#!/usr/bin/env python3
"""Read-only authorization coverage checks. A mechanical closure is not behavior proof."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import stat
import sys

VERSION = 2
STATUSES = {"unexamined", "observed", "patched", "verified", "blocked", "unknown", "not-applicable"}
RESULT_STATUSES = {"pass", "fail", "blocked", "unknown", "skipped"}
HEX64 = re.compile(r"[0-9a-f]{64}\Z")
IDENTIFIER = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,127}\Z")
MAX_DOCUMENT = 2 * 1024 * 1024


class Invalid(ValueError):
    """Invalid schema, unsafe reference, or broken provenance binding."""


def need(condition, message):
    if not condition:
        raise Invalid(message)


def obj(value, required, label, optional=()):
    need(isinstance(value, dict), f"{label} must be an object")
    need(set(required) <= value.keys(), f"{label} missing required fields: {sorted(set(required) - value.keys())}")
    need(value.keys() <= set(required) | set(optional), f"{label} contains unsupported fields")
    return value


def text(value, label):
    need(isinstance(value, str) and bool(value.strip()), f"{label} must be a non-empty string")
    return value


def identifier(value, label):
    need(isinstance(value, str) and bool(IDENTIFIER.fullmatch(value)), f"{label} must be an identifier")
    return value


def digest(value, label):
    need(isinstance(value, str) and bool(HEX64.fullmatch(value)), f"{label} must be a lowercase SHA-256")
    return value


def enum(value, allowed, label):
    need(isinstance(value, str) and value in allowed, f"{label} must be one of {sorted(allowed)}")
    return value


def array(value, label, nonempty=False):
    need(isinstance(value, list), f"{label} must be an array")
    need(not nonempty or bool(value), f"{label} must not be empty")
    return value


def ids(value, label, nonempty=False):
    array(value, label, nonempty)
    for item in value:
        identifier(item, label)
    need(len(value) == len(set(value)), f"{label} contains duplicate ids")
    return value


def timestamp(value, label):
    text(value, label)
    need(bool(re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z", value)),
         f"{label} must be an RFC3339 UTC timestamp ending in Z")
    try:
        return datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError as exc:
        raise Invalid(f"{label} has an invalid date") from exc


def json_document(raw, label):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            need(key not in result, f"{label} contains duplicate JSON keys")
            result[key] = value
        return result

    def constant(_):
        raise Invalid(f"{label} contains a non-finite JSON number")

    try:
        return json.loads(raw.decode("utf-8-sig"), object_pairs_hook=unique, parse_constant=constant)
    except (UnicodeError, ValueError, RecursionError) as exc:
        if isinstance(exc, Invalid):
            raise
        raise Invalid(f"{label} is not valid UTF-8 JSON") from exc


def markdown_fields(raw, label):
    """Read the existing simple Markdown field convention, never fenced commands."""
    try:
        source = raw.decode("utf-8-sig")
    except UnicodeError as exc:
        raise Invalid(f"{label} is not UTF-8") from exc
    sections = {"": {}}
    section = ""
    headings = []
    fence = None
    for line in source.splitlines():
        stripped = line.lstrip()
        if fence:
            if stripped.startswith(fence):
                fence = None
            continue
        match = re.match(r"^\s*(`{3,}|~{3,})", line)
        if match:
            fence = match[1]
            continue
        match = re.fullmatch(r"(#{1,6})\s+(.+?)\s*", line)
        if match:
            headings.append(match[2])
            if len(match[1]) == 2:
                section = match[2]
                need(section not in sections, f"{label} has duplicate sections")
                sections[section] = {}
            continue
        match = re.fullmatch(r"- ([A-Za-z_][A-Za-z0-9_]*):\s*(.*?)\s*", line)
        if match:
            key, value = match.groups()
            need(key not in sections[section], f"{label} has duplicate field {key}")
            sections[section][key] = value
    return sections, headings


def unlinked(path, label):
    info = path.lstat()
    need(not stat.S_ISLNK(info.st_mode) and not getattr(info, "st_file_attributes", 0) & 0x400,
         f"{label}: links/reparse points are not allowed")
    return info


class CaseFiles:
    def __init__(self, root):
        self.root = Path(root).absolute()
        for part in (self.root, *self.root.parents):
            unlinked(part, "case root")
        need(self.root.is_dir(), "case root must be a directory")

    def path(self, relative, label):
        text(relative, f"{label}.path")
        need(not any(ord(c) < 32 or ord(c) == 127 or c in "\\:%" for c in relative),
             f"{label}: unsafe path")
        parts = relative.split("/")
        for part in parts:
            need(part not in {"", ".", ".."} and not part.endswith((" ", ".")), f"{label}: unsafe path")
            need(not re.fullmatch(r"(?i:CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(?:\..*)?", part),
                 f"{label}: unsafe device path")
        path = self.root
        for part in parts:
            path = path / part
            info = unlinked(path, label)
        need(stat.S_ISREG(info.st_mode) and info.st_nlink == 1, f"{label}: expected a regular file with no hard links")
        return path

    def read(self, relative, label, expected=None, document=False):
        path = self.path(relative, label)
        hasher = hashlib.sha256()
        chunks = []
        size = 0
        with path.open("rb") as stream:
            while True:
                block = stream.read(1024 * 1024)
                if not block:
                    break
                hasher.update(block)
                if document:
                    size += len(block)
                    need(size <= MAX_DOCUMENT, f"{label}: document exceeds 2 MiB")
                    chunks.append(block)
        actual = hasher.hexdigest()
        if expected is not None:
            need(actual == expected, f"{label}: SHA-256 mismatch")
        return b"".join(chunks), actual

    def ref(self, value, label, document=False):
        obj(value, ("path", "sha256"), label)
        digest(value["sha256"], f"{label}.sha256")
        return self.read(value["path"], label, value["sha256"], document)[0]


class Checker:
    def __init__(self, files, now):
        self.files = files
        self.now = now
        self.evidence_seen = {}
        self.blockers = []
        self.summary = {
            "complete": False, "mechanical_only": True, "required": 0,
            "closed": 0, "verified": 0, "not_applicable": 0,
            "counts": {}, "reopened": [], "inventory_reviewed": False,
        }

    def evidence(self, ref, label, document=False):
        obj(ref, ("id", "path", "sha256"), label)
        eid = identifier(ref["id"], f"{label}.id")
        need(eid.startswith("E-"), f"{label}.id must start with E-")
        need(ref["path"] == f"evidence/{eid}.md", f"{label}: Evidence path must match id")
        previous = self.evidence_seen.setdefault(eid, ref)
        need(previous == ref, f"{label}: conflicting references for Evidence id")
        raw = self.files.ref({"path": ref["path"], "sha256": ref["sha256"]}, label, True)
        sections, headings = markdown_fields(raw, label)
        need(bool(headings) and bool(re.fullmatch(re.escape(eid) + r"(?:\s+.*)?", headings[0])),
             f"{label}: Evidence heading does not match id")
        fields = sections.get(headings[0], sections[""])
        observed = timestamp(fields.get("observed_at"), f"{label}.observed_at")
        need(observed <= self.now, f"{label}: Evidence is dated in the future")
        artifact = {"path": fields.get("artifact_path"), "sha256": fields.get("content_hash")}
        payload = self.files.ref(artifact, f"{label}.artifact", document)
        return artifact, payload

    def evidence_list(self, value, label, nonempty=False):
        array(value, label, nonempty)
        seen = set()
        for index, ref in enumerate(value):
            self.evidence(ref, f"{label}[{index}]")
            need(ref["id"] not in seen, f"{label}: duplicate Evidence id")
            seen.add(ref["id"])

    def identity(self, data, label):
        need(data["case_id"] == self.case_id, f"{label}: case_id mismatch")
        need(data["target_sha256"] == self.target, f"{label}: target_sha256 mismatch")

    def run(self, data):
        obj(data, ("schema_version", "case_id", "goal_id", "target_sha256", "scope", "target_evidence",
                   "inventory_evidence", "entries", "regression_results"), "manifest", ("complete",))
        need(type(data["schema_version"]) is int and data["schema_version"] == VERSION, "schema_version must be 2")
        if "complete" in data:
            need(type(data["complete"]) is bool, "complete must be a boolean")
        self.case_id = identifier(data["case_id"], "case_id")
        identifier(data["goal_id"], "goal_id")
        self.target = digest(data["target_sha256"], "target_sha256")
        scope_raw = self.files.ref(data["scope"], "scope", True)
        need(data["scope"]["path"] == "scope.md", "scope must reference the existing case scope.md")
        scope, _ = markdown_fields(scope_raw, "scope")
        need(scope.get("meta", {}).get("case_id") == self.case_id, "scope: case_id mismatch")
        pins = scope.get("authorization_coverage", {})
        need(pins.get("target_sha256") == self.target, "scope.authorization_coverage: target_sha256 mismatch or missing")
        inventory_hash = digest(pins.get("inventory_sha256"), "scope.authorization_coverage.inventory_sha256")
        if scope.get("auth", {}).get("status") != "granted" or scope.get("signoff", {}).get("ready_for_act") != "true":
            self.blockers.append("existing scope is not granted/ready; this checker never grants authorization")
        target_ref, _ = self.evidence(data["target_evidence"], "target_evidence")
        need(target_ref["sha256"] == self.target, "target Evidence artifact does not match target_sha256")
        inventory_ref, raw = self.evidence(data["inventory_evidence"], "inventory_evidence", True)
        need(inventory_ref["sha256"] == inventory_hash, "inventory differs from the immutable scope pin")
        inventory = json_document(raw, "inventory")
        surfaces, tests = self.inventory(inventory)
        self.summary["required"] = len(surfaces)
        rows = self.entries(data["entries"], surfaces)
        snapshot = []
        for sid in sorted(rows):
            row = rows[sid]
            snapshot.append({
                "id": sid, "source_sha256": surfaces[sid]["source"]["sha256"],
                "current_sha256": row["current"]["sha256"],
                "patch_sha256": row["patch"]["sha256"] if row["patch"] else None,
                "rollback_sha256": row["rollback"]["sha256"] if row["rollback"] else None,
                "changed_at": row["changed_at"],
            })
        state_hash = hashlib.sha256(json.dumps(snapshot, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode("ascii")).hexdigest()
        self.summary["state_sha256"] = state_hash
        latest_change = max(timestamp(row["changed_at"], "changed_at") for row in rows.values())
        results = self.results(data["regression_results"], tests, inventory_hash, state_hash, latest_change)
        self.closure(rows, surfaces, results)
        self.summary["complete"] = not self.blockers and self.summary["closed"] == len(surfaces)
        need(not data.get("complete", False) or self.summary["complete"],
             "complete=true is invalid until all required surfaces and regressions close")

    def inventory(self, data):
        obj(data, ("schema_version", "case_id", "target_sha256", "review", "surfaces", "regressions"), "inventory")
        need(type(data["schema_version"]) is int and data["schema_version"] == VERSION, "inventory.schema_version must be 2")
        self.identity(data, "inventory")
        review = obj(data["review"], ("status", "evidence"), "inventory.review")
        enum(review["status"], {"pending", "reviewed"}, "inventory.review.status")
        reviewed = review["status"] == "reviewed"
        self.evidence_list(review["evidence"], "inventory.review.evidence", reviewed)
        self.summary["inventory_reviewed"] = reviewed
        if not reviewed:
            self.blockers.append("inventory completeness/neighbor review is pending")
        surfaces = {}
        for index, surface in enumerate(array(data["surfaces"], "inventory.surfaces", True)):
            label = f"inventory.surfaces[{index}]"
            obj(surface, ("id", "component", "source", "gate", "entry_point", "expected_behavior", "neighbors", "regression_ids"), label)
            sid = identifier(surface["id"], f"{label}.id")
            need(sid not in surfaces, f"{label}: duplicate surface id")
            for key in ("component", "gate", "entry_point", "expected_behavior"):
                text(surface[key], f"{label}.{key}")
            self.files.ref(surface["source"], f"{label}.source")
            ids(surface["neighbors"], f"{label}.neighbors")
            ids(surface["regression_ids"], f"{label}.regression_ids", True)
            surfaces[sid] = surface
        tests = {}
        for index, test in enumerate(array(data["regressions"], "inventory.regressions", True)):
            label = f"inventory.regressions[{index}]"
            obj(test, ("id", "covers", "specification", "max_age_hours"), label)
            tid = identifier(test["id"], f"{label}.id")
            need(tid not in tests, f"{label}: duplicate regression id")
            ids(test["covers"], f"{label}.covers", True)
            need(set(test["covers"]) <= surfaces.keys(), f"{label}: unknown covered surface")
            need(type(test["max_age_hours"]) is int and 1 <= test["max_age_hours"] <= 8760,
                 f"{label}.max_age_hours must be an integer from 1 to 8760")
            self.files.ref(test["specification"], f"{label}.specification")
            tests[tid] = test
        for sid, surface in surfaces.items():
            need(set(surface["neighbors"]) <= surfaces.keys() - {sid}, f"{sid}: unknown/self neighbor")
            need(set(surface["regression_ids"]) <= tests.keys(), f"{sid}: unknown regression id")
            for tid in surface["regression_ids"]:
                need(sid in tests[tid]["covers"], f"{sid}: regression {tid} does not cover this surface")
        # Every planned test must participate in closure for every surface it covers.
        for tid, test in tests.items():
            for sid in test["covers"]:
                need(tid in surfaces[sid]["regression_ids"], f"{tid}: unrequired regression for covered surface {sid}")
        return surfaces, tests

    def entries(self, data, surfaces):
        rows = {}
        for index, row in enumerate(array(data, "entries")):
            label = f"entries[{index}]"
            obj(row, ("id", "status", "current", "changed_at", "patch", "rollback", "evidence", "reason", "side_effects"), label)
            sid = identifier(row["id"], f"{label}.id")
            need(sid in surfaces, f"{label}: unknown surface")
            need(sid not in rows, f"{label}: duplicate surface")
            status = enum(row["status"], STATUSES, f"{label}.status")
            self.files.ref(row["current"], f"{label}.current")
            changed = timestamp(row["changed_at"], f"{label}.changed_at")
            need(changed <= self.now, f"{label}: changed_at is in the future")
            need(isinstance(row["reason"], str) and isinstance(row["side_effects"], str), f"{label}: reason and side_effects must be strings")
            self.evidence_list(row["evidence"], f"{label}.evidence", status in {"observed", "patched", "verified", "not-applicable"} or row["patch"] is not None)
            if row["patch"] is None:
                need(row["rollback"] is None, f"{label}: rollback without patch")
                need(row["current"]["sha256"] == surfaces[sid]["source"]["sha256"], f"{label}: changed component requires patch/rollback")
                need(status != "patched", f"{label}: patched status requires patch")
            else:
                self.files.ref(row["patch"], f"{label}.patch")
                self.files.ref(row["rollback"], f"{label}.rollback")
                text(row["side_effects"], f"{label}.side_effects")
                need(status not in {"unexamined", "observed", "not-applicable"}, f"{label}: status incompatible with a recorded patch")
            if status in {"not-applicable", "blocked", "unknown"}:
                text(row["reason"], f"{label}.reason")
            rows[sid] = row
        need(rows.keys() == surfaces.keys(), "entries must retain every inventory surface; omitted components cannot reduce coverage")
        self.summary["counts"] = {status: sum(row["status"] == status for row in rows.values()) for status in sorted(STATUSES)}
        return rows

    def results(self, data, tests, inventory_hash, state_hash, latest_change):
        results = {}
        for index, ref in enumerate(array(data, "regression_results")):
            label = f"regression_results[{index}]"
            _, raw = self.evidence(ref, label, True)
            result = json_document(raw, f"{label}.artifact")
            obj(result, ("schema_version", "id", "case_id", "target_sha256", "inventory_sha256", "state_sha256",
                         "specification_sha256", "tested_surfaces", "status", "executed_at", "evidence"), label)
            need(type(result["schema_version"]) is int and result["schema_version"] == VERSION, f"{label}.schema_version must be 2")
            tid = identifier(result["id"], f"{label}.id")
            need(tid in tests, f"{label}: unknown/fake regression result id")
            need(tid not in results, f"{label}: duplicate regression result id; retain one current result per test")
            self.identity(result, label)
            for key in ("inventory_sha256", "state_sha256", "specification_sha256"):
                digest(result[key], f"{label}.{key}")
            ids(result["tested_surfaces"], f"{label}.tested_surfaces", True)
            need(set(result["tested_surfaces"]) == set(tests[tid]["covers"]), f"{label}: tested_surfaces mismatch")
            status = enum(result["status"], RESULT_STATUSES, f"{label}.status")
            executed = timestamp(result["executed_at"], f"{label}.executed_at")
            self.evidence_list(result["evidence"], f"{label}.evidence", True)
            problems = []
            if status != "pass":
                problems.append(f"status={status}")
            if result["inventory_sha256"] != inventory_hash or result["state_sha256"] != state_hash or result["specification_sha256"] != tests[tid]["specification"]["sha256"]:
                problems.append("stale inventory/state/specification binding")
            age = (self.now - executed).total_seconds()
            if age < 0 or age > tests[tid]["max_age_hours"] * 3600 or executed < latest_change:
                problems.append("stale/future result time or execution before latest change")
            results[tid] = problems
            if problems:
                self.blockers.append(f"{tid}: {'; '.join(problems)}")
        return results

    def closure(self, rows, surfaces, results):
        # Missing results are ordinary partial progress, not malformed JSON.
        for sid, row in rows.items():
            required_tests = set(surfaces[sid]["regression_ids"])
            if row["patch"]:
                for neighbor in surfaces[sid]["neighbors"]:
                    required_tests.update(surfaces[neighbor]["regression_ids"])
            problems = []
            for tid in sorted(required_tests):
                if tid not in results:
                    problems.append(f"{tid}: missing result")
                elif results[tid]:
                    problems.append(f"{tid}: {'; '.join(results[tid])}")
            if row["status"] in {"verified", "not-applicable"} and not problems:
                self.summary["closed"] += 1
                key = "verified" if row["status"] == "verified" else "not_applicable"
                self.summary[key] += 1
            else:
                if row["status"] in {"verified", "not-applicable"}:
                    self.summary["reopened"].append({"id": sid, "effective_status": "patched" if row["patch"] else "unknown", "reasons": problems})
                self.blockers.append(f"{sid}: " + ("; ".join(problems) if problems else f"status={row['status']}"))


def validate(data, case_root, now=None):
    """Return schema/provenance errors, summary and closure blockers; never write."""
    checker = None
    errors = []
    summary = {"complete": False, "mechanical_only": True}
    try:
        checker = Checker(CaseFiles(case_root), now or datetime.now(timezone.utc))
        checker.run(data)
    except (Invalid, OSError, ValueError, RecursionError) as exc:
        errors.append(str(exc) if isinstance(exc, Invalid) else "unreadable input, invalid path, or excessive nesting")
    if checker:
        summary = checker.summary
    if errors:
        summary["complete"] = False
    return errors, summary, checker.blockers if checker else []


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path, help="manifest inside the existing case")
    parser.add_argument("--case-root", type=Path, required=True, help="explicit existing case root; never inferred from manifest")
    parser.add_argument("--require-complete", action="store_true", help="exit 2 for a valid but incomplete manifest")
    parser.add_argument("--format", choices=("json", "text"), default="text")
    args = parser.parse_args(argv)
    try:
        files = CaseFiles(args.case_root)
        # absolute() preserves '..' for the path validator; do not resolve links away.
        relative = args.manifest.absolute().relative_to(files.root).as_posix()
        raw, _ = files.read(relative, "manifest", document=True)
        data = json_document(raw, "manifest")
        errors, summary, blockers = validate(data, args.case_root)
    except (Invalid, OSError, ValueError, RecursionError) as exc:
        errors = [str(exc) if isinstance(exc, Invalid) else "manifest must be a readable file inside the explicit case root"]
        summary, blockers = {"complete": False, "mechanical_only": True}, []
    exit_code = 1 if errors else (2 if args.require_complete and not summary["complete"] else 0)
    result = {"ok": not errors, "errors": errors, "blockers": blockers, "summary": summary, "exit_code": exit_code}
    if args.format == "json":
        print(json.dumps(result, ensure_ascii=True, indent=2))
    else:
        state = "INVALID" if errors else ("MECHANICALLY COMPLETE" if summary["complete"] else "INCOMPLETE")
        print(f"authorization coverage: {state}; semantic verification not performed")
        print(json.dumps(summary, ensure_ascii=True, indent=2))
        for message in errors + blockers:
            print(f"- {message}", file=sys.stderr)
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
