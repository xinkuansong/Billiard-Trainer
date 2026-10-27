from pathlib import Path
import json,gzip,math,hashlib
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
O=Path('output/rack-spin-forensics-20261027');r=json.loads(next(iter(gzip.open(O/'raw.jsonl.gz','rt'))));a=json.loads((O/'audit.json').read_text());L=json.loads((O/'ledger.json').read_text());P=a['constants'];R=P['ballRadius'];U=np.array([0.,1.,0.])
# First branch: all candidate states evaluated at the SAME post-cue-impact state.
source=r['eventTrace'][0]['postB'];p,v,w=map(np.array,[source['p'],source['v'],source['w']]);u=v+np.cross(w,-R*U);acc=-P['slidingFriction']*P['gravity']*u/np.linalg.norm(u)
fork=[]
for name in ['_3','_11']:
 b=next(x for x in r['rack'] if '_'+str(x['number'])==name);q=np.array([b['x'],p[1],b['z']])-p;dv=-v;da=-acc
 co=[.25*(da@da),dv@da,dv@dv+q@da,2*q@dv,q@q-4*R*R]
 roots=sorted(x.real for x in np.roots(co) if abs(x.imag)<1e-10 and x.real>0);t=roots[0]
 delta=q+dv*t+.5*da*t*t;res=abs(np.linalg.norm(delta)-2*R);assert res<1e-12 and delta@(dv+da*t)<0
 fork.append(dict(ball=name,gapM=float(np.linalg.norm(q)-2*R),predictedDelaySeconds=float(t),contactResidualM=float(res)))
assert fork[1]['predictedDelaySeconds']<fork[0]['predictedDelaySeconds'];(O/'first-fork.json').write_text(json.dumps(fork,indent=2))
# Exact scalar bookkeeping across every interval and every logged impulse.
budgets={}
for name in ['_12','_1']:
 fs=r['frames'][r['names'].index(name)];rows=L[name];signed=sum(x['post']['w'][1]-x['pre']['w'][1] for x in rows if x['kind']!='transition')
 # Signed decay from frames, subtracting all actual impulse/transition jumps.
 initial=fs[0]['w'][1];end=fs[-1]['w'][1]
 budgets[name]=dict(initialWy=initial,signedContactChange=signed,signedContinuousAndRoundoffChange=end-initial-signed,finalWy=end)
(O/'spin-budget.json').write_text(json.dumps(budgets,indent=2))
font='/System/Library/Fonts/STHeiti Medium.ttc'
font_manager.fontManager.addfont(font);plt.rcParams['font.family']=font_manager.FontProperties(fname=font).get_name();plt.rcParams['axes.unicode_minus']=False
fig=plt.figure(figsize=(13,9),layout='constrained');gs=fig.add_gridspec(2,2,height_ratios=[1,1]);ax=fig.add_subplot(gs[0,:]);av=fig.add_subplot(gs[1,0]);aw=fig.add_subplot(gs[1,1])
cols={'_12':'#c64040','_1':'#276cb5'}
ax.set_facecolor('#edf5f0');ax.plot([-1.27,1.27,1.27,-1.27,-1.27],[-.635,-.635,.635,.635,-.635],color='#426b54',lw=3)
for n in ['_12','_1']:
 fs=r['frames'][r['names'].index(n)];color=cols[n];xy=np.array([x['p'] for x in fs]);tt=[x['t'] for x in fs]
 ax.plot(xy[:,0],xy[:,2],color=color,lw=1.7,alpha=.8,label=n[1:]+'号球实际路径')
 ax.scatter([xy[0,0]],[xy[0,2]],color=color,s=65,zorder=4);ax.scatter([xy[-1,0]],[xy[-1,2]],color=color,s=70,marker='s',zorder=5)
 av.plot(tt,[np.linalg.norm(x['v']) for x in fs],color=color,lw=1.7,label=n[1:]+'号球')
 aw.plot(tt,[x['w'][1] for x in fs],color=color,lw=1.7,label=n[1:]+'号球')
for x,label,offset in [(L['_12'][5],'撞母球\n0.739秒',(30,32)),(L['_12'][6],'撞14号球\n0.813秒',(-15,-58))]:
 p=x['post']['p'];ax.scatter([p[0]],[p[2]],marker='X',s=75,color=cols['_12'],zorder=6);ax.annotate(label,(p[0],p[2]),xytext=offset,textcoords='offset points',fontsize=10,arrowprops=dict(arrowstyle='->',color='#444'))
for b in r['rack']:
 ax.add_patch(plt.Circle((b['x'],b['z']),R,fill=False,color='#555',alpha=.45,lw=.7))
ax.set_aspect('equal');ax.set_xlim(-1.35,1.35);ax.set_ylim(.72,-.72);ax.set_xlabel('世界X（米）');ax.set_ylabel('世界Z（米；横桌向下）');ax.legend(loc='upper right',fontsize=10);ax.set_title('固定球阵11331｜原生产引擎、原参数、杆速10｜圆点起点，方块终点',fontsize=14)
av.set_xlim(0,7.5);av.set_ylim(-.1,12.3);av.set_title('平移速度：后两次撞球明显减速');av.set_xlabel('击球后时间（秒）');av.set_ylabel('m/s');av.legend();av.grid(alpha=.2)
for t in [.739068508,.81289804]:av.axvline(t,color='#a77',alpha=.4,lw=.8)
aw.axvline(7.075041294,color='#777',ls='--',lw=1);aw.text(7.22,-23,'全台停移\n7.075秒',fontsize=10)
aw.axvspan(7.075041294,16.338579178,color='#c64040',alpha=.07);aw.set_title('竖直轴自旋：12号球保留强侧旋');aw.set_xlabel('击球后时间（秒）');aw.set_ylabel('rad/s（正负表示转向）');aw.set_xlim(0,17);aw.legend(loc='lower right');aw.grid(alpha=.2)
fig.savefig(O/'comparison.png',dpi=160);fig.savefig(O/'comparison.svg');plt.close(fig)
lines=['# 固定球阵逐次接触账本','',f"球阵11331；seed={r['input']['seed']}；原生产引擎与原参数；时间自击球起算。",'','问题球：12号（slot10，+Z角）；位置对应球：1号（slot14，−Z角）。原摆球有微扰，二者不是严格镜像初态。','']
for name in ['_12','_1']:
 lines += ['## '+name[1:]+'号球','','| 时间秒 | 事件 | 速度前→后 m/s | 侧旋前→后 rad/s | 平动能前→后 J | 侧旋能前→后 J |','|---:|---|---:|---:|---:|---:|']
 for x in L[name]:
  b,c=x['before'],x['after'];kind={'ball':'撞球','cushion':'碰库','transition':'转态'}[x['kind']]
  lines.append(f"|{x['t']:.6f}|{kind} {x['other']}|{b['speed']:.4f}→{c['speed']:.4f}|{b['wy']:.4f}→{c['wy']:.4f}|{b['energy']['linear']:.5f}→{c['energy']['linear']:.5f}|{b['energy']['axialSpin']:.5f}→{c['energy']['axialSpin']:.5f}|")
 lines.append('')
lines+=['各事件完整位置、三轴速度/角速度、接触滑移、冲量、力矩、摩擦上限和独立复算误差见ledger.json。此处侧旋指世界Y轴分量，未把绕水平轴滚转混作侧旋。']
(O/'ledger.md').write_text('\n'.join(lines)+'\n')
print('first fork',fork)
print('saved',O/'comparison.png')
