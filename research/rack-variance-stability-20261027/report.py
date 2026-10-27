from pathlib import Path
import json, math, statistics as st, hashlib
import numpy as np

ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-variance-stability-20261027'
def write(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=2,allow_nan=False)+'\n')
def wilson(k,n):
    z=1.959963984540054;p=k/n;d=1+z*z/n
    c=(p+z*z/(2*n))/d;h=z*math.sqrt(p*(1-p)/n+z*z/(4*n*n))/d
    return [c-h,c+h]
def analyze(folder):
    rows=json.loads((folder/'scalars.json').read_text());a=[r for r in rows if r['cohort']=='holdout' and r['condition']=='original']
    selected=json.loads((folder/'selection.json').read_text())['selected']
    if (folder/'gated-rows.json').exists():
        a+=json.loads((folder/'gated-rows.json').read_text());selected=selected+['geometry_gated_C']
    groups={p:sorted([r for r in a if r['policy']==p],key=lambda r:r['id']) for p in selected}
    assert all(len(a)==200 for a in groups.values())
    keys=['variance5','variance20','variance100','energy5','energy20','energy100','innerFirstSides','active5','slow5','maxSpeed5','cornerShare5','nearestGap','crowded','finalN','tail','scratch','cpuMS']
    summary={p:{k:st.mean(r[k] for r in rs) for k in keys} for p,rs in groups.items()}
    rng=np.random.default_rng(2026102719);idx=rng.integers(0,200,(5000,200));paired={}
    for new,base in [('C','B')]+[(p,b) for p in selected[2:] for b in ['B','C']]:
        aa,bb=groups[new],groups[base];assert [r['id'] for r in aa]==[r['id'] for r in bb]
        delta=np.array([[x[k]-y[k] for k in keys] for x,y in zip(aa,bb)]);ci=np.quantile(delta[idx].mean(axis=1),[.025,.975],axis=0)
        stats={k:dict(mean=float(delta[:,i].mean()),ci95=ci[:,i].tolist()) for i,k in enumerate(keys)}
        d=delta[:,0];wins=int(sum(d<0));mw=int(sum(d<-.01));ml=int(sum(d>.01));median=float(np.median(d))
        stats['stability']=dict(strictWins=wins,strictWinFractionCI95=wilson(wins,200),meaningfulWins=mw,meaningfulLosses=ml,nearEqual=200-mw-ml,meaningfulWinFractionCI95=wilson(mw,200),median=median,medianCI95=np.quantile(np.median(d[idx],axis=1),[.025,.975]).tolist(),worseOver10Percent=sum(x['variance5']>1.1*y['variance5'] for x,y in zip(aa,bb)))
        paired[f'{new}-{base}']=stats
    audit=dict(runs=len(rows),settled=len(rows),contacts=sum(r['contacts'] for r in rows),nonApproaching=sum(r['nonApproaching'] for r in rows),gapOutsideBudget=sum(r['gapOutsideBudget'] for r in rows),energyGain=sum(r['energyGain'] for r in rows),maxOverlap=max(r['maxOverlap'] for r in rows),maxMomentumResidual=max(r['maxMomentumResidual'] for r in rows))
    assert audit['nonApproaching']==audit['gapOutsideBudget']==audit['energyGain']==0
    write(folder/'summary-variance.json',summary);write(folder/'paired-variance.json',paired);write(folder/'audit-variance.json',audit)
    return dict(selected=selected,summary=summary,paired=paired,audit=audit)
def main():
    results={}
    for name,folder in [('local',OUT),('global',OUT/'stage2')]:
        if (folder/'closure.json').exists() and json.loads((folder/'closure.json').read_text())['success']:results[name]=analyze(folder)
    write(OUT/'results.json',results)
    for name,r in results.items():
        print(name,r['selected'])
        for p,s in r['summary'].items():print(p,{k:round(s[k],6) for k in ['variance5','energy5','innerFirstSides','nearestGap','crowded','tail','scratch']})
        for pair,s in r['paired'].items():print(pair,'variance',s['variance5'],'stability',s['stability'])
if __name__=='__main__':main()
