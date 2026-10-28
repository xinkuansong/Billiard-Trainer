"""Research figure, CBSA April 2026, not an app model or physics simulation.

Top view: mm, origin at left/top playing-area edge, x right, y down.
Head/break end is left; foot/rack end right. Pixel scale is uniform.
Side view is explicitly not to scale and only identifies height datums.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
FONT = '/System/Library/Fonts/Hiragino Sans GB.ttc'
BG, INK, MUTED, ACCENT = '#F5F4F0', '#163C38', '#526661', '#AF5728'
im = Image.new('RGB', (1600, 1270), BG)
d = ImageDraw.Draw(im)

def text(x, y, s, size=26, color=INK, anchor=None):
    d.text((x,y),s,font=ImageFont.truetype(FONT,size),fill=color,anchor=anchor)

def dim(a,b,label,label_at):
    d.line([a,b],fill=INK,width=2)
    if a[1] == b[1]:
        for x,y in (a,b): d.line((x,y-9,x,y+9),fill=INK,width=2)
    else:
        for x,y in (a,b): d.line((x-9,y,x+9,y),fill=INK,width=2)
    text(*label_at,label,24,INK,'mm')

text(60,40,'先看懂球台，再记尺寸',48)
text(60,112,'中国台球协会 · 华彩十六球比赛规则和竞赛规定（试行）· 2026年4月版',26,MUTED)
text(60,155,'俯视：台面与球等比例；外框、库边和袋口仅作符号示意。',23,MUTED)

S=0.4
L,W,D=2540,1270,57
x0,y0=180,270
x1,y1=x0+L*S,y0+W*S
head=x0+635*S
spot=x0+(L-635)*S
mid=(y0+y1)/2
assert (x1-x0)/(y1-y0)==2
assert head-x0 == x1-spot == 635*S
assert abs(D*S/(y1-y0)-57/1270)<1e-12

d.rounded_rectangle((x0-29,y0-29,x1+29,y1+29),25,fill='#C7BBA8')
d.rectangle((x0,y0,x1,y1),fill='#DCEBE5',outline=INK,width=3)
d.rectangle((x0+3,y0+3,head-1,y1-3),fill='#B8D9CC')
for xx,yy in [(x0,y0),(x0,y1),(x1,y0),(x1,y1),((x0+x1)/2,y0),((x0+x1)/2,y1)]:
    d.ellipse((xx-14,yy-14,xx+14,yy+14),fill=INK)
for xx in range(int(x0+24),int(x1-24),22):
    d.line((xx,mid,xx+10,mid),fill='#6A8C7F',width=2)
d.line((head,y0,head,y1),fill=INK,width=3)
d.ellipse((spot-5,mid-5,spot+5,mid+5),fill=ACCENT)
d.line((spot-15,mid,spot+15,mid),fill=ACCENT,width=2)
d.line((spot,mid-15,spot,mid+15),fill=ACCENT,width=2)
text((x0+head)/2,343,'开球线后区域',26,INK,'mm')
text((x0+head)/2,385,'不含线本身',22,MUTED,'mm')
text(head+22,440,'开球线',26)
text(spot,mid-45,'置球点',26,INK,'mm')
text((head+spot)/2,mid+43,'纵向中心线',23,MUTED,'mm')
text(x0,227,'底库 · 开球端',23,INK,'mm')
text(x1,227,'顶库 · 摆球端',23,INK,'mm')
text((x0+x1)/2,305,'中袋',23,INK,'mm')

cx,cy=x0+130*S,y0+900*S
r=D*S/2
d.ellipse((cx-r,cy-r,cx+r,cy+r),fill='white',outline=INK,width=1)
d.line((cx+15,cy,cx+52,cy),fill=INK,width=2)
text(cx+60,cy,'白球（按真实比例）',21,INK,'lm')
dim((x0,205),(x1,205),'台面长 2540 ± 10 mm',((x0+x1)/2,205))
# Opaque label background keeps the dimension rule out of the glyphs.
d.rectangle((470,188,910,227),fill=BG)
text(690,205,'台面长 2540 ± 10 mm',25,INK,'mm')
dim((115,y0),(115,y1),'', (115,mid))
label=Image.new('RGBA',(470,48),(0,0,0,0))
ImageDraw.Draw(label).text((235,24),'台面宽 1270 ± 10 mm',font=ImageFont.truetype(FONT,25),fill=INK,anchor='mm')
label=label.rotate(90,expand=True)
im.paste(label,(52,int(mid-label.height/2)),label)
dim((x0,850),(head,850),'635 mm',((x0+head)/2,828))
dim((spot,850),(x1,850),'635 mm',((spot+x1)/2,828))
text(690,880,'尺寸从台面边界量起，不是整桌外径，也不是从袋心量起。',24,MUTED,'mm')

d.rounded_rectangle((1265,242,1550,805),22,fill='white')
text(1407,285,'一颗球',30,INK,'mm')
d.ellipse((1347,332,1467,452),fill='white',outline=INK,width=3)
dim((1347,392),(1467,392),'', (1407,392))
text(1407,484,'直径 57 ± 0.2 mm',23,INK,'mm')
text(1407,525,'重量 167 ± 3 g',24,INK,'mm')
text(1407,579,'此处为局部放大',21,MUTED,'mm')
text(1407,643,'球杆最低长度',24,INK,'mm')
text(1407,688,'1000 mm',34,INK,'mm')
text(1407,747,'最低值不是选杆建议',21,MUTED,'mm')

d.rounded_rectangle((48,930,1552,1190),22,fill='white')
text(80,955,'高度要看量到哪里',30)
text(80,1005,'侧视示意，不按比例',22,MUTED)
floor,bed,rail=1150,1055,1015
d.line((550,floor,1220,floor),fill=MUTED,width=2)
d.rectangle((640,bed,1100,bed+22),fill='#C7BBA8')
d.rectangle((640,rail,690,bed),fill='#8AA99C')
d.rectangle((1050,rail,1100,bed),fill='#8AA99C')
for x in [665,1055]: d.rectangle((x,bed+22,x+20,floor),fill='#C7BBA8')
d.line((690,bed,1050,bed),fill=INK,width=3)
dim((605,bed),(605,floor),'', (605,(bed+floor)/2))
text(565,1100,'810 ± 10 mm',24,INK,'rm')
text(565,1132,'桌腿底部 → 台面',21,MUTED,'rm')
dim((1160,rail),(1160,bed),'',(1160,(rail+bed)/2))
text(1195,1034,'42 ± 0.5 mm',24)
text(1195,1072,'台面 → 库帮顶部',21,MUTED)
text(800,1170,'桌腿底部',20,MUTED,'mm')
text(60,1220,'来源：CBSA 2026年4月版 §1.1—1.3。数值不能与WPA Heyball或某款球桌外径混用。',23,MUTED)
im.save(ROOT/'equipment.png')
print('equipment.png: 2:1 playing area, equal scale, 635 mm offsets verified')
