from pathlib import Path
import hashlib
import json
import sys
root=Path(__file__).resolve().parents[3]
compact='--compact' in sys.argv
dimensions=[64,32,16] if compact else [256,128,16]
out=root/'output/render-activity-20261113'/('c1-static-field-compact' if compact else 'c1-static-field')
out.mkdir(parents=True,exist_ok=True)
package=root/'output/render-lowdim-20261113/native-scene-guardcombo-package-r2'
base=(package/'candidate.surface').read_text()
emitter=base[base.index('float3 v62EmitterCenter('):base.index('float v62RectIrradiance(')]
generator='''#include <metal_stdlib>
using namespace metal;
'''+emitter+'''
kernel void generateField(texture3d<float,access::write> field0 [[texture(0)]],texture3d<float,access::write> field1 [[texture(1)]],uint3 id [[thread_position_in_grid]]) {
 uint3 size=uint3(field0.get_width(),field0.get_height(),field0.get_depth());
 if(any(id>=size)) return;
 float3 g=float3(id)/float3(size-1);
 float3 p=float3(-1.6+3.2*g.x,0.65+0.25*g.z,-0.95+1.9*g.y);
 for(int panel=0;panel<2;++panel) {
  float3 c=v62EmitterCenter(panel)-p,u=v62EmitterU(panel),w=v62EmitterV(panel);
  float3 v[4]={normalize(c-u-w),normalize(c-u+w),normalize(c+u+w),normalize(c+u-w)};
  float3 value=float3(0);
  for(int i=0;i<4;++i){float3 a=v[i],b=v[(i+1)%4];float3 edge=cross(a,b);float len=length(edge);
   if(len>0.0000001) value+=atan2(len,dot(a,b))*edge/len;
  }
  if(panel==0) field0.write(float4(value,1),id);else field1.write(float4(value,1),id);
 }
}
'''
helper='''
bool temporalFieldEligible(float3 p,float3 n) {
 if(!all(isfinite(p)) || p.x<-1.6 || p.x>1.6 || p.z<-0.95 || p.z>0.95 || p.y<0.65 || p.y>0.9) return false;
 for(int panel=0;panel<2;++panel) {
  float3 c=v62EmitterCenter(panel)-p,u=v62EmitterU(panel),w=v62EmitterV(panel);
  if(!(dot(c-u-w,n)>=0 && dot(c-u+w,n)>=0 && dot(c+u+w,n)>=0 && dot(c+u-w,n)>=0)) return false;
 }
 return true;
}
float3 temporalFieldDiffuse(float3 p,float3 n,texture3d<float> field0,texture3d<float> field1) {
 if(!temporalFieldEligible(p,n)) return v62PanelDiffuse(p,n);
 float3 g=float3((p.x+1.6)/3.2,(p.z+0.95)/1.9,(p.y-0.65)/0.25);
 float3 size=float3(field0.get_width(),field0.get_height(),field0.get_depth());
 float3 uv=(g*(size-1.0)+0.5)/size;
 constexpr sampler linearSampler(coord::normalized,address::clamp_to_edge,filter::linear);
 float3 a=field0.sample(linearSampler,uv,level(0)).xyz,b=field1.sample(linearSampler,uv,level(0)).xyz;
 float total=abs(dot(a,n))*0.5*v62EmitterGain(0)+abs(dot(b,n))*0.5*v62EmitterGain(1);
 return float3(1.0,0.985,0.96)*(12.96944123374527/3.14159265)*total;
}
'''
anchor='// Research-only mask predicate.'
candidate='#pragma arguments\ntexture3d<float> temporalField0;\ntexture3d<float> temporalField1;\n'+base
candidate=candidate.replace(anchor,helper+'\n'+anchor,1)
old='E=v62PanelDiffuse(p,n)*(E/max(unoccludedE,float3(0.000001)));'
assert candidate.count(old)==1
candidate=candidate.replace(old,'E=temporalFieldDiffuse(p,n,temporalField0,temporalField1)*(E/max(unoccludedE,float3(0.000001)));')
(out/'baseline.surface').write_text(base);(out/'candidate.surface').write_text(candidate);(out/'generate.metal').write_text(generator)
native=(package/'benchmark.swift').read_text()
prefix=native[:native.index('func calibrate()')];shim=native[native.index('final class AngleTrainingScene'):]
helper_source=(root/'scripts/research/cloth_temporal_20261113/scene_main.swift').read_text()
helpers=helper_source[helper_source.index('func install('):helper_source.index('func cache(')]
helpers+=helper_source[helper_source.index('func difference('):helper_source.index('try FileManager.default.createDirectory(at:output')]
main=(root/'scripts/research/cloth_temporal_20261113/field_main.swift').read_text()
main=main.replace('// __DIMENSIONS__', 'let fieldWidth='+str(dimensions[0])+',fieldHeight='+str(dimensions[1])+',fieldDepth='+str(dimensions[2]))
(out/'scene.swift').write_text(prefix+main.replace('// __HELPERS__',helpers)+'\n'+shim)
(out/'manifest.json').write_text(json.dumps({'identity':'static-rectangle-vector-field-v2-compact' if compact else 'static-rectangle-vector-field-v1','approximation':'trilinear world-position field; no normal/view/ball approximation in remaining shader','size':dimensions,'rgba32Textures':2,'payloadBytes':32*dimensions[0]*dimensions[1]*dimensions[2],'candidateSHA256':hashlib.sha256(candidate.encode()).hexdigest(),'generatorSHA256':hashlib.sha256(generator.encode()).hexdigest(),'productionAllowed':False},indent=2)+'\n')
print(out)
