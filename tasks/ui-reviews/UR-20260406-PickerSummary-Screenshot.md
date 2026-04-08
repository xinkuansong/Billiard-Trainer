## UI 截图审查报告 — DrillPickerSheet + TrainingSummaryView（截图对照）
日期：2026-04-06

审查对象：动作选择弹窗 + 训练完成总结页
截图来源：P0-05-01, P0-06-01（2 张实机截图）
设计参考：P0-05 DrillPickerSheet, P0-06 TrainingSummaryView, ref-screenshots/02-training-active/07-08

---

## 一、DrillPickerSheet（动作选择弹窗）

> **整体评估**：当前实现与设计稿存在**架构级差异**。设计为左侧分类侧栏 + 右侧缩略图网格布局，实机为纯文字平铺列表。需要完整重构。

---

### S-01 整体布局架构与设计稿不一致
- **类别**：产品规格
- **严重程度**：P0（不可用）
- **位置**：训练 > 添加动作 > DrillPickerSheet（整个弹窗）
- **截图现状**：全屏列表布局，每行仅显示动作名称 + 类别/组数文本 + 右侧"⊕"按钮，无任何视觉层次区分
- **设计预期**：左侧 100px 分类侧栏（直球/角度球/组合球/翻袋/贴库/K球安全球/走位/综合）+ 右侧 2 列缩略图网格卡片，每张卡片含 4:3 缩略图 + 名称 + 等级标签。参考 `P0-05/code.html` L111–L221
- **修复方向**：重构为 `HStack { 侧栏 ScrollView + 主区域 LazyVGrid(columns: 2) }` 布局，引入分类侧栏导航与缩略图卡片

---

### S-02 缺少分类侧栏导航
- **类别**：产品规格
- **严重程度**：P1（功能缺陷）
- **位置**：训练 > 添加动作 > DrillPickerSheet 左侧区域
- **截图现状**：无分类导航，所有动作混合在一个扁平列表中
- **设计预期**：左侧 100px 宽栏，8 个分类按钮垂直排列（直球/角度球/组合球/翻袋/贴库/K球安全球/走位/综合），选中态为 btPrimary 文字 + 左侧 3px 边框 + btBGSecondary 背景；未选中态为 outline 灰色文字 + btBGTertiary/surface-container-low 背景
- **修复方向**：新增分类侧栏组件，绑定当前选中分类，联动过滤右侧网格内容

---

### S-03 缺少动作缩略图卡片
- **类别**：产品规格
- **严重程度**：P1（功能缺陷）
- **位置**：训练 > 添加动作 > DrillPickerSheet 列表项
- **截图现状**：每行仅显示文字（名称 + "基础功 · 3组 × 15球"）+ 右侧圆形"⊕"按钮，无任何视觉缩略图
- **设计预期**：2 列网格，每张卡片含 `aspect-[4/3]` 缩略图（Drill 对应的球台布局图或 AI 生成图）+ 名称 + BTLevelBadge。选中卡片有 `border-2 border-primary-container` 绿色边框 + `bg-primary/5` 浅绿背景；未选中卡片有 `border border-surface-variant` 细边框
- **修复方向**：使用 `LazyVGrid(columns: [.adaptive(minimum: 140)])` 渲染卡片，卡片内含 `AsyncImage`（或 BTBilliardTable 缩略图），下方显示名称和 BTLevelBadge

---

### S-04 搜索框位置与设计不符
- **类别**：布局
- **严重程度**：P1（功能缺陷）
- **位置**：训练 > 添加动作 > DrillPickerSheet 搜索栏
- **截图现状**：搜索框固定在弹窗最底部（在列表内容之下），且被列表末尾文字部分遮挡
- **设计预期**：搜索框位于标题栏下方、分类侧栏/网格上方，占据全宽度，高度 36pt，圆角 10pt，bg 为 surface-container，含搜索图标 + placeholder "搜索训练项目"。参考 `P0-05/code.html` L104–L109
- **修复方向**：将搜索框移至标题区域下方，使用 `flex-shrink-0` 固定（不随列表滚动），背景使用 `btBGTertiary`，圆角 `BTRadius.sm`

---

### S-05 顶栏关闭按钮缺失 + 完成按钮样式错误
- **类别**：产品规格 / HIG
- **严重程度**：P1（功能缺陷）
- **位置**：训练 > 添加动作 > DrillPickerSheet 顶栏 + 底栏
- **截图现状**：顶栏右侧仅有文字"完成"（btPrimary 色），无关闭(X)按钮，无底部操作栏
- **设计预期**：① 顶栏左侧有圆形关闭(X)按钮（32×32pt，surface-container 背景 + on-surface 图标）；② 底栏固定全宽"完成 (N)"按钮（高度 50pt，bg 为 primary-container，圆角 xl，白色 16pt bold 文字），按钮文字动态显示已选数量。参考 `P0-05/code.html` L96–L101, L225–L229
- **修复方向**：① 顶栏左侧添加 `.close` 系统图标按钮 dismiss sheet；② 底栏添加 sticky footer，使用 BTButton(.primary) 样式，标题为"完成 (\(selectedCount))"

---

### S-06 缺少多选态编号徽章
- **类别**：产品规格
- **严重程度**：P1（功能缺陷）
- **位置**：训练 > 添加动作 > DrillPickerSheet 卡片选中态
- **截图现状**：右侧"⊕"按钮提示可添加，但无已选状态视觉反馈，无选中编号
- **设计预期**：选中卡片右上角显示圆形编号徽章（20×20pt，bg 为 primary-container，白色 11pt bold 数字），卡片整体加绿色边框和浅绿背景，表达选中顺序（1、2、3…）。参考 `P0-05/code.html` L156–L158
- **修复方向**：维护 `@State var selectedDrills: [DrillID]` 有序数组，选中卡片使用 `.overlay(alignment: .topTrailing)` 叠加编号徽章 + 绿色边框

---

### S-07 列表行缺少等级标签色彩区分
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：训练 > 添加动作 > DrillPickerSheet 各行
- **截图现状**：所有行副标题统一显示"基础功 · 3组 × 15球"文字，无彩色等级标签（L0/L1/L2 等）
- **设计预期**：每张卡片名称下方显示 BTLevelBadge 胶囊标签，配色按 SKILL.md §九 五级配色——L0 绿底白字、L1 蓝底蓝字、L2 琥珀底琥珀字等，帮助用户快速识别难度
- **修复方向**：在卡片名称下方添加 `BTLevelBadge(level:)` 组件，数据来自 Drill model 的 level 字段

---

## 二、TrainingSummaryView（训练完成总结页）

> **整体评估**：结构与设计稿基本对齐——统计卡片 2×2 网格 + 成功率横条 + 训练明细 + 底部操作按钮均已实现，整体还原度约 **75%**。需修复导航栏缺失、细节样式差异。

---

### S-08 缺少"结束训练"返回导航按钮
- **类别**：产品规格 / HIG
- **严重程度**：P1（功能缺陷）
- **位置**：训练 > 训练总结 > 顶部导航栏左侧
- **截图现状**：导航栏仅显示居中"训练总结"标题 + 右侧分享图标，左侧无任何按钮
- **设计预期**：导航栏左侧有"< 结束训练"返回按钮（btPrimary 色 chevron_left + "结束训练"文字），用于放弃保存并返回。参考 `P0-06/code.html` L94–L98
- **修复方向**：在 NavigationStack toolbar 中添加 `.topBarLeading` 按钮，文字"结束训练"，点击后弹出确认 Alert（"放弃本次训练？"）再 dismiss

---

### S-09 统计卡片数字字号与设计预期偏差
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：训练 > 训练总结 > 4 张统计卡片数字
- **截图现状**：统计数字（"0"、"1"、"3"、"0"）视觉上约为 24–26pt，字重为 bold，但看起来未使用 `.rounded` 字体设计
- **设计预期**：设计稿使用 28px extrabold 数字（`P0-06/code.html` L117）。Typography.swift 中已定义 `btStatNumber = Font.system(size: 28, weight: .bold, design: .rounded)`，数字应使用 `.rounded` 设计以呈现圆润数字风格
- **修复方向**：确认数字 Text 使用 `.font(.btStatNumber)` 而非自定义字号，确保 `design: .rounded` 生效

---

### S-10 "总进球"图标颜色与设计不一致
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：训练 > 训练总结 > 总进球统计卡片右上角图标
- **截图现状**：图标为绿色圆环（与其他 3 张卡片图标颜色一致，均为 btPrimary 绿色）
- **设计预期**：总进球图标应使用金黄色（`#F5A623`，对应 btAccent / btBallTarget），与其他绿色图标形成视觉区分。参考 `P0-06/code.html` L152：`text-[#F5A623]`
- **修复方向**：将"总进球"卡片的 SF Symbol 图标颜色改为 `.btAccent`

---

### S-11 缺少"训练心得"区域
- **类别**：产品规格
- **严重程度**：P1（功能缺陷）
- **位置**：训练 > 训练总结 > 训练明细下方
- **截图现状**：训练明细列表下方直接是"保存训练"按钮，无训练心得输入/展示区域
- **设计预期**：在训练明细与底部按钮之间有"训练心得"卡片，含 edit_note 图标 + 标题"训练心得"+ 用户可编辑文字区域（白底 `rounded-2xl` 卡片）。参考 `P0-06/code.html` L307–L316
- **修复方向**：在明细列表下方添加训练心得卡片，支持 `TextEditor` 编辑或 AI 自动生成总结，保存时写入训练记录

---

### S-12 "训练明细"区域缺少"详情"链接
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：训练 > 训练总结 > "训练明细" section 标题行
- **截图现状**："训练明细"标题独立一行，右侧无任何元素
- **设计预期**：标题行右侧有"详情"链接文字（12px medium，`btTextSecondary` 灰色），点击可展开/收起或跳转至完整明细。参考 `P0-06/code.html` L177–L180
- **修复方向**：在 section 标题 HStack 中添加 Spacer + "详情" Button，样式为 `.font(.btCaption)` + `.foregroundStyle(.btTextSecondary)`

---

### S-13 平均成功率进度条背景色偏差
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：训练 > 训练总结 > 平均成功率卡片 > 进度条
- **截图现状**：进度条底色为较浅的灰色，填充色为 btPrimary 绿色（当前值 0% 故无填充）
- **设计预期**：进度条底色应为 `btBGTertiary`（Light: #E5E5EA），填充色为 btPrimary。设计稿使用 `bg-[#F1F5F9]`（偏蓝灰），但应映射到项目 Token `btBGTertiary` 以保证 Dark Mode 适配
- **修复方向**：确认进度条背景使用 `.btBGTertiary` 而非硬编码色值

---

### S-14 统计卡片标签文字样式偏差
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：训练 > 训练总结 > 4 张统计卡片的标签文字（训练时长/完成项目/总组数/总进球）
- **截图现状**：标签文字颜色较深，接近 btText 主色
- **设计预期**：标签文字应使用 `btTextSecondary`（60% 不透明度灰色），与数字形成明确层次对比。设计稿使用 `stat-label { color: rgba(60,60,67,0.6) }` 即对应 btTextSecondary
- **修复方向**：确认标签 Text 使用 `.foregroundStyle(.btTextSecondary)` + `.font(.btFootnote)`

---

## 审查总结

- **截图数量**：2 张（DrillPickerSheet 1 张 + TrainingSummaryView 1 张）
- **发现问题**：14 项（P0: 1 / P1: 6 / P2: 7）
- **总体评价**：
  - **DrillPickerSheet**：当前实现与设计稿存在架构级差距，需要完整重构——从扁平列表改为分类侧栏 + 缩略图网格，补充搜索框定位、关闭/完成按钮、多选编号等核心交互。
  - **TrainingSummaryView**：整体结构还原度较好，统计卡片网格、明细列表、底部按钮组基本到位。需补充"结束训练"导航按钮和"训练心得"区域，并打磨字体 Token、图标颜色等细节。
- **建议下一步**：
  1. **最高优先**：重构 DrillPickerSheet 布局（S-01 ~ S-06），这是核心交互入口
  2. **次优先**：补充 TrainingSummaryView 的"结束训练"导航 + "训练心得"功能（S-08, S-11）
  3. **后续打磨**：修复 Design Token 细节（S-09, S-10, S-12 ~ S-14）

---

## 路由表

| 问题编号 | 路由至 |
|---------|--------|
| S-01 ~ S-07 | `swiftui-developer`（DrillPickerSheet 重构） |
| S-08 | `swiftui-developer`（导航栏） |
| S-09, S-10, S-13, S-14 | `swiftui-developer`（Design Token 修正） |
| S-11 | `swiftui-developer` + `data-engineer`（心得数据模型 + UI） |
| S-12 | `swiftui-developer`（section header） |

## 代码提示

| 问题 | 可能涉及文件 |
|------|-------------|
| S-01 ~ S-07 | `Features/Training/Views/DrillPickerSheet.swift`（或需新建） |
| S-08 ~ S-14 | `Features/Training/Views/TrainingSummaryView.swift` |
| Design Token | `Core/DesignSystem/Colors.swift`, `Typography.swift`, `Spacing.swift` |
| BTLevelBadge | `Core/Components/BTLevelBadge.swift` |
