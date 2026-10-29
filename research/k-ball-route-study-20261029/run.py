"""Read-only route study: original two-ball paths plus hypothetical B locations.

No new physics is run. Candidate intersections use the archived 2 mm polyline.
"""
from pathlib import Path
import collections, gzip, hashlib, html, json, math
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/k-ball-route-study-20261029'
OLD = ROOT / 'output/two-ball-parameter-consumer-20261026/before/QiuJi/Resources/TwoBallBank'
NOW = ROOT / 'QiuJi/Resources/TwoBallBank'
OUT.mkdir(exist_ok=True)
(OUT / 'images').mkdir(exist_ok=True)
old_index = json.loads((OLD / 'index.json').read_text())
new_index = json.loads((NOW / 'index.json').read_text())
g = old_index['geometry']; R = g['radius']; HX = g['length']/2; HZ = g['width']/2
POCKETS = [[-HX,-HZ],[HX,-HZ],[-HX,HZ],[HX,HZ],[0,-HZ],[0,HZ]]
COLORS = ['#F4F4ED','#F6C65B','#BFA5FF','#FF9C84']
FONT = '/System/Library/Fonts/STHeiti Medium.ttc'
def font(n): return ImageFont.truetype(FONT,n)
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
bindings = {}
def read_layout(root, index, identity):
    e = next(x for x in index['layouts'] if x['id']==identity)
    p = root/(e['shard']+'.jsonl.gz')
    expected = next(x['sha256'] for x in index['shards'] if x['name']==e['shard'])
    assert sha(p)==expected
    bindings[str(p.relative_to(ROOT))] = expected
    row = [json.loads(s) for s in gzip.open(p,'rt')][e['line']]
    assert row['id']==identity
    return row

def projection(p,a,b):
    v=[b[k]-a[k] for k in range(2)]; den=sum(x*x for x in v)
    u=max(0,min(1,sum((p[k]-a[k])*v[k] for k in range(2))/den)) if den else 0
    q=[a[k]+u*v[k] for k in range(2)]
    return math.dist(p,q),u,q

def first_hit(p, pts):
    radius=2*R
    for i,(a,b) in enumerate(zip(pts,pts[1:])):
        v=[b[k]-a[k] for k in range(2)]; w=[a[k]-p[k] for k in range(2)]
        aa=sum(x*x for x in v); bb=2*sum(v[k]*w[k] for k in range(2)); cc=sum(x*x for x in w)-radius**2
        if cc<=0: return i,0,a
        disc=bb*bb-4*aa*cc
        if aa==0 or disc<0: continue
        u=(-bb-math.sqrt(disc))/(2*aa)
        if 0<=u<=1: return i,u,[a[k]+u*v[k] for k in range(2)]
    return None

def candidates(board,route):
    pts=[p[1:] for p in route['trajectory2mm']['points']]
    rails=route['trajectory2mm']['cushions']; result=[]
    for side in range(4):
        half=HX if side<2 else HZ
        count=int((2*half-2*R)/.02)
        for j in range(count+1):
            along=-half+R+j*.02
            for gap in [0,.03,.06]:
                if side==0: p=[along,-HZ+R+gap]
                elif side==1: p=[along,HZ-R-gap]
                elif side==2: p=[-HX+R+gap,along]
                else: p=[HX-R-gap,along]
                # These are exploratory sampling limits, not approved bank rules.
                if min(math.dist(p,q) for q in POCKETS)<.30: continue
                if min(math.dist(p,board[q]) for q in ['cue','object'])<=2*R+.002: continue
                if projection(p,board['cue'],pts[0])[0]<=2*R+.002: continue
                if projection(p,board['object'],board['aim'])[0]<=2*R+.002: continue
                dist=min(projection(p,a,b)[0] for a,b in zip(pts,pts[1:]))
                if dist>2*R-.004: continue  # Exclude numerically marginal grazing proposals.
                h=first_hit(p,pts)
                if h is None: continue
                i,u,contact=h
                if min((math.dist(contact,pts[e['pointIndex']]) for e in rails),default=9)<.015: continue
                n=sum(e['pointIndex']<=i for e in rails)
                if n>3: continue
                inward=[[0,1],[0,-1],[1,0],[-1,0]][side]
                v=[pts[i+1][k]-pts[i][k] for k in range(2)]; vn=sum(v[k]*inward[k] for k in range(2))/math.hypot(*v)
                approach='离库' if vn>.15 else '向库' if vn<-.15 else '近似沿库'
                result.append(dict(position=p,gap=gap,side=side,kRails=n,segment=i,fraction=u,
                    contact=contact,approach=approach,polylineMinimumDistance=dist))
    # Display a sparse, deterministic set; all candidates remain in the data file.
    chosen=[]
    for n in range(4):
        group=[x for x in result if x['kRails']==n]
        group.sort(key=lambda x:(x['gap'],x['side'],x['position']))
        group_chosen=[]
        for x in group:
            if all(math.dist(x['position'],y['position'])>=(.16 if y['kRails']==n else .07) for y in chosen):
                y=dict(x,label=f'K{n}-{len(group_chosen)+1}');chosen.append(y);group_chosen.append(y)
            if len(group_chosen)>=3:break
    return result,chosen

selected=[]
identities=['grid-v3:2137:66:0','grid-v3:1216:63:1','grid-v3:903:50:6']
for gi,identity in enumerate(identities):
    old=read_layout(OLD,old_index,identity);now=read_layout(NOW,new_index,identity)
    assert old['board']==now['board']
    current={r['id']:r for r in now['routes']}
    for n in range(4):
        pool=[r for r in old['routes'] if r['cueMainRailsAfterContact']==n and r['comboIndex'] in current]
        route=min(pool,key=lambda r:(r['executionDifficulty']['effort'],r['comboIndex']))
        cur=current[route['comboIndex']]
        assert [route['velocity'],route['spinX'],route['spinY'],route['strikeDirection']]==[cur['v'],cur['sx'],cur['sy'],cur['dir']]
        assert [e['cushionID'] for e in route['trajectory2mm']['cushions']]==cur['rails']
        assert len(cur['rails'])==n and route['trajectory2mm']['timeOrigin']=='firstTargetContact'
        assert route['trajectory2mm']['maxDeviationMeters']<=.002
        all_b,shown=candidates(old['board'],route)
        selected.append(dict(id=f'{chr(65+gi)}{n}',group=gi,sourceID=identity,board=old['board'],route=route,
            originalTotalRails=n,candidates=all_b,shown=shown))

def draw(row,overlay):
    im=Image.new('RGB',(1500,1040),'#101B24');d=ImageDraw.Draw(im)
    b=row['board'];r=row['route'];n=row['originalTotalRails'];pts=[p[1:] for p in r['trajectory2mm']['points']]
    scale=460;cx=750;cy=480
    def xy(p):return cx+p[0]*scale,cy+p[1]*scale
    d.text((55,25),f"底图 {chr(65+row['group'])} · 原路线全程 {n} 库",font=font(36),fill='white')
    d.text((55,79),f"源角度 {b['angle']}° · 杆速 {r['velocity']:.2f} m/s · 打点 x {r['spinX']:+.3f}R / y {r['spinY']:+.3f}R",font=font(23),fill='#C5D2D8')
    d.rounded_rectangle((110,142,1390,816),radius=25,fill='#49382F')
    d.rectangle((cx-HX*scale,cy-HZ*scale,cx+HX*scale,cy+HZ*scale),fill='#1D5B50')
    for i,p in enumerate(POCKETS):
        x,y=xy(p);rr=18
        d.ellipse((x-rr,y-rr,x+rr,y+rr),fill='#081411',outline='#56BFF5' if i==b['pocket'] else '#877568',width=4)
    def dashed(a,z,color):
        length=math.dist(a,z)
        for i in range(max(1,math.ceil(length/14))):
            u=min(1,i*14/max(length,1));v=min(1,(i*14+7)/max(length,1))
            d.line([(a[0]+u*(z[0]-a[0]),a[1]+u*(z[1]-a[1])),(a[0]+v*(z[0]-a[0]),a[1]+v*(z[1]-a[1]))],fill=color,width=2)
    dashed(xy(b['cue']),xy(pts[0]),'#9EB3B9')
    dashed(xy(b['object']),xy(b['aim']),'#56BFF5')
    events=r['trajectory2mm']['cushions']
    for i,(a,z) in enumerate(zip(pts,pts[1:])):
        k=sum(e['pointIndex']<=i for e in events);color=COLORS[k]
        d.line([xy(a),xy(z)],fill=color,width=4)
        if math.dist(a,z)>.13:
            aa=xy(a);zz=xy(z);x=aa[0]+.6*(zz[0]-aa[0]);y=aa[1]+.6*(zz[1]-aa[1]);ang=math.atan2(zz[1]-aa[1],zz[0]-aa[0])
            d.polygon([(x+9*math.cos(ang),y+9*math.sin(ang)),(x-9*math.cos(ang-.55),y-9*math.sin(ang-.55)),(x-9*math.cos(ang+.55),y-9*math.sin(ang+.55))],fill=color)
    for j,e in enumerate(events,1):
        x,y=xy(pts[e['pointIndex']]);d.rectangle((x-6,y-6,x+6,y+6),fill=COLORS[j])
        # Rail labels moved outward, keeping contact points exact.
        dx=0 if abs(pts[e['pointIndex']][1])>.59 else (27 if x>cx else -27)
        dy=(25 if y>cy else -25) if dx==0 else 0
        d.text((x+dx,y+dy),str(j),font=font(20),fill=COLORS[j],anchor='mm')
    if overlay:
        for c in row['shown']:
            x,y=xy(c['position']);rr=R*scale;col=COLORS[c['kRails']]
            d.ellipse((x-rr,y-rr,x+rr,y+rr),outline=col,width=3)
            d.text((x,y-24 if c['side']!=0 else y+27),c['label'],font=font(17),fill=col,anchor='mm')
    for p,label,col in [(b['cue'],'母','#FFFFFF'),(b['object'],'A','#56BFF5')]:
        x,y=xy(p);rr=R*scale;d.ellipse((x-rr,y-rr,x+rr,y+rr),fill=col,outline='#14232C',width=2)
        d.text((x,y),label,font=font(15),fill='#10242B',anchor='mm')
    x,y=xy(r['cueStop']);d.ellipse((x-6,y-6,x+6,y+6),outline='#BDC9CC',width=2)
    d.text((55,842),'白 K0：首库前    金 K1：一库后    紫 K2：两库后    橙 K3：三库后',font=font(24),fill='#E5E9E5')
    count=collections.Counter(c['kRails'] for c in row['candidates'])
    if overlay:
        line='探索候选数：'+' / '.join(f'K{i} {count[i]}' for i in range(n+1))+f"；图上稀疏展示 {len(row['shown'])} 个独立备选。"
    else:line='原走位参考：未放 B；蓝虚线为 A 的目标进袋方向，灰虚线为首碰前连线。'
    d.text((55,888),line,font=font(22),fill='#D0D9DD')
    d.text((55,930),'空心球仅为 B 的几何候选；每次只放一个。加入 B 后，碰撞后的原路线将改变。',font=font(22),fill='#F6C65B')
    d.text((55,974),'原库 2mm 折线；未重跑物理、未验证 K 后结果或容错。袋口绘制为示意。',font=font(20),fill='#AABFC5')
    im.save(OUT/'images'/f"{row['id']}-{'candidates' if overlay else 'original'}.png")

for row in selected:
    draw(row,False);draw(row,True)
for gi in range(3):
    im=Image.new('RGB',(1800,1330),'#101B24');d=ImageDraw.Draw(im)
    d.text((30,18),f"同一底图 {chr(65+gi)} · 0 / 1 / 2 / 3 库原路线对照",font=font(33),fill='white')
    for i,row in enumerate([s for s in selected if s['group']==gi]):
        pic=Image.open(OUT/'images'/f"{row['id']}-original.png");pic=pic.resize((900,624))
        im.paste(pic,((i%2)*900,75+(i//2)*624))
    im.save(OUT/f'overview-{chr(65+gi)}.jpg',quality=93)

data={'schema':'k-route-study-v1','geometry':g,'selected':selected,'policy':{
    'source':'Current parameter bank, archived matching 2mm trajectories',
    'selection':'First SHA256-sorted layout per source-angle band 10–20/21–30/31–45 with all four rail classes; lowest archived execution effort per class',
    'candidateSampling':'Straight-rail center lines with surface gaps 0/3/6cm, 2cm longitudinal step, >30cm from schematic pocket centers; exploratory only',
    'collision':'Earliest 2R intersection with original polyline; retain minimum distance <=2R-4mm; omit contacts within 15mm of an original rail vertex',
    'exclusions':'Initial overlap, cue pre-contact chord and A intended pot segment obstruction with 2mm margin',
    'notValidated':['three-ball physics','B pot difficulty / worth moving','B and cue final positions','robustness','exact contact speed'],
    'coordinates':'SceneKit XZ meters; Y up; screen right +X and down +Z'}}
(OUT/'data.json').write_text(json.dumps(data,ensure_ascii=False,indent=2))
residuals=[]
for row in selected:
    for c in row['candidates']:
        residuals.append(abs(math.dist(c['position'],c['contact'])-2*R))
        assert abs(c['position'][0])<=HX-R+1e-9 and abs(c['position'][1])<=HZ-R+1e-9
        assert c['kRails']<=row['originalTotalRails']
assert max(residuals,default=0)<1e-8
proof={'sourceBindings':bindings,'indexHashes':{str(p.relative_to(ROOT)):sha(p) for p in [OLD/'index.json',NOW/'index.json']},
       'routes':len(selected),'currentParametersMatchArchive':True,'maxIntersectionResidualMeters':max(residuals,default=0),
       'candidateCounts':{r['id']:dict(collections.Counter(c['kRails'] for c in r['candidates'])) for r in selected},
       'scope':'Source and analytic geometry checks only, not K-shot validation'}
(OUT/'audit.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2))
cards=[]
for row in selected:
    detail=''.join(f"<tr><td>{c['label']}</td><td>{c['gap']*100:.0f} cm</td><td>{c['approach']}</td></tr>" for c in row['shown'])
    cards.append(f'''<article data-group="{row['group']}"><h2>{row['id']} · 原路线全程 {row['originalTotalRails']} 库</h2>
<img width="1500" height="1040" loading="lazy" src="images/{row['id']}-original.png" data-id="{row['id']}" alt="底图{row['id']}的原走位路线和按已吃库数着色的路段">
<details><summary>查看候选位置的离库距离和接近方向</summary><p>仅为原折线上的接近方向，不能推断 B 的最终运动方向。{len(row['candidates'])} 个网格候选不是题目数量。</p><table><tr><th>候选</th><th>球面离库</th><th>母球接近方向</th></tr>{detail}</table></details></article>''')
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>K球 · 原走位路线与摆球探索</title>
<style>body{background:#101b24;color:#f5f5ed;font:17px/1.65 system-ui;margin:0}main{max-width:1280px;margin:auto;padding:24px}p{color:#c2d1d7}nav{display:flex;gap:12px;flex-wrap:wrap}button{background:#29414c;color:white;border:1px solid #78939d;border-radius:8px;font:inherit;padding:10px 18px;min-height:44px}button[aria-pressed=true]{background:#27735c}img{width:100%;height:auto}article{margin:32px 0 65px}a{color:#83d4ff}label{display:block;padding:18px 0}input{width:20px;height:20px}summary{cursor:pointer;padding:12px 0}td,th{text-align:left;padding:6px 24px 6px 0}.note{border-left:3px solid #f6c65b;padding-left:16px}</style>
<main><h1>K 球：先看原走位路线，再讨论 B 放哪里</h1>
<p>3 张原两球底图，各取 0 / 1 / 2 / 3 库代表路线，共 12 条。保留母球、A 和指定袋口；移除原走位题中的 B。三张底图的原角度字段分别为 19°、22°、35°。</p>
<p class="note">原路线是全程库数；K0 / K1 / K2 / K3 表示在该路段碰到 B 之前的库数。加入 B 后，碰撞之后的原走位线不再是预测。</p>
<nav aria-label="底图筛选"><button data-group="0" aria-pressed="true">底图 A · 19°</button><button data-group="1" aria-pressed="false">底图 B · 22°</button><button data-group="2" aria-pressed="false">底图 C · 35°</button></nav>
<label><input id="overlay" type="checkbox"> 显示 B 的探索候选（未验证 K 球）</label>
<p>候选先试球面离库 0 / 3 / 6 cm，沿库每 2 cm 取点，并远离示意袋口中心至少 30 cm。这些仅是本轮看图参数，尚未确定为题库规则。空心球为不同备选，不同时摆放；无候选的路段保持为空。</p>
'''+''.join(cards)+'''<p>来源：当前两球参数库与参数完全匹配的归档 2mm 轨迹。未启动模拟器，未重跑物理，也未证明 B 值得 K、能被 K 好或打法有容错。<a href="data.json">完整分析数据</a> · <a href="audit.json">来源与几何核对</a></p></main>
<script>let group='0';const buttons=[...document.querySelectorAll('button[data-group]')];function apply(){document.querySelectorAll('article').forEach(a=>a.hidden=a.dataset.group!==group);buttons.forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.group===group)));document.querySelectorAll('article img').forEach(i=>i.src='images/'+i.dataset.id+'-'+(document.querySelector('#overlay').checked?'candidates':'original')+'.png')}buttons.forEach(b=>b.onclick=()=>{group=b.dataset.group;apply()});document.querySelector('#overlay').onchange=apply;apply();</script></html>'''
(OUT/'index.html').write_text(page)
print(json.dumps(proof,ensure_ascii=False))
