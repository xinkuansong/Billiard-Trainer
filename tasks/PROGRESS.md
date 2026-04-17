# 开发进度（PROGRESS）

> Orchestrator 每次会话开始时读取本文件，结束时更新。
> 另须读取 `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog（若存在）。

---

## 任务状态（四态）

| 符号 | 含义 | 使用说明 |
|------|------|----------|
| ⏳ | 待开始 | 尚未开工 |
| 🔄 | 进行中 | 附 DoD 进度，例：`🔄 进行中（DoD 2/5）`；会话可能中断时**必须**写入，便于恢复 |
| ⚠️ | 返工 | 附 `见 FL-xxx`，对应 [`tasks/IMPLEMENTATION-LOG.md`](IMPLEMENTATION-LOG.md) 条目；修复后改回 ⏳ 或 🔄 |
| ✅ | 已完成 | Phase 任务卡 DoD 全部满足 |

---

## 当前状态

- **当前 Phase**：**P9 Aiming Feature Expansion** 🔄 进行中（DoD 11/14）+ **P8** 🔄（人工任务剩余）
- **当前激活角色**：QA Reviewer（P9 验收）
- **整体进度**：8 / 11 Phases 完成（R0 ✅ | P2 ✅ 附条件 | P4 ✅ 附条件 | P5 ✅ | P6 ✅ | P7 ✅ | R-UI ✅ 附条件 | R1 ✅）+ P8 🔄 + P9 🔄
- **UI 设计交付物**：44/44 任务完成，40 帧 Light + 5 帧 Dark + 3 份标注已就绪（见 `ui_design/final-report.md`）

---

## R0 Design System Upgrade — ✅ 已完成

> **前置**：UI 设计全部完成。P4 暂停于 T-P4-04。详见 `tasks/phases/R0-design-system.md`。

| 任务 | 状态 |
|------|------|
| T-R0-01 创建 UI-IMPLEMENTATION-SPEC.md | ✅ 已完成（2026-04-05）|
| T-R0-02 Token 值审计 | ✅ 已完成（2026-04-05）|
| T-R0-03 BTButton 补全 7 种样式 | ✅ 已完成（2026-04-05）|
| T-R0-04 新建组件 Batch 1（导航/布局） | ✅ 已完成（2026-04-05）|
| T-R0-05 新建组件 Batch 2（训练） | ✅ 已完成（2026-04-05）|
| T-R0-06 新建组件 Batch 3（反馈/分享） | ✅ 已完成（2026-04-05）|
| T-R0-07 校验与更新已有组件 | ✅ 已完成（2026-04-05）|
| QA-R0 Phase R0 验收 | ✅ 附条件通过（2026-04-05）— 3 项 P2 改进记入下一迭代 |

---

## P1 Foundation — 部分完成（阻塞项已推迟）

| 任务 | 状态 |
|------|------|
| T-P1-01 Xcode 项目初始化 | ✅ 已完成 |
| T-P1-02 SPM 依赖初始配置 | ✅ 已完成（ADR-001）|
| T-P1-03 Design System Token | ✅ 已完成 |
| T-P1-04 5 Tab 导航骨架 | ✅ 已完成 |
| T-P1-05 登录流程 UI | ✅ 已完成 |
| T-P1-06 Sign in with Apple | ✅ 已完成 |
| T-P1-07 REST API + 手机验证码登录 | ⏳ 待开始（H-15 推迟） |
| T-P1-08 微信登录集成 | ⏳ 待开始（H-05 推迟） |
| T-P1-09 AppConfig + .gitignore | ✅ 已完成 |
| QA-P1 P1 验收 | ⏳ 待开始 |

---

## P2 Data Layer — 功能完成，待人工验收

| 任务 | 状态 |
|------|------|
| T-P2-01 SwiftData Schema | ✅ 已完成（2026-03-29）|
| T-P2-02 Local Repository | ✅ 已完成（自动化测试 42/42）|
| T-P2-03 ~~CloudKit~~ | ✅ 已取消（ADR-002）|
| T-P2-04 Bundle Fallback JSON | ✅ 已完成（2026-03-29）|
| T-P2-05 后端用户数据同步 | ✅ 已完成（2026-03-29）|
| T-P2-06 匿名用户本地模式 | ✅ 已完成（2026-03-29）|
| T-P2-07 SyncQueue | ✅ 已完成（2026-03-29）|
| QA-P2 验收 | ✅ 附条件通过（2026-04-10）— 235/235 自动化 + 31/31 人工测试；3 issue（FL-001/FL-002/B-03）已修复 + Code Review 确认；条件：用户重建后确认修复生效 |

---

## P3 Drill Library — ✅ 附条件通过

| 任务 | 状态 |
|------|------|
| T-P3-01 ~ T-P3-11 | ✅ 全部已完成（2026-03-29，自动化测试 47/47）|
| QA-P3 验收 | ✅ 附条件通过（2026-04-11）— 自动化 47/47；人工 TP-P3 50/53 执行，3 项失败（FL-003/FL-004/FL-005）已修复并验证；设备矩阵/可访问性/性能待补测 |

---

## P4 Training Log — ✅ 附条件通过

| 任务 | 状态 |
|------|------|
| T-P4-01 官方训练计划 JSON | ✅ 已完成（2026-03-29）|
| T-P4-02 训练 Tab 今日计划视图 | ✅ 已完成（2026-03-29）|
| T-P4-03 官方计划列表与详情页 | ✅ 已完成（2026-03-29）|
| T-P4-04 开始训练流程 | ✅ 已完成（2026-03-29）|
| T-P4-05 训练中 Drill 记录界面 | ✅ 已完成（2026-04-05，使用 BTSetInputGrid + BTExerciseRow）|
| T-P4-06 心得备注输入 | ✅ 已完成（2026-04-05，匹配 code.html 设计，DR-004）|
| T-P4-07 训练完成总结页 | ✅ 已完成（2026-04-05，匹配 code.html 设计，使用 BTLevelBadge 等 R0 组件）|
| T-P4-08 TrainingSession 持久化 | ✅ 已完成（2026-04-05，saveTraining 已在 T-P4-04 实现并测试通过 30/30）|
| T-P4-09 自定义训练计划 | ✅ 已完成（2026-04-05，匹配 code.html 设计，DR-007）|
| T-P4-10 TrainingShareView（新增） | ✅ 已完成（2026-04-05，BTShareCard 升级匹配 code.html + 定制面板 + 分享入口）|
| QA-P4 验收 | ✅ 附条件通过（2026-04-11）— 自动化 235/235 + 人工 TP-P4 92/98；FL-006/FL-007/FL-008 已修复，FL-009 P3 延后 |

---

## P5 Angle Training — ✅ 已完成

| Phase | 状态 | 备注 |
|-------|------|------|
| P5 Angle Training | ✅ 已完成（2026-04-05） | 代码审查 + 设计对齐 + 22 测试通过 |

---

## P6 History + Statistics — ✅ 已完成

| 任务 | 状态 |
|------|------|
| T-P6-01 历史 Tab 日历视图 | ✅ 已完成（2026-04-05）— BTSegmentedTab + 6 行日历 + 训练分类标签 + 设计对齐 |
| T-P6-02 训练详情页 | ✅ 已完成（2026-04-05）— Sheet 模态 + 统计横滚 + Drill 组明细 + 底栏操作 |
| T-P6-03 统计视图 | ✅ 已完成（2026-04-05）— BTTogglePillGroup + 三张统计卡片 + 左侧绿线装饰 |
| T-P6-04 训练频率柱状图 + 趋势线 | ✅ 已完成（2026-04-05）— Swift Charts BarMark + RuleMark，琥珀+品牌绿双色 |
| T-P6-05 各类别成功率对比 | ✅ 已完成（2026-04-05）— 2 列网格替代雷达图，环比变化 + 迷你柱状图 |
| T-P6-06 Freemium 历史查看限制 | ✅ 已完成（2026-04-05）— HistoryAccessController 60 天限制 + 锁定提示 |
| QA-P6 验收 | ✅ 附条件通过（2026-04-12）— 人工 TP-P6 日历/详情/动画/边界/性能全通过；统计 Pro paywall 正确生效（符合规格）；Pro 统计 UI + 60 天限制 e2e 待 TestFlight 补测 |

---

## P7 Subscription — ✅ 已完成

| 任务 | 状态 |
|------|------|
| T-P7-01 StoreKit 2 集成 | ✅ 已完成 — StoreKitService + Products.storekit 3 个 IAP |
| T-P7-02 订阅状态管理 | ✅ 已完成 — SubscriptionManager isPremium + Transaction.updates 监听 |
| T-P7-03 订阅页 UI | ✅ 已完成（2026-04-05）— 深色 #111111 全屏 + 金色编号功能列表 + 3 列方案卡 + 年订绿框推荐 |
| T-P7-04 恢复购买 | ✅ 已完成 — AppStore.sync() + 成功/失败 Alert |
| T-P7-05 Freemium 边界整合 | ✅ 已完成（2026-04-05）— 修复 AngleTestView limiter isPremium 同步 bug |
| QA-P7 验收 | ✅ 通过（2026-04-05）— 代码审查 + 234/234 自动化测试通过 |

---

## R-UI Existing Page Alignment — ✅ 附条件通过

> 详见 `tasks/phases/R-UI-alignment.md`

| 任务 | 状态 |
|------|------|
| T-RUI-01 TrainingHomeView 对齐 | ✅ 已完成（2026-04-05）— 今日安排卡片 + BTSegmentedTab 计划浏览 + 筛选 Chip + 固定底部按钮 + 空状态 |
| T-RUI-02 DrillListView + DrillDetailView 对齐 | ✅ 已完成（2026-04-05）— 灰色操作图标行 + 标签行 + darkPill/primary 固定底栏 + Pro 金色底栏 |
| T-RUI-03 ActiveTrainingView 对齐 | ✅ 已完成（2026-04-05）— 毛玻璃顶栏 4 图标 + 计划名进度条 + 5 键底栏带文字标签 + 橙色热身标记 |
| T-RUI-04 ProfileView + LoginView 对齐 | ✅ 已完成（2026-04-05）— 彩色圆底图标菜单 + 月度概览 + 游客警告/Pro 推广卡 + 三按钮登录 + 药丸验证码输入 |
| T-RUI-05 OnboardingView 对齐 | ✅ 已完成（2026-04-05）— 品牌绿圆底图标 + QJ Logo + 强制浅色 + 3 FeatureRow |
| QA-RUI 验收 | ✅ 附条件通过（2026-04-05）— D-1 已修复；8 项 P2 改进记入 P8 |

---

## P8 Polish & Release — 🔄 进行中

| 任务 | 状态 |
|------|------|
| T-P8-01 Privacy Manifest | ✅ 已完成（2026-04-05）— PrivacyInfo.xcprivacy 创建 + Xcode Target 添加 |
| T-P8-02 性能优化 | ✅ 代码审计通过（2026-04-06）— LazyVStack/Canvas/debounce 等已优化；4 项 Instruments 指标待人工验证 |
| T-P8-03 空状态与加载态全覆盖 | ✅ 已完成（2026-04-05）— BTShimmer 骨架屏 + 6 场景空状态/加载态全覆盖 |
| T-P8-04 首次引导流程完整版 | ✅ 已完成（2026-04-06）— 3 页 TabView + Capsule 页指示器 + 跳过/登录分页按钮 |
| T-P8-05 个人设置页 | ✅ 已完成（2026-04-06）— SettingsView（球种+周目标）+ 账号注销 + 隐私政策链接 |
| T-P8-06 账号注销与数据删除 | ✅ 已完成（2026-04-06）— 在 T-P8-05 中一并实现（二次确认 + DELETE API + 失败重试）|
| T-P8-07 XCTest 核心流程测试 | ✅ 已完成（2026-04-06）— 235/235 通过（+1 CRUD update 测试）|
| T-P8-08 TestFlight 内部测试 | ⏳ 待开始 |
| T-P8-09 App Store 资产准备 | ⏳ 待开始 |
| T-P8-10 App Store 提交审核 | ⏳ 待开始 |
| T-P8-11 Dark Mode 全面通刷 | ✅ 已完成（2026-04-05）— 21 Token 双值验证 + 14 文件修复 + D-1~D-7 全部确认 |
| T-P8-12 人工测试计划更新与执行 | ✅ 已完成（2026-04-06）— TP-P2/P3/P4 更新 + TP-P5/P6/P7 新建 + H-17 人工执行项 |
| T-P8-13 R-UI QA P2 改进项 | ✅ 已完成（2026-04-05）— 8 项全部处理（P8-A~H，详见下方） |
| QA-P8 最终验收 | ⏳ 待开始 |

---

## 阻塞项

| 阻塞 ID | 影响任务 | 描述 | 负责方 |
|---------|---------|------|--------|
| H-05 | T-P1-08 | 微信开放平台资质 — 🔜 推迟至 App 主体开发完成后 | 人工 |
| H-15 | T-P1-07 | 腾讯云短信服务 — 🔜 推迟至 App 主体开发完成后 | 人工 |

---

## Phase 完成记录

| Phase | 完成日期 | 备注 |
|-------|---------|------|
| R0 Design System | 2026-04-05 | 附条件通过（3 项 P2 改进记入 P8 Polish）|
| P1 Foundation | — | 部分阻塞（H-05, H-15 推迟）|
| P2 Data Layer | 2026-04-10 | 附条件通过（FL-001/FL-002/B-03 已修复，待用户重建确认）|
| P3 Drill Library | 2026-04-11 | 附条件通过（FL-003/FL-004/FL-005 已修复；设备矩阵/可访问性/性能待补测）|
| P4 Training Log | 2026-04-11 | 附条件通过（人工 92/98 + FL-006/007/008 已修复；FL-009 P3 延后）|
| P5 Angle Training | 2026-04-05 | 代码审查 + 设计对齐 + 22 测试通过 |
| P6 History | 2026-04-12 | ✅ 附条件通过（人工 TP-P6 + 234/234 自动化；Pro 统计 UI + 60 天限制 e2e 待 TestFlight 补测）|
| P7 Subscription | 2026-04-05 | 5 任务完成 + SubscriptionView 设计对齐 + Freemium 全整合 + 234/234 测试 |
| R-UI Alignment | 2026-04-05 | 附条件通过（D-1 已修复；8 项 P2 改进记入 P8-13）|
| R1 UI 逐页审查 | 2026-04-06 | 11 份报告完成，145 项偏差（P0:0 / P1:33 / P2:112）|
| P8 Polish & Release | — | — |

---

## R1 UI 逐页审查 — ✅ 已完成

> 详见 `tasks/phases/R1-ui-review.md` + `tasks/ui-reviews/UR-20260406-*.md`（11 份）

| 任务 | 状态 |
|------|------|
| T-R1-01 TrainingHomeView 审查 | ✅ 已完成（2026-04-06）— 10 项（P1:3 / P2:7）|
| T-R1-02 ActiveTrainingView 审查 | ✅ 已完成（2026-04-06）— 16 项（P1:3 / P2:13）|
| T-R1-03 TrainingSummary + ShareView 审查 | ✅ 已完成（2026-04-06）— 17 项（P1:3 / P2:14）|
| T-R1-04 Plans（List+Detail+Builder）审查 | ✅ 已完成（2026-04-06）— 18 项（P1:7 / P2:11）|
| T-R1-05 DrillLibrary 审查 | ✅ 已完成（2026-04-06）— 13 项（P1:6 / P2:7）|
| T-R1-06 AngleTraining 审查 | ✅ 已完成（2026-04-06）— 16 项（P1:1 / P2:15）|
| T-R1-07 History + Statistics 审查 | ✅ 已完成（2026-04-06）— 13 项（P1:2 / P2:11）|
| T-R1-08 Profile + Settings 审查 | ✅ 已完成（2026-04-06）— 13 项（P1:4 / P2:9）|
| T-R1-09 Onboarding + Login 审查 | ✅ 已完成（2026-04-06）— 7 项（P1:1 / P2:6）|
| T-R1-10 SubscriptionView 审查 | ✅ 已完成（2026-04-06）— 11 项（P2:11）|
| T-R1-11 全局 + 组件审查 | ✅ 已完成（2026-04-06）— 11 项（P1:3 / P2:8）|

**汇总**：全部 11 个审查任务完成，共发现 **145 项偏差**（P0: 0 / P1: 33 / P2: 112）。

---

## P9 Aiming Feature Expansion — 🔄 进行中（DoD 11/14）

> 详见 `tasks/phases/P9-aiming.md`

| 任务 | 状态 |
|------|------|
| T-P9-00 UI 设计交付文档更新 | ⏳ 延后 |
| T-P9-D-01~06 UI 设计出图 | ✅ 已完成（2026-04-14，6/7 APPROVED） |
| T-P9-D-REVIEW 设计一致性审查 | ⏳ 待开始 |
| T-P9-01 SceneKit 场景基础设施 | ✅ 已完成（2026-04-14）— ADR-P9-01 |
| T-P9-02 数据层扩展 | ✅ 已完成（2026-04-14） |
| T-P9-03 AngleHomeView 导航重构 | ✅ 已完成（2026-04-14） |
| T-P9-04 瞄准原理页 | ✅ 已完成（2026-04-14） |
| T-P9-05 角度与打点动态关系页 | ✅ 已完成（2026-04-14） |
| T-P9-06 几何角度预测训练 | ✅ 已完成（2026-04-14） |
| T-P9-07 SceneKit 角度预测页（2D/3D） | ✅ 已完成（2026-04-14） |
| T-P9-08 SceneKit 角度预测增强 | ✅ 已完成（2026-04-14） |
| T-P9-09 进球点对照表增强 | ✅ 已完成（2026-04-14） |
| T-P9-10 浅淡球感页 | ✅ 已完成（2026-04-14） |
| T-P9-11 AngleHistoryView 增强 | ✅ 已完成（2026-04-14） |
| QA-P9 验收 | 🔄 编译通过，待人工验收 |

---

## 执行顺序

```
R0 ✅ → P4 ✅ → P5 ✅ → P6 ✅ → P7 ✅ → R-UI ✅ → P8 🔄 → R1 ✅ → P9 🔄
```

---

## 下一步

1. **P9 实现任务全部完成**（2026-04-14）：
   - Wave 1：SceneKit 基础设施 + 数据层 quizType + 导航重构（7 功能分组）
   - Wave 2：5 独立页面（瞄准原理 / 角度与打点 / 几何训练 / 对照表增强 / 浅淡球感）
   - Wave 3-4：SceneKit 2D/3D 角度预测 + 增强（训练类型/自由练习/幽灵球/瞄准线）
   - Wave 5：AngleHistoryView quizType 筛选增强
   - **待人工验收**：模拟器运行验证 SceneKit 加载 / 2D↔3D 切换 / 角度计算 / Dark Mode
   - **ADR-P9-01**：SceneKit 引入决策已记录
2. **R1 审查 + 修复 + DrillLibrary 改造已完成**（2026-04-06）：
   - 11 份审查报告 → 145 项偏差 → 10 组并行修复 → 235/235 测试通过
   - **DrillLibrary 参照训记全面改造**（DR-011）：
     - 新建 `BTMiniTable.swift`（缩略图 Canvas：球径 3x + 路径 2x + 袋口高亮 + 无库边）
     - `BTDrillGridCard` 使用 BTMiniTable + 等级徽章/PRO/收藏叠加层 + 底部渐变
     - `DrillListView` 改为训记风格：左侧分类侧边栏（72pt）+ 右侧 2 列网格
     - `DrillDetailView` 新增：备注输入卡、训练维度 5 进度条、查看精讲按钮、真人示范占位
     - `BTDrillListSkeleton` 更新为 2 列网格骨架
   - **延后项**：TrainingHome「即将到来」Section、DrillRecordView 休息设置行、BTShareCard 备注 toggle、History 新增功能按钮
   - **下一步**：人工测试（H-17）→ TestFlight
2. **P8 待执行**：
   - **H-17 人工测试执行**（TP-P2~P7 约 3 小时 — [HUMAN]）
   - T-P8-08（TestFlight 发布 — [HUMAN]）
   - T-P8-09（App Store 资产准备 — [HUMAN]）
   - T-P8-10（App Store 提交 — [HUMAN]）
   - QA-P8 最终验收
3. **人工测试**：6 份测试计划已就绪（TP-P2~P7），待人工在模拟器/真机上执行（见 H-17）。
4. **后端部署** ✅（2026-03-29）：已部署至 106.54.3.210:3000，72 条 Drill 已 seed。
5. **知识累积机制**：`tasks/IMPLEMENTATION-LOG.md`（FL/DR/PD 三类条目）+ `UI-IMPLEMENTATION-SPEC.md` Changelog 节跨会话保持实施知识。

---

## 已完成 Phase 归档

当某一 Phase **全部任务**均为 ✅ 后：

1. 将任务明细表剪切至 `tasks/archive/Pn-completed.md`。
2. 在「Phase 完成记录」表中填写完成日期。
3. 从下一会话起仅读当前 Phase 任务卡。
