import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle,Rectangle
from matplotlib.font_manager import fontManager,FontProperties
import pipeline as P
fontManager.addfont('/Library/Fonts/Arial Unicode.ttf');plt.rcParams['font.family']=FontProperties(fname='/Library/Fonts/Arial Unicode.ttf').get_name();plt.rcParams['axes.unicode_minus']=False
out=P.B/'pilot-direct';fig,axes=plt.subplots(3,2,figsize=(14,12))
for n in range(3):
 f=P.read(out/f'result-{n}.json');t=P.read(out/f'proof-{n}.json');c=next(c for c in f['candidates'] if c['top5']);q=c['top5'][0];routes={r['comboIndex']:r for r in f['routes']};roots={r['comboIndex']:r for r in t['roots']};parent=roots[q['rootComboIndices'][0]];new=routes[q['comboIndex']]
 assert P.seq(parent)==P.seq(new)
 for col,r in enumerate([parent,new]):
  ax=axes[n,col];L=P.C.G.length;W=P.C.G.width;R=P.C.G.radius;ax.add_patch(Rectangle((-L/2,-W/2),L,W,fc='#d7e6d4',ec='#355c4e',lw=9))
  for i,(x,z) in enumerate(P.C.G.anchors()):ax.add_patch(Circle((x,z),R*1.3,fc='#24483c'))
  cue=f['board']['cue'];obj=f['board']['object'];aim=f['board']['aim'];path=r['trajectory2mm']['points'];ax.plot([cue[0],path[0][1]],[cue[1],path[0][2]],color='#66808a',ls=':');ax.plot([p[1] for p in path],[p[2] for p in path],color='#1979b8' if col else '#8b6b91',lw=1.7)
  ax.plot([obj[0],aim[0]],[obj[1],aim[1]],ls='--',color='#bd832b')
  for pos,color,label in [(cue,'white','C'),(obj,'#efbb44','A'),(c['position'],'#e17e5d','B')]:ax.add_patch(Circle(pos,R,fc=color,ec='#405a52'));ax.text(*pos,label,ha='center',va='center',fontsize=8)
  ax.plot(*r['cueStop'],marker='o',mfc='white',mec='#1979b8',ms=6)
  name='原推荐中心' if col==0 else f"网格最优代表 · 第二杆{q['angle']:.2f}°"
  ax.set_title(f"例{n+1} B{c['cellID']} · {name}\n速度{r['velocity']:.3f} · 打点({r['spinX']:.3f},{r['spinY']:.3f}) · 库序{list(P.seq(r))}",fontsize=10)
  ax.set_aspect('equal');ax.set_xlim(-L/2-.08,L/2+.08);ax.set_ylim(W/2+.08,-W/2-.08);ax.axis('off')
fig.suptitle('同一路线中心与网格优化后对照（世界XZ米制；保留实际库序）',fontsize=17);fig.tight_layout();fig.savefig(out/'geometry-review.png',dpi=150)
