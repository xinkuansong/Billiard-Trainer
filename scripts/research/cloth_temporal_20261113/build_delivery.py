from pathlib import Path
import argparse,hashlib,json,subprocess
p=argparse.ArgumentParser();p.add_argument('--work',required=True);p.add_argument('--evidence',required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[3];work=Path(a.work);evidence=Path(a.evidence)
sources=['QiuJi/Core/Scene/StaticClothIrradiance.swift','QiuJi/Core/Scene/MobileReferenceLighting.swift','QiuJi/Core/Scene/AngleTrainingScene.swift','QiuJi.xcodeproj/project.pbxproj','QiuJi/Resources/StaticClothIrradiance-v1.bin']
sha=lambda path:hashlib.sha256(Path(path).read_bytes()).hexdigest()
before={s:sha(root/s) for s in sources}
with (evidence/'ios-build.log').open('w') as log:
    subprocess.run(['make','-f','scripts/Makefile','build-device-profile','BUILD_DIR='+str(work)],cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
app=work/'DeviceProfile/Build/Products/Debug-iphoneos/球迹.app'
asset=app/'StaticClothIrradiance-v1.bin'
assert sha(asset)==before['QiuJi/Resources/StaticClothIrradiance-v1.bin']
verify=subprocess.run(['codesign','--verify','--deep','--strict',str(app)],capture_output=True,text=True)
(evidence/'codesign.log').write_text(verify.stdout+verify.stderr)
assert verify.returncode==0
after={s:sha(root/s) for s in sources};assert before==after,'Build source drift'
(evidence/'build-identity.json').write_text(json.dumps({'buildSucceeded':True,'codesignVerified':True,'bundleAssetExact':True,'assetBytes':asset.stat().st_size,'binarySHA256':sha(app/'球迹'),'sourceSHA256':after,'phoneInstalled':False,'scope':'Debug iOS build; not runtime/phone rendering validation'},indent=2)+'\n')
print(evidence/'build-identity.json')
