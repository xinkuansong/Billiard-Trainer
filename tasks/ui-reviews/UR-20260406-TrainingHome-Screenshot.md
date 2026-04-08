## UI 截图审查报告 — TrainingHomeView（截图对照）
日期：2026-04-06

审查对象：训练首页（Training Tab）
截图来源：P0-01-01 ~ P0-01-04, P0-02-01（5 张实机截图）
设计参考：P0-01 code.html + screen.png, P0-02 code.html + screen.png, ref-screenshots/01-training-home

---

### S-01 滚动后导航标题与状态栏时间重叠
- **类别**：布局
- **严重程度**：P1
- **位置**：训练 > TrainingHomeView > NavigationBar（compact title 模式）
- **截图现状**：P0-01-04 截图中，页面向上滚动后，导航栏标题区域显示「训练49」——「49」来自状态栏时间「14:49」，两者发生视觉重叠，无法正常阅读标题。
- **设计预期**：滚动后 Large Title 折叠为标准 inline title，标题「训练」应独占导航栏中央区域，与状态栏时间「14:49」互不干扰。参考 P0-01 design header 区域：标题左对齐，右侧为 group + more_horiz 按钮，中间无内容。
- **修复方向**：检查 NavigationStack 的 `.navigationTitle` 与 `.navigationBarTitleDisplayMode(.large)` 配置，确保系统自动处理 Large → Inline 标题折叠。若使用自定义 header 实现，需确保 compact 状态下标题不与 status bar frame 重叠。
- **路由至**：swiftui-developer
- **代码提示**：`Features/Training/Views/TrainingHomeView.swift`，检查 NavigationStack / toolbar 配置

---

### S-02 缺少「即将到来」区域
- **类别**：产品规格
- **严重程度**：P1
- **位置**：训练 > TrainingHomeView > 今日安排与 Tab 切换器之间
- **截图现状**：P0-01-01 截图中，「今日安排」卡片列表之后直接进入「官方计划 / 自定义模版」Tab 切换器，中间没有「即将到来」区域。
- **设计预期**：P0-01 design (code.html line 142–155) 在「今日安排」与 Tab 切换器之间有一个 `mt-8` 的「即将到来」section，展示下一个训练日的预览卡片（如「走位突破 Day 3」），带 PRO 标签和灰色 GO! 按钮。
- **修复方向**：在 TrainingHomeView 的 ScrollView 中，「今日安排」section 之后、BTSegmentedTab 之前插入「即将到来」section，展示当前计划中下一个尚未到达训练日的 Drill 信息。若当前计划无「即将到来」项则隐藏该 section。
- **路由至**：swiftui-developer
- **代码提示**：`Features/Training/Views/TrainingHomeView.swift`

---

### S-03 自定义模版空状态同屏出现两个 Primary 按钮
- **类别**：HIG
- **严重程度**：P1
- **位置**：训练 > TrainingHomeView > 自定义模版 Tab（空状态）
- **截图现状**：P0-01-04 截图中，滚动后同时可见两个绿色填充按钮——空状态的「创建计划」和底部固定的「开始训练」。两个按钮视觉权重相同，均为 btPrimary 填充 + 白字。
- **设计预期**：设计系统（SKILL.md §七 BTButton）明确规定「Primary：同一视图最多 1 个」。底部「开始训练」为全局 Primary 操作。空状态的「创建计划」按钮应降级为 secondary 样式（描边），或在自定义模版空状态时隐藏底部「开始训练」。
- **修复方向**：方案 A——将空状态的「创建计划」改为 `.secondary` 样式（btPrimary 描边 + 品牌色文字）；方案 B——当自定义模版 Tab 处于空状态时，暂时隐藏底部「开始训练」按钮。推荐方案 A，保持底部按钮一致性。
- **路由至**：swiftui-developer
- **代码提示**：`Features/Training/Views/TrainingHomeView.swift`，`Core/Components/BTEmptyState.swift`

---

### S-04 缺少「综合」等级筛选 Chip
- **类别**：产品规格
- **严重程度**：P2
- **位置**：训练 > TrainingHomeView > 官方计划 > Filter Chips
- **截图现状**：P0-01-01 截图中筛选 Chip 为 5 个：「全部 / 入门 / 初级 / 中级 / 高级」。
- **设计预期**：P0-01 design (code.html line 164–171) 定义了 6 个筛选 Chip，包含末尾的「综合」选项。`docs/05` §Tab1 也列出了「综合提升」作为官方计划分类之一。
- **修复方向**：在 filter chips 数据源中增加「综合」选项，对应 `DrillLevel` 或 plan category 中的综合类型。
- **路由至**：swiftui-developer
- **代码提示**：`Features/Training/Views/TrainingHomeView.swift`，筛选 chip 数据源

---

### S-05 今日安排卡片中待完成 Drill 全部显示 GO! 按钮
- **类别**：产品规格
- **严重程度**：P2
- **位置**：训练 > TrainingHomeView > 今日安排 > Drill 卡片
- **截图现状**：P0-01-01 截图中，3 张今日 Drill 卡片的状态为：第 1 张（已完成）显示绿色对勾 ✓，第 2 张和第 3 张（待完成）均显示绿色「GO!」按钮。
- **设计预期**：P0-01 design (code.html line 122–139) 中，只有当前应执行的第 1 张卡片显示「GO!」按钮，第 2 张卡片右侧显示「⋮」more_vert 菜单图标而非 GO! 按钮，暗示该 Drill 尚未轮到。
- **修复方向**：仅为「下一个待执行」的 Drill 显示 GO! 按钮，后续 Drill 显示 BTOverflowMenu（⋮）或不显示操作按钮。逻辑：已完成 → ✓ 对勾，当前 → GO!，未到 → ⋮ 或无按钮。
- **路由至**：swiftui-developer
- **代码提示**：`Features/Training/Views/TrainingHomeView.swift`，今日安排卡片的状态逻辑

---

### S-06 等级标签显示「L1 初级」格式，设计仅显示「初级」
- **类别**：视觉打磨
- **严重程度**：P2
- **位置**：训练 > TrainingHomeView > 官方计划 > Plan Card > BTLevelBadge
- **截图现状**：P0-01-01 截图中，计划卡片的等级标签显示为「L1 初级」，包含等级代码前缀。
- **设计预期**：P0-01 design (code.html line 185, 199) 中等级标签仅显示 displayName「入门」「初级」「中级」，不带 L0/L1/L2 前缀。SKILL.md §九 BTLevelBadge 也使用 displayName：L0「入门」L1「初级」L2「中级」L3「高级」L4「专家」。
- **修复方向**：BTLevelBadge 在训练首页的计划卡片中使用 `displayName` 而非 `"L\(level.rawValue) \(displayName)"` 格式。注意 DrillListView 中可能需要保留完整格式，按场景区分。
- **路由至**：swiftui-developer
- **代码提示**：`Core/Components/BTLevelBadge.swift`，`Features/Training/Views/TrainingHomeView.swift`

---

### S-07 今日安排卡片副标题单位不一致（「组」vs 设计的「练」）
- **类别**：产品规格
- **严重程度**：P2
- **位置**：训练 > TrainingHomeView > 今日安排 > Drill 卡片副标题
- **截图现状**：P0-01-01 截图中，今日安排卡片副标题格式为「新手入门计划 · 2 组」「新手入门计划 · 3 组」，单位为「组」（sets）。
- **设计预期**：P0-01 design (code.html line 126, 134) 中副标题格式为「新手入门计划 · 3 练」「新手入门计划 · 5 练」，单位为「练」（exercises/drills）。
- **修复方向**：确认产品意图——「组」表示该 Drill 包含的训练组数，「练」表示训练次数。两者语义不同。若与设计对齐，应改为「N 练」；若「组」是更准确的业务表达则保留，但需同步更新设计。建议与产品确认。
- **路由至**：swiftui-developer
- **代码提示**：`Features/Training/Views/TrainingHomeView.swift`，今日安排卡片副标题 formatter

---

### S-08 计划卡片缩略图为相同占位图标，缺乏区分度
- **类别**：视觉打磨
- **严重程度**：P2
- **位置**：训练 > TrainingHomeView > 官方计划 > Plan Card > Thumbnail
- **截图现状**：P0-01-01 截图中，「新手入门计划」和「基础杆法专项」两张计划卡片的 80×80 缩略图均显示相同的深绿色背景 + 白色山水/波浪线图标，视觉上无法区分不同计划。
- **设计预期**：P0-01 design (code.html line 176–206) 中每张计划卡片有独立的真实台球场景照片作为缩略图（台球桌特写、球组排列、球手出杆等），具有明确的视觉差异和内容暗示。参考 ref-screenshots 中训记 App 的计划列表也使用差异化真实照片。
- **修复方向**：为每个官方计划准备独立的缩略图素材（台球场景照片或插画），存入 Assets.xcassets。短期可使用不同颜色/图标的 placeholder 做临时区分。长期需要美术资源。
- **路由至**：content-engineer
- **代码提示**：`Features/Training/Views/TrainingHomeView.swift`，Plan 数据模型的 `thumbnailImage` 字段

---

### S-09 底部「开始训练」按钮与列表末项重叠
- **类别**：布局
- **严重程度**：P2
- **位置**：训练 > TrainingHomeView > 底部固定按钮区域
- **截图现状**：P0-01-01 截图中，列表末尾的「基础杆法专项」计划卡片的下半部分被底部固定的「开始训练」绿色按钮遮挡，用户需要向上滚动才能完整看到最后一张卡片。
- **设计预期**：P0-01 design (code.html line 117) 使用 `pb-44`（176pt）底部内边距为固定按钮预留空间。实际截图中 padding 不足，导致内容被遮挡。
- **修复方向**：增加 ScrollView 的 `.contentInset` 或底部 padding，确保列表内容在完全滚动到底时不被「开始训练」按钮和 Tab Bar 遮挡。建议底部安全区 padding >= 按钮高度 (52pt) + 按钮上下间距 (16pt×2) + Tab Bar 高度 (约 83pt) ≈ 167pt。
- **路由至**：swiftui-developer
- **代码提示**：`Features/Training/Views/TrainingHomeView.swift`，ScrollView 的 bottom padding / safeAreaInset

---

### 审查总结
- 截图审查范围：5 张实机截图 + 2 张设计 screen.png + 2 份 code.html + 4 张布局参考截图
- 发现问题：9 项（P0: 0 / P1: 3 / P2: 6）
- 总体评价：训练首页的整体结构与设计高度一致——导航标题、今日安排卡片、Tab 切换器、筛选 Chip、计划列表、空状态均已实现且布局正确。3 个 P1 问题中，S-01（缺少「即将到来」section）为产品功能缺失，S-02（标题重叠）为明确的布局 bug，S-03（双 Primary 按钮）违反设计系统约束。P2 问题多为细节打磨项（筛选 Chip 数量、标签格式、缩略图差异化等），不影响核心功能使用。
- 建议下一步：
  1. **优先修复 S-02**（导航标题重叠 bug），这是最明显的视觉缺陷
  2. **修复 S-03**（双 Primary 按钮），将空状态按钮降级为 secondary
  3. **评估 S-01**（即将到来 section）是否在当前 Phase 范围内，若是则实现
  4. P2 问题可批量处理：S-04 + S-05 + S-06 + S-07 为逻辑/文案调整，S-08 + S-09 为视觉/布局调整
