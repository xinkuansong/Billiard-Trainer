#!/usr/bin/env python3
"""Freeze and run a portable native macOS isolated-cloth SceneKit benchmark.

Prepare on the repository host; copy the resulting package and run it unchanged
on another Mac with: python3 run.py --bundle . --out RESULTS --run-only.
No simulator or remote host is started by this script.
"""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess
import time
import platform

REPO = Path(__file__).resolve().parents[3]
SCRIPT = Path(__file__).resolve()


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def prepare(bundle, candidate_surface=None, candidate_name=None, candidate_sha256=None, candidate_evidence=None, include_plain_safe=False):
    source = REPO / 'output/render-lowdim-20261113/visual-height-safe-r4'
    helper = source / 'support_height_safe.metal'
    assert sha(helper) == '99d93c078c4db243898fa4a3d358277fec9f552d7ae534f42826b03c0ce90bf4'
    visual = (REPO / 'scripts/research/cloth_lowdim_20261113/visual_render.swift').read_text()
    frozen = (source / 'harness.swift').read_text()
    # Copy the reviewed real-USDZ setup exactly, changing only resource paths.
    setup = visual[visual.index('let loaded='):visual.index('let reference=')]
    frozen_setup = frozen[frozen.index('let loaded='):frozen.index('let reference=')]
    if setup != frozen_setup:
        raise ValueError('Live scene setup differs from reviewed frozen visual-r4; audit before preparing a new package')
    candidate_surface = candidate_surface or source / 'height-safe.surface'
    candidate_name = candidate_name or 'plain safe with raw-sign guard (safe-r3 / visual-r4)'
    candidate_evidence = candidate_evidence or source / 'support-analysis.json'
    if not candidate_surface.is_file() or not candidate_evidence.is_file():
        raise ValueError('Candidate surface and completed validation evidence must be files')
    if candidate_sha256 is not None and sha(candidate_surface) != candidate_sha256:
        raise ValueError('Candidate surface differs from the explicitly validated SHA256')
    bundle.mkdir(parents=True, exist_ok=False)
    setup = setup.replace('QiuJi/Resources/ModelTrial20261010_TaiQiuZhuo.usdz', 'assets/table.usdz')
    setup = setup.replace('QiuJi/Resources/MobileRailOcclusion.png', 'assets/rail-ao.png')
    setup = setup.replace('output/render-lowdim-20261113/native-reference/generated-production-core.json', 'rig.json')
    setup = 'func makeScene(_ package: URL) throws -> SceneFixture {\nlet root=package,out=package\n' + setup
    setup += '\nreturn SceneFixture(scene:scene,table:table,mats:mats,eye:eye,camera:camera,renderer:renderer,alignment:["modelScale":scale,"modelSurfaceBeforeCorrection":modelSurface,"measuredBedY":measuredBedY ?? -99,"alignmentLift":0.8-(measuredBedY ?? 0.8)])\n}\n'
    shim = frozen[frozen.index('\nfinal class AngleTrainingScene {'):]
    native = REPO / 'scripts/research/cloth_lowdim_20261113/native_scene_benchmark.swift'
    code = native.read_text()
    assert code.count('// __SCENE_SETUP__') == 1
    (bundle / 'benchmark.swift').write_text(code.replace('// __SCENE_SETUP__', setup) + shim)
    (bundle / 'assets').mkdir()
    inputs = {
        'assets/table.usdz': REPO / 'QiuJi/Resources/ModelTrial20261010_TaiQiuZhuo.usdz',
        'assets/rail-ao.png': REPO / 'QiuJi/Resources/MobileRailOcclusion.png',
        'rig.json': REPO / 'output/render-lowdim-20261113/native-reference/generated-production-core.json',
        'reference.surface': source / 'reference.surface',
        'candidate.surface': candidate_surface,
        'candidate-validation-evidence.json': candidate_evidence,
        'reference-environment.hdr': source / 'reference-environment.hdr',
        'baseline-height-safe.metal': helper,
        'baseline-visual-shader-manifest.json': source / 'shader-manifest.json',
    }
    if include_plain_safe:
        inputs['plain-safe.surface'] = source / 'height-safe.surface'
        inputs['plain-safe-validation-evidence.json'] = source / 'support-analysis.json'
    for name, path in inputs.items():
        shutil.copyfile(path, bundle / name)
    shutil.copyfile(SCRIPT, bundle / 'run.py')
    # Keep upstream metadata as evidence, but no Swift runtime path depends on it.
    manifest = {'schema': 2, 'candidate': candidate_name,
                'comparisonArms': ['reference', 'plain-safe', 'candidate'] if include_plain_safe else ['reference', 'candidate'],
                'pairSchedule': '9 cycles rotating R-P/R-C/P-C order, each pair alternating ABBA/BAAB with 2 warmup + 6 timed independent render commands per slot' if include_plain_safe else '9 alternating ABBA/BAAB cycles',
                'candidateSurfaceSHA256': sha(candidate_surface),
                'candidateValidationEvidenceSHA256': sha(candidate_evidence),
                'candidateValidationContract': 'Caller supplied previously completed validation evidence and exact candidate SHA; native same-target R/control/candidate/repeat/restore tests remain compulsory. Evidence content is retained, not interpreted as blanket approval.',
                'scope': 'Native macOS real USDZ/TaiNi isolated scene; imported other materials and diagnostic white spheres; no production room or R ball reflections; not full App/iPhone',
                'sourceHashes': {str(p.relative_to(REPO)): sha(p) for p in [SCRIPT, native, REPO / 'scripts/research/cloth_lowdim_20261113/visual_render.swift', source / 'harness.swift']},
                'setupTransforms': ['resource URL paths replaced with package-relative paths only', 'frozen visual-r4 full alignment/decode shim appended unchanged'],
                'files': {str(p.relative_to(bundle)): sha(p) for p in sorted(bundle.rglob('*')) if p.is_file()}}
    manifest['packageID'] = hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()
    write(bundle / 'manifest.json', manifest)
    (bundle / 'README.md').write_text('''# Native isolated-cloth SceneKit package

Run on macOS with Xcode command-line tools:

```sh
python3 run.py --bundle . --out ../results-UNIQUE-HOST --run-only
```

The package uses only relative resource paths. `manifest.json` records exact source/assets. Each host compiles the same frozen `benchmark.swift`. Default runs two-ball near and 16-ball scatter at 700×400, 1400×800, 2800×1600. `--max-width 1400` limits to four cases. All images and raw per-frame GPU/CPU values are kept in the output. A synthetic fragment-fill workload must scale before scene timing is accepted. This is an isolated actual-cloth scene, not the production room, presented App, phone, or Simulator benchmark.
''')


def run(bundle, out, max_width, timeout):
    manifest = json.loads((bundle / 'manifest.json').read_text())
    for name, expected in manifest['files'].items():
        if sha(bundle / name) != expected:
            raise ValueError('Frozen package changed: ' + name)
    out.mkdir(parents=True, exist_ok=False)
    compile_cmd = ['xcrun', 'swiftc', '-O', str(bundle / 'benchmark.swift'), '-o', str(out / 'benchmark')]
    run_cmd = [str(out / 'benchmark'), str(bundle), str(out), str(max_width), str(timeout)]
    metadata = {'packageID': manifest['packageID'], 'host': platform.platform(), 'machine': platform.machine(),
                'commands': [compile_cmd, run_cmd], 'timeoutSeconds': timeout, 'maxWidth': max_width,
                'status': 'running'}
    started = time.monotonic()
    try:
        for label, command in [('compile', compile_cmd), ('run', run_cmd)]:
            with (out / (label + '.log')).open('w') as stream:
                subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, check=True,
                               timeout=120 if label == 'compile' else timeout + 5)
        metadata['status'] = 'succeeded'
    except BaseException as error:
        metadata.update(status='failed', error=repr(error))
        raise
    finally:
        metadata['wallSeconds'] = time.monotonic() - started
        write(out / 'driver.json', metadata)
        shutil.copyfile(bundle / 'manifest.json', out / 'package-manifest.json')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle', type=Path, required=True)
    parser.add_argument('--out', type=Path)
    parser.add_argument('--run-only', action='store_true')
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--max-width', type=int, choices=[700, 1400, 2800], default=2800)
    parser.add_argument('--timeout', type=int, default=600)
    parser.add_argument('--candidate-surface', type=Path, help='Previously validated complete surface; does not generate a candidate')
    parser.add_argument('--candidate-name', help='Exact variant identity for the new frozen package/result')
    parser.add_argument('--candidate-sha256', help='Explicit SHA256 of the validated complete surface')
    parser.add_argument('--candidate-evidence', type=Path, help='Completed validation JSON retained in the package')
    parser.add_argument('--include-plain-safe', action='store_true', help='Add the frozen validated plain-safe surface as a third directly paired arm')
    args = parser.parse_args()
    custom = [args.candidate_surface, args.candidate_name, args.candidate_sha256, args.candidate_evidence]
    if any(custom) and not all(custom):
        parser.error('Custom candidates require surface, name, SHA256 and completed validation evidence together')
    if args.include_plain_safe and not all(custom):
        parser.error('A third plain-safe arm requires an explicitly validated custom candidate')
    if args.run_only and (any(custom) or args.include_plain_safe):
        parser.error('--run-only uses the immutable package; it cannot replace a candidate')
    if not args.run_only:
        prepare(args.bundle.resolve(), args.candidate_surface, args.candidate_name, args.candidate_sha256, args.candidate_evidence, args.include_plain_safe)
    if not args.prepare_only:
        if not args.out:
            parser.error('--out is required unless --prepare-only')
        run(args.bundle.resolve(), args.out.resolve(), args.max_width, args.timeout)


if __name__ == '__main__':
    main()
