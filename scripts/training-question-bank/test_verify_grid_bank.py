"""Build-gate regressions against a disposable copy of the real bundled bank."""
import contextlib
import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import textwrap
import unittest
from unittest.mock import patch

import verify_grid_bank as gate


class GridGateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.manifest_path = self.root / 'QiuJi/Resources/training-grid-bank-manifest.json'
        manifest = json.loads((gate.ROOT / self.manifest_path.relative_to(self.root)).read_text())
        for name in [*manifest['physicalSourceHashes'],
                     'QiuJi/Resources/training-grid-bank.json',
                     'QiuJi/Resources/training-grid-bank-manifest.json']:
            dest = self.root / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(gate.ROOT / name, dest)
        self.patch = patch.object(gate, 'ROOT', self.root)
        self.patch.start()
        self.addCleanup(self.patch.stop)

    def verify(self, strict=False):
        with contextlib.redirect_stdout(io.StringIO()) as output:
            gate.verify(strict)
        return output.getvalue()

    def change(self, path, old, new):
        p = self.root / path
        text = p.read_text()
        self.assertIn(old, text)
        p.write_text(text.replace(old, new, 1))

    def test_current_layout_passes_but_reports_stale_physics(self):
        self.assertIn('Historical physics qualification is stale', self.verify())
        with self.assertRaisesRegex(AssertionError, 'replay required'):
            self.verify(strict=True)

    def test_matching_physics_is_not_reported_as_a_new_replay(self):
        # Synthetic matching fixture only; never updates the production manifest.
        m = json.loads(self.manifest_path.read_text())
        m['physicalSourceHashes'] = {p: hashlib.sha256((self.root / p).read_bytes()).hexdigest()
                                    for p in m['physicalSourceHashes']}
        self.manifest_path.write_text(json.dumps(m))
        self.assertIn('no new physics replay performed', self.verify(strict=True))

    def test_bank_corruption_is_rejected(self):
        p = self.root / 'QiuJi/Resources/training-grid-bank.json'
        p.write_bytes(p.read_bytes() + b' ')
        with self.assertRaisesRegex(AssertionError, 'Bank bytes changed'):
            self.verify()

    def test_geometry_source_drift_is_rejected(self):
        p = self.root / gate.GEOMETRY_SOURCES[0]
        p.write_text(p.read_text() + '\n// changed\n')
        with self.assertRaisesRegex(AssertionError, 'Layout geometry changed'):
            self.verify()

    def test_reviewed_geometry_binding_still_rejects_drift(self):
        p = self.root / 'QiuJi/Core/Scene/AngleSceneCalculator.swift'
        p.write_text(p.read_text() + '\n// drift after reviewed extraction\n')
        with self.assertRaisesRegex(AssertionError, 'Layout geometry changed'):
            self.verify()

    def test_ball_table_and_pocket_dimension_changes_are_rejected(self):
        p = self.root / 'QiuJi/Core/Physics/BTPhysicsConstants.swift'
        original = p.read_text()
        for old, new in [('0.05715', '0.06000'), ('2.540', '2.600'), ('0.084', '0.090')]:
            with self.subTest(dimension=old):
                p.write_text(original.replace(old, new, 1))
                with self.assertRaisesRegex(AssertionError, 'Layout geometry constant changed'):
                    self.verify()
        p.write_text(original)

    def test_physics_coefficient_change_does_not_invalidate_layout(self):
        self.change('QiuJi/Core/Physics/BTPhysicsConstants.swift',
                    'pocketNoseRestitution: Float = 0.75', 'pocketNoseRestitution: Float = 0.76')
        self.assertIn('integrity and layout geometry verified', self.verify())

    def test_missing_geometry_binding_is_rejected(self):
        m = json.loads(self.manifest_path.read_text())
        del m['physicalSourceHashes'][gate.GEOMETRY_SOURCES[0]]
        self.manifest_path.write_text(json.dumps(m))
        with self.assertRaises(KeyError):
            self.verify()


class BuildWiringTests(unittest.TestCase):
    def test_both_build_configs_always_use_integrity_gate(self):
        expected = ('set -e\n'
                    '/usr/bin/python3 "$SRCROOT/scripts/training-question-bank/verify_grid_bank.py"\n'
                    '/usr/bin/python3 "$SRCROOT/scripts/verify_pocket_pipe_table.py"\n')
        spec = (gate.ROOT / 'project.yml').read_text()
        body = spec.split('name: Verify training question bank', 1)[1].split('    sources:', 1)[0]
        self.assertEqual(textwrap.dedent(body.split('script: |\n', 1)[1]), expected)
        self.assertNotIn('TRAINING_BANK_REVALIDATION', body)
        project = json.loads(subprocess.check_output([
            'plutil', '-convert', 'json', '-o', '-',
            str(gate.ROOT / 'QiuJi.xcodeproj/project.pbxproj')]))
        scripts = [x['shellScript'] for x in project['objects'].values()
                   if x.get('name') == 'Verify training question bank']
        self.assertEqual(scripts, [expected])


if __name__ == '__main__':
    unittest.main()
