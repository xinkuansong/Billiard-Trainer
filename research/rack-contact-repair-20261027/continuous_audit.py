from pathlib import Path
import json,gzip,itertools,math
import numpy as np
O=Path('output/rack-contact-repair-20261027');results=[]
def acceleration(b,p):
 v=np.array(b['v']);w=np.array(b['w'])
 if b['state']=='sliding':
  u=v+np.cross(w,[0,-p['ballRadius'],0]);length=np.linalg.norm(u)
  return -p['slidingFriction']*p['gravity']*u/length if length>.0001 else np.zeros(3)
 if b['state']=='rolling':
  length=np.linalg.norm(v)
  return -p['rollingFriction']*p['gravity']*v/length if length>.0001 else np.zeros(3)
 return np.zeros(3)
for line in gzip.open(O/'raw.jsonl.gz','rt'):
 r=json.loads(line)
 if r['input']['mode']!=2 or 'frames' not in r:continue
 params=r['parameters'];R=params['ballRadius'];fs=r['frames'];worst=0;arg=None;intervals=0;checked=0
 for k in range(len(fs[0])-1):
  dt=fs[0][k+1]['t']-fs[0][k]['t']
  if dt<=0:continue
  intervals+=1
  states=[f[k] for f in fs];pos=np.array([b['p'] for b in states])[:,[0,2]];vel=np.array([b['v'] for b in states])[:,[0,2]];acc=np.array([acceleration(b,params) for b in states])[:,[0,2]]
  for i,j in itertools.combinations(range(len(states)),2):
   if states[i]['state']=='pocketed' or states[j]['state']=='pocketed':continue
   dp=pos[j]-pos[i];dv=(vel[j]-vel[i])*dt;da=.5*(acc[j]-acc[i])*dt*dt
   if np.linalg.norm(dp)-np.linalg.norm(dv)-np.linalg.norm(da)>2*R+1e-6:continue
   checked+=1
   coeff=[float(da@da),float(2*da@dv),float(dv@dv+2*dp@da),float(2*dp@dv)]
   dc=np.trim_zeros(np.array([4*coeff[0],3*coeff[1],2*coeff[2],coeff[3]]),'f')
   roots=np.roots(dc) if len(dc)>1 else []
   ts=[0.,1.]+[float(t.real) for t in roots if abs(t.imag)<1e-8 and 0<t.real<1]
   pen,s=max((2*R-float(np.linalg.norm(dp+dv*t+da*t*t)),t) for t in ts)
   if pen>worst:worst=pen;arg=dict(frame=k,time=fs[0][k]['t']+s*dt,pair=[r['names'][i],r['names'][j]],fraction=s)
 results.append(dict(id=r['input']['rackID'],condition=r['input']['condition'],experiment=r['input']['experiment'],intervals=intervals,nearPairIntervals=checked,maxPenetrationM=worst,worst=arg,passes1um=worst<=1e-6))
report=dict(method='Independent Double constant-acceleration distance quartic; minima from cubic derivative over each positive-time frame interval, no interpolation of post-impact velocities',scope='Both known cases 11304 and 11331, all recorded candidate conditions; no assertion for unrecorded full trajectories',runs=len(results),maxPenetrationM=max(x['maxPenetrationM'] for x in results),allPass1um=all(x['passes1um'] for x in results),rows=results)
(O/'continuous-audit.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
assert report['allPass1um']
