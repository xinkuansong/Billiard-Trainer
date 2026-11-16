import tempfile
import unittest
from pathlib import Path

from verify_model_packaging import CURRENT, bundle_problems, config_problems


class ModelPackagingTests(unittest.TestCase):
    def setUp(self):
        root = Path(__file__).resolve().parents[1]
        self.spec = (root / "project.yml").read_text()
        self.pbx = (root / "QiuJi.xcodeproj/project.pbxproj").read_text()

    def test_current_configs(self):
        self.assertEqual(config_problems(self.spec, self.pbx), [])

    def test_lost_source_exclusion(self):
        spec = self.spec.replace('- "Resources/TaiQiuZhuo.usdz"', '')
        self.assertTrue(config_problems(spec, self.pbx))

    def test_explicit_source_reintroduction(self):
        spec = self.spec + '\n      - path: QiuJi/Resources/TaiQiuZhuo.usdz\n'
        self.assertTrue(config_problems(spec, self.pbx))

    def test_stale_generated_project(self):
        pbx = self.pbx + '\n/* TaiQiuZhuo.usdz in Resources */\n'
        self.assertTrue(config_problems(self.spec, pbx))

    def test_missing_production_reference(self):
        pbx = self.pbx.replace(f'/* {CURRENT[0]} in Resources */', '')
        self.assertTrue(config_problems(self.spec, pbx))

    def test_bundle_and_nested_legacy_resource(self):
        with tempfile.TemporaryDirectory() as folder:
            bundle = Path(folder)
            self.assertTrue(bundle_problems(bundle))
            for name in CURRENT:
                (bundle / name).write_bytes(b'fixture')
            self.assertEqual(bundle_problems(bundle), [])
            (bundle / "CueStyles").mkdir()
            (bundle / "CueStyles/CueUV.usdz").write_bytes(b'fixture')
            self.assertTrue(bundle_problems(bundle))


if __name__ == "__main__":
    unittest.main()
