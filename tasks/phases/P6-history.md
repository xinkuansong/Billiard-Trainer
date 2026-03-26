# P6 — History（历史与统计）

> **目标**：历史 Tab 完整实现，包含日历视图（F6）、训练详情、统计图表（F7）、Freemium 时间限制。
> **前置 Phase**：P5 通过 QA（统计需要足够的训练数据存在）

---

## T-P6-01 历史 Tab — 日历视图（F6）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P2-02
- **产出物**：`Features/History/Views/HistoryCalendarView.swift`

### DoD

- [ ] 默认展示当月日历
- [ ] 有训练记录的日期高亮（使用 `btPrimary` 点标记）
- [ ] 支持按月翻页（上下月切换）
- [ ] 点击有记录的日期展示当日训练列表（日期下方或新页面）
- [ ] 无记录日期点击提示「当天无训练记录」
- [ ] Dark Mode 正常

---

## T-P6-02 训练详情页（F6）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P6-01
- **产出物**：`Features/History/Views/TrainingDetailView.swift`

### DoD

- [ ] 展示该次训练：日期时间、总时长、球种
- [ ] Drill 列表：每个 Drill 的名称 + 各组「进X/目标X」+ 成功率
- [ ] 心得备注区（有内容时展示，无内容不显示占位）
- [ ] 顶部「整体成功率」统计数字（大字显示）

---

## T-P6-03 统计视图（F7）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P6-01
- **产出物**：`Features/History/Views/StatisticsView.swift`

### DoD

- [ ] 顶部时间范围切换：周 / 月 / 年
- [ ] 三个关键数字卡片：训练天数、总时长、总组数
- [ ] 无数据时展示空状态（`BTEmptyState`），引导「开始第一次训练」

---

## T-P6-04 训练频率折线图（F7）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P6-03
- **产出物**：`Features/History/Views/StatisticsView.swift`（折线图部分）

### DoD

- [ ] 使用 **Swift Charts**（iOS 16+ 系统库，无需第三方）
- [ ] 按所选时间范围绘制训练频率折线图（x 轴时间，y 轴次数）
- [ ] 数据点可点击显示具体日期和次数

---

## T-P6-05 各类别成功率雷达图（F7）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P6-03
- **产出物**：`Features/History/Views/RadarChartView.swift`（或用 Swift Charts 近似替代）

### DoD

- [ ] 展示 8 大类别的平均成功率
- [ ] 若无原生雷达图支持，可用水平条形图（`Chart` + `BarMark`）替代，ADR 记录决策
- [ ] 各类别标签中文显示

---

## T-P6-06 Freemium 历史查看限制（F6）

- **负责角色**：Data Engineer
- **前置依赖**：T-P6-01
- **产出物**：`HistoryAccessController.swift`

### DoD

- [ ] 免费用户仅可查看最近 60 天的训练记录
- [ ] 超出 60 天的记录显示「升级查看全部历史」遮罩
- [ ] 付费用户无限制
- [ ] 60 天边界在本地通过 `Date` 计算，不依赖服务器

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
