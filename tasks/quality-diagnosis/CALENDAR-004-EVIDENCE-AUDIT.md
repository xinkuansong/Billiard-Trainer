# 包7：时区、日历与目标调度证据审计

2026-09-08。按adapter、55-test-engineer规则只读核对snapshot004方法体/实现、原批次记录与当前004归档；不运行构建、XCTest或模拟器，不改业务/共享台账。这里只核包7日历残项，不替代正在串行执行的Daily UI。

## 应区分的三层

1. 通知：把用户选择的Date按页面Calendar提取hour/minute，再向OS注册每天重复通知；跨时区/DST后的实际送达属于另一层。
2. 今日训练队列：按注入now/timeZone的本地日键归档/新建，**不是**通知排程。
3. 每周目标：1…7天影响目标展示和剩余周数估算；当前实现并未按“目标N天”生成N条星期通知。因此不得凭文案“每周目标”新增每周通知分配功能作为隐含oracle，也不能把目标持久化通过称为时区调度通过。

## 已验证且无需同质重跑

|证据/精确方法|实际终态与原件|能核销的范围|
|---|---|---|
|QiuJiUITests/DataRefreshDiagnosticUITests/testGoalThreeToFivePersistsAfterRecordedDeletion|formal-004-data-goal-companion-001，xcode-test.log:1063，83.501秒失败，实际xcresult15-03-29；DATA-REFRESH-004-RESULT|正常3→5写入完成，首页仍1/3，QD028同进程刷新失败；不是持久化失败|
|QiuJiUITests/DataRefreshDiagnosticUITests/testColdRestartRetainsWrittenGoalAndDeletedLedger|formal-004-data-goal-cold-001，xcode-test.log:1679，94.581秒通过，xcresult15-07-03；observations/data-goal-cold-001-after有外部原库与偏好|正常冷启动/再重启目标5、B/C与2条entry保留，外部五表一致；不重复播种或目标链|
|QiuJiTests/NotificationPendingDiagnosticTests/testObserveActualAuthorizationAndDailyPendingRequest|NOTIFICATION-004-RESULT、NOTIFICATION-TIME-004-RESULT；004相关probe与time run归档selector/OS报告|真实权限及唯一重复请求hour/minute、sound、显式timezone=nil；稳定20:14→关闭/重进→OS一致，但原20:17输入失败保留|
|正常休息后台到零与下一次休息|REMAINING-PRIORITIES-004包7核销补记及对应休息结果|不重复普通后台；不等于时区切换或Live Activity真机恢复|

以上run目录完整前缀为 `archive/quality-diagnosis/runs/`。通知测试源码本轮核其dateComponents读回与断言：检查小时/分钟、repeats及nil timezone，没有比较多个Calendar，没有等待实际通知送达。notification-time还有点击关闭区域可能把weeklyGoal改成2的已记录诊断副作用，不能把它当正式目标变化调度正例。

## 旧测试存在与历史执行不能扩大解释

### V54ScheduleDomainTests（snapshot004/QiuJiTests/V54ScheduleDomainTests.swift）

已全文核以下方法及setUp/相关helper：

- `test_timezoneBoundary_andEstimateAreDeterministic`（630行）：同一epoch1788393600用固定GMT+14与GMT−10，只断言两个localDayKey不相等；未断言具体日期，未切换已有队列的时区。随后四个remainingWeeks断言：9课/ordinal0/每周4→3周；ordinal5/4→1周；ordinal5/3→2周；ordinalnil→0。覆盖算术，不调用OwnerProfileStore.setWeeklyGoalDays、不调用通知center。
- `test_crossDayArchivesWithoutAutoCarry_thenCopiesFreshItems`（606行）：注入UTC及可变clock，加86400秒，真实内存context中旧队列归档、新队列空，显式carry复制1项、新UUID且payload相同、旧项pending。是真服务跨日基础证据，但UTC86400不是DST23/25小时本地日。
- setUp用ModelContainerFactory.makeInMemoryContainer并持有container/context至tearDown；当前V5 schema，不需磁盘seed或实际系统时钟更改。

两精确selector列于 B2-SELECTORS.md:74–75，B2.md记FORMAL-B2-001 171/171通过。现存004 run未找到这两方法的selected selector/逐方法终态，旧002原xcresult当前缺失；正确标注是**已有历史通过记录，004未重新实跑**，不是“只有源码从未测过”，也不是“004已验证DST”。

### V53ProfilePreferencesTests（同目录）

`testReminderPermissionDeniedDoesNotSchedule`（376行）仅denied→permissionDenied且scheduleCount0；`testReminderAllowedSchedulesAndDisableCancels`（383行）允许→scheduled/count1，再cancelCount1。ReminderCenterMock.schedule(hour:minute:) **忽略两个参数，只加计数**；enable未传calendar，使用.current。完全不证明小时提取或时区。B4-PREPARATION列两个selector，B4.md记profile16/41整体通过，旧原件缺失；保留历史替身通过层，不重跑授权/取消同质用例，也不选整个含StoreKit/头像操作的类。

HistoryViewModelTests的日期过滤/普通月切换和28天二月测试，仅一般Gregorian/当前Calendar行为；DATA实际9月空日与8月历史已独立补证。它们不能回答通知Calendar传递，包7不因“日历”二字重跑全部历史测试。

## 当前实现约束与未验点

TrainingReminderScheduler.enable(at:calendar:)提供真实Calendar注入点，成功授权后用calendar.dateComponents([hour,minute],from:date)调用center.schedule。SystemTrainingReminderCenter只注册DateComponents(hour,minute)，repeats=true，先删除同ID再add；没有显式calendar/timeZone字段。TrainingGoalView从Environment.calendar传给enable；OwnerProfileStore.setWeeklyGoalDays只校验1…7、更新/persist或服务失败回滚，没有调用ReminderScheduler。提醒更新时间/启停由独立binding调用，不能凭目标变化推导需要重排。

UserPreferences.reminderTime存的是绝对epoch Date，页面按当前Calendar显示；冻结源未见系统时区改变监听/通知重排入口。因此“旅行后保持当地19:00”与“保持原绝对时刻”不能直接假定已定义/已验证。OS请求只有hour/minute，而偏好是Date，跨区重新显示/再次保存的关系确有观察价值；当前证据未证实其错误，也没有UI可安全注入Calendar的现成诊断入口。

TodayTrainingScheduleService将timeZone保存在let，localDayKey实际调用V54DataMigration中硬编码Gregorian Calendar。构造器calendarIdentifier仅记进模型元数据，不决定计算历法；传一个非gregorian字符串并不能模拟另一历法。当前页面Environment.calendar与队列Gregorian策略不同，是边界说明，不直接判产品缺陷。现有服务测试未覆盖夏令时本地午夜，也未覆盖同一队列由一个zone切到另一个zone的跨日期策略。

## 最小补验建议（仅建议，不新增源码/运行）

优先新建独立诊断类的**2方法**，主控审阅后选择；下列名字是建议新增，**当前不可直接运行**：

1. `QiuJiTests/CalendarBoundaryDiagnosticTests/testReminderUsesInjectedCalendarHourMinuteAcrossTimeZonesAndDST`：复用真实TrainingReminderScheduler，新增只记录(hour,minute)数组的允许态center替身。独立ISO UTC字面时刻2026-03-08T09:30:00Z和10:30:00Z，Los_Angeles预期01:30/03:30、Asia/Shanghai17:30/18:30；每次guard scheduled，核确切调用次数及所有参数。全程不注册OS通知、不改系统时钟、不调用真实授权。此方法填补旧mock丢参数和DST换算缺口，不证明不存在的02:30提醒如何送达。
2. `QiuJiTests/CalendarBoundaryDiagnosticTests/testTodayScheduleArchivesAcrossDSTLocalMidnightWithoutAutoCarry`：当前V5内存容器+真实TodayTrainingScheduleService，LA时区注入2026-03-08本地00:30到3月9日00:30（UTC08:30→次日07:30，23小时）。精确字面dayKey、旧队列归档一次、同owner新队列空、旧pending保留；同新日本地时刻重复today返回同UUID不重复新建。由now闭包推进，禁止86,400秒假装当地一天。此为原跨日服务的必要独立边界，不重复普通UTC用例。

若主控只需补可追溯的004基础算术而不接受历史记录，可附加现有精确 `QiuJiTests/V54ScheduleDomainTests/test_timezoneBoundary_andEstimateAreDeterministic`，但它是证据更新而非新覆盖，不应列为强制重复。已验证目标持久化与QD028保留，不再运行目标3→5 UI。

跨实际系统时区后的OS请求/偏好显示一致性仍单列未验：现有Calendar注入可测转换，但不代表OS自动时区响应；正常UI/共享scheduler暂没有独立可注入入口。本轮不要新增业务入口/强改系统时钟或误称人工唯一可测；最小纯层完成后按原范围保留这一具体集成层限制。真正锁屏送达、DST跳时当天通知实达与Live Activity仍属于M6条件，不能由上述2方法冒充。

所有补验需专用无凭据宿主，TestAction初始化前-v50.inMemoryStore、明确当前schema、5态区分（通过/失败/未执行/历史证据/外部层）；只选所列精确方法，不跑整个B2/B4。当前本文件是证据审核交付，不改变包7状态或取消任何原范围。
