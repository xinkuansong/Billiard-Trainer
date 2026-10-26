from pathlib import Path
import hashlib,json,os,subprocess,plistlib,shutil
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output/rack-production-integration-20261026';BASE=ROOT/'research/two-ball-strike-full-20261024'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def build():
 work=Path(os.environ['QIUJI_TEST_WORK']);ev=Path(os.environ['QIUJI_TEST_EVIDENCE']);sources=work/'sources';sources.mkdir();paths=[]
 current={p.name:p for p in (ROOT/'QiuJi').rglob('*.swift')};replacements=['RackLayout.swift','BreakFlowRunner.swift'];bindings=[];exceptions=json.loads((ROOT/'output/rack-power-sweep-20261026/source-exceptions.json').read_text())
 for old in sorted((BASE/'native-source').glob('*.swift')):
  q=current.get(old.name);new=sources/old.name;shutil.copy2(q if old.name in replacements else old,new);paths.append(new)
  if q and ('/Physics/' in str(q) or '/Rack/' in str(q) or any(s in old.name for s in ['AngleSceneCalculator','BTPhysics','CueClearance','CueStrikeAccess','TableGeometry','ShotFacts','AccuracyTipSelector'])):
   if old.name not in replacements and sha(q)!=sha(old):
    e=next(e for e in exceptions if e['path']==str(q.relative_to(ROOT)));assert sha(q)==e['currentSHA256'] and sha(old)==e['frozenSHA256']
   bindings.append(dict(path=str(q.relative_to(ROOT)),sha256=sha(q)))
 app=work/'Worker.app';app.mkdir();(app/'Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier='local.qiuji.rack-integration',CFBundleExecutable='Worker',CFBundlePackageType='APPL')))
 for p in (BASE/'Worker.app').iterdir():
  if p.name not in ['Worker','Info.plist','_CodeSignature']:(app/p.name).symlink_to(p)
 sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip();commands=[];objects=[]
 for name in replacements+['main.swift']:
  primary=HERE/name if name=='main.swift' else sources/name;obj=work/(name+'.o');objects.append(obj)
  commands.append(['xcrun','swiftc','-frontend','-c',*[str(p) for p in paths if p!=primary],'-primary-file',str(primary),'-sdk',sdk,'-target','arm64-apple-ios17.0-simulator','-swift-version','5','-O','-D','DEBUG','-module-name','QiuJi','-o',str(obj)])
 oldobjs=[p for p in (BASE/'objects').glob('*.o') if p.name not in ['main.o','RackLayout.o','BreakFlowRunner.o']]
 commands.append(['xcrun','swiftc','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator',*map(str,oldobjs+objects),'-lz','-Xlinker','-syslibroot','-Xlinker',sdk,'-o',str(app/'Worker')])
 (OUT/'source-binding.json').write_text(json.dumps(dict(production=bindings,recompiled=replacements,objects={p.name:sha(p) for p in oldobjs}),indent=2));(ev/'commands.json').write_text(json.dumps(commands,indent=2))
 with (ev/'build.log').open('w') as log:
  for c in commands:
   rc=subprocess.run(c,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,SDKROOT=sdk)).returncode
   if rc:raise RuntimeError((ev/'build.log').read_text()[-5000:])
 return app/'Worker'
