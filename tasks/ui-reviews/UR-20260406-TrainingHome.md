## UI 审查报告 — TrainingHomeView（Light + Dark）
日期：2026-04-06
任务：T-R1-01

**审查对象**：`QiuJi/Features/Training/Views/TrainingHomeView.swift`
**设计参考**：P0-01（有计划态）、P0-02（空状态）、E-01（Dark Mode）、ref-screenshots/01-training-home/
**规范参考**：`tasks/UI-IMPLEMENTATION-SPEC.md` § 四 Tab 1、§ 六 Dark Mode 全局规则、§ 七 训练流程决策

---

### U-01 缺少「即将到来」Section
- **类别**：产品规格
- **严重程度**：P1（应该修复）
- **位置**：训练 Tab > TrainingHomeView > 今日安排下方
- **现状**：代码仅实现了 `todayScheduleSection`（今日安排），无「即将到来」区块。ViewModel (`TrainingHomeViewModel`) 也无对应的 upcoming session 数据模型。
- **预期**：P0-01 设计稿明确展示「即将到来」Section，包含：① 区块标题"即将到来"（17px bold）；② 卡片显示下一训练日的 Drill 名 + PRO 徽章 + 禁用态 GO! 按钮（opacity 50%）+ 下一训练日提示文字。E-01 Dark 还增加了金色进度条（btAccent #F0AD30）。
- **修复方向**：① ViewModel 新增 `upcomingSession: UpcomingSessionInfo?` 数据源；② View 新增 `upcomingSection` 渲染区块，卡片样式与 todayDrillCard 一致但 GO! 按钮为 disabled + opacity(0.5)；③ PRO 计划显示金色 PRO 徽章（btAccent 12%底 + btAccent 字）。
- **涉及文件**：`TrainingHomeView.swift`、`TrainingHomeViewModel.swift`

### U-02 计划浏览卡片 Dark Mode 缺少卡片背景
- **类别**：Dark Mode
- **严重程度**：P1（应该修复）
- **位置**：训练 Tab > TrainingHomeView > 官方计划 / 自定义模版列表
- **现状**：`planBrowseCard` 和 `customPlanCard` 均无 `.background()` 设置。Light Mode 下设计即为透明背景（`bg-transparent`），表现正确。但 Dark Mode 下，卡片内容直接渲染在纯黑背景上，缺少 `btBGSecondary`（#1C1C1E）卡片容器。
- **预期**：E-01 code.html 明确为每张计划卡片设置 `bg-[#1C1C1E] rounded-[16pt] p-4`。即 Dark 模式下应有 btBGSecondary 背景 + BTRadius.lg 圆角 + Spacing.lg 内边距。UI-IMPLEMENTATION-SPEC § 6.2 也要求 Dark 下卡片背景为 `#1C1C1E`。
- **修复方向**：为 `planBrowseCard` 和 `customPlanCard` 添加条件化卡片容器：
  ```swift
  .padding(colorScheme == .dark ? Spacing.lg : Spacing.sm)
  .background(colorScheme == .dark ? Color.btBGSecondary : .clear)
  .clipShape(RoundedRectangle(cornerRadius: colorScheme == .dark ? BTRadius.lg : 0))
  ```
- **涉及文件**：`TrainingHomeView.swift`

### U-03 筛选 Chip 触摸目标 < 44pt
- **类别**：HIG
- **严重程度**：P1（应该修复）
- **位置**：训练 Tab > TrainingHomeView > filterChips 区域
- **现状**：`filterChipButton` 的可点击区域高度约为 8pt（top）+ 14pt（text）+ 8pt（bottom）= ~30pt，低于 HIG 要求的 44pt 最小触摸目标。
- **预期**：Apple HIG 要求所有可点击元素触摸目标 >= 44pt。设计稿（P0-01 `py-1.5`）本身也偏小，但实现时应通过 `.frame(minHeight: 44)` 或 `.contentShape(Rectangle())` 扩大点击区域以满足 HIG。
- **修复方向**：在 Chip Button label 外层添加 `.frame(minHeight: 44)` 或对整个 Button 添加 `.contentShape(Rectangle().size(width: ..., height: 44))`，保持视觉尺寸不变但扩大点击热区。
- **涉及文件**：`TrainingHomeView.swift`

### U-04 Chip 选中态使用硬编码 Color() 而非 Token
- **类别**：Design Token
- **严重程度**：P2（建议改进）
- **位置**：训练 Tab > TrainingHomeView > chipBackground / chipTextColor
- **现状**：`chipBackground` 中选中态颜色使用 `Color(red: 0x1C/255.0, green: 0x1C/255.0, blue: 0x1E/255.0)` 和 `Color(red: 0xF2/255.0, green: 0xF2/255.0, blue: 0xF7/255.0)`，为硬编码 RGB 值。
- **预期**：虽然这些值（`#1C1C1E` Light 选中、`#F2F2F7` Dark 选中）是规范指定的 Chip 专用色，与现有 Token 不完全对应（§ 七 明确要求「非品牌绿」），但仍建议提取为命名常量（如 `Color.btChipSelectedFill`）以提升可维护性。
- **修复方向**：在 Colors.swift 中新增 Chip 专用 Token（可作为代码常量，不必入 Asset Catalog），或在 TrainingHomeView 内提取为 `private static let chipActiveFill` 常量。
- **涉及文件**：`TrainingHomeView.swift`（或 `Colors.swift`）

### U-05 Chip 未选中 Light 背景使用硬编码 `.white`
- **类别**：Design Token
- **严重程度**：P2（建议改进）
- **位置**：训练 Tab > TrainingHomeView > chipBackground(false) Light 分支
- **现状**：`chipBackground` 在 `!isSelected && !dark` 时返回 `.white`，这是一个硬编码系统颜色。
- **预期**：应使用 `Color.btBGSecondary`（Light = #FFFFFF）。虽然视觉效果相同，但 `.white` 不会响应 Token 定义变更。P0-01 设计 `bg-white` 语义等价于 `btBGSecondary` Light 值。
- **修复方向**：将 `.white` 替换为 `Color.btBGSecondary`。
- **涉及文件**：`TrainingHomeView.swift`

### U-06 空状态「自由记录」按钮样式偏差
- **类别**：视觉打磨 / 产品规格
- **严重程度**：P2（建议改进）
- **位置**：训练 Tab > TrainingHomeView > emptyStateContent > 自由记录按钮
- **现状**：代码使用 `btPrimary` 绿色 + `.underline()` 装饰：
  ```swift
  .font(.btCallout.weight(.medium))  // 16pt Medium
  .foregroundStyle(.btPrimary)        // 品牌绿
  .underline()
  ```
- **预期**：P0-02 code.html 显示为：`text-on-background font-medium text-[17px]`，即 17px Medium、深色文字（btText）、无下划线。设计意图是「自由记录」为低层级纯文字按钮，视觉上弱于主 CTA。
- **修复方向**：① 字体改为 `.btBody`（17pt Regular）或 `.btHeadline`；② 颜色改为 `.btText`；③ 移除 `.underline()`。或改用 `BTButtonStyle.text` 但需确认 text 样式颜色是否应改为 btText。
- **涉及文件**：`TrainingHomeView.swift`

### U-07 BTSegmentedTab 下方缺少分隔线
- **类别**：布局
- **严重程度**：P2（建议改进）
- **位置**：训练 Tab > TrainingHomeView > planBrowsingSection > BTSegmentedTab 底部
- **现状**：`planBrowsingSection` 中 BTSegmentedTab 下方无底部分隔线，Tab 内容区域直接紧邻。
- **预期**：P0-01 code.html 第 159 行：`<div class="... border-b border-surface-container ...">` 显示 Tab 底部有一条分隔线。E-01 code.html 第 163 行：`border-b border-[#38383A]` 同样有 btSeparator 底线。BTSegmentedTab 组件自身仅渲染活跃项下划线，不含全宽分隔线。
- **修复方向**：在 `planBrowsingSection` 的 BTSegmentedTab 下方添加：
  ```swift
  Divider().foregroundStyle(.btSeparator)
  ```
  或在 BTSegmentedTab 组件内部添加全宽底部分隔线。
- **涉及文件**：`TrainingHomeView.swift`（或 `BTSegmentedTab.swift`）

### U-08 计划卡片缩略图为渐变占位符而非真实图片
- **类别**：产品规格
- **严重程度**：P2（建议改进）
- **位置**：训练 Tab > TrainingHomeView > planBrowseCard / customPlanCard 缩略图
- **现状**：`planBrowseCard` 使用 `RoundedRectangle + LinearGradient + SF Symbol 图标` 作为 80×80 缩略图占位；`customPlanCard` 使用 `btAccent.opacity(0.12) + hammer.fill 图标`。
- **预期**：P0-01 设计稿显示 80×80 圆角台球场景真实照片（billiard table/cue images）。E-01 Dark 版也显示带 opacity 调整的真实图片。
- **修复方向**：① 为每个官方计划准备缩略图资源（Asset Catalog 或远程 URL）；② PlanBrowseItem 新增 `thumbnailName: String?`；③ 渲染时优先使用 AsyncImage 或本地 Image，fallback 至当前渐变占位符。自定义计划可保留图标占位。
- **涉及文件**：`TrainingHomeView.swift`、`TrainingHomeViewModel.swift`、Asset Catalog

### U-09 Dark Mode 工具栏图标颜色未适配
- **类别**：Dark Mode
- **严重程度**：P2（建议改进）
- **位置**：训练 Tab > TrainingHomeView > 导航栏右侧 toolbar 图标
- **现状**：工具栏中 `person.2` 和 `ellipsis` 图标均使用 `.foregroundStyle(.btText)`，在 Dark Mode 下为纯白 (#FFFFFF)。
- **预期**：E-01 code.html 第 112 行：`text-[rgba(235,235,240,0.6)]` 即 btTextSecondary，Dark 下图标应更柔和（60% 不透明度白色），避免过于刺眼。Light 下 btText（#000000）正确。
- **修复方向**：将 `.foregroundStyle(.btText)` 改为 `.foregroundStyle(.btTextSecondary)` 或使用条件化：Light 用 btText、Dark 用 btTextSecondary。考虑到 Light 下 btTextSecondary 也偏灰，更好的方案可能是保持 btText 并接受 Dark 下的差异，或在系统 toolbar 中不强制指定颜色。
- **涉及文件**：`TrainingHomeView.swift`

### U-10 「GO!」按钮视觉高度偏小
- **类别**：HIG
- **严重程度**：P2（建议改进）
- **位置**：训练 Tab > TrainingHomeView > todayDrillCard > GO! 按钮
- **现状**：GO! 按钮的可见高度约为 8pt + 14pt + 8pt ≈ 30pt（vertical padding + text height），低于 44pt HIG 最小触摸目标。
- **预期**：HIG 要求可点击元素 >= 44pt。设计稿（P0-01 `py-2`）本身也为紧凑尺寸，但由于该按钮是卡片内的主要交互入口，建议增大触摸区域。
- **修复方向**：保持视觉尺寸，通过 `.contentShape(Rectangle())` 或 `.frame(minHeight: 44)` 扩展点击热区。按钮已在 padding(Spacing.lg) 的 HStack 内，父容器高度足够。
- **涉及文件**：`TrainingHomeView.swift`

---

### 审查总结
- **截图参考**：P0-01（Light 有计划态）、P0-02（Light 空状态）、E-01（Dark Mode）、ref-screenshots × 4 张
- **问题数量**：10 项（P0: 0 / P1: 3 / P2: 7）
- **总体评价**：TrainingHomeView 整体结构与设计稿高度一致，颜色 Token 使用规范，Dark Mode 阴影条件化、Chip 选中态均已正确实现。主要缺口为「即将到来」Section 未实现（P1）、Dark 下计划卡片缺少容器背景（P1）以及部分触摸目标偏小（P1）。7 项 P2 问题多为 Token 纯度、组件分隔线、占位图等打磨项。
- **建议优先级**：U-01（即将到来）→ U-02（Dark 卡片背景）→ U-03（触摸目标）→ 其余 P2 项可与后续 UI 打磨批次合并处理。

### 维度通过情况

| # | 维度 | 结果 | 说明 |
|---|------|------|------|
| 1 | Design Token | ⚠️ | 整体良好，Chip 有 2 处硬编码（P2） |
| 2 | 布局 | ⚠️ | 缺少「即将到来」Section（P1）；Tab 分隔线缺失（P2） |
| 3 | Dark Mode | ⚠️ | 阴影/Chip 适配正确；计划卡片背景缺失（P1）；工具栏图标色偏亮（P2） |
| 4 | 产品规格 | ⚠️ | 「即将到来」未实现（P1）；缩略图占位（P2） |
| 5 | HIG | ⚠️ | Chip 和 GO 按钮触摸目标偏小（P1+P2） |
| 6 | 无障碍 | ✅ | BTSegmentedTab 有 accessibility traits；颜色对比度充足；无色觉单一依赖 |
| 7 | 视觉打磨 | ⚠️ | 「自由记录」样式偏差（P2）；整体打磨度良好 |
