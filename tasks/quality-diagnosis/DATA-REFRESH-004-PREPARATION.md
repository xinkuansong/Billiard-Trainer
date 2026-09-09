# SC11–14 最小刷新与目标持久化补证草稿

2026-09-08。仅准备，尚未注册、类型编译、构建、播种或执行 UI。配套 `DataRefreshFixtureTests.swift`、`DataRefreshDiagnosticUITests.swift`；本轮只新增这三文件。沿 DATA-SC11-14-EVIDENCE-AUDIT 的 A/B 缺口，不重复千场、QD012 或 QD022。

## 有界执行合同

一个受控空白 guest 安装，一个 hosted 播种方法，一个连续 UI 方法。UI 方法先完成 A（日历、已有心得编辑、删除及自动刷新），再 B（每周目标 3→5、重进、一次正常进程重启）。合并为一个方法避免两个方法依赖测试排序或复用已删除的账本；若 A 前置失败，B 未执行，不能算 B 失败或通过。此链只用正常 UI 操作，不恢复清空后的记录。不得自动重跑同一已变更安装；必要重跑须新专用空白安装及独立播种审计。

播种是人工构造诊断数据，不是正常录入覆盖。`forcePremium` 仅放开统计和旧历史访问，保持 guest；不提供真实购买/登录/云同步结论。正常 UI 启动不带 inMemory、数据 fixture、deeplink、authenticatedProfileFixture。真实账户仍不触碰。

## 独立固定账本

Calendar Gregorian，Asia/Shanghai，实际本地日期必须是 2026-09-08；最早执行时间 00:02。跨日直接失败，重新计算新账本，不能改系统时间、删除日期护栏或原地更新旧证据。

|记录|日期与本地时间|时长|c001 条目与组|初始心得|
|---|---|---:|---|---|
|A|9 月 8 日 00:01|20 分钟|条目1：8/10球；条目2：2/5球；各1组|QD-DATA-REFRESH-0908-A|
|B|9 月 8 日 00:02|30 分钟|条目1：3/5球，1组|QD-DATA-REFRESH-0908-B|
|C|8 月 31 日 00:00|40 分钟|条目1：4/10球，1组|QD-DATA-REFRESH-0908-C|

均为 `kind=drill`、真实 canonical `drill_c001` / 半台直线球、同一专用 guest owner。初始3 sessions / 4 entries / 4 sets / 0 answers / 0 pendingSync。预期值由字面账本算出，不调用 App helper 生成 oracle：

|可观察项目|删除 A 前|删除 A 后|
|---|---|---|
|动作卡累计已练（按 entry）|4 次|2 次|
|统计「周」（9 月 2–8 日）训练天数|1|1|
|统计周总时长|50 分钟|30 分钟|
|统计周训练组数|3|1|
|首页（目标3）|本周训练 1 / 3 天，连续训练 1 天|相同（B仍在今天）|
|本月9月8日日列表|20、30分钟两行|仅30分钟 B|
|8月31日日列表|40分钟 C，心得匹配|磁盘应仍有 C|
|9月7日日列表|当天无训练记录|仍为空（不另扩组合）|

全部为球单位，避免重现已知混合单位口径问题。13/20=65%→3/5=60%仅为手算辅助，草稿不再引入命中率定位/四舍五入额外断言。

## 播种护栏与主控先决步骤

复用 `Data1September7FixtureTests.swift` 的真实默认磁盘构造路径，仅替换日期与最小账本，旧文件不动。

1. 主控新建/确认专用空白 guest 安装，用既有只读 empty-store probe 取得实际 owner 与默认 store **相对路径**；不能凭常见 `default.store` 字符串猜路径。检查宿主与 UI target 的安装确为同一 App 数据容器、owner不变。
2. Hosted seed 必须在 App 初始化之前已有 `-v50.inMemoryStore`，这样宿主不会抢先创建真实默认磁盘。其他 `-v*`、deeplink、forcePremium 被拒；bundle 必须 com.xinkuan.qiuji；身份从真实 DeviceGuestIdentity/CurrentOwnerContext 读回。设置 `QD_ALLOW_DATA_REFRESH_DISK_SEED=DEDICATED_EMPTY_GUEST_SIMULATOR`、`QD_EXPECTED_GUEST_OWNER`、`QD_EXPECTED_DEFAULT_STORE_RELATIVE_PATH`。这些 hosted env 使用直接名称。
3. 拒绝已有 store/wal/shm/manifest；相对路径不允许绝对、空段、`.`、`..`，解析 symlink 后必须在真实 NSHomeDirectory 内。通过当前 `ModelContainerFactory.currentSchema` 和 `QiuJiMigrationPlan` 创建默认磁盘。保存后核3/4/4/0/0与owner、心得，落 `Documents/qd-data-refresh-20260908-manifest.json`，带实际 UUID、日期、成绩和相对路径。
4. 主控独立检查 manifest **每一行**及实际数据库读回，不能只看 seed green 或计数。确认日期、20/30/40分钟、两个A条目顺序、球单位、guest一致。正常 UI 安装后再确认容器相对路径/owner/记录仍相同；绝不能把旧 manifest 字符串当当前数据库证据。
5. UI env：`QD_UI_ENVIRONMENT=SEEDED_DEDICATED_GUEST_SIMULATOR`、上述 expected owner/path、`QD_EXPECTED_MANIFEST_JSON`（原件完整 JSON）、`QD_SHOT_DIR`（新独立证据目录）。UI 读取直接名称或 TEST_RUNNER_ 前缀。预期初始 weeklyGoalDays 自然默认为3；不预写目标来绕过失败。

## UI Oracle 与实际来源

- `snapshot-004/.../HistoryCalendarView.swift`：月份前后按钮、dayCell、空日文案与详情 onDismiss reload。已读真实 `formal-004-template-continuation-007/screenshots/template-continuation-16489A2E-history-before-template-delete.txt`：月份按钮 identifier `chevron.left`/`chevron.right`，标题 `2026年9月`；未标记日 label `7`，标记日 `8、走位`，跨月日 disabled。因此草稿按真实日号正则 `^8(、.*)?$` 加 enabled 筛选，不猜本次 marker 文案；按钮 query 必须唯一。
- 切至9月7日，断言 `9月7日 星期一` + `当天无训练记录`；切8月31日，打开唯一40分钟行并读 C 心得；返回9月8日打开唯一20分钟行，再以 A 心得确认身份。日期标题源为 `HistoryViewModel.selectedDateTitle` 的 M月d日 EEEE，月标题 yyyy年M月。
- `TrainingDetailView` 确有「更多操作」→「编辑心得」；`TrainingNoteView` 使用 `UITextView trainingNote.editor` 和 `trainingNote.dismissKeyboard`，完成按钮为「完成」。原有心得先精确匹配；键盘实际出现后插入一次 `-EDIT`，不猜 UIKit 光标。断言新文本恰为原文某处一次插入（移除唯一 -EDIT 必须还原原文），保存后与重开后都读回**完整新文本**。插入位置不影响持久化契约，不把新文本存在当未变内容通过。
- 删除前再次确认已编辑 A 内容，确认标题「删除这条训练记录？」再点删除。要求详情退出、A行消失、B仍在；不重新加载磁盘或重启，先依次核首页、动作卡4→2、周统计50→30与3→1，从而检测正常切页后的自动刷新。
- `TrainingGoalView` 有1–7的「N 天」按钮与当前 `/ N 天` 文本，`ProfileView` 有「训练目标」。正常 guest 默认3，点5，读当前5；首页1/5、再次进入5，随后一次正常 terminate/launch，再读首页1/5、目标5、动作卡2、B心得与A不存在。不要把 profile静态3改为5当目标持久化证据。
- 统计值按同一屏真实 caption 与上方唯一整数的 frame 绑定，源来自已用 DATA1 layout；不从任意同值文字找命中。只读文字不要求 hittable；点击控件需要 hittable、非空frame、窗口内且不在可交互 TabBar 下方。滚动使用实际 scroll container 与可交互 TabBar 边界，有界12次。节点缺失/歧义是待观察或诊断失败，不能自动放宽成绿。

## 证据、判定与范围

每个关键阶段先PNG再AX写入唯一stem，并保留 xcresult attachment；任意业务/前置失败进入 catch 先截图/AX，再 throw，teardown取终态再终止进程，不吞异常、不删除播种或失败现场。主控必须检查真实图像，尤其空日、C、A编辑保存/重开、删除后的B、统计caption值、3→5与重启5。

UI green仍需主控读回最终真实磁盘：session ID 必须仅初始 B/C；entries2/sets2、B/C原成绩/日期/心得不变、A及其2entries/2sets级联消失，0 answers / 2 pending（A 的 update 和 delete，见下方实际 SQL 核销），真实 guest preference weeklyGoalDays=5。该外部读回未完成不能宣称全链数据完整性通过。草稿不写磁盘清理代码，也不直接读取 UI 进程业务内存。

已做 `xcrun swiftc -frontend -parse` 两草稿，语法通过；不代表模块导入、helper注册、SDK类型编译或运行已通过。UI依赖已有 `switchTab` 测试helper，由主控审核注册依赖；先确认 App/UITest 的本地 guest不连真实用户服务。对新 fixture 的日期日历AX尚无运行证据：若实际组合节点不符，应保留AX后只修观察器，不改业务/账本/oracle。真机、真实账号同步、其他时区/DST及上线性能均不在此最小补证内。

## 主控复审后的必要护栏与来源补充

- UI `setUpWithError` 在启动 App 前要求实际 `SIMULATOR_UDID` 等于非空、显式提供的 `QD_EXPECTED_DEVICE_UDID`；两者均经统一 env helper 支持直接名及 `TEST_RUNNER_` 前缀。此为 runner 所在模拟器护栏，不能代替前述 App 容器/guest 核验。
- `ready` 同时等待 exists/hittable/enabled，再检查实际 frame。首次 launch 明确等待 `.runningForeground`；目标持久化的进程重启先 `terminate`、等待 `.notRunning`，再日期校验、launch、等待 `.runningForeground`。任一失败中止，不能继续误标重启通过。
- 目标文本已用当前冻结源和**实际 AX 原件**交叉核验：`build/quality-diagnosis/snapshot-004/QiuJi/Features/Profile/Views/TrainingGoalView.swift:142` 是 `Text("/ \(profile.weeklyGoalDays) 天")`。`archive/quality-diagnosis/runs/formal-004-notification-deny-retry-ui-001/screenshots/system-AC2FC213-8C26-4E79-A9DB-6BBF79BE81EC-denied-retry-before-AX.txt:29` 确有独立 `StaticText label: '/ 3 天'`；同原件37行为 `Button label: '3 天', Selected`，41行为 `Button label: '5 天'`。因此初始 `/ 3 天` 是已观察形态，修改后的 `/ 5 天` 是同一动态 Text 的明确源码预期，尚未实际观察，不预先写成通过。这里准确保留斜杠后空格及数字后空格。
- 可复用的 empty-store probe **真实源码路径**为 `tasks/quality-diagnosis/ThousandStoreProbeTests.swift`，精确 selector 为 `QiuJiTests/ThousandStoreProbeTests/testReportInMemoryHostAndEmptyDefaultStore`；编排说明为 `tasks/quality-diagnosis/THOUSAND-EXECUTION-PREPARATION.md` 的首启动序。未找到独立 probe shell/Python 脚本，不虚构脚本入口；如需调用经主控审核注册的 selector，可使用现有 `scripts/Makefile` 的 `ONLY_TESTING`→`-only-testing` 管道，具体 scheme/设备由主控既有执行链提供。
- 已全文复核 probe 方法：必须 `QD_PROBE_ENVIRONMENT=DEDICATED_EMPTY_GUEST_SIMULATOR`，宿主预先带 `-v50.inMemoryStore`；仅构造 `ModelConfiguration` 获取 URL，不开真实磁盘 `ModelContainer`，JSON attachment 名 `thousand-store-preflight`，给出 `guestOwner/defaultStoreRelativePath/storeExists/walExists/shmExists`。环境字符串不符时旧方法会 `XCTSkip`，所以主控必须检查**方法实际执行且没有 skip**、所有断言通过及 JSON 三个 exists=false 后才进入 seed。旧 probe 未核显式 UDID，也不证明 Keychain 无真实凭据，须由主控设备边界保证；不修改该旧方法。新 seed 自身仍会再次拒绝现有数据库及验证规范化路径、owner，不能直接信任 probe 的相对路径推导。

本次只补 UI 草稿与本说明；fixture账本保持不变。更新后再次仅 Swift parse 检查通过，未注册、编译运行或触碰设备。

主控最新适配（尚未注册）：probe/seed支持TEST_RUNNER前缀但仍要求授权值匹配，probe缺授权XCTFail+throw不再skip。UI搜索增加仅在已观察Speed up your typing文案存在时点击唯一Continue，并严格核实际查询值；此键盘前置在AccountFailure001实际新设备出现。新语法parse0，不计类型编译/执行通过。详见RUNBOOK。


## UI001 失败后的独立目标持久化 companion（待审、未运行）

原 `testCalendarNoteDeleteAutomaticRefreshAndGoalThreeToFivePersists` 方法原样保留：UI001 实际删除 A 后统计总时长仍 50，没有变为 30，该失败不能被本方法替代或撤销。新增精确 selector：`QiuJiUITests/DataRefreshDiagnosticUITests/testGoalThreeToFivePersistsAfterRecordedDeletion`，1 方法，仅复用本次既有删除后磁盘，不重新 seed、不重新删除 A。

setUp 原 manifest 仍为初始身份/3 sessions/4 entries/4 sets/0 answers/0 pending 的出生账本，**不是当前磁盘状态**。新方法额外必须提供 `QD_GOAL_COMPANION_AUTHORIZATION=AFTER_UI001_DELETION_SQL_VERIFIED` 与 `QD_GOAL_AFTER_SQL_JSON`（完整原件字符串，支持 TEST_RUNNER_ 前缀）。原件为 `archive/quality-diagnosis/observations/data-refresh-001-after-failure/independent-sql.json`；只接受实际 schema，不要求原件不存在的 fixture/device 字段。沿用原 setUp 日期、时区、calendar、环境和实际 UDID 匹配，再固定本次 UDID `269AB5D4-0E43-41E6-9806-016B99996F25` 及 owner `guest:c24e68e8-857e-47c4-9cc5-82165b40a01a`。日期过期必须停止，不改系统时钟。

独立 JSON 前置要求 counts=2 sessions/2 entries/2 sets/0 answers/**2 pending**，零孤儿、唯一原 guest，unchangedBC/deletedAAndChildren 均 true、weeklyGoalDays=3、goalPreferencePresent=false。原 manifest 的 A/B/C UUID+note 必须匹配实际 ID；after 仅 B/C，且每行完整 JSON（日期、成绩、动作与心得）必须与初始行相同。queue 必须恰为原 A `24C19AFD-C5A8-46E7-A75C-072AF68029E8` 的 TrainingSession update/delete，各自属于该 guest，不删除或跳过队列。完整 JSON 作为附件保留。

此前准备文档的最终 0 queue 预期错误，已在本次改为 2 pending。主控独立 SQL 验证曾因期待 0 而两次失败，原件 verifierNote 已保留；主控只读 LocalTrainingSessionRepository 确认正常编辑/删除分别 enqueue，未清队列。这是外部验证预期修正，**不影响 UI001 统计 50→30 未刷新的产品失败**。

流程：home3/count2→9月8日 A20 行不存在、B30 原 note→8月31日 C40 原 note→返回9月→目标3→点5→离开 home5→重新进目标5→terminate 确认 notRunning→重启 home5/goal5/count2→B30 原 note、A20 行未回→记录 `companion-goal-persistence-verified-before-statistics` 图和阶段日志→最后严格 stats30/sets1。统计若仍错，整个方法失败但目标分支已有独立阶段证据；不能把失败方法统计为通过，也不能因此抹去先完成的目标子证据。

外部 SQL 是启动前提供的快照证据，不是 XCUITest 对宿主数据库的实时读取；完成后仍由主控独立检查真实 guest 偏好=5及 B/C/队列保持。UI 内未获得 session UUID 的直接可见控件，因此 UUID 来自 SQL 前置，UI 通过实际日期+分钟+原 note 交叉确认，不能冒称 UI 直接读出了 UUID。新增方法与 SQL guard 均只 append，原 method/setup/helper 未改。仅 swiftc -frontend -parse 退出 0，未注册、构建、运行或操作设备。
