from pathlib import Path
import json,csv,math,hashlib
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Rectangle
from matplotlib.font_manager import FontProperties,fontManager
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-pattern-5000-20261026'
font='/System/Library/Fonts/Hiragino Sans GB.ttc'
fontManager.addfont(font);plt.rcParams.update({'font.family':FontProperties(fname=font).get_name(),'axes.unicode_minus':False,'font.size':11,'figure.facecolor':'#f4f6f8','axes.facecolor':'#ffffff','savefig.facecolor':'#f4f6f8'})
a=json.loads((OUT/'analysis.json').read_text());features=json.loads((OUT/'features.json').read_text());specs=json.loads((OUT/'racks.json').read_text());protocol=json.loads((OUT/'protocol.json').read_text());meta=json.loads((OUT/'metadata.json').read_text());audit=json.loads((OUT/'audit.json').read_text())
raw={}
for p in OUT.glob('raw-*.jsonl'):
 for line in p.read_text().splitlines():
  r=json.loads(line);raw[(r['input']['rackID'],r['input']['position'])]=r
shots=list(csv.DictReader((OUT/'shots.csv').open()));score={(int(r['rackID']),r['position']):float(r['index']) for r in shots}
positions=[p['name'] for p in protocol['positions']];positionNames=['上侧较偏 -44.45cm','上侧中偏 -22.225cm','正中','下侧中偏 +22.225cm','下侧较偏 +44.45cm']
# Chart uses frozen holdout only for candidate comparison; main baseline all5000 separately labelled.
fig,axs=plt.subplots(1,2,figsize=(14,5.4));fig.suptitle('固定摆球参数：≥1.20 的概率与独立验证',fontsize=19,fontweight='bold')
base=a['baseline']['byPosition'];axs[0].bar(range(5),[p['rate']*100 for p in base],color='#278a80');axs[0].set_xticks(range(5),['-44.45','-22.225','0','+22.225','+44.45']);axs[0].set_xlabel('母球 Z 偏移（cm），每个位置1000局');axs[0].set_ylabel('分散指数≥1.20（%）');axs[0].set_title('全部5000局：开球位置影响')
for j,p in enumerate(base):axs[0].text(j,p['rate']*100+1,f"{p['rate']*100:.1f}%",ha='center')
axs[0].set_ylim(0,max(p['rate']*100 for p in base)*1.2+4)
cs=a['candidates'];x=np.arange(len(cs));width=.34
axs[1].bar(x-width/2,[c['holdoutOther']['rate']*100 for c in cs],width,label='其余球架',color='#a4afbd');axs[1].bar(x+width/2,[c['holdoutSelected']['rate']*100 for c in cs],width,label='符合候选规律',color='#e8aa45');axs[1].set_xticks(x,[c['id'] for c in cs]);axs[1].set_ylabel('分散指数≥1.20（%）');axs[1].set_title('仅独立验证：200副球架×5位置');axs[1].legend()
for j,c in enumerate(cs):axs[1].text(j,max(c['holdoutSelected']['rate'],c['holdoutOther']['rate'])*100+1,f"{c['holdoutDelta']*100:+.1f}个百分点\n选中{c['holdoutSelected']['racks']}副",ha='center',fontsize=10)
axs[1].set_ylim(0,max(max(c['holdoutSelected']['rate'],c['holdoutOther']['rate'])*100 for c in cs)*1.35+3)
for ax in axs:ax.spines[['top','right']].set_visible(False);ax.grid(axis='y',alpha=.15);ax.set_axisbelow(True)
fig.tight_layout(rect=[0,0,1,.93]);fig.savefig(OUT/'rates.png',dpi=160);plt.close(fig)
# Native geometry, nominal rack labels, highlighted candidate edges. Portrait mapping right=+Z, up=+X.
nom=np.array(features['nominal']);R=meta['radius'];fig,axes=plt.subplots(1,len(cs),figsize=(5*len(cs),5.8),squeeze=False)
fig.suptitle('候选规律涉及的位置（槽位编号，不是球号）',fontsize=18,fontweight='bold')
for ax,c in zip(axes[0],cs):
 highlighted=set()
 for condition in c['conditions']:
  f=features['features'][condition['feature']]
  if f['type']=='edge':highlighted.add(tuple(f['slots']))
  else:
   for idx in f.get('edgeIndices',[]):highlighted.add(tuple(features['edges'][idx]))
 for u,v in features['edges']:
  special=(u,v) in highlighted;ax.plot(nom[[u,v],1]*100,nom[[u,v],0]*100,color='#e77b2e' if special else '#bbc6cf',linewidth=3 if special else 1,zorder=4 if special else 1)
 for i,(xx,zz) in enumerate(nom):
  ax.add_patch(Circle((zz*100,xx*100),R*100,facecolor='#ffffff',edgecolor='#344d60',zorder=2));ax.text(zz*100,xx*100,features['labels'][i],ha='center',va='center',zorder=5,fontsize=10,bbox=dict(facecolor='white',edgecolor='none',pad=.5))
 ax.set_aspect('equal');ax.set_xlim(-16,16);ax.set_ylim(nom[:,0].min()*100-5,nom[:,0].max()*100+8);ax.annotate('母球来向',xy=(0,nom[0,0]*100+3),xytext=(0,nom[0,0]*100+7),ha='center',arrowprops=dict(arrowstyle='->'));ax.set_title(c['id']+' · '+('验证有正向证据' if c['positiveValidated'] else '未证实正向改善'));ax.set_xlabel('+Z 向右（cm）');ax.set_ylabel('+X 向上（cm）');ax.spines[['top','right']].set_visible(False)
fig.tight_layout(rect=[0,0,1,.92]);fig.savefig(OUT/'rack-rules.png',dpi=160);plt.close(fig)
# Actual holdout examples: selected median qualifying/failing indices, no synthetic replacement.
examples=[];pname='center';best=cs[0];eligible=[i for i in best['selectedRackIDs'] if specs[i]['split']=='holdout']
for success in [True,False]:
 ids=[i for i in eligible if (score[(i,pname)]>=1.2)==success]
 if ids:
  ids=sorted(ids,key=lambda i:score[(i,pname)]);examples.append(dict(rackID=ids[len(ids)//2],position=pname,success=success,rule=best['id']))
L,W=(meta[k] for k in ['length','width']);fig,axes=plt.subplots(len(examples),2,figsize=(13,4*len(examples)),squeeze=False)
fig.suptitle('同样符合R1，也会有开散与未开散：独立验证真实样本',fontsize=17,fontweight='bold')
for ri,e in enumerate(examples):
 row=raw[(e['rackID'],e['position'])];rack=row['rack'];p=np.array([[b['x'],b['z']] for b in rack]);ax=axes[ri,0]
 for k,(xx,zz) in enumerate(p):
  ax.add_patch(Circle((zz*100,xx*100),R*100,facecolor='white',edgecolor='#253c4e'));ax.text(zz*100,xx*100,features['labels'][k],ha='center',va='center',fontsize=9)
 ax.set_xlim(-16,16);ax.set_ylim(p[:,0].min()*100-5,p[:,0].max()*100+5);ax.set_aspect('equal');ax.set_title(f"球架 {e['rackID']:04d} · 初始摆球\n真实球径，缝隙肉眼不可辨；条件见正文");ax.set_xlabel('Z（cm）');ax.set_ylabel('X（cm）')
 ax=axes[ri,1];ax.set_facecolor('#344b47');ax.set_xlim(-L/2-.07,L/2+.07);ax.set_ylim(W/2+.07,-W/2-.07);ax.set_aspect('equal');ax.add_patch(Rectangle((-L/2,-W/2),L,W,facecolor='#1d6759',edgecolor='#a5c6b5'))
 for key,v in row['board'].items():
  xx=v[0]*L-L/2;zz=v[1]*L-W/2
  ax.add_patch(Circle((xx,zz),R,facecolor='#eae6d7' if key=='cueBall' else '#ffdd75',edgecolor='white',linewidth=.7));ax.text(xx,zz,'白' if key=='cueBall' else key[1:],ha='center',va='center',fontsize=7)
 ax.set_title(f"正中开球 · 指数 {score[(e['rackID'],e['position'])]:.3f} · {'达标' if e['success'] else '未达标'}\n目标球进袋 {len([k for k in row['pocketed'] if k!='cueBall'])} 颗");ax.set_xlabel('世界 X（m），右为+X');ax.set_ylabel('世界 Z（m），下为+Z')
fig.tight_layout(rect=[0,0,1,.94]);fig.savefig(OUT/'examples.png',dpi=160);plt.close(fig)
(OUT/'examples.json').write_text(json.dumps(examples,ensure_ascii=False,indent=2))
# Text report.
b=a['baseline'];lines=['# 摆球结构与开散概率：5000次开球分析','', '2026-10-26。生产代码和摆球参数未由本研究修改。1000副独立随机球架，每副5个固定母球位置；800副用于探索，200副用于独立验证。','',f"全部5000局中，指数≥1.20为 **{b['successes']}/5000（{b['rate']*100:.2f}%）**。按球架聚类的95%区间：{a['baselineClusterCI95'][0]*100:.2f}%～{a['baselineClusterCI95'][1]*100:.2f}%。",'', '本轮结论：三条候选均未在独立球架上验证出稳定的正向改善。在本次参数范围内，暂未找到可据此优化生产摆球的简单位置规律；这不等于证明球位之间不存在关系。','', '## 判据与边界','', '- 保持gap=0.20mm、每球独立圆盘偏移半径0.09mm、球号与随机算法、现有物理入口。','- 中八15球，中杆9.75m/s，母球X=L/4；Z为0、±22.225cm、±44.45cm，按真实球架瞄顶球。','- 评分仍为平均最近邻距离除以原固定校准分母，阈值1.20；按剩余目标球数查分母，进球局保留，母球不参与。不是题库零进球筛选。','- 5000是开球次数，独立球架只有1000；同架五局不跨探索/验证集，置信区间按球架而非5000独立样本计算。','- 本轮是现有随机摆球分布中的关联研究，不能把筛出的一类球架直接等同于修改某条缝隙后的因果收益。','- 预检5局、同输入重放20局另计，不进入5000局分析。','', '## 开球位置','', '| 母球Z偏移 | 达标局数/1000 | 达标率 | 平均指数 |','|---|---:|---:|---:|']
for name,p in zip(positionNames,b['byPosition']):lines.append(f"| {name} | {p['successes']} | {p['rate']*100:.2f}% | {p['meanIndex']:.3f} |")
lines+=['','![概率对比](rates.png)','','## 最多三条预先锁定的候选','',f"从探索集{a['features']}个初始几何特征、{a['selectionTrials']}个单条件试探与一棵最大深度2/最少100副叶节点树中选出候选。先写candidate-lock.json，随后才计算验证指标；没有按验证结果重新挑阈值。",'', '| 候选 | 探索：符合/其余 | 验证符合球架 | 验证：符合/其余 | 验证差值 | 同时置信区间 |','|---|---:|---:|---:|---:|---:|']
for c in cs:
 lo,hi=c['holdoutDeltaSimultaneousCI'];lines.append(f"| {c['id']} | {c['trainSelected']['rate']*100:.1f}% / {c['trainOther']['rate']*100:.1f}% | {c['holdoutSelected']['racks']}/200 | {c['holdoutSelected']['rate']*100:.1f}% / {c['holdoutOther']['rate']*100:.1f}% | {c['holdoutDelta']*100:+.1f}个百分点 | [{lo*100:+.1f}, {hi*100:+.1f}]个百分点 |")
lines+=['','区间为按球架分组重采样5000次的98.333%区间，以至多3个候选作Bonferroni控制；候选相互相关，不能相加。对比是符合条件的球架与不符合条件的球架。']
for c in cs:
 lines+=['',f"### {c['id']}：{c['description']}",'',f"结论：{'独立验证支持正向关联，但仍须干预实验确认因果。' if c['positiveValidated'] else '独立验证未证实稳定正向改善，不能据此修改摆球。'}",'', '| 开球位置 | 符合条件 | 其余球架 | 差值 |','|---|---:|---:|---:|']
 for name,s,o in zip(positionNames,c['holdoutSelected']['byPosition'],c['holdoutOther']['byPosition']):lines.append(f"| {name} | {s['rate']*100:.1f}% | {o['rate']*100:.1f}% | {(s['rate']-o['rate'])*100:+.1f}个百分点 |")
 lines += ['',f"验证集平均进球：符合{c['holdoutSelected']['meanPotted']:.2f}颗／其余{c['holdoutOther']['meanPotted']:.2f}颗；平均指数：{c['holdoutSelected']['meanIndex']:.3f}／{c['holdoutOther']['meanIndex']:.3f}。",'', '| 剩余目标球数 | 符合：局数/达标率 | 其余：局数/达标率 |','|---|---:|---:|']
 ss={x['remaining']:x for x in c['holdoutByRemainingSelected']};oo={x['remaining']:x for x in c['holdoutByRemainingOther']}
 for n in sorted(set(ss)|set(oo)):
  def cell(d):return f"{d['shots']} / {d['rate']*100:.1f}%" if d else '无样本'
  lines.append(f"| {n} | {cell(ss.get(n))} | {cell(oo.get(n))} |")
 lines+=['','剩余球数分层只是进球影响的敏感性诊断，小分层不作独立显著性结论，也不用于重新筛选候选。']
lines+=['','![槽位关系](rack-rules.png)','','A为顶排、B第二排……E底排；每排1号从+Z侧开始。图采用竖向表示：+X向上、+Z向右。字母数字是槽位，不是球号。橙色连线标识候选涉及的相邻球对，不代表球路；图按真实比例，不放大缝隙。','','![实际样本](examples.png)','','## 计算耗时','',f"本轮4原生进程并行，且同机另有计算任务。原生每局计时仅包围BreakSimulator完整调用，排除摆球生成和进程通信；不是单进程独占基准或真机耗时。",'',f"全部5000局：墙钟中位数 **{b['wallMedianMS']:.1f}ms**、P95 **{b['wallP95MS']:.1f}ms**、最慢 **{b['wallMaxMS']:.1f}ms**；进程CPU中位数 **{b['cpuMedianMS']:.1f}ms**、P95 **{b['cpuP95MS']:.1f}ms**。",'', '| 候选（验证集） | 墙钟中位数 符合/其余 | 墙钟P95 符合/其余 | CPU中位数 符合/其余 |','|---|---:|---:|---:|']
for c in cs:
 s,o=c['holdoutSelected'],c['holdoutOther'];lines.append(f"| {c['id']} | {s['wallMedianMS']:.1f}/{o['wallMedianMS']:.1f}ms | {s['wallP95MS']:.1f}/{o['wallP95MS']:.1f}ms | {s['cpuMedianMS']:.1f}/{o['cpuMedianMS']:.1f}ms |")
lines+=['','耗时分组是观察结果，不能据此保证改动缝隙后仍保持同样速度；后续干预需配对比较效果与耗时。','','## 审计与下一步','',f"5000局完整停稳且全部可评分；1000副每副5个位置、同架坐标一致、球号/数量/入袋集合/坐标有限性/不重叠、独立距离计算、探索验证隔离、20局同输入重放均核验。实际初始相邻缝隙{a['initialGapMM']['min']:.6f}～{a['initialGapMM']['max']:.6f}mm。",'', '- 当前建议维持生产摆球规则：三条候选均未通过独立验证，没有足够证据支持按它们调整球位。','- 本轮验证集中每条规则只覆盖20～37副球架，区间较宽；只能排除把探索集提升直接当成可靠结论，不能证明所有球位关系均无效。','- 如果继续研究，可先限定一个开球位置，并加入碰撞先后与能量传递记录，寻找可解释的局部结构，再用新球架验证；这部分尚未运行。','- 几何约束内的一次改动可能同时改变多条邻边，后续须记录全部邻边变化，不能把多处改变归因单条缝隙。','', '## 文件','', '- [冻结协议](protocol.json) / [输入](inputs.json) / [规则锁定](candidate-lock.json)','- [完整分析JSON](analysis.json) / [逐局表](shots.csv) / [全量审计](audit.json)','- [运行收尾](closure.json)；租约与构建目录回收另见外层生命周期回执。','- raw-0…3.jsonl保留全部原生输入/球架/终局/计时，不只保存达标局。']
(OUT/'REPORT.md').write_text('\n'.join(lines)+'\n')
print('Report and 3 figures written')
