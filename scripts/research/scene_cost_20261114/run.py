#!/usr/bin/env python3
"""Managed native current-scene study; freeze production inputs before building."""
import os
import json
from pathlib import Path
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))
from mac_mini_queue import snapshot

work = Path(os.environ['QIUJI_TEST_WORK'])
evidence = Path(os.environ['QIUJI_TEST_EVIDENCE'])
assert os.environ['QIUJI_TEST_RUN_ID']
minimum_gib = 7 if len(sys.argv) > 1 and sys.argv[1] == 'testNativeStreamingDiffuseCost' else 9
free = shutil.disk_usage(ROOT).free
(evidence / 'disk-preflight.json').write_text(json.dumps({'availableBytes': free,
    'minimumGiB': minimum_gib, 'basis': 'R3: two measured native build peaks approximately 2.2-2.4 GiB; reserve 4 GiB beyond observed peak; no trace capture'}) + '\n')
if free < minimum_gib * 1024 ** 3:
    raise RuntimeError(f'H13 requires {minimum_gib} GiB free before starting')
snapshot(ROOT, work / 'snapshot', dirty=True, quiescent=True)
for relative in ['QiuJiTests/ClothSupportPerformanceResearchTests.swift',
                 'QiuJi/Core/Scene/AngleTrainingScene.swift',
                 'QiuJi/Core/Scene/MobileReferenceLighting.swift',
                 'QiuJi/Core/Scene/StaticClothIrradiance.swift',
                 'QiuJi/Core/Scene/AngleSceneView.swift',
                 'QiuJi/Core/Scene/CameraRig.swift']:
    target = evidence / 'frozen-source' / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(work / 'snapshot/source' / relative, target)
shutil.copyfile(__file__, evidence / 'study-launcher.py')
result = subprocess.run([sys.executable, str(ROOT / 'scripts/research/cloth_lowdim_20261113/run_native_app.py'),
                '--snapshot', str(work / 'snapshot'), '--work', str(work), '--evidence', str(evidence),
                '--test', 'QiuJiTests/ClothSupportPerformanceResearchTests/' +
                (sys.argv[1] if len(sys.argv) > 1 else 'testNativeCurrentMaterialAndCPUCost')],
               cwd=ROOT)
if result.returncode and (evidence / 'tests.xcresult').exists() and not (evidence / 'attachments').exists():
    with (evidence / 'failure-attachment-export.log').open('wb') as stream:
        subprocess.run(['xcrun', 'xcresulttool', 'export', 'attachments', '--path', str(evidence / 'tests.xcresult'),
                        '--output-path', str(evidence / 'attachments')], stdout=stream, stderr=subprocess.STDOUT,
                       timeout=120)
sys.exit(result.returncode)
