from pathlib import Path
import json,hashlib
O=Path('output/rack-contact-tolerance-20261027');D=Path('research/rack-contact-tolerance-20261027');s=json.load(open(O/'summary.json'));v=json.load(open(O/'invariance.json'));p=json.load(open(O/'paired.json'))
lines=['# 接触容差单因素对照结果','', '固定200副球阵，每副四档；另40副四档倒序诊断。杆头速度10，摆球和全部物理系数不变。只有立即接触距离容差改变；记录探针不参与物理决策。','', '| 容差mm | 停稳 | 开散均分 | ≥1.2 | 自转尾段均值s | >5s | 最长s | 母球落袋 | CPU均值ms |','|---:|---:|---:|---:|---:|---:|---:|---:|---:|']
for e,a in s.items():lines.append(f"|{float(e)*1000:g}|{a['settled']}/{a['n']}|{a['meanScore']:.6f}|{a['pass1p2']}/200|{a['meanTail']:.4f}|{a['tailOver5']}/200|{a['maxTail']:.4f}|{a['scratch']}/200|{a['cpuMS']:.2f}|")
lines+=['','尾段定义为全桌所有球停止平移后，剩余侧旋到停稳的时间；不是单颗球自身纯自转总时间。CPU为带同等只读日志的原生模拟器计算耗时，不含JSON输出/后处理，也不是App真机性能。','', '| 容差mm | +Z角/−Z角5ms均速m/s | 两角能量份额 | >1µm正间隙接触次数 | 最大正间隙mm | 最大记录帧重叠mm | 倒序早期完全一致 | 倒序终局≤1mm |','|---:|---:|---:|---:|---:|---:|---:|---:|']
for e,a in s.items():
 b=v[e];speed='/'.join(f'{x:.3f}' for x in a['cornerSpeeds5ms']);share='/'.join(f'{x*100:.2f}%' for x in a['cornerShares5ms'])
 lines.append(f"|{float(e)*1000:g}|{speed}|{share}|{a['positiveGapContacts']}|{a['maxGapMM']:.6f}|{a['maxOverlapMM']:.6f}|{b['earlyExact']}/40|{b['boardWithin1mm']}/40|")
lines+=['','5ms以母球首次撞球为起点；能量份额分母为仍在记录中的15颗目标球平动能（不含母球）。倒序只是诊断，不并入主对照均值。>1µm统计实际球球响应前、make-kiss位置修正前的表面正间隙；它不是eps直接触发计数，其他旧求根/兜底路径也可能产生此类接触。','', '## 配对变化（相对0.25mm）','', '以下95%区间为固定随机种子的4000次按球阵重采样，描述性区间，未作多重比较校正。']
for e,a in p.items():
 lines.append(f"\n- {float(e)*1000:g}mm："+'；'.join(f"{k} Δ={x['mean']:.6f}，95%区间[{x['ci95'][0]:.6f}, {x['ci95'][1]:.6f}]" for k,x in a.items()))
lines+=['','## 结论与额外异常','', '三档开散均分均明显下降；自转尾段配对差95%区间均跨0，未证明改善。角球偏侧减轻，但40副倒序终局四档均未达到同落袋且≤1mm。单独缩小容差不宜接入生产。','', '0.10/0.05/0.01mm分别6/7/11次球对已经分离仍被响应（原档0）。11304在首次撞球后2.630µs，间隙0.048108mm，分离速度+14.4697m/s被响应成−13.7462m/s；见anomalies.json完整前后态。这里只定位到无效响应，未证明所有异常来自某一个预测/缓存/兜底分支。0.05/0.01mm各一副记录帧重叠略超10µm；全部自然停稳，但不能据此宣称没有数值缺陷。','', '四档主对照球球能量增长>1µJ为0次，回放结束在桌球残余速度/角速度为0。','', '完整任务分析与限制见tasks/RACK-CONTACT-TOLERANCE-20261027.md。','', '## 审计边界','', '- 全部模拟状态与失败均保留；0.25mm的200副逐字段对拍旧生产结果，11331全655帧另作精确对拍。','- 四档输入球位与母球初速度一致；所有生产Swift文件SHA与运行前一致。研究源差异见同目录两份swift.diff。','- overlapAudit覆盖记录帧；eventTrace覆盖球球冲量前及球库前后。未进行连续时间独立CCD穷举，因此不能声称绝无漏撞。','- 未调整求根、事件合并、碰后推开距离、球球响应公式、库边响应、自旋衰减或停稳预算。','- 未做App UI/真机回归或实物标定，不建议据此直接接入生产。','']
(O/'README.md').write_text('\n'.join(lines))
before=json.load(open(O/'production-before.json'));assert all(hashlib.sha256(Path(f).read_bytes()).hexdigest()==h for f,h in before.items())
assert json.load(open(O/'closure.json'))['success']
audit=dict(runs=960,baselineMatches=200,productionSwiftUnchanged=True,productionSwiftCount=len(before),researchFiles={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in D.glob('*') if f.is_file()},outputs={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in O.glob('*') if f.is_file() and f.name!='verification.json'})
(O/'verification.json').write_text(json.dumps(audit,indent=2))
