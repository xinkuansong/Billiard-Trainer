# W07 模型兼容审查（进行中）

对照问题集合_v63.md §8，2026-09-13。此文件整理验收对象，不替代原失败日志，不降低物理要求。

| 类别 | 当前事实与依据 | 裁定 / 未完成项 |
|---|---|---|
| 旧孔圈捕获 | PhysicsInvariantTests.test_invariant_centerInHoleRadiusMeansPocketed实际调用engine.simulate；EventDrivenEngine.simulatePrediction显式区分planarReference和appDefault | 保留旧断言作为平面参考模型护栏，不修改原断言，也不以其绿证明局部默认模型。需分别报告执行范围 |
| 普通原始引擎不变量 | 同文件能量、重叠、原始确定性、停稳等多项也直接调用simulate | 这些证明范围仍是平面引擎；不能因文件名PhysicsInvariantTests就声称默认混合物理全部覆盖 |
| 正式默认袋沿支持 | testAppDefaultDistinguishesSupportedAndUnsupportedPocketEdge走默认入口，角/中袋各三档支持边界、捕获ID、下落速度、无旧pocketEntries均有断言；optimized-tests-r1通过11.137s | 与旧孔圈规则不同是设计要求。DR-275同产物iPad scoring-residual-r3已复验六输入矩阵，4.257s通过 |
| 保存内容与当前预测不同 | c039第二杆旧保存after判目标球离场，当前预测返回台面；完整八杆实时/导出事件、起点和终点已通过最新single-control-regression-r1 | 内容消费一致性已证明；具体袋口返回是否足够符合实物仍需几何/物理证据，不能强制球进袋消除差异 |
| 旧W05临界收敛 | testCriticalPocketStepConvergence单独构造局部patch、固定原型恢复/摩擦系数，run无捕获尾段；最后记录在极短剩余时段失败 | 不是普通App进袋最终态测试，但暴露底层数值局限；保留疑似回归/未解释标记。用户已要求不再围绕该旧原型扩大袋内探索，不能伪报通过 |
| 搜索与完整预测同物理 | ScoringOnlyConsistencyTests两项分别比较搜索与完整预测、提前停止与完整模拟；现仍使用真实预测入口 | 当前DR-275下54/20组字段比较通过；新增完整性断言揭示两组5.4m/s全模拟timeLimit；scoring-time-limit-r1确认全部球平移停止，仅母球原地自旋约±16.477rad/s；DR-276补齐解析尾段后spin-tail-r4四项/0失败，54组完整性断言通过。默认六袋沿最新4.257s通过；不关闭highFidelityBounds、不缩搜索网格 |
| 真机性能 | Debug -O iPhone16Pro固定防守68.763s/5解，Release对照已构建但因锁屏未执行测试；session79732已主动中断并终态73 | 明确未达手机可用性能。模拟器19.192s不能替代设备结论 |

默认六边界、54/20组字段比较、旧平面孔圈已有上述结果。DR-276已修复纯台面自旋导致完整预测timeLimit：默认混合尾段与长时平面参考逐时刻对拍通过，真正平移未完及eventLimit继续拒绝。下一步按W07/W16继续性能与真实消费者验收；不可将4项单测当作完整页面/导出或整个3D验收。Release旧设备测试已停止，无解锁等待进程。原54/20组断言未弱化。

最新入口复验entry-audit-r1：默认捕获/自由局部捕获/指定模型近袋三项失败，未完预测拒绝/预算分离两项通过；旧结果不能代替当前回归，详W07-entry-audit.md。

DR-278修复默认/自由捕获的surface-moment失败，moment-bound-r2八项通过；指定模型近袋碰撞convergence仍失败。详W07-entry-audit.md。

DR-279已修复上条指定模型近袋force收敛失败；force-scale-r2五项、contact-regression-r1完整八杆事件/球形对照均通过。原三个入口失败已分别闭合，批次其他范围另审。

## 常规失败与实际入口分流（2026-09-13）
- `test_predictor_defaultLayoutPots`使用历史两球(-.35,.22)/(.55,-.18)、3.3m/s，注释声称与当前placeBallsAtDefaults一致已过时。当前AngleDynamic是几何页且球位不同；实际PositionPlayViewModel.applyDefaultLayout为归一化母球(.30,.30)、1号(.62,.20)、2号(.78,.34)，ShotTuning.defaultVelocity=1.5。原断言保留，只纠正注释；不得据历史fixture失败声称现页面开箱不能进。
- `test_currentPositionPlayDefaultsProduceResolvedPot`通过真实VM.setupScene→后台求解→solvedShot验证，不复制摆球/选袋算法。current-defaults-r1/session33311 exit0，实际1项1.250s；当前球形保持、自动topRight/目标_1、1.5/无塞、settled且进球，所有实际捕获Y≤对应收集平面。并非UI触控/帧率验收。
- `test_predictor_withSideSpin_stillPots`追加最终状态断言与诊断，side-spin-final-r1/session75802 exit65，实际1项1.906s、仅原进球断言失败；最终settled，非求解中断。此前整类日志的penetration不能直接归到该最终预测。原同一输入普通加塞未进仍是模型差异待审，不能宣称修复。
- 当前优先级：真实入口错误与规则/展示不一致优先；历史高力度“必须进”样例逐项按轨迹和旧捕获前提分类，不盲目改页面默认力度或物理参数。W07仍返工，常规10项失败尚未全部裁定。

证据范围更正（2026-09-13）：ShotSimulationView.onAppear在setupScene后loadBoard(defaultBoard)，实际仍为(-.35,.22)/(.55,-.18)两球，页面力度为1.5m/s。此前“历史defaultLayout不是当前页面默认”的说法过宽：布局仍被该页使用，测试的3.3m/s与当前默认力度不同。currentPositionPlayDefaults测试仅证明裸VM三球初始化，不证明该页面覆盖后的默认进球；原失败保留，未关闭W07。

## 实际页面默认球形补验（2026-09-13）
- page-default-r1/session65243 exit0，实际UI 1项24.621s。通过真实入口打开分离角与走位，未调整球位/力度/打点/瞄准，切3D击球后回2D。
- 已查看before-2d 1ED8321B、after-3d B7973FC3、after-2d 1F3EF2FF原图：默认母球/黑8、1.5；终态两模式仅母球在桌，8号球回到球库，状态为点选一颗目标球，击球禁用、重打/回放可用。这是实际页面的可见结果证明，区别于裸VM默认测试；不证明其他力度或袋沿连续运动质量。
- r2/session37334正在补生产“无目标球/禁用击球”状态断言、同杆回放与重打恢复。r1只说明流程与已审图，不把其就绪断言称为自动进球判定。原10项物理失败保留。

实际默认页r2/session37334 exit0：1项32.941s、0失败。默认击球后及3D回放后均命中生产“点选一颗目标球”状态且击球禁用；重打后恢复可击球。96DBC61E回放/47FF2037重打原图已审：回放后仅母球，重打恢复黑8及原默认球形。此处已补实际页面入口证据；没有改默认力度、物理系数或捕获边界。此用例的可见结果与状态通过，不替代原10项物理失败及连续袋口动画验收。两次测试均终态，无活跃句柄。
