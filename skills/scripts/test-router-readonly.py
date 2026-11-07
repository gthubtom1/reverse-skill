#!/usr/bin/env python3
"""Exercise native routing without any project or route artifacts."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parent


class ReadOnlyRouter(unittest.TestCase):
    def test_native_routes_do_not_create_a_requested_project_or_change_existing_output(self):
        shells = []
        if shutil.which('bash'):
            shells.append(('bash', ['bash', str(SCRIPTS / 'master-route.sh')], ['--hint', 'reconstruction verification', '--primary', 'R46'], '--dry-run', '--project-root', '--out-dir'))
        ps = shutil.which('pwsh') or shutil.which('powershell')
        if ps:
            shells.append(('powershell', [ps, '-NoProfile', '-File', str(SCRIPTS / 'master-route.ps1')], ['-Hint', 'reconstruction verification', '-Primary', 'R46'], '-DryRun', '-ProjectRoot', '-OutDir'))
        self.assertTrue(shells, 'at least one native shell must be available')
        for name, command, route, dry, project, out in shells:
            with self.subTest(shell=name), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                existing = root / 'existing'
                existing.mkdir()
                sentinel = existing / 'route-scope.md'
                sentinel.write_bytes(b'original route\n')
                for target_out in [root / 'new-output', existing]:
                    proc = subprocess.run(command + route + [dry, project, str(root / 'missing-project'), out, str(target_out)], cwd=root, capture_output=True, text=True, timeout=30)
                    self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
                    self.assertIn('PRIMARY -> skills/reconstruction/SKILL.md', proc.stdout)
                    self.assertIn('READ-ONLY', proc.stdout)
                    self.assertNotIn('ACTION:', proc.stdout)
                    self.assertFalse((root / 'missing-project').exists())
                    self.assertFalse((root / 'new-output').exists())
                    self.assertEqual(sentinel.read_bytes(), b'original route\n')
                bad = subprocess.run(command + [dry, ('--primary' if name == 'bash' else '-Primary'), 'R999'], cwd=root, capture_output=True, text=True, timeout=30)
                self.assertNotEqual(bad.returncode, 0)
                self.assertEqual(sorted(p.name for p in root.iterdir()), ['existing'])


if __name__ == '__main__':
    unittest.main()
