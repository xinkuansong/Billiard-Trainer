"""H17: native compute reuse; run through local_test_lifecycle."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--work', type=Path, required=True)
    p.add_argument('--evidence', type=Path, required=True)
    p.add_argument('--width', type=int, default=700)
    p.add_argument('--round', default='initial', choices=['initial', 'refine', 'final'])
    a = p.parse_args()
    root = Path(__file__).resolve().parents[3]
    package = root / 'output/render-lowdim-20261113/native-scene-guardcombo-package-r2'
    assert shutil.disk_usage(root).free >= 2 * 1024**3, 'Need 2 GiB free for bounded experiment'
    native = (package / 'benchmark.swift').read_text()
    prefix = native[:native.index('func calibrate()')]
    prefix = prefix.replace('    func frame() throws -> FrameTime {', '    var beforeRender: ((MTLCommandBuffer) throws -> Void)?\n    func frame() throws -> FrameTime {')
    prefix = prefix.replace('        renderer.render(atTime:1,viewport:', '        try beforeRender?(command)\n        renderer.render(atTime:1,viewport:')
    pose_source = (root/'QiuJi/Core/Scene/TwoViewCamera.swift').read_text()
    start=pose_source.index('    struct Pose {'); depth=0; end=None
    for i in range(pose_source.index('{',start),len(pose_source)):
        depth += (pose_source[i]=='{') - (pose_source[i]=='}')
        if depth==0: end=i+1; break
    prefix += '\nenum ProductionPose {\n'+pose_source[start:end]+'\n}\n'

    shim = native[native.index('final class AngleTrainingScene'):]
    old = (root / 'scripts/research/cloth_temporal_20261113/scene_main.swift').read_text()
    helpers = old[old.index('func difference('):old.index('try FileManager.default.createDirectory(at:output')]
    helpers = helpers.replace('s.eye.simdLook(at:SIMD3(0,0.8,0));', '''let delta=s.eye.simdPosition-SIMD3<Float>(0,0.8,0)
 let yaw=atan2(delta.z,delta.x),pitch = -atan2(delta.y,sqrt(delta.x*delta.x+delta.z*delta.z))
 let pose=ProductionPose.Pose.looking(eye:s.eye.simdPosition,yaw:yaw,pitch:pitch,fov:50)
 precondition(abs(pose.transform.columns.0.y)<1e-6 && simd_dot(pose.forward,simd_normalize(-delta))>0.99999)
 s.eye.simdTransform=pose.transform;''')
    source = Path(__file__).with_name('main.swift')
    config = 'let repository=URL(fileURLWithPath:' + json.dumps(str(root)) + ')\n'
    config += 'let experimentRound=' + json.dumps(a.round) + '\n'
    generated = prefix + '\n' + config + helpers + '\n' + source.read_text() + '\n' + shim
    files = [source, Path(__file__), root/'QiuJi/Core/Scene/StaticClothIrradiance.swift',
             root/'QiuJi/Core/Scene/MobileReferenceLighting.swift', root/'QiuJi/Core/Scene/TwoViewCamera.swift',
             root/'QiuJi/Resources/StaticClothIrradiance-v1.bin', package/'benchmark.swift',
             package/'candidate.surface', package/'assets/table.usdz', package/'assets/rail-ao.png',
             package/'reference-environment.hdr', package/'rig.json',
             root/'scripts/research/cloth_temporal_20261113/scene_main.swift']
    def identity():
        return {str(f.relative_to(root)): hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
    before = identity()
    for d in [a.work, a.evidence]:
        d.mkdir(parents=True, exist_ok=True)
        (d/'main.swift').write_text(generated)
        shutil.copy2(root/'QiuJi/Core/Scene/StaticClothIrradiance.swift', d)
    (a.evidence/'source-identity.json').write_text(json.dumps(before, indent=2)+'\n')
    # Independent algebra check, including zero/partial/full visibility.
    import random
    rng = random.Random(20261114)
    maximum = 0.0
    for _ in range(1000):
        weights = [rng.random() for _ in range(64)]
        responses = [rng.random() for _ in range(64)]
        visibility = [rng.choice([0.0, 1.0, rng.random()]) for _ in range(64)]
        original = sum(w*v*b for w,v,b in zip(weights,visibility,responses))
        separated = sum(w*b for w,b in zip(weights,responses)) + sum(w*(v-1)*b for w,v,b in zip(weights,visibility,responses) if v<1)
        maximum = max(maximum,abs(original-separated))
    assert maximum < 1e-12
    (a.evidence/'algebra-preflight.json').write_text(json.dumps({'cases':1000,'maximumDoubleError':maximum,'nearOcclusionSamples':64,'farSamples':8,'world':'XZ horizontal, Y up, metres','bedY':0.8,'ballCenterY':0.8+0.028575},indent=2)+'\n')
    with (a.evidence/'compile.log').open('w') as log:
        subprocess.run(['xcrun','swiftc','-O','-D','DEBUG',str(a.work/'StaticClothIrradiance.swift'),str(a.work/'main.swift'),'-o',str(a.work/'benchmark')],stdout=log,stderr=subprocess.STDOUT,check=True)
    with (a.evidence/'render.log').open('w') as log:
        subprocess.run([str(a.work/'benchmark'),str(package),str(a.evidence),str(a.width),'420'],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=440)
    assert before == identity(), 'Source or asset drift during run'
    print(a.evidence/'results.json',flush=True)


if __name__ == '__main__':
    main()
