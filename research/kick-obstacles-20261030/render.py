"""Measured geometry/trajectories only; three-column offline review gallery."""
from pathlib import Path
import json,html,math
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/kick-obstacles-20261030';IM=OUT/'images';IM.mkdir(exist_ok=True)
g=json.loads((ROOT/'output/kick-grid-filtered-20261030/geometry.json').read_text());R=g['radius']
requests=[]
for name in ['placed.json','placed-extra.json','placed-refined.json','placed-next.json','placed-additional.json','placed-last.json','placed-final.json']:
    if (OUT/name).exists():requests+=json.loads((OUT/name).read_text())
if (OUT/'placed-run.json').exists():requests=json.loads((OUT/'placed-run.json').read_text())
accepted=[];fail=[]
for req in requests:
    q=OUT/(req['id']+'-check.json')
    if not q.exists():continue
    check=json.loads(q.read_text())
    if check.get('referencePassed') and check.get('exactReplay') and check.get('lowerSolutionCount')==0 and check.get('incomplete')==0:
        accepted.append(dict(req,check=check,scan=json.loads((OUT/(req['id']+'-scan.json')).read_text())))
    else:fail.append({'id':req['id'],'referencePassed':check.get('referencePassed'),'lowerSolutionCount':check.get('lowerSolutionCount'),'incomplete':check.get('incomplete')})
(OUT/'accepted.json').write_text(json.dumps([{k:v for k,v in r.items() if k not in ['scan']} for r in accepted]))
(OUT/'check-failures.json').write_text(json.dumps(fail,indent=2))
def xy(p):return (p[0]+1.37)*450,(p[1]+.735)*450

def svg(r,mode):
    row=r['row'];reference=r['check']['reference'];c=row['seed']['cue'];target=row['target'];bs=r['obstacles']
    s=['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1233 661.5">','<rect width="1233" height="661.5" rx="25" fill="#554336"/>','<rect x="45" y="45" width="1143" height="571.5" fill="#20584e"/>']
    for p in g['pockets']:
        x,y=xy(p['center']);s.append(f'<circle cx="{x}" cy="{y}" r="{p["radius"]*450}" fill="#071915"/>')
        if p['lip']:s.append('<polygon points="'+' '.join(f'{x},{y}' for x,y in map(xy,p['lip']))+'" fill="#071915"/>')
    for rail in g['rails']:
        a,b=xy(rail['start']),xy(rail['end']);s.append(f'<path d="M{a[0]} {a[1]} L{b[0]} {b[1]}" stroke="#79a699" stroke-width="3"/>')
    def track(points,color,width=3,dashed=False):
        p=' '.join(f'{x},{y}' for x,y in (xy(p[1:]) for p in points));dash='stroke-dasharray="12 9"' if dashed else ''
        s.append(f'<polyline points="{p}" stroke="{color}" stroke-width="{width}" fill="none" {dash}/>')
    if mode=='blocked':
        # Choose one measured no-obstacle route per main-wall sequence; label as old paths.
        chosen=[];seen=set()
        for a in r['scan']['solutions']:
            key=tuple(a['rails'])
            if key not in seen:chosen.append(a);seen.add(key)
            if len(chosen)>=5:break
        for a in chosen:track(a['track'],'#efac80',4,True)
    if mode=='answer':
        track(reference['cueTrack'],'#edf3f2',4)
        hits=[e for e in reference['events'] if e['kind']=='cushion' and e.get('ball')=='cueBall' and e['time']<reference['contactTime']]
        for i,e in enumerate(hits):
            x,y=xy(e['cue']);dx,dy=616.5-x,330.75-y;ln=math.hypot(dx,dy);x+=dx/ln*20;y+=dy/ln*20
            s.append(f'<circle cx="{x}" cy="{y}" r="12" fill="#10222b" stroke="#eba96a" stroke-width="2"/><text x="{x}" y="{y+6}" text-anchor="middle" fill="white" font-family="sans-serif" font-size="17">{i+1}</text>')
        points=reference['cueTrack']
        for frac in [.2,.5,.8]:
            k=max(1,int((len(points)-1)*frac));x,y=xy(points[k][1:]);a,b=xy(points[k-1][1:]);theta=math.atan2(y-b,x-a)
            pts=[(x+10*math.cos(theta),y+10*math.sin(theta)),(x-9*math.cos(theta-.5),y-9*math.sin(theta-.5)),(x-9*math.cos(theta+.5),y-9*math.sin(theta+.5))]
            s.append('<polygon points="'+' '.join(f'{a},{b}' for a,b in pts)+'" fill="#edf3f2"/>')
    for p,label,color in [(c,'母','#edf3f2'),(target,'目','#56bff5')]+[(b,str(i+1),'#d97c79') for i,b in enumerate(bs)]:
        x,y=xy(p);s.append(f'<circle cx="{x}" cy="{y}" r="{R*450}" fill="{color}" stroke="#10222b" stroke-width="2"/><text x="{x}" y="{y+5}" font-size="14" text-anchor="middle" font-family="sans-serif" fill="#10222b">{label}</text>')
    return ''.join(s)+'</svg>'
for r in accepted:
 for mode in ['answer','blocked','question']:(IM/f'{r["id"]}-{mode}.svg').write_text(svg(r,mode))
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>解球 · 障碍球小样</title><style>
*{box-sizing:border-box}body{margin:0;background:#10222b;color:#edf3f2;font:16px/1.6 system-ui}main{max-width:1680px;margin:auto;padding:20px 24px 50px}h1{font-size:28px;margin:6px 0 10px}p{color:#bcd0d5}nav{display:flex;flex-wrap:wrap;gap:12px;align-items:center;position:sticky;top:0;z-index:2;background:#10222bf5;padding:12px 0}select,button{font:inherit;min-height:44px;background:#24444d;color:#edf3f2;border:1px solid #607b81;border-radius:7px;padding:6px 12px}a{color:#74cfff}.cards{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:16px}article{min-width:0;background:#173139;border:1px solid #32515b;border-radius:9px;padding:12px}article h3{font-size:18px;margin:0 0 8px}article img{width:100%;height:auto;display:block}article p{font-size:14px;margin:8px 0}.badge{font-size:13px;color:#96c8d5}.subtitle{font-size:15px}details{border-top:1px solid #36505a;margin-top:24px}summary{cursor:pointer;padding:12px 0}body.question .answerMeta{display:none}[hidden]{display:none!important}.legend{font-size:14px;color:#bcd0d5}.pass{color:#a6d9b3}</style><main><h1>解球 · 障碍球小样</h1>'''
page+=f'<p>共{len(accepted)}题：白色母球、蓝色目标球、红色障碍球。先碰到障碍球即失败；同库数及更多库解法允许。每行3题。</p>'
page+='<nav><label>库数 <select id="n" aria-label="库数"><option value="all">全部</option><option value="1">1库</option><option value="2">2库</option></select></label><label>展示 <select id="mode" aria-label="展示"><option value="answer">参考解法</option><option value="blocked">被挡路线</option><option value="question">只看球形</option></select></label><span id="count" role="status"></span></nav><p id="legend" class="legend">白线为加入障碍球后的实际参考轨迹，数字为碰库顺序。点击球桌放大。</p>'
for n in [1,2]:
    group=[r for r in accepted if r['row']['n']==n]
    page+=f'<section class="group"><h2>{n}库 · '+('封住直达' if n==1 else '封住直达和1库')+'</h2><div class="cards">'
    for r in group:
        s=r['row']['seed'];spin='无塞' if s['sx']==0 else ('左塞' if s['sx']>0 else '右塞')+f' {abs(s["sx"]):.2f}R'
        nalt=r['scan']['lowerSolutionCount'];once=sum(a['n']==1 for a in r['scan']['solutions'])
        roles=[]
        for a in r['placement']['assignments']:
            duties=(['直达通道'] if a['blocksDirectCone'] else [])+(['部分1库路线'] if 1 in a['blockedRailCounts'] else [])
            roles.append(f'障碍{a["blocker"]}：'+('、'.join(duties) or '补充封堵'))
        page+=f'<article data-n="{n}" id="{r["id"]}"><h3>{r["id"]} · {len(r["obstacles"])}颗障碍球</h3><a class="imageLink" href="images/{r["id"]}-answer.svg" target="_blank" aria-label="放大{r["id"]}"><img src="images/{r["id"]}-answer.svg" alt="{r["id"]}，{n}库障碍球解球" width="1233" height="662"></a><p class="answerMeta">{spin} · 杆速{s["v"]:.1f}m/s · 方向{s["slot"]*5}°</p><p class="answerMeta">'+ '<br>'.join(roles) +f'</p><p class="pass answerMeta">参考解法通过并重放一致</p><p class="answerMeta">加障碍前发现{nalt}组少库打法'+(f'（含{once}组1库）' if n==2 else '')+f'；加入后加密检索未发现少库解。</p><p class="badge">0.5° × 8档杆速 × 9档侧塞<br>有限搜索结果，不代表数学唯一解。</p></article>'
    page+='</div></section>'
page+='''<details><summary>搜索范围与判断边界</summary><p>固定母球、目标球，先在全方向1°间隔、杆速1.5/2.5/3.5/4.5m/s、侧塞0/±0.25R/±0.5R下找少库解。障碍球摆好后，使用全方向0.5°间隔、杆速1至4.5m/s每0.5一档、侧塞−0.5R至+0.5R每0.125R一档复查；纵向打点为0。没有运行扰动、容错或难度评分。</p><p>替代路线不套用首库距离、入库角等选样过滤。必须先碰目标球、母球不落袋且完整模拟结束；碰球后可以再撞障碍球。搜索只排除小于题目库数的解，同库或更多库解不影响收录。</p><p>每题最多3颗障碍球，位置来自实际路线的遮挡与避让；参考打法加入所有球后完整重算并原参数重放。直达还做球体扫掠的角域遮挡检查，不只挡球心连线。被挡路线图画的是“加入障碍前”的实际可行路径，虚线不表示球能穿过障碍。</p><p>这是离线研究图，不是App截图。尚未覆盖连续角度/力度/打点、其他高低杆、跳球或扎杆，不宣称绝对最少库数或唯一解；未做实台校准。</p></details><p><a href="REPORT.md">本轮报告</a> · <a href="audit.json">验证证据</a> · <a href="http://127.0.0.1:51476/">上一版无障碍图册</a></p></main><script>
const n=document.querySelector('#n'),mode=document.querySelector('#mode');function update(){let count=0;for(const c of document.querySelectorAll('article')){c.hidden=n.value!=='all'&&c.dataset.n!==n.value;if(!c.hidden)count++;const src='images/'+c.id+'-'+mode.value+'.svg';c.querySelector('img').src=src;c.querySelector('a').href=src;}for(const g of document.querySelectorAll('.group'))g.hidden=![...g.querySelectorAll('article')].some(c=>!c.hidden);document.querySelector('#count').textContent=count+' 题';document.body.classList.toggle('question',mode.value==='question');document.querySelector('#legend').textContent=mode.value==='answer'?'白线为加入障碍球后的实际参考轨迹，数字为碰库顺序。点击球桌放大。':mode.value==='blocked'?'橙色虚线：加障碍前可行的直达/少库路线代表。红球标出封堵位置；图示不表示能够穿过障碍。':'先观察球形，选择解球路线；母球应先碰指定库数，再首次碰到蓝色目标球，且不得落袋。';}n.onchange=mode.onchange=update;update();</script></html>'''
(OUT/'index.html').write_text(page);print('RENDER',len(accepted),'accepted;',len(fail),'rejected')
