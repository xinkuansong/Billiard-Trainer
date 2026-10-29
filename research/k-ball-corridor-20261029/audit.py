from pathlib import Path
import json,math,hashlib,collections
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/k-ball-corridor-20261029'
def read(n):return json.loads((OUT/n).read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
g=read('geometry.json');R=g['radius'];D=2*R;rows=read('trials.json');candidates=read('candidates.json');regions=read('regions.json');replay=read('replay.json');source=json.loads((ROOT/'output/k-ball-natural-review-20261029/data.json').read_text());byregion={e['id']:e for e in regions};events={e['id']:e for e in source['selected']}
def segdist(p,a,b):
 dx,dz=b[0]-a[0],b[1]-a[1];v=dx*dx+dz*dz;t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/v)) if v else 0
 return math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dz)
def pdist(p,pts):return min(segdist(p,a,b) for a,b in zip(pts,pts[1:])) if len(pts)>1 else math.dist(p,pts[0])
expected={(e['id'],a) for a in ['inAngle','outAngle'] for e in source['selected'] if e['id'] in {id for group in source['groups'][a] for id in group['ids']} and e[a]<=45}
assert {(e['sourceID'],e['axis']) for e in regions}==expected
assert len(rows)==len(candidates) and {r['id'] for r in rows}=={r['id'] for r in candidates}
assert len({r['id'] for r in rows})==len(rows)
for e in regions:
 rr=[r for r in rows if r['regionID']==e['id']];assert [r['id'] for r in rr]==e['sampleIDs']
 assert len(rr)<=6
 for band in range(3):assert sum(r['gapBand']==band for r in rr)<=2
 assert all(math.dist(a['B'],b['B'])>=.03 for i,a in enumerate(rr) for b in rr[i+1:])
for r,c in zip(rows,candidates):
 for k,v in c.items():assert r[k]==v,(r['id'],k)
 e=byregion[r['regionID']];p=r['B'];rail=g['rails'][r['railID']];a,z=rail['start'],rail['end'];length=math.dist(a,z)
 along=sum((p[j]-a[j])*(z[j]-a[j])/length for j in [0,1]);assert 0<=along<=length
 gap=segdist(p,a,z)-R;assert 0<=gap<=.15 and abs(gap-r['initialGap'])<1e-8
 assert r['gapBand']*.05<=gap<=(r['gapBand']+1)*.05
 assert pdist(p,e['points'][e['lo']:e['hi']+1])<=.45*D
 assert pdist(p,e['points'][:e['lo']+1])>D+.002
 assert segdist(p,r['seed']['cue'],e['points'][0])>D+.002
 assert min(math.dist(p,r['seed'][name]) for name in ['cue','object'])>D+.002
 assert min(segdist(p,q['lip'][i],q['lip'][(i+1)%len(q['lip'])]) for q in g['pockets'] for i in range(len(q['lip'])))>=.30
 ev=r.get('events',[]);hits=[(i,x) for i,x in enumerate(ev) if x['kind']=='ballBall' and 'cueBall' in x['balls']]
 firstA=bool(hits) and set(hits[0][1]['balls'])=={'cueBall','object'}
 laterB=firstA and any(i>hits[0][0] and set(x['balls'])=={'cueBall','kTarget'} for i,x in hits)
 pot=any(x['kind']=='pocket' and x['ball']=='object' and x['pocket']==f"pocket_{r['seed']['pocket']}" for x in ev)
 scratch=any(x['kind']=='pocket' and x['ball']=='cueBall' for x in ev)
 success=bool(r.get('complete') and firstA and laterB and pot and not scratch)
 assert success==r['success'],r['id']
 if success:
  first=hits[0][0];hit=next(i for i,x in hits if i>first and set(x['balls'])=={'cueBall','kTarget'})
  rails=[x['cushion'] for x in ev[first+1:hit] if x['kind']=='cushion' and x['ball']=='cueBall' and x['cushion']<6]
  assert rails==r['railsBeforeK']
  # Classification assertion only; not an added success rule.
  assert len(rails)==r['expectedRails'],('classification drift',r['id'])
  assert rails==[c['cushionID'] for c in events[r['sourceID']]['route']['trajectory2mm']['cushions']][:len(rails)]
 for tr in r.get('tracks',{}).values():
  assert all(all(math.isfinite(v) for v in p) for p in tr)
  assert all(a[0]<=b[0] for a,b in zip(tr,tr[1:]))
assert {p['id'] for p in replay}=={r['id'] for r in rows if r['success']}
assert all(p['exactReplay'] and p['success'] for p in replay)
for b in read('source-binding.json')['sources']:assert sha(ROOT/b['path'])==b['sha256'],b['path']
assert sha(ROOT/'research/k-ball-corridor-20261029/main.swift')==read('source-binding.json')['entrySHA256']
report=dict(passed=True,regions=len(regions),trials=len(rows),success=sum(r['success'] for r in rows),replays=len(replay),failures=dict(collections.Counter(r['reason'] for r in rows if not r['success'])),groupRegions=dict(collections.Counter(e['axis'] for e in regions)),gapBands=dict(collections.Counter(r['gapBand'] for r in rows)),actualKCounts=dict(collections.Counter(len(r['railsBeforeK']) for r in rows if r['success'])),checks=['All <=45 degree selected segments included even when empty','Tube half width, finite rail gap, 3 strata, far pocket and no earlier cue contact','All candidates preserved, no post-contact quality filtering','Independent ordered-event success check','Actual rail prefix consistent with before/after labels','Deterministic exact replay of every success','Source SHA bindings'],files={n:sha(OUT/n) for n in ['geometry.json','candidates.json','regions.json','trials.json','samples.json','replay.json','source-binding.json']})
(OUT/'audit.json').write_text(json.dumps(report,indent=2));print(json.dumps({k:v for k,v in report.items() if k not in ['files','checks']},ensure_ascii=False))
