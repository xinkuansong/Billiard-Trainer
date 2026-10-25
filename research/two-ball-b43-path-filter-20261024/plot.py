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
d=json.loads((OUT/'b43-all95-trajectories.json').read_text())
ex=json.loads((OUT/'example.json').read_text())
geo=json.loads((ROOT/'output/two-ball-object-distance-sampled-20261024/object-distance-sampled-bank.json').read_text())['geometry']
board=d['board'];b=ex['candidate']['position'];r=geo['radius'];hx=geo['length']/2;hz=geo['width']/2
ranked=json.loads((OUT/'b43-path-filtered-ranked.json').read_text())['rows'][:10]
rankmap={q['comboIndex']:q for q in ranked}
rows={q['comboIndex']:q for q in d['rows']}
d['rows']=[rows[q['comboIndex']] for q in ranked]
palette=['#1476b8','#e37824','#24863e','#bd4160','#845ac5','#9a741c','#008a92','#b650a2','#655d4e','#384f9e']
colors={q['comboIndex']:c for q,c in zip(ranked,palette)}
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


fig=plt.figure(figsize=(17,12),facecolor='#fafbf8')
ax=fig.add_axes([.035,.31,.93,.56]);table(ax)
for row in d['rows']:path(ax,row)
balls(ax)
label(ax,'C · 起始母球',board['cue'],(1.52,-.43),'#294438',11)
label(ax,'A · 第一球',board['object'],(1.52,-.02),'#755113',11)
label(ax,'B43 · 第二球',b,(-.04,.22),'#aa7823',12)
labelpos=[(.42,-.36),(.40,-.53),(.73,-.18),(1.07,-.81),(.16,-.37),(1.09,-.30),(.32,.45),(.46,.77),(.71,.77),(1.08,.38)]
for row,pos in zip(d['rows'],labelpos):
    q=rankmap[row['comboIndex']]
    label(ax,str(q['rank']),row['cueStop'],pos,colors[row['comboIndex']],13)
p=geo['pockets'][3]['center'];label(ax,'原目标袋：右下角袋',(p['x'],p['z']),(1.42,.82),'#a06f10',11)
ax.set_xlim(-hx-.1,1.76);ax.set_ylim(.94,-.89)
fig.text(.055,.945,'B43：过滤途中碰球后，重新排名前十',fontsize=24,color='#213e34')
fig.text(.055,.902,'95组检查，剔除7组，保留88组 · 数字为新排名，分数越低越容易 · 原第三名组合332已剔除',fontsize=12,color='#5a6b62')
for i,row in enumerate(d['rows']):
    q=rankmap[row['comboIndex']];x=.06+(i//5)*.48;y=.285-(i%5)*.038
    pocket='下中袋' if q['best']['pocket']==5 else '上中袋'
    fig.text(x,y,f"{q['rank']:>2}  组合 {row['comboIndex']:>3}   S={q['best']['score']:.4f}   {pocket}   吃{row['cueMainRailsAfterContact']}库",fontsize=12,color=colors[row['comboIndex']])
fig.text(.055,.072,'彩色实线：第一杆母球真实轨迹；白色彩圈：母球停点；金色虚线：第一球进袋轨迹。',fontsize=12,color='#5a6b62')
fig.text(.055,.036,'已按完整记录路径筛除球心距B43 ≤ 5.715厘米的组合；尚未进行三球重模拟和第二杆进袋验证。',fontsize=11,color='#7b5f32')
fig.savefig(OUT/'b43-filtered-top10-overview.png',dpi=170);fig.savefig(OUT/'b43-filtered-top10-overview.svg');plt.close(fig)

fig,axes=plt.subplots(5,2,figsize=(18,27),facecolor='#fafbf8')
for ax,row in zip(axes.flat,d['rows']):
    q=rankmap[row['comboIndex']];color=colors[row['comboIndex']]
    table(ax);path(ax,row);balls(ax)
    ax.set_xlim(-hx-.1,hx+.43);ax.set_ylim(hz+.26,-hz-.18)
    ax.set_title(f"第{q['rank']}名 · 组合{row['comboIndex']} · S={q['best']['score']:.4f}",loc='left',fontsize=16,color=color,pad=12)
    label(ax,'起始C',board['cue'],(1.42,-.48),'#294438',10)
    label(ax,'第一球A',board['object'],(1.48,-.02),'#755113',10)
    label(ax,'B43',b,(.08,.26),'#aa7823',11)
    end=row['cueStop'];where=(end[0]-.23,end[1]+(.18 if end[1]<0 else -.19))
    label(ax,f"终点 {q['rank']}",end,where,color,11)
    ax.text(1.14,.81,'目标：右下角袋',ha='center',fontsize=10,color='#a06f10')
    ax.text(-1.27,.81,f"杆速 {row['velocity']:.3f} m/s · 打点 ({row['spinX']:.3f}, {row['spinY']:.3f}) · 吃{row['cueMainRailsAfterContact']}库",fontsize=10,color='#4b5f54')
fig.suptitle('过滤途中碰球后 · 新前十名母球轨迹',fontsize=25,y=.987,color='#213e34')
fig.text(.065,.966,'C为起始母球，A为第一球；金圈为原目标袋。已检查母球与第一球记录路径对B43的球体扫掠。',fontsize=13,color='#5a6b62')
fig.subplots_adjust(top=.945,bottom=.025,left=.035,right=.98,hspace=.18,wspace=.06)
fig.savefig(OUT/'b43-filtered-top10-individual.png',dpi=150);plt.close(fig)
print('Rendered top 10 overview and individual trajectories.')
