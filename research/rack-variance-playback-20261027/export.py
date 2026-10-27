from pathlib import Path
import json,gzip,hashlib,math
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-variance-playback-20261027';SRC=ROOT/'output/rack-variance-minimize-20261027'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
defs=json.loads((OUT/'selection.json').read_text())
rows={}
for line in gzip.open(OUT/'captured.jsonl.gz','rt'):
 r=json.loads(line);rows[r['input']['rackID'],r['input']['policy']]=r
assert len(rows)==10
metrics={(r['id'],r['policy']):r for r in json.loads((SRC/'scalars.json').read_text()) if r['cohort']=='holdout'}
def pose(f,t,p):
 dt=max(0,t-f['t']);vx,vz=f['v'][0],f['v'][2];ax=az=0
 if f['state']=='sliding':
  ux,uz=vx+p['ballRadius']*f['w'][2],vz-p['ballRadius']*f['w'][0];n=math.hypot(ux,uz)
  if n>1e-4:ax,az=-p['slidingFriction']*p['gravity']*ux/n,-p['slidingFriction']*p['gravity']*uz/n
 elif f['state']=='rolling':
  n=math.hypot(vx,vz)
  if n>1e-4:ax,az=-p['rollingFriction']*p['gravity']*vx/n,-p['rollingFriction']*p['gravity']*vz/n
 return [f['p'][0]+vx*dt+.5*ax*dt*dt,f['p'][2]+vz*dt+.5*az*dt*dt,vx+ax*dt,vz+az*dt]
cases=[];pe=ve=be=0.;count=0
for rid,label,note in defs:
 c=dict(id=rid,label=label,note=note,variants=[])
 for pol in ['E','gate50']:
  r=rows[rid,pol];m=metrics[rid,pol];corners=[r['names'].index(r['canonicalNames'][i]) for i in [10,14]]
  for sample in r['samples']:
   t=r['t0']+sample['delay']
   for fs,b in zip(r['frames'],sample['states']):
    f=next(x for x in reversed(fs) if x['t']<=t);a=pose(f,t,r['parameters']);count+=1
    pe=max(pe,math.hypot(a[0]-b['p'][0],a[1]-b['p'][2]));ve=max(ve,math.hypot(a[2]-b['v'][0],a[3]-b['v'][2]))
  tracks=[]
  for name,fs in zip(r['names'],r['frames']):
   assert all(a['t']<=b['t'] for a,b in zip(fs,fs[1:]))
   last=fs[-1]
   if name in r['board']:
    target=r['board'][name];be=max(be,math.hypot(last['p'][0]-(target[0]-.5)*2.5399999618530273,last['p'][2]-(target[1]-.25)*2.5399999618530273))
    assert last['state']!='pocketed'
   else:assert last['state']=='pocketed'
   tracks.append([[f['t'],f['p'][0],f['p'][2],f['v'][0],f['v'][2],f['w'][0],f['w'][2],f['state']] for f in fs])
  sm=next(s for s in r['samples'] if round(s['delay']*1000)==5)
  speed5=[math.sqrt(sum(v*v for v in sm['states'][i]['v'])) for i in corners]
  c['variants'].append(dict(policy=pol,names=r['names'],corners=corners,frames=tracks,t0=r['t0'],duration=r['duration'],parameters=r['parameters'],
   cornerSpeed5=speed5,variance5=m['variance5'],variance20=m['variance20'],tail=m['tail'],pocketed=r['pocketed'],cueVelocity=r['initialCueVelocity'],board=r['board'],samples=r['samples']))
 a,b=c['variants'];assert a['names']==b['names'] and a['corners']==b['corners'] and a['parameters']==b['parameters'] and a['cueVelocity']==b['cueVelocity'] and a['t0']==b['t0']
 c['duration']=max(a['duration'],b['duration']);cases.append(c)
assert pe<3e-6 and ve<3e-5 and be<3e-6,(pe,ve,be)
data=dict(length=2.5399999618530273,width=1.2699999809265137,radius=a['parameters']['ballRadius'],cases=cases)
(OUT/'data.js').write_text('window.REPLAY_DATA='+json.dumps(data,ensure_ascii=False,separators=(',',':'))+';\n')
audit=dict(trajectories=10,snapshotChecks=count,maxPositionErrorM=pe,maxVelocityErrorMPS=ve,maxFinalPositionErrorM=be,sourceSHA={x:sha(SRC/x) for x in ['raw.jsonl.gz','scalars.json']},captureSHA=sha(OUT/'captured.jsonl.gz'),
 coordinates='X right, Z down, metres. Ball and table true ratio; pockets simplified. Spin not animated.',selection=defs)
(OUT/'data-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n');print(json.dumps(audit,ensure_ascii=False))
