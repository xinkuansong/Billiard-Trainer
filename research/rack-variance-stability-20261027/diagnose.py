from pathlib import Path
import gzip, json, math, statistics as st
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/rack-variance-stability-20261027';OUT.mkdir(exist_ok=True,parents=True)
D=2*.028574999421834946
def write(n,x):(OUT/n).write_text(json.dumps(x,ensure_ascii=False,indent=2,allow_nan=False)+'\n')
def features(r):
    p=np.array([[b['x'],b['z']] for b in r['rack']]);s=np.array(r['slots'])
    gaps={(j,i):float(np.linalg.norm(p[i]-p[j])-D)*1e6 for i in range(15) for j in range(i) if np.linalg.norm(s[i]-s[j])<D+.001}
    f={f'gap_{a}_{b}':v for (a,b),v in gaps.items()}
    f.update({f'offset_{i}':float(np.linalg.norm(p[i]-s[i]))*1e6 for i in range(15)})
    for label,parent,node,outer,inner in [('entryPlus',0,1,3,4),('entryMinus',0,2,5,4),('branchPlus',1,3,6,7),('branchMinus',2,5,9,8),('rearPlus',3,7,11,12),('rearMinus',5,8,13,12)]:
        incoming=p[node]-p[parent];incoming/=np.linalg.norm(incoming)
        times=[]
        for target in [outer,inner]:
            dp=p[target]-p[node];dist=np.linalg.norm(dp);closing=float(incoming@(dp/dist))
            assert closing>0
            times.append((dist-D)*1e6/closing)
        f[label]=times[0]-times[1]
    f['branchMin']=min(f['branchPlus'],f['branchMinus']);f['branchMax']=max(f['branchPlus'],f['branchMinus'])
    return f
def metric(r):
    a=next(s for s in r['samples'] if round(s['delay']*1000)==5)
    by=dict(zip(r['names'],a['states']));v=[math.sqrt(sum(x*x for x in by[n]['v'])) for n in r['canonicalNames']]
    return dict(variance=st.pvariance(v),energy=.5*r['parameters']['ballMass']*sum(x*x for x in v),speeds=v)
def sequence(r):
    names={n:i for i,n in enumerate(r['canonicalNames'])};names['cueBall']=-1
    return [dict(pair=sorted([names[e['preA']['name']],names[e['preB']['name']]]),us=(e['t']-r['t0'])*1e6) for e in r['eventTrace'] if e['kind']=='ball' and e['t']-r['t0']<=.005]
def main():
    rows=[];by={};metrics={}
    with gzip.open(ROOT/'output/rack-front-core-20261027/raw.jsonl.gz','rt') as f:
        for line in f:
            r=json.loads(line);q=r['input']
            if q['condition']!='original' or q['cohort'] not in ['screen','confirmation','holdout']:continue
            m=dict(cohort=q['cohort'],id=q['rackID'],policy=q['policy'],**metric(r));rows.append(m)
            if q['cohort']=='holdout' and q['policy'] in ['parentB','exit_-30']:
                by[q['rackID'],q['policy']]=dict(features=features(r),sequence=sequence(r),metric=m,rack=r['rack'],slots=r['slots'])
    paired=[]
    for rid in range(80000,80200):
        b,c=[by[rid,p] for p in ['parentB','exit_-30']]
        bs,cs=b['sequence'],c['sequence'];i=next((i for i,(x,y) in enumerate(zip(bs,cs)) if x['pair']!=y['pair']),min(len(bs),len(cs)))
        item=dict(id=rid,delta=c['metric']['variance']-b['metric']['variance'],b=b['metric'],c=c['metric'],featuresB=b['features'],featuresC=c['features'],firstDivergence=i,Bnext=bs[i:i+6],Cnext=cs[i:i+6])
        for policy,row in [('B',b),('C',c)]:
            for label,node,outer,inner in [('plus',3,6,7),('minus',5,9,8)]:
                seq=row['sequence'];times={}
                for e in seq:times.setdefault(tuple(e['pair']),e['us'])
                ti=times.get(tuple(sorted([node,inner])));to=times.get(tuple(sorted([node,outer])))
                item[f'{policy}_{label}_timesUS']=dict(inner=ti,outer=to)
                item[f'{policy}_{label}_order']='missing' if ti is None or to is None else 'inner' if ti<to else 'outer' if to<ti else 'same-time'
                item[f'{policy}_{label}_innerFirst']=(ti if ti is not None else 1e9)<(to if to is not None else 1e9)
        paired.append(item)
    groups={}
    for r in rows:groups.setdefault((r['cohort'],r['policy']),[]).append(r)
    ranks={}
    for cohort in ['screen','confirmation']:
        base={r['id']:r for r in groups[cohort,'parentB']};rank=[]
        for (co,p),rs in groups.items():
            if co!=cohort:continue
            ds=[r['variance']-base[r['id']]['variance'] for r in rs]
            rank.append(dict(policy=p,n=len(rs),mean=st.mean(r['variance'] for r in rs),delta=st.mean(ds),wins=sum(x<-.01 for x in ds),losses=sum(x>.01 for x in ds),median=st.median(ds)))
        ranks[cohort]=sorted(rank,key=lambda x:x['delta'])
    # Univariate associations are exploratory; no model selection on future samples.
    stats=[];y=np.array([p['delta'] for p in paired])
    for k in paired[0]['featuresB']:
        for mode in ['B','C','change']:
            x=np.array([p['featuresB'][k] if mode=='B' else p['featuresC'][k] if mode=='C' else p['featuresC'][k]-p['featuresB'][k] for p in paired])
            if np.std(x)<1e-10:continue
            stats.append(dict(feature=k,mode=mode,corr=float(np.corrcoef(x,y)[0,1])))
    write('diagnostic-pairs.json',paired);write('existing-metrics.json',rows);write('existing-rankings.json',ranks);write('feature-correlations.json',sorted(stats,key=lambda x:-abs(x['corr'])))
    print('screen',ranks['screen'][:8]);print('confirmation',ranks['confirmation']);print('features',sorted(stats,key=lambda x:-abs(x['corr']))[:15])
    for label,predicate in [('improved',lambda p:p['delta']<-.01),('worse',lambda p:p['delta']>.01),('near',lambda p:abs(p['delta'])<=.01)]:
        ps=[p for p in paired if predicate(p)];print(label,len(ps),'mean',st.mean(p['delta'] for p in ps))
        for side in ['plus','minus']:
            print(side, {f'{a}->{b}':sum(p[f'B_{side}_innerFirst']==a and p[f'C_{side}_innerFirst']==b for p in ps) for a in [False,True] for b in [False,True]})
    for p in sorted(paired,key=lambda x:x['delta'])[:2]+sorted(paired,key=lambda x:-x['delta'])[:2]:print('case',p['id'],p['delta'],p['firstDivergence'],p['Bnext'],p['Cnext'])
if __name__=='__main__':main()
