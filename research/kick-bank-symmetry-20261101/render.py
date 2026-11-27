"""Three-column atlas of frozen bank layouts; tracks are transformed source evidence."""
from pathlib import Path
import collections
import gzip
import html
import json

ROOT=Path(__file__).resolve().parents[2]
OLD=ROOT/'output/kick-bank-full-20261031'
OUT=ROOT/'output/kick-bank-symmetry-20261101'
audit=json.loads((OUT/'audit.json').read_text())
index=json.loads((OUT/'bank-index.json').read_text())
sample=json.loads((OUT/'sample.json').read_text())
bank={q['id']:q for q in json.loads((OUT/'kick-practice-bank.json').read_text())['questions']}
g=json.loads((OUT/'geometry.json').read_text())
names=['不变','左右镜像','上下镜像','中心对称']
chosen=[]
for n in range(1,5):
    for t in range(4):
        chosen += [r for r in sample if r['n']==n and r['transform']==t][:3 if n==t+1 else 2]
assert len(chosen)==36
by_cell=collections.defaultdict(list)
for r in chosen: by_cell[r['cell']].append(r)
rows=[]
for cell, records in by_cell.items():
    candidates=json.loads(gzip.decompress((OLD/f'cells/{cell:02d}/accepted.json.gz').read_bytes()))
    if isinstance(candidates,dict): candidates=candidates['accepted']
    candidates={r['id']:r for r in candidates}
    for r in records:
        q=bank[r['id']]; source=candidates[r['id']];t=r['transform']
        sx=-1 if t in [1,3] else 1;sz=-1 if t in [2,3] else 1
        rows.append(dict(q,n=r['n'],transform=t,cell=cell,rails=r['rails'],
                         track=[[sx*p[1],sz*p[2]] for p in source['cueTrack']],
                         contacts=[[sx*e['cue'][0],sz*e['cue'][1]] for e in source['events']
                                   if e['time']<source['contactTime'] and e['kind']=='cushion' and e.get('ball')=='cueBall']))
rows.sort(key=lambda r:(r['n'],r['transform'],r['id']))
assert all(len(r['contacts'])==r['n'] for r in rows)
(OUT/'selected.json').write_text(json.dumps(rows,separators=(',',':'))+'\n')
tokens=['btBallRoleCurrent','btBallRoleNext','btBallRoleUpcoming','btPracticeRailCoral']
colors=[]
for token in tokens:
    asset=json.loads((ROOT/'QiuJi/Resources/Assets.xcassets'/f'{token}.colorset/Contents.json').read_text())
    c=next(v for v in asset['colors'] if not v.get('appearances'))['color']['components']
    colors.append('#'+''.join(f'{(int(c[k],16) if c[k].startswith("0x") else round(float(c[k])*255)):02x}' for k in ['red','green','blue']))
scale=260;cx,cy=400,220;L,W,R=g['length'],g['width'],g['radius']
def xy(p):return cx+p[0]*scale,cy+p[1]*scale
def fmt(p):return ','.join(f'{v:.3f}' for v in xy(p))
def svg(r):
    s=f'<svg viewBox="0 0 800 440" role="img" aria-label="{r["n"]}库，{names[r["transform"]]}球形"><rect x="{cx-L*scale/2-20}" y="{cy-W*scale/2-20}" width="{L*scale+40}" height="{W*scale+40}" rx="16" fill="#554336"/><rect x="{cx-L*scale/2}" y="{cy-W*scale/2}" width="{L*scale}" height="{W*scale}" fill="#20584e"/>'
    for p in g['pockets']:
        x,y=xy(p['center']);s+=f'<circle cx="{x}" cy="{y}" r="{p["radius"]*scale}" fill="#071f1c"/>'
        if p['lip']:s+='<polygon points="'+' '.join(fmt(q) for q in p['lip'])+'" fill="#071f1c"/>'
    for order,id in enumerate(r['rails']):
        rail=g['rails'][id];visits=[i for i,v in enumerate(r['rails']) if v==id];part=visits.index(order)
        a=[min(rail['start'][j],rail['end'][j]) for j in range(2)]
        b=[max(rail['start'][j],rail['end'][j]) for j in range(2)]
        p=[a[j]+(b[j]-a[j])*part/len(visits)-rail['normal'][j]*.025 for j in range(2)]
        q=[a[j]+(b[j]-a[j])*(part+1)/len(visits)-rail['normal'][j]*.025 for j in range(2)]
        s+=f'<path d="M{fmt(p)} L{fmt(q)}" stroke="{colors[order]}" stroke-width="5"/>'
    s+='<g class="answer"><polyline points="'+' '.join(fmt(p) for p in r['track'])+'" fill="none" stroke="#e6ebeb" stroke-width="1.7"/>'
    for order,p in enumerate(r['contacts']):
        x,y=xy(p);x=cx+(x-cx)*.93;y=cy+(y-cy)*.88
        s+=f'<circle cx="{x}" cy="{y}" r="10" fill="{colors[order]}"/><text x="{x}" y="{y+4}" text-anchor="middle" font-size="13" fill="#17212b">{order+1}</text>'
    s+='</g>'
    for key,c in [('cue','#fff'),('target','#ebbc49')]:
        x,y=xy([r[key]['x'],r[key]['z']]);s+=f'<circle cx="{x}" cy="{y}" r="{R*scale}" fill="{c}" stroke="#132d2c"/>'
    return s+'</svg>'
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>解球题库 · 全桌覆盖</title><style>
*{box-sizing:border-box}body{background:#10222b;color:#edf3f2;font:16px/1.6 system-ui;margin:0}main{max-width:1680px;margin:auto;padding:24px}h1{font-size:28px;margin:0}p{color:#bcd0d5}nav{position:sticky;top:0;background:#10222bf5;display:flex;flex-wrap:wrap;gap:14px;padding:12px 0;z-index:1}select,button{font:inherit;color:#edf3f2;background:#24444d;border:1px solid #607b81;border-radius:7px;padding:8px 12px;min-height:44px}.cards{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:16px}article{min-width:0;background:#173139;border:1px solid #32515b;border-radius:9px;padding:12px}article h3{margin:0;font-size:18px}svg{width:100%;display:block}article p{font-size:14px;margin:4px 0;overflow-wrap:anywhere}.hide .answer{visibility:hidden}[hidden]{display:none!important}.heat{display:grid;grid-template-columns:repeat(24,1fr);gap:3px;max-width:1000px}.heat span{padding:4px 0;text-align:center;font-size:11px}table{border-collapse:collapse}td,th{padding:8px 15px;border-bottom:1px solid #36505a}a{color:#74cfff}details{margin:20px 0}summary{cursor:pointer}.badge{display:inline-block;min-width:22px;text-align:center;color:#17212b;border-radius:4px}</style><main><h1>解球题库 · 全桌覆盖</h1>'''
page+='<p>53,928题，每题提前固定一种变换；不变、左右镜像、上下镜像、中心对称各13,482题。重打和再次打开不会重新随机。</p><p>颜色跟随顺序：第一库蓝 → 第二库金 → 第三库紫 → 第四库珊瑚；未涉及的库边保持原色。</p><table><tr><th>库数</th>'+''.join(f'<th>{n}</th>' for n in names)+'<th>合计</th></tr>'
for n,counts in audit['perRail'].items():page+=f'<tr><td>{n}库</td>'+''.join(f'<td>{c:,}</td>' for c in counts)+f'<td>{sum(counts):,}</td></tr>'
page+='</table><details><summary>全桌288格覆盖 · 每格题数</summary><p>每个象限12×6格，四个象限均覆盖。1–4库每一类均覆盖全部288格。</p><div class="heat">'
raymap={r['cell']:(r['ix'],r['iz']) for r in json.loads((OLD/'sampling.json').read_text())['rays']}
cells=collections.Counter()
for r in index:
    x,z=raymap[r['cell']];t=r['transform'];x=23-x if t in [1,3] else x;z=11-z if t in [2,3] else z
    cells[x,z]+=1
assert len(cells)==288 and sum(cells.values())==53928
for z in range(12):
    for x in range(24):
        c=cells[x,z];page+=f'<span style="background:rgba(57,161,141,{.15+.75*c/max(cells.values())})" title="({x+1},{z+1})">{c}</span>'
page+='</div></details><nav><label>库数 <select id="n"><option value="all">全部</option>'+''.join(f'<option>{n}</option>' for n in range(1,5))+'</select></label><label>变换 <select id="t"><option value="all">全部</option>'+''.join(f'<option value="{t}">{name}</option>' for t,name in enumerate(names))+'</select></label><button id="toggle">隐藏轨迹</button><span id="count"></span></nav><div class="cards">'
for i,r in enumerate(rows):
    spin=r['input']['spinX'];spinLabel='无塞' if spin==0 else ('左塞' if spin>0 else '右塞')+f' {abs(spin):.2f}'
    chips=' → '.join(f'<span class="badge" style="background:{colors[j]}">{j+1}</span>' for j in range(r['n']))
    page+=f'<article data-n="{r["n"]}" data-t="{r["transform"]}"><h3>{i+1:02d} · {r["n"]}库　{chips}</h3>{svg(r)}<p>{names[r["transform"]]}</p><p class="answer">{spinLabel} · 杆速 {r["input"]["velocity"]:.1f}m/s</p><p>{html.escape(r["id"])}</p></article>'
page+='</div><details><summary>数据来源与验证范围</summary><p>图中球位和参数来自新App题库，折线由已验证原题轨迹作相同对称变换得到，属于等比例示意图，不是App截图。36道示例均纳入463道分层生产重放样本；重放结果以验证回执为准。</p><p>沿用原题筛选、库数分布和题目ID；无扰动、无障碍球或少库排他搜索。碰球后再次碰库仍仅用于实际作答，不据此删题。</p><p><a href="audit.json">变换审计</a> · <a href="validation.json">App验证回执</a> · <a href="kick-practice-bank.json">题库文件</a></p></details></main><script>const cards=[...document.querySelectorAll("article")];function filter(){const n=document.querySelector("#n").value,t=document.querySelector("#t").value;for(const c of cards)c.hidden=(n!=="all"&&c.dataset.n!==n)||(t!=="all"&&c.dataset.t!==t);document.querySelector("#count").textContent=cards.filter(c=>!c.hidden).length+"题"}for(const e of document.querySelectorAll("select"))e.onchange=filter;filter();document.querySelector("#toggle").onclick=function(){const hide=document.body.classList.toggle("hide");this.textContent=hide?"显示轨迹":"隐藏轨迹"}</script></html>'
(OUT/'index.html').write_text(page)
print('36 examples, 9 per rail count and symmetry; 288 populated cells, three cards per row')
