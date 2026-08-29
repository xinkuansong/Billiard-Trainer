# MA-SDD：球迹 iOS 多智能体协同开发

本仓库使用 **Multi-Agent Spec-Driven Development（MA-SDD）**：以产品文档 `docs/01`–`docs/08` 为规格源，由 **Orchestrator（主控）** 调度专项角色，通过 `tasks/` 共享状态与进度。

> 本项目同时纳入跨项目 **Project Hub**（`/Users/song/projects/project-hub`）。本项目状态卡：`/Users/song/projects/project-hub/projects/13.billiard_trainer.md`。任何与 14 / 15 / 16 / 18 联动的事项（设计、教程、定理、图标）须按 `.cursor/rules/00-project-hub-sync.mdc` 同步。

## Codex 适配入口（每次会话必读）

在 Codex 中处理本仓库的任何请求时，先完整读取并遵循 [`.agents/skills/cursor-project-adapter/SKILL.md`](.agents/skills/cursor-project-adapter/SKILL.md)。该技能负责把现有 `.cursor/rules/`、`.cursor/agents/`、`.cursor/skills/` 与 `.kiro/steering/` 按当前任务路由到 Codex；专项文件仍为真源，禁止仅凭本页摘要替代读取。

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
| `data-engineer.md` | SwiftData / 自建 REST API（用户数据 + Drill OTA） | 模型与同步 |
| `content-engineer.md` | Drill JSON、计划内容 | `Resources/Drills/`、批量内容 |
| `tutorial-writer.md` | 序列 JSON → 图文精讲（应用课模板 + 理论教练话） | 「给 drill_xxx 写精讲」 |
| `qa-reviewer.md` | 验收 / DoD / 边界 | Phase 收尾、回归前检查 |
| `test-engineer.md` | XCTest / XCUITest / Jest 自动化测试 + 人工测试计划 | 功能完成后补测试、生成人工测试清单 |
| `manual-test-runner.md` | 人工测试执行引导 + 文档填充 | 执行 TP-Pn.md、收集结果、填充问题表与摘要 |
| `ui-reviewer.md` | UI 截图审查 + 问题报告 | 截图驱动视觉审查、问题路由 |
| `devops-release.md` | 构建、证书、TestFlight | `scripts/Makefile`、发布 |

## 角色与规则（`.cursor/rules/`）

| 规则文件 | 角色 | 典型触发 |
|----------|------|----------|
| `00-orchestrator.mdc` | 主控调度 + 人工检查 | 每次会话入口 |
| `02-voice-billiard-terms.mdc` | 语音近音 → 标准台球术语 | 疑似语音输入、错字像「加赛/走味/定刚」 |
| `10-ios-architect.mdc` | 架构 / 模块 / ADR | 新模块、重构、技术选型 |
| `20-swiftui-developer.mdc` | SwiftUI / Canvas / 设计系统 | `*View.swift`、界面 |
| `30-data-engineer.mdc` | SwiftData / 自建 REST API | Model、同步、鉴权 |
| `40-content-engineer.mdc` | Drill JSON、动画路径、计划数据 | `*.json`、`Drills/` |
| `50-qa-reviewer.mdc` | 验收 / DoD / 边界测试 | Phase 收尾 |
| `55-test-engineer.mdc` | XCTest / XCUITest / Jest 自动化测试 + 人工测试计划 | 功能完成后、人工测试清单生成 |
| `56-manual-test-runner.mdc` | 人工测试执行引导 + 文档填充 | 执行 TP-Pn.md、`tasks/test-plans/` |
| `57-ui-reviewer.mdc` | UI 截图审查 + 问题报告 | 截图驱动视觉审查、问题路由 |
| `60-devops-release.mdc` | 构建、证书、TestFlight | `xcodebuild`、发布 |

## 技能（`.cursor/skills/`）

- `ios-architecture` — MVVM、模块边界、SPM
- `swiftui-design-system` — Design Token、组件、Dark Mode
- `swiftdata-cloudkit` — SwiftData 与 Drill 内容（Bundle + 自建 API OTA，ADR-002）
- `rest-api-backend` — 自建 REST API 与用户侧同步、JWT、微信 OAuth
- `content-engineering` — Drill Schema、坐标系、内容生产 SOP
- `tutorial-authoring` — 走位序列 JSON → 图文精讲：digest 脚本、应用课模板、理论教练话转写、自查清单
- `tutorial-migration` — legacy 四段纯文本精讲 → 新版结构化精讲：路由判定、旧文本资产化、去伪几何断言、单杆技术课/规则流程课骨架
- `geometry-spatial-reasoning` — 几何/坐标/角度/相对位置：坐标契约、禁止脑算清单、数值草稿验证、不变量护栏
- `voice-billiard-terms` — 疑似语音输入时把近音/错字还原成标准台球与球迹术语（详表 `glossary.md`）
- `formation-training-intent` — 口述球形训练意图 → 表内两句成段（摆法 + 这一球形主要练）；只写研究表，不回写 JSON
- `plan-delegated-execution` — 多会话方案全程委派执行（串行）：每批派给执行子智能体（模型按 01-subagent-model-selection 确认，默认 cursor-grok-4.6-high-fast），主控独立验收 + 返工循环直至达标
- `plan-parallel-delegated-execution` — 串行版的并行扩展：批次分波（横切串行/页面域并行 ≤3）、worktree 隔离执行、主控串行合并逐批验证、模型按批次风险路由

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
| [`tasks/test-plans/`](tasks/test-plans/) | 人工测试计划（按 Phase，用户在真机/模拟器上执行） |
| [`tasks/ui-reviews/`](tasks/ui-reviews/) | UI 截图审查报告（UR-YYYYMMDD-页面简称.md） |

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
- `table-geometry.md` — 球桌几何常量（坐标/尺寸唯一真源）
- `content-data-contract.md` — **内容资产真源、标识符契约、数据流、训练数据口径**（与 schema.md / README.md 冲突时以此为准）

## 讨论与决策

重大决策请追加 [`docs/00-讨论记录.md`](docs/00-讨论记录.md)。
