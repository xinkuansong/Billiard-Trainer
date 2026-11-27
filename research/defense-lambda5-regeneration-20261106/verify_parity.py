from pathlib import Path
import json,sys,math
out=Path(sys.argv[1]);root=Path(__file__).resolve().parents[2]
# Also works from frozen tooling copy.
if not (root/'output').exists():root=out.parents[1]
old=json.loads((root/'output/defense-lambda5-factors-20261106/results.json').read_text())
new=json.loads((out/'results.json').read_text());assert len(new)==len(old)==52
compared=0;bounds=[];maxdiff=0
for a,b in zip(old,new):
 assert a['case']==b['case'];oldv=a['variants'][0];newv=b['variants'][0]
 x,y=oldv['effect'],newv['effect'];assert y['scoringVersion']=='defense-target-pipe-cut-lambda5-v9'
 assert math.isfinite(y['score']) and 0<=y['score']<=100
 if x.get('pipeRoute') is None and x.get('estimateReason'):
  expected=100*math.sqrt((1-y['comfort']/100)/(1+5*y['targetPipeToleranceDegrees']))
  assert abs(y['score']-expected)<1e-8 and y['score']<=x['score']
  bounds.append(dict(id=b['case']['id'],old=x['score'],new=y['score']));continue
 diff=abs(x['score']-y['score']);assert diff<1e-7,(b['case']['id'],x,y);maxdiff=max(maxdiff,diff);compared+=1
 for p,q in zip(oldv['pockets'],newv['pockets']):
  assert p['pocket']==q['pocket'] and p['routeCount']==q['routeCount']
  if 'route' in p:
   assert abs(p['score']-q['score'])<1e-7
   assert abs(p['route']['experimentCutDegrees']-q['route']['cutDegrees'])<1e-9
(out/'parity-validation.json').write_text(json.dumps(dict(passed=True,cases=52,matched=compared,maximumScoreDifference=maxdiff,conservativeBoundUpgrade=bounds),indent=2))
print('Production parity PASS',compared,'cases; revised conservative bounds',bounds,flush=True)
