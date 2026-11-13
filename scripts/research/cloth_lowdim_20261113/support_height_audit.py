"""Independent CPU rejection-bound audit. SceneKit world XZ, +Y up, meters.
Oracle uses cross-product distance (float64) rather than production subtractive
perpendicular2; a second float32 evaluator mirrors shader arithmetic.
"""
from pathlib import Path
import json,math,argparse
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
R=.028575;BED=.8;Y=3.;H=Y-BED
rig=json.loads((ROOT/'output/render-lowdim-20261113/native-reference/generated-production-core.json').read_text())['rig']
L=[];Q=[]
for lamp in rig['panels']:
 for ix in range(8):
  for iz in range(4):
   L.append(np.array(lamp['center'])+np.array(lamp['u'])*(2*(ix+.5)/8-1)+np.array(lamp['v'])*(2*(iz+.5)/4-1))
   Q.append(math.sqrt(lamp['area']/32/math.pi))
L=np.array(L);Q=np.array(Q);S=rig['shadowSupportRadius'];M=np.linalg.norm(L[:,[0,2]],axis=-1).max();qMax=Q.max()
def bounds(b,h,y):return R+(h+R+np.maximum(0,BED-y))/np.maximum(.01,H-h-R)*(np.linalg.norm(b,axis=-1)+S)
def safe_bounds(b,h,y):
 r=R+1e-6;top=h+r;den=H-top-qMax
 return np.where(den>0,r+(top+np.maximum(0,BED-y))/np.maximum(1e-30,den)*(np.linalg.norm(b,axis=-1)+M+qMax+r),np.inf)
def oracle(p,b,h,dtype=np.float64,independent=True):
 p=p.astype(dtype);b=b.astype(dtype);h=h.astype(dtype);lp=L.astype(dtype);q=Q.astype(dtype)
 c=np.c_[b[:,0],BED+h,b[:,1]];delta=lp[None,:,:]-p[:,None,:];d=c-p;r2=np.sum(delta*delta,axis=-1);dist=np.sqrt(r2);unit=delta/dist[...,None];t=np.sum(d[:,None,:]*unit,axis=-1)
 if independent:perp=np.linalg.norm(np.cross(d[:,None,:],delta),axis=-1)/dist
 else:perp=np.sqrt(np.maximum(0,np.sum(d*d,axis=-1)[:,None]-t*t))
 fr=np.maximum(dtype(1e-6),q[None,:]*t/dist);margin=perp-(dtype(R)+fr)
 f=np.clip((perp-(dtype(R)-fr))/(2*fr),0,1);blocked=(1-f*f*(3-2*f))*((t>0)&(t*t<r2))
 margin=np.where((t>0)&(t*t<r2),margin,np.inf)
 return margin,blocked

def witness(p,b,h,i,j,margin,block):
 bd=bounds(b[i:i+1],h[i:i+1],p[i:i+1,1])[0]
 return {'p':p[i].tolist(),'ballPacked':[float(b[i,0]),float(b[i,1]),float(h[i]),.85],'sample':L[j].tolist(),'sampleIndex':int(j),'cellRadius':float(Q[j]),'candidateBound':float(bd),'receiverHorizontalDistance':float(np.linalg.norm(p[i,[0,2]]-b[i])),'supportMargin':float(margin),'blocked':float(block)}
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--out',type=Path,default=ROOT/'output/render-lowdim-20261113/support-height-audit');ap.add_argument('--n',type=int,default=200000);ap.add_argument('--safe',action='store_true');ap.add_argument('--bounded',action='store_true');a=ap.parse_args();a.out.mkdir(parents=True,exist_ok=True)
 if a.bounded:return bounded_audit(a.out,a.n)
 rng=np.random.default_rng(20261113);rows=[];bound_fn=safe_bounds if a.safe else bounds
 for domain in ['floorTiny','physicalBox','belowBroad','nearLamp','huge']:
  record={'domain':domain,'count':0,'falseNegative64':0,'falseNegative32':0,'worst':None,'minMargin':float('inf'),'withinTableFalseNegative64':0}
  for start in range(0,a.n,2000):
   n=min(2000,a.n-start);b=rng.uniform([-1.4,-.7],[1.4,.7],(n,2));theta=rng.uniform(0,2*np.pi,n)
   if domain=='floorTiny':h=np.full(n,R);y=BED-10**rng.uniform(-9,-2,n)
   elif domain=='physicalBox':h=rng.uniform(R,.6,n);y=rng.uniform(-.5,BED,n)
   elif domain=='belowBroad':h=rng.uniform(R,2,n);y=BED-10**rng.uniform(-6,3,n)
   elif domain=='nearLamp':h=H-R-10**rng.uniform(-6,-1,n);y=rng.uniform(-1,BED,n)
   else:h=rng.uniform(R,H-R-1e-6,n);y=BED-10**rng.uniform(-8,8,n)
   bd=bound_fn(b,h,y);finite=np.isfinite(bd);b=b[finite];h=h[finite];y=y[finite];theta=theta[finite];bd=bd[finite];n=len(bd)
   if n==0:continue
   d=bd*(1+10**rng.uniform(-9,-2,n));xz=b+d[:,None]*np.c_[np.cos(theta),np.sin(theta)];p=np.c_[xz[:,0],y,xz[:,1]]
   m,bl=oracle(p,b,h);m32,bl32=oracle(p,b,h,np.float32,False);bad=np.any(bl>0,axis=-1);bad32=np.any(bl32>0,axis=-1);record['count']+=n;record['falseNegative64']+=int(bad.sum());record['falseNegative32']+=int(bad32.sum());inside=(abs(p[:,0])<=1.4)&(abs(p[:,2])<=.7);record['withinTableFalseNegative64']+=int((bad&inside).sum())
   i,j=np.unravel_index(np.argmin(m),m.shape)
   if m[i,j]<record['minMargin']:record['minMargin']=float(m[i,j]);record['worst']=witness(p,b,h,i,j,m[i,j],bl[i,j]);record['worst']['testedBound']=float(bd[i])
  if not math.isfinite(record['minMargin']):record['minMargin']=None
  rows.append(record);print(json.dumps(record),flush=True)
 report={'schema':'world XZ/+Y meters; h=packed contactBall.z >=R, ball centerY=.8+h; receivers strictly outside candidate bound. p.y may be far outside actual mesh in broad cases.','boundMode':'provedSafe' if a.safe else 'proposedHeight','maxSampleHorizontalRadius':M,'sourceSupportRadius':S,'sampleCellRadius':Q[0],'rows':rows}
 (a.out/'results.json').write_text(json.dumps(report,indent=2)+'\n')

# Bounded-domain audit is callable independently: import and bounded_audit().
def float_grid():
 F=np.float32;points=[];radii=[]
 for panel in rig['panels']:
  q=F(np.sqrt(F(F(F(panel['area'])/F(32))/F(3.14159265))))
  for ix in range(8):
   for iz in range(4):
    sx=F(F(F(2)*F(F(ix)+F(.5)))/F(8)-F(1));sz=F(F(F(2)*F(F(iz)+F(.5)))/F(4)-F(1))
    points.append((np.asarray(panel['center'],dtype=F)+np.asarray(panel['u'],dtype=F)*sx)+np.asarray(panel['v'],dtype=F)*sz);radii.append(q)
 return np.asarray(points),np.asarray(radii)

def bounded_audit(out=ROOT/'output/render-lowdim-20261113/support-height-bounded',n=600000):
 out=Path(out);out.mkdir(parents=True,exist_ok=True);F=np.float32;lp,qs=float_grid();q=np.nextafter(qs.max(),F(np.inf));M=np.nextafter(F(np.linalg.norm(lp[:,[0,2]].astype(float),axis=-1).max()),F(np.inf));r=np.nextafter(F(float(F(R))+float(F(1e-6))),F(np.inf));bx=F(2.54);bz=F(1.27);rng=np.random.default_rng(11132026)
 def sb(b,h,y):
  cy=F(.8)+h;gap=((F(3)-cy)-r)-q;length=np.sqrt(np.sum(b*b,axis=-1));support=r+(((cy-y)+r)/np.maximum(gap,F(1e-30)))*(((length+M)+q)+r)
  return np.where(gap>0,support,F(np.inf))
 def eval(p,b,h,dtype,independent):
  delta=lp.astype(dtype)[None,:,:]-p.astype(dtype)[:,None,:];c=np.c_[b[:,0],F(.8)+h,b[:,1]].astype(dtype);d=c-p.astype(dtype);r2=np.sum(delta*delta,axis=-1);dist=np.sqrt(r2);t=np.sum(d[:,None,:]*(delta/dist[...,None]),axis=-1)
  if independent:perp=np.linalg.norm(np.cross(d[:,None,:],delta),axis=-1)/dist
  else:perp=np.sqrt(np.maximum(0,np.sum(d*d,axis=-1)[:,None]-t*t))
  fr=np.maximum(dtype(F(1e-6)),qs.astype(dtype)[None,:]*t/dist);u=np.clip((perp-(dtype(F(R))-fr))/(2*fr),0,1);valid=(t>0)&(t*t<r2);blocked=(1-u*u*(3-2*u))*valid;gap=perp-dtype(F(R))-fr;gap[~valid]=np.inf;return gap,blocked
 rows=[]
 for mode in ['random-boundary','collinear-boundary','independent-box']:
  rec={'mode':mode,'generated':n,'testedExcluded':0,'falseNegative64':0,'falseNegative32':0,'minimumRealSupportMargin':None,'worst':None}
  for start in range(0,n,2000):
   count=min(2000,n-start);b=rng.uniform([-bx,-bz],[bx,bz],(count,2)).astype(F);h=rng.uniform(R,2.2,count).astype(F);h[:count//2]=F(R);y=rng.uniform(0,float(F(.8)),count).astype(F);y[:count//4]=np.nextafter(F(.8),F(-np.inf));y[count//4:count//2]=F(0)
   support=sb(b,h,y)
   if mode=='independent-box':xz=rng.uniform([-bx,-bz],[bx,bz],(count,2)).astype(F)
   else:
    if mode=='collinear-boundary':li=rng.integers(0,len(lp),count);directions=b-lp[li][:,[0,2]];directions/=np.linalg.norm(directions,axis=-1,keepdims=True)
    else:theta=rng.uniform(0,2*np.pi,count);directions=np.c_[np.cos(theta),np.sin(theta)].astype(F)
    distance=support*(1+10**rng.uniform(-9,-3,count)).astype(F);xz=b+distance[:,None]*directions
   p=np.c_[xz[:,0],y,xz[:,1]].astype(F);offset=xz-b;d2=np.sum(offset*offset,axis=-1);top=h+F(R);old=F(R)+top/np.maximum(F(.01),F(2.2)-top)*(np.sqrt(np.sum(b*b,axis=-1))+F(S))
   keep=np.isfinite(support)&(y<F(.8))&(abs(xz[:,0])<=bx)&(abs(xz[:,1])<=bz)&(d2>support*support)&(d2>old*old)&(top<F(2.2));p=p[keep];b=b[keep];h=h[keep];support=support[keep]
   if not len(p):continue
   rec['testedExcluded']+=len(p);g,bl=eval(p,b,h,np.float64,True);g32,bl32=eval(p,b,h,np.float32,False);rec['falseNegative64']+=int(np.any(bl>0,axis=-1).sum());rec['falseNegative32']+=int(np.any(bl32>0,axis=-1).sum());i,j=np.unravel_index(np.argmin(g),g.shape)
   if rec['minimumRealSupportMargin'] is None or g[i,j]<rec['minimumRealSupportMargin']:
    rec['minimumRealSupportMargin']=float(g[i,j]);rec['worst']={'p':p[i].tolist(),'ball':[float(b[i,0]),float(b[i,1]),float(h[i]),.85],'sampleIndex':int(j),'safeBound':float(support[i]),'distanceXZ':float(np.linalg.norm(p[i,[0,2]].astype(float)-b[i].astype(float))),'blocked64':float(bl[i,j]),'blocked32':float(bl32[i,j])}
  rows.append(rec);print(json.dumps(rec),flush=True)
 report={'domain':{'receiverY':[0,float(F(.8))],'absReceiverXZ':[float(bx),float(bz)],'absBallXZ':[float(bx),float(bz)],'packedHeight':[R,2.2]},'constants':{'qUpper':float(q),'MUpper':float(M),'rUpper':float(r)},'oracle':'Float64 cross product of actual Float32 positions/center; Float32 subtraction source form. Every tested point is excluded by both safe helper and preserved originalInSupport OR.','rows':rows}
 (out/'results.json').write_text(json.dumps(report,indent=2)+'\n');return report

if __name__=='__main__':main()
