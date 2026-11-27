"""Metric diagrams from engine evidence (not app screenshots)."""
from pathlib import Path
import json,math,html,collections,hashlib
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/kick-grid-filtered-20261030'
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
        status='完整重跑通过 · 独立重放一致' if r['success'] else '淘汰：'+{'scratch':'碰球后母球落袋'}.get(r['reason'],r['reason'])
        d.text((54,924),status,font=font(29),fill=BLUE if r['success'] else '#FFAC87')
        d.text((54,970),f'碰球前速度 {r.get("contactSpeed",0):.2f} m/s  ·  第 {s["cell"]+1} 格  ·  起点随角度重新随机',font=font(23),fill='#BCD0D5')
    else:
        d.text((54,840),f'任务：母球先碰 {r["n"]} 库，再碰到目标球；母球不得落袋。',font=font(29),fill=FG)
        d.text((54,897),'可先观察球形，再切换答案图查看这一组已验证的击球参数。',font=font(24),fill='#BCD0D5')
    d.text((54,1030),'原生物理数据的等比例研究图；不是App截图。本轮未做扰动或难度分级。',font=font(22),fill='#90A9B1')
    return im

for r in rows:
    for answer,suffix in [(True,''),(False,'-question')]:
        im=draw(r,answer)
        im.save(IM/(r['displayID']+suffix+'.png'))
        im.crop((130,140,1370,800)).save(IM/(r['displayID']+suffix+'-table.png'))

# The overview matches the requested three-column gallery, with one row per rail count.
sheet=Image.new('RGB',(1800,1580),BG);d=ImageDraw.Draw(sheet)
d.text((30,20),'解球筛选新版 · 一至三库为主 · 四库精选',font=font(38),fill=FG)
for n in range(1,5):
    group=[r for r in rows if r['n']==n]
    samples=[group[0],next(r for r in group if r['category']=='leftLight'),next(r for r in group if r['category']=='rightMedium')]
    for col,r in enumerate(samples):
        x,y=col*600,90+(n-1)*370
        s=r['seed'];spin='无塞' if s['sx']==0 else ('左塞' if s['sx']>0 else '右塞')+f'{abs(s["sx"]):.2f}R'
        d.text((x+20,y),f'{r["displayID"]} · {n}库 · {spin}',font=font(26),fill=FG)
        pic=Image.open(IM/(r['displayID']+'-table.png')).resize((580,309))
        sheet.paste(pic,(x+10,y+38))
sheet.save(OUT/'overview.png')

# Rejected empty-table prefixes, including an actual ABA return example.
rejectLabels={'short-first-leg':'首库行程不足20cm','shallow-angle':'入库角小于15°','steep-angle':'入库角大于75°',
              'opposite-wall-return':'相对两库 A→B→A 往返','rail-pocket-buffer':'接近袋口或非主直库'}
rejectImages=[]
for i,r in enumerate(json.loads((OUT/'rejected-routes.json').read_text())):
    im=Image.new('RGB',(1500,920),BG);d=ImageDraw.Draw(im)
    title=rejectLabels.get(r['reason'],r['reason'])
    d.text((50,30),'筛除示例 · '+title,font=font(36),fill=FG)
    s=r['seed'];d.text((50,88),f'前缀：{r["n"]}库 · 方向{s["slot"]*5}° · 杆速{s["v"]:.1f}m/s · 侧塞{s["sx"]:+.2f}R',font=font(25),fill='#BCD0D5')
    scale=450;cx,cy=750,460;L,W=g['length'],g['width']
    def xy(p):return cx+p[0]*scale,cy+p[1]*scale
    d.rectangle((cx-L/2*scale,cy-W/2*scale,cx+L/2*scale,cy+W/2*scale),fill='#20584E')
    for p in g['pockets']:
        x,y=xy(p['center']);rr=p['radius']*scale;d.ellipse((x-rr,y-rr,x+rr,y+rr),fill='#061B18')
        if p['lip']:d.polygon([xy(q) for q in p['lip']],fill='#061B18')
    pts=[xy(p[1:]) for p in r['track']]
    if len(pts)>1:d.line(pts,fill='#FFB18B',width=4)
    end=r['track'][-1][0];k=0
    for e in r['events']:
        if e['time']>end:break
        if e['kind']=='cushion' and e.get('ball')=='cueBall':
            k+=1;x,y=xy(e['cue']);d.ellipse((x-17,y-17,x+17,y+17),fill=BG,outline=ORANGE,width=2);d.text((x,y),str(k),font=font(22),anchor='mm',fill=FG)
    x,y=xy(s['cue']);rr=g['radius']*scale;d.ellipse((x-rr,y-rr,x+rr,y+rr),fill=FG)
    d.text((50,800),'未放目标球的实际路线；仅淘汰不合格前缀，保留更早的合格片段。',font=font(26),fill=FG)
    name=f'R{i+1:02d}';im.save(IM/(name+'.png'));rejectImages.append((name,title))
for i,r in enumerate(contrasts):
    r['displayID']=f'X{i+1:02d}';draw(r).save(IM/(r['displayID']+'.png'))

audit=json.loads((OUT/'audit.json').read_text())
spinLabels={'zero':'无塞','leftLight':'轻左塞','rightLight':'轻右塞','leftMedium':'中左塞','rightMedium':'中右塞'}
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>解球筛选新版 · 三列图册</title><style>
*{box-sizing:border-box}body{margin:0;background:#10222b;color:#edf3f2;font:16px/1.6 system-ui}main{min-width:0;max-width:1680px;margin:auto;padding:20px 24px 50px}h1{font-size:28px;margin:6px 0 10px}p{color:#bcd0d5;margin:8px 0}nav{display:flex;flex-wrap:wrap;gap:12px;align-items:center;position:sticky;top:0;z-index:2;background:#10222bf5;padding:12px 0}select,button{font:inherit;min-height:44px;background:#24444d;color:#edf3f2;border:1px solid #607b81;border-radius:7px;padding:6px 12px}a{color:#74cfff}summary{cursor:pointer;padding:10px 0}.cards{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:16px;align-items:start}article{min-width:0;background:#173139;border:1px solid #32515b;border-radius:9px;padding:12px}article h3{font-size:18px;margin:0 0 8px}article img{width:100%;height:auto;display:block;border-radius:5px}article p{font-size:14px;margin:7px 0 0}.sectionTitle{font-size:22px;margin:20px 0 12px}.badge{font-size:13px;color:#96c8d5;margin-left:8px}details{border-top:1px solid #36505a;margin-top:18px}details img{width:100%;height:auto}body.question .answerMeta{display:none}[hidden]{display:none!important}.rejects{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px}.rejects h3{font-size:16px}td,th{padding:6px 18px;border-bottom:1px solid #36505a}</style><main><h1>解球筛选新版 · 三列图册</h1>'''
page+=f'<p>一、二、三库各9题，四库精选6题，共{len(rows)}题。每个5°方向重新在所属网格内随机母球起点；覆盖无塞及四档左右塞。</p>'
page+=f'<p>{audit["candidates"]}道候选均经真实击球验证和独立重放。新增相对两库A→B→A往返过滤；跨路线几何去重合并{audit["merged"]}题。本轮未进行扰动或容错分级。</p>'
page+='<nav><label>库数 <select id="n" aria-label="库数"><option value="all">全部</option>'+''.join(f'<option value="{n}">{n}库</option>' for n in range(1,5))+'</select></label><label>杆法 <select id="spin" aria-label="杆法"><option value="all">全部</option>'+''.join(f'<option value="{k}">{v}</option>' for k,v in spinLabels.items())+'</select></label><button id="toggle" aria-pressed="true">隐藏答案</button><span id="count" role="status"></span></nav>'
for n in range(1,5):
    page+=f'<section class="group" data-n="{n}"><h2 class="sectionTitle">{n}库'+(' · 精选' if n==4 else '')+'</h2><div class="cards">'
    for r in [r for r in rows if r['n']==n]:
        name=r['displayID'];s=r['seed']
        page+=f'<article data-n="{n}" data-spin="{r["category"]}" id="{name}"><h3>{name}<span class="answerMeta"> · {spinLabels[r["category"]]}</span><span class="badge">真实重放通过</span></h3><a class="imageLink" href="images/{name}.png" data-answer="images/{name}.png" data-question="images/{name}-question.png" target="_blank" aria-label="放大{name}"><img src="images/{name}-table.png" data-answer="images/{name}-table.png" data-question="images/{name}-question-table.png" width="1240" height="660" loading="lazy" alt="{name}，{n}库解球"></a><p class="answerMeta">杆速 {s["v"]:.1f}m/s · 方向 {s["slot"]*5}° · 侧塞 {s["sx"]:+.2f}R</p><p>第{s["cell"]+1}格 · 点击球桌放大</p></article>'
    page+='</div></section>'
page+='''<details><summary>采样、筛选与去重口径</summary><p>四分之一台面6×12格，每5°独立随机起点；同一位置和方向共用四档力度、五档侧塞。0°沿世界+X向右、90°沿+Z向下。几何尺寸和球径取生产物理。</p><p>首库行程≥20cm；碰球前每库与切线夹角15°–75°；有限直库段端部留10cm；排除相对墙A→B→A。目标球合法、不提前碰到、实际库数及库序一致；完整击球后母球不得落袋。阈值仍属研究试验。</p><p>去重：库数与墙序相同，两球起点各相距不超过一个球直径，碰球前整段路线双向距离也在一个球直径内。路线采样间隔≤1cm并留5mm余量。代表题依次优先管道横向偏移小、杆速低、稳定ID；这不是难度排名。选题保留已验证原始参数，未移球或改杆法。</p>'''
page+=f'<p>实际空台{summary["baselineSimulations"]}次、生成阶段共{summary["simulations"]}次；候选覆盖{audit["acceptedCells"]}/72格，展示覆盖{audit["selectedCells"]}/72格。有限样例未证明全量覆盖，也未加入障碍球、镜像扩库或实台校准。</p></details>'
page+='<details><summary>筛除路线对照</summary><div class="rejects">'
for name,title in rejectImages:page+=f'<div><h3>{title}</h3><a href="images/{name}.png" target="_blank"><img src="images/{name}.png" loading="lazy" alt="{title}"></a></div>'
for r in contrasts:page+=f'<div><h3>加球后母球落袋 · {r["n"]}库</h3><a href="images/{r["displayID"]}.png" target="_blank"><img src="images/{r["displayID"]}.png" loading="lazy" alt="实际母球落袋对照"></a></div>'
page+='</div></details><details><summary>筛选统计和数据</summary><table><tr><th>原因（各阶段次数，分母不同）</th><th>次数</th></tr>'
for k,v in summary['rejections'].items():page+=f'<tr><td>{html.escape(rejectLabels.get(k,k))}</td><td>{v}</td></tr>'
page+='</table><p><a href="REPORT.md">本轮记录</a> · <a href="audit.json">独立审计</a> · <a href="deduplication.json">去重结果</a> · <a href="selected.json">图册数据</a> · <a href="http://127.0.0.1:51475/">旧版1–6库图册</a></p></details></main>'
page+='''<script>let answer=true;const n=document.querySelector('#n'),spin=document.querySelector('#spin'),cards=[...document.querySelectorAll('article')];function filter(){let count=0;for(const c of cards){c.hidden=!(n.value==='all'||c.dataset.n===n.value)||!(spin.value==='all'||c.dataset.spin===spin.value);if(!c.hidden)count++;}for(const s of document.querySelectorAll('.group'))s.hidden=![...s.querySelectorAll('article')].some(c=>!c.hidden);document.querySelector('#count').textContent=count+' 题';}n.onchange=spin.onchange=filter;document.querySelector('#toggle').onclick=function(){answer=!answer;document.body.classList.toggle('question',!answer);this.textContent=answer?'隐藏答案':'显示答案';this.setAttribute('aria-pressed',answer);for(const img of document.querySelectorAll('article img'))img.src=answer?img.dataset.answer:img.dataset.question;for(const a of document.querySelectorAll('.imageLink'))a.href=answer?a.dataset.answer:a.dataset.question;};filter();</script></html>'''
(OUT/'index.html').write_text(page)
print('RENDERED',len(rows),'cards in 3 columns; no perturbation metadata')
