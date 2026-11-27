"""Place up to three blockers against measured alternative routes; never certify uniqueness."""
from pathlib import Path
import json,math,sys
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/kick-obstacles-20261030'
G=json.loads((ROOT/'output/kick-grid-filtered-20261030/geometry.json').read_text());R=G['radius'];D=2*R

def segdist(points,a,b):
    v=b-a;t=np.clip(((points-a)*v).sum(axis=-1)/(v*v).sum(axis=-1).clip(1e-20),0,1)
    return np.linalg.norm(points-a-t[...,None]*v,axis=-1)
def pathdist(points,track):
    tr=np.array(track)[:,1:];result=np.full(len(points),np.inf)
    for a,b in zip(tr,tr[1:]):result=np.minimum(result,segdist(points,a,b))
    return result

def direct_certificate(c,t,b):
    vt=t-c;vb=b-c;dt=np.linalg.norm(vt);db=np.linalg.norm(vb)
    if db<=D or db+D>=dt-D:return False
    delta=abs(math.atan2(vt[0]*vb[1]-vt[1]*vb[0],np.dot(vt,vb)))
    return delta+math.asin(D/dt)+1e-5 < math.asin(D/db)

def place(request,scan):
    row=request['row'];c=np.array(row['seed']['cue']);t=np.array(row['target']);ref=row['cueTrack']
    # Regular table grid plus direct-shadow candidates; all exclusions apply afterwards.
    xx=np.arange(-G['length']/2+R+.02,G['length']/2-R-.02,.025)
    zz=np.arange(-G['width']/2+R+.02,G['width']/2-R-.02,.025)
    grid=np.array([(x,z) for x in xx for z in zz]);direct=np.array([c+(t-c)*f for f in np.arange(.15,.81,.025)])
    points=np.concatenate([direct,grid])
    ok=(np.linalg.norm(points-c,axis=1)>D+.012)&(np.linalg.norm(points-t,axis=1)>D+.012)&(pathdist(points,ref)>D+.012)
    for pocket in G['pockets']:
        ok &= np.linalg.norm(points-np.array(pocket['center']),axis=1)>pocket['radius']+R+.012
        lip=np.array(pocket['lip'])
        for a,b in zip(lip,np.roll(lip,-1,axis=0)):ok &= segdist(points,a,b)>R+.012
    points=points[ok]
    directOK=np.array([direct_certificate(c,t,b) for b in points])
    if not directOK.any():return None,{'reason':'no-direct-shadow-position'}
    alts=scan['solutions'];coverage=np.zeros((len(points),len(alts)),dtype=bool)
    for j,a in enumerate(alts):coverage[:,j]=pathdist(points,a['track'])<D-.008
    # Enumerate best direct shadow starts and beam-search at most two more balls.
    starts=np.where(directOK)[0];starts=sorted(starts,key=lambda i:(-int(coverage[i].sum()),-pathdist(points[i:i+1],ref)[0],i))[:24]
    beam=[([int(i)],coverage[i].copy()) for i in starts]
    for count in range(1,4):
        complete=[(ids,cov) for ids,cov in beam if cov.all()]
        if complete:
            ids,cov=max(complete,key=lambda item:min(pathdist(points[item[0]],ref)))
            blocks=points[ids];assignments=[]
            for bi,i in enumerate(ids):
                blocked=[j for j in range(len(alts)) if coverage[i,j]]
                assignments.append({'blocker':bi+1,'blocksDirectCone':bool(directOK[i]),'blockedAlternativeCount':len(blocked),'blockedRailCounts':sorted(set(alts[j]['n'] for j in blocked))})
            return dict(request,obstacles=blocks.tolist(),placement={'referenceMinCentreDistance':float(pathdist(blocks,ref).min()),'directConeBlocked':True,'coveredAlternatives':len(alts),'assignments':assignments}),None
        nextBeam=[]
        for ids,cov in beam:
            compatible=np.ones(len(points),dtype=bool)
            for i in ids:compatible &= np.linalg.norm(points-points[i],axis=1)>D+.012
            gain=(coverage & ~cov).sum(axis=1);gain[~compatible]=0
            choices=np.argsort(-gain,kind='stable')[:8]
            for i in choices:
                if gain[i]>0:nextBeam.append((ids+[int(i)],cov|coverage[i]))
        nextBeam.sort(key=lambda item:(-int(item[1].sum()),tuple(item[0])))
        seen=set();beam=[]
        for ids,cov in nextBeam:
            key=tuple(sorted(ids))
            if key not in seen:beam.append((ids,cov));seen.add(key)
            if len(beam)>=32:break
    return None,{'reason':'needs-more-than-three-or-beam-search-exhausted','alternativeCount':len(alts),'bestCovered':max((int(x[1].sum()) for x in beam),default=0)}

if __name__=='__main__':
    source=Path(sys.argv[1]) if len(sys.argv)>1 else OUT/'requests.json'
    target=Path(sys.argv[2]) if len(sys.argv)>2 else OUT/'placed.json'
    requests=json.loads(source.read_text());placed=[];failed=[]
    for r in requests:
        scan=json.loads((OUT/(r['id']+'-scan.json')).read_text())
        p,f=place(r,scan)
        if p:placed.append(p);print(r['id'],'PLACED',len(p['obstacles']),'blocks',len(scan['solutions']),flush=True)
        else:failed.append(dict(id=r['id'],**f));print(r['id'],'REJECT',f,flush=True)
    target.write_text(json.dumps(placed));target.with_name(target.stem+'-failures.json').write_text(json.dumps(failed,indent=2))
