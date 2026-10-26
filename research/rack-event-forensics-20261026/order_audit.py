from pathlib import Path
import json,gzip,math,collections
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-event-forensics-20261026'
rows={}
for p in (ROOT/'output/rack-contact-factorial-20261026').glob('raw-*.gz'):
 with gzip.open(p,'rt') as f:
  for l in f:
   r=json.loads(l);i=r['input']
   if i['contactEpsilon']==1e-6 and i['tieEpsilon']==1e-12:rows[i['rackID'],i['reverseRegistration']]=r
result=[]
for rid in sorted({k[0] for k in rows}):
 a,b=rows[rid,False],rows[rid,True];aa=a['impulseTrace'];bb=b['impulseTrace'];first=None;firstSchedule=None
 for k,(x,y) in enumerate(zip(aa,bb)):
  if x['t']!=y['t'] or [c['slot'] for c in x['changed']]!=[c['slot'] for c in y['changed']]:
   firstSchedule=dict(index=k,tA=x['t'],tB=y['t'],slotsA=[c['slot'] for c in x['changed']],slotsB=[c['slot'] for c in y['changed']]);break
  if x!=y and first is None:
   deltas={field:max(math.dist(c[field],d[field]) for c,d in zip(x['changed'],y['changed'])) for field in ['preP','p','preV','postV','preW','postW']}
   first=dict(index=k,t=x['t'],slots=[c['slot'] for c in x['changed']],deltas=deltas,preExactlyEqual=all(c[field]==d[field] for c,d in zip(x['changed'],y['changed']) for field in ['preP','preV','preW']))
 result.append(dict(rackID=rid,firstStateDifference=first,firstScheduleDifference=firstSchedule))
summary=dict(n=len(result),samePreStateAtFirstDifference=sum(r['firstStateDifference'] is not None and r['firstStateDifference']['preExactlyEqual'] for r in result),missingStateDifference=sum(r['firstStateDifference'] is None for r in result),firstDifferenceEventCounts=dict(collections.Counter(r['firstStateDifference']['index'] if r['firstStateDifference'] else -1 for r in result)),maxFirstVelocityDifference=max(r['firstStateDifference']['deltas']['postV'] for r in result if r['firstStateDifference']),rows=result)
(OUT/'order-audit.json').write_text(json.dumps(summary,indent=2));print(json.dumps({k:v for k,v in summary.items() if k!='rows'},indent=2));print(json.dumps(result[:3],indent=2))
