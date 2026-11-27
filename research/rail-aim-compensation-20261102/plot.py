from pathlib import Path
import json,math
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.patches import Circle
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rail-aim-compensation-20261102'
font_manager.fontManager.addfont('/System/Library/Fonts/STHeiti Medium.ttc')
plt.rcParams['font.family']=font_manager.FontProperties(fname='/System/Library/Fonts/STHeiti Medium.ttc').get_name()
plt.rcParams['axes.unicode_minus']=False
rows=[json.loads(l) for l in (OUT/'results.jsonl').read_text().splitlines()]
r=next(x for x in rows if x['index']==9 and x['speed']==3 and x['spinX']==0)
g=json.loads((ROOT/'QiuJi/Resources/training-grid-bank.json').read_text())['geometry']
fig,axes=plt.subplots(1,2,figsize=(11,5),layout='constrained')
for ax,name,color,p in [(axes[0],'当前补偿：撞袋角，未进','#d44949',r['baseline']),
                         (axes[1],'瞄准偏转 0.075°：直接入袋','#13836b',r['rescue']['prediction'])]:
    for l in g['lines']:
        ax.plot([l['start']['x']*100,l['end']['x']*100],[l['start']['z']*100,l['end']['z']*100],color='#656b73',lw=2)
    for a in g['arcs']:
        start,end=a['start'],a['end']
        if end<start:end+=2*math.pi
        ts=[start+(end-start)*i/100 for i in range(101)]
        ax.plot([(a['center']['x']+a['radius']*math.cos(t))*100 for t in ts],[(a['center']['z']+a['radius']*math.sin(t))*100 for t in ts],color='#656b73',lw=2)
    cap=next((e['t'] for e in p['events'] if e['kind'].startswith('pocket(ball: "object"')),999)
    jaw=next((e['t'] for e in p['events'] if e['kind']=='ballCushion(ball: "object")'),999)
    frames=[f for f in p['frames'] if f['t']<=min(cap,jaw+.08)]
    ax.plot([f['p'][0]*100 for f in frames],[f['p'][1]*100 for f in frames],color=color,lw=2.5,label='实测目标球球心轨迹')
    last=next((f for f in frames if f['t']==min(cap,jaw)),frames[-1])
    ax.add_patch(Circle((last['p'][0]*100,last['p'][1]*100),2.8575,color=color,alpha=.2))
    ax.scatter([last['p'][0]*100],[last['p'][1]*100],s=28,color=color,zorder=5)
    ax.set(xlim=(-12,12),ylim=(-72,-52),xlabel='World X (cm)',ylabel='World Z (cm)',title=name)
    ax.invert_yaxis();ax.set_aspect('equal');ax.grid(alpha=.15);ax.legend(loc='lower left',fontsize=8)
fig.suptitle('同一球形、杆速 3 m/s、中杆；仅改变瞄准方向，物理参数保持\n题库 ID：grid-v3:1997:93:1',fontsize=12)
fig.savefig(OUT/'same-input-comparison.png',dpi=180,bbox_inches='tight',pad_inches=.3)
