"""R7c: isolate LTC code generation, keeping the proven algorithm unchanged."""
import os, json, shutil, subprocess, hashlib, sys
from pathlib import Path
root=Path(__file__).resolve().parents[3]
work=Path(os.environ['QIUJI_TEST_WORK']); evidence=Path(os.environ['QIUJI_TEST_EVIDENCE'])
archive=root/'output/local-test-runs/98e2942ea6ec449bb12b5ef7bf5f7b0a/evidence'
source=(root/'output/local-test-runs/91af674af8ef4735bcbb6328df04363f/evidence/production.surface').read_text()
start=source.index('float3 h18T=v-n*dot(n,v);')
end=source.index('}else{\nfor(int panel=0;panel<2;++panel) {',start)
body=source[start:end].replace('_surface.roughness','roughness')
function='''
struct H18Integral { float3 E, unoccludedE, S; };
__attribute__((noinline)) H18Integral h18Separate(float3 p,float3 n,float3 v,float nv,float roughness,uint2 nearLampMasks,constant QiuJiContactUniforms &contactUniforms,texture2d<float> h18Table0,texture2d<float> h18Table1) {
float3 E=0,unoccludedE=0,S=0; const bool shadowPossible=true;
'''+body+'''
return {E,unoccludedE,S};
}
'''
candidate=source[:start]+'''H18Integral h18Result=h18Separate(p,n,v,nv,_surface.roughness,nearLampMasks,contactUniforms,h18Table0,h18Table1);
E=h18Result.E;unoccludedE=h18Result.unoccludedE;S=h18Result.S;
'''+source[end:]
candidate=candidate.replace('#pragma body',function+'\n#pragma body').replace('clothLTCHeight<=0.65','clothLTCHeight<=0.50')
if '--both' in sys.argv:
 original=(archive/'baseline.surface').read_text()
 a=original.rindex('for(int panel=0;panel<2;++panel) {');b=original.index('E=temporalFieldDiffuse',a)
 loop=original[a:b]
 function2="""
__attribute__((noinline)) H18Integral h18Original(float3 p,float3 n,float3 v,float nv,float a2,bool shadowPossible,uint2 nearLampMasks,constant QiuJiContactUniforms &contactUniforms) {
float3 E=0,unoccludedE=0,S=0;
"""+loop+"""
return {E,unoccludedE,S};
}
"""
 assert candidate.count(loop)==1
 candidate=candidate.replace(loop,"H18Integral old=h18Original(p,n,v,nv,a2,shadowPossible,nearLampMasks,contactUniforms);E=old.E;unoccludedE=old.unoccludedE;S=old.S;\n")
 candidate=candidate.replace('#pragma body',function2+'\n#pragma body')
(evidence/'isolated.surface').write_text(candidate)
(evidence/'prior.surface').write_text(source)
native=(archive/'main.swift').read_text(); prefix=native[:native.index('var results=[[String:Any]]()')]; shim=native[native.index('final class AngleTrainingScene'):]
tail=r'''
let isolated=try String(contentsOf:output.appendingPathComponent("isolated.surface"),encoding:.utf8)
var rows=[[String:Any]]()
for pose in ["single-near","single-low","scatter-overview"] {
 let scene=try makeScene(package),target=try Target(scene.renderer,maxWidth,maxWidth*4/7)
 for m in scene.mats {field.install(on:m);for i in 0..<2{m.setValue(SCNMaterialProperty(contents:textures[i]),forKey:"h18Table\(i)")}}
 _=input(scene,pose,0)
 install(scene,baseline);_=try target.batch(3);let a=try target.read()
 install(scene,isolated);_=try target.batch(3);let b=try target.read()
 try need(counts(b)["green"]!>100 && counts(b)["magenta"]==0,"Shader valid")
 try target.save(a,pose+"-A");try target.save(b,pose+"-B")
 var times=[[String:Any]]()
 for cycle in 0..<6 {for kind in cycle%2==0 ? ["AA","AB"]:["AB","AA"] {
  for arm in cycle%2==0 ? [false,true,true,false]:[true,false,false,true] {
   install(scene,kind=="AB" && arm ? isolated:baseline)
   for f in 0..<24 {_=input(scene,pose,f%6);_=try target.frame()}
   var samples=[FrameTime]()
   for f in 0..<48 {_=input(scene,pose,f%6);samples.append(try target.frame())}
   times.append(["kind":kind,"cycle":cycle,"arm":arm ? "B":"A","frames":samples.map{$0.json},"thermal":ProcessInfo.processInfo.thermalState.rawValue])
  }
 }}
 rows.append(["pose":pose,"difference":difference(a,b),"times":times]);try write(rows,"results.json");print(pose);fflush(stdout)
}
'''
(work/'main.swift').write_text(prefix+tail+'\n'+shim); shutil.copy2(work/'main.swift',evidence/'main.swift')
for name in ['ltc0.f32','ltc1.f32','ltc.metal','fit.json']:
 shutil.copy2(archive/name,evidence/name)
swift=root/'QiuJi/Core/Scene/StaticClothIrradiance.swift';shutil.copy2(swift,evidence/swift.name)
with (evidence/'compile.log').open('w') as log:
 subprocess.run(['xcrun','swiftc','-O','-D','DEBUG',str(swift),str(work/'main.swift'),'-o',str(work/'bench')],stdout=log,stderr=subprocess.STDOUT,check=True)
with (evidence/'render.log').open('w') as log:
 subprocess.run([str(work/'bench'),str(root/'output/render-lowdim-20261113/native-scene-guardcombo-package-r2'),str(evidence),'1400','180'],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=190)
print(evidence/'results.json')
