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

- **当前 Phase**：P1 Foundation（部分阻塞）+ P2 Data Layer（进行中）
- **当前激活角色**：Data Engineer
- **整体进度**：0 / 8 Phases 完成（P2 进行中）

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

## P2 Data Layer — 进行中任务

> **人工前置**：H-14 ✅（腾讯云服务器）、H-16 ⏳（MongoDB）、H-07 ⏳（CloudKit 容器）

| 任务 | 状态 |
|------|------|
| T-P2-01 SwiftData Schema（全量实体） | ✅ 已完成（2026-03-29）|
| T-P2-02 Local Repository 实现 | ✅ 已完成（2026-03-29）|
| T-P2-03 CloudKit 公开库内容拉取 | ⏳ 待开始（H-07 阻塞）|
| T-P2-04 Bundle Fallback JSON 结构 | ✅ 已完成（2026-03-29）|
| T-P2-05 后端用户数据同步 | ⏳ 待开始（H-16 + T-P1-07 阻塞）|
| T-P2-06 匿名用户本地模式 | ✅ 已完成（2026-03-29）|
| T-P2-07 SyncQueue（后台同步队列） | ✅ 已完成（2026-03-29，stub，T-P2-05 填充上传）|
| QA-P2 P2 验收 | ⏳ 待开始 |

---

## 阻塞项

| 阻塞 ID | 影响任务 | 描述 | 负责方 |
|---------|---------|------|--------|
| H-01 | ~~T-P1-01~~ | ~~Apple Developer 账号未确认~~ | ✅ 已完成 |
| H-05 | T-P1-08 | 微信开放平台资质未申请（需1-3天审核） | 人工（你） |
| H-06 | ~~T-P1-07, T-P2-05~~ | ~~LeanCloud~~ ✅ 已取消（ADR-001） | — |
| H-07 | T-P2-03 | CloudKit 容器未创建 | 人工（你） |
| H-08 | ~~T-P1-06~~ | ~~Sign in with Apple 能力未开启~~ | ✅ 已完成 |
| H-14 | ~~T-P1-07, T-P2-05~~ | ~~腾讯云服务器未购买部署~~ | ✅ 已完成 |
| H-15 | T-P1-07 | 腾讯云短信服务未申请 | 人工（你） |
| H-16 | T-P2-05 | 腾讯云 MongoDB 未创建 | 人工（你） |

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

1. **等待人工操作**：H-15（腾讯云短信）完成后，T-P1-07 解锁。
2. H-16（腾讯云 MongoDB）完成后 T-P2-05 解锁。
3. H-07（CloudKit 容器）完成后 T-P2-03 解锁。
4. H-05（微信）审核需 1-3 工作日，T-P1-08 暂缓。
5. **现在可继续**：P3 Drill Library（T-P3-xx）无后端依赖，可立即开始。

---

## 已完成 Phase 归档（上下文压缩）

当某一 Phase **全部任务**均为 ✅ 后：

1. 将该 Phase 在本文中的**任务明细表**（若有）剪切至 `tasks/archive/Pn-completed.md`（新建文件，`n` 为 Phase 编号）。
2. 在本文「Phase 完成记录」表中填写完成日期；在本节或「当前状态」下仅保留一行摘要，例如：`P1 Foundation 详情见 tasks/archive/P1-completed.md`。
3. 从下一会话起，Orchestrator 优先读「当前 Phase」与 `tasks/phases/Pn-*.md`，不必每次加载已归档明细。

> 目录 `tasks/archive/` 仅存放已结案 Phase 的快照，与 `tasks/phases/` 中权威任务卡并存。
