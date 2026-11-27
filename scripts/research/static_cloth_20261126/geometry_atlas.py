#!/usr/bin/env python3
"""S1: static planar light geometry for the original 64/8 sample paths.

The shader consumes a scene-independent atlas prepared once by the native
research host. Curved/out-of-domain receivers retain original functions.
"""
import hashlib
import json
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
source=(ROOT/"output/render-regression-20261126/phone.surface").read_text()
expected="ca7cae37f1722967d73caa13f64676f8fe8ce3109303934cae22e8fa03878b04"
assert hashlib.sha256(source.encode()).hexdigest()==expected
start=source.index("__attribute__((noinline)) ClothIntegral clothLTCIntegral")
end=source.index("#pragma arguments\ntexture2d<float> bedRailVisibility;",start)
body=source[start:end]

def replace(old,new,count):
    global body
    assert body.count(old)==count,(old,body.count(old))
    body=body.replace(old,new)

replace("clothLTCIntegral(","clothAtlasLTCIntegral(",1)
replace("clothReferenceIntegral(","clothAtlasReferenceIntegral(",1)
replace("texture2d<float> h18Table1) {",
        "texture2d<float> h18Table1,texture2d<float> staticGeometryAtlas) {",1)
replace("constant QiuJiContactUniforms &contactUniforms) {",
        "constant QiuJiContactUniforms &contactUniforms,texture2d<float> staticGeometryAtlas) {",1)
position="""float3 lp=v62EmitterCenter(panel)+v62EmitterU(panel)*(2.0*(float(ix)+0.5)/float(samplesX)-1.0)+v62EmitterV(panel)*(2.0*(float(iz)+0.5)/float(samplesZ)-1.0);
   float3 delta=lp-p;float r2=dot(delta,delta);float3 l=delta/sqrt(r2);"""
replace(position,"""float4 staticGeometry=readStaticClothGeometry(p,panel,ix,iz,shadowPossible,staticGeometryAtlas);
   float3 l=staticGeometry.xyz;float inverseDistance=staticGeometry.w;""",2)
replace("t>0.0 && t*t<r2","t>0.0 && t*inverseDistance<1.0",2)
replace("lightCellRadius*t/sqrt(r2)","lightCellRadius*t*inverseDistance",2)
replace("/r2*cellArea","*(inverseDistance*inverseDistance)*cellArea",3)
assert re.search(r"\br2\b",body) is None
helper="""
float4 readStaticClothGeometry(float3 p,int panel,int ix,int iz,bool nearSamples,texture2d<float> atlas) {
    int slot=nearSamples ? panel*32+ix*4+iz : 64+panel*4+ix*2+iz;
    float2 grid=float2(atlas.get_width()/8,atlas.get_height()/9);
    float2 cell=float2(slot%8,slot/8);
    float2 g=(p.xz+float2(1.27,0.635))/float2(2.54,1.27);
    float2 uv=(cell*grid+0.5+g*(grid-1.0))/float2(atlas.get_width(),atlas.get_height());
    constexpr sampler geometrySampler(coord::normalized,address::clamp_to_edge,filter::linear);
    return atlas.sample(geometrySampler,uv,level(0));
}
"""
candidate=source[:end]+helper+body+source[end:]
candidate=candidate.replace("#pragma arguments","#pragma arguments\ntexture2d<float> staticGeometryAtlas;",1)
gate="if(clothLTCCloseView && _surface.roughness>=0.4 && shadowPossible){"
assert candidate.count(gate)==1
candidate=candidate.replace(gate,"bool staticGeometryEligible=all(isfinite(p)) && abs(p.y-0.8)<0.0005 && abs(p.x)<=1.27 && abs(p.z)<=0.635;\n"+gate)
calls=[
    ("clothLTCIntegral(p,n,v,nv,_surface.roughness,nearLampMasks,contactUniforms,h18Table0,h18Table1)",
     "clothAtlasLTCIntegral(p,n,v,nv,_surface.roughness,nearLampMasks,contactUniforms,h18Table0,h18Table1,staticGeometryAtlas)"),
    ("clothReferenceIntegral(p,n,v,nv,a2,shadowPossible,nearLampMasks,contactUniforms)",
     "clothAtlasReferenceIntegral(p,n,v,nv,a2,shadowPossible,nearLampMasks,contactUniforms,staticGeometryAtlas)"),
]
for original,atlas in calls:
    old="ClothIntegral result="+original+";"
    assert candidate.count(old)==1
    candidate=candidate.replace(old,"ClothIntegral result;\nif(staticGeometryEligible) result="+atlas+";\nelse result="+original+";")
# Original functions are retained byte-for-byte for curved and domain fallback.
assert source[start:end] in candidate
out=ROOT/"output/static-cloth-20261126/static-geometry"
out.mkdir(parents=True,exist_ok=True)
path=out/"planar-atlas.surface";path.write_text(candidate)
metadata={"inputSHA256":expected,"outputSHA256":hashlib.sha256(candidate.encode()).hexdigest(),
    "samples":72,"grids":[[33,17],[65,33]],"format":"rgba16Float",
    "static":"Light directions and reciprocal distances at fixed planar receiver points",
    "dynamic":"Current ball visibility, actual normal/roughness/view, BRDF and LTC gate",
    "fallback":"Original exact functions outside planar eligibility",
    "risk":"Direction interpolation/FP16 can perturb soft shadows and highlights; full image evaluation required"}
path.with_suffix(".json").write_text(json.dumps(metadata,indent=2)+"\n")
print(json.dumps(metadata))
