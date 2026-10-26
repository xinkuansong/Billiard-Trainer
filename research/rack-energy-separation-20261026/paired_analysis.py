"""Audit full paired input geometry and compare continuous outcomes by rack."""
import json,gzip,math,hashlib,sys
import numpy as np
from analyze import ROOT,OUT,R,L,W,INS,PRIMARY,extract,stats,write,corr,ranks

MODE='control' if '--control' in sys.argv else 'paired'
PAIRED=OUT/MODE

def interval(d,comparisons=2):
    d=np.asarray(d);rng=np.random.default_rng(202610261230);samples=[]
    for _ in range(100):samples.extend(d[rng.integers(len(d),size=(200,len(d)))].mean(1).tolist())
    return dict(mean=float(d.mean()),ci95=np.quantile(samples,[.025,.975]).tolist(),family95=np.quantile(samples,[.05/(2*comparisons),1-.05/(2*comparisons)]).tolist())

def main():
    raw={};rows={};sources=[]
    for p in sorted(PAIRED.glob('raw-*.jsonl.gz')):
        sources.append(dict(path=str(p.relative_to(ROOT)),sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
        with gzip.open(p,'rt') as f:
            for line in f:
                r=json.loads(line);key=(r['input']['rackID'],r['input']['variant'])
                assert key not in raw;raw[key]=r
    assert len(raw)==3000
    status={s:sum(r['status']==s for r in raw.values()) for s in set(r['status'] for r in raw.values())}
    (PAIRED/'statuses.json').write_text(json.dumps(status,indent=2))
    assert status=={'settled':3000},'Incomplete results retained; analysis protocol must be revised explicitly.'
    for k,r in raw.items():rows[k]=extract(r)
    ids=sorted({k[0] for k in raw});assert ids==list(range(2200,3200))
    protocol=json.loads((PAIRED/'protocol.json').read_text())
    assert {(r['rackID'],r['seed']) for r in protocol['racks']}=={(i,raw[i,'baseline']['input']['seed']) for i in ids}
    s=np.float32(np.float32(R)*2+np.float32(.0002));step=np.float32(np.float32(s*np.sqrt(np.float32(3)))/2)
    nom=np.array([[np.float32(-np.float32(L)/4-np.float32(rr)*step),np.float32((np.float32(rr)/2-np.float32(c))*s)] for rr in range(5) for c in range(rr+1)],dtype=float)
    rowids=np.array([rr for rr in range(5) for c in range(rr+1)])
    edges=[(i,j) for i in range(15) for j in range(i+1,15) if abs(math.dist(nom[i],nom[j])-s)<1e-6]
    assert len(edges)==30
    bounds=[];offsets=[];static={};zero=False
    for i in ids:
        base=raw[i,'baseline'];bp=np.array([[b['x'],b['z']] for b in base['rack']])
        for v in protocol['variants']:
            r=raw[i,v];p=np.array([[b['x'],b['z']] for b in r['rack']])
            assert [b['number'] for b in base['rack']]==[b['number'] for b in r['rack']]
            for f in ['cue','direction','power','spin','accessElevation','simulatedElevation']:assert r[f]==base[f]
            assert np.array_equal(p[:,1],bp[:,1])
            assert np.array_equal(p[[j for j in range(15) if j not in INS]],bp[[j for j in range(15) if j not in INS]])
            offsets.extend(np.linalg.norm(p-nom,axis=1))
            bounds.extend((math.dist(p[a],p[b])-2*R)*1000 for a,b in edges)
            if v!='baseline':
                sign=1 if v=='toward' else -1
                target=nom[INS,0]+sign*np.abs(bp[INS,0]-nom[INS,0])
                assert np.max(np.abs(p[INS,0]-target))<1e-7
            inc=[];out=[]
            for ball in INS:
                for a,b in edges:
                    if ball not in (a,b):continue
                    other=b if a==ball else a
                    if rowids[other]<rowids[ball]:inc.append((math.dist(p[a],p[b])-2*R)*1000)
                    if rowids[other]>rowids[ball]:out.append((math.dist(p[a],p[b])-2*R)*1000)
            static[i,v]=dict(incomingGapMM=float(np.mean(inc)),outgoingGapMM=float(np.mean(out)))
            rows[i,v]['initialGeometry']=static[i,v]
        # Three balls move together, so aggregate incoming/outgoing gaps are not
        # assumed monotone; each C2-D2/D3 edge is shared by the internal group.
    assert min(bounds)>=.02-.0003 and max(bounds)<=.38+.0003
    assert max(offsets)<=.00009+1e-7
    result=dict(status=status,sources=sources,cohorts={},thresholdComparisons={},audit=dict(total=3000,uniqueSeeds=len({raw[i,'baseline']['input']['seed'] for i in ids}),gapMinMM=min(bounds),gapMaxMM=max(bounds),maxOffsetMM=max(offsets)*1000,unchangedNonInternalBalls=True,unchangedCueAimPowerSpin=True,identicalBallNumbers=True))
    for name,subset in [('first500',ids[:500]),('second500',ids[500:]),('all1000',ids)]:
        bas=[rows[i,'baseline'] for i in subset];result['cohorts'][name]={}
        for v in protocol['variants']:
            rr=[rows[i,v] for i in subset];d=[a['score']-b['score'] for a,b in zip(rr,bas)]
            m={n:float(np.mean([r['features']['5'][n] for r in rr])) for n in rr[0]['features']['5']}
            result['cohorts'][name][v]=dict(**stats(rr),scoreDelta=interval(d),relativeMeanChange=float(np.mean(d)/np.mean([r['score'] for r in bas])),better=sum(x>1e-12 for x in d),worse=sum(x< -1e-12 for x in d),same=sum(abs(x)<=1e-12 for x in d),initialGeometry={n:float(np.mean([static[i,v][n] for i in subset])) for n in static[subset[0],v]},mechanisms=m,mechanismDelta={n:interval([r['features']['5'][n]-b['features']['5'][n] for r,b in zip(rr,bas)],8) for n in PRIMARY},wallDelta=interval([r['wallMS']-b['wallMS'] for r,b in zip(rr,bas)]),cpuMeanMS=float(np.mean([r['cpuMS'] for r in rr])),deltaCorrelation={n:corr([r['features']['5'][n]-b['features']['5'][n] for r,b in zip(rr,bas)],d) for n in PRIMARY} if v!='baseline' else {})
    # Previously fixed observational thresholds, independently applied to fresh baselines.
    from analyze import boot
    old=json.loads((OUT/'analysis.json').read_text())
    bas=[rows[i,'baseline'] for i in ids]
    for n,(lo,hi) in old['thresholds'].items():
        low=[r for r in bas if r['features']['5'][n]<=lo];high=[r for r in bas if r['features']['5'][n]>hi]
        if not low or not high:
            result['thresholdComparisons'][n]=dict(notEstimable=True,reason='Production-derived thresholds leave an empty group in this model; no threshold retuning.',lowCount=len(low),highCount=len(high))
            continue
        result['thresholdComparisons'][n]=dict(low=stats(low),high=stats(high),delta=stats(high)['mean']-stats(low)['mean'],**boot([r['score'] for r in high],[r['score'] for r in low]))
    binding=json.loads((PAIRED/'source-binding.json').read_text())
    result['audit']['sourceDrift']=[x['path'] for x in binding['production'] if hashlib.sha256((ROOT/x['path']).read_bytes()).hexdigest()!=x['sha256']]
    assert not result['audit']['sourceDrift']
    write(MODE+'-analysis.json',result)
    write(MODE+'-rows.json',[dict(**r,variant=v) for (i,v),r in sorted(rows.items())])
    for v,r in result['cohorts']['all1000'].items():print(v,'score',r['mean'],'delta',r['scoreDelta'],'features',r['mechanisms'],flush=True)

if __name__=='__main__':main()
