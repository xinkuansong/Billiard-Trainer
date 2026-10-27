from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-variance-minimize-20261027'
read=lambda name:json.loads((OUT/name).read_text())
s=read('summary.json');p=read('paired.json');m=read('mechanism.json');v=read('verification.json')
new=read('holdout-selection.json')['selected'][-1]
assert new not in ['B','E']
ne=p[new+'-E'];nb=p[new+'-B'];st=ne['stability']
labels={'B':'B','E':'上一轮 E',new:'新方案：后排分流'}
ci=lambda d:f"{d['mean']:+.6f} [{d['ci95'][0]:+.6f}, {d['ci95'][1]:+.6f}]"
lines=[
'# 通过摆球降低整副球速度方差',
'',
f"独立终验为 300 副新球阵，每副配对运行 B、E、新方案。新方案 5ms 的平均球内速度方差为 **{s[new]['variance5']:.6f} (m/s)²**，比 E 低 **{100*(1-s[new]['variance5']/s['E']['variance5']):.2f}%**，比 B 低 **{100*(1-s[new]['variance5']/s['B']['variance5']):.2f}%**。研究引擎和物理参数未改，未修改生产代码。",
'',
'## 摆球规则',
'',
'在 E 的基础上，只调整最后一排五颗球（槽 10–14）的随机偏移方向。最后一排之外的十颗球（包括顶球）、每颗球原偏移长度、名义间距 0.20mm、微扰半径上限 0.09mm、正中击球和杆速 10 保持不变；同种子各方案的实际母球初速度完全相同。',
'',
'后排两侧各有一条分叉：槽 6 向角球 10 / 内接球 11 传能；槽 9 向角球 14 / 内接球 13 传能。调整这两对接球的方向，尽量让内接球先接到碰撞，再传向角球。后排正中槽 12 回到 C 的方向，撤销 E 对它额外施加的 90° 转向。',
'',
'具体规则 gate50：用上一级球到分叉球的连线估计初始来球方向 u；对接球初始表面间隙 g 和接触法线 n，计算闭合行程近似 q=g/(u·n)。在原偏移圆上按 5° 网格搜索角球与内接球方向，尽量使 q角−q内≥50µm；有解时取相对 E 转角平方和最小的一对，无解时取能达到的最大差值。50µm 是摆球几何目标，不是引擎碰撞容差，也不是要求实际间隙等于该值。它只近似最早分叉条件，不能预测全部后续碰撞。',
'',
'每副球阵只根据初始几何生成摆法，不运行物理模拟挑选开球结果，不建题库。当前是 Python 研究原型，未做生产性能或设备体验验收。',
'',
'## 固定口径与独立验证',
'',
'每副球阵在首次球球接触后 5ms，取全部 15 颗目标球的速度大小（包含零速度，排除母球），计算总体方差 Σ(v−平均v)²/15，再跨球阵取平均。不是向量方差、平均速度或变异系数。20ms、100ms 为旁证。',
'',
'预设 32 条规则 ×24 副筛选；E 加前五候选 ×64 副独立确认；确认后冻结胜出规则，最后与 B/E 配对验证 300 副新球阵。筛选要求平均 5ms 目标球平动能至少为配对 E 的 99%。终验数据没有参与选规则。',
'',
'| 方案 | 5ms 方差 | 20ms 方差 | 100ms 方差 | 5ms 平动能 J | 5ms 最大球速均值 m/s | 5ms 角球能量占比 |',
'|---|---:|---:|---:|---:|---:|---:|']
for k in ['B','E',new]:
 a=s[k];lines.append(f"| {labels[k]} | {a['variance5']:.4f} | {a['variance20']:.4f} | {a['variance100']:.4f} | {a['energy5']:.4f} | {a['maxSpeed5']:.4f} | {a['cornerShare5']*100:.2f}% |")
lines += ['',f"新−E 方差差值的 95% 配对 bootstrap 区间：**{ci(ne['variance5'])}**；新−B：**{ci(nb['variance5'])}**。5000 次重采样，以球阵为配对单位。",
'',
f"相对 E：严格变小 {st['strictWins']}/300；明显改善 {st['meaningfulWins']}、近似不变 {st['nearEqual']}、明显退化 {st['meaningfulLosses']}。明显变化阈值为绝对方差差 >0.01 (m/s)²。退化超过 E 的 10% 有 {st['worseOver10Percent']} 副。配对差中位数 {st['median']:+.6f}，95% 区间 {st['medianCI95']}。不能据此声称每副球阵都改善。",
'',
f"目标球 5ms 平动能相对 E 变化 {100*(s[new]['energy5']/s['E']['energy5']-1):+.3f}%，相对 B {100*(s[new]['energy5']/s['B']['energy5']-1):+.3f}%。初始输入相同不代表之后目标球平动能相同；碰撞损耗、母球残余动能、旋转均会影响它。结果需与方差一并看。",
'',
'## 碰撞记录支持的机制',
'',
'“内接球先接能量”按前 5ms 分叉球对这两个接球首次发生明显能量损失的事件记录，避免把无能量交换的事件计入。',
'',
'| 方案 | 槽 6 首先向内接球 11 传能 | 槽 9 首先向内接球 13 传能 | 两角球平均能量合计 J | 初始几何达到 50µm 的侧数 /600 |',
'|---|---:|---:|---:|---:|']
for k in ['B','E',new]:
 a=m[k];lines.append(f"| {labels[k]} | {a['rearInnerFirstPlus']}/300 | {a['rearInnerFirstMinus']}/300 | {a['slotMeanEnergy'][10]+a['slotMeanEnergy'][14]:.4f} | {sum(a['initialAtLeast50UMCounts'])}/600 |")
lines += ['','分叉的实际顺序仍受其他碰撞影响。按新方案相对 E 的“内接球优先侧数”变化分组：','','| 优先侧数变化 | 球阵数 | 平均方差差值 | 明显改善 / 退化 |','|---|---:|---:|---:|']
for a in read('mechanism-paired.json')[new]['groups']:
 lines.append(f"| {a['change']:+d} | {a['n']} | {a['meanDelta']:+.5f} | {a['meaningfulWins']} / {a['meaningfulLosses']} |")
lines += ['','这支持通过改变分叉接触先后来减少角球能量集中，但不是完整因果分解：新方案同时调整多个后排位置；具体事件和逐副结果保存在 mechanism-paired.json / raw.jsonl.gz。','','## 副作用与限制','','| 方案 | 方差最差四分之一均值 | 停球后自转尾巴均值 s | 自转尾巴 P95 s | 尾巴 >5s 副数 | 母球落袋 | 最终最近表面距离均值 m | 拥挤球数 |','|---|---:|---:|---:|---:|---:|---:|---:|']
for k in ['B','E',new]:
 a=s[k];lines.append(f"| {labels[k]} | {a['worstQuartileVariance']:.4f} | {a['tail']:.4f} | {a['tailP95']:.4f} | {a['tailOver5']} | {round(a['scratch']*300)}/300 | {a['nearestGap']:.4f} | {a['crowded']:.3f} |")
lines += ['',f"新−E 自转尾巴差值：{ci(ne['tail'])} 秒；最近表面距离差值：{ci(ne['nearestGap'])} 米；拥挤球数差值：{ci(ne['crowded'])}。区间跨零时，不宣称确定改善。拥挤球指最终最近表面间距小于一个球直径；终局统计仅含留在台面的目标球，因此同时保留 finalN 和 scratch 原始指标。",'',
'速度方差更低并不自动保证最终开散更好；各球运动方向、相邻球相对速度及之后碰库仍有影响。本轮以用户指定的整副球速度方差为主目标，不能把它等同于生产开散评分或完成异常自转修复。',
'',
'## 可复核证据',
'',
f"完成 {v['nativeRuns']} 次原生物理模拟，全部正常停球；另有 {v['layoutOnlyRequests']} 次纯摆球请求。{v['auditedBallResponses']} 次球球响应审计中，无效响应、容差外响应及能量增加超过 1µJ 的响应均为零。2 次旧 B/E 完整精确重放通过，15 次倒序/打乱/镜像验证通过。方差与平动能恒等式检查 {v['varianceEnergyIdentityChecks']} 次，最大误差 {v['maxIdentityError']:.3g}。",
'',
f"6 份研究引擎文件及 {v['physicsSourceBindings']} 份生产物理/摆球绑定的 SHA 均未变；运行脚本和摆球构造器 SHA 固定。同期其他任务改变的生产 Swift 文件数为 {len(v['productionChangesDuringRun'])}，记录在 source-review.json，本任务未改生产文件。",
'',
'- 原始证据：raw.jsonl.gz、layouts.jsonl.gz、scalars.json。',
'- 选择过程：screen-ranking.json、confirmation-ranking.json、holdout-selection.json。',
'- 分析：summary.json、paired.json、mechanism.json、mechanism-paired.json、verification.json。',
'- 规则源码：../../research/rack-variance-minimize-20261027/layout_study.py。',
'- 原生运行：../../research/rack-variance-minimize-20261027/run.py。',
'',
'![摆球与方差对比](variance-minimize.png)',
]
(OUT/'README.md').write_text('\n'.join(lines)+'\n')
