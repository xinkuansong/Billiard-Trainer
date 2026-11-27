from pathlib import Path
import json,math,html,base64,hashlib,subprocess,os
ROOT=Path(__file__).resolve().parents[2];OUT=Path(os.environ.get('POCKET_OUTPUT',str(ROOT/'output/pocket-window-20261103/r3')))
rows=json.loads((OUT/'results.json').read_text());R=.028575
pockets=json.loads((ROOT/'output/defense-distance-rail-20261103/r2/geometry.json').read_text())['pockets']
def text(x,y,s,size=18,color='#173e35',weight=400):return f'<text x="{x}" y="{y}" font-family="PingFang SC,Heiti SC,sans-serif" font-size="{size}" fill="{color}" font-weight="{weight}">{html.escape(str(s))}</text>'
def scene(row,cx,cy,scale,origin=(0,0),clip=''):
 def pt(p):return (cx+(p[1]-origin[1])*scale,cy-(p[0]-origin[0])*scale)
 def line(a,b,col,width=2,dash=''):
  x,y=pt(a);u,v=pt(b);return f'<line x1="{x}" y1="{y}" x2="{u}" y2="{v}" stroke="{col}" stroke-width="{width}" {dash}/>'
 w=row['window'];g=w['geometry'];t=w['target'];svg=f'<g clip-path="url(#{clip})">' if clip else '<g>'
 x,y=pt([1.27,-.635]);svg+=f'<rect x="{x}" y="{y}" width="{1.27*scale}" height="{2.54*scale}" fill="#e4eee8"/>'
 for p in pockets:
  x,y=pt(p['center']);svg+=f'<circle cx="{x}" cy="{y}" r="{.042*scale}" fill="#293f38"/>'
 for seg in g['rails']:svg+=line(seg['a'],seg['b'],'#77674f',max(3,.012*scale))
 for j in g['jaws']:
  a,b=j['angleA'],j['angleB'];delta=math.atan2(math.sin(b-a),math.cos(b-a))
  path=[]
  for i in range(81):
   ang=a+delta*i/80;p=[j['center'][0]+j['radius']*math.cos(ang),j['center'][1]+j['radius']*math.sin(ang)];path.append(pt(p))
  svg+='<polyline points="'+' '.join(f'{x},{y}' for x,y in path)+'" fill="none" stroke="#8a5c41" stroke-width="4"/>'
  svg+=line(j['lineA'],j['lineB'],'#8a5c41',4)
 for interval in w['intervals']:
  lp,rp=interval['leftEnd'],interval['rightEnd']
  points=[pt(p) for p in [t,lp,rp]];svg+='<polygon points="'+' '.join(f'{x},{y}' for x,y in points)+'" fill="#39a77c" opacity=".18"/>'
  for end,color in [(lp,'#2876bb'),(rp,'#c97c22')]:
   d=math.dist(t,end);nx=-(end[1]-t[1])/d*R;nz=(end[0]-t[0])/d*R
   corners=[[p[0]+sgn*nx,p[1]+sgn*nz] for p,sgn in [(t,1),(end,1),(end,-1),(t,-1)]]
   svg+='<polygon points="'+' '.join(f'{x},{y}' for x,y in map(pt,corners))+f'" fill="{color}" fill-opacity=".08" stroke="{color}" stroke-width="1"/>'
   svg+=line(t,end,color,1.5,'stroke-dasharray="5 3"')
  svg+=line(t,interval['midEnd'],'#288362',1)
 x,y=pt(t);svg+=f'<circle cx="{x}" cy="{y}" r="{R*scale}" fill="#f3c64f" stroke="#9b7320" stroke-width="1.2"/>'
 svg+='</g>';return svg

def figure(row):
 w=row['window'];wid=w['totalWidthDegrees'];g=w['geometry'];cent=g['center'];inside=[p for p in row['rollingProbes'] if 0<p['fraction']<1];outside=[p for p in row['rollingProbes'] if not 0<p['fraction']<1]
 svg='<svg xmlns="http://www.w3.org/2000/svg" width="780" height="500"><rect width="780" height="500" fill="#f5f7f2"/>'
 svg+=text(22,34,row['id']+' · '+row['label'],24,weight=600)
 svg+=text(22,61,'目标球球心出射角范围 · 干净直进',15,color='#64766b')
 svg+='<defs><clipPath id="full"><rect x="15" y="80" width="230" height="350"/></clipPath><clipPath id="zoom"><rect x="278" y="170" width="470" height="224" rx="8"/></clipPath></defs>'
 svg+=scene(row,127,255,124,clip='full')
 svg+=text(278,108,f'{wid:.2f}°' if wid else '未找到非零窗口',36,weight=650)
 distance=math.dist(w['target'],cent);svg+=text(278,140,f'目标球到袋心 {distance:.2f} m',18)
 svg+='<rect x="278" y="170" width="470" height="224" rx="8" fill="#dce6dc"/>'
 # Local detail retains world axis orientation and true proportions.
 svg+=scene(row,513,282,900,origin=cent,clip='zoom')
 svg+=text(278,163,'袋口局部放大 · 两种颜色是两条极限管道' if w['intervals'] else '袋口局部放大 · 此例没有非零干净窗口',13)
 if inside:svg+=text(278,423,f'范围内：{sum(p["cleanPot"] for p in inside)}/{len(inside)} 次干净进指定袋',17)
 else:
  trials=row.get('zeroWindowSearch',[]);pots=[p for p in trials if p['pocket']==f"pocket_{row['pocket']}"];svg+=text(278,423,f'另搜 {len(trials)} 杆：{len(pots)} 杆进袋（含碰库／袋角）',16)
 svg+=text(22,461,'蓝 / 橙：左右边界；管宽 = 球直径。所有图均上 +X、右 +Z。',15)
 svg+=text(22,486,'几何容错，不是进球概率；滚动探针不包含母球碰撞。',14,color='#68776f')+'</svg>'
 return svg
(OUT/'figures').mkdir(exist_ok=True);figs={}
for row in rows:
 s=figure(row);figs[row['id']]=s;p=OUT/'figures'/row['id'];p.with_suffix('.svg').write_text(s);subprocess.run(['rsvg-convert',str(p.with_suffix('.svg')),'-o',str(p.with_suffix('.png'))],check=True)
# Four comparisons in a single shareable artifact.
ids=['N','F','L2','G0'];hero='<svg xmlns="http://www.w3.org/2000/svg" width="1560" height="1000">'
for i,id in enumerate(ids):hero+=f'<g transform="translate({i%2*780},{i//2*500})">'+figs[id].split('>',1)[1].rsplit('</svg>',1)[0].replace('id="full"',f'id="full{i}"').replace('url(#full)',f'url(#full{i})').replace('id="zoom"',f'id="zoom{i}"').replace('url(#zoom)',f'url(#zoom{i})')+'</g>'
hero+='</svg>';(OUT/'comparison.svg').write_text(hero);subprocess.run(['rsvg-convert',str(OUT/'comparison.svg'),'-o',str(OUT/'comparison.png')],check=True)
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>进袋容错角 · 原型验证</title><style>body{font:16px/1.7 "PingFang SC",sans-serif;background:#f5f7f2;color:#173e35;margin:24px}.grid{display:grid;grid-template-columns:repeat(5,minmax(230px,1fr));gap:12px;overflow-x:auto}button{background:white;border:1px solid #bbcdbf;border-radius:8px;padding:8px;color:inherit;font:inherit;cursor:pointer;text-align:left}img{width:100%}dialog{max-width:95vw;max-height:94vh;border:0;border-radius:10px}dialog img{width:min(1400px,90vw);max-height:80vh;object-fit:contain}table{border-collapse:collapse}td,th{padding:6px 18px;border-bottom:1px solid #ccd7ce}</style><h1>目标球进袋容错角</h1><p>复用求解器袋口与管道几何；只统计干净直进的方向范围。点击图片放大。管道两条外缘与实际球半径一致。</p><p>范围越宽，目标球出射方向的几何容错越大；尚未转成100分，不代表完整击球难度或成功概率。</p>'''
for title,subset in [('对照球形',rows[:10]),('原防守样题复查（原候选袋，不代表已重评整杆）',rows[10:])]:
 page+=f'<h2>{title}</h2><div class="grid">'
 for row in subset:page+='<button class="tile"><img alt="'+html.escape(row['label'])+'" src="data:image/svg+xml;base64,'+base64.b64encode(figs[row['id']].encode()).decode()+'">'+html.escape(row['id']+' '+row['label'])+'</button>'
 page+='</div>'
page+='<h2>边界与适用范围</h2><p>严格贴库可以没有非零干净窗口，但仍可能通过触库或袋角入袋。三档速度下有限探针只用于发现几何与物理差异。此处没有加入母球、其它球遮挡、旋转或切角产生的偏移；这些属于下一层整杆难度。</p><dialog id="dialog"><button id="close">关闭</button><img id="large" alt=""></dialog><script>const dialog=document.getElementById("dialog"),large=document.getElementById("large");for(const tile of document.querySelectorAll(".tile"))tile.onclick=()=>{const img=tile.querySelector("img");large.src=img.src;large.alt=img.alt;dialog.showModal()};document.getElementById("close").onclick=()=>dialog.close();</script></html>'
(OUT/'review.html').write_text(page)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(OUT/'render-manifest.json').write_text(json.dumps({'resultsSHA256':sha(OUT/'results.json'),'htmlSHA256':sha(OUT/'review.html'),'comparisonPNG':sha(OUT/'comparison.png'),'figures':{row['id']:{ext:sha(OUT/'figures'/f"{row['id']}.{ext}") for ext in ['svg','png']} for row in rows}},indent=2))
print('Rendered',len(rows),'figures and comparison + single-file HTML')
