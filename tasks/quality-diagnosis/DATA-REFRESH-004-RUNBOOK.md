# DATA-REFRESH snapshot004 串行运行配置核对

2026-09-08，只读准备。未修改任何既有源、工程或共享台账，未运行测试或操作设备。必须等主控 AccountFailure001 完整终态及归档后再安排此批，不能并行占 UI。

## 当前注册状态（本次直接检查）

- `build/quality-diagnosis/snapshot-004/QiuJiTests` 与 `QiuJiUITests` 内没有 `ThousandStoreProbeTests`、`testReportInMemoryHostAndEmptyDefaultStore` 或 DataRefresh 类；生成的 `QiuJi.xcodeproj/project.pbxproj` 亦无这些文件引用。**probe 未注册**，不能因为旧千场任务运行过便直接选择它；新 seed/UI 也仍未注册。
- `snapshot-004/project.yml:189` 的 QiuJiTests sources 是 `QiuJiTests` 目录。主控后续需按现有批准流程纳入三个独立草稿并核真实 Sources，不能只复制到 tasks 目录后把 selector 零执行算成功。
- `snapshot-004/QiuJi.xcodeproj/xcshareddata/xcschemes/QiuJiDiagnosticMemoryHost.xcscheme` 已存在：TestAction `shouldUseLaunchSchemeArgsEnv="NO"`，内有启用的 `-v50.inMemoryStore` CommandLineArgument；Testables 包含两个测试 target 且 parallelizable=NO。当前 TestAction **没有**本任务所需 EnvironmentVariables。只向 LaunchAction 添加 env 不保证 TestAction 收到。
- 此手工 memory scheme 未出现在 project.yml 的 scheme 定义中；如果主控重新生成工程，必须重新检查生成后的实际 scheme，不能假设自定义文件与参数仍正确。UI 阶段正常 App 的启动参数由 UI 草稿显式赋值，不继承内存参数。

## 最小执行顺序及 selector

1. 主控建立专用空白 guest 模拟器，记录实际 UDID；确认无真实凭据，不普通 disk 启动 App。不复用 AccountFailure 或其他有库设备。
2. probe 单跑：`QiuJiTests/ThousandStoreProbeTests/testReportInMemoryHostAndEmptyDefaultStore`。源码：`tasks/quality-diagnosis/ThousandStoreProbeTests.swift`；使用预置内存宿主的 scheme，只选此方法。
3. 主控读 probe JSON，核 owner、路径和三项 exists=false，确认实际1方法通过、无 skip、无其他测试。再单跑 `QiuJiTests/DataRefreshFixtureTests/testSeedThreeSessionRefreshLedgerIntoDedicatedEmptyDefaultStore`，仍用内存宿主；不能 probe 与 seed 同批靠排序运行。
4. 主控归档真实 manifest 并独立核数据库，再正常 UI 单跑 `QiuJiUITests/DataRefreshDiagnosticUITests/testCalendarNoteDeleteAutomaticRefreshAndGoalThreeToFivePersists`。从正常 UI 方法启动真实磁盘 App，保留同一 owner/账本。正常重启仅发生在该方法目标3→5之后。
5. 主控审 PNG/AX 与最终磁盘，按 PREPARATION 判定链路。任何失败保留现场；不自动重播、清库、改日期或降低断言。

## 进程内实际环境配置

|阶段|进程实际需要的键|值/来源|
|---|---|---|
|probe|QD_PROBE_ENVIRONMENT|DEDICATED_EMPTY_GUEST_SIMULATOR|
|seed|QD_ALLOW_DATA_REFRESH_DISK_SEED|DEDICATED_EMPTY_GUEST_SIMULATOR|
|seed|QD_EXPECTED_GUEST_OWNER|本次 probe 的 guestOwner 原值|
|seed|QD_EXPECTED_DEFAULT_STORE_RELATIVE_PATH|本次 probe 的 defaultStoreRelativePath，主控核验规范化容器路径|
|UI|QD_UI_ENVIRONMENT|SEEDED_DEDICATED_GUEST_SIMULATOR|
|UI|QD_EXPECTED_DEVICE_UDID|主控指定专用设备的实际 UDID，不采用 runner 自动推导作为 expected|
|UI|SIMULATOR_UDID|实际模拟器 runner 环境提供；不得手写覆盖成 expected 来绕过核对|
|UI|QD_EXPECTED_GUEST_OWNER|同一 guestOwner|
|UI|QD_EXPECTED_DEFAULT_STORE_RELATIVE_PATH|同一核准相对路径|
|UI|QD_EXPECTED_MANIFEST_JSON|刚导出的完整真实 manifest JSON，不是手工符合预期的 JSON|
|UI|QD_SHOT_DIR|本批新建、runner 可写的独立绝对证据目录|

**最新主控修改已回读核实：tasks 中的 probe/seed 现在均支持前缀，尚未复制 snapshot 或注册。** `ThousandStoreProbeTests.swift` 的 authorization 已改为直接 QD_PROBE_ENVIRONMENT 优先、TEST_RUNNER_QD_PROBE_ENVIRONMENT 回退；值不匹配执行 XCTFail + throw，不再 XCTSkip。`DataRefreshFixtureTests.swift` 新增 setting helper，三个 env 键均直接名优先、TEST_RUNNER_ 回退；授权值匹配、owner/路径/日期/空库等守卫不变。本子任务只更新此 runbook，未修改这些源。

因此，前一次“两个 hosted 草稿不支持前缀”的只读发现是**修改前状态，现已失效**。下一批主控须复制并注册最新 tasks 版本，不能拿旧 snapshot/旧构建来验证前缀适配。不得以 skip、零方法或只看到 Make 退出0算通过；probe与seed各需要实际方法执行成功及对应产物。

UI 的统一 env helper 同样直接名优先、TEST_RUNNER_ 回退。三个阶段可传表中直接键，或对应 TEST_RUNNER_ 键；不要同时保留冲突值。源代码支持前缀并不保证父 shell 环境天然进入 hosted App：现有 scripts/Makefile 记录过该传递边界。主控仍应核本次 xctestrun/TestAction 的实际环境配置；若 shell 传递不能保障，使用所选 scheme **TestAction EnvironmentVariables** 的直接 QD_*（isEnabled=YES）并静态回读 XML。当前 TestAction shouldUseLaunchSchemeArgsEnv=NO，不能只向 LaunchAction 添加。环境未到达或值不符必须失败，不能进一步放宽授权。

宿主启动参数：probe/seed 必须在 App 初始化前已有 `-v50.inMemoryStore`，不可在方法 setUp 才补；seed 拒绝其它 `-v*`、deeplink、forcePremium。UI 草稿固定中文、跳过onboarding、followSystemAppearance、forcePremium（统计/旧历史门控），不带内存/数据/登录 fixture。

## 固定日期前提

seed 检查 Asia/Shanghai、Gregorian、实际日期 **2026-09-08**，当前时间至少 00:02；保存后再次检查当天。UI setUp、重启前、链尾重复日期检查。三条日期是9月8日00:01/00:02及8月31日00:00。周统计字面范围9月2–8日，50分钟3组→30分钟1组。

日期不是 env 参数，不能通过 QD_EXPECTED_LOCAL_DAY 或修改系统时间切换。跨过9月8日必须停止使用这份固定账本，另做新日期的独立预期审阅；不能把日期 guard 删除以继续跑。旧 DATA1-0907 的 manifest 不兼容。

## 可观测产物与路径

- probe：XCTest attachment 名 `thousand-store-preflight`（JSON），同 JSON 打印到测试日志；**不写 App 文件**。字段 defaultStorePath/defaultStoreRelativePath/home/guestOwner/inMemoryArgumentPresent/三项 exists。不能凭不存在某个自造 probe.json 路径判断失败。
- seed：App 实际当前沙盒 `<NSHomeDirectory>/Documents/qd-data-refresh-20260908-manifest.json`。manifest 自带 `manifestRelativePath`、`storeRelativePath`、实际 UUID/日期/条目成绩、计数3/4/4/0/0。默认数据库为 probe 观察、seed 再验证的 `<当前home>/<storeRelativePath>`；不硬编码 Library/Application Support/default.store。安装可能合法改变容器 UUID，必须重新验证 owner/数据身份，不能把旧绝对路径当真源。
- UI：`<QD_SHOT_DIR>/data-refresh-<runID>-<stage>.png` 和 `.txt`；PNG先写、AX后写，同时保留 xcresult 附件（AX附件名加 -AX）。阶段含 empty-september-seven、august-C、A-edited-input/saved/reopened、A-delete-confirmation、history-after-delete、statistics-before-assert-50/30、goal-five-written、restart-B-preserved、completed-UI-chain、failure-before-termination、teardown，部分 home/count/goal stage 自带 UUID。
- 所有阶段需要本批独立 log/xcresult/selectors/源码快照及退出码归档。现有 snapshot `scripts/Makefile` 支持 `SCHEME`、`ONLY_TESTING`、`TEST_DESTINATION`、`DERIVED_DATA`、`TEST_LOG`，但未显式 `-resultBundlePath`；xcresult默认在该 DerivedData 的 `Logs/Test`，主控须按本次实际生成的结果包归档，不能假设固定自造结果路径。调用应锚定 snapshot 的 Makefile，不能误用根项目当前工程。本文不给未绑定真实 UDID/owner 的可直接粘贴执行命令。

最后仍需主控外部只读数据库/偏好验收：原B/C UUID和原数据保留、A级联删除、2entries/2sets/0answers/2pending（UI001实际A update/delete，原0queue预期已由源码及SQL纠正，无清理数据）、目标5；UI绿只代表草稿自动断言，不代替以上证据与图审。当前本文件是准备产物，不意味着任何新执行通过。
