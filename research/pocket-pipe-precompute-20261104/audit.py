from pathlib import Path
import json,math,hashlib,statistics,time,struct
from lookup import PipeGrid
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/pocket-pipe-precompute-20261104'
raw=json.loads((OUT/'grid-raw.json').read_text());holdouts=json.loads((OUT/'holdouts.json').read_text());grid=PipeGrid(OUT)
summary=json.loads((OUT/'summary.json').read_text());nx,nz=len(grid.x),len(grid.z)
assert len(raw['cells'])==nx*nz
assert summary['openEdges']==0,summary
maxQuant=0.;positive=zero=multi=isolated=0;maxMirror=0.
for point,options in enumerate(raw['cells']):
 ix,iz=divmod(point,nz)
 for p in range(6):
  actual,flags=grid.record(ix,iz,p)
  if not options:assert flags==0 and not actual;continue
  expected=options[p]['intervals'];assert len(actual)==len(expected)
  if flags&7!=7:continue
  if not actual:zero+=1
  else:positive+=1
  if len(actual)>1:multi+=1
  if flags&8:isolated+=1
  for a,b in zip(actual,expected):
   assert a[0]<=a[1] and all(map(math.isfinite,a))
   maxQuant=max(maxQuant,abs(a[0]-b[0]),abs(a[1]-b[1]))
  for jx,jz,mp in [(nx-1-ix,iz,[1,0,3,2,4,5][p]),(ix,nz-1-iz,[2,3,0,1,5,4][p])]:
   mirror,_=grid.record(jx,jz,mp)
   assert len(mirror)==len(actual),(ix,iz,p,'mirror topology')
   for (a,b),(c,d) in zip(actual,reversed(mirror)):
    maxMirror=max(maxMirror,abs(a+d),abs(b+c))
assert maxQuant<=180*2**-23, maxQuant
assert maxMirror<=0.001,maxMirror
errors=[];widthErrors=[];counts={};falsePositive=0;examples=[];maxCase=None
rawErrors=[]
for h in holdouts:
 if not h['valid']:continue
 x,z=h['position']
 for p,truth in enumerate(h['pockets']):
  query=grid.query(x,z,p);counts[query['status']]=counts.get(query['status'],0)+1
  if query['status']=='interpolated':
   actual=truth['intervals'];pred=query['intervals']
   if len(actual)!=1:falsePositive+=1;continue
   error=max(abs(pred[0][0]-actual[0][0]),abs(pred[0][1]-actual[0][1]))
   widthError=abs(query['width']-(actual[0][1]-actual[0][0]))
   errors.append(error);widthErrors.append(widthError)
   if maxCase is None or error>maxCase['error']:maxCase={'id':h['id'],'pocket':p,'position':[x,z],'error':error}
  unguarded=grid.query(x,z,p,guarded=False)
  if unguarded['status']=='interpolated' and len(truth['intervals'])==1:
   rawErrors.append(max(abs(unguarded['intervals'][0][k]-truth['intervals'][0][k]) for k in (0,1)))
 if h['id'] in ['A','B','C']:
  examples.append({'id':h['id'],'target':h['position'],'pockets':[{'pocket':p,'directIntervals':w['intervals'],
    'directWidth':max((b-a for a,b in w['intervals']),default=0),'lookup':grid.query(x,z,p)} for p,w in enumerate(h['pockets'])]})
def stats(values):
 values=sorted(values)
 return {'count':len(values),'median':statistics.median(values),'p95':values[min(len(values)-1,int(.95*len(values)))],
         'p99':values[min(len(values)-1,int(.99*len(values)))],'max':max(values)} if values else {}
# Guard policy was fixed before reading holdouts; do not discard failed observations.
passed=summary['unresolved']==0 and falsePositive==0 and max(errors,default=0)<=0.005 and max(widthErrors,default=0)<=0.005
result={'passed':passed,'gridPoints':nx*nz,'pocketRecords':nx*nz*6,'positiveWindows':positive,'zeroWindows':zero,
 'multipleWindows':multi,'isolatedTangencies':isolated,'maxFloat32BoundaryError':maxQuant,'maxMirrorError':maxMirror,
 'holdoutPositions':len(holdouts),'queryCounts':counts,'falsePositiveTopology':falsePositive,
 'guardedBoundaryErrorsDegrees':stats(errors),'guardedWidthErrorsDegrees':stats(widthErrors),
 'unguardedBoundaryErrorsDegrees':stats(rawErrors),'worstAccepted':maxCase,
 'binaryBytes':(OUT/'pipe-grid.bin').stat().st_size,'gzipBytes':(OUT/'pipe-grid.bin.gz').stat().st_size,
 'scope':'Sampled interpolation evidence, not a continuous error guarantee; all deferred queries require exact geometry.'}
(OUT/'audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
(OUT/'abc-pipe-windows.json').write_text(json.dumps(examples,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result,ensure_ascii=False,indent=2))
assert passed,'Unresolved grid records or sampled interpolation failure; see audit.json'
