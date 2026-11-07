#!/usr/bin/env python3
"""Offline CLI tests using real case-local files and Evidence, never target execution.

Fixtures are retained in an owned directory printed at exit for inspection/recycling.
No files are deleted. Pass --work-dir to select a new, absent fixture directory.
"""
from __future__ import annotations

import argparse
import copy
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

CHECKER = Path(__file__).absolute().with_name("check-authorization-coverage.py")
WORK_DIR = None


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def stamp(value):
    return value.strftime("%Y-%m-%dT%H:%M:%SZ")


class Fixture:
    """Seven surfaces, one changed binary, a plugin neighbor, and seven tests."""
    def __init__(self, root):
        self.root = root
        self.root.mkdir(parents=True)
        self.now = datetime.now(timezone.utc).replace(microsecond=0)
        self.changed_at = stamp(self.now - timedelta(hours=2))
        self.executed_at = stamp(self.now - timedelta(hours=1))
        self.observed_at = stamp(self.now - timedelta(minutes=30))
        self.inventory = {
            "schema_version": 2, "case_id": "case-coverage", "target_sha256": "",
            "review": {"status": "reviewed", "evidence": []}, "surfaces": [], "regressions": [],
        }
        self.manifest = {
            "schema_version": 2, "case_id": "case-coverage", "goal_id": "GOAL-LOGIC",
            "target_sha256": "", "scope": {}, "target_evidence": {}, "inventory_evidence": {},
            "entries": [], "regression_results": [],
        }
        names = ["main", "plugin", "jni", "cache", "online", "heartbeat", "integrity"]
        for index, name in enumerate(names):
            sid, tid = f"S-{index}", f"T-{index}"
            original = self.file(f"artifacts/source-{index}.bin", f"original {name}\n")
            if index == 0:
                self.inventory["target_sha256"] = self.manifest["target_sha256"] = original["sha256"]
                self.manifest["target_evidence"] = self.evidence("E-target", original)
            self.inventory["surfaces"].append({
                "id": sid, "component": name, "source": original,
                "gate": f"{name} entitlement", "entry_point": f"{name}::check_entitlement",
                "expected_behavior": f"{name}: allow authorized fixture; reject invalid and expired fixture",
                "neighbors": ["S-1"] if index == 0 else [], "regression_ids": [tid],
            })
            spec = self.file(f"artifacts/spec-{index}.txt", f"Compare allow, deny and error outputs for {name}\n")
            self.inventory["regressions"].append({"id": tid, "covers": [sid], "specification": spec, "max_age_hours": 168})
            observation = self.file(f"artifacts/observation-{index}.txt", f"Fixture observations for {name}; side effects reviewed\n")
            self.manifest["entries"].append({
                "id": sid, "status": "verified", "current": original,
                "changed_at": self.changed_at, "patch": None, "rollback": None,
                "evidence": [self.evidence(f"E-observation-{index}", observation)], "reason": "", "side_effects": "",
            })
        main = self.manifest["entries"][0]
        main.update({
            "current": self.file("artifacts/main-current.bin", "modified main fixture\n"),
            "patch": self.file("artifacts/main.patch", "synthetic patch description\n"),
            "rollback": self.file("artifacts/main.rollback", "synthetic rollback description\n"),
            "side_effects": "Plugin behavior affected; reviewed in the linked observation.",
        })
        reviewed = self.file("artifacts/inventory-review.txt", "Reviewed seven components, all gates, failure states and neighbor effects.\n")
        self.inventory["review"]["evidence"] = [self.evidence("E-inventory-review", reviewed)]
        self.seal_inventory()
        self.refresh_results()
        self.save_manifest()

    def file(self, relative, value):
        raw = value if isinstance(value, bytes) else value.encode("utf-8")
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(raw)
        return {"path": relative, "sha256": sha(raw)}

    def json_file(self, relative, value):
        return self.file(relative, json.dumps(value, indent=2, ensure_ascii=True) + "\n")

    def evidence(self, eid, artifact):
        record = (
            f"### {eid}\n- title: synthetic offline fixture\n- observed_at: {self.observed_at}\n"
            f"- source_type: file\n- source_ref: {artifact['path']}\n"
            f"- content_hash: {artifact['sha256']}\n- artifact_path: {artifact['path']}\n"
            "- repro_command: |\n    descriptive text only; never execute\n"
            "- raw_excerpt: |\n    synthetic evidence, not real behavior validation\n"
            "- linked_workitem: WI-001\n- supersedes: none\n"
        )
        return {"id": eid, **self.file(f"evidence/{eid}.md", record)}

    def seal_inventory(self, update_scope=True):
        self.inventory_ref = self.json_file("notes/inventory.json", self.inventory)
        self.manifest["inventory_evidence"] = self.evidence("E-inventory", self.inventory_ref)
        if update_scope:
            self.scope_text = (
                "# Case Scope\n\n## meta\n- case_id: case-coverage\n\n"
                "## auth\n- status: granted\n- basis: own_system\n- evidence_of_auth: owner-operated fixture\n\n"
                "## in_scope\n- assets: [artifacts/source-0.bin]\n- activities: [reverse]\n\n"
                "## network_profile\n- mode: offline\n\n## signoff\n- ready_for_act: true\n\n"
                "## authorization_coverage\n"
                f"- target_sha256: {self.manifest['target_sha256']}\n"
                f"- inventory_sha256: {self.inventory_ref['sha256']}\n"
            )
            self.manifest["scope"] = self.file("scope.md", self.scope_text)

    def state_hash(self):
        # Serialize the documented interchange format independently of the checker.
        source = {s["id"]: s["source"]["sha256"] for s in self.inventory["surfaces"]}
        snapshot = [{
            "id": row["id"], "source_sha256": source[row["id"]],
            "current_sha256": row["current"]["sha256"],
            "patch_sha256": row["patch"]["sha256"] if row["patch"] is not None else None,
            "rollback_sha256": row["rollback"]["sha256"] if row["rollback"] is not None else None,
            "changed_at": row["changed_at"],
        } for row in sorted(self.manifest["entries"], key=lambda row: row["id"])]
        return sha(json.dumps(snapshot, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode("ascii"))

    def refresh_results(self):
        self.results = []
        self.manifest["regression_results"] = []
        for index, test in enumerate(self.inventory["regressions"]):
            raw = self.file(f"artifacts/run-{index}.log", f"Synthetic {test['id']} comparison output\n")
            result = {
                "schema_version": 2, "id": test["id"], "case_id": self.manifest["case_id"],
                "target_sha256": self.manifest["target_sha256"], "inventory_sha256": self.inventory_ref["sha256"],
                "state_sha256": self.state_hash(), "specification_sha256": test["specification"]["sha256"],
                "tested_surfaces": test["covers"], "status": "pass", "executed_at": self.executed_at,
                "evidence": [self.evidence(f"E-run-{index}", raw)],
            }
            self.results.append(result)
            self.manifest["regression_results"].append(None)
            self.save_result(index)

    def save_result(self, index):
        artifact = self.json_file(f"artifacts/result-{index}.json", self.results[index])
        self.manifest["regression_results"][index] = self.evidence(f"E-result-{index}", artifact)

    def save_manifest(self):
        self.json_file("notes/authorization-coverage.json", self.manifest)

    def run(self, require=True, raw=None, case_root=None):
        if raw is None:
            self.save_manifest()
        else:
            self.file("notes/authorization-coverage.json", raw)
        command = [sys.executable, "-B", str(CHECKER), str(self.root / "notes/authorization-coverage.json"),
                   "--case-root", str(case_root or self.root), "--format", "json"]
        if require:
            command.append("--require-complete")
        return subprocess.run(command, capture_output=True, text=True, timeout=20)


class CoverageTests(unittest.TestCase):
    def setUp(self):
        self.root = WORK_DIR / self._testMethodName
        self.fixture = Fixture(self.root / "case")

    def check(self, expected=0, contains=None, fixture=None, **kwargs):
        process = (fixture or self.fixture).run(**kwargs)
        self.assertNotIn("Traceback", process.stderr)
        self.assertEqual(process.returncode, expected, process.stdout + process.stderr)
        result = json.loads(process.stdout)
        self.assertEqual(result["exit_code"], expected)
        self.assertTrue(result["summary"]["mechanical_only"])
        self.assertEqual(result["ok"], not result["errors"])
        if expected:
            self.assertFalse(result["summary"]["complete"])
        if contains:
            self.assertIn(contains, process.stdout)
        return result

    def test_complete_seven_surfaces_and_read_only(self):
        f = self.fixture
        f.manifest["complete"] = True
        f.save_manifest()
        def snapshot():
            return {p.relative_to(f.root).as_posix(): (sha(p.read_bytes()), p.stat().st_mtime_ns)
                    for p in f.root.rglob("*") if p.is_file()}
        before = snapshot()
        process = subprocess.run([sys.executable, "-B", str(CHECKER), str(f.root / "notes/authorization-coverage.json"),
                                  "--case-root", str(f.root), "--format", "json", "--require-complete"],
                                 capture_output=True, text=True, timeout=20)
        self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
        result = json.loads(process.stdout)
        self.assertEqual((result["summary"]["verified"], result["summary"]["closed"], result["summary"]["required"]), (7, 7, 7))
        self.assertEqual(result["summary"]["state_sha256"], f.state_hash())
        self.assertEqual(snapshot(), before)

    def test_partial_one_of_seven_and_complete_claim(self):
        f = self.fixture
        for row in f.manifest["entries"][1:]:
            row.update(status="unexamined", evidence=[])
        f.manifest["regression_results"] = f.manifest["regression_results"][:2]
        partial = self.check(0, require=False)
        self.assertFalse(partial["summary"]["complete"])
        self.assertEqual((partial["summary"]["verified"], partial["summary"]["required"]), (1, 7))
        self.check(2)
        f.manifest["complete"] = True
        self.check(1, contains="complete=true")

    def test_empty_results_and_pending_statuses_are_valid_partial(self):
        f = self.fixture
        f.manifest["regression_results"] = []
        f.manifest["entries"][0]["status"] = "patched"
        for index, status in enumerate(("unexamined", "observed", "unknown", "blocked"), 1):
            f.manifest["entries"][index].update(status=status, reason="More evidence needed")
        self.check(0, require=False, contains="missing result")
        self.check(2)

    def test_omitted_component_and_required_false_cannot_hide_rows(self):
        f = self.fixture
        saved = copy.deepcopy(f.manifest)
        f.manifest["entries"].pop()
        self.check(1, contains="omitted components")
        for field in ("required", "required_for_completion"):
            f.manifest = copy.deepcopy(saved)
            f.manifest["entries"][0][field] = False
            self.check(1, contains="unsupported fields")
        f.manifest = saved
        f.manifest["required_for_completion"] = False
        self.check(1, contains="unsupported fields")

    def test_inventory_shrink_cannot_repin_itself(self):
        f = self.fixture
        f.inventory["surfaces"].pop()
        f.inventory["regressions"].pop()
        f.manifest["entries"].pop()
        f.seal_inventory(update_scope=False)
        self.check(1, contains="immutable scope pin")

    def test_inventory_review_pending_and_missing_evidence(self):
        f = self.fixture
        f.inventory["review"] = {"status": "pending", "evidence": []}
        f.seal_inventory()
        f.refresh_results()
        self.check(0, require=False, contains="review is pending")
        self.check(2)
        f.inventory["review"]["status"] = "reviewed"
        f.seal_inventory()
        self.check(1, contains="must not be empty")

    def test_neighbor_nonpass_results_reopen_main_and_neighbor(self):
        f = self.fixture
        for status in ("fail", "unknown", "skipped", "blocked"):
            with self.subTest(status=status):
                f.results[1]["status"] = status
                f.save_result(1)
                result = self.check(2, contains=f"status={status}")
                reopened = {row["id"]: row["effective_status"] for row in result["summary"]["reopened"]}
                self.assertEqual(reopened, {"S-0": "patched", "S-1": "unknown"})
                self.assertEqual(result["summary"]["closed"], 5)
                self.check(0, require=False)
                f.manifest["complete"] = True
                self.check(1, contains="complete=true")
                f.manifest["complete"] = False

    def test_missing_neighbor_regression_reopens_main(self):
        self.fixture.manifest["regression_results"].pop(1)
        result = self.check(2, contains="T-1: missing result")
        self.assertEqual({row["id"] for row in result["summary"]["reopened"]}, {"S-0", "S-1"})

    def test_stale_inventory_state_and_specification_bindings(self):
        f = self.fixture
        original = copy.deepcopy(f.results[1])
        for field in ("inventory_sha256", "state_sha256", "specification_sha256"):
            with self.subTest(field=field):
                f.results[1] = {**original, field: "f" * 64}
                f.save_result(1)
                result = self.check(2, contains="stale inventory/state/specification")
                self.assertEqual({row["id"] for row in result["summary"]["reopened"]}, {"S-0", "S-1"})

    def test_expired_future_and_prechange_regressions(self):
        f = self.fixture
        times = (f.now - timedelta(days=8), f.now + timedelta(hours=1), f.now - timedelta(hours=3))
        for value in times:
            with self.subTest(value=value):
                f.results[1]["executed_at"] = stamp(value)
                f.save_result(1)
                self.check(2, contains="stale/future result time")

    def test_new_patch_reopens_then_fresh_results_close(self):
        f = self.fixture
        f.manifest["entries"][0]["current"] = f.file("artifacts/main-current.bin", "second version\n")
        f.manifest["entries"][0]["patch"] = f.file("artifacts/main.patch", "second patch\n")
        f.manifest["entries"][0]["changed_at"] = stamp(f.now - timedelta(minutes=5))
        stale = self.check(2)
        self.assertEqual(stale["summary"]["closed"], 0)
        self.assertEqual(len(stale["summary"]["reopened"]), 7)
        f.executed_at = stamp(f.now - timedelta(minutes=2))
        f.refresh_results()
        self.check(0)

    def test_wrong_case_target_fake_id_and_tested_surfaces(self):
        f = self.fixture
        original = copy.deepcopy(f.results[1])
        mutations = {"case_id": "another-case", "target_sha256": "f" * 64,
                     "id": "T-made-up", "tested_surfaces": ["S-0"]}
        for field, value in mutations.items():
            with self.subTest(field=field):
                f.results[1] = {**original, field: value}
                f.save_result(1)
                self.check(1)
        f.results[1] = original
        f.save_result(1)
        f.manifest["target_sha256"] = "f" * 64
        self.check(1, contains="target_sha256 mismatch")

    def test_existing_scope_authorization_is_never_changed(self):
        f = self.fixture
        for field, before, after in (("auth", "- status: granted", "- status: pending"),
                                     ("signoff", "- ready_for_act: true", "- ready_for_act: false")):
            with self.subTest(field=field):
                scope = f.scope_text.replace(before, after)
                f.manifest["scope"] = f.file("scope.md", scope)
                self.check(2, contains="never grants authorization")
                self.assertEqual((f.root / "scope.md").read_text(encoding="utf-8"), scope)

    def test_wrong_scope_case_and_external_case_root(self):
        f = self.fixture
        f.manifest["scope"] = f.file("scope.md", f.scope_text.replace("- case_id: case-coverage", "- case_id: other-case"))
        self.check(1, contains="case_id mismatch")
        other = self.root / "other-case"
        other.mkdir()
        self.check(1, case_root=other, contains="inside the explicit case root")

    def test_not_applicable_needs_reason_evidence_and_regressions(self):
        f = self.fixture
        row = f.manifest["entries"][6]
        row.update(status="not-applicable", reason="Feature absent in this scoped build; absence checked")
        result = self.check(0)
        self.assertEqual((result["summary"]["verified"], result["summary"]["not_applicable"]), (6, 1))
        row["reason"] = ""
        self.check(1, contains="reason")
        row["reason"] = "Absent feature"
        evidence = row["evidence"]
        row["evidence"] = []
        self.check(1, contains="must not be empty")
        row["evidence"] = evidence
        f.results[6]["status"] = "skipped"
        f.save_result(6)
        self.check(2, contains="status=skipped")

    def test_all_referenced_bytes_are_hash_checked(self):
        f = self.fixture
        paths = ["scope.md", "notes/inventory.json", "artifacts/source-0.bin", "artifacts/source-1.bin",
                 "artifacts/main-current.bin", "artifacts/main.patch", "artifacts/main.rollback",
                 "artifacts/spec-1.txt", "artifacts/result-1.json", "artifacts/run-1.log",
                 "artifacts/inventory-review.txt", "artifacts/observation-1.txt", "evidence/E-result-1.md"]
        for relative in paths:
            with self.subTest(path=relative):
                path = f.root / relative
                original = path.read_bytes()
                path.write_bytes(original + b"changed\n")
                self.check(1, contains="SHA-256 mismatch")
                path.write_bytes(original)

    def test_fake_evidence_heading_and_bare_reference(self):
        f = self.fixture
        ref = f.manifest["regression_results"][1]
        path = f.root / ref["path"]
        changed = path.read_text(encoding="utf-8").replace("### E-result-1", "### E-fake")
        ref["sha256"] = f.file(ref["path"], changed)["sha256"]
        self.check(1, contains="heading does not match")
        f.manifest["regression_results"][1] = "T-1"
        self.check(1, contains="must be an object")

    def test_missing_and_unsafe_paths(self):
        f = self.fixture
        row = f.manifest["entries"][1]
        old = row["current"]["path"]
        paths = ["../outside", "/absolute", "C:/absolute", "C:relative", "//host/share", "a\\b",
                 "a/../b", "a/./b", "a//b", "a/", "a:stream", "%2e%2e/outside", "NUL", "CON.txt",
                 "a. /b", "a./b", "a /b", "bad\x00path", "bad\npath", ""]
        for value in paths:
            with self.subTest(path=value):
                row["current"]["path"] = value
                self.check(1)
        row["current"]["path"] = "artifacts/nonexistent.bin"
        self.check(1)
        row["current"]["path"] = old

    def test_symlink_file_and_directory_rejected(self):
        f = self.fixture
        try:
            os.symlink(f.root / "artifacts/source-1.bin", f.root / "linked.bin")
            os.symlink(f.root / "artifacts", f.root / "linked-dir", target_is_directory=True)
        except (OSError, NotImplementedError) as exc:
            self.skipTest(f"symlink creation unavailable: {type(exc).__name__}")
        for relative in ("linked.bin", "linked-dir/source-1.bin"):
            with self.subTest(path=relative):
                f.manifest["entries"][1]["current"]["path"] = relative
                self.check(1, contains="links/reparse points")

    def test_hard_link_rejected(self):
        f = self.fixture
        try:
            os.link(f.root / "artifacts/source-1.bin", f.root / "hard-link.bin")
        except (OSError, NotImplementedError) as exc:
            self.skipTest(f"hard link creation unavailable: {type(exc).__name__}")
        self.check(1, contains="no hard links")

    def test_schema_type_matrix_never_crashes(self):
        f = self.fixture
        original = copy.deepcopy(f.manifest)
        cases = [((), value) for value in (None, [], "text", 1, True)]
        fields = {
            ("schema_version",): [None, [], {}, "2", True],
            ("complete",): [None, [], {}, "true", 1],
            ("case_id",): [None, [], {}, 1], ("target_sha256",): [None, [], {}, 1],
            ("scope",): [None, [], "scope.md", True], ("entries",): [None, {}, "rows", 1],
            ("entries", 0): [None, [], "row", 1],
            ("entries", 0, "status"): [None, [], {}, 1],
            ("entries", 0, "current"): [None, [], "current", 1],
            ("entries", 0, "current", "path"): [None, [], {}, 1],
            ("entries", 0, "current", "sha256"): [None, [], {}, 1],
            ("entries", 0, "changed_at"): [None, [], {}, 1, "2026-99-01T00:00:00Z"],
            ("entries", 0, "evidence"): [None, {}, "E-1", 1],
            ("entries", 0, "patch"): [None, [], "patch", 1],
            ("entries", 0, "rollback"): [None, [], "rollback", 1],
            ("entries", 0, "reason"): [None, [], {}, 1],
            ("regression_results",): [None, {}, "T-0", 1],
        }
        cases.extend((path, value) for path, values in fields.items() for value in values)
        for path, value in cases:
            with self.subTest(path=path, value=value):
                f.manifest = copy.deepcopy(original)
                if not path:
                    f.manifest = value
                else:
                    target = f.manifest
                    for key in path[:-1]:
                        target = target[key]
                    target[path[-1]] = value
                self.check(1)

    def test_inventory_and_result_malformed_types(self):
        f = self.fixture
        saved_inventory = copy.deepcopy(f.inventory)
        mutations = [("review", None), ("surfaces", {}), ("regressions", "tests")]
        for field, value in mutations:
            with self.subTest(inventory_field=field):
                f.inventory = {**saved_inventory, field: value}
                f.seal_inventory()
                self.check(1)
        for field, values in {"neighbors": [None, {}, [[]], ["S-0"]], "regression_ids": [None, {}, [{}]]}.items():
            for value in values:
                with self.subTest(inventory_field=field, value=value):
                    f.inventory = copy.deepcopy(saved_inventory)
                    f.inventory["surfaces"][0][field] = value
                    f.seal_inventory()
                    self.check(1)
        f.inventory = saved_inventory
        f.seal_inventory()
        f.refresh_results()
        original = copy.deepcopy(f.results[0])
        fields = {"status": [None, [], {}, True], "tested_surfaces": [None, {}, [[]], ["S-0", "S-0"]],
                  "executed_at": [None, {}, "bad date"], "evidence": [None, {}, ["E-1"]], "id": [None, {}, []]}
        for field, values in fields.items():
            for value in values:
                with self.subTest(result_field=field, value=value):
                    f.results[0] = {**original, field: value}
                    f.save_result(0)
                    self.check(1)

    def test_duplicate_ids_and_uncovered_neighbors(self):
        f = self.fixture
        original = copy.deepcopy(f.manifest)
        f.manifest["entries"].append(copy.deepcopy(f.manifest["entries"][0]))
        self.check(1, contains="duplicate surface")
        f.manifest = copy.deepcopy(original)
        f.manifest["regression_results"].append(copy.deepcopy(f.manifest["regression_results"][0]))
        self.check(1, contains="duplicate regression result id")
        f.manifest = original
        f.inventory["surfaces"][0]["neighbors"] = ["S-made-up"]
        f.seal_inventory()
        self.check(1, contains="unknown/self neighbor")
        f.inventory["surfaces"][0]["neighbors"] = ["S-1"]
        f.inventory["regressions"][1]["covers"] = ["S-0"]
        f.seal_inventory()
        self.check(1, contains="does not cover this surface")

    def test_invalid_json_utf8_duplicates_constants_and_depth(self):
        payloads = [b"{", b"\xff", b'{"schema_version":2,"schema_version":2}', b'{"schema_version":NaN}',
                    b"[" * 2000 + b"0" + b"]" * 2000, b" " * (2 * 1024 * 1024 + 1)]
        for value in payloads:
            with self.subTest(size=len(value)):
                self.check(1, raw=value)

    def test_commands_in_evidence_are_inert(self):
        f = self.fixture
        marker = f.root / "must-not-exist.txt"
        artifact = f.file("artifacts/command.txt", f"python -c \"open({str(marker)!r}, 'w').write('bad')\"\n")
        ref = f.evidence("E-command", artifact)
        f.manifest["entries"][0]["evidence"].append(ref)
        self.check(0)
        self.assertFalse(marker.exists())
        f.manifest["command"] = "this is not an executable manifest"
        self.check(1, contains="unsupported fields")
        self.assertFalse(marker.exists())


def main():
    global WORK_DIR
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--work-dir", type=Path, help="new directory for retained synthetic fixtures")
    args = parser.parse_args()
    if args.work_dir:
        WORK_DIR = args.work_dir.absolute()
        WORK_DIR.mkdir(parents=True, exist_ok=False)
    else:
        WORK_DIR = Path(tempfile.mkdtemp(prefix="authorization-coverage-tests-")).absolute()
    print(f"Synthetic fixtures retained for inspection/recycling: {WORK_DIR}", flush=True)
    program = unittest.main(argv=[sys.argv[0], "-v"], exit=False)
    return 0 if program.result.wasSuccessful() else 1


if __name__ == "__main__":
    raise SystemExit(main())
