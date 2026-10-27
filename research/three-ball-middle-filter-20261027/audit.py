from pathlib import Path
import sys, json, math, time, os
from concurrent.futures import ProcessPoolExecutor
import numpy as np
import filter as F
import pocket_rules as M
R=F.R;OUT=F.OUT;ROOT=F.ROOT

def dense_group(job):
    s,region,group=job;ball=np.array(s['second']);aim=np.array(region['aim'])
    x=np.linspace(-R.HX+R.R,R.HX-R.R,math.ceil((R.L-2*R.R)/.001)+1)
    z=np.linspace(-R.HZ+R.R,R.HZ-R.R,math.ceil((R.W-2*R.R)/.001)+1)
    xx,zz=np.meshgrid(x,z);pts=np.stack([xx.ravel(),zz.ravel()],axis=1)
    f2=R.evaluate(pts,ball,aim)[:,3];valid=np.isfinite(f2)&(f2>=85)
    pts=pts[valid];f2=f2[valid];results=[]
    ghost=ball-2*R.R*(aim-ball)/np.linalg.norm(aim-ball)
    positions=F.read(F.OLD/f"sample-{s['number']}.json")['candidates']
    for checked in group['results']:
        if checked['status']!='bounded_pass':continue
        third=np.array(positions[checked['candidate']]['position'])
        scores=np.stack([np.nan_to_num(R.evaluate(pts,third,a)[:,3],nan=0) for a in R.ANCHORS[M.pockets(third)]],axis=1)
        margin=f2-scores.max(axis=1);idx=int(margin.argmin())
        assert margin.min()>0
        assert np.linalg.norm(pts-third,axis=1).min()>=2*R.R
        assert F.segment_distance(third,pts,ghost).min()>=2*R.R
        results.append(dict(candidate=checked['candidate'],points=len(pts),minObservedMargin=float(margin[idx]),worstCue=pts[idx].tolist(),bestPocket3=M.pockets(third)[int(scores[idx].argmax())]))
    return dict(sample=s['number'],pocket=region['pocket'],results=results)

def main():
    start=time.monotonic();filtered=F.read(OUT/'filter.json');regions=F.read(F.REG/'data.json');jobs=[];cases=[];rejected=0
    for s in regions['samples']:
        old=F.read(F.OLD/f"sample-{s['number']}.json")
        for region in s['regions']:
            group=next(g for g in filtered['groups'] if g['sample']==s['number'] and g['pocket']==region['pocket'])
            if any(c['status']=='bounded_pass' for c in group['results']):jobs.append((s,region,group))
            for c in group['results']:
                if c['status']!='rejected':continue
                rejected+=1;w=c['witness'];third=old['candidates'][c['candidate']]['position'];cue=w['cue']
                score=R.evaluate(cue,s['second'],region['aim'])[3];assert score>=85
                if w['reason']=='blocks_second_target_path':assert F.segment_distance(third,np.array(s['second']),np.array(region['aim']))<2*R.R
                else:assert F.assess_points([cue],np.array(s['second']),np.array(region['aim']),np.array(third)) is not None
                cases.append(dict(c=cue,b=s['second'],p=region['aim']))
                cases.extend(dict(c=cue,b=third,p=a.tolist()) for a in R.ANCHORS)
    with ProcessPoolExecutor(max_workers=4) as pool:dense=list(pool.map(dense_group,jobs))
    F.write(OUT/'dense-audit.json',dense)
    for g in dense:
        s=regions['samples'][g['sample']-1];old=F.read(F.OLD/f"sample-{g['sample']}.json")
        for result in g['results']:
            cue=result['worstCue'];third=old['candidates'][result['candidate']]['position']
            cases.extend([dict(c=cue,b=s['second'],p=R.ANCHORS[g['pocket']].tolist()),dict(c=cue,b=third,p=R.ANCHORS[result['bestPocket3']].tolist())])
    chains=0;third_below_new85=0
    for s in filtered['samples']:
        fresh=F.read(OUT/f"sample-{s['number']}.json");old=F.read(F.OLD/f"sample-{s['number']}.json")
        assert len(fresh['positions'])==72
        for c in fresh['positions']:
            reasons,best=F.opening(old['sample'],old['candidates'][c['id']])
            assert reasons==c['reasons'] and best==c['bestInitial']
            assert c['legalPockets3']==M.pockets(c['position'])
            if c['chains']:assert not reasons
        for c in fresh['positions']:
            for ch in c['chains']:
                chains+=1;rank=ch['firstRank'];assert rank in c['eligibleRanks'];assert ch['pocket2']==fresh['sample']['refs'][rank][1]
                shots=ch['shots'];base=old['baselines'][rank];assert shots[0]['request']['dir']==base['request']['dir']
                assert all(shots[0]['request'][k]==base['request'][k] for k in ['v','sx','sy','pocket'])
                assert shots[0]['result']['rails']==base['parameter']['rails'];assert math.dist(shots[0]['result']['stop'],base['result']['stop'])<1e-6
                for k,shot in enumerate(shots):
                    q=shot['request'];r=shot['result'];assert r['success']
                    if k:
                        prev=shots[k-1]['result'];assert q['cue']==prev['stop'];assert q['object']==prev['finals']['obstacle0']
                        assert q['obstacles']==([prev['finals']['obstacle1']] if k==1 else [])
                    for j,p in enumerate(q['obstacles']):assert math.dist(p,r['finals'][f'obstacle{j}'])<1e-6
                    pockets=[e for e in r['events'] if e['kind']=='pocket'];assert len(pockets)==1 and pockets[0]['ball']=='object' and pockets[0]['pocket']==f'pocket_{q["pocket"]}'
                    contacts=[e for e in r['events'] if e['kind']=='ball'];assert all(set(e['balls'])=={'cueBall','object'} for e in contacts)
                q=shots[1]['request'];assert R.evaluate(q['cue'],q['object'],R.ANCHORS[ch['pocket2']])[3]>=85
                third=shots[2]['request'];assert M.allowed(third['object'],ch['pocket3']);new3=R.evaluate(third['cue'],third['object'],R.ANCHORS[ch['pocket3']]);assert np.allclose(new3,ch['newComfort3'],atol=1e-10)
                direction=R.ANCHORS[ch['pocket3']]-third['object'];direction/=np.linalg.norm(direction)
                incoming=np.array(third['object'])-2*R.R*direction-third['cue']
                cut=math.degrees(math.atan2(abs(incoming[0]*direction[1]-incoming[1]*direction[0]),incoming@direction))
                old_angle=100*math.exp(-(max(cut-15,0)/30)**2)
                old_total=float(np.cbrt(new3[0]*new3[1]*old_angle))
                assert old_total>=85-1e-9 and abs(old_total-ch['comfort3']['total'])<1e-6
                third_below_new85+=bool(new3[3]<85)
                cases.append(dict(c=q['cue'],b=q['object'],p=R.ANCHORS[ch['pocket2']].tolist()))
    # Reuse the earlier exact-source harness with explicitly redirected research
    # paths; no files in the previous experiments are modified.
    saved_out,saved_here=R.OUT,R.HERE
    try:
        R.OUT=OUT/'score-oracle';R.OUT.mkdir(exist_ok=True);R.HERE=F.HERE
        oracle=R.native_check(cases,Path(os.environ['QIUJI_TEST_WORK']))
    finally:R.OUT,R.HERE=saved_out,saved_here
    native_output=F.read(OUT/'score-oracle/native-output.json')
    native_witness_scores=[native_output[i*7][3] for i in range(rejected)]
    assert min(native_witness_scores)>=85
    for path,digest in filtered['inputSHA'].items():assert F.sha(ROOT/path)==digest
    summary=dict(passed=True,rejectedGroupWitnesses=rejected,nativeWitnessMinimumScore2=min(native_witness_scores),boundedPassGroups=sum(len(g['results']) for g in dense),densePointComparisons=sum(r['points'] for g in dense for r in g['results']),minimumDenseObservedMargin=min(r['minObservedMargin'] for g in dense for r in g['results']),middleFilterOracle=F.read(OUT/'middle-oracle.json')['passed'],chains=chains,thirdBelowNew85=third_below_new85,oracle=oracle,seconds=time.monotonic()-start,scriptSHA={p.name:F.sha(p) for p in [F.HERE/'filter.py',F.HERE/'flow.py',F.HERE/'audit.py',F.HERE/'pocket_rules.py',F.HERE/'main.swift',F.HERE/'build.py']})
    F.write(OUT/'audit.json',summary);print('AUDIT',summary,flush=True)
if __name__=='__main__':main()
