from pathlib import Path
import json,math,collections
import numpy as np
root=Path(__file__).resolve().parent
scan=json.loads((root/'scan.json').read_text());grid=json.loads((root/'grid.json').read_text());sample=json.loads((root/'sample.json').read_text())
points=np.array([g['p'] for g in grid]);aims=np.array([g['aims'] for g in grid]);R=sample['geometry']['radius'];gap=2*R+.005
rows=[r for r in scan['rows'] if r['accepted']]
def corridor(path):
 p=np.array(path);a=p[:-1];v=p[1:]-a;ll=np.sum(v*v,axis=1);ll[ll<1e-20]=1e-20
 result=np.full(len(points),np.inf)
 for j in range(0,len(a),128):
  delta=points[:,None,:]-a[None,j:j+128,:];vec=v[None,j:j+128,:];t=np.clip(np.sum(delta*vec,axis=2)/ll[None,j:j+128],0,1)
  ds=np.linalg.norm(delta-t[:,:,None]*vec,axis=2);result=np.minimum(result,ds.min(axis=1))
 return result
# Douglas-Peucker only for visual output; regions use original full paths.
def simplify(path,tol=.002):
 p=np.array(path)
 if len(p)<3:return p.tolist()
 v=p[-1]-p[0];l=np.dot(v,v)
 t=np.clip(((p-p[0])@v)/max(l,1e-20),0,1)
 d=np.linalg.norm(p-p[0]-t[:,None]*v,axis=1);i=int(d.argmax())
 if d[i]<=tol:return [p[0].tolist(),p[-1].tolist()]
 return simplify(p[:i+1],tol)[:-1]+simplify(p[i:],tol)
proof_requests=[]
# Clip the object trail at its first recorded sample inside the actual capture union;
# exclude pocket presentation and collection motion from both drawing and clearance.
pocketGeometry=sample['geometry']['pockets'][scan['pocket']]
poly=np.array([[p['x'],p['z']] for p in pocketGeometry['lip']]);center=np.array([pocketGeometry['center']['x'],pocketGeometry['center']['z']])
def captured(p):
 if np.linalg.norm(p-center)<=pocketGeometry['radius']:return True
 d=np.roll(poly,-1,axis=0)-poly;v=p-poly;cross=d[:,0]*v[:,1]-d[:,1]*v[:,0]
 return bool(np.all(cross>=-1e-9) or np.all(cross<=1e-9))
for row in rows:
 for i,p in enumerate(row['objectPath']):
  if captured(np.array(p)):
   row['objectPath']=row['objectPath'][:i+1];break
 stop=np.array(row['stop']);safe=(corridor(row['cuePath'])>gap)&(corridor(row['objectPath'])>gap)
 safe&=np.linalg.norm(points-np.array(scan['cue']),axis=1)>gap
 safe&=np.linalg.norm(points-np.array(scan['target']),axis=1)>gap
 safe&=np.linalg.norm(points-stop,axis=1)>gap
 regions=[]
 for k in range(6):
  if k==scan['pocket']:regions.append(None);continue
  n=aims[:,k,:]-points;n/=np.linalg.norm(n,axis=1)[:,None];ghost=points-2*R*n;inc=ghost-stop;inc/=np.linalg.norm(inc,axis=1)[:,None]
  angle=np.degrees(np.arctan2(n[:,0]*inc[:,1]-n[:,1]*inc[:,0],np.sum(n*inc,axis=1)))
  raw=np.where(np.abs(angle)<=20)[0];valid=raw[safe[raw]]
  pick=None
  if len(valid):
   dist=np.linalg.norm(points[valid]-stop,axis=1)
   rank=np.abs(np.abs(angle[valid])-12)+10*np.abs(dist-.65)
   pick=int(valid[np.argmin(rank)])
   proof_requests.append({'rowID':row['id'],'pocket':k,'point':points[pick].tolist(),'angle':float(angle[pick]),'v':row['v'],'sx':row['sx'],'sy':row['sy'],'direction':row['direction'],'stop':row['stop']})
  regions.append({'raw':raw.tolist(),'valid':valid.tolist(),'pick':pick,'angle':round(float(angle[pick]),2) if pick is not None else None})
 row['regions']=regions
 row['cuePath']=simplify(row['cuePath']);row['objectPath']=simplify(row['objectPath'])
for r in rows:
 for key in ('cuePath','objectPath'):
  r[key]=[[round(v,5) for v in pt] for pt in r[key]]
counts=collections.Counter(len(r['rails']) for r in scan['rows'] if r['accepted'])
data={'cue':scan['cue'],'target':scan['target'],'pocket':scan['pocket'],'effectiveAim':scan['effectiveAim'],'actualAngle':scan['actualAngle'],'rows':rows,'counts':dict(counts),'speedLevels':sorted({r['v'] for r in scan['rows']}),'trials':len(scan['rows']),'accepted':sum(counts.values()),'points':points.round(5).tolist(),'pockets':[[p['center']['x'],p['center']['z']] for p in sample['geometry']['pockets']],'radius':R,'margin':.005,'gridStep':.03}
(root/'all-visual-data.json').write_text(json.dumps(data,separators=(',',':')))
(root/'all-verify-request.json').write_text(json.dumps(proof_requests,indent=2))
print({'counts':counts,'regions':len(proof_requests),'bytes':(root/'all-visual-data.json').stat().st_size})
