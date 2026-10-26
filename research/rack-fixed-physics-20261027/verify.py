from pathlib import Path
import gzip,json,math,hashlib,collections
O=Path('output/rack-fixed-physics-20261027');audit={};allrows=[]
for phase,expected in [('pilot',72),('full',1200),('invariance',120)]:
 d=O/phase;cl=json.loads((d/'closure.json').read_text());assert cl['success'] and cl['total']==expected and cl['shutdownExitCode']==0
 assert json.loads((d/'worker-closure.json').read_text())['exitCode']==0
 binding=json.loads((d/'source-binding.json').read_text());assert all(hashlib.sha256(Path(r['path']).read_bytes()).hexdigest()==r['sha256'] for r in binding['production'])
 rs=[json.loads(l) for l in gzip.open(d/'raw.jsonl.gz','rt')];assert len(rs)==expected and all(r['status']=='settled' and not r['researchFailures'] for r in rs)
 allrows+=rs;audit[phase]=dict(runs=len(rs),settled=len(rs),sourceUnchanged=True,shutdown=True)
orig={(r['input']['rackID'],r['input']['experiment']):r for r in allrows if r['input']['condition']=='original'}
params=allrows[0]['parameters'];assert all(r['parameters']==params for r in allrows)
R=params['ballRadius'];M=params['ballMass'];L=2.5399999618530273
checks=[]
for r in allrows:
 c=r['input']['condition']
 if c=='original':continue
 a=orig[r['input']['rackID'],r['input']['experiment']];dp=dv=dw=0
 for sa,sb in zip(a['samples'],r['samples']):
  bm=dict(zip(r['names'],sb['states']))
  for n,x in zip(a['names'],sa['states']):
   p=x['p'][:];v=x['v'][:];w=x['w'][:]
   if c=='mirror':p[2]*=-1;v[2]*=-1;w[0]*=-1;w[1]*=-1
   y=bm[n];dp=max(dp,math.dist(p,y['p']));dv=max(dv,math.dist(v,y['v']));dw=max(dw,math.dist(w,y['w']))
 sameKeys=a['board'].keys()==r['board'].keys();delta=0
 for n in a['board'].keys()&r['board'].keys():
  p=a['board'][n][:]
  if c=='mirror':p[1]=.5-p[1]
  delta=max(delta,math.dist(p,r['board'][n])*L)
 samePockets=a['pocketed']==r['pocketed'];sameDuration=a['duration']==r['duration']
 passed=dp==dv==dw==0 and sameKeys and delta<=1e-6 and samePockets and sameDuration
 checks.append(dict(id=r['input']['rackID'],label=r['input']['experiment'],condition=c,dp=dp,dv=dv,dw=dw,maxBoardDeltaM=delta,pocketedMatch=samePockets,durationMatch=sameDuration,passed=passed))
assert len(checks)==80
probe=json.loads((O/'invariance/metadata.json').read_text())['fixedProbe'];assert probe['passed']
audit['fixtures']=probe
audit['invarianceRun']=audit['invariance']
audit['invariance']=dict(n=len(checks),passed=sum(x['passed'] for x in checks),maxBoardDeltaM=max(x['maxBoardDeltaM'] for x in checks),failures=[x for x in checks if not x['passed']])
events=[]
for r in allrows:
 for c in r['cushionTrace']:
  def energy(s):return .5*M*(sum(v*v for v in s['v'])+.4*R*R*sum(v*v for v in s['w']))
  gain=energy(c['post'])-energy(c['pre']);assert math.isfinite(gain)
  events.append(gain)
audit['cushions']=dict(n=len(events),energyGainAbove1microJ=sum(e>1e-6 for e in events),maxEnergyGainJ=max(events))
audit['parametersIdentical']=True
for n,v in [('verification',audit),('invariance-checks',checks)]: (O/(n+'.json')).write_text(json.dumps(v,indent=2))
print(json.dumps(audit,indent=2));assert all(c['passed'] for c in checks) and not any(e>1e-6 for e in events)
