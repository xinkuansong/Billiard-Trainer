# R1 — UI 逐页审查（Page-by-Page UI Review）

> **目标**：逐页对照设计稿（screen.png + code.html + ref-screenshots），产出每个页面的偏差报告。本阶段**只审查、不修代码**。
> **前置条件**：R-UI 对齐已完成；Phase 0 字体 Token 批量替换已完成。
> **角色**：UI Reviewer（主）— 按 `57-ui-reviewer.mdc` 7 维度审查协议执行
> **产出物**：每个审查任务对应一份 `tasks/ui-reviews/UR-YYYYMMDD-<页面>.md`
> **后续**：审查报告汇总后生成 R2 优化任务列表（Phase 级），再逐个修复。

---

## 审查流程

每个审查任务按以下步骤执行：

1. **打开设计参考**：先看 ref-screenshots（整体印象），再看 stitch screen.png（精确布局），最后看 code.html（间距/字号/颜色数值）
2. **打开 Swift 源码**：对照代码实际实现
3. **逐维度检查**（7 维度见下方）
4. **输出偏差报告**：写入 `tasks/ui-reviews/UR-YYYYMMDD-<页面>.md`，每条偏差按报告模板记录

## 7 维度检查清单（每个审查任务通用）

| # | 维度 | 核心检查点 |
|---|------|-----------|
| 1 | **Design Token** | 颜色/字体/间距/圆角是否使用 Token，无硬编码 hex/pt |
| 2 | **布局** | 对齐一致、无截断溢出、Safe Area 合规、滚动边界、固定元素位置 |
| 3 | **Dark Mode** | 阴影条件化、卡片边框、Chip 选中态、对比度充足 |
| 4 | **产品规格** | 功能与 docs/05 一致、空状态/加载态/错误态覆盖、Freemium 门控 |
| 5 | **HIG** | 触摸目标>=44pt、系统导航、Large Title、系统弹窗 |
| 6 | **无障碍** | 对比度 WCAG AA（4.5:1 / 3:1）、Dynamic Type 支持 |
| 7 | **视觉打磨** | 阴影克制、圆角层级一致、组件复用、列表行高 |

## 偏差报告模板

每条偏差按以下格式记录：

```markdown
### U-NN <一句话标题>
- **类别**：Design Token / 布局 / Dark Mode / 产品规格 / HIG / 无障碍 / 视觉打磨
- **严重程度**：P0（必须修复）/ P1（应该修复）/ P2（建议改进）
- **位置**：<Tab> > <页面> > <组件或区域>
- **现状**：<代码中的实际表现或截图中的问题>
- **预期**：<设计稿/规范要求，引用具体 Token 或文档节>
- **修复方向**：<建议的代码修改方向>
- **涉及文件**：<Swift 文件路径>
```

---

## T-R1-01 TrainingHomeView 审查

- **负责角色**：UI Reviewer
- **审查对象**：`QiuJi/Features/Training/Views/TrainingHomeView.swift`（490 行）
- **设计参考（stitch）**：
  - 有计划态：`ui_design/tasks/P0-01/stitch_task_p0_01_02/screen.png` + `code.html`
  - 空状态：`ui_design/tasks/P0-02/stitch_task_p0_02_02/screen.png` + `code.html`
- **设计参考（ref-screenshots）**：
  - `ui_design/ref-screenshots/01-training-home/01-home-with-plan.png`
  - `ui_design/ref-screenshots/01-training-home/02-home-scrolled.png`
  - `ui_design/ref-screenshots/01-training-home/03-home-with-plan-detail.png`
  - `ui_design/ref-screenshots/01-training-home/04-home-scrolled-plans.png`
- **Dark Mode 参考**：`ui_design/tasks/E-01/stitch_task_e_01/screen.png` + `code.html`
- **规范参考**：`tasks/UI-IMPLEMENTATION-SPEC.md` § 四 Tab 1、§ 七 训练流程决策

### DoD

- [ ] 偏差报告输出至 `tasks/ui-reviews/UR-YYYYMMDD-TrainingHome.md`
- [ ] 7 维度全部检查完毕
- [ ] 偏差按 P0/P1/P2 分级

---

## T-R1-02 ActiveTrainingView 审查

- **负责角色**：UI Reviewer
- **审查对象**：`QiuJi/Features/Training/Views/ActiveTrainingView.swift`（671 行）
- **设计参考（stitch）**：
  - 总览：`ui_design/tasks/P0-03/stitch_task_p0_03_02/screen.png` + `code.html`
  - 单项记录：`ui_design/tasks/P0-04/stitch_task_p0_04_04/screen.png` + `code.html`
- **设计参考（ref-screenshots）**：
  - `ui_design/ref-screenshots/02-training-active/01-plan-day-overview.png`
  - `ui_design/ref-screenshots/02-training-active/02-pre-training-exercises.png`
  - `ui_design/ref-screenshots/02-training-active/03-active-main.png`
  - `ui_design/ref-screenshots/02-training-active/04-active-set-progress.png`
  - `ui_design/ref-screenshots/02-training-active/05-active-rest-timer.png`
  - `ui_design/ref-screenshots/02-training-active/06-active-end-confirm.png`
- **Dark Mode 参考**：
  - `ui_design/tasks/E-01/stitch_task_e_01_frame2/screen.png` + `code.html`
  - `ui_design/tasks/E-01/stitch_task_e_01_frame3_02/screen.png` + `code.html`
- **规范参考**：`tasks/UI-IMPLEMENTATION-SPEC.md` § 四 Tab 1、§ 七 训练流程决策

### DoD

- [ ] 偏差报告输出至 `tasks/ui-reviews/UR-YYYYMMDD-ActiveTraining.md`
- [ ] 含 DrillRecordView、DrillPickerSheet、BTRestTimer 弹层的子审查
- [ ] 7 维度全部检查完毕

---

## T-R1-03 TrainingSummaryView + TrainingShareView 审查

- **负责角色**：UI Reviewer
- **审查对象**：
  - `QiuJi/Features/Training/Views/TrainingSummaryView.swift`（392 行）
  - `QiuJi/Features/Training/Views/TrainingShareView.swift`（253 行）
  - `QiuJi/Core/Components/BTShareCard.swift`（322 行）
- **设计参考（stitch）**：
  - 总结页：`ui_design/tasks/P0-06/stitch_task_p0_06_trainingsummaryview_02/screen.png` + `code.html`
  - 分享页：`ui_design/tasks/P0-06/stitch_task_p0_06_trainingshareview_02/screen.png` + `code.html`
- **设计参考（ref-screenshots）**：
  - `ui_design/ref-screenshots/02-training-active/07-training-summary.png`
  - `ui_design/ref-screenshots/02-training-active/08-training-summary-scrolled.png`
  - `ui_design/ref-screenshots/02-training-active/09-training-note.png`
- **Dark Mode 参考**：`ui_design/tasks/E-01/stitch_task_e_01_frame4_02/screen.png` + `code.html`

### DoD

- [ ] 偏差报告输出至 `tasks/ui-reviews/UR-YYYYMMDD-TrainingSummary.md`
- [ ] 含 TrainingNoteView 子审查
- [ ] 7 维度全部检查完毕

---

## T-R1-04 PlanListView + PlanDetailView + CustomPlanBuilderView 审查

- **负责角色**：UI Reviewer
- **审查对象**：
  - `QiuJi/Features/Training/Views/PlanListView.swift`（395 行）
  - `QiuJi/Features/Training/Views/PlanDetailView.swift`（375 行）
  - `QiuJi/Features/Training/Views/CustomPlanBuilderView.swift`（434 行）
- **设计参考（stitch）**：
  - 计划列表：`ui_design/tasks/P2-01/stitch_task_p2_01_planlistview_02/screen.png` + `code.html`
  - 计划详情：`ui_design/tasks/P2-01/stitch_task_p2_01_plandetailview/screen.png` + `code.html`
  - 自定义计划：`ui_design/tasks/P2-02/stitch_task_p2_02_02/screen.png` + `code.html`
- **设计参考（ref-screenshots）**：
  - `ui_design/ref-screenshots/03-training-plan/01-custom-plan-edit.png`
  - `ui_design/ref-screenshots/03-training-plan/02-custom-plan-edit-2.png`
  - `ui_design/ref-screenshots/03-training-plan/03-custom-plan-empty.png`
  - `ui_design/ref-screenshots/03-training-plan/04-custom-plan-pick.png`
  - `ui_design/ref-screenshots/03-training-plan/05-custom-plan-after-pick.png`
- **Dark Mode 参考**：`ui_design/tasks/E-01/stitch_task_e1_frame5/screen.png` + `code.html`

### DoD

- [ ] 偏差报告输出至 `tasks/ui-reviews/UR-YYYYMMDD-Plans.md`
- [ ] 7 维度全部检查完毕

---

## T-R1-05 DrillListView + DrillDetailView 审查

- **负责角色**：UI Reviewer
- **审查对象**：
  - `QiuJi/Features/DrillLibrary/Views/DrillListView.swift`（217 行）
  - `QiuJi/Features/DrillLibrary/Views/DrillDetailView.swift`（333 行）
- **设计参考（stitch）**：
  - 列表默认：`ui_design/tasks/P1-01/stitch_task_p1_01_02/screen.png` + `code.html`
  - 搜索无结果：`ui_design/tasks/P1-02/stitch_task_p1_02_02/screen.png` + `code.html`
  - 详情完整：`ui_design/tasks/P1-03/stitch_task_p1_03_02/screen.png` + `code.html`
  - 详情 Pro 锁：`ui_design/tasks/P1-04/stitch_task_p1_04_02/screen.png` + `code.html`
- **设计参考（ref-screenshots）**：
  - `ui_design/ref-screenshots/04-exercise-library/01-list-default.png`
  - `ui_design/ref-screenshots/04-exercise-library/02-list-search-active.png`
  - `ui_design/ref-screenshots/04-exercise-library/03-list-filtered.png`
  - `ui_design/ref-screenshots/04-exercise-library/04-list-no-result.png`
  - `ui_design/ref-screenshots/04-exercise-library/05-detail-top.png`
  - `ui_design/ref-screenshots/04-exercise-library/06-detail-mid.png`
  - `ui_design/ref-screenshots/04-exercise-library/07-detail-bottom.png`
  - `ui_design/ref-screenshots/04-exercise-library/08-detail-tutorial.png`
- **设计参考（ref-screenshots 额外）**：
  - `ui_design/ref-screenshots/04-exercise-library/09-detail-video-list.png`
  - `ui_design/ref-screenshots/04-exercise-library/10-detail-video-human.png`
  - `ui_design/ref-screenshots/04-exercise-library/11-detail-video-gif.png`
- **规范参考**：`tasks/UI-IMPLEMENTATION-SPEC.md` § 四 Tab 2、§ 七 动作库决策

### DoD

- [ ] 偏差报告输出至 `tasks/ui-reviews/UR-YYYYMMDD-DrillLibrary.md`
- [ ] 含 FavoriteDrillsView 子审查（stitch: `P2-07`）
- [ ] 7 维度全部检查完毕

---

## T-R1-06 AngleHomeView + AngleTestView + ContactPointTableView + AngleHistoryView 审查

- **负责角色**：UI Reviewer
- **审查对象**：
  - `QiuJi/Features/AngleTraining/Views/AngleHomeView.swift`（133 行）
  - `QiuJi/Features/AngleTraining/Views/AngleTestView.swift`（282 行）
  - `QiuJi/Features/AngleTraining/Views/ContactPointTableView.swift`（235 行）
  - `QiuJi/Features/AngleTraining/Views/AngleHistoryView.swift`（309 行）
  - `QiuJi/Features/AngleTraining/Views/BTAngleTestTable.swift`（132 行）
- **设计参考（stitch）**：
  - 角度首页：`ui_design/tasks/P1-05/stitch_task_p1_05_02/screen.png` + `code.html`
  - 对照表：`ui_design/tasks/P1-05/stitch_task_p1_05_contactpointtableview_02/screen.png` + `code.html`
  - 答题：`ui_design/tasks/P0-07/stitch_task_p0_07_angletestview_02/screen.png` + `code.html`
  - 结果：`ui_design/tasks/P0-07/stitch_task_p0_07_angletestviewresult_02/screen.png` + `code.html`
  - 历史：`ui_design/tasks/P1-06/stitch_task_p1_06_02/screen.png` + `code.html`

### DoD

- [ ] 偏差报告输出至 `tasks/ui-reviews/UR-YYYYMMDD-AngleTraining.md`
- [ ] 7 维度全部检查完毕

---

## T-R1-07 HistoryCalendarView + TrainingDetailView + StatisticsView 审查

- **负责角色**：UI Reviewer
- **审查对象**：
  - `QiuJi/Features/History/Views/HistoryCalendarView.swift`（316 行）
  - `QiuJi/Features/History/Views/TrainingDetailView.swift`（321 行）
  - `QiuJi/Features/History/Views/StatisticsView.swift`（457 行）
- **设计参考（stitch）**：
  - 日历有数据：`ui_design/tasks/P1-07/stitch_task_p1_07_02/screen.png` + `code.html`
  - 日历空+详情：`ui_design/tasks/P1-08/stitch_task_p1_08_historycalendarview_02/screen.png` + `code.html`
  - 训练详情：`ui_design/tasks/P1-08/stitch_task_p1_08_trainingdetailview_02/screen.png` + `code.html`
  - 统计有数据：`ui_design/tasks/P1-09/stitch_task_p1_09_02/screen.png` + `code.html`
  - 统计 Pro 锁：`ui_design/tasks/P1-10/stitch_task_p1_10_02/screen.png` + `code.html`
- **设计参考（ref-screenshots）**：
  - `ui_design/ref-screenshots/05-history-calendar/01-calendar-active.png`
  - `ui_design/ref-screenshots/05-history-calendar/02-calendar-empty.png`
  - `ui_design/ref-screenshots/05-history-calendar/03-calendar-day-list.png`
  - `ui_design/ref-screenshots/05-history-calendar/04-training-detail.png`
  - `ui_design/ref-screenshots/05-history-calendar/05-training-detail-more.png`
  - `ui_design/ref-screenshots/05-history-calendar/06-calendar-month.png`
  - `ui_design/ref-screenshots/05-history-calendar/07-calendar-year.png`
  - `ui_design/ref-screenshots/06-statistics/01-stats-weekly.png`
  - `ui_design/ref-screenshots/06-statistics/02-stats-monthly.png`
  - `ui_design/ref-screenshots/06-statistics/03-stats-yearly.png`
  - `ui_design/ref-screenshots/06-statistics/04-stats-bar-chart.png`
  - `ui_design/ref-screenshots/06-statistics/05-stats-bar-chart-2.png`
  - `ui_design/ref-screenshots/06-statistics/06-stats-bar-chart-3.png`
  - `ui_design/ref-screenshots/06-statistics/07-stats-personal-record.png`
  - `ui_design/ref-screenshots/06-statistics/08-trend-chart.png`
- **规范参考**：`tasks/UI-IMPLEMENTATION-SPEC.md` § 四 Tab 4、§ 七 历史与统计决策

### DoD

- [ ] 偏差报告输出至 `tasks/ui-reviews/UR-YYYYMMDD-History.md`
- [ ] 7 维度全部检查完毕

---

## T-R1-08 ProfileView + SettingsView 审查

- **负责角色**：UI Reviewer
- **审查对象**：
  - `QiuJi/Features/Profile/Views/ProfileView.swift`（530 行）
  - `QiuJi/Features/Profile/Views/SettingsView.swift`（171 行）
  - `QiuJi/Features/Profile/Views/FavoriteDrillsView.swift`（78 行）
- **设计参考（stitch）**：
  - 已登录：`ui_design/tasks/P2-03/stitch_task_p2_03_userprofile_02/screen.png` + `code.html`
  - 访客：`ui_design/tasks/P2-03/stitch_task_p2_03_guestprofile_02/screen.png` + `code.html`
- **设计参考（ref-screenshots）**：
  - `ui_design/ref-screenshots/07-profile/01-profile-logged-in.png`
  - `ui_design/ref-screenshots/07-profile/02-profile-guest.png`
  - `ui_design/ref-screenshots/07-profile/03-profile-menu.png`
  - `ui_design/ref-screenshots/07-profile/04-profile-change-info.png`
  - `ui_design/ref-screenshots/07-profile/05-settings-1.png`
  - `ui_design/ref-screenshots/07-profile/06-settings-2.png`
  - `ui_design/ref-screenshots/07-profile/06-settings-3.png`
- **规范参考**：`tasks/UI-IMPLEMENTATION-SPEC.md` § 四 Tab 5

### DoD

- [ ] 偏差报告输出至 `tasks/ui-reviews/UR-YYYYMMDD-Profile.md`
- [ ] 7 维度全部检查完毕

---

## T-R1-09 OnboardingView + LoginView + PhoneLoginView 审查

- **负责角色**：UI Reviewer
- **审查对象**：
  - `QiuJi/Features/Profile/Views/OnboardingView.swift`（227 行）
  - `QiuJi/Features/Profile/Views/LoginView.swift`（194 行）
  - `QiuJi/Features/Profile/Views/PhoneLoginView.swift`（201 行）
- **设计参考（stitch）**：
  - 引导页：`ui_design/tasks/P2-04/stitch_task_p2_04_02/screen.png` + `code.html`
  - 登录页：`ui_design/tasks/P2-05/stitch_task_02_05_loginview_02/screen.png` + `code.html`
  - 手机登录：`ui_design/tasks/P2-05/stitch_task_02_05_phoneloginview/screen.png` + `code.html`
- **设计参考（ref-screenshots）**：
  - `ui_design/ref-screenshots/08-onboarding-login/01-onboarding-1.png`
  - `ui_design/ref-screenshots/08-onboarding-login/02-onboarding-2.png`
  - `ui_design/ref-screenshots/08-onboarding-login/03-login-in-options.png`
  - `ui_design/ref-screenshots/08-onboarding-login/04-phone-wechat-login.png`
- **规范参考**：`tasks/UI-IMPLEMENTATION-SPEC.md` § 四 Tab 5、§ 六 Dark Mode（OnboardingView 排除）

### DoD

- [ ] 偏差报告输出至 `tasks/ui-reviews/UR-YYYYMMDD-Onboarding.md`
- [ ] OnboardingView 确认 `.preferredColorScheme(.light)` 强制浅色
- [ ] 7 维度全部检查完毕

---

## T-R1-10 SubscriptionView 审查

- **负责角色**：UI Reviewer
- **审查对象**：`QiuJi/Features/Profile/Views/SubscriptionView.swift`（373 行）
- **设计参考（stitch）**：
  - `ui_design/tasks/P2-06/stitch_task_p2_06_02/screen.png` + `code.html`
- **设计参考（ref-screenshots）**：
  - `ui_design/ref-screenshots/09-premium-paywall/01-premium-lock.png`
  - `ui_design/ref-screenshots/09-premium-paywall/02-premium-lock-2.png`
  - `ui_design/ref-screenshots/09-premium-paywall/03-paywall.png`
  - `ui_design/ref-screenshots/09-premium-paywall/04-paywall-selected.png`
  - `ui_design/ref-screenshots/09-premium-paywall/05-paywall-selected-2.png`
- **规范参考**：`tasks/UI-IMPLEMENTATION-SPEC.md` § 四 Tab 5、§ 六 Dark Mode（SubscriptionView 排除，自身深色 #111111）

### DoD

- [ ] 偏差报告输出至 `tasks/ui-reviews/UR-YYYYMMDD-Subscription.md`
- [ ] 7 维度全部检查完毕

---

## T-R1-11 全局 + 组件审查

- **负责角色**：UI Reviewer
- **审查对象**：
  - `QiuJi/App/MainTabView.swift`
  - `QiuJi/App/AppRouter.swift`
  - `QiuJi/Core/Components/` 下全部 15 个 BT* 组件
- **设计参考（stitch）**：
  - 组件：`ui_design/tasks/A-01` ~ `A-08` 各 stitch 目录
  - 全局浮动指示器：`ui_design/tasks/P2-08/stitch_task_p2_08/screen.png` + `code.html`
- **设计参考（ref-screenshots）**：
  - `ui_design/ref-screenshots/00-global/01-app-overview.png`
  - `ui_design/ref-screenshots/00-global/02-tab1-selected.png` ~ `06-nav-push-detail.png`
- **Dark Mode 参考**：`ui_design/tasks/E-01/` 全部 5 帧 + `E-02` ~ `E-04` 标注文档
- **规范参考**：`tasks/UI-IMPLEMENTATION-SPEC.md` § 二 组件 API、§ 五 已知偏差 14 项、§ 六 Dark Mode 全局规则

### DoD

- [ ] 偏差报告输出至 `tasks/ui-reviews/UR-YYYYMMDD-Global.md`
- [ ] Tab 栏图标/文字/选中色检查
- [ ] 15 个 BT* 组件逐个对照 API 规范
- [ ] 14 项已知偏差逐条确认是否已修正
- [ ] Dark Mode 全局 5 条规则逐条验证
- [ ] 7 维度全部检查完毕

---

## 审查完成后

1. 所有 `tasks/ui-reviews/UR-*.md` 汇总，统计 P0/P1/P2 数量
2. 基于偏差报告生成 `tasks/phases/R2-ui-fix.md`（优化任务列表），每条偏差对应一个修复任务
3. 更新 `tasks/PROGRESS.md` 记录 R1 完成状态
