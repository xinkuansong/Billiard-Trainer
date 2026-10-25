"""Full source/output partition and independent vector score audit; review artifacts."""
from prepare import *
import collections,math,shutil
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import fontManager
def mouth_owner(i):
 if 6<=i<14:return [0,2,1,3][(i-6)//2]
 if 14<=i<18:return 4+(i-14)//2
 if 18<=i<38:return [3,2,1,0][(i-18)//5]
 if 38<=i<44:return 4+(i-38)//3
 if 44<=i<52:return [0,2,1,3][(i-44)//2]
 if 52<=i<56:return 4+(i-52)//2

def recompute(g,C,B,pockets):
 hx=g['length']/2;hz=g['width']/2;r=g['radius'];anchors=np.array([[-hx+r,-hz+r],[hx-r,-hz+r],[-hx+r,hz-r],[hx-r,hz-r],[0,-hz],[0,hz]])
 N=anchors[pockets]-B;N/=np.linalg.norm(N,axis=1)[:,None];V=B-2*r*N-C;L=np.linalg.norm(V,axis=1);back=-V/L[:,None]
 cut=np.degrees(np.arctan2(np.abs(V[:,0]*N[:,1]-V[:,1]*N[:,0]),np.sum(V*N,axis=1)));dist=np.linalg.norm(C-B,axis=1)
 direction=-N;bound=np.array([hx-r,hz-r]);ray=np.divide(np.where(direction>0,bound-B,-bound-B),direction,out=np.full_like(B,np.inf),where=np.abs(direction)>1e-12);depth=np.maximum(0,ray.min(axis=1));scale=np.clip(depth/.9,.4,1);lo=.5*scale;hi=.8*scale
 D=100*np.exp(-(np.maximum(lo-dist,0)/(.8*lo))**2-(np.maximum(dist-hi,0)/.75)**2)
 gaps=np.column_stack([hx-C[:,0]-r,hx+C[:,0]-r,hz-C[:,1]-r,hz+C[:,1]-r]);toward=np.column_stack([back[:,0],-back[:,0],back[:,1],-back[:,1]])
 pen=(45+15*np.maximum(toward,0)**2)*np.exp(-(np.maximum(gaps,0)*100/8)**1.2);axis=pen.argmax(axis=1);neighbor=np.where(axis<2,pen[:,2:].max(axis=1),pen[:,:2].max(axis=1));S=100-pen.max(axis=1)-np.minimum(8,.25*neighbor)
 A=100*np.exp(-(np.maximum(cut-15,0)/30)**2);T=np.cbrt(D*S*A)
 return np.column_stack([D,S,A,T])

def main():
 start=time.perf_counter();s=read(OUT/'summary-pending.json');manifest=read(OUT/'manifest.json');g=manifest['geometry'];proofs={p['key']:p for p in read(OUT/'entry-decisions.json')};ga=read(OUT/'geometry-audit.json');assert ga['passed'] and ga['proofsSHA256']==sha(OUT/'geometry-proofs.json')
 entry=read(OUT/'entry-audit.json');assert entry['passed'] and entry['noKnownDirectPotPairDeleted'] and entry['decisionSHA256']==sha(OUT/'entry-decisions.json')
 native={p['key']:p for p in read(OUT/'native-validation/proofs.json')};witnesses=read(OUT/'existing-pot-witnesses.json');raw={p['key']:p for p in read(OUT/'geometry-proofs.json')}
 assert entry['witnessSHA256']==sha(OUT/'existing-pot-witnesses.json') and entry['nativeProofsSHA256']==sha(OUT/'native-validation/proofs.json')
 for k,p in proofs.items():
  n=native.get(k);known=k in witnesses;positive=raw[k]['passed'] or (n is not None and n['passed']) or known;incomplete=n is not None and any(not t['settled'] for t in n['trials'])
  assert p['passed']==bool(positive or incomplete)
  if n:
   assert n['passed']==any(t['passed'] for t in n['trials'])
   assert 1<=len(n['trials'])<=5;lo=.5;hi=8.
   for t in n['trials']:
    assert abs(t['speed']-(lo+hi)/2)<1e-7
    if t['passed']:
     assert t['settled'] and t['route']=='direct-pot' and any(e['kind']=='pocket' and e['pocket']==f"pocket_{p['pocket']}" for e in t['events'])
     assert all(e['kind']!='cushion' or (e['index']>=6 and mouth_owner(e['index'])==p['pocket']) for e in t['events'])
    if t['feedback']=='probe-lower':hi=t['speed']
    elif t['feedback']=='short-increase':lo=t['speed']
 seen=set();bs=set();values=[];best=[];counts=collections.Counter();hist=collections.Counter();maxdiff=0;beforeValid=0;loss=0;byPart={x['stem']:x for x in manifest['schedule']};pairDecisions={}
 for part in read(OUT/'parts-index.json'):
  source=byPart[part['stem']];assert sha(Path(source['source']))==part['sourceSHA256']==source['sourceSHA256'];oldrows=rows(Path(source['source']));data={}
  for d in ['final','scores','deletions']:
   p=OUT/d/(part['stem']+'.jsonl.gz');assert sha(p)==part[d+'SHA256'];assert p.stat().st_size==part[d+'Bytes'];data[d]=rows(p)
  assert [r['id'] for r in oldrows]==part['layoutIDs']
  coords=[];balls=[];pockets=[];saved=[]
  for old,new,score,deleted in zip(oldrows,data['final'],data['scores'],data['deletions'],strict=True):
   assert old['id']==new['id']==score['id']==deleted['id'] and old['id'] not in seen;seen.add(old['id']);assert old['board']==new['board']
   originalroutes={r['comboIndex']:r for r in old['routes']};newroutes={r['comboIndex']:r for r in new['routes']};assert all(originalroutes[k]==r for k,r in newroutes.items());used=set()
   delmap={(d['cellID'],d['recommendation']['comboIndex'],d['recommendation']['pocket']):d for d in deleted['deleted']};assert len(delmap)==len(deleted['deleted']);delused=set()
   for oc,nc,sc in zip(old['candidates'],new['candidates'],score['candidates'],strict=True):
    assert oc['cellID']==nc['cellID']==sc['cellID'] and oc['position']==nc['position']==sc['position'];ident=(old['id'],oc['cellID']);assert ident not in bs;bs.add(ident);beforeValid+=bool(oc['top5'])
    expected=[]
    for q in oc['top5']:
     counts['before']+=1;middle=q['pocket'] in (4,5);pk=key(oc['position'],q['pocket']);ok=proofs[pk]['passed'] if middle else True
     if middle:
      counts['middleChecked']+=1
      if pk in pairDecisions:assert pairDecisions[pk]==ok
      pairDecisions[pk]=ok
     if ok:expected.append(q);counts['keptMiddle' if middle else 'unchangedCorner']+=1;counts['after']+=1
     else:
      k=(oc['cellID'],q['comboIndex'],q['pocket']);assert delmap[k]['recommendation']==q and delmap[k]['geometryProofKey']==pk;delused.add(k);counts['deletedMiddle']+=1
    assert nc['top5']==expected
    assert [(q['comboIndex'],q['pocket']) for q in expected]==[(q['comboIndex'],q['pocket']) for q in sc['recommendations']]
    rowvalues=[];hist[len(expected)]+=1;loss+=bool(oc['top5']) and not expected
    for q in sc['recommendations']:
     assert newroutes[q['comboIndex']]['cueStop']==q['stop'];used.add(q['comboIndex']);coords.append(q['stop']);balls.append(sc['position']);pockets.append(q['pocket']);saved.append([q[k] for k in ['distanceScore','spaceScore','angleScore','totalScore']]);values.append(q['totalScore']);rowvalues.append(q['totalScore'])
    assert sc['bestTotalScore']==max(rowvalues,default=None)
    if rowvalues:best.append(max(rowvalues))
   assert set(newroutes)==used and set(delmap)==delused
  if coords:
   calc=recompute(g,np.array(coords),np.array(balls),np.array(pockets));diff=float(np.max(np.abs(calc-np.array(saved))));maxdiff=max(maxdiff,diff);assert diff<1e-8 and np.all(np.isfinite(calc)) and np.all((calc>=0)&(calc<=100))
 assert len(seen)==13570 and len(bs)==173577 and dict(counts)==s['counts'] and len(best)==s['questionsWithRoutesAfter'] and beforeValid==s['questionsWithRoutesBefore'] and loss==s['questionsLostAllRoutes']
 assert {str(k):v for k,v in hist.items()}==s['recommendationCountHistogram'] and len(pairDecisions)==s['geometryUniquePairs']
 for vals,field in [(values,'routeScores'),(best,'questionBestScores')]:
  a=np.array(vals);assert np.histogram(a,bins=np.linspace(0,100,11))[0].tolist()==s[field]['histogram10']
  assert abs(float(a.mean())-s[field]['mean'])<1e-10
  for t in [80,85,90]:assert int(np.sum(a>=t))==s[field]['atLeast'][str(t)]
 for p,h in manifest['sourceHashes'].items():assert sha(Path(p))==h
 for p,h in read(OUT/'geometry-source.json')['sha256'].items():assert sha(Path(p))==h
 for p,h in read(OUT/'witness-source-hashes.json').items():assert sha(Path(p))==h
 for p,h in read(OUT/'native-source-hashes.json').items():assert sha(Path(p))==h
 closure=read(OUT/'closure.json');assert closure['allWorkersExited'] and closure['leaseReleased'] and closure['device']['state']=='Shutdown'
 s.update(state='complete',auditPassed=True,completedAt=time.time(),auditSeconds=time.perf_counter()-start,verification=dict(uniqueLayouts=len(seen),uniqueB=len(bs),sourceAndOutputSHA256=True,allKeptRecommendationFieldsAndOrderUnchanged=True,allKeptTrajectoriesUnchanged=True,deletedAndRetainedPartition=True,allBPairDecisionsShared=True,allScoresIndependentlyRecomputed=len(values),maxScoreDifference=maxdiff,geometryAudit=ga))
 write(OUT/'summary.json',s);write(OUT/'progress.json',dict(state='complete',auditPassed=True))
 render(s,g,list(raw.values()))
 print(json.dumps(s,ensure_ascii=False))

def render(s,g,proofs):
 fontManager.addfont('/Library/Fonts/Arial Unicode.ttf');plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
 fig,axes=plt.subplots(2,2,figsize=(14,10),facecolor='#f6f8f1');edges=np.arange(0,101,10)
 for ax,field,title,color in [(axes[0,0],'routeScores','保留推荐停点分布','#1683ac'),(axes[0,1],'questionBestScores','每道题最高分分布','#258c67')]:
  ax.bar(edges[:-1]+5,s[field]['histogram10'],width=9,color=color);ax.set(title=f'{title} · {s[field]["count"]:,}',xlabel='舒适度总分',ylabel='数量',xticks=edges);ax.grid(axis='y',alpha=.2)
 for ax,field,title,color in [(axes[1,0],'routeScores','达到阈值的推荐停点','#1683ac'),(axes[1,1],'questionBestScores','至少一个停点达到阈值的题','#258c67')]:
  vals=[s[field]['atLeast'][str(t)] for t in [80,85,90]];ax.bar(['≥80','≥85','≥90'],vals,color=color);ax.set_title(title);ax.margins(y=.2)
  for i,v in enumerate(vals):ax.text(i,v,f'{v:,}',ha='center',va='bottom',fontsize=12)
 fig.suptitle('原版题库 · 按 B＋中袋入袋核验后的舒适度',fontsize=19)
 fig.text(.5,.02,f'删除 {s["counts"]["deletedMiddle"]:,} 条中袋推荐；{s["questionsWithoutRoutes"]:,} 个空题无分数。三个分项公式保持不变；不按分数筛选。',ha='center',fontsize=11)
 fig.tight_layout(rect=[0,.04,1,.95]);fig.savefig(OUT/'statistics.png',dpi=150);plt.close(fig)
 # Deterministic boundary examples: blocked rays and adjacent clear directions.
 for p in proofs:
  d=p['direction'];p['entryAngleDegrees']=math.degrees(math.atan2(abs(d[1]),abs(d[0])))
 decision={p['key']:p for p in read(OUT/'entry-decisions.json')}
 blocked=sorted([p for p in proofs if not decision[p['key']]['passed'] and p['pocket']==4],key=lambda p:p['entryAngleDegrees']);clear=sorted([p for p in proofs if p['passed'] and p['pocket']==4],key=lambda p:p['entryAngleDegrees'])
 examples=[blocked[len(blocked)//4],blocked[len(blocked)//2],blocked[-1],clear[0],clear[len(clear)//4],clear[-1]]
 fig,axes=plt.subplots(2,3,figsize=(15,9),facecolor='#f6f8f1');hx=g['length']/2;hz=g['width']/2
 for ax,p in zip(axes.flat,examples):
  ax.set_facecolor('#dcebd7')
  for line in g['lines']:
   a=line['start'];b=line['end'];ax.plot([a['x'],b['x']],[a['z'],b['z']],color='#234e41',lw=2)
  for arc in g['arcs']:
   start=arc['start'];end=arc['end'];end+=2*math.pi if end<start else 0;angles=np.linspace(start,end,60);ax.plot(arc['center']['x']+arc['radius']*np.cos(angles),arc['center']['z']+arc['radius']*np.sin(angles),color='#234e41',lw=2)
  for pocket in g['pockets']:
   lip=np.array([[v['x'],v['z']] for v in pocket['lip']]);ax.fill(lip[:,0],lip[:,1],color='#99bbaa');ax.add_patch(plt.Circle((pocket['center']['x'],pocket['center']['z']),pocket['radius'],color='#234e41'))
  b=np.array(p['object']);d=np.array(p['direction']);travel=p.get('captureDistance',math.dist(p['object'],p['aim']));end=b+d*travel;color='#1d9366' if p['passed'] else '#cb573e';ax.plot([b[0],end[0]],[b[1],end[1]],color=color,ls='--');ax.add_patch(plt.Circle(b,g['radius'],color='#178bb5'))
  if not p['passed']:
   hit=b+d*p['solidDistance'];ax.add_patch(plt.Circle(hit,g['radius'],fill=False,color='#cb573e',lw=1.4));ax.scatter(*hit,color='#cb573e',s=12)
  ax.set(xlim=(-hx-.12,hx+.12),ylim=(hz+.13,-hz-.13),title=f'{"保留" if p["passed"] else "删除"} · 与长库夹角 {p["entryAngleDegrees"]:.1f}°');ax.set_aspect('equal');ax.set_xticks([]);ax.set_yticks([])
 fig.suptitle('B 到上中袋：指定方向的几何检查示例\n蓝球为 B；红色空心球为到达袋口前的首个碰壁位置，不含母球停点',fontsize=15);fig.subplots_adjust(left=.015,right=.985,bottom=.02,top=.84,wspace=.04,hspace=.25);fig.savefig(OUT/'geometry-examples.png',dpi=150);plt.close(fig)
 write(OUT/'geometry-examples.json',examples)
 thresholds='\n'.join(f'| ≥{t} | {s["routeScores"]["atLeast"][str(t)]:,} | {s["questionBestScores"]["atLeast"][str(t)]:,} | {s["questionBestScores"]["atLeast"][str(t)]/173577:.2%} |' for t in [80,85,90])
 bins='\n'.join(f'| {i*10}–{(i+1)*10} | {s["routeScores"]["histogram10"][i]:,} | {s["questionBestScores"]["histogram10"][i]:,} |' for i in range(10))
 readme=f'''# 原版两球题库：B＋中袋几何过滤与舒适度统计

本轮从 `output/two-ball-refine-full-20261025/final/` 原25°版的816,076条推荐重新出发，未使用上轮70,923条删除结果作为输入。原文件及App未改。

## 判定口径

输入只含第二球B坐标和原选袋口。复用2D准度生成器 `GridGeometry.cleanObjectPath`：B沿原中袋生成瞄点(0,±W/2)方向，射线延伸至实际实测口沿多边形与深部捕获圆的并集；球半径完整保留，检查有限主库、袋角直线/圆弧与端点是否先挡住球体。4×Float.ulpOfOne沿用原接触容差。

几何无阻挡的对保留；对射线受阻的B＋中袋，补做**B单独运动的原生入袋核验**（固定原方向、零自旋、0.5–8速度范围自适应至多5次）。沿用准度的直进语义：允许本袋正常袋角接触，排除主库反弹或其他袋口。模拟中没有母球，工程入口的球名cueBall仅代表本次唯一的B。已有证据里只要B曾直接入指定袋，也作为该B＋袋口可用的正例保护，忽略当时母球落袋与否。未完成的核验保守保留，不当失败删除。

最终只有几何射线受阻、单球核验未直进、且没有既有目标球直进正例的B＋中袋对删除其全部推荐；角袋和其他推荐不动，不改目标袋、不补足5条。这与母球停点无关；但有限力度核验仍不是所有速度/瞄点/旋转打法均不可进的数学证明。`diagnostic-pure-ray/`仅是被发现会误删正常袋角入袋的初步试算，不是本次结果。

不使用第一杆停点、母球落袋或球杆可达性作为删除条件。母球停点只参与后续舒适度评分。

## 删除与题数

- 原中袋357,711条，删除 **{s['counts']['deletedMiddle']:,}**，保留 **{s['counts']['keptMiddle']:,}**；角袋458,365条全部保留。
- 总推荐816,076 → **{s['counts']['after']:,}**。
- {s['geometryUniquePairs']:,}个精确不同的B坐标＋中袋对，{s['geometryBlockedUniquePairs']:,}对几何射线受阻，补验后最终删除{s['entryRejectedUniquePairs']:,}对；按题身份统计受影响B＋袋口为{s['removedQuestionPocketPairs']:,}对。
- 有推荐题170,445 → **{s['questionsWithRoutesAfter']:,}**；{s['questionsLostAllRoutes']:,}题失去最后一条推荐。原3,132空题加本次新增，共{s['questionsWithoutRoutes']:,}空题，保留空记录而不记0分。
- 全部布局13,570、B题173,577，唯一性和输入/输出SHA全量核验。

## 舒适度分布

球距放缓v2＋出杆空间v3＋角度0–15°满分/30°下降尺度；等权几何平均。每题=(布局id,B cellID)，题分为保留推荐最高总分。以下≥阈值用未舍入分数、累计包含，不能相加。不按舒适度删题。

| 阈值 | 推荐停点数 | 题数 | 占全部173,577题 |
|---|---:|---:|---:|
{thresholds}

| 分数段（右端不含，最后含100） | 推荐停点数 | 题最高分数 |
|---|---:|---:|
{bins}

推荐均分{s['routeScores']['mean']:.2f}，中位数{s['routeScores']['percentiles']['50']:.2f}；有推荐题最高分均值{s['questionBestScores']['mean']:.2f}，中位数{s['questionBestScores']['percentiles']['50']:.2f}。

![统计](statistics.png)
![几何检查示例](geometry-examples.png)

## 文件与验证

- `final/*.jsonl.gz`：过滤后题库，保留原球位、推荐参数/顺序、实际轨迹；只删除不合格引用和无引用的轨迹，原统计放originalStats以免混淆。
- `scores/*.jsonl.gz`：各保留停点三个分项与总分；按id/cellID/comboIndex/pocket关联final。
- `deletions/*.jsonl.gz`：删除推荐原记录及几何证明key。
- `geometry-proofs.json`与`requests.json`：逐B/中袋几何证据；`entry-decisions.json`最终决定；`native-validation/`单球物理核验；`existing-pot-witnesses.json`既有直进正例；`geometry-source.json`绑定原Swift几何代码、适配器和数据源。
- `parts-index.json`：三类分片大小及SHA；`manifest.json`：来源、政策；`summary.json`：全量统计。
- 原Swift几何谓词与独立NumPy实现对拍{s['geometryUniquePairs']:,}对、双轴镜像及标准样例；{s['counts']['after']:,}个分数独立复算最大差{s['verification']['maxScoreDifference']:.3g}，全部原推荐保留/删除分区、库坐标、轨迹与字段逐项读回通过。
- gzip：题库{s['gzipBytes']['final']/1e6:.2f} MB，评分{s['gzipBytes']['scores']/1e6:.2f} MB，删除记录{s['gzipBytes']['deletions']/1e6:.2f} MB。过滤评分{s['filterAndScoreSeconds']:.2f}秒；全量读回审计{s['auditSeconds']:.2f}秒；前置几何另见geometry-audit.json。

上轮基于母球停点的过滤结果仍保留作历史，本轮不继承其删除决定，只复用目标球实际直进的正例证据；交叉数量见summary.priorFilterComparison。分数是当前经验评分，不是进球概率。8个原生单球核验进程通过共享large-phone租约运行，结束关机归还；未重新计算首杆、未改App消费端。
'''
 (OUT/'README.md').write_text(readme)
 table=''.join(f'<tr><td>≥{t}</td><td>{s["routeScores"]["atLeast"][str(t)]:,}</td><td>{s["questionBestScores"]["atLeast"][str(t)]:,}</td><td>{s["questionBestScores"]["atLeast"][str(t)]/173577:.2%}</td></tr>' for t in [80,85,90])
 html=f'''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>B＋中袋几何过滤 · 舒适度</title><style>body{{max-width:1250px;margin:32px auto;padding:20px;background:#f6f8f1;color:#243f32;font:18px system-ui}}p{{line-height:1.8}}img{{width:100%}}table{{width:100%;border-collapse:collapse;background:white}}td,th{{padding:16px;border:1px solid #ccd6c4;text-align:center}}a{{color:#26765d}}</style><h1>原版题库 · B＋中袋几何过滤</h1><p>仅按第二球位置与原目标中袋方向检查实际袋口几何。删除 <b>{s['counts']['deletedMiddle']:,}</b> 条中袋推荐，总保留 <b>{s['counts']['after']:,}</b> 条；<b>{s['questionsWithRoutesAfter']:,}</b> 道题仍有推荐，{s['questionsWithoutRoutes']:,} 道为空。来源为原25°版，原库保留。</p><p>几何受阻的B＋中袋已补做单球入袋核验，允许本袋正常袋角接触，并保留已有实际直进正例；最多5次力度失败不等于全参数数学无解。与上轮“从母球停点试打”的删除规则分开。评分仍为球距放缓版、空间最新版、角度15°平台；不按分数筛选。</p><table><tr><th>分数</th><th>推荐停点</th><th>题数（至少一个停点达标）</th><th>占全部题</th></tr>{table}</table><p>题数分母173,577；阈值为累计≥，空题无分数。</p><img src="statistics.png" alt="舒适度全量分布"><img src="geometry-examples.png" alt="中袋几何检查示例"><p><a href="README.md">完整报告及口径</a> · <a href="summary.json">统计数据</a> · <a href="manifest.json">来源与规则</a></p></html>'''
 (OUT/'index.html').write_text(html)
 served=ROOT/'output/two-ball-multi-position-top10-20261024/comfort-middle-geometry';served.mkdir(exist_ok=True)
 for name in ['index.html','README.md','summary.json','manifest.json','statistics.png','geometry-examples.png']:shutil.copy2(OUT/name,served/name)
if __name__=='__main__':main()
