"""Metric diagrams from engine evidence (not app screenshots)."""
from pathlib import Path
import json,math,html,collections,hashlib
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/kick-grid-sample-20261030'
IM=OUT/'images';IM.mkdir(exist_ok=True)
g=json.loads((OUT/'geometry.json').read_text());rows=json.loads((OUT/'selected.json').read_text())
contrasts=json.loads((OUT/'contrasts.json').read_text());summary=json.loads((OUT/'generation-summary.json').read_text())
verification={r['id']:r for r in json.loads((OUT/'verification.json').read_text())}
FONT='/System/Library/Fonts/STHeiti Medium.ttc'
def font(n):return ImageFont.truetype(FONT,n)
BG='#10222B';FG='#EDF3F2';BLUE='#56BFF5';ORANGE='#EBA96A'
def draw(r,answer=True):
    im=Image.new('RGB',(1500,1090),BG);d=ImageDraw.Draw(im)
    s=r['seed'];name=r.get('displayID','未通过对照');sx=s['sx'];spin='中杆无塞' if sx==0 else ('左塞' if sx>0 else '右塞')+f' {abs(sx):.2f}R'
    d.text((54,28),f'{name}  ·  {r["n"]} 库解球'+(f'  ·  {spin}' if answer else '  ·  题目'),font=font(36),fill=FG)
    subtitle=f'杆速 {s["v"]:.1f} m/s    方向 {s["slot"]*5}°    实测首库角 {r["baselineFirstAngle"]:.1f}°' if answer else '观察球位，选择方向、力度与侧塞'
    d.text((54,86),subtitle,font=font(24),fill='#BCD0D5')
    scale=450;cx,cy=750,470;L,W,R=g['length'],g['width'],g['radius']
    def xy(p):return cx+p[0]*scale,cy+p[1]*scale
    d.rounded_rectangle((cx-L*scale/2-35,cy-W*scale/2-35,cx+L*scale/2+35,cy+W*scale/2+35),radius=24,fill='#554336')
    d.rectangle((cx-L*scale/2,cy-W*scale/2,cx+L*scale/2,cy+W*scale/2),fill='#20584E')
    # True measured capture lips, plus deep collection circles.
    for p in g['pockets']:
        x,y=xy(p['center']);rr=p['radius']*scale
        d.ellipse((x-rr,y-rr,x+rr,y+rr),fill='#061B18')
        if p['lip']:d.polygon([xy(q) for q in p['lip']],fill='#061B18')
    for rail in g['rails']:
        a,b=rail['start'],rail['end'];d.line([xy(a),xy(b)],fill='#79A699',width=4)
    for k in range(1,8):
        if k==4:continue
        for sign in [-1,1]:
            x,y=xy([-L/2+L*k/8,sign*(W/2+.047)]);d.ellipse((x-3,y-3,x+3,y+3),fill='#C0B59F')
    for k in range(1,4):
        for sign in [-1,1]:
            x,y=xy([sign*(L/2+.047),-W/2+W*k/4]);d.ellipse((x-3,y-3,x+3,y+3),fill='#C0B59F')
    if answer:
        def line(track,color,width,dashed=False):
            for i,(a,b) in enumerate(zip(track,track[1:])):
                if dashed and i%8>=4:continue
                d.line([xy(a[1:]),xy(b[1:])],fill=color,width=width)
        line(r['cueTrack'],'#0A2E2D',7);line(r['cueTrack'],FG,3)
        if not r['success']:
            line(r['cueAfter'],'#FFB18B',4,True)
        track=r['cueTrack'];end=r.get('contactTime',1e10)
        segments=[[]]
        times=[e['time'] for e in r['events'] if e['kind']=='cushion' and e.get('ball')=='cueBall' and e['time']<end]
        for a,b in zip([0]+times,times+[end]):
            tr=[p for p in track if a<=p[0]<=b]
            if len(tr)<3:continue
            k=len(tr)//2;p,q=tr[k-1],tr[k];x,y=xy(q[1:]);x0,y0=xy(p[1:]);ang=math.atan2(y-y0,x-x0)
            d.polygon([(x+9*math.cos(ang),y+9*math.sin(ang)),(x-9*math.cos(ang-.55),y-9*math.sin(ang-.55)),(x-9*math.cos(ang+.55),y-9*math.sin(ang+.55))],fill=FG)
        railno=0
        for e in r['events']:
            if e['time']>=end:break
            if e['kind']=='cushion' and e.get('ball')=='cueBall':
                railno+=1;x,y=xy(e['cue']);p=e['cue'];ln=math.hypot(*p)
                x-=p[0]/max(ln,.01)*22;y-=p[1]/max(ln,.01)*22
                d.ellipse((x-12,y-12,x+12,y+12),fill=BG,outline=ORANGE,width=2)
                d.text((x,y),str(railno),font=font(16),fill=FG,anchor='mm')
        if 'contactCue' in r:
            x,y=xy(r['contactCue']);rr=R*scale;d.ellipse((x-rr,y-rr,x+rr,y+rr),outline=ORANGE,width=3)
    for label,p,color in [('母',s['cue'],FG),('目',r['target'],BLUE)]:
        x,y=xy(p);rr=R*scale
        d.ellipse((x-rr,y-rr,x+rr,y+rr),fill=color,outline='#10222B',width=2)
        d.text((x,y),label,font=font(15),fill='#10222B',anchor='mm')
    if answer:
        d.text((54,818),'白线：碰球前真实轨迹    数字：碰库次序    橙圈：接触时母球',font=font(24),fill=FG)
        d.text((54,860),'入库角以库边切线为基准；本图省略碰球后的运动轨迹。' if r['success'] else '橙虚线：碰球后母球实际运动，最终落袋。',font=font(24),fill='#BCD0D5')
        v=verification.get(r['id']);hits=sum(p['success'] for p in v['probes']) if v else None
        status=f'完整重跑通过 · 独立重放一致 · 微扰 {hits}/6' if r['success'] else '淘汰：'+{'scratch':'碰球后母球落袋'}.get(r['reason'],r['reason'])
        d.text((54,924),status,font=font(29),fill=BLUE if r['success'] else '#FFAC87')
        d.text((54,970),f'碰球前速度 {r.get("contactSpeed",0):.2f} m/s  ·  第 {s["cell"]+1} 格  ·  起点随角度重新随机',font=font(23),fill='#BCD0D5')
    else:
        d.text((54,840),f'任务：母球先碰 {r["n"]} 库，再碰到目标球；母球不得落袋。',font=font(29),fill=FG)
        d.text((54,897),'可先观察球形，再切换答案图查看这一组已验证的击球参数。',font=font(24),fill='#BCD0D5')
    d.text((54,1030),'原生物理数据的等比例研究图；不是App截图。微扰计数不是人手成功率。',font=font(22),fill='#90A9B1')
    return im

for r in rows:
    for answer,suffix in [(True,''),(False,'-question')]:
        draw(r,answer).save(IM/(r['displayID']+suffix+'.png'))
for i,r in enumerate(contrasts):
    r['displayID']=f'X{i+1:02d}';draw(r).save(IM/(r['displayID']+'.png'))

# Six representative routes, one per cushion count.
overview=Image.new('RGB',(1600,1835),BG);od=ImageDraw.Draw(overview)
od.text((35,18),'解球样例 · 四分之一台面随机采样 · 1–6库',font=font(36),fill=FG)
for n in range(1,7):
    category=['zero','leftLight','rightLight','leftMedium','rightMedium','zero'][n-1]
    r=next((x for x in rows if x['n']==n and x['category']==category),None)
    if r:
        pic=Image.open(IM/(r['displayID']+'.png')).resize((780,567))
        overview.paste(pic,((n-1)%2*800,80+(n-1)//2*580))
overview.save(OUT/'overview.png')

# Visible proof of independent origins for every angle, with a single enlarged cell.
sampling=json.loads((OUT/'sampling.json').read_text())['rays']
im=Image.new('RGB',(1500,950),BG);d=ImageDraw.Draw(im)
d.text((50,30),'每个角度重新随机母球起点',font=font(38),fill=FG)
d.text((50,90),'左：四分之一台面 72 格，共 5,184 个起点    右：第 33 格的 72 个起点',font=font(24),fill='#BCD0D5')
ox,oy,scale=55,220,660
L,W=g['length'],g['width']
for ix in range(13):
    x=ox+ix*L/24*scale;d.line((x,oy,x,oy+W/2*scale),fill='#56716E',width=1)
for iz in range(7):
    y=oy+iz*W/12*scale;d.line((ox,y,ox+L/2*scale,y),fill='#56716E',width=1)
for r in sampling:
    x=ox+(r['cue'][0]+L/2)*scale;y=oy+(r['cue'][1]+W/2)*scale
    d.ellipse((x-1,y-1,x+1,y+1),fill=BLUE)
chosen=[r for r in sampling if r['cell']==32];ix,iz=chosen[0]['ix'],chosen[0]['iz']
d.rectangle((ox+ix*L/24*scale,oy+iz*W/12*scale,ox+(ix+1)*L/24*scale,oy+(iz+1)*W/12*scale),outline=ORANGE,width=3)
xx,yy,size=1000,220,420
d.rectangle((xx,yy,xx+size,yy+size),outline=ORANGE,width=2)
for r in chosen:
    u=(r['cue'][0]-(-L/2+ix*L/24))/(L/24);v=(r['cue'][1]-(-W/2+iz*W/12))/(W/12)
    x,y=xx+u*size,yy+v*size;dx,dz=r['dir']
    d.line((x,y,x+dx*10,y+dz*10),fill='#EBA96A',width=2)
    d.ellipse((x-2,y-2,x+2,y+2),fill=FG)
for i,t in enumerate(['每格 0°、5°…355°；每个方向独立取点。',
                      '同一“格子＋角度”下的五档侧塞与四档力度共用起点。',
                      '图中为采样提案；球位、出杆可达性与路线条件仍须经过物理筛选。',
                      '世界 X 向右、Z 向下；0°向右，90°向下。固定随机种子 20261030。']):
    d.text((55,710+i*48),t,font=font(26),fill=FG if i<2 else '#BCD0D5')
im.save(OUT/'sampling.png')

# Empty-table rejected prefixes are kept separate from complete two-ball questions.
rejectLabels={'short-first-leg':'首库行程不足20cm','shallow-angle':'入库角小于15°','steep-angle':'入库角大于75°',
              'opposite-wall-repeat':'相对两库连续往返','rail-pocket-buffer':'接近袋口或非主直库'}
rejectImages=[]
for i,r in enumerate(json.loads((OUT/'rejected-routes.json').read_text())):
    im=Image.new('RGB',(1500,920),BG);d=ImageDraw.Draw(im)
    title=rejectLabels.get(r['reason'],r['reason'])
    d.text((50,30),'筛除示例 · '+title,font=font(36),fill=FG)
    s=r['seed'];d.text((50,88),f'空台前缀：{r["n"]}库  ·  方向{s["slot"]*5}°  ·  杆速{s["v"]:.1f}m/s  ·  侧塞{s["sx"]:+.2f}R',font=font(25),fill='#BCD0D5')
    scale=450;cx,cy=750,460
    def xy(p):return cx+p[0]*scale,cy+p[1]*scale
    d.rectangle((cx-L/2*scale,cy-W/2*scale,cx+L/2*scale,cy+W/2*scale),fill='#20584E')
    for p in g['pockets']:
        x,y=xy(p['center']);rr=p['radius']*scale;d.ellipse((x-rr,y-rr,x+rr,y+rr),fill='#061B18')
        if p['lip']:d.polygon([xy(q) for q in p['lip']],fill='#061B18')
    pts=[xy(p[1:]) for p in r['track']]
    if len(pts)>1:d.line(pts,fill='#FFB18B',width=4)
    x,y=xy(s['cue']);rr=g['radius']*scale;d.ellipse((x-rr,y-rr,x+rr,y+rr),fill=FG)
    d.text((50,800),'试验筛选示意，未放目标球；只淘汰该前缀，不否定更早的合格片段。',font=font(26),fill=FG)
    name=f'R{i+1:02d}';im.save(IM/(name+'.png'));rejectImages.append((name,title))

audit=json.loads((OUT/'audit.json').read_text())
spinLabels={'zero':'无塞','leftLight':'轻左塞','rightLight':'轻右塞','leftMedium':'中左塞','rightMedium':'中右塞'}
cards=[]
for r in rows:
    name=r['displayID'];hits=sum(p['success'] for p in verification[r['id']]['probes'])
    cards.append(f'<article data-n="{r["n"]}" data-spin="{r["category"]}"><h2>{name} · {r["n"]}库 <span class="answerMeta">· {spinLabels[r["category"]]} · 微扰{hits}/6</span></h2><img src="images/{name}.png" data-answer="images/{name}.png" data-question="images/{name}-question.png" width="1500" height="1090" loading="lazy" alt="{name}，{r["n"]}库解球研究图"><p><a href="images/{name}.png">高清答案图</a> · <a href="images/{name}-question.png">题目图</a></p></article>')
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>解球样例 · 1–6库</title><style>body{margin:0;background:#10222b;color:#edf3f2;font:17px/1.7 system-ui}main{max-width:1350px;margin:auto;padding:28px}h1{font-size:34px}p{color:#bcd0d5}img{width:100%;height:auto;border-radius:10px}nav{display:flex;gap:12px;flex-wrap:wrap;position:sticky;top:0;background:#10222bf5;padding:14px 0;z-index:2}select,button{font:inherit;min-height:44px;background:#24444d;color:#edf3f2;border:1px solid #607b81;border-radius:8px;padding:8px 14px}a{color:#74cfff}summary{cursor:pointer;padding:14px 0}article{margin:20px 0 45px}h2{font-size:24px}details{border-top:1px solid #36505a}td,th{padding:8px 20px;border-bottom:1px solid #36505a}body.question .answerMeta{display:none}article[hidden]{display:none}</style><main><h1>解球样例 · 1–6库</h1>'''
page+=f'<p>展示 {len(rows)} 题，每库 6 题：2 题无塞，轻左／轻右／中左／中右塞各 1 题。共生成 {audit["candidates"]} 题，逐题独立重放一致；{audit["perturbations"]} 次单因素微扰中 {audit["perturbationsSucceeded"]} 次满足原规则。</p>'
page+='<p>本轮采用四分之一台面 6×12 格；每个 5°方向重新随机母球位置。图中白线来自原生物理模拟，数字为实际碰库次序。无障碍球，练习指定库数碰球；母球不得落袋。</p>'
page+=f'<p>实际运行 {summary["baselineSimulations"]} 次空台模拟，候选覆盖 {audit["acceptedCells"]}/72 格，展示覆盖 {audit["selectedCells"]}/72 格。按样例配额提前停止，未做全库覆盖或完整容错分级；微扰比例不是人手成功率。</p>'
page+='''<details><summary>采样位置与本轮试验条件</summary><img src="sampling.png" width="1500" height="950" alt="四分之一台面网格及每角度独立随机的母球起点"><p>杆速1.5／2.5／3.5／4.5m/s；侧塞0／±0.25R／±0.50R，上下打点为0。角度以世界+X为0°，朝+Z增加。全部参数提案103,680组，抽样执行。</p><p>试验阈值：首库行程≥20cm；碰球前各库相对切线15°–75°；每次碰库离有限直库端部≥10cm；排除相对两墙连续A→B→A→B。第N库后放目标，出库段两端各留9cm，横向±0.9R。每次加球完整重跑，要求实际库数和库序一致、母球不落袋。一条来源路线同库数只保留一个位置。</p><p>微扰：方向±0.1°、杆速±3%、侧塞±0.02R，六次独立单轴检查，保留失败，不据此作难度承诺。镜像扩库、跨路线几何去重和真台校准尚未执行。</p></details>'''
page+='<nav><select id="n" aria-label="库数"><option value="all">全部库数</option>'+''.join(f'<option value="{n}">{n}库</option>' for n in range(1,7))+'</select><select id="spin" aria-label="杆法"><option value="all">全部杆法</option>'+''.join(f'<option value="{k}">{v}</option>' for k,v in spinLabels.items())+'</select><button id="toggle" aria-pressed="true">隐藏答案</button><span id="count" role="status"></span></nav>'
page+=''.join(cards)+'<details><summary>查看筛除路线的对照图</summary>'
for name,title in rejectImages:page+=f'<h2>{title}</h2><img src="images/{name}.png" width="1500" height="920" loading="lazy" alt="{title}的空台路线示例">'
for r in contrasts:page+=f'<h2>{r["displayID"]} · 加球后母球落袋</h2><img src="images/{r["displayID"]}.png" width="1500" height="1090" loading="lazy" alt="加球后母球落袋的淘汰对照">'
page+='</details><details><summary>筛选统计与证据</summary><table><tr><th>原因（各阶段累计，分母不同）</th><th>次数</th></tr>'
for k,v in summary['rejections'].items():page+=f'<tr><td>{html.escape(rejectLabels.get(k,k))}</td><td>{v}</td></tr>'
page+='</table><p><a href="REPORT.md">完整记录</a> · <a href="audit.json">审计</a> · <a href="selected.json">展示题目</a> · <a href="verification.json">独立重放与微扰</a></p></details></main>'
page+='''<script>let answer=true;const n=document.querySelector('#n'),spin=document.querySelector('#spin'),cards=[...document.querySelectorAll('article')];function filter(){let c=0;for(const a of cards){a.hidden=!(n.value==='all'||a.dataset.n===n.value)||!(spin.value==='all'||a.dataset.spin===spin.value);if(!a.hidden)c++;}document.querySelector('#count').textContent=c+' 道';}n.onchange=spin.onchange=filter;document.querySelector('#toggle').onclick=function(){answer=!answer;this.textContent=answer?'隐藏答案':'显示答案';this.setAttribute('aria-pressed',answer);document.body.classList.toggle('question',!answer);for(const i of document.querySelectorAll('article img'))i.src=answer?i.dataset.answer:i.dataset.question;};filter();</script></html>'''
(OUT/'index.html').write_text(page)
print('RENDERED',len(rows),'questions; rejected prefixes',len(rejectImages))
