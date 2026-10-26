from common import *
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle
from matplotlib.font_manager import FontProperties
FONT=FontProperties(fname='/System/Library/Fonts/Hiragino Sans GB.ttc',weight=300);plt.rcParams['axes.unicode_minus']=False
raw=json.loads((OUT/'discovery/preflight/pilot.json').read_text());bases={r['input']['rackID']:r for r in raw if r['input']['variant']=='baseline'}
audits=[]
for r in raw:
 a,*_=audit_geometry(r,bases[r['input']['rackID']]);audits.append(a);sequence(r)
assert len(raw)==36
write(OUT/'pilot-audit.json',dict(count=len(raw),maxTransformErrorM=max(a['transformErrorM'] for a in audits),maxRadiusChangeMM=max(a['maxRadiusChangeMM'] for a in audits),minGapMM=min(a['minGapMM'] for a in audits)))
seed=min(bases);variants=['baseline']+[f+'_full' for f in FAMILY_NAMES]
fig,axs=plt.subplots(3,3,figsize=(13,12))
for ax,v in zip(axs.flat,variants):
 r=next(r for r in raw if r['input']['rackID']==seed and r['input']['variant']==v);p=np.array([[b['x'],b['z']] for b in r['rack']]);d=p-NOM
 for i in range(15):
  ax.add_patch(Circle(NOM[i],R,facecolor='#edf3f6',edgecolor='#afc2cc',lw=.8));ax.annotate('',xy=NOM[i]+d[i]*300,xytext=NOM[i],arrowprops=dict(arrowstyle='->',lw=1.2,color='#327e9b'));ax.text(NOM[i,0],NOM[i,1]+R*.6,NAMES[i],ha='center',va='center',fontsize=6,color='#4a5155')
 ax.set_xlim(-.88,-.58);ax.set_ylim(-.15,.15);ax.set_aspect('equal');ax.axis('off');ax.set_title(label(v),fontproperties=FONT,fontsize=11)
fig.suptitle('同一副球阵：偏移方向之间的关联（箭头放大 300 倍）',fontproperties=FONT,fontsize=16)
fig.tight_layout();fig.savefig(OUT/'correlation-patterns.png',dpi=170,bbox_inches='tight');plt.close(fig)
print('36 pilot geometries and trace orders audited')
