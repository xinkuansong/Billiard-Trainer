from pathlib import Path
import json,hashlib,math
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-regional-phase-20261026';HERE=Path(__file__).resolve().parent
D=json.loads((OUT/'discovery/summary.json').read_text());V=json.loads((OUT/'validation/summary.json').read_text());VER=json.loads((OUT/'verification.json').read_text())
FONT=FontProperties(fname='/System/Library/Fonts/Hiragino Sans GB.ttc');plt.rcParams['axes.unicode_minus']=False
labels={'baseline':'生产随机','radial_contract':'原共同向内'}
for region,name in [('core','内部'),('side','两侧'),('front','前排')]:
 for mode in ['M60','M30','P30','P60','Flip']:
  labels['radial_'+region+mode]=name+('切向反转' if mode=='Flip' else ('-' if mode[0]=='M' else '+')+mode[1:]+'°')
vs=list(V['variants']);selected=vs[2:];positive=[v for v in selected if V['comparisons'][v+'--radial_contract']['family95'][0]>0]
fig,axs=plt.subplots(1,3,figsize=(16,4.9),gridspec_kw={'width_ratios':[1.35,1,1]})
a=axs[0];heat=np.array([[D['variants']['radial_'+g+m]['mean']-D['variants']['radial_contract']['mean'] for m in ['M60','M30','P30','P60','Flip']] for g in ['core','side','front']]);a.imshow(heat,cmap='RdBu_r',vmin=-.06,vmax=.06,aspect='auto');a.set_yticks(range(3),['内部/外围','两侧','前/后排'],fontproperties=FONT);a.set_xticks(range(5),['-60°','-30°','+30°','+60°','反转'],fontproperties=FONT)
for i in range(3):
 for j in range(5):a.text(j,i,f'{heat[i,j]:+.3f}',ha='center',va='center',fontsize=11)
a.set_title('筛选300副：相对原共同向内的均分差',fontproperties=FONT);a.set_xlabel('相位变化在折向内之前施加',fontproperties=FONT)
a=axs[1]
for j,v in enumerate(selected):
 c=V['comparisons'][v+'--radial_contract'];lo,hi=c['family95'];a.errorbar(c['mean'],j,xerr=[[c['mean']-lo],[hi-c['mean']]],fmt='o',color='#d47f42',capsize=5)
a.axvline(0,color='#697481',ls='--');a.set_yticks(range(len(selected)),[labels[v] for v in selected],fontproperties=FONT);a.invert_yaxis();a.set_title('独立1500副：候选能否再提高',fontproperties=FONT);a.set_xlabel('均分差；五对比校正区间',fontproperties=FONT)
a=axs[2]
for j,v in enumerate(selected):
 c=V['comparisons'][v+'--radial_contract']['scratch'];lo,hi=c['family95'];a.errorbar(c['mean']*100,j,xerr=[[(c['mean']-lo)*100],[(hi-c['mean'])*100]],fmt='o',color='#2c8d88',capsize=5)
a.axvline(0,color='#697481',ls='--');a.set_yticks(range(len(selected)),[labels[v] for v in selected],fontproperties=FONT);a.invert_yaxis();a.set_title('独立复验：母球落袋率差',fontproperties=FONT);a.set_xlabel('相对原共同向内；百分点，负值更少',fontproperties=FONT)
fig.suptitle('区域之间的偏移配合：改变关联，保留每颗球的原偏移长度',fontproperties=FONT,fontsize=17);fig.tight_layout(rect=(0,0,1,.93));fig.savefig(OUT/'regional-validation.png',dpi=150);plt.close(fig)
text=['# 区域之间的摆球方向配合研究','',('新样本支持进一步均分改善：'+ '、'.join(labels[v] for v in positive)) if positive else '本轮两种区域候选均未证实进一步提高散开均分，但都减少了母球落袋；两侧-60°更值得保留为后续复验候选。不能据此声称已找到更容易开散的最优摆法。','', '共11,100次正式模拟：300副×17种=5,100次筛选；1,500副×4种=6,000次独立复验。1,800新seed与历史9,500个无重合。所有正式模拟停稳，独立评分复算及坐标/输入/重放审计完成。生产未由本任务修改。','', '## 独立复验结果','', '|摆法|均分|≥1.20|母球落袋率|平均物理耗时ms|P95物理ms|平均CPUms|','|---|---:|---:|---:|---:|---:|---:|']
for v in vs:
 r=V['variants'][v];text.append(f"|{labels[v]}|{r['mean']:.6f}|{r['passRate']:.2%}|{r['scratch']:.2%}|{r['wallMeanMS']:.2f}|{r['wallP95MS']:.2f}|{r['cpuMS']:.2f}|")
scratchSupported=[v for v in selected if V['comparisons'][v+'--radial_contract']['scratch']['family95'][1]<0]
text+=['', '本轮母球落袋减少得到独立复验支持的候选：'+ '、'.join(labels[v] for v in scratchSupported)+'。这是预设辅助指标中的结果，不能替代主指标“平均散开分进一步提高”。', '', '两侧-60°的均分和达标率观测值均高于原共同向内，且均分差在前后两半样本都为正，但校正区间仍跨零；优先保留它继续验证是候选选择，不是证明它最优。前排+60°的达标率观测值下降，因此不优先于两侧方案。']
text+=['','均分是主指标，不用1.20硬阈值替代它。物理耗时为同机四原生worker随机交错模拟，不是iPhone实机性能；不跨阶段比较绝对耗时。','', '|对比|均分差|相对均分变化|五对比校正区间|前750/后750均分差|','|---|---:|---:|---|---|']
for key,c in V['comparisons'].items():
 v,ref=key.split('--');lo,hi=c['family95'];text.append(f"|{labels[v]} 减去 {labels[ref]}|{c['mean']:+.6f}|{c['relative']:+.2%}|[{lo:+.6f},{hi:+.6f}]|{c['halfMeans'][0]:+.6f}/{c['halfMeans'][1]:+.6f}|")
text+=['','20,000次按球形配对bootstrap，预设五对比Bonferroni校正；区间跨零代表未证实改善，不代表证明严格等效。选择只用300副筛选，不在复验后改候选。','', '|对比|母球落袋差pp（校正区间）|≥1.20差pp（校正区间）|物理耗时差ms（校正区间）|','|---|---|---|---|']
for key,c in V['comparisons'].items():
 v,ref=key.split('--');cells=[]
 for metric,mult in [('scratch',100),('pass',100),('wallMS',1)]:
  r=c[metric];lo,hi=r['family95'];cells.append(f"{r['mean']*mult:+.2f} [{lo*mult:+.2f},{hi*mult:+.2f}]")
 text.append('|'+labels[v]+' 减去 '+labels[ref]+'|'+'|'.join(cells)+'|')
text+=['','不同指标分别校正五对比，没有跨全部指标的整体95%覆盖声明；落袋差区间跨零也不能证明无代价。','', '## 实际改变了什么','', '每副球形沿用原名义0.20mm间距、原圆盘随机偏移上限0.09mm，保留各球原偏移长度和球号。固定正中母球、瞄准实际顶球、力度9.75、零旋转。没有模拟后筛球、重抽或改变评分。','', '对每颗球建立以名义球阵质心向外为径向的局部坐标；将原偏移方向平均成共同方向。原共同向内直接把径向分量折向内。本轮先对不同区域旋转共同方向，或反转切向分量，再折向内。','', '- 内部三球：第三排中间球和第四排中间两球（slots4/7/8），对照外围12球。','- 前排：前三排6球，后排为最后两排9球。','- 两侧：名义+Z与-Z两侧，中线不转。两侧各转±半个标称角。','', '±30°、±60°是折向内前的相位偏移，不是最终任意两颗球的实际夹角。反转仅改变选中区域的切向分量。旋转/反射在理论上保留每颗球相同的向内角度边际分布，改变球与球之间的关联；1440方向网格验证分布一致，实际Float坐标另逐行审计。该角度规律仍不同于生产的独立均匀角度。','', '## 碰撞与终局诊断','', '|摆法|内三球平均首次冲量序号|20ms冲量事件数|5ms内部能量/入射能量|5ms能量有效球数|终局近邻球比例|最大团均球数|','|---|---:|---:|---:|---:|---:|---:|']
for v in vs:
 r=V['variants'][v];text.append(f"|{labels[v]}|{r['internalFirstOrder']:.3f}|{r['earlyJumpsMean']:.3f}|{r['internalEnergy5']:.3%}|{r['effectiveBalls5']:.3f}|{r['closeFraction']:.2%}|{r['largestGroup']:.3f}|")
text+=['','近邻定义为球心距<4R（表面间距小于一个球直径），仅作描述性辅助。20ms内未观察到首次冲量者作为删失，保留终局评分；内部首次序号只统计三球均观察到者，分母见summary。诊断变化不自动意味着能解释终局因果。','', '|摆法|全部相邻间隙mm|外围-外围mm|内部-外围mm|内部-内部mm|','|---|---:|---:|---:|---:|']
for v in vs:
 r=V['variants'][v];e=r['edgeGroupMeansMM'];text.append(f"|{labels[v]}|{r['edgeGapMM']:.6f}|{e['0']:.6f}|{e['1']:.6f}|{e['2']:.6f}|")
G=json.loads((OUT/'geometry-network.json').read_text())
text+=['','### 为什么平均间隙不够用','', '在理想三角球阵里，内部三球各有六个相邻球，六条连接方向的向量和为零。把相邻球心距作一阶展开，某颗内部球的微移对所有相邻间隙总和的贡献会抵消；它主要重新分配局部间隙，平均值几乎不变。', '', f"本轮300副的内部切向反转，相对共同向内：相邻平均间隙的平均变化只有 {G['meanExactMeanGapDeltaMM']:.8f} mm，单副最大绝对变化 {G['maxAbsExactMeanGapDeltaMM']:.8f} mm。独立一阶计算与二阶余项界逐条通过。", '', '这是一个经过数值核验的几何结论：平均紧密程度无法完整表示内部间隙结构。它不证明任何具体碰撞链更优；内部反转的散开得分下降仍只是筛选数据中的观察。']
text+=['','## 筛选全表（探索性）','', '|区域方案|均分|对原共同向内均分差|≥1.20|母球落袋|','|---|---:|---:|---:|---:|']
for v,r in D['variants'].items():text.append(f"|{labels[v]}|{r['mean']:.6f}|{r['mean']-D['variants']['radial_contract']['mean']:+.6f}|{r['passRate']:.2%}|{r['scratch']:.2%}|")
text+=['','三类切向反转方案筛选均偏低，这是“破坏共同关系可能有害”的线索；它们没有进入独立复验，不能把该观察写成已确认的物理定律。也不能从15种候选的结果推断所有区域组合都无效。','', '## 范围和证据','', '- 全量输入/坐标变换/每球半径/初始无重叠/计分/确定性重放已核；verify.py独立标量复算全部11100行，最大误差见verification.json。','- 与上轮使用相同冻结物理源和编译对象，33相关源绑定核验；当前唯一精确例外为BreakFlowRunner的UI授权回调，研究直接调用BreakSimulator，不经过该UI包装器。','- 正式两轮worker各exit0、关机成功，租约已归还、临时构建目录reclaimed；用户App和设备数据保留。','- 准备时旧每日排序例外已恢复原源，首次准备校验停下，缺协议命令exit1（未编译/开机/模拟），原证据保留在run c2f835ff2eda4d31959c8e889406c097并已complete回收。正式模拟未受影响。','- 离线几何预检发现side权重继承NumPy Float32，已改Double匹配原生算法；方向分布与已知样例随后通过，原生输入/模拟未改。','- 结果仅适用于当前引擎、固定正中力度条件；既有近同时接触顺序敏感性仍在。没有据此修改生产代码、评分、题库或物理参数，没有提交或发布。','', '![结果](regional-validation.png)','', '![方向](regional-directions.png)','']
(OUT/'REPORT.md').write_text('\n'.join(text));print('Report saved; further improvements supported:',positive)
