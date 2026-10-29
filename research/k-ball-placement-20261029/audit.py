from pathlib import Path
import json,math,hashlib,collections
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/k-ball-placement-20261029'
def read(n):return json.loads((OUT/n).read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
g=read('geometry.json');rows=read('trials.json');samples=read('samples.json');probes=read('perturbations.json');bases=read('baselines.json');source=json.loads((ROOT/'output/k-ball-natural-review-20261029/data.json').read_text());events={e['id']:e for e in source['selected']};R=g['radius']
def segdist(p,a,b):
 dx,dz=b[0]-a[0],b[1]-a[1];u=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/(dx*dx+dz*dz))) if dx*dx+dz*dz else 0
 return math.hypot(p[0]-a[0]-u*dx,p[1]-a[1]-u*dz)
assert len({r['id'] for r in rows})==len(rows)
assert {r['id'] for r in samples}=={r['id'] for r in probes}
assert all(p['exactReplay'] and len(p['perturbations'])==8 for p in probes)
for r in rows:
 e=events[r['sourceID']];assert e['key']==r['sourceKey'] and e[r['axis']]<=45
 assert r['sourceID'] in {id for group in source['groups'][r['axis']] for id in group['ids']}
 rail=g['rails'][r['railID']];distance=segdist(r['B'],rail['start'],rail['end'])-R
 assert abs(distance-r['initialGap'])<1e-6
 assert min(segdist(r['B'],p['lip'][i],p['lip'][(i+1)%len(p['lip'])]) for p in g['pockets'] for i in range(len(p['lip'])))>=.3-1e-8
 assert min(math.dist(r['B'],r['seed'][name]) for name in ['cue','object'])>2*R
 if not r['success']:continue
 assert r['complete'] and 'cueBall' not in r['pocketedBalls'] and r['actualApproachAngle']<=45
 ev=r['events'];hits=[(i,x) for i,x in enumerate(ev) if x['kind']=='ballBall' and 'cueBall' in x['balls']]
 assert hits and set(hits[0][1]['balls'])=={'cueBall','object'}
 first=hits[0][0];hit=next(i for i,x in hits if set(x['balls'])=={'cueBall','kTarget'})
 assert first<hit and first==r['firstAEvent'] and hit==r['firstBEvent']
 assert any(x['kind']=='pocket' and x['ball']=='object' and x['pocket']==f"pocket_{r['seed']['pocket']}" for x in ev)
 actual=[x['cushion'] for x in ev[first+1:hit] if x['kind']=='cushion' and x['ball']=='cueBall']
 assert actual==r['railsBeforeK'] and len(actual)==r['expectedRails']
 assert actual==[x['cushionID'] for x in e['route']['trajectory2mm']['cushions']][:len(actual)]
 assert len(actual)==r['railOrdinal']-(r['axis']=='inAngle')
 assert not any(x['kind']=='ballBall' and set(x['balls'])=={'object','kTarget'} for x in ev[:hit])
 for track in r['tracks'].values():
  assert all(all(math.isfinite(v) for v in p) for p in track)
  assert all(a[0]<=b[0] for a,b in zip(track,track[1:]))
 if 'kTarget' not in r['pocketedBalls']:
  final=r['finalPositions']['kTarget'];assert abs(math.dist(final,r['B'])-r['BDisplacementMeters'])<1e-5
  gap=min(segdist(final,l['start'],l['end']) for l in g['rails'])-R
  assert abs(gap-r['finalBGap'])<1e-5
for r in samples:assert r['success'] and r in rows
binding=read('source-binding.json')
for b in binding['sources']:assert sha(ROOT/b['path'])==b['sha256'],b['path']
assert sha(ROOT/'research/k-ball-placement-20261029/main.swift')==binding['entrySHA256']
# Compare archived post-A points with current no-B full replay, without assuming exact binary identity.
drift=[]
for key,base in bases.items():
 e=next(e for e in events.values() if f"{e['layout']}/{e['route']['comboIndex']}"==key)
 assert base['complete']
 assert any(x['kind']=='pocket' and x['ball']=='object' and x['pocket']==f"pocket_{e['board']['pocket']}" for x in base['events'])
 tr=[p[1:] for p in base['tracks']['cueBall']]
 maxd=max(min(segdist(p[1:],a,b) for a,b in zip(tr,tr[1:])) for p in e['route']['trajectory2mm']['points'])
 drift.append(dict(key=key,maxArchivedPointDistanceMeters=maxd))
report=dict(passed=True,trials=len(rows),passedTrials=sum(r['success'] for r in rows),samples=len(samples),independentProbes=len(probes)*8,probeSuccess=sum(p['success'] for r in probes for p in r['perturbations']),railCounts=dict(collections.Counter(str(r['expectedRails']) for r in samples)),noBReplay=drift,checks=['finite production rail gaps and pocket-lip distances','A first, A specified pocket, cue B later, no scratch','exact prior main-rail IDs and counts','actual contact angle <=45','finite ordered tracks and final metrics','deterministic replay and 8 independent probes per selected sample','source SHA bindings'],limits=['No human success-rate claim','Probe success checks contact rule only, not outcome quality or rail identity','No next-shot potting or useful-breakout target evaluation','Only existing three-shard atlas sources'],files={n:sha(OUT/n) for n in ['geometry.json','candidates.json','trials.json','baselines.json','samples.json','perturbations.json','source-binding.json']})
(OUT/'audit.json').write_text(json.dumps(report,indent=2));print(json.dumps({k:v for k,v in report.items() if k not in ['noBReplay','files','checks','limits']},ensure_ascii=False))
