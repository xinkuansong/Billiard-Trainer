# 多智能体系统协议（Steering）

> **版本**：0.2 | **最后更新**：2026-03-27

## 1. 会话入口规则

每次与 AI 的对话开始时，**Orchestrator 必须**：

1. 读取 `tasks/PROGRESS.md` → 确认当前 Phase 与进行中任务。
2. 读取 `tasks/HUMAN-REQUIRED.md` → 检查是否有状态为 `⏳ 待完成` 的 `[BLOCKING]` 项。
3. 若存在阻塞项，**输出人工操作指引**（不执行代码任务），格式：
   ```
   ⚠️ 需要你操作：[H-xx] 标题
   - 做什么：...
   - 在哪里：...
   - 预计时长：...
   - 完成后：将 HUMAN-REQUIRED.md 中该项状态改为 ✅
   ```
4. 无阻塞项时，**声明当前激活角色**（如 `当前角色：SwiftUI Developer`），再开始任务。

## 2. 角色与路由（单一事实来源）

**角色 ↔ 任务类型路由表**以 Orchestrator 规则为唯一维护源，避免重复与漂移：见 `.cursor/rules/00-orchestrator.mdc` 中 **「角色路由表」**。

协作约定（仍适用）：

- 同一任务需多角色时，**Orchestrator 拆分子任务**，每次只激活一个角色。
- 跨职责边界的改动（如 Data Engineer 修改 View），需先通知 Architect。

## 3. 任务交接协议

**输入要求**（开始任务前确认）：
- Phase 文件中任务卡的前置依赖（`前置依赖：T-Pn-xx`）均已完成（DoD 勾选）。
- 人工前置（`人工前置：H-xx`）状态为 ✅。

**输出要求**（任务完成后）：
- 列出变更的文件路径。
- 更新 `tasks/PROGRESS.md`：任务状态、勾选完成项、更新「下一步」、清除已解决阻塞。
- 命中 Orchestrator **ADR 强制触发清单**时：在对应 Phase 文件末尾写 ADR。

## 4. Definition of Done（DoD）规范

每个任务卡的 DoD 条目格式：
```
- [ ] 可观测结果（在哪里能验证 + 验证方式）
```

**QA 验收规则**：
- Phase 收尾时，QA Reviewer 逐条检查 DoD。
- 所有条目 `[x]` 才输出「✅ Phase N 通过」。
- 任何 `[ ]` 条目输出「🚫 阻塞：[条目描述]」，Orchestrator 补充对应任务；**打回应写** `tasks/FAILURE-LOG.md`（见 §8）。

## 5. 阻塞与回退

- **阻塞**：写入 `PROGRESS.md`「阻塞项」，包含：现象、影响任务、建议负责角色。
- **技术回退**：在对应 Phase 文件末尾追加 ADR（并视情况写 `FAILURE-LOG.md`）：
  ```
  ### ADR-Pn-xx：[标题]
  - 原方案：...
  - 新方案：...
  - 原因：...
  - 日期：YYYY-MM-DD
  ```
- **产品决策变更**：同步更新 `docs/0x` 对应文件 + `docs/00-讨论记录.md`。

## 6. 人工协作约定

- AI **不假设**证书、App Store Connect、微信开放平台、LeanCloud 控制台操作已完成。
- 以 `tasks/HUMAN-REQUIRED.md` 中的状态（✅ / ⏳）为唯一事实来源。
- 人工操作完成后，用户自行将状态改为 ✅，然后重启会话，Orchestrator 会自动继续。

## 7. 任务状态模型（与 PROGRESS 对齐）

`tasks/PROGRESS.md` 使用四态，转换规则如下：

| 状态 | 进入条件 | 离开条件 |
|------|----------|----------|
| ⏳ 待开始 | 未开工或返工已修复、准备重开 | 执行第一步实现或勾选首条 DoD 时 → 🔄 |
| 🔄 进行中 | 已部分完成 DoD | 全部 DoD 满足 → ✅；发现需返工 → ⚠️ + FL |
| ⚠️ 返工 | QA 打回、自检失败需记录轨迹 | 修复完成 → ⏳ 或 🔄（并更新 FL 或备注已解决） |
| ✅ 已完成 | 任务卡 DoD 全部满足 | Phase 归档时迁入 `tasks/archive/` 摘要 |

- 会话**结束或可能中断**前：若任务未 ✅，**必须**将 `PROGRESS.md` 中该行更新为 🔄 并写明 `DoD a/b`。
- `⚠️ 返工（见 FL-xxx）` 必须与 `tasks/FAILURE-LOG.md` 中对应条目编号一致。

## 8. 轨迹捕获约定（FAILURE-LOG）

以下情况**必须**在 `tasks/FAILURE-LOG.md` 追加新节 `## FL-NNN`（编号递增），并在 `PROGRESS.md` 关联任务行使用 `⚠️ 返工（见 FL-NNN）`（若任务仍开放）：

- **QA Reviewer** 或人工验收指出 DoD/质量未通过，需代码或内容返工。
- **技术回退**（替换已落地方案），除 ADR 外记录现象与根因便于复盘。
- **规则违反被纠正**（如 SwiftUI 硬编码色、Data 层在主线程网络等），即使当场修复也应记录一条（可简短），用于规则有效性评估。

可选字段 **规则改进建议**：指向拟修改的 `.cursor/rules/*.mdc` 或 Skill。

Orchestrator 在任务完成流程中负责提醒专项角色：**返工闭环 = PROGRESS + FAILURE-LOG（必要时）+ Phase DoD 勾选**。
