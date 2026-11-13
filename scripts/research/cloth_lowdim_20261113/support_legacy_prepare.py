#!/usr/bin/env python3
"""CPU-only reproduction of the historical r5/r7/r8 support-full-height shader.

Executes the archived Swift generator on freshly generated current production R.
Keeps a byte-identical current referenceAt, and exports the legacy and combined
legacy + safe-hoisted candidates for the existing six-channel lighting harness.
No Metal device, renderer, dispatch, benchmark or production mutation is invoked.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
HISTORY = ROOT / 'output/render-system-audit-20261011'
LEGACY_SHA = 'ac06cf99a9b9e4774dbed223a3a477fdeafecc44c44f94db45ee2632b8b3ab9c'


def digest(value):
    return hashlib.sha256(value if isinstance(value, bytes) else value.encode()).hexdigest()


def once(value, old, new):
    if value.count(old) != 1:
        raise ValueError(('Source anchor drift', old[:100], value.count(old)))
    return value.replace(old, new)


def load_script(name):
    spec = importlib.util.spec_from_file_location('legacy_dependency_' + name, HERE / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def reference_function(source):
    start = source.index('inline Result referenceAt(')
    end = source.index('inline float groupBRDF(', start)
    return source[start:end]


def lighting_function(cloth, name):
    body = once(cloth, 'float3 p=contactWorld;', 'float3 p=input.position.xyz;')
    body = once(body, 'normalize((scn_frame.inverseViewTransform*float4(_surface.normal,0.0)).xyz)',
                'normalize(input.normal.xyz)')
    body = once(body, 'normalize(scn_frame.inverseViewTransform[3].xyz-p)', 'normalize(input.view.xyz)')
    body = body.replace('_surface.roughness', 'input.view.w')
    body = re.sub(r'\bcontactBall(\d+)\b', lambda m: 'balls[' + m[1] + ']', body)
    body = once(body, 'E=v62PanelDiffuse(p,n)*(E/max(unoccludedE,float3(0.000001)));',
                'float3 sampledE=E;\n    E=v62PanelDiffuse(p,n)*(E/max(unoccludedE,float3(0.000001)));')
    body = body[:body.index('// v64ClothNap:')]
    if any(token in body for token in ['_surface', 'scn_frame', '{{']):
        raise ValueError('Unmapped SceneKit source')
    return ('inline Result ' + name + '(Input input, constant float4 *balls) {\n' + body + '''
    return {float4(unoccludedE,float(shadowPossible)),float4(sampledE,float(shadowMask)),
            float4(E,0),float4(S,0)};
}
''')


def write_candidate(out, original, extra, candidate, wrappers, metadata):
    out.mkdir()
    source = original + extra + candidate + '''
kernel void evaluateHeightSupport(device const Input *inputs [[buffer(0)]],
    constant float4 *balls [[buffer(1)]],device Result *results [[buffer(2)]],
    constant uint &count [[buffer(3)]],uint index [[thread_position_in_grid]]) {
    if(index<count) results[index]=heightSupportAt(inputs[index],balls);
}
'''
    # Existing support_lighting_benchmark appends its own wrappers to this file.
    (out / 'height-support.metal').write_text(source)
    # Standalone entry points expose only corrected E.xyz and S.xyz (two pads).
    (out / 'lighting.metal').write_text(source + wrappers)
    metadata.update({'candidateSourceSHA256': digest(source),
                     'standaloneLightingSHA256': digest(source + wrappers),
                     'referenceFunctionSHA256': digest(reference_function(source)),
                     'lightingContract': 'Input N x 12 Float32; balls 16 x 4. Lighting output N x 8: correctedE.xyz/0, S.xyz/0. Diagnostic masks/near are not timed outputs.',
                     'entryPoints': ['evaluateReference', 'evaluateHeightSupport',
                                     'evaluateLightingReference', 'evaluateLightingHeight'],
                     'status': 'CPU generated only; no current GPU numerical or timing acceptance'})
    (out / 'source-manifest.json').write_text(json.dumps(metadata, indent=2) + '\n')


def prepare(reference, out):
    out.mkdir(parents=True, exist_ok=False)
    archived = {r: (HISTORY / r / 'IndependentQualitySupport.swift').read_bytes()
                for r in ['r5', 'r7', 'r8']}
    if any(digest(value) != LEGACY_SHA for value in archived.values()):
        raise ValueError('Historical r5/r7/r8 generator SHA drift')
    # Fresh source execution verifies the selected input has not become stale.
    load_script('prepare_reference').prepare(out / 'current-reference')
    fresh = (out / 'current-reference/reference.metal').read_text()
    original = reference.read_text()
    if fresh != original:
        raise ValueError('Selected reference differs from freshly generated current R')
    payload = out / 'current-reference/generated-production-core.json'
    current = json.loads(payload.read_text())
    original_function = reference_function(original)
    if lighting_function(current['cloth'], 'referenceAt') != original_function:
        raise ValueError('SceneKit-to-input mapping differs from current referenceAt')
    if current['cloth'].count('int samplesX=shadowPossible?8:2;\n int samplesZ=shadowPossible?4:2;') != 1:
        raise ValueError('Legacy proof requires original reference 8 x 4 / 2 x 2 sampling')
    for panel in current['rig']['panels']:
        if panel['u'][1:] != [0, 0] or panel['v'][:2] != [0, 0] or panel['normal'] != [0, -1, 0]:
            raise ValueError('Legacy cone requires horizontal X/Z axis-aligned emitters')
    driver = archived['r8'].decode() + '''
let inputURL=URL(fileURLWithPath:CommandLine.arguments[1])
let payload=try JSONSerialization.jsonObject(with:Data(contentsOf:inputURL)) as! [String:Any]
let source=payload["cloth"] as! String
let result=try IndependentQualitySupport.apply(source:source,ballCount:16,variant:"support-full-height")
try result.write(toFile:CommandLine.arguments[2],atomically:true,encoding:.utf8)
'''
    (out / 'legacy-generator.swift').write_text(driver)
    process = subprocess.run(['xcrun', 'swift', str(out / 'legacy-generator.swift'),
                              str(payload), str(out / 'legacy.cloth')], capture_output=True, text=True)
    (out / 'legacy-generator.log').write_text(process.stdout + process.stderr)
    if process.returncode:
        raise RuntimeError(process.stderr)
    legacy_cloth = (out / 'legacy.cloth').read_text()
    legacy_function = lighting_function(legacy_cloth, 'referenceAt')
    # Verify only the preclassification and shadow-loop predicate changed.
    begin = legacy_cloth.index('bool diagnosticGlobalQuality=false;')
    panel_loop = 'for(int panel=0;panel<2;++panel) {'
    second_loop = legacy_cloth.index(panel_loop, legacy_cloth.index(panel_loop, begin) + len(panel_loop))
    classification = legacy_cloth[begin:second_loop]
    unclassified = legacy_cloth[:begin] + legacy_cloth[second_loop:]
    restored = once(unclassified, 'if(diagnosticGlobalQuality) {\nuint remainingShadowBalls=shadowMask;',
                    'if(shadowPossible) {\nuint remainingShadowBalls=shadowMask;')
    if restored != current['cloth']:
        raise ValueError('Legacy generator changes more than classification/shadow gate')
    benchmark = (HERE / 'support_lighting_benchmark.swift').read_text()
    wrappers = benchmark.split('let wrappers="""\n', 1)[1].split('\n"""\nlet source=original+wrappers', 1)[0]
    metadata = {'legacyGeneratorSHA256': LEGACY_SHA,
                'legacySource': str(HISTORY / 'r8/IndependentQualitySupport.swift'),
                'r5r7r8Identical': True, 'currentReferenceSHA256': digest(original),
                'currentProductionManifest': json.loads((out / 'current-reference/manifest.json').read_text()),
                'generatorExecuted': 'IndependentQualitySupport.apply(...variant: support-full-height)',
                'unchanged': ['shadowPossible', '8x4/2x2 quadrature', 'sample order', 'BRDF',
                              'global two-panel diffuse normalization', 'emitter geometry and ball positions'],
                'proofBoundary': 'Real-arithmetic cone support proof for current horizontal axis-aligned panels. Historical 64*Float.epsilon*worldScale margin is not a universal GPU Float32 proof. Combination additionally relies on bounded safe-mask contract.',
                'prepareSHA256': digest(Path(__file__).read_bytes()),
                'wrapperSourceSHA256': digest(benchmark)}
    write_candidate(out / 'legacy', original, '',
                    once(legacy_function, 'referenceAt(', 'heightSupportAt('), '\n' + wrappers,
                    {**metadata, 'variant': 'historical-support-full-height',
                     'maskContract': 'Original mask retained; classifier scans original mask for both lamps'})
    # Apply the canonical current candidate generator first, then the exact
    # archived classification text. This leaves its global predicate outside
    # the near-only mask scope and does not alter the pristine R referenceAt.
    staging = out / 'combined-staging'
    staging.mkdir()
    support = load_script('support_height_run')
    support.prepare(reference, staging, 'safe-hoisted')
    combined = (staging / 'height-support.metal').read_text()
    suffix = combined[len(original):]
    function_start = suffix.index('inline Result heightSupportAt(')
    function_end = suffix.index('\nkernel void evaluateHeightSupport(', function_start)
    extra, function = suffix[:function_start], suffix[function_start:function_end]
    function = once(function, panel_loop, classification + panel_loop)
    function = once(function, 'if(shadowPossible) {\nuint remainingShadowBalls=shadowMask;',
                    'if(diagnosticGlobalQuality) {\nuint remainingShadowBalls=shadowMask;')
    # Both classifiers use the same narrowed mask; no alternate sample decision.
    if function.count('int samplesX=shadowPossible?8:2;') != 1:
        raise ValueError('Combined sample selector drift')
    write_candidate(out / 'legacy-plus-safe-hoisted', original, extra, function, '\n' + wrappers,
                    {**metadata, 'variant': 'historical-support-full-height-plus-current-safe-hoisted',
                     'maskContract': 'Near-first safe-hoisted mask; old cone scans that same mask; far diagnostic mask is zero',
                     'safeHelperSHA256': digest((HERE / 'support_height_safe.metal').read_bytes()),
                     'safeGeneratorSHA256': digest((HERE / 'support_height_run.py').read_bytes())})
    (out / 'IndependentQualitySupport.swift').write_bytes(archived['r8'])
    (out / 'support_height_safe.metal').write_bytes((HERE / 'support_height_safe.metal').read_bytes())
    (out / 'support_height_run.py').write_bytes((HERE / 'support_height_run.py').read_bytes())
    (out / 'support_legacy_prepare.py').write_bytes(Path(__file__).read_bytes())
    print(json.dumps({'out': str(out), 'legacySHA256': LEGACY_SHA,
                      'referenceUnchanged': True, 'GPUUsed': False}, indent=2))


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--reference', type=Path, required=True)
    ap.add_argument('--out', type=Path, required=True)
    args = ap.parse_args()
    prepare(args.reference.resolve(), args.out.resolve())
