from pathlib import Path
import json,hashlib,math,gzip
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
from analyze import ROOT,OUT,L,R,INS

font_manager.fontManager.addfont('/System/Library/Fonts/Hiragino Sans GB.ttc')
plt.rcParams.update({'font.family':'Hiragino Sans GB','axes.unicode_minus':False,'font.size':11,'font.weight':300,'axes.labelweight':300,'axes.titleweight':300})
a=json.loads((OUT/'analysis.json').read_text())
p=json.loads((OUT/'paired-analysis.json').read_text())
c=json.loads((OUT/'control-analysis.json').read_text())
labels=['生产原摆法','内部三球偏向来球','内部三球背离来球'];variants=['baseline','toward','away']
colors=['#637080','#197a70','#c37b36']
fig,axs=plt.subplots(2,2,figsize=(13,9),layout='constrained')
for dataset,label,marker,color in [(p,'当前生产引擎','o','#197a70'),(c,'顺序控制研究模型','s','#a35a42')]:
    vs=dataset['cohorts']['all1000']
    xx=np.arange(3)+(0 if dataset is p else .10)
    axs[0,0].plot(xx,[vs[v]['mean'] for v in variants],marker=marker,label=label,color=color)
    for x,v in zip(xx,variants):axs[0,0].annotate(f"{vs[v]['mean']:.4f}",(x,vs[v]['mean']),xytext=(0,8 if dataset is p else -17),textcoords='offset points',ha='center',color=color)
axs[0,0].set(xticks=range(3),xticklabels=labels,ylabel='最终平均散开分',title='同一批 1,000 副球架，分别在各模型内配对')
axs[0,0].set_ylim(.735,1.025)
axs[0,0].legend(loc='best',fontsize=9)
vs=p['cohorts']['all1000']
for i,v in enumerate(variants[1:]):
    rr=vs[v]['scoreDelta'];m=rr['mean'];lo,hi=rr['family95']
    axs[0,1].errorbar(m,i,xerr=[[m-lo],[hi-m]],fmt='o',capsize=5,color=colors[i+1])
axs[0,1].axvline(0,color='#888',lw=1)
axs[0,1].set(yticks=[0,1],yticklabels=labels[1:],xlabel='相对同球架原摆法的平均分变化',title='生产引擎：两项比较校正后的 95% 区间')
for i,v in enumerate(variants):
    n=vs[v]['mechanisms']['interiorEnergyFraction']*100
    axs[1,0].bar(i,n,color=colors[i],width=.55)
    axs[1,0].text(i,n+.025,f'{n:.3f}%',ha='center')
axs[1,0].set(xticks=range(3),xticklabels=labels,ylabel='内部三球平动能 / 入射母球平动能（%）',title='首碰后 5 ms：内部三球获得多少能量')
for i,v in enumerate(variants):
    n=vs[v]['mechanisms']['interiorMinOpening']
    axs[1,1].bar(i,n,color=colors[i],width=.55)
    axs[1,1].text(i,n+.003,f'{n:.3f}',ha='center')
axs[1,1].set(xticks=range(3),xticklabels=labels,ylabel='各副最慢内部球的邻球分离速度均值（m/s）',title='首碰后 5 ms：检查分离最差的内部球')
for ax in axs.flat:ax.spines[['top','right']].set_visible(False);ax.grid(axis='y',alpha=.15)
fig.suptitle('开散研究：能量覆盖、局部分离与最终得分',fontsize=18)
fig.savefig(OUT/'comparison.png',dpi=170,bbox_inches='tight');plt.close(fig)

# Exact input offsets in micrometres, separate from the much larger rack geometry.
example={}
for file in sorted((OUT/'paired').glob('raw-*.jsonl.gz')):
    with gzip.open(file,'rt') as f:
        for line in f:
            r=json.loads(line)
            if r['input']['rackID']==2200:example[r['input']['variant']]=r
s=np.float32(np.float32(R)*2+np.float32(.0002));step=np.float32(s*np.sqrt(np.float32(3))/2)
nom=np.array([[np.float32(-np.float32(L)/4-np.float32(rr)*step),np.float32((np.float32(rr)/2-np.float32(cc))*s)] for rr in range(5) for cc in range(rr+1)],dtype=float)
fig,axs=plt.subplots(1,3,figsize=(11,4.2),layout='constrained')
for ax,slot,label in zip(axs,INS,['C2','D2','D3']):
    ax.add_patch(plt.Circle((0,0),90,fill=False,color='#888',linestyle='--'))
    for variant,color,marker in zip(variants,colors,['o','>','<']):
        b=example[variant]['rack'][slot];xy=(np.array([b['x'],b['z']])-nom[slot])*1e6
        ax.scatter(*xy,color=color,marker=marker,s=100,label=labels[variants.index(variant)],alpha=.8)
    ax.axvline(0,color='#ddd');ax.axhline(0,color='#ddd');ax.set(xlim=(-100,100),ylim=(-100,100),aspect='equal',title=label,xlabel='X 偏移（微米）；向右为来球方向',ylabel='Z 偏移（微米）')
axs[0].legend(fontsize=8,loc='lower left')
fig.suptitle('2200 号球架的实际偏移：只翻转 X 符号，半径与 Z 不变',fontsize=14)
fig.savefig(OUT/'offsets.png',dpi=170,bbox_inches='tight');plt.close(fig)

def table(dataset):
    lines=['| 摆法 | 平均散开分 | 相对原摆法 | 配对差校正95%区间 | ≥1.2 | 平均/P95耗时 ms |','|---|---:|---:|---|---:|---:|']
    for label,v in zip(labels,variants):
        r=dataset['cohorts']['all1000'][v];lo,hi=r['scoreDelta']['family95']
        lines.append(f"| {label} | {r['mean']:.6f} | {100*r['relativeMeanChange']:+.2f}% | {'—' if v=='baseline' else f'[{lo:+.5f}, {hi:+.5f}]'} | {100*r['passRate']:.1f}% | {r['wallMeanMS']:.2f} / {r['wallP95MS']:.2f} |")
    return '\n'.join(lines)

text=f'''# 开球能量覆盖与内部球分离研究

日期：2026-10-26。状态：2200 次既有记录回顾分析完成；1000 副全新球架 × 3 摆法 × 2 模型，共 6000 次完整开球完成。生产代码、物理常量和生产摆球生成器未修改。

结论：发现一条有重复证据的小幅改善候选——在原有偏移半径内，将内部三球的前后偏移定向到来球一侧。当前生产引擎平均分提升{p['cohorts']['all1000']['toward']['relativeMeanChange']*100:.2f}%，研究控制模型提升{c['cohorts']['all1000']['toward']['relativeMeanChange']*100:.2f}%，两者配对区间均为正。能量覆盖和内部球分离同时改善，支持用户假设的一部分，但逐局关联很弱，尚不能证明“能量越均匀，最终一定越散”，也未获准接入生产。

## 问题与口径

用户假设：让更多球获得母球传入的能量，并让内部球真正分离，可能使最终球形更散。主指标沿用已有逐局最近邻散开分的平均值，1.20 合格率仅作辅助。不同摆法必须与同一批、同一球架的原摆法配对比较，不能拿新批候选均值直接减旧批均值。

已有 2200 副生产样本均值 {a['all']['mean']:.6f}；本轮新 1000 副生产基线 {p['cohorts']['all1000']['baseline']['mean']:.6f}，这是抽样差异，不是代码变化。新样本 seed 与旧 2200 副无重复。

## 先做回顾分析

在第一批1000副上固定5ms指标的20%/80%分位阈值，原样用于其后1000、副批200和本轮全新1000副。此前样本已分析过其他问题，明确属于回顾分析，不称新盲测。

四项预先固定指标：能量有效球数 `N_eff=(ΣE)^2/Σ(E²)`、内部三球平动能/入射母球能、内部三球中最小的最近邻分离速度、内部三球中最小的最近邻球面净距。内部三球固定C2/D2/D3；1和20ms为时间敏感性分析。

旧批各指标总体是弱正相关，第二批1000副Spearman约0.05–0.09。新1000副按旧阈值分组，高组均值仍全部高于低组，但四项比较校正后的区间全部包含0。故相关性不足以证明因果或作为可靠的单局预测器。

| 新1000副生产基线的5ms指标 | 低组平均分 | 高组平均分 | 高减低校正95%区间 |
|---|---:|---:|---|
'''
for name,label in zip(['effectiveBalls','interiorEnergyFraction','interiorMinOpening','interiorMinGap'],['能量有效球数','内部球能量/入射能','最慢内部球的邻球分离速度','最挤内部球的邻球净距']):
    rr=p['thresholdComparisons'][name];lo,hi=rr['family95']
    text+=f"| {label} | {rr['low']['mean']:.4f} | {rr['high']['mean']:.4f} | [{lo:+.4f}, {hi:+.4f}] |\n"
text+='''
## 局部球位干预

每副先调用未改动的生产RackLayout.make，保留球号、其余12颗目标球、母球、瞄向、杆速9.75、零旋转及物理代码。研究版本只把C2/D2/D3相对标准球位的X偏移改为+abs(dx)或-abs(dx)，Z与偏移幅度保持。+X指向来球，因此“偏向来球”平均缩小前排来球间隙、增大后排出球间隙。内部球之间的共享边不能假定每条都同向变化，统计使用实际球位计算。

名义间隙0.20mm、最大偏移0.09mm保持；定向折叠会改变随机方向的分布，是研究干预，不冒称生产原随机规律完全不变，也没有按开球得分筛选球架。1000副、两项干预及分析规则在模拟前锁定；前后500副都报告，无中途选优或调参。

![真实偏移示例](offsets.png)

## 当前生产引擎下的结果

'''+table(p)+'\n\n'
v=p['cohorts']['all1000'];base=v['baseline'];tow=v['toward'];away=v['away']
text+=f'''偏向来球的平均分提高 {tow['scoreDelta']['mean']:.6f}（{tow['relativeMeanChange']*100:.2f}%），前500副{p['cohorts']['first500']['toward']['relativeMeanChange']*100:+.2f}%、后500副{p['cohorts']['second500']['toward']['relativeMeanChange']*100:+.2f}%。两半结果仅用于一致性检查，不视为另外两个独立预注册试验。背离来球未证实平均分提高，尽管其≥1.2比例更高，说明只看阈值会得出不同排序。

| 5ms机制指标 | 原摆法 | 偏向来球 | 背离来球 |
|---|---:|---:|---:|
'''
for n,label,mult in [('effectiveBalls','能量有效球数',1),('interiorEnergyFraction','内部三球/入射能量（%）',100),('objectEnergyFraction','全部目标球/入射能量（%）',100),('cornerShare','两底角/目标球能量（%）',100),('interiorMinOpening','最慢内部球邻球分离速度均值（m/s）',1),('interiorMinGap','最挤内部球邻球净距均值（mm）',1)]:
    text+='| '+label+' | '+' | '.join(f"{v[k]['mechanisms'][n]*mult:.4f}" for k in variants)+' |\n'
text+=f'''
偏向来球组的平均前侧间隙由 {base['initialGeometry']['incomingGapMM']:.4f}mm 变为 {tow['initialGeometry']['incomingGapMM']:.4f}mm，后侧由 {base['initialGeometry']['outgoingGapMM']:.4f}mm 变为 {tow['initialGeometry']['outgoingGapMM']:.4f}mm。

上述四项主要机制指标的配对均值改善在8项机制比较校正后仍为正；但逐副球架的“机制指标增量”与“得分增量”相关性仅约0.015–0.064。因此实验支持这套球位干预在当前实现里有平均收益，不能据此断言收益全部由能量均匀化中介，也不能保证每副都更散。

## 数值模型敏感性

复用既有研究模型：接触判据1µm、时间并列1ps、固定球球解算A/B参数顺序、区间求根并只接受进入接触的根。不是pooltool完整移植，也不是已验证的真实物理金标准；此前仍发现重叠状态下分离冲量。该模型与生产模型各自进行配对比较，不能把跨模型均值差当摆球收益。两模型输入球位完全一致。

'''+table(c)+'''

偏向来球在研究控制模型中仍有正收益，削弱了“收益只由当前大接触容差造成”的解释。该模型同时改变多项数值处理，不能逐项归因，也不能替代真实球桌验证。此处的有效球数/能量分布区间与生产模型相差较大：将生产分组阈值直接套入时可能没有高组，结果标为不可估计，不重新寻找阈值。首次分析因此空组报错，原日志保留为control-analysis-empty-group.log；修正统计的空组处理后重算，原始模拟数据和阈值未改。

![结果概览](comparison.png)

## 统计、验证与限制

- 主要分差使用以球架为单位的20000次配对bootstrap，95%家族区间按两项摆法比较Bonferroni校正；观察组比较按四项校正。探索机制统计不能替代因果中介实验。
- 全量终局评分用向量与独立标量最近邻公式复算；局部分离速度和距离另作标量交叉核验；检查能量有效球数界与质心平动能分解恒等式。
- 同球架对照检查球号/其他12球/母球/瞄向/力度/旋转不变；全量初始球位不重叠、偏移半径及边界保持。原摆法精确重放、研究控制旧样本精确重放及新样本确定性重放均有记录。
- 时间是同一模拟器、同批随机调度的原生计算墙钟（4并发进程），不代表真机交互耗时。跨两个运行批次比较耗时有共享负载影响。
- 5ms和20ms样本只描述该时刻，不能冒充整个时间区间持续分离的证明。终局分数还受后续碰库、再碰撞和进球影响；此分数也不是局部团簇的完整描述。
- 两批原生任务由生命周期入口独占借用同一设备，成功后关机、释放租约并回收独占构建工作区；日志和原始数据保留。详情见 verification.json。

下一步应拆开C2、D2、D3单球及两球组合，辨别主要贡献位置和必要的前后间隙关系；本轮只检验了三球共同定向，不能认定三颗都必须这样摆。生产接入与随机方式改变仍未执行。

证据入口：protocol.json、analysis.json、paired/protocol.json、paired-analysis.json、control/protocol.json、control-analysis.json、verification.json。研究代码位于research/rack-energy-separation-20261026及research/rack-energy-control-20261026。
'''
(OUT/'REPORT.md').write_text(text)
print('Report and two figures generated')
