"""Retrospective, continuous-outcome analysis; never changes production inputs."""
from pathlib import Path
import json, gzip, math, hashlib
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/rack-energy-separation-20261026'
OLD=ROOT/'output/rack-center-mechanism-20261026'
CAL=json.loads((OLD/'calibration.json').read_text())
META=json.loads((OLD/'metadata.json').read_text())
L,W,R=[META[k] for k in ['length','width','radius']]
INS=[4,7,8]
PRIMARY=['effectiveBalls','interiorEnergyFraction','interiorMinOpening','interiorMinGap']

def write(name,obj):
    (OUT/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2,allow_nan=False))

def extract(r):
    assert r['status']=='settled'
    q=np.array([[v[0]*L-L/2,v[1]*L-W/2] for k,v in r['board'].items() if k!='cueBall'])
    d=np.linalg.norm(q[:,None]-q[None,:],axis=2);np.fill_diagonal(d,np.inf)
    score=float(d.min(1).mean()/CAL['reference'][str(len(q))]['expectedMeanM'])
    scalar=sum(min(math.dist(p,q[j]) for j in range(len(q)) if i!=j) for i,p in enumerate(q))/len(q)/CAL['reference'][str(len(q))]['expectedMeanM']
    assert abs(score-scalar)<1e-12
    energy0=sum(.085*np.dot(c['preV'],c['preV']) for c in r['impulseTrace'][0]['changed'])
    row=dict(id=r['input']['rackID'],seed=r['input']['seed'],score=score,remaining=len(q),wallMS=r['seconds']*1000,cpuMS=r['cpuSeconds']*1000,features={})
    for sample in r['samples']:
        ms=round(sample['delay']*1000)
        if ms not in [1,5,20]:continue
        assert all(s['state']!='pocketed' for s in sample['states'])
        p=np.array([s['p'] for s in sample['states'][1:]])[:,[0,2]]
        v=np.array([s['v'] for s in sample['states'][1:]])[:,[0,2]]
        energies=.085*(v*v).sum(1)
        dist=np.linalg.norm(p[:,None]-p[None,:],axis=2);np.fill_diagonal(dist,np.inf)
        near=dist.argmin(1);gap=dist.min(1)-2*R
        opening=((v[near]-v)*(p[near]-p)).sum(1)/dist.min(1)
        ecom=.085*((v-v.mean(0))**2).sum()
        f=dict(effectiveBalls=float(energies.sum()**2/np.dot(energies,energies)),
               interiorEnergyFraction=float(energies[INS].sum()/energy0),
               interiorMinOpening=float(opening[INS].min()),
               interiorMinGap=float(gap[INS].min()*1000),
               interiorMeanOpening=float(opening[INS].mean()),
               interiorEnergyShare=float(energies[INS].sum()/energies.sum()),
               relativeEnergyFraction=float(ecom/energy0),
               objectEnergyFraction=float(energies.sum()/energy0),
               weakestInternalEnergy=float(energies[INS].min()/energy0),
               allInternalSeparating=int(np.all(opening[INS]>0)),
               cornerShare=float(energies[[10,14]].sum()/energies.sum()))
        # Independent scalar vector/distance audit for the primary local quantities.
        for i in INS:
            j=min((j for j in range(15) if j!=i),key=lambda j:math.dist(p[i],p[j]))
            dd=math.dist(p[i],p[j]);oo=sum((v[j,k]-v[i,k])*(p[j,k]-p[i,k]) for k in range(2))/dd
            assert abs(dd-dist[i,near[i]])<1e-12 and abs(oo-opening[i])<1e-12
        assert 1-1e-12<=f['effectiveBalls']<=15+1e-12
        assert math.isclose(energies.sum(),ecom+.085*15*np.dot(v.mean(0),v.mean(0)),abs_tol=1e-10)
        row['features'][str(ms)]=f
    row['sustainedGap']=min(row['features']['5']['interiorMinGap'],row['features']['20']['interiorMinGap'])
    row['allSeparatingBoth']=int(all(row['features'][t]['allInternalSeparating'] for t in ['5','20']))
    return row

def ranks(x):
    _,inv,cnt=np.unique(x,return_inverse=True,return_counts=True)
    return (np.cumsum(cnt)-(cnt-1)/2)[inv]

def corr(x,y):
    return float(np.corrcoef(x,y)[0,1]) if np.std(x)>0 else None

def boot(a,b):
    rng=np.random.default_rng(202610261211);a=np.array(a);b=np.array(b);ds=[]
    for _ in range(100):
        ds.extend((a[rng.integers(len(a),size=(200,len(a)))].mean(1)-b[rng.integers(len(b),size=(200,len(b)))].mean(1)).tolist())
    return dict(ci95=np.quantile(ds,[.025,.975]).tolist(),family95=np.quantile(ds,[.05/8,1-.05/8]).tolist())

def stats(rows):
    y=np.array([r['score'] for r in rows])
    return dict(n=len(rows),mean=float(y.mean()),median=float(np.median(y)),sd=float(y.std(ddof=1)),passRate=float((y>=1.2).mean()),wallMeanMS=float(np.mean([r['wallMS'] for r in rows])),wallP95MS=float(np.quantile([r['wallMS'] for r in rows],.95)))

def main():
    rows=[];sources=[]
    for directory in [OLD,ROOT/'output/rack-contact-factorial-20261026']:
        for path in sorted(directory.glob('raw-*.jsonl.gz')):
            sources.append(dict(path=str(path.relative_to(ROOT)),sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
            with gzip.open(path,'rt') as f:
                for line in f:
                    r=json.loads(line)
                    if directory!=OLD and not (r['input']['contactEpsilon']==.00025 and r['input']['tieEpsilon']==1e-7 and not r['input']['reverseRegistration']):continue
                    rows.append(extract(r))
    rows.sort(key=lambda r:r['id']);assert len(rows)==len({r['seed'] for r in rows})==2200
    write('rows.json',rows)
    groups={'first1000':rows[:1000],'second1000':rows[1000:2000],'later200':rows[2000:]}
    cuts={n:np.quantile([r['features']['5'][n] for r in rows[:1000]],[.2,.8]).tolist() for n in PRIMARY}
    results={}
    for group,data in groups.items():
        rr={}
        for name in PRIMARY:
            lo,hi=cuts[name];low=[r for r in data if r['features']['5'][name]<=lo];high=[r for r in data if r['features']['5'][name]>hi]
            x=[r['features']['5'][name] for r in data];y=[r['score'] for r in data]
            rr[name]=dict(low=stats(low),high=stats(high),delta=stats(high)['mean']-stats(low)['mean'],pearson=corr(x,y),spearman=corr(ranks(x),ranks(y)),**boot([r['score'] for r in high],[r['score'] for r in low]))
        results[group]=rr
    sensitivities={}
    for group,data in groups.items():
        sensitivities[group]={t:{n:dict(pearson=corr([r['features'][t][n] for r in data],[r['score'] for r in data]),spearman=corr(ranks([r['features'][t][n] for r in data]),ranks([r['score'] for r in data]))) for n in data[0]['features'][t]} for t in ['1','5','20']}
    result=dict(baseline={k:stats(v) for k,v in groups.items()},all=stats(rows),thresholds=cuts,primary=results,sensitivity=sensitivities,sources=sources)
    write('analysis.json',result)
    for group,rs in results.items():
        print(group,flush=True)
        for n,v in rs.items():print(n,'low/high/delta',*[round(v[k]['mean'],4) for k in ['low','high']],round(v['delta'],4),'CI',np.round(v['family95'],4),'rho',round(v['spearman'],3),flush=True)

if __name__=='__main__':main()
