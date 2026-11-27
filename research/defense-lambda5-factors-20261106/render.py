from pathlib import Path
import json,math,sys,hashlib,html
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name
sys.path.insert(0,str(ROOT/'research/defense-threshold-comparison-20261105'))
import geometric_table as g
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.patches import Circle
rows=json.loads((OUT/'results.json').read_text());designs={c['id']:c for c in json.loads((HERE/'cases.json').read_text())}
names=['左上','右上','左下','右下','上中','下中'];BG='#f4f5ef';INK='#163d36';summary=[]
def fp(p):return np.array(p,dtype=np.float32).astype(float)
def nearrail(p):
 def dist(a,b):
  d=b-a;t=np.clip((p-a)@d/(d@d),0,1);point=a+t*d;return np.linalg.norm(p-point),point
 d,q=min((dist(np.array(a),np.array(b)) for a,b in g.rails),key=lambda v:v[0]);return float(d-g.R),q

def metric(c,r):
 cue=fp(c['cue']);ball=fp(c['target']);a=np.array(r['aim']);n=(a-ball)/np.linalg.norm(a-ball);ghost=ball-2*float(np.float32(g.R))*n;v=ghost-cue
 cut=math.degrees(math.atan2(abs(v[0]*n[1]-v[1]*n[0]),v@n));theta=r['rightDegrees']-r['leftDegrees'];score=100*math.sqrt((1-r['comfort']/100)/(1+5*theta*math.cos(math.radians(cut))**2))
 assert abs(cut-r['experimentCutDegrees'])<1e-7
 return dict(cut=cut,theta=theta,comfort=r['comfort'],score=score,cueDistance=float(np.linalg.norm(ball-cue)),potDistance=float(np.linalg.norm(a-ball)),pocketCenterDistance=float(np.linalg.norm(np.array(g.geo['pockets'][r['pocket']]['center'])-ball)),railGap=nearrail(cue)[0],targetRailGap=nearrail(ball)[0],estimate=bool(r.get('zeroWidthEstimate')))

for row in rows:
 c=designs[row['case']['id']];v=row['variants'][0];assert v['lambda']==5
 e=v['effect'];pockets=[]
 assert 0<=e['score']<=100 and math.isfinite(e['score'])
 for p in v['pockets']:
  if 'route' in p:
   m=metric(c,p['route']);assert abs(p['score']-m['score'])<1e-8
   pockets.append(dict(pocket=p['pocket'],name=names[p['pocket']],**m))
  else:pockets.append(dict(pocket=p['pocket'],name=names[p['pocket']],confirmedClosed=p['confirmedClosed'],noRoute=True))
 r=e.get('pipeRoute');m=metric(c,r) if r else None
 if m:assert abs(e['score']-m['score'])<1e-8
 else:
  if e.get('estimateReason'):
   assert e['estimateReason']=='可行线路尚未确认，按对方进攻的有利几何上界保守估分。'
   expected=100*math.sqrt((1-e['comfort']/100)/(1+e['targetPipeToleranceDegrees']))
   assert abs(expected-e['score'])<1e-8
  else:assert e.get('fullDirectBlock') or e.get('potContactsBlocked'),('unexpected branch',c['id'])
 if r and v['routes']:
  low=min(metric(c,t)['score'] for t in v['routes']);assert abs(low-e['score'])<1e-8
 summary.append(dict(id=c['id'],group=c['group'],name=c['name'],design=c['design'],cue=c['cue'],target=c['target'],globalScore=e['score'],legacyBound=bool(e.get('estimateReason') and not r),bestPocket=names[r['pocket']] if r else None,best=m,focusPocket=c['focusPocket'],pockets=pockets))
byid={r['case']['id']:r for r in rows};bys={s['id']:s for s in summary}

def draw(ax,row,pocket=None,title=None):
 c=designs[row['case']['id']];v=row['variants'][0];e=v['effect'];idx=c['focusPocket'] if pocket is None else pocket;p=v['pockets'][idx];r=p.get('route')
 g.table(ax)
 cue=fp(c['cue']);ball=fp(c['target'])
 if r:
  aim=np.array(r['aim']);n=(aim-ball)/np.linalg.norm(aim-ball);ghost=ball-2*g.R*n
  ax.plot([cue[0],ghost[0]],[cue[1],ghost[1]],color='white',lw=1.7,zorder=6)
  ax.plot([ball[0],aim[0]],[ball[1],aim[1]],color='#ffe37a',lw=1.8,zorder=6)
  ax.add_patch(Circle(ghost,g.R,facecolor='none',edgecolor='white',ls=':',lw=.9,zorder=7))
 if c['group'].startswith('rail'):
  gap,q=nearrail(cue);u=(q-cue)/np.linalg.norm(q-cue);edge=cue+g.R*u
  ax.plot([edge[0],q[0]],[edge[1],q[1]],color='#6fe5ee',lw=2,zorder=7)
 ax.add_patch(Circle(g.geo['pockets'][idx]['center'],.061,facecolor='none',edgecolor='#63ddff',lw=1.5,zorder=6))
 g.ball(ax,c['cue'],0);g.ball(ax,c['target'],9)
 for i,b in enumerate(c['blockers']):g.ball(ax,b,8 if i==0 else 1)
 head=title or (c['id']+' '+c['name']);ax.set_title(head,loc='left',fontsize=13,color=INK,pad=9)
 globalp=names[e['pipeRoute']['pocket']]+'袋'+('，估算' if e['pipeRoute'].get('zeroWidthEstimate') or e.get('estimateReason') else '') if e.get('pipeRoute') else ('旧式保守估算' if e.get('estimateReason') else '完整封锁')
 if r:
  m=metric(c,r);theta='未知（0°估算）' if m['estimate'] else f'{m["theta"]:.3f}°'
  label=f'{names[idx]}袋线路分 {m["score"]:.1f}   |   整体 {e["score"]:.1f}（{globalp}）\n切角 {m["cut"]:.1f}°   容错角 {theta}   舒适分 {m["comfort"]:.1f}\n母目标距 {m["cueDistance"]*100:.1f}cm   目标至入袋点 {m["potDistance"]*100:.1f}cm\n母球库边净距 {max(0,m["railGap"])*100:.1f}cm'
 else:
  state='直线模型已排除' if p['confirmedClosed'] else '未确认可用路线'
  label=f'{names[idx]}袋：{state}   |   整体 {e["score"]:.1f}（{globalp}）\n'+('无切角见证，沿用旧公式；不计入λ=5有效对照。\n' if e.get('estimateReason') else '该袋没有候选，不赋单袋分；不代表所有打法均不可行。\n')+f'母目标距 {np.linalg.norm(cue-ball)*100:.1f}cm   母球库边净距 {max(0,nearrail(cue)[0])*100:.1f}cm'
 ax.text(.01,-.025,label,transform=ax.transAxes,va='top',fontsize=10.3,color='#31584e',linespacing=1.5)

def panel(ids,filename,title,note,pockets=None):
 count=len(ids);nr=math.ceil(count/2);fig,axs=plt.subplots(nr,2,figsize=(13.6,nr*4.9+1.0),squeeze=False);fig.patch.set_facecolor(BG)
 for i,ax in enumerate(axs.flat):
  if i>=count:ax.axis('off');continue
  pocket=pockets[i] if pockets else None
  draw(ax,byid[ids[i]],pocket,title=(ids[i]+' · '+names[pocket]+'袋') if pockets else None)
 fig.suptitle(title,fontsize=20,color=INK,y=.985)
 fig.subplots_adjust(top=1-.85/(nr*4.9+1),bottom=2.0/(nr*4.9+1),left=.035,right=.975,hspace=.74,wspace=.10)
 fig.text(.035,.018,'λ=5；白球为母球，9号为对方目标球。白线为瞄准、黄线为目标球进袋方向，均非运动轨迹。\n'+note,fontsize=10,color='#31584e')
 fig.savefig(OUT/filename,dpi=135,facecolor=BG);plt.close(fig)

groups=[('angle','切角变化','目标球固定，母目标距70cm；构造角不等于实际选袋切角。'),('cue_distance','母球到目标球距离','目标球固定、右下袋构造切角15°；母球库距会随位置变化。'),('pot_distance','目标球袋距与容错角','构造切角30°、母目标距65cm；袋距变化会同时改变容错角及舒适分。'),('rail_away','母球靠近左短库','母球与目标球整体平移；此组杆后方向较朝向短库。袋距和切角亦变化。'),('rail_parallel','母球靠近上长库','母球与目标球整体平移；此组入射较平行长库。袋距和切角亦变化。'),('near_rail','目标球半贴库：模型边界','未知窗口标“0°估算”，不是实测0°；不能据此认定防守评分已校准。')]
for group,title,note in groups:
 ids=[s['id'] for s in summary if s['group']==group];panel(ids,group+'-all.png','λ=5 · '+title,note)
 picks=[ids[i] for i in ([0,2,3,4,5,7] if group!='near_rail' else [0,1,2,3,6,7])];panel(picks,group+'.png','λ=5 · '+title,note)
for id in ['D01','D02']:panel([id]*6,id+'-pockets.png','λ=5 · 同一球形比较六个袋口',designs[id]['note'],list(range(6)))
# Individual single-layout diagram with six-pocket numeric table saved separately in the report.
for row in rows:
 c=designs[row['case']['id']];fig,ax=plt.subplots(figsize=(10,7.6));fig.patch.set_facecolor(BG);draw(ax,row)
 fig.subplots_adjust(top=.89,bottom=.27,left=.035,right=.975);fig.text(.04,.025,c['note'],fontsize=9,color=INK,wrap=True)
 fig.savefig(OUT/(c['id']+'.png'),dpi=125,facecolor=BG);plt.close(fig)

# Formula-only sensitivity: hold comfort fixed; no implied realizable ball layout.
angles=[0,15,30,45,60,75,85,88];thetas=[.05,.1,.25,.5,1,2,5,10];sens=[]
fig,axs=plt.subplots(1,3,figsize=(16,6.3));fig.patch.set_facecolor(BG)
for ax,C in zip(axs,[20,50,80]):
 vals=np.array([[100*math.sqrt((1-C/100)/(1+5*t*math.cos(math.radians(a))**2)) for a in angles] for t in thetas]);sens.append(dict(comfort=C,angles=angles,thetas=thetas,scores=vals.tolist()))
 im=ax.imshow(vals,vmin=0,vmax=100,cmap='YlGnBu',aspect='auto');ax.set_xticks(range(len(angles)),[str(a)+'°' for a in angles]);ax.set_yticks(range(len(thetas)),[str(t)+'°' for t in thetas]);ax.set_title(f'固定舒适分 C={C}',fontsize=15);ax.set_xlabel('碰撞切角 α');ax.set_ylabel('目标球容错角 θ')
 for i in range(len(thetas)):
  for j in range(len(angles)):ax.text(j,i,f'{vals[i,j]:.1f}',ha='center',va='center',fontsize=8.5,color='white' if vals[i,j]>55 else '#163d36')
fig.suptitle('λ=5 · 容错角与切角的独立作用（纯公式）',fontsize=20,color=INK,y=.98);fig.subplots_adjust(left=.06,right=.98,top=.85,bottom=.19,wspace=.32)
fig.text(.035,.035,'固定C仅隔离分母的影响：这不是一组真实球形，也未包含C随切角、距离变化的作用。\n真实球形必须使用上方原生计算结果，并在六袋中取对方最好机会。',fontsize=11,color=INK);fig.savefig(OUT/'tolerance-sensitivity.png',dpi=140,facecolor=BG);plt.close(fig)
(OUT/'sensitivity.json').write_text(json.dumps(sens,ensure_ascii=False,indent=2))
(OUT/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
report=['# λ=5 多因素球形对照','', '52个静态终态，其中10个最佳机会使用未知宽度的0°估算（F05/F06及G组），1个E01沿用旧公式上界估算，其余41例为40个有窗口路线及1个完整遮挡。原生候选评分；没有生成防守击球路线或修改App。指定袋口分只说明该线路，整体分从全部六袋中选择对方最好机会。E01恰好贴短库未确认可用路线，20.44为旧公式保守估算，不能当λ5实算或完整遮挡。', '', '距离口径：母目标球心距；目标球到实际入袋候选点；母球面到最近有限主库段净距（含端点），不等同沿球杆回杆方向的可用空间。图上蓝圈为当前所比较袋口，白/黄线为进攻几何。','']
for group,title,note in groups:
 report+=['## '+title,'',note,'',f'![{title}]({group}-all.png)','', '| 编号 | 指定袋分 | 整体分 | 最佳袋 | 实际切角 | 容错角 | 母目标距cm | 目标入袋距cm | 母球库净距cm |','|---|---:|---:|---|---:|---:|---:|---:|---:|']
 for s in [s for s in summary if s['group']==group]:
  p=s['pockets'][s['focusPocket']]
  if 'score' in p:report.append(f'| {s["id"]} | {p["score"]:.2f} | {s["globalScore"]:.2f}{'*' if s['best'] and s['best']['estimate'] else ''} | {s["bestPocket"]} | {p["cut"]:.2f}° | '+('未知*' if p['estimate'] else f'{p["theta"]:.4f}°')+f' | {p["cueDistance"]*100:.2f} | {p["potDistance"]*100:.2f} | {max(0,p["railGap"])*100:.2f} |')
  else:report.append(f'| {s["id"]} | 无该袋候选 | {s["globalScore"]:.2f}{'*' if s['best'] and s['best']['estimate'] else ''} | {s["bestPocket"]} | — | — | — | — | — |')
 report+=['','* 未确认正宽窗口，沿用0°估算，不是真实0°。','']
for id in ['D01','D02']:
 s=bys[id];report+=['## '+id+' 六袋比较','',f'![六袋比较]({id}-pockets.png)','', '| 袋口 | 线路分 | 切角 | 容错角 | 目标至入袋点cm | 舒适分 |','|---|---:|---:|---:|---:|---:|']
 for p in s['pockets']:
  if 'score' in p:report.append(f'| {p["name"]} | {p["score"]:.2f} | {p["cut"]:.2f}° | '+('未知*' if p['estimate'] else f'{p["theta"]:.4f}°')+f' | {p["potDistance"]*100:.2f} | {p["comfort"]:.2f} |')
  else:report.append(f'| {p["name"]} | '+('当前直线模型排除' if p['confirmedClosed'] else '未确认路线')+' | — | — | — | — |')
 report+=['',f'整体防守分：{s["globalScore"]:.2f}；对方最好机会：{s["bestPocket"]}袋。','']
report+=['## 公式敏感性','', '![纯公式敏感性](tolerance-sensitivity.png)','', '这张图固定C，仅隔离容错角与切角因子的作用，不代表实际球形。λ=5尚未标定成进球概率；本批静态终态不证明防守击球可达。','', '生产v8未改，全量生成仍暂停。完整App/真机/UI交互未测。本轮原生构建、评估、几何审计及静态PNG可视检查分别记录于validation.json和execution.json。']
(OUT/'README.md').write_text('\n'.join(report)+'\n')
page='<html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>λ=5 多因素防守评分</title><style>body{font:17px system-ui;max-width:1100px;margin:24px auto;padding:0 16px;color:#163d36;background:#f4f5ef}img{width:100%}p{line-height:1.7}</style><h1>λ=5 多因素防守评分</h1><p>52个静态终态，逐袋比较。蓝圈为当前袋口；白线瞄准、黄线进袋。线路分与整体分分开。原始坐标及各袋数据见summary.json。</p>'
for file in [g[0]+'-all.png' for g in groups]+['D01-pockets.png','D02-pockets.png','tolerance-sensitivity.png']:page+=f'<p><a href="{file}"><img src="{file}" alt="{file}"></a></p>'
page+='<p>App未改；全量仍暂停。窗口未知的估算分单独标记。</p></html>'
(OUT/'index.html').write_text(page)
# Prespecified controls verified at construction geometry, independently of winning pocket.
for s in summary:
 c=designs[s['id']];d=c['design']
 if 'cueDistance' in d:assert abs(np.linalg.norm(np.array(c['cue'])-c['target'])-d['cueDistance'])<1e-10
 if 'cut' in d:
  n=np.array(g.geo['pockets'][c['focusPocket']]['center'])-c['target'];n/=np.linalg.norm(n);v=np.array(c['target'])-2*g.R*n-c['cue'];cut=math.degrees(math.atan2(abs(v[0]*n[1]-v[1]*n[0]),v@n));assert abs(cut-d['cut'])<.0001,(s['id'],cut,d)
 if 'railGap' in d:assert abs(nearrail(np.array(c['cue']))[0]-d['railGap'])<1e-6
 if 'pocketCenterDistance' in d:assert abs(np.linalg.norm(np.array(g.geo['pockets'][3]['center'])-c['target'])-d['pocketCenterDistance'])<1e-6
# Same target -> unchanged geometric pipe width for the same confirmed branch.
for prefix in ['A','B']:
 widths=[bys[c['id']]['pockets'][3].get('theta') for c in designs.values() if c['id'].startswith(prefix)];widths=[v for v in widths if v is not None];assert max(widths)-min(widths)<1e-10,(prefix,widths)
manifest=json.loads((OUT/'source-manifest.json').read_text());drift=[p for p,h in manifest.items() if hashlib.sha256((ROOT/p).read_bytes()).hexdigest()!=h];assert not drift
val=dict(passed=True,cases=len(rows),pocketEvaluations=6*len(rows),formulaRoutes=sum('score' in p for s in summary for p in s['pockets']),estimatedGlobalCases=[s['id'] for s in summary if s['best'] and s['best']['estimate']],legacyBoundCases=[s['id'] for s in summary if s['legacyBound']],sourceDrift=drift,geometrySources=g.checked,checks=['native all six pockets','independent route angle and score','best opportunity min','fixed ball-distance and construction-angle controls','surface-to-finite-rail gap','target-pipe width invariant under cue movement'],visualReview='pending')
(OUT/'validation.json').write_text(json.dumps(val,ensure_ascii=False,indent=2))
print(json.dumps(val,ensure_ascii=False,indent=2))
