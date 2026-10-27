"""Export existing native trajectories. No simulation or engine edits."""
import gzip, hashlib, json, math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'output/rack-front-core-20261027'
OUT = ROOT / 'output/rack-front-playback-20261027'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
defs = [
    (80179, '改善最大例', '按前阵心球5ms速度增幅选出；是最佳收益个例，不代表平均效果。'),
    (80139, '候选速度居中例', '候选5ms速度在200副中排名第100；不代表所有指标都居中。'),
    (80000, '原定首副样本', '按种子顺序的第一副，几乎没有改善。'),
    (80067, '退步最大例', '按前阵心球5ms速度降幅选出，展示候选的局限。'),
    (80087, '候选前球最快例', '候选5ms前球速度最高，但方案B也同样快；不能把它归功于这次优化。'),
]
selected = {d[0] for d in defs}
scalars = json.loads((SRC/'scalars.json').read_text())
metrics = {(s['id'], s['policy']): s for s in scalars if s['cohort']=='holdout' and s['condition']=='original'}
allids = range(80000, 80200)
delta = lambda i: metrics[i,'exit_-30']['frontSpeed5']-metrics[i,'parentB']['frontSpeed5']
assert max(allids,key=delta)==80179 and min(allids,key=delta)==80067
assert sorted(allids,key=lambda i:metrics[i,'exit_-30']['frontSpeed5'])[99]==80139
assert max(allids,key=lambda i:metrics[i,'exit_-30']['frontSpeed5'])==80087
rows = {}
with gzip.open(SRC/'raw.jsonl.gz', 'rt') as f:
    for line in f:
        r = json.loads(line); q=r['input']
        if q['cohort']=='holdout' and q['rackID'] in selected and q['condition']=='original' and q['policy'] in ['parentB','exit_-30']:
            rows[q['rackID'],q['policy']] = r
assert len(rows)==10
with gzip.open(OUT/'captured.jsonl.gz', 'rt') as f:
    for line in f:
        r=json.loads(line);rows[r['input']['rackID'],r['input']['policy']]=r

def evolve(f, t, p):
    dt=max(0,t-f['t']); x,z=f['p'][0],f['p'][2]; vx,vz=f['v'][0],f['v'][2]
    ax=az=0
    if f['state']=='sliding':
        ux=vx+p['ballRadius']*f['w'][2]; uz=vz-p['ballRadius']*f['w'][0]; n=math.hypot(ux,uz)
        if n>1e-4: ax,az=-p['slidingFriction']*p['gravity']*ux/n,-p['slidingFriction']*p['gravity']*uz/n
    elif f['state']=='rolling':
        n=math.hypot(vx,vz)
        if n>1e-4: ax,az=-p['rollingFriction']*p['gravity']*vx/n,-p['rollingFriction']*p['gravity']*vz/n
    return [x+vx*dt+.5*ax*dt*dt,z+vz*dt+.5*az*dt*dt,vx+ax*dt,vz+az*dt]

cases=[];max_p=max_v=0;states=set()
for rid,label,note in defs:
    c=dict(id=rid,label=label,note=note,variants=[])
    for pol in ['parentB','exit_-30']:
        r=rows[rid,pol];m=metrics[rid,pol];front=r['names'].index(r['canonicalNames'][4])
        for sample in r['samples']:
            target=r['t0']+sample['delay']
            for i,fs in enumerate(r['frames']):
                f=next(x for x in reversed(fs) if x['t']<=target)
                a=evolve(f,target,r['parameters']);b=sample['states'][i]
                max_p=max(max_p,math.hypot(a[0]-b['p'][0],a[1]-b['p'][2]));max_v=max(max_v,math.hypot(a[2]-b['v'][0],a[3]-b['v'][2]))
        trajectories=[]
        for fs in r['frames']:
            assert all(a['t']<=b['t'] for a,b in zip(fs,fs[1:]))
            for f in fs: states.add(f['state'])
            trajectories.append([[f['t'],f['p'][0],f['p'][2],f['v'][0],f['v'][2],f['w'][0],f['w'][2],f['state']] for f in fs])
        ev=[]
        for e in r['eventTrace']:
            if e['kind']!='ball':continue
            for own,other in [('A','B'),('B','A')]:
                if e['pre'+own]['name']!=r['names'][front]:continue
                pre=e['pre'+own]['v'];post=e['post'+own]['v'];partner=e['pre'+other]['name']
                ev.append(dict(t=e['t'],delay=(e['t']-r['t0'])*1000,partner=partner,pre=math.sqrt(sum(v*v for v in pre)),post=math.sqrt(sum(v*v for v in post))))
        c['variants'].append(dict(policy=pol,names=r['names'],front=front,frames=trajectories,t0=r['t0'],duration=r['duration'],events=ev,
            parameters=r['parameters'],speed5=m['frontSpeed5'],speed20=m['frontSpeed20'],tail=m['tail'],pocketed=r['pocketed'],cueVelocity=r['initialCueVelocity'],
            board=r['board'],samples=r['samples'],rack=r['rack']))
    a,b=c['variants'];assert a['names']==b['names'] and a['front']==b['front'] and a['parameters']==b['parameters'] and a['cueVelocity']==b['cueVelocity'] and a['t0']==b['t0']
    c['duration']=max(a['duration'],b['duration']);cases.append(c)
assert max_p<3e-6 and max_v<3e-5,(max_p,max_v)
data=dict(length=2.54,width=1.27,radius=rows[80179,'parentB']['parameters']['ballRadius'],cases=cases)
(OUT/'data.js').write_text('window.REPLAY_DATA='+json.dumps(data,separators=(',',':'),ensure_ascii=False)+';\n')
audit=dict(sourceSHA={f:sha(SRC/f) for f in ['raw.jsonl.gz','scalars.json','verification.json']},captureSHA=sha(OUT/'captured.jsonl.gz'),cases=[dict(id=i,label=l,note=n) for i,l,n in defs],simulationsRun=8,trajectories=10,states=sorted(states),snapshotPositionMaxErrorM=max_p,snapshotVelocityMaxErrorMPS=max_v,
    interpolation='Replay native post-event frames with the existing sliding/rolling closed-form translation until the next recorded frame. No collision calculation. Spin not visualized.',
    coordinates='X right, Z down, metres; true ball/table ratio; table/pocket appearance simplified')
(OUT/'data-audit.json').write_text(json.dumps(audit,indent=2,ensure_ascii=False)+'\n')
print(json.dumps(audit,ensure_ascii=False,indent=2))
