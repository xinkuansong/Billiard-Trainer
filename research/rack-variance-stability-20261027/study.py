from pathlib import Path
import importlib.util, math, statistics as st
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
def load(name,path):
    s=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
front=load('front_stability',ROOT/'research/rack-front-core-20261027/study.py')
R,F,L,seed=front.R,front.F,front.L,front.seed
POLICIES=['B','C','inner_only','branch_0','branch_05','branch_1','branch_2']

def positions(generated,policy):
    b=front.positions(generated,front.definitions()['parentB'])
    if policy=='B':return b
    c=front.positions(generated,front.definitions()['exit_-30'])
    if policy=='C':return c
    slots=np.array(generated['slots']);original=np.array([[b['x'],b['z']] for b in generated['rack']])
    mag=np.linalg.norm(original-slots,axis=1);p=np.array(c)
    weight={'inner_only':1.,'branch_0':0.,'branch_05':.5,'branch_1':1.,'branch_2':2.}[policy]
    # All candidates use geometry alone. No simulated velocity is consulted.
    for parent,node,outer,inner in [(1,3,6,7),(2,5,9,8)]:
        sign=1 if slots[node,1]>0 else -1
        angles=np.arange(72)*math.pi/36*sign
        coords={i:np.array([[F(slots[i,0]+mag[i]*math.cos(t)),F(slots[i,1]+mag[i]*math.sin(t))] for t in angles]) for i in [node,outer,inner]}
        def score(a):
            incoming=a[node]-a[parent];incoming/=np.linalg.norm(incoming)
            d_outer=a[outer]-a[node];d_inner=a[inner]-a[node]
            ro=np.linalg.norm(d_outer);ri=np.linalg.norm(d_inner)
            outer_time=(ro-2*R)/float(incoming@(d_outer/ro))
            inner_time=(ri-2*R)/float(incoming@(d_inner/ri))
            front_gap=np.linalg.norm(a[inner]-a[4])-2*R
            return outer_time-inner_time+weight*(front_gap-(ri-2*R))
        for _ in range(3):
            for i in ([inner] if policy=='inner_only' else [node,outer,inner]):
                best=score(p);bestp=p[i].copy()
                for q in coords[i]:
                    p[i]=q;value=score(p)
                    if value>best+1e-14:best=value;bestp=q.copy()
                p[i]=bestp
    ans=p.tolist()
    assert ans[0]==b[0]
    for i in range(15):
        assert abs(math.dist(slots[i],ans[i])-mag[i])<1e-7
        assert math.dist(slots[i],ans[i])<.00009015
        for j in range(i):assert math.dist(ans[i],ans[j])-2*R>.0000195
        if i not in [3,5,6,7,8,9]:assert ans[i]==b[i]
    return ans

def metrics(row):
    r=front.metrics(row)
    for sm in row['samples']:
        ms=round(sm['delay']*1000);by=dict(zip(row['names'],sm['states']))
        v=[math.sqrt(sum(x*x for x in by[n]['v'])) for n in row['canonicalNames']]
        r[f'variance{ms}']=st.pvariance(v)
    pts=[[v*L for v in p] for n,p in row['board'].items() if n!='cueBall']
    gaps=[min(math.dist(p,q)-2*R for j,q in enumerate(pts) if i!=j) for i,p in enumerate(pts)]
    r['nearestGap']=st.mean(gaps);r['crowded']=sum(g<2*R for g in gaps);r['finalN']=len(pts)
    byname={n:i for i,n in enumerate(row['canonicalNames'])};times={}
    for e in row['eventTrace']:
        if e['kind']!='ball' or e['t']-row['t0']>.005:continue
        a,b=e['preA']['name'],e['preB']['name']
        if a not in byname or b not in byname:continue
        times.setdefault(tuple(sorted([byname[a],byname[b]])),e['t'])
    r['innerFirstSides']=sum(times.get(tuple(sorted([node,inner])),1e9)<times.get(tuple(sorted([node,outer])),1e9) for node,outer,inner in [(3,6,7),(5,9,8)])
    return r
