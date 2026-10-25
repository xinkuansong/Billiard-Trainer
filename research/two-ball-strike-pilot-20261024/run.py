from pathlib import Path
import hashlib,json,subprocess,sys,shutil,time
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent

def save(n,v): (OUT/n).write_text(json.dumps(v,ensure_ascii=False,indent=2))
def read(n): return json.loads((OUT/n).read_text())
def hashes(root):
    files=list((root/'QiuJi').rglob('*.swift'))+[root/'QiuJi.xcodeproj/project.pbxproj',root/'QiuJi/Resources/training-grid-bank.json']
    return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
def command(args,log,cwd):
    print('START',log.name,flush=True); start=time.monotonic()
    with log.open('w') as f: p=subprocess.run(list(map(str,args)),cwd=cwd,stdout=f,stderr=subprocess.STDOUT)
    print('END',log.name,p.returncode,round(time.monotonic()-start,2),flush=True)
    if p.returncode: raise RuntimeError(log.read_text(errors='replace')[-6000:])
def make(c,action,phase,uid=None):
    work,evidence,snap=[Path(c[k]) for k in ['work','evidence','snapshot']]
    return ['make','-f',snap/'scripts/Makefile','test',f'TEST_ACTION={action}',f'BUILD_DIR={work}',f'DERIVED_DATA={work}/DerivedData',f'TEST_LOG={evidence}/{phase}.log',f'TEST_JUNIT={evidence}/{phase}.xml','TEST_CODE_COVERAGE=NO','ONLY_TESTING=QiuJiTests/StrikeGridPilotTests/testPilot','TEST_BUILD_SETTINGS=-jobs 2'+(' -parallel-testing-enabled NO' if action=='build-for-testing' else ''),f'TEST_DESTINATION=platform=iOS Simulator,id={uid}' if uid else 'TEST_DESTINATION=generic/platform=iOS Simulator',f'TEST_RESULT_BUNDLE={evidence}/{phase}.xcresult']
def prepare():
    board=json.loads((ROOT/'output/two-ball-second-grid-20261024/preview-data.json').read_text())['boards'][2]
    board={k:v for k,v in board.items() if k!='points'}
    source=ROOT/'output/two-ball-object-distance-sampled-20261024/object-distance-sampled-bank.json'
    bank=json.loads(source.read_text());target=next(t for t in bank['targets'] if t['inventoryTargetIndex']==1512)
    board['aim']=[target['aim']['x'],target['aim']['z']]
    sample=ROOT/'output/two-ball-strike-sampling-preview-20261024/sampling-example.json'
    sampling=json.loads(sample.read_text());assert board['id']==sampling['originalLayout']
    save('input.json',{'board':board,'combinations':sampling['combinations'],'samplingSHA256':hashlib.sha256(sample.read_bytes()).hexdigest(),'bankSHA256':hashlib.sha256(source.read_bytes()).hexdigest()})
    save('source-hashes-before.json',hashes(ROOT))
def work(w,e):
    w,e=Path(w),Path(e);snap=w/'snapshot';snap.mkdir()
    for item in ['QiuJi','QiuJiTests','QiuJiUITests','QiuJiLiveActivity','Config','scripts','QiuJi.xcodeproj']:
        subprocess.run(['/bin/cp','-cR',str(ROOT/item),str(snap/item)],check=True)
    assert hashes(snap)==read('source-hashes-before.json')
    with (snap/'QiuJiTests/PhysicsEngineTests.swift').open('a') as f:f.write('\n'+(OUT/'Research.swift').read_text())
    c={'work':str(w),'evidence':str(e),'snapshot':str(snap)};save('run-paths.json',c)
    shutil.copy2(OUT/'Research.swift',e/'Research.swift');shutil.copy2(OUT/'input.json',e/'input.json')
    command(make(c,'build-for-testing','build'),e/'make-build.log',snap)
    command([sys.executable,ROOT/'scripts/simulator_fleet.py','run','--role','notch-phone','--task','strike-grid-pilot','--',sys.executable,OUT/'run.py','device','{udid}'],e/'device.log',ROOT)
    assert hashes(snap)==read('source-hashes-before.json')
    save('source-hashes-after.json',hashes(ROOT));shutil.copy2(OUT/'results.json',e/'results.json')
def device(uid):
    c=read('run-paths.json');e=Path(c['evidence']);save('device.json',{'udid':uid,'role':'notch-phone'})
    try: command(make(c,'test-without-building','pilot',uid),e/'make-pilot.log',c['snapshot'])
    finally:
        r=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True,text=True)
        save('shutdown.json',{'returncode':r.returncode,'stdout':r.stdout,'stderr':r.stderr})
if __name__=='__main__':
    if sys.argv[1]=='prepare':prepare()
    elif sys.argv[1]=='work':work(*sys.argv[2:4])
    elif sys.argv[1]=='device':device(sys.argv[2])
