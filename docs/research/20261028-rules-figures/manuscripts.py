"""Original rule diagrams, research only. Pixel x-right/y-down; no App coordinates.

Table overview: 2:1 inner rectangle, head string at 1/4, spot at 3/4.
Rack closeups: equal-radius disks, exact non-overlap assertions. Five-ball cross
and 1-on-spot racks are explicitly editorial practice conventions, not standards.
Arrows in process diagrams encode sequence, never simulated shot trajectories.
"""
from pathlib import Path
from math import hypot, sqrt
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
FONT = '/System/Library/Fonts/Hiragino Sans GB.ttc'
BG, INK, MUTED, GREEN, ORANGE = '#F5F4F0', '#173D38', '#566963', '#367D6E', '#AE5727'
COLORS = {1:'#C99B22',2:'#2D71A4',3:'#BA484C',4:'#805997',5:'#CB773A',6:'#317762',7:'#82493E',8:'#28342F',9:'#C99B22',10:'#2D71A4',11:'#BA484C',12:'#805997',13:'#CB773A',14:'#317762',15:'#82493E'}

def f(n): return ImageFont.truetype(FONT, n)
def t(d,x,y,s,n=28,c=INK,anchor=None):
    d.text((x,y),s,font=f(n),fill=c,anchor=anchor)
def base(title,sub,h=1000):
    im=Image.new('RGB',(1440,h),BG);d=ImageDraw.Draw(im)
    t(d,60,42,title,44);t(d,60,108,sub,24,MUTED)
    return im,d
def card(d,box): d.rounded_rectangle(box,22,fill='white')
def arrow(d,a,b,c=GREEN,w=5):
    d.line([a,b],fill=c,width=w);dx,dy=b[0]-a[0],b[1]-a[1];l=hypot(dx,dy)
    ux,uy=dx/l,dy/l
    d.polygon([b,(b[0]-18*ux+8*uy,b[1]-18*uy-8*ux),(b[0]-18*ux-8*uy,b[1]-18*uy+8*ux)],fill=c)
def double(d,a,b): arrow(d,a,b);arrow(d,b,a)
def ball(d,x,y,num,r=29,spot=False):
    color=COLORS.get(num,'#FFFFFF')
    d.ellipse((x-r,y-r,x+r,y+r),fill=color,outline='#A5B6AE',width=2)
    if num>8:
        # White polar caps identify striped balls, with a colored equator.
        d.pieslice((x-r+2,y-r+2,x+r-2,y+r-2),180,360,fill='white')
        d.pieslice((x-r+2,y-r+2,x+r-2,y+r-2),0,180,fill='white')
        # Rounded stripe remains contained in the circular contour.
        d.rounded_rectangle((x-r+3,y-r*.42,x+r-3,y+r*.42),7,fill=color)
    if num:
        d.ellipse((x-14,y-14,x+14,y+14),fill='white')
        t(d,x,y-1,str(num),19,INK,'mm')
    if spot:d.ellipse((x-r-6,y-r-6,x+r+6,y+r+6),outline=ORANGE,width=3)
def rack(d,cx,y,rows,spot,r=29):
    pts=[]
    for j,row in enumerate(rows):
        for k,n in enumerate(row):
            x=cx+(k-(len(row)-1)/2)*2*r;yy=y+j*sqrt(3)*r
            pts.append((n,x,yy));ball(d,x,yy,n,r,n==spot)
    for i,(_,x,yy) in enumerate(pts):
        for _,xx,y2 in pts[i+1:]:assert hypot(x-xx,yy-y2)>=2*r-1e-6
    return pts
def save(im,name):im.save(OUT/name)

# 1. Table: schematic openings, not pocket construction dimensions.
im,d=base('先认识球桌上的位置','尺寸采用 CBSA 2026年4月版；球与球袋为识图放大，不按实物比例',1000)
x0,y0,x1,y1=160,290,1280,850
assert x1-x0==2*(y1-y0)
d.rounded_rectangle((x0-25,y0-25,x1+25,y1+25),20,fill='#765F47')
d.rectangle((x0,y0,x1,y1),fill='#D8EAE0')
hx=x0+(x1-x0)/4;fx=x0+3*(x1-x0)/4
d.rectangle((x0,y0,hx,y1),fill='#B5D4C3')
for x,y in [(x0,y0),(x0,y1),(x1,y0),(x1,y1),((x0+x1)/2,y0),((x0+x1)/2,y1)]:
    d.ellipse((x-16,y-16,x+16,y+16),fill='#173D38')
d.line((hx,y0,hx,y1),fill=GREEN,width=4)
d.line((x0,(y0+y1)/2,x1,(y0+y1)/2),fill='#A2BBAF',width=2)
d.ellipse((fx-6,564,fx+6,576),fill=ORANGE)
ball(d,295,570,0,25)
t(d,300,420,'开球线后',31,INK,'mm');t(d,300,465,'白球球心在线左侧',21,MUTED,'mm')
t(d,hx+14,330,'开球线',27);t(d,fx,620,'置球点',29,INK,'mm')
t(d,95,570,'底库',25,INK,'mm');t(d,1350,570,'顶库',25,INK,'mm')
t(d,720,265,'中袋',23,INK,'mm');t(d,1210,258,'角袋',23,INK,'mm')
double(d,(160,195),(1280,195));t(d,720,163,'库边以内：2540 ± 10 mm',28,INK,'mm')
double(d,(1390,305),(1390,835));t(d,970,795,'短边：1270 ± 10 mm',25)
double(d,(160,910),(440,910));t(d,300,945,'635 mm',25,INK,'mm')
double(d,(1000,910),(1280,910));t(d,1140,945,'635 mm',25,INK,'mm')
save(im,'table-map.png')

# 2. Distinguish sourced numerical specification from a different body's concept.
im,d=base('袋口：先问采用哪份标准，再问量哪里','数值表与右侧概念图来自不同口径，不能拼成中式袋口检验模板',970)
card(d,(48,180,690,850));card(d,(720,180,1392,850))
t(d,80,210,'GB/T 22751—2008 · 中式球台',28)
t(d,80,282,'角袋',30);t(d,360,280,'84 ± 1 mm',40)
t(d,80,360,'中袋',30);t(d,360,358,'86 ± 1 mm',40)
t(d,80,460,'国家推荐性产品标准 · 表1',26)
t(d,80,510,'2025年复审：继续有效',26)
t(d,80,600,'CBSA 2026规则正文要求符合协会规定，',24,MUTED)
t(d,80,644,'但正文未列角袋／中袋数值表。',24,MUTED)
t(d,80,730,'不能宣称所有赛事都统一为84／86。',25,ORANGE)
t(d,755,210,'WPA普尔：入口宽度 ≠ 袋台深度',27)
# Generic side pocket concept, not dimensionally scaled.
d.rectangle((780,320,1330,650),fill='#D8EAE0')
d.polygon([(780,320),(945,320),(1000,455),(780,455)],fill='#6C9381')
d.polygon([(1165,320),(1330,320),(1330,455),(1110,455)],fill='#6C9381')
d.ellipse((1005,298,1105,402),fill='#173D38')
double(d,(1000,455),(1110,455));t(d,1055,500,'入口宽度',27,INK,'mm')
d.line((1000,455,1110,455),fill=ORANGE,width=3)
double(d,(1055,405),(1055,452));t(d,1195,395,'袋台深度',24,INK,'mm')
t(d,755,690,'入口：两侧库鼻转入袋口处之间。',24)
t(d,755,735,'深度：入口连线中点到石板落袋边缘。',23)
t(d,60,905,'来源：GB/T表1、第6.1条；WPA设备规格第9节。右图仅解释概念，非比例图。',24,MUTED)
save(im,'pocket-guide.png')

im,d=base('中八怎样摆球','CBSA 2026「71」；顶角号码不限，其他球位随机，下面只是一例',1000)
card(d,(48,180,1392,900))
t(d,480,230,'开球方向 ↓',28,INK,'mm')
p=rack(d,480,340,[[7],[2,10],[3,8,11],[4,12,5,13],[1,14,6,15,9]],7,43)
assert sorted(n for n,_,_ in p)==list(range(1,16))
t(d,850,320,'顶角球压置球点',31)
t(d,850,420,'黑8在第三排中央',31)
t(d,850,520,'底边两角各一组',31)
t(d,850,565,'一颗全色、一颗花色',26,MUTED)
t(d,850,690,'不要求1号在最前面',28,ORANGE)
t(d,90,830,'橙色外圈只表示“压置球点”，不改变球的身份。',27,MUTED)
save(im,'eight-rack.png')

im,d=base('开球以后，怎样确定全色／花色','三个独立例子都假设击球合法；箭头只表示接触先后，不是物理路线',1060)
rows=[(185,3,'白球先碰3，3进袋','确定全色，继续打。'),(440,6,'白球先碰3，3把6撞进','同组传球：确定全色，继续打。'),(695,11,'白球先碰3，只把11撞进','仍然开放，交出球权。')]
for y,n,title,footer in rows:
    card(d,(48,y,1392,y+225));t(d,80,y+23,title,30)
    ball(d,160,y+126,0,33);ball(d,360,y+126,3,33)
    arrow(d,(202,y+126),(316,y+126))
    if n!=3:
        ball(d,570,y+126,n,33);arrow(d,(403,y+126),(526,y+126));arrow(d,(614,y+126),(715,y+126))
    else:arrow(d,(403,y+126),(715,y+126))
    t(d,750,y+124,'进袋',27,INK,'mm');t(d,850,y+116,footer,27,ORANGE if n==11 else GREEN)
t(d,60,988,'来源：CBSA 2026年4月版 §5.3。开球本身不分组。',25,MUTED)
save(im,'grouping.png')

im,d=base('打黑8：先看进袋结果，再判断胜负','正常击球阶段；开球进8、开球飞8另有规则',960)
cases=[('己方球已清完 → 合法进8','赢这一局',GREEN),('己方还有球 → 提前进8','输这一局',ORANGE),('最后己方球与8 → 同一杆进袋','输这一局',ORANGE),('8进袋 → 同时白球落袋／其他犯规','输这一局',ORANGE),('8飞出台','输这一局',ORANGE),('正在打8 → 白球落袋，但8仍在台上','一般犯规，对手全台自由球',GREEN)]
for i,(a,b,c) in enumerate(cases):
    y=182+i*112;card(d,(48,y,1392,y+95));t(d,80,y+28,a,29);t(d,930,y+28,b,27,c)
t(d,60,895,'来源：CBSA 2026年4月版 §5.6—5.7；另有严重行为、战术犯规等特殊规定。',23,MUTED)
save(im,'eight-results.png')

im,d=base('四／五／六／九球：本文试玩摆法','全部为教学约定：1号压点；尤其五球十字摆法，不能当作已核实的球房标准',1160)
for x in [48,744]:
    for y in [180,650]:card(d,(x,y,x+648,y+440))
t(d,80,207,'四球：1、2、3、9',29)
rack(d,360,320,[[1],[2,3],[9]],1,35)
t(d,80,550,'三排菱形；9号在后端',25,MUTED)
t(d,780,207,'五球：1、2、3、4、9',29)
pts=[(1,1068,315),(2,998,385),(9,1068,385),(3,1138,385),(4,1068,455)]
for n,x,y in pts:ball(d,x,y,n,35,n==1)
for i,(_,x,y) in enumerate(pts):
    for _,xx,yy in pts[i+1:]:assert hypot(x-xx,y-yy)>=70-1e-6
t(d,780,550,'本稿自定十字阵；9号在中央',25,ORANGE)
t(d,80,680,'六球：1、2、3、4、5、9',29)
rack(d,360,795,[[1],[2,3],[4,9,5]],1,35)
t(d,80,1020,'三排三角形；9号在底排中央',25,MUTED)
t(d,780,680,'九球：1—9',29)
rack(d,1068,770,[[1],[2,3],[4,9,5],[6,7],[8]],1,30)
t(d,780,1020,'五排菱形；9号在中央',25,MUTED)
t(d,60,1110,'WPA 2026正式九球采用9号压点；不可拿这张试玩图代替正式赛事摆球图。',24,MUTED)
save(im,'short-racks.png')

im,d=base('三人追分：分数与球权分开看','14710教学约定；三个场景独立，所有数字均为净积分',1060)
for name,x in [('A',250),('B',720),('C',1190)]:
    d.rounded_rectangle((x-105,185,x+105,280),22,fill='#DDE9E1');t(d,x,232,name,40,INK,'mm')
arrow(d,(360,232),(605,232));arrow(d,(830,232),(1075,232))
t(d,720,325,'局内循环 A → B → C → A；合法进球继续打',27,INK,'mm')
data=[('A交出台面，B普胜',(-4,4,0),'A承担4分；本局结束。'),('A开球并大金',(20,-10,-10),'B、C各承担10分；A总共得到20分。'),('轮到B时，B普通犯规',(1,-1,0),'A得到1分；下一杆C拿全台自由球。')]
for i,(title,values,footer) in enumerate(data):
    y=390+i*195;card(d,(48,y,1392,y+176));t(d,80,y+15,title,29)
    for v,x in zip(values,[250,720,1190]):t(d,x,y+85,f'{v:+d}' if v else '0',38,INK,'mm')
    assert sum(values)==0
    t(d,80,y+130,footer,26,MUTED)
t(d,60,1007,'下局开球按本文约定轮换；别把“谁拿罚分”和“谁拿自由球”记成一回事。',24,MUTED)
save(im,'three-player-14710.png')

im,d=base('让杆：请上家回来处理，之后球权回到你','本文约定：直线完全碰不到最小号时可让杆；三人顺序原为A → B → C',1050)
card(d,(48,180,1392,360))
t(d,80,210,'A合法失手留下遮挡 → B未击球，声明让A处理 → A从原位再打',30)
t(d,80,285,'C等待。B没有把自己的轮次交给C，也没有自行移动白球。',27,MUTED)
items=[('A合法解到，但没有进球','B接着打；不罚分。'),('A解球犯规','A -1，B +1；B拿全台自由球。'),('A解进非9号球，继续后失手','球权回B；B失手后才轮到C。'),('A解进非9号球，并连续按序清台','B一人承担加倍分；C不承担。')]
for i,(a,b) in enumerate(items):
    y=405+i*128;card(d,(48,y,1392,y+108));t(d,80,y+20,a,29);t(d,80,y+63,b,27,GREEN)
t(d,60,963,'让杆直接传9：本文按普胜4分、不翻倍。其他球房可能另约定，须事先确认。',23,MUTED)
save(im,'return-turn.png')

im,d=base('谈门：把黑话展开成能判断的条件','下方“打到3号”是正文自定两人示例，不是“三金三”的权威释义',1030)
card(d,(48,180,1392,405))
t(d,80,215,'先明确谁让谁',32)
t(d,80,280,'两人：A让B',31,GREEN);t(d,640,280,'三人：A—B、A—C、B—C分别确认',29)
t(d,80,345,'A愿意让B，不代表C也同意承担同样的分数。',27,MUTED)
for x,title,lines in [(48,'获胜条件',['B仍须先碰最小号','合法进3，是否立即结束？','记普胜，还是按金分？']),(510,'特殊状态',['开球已进3怎么办？','对手打掉3怎么办？','自由球、传球、白球同下呢？']),(972,'结算与续局',['谁加分、谁减分？','只结算一对，还是全局结束？','下一杆、下一局轮到谁？'])]:
    card(d,(x,455,x+420,850));t(d,x+25,490,title,32)
    for j,s in enumerate(lines):t(d,x+25,577+j*70,s,23)
t(d,60,915,'一句“三金四”无法替代这些条件；球号、进球颗数、金分档位也不能混为一谈。',25,ORANGE)
save(im,'handicap.png')
print('Generated 9 manuscript diagrams; table ratio, rack non-overlap and score sums verified.')
