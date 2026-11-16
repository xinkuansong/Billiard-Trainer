"""Test-only recovery of the signed R7d product after disk exhaustion."""
import hashlib, json, os, shutil, signal, subprocess, sys, time
from pathlib import Path
root=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(root/'scripts'));from mac_mini_queue import verify,tree_files,test_summary
parent=root/'output/local-test-runs/9ddd061c8ed4403f9d1c590283ef6db4'
evidence=Path(os.environ['QIUJI_TEST_EVIDENCE']);source=parent/'work/source'
assert shutil.disk_usage(root).free>=4*1024**3,'4 GiB test-only reserve; no build'
manifest=verify(parent/'work/snapshot');assert tree_files(source)==manifest['files']
command=json.loads((parent/'evidence/tests-command.json').read_text())
for i,arg in enumerate(command):
 for key,name in [('TEST_LOG','tests.log'),('TEST_JUNIT','tests.xml'),('TEST_RESULT_BUNDLE','tests.xcresult')]:
  if arg.startswith(key+'='):command[i]=key+'='+str(evidence/name)
(evidence/'command.json').write_text(json.dumps(command,indent=2))
(evidence/'parent.json').write_text(json.dumps({'parent':str(parent),'sameBinary':True,'build':'already succeeded; no rebuild','preflightFreeBytes':shutil.disk_usage(root).free,'manifest':manifest['snapshot_id']},indent=2))
shutil.copy2(__file__,evidence/'recovery.py');shutil.copy2(parent/'evidence/snapshot-manifest.json',evidence/'snapshot-manifest.json')
shutil.copytree(parent/'evidence/frozen-source',evidence/'frozen-source')
product=parent/'work/build/DerivedData/Build/Products/Debug-iphoneos'
identities={str(p.relative_to(product)):hashlib.sha256(p.read_bytes()).hexdigest() for p in product.rglob('*') if p.is_file() and (p.name in ['球迹','球迹.debug.dylib','QiuJiTests','ClothSpecularLTC-v1.bin'] or p.suffix=='.xctestrun')}
assert any(k.endswith('/球迹') for k in identities) and any(k.endswith('/QiuJiTests') for k in identities), 'Missing executable identity'
for p in product.parent.glob('*.xctestrun'):identities[p.name]=hashlib.sha256(p.read_bytes()).hexdigest()
(evidence/'binary-sha256.json').write_text(json.dumps(identities,indent=2))
with (evidence/'codesign.log').open('w') as log:
 subprocess.run(['codesign','--verify','--deep','--strict',str(product/'球迹.app')],stdout=log,stderr=subprocess.STDOUT,check=True)
with (evidence/'driver.log').open('w') as log:
 process=subprocess.Popen(command,cwd=source,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
 started=time.monotonic();samples=[];aborted=False
 while process.poll() is None:
  free=shutil.disk_usage(root).free;samples.append([time.monotonic()-started,free])
  if free<1024**3 or time.monotonic()-started>360:
   aborted=True;os.killpg(process.pid,signal.SIGINT)
   try:process.wait(timeout=30)
   except subprocess.TimeoutExpired:os.killpg(process.pid,signal.SIGTERM);process.wait(timeout=20)
   break
  time.sleep(2)
(evidence/'space.json').write_text(json.dumps({'samples':samples,'aborted':aborted,'exitCode':process.returncode},indent=2))
with (evidence/'export.log').open('w') as log:
 export=subprocess.run(['xcrun','xcresulttool','export','attachments','--path',str(evidence/'tests.xcresult'),'--output-path',str(evidence/'attachments')],stdout=log,stderr=subprocess.STDOUT)
assert not aborted and process.returncode==0,'Native test-only recovery failed'
assert export.returncode==0
summary=test_summary(evidence,['QiuJiTests/ClothSupportPerformanceResearchTests/testNativeClothLTCR7a','QiuJiTests/ClothSupportPerformanceResearchTests/testNativeClothLTCR7b']);assert summary['totalTestCount']==2
assert tree_files(source)==manifest['files'];verify(parent/'work/snapshot')
(evidence/'result.json').write_text(json.dumps({'status':'succeeded','snapshotVerified':True,'cloneVerified':True,'sameBuiltProduct':True})+'\n')
print(evidence)
