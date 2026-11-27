from pathlib import Path
import gzip, hashlib, json, math, os, subprocess, sys, xml.etree.ElementTree as ET
from collections import Counter
import numpy as np
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2];OUT=Path(os.environ.get('DEFENSE_REVIEW_OUTPUT',str(ROOT/'output/defense-reuse-20261104')))
STRICT=os.environ.get('DEFENSE_REVIEW_STRICT')=='1'
qs=json.loads((OUT/'samples.json').read_text());geom=json.loads((OUT/'geometry.json').read_text());R=geom['radius']
summary=json.loads((OUT/'summary.json').read_text())
if STRICT:
 assert Counter(q['kind'] for q in qs)=={'one':1,'two_black':5,'two_own':5,'three':5}
 policy=json.loads((OUT/'protocol.json').read_text())
 assert [c['accepted'] for c in policy['controls']]==[True,False,False]
 for q in qs:
  assert 1e-6<q['ownAttack']['best']['cueWidth']<=policy['cueWidthLimitDegrees']
  assert max(o.get('comfort',{}).get('total',0) for o in q['ownAttack']['options'])<=policy['maxRepresentativeComfortLimit']
else:
 assert len(qs)==20 and set(Counter(q['kind'] for q in qs).values())=={5}
assert summary['searchEdgeHits']==0 and summary['windowCoarseFineMax']<.001 and summary['mappingCoarseFineMax']<.001
provenance=json.loads((OUT/'bank-provenance.json').read_text())
for name,h in provenance['files'].items():assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==h,name
inputs={q['id']:q for q in json.loads((OUT/'candidate-input.json').read_text())}
# Resolve selected coordinates back to actual bundled resources, not just copied inputs.
sources={}
sys.path.insert(0,str(ROOT/'scripts/training-question-bank'))
from pocket_geometry_filter import layouts
want={q['sourceID'] for q in qs}
for lid,c,o,p,a in layouts(json.loads((ROOT/'QiuJi/Resources/training-grid-bank.json').read_text())):
 if lid in want:sources[lid]=(list(c),[list(o)])
for name in provenance['files']:
 if not name.endswith('.gz'):continue
 raw=gzip.decompress((ROOT/name).read_bytes())
 if '/TwoBallBank/' in name:
  for row in map(json.loads,raw.splitlines()):
   for question in row['questions']:
    key=str(row['id'])+'/'+str(question['id'])
    if key in want:sources[key]=(row['board']['cue'],[row['board']['object'],question['p']])
 else:
  for row in json.loads(raw):
   if row['id'] in want:sources[row['id']]=(row['board']['cue'],[row['board']['object'],row['second'],row['third']])
assert want==set(sources)
def line_dist(points,a,b):
 a=np.array(a);b=np.array(b);v=b-a;t=np.clip(((points-a)*v).sum(axis=-1)/np.dot(v,v),0,1)
 return np.linalg.norm(points-(a+t[...,None]*v),axis=-1)
def jaw_dist(points,j):
 c=np.array(j['center']);v=points-c;ang=np.arctan2(v[:,1],v[:,0]);a=j['angleA'];d=math.atan2(math.sin(j['angleB']-a),math.cos(j['angleB']-a));off=np.arctan2(np.sin(ang-a),np.cos(ang-a));inside=(off>=-1e-10)&(off<=d+1e-10) if d>=0 else (off<=1e-10)&(off>=d-1e-10)
 ends=np.minimum(np.linalg.norm(points-(c+j['radius']*np.array([math.cos(a),math.sin(a)])),axis=1),np.linalg.norm(points-(c+j['radius']*np.array([math.cos(a+d),math.sin(a+d)])),axis=1))
 return np.minimum(np.where(inside,np.abs(np.linalg.norm(v,axis=1)-j['radius']),ends),line_dist(points,j['lineA'],j['lineB']))
def cross(a,b):return a[0]*b[1]-a[1]*b[0]
minimum=float('inf');raycount=0;maxinverse=0
for q in qs:
 src=inputs[q['id']]
 assert (q['cue'],q['positions'])==sources[q['sourceID']]
 for k in ['cue','positions','numbers','own','enemy','sourceID']:assert q[k]==src[k]
 assert sorted(q['numbers'])==dict(one=[8],two_black=[8,9],two_own=[1,8],three=[1,8,9])[q['kind']]
 ps=[q['cue']]+q['positions']
 for i,p in enumerate(ps):
  assert abs(p[0])<=geom['length']/2-R+1e-6 and abs(p[1])<=geom['width']/2-R+1e-6
  for other in ps[i+1:]:assert math.dist(p,other)>=2*R-1e-6
 for side in ['ownAttack','enemyAttack']:
  attack=q[side]; assert len(attack['options'])==6
  assert attack['best']['cueWidth']==max(o['cueWidth'] for o in attack['options'])
 b=q['ownAttack']['best'];cue=np.array(q['cue']);ball=np.array(q['positions'][q['own']]);g=np.array(b['ghost']);n=(ball-g)/(2*R)
 assert abs(np.linalg.norm(n)-1)<1e-10
 direction=(g-cue)/np.linalg.norm(g-cue);cut=math.degrees(math.atan2(abs(cross(direction,n)),np.dot(direction,n)))
 assert abs(cut-b['cut'])<1e-8
 a=np.array(b['leftGhost'])-cue;z=np.array(b['rightGhost'])-cue
 width=abs(math.degrees(math.atan2(float(cross(a,z)),np.dot(a,z))))
 assert abs(width-b['cueWidth'])<1e-9
 # Inverse independent check: ray/circle first contact -> target departure normal.
 start=math.atan2(a[1],a[0]);delta=math.atan2(float(cross(a,z)),np.dot(a,z));base=math.atan2(geom['pockets'][b['pocket']]['center'][1]-ball[1],geom['pockets'][b['pocket']]['center'][0]-ball[0])
 for f in np.linspace(.001,.999,201):
  theta=start+delta*f;v=np.array([math.cos(theta),math.sin(theta)]);d=ball-cue;proj=np.dot(d,v);disc=(2*R)**2-float(cross(d,v))**2
  assert disc>=0
  contact=cue+v*(proj-math.sqrt(disc));normal=(ball-contact)/(2*R)
  angle=math.degrees(math.atan2(math.sin(math.atan2(normal[1],normal[0])-base),math.cos(math.atan2(normal[1],normal[0])-base)))
  assert b['objectInterval'][0]-1e-5<=angle<=b['objectInterval'][1]+1e-5
  for j,obstacle in enumerate(q['positions']):
   if j!=q['own']:assert line_dist(np.array([obstacle]),cue,contact)[0]>=2*R-1e-7
  raycount+=1
 # Independent densely sampled spatial clearance for boundary and representative pot rays.
 for key in ['leftEnd','aim','rightEnd']:
  end=np.array(b[key]);points=np.linspace(ball,end,max(3,math.ceil(np.linalg.norm(end-ball)/.0001)))
  g=geom['pockets'][b['pocket']]
  distances=[float(jaw_dist(points,j).min()) for j in g['jaws']]+[float(line_dist(points,r['a'],r['b']).min()) for r in g['rails']]
  clearance=min(distances);minimum=min(minimum,clearance);assert clearance>=R-2e-6,(q['sampleID'],key,clearance)
  for j,obstacle in enumerate(q['positions']):
   if j!=q['own']:assert line_dist(np.array([obstacle]),ball,end)[0]>=2*R-2e-6
 ET.parse(OUT/(q['sampleID']+'.svg'))
 subprocess.run(['rsvg-convert','-w','300','-o',str(OUT/(q['sampleID']+'.png')),str(OUT/(q['sampleID']+'.svg'))],check=True)
page=(OUT/'review.html').read_text();assert page.count('<article ')==len(qs) and page.count('<section>')==4 and page.count('<svg ')==len(qs) and 'repeat(5,minmax(245px,1fr))' in page
assert '<script src=' not in page and '<link ' not in page
font='/System/Library/Fonts/STHeiti Medium.ttc';small=ImageFont.truetype(font,16);title=ImageFont.truetype(font,24)
im=Image.new('RGB',(1600,2850),'#f3f4ee');dr=ImageDraw.Draw(im)
dr.text((26,22),('防守严选 · 03-1双条件 · 16题 / 一颗黑八缺4题' if STRICT else '防守候选样题 · 四类各5题 · 总分待定'),font=title,fill='#20392e')
groupnames=['一颗黑八','两颗球：我方打黑八','两颗球：对方打黑八','三颗球：双方各剩一颗']
seen=Counter()
for i,q in enumerate(qs):
 row=['one','two_black','two_own','three'].index(q['kind']);col=seen[q['kind']];seen[q['kind']]+=1;x=16+col*316;y=110+row*680
 if col==0:dr.text((24,y-38),groupnames[row],font=title,fill='#284c39')
 dr.rounded_rectangle((x,y,x+304,y+630),radius=10,fill='#fffef9',outline='#dce1d5')
 drawing=Image.open(OUT/(q['sampleID']+'.png')).convert('RGBA');im.paste(drawing,(x+2,y+26),drawing)
 b=q['ownAttack']['best'];dr.text((x+12,y+8),q['sampleID'],font=small,fill='#284c39')
 dr.text((x+12,y+580),f"母球角 {b['cueWidth']:.6f}° · 袋口角 {b['objectWidth']:.2f}°",font=small,fill='#865223')
 dr.text((x+12,y+604),f"切角 {b['cut']:.1f}° · 旧舒适分 {b['comfort']['total']:.1f}",font=small,fill='#687469')
im.save(OUT/'overview.png')
report=dict(passed=True,samples=len(qs),groups=4,sourceHashes=len(provenance['files']),inverseRayProbes=raycount,minimumSpatialClearanceMeters=minimum,windowConvergenceDegrees=summary['windowCoarseFineMax'],mappingConvergenceDegrees=summary['mappingCoarseFineMax'],standaloneSVGs=len(qs),htmlCards=len(qs),browserVerified=False,safetyStrokesVerified=False,combinedScoreImplemented=False)
(OUT/'audit.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
