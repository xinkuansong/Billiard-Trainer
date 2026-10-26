"""Equal-scale plot of exported production collision geometry and audited envelope."""
from pathlib import Path
import json, math, hashlib
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon, Circle, Rectangle, Arc
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/middle-pocket-angle-20261026'
mp=OUT/'tangent-check/metadata.json'
m=json.loads(mp.read_text());g=json.loads((OUT/'tangent-check/geometry.json').read_text())
hx=m['length']/2;hz=m['width']/2;r=m['radius'];b=g['inset'];k=1/math.tan(math.radians(g['theta']))
plt.rcParams.update({'font.family':'Heiti SC','axes.unicode_minus':False,'font.size':12,'svg.fonttype':'path'})
# Reconstruct the single closed physical contour. No invented mouth circles.
segments=[];seen=set()
for s in m['linear']:
    p=np.array([[s['start'][0],s['start'][2]],[s['end'][0],s['end'][2]]])
    key=tuple(sorted(tuple(np.round(x,6)) for x in p))
    if key not in seen:segments.append(p);seen.add(key)
for c in m['circular']:
    a=c['startAngle'];d=(c['endAngle']-a)%(2*math.pi)
    assert d<math.pi
    t=np.linspace(a,a+d,121)
    segments.append(np.c_[c['center'][0]+c['radius']*np.cos(t),c['center'][2]+c['radius']*np.sin(t)])
remaining=list(segments);chain=list(remaining.pop(0));errors=[]
while remaining:
    distance,i,rev=min((float(np.linalg.norm(chain[-1]-p[j])),i,j==-1) for i,p in enumerate(remaining) for j in [0,-1])
    assert distance<1e-6,(distance,i)
    errors.append(distance);p=remaining.pop(i)
    if rev:p=p[::-1]
    chain.extend(p[1:])
assert np.linalg.norm(chain[-1]-chain[0])<1e-6
contour=np.array(chain)
BG='#f4f2eb';INK='#183b32';CLOTH='#206c4f';RED='#ff9983';BLUE='#8cddf6'
def table(ax):
    ax.set_aspect('equal');ax.set_facecolor(BG)
    ax.add_patch(Polygon(contour,closed=True,facecolor=CLOTH,edgecolor='none',zorder=0))
    for p in m['pockets']:
        ax.add_patch(Circle((p['center'][0],p['center'][2]),p['radius'],facecolor='#111f1b',edgecolor='none',zorder=4))
        ax.add_patch(Polygon(p['lip'],closed=True,facecolor='#172d25',edgecolor='none',zorder=4))
    for p in segments:ax.plot(p[:,0],p[:,1],color='#d6caa5',lw=1.8,zorder=6,solid_capstyle='round')
    ax.axis('off')
fig=plt.figure(figsize=(15,11),facecolor=BG)
fig.text(.055,.95,'中袋可行区域 · 按生产球桌几何绘制',fontsize=25,color=INK)
fig.text(.055,.91,'台面 2540 × 1270 mm   /   球直径 57.15 mm   /   袋嘴与圆角使用实际物理轮廓',fontsize=13,color='#557063')
ax=fig.add_axes([.055,.36,.89,.51]);table(ax)
xs=np.linspace(-hx+r,hx-r,1400);top=-hz+b+k*np.abs(xs);bot=hz-b-k*np.abs(xs)
ax.fill_between(xs,-hz+r,np.maximum(top,-hz+r),color=RED,alpha=.30,zorder=1)
ax.fill_between(xs,np.minimum(bot,hz-r),hz-r,color=BLUE,alpha=.30,zorder=1)
for side,color in [(-1,RED),(1,BLUE)]:
    ys=side*(hz-b-k*np.abs(xs));valid=np.abs(ys)<=hz-r
    ax.plot(xs,np.where(valid,ys,np.nan),color=color,lw=2.6,zorder=5)
    ax.plot(xs,np.where(~valid,ys,np.nan),color=color,lw=1.3,ls='--',zorder=5)
    ax.plot([0,0],[side*(hz-b),side*(hz-.21)],color='#d6e9dd',ls=':',lw=1.2,zorder=5)
ax.text(0,-.13,'上中袋：红线下方可候选',ha='center',color=RED,fontsize=15)
ax.text(0,.13,'下中袋：蓝线上方可候选',ha='center',color=BLUE,fontsize=15)
ax.text(-.82,-.50,'排除上中袋',ha='center',color='#ffe4db',fontsize=12)
ax.text(.82,.50,'排除下中袋',ha='center',color='#dcf5fe',fontsize=12)
# Physical-size ball, placed in the overlapping candidate region.
ax.add_patch(Circle((.73,.04),r,facecolor='#f7f3de',edgecolor='#172d25',lw=.9,zorder=8))
ax.text(.81,.05,'等比例目标球',color='#e3eee5',fontsize=10,va='center')
# Measured inner rectangle dimensions, not the visual/collision outer bounds.
ax.annotate('',xy=(-hx,-.80),xytext=(hx,-.80),arrowprops={'arrowstyle':'|-|','color':'#7a8d80','lw':.8})
ax.text(0,-.825,'2540 mm',ha='center',va='bottom',color=INK,fontsize=11)
ax.annotate('',xy=(1.45,-hz),xytext=(1.45,hz),arrowprops={'arrowstyle':'|-|','color':'#7a8d80','lw':.8})
ax.text(1.49,0,'1270 mm',rotation=90,ha='center',va='center',color=INK,fontsize=11)
ax.set_xlim(-1.48,1.55);ax.set_ylim(.78,-.85)
# Enlarged upper middle mouth; same coordinates and no shape adjustments.
zax=fig.add_axes([.055,.09,.43,.235]);table(zax)
zax.set_xlim(-.19,.25);zax.set_ylim(-hz+.14,-hz-.105)
xx=np.linspace(-.2,.26,500);yy=-hz+b+k*np.abs(xx)
zax.plot(xx,yy,color=RED,lw=2,zorder=7)
zax.plot([-.2,.26],[-hz,-hz],ls='--',color='#748a7d',lw=1,zorder=7)
zax.plot([0,0],[-hz-.08,-hz+.13],ls=':',color='#c8d9cd',lw=1,zorder=7)
zax.scatter([0],[-hz+b],s=13,color=RED,zorder=8)
zax.annotate('交点向台内偏移 9.26 mm',xy=(0,-hz+b),xytext=(-.17,-hz+.115),color='#fff2de',fontsize=10,arrowprops={'arrowstyle':'-','color':'#fff2de'},zorder=9)
zax.add_patch(Arc((0,-hz+b),.29,.29,theta1=0,theta2=90-g['theta'],color=RED,lw=1.2,zorder=8))
zax.text(.15,-hz+.028,'16.69°',color=RED,fontsize=11,zorder=9)
zax.text(-.185,-hz-.089,'上中袋局部放大',fontsize=12,color=INK)
zax.text(.12,-hz-.015,'长库基准线',fontsize=9,color=INK)
fig.text(.535,.285,'边界与长库夹角 16.69°',fontsize=20,color=INK)
fig.text(.535,.237,'与正面法线夹角 73.31°',fontsize=16,color='#557063')
fig.text(.535,.18,'红、蓝边界分别对应两个中袋；\n排除某个中袋，不等于这颗球不能打其他袋。',fontsize=12,color=INK,linespacing=1.8)
fig.text(.055,.035,'区域按球心计算，近库一球半径带未着色。当前 App 物理、无其他球遮挡；可行外沿不代表稳定进球。',fontsize=11,color='#657a6d')
fig.savefig(OUT/'real-geometry-region.png',dpi=180,facecolor=BG)
fig.savefig(OUT/'real-geometry-region.svg',facecolor=BG)
audit={'metadataSHA256':hashlib.sha256(mp.read_bytes()).hexdigest(),'uniqueLinearCount':len(seen),'arcCount':len(m['circular']),'maxJoinErrorMeters':max(errors),'closureErrorMeters':float(np.linalg.norm(contour[-1]-contour[0])),'innerAspectRatio':hx/hz,'ballDiameterMM':2*r*1000,'angleToRailDegrees':90-g['theta'],'insetMM':b*1000,'axesEqualScale':True,'productionChanged':False}
(OUT/'real-geometry-drawing-check.json').write_text(json.dumps(audit,indent=2)+'\n')
print(json.dumps(audit,indent=2))
