"""Render measured native scores on the production CAD table; no invented trajectories."""
from pathlib import Path
import json, math, hashlib, csv
import numpy as np
from matplotlib.collections import PolyCollection
from matplotlib.colors import Normalize
from matplotlib.cm import ScalarMappable
from matplotlib.patches import Circle
import geometric_table as g

OUT=g.OUT; plt=g.plt
cmap=plt.get_cmap('plasma');norm=Normalize(0,100)
summaries=[]

def score_label(score):
    return '≈100' if 99.95<=score<100 else f'{score:.1f}'

def area(r):
    x0,z0,x1,z1=r['bounds'];return (x1-x0)*(z1-z0)

def load(item):
    folder=OUT/item['label'];scan=json.loads((folder/'scan-adaptive.json').read_text());native=json.loads((folder/'native-results.json').read_text())
    target=next(b['position'] for b in item['question']['balls'] if b['number']==9)
    assert np.allclose(scan['target'],target,atol=1e-7,rtol=0)
    assert native['passed'] and native['targetPerturbationCount']==0 and native['cacheParityCount']==0
    rows=scan['rows'];valid=[r for r in rows if 'score' in r]
    for r in valid:
        e=r['effect'];s=r['score']
        assert math.isfinite(s) and 0<=s<=100 and not e.get('unavailableReason')
        assert e['opponentBallNumber']==9
        if e.get('potContactsBlocked') or e['fullDirectBlock']:assert s==100
        else:
            expected=100*math.sqrt((1-e['comfort']/100)/(1+e['targetPipeToleranceDegrees']))
            assert abs(s-expected)<1e-8,(s,expected)
        assert math.hypot(r['x']-target[0],r['z']-target[1])>=2*g.R-1e-7
    # Adaptive leaves must partition every coarse root, without duplicate rectangles.
    assert len({tuple(r['bounds']) for r in rows})==len(rows)
    roots={}
    for r in rows: roots.setdefault((r['ix'],r['iz']),[]).append(r)
    for c in scan['coarse']:
        leaves=roots[(c['ix'],c['iz'])]
        assert abs(sum(map(area,leaves))-area(c))<1e-10
        for r in leaves:
            a,b,d,e=r['bounds'];x,z,y,w=c['bounds'];assert a>=x-1e-12 and b>=z-1e-12 and d<=y+1e-12 and e<=w+1e-12
    total=sum(map(area,valid));estimated=[r for r in valid if 'estimate' in r['status']]
    summary={'label':item['label'],'title':item['title'],'target':target,'native':native,'validLeafCount':len(valid),
             'sampleMin':min(r['score'] for r in valid),'sampleMax':max(r['score'] for r in valid),
             'areaWeightedMean':sum(r['score']*area(r) for r in valid)/total,
             'estimatedAreaPercent':100*sum(map(area,estimated))/total,
             'scoreBandAreaPercent':{f'{lo}-{lo+20}':100*sum(area(r) for r in valid if lo<=r['score']<lo+20 or lo==80 and r['score']==100)/total for lo in range(0,100,20)},
             'statusAreaPercent':{k:100*sum(area(r) for r in valid if r['status']==k)/total for k in sorted({r['status'] for r in valid})},
             'fullScoreAreaPercent':100*sum(area(r) for r in valid if r['score']==100)/total,
             'annotations':[]}
    # Labels are exact evaluated cell centres nearest a small regular set of anchors.
    # They are not averages of the surrounding region or extra parity tests.
    used=set()
    for z in [-.43,0,.43]:
        for x in [-.93,-.31,.31,.93]:
            candidates=[r for r in valid if math.hypot(r['x']-target[0],r['z']-target[1])>.14]
            r=min(candidates,key=lambda r:(r['x']-x)**2+(r['z']-z)**2)
            if (r['x'],r['z']) not in used:
                used.add((r['x'],r['z']));summary['annotations'].append({'x':r['x'],'z':r['z'],'score':r['score'],'status':r['status']})
    with (folder/'scores.csv').open('w') as f:
        writer=csv.writer(f);writer.writerow(['x_m','z_m','score','status','pipe_angle_degrees','comfort','x0','z0','x1','z1'])
        for r in rows:
            e=r.get('effect',{});writer.writerow([r['x'],r['z'],r.get('score',''),r['status'],e.get('targetPipeToleranceDegrees',''),e.get('comfort',''),*r['bounds']])
    summaries.append(summary);return rows,summary

loaded=[load(i) for i in g.items]

def draw(ax,item,data):
    rows,stats=data;g.table(ax)
    verts=[];colors=[]
    for r in rows:
        x0,z0,x1,z1=r['bounds'];verts.append([(x0,z0),(x1,z0),(x1,z1),(x0,z1)])
        colors.append(cmap(norm(r['score'])) if 'score' in r else '#bbc2c5')
    cells=PolyCollection(verts,facecolors=colors,edgecolors='none',zorder=2.5,rasterized=True);ax.add_collection(cells)
    cells.set_clip_path(g.Polygon(g.outline,closed=True,transform=ax.transData))
    # Initial 8/cue positions are deliberately omitted: this is a terminal cue-position field.
    target=stats['target'];g.ball(ax,target,9)
    ax.add_patch(Circle(target,g.R*1.5,fill=False,edgecolor='white',linewidth=1.5,zorder=12))
    zero=[r for r in rows if r['status']=='zero-width']
    if zero:ax.scatter([r['x'] for r in zero],[r['z'] for r in zero],s=.75,c='white',alpha=.35,zorder=3)
    estimates=[r for r in rows if 'estimate' in r['status']]
    if estimates:ax.scatter([r['x'] for r in estimates],[r['z'] for r in estimates],s=1.3,c='#202e38',alpha=.6,zorder=3)
    for a in stats['annotations']:
        ax.plot(a['x'],a['z'],'o',ms=2,color='white',zorder=12)
        ax.annotate(score_label(a['score'])+('*' if 'estimate' in a['status'] else '†' if a['status']=='zero-width' else ''),(a['x'],a['z']),xytext=(0,8),textcoords='offset points',ha='center',va='bottom',fontsize=9,color='white',bbox=dict(boxstyle='round,pad=.17',fc='#172b35',ec='none',alpha=.82),zorder=13)
    ax.set_title(item['label']+'  '+(item['title'] if item['label']!='D' else '对方9号在右半台（原图D）'),loc='left',fontsize=16,color='#193a35',pad=8)
    ax.text(0,-.035,f"采样分数 {stats['sampleMin']:.1f}–{stats['sampleMax']:.1f}  ·  ≥80分约占 {stats['scoreBandAreaPercent']['80-100']:.1f}%",transform=ax.transAxes,fontsize=10,color='#526660')

fig,axes=plt.subplots(2,2,figsize=(16,11));fig.patch.set_facecolor('#f4f5f0')
fig.subplots_adjust(left=.035,right=.965,bottom=.21,top=.86,wspace=.07,hspace=.21)
for ax,item,data in zip(axes.flat,g.items,loaded):draw(ax,item,data)
fig.text(.035,.955,'固定对方9号：母球落在不同位置的防守分',fontsize=24,color='#173b32')
fig.text(.035,.911,'分数越高，对方越难直接进攻  ·  四图统一0–100分色标  ·  数字为标记点的实算分',fontsize=13,color='#52665b')
cax=fig.add_axes([.23,.146,.54,.018]);bar=fig.colorbar(ScalarMappable(norm=norm,cmap=cmap),cax=cax,orientation='horizontal',ticks=[0,20,40,60,80,100]);bar.ax.tick_params(labelsize=10)
fig.text(.035,.083,'固定9号原坐标；本图不计8号遮挡。5厘米粗扫＋边界局部细化，未扰动目标球位置。',fontsize=11,color='#52665b')
fig.text(.035,.047,'灰色＝无效摆放区；白点／†＝按0°管道计分，黑点／*＝估算。色块为采样展示，尚未判断一杆能否走到。',fontsize=10.5,color='#52665b')
fig.savefig(OUT/'regions-overview.png',dpi=180,facecolor=fig.get_facecolor());fig.savefig(OUT/'regions-overview.pdf',facecolor=fig.get_facecolor());plt.close(fig)
for item,data in zip(g.items,loaded):
    fig,ax=plt.subplots(figsize=(12,8));fig.patch.set_facecolor('#f4f5f0');fig.subplots_adjust(left=.04,right=.96,bottom=.24,top=.88)
    draw(ax,item,data)
    cax=fig.add_axes([.23,.15,.54,.022]);fig.colorbar(ScalarMappable(norm=norm,cmap=cmap),cax=cax,orientation='horizontal',ticks=[0,20,40,60,80,100])
    fig.text(.04,.06,'固定9号；不计8号遮挡。分数越高越有利于防守。数字为标记点实算分。\n灰色＝无效摆放区；白点／†＝按0°管道计分，黑点／*＝估算；未验证一杆可达。',fontsize=11,color='#52665b')
    fig.savefig(OUT/(item['label']+'-region.png'),dpi=180,facecolor=fig.get_facecolor());plt.close(fig)
(OUT/'summary.json').write_text(json.dumps({'scope':'Fixed exact target 9, no blockers or shot solving; area shares are centre-sampled estimates, not certified continuous areas.','cases':summaries},ensure_ascii=False,indent=2))
(OUT/'validation.json').write_text(json.dumps({'passed':True,'checks':['four targets match bank coordinates within Float representation','all valid samples have finite scores in 0..100 and target number 9','formula values independently recomputed','adaptive leaves cover each coarse cell without duplicate rectangles','sample cue and target do not overlap','no target perturbation or cache-parity run'], 'productionGeometryHashesMatch':g.checked,'maxContourJoinGapMeters':max(g.joins),'maxArcToJawGapMeters':g.max_arc_join},indent=2))
print(json.dumps([{k:v for k,v in s.items() if k not in ['annotations','native']} for s in summaries],ensure_ascii=False,indent=2))
