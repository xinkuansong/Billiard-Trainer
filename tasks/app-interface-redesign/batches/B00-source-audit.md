# B00 源码预核与并行规划审查

日期：2026-10-08。性质：只读规划；未构建、启动 App、操作 Figma、执行模拟器或真机验收。页面入口汇总见 [PAGE-INVENTORY](../PAGE-INVENTORY.md)。

## 执行者与范围

| 执行者 | 模型 | 范围/产物 |
|---|---|---|
| training_library_inventory | gpt-6.1-sol / high | 训练、动作库、练习/理论外壳的入口、状态与共享调用核查 |
| profile_history_inventory | gpt-6.1-sol / high | 我的、设置、账号、记录与统计核查；追加全局/每日设置区分 |
| parallel_plan_audit | gpt-6-astra / high | 共享依赖、工作树基线、工具并发与验收风险审查 |
| 主控 | 当前会话 | 独立回读关键来源，汇总需求/页面/批次/协议；负责中央文档 |

子智能体均只返回调查结果，没有编辑业务文件或中央进度。以下为返回结论及主控核对后的记录，不能代替运行证据。

## 已核实的关键交集

1. `MainTabView.swift:7/72/79` 的导航、全局训练胶囊与会话覆盖；`AppRouter.swift:42/54` 的导航栈/训练生命周期必须归公共批。
2. `BTContentGridCard.swift:7` 被 TrainingHome、PlanList、AngleHome 和 BTDrillCard 消费；不同卡片内容比例不能因统一风格全部抹平。`BTLibrarySearchBar` 被动作库和练习首页共同使用。
3. `BTFilterChip.swift:6` 在 TrainingHome `:1721`、DrillList `:300` 复用；`BTSegmentedTab` 被训练/记录/统计相关视图消费。全局 Colors/Typography/Spacing 也被 FreePlay 等球桌页消费，修改默认值需联合回归。
4. `CustomPlanBuilderView.swift:51` 消费 `ActiveTrainingView.swift:894` 定义的 `DrillPickerSheet`；不能以模版与会话属于不同任务而并写该源文件。
5. `PlanListView` 中的 `CustomPlanAtmosphere` 被首页复用；首页含 `TodayCourseSelectionView`，首页/选择器必须同属一批。
6. `DrillDetailView.swift:157` 起集精讲、试打、球形选择、加入训练与订阅，训练/动作库/练习/收藏均可消费。详情与支付页必须各有唯一改动负责人。
7. `HistoryCalendarView.swift:42/59` 同时保活统计并以 sheet 呈现训练详情；详情复用 Training 的分享与补记。`TrainingDetailView.swift:115/123` 分别呈现分享和数据编辑，不能按 Feature 目录隔离所有依赖。
8. `SettingsView.swift:135` 的球房入口无 DEBUG 限制，声音是内联分区；`AppearanceCombinationPreview.swift:13` 用独立 SceneKit 场景，壳层/渲染分工必须明确。

主控重点回读：MainTabView/AppRouter、Settings/Profile、HistoryCalendar/TrainingDetail、DrillDetail、DrillPickerSheet 及其 Builder 调用、AppearanceCombinationPreview、BTFilterChip/BTButton/Spacing、ScreenshotTour。其它页面细项由 B01 继续穷尽核对。

## 生产入口与“存在文件”差别

- `AppTab.title` 当前显示“练习/记录”，早期规格仍有“角度/历史”用语；清单按现行代码记入口名。
- PlanList 除路由注册外有 TrainingHelp 的实际入口，首页自身也承载计划货架；不能沿用早期首页结构直接推断按钮。
- TheoryIndex 已注册，但初扫未发现生产入口触发；理区直接展示 12 篇文章卡。暂列待核，不能自动当成必达页面。
- PhoneLogin 保留 RootView 的测试启动参数入口，当前 Login 不引用；内部工作室依模拟器条件、设置开发者区依 DEBUG+模拟器条件。
- 分享微信按钮仍有未实现闭包，设置导出为“即将推出”占位。UI 盘点记录实际能力，不能靠重设计承诺新功能。
- 用户后续澄清“设置页没用最新”的反馈来自另一会话；这里不记为本案缺陷，不生成对应返工项。版本核验仍作为正常流程保留。

## 基线与资源审查

- 源码指纹记录：[source-baseline.json](../../../output/app-interface-redesign/B00/source-baseline.json)。686 个 Swift/配置文件；HEAD 和实际 dirty 状态另存，不能用 HEAD 取代工作区。
- 当时 dirty 包含 BTShotPageChrome、BTShotInstrumentColumn、HUDStyle、相机/每日页及测试、多个进度文件。当前每日真源已到 C56，历史记忆中的 B1/B2 暂停不适用。
- `tmp/feel-middle-build-snapshot-20261003` 有符号链接循环警告；禁止把 tmp 当整体基线复制。未删除或修复别的任务文件。
- Figma 桌面只允许单操作员。构建默认排队；真正并发必须隔离树、DerivedData、设备 UDID 与所有输出目录。
- `ScreenshotTourUITests.swift:8` 明确缺失跳过；`:55–79` 兼容全局 `/tmp` 路径。测试绿不等于覆盖全页面，未隔离前不得多任务抢写这些路径。

## 已纳入方案的审查结论

公共批串行、页面批最多三个并行、逐批集成、独立证据审读；全部产物按 A-ID/manifest 登记；CURRENT 单一恢复；源码/设计/运行/用户确认分层。子智能体建议用极少文件，但本工作包按用户“很多页面和文档均需记录”的目标保留独立页面、成果和决定台账，职责互不重复。

正式页面盘点、真实截图与具体 Figma 版本核验尚未执行。上述源码报告不替代 B01/B02，也不构成正式 Phase 完成。
