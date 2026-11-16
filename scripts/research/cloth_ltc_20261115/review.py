"""R6: evaluate frozen R3 under the user-authorized perceptual review policy."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess


def main():
    p=argparse.ArgumentParser();p.add_argument('--work',type=Path,required=True);p.add_argument('--evidence',type=Path,required=True)
    p.add_argument('--width',type=int,default=1400);p.add_argument('--mode',choices=['cost','motion'],default='cost');p.add_argument('--pose',default='single-near')
    a=p.parse_args();root=Path(__file__).resolve().parents[3]
    archive=root/'output/local-test-runs/98e2942ea6ec449bb12b5ef7bf5f7b0a/evidence'
    package=root/'output/render-lowdim-20261113/native-scene-guardcombo-package-r2'
    assert shutil.disk_usage(root).free>3*1024**3,'3 GiB preflight for images and compiler'
    original=json.loads((archive/'source-identity.json').read_text())
    for relative in ['QiuJi/Core/Scene/StaticClothIrradiance.swift','QiuJi/Core/Scene/MobileReferenceLighting.swift','QiuJi/Core/Scene/TwoViewCamera.swift']:
        f=root/relative;assert hashlib.sha256(f.read_bytes()).hexdigest()==original[str(f)],f'Production drift: {f}'
    native=(archive/'main.swift').read_text()
    prefix=native[:native.index('var results=[[String:Any]]()')]
    shim=native[native.index('final class AngleTrainingScene'):]
    tail=Path(__file__).with_name('review.swift')
    config='\nlet reviewMode='+json.dumps(a.mode)+'\nlet reviewPose='+json.dumps(a.pose)+'\n'
    generated=prefix+config+tail.read_text()+'\n'+shim
    files=[Path(__file__),tail,archive/'main.swift',archive/'baseline.surface',archive/'integral.surface',
           archive/'ltc0.f32',archive/'ltc1.f32',archive/'fit.json',archive/'ltc.metal',root/'QiuJi/Core/Scene/StaticClothIrradiance.swift']
    def identity():return {str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
    before=identity()
    for d in [a.work,a.evidence]:
        d.mkdir(parents=True,exist_ok=True);(d/'main.swift').write_text(generated)
        shutil.copy2(root/'QiuJi/Core/Scene/StaticClothIrradiance.swift',d)
    for name in ['ltc0.f32','ltc1.f32','fit.json','ltc.metal','baseline.surface','integral.surface']:
        shutil.copy2(archive/name,a.evidence/('frozen-'+name if name.endswith('.surface') else name))
    (a.evidence/'source-identity.json').write_text(json.dumps(before,indent=2)+'\n')
    with (a.evidence/'compile.log').open('w') as log:
        subprocess.run(['xcrun','swiftc','-O','-D','DEBUG',str(a.work/'StaticClothIrradiance.swift'),str(a.work/'main.swift'),'-o',str(a.work/'review')],stdout=log,stderr=subprocess.STDOUT,check=True)
    with (a.evidence/'render.log').open('w') as log:
        subprocess.run([str(a.work/'review'),str(package),str(a.evidence),str(a.width),'600'],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=620)
    assert before==identity(),'Source drift during R6'
    print(a.evidence/'results.json',flush=True)


if __name__=='__main__':main()
