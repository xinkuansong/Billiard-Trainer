#!/usr/bin/env python3
"""Discrete map retrieval, frozen rankings, and independent two-shot audit."""
from pathlib import Path
from collections import Counter
import hashlib, json, math, sys
import numpy as np

OUT=Path(__file__).resolve().parent
def read(n): return json.loads((OUT/n).read_text())
def save(n,v): (OUT/n).write_text(json.dumps(v,ensure_ascii=False,indent=2))
def point(d): return np.array([d['x'],d['z']])
def cut(cue, target, aim):
    n=np.asarray(aim)-np.asarray(target);n=n/np.linalg.norm(n)
    v=np.asarray(target)-2*.028575*n-np.asarray(cue)
    v=v/np.maximum(np.linalg.norm(v,axis=-1,keepdims=True),1e-20)
    return np.degrees(np.arccos(np.clip(np.sum(v*n,axis=-1),-1,1)))
def cell(p):
    ij=np.floor((np.asarray(p)-[-1.2,-.6])/.06+.5+1e-7).astype(int)
    return int(ij[0]*21+ij[1]) if 0<=ij[0]<=40 and 0<=ij[1]<=20 else None
def checks():
    assert abs(float(cut([-1,0],[0,0],[1,0])))<1e-6
    assert abs(float(cut([-.05715-1,-1],[0,0],[1,0]))-45)<1e-6
    assert float(cut([1,0],[0,0],[1,0]))>179
    assert cell([-1.2,-.6])==0 and cell([1.2,.6])==860 and cell([0,0])==430
    # Same support, unequal density: area and sample-mass rankings must differ.
    counts=Counter({0:80,1:10,2:10});a={1,2};b={0}
    assert len(a)>len(b) and sum(counts[x] for x in a)<sum(counts[x] for x in b)
    save('geometry-checks.json',{'passed':7,'plane':'world X-Z','unit':'m','areaUnit':'m2','noConvexHull':True})

def scan():
    checks(); data=read('scan-results.json');sample=read('sample.json')
    targets=read('target-metadata.json');groups={r['id']:[x for x in data['rows'] if x['route']==r['id'] and x['accepted']] for r in data['routes']}
    eligible=[]
    for t in targets:
        p=np.array(t['point'])
        if t['railClearance']<.05 or min(np.linalg.norm(p-point(sample[k])) for k in ['cue','target'])<.10: continue
        t['roughCounts']={}
        for key,rows in groups.items():
            stops=np.array([x['stop'] for x in rows])
            if not len(stops):t['roughCounts'][key]=0;continue
            ds=np.linalg.norm(stops-p,axis=1)
            t['roughCounts'][key]=int(np.sum((cut(stops,p,t['aim'])<=35)&(ds>=.15)&(ds<=1.2)))
        if sum(t['roughCounts'].values()):eligible.append(t)
    selected=[]
    for pk in range(6):
        local=[]
        for key in groups:
            pool=[t for t in eligible if t['pocket']==pk and all(np.linalg.norm(np.array(t['point'])-s['point'])>=.20 for s in local)]
            if not pool:continue
            chosen=max(pool,key=lambda t:(t['roughCounts'][key],sum(t['roughCounts'].values()),-t['id']))
            local.append(chosen)
        selected.extend(local)
    assert len(selected)>0 and len({t['id'] for t in selected})==len(selected)
    save('candidates.json',selected)
    save('candidate-selection.json',{'method':'Exploratory pool: up to three per pocket, round-robin highest geometric design-stop coverage per route; 20cm within-pocket spacing; no holdout use; not a representative sample of all 2520 targets.',
         'count':len(selected),'eligibleTargets':len(eligible),'designFirstPass':{k:len(v) for k,v in groups.items()}})
    print('Candidates',len(selected),'first-pass',{k:len(v) for k,v in groups.items()},flush=True)

def maps():
    checks();scan=read('scan-results.json');maps={m['id']:m['rows'] for m in read('map-results.json')['maps']}
    rankings=[];selections=[]
    for route in scan['routes']:
        rows=[r for r in scan['rows'] if r['route']==route['id']]
        counts=Counter(cell(r['stop']) for r in rows if r['accepted'])
        counts.pop(None,None); scores=[]
        for cid,grid in maps.items():
            assert len(grid)==861 and len({r['cell'] for r in grid})==861
            feasible={r['cell'] for r in grid if r['pass']};common=feasible&counts.keys()
            scores.append({'id':cid,'intersectionCells':len(common),'intersectionM2':len(common)*.06**2,
                           'coveredSamples':sum(counts[k] for k in common),'coverage':sum(counts[k] for k in common)/len(rows),
                           'mapPassCells':len(feasible),'intersectionCellIDs':sorted(common)})
        area=sorted(scores,key=lambda x:(-x['intersectionCells'],-x['coveredSamples'],x['id']))
        coverage=sorted(scores,key=lambda x:(-x['coveredSamples'],-x['intersectionCells'],x['id']))
        for rank,x in enumerate(area,1):x['areaRank']=rank
        for rank,x in enumerate(coverage,1):x['coverageRank']=rank
        ids=sorted({x['id'] for x in area[:3]+coverage[:3]})
        control=coverage[len(coverage)//2]['id']
        ids=sorted(set(ids+[control]))
        rankings.append({'route':route['id'],'scores':scores,'areaOrder':[x['id'] for x in area], 'coverageOrder':[x['id'] for x in coverage],
                         'occupiedCells':{str(k):v for k,v in counts.items()},'firstPass':sum(r['accepted'] for r in rows),'designTotal':len(rows)})
        selections.append({'route':route['id'],'candidateIDs':ids,'controlID':control})
    save('rankings.json',{'rankings':rankings,'selections':selections})
    save('ranking-identity.json',{'sha256':hashlib.sha256((OUT/'rankings.json').read_bytes()).hexdigest(), 'holdoutUsed':False})
    print('Ranked',len(maps),'maps; full two-shot pairs',sum(len(s['candidateIDs']) for s in selections),flush=True)

def interval(k,n):
    z=1.96;p=k/n;d=1+z*z/n;c=(p+z*z/(2*n))/d;w=z*math.sqrt(p*(1-p)/n+z*z/(4*n*n))/d
    return [c-w,c+w]

def validate():
    assert hashlib.sha256((OUT/'rankings.json').read_bytes()).hexdigest()==read('ranking-identity.json')['sha256']
    data=read('validate-results.json');scan=read('scan-results.json');ranks=read('rankings.json');metrics=[]
    nominalIndex=read('protocol.json')['designOffsets'].index([0,0,0,0])
    for result in data['results']:
        assert len(result['rows'])==177
        for split,n in [('design',81),('holdout',96)]:
            rows=[r for r in result['rows'] if r['split']==split];assert len(rows)==n
            k=sum(r['complete'] for r in rows)
            m={'route':result['route'],'id':result['id'],'split':split,'total':n,'complete':k,'rate':k/n,
               'firstPass':sum(r['accepted'] for r in rows),'secondMoved':sum(not r['secondUnchanged'] for r in rows),
               'firstScratch':sum(r.get('scratch',False) for r in rows),'secondOutsideRules':sum(r.get('second',{}).get('status')=='outside_pilot_rules' for r in rows),
               'secondBudgetExhausted':sum(r.get('second',{}).get('status')=='budget_exhausted' for r in rows)}
            if split=='holdout':m['wilson95']=interval(k,n)
            metrics.append(m)
        for row in result['rows']:
            if row['complete']:
                assert row['accepted'] and row['secondUnchanged'] and row['second']['replay']['physicsPass']
                assert not row['scratch'] and not row['second']['replay']['scratch']
            # Fixed-aim parameter reconstruction independent of the Swift code.
            route=next(r for r in scan['routes'] if r['id']==result['route'])
            a=row['offset'][1]*.25*math.pi/180;x,z=route['direction']
            assert np.linalg.norm(np.array(row['direction'])-[x*math.cos(a)-z*math.sin(a),x*math.sin(a)+z*math.cos(a)])<2e-6
        nominal=next(r for r in result['rows'] if r['split']=='design' and r['sampleIndex']==nominalIndex)
        for m in metrics[-2:]:m['nominalComplete']=nominal['complete']
    comparison=[]
    for rank in ranks['rankings']:
        item={'route':rank['route']}
        for method in ['area','coverage']:
            ids=rank[f'{method}Order'][:3]
            ms=[m for m in metrics if m['route']==rank['route'] and m['split']=='holdout' and m['id'] in ids]
            assert len(ms)==3
            item[method]={'ids':ids,'meanHoldoutRate':sum(m['rate'] for m in ms)/3,'rates':[next(m['rate'] for m in ms if m['id']==i) for i in ids]}
        comparison.append(item)
    save('summary.json',{'metrics':metrics,'comparison':comparison,'validatedPairs':len(data['results']),
                        'designAndHoldoutTrials':len(data['results'])*177,'mapCells':sum(len(m['rows']) for m in read('map-results.json')['maps']),
                        'mapWitnesses':sum(r['pass'] for m in read('map-results.json')['maps'] for r in m['rows']),
                        'audit':'fixed aim reconstructed; all successful sequences checked for first pass, unchanged B, second replay and no scratch; rankings hash unchanged'})
    print(json.dumps({'pairs':len(data['results']),'comparison':comparison},ensure_ascii=False),flush=True)

if __name__=='__main__':
    {'scan':scan,'map':maps,'validate':validate}[sys.argv[1]]()
