# 正常清台开始与恢复：snapshot004准备

2026-09-08，Test Engineer。**仅草稿，未注册、编译或执行；0条新增通过结果。** 只新增本文及 `DailyClearanceNormalDiagnosticUITests.swift`，未操作设备、修改冻结源/业务或共享台账。

精确候选：`QiuJiUITests/DailyClearanceNormalDiagnosticUITests/testNormalAutomaticBreakReturnAndResumePreservesHUD`，预期选择 **1个方法**。按原SC23补正常开始/恢复UI，不替代完整清台诊断。

## 意图、已有证据与本次差异

- 有效意图来自 `docs/00-讨论记录.md`「2026-09-03：每日清台v52落地决策」、`docs/04-功能规划.md`§7及 `EXPECTATIONS.md` EXP-R05：未开始自动开球、有草稿恢复同盘；自动/重开不计用户杆数犯规；完成每日一次、再来不重复；草稿仅本机。
- 实际只读 `archive/quality-diagnosis/snapshot-004/source/` 下 `DailyClearanceController.swift`、`FreePlayView.swift`、首页清台按钮、`DailyClearanceControllerTests.swift`相关方法、`DailyClearanceRulesTests.swift`及 `V52DailyClearanceUITests.swift`。旧名为自动开球的UI方法使用 `fixtureSettled`，不能承担当次正常物理开球证据；旧 `TrainingJourneyDiagnosticUITests` 正常方法只断HUD存在与首页进行中，没有比较数值。
- 可复用的服务断言：`test_firstEntryStartsAutomaticBreakWithoutCountingShot`、`test_resumePlayingDraftRestoresBoardAndSeedWithoutNewBreak`、`test_resumeDeliveredBoardBeforeFirstShotRemainsShootableWithoutNewBreak`、`test_resumeFailedDraftRestoresBoardAndWaitsForExplicitRerack`、`test_completedDayWaitsForExplicitReplayAndKeepsCompletion`、`test_timerFlushIsIdempotentAndDoesNotCountBackgroundTime`。本次仅核读/引用，**未重新运行**，历史覆盖见B2及剩余审计。

## 正常旅程与断言

1. 主控先创建全新专用iPhone模拟器，留存UDID、运行时、普通字号/外观、安装及无旧账户材料证明。必须传 `QD_DAILY_BOUNDARY=NEW_DEDICATED_GUEST_SIMULATOR`、`QD_DAILY_DEVICE_UDID=<该新UDID>`、`QD_SHOT_DIR=<本run独立screenshots>`，兼容 `TEST_RUNNER_` 前缀。测试比对Runner的 `SIMULATOR_UDID`，不允许失配继续；如果宿主不暴露该变量，先记录环境失配，由主控核实安全等价来源，不直接删除guard。
2. 使用正常磁盘游客、跳引导、forceNonPremium、跟随系统外观。直接构造XCUIApplication，不调用会带 `resetDebugPremium` 的launchClean；无任意daily reset、清库、fixture、预填完成、seed固定、`fixtureSettled` 或deeplink。先正常“我的”验证 `profile.login`，再训练首页清台入口必须明确“未开始”。不符即保留证据停下，不能重置已有局。
3. 首页按钮完整frame必须位于实际TabBar上方且窗口内才点击；默认只面向底部TabBar的iPhone，不默默把iPad浮动TabBar当等价。HUD/球台/文案只读存在和数值，不要求其hittable。
4. 正常点击清台，让 `DailyClearanceController.start`→`beginNewAutomaticAttempt`→真实 `breakRunner.breakNow()` 执行。最长45秒候选等待是沿旧正常草稿的有界取证预算，不是SLA；超时先保存PNG/AX，不注入停稳、不换seed挤出通过。自动重试来自业务正常规则，最多3次；达到手动失败状态应保留为该次真实终态。
5. `dailyClearance.hud` 仅在非break模式展示，但失败也可能显示HUD，因此另要求球台存在、无 `autoBreaking`/`breakStatus`/失败 `rerack`/完成 `replay` 控件。解析当前明确AX格式：玩法、余球、杆数、犯规、mm:ss。自动开球后杆数=0、犯规=0、余球>0，玩法与初始首页一致；余球不硬编成15，真实开球可以进球。
6. 正常返回首页，入口为进行中且玩法一致；重进清台，不点击击球。再次核非开球/失败/完成状态，并逐项比较玩法、余球、杆数、犯规完全相等；用时允许增长但不能倒退。日志输出前后数值和单调时钟；不把等待期间差值定义为产品性能。
7. 每关键阶段PNG/同stem AX及xcresult附件保留；teardown先拍terminal再结束本App，不删除草稿/库。只有父控串行执行后的真实方法数、退出码、原始录屏/截图与视觉复核才能形成结果。

游客无凭证，不进入登录/购买/上传操作，无虚拟身份联网；运行前主控仍须按冻结配置核对不会访问真实账号服务（本测试不主动发网络请求，也没有全局断网措施），不能把游客UI断言等同传输层拦截。其余任务仍live时不得注册、安装或构建。输入/overlay/日志、PNG/AX与实际xcresult依004归档协议保存。

## 证据边界及后续必要分支

本候选只证明**真实自动开球后正常返回/重入的HUD字段保持**。不会声称实际赢局、真进程重启、球位置逐颗相同、没有再次开球的全部中间帧、独立数据库完全一致或tool统计无污染；同余球可能对应不同球形，后续可由独立只读草稿的seed/board键与坐标核对加强。截图用于核对真实盘面呈现，不替代坐标断言。未承诺45秒内业务一定停稳，AX等待可能受框架影响，失败须先审录屏/日志。

后续真实击球仍缺，按实际盘面一步一步操作，不预填完成：

| 分支 | 正常操作依据与执行方式 | 应核对 |
|---|---|---|
| 用户杆与犯规 | 真实自动开球停稳后，用FreePlay球桌选择目标/袋口及击球控件；先取实际AX/截图确认可操作状态。不要直接注入ShotFacts。 | `handleShotSettled` 每用户杆+1；依据当杆事实判犯规，单人不轮转；返回恢复保留新状态。 |
| 失败终态 | 中式八球真实提前进8球或犯规进8球；九球需犯规进终局球（普通错首碰或母球落袋是继续犯规，不能预期整局失败）。依据RulesTests相应独立规则断言；实际几何需从当次盘面确认，不能在未知坐标上盲点。 | `dailyClearance.rerack` 与失败原因；返回再入保持失败；点重新开球，如已有用户杆，应出现“放弃并重新开球”确认，取消保持、确认重置该局而不抹当日完成。 |
| 完成与再来 | 中式先清所属组再合法进8；九球合法先碰最低球并进9也可完成。可正常从偏好选择球数较少玩法后新开局降低成本，但不改变已进行盘、不改源/预填盘面。 | 完成页 `dailyClearance.replay`、首页今日已清台；再来需实际点击后新自动开球，已有每日完成保持且不重复授予；独立记录核对tool且不污染目标/准确率。 |

不能用 `testCompletedReplayPreservesCompletionAndStartsAnotherBoard` 的completed+fixtureSettled替代真实赢局链；该既有方法只能分层承担完成页再来操作。正常终局如果实际尝试受阻，记录到达状态和具体阻碍，由主控确定剩余受控证据，不默认全部转人工。跨日与后台计时的已有注入时钟方法可复用，不改系统时间、不等午夜，也不重复造相同服务反例。
