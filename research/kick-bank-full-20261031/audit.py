"""Full-sweep audit, indexed exact-compatible dedup, compact App export.
Run with the managed runtime's numpy Python after generation-complete.json exists.
"""
from pathlib import Path
import collections, copy, gzip, hashlib, importlib.util, json, math, sys, time
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/kick-bank-full-20261031'
spec=importlib.util.spec_from_file_location('original',ROOT/'research/kick-grid-filtered-20261030/dedup.py')
original=importlib.util.module_from_spec(spec);spec.loader.exec_module(original)
def read(p):
    return json.loads(gzip.decompress(p.read_bytes()) if p.suffix=='.gz' else p.read_bytes())
def dump(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def points(r):return np.asarray([p[1:] for p in r['cueTrack']],dtype=np.float64)
def directed_close(a,b,limit):
    samples=np.asarray(original.densify(a.tolist()))
    x=b[:-1];d=b[1:]-x;length=(d*d).sum(axis=1)
    for start in range(0,len(samples),64):
        delta=samples[start:start+64,None,:]-x
        t=np.clip((delta*d).sum(axis=2)/np.where(length==0,1,length),0,1)
        ds=((delta-t[:,:,None]*d)**2).sum(axis=2)
        if np.any(np.sqrt(ds.min(axis=1))>limit):return False
    return True
def same(a,b,diameter):
    if a['n']!=b['n'] or a['walls']!=b['walls']:return False
    if math.dist(a['seed']['cue'],b['seed']['cue'])>diameter or math.dist(a['target'],b['target'])>diameter:return False
    aa=points(a);bb=points(b)
    return directed_close(aa,bb,diameter-.005) and directed_close(bb,aa,diameter-.005)
def key(r,diameter):
    x,z=r['seed']['cue']
    return (r['n'],tuple(r['walls']),math.floor(x/diameter),math.floor(z/diameter))
def neighbors(r,index,diameter):
    n,w,x,z=key(r,diameter)
    return sorted(i for dx in (-1,0,1) for dz in (-1,0,1) for i in index.get((n,w,x+dx,z+dz),[]))
def reduce(rows,diameter):
    kept=[];merged=[];index=collections.defaultdict(list);comparisons=0
    for count,row in enumerate(sorted(rows,key=original.rank)):
        for i in neighbors(row,index,diameter):
            comparisons+=1
            if same(row,kept[i],diameter):
                merged.append({'removed':row['id'],'representative':kept[i]['id']});break
        else:
            index[key(row,diameter)].append(len(kept));kept.append(row)
        if count and count%5000==0:print('DEDUP',count,len(kept),flush=True)
    return kept,merged,comparisons

def selftest():
    original.selftest()
    old=read(ROOT/'output/kick-grid-filtered-20261030/accepted.json')
    base=dict(id='a',n=1,walls=[0],seed={'cue':[0,0],'v':2},target=[1,0],cueTrack=[[0,0,0],[1,.5,.5],[2,1,0]],offsetR=.1)
    synthetic=[]
    # Includes neighboring bucket boundaries, non-transitive chains, different
    # paths with identical endpoints, changed walls and distant endpoints.
    for i,shift in enumerate([0,.04,.08,-.04,.05715,.057150001,-.05715]):
        r=copy.deepcopy(base);r['id']=f's{i}';r['seed']['cue'][1]+=shift;r['target'][1]+=shift
        for p in r['cueTrack']:p[2]+=shift
        synthetic.append(r)
    for i in range(3):
        r=copy.deepcopy(base);r['id']=f'd{i}'
        if i==0:r['cueTrack'][1][2]=-.5
        elif i==1:r['walls']=[1]
        else:r['target'][0]+=.06
        synthetic.append(r)
    for a in synthetic:
        for b in synthetic:assert same(a,b,.05715)==original.same_question(a,b,.05715)
    for rows in [synthetic,synthetic[::-1],old]:
        a,b,_=reduce(rows,.05715);x,y,_=original.reduce_rows(rows,.05715)
        assert [r['id'] for r in a]==[r['id'] for r in x] and b==y
    return {'passed':True,'pairwiseSyntheticChecks':len(synthetic)**2,'legacyCandidates':len(old),'deterministicRepresentativeParity':True}

def main():
    checks=selftest()
    if '--selftest' in sys.argv:print(checks);return
    started=time.time();partial='--partial' in sys.argv
    complete=None if partial else read(OUT/'generation-complete.json')
    if not partial:assert complete['processedSeeds']==103680 and complete['cells']==72
    g=read(OUT/'geometry.json');rays=read(OUT/'sampling.json')['rays'];diameter=2*g['radius']
    raymap={(r['cell'],r['degrees']):r for r in rays}
    assert len(raymap)==len(rays)==len({tuple(r['cue']) for r in rays})==5184
    for r in rays:
        x,z=r['cue'];ix,iz=r['ix'],r['iz'];L,W=g['length'],g['width']
        assert -L/2+ix*L/24<=x<=-L/2+(ix+1)*L/24
        assert -W/2+iz*W/12<=z<=-W/2+(iz+1)*W/12
        assert x<=0 and z<=0 and r['degrees']%5==0
    def wall(rail):
        nx,nz=g['rails'][rail]['normal']
        return (0 if nx>0 else 1) if abs(nx)>.5 else (2 if nz>0 else 3)
    allrows=[];ids=set();seedn=set();rejections=collections.Counter();simulations=0;baseline=0
    for cell in range(72):
        folder=OUT/'cells'/f'{cell:02d}'
        if partial and not (folder/'receipt.json').exists():break
        receipt=read(folder/'receipt.json')
        assert receipt['cell']==cell and receipt['summary']['processedSeeds']==1440 and receipt['summary']['fullScan']
        assert all(sha(folder/name)==digest for name,digest in receipt['files'].items())
        assert receipt['identity']['entry']==sha(Path(__file__).with_name('main.swift'))
        rejections.update(receipt['summary']['rejections']);simulations+=receipt['summary']['simulations'];baseline+=receipt['summary']['baselineSimulations']
        rejected=receipt['summary']['rejections']
        assert receipt['summary']['baselineSimulations']+rejected.get('baseline-inaccessible',0)+rejected.get('baseline-incomplete',0)==1440
        bases=read(folder/'baselines.json.gz')
        assert len(bases)==len({b['id'] for b in bases})==receipt['summary']['baselineSimulations']
        assert all(b['cell']==cell for b in bases)
        rows=read(folder/'accepted.json.gz');verify=read(folder/'verification.json.gz')
        assert {r['id'] for r in rows}=={r['id'] for r in verify} and all(r['exactReplay'] for r in verify)
        for r in rows:
            s=r['seed'];orig=raymap[s['cell'],s['slot']*5]
            assert s['cell']==cell and math.dist(s['cue'],orig['cue'])<1e-6 and math.dist(s['dir'],orig['dir'])<1e-6
            assert s['sx'] in [0,-.25,.25,-.5,.5] and s['v'] in [1.5,2.5,3.5,4.5] and s['sy']==0
            hit=next(e for e in r['events'] if e['kind']=='ballBall' and set(e['balls'])=={'cueBall','object'})
            events=[e for e in r['events'] if e['index']<hit['index'] and e['kind']=='cushion' and e.get('ball')=='cueBall']
            rails=[e['rail'] for e in events]
            assert rails==r['rails'] and len(rails)==r['n'] and 1<=r['n']<=4 and all(0<=v<6 for v in rails)
            assert r['complete'] and 'cueBall' not in r['pocketedBalls']
            assert len(r['railAngles'])==r['n'] and all(15<=v<=75 for v in r['railAngles'])
            for e in events:
                a,b=g['rails'][e['rail']]['start'],g['rails'][e['rail']]['end'];length=math.dist(a,b);q=e['cue']
                t=sum((q[i]-a[i])*(b[i]-a[i]) for i in range(2))/length
                assert .10-1e-6<=t<=length-.10+1e-6
            walls=list(map(wall,rails));assert walls==r['walls']
            assert not any(a==c and a!=b and a//2==b//2 for a,b,c in zip(walls,walls[1:],walls[2:]))
            before=[p[1:] for p in r['cueTrack'] if p[0]<=events[0]['time']]
            assert sum(math.dist(a,b) for a,b in zip(before,before[1:]))>=.20-1e-6
            assert abs(r['offsetR'])<=.9 and r['segmentLength']>.22
            assert abs(math.dist(r['target'],r['placementCenter'])-abs(r['offsetR'])*g['radius'])<1e-8
            assert math.dist(s['cue'],r['target'])>diameter
            assert abs(r['target'][0])<g['length']/2-g['radius'] and abs(r['target'][1])<g['width']/2-g['radius']
            # The App decodes to Float; validate its bounds and normalization too.
            cue32=np.asarray(s['cue'],dtype=np.float32);target32=np.asarray(r['target'],dtype=np.float32)
            bound32=np.asarray([g['length'],g['width']],dtype=np.float32)/np.float32(2)-np.float32(g['radius'])
            assert np.all(np.abs(cue32)<bound32) and np.all(np.abs(target32)<bound32)
            assert np.hypot(*(cue32-target32))>np.float32(diameter)
            assert abs(float(np.hypot(*np.asarray(s['dir'],dtype=np.float32)))-1)<.0001
            assert r['id'] not in ids and (s['id'],r['n']) not in seedn
            ids.add(r['id']);seedn.add((s['id'],r['n']))
            # Diagnostic only: never use the player's post-contact rule to select the bank.
            laterEvents=[e for e in r['events'] if e['time']>hit['time'] and e['kind']=='cushion' and e.get('ball') in ['cueBall','object']]
            later=bool(laterEvents)
            mainLater=any(0<=e.get('rail',-1)<6 for e in laterEvents)
            keep={k:r[k] for k in ['id','n','walls','rails','offsetR','seed','target','cueTrack','category']}
            keep['postContactRail']=later;keep['postContactMainRail']=mainLater;allrows.append(keep)
        print('AUDITED',cell+1,len(allrows),flush=True)
    if partial:
        print('PARTIAL AUDIT PASSED',len(allrows),flush=True)
        if '--benchmark' in sys.argv:
            t=time.time();k,m,c=reduce(allrows[:5000],diameter);print('BENCHMARK',dict(input=5000,kept=len(k),merged=len(m),comparisons=c,seconds=time.time()-t),flush=True)
        return
    assert len(allrows)==complete['accepted']
    binding=read(OUT/'source-binding.json')
    drift=[b['path'] for b in binding['sources'] if b['currentProduction'] and sha(ROOT/b['path'])!=b['sha256']]
    assert not drift,drift
    for b in read(OUT/'input-binding.json').values():assert sha(Path(b['path']))==b['sha256']
    kept,merged,comparisons=reduce(allrows,diameter)
    byid={r['id']:r for r in allrows}
    for pair in merged:assert same(byid[pair['removed']],byid[pair['representative']],diameter)
    index=collections.defaultdict(list)
    for i,a in enumerate(kept):
        for j in neighbors(a,index,diameter):assert not same(a,kept[j],diameter)
        index[key(a,diameter)].append(i)
    assert len(kept)+len(merged)==len(allrows)
    questions=[]
    for r in kept:
        s=r['seed'];point=lambda p:dict(zip(['x','z'],p))
        questions.append(dict(id=r['id'],cue=point(s['cue']),target=point(r['target']),walls=r['walls'],direction=point(s['dir']),input=dict(spinX=s['sx'],spinY=s['sy'],velocity=s['v'])))
    (OUT/'kick-practice-bank.json').write_text(json.dumps({'version':1,'questions':questions},ensure_ascii=False,separators=(',',':'))+'\n')
    def coverage(rows):
        return dict(total=len(rows),perRail=dict(collections.Counter(r['n'] for r in rows)),cells=len({r['seed']['cell'] for r in rows}),
            perRailCells={str(n):len({r['seed']['cell'] for r in rows if r['n']==n}) for n in range(1,5)},
            angles=len({r['seed']['slot'] for r in rows}),spin=dict(collections.Counter(r['seed']['sx'] for r in rows)),speed=dict(collections.Counter(r['seed']['v'] for r in rows)),
            wallSequences=len({tuple(r['walls']) for r in rows}),segmentSequences=len({tuple(r['rails']) for r in rows}))
    selected=[]
    for n in range(1,5):
        used=set()
        for category,quota in [('zero',3),('leftLight',2),('rightLight',2),('leftMedium',1),('rightMedium',1)]:
            options=[r for r in kept if r['n']==n and r['category']==category]
            for _ in range(quota):
                if not options:break
                options.sort(key=lambda r:(r['seed']['cell'] in used,abs(r['offsetR']),r['id']))
                row=options.pop(0);selected.append(row);used.add(row['seed']['cell'])
    selected_ids={r['id'] for r in selected};fullselected=[]
    for cell in range(72):
        for r in read(OUT/'cells'/f'{cell:02d}'/'accepted.json.gz'):
            if r['id'] in selected_ids:fullselected.append(r)
    fullselected.sort(key=lambda r:(r['n'],r['id']))
    for i,r in enumerate(fullselected):r['displayID']=f'F{i+1:02d}'
    dump(OUT/'selected.json',fullselected)
    dump(OUT/'deduplication.json',dict(merged=merged,comparisons=comparisons,thresholdMetres=diameter,sampleStepMetres=.01,pathReserveMetres=.005,ranking='absolute lateral offset, lower speed, stable ID'))
    dump(OUT/'dedup-selftest.json',checks)
    noLater=[r for r in kept if not r['postContactRail']]
    report=dict(processedSeeds=103680,randomOrigins=5184,scannedCells=72,candidates=coverage(allrows),bank=coverage(kept),merged=len(merged),
        simulations=simulations,baselineSimulations=baseline,exactReplays=len(allrows),rejections=dict(rejections),
        referencesWithoutPostContactRail=len(noLater),referencesWithoutPostContactMainRail=sum(not r['postContactMainRail'] for r in kept),postContactRailUsedAsBankFilter=False,
        noLaterRailExample=next(r['id'] for r in noLater if r['n']==1),successExample=next(r['id'] for r in kept if r['postContactRail']),
        bankSHA256=sha(OUT/'kick-practice-bank.json'),bankBytes=(OUT/'kick-practice-bank.json').stat().st_size,
        sourceDrift=drift,selftest=checks,seconds=time.time()-started,
        boundary='Complete finite 72-cell x 72-angle x 4-speed x 5-side-spin scan; first valid target per input and N. No perturbation, high/low spin, mirror replay, obstacle/minimum-rail exclusivity, or real-table validation.')
    dump(OUT/'audit.json',report)
    dump(OUT/'bank-index.json',[dict(id=r['id'],cell=r['seed']['cell'],angle=r['seed']['slot']*5,n=r['n'],rails=r['rails'],postContactRail=r['postContactRail'],postContactMainRail=r['postContactMainRail']) for r in kept])
    print(json.dumps(report,ensure_ascii=False,indent=2),flush=True)
if __name__=='__main__':main()
