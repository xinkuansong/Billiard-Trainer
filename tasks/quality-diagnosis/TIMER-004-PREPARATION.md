# 正常训练计时诊断准备 — snapshot004

2026-09-08；Test Engineer。**草稿未注册、未编译、未运行**。只新增诊断文件，没有改业务/snapshot 或操作设备；主控 UI 批结束后才能串行注册执行。

## 产品意图与证据边界

- `问题集合_v48.md:85–94` 仍明确 Q-v48-1（累计是否排除休息）等为待拍板，推荐不等于结论；定向核对 `docs/00-讨论记录.md`、`tasks/IMPLEMENTATION-LOG.md`、`tasks/UI-IMPLEMENTATION-SPEC.md`、数据契约，未发现对应最终 D-v48 裁定。**本次不判定休息应计入还是排除训练累计**，不按当前实现自封产品预期。
- `问题集合_v57.md:121–133` 2026-09-06 真机反馈：数字可正常倒计时，现象集中于进度/岛布局；未提供该次完整版本矩阵。普通模拟器 UI 不能替代真实锁屏 Live Activity 验收。
- `tasks/IMPLEMENTATION-LOG.md:207–210`：休息最小化只收起休息卡，人留在训练记分页；整场最小化才使用跨 Tab 浮标。DR-094 后续带时间胶囊隐藏可见标题，但 AX 完整说明保留。草稿使用精确标识 `activeTraining.restPill` 与 `minimizedTraining.resume` 区分两者。

## 已有判例复用

- `ActiveTrainingViewModelTests` 已有 `test_pauseTimer_stops` / `test_toggleTimer` / 跳过恢复等启停属性测试；不证明正常 UI 暂停读数保持或真实前后台。
- `test_restActivity_repeatedExtensionsPreserveStartAndPublishLatestTotal` 等覆盖 +30、总时长、截止时间、缩短及过期不复活，注入的是 Live Activity recorder；不要重造同一服务层判例来冒充 UI/系统活动。
- `V51ResponsiveLayoutUITests` 休息最小化与长计时浮标用 fixture 验布局/恢复。本次从训练首页正常自由训练添加动作，**不使用 activeTraining / minimizedTraining / elapsedSeconds fixture**。
- 正常自由训练入口复用 `QualityDiagnosticUITests.createNormalTrainingAndReopen` 的已有源：freeTraining → 添加中袋直线出杆 → 完成(1)。原长旅程已有其他数据问题，本次不重复填成绩/保存来求绿。

## 待执行方法：1 项

`QiuJiUITests/TimerJourneyDiagnosticUITests/testNormalTimerPauseResumeMinimizeBackgroundAndRestExtension`

源：`tasks/quality-diagnosis/TimerJourneyDiagnosticUITests.swift`。

流程：游客登录入口前置 → 正常自由训练选动作 → 初始 00:00:00 / 继续计时 → 开始并确认走秒 → 暂停短等读数精确不变 → 继续确认走秒 → 整场最小化/浮标恢复 → Home 短后台/activate 前台 → 进入休息 → +30S → 休息卡最小化/倒计时继续 → 展开/完成休息 → 更多/结束/确认 → 训练心得结束阶段。

预计 9 个阶段 PNG 与 AX：running、paused-unchanged、session-minimized、session-restored、foreground-time-restored、rest-extended、rest-minimized-ticking、rest-finished、training-ended-note-phase。测试未运行，不能先认定图数或状态通过。

时间方法：每次 AX 读值以 `ProcessInfo.systemUptime` 前后包围，输出原标签与秒值。暂停后对两个读取值做**精确相等**；运行/恢复阶段将变化与实测单调时间区间对照；休息 +30 阶段以 `30 - 实际经过时间` 为预期差，其他休息段以负经过时间为预期差。边界额外 2 秒只由整数化 1 秒与页面 tick 显示滞后 1 秒组成，不是宽百分比或任意 0–30 秒范围；另保留真实走秒/倒计时变小断言。3/4 秒等待是观察窗口，不是 SLA、固定结果值或设系统时间。

## 隔离、风险与尚未覆盖

- 独立游客模拟器、memory store、forceNonPremium；不登录、不联网 API，不改系统时间；不重置真实库。此用例会真实触发专用模拟器的本地休息服务/Live Activity 请求，但只断言 App 页面。
- 使用默认已存在的休息时长。+30 测量前断言正数；若 AX 操作耗时已超过原休息截止，不放宽到负值或跳过失败，应归档判断环境/测量不可用并独立续测。
- 休息展开时，读取的是后方顶部 `activeTraining.rest` 的 AX 标签（并不点击被遮挡按钮）。这是源审查方案，运行时若系统隐藏该节点，应保留失败与 AX，改用实际可见倒计时定位；不能新增业务 test hook。
- 累计钟比较全部在进入休息之前完成，避免未决累计口径影响结论；后台场景当前为普通训练运行态，**休息后台/锁屏、到零、过期 +30 及系统活动解除未在此方法验收**。
- 结束到“训练心得”证明已走结束确认且退出计时页面。此方法不保存零完成组、不宣称磁盘计时保存、结束后台任务完全清理或真实 Activity 消失；后者需分层补证。
- 主控先独立审查源并注册，精确选择 1 方法、禁 UI 并行；归档真实 exit/xcresult/截图/AX/单调日志与源码哈希，失败不修改业务或削弱断言。

静态文本检查：`git diff --check` 对两份新增文件无输出、exit 0；没有 Swift 编译结果。
