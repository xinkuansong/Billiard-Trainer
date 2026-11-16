from pathlib import Path
import os,json,re,subprocess,hashlib
root=Path(__file__).resolve().parents[3]
work=Path(os.environ['QIUJI_TEST_WORK']);evidence=Path(os.environ['QIUJI_TEST_EVIDENCE'])
source=(root/'QiuJi/Core/Scene/MobileReferenceLighting.swift').read_text()
fragment=re.search(r'static let trainingBrightnessFragment = """(.*?)"""',source,re.S).group(1)
shader='#include <metal_stdlib>\nusing namespace metal;\nstruct Output { float4 color; };\nkernel void validateBrightness(device float4 *pixels [[buffer(0)]],uint id [[thread_position_in_grid]]) {\nOutput _output;_output.color=pixels[id];\n'+fragment+'\npixels[id]=_output.color;\n}'
(evidence/'brightness.metal').write_text(shader)
commands=[['xcrun','-sdk','iphoneos','metal','-std=ios-metal2.4','-mios-version-min=17.0','-c',str(evidence/'brightness.metal'),'-o',str(work/'brightness.air')],['xcrun','-sdk','iphoneos','metallib',str(work/'brightness.air'),'-o',str(evidence/'brightness.metallib')]]
(evidence/'commands.json').write_text(json.dumps(commands,indent=2))
with (evidence/'compile.log').open('w') as log:
 for command in commands:subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,check=True)
(evidence/'result.json').write_text(json.dumps({'target':'iOS 17 / MSL 2.4','compiled':True,'sourceSHA256':hashlib.sha256(source.encode()).hexdigest(),'scope':'Exact brightness block compiles and links; not older-device visual acceptance'}))
