# SC06 三源今日队列正常UI准备

2026-09-08，Test Engineer独立准备。初版仅文档；同日按主控后续委派新增独立Swift草稿，详文末。**未注册、构建、运行或操作UI；无新增通过结果。** 不改变生产、snapshot或共享台账。范围只到三种来源正常入队→分别重复加入→菜单排序→删除一项本次pending队列；不开始训练，不录15组，不删除模版源，不重复整组旧单测。

只读依据：frozen `archive/quality-diagnosis/snapshot-004/source/` 的 `TodayTrainingScheduleService.swift`、`TrainingHomeView.swift`、`PlanDetailView.swift`、`DrillDetailView.swift`、`CustomPlanBuilderView.swift`，以及 `V54ScheduleDomainTests` 三个相关方法；既有 `PlanContinuationDiagnosticUITests` / `TemplateContinuationDiagnosticUITests` 正常路径与004结果。原语义见 `docs/00-讨论记录.md`「2026-09-03：v54官方主线、今日编排与模版并行」及 `COVERAGE-PLAN.md` SC06。

## 隔离、源身份与不能混淆的数量

主控使用全新专用游客设备/沙盒，记录UDID、版本、运行时、字号和本run目录。可采用既有内存容器做同进程正常UI诊断；这不保证偏好/工具状态无磁盘副作用，仍不可复用用户设备或清旧数据。初态需正常“我的”见游客登录入口、记录页无记录、“我的模版”为空，今日没有任何精确队列卡。不用预填计划/模版/队列夹具，不改时钟、不登录或联网同步。若有既有队列或自建模版，留证停止更换新隔离环境，不清空它们来满足前提。

| 代号 | 本次来源 | sourceId与首页精确身份 |
|---|---|---|
| A | 免费官方`plan_beginner`首课 | `plan_beginner.stage01.lesson01`；首页`trainingHome.scheduleItem.plan_beginner.stage01.lesson01`。父计划是`plan_beginner`，不能拿父ID当课程sourceId。 |
| T | 本次新建唯一名称`队列诊断<本run短UUID>`，只含“走位基础” | 模版内容`drill_c037`，但队列sourceId为**实际新模版UUID**；首页`trainingHome.scheduleItem.<UUID>`。从纯`trainingHome.template.edit.<UUID>`卡ID提取UUID，排除`.cover`等子节点。 |
| L | 动作库“中袋直线出杆”独立自由动作 | 冻结JSON真实ID **`drill_c012`**，不是简称`c012`；首页`trainingHome.scheduleItem.drill_c012`。 |

服务去重键是在同owner/同日schedule内的 `sourceKind + sourceId`，只匹配pending/inProgress。完成后允许再次加入是另一分支，不在本批。三种来源即使含同一动作也不应互相合并。本批使用不同动作名便于辨识，但去重断言必须按三种来源身份，不按动作文字次数。

首页“今日安排”或`trainingHome.todaySummary`的动作总数不是队列卡数：A首课实际含2动作（已有004定位失配教训），T、L各1动作。**不要写三队列就必为0/3**。用A/T/L三个精确折叠按钮的存在与唯一性验证3项；若核对摘要，先按实际投影口径读出，另记为动作计数。建议可选只读P层核对3条item各自UUID、sourceKind/sourceId/state/orderIndex；没有这层则只称UI去重，不宣称数据库无重复。

## 有限正常路径

### 1. A：官方首课入队、再次选择同课

1. 正常训练页进入`planPoster-plan_beginner`，`planDetail.primaryCTA`必须实际为“开始此计划”；点后确认“确定激活”。进入激活后的“编排今天”，不把激活当自动入队。
2. 编排页首课默认被选择，实际label含“当前”“已选择”；只选这一课，`planDetail.arrangementSummary`应“将加入1项”（按真实排版空格读取，不硬搬旧空格）。点`planDetail.addToToday`，等待编排sheet消失，正常返回训练页，确认精确A卡待训练。
3. 再进相同计划的“编排今天”，核对同一首课被选而不是下一课/另课。点同一“加入今日安排”；回来A卡仍恰一项、没有新增课程sourceId。源码会返回alreadyPresent、显示“所选课程已在今日安排”；toast仅辅助，不代替卡/数据数量。

### 2. T：唯一模版正常保存并加入，再点已在今日安排

1. “我的模版”→正常“新建模版”→`customPlanNameField`填唯一名→“添加训练项目”→搜索“走位基础”→“添加走位基础”。确认选中后先实际关闭搜索（已知“关闭”路径）收起搜索态，才能点“完成(1)”；不假设搜索期间工具栏已露出。
2. 保持默认剂量，本批不需要改名/改遍数或完成训练。Builder的“保存”是**Menu**，选“保存并加入今日安排”才同时调用save和`addTemplate`；等编辑页真正消失与首页稳定，不用保存点击后瞬时断言。
3. 正常到模版架读取刚建唯一名卡的**纯UUID ID**，不是`.cover`。确认T队列卡恰一项、待训练。打开`trainingHome.template.menu.<UUID>`，点实际文案“已在今日安排”；源码该按钮仍可点击，`requestUseForToday`发现已在今日只toast并return。回来T卡仍一项，A仍一项。
4. 注意该重复入口证明**UI防重复**，第二次并未调用service.addTemplate；不要称其为服务幂等第二次写入。已有服务层证据另列，不为本批去改生产绕开UI防重。

### 3. L：动作详情加入今日，再走同一入口

1. 正常“动作库”搜索“中袋直线出杆”进入详情，确认是`drill_c012`对应内容，未到Pro遮挡页。底部`addToTrainingButton`文案“加入训练”只负责打开sheet。
2. 在sheet内点 **`addToTodayTrainingRow`**，对应“加入今日安排 / 作为独立训练项，不影响当前官方计划”。不要点`addToPlan_<UUID>`，后者会修改模版内容而不是新增自由来源队列。
3. sheet关闭后再点详情“加入训练”→相同`addToTodayTrainingRow`，返回首页L仍恰一项，A/T都还在。服务第二次会返回alreadyPresent，辅助toast“已在今日安排”。

上述顺序全程没有开始按钮点击，预期队列为 **[A,T,L]**。每个重复步骤返回首页取证一次，最终记录三个sourceId、label/value、顺序、实际可见frame。首页建议卡`trainingHome.suggestion`与历史卡`trainingHome.savedTraining.*`不属于新增pending队列，不能混计。

## 排序无需拖拽：真实菜单上移 / 下移

`TrainingHomeView.scheduleItemRow`每个pending卡头旁有`Menu`，**没有专用ID**，AX label为`管理<item.sourceTitleSnapshot>`。它与模版架的`trainingHome.template.menu.<UUID>`不是同一个菜单。菜单内真实Button是“上移”“下移”“删除”；移动调用`moveScheduleItem`→交换unfinished数组两个元素→`reorderUnfinished`。无需编辑模式或拖拽坐标。

建议只用本次唯一名T菜单走两个动作：

| 步骤 | 预期来源顺序 | 必要核对 |
|---|---|---|
| 初始 | A,T,L | 三个精确卡均待训练；唯一名`管理队列诊断…`应唯一命中。 |
| T菜单→上移一次 | T,A,L | 实际卡片序列交换，sourceId和待训练状态不变；T再开菜单，“上移”在首位禁用。 |
| T菜单→下移一次 | A,T,L | 回到原顺序，三个来源都保留；没有新增卡或已开始状态。 |

实际顺序应在同一滚动状态以卡片frame或真实AX顺序核对，不能把查找query的返回次序直接当视觉顺序。最小策略保持三卡折叠以降低高度；若三卡无法同屏，记录可见相邻对和滚动前后位置，或用独立只读orderIndex证据补足，不编绝对拖拽坐标或放宽顺序断言。

点击前每个目标完整frame须在实际窗口内且高于真实TabBar顶缘；004曾出现卡中心在TabBar下方却isHittable=true并误触动作库，不能仅hittable。顶部若有真实NavigationBar也要排遮挡，根页不存在时不强查frame。排序动画稳定后再取位；若框架报告Scroll element to visible，应区分自动揭露与真正排序，先保存前后PNG/AX。

## 只删除本次L的pending队列项

1. 初态/三项身份已严格核对，L卡仍label“待训练”。打开该队列卡的 **“管理中袋直线出杆”** 菜单；唯一匹配与本次L卡相邻关系需现场AX/截图核对。
2. 点菜单“删除”。该路径直接调用`removePending`，源码无确认alert；不要添加虚构“确定删除”步骤。服务只允许pending，否则抛`itemNotEditable`。
3. 等L精确队列卡消失；A/T仍恰各一项、顺序[A,T]、均待训练。正常离开训练Tab再回来，L不复现，T模版架仍存在、动作库原内容仍可查。此处删除的是本次添加的TodayScheduleItem，**不是Drill资产、训练历史或CustomPlan**。
4. 不点击模版架“删除”，不长按模版卡（该手势删除模版源），不调用任何清库或用户历史删除。本批结束保留A/T和本次模版，不为清理证据继续删它们。

源码管理菜单仅pending显示，故本次不启动任何项就能限定可删范围。inProgress删除拒绝已有精确单测 `test_reorderDoesNotChangeFrozenRole_andStartedItemCannotBeDeleted`，本批不再人为开始训练复制该服务反例；也不宣称验证了正常UI进行中删除。

## 复用范围、尚缺AX与交付边界

已核读可复用 `V54ScheduleDomainTests/test_service_freezesRoles_deduplicatesUnfinished_andAllowsRepeatAfterCompletion`（官方课去重及完成后再排）、`test_reorderDoesNotChangeFrozenRole_andStartedItemCannotBeDeleted`（两个库动作服务排序、角色冻结及拒删已开始）、`test_crossDayArchivesWithoutAutoCarry_thenCopiesFreshItems`（注入时钟跨日及新ID复制）。不是三源正常UI完成的替代；不重新运行旧171方法来增加计数。

当前还缺：新run三卡/三个管理菜单实际AX归属、首课编排重复选择的当前label、模版Builder搜索收起及保存menu的实际命中、三卡同屏能否充分观察顺序。先按A一次入队抓AX，T正常创建后抓AX，最后L加入后确定排序/删除菜单；路径已由源码确定，现场只补控件身份与动作证据，不猜位置。

建议一条串行旅程覆盖本范围；每阶段PNG/同stem AX，保留实际方法体与输入、退出码、失败现场和最终状态。若UI重复某个来源失败，只记已到达分支，不删除断言、不把测试失配归成产品缺陷。此批不证明跨日、跨owner、杀进程磁盘、来源删改历史冻结或完成后允许再次入队；这些按原分层证据/缺口处理。仅内存UI时记录“同进程重入”，不能称持久化通过。

## 2026-09-08 独立Swift草稿交付补充

已新增 `TodayQueueDiagnosticUITests.swift`，**仍未注册、编译或运行**。精确候选 `QiuJiUITests/TodayQueueDiagnosticUITests/testThreeSourcesDeduplicateMoveAndDeleteOnlyPendingLibraryItem`，选择1方法。启动要求 `QD_TODAY_QUEUE_AUTH=DEDICATED_GUEST_SIMULATOR` 与绝对 `QD_SHOT_DIR`（兼容TEST_RUNNER前缀），专用iPhone底部TabBar、内存ModelContainer、正常游客与forceNonPremium。主控确认实际新设备及配置；guard是授权声明，不独立证明设备新建。无fixture队列、后台任务或数据清理；不调用launchClean，以免夹带其重启/重置行为。

所有业务检查通过throw停止，没有XCTAssert失败后仍走后续步骤或success输出。teardown先保留`terminal-unclassified` PNG/AX再终止本App；只有整条执行到底才产生`verified-final…`与最终日志。按钮类型/菜单归属不符会中止留证，不降级成猜坐标动作。Builder保存menu唯一使用此前004已观察语义：根据**实际元素frame中心**点击，前置窗口完整包含/启用/键盘消失检查并截图；这不是硬编屏幕点，也未验证本次一定命中。

具体观察阻碍预先保留：①官方编排行的完整AX期望为“中底袋直线出杆，当前，已选择”，若新run实际不同先审AX；②模版新建排除装饰同名节点、纯UUID卡排除.cover，但菜单若暴露成非Button需真实证据后再适配；③队列菜单须唯一label且frame紧邻对应pending卡头，不能误用模版源菜单；④三折叠卡排序要求同屏完整可见并按frame验证，如屏幕容不下则明确观察受阻，不删顺序断言或猜拖拽坐标；⑤首次键盘引导/名称value/搜索关闭控件可能产生环境失配，草稿没有盲点系统引导或自动清未知内容。

本草稿只读回三来源UI身份和数量，不证明数据库中没有不可见重复；内存分页/AX若未暴露全部卡，精确集合检查会失败。最终记录页仍无训练、T源存在、L详情仍可达、首页仅[A,T]，用于区分队列项删除与源/历史删除。磁盘持久化、失败保存恢复及跨日仍独立缺口。

### Queue001 后的滚动适配（未重跑）

主控报告001实际失败61.296s、归档1341文件。本次实际打开其terminal PNG，并读同stem AX与xcode-test.log：官方分栏可见，`planPoster-plan_beginner` frame=(16,616,179,189)，底805落到TabBar顶791下；外层纵向ScrollView=(0,120,402,754)，内部等级横向ScrollView=(0,548,402,44)。日志29.09–56.38s反复全App Swipe up/down，最终因卡未完整露出抛错；没有成功入队证据，失败不改为通过。

仅修`homeReveal`：每步从实时AX选唯一近全宽且高大于宽的外层ScrollView，实际可视区取scroll/nav/window顶部与TabBar顶部交集；不再全App惯性swipe。按目标实际上/下溢出量，做以该可视区为界的短幅press-drag，每步最大可视高度1/8，重新读frame，仍保留最多10步、完整可见、非遮挡及throw护栏；横向筛选不成为手势宿主。端点从实时元素frame计算，不硬编屏幕坐标；幅度仅测试导航参数，不是放宽产品断言。其他业务断言未改。`xcrun swiftc -frontend -parse`退出0，仅语法解析，未注册/构建/设备操作或重跑，实际滚动效果仍待主控新run验证。

2026-09-08 13:53：queue002实际失败158.987秒，make2；xcresult13-49-07及1399文件已归档。官方课入队/重复、模版正常创建加入/重复UI守卫均已走过，尚未三源排序删除。根因测试误把库的TextField librarySearchField当SearchField，主控目视终态PNG并核实际AX；仅对应库字段改为真实ID/类型，搜索结果使用原完整可见断言，避免套用首页全宽滚动器。queue003已启动，未计通过。SC07两个真实服务边界方法已审，待串行注册运行。
