from pathlib import Path
import json,gzip,math,collections
O=Path('output/rack-contact-tolerance-20261027');out={}
def approach(a,b):
 dp=[b['p'][i]-a['p'][i] for i in [0,2]];d=math.hypot(*dp)
 return sum(dp[j]*(b['v'][i]-a['v'][i]) for j,i in enumerate([0,2]))/d
for line in gzip.open(O/'raw.jsonl.gz','rt'):
 r=json.loads(line)
 if r['input']['reverse']:continue
 key=str(r['input']['toleranceM']);a=out.setdefault(key,dict(separating=[],largestGaps=[],overlapRuns=[]))
 if r['overlapAudit']['framesOver10um']:a['overlapRuns'].append(dict(id=r['input']['rackID'],audit=r['overlapAudit']))
 for e in r['eventTrace']:
  if e['kind']!='ball':continue
  b,c=e['beforeKissA'],e['beforeKissB'];gap=math.hypot(b['p'][0]-c['p'][0],b['p'][2]-c['p'][2])-2*.028574999421834946
  item=dict(id=r['input']['rackID'],delay=e['t']-r['t0'],gapMM=gap*1000,approachBefore=approach(e['preA'],e['preB']),approachAfter=approach(e['postA'],e['postB']),event=e)
  if item['approachBefore']>1e-6:a['separating'].append(item)
  a['largestGaps']=sorted(a['largestGaps']+[item],key=lambda x:x['gapMM'],reverse=True)[:5]
(O/'anomalies.json').write_text(json.dumps(out,indent=2))
for e,a in out.items():
 print(e,'separating',len(a['separating']),'overlap',a['overlapRuns'])
 if a['separating']:
  b=a['separating'][0];print({k:v for k,v in b.items() if k!='event'})
