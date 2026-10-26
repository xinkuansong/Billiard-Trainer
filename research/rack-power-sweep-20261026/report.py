from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-power-sweep-20261026'
s=json.loads((OUT/'summary.json').read_text());rows=s['powers'];base=rows['9.75']
lines=['# 当前候选增加杆速的配对比较','', '1000副相同球形 × 6档杆速，共6000次正式模拟；全部停稳。固定两侧差异化偏移、正中无塞，生产代码未由本任务修改。100副来自原效果图册，900副是全新种子；无重抽、无结果筛选。','', '|杆速m/s|平均评分|≥1.20|母球落袋|≥1.20且无母球落袋|近邻球占比|平均进球|CPU ms|墙钟ms|','|---|---:|---:|---:|---:|---:|---:|---:|---:|']
for p,r in rows.items():lines.append(f"|{p}|{r['mean']:.4f}|{r['passRate']:.1%}|{r['scratch']:.1%}|{r['cleanPass']:.1%}|{r['closeFraction']:.1%}|{r['potted']:.2f}|{r['cpuMS']:.1f}|{r['wallMeanMS']:.1f}|")
lines+=['','近邻球指与至少一颗其他目标球的球心距离<4R（球面间隙<一个直径57.15mm），分母为剩余目标球。评分独立按NumPy与标量最近邻均距复算，按剩余球数校准，母球不参与散开评分。','', '## 相比9.75的配对变化','', '每项指标的5个速度对照报告Bonferroni校正95%区间；这不是同时覆盖所有指标的总区间。随机混排执行以减轻时间顺序偏差，使用同种子逐对bootstrap。','', '|杆速|平均分变化|校正95%区间|母球落袋变化|校正95%区间|','|---|---:|---|---:|---|']
for p,c in s['comparisons'].items():
 ci=c['score']['family95'];sc=c['scratch']['family95'];lines.append(f"|{p}|{c['score']['mean']:+.4f}|[{ci[0]:+.4f}, {ci[1]:+.4f}]|{c['scratch']['mean']:+.1%}|[{sc[0]:+.1%}, {sc[1]:+.1%}]|")
lines+=['','## 新900副敏感性结果','', '|杆速|平均评分|≥1.20|','|---|---:|---:|']
for p,r in rows.items():lines.append(f"|{p}|{r['new900Mean']:.4f}|{r['new900Pass']:.1%}|")
lines+=['','## 物理模型与范围','', 'App当前开球控件上限10m/s。直接BreakSimulator入口不截断研究输入；每条实际母球初速度已按杆球质量公式核验。当前零塞、平杆模型下母球初速=2V/(1+0.170/0.567)，随杆速线性增加，初始动能随杆速平方增加；母球到达球阵前会有台呢摩擦。','', '|杆速|模型母球初速m/s|相对9.75初始动能|5ms目标球动能J|5ms有效获能球数|5ms内部三球能量占比|','|---|---:|---:|---:|---:|---:|']
for p,r in rows.items():lines.append(f"|{p}|{r['initialCueSpeed']:.2f}|{(float(p)/9.75)**2:.3f}倍|{r['energy5']:.2f}|{r['effectiveBalls5']:.2f}|{r['internalShare5']:.1%}|")
lines+=['','早期5ms统一以首次碰球为零点；不同力度在相同时间内可能处于不同碰撞阶段，早期指标仅作描述，不足以证明因果机制。高于10m/s是当前模型的范围外输入探索，未进行真实高速开球校准；本结果不证明现实中同样增益，也不包含手动加力后的瞄准误差。','', '平均分随力度的实测变化不自动等同“越大越好”；必须同时看母球落袋、局部聚团、进球、耗时。只比较本次六个固定档位，未证明连续区间或更高力度的全局最优。','', '## 证据与交付','', '- [六档统计曲线](power-comparison.png)','- [100副原球形六档视觉对照](index.html)','- [原始协议](sweep/protocol.json)、[汇总与审计](summary.json)、[逐局派生指标](rows.json)、[图册数据](atlas.json)。','- 9.75档原图册100副的球位、落袋、摆法和瞄准逐位一致；其余档位球位/编号/瞄准与本轮9.75完全一致。','- 原生预检、12条重复运行、33项当前生产源绑定；生产冻结差异精确审核记录在[source-exceptions](source-exceptions.json)。','- 同机另有编译任务，墙钟包含调度竞争；CPU耗时更能反映本批模拟计算成本。仍不应外推为iPhone或App全流程延迟。','']
(OUT/'REPORT.md').write_text('\n'.join(lines));print('\n'.join(lines[:14]))
