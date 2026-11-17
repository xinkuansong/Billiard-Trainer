from pathlib import Path
import os,json,subprocess,hashlib
root=Path(__file__).resolve().parents[3]
work=Path(os.environ['QIUJI_TEST_WORK']);evidence=Path(os.environ['QIUJI_TEST_EVIDENCE'])
helper=Path(__file__).with_name('bounce.metal').read_text()
shader='#include <metal_stdlib>\nusing namespace metal;\n'+helper+'\nkernel void checkRail(device float4 *v [[buffer(0)]],uint i [[thread_position_in_grid]]){v[i].w=railBedFormFactor(v[i].xyz,float3(0,0,1));}\n'
(evidence/'rail-helper.metal').write_text(shader)
commands=[['xcrun','-sdk','iphoneos','metal','-std=ios-metal2.4','-mios-version-min=17.0','-c',str(evidence/'rail-helper.metal'),'-o',str(work/'rail.air')],['xcrun','-sdk','iphoneos','metallib',str(work/'rail.air'),'-o',str(evidence/'rail.metallib')]]
(evidence/'commands.json').write_text(json.dumps(commands,indent=2))
with (evidence/'compile.log').open('w') as log:
 for command in commands:subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,check=True)
(evidence/'result.json').write_text(json.dumps({'target':'iOS 17 / MSL 2.4','helperCompiledAndLinked':True,'helperSHA256':hashlib.sha256(helper.encode()).hexdigest(),'scope':'New rectangle integration helper language compatibility only; not full iOS17 app/runtime acceptance'}))
