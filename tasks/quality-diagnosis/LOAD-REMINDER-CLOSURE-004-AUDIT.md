# L8/L9 加载与提醒收口证据审计

2026-09-08。只读审核 `LOCAL-CLOSURE-004-AUDIT.md` L8/L9、对应实际源/测试/归档；仅新增本文件。不运行测试、不改设备时区/权限、不新增生产fixture，不写共享汇总。以下“未建立”是具体分支能力与判据限制，不等于待人工泛称或已验通过。

## L8：必须分清三种 StoreKit 结果

| 层/精确证据 | 当前结论 |
|---|---|
| `StoreKitCatalogDiagnosticUITests/testProductLoadFailureShowsRetryAndRecoversLocalCatalog`；`archive/quality-diagnosis/runs/formal-004-storekit-catalog-001` | 1方法失败41.513秒，不能计全通过。loadProducts错误注入读回非nil，但实际无商品并显示模拟器未配置文案；清nil正常点重试后三商品恢复、单选/购买启用、返回Free与交易0有局部实测。 |
| 同run `screenshots/storekit-catalog-76081233-BB79-4E2C-985E-7D4F7C25E756-injected-load-failure-retry-visible.txt:157` | 明确文字「模拟器未注入商店配置，无法购买。请点下方『模拟器解锁 Pro』。」；它对应loaded.isEmpty分支，不是catch。文件阶段名含failure不是catch已命中的证据。测试源码/selector/xcode-test.log保存原“加载失败：”断言与失败。 |
| `formal-004-storekit-lifecycle-l0-001` 1/1 .879s；L1-002失败1.403s；L2失败1.388s（详STOREKIT-004-RESULT） | 这些是**Product.purchase**注入/清除生命周期。首笔-1009→clear读回nil→第二笔code2/无成功交易，直接SDK绕过UI仍复现，refetch未消除。既不证明loadProducts catch，也不值得重复clear/reset/再购来追商品加载catch。L1-001另是错误观察器关联URLError未展开，保留其失败类别。 |
| `formal-004-storekit-restore-001` 1/1 75.497s | 正常本地月购成功、同交易重启，appStoreSync网络失败→既有Pro保持→清注入重试恢复成功。是恢复分支，不是商品loader错误分支；不得拿它填load catch。 |

### 为什么当前不能直接挑一条throw→UI→retry测试

核当前与冻结004逐字节相同的 `Data/Services/SubscriptionManager.swift`：`private let service = StoreKitService.shared`；init只注入entitlementLoader（返回权益快照）、listenForUpdates和debug overrides，**没有Product loader接口**。`loadProductsWithTimeout`私有，真实service.loadProducts与8秒sleep race；catch TimeoutError和其他Error各自有UI文案，但没有可控clock/throw入口。`StoreKitService`是private init、直接调用`Product.products(for:)`的真实服务。不能用entitlementLoader替身让商品加载抛错，也不能通过给errorMessage赋值冒充真实catch链。

已读 `QiuJiUITests/OnboardingProUITests.swift::testStoreKitPurchaseAndRestore`，仅正常商品/购买/恢复，部分preview路由，不含load抛错。`V53ProfilePreferencesTests::testStoreKitConfigurationLoadsMonthlyYearlyAndLifetimeProducts`核正常Products，其他StoreKit方法是权益/购买；本次定向测试检索未找到可复用的产品loader抛错UT。不能为了制造超时去断全机网、篡改Bundle或挂起系统服务；这也未必令task group正确结束，不是当前可重复、隔离的诊断入口。

**收口动作：**本轮将本地商品empty→retry正常UI列“已观察”，loadProducts真实catch/timeout UI列“未建立：SKTestSession当前刺激返回空商品，且现实现无loader/clock注入点”。保存原失败与具体能力限制，不新增同质运行。不宣称真实商店不会抛错或真实用户网络错误已覆盖；未来若产品允许测试接缝或提供可复现Sandbox条件，再只补一条catch→retry，无需重跑整套StoreKit。

### SC03动作库也不能借 StoreKit 的证据核销

`DrillListViewModel.loadDrills`固定调用`DrillContentService.shared.loadFallbackDrills()`，接收非throw数组，没有errorMessage。service private init，固定Bundle.main；index缺失/解码失败记录diagnostics后nil，loadFallbackDrills转成[]，逐项解码失败经compactMap丢弃。`DrillListView`再按搜索/筛选条件或默认空状态显示。没有可注入失败loader/独立Bundle容器，也没有专门传播加载错误的页面状态。

这提供**静态可确认的错误信息丢失路径**：Bundle失败与空结果在VM接口上不可区分；尚未通过正常包故障UI重现实验，不能伪写成“页面错误态与恢复已验”。原内容完整性/Bundle解码诊断证明当前资产可加载，不等价失败可区分。不要删除正式资产、重签损坏包或强写VM数组来造这个分支。最终报告应保留这个源码层风险及缺失注入口，交产品/修复优先级处理；本轮不新增生产fixture，也不泛化为所有页面加载错误都相同。

## L9：已验层不重复，跨区产品意图尚未定义

| 层/精确方法与原件 | 能核销什么 |
|---|---|
| `V53ProfilePreferencesTests/testReminderPermissionDeniedDoesNotSchedule`、`testReminderAllowedSchedulesAndDisableCancels` | 历史B4替身授权/排期计数/取消；mock忽略hour/minute，不证明时区。旧原件边界按既有审计保留。 |
| `CalendarBoundaryDiagnosticTests/testReminderUsesInjectedCalendarHourMinuteAcrossTimeZonesAndDST` | 当前`formal-004-calendar-boundary-001`真实0.025s通过；UTC2026-03-08T09:30Z/10:30Z在LA得01:30/03:30、上海17:30/18:30，四次精确调用。原件63文件，外置六JSON `archive/quality-diagnosis/observations/calendar-boundary001-attachments`；Calendar转换已验，不再重跑。 |
| `NOTIFICATION-004-RESULT.md`；`NOTIFICATION-TIME-004-RESULT.md` | 正常权限/开关和唯一重复OS请求已有实证。time-preprobe001 .615s通过；time-ui001失败50.634s；postprobe001失败1.177s。期望20:17没有输入成功，实际picker两次20:14→关闭/重入20:14→独立prefs Date和OS20:14一致。未证明17被保存改成14，不再次调轮碰运气。 |
| `OWNER-GOAL-004-RESULT.md`；`CALENDAR-004-RESULT.md`；`PREFERENCE-REMINDER-004-ORACLE.md` | owner目标2/5/6切换持久键、非法值、真实目标3→5与QD028已处理。setWeeklyGoalDays不触发Scheduler；每日提醒不按每周目标天数排日期。无需发明改目标必须重排通知的要求。 |

### 当前实际语义

`UserPreferences.reminderTime`以epoch保存Date，init还原该绝对时刻；DatePicker仅展示hourAndMinute。`TrainingGoalView`使用Environment.calendar调用`TrainingReminderScheduler.shared.enable(at:calendar:)`，scheduled后才persist；启停和时间binding独立于weeklyGoalDays。`SystemTrainingReminderCenter`注册固定ID的`UNCalendarNotificationTrigger(DateComponents(hour:minute:), repeats:true)`，不设置timeZone/calendar；没有周目标正文插值。当前相关七源与冻结004逐字节一致（SubscriptionManager/StoreKitService/TrainingReminderScheduler/UserPreferences/TrainingGoalView/DrillListViewModel/DrillContentService）。

核docs04 F9、docs05设置与owner/设备边界，以及既有PREFERENCE/CALENDAR审计，只定义每日时间和设备偏好，**未裁定旅行跨区后要固定当地钟点，还是保持原绝对时刻**。Date显示可随当前时区变化，OS只有重复hour/minute，两者存在潜在语义错位；但本次没有观察OS跨区行为，也不能无文档直接指定哪一方错。存储Date的日期部分还影响DST转换，不能把4组固定Date参数测试扩称为每个DST缺失小时实达。

### 可安全的下一动作/阶段结论

1. 现在可完成的就是此证据清算：转换层已验、同区UI/prefs/OS实际时间一致已验、20:17目标输入失败保留、真实跨区集成与产品策略未裁定。无需新增测试才能形成诚实阶段结论。
2. 后续产品决定“当地固定钟点/绝对时刻”后，再准备一个专用新账号无关设备的跨区显示与OS请求对照。须先核UI继承真实系统时区的路径与OS请求读回；当前TrainingGoalView/UserPreferences/shared Scheduler没有独立的UI Calendar注入入口。仅在测试host临时改NSTimeZone.default（额度QD032用过）不会等价改变另一个App进程或OS通知服务，不能照搬额度方法来宣称提醒系统跨区已验。
3. 如先要纯层观察，可只读同一epoch按两显式Calendar格式化并对比现有hour/minute参数，但那是确定的转换事实，已有方法已经覆盖，**不推荐为收口新增同质U测试**。若以后获准做系统时区变更，应独立设计、保存恢复及前后台/实际请求，不在当前并行UI运行期间实施。
4. 锁屏真正送达、DST不存在时刻怎么送达与Live Activity依然外部实际条件；不要把产品跨区意图问题全部扔成“等人工”。最终报告区分“尚无确定oracle”“尚无安全集成刺激”“真实送达未验”。

结论：L8/L9可以以明确的已验层、源码风险、未建立原因和后续触发条件完成本轮审计；不能记成两条UI故障分支全通过，也不需要继续重复SDK清错或20:17轮值失配。本文不宣布原38场景全完成、不修改共享状态。
