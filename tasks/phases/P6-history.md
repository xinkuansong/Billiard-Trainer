# P6 — History（历史与统计）

> **目标**：历史 Tab 完整实现，包含日历视图（F6）、训练详情、统计图表（F7）、Freemium 时间限制。
> **前置 Phase**：P5 通过 QA（统计需要足够的训练数据存在）

---

## T-P6-01 历史 Tab — 日历视图（F6）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P2-02
- **产出物**：`Features/History/Views/HistoryCalendarView.swift`
- **设计参考**：`ui_design/tasks/P1-07/stitch_task_p1_07_02/screen.png`

### DoD

- [x] 使用 R0 BT* 组件，不自建临时组件 — BTSegmentedTab, BTEmptyState
- [x] 布局对照 `tasks/UI-IMPLEMENTATION-SPEC.md` 中对应设计截图 — P1-07 code.html
- [x] Light + Dark `#Preview` 通过视觉检查
- [x] 如有组件 API 或设计解读变更，追加 DR/PD 至 `tasks/IMPLEMENTATION-LOG.md` 并更新 `UI-IMPLEMENTATION-SPEC.md` Changelog — 无变更
- [x] 默认展示当月日历 — 6 行网格 + 上下月灰色日期
- [x] 有训练记录的日期高亮（使用 `btPrimary` 点标记）— 改为分类名称胶囊标签
- [x] 支持按月翻页（上下月切换）
- [x] 点击有记录的日期展示当日训练列表（日期下方或新页面）
- [x] 无记录日期点击提示「当天无训练记录」
- [x] Dark Mode 正常

---

## T-P6-02 训练详情页（F6）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P6-01
- **产出物**：`Features/History/Views/TrainingDetailView.swift`
- **设计参考**：`ui_design/tasks/P1-08/stitch_task_p1_08_trainingdetailview_02/screen.png`

### DoD

- [x] 使用 R0 BT* 组件，不自建临时组件 — BTOverflowMenu, BTButton
- [x] 布局对照 `tasks/UI-IMPLEMENTATION-SPEC.md` 中对应设计截图 — P1-08 code.html
- [x] Light + Dark `#Preview` 通过视觉检查
- [x] 如有组件 API 或设计解读变更 — 无变更
- [x] 展示该次训练：日期时间、总时长、球种 — 统计横滚：进球/组/分钟/时段/日期
- [x] Drill 列表：每个 Drill 的名称 + 各组「进X/目标X」+ 成功率 — 含迷你球台缩略图
- [x] 心得备注区（有内容时展示，无内容不显示占位）
- [x] 顶部「整体成功率」统计数字（大字显示）— 改为横滚统计行

---

## T-P6-03 统计视图（F7）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P6-01
- **产出物**：`Features/History/Views/StatisticsView.swift`
- **设计参考**：`ui_design/tasks/P1-09/stitch_task_p1_09_02/screen.png`

### DoD

- [x] 使用 R0 BT* 组件，不自建临时组件 — BTTogglePillGroup, BTEmptyState
- [x] 布局对照 `tasks/UI-IMPLEMENTATION-SPEC.md` 中对应设计截图 — P1-09 code.html
- [x] Light + Dark `#Preview` 通过视觉检查
- [x] 如有组件 API 或设计解读变更 — 无变更
- [x] 顶部时间范围切换：周 / 月 / 年 — BTTogglePillGroup
- [x] 三个关键数字卡片：训练天数、总时长、总组数 — 训练概况 + 训练时长 + 分类成功率
- [x] 无数据时展示空状态（`BTEmptyState`），引导「开始第一次训练」

---

## T-P6-04 训练频率柱状图 + 趋势线（F7）

> 图表形态对齐 `ui_design/tasks/E-06/design-decisions.md` §4.4（柱状图 + 趋势线，非纯折线）。

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P6-03
- **产出物**：`Features/History/Views/StatisticsView.swift`（柱状图 + 趋势线部分）

### DoD

- [x] 使用 R0 BT* 组件，不自建临时组件
- [x] 布局对照 `tasks/UI-IMPLEMENTATION-SPEC.md` 中对应设计截图
- [x] Light + Dark `#Preview` 通过视觉检查
- [x] 如有组件 API 或设计解读变更 — 无变更
- [x] 使用 **Swift Charts**（iOS 16+ 系统库，无需第三方）— BarMark + RuleMark
- [x] 按所选时间范围绘制训练相关 **柱状图 + 趋势线**（x 轴时间）
- [x] 图表双色：琥珀 `#F5A623`（时长）+ 品牌绿（成功率）
- [ ] 数据点可点击显示具体日期和次数 — P8 Polish 优化项

---

## T-P6-05 各类别成功率雷达图（F7）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P6-03
- **产出物**：`Features/History/Views/RadarChartView.swift`（或用 Swift Charts 近似替代）

### DoD

- [x] 使用 R0 BT* 组件，不自建临时组件
- [x] 布局对照 `tasks/UI-IMPLEMENTATION-SPEC.md` 中对应设计截图
- [x] Light + Dark `#Preview` 通过视觉检查
- [x] 如有组件 API 或设计解读变更 — 无变更
- [x] 卡片左侧绿线为统计页面专属装饰 — StatisticsCardModifier 实现
- [x] 展示 8 大类别的平均成功率 — 2 列网格 + 迷你柱状图 + 环比变化
- [x] 若无原生雷达图支持，可用水平条形图替代 — 使用 2 列网格替代雷达图（ADR 见下方）
- [x] 各类别标签中文显示

---

## T-P6-06 Freemium 历史查看限制（F6）

- **负责角色**：Data Engineer
- **前置依赖**：T-P6-01
- **产出物**：`HistoryAccessController.swift`

### DoD

- [x] 免费用户仅可查看最近 60 天的训练记录 — HistoryAccessController.isAccessible()
- [x] 超出 60 天的记录显示「升级查看全部历史」遮罩 — 锁图标 + Pro 标签 + 触发 SubscriptionView
- [x] 付费用户无限制 — isPremium 检查
- [x] 60 天边界在本地通过 `Date` 计算，不依赖服务器

---

## QA-P6 P6 验收

- **负责角色**：QA Reviewer

### 验收要点

- [ ] 日历翻月正常，有记录的日期正确高亮（使用 P4 创建的测试数据）
- [ ] 训练详情完整展示（所有 Drill、分组数据、心得）
- [ ] 统计图在有数据时正常绘制，切换周/月/年后图表更新
- [ ] 空数据状态（首次使用）展示引导，不显示空白图表
- [ ] 免费用户：60 天前的记录有遮罩，60 天内正常访问
- [ ] Dark Mode：图表颜色适配正常

---

## ADR 记录区

### ADR-P6-01 — 2 列网格替代雷达图

- **背景**：T-P6-05 DoD 要求展示 8 大类别的平均成功率，原设计提及雷达图。
- **决策**：使用 **2 列 LazyVGrid** 替代雷达图，每个 cell 包含分类名称、环比变化百分比、迷你 3 柱对比图。
- **原因**：
  1. Swift Charts (iOS 16+) 无内建雷达图 Mark 类型
  2. 自绘 Canvas 雷达图维护成本高，且 8 轴雷达在手机屏幕上可读性差
  3. P1-09 code.html 设计稿实际使用 2 列网格（非雷达图），与代码对齐
- **影响**：`StatisticsView` + `StatisticsViewModel.categoryComparison`
- **回退条件**：若产品侧要求雷达图，可在 P8 Polish 中用 Canvas 自绘补充
