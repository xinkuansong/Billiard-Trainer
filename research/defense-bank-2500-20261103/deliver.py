from pathlib import Path
import ast, collections, hashlib, html, json, math, os, subprocess
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
OUT=Path(os.environ.get('DEFENSE_PILOT_OUTPUT',str(ROOT/'output/defense-bank-2500-20261103')))
geom=json.loads((OUT/'geometry.json').read_text());L,W,R=(geom[k] for k in ['length','width','radius']);CUE=geom['cueKey']
index=json.loads((OUT/'index.json').read_text());audit=json.loads((OUT/'audit.json').read_text());assert audit['passed'] and not audit['partial']
checks={r['id']:r for r in audit['checks']}
NAMES={'twoA':'两球 · 我方1号，对方8号','twoB':'两球 · 我方8号，对方9号','own':'三球 · 用1号挡','black':'三球 · 借8号挡','joint':'三球 · 两球联合挡'}
ZONES={'short':'短库附近','long':'长库附近','open':'离库开局'}
FONT='PingFang SC,Heiti SC,sans-serif';COLORS={CUE:'#fffdf5','_1':'#f9c447','_8':'#18231f','_9':'#f9c447'}
for file,names in [('research/defense-two-expand-20261103/review.py',['first','text','ball','panel','opening_label'])]:
 for node in ast.parse((ROOT/file).read_text()).body:
  if isinstance(node,ast.FunctionDef) and node.name in names:exec(compile(ast.Module(body=[node],type_ignores=[]),file,'exec'))

def zoom(q):
 ps=q['reference']['positions'];own,enemy=q['ownKey'],q['enemyKey']
 blockers=[own] if q['family'] in ['twoA','twoB','own'] else ['_8'] if q['family']=='black' else ['_1','_8']
 show=[CUE,*blockers,enemy];c,t=ps[CUE],ps[enemy];bs=[ps[k] for k in blockers]
 xs=[ps[k][0] for k in show];zs=[ps[k][1] for k in show];mx,mz=(min(xs)+max(xs))/2,(min(zs)+max(zs))/2
 scale=min(300/(max(zs)-min(zs)+.22),460/(max(xs)-min(xs)+.22))
 def project(p):return 190+(p[1]-mz)*scale,312-(p[0]-mx)*scale
 s='<rect x="27" y="56" width="326" height="525" rx="16" fill="#e7eee4"/>'
 for p in [*bs,t]:
  x,y=project(p);s+=f'<circle cx="{x}" cy="{y}" r="{2*R*scale}" fill="none" stroke="#b26450" stroke-width="1.3" stroke-dasharray="5 4"/>'
 a=math.atan2(t[1]-c[1],t[0]-c[0]);half=math.asin(2*R/math.dist(c,t))
 for f in [-1,-.5,0,.5,1]:
  angle=a+half*f;td=first(c,t,angle);bd=min(first(c,b,angle) for b in bs);assert bd<td
  end=[c[0]+td*math.cos(angle),c[1]+td*math.sin(angle)];stop=[c[0]+bd*math.cos(angle),c[1]+bd*math.sin(angle)]
  x1,y1=project(c);x2,y2=project(end);x3,y3=project(stop)
  s+=f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="#bb6858" stroke-dasharray="4 4" stroke-width="1.2"/><line x1="{x1}" y1="{y1}" x2="{x3}" y2="{y3}" stroke="#b84030" stroke-width="1.6"/>'
 for k in show:s+=ball(k,ps[k],project,scale)
 return s+text(190,611,'完整直击角域已检查，含球间缝隙',16,anchor='middle')+text(190,638,'虚线圆计入母球半径，非球体大小',14,anchor='middle')

light=[];bank=[];rows=[]
for entry in index:
 p=OUT/entry['file'];assert hashlib.sha256(p.read_bytes()).hexdigest()==audit['sourceHashes'][entry['file']]
 q=json.loads(p.read_text());rows.append(q)
 qlite={k:q[k] for k in ['id','family','zone','ownKey','enemyKey','positions','openingComfort']}
 for k in ['reference','comparison']:
  qlite[k]={key:q[k][key] for key in ['shot','positions','tracks']}
  qlite[k]['tracks']={name:[[round(x,6) for x in frame] for frame in frames] for name,frames in q[k]['tracks'].items()}
  for name,frames in q[k]['tracks'].items():
   assert max(abs(a-b) for original,rounded in zip(frames,qlite[k]['tracks'][name]) for a,b in zip(original,rounded))<=.0000005001
 qlite['stress']=checks[q['id']]['stress'];light.append(qlite)
 bank.append({**{k:q[k] for k in ['id','family','zone','ownKey','enemyKey','positions','openingComfort']},'objective':'fullStraightOcclusion','referenceFile':entry['file'],'answerSHA256':audit['sourceHashes'][entry['file']],'difficulty':None})
(OUT/'bank.json').write_text(json.dumps({'schemaVersion':1,'status':'offlineValidatedCandidate','questionCount':len(bank),'classes':NAMES,'questions':bank,'scope':'No App integration; difficulty uncalibrated'},ensure_ascii=False,separators=(',',':')))
for family,label in NAMES.items():
 subset=[q for q in bank if q['family']==family]
 assert len(subset)==500
 (OUT/f'bank-{family}.json').write_text(json.dumps({'schemaVersion':1,'status':'offlineValidatedCandidate','className':label,'questionCount':len(subset),'questions':subset},ensure_ascii=False,separators=(',',':')))
# Representative static figures: one at each zone's median difficulty proxy per family.
(OUT/'figures').mkdir(exist_ok=True);sample=[]
for family in NAMES:
 for z in ZONES:
  group=sorted([q for q in rows if q['family']==family and q['zone']==z],key=lambda q:q['openingComfort'])
  replacements=[q for q in group if '-R2-' in q['id']]
  if replacements:group=replacements
  q=group[len(group)//2];sample.append(q['id'])
  svg='<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="870"><rect width="1200" height="870" fill="#f5f7f2"/>'
  svg+=text(32,39,f"{q['id']} · {NAMES[family]}",27,weight=650)
  svg+=text(32,70,f"{ZONES[z]} · 开局进攻舒适度 {opening_label(q['openingComfort'])}/100 · 先合法碰{q['ownKey'][1:]}号",17)
  for i,(title,body) in enumerate([('开局 · 先想怎样做遮挡',panel(q)),('参考打法 · 实际模拟轨迹',panel(q,q['reference'])),('停稳遮挡检查 · 局部放大',zoom(q))]):
   svg+=f'<g transform="translate({400*i},90)">'+text(190,12,title,19,weight=600,anchor='middle')+body+'</g>'
  shot=q['reference']['shot'];spin='中杆' if shot['spinY']==0 else '高杆' if shot['spinY']>0 else '低杆'
  svg+=text(32,773,f"{spin} · 杆速 {shot['speed']:.2f} m/s · 无侧塞",18,weight=550)+text(610,773,'完整遮挡100 · 8次小幅微调仍挡住',20,weight=650)
  svg+=text(32,814,'浅蓝：母球轨迹 · 黄色：我方球轨迹 · 虚圈：起点 · 实心球：停点',16)
  s=checks[q['id']]['stress'];svg+=text(32,844,f"较大微调挡住：中档{s['medium'].get('full',0)}/8；宽档{s['wide'].get('full',0)}/8。有限探针不代表实台成功率。",16)+'</svg>'
  dest=OUT/'figures'/q['id'];dest.with_suffix('.svg').write_text(svg)
  subprocess.run(['rsvg-convert',str(dest.with_suffix('.svg')),'-o',str(dest.with_suffix('.png'))],check=True)
(OUT/'visual-sample.json').write_text(json.dumps({'selection':'15 family/zone strata; median opening comfort, preferentially r2 replacements in joint long/short','ids':sample},ensure_ascii=False,indent=2))
page=(HERE/'gallery.html').read_text().replace('__DATA__',json.dumps(light,ensure_ascii=False,separators=(',',':'))).replace('__GEOM__',json.dumps(geom,separators=(',',':')))
(OUT/'review.html').write_text(page)
(OUT/'package-manifest.json').write_text(json.dumps({'count':len(bank),'classes':collections.Counter(q['family'] for q in bank),'bankSHA256':hashlib.sha256((OUT/'bank.json').read_bytes()).hexdigest(),'gallerySHA256':hashlib.sha256((OUT/'review.html').read_bytes()).hexdigest(),'auditSHA256':hashlib.sha256((OUT/'audit.json').read_bytes()).hexdigest(),'sampleIDs':sample},ensure_ascii=False,indent=2))
print(json.dumps({'questions':len(bank),'figures':len(sample),'review':str(OUT/'review.html')},ensure_ascii=False))
