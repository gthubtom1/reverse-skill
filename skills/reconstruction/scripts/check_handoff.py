#!/usr/bin/env python3
"""Read-only handoff pointer checks. No execution, REA imports or semantic closure."""

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path, PureWindowsPath


FR_ID = re.compile(r"\bFR-\d{3,}\b")
E_ID = re.compile(r"E-[A-Za-z0-9][A-Za-z0-9_-]*")
SHA256 = re.compile(r"[0-9a-f]{64}")
SOURCE_KINDS = {"observed", "inferred", "unknown", "designed"}


class CheckError(ValueError):
    def __init__(self, code, location, message):
        super().__init__(message)
        self.code = code
        self.location = location


def fail(code, location, message):
    raise CheckError(code, location, message)


def object_keys(value, required, location):
    if not isinstance(value, dict) or set(value) != set(required):
        fail("input.fields", location, "Expected exactly: " + ", ".join(required))
    return value


def items(value, location, nonempty=False):
    if not isinstance(value, list) or (nonempty and not value):
        fail("input.list", location, "Expected " + ("nonempty " if nonempty else "") + "array")
    return value


def relative_file(root, value, location, directory=False):
    """Check both portable spelling and resolved containment, including links/junctions."""
    if not isinstance(value, str) or not value or value != value.strip():
        fail("path.relative", location, "Expected a nonempty project-relative path")
    parts = value.split("/")
    if (PureWindowsPath(value).drive or value.startswith("/") or "\\" in value
            or ":" in value or any(p in {"", ".", ".."} for p in parts)
            or any(ord(c) < 32 for c in value)):
        fail("path.relative", location, "Use relative slash paths without traversal or drive/URI prefixes")
    path = (root / value).resolve()
    try:
        path.relative_to(root)
    except ValueError:
        fail("path.outside_root", location, "Resolved path leaves the selected root")
    if not (path.is_dir() if directory else path.is_file()):
        fail("path.missing", location, "Referenced " + ("directory" if directory else "file") + " is missing")
    return path


def digest(path):
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def no_duplicate_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate JSON key: " + key)
        result[key] = value
    return result


def load_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"), object_pairs_hook=no_duplicate_keys)


def field(text, key, location):
    # Only top-level scalar Evidence fields; block text is never interpreted as fields.
    matches = re.findall(r"(?m)^- " + re.escape(key) + r":[ \t]*(.*)$", text)
    if len(matches) != 1:
        fail("evidence.field", location, "Expected one scalar Evidence field: " + key)
    return matches[0].strip()


class HandoffCheck:
    def __init__(self, root):
        self.root = root
        self.checked_files = set()

    def file_ref(self, value, location):
        object_keys(value, ("path", "sha256"), location)
        expected = value["sha256"]
        if not isinstance(expected, str) or not SHA256.fullmatch(expected):
            fail("sha256.invalid", location, "Expected lowercase 64-hex SHA-256 of exact file bytes")
        path = relative_file(self.root, value["path"], location)
        # Recheck every commitment, even when multiple pointers name the same path.
        if digest(path) != expected:
            fail("sha256.mismatch", location, "Referenced bytes differ from the committed SHA-256")
        self.checked_files.add(value["path"])
        return path

    def json_ref(self, value, location):
        object_keys(value, ("document_ref", "pointer"), location)
        path = self.file_ref(value["document_ref"], location + ".document_ref")
        target = load_json(path)
        pointer = value["pointer"]
        if not isinstance(pointer, str) or not pointer.startswith("/"):
            fail("pointer.invalid", location, "Expected a non-root RFC 6901 JSON pointer")
        for token in pointer[1:].split("/"):
            if re.search(r"~(?![01])", token):
                fail("pointer.invalid", location, "Invalid JSON pointer escape")
            token = token.replace("~1", "/").replace("~0", "~")
            if isinstance(target, dict) and token in target:
                target = target[token]
            elif isinstance(target, list) and re.fullmatch(r"0|[1-9]\d*", token) and int(token) < len(target):
                target = target[int(token)]
            else:
                fail("pointer.missing", location, "JSON pointer does not resolve")
        return target

    def evidence_ref(self, value, case, location):
        object_keys(value, ("evidence_id", "record_ref"), location)
        evidence_id = value["evidence_id"]
        if not isinstance(evidence_id, str) or not E_ID.fullmatch(evidence_id):
            fail("evidence.id", location, "Expected an original case E-id")
        path = self.file_ref(value["record_ref"], location + ".record_ref")
        expected_path = relative_file(case, "evidence/" + evidence_id + ".md", location)
        if path != expected_path:
            fail("evidence.record", location, "E-id must reference its original case Evidence file")
        text = path.read_text(encoding="utf-8-sig")
        headings = re.findall(r"(?m)^### (E-[A-Za-z0-9][A-Za-z0-9_-]*)\b", text)
        if headings != [evidence_id]:
            fail("evidence.heading", location, "Evidence heading must match the referenced E-id exactly once")
        artifact_path = field(text, "artifact_path", location)
        artifact = relative_file(case, artifact_path, location + ".artifact_path")
        expected_hash = field(text, "content_hash", location)
        if expected_hash.startswith("sha256:"):
            expected_hash = expected_hash[7:]
        if not SHA256.fullmatch(expected_hash) or digest(artifact) != expected_hash:
            fail("evidence.artifact_sha256", location, "Evidence artifact is unpinned or has changed")
        self.checked_files.add(artifact.relative_to(self.root).as_posix())
        return evidence_id

    def check(self, manifest):
        object_keys(manifest, ("manifest_version", "case_root", "context_refs", "feature_refs",
                               "bundle_refs", "requirements"), "manifest")
        if type(manifest["manifest_version"]) is not int or manifest["manifest_version"] != 1:
            fail("input.version", "manifest_version", "Supported manifest_version is 1")
        case = relative_file(self.root, manifest["case_root"], "case_root", directory=True)
        context = object_keys(manifest["context_refs"], ("scope", "timeline", "workitems"), "context_refs")
        for name, ref in context.items():
            path = self.file_ref(ref, "context_refs." + name)
            expected = relative_file(case, name + ".md", "context_refs." + name)
            if path != expected:
                fail("case.reference", "context_refs." + name, "Must reference the selected case's original file")
        feature = object_keys(manifest["feature_refs"], ("spec", "plan", "tasks"), "feature_refs")
        feature_paths = {name: self.file_ref(ref, "feature_refs." + name) for name, ref in feature.items()}
        spec_path = feature_paths["spec"]
        try:
            spec_path.relative_to(self.root / "specs")
        except ValueError:
            fail("feature.reference", "feature_refs.spec", "Feature must reside under project specs/")
        if any(path.name != name + ".md" or path.parent != spec_path.parent
               for name, path in feature_paths.items()):
            fail("feature.reference", "feature_refs", "Use spec.md, plan.md and tasks.md from the same feature")
        spec_ids = set(FR_ID.findall(spec_path.read_text(encoding="utf-8-sig")))
        if not spec_ids:
            fail("fr.missing", "feature_refs.spec", "No native FR identifiers found in selected spec")
        bundles = items(manifest["bundle_refs"], "bundle_refs", nonempty=True)
        for index, ref in enumerate(bundles):
            self.file_ref(ref, "bundle_refs[" + str(index) + "]")
        requirements = items(manifest["requirements"], "requirements", nonempty=True)
        seen = set()
        review = []
        for index, req in enumerate(requirements):
            loc = "requirements[" + str(index) + "]"
            object_keys(req, ("fr_id", "source_kind", "evidence_refs", "unknown_refs", "obligation_ref"), loc)
            fr = req["fr_id"]
            if not isinstance(fr, str) or not FR_ID.fullmatch(fr) or fr not in spec_ids:
                fail("fr.reference", loc, "FR must occur in the selected native spec")
            if fr in seen:
                fail("fr.duplicate", loc, "Repeated FR mapping")
            seen.add(fr)
            if not isinstance(req["source_kind"], str) or req["source_kind"] not in SOURCE_KINDS:
                fail("fr.source_kind", loc, "Expected observed, inferred, unknown or designed")
            evidence_ids = []
            for j, ref in enumerate(items(req["evidence_refs"], loc + ".evidence_refs", nonempty=True)):
                evidence_ids.append(self.evidence_ref(ref, case, loc + ".evidence_refs[" + str(j) + "]"))
            if len(set(evidence_ids)) != len(evidence_ids):
                fail("evidence.duplicate", loc, "Repeated Evidence reference for FR")
            obligation = self.json_ref(req["obligation_ref"], loc + ".obligation_ref")
            if (not isinstance(obligation, dict)
                    or not isinstance(obligation.get("obligation_id"), str)
                    or not obligation["obligation_id"].strip()
                    or type(obligation.get("obligation_version")) is not int
                    or obligation["obligation_version"] < 1):
                fail("obligation.identity", loc, "Obligation pointer must select an object with ID and positive integer version")
            for j, ref in enumerate(items(req["unknown_refs"], loc + ".unknown_refs")):
                u_loc = loc + ".unknown_refs[" + str(j) + "]"
                object_keys(ref, ("document_ref", "pointer", "critical"), u_loc)
                if type(ref["critical"]) is not bool:
                    fail("unknown.critical", u_loc, "critical must be an explicit boolean")
                unknown = self.json_ref({k: ref[k] for k in ("document_ref", "pointer")}, u_loc)
                if not isinstance(unknown, dict) or not unknown:
                    fail("unknown.identity", u_loc, "Unknown pointer must select a nonempty source object")
                if ref["critical"]:
                    fail("unknown.critical_open", u_loc, fr + " cites a declared unresolved critical unknown; return it to analysis")
            review.append({"fr_id": fr, "source_kind": req["source_kind"],
                           "required": "Review evidence support, unknown completeness, authority and current applicability"})
        if seen != spec_ids:
            fail("fr.unmapped", "requirements", "Missing FR mappings: " + ", ".join(sorted(spec_ids - seen)))
        return review


def check_handoff(project_root, manifest_path):
    checker = None
    issues = []
    review = []
    try:
        root = Path(project_root).resolve()
        if not root.is_dir():
            fail("path.missing", "project_root", "Project root directory is missing")
        path = relative_file(root, manifest_path, "manifest")
        checker = HandoffCheck(root)
        review = checker.check(load_json(path))
    except CheckError as exc:
        issues.append({"code": exc.code, "location": exc.location, "message": str(exc)})
    except (OSError, ValueError, RuntimeError, RecursionError) as exc:
        issues.append({"code": "input.unreadable", "location": "input", "message": str(exc)})
    return {"assessment_scope": "machine_check_only", "status": "FAIL" if issues else "PASS",
            "semantic_verification": "not_performed", "target_execution": "not_performed",
            "authorization": "not_assessed", "issues": issues,
            "checked_files": sorted(checker.checked_files) if checker else [],
            "semantic_review_required": review,
            "limitations": ["SHA-256 checks fixity against supplied commitments, not authenticity or freshness of the selected version.",
                            "Source classifications and unknown lists require independent review; omitted or misclassified unknowns are not discovered.",
                            "No REA schema validation, Evidence authentication, proof applicability or semantic closure is performed.",
                            "PASS permits only mechanical handoff review; it does not authorize ACT or establish implementation readiness."]}


def render_markdown(report):
    lines = ["# Handoff machine check", "", "- assessment_scope: machine_check_only",
             "- status: " + report["status"], "- semantic_verification: not_performed",
             "- target_execution: not_performed", "- authorization: not_assessed", ""]
    for issue in report["issues"]:
        lines.append("- " + issue["code"] + " @ " + issue["location"] + ": " + issue["message"])
    lines.extend(["", "Independent semantic review remains required for every FR.", ""])
    lines.extend("- " + limitation for limitation in report["limitations"])
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Read-only relative-path/SHA/Evidence/FR pointer checks (machine_check_only)")
    parser.add_argument("project_root", help="Explicit user outcome project root; never searches for projects")
    parser.add_argument("manifest", help="Handoff manifest path relative to project_root")
    parser.add_argument("--format", choices=("json", "markdown"), default="json")
    args = parser.parse_args(argv)
    report = check_handoff(args.project_root, args.manifest)
    print(json.dumps(report, ensure_ascii=False, indent=2) if args.format == "json" else render_markdown(report))
    return 1 if report["status"] == "FAIL" else 0


if __name__ == "__main__":
    sys.exit(main())
