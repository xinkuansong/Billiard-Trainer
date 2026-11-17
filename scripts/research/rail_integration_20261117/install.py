"""Cover-install the validated production app on the user-connected iPhone."""
from pathlib import Path
import argparse,hashlib,json,os,plistlib,subprocess
p=argparse.ArgumentParser();p.add_argument('--app',type=Path,required=True);p.add_argument('--device',required=True);a=p.parse_args()
e=Path(os.environ['QIUJI_TEST_EVIDENCE']);w=Path(os.environ['QIUJI_TEST_WORK'])
assert os.environ['QIUJI_TEST_RUN_ID']
app=a.app.resolve();info=plistlib.loads((app/'Info.plist').read_bytes())
assert info['CFBundleIdentifier']=='com.xinkuan.qiuji'
assert info['DTPlatformName']=='iphoneos'
profile=plistlib.loads(subprocess.check_output(['security','cms','-D','-i',str(app/'embedded.mobileprovision')],stderr=subprocess.DEVNULL))
assert a.device in profile['ProvisionedDevices'],'Signing profile must cover selected iPhone'
asset=app/'MobileRailDirectVisibility-v1.bin';assert asset.stat().st_size==1024*512*4
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(e/'product.json').write_text(json.dumps({'app':str(app),'executableSHA256':sha(app/info['CFBundleExecutable']),'railAssetSHA256':sha(asset),'device':a.device,'bundle':info['CFBundleIdentifier'],'scope':'Production default; cover-install, no reset or test flags'},indent=2))
commands=[('signature',['codesign','--verify','--deep','--strict',str(app)]),('install',['xcrun','devicectl','device','install','app','--device',a.device,str(app),'--json-output',str(e/'install.json'),'--timeout','180']),('launch',['xcrun','devicectl','device','process','launch','--device',a.device,'--terminate-existing','--json-output',str(e/'launch.json'),'--timeout','30',info['CFBundleIdentifier']])]
for name,cmd in commands:
 (e/(name+'-command.json')).write_text(json.dumps(cmd))
 print(name+' started',flush=True)
 with (e/(name+'.log')).open('w') as log:subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=200)
 print(name+' completed',flush=True)
(e/'result.json').write_text(json.dumps({'installed':True,'launched':True,'device':a.device}))
