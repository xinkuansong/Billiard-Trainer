from pathlib import Path
import json,gzip,math,statistics as st,hashlib
import numpy as np

ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-variance-minimize-20261027'
M=.17000000178813934
def write(n,x):(OUT/n).write_text(json.dumps(x,ensure_ascii=False,indent=2,allow_nan=False)+'\n')
def wilson(k,n):
    z=1.959963984540054;p=k/n;den=1+z*z/n
    c=(p+z*z/2/n)/den;h=z*math.sqrt(p*(1-p)/n+z*z/4/n/n)/den
    return [c-h,c+h]
def sha(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
    return h.hexdigest()
def main():
    closure=json.loads((OUT/'closure.json').read_text());assert closure['success'] and closure['workerExit']==closure['shutdownExit']==0
    rows=json.loads((OUT/'scalars.json').read_text());selected=json.loads((OUT/'holdout-selection.json').read_text())['selected']
    groups={p:sorted([r for r in rows if r['cohort']=='holdout' and r['condition']=='original' and r['policy']==p],key=lambda r:r['id']) for p in selected}
    assert all(len(a)==300 for a in groups.values())
    keys=['variance5','variance20','variance100','energy5','energy20','energy100','maxSpeed5','cornerShare5','nEff5','active5','slow5','nearestGap','crowded','finalN','tail','scratch','cpuMS']
    summary={}
    for p,a in groups.items():
        summary[p]={k:st.mean(r[k] for r in a) for k in keys}
        summary[p].update(n=len(a),varianceMedian=st.median(r['variance5'] for r in a),varianceP90=float(np.quantile([r['variance5'] for r in a],.9)),worstQuartileVariance=st.mean(sorted(r['variance5'] for r in a)[-75:]),tailP95=float(np.quantile([r['tail'] for r in a],.95)),tailOver5=sum(r['tail']>5 for r in a))
    idx=np.random.default_rng(2026102729).integers(0,300,(5000,300));paired={}
    comparisons=[('E','B')]+[(p,b) for p in selected if p not in ['B','E'] for b in ['B','E']]
    for new,base in comparisons:
        a,b=groups[new],groups[base];assert [r['id'] for r in a]==[r['id'] for r in b]
        delta=np.array([[x[k]-y[k] for k in keys] for x,y in zip(a,b)]);ci=np.quantile(delta[idx].mean(axis=1),[.025,.975],axis=0)
        d=delta[:,0]
        stats={k:dict(mean=float(delta[:,i].mean()),ci95=ci[:,i].tolist()) for i,k in enumerate(keys)}
        stats['stability']=dict(strictWins=int(sum(d<0)),meaningfulWins=int(sum(d<-.01)),meaningfulLosses=int(sum(d>.01)),nearEqual=int(sum(abs(d)<=.01)),strictWinFractionCI95=wilson(int(sum(d<0)),300),meaningfulWinFractionCI95=wilson(int(sum(d<-.01)),300),median=float(np.median(d)),medianCI95=np.quantile(np.median(d[idx],axis=1),[.025,.975]).tolist(),worseOver10Percent=sum(x['variance5']>1.1*y['variance5'] for x,y in zip(a,b)))
        paired[f'{new}-{base}']=stats
    # Independent checks and mechanism extraction from saved native snapshots.
    per_slot={p:[] for p in selected};routes={p:[] for p in selected};margins={p:[] for p in selected};rack_mechanism={p:{} for p in selected};examples={};rawcount=0;params=None;cue={};maxerr=0.;contacts=0
    for line in gzip.open(OUT/'raw.jsonl.gz','rt'):
        r=json.loads(line);q=r['input'];rawcount+=1;assert r['status']=='settled'
        if params is None:params=r['parameters']
        assert params==r['parameters']
        if q['cohort']!='holdout' or q['condition']!='original':continue
        assert cue.setdefault(q['rackID'],r['initialCueVelocity'])==r['initialCueVelocity']
        sm=next(x for x in r['samples'] if round(x['delay']*1000)==5);by=dict(zip(r['names'],sm['states']));v=[math.sqrt(sum(t*t for t in by[n]['v'])) for n in r['canonicalNames']]
        assert all(by[n]['state']!='pocketed' for n in r['canonicalNames'])
        saved=next(x for x in groups[q['policy']] if x['id']==q['rackID']);assert abs(float(np.var(v))-saved['variance5'])<1e-10
        per_slot[q['policy']].append(v)
        xy=np.array([[b['x'],b['z']] for b in r['rack']]);pair_margins=[]
        for upstream,node,outer,inner in [(3,6,10,11),(5,9,14,13)]:
            u=xy[node]-xy[upstream];u/=np.linalg.norm(u);travel=[]
            for target in [outer,inner]:
                dp=xy[target]-xy[node];dist=np.linalg.norm(dp)
                travel.append((dist-2*params['ballRadius'])/float(u@(dp/dist)))
            pair_margins.append((travel[0]-travel[1])*1e6)
        margins[q['policy']].append(pair_margins)
        first={};ni={n:i for i,n in enumerate(r['canonicalNames'])}
        for ev in r['eventTrace']:
            if ev['kind']!='ball' or ev['t']-r['t0']>.005:continue
            for side,other in [('A','B'),('B','A')]:
                a,b=ni.get(ev['pre'+side]['name'],-1),ni.get(ev['pre'+other]['name'],-1)
                if a not in [6,9] or b not in [10,11,13,14]:continue
                loss=sum(x*x for x in ev['pre'+side]['v'])-sum(x*x for x in ev['post'+side]['v'])
                if loss>1e-5:first.setdefault(a,b)
        routes[q['policy']].append(first)
        rack_mechanism[q['policy']][q['rackID']]=dict(first=first,initialMarginsUM=pair_margins,variance5=saved['variance5'])
        if q['rackID']==102000:examples[q['policy']]=dict(rack=r['rack'],slots=r['slots'],input=q,speeds=v)
    for r in rows:
        assert r['nonApproaching']==r['gapOutsideBudget']==r['energyGain']==0;contacts+=r['contacts']
        for ms in [5,20,100]:
            err=abs(r[f'variance{ms}']+r[f'allMeanSpeed{ms}']**2-2*r[f'energy{ms}']/(15*M));assert err<1e-10;maxerr=max(maxerr,err)
    assert rawcount==len(rows)==closure['runs']
    freeze=json.loads((OUT/'engine-freeze.json').read_text());assert all(sha(ROOT/'research/rack-front-core-20261027'/p)==h for p,h in freeze.items())
    binding=json.loads((OUT/'source-binding.json').read_text());assert all(sha(ROOT/r['path'])==r['sha256'] for r in binding['production'])
    sources=json.loads((OUT/'research-source-before.json').read_text());assert all(sha(ROOT/p)==h for p,h in sources.items())
    write('summary.json',summary);write('paired.json',paired);write('example-layout.json',examples)
    mechanism={p:dict(slotMeanSpeeds=np.mean(per_slot[p],axis=0).tolist(),slotMeanEnergy=(.5*M*np.mean(np.array(per_slot[p])**2,axis=0)).tolist(),
        rearInnerFirstPlus=sum(r.get(6)==11 for r in routes[p]),rearInnerFirstMinus=sum(r.get(9)==13 for r in routes[p]),
        meanInitialMarginUM=np.mean(margins[p],axis=0).tolist(),initialPositiveMarginCounts=np.sum(np.array(margins[p])>0,axis=0).tolist(),
        initialAtLeast50UMCounts=np.sum(np.array(margins[p])>=50,axis=0).tolist()) for p in selected}
    write('mechanism.json',mechanism)
    mechanisms_paired={}
    for p in selected:
        if p in ['B','E']:continue
        cases=[]
        for rid,r in rack_mechanism[p].items():
            b=rack_mechanism['E'][rid]
            number=lambda x:sum(x['first'].get(i)==j for i,j in [(6,11),(9,13)])
            cases.append(dict(id=rid,delta=r['variance5']-b['variance5'],E=b,candidate=r,innerFirstSidesChange=number(r)-number(b)))
        grouped=[]
        for change in [-2,-1,0,1,2]:
            a=[r for r in cases if r['innerFirstSidesChange']==change]
            if a:grouped.append(dict(change=change,n=len(a),meanDelta=st.mean(r['delta'] for r in a),meaningfulWins=sum(r['delta']<-.01 for r in a),meaningfulLosses=sum(r['delta']>.01 for r in a)))
        mechanisms_paired[p]=dict(groups=grouped,cases=sorted(cases,key=lambda r:r['delta']))
    write('mechanism-paired.json',mechanisms_paired)
    inv=json.loads((OUT/'invariance.json').read_text());assert len(inv)==15 and max(r['maxBoardErrorM'] for r in inv)<=1e-6
    seeds=[json.loads(s)['input']['seed'] for s in gzip.open(OUT/'layouts.jsonl.gz','rt')];assert len(seeds)==len(set(seeds))==closure['layoutOnlyRequests']
    old=set()
    for name in ['rack-front-core-20261027','rack-variance-stability-20261027','rack-variance-stability-20261027/stage2']:
        old.update(json.loads(s)['input']['seed'] for s in gzip.open(ROOT/'output'/name/'layouts.jsonl.gz','rt'))
    assert not set(seeds)&old
    write('verification.json',dict(nativeRuns=rawcount,layoutOnlyRequests=len(seeds),allSettled=True,pairedSeeds=len(cue),auditedBallResponses=contacts,
        invalidResponses=0,outsideEnvelopeResponses=0,energyGainOver1MicrojouleResponses=0,varianceEnergyIdentityChecks=3*len(rows),maxIdentityError=maxerr,
        oldReplays=len(json.loads((OUT/'replay.json').read_text())),invarianceRuns=len(inv),physicsSourceBindings=len(binding['production']),parameters=params,
        productionChangesDuringRun=json.loads((OUT/'source-review.json').read_text())['productionChangesDuringRun'],
        sourceSHA={str(p.relative_to(ROOT)):sha(p) for p in Path(__file__).parent.glob('*.py')},rawSHA=sha(OUT/'raw.jsonl.gz')))
    print(json.dumps(summary,indent=2));print(json.dumps(paired,indent=2))
if __name__=='__main__':main()
