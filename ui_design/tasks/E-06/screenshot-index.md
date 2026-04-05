# 球迹 (QiuJi) UI 设计 — 最终截图索引

**生成日期**: 2026-04-05
**覆盖范围**: Phase A~E 全部已通过截图

---

## 一、概览

| 模式 | 帧数 | 说明 |
|------|------|------|
| Light Mode — 组件库 | 8 张 | Phase A 设计系统基础组件 |
| Light Mode — 完整页面 | 27 帧 | Phase B~D 全部业务页面 |
| Dark Mode — Stitch 参考帧 | 5 帧 | Phase E-01 训练流程 + 训练计划 |
| Dark Mode — 开发标注文档 | 3 份 | Phase E-02~E-04 覆盖其余页面 |
| **总计** | **40 帧 + 3 份标注** | |

所有截图路径均相对于项目根目录 `/Users/song/projects/14.ui_design/`。

---

## 二、Phase A — 设计系统组件库（8 张）

| # | 任务 ID | 组件 | 截图路径 | 备注 |
|---|---------|------|---------|------|
| 1 | A-01 | Design Token 色板 | `tasks/A-01/stitch_task_01_03/screen.png` | 品牌色锚定 #1A6B3C |
| 2 | A-02 | BTButton 7 种样式 | `tasks/A-02/stitch_task_02_02/screen.png` | 三级层级体系 |
| 3 | A-03 | BTEmptyState + BTDrillCard + BTLevelBadge | `tasks/A-03/stitch_task_03_02/screen.png` | 五级 Badge 配色 |
| 4 | A-04 | BTPremiumLock 两种模式 | `tasks/A-04/stitch_task_04_02/screen.png` | 渐进锁 vs 全遮罩 |
| 5 | A-05 | BTRestTimer + BTFloatingIndicator | `tasks/A-05/stitch_task_05_02/screen.png` | 双环计时 + 浮动胶囊 |
| 6 | A-06 | BTSegmentedTab + BTTogglePillGroup + BTOverflowMenu | `tasks/A-06/stitch_task_06_02/screen.png` | 以 code.html 为准 |
| 7 | A-07 | BTExerciseRow + BTSetInputGrid | `tasks/A-07/stitch_task_07_02/screen.png` | 以 code.html 为准 |
| 8 | A-08 | BTShareCard + BTBilliardTable | `tasks/A-08/stitch_task_08_02/screen.png` | 以 code.html 为准 |

> A-06/A-07/A-08 截图为空或不完整，以 `code.html` 浏览器渲染为最终参考。

---

## 三、Phase B — P0 核心训练流（11 帧）

| # | 任务 ID | 页面 | 截图路径 | 备注 |
|---|---------|------|---------|------|
| 9 | P0-01 | TrainingHomeView（有计划态）| `tasks/P0-01/stitch_task_p0_01_02/screen.png` | 确立导航/Tab/区块模式 |
| 10 | P0-02 | TrainingHomeView（空状态）| `tasks/P0-02/stitch_task_p0_02_02/screen.png` | EmptyState 通用模式 |
| 11 | P0-03 | ActiveTrainingView — 训练总览 | `tasks/P0-03/stitch_task_p0_03_02/screen.png` | 全屏模态 + 毛玻璃顶栏 |
| 12 | P0-04 | ActiveTrainingView — 单项记录 | `tasks/P0-04/stitch_task_p0_04_04/screen.png` | v4 最终版，品牌绿添加钮 |
| 13 | P0-05a | BTRestTimer 弹层 | `tasks/P0-05/stitch_task_p0_05_restTimer/screen.png` | 对齐 A-05 |
| 14 | P0-05b | DrillPickerSheet | `tasks/P0-05/stitch_task_p0_05_DrillPickerSheet/screen.png` | 选择顺序角标 1,2,3… |
| 15 | P0-06a | TrainingSummaryView | `tasks/P0-06/stitch_task_p0_06_trainingsummaryview_02/screen.png` | 2×2+1 统计 + 明细展开 |
| 16 | P0-06b | TrainingShareView | `tasks/P0-06/stitch_task_p0_06_trainingshareview_02/screen.png` | 深色分享卡（无 Dark 变体） |
| 17 | P0-07a | AngleTestView 答题 | `tasks/P0-07/stitch_task_p0_07_angletestview_02/screen.png` | 球台横版 2:1 |
| 18 | P0-07b | AngleTestView 结果 | `tasks/P0-07/stitch_task_p0_07_angletestviewresult_02/screen.png` | 叠加可视化 + 教育提示 |
| 19 | P0-08 | TrainingNoteView | `tasks/P0-08/stitch_task_p0_08_02/screen.png` | 极简书写页 |

---

## 四、Phase C — P1 重要页面（13 帧）

| # | 任务 ID | 页面 | 截图路径 | 备注 |
|---|---------|------|---------|------|
| 20 | P1-01 | DrillListView（默认态）| `tasks/P1-01/stitch_task_p1_01_02/screen.png` | 64pt 缩略图 + Chip |
| 21 | P1-02 | DrillListView（搜索无结果）| `tasks/P1-02/stitch_task_p1_02_02/screen.png` | 浅绿圆底空状态 |
| 22 | P1-03 | DrillDetailView（完整详情）| `tasks/P1-03/stitch_task_p1_03_02/screen.png` | 居中标题 + Hero 球台 |
| 23 | P1-04 | DrillDetailView（Pro 锁定）| `tasks/P1-04/stitch_task_p1_04_02/screen.png` | 金色解锁 CTA |
| 24 | P1-05a | AngleHomeView | `tasks/P1-05/stitch_task_p1_05_02/screen.png` | 三入口枢纽 |
| 25 | P1-05b | ContactPointTableView | `tasks/P1-05/stitch_task_p1_05_contactpointtableview_02/screen.png` | 纯工具对照表 |
| 26 | P1-06 | AngleHistoryView | `tasks/P1-06/stitch_task_p1_06_02/screen.png` | 统计卡片 + 品牌绿 Section |
| 27 | P1-07 | HistoryCalendarView（有数据）| `tasks/P1-07/stitch_task_p1_07_02/screen.png` | 6×7 月历 + 绿底训练日 |
| 28 | P1-08a | HistoryCalendarView（空状态）| `tasks/P1-08/stitch_task_p1_08_historycalendarview_02/screen.png` | 保留日历 + 空列表 |
| 29 | P1-08b | TrainingDetailView（Sheet）| `tasks/P1-08/stitch_task_p1_08_trainingdetailview_02/screen.png` | 统计横排 + 逐组详情 |
| 30 | P1-09 | StatisticsView（有数据）| `tasks/P1-09/stitch_task_p1_09_02/screen.png` | 琥珀/绿双色图表 |
| 31 | P1-10 | StatisticsView（Pro 锁定）| `tasks/P1-10/stitch_task_p1_10_02/screen.png` | 渐变磨砂遮罩 + 金色 CTA |

---

## 五、Phase D — P2 辅助页面（12 帧）

| # | 任务 ID | 页面 | 截图路径 | 备注 |
|---|---------|------|---------|------|
| 32 | P2-01a | PlanListView | `tasks/P2-01/stitch_task_p2_01_planlistview_02/screen.png` | push 子页 + 计划卡 |
| 33 | P2-01b | PlanDetailView | `tasks/P2-01/stitch_task_p2_01_plandetailview/screen.png` | Hero 照片 + Pro CTA |
| 34 | P2-02 | CustomPlanBuilderView | `tasks/P2-02/stitch_task_p2_02_02/screen.png` | 多色球 + 品牌绿底栏 |
| 35 | P2-03a | ProfileView（已登录）| `tasks/P2-03/stitch_task_p2_03_userprofile_02/screen.png` | 多色菜单圆标 |
| 36 | P2-03b | ProfileView（访客）| `tasks/P2-03/stitch_task_p2_03_guestprofile_02/screen.png` | Pro 深色卡 + 金色文案 |
| 37 | P2-04 | OnboardingView | `tasks/P2-04/stitch_task_p2_04_02/screen.png` | 三特性品牌绿图标 |
| 38 | P2-05a | LoginView（Sheet）| `tasks/P2-05/stitch_task_02_05_loginview_02/screen.png` | 三按钮层级 |
| 39 | P2-05b | PhoneLoginView | `tasks/P2-05/stitch_task_02_05_phoneloginview/screen.png` | 药丸验证码输入 |
| 40 | P2-06 | SubscriptionView（付费墙）| `tasks/P2-06/stitch_task_p2_06_02/screen.png` | 全屏深色（无 Dark 变体）|
| 41 | P2-07a | FavoriteDrillsView（有数据）| `tasks/P2-07/stitch_task_p2_07_favoritedrillsview/screen.png` | 纯列表无搜索 |
| 42 | P2-07b | FavoriteDrillsView（空状态）| `tasks/P2-07/stitch_task_p2_07_favoritedrillsviewempty/screen.png` | EmptyState |
| 43 | P2-08 | BTFloatingIndicator 跨 Tab | `tasks/P2-08/stitch_task_p2_08/screen.png` | 动作库 Tab 浮动展示 |

---

## 六、Phase E — Dark Mode（5 帧 + 3 份标注）

### E-01 Stitch 生成参考帧

| # | 帧 | 对应 Light Mode | 截图路径 | 版本 |
|---|------|----------------|---------|------|
| 44 | TrainingHomeView Dark | P0-01 | `tasks/E-01/stitch_task_e_01/screen.png` | v1 |
| 45 | ActiveTraining 总览 Dark | P0-03 | `tasks/E-01/stitch_task_e_01_frame2/screen.png` | v1 |
| 46 | ActiveTraining 记录 Dark | P0-04 | `tasks/E-01/stitch_task_e_01_frame3_02/screen.png` | v2 |
| 47 | TrainingSummary Dark | P0-06a | `tasks/E-01/stitch_task_e_01_frame4_02/screen.png` | v2 |
| 48 | PlanListView Dark | P2-01a | `tasks/E-01/stitch_task_e1_frame5/screen.png` | v1 |

### E-02~E-04 Dark Mode 开发标注文档

| 文档 | 覆盖页面 | 路径 |
|------|---------|------|
| E-02 动作库+角度+收藏 | P1-01/P1-03/P1-05/P0-07/P2-07 | `tasks/E-02/dark-mode-annotations.md` |
| E-03 历史+统计 | P1-07/P1-09/P1-10 | `tasks/E-03/dark-mode-annotations.md` |
| E-04 个人中心+登录 | P2-03/P2-05 | `tasks/E-04/dark-mode-annotations.md` |

### 标准 Token 映射覆盖（无需专门标注）

以下页面使用 `dark-mode-rules.md` DM-001 通用 Token 即可完成 Dark Mode 适配：

- P0-02 TrainingHomeView 空 — 同 P0-01 框架 + BTEmptyState
- P0-05 BTRestTimer + Picker — 双环色标准映射
- P0-08 TrainingNoteView — 纯输入页面
- P1-02 DrillListView 空 — 同 P1-01 框架
- P1-04 DrillDetailView Pro 锁 — E-02 DrillDetail + E-03 Pro 锁组合
- P1-06 AngleHistoryView — 标准绿/琥珀色映射
- P1-08 CalendarView 空 + Detail — E-03 日历 + Sheet 标准映射
- P2-01b PlanDetailView — 标准 Token 映射
- P2-02 CustomPlanBuilder — 表单标准映射
- P2-08 BTFloatingIndicator — 品牌绿标准映射

### 明确排除 Dark Mode 的页面（DM-009）

- P2-04 OnboardingView — 品牌首屏保持浅色
- P2-06 SubscriptionView — 自身已是深色设计（#111111）
- P0-06b TrainingShareView — 分享卡自身已是深色主题

---

## 七、一致性审核报告索引

| Phase | 审核日期 | 报告路径 |
|-------|---------|---------|
| A | 2026-04-03 | `tasks/A-REVIEW/consistency-review.md` |
| B | 2026-04-04 | `tasks/B-REVIEW/consistency-review.md` |
| C | 2026-04-05 | `tasks/C-REVIEW/consistency-review.md` |
| D | 2026-04-05 | `tasks/D-REVIEW/consistency-review.md` |
| E (终审) | 2026-04-05 | `tasks/E-05/global-final-review.md` |
