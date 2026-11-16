"""Frozen current-App R7 integration and boundary tests under the managed owner."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
root = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(root / 'scripts'))
from mac_mini_queue import snapshot

work, evidence = Path(os.environ['QIUJI_TEST_WORK']), Path(os.environ['QIUJI_TEST_EVIDENCE'])
assert os.environ['QIUJI_TEST_RUN_ID']
free = shutil.disk_usage(root).free
# Reclaimed-space delta is not peak demand (APFS sharing and concurrent work).
# R7d proved that a 6 GiB full-build preflight was insufficient under concurrent builds.
(evidence / 'preflight.json').write_text(json.dumps({'availableBytes': free, 'requiredGiB': 10,
    'reason': 'Full build peak plus concurrent-work reserve; test-only recovery has its own smaller budget'}) + '\n')
assert free >= 10 * 1024**3, 'Reserve full-build peak and concurrent-work space'
snapshot(root, work / 'snapshot', dirty=True, quiescent=True)
for relative in ['QiuJiTests/ClothSupportPerformanceResearchTests.swift', 'QiuJi/Core/Scene/ClothSpecularLTC.swift',
                 'QiuJi/Core/Scene/MobileReferenceLighting.swift', 'QiuJi/Core/Scene/AngleTrainingScene.swift',
                 'QiuJi/Core/Scene/RoomReflectionProbe.swift', 'QiuJi/Resources/ClothSpecularLTC-v1.bin']:
    target = evidence / 'frozen-source' / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(work / 'snapshot/source' / relative, target)
shutil.copy2(__file__, evidence / 'study-launcher.py')
names = sys.argv[1:] or ['testNativeClothLTCR7a', 'testNativeClothLTCR7b']
arguments = [item for name in names for item in ['--test', 'QiuJiTests/ClothSupportPerformanceResearchTests/' + name]]
result = subprocess.run([sys.executable, str(root / 'scripts/research/cloth_lowdim_20261113/run_native_app.py'),
    '--snapshot', str(work / 'snapshot'), '--work', str(work), '--evidence', str(evidence),
    '--expected-count', str(len(names)), *arguments], cwd=root)
if result.returncode and (evidence / 'tests.xcresult').exists() and not (evidence / 'attachments').exists():
    with (evidence / 'failure-export.log').open('w') as log:
        subprocess.run(['xcrun', 'xcresulttool', 'export', 'attachments', '--path', str(evidence / 'tests.xcresult'),
            '--output-path', str(evidence / 'attachments')], stdout=log, stderr=subprocess.STDOUT, timeout=120)
sys.exit(result.returncode)
