from pathlib import Path
import hashlib,json,os,plistlib,subprocess,sys,tarfile,shutil
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name
work=Path(os.environ['QIUJI_TEST_WORK']);ev=Path(os.environ['QIUJI_TEST_EVIDENCE']);src=work/'sources'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
paths=[];manifest={}
for p in sorted((ROOT/'QiuJi').rglob('*.swift')):
 rel=p.relative_to(ROOT);data=p.read_bytes();manifest[str(rel)]=sha(p)
 if b'@main' in data:
  assert p.name=='QiuJiApp.swift';data=data.replace(b'@main',b'// Research driver supplies main')
 dest=src/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data);paths.append(str(dest))
s=(ROOT/'QiuJi/Features/DefensePractice/DefenseEffect.swift').read_text()
body='        if fullyBlocked(cue, target, blockers) {'+s.split('        if fullyBlocked(cue, target, blockers) {',1)[1].split('    /// Upper bounds',1)[0]
body=body.replace('var assessment = DefenseAttackAssessment()','var assessment = windows ?? DefenseAttackAssessment()')
wrapper='import Foundation\nimport SceneKit\nextension DefenseEffect {\nstatic func regionState(cue:SCNVector3,target:SCNVector3,blockers:[SCNVector3],windows:DefenseAttackAssessment?=nil,opponent:Int=9) throws -> Self {\nvar timing=Timing();let usePrecomputedWindows=false\n'+body+'}\n'
p=src/'RegionState.swift';p.write_text(wrapper);paths.append(str(p))
for name in ['RegionFilter.swift']:
 p=src/name;shutil.copy2(HERE/name,p);paths.append(str(p))
main=work/'main.swift';shutil.copy2(HERE/'main.swift',main)
app=work/'RegionFilter.app';app.mkdir();binary=app/'Worker'
(app/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'local.qiuji.defense-region-filter','CFBundleExecutable':'Worker','CFBundlePackageType':'APPL'}))
(OUT/'source-manifest.json').write_text(json.dumps(manifest,indent=2))
with tarfile.open(OUT/'source-snapshot.tar.gz','w:gz') as ar:
 ar.add(src,arcname='sources');ar.add(main,arcname='main.swift');ar.add(HERE,arcname='tooling')
sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
cmd=['xcrun','swiftc','-O','-whole-module-optimization','-num-threads','4','-D','DEBUG','-swift-version','5','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator',*paths,str(main),'-lz','-o',str(binary)]
(ev/'build-command.json').write_text(json.dumps(cmd,indent=2));print('Compiling source-region filter',flush=True)
with (ev/'build.log').open('w') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,env=dict(os.environ,SDKROOT=sdk))
if r.returncode:print((ev/'build.log').read_text()[-5000:]);sys.exit(r.returncode)
identity=dict(production=manifest,tooling={p.name:sha(p) for p in HERE.iterdir() if p.suffix in ['.py','.swift']},inputManifestSHA256=sha(OUT/'input-manifest.json'),binarySHA256=sha(binary))
identity['id']=hashlib.sha256(json.dumps(identity,sort_keys=True).encode()).hexdigest()
(OUT/'run-identity.json').write_text(json.dumps(identity,indent=2))
(OUT/'run-paths.json').write_text(json.dumps(dict(work=str(work),binary=str(binary),evidence=str(ev)),indent=2))
frozen=work/'tooling';frozen.mkdir()
p=frozen/'controller.py';s=(HERE/'controller.py').read_text().replace('OUT=Path(__file__).resolve().parents[2]/"output"/Path(__file__).resolve().parent.name',f'OUT=Path({str(OUT)!r})');p.write_text(s)
subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','large-phone','--task',HERE.name,'--',sys.executable,str(p),'{udid}',str(binary),*sys.argv[1:]],check=True)
(OUT/'execution.json').write_text(json.dumps(dict(exitCode=0,sourceDrift=[p for p,h in manifest.items() if sha(ROOT/p)!=h],evidence=str(ev)),indent=2))
