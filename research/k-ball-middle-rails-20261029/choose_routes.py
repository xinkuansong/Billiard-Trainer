"""Add a bounded, angle-spread middle-pocket review batch; retain prior cards."""
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/k-ball-middle-rails-20261029'
pool=json.loads((OUT/'scan-pool.json').read_text())
base=ROOT/'output/k-ball-natural-review-20261029/data.json'
data=json.loads(base.read_text());chosen={};selection={}
for ordinal in (1,3):
 for axis in ['inAngle','outAngle']:
  eligible=[e for e in pool if e['railOrdinal']==ordinal and e['eligibility'][axis]['passed'] and e[axis]<=45]
  angles=sorted(e[axis] for e in eligible);used=set();keys=[]
  # Eight quantile targets, alternating upper/lower middle pockets, unique layouts per group.
  for i in range(min(8,len(eligible))):
   target=angles[round(i*(len(angles)-1)/7)]
   available=[e for e in eligible if e['layout'] not in used]
   preferred=[e for e in available if e['board']['pocket']==4+i%2]
   e=min(preferred or available,key=lambda e:(abs(e[axis]-target),e['reviewMetrics']['prefixMeters'],e['key']))
   used.add(e['layout']);keys.append(e['key'])
   if e['key'] not in chosen:chosen[e['key']]=dict(e,id=f'M{len(chosen)+1:02d}')
  selection[f'{ordinal}-{axis}']=dict(poolCount=len(eligible),keys=keys)
  for key in keys:
   e=chosen[key];bucket=min(5,int(e[axis]/15));data['groups'][axis][bucket]['ids'].append(e['id'])
data['selected']+=list(chosen.values())
data['middleExpansion']=dict(scope='All matching archived middle-pocket layouts with source cut angle 10–45 degrees; first/third cushion, unchanged natural-route filters',selection=selection,baseSHA256=hashlib.sha256(base.read_bytes()).hexdigest(),scanPoolSHA256=hashlib.sha256((OUT/'scan-pool.json').read_bytes()).hexdigest())
(OUT/'source-data.json').write_text(json.dumps(data))
(OUT/'selection.json').write_text(json.dumps(data['middleExpansion'],indent=2))
print('ADDED',len(chosen),'events',sum(len(x['keys']) for x in selection.values()),'group fragments',flush=True)
