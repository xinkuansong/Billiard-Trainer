"""H18 native SceneKit fixture. Invoke through local_test_lifecycle."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--work',type=Path,required=True);p.add_argument('--evidence',type=Path,required=True)
    p.add_argument('--fit',type=Path,required=True);p.add_argument('--width',type=int,default=700)
    p.add_argument('--quality-only',action='store_true')
    a=p.parse_args();root=Path(__file__).resolve().parents[3]
    package=root/'output/render-lowdim-20261113/native-scene-guardcombo-package-r2'
    assert shutil.disk_usage(root).free>2*1024**3
    native=(package/'benchmark.swift').read_text();prefix=native[:native.index('func calibrate()')]
    pose=(root/'QiuJi/Core/Scene/TwoViewCamera.swift').read_text();start=pose.index('    struct Pose {');depth=0
    for i in range(pose.index('{',start),len(pose)):
        depth+=(pose[i]=='{')-(pose[i]=='}')
        if depth==0:end=i+1;break
    prefix+='\nenum ProductionPose {\n'+pose[start:end]+'\n}\n'
    old=(root/'scripts/research/cloth_temporal_20261113/scene_main.swift').read_text()
    helpers=old[old.index('func difference('):old.index('try FileManager.default.createDirectory(at:output')]
    helpers=helpers.replace('s.eye.simdLook(at:SIMD3(0,0.8,0));', '''let delta=s.eye.simdPosition-SIMD3<Float>(0,0.8,0)
 let yaw=atan2(delta.z,delta.x),pitch = -atan2(delta.y,sqrt(delta.x*delta.x+delta.z*delta.z))
 let pose=ProductionPose.Pose.looking(eye:s.eye.simdPosition,yaw:yaw,pitch:pitch,fov:50)
 precondition(abs(pose.transform.columns.0.y)<1e-6 && simd_dot(pose.forward,simd_normalize(-delta))>0.99999)
 s.eye.simdTransform=pose.transform;''')
    shim=native[native.index('final class AngleTrainingScene'):]
    source=Path(__file__).with_name('main.swift')
    generated=prefix+'\nlet repository=URL(fileURLWithPath:'+json.dumps(str(root))+')\nlet measurePerformance='+('false' if a.quality_only else 'true')+'\n'+helpers+'\n'+source.read_text()+'\n'+shim
    table_names=[f'ltc{i}.f32' for i in range(2*int(json.loads((a.fit/'fit.json').read_text()).get('lobes',1)))]
    files=[Path(__file__),source,Path(__file__).with_name('ltc.metal'),root/'QiuJi/Core/Scene/StaticClothIrradiance.swift',
           root/'QiuJi/Core/Scene/MobileReferenceLighting.swift',root/'QiuJi/Core/Scene/TwoViewCamera.swift',
           package/'benchmark.swift',package/'candidate.surface',package/'assets/table.usdz',
           root/'QiuJi/Resources/StaticClothIrradiance-v1.bin',a.fit/'fit.json']+[a.fit/name for name in table_names]
    def identity():return {str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
    before=identity()
    for d in [a.work,a.evidence]:
        d.mkdir(parents=True,exist_ok=True);(d/'main.swift').write_text(generated)
        shutil.copy2(root/'QiuJi/Core/Scene/StaticClothIrradiance.swift',d)
    for name in table_names+['fit.json']:shutil.copy2(a.fit/name,a.evidence/name)
    shutil.copy2(Path(__file__).with_name('ltc.metal'),a.evidence/'ltc.metal')
    (a.evidence/'source-identity.json').write_text(json.dumps(before,indent=2)+'\n')
    with (a.evidence/'compile.log').open('w') as log:
        subprocess.run(['xcrun','swiftc','-O','-D','DEBUG',str(a.work/'StaticClothIrradiance.swift'),str(a.work/'main.swift'),'-o',str(a.work/'benchmark')],stdout=log,stderr=subprocess.STDOUT,check=True)
    with (a.evidence/'render.log').open('w') as log:
        subprocess.run([str(a.work/'benchmark'),str(package),str(a.evidence),str(a.width),'600'],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=620)
    assert before==identity(),'Source drift'
    print(a.evidence/'results.json',flush=True)


if __name__=='__main__':main()
