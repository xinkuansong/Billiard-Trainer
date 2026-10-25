from pathlib import Path
import json,math,hashlib,random,gzip,shutil
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle,Rectangle,Polygon
from matplotlib.font_manager import fontManager
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name
d=json.loads((OUT/'data.json').read_text());g=d['geometry'];r=g['radius'];hx=g['length']/2;hz=g['width']/2
source=ROOT/'output/two-ball-p2-60-top5-full-20261025'
index=json.loads((ROOT/'output/two-ball-block-sampled-13570-20261025/simulation-index.json').read_text());rng=random.Random(d['seed']);chosen=rng.sample(index,5)
assert [v['id'] for v in chosen]==[v['id'] for v in d['boards']]
receipts={Path(v['part']).name:v for v in json.loads((source/'parts-index.json').read_text())};sources={}
for board,idx in zip(d['boards'],chosen):
 p=source/'parts'/Path(idx['part']).name;raw=p.read_bytes();assert hashlib.sha256(raw).hexdigest()==receipts[p.name]['sha256'];sources[str(p.relative_to(ROOT))]=receipts[p.name]['sha256']
 original=next(v for v in map(json.loads,gzip.decompress(raw).splitlines()) if v['id']==board['id'])
 assert original=={k:v for k,v in board.items() if k!='defaultCellID'}
 assert rng.choice([c for c in board['candidates'] if c['top5']])['cellID']==board['defaultCellID']
fontManager.addfont('/Library/Fonts/Arial Unicode.ttf');plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
colors=['#147cbd','#d87824','#268651','#965ac1','#c04572'];names=['左上角袋','右上角袋','左下角袋','右下角袋','上中袋','下中袋'];cats={'center':'中杆','vertical':'纯高低','horizontal':'纯左右','mixed':'混合'}
anchors=[[-hx+r,-hz+r],[hx-r,-hz+r],[-hx+r,hz-r],[hx-r,hz-r],[0,-hz],[0,hz]]
def table(ax,b):
 ax.set_aspect('equal');ax.axis('off');ax.add_patch(Rectangle((-hx-.055,-hz-.055),2*hx+.11,2*hz+.11,color='#345d50'));ax.add_patch(Rectangle((-hx,-hz),2*hx,2*hz,color='#dbe9d9'))
 for p in g['pockets']:
  ax.add_patch(Polygon([(v['x'],v['z']) for v in p['lip']],color='#193c33'));ax.add_patch(Circle((p['center']['x'],p['center']['z']),p['radius'],color='#193c33'))
 p=g['pockets'][b['pocket']]['center'];ax.add_patch(Circle((p['x'],p['z']),.068,fill=False,ec='#bd8719',lw=2))
 ax.plot([b['object'][0],b['aim'][0]],[b['object'][1],b['aim'][1]],'--',color='#bd8719',lw=1.4);ax.set_xlim(-hx-.14,hx+.14);ax.set_ylim(hz+.14,-hz-.13)
def balls(ax,b,c):
 for p,fc,ec,label in [(b['cue'],'white','#284438','C'),(b['object'],'#efbd49','#8a6222','A'),(c['position'],'#208eb7','#0a6286','B')]:
  ax.add_patch(Circle(p,r,fc=fc,ec=ec,lw=1.3,zorder=10));ax.text(*p,label,ha='center',va='center',fontsize=8,color='white' if label=='B' else ec,zorder=11)
for no,rec in enumerate(d['boards'],1):
 b=rec['board'];c=next(c for c in rec['candidates'] if c['cellID']==rec['defaultCellID']);routes={t['comboIndex']:t for t in rec['routes']}
 fig,axs=plt.subplots(3,2,figsize=(16,13),facecolor='#f8faf6');ax=axs.flat[0];table(ax,b)
 for cand in rec['candidates']:
  p=cand['position'];ax.add_patch(Circle(p,r,fc='#edf4e9',ec='#829b8a',lw=1));ax.annotate(f'B{cand["cellID"]}',p,xytext=(0,12),textcoords='offset points',ha='center',fontsize=9,color='#527061')
 balls(ax,b,c);ax.set_title(f'第二球位置分布 · 当前B{c["cellID"]}',loc='left',fontsize=14)
 for i,q in enumerate(c['top5']):
  ax=axs.flat[i+1];color=colors[i];t=routes[q['comboIndex']];xy=[p[1:] for p in t['trajectory2mm']['points']];table(ax,b)
  ax.plot([b['cue'][0],xy[0][0]],[b['cue'][1],xy[0][1]],':',color='#8b9b91',lw=1.3)
  ax.plot([p[0] for p in xy],[p[1] for p in xy],color=color,lw=1.8)
  for a,v in zip(xy,xy[1:]):
   if math.dist(a,v)>.17:ax.annotate('',xy=[a[j]+.62*(v[j]-a[j]) for j in range(2)],xytext=[a[j]+.50*(v[j]-a[j]) for j in range(2)],arrowprops=dict(arrowstyle='->',color=color,lw=1))
  a=anchors[q['pocket']];ax.plot([c['position'][0],a[0]],[c['position'][1],a[1]],'--',color='#648966',lw=1)
  ax.add_patch(Circle(t['cueStop'],r,fc='white',ec=color,lw=1.6,zorder=8));ax.annotate(f'停{i+1}',t['cueStop'],xytext=(10,10),textcoords='offset points',color=color,fontsize=10,bbox=dict(fc='white',ec=color,boxstyle='round,pad=.1'))
  balls(ax,b,c);ax.set_title(f'第{i+1}名 · 组合{q["comboIndex"]} · S={q["score"]:.4f} · {names[q["pocket"]]}',loc='left',fontsize=13,color=color)
  ax.text(-hx,hz+.125,f'{cats[t["strokeCategory"]]} · {t["velocity"]:.3f} m/s · 打点({t["spinX"]:+.3f}, {t["spinY"]:+.3f}) · {t["cueMainRailsAfterContact"]}库',fontsize=10,color='#51685d')
 for ax in list(axs.flat)[len(c['top5'])+1:]:ax.axis('off')
 fig.suptitle(f'随机球形 {no}/5 · B{c["cellID"]} · P2 60分去重后前五',fontsize=22,y=.985)
 fig.text(.04,.953,f'{rec["id"]} · C初始母球 / A第一球 / B第二球；彩线为2mm关键点，灰点线为首碰前连线，虚线为进袋方向',fontsize=11,color='#51685d')
 fig.subplots_adjust(left=.025,right=.98,top=.925,bottom=.025,hspace=.15,wspace=.06);fig.savefig(OUT/f'sample-{no}-B{c["cellID"]}.png',dpi=145);plt.close(fig)
page=(HERE/'index.template.html').read_text().replace('__DATA__',json.dumps(d,ensure_ascii=False,separators=(',',':')).replace('</','<\\/'));(OUT/'index.html').write_text(page)
served=ROOT/'output/two-ball-multi-position-top10-20261024/top5-random-five';served.mkdir(exist_ok=True)
for p in OUT.glob('*'):
 if p.is_file():shutil.copy2(p,served/p.name)
manifest={'seed':d['seed'],'selectedIDs':[b['id'] for b in d['boards']],'defaultBs':[b['defaultCellID'] for b in d['boards']],
 'candidateCount':sum(len(b['candidates']) for b in d['boards']),'sourceSHA256':sources,'verified':{'uniformInitialSampleReplayed':True,'defaultBSampleReplayed':True,'allFiveRecordsExactlyMatchFinalResults':True,'noRecomputeOrResimulation':True}}
(OUT/'verification.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2));print(json.dumps(manifest,ensure_ascii=False))
