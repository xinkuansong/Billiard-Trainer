from pathlib import Path
import hashlib,json,os,plistlib,subprocess,shutil
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=Path(os.environ.get('THREE_BALL_BUILD_OUTPUT',str(ROOT/'output'/HERE.name)));BASE=ROOT/'research/two-ball-strike-full-20261024'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def build():
 work=Path(os.environ['QIUJI_TEST_WORK']);ev=Path(os.environ['QIUJI_TEST_EVIDENCE']);src=work/'source';src.mkdir()
 current={p.name:p for p in (ROOT/'QiuJi').rglob('*.swift')};sources=[];bindings=[];changes=[]
 for p in sorted((BASE/'native-source').glob('*.swift')):
  q=current.get(p.name)
  relevant=q and ('/Physics/' in str(q) or any(s in p.name for s in ('AngleSceneCalculator','CueClearance','CueStrikeAccess','TableGeometry','AccuracyTipSelector')))
  if relevant:
   bindings.append(dict(path=str(q.relative_to(ROOT)),sha256=sha(q)))
   if sha(p)!=sha(q):
    assert p.name=='BTPhysicsConstants.swift','Unreviewed kernel drift '+str(q)
    dest=src/p.name;shutil.copy2(q,dest);sources.append(dest);changes.append(dest);continue
  sources.append(p)
 app=work/'ThreeBallWorker.app';app.mkdir()
 (app/'Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier='local.qiuji.three-ball-research',CFBundleExecutable='Worker',CFBundleName='ThreeBallResearch',CFBundlePackageType='APPL')))
 for p in (BASE/'Worker.app').iterdir():
  if p.name not in ('Worker','Info.plist','_CodeSignature'):(app/p.name).symlink_to(p)
 sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip();entry=HERE/'main.swift'
 commands=[];objs=[]
 for primary in changes+[entry]:
  obj=work/(primary.stem+'.o');objs.append(obj)
  commands.append(['xcrun','swiftc','-frontend','-c',*[str(p) for p in sources if p!=primary],'-primary-file',str(primary),*([str(entry)] if primary!=entry else []),'-sdk',sdk,'-target','arm64-apple-ios17.0-simulator','-swift-version','5','-O','-D','DEBUG','-module-name','QiuJi','-o',str(obj)])
 skip={p.name for p in objs};old=[p for p in sorted((BASE/'objects').glob('*.o')) if p.name not in skip]
 commands.append(['xcrun','swiftc','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator',*map(str,old+objs),'-lz','-Xlinker','-syslibroot','-Xlinker',sdk,'-o',str(app/'Worker')])
 (OUT/'source-binding.json').write_text(json.dumps(dict(production=bindings,entrySHA=sha(entry),recompiled=[p.name for p in changes],frozenSources={p.name:sha(p) for p in sources},objects={p.name:sha(p) for p in old},note='Unused UI/Rack frozen objects retained for linking; direct ShotPredictor/physics/geometry/access source binding exact. BTPhysicsConstants rebuilt from current source.'),indent=2))
 (ev/'build-commands.json').write_text(json.dumps(commands,indent=2))
 with (ev/'build.log').open('w') as log:
  for cmd in commands:
   result=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,SDKROOT=sdk))
   if result.returncode:raise RuntimeError((ev/'build.log').read_text()[-5000:])
 return app/'Worker'
