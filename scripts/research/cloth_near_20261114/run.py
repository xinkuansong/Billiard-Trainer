"""Native near-shadow experiments. Use local_test_lifecycle.py."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess

p = argparse.ArgumentParser()
p.add_argument('--work', required=True, type=Path)
p.add_argument('--evidence', required=True, type=Path)
p.add_argument('--width', default=700, type=int)
p.add_argument('--round', choices=['initial','row','group2','lamp-mask','relative','squared','capture','h9-capture','constant-array','constant-lamp','quality'], default='initial')
a = p.parse_args()
root = Path(__file__).resolve().parents[3]
package = root / 'output/render-lowdim-20261113/native-scene-guardcombo-package-r2'
native = (package / 'benchmark.swift').read_text()
prefix = native[:native.index('func calibrate()')]
shim = native[native.index('final class AngleTrainingScene'):]
old = (root / 'scripts/research/cloth_temporal_20261113/scene_main.swift').read_text()
helpers = old[old.index('func difference('):old.index('try FileManager.default.createDirectory(at:output')]
main_path = Path(__file__).with_name('main.swift')
main = main_path.read_text()
is_capture = a.round in ('capture', 'h9-capture')
if is_capture or a.round == 'quality':
    main = main[:main.index('let variants:')] + Path(__file__).with_name(('capture' if is_capture else a.round) + '.swift').read_text()
config = 'let repository=URL(fileURLWithPath:' + json.dumps(str(root)) + ')\n'
config += 'let experimentRound=' + json.dumps(a.round) + '\n'
config += 'let captureWork=URL(fileURLWithPath:' + json.dumps(str(a.work / 'captures')) + ')\n'
generated = prefix + '\n' + config + helpers + '\n' + main + '\n' + shim
for directory in (a.work, a.evidence):
    (directory / 'main.swift').write_text(generated)
    shutil.copy2(root / 'QiuJi/Core/Scene/StaticClothIrradiance.swift', directory)
files = [root / 'QiuJi/Core/Scene/StaticClothIrradiance.swift',
         root / 'QiuJi/Core/Scene/MobileReferenceLighting.swift',
         root / 'QiuJi/Resources/StaticClothIrradiance-v1.bin',
         package / 'candidate.surface', package / 'benchmark.swift',
         package / 'assets/table.usdz', package / 'assets/rail-ao.png',
         package / 'reference-environment.hdr', package / 'rig.json', main_path,
         Path(__file__), root / 'scripts/research/cloth_temporal_20261113/scene_main.swift']
if is_capture:
    files.append(Path(__file__).with_name('capture.swift'))
    files.append(Path(__file__).with_name('pack_captures.py'))
elif a.round == 'quality':
    files.append(Path(__file__).with_name('quality.swift'))

def identity():
    return {str(f.relative_to(root)): hashlib.sha256(f.read_bytes()).hexdigest() for f in files}

before = identity()
(a.evidence / 'source-identity.json').write_text(json.dumps(before, indent=2) + '\n')
z = [2 * (i + 0.5) / 4 - 1 for i in range(4)]
assert z == [-0.75, -0.25, 0.25, 0.75]
assert [(z[i] + z[i+1]) / 2 for i in (0, 2)] == [-0.5, 0.5]
assert abs(0.8 + 0.028575 - 0.828575) < 1e-12
(a.evidence / 'geometry-preflight.json').write_text(json.dumps({
    'world': 'XZ horizontal, Y up, meters', 'sampleZ': z,
    'pairCenters': [-0.5, 0.5], 'bedY': 0.8, 'ballCenterY': 0.828575,
    'nearOcclusionSamplesPreserved': 64, 'farSamplesPreserved': 8,
}, indent=2) + '\n')
with (a.evidence / 'compile.log').open('w') as log:
    subprocess.run(['xcrun', 'swiftc', '-O', '-D', 'DEBUG',
                    str(a.work / 'StaticClothIrradiance.swift'), str(a.work / 'main.swift'),
                    '-o', str(a.work / 'benchmark')], stdout=log, stderr=subprocess.STDOUT, check=True)
with (a.evidence / 'render.log').open('w') as log:
    environment = os.environ.copy()
    if is_capture:
        environment['METAL_CAPTURE_ENABLED'] = '1'
    subprocess.run([str(a.work / 'benchmark'), str(package), str(a.evidence), str(a.width), '240'],
                   stdout=log, stderr=subprocess.STDOUT, check=True, timeout=260, env=environment)
assert identity() == before, 'Source or asset drift'
if is_capture:
    from pack_captures import pack
    pack(a.work, a.evidence, names=('baseline', 'constant-lamp') if a.round == 'h9-capture' else ('baseline', 'lamp-mask', 'squared'))
print(a.evidence / 'results.json', flush=True)
