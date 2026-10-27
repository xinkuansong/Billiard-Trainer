from pathlib import Path
import json,gzip,hashlib,math,statistics as st
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-global-review-20261027'
SETS=['rack-energy-layout-20261027','rack-core-energy-20261027','rack-front-core-20261027']
R=.028574999421834946;D=2*R;L=2.5399999618530273
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def write(n,d):(OUT/n).write_text(json.dumps(d,ensure_ascii=False,indent=2,allow_nan=False)+'\n')
def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
def hull(points):
    p=sorted(set(map(tuple,points)));lo=[];hi=[]
    for group,target in [(p,lo),(p[::-1],hi)]:
        for q in group:
            while len(target)>1 and cross(target[-2],target[-1],q)<=0:target.pop()
            target.append(q)
    return lo[:-1]+hi[:-1]
def outside_distance(p,h):
    edges=list(zip(h,h[1:]+h[:1]))
    if all(cross(a,b,p)>=-1e-14 for a,b in edges):return 0.
    def seg(a,b):
        dx,dz=b[0]-a[0],b[1]-a[1];u=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/(dx*dx+dz*dz)))
        return math.dist(p,[a[0]+u*dx,a[1]+u*dz])
    return min(seg(a,b) for a,b in edges)
assert outside_distance((.5,.5),hull([(0,0),(1,0),(1,1),(0,1)]))==0
assert abs(outside_distance((2,.5),hull([(0,0),(1,0),(1,1),(0,1)]))-1)<1e-12
def clusters(pts,gap):
    edges=[(i,j) for i in range(len(pts)) for j in range(i) if math.dist(pts[i],pts[j])-D<gap]
    touched=set(sum(([i,j] for i,j in edges),[]));parent=list(range(len(pts)))
    def root(i):
        while parent[i]!=i:i=parent[i]
        return i
    for i,j in edges:parent[root(i)]=root(j)
    return len(touched),max((sum(root(j)==root(i) for j in range(len(pts))) for i in range(len(pts))),default=0),len(edges)
def rank(a):
    a=np.asarray(a);order=np.argsort(a);out=np.empty(len(a),float);i=0
    while i<len(a):
        j=i+1
        while j<len(a) and a[order[j]]==a[order[i]]:j+=1
        out[order[i:j]]=(i+j-1)/2;i=j
    return out
def corr(a,b):
    return float(np.corrcoef(a,b)[0,1]) if np.std(a)>0 and np.std(b)>0 else None

before={str(p.relative_to(ROOT)):sha(p) for p in (ROOT/'QiuJi').rglob('*.swift')};write('production-before.json',before)
rows=[];sources={};params=None;engine=None;cue={};crosschecks=0
for batch,name in enumerate(SETS):
    folder=ROOT/'output'/name;frozen=json.loads((folder/'engine-freeze.json').read_text())
    if engine is None:engine=frozen
    assert frozen==engine
    sources[name]={f:sha(folder/f) for f in ['raw.jsonl.gz','scalars.json','engine-freeze.json','verification.json']}
    old={(s['id'],s['policy']):s for s in json.loads((folder/'scalars.json').read_text()) if s['cohort']=='holdout' and s['condition']=='original'}
    with gzip.open(folder/'raw.jsonl.gz','rt') as inp:
        for line in inp:
            r=json.loads(line);q=r['input']
            if q['cohort']!='holdout' or q['condition']!='original':continue
            assert q['mode']==2 and q['power']==10 and r['status']=='settled'
            if params is None:params=r['parameters']
            assert r['parameters']==params
            ck=(batch,q['rackID']);expected=cue.setdefault(ck,r['initialCueVelocity']);assert expected==r['initialCueVelocity']
            o=old[q['rackID'],q['policy']];v=dict(batch=batch,id=q['rackID'],policy=q['policy'],score=o['score'],tail=o['tail'],scratch=o['scratch'])
            names=r['canonicalNames'];initial={f"_{b['number']}":[b['x'],b['z']] for b in r['rack']};poly=hull([initial[n] for n in names]);slots=r['slots']
            neighbors=[(i,j) for i in range(15) for j in range(i) if math.dist(slots[i],slots[j])<D+.001];assert len(neighbors)==30
            for sm in r['samples']:
                ms=round(sm['delay']*1000)
                if ms not in [5,20,100]:continue
                by=dict(zip(r['names'],sm['states']));a=[by[n] for n in names];p=[(s['p'][0],s['p'][2]) for s in a];speeds=np.array([math.sqrt(sum(x*x for x in s['v'])) for s in a]);shares=speeds**2/sum(speeds**2)
                if ms==5:
                    assert all(s['state']!='pocketed' for s in a)
                    v.update(meanSpeed=float(np.mean(speeds)),speedCV=float(np.std(speeds)/np.mean(speeds)),bottom5Speed=float(np.mean(np.sort(speeds)[:5])),top2Share=float(sum(sorted(shares)[-2:])),nEff=float(1/sum(shares**2)),energy=float(.5*params['ballMass']*sum(speeds**2)),active=int(sum(speeds>=1)),slow=int(sum(speeds<.1)),maxSpeed=float(max(speeds)),coherence=float(np.linalg.norm(np.sum([s['v'] for s in a],axis=0))/sum(speeds)))
                    for key,prev in [('nEff','nEff5'),('energy','energy5'),('active','active5'),('slow','slow5')]:assert abs(v[key]-o[prev])<1e-9
                    assert abs(v['meanSpeed']**2*(1+v['speedCV']**2)-2*v['energy']/(15*params['ballMass']))<1e-10
                    crosschecks+=1
                else:
                    present=[s['state']!='pocketed' for s in a];gaps=[math.dist(p[i],p[j])-D for i,j in neighbors if present[i] and present[j]]
                    radial=[]
                    for i,j in neighbors:
                        if not(present[i] and present[j]):continue
                        dp=np.array(p[i])-p[j];dv=np.array([a[i]['v'][0]-a[j]['v'][0],a[i]['v'][2]-a[j]['v'][2]]);radial.append(float(dp@dv/np.linalg.norm(dp)))
                    v.update({f'gap{ms}':st.mean(gaps),f'gapP10_{ms}':float(np.quantile(gaps,.1)),f'closePairs{ms}':sum(g<D for g in gaps),f'opening{ms}':st.mean(x>1e-5 for x in radial),f'earlyPotted{ms}':sum(not x for x in present),f'escape{ms}':sum(outside_distance(p[i],poly)>=D for i in range(15) if present[i])})
            pts=[[p[0]*L,p[1]*L] for n,p in r['board'].items() if n!='cueBall'];n=len(pts);assert n>1
            gaps=[min(math.dist(a,b)-D for j,b in enumerate(pts) if i!=j) for i,a in enumerate(pts)]
            v.update(finalN=n,potted=15-n,nearestGap=st.mean(gaps),nearestGapP10=float(np.quantile(gaps,.1)),tailOver5=int(v['tail']>5))
            for key,factor in [('half',.5),('one',1),('two',2)]:
                near,largest,pairs=clusters(pts,D*factor);v.update({f'crowded_{key}':near,f'crowdedFraction_{key}':near/n,f'largest_{key}':largest,f'pairs_{key}':pairs})
            rows.append(v)
    print(name,'done',flush=True)
assert len(rows)==2000 and crosschecks==2000
keys=[k for k in rows[0] if k not in ['batch','id','policy']]
groups={}
for r in rows:groups.setdefault(f"{r['batch']}:{r['policy']}",[]).append(r)
summary={g:dict(n=len(a),**{k:st.mean(r[k] for r in a) for k in keys}) for g,a in groups.items()};assert all(a['n']==200 for a in summary.values())
comparisons=[(0,'inner_first','baseline'),(0,'template_09','inner_first'),(0,'independent','baseline'),(1,'corerear_90','parent'),(1,'late_60_0_90','parent'),(1,'late_60_0_90','corerear_90'),(2,'exit_-30','parentB'),(2,'exit_-60','parentB'),(2,'exit_-30','exit_-60')]
rng=np.random.default_rng(2026102709);indices=rng.integers(0,200,(4000,200));paired={}
for batch,new,base in comparisons:
    a=sorted(groups[f'{batch}:{new}'],key=lambda r:r['id']);b=sorted(groups[f'{batch}:{base}'],key=lambda r:r['id']);assert [r['id'] for r in a]==[r['id'] for r in b]
    delta=np.array([[x[k]-y[k] for k in keys]for x,y in zip(a,b)]);boots=delta[indices].mean(axis=1);ci=np.quantile(boots,[.025,.975],axis=0)
    paired[f'{batch}:{new}-{base}']={k:dict(mean=float(delta[:,j].mean()),ci95=ci[:,j].tolist(),increased=int(sum(delta[:,j]>1e-12)),decreased=int(sum(delta[:,j]<-1e-12))) for j,k in enumerate(keys)}
associations={}
for g,a in groups.items():
    x=rank([r['speedCV']for r in a]);controls=np.column_stack([np.ones(200),rank([r['energy']for r in a]),rank([r['finalN']for r in a])]);rx=x-controls@np.linalg.lstsq(controls,x,rcond=None)[0]
    associations[g]={}
    for key in ['nearestGap','crowdedFraction_one','score','gap100']:
        y=rank([r[key]for r in a]);ry=y-controls@np.linalg.lstsq(controls,y,rcond=None)[0];associations[g][key]=dict(spearman=corr(x,y),partialRankEnergyAndFinalN=corr(rx,ry))
write('rows.json',rows);write('summary.json',summary);write('paired.json',paired);write('associations.json',associations)
write('source-audit.json',dict(sources=sources,engineSHA=engine,parameters=params,rows=len(rows),cohorts=3,pairedSeeds=600,allSettled=True,scalarCrosschecks=crosschecks,earlyPotted100=sum(r['earlyPotted100']for r in rows),newPhysicsSimulations=0))
assert all(sha(ROOT/k)==v for k,v in before.items())
print(json.dumps(summary,ensure_ascii=False,indent=2))
