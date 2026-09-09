# SC08 模版拒存、长名与磁盘重启准备

2026-09-08；独立待审草稿。仅新增 `TemplateBoundaryDiagnosticUITests.swift` 和本文。未注册、构建、运行或操作设备，不能计为通过。语法解析 `xcrun swiftc -frontend -parse tasks/quality-diagnosis/TemplateBoundaryDiagnosticUITests.swift` 退出 0，不等于类型检查。

精确 selector：`QiuJiUITests/TemplateBoundaryDiagnosticUITests/testInvalidDraftsLongNameAndOneDrillTemplateSurviveProcessRestart`，1 方法。无需重复既有模版录分/删除后历史冻结旅程。

## 输入、隔离与操作定义

主控提供新专用普通磁盘游客模拟器。环境（或 TEST_RUNNER_ 同名）：`QD_TEMPLATE_BOUNDARY=NEW_DEDICATED_DISK_GUEST_SIMULATOR`、`QD_TEMPLATE_DEVICE_UDID=<新设备 UUID>`、绝对 `QD_SHOT_DIR`。UDID 必须与 runner 的 `SIMULATOR_UDID` 匹配；无法读到则停止。该授权值不能自动证明设备新建，主控仍须保留创建记录。启动不用 launchClean/reset/inMemory/auth fixture，不写 store、不删除用户库。每次启动正常“我的”核游客模式与无 accountHeader，然后训练→我的模版。初始要求可见“还没有模版”且真实 UUID 编辑卡数为零。

1. 新建空草稿：保存 disabled；正常添加 `drill_c037`“走位基础”，实际选中控制“取消选择走位基础”出现、关闭搜索、完成(1)，看到“3 组  1 动作”；名称保持空/placeholder，保存仍 disabled。正常返回，货架仍空。该阶段隔离空名条件，不把“两个都空”当充分覆盖。
2. 再新建，无动作输入长名 `长名称模版边界` × 8 + 本次 UUID 前 8 位，共 64 个字符。精确 field value 必须匹配、键盘正常收起；保存仍 disabled，留图审长名与返回控件，正常返回且货架仍空。该阶段隔离无动作条件。64 是有界展示压力样本，不是臆造产品上限。
3. 再新建，同长名 + 正常选入 c037，保存 enabled→仅保存→真实退出 builder。货架必须恰有一个 UUID 编辑卡、AX 含全名；进入编辑核全文和 c037/3 组 1 动作。正常返回，terminate→确认 notRunning→同设备普通磁盘重启→再次游客→同一个 UUID、全名及动作/剂量保留，编辑页可正常退出。仅保存，不加入今日、不训练、不删除。

## 定位依据与待现场适配处

冻结根：`archive/quality-diagnosis/snapshot-004/source/`。

- `QiuJi/Features/Training/ViewModels/CustomPlanBuilderViewModel.swift:60–62` 的 canSave = 名称 trimming whitespaces 后非空且 drillItems 非空；`:176–180` 保存自身也检查这两项。没有已核名称长度上限。因此 UI 禁用是实际拒存机制，不强行点击 disabled 项冒充 API 拒绝测试。
- `QiuJi/Features/Training/Views/CustomPlanBuilderView.swift:44–49`：新建/编辑导航标题、隐藏 TabBar、保存工具栏；`:113–120`：placeholder 我的模版、ID customPlanNameField、实际剂量汇总；`:238–259`：保存 Menu 的仅保存/保存并加入今日安排、disabled 条件。
- `TrainingHomeView.swift:1775`：空货架“还没有模版”。既有 TemplateContinuation/TodayQueue 的真实 UUID 编辑卡 `trainingHome.template.edit.<UUID>`、排除装饰 `list.bullet.clipboard` 的新建入口、搜索走位基础→关闭→完成(1) 为复用经验。
- 名称每次只向新建空 field 输入，不清旧文本、不假设光标位置。若出现实际已知 iOS “Speed up your typing”引导，仅按其 Continue 处理。未出现时不盲点。按正常回车收键盘，未收起则失败保留证据。
- Toolbar 保存此前有实际 AX isHittable 不可靠情况，本草稿仅在真实 navigation bar 包含启用控件完整 frame 时点其测量中心；BackButton 沿实际导航标识。若现场类型/标识不匹配就停止，不猜屏幕坐标。首页滚动选实际唯一外层纵向 ScrollView，短幅滚动并保留目标在真实导航与 TabBar 之间的完整 frame。
- “3 组  1 动作”为源码字符串及 c037 剂量；若 AX 合并/空格归一化导致不能直接读到，先保留原 AX，再做等义精确适配，不把它改成只判动作存在。

## 证据边界

既有 `QiuJiTests/CustomPlanBuilderViewModelTests.swift:38–62` 已有 `test_canSave_empty_name`、`test_canSave_whitespace_name`、`test_canSave_empty_drills`、`test_canSave_valid`，`:161–175` 另含名称 trim/空名保存失败。本次只读测试源，没有重跑；新方法补真实 UI 拒存及进程重启，不重复把这些判定写成新单测。

每个前置/业务验收失败都 throw，teardown 先存 PNG+AX 再停止 App。阶段图带 review-required，不用 AX 全文或运行通过替代人眼检查长名称的可辨认性、截断、控件遮挡。允许单行字段/卡片合理截断；本方案不要求 64 字同时肉眼全显，但必须能正常进入编辑、保留完整值、退出。若实际视觉异常，独立记录产品问题并保留截图。

进程重启要求旧进程 notRunning 且同 UUID/内容读回；不是设备重启、SQLite 外部审计或跨 owner/跨设备证明。无真实账号、无联网业务操作；普通游客启动不构成全 App 零网络保证。测试保留新设备及新建记录供主控查证，不做清理。既有创建/编辑/录分/删除冻结结果依原文档引用，本草稿只补这些剩余边界。

主控审阅后适配：依据新模拟器实际异步键盘引导，两处 intro 分支等待出现最多 2 秒；出现则确认唯一 Continue 后点击，等待 intro 消失最多 8 秒才输入。仅此两处前置稳定性调整；再次 Swift parse 退出 0，未注册/构建/运行。
