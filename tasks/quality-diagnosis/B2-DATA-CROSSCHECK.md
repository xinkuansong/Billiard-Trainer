# DATA1 / SC36 追加诊断准备

状态：只读审计及独立测试草稿；未编译、未运行、无 UI 实看，不能计入通过数。业务真源为 `build/quality-diagnosis/snapshot-002/`。本轮仅新增本文件及 `CrossDataDiagnosticTests.swift`，由主控审核后复制进正式诊断 harness，单独登记选择器/哈希/结果，不变更冻结业务源。

## 已核对的口径与边界

- 现行 `.kiro/steering/content-data-contract.md:307–331`：训练量/目标计 drill+cognitive，tool 只活跃，不计准确率；准确率按 category 分组，不再全局相加。
- 冻结 `QiuJi/Features/History/ViewModels/StatisticsViewModel.swift:69–127`：周为今天及前6天；月为今日零点向前1日历月；年向前1年，均只设下界。不同于自然周、自然月，不能要求所有页面显示相同数字。未来异常日期的处理仍是缺口。
- `…/StatisticsViewModel.swift:161–177,199–201,227–231,331–360`：训练日去重、时长求和、组数只算 drill；分类成绩汇总全部持久化组。`…/Profile/Views/TrainingGoalView.swift:24–72`：目标 daysTrained 仅 since 下界；个人月卡明确自然月上下界并去重、最长连日。`…/Profile/Views/ProfileView.swift:167–173,411–425`：实际个人卡接 monthlyOverview，已有 AX 数字入口。
- `…/History/ViewModels/HistoryViewModel.swift:267–330`：历史 drill/cognitive/tool 三种各成行，cognitive/tool 需要独立投影数组，仅给 sessions 赋值不能冒充历史加载链通过。新草稿显式投影，验证呈现模型，**不验证 repository/loadSessions/真实 UI**。
- `…/StatisticsViewModel.swift:331–360` 同一 category 混单位仍合并 made/target；`…/History/Views/StatisticsView.swift:530–537` 有“单位混合”提示但比例仍显示。这是可复现语义疑点；契约明确跨类别禁混，同类别处理没有足够裁定，不能擅自设“正确单一比例”。
- `QiuJi/Data/Models/DrillSet.swift:5–45` 无完成标志；参见已交付 `PARTIAL-TRAINING-FINDING.md`。新测试仅刻画影响，不新增重复缺陷，不将“当前行为复现通过”解释成预期达标。

## 一轮最多四条选择器

类路径均为 `QiuJiTests/CrossDataDiagnosticTests/`，独立草稿里共4条，不计入既有 B2 方法数。

| 方法 | 独立账本与断言 | 覆盖 / 不覆盖 |
|---|---|---|
| `testCrossKindMultipleSessionsRollingWeekAgainstLiteralLedger` | 今天 drill20分8/10、drill30分2/5，昨天 cognitive5分，今天 tool99分，第6天前 drill10分3/10局，第7天前 drill200分排除。滚动周4场训练、3天、65分、3组；准度10/15，走位不合并；今天历史3行（2训练+工具），动作a计2条 | 跨日与滚动周边界、同日多场、kind、目标同下界、动作计次、历史呈现模型。未覆盖首页计划身份/刷新，也未覆盖周图每根柱。 |
| `testNaturalMonthAndCalendarWeekUseLiteralBoundaryLedger` | 固定 Gregorian UTC：8/31 drill100，9/1 drill20+30，9/2 cog5，9/3 tool99，9/4 drill10，10/1 drill200。9月自然月3天65分最长2天；截至9/5的8/31起自然周4天。显式未来10/1只用于月上界，周调用不供未来行 | 自然月前后边界、跨自然周、同日多场、tool排除。统计 VM 无注入 now，不能用固定2026-09数据证明其当前滚动月；草稿第一条采用相对今天日期，并检查未跨午夜。 |
| `testCharacterizeMixedUnitsAndUnfinishedPlannedSetsNotAcceptance` | 综合分类：已完成8/10球+七组未操作0/10球，另一条1/2局。当前持久化共9组9/82、单位集合球/局、混合标志true。真实完成应单列2组，球8/10与局1/2各自展示 | **刻画测试**：通过仅确认损失信息后的现状。不能证明正确、不证明保存链，不能把7个0成绩猜成未完成：真实全部练完但0进球也可以具有同一数据形状。 |
| `testThousandPersistedSessionsIndependentCounts` | 1000条真实 SwiftData 内存session，同日500 drill每条2分一组1/2；250 cog每条3分；250 tool每条4分。fetch1000、训练750场1天1750分、tool1000分、500组、50%、动作500条、历史1000行/500训练行 | 保存/fetch/关系与多投影大样本一致性；非磁盘、非冷启动、非真实UI渲染、非内存峰值/卡顿证明。cog无题目仅测行与训练量，不证明认知成绩聚合。 |

预期值来自上表有限账本及整数算术，未调用生产过滤/聚合产生 expected。日期辅助仅建样本，不把生产统计结果回填 oracle。首条滚动周与第二条固定自然月分别控制时钟适用范围，不能拼成一次真实四页端到端验证。无达标线样本不等于达标成绩缺失；本批不新增 pass 判定。

## 安全审计与执行建议

草稿显式 owner `guest:quality-cross-data`，不构造 AuthState/同步服务/仓储，不调用 saveSession/deleteSession，不登录、不连网、不写资产。千条场景直接用 `ModelConfiguration(isStoredInMemoryOnly: true)`+当前 schema 建容器，避免 `ModelContainerFactory.makeInMemoryContainer():35–48` 内部默认设备guest identity与迁移入口的附带动作。其余仅脱离 context 的模型与计算属性。代码无计时阈值、截图导出、固定路径写盘。测试宿主 App 自身仍由主控既有专用无凭证环境策略约束，不能因单测安全声称宿主绝无启动副作用。

审核后只执行上述4个方法；第三条结果标注 characterization，不并入“预期符合”分母。千条方法首次只跑一次正确性；如另取耗时应重复固定轮次并报告环境/中位/最大值，同时明确包含建样本还是仅查询；没有当前有效性能阈值，不能自行发明通过线。

## 现有 UI fixture 能做什么

1. 冻结 `QiuJi/App/RootView.swift:67–70,475–541` 的 `-v57.practiceCountFixture -v57.practiceCount=1000` 有独立内存容器、固定guest owner，**1个session内1000个entry**，仅动作库导航，能正常通过fixture保存/删除按钮验证计次刷新。不是1000训练session，也不带全Tab，不能据此闭环历史/统计/个人卡。root fixture不消除宿主初始化的外部条件。
2. `RootView.swift:116–120,233–290` 的 `-v54.historySource=official/template` 仅建1条来源明细，使用环境modelContext；单独参数不保证内存，且绕过正常历史入口。不能扩充为千条全页数据的现成入口。
3. 本轮定向检索未发现把统一任意账本注入整个 MainTabView 且跨页共享的冻结fixture。现有 Profile AX 有利于读取但不解决播种；不得臆造 `-seed1000`。正常训练逐条建立1000场代价大且污染统计，不建议。
4. SC36历史/统计实际UI仍缺受控同owner全Tab账本入口（需单独获准诊断host或外部隔离store准备方案），以及1000条时滚动/切统计/回个人页/切月、多轮冷启动的截图、耗时、峰值内存与crash证据。单测成功不关闭此缺口。

## 对先前准备文档的更正

`B2-SELECTORS.md:20`“未找到本快照专门1000条practiceCount单测”的说法不准确：冻结 `QiuJiTests/DrillListViewModelTests.swift:282,318–329` 已有 **`QiuJiTests/V57PracticeCountTests/testLargeCountsAndZero`**，覆盖0/1/2/10/100/1000 entry。文件名与测试类名不同，不能用 DrillListViewModelTests 当选择器类名。本轮未执行；供主控对照既有正式账本查是否已跑，避免重复计数。本文不修改此前交付文件。`V57PracticeCardRenderTests` 属渲染制作方向，不纳本批。
