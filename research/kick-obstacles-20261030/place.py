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
    # Exact set cover on this finite position grid, conditioned on one blocker
    # covering the whole direct angular cone. Enumerate <=2 additional blockers.
    masks=[int.from_bytes(np.packbits(cov,bitorder='little').tobytes(),'little') for cov in coverage]
    full=(1<<len(alts))-1
    coverers=[np.flatnonzero(coverage[:,j]).tolist() for j in range(len(alts))]
    starts=sorted(np.flatnonzero(directOK).tolist(),key=lambda i:(-masks[i].bit_count(),i))
    def compatible(i,j):return np.linalg.norm(points[i]-points[j])>D+.012
    def rarest(mask):
        bits=[]
        while mask:
            bit=mask & -mask;bits.append(bit.bit_length()-1);mask-=bit
        return min(bits,key=lambda j:len(coverers[j]))
    answer=None;attempts=0
    for i in starts:
        remaining=full & ~masks[i]
        if not remaining:answer=[i];break
        first=sorted(coverers[rarest(remaining)],key=lambda j:-(masks[j]&remaining).bit_count())
        for j in first:
            if not compatible(i,j):continue
            rem=remaining & ~masks[j]
            if not rem:answer=[i,j];break
            for k in coverers[rarest(rem)]:
                attempts+=1
                if masks[k]&rem==rem and compatible(i,k) and compatible(j,k):answer=[i,j,k];break
            if answer:break
        if answer:break
    if answer:
        blocks=points[answer];assignments=[]
        for bi,i in enumerate(answer):
            blocked=np.flatnonzero(coverage[i]).tolist()
            assignments.append({'blocker':bi+1,'blocksDirectCone':bool(directOK[i]),'blockedAlternativeCount':len(blocked),'blockedRailCounts':sorted(set(alts[j]['n'] for j in blocked))})
        return dict(request,obstacles=blocks.tolist(),placement={'method':'finite-grid exact cover up to three, with a single direct-shadow blocker','pairChecks':attempts,'referenceMinCentreDistance':float(pathdist(blocks,ref).min()),'directConeBlocked':True,'coveredAlternatives':len(alts),'assignments':assignments}),None
    return None,{'reason':'no-up-to-three-cover-on-this-grid-with-single-direct-shadow','alternativeCount':len(alts),'pairChecks':attempts}

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
