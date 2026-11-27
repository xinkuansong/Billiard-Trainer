from pathlib import Path
import hashlib, json, os, plistlib, shutil, subprocess, sys, tarfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = ROOT / 'output/defense-grid-mirror-20261105'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
if len(sys.argv) > 1 and sys.argv[1] == 'worker':
    uid, binary = sys.argv[2:]
    subprocess.run(['xcrun', 'simctl', 'boot', uid], check=True)
    try:
        subprocess.run(['xcrun', 'simctl', 'bootstatus', uid, '-b'], check=True)
        with (OUT/'run.log').open('w') as log:
            subprocess.run(['xcrun','simctl','spawn',uid,binary,str(OUT)],stdout=log,stderr=subprocess.STDOUT,check=True)
    finally:
        subprocess.run(['xcrun','simctl','shutdown',uid],check=True)
    sys.exit(0)

OUT.mkdir(exist_ok=True,parents=True)
work = Path(os.environ['QIUJI_TEST_WORK']); evidence = Path(os.environ['QIUJI_TEST_EVIDENCE'])
src = work/'sources'; paths = []; manifest = {}
for p in sorted((ROOT/'QiuJi').rglob('*.swift')):
    rel = p.relative_to(ROOT); data = p.read_bytes(); manifest[str(rel)] = sha(p)
    if b'@main' in data:
        assert p.name == 'QiuJiApp.swift', p
        data = data.replace(b'@main', b'// Native benchmark supplies main')
    dest = src/rel; dest.parent.mkdir(parents=True,exist_ok=True); dest.write_bytes(data); paths.append(str(dest))
main = work/'main.swift'; shutil.copy2(HERE/'main.swift',main)
app = work/'DefenseBench.app'; app.mkdir(); binary = app/'Worker'
(app/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'local.qiuji.defense-benchmark','CFBundleExecutable':'Worker','CFBundlePackageType':'APPL'}))
shutil.copytree(ROOT/'QiuJi/Resources/PocketPipe',app/'PocketPipe')


(OUT/'source-manifest.json').write_text(json.dumps(manifest,indent=2))
with tarfile.open(OUT/'source-snapshot.tar.gz','w:gz') as ar:
    ar.add(src,arcname='sources'); ar.add(main,arcname='main.swift'); ar.add(app/'PocketPipe',arcname='PocketPipe')
subprocess.run([sys.executable,str(ROOT/'scripts/verify_pocket_pipe_table.py')],check=True)
sdk = subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
cmd = ['xcrun','swiftc','-O','-whole-module-optimization','-num-threads','4','-D','DEBUG','-swift-version','5','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator',*paths,str(main),'-lz','-o',str(binary)]
(evidence/'build-command.json').write_text(json.dumps(cmd,indent=2))
print('Compiling current production sources',len(paths),flush=True)
with (evidence/'build.log').open('w') as log:
    result = subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,SDKROOT=sdk))
if result.returncode:
    print((evidence/'build.log').read_text()[-8000:]);sys.exit(result.returncode)
print('Native build passed; running benchmark',flush=True)
subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','large-phone','--task','defense-grid-mirror-20261105','--',sys.executable,__file__,'worker','{udid}',str(binary)],check=True)
drift = [p for p,h in manifest.items() if sha(ROOT/p) != h]
(OUT/'execution.json').write_text(json.dumps({'exitCode':0,'sourceDrift':drift,'binarySHA256':sha(binary),'evidence':str(evidence)},indent=2))
print((OUT/'run.log').read_text()[-3500:])
print('Source drift:',drift)
