"""Plot native static-state scores, preserving sampled/invalid/estimated distinctions."""
from pathlib import Path
import collections, json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
from matplotlib.patches import Circle, Rectangle
from matplotlib.collections import PolyCollection

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'output/defense-region-adaptive-20261105'
font = FontProperties(fname='/System/Library/Fonts/Supplemental/Arial Unicode.ttf')
plt.rcParams.update({'font.family':font.get_name(),'axes.unicode_minus':False,'font.size':12})
s=json.loads((OUT/'scan-adaptive.json').read_text());geom=json.loads((OUT/'geometry.json').read_text())
metrics=json.loads((OUT/'native-results.json').read_text())
rows=s['rows'];valid=[r for r in rows if 'score' in r]
polygons=[];values=[]
for r in rows:
    x0,z0,x1,z1=r['bounds'];polygons.append([(x0,z0),(x1,z0),(x1,z1),(x0,z1)])
    values.append(r.get('score',float('nan')))
target=np.array(s['target']);hx,hz=geom['halfX'],geom['halfZ']
fig,ax=plt.subplots(figsize=(15,9.3))
fig.subplots_adjust(left=.075,right=.92,bottom=.20,top=.85)
fig.patch.set_facecolor('#f5f5f2');ax.set_facecolor('#d7d9d8')
cmap=plt.get_cmap('turbo').copy();cmap.set_bad('#d7d9d8')
m=PolyCollection(polygons,array=np.ma.masked_invalid(values),cmap=cmap,edgecolors=(0,0,0,.12),linewidths=.15,rasterized=True)
m.set_clim(0,100);ax.add_collection(m)
ax.add_patch(Rectangle((-hx,-hz),2*hx,2*hz,fill=False,linewidth=5,edgecolor='#4b5c53',zorder=5))
for p in geom['pockets']:
    c=np.array(p['center']);c=np.clip(c,[-hx,-hz],[hx,hz]);ax.add_patch(Circle(c,.031,color='#2e3433',zorder=6))
ax.add_patch(Circle(target,geom['radius'],facecolor='#14181c',edgecolor='white',linewidth=1.3,zorder=8))
ax.text(*target,'8',color='white',ha='center',va='center',fontsize=11,zorder=9)
blocked=[r for r in valid if r['status']=='pot-block']
ax.scatter([r['x'] for r in blocked],[r['z'] for r in blocked],s=13,marker='x',color='white',linewidths=.8,zorder=7,
           label='白叉：采样点直接进球路线受阻（100分）')
samples=[]
for label,(px,pz),offset in [('A',(-1,.34),(26,9)),('B',(-.9,0),(35,-34)),('C',(1,0),(-120,-30))]:
    r=min(valid,key=lambda r:(r['x']-px)**2+(r['z']-pz)**2);samples.append({'label':label,**r})
    ax.plot(r['x'],r['z'],'o',color='white',markeredgecolor='#18252e',markersize=7,zorder=10)
    ax.annotate(f"{label}  {r['score']:.1f}分",(r['x'],r['z']),xytext=offset,textcoords='offset points',
                fontsize=12,bbox=dict(boxstyle='round,pad=.35',fc='white',ec='#74828c',alpha=.96),
                arrowprops=dict(arrowstyle='-',color='#273641'),zorder=11)
ax.set(xlim=(-hx-.025,hx+.025),ylim=(hz+.03,-hz-.03),aspect='equal',xlabel='X / 米（向右为正）',ylabel='Z / 米（向下为正）')
ax.set_title('5厘米粗扫＋局部细化：母球位置评分场\n固定8号≈(-1.142, -0.010)米 · 无其他球 · 当前v8直接进攻模型',loc='left',fontsize=19,pad=20)
cb=fig.colorbar(m,ax=ax,shrink=.82,pad=.025);cb.set_label('防守效果分（高分表示模型内更难直接进球）')
ax.legend(loc='upper right',frameon=True,facecolor='#55616b',labelcolor='white',framealpha=.94,fontsize=10).set_zorder(20)
fig.text(.075,.05,f"全桌{metrics['coarseCount']}个粗格；{metrics['refinedRootCount']}格细化，新增{metrics['additionalFineCount']}个采样点。无8号扰动、无67点复核。\n格内颜色代表中心采样值，不代表整格有相同分数；灰色采样点无效。当前图不证明击球可达或连续安全区。",fontsize=11,color='#33414b')
fig.savefig(OUT/'region-map.png',dpi=160,bbox_inches='tight');fig.savefig(OUT/'region-map.pdf',bbox_inches='tight');plt.close(fig)

scores=np.array([r['score'] for r in valid])
summary={'validCells':len(valid),'maskedCells':len(rows)-len(valid),'statusCounts':dict(collections.Counter(r['status'] for r in rows)),
         'scoreMin':float(scores.min()),'leafScoreMedianNotAreaWeighted':float(np.median(scores)),'scoreMax':float(scores.max()),
         'thresholdLeafCounts':{str(n):int((scores>=n).sum()) for n in [60,80,90,95,100]},
         'selectedSamples':samples,
         'scope':'Existing v8 static direct-attack model; sampled cells, not certified continuous regions or reachable shots.'}
(OUT/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
print(json.dumps({k:v for k,v in summary.items() if k != 'selectedSamples'},ensure_ascii=False,indent=2))
