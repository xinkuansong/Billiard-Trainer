"""H11 native SceneKit experiment; invoke through local_test_lifecycle."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--evidence', type=Path, required=True)
    parser.add_argument('--width', type=int, default=700)
    parser.add_argument('--round', default='initial')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    package = root / 'output/render-lowdim-20261113/native-scene-guardcombo-package-r2'
    assert shutil.disk_usage(root).free >= 2 * 1024**3
    native_path = package / 'benchmark.swift'
    helpers_path = root / 'scripts/research/cloth_temporal_20261113/scene_main.swift'
    native, helpers = native_path.read_text(), helpers_path.read_text()
    source = Path(__file__).with_name('main.swift')
    prepared = Path(__file__).with_name('PreparedState.swift')
    production = root / 'QiuJi/Core/Scene/StaticClothIrradiance.swift'
    files = [Path(__file__), source, prepared, production, native_path, helpers_path,
             root/'QiuJi/Core/Scene/MobileReferenceLighting.swift',
             root/'QiuJi/Core/Scene/MobileTableRendering.swift',
             root/'QiuJi/Resources/StaticClothIrradiance-v1.bin',
             *[package/p for p in ['candidate.surface', 'assets/table.usdz', 'assets/rail-ao.png', 'reference-environment.hdr', 'rig.json']]]
    def identity():
        return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    before = identity()
    generated = native[:native.index('func calibrate()')]
    generated += '\nlet repository=URL(fileURLWithPath:' + json.dumps(str(root)) + ')\n'
    generated += 'let experimentRound=' + json.dumps(args.round) + '\n'
    generated += helpers[helpers.index('func difference('):helpers.index('func input(')]
    generated += source.read_text() + '\n' + native[native.index('final class AngleTrainingScene'):]
    for destination in [args.work, args.evidence]:
        destination.mkdir(parents=True, exist_ok=True)
        (destination/'main.swift').write_text(generated)
        shutil.copy2(prepared, destination)
        shutil.copy2(production, destination)
    (args.evidence/'source-identity.json').write_text(json.dumps(before, indent=2)+'\n')
    with (args.evidence/'compile.log').open('w') as log:
        subprocess.run(['xcrun', 'swiftc', '-O', '-D', 'DEBUG',
                        str(args.work/'StaticClothIrradiance.swift'), str(args.work/'PreparedState.swift'),
                        str(args.work/'main.swift'), '-o', str(args.work/'benchmark')],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    with (args.evidence/'render.log').open('w') as log:
        subprocess.run([str(args.work/'benchmark'), str(package), str(args.evidence), str(args.width), '360'],
                       stdout=log, stderr=subprocess.STDOUT, check=True, timeout=380)
    assert identity() == before, 'Source/asset drift during run'
    print(args.evidence/'results.json', flush=True)


if __name__ == '__main__':
    main()
