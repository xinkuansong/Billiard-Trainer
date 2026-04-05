# UI 审查报告 — TrainingSummaryView + TrainingShareView + BTShareCard + TrainingNoteView

日期：2026-04-06
任务：T-R1-03
审查模式：代码对照设计稿（无真机截图）
审查范围：Light + Dark Mode

---

## P1 问题（功能缺陷）

### U-01 「隐藏球台图」toggle 缺失

- **类别**：产品规格
- **严重程度**：P1
- **位置**：训练 > 分享训练 > 定制面板 > 选项区
- **现状**：`TrainingShareView` 声明了 `@State private var hideBallTable = false`（第 12 行），但 `optionToggles` 视图（第 153–163 行）仅包含「隐藏备注」和「隐藏成功率」两个 pill，「隐藏球台图」未渲染到 UI 中。
- **预期**：设计稿 `P0-06 code.html` 第 221 行明确包含第三个 toggle `隐藏球台图`；`screen.png` 同样可见三个选项按钮。
- **修复方向**：在 `optionToggles` 中补回第三个 `togglePill("隐藏球台图", isActive: $hideBallTable)`，并在 BTShareCard 中增加 `hideBallTable` 参数控制球台缩略图显示。
- **路由至**：swiftui-developer
- **代码提示**：`TrainingShareView.swift:153–163`、`BTShareCard.swift`

### U-02 「隐藏备注」toggle 未接入 BTShareCard

- **类别**：产品规格
- **严重程度**：P1
- **位置**：训练 > 分享训练 > 定制面板 > 选项 > 「隐藏备注」
- **现状**：`hideNote` state 存在且 UI 中可点击，但 `BTShareCard` 的 init 未暴露 `hideNote` 参数（第 78–81 行）。BTShareCard 内部也没有任何备注/心得区域可隐藏。toggle 点击后**无视觉效果**。
- **预期**：toggle 应控制分享卡内训练心得/备注文字的显隐。
- **修复方向**：若分享卡需显示心得，先在 `TrainingSessionSummary` 添加 `note` 字段，再在 BTShareCard 增加备注区域与 `hideNote` 参数。若 MVP 不含备注区域，移除该 toggle 以避免误导。
- **路由至**：swiftui-developer
- **代码提示**：`TrainingShareView.swift:10,153`、`BTShareCard.swift:77-81`

### U-03 多处触摸目标 < 44pt（HIG 违规）

- **类别**：HIG
- **严重程度**：P1
- **位置**：多处

| 组件 | 位置 | 实际高度估算 | 要求 |
|------|------|-------------|------|
| 字体选择 pill | TrainingShareView 字体行 | ~30pt（vertical padding 8pt × 2 + 14pt text） | ≥ 44pt |
| 选项 toggle pill | TrainingShareView 选项行 | ~29pt（vertical padding 8pt × 2 + 13pt text） | ≥ 44pt |
| 「查看历史记录」 | TrainingSummaryView 底栏 | ~20pt（仅文字，无 frame/padding） | ≥ 44pt |
| 底栏「返回」文字 | TrainingShareView 分享区 | ~20pt（仅文字 + padding.top 12） | ≥ 44pt |
| 「跳过」按钮 | TrainingNoteView 底栏左侧 | ~20pt（仅文字，无 frame） | ≥ 44pt |

- **预期**：所有可点击元素触摸目标 ≥ 44pt（Apple HIG）。
- **修复方向**：对各 pill / 文字按钮添加 `.frame(minHeight: 44)` 或增加 vertical padding。
- **路由至**：swiftui-developer
- **代码提示**：`TrainingSummaryView.swift:268`、`TrainingShareView.swift:97–105,167–179,200–207`、`TrainingNoteView.swift:90–95`

---

## P2 问题（视觉瑕疵）

### U-04 ShareCardTheme 枚举与规格不一致

- **类别**：产品规格
- **严重程度**：P2
- **位置**：BTShareCard 支持类型
- **现状**：`ShareCardTheme` 包含 4 个 case：`defaultGreen / blackWhite / nightBlue / deepPurple`。
- **预期**：`UI-IMPLEMENTATION-SPEC.md` §2.14 定义 API 为 3 个 case：`defaultGreen / blackWhite / nightBlue`。设计稿 P0-06 `screen.png` 也仅显示 3 个主题 + 1 个「更多」placeholder。
- **修复方向**：移除 `deepPurple` 或将其归入未来「更多」扩展功能。需要产品决策。
- **路由至**：swiftui-developer / ios-architect
- **代码提示**：`BTShareCard.swift:32–46`

### U-05 BTShareCard 内字体使用 inline `Font.system(size:)` 而非 Typography Token

- **类别**：Design Token
- **严重程度**：P2
- **位置**：BTShareCard 全组件
- **现状**：BTShareCard 内所有字体通过 `Font.system(size: XX, weight: YY, design: fontDesign)` 直接指定，例如：
  - Logo 标题：`size: 15, weight: .semibold`（等效 btSubheadlineMedium）
  - 计划名称：`size: 22, weight: .bold`（等效 btTitle）
  - Stat 数值：`size: 22, weight: .bold`（等效 btTitle）
  - 品牌名：`size: 13, weight: .bold`（等效 btFootnote + bold）
- **预期**：即使需要 `fontDesign` 参数做圆角字体切换，也应尽量复用 Token 常量或提取卡片专属 Token，避免散落硬编码。
- **修复方向**：可在 BTShareCard 内部定义 `cardFont(_ base: Font, design: Font.Design)` 辅助方法，或为 Font extension 添加接受 design 参数的变体。
- **路由至**：swiftui-developer
- **代码提示**：`BTShareCard.swift:118,124,138,162,214,250`

### U-06 Drill 明细卡片使用非标准间距 `Spacing.md + 2`

- **类别**：Design Token
- **严重程度**：P2
- **位置**：训练 > 训练总结 > 训练明细卡片
- **现状**：`drillCard()` 方法中多处使用 `.padding(Spacing.md + 2)` = 14pt 和 `.padding(.horizontal, Spacing.md + 2)` = 14pt。
- **预期**：间距必须为 Spacing 枚举值之一（4/8/12/16/20/24/32/48）。14pt 不在 Token 体系中。
- **修复方向**：视设计意图选择 `Spacing.md`（12pt）或 `Spacing.lg`（16pt）。设计稿 `p-3.5` = 14px 是 Tailwind 值，对应 iOS 最近 Token 应为 `Spacing.lg`（16pt）。
- **路由至**：swiftui-developer
- **代码提示**：`TrainingSummaryView.swift:163,169,176,177`

### U-07 TrainingNoteView「完成」按钮使用硬编码 padding

- **类别**：Design Token
- **严重程度**：P2
- **位置**：训练 > 训练心得 > 底栏「完成」按钮
- **现状**：`.padding(.horizontal, 40)` 和 `.padding(.vertical, 14)`，均为非 Token 值。
- **预期**：应使用 Spacing Token 或复用 BTButtonStyle。设计稿参考训记的训练心得页，底栏按钮应为标准尺寸。
- **修复方向**：使用 `BTButtonStyle.primary`（高度 52pt）或至少将 padding 替换为 Spacing Token 组合。
- **路由至**：swiftui-developer
- **代码提示**：`TrainingNoteView.swift:103–108`

### U-08 成功率数字字号与设计稿偏差（34pt vs 32pt）

- **类别**：Design Token
- **严重程度**：P2
- **位置**：训练 > 训练总结 > 平均成功率卡片
- **现状**：使用 `.btLargeTitle`（34pt bold rounded）+ `.fontWeight(.heavy)`。
- **预期**：设计稿 P0-06 code.html 为 `text-[32px] font-extrabold`（32px extrabold）。34pt 比设计大 2pt，且 `.heavy`（W900）比 extrabold（W800）更重。
- **修复方向**：btLargeTitle 为系统 Token（34pt），偏差可接受。但 `.fontWeight(.heavy)` 在已有 `.bold` 的 btLargeTitle 上叠加，建议移除多余的 `.fontWeight(.heavy)` 以回归 Token 定义。
- **路由至**：swiftui-developer
- **代码提示**：`TrainingSummaryView.swift:99`

### U-09 Drill 成功率百分比字号偏差（17pt vs 18px）

- **类别**：Design Token
- **严重程度**：P2
- **位置**：训练 > 训练总结 > 训练明细 > 各 Drill 卡片右侧百分比
- **现状**：使用 `.btHeadline`（17pt semibold）+ `.fontWeight(.heavy)`。
- **预期**：设计稿 `text-[18px] font-extrabold`，对应 18pt。
- **修复方向**：17pt 在视觉上接近 18pt，偏差可控。但 `.fontWeight(.heavy)` 叠加在 semibold 之上偏重。建议保持 btHeadline 并调整为 `.fontWeight(.bold)` 即可。若需严格匹配可改用 `Font.system(size: 18, weight: .heavy, design: .rounded)`。
- **路由至**：swiftui-developer
- **代码提示**：`TrainingSummaryView.swift:160`

### U-10 分享卡弱化成功率文字对比度不足

- **类别**：无障碍
- **严重程度**：P2
- **位置**：分享训练 > BTShareCard > 成功率 < 70% 的 Drill 行
- **现状**：`drillRateColor` 对 `< 0.7` 返回 `.white.opacity(0.45)`。在 `#1C1C1E` 背景上，白色 45% 不透明度的近似 hex 为 `#838383`，对比度约 3.3:1。
- **预期**：WCAG AA 要求正常文字对比度 ≥ 4.5:1（15pt bold 约为大文字阈值，可降至 3:1，但 15pt medium 不算大文字）。
- **修复方向**：提高 opacity 至 `0.60`（约 4.8:1）或使用 `btTextSecondary` Dark 值 `rgba(235,235,240,0.6)` 作为弱化色。
- **路由至**：swiftui-developer
- **代码提示**：`BTShareCard.swift:186–194`

### U-11 Drill 缩略图为占位图标，未匹配设计稿

- **类别**：视觉打磨
- **严重程度**：P2
- **位置**：训练 > 训练总结 > 训练明细 > Drill 卡片左侧缩略图
- **现状**：统一使用 SF Symbol `figure.pool.swim` 置于 `btPrimaryMuted` 背景的 48×48 方块。
- **预期**：设计稿 P0-06 显示各 Drill 有独立的球台布局插图（红球阵列、斜角线等）；Dark 模式 E-01 stitch 显示缩略图使用 `btTableFelt`（#144D2A）背景 + `btTableCushion`（#5C2E00）边框的真实球台迷你图（56×56 带 3px border）。
- **修复方向**：当 Drill 有关联的球台 Canvas 数据时，渲染迷你球台缩略图（复用 BTBilliardTable 缩略模式）。无 Canvas 数据时保留当前 SF Symbol 占位。缩略图尺寸可从 48pt 提升至设计的 56pt。Dark 模式边框改用 `btTableCushion` + 3pt 宽度。
- **路由至**：swiftui-developer
- **代码提示**：`TrainingSummaryView.swift:188–201`

### U-12 导航栏缺少右侧分享按钮

- **类别**：产品规格
- **严重程度**：P2
- **位置**：训练 > 训练总结 > 导航栏
- **现状**：TrainingSummaryView 未设置 toolbar 项。分享功能仅通过底栏「生成分享图」按钮触发。
- **预期**：设计稿 P0-06 和 E-01 帧4 均在导航栏右侧显示分享图标（iOS share icon）。
- **修复方向**：在 parent view（或 TrainingSummaryView 内部）添加 `.toolbar { ToolbarItem(placement: .topBarTrailing) { shareButton } }`。
- **路由至**：swiftui-developer
- **代码提示**：`TrainingSummaryView.swift`（需在 body 或调用方添加 toolbar）

### U-13 训练心得区缺少装饰性模糊背景

- **类别**：视觉打磨
- **严重程度**：P2
- **位置**：训练 > 训练总结 > 训练心得卡片
- **现状**：心得卡片为纯 `btBGSecondary` 背景 + 边框，无装饰元素。
- **预期**：Light 设计稿 P0-06 code.html 包含 `absolute -right-4 -top-4 w-24 h-24 bg-[#1A6B3C]/5 rounded-full blur-2xl` 装饰模糊圆。
- **修复方向**：在 noteSection 卡片内 overlay 一个 `Circle().fill(Color.btPrimary.opacity(0.05)).blur(radius: 32)` 定位在右上角。优先级低，可作为打磨项。
- **路由至**：swiftui-developer
- **代码提示**：`TrainingSummaryView.swift:226–250`

### U-14 WeChat 分享按钮颜色硬编码

- **类别**：Design Token
- **严重程度**：P2
- **位置**：训练 > 分享训练 > 分享按钮区
- **现状**：微信好友和朋友圈按钮使用 `Color(red: 0x07/255.0, green: 0xC1/255.0, blue: 0x60/255.0)` 硬编码 hex。
- **预期**：第三方品牌色无对应 Token，可接受。但建议提取为命名常量 `Color.wechatGreen` 避免重复硬编码。
- **修复方向**：在 Colors.swift 或 TrainingShareView 顶部添加 `private let wechatGreen = Color(...)` 常量。
- **路由至**：swiftui-developer
- **代码提示**：`TrainingShareView.swift:187,190`

### U-15 TrainingNoteView 占位文字 padding 硬编码

- **类别**：Design Token
- **严重程度**：P2
- **位置**：训练 > 训练心得 > 文本编辑器占位文字
- **现状**：`.padding(.top, 8)` 和 `.padding(.leading, 5)`，8 恰好等于 `Spacing.sm`，但 5 不在 Token 体系中。
- **预期**：间距使用 Spacing Token。
- **修复方向**：改为 `.padding(.top, Spacing.sm)` `.padding(.leading, Spacing.xs)`（4pt）或 `.padding(.leading, Spacing.sm)`（8pt），取视觉匹配。TextEditor 内部有约 5pt 默认 padding，需实测对齐效果。
- **路由至**：swiftui-developer
- **代码提示**：`TrainingNoteView.swift:67`

### U-16 分享卡预览阴影 radius 12 超出 SKILL.md 限制

- **类别**：视觉打磨
- **严重程度**：P2
- **位置**：训练 > 分享训练 > 卡片预览
- **现状**：`.shadow(... radius: 12, ...)` 超出 SKILL.md §6 建议的 blur ≤ 8pt。
- **预期**：设计稿 P0-06 code.html 使用 `shadow-[0_8pt_24pt_rgba(0,0,0,0.18)]`（radius=24pt），实际设计意图是较大阴影。代码的 12pt 已比设计保守。
- **修复方向**：因设计明确要求较大阴影以凸显卡片浮动效果，且仅用于预览场景非通用组件，可保留。建议在代码注释中标注设计决策。
- **路由至**：swiftui-developer（低优先级）
- **代码提示**：`TrainingShareView.swift:54`

### U-17 Dark 模式 < 70% 成功率色应为灰色调

- **类别**：Dark Mode
- **严重程度**：P2
- **位置**：训练 > 训练总结 > Drill 明细 > 低成功率百分比
- **现状**：`drillRateColor` 对 `< 0.7` 返回 `.btWarning`（Dark #FF7043 橙红色）。
- **预期**：Dark 设计稿 E-01 帧4 code.html 第 250 行对 56% 使用 `text-on-surface-variant`（`rgba(235,235,240,0.6)` 淡灰），而非橙色。Light 设计稿使用 `#D97706`（琥珀色）。Dark 模式下应为灰色弱化处理以匹配设计。
- **修复方向**：将 `drillRateColor` 修改为 Dark 模式感知：`colorScheme == .dark ? .btTextSecondary : .btWarning`。或者统一使用 `.btTextSecondary` 在两种模式下弱化低成功率（与分享卡逻辑对齐）。
- **路由至**：swiftui-developer
- **代码提示**：`TrainingSummaryView.swift:219–222`

---

## D-3 验证

- **「详情」标签已移除**：✅ `drillBreakdownSection`（第 126–137 行）仅包含 `Text("训练明细")` 标题，无「详情」副标签。符合 D-3 修正要求。

## 分享卡成功率色阶验证

- **BTShareCard `drillRateColor`**：
  - `≥ 0.9` → `#25A25A`（亮绿） ✅
  - `≥ 0.7` → `theme.accentColor`（品牌色） ✅
  - `< 0.7` → `.white.opacity(0.45)`（弱化白） ✅（但对比度不足，见 U-10）
- **BTShareCard `overallRateColor`**：同逻辑 ✅

---

## 审查总结

- **审查文件**：4 个（TrainingSummaryView / TrainingShareView / BTShareCard / TrainingNoteView）
- **发现问题**：17 项（P0: 0 / P1: 3 / P2: 14）
- **D-3 验证**：通过
- **分享卡色阶验证**：通过
- **总体评价**：四个视图整体结构与设计稿高度一致，Token 使用规范度较好。主要问题集中在：(1) 分享页两个 toggle 未实际生效 — 用户可操作但无反馈，体验受损；(2) 多处小组件触摸目标不足；(3) BTShareCard 字体硬编码较多。
- **建议下一步**：
  1. **优先修复 P1**：U-01 / U-02（toggle 功能缺失）、U-03（触摸目标）
  2. **第二轮修复 P2 高价值项**：U-05（Token 一致性）、U-06 / U-07（间距硬编码）、U-10（无障碍对比度）、U-17（Dark 模式色调）
  3. **打磨项**（可随后续迭代处理）：U-11（缩略图）、U-12（导航栏分享）、U-13（装饰模糊）
