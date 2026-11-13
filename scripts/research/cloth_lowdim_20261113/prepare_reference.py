#!/usr/bin/env python3
"""Execute selected production Swift generators and wrap their MSL in a math kernel.

This is not the final SceneKit-compiled material. It evaluates the actual cloth
lighting core, excluding textures, contact AO, material emission, native PBR and
output transforms. No production source is edited.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'QiuJi/Core/Scene/MobileReferenceLighting.swift'
CONSTANTS = ROOT / 'QiuJi/Core/Physics/BTPhysicsConstants.swift'


def slice_between(text, start, end):
    assert text.count(start) == 1, start
    a = text.index(start)
    b = text.index(end, a)
    return text[a:b]


def replace_once(text, old, new):
    assert text.count(old) == 1, (old, text.count(old))
    return text.replace(old, new, 1)


def prepare(out):
    out.mkdir(parents=True, exist_ok=True)
    source = SOURCE.read_text()
    constants = CONSTANTS.read_text()
    pieces = {}
    pieces['Panel_Rig'] = slice_between(source, '    struct Panel {', '    /// Same gate')
    pieces['sampling'] = slice_between(source, '    enum SamplingProfile {', '    enum SpecializedProfile:')
    pieces['profile'] = slice_between(source, '    enum SpecializedProfile:', '    /// Shared baseline.')
    pieces['directShadowShader'] = slice_between(source, '    static func directShadowShader(', '    /// S1:')
    # Only the R branch is evaluated. Keep exact R generator, exclude unreachable S dependency.
    guard = '        if specialized && (profile ?? specializedProfile).usesShadow { return analyticDirectShadowShader(ballCount: ballCount) }\n'
    direct = replace_once(pieces['directShadowShader'], guard, '        precondition(!(profile ?? specializedProfile).usesShadow, "R reference only")\n')
    pieces['analytic'] = slice_between(source, '    static let emitterGeometry: String = {', '    /// Cue varnish,')
    pieces['cloth'] = slice_between(source, '    private static let clothShader = rig.shader("""', '\n}\n\n\n#if DEBUG')
    size_lines = []
    for name in ('innerLength', 'innerWidth'):
        matches = re.findall(r'^    static let ' + name + r': Float = [0-9.]+$', constants, re.M)
        assert len(matches) == 1, name
        size_lines.extend(matches)
    swift = ('import Foundation\nimport SceneKit\nimport simd\n'
             + 'enum TablePhysics {\n' + '\n'.join(size_lines) + '\n}\n'
             + 'enum ExportedLighting {\n' + pieces['Panel_Rig'] + pieces['sampling']
             + pieces['profile'] + '    static var specializedProfile: SpecializedProfile { .reflection }\n'
             + direct + pieces['analytic'] + pieces['cloth'] + '\n}\n'
             + '''let rig = ExportedLighting.rig
let value: [String: Any] = [
    "helpers": ExportedLighting.analyticPanelDiffuse,
    "cloth": ExportedLighting.directShadowShader(ballCount: 16, profile: .reflection),
    "rig": ["radiance": rig.radiance, "minimumHeight": rig.minimumHeight,
            "shadowSupportRadius": rig.shadowSupportRadius,
            "panels": rig.panels.map { p in
                ["center": [p.center.x,p.center.y,p.center.z],
                 "u": [p.u.x,p.u.y,p.u.z], "v": [p.v.x,p.v.y,p.v.z],
                 "normal": [p.normal.x,p.normal.y,p.normal.z],
                 "area": p.area,"gain": p.gain] as [String:Any]
            }]
]
let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted,.sortedKeys])
FileHandle.standardOutput.write(data)
''')
    swift_path = out / 'generator.swift'
    swift_path.write_text(swift)
    result = subprocess.run(['xcrun', 'swift', str(swift_path)], cwd=ROOT, capture_output=True)
    (out / 'generator.stderr.log').write_bytes(result.stderr)
    if result.returncode:
        raise RuntimeError(result.stderr.decode())
    payload = json.loads(result.stdout)
    (out / 'generated-production-core.json').write_bytes(result.stdout)
    body = payload['cloth']
    body = replace_once(body, 'float3 p=contactWorld;', 'float3 p=input.position.xyz;')
    body = replace_once(body, 'normalize((scn_frame.inverseViewTransform*float4(_surface.normal,0.0)).xyz)', 'normalize(input.normal.xyz)')
    body = replace_once(body, 'normalize(scn_frame.inverseViewTransform[3].xyz-p)', 'normalize(input.view.xyz)')
    body = body.replace('_surface.roughness', 'input.view.w')
    body = re.sub(r'\bcontactBall(\d+)\b', lambda m: 'balls[' + m[1] + ']', body)
    body = replace_once(body, 'E=v62PanelDiffuse(p,n)*(E/max(unoccludedE,float3(0.000001)));',
                        'float3 sampledE=E;\n    E=v62PanelDiffuse(p,n)*(E/max(unoccludedE,float3(0.000001)));')
    body = body[:body.index('// v64ClothNap:')]
    assert '_surface' not in body and 'scn_frame' not in body and '{{' not in body
    # Reuse the production BRDF expression; only the evaluated light direction changes.
    brdf = body[body.index('float nl=max(0.001,dot(n,l));'):body.index('float3 weighted=')]
    metal = """#include <metal_stdlib>
using namespace metal;
struct Input { float4 position; float4 normal; float4 view; };
struct Result { float4 unoccluded; float4 sampled; float4 corrected; float4 specular; };
""" + payload['helpers'] + """
inline Result referenceAt(Input input, constant float4 *balls) {
""" + body + """
    return {float4(unoccludedE,float(shadowPossible)),float4(sampledE,float(shadowMask)),
            float4(E,0),float4(S,0)};
}
inline float groupBRDF(float3 n,float3 v,float3 l,float roughness) {
    float nv=max(0.001,dot(n,v));
    float alpha=max(0.01,roughness*roughness);
    float a2=alpha*alpha;
""" + brdf + """
    return D*G*F/(4.0*nv*nl);
}
kernel void evaluateReference(device const Input *inputs [[buffer(0)]],
                              constant float4 *balls [[buffer(1)]],
                              device Result *results [[buffer(2)]],
                              constant uint &count [[buffer(3)]],
                              uint index [[thread_position_in_grid]]) {
    if (index < count) results[index]=referenceAt(inputs[index],balls);
}
// Frozen-cache consumption only. Moment generation/lookup/interpolation are not measured.
kernel void evaluateCandidate(device const Input *inputs [[buffer(0)]],
                              constant float4 *balls [[buffer(1)]],
                              device Result *results [[buffer(2)]],
                              constant uint &count [[buffer(3)]],
                              device const float4 *moments [[buffer(4)]],
                              constant uint &groups [[buffer(5)]],
                              uint index [[thread_position_in_grid]]) {
    if (index >= count) return;
    uint base=index*(groups+2);
    if(moments[base].w==0.0) { results[index]=referenceAt(inputs[index],balls); return; }
    Input input=inputs[index];
    float3 p=input.position.xyz,n=normalize(input.normal.xyz),v=normalize(input.view.xyz);
    float3 color=float3(1.0,0.985,0.96);
    float3 sampled=color*dot(n,moments[base].xyz);
    float3 unoccluded=color*dot(n,moments[base+1].xyz);
    float3 E=v62PanelDiffuse(p,n)*(sampled/max(unoccluded,float3(0.000001)));
    float3 S=float3(0.0);
    for(uint k=0;k<groups;++k) {
        float3 m=moments[base+2+k].xyz;
        float length2=dot(m,m);
        if(length2>0.0) {
            float3 l=m/sqrt(length2);
            S+=color*max(0.0,dot(n,m))*groupBRDF(n,v,l,input.view.w);
        }
    }
    // Diagnostic flags are candidate-enabled/0, not the reference's near/mask metadata.
    results[index]={float4(unoccluded,1),float4(sampled,0),float4(E,0),float4(S,0)};
}
"""
    (out / 'reference.metal').write_text(metal)
    manifest = {
        'source': str(SOURCE.relative_to(ROOT)), 'source_sha256': hashlib.sha256(source.encode()).hexdigest(),
        'constants_sha256': hashlib.sha256(constants.encode()).hexdigest(),
        'extracted_sections': {k: hashlib.sha256(v.encode()).hexdigest() for k, v in pieces.items()},
        'reference_metal_sha256': hashlib.sha256(metal.encode()).hexdigest(),
        'profile': 'R; ordinary sampling; usesMask true; mergesSupport false; factorsBRDF false; 16 balls',
        'input': 'Float32 little endian N x 12: position.xyzw, normal.xyzw, viewDirection.xyz/roughness',
        'balls': 'Float32 little endian 16 x 4: worldX,worldZ,heightAbove0.8,encodedWeight',
        'output': 'Float32 little endian N x 16: unoccludedE.xyz/nearFlag, sampledE.xyz/shadowMask, correctedE.xyz/0, S.xyz/0',
        'candidate_input': 'Optional Float32 N x (2+G) x 4: MV.xyz/enabledFlag, M0.xyz/0, then G Mgroup.xyz/0; moments include radiance/pi but not RGB light color',
        'candidate_scope': 'Frozen moment consumption; original reference fallback when enabledFlag=0; no field generation or spatial texture/interpolation costs',
        'transforms': ['Execute extracted Swift Rig and R shader generator, preserve Float32 TablePhysics dimensions',
                       'Only unreachable S generator dependency replaced with precondition R',
                       'Replace SceneKit world normal and camera reads with already-world-space input vectors',
                       'Replace roughness binding with explicit input', 'Replace packed contactBall aliases with constant ball array',
                       'Save sampled E before analytic correction; expose E/S diagnostics',
                       'Stop before emission composition/native PBR/output transform'],
        'limits': 'Math kernel reference, not final SceneKit-compiled shader or complete pixel output; no performance claim',
        'rig': payload['rig'],
    }
    assert SOURCE.read_text() == source and CONSTANTS.read_text() == constants, 'Source changed during extraction'
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps({'output': str(out), 'source_sha256': manifest['source_sha256'], 'rig': payload['rig']}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    prepare(parser.parse_args().out.resolve())
