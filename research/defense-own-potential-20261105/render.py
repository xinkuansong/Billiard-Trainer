from pathlib import Path
import json, math, itertools
import numpy as np
from matplotlib.collections import PolyCollection
from matplotlib.patches import Circle
from matplotlib.backends.backend_pdf import PdfPages
import geometric_table as g

out=g.OUT;old=out.parent/'defense-region-routes-20261105';plt=g.plt
config=json.loads((out/'scenario.json').read_text());inputs={x['label']:x for x in config['cases']}
selected=json.loads((out/'selected.json').read_text());oldsummary={x['label']:x for x in json.loads((old/'summary.json').read_text())}
summary=[];figures=[]

def angle(v):return '未确认正宽窗' if v is None else (f'{v:.3f}°' if v<.1 else f'{v:.2f}°')
def score(v):return '≈100' if 99.95<=v<100 else f'{v:.1f}'
def overlay(ax,scan):
    verts=[];colors=[]
    for r in scan['rows']:
        if r.get('score',-1)<90:continue
        x,z,x1,z1=r['bounds'];verts.append([(x,z),(x1,z),(x1,z1),(x,z1)])
        colors.append('#ffc247' if r['score']<95 else '#f38b45')
    c=PolyCollection(verts,facecolors=colors,edgecolors='none',alpha=.35,zorder=2.5);ax.add_collection(c)
    c.set_clip_path(g.Polygon(g.outline,closed=True,transform=ax.transData))

def shot(ax,label,scan,route,own,title):
    g.table(ax);overlay(ax,scan);q=inputs[label]['question']
    if route is None:
        ax.text(0,0,'有限搜索未找到联合达标解',ha='center',color='white',fontsize=12)
        g.ball(ax,q['cue'],0)
        for b in q['balls']:g.ball(ax,b['position'],b['number'])
        ax.set_title('本轮未选出稳定代表（保留初态）',loc='left',fontsize=12,color='#193a35');return
    hit=next(e['time'] for e in route['events'] if e['kind']=='ballBall')
    cue=np.array(route['tracks']['cueBall']);obj=np.array(route['tracks']['_8'])
    for p,c,style in [(cue[cue[:,0]<=hit+1e-5],'white','-'),(cue[cue[:,0]>=hit-1e-5],'white','--'),(obj,'#16211e','--')]:
        if len(p)>1:
            ax.plot(p[:,1],p[:,2],color='#dae9df' if c!='white' else '#355447',lw=2.6,ls=style,alpha=.6,zorder=5)
            ax.plot(p[:,1],p[:,2],color=c,lw=1.45,ls=style,zorder=6)
    g.ball(ax,q['cue'],0)
    for b in q['balls']:g.ball(ax,b['position'],b['number'])
    for key,color in [('cueBall','white'),('_8','#17221d')]:ax.add_patch(Circle(route['finalPositions'][key],g.R,fill=False,ec=color,lw=1.7,zorder=12))
    if own and own.get('bestPocket') is not None:
        centre=g.geo['pockets'][own['bestPocket']]['center'];ax.add_patch(Circle(centre,.058,fill=False,ec='#bb81ff',lw=2.0,zorder=13))
    s=route['shot'];marker='†' if route['effect'].get('pipeRoute',{}).get('zeroWidthEstimate') else ''
    ax.set_title(f"{title}  防守{score(route['effect']['score'])}{marker}",loc='left',fontsize=12,pad=5,color='#193a35')
    text=f"{s['cutDegrees']}°  杆速{s['speed']:.2f}  打点({s['spinX']:+.2f},{s['spinY']:+.2f})"
    if own:text+='\n8号最佳避障窗口 '+angle(own['bestClearDegrees'])+f"  ·  正宽袋口{own['openPocketCount']}个"
    if 'ownAfter' in route:text+=f"  ·  联合扰动{route['probePasses']}/4"
    ax.text(0,-.045,text,transform=ax.transAxes,fontsize=9,color='#526660',va='top')

for case in selected:
    label=case['label'];folder=out/label
    scan=json.loads((folder/'scan-adaptive.json').read_text());new=json.loads((folder/'routes.json').read_text())
    selection=json.loads((folder/'presentation-selection.json').read_text())
    new['routes']=[r for r in new['routes'] if r['id'] in selection['ids']]
    oldroutes=json.loads((old/label/'routes.json').read_text())['routes'];metrics=json.loads((folder/'old-route-metrics.json').read_text());candidates=json.loads((folder/'candidate-metrics.json').read_text())
    oldid=oldsummary[label]['overviewRoute'];previous=next(r for r in oldroutes if r['id']==oldid);previousOwn=next(x['after'] for x in metrics if x['id']==oldid)
    # Native result is ordered by effort among stable Pareto candidates.
    best=new['routes'][0] if new['routes'] else None
    before=new['ownBefore'];after=best['ownAfter'] if best else None
    summary.append({'label':label,'before':before,'oldOverviewID':oldid,'oldOverviewOwn':previousOwn,'oldPreserved':sum(x['ownPreserved'] for x in metrics),'oldCount':len(metrics),'newRetained':len(new['routes']),'jointStableCandidates':new['stableJointCandidates'],'paretoCount':new['paretoCount'],'stoppedTier':new['tiers'][-1]['tier'],'recommendedID':best['id'] if best else None,'after':after,'maximumRetainedOwnDegrees':max([r['ownAfter']['bestClearDegrees'] for r in new['routes']],default=None),'recommendedShot':best['shot'] if best else None,'recommendedDefenseScore':best['effect']['score'] if best else None,'seconds':new['seconds'],'counts':new['counts']})
    fig,axes=plt.subplots(1,2,figsize=(16,6.6));fig.patch.set_facecolor('#f4f5f0');fig.subplots_adjust(left=.03,right=.97,top=.83,bottom=.19,wspace=.08)
    shot(axes[0],label,scan,previous,previousOwn,'旧代表（仅防守筛选）')
    shot(axes[1],label,scan,best,after,'新代表（低力度优先）')
    fig.text(.03,.95,label+'  防守与我方后续进攻同时评价',fontsize=20,color='#173b32')
    fig.text(.03,.88,'8号初态最佳避障窗口 '+angle(before['bestClearDegrees'])+'；原始几何角 '+angle(before['bestGeometricDegrees']),fontsize=11,color='#526660')
    fig.text(.03,.035,'白线母球／黑线8号；实心为初态，空心为终点；紫圈标8号最佳已确认袋口。\n背景仍为对方9号的90/95分区域。†为防守0°估计分支；窗口是模型内几何潜力，不代表下一杆成功率。',fontsize=10,color='#52665b')
    fig.savefig(folder/'comparison.png',dpi=160,facecolor=fig.get_facecolor());plt.close(fig)
    with PdfPages(folder/'routes.pdf') as pdf:
        for route in new['routes']:
            fig,ax=plt.subplots(figsize=(12,8));fig.patch.set_facecolor('#f4f5f0');fig.subplots_adjust(left=.04,right=.96,bottom=.22,top=.87)
            shot(ax,label,scan,route,route['ownAfter'],f"{label} 候选{route['id']}")
            fig.text(.04,.05,'8号最佳避障窗口：'+angle(before['bestClearDegrees'])+' → '+angle(route['ownAfter']['bestClearDegrees'])+'\n六袋原始角和避障角分别保存；未知袋口不伪造为0。紫圈为最佳已确认袋口，未假定下次母球位置。',fontsize=11,color='#52665b')
            fig.savefig(folder/f"route-{route['id']:02}.png",dpi=150,facecolor=fig.get_facecolor());pdf.savefig(fig);plt.close(fig)
    figures.append((label,scan,previous,previousOwn,best,after))
fig,axes=plt.subplots(len(figures),2,figsize=(16,5.2*len(figures)));fig.patch.set_facecolor('#f4f5f0');fig.subplots_adjust(left=.035,right=.965,top=.95,bottom=.04,wspace=.08,hspace=.32)
for row,(label,scan,previous,previousOwn,best,after) in enumerate(figures):
    shot(axes[row,0],label,scan,previous,previousOwn,label+' 旧代表');shot(axes[row,1],label,scan,best,after,label+' 新代表（低力度）')
fig.text(.035,.98,'防守候选重选：同时保留8号的进球容错角',fontsize=23,color='#173b32')
fig.text(.035,.012,'杆法按需，无切角／吃库配额。白线母球、黑线8号、空心圈终点；紫圈为8号最佳已确认袋口。\n有解的新代表通过4次联合扰动；有限采样不等于实战保证。†表示现行防守评分的0°估计分支。',fontsize=11,color='#52665b')
fig.savefig(out/'comparison-overview.png',dpi=150,facecolor=fig.get_facecolor());fig.savefig(out/'comparison-overview.pdf',facecolor=fig.get_facecolor());plt.close(fig)
(out/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
print(json.dumps([{k:v for k,v in row.items() if k not in ['before','after','oldOverviewOwn','counts']} for row in summary],ensure_ascii=False,indent=2))
