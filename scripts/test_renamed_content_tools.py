"""Exercise the actual content CLIs in an isolated CuePhys layout."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


class RenamedContentToolsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.resources = self.root / "CuePhys/Resources"
        (self.resources / "Drills/accuracy").mkdir(parents=True)
        (self.root / "scripts").mkdir()
        for name in ("tutorial_copy_facts.py", "tutorial_digest.py", "import-engine-export-to-app.py"):
            shutil.copy2(Path(__file__).parent / name, self.root / "scripts" / name)
        self.write("CuePhys/Resources/Drills/index.json", {"categories": [{"drills": ["drill_c001"]}]})
        self.write("CuePhys/Resources/Drills/accuracy/drill_c001.json", {
            "id": "drill_c001", "nameZh": "路径夹具", "standardCriteria": "", "sets": {},
            "tutorial": {"sections": [{"image": "drill_c001_initial"}]}})
        self.sequence = {"name": "路径夹具", "steps": []}
        self.write("content/position_play/sequences/drill_c001__manual01-fixture.json", self.sequence)
        path = self.root / "docs/research/20260819-动作库球形训练意图.md"
        path.parent.mkdir(parents=True)
        path.write_text("fixture\n")

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, name, value):
        p = self.root / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(json.dumps(value))

    def run_tool(self, name, *args):
        return subprocess.run([sys.executable, str(self.root / "scripts" / name), *args],
                              text=True, capture_output=True, cwd=self.root)

    def test_import_then_fact_collection_reads_current_paths_and_preserves_content(self):
        export = self.root / "build/position_play_export/drill_c001__manual01-fixture"
        export.mkdir(parents=True)
        # These tools only copy/hash images; native image decoding is tested separately.
        data = b"image-copy-fixture"
        (export / "initial.png").write_bytes(data)
        self.write(str((export / "render-input.json").relative_to(self.root)), {
            "sequence": self.sequence, "framesSHA256": {"initial.png": hashlib.sha256(data).hexdigest()}})
        drill = self.resources / "Drills/accuracy/drill_c001.json"
        original = drill.read_bytes()
        for _ in range(2):
            result = self.run_tool("import-engine-export-to-app.py", "--stills-only", "--skip-publish")
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.resources / "DrillTutorials/drill_c001_initial.png").read_bytes(), data)
        self.assertEqual(drill.read_bytes(), original)
        figures = self.resources / "TutorialFigures"
        figures.mkdir()
        (figures / "drill_c001_initial.heic").write_bytes(b"published-fixture")
        result = self.run_tool("tutorial_copy_facts.py", "--output", str(self.root / "facts"))
        self.assertEqual(result.returncode, 0, result.stderr)
        facts = json.loads((self.root / "facts/drill_c001/facts.json").read_text())
        self.assertEqual(facts["source"], "CuePhys/Resources/Drills/accuracy/drill_c001.json")
        self.assertEqual(len(facts["formations"][0]["images"]), 1)
        self.assertFalse((self.root / "QiuJi").exists())

    def test_missing_export_is_a_real_failure(self):
        result = self.run_tool("import-engine-export-to-app.py", "--stills-only", "--skip-publish")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / "QiuJi").exists())


if __name__ == "__main__":
    unittest.main()
