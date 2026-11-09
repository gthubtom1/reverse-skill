"""Run the real native router: backend selection must not create a PRIMARY/case.

Only disposable fixture directories under this worktree are used. No model,
provider, Craft process, config, case-init or bootstrap is invoked.
"""

import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


TESTS = Path(__file__).resolve().parent
SCRIPTS = TESTS.parents[1] / "scripts"
ROOT = TESTS.parents[2]
DESCRIPTOR = "skills/reconstruction/references/execution-backend-contract.json"
CASES = json.loads((TESTS / "fixtures" / "backend-routing.json").read_text(encoding="utf-8"))


class BackendRoutingTests(unittest.TestCase):
    def assert_required_hashes(self, root, descriptor):
        # Test-only integrity assertion, not an installer reader or authorization
        # validator. The installer owns strict parsing and containment checks.
        for ref in descriptor["required_files"]:
            self.assertEqual(set(ref), {"path", "sha256"})
            self.assertRegex(ref["sha256"], r"^[0-9a-f]{64}$")
            self.assertEqual(hashlib.sha256((root / ref["path"]).read_bytes()).hexdigest(),
                             ref["sha256"], ref["path"])

    def test_capability_descriptor_binds_final_files_and_local_minor_version(self):
        descriptor = json.loads((ROOT / DESCRIPTOR).read_text(encoding="utf-8"))
        self.assertEqual(set(descriptor), {"schema_version", "contract_id", "contract_version",
                                           "min_reverse_version", "capabilities", "required_files"})
        for key in ("schema_version", "contract_version"):
            self.assertIs(type(descriptor[key]), int)
            self.assertEqual(descriptor[key], 1)
        self.assertEqual(descriptor["contract_id"], "reverse.r46.execution-backend")
        self.assertEqual(descriptor["min_reverse_version"], "1.9.0")
        version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
        self.assertRegex(version, r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")
        self.assertGreaterEqual(tuple(map(int, version.split("."))),
                                tuple(map(int, descriptor["min_reverse_version"].split("."))))
        caps = descriptor["capabilities"]
        self.assertEqual(len(caps), len(set(caps)))
        self.assertEqual(set(caps), {"r46.accepted-research-v1", "r46.single-implementation-owner-v1",
                                    "r46.bounded-pi-builder-v1", "r46.candidate-independent-acceptance-v1"})
        paths = [ref["path"] for ref in descriptor["required_files"]]
        self.assertEqual(len(paths), len(set(paths)))
        self.assertEqual(set(paths), {"skills/reconstruction/references/execution-backend.md",
                                     "skills/reconstruction/SKILL.md", "skills/ops/role-map.md",
                                     "skills/reconstruction/references/spec-kit-workflow.md"})
        self.assertNotIn(DESCRIPTOR, paths)
        self.assert_required_hashes(ROOT, descriptor)

    def test_descriptor_missing_file_or_hash_fails_integrity_assertion(self):
        descriptor = json.loads((ROOT / DESCRIPTOR).read_text(encoding="utf-8"))
        missing_hash = copy.deepcopy(descriptor)
        del missing_hash["required_files"][0]["sha256"]
        with self.assertRaises(AssertionError):
            self.assert_required_hashes(ROOT, missing_hash)
        with tempfile.TemporaryDirectory(prefix="descriptor-missing-", dir=TESTS) as tmp:
            with self.assertRaises(FileNotFoundError):
                self.assert_required_hashes(Path(tmp), descriptor)

    def test_descriptor_digest_drift_fails_without_changing_source(self):
        descriptor = json.loads((ROOT / DESCRIPTOR).read_text(encoding="utf-8"))
        with tempfile.TemporaryDirectory(prefix="descriptor-drift-", dir=TESTS) as tmp:
            root = Path(tmp)
            for ref in descriptor["required_files"]:
                path = root / ref["path"]
                path.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / ref["path"], path)
            self.assert_required_hashes(root, descriptor)
            path = root / descriptor["required_files"][0]["path"]
            with path.open("ab") as stream:
                stream.write(b"\nUnaccepted drift\n")
            with self.assertRaises(AssertionError):
                self.assert_required_hashes(root, descriptor)

    def test_backend_terms_preserve_native_primary_and_read_only_boundary(self):
        shells = []
        if os.name != "nt" and shutil.which("bash"):
            shells.append((["bash", str(SCRIPTS / "master-route.sh")],
                           ["--dry-run"], "--hint", "--project-root", "--out-dir"))
        ps = (shutil.which("powershell") or shutil.which("pwsh")) if os.name == "nt" else shutil.which("pwsh")
        if ps:
            shells.append(([ps, "-NoProfile", "-File", str(SCRIPTS / "master-route.ps1")],
                           ["-DryRun"], "-Hint", "-ProjectRoot", "-OutDir"))
        self.assertTrue(shells, "At least one native router shell is required")
        for command, dry, hint, project, out in shells:
            with tempfile.TemporaryDirectory(prefix="backend-route-", dir=TESTS) as tmp:
                root = Path(tmp)
                existing = root / "existing"
                existing.mkdir()
                sentinel = existing / "route-scope.md"
                sentinel.write_bytes(b"original authority\n")
                for case in CASES:
                    with self.subTest(shell=command[0], hint=case["hint"]):
                        result = subprocess.run(
                            command + dry + [hint, case["hint"], project, str(root / "missing-project"),
                                             out, str(existing)],
                            cwd=root, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=30)
                        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                        self.assertIn("PRIMARY -> skills/" + case["primary"] + "/SKILL.md", result.stdout)
                        self.assertIn("READ-ONLY", result.stdout)
                        self.assertNotIn("ACTION:", result.stdout)
                        self.assertFalse((root / "missing-project").exists())
                        self.assertEqual(sentinel.read_bytes(), b"original authority\n")
                        self.assertEqual(sorted(p.relative_to(root).as_posix() for p in root.rglob("*")),
                                         ["existing", "existing/route-scope.md"])


if __name__ == "__main__":
    unittest.main()
