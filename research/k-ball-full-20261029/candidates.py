"""Deterministic B proposals from archived corridors; no physics claims."""
from pathlib import Path
import collections, hashlib, json, math, sqlite3
import numpy as np
from scan import ROOT, OUT, sha


def segment_dist(p,a,b):
    a,b=np.asarray(a),np.asarray(b);v=b-a;den=v@v
    t=np.clip(np.sum((p-a)*v,axis=-1)/den,0,1) if den else np.zeros(p.shape[:-1])
    return np.linalg.norm(p-a-t[...,None]*v,axis=-1)


def path_dist(p,points):
    return np.minimum.reduce([segment_dist(p,a,b) for a,b in zip(points,points[1:])]) if len(points)>1 else np.linalg.norm(p-points[0],axis=-1)


def first_hit(points,b,diameter):
    for i,(a,z) in enumerate(zip(points,points[1:])):
        d=np.array(z)-a;q=np.array(a)-b;aa=d@d;bb=2*(q@d);cc=q@q-diameter**2
        if cc<=0:return i
        disc=bb*bb-4*aa*cc
        if aa and disc>=0 and 0<=(-bb-math.sqrt(disc))/(2*aa)<=1:return i
    return None


def proposals(route,reg,g):
    pts=np.array([p[1:] for p in route['route']['trajectory2mm']['points']]);seed=route['seed']
    r=g['radius'];diameter=2*r;half=.45*diameter;rail=g['rails'][reg['railID']]
    a,b=np.array(rail['start']),np.array(rail['end']);normal=np.array(rail['normal']);tangent=(b-a)/np.linalg.norm(b-a)
    leg=pts[reg['lo']:reg['hi']+1];segments=[];weights=[]
    for p,q in zip(leg,leg[1:]):
        # Clip the proposal centerline to the rail band expanded by the corridor radius.
        da=(p-a)@normal;db=(q-a)@normal;u0,u1=0.,1.
        if abs(db-da)<1e-15:
            if not r-half<=da<=.1+half:continue
        else:
            t0,t1=sorted(((r-half-da)/(db-da),(.1+half-da)/(db-da)))
            u0,u1=max(0,t0),min(1,t1)
            if u0>=u1:continue
        p0,p1=p+u0*(q-p),p+u1*(q-p);length=np.linalg.norm(p1-p0)
        if length>1e-9:segments.append((p0,p1));weights.append(length)
    if not segments:return []
    randomseed=int(hashlib.sha256(('k-full-v1/'+reg['key']).encode()).hexdigest()[:16],16)
    rng=np.random.default_rng(randomseed);seg=np.array(segments);n=1024
    which=rng.choice(len(seg),n,p=np.array(weights)/sum(weights));u=rng.random(n);offset=rng.uniform(-half,half,n)
    starts,ends=seg[which,0],seg[which,1];d=ends-starts;unit=d/np.linalg.norm(d,axis=1)[:,None]
    points=starts+u[:,None]*d+offset[:,None]*np.stack([-unit[:,1],unit[:,0]],axis=1)
    center=segment_dist(points,a,b);along=(points-a)@tangent;depth=(points-a)@normal
    valid=(center<=.1)&(depth>=r)&(along>=0)&(along<=np.linalg.norm(b-a))
    valid&=(np.abs(points[:,0])<=g['length']/2-r)&(np.abs(points[:,1])<=g['width']/2-r)
    for pocket in g['pockets']:
        lip=pocket['lip'];valid&=np.minimum.reduce([segment_dist(points,p,lip[(j+1)%len(lip)]) for j,p in enumerate(lip)])>=.30
    for p in (seed['cue'],seed['object']):valid&=np.linalg.norm(points-p,axis=1)>diameter+.002
    valid&=path_dist(points,pts[:reg['lo']+1])>diameter+.002
    valid&=segment_dist(points,seed['cue'],pts[0])>diameter+.002
    chosen=[]
    # Seeded proposals; central paths first, then spread along the band.
    for ix in sorted(np.flatnonzero(valid),key=lambda i:(abs(offset[i]),int(i))):
        p=points[ix].tolist()
        if any(math.dist(p,c['B'])<.03 for c in chosen):continue
        hit=first_hit(pts,p,diameter)
        if hit is None or not reg['lo']<=hit<reg['hi']:continue
        assert path_dist(np.array([p]),leg)[0]<=half+1e-12
        chosen.append(dict(id=hashlib.sha256((reg['key']+f'/{int(ix)}').encode()).hexdigest()[:20],B=p,centerRailDistance=float(center[ix]),corridorOffset=float(abs(offset[ix])),randomSeed=str(randomseed),**reg))
        if len(chosen)==6:break
    return chosen


def run():
    assert json.loads((OUT/'scan-audit.json').read_text())['complete']
    dest=OUT/'jobs.jsonl'
    if dest.exists():raise RuntimeError('Candidate output already exists; retained.')
    db=sqlite3.connect(OUT/'pool.sqlite');g=json.loads((OUT/'geometry.json').read_text());counts=collections.Counter();reasons=collections.Counter()
    with dest.open('w') as f, (OUT/'candidate-regions.jsonl').open('w') as audit:
        for number,(key,data) in enumerate(db.execute('SELECT key,data FROM routes ORDER BY key')):
            route=json.loads(data);byaxis=collections.defaultdict(list)
            for (raw,) in db.execute('SELECT data FROM regions WHERE route=? ORDER BY key',(key,)):
                reg=json.loads(raw);ps=proposals(route,reg,g)
                audit.write(json.dumps(dict(region=reg,proposals=ps))+'\n');counts['regions']+=1
                if not ps:reasons['noLegalBInSampledCorridor']+=1
                byaxis[reg['axis']].append(ps)
            jobs=[]
            for axis,sets in byaxis.items():
                # Round-robin cushions, with a bounded four alternatives per route/timing.
                options=[]
                for i in range(6):
                    for ps in sets:
                        if len(ps)>i:
                            p=ps[i]
                            if not any(math.dist(p['B'],q['B'])<.03 and p['railID']==q['railID'] for q in options):options.append(p)
                    if len(options)>=4:break
                options=options[:4]
                if options:jobs.append(dict(axis=axis,candidates=options));counts[axis]+=1;counts['candidates']+=len(options)
            if jobs:
                f.write(json.dumps(dict(key=key,seed=route['seed'],groups=jobs))+'\n');counts['routes']+=1
            if number%500==0:print('CANDIDATES',number+1,dict(counts),flush=True)
    db.close()
    protocol=json.loads((ROOT/'output/k-ball-tolerance-20261029/protocol.json').read_text())
    protocol={k:protocol[k] for k in ('levels','probes','dimensions','jointDesign')}
    protocol.update(version='k-full-v1',success='first cue contact A; A in specified pocket; cue subsequently contacts B; scratch recorded but ignored',quota='one before and one after per source layout/route; no substitute if absent',candidateLimitPerTiming=4,earlyExit='Stop failed level on first failed axis or seventh failed joint. Higher levels skipped once failed; cumulative grade is exact for this protocol. Stop candidate search after a medium-or-better candidate; choose best sensitive fallback if needed.',sourceJobSHA256=sha(dest),candidateAuditSHA256=sha(OUT/'candidate-regions.jsonl'))
    (OUT/'protocol.json').write_text(json.dumps(protocol,ensure_ascii=False,indent=2))
    summary=dict(counts=dict(counts),rejections=dict(reasons),allRoutesVisited=number+1,scriptSHA256=sha(Path(__file__)),complete=True)
    (OUT/'candidate-summary.json').write_text(json.dumps(summary,indent=2));print(summary,flush=True)


if __name__=='__main__':
    assert np.allclose(segment_dist(np.array([[.5,1],[-1,0],[2,0]]),[0,0],[1,0]),[1,1,1])
    assert first_hit([[0,0],[1,0]],[.5,0],.1)==0
    assert first_hit([[0,0],[1,0]],[.5,.2],.1) is None
    run()
