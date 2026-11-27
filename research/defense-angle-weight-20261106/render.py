from pathlib import Path
import sys,json,math,html
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name
sys.path.insert(0,str(ROOT/'research/defense-threshold-comparison-20261105'))
import geometric_table as g
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.patches import Circle
rows=json.loads((OUT/'results.json').read_text());before=json.loads((ROOT/'output/defense-angle-factor-20261106/results.json').read_text())
names=['左上','右上','左下','右下','上中','下中'];weights=[0,.1,.25,1,2,5]
def chosen(row,w):return next(v for v in row["variants"] if v["lambda"]==w)
def summarized(row,w):return next(v for v in row["variants"] if v["weight"]==w)
summary=[];maxbaseline=0;checks=0
for row,prev in zip(rows,before):
 assert row['case']==prev['case']
 scores=[];case=row['case'];variants=[]
 for v in row['variants']:
  e=v['effect'];r=e.get('pipeRoute');w=v['lambda'];score=e['score']
  if r:
   a=r['experimentCutDegrees'];t=r['rightDegrees']-r['leftDegrees'];c=r['comfort']
   factor=1 if w<0 else w*math.cos(math.radians(a))**2
   expected=100*math.sqrt((1-c/100)/(1+t*factor))
   assert abs(score-expected)<1e-8,(case['id'],score,expected)
   # Float terminal positions are shared by the actual native entry point.
   cue=np.array(case['cue'],dtype=np.float32).astype(float);ball=np.array(case['target'],dtype=np.float32).astype(float);n=np.array(r['aim'])-ball;n/=np.linalg.norm(n)
   radius=float(np.float32(.028575));vIn=ball-2*radius*n-cue
   actual=math.degrees(math.atan2(abs(vIn[0]*n[1]-vIn[1]*n[0]),float(vIn@n)))
   assert abs(a-actual)<1e-7
   if w==0:assert abs(score-100*math.sqrt(1-c/100))<1e-8
  else:
   assert e.get('fullDirectBlock') or e.get('potContactsBlocked'),('Unexpected no-route bound',case['id'])
   a=t=c=None
  assert math.isfinite(score) and 0<=score<=100
  if len(scores)>=2:assert score>=scores[-1]-1e-7
  scores.append(score);checks+=1
  variants.append(dict(weight=w,score=score,cut=a,theta=t,comfort=c,pocket=names[r['pocket']] if r else None,estimate=bool(r and r.get('zeroWidthEstimate') or e.get('estimateReason'))))
 for i,j in [(0,0),(3,1)]:
  delta=abs(scores[i]-prev['variants'][j]['effect']['score']);maxbaseline=max(maxbaseline,delta);assert delta<.005
 summary.append(dict(id=case['id'],name=case['name'],variants=variants))

def draw(ax,row,v):
 case=row['case'];e=v['effect'];r=e.get('pipeRoute');w=v['lambda']
 g.table(ax)
 if r:
  cue=np.array(case['cue']);ball=np.array(case['target']);aim=np.array(r['aim']);n=(aim-ball)/np.linalg.norm(aim-ball);ghost=ball-2*g.R*n
  ax.plot([cue[0],ghost[0]],[cue[1],ghost[1]],color='white',lw=1.5,zorder=6)
  ax.plot([ball[0],aim[0]],[ball[1],aim[1]],color='#ffe37a',lw=1.5,zorder=6)
  ax.add_patch(Circle(ghost,g.R,facecolor='none',edgecolor='white',linestyle=':',lw=.8,zorder=7))
  ax.add_patch(Circle(g.geo['pockets'][r['pocket']]['center'],.061,facecolor='none',edgecolor='#63ddff',lw=1.5,zorder=6))
 g.ball(ax,case['cue'],0);g.ball(ax,case['target'],9)
 for i,b in enumerate(case['blockers']):g.ball(ax,b,8 if i==0 else 1)
 ax.set_title(f'λ={w:g}   防守 {e["score"]:.1f} 分',loc='left',fontsize=15,color='#163d36',pad=12)
 if r:
  t=r['rightDegrees']-r['leftDegrees'];a=r['experimentCutDegrees'];c=r['comfort']
  pipe='未确认（按0°估算）' if r.get('zeroWidthEstimate') else f'{t:.3f}°'
  label=f'{names[r["pocket"]]}袋 · 切角 {a:.1f}° · 舒适分 {c:.1f}\n管道角 {pipe}'
 else:label='确认完整遮挡，六档均为100分'
 ax.text(.01,-.03,label,transform=ax.transAxes,va='top',fontsize=10,color='#31584e')

for row in rows:
 fig,axs=plt.subplots(2,3,figsize=(19,11));fig.patch.set_facecolor('#f4f5ef')
 for ax,v in zip(axs.flat,[chosen(row,w) for w in weights]):draw(ax,row,v)
 fig.suptitle(f'{row["case"]["id"]} · {row["case"]["name"]}',fontsize=19,color='#163d36',y=.98)
 fig.subplots_adjust(top=.87,bottom=.13,left=.035,right=.97,hspace=.45,wspace=.09)
 fig.text(.035,.025,'六档分别重选六袋最好机会；分数越高表示防守越好。白线：母球瞄准；黄线：9号进袋方向。\n'+row['case']['note'],fontsize=10,color='#31584e')
 fig.savefig(OUT/f'{row["case"]["id"]}.png',dpi=135,facecolor=fig.get_facecolor());plt.close(fig)

labels=[]
for s in summary:labels.append(s['id']+' '+s['name'].replace('固定目标球 · 构造切角','构造').replace('67.8分截图 · 近似复摆','截图近似复摆'))
fig,ax=plt.subplots(figsize=(15,12));fig.patch.set_facecolor('#f4f5ef');ax.set_facecolor('#f4f5ef')
colors=['#374c9c','#148876','#71a748','#d5ac51','#d77940','#aa4444'];ys=np.arange(len(summary));height=.135
for j,w in enumerate(weights):
 vals=[summarized(s,w)['score'] for s in summary];y=ys+(j-2.5)*height
 ax.barh(y,vals,height,color=colors[j],label=f'λ={w:g}')
 for yy,value in zip(y,vals):ax.text(value+.7,yy,f'{value:.1f}',va='center',fontsize=8,color=colors[j])
ax.set_yticks(ys,labels);ax.invert_yaxis();ax.set_xlim(0,111);ax.set_xticks([0,20,40,60,80,100]);ax.grid(axis='x',alpha=.15);ax.set_axisbelow(True)
for sp in ax.spines.values():sp.set_visible(False)
ax.legend(ncol=6,loc='lower center',bbox_to_anchor=(.5,1.01),frameon=False)
ax.set_xlabel('防守分（越高表示对方进攻越困难）')
fig.suptitle('容错角六档权重 · 同15个球形比较',fontsize=21,color='#163d36',y=.98)
fig.subplots_adjust(left=.245,right=.96,top=.89,bottom=.10)
fig.text(.04,.02,'λ=0：仅使用舒适分及封锁判定。C10/C11沿用未确认窗口的0°估算，六档不变。\nC15为截图近似复摆。全部为终态评分实验；未恢复轨迹生成，未修改App。',fontsize=10,color='#31584e')
fig.savefig(OUT/'comparison.png',dpi=145,facecolor=fig.get_facecolor());plt.close(fig)

style='<style>body{max-width:1200px;margin:24px auto;padding:0 18px;background:#f4f5ef;color:#163d36;font:16px system-ui}p{line-height:1.7}img{width:100%;height:auto}table{border-collapse:collapse;width:100%;margin:20px 0}td,th{padding:9px;border-bottom:1px solid #cdd6cf;text-align:left}a{color:#146e62}article{background:white;border-radius:12px;padding:16px;margin:24px 0}summary{cursor:pointer}code{font-size:15px}</style>'
page='<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>防守容错角权重对照</title>'+style+'<h1>容错角权重：λ=0 / 0.1 / 0.25 / 1 / 2 / 5</h1><p>S = 100√[(1−C/100)/(1+λ×θ/1°×cos²α)]。沿用上一轮15个球形和同源几何/舒适分/遮挡判断，每档重选袋内路线和六袋最佳进攻机会。λ=0仍保留两管道遮挡判断。所示为终态评分，不是防守击球轨迹或实战成功率。</p><p>C10/C11仍走未确认正宽窗口的0°估算；C15只为截图近似复摆。构造切角是布置球形时的参考，评分使用对方最佳袋口的实际切角；各图已标出。C15显示100.0是四舍五入，不代表确认完整遮挡。原始effect.scoringVersion保留生产结构版本，variants.lambda是实验权重，−1表示原始生产公式，非已发布新版。</p><img src="comparison.png" alt="15个球形六档权重的防守分对比"><table><tr><th>球形</th><th>λ=0</th><th>λ=.1</th><th>λ=.25</th><th>λ=1</th><th>λ=2</th><th>λ=5</th></tr>'
for row,s in zip(rows,summary):page+='<tr><td><a href="#'+s['id']+'">'+html.escape(s['id']+' '+s['name'])+'</a></td>'+''.join(f'<td>{v["score"]:.1f}{"*" if v["estimate"] else ""}</td>' for v in [summarized(s,w) for w in weights])+'</tr>'
page+='</table><p>* 估算分支，窗口未知不可解释为真实0°。</p>'
for row,s in zip(rows,summary):
 page+=f'<article id="{s["id"]}"><h2>{html.escape(s["id"]+" "+s["name"])}</h2><a href="{s["id"]}.png"><img loading="lazy" src="{s["id"]}.png" alt="六档权重对应的选袋、切角、舒适分和防守分"></a><details><summary>各档数值与各袋候选</summary><pre>'+html.escape(json.dumps(row['variants'],ensure_ascii=False,indent=2))+'</pre></details></article>'
page+='<p><a href="summary.json">汇总数值</a> · <a href="results.json">原始结果</a></p>'
(OUT/'index.html').write_text(page);(OUT/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
(OUT/'validation.json').write_text(json.dumps(dict(passed=True,cases=15,evaluations=checks,maxPriorBaselineDifference=maxbaseline,checks=['exact per-route formula','independent cut from Float terminal geometry','lambda0 equals comfort-only','monotone scores across descending lambda','original two baselines match previous run','no unresolved bound branch in these cases'],visualReview='pending',geometrySources=g.checked),indent=2))
print(json.dumps([dict(id=s['id'],scores=[round(v['score'],2) for v in [summarized(s,w) for w in weights]],pockets=[v['pocket'] for v in [summarized(s,w) for w in weights]]) for s in summary],ensure_ascii=False,indent=2))
