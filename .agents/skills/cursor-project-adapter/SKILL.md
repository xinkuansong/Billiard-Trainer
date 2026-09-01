---
name: cursor-project-adapter
description: 适配本项目现有 Cursor 配置，使 Codex 在每次会话启动及执行仓库任务时，按需加载 .cursor/rules、.cursor/agents、.cursor/skills 与 .kiro/steering 中适用的指令。仅用于本仓库的配置路由，不替代专项技能。
---

# Cursor 项目适配器

本技能是 Codex 与本仓库 Cursor 配置之间的路由层。它只决定需要读取哪些现有配置；专项规则与技能文件仍是真源。不要复制、概括或改写专项文件来替代原文。

## 每次会话启动

1. 读取 `.cursor/rules/00-orchestrator.mdc` 全文，并执行其中适合当前请求的启动检查。
2. 按 `AGENTS.md` 读取项目状态文件。轻量问答或元配置任务遵循 Orchestrator 的轻量任务分流，不因无关人工阻塞项停止。
3. 判断当前请求属于问答、诊断、实现、验收、人工测试、发布还是多批次方案，再按下表加载最小必要配置。
4. 向用户声明当前角色；若任务跨角色，只在切换实际发生时声明。

## 配置优先级与冲突

始终遵守当前会话的 system/developer/user 指令和根目录 `AGENTS.md`。在项目配置内部：

1. 产品与数据真源：`docs/`、`.kiro/steering/` 中明确标为真源的文件。
2. 调度与角色约束：`.cursor/rules/*.mdc`。
3. 专项工作流：`.cursor/skills/*/SKILL.md` 及其直接引用资源。
4. 角色提示：`.cursor/agents/*.md`。

Cursor 专属能力不得假装在 Codex 中存在。`.mdc` 的 `alwaysApply` 和 `globs` 不会自动生效，必须由本技能显式路由；Cursor 模型名、`@agent`、worktree 或 UI 操作应映射到当前实际可用的 Codex 能力。无法等价映射时，说明差异并使用最接近的安全流程。

## 任务路由

| 任务 | 必读规则 | 按需角色 | 必读技能 |
|---|---|---|---|
| 架构、模块、SPM、ADR | `.cursor/rules/10-ios-architect.mdc` | `.cursor/agents/ios-architect.md` | `.cursor/skills/ios-architecture/SKILL.md` |
| SwiftUI、Canvas、组件、视觉实现 | `.cursor/rules/20-swiftui-developer.mdc` | `.cursor/agents/swiftui-developer.md` | `.cursor/skills/swiftui-design-system/SKILL.md` |
| SwiftData、同步、鉴权、后端 | `.cursor/rules/30-data-engineer.mdc` | `.cursor/agents/data-engineer.md` | 在 `swiftdata-cloudkit` 与 `rest-api-backend` 中选择适用者 |
| Drill/Plan JSON、动画路径、内容生产 | `.cursor/rules/40-content-engineer.mdc` | `.cursor/agents/content-engineer.md` | `.cursor/skills/content-engineering/SKILL.md` |
| 动作库/练习卡片/详情/精讲的学员文案 | 当前字段对应规则 | Content Engineer；精讲再叠 Tutorial Writer | `.cursor/skills/billiard-copy-editing/SKILL.md`，再由其按字段加载专项技能 |
| 精讲创作或迁移 | `.cursor/rules/40-content-engineer.mdc` | `.cursor/agents/tutorial-writer.md` | `billiard-copy-editing` + 在 `tutorial-authoring` 与 `tutorial-migration` 中选择适用者 |
| 球形训练意图录入或完善 | `.cursor/rules/40-content-engineer.mdc` | `.cursor/agents/content-engineer.md` | `billiard-copy-editing` + `.cursor/skills/formation-training-intent/SKILL.md` |
| 几何、坐标、角度、相对位置 | 当前角色规则 | 当前任务角色 | `.cursor/skills/geometry-spatial-reasoning/SKILL.md`，并核对 `.kiro/steering/table-geometry.md` |
| QA、DoD、边界验收 | `.cursor/rules/50-qa-reviewer.mdc` | `.cursor/agents/qa-reviewer.md` | 读取任务卡与验收真源 |
| 自动化测试或测试计划 | `.cursor/rules/55-test-engineer.mdc` | `.cursor/agents/test-engineer.md` | 读取对应测试真源 |
| 人工测试执行 | `.cursor/rules/56-manual-test-runner.mdc` | `.cursor/agents/manual-test-runner.md` | 读取对应 `tasks/test-plans/TP-Pn.md` |
| UI 截图审查 | `.cursor/rules/57-ui-reviewer.mdc` | `.cursor/agents/ui-reviewer.md` | 读取 UI 规格与审查模板 |
| 构建、证书、TestFlight | `.cursor/rules/60-devops-release.mdc` | `.cursor/agents/devops-release.md` | 读取构建脚本与发布文档 |
| 疑似语音或台球近音词 | `.cursor/rules/02-voice-billiard-terms.mdc` | 当前任务角色 | `.cursor/skills/voice-billiard-terms/SKILL.md`，需要时再读 `glossary.md` |
| 复杂问题清单拆批 | Orchestrator 规则 | Orchestrator | `.cursor/skills/issue-collection-restructure/SKILL.md` |
| 执行既有批次方案 | Orchestrator + 对应专项规则 | 对应任务角色 | `.cursor/skills/plan-batch-execution/SKILL.md` |
| 用户明确要求委派或并行智能体 | Orchestrator + `.cursor/rules/01-subagent-model-selection.mdc` | 读取被委派角色文件 | 在 `plan-delegated-execution` 与 `plan-parallel-delegated-execution` 中选择适用者 |
| 结构化辩论 | `.cursor/rules/70-debate-protocol.mdc` 及议题规则 | 对应 debate agent | 在 idea generation/evaluation/recording 中选择当前轮需要者 |

一个任务可叠加多个技能，但只读取确实影响当前任务的文件。选中某个 `SKILL.md` 后必须完整读取；它引用的资源仅在该分支需要时读取。

## 智能体适配

- 普通任务默认由当前 Codex 直接承担对应角色；读取角色文件不等于必须创建子智能体。
- 只有用户明确要求子智能体、委派或并行执行，或更高优先级指令明确要求时，才使用 Codex 协作智能体。
- 创建子智能体前，读取目标 `.cursor/agents/<role>.md` 和适用规则，把二者作为任务约束传递；不得声称 Cursor 的模型 slug 在 Codex 可用。
- 多智能体共享工作区时，先划分不重叠文件范围；除非所用执行技能明确要求并且当前环境支持，否则不要假设自动 worktree 隔离。
- 主控必须独立验收子智能体产物；子智能体自报完成不等于任务完成。

## 完成与回写

实质性项目工作完成后，按 `.cursor/rules/00-orchestrator.mdc` 更新进度、任务卡、ADR、DR/PD/FL 或 Project Hub；纯解释、只读检查以及本适配器自身维护只在确有项目状态变化时写进度。所有“完成/通过”声明必须有真实验证输出；未运行的检查明确标为未验证。
