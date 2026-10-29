from pathlib import Path
import json,math,html
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/k-ball-placement-20261029';images=OUT/'images';images.mkdir(exist_ok=True)
rows=json.loads((OUT/'samples.json').read_text());contrasts=json.loads((OUT/'contrasts.json').read_text());meta=json.loads((OUT/'geometry.json').read_text());summary=json.loads((OUT/'summary.json').read_text());runs={r['id']:r for r in json.loads((OUT/'perturbations.json').read_text())}
FONT='/System/Library/Fonts/STHeiti Medium.ttc'
def font(n):return ImageFont.truetype(FONT,n)
colors={'cueBall':'#F5F5F1','object':'#56BFF5','kTarget':'#F6C65B'}
axisnames={'inAngle':'入库前 K','outAngle':'出库后 K'}
def draw(r):
 im=Image.new('RGB',(1500,1080),'#101B24');d=ImageDraw.Draw(im);s=r['seed'];axis=axisnames[r['axis']]
 title=f"{r['id']} · {r['sourceID']} · 第{r['railOrdinal']}库{axis} · 实际{r['expectedRails']}库 K"
 d.text((50,24),title,font=font(30),fill='#FAF8F1')
 d.text((50,76),f"接近 B {r.get('actualApproachAngle',r['proposedAngle']):.1f}° · B 球面离库 {r['initialGap']*100:.1f} cm",font=font(25),fill='#C5D2D8')
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
 outcome='B 落袋（另列结果）' if 'kTarget' in r.get('pocketedBalls',[]) else f"B 位移 {r.get('BDisplacementMeters',0)*100:.1f} cm · 停后距最近直库 {r.get('finalBGap',0)*100:.1f} cm"
 d.text((50,860),outcome,font=font(29),fill='#F6C65B')
 count=sum(p['success'] for p in runs.get(r['id'],{}).get('perturbations',[]))
 detail=f"规则成功 · 8 次独立微扰成功 {count}/8" if r['success'] else '未通过：'+({'scratch':'母球落袋'}.get(r['reason'],str(r['reason'])))
 d.text((50,910),detail+f" · 碰 B 前速度 {r.get('contactSpeed',0):.2f} m/s",font=font(25),fill='#FAF8F1')
 d.text((50,955),f"杆速 {s['v']:.2f} m/s · 打点 x {s['sx']:+.3f}R / y {s['sy']:+.3f}R",font=font(22),fill='#C5D2D8')
 d.text((50,998),'生产物理重算的平面示意；微扰计数不是人手成功率，离库增加不等于下一杆必然好打。',font=font(22),fill='#C5D2D8')
 im.save(images/(r['id']+'.png'))
for r in rows+contrasts:draw(r)
cards=[]
for r in sorted(rows,key=lambda r:(r['axis'],r['actualApproachAngle'],r['railOrdinal'])):
 n=sum(p['success'] for p in runs[r['id']]['perturbations'])
 cards.append(f'''<article data-axis="{r['axis']}" data-rail="{r['railOrdinal']}" id="{r['id']}"><h2>{r['id']} · {r['sourceID']} · 第{r['railOrdinal']}库{axisnames[r['axis']]}（实际{r['expectedRails']}库 K）</h2><p>接近 B {r['actualApproachAngle']:.1f}° · 离库 {r['initialGap']*100:.1f} cm · 微扰成功 {n}/8 · <a href="images/{r['id']}.png">原尺寸图</a></p><img src="images/{r['id']}.png" width="1500" height="1080" alt="{r['id']}，完整三球轨迹和停点" loading="lazy"></article>''')
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>K 球 · 靠库 B 代表样本</title><style>body{margin:0;background:#101b24;color:#faf8f1;font:17px/1.65 system-ui}main{max-width:1260px;margin:auto;padding:28px}h1{font-size:32px}h2{font-size:24px}p{color:#bfced4}nav{display:flex;gap:12px;flex-wrap:wrap;margin:24px 0}button,select{font:inherit;color:inherit;background:#253b46;border:1px solid #67828e;border-radius:8px;padding:10px 18px;min-height:44px}button[aria-pressed=true]{background:#28634f}article{margin:35px 0 60px}img{width:100%;height:auto;border-radius:12px}a{color:#7bd3ff}.note{border-left:3px solid #f6c65b;padding-left:18px}summary{cursor:pointer;padding:15px}table{border-collapse:collapse}td,th{padding:8px 18px;border-bottom:1px solid #456}</style><main><h1>K 球 · 靠库 B 代表样本</h1>'''
page+=f"<p>≤45°试算 · {summary['trials']} 个候选位置 · {summary['success']} 个通过当前规则 · 展示 {len(rows)} 个代表样本。</p>"
page+='''<p class="note">A 进指定袋，母球先碰 A 再碰 B，且母球不落袋。所有图已放入 B 并重跑生产物理。B 落袋单列；本轮只描述碰后变化，还没有把“碰到”认定为“处理好”。</p><p>B 球面距直库 0 / 1.5 / 3 厘米，球心距袋口边缘至少 30 厘米，均为试验选点。角度相对该库的平行方向，0°为沿库。微扰独立改变瞄准 ±0.1°、杆速 ±3%、打点 x/y 各 ±0.02R；计数只检验当前成功规则，不代表人手成功率或落点稳定。</p><p>保留 N01、N08-R2 对照路线；其余优先展示不同来源、较大离库变化及变化较小的对照，不是随机抽样。N04-R3 在本轮远离袋口条件下没有候选 B 位置。</p><p>入第 1/2/3 库前 K，分别是实际 0/1/2 库 K；出第 1/2/3 库后 K，分别是实际 1/2/3 库 K。按碰 B 前实际碰库事件核对。</p><nav aria-label="K 时机"><button data-axis="inAngle" aria-pressed="true">入库前 K</button><button data-axis="outAngle" aria-pressed="false">出库后 K</button><select id="rail" aria-label="观察库次"><option value="all">全部库次</option><option value="1">第一库</option><option value="2">第二库</option><option value="3">第三库</option></select></nav><p id="count" role="status"></p>'''
page+=''.join(cards)
page+='<details><summary>查看未通过的对照样本</summary>'
for r in contrasts:page+=f'<h2>{r["id"]} · {r["sourceID"]} · {html.escape({'scratch':'母球落袋'}.get(r['reason'],str(r['reason'])))}</h2><img src="images/{r["id"]}.png" width="1500" height="1080" alt="未通过的对照样本 {r["id"]}" loading="lazy">'
page+='</details><footer><p>研究样本，尚未接入 App；正式角度范围、B 的处理目标及人手难度仍待评阅。</p><p><a href="summary.json">本轮统计</a> · <a href="audit.json">独立核验</a> · <a href="samples.json">完整样本数据</a> · <a href="perturbations.json">微扰结果</a> · <a href="http://127.0.0.1:8851/">上一轮无 B 角度图册</a></p></footer></main>'
page+='''<script>let axis='inAngle';const saved={inAngle:'all',outAngle:'all'},rail=document.getElementById('rail'),cards=[...document.querySelectorAll('article')],buttons=[...document.querySelectorAll('button[data-axis]')];function apply(){let n=0;cards.forEach(c=>{c.hidden=c.dataset.axis!==axis||(rail.value!=='all'&&c.dataset.rail!==rail.value);if(!c.hidden)n++});buttons.forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.axis===axis)));document.getElementById('count').textContent=n?`本组显示 ${n} 个代表样本（按接近 B 的角度排列）`:'本组暂无通过规则的代表样本，未用不合格路线补位。'}buttons.forEach(b=>b.onclick=()=>{saved[axis]=rail.value;axis=b.dataset.axis;rail.value=saved[axis];apply()});rail.onchange=apply;apply();</script></html>'''
(OUT/'index.html').write_text(page)
print('Rendered',len(rows),'samples and',len(contrasts),'contrasts')
