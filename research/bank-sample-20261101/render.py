from pathlib import Path
import json,math,html
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/bank-sample-20261101'
rows=json.loads((OUT/'selected.json').read_text());g=json.loads((OUT/'geometry.json').read_text())
COLORS=['#56BFF5','#F6C65B','#C3A4F4','#F49A84'];WALLS=['左短库','右短库','上长库','下长库'];PK=['左上底袋','右上底袋','左下底袋','右下底袋','上中袋','下中袋']
def svg(r):
    scale=300;cx,cy=450,242
    def xy(p):return cx+p[0]*scale,cy+p[1]*scale
    def coords(points):return ' '.join(f'{x:.3f},{y:.3f}' for x,y in map(xy,points))
    def line(points,color,width=2,extra=''):
        return f'<polyline points="{coords(points)}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round" {extra}/>'
    def circle(p,radius,fill,extra=''):
        x,y=xy(p);return f'<circle cx="{x:.3f}" cy="{y:.3f}" r="{radius:.3f}" fill="{fill}" {extra}/>'
    L,H,R=g['length'],g['width'],g['radius'];x0,y0=xy([-L/2,-H/2])
    a=[f'<svg viewBox="0 0 900 485" role="img" aria-label="{r["id"]} {r["n"]}库翻袋球形与实际路线" xmlns="http://www.w3.org/2000/svg">',f'<rect x="{x0-22}" y="{y0-22}" width="{L*scale+44}" height="{H*scale+44}" rx="16" fill="#554438"/>',f'<rect x="{x0}" y="{y0}" width="{L*scale}" height="{H*scale}" fill="#23594f"/>']
    for pk in g['pockets']:
        a.append(circle(pk['center'],pk['radius']*scale,'#071d1a'))
        if pk['lip']:a.append(f'<polygon points="{coords(pk["lip"])}" fill="#071d1a"/>')
    for q in g['rails']:a.append(line([q['start'],q['end']],'#81a899',2))
    for k in [1,2,3,5,6,7]:
        for sign in [-1,1]:a.append(circle([-L/2+k*L/8,sign*(H/2+.045)],1.7,'#d5c8ae'))
    for k in [1,2,3]:
        for sign in [-1,1]:a.append(circle([sign*(L/2+.045),-H/2+k*H/4],1.7,'#d5c8ae'))
    a.append(circle(g['pockets'][r['pocket']]['center'],20,'none','stroke="#56BFF5" stroke-width="3"'))
    hits=[e for e in r['events'] if e['kind']=='cushion' and e['ball']=='object' and 0<=e['rail']<6 and e['time']<r['potTime']]
    byrail={}
    for i,e in enumerate(hits):byrail.setdefault(e['rail'],[]).append(i)
    for rid,orders in byrail.items():
        q=g['rails'][rid];n=q['normal'];p0=q['start'];p1=q['end']
        for k,i in enumerate(orders):
            u=k/len(orders);v=(k+1)/len(orders)
            pts=[[p0[j]+t*(p1[j]-p0[j])-n[j]*.018 for j in [0,1]] for t in [u,v]]
            a.append(line(pts,COLORS[i],5))
    a.append('<g class="after">'+line([p[1:] for p in r['cueAfter']],'#b2c4bf',1.8,'stroke-dasharray="6 6" opacity=".65"')+'</g>')
    a.append('<g class="route">')
    a.append(line([p[1:] for p in r['cueTrack']],'#fafbf7',2.7))
    a.append(line([p[1:] for p in r['targetTrack']],'#f2b978',3.0))
    # Direction arrows chosen by travelled arc length for every actual rail leg.
    ends=[r['contactTime']]+[e['time'] for e in hits]+[r['potTime']]
    for t0,t1 in zip(ends,ends[1:]):
        tr=[p for p in r['targetTrack'] if t0<=p[0]<=t1]
        lengths=[math.dist(p[1:],q[1:]) for p,q in zip(tr,tr[1:])]
        if not lengths:continue
        need=sum(lengths)*.52;s=0
        for k,dd in enumerate(lengths):
            s+=dd
            if s>=need:
                p,q=xy(tr[k][1:]),xy(tr[k+1][1:]);ang=math.atan2(q[1]-p[1],q[0]-p[0]);x,y=q
                pts=[(x+7*math.cos(ang),y+7*math.sin(ang)),(x-6*math.cos(ang-.55),y-6*math.sin(ang-.55)),(x-6*math.cos(ang+.55),y-6*math.sin(ang+.55))]
                a.append('<polygon points="'+' '.join(f'{xx:.2f},{yy:.2f}' for xx,yy in pts)+'" fill="#f2b978"/>');break
    for i,e in enumerate(hits):
        q=g['rails'][e['rail']];n=q['normal'];p=[e['target'][j]+n[j]*.055 for j in [0,1]];x,y=xy(p)
        a.append(circle(p,10,COLORS[i]));a.append(f'<text x="{x}" y="{y+.5}" text-anchor="middle" dominant-baseline="central" font-family="sans-serif" font-size="12" font-weight="700" fill="#10262a">{i+1}</text>')
    a.append('</g>')
    for p,color,label in [(r['cue'],'#f7f7ef',''),(r['target'],'#56BFF5','1')]:
        a.append(circle(p,R*scale,color,'stroke="#102a26" stroke-width="1"'));x,y=xy(p)
        a.append(f'<circle cx="{x-2}" cy="{y-3}" r="2.1" fill="white" opacity=".55"/>')
        if label:a.append(f'<text x="{x}" y="{y+1}" text-anchor="middle" dominant-baseline="central" font-family="sans-serif" font-size="9" font-weight="600" fill="#133342">{label}</text>')
    a.append('</svg>');return ''.join(a)
sections=[]
for t in ['middle','corner']:
    for n in range(1,5):
        name='中袋' if t=='middle' else '底袋';cards=[]
        for r in [x for x in rows if x['type']==t and x['n']==n]:
            sp='中杆无塞' if r['spinX']==0 else ('左塞' if r['spinX']>0 else '右塞')+f' {abs(r["spinX"]):.2f}R'
            route=' → '.join(WALLS[w] for w in r['walls'])+' → '+PK[r['pocket']]
            chips=''.join(f'<span style="--c:{COLORS[i]}">{i+1}</span>' for i in range(n))
            cards.append(f'<article data-id="{r["id"]}"><div class="cardhead"><b>{r["id"]}</b><div class="chips">{chips}</div><small>{PK[r["pocket"]]}</small></div><button class="table" aria-label="放大 {r["id"]}" onclick="expand(this)">{svg(r)}</button><p class="route-text">{route}</p><p class="answer">{sp} · 杆速 {r["speed"]:.1f} m/s<br><span>切角 {r["actualCutAngle"]:.1f}° · 翻袋路程 {r["pathLength"]:.2f} m</span></p></article>')
        sections.append(f'<section data-type="{t}" data-n="{n}"><h2>{name} · {n} 库 <small>6 题</small></h2><div class="grid">'+''.join(cards)+'</div></section>')
page='''<!DOCTYPE html><html lang="zh-CN"><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>翻袋题库 · 八类小样</title><style>
:root{color-scheme:dark;font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif;color:#e8eeed;background:#11232b}*{box-sizing:border-box}body{margin:0;padding:24px 22px 60px}header,main{max-width:1440px;margin:auto}h1{font-size:26px;font-weight:650;margin:0 0 12px}header p{color:#b4c6ca;font-size:14px;line-height:1.8;margin:6px 0}.toolbar{display:flex;align-items:center;flex-wrap:wrap;gap:10px;margin:16px 0 12px}select,button.ctrl{font:inherit;background:#243943;color:#e8eeed;border:1px solid #49616b;border-radius:8px;min-height:44px;padding:8px 12px}label{font-size:14px;display:flex;align-items:center;gap:7px;min-height:44px}input{accent-color:#56bff5}#count{margin-left:auto;color:#a5bdc5;font-size:14px}.legend{display:flex;gap:18px;flex-wrap:wrap;font-size:13px;color:#b4c6ca}.legend i{display:inline-block;width:20px;margin-right:6px;border-top:2px solid;vertical-align:middle}h2{font-size:19px;margin:28px 0 12px}h2 small{font-weight:400;font-size:13px;color:#90aab3;margin-left:8px}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px}article{background:#192e37;border:1px solid #314a55;border-radius:10px;overflow:hidden}.cardhead{display:flex;align-items:center;gap:9px;padding:12px 12px 4px;font-size:13px}.cardhead b{font-variant-numeric:tabular-nums}.cardhead small{margin-left:auto;color:#b4c6ca;font-size:12px}.chips{display:flex;gap:4px}.chips span{background:var(--c);width:18px;height:18px;text-align:center;line-height:18px;font-size:11px;color:#17323c;border-radius:2px;font-weight:700}.table{display:block;padding:0;background:none;border:0;width:100%;cursor:zoom-in}.table svg{display:block;width:100%;height:auto}.route-text{color:#c3d2d6;font-size:12px;padding:0 12px;margin:2px 0 8px;line-height:1.6}.answer{font-size:13px;padding:0 12px;margin:0 0 12px;line-height:1.8;color:#edf2ef}.answer span{color:#9eb6bf;font-size:12px}.after{display:none}body.show-after .after{display:block}body.hide-route .route,body.hide-route .answer,body.hide-route .after{display:none}footer{max-width:1440px;margin:28px auto 0;font-size:12px;line-height:1.8;color:#8da7b0}dialog{max-width:min(1200px,96vw);width:1100px;padding:18px;background:#11232b;color:#e8eeed;border:1px solid #54717d;border-radius:14px}dialog::backdrop{background:#000a}dialog article{border:0}dialog .cardhead{font-size:18px}dialog .cardhead small{font-size:15px}dialog .route-text,dialog .answer{font-size:16px}dialog .answer span{font-size:14px}dialog .table{cursor:default}dialog .close{display:block;margin-left:auto}@media(max-width:780px){body{padding:16px 10px}.grid{gap:8px;min-width:720px}section{overflow-x:auto}.cardhead{padding:9px 7px 3px;gap:5px}.route-text,.answer{padding:0 7px}}@media print{.toolbar,dialog{display:none}section{break-inside:avoid}body{padding:0}.grid{gap:8px}}
</style><header><h1>翻袋题库 · 八类小样</h1><p>中袋、底袋各 1—4 库，每类 6 题。白球击中蓝球，蓝球按编号碰库后进入蓝色标记袋口。点击球桌可放大。</p><div class="toolbar"><label>袋型 <select id="type" onchange="filter()"><option value="all">全部</option><option value="middle">中袋</option><option value="corner">底袋</option></select></label><label>库数 <select id="n" onchange="filter()"><option value="all">全部</option><option value="1">1 库</option><option value="2">2 库</option><option value="3">3 库</option><option value="4">4 库</option></select></label><label><input id="route" type="checkbox" checked onchange="document.body.classList.toggle('hide-route',!this.checked)">显示路线与打法</label><label><input id="after" type="checkbox" onchange="document.body.classList.toggle('show-after',this.checked)">母球碰后路线</label><span id="count">48 / 48 题</span></div><div class="legend"><span><i style="color:#fafbf7"></i>母球击球路线</span><span><i style="color:#f2b978"></i>目标球翻袋路线</span><span>库序：<b style="color:#56BFF5">1</b> → <b style="color:#F6C65B">2</b> → <b style="color:#C3A4F4">3</b> → <b style="color:#F49A84">4</b></span></div></header><main>'''+''.join(sections)+'''</main><footer>48 题均经生产物理完整两球模拟和逐题独立重放。等比例研究图，不是 App 截图；不含扰动评分，未做实台校准。<br>库数仅统计目标球入袋前的主库碰撞。所示打法是已验证参考解，不代表唯一解；杆速为模型输入。底袋指四个角袋。</footer><dialog id="detail"><button class="ctrl close" onclick="document.getElementById('detail').close()">关闭</button><div id="detailBody"></div></dialog><script>
function filter(){let type=document.getElementById('type').value,n=document.getElementById('n').value,count=0;document.querySelectorAll('main section').forEach(s=>{let show=(type==='all'||s.dataset.type===type)&&(n==='all'||s.dataset.n===n);s.hidden=!show;if(show)count+=s.querySelectorAll('article').length});document.getElementById('count').textContent=count+' / 48 题'}
function expand(el){let node=el.closest('article').cloneNode(true);node.querySelector('.table').removeAttribute('onclick');document.getElementById('detailBody').replaceChildren(node);document.getElementById('detail').showModal()}
document.getElementById('detail').addEventListener('click',e=>{if(e.target===e.currentTarget)e.currentTarget.close()});
</script></html>'''
(OUT/'index.html').write_text(page)
print(OUT/'index.html')
