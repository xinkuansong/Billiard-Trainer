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
    old = ROOT / 'research/joint-trajectory-20261022'
    shutil.copy2(old / 'sample.json', OUT / 'sample.json')
    bank = json.loads((ROOT / 'QiuJi/Resources/training-grid-bank.json').read_text())
    targets = [{'id': i, 'pocket': t['pocket'], 'point': [t['object']['x'], t['object']['z']]} for i, t in enumerate(bank['targets'])]
    save('targets.json', targets)
    routes = [
        {'id': 'follow-two', 'label': '无侧塞跟进 · 2.9375', 'v': 2.9375, 'sx': 0., 'sy': .25},
        {'id': 'side-two', 'label': '侧塞 · 2.9375', 'v': 2.9375, 'sx': -.25, 'sy': 0.},
        {'id': 'side-three', 'label': '侧塞 · 4.1875', 'v': 4.1875, 'sx': -.25, 'sy': 0.},
    ]
    import random
    rng = random.Random(2026102301)
    design = [list(z) for z in itertools.product([-1, 0, 1], repeat=4)]
    holdout = [[rng.uniform(-1, 1) for _ in range(4)] for _ in range(96)]
    protocol = {'schema': 1, 'routes': routes, 'perturbation': {'speedFraction': .04, 'angleDegrees': .25, 'tipX': .025, 'tipY': .025},
                'designOffsets': design, 'holdoutOffsets': holdout, 'holdoutSeed': 2026102301,
                'gridStep': .06, 'gridOrigin': [-1.20, -.60], 'gridShape': [41, 21],
                'candidateCountPerPocket': 3, 'candidateSeparation': .20, 'topN': 3,
                'secondPolicy': {'maxCutDegrees': 35, 'distanceRange': [.15, 1.20], 'minCueRailClearance': .05,
                                 'speeds': [1., 1.5, 2., 2.5], 'tipsY': [0., .25, -.25], 'tipX': 0.},
                'firstPolicy': 'Nominal aim solved once; fixed aim plus execution error, no per-perturbation correction. Same initial C/A and first pocket for three shot settings.',
                'qualification': 'Both shots settled; specified direct target pot, no scratch; one correct cue-target collision; no cue jaw, pre-contact cue rail or target cushion; B unchanged on first shot. These are pilot training rules, not universal legal-shot rules.',
                'scope': 'Reuse accuracy target/pocket configurations; resample cue positions on shared 6cm grid. Not validating the entire accuracy bank. Map cells are sampled-center proxies, not continuous feasibility guarantees.',
                'ranking': 'Area=number of occupied successful-map cells * cell area. Coverage=sum of successful-map cell sample counts / ALL 81 design shots. Ties: other metric, then target ID. No convex hull.',
                'holdoutUse': 'Frozen before scan; never used to choose candidates or rankings. Uniform independent parameter noise is a declared simulation model, not a calibrated human model.'}
    save('protocol.json', protocol)
    save('request.json', {'mode': 'scan'})
    save('source-hashes-before.json', hashes(ROOT))
    save('input-identity.json', {f: hashlib.sha256((OUT / f).read_bytes()).hexdigest() for f in ['sample.json','targets.json','protocol.json','Research.swift']})
    print('Prepared 3 first-shot settings, 81 design offsets and 96 held-out offsets per setting.', flush=True)

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
            'ONLY_TESTING=QiuJiTests/TwoBallPrecomputeResearchTests/testResearch',
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
    command(make_args(compiled, 'build-for-testing', 'build'), evidence/'make-build.log', snap)
    command([sys.executable,ROOT/'scripts/simulator_fleet.py','run','--role','notch-phone','--task','two-ball-precompute-pilot','--',sys.executable,OUT/'run.py','device','{udid}'], evidence/'device.log', ROOT)
    assert hashes(snap) == read('snapshot-hashes.json'), 'Frozen app sources changed'
    save('source-hashes-after.json', hashes(ROOT))

def device(uid):
    c=read('run-paths.json'); evidence=Path(c['evidence'])
    save('device.json', {'udid': uid, 'role': 'notch-phone'})
    try:
        for phase in ['scan','map','validate']:
            save('request.json', {'mode': phase})
            command(make_args(c, 'test-without-building', phase, uid), evidence/f'make-{phase}.log', c['snapshot'])
            command([PY, OUT/'analyze.py', phase], evidence/f'analyze-{phase}.log', ROOT)
    finally:
        r=subprocess.run(['xcrun','simctl','shutdown',uid], capture_output=True,text=True)
        save('shutdown.json', {'returncode':r.returncode,'stdout':r.stdout,'stderr':r.stderr})

def resume():
    c=read('run-paths.json'); evidence=Path(c['evidence'])
    assert hashes(Path(c['snapshot']))==read('snapshot-hashes.json')
    for name in ['scan.log','make-scan.log','scan.xml']:
        p=evidence/name
        if p.exists():p.rename(evidence/('invocation-failed-'+name))
    command([sys.executable,ROOT/'scripts/simulator_fleet.py','run','--role','notch-phone','--task','two-ball-precompute-pilot-resume','--',sys.executable,OUT/'run.py','device','{udid}'], evidence/'device-resume.log', ROOT)
    assert hashes(Path(c['snapshot']))==read('snapshot-hashes.json')
    save('source-hashes-after.json',hashes(ROOT))

def repair():
    c=read('run-paths.json'); evidence=Path(c['evidence']); snap=Path(c['snapshot'])
    assert hashes(snap)==read('snapshot-hashes.json')
    for name in ['scan.log','make-scan.log','scan.xml','scan.xcresult']:
        p=evidence/name
        if p.exists():p.rename(evidence/('cast-failed-'+name))
    target=snap/'QiuJiTests/PhysicsEngineTests.swift'
    marker='// Research-only harness, appended to an immutable test snapshot by run.py.'
    before=target.read_text();assert before.count(marker)==1
    target.write_text(before.split(marker)[0]+(OUT/'Research.swift').read_text())
    shutil.copy2(OUT/'Research.swift',evidence/'Research-v2.swift')
    save('harness-revisions.json',{'v1':hashlib.sha256((evidence/'Research.swift').read_bytes()).hexdigest(),
        'v2':hashlib.sha256((evidence/'Research-v2.swift').read_bytes()).hexdigest(),
        'repair':'Store in-memory solved direction as Double before consuming it; preserve app physics and all criteria.'})
    command(make_args(c,'build-for-testing','build-harness-v2'),evidence/'make-build-harness-v2.log',snap)
    command([sys.executable,ROOT/'scripts/simulator_fleet.py','run','--role','notch-phone','--task','two-ball-precompute-pilot-v2','--',sys.executable,OUT/'run.py','device','{udid}'],evidence/'device-v2.log',ROOT)
    assert hashes(snap)==read('snapshot-hashes.json')
    save('source-hashes-after.json',hashes(ROOT))

if __name__=='__main__':
    if sys.argv[1]=='prepare': prepare()
    elif sys.argv[1]=='work': work(*sys.argv[2:4])
    elif sys.argv[1]=='device': device(sys.argv[2])
    elif sys.argv[1]=='resume': resume()
    elif sys.argv[1]=='repair': repair()
