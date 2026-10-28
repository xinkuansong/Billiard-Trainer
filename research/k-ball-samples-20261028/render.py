"""Read-only review atlas. Every plotted point comes from a verified simulation."""
from pathlib import Path
import json, math, html
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/k-ball-samples-20261028'
FONT='/System/Library/Fonts/STHeiti Medium.ttc'
def font(n):return ImageFont.truetype(FONT,n)
rows=json.loads((OUT/'samples.json').read_text());runs={r['id']:r for r in json.loads((OUT/'replay.json').read_text())}
meta=json.loads((OUT/'generation.json').read_text());audit=json.loads((OUT/'audit.json').read_text());assert audit['passed']
names=['直接 K','一库 K','两库 K'];colors={'cueBall':'#F5F5F1','object':'#56BFF5','kTarget':'#F6C65B'}
images=OUT/'images';images.mkdir(exist_ok=True)
def draw(row):
    im=Image.new('RGB',(1500,1040),'#101B24');d=ImageDraw.Draw(im)
    s=row['seed'];success=sum(p['success'] for p in runs[row['id']]['perturbations']);hit=row['events'][row['firstBEvent']]['time']
    d.text((60,28),f"{row['id']}  ·  {names[row['category']]}",font=font(38),fill='#FAF8F1')
    d.text((60,88),'A 进指定袋；母球先碰 A 再碰 B；母球留台',font=font(24),fill='#CBD6DC')
    # X increases right, Z increases down; table ratio and ball radius are physical.
    scale=460;cx,cy=750,485
    def xy(p):return (cx+p[0]*scale,cy+p[1]*scale)
    d.rounded_rectangle((110,150,1390,820),radius=28,fill='#402F27')
    d.rectangle((cx-1.27*scale,cy-.635*scale,cx+1.27*scale,cy+.635*scale),fill='#156257',outline='#287F6F',width=4)
    for i,p in enumerate(meta['pockets']):
        x,y=xy(p);rr=meta['radius']*scale*1.5
        d.ellipse((x-rr,y-rr,x+rr,y+rr),fill='#081411',outline='#56BFF5' if i==s['pocket'] else '#6F6255',width=5 if i==s['pocket'] else 2)
    for name in ['object','kTarget','cueBall']:
        tr=row['tracks'][name]
        for p,q in zip(tr,tr[1:]):
            if name=='cueBall' and p[0]>=hit:
                if int(p[0]*60)%8>=4:continue
                color='#9CACB2';width=3
            else:color=colors[name];width=4
            d.line([xy(p[1:]),xy(q[1:])],fill=color,width=width)
        # Direction arrow on the actual sampled route, without changing geometry.
        moving=[(p,q) for p,q in zip(tr,tr[1:]) if math.dist(p[1:],q[1:])>.002 and (name!='cueBall' or q[0]<hit)]
        if moving:
            p,q=moving[len(moving)//2];x,y=xy(q[1:]);x0,y0=xy(p[1:]);a=math.atan2(y-y0,x-x0)
            d.polygon([(x+8*math.cos(a),y+8*math.sin(a)),(x-10*math.cos(a-.55),y-10*math.sin(a-.55)),(x-10*math.cos(a+.55),y-10*math.sin(a+.55))],fill=colors[name])
        if name not in row['pocketedBalls']:
            x,y=xy(row['finalPositions'][name]);r=meta['radius']*scale
            d.ellipse((x-r,y-r,x+r,y+r),outline=colors[name],width=2)
    for name,label,p in [('cueBall','母',s['cue']),('object','A',s['object']),('kTarget','B',row['B'])]:
        x,y=xy(p);r=meta['radius']*scale
        d.ellipse((x-r,y-r,x+r,y+r),fill=colors[name],outline='#10252A',width=2)
        # Labels sit on the balls; no arbitrary offsets that can cover neighbouring paths.
        d.text((x,y),label,font=font(15),fill='#09232B',anchor='mm')
    for name in ['cueBall','kTarget']:
        p=next(p for p in row['tracks'][name] if p[0]==hit);x,y=xy(p[1:]);r=meta['radius']*scale
        d.ellipse((x-r,y-r,x+r,y+r),outline='#FFAD6B',width=2)
    d.text((60,846),f"杆速 {s['v']:.2f} m/s     打点 x {s['sx']:+.3f}R / y {s['sy']:+.3f}R     微扰成功 {success}/8",font=font(25),fill='#FAF8F1')
    d.text((60,889),'打点：x 正为左塞 / 负为右塞，y 正为高杆 / 负为低杆；R 为球半径。',font=font(20),fill='#BBCBD1')
    d.text((60,926),'白实线：母球 K 前    灰虚线：K 后    蓝：A 路线    金：B 路线    空心圆：停点',font=font(20),fill='#BBCBD1')
    note='B 也落袋；按当前成功规则允许。' if 'kTarget' in row['pocketedBalls'] else f"B 终点位移 {row['BDisplacementMeters']*100:.1f} cm。"
    d.text((60,964),f"橙圈：实际 K 接触位置。{note}  平面模拟示意，非 App 截图。",font=font(20),fill='#E6B48C')
    im.save(images/(row['id']+'.png'))
for row in rows:draw(row)
for cat in range(3):
    group=[r for r in rows if r['category']==cat]
    sheet=Image.new('RGB',(1500,2700),'#101B24');d=ImageDraw.Draw(sheet)
    d.text((30,20),f"K 球首批样本 · {names[cat]} · 10 题",font=font(38),fill='white')
    for i,row in enumerate(group):
        im=Image.open(images/(row['id']+'.png'));im.thumbnail((740,513))
        sheet.paste(im,((i%2)*750,90+(i//2)*520))
    sheet.save(OUT/f'overview-{cat}.jpg',quality=92)
cards=[]
for r in rows:
    n=sum(p['success'] for p in runs[r['id']]['perturbations']);s=r['seed']
    event_lines=[]
    for e in r['events']:
        if e['kind']=='ballBall':detail=' ↔ '.join({'cueBall':'母球','object':'A','kTarget':'B'}[b] for b in e['balls'])
        elif e['kind']=='pocket':detail=f"{e['ball']} 进 {e['pocket']}"
        else:detail=f"{e['ball']} 碰库段 {e['cushion']}"
        event_lines.append(f"<li>{e['time']:.4f} s · {html.escape(detail)}</li>")
    cards.append(f'''<article data-category="{r['category']}" id="{r['id']}"><h2>{r['id']} · {names[r['category']]}</h2>
      <p>微扰成功 {n}/8 · 杆速 {s['v']:.2f} m/s · <a href="images/{r['id']}.png" target="_blank">打开原尺寸图</a></p>
      <img src="images/{r['id']}.png" width="1500" height="1040" alt="{r['id']}，{names[r['category']]}，A进指定袋，母球先碰A再K到B，母球留台。微扰成功{n}/8。" loading="lazy">
      <details><summary>查看碰撞与进袋事件</summary><ol>{''.join(event_lines)}</ol></details></article>''')
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>K 球题库 · 首批 30 题</title><style>body{margin:0;background:#101b24;color:#f7f5ed;font:17px/1.65 system-ui,sans-serif}main{max-width:1250px;margin:auto;padding:28px}h1{font-size:32px}p{color:#c5d2d8}a{color:#7cd1ff}nav{display:flex;gap:10px;flex-wrap:wrap;margin:25px 0}button,select{font:inherit;padding:10px 18px;background:#213743;color:#f7f5ed;border:1px solid #627985;border-radius:8px;min-height:44px}button[aria-pressed=true]{background:#276d56}article{margin:35px 0 60px}article img{width:100%;height:auto;border-radius:10px}summary{cursor:pointer;padding:12px 0}h2{margin-bottom:0}.note{border-left:3px solid #f6c65b;padding-left:18px}footer{margin:40px 0;color:#afc0c7}</style>
<main><h1>K 球题库 · 首批 30 题</h1><p>直接 K、一库 K、两库 K 各 10 题。固定 A 进指定袋，母球先碰 A、随后碰 B，母球留台。</p>
<p class="note">这是待评阅的研究样本，尚未接入 App。图中路线来自完整三球平面模拟。A 可以在 K 到 B 后才落袋；B 是否落袋不影响当前成功判定。</p>
<p>微扰是独立改变瞄准 ±0.1°、杆速 ±3%、打点 x/y 各 ±0.02R，共 8 次。数值只表示本模拟的敏感性，不是真人成功率；未按分数筛掉脆弱题。</p>
<nav aria-label="题型筛选"><button aria-pressed="true" data-filter="all">全部 30 题</button><button aria-pressed="false" data-filter="0">直接 K</button><button aria-pressed="false" data-filter="1">一库 K</button><button aria-pressed="false" data-filter="2">两库 K</button><select id="jump" aria-label="跳到样本"><option value="">跳到题号</option>'''
page+=''.join(f'<option value="{r["id"]}">{r["id"]} · {names[r["category"]]}</option>' for r in rows)
page+='</select></nav>'+''.join(cards)+'''<footer>验证数据：<a href="audit.json">独立审计</a> · <a href="samples.json">样本与轨迹 JSON</a> · <a href="replay.json">逐题重放与微扰</a><br>日期：2026-10-28。图册用于筛选题目，不代表真机或训练页面验收。</footer></main>
<script>const buttons=[...document.querySelectorAll('button[data-filter]')],cards=[...document.querySelectorAll('article')];function filter(value){buttons.forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.filter===value)));cards.forEach(c=>c.hidden=value!=='all'&&c.dataset.category!==value)}buttons.forEach(b=>b.onclick=()=>filter(b.dataset.filter));document.getElementById('jump').onchange=e=>{if(!e.target.value)return;filter('all');document.getElementById(e.target.value).scrollIntoView({behavior:'instant'})};</script></html>'''
(OUT/'index.html').write_text(page)
print('Rendered 30 individual PNGs, 3 overview sheets, and review index.html')
