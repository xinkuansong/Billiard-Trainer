from pathlib import Path
import json,math,html
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/k-ball-corridor-20261029';images=OUT/'images';images.mkdir(exist_ok=True)
rows=json.loads((OUT/'trials.json').read_text());regions=json.loads((OUT/'regions.json').read_text());meta=json.loads((OUT/'geometry.json').read_text())
FONT='/System/Library/Fonts/STHeiti Medium.ttc'
def font(n):return ImageFont.truetype(FONT,n)
colors={'cueBall':'#F5F5F1','object':'#56BFF5','kTarget':'#F6C65B'}
axisnames={'inAngle':'入库前 K','outAngle':'出库后 K'}
def reason_name(reason):return {'scratch':'母球落袋','wrong-first-ball':'第一颗碰球不是 A','no-cue-B-contact':'母球未碰到 B','A-not-in-specified-pocket':'A 未进指定袋','inaccessible':'当前打点不可出杆','incomplete':'模拟未完成'}.get(reason,str(reason))
def draw(r):
 im=Image.new('RGB',(1500,1080),'#101B24');d=ImageDraw.Draw(im);s=r['seed'];axis=axisnames[r['axis']]
 title=f"{r['id']} · {r['sourceID']} · 第{r['railOrdinal']}库{axis} · 实际{r['expectedRails']}库 K"
 d.text((50,24),title,font=font(30),fill='#FAF8F1')
 d.text((50,76),f"B{r['localNumber']} · 球面离库 {r['initialGap']*100:.1f} cm · 原片段角 {r['sourceAngle']:.1f}°",font=font(25),fill='#C5D2D8')
 scale=450;cx,cy=750,450;hx=meta['length']/2;hz=meta['width']/2
 def xy(p):return cx+p[0]*scale,cy+p[1]*scale
 d.rounded_rectangle((cx-hx*scale-35,cy-hz*scale-35,cx+hx*scale+35,cy+hz*scale+35),radius=28,fill='#47372D')
 d.rectangle((cx-hx*scale,cy-hz*scale,cx+hx*scale,cy+hz*scale),fill='#205A50')
 for p in meta['pockets']:
  x,y=xy(p['center']);rr=p['radius']*scale
  d.ellipse((x-rr,y-rr,x+rr,y+rr),fill='#081916',outline='#56BFF5' if p['id']==f"pocket_{s['pocket']}" else '#9C8E79',width=4)
 hit=r['events'][r['firstBEvent']]['time'] if r.get('firstBEvent',-1)>=0 else math.inf
 for name in ['object','kTarget','cueBall']:
  tr=r.get('tracks',{}).get(name,[])
  for p,q in zip(tr,tr[1:]):
   after=name=='cueBall' and p[0]>=hit
   if after and int(p[0]*60)%8>=4:continue
   d.line([xy(p[1:]),xy(q[1:])],fill='#A1ADB0' if after else colors[name],width=3 if after else 4)
  moving=[(p,q) for p,q in zip(tr,tr[1:]) if math.dist(p[1:],q[1:])>.002 and (name!='cueBall' or q[0]<hit)]
  if moving:
   p,q=moving[len(moving)//2];x,y=xy(q[1:]);x0,y0=xy(p[1:]);a=math.atan2(y-y0,x-x0)
   d.polygon([(x+8*math.cos(a),y+8*math.sin(a)),(x-10*math.cos(a-.55),y-10*math.sin(a-.55)),(x-10*math.cos(a+.55),y-10*math.sin(a+.55))],fill=colors[name])
  if name in r.get('finalPositions',{}) and name not in r.get('pocketedBalls',[]):
   x,y=xy(r['finalPositions'][name]);rad=meta['radius']*scale
   d.ellipse((x-rad,y-rad,x+rad,y+rad),outline=colors[name],width=3)
   d.text((x,y),{'cueBall':'母','object':'A','kTarget':'B'}[name],font=font(13),fill=colors[name],anchor='mm')
 for name,label,p in [('cueBall','母',s['cue']),('object','A',s['object']),('kTarget','B',r['B'])]:
  x,y=xy(p);rad=meta['radius']*scale
  d.ellipse((x-rad,y-rad,x+rad,y+rad),fill=colors[name],outline='#10252A',width=2)
  d.text((x,y),label,font=font(14),fill='#09232B',anchor='mm')
 if 'contactPosition' in r:
  x,y=xy(r['contactPosition']);rad=meta['radius']*scale
  d.ellipse((x-rad,y-rad,x+rad,y+rad),outline='#FF9365',width=3)
 d.text((50,808),'实心球：起点    空心球：停点    橙圈：K 时母球    白：K 前    灰虚线：K 后    金：B 路线',font=font(22),fill='#C5D2D8')
 d.text((50,860),'成功：进 A、K 到 B，母球不落袋' if r['success'] else '未通过：'+reason_name(r['reason']),font=font(29),fill='#F6C65B' if r['success'] else '#FF9988')
 d.text((50,910),'B 的移动方向、距离和停点不参与成功判定。每次模拟只放本图这一颗 B。',font=font(24),fill='#C5D2D8')
 d.text((50,955),f"杆速 {s['v']:.2f} m/s · 打点 x {s['sx']:+.3f}R / y {s['sy']:+.3f}R",font=font(22),fill='#C5D2D8')
 d.text((50,998),'生产物理重算的平面示意；图中停点仅供观察，不要求形成下一杆走位。',font=font(22),fill='#C5D2D8')
 im.save(images/(r['id']+'.png'))
for r in rows:draw(r)
def region_draw(e):
 im=Image.new('RGBA',(1500,1080),'#101B24');d=ImageDraw.Draw(im);s=e['seed'];group=[r for r in rows if r['regionID']==e['id']]
 d.text((45,24),f"{e['sourceID']} · 第{e['railOrdinal']}库{axisnames[e['axis']]} · 原片段角 {e['sourceAngle']:.1f}°",font=font(30),fill='#FAF8F1')
 d.text((45,78),f"随机抽取 {len(group)} 个 B 位置 · 通过 {sum(r['success'] for r in group)} 个 · 每次只放一颗 B",font=font(25),fill='#C5D2D8')
 scale=500;cx,cy=750,460;hx=meta['length']/2;hz=meta['width']/2
 def xy(p):return cx+p[0]*scale,cy+p[1]*scale
 d.rounded_rectangle((cx-hx*scale-35,cy-hz*scale-35,cx+hx*scale+35,cy+hz*scale+35),radius=28,fill='#47372D')
 d.rectangle((cx-hx*scale,cy-hz*scale,cx+hx*scale,cy+hz*scale),fill='#205A50')
 # Full-table mask is a metric 2mm raster, plotted at 500px/m without geometric distortion.
 mask=Image.open(OUT/e['mask']);im.alpha_composite(mask,(round(cx-hx*scale),round(cy-hz*scale)));d=ImageDraw.Draw(im)
 for p in meta['pockets']:
  x,y=xy(p['center']);rad=p['radius']*scale
  d.ellipse((x-rad,y-rad,x+rad,y+rad),fill='#081916',outline='#56BFF5' if p['id']==f"pocket_{s['pocket']}" else '#9C8E79',width=3)
 pts=e['points'];d.line([xy(s['cue']),xy(pts[0])],fill='#8C9A9B',width=2)
 d.line([xy(p) for p in pts],fill='#7B9292',width=2)
 d.line([xy(p) for p in pts[e['lo']:e['hi']+1]],fill='#FAFAF5',width=3)
 # Actual old A aim line is reference only on this candidate-region diagram.
 pocket=meta['pockets'][s['pocket']]['center'];d.line([xy(s['object']),xy(pocket)],fill='#56BFF5',width=2)
 for name,label,p in [('cueBall','母',s['cue']),('object','A',s['object'])]:
  x,y=xy(p);rad=meta['radius']*scale;d.ellipse((x-rad,y-rad,x+rad,y+rad),fill=colors[name],outline='#10252A',width=2);d.text((x,y),label,font=font(15),fill='#09232B',anchor='mm')
 for r in group:
  x,y=xy(r['B']);d.ellipse((x-5,y-5,x+5,y+5),fill='#F6C65B' if r['success'] else '#FF756C',outline='#152931',width=1)
  d.text((x,y-16),str(r['localNumber']),font=font(18),fill='#F6C65B' if r['success'] else '#FF756C',anchor='mm',stroke_width=2,stroke_fill='#10252A')
 d.text((45,836),'蓝区：靠库 15cm 内的轨迹管道    绿区：本组可抽样区域    编号点：B 球心位置',font=font(23),fill='#C5D2D8')
 d.text((45,882),'总宽约 5.14cm（0.9 个球直径）；15cm 按球面净距。编号点不是同时摆放的多颗球。',font=font(22),fill='#C5D2D8')
 d.text((45,930),'绿区避开袋口附近、起始重叠，以及母球会在此前轨迹先碰到 B 的部分。',font=font(23),fill='#C5D2D8')
 d.text((45,1018),'灰线：原完整路线；白线：本次片段；蓝线：A 进袋方向示意。区域不是碰 B 后的预测。',font=font(20),fill='#C5D2D8')
 d.text((45,980),'区域图沿用无 B 参考轨迹；选择编号后，下图显示该 B 位置的完整三球模拟。',font=font(23),fill='#F6C65B')
 im.convert('RGB').save(images/f"{e['id']}-region.png")
 bbox=mask.getbbox()
 if bbox:
  bx,by=round(cx-hx*scale),round(cy-hz*scale);x0,y0,x1,y1=bbox
  crop=im.crop((max(0,bx+x0-75),max(120,by+y0-75),min(1500,bx+x1+75),min(820,by+y1+75)))
  crop.convert('RGB').save(images/f"{e['id']}-local.png")
  e['hasLocal']=True
 else:e['hasLocal']=False
for e in regions:region_draw(e)
cards=[]
for e in sorted(regions,key=lambda e:(e['axis'],e['sourceAngle'],e['id'])):
 group=[r for r in rows if r['regionID']==e['id']];count=sum(r['success'] for r in group)
 card=f'''<article data-axis="{e['axis']}" data-rail="{e['railOrdinal']}" id="{e['id']}"><h2>{e['sourceID']} · 第{e['railOrdinal']}库{axisnames[e['axis']]} · {e['sourceAngle']:.1f}°</h2><p>随机位置 {len(group)} 个，通过 {count} 个。完整参考轨迹和管道区域：</p><img src="images/{e['id']}-region.png" width="1500" height="1080" alt="{e['sourceID']}的轨迹管道及随机B球心位置" loading="lazy">'''
 if e['hasLocal']:card+=f'<details open><summary>放大查看管道区域</summary><img class="local" src="images/{e["id"]}-local.png" alt="管道局部，几何比例保持一致" loading="lazy"></details>'
 if group:
  card+=f'<label>选择 B 位置 <select class="sample" aria-label="{e["id"]}选择B位置">'
  for r in group:card+=f'<option value="{r["id"]}">B{r["localNumber"]} · 离库 {r["initialGap"]*100:.1f}cm · {"成功" if r["success"] else reason_name(r["reason"])}</option>'
  card+=f'</select></label><p>以下为选中位置的三球重算；停点只供观察，不评分。</p><img class="result" src="images/{group[0]["id"]}.png" width="1500" height="1080" alt="B1的完整三球模拟" loading="lazy">'
 else:card+='<p class="note">本片段在当前靠库、远袋及首次接触条件下没有抽到 B；保留区域图，不补入不符合条件的位置。</p>'
 cards.append(card+'</article>')
summary=dict(regions=len(regions),candidates=len(rows),success=sum(r['success'] for r in rows),failed=sum(not r['success'] for r in rows),emptyRegions=[e['id'] for e in regions if not e['sampleIDs']],successRule='A first; A specified pocket; cue later contacts B; cue no scratch. B outcome is not scored.')
(OUT/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>K 球 · 靠库15cm轨迹管道</title><style>body{margin:0;background:#101b24;color:#faf8f1;font:17px/1.65 system-ui}main{max-width:1260px;margin:auto;padding:28px}h1{font-size:32px}h2{font-size:25px}p{color:#bfd0d5}nav{display:flex;gap:12px;flex-wrap:wrap;margin:24px 0}button,select{font:inherit;color:inherit;background:#253b46;border:1px solid #67828e;border-radius:8px;padding:10px 15px;min-height:44px}button[aria-pressed=true]{background:#28634f}article{margin:35px 0 70px}img{width:100%;height:auto;border-radius:12px}img.local{width:auto;max-width:100%;min-width:50%}a{color:#7bd3ff}.note{border-left:3px solid #f6c65b;padding-left:18px}summary{cursor:pointer;padding:14px 0}label{display:block;margin-top:20px}</style><main><h1>K 球 · 靠库15cm轨迹管道</h1>'''
page+=f'<p>{len(regions)} 个入／出库片段 · 随机 {len(rows)} 个 B 位置 · {summary["success"]} 个通过 · {summary["failed"]} 个未通过。</p>'
page+='''<p class="note">只验证：母球先碰 A，A 进指定袋，母球随后碰 B 且不落袋。B 的移动方向、距离、停点和是否进袋均不影响成功。</p><p>沿用≤45°的原片段初筛；管道总宽0.9个球直径，B球面到观察库段净距0–15cm。蓝区为几何管道，绿区为避开袋口附近及提前碰撞后的可抽样部分。每个片段按0–5、5–10、10–15cm三档各随机抽取最多2点，固定随机种子，狭小区域可能不足6点。保留前轮距袋口沿至少30cm条件。</p><p>每张区域图的编号点代表互相独立的 B 位置，每次只放一颗 B。下方选择编号查看实际三球路线；所有随机点的成功和失败都保留，不按碰后效果挑选。</p><nav aria-label="K时机"><button data-axis="inAngle" aria-pressed="true">入库前 K</button><button data-axis="outAngle" aria-pressed="false">出库后 K</button><select id="rail" aria-label="观察库次"><option value="all">全部库次</option><option value="1">第一库</option><option value="2">第二库</option><option value="3">第三库</option></select></nav><p id="count" role="status"></p>'''+''.join(cards)
page+='''<footer><p>研究图册，未接入正式题库。区域采用旧轨迹的2mm显示网格，三球结果来自当前生产物理；无需达到指定B落点，尚不代表真人成功率。</p><p><a href="audit.json">独立核验</a> · <a href="trials.json">全部候选结果</a> · <a href="candidate-audit.json">区域与随机参数</a> · <a href="http://127.0.0.1:8852/">上一轮固定位置样本</a></p></footer></main><script>let axis='inAngle';const saved={inAngle:'all',outAngle:'all'},rail=document.getElementById('rail'),cards=[...document.querySelectorAll('article')],buttons=[...document.querySelectorAll('button[data-axis]')];function apply(){let n=0;cards.forEach(c=>{c.hidden=c.dataset.axis!==axis||(rail.value!=='all'&&c.dataset.rail!==rail.value);if(!c.hidden)n++});buttons.forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.axis===axis)));document.getElementById('count').textContent=`本组显示 ${n} 个片段（按原片段角度排列）`;}buttons.forEach(b=>b.onclick=()=>{saved[axis]=rail.value;axis=b.dataset.axis;rail.value=saved[axis];apply()});rail.onchange=apply;document.querySelectorAll('select.sample').forEach(s=>s.onchange=()=>{const im=s.closest('article').querySelector('img.result');im.src=`images/${s.value}.png`;im.alt=s.options[s.selectedIndex].text+'的完整三球模拟';});apply();</script></html>'''
(OUT/'index.html').write_text(page);print(summary)
