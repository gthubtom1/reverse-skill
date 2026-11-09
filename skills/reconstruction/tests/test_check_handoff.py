"""Synthetic negative controls for pointer integrity and explicit semantic limits.

Temporary writes are confined to this skill's tests directory. No target, network,
REA or Spec Kit is invoked. The subprocess tests run only check_handoff.py.
"""

import copy
import hashlib
import importlib.util
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


sys.dont_write_bytecode = True
SKILL = Path(__file__).resolve().parents[1]
SCRIPT = SKILL / "scripts" / "check_handoff.py"
EXAMPLE = SKILL / "examples" / "synthetic-project"
MANIFEST = "case-fixture/demo/notes/handoff-manifest.json"
SPEC = "specs/001-literal-v1/spec.md"
EVIDENCE = "case-fixture/demo/evidence/E-001.md"
BUNDLE = "case-fixture/demo/evidence/synthetic-bundle.json"
OBLIGATIONS = "case-fixture/demo/evidence/synthetic-obligations.json"
module_spec = importlib.util.spec_from_file_location("check_handoff", SCRIPT)
handoff = importlib.util.module_from_spec(module_spec)
module_spec.loader.exec_module(handoff)


class HandoffTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="handoff-", dir=Path(__file__).parent)
        self.addCleanup(self.temp.cleanup)
        self.area = Path(self.temp.name)
        self.root = self.area / "project"
        shutil.copytree(EXAMPLE, self.root)
        self.manifest = json.loads((self.root / MANIFEST).read_text(encoding="utf-8"))

    @property
    def req(self):
        return self.manifest["requirements"][0]

    def write_text(self, relative, text):
        with (self.root / relative).open("w", encoding="utf-8", newline="") as stream:
            stream.write(text)

    def update_ref(self, ref):
        ref["sha256"] = hashlib.sha256((self.root / ref["path"]).read_bytes()).hexdigest()

    def save(self):
        self.write_text(MANIFEST, json.dumps(self.manifest, indent=2))

    def check(self):
        self.save()
        return handoff.check_handoff(self.root, MANIFEST)

    def assert_failure(self, report, code):
        self.assertEqual(report["status"], "FAIL", report)
        self.assertEqual(report["issues"][0]["code"], code, report)
        self.assertEqual(report["assessment_scope"], "machine_check_only")
        self.assertEqual(report["semantic_verification"], "not_performed")

    def cli(self, *args):
        return subprocess.run([sys.executable, "-B", str(SCRIPT), *map(str, args)],
                              cwd=self.root, capture_output=True, text=True, encoding="utf-8", timeout=15)

    def test_supplied_example_has_real_matching_commitments(self):
        report = handoff.check_handoff(EXAMPLE, MANIFEST)
        self.assertEqual(report["status"], "PASS", report)
        self.assertEqual(report["assessment_scope"], "machine_check_only")
        self.assertEqual(report["authorization"], "not_assessed")
        self.assertEqual(report["target_execution"], "not_performed")
        self.assertEqual(report["semantic_verification"], "not_performed")
        self.assertEqual([item["fr_id"] for item in report["semantic_review_required"]], ["FR-001"])

    def test_bundle_tampering_rejected(self):
        self.write_text(BUNDLE, '{"tampered": true}')
        self.assert_failure(self.check(), "sha256.mismatch")

    def test_stale_sha_for_spec_or_obligation_document_rejected(self):
        for pick in (lambda m: m["feature_refs"]["spec"],
                     lambda m: m["requirements"][0]["obligation_ref"]["document_ref"]):
            with self.subTest(ref=pick(self.manifest)["path"]):
                ref = pick(self.manifest)
                old = ref["sha256"]
                ref["sha256"] = "0" * 64
                self.assert_failure(self.check(), "sha256.mismatch")
                ref["sha256"] = old

    def test_sha_format_is_exact(self):
        ref = self.manifest["feature_refs"]["spec"]
        for value in ("sha256:" + "a" * 64, "A" * 64, "a" * 63, None, 42):
            with self.subTest(value=value):
                ref["sha256"] = value
                self.assert_failure(self.check(), "sha256.invalid")

    def test_absolute_drive_uri_unc_and_traversal_rejected(self):
        ref = self.manifest["bundle_refs"][0]
        for path in ("../outside.json", "/tmp/outside.json", "C:/outside.json", "C:outside.json",
                     "//server/share/file.json", "file:///tmp/a.json", "work\\demo\\a.json",
                     "work/./demo/a.json", "work//demo/a.json", "work/demo/../a.json", "a\x00.json"):
            with self.subTest(path=path):
                ref["path"] = path
                self.assert_failure(self.check(), "path.relative")

    def test_manifest_itself_must_be_relative_and_contained(self):
        self.assert_failure(handoff.check_handoff(self.root, "../outside.json"), "path.relative")
        self.assert_failure(handoff.check_handoff(self.root, str(self.root / MANIFEST)), "path.relative")

    def test_symlink_escape_rejected(self):
        outside = self.area / "outside.json"
        outside.write_text("{}", encoding="utf-8")
        link = self.root / "escape.json"
        try:
            link.symlink_to(outside)
        except (OSError, NotImplementedError) as exc:
            self.skipTest("Platform does not permit symlink creation: " + str(exc))
        ref = self.manifest["bundle_refs"][0]
        ref["path"] = "escape.json"
        ref["sha256"] = hashlib.sha256(outside.read_bytes()).hexdigest()
        self.assert_failure(self.check(), "path.outside_root")

    def test_evidence_record_is_required_not_just_id_text(self):
        (self.root / EVIDENCE).unlink()
        self.assert_failure(self.check(), "path.missing")

    def test_empty_evidence_refs_rejected(self):
        self.req["evidence_refs"] = []
        self.assert_failure(self.check(), "input.list")

    def test_changed_original_artifact_rejected_even_with_unchanged_record(self):
        self.write_text("case-fixture/demo/evidence/observation.md", "Unapproved replacement observation")
        self.assert_failure(self.check(), "evidence.artifact_sha256")

    def test_evidence_artifact_must_stay_inside_case(self):
        text = (self.root / EVIDENCE).read_text(encoding="utf-8")
        text = text.replace("evidence/observation.md", "../observation.md")
        self.write_text(EVIDENCE, text)
        self.update_ref(self.req["evidence_refs"][0]["record_ref"])
        self.assert_failure(self.check(), "path.relative")

    def test_evidence_record_cannot_be_substituted_by_copy_in_notes(self):
        self.write_text("case-fixture/demo/notes/E-001.md", (self.root / EVIDENCE).read_text(encoding="utf-8"))
        self.req["evidence_refs"][0]["record_ref"]["path"] = "case-fixture/demo/notes/E-001.md"
        self.assert_failure(self.check(), "evidence.record")

    def test_wrong_evidence_heading_rejected(self):
        text = (self.root / EVIDENCE).read_text(encoding="utf-8").replace("### E-001", "### E-002")
        self.write_text(EVIDENCE, text)
        self.update_ref(self.req["evidence_refs"][0]["record_ref"])
        self.assert_failure(self.check(), "evidence.heading")

    def test_missing_and_duplicate_fr_mapping_rejected(self):
        self.write_text(SPEC, (self.root / SPEC).read_text(encoding="utf-8") + "\n- **FR-002**: Another selected behavior.\n")
        self.update_ref(self.manifest["feature_refs"]["spec"])
        self.assert_failure(self.check(), "fr.unmapped")
        self.manifest["requirements"].append(copy.deepcopy(self.req))
        self.assert_failure(self.check(), "fr.duplicate")

    def test_fr_must_belong_to_selected_feature(self):
        self.req["fr_id"] = "FR-999"
        self.assert_failure(self.check(), "fr.reference")

    def test_feature_must_not_mix_frozen_old_and_new_documents(self):
        path = "specs/002-literal-v2/plan.md"
        (self.root / path).parent.mkdir()
        shutil.copyfile(self.root / "specs/001-literal-v1/plan.md", self.root / path)
        self.manifest["feature_refs"]["plan"]["path"] = path
        self.assert_failure(self.check(), "feature.reference")

    def test_context_cannot_point_to_other_case(self):
        path = "case-fixture/other/scope.md"
        (self.root / path).parent.mkdir()
        shutil.copyfile(self.root / "case-fixture/demo/scope.md", self.root / path)
        self.manifest["context_refs"]["scope"]["path"] = path
        self.assert_failure(self.check(), "case.reference")

    def test_critical_unknown_blocks_selected_fr(self):
        self.req["unknown_refs"][0]["critical"] = True
        report = self.check()
        self.assert_failure(report, "unknown.critical_open")
        self.assertIn("FR-001", report["issues"][0]["message"])

    def test_noncritical_unknown_remains_reference_with_review(self):
        self.assertEqual(self.check()["status"], "PASS")
        del self.req["unknown_refs"]
        self.assert_failure(self.check(), "input.fields")

    def test_unknown_pointer_and_boolean_are_required(self):
        ref = self.req["unknown_refs"][0]
        ref["pointer"] = "/unknowns/9"
        self.assert_failure(self.check(), "pointer.missing")
        ref["pointer"] = "/unknowns/0"
        ref["critical"] = "false"
        self.assert_failure(self.check(), "unknown.critical")

    def test_unknown_pointer_must_select_an_object_not_null_or_scalar(self):
        for value in (None, "unknown", [], {}):
            with self.subTest(value=value):
                self.write_text(BUNDLE, json.dumps({"unknowns": [value]}))
                self.update_ref(self.manifest["bundle_refs"][0])
                self.update_ref(self.req["unknown_refs"][0]["document_ref"])
                self.assert_failure(self.check(), "unknown.identity")

    def test_obligation_pointer_must_resolve_identity_and_revision(self):
        ref = self.req["obligation_ref"]
        ref["pointer"] = "/obligations/9"
        self.assert_failure(self.check(), "pointer.missing")
        ref["pointer"] = "/obligations/0"
        for body in ({"obligation_id": "x"}, {"obligation_id": "", "obligation_version": 1},
                     {"obligation_id": "x", "obligation_version": True},
                     {"obligation_id": "x", "obligation_version": 0}):
            with self.subTest(body=body):
                self.write_text(OBLIGATIONS, json.dumps({"obligations": [body]}))
                self.update_ref(ref["document_ref"])
                self.assert_failure(self.check(), "obligation.identity")

    def test_obligation_ref_cannot_be_omitted(self):
        del self.req["obligation_ref"]
        self.assert_failure(self.check(), "input.fields")

    def test_rfc6901_escapes_and_invalid_array_indices(self):
        self.write_text(OBLIGATIONS, json.dumps({"a/b~c": [{"obligation_id": "synthetic", "obligation_version": 1}]}))
        ref = self.req["obligation_ref"]
        self.update_ref(ref["document_ref"])
        ref["pointer"] = "/a~1b~0c/0"
        self.assertEqual(self.check()["status"], "PASS")
        for pointer in ("/a~2b/0", "", "a/b/0", "/a~1b~0c/00", "/a~1b~0c/-"):
            with self.subTest(pointer=pointer):
                ref["pointer"] = pointer
                self.assertEqual(self.check()["status"], "FAIL")

    def test_no_status_database_or_self_asserted_outcome_fields(self):
        self.req["status"] = "ready"
        self.assert_failure(self.check(), "input.fields")

    def test_malformed_json_duplicate_keys_and_types_fail_closed(self):
        for text in ("{", '{"manifest_version":1,"manifest_version":1}', "[]", "null"):
            with self.subTest(text=text):
                self.write_text(MANIFEST, text)
                report = handoff.check_handoff(self.root, MANIFEST)
                self.assertEqual(report["status"], "FAIL", report)
        self.req["source_kind"] = []
        self.assert_failure(self.check(), "fr.source_kind")

    def test_semantic_miscitation_can_pass_mechanics_but_requires_review(self):
        observation = (self.root / "case-fixture/demo/evidence/observation.md").read_text(encoding="utf-8")
        self.assertIn("exit code 2", observation)
        text = (self.root / SPEC).read_text(encoding="utf-8").replace("exit code 2", "exit code 0")
        self.write_text(SPEC, text)
        self.update_ref(self.manifest["feature_refs"]["spec"])
        report = self.check()
        self.assertEqual(report["status"], "PASS", report)
        self.assertEqual(report["semantic_verification"], "not_performed")
        self.assertTrue(report["semantic_review_required"])
        self.assertTrue(any("authority" in item["required"] for item in report["semantic_review_required"]))
        # The deliberately wrong spec must be rejected by independent review of
        # these two texts. This checker does not contain an invented semantic evaluator.
        self.assertNotIn("exit code 0", observation)

    def test_omitted_unknowns_and_source_qualification_need_semantic_review(self):
        self.req["unknown_refs"] = []
        for kind in ("observed", "inferred", "unknown", "designed"):
            with self.subTest(kind=kind):
                self.req["source_kind"] = kind
                report = self.check()
                self.assertEqual(report["status"], "PASS", report)
                self.assertEqual(report["semantic_verification"], "not_performed")
                self.assertTrue(any("omitted" in text for text in report["limitations"]))

    def test_cli_never_executes_commands_or_writes_project(self):
        marker = self.root / "must-not-exist.md"
        text = (self.root / EVIDENCE).read_text(encoding="utf-8").replace(
            "- repro_command: n/a", "- repro_command: python -c \"open('must-not-exist.md','w').write('executed')\"")
        self.write_text(EVIDENCE, text)
        self.update_ref(self.req["evidence_refs"][0]["record_ref"])
        self.save()
        before = {p.relative_to(self.root): p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        result = self.cli(self.root, MANIFEST)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(marker.exists())
        after = {p.relative_to(self.root): p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        self.assertEqual(before, after)
        self.assertEqual(json.loads(result.stdout)["target_execution"], "not_performed")

    def test_cli_success_failure_and_markdown(self):
        result = self.cli(self.root, MANIFEST)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["assessment_scope"], "machine_check_only")
        result = self.cli(self.root, MANIFEST, "--format", "markdown")
        self.assertEqual(result.returncode, 0)
        self.assertIn("semantic_verification: not_performed", result.stdout)
        self.req["unknown_refs"][0]["critical"] = True
        self.save()
        result = self.cli(self.root, MANIFEST)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(json.loads(result.stdout)["issues"][0]["code"], "unknown.critical_open")
        result = self.cli(self.root, "missing.json")
        self.assertEqual(result.returncode, 1)

    def test_backend_receipt_cannot_replace_scope_or_obligation_with_ready(self):
        # A syntactically valid, hash-pinned synthetic backend receipt is still
        # neither the original scope nor an obligation production-chain result.
        # This imitation is deliberately not an actual AcceptedResearch schema.
        receipt = "case-fixture/demo/notes/backend-result.json"
        self.write_text(receipt, json.dumps({"contract_version": 1, "status": "Ready",
                                             "candidate": True, "accepted": True}))
        ref = {"path": receipt}
        self.update_ref(ref)
        original = copy.deepcopy(self.manifest["context_refs"]["scope"])
        self.manifest["context_refs"]["scope"] = ref
        self.assert_failure(self.check(), "case.reference")
        self.manifest["context_refs"]["scope"] = original
        self.req["obligation_ref"] = {"document_ref": ref, "pointer": "/status"}
        self.assert_failure(self.check(), "obligation.identity")

    def test_backend_resolved_or_ready_cannot_close_referenced_critical_unknown(self):
        # Even when bytes and commitments agree, a backend state string must
        # not override the explicit critical dependency in the original handoff.
        self.req["unknown_refs"][0]["critical"] = True
        body = json.loads((self.root / BUNDLE).read_text(encoding="utf-8"))
        body["unknowns"][0].update({"status": "resolved", "backend_status": "Ready"})
        self.write_text(BUNDLE, json.dumps(body))
        self.update_ref(self.manifest["bundle_refs"][0])
        self.update_ref(self.req["unknown_refs"][0]["document_ref"])
        self.assert_failure(self.check(), "unknown.critical_open")

    def test_candidate_extensions_cannot_smuggle_scope_or_ledger_authority(self):
        # No backend manifest extension is supported. Keep the existing reader
        # fail-closed instead of silently discarding unfamiliar authority claims.
        for key, value in (("external_backend", {"contract_version": 1, "scope_override": True}),
                           ("ledger", {"ready": True, "required_open": 0}),
                           ("accepted", True), ("status", "Ready")):
            with self.subTest(key=key):
                self.manifest[key] = value
                self.assert_failure(self.check(), "input.fields")
                del self.manifest[key]
        report = self.check()
        self.assertEqual(report["status"], "PASS", report)
        self.assertEqual(report["authorization"], "not_assessed")
        self.assertEqual(report["semantic_verification"], "not_performed")
        self.assertNotIn("accepted", report)

    def test_changed_task_baseline_invalidates_handoff_commitment(self):
        tasks = self.root / self.manifest["feature_refs"]["tasks"]["path"]
        tasks.write_text(tasks.read_text(encoding="utf-8") + "\n- [ ] T999 Unaccepted new task\n",
                         encoding="utf-8")
        self.assert_failure(self.check(), "sha256.mismatch")

    def test_cli_argument_errors_and_help(self):
        for args in ((), (self.root,), (self.root, MANIFEST, "--format", "yaml"),
                     (self.root, MANIFEST, "--execute")):
            with self.subTest(args=args):
                result = self.cli(*args)
                self.assertEqual(result.returncode, 2)
                self.assertIn("usage:", result.stderr)
        result = self.cli("--help")
        self.assertEqual(result.returncode, 0)
        self.assertIn("machine_check_only", result.stdout)


if __name__ == "__main__":
    unittest.main()
