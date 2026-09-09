# snapshot004 正常课程完成与 A→B→A 续接准备

2026-09-08。仅新增本说明与 `PlanContinuationDiagnosticUITests.swift`，未注册snapshot、未生成工程、未编译或运行；候选源码须主控全文审核后才执行。本子任务未操作设备，不改生产/正式内容/共享台账，不提交。角色 Test Engineer，遵循55规则与诊断only边界。

## 测试目标与有效预期

- EXP-T01及v57§2.1：每owner唯一官方主线，同计划复用记录，A→B→A保留A游标；B不覆盖A进度。
- EXP-T03与内容数据契约§9.2.4–6：仅completed且advanceEligible连续前缀推进；入队/开始不推进；保存session携带冻结来源与效果。
- docs/05 v54导航：正常激活→编排当前课→加入今日→开始；课程完成后下一课当前，第一课已完成，第三课未开始。
- 使用snapshot004业务与正式JSON，不依赖HEAD之后的并行修改。PlanDetailView的编排行标签直接包含“课名，状态，已选择/未选择”，本例以该可见UI作为游标投影oracle。

本候选聚焦正常完整课程及游标UI。已有 `V54ScheduleDomainTests/test_v57_switchRestoresCursorAndIsolatesOwners`、`test_v57_failedSwitchRestoresSavedAndInMemoryState`、`test_v57_failedFirstActivationDoesNotLeaveAnActiveDraft`、`test_persistentSettlement_handlesReverseOrder_finalCompletion_andReplay` 覆盖服务/错误/逆序反例；不为本新旅程再全跑171方法。数据库ID唯一和跨owner仍依赖独立服务证据，UI不伪称直接读到数据库。

## 为什么真实填15组

核对 `snapshot-004/QiuJi/Resources/Plans/plan_beginner.json`：免费计划基本功首课 `plan_beginner.stage01.lesson01`，课名“中底袋直线出杆”，c012/manual01 8 rounds、c009/manual01 7 rounds，两动作均重复型15球。第二课“底袋直线出杆入门”，第三课“底袋直线出杆检验”。计划与组UI实际剂量先断言，不能凭标题假定短课。

可见首课无法正常选成单组而仍保持原完整课程定义。本方案保留15组，每组真实输入15/15、点数字键盘“完成”，分别独立验证总览：

| 动作 | 预期完整组数 | 预期总览进球/总球 |
|---|---:|---:|
| 中袋直线出杆 c012 | 8/8 | 120/120 |
| 底袋直线出杆 c009 | 7/7 | 105/105 |
| 全课 | 15 | 225/225 |

计时不要求真的等训练95分钟；人工录入成绩并不由时长门禁定义完成。仍如实记录本例未证明计时真实性，也不是实际打225个物理球。没有减少组数、删除动作、改剂量、seed已完成或提前结束。先全组完成才走结束训练→心得跳过→保存，故不重复QD012“只录一组就结束”的同质输入。若此全组路径产生新错误则保留差异，不以已知QD012解释所有失败。

## 唯一候选选择器与流程

`QiuJiUITests/PlanContinuationDiagnosticUITests/testCompleteAllFifteenSetsThenSwitchBackPreservesSecondLesson`

1. 专用guest模拟器，`-v50.inMemoryStore -forceNonPremium -v51.followSystemAppearance`，核对游客入口与空历史。不预置计划/成绩，Pro强制免费仅避免历史模拟开关污染，A/B两个计划均免费。
2. 正常训练首页卡片→基本功→开始此计划→确定激活→编排今天。断言首课当前已选且将加入1项，实际加入，然后首页“开始这节课”。
3. 用真实总览按钮定位两个动作。每组输入前确认唯一可见“第N组进球/总球”字段且总球15；键盘1、5→字段15→完成。实际出现休息时点完成休息。最后一组会自动切下一动作，不再点击已完成勾，避免反向取消。
4. 两动作全组总览验证后才结束；训练心得收键盘/跳过→保存一次。不重复保存；如保存后实际显示完成按钮则点一次退出。等待首页可操作。
5. 重进A编排器，精确断言“中底袋直线出杆，已完成，未选择”“底袋直线出杆入门，当前，已选择”“底袋直线出杆检验，未开始，未选择”，截图后取消，不入队下一课。
6. 回首页→免费B `plan_accuracy`（准度Ⅰ·近中台）→切换到此计划/确定激活→编排器“近台小角度入门，当前，已选择”；取消，不训练B。
7. 回A→切换/确定激活，重复步骤5的三课状态精确断言，正常取消返回。证明UI投影没有跳回首课或额外进第三课。

## 运行前提与副作用

- `TEST_RUNNER_QD_PLAN_CONTINUATION_AUTH=DEDICATED_GUEST_SIMULATOR`；输出通过runner唯一 `QD_SHOT_DIR`，PNG/AX采用run UUID+阶段且withoutOverwriting，15个组确认逐步存证，失败teardown截图。
- 同进程内存store：不要求占用主控认知磁盘设备，可在单独闲置诊断guest设备执行；UI仍必须全机串行。偏好/模拟Pro开关等可能写独立App沙盒，inMemory不等于无副作用。不得用真实账号设备。
- 不使用deeplink、业务fixture、网络登录、购买、录制、导出正式资产或SQL。未调整业务时间/组数/课程内容。
- 精确选择器只此一方法，必须检查实际非零执行数、make/xcode退出、输入hash、图片和AX后决定结果。所有源码/资产仍应与snapshot004基线相符。

## 已审实际实现与剩余适配不确定性

已读 PlanDetailView 的主CTA、激活alert、arrangementSheet精确标签和lessonStatus；ActiveTrainingView正常开始/结束/summary回调与overview；ActiveTrainingViewModel completeSet最后组自动换动作、hasStartedTraining含已完成组；DrillRecordView、BTExerciseRow总览精确逗号标签、BTSetInputGrid的完成字段转静态文字和键盘确认即完成；TrainingNoteView及TrainingSummaryView的真实完成/保存交互。两枚计划名称/首课/第二课均反查冻结JSON。

本草稿尚未运行，真实AX仍可能有适配差异：TabView后台页可能保留同名字段，故只选isHittable且要求唯一；多组滚动每字段最多10次，首页回顶8次及找卡最多16次，均有界而非失败后无限重试；实际数字键盘、休息浮层、总结返回若不符预期须保留原证据后定性。主控曾有正常保存后停留“完成”的观察，候选允许实际存在的完成按钮一次正常退出，不允许再次点保存或省略首页返回断言。

本方法不直接读回历史225/225、数据库session数量/owner唯一active，也不含杀进程。不能据此独立关闭SC04/07的磁盘层。建议主控优先作为当前缺失正常UI证据执行一次；若通过，必要的磁盘/历史来源读回可以另做专用磁盘同链或只读宿主观察，不能在当前内存方法末terminate/relaunch后称磁盘恢复。若UI完整课程已明确失败且链路中断，不要求为凑A→B→A通过改生产/降低完成定义；保存原进度并继续其他可执行领域。
