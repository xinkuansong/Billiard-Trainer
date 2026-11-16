"""Reuse the two measured builds with host stack sampling on a leased simulator."""
import argparse, hashlib, json, os, shutil, subprocess, time, threading
from pathlib import Path
p=argparse.ArgumentParser()
for name in ['work','evidence','source-run']:p.add_argument('--'+name,type=Path,required=True)
p.add_argument('--udid',required=True)
p.add_argument('--arms',nargs='+',choices=['A','B'],default=['A','B','B','A'])
a=p.parse_args();a.source_run=a.source_run.resolve();work,evidence=a.work,a.evidence
source=a.source_run/'work';snapshot=source/'snapshot'
def run(cmd,**kw):return subprocess.run([str(x) for x in cmd],check=True,**kw)
def sha(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
for label in ['A','B']:
 (work/label/'Build').mkdir(parents=True)
 run(['cp','-cR',source/label/'Build/Products',work/label/'Build/Products'])
products={k:work/k/'Build/Products/Debug-iphonesimulator' for k in ['A','B']}
identity=json.loads((a.source_run/'evidence/built-identities.json').read_text())
(evidence/'protocol.json').write_text(json.dumps({'sourceRun':str(a.source_run),'arms':a.arms,'cyclesPerArm':15,'freshDevice':False,'udid':a.udid,'sampler':'host sample 1 second / 5 ms interval windows during each test; affects timing','limits':'App cold processes on reused simulator; host GPU caches not reset. didRender callback is not on-glass timing.'},indent=2))
run(['xcrun','simctl','boot',a.udid]);run(['xcrun','simctl','bootstatus',a.udid,'-b'])
selector='QiuJiUITests/DailyAdaptivePanelUITests/testTemporaryTopDownBuildComparison'
def sample_windows(target, stop):
    dest=target/'host-samples';dest.mkdir()
    index=0;deadline=time.time()+180
    while not stop.is_set() and time.time()<deadline:
        lines=subprocess.check_output(['ps','-Ao','pid=,comm='],text=True).splitlines()
        matches=[int(line.strip().split(None,1)[0]) for line in lines if a.udid in line and line.rstrip().endswith('/球迹.app/球迹')]
        if len(matches)!=1:
            stop.wait(.25);continue
        pid=matches[0];index+=1;start=time.time()
        file=dest/f'window-{index:03d}.txt'
        with (dest/'sampler.log').open('a') as log:
            result=subprocess.run(['sample',str(pid),'1','5','-file',str(file)],stdout=log,stderr=log,timeout=15)
        (dest/f'window-{index:03d}.json').write_text(json.dumps({'pid':pid,'wallStart':start,'wallEnd':time.time(),'exitCode':result.returncode,'file':str(file)},indent=2))

try:
    for index,label in enumerate(a.arms,1):
        target=evidence/f'arm{index}-{label}';target.mkdir()
        app=products[label]/'球迹.app'
        run(['xcrun','simctl','install',a.udid,app])
        start=time.time()
        cmd=['make','-f',snapshot/'scripts/Makefile','test','TEST_ACTION=test-without-building',
             f'DERIVED_DATA={work/label}',f'BUILD_DIR={work}',f'TEST_LOG={target/"test.log"}',
             f'TEST_JUNIT={target/"test.xml"}',f'TEST_RESULT_BUNDLE={target/"result.xcresult"}',
             f'TEST_DESTINATION=platform=iOS Simulator,id={a.udid}',
             'SIM_TEST_GUARD=','TEST_CODE_COVERAGE=NO',f'ONLY_TESTING={selector}',
             'TEST_BUILD_SETTINGS=ARCHS=arm64 ONLY_ACTIVE_ARCH=YES']
        print('ARM',index,label,flush=True)
        stop=threading.Event();sampler=threading.Thread(target=sample_windows,args=(target,stop));sampler.start()
        with (target/'console.log').open('w') as log:
            done=subprocess.run([str(x) for x in cmd],cwd=snapshot,stdout=log,stderr=subprocess.STDOUT,
                env={**os.environ,'TEST_RUNNER_DAILY_ADAPTIVITY_DIR':str(target/'ui')})
        stop.set();sampler.join(timeout=20);assert not sampler.is_alive()
        data=Path(subprocess.check_output(['xcrun','simctl','get_app_container',a.udid,'com.xinkuan.qiuji','data'],text=True).strip())
        selected=[]
        samples=target/'samples';samples.mkdir()
        for f in (data/'Documents/TopDownLatency').glob('*/*.json'):
            rows=json.loads(f.read_text())
            begin=next(x for x in rows if x['event']=='begin')
            if begin['wallUnix']<start:continue
            shutil.copy2(f,samples/f.name);selected.append(f)
        installed=Path(subprocess.check_output(['xcrun','simctl','get_app_container',a.udid,'com.xinkuan.qiuji','app'],text=True).strip())
        state={'exitCode':done.returncode,'startUnix':start,'sampleCount':len(selected),
               'installedSHA256':sha(installed/'球迹'),'expectedSHA256':identity[label]['appSHA256']}
        (target/'identity.json').write_text(json.dumps(state,indent=2))
        assert done.returncode==0,state
        assert state['installedSHA256']==state['expectedSHA256'],state
        assert len(selected)==15,state
    (evidence/'completed.json').write_text(json.dumps({'arms':len(a.arms),'samples':len(a.arms)*15,'status':'completed'}))
finally:
    run(['xcrun','simctl','shutdown',a.udid])
