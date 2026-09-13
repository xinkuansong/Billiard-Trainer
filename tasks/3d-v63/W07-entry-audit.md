# W07生产入口审查（未通过）

2026-09-13；真源问题集合_v63.md §8。当前不能关闭W07。

| 入口 | 当前代码事实 | 证据边界 |
|---|---|---|
| ShotPredictor.runShot | ShotInput默认appDefault，经simulatePrediction，正常/搜索同模型 | DR-277的12组方向与完整帧对拍通过，不代表所有近袋初值 |
| ShotPredictor.simulateFree | simulationModel默认appDefault；完整呈现单独接纯自旋尾段 | 本轮默认捕获和固定角/中袋样本失败，待归因 |
| BreakSimulator.breakShot | 参数默认appDefault，simulatePrediction；仅settled才清理停稳重叠 | 既有15/9球UI证据在W09；本轮未重新跑开球 |
| ReflectionSolverCore.launch | 默认appDefault，自然滚动无初始侧旋；携带termination | 不以扫描结果替代数值回归 |
| SimulationWorker.submit | 仍直接simulate，但全QiuJi/QiuJiTests只有定义无引用 | 当前不是生产用户入口；不为此扩大范围重构未用worker |
| legacy resolvePocket/enforceTableBounds | 仍供平面参考入口，混合路径使用evolvePlanarBall及局部接管 | 不能删除参考实现或将其旧捕获圈断言当默认模型验收 |

## 本轮实证

entry-audit-r1/session87365终态65；实际5项，3项失败/2项通过，10断言失败，总1.044s。

- testDefaultPredictionUsesPhysicalPocketCapture：.945s失败，两条完整性/确认捕获断言失败。
- testRealFreePredictionUsesLocalCaptureWithoutPlanarFallback：.040s失败，中袋出现supportConvergence(time:2.755881538872733e-05,stage:surface-moment,contacts:2,residual:9.04971189702637e-09)，随后捕获数量/ID/尾段断言失败。
- testRealPocketPredictionPreservesSelectedSimulationModel：.029s失败，convergence residual2.9487523534044158e-12，后续进袋/确认捕获断言失败。
- testIncompletePredictionCannotEnableShotOrExport：.027s通过。
- testPredictionAdapterSeparatesEventBudgetFromLocalWorkFailure：.003s通过。

完整输出output/3d-v63/W07/entry-audit-r1.log和同名xcresult。先前口头两失败/三通过已更正，以此真实计数为准。

makeCollectionEntryEngine以真实接触网格向下投射定位，随后自由预测重新通过CueBallStrike构建滑动态，不是直接重放原rolling状态。不能把既有rolling单体对拍通过推及此滑动入口。下一步比较相同实际输入的单体快捷/原共享控制，判明DR-274影响；不得放宽残差容限、改弱捕获断言或把失败转成成功兜底。DR-277淘汰未在simulateFree启用，本轮失败不能直接归咎该搜索优化。

DR-278扩展验证：moment-bound-r2/session94468终态0，实际8项/0失败，总4.339s。默认六袋沿4.118s、默认捕获.028s、自由近袋捕获.044s、滑动态新旧单体对拍.118s；坡面静止/超临界加速、滚阻不反转、不增自旋能四项共.031s。gate-r1/session9023终态0。原指定模型近袋的CollisionResolver convergence失败仍未解决，不得以此8项绿覆盖。

DR-279完成本轮入口修复：force-scale-r2/session1884实际5项/0失败1.087s，原指定模型近袋.101s通过，双球滑移/顺序交换与未完预测拒绝保留。contact-regression-r1/session42730终态0，真实c039完整8杆实时/导出事件、起止球形与192静止帧对比1项57.338s通过；旧保存第二杆离场与当前返回台面差异断言仍通过。未新审MP4视觉，不据此宣称全部W08/W16完成。
