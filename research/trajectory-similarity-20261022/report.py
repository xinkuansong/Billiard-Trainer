from pathlib import Path
import json,math,csv,html
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
OUT=Path(__file__).resolve().parent
D=json.loads((OUT/'metrics.json').read_text());P=json.loads((OUT/'display-trajectories.json').read_text())
MET=['frechet','dtw','chamfer'];NAMES={'frechet':'Fréchet','dtw':'Mean DTW','chamfer':'Chamfer'}
ids=list(P);E={(r['a'],r['b'],r['budget']):r for r in D['engine']}
def get(a,b,n=512):
 if a==b:return {k:0 for k in MET}
 return E.get((a,b,n),E.get((b,a,n)))
def score(d,t=10):return 100*2**(-d/t)
def table(headers,rows):return '| '+' | '.join(headers)+' |\n|'+'|'.join(['---']*len(headers))+'|\n'+'\n'.join('| '+' | '.join(str(x) for x in row)+' |' for row in rows)+'\n'
summary={}
for n in [128,256,512,1024]:
 rows=[r for r in D['engine'] if r['budget']==n]
 summary[n]={k:{'max':max(abs(r[k]-get(r['a'],r['b'],2048)[k]) for r in rows),'median':float(np.median([abs(r[k]-get(r['a'],r['b'],2048)[k]) for r in rows]))} for k in MET}
 summary[n]['scoreMaxDelta']=max(abs(score(r['frechet'])-score(get(r['a'],r['b'],2048)['frechet'])) for r in rows)
 summary[n]['maxEdge']=max(r['maxEdge'] for r in D['sampling'] if r['budget']==n)
 summary[n]['maxReconstructionError']=max(r['reconstructionError'] for r in D['sampling'] if r['budget']==n)
(OUT/'convergence-summary.json').write_text(json.dumps(summary,indent=2))
for key in MET:
 with (OUT/f'matrix-{key}-cm.csv').open('w') as f:
  w=csv.writer(f);w.writerow(['id']+ids)
  for a in ids:w.writerow([a]+[get(a,b)[key] for b in ids])
 with (OUT/f'matrix-{key}-score-t10.csv').open('w') as f:
  w=csv.writer(f);w.writerow(['id']+ids)
  for a in ids:w.writerow([a]+[score(get(a,b)[key]) for b in ids])
plt.rcParams.update({'font.size':10,'axes.spines.top':False,'axes.spines.right':False})
selected=[('pot_center','pot_side_small'),('pot_center','pot_right'),('pot_center','pot_follow'),('pot_center','pot_draw'),('pot_center','pot_fast'),('pot_center','pot_multirail'),('pot_center','pot_left'),('pot_right','pot_multirail')]
fig,axs=plt.subplots(4,2,figsize=(13,14),layout='constrained')
for ax,(a,b) in zip(axs.flat,selected):
 for name,color in [(a,'#146c94'),(b,'#d37619')]:
  points=np.array(P[name]);ax.plot(*points.T,color=color,lw=1.7,label=name)
  ax.scatter(*points[0],c=color,marker='o',s=15);ax.scatter(*points[-1],c=color,marker='x',s=35)
  for e in D['metadata'][name]['events']:
   if e['kind']=='cushion':ax.scatter(*(np.array(e['position'])*100),s=24,facecolors='none',edgecolors=color)
 ax.plot([-127,127,127,-127,-127],[-63.5,-63.5,63.5,63.5,-63.5],color='#aac3af',lw=2)
 ax.set(xlim=(-135,135),ylim=(72,-72),aspect='equal',xlabel='X (cm)',ylabel='Z (cm)')
 r=get(a,b);ax.set_title(' / '.join(f'{NAMES[k]} {r[k]:.2f} cm' for k in MET),fontsize=10)
 ax.legend(fontsize=8,loc='upper center');ax.grid(alpha=.15)
fig.suptitle('Post-contact cue-ball trajectories · circles=contact / crosses=end / rings=cushion',fontsize=16)
fig.savefig(OUT/'engine-comparisons.png',dpi=160);plt.close(fig)
fig,axs=plt.subplots(3,3,figsize=(14,11),layout='constrained')
for ax,r in zip(axs.flat,[r for r in D['synthetic'] if r['budget']==512][:9]):
 for key,c in [('a','#146c94'),('b','#d37619')]:
  p=np.array(r[key]);ax.plot(*p.T,color=c,lw=1.8);ax.scatter(*p[0],c=c,s=15);ax.scatter(*p[-1],c=c,marker='x')
 ax.set_title(r['id']+'\n'+' / '.join(f'{r[k]:.2f}' for k in MET)+' cm')
 ax.set(xlim=(-110,110),ylim=(65,-65),aspect='equal');ax.grid(alpha=.2)
fig.suptitle('Constructed counterexamples · distance order: Fréchet / mean DTW / Chamfer',fontsize=14)
fig.savefig(OUT/'counterexamples.png',dpi=160);plt.close(fig)
chosen=ids
fig,axs=plt.subplots(1,3,figsize=(16,6),layout='constrained')
for ax,key in zip(axs,MET):
 matrix=np.array([[score(get(a,b)[key]) for b in chosen] for a in chosen]);ax.imshow(matrix,vmin=0,vmax=100,cmap='YlGnBu')
 ax.set_xticks(range(len(chosen)),[x.replace('pot_','p_').replace('free_','f_') for x in chosen],rotation=65,ha='right');ax.set_yticks(range(len(chosen)),chosen)
 ax.set_title(NAMES[key]+' score · T50=10 cm')
 for i in range(len(chosen)):
  for j in range(len(chosen)):ax.text(j,i,f'{matrix[i,j]:.0f}',ha='center',va='center',color='white' if matrix[i,j]>60 else '#111',fontsize=8)
fig.savefig(OUT/'similarity-matrices.png',dpi=170);plt.close(fig)
fig,axs=plt.subplots(1,2,figsize=(11,4),layout='constrained')
for key in MET:axs[0].plot(list(summary),[summary[n][key]['max'] for n in summary],marker='o',label=NAMES[key])
axs[0].set(xlabel='Base sampling count',ylabel='Max difference from 2048 (cm)',xscale='log',yscale='log');axs[0].legend();axs[0].grid(alpha=.2)
x=np.linspace(0,60,200)
for t in [5,10,20]:axs[1].plot(x,100*2**(-x/t),label=f'T50={t} cm')
axs[1].set(xlabel='Distance (cm)',ylabel='Illustrative score',ylim=(0,102));axs[1].legend();axs[1].grid(alpha=.2)
fig.savefig(OUT/'convergence-and-score.png',dpi=160);plt.close(fig)
# Standalone interactive report; data embedded, no external dependencies.
payload=json.dumps({'data':D,'paths':P,'summary':summary},ensure_ascii=False)
template=(OUT/'report-template.html').read_text();(OUT/'report.html').write_text(template.replace('__DATA__',payload))
# Tables for the written research report.
parts=[]
parts.append('## 实测碰球后轨迹目录\n'+table(['ID','力度 m/s','打点 x/y','长度 cm','主库/袋角次数','终止'],[[k,f"{v['speed']:.2f}",f"{v['spinX']:.2f}/{v['spinY']:.2f}",f"{v['length_cm']:.2f}",str(sum(e['kind']=='cushion' and 0<=e['rail']<6 for e in v['events']))+'/'+str(sum(e['kind']=='cushion' and e['rail']>=6 for e in v['events'])),('母球落袋（完整）' if v['scratch'] else '停稳')] for k,v in D['metadata'].items()]))
parts.append('## 典型真实仿真对比\n'+table(['轨迹 A / B','Fréchet cm','平均 DTW cm','Chamfer cm','F 示例分'],[[a+' / '+b]+[f'{get(a,b)[k]:.3f}' for k in MET]+[f"{score(get(a,b)['frechet']):.1f}"] for a,b in selected]))
parts.append('## 构造边界案例\n'+table(['案例','Fréchet cm','平均 DTW cm','Chamfer cm','F / DTW / C 示例分'],[[r['label']]+[f"{r[k]:.3f}" for k in MET]+[' / '.join(f"{score(r[k]):.1f}" for k in MET)] for r in D['synthetic'] if r['budget']==512]))
parts.append('## 采样收敛（36 对碰球后真实轨迹，对照 2048 基础点）\n'+table(['基础点数','F 最大/中位差 cm','DTW 最大/中位差 cm','C 最大/中位差 cm','F 最大分差','最大相邻间距 cm','最大重建差 cm'],[[n]+[f"{summary[n][k]['max']:.4f}/{summary[n][k]['median']:.4f}" for k in MET]+[f"{summary[n]['scoreMaxDelta']:.3f}",f"{summary[n]['maxEdge']:.4f}",f"{summary[n]['maxReconstructionError']:.6f}"] for n in summary]))
parts.append('## 核心相似度矩阵（Fréchet，T50=10 cm，512 基础点）\n'+table(['ID']+chosen,[[a]+[f"{score(get(a,b)['frechet']):.1f}" for b in chosen] for a in chosen]))
(OUT/'RESULTS.md').write_text('\n\n'.join(parts))
print(json.dumps(summary,indent=2))
print((OUT/'RESULTS.md').read_text())
