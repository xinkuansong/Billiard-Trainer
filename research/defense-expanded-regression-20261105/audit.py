"""Independent NumPy finite-corridor checks, using exported geometry, never Swift proof helpers.

XZ metres. Ball-to-ball center clearance 2R; ball-to-main-rail clearance R.
Dense sampling can find counterexamples; it is not a continuous blocking proof.
"""
from pathlib import Path
import collections, json, math
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/defense-expanded-regression-20261105'
rows=json.loads((OUT/'cases.json').read_text())
geometry=json.loads((OUT/'geometry.json').read_text())
r=geometry['radius'];rails=np.array(geometry['rails'])
issues=[];directions=0;closed_cases=0;route_cases=0

def cross(a,b): return a[...,0]*b[...,1]-a[...,1]*b[...,0]
def point_segment(p,a,b):
    v=b-a;den=np.sum(v*v,axis=-1)
    t=np.clip(np.sum((p-a)*v,axis=-1)/np.maximum(den,1e-30),0,1)
    return np.linalg.norm(p-a-v*t[...,None],axis=-1)
def segment_distance(a,b,c,d):
    u=b-a;v=d-c;den=cross(u,v)
    nonparallel=np.abs(den)>1e-20
    safe=np.where(nonparallel,den,1)
    t=cross(c-a,v)/safe;s=cross(c-a,u)/safe
    intersect=nonparallel&(t>=0)&(t<=1)&(s>=0)&(s<=1)
    dist=np.minimum.reduce(np.broadcast_arrays(point_segment(a,c,d),point_segment(b,c,d),point_segment(c,a,b),point_segment(d,a,b)))
    return np.where(intersect,0,dist)
def path_clear(cue,target,blockers,angles,ends):
    n=np.stack([np.cos(angles),np.sin(angles)],axis=-1)
    ghost=target-2*r*n
    finite=np.isfinite(ends).all(axis=-1)
    valid=finite&(np.sum((ghost-cue)*n,axis=-1)>1e-10)
    # Rays missing the capture region are already invalid; use a finite dummy
    # endpoint so unrelated distance operations do not propagate NaN warnings.
    ends=np.where(finite[:,None],ends,target)
    valid&=(np.abs(ghost[:,0])<=geometry['halfX']-r+1e-7)&(np.abs(ghost[:,1])<=geometry['halfZ']-r+1e-7)
    # Exclude Float capture-boundary noise; any reported counterexample has >=2um clearance.
    for blocker in blockers:
        valid&=(point_segment(blocker,cue,ghost)>=2*r+2e-6)&(point_segment(blocker,target,ends)>=2*r+2e-6)
    for a,b in rails:
        valid&=(segment_distance(cue,ghost,a,b)>=r+2e-6)&(segment_distance(target,ends,a,b)>=r+2e-6)
    return valid
def entry(target,angles,pocket):
    n=np.stack([np.cos(angles),np.sin(angles)],axis=-1)
    delta=np.array(pocket['center'])-target;projection=n@delta
    disc=projection**2-delta@delta+pocket['radius']**2
    root=np.sqrt(np.maximum(disc,0));times=np.full(len(angles),np.inf)
    for t in [projection-root,projection+root]:
        times=np.minimum(times,np.where((disc>=0)&(t>=0),t,np.inf))
    lip=np.array(pocket['lip'])
    for a,b in zip(lip,np.roll(lip,-1,axis=0)):
        edge=b-a;den=cross(n,edge);valid=np.abs(den)>1e-20;safe=np.where(valid,den,1)
        t=cross(a-target,edge)/safe;u=cross(a-target,n)/safe
        times=np.minimum(times,np.where(valid&(t>=0)&(u>=0)&(u<=1),t,np.inf))
    return target+n*times[:,None]
def envelope(target,pocket):
    delta=np.array(pocket['center'])-target;d=np.linalg.norm(delta)
    if d<=pocket['radius']:return [-math.pi,math.pi]
    base=math.atan2(delta[1],delta[0]);half=math.asin(pocket['radius']/d)
    angles=[-half,half]
    for v in np.array(pocket['lip'])-target:
        angle=math.atan2(v[1],v[0])-base;angles.append(math.atan2(math.sin(angle),math.cos(angle)))
    return [base+min(angles),base+max(angles)]

for row in rows:
    if 'effect' not in row:continue
    e=row['effect'];positions=row['positions'];cue=np.array(positions['cueBall'])
    targetkey='_'+str(e['opponentBallNumber']);target=np.array(positions[targetkey])
    blockers=[np.array(p) for k,p in positions.items() if k not in ['cueBall',targetkey] and k not in row['pocketed']]
    if e.get('fullDirectBlock') or e.get('potContactsBlocked'):
        closed_cases+=1
        for pocket,window in zip(geometry['pockets'],row['windows']):
            intervals=[[window['baseRadians']+a[k]*math.pi/180 for k in ['leftDegrees','rightDegrees']] for a in window['intervals']]
            if not intervals:intervals=[envelope(target,pocket)]
            aa=[np.linspace(lo,hi,max(1001,min(50001,int(math.ceil((hi-lo)*180/math.pi/.002))+1))) for lo,hi in intervals]
            isolated=[window['baseRadians']+d*math.pi/180 for d in window.get('isolatedDirections',[])]
            angles=np.concatenate(aa+[np.array(isolated)]);directions+=len(angles)
            ends=entry(target,angles,pocket);valid=path_clear(cue,target,blockers,angles,ends)
            if valid.any():
                at=np.flatnonzero(valid)[0]
                issues.append(dict(id=row['id'],issue='Dense full-score counterexample',angle=float(angles[at]),end=ends[at].tolist()))
    elif 'pipeRoute' in e:
        route_cases+=1
        end=np.array(e['pipeRoute']['aim']);angle=math.atan2(*(end-target)[::-1])
        # Record route clearances separately without treating zero-width tangency as a failure.
        ghost=target-2*r*np.array([math.cos(angle),math.sin(angle)])
        ballgap=min([float(min(point_segment(b,cue,ghost),point_segment(b,target,end)))-2*r for b in blockers],default=1)
        railgap=min(float(min(segment_distance(cue,ghost,a,b),segment_distance(target,end,a,b)))-r for a,b in rails)
        row['independentBallGapMM']=ballgap*1000;row['independentRailGapMM']=railgap*1000
        if ballgap < -2e-6 or railgap < -2e-6:
            issues.append(dict(id=row['id'],issue='Selected route penetrates corridor',ballGapMM=ballgap*1000,railGapMM=railgap*1000))

effects=[x['effect'] for x in rows if 'effect' in x]
summary=dict(samples=len(rows),kinds=dict(collections.Counter(x['kind'] for x in rows)),
 scored=sum(e.get('score') is not None for e in effects),fullScores=sum(e.get('score')==100 for e in effects),
 directBlocked=sum(e.get('fullDirectBlock',False) for e in effects),
 pipeBlocked=sum(e.get('potContactsBlocked',False) for e in effects),
 estimates=sum(e.get('estimateReason') is not None for e in effects),
 zeroWidthRoutes=sum(e.get('pipeRoute',{}).get('zeroWidthEstimate',False) for e in effects),
 failures=dict(collections.Counter(e['failure'] for e in effects if e.get('failure'))),
 maxScoreDelta=max(x.get('scoreDelta',0) for x in rows),
 scoreRange=[min(e['score'] for e in effects),max(e['score'] for e in effects)],
 fullScoreAuditCases=closed_cases,denseDirections=directions,selectedRoutesAudited=route_cases,
 independentIssues=issues,nativeIssues=json.loads((OUT/'issues.json').read_text()),
 timingMS={mode:{'median':float(np.median([x[mode+'Seconds']*1000 for x in rows if mode+'Seconds' in x])),
                 'p95':float(np.percentile([x[mode+'Seconds']*1000 for x in rows if mode+'Seconds' in x],95))} for mode in ['cached','exact']})
summary['passed']=not(summary['independentIssues'] or summary['nativeIssues']) and summary['scored']==800
(OUT/'audit.json').write_text(json.dumps(summary,indent=2))
(OUT/'audited-cases.json').write_text(json.dumps(rows,separators=(',',':')))
print(json.dumps(summary,indent=2))
raise SystemExit(0 if summary['passed'] else 2)
