from pathlib import Path
import json,subprocess,sys,zipfile,hashlib
ROOT=Path('/Users/song/projects/13.billiard_trainer')
OUT=Path(__file__).resolve().parent
def save(name,value): (OUT/name).write_text(json.dumps(value,ensure_ascii=False,indent=2))
def command(args,log,cwd=None):
    with log.open('w') as f: p=subprocess.run([str(x) for x in args],cwd=cwd,stdout=f,stderr=subprocess.STDOUT)
    print(log,p.returncode,flush=True)
    if p.returncode: raise RuntimeError(log.read_text(errors='replace')[-5000:])
def work(work,evidence):
    work,evidence=Path(work),Path(evidence);snap=work/'snapshot';snap.mkdir()
    save('run-paths.json',dict(work=str(work),evidence=str(evidence)))
    for name in ['QiuJi','QiuJiTests','QiuJiUITests','QiuJiLiveActivity','Config','scripts','QiuJi.xcodeproj']:
        subprocess.run(['/bin/cp','-cR',ROOT/name,snap/name],check=True)
    with zipfile.ZipFile(OUT.parent/'source-snapshot.zip') as z: z.extractall(snap)
    hashes={str(p.relative_to(snap)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (snap/'QiuJi').rglob('*.swift')}
    save('source-hashes.json',hashes)
    with (snap/'QiuJiTests/BreakRackPhysicsTests.swift').open('a') as f:f.write('\n'+(OUT/'Research.swift').read_text())
    base=['xcodebuild','-project',snap/'QiuJi.xcodeproj','-scheme','QiuJi','-derivedDataPath',work/'DerivedData','-enableCodeCoverage','NO','-parallel-testing-enabled','NO','-jobs','3','-only-testing:QiuJiTests/CenterSpeedResearchTests/testResearch']
    save('compiled.json',dict(base=[str(x) for x in base],evidence=str(evidence)))
    command(base+['-destination','generic/platform=iOS Simulator','build-for-testing'],evidence/'build.log',snap)
    command([sys.executable,ROOT/'scripts/simulator_fleet.py','run','--role','notch-phone','--task','center-speed-13','--',sys.executable,OUT/'run.py','device','{udid}'],evidence/'device.log',ROOT)
    assert hashes=={str(p.relative_to(snap)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (snap/'QiuJi').rglob('*.swift')}
def device(uid):
    c=json.loads((OUT/'compiled.json').read_text());e=Path(c['evidence'])
    try: command(c['base']+['-destination',f'platform=iOS Simulator,id={uid}','-resultBundlePath',e/'scan.xcresult','test-without-building'],e/'scan.log')
    finally:
        inventory=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','--json']))
        device=next(d for group in inventory['devices'].values() for d in group if d['udid']==uid)
        if device['state']!='Shutdown':subprocess.run(['xcrun','simctl','shutdown',uid],check=True)
if sys.argv[1]=='work':work(*sys.argv[2:4])
elif sys.argv[1]=='device':device(sys.argv[2])
