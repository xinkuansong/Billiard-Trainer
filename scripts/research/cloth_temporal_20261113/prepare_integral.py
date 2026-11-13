"""Exact full-horizon rectangle specialization, separate from rejected caching."""
from pathlib import Path
import json
import hashlib
import sys
root = Path(__file__).resolve().parents[3]
ring = '--ring' in sys.argv
out = root / ('output/render-activity-20261113/c1-integral-r2' if ring else 'output/render-activity-20261113/c1-integral')
out.mkdir(parents=True, exist_ok=True)
b3 = root / 'output/render-activity-20261113/b3'
base = (b3 / 'aa.metal').read_text()
start = base.index('float v62RectIrradiance(')
end = base.index('float3 v62PanelDiffuse(', start)
old = base[start:end]
anchor = 'float3 clipped[8];int count=0;'
assert old.count(anchor) == 1
fast = '''// Exact no-clipping branch: preserve each normalized corner and the
        // original edge order; only repeat normalization work is removed.
        if(dot(v[0],n)>=0.0 && dot(v[1],n)>=0.0 && dot(v[2],n)>=0.0 && dot(v[3],n)>=0.0) {
            float3 unit[4]={normalize(v[0]),normalize(v[1]),normalize(v[2]),normalize(v[3])};
            float integral=0.0;
            for(int i=0;i<4;++i) {
                float3 a=unit[i],b=unit[(i+1)%4];
                float3 c=cross(a,b);float lengthC=length(c);
                if(lengthC>0.0000001) integral+=atan2(lengthC,dot(a,b))*dot(c,n)/lengthC;
            }
            return abs(integral)*0.5;
        }
        '''
new = old.replace(anchor, fast+anchor)
if ring:
    new = old.replace('float integral=0.0;', 'float integral=0.0;\n    float3 firstUnit=normalize(clipped[0]);float3 previousUnit=firstUnit;')
    new = new.replace('float3 a=normalize(clipped[i]),b=normalize(clipped[(i+1)%count]);',
        'float3 a=previousUnit,b=(i+1==count)?firstUnit:normalize(clipped[i+1]);\n        previousUnit=b;')
panel_end = base.index('// Research-only mask predicate.', end)
panel = base[end:panel_end]
helpers = (new + panel).replace('v62RectIrradiance', 'temporalRectIrradiance').replace('v62PanelDiffuse', 'temporalPanelDiffuse')
ref_start = base.index('inline Result referenceAt(')
ref_end = base.index('inline float groupBRDF(', ref_start)
reference = base[ref_start:ref_end]
candidate = reference.replace('referenceAt(', 'heightSupportAt(', 1).replace('v62PanelDiffuse(', 'temporalPanelDiffuse(')
base_only = base[:ref_end]
wrappers = '''
kernel void evaluateReference(device const Input *input [[buffer(0)]],constant float4 *balls [[buffer(1)]],device Result *output [[buffer(2)]],constant uint &count [[buffer(3)]],uint i [[thread_position_in_grid]]) {if(i<count) output[i]=referenceAt(input[i],balls);}
kernel void evaluateHeightSupport(device const Input *input [[buffer(0)]],constant float4 *balls [[buffer(1)]],device Result *output [[buffer(2)]],constant uint &count [[buffer(3)]],uint i [[thread_position_in_grid]]) {if(i<count) output[i]=heightSupportAt(input[i],balls);}
'''
(out / 'candidate.metal').write_text(base_only + helpers + candidate + wrappers)
(out / 'aa.metal').write_text(base_only + reference.replace('referenceAt(', 'heightSupportAt(', 1) + wrappers)
surface = (root / 'output/render-lowdim-20261113/native-scene-guardcombo-package-r2/candidate.surface').read_text()
assert surface.count(old) == 1
(out / 'baseline.surface').write_text(surface)
(out / 'candidate.surface').write_text(surface.replace(old,new))
(out / 'manifest.json').write_text(json.dumps({
    'identity': 'clipped-ring-corner-reuse-v1' if ring else 'full-horizon-corner-reuse-v1',
    'newMechanism': 'Reuse the previously normalized corner in the unchanged dynamic clipped-edge loop; N normalizations instead of 2N per lamp.' if ring else 'Fully above-horizon branch uses 4 corner normalizations instead of 8 per lamp; clipped/back-facing path unchanged.',
    'numericPolicy': '12 radiometric channels, near/mask bit-identical under strict and fast math; native displayed pixel equality required.',
    'performancePolicy': 'AA then six-output lighting ABBA; at least 5 percent beyond AA; real material net cost before production.',
    'candidateSurfaceSHA256': hashlib.sha256((out/'candidate.surface').read_bytes()).hexdigest(),
    'candidateMSLSHA256': hashlib.sha256((out/'candidate.metal').read_bytes()).hexdigest(),
    'extraGPUBytes':0,'extraPasses':0,
}, indent=2)+'\n')
print(out)
