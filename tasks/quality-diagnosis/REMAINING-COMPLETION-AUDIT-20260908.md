# 剩余覆盖与完成条件独立审计

2026-09-08，QA Reviewer，只读审核后写入本文件。未运行测试、构建或操作设备，未修改实现及共享台账。本审计不是 Phase 验收，不宣告总目标完成。依据 PLAN-v2、COVERAGE-PLAN 原38场景约定，重点审计 SC04/06/07/08/10/19/23/24/32/33/36。主控正在执行学习 remainder002 六项，不计为本文通过结果；完成后按真实终态核销。认知五保存与六入口未提交退出草稿已全文审核，但尚未注册或运行。

## 当前证据怎样使用

已读 COVERAGE-STATUS、README 9月8日末尾、CURRENT-REMAINING-SELECTORS、REMAINING-LOCAL-WORK、B2-UI-RESULT-REVIEW、PERFORMANCE-REVIEW。旧文档首页的“未执行/运行中”不是最新终态；已记录的历史实测保留，旧原始 build 不可用另记证据限制，不能改写成从未测试。新004的通知允许/拒绝/重试/关闭取消、搜索收藏已有主控记录，不重跑来增加数量。学习截至 remainder001 累计10个方法，9通过、1菜单关闭坐标失配；原关闭点击(201,78.66)落在实际菜单x144…394/y62…152.3内，已证实为测试参数错误，保留原失败。

实际读取下列测试方法体，而非仅按名字推荐：V54ScheduleDomain、V54TrainingTransaction、ActiveTrainingViewModel 休息相关、DailyClearanceStore/Controller/Rules相关、V29W5CognitiveToolSession 的重复保存、P7_SubscriptionUITests、TrainingJourney、MenuHit、CognitiveJourney 未提交方法、Performance 全文。六份核心单测文件与 snapshot004 逐字节比较一致（V54ScheduleDomain、V54TrainingTransaction、ActiveTrainingViewModel、DailyClearanceStore、DailyClearanceController、V29W5CognitiveToolSession）。这只证明所审源码一致，不恢复旧运行原件，也不等于这些方法当前已重跑。

以下精确选择器写为 `类/方法`，UI 前缀 `QiuJiUITests/`，单测前缀 `QiuJiTests/`。tasks 中候选必须由主控核对 snapshot004 注册和运行清单；本文不注册或预记成功。新增类型指尚需设计的断言，不能直接作为命令执行。

## 重点场景：必须补的层与可复用证据

| 场景 | 已有证据或实质断言，不必整组重跑 | 仍须本机执行的有界缺口 |
|---|---|---|
| SC04 主线 | `V54ScheduleDomainTests/test_v57_switchRestoresCursorAndIsolatesOwners` 真正调用 A→B→A，验证原ID/第三课游标与另owner不变；`test_v57_failedSwitchRestoresSavedAndInMemoryState`、`test_v57_failedFirstActivationDoesNotLeaveAnActiveDraft` 验保存异常后无错误active。这是服务/内存层，已有历史B2，不是正常UI。 | 先 `TrainingJourneyDiagnosticUITests/testNormalOfficialPlanActivationArrangementAndStart`（确认激活、编排加入、首页0/1、开始计时）。再新增同一连续正常UI中推进一课→B→A→当前课不回退；以独立记录核对owner唯一active。已有失败回滚无需重造完整UI错误注入。 |
| SC06 今日编排 | `test_service_freezesRoles_deduplicatesUnfinished_andAllowsRepeatAfterCompletion` 检查eligible/preview及未完成去重；`test_reorderDoesNotChangeFrozenRole_andStartedItemCannotBeDeleted` 实际排序两动作且开始后删除被拒；`test_crossDayArchivesWithoutAutoCarry_thenCopiesFreshItems` 用注入时钟验证次日空队列、显式带入新ID。 | 新增一条三源正常UI链：上述计划课+新模版+库动作入队，重复加入不增、排序、删除一个pending、开始另一个。跨日服务已有，不要求等到午夜；若UI日期投影仍缺，以专用夹具明确标注，不改系统时钟。 |
| SC07 课程推进 | `test_progressRules_reverseCompletion_switchAndTwentyReplays`、`test_persistentSettlement_handlesReverseOrder_finalCompletion_andReplay` 验逆序先不进、补前课后连续进2课、20次重复不再进及最终完成；后者虽名persistent，不能据名字称杀进程磁盘。 | 与SC04共用一次正常课程非零成绩保存→历史来源→主线下一课连续证据，不将fixture已完成卡替代。跨缺口preview/复练的边界由已有服务断言承担；若当前课程保存复现明确缺陷，记录影响与链路中止点，不反复硬跑到绿。 |
| SC08 模版 | 旧UI只开编辑和菜单幂等；`test_v57_projectionReopensDiskStoreAfterTemplateDeletion` 确实临时磁盘写入、改源/删源、重开，验证队列payload冻结，但不是历史记录真实删除前后。 | `MenuHitDiagnosticUITests/testTemplateEmptyShelfCreateSaveAndReopen` 可复用正常创建唯一名+c012、仅保存、重开字段。新增同份模版改名/剂量→保存→加入今日→完成一项→删模版→历史来源快照保持；另空名/无动作/长名各一次，按当前有效规格先定期望，不自拟长度。用专用磁盘环境收重启读回，不能把原内存方法外推。 |
| SC10 计时 | `ActiveTrainingViewModelTests/test_restActivity_repeatedExtensionsPreserveStartAndPublishLatestTotal` 验2次加30、起点保持及169秒；缩短/过期方法验证边界，但LiveActivityRecorder是替身。旧UI只有最小化恢复局部。 | 新增一条正常UI：开始计时→暂停→短等待读值不变→继续→进入休息→加时→缩小/恢复→短后台→前台→结束，记单调时间与UI值。先查当前休息计入训练时长的最终裁定，不能按实现自封正确。锁屏/真LiveActivity转外部层，普通模拟器前后台仍本机可做。 |
| SC19 认知 | 角度预测三输入历史已有；五个认知保存候选及六入口未提交方法已备。`V29W5CognitiveToolSessionTests/test_retriedSave_keepsOriginalSessionId` 第二次save同一对象，验证一个session；**没有真正注入首次失败**。 | 执行已审但尚未注册/运行的五保存+六题型未提交退出候选批，每题型核对真实记录数/类型/结果。`CognitiveJourneyDiagnosticUITests/testSixCognitiveEntriesReturnWithoutSubmissionAndLeaveHistoryEmpty` 不点提交、每次返回查看空史，共六题型；它不是磁盘0断言。补共享repository的重复结果ID数量与受控首次失败后重试断言，复用已有四VM错误测试作分层证据，不要求六套相同错误UI。瞄准点0°的单位疑点保留，不称单位正确。至少一类磁盘重启读回认知记录，填清内存边界。 |
| SC23 清台 | Store已有昨日草稿丢弃、完成保留且再来不重写、损坏仅清坏key；Controller已有失败草稿保留、再来需明确动作、计时不算后台；规则已有合法终球完成/早黑失败。 | `TrainingJourneyDiagnosticUITests/testDailyClearanceNormalStartReturnAndResume` 验真实自动开球与恢复，需未开始的专用设备/当日。再补失败/完成终态到再来可操作的页面证据。现有 `V52DailyClearanceUITests/testCompletedReplayPreservesCompletionAndStartsAnotherBoard` 明确completed+fixtureSettled，只可证明完成页再来，不证明正常击球赢得一局；其launch reset限全新指定沙盒，输出路径须重定向。完整正常局若成本过高仍须实际尝试并记录，不能默认全划人工。跨日无需人为等一天，已有注入时钟断言可承担。 |
| SC24 离线恢复 | `V54TrainingTransactionTests/test_injectedSaveFailure_rollsBackEverything_andSameBlockCanRetry` 真注入第一次save失败，验证session/queue空及游标未进，第二次只各1条；`test_uploadFailureKeepsAtomicQueue_andRetryCarriesProvenance` 使用失败后成功替身，验证queue1→0和冻结来源。`test_inProgressItem_rebuildsFrozenBlockAfterRestart` 只重新构造VM/重fetch，不是真杀进程。 | 新增隔离可控失败网络条件下正常浏览→录入→本地保存→杀进程重开，确认未伪成功/未丢草稿；用专用本地服务或传输失败注入核对只重试待传，无需Apple真账号授权。不要关全机网络影响其他任务。无测试注入口时先确认为环境/可观察性缺口，不破坏沙盒模拟磁盘损坏。 |
| SC32 门控 | 旧forced Free/Pro深链只证明一部分门控且固定Dark；不能代替正常入口和真实权益变化。 | 当前可达付费类别列明确入口，正常免费至少动作/计划/高级工具各1例受限并能返回，Pro同例可进入；本地StoreKit到期后的同例再次受限，额度按已生效规格做当日耗尽/跨日恢复服务断言。首次免费权益不能由旧Pro测试名字推断；先查有效额度契约。 |
| SC33 购买 | 已有本地SK三项商品/月到期/年/终身恢复历史证据。P7六方法多处入口不存在return或仅点按钮，`testRestorePurchaseNoCrash` 只前台，不是恢复权益。 | 在明确本地Products.storekit隔离环境，新增正常商品展示→取消→不获权益、pending→不提前获权益、购买→刷新→恢复一致，以及商品请求失败友好提示/重试。用本地交易控制，不切到真实商店兜底。当前其他任务新Pro测试可按快照/实际断言/原件审计复用，不能只依据PROGRESS的购买通过一句话。真实Apple Sandbox另列。 |
| SC36 性能 | 千场真实磁盘UI局部总量/999/978已有历史证据，不再重新铺同质千场来赚计数。 | `PerformanceDiagnosticUITests/testFiveProcessColdLaunchObservations` 可运行5次进程冷启动并报中位/最大；不是OS冷缓存。`testTenToolEntryExitCyclesInOneExplicitAppLaunch` 仅进出+打点弹层，不能关闭“反复工具回放”缺口。新增或叠加10轮实际击球→回放→重打（同进程可追踪PID、每轮状态），按时间线采App内存与最后回落。千场剩余为固定查询/滚动/统计耗时，可在受控已有可用大数据环境补测；旧环境丢失才新建，不追求逐条1000项UI遍历。 |

## 完成判据与外部条件

上述正常UI链可合并跨SC，但执行数量只算实际方法一次；共享服务反例不需要复制成每设备每入口。重要领域必须具备正常UI、独立数据/规则、异常恢复的分层结果；明确缺陷可结束该分支，失败并不是必须修好才能收口。

真正外部依赖是：用户指定测试账号的Apple授权/撤销、真实Sandbox交易和到账恢复、指定真实后端跨设备恢复、真机相机/声音静音/触感/热耗电、锁屏LiveActivity及通知实际送达、VoiceOver实际朗读。最终报告应给设备/账号/配置条件、步骤、预期和影响。不能把本地StoreKit、普通前后台、隔离HTTP失败、服务时钟边界、正常模版创建等本机可执行项归入“待人工”。

本重点表不排除其他27场景：学习剩余17入口、工具完整约束有解/无解/多杆、详情两球形、拍照合成图输入、M1深色与iPad剩余长文/输入、Release004等仍按原计划核销。所有M1–M5代表组合必须有执行/明确尝试与受阻记录；已证伪QD019等不要求修复后全矩阵再跑才能交付诊断。

## 有界收尾顺序

1. 收主控正在执行的学习 remainder002 六项真实终态、记录与图审；截至 remainder001 的9个通过方法不重复，1个已证实菜单关闭坐标失配保留原失败并按实际菜单范围做聚焦补验，其余学习入口逐项核销。随后注册并执行已审的认知五保存与六入口未提交退出草稿，补保存去重/真实失败重试的共享数据断言，避免把“第二次保存”说成“失败恢复”。
2. 一组正常计划与模版连续旅程合并SC04/06/07/08，沿同份受控数据补计时SC10和离线本地保存SC24。已有服务反例按准确选择器与旧证据引用；仅受版本变化影响或需关键原件恢复的有限方法重验。
3. 清台真实开始恢复+终态页面、其余工具完整输入/无解和多杆；每工具至少一个正常与边界终态，分支真实走到哪里记到哪里。
4. 本地StoreKit与正常门控单独隔离批，完成取消/pending/失败/恢复；不要在forcePremium状态测真实权益刷新。再补代表设备/字号缺口，不扩成无限全排列。
5. 串行性能观测与Release004包审计；性能不与大构建或另一UI队列并行。不存在已批准SLA则报测量口径与数据，不自设2秒/100MB阈值。
6. B6逐条将38SC展开到约定子项，分别标已验证、已发现问题、测试失配、外部条件、仍未知。独立核查RUN真实非零方法数、退出码、快照/overlay、截图实际内容和问题影响；去重跨SC执行计数，审被测快照到当前变更的影响。只有本机必要缺口确实收口且外部边界明确，才能形成最终报告。

### 防止收尾无限延伸

QD007/008 已有 backend004 真Mongo当前复现，不再重跑同一501或归属改写来证明同一结论；QD012已有模型与正常UI证据，后续计划旅程遇同类失败可关联；通知20:17→20:15保持未定性，允许一次有条件稳定等待的聚焦复验，不能围绕该控件无限更换选择器挤占主领域覆盖。每个测试适配失败保留证据，只有新信息支持时才做下一变体；缺口本机可做且无外部阻碍时继续执行，不能以写完本审计作为目标完成。
