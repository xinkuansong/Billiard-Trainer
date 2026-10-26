from common import *
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
FONT=FontProperties(fname='/System/Library/Fonts/Hiragino Sans GB.ttc',weight=300);plt.rcParams['axes.unicode_minus']=False
D=json.loads((OUT/'discovery/summary.json').read_text());V=json.loads((OUT/'validation/summary.json').read_text());P=json.loads((OUT/'validation/protocol.json').read_text());variants=P['variants'];colors=['#7a8794','#d1965e','#358e9d','#ae628c'];PH=json.loads((OUT/'validation-phase.json').read_text())
fig,axs=plt.subplots(1,3,figsize=(14,4.6))
for ax,key,title in zip(axs,['mean','passRate','wallMeanMS'],['平均散开分','达到 1.20 的比例','单次物理计算均耗时 / 毫秒']):
 vals=[V['variants'][v][key]*(100 if key=='passRate' else 1) for v in variants];ax.bar(range(4),vals,color=colors)
 ax.set_xticks(range(4),[label(v) for v in variants],fontproperties=FONT,rotation=20,ha='right');ax.set_title(title,fontproperties=FONT);ax.set_ylim(0,max(vals)*1.22)
 for i,y in enumerate(vals):ax.text(i,y,f'{y:.4f}' if key=='mean' else f'{y:.1f}'+('%' if key=='passRate' else ''),ha='center',va='bottom',fontsize=10)
fig.suptitle('独立 2,000 副球阵：四种摆法逐副配对复验',fontproperties=FONT,fontsize=15);fig.tight_layout();fig.savefig(OUT/'validation.png',dpi=170,bbox_inches='tight');plt.close(fig)
fig,axs=plt.subplots(1,2,figsize=(12,5))
for v,c in zip(variants,colors):
 s=V['variants'][v];axs[0].plot(range(15),s['meanFirstImpulseOrder'],marker='o',color=c,label=label(v));axs[1].plot(range(30),np.array(s['edgeGapSDMM'])*1000,marker='.',color=c,label=label(v))
axs[0].set_xticks(range(15),NAMES,rotation=60);axs[0].set_ylabel('首次受冲量序号的均值（已观测样本）',fontproperties=FONT);axs[0].set_title('碰撞先后确实改变，但不直接等于最终效果',fontproperties=FONT)
axs[1].set_xticks(range(30),[NAMES[a]+'-'+NAMES[b] for a,b in EDGES],rotation=90,fontsize=7);axs[1].set_ylabel('初始间隙标准差 / 微米',fontproperties=FONT);axs[1].set_title('同样偏移范围，不同的相邻间隙波动',fontproperties=FONT);axs[1].legend(prop=FONT,fontsize=9)
fig.tight_layout();fig.savefig(OUT/'order-and-gaps.png',dpi=170,bbox_inches='tight');plt.close(fig)
phase=json.loads((OUT/'validation-phase-rows.json').read_text());x=np.array([r['cosine'] for r in phase]);y=np.array([r['delta'] for r in phase]);fig,ax=plt.subplots(figsize=(9,4.5));ax.scatter(x,y,s=5,alpha=.18,color='#4e829a');ax.axhline(0,lw=1,color='#879098');ax.axvline(0,lw=1,color='#879098')
for lo,hi in zip(np.linspace(-1,1,9)[:-1],np.linspace(-1,1,9)[1:]):
 keep=(x>=lo)&(x<hi if hi<1 else x<=hi);ax.plot([(lo+hi)/2],[y[keep].mean()],'o',color='#c85a53')
ax.set_xlabel('共同径向分量：负值倾向收缩，正值倾向展开',fontproperties=FONT);ax.set_ylabel('相对同副生产摆法的最终分差',fontproperties=FONT);ax.set_title('径向相位补充分析：散点为单副，红点为分箱均值',fontproperties=FONT);fig.tight_layout();fig.savefig(OUT/'radial-phase.png',dpi=170,bbox_inches='tight');plt.close(fig)
lines=['# 全阵随机方向关联与碰撞先后研究','','完成5,400次筛选和8,000次独立复验，共13,400次，全部停稳。生产代码未改。','','## 设计与范围','','8类方向关联，每类中/强两档，加生产/旧三球两个对照。每球原偏移长度保留，半径仍0.09毫米，名义间隙仍0.20毫米；Float舍入误差单列。固定正中母球、瞄准实际顶球、杆速9.75、零旋转。XZ世界平面，Y朝上，+X朝来球侧。', '', '相关方向由原随机单位方向按球排、斜链、镜像、邻接关系或局部径向坐标共同计算。理想算术下，各球方向仍有旋转对称性；球与球的方向不再独立。不是从结果中挑选高分题库，也没有按每副终局优化输入。', '', '300副新球阵筛选16候选，按均分选前二；另外2000副新球阵配对复验。主指标是既有校准散开分均值，1.20辅助。五个主比较用20,000次按球架bootstrap和Bonferroni家族95%区间。前后1000只做一致性描述。','','![关联方向](correlation-patterns.png)','','## 独立复验','','|摆法|平均分|中位数|P10|≥1.20|均耗时/P95 ms|','|---|---:|---:|---:|---:|---:|']
for v in variants:
 s=V['variants'][v];lines.append(f"|{label(v)}|{s['mean']:.6f}|{s['median']:.4f}|{s['p10']:.4f}|{s['passRate']:.2%}|{s['wallMeanMS']:.2f}/{s['wallP95MS']:.2f}|")
lines+=['','耗时是本机四进程模拟器中的BreakSimulator墙钟，调度随机交错，不包括关联摆球生成；不是iPhone真机性能。','','|比较|配对平均差|相对变化|校正95%区间|前/后1000平均差|','|---|---:|---:|---|---|']
for k,c in V['comparisons'].items():
 a,b=k.split('--');lines.append(f"|{label(a)} 对 {label(b)}|{c['mean']:+.6f}|{c['relativeMeanChange']:+.2%}|[{c['family95'][0]:+.6f}, {c['family95'][1]:+.6f}]|{c['halfMeans'][0]:+.5f}/{c['halfMeans'][1]:+.5f}|")
lines+=['','![复验](validation.png)','','## 全阵位置与传递顺序','','径向联动：把各球原随机方向转入“从球阵中心指向该球”的局部坐标，求共同方向后再旋转回世界坐标；共享一个相位，形成微量展开/收缩/转动趋势，逐球偏移长度不变。邻球同向：每球使用自身及初始相邻球的平均方向；邻域重叠，但不会让所有球的位置完全刚性平移。','','|摆法|相邻球偏移方向余弦均值|内部首个冲量平均序号|内部先于任一后角球受撞比例|20ms未受冲量的球架数|内部能量/入射母球能量，5ms|能量有效球数，5ms|','|---|---:|---:|---:|---:|---:|---:|']
for v in variants:
 s=V['variants'][v];m=s['mechanisms'];lines.append(f"|{label(v)}|{s['neighborOffsetAlignment']:.3f}|{s['meanInternalFirstOrder']:.3f}|{s['firstInternalBeforeCornerRate']:.2%}|{s['censoredRackCount']}|{m['interiorEnergyFraction']:.3%}|{m['effectiveBalls']:.3f}|")
lines+=['','冲量顺序来自记录帧中速度跳变量大于1e-5m/s的事件，时间相同仍保留frameIndex先后；不是穷举引擎的所有候选事件。内部序号均值只使用三个内部球均已受撞的球架；逐球序号图按各球已观测样本计算，分母见summary.json。无早期冲量的球仍保留在最终分统计中。','','![碰撞与间隙](order-and-gaps.png)','','## 径向展开/收缩补充分析','','筛选发现径向方式领先后，按几何自然分界cos=0，预先固定展开/收缩两组；在读取复验结果前保存phase-plan.json，未改变候选或模拟参数。此为次要分析，两个组内配对差＋组间差共3项独立家族校正，不冒充原五项主分析。','','|径向倾向|样本数|当前组生产均分|径向均分|平均邻接间隙 mm|配对差校正95%区间|','|---|---:|---:|---:|---:|---|']
for k,n in [('expanding','展开'),('contracting','收缩')]:
 s=PH[k];c=s['delta'];lines.append(f"|{n}|{s['n']}|{s['baselineMean']:.6f}|{s['mean']:.6f}|{s['gapMeanMM']:.5f}|[{c['family95'][0]:+.6f}, {c['family95'][1]:+.6f}]|")
c=PH['interaction'];lines+=['',f"两组配对改善量之差：{c['mean']:+.6f}，校正95%区间 [{c['family95'][0]:+.6f}, {c['family95'][1]:+.6f}]。这是已有随机相位的分组结果，不等于已验证强制展开或强制收缩的新生成策略。",'','![径向相位](radial-phase.png)','','## 全部筛选结果（探索）','','|方式|均分|≥1.20|内部能量比例，5ms|','|---|---:|---:|---:|']
for v in ['baseline','toward']+D['ranking']:
 s=D['variants'][v];lines.append(f"|{label(v)}|{s['mean']:.6f}|{s['passRate']:.2%}|{s['mechanisms']['interiorEnergyFraction']:.3%}|")
lines+=['','## 核验与限制','',f"- 13,400次终局分独立标量复算；所有球号、母球/杆速/旋转、方向变换、105球对初始间距已核。两轮最小净距 {min(D['audit']['minGapMM'],V['audit']['minGapMM']):.6f} 毫米，逐球偏移长度最大舍入变化 {max(D['audit']['maxRadiusChangeMM'],V['audit']['maxRadiusChangeMM']):.6f} 毫米。", '- 33项生产相关源码前后无漂移，两轮各12条历史基线精确对拍及12条新结果确定性重放。每条初始位置还由独立Python变换复算；未改生产物理。', '- 筛选首次分析错误假设20ms内所有球必被撞到，4组原始记录反证：球仍stationary且速度0，其中一例约395ms才首撞。修正为窗口删失并保留分母/缺测标志；原错误日志及明细保留，终局均分仍包含这些记录。', '- 两轮8个worker退出0；设备关机、租约释放，临时工作目录回收；证据见verification.json。', '- 固定杆速、正中开球、现行生产引擎，不代表其他开球条件或现实球台。现行接触阈值及同刻事件顺序敏感性仍限制物理外推。', '- 此实验只覆盖16种预定关联方式。结果不能证明全部位置规律有效或无效，也不能把早期能量/冲量变化当成完整因果解释。','']
(OUT/'REPORT.md').write_text('\n'.join(lines));print('Report rendered')
