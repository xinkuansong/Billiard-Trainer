from pathlib import Path
from collections import Counter
from html.parser import HTMLParser
import ast,gzip,hashlib,json,math,subprocess,sys,xml.etree.ElementTree as ET
import numpy as np
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/defense-t02-expand-20261104';BASE=OUT
qs=json.loads((OUT/'samples.json').read_text());proto=json.loads((OUT/'protocol.json').read_text());geom=json.loads((OUT/'geometry.json').read_text());R=geom['radius']
assert len(qs)==24 and not proto['formalGlobalCutoffsApproved']
assert Counter(q['stage'] for q in qs)=={**{f'G{i:02}':3 for i in range(1,8)},'reference':3}
source=json.loads((BASE/'evaluated.json').read_text());lookup={q['id']:q for q in source}
assert hashlib.sha256((BASE/'evaluated.json').read_bytes()).hexdigest()==proto['sourceEvaluationSHA256']
assert hashlib.sha256((ROOT/'research/defense-reuse-20261104/build_page.py').read_bytes()).hexdigest()==proto['rendererSHA256']
assert hashlib.sha256((ROOT/'research/defense-threshold-ladder-20261104/build.py').read_bytes()).hexdigest()==proto['cardBuilderSHA256']
seen=set()
for q in qs:
 for k in ['cue','positions','own','enemy','ownAttack','enemyAttack','sourceID','originalAngle']:
  assert q[k]==lookup[q['id']][k],(q['sampleID'],k)
 # The original pilot schema did not store the generation pocket.
 assert ('originalPocket' in q)==('originalPocket' in lookup[q['id']])
 if 'originalPocket' in q:assert q['originalPocket']==lookup[q['id']]['originalPocket']
 assert .002<q['ownAttack']['best']['cueWidth']<=.008 and 4<=q['maxPocketComfort']<10
 assert abs(q['maxPocketComfort']-q['ownAttack']['best']['comfort']['total'])<1e-8
 key=min(tuple(round(v,3) for p in [q['cue'],q['positions'][q['own']]] for v in [p[0]*sx,p[1]*sz]) for sx,sz in [(1,1),(-1,1),(1,-1),(-1,-1)])
 assert key not in seen;seen.add(key)
 assert q['numbers'][q['own']]==(8 if q['kind'] in ['one','two_black'] else 1)
 assert q['numbers'][q['enemy']]==(8 if q['kind'] in ['one','two_own'] else 9)
original=json.loads((ROOT/'output/defense-threshold-ladder-20261104/samples.json').read_text())
for q in qs[:3]:
 prior=next(p for p in original if p['sampleID']==q['sampleID'])
 for k in ['cue','positions','own','enemy','numbers','ownAttack']:assert q[k]==prior[k]
provenance=json.loads((OUT/'bank-provenance.json').read_text())
for p,h in provenance['files'].items():assert hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h,p
want={q['sourceID'] for q in qs};sources={}
sys.path.insert(0,str(ROOT/'scripts/training-question-bank'));from pocket_geometry_filter import layouts
for lid,c,o,p,a in layouts(json.loads((ROOT/'QiuJi/Resources/training-grid-bank.json').read_text())):
 if lid in want:sources[lid]=(list(c),[list(o)])
for name in provenance['files']:
 if not name.endswith('.gz'):continue
 raw=gzip.decompress((ROOT/name).read_bytes())
 if '/TwoBallBank/' in name:
  for row in map(json.loads,raw.splitlines()):
   for q in row['questions']:
    key=str(row['id'])+'/'+str(q['id'])
    if key in want:sources[key]=(row['board']['cue'],[row['board']['object'],q['p']])
 else:
  for row in json.loads(raw):
   if row['id'] in want:sources[row['id']]=(row['board']['cue'],[row['board']['object'],row['second'],row['third']])
assert set(sources)==want
ns=dict(np=np,math=math)
tree=ast.parse((ROOT/'research/defense-reuse-20261104/audit.py').read_text());nodes=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['line_dist','jaw_dist','cross']];assert len(nodes)==3
exec(compile(ast.Module(body=nodes,type_ignores=[]),'previous-audit-helpers','exec'),ns)
line_dist,jaw_dist,cross=[ns[k] for k in ['line_dist','jaw_dist','cross']]
minclear=float('inf');rays=0
for q in qs:
 assert (q['cue'],q['positions'])==sources[q['sourceID']]
 assert sorted(q['numbers'])==dict(one=[8],two_black=[8,9],two_own=[1,8],three=[1,8,9])[q['kind']]
 ps=[q['cue']]+q['positions']
 for i,p in enumerate(ps):
  assert abs(p[0])<=geom['length']/2-R+1e-6 and abs(p[1])<=geom['width']/2-R+1e-6
  for other in ps[i+1:]:assert math.dist(p,other)>=2*R-1e-6
 b=q['ownAttack']['best'];cue=np.array(q['cue']);ball=np.array(q['positions'][q['own']]);g=np.array(b['ghost']);n=(ball-g)/(2*R)
 assert abs(np.linalg.norm(n)-1)<1e-10
 a=np.array(b['leftGhost'])-cue;z=np.array(b['rightGhost'])-cue
 delta=math.atan2(float(cross(a,z)),np.dot(a,z));assert abs(abs(math.degrees(delta))-b['cueWidth'])<1e-9
 start=math.atan2(a[1],a[0]);base=math.atan2(geom['pockets'][b['pocket']]['center'][1]-ball[1],geom['pockets'][b['pocket']]['center'][0]-ball[0])
 for f in np.linspace(.001,.999,201):
  theta=start+delta*f;v=np.array([math.cos(theta),math.sin(theta)]);d=ball-cue;proj=np.dot(d,v);disc=(2*R)**2-float(cross(d,v))**2;assert disc>=0
  contact=cue+v*(proj-math.sqrt(disc));normal=(ball-contact)/(2*R)
  angle=math.degrees(math.atan2(math.sin(math.atan2(normal[1],normal[0])-base),math.cos(math.atan2(normal[1],normal[0])-base)))
  assert b['objectInterval'][0]-1e-5<=angle<=b['objectInterval'][1]+1e-5
  for j,o in enumerate(q['positions']):
   if j!=q['own']:assert line_dist(np.array([o]),cue,contact)[0]>=2*R-1e-7
  rays+=1
 for key in ['leftEnd','aim','rightEnd']:
  end=np.array(b[key]);points=np.linspace(ball,end,max(3,math.ceil(np.linalg.norm(end-ball)/.0001)));pg=geom['pockets'][b['pocket']]
  ds=[float(jaw_dist(points,j).min()) for j in pg['jaws']]+[float(line_dist(points,r['a'],r['b']).min()) for r in pg['rails']]
  clearance=min(ds);minclear=min(minclear,clearance);assert clearance>=R-2e-6,(q['sampleID'],key,clearance)
  for j,o in enumerate(q['positions']):
   if j!=q['own']:assert line_dist(np.array([o]),ball,end)[0]>=2*R-2e-6
 ET.parse(OUT/(q['sampleID']+'.svg'))
 subprocess.run(['rsvg-convert','-w','330','-o',str(OUT/(q['sampleID']+'.png')),str(OUT/(q['sampleID']+'.svg'))],check=True)
class Page(HTMLParser):
 def __init__(self):super().__init__();self.ids=[];self.links=[];self.counts=Counter()
 def handle_starttag(self,tag,attrs):
  d=dict(attrs);self.counts[tag]+=1
  if 'id' in d:self.ids.append(d['id'])
  if tag=='a':self.links.append(d['href'])
  assert 'src' not in d,'Unexpected external resource'
p=Page();page=(OUT/'review.html').read_text();p.feed(page)
assert len(set(p.ids))==len(p.ids)
assert all(h.startswith('#') and h[1:] in p.ids for h in p.links)
assert p.counts['article']==24 and p.counts['svg']==24 and p.counts['section']==8 and p.counts['select']==24
assert 'repeat(3,minmax(280px,1fr))' in page
font='/System/Library/Fonts/STHeiti Medium.ttc';body=ImageFont.truetype(font,17);title=ImageFont.truetype(font,24);metric=ImageFont.truetype(font,22)
# Offline illustration sheets; explicitly not browser screenshots.
for part,stages in [('01-12',['reference','G01','G02','G03']),('13-24',['G04','G05','G06','G07'])]:
 im=Image.new('RGB',(1080,len(stages)*860+55),'#f3f4ee');dr=ImageDraw.Draw(im)
 dr.text((20,15),'T02扩展 · 容错角0.002–0.008° / 舒适分4–10',font=title,fill='#20392e')
 for r,stage in enumerate(stages):
  group=[q for q in qs if q['stage']==stage];y=65+r*860
  if stage=='reference':heading='原T02的3个对照例子'
  else:heading='新增 '+group[0]['sampleID']+'–'+group[-1]['sampleID']+' · T02范围内'
  dr.text((20,y),heading,font=title,fill='#20392e')
  for col,q in enumerate(group):
   x=12+col*356;yy=y+40;b=q['ownAttack']['best']
   dr.rounded_rectangle((x,yy,x+344,yy+798),radius=12,fill='#fffef9',outline='#dce1d5')
   dr.text((x+14,yy+13),q['sampleID']+' · 我方打'+str(q['numbers'][q['own']])+'号',font=body,fill='#294535')
   dr.text((x+14,yy+43),f"{b['cueWidth']:.6f}°   /   {q['maxPocketComfort']:.2f} 分",font=metric,fill='#aa6630')
   drawing=Image.open(OUT/(q['sampleID']+'.png')).convert('RGBA');im.paste(drawing,(x+7,yy+78),drawing)
   dr.text((x+14,yy+704),f"切角 {b['cut']:.1f}° · 母球距离 {b['cueDistance']:.2f}m",font=body,fill='#62745f')
   dr.text((x+14,yy+735),f"进袋距离 {b['potDistance']:.2f}m",font=body,fill='#62745f')
   if stage=='reference':dr.text((x+14,yy+766),q['referenceLabel'],font=body,fill='#62745f')
 im.save(OUT/f'preview-{part}.png')
report=dict(passed=True,samples=24,retainedReferences=3,added=21,T02BandSatisfied=True,distinctCueTargetGeometries=24,sourceFilesVerified=len(provenance['files']),inverseRayProbes=rays,minimumJawRailClearanceMeters=minclear,svgs=24,htmlCards=24,browserVerified=False,safetyStrokesVerified=False)
(OUT/'audit.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
