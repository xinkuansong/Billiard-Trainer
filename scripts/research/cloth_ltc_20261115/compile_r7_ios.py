"""Compile the exact shared integrator declarations for the minimum iOS target."""
import os, subprocess, json, re
from pathlib import Path
root=Path(__file__).resolve().parents[3]; work=Path(os.environ['QIUJI_TEST_WORK']); evidence=Path(os.environ['QIUJI_TEST_EVIDENCE'])
source=(root/'output/local-test-runs/892789dda3a545fe820251692c591e2c/evidence/production.surface').read_text()
declarations=source[:source.index('#pragma body')]
lines=[line for line in declarations.splitlines() if not (line.startswith('#pragma ') or re.fullmatch(r'texture[23]d<float> \w+;',line) or line=='QiuJiContactUniforms contactUniforms;')]
shader='#include <metal_stdlib>\nusing namespace metal;\n'+'\n'.join(lines)+'''
kernel void validateClothIntegrators(constant QiuJiContactUniforms &balls [[buffer(0)]],device float4 *out [[buffer(1)]],texture2d<float> lut0 [[texture(0)]],texture2d<float> lut1 [[texture(1)]],uint id [[thread_position_in_grid]]) {
 float3 p=float3(float(id)/1024.0,0.8,0),n=float3(0,1,0),v=normalize(float3(0,1,1));
 ClothIntegral a=clothLTCIntegral(p,n,v,0.70710678,0.8,uint2(1,1),balls,lut0,lut1);
 ClothIntegral b=clothReferenceIntegral(p,n,v,0.70710678,0.4096,true,uint2(1,1),balls);
 out[id]=float4(a.S+b.S,1);
}
'''
(evidence/'integrators.metal').write_text(shader)
commands=[['xcrun','-sdk','iphoneos','metal','-std=ios-metal2.4','-mios-version-min=17.0','-c',str(evidence/'integrators.metal'),'-o',str(work/'integrators.air')],['xcrun','-sdk','iphoneos','metallib',str(work/'integrators.air'),'-o',str(evidence/'integrators.metallib')]]
(evidence/'commands.json').write_text(json.dumps(commands,indent=2))
with (evidence/'compile.log').open('w') as log:
 for command in commands:subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,check=True)
(evidence/'result.json').write_text(json.dumps({'target':'iOS 17','language':'MSL 2.4','compiled':True,'scope':'integrators, not older-device GPU performance'})+'\n')
print('iOS 17 / MSL 2.4 integrators compiled and linked')
