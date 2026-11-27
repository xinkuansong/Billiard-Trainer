from pathlib import Path
import json,math,html
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/bank-distance12-20261101'
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
    d=r['bestDirect'];aim=d['aim'];ll=math.dist(r['target'],aim);u=[(aim[j]-r['target'][j])/ll for j in [0,1]]
    ghost=[r['target'][j]-2*R*u[j] for j in [0,1]]
    a.append('<g class="direct">'+line([r['cue'],ghost],'#e8a5cf',2,'stroke-dasharray="7 5"')+line([r['target'],aim],'#e8a5cf',3,'stroke-dasharray="8 5"')+circle(g['pockets'][d['pocket']]['center'],16,'none','stroke="#e8a5cf" stroke-width="2" stroke-dasharray="4 3"')+'</g>')
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
for typ in ['middle','corner']:
 for sampleIndex in [0,1]:
  cards=[]
  for r in sorted([r for r in rows if r['type']==typ and r['sampleIndex']==sampleIndex],key=lambda x:x['angleBand']):
   d=r['bestDirect'];route=WALLS[r['walls'][0]]+' → '+PK[r['pocket']]
   band=['45–55°','55–65°','≥65°'][r['angleBand']]
   cards.append(f'''<article data-id="{r['id']}" data-score="{45+10*r['angleBand']}"><div class="cardhead"><b>{r['id']}</b><span>直打 {band}</span></div><button class="table" onclick="expand(this)" aria-label="放大 {r['id']}">{svg(r)}</button><div class="facts"><div class="direct-label">最小直打切角 <strong>{d['cut']:.1f}°</strong></div><div>去{PK[d['pocket']]} · 距袋 {d['distance']:.2f} m</div><div class="bank-label">翻袋实测切角 <strong>{r['actualCutAngle']:.1f}°</strong> · 杆速 {r['speed']:.1f} m/s</div><div>{route}</div><div class="bank-label">翻袋综合分 <strong>{r['bankComfort']['total']:.1f}</strong></div><div>距离 {r['bankComfort']['distance']:.0f} · 空间 {r['bankComfort']['space']:.0f} · 角度 {r['bankComfort']['angle']:.0f}</div><div class="sub">两球间距 {r['bankComfort']['cueTargetDistance']*100:.1f} cm · 母球离库 {r['cueRailGap']*100:.1f} cm</div><div class="sub">六袋最高直打综合分 {r['directComfortOptions'][0]['total']:.1f}</div><div class="sub">目标球离库 {r['railGap']*100:.1f} cm</div></div></article>''')
  sections.append(f'''<section data-type="{typ}"><h2>{'中袋' if typ=='middle' else '底袋'} · {'中距离 40–100cm' if sampleIndex==0 else '远距离 ≥1m'} <small>直打切角从左到右增大</small></h2><div class="grid">{''.join(cards)}</div></section>''')
page='''<!DOCTYPE html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>中远台对照 · 翻袋12题</title><style>
:root{font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif;color-scheme:dark;color:#e8eeed;background:#11232b}*{box-sizing:border-box}body{margin:0;padding:24px 22px 50px}header,main,footer{max-width:1440px;margin:auto}h1{font-size:26px;margin:0 0 12px}header p{color:#b4c6ca;font-size:14px;line-height:1.8;margin:6px 0}.toolbar{display:flex;gap:14px;align-items:center;flex-wrap:wrap;margin:16px 0}label{display:flex;align-items:center;gap:8px;font-size:14px}select,.close{background:#243943;border:1px solid #49616b;border-radius:8px;color:inherit;min-height:44px;font:inherit;padding:8px 12px}#count{margin-left:auto;color:#a5bdc5}.legend{display:flex;gap:18px;font-size:13px;color:#b4c6ca;flex-wrap:wrap}.legend i{display:inline-block;width:24px;border-top:2px solid;margin-right:6px;vertical-align:middle}h2{font-size:19px;margin:28px 0 12px}h2 small{font-size:12px;font-weight:400;color:#90aab3;margin-left:12px}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px}article{border:1px solid #314a55;border-radius:10px;background:#192e37;overflow:hidden}.cardhead{display:flex;align-items:center;justify-content:space-between;padding:12px 12px 4px;font-size:13px}.cardhead span{font-size:12px;color:#b4c6ca}.table{display:block;border:0;padding:0;background:none;width:100%;cursor:zoom-in}.table svg{display:block;width:100%;height:auto}.facts{font-size:12px;line-height:1.9;padding:0 12px 12px}.direct-label{color:#e8a5cf;font-size:13px}.direct-label strong{font-size:18px;margin:0 3px}.direct-label small{font-size:11px;color:#96adb5}.bank-label{color:#f2b978;margin-top:5px}.sub{color:#9eb6bf}.after{display:none}body[data-route=bank] .direct{display:none}body[data-route=direct] .route{display:none}body[data-route=none] .route,body[data-route=none] .direct{display:none}footer{font-size:12px;color:#8da7b0;line-height:1.8;margin-top:28px}dialog{background:#11232b;color:#e8eeed;border:1px solid #54717d;border-radius:14px;width:1100px;max-width:96vw;padding:18px}dialog::backdrop{background:#000a}.close{display:block;margin-left:auto;margin-bottom:10px}dialog .facts{font-size:15px}dialog .direct-label,dialog .bank-label{font-size:16px}dialog .table{cursor:default}@media(max-width:780px){body{padding:16px 10px}.grid{min-width:720px;gap:8px}section{overflow-x:auto}}
</style><body data-route="both"><header><h1>中远台对照 · 翻袋12题</h1><p>两球球心间距至少40cm；出杆空间分≥85。远台保留，距离分与综合分仅作参考，不用于淘汰远台。目标球没有固定区域限制。六袋合法候选的最小直打切角≥45°；一库翻袋实测切角≤35°。每行从左到右为直打45–55°、55–65°、≥65°。</p><p>粉色虚线为最小切角直打几何线，橙色为翻袋实际路线；点击球桌可放大。</p><div class="toolbar"><label>翻袋袋型 <select id="type" onchange="filter()"><option value="all">全部</option><option value="middle">中袋</option><option value="corner">底袋</option></select></label><label>直打切角 <select id="score" onchange="filter()"><option value="all">全部</option><option value="45">45–55°</option><option value="55">55–65°</option><option value="65">≥65°</option></select></label><label>路线 <select id="route" onchange="document.body.dataset.route=this.value"><option value="both">直打＋翻袋</option><option value="bank">只看翻袋</option><option value="direct">只看直打</option><option value="none">只看球形</option></select></label><span id="count">12 / 12 题</span></div><div class="legend"><span><i style="color:#e8a5cf;border-top-style:dashed"></i>最小切角直打 · 粉色虚线袋圈</span><span><i style="color:#f2b978"></i>翻袋实际路线 · 蓝色实线袋圈</span><span><i style="color:#fafbf7"></i>翻袋母球路线</span></div></header><main>'''+''.join(sections)+'''</main><footer>直打切角取六袋有限合法候选中的最小值；直打综合分另取六袋候选最高值。翻袋综合分采用距离、出杆空间、角度及原总分合成方式，按实际击打方向与完整目标球路线适配，本轮只以空间分与不过近条件筛选母球，不用距离分或总分淘汰远台；分数不代表成功率。无合法直打候选的球形单独排除，不伪记为90°。<br>直打切角为几何值，翻袋切角来自实际碰撞。两种参考打法均经完整生产物理模拟和独立重放，共24杆；直打实测切角也落在相应档位。<br>球位沿完整反射线采样；离库距离仅作说明，不作准入条件。角度对比不保证翻袋成功率高于直打。未做实台或扰动校准，未修改正式题库。</footer><dialog id="detail"><button class="close" onclick="document.getElementById('detail').close()">关闭</button><div id="detailBody"></div></dialog><script>
function filter(){let t=document.getElementById('type').value,s=document.getElementById('score').value,n=0;document.querySelectorAll('main section').forEach(e=>{let visible=0;e.querySelectorAll('article').forEach(c=>{c.hidden=!(s==='all'||c.dataset.score===s);if(!c.hidden)visible++});e.hidden=!(t==='all'||e.dataset.type===t)||visible===0;if(!e.hidden)n+=visible});document.getElementById('count').textContent=n+' / 12 题'}
function expand(el){let n=el.closest('article').cloneNode(true);n.querySelector('.table').removeAttribute('onclick');document.getElementById('detailBody').replaceChildren(n);document.getElementById('detail').showModal()}
document.getElementById('detail').addEventListener('click',e=>{if(e.target===e.currentTarget)e.currentTarget.close()});</script></body></html>'''
(OUT/'index.html').write_text(page)
print(OUT/'index.html')
