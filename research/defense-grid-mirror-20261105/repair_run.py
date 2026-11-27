from pathlib import Path
import json,os,subprocess,sys,shutil,plistlib,hashlib,tarfile
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).parent;OUT=ROOT/'output/defense-grid-mirror-20261105'
work=Path(os.environ['QIUJI_TEST_WORK']);ev=Path(os.environ['QIUJI_TEST_EVIDENCE'])
old=work/'frozen';old.mkdir()
with tarfile.open(OUT/'source-snapshot.tar.gz') as archive:
 for member in archive.getmembers():
  assert (old/member.name).resolve().is_relative_to(old.resolve()) and not member.issym() and not member.islnk()
 archive.extractall(old)
paths=sorted(str(p) for p in (old/'sources').rglob('*.swift'))
assert len(paths)>450
main=work/'main.swift';shutil.copy2(HERE/'repair.swift',main)
app=work/'DefenseBench.app';app.mkdir();binary=app/'Worker'
(app/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'local.qiuji.defense-benchmark','CFBundleExecutable':'Worker','CFBundlePackageType':'APPL'}))
shutil.copytree(old/'PocketPipe',app/'PocketPipe')
sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
cmd=['xcrun','swiftc','-O','-whole-module-optimization','-num-threads','4','-D','DEBUG','-swift-version','5','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator',*paths,str(main),'-lz','-o',str(binary)]
(ev/'build-command.json').write_text(json.dumps(cmd))
with (ev/'build.log').open('w') as log:subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,check=True)
print('Diagnostic build passed',flush=True)
shutil.copy2(OUT/'run.log',OUT/'run-replay-complete.log')
subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','large-phone','--task','defense-grid-mirror-20261105-repair','--',sys.executable,str(HERE/'run.py'),'worker','{udid}',str(binary)],check=True)
manifest=json.loads((OUT/'source-manifest.json').read_bytes());drift=[p for p,h in manifest.items() if hashlib.sha256((ROOT/p).read_bytes()).hexdigest()!=h]
(OUT/'execution.json').write_text(json.dumps(dict(exitCode=0,sourceDrift=drift,evidence=str(ev),scope='Frozen production sources; all transformed references replayed; no UI'),indent=2))
