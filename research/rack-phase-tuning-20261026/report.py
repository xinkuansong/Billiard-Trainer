from pathlib import Path
import json,hashlib
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-phase-tuning-20261026';HERE=Path(__file__).resolve().parent
D=json.loads((OUT/'discovery/summary.json').read_text());V=json.loads((OUT/'validation/summary.json').read_text());VER=json.loads((OUT/'verification.json').read_text())
FONT=FontProperties(fname='/System/Library/Fonts/Hiragino Sans GB.ttc');plt.rcParams['axes.unicode_minus']=False
labels={'baseline':'生产随机','radial_contract':'原共同向内','radial_pure':'纯向内',**{f'radial_band{i}':f'{15*i}–{15*i+15}°' for i in range(6)}}
vs=list(V['variants']);selected=vs[2:]
fig,axs=plt.subplots(1,3,figsize=(15,4.8),gridspec_kw={'width_ratios':[1.35,1,1]})
a=axs[0];dv=list(D['variants']);a.scatter([D['variants'][v]['mean'] for v in dv],range(len(dv)),s=65,c=['#8293a7' if v=='baseline' else '#2c8d88' if v=='radial_contract' else '#df995d' for v in dv]);a.set_yticks(range(len(dv)),[labels[v] for v in dv],fontproperties=FONT);a.invert_yaxis();a.set_xlim(.93,1.09);a.set_title('筛选：300副 × 9种',fontproperties=FONT);a.set_xlabel('平均散开分',fontproperties=FONT)
for j,v in enumerate(dv):a.text(D['variants'][v]['mean']+.002,j,f"{D['variants'][v]['mean']:.4f}",va='center',fontsize=9)
a=axs[1]
for j,v in enumerate(selected):
 c=V['comparisons'][v+'--radial_contract'];lo,hi=c['family95'];a.errorbar(c['mean'],j,xerr=[[c['mean']-lo],[hi-c['mean']]],fmt='o',color='#d47f42',capsize=5)
a.axvline(0,color='#697481',ls='--');a.set_yticks(range(len(selected)),[labels[v] for v in selected],fontproperties=FONT);a.invert_yaxis();a.set_title('复验：相对原共同向内的增益',fontproperties=FONT);a.set_xlabel('均分差；五对比校正区间',fontproperties=FONT)
a=axs[2];x=np.arange(len(vs));a.bar(x,[V['variants'][v]['scratch']*100 for v in vs],color=['#8293a7','#2c8d88','#df995d','#df995d']);a.set_xticks(x,[labels[v] for v in vs],fontproperties=FONT,rotation=20);a.set_ylabel('母球落袋率（%）',fontproperties=FONT);a.set_title('复验：1500副，各方案配对',fontproperties=FONT)
fig.suptitle('保留每球偏移长度，只调整整阵共同偏移角度',fontproperties=FONT,fontsize=16);fig.tight_layout(rect=(0,0,1,.93));fig.savefig(OUT/'phase-validation.png',dpi=160);plt.close(fig)
positive=[v for v in selected if V['comparisons'][v+'--radial_contract']['family95'][0]>0]
text=['# 开球摆球方向细化：8,700 次新模拟','',('本轮独立复验找到进一步均分改善：'+ '、'.join(labels[v] for v in positive)) if positive else '本轮没有证明进一步改善：筛选中领先的两个角度区间，在独立复验中均未稳定超过原共同向内方案。','', '已完成 300 副 × 9 种筛选、1,500 副 × 4 种独立复验；共 8,700 次正式模拟、1,800 新 seed，全部停稳。新 seed 与历史 7,700 副无重合。生产代码未由本任务修改。','', '## 独立复验结果','', '|摆法|平均散开分|≥1.20|母球落袋|物理均耗时 ms|CPU均耗时 ms|相邻平均间隙 mm|','|---|---:|---:|---:|---:|---:|---:|']
for v in vs:
 r=V['variants'][v];text.append(f"|{labels[v]}|{r['mean']:.6f}|{r['passRate']:.2%}|{r['scratch']:.2%}|{r['wallMeanMS']:.2f}|{r['cpuMS']:.2f}|{r['edgeGapMM']:.6f}|")
text+=['','均分为主指标；≥1.20 沿用旧阈值，仅作辅助。耗时是在同机四原生进程、随机交错任务下的物理调用耗时，不能当 iPhone 实机耗时。不同阶段环境负载不同，不跨阶段比较绝对耗时。','', '## 配对差值与不确定性','', '|对比|均分差|相对均分变化|五对比校正区间|前750/后750均分差|','|---|---:|---:|---|---|']
for key,c in V['comparisons'].items():
 v,ref=key.split('--');lo,hi=c['family95'];text.append(f"|{labels[v]} 减去 {labels[ref]}|{c['mean']:+.6f}|{c['relative']:+.2%}|[{lo:+.6f}, {hi:+.6f}]|{c['halfMeans'][0]:+.6f} / {c['halfMeans'][1]:+.6f}|")
text+=['','20,000 次按球形配对 bootstrap；预设五对比 Bonferroni 校正。候选仅按筛选均分选择，复验 seed 未参与选型。区间跨零意味着不能证明提高，不等于证明完全无效。','', '|对比|母球落袋差（百分点；校正区间）|≥1.20差（百分点；校正区间）|物理耗时差 ms（校正区间）|','|---|---|---|---|']
for key,c in V['comparisons'].items():
 v,ref=key.split('--');cells=[]
 for metric,mult in [('scratch',100),('pass',100),('wallMS',1)]:
  r=c[metric];lo,hi=r['family95'];cells.append(f"{r['mean']*mult:+.2f} [{lo*mult:+.2f}, {hi*mult:+.2f}]")
 text.append('|'+labels[v]+' 减去 '+labels[ref]+'|'+'|'.join(cells)+'|')
text+=['','以上每种指标各自校正五对比，未声称所有指标合起来整体95%。母球落袋差区间跨零不能证明同样安全。','', '## 与整个球阵相关的规律','', '本轮角度从各球指向名义球阵质心的方向量起；0° 纯向内，90° 纯切向。所有球共用角度大小和切向符号，各自保留原随机偏移长度。它改变原独立均匀角度分布，但没有修改 0.20mm 名义间距、0.09mm 最大随机半径，也没有模拟后筛球或重抽。','', '筛选中，纯向内的平均间隙最小，却不是散开分最高。这说明不能把优化目标简化为最大程度压紧球阵。独立复验是否支持角度细分，以上配对区间为准。','', '|摆法|5ms内部三球能量/入射能量|5ms能量有效球数|终局近邻球比例|终局最大团平均球数|','|---|---:|---:|---:|---:|']
for v in vs:
 r=V['variants'][v];text.append(f"|{labels[v]}|{r['internalEnergy5']:.3%}|{r['effectiveBalls5']:.3f}|{r['closeFraction']:.2%}|{r['largestGroup']:.3f}|")
text+=['','终局近邻定义为球心距 <4R（表面间距小于一个球直径），只作描述性诊断；并非修改散开评分。早期能量、接触先后和终局分布是不同量，以上统计不能单独证明因果传递路径。缺失20ms内首次冲量按删失记录，保留全部终局样本，不填零、不丢弃。','', '后续更值得检验的是分区域的相位关系：外围与内部是否需要不同方向、左右斜链是否应保留不同的错位。继续之前应承认本轮已检验的范围：这只是一种共同径向/切向参数化，未穷尽球阵位置规律，也没有证明物理上限。生产引擎既有近同时接触排序敏感性仍在，结果只支持当前引擎、固定正中力度条件。','', '## 全量筛选（探索性）','', '|摆法|平均分|≥1.20|母球落袋|','|---|---:|---:|---:|']
for v,r in D['variants'].items():text.append(f"|{labels[v]}|{r['mean']:.6f}|{r['passRate']:.2%}|{r['scratch']:.2%}|")
text+=['','## 核验和执行边界','', '- 全量8,700行已做独立标量评分复算、seed/配对完整性、停稳状态、坐标变换、原半径保持、球不重叠、固定击球条件和确定性重放核验。详见 verification.json、各阶段 summary.json。','- 复验与筛选使用相同冻结物理源与对象文件；当期33个相关源绑定逐个校验，仅两个精确审查例外：BreakFlowRunner 的 UI 授权回调、AngleSceneCalculator 的每日推荐排序代码块。均非研究调用路径。','- 筛选收尾时源码守卫因并发每日推荐代码变化返回1，原失败日志/closure未覆盖；2,700模拟与12条worker重放全部完成、worker正常退出、设备关机。post-run-review.json记录逐字审查与数据可用依据。该轮在审查后complete并回收；复验正常完成回收。','- 极小偏移的角度重建受Float舍入影响。ID7738的最小偏移约1微米，纯向内重建角0.0544°，坐标却与独立变换完全相同；取消不适定固定角度门槛，保留笛卡尔误差/半径/间隙审计，样本未删除。','- 共用设备仅借用后归还，保留原数据；没有生产App安装、发布、物理参数或评分修改。','', '![复验](phase-validation.png)','', '![方向示意](phase-directions.png)','']
(OUT/'REPORT.md').write_text('\n'.join(text));print('Report and plot saved; positive refinements:',positive)
