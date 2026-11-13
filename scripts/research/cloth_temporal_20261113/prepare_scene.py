"""Build a bounded native SceneKit research consumer, never a production patch."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[3]
out = root / 'output/render-activity-20261113/c1-temporal/scene'
out.mkdir(parents=True, exist_ok=True)
package = root / 'output/render-lowdim-20261113/native-scene-guardcombo-package-r2'
baseline = (package / 'candidate.surface').read_text()
assert hashlib.sha256(baseline.encode()).hexdigest() == 'ca5acc70043f0da620e2c6501188063c78027c8e26b62233d128ced01f81aabd'
arguments = '''#pragma arguments
texture2d_array<float, access::read_write> temporalCache [[raster_order_group(0)]];
float4 temporalViewport;
float temporalEnabled;
'''
lookup = '''
// Research only: projected pixel addressing must be independently audited before
// production. ROG orders only genuinely overlapping raster pixel invocations.
float4 temporalClip=scn_frame.projectionTransform*float4(_surface.position,1.0);
float2 temporalScreen=(temporalClip.xy/temporalClip.w*float2(0.5,-0.5)+0.5)*temporalViewport.xy;
int2 temporalPixel=int2(floor(temporalScreen))-int2(temporalViewport.zw);
bool temporalEligible=temporalEnabled>0.5 && !shadowPossible && all(isfinite(temporalScreen)) &&
 all(temporalPixel>=int2(0)) && temporalPixel.x<int(temporalCache.get_width()) && temporalPixel.y<int(temporalCache.get_height());
float4 temporalP=float4(p,_surface.roughness),temporalN=float4(n,1),temporalV=float4(v,1);
bool temporalHit=false;
if(temporalEligible && temporalEnabled>1.5) {
 uint2 pixel=uint2(temporalPixel);
 temporalHit=all(as_type<uint4>(temporalCache.read(pixel,0))==as_type<uint4>(temporalP)) &&
 all(as_type<uint4>(temporalCache.read(pixel,1))==as_type<uint4>(temporalN)) &&
 all(as_type<uint4>(temporalCache.read(pixel,2))==as_type<uint4>(temporalV));
 if(temporalHit) {E=temporalCache.read(pixel,3).xyz;S=temporalCache.read(pixel,4).xyz;}
}
if(!temporalHit) {
'''
store = '''
 if(temporalEligible && temporalEnabled<1.5) {
  uint2 pixel=uint2(temporalPixel);
  temporalCache.write(temporalP,pixel,0);temporalCache.write(temporalN,pixel,1);temporalCache.write(temporalV,pixel,2);
  temporalCache.write(float4(E,1),pixel,3);temporalCache.write(float4(S,1),pixel,4);
 }
}
'''
candidate = arguments.replace('access::read_write', 'access::read').replace(' [[raster_order_group(0)]]', '') + baseline
anchor = 'bool diagnosticConeEligible='
assert candidate.count(anchor) == 1
candidate = candidate.replace(anchor, lookup + anchor)
anchor = '// v64ClothNap:'
assert candidate.count(anchor) == 1
candidate = candidate.replace(anchor, '}\n' + anchor)
generator = arguments + baseline
# Keep the generation shader's original lighting calculation unconditional.
generation_store = lookup.split('bool temporalHit=false;')[0] + store.removesuffix('}\n')
generator = generator.replace(anchor, generation_store + anchor)
(out / 'baseline.surface').write_text(baseline)
(out / 'candidate.surface').write_text(candidate)
(out / 'generate.surface').write_text(generator)
native = (package / 'benchmark.swift').read_text()
prefix = native[:native.index('func calibrate()')]
prefix = prefix.replace('let packageManifest =', 'let packageManifest =', 1)
shim = native[native.index('final class AngleTrainingScene'):]
main = (root / 'scripts/research/cloth_temporal_20261113/scene_main.swift').read_text()
(out / 'benchmark.swift').write_text(prefix + main + '\n' + shim)
(out / 'manifest.json').write_text(json.dumps({
    'baselineSurfaceSHA256': hashlib.sha256(baseline.encode()).hexdigest(),
    'candidateSurfaceSHA256': hashlib.sha256(candidate.encode()).hexdigest(),
    'package': str(package), 'cacheMaximumPixels': 512*512, 'cacheBytesPerPixel': 80,
    'scope': 'Native isolated real USDZ/TaiNi, MSAA4/HDR; projected-address prototype not production-safe',
    'knownOpen': 'pixel addressing/ROG domain, per-sample shading, SCNView renderer concurrency and automatic lifecycle',
}, indent=2) + '\n')
print(out / 'benchmark.swift')
