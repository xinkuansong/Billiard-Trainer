from analyze import *
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
FONT=FontProperties(fname='/System/Library/Fonts/Hiragino Sans GB.ttc');plt.rcParams['axes.unicode_minus']=False
raw=json.loads((OUT/'discovery/preflight/pilot.json').read_text());bases={r['input']['rackID']:r for r in raw if r['input']['variant']=='baseline'};audits=[geometry(r,bases[r['input']['rackID']])[0] for r in raw]
write(OUT/'pilot-audit.json',dict(count=len(raw),maxErrorM=max(a['errorM'] for a in audits),minGapMM=min(a['minGapMM'] for a in audits),maxRadiusChangeMM=max(a['maxRadiusChangeMM'] for a in audits)))
first=min(bases);by={r['input']['variant']:r for r in raw if r['input']['rackID']==first}
fig,axs=plt.subplots(3,6,figsize=(18,9))
for row,(region,title) in enumerate([('core','内部对外围'),('side','两侧'),('front','前排对后排')]):
 for col,mode in enumerate(['ref','M60','M30','P30','P60','Flip']):
  v='radial_contract' if mode=='ref' else 'radial_'+region+mode;r=by[v];p=np.array([[b['x'],b['z']] for b in r['rack']]);d=p-NOM;u=d/np.linalg.norm(d,axis=1)[:,None];ax=axs[row,col]
  mask=CORE if region=='core' else ROW<=2 if region=='front' else NOM[:,1]<0
  colors=['#d87944' if x else '#388d88' for x in mask]
  ax.scatter(NOM[:,0]*1000,NOM[:,1]*1000,s=60,c='#d7dce2');ax.quiver(NOM[:,0]*1000,NOM[:,1]*1000,u[:,0]*18,u[:,1]*18,angles='xy',scale_units='xy',scale=1,color=colors,width=.009)
  name='原共同向内' if mode=='ref' else '切向反转' if mode=='Flip' else ('-' if mode[0]=='M' else '+')+mode[1:]+'°相位'
  ax.set_title(name,fontproperties=FONT,fontsize=11);ax.set_aspect('equal');ax.set_xlim(-875,-605);ax.set_ylim(-142,142);ax.set_xticks([]);ax.set_yticks([])
  if col==0:ax.set_ylabel(title,fontproperties=FONT,fontsize=12)
fig.suptitle('同一副球形：区域间方向配合（箭头放大且等长，实际保留各球偏移长度）',fontproperties=FONT,fontsize=17)
fig.tight_layout(rect=(0,0,1,.96));fig.savefig(OUT/'regional-directions.png',dpi=150);plt.close(fig)
print('34 pilot rows independently audited, region diagram saved.')
