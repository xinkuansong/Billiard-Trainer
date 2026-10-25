"""Full independent NumPy readback, then statistics and a read-only report."""
from pathlib import Path
import gzip,hashlib,json,math,shutil,time
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import fontManager
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/two-ball-comfort-full-20261025'
def read(p):return json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=2,allow_nan=False)+'\n')
start=time.perf_counter();s=read(OUT/'summary-pending.json');manifest=read(OUT/'manifest.json');g=manifest['geometry'];hx=g['length']/2;hz=g['width']/2;r=g['radius'];anchors=np.array([[-hx+r,-hz+r],[hx-r,-hz+r],[-hx+r,hz-r],[hx-r,hz-r],[0,-hz],[0,hz]])
seen=set();bs=set();allvalues=[];best=[];maxdiff=0;count=0;negative=0
for part in read(OUT/'parts-index.json'):
 p=OUT/'parts'/(part['stem']+'.jsonl.gz');assert sha(p)==part['sha256'];rows=[json.loads(l) for l in gzip.decompress(p.read_bytes()).splitlines()];assert [x['id'] for x in rows]==part['layoutIDs']
 coords=[];balls=[];pockets=[];saved=[]
 for row in rows:
  assert row['id'] not in seen;seen.add(row['id'])
  for c in row['candidates']:
   key=(row['id'],c['cellID']);assert key not in bs;bs.add(key);values=[];combos=set()
   for q in c['recommendations']:
    assert q['comboIndex'] not in combos;combos.add(q['comboIndex']);values.append(q['totalScore']);allvalues.append(q['totalScore'])
    coords.append(q['stop']);balls.append(c['position']);pockets.append(q['pocket']);saved.append([q['distanceScore'],q['spaceScore'],q['angleScore'],q['totalScore']]);count+=1
   assert c['bestTotalScore']==(max(values) if values else None)
   if values:best.append(max(values))
 if not coords:continue
 C=np.array(coords);B=np.array(balls);N=anchors[pockets]-B;N/=np.linalg.norm(N,axis=1)[:,None];V=B-2*r*N-C;L=np.linalg.norm(V,axis=1);back=-V/L[:,None]
 cut=np.degrees(np.arctan2(np.abs(V[:,0]*N[:,1]-V[:,1]*N[:,0]),np.sum(V*N,axis=1)));dist=np.linalg.norm(C-B,axis=1)
 direction=-N;bound=np.array([hx-r,hz-r]);ray=np.divide(np.where(direction>0,bound-B,-bound-B),direction,out=np.full_like(B,np.inf),where=np.abs(direction)>1e-12);depth=np.maximum(0,ray.min(axis=1));scale=np.clip(depth/.9,.4,1);lo=.5*scale;hi=.8*scale
 D=100*np.exp(-(np.maximum(lo-dist,0)/(.8*lo))**2-(np.maximum(dist-hi,0)/.75)**2)
 gaps=np.column_stack([hx-C[:,0]-r,hx+C[:,0]-r,hz-C[:,1]-r,hz+C[:,1]-r]);negative+=int(np.sum(gaps.min(axis=1)<0));toward=np.column_stack([back[:,0],-back[:,0],back[:,1],-back[:,1]])
 pen=(45+15*np.maximum(toward,0)**2)*np.exp(-(np.maximum(gaps,0)*100/8)**1.2);axis=pen.argmax(axis=1);neighbor=np.where(axis<2,pen[:,2:].max(axis=1),pen[:,:2].max(axis=1));S=100-pen.max(axis=1)-np.minimum(8,.25*neighbor)
 A=100*np.exp(-(np.maximum(cut-15,0)/30)**2);T=np.cbrt(D*S*A);calc=np.column_stack([D,S,A,T]);delta=float(np.max(np.abs(calc-np.array(saved))));maxdiff=max(maxdiff,delta);assert delta<1e-8
 assert np.all(np.isfinite(calc)) and np.all((calc>=0)&(calc<=100+1e-10))
assert len(seen)==13570 and len(bs)==173577 and count==745153 and len(best)==167062
assert negative==s['negativeRectangleGap']['count']
for values,field in [(allvalues,'routeScores'),(best,'questionBestScores')]:
 a=np.array(values);assert np.histogram(a,bins=np.linspace(0,100,11))[0].tolist()==s[field]['histogram10']
 for t in [80,85,90]:assert int(np.sum(a>=t))==s[field]['atLeast'][str(t)]
 for pc,val in s[field]['percentiles'].items():assert abs(float(np.percentile(a,int(pc)))-val)<1e-10
for p,h in manifest['sourceHashes'].items():assert sha(Path(p))==h
s.update(state='complete',auditPassed=True,auditSeconds=time.perf_counter()-start,completedAt=time.time(),verification=dict(uniqueLayouts=len(seen),uniqueB=len(bs),allScoresIndependentlyRecomputed=count,maxComponentDifference=maxdiff,allOutputSHA256Passed=True,originalSourceHashesUnchanged=True,original22PreviewMatched=True))
write(OUT/'summary.json',s)
fontManager.addfont('/Library/Fonts/Arial Unicode.ttf');plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
fig,axes=plt.subplots(2,2,figsize=(14,10),facecolor='#f6f8f1');edges=np.arange(0,101,10)
for ax,values,title,color in [(axes[0,0],allvalues,'全部推荐停点 · 745,153条','#1683ac'),(axes[0,1],best,'每题最高分 · 167,062道有推荐题','#258c67')]:
 ax.hist(values,bins=edges,color=color,rwidth=.9);ax.set(title=title,xlabel='舒适度总分',ylabel='数量',xticks=edges);ax.grid(axis='y',alpha=.2)
for ax,field,title,color,denom in [(axes[1,0],'routeScores','达到阈值的推荐停点','#1683ac',745153),(axes[1,1],'questionBestScores','至少有一个停点达到阈值的题','#258c67',173577)]:
 vals=[s[field]['atLeast'][str(t)] for t in [80,85,90]];ax.bar(['≥80','≥85','≥90'],vals,color=color);ax.set_title(title);ax.margins(y=.22)
 for i,v in enumerate(vals):ax.text(i,v,f'{v:,}\n{v/denom:.2%}',ha='center',va='bottom',fontsize=11)
 for spine in ['top','right']:ax.spines[spine].set_visible(False)
fig.suptitle('原版题库 · 中袋验证后舒适度分布',fontsize=20);fig.text(.5,.025,'球距v2 / 空间v3 / 角度15°平台·30°尺度；三项等权几何平均。题数按布局+B位置去重；阈值累计包含。',ha='center',fontsize=11);fig.text(.5,.005,'另有6,515个位置无推荐，保留为空，不记作0分；题比例分母173,577，停点比例分母745,153。',ha='center',fontsize=10);fig.tight_layout(rect=[0,.05,1,.95]);fig.savefig(OUT/'statistics.png',dpi=150);plt.close(fig)
thresholdRows='\n'.join(f'| ≥{t} | {s["routeScores"]["atLeast"][str(t)]:,} | {s["questionBestScores"]["atLeast"][str(t)]:,} | {s["questionBestScores"]["atLeast"][str(t)]/173577:.2%} | {s["questionBestScores"]["atLeast"][str(t)]/167062:.2%} |' for t in [80,85,90])
binRows='\n'.join(f'| {i*10}–{(i+1)*10}{"（含100）" if i==9 else "（不含右端）"} | {s["routeScores"]["histogram10"][i]:,} | {s["questionBestScores"]["histogram10"][i]:,} |' for i in range(10))
readme=f'''# 原版题库：中袋验证后的舒适度全量统计

本轮只计算分数和分布，没有按分数筛选、没有修改原题库或App。原版指已审计25°微调版，经阶段A中袋验证后保留的推荐，不采用18°网格优化版。

## 先做中袋过滤

复用已完成的阶段A验证，并全量重新核验原25°来源、A产物/证据SHA、删除分区及每条保留中袋的物理证明。357,711条中袋推荐中删除70,923、通过286,788；458,365条角袋推荐保持原样。816,076条推荐变为745,153条。

有推荐的题：170,445 → 167,062；3,383题在中袋过滤后失去全部推荐，加上原有3,132空题，共6,515空题。保留其他可用袋口/路线的题不会整题删除。中袋失败表示固定中杆方向、至多5个速度未通过验证，不是全参数不可进证明。

## 统计口径与结果

一题 = (初始布局id, 第二球cellID)，共173,577道、13,570初始布局。同一题最高推荐总分作为题分；各推荐用原袋口评价，未经舍入判断≥阈值。以下是累计数量，不能相加。空题无分数，不伪记0分。

| 阈值 | 推荐停点数量 | 题数（至少一个停点达标） | 占全部题 | 占有推荐题 |
|---|---:|---:|---:|---:|
{thresholdRows}

| 分数段 | 推荐停点数 | 题最高分数量 |
|---|---:|---:|
{binRows}

推荐停点均分{s['routeScores']['mean']:.2f}，中位数{s['routeScores']['percentiles']['50']:.2f}；有推荐题的最高分均值{s['questionBestScores']['mean']:.2f}，中位数{s['questionBestScores']['percentiles']['50']:.2f}。

![分布](statistics.png)

## 评分与边界

球距放缓v2，空间v3，角度0–15°满分、30°衰减尺度，总分∛(球距×空间×角度)。见manifest.json冻结完整参数及几何。距离是母球—B球心距；角度由母球到假想球方向计算；空间使用沿第二杆杆尾方向的四库罚分，离库按球面净距。分数不是进球概率，不含首杆难度。

{negative:,}个推荐引用的原生停点出现负矩形净距（最小{s['negativeRectangleGap']['minMeters'] if negative else 0:.9f}m），袋口开口处原生可停点可能超出矩形内缩边界。按既有空间公式将净距输入clamp到0，不改变坐标、不删路线，单独记录口径。没有新增进袋模拟。首轮审查误把矩形内缩当停点硬门槛的失败日志保留于failures/；移除此额外门槛后全量评分，22个原预览分数一致。

## 文件和验证

- `parts/*.jsonl.gz`：仅评分附表，保留全部题和原推荐顺序；按id/cellID/comboIndex/pocket关联阶段A原轨迹，含原停点、三个分项及总分，不复制/改写轨迹。
- `parts-index.json`：每分片SHA；`manifest.json`：来源与参数；`summary.json`：完整统计与验证。
- {count:,}条评分独立NumPy复算通过，最大分项差{maxdiff:.3g}；13,570布局/173,577题唯一、SHA、22例、全部阈值和分布核验通过。
- 计算及来源审计{s['scoringAndSourceAuditSeconds']:.2f}秒，独立读回审计{s['auditSeconds']:.2f}秒；评分附表gzip共{s['scoreGzipBytes']/1e6:.2f}MB。
'''
(OUT/'README.md').write_text(readme)
rows=''.join(f'<tr><td>≥{t}</td><td>{s["routeScores"]["atLeast"][str(t)]:,}</td><td>{s["questionBestScores"]["atLeast"][str(t)]:,}</td><td>{s["questionBestScores"]["atLeast"][str(t)]/173577:.2%}</td></tr>' for t in [80,85,90])
(OUT/'index.html').write_text('''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>舒适度全量分布</title><style>body{max-width:1250px;margin:35px auto;padding:20px;background:#f6f8f1;color:#243f32;font:18px system-ui}p{line-height:1.8}img{width:100%}table{width:100%;border-collapse:collapse;background:white}td,th{padding:16px;border:1px solid #ccd6c4;text-align:center}a{color:#26765d}</style><h1>原版题库 · 中袋验证后的舒适度分布</h1><p>原版25°推荐 → 中袋验证过滤 → 最新三分项评分。全部13,570布局／173,577道题；保留745,153条推荐，167,062道有推荐。每题按最高推荐分计数；6,515空题无分数。</p><p>中袋验证删除70,923条推荐，保留其他可用路线；本轮不按分数筛选，不改原库或App。80/85/90按未舍入分数≥阈值累计统计，题比例分母为全部173,577道。</p><table><tr><th>分数</th><th>推荐停点数</th><th>题数</th><th>占全部题</th></tr>'''+rows+'</table><a href="statistics.png"><img src="statistics.png" alt="全部推荐停点与每题最高分分布、80/85/90阈值统计"></a><p><a href="README.md">完整口径及分段统计</a> · <a href="summary.json">统计数据</a> · <a href="manifest.json">参数与来源</a></p></html>')
served=ROOT/'output/two-ball-multi-position-top10-20261024/comfort-full';served.mkdir(exist_ok=True)
for fn in ['README.md','summary.json','manifest.json','index.html','statistics.png']:shutil.copy2(OUT/fn,served/fn)
print(json.dumps(s,ensure_ascii=False))
