"""Compile the owning Swift pipe geometry and compute a target-only lookup table."""
from pathlib import Path
import hashlib,json,os,plistlib,subprocess,sys,tarfile
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
OUT=Path(os.environ.get('PIPE_OUTPUT',str(ROOT/'output/pocket-pipe-precompute-20261104')))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
if len(sys.argv)>1 and sys.argv[1]=='worker':
 uid,binary=sys.argv[2:]
 subprocess.run(['xcrun','simctl','boot',uid],check=True)
 try:
  subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
  with (OUT/'run.log').open('w') as log:
   subprocess.run(['xcrun','simctl','spawn',uid,binary,str(OUT)],stdout=log,stderr=subprocess.STDOUT,check=True)
 finally:subprocess.run(['xcrun','simctl','shutdown',uid],check=True)
 sys.exit(0)
OUT.mkdir(exist_ok=True,parents=True)
work=Path(os.environ['QIUJI_TEST_WORK']);evidence=Path(os.environ['QIUJI_TEST_EVIDENCE']);src=work/'sources'
frozen=ROOT/'output/pocket-heatmap-20261104/r2'
manifest=json.loads((frozen/'source-manifest.json').read_text());paths=[]
# Historical unrelated app files only supply compilation dependencies. All owning
# geometry inputs must match current production; calculator uses current bytes.
geometry=['QiuJi/Core/Physics/'+n+'.swift' for n in ['TableGeometry','TableGeometry+QiuJi','BTPhysicsConstants','QuarticSolver','EngineNumerics','SCNVector3+Physics']]
for name in geometry:
 assert manifest[name]==sha(ROOT/name),('geometry drift',name)
with tarfile.open(frozen/'source-snapshot.tar.gz') as archive:
 for name,expected in manifest.items():
  data=archive.extractfile('sources/'+name.removeprefix('QiuJi/')).read()
  if name.endswith('/AngleSceneCalculator.swift'):
   base=data.decode().split('// Research-only extension')[0].rstrip()
   assert (ROOT/name).read_text().startswith(base),'Owning calculator base drift'
   data=(ROOT/name).read_bytes()
  else:
   raw=data.replace(b'// Research worker supplies main',b'@main') if name.endswith('/QiuJiApp.swift') else data
   assert hashlib.sha256(raw).hexdigest()==expected,name
  p=src/name.removeprefix('QiuJi/');p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data);paths.append(str(p))
current=geometry+['QiuJi/Core/Scene/AngleSceneCalculator.swift']
(OUT/'geometry-manifest.json').write_text(json.dumps({n:sha(ROOT/n) for n in current},indent=2))
(OUT/'source-manifest.json').write_text(json.dumps({str(Path(p).relative_to(src)):sha(Path(p)) for p in paths},indent=2))
main=work/'main.swift';main.write_bytes(Path(os.environ.get('PIPE_MAIN',str(HERE/'main.swift'))).read_bytes())
if 'PIPE_REFINE_INPUT' in os.environ:(OUT/'refine-input.json').write_bytes(Path(os.environ['PIPE_REFINE_INPUT']).read_bytes())
with tarfile.open(OUT/'source-snapshot.tar.gz','w:gz') as ar:
 ar.add(src,arcname='sources');ar.add(main,arcname='main.swift')
app=work/'PipeTable.app';app.mkdir();binary=app/'Worker'
(app/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'local.qiuji.pipe-precompute','CFBundleExecutable':'Worker','CFBundlePackageType':'APPL'}))
sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
cmd=['xcrun','swiftc','-O','-whole-module-optimization','-num-threads','4','-D','DEBUG','-swift-version','5','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator',*paths,str(main),'-lz','-o',str(binary)]
(evidence/'build-command.json').write_text(json.dumps(cmd,indent=2))
print('Compiling geometry worker',flush=True)
with (evidence/'build.log').open('w') as log:result=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,SDKROOT=sdk))
if result.returncode:
 print((evidence/'build.log').read_text()[-6000:]);sys.exit(result.returncode)
(OUT/'build.json').write_text(json.dumps({'exitCode':0,'binarySHA256':sha(binary),'evidence':str(evidence)}))
print('Build passed; computing grid',flush=True)
subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','large-phone','--task','pocket-pipe-precompute-20261104','--',sys.executable,__file__,'worker','{udid}',str(binary)],check=True)
assert all(sha(ROOT/n)==h for n,h in json.loads((OUT/'geometry-manifest.json').read_text()).items())
(OUT/'execution.json').write_text(json.dumps({'exitCode':0,'geometryDrift':False,'evidence':str(evidence),'scope':'target-only pipe geometry; no App installation or scoring changes'}))
print((OUT/'run.log').read_text()[-2000:])
