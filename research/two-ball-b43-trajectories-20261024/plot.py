from pathlib import Path
import json, math
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Rectangle, Polygon
from matplotlib.font_manager import fontManager

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/two-ball-second-difficulty-20261024'
d=json.loads((OUT/'b43-trajectories.json').read_text())
ex=json.loads((OUT/'example.json').read_text())
geo=json.loads((ROOT/'output/two-ball-object-distance-sampled-20261024/object-distance-sampled-bank.json').read_text())['geometry']
board=d['board'];b=ex['candidate']['position'];r=geo['radius'];hx=geo['length']/2;hz=geo['width']/2
colors={411:'#1675bc',41:'#7650a5',183:'#d26922'}
fontManager.addfont('/Library/Fonts/Arial Unicode.ttf')
plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})

def label(ax,text,pos,where,color,size=11):
    ax.annotate(text,xy=pos,xytext=where,ha='center',va='center',fontsize=size,color=color,zorder=15,
        bbox=dict(boxstyle='round,pad=.3',fc='#fafbf8',ec=color,lw=.9),
        arrowprops=dict(arrowstyle='-',color=color,lw=1))

def table(ax):
    ax.set_aspect('equal')
    ax.add_patch(Rectangle((-hx-.065,-hz-.065),2*hx+.13,2*hz+.13,facecolor='#345d50',zorder=0))
    ax.add_patch(Rectangle((-hx,-hz),2*hx,2*hz,facecolor='#dbe9d9',zorder=1))
    for p in geo['pockets']:
        ax.add_patch(Polygon([(q['x'],q['z']) for q in p['lip']],color='#193c33',zorder=2))
        ax.add_patch(Circle((p['center']['x'],p['center']['z']),p['radius'],color='#193c33',zorder=2))
    for x in [-.9525,-.635,-.3175,.3175,.635,.9525]:
        for z in [-hz-.032,hz+.032]:ax.plot(x,z,'D',ms=3,color='#c9d7cb',zorder=3)
    for z in [-.3175,0,.3175]:
        for x in [-hx-.032,hx+.032]:ax.plot(x,z,'D',ms=3,color='#c9d7cb',zorder=3)
    p=geo['pockets'][board['pocket']]['center']
    ax.add_patch(Circle((p['x'],p['z']),.067,fill=False,ec='#b27c0f',lw=2.6,zorder=7))
    ax.axis('off')

def path(ax,row):
    color=colors[row['comboIndex']]
    pts=np.array(row['paths']['cueBall']);xy=pts[:,1:]
    ax.plot(xy[:,0],xy[:,1],color=color,lw=2.1,alpha=.92,zorder=5)
    # Direction arrows located by actual path arc length, not straight endpoint chords.
    length=np.r_[0,np.cumsum(np.linalg.norm(np.diff(xy,axis=0),axis=1))]
    for frac in [.15,.4,.65,.85]:
        a=np.searchsorted(length,max(0,frac*length[-1]-.035));j=np.searchsorted(length,min(length[-1],frac*length[-1]+.035))
        if j>a:
            ax.annotate('',xy=xy[j],xytext=xy[a],arrowprops=dict(arrowstyle='->',color=color,lw=1.8),zorder=6)
    end=row['cueStop'];ax.add_patch(Circle(end,r,fc='white',ec=color,lw=2.1,zorder=9))
    # First object's actual replay up to its selected-pocket capture event.
    capture=next(e['time'] for e in row['events'] if e['kind']=='pocket' and e['ball']=='object')
    obj=np.array([p for p in row['paths']['object'] if p[0]<=capture])
    ax.plot(obj[:,1],obj[:,2],color='#b27c0f',lw=1.5,ls='--',alpha=.8,zorder=4)

def balls(ax):
    for pos,fill,edge,text in [(board['cue'],'white','#294438','C'),(board['object'],'#e9b234','#755113','A'),(b,'#fff4d9','#aa7823','B')]:
        ax.add_patch(Circle(pos,r,fc=fill,ec=edge,lw=1.8,zorder=10))
        ax.text(*pos,text,ha='center',va='center',fontsize=9,color=edge,zorder=11)

fig=plt.figure(figsize=(16,10),facecolor='#fafbf8');ax=fig.add_axes([.045,.19,.91,.65]);table(ax)
for row in d['rows']:path(ax,row)
balls(ax)
label(ax,'C · 起始母球',board['cue'],(1.51,-.43),'#294438')
label(ax,'A · 第一颗目标球',board['object'],(1.52,-.04),'#755113')
label(ax,'B43 · 第二球参照',b,(.20,.32),'#aa7823')
positions={411:(.45,-.43),41:(-1.0,-.35),183:(1.52,.27)}
for row in d['rows']:label(ax,f"{row['comboIndex']} 停点",row['cueStop'],positions[row['comboIndex']],colors[row['comboIndex']])
p=geo['pockets'][3]['center'];label(ax,'原目标袋：右下角袋',(p['x'],p['z']),(1.23,.86),'#a06f10')
ax.set_xlim(-hx-.12,1.80);ax.set_ylim(.98,-.80)
fig.text(.055,.94,'起始球形与三个组合的真实母球轨迹',fontsize=23,color='#213e34')
fig.text(.055,.895,'同一起点、同一颗第一球、同一个右下角目标袋 · 复用原参数重跑，停点与全量记录一致',fontsize=12,color='#5a6b62')
for i,row in enumerate(d['rows']):
    x=.065+i*.32;cid=row['comboIndex']
    fig.text(x,.16,f"组合 {cid} · 母球碰球后吃 {row['cueMainRailsAfterContact']} 库",fontsize=14,color=colors[cid])
    fig.text(x,.12,f"杆速 {row['velocity']:.3f} m/s   打点 ({row['spinX']:.3f}, {row['spinY']:.3f})",fontsize=11,color='#4b5f54')
fig.text(.055,.065,'彩色实线：真实母球轨迹；金色虚线：第一球进袋轨迹。白球彩色圈：各组合终点。',fontsize=11,color='#5a6b62')
fig.text(.055,.032,'B43仅作位置参照，未加入本轮模拟；图中不是加入第二球后重新验证过的三球轨迹。',fontsize=11,color='#7b5f32')
fig.savefig(OUT/'b43-start-and-trajectories.png',dpi=170);fig.savefig(OUT/'b43-start-and-trajectories.svg');plt.close(fig)

fig,axes=plt.subplots(3,1,figsize=(12,20),facecolor='#fafbf8')
for ax,row in zip(axes,d['rows']):
    table(ax);path(ax,row);balls(ax)
    cid=row['comboIndex'];color=colors[cid]
    ax.set_xlim(-hx-.14,hx+.45);ax.set_ylim(hz+.23,-hz-.15)
    ax.set_title(f"组合 {cid} · 碰球后吃 {row['cueMainRailsAfterContact']} 库 · 杆速 {row['velocity']:.3f} m/s",loc='left',fontsize=16,color=color,pad=12)
    label(ax,'起始C',board['cue'],(.96,-.55),'#294438',10)
    label(ax,'第一球A',board['object'],(1.50,-.02),'#755113',10)
    label(ax,'B43参照',b,(.20,.30),'#aa7823',10)
    end=row['cueStop'];where={411:(.58,-.39),41:(-1.0,-.35),183:(1.50,.28)}[cid]
    label(ax,'母球终点',end,where,color,10)
    ax.text(1.20,.80,'目标：右下角袋',ha='center',fontsize=10,color='#a06f10')
fig.suptitle('三个组合分开展示 · 相同坐标与比例',fontsize=23,y=.985)
fig.text(.08,.015,'实线为母球真实轨迹，金色虚线为第一球进袋轨迹；B43仅作参照，未参与模拟。',fontsize=11,color='#5a6b62')
fig.subplots_adjust(top=.95,bottom=.04,left=.05,right=.97,hspace=.13)
fig.savefig(OUT/'b43-trajectories-separate.png',dpi=150);plt.close(fig)
print('Rendered overlay and three individual replay diagrams.')
