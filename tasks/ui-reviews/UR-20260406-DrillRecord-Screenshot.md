## UI 截图审查报告 — DrillRecordView + NoteInput（截图对照）
日期：2026-04-06

审查对象：单项记录视图 + 训练心得输入
截图来源：P0-04-01, P0-04-02, P0-08-01（3 张实机截图）
设计参考：P0-04 code.html + screen.png (3 versions), P0-08 code.html + screen.png

---

### S-01 缺少休息设置行（Rest Settings Row）
- **类别**：产品规格
- **严重程度**：P1（功能缺陷）
- **位置**：训练 > DrillRecordView > 备注行与组输入网格之间
- **截图现状**：备注输入行下方直接跟随 BTSetInputGrid 组输入网格，无休息设置入口
- **设计预期**：备注行与网格之间应有「休息设置」行，含 alarm 图标、"休息设置" 文字、"60s" 当前值（btPrimary bold）和 "设置" 按钮（secondary bold）。参见 P0-04-04 code.html L146–L155
- **修复方向**：在 DrillRecordView / ActiveTrainingView 的备注行下方插入 BTRestTimer 配置行，展示当前休息时长及进入设置入口

---

### S-02 缺少模式切换 Chips（Toggle Chips）
- **类别**：产品规格
- **严重程度**：P1（功能缺陷）
- **位置**：训练 > DrillRecordView > 休息设置行与组网格之间
- **截图现状**：无 "每组计时" 和 "显示成功率" 切换选项
- **设计预期**：两个胶囊形 Toggle Chip 并排显示，选中态含 check 图标 + btPrimary 文字，背景 `bg-slate-200/50`。参见 P0-04-04 code.html L157–L166
- **修复方向**：使用 BTTogglePillGroup 组件添加两个选项："每组计时"、"显示成功率"，根据选中状态显示 check 图标

---

### S-03 Drill 卡片使用通用头像而非球台缩略图
- **类别**：产品规格 / Design Token
- **严重程度**：P1（功能缺陷）
- **位置**：训练 > DrillRecordView > Drill Header Card
- **截图现状**：Drill 卡片左侧使用绿色圆形通用头像（含游泳类图标），尺寸约 48pt 圆形
- **设计预期**：应使用 56×56pt 方形球台缩略图（`.billiard-table-thumb`），含 btTableFelt 底色、btTableCushion 边框（3px）、12px 圆角，内部渲染母球和目标球位置。参见 P0-04-04 code.html L126–L129（`billiard-table-thumb` 样式）
- **修复方向**：BTExerciseRow 组件中将头像替换为 BTBilliardTable 迷你缩略图，根据 drill JSON 中的球位数据渲染球位，使用 SKILL.md §十一 球台 Canvas 规范
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Core/Components/BTExerciseRow.swift`、`QiuJi/Core/Components/BTBilliardTable.swift`

---

### S-04 组输入网格列头使用 "#" 而非 "组"
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：训练 > DrillRecordView > BTSetInputGrid > 表头行
- **截图现状**：第一列表头显示 "#"
- **设计预期**：第一列表头应为 "组"，12px bold uppercase tracking-wider，颜色 btTextSecondary 50% 透明度。参见 P0-04-04 code.html L169–L170
- **修复方向**：将 BTSetInputGrid 表头第一列文字从 "#" 改为 "组"
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Core/Components/BTSetInputGrid.swift`

---

### S-05 已完成行数值仍显示在边框输入框内
- **类别**：布局
- **严重程度**：P2（视觉瑕疵）
- **位置**：训练 > DrillRecordView > BTSetInputGrid > 已完成行（P0-04-02 截图 row 1）
- **截图现状**：row 1 输入 "8" 后，进球数值仍然显示在带边框的输入单元格中（与未开始行相同的边框样式）
- **设计预期**：已完成行（有 filled check_circle）应去掉输入框边框，数值以 plain bold text 居中显示，行背景使用 `btPrimaryMuted`（btPrimary 6% opacity）淡绿色调。参见 P0-04-04 code.html L178、L192（已完成行使用 `bg-[#1A6B3C]/[0.06]`，无输入框边框）
- **修复方向**：BTSetInputGrid 中根据行状态（completed/active/pending）切换不同渲染样式：completed → plain text + tinted bg，active → bordered cell + accent bar，pending → light border + muted text
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Core/Components/BTSetInputGrid.swift`

---

### S-06 底部工具栏图标与设计不一致
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：训练 > DrillRecordView > 底部工具栏（5 个按钮）
- **截图现状**：
  - "最小化"：使用向下 chevron 图标
  - "更多"：使用 2×2 网格图标（类似 `square.grid.2x2`）
  - "切换"：使用列表/排列图标（类似 `list.bullet`）
- **设计预期**：
  - "最小化"：`minimize`（水平短线图标）
  - "更多"：`more_horiz`（三点横排图标）
  - "切换"：`swap_horiz`（左右双向箭头图标）
  - 参见 P0-04-04 code.html L291–L312
- **修复方向**：将三个图标的 SF Symbol 名称分别调整为设计指定的对应图标
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/Training/Views/ActiveTrainingView.swift`（底部工具栏区域）

---

### S-07 底部工具栏 "添加" 按钮颜色为 btPrimary（绿色）
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：训练 > DrillRecordView > 底部工具栏 > 中央 "添加" 按钮
- **截图现状**：圆形 "+" 按钮使用绿色（btPrimary #1A6B3C）填充
- **设计预期**：P0-04-02/03 设计中该按钮使用 `secondary`（#0058bc 蓝色）填充 + `shadow-secondary/30` 阴影。P0-04-04 最新版使用 `primary`（#1A6B3C 绿色）。两版设计不一致，建议以 P0-04-04 为准
- **修复方向**：确认以 P0-04-04 为最终设计，当前截图使用绿色与 P0-04-04 一致。若以 P0-04-02/03 为准则需改为 secondary 蓝色。建议确认最终版本

---

### S-08 球台示意展开/折叠指示符方向不一致
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：训练 > DrillRecordView > 球台示意 Section 标题
- **截图现状**："球台示意" 标题右侧使用向下 chevron（∨），暗示展开/折叠功能
- **设计预期**：标题右侧使用向右 chevron（>），`chevron_right` 图标，暗示可点击进入详情。参见 P0-04-04 code.html L263–L264
- **修复方向**：将 chevron 方向改为 `chevron.right`（SF Symbol: `chevron.right`），若功能确实为折叠式则保留当前设计并更新设计稿
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/Training/Views/ActiveTrainingView.swift`

---

### S-09 球台 Canvas 渲染缺少路径线与目标球
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：训练 > DrillRecordView > 球台示意 Canvas
- **截图现状**：球台仅显示一条垂直居中虚线和底部一个白色球（母球）。无目标球，无击球路径线
- **设计预期**：球台应根据 drill JSON 渲染母球（btBallCue 白色）、目标球（btBallTarget 橙黄色 #F5A623），以及连接两球的路径虚线（白色母球路径 + 橙色目标球路径）。参见 P0-04-04 code.html L276–L282、SKILL.md §十一
- **修复方向**：BTBilliardTable 组件根据当前 drill 的 JSON 数据正确渲染所有球位和路径线。当前截图的 drill（握杆稳定性练习）可能确实只有母球定位线，需确认 drill JSON 内容。若 JSON 确实如此则为内容问题而非代码问题
- **路由至**：swiftui-developer / content-engineer
- **代码提示**：`QiuJi/Core/Components/BTBilliardTable.swift`、`Resources/Drills/` 对应 JSON

---

### S-10 训练心得页面导航栏多出居中标题
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：训练心得 > 导航栏
- **截图现状**：导航栏显示左侧 "< 返回" + 居中 "训练心得" 标题
- **设计预期**：P0-08 设计中导航栏仅有左侧返回按钮（胶囊形式），无居中标题。页面上下文通过提示文字传达。参见 P0-08-02 code.html L101–L107
- **修复方向**：移除导航栏居中标题 "训练心得"，保持简洁编辑器体验。或保留标题并更新设计稿（标题有助于用户理解上下文）

---

### S-11 训练心得返回按钮使用标准 iOS 样式（与设计稿胶囊按钮不同）
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：训练心得 > 导航栏 > 返回按钮
- **截图现状**：使用标准 iOS NavigationStack 返回按钮：绿色 chevron + "返回" 文字，无背景
- **设计预期**：设计使用自定义胶囊按钮（`rounded-full bg-black/5 border border-black/10`），含 arrow_back_ios 图标 + "返回" 文字。参见 P0-08-02 code.html L103–L106
- **修复方向**：**建议保留截图实现**。标准 iOS 返回按钮更符合 Apple HIG（SKILL.md §十 "返回按钮：系统默认，不自定义文字"），设计稿的胶囊按钮偏离 HIG。建议更新设计稿以对齐 HIG 规范

---

### S-12 计时器显示格式与字号差异
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：训练 > DrillRecordView > 顶部计时器
- **截图现状**：计时器 "00:04" / "00:42" 使用大字号 bold 显示，数字间距较宽（字母间有明显空隙），格式为 MM:SS
- **设计预期**：计时器 "00:12:34" 使用 28–32px monospace bold，tracking-tight（紧凑字距），btPrimary 颜色。格式为 HH:MM:SS。参见 P0-04-04 code.html L106（`text-[32px] font-mono font-bold tracking-tight text-primary`）
- **修复方向**：
  1. 时间格式统一为 HH:MM:SS（即使时长 < 1 小时也显示 "00:00:04"）
  2. 字体使用 `.monospacedDigit()` + tracking tight
  3. 确认颜色使用 btPrimary token
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/Training/Views/ActiveTrainingView.swift`（顶部计时器区域）

---

### S-13 Drill 进度指示器使用圆点而非文字
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：训练 > DrillRecordView > Drill Header Card > 副标题区
- **截图现状**：Drill 名称下方显示 "3组 ●●●"（三个圆点指示器），右侧显示 "0/45"
- **设计预期**：副标题应为 "进球 36/90" 格式的纯文字（13px medium btTextSecondary）。参见 P0-04-04 code.html L132–L133。圆点进度指示器未在设计稿中出现
- **修复方向**：BTExerciseRow 副标题区域改为显示 "进球 X/Y" 格式文字，移除圆点指示器
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Core/Components/BTExerciseRow.swift`

---

### 审查总结
- 截图审查范围：3 张实机截图 + 4 张设计参考（P0-04-02/03/04 + P0-08-02）
- 发现问题：13 项（P0: 0 / P1: 3 / P2: 10）
- 总体评价：DrillRecordView 的核心交互框架（组输入网格、底部工具栏、球台示意）已基本实现，整体布局方向正确。但缺少休息设置行和模式切换 Chips 两个设计规格中的功能模块，Drill 卡片的缩略图风格偏离设计规范。训练心得页面与设计高度一致，返回按钮使用标准 iOS 样式反而比设计稿更符合 HIG。多处细节（图标选择、计时器格式、行状态样式区分）需要打磨。
- 建议下一步：
  1. **优先修复 P1**：实现休息设置行（S-01）、模式切换 Chips（S-02）、Drill 缩略图（S-03）
  2. **批量修复 P2**：统一底部工具栏图标（S-06）、计时器格式（S-12）、组输入网格行状态样式（S-05）
  3. **确认设计版本**：S-07 中添加按钮颜色在两版设计中不一致，需确认以 P0-04-04 为准
  4. **反向更新设计稿**：S-11 返回按钮建议保留标准 iOS 实现，更新设计稿对齐 HIG
