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
OUT=ROOT/'output/two-ball-multi-position-top10-20261024';OUT.mkdir(exist_ok=True)
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
    fig.text(.055,.90,f"95组检查 → 保留{data['keptCount']}组 / 剔除{data['removedCount']}组 · 仅按第二杆几何难度排序，尚未加入杆法、力度惩罚",fontsize=13,color='#5a6b62')
    for i,q in enumerate(rows):
        e=q['evaluation']['best'];x=.06+(i//5)*.49;y=.31-(i%5)*.045
        fig.text(x,y,f"{i+1:>2}  组合{q['comboIndex']:>3} · S={e['score']:.4f} · {names[e['pocket']]} · {q['mainRails']}库",fontsize=12,color=palette[i])
        fig.text(x,y-.019,f"杆速 {q['velocity']:.3f} m/s    左右 {q['spinX']:+.3f} / 高低 {q['spinY']:+.3f}",fontsize=10,color='#4b5f54')
    fig.text(.055,.064,'C：起始母球；A：第一球；金圈：原右下目标袋。编号为排名，彩色线为真实母球轨迹，彩圈为停点。',fontsize=11,color='#5a6b62')
    fig.text(.055,.031,'已按球直径筛除途中碰B的组合；尚未做三球重模拟、第二杆进袋及击球扰动稳定性验证。',fontsize=11,color='#7b5f32')
    fig.savefig(OUT/f'B{cid:02}-top10.png',dpi=150);plt.close(fig)
    fig,axes=plt.subplots(5,2,figsize=(18,27),facecolor='#fafbf8')
    for ax,q,color in zip(axes.flat,rows,palette):
        table(ax);path(ax,trials[q['comboIndex']],color);balls(ax,b)
        end=q['cueStop'];ax.annotate(f"终点{q['rank']}",xy=end,xytext=(end[0]+(-.18 if end[0]>0 else .18),end[1]+(.16 if end[1]<0 else -.16)),fontsize=10,color=color,ha='center',bbox=dict(fc='white',ec=color,boxstyle='round,pad=.2'),arrowprops=dict(arrowstyle='-',color=color),zorder=15)
        e=q['evaluation']['best'];ax.set_title(f"第{q['rank']}名 · 组合{q['comboIndex']} · S={e['score']:.4f} · {names[e['pocket']]}",loc='left',fontsize=15,color=color,pad=12)
        ax.text(-hx,hz+.13,f"杆速{q['velocity']:.3f} m/s · 打点({q['spinX']:+.3f}, {q['spinY']:+.3f}) · {q['mainRails']}库",fontsize=10,color='#4b5f54')
    fig.suptitle(f'B{cid} · {region} · 前十名逐组轨迹',fontsize=25,y=.986,color='#213e34')
    fig.text(.06,.962,'C为起始母球，A为第一球，B为固定第二球，金圈为原目标袋；原始求解轨迹按整段球体扫掠过滤。',fontsize=13,color='#5a6b62')
    fig.subplots_adjust(top=.94,bottom=.025,left=.04,right=.97,hspace=.22,wspace=.08)
    fig.savefig(OUT/f'B{cid:02}-individual.png',dpi=130);plt.close(fig)

results=[]
for cid,region in selected:
    data=evaluate(cid);data['region']=region;results.append(data)
    (OUT/f'B{cid:02}-ranking.json').write_text(json.dumps(data,ensure_ascii=False,indent=2,allow_nan=False))
    render(data,region);print(cid,data['keptCount'],data['removedCount'],flush=True)
# Cross-check vectorized implementation against independently used B43 scalar segment filter.
b43=evaluate(43);old=json.loads((SRC/'b43-path-filtered-ranked.json').read_text())
assert [q['comboIndex'] for q in b43['rows']]==[q['comboIndex'] for q in old['rows']]
for q,o in zip(b43['rows'],old['rows']):assert math.isclose(q['pathChecks']['cue']['distance'],o['pathChecks']['cue']['distance'],abs_tol=1e-12)
fig,axes=plt.subplots(4,2,figsize=(18,20),facecolor='#fafbf8')
for ax,data in zip(axes.flat,results):
    table(ax)
    for q,color in zip(data['rows'][:10],palette):path(ax,trials[q['comboIndex']],color,.7)
    balls(ax,data['position'])
    ax.text(*data['position'],f"  B{data['cellID']}",ha='left',va='bottom',fontsize=14,color='#835d19',zorder=20,bbox=dict(fc='#fff6dd',ec='#aa7823',boxstyle='round,pad=.2'))
    ax.set_title(f"B{data['cellID']} · {data['region']} · 保留{data['keptCount']}/95组",loc='left',fontsize=17,color='#213e34',pad=12)
fig.suptitle('8个第二球位置 · 各自前十名路线总览',fontsize=25,y=.985,color='#213e34')
fig.text(.06,.958,'初始母球、第一球与目标袋相同；先过滤途中碰第二球，再按原第二杆难度排序。各候选独立摆放。',fontsize=13,color='#5a6b62')
fig.subplots_adjust(top=.93,bottom=.025,left=.035,right=.97,hspace=.18,wspace=.08)
fig.savefig(OUT/'overview-eight-positions.png',dpi=140);plt.close(fig)
summary=dict(layoutID=board['id'],positions=8,combinationsPerPosition=95,displayedRoutes=80,ranking='unchanged minimum six-pocket OP/cos(cut); lower is easier',filter='complete cue path and first-object path until capture; point-to-segment center distance <=2R rejected',verification='95 distinct input combos per position, full classification partition, kept distances>2R; independent B43 scalar/vectorized ranking and distance agreement',sources={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [SRC/'analysis.json',SRC/'b43-all95-trajectories.json']},results=[dict(cellID=d['cellID'],region=d['region'],position=d['position'],kept=d['keptCount'],removed=d['removedCount'],top10=[q['comboIndex'] for q in d['rows'][:10]]) for d in results])
(OUT/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
md=['# 不同第二球位置：前十名轨迹图','', '同一个初始球形，选择8个不同区域的第二球位置；各位置独立摆放，合计80条入选路线。沿用第二杆六袋最低几何难度S，未新增杆法、杆速、吃库惩罚。95组真实轨迹复用上一轮原参数重跑及一致性核验结果，不重新模拟相同轨迹。','', '对整条母球路径及第一球入袋前路径进行球体扫掠检查：球心距第二球≤5.715cm剔除。原始记录120Hz并包含全部事件/状态帧。仍不是三球重模拟或第二杆进袋验证，也未测扰动稳定性。','', '坐标为米制X–Z平面，+X向右、+Z向下；打点为原记录spinX/spinY数值。前十图均标杆速、打点、吃库数及第二杆推荐袋，吃库数只作描述。','', '![8位置总览](overview-eight-positions.png)','', '|位置|区域|保留|剔除|前十叠加图|逐组分图|完整排序数据|','|---|---|---:|---:|---|---|---|']
for d in results:
    cid=d['cellID'];md.append(f"|B{cid}|{d['region']}|{d['keptCount']}|{d['removedCount']}|[查看](B{cid:02}-top10.png)|[查看](B{cid:02}-individual.png)|[JSON](B{cid:02}-ranking.json)|")
md+=['','验证：每位置95组ID唯一、分类数量闭合、保留路径全部距B>2R；B43独立向量算法与此前标量算法的全部保留ID及最小距离对拍一致。未改原数据或全量题库。']
(OUT/'README.md').write_text('\n'.join(md)+'\n')
html=['<!doctype html><html lang="zh"><meta charset="utf-8"><title>8个第二球位置的前十轨迹</title><style>body{margin:24px auto;max-width:1450px;background:#fafbf8;color:#213e34;font:18px system-ui}nav{position:sticky;top:0;background:#fafbf8;padding:16px;display:flex;gap:24px;z-index:2}img{max-width:100%;height:auto}section{scroll-margin-top:75px}summary{cursor:pointer;padding:16px;color:#176f86}</style><h1>8个第二球位置 · 各自排名前十</h1><p>同一初始球形；先剔除途中碰第二球的组合，仍按原第二杆难度排序。暂未加入力度、杆法权重。</p><nav>']
for d in results:html.append(f'<a href="#b{d["cellID"]}">B{d["cellID"]}</a>')
html.append('</nav>')
for d in results:
    cid=d['cellID'];html.append(f'<section id="b{cid}"><h2>B{cid} · {d["region"]} · 保留{d["keptCount"]}/95</h2><img src="B{cid:02}-top10.png"><details><summary>展开十组独立轨迹</summary><img loading="lazy" src="B{cid:02}-individual.png"></details></section>')
html.append('<p>已按原模拟路径做球体扫掠过滤；未进行三球重模拟、第二杆进袋或扰动稳定性验证。</p></html>')
(OUT/'index.html').write_text(''.join(html))
