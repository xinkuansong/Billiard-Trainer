from pathlib import Path
import os,json,re,subprocess,hashlib
root=Path(__file__).resolve().parents[3]
work=Path(os.environ['QIUJI_TEST_WORK']);evidence=Path(os.environ['QIUJI_TEST_EVIDENCE'])
source=(root/'QiuJi/Core/Scene/MobileRailAppearance.swift').read_text()
finish=re.search(r'static let finish = """(.*?)"""',source,re.S).group(1)
attenuation=re.search(r'static let attenuation = "(.*?)"',source).group(1).replace('\\n','\n')
shader="#include <metal_stdlib>\nusing namespace metal;\nstruct Surf {float3 emission,diffuse,multiply,geometryNormal; float ambientOcclusion;};\nstruct Frame {float4x4 inverseViewTransform;};\nfloat3 v62PanelDiffuse(float3 p,float3 n){return float3(1); }\nkernel void validateRail(device float4 *pixels [[buffer(0)]],texture2d<float> bedRailVisibility [[texture(0)]],uint id [[thread_position_in_grid]]) {\nSurf _surface; Frame scn_frame; float3 p=float3(0,.8,0),n=float3(0,1,0),E=float3(1);\n"+attenuation+finish+"\npixels[id]=float4(E+_surface.emission,1);\n}"
# The harness supplies SceneKit structs; the shipping shader blocks are verbatim.
(evidence/'rail.metal').write_text(shader)
commands=[['xcrun','-sdk','iphoneos','metal','-std=ios-metal2.4','-mios-version-min=17.0','-c',str(evidence/'rail.metal'),'-o',str(work/'rail.air')],['xcrun','-sdk','iphoneos','metallib',str(work/'rail.air'),'-o',str(evidence/'rail.metallib')]]
(evidence/'commands.json').write_text(json.dumps(commands,indent=2))
with (evidence/'compile.log').open('w') as log:
 for command in commands: subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,check=True)
(evidence/'result.json').write_text(json.dumps({'target':'iOS17 / MSL2.4','compiled':True,'sourceSHA256':hashlib.sha256(source.encode()).hexdigest(),'scope':'Shader blocks compile and link; not device runtime appearance'}))
