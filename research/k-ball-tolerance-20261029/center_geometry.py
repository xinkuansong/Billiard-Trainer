"""Center-to-finite-cushion distances and explicitly defined geometric angles."""
import math,json,hashlib,ast
from collections import Counter
def angle(u,v):
 assert math.hypot(*u)>0 and math.hypot(*v)>0
 return math.degrees(math.atan2(abs(u[0]*v[1]-u[1]*v[0]),sum(a*b for a,b in zip(u,v))))
def segment_distance(p,a,b):
 v=[b[i]-a[i] for i in range(2)];den=sum(x*x for x in v);assert den>0
 t=max(0,min(1,sum((p[i]-a[i])*v[i] for i in range(2))/den))
 return math.dist(p,[a[i]+t*v[i] for i in range(2)])
def measure_all(root,ss,geo):
 assert angle([1,0],[1,0])==0 and abs(angle([1,0],[1,1])-45)<1e-10
 assert abs(segment_distance([2,1],[0,0],[1,0])-math.sqrt(2))<1e-10
 assert segment_distance([.5,.1],[0,0],[1,0])==.1
 path=root/'output/two-ball-parameter-consumer-20261026/before/QiuJi/Resources/TwoBallBank/index.json'
 boards={b['id']:b['board'] for b in json.loads(path.read_text())['layouts']};measurements={};r=geo['radius']
 for s in ss:
  seed=s['seed'];a=seed['object'];c=seed['cue'];p=geo['pockets'][seed['pocket']]['center'];rail=next(q for q in geo['rails'] if q['id']==s['railID'])
  v=[p[i]-a[i] for i in range(2)];norm=math.hypot(*v);ghost=[a[i]-2*r*v[i]/norm for i in range(2)]
  b=boards[seed['layout']];assert b['cue']==c and b['object']==a and b['pocket']==seed['pocket']
  center=segment_distance(s['B'],rail['start'],rail['end']);assert abs(center-(s['initialGap']+r))<1e-9
  alpha=angle([a[i]-c[i] for i in range(2)],v)
  measurements[s['id']]=dict(centerRailDistance=center,surfaceGap=center-r,layoutAngle=alpha,geometricPocketCenterCut=angle([ghost[i]-c[i] for i in range(2)],v),sourceGenerationAngle=b['angle'],angleBin='10-20' if alpha<20 else '20-30' if alpha<30 else '30-45' if alpha<=45 else '>45')
 previous=json.loads((root/'output/k-ball-selected-20261029/selected.json').read_text())
 def stats(rows):
  vals=[measurements[s['id']] for s in rows]
  return dict(count=len(vals),bins=dict(Counter(v['angleBin'] for v in vals)),min=min(v['layoutAngle'] for v in vals),max=max(v['layoutAngle'] for v in vals),atLeast20=sum(v['layoutAngle']>=20 for v in vals),atLeast30=sum(v['layoutAngle']>=30 for v in vals))
 prev=[x['sample'] for x in previous];unique=lambda rows:list({s['seed']['layout']:s for s in rows}.values())
 audit=dict(definitions={'layoutAngle':'angle between initial cue center→A center and A center→specified physical pocket center; straight=0; not collision cut angle','geometricPocketCenterCut':'angle between initial cue→ghost(A−2R*unit(A→pocket center)) and A→pocket center; geometric only, no throw or spin compensation','sourceGenerationAngle':'archived board.angle; generation parameter, not necessarily either measured angle','railAngle':'original pre/post cushion path vs cushion tangent, independent of potting/layout angles'},previousSelectedSamples=stats(prev),previousSelectedFormations=stats(unique(prev)),allSamples=stats(ss),allFormations=stats(unique(ss)),sourceIndexSHA256=hashlib.sha256(path.read_bytes()).hexdigest(),distanceCheck='all293 finite segment center distances equal original surface gap + exported R within1e-9m')
 return measurements,audit

_renderer=None
def render_center(root,out,s,measure,geo):
 global _renderer
 if _renderer is None:
  from PIL import Image,ImageDraw,ImageFont
  source=(root/'research/k-ball-middle-rails-20261029/render.py').read_text();tree=ast.parse(source)
  names={'font','pocket_label','reason_name','draw'}
  snippet='\n\n'.join(ast.get_source_segment(source,n) for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in names)
  old='球面离库 {r[\'initialGap\']*100:.1f} cm · 原片段角 {r[\'sourceAngle\']:.1f}°'
  new='球心距库 {measure[\'centerRailDistance\']*100:.1f} cm · 球形夹角 {measure[\'layoutAngle\']:.1f}° · 入/出库角 {r[\'sourceAngle\']:.1f}°'
  assert snippet.count(old)==1;snippet=snippet.replace(old,new)
  (out/'frozen-renderer.py').write_text(snippet)
  env=dict(Image=Image,ImageDraw=ImageDraw,ImageFont=ImageFont,math=math,FONT='/System/Library/Fonts/STHeiti Medium.ttc',colors={'cueBall':'#F5F5F1','object':'#56BFF5','kTarget':'#F6C65B'},axisnames={'inAngle':'入库前 K','outAngle':'出库后 K'},pocketnames=['左上角袋','右上角袋','左下角袋','右下角袋','上中袋','下中袋'],meta=geo,images=out/'images')
  exec(compile(snippet,'frozen-renderer.py','exec'),env);_renderer=env
 _renderer['measure']=measure;_renderer['draw'](s)
