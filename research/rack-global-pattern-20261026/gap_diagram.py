import json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import TwoSlopeNorm
from matplotlib.patches import Circle
from analyze import OUT,NOM,R,EDGES
from diagram import FONT,BALLS
V=json.loads((OUT/'validation/summary.json').read_text());p=json.loads((OUT/'validation/protocol.json').read_text());selected=p['variants'][2:]
base=np.array(V['variants']['baseline']['edgeGapMM']);deltas=[(np.array(V['variants'][v]['edgeGapMM'])-base)*1000 for v in selected]
maxv=max(abs(d).max() for d in deltas);norm=TwoSlopeNorm(vmin=-maxv,vcenter=0,vmax=maxv);cmap=plt.get_cmap('coolwarm_r')
fig,axs=plt.subplots(1,2,figsize=(12,5));records=[]
for ax,v,ds,title in zip(axs,selected,deltas,['方案 A','方案 B']):
 for (a,b),d in zip(EDGES,ds):
  ax.plot(NOM[[a,b],0],NOM[[a,b],1],color=cmap(norm(d)),lw=5,zorder=1)
  records.append(dict(variant=v,a=BALLS[a],b=BALLS[b],deltaMicrometers=float(d)))
 for i in range(15):
  ax.add_patch(Circle(NOM[i],.010,facecolor='#f4f5f5',edgecolor='#6b7881',zorder=2));ax.text(*NOM[i],BALLS[i],ha='center',va='center',fontsize=9,zorder=3)
 ax.set_xlim(-.86,-.60);ax.set_ylim(-.14,.14);ax.set_aspect('equal');ax.axis('off');ax.set_title(title+'：30 条邻接边',fontproperties=FONT)
sm=plt.cm.ScalarMappable(norm=norm,cmap=cmap);cb=fig.colorbar(sm,ax=axs,shrink=.8,pad=.03);cb.set_label('平均表面间隙变化 / 微米（负值变近）',fontproperties=FONT)
fig.suptitle('相对生产摆法的初始间隙变化；线段颜色是实测几何差',fontproperties=FONT,fontsize=13)
fig.savefig(OUT/'gap-changes.png',dpi=180,bbox_inches='tight');plt.close(fig)
(OUT/'gap-changes.json').write_text(json.dumps(records,ensure_ascii=False,indent=2));print('Gap diagram generated')
