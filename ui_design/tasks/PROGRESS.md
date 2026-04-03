# 开发进度（PROGRESS）

> Orchestrator 每次会话开始时读取本文件，结束时更新。

---

## 任务状态（四态）

| 符号 | 含义 | 使用说明 |
|------|------|----------|
| ⏳ | 待开始 | 尚未开工 |
| 🔄 | 进行中 | 附 DoD 进度，例：`🔄 进行中（DoD 2/5）`；会话可能中断时**必须**写入，便于恢复 |
| ⚠️ | 返工 | 附 `见 FL-xxx`，对应 [`tasks/FAILURE-LOG.md`](FAILURE-LOG.md) 条目；修复后改回 ⏳ 或 🔄 |
| ✅ | 已完成 | Phase 任务卡 DoD 全部满足 |

---

## 当前状态

- **当前 Phase**：P7 Subscription 开发 ✅ → 待 QA 验收；P2–P6 均待人工测试
- **当前激活角色**：Data Engineer + SwiftUI Developer → Orchestrator
- **整体进度**：0 / 8 Phases 完成（P2–P7 开发全部 ✅，P2–P6 自动化测试 ✅，均待人工测试后最终验收）
- **全项目累计自动化测试**：232 项（P7 为 StoreKit 集成，需真机/沙盒验证，暂无新增自动化测试）

---

## P2 Data Layer — 进行中任务

> 开始 P1 前，确认以下项均为 ✅（见 `tasks/HUMAN-REQUIRED.md`）：H-01, H-02；T-P1-06 另需 H-08。

| 任务 | 状态 |
|------|------|
| T-P1-01 Xcode 项目初始化 | ✅ 已完成 |
| T-P1-02 SPM 依赖初始配置 | ✅ 已完成（LeanCloud 已移除，ADR-001）|
| T-P1-03 Design System Token | ✅ 已完成 |
| T-P1-04 5 Tab 导航骨架 | ✅ 已完成 |
| T-P1-05 登录流程 UI | ✅ 已完成 |
| T-P1-06 Sign in with Apple | ✅ 已完成 |
| T-P1-07 REST API 初始化 + 手机验证码登录 | ⏳ 待开始（H-15 阻塞） |
| T-P1-08 微信登录集成 | ⏳ 待开始（H-05, H-13 阻塞） |
| T-P1-09 AppConfig + .gitignore | ✅ 已完成 |
| QA-P1 P1 验收 | ⏳ 待开始 |

---

## P2 Data Layer — 🔄 重新验收中（DoD 已更新含测试要求）

| 任务 | 状态 |
|------|------|
| T-P2-01 SwiftData Schema（全量实体） | ✅ 已完成（2026-03-29）|
| T-P2-02 Local Repository 实现 | ✅ 已完成（2026-03-29，自动化测试 42/42 通过）|
| T-P2-03 ~~CloudKit 公开库~~ 自建 API Drill 内容 OTA | ✅ 已取消（ADR-002）|
| T-P2-04 Bundle Fallback JSON 结构 | ✅ 已完成（2026-03-29）|
| T-P2-05 后端用户数据同步 | ✅ 已完成（2026-03-29）|
| T-P2-06 匿名用户本地模式 | ✅ 已完成（2026-03-29）|
| T-P2-07 SyncQueue（后台同步队列） | ✅ 已完成（2026-03-29）|
| QA-P2 P2 验收 | 🔄 自动化测试 ✅ 通过（42/42）；人工测试计划 TP-P2 已编写，待用户执行 |

---

## 阻塞项

| 阻塞 ID | 影响任务 | 描述 | 负责方 |
|---------|---------|------|--------|
| H-01 | ~~T-P1-01~~ | ~~Apple Developer 账号未确认~~ | ✅ 已完成 |
| H-05 | T-P1-08 | 微信开放平台资质 — 🔜 推迟至 App 开发完成后 | 人工（你） |
| H-06 | ~~T-P1-07, T-P2-05~~ | ~~LeanCloud~~ ✅ 已取消（ADR-001） | — |
| H-07 | ~~T-P2-03~~ | ~~CloudKit 容器~~ ✅ 已取消（ADR-002） | — |
| H-08 | ~~T-P1-06~~ | ~~Sign in with Apple 能力未开启~~ | ✅ 已完成 |
| H-14 | ~~T-P1-07, T-P2-05~~ | ~~腾讯云服务器未购买部署~~ | ✅ 已完成 |
| H-15 | T-P1-07 | 腾讯云短信服务 — 🔜 推迟至 App 开发完成后 | 人工（你） |
| H-16 | ~~T-P2-05~~ | ~~腾讯云 MongoDB 未创建~~ | ✅ 已完成（同机部署） |

---

## Phase 完成记录

| Phase | 完成日期 | 备注 |
|-------|---------|------|
| P1 Foundation | — | — |
| P2 Data Layer | — | DoD 已更新含测试要求，重新验收中 |
| P3 Drill Library | — | 待重新验收 |
| P4 Training Log | — | — |
| P5 Angle Training | — | — |
| P6 History | — | — |
| P7 Subscription | — | — |
| P8 Polish & Release | — | — |

---

## 下一步

1. **H-05（微信）、H-15（短信）**：用户决定推迟至 App 主体开发完成后处理，不阻塞当前开发。
2. **后端部署** ✅（2026-03-29）：`backend/` 已部署至 106.54.3.210:3000（Node.js 20 + pm2 + MongoDB 7.0.31），72 条 Drill 已 seed，`/health` 可达。
3. **P3 自动化测试 ✅ 完成**（2026-03-29）：新增 47 项自动化测试全部通过（DrillContentValidation 20 + DrillListViewModel 13 + DrillCategoryAndLevel 14），含 72 条 Drill JSON 全量校验、ViewModel 搜索/筛选/分组逻辑、枚举完整性与元数据验证。全项目累计 89/89 测试通过，无回归。QA-P3 待用户执行人工测试计划 `TP-P3.md` 后最终验收。
4. **P4 全部开发任务 ✅ 完成**（2026-04-02）：T-P4-01~T-P4-09 全部完成 → 下一步 QA-P4 验收。T-P4-09 新增 CustomPlan/CustomPlanDrill SwiftData 模型 + UserActivePlan 增加 isCustom 字段（ADR-003）。
5. **Test Engineer 角色已创建**（2026-03-29）：新增 `55-test-engineer.mdc` 规则 + `test-engineer.md` 子智能体，已注册至 Orchestrator 路由表与 `AGENTS.md`。项目当前零测试代码，后续在功能任务完成后由 Test Engineer 补写自动化测试。
6. **P2 自动化测试 ✅ 完成**（2026-03-29）：QiuJiTests target 创建，42 项自动化测试全部通过（Models 11 + Repositories 20 + Services 11）。修复了 Drills/Plans 未加入 Bundle Resources 的问题。QA-P2 待用户执行人工测试计划 `TP-P2.md` 后最终验收。
7. **UI 审查 UR-20260402 完成**（2026-04-02）：首轮全 Tab 截图审查，发现 11 项问题（P0:2 / P1:6 / P2:3），创建 FL-002~FL-009，规则回写至 `20-swiftui-developer.mdc`。**优先修复**：FL-007（弹窗按钮无文字）→ FL-006/FL-009（T-P4-05 开发）→ FL-003/FL-004（按钮/Drill名渲染）→ FL-002/FL-005/FL-008（图标/导航/列表标签）。
8. **P5 全部开发任务 ✅ 完成**（2026-04-02）：T-P5-01~T-P5-06 全部完成 → 下一步 QA-P5 验收。新增 10 个文件（AngleCalculator + AdaptiveQuestionEngine + AngleUsageLimiter + AngleTestViewModel + AngleHistoryViewModel + AngleHomeView + AngleTestView + BTAngleTestTable + ContactPointTableView + AngleHistoryView），角度 Tab 从占位视图替换为完整功能。纯离线、零网络依赖。构建通过，89 项自动化测试无回归。
9. **P6 全部开发任务 ✅ 完成**（2026-04-02）：T-P6-01~T-P6-06 全部完成 → 下一步 QA-P6 验收。新增 6 个文件（HistoryViewModel + StatisticsViewModel + HistoryCalendarView + TrainingDetailView + StatisticsView + HistoryAccessController），历史 Tab 从占位视图替换为完整功能：日历月视图、训练详情页、统计图表（Swift Charts 折线图 + 水平条形图，ADR-004）、Freemium 60 天限制。构建通过，自动化测试无回归。
10. **P4+P5 自动化测试 ✅ 完成**（2026-04-02）：新增 87 项自动化测试全部通过。P4 新增：ActiveTrainingViewModelTests（32 项，覆盖计时器/导航/录入/统计/保存/清理）+ CustomPlanBuilderViewModelTests（18 项，覆盖 CRUD/验证/激活/编辑）。P5 新增：AngleTestViewModelTests（12 项，覆盖测试流程/提交/限额/统计）+ AngleTrainingTests 恢复（AngleCalculator 7 + AdaptiveEngine 11 + UsageLimiter 7）。修复预有 BallTypeFilter 枚举计数回归。全项目累计 175/175 测试通过，零回归。人工测试计划 TP-P4.md 已有、TP-P5.md 已创建，待用户执行。
11. **P6 自动化测试 ✅ 完成**（2026-04-02）：新增 57 项自动化测试全部通过。HistoryViewModelTests（18 项，覆盖日历数据/日期过滤/月份导航/SwiftData 加载）+ StatisticsViewModelTests（26 项，覆盖时间范围筛选/训练天数/时长统计/频率图数据/分类成功率）+ HistoryAccessControllerTests（13 项，覆盖 Freemium 60 天限制/Premium 无限/边界值）。全项目累计 232 项测试（P6 新增 57 项无回归；预存 ActiveTrainingVM test_saveTraining_success 因 SwiftData 关系无序有 1 项间歇失败，非 P6 引入）。人工测试计划 TP-P6.md 已创建，待用户执行。
12. **P7 全部开发任务 ✅ 完成**（2026-04-02）：T-P7-01~T-P7-05 全部完成。新增 3 个 Swift 文件 + 1 个 StoreKit 配置文件：StoreKitService（actor，Product 加载/购买/恢复/权益验证）+ SubscriptionManager（ObservableObject 单例，isPremium 全局状态 + Transaction.updates 监听）+ SubscriptionView（三方案选择/动态价格/恢复购买/条款链接）+ Products.storekit（月¥18 / 年¥88 / 终身¥198，含 7 天免费试用）。Freemium 边界全整合：BTPremiumLock 新增 PremiumGateModifier、DrillDetailView/PlanDetailView 使用 .premiumGate()、AngleUsageLimiter 由 SubscriptionManager 驱动、HistoryCalendarView 使用真实 isPremium、StatisticsView/AngleHistoryView 添加 Pro 门控、ProfileView 新增订阅入口 + 管理订阅。构建通过，232 项自动化测试零回归。下一步：P8 Polish & Release。

---

## P7 Subscription — 任务列表

| 任务 | 状态 |
|------|------|
| T-P7-01 StoreKit 2 集成（Product 加载 + 购买） | ✅ 已完成（2026-04-02，StoreKitService actor + Products.storekit 配置）|
| T-P7-02 订阅状态管理（SubscriptionManager） | ✅ 已完成（2026-04-02，ObservableObject 单例 + Transaction.updates 监听）|
| T-P7-03 订阅页 UI | ✅ 已完成（2026-04-02，SubscriptionView 三方案 + 动态价格 + 恢复购买 + 条款链接）|
| T-P7-04 恢复购买 | ✅ 已完成（2026-04-02，AppStore.sync() + 成功/失败提示）|
| T-P7-05 Freemium 边界逻辑全整合 | ✅ 已完成（2026-04-02，PremiumGateModifier + 9 处检查点统一）|
| QA-P7 P7 验收 | 🔄 构建通过 + 232 项自动化测试零回归；待用户 StoreKit Testing 沙盒验证 |

---

## P6 History — 任务列表

| 任务 | 状态 |
|------|------|
| T-P6-01 历史 Tab — 日历视图（F6） | ✅ 已完成（2026-04-02，HistoryCalendarView + HistoryViewModel）|
| T-P6-02 训练详情页（F6） | ✅ 已完成（2026-04-02，TrainingDetailView + 日期时间/成功率/分组/心得）|
| T-P6-03 统计视图（F7） | ✅ 已完成（2026-04-02，StatisticsView + 周/月/年切换 + 三卡片 + 空状态）|
| T-P6-04 训练频率折线图（F7） | ✅ 已完成（2026-04-02，Swift Charts LineMark + AreaMark + PointMark）|
| T-P6-05 各类别成功率图表（F7） | ✅ 已完成（2026-04-02，水平 BarMark 替代雷达图，ADR-004）|
| T-P6-06 Freemium 历史查看限制（F6） | ✅ 已完成（2026-04-02，HistoryAccessController 60 天本地计算）|
| QA-P6 P6 验收 | 🔄 自动化测试 ✅ 通过（HistoryVM 18 + StatisticsVM 26 + HistoryAccessController 13）；人工测试计划 TP-P6 已编写，待用户执行 |

---

## P5 Angle Training — 任务列表

| 任务 | 状态 |
|------|------|
| T-P5-01 角度计算引擎 + 自适应算法 | ✅ 已完成（2026-04-02，AngleCalculator + AdaptiveQuestionEngine）|
| T-P5-02 角度测试出题 UI（F10） | ✅ 已完成（2026-04-02，AngleTestView + BTAngleTestTable + 数字键盘输入）|
| T-P5-03 角度测试答案动画（F10） | ✅ 已完成（2026-04-02，绿色正确路线 + 橙色用户路线 + 红点接触点 + 误差评级）|
| T-P5-04 角度测试历史记录 | ✅ 已完成（2026-04-02，AngleTestResult 持久化 + Canvas 折线图趋势 + 角袋/中袋分离）|
| T-P5-05 进球点对照表（F11） | ✅ 已完成（2026-04-02，交互式滑块 + 球面接触点图 + 13 标准角度静态表）|
| T-P5-06 Freemium 每日次数限制 | ✅ 已完成（2026-04-02，AngleUsageLimiter + 每日 20 题 + 日期重置 + 订阅引导）|
| QA-P5 P5 验收 | 🔄 自动化测试 ✅ 通过（AngleCalculator 7 + AdaptiveEngine 11 + UsageLimiter 7 + AngleTestVM 12）；人工测试计划 TP-P5 已编写，待用户执行 |

---

## P4 Training Log — 任务列表

| 任务 | 状态 |
|------|------|
| T-P4-01 官方训练计划 JSON 生产（6 套） | ✅ 已完成（2026-03-29）|
| T-P4-02 训练 Tab — 今日计划视图 | ✅ 已完成（2026-03-29）|
| T-P4-03 官方计划列表与详情页 | ✅ 已完成（2026-03-29）|
| T-P4-04 开始训练流程 | ✅ 已完成（2026-03-29）|
| T-P4-05 训练中 Drill 记录界面 | ✅ 已完成（2026-04-02，含球台动画 + 进球记录 + 分组进度）|
| T-P4-06 心得备注输入 | ✅ 已完成（2026-04-02，TrainingNoteView + 可跳过 + 软字数提示 + 键盘适配）|
| T-P4-07 训练完成总结页 | ✅ 已完成（2026-04-02，TrainingSummaryView + 统计卡片 + Drill 成功率排序 + 查看历史跳转）|
| T-P4-08 TrainingSession 持久化 | ✅ 已完成（2026-04-02，SwiftData 写入 + SyncQueue 入列 + 中文错误提示）|
| T-P4-09 自定义训练计划 | ✅ 已完成（2026-04-02，CustomPlan/CustomPlanDrill SwiftData 模型 + CustomPlanBuilderView + 计划列表集成 + 激活/删除/编辑）|
| QA-P4 P4 验收 | 🔄 自动化测试 ✅ 通过（ActiveTrainingVM 32 + CustomPlanBuilderVM 18）；人工测试计划 TP-P4 已编写，待用户执行 |

---

## P3 Drill Library — 任务列表

| 任务 | 状态 |
|------|------|
| T-P3-01 Drill JSON Schema 定稿 + index.json | ✅ 已完成（2026-03-29）|
| T-P3-02 Drill Batch 1（fundamentals 5 + accuracy 5） | ✅ 已完成（2026-03-29，H-11 Batch 1 ✅ 验证通过）|
| T-P3-03 Drill Batch 2–7 | ✅ 已完成（2026-03-29，62 条全部生成，坐标自检通过，待 H-11 人工验证）|
| T-P3-06 DrillLibrary Tab 分类列表 UI | ✅ 已完成（2026-03-29）|
| T-P3-07 Drill 详情页 | ✅ 已完成（2026-03-29）|
| T-P3-08 BTBilliardTable Canvas 组件 | ✅ 已完成（2026-03-29）|
| T-P3-09 球种筛选 + 搜索 | ✅ 已完成（2026-03-29，嵌入 DrillListView）|
| T-P3-10 Drill 收藏 | ✅ 已完成（2026-03-29）|
| T-P3-11 Freemium 锁定（BTPremiumLock） | ✅ 已完成（2026-03-29）|
| QA-P3 P3 验收 | 🔄 自动化测试 ✅ 通过（47/47）；人工测试计划 TP-P3 待用户执行 |

---

## 已完成 Phase 归档（上下文压缩）

当某一 Phase **全部任务**均为 ✅ 后：

1. 将该 Phase 在本文中的**任务明细表**（若有）剪切至 `tasks/archive/Pn-completed.md`（新建文件，`n` 为 Phase 编号）。
2. 在本文「Phase 完成记录」表中填写完成日期；在本节或「当前状态」下仅保留一行摘要，例如：`P1 Foundation 详情见 tasks/archive/P1-completed.md`。
3. 从下一会话起，Orchestrator 优先读「当前 Phase」与 `tasks/phases/Pn-*.md`，不必每次加载已归档明细。

> 目录 `tasks/archive/` 仅存放已结案 Phase 的快照，与 `tasks/phases/` 中权威任务卡并存。
