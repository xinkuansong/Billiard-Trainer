from pathlib import Path
import hashlib,json,os,subprocess,sys,shutil
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
OUT=ROOT/'output/rail-aim-compensation-20261102'
work=Path(os.environ['QIUJI_TEST_WORK']);ev=Path(os.environ['QIUJI_TEST_EVIDENCE'])
previous=json.loads((OUT/'execution.json').read_text());src=Path(previous['work'])/'sources'
shutil.copytree(src,work/'sources');paths=sorted(map(str,(work/'sources').rglob('*.swift')))
sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
cmd=['xcrun','swiftc','-O','-whole-module-optimization','-num-threads','4','-D','DEBUG','-swift-version','5','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator',*paths,str(HERE/'followup/main.swift'),'-lz','-o',str(work/'Worker')]
(OUT/'followup-build-command.json').write_text(json.dumps(cmd,indent=2))
with (ev/'build.log').open('w') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,env=dict(os.environ,SDKROOT=sdk))
if r.returncode:print((ev/'build.log').read_text()[-7000:]);sys.exit(r.returncode)
print('FOLLOWUP BUILD COMPLETE',flush=True)
uid=sys.argv[1];subprocess.run(['xcrun','simctl','boot',uid],check=True)
try:
    subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
    with (OUT/'followup.log').open('w') as f:r=subprocess.run(['xcrun','simctl','spawn',uid,str(work/'Worker'),'unused',str(OUT)],stdout=f,stderr=subprocess.STDOUT)
finally:subprocess.run(['xcrun','simctl','shutdown',uid],check=True)
(OUT/'followup-execution.json').write_text(json.dumps(dict(exit=r.returncode,uid=uid,evidence=str(ev),source='same frozen sources as source-manifest.json'),indent=2))
print((OUT/'followup.log').read_text()[-2000:]);sys.exit(r.returncode)
