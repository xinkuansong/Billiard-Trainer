from pathlib import Path
import json,sys
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
from matplotlib.patches import Circle,Patch
from analyze import NOM,R,GROUPS,OUT,expected
FONT=FontProperties(fname='/System/Library/Fonts/Hiragino Sans GB.ttc',weight=300)
plt.rcParams['axes.unicode_minus']=False
COLORS=['#ee9345','#d04b58','#388fa6','#7169ba','#4d9b6b']
LABELS=['前端三球','内部三球','两侧四球','后排中间三球','后排两角球']
BALLS=[f'{chr(65+r)}{c+1}' for r in range(5) for c in range(r+1)]
def axes_rack(ax,title):
 for g,slots in enumerate(GROUPS):
  for i in slots:
   ax.add_patch(Circle(NOM[i],R,facecolor=COLORS[g],edgecolor='white',lw=1.5,alpha=.9));ax.text(*NOM[i],BALLS[i],ha='center',va='center',fontsize=9,color='white')
 ax.set_aspect('equal');ax.set_xlim(-.89,-.56);ax.set_ylim(-.16,.16);ax.set_xlabel('世界 X / 米（向右为来球侧）',fontproperties=FONT);ax.set_ylabel('世界 Z / 米',fontproperties=FONT);ax.set_title(title,fontproperties=FONT);ax.grid(alpha=.15)
def main():
 pilot=json.loads((OUT/'discovery/preflight/pilot.json').read_text()); bases={r['input']['rackID']:r for r in pilot if r['input']['variant']=='baseline'}
 err=0;minimum=1;radius=0
 for row in pilot:
  bp=np.array([[b['x'],b['z']] for b in bases[row['input']['rackID']]['rack']]);p=np.array([[b['x'],b['z']] for b in row['rack']]);err=max(err,float(np.max(np.abs(p-expected(bp,row['input']['variant'])))))
  d=np.linalg.norm(p[:,None]-p[None,:],axis=2);np.fill_diagonal(d,np.inf);minimum=min(minimum,float(d.min()-2*R));radius=max(radius,float(np.linalg.norm(p-NOM,axis=1).max()))
 assert len(pilot)==68 and err<1e-7 and minimum>0 and radius<.0000901
 (OUT/'pilot-geometry.json').write_text(json.dumps(dict(count=len(pilot),maximumTransformErrorM=err,minimumGapMM=minimum*1000,maxOffsetMM=radius*1000),indent=2))
 fig,ax=plt.subplots(figsize=(8,6));axes_rack(ax,'全部 15 球：五区域方向组合（箭头仅示方向）')
 for g,slots in enumerate(GROUPS):
  for i in slots:
   delta=np.array([.019,0]) if g not in (2,4) else np.array([0,.019*np.sign(NOM[i,1])])
   ax.annotate('',xy=NOM[i]+delta,xytext=NOM[i],arrowprops=dict(arrowstyle='->',lw=1.8,color='#182c3b'))
 ax.legend(handles=[Patch(color=c,label=l) for c,l in zip(COLORS,LABELS)],prop=FONT,loc='upper left',bbox_to_anchor=(1.02,1))
 fig.text(.12,.015,'每组均比较正、反两个方向，共 32 种；随机偏移半径仍为 0.09 毫米。',fontproperties=FONT,fontsize=10)
 fig.savefig(OUT/'regions.png',dpi=180,bbox_inches='tight');plt.close(fig)
 print('pilot geometry passed',err,minimum,radius)
if __name__=='__main__':main()
