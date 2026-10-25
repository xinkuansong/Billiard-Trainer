"""Independent vectorized ray/capsule/polygon audit against extracted Swift predicates."""
from prepare import *
import numpy as np
EPS=4*2**-23
def point(d):return np.array([d['x'],d['z']],float)
def check(g,origins,pockets):
 O=np.array(origins,float);pockets=np.array(pockets);aim=np.column_stack([np.zeros(len(O)),np.where(pockets==4,-1,1)*g['width']/2]);D=aim-O;D/=np.linalg.norm(D,axis=1)[:,None]
 R=g['radius'];solid=np.full(len(O),np.inf)
 def circle(c,r):
  d=O-c;b=np.sum(d*D,axis=1);disc=b*b-np.sum(d*d,axis=1)+r*r;t=-b-np.sqrt(np.maximum(0,disc))
  good=(disc>1e-14)&(t>=-EPS)&(b+np.maximum(0,t)<-1e-10)
  return np.where(good,np.maximum(0,t),np.inf)
 for line in g['lines']:
  a=point(line['start']);b=point(line['end']);e=b-a;n=np.array([-e[1],e[0]])/np.linalg.norm(e);offset=(O-a)@n;speed=D@n
  for sign in [-1,1]:
   t=np.divide(sign*R-offset,speed,out=np.full(len(O),np.inf),where=np.abs(speed)>1e-12)
   safe=np.where(np.isfinite(t),np.maximum(t,0),0);u=((O+D*safe[:,None]-a)@e)/(e@e)
   solid=np.minimum(solid,np.where((sign*speed<0)&(t>=-EPS)&(u>=0)&(u<=1),np.maximum(0,t),np.inf))
  solid=np.minimum(solid,np.minimum(circle(a,R),circle(b,R)))
 for arc in g['arcs']:
  c=point(arc['center']);rr=arc['radius'];t=circle(c,rr+R);hit=O+D*np.where(np.isfinite(t),t,0)[:,None]-c
  # Match native Float angle normalization and its existing 0.01-radian arc tolerance.
  twopi=np.float32(np.float32(np.pi)*2);angle=np.arctan2(hit[:,1],hit[:,0]).astype(np.float32)%twopi
  start=np.float32(arc['start'])%twopi;end=np.float32(arc['end'])%twopi
  inside=((angle>=start-.01)&(angle<=end+.01)) if start<=end else ((angle>=start-.01)|(angle<=end+.01))
  solid=np.minimum(solid,np.where(inside,t,np.inf))
  for a in [arc['start'],arc['end']]:solid=np.minimum(solid,circle(c+rr*np.array([np.cos(a),np.sin(a)]),R))
 captures=[]
 for pocket in g['pockets']:
  # Capture plane uses Float input positions/direction in the original native API.
  P=O.astype(np.float32).astype(float);V=D.astype(np.float32).astype(float)
  c=point(pocket['center']);d=P-c;aa=np.sum(V*V,axis=1);bb=np.sum(d*V,axis=1);disc=bb*bb-aa*(np.sum(d*d,axis=1)-pocket['radius']**2)
  t=(-bb-np.sqrt(np.maximum(0,disc)))/aa;t=np.where((disc>=0)&(t>1e-6),t,np.inf)
  poly=np.array([point(x) for x in pocket['lip']]);low=np.zeros(len(O));high=np.full(len(O),np.inf);ok=np.ones(len(O),bool)
  for a,b in zip(poly,np.roll(poly,-1,axis=0)):
   e=b-a;off=e[0]*(P[:,1]-a[1])-e[1]*(P[:,0]-a[0]);v=e[0]*V[:,1]-e[1]*V[:,0]
   cross=np.divide(-off,v,out=np.zeros(len(O)),where=np.abs(v)>1e-15)
   low=np.where(v>1e-15,np.maximum(low,cross),low);high=np.where(v< -1e-15,np.minimum(high,cross),high);ok &= (np.abs(v)>1e-15)|(off>=0)
  lip=np.where(ok&(low<=high)&(low>0),low,np.inf);captures.append(np.minimum(t,lip))
 caps=np.array(captures).T;cap=caps[np.arange(len(O)),pockets];others=caps.copy();others[np.arange(len(O)),pockets]=np.inf;other=others.min(axis=1)
 return np.isfinite(cap)&(solid+EPS>=cap)&(other+EPS>=cap),cap,solid,other
if __name__=='__main__':
 t=time.perf_counter();g=read(OUT/'geometry.json');proofs=read(OUT/'geometry-proofs.json');requests=read(OUT/'requests.json')
 assert len(proofs)==len(requests) and len({p['key'] for p in proofs})==len(proofs)
 for p,q in zip(proofs,requests,strict=True):
  assert all(p[k]==q[k] for k in ('key','object','pocket')) and key(q['object'],q['pocket'])==p['key']
 O=[p['object'] for p in proofs];pockets=[p['pocket'] for p in proofs]
 passed,cap,solid,other=check(g,O,pockets);native=np.array([p['passed'] for p in proofs]);mismatches=np.flatnonzero(native!=passed)
 assert len(mismatches)==0,[(int(i),proofs[i],float(cap[i]),float(solid[i])) for i in mismatches[:10]]
 nativecap=np.array([p.get('captureDistance',np.inf) for p in proofs]);diff=np.abs(nativecap-cap);finite=np.isfinite(diff);maxdiff=float(diff[finite].max());assert maxdiff<2e-5
 # Exact X symmetry and paired Z/pocket reflection over every B request.
 for axis in [0,1]:
  mirror=np.array(O);mirror[:,axis]*=-1;mp=np.array(pockets) if axis==0 else 9-np.array(pockets)
  mirrorpass,*_=check(g,mirror,mp);assert np.array_equal(mirrorpass,passed)
 canonical=[[0,0],[.8,-.59],[-.8,-.59],[.8,.59],[0,.3]];cp=[4,4,4,5,4]
 cpass,*_=check(g,canonical,cp);assert cpass.tolist()==[True,False,False,False,True]
 write(OUT/'geometry-audit.json',dict(passed=True,requests=len(proofs),keptPairs=int(passed.sum()),blockedPairs=int((~passed).sum()),nativeVectorizedParity=True,exactRequestRoundtrip=True,mirrorChecks=2*len(proofs),canonicalChecks=5,maxCaptureDistanceDifferenceMeters=maxdiff,seconds=time.perf_counter()-t,proofsSHA256=sha(OUT/'geometry-proofs.json'),requestsSHA256=sha(OUT/'requests.json')))
 print((OUT/'geometry-audit.json').read_text())
