import json
from pathlib import Path
import numpy as np
from matplotlib.collections import PolyCollection
from matplotlib.patches import Circle
from matplotlib.backends.backend_pdf import PdfPages
import geometric_table as g
out=g.OUT;plt=g.plt;cases=json.loads((out/'scenario.json').read_text())['cases'];summary=json.loads((out/'summary.json').read_text())
colors=['#d0d761','#f5ad48','#ed6664'];labels=['70–80','80–90','90–100']
def overlay(ax,scan):
    verts=[];cs=[]
    for r in scan['rows']:
        score=r.get('score',-1)
        if score<70:continue
        x,z,x1,z1=r['bounds'];verts.append([(x,z),(x1,z),(x1,z1),(x,z1)]);cs.append(colors[0 if score<80 else 1 if score<90 else 2])
    coll=PolyCollection(verts,facecolors=cs,edgecolors='none',alpha=.65,zorder=2.5);ax.add_collection(coll)
    coll.set_clip_path(g.Polygon(g.outline,closed=True,transform=ax.transData))
def branch(r):
    e=r['effect']
    if e.get('fullDirectBlock') or e.get('potContactsBlocked'):return '封锁'
    if e.get('estimateReason'):return '估算'
    if (e.get('pipeRoute') or {}).get('zeroWidthEstimate'):return '0°估计'
    return '公式'
def draw(ax,case,scan,route=None):
    g.table(ax);overlay(ax,scan);q=case['question']
    if route:
        hit=next(e['time'] for e in route['events'] if e['kind']=='ballBall')
        cue=np.array(route['tracks']['cueBall']);obj=np.array(route['tracks']['_8'])
        for p,c,style in [(cue[cue[:,0]<=hit+1e-5],'white','-'),(cue[cue[:,0]>=hit-1e-5],'white','--'),(obj,'#16211e','--')]:
            if len(p)>1:
                ax.plot(p[:,1],p[:,2],color='#cde5df' if c!='white' else '#365546',lw=2.7,ls=style,alpha=.7,zorder=5)
                ax.plot(p[:,1],p[:,2],color=c,lw=1.4,ls=style,zorder=6)
        for key,c in [('cueBall','white'),('_8','#17221d')]:ax.add_patch(Circle(route['finalPositions'][key],g.R,fill=False,ec=c,lw=1.7,zorder=12))
    g.ball(ax,q['cue'],0)
    for b in q['balls']:g.ball(ax,b['position'],b['number'])
fig,axes=plt.subplots(3,3,figsize=(18,13));fig.patch.set_facecolor('#f4f5f0');fig.subplots_adjust(top=.88,bottom=.13,left=.03,right=.98,hspace=.48,wspace=.12)
for ax,case,row in zip(axes.flat,cases,summary['cases']):
    scan=json.loads((out/case['label']/'scan-adaptive.json').read_text());draw(ax,case,scan)
    ax.set_title(f"{case['label']}  9号离库{row['railGapCM']:.1f}cm",loc='left',fontsize=12,color='#173b32')
    ax.text(0,-.07,'≥70/80/90面积：'+'/'.join(f"{t['areaPercent']:.2f}%" for t in row['thresholds'])+'\n联合达标候选：'+'/'.join(str(t['robust']) for t in row['thresholds']),transform=ax.transAxes,fontsize=10,color='#355950',va='top')
fig.text(.035,.96,'90分硬门槛是否偏向贴库？九个球形对照',fontsize=24,color='#173b32')
for i,c in enumerate(colors):fig.text(.035+i*.18,.92,'■ '+labels[i]+'分区域',color=c,fontsize=14,bbox=dict(facecolor='#204b41',edgecolor='none',pad=4))
fig.text(.035,.025,'底图仅评价固定9号，含0°估计分支；实际终态另计8号遮挡。绿色为低于70分或无有效采样区域。\n候选要求我方8号已确认窗口不下降，并通过4次方向/速度扰动；候选数量不代表成功率或题库分布。',fontsize=11,color='#49645a')
fig.savefig(out/'overview.png',dpi=150,facecolor=fig.get_facecolor());fig.savefig(out/'overview.pdf',facecolor=fig.get_facecolor());plt.close(fig)
with PdfPages(out/'routes.pdf') as pdf:
    for case in cases:
        d=out/case['label'];scan=json.loads((d/'scan-adaptive.json').read_text());routes=json.loads((d/'routes.json').read_text())
        for r in routes['routes']:
            fig,ax=plt.subplots(figsize=(12,8));fig.patch.set_facecolor('#f4f5f0');fig.subplots_adjust(left=.04,right=.96,bottom=.22,top=.87)
            draw(ax,case,scan,r);s=r['shot'];before=r['ownBefore']['bestClearDegrees'];after=r['ownAfter']['bestClearDegrees']
            ax.set_title(f"{case['label']} 路线{r['id']}  防守{r['effect']['score']:.1f}分（{branch(r)}）",loc='left',fontsize=17,color='#173b32')
            fig.text(.04,.15,f"基础分{r['baseScore']:.1f} → 含8号分{r['effect']['score']:.1f}；联合达标门槛 "+'/'.join(str(int(t)) for t in r['stableThresholds'])+f"\n切角{s['cutDegrees']}°  杆速{s['speed']:.2f}  打点({s['spinX']:+.2f},{s['spinY']:+.2f})\n8号最佳已确认避障窗：{before:.3f}° → {after:.3f}°",fontsize=12,color='#355950')
            fig.text(.04,.035,'白线母球、黑线8号；空心终点。背景为无8号遮挡的基础分。\n0°估计须单独看待；4/4扰动通过不等于实战成功率；未知袋口未伪造0角。',fontsize=10,color='#49645a')
            fig.savefig(d/f"route-{r['id']:02}.png",dpi=150,facecolor=fig.get_facecolor());pdf.savefig(fig);plt.close(fig)
print(out/'overview.png')
