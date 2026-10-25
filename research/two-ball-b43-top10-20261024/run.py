from pathlib import Path
import json, subprocess, sys, hashlib, math
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
OUT=ROOT/'output/two-ball-second-difficulty-20261024'
uid=sys.argv[1]
def command(args): return subprocess.run(args,check=True,capture_output=True,text=True)
try:
    command(['xcrun','simctl','boot',uid])
    command(['xcrun','simctl','bootstatus',uid,'-b'])
    with (HERE/'native.log').open('w') as log:
        r=subprocess.run(['xcrun','simctl','spawn',uid,str(HERE.parent/'two-ball-b43-trajectories-20261024/Worker.app/Worker')],
            input=(HERE/'input.json').read_text()+'\n',stdout=subprocess.PIPE,stderr=log,text=True,timeout=180,check=True)
    (HERE/'native-stdout.txt').write_text(r.stdout)
    result=next(json.loads(l.split('\t',1)[1]) for l in r.stdout.splitlines() if l.startswith('RESULT\t'))
    originals=json.loads((HERE/'original-rows.json').read_text())
    differences=[]
    for old,new in zip(originals,result['rows'],strict=True):
        for k,v in old.items():
            if k not in ['trialID','wallMilliseconds'] and new.get(k)!=v:
                differences.append([old['comboIndex'],k,v,new.get(k)])
        path=new['paths']['cueBall']
        assert len(path)>10 and all(math.isfinite(v) for pt in path for v in pt)
        assert math.dist(path[0][1:],result['board']['cue'])<1e-6
        assert math.dist(path[-1][1:],new['cueStop'])<1e-6
    audit=dict(exactOldFieldsMatch=not differences,differences=differences,
               combinations=[r['comboIndex'] for r in result['rows']],
               sampleCounts=[len(r['paths']['cueBall']) for r in result['rows']],
               nativeBinarySHA256=hashlib.sha256((HERE.parent/'two-ball-b43-trajectories-20261024/Worker.app/Worker').read_bytes()).hexdigest(),
               scope='same scoring-only predictor; sample recorder through production TrajectoryPlayback at 120Hz plus all event/frame timestamps; B43 absent from simulation')
    (OUT/'b43-top10-trajectories-validation.json').write_text(json.dumps(audit,indent=2))
    assert not differences, differences
    (OUT/'b43-top10-trajectories.json').write_text(json.dumps(result,indent=2))
    print(json.dumps(audit))
finally:
    command(['xcrun','simctl','shutdown',uid])
