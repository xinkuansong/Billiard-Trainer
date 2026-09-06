# 可观测性与本轮崩溃证据边界审查

2026-09-06。只读冻结源码、观测steering及已结束正式批次日志；未故意崩溃App、未操作设备、未上传日志、未读取账号凭证或进程环境，未修改业务。

## 先校正SC归属

`COVERAGE-PLAN.md` 的 **SC38是“提醒系统 F9/v48：通知拒绝/允许、时区目标变化、后台/LiveActivity恢复结束”**。可观测性不是SC38定义，不能用本报告顶替提醒系统测试。本审查辅助SC36性能稳定性、SC37 Release及跨批证据解释；SC38可执行的既有选择器另列在下方。

## 策略与冻结实现

`.kiro/steering/observability.md`（2026-03-24）要求Apple原生观测、不接第三方分析SDK、不自定义崩溃上传、依赖Organizer/TestFlight/App Store符号化报告，MetricKit可选；本地OSLog，不出现明文用户ID/手机号/openid。

在冻结QiuJi Swift源码检索 `Logger(`/OSLog/MetricKit/MXMetric/Crashlytics/Sentry：找到DrillContent、TrainingDose、Profiler三处Logger定义，未找到MetricKit订阅或第三方崩溃SDK调用。这里只是源码范围检查，不能据此为所有二进制依赖/服务端数据流做“绝无上报”的全量保证。

- `DrillContentService.swift:446–477`：OSLog类别DrillContent，公开输出资源名和解码错误描述，缺失与解码失败有本地诊断入口。
- `TrainingDoseResolver.swift:213/295/307`：类别TrainingDose，记录内容token及轮数clamp信息。是内容标识，不能直接当用户身份。
- `PerformanceProfiler.swift:143–169`：类别Profiler，Debug内汇总计时并public输出；Release `measureSample`直接执行block，报告不输出。Debug采样结果不等于Release性能。
- 日志体系并不统一走Logger：例如DailyClearanceStore默认print，模板增删/同步恢复/订阅亦存在print。不能以“.private默认隐藏”概括全部日志实现。
- **源码规范偏差**：`SyncRestoreService.swift:129–134` 未配置context时直接 `print(...userId=用户ID)`；该文件没有`#if DEBUG`门控。与steering不出现明文用户ID要求冲突。此处是静态可确认的日志路径，不声称本轮发生真实用户泄露；没有触发/读取真实ID，也不自动修复。
- `ModelContainerFactory.swift:30/50` 初始化失败仍使用fatalError，说明存在致命路径。未注入损坏数据库去故意触发，不由日常旅程通过推断这些路径已安全恢复。
- steering称archive处理dSYM上传，但冻结` scripts/Makefile:361–374`实际只执行Release archive再make dsym；dsym target约428行复制Archive内dSYMs到build目录。**提取不等于已上传/UUID匹配/可符号化**。本轮不Archive、不发布，不声称Organizer端已有报告。

## 已完成正式日志的有限扫描

本次扫描时共有 **32个带exit.json的formal-*目录**，其中读取 **60份xcode-test.log/make.log**。只读完成目录；未完成批次排除。检索EXC_BAD_ACCESS、EXC_CRASH、SIGABRT/SIGSEGV/SIGILL/SIGBUS、uncaught exception、crashed、crash report、signal数字、fatal error、unexpectedly quit、lost connection，**匹配0行**。

这个结论严格是“扫描的文本中未发现上述显式信号”，不是“App没有崩过”或“App稳定”。make.log和xcode-test.log可能只包含测试驱动摘要；本轮未收集完整设备OSLog、系统.ips/jetsam/Watchdog记录、所有xcresult诊断附件、Organizer报告或长时后台日志。重复make/xcode日志不是两次独立稳定性样本。

同一范围另见6条明确XCTest断言失败：formal-b2-003/004历史编辑、formal-b5-m2-light-core备注定位、formal-extra-m2-ax5-input-001与template-002更多菜单命中、formal-extra-m2-ax5-menu-003模版流程。行形态为`error: -[...test...] : XCTAssertTrue failed`，本身是测试断言，不是App崩溃信号。具体根因应引用各批复验报告；不能把断言失败全部归为工具错误，也不能把它们全部归为App崩溃。配置选中0测试的情况同理没有执行覆盖，不因make0算稳定性通过。

## 本机最小可验证范围与精确候选

下列方法已从冻结文件核对存在，给主控按已有结果去重；本报告未执行，不能新增通过次数。

| 精确选择器 | 能回答的问题 / 副作用边界 |
|---|---|
| `QiuJiTests/DailyClearanceStoreTests/test_corruptedDraftIsReportedAndOnlyCorruptedKeyIsCleared` | 用UUID专用UserDefaults和注入log闭包，核对“草稿损坏”诊断及仅损坏key清理。属于可恢复草稿错误，不故意崩App；不证明OSLog/Release上传 |
| `QiuJiTests/DailyClearanceStoreTests/test_yesterdayDraftIsDiscardedOnNewDay` | 隔离defaults与固定日历，跨日草稿清理及诊断消息断言；不是真实通知时区重排 |
| `QiuJiTests/DrillContentServiceTests/test_loadDrillFromBundle_invalidId_returnsNil` | 无效资源返回nil，辅助缺资源行为；现有方法没有捕获OSLog的消息断言，不冒充日志完整性测试 |
| `QiuJiTests/V53ProfilePreferencesTests/testReminderPermissionDeniedDoesNotSchedule` | 真SC38局部：ReminderCenterMock.denied，返回permissionDenied且scheduleCount=0；不弹系统权限框 |
| `QiuJiTests/V53ProfilePreferencesTests/testReminderAllowedSchedulesAndDisableCancels` | 真SC38局部：mock允许，调度一次、禁用取消一次；不是通知真实到达/时区变化 |

真实权限UI已有独立草稿 `SystemBoundaryDiagnosticUITests/testNotificationRealPromptAllowedWithEvidence` 与 `.../testNotificationRealPromptDeniedWithEvidence`，执行要求各自全新专用设备；它们不属于上述无设备单测白名单，也不在本审查中执行。LiveActivity后台恢复/结束及推送真机仍要按SC38原计划保留。没有找到可直接据上述Logger证明“错误发生→日志被系统持久采集→符号化/检索成功”的完整现有测试。

## 收敛

可立即补的是隔离草稿损坏的诊断/恢复断言，及核对现有提醒mock结果；更强崩溃诊断证明需独立采集策略、进程身份/时间窗关联与符号文件验证。当前零显式crash匹配仅作为已完成短批次的有限观察，不推导崩溃率、长期稳定、后台可靠、Release可观测或SC38整体通过。

## 追加：五个候选逐方法去重

已对照所有现存 `formal-*/selectors.txt`，并查实际passed行。四项已有有效通过证据，无须重复运行：

| 候选方法（类名/方法） | 既有有效证据 |
|---|---|
| DailyClearanceStoreTests/test_corruptedDraftIsReportedAndOnlyCorruptedKeyIsCleared | formal-b2-001/selectors.txt:148；xcode-test.log:415明确passed(0.006s)，exit make0 |
| DailyClearanceStoreTests/test_yesterdayDraftIsDiscardedOnNewDay | formal-b2-001/selectors.txt:145；xcode-test.log:421明确passed(0.002s)，exit make0 |
| V53ProfilePreferencesTests/testReminderAllowedSchedulesAndDisableCancels | formal-b5-m2-unit/selectors.txt:15；xcode-test.log:310明确passed(0.010s)，exit make0 |
| V53ProfilePreferencesTests/testReminderPermissionDeniedDoesNotSchedule | formal-b5-m2-unit/selectors.txt:14；xcode-test.log:312明确passed(0.000s)，exit make0 |

Reminder两项还出现在formal-b4-001清单40/41行，但本次直接引用可读取的M2-unit逐方法通过日志，不把“清单存在”当通过，也不重复执行。formal-b4-002等其他正式清单未补出第五项证据。

唯一无正式清单/通过证据的候选为 `QiuJiTests/DrillContentServiceTests/test_loadDrillFromBundle_invalidId_returnsNil`，已写入 `build/quality-diagnosis/additional-configs/observability-unit.json`，run=`formal-extra-observability-unit-001`，M1 UDID=`439DA53C-2E95-441E-8BD0-A6F8DA6F616D`。仅准备1个精确选择器，未执行；它检查nil返回，仍不等于OSLog采集验证。

去重复核补充：已递归检查formal目录内嵌套selectors.txt（包含B4/profile/api子批），无DrillContentServiceTests类级或该无效ID方法选择器。B4原始有效证据也已定位：`formal-b4-001/profile/xcode-test.log:290/292`分别为Reminder允许/拒绝passed(均0.001s)，因此这些不仅在M2重跑通过，B4也已有证据。

日志扫描范围补充校正：原32根目录/60日志没有包含B4的profile/api等嵌套完成子批。本次按formal目录递归寻找exit.json，在其同目录读取make/xcode日志，共 **78份已完成日志**，同样显式crash/signal检索 **0匹配**。它补齐了嵌套日志范围，仍不代表OSLog、.ips、xcresult全量诊断或零崩溃结论；后续正在运行批次不在固定扫描结果中。
