"""Fixed comfort-region screening. Exact counterexamples or conservative box bounds.

Region never shrinks in response to ball 3. Unresolved cells never pass.
"""
from pathlib import Path
import sys, json, math, time, hashlib
from concurrent.futures import ProcessPoolExecutor
import numpy as np
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
OUT=ROOT/'output'/HERE.name;OLD=ROOT/'output/three-ball-placement-pilot-20261026'
REG=ROOT/'output/three-ball-comfort-region-20261027'
sys.path.insert(0,str(ROOT/'research/three-ball-comfort-region-20261027'))
import region as R
import pocket_rules as M
sys.path.insert(0,str(ROOT/'research/three-ball-placement-pilot-20261026'))
import experiment as E

def opening(s,c):
    reasons=[r for r in c['reasons'] if r!='third_not_harder']
    opts=[dict(pocket=p,**E.metric(s['board']['cue'],c['position'],E.ANCHORS[p])) for p in M.pockets(c['position'])]
    opts=[o for o in opts if o['score'] is not None]
    best=min(opts,key=lambda o:(o['score'],o['pocket'])) if opts else None
    if best and best['score']<=s['firstMetric']['score']:reasons.append('third_not_harder')
    return reasons,best

EPS=1e-8
def read(p):return json.loads(p.read_text())
def write(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=2,allow_nan=False))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def norm_range(lo,hi):
    near=np.where(lo>0,lo,np.where(hi<0,hi,0))
    return np.linalg.norm(near,axis=-1),np.linalg.norm(np.maximum(abs(lo),abs(hi)),axis=-1)

def bounds(boxes,ball,aim):
    """Monotone range enclosure of every score component on axis-aligned boxes.

    Invalid evaluations have value 0 for enclosure only. Angular ranges use
    linear dot/cross extrema. Direction ratios widen to [-1,1] at zero norm.
    A small score-unit outward guard handles floating point round-off; this is
    an analytically conservative double-precision calculation, not formal IA.
    """
    boxes=np.asarray(boxes);lo,hi=boxes[:,:2],boxes[:,2:]
    b=np.asarray(ball);p=np.asarray(aim);length=np.linalg.norm(p-b);n=(p-b)/length
    ghost=b-2*R.R*n;vlow,vhigh=ghost-hi,ghost-lo
    nl,nh=norm_range(vlow,vhigh);dl,dh=norm_range(lo-b,hi-b)
    def linear(a):
        return np.sum(np.where(a>=0,vlow*a,vhigh*a),axis=1),np.sum(np.where(a>=0,vhigh*a,vlow*a),axis=1)
    dotlo,dothi=linear(n);cl,ch=linear(np.array([n[1],-n[0]]))
    crosslo=np.maximum(0,np.maximum(cl,-ch));crosshi=np.maximum(abs(cl),abs(ch))
    cutlo=np.degrees(np.arctan2(crosslo,np.maximum(dothi,0)))
    cuthi=np.degrees(np.arctan2(crosshi,np.maximum(dotlo,0)))
    cuthi=np.where(dotlo<=1e-12,90,cuthi)
    depth=max(0,min(((bound if direction>0 else -bound)-pos)/direction for pos,direction,bound in zip(b,-n,[R.HX-R.R,R.HZ-R.R]) if abs(direction)>1e-12))
    scale=min(1,max(.4,depth/.9));a,z=.5*scale,.8*scale
    def distance(d):return 100*np.exp(-(np.maximum(a-d,0)/(.8*a))**2-(np.maximum(d-z,0)/.75)**2)
    Dlo=np.minimum(distance(dl),distance(dh))
    Dhi=distance(np.maximum(dl,np.minimum(dh,(a+z)/2)))
    backlo,backhi=lo-ghost,hi-ghost
    safe=np.maximum(nl,1e-100)[:,None];nhsafe=np.maximum(nh,1e-100)[:,None]
    ratios=np.stack([backlo/safe,backlo/nhsafe,backhi/safe,backhi/nhsafe])
    rlo=np.maximum(-1,np.min(ratios,axis=0));rhi=np.minimum(1,np.max(ratios,axis=0))
    rlo=np.where((nl<=1e-12)[:,None],-1,rlo);rhi=np.where((nl<=1e-12)[:,None],1,rhi)
    tlo=np.maximum(0,np.stack([rlo[:,0],-rhi[:,0],rlo[:,1],-rhi[:,1]],axis=1))
    thi=np.maximum(0,np.stack([rhi[:,0],-rlo[:,0],rhi[:,1],-rlo[:,1]],axis=1))
    gaplo=np.stack([R.HX-hi[:,0]-R.R,R.HX+lo[:,0]-R.R,R.HZ-hi[:,1]-R.R,R.HZ+lo[:,1]-R.R],axis=1)
    gaphi=np.stack([R.HX-lo[:,0]-R.R,R.HX+hi[:,0]-R.R,R.HZ-lo[:,1]-R.R,R.HZ+hi[:,1]-R.R],axis=1)
    plo=(45+15*tlo*tlo)*np.exp(-(np.maximum(gaphi,0)*12.5)**1.2)
    phi=(45+15*thi*thi)*np.exp(-(np.maximum(gaplo,0)*12.5)**1.2)
    maxlo=plo.max(axis=1);elo=[];ehi=[]
    for main in range(4):
        possible=phi[:,main]>=maxlo
        other=[2,3] if main<2 else [0,1]
        elo.append(np.where(possible,100-phi[:,main]-np.minimum(8,.25*phi[:,other].max(axis=1)),np.inf))
        ehi.append(np.where(possible,100-maxlo-np.minimum(8,.25*plo[:,other].max(axis=1)),-np.inf))
    Elo=np.min(elo,axis=0);Ehi=np.max(ehi,axis=0)
    plateau,decay=min(15,9/length),min(20,20*math.sqrt(.6/length))
    def angular(cut):return 100*np.exp(-(np.maximum(cut-plateau,0)/decay)**2)
    Alo,Ahi=angular(cuthi),angular(cutlo)
    lower=.5*np.minimum(np.minimum(Dlo,Elo),Alo)+.5*np.cbrt(Dlo*Elo*Alo)
    upper=.5*np.minimum(np.minimum(Dhi,Ehi),Ahi)+.5*np.cbrt(Dhi*Ehi*Ahi)
    definitely_invalid=(dh<2*R.R)|(nh<=1e-9)|(dothi<=1e-12)
    possibly_invalid=(dl<2*R.R)|(nl<=1e-9)|(dotlo<=1e-12)
    return np.where(possibly_invalid,0,np.maximum(0,lower-EPS)),np.where(definitely_invalid,0,np.minimum(100,upper+EPS))

def segment_distance(p,a,b):
    a=np.asarray(a);b=np.asarray(b);v=b-a
    vv=np.sum(v*v,axis=-1)
    t=np.sum((np.asarray(p)-a)*v,axis=-1)/np.maximum(vv,1e-100)
    return np.linalg.norm(a+np.clip(t,0,1)[...,None]*v-p,axis=-1)

def assess_points(points,ball,aim,third):
    points=np.asarray(points);f2=R.evaluate(points,ball,aim)[:,3]
    valid=np.isfinite(f2)&(f2>=85)
    if not valid.any():return None
    q=points[valid];f2=f2[valid]
    f3=np.stack([np.nan_to_num(R.evaluate(q,third,a)[:,3],nan=0.) for a in R.ANCHORS[M.pockets(third)]],axis=1)
    best=f3.max(axis=1);p3=np.array(M.pockets(third))[f3.argmax(axis=1)]
    ghost=np.array(ball)-2*R.R*(np.array(aim)-ball)/np.linalg.norm(np.array(aim)-ball)
    overlap=np.linalg.norm(q-third,axis=1)<2*R.R
    block=segment_distance(third,q,ghost)<2*R.R
    bad=(f2<=best)|overlap|block
    if not bad.any():return None
    candidates=np.flatnonzero(bad);idx=candidates[np.argmin((f2-best)[bad])]
    reason='cue_overlap' if overlap[idx] else 'blocks_second_cue_path' if block[idx] else 'third_not_harder_in_region'
    return dict(reason=reason,cue=q[idx].tolist(),score2=float(f2[idx]),score3=float(best[idx]),bestPocket3=int(p3[idx]))

def certify(ball,aim,third):
    boxes=np.array([[-R.HX+R.R,-R.HZ+R.R,R.HX-R.R,R.HZ-R.R]])
    ghost=np.array(ball)-2*R.R*(np.array(aim)-ball)/np.linalg.norm(np.array(aim)-ball)
    examined=0;certified=0;smallest_margin=math.inf;unresolved=[];max_active=0
    for depth in range(17):
        examined+=len(boxes);max_active=max(max_active,len(boxes))
        low2,up2=bounds(boxes,ball,aim)
        mask=up2>=85;boxes=boxes[mask];low2=low2[mask]
        if not len(boxes):break
        center=(boxes[:,:2]+boxes[:,2:])/2
        witness=assess_points(center,ball,aim,third)
        if witness:return dict(status='rejected',witness=witness,examined=examined)
        upper3=np.maximum.reduce([bounds(boxes,third,a)[1] for a in R.ANCHORS[M.pockets(third)]])
        margin=np.maximum(85,low2)-upper3
        radius=np.linalg.norm((boxes[:,2:]-boxes[:,:2])/2,axis=1)
        clear=(segment_distance(third,center,ghost)-radius>=2*R.R+EPS)&(np.linalg.norm(center-third,axis=1)-radius>=2*R.R+EPS)
        done=(margin>EPS)&clear
        if done.any():smallest_margin=min(smallest_margin,float(margin[done].min()))
        certified+=int(done.sum());boxes=boxes[~done]
        if not len(boxes):break
        widths=np.max(boxes[:,2:]-boxes[:,:2],axis=1)
        tiny=widths<=.0001
        if tiny.any():unresolved.extend(boxes[tiny].tolist());boxes=boxes[~tiny]
        if not len(boxes):break
        if len(boxes)>200000:
            unresolved.extend(boxes.tolist());boxes=boxes[:0];break
        lo,hi=boxes[:,:2],boxes[:,2:];mid=(lo+hi)/2
        boxes=np.concatenate([np.column_stack([lo,mid]),np.column_stack([mid,hi]),np.column_stack([lo[:,0],mid[:,1],mid[:,0],hi[:,1]]),np.column_stack([mid[:,0],lo[:,1],hi[:,0],mid[:,1]])])
    else:unresolved.extend(boxes.tolist())
    return dict(status='unresolved' if unresolved else 'bounded_pass',examined=examined,certifiedBoxes=certified,maxActive=max_active,minConservativeMargin=None if smallest_margin==math.inf else smallest_margin,unresolvedCount=len(unresolved),unresolvedExample=unresolved[:4])

def run_group(job):
    s,region=job;started=time.monotonic();ball=np.array(s['second']);aim=np.array(region['aim'])
    eligible=[r['rank'] for r in region['stops'] if r['inside']]
    x=np.arange(-R.HX+R.R,R.HX-R.R,.01);z=np.arange(-R.HZ+R.R,R.HZ-R.R,.01)
    xx,zz=np.meshgrid(x,z);points=np.stack([xx.ravel(),zz.ravel()],axis=1)
    f=R.evaluate(points,ball,aim)[:,3];points=points[np.isfinite(f)&(f>=85)]
    points=np.concatenate([points,np.array([r['position'] for r in region['stops']]),np.array(region['levels'][0]['loops'][0][::4])])
    raw=read(OLD/f"sample-{s['number']}.json");results=[]
    for c in raw['candidates']:
        result=dict(candidate=c['id'])
        if opening(raw['sample'],c)[0]:result['status']='initial_rejected'
        elif not eligible:result['status']='no_new85_first_route'
        elif segment_distance(c['position'],ball,aim)<2*R.R:
            result.update(status='rejected',witness=dict(reason='blocks_second_target_path',cue=next(t['position'] for t in region['stops'] if t['inside'])))
        else:
            witness=assess_points(points,ball,aim,np.array(c['position']))
            if witness:result.update(status='rejected',witness=witness,stage='counterexample_scan')
            else:result.update(certify(ball,aim,np.array(c['position'])))
        results.append(result)
    return dict(sample=s['number'],pocket=region['pocket'],eligibleRanks=eligible,results=results,seconds=time.monotonic()-started)

def validate_bounds():
    rng=np.random.default_rng(2026102702);max_violation=0.;count=0
    source=read(REG/'data.json')
    for s in source['samples']:
        # Includes other target placements, mixed-validity boxes, all six aims.
        for ball in [s['second'],[-.8,.4],[.6,-.4]]:
            centers=rng.uniform([-R.HX+R.R,-R.HZ+R.R],[R.HX-R.R,R.HZ-R.R],size=(500,2))
            sizes=10**rng.uniform(-5,-.1,size=(500,2))
            lo=np.maximum(centers-sizes,[-R.HX+R.R,-R.HZ+R.R]);hi=np.minimum(centers+sizes,[R.HX-R.R,R.HZ-R.R]);box=np.column_stack([lo,hi])
            for aim in R.ANCHORS:
                lower,upper=bounds(box,ball,aim)
                for weights in [np.array([0,0]),np.array([1,1]),np.array([0,1]),np.array([1,0]),rng.random((500,2))]:
                    actual=np.nan_to_num(R.evaluate(lo+(hi-lo)*weights,ball,aim)[:,3],nan=0.)
                    violation=float(max(np.max(lower-actual),np.max(actual-upper)))
                    max_violation=max(max_violation,violation);assert violation<=1e-10,(ball,aim,violation)
                    count+=len(actual)
    return dict(points=count,maxViolation=max_violation)

def main():
    OUT.mkdir(parents=True,exist_ok=True);started=time.monotonic();data=read(REG/'data.json')
    assert sha(R.SOURCE)==data['audit']['native']['sourceSHA256']
    validation=validate_bounds();jobs=[(s,r) for s in data['samples'] for r in s['regions']]
    results=[]
    with ProcessPoolExecutor(max_workers=4) as pool:
        for result in pool.map(run_group,jobs):
            results.append(result);write(OUT/'groups-progress.json',results)
            print('GROUP',result['sample'],result['pocket'],{status:sum(c['status']==status for c in result['results']) for status in sorted({c['status'] for c in result['results']})},flush=True)
    samples=[]
    for s in data['samples']:
        raw=read(OLD/f"sample-{s['number']}.json");groups=[g for g in results if g['sample']==s['number']];positions=[]
        for c in raw['candidates']:
            checks=[dict(pocket=g['pocket'],eligibleRanks=g['eligibleRanks'],**g['results'][c['id']]) for g in groups]
            ranks=sorted({rank for q in checks if q['status']=='bounded_pass' for rank in q['eligibleRanks']})
            reasons,best=opening(raw['sample'],c)
            status='initial_rejected' if reasons else 'region_pass' if ranks else 'region_unresolved' if any(q['status']=='unresolved' for q in checks) else 'region_rejected'
            oldchains=[i for i,ch in enumerate(c['chains']) if ch['firstRank'] in ranks]
            positions.append(dict(id=c['id'],position=c['position'],status=status,eligibleRanks=ranks,checks=checks,reasons=reasons,bestInitial=best,legalPockets3=M.pockets(c['position']),oldStatus=c['status'],oldChains=len(c['chains']),retainedOldChains=oldchains))
        samples.append(dict(number=s['number'],positions=positions))
    output=dict(samples=samples,groups=results,validation=validation,seconds=time.monotonic()-started,workers=4,inputSHA={str(p.relative_to(ROOT)):sha(p) for p in [REG/'data.json',R.SOURCE,M.SOURCE,OLD/'samples.json',*[OLD/f'sample-{i}.json' for i in range(1,6)]]})
    write(OUT/'filter.json',output)
    for s in samples:print('SAMPLE',s['number'],{status:sum(c['status']==status for c in s['positions']) for status in sorted({c['status'] for c in s['positions']})},'old chains',sum(len(c['retainedOldChains']) for c in s['positions']),flush=True)
    print('FILTER DONE',output['seconds'],validation,flush=True)

if __name__=='__main__':main()
