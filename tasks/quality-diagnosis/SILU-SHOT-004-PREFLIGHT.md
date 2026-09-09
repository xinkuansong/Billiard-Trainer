# 思路矩形正例：下一解、实打与上一杆

2026-09-08；独立 Test Engineer 草稿。只新增 `SiluShotDiagnosticUITests.swift` 与本文；未注册、构建、运行、操作设备、修改业务或共享台账。语法 parse 退出0，不是类型检查或运行通过。

Selector：`QiuJiUITests/SiluShotDiagnosticUITests/testObservedRectangleNextSolutionStrikeAndUndoRestoresBoardAndSolutionIndex`。

## 复用与范围

已读 TOOL-CONSTRAINT-004-PREPARATION/RESULT、已跑 SolverBoundaryDiagnosticUITests 的思路矩形/落点及三球实打撤销方法、冻结 SiluTrainerView/ViewModel 相关动作/收尾/恢复逻辑、positive001 原始AX和make.log。原思路矩形1/1、34.381s返回解1/5（低杆2.1、不吃库、余量15cm），随后清约束；未实际下一解或击球。followup001 三球已经实打/上一杆，不重跑。本条只用该**一个**思路矩形，不搜新盘，不降级到近似/翻袋分支。

原make.log证实设备 `401DEA72-01DD-46C2-B774-86B7D58BC06C`，402×874。保留正常练习→解→思路训练；forcePremium只是功能门控隔离，inMemory保护训练数据，真实guest校验，无board/deepLink/result注入。黄球_1实际外层frame中心(176.35,394.65)，左上袋实测(71.6,201)，矩形(105,310)→(295,640)。黄球先按当前实际_1外层中心并要求与旧中心≤2pt；袋和绘制点仅用于原已观察设备/尺寸，不能移植到其他设备。屏幕点不是世界米制坐标，不额外预测落点或精度。

## 主控前置

- 使用原隔离设备/相同普通字号外观，保留实际安装和配置读回。不能因为尺寸相同就使用其他设备或被污染盘面。
- `QD_SILU_SHOT_AUTH=EXISTING_004_RECTANGLE_DEVICE_NORMAL_UI`。
- `QD_SOLVER_DEVICE_UDID` 精确上述UUID，并匹配实际SIMULATOR_UDID。
- `QD_SHOT_DIR` 绝对根；新建 `silu-shot-<UUID>` 叶目录，env均支持TEST_RUNNER_前缀。
- 主控应连续录屏并按本次终态图审，不以按钮变化代替动作画面。没有修改求解/物理参数，无真实账户操作。

## 强链与恢复依据

1. 初态游客→正常思路入口→旧黄球与袋→真实画矩形→严格“已就绪，点「求解」反解走位”。原图/AX同stem留存用于对比选择袋和矩形。
2. 求解一次，最多120s观察上限（不是SLA），要求解1/N且N≥2，下一解/击球可用，拒绝最近解/翻袋分支。不硬编码旧5解，因为数量不是需求；没有至少2解则明确本包未建立，不能跳过下一解成功。
3. 下一解一次→解2/N，保存摘要与cueBall/_1击打前外层frame，要求上一杆/回放disabled。`SiluTrainerViewModel.nextSolution:533` 按index循环并清draft；本次不微调。
4. 点击击球一次，最多90s等待**源码明确终态**：“已击打 · 母球停在终点，可继续画约束再求解”或“母球进袋（scratch）· 重新摆母球或「恢复默认」”，且上一杆enabled；击球/下一解disabled，因为收尾清旧解/约束。`finishPlayback:1030–1066` 是此真实语义；不能套用三球的①进袋提示。
5. 上一杆→精确“已退回上一杆击打前 · 球形/约束/解已还原”；两原球ID实际ball-sized外层frame恢复至各自击前中心和尺寸≤2pt，击球/求解/下一解可用，上一杆/回放disabled。`undoLastShot:813–822` 消耗上下文，`restore:835起` 恢复snapshot.before、目标/袋、draft、solutions/currentIndex及参数。截图完整复核区域/目标袋/轨迹/杆法恢复；UI提示本身不证明全部内部字段。
6. 因undo把摘要换成解释文案，再点一次下一解，严格显示解3/N（N=2则解1/2），**未再求解**。这是恢复second-index的独立可观察证据，不从“已还原”文字推定index正确。
7. 当前导航栏唯一BackButton返回正常解首页；未知控件失败取证，不猜首按钮。

每阶段PNG先于完整AX；捕获击前、终态、恢复、索引探针。失败先取证，teardown再捕获后只terminate，保留沙盒。工具按钮必须唯一、实际可点且全框在window内；主页目标完整clear TabBar且按真实上下边界短幅滚动。所有控制等待有界，无静默if跳过必需动作。

## 证据边界

末杆可能scratch；草稿保留明确分支并仍检验上一杆恢复，不能将scratch终态称满足落区。实际是否进目标袋、最终停点是否在矩形、轨迹与红袋标记一致，要依连续录像与完整图审；不以solver满意声明推定实打一定达标。_1隐藏mesh可能保留AX小frame，严格取同key首个语义外层并要求<30pt；不要求所有旧mesh不存在。2pt只是恢复屏幕投影重复性，不证明毫米物理准确度。本包不核销完整空解/扇形满足/物理金样或整个SC22。
