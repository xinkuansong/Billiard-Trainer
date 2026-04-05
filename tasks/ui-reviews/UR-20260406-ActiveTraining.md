## UI 审查报告 — ActiveTrainingView（Light + Dark）
日期：2026-04-06

审查对象：`ActiveTrainingView.swift`、`DrillRecordView.swift`、`BTRestTimer.swift`、`BTSetInputGrid.swift`、`BTExerciseRow.swift`

设计参考：P0-03 code.html + screen.png（总览）、P0-04 code.html + screen.png（单项记录）、E-01 frame2/frame3（Dark Mode）、ref-screenshots 02-training-active 系列

---

### U-01 BTExerciseRow 缩略图为占位图标，未使用球台缩略图
- **类别**：产品规格 / 视觉打磨
- **严重程度**：P1
- **位置**：训练 Tab > ActiveTrainingView > 总览 > BTExerciseRow > thumbnail
- **现状**：缩略图区域使用 `btPrimaryMuted` 底色 + `figure.pool.swim` SF Symbol 图标占位，无球台渲染。
- **预期**：P0-03/P0-04 设计及 UI-IMPLEMENTATION-SPEC §2.10 明确要求「左侧 | 球台缩略图 56pt 方形圆角」，应渲染缩小版球台（btTableFelt 台面 + btTableCushion 库边 + 母球/目标球位置）。E-01 Dark 帧同样展示 `#144D2A` 台面 + `#5C2E00` 库边 + 两球缩略图。
- **修复方向**：在 BTExerciseRow 的 thumbnail 中，当 `thumbnailAnimation != nil` 时渲染 mini BTBilliardTable（仅台面+库边+球，不含路径动画）；为 nil 时保留当前占位图标作为 fallback。
- **涉及文件**：`QiuJi/Core/Components/BTExerciseRow.swift`

---

### U-02 总览页 ExerciseRow 卡片间距偏小（8pt → 12pt）
- **类别**：布局
- **严重程度**：P2
- **位置**：训练 Tab > ActiveTrainingView > overviewContent > VStack spacing
- **现状**：`VStack(spacing: Spacing.sm)` = 8pt 间距。
- **预期**：P0-03 code.html 总览卡片使用 `space-y-3`（12px），P0-04 code.html `space-y-4`（16px）。应使用 `Spacing.md`（12pt）保持与设计一致。
- **修复方向**：将 overviewContent 中 `VStack(spacing: Spacing.sm)` 改为 `VStack(spacing: Spacing.md)`。
- **涉及文件**：`QiuJi/Features/Training/Views/ActiveTrainingView.swift` L194

---

### U-03 顶栏右侧图标触摸目标不足 44pt
- **类别**：HIG / 无障碍
- **严重程度**：P1
- **位置**：训练 Tab > ActiveTrainingView > frostedTopBar > 右侧 4 个图标按钮
- **现状**：每个图标按钮 `.frame(width: 36, height: 36)`，触摸目标仅 36×36pt。
- **预期**：Apple HIG 要求可交互元素触摸目标 ≥ 44×44pt。设计 code.html 中图标使用 `p-1 rounded-lg`（约 40px）但属于极限值。
- **修复方向**：将图标按钮 frame 改为 `44×44`，内部图标保持当前大小。图标间距 `Spacing.md`（12pt）可能需要微调为 `Spacing.sm`（8pt）以容纳更大触摸区。
- **涉及文件**：`QiuJi/Features/Training/Views/ActiveTrainingView.swift` L321–L355

---

### U-04 DrillRecordView 缺少「休息设置」行与「模式切换」芯片
- **类别**：产品规格
- **严重程度**：P1
- **位置**：训练 Tab > ActiveTrainingView > DrillRecordView > 备注行与网格之间
- **现状**：DrillRecordView 中 noteInputRow 直接接 BTSetInputGrid，缺少两个设计元素。
- **预期**：P0-04 code.html 在备注与网格之间依次显示：(1)「休息设置 60s 设置」行（闹钟图标 + 时间 + 设置按钮）、(2) 两个模式芯片（「每组计时」和「显示成功率」各带对勾）。E-01 Dark frame3 同样展示此布局。
- **修复方向**：在 DrillRecordView 中 noteInputRow 与 BTSetInputGrid 之间增加休息设置快捷行和双芯片行。休息设置需与 BTRestTimer 联动。
- **涉及文件**：`QiuJi/Features/Training/Views/DrillRecordView.swift`

---

### U-05 Dark Mode 底栏应使用实色背景而非毛玻璃材质
- **类别**：Dark Mode
- **严重程度**：P2
- **位置**：训练 Tab > ActiveTrainingView > bottomToolbar
- **现状**：底栏使用 `.ultraThinMaterial`，Dark Mode 下为半透明模糊效果。
- **预期**：E-01 frame2 code.html 底栏明确使用 `bg-[#1C1C1E] border-t border-[#38383A]`（实色 btBGSecondary + btSeparator 上边框）。UI-IMPLEMENTATION-SPEC §六「Dark Mode 全局规则 §6.2」要求卡片容器移除阴影并靠色差分层。
- **修复方向**：底栏背景改为 `colorScheme == .dark ? Color.btBGSecondary : .ultraThinMaterial` 分支处理；Dark Mode 下添加 `.border(top: Color.btSeparator, width: 0.5)`。
- **涉及文件**：`QiuJi/Features/Training/Views/ActiveTrainingView.swift` L481

---

### U-06 BTRestTimer 倒计时数字字号与规格不符（28pt → 32pt）
- **类别**：Design Token
- **严重程度**：P2
- **位置**：Core > BTRestTimer > timerRing > timeString
- **现状**：使用 `.btStatNumber`（28pt Bold Rounded）。
- **预期**：UI-IMPLEMENTATION-SPEC §2.12 要求「中心 | 倒计时数字 32pt Bold」。设计意图为更突出的视觉焦点。
- **修复方向**：改为 `.font(.system(size: 32, weight: .bold, design: .rounded))`，或在 Typography 中新增 `btTimerDisplay` Token。
- **涉及文件**：`QiuJi/Core/Components/BTRestTimer.swift` L48

---

### U-07 BTSetInputGrid 当前行左侧标记宽度偏窄（2px → 应更醒目）
- **类别**：视觉打磨
- **严重程度**：P2
- **位置**：训练 Tab > ActiveTrainingView > BTSetInputGrid > active row 左侧竖条
- **现状**：active 行左侧竖条为 `Rectangle().fill(Color.btPrimary).frame(width: 2)`。
- **预期**：P0-04 code.html active 行使用 `border-l-4`（4px 宽度，CSS 像素 ≈ 4pt）。E-01 Dark frame3 同为 `border-l-4 border-[#25A25A]`。
- **修复方向**：将竖条宽度改为 3pt 或 4pt，更清晰地标识当前行。
- **涉及文件**：`QiuJi/Core/Components/BTSetInputGrid.swift` L177–L179

---

### U-08 BTExerciseRow Dark Mode 缺少 0.5pt 描边
- **类别**：Dark Mode
- **严重程度**：P2
- **位置**：训练 Tab > ActiveTrainingView > 总览 > BTExerciseRow 卡片
- **现状**：BTExerciseRow 在 Dark Mode 下仅有 btBGSecondary 背景，无描边。
- **预期**：E-01 frame2 code.html Drill 卡片使用 `border border-white/5`。UI-IMPLEMENTATION-SPEC §六「Dark Mode §6.2」规定需区分时使用 `#38383A` 1px 细边框。SKILL.md §十五「Dark Mode 检查清单」要求缩略图添加 0.5pt btSeparator 描边。
- **修复方向**：在 BTExerciseRow 添加 `@Environment(\.colorScheme)`，Dark 下给卡片 `.overlay(RoundedRectangle(cornerRadius: BTRadius.md).stroke(Color.btSeparator, lineWidth: 0.5))`。
- **涉及文件**：`QiuJi/Core/Components/BTExerciseRow.swift`

---

### U-09 底栏垂直 padding 过小（4pt → ≥8pt）
- **类别**：布局
- **严重程度**：P2
- **位置**：训练 Tab > ActiveTrainingView > bottomToolbar
- **现状**：`.padding(.vertical, Spacing.xs)` = 4pt，底栏整体偏矮。
- **预期**：P0-04 code.html 底栏 `h-20`（80px）+ `pb-safe`。E-01 Dark code.html 底栏 `h-20 px-4 pb-6 pt-2`。当前 4pt 上下边距导致底栏视觉高度不足。
- **修复方向**：垂直 padding 改为 `Spacing.sm`（8pt），并确保 Safe Area 底部留白（`safeAreaInset(edge: .bottom)` 或 `.padding(.bottom)` 适配 Home Indicator）。
- **涉及文件**：`QiuJi/Features/Training/Views/ActiveTrainingView.swift` L480

---

### U-10 顶栏与底栏图标缺少无障碍标签
- **类别**：无障碍
- **严重程度**：P2
- **位置**：训练 Tab > ActiveTrainingView > frostedTopBar + bottomToolbar
- **现状**：顶栏 4 个图标按钮（暂停/计时器/排序/完成）和底栏 5 个工具项均无 `.accessibilityLabel`。
- **预期**：VoiceOver 用户无法识别按钮功能。应为每个按钮添加描述性标签（如「暂停计时」「结束训练」「最小化」等）。
- **修复方向**：为每个 Button 添加 `.accessibilityLabel("描述")`。
- **涉及文件**：`QiuJi/Features/Training/Views/ActiveTrainingView.swift` L316–L355（顶栏）、L417–L497（底栏）

---

### U-11 总览页 Drill 卡片缺少轻阴影
- **类别**：视觉打磨
- **严重程度**：P2
- **位置**：训练 Tab > ActiveTrainingView > 总览 > BTExerciseRow
- **现状**：BTExerciseRow 无阴影，纯 btBGSecondary 背景平铺。
- **预期**：P0-03 code.html 卡片使用 `shadow-sm border border-black/[0.02]`（极轻阴影 + 极淡边框），P0-04 code.html 同样使用 `shadow-sm`。Light Mode 下应有轻微阴影提升层次感，Dark Mode 下自动移除（`.clear`）。
- **修复方向**：在 BTExerciseRow 添加条件阴影 `.shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.04), radius: 4, x: 0, y: 1)`。
- **涉及文件**：`QiuJi/Core/Components/BTExerciseRow.swift`

---

### U-12 BTSetInputGrid 待完成行输入格 Dark 背景应为 btBGTertiary
- **类别**：Dark Mode
- **严重程度**：P2
- **位置**：训练 Tab > BTSetInputGrid > pending 行的进球/总球输入格
- **现状**：所有行的输入格均使用 `btBGSecondary` 背景（Light #FFFFFF / Dark #1C1C1E），与容器背景相同。
- **预期**：E-01 Dark frame3 code.html 中 pending 行输入格使用 `bg-[#2C2C2E] border border-[#3A3A3C]`，即 btBGTertiary 底色 + btBGQuaternary 描边，与容器 btBGSecondary 形成层次差异。
- **修复方向**：pending/active 行输入格背景改为 `btBGTertiary`，仅 completed 行保持 `btBGSecondary`。
- **涉及文件**：`QiuJi/Core/Components/BTSetInputGrid.swift` L203–L248

---

### U-13 frostedTopBar 计时器字重为 semibold，设计为 bold
- **类别**：Design Token
- **严重程度**：P2
- **位置**：训练 Tab > ActiveTrainingView > frostedTopBar > 计时器
- **现状**：`.font(.system(size: 28, weight: .semibold, design: .monospaced))`
- **预期**：P0-03 code.html `text-[28px] font-bold tracking-tight`（28pt bold），P0-04 code.html `text-[32px] font-mono font-bold`。E-01 Dark 两帧均 `text-[28pt] font-bold`。权重应为 `.bold`。
- **修复方向**：改为 `.font(.system(size: 28, weight: .bold, design: .monospaced))`。
- **涉及文件**：`QiuJi/Features/Training/Views/ActiveTrainingView.swift` L307

---

### U-14 BTSetInputGrid 热身行「热」标记字号/尺寸与设计差异
- **类别**：Design Token
- **严重程度**：P2
- **位置**：训练 Tab > BTSetInputGrid > warmup 行 > setNumberColumn
- **现状**：「热」标记使用 btCaption2（11pt Medium），容器 22×22pt，圆角 4pt。
- **预期**：P0-04 code.html 热身标记 `text-[10px] font-black px-1.5 py-0.5 rounded-sm`（10px 极粗体）。E-01 Dark code.html 标记 `w-6 h-6`（24×24pt）。尺寸应为 24×24pt，字号 10pt，字重 Black 以匹配设计的紧凑厚重感。
- **修复方向**：容器改为 24×24pt，字重改为 `.black`（或 `.heavy`），圆角保持 4pt。
- **涉及文件**：`QiuJi/Core/Components/BTSetInputGrid.swift` L189–L193

---

### U-15 总览与记录视图间缺少明确的视觉切换反馈
- **类别**：产品规格
- **严重程度**：P2
- **位置**：训练 Tab > ActiveTrainingView > 底栏「切换」按钮
- **现状**：底栏「切换」按钮在总览/记录模式间切换时图标变化（list.bullet ↔ rectangle.grid.1x2），但图标较小且均为灰色，不易区分当前状态。
- **预期**：设计参考中（ref-screenshots 03-active-main）底栏「在表练」按钮在激活时有蓝色高亮。应有视觉反馈标识当前模式。
- **修复方向**：考虑在总览模式下将「切换」按钮图标/文字改为 btPrimary 色以标识当前位于总览视图，或在记录模式下高亮对应按钮。
- **涉及文件**：`QiuJi/Features/Training/Views/ActiveTrainingView.swift` L470–L477

---

### U-16 DrillRecordView completedBanner 使用非标准圆角
- **类别**：Design Token
- **严重程度**：P2
- **位置**：训练 Tab > DrillRecordView > completedBanner
- **现状**：`clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))` = 16pt。
- **预期**：completedBanner 为内嵌卡片，应与同级组件保持一致圆角。其他卡片（noteInputRow、ballTableSection）使用 BTRadius.md = 12pt。
- **修复方向**：统一改为 `BTRadius.md`（12pt）。
- **涉及文件**：`QiuJi/Features/Training/Views/DrillRecordView.swift` L125

---

### 审查总结
- 截图/代码审查范围：5 个 Swift 文件 + 3 个 stitch 设计（含 Light/Dark）+ 6 张 ref-screenshots
- 发现问题：16 项（P0: 0 / P1: 3 / P2: 13）
- 总体评价：ActiveTrainingView 的框架结构（毛玻璃顶栏 + 5 键底栏 + 总览/记录切换 + 网格在上球台在下）与设计意图基本一致，Token 使用规范。主要差距集中在：(1) BTExerciseRow 缩略图未还原球台渲染（P1，视觉影响最大）；(2) 缺少休息设置行和模式切换芯片（P1，功能完整性）；(3) 多处 Dark Mode 细节未对齐（描边/底栏背景/输入格层次）。
- 建议下一步：
  1. **优先修复 P1**：U-01（缩略图）、U-03（触摸目标）、U-04（休息设置行 + 模式芯片）
  2. **批量修复 Dark Mode P2**：U-05、U-08、U-12 可一次性处理
  3. **Token 微调 P2**：U-02、U-06、U-07、U-13、U-14 为数值校准，改动量小
  4. **无障碍 P2**：U-10 添加 accessibilityLabel
