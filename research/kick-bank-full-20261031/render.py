"""Bounded 36-question review atlas, three cards per row, using measured tracks."""
from pathlib import Path
import json,html,collections
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/kick-bank-full-20261031'
g=json.loads((OUT/'geometry.json').read_text());audit=json.loads((OUT/'audit.json').read_text())
rows=json.loads((OUT/'selected.json').read_text());index=json.loads((OUT/'bank-index.json').read_text())
L,W,R=g['length'],g['width'],g['radius'];scale=260;cx,cy=400,220
tokens=['btBallRoleCurrent','btBallRoleNext','btBallRoleUpcoming','btPracticeRailCoral','btPracticeRailTeal','btPracticeRailOrange']
colors=[]
for token in tokens:
    asset=json.loads((ROOT/'QiuJi/Resources/Assets.xcassets'/f'{token}.colorset'/'Contents.json').read_text())
    c=next(v for v in asset['colors'] if not v.get('appearances'))['color']['components']
    colors.append('#'+''.join(f'{(int(c[k],16) if c[k].startswith('0x') else round(float(c[k])*255)):02x}' for k in ['red','green','blue']))
def xy(p):return cx+p[0]*scale,cy+p[1]*scale
def fmt(p):return ','.join(f'{v:.3f}' for v in xy(p))
def svg(r):
    s=f'<svg viewBox="0 0 800 440" role="img" aria-label="{r["n"]}库实测轨迹"><rect x="{cx-L*scale/2-20}" y="{cy-W*scale/2-20}" width="{L*scale+40}" height="{W*scale+40}" rx="16" fill="#554336"/><rect x="{cx-L*scale/2}" y="{cy-W*scale/2}" width="{L*scale}" height="{W*scale}" fill="#20584e"/>'
    for p in g['pockets']:
        x,y=xy(p['center']);s+=f'<circle cx="{x}" cy="{y}" r="{p["radius"]*scale}" fill="#071f1c"/>'
        if p['lip']:s+='<polygon points="'+' '.join(fmt(q) for q in p['lip'])+'" fill="#071f1c"/>'
    for i,rail in enumerate(g['rails']):
        x,y=xy([rail['start'][j]-rail['normal'][j]*.045 for j in range(2)]);xx,yy=xy([rail['end'][j]-rail['normal'][j]*.045 for j in range(2)])
        s+=f'<path d="M{x},{y} L{xx},{yy}" stroke="{colors[i]}" stroke-width="8"/>'
    s+='<g class="answer"><polyline points="'+' '.join(fmt(p[1:]) for p in r['cueTrack'])+'" fill="none" stroke="#e6ebeb" stroke-width="1.7"/>'
    no=0
    for e in r['events']:
        if e['time']>=r['contactTime']:break
        if e['kind']=='cushion' and e.get('ball')=='cueBall':
            no+=1;x,y=xy(e['cue']);x=cx+(x-cx)*.92;y=cy+(y-cy)*.88
            s+=f'<circle cx="{x}" cy="{y}" r="9" fill="#10222b" stroke="{colors[e["rail"]]}"/><text x="{x}" y="{y+4}" text-anchor="middle" font-size="12" fill="white">{no}</text>'
    s+='</g>'
    for p,c in [(r['seed']['cue'],'#fff'),(r['target'],'#ebbc49')]:
        x,y=xy(p);s+=f'<circle cx="{x}" cy="{y}" r="{R*scale}" fill="{c}" stroke="#132d2c"/>'
    return s+'</svg>'
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>解球全库 · 覆盖与样题</title><style>
*{box-sizing:border-box}body{background:#10222b;color:#edf3f2;font:16px/1.6 system-ui;margin:0}main{max-width:1680px;margin:auto;padding:24px}h1{font-size:28px;margin:0}p{color:#bcd0d5}nav{position:sticky;top:0;background:#10222bf5;display:flex;gap:14px;padding:12px 0;z-index:1}select,button{font:inherit;color:#edf3f2;background:#24444d;border:1px solid #607b81;border-radius:7px;padding:8px 12px;min-height:44px}.cards{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:16px}article{min-width:0;background:#173139;border:1px solid #32515b;border-radius:9px;padding:12px}article h3{margin:0;font-size:18px}svg{width:100%;display:block}article p{font-size:14px;margin:4px 0}.hide .answer{visibility:hidden}[hidden]{display:none!important}.heat{display:grid;grid-template-columns:repeat(12,1fr);gap:4px;max-width:800px}.heat span{padding:8px 0;text-align:center;border:1px solid #436970;font-size:13px}table{border-collapse:collapse}td,th{padding:8px 22px;border-bottom:1px solid #36505a}a{color:#74cfff}details{margin:20px 0}summary{cursor:pointer}</style><main><h1>解球全库 · 覆盖与样题</h1>'''
page+=f'<p>103,680组输入已完整扫描，{audit["candidates"]["total"]:,}条候选经过逐条精确重放；几何去重后入库 {audit["bank"]["total"]:,}题。下方从全库选36道实测样题，每行3道。</p><table><tr><th>库数</th><th>入库题数</th><th>有效起点网格</th></tr>'
for n in range(1,5):page+=f'<tr><td>{n}库</td><td>{audit["bank"]["perRail"][str(n)]:,}</td><td>{audit["bank"]["perRailCells"][str(n)]}/72</td></tr>'
page+='</table><details><summary>72格覆盖 · 每格入库数</summary><p>四分之一台面，横向12格、纵向6格。每5°方向重新随机母球位置。</p><div class="heat">'
c=collections.Counter(r['cell'] for r in index)
raymap={r['cell']:(r['ix'],r['iz']) for r in json.loads((OUT/'sampling.json').read_text())['rays']}
for cell in sorted(raymap,key=lambda k:(raymap[k][1],raymap[k][0])):
    alpha=.15+.75*c[cell]/max(c.values());page+=f'<span style="background:rgba(57,161,141,{alpha})" title="第{cell+1}格">{c[cell]}</span>'
page+='</div></details><nav><label>库数 <select id="n"><option value="all">全部</option>'+''.join(f'<option>{n}</option>' for n in range(1,5))+'</select></label><button id="toggle">隐藏轨迹</button><span id="count"></span></nav><div class="cards">'
for r in rows:
    s=r['seed'];spin='无塞' if s['sx']==0 else ('左塞' if s['sx']>0 else '右塞')+f' {abs(s["sx"]):.2f}R'
    chips=' → '.join(f'<span style="color:{colors[i]}">●</span>' for i in r['rails'])
    page+=f'<article data-n="{r["n"]}"><h3>{r["displayID"]} · {r["n"]}库 <span>{chips}</span></h3>{svg(r)}<p class="answer">{spin} · {s["v"]:.1f}m/s · {s["slot"]*5}°</p><p>第{s["cell"]+1}格 · {html.escape(r["id"])}</p></article>'
page+='</div><details><summary>范围与筛选口径</summary><p>72格 × 72方向 × 4档杆速 × 5档侧塞；每组分别寻找1–4库的第一个合格目标球位置。首库行程≥20cm、每次入库与切线夹角15°–75°、直库端部留10cm；排除相对两库往返、提前碰球、母球落袋、杆身无法击球及不完整模拟。</p><p>库数和库序相同，两球位置及整条路线足够接近才合并；保留完整原始题目，未调整入选题目的坐标或参数。没有扰动、障碍球、少库排他搜索、5–6库、镜像扩展或实台校准。</p><p>图为生产物理数据的等比例示意，不是App截图。白线只展示碰球前路线；参考参数不保证满足用户实际作答新增的碰球后碰库判罚，题库不据此删题。</p><p><a href="audit.json">审计统计</a> · <a href="deduplication.json">去重映射</a> · <a href="kick-practice-bank.json">App题库</a></p></details></main><script>const cards=[...document.querySelectorAll("article")];document.querySelector("#n").onchange=function(){for(const c of cards)c.hidden=this.value!=="all"&&c.dataset.n!==this.value;document.querySelector("#count").textContent=cards.filter(c=>!c.hidden).length+"题"};document.querySelector("#n").onchange();document.querySelector("#toggle").onclick=function(){const hide=document.body.classList.toggle("hide");this.textContent=hide?"显示轨迹":"隐藏轨迹"}</script></html>'
(OUT/'index.html').write_text(page)
print('36-card, three-column full-bank atlas written')
