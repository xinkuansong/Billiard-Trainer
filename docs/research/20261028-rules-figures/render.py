"""Research-only diagrams; pixel coordinates, x right/y down, no shot simulation."""
from pathlib import Path
import math
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
FONT = '/System/Library/Fonts/Hiragino Sans GB.ttc'
BG, INK, MUTED = '#F5F4F0', '#163C38', '#526661'

def font(size):
    return ImageFont.truetype(FONT, size)

def text(d, xy, s, size=24, fill=INK, anchor=None):
    d.text(xy, s, font=font(size), fill=fill, anchor=anchor)

def arrow(d, a, b, color='#397A70', width=5):
    d.line([a, b], fill=color, width=width)
    dx, dy = b[0]-a[0], b[1]-a[1]
    length = math.hypot(dx, dy)
    ux, uy = dx/length, dy/length
    d.polygon([b, (b[0]-16*ux+7*uy,b[1]-16*uy-7*ux),
               (b[0]-16*ux-7*uy,b[1]-16*uy+7*ux)], fill=color)

COLORS = {1:'#D9A924',2:'#2674AA',3:'#BF4549',4:'#815A99',5:'#CE7534',6:'#327F68',7:'#83473E',8:'#25312E'}
def ball(d, x, y, n, r=27, spot=False):
    color = COLORS.get(n if n<9 else n-8,'#D9A924')
    d.ellipse((x-r,y-r,x+r,y+r),fill='#FFFFFF' if n>8 else color,outline='#D3D6D0',width=2)
    if n>8:
        # central band stays within the disk through a mask
        layer = Image.new('RGBA',d._image.size,(0,0,0,0))
        ld = ImageDraw.Draw(layer)
        ld.ellipse((x-r+2,y-r+2,x+r-2,y+r-2),fill=color)
        mask = Image.new('L',d._image.size,0)
        ImageDraw.Draw(mask).rectangle((x-r,y-r*.49,x+r,y+r*.49),fill=255)
        band = Image.new('RGBA',d._image.size,(0,0,0,0))
        band.paste(layer,(0,0),mask)
        d._image.paste(band,(0,0),band)
    d.ellipse((x-13,y-13,x+13,y+13),fill='#FFFFFF')
    text(d,(x,y-1),str(n),18,INK,'mm')
    if spot:
        d.ellipse((x-r-5,y-r-5,x+r+5,y+r+5),outline='#B55A24',width=3)

def rack(d, cx, top, rows, spot_number):
    r=27
    positions=[]
    for j,row in enumerate(rows):
        for k,n in enumerate(row):
            x=cx+(k-(len(row)-1)/2)*2*r
            y=top+j*math.sqrt(3)*r
            positions.append((n,x,y))
            ball(d,x,y,n,r,n==spot_number)
    for i,(_,x,y) in enumerate(positions):
        for _,xx,yy in positions[i+1:]:
            assert math.hypot(x-xx,y-yy)>=2*r-1e-7
    return positions

im=Image.new('RGB',(1440,1040),BG)
d=ImageDraw.Draw(im)
text(d,(64,45),'摆阵先看规则版本',44)
text(d,(64,110),'局部放大示意 · 球的号码与关键位置为重点，不是球台比例图',24,MUTED)
for x in [48,744]:
    d.rounded_rectangle((x,175,x+648,900),24,fill='#FFFFFF')
text(d,(85,205),'中八 · CBSA 2026「71」',30)
text(d,(780,205),'九球 · WPA 2026-10-21',30)
text(d,(370,280),'开球方向 ↓',22,MUTED,'mm')
text(d,(1065,280),'开球方向 ↓',22,MUTED,'mm')
p=rack(d,370,345,[[7],[2,10],[3,8,11],[4,12,5,13],[1,14,6,15,9]],7)
q=rack(d,1065,345,[[1],[2,3],[4,9,5],[6,7],[8]],9)
assert sorted(n for n,_,_ in p)==list(range(1,16))
assert sorted(n for n,_,_ in q)==list(range(1,10))
text(d,(84,640),'顶角球压置球点；黑8在第三排中央',24)
text(d,(84,690),'底边两端：一颗全色，一颗花色',24)
text(d,(84,740),'图中7号、其余号码排列仅作示例',22,MUTED)
text(d,(780,640),'1号在前端；9号居中并压置球点',24)
text(d,(780,690),'其余号码应随机，本图只是一种示例',24)
text(d,(780,740),'不能标成旧版常见的“1号压点”',22,MUTED)
text(d,(84,825),'来源：CBSA 2026年4月版 §5.1',21,MUTED)
text(d,(780,825),'来源：WPA Rules of Play §5.2',21,MUTED)
text(d,(64,945),'橙色外圈仅标识压置球点的球；完整来源链接见调研方案。',23,MUTED)
im.save(ROOT/'racks.png')

im=Image.new('RGB',(1440,1060),BG)
d=ImageDraw.Draw(im)
text(d,(64,45),'三人追分：分数与球权要分开看',42)
text(d,(64,110),'以下是方案自定的积分演算例，不是统一比赛规则。三个场景彼此独立。',23,MUTED)
names=[('A',250),('B',720),('C',1190)]
for name,x in names:
    d.rounded_rectangle((x-105,195,x+105,295),22,fill='#E2EDE8')
    text(d,(x,242),name,39,INK,'mm')
arrow(d,(360,245),(605,245));arrow(d,(830,245),(1075,245))
text(d,(720,325),'局内循环：A → B → C → A；合法进球继续打',25,MUTED,'mm')
cards=[
 (390,'场景一：A交出台面，B普通获胜',['A -2','B +2','C 0'],'只有A承担；本局结束。'),
 (590,'场景二：A开球一轮清台',['A +12','B -6','C -6'],'另外两人各承担6分；A总共获得12分。'),
 (790,'场景三：轮到B时，B犯规',['A +1','B -1','C 0'],'A获得罚分；下一杆由C拿自由球上场。'),
]
for y,title,values,footer in cards:
    d.rounded_rectangle((48,y,1392,y+176),20,fill='#FFFFFF')
    text(d,(80,y+17),title,28)
    for value,(_,x) in zip(values,names):
        text(d,(x,y+89),value,34,INK,'mm')
    text(d,(80,y+132),footer,24,MUTED)
for row in [(-2,2,0),(12,-6,-6),(1,-1,0)]:
    assert sum(row)==0
text(d,(64,1005),'这一约定中，“拿到分”不等于“下一杆轮到我”。开打前还须确认下局顺序。',23,MUTED)
im.save(ROOT/'three-player.png')
print('Generated 2 diagrams; ball counts, no overlaps and zero-sum examples verified.')
