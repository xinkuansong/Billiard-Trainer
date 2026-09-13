# W07 验收返工：统一预测、捕获与规则入口

2026-09-13；需求真源问题集合_v63.md §8 W07。更正结论：此前完成声明撤回（FL-070）。以下通过证据保留，但strike-r1新增反证：PhysicsEngineTests 10项/19断言失败，完整常规基准尚未归因；W07返工。整个v63未完成；W08–W10及W16完整验收、H01–H04仍需继续。真机防守求解68.763s不达可用水平，不能以本批状态覆盖该问题。

| 要求 | 当前证据 |
|---|---|
| 捕获/正常预测/批量求解同入口 | ShotInput、simulateFree、BreakSimulator和ReflectionSolverCore默认appDefault并调用simulatePrediction；完整源码调用审查见W07-entry-audit。仅未被生产引用的SimulationWorker保留旧simulate，已明确归类，不当作在线页面路径 |
| 默认捕获不回退旧孔圈 | moment-bound-r2默认捕获/自由捕获通过；force-scale-r2指定模型真实近袋通过，确认捕获记录与无legacy pocketEntries断言保留 |
| 失败预算和输出保护 | entry-audit-r1预算分离通过；force-scale-r2未完预测不能击球/导出、可恢复有效结果通过；DR-276纯自旋解析尾段及事件上限保护经final-compatibility再次通过 |
| 规则与实际轨迹一致 | contact-regression-r1实际八杆实时/导出事件顺序及时间、同杆起点/末局、192静止采样帧逐一一致，57.338s。确认捕获与可见尾段分开，未用保存after强迫物理进袋 |
| 旧基准保持/合理改变/疑似回归分类 | W07-compatibility-audit：旧孔圈仅平面参考；微悬袋与失撑差异属于新模型；旧保存进球与新返回的消费一致性已验。独立W05旧原型极小尾步失败仍保留，按用户v63.12裁定不重新扩大袋底探索，不声称该原型已绿 |
| 普通远离袋口平面行为 | final-compatibility-r1的testFarTableKeepsPlanarMotionWithoutSpatialStepBudget以旧引擎为对照，位置/线速度/自旋/状态/事件数与无局部handoff断言通过，.916s |
| 理论评分不变 | 同结果中AngleCalculatorTests 7项、AimPointGeometryTests 7项、BTFeedbackTests 3项通过；不修改理论定义 |
| 搜索兼容 | 同结果ScoringOnlyConsistencyTests 6项通过：54/20组终态字段、12组新旧搜索完整帧/事件、自旋补齐和拒绝边界；固定网格不缩小 |

最后综合验证final-compatibility-r1/session43514终态0，实际24项/0失败18.927s；生产代码构建包含于各测试构建。最新force-scale-gate-r1/session67360终态0；diff-check/doc-size通过。入口曾出现的3项失败经DR-278/279分别修复，原始失败日志保留。

不外推：单袋真实材料/极端临界的实验校准、全平台视觉、VoiceOver、真机发热/FPS与性能、空间跳球/扎杆均无本批完成声明。W05旧原型失败与现有数值近似限制不得从记录删除。

FL-070最新诊断：默认球形五档新旧对照均settled；0.8/1.2/1.6m/s均进，2.4/3.3m/s仅新模型吐袋，方向一致。已定位首次反弹为皮革内壁；形状/响应合理性未裁定。见W07-working文末与default-speed-r2原始日志。该诊断1项通过不关闭旧默认进球失败。

后续对照：皮革e降至0仍返回；相同默认球形换现有marker方向后2.4/3.3均进但有袋角碰撞。下一步验证实际几何瞄准契约，不直接采用视觉标记中心；未修复/关闭原失败。证据见W07-working文末。

DR-281修复收集求根误把台面球判捕获。完整物理类当前40项中10项失败、22断言失败；原中袋部分进球为误捕获，旧通过证据不得直接沿用。局部回归实际4项通过，boundary-r2补验中，见W07-working。整体保持返工。

DR-281补验：capture-root-boundary-r2/session97595 exit0，实际2项0.004s通过：正常向下穿越/外侧拒绝及有在场邻球接触时延后捕获。联合前轮实际4项为6项定向验证。完整40项仍10失败；新求根下marker两档仍进（但吃袋角），并未因此采纳视觉点为物理真源。所有句柄终态；gate/doc-size/diff通过。

DR-281下八杆实时/导出复验capture-root-sequence-r1实际1项56.298s通过，192杆末帧及逐杆事件/起始球形一致；新67.23s视频已审7张抽样帧，范围见W08-working。普通物理10失败未关闭。

默认入口纠正：历史defaultLayout测试不是当前页面默认；真实PositionPlayViewModel初始化/后台求解1项1.250s通过（当前三球/1.5m/s/topRight，settled进球且捕获高度正确）。侧塞旧样例独跑最终settled，仅进球预期仍失败；见compatibility-audit。未关闭W07。

证据范围更正（2026-09-13）：ShotSimulationView.onAppear在setupScene后loadBoard(defaultBoard)，实际仍为(-.35,.22)/(.55,-.18)两球，页面力度为1.5m/s。此前“历史defaultLayout不是当前页面默认”的说法过宽：布局仍被该页使用，测试的3.3m/s与当前默认力度不同。currentPositionPlayDefaults测试仅证明裸VM三球初始化，不证明该页面覆盖后的默认进球；原失败保留，未关闭W07。

实际默认页r2/session37334 exit0：1项32.941s、0失败。默认击球后及3D回放后均命中生产“点选一颗目标球”状态且击球禁用；重打后恢复可击球。96DBC61E回放/47FF2037重打原图已审：回放后仅母球，重打恢复黑8及原默认球形。此处已补实际页面入口证据；没有改默认力度、物理系数或捕获边界。此用例的可见结果与状态通过，不替代原10项物理失败及连续袋口动画验收。两次测试均终态，无活跃句柄。
