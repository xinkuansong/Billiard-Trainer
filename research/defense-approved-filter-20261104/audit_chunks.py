"""Independently audit every metric candidate as completed chunks arrive.
Failures remain explicit quarantine records and never enter the final catalog.
"""
from pathlib import Path
import ast,hashlib,json,math,time
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/defense-approved-filter-20261104'
read=lambda p:json.loads(p.read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
geom=read(ROOT/'output/defense-t02-expand-20261104/geometry.json');R=geom['radius']
ns=dict(np=np,math=math)
tree=ast.parse((ROOT/'research/defense-reuse-20261104/audit.py').read_text());nodes=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['line_dist','jaw_dist','cross']];assert len(nodes)==3
exec(compile(ast.Module(body=nodes,type_ignores=[]),'independent-geometry-helpers','exec'),ns)
line_dist,jaw_dist,cross=[ns[k] for k in ['line_dist','jaw_dist','cross']]
manifest=read(OUT/'input-manifest.json');folder=OUT/'geometry-chunks';folder.mkdir(exist_ok=True)
fingerprint=sha(Path(__file__))
def verify(q):
 cue=np.array(q['cue']);ball=np.array(q['positions'][q['own']]);ps=[q['cue']]+q['positions'];rays=0;potrays=0;windows=0;minimum=float('inf');tiny=0
 for i,p in enumerate(ps):
  assert abs(p[0])<=geom['length']/2-R+1e-6 and abs(p[1])<=geom['width']/2-R+1e-6,'outside table'
  for other in ps[i+1:]:assert math.dist(p,other)>=2*R-1e-6,'overlapping initial balls'
 for b in q['ownAttack']['options']:
  if b['cueWidth']==0:continue
  if b['cueWidth']<=1e-6:
   tiny+=1;continue  # Same explicitly declared numerical floor as the selection protocol.
  windows+=1;g=np.array(b['ghost']);n=(ball-g)/(2*R)
  assert abs(np.linalg.norm(n)-1)<1e-10,'ghost normal length'
  direction=(g-cue)/np.linalg.norm(g-cue);cut=math.degrees(math.atan2(abs(cross(direction,n)),np.dot(direction,n)))
  assert abs(cut-b['cut'])<1e-8,'representative cut mismatch'
  a=np.array(b['leftGhost'])-cue;z=np.array(b['rightGhost'])-cue
  delta=math.atan2(float(cross(a,z)),np.dot(a,z));assert abs(abs(math.degrees(delta))-b['cueWidth'])<1e-9,'cue width mismatch'
  start=math.atan2(a[1],a[0]);base=math.atan2(geom['pockets'][b['pocket']]['center'][1]-ball[1],geom['pockets'][b['pocket']]['center'][0]-ball[0])
  for f in np.linspace(.001,.999,21):
   theta=start+delta*f;v=np.array([math.cos(theta),math.sin(theta)]);d=ball-cue;proj=np.dot(d,v);disc=(2*R)**2-float(cross(d,v))**2
   assert disc>=-1e-14,'cue ray misses first contact circle'
   contact=cue+v*(proj-math.sqrt(max(0,disc)));normal=(ball-contact)/(2*R)
   angle=math.degrees(math.atan2(math.sin(math.atan2(normal[1],normal[0])-base),math.cos(math.atan2(normal[1],normal[0])-base)))
   assert b['objectInterval'][0]-1e-5<=angle<=b['objectInterval'][1]+1e-5,'inverse departure outside stored interval'
   for j,o in enumerate(q['positions']):
    if j!=q['own']:assert line_dist(np.array([o]),cue,contact)[0]>=2*R-1e-7,'cue ray hits another ball'
   rays+=1
  for key in ['leftEnd','aim','rightEnd']:
   end=np.array(b[key]);distance=np.linalg.norm(end-ball);assert distance>1e-8,'incomplete capture endpoint'
   points=np.linspace(ball,end,max(3,math.ceil(distance/.0005)));pg=geom['pockets'][b['pocket']]
   ds=[float(jaw_dist(points,j).min()) for j in pg['jaws']]+[float(line_dist(points,r['a'],r['b']).min()) for r in pg['rails']]
   clearance=min(ds);minimum=min(minimum,clearance);assert clearance>=R-2e-6,f'jaw/rail clearance {clearance}'
   for j,o in enumerate(q['positions']):
    if j!=q['own']:assert line_dist(np.array([o]),ball,end)[0]>=2*R-2e-6,'pot ray hits another ball'
   potrays+=1
 assert windows>0,'no resolvable pocket window'
 return dict(rays=rays,potRays=potrays,windows=windows,subresolutionPocketWindows=tiny,minimumClearance=minimum)
seen=set();begun=time.time()
while len(seen)<len(manifest['chunks']):
 progress=False
 for c in manifest['chunks']:
  stem=Path(c['file']).stem
  if stem in seen:continue
  marker=OUT/f'results/{stem}-done.json'
  if not marker.exists():continue
  data=OUT/f'results/{stem}-accepted.json';done=read(marker)
  assert sha(data)==done['outputs'][str(data.relative_to(OUT))]
  dest=folder/f'{stem}.json'
  if dest.exists():
   r=read(dest);assert r['inputSHA256']==sha(data) and r['auditorSHA256']==fingerprint
  else:
   passing=[];failures=[];totals=dict(rays=0,potRays=0,windows=0,subresolutionPocketWindows=0);minimum=None
   for q in read(data):
    try:stats=verify(q)
    except AssertionError as e:
     failures.append(dict(ordinal=q['ordinal'],own=q['own'],sourceID=q['sourceID'],reason=str(e)));continue
    passing.append([q['ordinal'],q['own']]);minimum=stats['minimumClearance'] if minimum is None else min(minimum,stats['minimumClearance'])
    for k in totals:totals[k]+=stats[k]
   r=dict(inputSHA256=sha(data),auditorSHA256=fingerprint,passing=passing,quarantine=failures,totals=totals,minimumClearance=minimum)
   tmp=dest.with_suffix('.tmp');tmp.write_text(json.dumps(r,separators=(',',':')));tmp.replace(dest)
  seen.add(stem);progress=True
 if progress:
  (OUT/'geometry-progress.json').write_text(json.dumps(dict(chunks=len(seen),total=len(manifest['chunks']),seconds=time.time()-begun)))
 if len(seen)<len(manifest['chunks']):time.sleep(2)
while not (OUT/'summary.json').exists():time.sleep(1)
assert read(OUT/'geometry.json')==geom,'Frozen geometry changed'
records=[read(folder/(Path(c['file']).stem+'.json')) for c in manifest['chunks']]
summary=dict(complete=True,chunks=len(records),auditorSHA256=fingerprint,passedTargets=sum(len(r['passing']) for r in records),quarantinedTargets=sum(len(r['quarantine']) for r in records),inverseCueRayProbes=sum(r['totals']['rays'] for r in records),potRaysChecked=sum(r['totals']['potRays'] for r in records),positivePocketWindows=sum(r['totals']['windows'] for r in records),subresolutionPocketWindows=sum(r['totals']['subresolutionPocketWindows'] for r in records),minimumJawRailClearanceMeters=min(r['minimumClearance'] for r in records if r['minimumClearance'] is not None),spatialSampleStepMeters=.0005,physicalStrokesSimulated=False)
assert summary['passedTargets']+summary['quarantinedTargets']==read(OUT/'summary.json')['counts']['accepted']
(OUT/'geometry-audit.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary,indent=2))
