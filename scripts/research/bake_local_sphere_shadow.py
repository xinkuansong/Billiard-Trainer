"""Diagnostic local visibility LUTs, not production assets or an accepted moving-ball model."""
import json,sys
from pathlib import Path
import numpy as np
from scipy.ndimage import map_coordinates
from fit_local_sphere_shadow import reference,R
out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True);cases=[]
for cx,cz in [(0.,0.),(.8,.4),(-1.15,.52)]:
 for h in [R,.1]:
  ball=np.array([cx,.8+h,cz]);top=h+R
  extent=R+top/(2.2-top)*(np.hypot(cx,cz)+np.hypot(2.54,1.27))
  size=128;grid=(np.arange(size)+.5)/size*(2*extent)-extent
  xx,zz=np.meshgrid(grid,grid);xy=np.stack([xx.ravel(),zz.ravel()],axis=1)
  points=np.stack([cx+xy[:,0],np.full(len(xy),.8),cz+xy[:,1]],axis=1)
  for panel in [-.635,.635]:
   table=reference(points,ball,panel,64).reshape(size,size).astype(np.float16)
   rng=np.random.default_rng(882);vxy=np.concatenate([rng.uniform(-extent,extent,(1000,2)),rng.uniform(-.06,.06,(1000,2)),np.zeros((1,2))])
   vp=np.stack([cx+vxy[:,0],np.full(len(vxy),.8),cz+vxy[:,1]],axis=1)
   truth=reference(vp,ball,panel,128);coordinates=(vxy+extent)/(2*extent)*size-.5
   predicted=map_coordinates(table.astype(float),[coordinates[:,1],coordinates[:,0]],order=1,mode='constant',cval=0)
   errors=np.abs(predicted-truth);active=(truth>.01)|(predicted>.01);e=errors[active]
   i=len(cases);table.tofile(out/f'patch-{i}.r16f')
   row={'index':i,'ball':ball.tolist(),'panelZ':panel,'extent':float(extent),'size':size,'bytes':int(table.nbytes),'activeRMSE':float(np.sqrt(np.mean(e*e))),'activeP95':float(np.percentile(e,95)),'max':float(errors.max()),'contactReference':float(truth[-1]),'contactLookup':float(predicted[-1])}
   row['acceptedNumerically']=row['activeRMSE']<=.02 and row['activeP95']<=.05 and row['max']<=.15
   cases.append(row);print(json.dumps(row),flush=True)
(out/'lut.json').write_text(json.dumps({'scope':'12 local patches at 3 positions and 2 heights; no interpolation across positions/heights yet','coordinateSystem':'XZ horizontal, Y up, metres','cases':cases,'accepted':all(x['acceptedNumerically'] for x in cases)},indent=2))
