# SC32 活实例额度当地日变化诊断预飞

2026-09-08。仅新建本说明与 `QuotaDayBoundaryDiagnosticTests.swift`；语法 parse 通过，未注册、编译、运行或操作设备。主控性能UI002期间不改变任何进程时区。

## 诊断可行性与精确边界

可在**新专用、串行、内存测试宿主进程**中临时设置 `NSTimeZone.default` 为固定 UTC−12，再设置 UTC+14；这是26小时的时区差，不改变绝对时刻、系统/Simulator时钟或系统设置。对同一个Date，两时区的当地日期必然不同。测试实际记录各阶段Date epoch、进程/新建DateFormatter时区与秒偏移、隐式与独立显式日期字符串，再硬验实际旧新日期不同。

这测的是**App进程运行时，默认时区引起的当地日期变化**；没有等待真实午夜，没有发系统时区变更/显著时间通知，不证明真实系统午夜、前后台恢复或SwiftUI页面自动刷新的时序。不能直接写成“午夜刷新实测”。如果该局部刺激发现活实例与新实例差异，应记录为本地日期变更条件下的服务实例差异，真实跨午夜边界仍保留说明。

Foundation SDK本机头文件 `.../iPhoneSimulator.sdk/System/Library/Frameworks/Foundation.framework/Headers/NSTimeZone.h` 声明可写类属性 `defaultTimeZone`；Swift桥接为 `NSTimeZone.default`。该设置是进程全局，不能与其他测试并行，不能在复用真实账号宿主运行。必须由主控新建专用设备、无真实凭据，单selector运行。代码使用 `defer` 最终恢复，且正常/失败路径都在重抛前显式恢复并保存第五阶段。进程异常终止本身不会修改系统时区；但正常验收仍要求第五阶段恢复原件。

## 规格与已有测试

- `docs/08-商业化与合规.md` §2.3：角度训练测试免费每天20次，Pro无限。此处不新增规则或Pro矩阵。
- 已全文读 frozen004 `QiuJi/Features/AngleTraining/AngleUsageLimiter.swift`。`todayString()`每次新建DateFormatter，只设`yyyy-MM-dd`，默认时区来自进程环境；init比较存储日期并重置，`recordQuestion`递增并写当前日期；`remainingToday`与`isLimitReached`只读活实例计数，没有日期检查。故源码预期活实例保留20，新的实例重置0；**该预期不是已经实测的失败**。
- 已全文读 frozen004 `QiuJiTests/AngleTrainingTests.swift::AngleUsageLimiterTests` 全9方法：dailyLimit/fresh/increment/20满额/Pro bypass/dateReset/sameDay/shared/key。`test_dateReset_clearsPreviousDayCount`写昨日后再init，不能证明活实例跨日；本方法不重复整类历史测试。
- `B6-COVERAGE-AUDIT-004.md` SC32区分init日期重置与活进程跨日缺口。本方法仅补该有界服务刺激，不替代末题真实UI/权益边界。

## 唯一选择器及执行条件

`QiuJiTests/QuotaDayBoundaryDiagnosticTests/testLiveFullQuotaMatchesNewInstanceAfterProcessLocalDayChanges`

主控另建新空宿主设备；不要复用当前千场磁盘性能设备。宿主初始化前传 `-v50.inMemoryStore`。禁止 authenticatedProfileFixture、forcePremium/nonPremium、forceDailyLimit/forceDailyLimitNear。代码核shared owner仍guest，但该检查不能证明凭据为空；新宿主无凭据仍由主控落实。

| 环境键（direct优先，TEST_RUNNER_回退） | 必须值 |
|---|---|
| `QD_QUOTA_DAY_AUTH` | `NEW_EMPTY_MEMORY_HOST_PROCESS_TIMEZONE` |
| `QD_QUOTA_DAY_DEVICE_UDID` | 显式有效UUID，与实际SIMULATOR_UDID严格相等（忽略大小写） |
| `QD_SHOT_DIR` | 新绝对空叶目录；已有内容拒绝 |

只用 UUID UserDefaults suite和两个普通`AngleUsageLimiter(defaults:)`对象，不读写`AngleUsageLimiter.shared`，不强制计数、不访问真实用户defaults/Keychain，不发通知或调用网络/认证。shared owner守卫仅观察新沙盒宿主身份。测试结束删除自己的UUID domain；不清理主控其他数据。宿主App其他启动任务也处于临时进程时区，因此必须专用且串行，本方法不声明整个宿主所有日期消费者均隔离无副作用。

## 五阶段证据与判据

1. `01-original-process-state.json`：原始进程时区与日期，无quota对象。
2. `02-west-full20.json`：UTC−12下全新对象自然从0开始，经20次`recordQuestion`满额。必须used20/remaining0/limitReached true/非Pro，存储日期等于实际当地日、计数20。
3. `03-east-live-before-recreation.json`：切UTC+14，先读同一个活实例remaining与limitReached，**在创建新对象前取证**，避免新init重置defaults污染前态。
4. `04-east-live-versus-new.json`：同suite新建第二对象，验新对象used0/remaining20/未限额并写新日期、count0，再比较活实例切换前后读数。期望活实例也remaining20/未限额，失败保留真实差异，不放宽为只要新对象正常即可。
5. `05-restored-process-state.json`：恢复原`NSTimeZone.default`后，旧/新日期、两对象计数、defaults和完整阶段事实，以及捕获的失败信息。即使产品断言失败也必须走到这里，再重抛原错误；`defer`兜底恢复和清suite。

所有阶段含单调时间、绝对epoch、默认/formatter时区标识与偏移、独立日期oracle、used/remaining/reached/Pro与隔离存储键。每份JSON累计保留之前观察，无真实用户资料。写入错误不吞、不把缺失恢复原件算完成。

**前提硬失败**：新建DateFormatter偏移不等于要求的−43200/+50400，或其隐式字符串不同于同一个Date在显式Gregorian/POSIX+要求时区下的字符串，或填满/比较期间当地日期再次变化，或旧新日相等，均报`PRECONDITION`并停止，不分类产品缺陷。初始20计数/新对象重置control失败也不能只归因活实例。源码的私有todayString不能直接调用，故以同构新formatter的事实和实际defaults写入日期双重验证时区确已被业务采用。

临时默认时区这条对照是可执行的有限服务诊断，不是为原真实午夜覆盖造通过。若运行有效并暴露预期差异，停止同质重测，由主控登记证据与真实午夜边界；不要求修业务到绿。

主控执行前修正：require仅抛出Swift错误，不在恢复时区前调用XCTFail，确保失败先经过catch、第五阶段取证与defer恢复，再由测试方法抛错报告失败；所有预期保持。
