"""Metric diagrams from engine evidence (not app screenshots)."""
from pathlib import Path
import json,math,html,collections,hashlib
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/kick-bank-sample-20261029'
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
    d.text((54,28),f'{name}  ·  {r["n"]} 库解球  ·  {spin}',font=font(36),fill=FG)
    d.text((54,86),f'杆速 {s["v"]:.1f} m/s     第一库 {r["baselineFirstAngle"]:.1f}°     横向偏移 {r["offsetR"]:+.2f}R',font=font(24),fill='#BCD0D5')
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
        layer=Image.new('RGBA',im.size);ld=ImageDraw.Draw(layer)
        pts=[xy(p[1:]) for p in r['baselineSegment']]
        if len(pts)>1:ld.line(pts,fill=(235,169,106,60),width=round(2*R*scale))
        im=Image.alpha_composite(im.convert('RGBA'),layer).convert('RGB');d=ImageDraw.Draw(im)
        def line(track,color,width,dashed=False):
            for i,(a,b) in enumerate(zip(track,track[1:])):
                if dashed and i%8>=4:continue
                d.line([xy(a[1:]),xy(b[1:])],fill=color,width=width)
        line(r['cueAfter'],'#94ABA8',2,True);line(r['targetTrack'],BLUE,2,True)
        line(r['baselineSegment'],ORANGE,2,True);line(r['cueTrack'],'#0A2E2D',7);line(r['cueTrack'],FG,3)
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
        d.text((54,818),'白实线：碰目标球前    橙带：空台出库管道    橙圈：接触时母球',font=font(24),fill=FG)
        d.text((54,860),'灰虚线：碰球后母球    蓝虚线：目标球    数字：实际碰库次序',font=font(24),fill='#BCD0D5')
        v=verification.get(r['id']);hits=sum(p['success'] for p in v['probes']) if v else None
        status=f'完整重跑通过 · 独立重放一致 · 微扰 {hits}/6' if r['success'] else '淘汰：'+{'scratch':'碰球后母球落袋'}.get(r['reason'],r['reason'])
        d.text((54,924),status,font=font(29),fill=BLUE if r['success'] else '#FFAC87')
        d.text((54,970),f'碰球前速度 {r.get("contactSpeed",0):.2f} m/s  ·  第 {s["cell"]+1} 格  ·  每题仅一颗目标球',font=font(23),fill='#BCD0D5')
    else:
        d.text((54,840),f'任务：母球先碰 {r["n"]} 库，再碰到目标球；母球不得落袋。',font=font(29),fill=FG)
        d.text((54,897),'可先观察球形，再切换答案图查看这一组已验证的击球参数。',font=font(24),fill='#BCD0D5')
    d.text((54,1030),'原生物理数据的等比例研究图；不是App截图。微扰计数不是人手成功率。',font=font(22),fill='#90A9B1')
    return im
for r in rows:
    for answer,suffix in [(True,''),(False,'-question')]:draw(r,answer).save(IM/(r['displayID']+suffix+'.png'))
for i,r in enumerate(contrasts):
    r['displayID']=f'X{i+1:02d}';draw(r).save(IM/(r['displayID']+'.png'))
# Compact, legible overview: one sample per cushion count, sixth panel describes scope.
overview=Image.new('RGB',(1600,1815),BG);od=ImageDraw.Draw(overview)
od.text((35,20),'颗星解球 · 一至五库首轮样题',font=font(40),fill=FG)
for n in range(1,6):
    r=next((x for x in rows if x['n']==n),None)
    if r:
        pic=Image.open(IM/(r['displayID']+'.png')).resize((780,567))
        overview.paste(pic,((n-1)%2*800,80+(n-1)//2*575))
od.text((840,1265),'完整流程已走通',font=font(36),fill=FG)
for i,t in enumerate(['72格母球 → 72段边界采样','角度与袋口筛选 → 空台模拟','每个出库段放3个独立目标','加入目标球 → 完整重跑','独立重放 → 六项微扰 → 出图']):od.text((840,1330+i*60),t,font=font(26),fill='#BCD0D5')
overview.save(OUT/'overview.png')
# Quantitative audit independent of generation's control flow.
allrows=json.loads((OUT/'accepted.json').read_text());checks=[]
for r in allrows:
    hit=next(e for e in r['events'] if e['kind']=='ballBall' and set(e['balls'])=={'cueBall','object'})
    rails=[e['rail'] for e in r['events'] if e['index']<hit['index'] and e['kind']=='cushion' and e.get('ball')=='cueBall']
    assert rails==r['rails'] and len(rails)==r['n']
    assert r['complete'] and 'cueBall' not in r['pocketedBalls']
    assert abs(r['offsetR'])<=.9 and abs(math.dist(r['target'],r['placementCenter'])-abs(r['offsetR'])*g['radius'])<1e-8
    assert 20<=r['baselineFirstAngle']<=(75 if r['n']==1 else 65)
    assert math.dist(r['target'],r['seed']['cue'])>2*g['radius']
    checks.append(r['id'])
assert all(v['exactReplay'] for v in verification.values()) and len(verification)==len(allrows)
bind=json.loads((OUT/'source-binding.json').read_text());drift=[]
for b in bind['sources']:
    if b['currentProduction'] and hashlib.sha256((ROOT/b['path']).read_bytes()).hexdigest()!=b['sha256']:drift.append(b['path'])
assert not drift,drift
audit={'checkedCandidates':len(checks),'selected':len(rows),'exactReplays':len(verification),'perturbationCount':len(allrows)*6,'perturbationsSucceeded':sum(sum(p['success'] for p in v['probes']) for v in verification.values()),'sourceDrift':drift,'acceptedCells':len({r['seed']['cell'] for r in allrows}),'selectedCells':len({r['seed']['cell'] for r in rows}),'images':len(list(IM.glob('*.png')))}
(OUT/'audit.json').write_text(json.dumps(audit,indent=2))
cards=[]
for r in rows:
    name=r['displayID'];v=verification[r['id']];hit=sum(p['success'] for p in v['probes'])
    cards.append(f'<article data-n="{r["n"]}" data-spin="{r["category"]}"><h2>{name} · {r["n"]}库 · 微扰 {hit}/6</h2><img src="images/{name}.png" data-answer="images/{name}.png" data-question="images/{name}-question.png" width="1500" height="1090" loading="lazy" alt="{name}，{r["n"]}库解球，含母球、目标球及实际轨迹"><p><a href="images/{name}.png">打开高清答案图</a> · <a href="images/{name}-question.png">打开题目图</a></p></article>')
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>颗星解球 · 首轮题库样本</title><style>body{margin:0;background:#10222b;color:#edf3f2;font:17px/1.7 system-ui}main{max-width:1260px;margin:auto;padding:28px}h1{font-size:34px}p{color:#bcd0d5}img{width:100%;height:auto;border-radius:12px}nav{display:flex;gap:12px;flex-wrap:wrap;position:sticky;top:0;background:#10222bf2;padding:16px 0;z-index:2}select,button{font:inherit;min-height:44px;background:#24444d;color:#edf3f2;border:1px solid #607b81;border-radius:8px;padding:8px 14px}article{margin:32px 0 58px}a{color:#74cfff}summary{cursor:pointer;padding:14px 0}.note{border-left:3px solid #eba96a;padding-left:18px}table{border-collapse:collapse}td,th{padding:8px 20px;border-bottom:1px solid #36505a}</style><main><h1>颗星解球 · 首轮题库样本</h1>'''
page+=f'<p>{summary["accepted"]}道候选通过完整重跑，展示{len(rows)}道代表题，一至五库各6道。已核对保存后的独立重放，并完成{audit["perturbationCount"]}次微扰。</p>'
page+='''<p class="note">这是题库生成研究图册，所有线路来自项目现有物理引擎；没有接入App，也不是原生界面截图。每个目标位置是一道独立题。无障碍球，按指定库数练习。</p><details><summary>查看流程、已确认规则与本轮假设</summary><p>流程：72个台面格各取一个母球点 → 两长库各24段、两短库各12段随机选点 → 检查5184条方向 → 每格抽2条可行方向组成小样 → 4档杆速×5档侧塞 → 空台模拟 → 每个出库段分前中后各取一个目标位置 → 加目标球完整重跑 → 按真实首次碰球前的库数及库序核验 → 独立重放和微扰。</p><p>已确认：多库第一库20°～65°，单库上限75°；目标球中心两侧±0.9R随机偏移；2～3个位置分别独立成题。本轮暂定：单库下限20°；直库段端部各留10厘米，碰球前每库均核对；近角区域为距两条矩形边各25厘米内，排除同时向两边外侧的方向，再检查真实出杆可达性；出库段两端各留9厘米放球余量；杆速1.5/2.5/3.5/4.5m/s；中杆打点y=0，侧向x=0/±0.25/±0.50R；最终候选一半无塞。首次碰球前库序须与空台来源一致，全杆停稳且母球不落袋，目标球进袋允许。</p><p>多库没有将第一库的角度限制套用到后续库。后续库仅检查直库及袋口距离。空台后段落袋不提前否决前段候选，实际结果由加球后的重跑裁定。微扰分别为方向±0.1°、杆速±3%、侧塞±0.02R，每次只改一项；比例不代表人手成功率。此次是配额选样，不是全量分布统计。</p></details>'''
page+=f'<p>实际空台模拟 {summary["baselineSimulations"]} 次，总生成阶段模拟 {summary["simulations"]} 次。候选覆盖 {audit["acceptedCells"]}/72 个起球格，展示覆盖 {audit["selectedCells"]}/72 格；按配额提前停止，尚未验证全台覆盖均匀性。</p>'
page+='''<nav><select id="n" aria-label="库数"><option value="all">全部库数</option>'''+''.join(f'<option value="{n}">{n}库</option>' for n in range(1,6))+'''</select><select id="spin" aria-label="杆法"><option value="all">全部杆法</option><option value="zero">中杆无塞</option><option value="left">左塞</option><option value="right">右塞</option></select><button id="toggle" aria-pressed="true">隐藏答案</button><span id="count" role="status"></span></nav>'''
page+=''.join(cards)+'<details><summary>查看未通过的对照图</summary>'
for r in contrasts:page+=f'<h2>{r["displayID"]} · {r["n"]}库候选 · 母球落袋</h2><img src="images/{r["displayID"]}.png" width="1500" height="1090" loading="lazy" alt="候选题失败对照">'
page+='</details><details><summary>筛选统计与数据</summary><table><tr><th>筛除原因（各阶段累计）</th><th>数量</th></tr>'
labels={'baseline-angle':'第一库角度不符当前库数','baseline-rail-pocket-buffer':'途中碰库过近袋口/非直库','earlier-path-overlap':'目标位置与更早轨迹重叠','scratch':'加入目标球后母球落袋','segment-too-short':'出库段过短'}
for k,v in summary['rejections'].items():page+=f'<tr><td>{html.escape(labels.get(k,k))}</td><td>{v}</td></tr>'
page+='</table><p><a href="REPORT.md">试验报告</a> · <a href="audit.json">独立审计</a> · <a href="selected.json">图册题目数据</a> · <a href="accepted.json">全部120题</a> · <a href="verification.json">重放与微扰明细</a></p></details></main><script>let answer=true;const n=document.querySelector("#n"),spin=document.querySelector("#spin"),cards=[...document.querySelectorAll("article")];function filter(){let count=0;for(const c of cards){c.hidden=!(n.value==="all"||c.dataset.n===n.value)||!(spin.value==="all"||c.dataset.spin===spin.value);if(!c.hidden)count++;}document.querySelector("#count").textContent=count+" 道";}n.onchange=spin.onchange=filter;document.querySelector("#toggle").onclick=function(){answer=!answer;this.textContent=answer?"隐藏答案":"显示答案";this.setAttribute("aria-pressed",answer);for(const img of document.querySelectorAll("article img")){img.src=answer?img.dataset.answer:img.dataset.question;}};filter();</script></html>'
(OUT/'index.html').write_text(page)
print('RENDERED',audit,flush=True)
