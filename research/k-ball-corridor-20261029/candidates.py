"""2mm display raster and reproducible stratified continuous B samples in a narrow corridor."""
from pathlib import Path
import json,math,hashlib,random,collections
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/k-ball-corridor-20261029';OUT.mkdir(exist_ok=True);(OUT/'masks').mkdir(exist_ok=True)
source=ROOT/'output/k-ball-natural-review-20261029/data.json';data=json.loads(source.read_text());g=json.loads((OUT/'geometry.json').read_text());R=g['radius'];D=2*R;HALF=.45*D;STEP=.002;HX=g['length']/2;HZ=g['width']/2
W=round(g['length']/STEP);H=round(g['width']/STEP)
def segdist(p,a,b):
 d=np.array(b)-a;q=np.array(p)-a;u=np.clip(np.sum(q*d,axis=-1)/(d@d),0,1) if d@d else 0
 return np.linalg.norm(q-np.asarray(u)[...,None]*d,axis=-1)
def pathdist(p,pts):
 return np.minimum.reduce([segdist(p,a,b) for a,b in zip(pts,pts[1:])]) if len(pts)>1 else np.linalg.norm(np.array(p)-pts[0],axis=-1)
def first_hit(points,b):
 for i,(a,z) in enumerate(zip(points,points[1:])):
  dx,dz=z[0]-a[0],z[1]-a[1];qx,qz=a[0]-b[0],a[1]-b[1];aa=dx*dx+dz*dz;bb=2*(qx*dx+qz*dz);cc=qx*qx+qz*qz-D*D
  if cc<=0:return i,a
  disc=bb*bb-4*aa*cc
  if aa and disc>=0:
   u=(-bb-math.sqrt(disc))/(2*aa)
   if 0<=u<=1:return i,[a[0]+u*dx,a[1]+u*dz]
 return None
rows=[];regions=[]
for axis in ['inAngle','outAngle']:
 active={id for group in data['groups'][axis] for id in group['ids']}
 for e in data['selected']:
  if e['id'] not in active or e[axis]>45:continue
  regionID=e['id']+('-before' if axis=='inAngle' else '-after');tr=e['route']['trajectory2mm'];pts=[p[1:] for p in tr['points']];cs=tr['cushions'];ordinal=e['railOrdinal'];idx=e['pointIndex'];lo,hi=(cs[ordinal-2]['pointIndex'] if ordinal>1 else 0,idx) if axis=='inAngle' else (idx,cs[ordinal]['pointIndex'] if ordinal<len(cs) else len(pts)-1)
  leg=pts[lo:hi+1];rail=g['rails'][e['railID']];a=np.array(rail['start']);z=np.array(rail['end']);tan=(z-a)/np.linalg.norm(z-a);normal=np.array(rail['normal']);L=np.linalg.norm(z-a)
  seed=dict(layout=e['layout'],route=e['route']['comboIndex'],cue=e['board']['cue'],object=e['board']['object'],pocket=e['board']['pocket'],dir=e['route']['strikeDirection'],v=e['route']['velocity'],sx=e['route']['spinX'],sy=e['route']['spinY'])
  x0=max(0,math.floor((min(p[0] for p in leg)-HALF+HX)/STEP));x1=min(W,math.ceil((max(p[0] for p in leg)+HALF+HX)/STEP))
  y0=max(0,math.floor((min(p[1] for p in leg)-HALF+HZ)/STEP));y1=min(H,math.ceil((max(p[1] for p in leg)+HALF+HZ)/STEP))
  xx,zz=np.meshgrid(-HX+(np.arange(x0,x1)+.5)*STEP,-HZ+(np.arange(y0,y1)+.5)*STEP);grid=np.stack([xx,zz],axis=-1);flat=grid.reshape(-1,2)
  def valid(p,elig=True):
   p=np.asarray(p);delta=p-a;along=delta@tan;gap=delta@normal-R
   ok=(along>=0)&(along<=L)&(gap>=0)&(gap<=.15)&(pathdist(p,leg)<=HALF)
   ok &= (np.abs(p[...,0])<=HX-R)&(np.abs(p[...,1])<=HZ-R)
   if elig:
    for pocket in g['pockets']:
     lip=pocket['lip'];pd=np.minimum.reduce([segdist(p,lip[j],lip[(j+1)%len(lip)]) for j in range(len(lip))]);ok &= pd>=.30
    for center in [seed['cue'],seed['object']]:ok &= np.linalg.norm(p-center,axis=-1)>D+.002
    # Before this local leg, the cue must not already meet B. Keep the two K groups distinct.
    ok &= pathdist(p,pts[:lo+1])>D+.002
    ok &= segdist(p,seed['cue'],pts[0])>D+.002
   return ok
  raw=valid(flat,False);eligible=valid(flat,True)
  rgba=np.zeros((H,W,4),dtype=np.uint8);crop=rgba[y0:y1,x0:x1].reshape(-1,4)
  # reshape of a crop can copy; fill a separate patch then assign explicitly.
  patch=np.zeros((len(flat),4),dtype=np.uint8);patch[raw]=[74,181,222,100];patch[eligible]=[94,222,143,175];rgba[y0:y1,x0:x1]=patch.reshape(y1-y0,x1-x0,4)
  Image.fromarray(rgba).save(OUT/'masks'/f'{regionID}.png')
  randomSeed=int(hashlib.sha256(('20261029/'+regionID).encode()).hexdigest()[:16],16);rng=random.Random(randomSeed);chosen=[];bands=[]
  gaps=(flat-a)@normal-R
  for k in range(3):
   indices=np.flatnonzero(eligible&(gaps>=k*.05)&(gaps<=(k+1)*.05)).tolist();rng.shuffle(indices);n=0
   for index in indices:
    p=(flat[index]+np.array([rng.uniform(-STEP/2,STEP/2),rng.uniform(-STEP/2,STEP/2)])).tolist()
    actualGap=float((np.array(p)-a)@normal-R)
    if not k*.05<=actualGap<=(k+1)*.05:continue
    if not valid(np.array([p]))[0] or any(math.dist(p,q['B'])<.03 for q in chosen):continue
    hit=first_hit(pts,p)
    if not hit or not lo<=hit[0]<hi:continue
    row=dict(id=f"C{len(rows)+len(chosen)+1:03d}",regionID=regionID,sourceID=e['id'],sourceKey=e['key'],axis=axis,railOrdinal=ordinal,railID=e['railID'],expectedRails=ordinal-(axis=='inAngle'),seed=seed,B=p,tangent=tan.tolist(),initialGap=float((np.array(p)-a)@normal-R),sourceAngle=e[axis],proposedContact=hit[1],gapBand=k,localNumber=len(chosen)+1)
    chosen.append(row);n+=1
    if n==2:break
   bands.append(n)
  rows+=chosen
  regions.append(dict(id=regionID,sourceID=e['id'],sourceKey=e['key'],axis=axis,railOrdinal=ordinal,railID=e['railID'],sourceAngle=e[axis],seed=seed,points=pts,lo=lo,hi=hi,mask=f'masks/{regionID}.png',rawAreaM2=float(raw.sum()*STEP*STEP),eligibleAreaM2=float(eligible.sum()*STEP*STEP),randomSeed=randomSeed,bands=bands,sampleIDs=[r['id'] for r in chosen]))
(OUT/'candidates.json').write_text(json.dumps(rows));(OUT/'regions.json').write_text(json.dumps(regions))
(OUT/'candidate-audit.json').write_text(json.dumps(dict(sourceSHA256=hashlib.sha256(source.read_bytes()).hexdigest(),geometrySHA256=hashlib.sha256((OUT/'geometry.json').read_bytes()).hexdigest(),displayGridMeters=STEP,fullCorridorWidth=.9*D,maxSurfaceGap=.15,minPocketLipDistance=.30,provisionalMaxSourceAngle=45,count=len(rows),regions=len(regions),sampling='Seeded random cell selection plus uniform cell jitter; 2 points per gap band, minimum separation 3cm; sparse regions may have fewer.'),indent=2))
print('CORRIDORS',len(regions),'CANDIDATES',len(rows),'BY GROUP',collections.Counter(r['axis'] for r in rows),flush=True)
