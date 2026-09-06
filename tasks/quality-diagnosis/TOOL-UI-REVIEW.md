# B4 工具与认知 UI 草稿审阅

状态：2026-09-05，仅基于 snapshot-002 源码编写。**未编译、未运行、未操作模拟器，不能计为覆盖通过。** 主控独立审阅并执行；本子任务只写本文件及 ToolDiagnosticUITests.swift。

## 执行边界

- 10 条测试均从正常「练习」Tab → 分类 → 卡片进入，无 deeplink、无预置成绩、无强制角度。
- 使用 `launchClean` 的中文语言与已完成引导前提，额外 `-v50.inMemoryStore -forcePremium`。六认知页面共享限额不应阻止功能检查；不证明购买、免费额度或恢复购买。
- 内存容器仅隔离 SwiftData；UserDefaults 不清理，主控须使用诊断专用模拟器并记录其状态。测试不切账号、不发起购买、不连真实数据后端；launch 自身既有网络行为须由主控总体环境管控。
- 不复用 P5 的硬编码截图输出，不调用录制、保存序列、批量出片台或资产生成。截图用 `QD_SHOT_DIR` / `TEST_RUNNER_QD_SHOT_DIR`，每图带测试名、阶段、UUID，附件 keepAlways；I/O 失败抛出而非吞掉。
- 可以将新文件仅复制到冻结快照测试目标。新增测试文件指纹属于诊断叠加层，业务指纹保持不变。串行 UI；禁用 parallel-testing，不向 Simulator 发送 CUA 操作。

## 10 条 selector 与实际断言

前缀 `QiuJiUITests/ToolDiagnosticUITests/`。

| 方法 | SC | 正常操作与核对 |
|---|---|---|
| testAnglePredictionAnswersAppearInHistory | 19 | 先证记录空态；随机角度答 17/28/39 三题→返回→记录→角度预测明细，核对3题、#3存在/#4不存在及三项输入数值可见，再返回记录 |
| testAngle2DAnswerAndNext | 19 | 正常训练设置→开始训练→输入45→结果可下一题→下一题可答→返回练习 |
| testAngle3DAnswerAndNext | 19 | 同上，3D卡片正常入口，forcePremium只作功能前提 |
| testAimPointSubmitAndNext | 19 | 默认偏移提交→正确偏移反馈→下一题可提交→返回 |
| testAimPoint2DSubmitAndAdvance | 19 | 默认瞄准提交→提交按钮消失→物理验证后下一题按钮恢复→返回 |
| testAimPoint3DSubmitAndAdvance | 19 | 同上，3D正常入口 |
| testShotSimulationStrikeAndReplay | 20 | 默认球形→回放初始禁用→击球→停稳回放可用→回放→击球恢复→返回 |
| testFreePlayStrikeAndReplay | 21 | 默认母球+1/2号球击球与回放同上；未走开球玩法 |
| testBankSolverModeStrikeUndoReturn | 20 | 正常翻袋卡→求解切自由→击球→上一杆可用并撤回→切回求解→下一解存在→返回 |
| testReflectionSolverModeStrikeUndoReturn | 20 | 正常反射卡，模式/击球/撤回同上 |

角度预测只证明同进程真实页面答题的结果进入记录 UI；**不证明磁盘持久化、跨进程、同步、事务原子性**。三项数字显示目前未绑定每行的「你答」父容器，实际角度偶然同值可能造成弱断言；运行取得 AX 层级后应把值与对应题号/你答列绑定，或由独立存储探针补强。未把内存测试称为磁盘保存通过。

## 源码依据

以 `build/quality-diagnosis/snapshot-002/` 为根：

- `QiuJi/Features/AngleTraining/Views/AngleHomeView.swift`：六认知卡片、学/理/练/打/解身份、会员入口和页面路由。
- `SceneAimingView.swift`：初次必弹「训练设置」，按钮「开始训练」；答题→提交→下一题。不能沿用旧 P5 点卡即认为已训练。
- `GeometricAngleQuizView.swift`、`AimPointTrainingView.swift`：结果与下一题文案；`AimPointSceneTrainingView.swift`：提交后1.5秒自动物理验证并自动下一题，故不强依赖短暂误差标签。
- `AngleSessionDetailView.swift`：题目明细、N题、#序号、实际/你答值。`HistoryCalendarView.swift`：认知行标题取会话快照。
- `SolverStageChrome.swift`：`solver.mode`、自由态击球、上一杆、求解态下一解。切模式不要求默认盘面必有解。
- `Core/Components/BTShotPageChrome.swift`：瞄准模式 AX 标签、击球/回放/上一杆文字按钮。
- `PositionPlay/ViewModels/PositionPlayViewModel.swift`：setupScene正常默认母球+1/2号球；`ShotSimulationView.swift` 自带 defaultBoard。无需注入录制球形。

## AX 与测试可靠性待实测

1. 卡片用现有 identifier，模式用 `solver.mode`；很多动作生产代码无 identifier，因此草稿使用精确中文标签。记录行与结果文字可能因 SwiftUI AX 合并而变化，若失败先导出 AX 和附件，判别脚本前提问题，禁止跳断言或改业务喂绿。
2. `navigationBars.buttons.firstMatch` 依赖正常 push 返回按钮排序；运行检查确实返回原分类和原卡片。不能凭点击动作判成功。
3. 滚动最多5次且最终必须可操作；等待条件为 exists+hittable+enabled，无 guard-return 假通过。
4. 场景瞄准自动下一题用按钮消失→恢复验证状态推进；不证明球几何正确、问题已变化或成绩保存。屏幕呈现须结合截图，若需题号断言先依据真实 AX 取证。
5. 回放后击球恢复断言不证明动画的每帧或重放轨迹一致。默认球形与用户偏好可能影响是否可击球；失败必须保留真实环境与前提，不擅自注入成功状态。
6. 等待上限是观察窗口（SceneKit 35/45s），不是性能验收阈值。超时不能直接宣称性能缺陷。

## 尚未覆盖

- SC19：除角度预测外五种成绩保存/取消/重复结束/保存失败；角度预测输入到记录的逐行严格对应、真实磁盘恢复。默认瞄准提交未覆盖拖动手势。
- SC20：求解无解/多解切换、独立物理方向/反射/标签真值、真实/理想模式、力度打点改变、球形撤回前后数值一致。当前求解器测试只证明自由试打往返。
- SC21：自由走位编排、开球游戏规则/seed、下一杆、进袋、球数ID/终位、撤回；草稿只覆盖自由击球正常击球与回放。
- **SC22：本10条中未覆盖思路训练、打一走二想三、防守。** 这些需要定义可行与无解球形、正常摆球前提和可核对结果，不能用点入标题冒充完成。建议第二轮独立用例准备，不将此批记为SC22通过。
- 拍照建球形：真实相册/相机权限及导入另行测试；本批不触发权限。
- 全部截图需要主控视觉审查；没有截图就不能称屏幕完整呈现。M3/iPad、动态字体、VoiceOver、真机性能留后续矩阵。
