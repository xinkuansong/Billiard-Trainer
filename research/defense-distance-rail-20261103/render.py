from pathlib import Path
import ast,base64,html,json,math,subprocess,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/defense-distance-rail-20261103/r2'
geom=json.loads((OUT/'geometry.json').read_text());L,W,R=(geom[k] for k in ['length','width','radius']);CUE=geom['cueKey']
FONT='PingFang SC,Heiti SC,sans-serif';COLORS={CUE:'#fffdf5','_1':'#f9c447','_8':'#18231f','_9':'#f9c447'}
for node in ast.parse((ROOT/'research/defense-two-expand-20261103/review.py').read_text()).body:
 if isinstance(node,ast.FunctionDef) and node.name in ['text','ball','panel','opening_label']:exec(compile(ast.Module(body=[node],type_ignores=[]),'drawing','exec'))
rows=json.loads((OUT/'questions.json').read_text());assert len(rows)==6
NAMES={'long':'拉长台','rail':'母球留近贴库'}
LAYOUTS={'twoA':'两球 · 我方1号，对方8号','twoB':'两球 · 我方8号，对方9号','three':'三球 · 我方1号，对方9号，另有8号'}

def next_shot(q,r):
 ps=r['positions'];c=ps[CUE];t=ps[q['enemyKey']];best=r['opportunities'][0];aim=best['aim'];d=math.dist(t,aim);u=[(aim[i]-t[i])/d for i in range(2)];ghost=[t[i]-2*R*u[i] for i in range(2)]
 assert abs(math.dist(ghost,t)-2*R)<1e-10
 project=lambda p:(47+(p[1]+W/2)*226,56+(L/2-p[0])*226)
 s=panel(dict(q,positions=ps))
 for a,b in [(c,ghost),(t,aim)]:
  x1,y1=project(a);x2,y2=project(b);s+=f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="#ffbc79" stroke-width="2" stroke-dasharray="6 4"/>'
 x,y=project(ghost);s+=f'<circle cx="{x}" cy="{y}" r="{R*226}" fill="none" stroke="#ffbc79" stroke-width="1.2"/>'
 # Restore the solid balls on top of schematic lines, preserve measured positions.
 for key,p in ps.items():s+=ball(key,p,project,226)
 s+=text(190,673,f"几何候选切角 {best['cutDegrees']:.1f}°",16,anchor='middle')
 return s

def gap_label(gap):return '<0.1' if 0<gap*1000<.1 else f'{gap*1000:.1f}'

def rail_inset(gap):
 scale=1600;rr=R*scale;cy=42+(R+gap)*scale
 s='<rect x="0" y="0" width="325" height="207" rx="12" fill="#e3eee5"/><rect x="0" y="0" width="325" height="42" rx="8" fill="#705d48"/><path d="M0 42 H325" stroke="#17624a" stroke-width="4"/>'
 s+=f'<circle cx="100" cy="{cy}" r="{rr}" fill="#fffdf5" stroke="#b4c4b7"/><path d="M164 42 H195 M164 {42+gap*scale} H195 M183 42 V{42+gap*scale}" fill="none" stroke="#ac4e2d" stroke-width="1.6"/>'
 s+=text(207,87,f'{gap_label(gap)} mm',21,color='#9c4326',weight=600)+text(162,176,'球面到主库的实际净距',16,anchor='middle')
 return s

figs=[];(OUT/'figures').mkdir(exist_ok=True)
for qi,q in enumerate(rows):
 r=q['reference'];m=q['metrics'];before=q['positions'];d0=math.dist(before[CUE],before[q['enemyKey']]);best=r['opportunities'][0];comfort=best['score'];gap=m['cueRailGap'];kind=q['family'];label=q['displayID']
 svg='<svg xmlns="http://www.w3.org/2000/svg" width="1500" height="1000"><rect width="1500" height="1000" fill="#f5f7f2"/>'
 svg+=text(30,40,f"{label} · {NAMES[kind]}",28,weight=650)+text(30,72,f"{LAYOUTS[q['layoutFamily']]} · 我方开局进攻舒适度 {opening_label(q['openingComfort'])}/100",18)
 for i,(title,body) in enumerate([('开局 · 先考虑防守',panel(q)),('参考打法 · 实际模拟路线',panel(q,r)),('留给对方 · 最佳直进候选',next_shot(q,r))]):
  svg+=f'<g transform="translate({i*375},100) scale(.9375)">'+text(190,14,title,20,weight=600,anchor='middle')+body+'</g>'
 svg+=text(1135,114,'防守效果',21,weight=650)
 if kind=='long':
  svg+=text(1135,164,'母球到对方目标球',17)+text(1135,205,f'{d0:.2f} → {m["ballDistance"]:.2f} m',31,weight=650)+text(1135,244,f'拉开 {m["distanceGain"]:.2f} m',20,color='#a64b31')
 else:
  svg+=text(1135,164,'母球球面离库',17)+text(1135,205,f'{gap_label(gap)} mm',33,weight=650)+text(1135,244,f'球间距 {m["ballDistance"]:.2f} m',20)
 svg+=text(1135,292,'对方最佳进攻舒适度',17)+text(1135,332,f'{comfort:.1f} / 100',29,weight=650)
 svg+=text(1135,370,f'本杆防守结果分 {100-comfort:.1f}',20,weight=550)
 for j,(key,name) in enumerate([('distance','距离'),('space','空间'),('angle','角度')]):
  y=410+j*38;v=best[key];svg+=text(1135,y,name,16)+f'<rect x="1184" y="{y-13}" width="220" height="13" rx="4" fill="#dce5db"/><rect x="1184" y="{y-13}" width="{2.2*v}" height="13" rx="4" fill="#337c61"/>'+text(1417,y,f'{v:.0f}',15)
 if kind=='rail':svg+='<g transform="translate(1135,525)">'+rail_inset(gap)+'</g>'
 else:
  svg+=text(1135,552,'距离分最低，长距离是主要难点。',16)+text(1135,588,'目标仍可直接碰到，未靠球遮挡。',16)+text(1135,630,f'母球离库 {gap*100:.1f} cm',18)
 shot=r['shot'];spin='中杆' if shot['spinY']==0 else '高杆' if shot['spinY']>0 else '低杆'
 svg+=text(30,800,f"参考：{spin}，杆速 {shot['speed']:.2f} m/s，无侧塞；先合法碰{q['ownKey'][1:]}号，碰后有球碰库，无球入袋。",20)
 svg+=text(30,840,f"同一开局的另一杆对照：对方进攻舒适度 {q['comparisonComfort']:.1f}；本杆降至 {comfort:.1f}（越低越难）。",20,weight=550)
 ranges=q['probeSummary']
 if kind=='long':probe=f"8次小幅微调：球间距 {ranges['distanceMin']:.2f}–{ranges['distanceMax']:.2f} m，对方舒适度 {ranges['comfortMin']:.1f}–{ranges['comfortMax']:.1f}。"
 else:probe=f"8次小幅微调：母球离库 {gap_label(ranges['gapMin'])}–{gap_label(ranges['gapMax'])} mm，对方舒适度 {ranges['comfortMin']:.1f}–{ranges['comfortMax']:.1f}。"
 svg+=text(30,880,probe,18)
 svg+=text(30,921,'浅蓝/黄实线：本杆实际母球/我方球路线；橙虚线：对方下一杆几何候选，未模拟其进球。',17)
 svg+=text(30,958,'舒适度用于比较几何难度，不是进球概率；8次微调不代表实台成功率。近贴库并非严格相切。',17,color='#627369')+'</svg>'
 f=OUT/'figures'/label;f.with_suffix('.svg').write_text(svg);subprocess.run(['rsvg-convert',str(f.with_suffix('.svg')),'-o',str(f.with_suffix('.png'))],check=True);figs.append((q,svg))
# Same five-column overview contract; all six images embedded, click for full size.
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>拉长台与近贴库 · 6道样题</title><style>body{font:16px/1.6 "PingFang SC",sans-serif;margin:22px;background:#f5f7f2;color:#193731}h1{margin:0}a{color:#236b51}.grid{display:grid;grid-template-columns:repeat(5,minmax(230px,1fr));gap:12px;overflow-x:auto}button{font:inherit;color:inherit;cursor:pointer;background:white;border:1px solid #c1d3c5;border-radius:10px;padding:8px;text-align:left}button img{width:100%;height:auto}dialog{border:0;border-radius:12px;padding:12px;max-width:96vw;max-height:96vh;background:#f5f7f2}dialog::backdrop{background:#10221bc9}dialog img{width:min(1500px,92vw);max-height:82vh;object-fit:contain}summary{cursor:pointer}.note{color:#627369}</style><h1>拉长台与近贴库 · 各3道样题</h1><p>点击图片放大。三种局面各一题：我方剩1颗、对方打黑八；我方打黑八、对方剩1颗；双方各1颗加黑八。</p><p class="note">所有题目均保留较难的己方开局进攻，参考及8次微调均合法。对方仍能直接碰到目标；防守效果由下一杆最佳直接进攻的几何舒适度比较。</p>'''
for kind in ['long','rail']:
 page+=f'<h2>{NAMES[kind]}</h2><div class="grid">'
 for q,svg in figs:
  if q['family']!=kind:continue
  data=base64.b64encode(svg.encode()).decode();page+=f'<button class="tile"><img alt="{q["displayID"]} {NAMES[kind]}" src="data:image/svg+xml;base64,{data}"><b>{q["displayID"]}</b> · {LAYOUTS[q["layoutFamily"]]}</button>'
 page+='</div>'
page+='<p class="note">近贴库专指母球留在库边，不等于把对方目标球送到库边。参考要求≤15mm；微调检查记录真实范围，未要求每次都在15mm内。本轮为离线样题，尚未接入App或实台校准。</p><dialog id="dialog"><button id="close">关闭（Esc）</button><div><img id="large" alt=""></div></dialog><script>const dialog=document.getElementById("dialog"),large=document.getElementById("large");for(const button of document.querySelectorAll(".tile"))button.onclick=()=>{const img=button.querySelector("img");large.src=img.src;large.alt=img.alt;dialog.showModal();};document.getElementById("close").onclick=()=>dialog.close();</script></html>'
(OUT/'review.html').write_text(page)
(OUT/'render-manifest.json').write_text(json.dumps({'questions':6,'figures':[{'id':q['displayID'],'sourceID':q['id'],'svgSHA256':hashlib.sha256(svg.encode()).hexdigest(),'pngSHA256':hashlib.sha256((OUT/'figures'/f"{q['displayID']}.png").read_bytes()).hexdigest()} for q,svg in figs],'htmlSHA256':hashlib.sha256(page.encode()).hexdigest()},ensure_ascii=False,indent=2))
print('RENDERED 6 figures and standalone HTML')
