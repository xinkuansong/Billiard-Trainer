from pathlib import Path
import gzip,json,math
import numpy as np
O=Path('output/rack-contact-repair-20261027')
with gzip.open(O/'raw.jsonl.gz','rt') as f:rows=[json.loads(next(f)),json.loads(next(f))]
findings=[]
for r in rows:
 for e in r['eventTrace']:
  if e['kind']!='ball':continue
  a,b=e['preA'],e['preB'];dp=np.array(b['p'])-np.array(a['p']);dv=np.array(b['v'])-np.array(a['v']);dp[1]=dv[1]=0
  if dp@dv<=0:continue
  names={a['name'],b['name']}
  candidates=[p for p in r['predictions'] if p['origin']=='selected' and {p['a']['name'],p['b']['name']}==names and abs(p['t']+p['dt']-e['t'])<1e-8]
  if not candidates:findings.append(dict(mode=r['input']['mode'],event=e,noSelectedPrediction=True));continue
  def match_error(p):
   before={a['name']:a,b['name']:b}
   return max(np.linalg.norm(np.array(p[k]['v'])+np.array(p[acc])*p['dt']-np.array(before[p[k]['name']]['v'])) for k,acc in [('a','aa'),('b','ab')])
  pred=min(candidates,key=match_error);assert match_error(pred)<1e-5,(match_error(pred),e['t'])
  origins=[p['origin'] for p in r['predictions'] if p['t']==pred['t'] and p['dt']==pred['dt'] and {p['a']['name'],p['b']['name']}==names and p['origin']!='selected' and p['a']==pred['a'] and p['b']==pred['b']]
  p=np.array(pred['b']['p'])-np.array(pred['a']['p']);v=np.array(pred['b']['v'])-np.array(pred['a']['v']);acc=np.array(pred['ab'])-np.array(pred['aa']);p[1]=v[1]=acc[1]=0;radius=r['parameters']['ballRadius']
  co=[float(acc@acc/4),float(acc@v),float(v@v+p@acc),float(2*p@v),float(p@p-4*radius**2)]
  roots=np.roots(np.trim_zeros(np.array(co),'f'))
  real=[float(x.real) for x in roots if abs(x.imag)<1e-8]
  dt=pred['dt'];q=p+v*dt+.5*acc*dt*dt
  findings.append(dict(mode=r['input']['mode'],time=e['t'],pair=sorted(names),gapAtResponseM=float(np.linalg.norm(dp)-2*radius),separatingSpeed=float(dp@dv/np.linalg.norm(dp)),origin=origins,prediction=pred,coefficients=co,independentRealRoots=real,predictedGapAtReturnedTimeM=float(np.linalg.norm(q)-2*radius),distanceSquaredResidual=float(np.polyval(co,dt)),event=e))
result=dict(case=11304,oldInvalidResponses=sum(f['mode']==0 for f in findings),repairInvalidResponses=sum(f['mode']==2 for f in findings),findings=findings,repairRejected=rows[1]['rejectedPairs'])
(O/'prediction-audit.json').write_text(json.dumps(result,indent=2))
for f in findings:print({k:v for k,v in f.items() if k not in ['event','prediction','coefficients']})
print('invalid:',result['oldInvalidResponses'],result['repairInvalidResponses'])
