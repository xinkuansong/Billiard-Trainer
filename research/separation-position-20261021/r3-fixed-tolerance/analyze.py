from pathlib import Path
import json,math,numpy as np
b=Path(__file__).resolve().parent
request=json.loads((b/'request-scan.json').read_text())
sample=json.loads((b/'sample.json').read_text());scan=json.loads((b/'scan-results.json').read_text())
grid=json.loads((b.parent/'grid.json').read_text());points=np.array([g['p'] for g in grid]);aims=np.array([g['aims'][1] for g in grid]);R=sample['geometry']['radius'];gap=2*R+.005
n=aims-points;n/=np.linalg.norm(n,axis=1)[:,None];ghost=points-2*R*n

def angles(stop):
 inc=ghost-stop;inc/=np.linalg.norm(inc,axis=1)[:,None]
 return np.degrees(np.arctan2(n[:,0]*inc[:,1]-n[:,1]*inc[:,0],np.sum(n*inc,axis=1)))
def corridor(pts,path):
 if len(path)<2:return np.linalg.norm(pts-np.array(path[0]),axis=1) if path else np.full(len(pts),np.inf)
 p=np.array(path);a=p[:-1];v=p[1:]-a;ll=np.maximum(np.sum(v*v,axis=1),1e-20);result=np.full(len(pts),np.inf)
 for j in range(0,len(a),128):
  delta=pts[:,None,:]-a[None,j:j+128,:];vec=v[None,j:j+128,:];t=np.clip(np.sum(delta*vec,axis=2)/ll[None,j:j+128],0,1)
  result=np.minimum(result,np.linalg.norm(delta-t[:,:,None]*vec,axis=2).min(axis=1))
 return result

def runs(rows,predicate):
 groups=[];g=[]
 for row in rows:
  if predicate(row):g.append(row)
  else:
   if g:groups.append(g)
   g=[]
 if g:groups.append(g)
 return groups

def simplify(path,tol=.001):
 p=np.array(path)
 if len(p)<3:return p.tolist()
 vec=p[-1]-p[0];t=np.clip((p-p[0])@vec/max(vec@vec,1e-20),0,1);d=np.linalg.norm(p-p[0]-t[:,None]*vec,axis=1);i=int(d.argmax())
 if d[i]<=tol:return [p[0].tolist(),p[-1].tolist()]
 return simplify(p[:i+1],tol)[:-1]+simplify(p[i:],tol)

out=[];validation=[]
for route in request['routes']:
 rows=sorted([r for r in scan['rows'] if r['key']==route['key']],key=lambda r:r['v'])
 originalIndex=int(np.argmin(np.linalg.norm(points-np.array(route['ball2']),axis=1)))
 for row in rows:
  row['sameRoute']=row['rails']==route['rails']
  row['safe']=row['accepted'] and row['sameRoute'] and row['clearance']>.1
  row['originalAngle']=float(angles(np.array(row['stop']))[originalIndex])
  row['valid']=[]
  if row['safe']:
   a=angles(np.array(row['stop']));ids=np.where(np.abs(a)<=20)[0];p=points[ids]
   mask=(corridor(p,row['cuePath'])>gap)&(corridor(p,row['objectPath'])>gap)&(np.linalg.norm(p-np.array(row['stop']),axis=1)>gap)
   row['valid']=ids[mask].tolist()
  row['originalGood']=originalIndex in row['valid']
 safeRuns=runs(rows,lambda r:r['safe']);origRuns=runs(rows,lambda r:r['originalGood'])
 selected=max(safeRuns,key=lambda x:x[-1]['v']) if safeRuns else []
 maximum=max((r for r in rows if r['accepted'] and r['sameRoute']),key=lambda r:r['clearance'],default=None)
 record={'key':route['key'],'source':route,'originalIndex':originalIndex,'safeRuns':[[g[0]['v'],g[-1]['v']] for g in safeRuns],'originalRuns':[[g[0]['v'],g[-1]['v']] for g in origRuns],'maxClearance':{k:maximum[k] for k in ['v','clearance','stop']} if maximum else None}
 local=[r for r in selected if r['v']>=4.5-.3125]
 original=max(origRuns,key=lambda x:x[-1]['v']) if origRuns else []
 bands=[]
 for name,group in [('local',local),('original',original),('clearance',selected)]:
  common=sorted(set.intersection(*(set(r['valid']) for r in group))) if group else []
  band={'key':name,'interval':[group[0]['v'],group[-1]['v']] if group else [],'common':common,'verified':[]}
  if group:
   mid=(group[0]['v']+group[-1]['v'])/2
   band['nominal']=min(group,key=lambda r:abs(r['v']-mid))['v']
   band['minGap']=min(r['clearance'] for r in group);band['maxGap']=max(r['clearance'] for r in group)
   band['angleRange']=[min(r['originalAngle'] for r in group),max(r['originalAngle'] for r in group)]
   if common:validation.append(route|{'key':route['key']+'/'+name,'speeds':[r['v'] for r in group],'points':points[common].tolist()})
  bands.append(band)
 record['bands']=bands
 common=bands[0]['common']
 for row in rows:
  for key in ['cuePath','objectPath']:
   row[key]=[[round(x,6) for x in pt] for pt in simplify(row[key])]
 record['rows']=rows;out.append(record)
 print(route['key'],{k:v for k,v in record.items() if k not in ['rows','source']},flush=True)
data={'cases':out,'points':points.round(6).tolist(),'aims':aims.round(8).tolist(),'pockets':[[p['center']['x'],p['center']['z']] for p in sample['geometry']['pockets']],'cue':[sample['cue']['x'],sample['cue']['z']],'target':[sample['target']['x'],sample['target']['z']],'radius':R,'gridStep':.03,'speedStep':.005}
(b/'analysis.json').write_text(json.dumps(data,separators=(',',':')))
(b/'request-validate.json').write_text(json.dumps({'mode':'validate','routes':validation,'speeds':[]}))
