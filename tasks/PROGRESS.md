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

- **当前 Phase**：P1 — Foundation（待开始）
- **当前激活角色**：—
- **整体进度**：0 / 8 Phases 完成

---

## P1 Foundation — 进行中任务

> 开始 P1 前，确认以下项均为 ✅（见 `tasks/HUMAN-REQUIRED.md`）：H-01, H-02；T-P1-06 另需 H-08。

| 任务 | 状态 |
|------|------|
| T-P1-01 Xcode 项目初始化 | ⏳ 待开始 |
| T-P1-02 SPM 依赖初始配置 | ⏳ 待开始 |
| T-P1-03 Design System Token | ⏳ 待开始 |
| T-P1-04 5 Tab 导航骨架 | ⏳ 待开始 |
| T-P1-05 登录流程 UI | ⏳ 待开始 |
| T-P1-06 Sign in with Apple | ⏳ 待开始（H-08 阻塞） |
| T-P1-07 LeanCloud 手机验证码登录 | ⏳ 待开始（H-06 阻塞） |
| T-P1-08 微信登录集成 | ⏳ 待开始（H-05, H-13 阻塞） |
| T-P1-09 AppConfig + .gitignore | ⏳ 待开始 |
| QA-P1 P1 验收 | ⏳ 待开始 |

---

## 阻塞项

| 阻塞 ID | 影响任务 | 描述 | 负责方 |
|---------|---------|------|--------|
| H-01 | ~~T-P1-01~~ | ~~Apple Developer 账号未确认~~ | ✅ 已完成 |
| H-05 | T-P1-08 | 微信开放平台资质未申请（需1-3天审核） | 人工（你） |
| H-06 | T-P1-07, T-P2-05 | LeanCloud 账号未注册 | 人工（你） |
| H-07 | T-P2-03 | CloudKit 容器未创建 | 人工（你） |
| H-08 | T-P1-06 | Sign in with Apple 能力未开启 | 人工（你） |

---

## Phase 完成记录

| Phase | 完成日期 | 备注 |
|-------|---------|------|
| P1 Foundation | — | — |
| P2 Data Layer | — | — |
| P3 Drill Library | — | — |
| P4 Training Log | — | — |
| P5 Angle Training | — | — |
| P6 History | — | — |
| P7 Subscription | — | — |
| P8 Polish & Release | — | — |

---

## 下一步

1. **P1 前置人工项**：按需完成 `tasks/HUMAN-REQUIRED.md` 中仍为 ⏳ 的 `[BLOCKING]` 项（如 H-08 对应 T-P1-06）。
2. H-05（微信）、H-06（LeanCloud）可与 P1 早期任务并行准备，不阻塞 T-P1-01～T-P1-05。
3. 告知 AI「开始 P1」后，Orchestrator 将从 T-P1-01 开始；长任务中断前请将当前任务标为 🔄 并写明 DoD 进度。

---

## 已完成 Phase 归档（上下文压缩）

当某一 Phase **全部任务**均为 ✅ 后：

1. 将该 Phase 在本文中的**任务明细表**（若有）剪切至 `tasks/archive/Pn-completed.md`（新建文件，`n` 为 Phase 编号）。
2. 在本文「Phase 完成记录」表中填写完成日期；在本节或「当前状态」下仅保留一行摘要，例如：`P1 Foundation 详情见 tasks/archive/P1-completed.md`。
3. 从下一会话起，Orchestrator 优先读「当前 Phase」与 `tasks/phases/Pn-*.md`，不必每次加载已归档明细。

> 目录 `tasks/archive/` 仅存放已结案 Phase 的快照，与 `tasks/phases/` 中权威任务卡并存。
