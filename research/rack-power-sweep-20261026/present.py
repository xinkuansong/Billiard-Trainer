from pathlib import Path
import json
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output/rack-power-sweep-20261026'
s=json.loads((OUT/'summary.json').read_text());a=json.loads((OUT/'atlas.json').read_text());p=a['powers'];r=[s['powers'][str(x)] for x in p]
f=FontProperties(fname='/System/Library/Fonts/Hiragino Sans GB.ttc');plt.rcParams['axes.unicode_minus']=False
fig,axs=plt.subplots(2,2,figsize=(12,8),layout='constrained');fig.suptitle('相同1000副球形 · 两侧差异化偏移 · 只改变杆速',fontproperties=f,fontsize=18)
for ax,values,title,ylabel in [(axs[0,0],[x['mean'] for x in r],'平均散开评分','评分'),(axs[0,1],[x['passRate']*100 for x in r],'达到1.20的比例','%'),(axs[1,0],[x['scratch']*100 for x in r],'母球落袋率','%'),(axs[1,1],[x['closeFraction']*100 for x in r],'停稳后仍靠近邻球的比例','%')]:
 ax.plot(p,values,'o-',color='#167c71',linewidth=2);ax.set_title(title,fontproperties=f);ax.set_xlabel('杆速 (m/s)',fontproperties=f);ax.set_ylabel(ylabel,fontproperties=f);ax.grid(alpha=.2);ax.set_xticks([9.75,11,12,13,14])
 for x,y in zip(p,values):ax.annotate(f'{y:.3f}' if title=='平均散开评分' else f'{y:.1f}',(x,y),xytext=(0,9),textcoords='offset points',ha='center',fontsize=9)
 ax.margins(y=.22)
fig.savefig(OUT/'power-comparison.png',dpi=160);plt.close(fig)
t=(HERE/'template.html').read_text();t=t.replace('__ATLAS__',json.dumps(a,ensure_ascii=False)).replace('__SUMMARY__',json.dumps(s,ensure_ascii=False));(OUT/'index.html').write_text(t)
