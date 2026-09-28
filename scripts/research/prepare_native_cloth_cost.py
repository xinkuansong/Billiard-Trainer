"""Extract exported production cloth programs into a native Metal isolation fixture."""
import json,re,sys
from pathlib import Path
root,out=map(Path,sys.argv[1:3]);out.mkdir(exist_ok=True,parents=True)
for name,index in [('A',0),('S',3)]:
 s=json.loads((root/f'ab-specialized-2d-{index}-{name}-programs.json').read_text())['clothPrograms'][0]
 decl,body=s.split('#pragma body')
 decl=re.sub(r'#pragma arguments.*?#pragma declaration','',decl,flags=re.S)
 body=re.sub(r'contactUniforms.contactGroup(\d+)\[(\d+)\]',lambda m:f'balls[{int(m[1])*4+int(m[2])}]',body)
 body=re.sub(r'\(scn_frame.inverseViewTransform\s*\*\s*float4\(_surface.position,\s*1.0\)\).xyz','_surface.position',body)
 body=re.sub(r'\(scn_frame.inverseViewTransform\s*\*\s*float4\(_surface.normal,\s*0.0\)\).xyz','_surface.normal',body)
 body=body.replace('scn_frame.inverseViewTransform[3].xyz','float3(0,1.5,1)')
 source='''#include <metal_stdlib>
using namespace metal;
struct VS {float4 position [[position]];float2 uv;};
vertex VS vertexMain(uint id [[vertex_id]]) {float2 p[3]={float2(-1,-1),float2(3,-1),float2(-1,3)};return {float4(p[id],0,1),p[id]};}
struct Surface {float3 position;float3 normal;float4 diffuse;float4 multiply;float4 emission;float roughness;float ambientOcclusion;float metalness;};
'''+decl+'''
fragment half4 fragmentMain(VS in [[stage_in]], texture2d<float> bakedRailAO [[texture(0)]],constant float4* balls [[buffer(0)]]) {
Surface _surface;_surface.position=float3(in.uv.x*1.27,0.8,in.uv.y*0.635);_surface.normal=float3(0,1,0);
_surface.diffuse=float4(0.02,0.16,0.004,1);_surface.multiply=float4(1);_surface.emission=float4(0);_surface.roughness=0.8;_surface.ambientOcclusion=1;_surface.metalness=0;
'''+body+'''
return half4(half3(_surface.emission.rgb),1);
}
'''
 (out/f'cloth-{name}.metal').write_text(source)

# Local two-channel visibility consumes a separate bounded-quad pass.
s=(out/'cloth-S.metal').read_text()
s=s.replace('constant float4* balls [[buffer(0)]]', 'constant float4* balls [[buffer(0)]], texture2d<float> localVisibility [[texture(1)]]')
s=s.replace('visibility=1.0;', 'visibility=1.0;\nconstexpr sampler localSampler(coord::normalized,address::clamp_to_edge,filter::linear);\nvisibility=localVisibility.sample(localSampler,float2(p.x/2.54+0.5,0.5-p.z/1.27))[panel];')
s=re.sub(r'visibility \*= 1.0-v2SphereBlocked\([^;]+;', '',s)
(out/'cloth-L.metal').write_text(s)
