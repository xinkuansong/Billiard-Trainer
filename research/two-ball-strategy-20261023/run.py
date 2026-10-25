#!/usr/bin/env python3
"""Managed, frozen-source pilot. Never edits app sources or the accuracy bank."""
from pathlib import Path
import hashlib, itertools, json, math, os, shutil, subprocess, sys, time

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
PY = ROOT / 'build/break-potting-research-20261002/plot-venv/bin/python'

def save(name, value):
    (OUT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2))

def read(name): return json.loads((OUT / name).read_text())

def hashes(root):
    paths = list((root / 'QiuJi').rglob('*.swift')) + [root / 'QiuJi.xcodeproj/project.pbxproj', root / 'QiuJi/Resources/training-grid-bank.json']
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}

def prepare():
    old = ROOT / 'research/two-ball-precompute-20261023'
    source=json.loads((old/'sample.json').read_text())
    target=next(c for c in json.loads((old/'candidates.json').read_text()) if c['id']==1233)
    save('sample.json', {'cue':[source['cue']['x'],source['cue']['z']], 'a':[source['target']['x'],source['target']['z']], 'b':target['point'], 'geometry':source['geometry'], 'provenance':'Previous fixed C/A and candidate B#1233, selected before current experiment; not a representative random layout.'})
    import random
    axes=[[0.,0,0,0]]
    for j in range(4):
        for sign in [-1.,1.]:
            x=[0.,0,0,0];x[j]=sign;axes.append(x)
    design_rng=random.Random(2026102302); holdout_rng=random.Random(2026102303)
    styles=[{'id':i,'label':l,'sx':x,'sy':y} for i,l,x,y in [('center','中杆',0.,0.),('follow','高杆',0.,.25),('draw','低杆',0.,-.25),('left','横向打点 −0.25',-.25,0.),('right','横向打点 +0.25',.25,0.)]]
    save('protocol.json',{'version':1,'styles':styles,'speeds':[.75,1.,1.5,2.,2.5,2.9375,3.5,4.,4.1875], 'axisOffsets':axes, 'designOffsets':[[design_rng.uniform(-1,1) for _ in range(8)] for _ in range(48)], 'holdoutOffsets':[[holdout_rng.uniform(-1,1) for _ in range(8)] for _ in range(128)], 'seeds':[2026102302,2026102303], 'perturbation':{'speedFraction':.04,'angleDegrees':.25,'tipX':.025,'tipY':.025}, 'eligibility':{'cutMax':75,'distance':[.15,2.54],'cueRailClearance':.05}, 'secondSearch':{'tipsY':[0,.25,-.25],'speeds':[1,1.5,2,2.5],'sx':0}, 'selection':'Up to 12 per order: best per first tip, best per pocket pair, second per tip, then fill by proxy. Proxy=first 9-axis pass count times second 9-axis pass count at nominal stop. All selected complete design and holdout. Freeze design winners before holdout.', 'execution':'First nominal direction fixed before all noise; second speed/tip fixed per strategy. At actual first stop re-solve second aim only, then apply independent 4D second noise. Execute even if second zero-error baseline fails. Geometry rejects count as sequence failures.', 'qualification':'Direct target pot into specified pocket; settled cue, no scratch, one correct ball contact, no precontact cue rail, no cue jaw, no target rail/jaw; other ball untouched on first. These are pilot restrictions, not universal game rules.', 'scope':'Fixed one layout, finite parameter grid and flat production physics, no jump/masse/bank target shots; no human calibration. New cut/distance scope differs from previous 35deg/1.2m pilot.'})
    save('source-hashes-before.json',hashes(ROOT))
    save('input-identity.json',{f:hashlib.sha256((OUT/f).read_bytes()).hexdigest() for f in ['sample.json','protocol.json','Research.swift','analyze.py']})
    print('Frozen one C/A/B layout, 540 first-shot slots, independent 48 design +128 held-out pairs.',flush=True)

def command(args, log, cwd=None):
    print('START', log.name, flush=True)
    start = time.monotonic()
    with log.open('w') as f:
        r = subprocess.run([str(a) for a in args], cwd=cwd, stdout=f, stderr=subprocess.STDOUT)
    print('END', log.name, r.returncode, round(time.monotonic() - start, 1), 's', flush=True)
    if r.returncode: raise RuntimeError(log.read_text(errors='replace')[-5000:])

def make_args(compiled, action, phase, uid=None):
    work, evidence, snap = (Path(compiled[k]) for k in ['work','evidence','snapshot'])
    return ['make', '-f', snap / 'scripts/Makefile', 'test', f'TEST_ACTION={action}',
            f'BUILD_DIR={work}', f'DERIVED_DATA={work}/DerivedData', f'TEST_LOG={evidence}/{phase}.log',
            f'TEST_JUNIT={evidence}/{phase}.xml', 'TEST_CODE_COVERAGE=NO',
            'ONLY_TESTING=QiuJiTests/TwoBallStrategyResearchTests/testResearch',
            'TEST_BUILD_SETTINGS=-jobs 2' + (' -parallel-testing-enabled NO' if action=='build-for-testing' else ''),
            f'TEST_DESTINATION=platform=iOS Simulator,id={uid}' if uid else 'TEST_DESTINATION=generic/platform=iOS Simulator',
            f'TEST_RESULT_BUNDLE={evidence}/{phase}.xcresult']

def work(work_path, evidence_path):
    work, evidence = Path(work_path), Path(evidence_path)
    snap = work / 'snapshot'; snap.mkdir()
    for item in ['QiuJi','QiuJiTests','QiuJiUITests','QiuJiLiveActivity','Config','scripts','QiuJi.xcodeproj']:
        subprocess.run(['/bin/cp','-cR', str(ROOT/item), str(snap/item)], check=True)
    assert hashes(snap) == read('source-hashes-before.json'), 'Source changed while preparing; freeze a new run.'
    with (snap/'QiuJiTests/PhysicsEngineTests.swift').open('a') as f:
        f.write('\n' + (OUT/'Research.swift').read_text())
    compiled = {'work': str(work), 'evidence': str(evidence), 'snapshot': str(snap)}
    save('run-paths.json', compiled)
    save('snapshot-hashes.json', hashes(snap))
    shutil.copy2(OUT/'Research.swift', evidence/'Research.swift')
    delta=OUT/'frozen-source-delta';delta.mkdir(exist_ok=True)
    changed=subprocess.check_output(['git','diff','--name-only','HEAD'],cwd=ROOT,text=True).splitlines()
    for name in changed:
        src=snap/name
        if src.is_file():
            dst=delta/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
    save('source-base.json',{'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'deltaFiles':[str(f.relative_to(delta)) for f in delta.rglob('*') if f.is_file()]})
    command(make_args(compiled, 'build-for-testing', 'build'), evidence/'make-build.log', snap)
    command([sys.executable,ROOT/'scripts/simulator_fleet.py','run','--role','notch-phone','--task','two-ball-strategy-comparison','--',sys.executable,OUT/'run.py','device','{udid}'], evidence/'device.log', ROOT)
    assert hashes(snap) == read('snapshot-hashes.json'), 'Frozen app sources changed'
    save('source-hashes-after.json', hashes(ROOT))

def device(uid):
    c=read('run-paths.json'); evidence=Path(c['evidence'])
    save('device.json', {'udid': uid, 'role': 'notch-phone'})
    try:
        for phase in ['scan','design','holdout']:
            save('request.json', {'mode': phase})
            command(make_args(c, 'test-without-building', phase, uid), evidence/f'make-{phase}.log', c['snapshot'])
            command([PY, OUT/'analyze.py', phase], evidence/f'analyze-{phase}.log', ROOT)
    finally:
        r=subprocess.run(['xcrun','simctl','shutdown',uid], capture_output=True,text=True)
        save('shutdown.json', {'returncode':r.returncode,'stdout':r.stdout,'stderr':r.stderr})

if __name__=='__main__':
    if sys.argv[1]=='prepare':prepare()
    elif sys.argv[1]=='work':work(*sys.argv[2:4])
    elif sys.argv[1]=='device':device(sys.argv[2])
