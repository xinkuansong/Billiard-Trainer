#!/usr/bin/env python3
"""Frozen research snapshot + managed build and simulator; production is read-only."""
from pathlib import Path
import json, hashlib, subprocess, sys, os, shutil, itertools, math
ROOT=Path('/Users/song/projects/13.billiard_trainer')
OUT=Path(__file__).resolve().parent
PY=ROOT/'build/break-potting-research-20261002/plot-venv/bin/python'
def save(p,d): p.write_text(json.dumps(d,ensure_ascii=False,indent=2))
def hashes(root):
    paths=list((root/'QiuJi').rglob('*.swift'))+[root/'QiuJi.xcodeproj/project.pbxproj']
    return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
def prepare():
    old=ROOT/'research/separation-position-20261021/r3-fixed-tolerance'
    shutil.copy2(old/'sample.json',OUT/'sample.json')
    routes=json.loads((old/'request-scan.json').read_text())['routes']
    tiers={'A':{'speed':.04,'angle':.25,'tip':.025},'B':{'speed':.08,'angle':.5,'tip':.05}}
    speeds=[.75+i*.3125 for i in range(13)]
    jobs=[]
    for route in routes:
      for vi,v in enumerate(speeds):
       for tier,scale in tiers.items():
        for z in itertools.product([-1,0,1],repeat=4):
         delta=z[1]*scale['angle']*math.pi/180
         x,y=route['direction'];direction=[x*math.cos(delta)-y*math.sin(delta),x*math.sin(delta)+y*math.cos(delta)]
         job={'id':f"{route['key']}-{vi}-{tier}-"+''.join(str(a+1) for a in z),'route':route['key'],'nominalV':v,'tier':tier,'offset':list(z),'v':v*(1+z[0]*scale['speed']),'sx':route['sx']+z[2]*scale['tip'],'sy':route['sy']+z[3]*scale['tip'],'direction':direction,'pocket2':route['pocket2'],'expectedRails':route['rails']}
         job['directionDeltaDegrees']=z[1]*scale['angle']
         if z==(0,0,0,0) and vi==12:job.update(baselineCheck=True,expectedStop=route['stop'])
         jobs.append(job)
    save(OUT/'protocol.json',{'routes':routes,'tiers':tiers,'speeds':speeds,'sampleDesign':'main: {-1,0,+1}^3 speed/tipX/tipY, solve aim per combination; +/- direction are auxiliary only','maxSpeed':4.5,'gridStep':.03,'secondAngleMax':20,'railGapTarget':.1,'solverCompensated':True,'userConfirmed':'2026-10-22: resolve aim for every speed and tip; focus on cue-ball positioning'})
    save(OUT/'request-scan.json',{'mode':'scan','jobs':jobs})
    shutil.copy2(OUT/'request-scan.json',OUT/'request.json')
    save(OUT/'source-hashes-before.json',hashes(ROOT))
    subprocess.run(['git','diff','--','QiuJi','QiuJiTests','QiuJi.xcodeproj'],cwd=ROOT,stdout=(OUT/'working-source-before.diff').open('w'),check=True)
    print('prepared',len(jobs),'factorial samples',flush=True)
def command(args,log,cwd=None):
    with log.open('w') as f:r=subprocess.run([str(a) for a in args],cwd=cwd,stdout=f,stderr=subprocess.STDOUT)
    print(log.name,'exit',r.returncode,flush=True)
    if r.returncode:raise RuntimeError(log.read_text(errors='replace')[-6000:])
def work(work,evidence):
    work=Path(work);evidence=Path(evidence);save(OUT/'run-paths.json',{'work':str(work),'evidence':str(evidence)})
    snap=work/'snapshot';snap.mkdir()
    for item in ['QiuJi','QiuJiTests','QiuJiUITests','QiuJiLiveActivity','Config','scripts','QiuJi.xcodeproj']:
        subprocess.run(['/bin/cp','-cR',str(ROOT/item),str(snap/item)],check=True)
    assert hashes(snap)==json.loads((OUT/'source-hashes-before.json').read_text()),'Snapshot drift before build'
    with (snap/'QiuJiTests/PhysicsEngineTests.swift').open('a') as f:f.write('\n'+(OUT/'Research.swift').read_text())
    save(OUT/'snapshot-hashes.json',hashes(snap))
    base=['xcodebuild','-project',snap/'QiuJi.xcodeproj','-scheme','QiuJi','-configuration','Debug','-derivedDataPath',work/'DerivedData','-enableCodeCoverage','NO','-parallel-testing-enabled','NO','-jobs','2','-only-testing:QiuJiTests/JointTrajectoryResearchTests/testResearch']
    save(OUT/'build-command.json',[str(x) for x in base])
    command(base+['-destination','generic/platform=iOS Simulator','build-for-testing'],evidence/'build.log',snap)
    save(OUT/'compiled.json',{'base':[str(x) for x in base],'snapshot':str(snap),'evidence':str(evidence)})
    # A single managed lease owns all research invocations; no UI interaction.
    command([sys.executable,ROOT/'scripts/simulator_fleet.py','run','--role','notch-phone','--task','joint-trajectory-research','--',sys.executable,OUT/'run.py','device','{udid}'],evidence/'device.log',ROOT)
    save(OUT/'source-hashes-after.json',hashes(ROOT))
    assert hashes(snap)==json.loads((OUT/'snapshot-hashes.json').read_text()),'Frozen source mutated'
def device(uid):
    import time
    while (OUT/'protocol-pending').exists():
        time.sleep(1)
    compiled=json.loads((OUT/'compiled.json').read_text());base=compiled['base'];evidence=Path(compiled['evidence'])
    try:
        # Protocol clarification happened while the initial snapshot was compiling.
        # Recompile only the research test before running any samples.
        target=Path(compiled['snapshot'])/'QiuJiTests/PhysicsEngineTests.swift'
        marker='// Research-only harness, appended to a frozen test snapshot by run.py.'
        existing=target.read_text();replacement=(OUT/'Research.swift').read_text()
        assert existing.count(marker)==1
        desired=existing.split(marker)[0]+replacement
        if desired!=existing:
            target.write_text(desired)
            command(base+['-destination','generic/platform=iOS Simulator','build-for-testing'],evidence/'build-solver-protocol.log')
        shutil.copy2(OUT/'Research.swift',OUT/'compiled-harness.swift')
        save(OUT/'harness-identity.json',{'sha256':hashlib.sha256(replacement.encode()).hexdigest(),'protocol':read_protocol()})
        command(base+['-destination',f'platform=iOS Simulator,id={uid}','-resultBundlePath',evidence/'scan.xcresult','test-without-building'],evidence/'scan.log')
        command([PY,OUT/'analyze.py','select'],evidence/'analysis-select.log')
        shutil.copy2(OUT/'request-validate.json',OUT/'request.json')
        command(base+['-destination',f'platform=iOS Simulator,id={uid}','-resultBundlePath',evidence/'validate.xcresult','test-without-building'],evidence/'validate.log')
        command([PY,OUT/'analyze.py','report'],evidence/'analysis-report.log')
    finally:
        subprocess.run(['xcrun','simctl','shutdown',uid],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
def read_protocol():return json.loads((OUT/'protocol.json').read_text())
if __name__=='__main__':
    if sys.argv[1]=='prepare':prepare()
    elif sys.argv[1]=='work':work(*sys.argv[2:4])
    elif sys.argv[1]=='device':device(sys.argv[2])
