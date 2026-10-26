from pathlib import Path
from decimal import Decimal,localcontext
import json,gzip,math
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-event-forensics-20261026'
rows=[json.loads(l) for l in gzip.open(OUT/'raw.jsonl.gz','rt')];anomalies=[];order=[]
for r in rows:
 trace=r['researchTrace']
 for j,event in enumerate(trace):
  if event['phase']!='beforeImpulse' or event['approach']>=-1e-5:continue
  sel=next(x for x in reversed(trace[:j]) if x['phase']=='selected')
  candidate=[x for x in trace[:j] if x['phase']=='candidate' and x['now']==sel['now'] and x['dt']==sel['dt'] and {x['a']['name'],x['b']['name']}=={sel['a'],sel['b']}][-1]
  coeff=candidate['coefficients'];t=candidate['dt']
  with localcontext() as ctx:
   ctx.prec=60
   d=[Decimal.from_float(x) for x in coeff];dt=Decimal.from_float(t);res=Decimal(0)
   for c in d:res=res*dt+c
   scale=max(Decimal(1),max(abs(c*dt**(4-k)) for k,c in enumerate(d)))
  anomalies.append(dict(id=r['input']['id'],relativeTime=event['now']-r['t0'],source=candidate['source'],gapMM=event['gap']*1000,approach=event['approach'],candidate=candidate,exactPositiveCoefficientProof=all(x>=0 for x in coeff) and coeff[-1]>0,decimalResidual=str(res),acceptedByLegacyResidualRule=abs(res/scale)<=Decimal('0.0001')))
 if r['input']['rackID']==2000 and r['input']['contactEpsilon']==1e-6:
  before=[x for x in trace if x['phase']=='beforeImpulse'][1]
  after=[x for x in trace if x['phase']=='afterImpulse'][1]
  order.append(dict(reverse=r['input']['reverseRegistration'],before=before,after=after))
assert len(order)==2
order.sort(key=lambda x:x['reverse']);x,y=order
preA={x['before'][k]['name']:x['before'][k] for k in ['a','b']};preB={y['before'][k]['name']:y['before'][k] for k in ['a','b']};assert preA==preB
postA={x['after'][k]['name']:x['after'][k] for k in ['a','b']};postB={y['after'][k]['name']:y['after'][k] for k in ['a','b']}
observed=max(math.dist(postA[k]['v'],postB[k]['v']) for k in postA);assert observed==x['before']['swapVelocityDelta']
proof=[a for a in anomalies if a['id']=='2037-1e-06-1e-12-False' and a['approach'] < -1][0];assert proof['source']=='quartic' and proof['exactPositiveCoefficientProof'] and proof['acceptedByLegacyResidualRule'] and not proof['candidate']['boundedRoots']
allorder=json.loads((OUT/'order-audit.json').read_text());assert allorder['samePreStateAtFirstDifference']==200
summary=dict(records=len(rows),exactReplays=12,anomalyEvents=len(anomalies),positiveCoefficientCounterexample=proof,orientationProof=dict(rackID=2000,relativeTime=x['before']['now']-rows[0]['t0'],samePhysicalPreState=True,forwardArguments=[x['before'][k]['name'] for k in ['a','b']],reverseArguments=[y['before'][k]['name'] for k in ['a','b']],observedVelocityDelta=observed,swapProbeDelta=x['before']['swapVelocityDelta']),orderSummary={k:v for k,v in allorder.items() if k!='rows'})
(OUT/'analysis.json').write_text(json.dumps(summary,indent=2));(OUT/'anomaly-origins.json').write_text(json.dumps(anomalies,indent=2));print(json.dumps(summary,indent=2))
