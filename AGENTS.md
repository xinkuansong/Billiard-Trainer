# MA-SDD：球迹 iOS 多智能体协同开发

本仓库使用 **Multi-Agent Spec-Driven Development（MA-SDD）**：以产品文档 `docs/01`–`docs/08` 为规格源，由 **Orchestrator（主控）** 调度专项角色，通过 `tasks/` 共享状态与进度。

## 快速开始

1. **先读** [`tasks/PROGRESS.md`](tasks/PROGRESS.md)、[`tasks/HUMAN-REQUIRED.md`](tasks/HUMAN-REQUIRED.md) 与（若存在返工）[`tasks/FAILURE-LOG.md`](tasks/FAILURE-LOG.md)。
2. 若有未完成的 **`[BLOCKING]`** 人工项，按 `HUMAN-REQUIRED.md` 完成后再让 AI 继续写代码。
3. 在 Cursor 中开始工作时，声明：**「以 Orchestrator 身份执行下一任务」**；或 **@ 子智能体**（见下「子智能体」表，例如 `@orchestrator`、`@swiftui-developer`）；或手动 @ 对应规则（见下「角色与规则」表）。
4. 任务完成后：**更新 `tasks/PROGRESS.md`**（状态、阻塞、下一步）。

## 子智能体（`.cursor/agents/`）

项目级子智能体与 `.cursor/rules/*.mdc` **对齐**：规则随文件/glob **被动**注入上下文；子智能体适合**主动**新开对话或长任务，在独立上下文中执行同一套角色约定。路由表仍以 `00-orchestrator.mdc` 为准。

| 子智能体文件 | 角色 | 典型用法 |
|--------------|------|----------|
| `orchestrator.md` | 主控调度 + 人工检查 | 会话入口、选任务、拆分子任务 |
| `ios-architect.md` | 架构 / 模块 / ADR | 新模块、重构、SPM 决策 |
| `swiftui-developer.md` | SwiftUI / Canvas / 设计系统 | 界面与组件 |
| `data-engineer.md` | SwiftData / CloudKit / 自建 REST API | 模型与同步 |
| `content-engineer.md` | Drill JSON、计划内容 | `Resources/Drills/`、批量内容 |
| `qa-reviewer.md` | 验收 / DoD / 边界 | Phase 收尾、回归前检查 |
| `devops-release.md` | 构建、证书、TestFlight | `scripts/Makefile`、发布 |

## 角色与规则（`.cursor/rules/`）

| 规则文件 | 角色 | 典型触发 |
|----------|------|----------|
| `00-orchestrator.mdc` | 主控调度 + 人工检查 | 每次会话入口 |
| `10-ios-architect.mdc` | 架构 / 模块 / ADR | 新模块、重构、技术选型 |
| `20-swiftui-developer.mdc` | SwiftUI / Canvas / 设计系统 | `*View.swift`、界面 |
| `30-data-engineer.mdc` | SwiftData / CloudKit / 自建 REST API | Model、同步、鉴权 |
| `40-content-engineer.mdc` | Drill JSON、动画路径、计划数据 | `*.json`、`Drills/` |
| `50-qa-reviewer.mdc` | 验收 / DoD / 边界测试 | Phase 收尾 |
| `60-devops-release.mdc` | 构建、证书、TestFlight | `xcodebuild`、发布 |

## 技能（`.cursor/skills/`）

- `ios-architecture` — MVVM、模块边界、SPM
- `swiftui-design-system` — Design Token、组件、Dark Mode
- `swiftdata-cloudkit` — 本地模型与 CloudKit 公开库
- `rest-api-backend` — 自建 REST API 与用户侧同步、JWT、微信 OAuth
- `content-engineering` — Drill Schema、坐标系、内容生产 SOP

## 任务与文档

| 路径 | 用途 |
|------|------|
| [`tasks/MASTER-TASKS.md`](tasks/MASTER-TASKS.md) | F1–F11 → Phase → 任务与 DoD 索引 |
| [`tasks/phases/`](tasks/phases/) | P1–P8 阶段任务卡（详细） |
| [`tasks/PROGRESS.md`](tasks/PROGRESS.md) | 当前阶段、进行中、阻塞、四态任务与 Phase 归档指引 |
| [`tasks/FAILURE-LOG.md`](tasks/FAILURE-LOG.md) | 返工/回退轨迹（FL-NNN），供规则改进与复盘 |
| [`tasks/HUMAN-REQUIRED.md`](tasks/HUMAN-REQUIRED.md) | 必须人工完成的步骤 |
| [`tasks/compliance-checklist.md`](tasks/compliance-checklist.md) | 隐私清单、IAP、合规 |
| [`tasks/dependencies.md`](tasks/dependencies.md) | SPM / SDK 依赖与集成 SOP |
| [`tasks/appstore-assets.md`](tasks/appstore-assets.md) | 截图、ASO、元数据 |

## 产品规格源（权威）

- [`docs/04-功能规划.md`](docs/04-功能规划.md) — F1–F11
- [`docs/05-信息架构与交互设计.md`](docs/05-信息架构与交互设计.md) — 5 Tab、交互
- [`docs/06-技术架构.md`](docs/06-技术架构.md) — 技术栈与数据流
- [`docs/07-路线图与MVP.md`](docs/07-路线图与MVP.md) — 里程碑与计划内容
- [`docs/08-商业化与合规.md`](docs/08-商业化与合规.md) — Freemium、IAP

## 构建脚本

```bash
cd scripts && make help
```

## Steering（`.kiro/steering/`）

- `product.md` — 产品共识摘要
- `tech-stack.md` — 技术约束（全员只读）
- `agent-system.md` — 多智能体交接协议
- `observability.md` — 日志、崩溃、分析策略

## 讨论与决策

重大决策请追加 [`docs/00-讨论记录.md`](docs/00-讨论记录.md)。
