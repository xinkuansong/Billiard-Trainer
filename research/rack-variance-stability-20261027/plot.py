"""Standalone evidence chart; actual positions and measured paired statistics."""
from pathlib import Path
import json,gzip,math
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-variance-stability-20261027'
results=json.loads((OUT/'results.json').read_text());result=results['global'];folder=OUT/'stage2'
rows=json.loads((folder/'scalars.json').read_text())+json.loads((folder/'gated-rows.json').read_text())
groups={p:{r['id']:r for r in rows if r['cohort']=='holdout' and r['condition']=='original' and r['policy']==p} for p in result['selected']}
im=Image.new('RGB',(1600,1050),'#f5f7fa');d=ImageDraw.Draw(im)
font=lambda n:ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',n)
def text(x,y,s,n=20,c='#193047'):d.text((x,y),s,font=font(n),fill=c)
def arrow(a,b,c):
    d.line([a,b],fill=c,width=4);dx,dy=b[0]-a[0],b[1]-a[1];l=math.hypot(dx,dy);ux,uy=dx/l,dy/l
    d.polygon([b,(b[0]-12*ux+5*uy,b[1]-12*uy-5*ux),(b[0]-12*ux-5*uy,b[1]-12*uy+5*ux)],fill=c)
text(32,22,'Whole-rack speed variance | geometry before the break',32)
text(32,66,'Frozen physics. Final independent 200 racks. Object balls only; population variance at 5 ms.',22)
for box in [(25,110,790,550),(810,110,1575,550),(25,570,790,1020),(810,570,1575,1020)]:d.rounded_rectangle(box,14,fill='white',outline='#d4dde6',width=2)
text(45,125,'1. Rack slot network (schematic links)',23)
with gzip.open(folder/'layouts.jsonl.gz','rt') as f:g=json.loads(next(f))
slots=g['slots'];xy=lambda p:(100+(p[0]+.9)*1250,175+(p[1]+.13)*1250)
for i,p in enumerate(slots):
    x,y=xy(p);color='#bce1d8' if i in [7,8,11,13] else '#f5d5b4' if i in [6,9,10,14] else '#e3e9f0'
    d.ellipse((x-20,y-20,x+20,y+20),fill=color,outline='#8294a6',width=2);text(x-7,y-12,str(i),18)
for a,b,c in [(3,7,'#18866d'),(5,8,'#18866d'),(3,6,'#d78430'),(5,9,'#d78430'),(4,7,'#9264a9'),(4,8,'#9264a9'),(6,11,'#18866d'),(9,13,'#18866d'),(6,10,'#d78430'),(9,14,'#d78430')]:
    x1,y1=xy(slots[a]);x2,y2=xy(slots[b]);dx,dy=x2-x1,y2-y1;l=math.hypot(dx,dy)
    arrow((x1+23*dx/l,y1+23*dy/l),(x2-23*dx/l,y2-23*dy/l),c)
text(450,210,'Green: inner branch',19,'#18866d');text(450,245,'Orange: outer branch',19,'#d78430');text(450,280,'Purple: competing core feed',18,'#9264a9')
text(45,500,'Indices are geometric slots, not ball numbers. Arrows show links, not trajectories.',17)

text(830,125,'2. Gated rule: every paired variance change',23)
base=groups['B'];gated=groups['geometry_gated_C'];delta=sorted([gated[i]['variance5']-b['variance5'] for i,b in base.items()])
lo=min(-.1,min(delta));hi=max(.1,max(delta));xx=lambda i:860+i*3.3;yy=lambda v:470-(v-lo)/(hi-lo)*260
d.line([(855,yy(0)),(1535,yy(0))],fill='#7f8c99',width=2)
for i,v in enumerate(delta):x,y=xx(i),yy(v);d.ellipse((x-2,y-2,x+2,y+2),fill='#18866d' if v<-.01 else '#d97a45' if v>.01 else '#adb7c2')
text(835,180,f'{hi:+.2f}',17);text(835,465,f'{lo:+.2f}',17);text(900,490,'200 racks sorted by change; lower is better',18)

text(45,590,'3. Meaningful improvement / near-equal / regression',22)
colors=['#18866d','#c9d1da','#d97a45']
for j,p in enumerate(result['selected'][1:]):
    s=result['paired'][f'{p}-B']['stability'];vals=[s['meaningfulWins'],s['nearEqual'],s['meaningfulLosses']]
    label='Gated C' if p=='geometry_gated_C' else p
    text(45,640+j*95,label,20);x=220;y=640+j*95
    for n,c in zip(vals,colors):
        w=n/200*520
        if w:d.rectangle((x,y,x+w,y+36),fill=c)
        if w>28:text(x+w/2-10,y+6,str(n),17,'white' if c!='#c9d1da' else '#193047')
        x+=w
text(45,965,'Meaningful: absolute variance change > 0.01 (m/s)^2.',18)

text(830,590,'4. Mean variance, same 200 racks',23)
ps=['B','C','C_back90','geometry_gated_C'];cs=['#8495aa','#5792c3','#9264a9','#18866d']
maximum=max(result['summary'][p][f'variance{t}'] for p in ps for t in [5,20,100])*1.1
for j,t in enumerate([5,20,100]):
    for k,p in enumerate(ps):
        value=result['summary'][p][f'variance{t}'];x=870+j*225+k*46;h=value/maximum*260
        d.rectangle((x,930-h,x+32,930),fill=cs[k]);text(x-5,900-h,f'{value:.2f}',15)
    text(910+j*210,942,f'{t} ms',19)
for k,(p,c) in enumerate(zip(['B','C','C_back90','Gated C'],cs)):d.rectangle((840+k*180,995,858+k*180,1011),fill=c);text(866+k*180,990,p,18)
im.save(OUT/'variance-stability.png')
