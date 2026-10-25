from pathlib import Path
import json,math,importlib.util,hashlib
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle,Rectangle,Polygon
from matplotlib.font_manager import fontManager
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'output/two-ball-second-difficulty-20261024'
OUT=ROOT/'output/two-ball-b42-dedup75-20261024';OUT.mkdir(exist_ok=True)
analysis=json.loads((SRC/'analysis.json').read_text())
replay=json.loads((SRC/'b43-all95-trajectories.json').read_text())
geo=json.loads((ROOT/'output/two-ball-object-distance-sampled-20261024/object-distance-sampled-bank.json').read_text())['geometry']
board=replay['board'];r=geo['radius'];hx=geo['length']/2;hz=geo['width']/2
trials={q['comboIndex']:q for q in replay['rows']}
fontManager.addfont('/Library/Fonts/Arial Unicode.ttf')
plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
palette=['#1476b8','#e37824','#24863e','#bd4160','#845ac5','#9a741c','#008a92','#b650a2','#655d4e','#384f9e']
names=['左上角袋','右上角袋','左下角袋','右下角袋','上中袋','下中袋']
selected=[(2,'左上区域'),(5,'上中袋附近'),(10,'右上区域'),(24,'左侧短库附近'),(42,'台面中部'),(48,'左下区域'),(65,'下中袋附近'),(70,'右下区域')]

def nearest(path,b):
    pts=np.array(path);a=pts[:-1,1:];v=pts[1:,1:]-a;vv=np.sum(v*v,axis=1)
    u=np.clip(np.divide(np.sum((b-a)*v,axis=1),vv,out=np.zeros(len(v)),where=vv>0),0,1)
    q=a+u[:,None]*v;dist=np.linalg.norm(q-b,axis=1);i=int(np.argmin(dist))
    return dict(distance=float(dist[i]),time=float(pts[i,0]+u[i]*(pts[i+1,0]-pts[i,0])),point=q[i].tolist())

# Segment crossing and endpoint clamp must both be considered.
assert nearest([[0,-1,0],[1,1,0]],np.array([0,0]))['distance']==0
assert nearest([[0,0,0],[1,1,0]],np.array([2,0]))['distance']==1

def evaluate(cid):
    candidate=next(c for c in analysis['candidates'] if c['cellID']==cid);b=np.array(candidate['position'])
    kept=[];removed=[]
    old=sorted([q for q in analysis['rows'] if next(e for e in q['evaluations'] if e['cellID']==cid)['best']],key=lambda q:(next(e for e in q['evaluations'] if e['cellID']==cid)['best']['score'],q['comboIndex']))
    oldr={q['comboIndex']:i+1 for i,q in enumerate(old)}
    for q in analysis['rows']:
        e=next(e for e in q['evaluations'] if e['cellID']==cid);t=trials[q['comboIndex']]
        capture=next(e['time'] for e in t['events'] if e['kind']=='pocket' and e['ball']=='object')
        checks={'cue':nearest(t['paths']['cueBall'],b),'object':nearest([p for p in t['paths']['object'] if p[0]<=capture],b)}
        collision=[name for name,c in checks.items() if c['distance']<=2*r]
        row=dict(comboIndex=q['comboIndex'],oldRank=oldr.get(q['comboIndex']),cueStop=q['cueStop'],spinX=q['spinX'],spinY=q['spinY'],velocity=q['velocity'],mainRails=q['mainRails'],evaluation=e,pathChecks=checks,collisionBalls=collision)
        (removed if collision or e['status']!='available' else kept).append(row)
    kept.sort(key=lambda q:(q['evaluation']['best']['score'],q['comboIndex']))
    for i,q in enumerate(kept,1):q['rank']=i
    assert len(kept)+len(removed)==95 and len({q['comboIndex'] for q in kept+removed})==95
    assert all(q['pathChecks'][n]['distance']>2*r for q in kept for n in ['cue','object'])
    return dict(cellID=cid,position=b.tolist(),keptCount=len(kept),removedCount=len(removed),rows=kept,removed=removed)

def table(ax):
    ax.set_aspect('equal');ax.axis('off')
    ax.add_patch(Rectangle((-hx-.065,-hz-.065),2*hx+.13,2*hz+.13,fc='#345d50',zorder=0))
    ax.add_patch(Rectangle((-hx,-hz),2*hx,2*hz,fc='#dbe9d9',zorder=1))
    for p in geo['pockets']:
        ax.add_patch(Polygon([(q['x'],q['z']) for q in p['lip']],color='#193c33',zorder=2))
        ax.add_patch(Circle((p['center']['x'],p['center']['z']),p['radius'],color='#193c33',zorder=2))
    p=geo['pockets'][board['pocket']]['center'];ax.add_patch(Circle((p['x'],p['z']),.067,fill=False,ec='#b27c0f',lw=2.6,zorder=7))
    ax.set_xlim(-hx-.13,hx+.13);ax.set_ylim(hz+.16,-hz-.16)

def balls(ax,b):
    for pos,fill,edge,txt in [(board['cue'],'white','#294438','C'),(board['object'],'#e9b234','#755113','A'),(b,'#fff4d9','#aa7823','B')]:
        ax.add_patch(Circle(pos,r,fc=fill,ec=edge,lw=1.8,zorder=12));ax.text(*pos,txt,ha='center',va='center',fontsize=9,color=edge,zorder=13)

def path(ax,t,color,alpha=1):
    xy=np.array(t['paths']['cueBall'])[:,1:];ax.plot(xy[:,0],xy[:,1],color=color,lw=1.8,alpha=alpha,zorder=4)
    length=np.r_[0,np.cumsum(np.linalg.norm(np.diff(xy,axis=0),axis=1))]
    for frac in [.25,.55,.8]:
        i=np.searchsorted(length,max(0,frac*length[-1]-.025));j=np.searchsorted(length,min(length[-1],frac*length[-1]+.025))
        if j>i:ax.annotate('',xy=xy[j],xytext=xy[i],arrowprops=dict(arrowstyle='->',color=color,lw=1.5,alpha=alpha),zorder=5)
    capture=next(e['time'] for e in t['events'] if e['kind']=='pocket' and e['ball']=='object')
    obj=np.array([p for p in t['paths']['object'] if p[0]<=capture]);ax.plot(obj[:,1],obj[:,2],color='#b27c0f',lw=1.3,ls='--',alpha=.7,zorder=3)
    ax.add_patch(Circle(t['cueStop'],r,fc='white',ec=color,lw=1.8,zorder=8))

def stoplabels(ax,rows):
    occupied=[np.array(board['cue']),np.array(board['object'])]+[np.array(q['cueStop']) for q in rows]
    for q,color in zip(rows,palette):
        end=np.array(q['cueStop']);options=[]
        for radius in [.09,.15,.22,.3]:
            for theta in np.arange(0,2*math.pi,math.pi/4):
                x=end+radius*np.array([math.cos(theta),math.sin(theta)])
                if abs(x[0])>hx+.07 or abs(x[1])>hz+.10:continue
                gap=min(np.linalg.norm(x-y) for y in occupied)
                options.append((max(0,.10-gap)*20+radius,x))
        where=min(options,key=lambda x:x[0])[1];occupied.append(where)
        ax.annotate(str(q['rank']),xy=end,xytext=where,ha='center',va='center',fontsize=10,color=color,zorder=15,bbox=dict(boxstyle='round,pad=.2',fc='#fafbf8',ec=color,lw=.7),arrowprops=dict(arrowstyle='-',color=color,lw=.8))

def render(data,region):
    cid=data['cellID'];b=data['position'];rows=data['rows'][:10];assert len(rows)==10
    fig=plt.figure(figsize=(17,12),facecolor='#fafbf8');ax=fig.add_axes([.045,.35,.91,.49]);table(ax)
    for q,color in zip(rows,palette):path(ax,trials[q['comboIndex']],color,.85)
    balls(ax,b);stoplabels(ax,rows)
    ax.annotate(f'B{cid}',xy=b,xytext=(b[0]+(-.17 if b[0]>0 else .17),b[1]+(.16 if b[1]<0 else -.16)),fontsize=13,color='#835d19',ha='center',zorder=17,bbox=dict(fc='#fff6dd',ec='#aa7823',boxstyle='round,pad=.25'),arrowprops=dict(arrowstyle='-',color='#aa7823'))
    fig.text(.055,.945,f'B{cid} · {region}：排名前十的母球轨迹',fontsize=24,color='#213e34')
    fig.text(.055,.90,f"93组有效 → 去重保留{data['keptCount']}条 / 合并{data['removedCount']}组 · 相似度≥75分合并 · 原难度评分不变",fontsize=13,color='#5a6b62')
    for i,q in enumerate(rows):
        e=q['evaluation']['best'];x=.06+(i//5)*.49;y=.31-(i%5)*.045
        fig.text(x,y,f"{i+1:>2}  组合{q['comboIndex']:>3}（原{q['oldRank']}名）· S={e['score']:.4f} · {names[e['pocket']]} · {q['mainRails']}库",fontsize=12,color=palette[i])
        fig.text(x,y-.019,f"杆速 {q['velocity']:.3f} m/s    左右 {q['spinX']:+.3f} / 高低 {q['spinY']:+.3f}",fontsize=10,color='#4b5f54')
    fig.text(.055,.064,'C：起始母球；A：第一球；金圈：原右下目标袋。编号为排名，彩色线为真实母球轨迹，彩圈为停点。',fontsize=11,color='#5a6b62')
    fig.text(.055,.031,'已过滤途中碰B42的组合，再按碰后轨迹相似度去重；尚未进行三球、第二杆进袋与扰动稳定性验证。',fontsize=11,color='#7b5f32')
    fig.savefig(OUT/f'B{cid:02}-top10.png',dpi=150);plt.close(fig)
    fig,axes=plt.subplots(5,2,figsize=(18,27),facecolor='#fafbf8')
    for ax,q,color in zip(axes.flat,rows,palette):
        table(ax);path(ax,trials[q['comboIndex']],color);balls(ax,b)
        end=q['cueStop'];ax.annotate(f"终点{q['rank']}",xy=end,xytext=(end[0]+(-.18 if end[0]>0 else .18),end[1]+(.16 if end[1]<0 else -.16)),fontsize=10,color=color,ha='center',bbox=dict(fc='white',ec=color,boxstyle='round,pad=.2'),arrowprops=dict(arrowstyle='-',color=color),zorder=15)
        e=q['evaluation']['best'];ax.set_title(f"第{q['rank']}名（原{q['oldRank']}名）· 组合{q['comboIndex']} · S={e['score']:.4f} · {names[e['pocket']]}",loc='left',fontsize=15,color=color,pad=12)
        ax.text(-hx,hz+.13,f"杆速{q['velocity']:.3f} m/s · 打点({q['spinX']:+.3f}, {q['spinY']:+.3f}) · {q['mainRails']}库",fontsize=10,color='#4b5f54')
    fig.suptitle(f'B{cid} · {region} · 前十名逐组轨迹',fontsize=25,y=.986,color='#213e34')
    fig.text(.06,.962,'C为起始母球，A为第一球，B为固定第二球，金圈为原目标袋；原始求解轨迹按整段球体扫掠过滤。',fontsize=13,color='#5a6b62')
    fig.subplots_adjust(top=.94,bottom=.025,left=.04,right=.97,hspace=.22,wspace=.08)
    fig.savefig(OUT/f'B{cid:02}-individual.png',dpi=130);plt.close(fig)


data=json.loads((OUT/"dedup-result.json").read_text())
render(data,"75分阈值去重后")
print("Deduplicated top 10 overview and individual panels rendered.")
