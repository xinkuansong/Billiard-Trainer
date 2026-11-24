"""Run real capture entrypoints with an isolated make stub; never render media."""
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CaptureEntryTests(unittest.TestCase):
    def test_current_capture_scripts_select_existing_methods_without_writing_media(self):
        cases = {
            'angle-aiming': ('keyframes', 'AngleAimingVideoCaptureTests/testGeometryAndKeyframes()'),
            'advanced-snake': ('keyframes', 'AdvancedSnakeVideoCaptureTests/testKeyframes()'),
            'cue-spin': ('keyframes', 'CueSpinPreviewCaptureTests/testCapture()'),
            'feel-aiming': ('keyframes', 'FeelAimingVideoCaptureTests/testKeyframes()'),
            'separation-intro': ('keyframes', 'SeparationIntroVideoCaptureTests/testKeyframes()'),
            'separation-eightball': ('preview', 'SeparationEightBallVideoCaptureTests/testExport()'),
        }
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            stub = root / 'make'
            stub.write_text('#!' + sys.executable + '\nimport json,os,sys\n'
                            'open(os.environ["CAPTURE_ARGV"],"w").write(json.dumps(sys.argv[1:]))\n')
            stub.chmod(0o755)
            env = dict(os.environ, PATH=tmp + os.pathsep + os.environ['PATH'], CAPTURE_ARGV=str(root/'args.json'))
            sources = '\n'.join(p.read_text() for p in (ROOT/'CuePhysTests').glob('*.swift'))
            for name, (mode, method) in cases.items():
                with self.subTest(name=name):
                    script = ROOT/'scripts/video'/('capture-' + name + '.sh')
                    subprocess.run(['bash', '-n', str(script)], check=True)
                    result = subprocess.run(['bash', str(script), mode, 'fixture-device', str(root/name)], env=env, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    args = json.loads((root/'args.json').read_text())
                    self.assertIn('ONLY_TESTING=CuePhysTests/' + method, args)
                    self.assertIn('TEST_DESTINATION=platform=iOS Simulator,id=fixture-device', args)
                    cls, func = method.split('/')
                    self.assertRegex(sources, r'class\s+' + cls + r'\s*:')
                    self.assertIn('func ' + func, sources)
                    self.assertFalse(list((root/name).rglob('*.mp4')))

    def test_make_quotes_parenthesized_selector_as_one_shell_argument(self):
        selector = 'CuePhysTests/ModelAssetTrialTests/testBundleContainsOnlyProductionModels()'
        text = subprocess.check_output(['make', '-n', '-f', str(ROOT/'scripts/Makefile'), '_test', 'ONLY_TESTING='+selector], text=True, cwd=ROOT)
        flattened = text.replace('\\\n', '')
        self.assertIn('-only-testing:' + selector, shlex.split(flattened))


if __name__ == '__main__':
    unittest.main()
