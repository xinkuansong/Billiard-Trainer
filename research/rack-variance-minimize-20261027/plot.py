from pathlib import Path
import json,math
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-variance-minimize-20261027'
sel=json.loads((OUT/'holdout-selection.json').read_text())['selected'];new=sel[-1]
summary=json.loads((OUT/'summary.json').read_text());paired=json.loads((OUT/'paired.json').read_text())
examples=json.loads((OUT/'example-layout.json').read_text());mech=json.loads((OUT/'mechanism.json').read_text())
im=Image.new('RGB',(1600,1100),'#f5f7fa');draw=ImageDraw.Draw(im);font=lambda n:ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',n)
def text(x,y,s,n=20,c='#193047'):draw.text((x,y),s,font=font(n),fill=c)
def arrow(a,b,c):
    draw.line([a,b],fill=c,width=3);dx,dy=b[0]-a[0],b[1]-a[1];d=math.hypot(dx,dy)
    if d<2:return
    x,y=dx/d,dy/d;draw.polygon([b,(b[0]-8*x+4*y,b[1]-8*y-4*x),(b[0]-8*x-4*y,b[1]-8*y+4*x)],fill=c)
text(32,20,'Lower speed variance through rack placement',32)
text(32,64,f'300 fresh paired racks | frozen physics and tip speed 10 | candidate: {new}',21)
for x in [25,810]:
    for y in [110,600]:draw.rounded_rectangle((x,y,x+765,y+465),14,fill='white',outline='#d1dbe5',width=2)
for panel,p,label in [(0,'E','E baseline'),(1,new,'New candidate')]:
    left=25+785*panel;text(left+20,126,f'{label}: actual layout of first validation rack',23)
    e=examples[p];scale=1300
    def xy(pt):return left+75+(pt[0]+.9)*scale,180+(pt[1]+.13)*scale
    for i,(slot,b) in enumerate(zip(e['slots'],e['rack'])):
        x,y=xy([b['x'],b['z']]);color='#f5d5b4' if i in [10,14] else '#bce1d8' if i in [11,13] else '#e3e9f0'
        radius=.028574999421834946*scale
        draw.ellipse((x-radius,y-radius,x+radius,y+radius),fill=color,outline='#8d9cab',width=2)
        text(x-8,y-29,str(i),16)
        if i>=10:
            target=[slot[0]+200*(b['x']-slot[0]),slot[1]+200*(b['z']-slot[1])]
            arrow((x,y),xy(target),'#b45770')
    text(left+495,220,'Rear-slot offsets x200',19,'#b45770')
    text(left+495,255,'Corners: orange',18,'#c27b37');text(left+495,285,'Inner receivers: green',18,'#18866d')
    text(left+495,340,'All offset magnitudes',18);text(left+495,370,'and rack envelope preserved.',18)
    text(left+20,550,'Slot labels, not ball numbers. Arrows magnify initial offsets; not trajectories.',17)

text(45,615,'Mean within-rack variance at 5 ms',24)
colors=['#9ba9b9','#5792c3','#18866d'];maxv=max(summary[p]['variance5'] for p in sel)*1.15
for i,p in enumerate(sel):
    x=110+210*i;v=summary[p]['variance5'];h=v/maxv*280
    draw.rectangle((x,990-h,x+110,990),fill=colors[i]);text(x+18,955-h,f'{v:.3f}',26)
    text(x+25,1005,'New' if p==new else p,21)
text(45,1040,'Unit: (m/s)^2. Same 15 object balls per rack, cue excluded.',18)

text(830,615,'Paired outcomes: new candidate minus E',24)
s=paired[f'{new}-E']['stability'];vals=[s['meaningfulWins'],s['nearEqual'],s['meaningfulLosses']];cols=['#18866d','#c9d1da','#d97a45'];labels=['Lower variance','Near-equal','Higher variance']
x=850
for n,c in zip(vals,cols):
    w=n/300*680
    if w:draw.rectangle((x,685,x+w,735),fill=c)
    if w>30:text(x+w/2-13,698,str(n),21,'white' if c!='#c9d1da' else '#193047')
    x+=w
for i,(label,c,n) in enumerate(zip(labels,cols,vals)):
    draw.rectangle((850,780+i*55,870,800+i*55),fill=c);text(885,775+i*55,f'{label}: {n}/300',21)
text(850,965,f"Mean difference: {paired[f'{new}-E']['variance5']['mean']:+.3f}",23)
text(850,1002,f"Strictly lower: {s['strictWins']}/300",21)
text(830,1040,'Near-equal: absolute variance change <= 0.01 (m/s)^2.',18)
im.save(OUT/'variance-minimize.png')
