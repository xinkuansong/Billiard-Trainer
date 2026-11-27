"""Independent evidence audit and deterministic representative selection."""
from pathlib import Path
import json, math, hashlib, collections
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/kick-grid-sample-20261030'
rows=json.loads((OUT/'accepted.json').read_text())
g=json.loads((OUT/'geometry.json').read_text())
rays=json.loads((OUT/'sampling.json').read_text())['rays']
verify=json.loads((OUT/'verification.json').read_text())
assert len(rays)==5184
raymap={(r['cell'],r['degrees']):r for r in rays}
assert len(raymap)==5184 and len({tuple(r['cue']) for r in rays})==5184
for r in rays:
    x,z=r['cue'];ix,iz=r['ix'],r['iz'];L,W=g['length'],g['width']
    assert -L/2+ix*L/24<=x<=-L/2+(ix+1)*L/24
    assert -W/2+iz*W/12<=z<=-W/2+(iz+1)*W/12
    assert x<=0 and z<=0 and r['degrees']%5==0
def wall(rail):
    nx,nz=g['rails'][rail]['normal']
    return (0 if nx>0 else 1) if abs(nx)>.5 else (2 if nz>0 else 3)
for r in rows:
    s=r['seed'];orig=raymap[s['cell'],s['slot']*5]
    assert math.dist(s['cue'],orig['cue'])<1e-6
    assert math.dist(s['dir'],orig['dir'])<1e-6
    assert s['sx'] in [0,-.25,.25,-.5,.5] and s['v'] in [1.5,2.5,3.5,4.5] and s['sy']==0
    hit=next(e for e in r['events'] if e['kind']=='ballBall' and set(e['balls'])=={'cueBall','object'})
    events=[e for e in r['events'] if e['index']<hit['index'] and e['kind']=='cushion' and e.get('ball')=='cueBall']
    rails=[e['rail'] for e in events]
    assert rails==r['rails'] and len(rails)==r['n'] and 1<=r['n']<=6
    assert all(0<=v<6 for v in rails)
    assert r['complete'] and 'cueBall' not in r['pocketedBalls']
    assert len(r['railAngles'])==r['n'] and all(15<=v<=75 for v in r['railAngles'])
    for e in events:
        a,b=g['rails'][e['rail']]['start'],g['rails'][e['rail']]['end']
        length=math.dist(a,b);q=e['cue']
        t=sum((q[i]-a[i])*(b[i]-a[i]) for i in range(2))/length
        assert .10-1e-6<=t<=length-.10+1e-6
    walls=list(map(wall,rails))
    assert walls==r['walls']
    assert not any(a==c and b==d and a!=b and a//2==b//2 for a,b,c,d in zip(walls,walls[1:],walls[2:],walls[3:]))
    before=[p[1:] for p in r['cueTrack'] if p[0]<=events[0]['time']]
    assert sum(math.dist(a,b) for a,b in zip(before,before[1:]))>=.20-1e-6
    assert abs(r['offsetR'])<=.9
    assert abs(math.dist(r['target'],r['placementCenter'])-abs(r['offsetR'])*g['radius'])<1e-8
    assert math.dist(s['cue'],r['target'])>2*g['radius']
assert len({(r['seed']['id'],r['n']) for r in rows})==len(rows)
assert {r['id'] for r in rows}=={r['id'] for r in verify} and all(r['exactReplay'] for r in verify)
binding=json.loads((OUT/'source-binding.json').read_text())
drift=[b['path'] for b in binding['sources'] if b['currentProduction'] and hashlib.sha256((ROOT/b['path']).read_bytes()).hexdigest()!=b['sha256']]
assert not drift,drift
selected=[]
for n in range(1,7):
    used=set()
    for category,quota in [('zero',2),('leftLight',1),('rightLight',1),('leftMedium',1),('rightMedium',1)]:
        options=[r for r in rows if r['n']==n and r['category']==category]
        for _ in range(quota):
            if not options:break
            options.sort(key=lambda r:(r['seed']['cell'] in used,abs(r['offsetR']),r['id']))
            row=options.pop(0);selected.append(row);used.add(row['seed']['cell'])
for i,r in enumerate(selected):r['displayID']=f'G{i+1:02d}'
(OUT/'selected.json').write_text(json.dumps(selected))
audit=dict(candidates=len(rows),selected=len(selected),replays=len(verify),
           perturbations=sum(len(v['probes']) for v in verify),
           perturbationsSucceeded=sum(p['success'] for v in verify for p in v['probes']),
           perRail=dict(collections.Counter(r['n'] for r in rows)),
           selectedPerRail=dict(collections.Counter(r['n'] for r in selected)),
           acceptedCells=len({r['seed']['cell'] for r in rows}),selectedCells=len({r['seed']['cell'] for r in selected}),
           uniqueRandomPositions=len(rays),sourceDrift=drift,
           boundary='Finite sample; no full-bank coverage, full tolerance grading, symmetry replay or real-table calibration.')
(OUT/'audit.json').write_text(json.dumps(audit,indent=2))
print(json.dumps(audit,indent=2))
