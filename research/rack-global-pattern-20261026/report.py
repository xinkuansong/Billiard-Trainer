from pathlib import Path
import json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle
from diagram import FONT,COLORS,LABELS,BALLS,axes_rack
from analyze import OUT,NOM,R,GROUPS,EDGES
D=json.loads((OUT/'discovery/summary.json').read_text());V=json.loads((OUT/'validation/summary.json').read_text());P=json.loads((OUT/'validation/protocol.json').read_text());variants=P['variants']; selected=variants[2:]
names={'baseline':'生产摆法','toward':'上次三球方案',selected[0]:'整阵方案 A',selected[1]:'整阵方案 B'}
def description(v):
 mask=int(v[1:]);return [('向来球侧' if mask&(1<<g) else '背离来球侧') if g not in (2,4) else ('向外' if mask&(1<<g) else '向内') for g in range(5)]
fig,axs=plt.subplots(1,2,figsize=(12,5))
for ax,v in zip(axs,selected):
 axes_rack(ax,names[v]+'（'+v+'）')
 for g,slots in enumerate(GROUPS):
  sign=1 if int(v[1:])&(1<<g) else -1
  for i in slots:
   delta=np.array([.019*sign,0]) if g not in (2,4) else np.array([0,.019*np.sign(NOM[i,1])*sign])
   ax.annotate('',xy=NOM[i]+delta,xytext=NOM[i],arrowprops=dict(arrowstyle='->',lw=1.8,color='#182c3b'))
fig.suptitle('复验方案：箭头是偏移方向，非真实位移大小',fontproperties=FONT,fontsize=14);fig.tight_layout();fig.savefig(OUT/'selected-patterns.png',dpi=180,bbox_inches='tight');plt.close(fig)
fig,axs=plt.subplots(1,3,figsize=(13,4));xx=np.arange(4);colors=['#758595','#cd9160','#c34e5c','#438eaa']
for ax,key,title in zip(axs,['mean','passRate','wallMeanMS'],['平均散开分','达到 1.20 的比例','单次物理计算平均耗时 / 毫秒']):
 vals=[V['variants'][v][key]*(100 if key=='passRate' else 1) for v in variants];ax.bar(xx,vals,color=colors)
 ax.set_xticks(xx,[names[v] for v in variants],fontproperties=FONT,rotation=20,ha='right');ax.set_title(title,fontproperties=FONT);ax.set_ylim(0,max(vals)*1.2)
 for i,a in enumerate(vals):ax.text(i,a,f'{a:.3f}' if key=='mean' else f'{a:.1f}'+('%' if key=='passRate' else ''),ha='center',va='bottom')
fig.suptitle('独立 1,000 副球阵复验：每副使用四种摆法',fontproperties=FONT,fontsize=14);fig.tight_layout();fig.savefig(OUT/'validation.png',dpi=180,bbox_inches='tight');plt.close(fig)
fig,axs=plt.subplots(1,2,figsize=(12,5))
keys=list(D['factorEffects']);vals=[D['factorEffects'][k]['mean'] for k in keys];cis=np.array([D['factorEffects'][k]['family95'] for k in keys]);axs[0].errorbar(vals,range(5),xerr=[np.array(vals)-cis[:,0],cis[:,1]-np.array(vals)],fmt='o',color='#246d8c',capsize=4);axs[0].set_yticks(range(5),[LABELS[i]+('：向外 减去 向内' if i in (2,4) else '：向前 减去 向后') for i in range(5)],fontproperties=FONT);axs[0].axvline(0,color='gray',lw=1);axs[0].set_title('筛选阶段区域平均影响（校正区间）',fontproperties=FONT)
for v,c in zip(variants,colors):axs[1].plot(range(15),V['variants'][v]['energyShares5'],marker='o',label=names[v],color=c)
axs[1].set_xticks(range(15),BALLS,rotation=60);axs[1].set_ylabel('5 毫秒时目标球平动能份额',fontproperties=FONT);axs[1].legend(prop=FONT);axs[1].set_title('能量分配仍需与最终效果分别检查',fontproperties=FONT)
fig.tight_layout();fig.savefig(OUT/'mechanisms.png',dpi=180,bbox_inches='tight');plt.close(fig)
lines=['# 全阵五区域摆球规律研究','', '完成 6,800 次筛选和 4,000 次独立复验，共 10,800 次，全部停稳。生产代码未改。','', '## 实验范围与预先规定','', '固定正中母球位置、瞄准实际顶球、杆速9.75和零旋转；0.20毫米名义间隙与0.09毫米偏移半径保持。世界XZ平面，+X朝来球侧。前端顶球移动时实际瞄准方向随其球心微量变化，不能称固定同一个方向向量。','', '五个不重叠区域覆盖15球。前端、内部、后排中间比较X偏移向前/向后，两侧和后排两角比较Z偏移向外/向内。折叠保留各球原偏移模长（Float舍入内），改变方向分布。只测试这一组结构化策略，不等于穷举全部球位关系。','', '200个新seed，每个32组合＋生产/旧三球两个对照。按平均分选前二，再用另外1000个新seed复验四方案；不从中挑高分球架。复验五个配对比较采用20,000次按球架bootstrap与Bonferroni家族95%区间。筛选阶段五主效应和十个二阶交互为探索性结果，另作15项校正。', '', '## 独立复验结果','', '|摆法|均分|中位数|P10|≥1.20|均耗时/P95 ms|近邻球数均值|', '|---|---:|---:|---:|---:|---:|---:|']
for v in variants:
 s=V['variants'][v];lines.append(f"|{names[v]} ({v})|{s['mean']:.6f}|{s['median']:.4f}|{s['p10']:.4f}|{s['passRate']:.1%}|{s['wallMeanMS']:.2f}/{s['wallP95MS']:.2f}|{s['closeBallMean']:.2f}|")
lines+=['','近邻球数：停球后存在球心距小于两个球直径的邻球的目标球数量；仅辅助描述局部聚集，不替代既有评分。耗时是本机模拟器四进程下BreakSimulator调用墙钟，任务随机交错；不包括摆球方向变换，未测真机。','','|配对比较|平均差|相对均分变化|家族95%区间|前500/后500平均差|','|---|---:|---:|---|---|']
for k,c in V['comparisons'].items():lines.append(f"|{k}|{c['mean']:+.6f}|{c['relativeMeanChange']:+.2%}|[{c['family95'][0]:+.6f}, {c['family95'][1]:+.6f}]|{c['halfMeans'][0]:+.4f}/{c['halfMeans'][1]:+.4f}|")
lines+=['','![复验](validation.png)','','## 候选整阵规律','', '|区域|方案 A|方案 B|','|---|---|---|']
for label,a,b in zip(LABELS,description(selected[0]),description(selected[1])):lines.append(f'|{label}|{a}|{b}|')
lines+=['','![候选方向](selected-patterns.png)','','方向均是相对于理想球位的微小随机偏移方向，不能解释成将整排移动一个球径。初始30条邻接边的实际均值及每球5毫秒能量份额见summary.json。方向相关的间隙增减由坐标距离计算，不能仅凭箭头声称所有相关边同时变小。','','## 区域主效应与交互（筛选阶段）','', '|区域：正方向−反方向|平均分影响|15项校正95%区间|','|---|---:|---|']
for i,(k,c) in enumerate(D['factorEffects'].items()):lines.append(f"|{LABELS[i]}|{c['mean']:+.6f}|[{c['family95'][0]:+.6f}, {c['family95'][1]:+.6f}]|")
lines+=['','二阶交互为差中差；正负仅在其余三个因素平均的意义上解释，不能当独立球级因果定律。','', '|交互|差中差|校正95%区间|','|---|---:|---|']
for k,c in sorted(D['interactions'].items(),key=lambda kv:-abs(kv[1]['mean'])):lines.append(f"|{k}|{c['mean']:+.6f}|[{c['family95'][0]:+.6f}, {c['family95'][1]:+.6f}]|")
lines+=['','![区域和能量](mechanisms.png)','','## 核验与边界','', f"- 全量重新计算终局分；输入、五区域方向变换、球号、母球/杆速/旋转、全部105球对间距均检查。复验最小初始净距 {V['audit']['gapMinMM']:.6f} 毫米，最大偏移 {V['audit']['maxOffsetMM']:.6f} 毫米。", '- 33项生产相关源码绑定前后未漂移；两轮各12个历史生产结果精确重放，新结果各12个确定性重放；所有worker退出0、设备关机并释放租约。工作区收尾见verification.json。', '- 本轮是现有生产模型中的摆法干预；没有在另一碰撞模型重跑，也不是现实球台实验。此前发现的接触阈值及事件顺序敏感性仍是外推限制。', '- 筛选样本排名有选择偏差；应以独立复验结论为准。即使早期能量覆盖改善，也不能直接断言最终散开一定更好。', '- 前后500只是预定一致性描述，不是再一次独立筛选或模型调整。图和统计脚本曾遇同名模块导入冲突，修正导入后运行；未改动协议、原始模拟数据和生产代码。', '', '## 文件','', '- discovery/protocol.json / summary.json / rows.json / raw-*.jsonl.gz', '- validation-plan.json / validation/protocol.json / summary.json / rows.json / raw-*.jsonl.gz', '- verification.json：独立标量复算、选择规则及资源审计', '- research/rack-global-pattern-20261026：研究入口、分析和绘图脚本', '']

conclusion=[
'**结论：扩展到整个球阵后，本轮没有找到经独立样本确认、稳定超过原生产或上次三球方案的新摆法。** 方案A平均分相对生产提高1.35%，但校正区间跨零；相对旧三球方案只提高0.33%，同样未确认。方案B相对生产为-0.08%。这只限制本轮五区域方向折叠策略，不证明所有全阵规律无效。',
'',
'筛选阶段A/B相对生产分别约+4.59%/+4.25%，独立复验明显缩水，不能用筛选排名代替可重复的改善。旧三球方案本轮+1.01%，也未单批确认；应与此前独立研究的小幅收益区分，不把任何一批当固定真实增益。',
'',
'**位置规律目前分两层：** 内部三球向前的平均效应在32组合中仍有支持；两侧四球向内在筛选中有信号，但没有针对该单一因素的独立验证。前端、后排中部、后排两角及10个二阶交互的校正区间均跨零，因此不能把前后排的某种配合宣布为已找到的稳定规律。',
'',
'**能量与最终散开并不等价。** 方案B在5毫秒时，内部三球平动能/入射母球平动能由1.010%升至1.380%（相对+36.7%），但最终均分没有提高。事后全阵诊断还发现，其20毫秒最近邻分离速度逐局中位数的均值由0.498升至0.546米/秒、最近邻间隙逐局下四分位数的均值由3.819升至4.231毫米，仍未转化为更高终局均分。早期多球分离改善本身不足以保证最终开散；具体后续抵消环节尚未定位。',
'',
'后续更值得测试的是30条邻接间隙的联合关系：保留同样偏移范围，让相邻球的偏移彼此配合，并用碰撞先后检查传递路径。当前没有执行该新策略，不能称已经找到最优摆法。',
'']
lines[4:4]=conclusion
whole=json.loads((OUT/'whole-separation.json').read_text())
lines+=['## 全阵相对分离补查（事后探索）','', '主复验结束后定义，只解释结果、不用于重新选择候选或宣称独立确认。每局先计算15球的最近邻分离速度中位数/下四分位数，再对1000局取均值；初始30邻接边按原身份跟踪。','', '|摆法|20ms最近邻分离速度中位数均值 m/s|20ms最近邻间隙下四分位均值 mm|5ms初始边仍接近的数量均值|','|---|---:|---:|---:|']
for v in variants:
 a=whole['variants'][v];lines.append(f"|{names[v]}|{a['20']['nearestOpeningMedian']:.4f}|{a['20']['nearestGapQ25MM']:.3f}|{a['5']['initialEdgeClosingCount']:.3f}|")
lines+=['','逐球架机制变化与得分变化的探索性相关均较弱，已计算指标绝对相关最大约0.121；不能认定任何一个早期指标已经解释终局改善。完整记录见whole-separation.json。','','## 初始30邻接边的实测变化','','![邻接边变化](gap-changes.png)','','红色表示相对生产平均间隙变小，蓝色表示变大。每个方案同时改变多条边，此图显示几何干预，不单独证明哪条边造成得分变化。']
(OUT/'REPORT.md').write_text('\n'.join(lines));print('Report and three figures generated.')
