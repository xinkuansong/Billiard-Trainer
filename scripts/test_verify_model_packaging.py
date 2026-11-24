import tempfile
import unittest
import zipfile
from pathlib import Path

from verify_model_packaging import CURRENT, attribute_problems, bundle_problems, config_problems, model_problems


class ModelPackagingTests(unittest.TestCase):
    def setUp(self):
        root = Path(__file__).resolve().parents[1]
        self.spec = (root / "project.yml").read_text()
        self.pbx = (root / "CuePhys.xcodeproj/project.pbxproj").read_text()
        self.attributes = (root / ".gitattributes").read_text()

    def test_current_configs(self):
        self.assertEqual(config_problems(self.spec, self.pbx), [])

    def test_lost_source_exclusion(self):
        spec = self.spec.replace('- "Resources/TaiQiuZhuo.usdz"', '')
        self.assertTrue(config_problems(spec, self.pbx))

    def test_explicit_source_reintroduction(self):
        spec = self.spec + '\n      - path: CuePhys/Resources/TaiQiuZhuo.usdz\n'
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
                with zipfile.ZipFile(bundle / name, "w") as archive:
                    archive.writestr("model.usda", '#usda 1.0\ndef Xform "Table" {}\n')
            self.assertEqual(bundle_problems(bundle), [])
            (bundle / "CueStyles").mkdir()
            (bundle / "CueStyles/CueUV.usdz").write_bytes(b'fixture')
            self.assertTrue(bundle_problems(bundle))

    def test_rename_must_update_lfs_rules(self):
        self.assertEqual(attribute_problems(self.attributes), [])
        self.assertEqual(len(attribute_problems(self.attributes.replace("CuePhys/", "QiuJi/"))), 3)

    def test_lfs_pointer_in_source_or_bundle_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            bundle = Path(folder)
            for name in CURRENT:
                (bundle / name).write_text("version https://git-lfs.github.com/spec/v1\noid sha256:" + "0" * 64 + "\nsize 100\n")
            problems = bundle_problems(bundle)
            self.assertEqual(len(problems), 2)
            self.assertTrue(all("Unresolved Git LFS pointer" in problem for problem in problems))
            self.assertIn("Unresolved Git LFS pointer", model_problems(bundle / CURRENT[0])[0])

    def test_invalid_archive_and_missing_scene_are_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / CURRENT[0]
            path.write_bytes(b"not a model")
            self.assertIn("Invalid USDZ", model_problems(path)[0])
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("image.png", b"fixture")
            self.assertIn("no USD scene", model_problems(path)[0])

    def test_corrupt_scene_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / CURRENT[0]
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("model.usda", b"#usda 1.0\n")
            path.write_bytes(path.read_bytes().replace(b"#usda 1.0", b"#usda 2.0"))
            self.assertIn("CRC failure", model_problems(path)[0])


if __name__ == "__main__":
    unittest.main()
