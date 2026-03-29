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

- **当前 Phase**：P1 Foundation（部分阻塞）+ P4 Training Log（进行中）
- **当前激活角色**：Orchestrator（基础设施更新）→ 待切换
- **整体进度**：0 / 8 Phases 完成（P2 自动化测试 ✅ 42/42 + P3 自动化测试 ✅ 47/47，均待人工测试后最终验收）

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
4. **P4 进行中**：T-P4-04 ✅ → 下一步 T-P4-05（训练中 Drill 记录界面）。
5. **Test Engineer 角色已创建**（2026-03-29）：新增 `55-test-engineer.mdc` 规则 + `test-engineer.md` 子智能体，已注册至 Orchestrator 路由表与 `AGENTS.md`。项目当前零测试代码，后续在功能任务完成后由 Test Engineer 补写自动化测试。
6. **P2 自动化测试 ✅ 完成**（2026-03-29）：QiuJiTests target 创建，42 项自动化测试全部通过（Models 11 + Repositories 20 + Services 11）。修复了 Drills/Plans 未加入 Bundle Resources 的问题。QA-P2 待用户执行人工测试计划 `TP-P2.md` 后最终验收。

---

## P4 Training Log — 任务列表

| 任务 | 状态 |
|------|------|
| T-P4-01 官方训练计划 JSON 生产（6 套） | ✅ 已完成（2026-03-29）|
| T-P4-02 训练 Tab — 今日计划视图 | ✅ 已完成（2026-03-29）|
| T-P4-03 官方计划列表与详情页 | ✅ 已完成（2026-03-29）|
| T-P4-04 开始训练流程 | ✅ 已完成（2026-03-29）|
| T-P4-05 训练中 Drill 记录界面 | ⏳ 待开始 |
| T-P4-06 心得备注输入 | ⏳ 待开始 |
| T-P4-07 训练完成总结页 | ⏳ 待开始 |
| T-P4-08 TrainingSession 持久化 | ⏳ 待开始 |
| T-P4-09 自定义训练计划 | ⏳ 待开始 |
| QA-P4 P4 验收 | ⏳ 待开始 |

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
