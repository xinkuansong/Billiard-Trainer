"""Angle comparison from matching archived two-ball polylines. No B or physics run."""
from pathlib import Path
import collections, gzip, hashlib, html, json, math
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/k-ball-rail-angle-review-20261029'
OLD=ROOT/'output/two-ball-parameter-consumer-20261026/before/QiuJi/Resources/TwoBallBank'
NOW=ROOT/'QiuJi/Resources/TwoBallBank'
OUT.mkdir(exist_ok=True);(OUT/'images').mkdir(exist_ok=True)
FONT='/System/Library/Fonts/STHeiti Medium.ttc'
def font(n):return ImageFont.truetype(FONT,n)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
old_index=json.loads((OLD/'index.json').read_text());new_index=json.loads((NOW/'index.json').read_text())
G=old_index['geometry'];R=G['radius'];HX=G['length']/2;HZ=G['width']/2
bindings={};events=[]
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def sub(a,b):return [a[k]-b[k] for k in (0,1)]
def basis(p):
    if abs(abs(p[1])-(HZ-R))<.001:return [1,0],[0,-1 if p[1]>0 else 1]
    assert abs(abs(p[0])-(HX-R))<.001
    return [0,1],[-1 if p[0]>0 else 1,0]
def angle(v,t,n):return math.degrees(math.atan2(abs(dot(v,n)),abs(dot(v,t))))
def clipped(points,limit=.35):
    result=[points[0]];length=0
    for a,b in zip(points,points[1:]):
        step=math.dist(a,b)
        if length+step>limit:
            u=(limit-length)/step;result.append([a[k]+u*(b[k]-a[k]) for k in (0,1)]);break
        result.append(b);length+=step
    return result
for shard in ['00171','01060','00826']:
    tables=[]
    for root,index in [(OLD,old_index),(NOW,new_index)]:
        p=root/(shard+'.jsonl.gz');digest=sha(p)
        assert digest==next(x['sha256'] for x in index['shards'] if x['name']==shard)
        bindings[str(p.relative_to(ROOT))]=digest
        tables.append({d['id']:d for d in map(json.loads,gzip.open(p,'rt'))})
    for identity,d in tables[0].items():
        if not 10<=d['board']['angle']<=45 or identity not in tables[1]:continue
        current=tables[1][identity];assert current['board']==d['board']
        routes={r['id']:r for r in current['routes']}
        for r in d['routes']:
            if r['comboIndex'] not in routes:continue
            cur=routes[r['comboIndex']]
            assert [r['velocity'],r['spinX'],r['spinY'],r['strikeDirection']]==[cur['v'],cur['sx'],cur['sy'],cur['dir']]
            track=r['trajectory2mm'];pts=[p[1:] for p in track['points']];cushions=track['cushions']
            assert [e['cushionID'] for e in cushions]==cur['rails']
            assert track['timeOrigin']=='firstTargetContact' and track['maxDeviationMeters']<=.002
            for j,e in enumerate(cushions[:3]):
                i=e['pointIndex']
                if i==0 or i==len(pts)-1:continue
                pre,hit,post=pts[i-1:i+2];lens=[math.dist(pre,hit),math.dist(hit,post)]
                if min(lens)<.06:continue
                t,n=basis(hit);incoming=sub(hit,pre);outgoing=sub(post,hit)
                assert dot(incoming,n)<0 and dot(outgoing,n)>0
                if dot(incoming,t)<0:t=[-v for v in t]
                lo=cushions[j-1]['pointIndex'] if j else 0
                hi=cushions[j+1]['pointIndex'] if j+1<len(cushions) else len(pts)-1
                before=clipped(list(reversed(pts[lo:i+1])))
                after=clipped(pts[i:hi+1])
                def local(p):
                    delta=sub(p,hit);return [dot(delta,t),dot(delta,n)+R]
                events.append(dict(key=f'{identity}/{r["comboIndex"]}/{j+1}',layout=identity,board=d['board'],route=r,
                    railOrdinal=j+1,pointIndex=i,railID=e['cushionID'],inAngle=angle(incoming,t,n),outAngle=angle(outgoing,t,n),
                    adjacentLengths=lens,tangent=t,inward=n,contact=hit,
                    localIn=list(reversed([local(p) for p in before])),localOut=[local(p) for p in after],
                    segmentIn=[local(pre),[0,R]],segmentOut=[[0,R],local(post)]))

# Six bins. First: closest to bin midpoint; second: biggest in/out difference,
# using another layout when available. Examples demonstrate geometry, not frequency.
selections={};chosen={}
for axis in ['inAngle','outAngle']:
    groups=[]
    for b in range(6):
        pool=[e for e in events if min(5,int(e[axis]/15))==b];assert pool
        first=min(pool,key=lambda e:(abs(e[axis]-(b*15+7.5)),e['key']))
        rest=[e for e in pool if e['layout']!=first['layout']] or [e for e in pool if e['key']!=first['key']]
        second=min(rest,key=lambda e:(-abs(e['inAngle']-e['outAngle']),e['key']))
        group=[]
        for e in [first,second]:
            if e['key'] not in chosen:chosen[e['key']]=dict(e,id=f'E{len(chosen)+1:02d}')
            group.append(chosen[e['key']]['id'])
        groups.append(dict(lower=b*15,upper=(b+1)*15,ids=group,poolCount=len(pool)))
    selections[axis]=groups
rows=list(chosen.values());lookup={r['id']:r for r in rows}

def arrow(d,a,b,color):
    if math.dist(a,b)<10:return
    x=a[0]+.55*(b[0]-a[0]);y=a[1]+.55*(b[1]-a[1]);ang=math.atan2(b[1]-a[1],b[0]-a[0])
    d.polygon([(x+9*math.cos(ang),y+9*math.sin(ang)),(x-8*math.cos(ang-.6),y-8*math.sin(ang-.6)),(x-8*math.cos(ang+.6),y-8*math.sin(ang+.6))],fill=color)
def draw_local(e, focus=None):
    im=Image.new('RGB',(1000,650),'#101B24');d=ImageDraw.Draw(im)
    d.text((30,20),f"{e['id']}    入库 ≈ {e['inAngle']:.1f}°     出库 ≈ {e['outAngle']:.1f}°",font=font(32),fill='white')
    d.text((30,70),f"第 {e['railOrdinal']} 次吃库 · 原路线全程 {e['route']['cueMainRailsAfterContact']} 库",font=font(23),fill='#C3D1D6')
    colors={'localIn':'#FFFFFF','localOut':'#F6C65B'}
    if focus: colors['localOut' if focus=='inAngle' else 'localIn']='#57786F'
    scale=1080;cx=500;rail_y=145
    def xy(p):return (cx+p[0]*scale,rail_y+p[1]*scale)
    d.rectangle((45,123,955,555),fill='#1D5B50');d.rectangle((45,123,955,145),fill='#584338')
    d.line([(45,145),(955,145)],fill='#99A9A0',width=3)
    cy=rail_y+R*scale
    for x in range(60,950,18):d.line([(x,cy),(x+8,cy)],fill='#65867C',width=1)
    for name,color in colors.items():
        for a,b in zip(e[name],e[name][1:]):d.line([xy(a),xy(b)],fill=color,width=6 if color!='#57786F' else 2)
        longest=max(zip(e[name],e[name][1:]),key=lambda ab:math.dist(*ab));arrow(d,xy(longest[0]),xy(longest[1]),color)
    d.ellipse((cx-R*scale,cy-R*scale,cx+R*scale,cy+R*scale),outline='#8FD9F0',width=2)
    d.ellipse((cx-4,cy-4,cx+4,cy+4),fill='#8FD9F0')
    # Small arcs show each measured adjacent secant relative to the cushion tangent.
    for point,color,rad in [(e['segmentIn'][0],colors['localIn'],65),(e['segmentOut'][1],colors['localOut'],90)]:
        v=sub(point,[0,R]);theta=math.degrees(math.atan2(v[1],v[0]));base=0 if v[0]>=0 else 180
        d.arc((cx-rad,cy-rad,cx+rad,cy+rad),start=min(base,theta),end=max(base,theta),fill=color,width=2)
    d.text((58,515),'10 cm',font=font(18),fill='#CADBD3');d.line([(58,545),(166,545)],fill='#CADBD3',width=3)
    legend=('白：入库前 K 观察段' if focus=='inAngle' else '金：出库后 K 观察段') if focus else '白：来路   金：去路'
    r=e['route'];d.text((30,575),f"{legend}    杆速 {r['velocity']:.2f} m/s    打点 ({r['spinX']:+.2f}, {r['spinY']:+.2f})R",font=font(22),fill='#D3DEE0')
    d.text((30,615),'同尺度局部：每侧最多 35 cm；角度为相邻折线方向，不是瞬时速度角。',font=font(19),fill='#ADBDC4')
    im.save(OUT/'images'/f"{e['id']}{'-'+focus if focus else ''}.png")
def draw_full(e):
    im=Image.new('RGB',(1500,950),'#101B24');d=ImageDraw.Draw(im);b=e['board'];r=e['route'];s=460;cx=750;cy=440
    def xy(p):return cx+p[0]*s,cy+p[1]*s
    d.text((45,20),f"{e['id']} 原球形 · 第 {e['railOrdinal']} 库 · 入 ≈ {e['inAngle']:.1f}° / 出 ≈ {e['outAngle']:.1f}°",font=font(35),fill='white')
    d.rounded_rectangle((115,118,1385,765),radius=24,fill='#49382F');d.rectangle((cx-HX*s,cy-HZ*s,cx+HX*s,cy+HZ*s),fill='#1D5B50')
    for i,p in enumerate([[-HX,-HZ],[HX,-HZ],[-HX,HZ],[HX,HZ],[0,-HZ],[0,HZ]]):
        x,y=xy(p);d.ellipse((x-17,y-17,x+17,y+17),fill='#081411',outline='#56BFF5' if i==b['pocket'] else '#8F7F6A',width=4)
    pts=[p[1:] for p in r['trajectory2mm']['points']];d.line([xy(p) for p in pts],fill='#899C9B',width=3)
    d.line([xy(b['cue']),xy(pts[0])],fill='#536D70',width=2);d.line([xy(b['object']),xy(b['aim'])],fill='#56BFF5',width=2)
    hit=e['contact'];t=e['tangent'];n=e['inward']
    def world(p):return [hit[k]+p[0]*t[k]+(p[1]-R)*n[k] for k in (0,1)]
    for key,col in [('localIn','#FFFFFF'),('localOut','#F6C65B')]:
        arr=[xy(world(p)) for p in e[key]];d.line(arr,fill=col,width=5)
        aa,bb=max(zip(arr,arr[1:]),key=lambda q:math.dist(*q));arrow(d,aa,bb,col)
    for j,event in enumerate(r['trajectory2mm']['cushions'],1):
        x,y=xy(pts[event['pointIndex']]);d.text((x,y),str(j),font=font(18),fill='#101B24',stroke_width=3,stroke_fill='#8FD9F0')
    for p,l,c in [(b['cue'],'母','#FFFFFF'),(b['object'],'A','#56BFF5')]:
        x,y=xy(p);rr=R*s;d.ellipse((x-rr,y-rr,x+rr,y+rr),fill=c);d.text((x,y),l,font=font(15),fill='#10242B',anchor='mm')
    d.text((45,800),'灰：完整原路线   白/金：本次比较的来路/去路   蓝：A 的目标进袋方向',font=font(23),fill='#D3DEE0')
    d.text((45,845),f"源角度字段 {b['angle']}° · {e['layout']} · 路线 {r['comboIndex']}",font=font(23),fill='#ADBDC4')
    d.text((45,888),'未放 B，未重跑物理；仅比较归档路线的局部方向。',font=font(22),fill='#F6C65B')
    im.save(OUT/'images'/f"{e['id']}-full.png")
for e in rows:
    draw_local(e);draw_full(e)
    for axis in ['inAngle','outAngle']:draw_local(e,axis)
for axis,title in [('inAngle','入库前 K · 按入库角升序'),('outAngle','出库后 K · 按出库角升序')]:
    sheet=Image.new('RGB',(1600,6*580+85),'#101B24');d=ImageDraw.Draw(sheet);d.text((25,20),title+' · 平行 0° / 垂直 90°',font=font(33),fill='white')
    for j,group in enumerate(selections[axis]):
        y=85+j*580;d.text((25,y),f"{group['lower']}–{group['upper']}°",font=font(29),fill='#8FD9F0')
        for k,id in enumerate(sorted(group['ids'],key=lambda id:lookup[id][axis])):sheet.paste(Image.open(OUT/'images'/f'{id}-{axis}.png').resize((800,520)),(k*800,y+45))
    sheet.save(OUT/f'overview-{axis}.jpg',quality=94)

data={'geometry':G,'eventsScanned':len(events),'selected':rows,'groups':selections,
      'method':{'angleReference':'Angle to cushion tangent, parallel=0, normal=90; absolute acute angle',
      'direction':'Adjacent archived 2mm polyline secants; each >=6cm. Not instantaneous tangent/velocity. Curvature and compression can affect angle.',
      'normalization':'Rigid orthogonal transform, optional tangent reflection; cushion at y=0, interior y>0, cue center at y=R. Same scale. 35cm arc length each side, stopping at adjacent event or track end.',
      'sampling':'Three existing source shards; source board angle 10–45; first three cushion events of every matching route. Per bin: midpoint-nearest plus largest in/out difference from another layout if available.',
      'limits':'No B, no robustness, no threshold decision; examples differ in shot speed, spin, layout and route history, not a controlled angle-only experiment.'}}
(OUT/'data.json').write_text(json.dumps(data,ensure_ascii=False,indent=2))
(OUT/'source-audit.json').write_text(json.dumps({'bindings':bindings,'indices':{str(p.relative_to(ROOT)):sha(p) for p in [OLD/'index.json',NOW/'index.json']},'events':len(events),'selected':len(rows)},indent=2))
payload=json.dumps({'rows':[{k:e[k] for k in ['id','inAngle','outAngle','railOrdinal']} for e in rows],'groups':selections},ensure_ascii=False)
page=(Path(__file__).with_name('page.html').read_text()).replace('__DATA__',payload)
(OUT/'index.html').write_text(page)
print(json.dumps({'events':len(events),'uniqueExamples':len(rows),'groups':selections},ensure_ascii=False))
