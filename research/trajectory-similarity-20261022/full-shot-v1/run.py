from pathlib import Path
import json,hashlib,subprocess,sys,shutil
ROOT=Path('/Users/song/projects/13.billiard_trainer');OUT=Path(__file__).resolve().parent

def save(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2))
def hashes(root):
    paths=list((root/'QiuJi').rglob('*.swift'))+[root/'QiuJi.xcodeproj/project.pbxproj']
    return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
def command(args,log,cwd=None):
    with log.open('w') as f:r=subprocess.run([str(x) for x in args],cwd=cwd,stdout=f,stderr=subprocess.STDOUT)
    print(log.name,'exit',r.returncode,flush=True)
    if r.returncode:raise RuntimeError(log.read_text(errors='replace')[-4000:])
def work(work,evidence):
    work=Path(work);evidence=Path(evidence);snap=work/'snapshot';snap.mkdir()
    save(OUT/'source-hashes-before.json',hashes(ROOT))
    for name in ['QiuJi','QiuJiTests','QiuJiUITests','QiuJiLiveActivity','Config','scripts','QiuJi.xcodeproj']:
        subprocess.run(['/bin/cp','-cR',str(ROOT/name),str(snap/name)],check=True)
    assert hashes(snap)==json.loads((OUT/'source-hashes-before.json').read_text())
    with (snap/'QiuJiTests/PhysicsEngineTests.swift').open('a') as f:f.write('\n'+(OUT/'Research.swift').read_text())
    save(OUT/'snapshot-hashes.json',hashes(snap))
    base=['xcodebuild','-project',snap/'QiuJi.xcodeproj','-scheme','QiuJi','-configuration','Debug','-derivedDataPath',work/'DerivedData','-enableCodeCoverage','NO','-parallel-testing-enabled','NO','-jobs','2','-only-testing:QiuJiTests/TrajectorySimilarityResearchTests/testExport']
    save(OUT/'run-paths.json',{'work':str(work),'evidence':str(evidence),'base':[str(x) for x in base]})
    command(base+['-destination','generic/platform=iOS Simulator','build-for-testing'],evidence/'build.log',snap)
    command([sys.executable,ROOT/'scripts/simulator_fleet.py','run','--role','large-phone','--task','trajectory-similarity-research','--',sys.executable,OUT/'run.py','device','{udid}'],evidence/'device.log',ROOT)
    save(OUT/'source-hashes-after.json',hashes(ROOT))
    save(OUT/'source-drift.json',{k:v for k,v in hashes(ROOT).items() if json.loads((OUT/'source-hashes-before.json').read_text()).get(k)!=v})
    assert hashes(snap)==json.loads((OUT/'snapshot-hashes.json').read_text())
def device(uid):
    d=json.loads((OUT/'run-paths.json').read_text());e=Path(d['evidence'])
    try:command(d['base']+['-destination',f'platform=iOS Simulator,id={uid}','-resultBundlePath',e/'research.xcresult','test-without-building'],e/'test.log')
    finally:
        r=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True,text=True)
        save(OUT/'device-cleanup.json',{'udid':uid,'shutdownReturnCode':r.returncode,'stderr':r.stderr})
if __name__=='__main__':
    if sys.argv[1]=='work':work(*sys.argv[2:4])
    else:device(sys.argv[2])
