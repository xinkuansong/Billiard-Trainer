"""Independent ray-circle and jaw/rail clearance audit for every accepted target."""
from pathlib import Path
import json,math,gzip,hashlib,zipfile
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/defense-full-filter-20261104'
geom=json.loads((OUT/'geometry.json').read_text());R=geom['radius']
def cross(a,b):return a[0]*b[1]-a[1]*b[0]
def line_dist(points,a,b):
 a=np.array(a);b=np.array(b);v=b-a;t=np.clip(((points-a)*v).sum(axis=-1)/np.dot(v,v),0,1)
 return np.linalg.norm(points-(a+t[...,None]*v),axis=-1)
def jaw_dist(points,j):
 c=np.array(j['center']);v=points-c;ang=np.arctan2(v[:,1],v[:,0]);a=j['angleA'];d=math.atan2(math.sin(j['angleB']-a),math.cos(j['angleB']-a));off=np.arctan2(np.sin(ang-a),np.cos(ang-a));inside=(off>=-1e-10)&(off<=d+1e-10) if d>=0 else (off<=1e-10)&(off>=d-1e-10)
 ends=np.minimum(np.linalg.norm(points-(c+j['radius']*np.array([math.cos(a),math.sin(a)])),axis=1),np.linalg.norm(points-(c+j['radius']*np.array([math.cos(a+d),math.sin(a+d)])),axis=1))
 return np.minimum(np.where(inside,np.abs(np.linalg.norm(v,axis=1)-j['radius']),ends),line_dist(points,j['lineA'],j['lineB']))
count=0;options=0;raycount=0;potrays=0;minimum=float('inf');min_obstacle=float('inf')
for path in sorted((OUT/'results').glob('*-accepted.json')):
 for q in json.loads(path.read_text()):
  count+=1;cue=np.array(q['cue']);ball=np.array(q['positions'][q['own']]);ps=[q['cue']]+q['positions']
  for i,p in enumerate(ps):
   assert abs(p[0])<=geom['length']/2-R+1e-6 and abs(p[1])<=geom['width']/2-R+1e-6
   for other in ps[i+1:]:assert math.dist(p,other)>=2*R-1e-6
  for b in q['ownAttack']['options']:
   if b['cueWidth']==0:continue
   options+=1;g=np.array(b['ghost']);n=(ball-g)/(2*R)
   assert abs(np.linalg.norm(n)-1)<1e-10
   direction=(g-cue)/np.linalg.norm(g-cue);cut=math.degrees(math.atan2(abs(cross(direction,n)),np.dot(direction,n)))
   assert abs(cut-b['cut'])<1e-8
   a=np.array(b['leftGhost'])-cue;z=np.array(b['rightGhost'])-cue
   delta=math.atan2(float(cross(a,z)),np.dot(a,z));assert abs(abs(math.degrees(delta))-b['cueWidth'])<1e-9
   start=math.atan2(a[1],a[0]);base=math.atan2(geom['pockets'][b['pocket']]['center'][1]-ball[1],geom['pockets'][b['pocket']]['center'][0]-ball[0])
   # 21 evenly spaced interior cue directions in each stored positive window.
   for f in np.linspace(.001,.999,21):
    theta=start+delta*f;v=np.array([math.cos(theta),math.sin(theta)]);d=ball-cue;proj=np.dot(d,v);disc=(2*R)**2-float(cross(d,v))**2
    assert disc>=-1e-14
    contact=cue+v*(proj-math.sqrt(max(0,disc)));normal=(ball-contact)/(2*R)
    angle=math.degrees(math.atan2(math.sin(math.atan2(normal[1],normal[0])-base),math.cos(math.atan2(normal[1],normal[0])-base)))
    assert b['objectInterval'][0]-1e-5<=angle<=b['objectInterval'][1]+1e-5,(q['sourceID'],b['pocket'],angle,b['objectInterval'])
    for j,obstacle in enumerate(q['positions']):
     if j!=q['own']:assert line_dist(np.array([obstacle]),cue,contact)[0]>=2*R-1e-7
    raycount+=1
   for key in ['leftEnd','aim','rightEnd']:
    end=np.array(b[key]);points=np.linspace(ball,end,max(3,math.ceil(np.linalg.norm(end-ball)/.0005)))
    pocket=geom['pockets'][b['pocket']]
    distances=[float(jaw_dist(points,j).min()) for j in pocket['jaws']]+[float(line_dist(points,r['a'],r['b']).min()) for r in pocket['rails']]
    clearance=min(distances);minimum=min(minimum,clearance)
    assert clearance>=R-2e-6,(q['sourceID'],b['pocket'],key,clearance,R)
    for j,obstacle in enumerate(q['positions']):
     if j!=q['own']:
      separation=line_dist(np.array([obstacle]),ball,end)[0];min_obstacle=min(min_obstacle,separation)
      assert separation>=2*R-2e-6,(q['sourceID'],key,separation)
    potrays+=1
 assert count>=0
report=dict(passed=True,acceptedTargets=count,positivePocketWindows=options,inverseCueRayProbes=raycount,potRaysChecked=potrays,spatialSampleStepMeters=.0005,minimumJawRailClearanceMeters=minimum if math.isfinite(minimum) else None,minimumOtherBallSeparationMeters=min_obstacle if math.isfinite(min_obstacle) else None,physicalStrokesSimulated=False,browserVerified=False)
assert count==json.loads((OUT/'catalog-summary.json').read_text())['acceptedTargets']
(OUT/'geometry-audit.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
files=list((OUT/'catalogs').glob('*'))+[OUT/n for n in ['README.md','protocol.json','catalog-summary.json','summary.json','geometry.json','geometry-audit.json','controls-audit.json','input-manifest.json','algorithm.json','export-source-manifest.json']]
with zipfile.ZipFile(OUT/'defense-opening-catalogs.zip','w',compression=zipfile.ZIP_DEFLATED) as archive:
 for p in files:archive.write(p,p.relative_to(OUT))
