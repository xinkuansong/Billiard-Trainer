from pathlib import Path
import json
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
O=Path('output/rack-spin-experiments-20261026');s=json.loads((O/'combined-summary.json').read_text())
font=FontProperties(fname='/System/Library/Fonts/STHeiti Medium.ttc')
keys=['production','repair','han14','spin16','spin22','han14_spin22','mathavan','mathavan14','mathavan14_spin22']
names=['生产基线','碰撞求解修复底座','Han 摩擦 0.14','自旋减速度 16','自旋减速度 22','Han 0.14 + 减速度 22','Mathavan 摩擦 0.20','Mathavan 摩擦 0.14','Mathavan 0.14 + 减速度 22']
fig,axs=plt.subplots(1,3,figsize=(14,6.7),sharey=True,gridspec_kw={'width_ratios':[1.2,1,1]});fig.patch.set_facecolor('#fafaf8')
colors=['#70777e','#bb6b3a','#0d8a80','#8ab4ba','#8ab4ba','#0d8a80','#6e81a5','#6e81a5','#6e81a5']
for ax,key,title,lim in zip(axs,['meanTail','meanScore','scratch'],['平均原地自转尾段（秒）','平均开散分（原公式）','母球落袋率（%）'],[6,1.35,30]):
 vals=[s[k][key] if key!='scratch' else s[k][key]/2 for k in keys]
 ax.barh(range(9),vals,color=colors,height=.62);ax.set_xlim(0,lim);ax.set_facecolor('#fafaf8');ax.set_title(title,fontproperties=font,fontsize=12,pad=18)
 for i,v in enumerate(vals):ax.text(v+lim*.025,i,f'{v:.2f}' if key!='scratch' else f'{v:.1f}%',va='center',fontsize=10)
 ax.grid(axis='x',alpha=.14);ax.set_axisbelow(True)
 for side in ['top','right','left']:ax.spines[side].set_visible(False)
 ax.tick_params(axis='y',length=0)
axs[0].set_yticks(range(9),names,fontproperties=font,fontsize=11);axs[0].invert_yaxis();axs[1].axvline(1.2,color='#888',ls='--',lw=1)
fig.suptitle('长自转研究：同 200 副球形，9 组配对比较',fontproperties=font,fontsize=19,x=.05,ha='left')
fig.text(.05,.035,'正中开球 · 杆速 10 m/s · 摆球不变 · 除生产外均基于修复副本\n候选参数尚未经当前球台实测标定；此图不代表生产已修改。',fontproperties=font,fontsize=11,color='#555')
plt.subplots_adjust(left=.235,right=.96,top=.86,bottom=.16,wspace=.28)
fig.savefig(O/'comparison.png',dpi=180);fig.savefig(O/'comparison.svg')
