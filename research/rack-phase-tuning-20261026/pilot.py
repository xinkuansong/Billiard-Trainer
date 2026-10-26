from analyze import *
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
FONT=FontProperties(fname='/System/Library/Fonts/Hiragino Sans GB.ttc')
plt.rcParams['axes.unicode_minus']=False
raw=json.loads((OUT/'discovery/preflight/pilot.json').read_text());bases={r['input']['rackID']:r for r in raw if r['input']['variant']=='baseline'}
audits=[geometry(r,bases[r['input']['rackID']])[0] for r in raw]
write(OUT/'pilot-audit.json',dict(count=len(raw),maxErrorM=max(a['errorM'] for a in audits),minGapMM=min(a['minGapMM'] for a in audits)))
names=['生产随机','原共同向内','纯向内','偏离向内 0–15°','偏离向内 15–30°','偏离向内 30–45°','偏离向内 45–60°','偏离向内 60–75°','偏离向内 75–90°']
fig,axs=plt.subplots(3,3,figsize=(12,10))
for ax,r,name in zip(axs.flat,raw[:9],names):
 p=np.array([[b['x'],b['z']] for b in r['rack']]);d=p-NOM;u=d/np.linalg.norm(d,axis=1)[:,None]
 ax.scatter(NOM[:,0]*1000,NOM[:,1]*1000,s=85,c='#b7c5d5');ax.quiver(NOM[:,0]*1000,NOM[:,1]*1000,u[:,0]*15,u[:,1]*15,angles='xy',scale_units='xy',scale=1,color='#d36b3c',width=.007)
 ax.set_title(name,fontproperties=FONT);ax.set_aspect('equal');ax.set_xlim(-880,-600);ax.set_ylim(-140,140);ax.set_xticks([]);ax.set_yticks([])
fig.suptitle('同一副球形的偏移方向（箭头放大且等长；实际各球长度不变）',fontproperties=FONT,fontsize=16)
fig.tight_layout(rect=(0,0,1,.96));fig.savefig(OUT/'phase-directions.png',dpi=150);plt.close(fig)
print('18 pilot transforms audited; direction atlas saved.')
