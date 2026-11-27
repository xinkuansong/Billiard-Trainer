"""Independent placement invariants before expensive physics generation."""
from pathlib import Path
import math,json,gzip,collections
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/bank-variants-20261101';BASE=ROOT/'output/bank-full-20261101'
g=json.loads((BASE/'geometry.json').read_text());D=2*g['radius'];cases=0
for distance in [.4,.6,1,1.6,2.5]:
 for degrees in [-35,-15,0,15,35]:
  for theta in [0,math.pi/2,math.pi,-math.pi/2]:
   a=math.radians(degrees);length=-D*math.cos(a)+math.sqrt(distance**2-(D*math.sin(a))**2)
   ghost=[-D*math.cos(theta),-D*math.sin(theta)];cue=[ghost[0]-length*math.cos(theta+a),ghost[1]-length*math.sin(theta+a)]
   assert abs(math.hypot(*cue)-distance)<1e-12
   incoming=math.atan2(ghost[1]-cue[1],ghost[0]-cue[0]);cut=math.atan2(math.sin(incoming-theta),math.cos(incoming-theta))
   assert abs(cut-a)<1e-12;cases+=1
with gzip.open(BASE/'formations.jsonl.gz','rt') as f:counts=collections.Counter(r['type'] for r in map(json.loads,f))
assert counts=={'middle':1500,'corner':2493}
maps={}
for p in [0,4]:
 maps[p]=[]
 for t in ([0,2] if p==4 else [0,1,2,3]):
  s=[-1 if t in [1,3] else 1,-1 if t in [2,3] else 1];point=[v*s[i] for i,v in enumerate(g['pockets'][p]['center'])]
  result=min(range(6),key=lambda k:math.dist(point,g['pockets'][k]['center']));maps[p].append(result)
assert set(maps[0])=={0,1,2,3} and maps[4]==[4,5]
result={'placementCases':cases,'pocketMappings':maps,'expectedOriginalMirrors':2*counts['middle']+4*counts['corner'],'passed':True}
(OUT/'preflight.json').write_text(json.dumps(result,indent=2));print(result)
# Regression: reconstructing a ray from a near-cushion Float center magnifies
# its original rounding error; the reflected Double route is the source.
import struct
f32=lambda x:struct.unpack('f',struct.pack('f',x))[0]
tree={r['id']:r for r in json.loads((BASE/'route-tree.json').read_text())};newMax=0;oldMax=0;checks=0
with gzip.open(BASE/'formations.jsonl.gz','rt') as f:
 for b in map(json.loads,f):
  q=b['seedRailPoint'];nxt=b['seedPath'][2];incoming=[q[i]-nxt[i] for i in [0,1]];norm=math.hypot(*incoming);v=[x/norm for x in incoming];v[0 if b['walls'][0]<2 else 1]*=-1
  truth=tree[b['routeID']]['reverseDirection'];assert math.dist(v,truth)<1e-12
  prior=[b['target'][i]-q[i] for i in [0,1]];norm=math.hypot(*prior);prior=[x/norm for x in prior]
  for dt in [-.03,.03]:
   pt=[f32(b['target'][i]+dt*v[i]) for i in [0,1]];old=[f32(b['target'][i]+dt*prior[i]) for i in [0,1]]
   err=abs((pt[0]-q[0])*truth[1]-(pt[1]-q[1])*truth[0]);oldErr=abs((old[0]-q[0])*truth[1]-(old[1]-q[1])*truth[0])
   assert err<2e-7;newMax=max(newMax,err);oldMax=max(oldMax,oldErr);checks+=1
assert oldMax>=2e-7
result.update(rayPerturbationCases=checks,newMaxCrossError=newMax,oldMaxCrossError=oldMax)
(OUT/'preflight.json').write_text(json.dumps(result,indent=2));print('near-rail regression',checks,newMax,oldMax)
