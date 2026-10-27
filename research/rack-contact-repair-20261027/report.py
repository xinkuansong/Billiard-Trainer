from pathlib import Path
import json,hashlib,collections
O=Path('output/rack-contact-repair-20261027');D=Path('research/rack-contact-repair-20261027');s=json.load(open(O/'summary.json'));a=json.load(open(O/'audit.json'));v=json.load(open(O/'invariance.json'));p=json.load(open(O/'paired.json'));pred=json.load(open(O/'prediction-audit.json'));cont=json.load(open(O/'continuous-audit.json'));history=json.load(open(O/'historical-comparison.json'))
closure=json.load(open(O/'closure.json'));review=json.load(open(O/'post-run-validation.json'));assert closure['total']==1402 and review['scopeReviewPassed'] and review['allPhysicsAndRackBindingsUnchanged']
assert a['allStatuses']=={'settled':1402}
assert a['nonApproaching']==0 and a['gapBeyondRoundoff']==0 and a['positiveGapOver1um']==0 and a['pairEnergyGains']==0
assert all(c['n']==200 and c['samplesExact']==200 and c['boardWithin1um']==200 and c['durationExact']==200 for c in v.values())
assert cont['allPass1um'] and pred['repairInvalidResponses']==0
before=json.load(open(O/'production-before.json'));assert [f for f,h in before.items() if hashlib.sha256(Path(f).read_bytes()).hexdigest()!=h]==review['changedSources']
# Pure production controls really use the original three numerical source files.
for name in ['CollisionDetector.swift','CollisionResolver.swift','PhysicsEvent.swift']:
 original=next(Path('QiuJi').rglob(name));assert (D/'control'/name).read_bytes()==original.read_bytes()
lines=['# 无效碰撞与顺序敏感：研究修复对照','', '本轮使用当前SDK27.1分别编译原生产对照与研究候选，在同一模拟器、同批球阵/实际初速度下比较。原200副加独立新200副，每副两方案；另200副×三种顺序/镜像诊断及2次错误现场重放，共1402次，全部停稳。生产源码未改。','', '物理系数、球距、微扰、杆头速度10、30秒/8000事件预算均保持。修复的是数值接触判据、预测进入根、事件时序和对称计算；不是调摩擦或限制转速。','', '| 球阵批次 | 方案 | 数量 | 开散均分 | ≥1.2 | 平均全桌自转尾段s | >5s | 最长尾段s | 母球落袋 | CPU均值ms |','|---|---|---:|---:|---:|---:|---:|---:|---:|---:|']
for cohort in ['old','new','all']:
 for label,x in s[cohort].items():
  lines.append(f"|{cohort}|{label}|{x['n']}|{x['meanScore']:.6f}|{x['pass1p2']}/{x['n']}|{x['meanTail']:.4f}|{x['tailOver5']}/{x['n']}|{x['maxTail']:.4f}|{x['scratch']}/{x['n']}|{x['cpuMS']:.2f}|")
lines+=['','尾段是全桌停止平移后的剩余旋转时间。CPU含两组相同的全程接触日志；不是App真机帧率或耗电测量。','', '## 正确性结果','',f"- 候选主对照及排列/镜像共{a['runs']}次，审计全程{a['pairContacts']}次球球响应：非接近响应0、超数值包络正间隙响应0、>1µm正间隙响应0、球球能量增长>1µJ为0。",f"- 最大响应前正间隙{a['maxGapM']*1e6:.6f}µm；最大记录帧重叠{a['frameOverlapM']*1e6:.6f}µm。",f"- 旧错误现场11304在0.10mm容差下原版有{pred['oldInvalidResponses']}次无效响应，候选为0。预测来源quartic，独立NumPy复算实根均为负；旧返回正时间不是有效接触根。详见prediction-audit.json。"]
for condition,x in v.items():lines.append(f"- {condition}：{x['n']}副，早期球态完全一致{x['samplesExact']}，逐次接触前后球态完全一致{x['fullContactTraceExact']}，终局≤1µm{x['boardWithin1um']}，时长完全一致{x['durationExact']}；最大终局差{x['maxBoardDifferenceM']*1e6:.6f}µm。")
lines += [f"- 11304/11331完整轨迹的{cont['runs']}次候选条件，独立按每段距离四次式的三次导数求最小距离，最大穿透{cont['maxPenetrationM']*1e6:.6f}µm，均≤1µm。此项只覆盖这两副，不能外推全批连续时间绝无漏撞。",'- 300组双球交换/镜像/能量夹具和实际间隙碰撞时间夹具由原生worker启动时运行，详见metadata.json。','', '## 方法与解释','', '1. 把0.25mm提前接触窗口替换为按实际Float坐标ULP估计的数值误差包络；有可分辨间隙则等待实际接触。','2. 球球时间使用区间内实根隔离，并只选正在进入接触面的根；不再用旧离散兜底重新引入伪根。','3. 响应前重新检查位置与接近方向；无效事件不施加冲量、不计作实际球球碰撞。','4. 按实际事件时间排序，移除1e−7秒近时刻合并；位置修复与冲量分开，不引入原10/30µm人为分隔。','5. 原球球摩擦/恢复定律改写为对称向量式，Double中间计算、一次Float舍入；保留原切向冲量上限形式，不改变物理模型参数。','', '当前验证对象均为原有随机微扰和正间隙球阵。真正零间隙、完全同刻的多接触联合求解，以及所有其他App消费者/提前停止API，未由本批证明；不能称任意球阵的普适解或生产就绪。','', '## 配对统计','', '4000次按球阵重采样，报告候选减原生产，95%描述性区间。']
for cohort,x in p.items():
 lines.append('\n'+cohort+'：'+'；'.join(f"{k} Δ={b['mean']:.6f} [{b['ci95'][0]:.6f},{b['ci95'][1]:.6f}]" for k,b in x.items()))
lines+=['','镜像21386有一次碰库前位置相差0.953674µm，速度/角速度一致、碰后恢复精确对应，其余144次事件一致；未将199/200逐位一致写成200/200。这个残余位于未改的库边几何处理，符合预设1µm空间验收范围。见mirror-exception.json。','', '## 工具链与历史基线','',f"本轮SDK27.1与此前26.2不同。原生产旧200副逐字段完全相等{sum(x['label']=='production' and not x['differentFields'] for x in history)}/200；研究候选旧200副相等{sum(x['label']=='repair' and not x['differentFields'] for x in history)}/200。历史数值只作诊断，不冒充本轮生产基线。两个当前二进制backend标签独立核对，三份核心原生产数值源逐字相同，其他差异均保留diff。",'','失败构建/中止及输入元数据问题保留在attempt-*和受管运行日志，未删除或放松断言。完整过程、具体限制见tasks/RACK-CONTACT-REPAIR-20261027.md。','']
lines+=['## 原全仓源码监控失败的范围核查','', '最终1402次均停稳、两个worker退出0、模拟器正常关闭；原运行收尾返回失败，是因为全仓SHA监控发现ContactPointTableView.swift与BTShotPageChrome.swift两个并发UI编辑。本任务未修改这两个文件。该失败保留在closure.json，未改写为成功。物理/摆球绑定逐项未变，两组冻结对象完全相同；重复当前工具链生产200副终局/接触/时长精确一致，故本次物理对照有效。详见post-run-validation.json。','']
(O/'README.md').write_text('\n'.join(lines))
verification=dict(runs=1402,physicsResearchChecksPassed=True,wholeWorkspaceMonitorPassed=False,physicsAndRackBindingsUnchanged=True,concurrentUIChanges=review['changedSources'],productionSwiftCount=len(before),researchSHA={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in D.rglob('*') if f.is_file() and '__pycache__' not in str(f)},outputSHA={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in O.glob('*') if f.is_file() and f.name!='verification.json'})
(O/'verification.json').write_text(json.dumps(verification,indent=2));print('Physics-specific research audits passed; broad workspace-monitor failure retained and scoped in post-run-validation.json.')
