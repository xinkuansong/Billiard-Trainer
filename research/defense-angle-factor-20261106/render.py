from pathlib import Path
import sys,json,math,html,hashlib
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name
sys.path.insert(0,str(ROOT/'research/defense-threshold-comparison-20261105'))
import geometric_table as g
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.patches import Circle
rows=json.loads((OUT/'results.json').read_text());names=['左上','右上','左下','右下','上中','下中']
records=[]
def values(v):
 e=v['effect'];r=e.get('pipeRoute');return e['score'],r,v.get('cutDegrees'),e.get('targetPipeToleranceDegrees'),e.get('comfort')
def draw(ax,row,compact=False):
 s=row['case'];old,new=row['variants'];os,orr,oa,ot,oc=values(old);ns,nr,na,nt,nc=values(new)
 g.table(ax)
 cue=np.array(s['cue']);target=np.array(s['target'])
 if nr:
  aim=np.array(nr['aim']);n=(aim-target)/np.linalg.norm(aim-target);ghost=target-2*g.R*n
  ax.plot([*cue[:1],ghost[0]],[cue[1],ghost[1]],color='white',lw=1.6,zorder=6)
  ax.plot([target[0],aim[0]],[target[1],aim[1]],color='#ffe37a',lw=1.7,zorder=6)
  ax.add_patch(Circle(ghost,g.R,facecolor='none',edgecolor='white',linestyle=':',lw=.8,zorder=7))
  pc=g.geo['pockets'][nr['pocket']]['center'];ax.add_patch(Circle(pc,.061,facecolor='none',edgecolor='#63ddff',lw=1.8,zorder=6))
 if orr and nr and orr['pocket']!=nr['pocket']:
  aim=np.array(orr['aim']);ax.plot([target[0],aim[0]],[target[1],aim[1]],color='#bdc9c4',linestyle='--',lw=1,zorder=6)
 g.ball(ax,cue,0);g.ball(ax,target,9)
 for i,b in enumerate(s['blockers']):g.ball(ax,b,8 if i==0 else 1)
 label=s['name'].replace('固定目标球 · 构造切角','构造')
 ax.set_title(f'{s["id"]} {label}\n旧 {os:.1f} → 新 {ns:.1f}',loc='left',fontsize=11 if compact else 15,color='#163d36',pad=11)
 if nr:
  pipeText='未确认（按0°估算）' if nr.get('zeroWidthEstimate') else f'{nt:.3f}°'
  text=f'新选{names[nr["pocket"]]}袋  切角 {na:.1f}°\n管道角 {pipeText}  舒适分 {nc:.1f}'
  if nr.get('zeroWidthEstimate') or new['effect'].get('estimateReason'):text+='  · 估算分支'
 else:text='确认完整遮挡 / 全部直接进球线路受阻' if ns==100 else '无路线见证 · 保守估算'
 ax.text(.01,-.035,text,transform=ax.transAxes,ha='left',va='top',fontsize=9 if compact else 11,color='#31584e')
for row in rows:
 s=row['case'];old,new=row['variants'];os,orr,oa,ot,oc=values(old);ns,nr,na,nt,nc=values(new)
 for v in row['variants']:
  score,r,a,t,c=values(v)
  if r:
   n=np.array(r['aim'])-np.array(s['target']);n/=np.linalg.norm(n);incoming=np.array(s['target'])-2*g.R*n-np.array(s['cue'])
   measured=math.degrees(math.atan2(abs(incoming[0]*n[1]-incoming[1]*n[0]),float(incoming@n)))
   assert abs(measured-a)<1e-5
   calc=100*math.sqrt((1-c/100)/(1+t*(math.cos(math.radians(r['experimentCutDegrees']))**2 if v['revised'] else 1)))
   assert abs(calc-score)<1e-8,(s['id'],calc,score)
   assert abs(r['experimentCutDegrees']-a)<1e-5
  assert 0<=score<=100
 assert ns+1e-7>=os
 fig,ax=plt.subplots(figsize=(10,6.5));fig.patch.set_facecolor('#f4f5ef');draw(ax,row);fig.subplots_adjust(top=.85,bottom=.16,left=.03,right=.97)
 fig.savefig(OUT/f'{s["id"]}.png',dpi=140,facecolor=fig.get_facecolor());plt.close(fig)
 records.append(dict(id=s['id'],name=s['name'],old=os,new=ns,cut=na,theta=nt,comfort=nc,pocket=names[nr['pocket']] if nr else None,estimate=bool(nr and nr.get('zeroWidthEstimate') or new['effect'].get('estimateReason'))))
selected=[0,2,4,6,9,14]
fig,axs=plt.subplots(3,2,figsize=(14,15.5));fig.patch.set_facecolor('#f4f5ef')
for ax,i in zip(axs.flat,selected):draw(ax,rows[i],True)
fig.subplots_adjust(top=.88,bottom=.085,left=.025,right=.975,hspace=.45,wspace=.08)
fig.suptitle('候选公式：容错角 × cos²(切角)\n每个球形均重新比较六袋，分数越高表示防守越好',fontsize=18,color='#163d36',y=.985)
fig.text(.03,.015,'白线：母球至假想球；黄线：对方9号至新选袋。灰虚线：旧选袋发生变化时的方向。\n均为终态进攻几何示意，不是新生成的防守轨迹；C15仅为截图近似复摆。',fontsize=10,color='#31584e')
fig.savefig(OUT/'comparison.png',dpi=140,facecolor=fig.get_facecolor());plt.close(fig)
header='''<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>防守切角因子对照</title><style>body{margin:24px auto;max-width:1350px;padding:0 18px;background:#f4f5ef;color:#163d36;font:16px system-ui}h1{font-size:28px}p{line-height:1.7}.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(430px,1fr));gap:20px}article{background:white;padding:12px;border-radius:12px}img{width:100%;display:block}table{width:100%;border-collapse:collapse;font-size:14px}td,th{padding:7px;border-bottom:1px solid #ddd;text-align:left}details{margin:12px 0}a{color:#146e62}@media(max-width:500px){.cards{display:block}}</style><h1>防守评分 · 切角因子对照</h1><p>候选：S = 100√[(1−C/100) / (1+θ/1° × cos²α)]。θ为目标球进球管道角，α为同一进攻路线的碰撞切角。几何、舒适分和六袋判定沿用生产实现，仅独立快照修改公式与选线排序。每图白球为对手接下来使用的母球，9号为对手目标，8号为障碍球。设计球形按指定袋构造，但实际评分可选择其他袋；下方均显示实际选袋与切角。</p><p>只评估静态终态，不证明能通过某次防守击球到达。C15由截图近似复摆，不能当作手机67.8分的精确复现。零宽/覆盖不足分支明确标记估算，不把未知窗口解释成已证实的0°。未修改App，轨迹全量仍暂停。</p>'''
cards=[]
for row,rec in zip(rows,records):
 s=row['case'];body=f'<article><img src="{s["id"]}.png" alt="{html.escape(s["name"])}"><p>{html.escape(s["note"])}</p><details><summary>查看各袋候选与舒适分构成</summary>'
 for v in row['variants']:
  body+=f'<h3>{"新" if v["revised"] else "旧"}公式</h3><table><tr><th>袋</th><th>切角</th><th>管道角</th><th>舒适分</th><th>防守分</th></tr>'
  for r in v['routes']:
   a=r['experimentCutDegrees'];t=r['rightDegrees']-r['leftDegrees'];c=r['comfort'];score=100*math.sqrt((1-c/100)/(1+t*(math.cos(math.radians(r['experimentCutDegrees']))**2 if v['revised'] else 1)))
   body+=f'<tr><td>{names[r["pocket"]]}</td><td>{a:.2f}°</td><td>{t:.4f}°</td><td>{c:.2f}</td><td>{score:.2f}{"（估算）" if r.get("zeroWidthEstimate") else ""}</td></tr>'
  body+='</table><p>确认封锁袋：'+str([names[p] for p in v['closedPockets']])+'</p>'
  if v.get('components'):body+='<p>选中路线：'+ ' / '.join(f'{k}={n:.2f}' for k,n in v['components'].items())+'</p>'
 body+='</details></article>';cards.append(body)
(OUT/'index.html').write_text(header+'<div class="cards">'+''.join(cards)+'</div><p><a href="results.json">完整数值</a> · <a href="summary.json">汇总</a></p>')
(OUT/'summary.json').write_text(json.dumps(records,ensure_ascii=False,indent=2))
(OUT/'validation.json').write_text(json.dumps(dict(passed=True,cases=len(rows),coordinateAndFormulaAudit=True,geometrySources=g.checked,scope='Static positions; native six-pocket old/new evaluation and independent formula check; PNG visual review pending'),indent=2))
print(json.dumps(records,ensure_ascii=False,indent=2))
