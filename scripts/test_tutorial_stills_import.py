"""Static tutorial imports preserve other media and remain covered by C2."""
import importlib.util
import tempfile
import json
import sys
from unittest.mock import patch
import unittest
from pathlib import Path

import verify_tutorial_sync as verifier

spec = importlib.util.spec_from_file_location(
    "importer", Path(__file__).with_name("import-engine-export-to-app.py")
)
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)


class ImportScopeTests(unittest.TestCase):
    def configure(self, root):
        importer.TUTORIALS_ROOT = root / "masters"
        importer.VIDEOS_ROOT = root / "videos"
        importer.PREVIEWS_ROOT = root / "previews"

    def test_stills_only_preserves_videos_and_preview(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "source"
            source.mkdir()
            for name in ["initial.png", "s01_still.png", "final.png", "full.mp4", "cover.png"]:
                (source / name).write_bytes(name.encode())
            (source / "preview").mkdir()
            (source / "preview/frame_01.png").write_bytes(b"new")
            self.configure(root)
            video = importer.VIDEOS_ROOT / "drill_c001/full.mp4"
            video.parent.mkdir(parents=True)
            video.write_bytes(b"old video")
            entries = importer.import_one(source, "drill_c001", "manual01", True, False, True)
            self.assertEqual(entries, [])
            self.assertEqual(video.read_bytes(), b"old video")
            self.assertFalse(importer.PREVIEWS_ROOT.exists())
            self.assertEqual(
                {p.name for p in importer.TUTORIALS_ROOT.iterdir()},
                {f"drill_c001_{token}{frame}.png" for token in ["", "manual01_"]
                 for frame in ["initial", "s01", "final"]},
            )

    def test_repeated_import_keeps_names_and_bytes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "source"
            source.mkdir()
            (source / "s01_still.png").write_bytes(b"new frame")
            self.configure(root)
            for _ in range(2):
                importer.import_one(source, "drill_c023", "manual01", True, False, True)
            self.assertEqual(len(list(importer.TUTORIALS_ROOT.iterdir())), 2)
            self.assertEqual(
                (importer.TUTORIALS_ROOT / "drill_c023_manual01_s01.png").read_bytes(), b"new frame"
            )

    def test_cli_single_legacy_token_updates_default_alias(self):
        self.check_cli_alias(source_tokens=["Snipaste_2026"], selected="Snipaste_2026", expected=b"new")

    def test_cli_partial_second_formation_preserves_default_alias(self):
        self.check_cli_alias(source_tokens=["manual01", "manual02"], selected="manual02", expected=b"old")

    def check_cli_alias(self, source_tokens, selected, expected):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            library = root / "content/position_play/sequences"
            library.mkdir(parents=True)
            for token in source_tokens:
                (library / f"drill_c099__{token}-example-1杆.json").write_text(json.dumps({"steps": [{}]}))
            export = root / "export"
            source = export / f"drill_c099__{selected}-example-1杆"
            source.mkdir(parents=True)
            (source / "initial.png").write_bytes(b"new")
            masters = root / "masters"
            masters.mkdir()
            (masters / "drill_c099_initial.png").write_bytes(b"old")
            with patch.multiple(importer, REPO_ROOT=root, TUTORIALS_ROOT=masters,
                                VIDEOS_ROOT=root / "videos", PREVIEWS_ROOT=root / "previews"), \
                 patch.object(importer, "load_index_ids", return_value={"drill_c099"}), \
                 patch.object(sys, "argv", ["import", "--stills-only", "--skip-publish", "--export-root", str(export)]):
                self.assertEqual(importer.main(), 0)
            self.assertEqual((masters / "drill_c099_initial.png").read_bytes(), expected)
            self.assertEqual((masters / f"drill_c099_{selected}_initial.png").read_bytes(), b"new")

    def test_static_export_backfill_detects_corruption_without_video(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            paths = verifier.Paths(root)
            source = paths.export / "drill_c023__manual01-example-1杆"
            source.mkdir(parents=True)
            for frame in ["initial", "s01_still"]:
                (source / (frame + ".png")).write_bytes(frame.encode())
            self.configure(root)
            importer.TUTORIALS_ROOT = paths.tutorials
            importer.import_one(source, "drill_c023", "manual01", True, False, True)
            refs = {"drill_c023_manual01_initial", "drill_c023_manual01_s01"}
            result = verifier.check_backfill(refs, paths)
            self.assertEqual(result["ok"], 4)
            self.assertEqual(result["fail"], [])
            (paths.tutorials / "drill_c023_manual01_s01.png").write_bytes(b"corrupted")
            result = verifier.check_backfill(refs, paths)
            self.assertEqual(len(result["fail"]), 1)
            self.assertEqual(result["fail"][0][0], "drill_c023_manual01_s01.png")


if __name__ == "__main__":
    unittest.main()
