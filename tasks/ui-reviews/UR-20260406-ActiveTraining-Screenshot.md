## UI 截图审查报告 — ActiveTrainingView（截图对照）
日期：2026-04-06

审查对象：训练中视图（自由记录 + 计划训练总览）
截图来源：P0-03-01 ~ P0-03-06（6 张实机截图）
设计参考：P0-03 code.html + screen.png, ref-screenshots/02-training-active

---

### S-01 BTExerciseRow 缩略图为占位图标，未渲染球台缩略图
- **类别**：产品规格
- **严重程度**：P1
- **位置**：训练 Tab > ActiveTrainingView > BTExerciseRow > thumbnail
- **截图现状**：P0-03-02/04/05/06 所有 exercise row 左侧缩略图为灰绿底色 + `figure.pool.swim` SF Symbol 占位图标，无球台元素。
- **设计预期**：P0-03 screen.png 明确展示每个 drill 卡片左侧为 56×56pt 深绿底 (#1A6B3C) 方形缩略图，内含母球（白色圆点）+ 目标球（橙色圆点）的位置标记，带 2px 棕色 (#5D4037) 描边。code.html `.drill-thumbnail { background-color: #1A6B3C; border: 2px solid #5D4037; }` + 内置 `bg-white`/`bg-orange-500` 圆点。
- **修复方向**：在 BTExerciseRow 中，当 drill 有坐标数据时渲染 mini BTBilliardTable（台面 + 库边 + 母球/目标球位置），无数据时保留当前占位。需从 Drill JSON 读取球位坐标。

---

### S-02 计划训练显示通用标签"按计划训练"，未显示实际计划名称及编辑图标
- **类别**：产品规格
- **严重程度**：P1
- **位置**：训练 Tab > ActiveTrainingView > frostedTopBar > planTitle
- **截图现状**：P0-03-04/05 标题行显示"按计划训练"（通用文案），无可编辑计划名称，无编辑图标。
- **设计预期**：P0-03 screen.png + code.html 标题行显示具体计划名称"基础直球训练"，旁有编辑图标 (pencil icon, `opacity-40`)，code.html: `<h2 class="text-[22px] font-bold">基础直球训练</h2> <button><span>edit</span></button>`。docs/05 §3 Tab 1 交互设计同样指定显示"当前计划名称"。
- **修复方向**：从 TrainingSession.planName 或关联 Plan 实体获取计划名称并显示；添加编辑按钮（pencil SF Symbol, btTextTertiary）允许用户在训练中重命名会话。自由记录模式下显示"自由记录"无编辑图标（当前行为正确）。

---

### S-03 底栏"添加"按钮颜色为 btPrimary 绿，设计为 iOS 系统蓝 (#007AFF)
- **类别**：Design Token
- **严重程度**：P2
- **位置**：训练 Tab > ActiveTrainingView > bottomToolbar > 中央添加按钮
- **截图现状**：P0-03-02/04/05/06 底栏中央"添加"按钮为实心绿色圆形（btPrimary #1A6B3C），文字标签也为深绿色。
- **设计预期**：P0-03 code.html 明确指定 `bg-[#007AFF]`（iOS 系统蓝）+ `shadow-[0_8px_20px_rgba(0,122,255,0.3)]` 蓝色投影，标签文字 `text-[#007AFF]`。ref-screenshots/03-active-main 同样使用蓝色中央按钮。
- **修复方向**：如团队确认沿用设计，将中央按钮改为 `Color.accentColor`（iOS 蓝 #007AFF）+ 蓝色投影。若团队决定品牌统一使用 btPrimary 绿，需更新设计稿并在 IMPLEMENTATION-LOG 追加 DR-NNN 记录设计偏差。

---

### S-04 计时器格式为 MM:SS（4 位），设计为 HH:MM:SS（6 位 + 双冒号）
- **类别**：产品规格
- **严重程度**：P2
- **位置**：训练 Tab > ActiveTrainingView > frostedTopBar > timerDisplay
- **截图现状**：P0-03-01/02/04/05 计时器显示"00:00"、"00:02"格式（MM:SS，单冒号，4 位数字）；P0-03-06 显示"00:42"。
- **设计预期**：P0-03 screen.png + code.html 计时器显示"00:12:34"（HH:MM:SS，双冒号，6 位数字），code.html: `<h1 class="font-mono font-bold text-[28px]">00:12:34</h1>`。ref-screenshots/03-active-main 同样使用 HH:MM:SS 格式。
- **修复方向**：计时器格式化函数改为始终显示 HH:MM:SS 三段（至少在训练视图中）。短时间训练时显示"00:00:42"而非"00:42"，保持格式一致性和宽度稳定。

---

### S-05 顶栏第一个图标为播放/暂停，设计为通知铃铛
- **类别**：产品规格
- **严重程度**：P2
- **位置**：训练 Tab > ActiveTrainingView > frostedTopBar > 右侧第一个图标
- **截图现状**：P0-03-02/03 显示播放按钮 (▶)（计时器暂停时），P0-03-04 显示暂停按钮 (⏸)（计时器运行时）。播放/暂停功能复用了顶栏图标位置。
- **设计预期**：P0-03 code.html 第一个图标为 `notifications`（铃铛），用于训练中通知/提醒功能；code.html: `<span class="material-symbols-outlined">notifications</span>`。ref-screenshots/03 也在对应位置显示蓝色功能图标。
- **修复方向**：(1) 将播放/暂停移至计时器数字旁（点击数字区域暂停/恢复，或在数字左侧添加小图标）；(2) 恢复顶栏通知铃铛功能（用于组间休息提醒、训练时长提醒等）。需产品确认播放/暂停的最终交互位置。

---

### S-06 自由记录空状态与已填充状态的顶栏布局不一致
- **类别**：布局
- **严重程度**：P2
- **位置**：训练 Tab > ActiveTrainingView > 自由记录空状态 header
- **截图现状**：P0-03-01（空状态）顶栏为传统导航栏布局：左侧 [结束] 红色描边胶囊按钮 + 居中"自由记录"标题 + 右侧 [+] 图标按钮。计时器作为独立白色卡片置于标题下方，包含"继续"和"跳过计时"两个操作按钮。底栏 5 按钮工具栏不可见。
- **设计预期**：P0-03-02（已填充状态）使用毛玻璃顶栏（计时器 + 4 图标按钮），底栏显示 5 按钮工具栏。两种状态的导航范式完全不同（传统导航栏 vs 自定义毛玻璃栏），视觉断裂感明显。设计稿（code.html）仅展示已填充状态。
- **修复方向**：统一两种状态的顶栏布局——空状态也使用毛玻璃顶栏（计时器初始为 00:00:00 + 暂停态图标），将"结束"功能统一到顶栏完成按钮 (✓)，"添加"功能统一到底栏"添加"按钮。空状态的主体区域使用 BTEmptyState 组件（已有该模式）。

---

### S-07 结束训练确认弹窗为自定义浮动卡片，与参考设计差异较大
- **类别**：视觉打磨
- **严重程度**：P2
- **位置**：训练 Tab > ActiveTrainingView > endConfirmation dialog
- **截图现状**：P0-03-03/06 弹窗为自定义浮动圆角卡片（居中偏下），"结束训练？"标题 + "结束后可以记录本次训练心得。"副文本 + 水平排列两个按钮（"继续训练"描边 + "结束"红色文字），背景半透明遮罩。
- **设计预期**：ref-screenshots/06-active-end-confirm 展示大尺寸居中白卡（占屏幕约 40%宽），包含庆祝 emoji (🎉)、"完成训练"正向标题、"是否已经完成训练"副文本、蓝色填充主按钮 "完成并生成分享图"、"完成训练"文字按钮、"取消"文字按钮——按钮垂直堆叠。整体基调为「完成庆祝」而非「中途退出」。
- **修复方向**：需产品确认弹窗基调——若训练未完成（提前结束）使用当前警告风格，若训练已完成所有组数则切换为庆祝风格。建议参照 ref-06 增加完成状态弹窗变体：庆祝 emoji + "训练完成！" + 可选"生成分享图"按钮。同时考虑使用系统 `.confirmationDialog` 或 `.alert` 以符合 HIG。

---

### S-08 总览页 exercise row 卡片缺少轻阴影和超薄边框
- **类别**：视觉打磨
- **严重程度**：P2
- **位置**：训练 Tab > ActiveTrainingView > BTExerciseRow
- **截图现状**：P0-03-02/04/05 中 drill 卡片为纯白色背景平铺于灰色 (#F2F2F7) 底色上，无可见阴影或边框，卡片与背景仅靠色差区分。
- **设计预期**：P0-03 code.html 卡片样式 `bg-white rounded-xl p-4 shadow-sm border border-black/[0.02]`——包含极轻阴影 (shadow-sm ≈ 0 1px 2px rgba(0,0,0,0.05)) + 极淡边框 (border 2% 透明度黑色)。Light Mode 下应有微妙的浮起感。
- **修复方向**：在 BTExerciseRow 添加 `.shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)` + `.overlay(RoundedRectangle(cornerRadius: BTRadius.md).stroke(Color.black.opacity(0.02)))`；Dark Mode 下阴影自动替换为 btSeparator 描边。

---

### S-09 总览页卡片间距偏小（视觉对比设计为 12px）
- **类别**：布局
- **严重程度**：P2
- **位置**：训练 Tab > ActiveTrainingView > overviewContent > VStack
- **截图现状**：P0-03-04/05 中多张 drill 卡片间距目测约 8pt，卡片排列较紧凑。
- **设计预期**：P0-03 code.html 卡片列表使用 `space-y-3`（12px），卡片间应有适度呼吸空间。ref-screenshots/03-active-main 中卡片间距也明显大于当前截图。
- **修复方向**：将 overviewContent 的 `VStack(spacing: Spacing.sm)` (8pt) 改为 `VStack(spacing: Spacing.md)` (12pt)。

---

### S-10 自由记录空状态计时器卡片设计与主计时器不统一
- **类别**：布局 / 视觉打磨
- **严重程度**：P2
- **位置**：训练 Tab > ActiveTrainingView > 自由记录空状态 > timerCard
- **截图现状**：P0-03-01 空状态计时器为独立白色圆角卡片，内含超大字号"00:00"（约 48pt）+ 两个按钮行（"▶ 继续"胶囊按钮 + "▶▶ 跳过计时"胶囊按钮）。整体占据顶部约 1/4 屏幕高度。
- **设计预期**：P0-03 code.html / screen.png 计时器为毛玻璃顶栏内嵌元素（28pt font-mono font-bold），紧凑而不突兀。空状态的计时器卡片风格与已填充状态的紧凑顶栏计时器差异巨大：(1) 字号从 ~48pt → 28pt；(2) 从独立卡片 → 内嵌顶栏；(3) 从带操作按钮 → 仅数字显示。
- **修复方向**：与 S-06 统一处理——空状态也使用顶栏内嵌计时器，移除独立计时器卡片。"跳过计时"功能可移至顶栏长按计时器或设置菜单。

---

### S-11 自由记录空状态"选择训练项目"按钮为全宽绿色填充，与设计系统风格略有差异
- **类别**：视觉打磨
- **严重程度**：P2
- **位置**：训练 Tab > ActiveTrainingView > 自由记录空状态 > addDrillButton
- **截图现状**：P0-03-01 底部"选择训练项目"为全宽（约 80% 屏幕宽度）绿色填充按钮，高度约 52pt，白色文字。上方为绿色圆形加号图标 + "添加训练项目"标题 + 灰色说明文字。
- **设计预期**：设计系统 BTEmptyState 组件规范（SKILL.md §十二）定义为 SF Symbol 图标 + 标题 + 副标题 + 可选 actionButton。当前实现虽然包含这些元素，但 (1) 圆形加号图标不是标准 SF Symbol 样式（有圆形灰色底色环绕），(2) 全宽按钮在空旷页面中视觉比重过大。
- **修复方向**：考虑使用标准 BTEmptyState 组件（无额外圆形底色包裹的 SF Symbol `plus.circle` + 标题 + 副标题 + BTButton.primary）以保持组件一致性。按钮宽度可收窄至内容自适应。

---

### S-12 P0-03-06 训练中页面的底栏"切换"按钮图标变为列表图标
- **类别**：产品规格
- **严重程度**：P2
- **位置**：训练 Tab > ActiveTrainingView > bottomToolbar > switchButton (drill recording mode)
- **截图现状**：P0-03-06（钻入单项记录视图）底栏最右侧"切换"按钮图标变为三横线列表图标 (≡)，与 P0-03-04/05 总览模式下的方格图标 (⊞) 不同。
- **设计预期**：P0-03 code.html 底栏最右侧使用 `dashboard` 图标，始终一致。ref-screenshots/03 使用圆形图标。切换按钮的图标应在两种模式下保持一致（始终显示"切换到另一视图"的含义），或更清晰地传达当前所处模式。
- **修复方向**：建议固定使用一个图标（如 `rectangle.2.swap` 或保持 `list.bullet.rectangle`），通过图标颜色（选中态 btPrimary / 未选中态 btTextTertiary）标识当前模式，而非更换图标。

---

### 审查总结
- 截图审查范围：6 张实机截图 + 1 张设计 screen.png + 1 份设计 code.html + 6 张 ref-screenshots
- 发现问题：12 项（P0: 0 / P1: 2 / P2: 10）
- 总体评价：ActiveTrainingView 的核心框架（毛玻璃顶栏 + 5 键底栏 + 总览/记录切换 + 计时器 + 进度标示）在已填充状态下与设计意图基本吻合。主要差距集中在三个方面：(1) **缩略图未还原球台渲染**（S-01, P1）是视觉还原度最大的缺口；(2) **计划名称缺失 + 编辑图标缺失**（S-02, P1）影响用户对当前训练的辨识；(3) **自由记录空状态导航范式与已填充状态断裂**（S-06 + S-10）导致空→填充状态的体验不连贯。P2 问题多为颜色/间距/格式细节，改动量小。
- 建议下一步：
  1. **优先修复 P1**：S-01（球台缩略图渲染）、S-02（显示计划名称 + 编辑图标）
  2. **统一空状态布局**：S-06 + S-10 一并处理，让空状态复用已填充状态的顶栏 + 底栏布局
  3. **确认设计决策**：S-03（添加按钮颜色 绿 vs 蓝）、S-05（播放/暂停 vs 通知铃铛）需产品/设计确认
  4. **批量修复 P2 细节**：S-04（计时器格式）、S-08（卡片阴影）、S-09（间距）为小幅调整
