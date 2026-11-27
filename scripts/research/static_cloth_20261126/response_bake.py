#!/usr/bin/env python3
"""S1b: preintegrated two-lamp response, with live view and per-lamp shadows."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
s=(ROOT/'output/render-regression-20261126/phone.surface').read_text()
assert hashlib.sha256(s.encode()).hexdigest()=='ca7cae37f1722967d73caa13f64676f8fe8ce3109303934cae22e8fa03878b04'
emitters=s[s.index('float3 v62EmitterCenter'):s.index('// Research-only mask predicate.')]
kernel='''#include <metal_stdlib>
using namespace metal;
'''+emitters+'''
kernel void staticResponse(texture2d<half,access::write> target [[texture(0)]],
 constant uint4 &par [[buffer(0)]],uint2 id [[thread_position_in_grid]]) {
 uint w=par.x,h=par.y;
 if(id.x>=w*16 || id.y>=h*35)return;
 if(par.z!=0){target.write(half4(0.8,0.8,0.8,0.8),id);return;}
 uint tileX=id.x/w,tileY=id.y/h;
 float3 p=float3(-1.27+2.54*float(id.x%w)/float(w-1),0.8,-0.635+1.27*float(id.y%h)/float(h-1));
 if(tileY==34){target.write(half4(v62RectIrradiance(p,float3(0,1,0),0),v62RectIrradiance(p,float3(0,1,0),1),0,1),id);return;}
 uint panel=tileY/17;float t=float(tileY%17)/16.0;
 float nv=max(0.001,1-t*t),angle=float(tileX)*6.28318530718/16;
 float3 v=float3(sqrt(1-nv*nv)*cos(angle),nv,sqrt(1-nv*nv)*sin(angle));
 float4 rough=float4(0.4,0.6,0.8,1),a2=rough*rough*rough*rough,S=0;
 for(int ix=0;ix<8;++ix)for(int iz=0;iz<4;++iz){
  float3 lp=v62EmitterCenter(panel)+v62EmitterU(panel)*(2*(float(ix)+0.5)/8-1)+v62EmitterV(panel)*(2*(float(iz)+0.5)/4-1);
  float3 delta=lp-p;float r2=dot(delta,delta);float3 l=delta/sqrt(r2),hv=normalize(l+v);
  float nl=max(0.001,l.y),nh=max(0.0,hv.y),vh=max(0.0,dot(v,hv));
  float4 denom=nh*nh*(a2-1)+1,D=a2/(3.14159265*denom*denom);
  float4 G=2*nv/(nv+sqrt(a2+(1-a2)*nv*nv))*2*nl/(nl+sqrt(a2+(1-a2)*nl*nl));
  float F=0.012+0.988*pow(1-vh,5.0);
  float weighted=max(0.0,l.y)*max(0.0,dot(v62EmitterNormal(panel),-l))/r2*v62EmitterArea(panel)/32*v62EmitterGain(panel);
  S+=weighted*D*G*F/(4*nv*nl);
 }
 target.write(half4(S),id);
}
'''
helper='''
float4 readBakedResponse(float3 p,int phi,int polar,int panel,texture2d<float> atlas){
 float2 grid=float2(atlas.get_width()/16,atlas.get_height()/35);
 float2 g=(p.xz+float2(1.27,0.635))/float2(2.54,1.27);
 float2 uv=(float2(phi,polar+panel*17)*grid+0.5+g*(grid-1))/float2(atlas.get_width(),atlas.get_height());
 constexpr sampler sam(coord::normalized,address::clamp_to_edge,filter::linear);
 return atlas.sample(sam,uv,level(0));
}
float4 bakedLampResponse(float3 p,float3 v,int panel,texture2d<float> atlas){
 float phi=atan2(v.z,v.x)*(16.0/6.28318530718);phi=phi<0?phi+16:phi;
 int a=int(floor(phi))%16,b=(a+1)%16;
 float polar=sqrt(1-clamp(v.y,0.001,1.0))*16;
 int c=min(15,int(floor(polar))),d=c+1;
 return mix(mix(readBakedResponse(p,a,c,panel,atlas),readBakedResponse(p,b,c,panel,atlas),fract(phi)),
  mix(readBakedResponse(p,a,d,panel,atlas),readBakedResponse(p,b,d,panel,atlas),fract(phi)),polar-float(c));
}
__attribute__((noinline)) ClothIntegral clothBakedResponse(float3 p,float3 v,float roughness,bool shadowPossible,uint2 masks,constant QiuJiContactUniforms &contactUniforms,texture2d<float> atlas){
 float3 E=0,S=0;float2 fixedDiffuse=readBakedResponse(p,0,0,2,atlas).xy;
 float r=clamp((roughness-0.4)/0.2,0.0,3.0);int ri=min(2,int(floor(r)));
 for(int panel=0;panel<2;++panel){
  float visibility=1;
  if(masks[panel]!=0u){
   float total=0,visible=0;
   int nx=shadowPossible?8:2,nz=shadowPossible?4:2;
   float cellArea=v62EmitterArea(panel)/float(nx*nz),radius=sqrt(cellArea/3.14159265);
   for(int ix=0;ix<nx;++ix)for(int iz=0;iz<nz;++iz){
    float3 lp=v62EmitterCenter(panel)+v62EmitterU(panel)*(2*(float(ix)+0.5)/float(nx)-1)+v62EmitterV(panel)*(2*(float(iz)+0.5)/float(nz)-1);
    float3 delta=lp-p;float r2=dot(delta,delta);float3 l=delta/sqrt(r2);float vis=1;
    uint remaining=masks[panel];while(remaining!=0u){uint index=ctz(remaining);remaining&=remaining-1u;
     float4 ball=contactUniforms.contactBalls[index];
     if(ball.w>0){float3 center=float3(ball.x,0.8+ball.z,ball.y),offset=center-p;float t=dot(offset,l);
      if(t>0 && t*t<r2){float dist=sqrt(max(0.0,dot(offset,offset)-t*t)),filterRadius=max(0.000001,radius*t/sqrt(r2));
       float blocked=1-smoothstep(0.028575-filterRadius,0.028575+filterRadius,dist);
       vis*=1-min(1.0,ball.w/0.85)*blocked;
      }
     }
    }
    float weight=max(0.0,l.y)*max(0.0,dot(v62EmitterNormal(panel),-l))/r2*cellArea;
    total+=weight;visible+=weight*vis;
   }
   visibility=visible/max(total,1e-6);
  }
  float4 response=bakedLampResponse(p,v,panel,atlas);
  float spec=mix(response[ri],response[ri+1],r-float(ri));
  E+=float3(1,0.985,0.96)*(12.96944123374527/3.14159265)*fixedDiffuse[panel]*visibility;
  S+=float3(1,0.985,0.96)*(12.96944123374527/3.14159265)*max(0.0,spec)*visibility;
 }
 return {E,float3(1),S};
}
'''
# Keep both original functions and non-planar output paths unchanged.
anchor='#pragma arguments\ntexture2d<float> bedRailVisibility;'
assert s.count(anchor)==1
candidate=s.replace(anchor,helper+anchor)
candidate=candidate.replace('#pragma arguments','#pragma arguments\ntexture2d<float> staticGeometryAtlas;',1)
gate='if(clothLTCCloseView && _surface.roughness>=0.4 && shadowPossible){'
assert candidate.count(gate)==1
candidate=candidate.replace(gate,'''bool bakedEligible=all(isfinite(p)) && abs(p.y-0.8)<0.0005 && abs(p.x)<=1.27 && abs(p.z)<=0.635 && v.y>0.001 && _surface.roughness>=0.4 && _surface.roughness<=1.0;
if(bakedEligible){ClothIntegral result=clothBakedResponse(p,v,_surface.roughness,shadowPossible,nearLampMasks,contactUniforms,staticGeometryAtlas);E=result.E;unoccludedE=result.unoccludedE;S=result.S;}
else '''+gate)
old='E=temporalFieldDiffuse(p,n,temporalField0,temporalField1)*(E/max(unoccludedE,float3(0.000001)));'
assert candidate.count(old)==1
candidate=candidate.replace(old,'if(!bakedEligible) '+old)
out=ROOT/'output/static-cloth-20261126/response-bake';out.mkdir(parents=True,exist_ok=True)
(out/'response.surface').write_text(candidate);(out/'response.metal').write_text(kernel)
metadata={'shaderSHA256':hashlib.sha256(candidate.encode()).hexdigest(),'kernelSHA256':hashlib.sha256(kernel.encode()).hexdigest(),'grids':[[17,9],[33,17]],'azimuth':16,'polar':17,'roughness':[.4,.6,.8,1.0],'static':'Per-lamp diffuse and full unoccluded GGX integral for a canonical flat normal','dynamic':'Current eye, actual roughness, per-lamp ball visibility with original sample grid and footprint, AO, albedo and nap','approximations':['Canonical up normal for planar lighting','View/roughness/spatial interpolation','Per-lamp diffuse visibility also modulates specular, not exact directional specular shadow'],'fallback':'Original full program outside planar/view/roughness eligibility','scope':'Research only; no installation'}
(out/'response.json').write_text(json.dumps(metadata,indent=2)+'\n');print(json.dumps(metadata))
