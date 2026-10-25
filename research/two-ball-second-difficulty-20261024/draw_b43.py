"""Plot saved B43 and measured cue endpoints at equal world-coordinate scale."""
from pathlib import Path
import json, math, sys
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Rectangle, Polygon
from matplotlib.font_manager import fontManager

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'output/two-ball-second-difficulty-20261024'
sys.path.insert(0, str(ROOT/'scripts/training-question-bank'))
from pocket_geometry_filter import Geometry, pocket_metrics

d = json.loads((OUT/'example.json').read_text())
geo = json.loads((ROOT/'output/two-ball-object-distance-sampled-20261024/object-distance-sampled-bank.json').read_text())['geometry']
g = Geometry(geo['length'], geo['width'], geo['radius'])
b = d['candidate']['position']
colors = ['#1675bc', '#7650a5', '#d26922']
names = ['左上角袋','右上角袋','左下角袋','右下角袋','上中袋','下中袋']
fontManager.addfont('/Library/Fonts/Arial Unicode.ttf')
plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
fig = plt.figure(figsize=(15,9.4), facecolor='#fafbf8')
ax = fig.add_axes([.045,.21,.91,.64])
hx,hz,r = g.length/2,g.width/2,g.radius
ax.set_aspect('equal')
ax.add_patch(Rectangle((-hx-.065,-hz-.065),g.length+.13,g.width+.13,facecolor='#345d50',zorder=0))
ax.add_patch(Rectangle((-hx,-hz),g.length,g.width,facecolor='#dbe9d9',zorder=1))
for p in geo['pockets']:
    ax.add_patch(Polygon([(q['x'],q['z']) for q in p['lip']],facecolor='#193c33',zorder=2))
    ax.add_patch(Circle((p['center']['x'],p['center']['z']),p['radius'],facecolor='#193c33',zorder=2))
for x in [-.9525,-.635,-.3175,.3175,.635,.9525]:
    for z in [-hz-.032,hz+.032]: ax.plot(x,z,'D',ms=3,color='#c9d7cb',zorder=3)
for z in [-.3175,0,.3175]:
    for x in [-hx-.032,hx+.032]: ax.plot(x,z,'D',ms=3,color='#c9d7cb',zorder=3)
label_offsets = {411:(.18,-.13),41:(.03,-.14),183:(-.37,.17)}
for e,color in zip(d['examples'],colors):
    c=e['cueStop'];pid=e['best']['pocket'];p=g.anchors()[pid]
    m=pocket_metrics(c,b,p,r,pid)
    assert math.isclose(m.cut_degrees,e['best']['angle'],abs_tol=1e-9)
    dist=math.dist(b,p);u=[(p[i]-b[i])/dist for i in range(2)]
    ghost=[b[i]-2*r*u[i] for i in range(2)]
    assert math.isclose(math.dist(ghost,b),2*r,abs_tol=1e-12)
    assert abs(c[0])<hx-r and abs(c[1])<hz-r
    ax.annotate('',xy=ghost,xytext=c,arrowprops=dict(arrowstyle='->',color=color,lw=1.8,shrinkA=12,shrinkB=0),zorder=4)
    ax.annotate('',xy=p,xytext=b,arrowprops=dict(arrowstyle='->',color=color,lw=1.8,linestyle=(0,(5,4)),shrinkA=14,shrinkB=0),zorder=4)
    ax.add_patch(Circle(c,r,facecolor='white',edgecolor=color,lw=2.6,zorder=6))
    off=label_offsets[e['comboIndex']]
    ax.annotate(f"组合 {e['comboIndex']}\n母球停点",xy=c,xytext=(c[0]+off[0],c[1]+off[1]),
                color=color,fontsize=12,ha='center',va='center',zorder=7,
                bbox=dict(boxstyle='round,pad=.35',fc='#fafbf8',ec=color,lw=1),
                arrowprops=dict(arrowstyle='-',color=color,lw=1))
    ax.add_patch(Circle(p,.049,facecolor='none',edgecolor=color,lw=2,zorder=5))
    ax.text(p[0],p[1]+(-.135 if p[1]<0 else .14),names[pid],ha='center',va='center',color=color,fontsize=12)
ax.add_patch(Circle(b,r,facecolor='#edb53b',edgecolor='#674817',lw=1.8,zorder=8))
ax.annotate('B43 · 第二球固定位置',xy=b,xytext=(b[0]-.27,b[1]+.23),
            fontsize=13,color='#674817',ha='center',va='center',zorder=9,
            bbox=dict(boxstyle='round,pad=.4',fc='#fff4d9',ec='#b28a3d'),
            arrowprops=dict(arrowstyle='-',color='#8b6725',lw=1.2))
ax.set_xlim(-hx-.15,hx+.15);ax.set_ylim(hz+.22,-hz-.22);ax.axis('off')
fig.text(.055,.94,'B43不动，比较三个第一杆组合的母球停点',fontsize=23,color='#213e34')
fig.text(.055,.892,'254 × 127 cm台面 · 按实际坐标等比例绘制 · 三个白球代表三次不同击球的结果',fontsize=12,color='#5a6b62')
for i,(e,color) in enumerate(zip(d['examples'],colors)):
    x=.065+i*.32;m=e['best']
    fig.text(x,.163,f"组合 {e['comboIndex']} → {names[m['pocket']]}",fontsize=14,color=color,weight='bold')
    fig.text(x,.125,f"切角 {m['angle']:.2f}°   难度 S={m['score']:.3f}",fontsize=12,color='#33463d')
    fig.text(x,.09,f"母球→B43 {e['cueObjectDistance']*100:.1f} cm   B43→下球点 {m['distance']*100:.1f} cm",fontsize=10.5,color='#5a6b62')
fig.text(.055,.035,'实线：第二杆母球瞄准方向；虚线：B43到几何目标袋下球点。均为第二杆几何示意，不是第一杆运动轨迹。',fontsize=11,color='#5a6b62')
fig.savefig(OUT/'b43-three-endpoints.png',dpi=180,facecolor=fig.get_facecolor())
fig.savefig(OUT/'b43-three-endpoints.svg',facecolor=fig.get_facecolor())
print('PASS: saved positions, three angles and ghost distances verified; equal X/Z scale, +Z down.')
