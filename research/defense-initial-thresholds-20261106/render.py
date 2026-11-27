from pathlib import Path
import sys,json
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'research/defense-threshold-comparison-20261105'))
import geometric_table as g
from matplotlib.collections import PolyCollection
SOURCE=ROOT/'output/defense-threshold-comparison-20261105';OUT=ROOT/'output/defense-initial-thresholds-20261106'
report=json.loads((OUT/'comparison.json').read_text());cases=json.loads((SOURCE/'scenario.json').read_text())['cases'];plt=g.plt
palette={'formula':'#f3ce65','estimate':'#db8b91','blocked':'#91d3e0'}
for page in range(3):
 fig,axes=plt.subplots(3,4,figsize=(20,10.5));fig.patch.set_facecolor('#f4f5f0');fig.subplots_adjust(left=.025,right=.985,top=.86,bottom=.11,wspace=.10,hspace=.37)
 for row,case in enumerate(cases[page*3:page*3+3]):
  item=report['cases'][page*3+row];scan=json.loads((SOURCE/case['label']/'scan-adaptive.json').read_text())
  for col,t in enumerate(report['thresholds']):
   ax=axes[row,col];g.table(ax);verts=[];colors=[]
   for r in scan['rows']:
    if r.get('score',-1)<t:continue
    x,z,x1,z1=r['bounds'];verts.append([(x,z),(x1,z),(x1,z1),(x,z1)])
    status=r['status'];kind='formula' if status=='formula' else ('blocked' if status in ['direct-block','pot-block'] else 'estimate');colors.append(palette[kind])
   coll=PolyCollection(verts,facecolors=colors,edgecolors='none',alpha=.65,zorder=2.5);ax.add_collection(coll);coll.set_clip_path(g.Polygon(g.outline,closed=True,transform=ax.transData))
   q=case['question'];g.ball(ax,q['cue'],0)
   for b in q['balls']:g.ball(ax,b['position'],b['number'])
   ax.set_title(f"{case['label']}  ≥{t}分",loc='left',fontsize=13,color='#173b32',pad=3)
   a=item['thresholds'][col];ax.text(.01,-.04,f"区域占比 {a['areaPercent']:.2f}%  ·  {a['areaSquareMeters']*10000:.0f}cm²",transform=ax.transAxes,fontsize=10,color='#355950',va='top')
 fig.text(.03,.96,f"初始球形基础防守区域  ·  F{page*3+1:02}—F{page*3+3:02}",fontsize=22,color='#173b32')
 fig.text(.03,.91,'固定9号，不加入移动8号的遮挡；同一行对比70／80／90／95，不先淘汰球形。',fontsize=12,color='#355950')
 for i,(label,key) in enumerate([('正常公式','formula'),('0°或其他估算','estimate'),('确认封锁','blocked')]):
  fig.text(.50+i*.16,.96,'■ '+label,color=palette[key],fontsize=12,bbox=dict(facecolor='#244b40',edgecolor='none',pad=3))
 fig.text(.03,.035,'原题三球仅作位置参照。面积按有效采样叶格估计，不是连续安全区，也不证明击球可达。\n当前九例均有100分局部点；峰值本身无法区分区域潜力。红色估算区域需要单独看待，绿色为未达门槛或无有效采样。',fontsize=11,color='#49645a')
 fig.savefig(OUT/f'regions-{page+1}.png',dpi=145,facecolor=fig.get_facecolor());plt.close(fig)
print('Rendered 36 panels on 3 geometric-table sheets')
