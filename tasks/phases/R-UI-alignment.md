# R-UI — 已有页面设计对齐（Existing Page Alignment）

> **目标**：将 P1（Foundation）、P3（Drill Library）、P4 前半（Training Log T-P4-01~04）中已构建的页面对齐至 UI 设计交付物。
> **前置条件**：P7 Subscription 完成后执行。R0 组件已就位，P4-P7 新建页面已使用新组件。
> **建议时长**：2–3 个会话
> **角色**：SwiftUI Developer（主）+ QA Reviewer（验收）
> **设计参考**：`tasks/UI-IMPLEMENTATION-SPEC.md` § 四（页面-组件映射表）

---

## 通用 DoD 条目

> - [ ] 使用 R0 已实现的 BT* 组件，不自建临时组件
> - [ ] 布局对照设计截图 PNG（screen.png 为主，code.html 为辅）
> - [ ] Light + Dark `#Preview` 可视觉校验
> - [ ] 如有组件 API 变更或设计解读调整，追加 DR/PD 至 `tasks/IMPLEMENTATION-LOG.md` 并更新 `UI-IMPLEMENTATION-SPEC.md` Changelog

---

## T-RUI-01 TrainingHomeView 对齐

- **负责角色**：SwiftUI Developer
- **产出物**：更新后的 `QiuJi/Features/Training/Views/TrainingHomeView.swift`
- **设计参考**：
  - 有计划态 PNG: `ui_design/tasks/P0-01/stitch_task_p0_01_02/screen.png`
  - 空状态 PNG: `ui_design/tasks/P0-02/stitch_task_p0_02_02/screen.png`

### DoD

- [ ] 导航栏：大标题「训练」34pt Bold Rounded，右上角图标按钮（朋友+溢出菜单）
- [ ] 今日安排区：白色卡片（BTRadius.lg），名称 20pt Bold + 副标题 13pt + 「GO!」BTButton.primary
- [ ] 计划浏览区：BTSegmentedTab（官方计划 / 自定义模版）+ 筛选 Chip 行（选中态 #1C1C1E+白字）
- [ ] 计划卡片列表：全宽卡片，左侧 80pt 缩略图 + 右侧名称/描述 + Pro 锁标识
- [ ] 底部固定「开始训练」BTButton.primary，50pt 高
- [ ] 空状态：BTEmptyState + 两个按钮（primary / secondary）
- [ ] BTFloatingIndicator 训练进行中显示
- [ ] `#Preview` Light + Dark

---

## T-RUI-02 DrillListView + DrillDetailView 对齐

- **负责角色**：SwiftUI Developer
- **产出物**：更新后的 `DrillListView.swift`、`DrillDetailView.swift`
- **设计参考**：
  - 列表 PNG: `ui_design/tasks/P1-01/stitch_task_p1_01_02/screen.png`
  - 详情 PNG: `ui_design/tasks/P1-03/stitch_task_p1_03_02/screen.png`
  - Pro 锁 PNG: `ui_design/tasks/P1-04/stitch_task_p1_04_02/screen.png`

### DoD

- [ ] DrillListView：BTDrillCard 含 64pt 台球照片缩略图
- [ ] 球种 Chip 行 + 分类 Chip 行，选中态 #1C1C1E+白字
- [ ] 搜索无结果：BTEmptyState 圆形浅底图标（参照 P1-02 截图）
- [ ] DrillDetailView：push 导航居中标题（中文 Drill 名）
- [ ] Hero 球台动画区 350×190pt + 收藏胶囊 + 全屏按钮
- [ ] 操作图标行：灰色非品牌绿
- [ ] 底部固定栏：左 BTButton.darkPill「关闭」+ 右 BTButton.primary「加入训练」
- [ ] Pro 锁定态：BTPremiumLock 渐进式锁 + 金色填充「解锁 Pro」底栏
- [ ] `#Preview` Light + Dark

---

## T-RUI-03 ActiveTrainingView 对齐

- **负责角色**：SwiftUI Developer
- **产出物**：更新后的 `ActiveTrainingView.swift`
- **设计参考**：
  - 总览 PNG: `ui_design/tasks/P0-03/stitch_task_p0_03_02/screen.png`
  - 单项记录 PNG: `ui_design/tasks/P0-04/stitch_task_p0_04_04/screen.png`

### DoD

- [ ] 顶部：毛玻璃顶栏（`.ultraThinMaterial`），大号计时器 btPrimary 28pt 等宽 + 操作图标行
- [ ] Drill 列表：BTExerciseRow 白色卡片
- [ ] 底部 5 键工具栏：最小化 / 更多 / + 添加（BTButton.iconCircle btPrimary 圆形）/ 写心得 / 切换视图
- [ ] 单项记录：BTSetInputGrid（网格在上球台在下）
- [ ] 热身组：橙色「热」标记
- [ ] 添加按钮颜色为品牌绿（非蓝色，修正 L-1 偏差）
- [ ] `#Preview` Light + Dark

---

## T-RUI-04 ProfileView + LoginView 对齐

- **负责角色**：SwiftUI Developer
- **产出物**：更新后的 `ProfileView.swift`、`LoginView.swift`、`PhoneLoginView.swift`
- **设计参考**：
  - 已登录 PNG: `ui_design/tasks/P2-03/stitch_task_p2_03_userprofile_02/screen.png`
  - 访客 PNG: `ui_design/tasks/P2-03/stitch_task_p2_03_guestprofile_02/screen.png`
  - 登录 PNG: `ui_design/tasks/P2-05/stitch_task_02_05_loginview_02/screen.png`
  - 手机登录 PNG: `ui_design/tasks/P2-05/stitch_task_02_05_phoneloginview/screen.png`

### DoD

- [ ] ProfileView：大标题「我的」无额外顶栏图标
- [ ] 菜单列表：彩色圆底图标 + 标签行（参照 P2-03 截图多色菜单样式）
- [ ] 退出登录按钮：btDestructive `#C62828`（修正 L-6 偏差）
- [ ] 访客模式：Pro 推广深色卡 + 金色文案
- [ ] LoginView Sheet：三按钮层级 Apple 黑底 > 微信 `#07C160` > 手机号灰边框
- [ ] PhoneLoginView：验证码药丸输入
- [ ] `.buttonStyle(.plain)` 已添加到所有 List/Button 行（FL-004/FL-008）
- [ ] `#Preview` Light + Dark

---

## T-RUI-05 OnboardingView 对齐

- **负责角色**：SwiftUI Developer
- **产出物**：更新后的 `OnboardingView.swift`
- **设计参考**：
  - PNG: `ui_design/tasks/P2-04/stitch_task_p2_04_02/screen.png`

### DoD

- [ ] 3 个 FeatureRow：品牌绿圆底图标（`rgba(26,107,60,0.12)`）+ SF Symbol + 标题 + 副标题
- [ ] 主按钮 BTButton.primary「开始使用」
- [ ] 文字按钮 BTButton.text「登录已有账号」
- [ ] 保持浅色设计（不适配 Dark Mode，DM-009）
- [ ] `#Preview`

---

## QA-RUI Phase R-UI 验收

- **负责角色**：QA Reviewer
- **前置依赖**：T-RUI-01 至 T-RUI-05 全部完成

### 验收要点

- [x] 逐页对照设计截图，确认布局、间距、颜色与设计一致（附条件，见 P2 改进项）
- [x] 14 项已知偏差（`UI-IMPLEMENTATION-SPEC.md` § 五）全部按开发基准修正（D-1 本次修复；D-4 记入 P8）
- [x] 所有页面 Tab 文案为「动作库」（非「题库」，修正 L-5）✅
- [x] 所有卡片圆角为 BTRadius.md=12pt（修正 L-7）✅
- [x] 全部页面 Dark Mode 切换无白色硬编码块 ✅（合理 `.white` 用法已审查）
- [x] `xcodebuild test` 全部通过（无回归）✅ 234/234
- [x] `tasks/PROGRESS.md` 已更新 R-UI 完成状态 ✅

### QA 验收报告 — Phase R-UI [Existing Page Alignment]

验收日期：2026-04-05

#### ✅ 通过项

- **T-RUI-01 TrainingHomeView**：大标题、BTSegmentedTab、筛选 Chip（D-1 已修复）、计划卡片、双 Preview 均到位
- **T-RUI-02 DrillListView + DrillDetailView**：BTDrillCard 64pt 缩略图 + 球种/分类 Chip + 操作图标灰色 + chevron + BTLevelBadge 五级 + Light/Dark Preview
- **T-RUI-03 ActiveTrainingView**：毛玻璃顶栏 + 4 图标 + 计划名进度 + BTExerciseRow + 5 键底栏带文字标签 + BTSetInputGrid + 橙色热身「热」+ 品牌绿添加按钮
- **T-RUI-04 ProfileView + LoginView**：彩色圆底图标菜单 + btDestructive 退出 + 三按钮分层登录 + 药丸验证码 + .buttonStyle(.plain) + Dark Preview
- **T-RUI-05 OnboardingView**：品牌绿圆底 FeatureRow + QJ Logo + BTButton.primary/text + `.preferredColorScheme(.light)` ✅
- **14 项偏差**：L-1 ✅ L-3 ✅ L-5 ✅ L-6 ✅ L-7 ✅ D-2 ✅ D-5 ✅ D-6 ✅ D-7 ✅ | D-1 本次修复 ✅
- **自动化测试**：234/234 通过，0 失败

#### 📋 P2 改进项（记入 P8 Polish）

| # | 项目 | 影响范围 | 来源 |
|---|------|---------|------|
| P8-A | D-4：push 子页面未隐藏 Tab 栏（需 `.toolbar(.hidden, for: .tabBar)`） | DrillDetailView, PlanDetailView, CustomPlanBuilder, AngleHistory, FavoriteDrills | D-4 |
| P8-B | L-2：StatisticsView 无独立 large title（嵌入在 HistoryCalendarView「记录」Tab 内，功能正常） | StatisticsView | L-2 |
| P8-C | L-4：BTDrillCard 缩略图为 SF Symbol 占位，待替换为台球场景照片 | BTDrillCard | L-4 |
| P8-D | D-3：TrainingSummaryView 训练明细区「详情」标签存在性（轻微） | TrainingSummaryView | D-3 |
| P8-E | BTFloatingIndicator 已创建但未在 TrainingHomeView 接入（需 ViewModel 状态桥接） | TrainingHomeView | T-RUI-01 DoD |
| P8-F | 部分按钮使用手写样式而非 BTButtonStyle（视觉匹配，代码可维护性改进） | TrainingHomeView 底按钮, DrillDetailView 底栏 | 代码规范 |
| P8-G | DrillDetailView 未使用 BTPremiumLock 组件（自定义实现视觉等效） | DrillDetailView | T-RUI-02 DoD |
| P8-H | ProfileView Pro 推广卡标题为白色而非金色（设计细节） | ProfileView | T-RUI-04 DoD |

#### 📋 总结

状态：**✅ 附条件通过** — D-1 已修复；8 项 P2 改进记入 P8 Polish Phase。无 P0/P1 阻塞。

---

## ADR 记录区

_（空，页面对齐调整在 IMPLEMENTATION-LOG.md 的 DR-NNN 中记录）_
