"""Read-only comfort scoring of middle-filtered original 25-degree recommendations."""
from pathlib import Path
import collections,gzip,hashlib,importlib.util,json,math,time,traceback
import numpy as np
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
A=ROOT/'output/two-ball-middle-filter-20261025';OUT=ROOT/'output/two-ball-comfort-full-20261025'
PREVIEW=ROOT/'output/two-ball-comfort-score-five-v2-20261025/data.json'
def read(p):return json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=2,allow_nan=False)+'\n')
def loadrows(p):return [json.loads(l) for l in gzip.decompress(p.read_bytes()).splitlines()]
G=read(PREVIEW)['geometry'];HX=G['length']/2;HZ=G['width']/2;R=G['radius']
ANCHORS=[(-HX+R,-HZ+R),(HX-R,-HZ+R),(-HX+R,HZ-R),(HX-R,HZ-R),(0,-HZ),(0,HZ)]
THRESHOLDS=[80,85,90]
def score(c,b,p):
    nx,nz=ANCHORS[p][0]-b[0],ANCHORS[p][1]-b[1];nn=math.hypot(nx,nz);nx/=nn;nz/=nn
    depth=max(0,min(((bound-pos) if direction>0 else (-bound-pos))/direction for pos,direction,bound in zip(b,(-nx,-nz),(HX-R,HZ-R)) if abs(direction)>1e-12))
    scale=min(1,max(.4,depth/.9));lo=.5*scale;hi=.8*scale
    vx,vz=b[0]-2*R*nx-c[0],b[1]-2*R*nz-c[1];norm=math.hypot(vx,vz);assert norm>1e-9
    bx,bz=-vx/norm,-vz/norm;cut=math.degrees(math.atan2(abs(vx*nz-vz*nx),vx*nx+vz*nz));dist=math.dist(c,b)
    gaps=[HX-c[0]-R,HX+c[0]-R,HZ-c[1]-R,HZ+c[1]-R];gap=min(gaps)
    assert dist>=2*R and cut<90
    # A valid native stop near a pocket opening can overlap the rectangular
    # body inset. Preserve it; the existing proximity formula clamps gap at zero.
    D=100*math.exp(-(max(lo-dist,0)/(.8*lo))**2-(max(dist-hi,0)/.75)**2)
    penalties=[(45+15*max(t,0)**2)*math.exp(-(max(g,0)*100/8)**1.2) for g,t in zip(gaps,(bx,-bx,bz,-bz))]
    i=max(range(4),key=lambda k:penalties[k]);other=max(penalties[2:]) if i<2 else max(penalties[:2]);S=100-penalties[i]-min(8,.25*other)
    V=100*math.exp(-(max(cut-15,0)/30)**2);total=math.exp((math.log(D)+math.log(S)+math.log(V))/3)
    return dict(distanceScore=D,spaceScore=S,angleScore=V,totalScore=total,distanceMeters=dist,angleDegrees=cut,gapMeters=gap,depthMeters=depth,preferredMeters=[lo,hi])
def describe(values):
    a=np.asarray(values,dtype=float)
    return dict(count=len(a),mean=float(a.mean()),min=float(a.min()),max=float(a.max()),percentiles={str(p):float(np.percentile(a,p)) for p in [5,10,25,50,75,90,95]},histogram10=np.histogram(a,bins=np.linspace(0,100,11))[0].tolist(),atLeast={str(t):int(np.sum(a>=t)) for t in THRESHOLDS})

def main():
    start=time.perf_counter();OUT.mkdir(exist_ok=True)
    assert not (OUT/'summary.json').exists(),'Use a new output version; completed summaries are immutable.'
    (OUT/'parts').mkdir(exist_ok=True)
    source=read(A/'summary.json');assert source['state']=='complete' and source['auditPassed'] and source['stats']['afterTop']==745153
    index=read(A/'parts-index.json');jobs={r['stem']:r for r in read(A/'manifest.json')['schedule']};assert len(index)==1357
    preview=read(PREVIEW);expected={(s['id'],s['cellID'],q['comboIndex'],q['pocket']):q['latestScores'] for s in preview['samples'] for q in s['routes']};matched=set()
    frozen={str(A/'summary.json'):sha(A/'summary.json'),str(A/'manifest.json'):sha(A/'manifest.json'),str(A/'parts-index.json'):sha(A/'parts-index.json'),str(PREVIEW):sha(PREVIEW),str(HERE/'run.py'):sha(HERE/'run.py')}
    write(OUT/'manifest.json',dict(source=str(A),sourceHashes=frozen,geometry=G,policy=dict(distanceNearWidth=.8,distanceFarWidthMeters=.75,distanceBasePlateau=[.5,.8],depthScaleDenominator=.9,depthScaleMin=.4,space=dict(gapScaleCm=8,basePenalty=45,directionPenalty=15,gapPower=1.2,secondaryWeight=.25,secondaryCap=8),anglePlateauDegrees=15,angleDecayDegrees=30,total='equal geometric mean',questionKey=['layout.id','candidate.cellID'],questionScore='max remaining recommendation total',thresholdComparison='>= on unrounded score',filterByComfort=False,zeroRecommendationScore=None,originalPocketKept=True,negativeRectangleGap="clamp proximity input to zero; preserve and count existing valid native stops")))
    totals=[];best=[];allroutecounts=collections.Counter();thresholdCountHists={str(t):collections.Counter() for t in THRESHOLDS};seen=set();bseen=set();partIndex=[];counts=collections.Counter();negative=[];validLayouts=0;layoutsAbove={str(t):0 for t in THRESHOLDS};beforeB=afterB=0
    for ni,receipt in enumerate(index):
        stem=receipt['stem'];fp=A/'parts'/f'{stem}.jsonl.gz';pp=A/'proofs'/f'{stem}.jsonl.gz';op=Path(jobs[stem]['source'])
        assert sha(fp)==receipt['finalSHA256'] and sha(pp)==receipt['proofsSHA256'] and sha(op)==jobs[stem]['sourceSHA256']
        rows=loadrows(fp);proofrows=loadrows(pp);oldrows=loadrows(op);results=[]
        for row,proof,old in zip(rows,proofrows,oldrows,strict=True):
            assert row['id']==proof['id']==old['id'] and row['id'] not in seen;seen.add(row['id']);assert row['board']==old['board']
            routes={r['comboIndex']:r for r in row['routes']};oldroutes={r['comboIndex']:r for r in old['routes']};assert all(r==oldroutes[i] for i,r in routes.items())
            proofs={p['key']:p for p in proof['middleProofs']};deleted={(d['cellID'],d['recommendation']['comboIndex'],d['recommendation']['pocket']):d for d in proof['deleted']}
            new=dict(id=row['id'],sourcePart=stem,sourceSHA256=receipt['finalSHA256'],candidates=[]);layoutBest=[]
            for c,o in zip(row['candidates'],old['candidates'],strict=True):
                assert c['cellID']==o['cellID'] and c['position']==o['position'];key=(row['id'],c['cellID']);assert key not in bseen;bseen.add(key)
                beforeB+=bool(o['top5']);afterB+=bool(c['top5']);allroutecounts[len(c['top5'])]+=1
                kept={(q['comboIndex'],q['pocket']):q for q in c['top5']}
                for q in o['top5']:
                    k=(q['comboIndex'],q['pocket'])
                    if k in kept:assert {a:b for a,b in kept[k].items() if a!='middleProofKey'}==q
                    else:
                        dd=deleted[(c['cellID'],*k)];pr=proofs[dd['proofKey']];assert q['pocket'] in (4,5) and not pr['passed'];counts['deletedMiddle']+=1
                out=dict(cellID=c['cellID'],position=c['position'],recommendations=[])
                for rank,q in enumerate(c['top5'],1):
                    route=routes[q['comboIndex']];stop=route['cueStop']
                    if q['pocket'] in (4,5):
                        pr=proofs[q['middleProofKey']];assert pr['passed'] and pr['request']['cue']==stop and pr['request']['object']==c['position'] and pr['request']['pocket']==q['pocket']
                        assert any(t['passed'] and t['settled'] and not t['cuePocketed'] and t['route']=='direct-pot' and any(e['kind']=='pocket' and e['ball']=='object' and e['pocketID']==f"pocket_{q['pocket']}" for e in t['events']) for t in pr['trials']);counts['verifiedMiddle']+=1
                    else:counts['unchangedCorner']+=1
                    scores=score(stop,c['position'],q['pocket']);assert abs(scores['angleDegrees']-q['angle'])<1e-6
                    if scores['gapMeters']<0:negative.append(scores['gapMeters'])
                    record=dict(originalFilteredRank=rank,comboIndex=q['comboIndex'],pocket=q['pocket'],stop=stop,**scores);out['recommendations'].append(record);totals.append(scores['totalScore'])
                    ek=(*key,q['comboIndex'],q['pocket'])
                    if ek in expected:
                        for k,v in [('distance','distanceScore'),('space','spaceScore'),('angle','angleScore'),('total','totalScore')]:assert abs(expected[ek][k]-scores[v])<1e-8
                        matched.add(ek)
                values=[q['totalScore'] for q in out['recommendations']];out['bestTotalScore']=max(values) if values else None
                for t in THRESHOLDS:thresholdCountHists[str(t)][sum(x>=t for x in values)]+=1
                if values:best.append(max(values));layoutBest.append(max(values))
                new['candidates'].append(out)
            if layoutBest:
                validLayouts+=1
                for t in THRESHOLDS:layoutsAbove[str(t)]+=max(layoutBest)>=t
            results.append(new)
        p=OUT/'parts'/f'{stem}.jsonl.gz'
        with gzip.open(p,'wt',compresslevel=6) as f:
            for r in results:f.write(json.dumps(r,ensure_ascii=False,separators=(',',':'),allow_nan=False)+'\n')
        partIndex.append(dict(stem=stem,sha256=sha(p),bytes=p.stat().st_size,layoutIDs=[r['id'] for r in results]))
        if ni%75==0:write(OUT/'progress.json',dict(state='scoring',parts=ni+1,totalParts=len(index),layouts=len(seen),BPositions=len(bseen),recommendations=len(totals),elapsedSeconds=time.perf_counter()-start));print('scoring',ni+1,len(totals),flush=True)
    assert len(seen)==13570 and len(bseen)==173577 and len(totals)==745153 and afterB==167062
    assert counts==dict(deletedMiddle=70923,verifiedMiddle=286788,unchangedCorner=458365)
    assert matched==set(expected)
    for p,h in frozen.items():assert sha(Path(p))==h
    write(OUT/'parts-index.json',partIndex)
    summary=dict(state='computed-needs-audit',auditPassed=False,layouts=len(seen),BPositions=len(bseen),recommendations=len(totals),sourceMiddleValidation=dict(counts),questionsWithRoutesBeforeMiddle=beforeB,questionsWithRoutesAfterMiddle=afterB,questionsLostAllRoutes=beforeB-afterB,questionsWithoutRoutes=173577-afterB,layoutsWithRoutes=validLayouts,layoutsAtLeast=layoutsAbove,routeScores=describe(totals),questionBestScores=describe(best),recommendationCountHistogram=dict(allroutecounts),thresholdRecommendationCountHistograms={k:dict(v) for k,v in thresholdCountHists.items()},negativeRectangleGap=dict(count=len(negative),minMeters=min(negative) if negative else None),preview22Matched=True,scoreGzipBytes=sum(p['bytes'] for p in partIndex),scoringAndSourceAuditSeconds=time.perf_counter()-start)
    write(OUT/'summary-pending.json',summary);print('COMPUTED',json.dumps(summary,ensure_ascii=False),flush=True)
if __name__=='__main__':
    try:main()
    except BaseException:write(OUT/'failure.json',dict(traceback=traceback.format_exc(),time=time.time()));raise
