# DATA1：9 月 7 日独立混合磁盘账本

2026-09-07。基线 `build/quality-diagnosis/snapshot-003`。本次只新增两份 Swift 诊断草稿和本文，原 `Data1DiskFixtureTests.swift`、`Data1UIDiagnosticUITests.swift`、`DATA1-PREPARATION.md` 保留。**未注册、编译、运行或操作设备；没有新测试通过结果。** 七场由真实 SwiftData 模型合成播种，随后正常 App 磁盘读取，不能表述为七场通过 UI 创建。

## 日期变化与当前代码核对

适用日仅 **2026-09-07，Asia/Shanghai，公历，00:03 后**；跨日拒绝，不改系统时间。与旧周日账本相比，今天为周一，首页自然周重新开始。不能仅替换日期字符串并沿用首页 3/3 天。

已只读核对 snapshot-003：

- `QiuJi/Features/Training/Views/TrainingHomeView.swift:1339` 明确用 `(weekday + 5) % 7` 求周一，独立于地区默认 firstWeekday；`:1318` 组合 AX 为“本周训练 N / M 天，连续训练 S 天”。`:1523` 分母现为 `max(实际天数, profile.weeklyGoalDays)`，新游客默认 3，故本账本为 **1 / 3 天、连续 2 天**。
- `QiuJi/Features/History/ViewModels/StatisticsViewModel.swift:70`：周从今日零时减 6 天，月减 1 个历月，年减 1 年。训练量含 drill+cognitive、排除 tool；成绩/组数仅 drill。当前过滤未设置未来上界，因此本 seed 明确拒绝未来样本，不能以本批证明未来脏数据处理。
- `QiuJi/Features/History/Views/StatisticsView.swift:196` 仍为数字在标题上方的布局，标题“本周/月/年训练天数”“分钟 · 总时长”“训练组数”；`:530` 混单位摘要、组数、“单位混合”仍同一 HStack。沿用唯一可见标题和唯一数字框关联、同行摘要绑定；保留歧义即失败。
- `QiuJi/Features/DrillLibrary/ViewModels/DrillListViewModel.swift:187` 实际按 owner 下不同 entry UUID 计次，不按 session，A 的两 entry 必须算两次。这里只构造 drill 的 entry，不能由本批外推非法 tool entry 的计次。
- `QiuJi/Features/Profile/Views/ProfileView.swift:34` 游客不显示月概况，`:223` 保留 `profile.login`。自然月值只作独立解释，不能假装游客 UI 已验证月卡。
- `QiuJi/Features/History/Views/HistoryCalendarView.swift:348` 保留名称、项目、组、分钟的行；`Resources/Drills/fundamentals/drill_c001.json` 仍是半台直线球。动作卡“已练”布局改动不改变本草稿的卡内语义绑定。

本次没有读取活跃 UI 树，以免干扰主控测试；上述是当前代码的 AX 声明和布局契约，**实际 AX 合并/可点性仍须首次执行取证**。失败时保留 PNG/AX，不删为全局数字存在。

## 新字面账本

所有 note 前缀统一 `QD-DATA1-0907-`，与旧 seed 明确区分。

| 标记 | 上海日期/时间 | kind | 分钟 | c001 成绩 |
|---|---|---|---:|---|
| A | 09-07 00:01 | drill | 20 | 两 entry，8/10 球、2/5 球，order 0/1 |
| B | 09-07 00:02 | drill | 30 | 一 entry，1/2 局 |
| C | 09-06 00:00 | cognitive | 5 | 无 entry；关联一题 geometric，actual 45/user 40，题目 00:01 |
| D | 09-07 00:03 | tool | 99 | 无 entry，历史标题取 note |
| E | 09-01 00:00 | drill | 10 | 3/10 球 |
| F | 08-31 00:00 | drill | 40 | 4/10 球 |
| G | 08-06 00:00 | drill | 80 | 6/10 球 |

共 7 session、6 entry、6 set、1 AngleTestResult、0 SyncPendingItem；5 个 drill session 却为已练 6 次。局单位是刻意合成的历史快照差异，不声称 c001 现行训练能正常生成此单位。没有复制造成 QD012 的未完成组。

## 标准库独立复算

准备时实际执行 `/usr/bin/python3`，仅使用 `datetime.date/timedelta`。输入为上述逐行 kind/date/minutes/sets；不 import 项目、不调用产品指标。周一起点用 `today - timedelta(days=today.weekday())`，滚动周为减 6 天；本月无月底截断歧义，历月起点字面为 2026-08-07，年为 2025-09-07。过滤 `start <= row.date <= today` 且 kind 属于 drill/cognitive，按日期集合、分钟加法、drill 的 set 列表分别计数，输出为：

```text
homeWeek     2026-09-07 AB     1  50 3 11 17 {'局': (1, 2), '球': (10, 15)}
rollingWeek  2026-09-01 ABCE   3  65 4 14 27 {'局': (1, 2), '球': (13, 25)}
rollingMonth 2026-08-07 ABCEF  4 105 5 18 37 {'局': (1, 2), '球': (17, 35)}
rollingYear  2025-09-07 ABCEFG 5 185 6 24 47 {'局': (1, 2), '球': (23, 45)}
naturalMonth 2026-09-01 ABCE   3  65 4 14 27 {'局': (1, 2), '球': (13, 25)}
```

列顺序为起点、标记、天数、分钟、组数、混合 made/target、分单位 made/target。连续 9/6–9/7 为 2 天；8/31–9/1 另有两天但不是当前连续段。自然月最长连续 2 天、65 分钟显示 1h5m，仅模型预期。首页自然周 1 天与统计滚动周 3 天不同是预期口径差异。

统计周/月/年仍是 65/105/185 分钟、4/5/6 组、3/4/5 天；与旧账本数字相同来自重选每个边界日期的独立加法，**不是复制旧测试结果**。D 的 99 分钟不进这些数值。今日历史应有 A/B/D 三条；C 在昨日；其余 E/F/G 分别在 9/1、8/31、8/6。

当前同一 fundamentals 分类的混单位刻画为 `14/27 局/球`、`18/37 局/球`、`24/47 局/球`，且需伴随 4/5/6 组和“单位混合”。这些跨单位合计只用于识别当前显示行为，**不是认可局和球可以通分**；独立正确解释保留上表分单位数。本 UI 草稿不验证 52%/49%/51% 百分比或图表，不能外推。

## 文件、选择器与护栏

新增：

- `Data1September7FixtureTests.swift` → `QiuJiTests/Data1September7FixtureTests/testSeedSevenSessionLedgerIntoDedicatedEmptyDefaultStore`
- `Data1September7UITests.swift` → `QiuJiUITests/Data1September7UITests/testNormalGuestHomeTodayHistoryAndEntryCount`
- 同 UI 类 → `testNormalGuestStatisticsRangeValuesAndProfileBoundary`

seed 必须在**全新专用游客设备**先执行只读 probe，再以宿主启动层 `-v50.inMemoryStore` 的独立 scheme 运行。原空库条件全部保留：真实默认 ModelConfiguration URL，仅以 probe 给出的相对路径作比较；拒绝绝对/空组件/点/上级路径；解析符号链接后在当前 home 内；默认 store、wal、shm、manifest 均不存在。已有 guest owner、CurrentOwnerContext、bundle 必须一致。不得清库重跑失败 seed。

必需环境保留 `QD_ALLOW_DATA1_DISK_SEED=DEDICATED_EMPTY_GUEST_SIMULATOR`、`QD_EXPECTED_GUEST_OWNER`、`QD_EXPECTED_DEFAULT_STORE_RELATIVE_PATH`。新增 seed 对 `-forcePremium` 拒绝，统计解锁仅用于后续正常 UI，seed 不需要购买覆盖。仍不得使用 deeplink、其他 v 系列数据 fixture、真实登录或同步。

成功保存并核对实际 7/6/6/1 数量、每行 owner、note 集合、认知 sessionId、同步队列 0，以及未跨午夜后，才写唯一新路径 **`Documents/qd-data1-20260907-manifest.json`**。fixture 为 **`DATA1-20260907-v1`**。失败不发 manifest，已留 store 保留为失败证据。manifest 逐条记录实际数据，主控必须与本表核对，不能只信 counts。

UI 环境保留 `QD_UI_ENVIRONMENT=SEEDED_DEDICATED_GUEST_SIMULATOR`、真实 `QD_EXPECTED_MANIFEST_JSON`、同 owner/相对路径、新 screenshot 目录。UI 新增检查 manifest 的 localDay/timezone；使用正常磁盘、真实 guest，仅 `-forcePremium` 解锁统计，不用 auth fixture。主控核对 probe→seed→终止宿主→重新取实际容器→正常 UI 的安装数据存续链；容器 UUID 可变化，不能只复用旧绝对路径。只观察专用 guest，不读其他用户数据、Secrets 或全量 defaults。

## 实际计划覆盖与边界

第一 UI 方法检查首页 1/3、连续 2 → 动作库 c001 已练 6 次 → 今日 A/B/D 唯一行 → A 唯一 note 和 8/10、2/5 两 entry → 返回首页。第二方法逐一检查滚动周/月/年概况与混单位提示，最后验证游客无月卡。

尚不包括历史 B/C/E/F/G 每条详情、真实登录月卡、统计图表、认知误差卡、百分比、重复杀进程重读、正常七场 UI 创建、服务端恢复。也不提高任何覆盖等级，必须等待主控注册与实际运行。
