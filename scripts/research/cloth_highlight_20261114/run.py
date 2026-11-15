"""Native C1-baseline experiments; run inside local_test_lifecycle.py."""
from pathlib import Path
import argparse, hashlib, json, shutil, subprocess

p=argparse.ArgumentParser()
p.add_argument('--work',required=True,type=Path)
p.add_argument('--evidence',required=True,type=Path)
p.add_argument('--round',choices=['pipeline','field','split','direct','direct_marker','reduced','ablation'],default='pipeline')
p.add_argument('--width',type=int,default=700)
p.add_argument('--field-format',choices=['f32','f16'],default='f32')
p.add_argument('--field-resolution',choices=[32,64],type=int,default=64)
a=p.parse_args()
root=Path(__file__).resolve().parents[3]
package=root/'output/render-lowdim-20261113/native-scene-guardcombo-package-r2'
native=(package/'benchmark.swift').read_text()
prefix=native[:native.index('func calibrate()')]
shim=native[native.index('final class AngleTrainingScene'):]
old=(root/'scripts/research/cloth_temporal_20261113/scene_main.swift').read_text()
helpers=old[old.index('func difference('):old.index('try FileManager.default.createDirectory(at:output')]
main=(Path(__file__).parent/(a.round+'_main.swift')).read_text()
if a.round in ['split','reduced']:
 field_main=(Path(__file__).parent/'field_main.swift').read_text()
 main=main.replace('// __DRAW_HELPERS__',field_main[field_main.index('let headroom='):])
config='let repository=URL(fileURLWithPath:'+json.dumps(str(root))+')\n'
config+='let sampleFieldFormat:MTLPixelFormat = .'+('rgba16Float' if a.field_format=='f16' else 'rgba32Float')+'\n'
config+=f'let sampleFieldWidth={a.field_resolution},sampleFieldHeight={a.field_resolution//2},sampleFieldDepth={a.field_resolution//4}\n'
generated=prefix+'\n'+config+helpers+'\n'+main+'\n'+shim
(a.work/'main.swift').write_text(generated)
(a.evidence/'main.swift').write_text(generated)
src=root/'QiuJi/Core/Scene/StaticClothIrradiance.swift'
shutil.copy2(src,a.work/'StaticClothIrradiance.swift')
shutil.copy2(src,a.evidence/'StaticClothIrradiance.swift')
files=[src,package/'candidate.surface',package/'benchmark.swift',root/'QiuJi/Core/Scene/MobileReferenceLighting.swift',root/'QiuJi/Resources/StaticClothIrradiance-v1.bin']
identity={str(f.relative_to(root)):hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
(a.evidence/'source-identity.json').write_text(json.dumps(identity,indent=2)+'\n')
with (a.evidence/'compile.log').open('w') as log:
 subprocess.run(['xcrun','swiftc','-O','-D','DEBUG',str(a.work/'StaticClothIrradiance.swift'),str(a.work/'main.swift'),'-o',str(a.work/'benchmark')],stdout=log,stderr=subprocess.STDOUT,check=True)
with (a.evidence/'render.log').open('w') as log:
 subprocess.run([str(a.work/'benchmark'),str(package),str(a.evidence),str(a.width),'240'],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=260)
assert identity=={str(f.relative_to(root)):hashlib.sha256(f.read_bytes()).hexdigest() for f in files},'Source drift'
print(a.evidence/'results.json',flush=True)
