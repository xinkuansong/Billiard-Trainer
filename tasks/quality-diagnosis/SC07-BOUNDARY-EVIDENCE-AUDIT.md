# SC07 课程边界证据审核

2026-09-08，QA/Test Engineer，只读。只新增本文，未运行测试或修改共享台账。结论：**正常完整课程推进与A→B→A已有004原始通过证据，不应重跑；逆序、幂等、末课完成有历史通过记录，但旧原件当前不可重核。真正薄弱处是把“角色分类正确”误当“完成后的review/preview不会推进”，以及未完成状态不推进的直接结算反例。**

## 原约定

`COVERAGE-PLAN.md` SC07：顺逆完成、复练/预习/重复回调，仅连续eligible推进，U/P/UI分层。`EXPECTATIONS.md` EXP-T03补充复练不倒退、预习不跨课、拖动不重分类、切换后旧课不推进新主线。当前契约 `.kiro/steering/content-data-contract.md §9.2`：completed + advanceEligible的连续前缀；加入、开始、退出、review、preview、neutral、tool不得推进；scheduleItemId+lessonId幂等。

这些是边界组合，不要求为了每个状态再手工录15组。正常UI链已有实证，规则/服务反例可以分层核销，但不能仅因方法名含persistent/reverse就扩张其实际范围。

## 当前原件可用性

实际核查：旧 `build/quality-diagnosis/formal-b2-001` 与 `archive/quality-diagnosis/runs/formal-b2-001` 均不存在。`B2.md`、`EXECUTIONS.md`和完整 `B2-SELECTORS.md`仍存在，记录snapshot002、171/171、make0、1.715秒用例/29.464秒测试阶段；不能从这个聚合记录编造每个方法的具体耗时。`EVIDENCE-AVAILABILITY-20260907.md`已说明旧build消失。本次没有发现归档run日志中这些V54方法的实际Test Case执行终态；编译命令提到文件不算执行。

冻结004的 `QiuJiTests/V54ScheduleDomainTests.swift`、`V54TrainingTransactionTests.swift`当前可读；本次逐段读断言，但它们不能替代历史已执行源码/哈希。历史“已通过”保留，不改写成“没测过”；报告必须同时标“旧原件不可重核”。不因旧原件缺失自动重跑171项。

`formal-004-plan-continuation-001/002`有现存归档。002的inputs/exit/selector/tested-source/log/xcresult/PNG/AX可直接核对，本次确认唯一selector与日志373.399秒passed、make0。原001定位失败也保留。主控已目视关键图的记录在 `PLAN-CONTINUATION-004-RESULT.md`；本次重点核方法断言和原件可用性，未把先前主控图审冒充本次新图审。

## 精确方法、历史终态与断言边界

下面V54全限定前缀为 `QiuJiTests/V54ScheduleDomainTests/`；其历史终态均来自B2-SELECTORS明确选中和B2-001全171通过记录，不是本次重新运行。

| 精确方法 | 实際断言 | 可核销/不能扩张 |
|---|---|---|
| `test_classification_matchesAllFrozenSelectionCases` | 7组独立字面预期：current4选1+4→review/eligible；4+5→连续eligible；4+6→6preview；只6preview；只4eligible；末课8eligible；current=nil选2review。 | 历史分类规则已测；**没有将completed review/preview传入settle**，不能独自证明这些完成记录不推进。 |
| `test_progressRules_reverseCompletion_switchAndTwentyReplays` | 输入同时已完成的ordinal4/5 eligible，current4→6且advanced2；activePlanID不同advanced0；同一输入调用20次游标最终6。 | 历史连续与幂等/不同主线纯函数已测。方法名虽含reverse，实际没有“先只完成5”的第一次调用；真实逆序由下一方法补。无review、preview、isCompleted=false输入。 |
| `test_persistentSettlement_handlesReverseOrder_finalCompletion_andReplay` | 服务加4/5；先完成5→none、仍4；补完成4→advanced2、游标6；20次重复current结算均none；末课完成→completed、currentLessonId=nil、completedAt非nil。 | 历史真实服务逆序、补洞连续、20次幂等、末课终态已测，可按历史证据核销这些逻辑子项。**setUp是内存ModelContainer，名称persistent不等于磁盘或进程重启**。 |
| `test_service_freezesRoles_deduplicatesUnfinished_andAllowsRepeatAfterCompletion` | 加4/6时分别eligible/preview；重复加入不增加未完成item；把4标completed后可新建同课第二条。 | 历史入队冻结角色/去重/完成后可复练已测；只证明可再排，不验证第二条复练保存后游标不倒退。 |
| `test_reorderDoesNotChangeFrozenRole_andStartedItemCannotBeDeleted` | 创建两条动作来源item，调换orderIndex，第一条progressRole不变；started删除抛错，abandon后状态正确。 | 历史neutral动作顺序不改变角色、不可删started已测；不是official eligible/preview混排的直接角色保持样本，不证明abandon不推进游标。 |
| `test_v57_oldQueuedLessonCannotAdvanceNewMainline` | 激活A排第一课→激活B→将旧A item completed→结算none，B仍第一课、A仍第一课。 | 历史切换后旧队列不能推进新/旧游标的服务反例已测。不是退出App再恢复。 |

跨SC旁证：

- `QiuJiTests/V54TrainingTransactionTests/test_scheduledCompletion_commitsSessionItemCursorAndQueueTogether`：实际VM保存后session/item/游标/queue关联、effect=advanced:1。是内存夹具，不是用户完整录分UI；该保存路径的部分完成问题QD012另有明确发现，不能用它全绿否认QD012。
- `.../test_injectedSaveFailure_rollsBackEverything_andSameBlockCanRetry`：第一次save注入失败，session/queue空、item pending且无trainingSessionId、cursor首课；再试只一个session/queue、游标第二课。覆盖事务失败不提前推进和同块重试，但不是20次重复完整保存，也不是磁盘重启。
- `.../test_inProgressItem_rebuildsFrozenBlockAfterRestart`：同一内存库fetch后创建新VM，冻结名称保持；不是杀进程，也没断言未保存游标不动，不能充当SC07退出不推进的完整反例。
- `V29W7PlanProgressTests`主要旧周/天推进契约；其中首页读取测试改为新lesson结算，不能用旧周/天封顶断言替代v54 completed/null游标合同。本次不把它计为SC07新的执行证据。

## 004正常UI已经满足的部分

`QiuJiUITests/PlanContinuationDiagnosticUITests/testCompleteAllFifteenSetsThenSwitchBackPreservesSecondLesson`：

- 001：方法失败。15组225球完整录入、保存返回首页已发生；后续卡片中心落TabBar误触动作库，未到推进断言。保存局部不等于SC07推进已通过。
- 002：**1/1 passed，373.399秒，make0**。内存游客、非Pro、正常plan_beginner第一课8+7组均15/15；总览120/120及105/105；正常保存；编排器第一课已完成未选、第二课当前已选、第三课未开始未选；切免费B第一课当前，再回A仍第二课。
- 原件目录 `archive/quality-diagnosis/runs/formal-004-plan-continuation-002/`，xcresult为 `Test-QiuJi-2026.09.08_11-41-32-+0800.xcresult`；tested-source保持真实15组及三课断言。001/002不能计2条通过。
- 因而**当前正常保存→下一课、A→B→A游标保持可核销，不应再次录入这15组**。这条没打开完成记录逐字段读历史，不覆盖全部provenance；没杀进程，不覆盖磁盘游标恢复。这些分别与SC05/09等合并看，不在SC07重复造十几分钟UI长链。

## 真正仍缺及最小补证建议

1. **冻结preview完成后仍不得推进，尤其“原缺口后来补上”**。当前直接读到的V54断言只有分类，没执行这个关键状态组合。最小服务方法可用独立预期：current4排4+6（6为preview）→先完成preview6仍4→完成eligible4推进到5→新排eligible5并完成，只能到6，不能因旧preview6完成而跳到7→再显式新排6为eligible完成才到7。全程核role原值及currentLessonId，不需UI录分。此一例能判“冻结预习误升级eligible”的真实风险。
2. **review完成不倒退，以及completed gate**。小表覆盖当前6、已完成历史课1的review结算none；当前课eligible分别pending/inProgress/abandoned时结算none；再completed才推进。每行直接核cursor和返回值，不能只核角色label。当前找到的准确方法未覆盖这个表。加入/开始/退出的“不推进”可通过同服务状态表与正常UI前后状态组合，不要求五套重复UI。
3. **official混合角色调序不重分类**是现有neutral动作reorder方法的薄弱点，可并入第1条：调换4/6顺序后分别仍eligible/preview，继续同一结算序列，避免为它单独跑完整UI。

以上建议最多新增2个服务方法，使用内存或隔离磁盘容器并明确边界，不改业务、不seed正式内容。若主控要求最终SC07必须附现可打开的规则原件，再选现有 `test_classification_matchesAllFrozenSelectionCases`、`test_persistentSettlement_handlesReverseOrder_finalCompletion_andReplay`、`test_v57_oldQueuedLessonCannotAdvanceNewMainline` 三个方法做**证据恢复性补录**；它们不是“此前未执行的新缺口”，也不要顺手重跑171项。是否需要补录取决于最终证据等级，不能把补录当唯一继续条件。

## 核销建议

- **现有原件可核销**：完整正常课程推进、UI A→B→A保持。
- **按历史记录可核销并标原件限制**：七类分类、逆序补洞推进、20次重复结算、末课完成、切换后旧课不推进、内存保存事务回滚重试。
- **仍缺直接反例**：冻结preview在缺口补齐后仍不推进；review不倒退；eligible未completed不推进；official混合角色调序保持（可合并前述2方法）。
- **不属于这些方法已证明的范围**：真实进程磁盘游标、跨owner设备同步、所有端到端组合、历史内容全部字段。与SC04/09/24现有证据交叉核销，不凭SC07一个包吞并或重跑。

本审核更正了先前REMAINING-COMPLETION-AUDIT中“跨缺口preview/复练边界由已有服务断言承担”的过宽概括：现有代码明确承担的是分类和重复排课能力，不足以证明两者完成后的全部结算行为。本次仅在独立审计写明，不修改原记录或共享台账。
