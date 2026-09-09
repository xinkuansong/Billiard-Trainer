# 千场正常磁盘 UI 性能观察草稿

2026-09-08。只新增本文件及 `ThousandPerformanceDiagnosticUITests.swift`；未注册、编译或执行。语法 parse 通过。依据 [THOUSAND-PERFORMANCE-004-PREFLIGHT.md](THOUSAND-PERFORMANCE-004-PREFLIGHT.md) 的唯一有限链，不重测999/978详情、不遍历千场。

## 选择器与运行前置

`QiuJiUITests/ThousandPerformanceDiagnosticUITests/testObserveThousandRecordScrollStatisticsAndReturn`

主控新专用设备 `CCA94E7E-981D-4F16-A115-40677FC3097C`。主控先串行完成新内存宿主 probe、实际默认磁盘 seed、宿主终止、manifest 原件/独立 SQL 1000 sessions/entries/sets 与 queue0核验，才允许此 UI 测试。代码不种库、不搬库、不改 guest 身份、不使用 fixture/deep-link 路由。使用正常磁盘根入口的一次 launch，若 App 已在运行直接失败，不自行接管旧宿主。

环境均支持 direct 优先和 `TEST_RUNNER_` 回退；缺少或不匹配即 throw，不 skip：

| 键 | 值 |
|---|---|
| `QD_UI_ENVIRONMENT` | `SEEDED_DEDICATED_GUEST_SIMULATOR` |
| `QD_EXPECTED_DEVICE_UDID` | 上述新设备 UUID，必须与实际 `SIMULATOR_UDID` 相等 |
| `QD_SHOT_DIR` | 新绝对空叶目录，不能与 probe/seed 输出共用 |
| `QD_EXPECTED_MANIFEST_JSON` | 主控从实际磁盘取得的完整 seed JSON 原文 |
| `QD_EXPECTED_GUEST_OWNER` | probe/seed 实测 owner，与 manifest 相等 |
| `QD_EXPECTED_DEFAULT_STORE_PATH` | 主控核对的实际 seed 默认磁盘绝对路径，与 manifest 相等 |

代码强验 manifest：bundle=com.xinkuan.qiuji，1000场/entry/set，1天、2000分钟、8000成功/10000目标、queue0。运行开始和结束检查 runner 当地日仍等于 manifest.localDay；主控须保证 Simulator/App/runner 时区一致，当天结束前执行。UI runner不能独立打开 App 沙盒数据库核验输入真实性；manifest和SQL链仍是主控硬前置，不将环境值当独立实测。

启动参数仅中文、zh_CN、已完成 onboarding 和 `-forcePremium`。统计源码存在 Pro 门控；主控已明确授权此参数仅开放性能观察中的统计内容，不代表真实购买、权益或普通 guest 可用性验收。无 inMemoryStore/authenticatedProfileFixture/深链。App启动常规任务可能写其自身偏好/迁移标志，测试不声明磁盘逐字节不变；不点击详情、录入、删除、编辑。

## 一次有限操作链与证据

1. 正常 launch→底部「记录」按钮可操作；单独记录启动到该节点 ready，非启动 SLA。
2. 点击「记录」→「统计」分段按钮可操作且当月标题可见，保存01 PNG/AX。
3. 在实际 active ScrollView与分段/TabBar交集里上拖一次（可视高度46%），在前32候选内找到含「半台直线球」「2 分钟」的实际完整可见可操作行，不打开；保存02。无第二次历史滚动，无行则失败。
4. 正常点击「统计」→训练概况/2000/分钟·总时长/1000/训练组数完整可见；保存03。
5. 固定最多6次统计页短拖，找到同一分类行的 `8000/10000 球`、`1,000 组`，两者midY差<12；保存04。统计显露滚动逐次单独记录，其计时终点为拖动返回且App前台，**不把它标成摘要ready**；最后另记真实摘要 AXready检查。无再次打开统计/切换时间范围/循环重试。
6. 点击「历史」→实际行再次可用，保存05，核当天日期。结束后终止App并等待notRunning。

文件：`input-manifest.json`、`operation-observations.json`、01–05各PNG及AX.txt；失败先更新事件 JSON，再保存failure PNG（读回）和AX。PNG先于AX查询，以免AX卡住时丢失已取得画面；附件同时保留xcresult。所有已完成阶段原件保留，不清目录/覆盖图片。

计时用 `ProcessInfo.systemUptime`，每个 completed事件含start/end/差值。操作前先写prepared事件，随后取start再执行动作，避免日志写入污染区间；ready后截图/完整AX采集在计时外。若失败只保留prepared与failed终态，不伪造completed；无成功阈值、FPS、内存泄漏断言或新SLA。标量含XCTest输入派发、idle等待、AX查询、轮询和框架成本，并非纯产品延迟。不同阶段因截图/AX已预热、统计预加载，不可相加解释为冷用户旅程。

主控需保持连续xcresult或外部录屏，并另采实际App PID/RSS、采样时间/进程启动边界；代码不从UI runner PID冒充App内存。五图仍须实看（尤其统计数值、返回历史以及一次拖动实际视觉变化）；行label没有独立ID，方法不声称证明不同记录编号。原999/978正常详情历史结果保留，不再重复长链。

## 已核实际源码与现场适配边界

全文阅读旧 `ThousandHistoryUIDiagnosticUITests.swift` 与 `ThousandHistoryFixtureTests.swift`，保留旧中文AX发现：概况值来自String参数，值为1000/2000；分类内SwiftUI整数插值实际曾为`1,000 组`，不能重新写成旧失败的`1000 组`。历史用例439/121秒不等价交互延迟。旧UI草稿skip/弱前置没有复制进本方法。

核对 frozen004 的 `QiuJi/Features/History/Views/HistoryCalendarView.swift` 的正常分段、ScrollView、行组合、可操作性与月标题，`StatisticsView.swift` 的门控、概况与分类摘要；两个ViewModel的真实load/filter/聚合、日期范围与格式。核 `QiuJiUITests/Helpers/XCUIApplication+Extensions.swift` 正常「记录」标签；本方法直接操作iPhone底部TabBar，避免helper隐藏的activate/重试进入观察区间。没有依赖未注册helper。

当前工作树与004以下4源逐字节相同；当前SHA256：

| 相对QiuJi路径 | SHA256 |
|---|---|
| Features/History/Views/HistoryCalendarView.swift | b56d2c12e3770401364f9785189ef99c94f66400ebf1a24f8203e135bd57f289 |
| Features/History/Views/StatisticsView.swift | 760292b55bc1247cc6f6de0e06e1d62322c5eb74726725aa823b4e02bc74a50e |
| Features/History/ViewModels/HistoryViewModel.swift | 5337eadb0db54f486cf5692732b6984e13ee478a3229de0543608aab2cf772a1 |
| Features/History/ViewModels/StatisticsViewModel.swift | 1667e066ece0e9731bab08e91b55b3ec646f5ca91eee699f0cea21e54226bf03 |

`HistoryCalendarView`以opacity/hit-testing保活历史和统计，统计可能在进入记录页时就加载；不是点击统计后才冷创建。因此这里只报告已存活视图切换、显示和查询端到端耗时。两个ViewModel读owner范围仓储；单日合成drill数据在默认最近7天范围内，恰1000组/2000分钟/8000到10000球。该合成时间分布不代表真实千日或混合kind工作负载。

有意保留有限现场未知：active ScrollView必须唯一且hittable；iPhone底部TabBar必须存在；文字要求整frame在真实分段与TabBar之间，不以只读文字hittable作判据。若隐藏ZStack仍干扰AX、首次短拖未露行、布局把概况推到屏外、数字本地化与已知证据不同，先保留原图AX失败，主控据实仅适配观察节点/视口，不改统计字面总值、不追加历史长滚动或绕过真实数据前置。XCTest单次AX调用本身可能超过30秒名义等待，外部监控负责保留超时原件，代码无无限轮询。


2026-09-08 perf-ui001构建失败：NSStringFromCGRect在当前SDK不可用，0方法执行，make2/recorder0，25文件及observer归档；不是产品失败/性能数据。只将两处日志矩形格式化改String(describing:)，不改数据前置、断言、操作或超时；002独立输出补验。
