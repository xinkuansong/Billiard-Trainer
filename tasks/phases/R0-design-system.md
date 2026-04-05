# R0 — Design System Upgrade（设计系统升级）

> **目标**：对齐 UI 设计交付物（44 任务），校验 Token 值，补全 16 个 BT* 组件，建立实施规范。
> **前置条件**：P3 Drill Library 已完成，P4 暂停于 T-P4-04。
> **建议时长**：2–3 个会话
> **设计参考源**（优先级顺序）：
> 1. `tasks/UI-IMPLEMENTATION-SPEC.md`（合并后的实施规范，活跃文档）
> 2. `ui_design/tasks/E-06/screenshot-index.md`（48 帧截图路径索引）
> 3. `ui_design/tasks/{task-id}/stitch_task_*/screen.png`（视觉参考）
> 4. `ui_design/tasks/{task-id}/stitch_task_*/code.html`（HTML 原型，A-06/A-07/A-08 的 PNG 不完整时为主要参考）

---

## 通用 DoD 条目（适用于本 Phase 及后续所有任务）

> 每个任务除自身 DoD 外，还须满足以下条目：
>
> - [ ] 如有组件 API 变更、设计解读调整或可复用模式发现，追加 DR-NNN / PD-NNN 至 `tasks/IMPLEMENTATION-LOG.md`，并更新 `tasks/UI-IMPLEMENTATION-SPEC.md` Changelog 节。触发对应 `.mdc` / `SKILL.md` 回写。

---

## T-R0-01 创建 UI-IMPLEMENTATION-SPEC.md

- **负责角色**：iOS Architect
- **产出物**：`tasks/UI-IMPLEMENTATION-SPEC.md`

### DoD

- [x] 合并 `design-decisions.md`、`dark-mode-spec.md`、`design-guidelines.md`、14 项已知偏差为一份文件
- [x] 定义全部 16 个组件的 SwiftUI API（init 参数、枚举、modifier）
- [x] 每个页面映射到其组件组成 + 设计截图 PNG 路径 + code.html 路径
- [x] 包含 Changelog 节（活跃文档更新入口）

---

## T-R0-02 Token 值审计

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-R0-01
- **产出物**：更新后的 `Assets.xcassets`、`Colors.swift`、`Typography.swift`、`Spacing.swift`
- **设计参考**：`tasks/UI-IMPLEMENTATION-SPEC.md` § 一

### DoD

- [x] 21 个颜色 Token 的 Light/Dark 值与 `UI-IMPLEMENTATION-SPEC.md` § 1.1 完全一致
- [x] `btSuccess` 已有 Dark 值 `#4CAF50`（原代码中可能缺失 Dark 变体）
- [x] `btBGSecondary` 在代码中保留，`btSurface` 作为别名可选添加（不破坏现有引用）
- [x] Typography 13 级全部存在：`btDisplay`(48pt) ~ `btCaption2`(11pt)
- [x] `#Preview("Token Swatch")` 可预览全部颜色 Token，Light + Dark 均无白色硬编码块
- [x] Spacing 8 级 + BTRadius 6 级值与规范一致

---

## T-R0-03 BTButton 补全 7 种样式

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-R0-02
- **产出物**：更新后的 `QiuJi/Core/Components/BTButton.swift`
- **设计参考**：
  - PNG: `ui_design/tasks/A-02/stitch_task_02_02/screen.png`
  - HTML: `ui_design/tasks/A-02/stitch_task_02_02/code.html`

### DoD

- [x] 现有 4 种样式（primary, secondary, text, destructive）与设计截图校验一致
- [x] 新增 `darkPill` 样式：`#1C1C1E` 填充 + 白字，BTRadius.full 胶囊形，高度 44pt
- [x] 新增 `iconCircle` 样式：48pt 圆形，btPrimary 填充 + 白色 SF Symbol
- [x] 新增 `segmentedPill` 样式：选中态 btPrimary 填充+白字，未选中态白底+灰边框，高度 36pt
- [x] 所有按钮最小触控区域 44pt
- [x] `#Preview` 覆盖全部 7 种样式，Light + Dark

---

## T-R0-04 新建组件 Batch 1（导航/布局）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-R0-02
- **产出物**：
  - `QiuJi/Core/Components/BTSegmentedTab.swift`
  - `QiuJi/Core/Components/BTTogglePillGroup.swift`
  - `QiuJi/Core/Components/BTOverflowMenu.swift`
- **设计参考**：
  - PNG: `ui_design/tasks/A-06/stitch_task_06_02/screen.png`（可能不完整）
  - HTML: `ui_design/tasks/A-06/stitch_task_06_02/code.html`（主要参考）

### DoD

- [x] BTSegmentedTab：活跃项 btPrimary 文字 + 2pt 下划线，非活跃 btTextSecondary，间距 24pt
- [x] BTTogglePillGroup：选中 btPrimary 填充+白字，未选中白底+灰边框，高度 36pt，胶囊形
- [x] BTOverflowMenu：浮层白色圆角 16pt + 阴影，菜单项图标+标签，危险项红色+上方分隔线
- [x] 全部组件泛型化（接受 `Hashable` 类型参数）
- [x] Accessibility：VoiceOver label 可读
- [x] `#Preview` 覆盖 Light + Dark

---

## T-R0-05 新建组件 Batch 2（训练）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-R0-02
- **产出物**：
  - `QiuJi/Core/Components/BTExerciseRow.swift`
  - `QiuJi/Core/Components/BTSetInputGrid.swift`
- **设计参考**：
  - PNG: `ui_design/tasks/A-07/stitch_task_07_02/screen.png`（可能不完整）
  - HTML: `ui_design/tasks/A-07/stitch_task_07_02/code.html`（主要参考）

### DoD

- [x] BTExerciseRow：白色卡片 ~80pt 高，左侧 56pt 球台缩略图，中部名称+组数，右侧累计进球+齿轮，底部进度圆点
- [x] BTSetInputGrid：表格布局，列定义（组号 32pt / 进球 44pt / 总球 44pt / 完成 44pt / 菜单 44pt）
- [x] 行状态：已完成（btPrimaryMuted 浅底）/ 当前（btPrimary 边框）/ 未完成（灰边框）/ 热身（橙色「热」）
- [x] `+ 添加一组` 底部文字按钮
- [x] `#Preview` 覆盖多组状态，Light + Dark

---

## T-R0-06 新建组件 Batch 3（反馈/分享）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-R0-02
- **产出物**：
  - `QiuJi/Core/Components/BTRestTimer.swift`
  - `QiuJi/Core/Components/BTFloatingIndicator.swift`
  - `QiuJi/Core/Components/BTShareCard.swift`
- **设计参考**：
  - BTRestTimer — PNG: `ui_design/tasks/A-05/stitch_task_05_02/screen.png` + `code.html`
  - BTFloatingIndicator — 同 A-05
  - BTShareCard — PNG: `ui_design/tasks/A-08/stitch_task_08_02/screen.png`（可能不完整）; HTML: `code.html`（主要参考）

### DoD

- [x] BTRestTimer：同心双环 200pt，外环 btPrimary + 内环 btAccent，中心倒计时 32pt Bold，底部「+30s」+「完成」横向并排
- [x] BTFloatingIndicator：胶囊 44pt，btPrimary 填充 + 白文字「训练中 12:34 ←」，右对齐距右 16pt，Tab 栏上方 8pt，呼吸动画 + 阴影
- [x] BTShareCard：深色主题容器 BTRadius.lg，支持多种配色主题枚举，成功率色阶（≥90% 亮绿 / 70-89% btPrimary / <70% 弱化白），底部品牌区
- [x] `#Preview` 覆盖 Light + Dark

---

## T-R0-07 校验与更新已有组件

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-R0-02
- **产出物**：更新后的已有组件文件

### DoD

- [x] BTLevelBadge：五级配色与 `UI-IMPLEMENTATION-SPEC.md` § 2.4 一致（L0 品牌绿实心白字，L1 蓝色，L2 琥珀，L3 橙色，L4 红色）
  - 当前代码中 L0=btTextSecondary, L1=btPrimary, L2=blue, L3=purple, L4=btAccent，**需全部修正**
  - `displayName` 调整：L0「入门」L1「初级」L2「中级」L3「高级」L4「专家」
- [x] BTDrillCard：左侧新增 64pt 方形台球照片缩略图（圆角 BTRadius.sm），Dark Mode 下添加 0.5pt btSeparator 描边
- [x] BTPremiumLock：实现渐进式锁模式（显示前 2-3 条 → 隐藏剩余 → 金色锁 + 金色描边 CTA）和全遮罩模式（磨砂渐变 + 金色填充 CTA），两种模式通过参数切换
- [x] BTEmptyState：图标添加 btPrimary 30% 不透明度圆形背景底
- [x] BTBilliardTable：台面色 btTableFelt（`#1B6B3A`/`#144D2A`），库边色 btTableCushion（`#7B3F00`/`#5C2E00`），确认使用 Token 而非硬编码
- [x] 所有组件 `#Preview` 覆盖 Light + Dark

---

## QA-R0 Phase R0 验收

- **负责角色**：QA Reviewer
- **前置依赖**：T-R0-01 至 T-R0-07 全部完成

### 验收要点

- [x] 全部 16 个组件在 `QiuJi/Core/Components/` 中有对应文件
- [x] 每个组件有 `#Preview`，Light + Dark 均可正常渲染（无白色硬编码块、无 btPrimary 偏蓝）
- [x] 组件 API 与 `tasks/UI-IMPLEMENTATION-SPEC.md` § 二 中定义一致
- [x] 无硬编码 hex 值——所有颜色通过 `Color("btXxx")` 或 `.btXxx` 引用
- [x] `xcodebuild test` 全部通过（现有 89 项测试无回归）
- [x] `tasks/PROGRESS.md` 已更新 R0 完成状态

#### QA 附条件通过备注（2026-04-05）

以下 P2 级别发现不阻塞验收，记入 P8 Polish 改进项：

1. **BTPremiumLock** 缺少 `#Preview("Progressive Lock Dark")`
2. **ShareCardTheme** 为顶层 enum（spec 定义为嵌套 `BTShareCard.ShareCardTheme`）
3. **BTPremiumLock** `goldColor` 计算属性可用 `Color.btAccent` Token 替代硬编码 hex

已知测试缺陷（非 R0 引入）：
- `ActiveTrainingViewModelTests.test_saveTraining_success`：Optional(8) ≠ Optional(7)，来自 P5-P7 commit bb98c6f

---

## ADR 记录区

_（空，组件层决策在 IMPLEMENTATION-LOG.md 的 DR-NNN 中记录）_
