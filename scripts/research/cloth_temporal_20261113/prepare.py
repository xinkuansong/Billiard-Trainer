"""Exact far-light temporal reuse prototype; deliberately outside production."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'output/render-activity-20261113/c1-temporal'
B3 = ROOT / 'output/render-activity-20261113/b3'
OUT.mkdir(parents=True, exist_ok=True)
sha = lambda b: hashlib.sha256(b).hexdigest()
manifest = json.loads((B3 / 'current-reference/manifest.json').read_text())
live = ROOT / manifest['source']
assert sha(live.read_bytes()) == manifest['source_sha256'], 'Regenerate live reference first'
guard = json.loads((B3 / 'generated-guard.json').read_text())
guard_sha = sha(guard['guard'].encode())
assert guard_sha in (ROOT / 'QiuJi/Core/Scene/DailyClothSupportExperiment.swift').read_text()
original = (B3 / 'aa.metal').read_text()
prefix = original[:original.index('inline Result referenceAt(')]
reference = original[original.index('inline Result referenceAt('):original.index('inline float groupBRDF(')]
light = reference.replace('inline Result referenceAt(Input input, constant float4 *balls)',
    'inline Light cachedAt(Input input, constant float4 *balls, device const Light &cached, bool valid)')
anchor = 'bool diagnosticConeEligible='
assert light.count(anchor) == 1
light = light.replace(anchor, 'if(valid && !shadowPossible) return cached;\n' + anchor)
tail = '''return {float4(unoccludedE,float(shadowPossible)),float4(sampledE,float(shadowMask)),
            float4(E,0),float4(S,0)};'''
assert light.count(tail) == 1
light = light.replace(tail, 'return {float4(E,0),float4(S,0)};')
wrappers = '''
kernel void baseline(device const Input *inputs [[buffer(0)]], constant float4 *balls [[buffer(1)]],
 device Light *output [[buffer(2)]], constant uint &count [[buffer(3)]], uint i [[thread_position_in_grid]]) {
 if(i<count) { Result r=referenceAt(inputs[i],balls); output[i]={r.corrected,r.specular}; }
}
// The generation caller supplies an independently verified zero-ball buffer.
kernel void generate(device const Input *inputs [[buffer(0)]], constant float4 *emptyBalls [[buffer(1)]],
 device Light *cache [[buffer(2)]], constant uint &count [[buffer(3)]], uint i [[thread_position_in_grid]]) {
 if(i<count) { Result r=referenceAt(inputs[i],emptyBalls); cache[i]={r.corrected,r.specular}; }
}
kernel void consume(device const Input *inputs [[buffer(0)]], constant float4 *balls [[buffer(1)]],
 device Light *output [[buffer(2)]], constant uint &count [[buffer(3)]], device const Light *cache [[buffer(4)]],
 constant uint &valid [[buffer(5)]], uint i [[thread_position_in_grid]]) {
 if(i<count) output[i]=cachedAt(inputs[i],balls,cache[i],valid!=0);
}
kernel void classify(device const Input *inputs [[buffer(0)]], constant float4 *balls [[buffer(1)]],
 device uint *output [[buffer(2)]], constant uint &count [[buffer(3)]], uint i [[thread_position_in_grid]]) {
 if(i<count) output[i]=uint(referenceAt(inputs[i],balls).unoccluded.w);
}
'''
source = prefix + 'struct Light { float4 diffuse; float4 specular; };\n' + reference + light + wrappers
(OUT / 'temporal.metal').write_text(source)
(OUT / 'source.json').write_text(json.dumps({
    'baselineCommit': '354480b97', 'liveGeneratorSHA256': sha(live.read_bytes()),
    'guardSHA256': guard_sha, 'metalSHA256': sha(source.encode()),
    'cacheBytesPerInput': 32, 'scope': 'Math-only prerequisite; no SceneKit generation, raster, MSAA or input capture costs',
    'identity': 'exact-far-temporal-v1',
}, indent=2) + '\n')
print(OUT / 'temporal.metal')
