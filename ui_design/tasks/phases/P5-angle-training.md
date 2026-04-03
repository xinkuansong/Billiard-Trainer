# P5 — Angle Training（角度感知训练）

> **目标**：完整的角度 Tab，包含自适应角度测试（F10）和进球点对照表（F11）。
> **特点**：纯本地计算，零网络依赖，离线完整可用。
> **前置 Phase**：P4 通过 QA

---

## T-P5-01 角度计算引擎 + 自适应算法

- **负责角色**：iOS Architect
- **前置依赖**：无（可并行 P4）
- **产出物**：`Features/AngleTraining/AngleCalculator.swift`、`AdaptiveQuestionEngine.swift`

### DoD

- [x] `AngleCalculator.contactPointOffset(angle:)` → `sin(α) × R`，精度 ≤ 0.001
- [x] `AngleCalculator.randomAngle(pocketType:)` → 角袋 5°–85°，中袋 15°–60°，以 5° 为步进
- [x] `AdaptiveQuestionEngine` 实现加权出题：
  - 基础权重 30% + 误差历史权重 70%
  - 以 5° 为单位划分 18 个区间，各区间记录最近 10 次误差
  - 角袋（60%比例）/ 中袋（40%比例）分开统计
- [ ] XCTest：`contactPointOffset(45°)` ≈ 0.707（误差 < 0.001）
- [ ] XCTest：随机出 100 题，角袋/中袋比例在 55%–65% 之间

---

## T-P5-02 角度测试出题 UI（F10）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P5-01
- **产出物**：`Features/AngleTraining/Views/AngleTestView.swift`

### DoD

- [x] 顶视图球台（`BTAngleTestTable`）展示：目标球（随机位置）、袋口方向标记
- [x] 母球位置随机生成，位于合理击球区域（不贴近袋口）
- [x] 数字键盘输入估计角度（0–90°整数）
- [x] 「确认」按钮提交答案
- [x] 每题显示题号（如「第 5 / 20 题」）+ 进度条

---

## T-P5-03 角度测试答案动画（F10）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P5-02
- **产出物**：`AngleTestView.swift` 动画部分

### DoD

- [x] 提交后动画：正确击球路线（绿色）高亮，用户答案路线（橙色虚线）对比展示
- [x] 目标球面标注红点（正确接触点位置）
- [x] 显示：用户答案、正确答案、误差值（±X°）
- [x] 误差 ≤ 3° 显示绿色「精准」，3°–10° 显示橙色「接近」，>10° 显示红色「偏差较大」
- [x] 「下一题」按钮 + 测试完成总结页

---

## T-P5-04 角度测试历史记录

- **负责角色**：Data Engineer + SwiftUI Developer
- **前置依赖**：T-P5-03, T-P2-02
- **产出物**：`AngleTestResult` 持久化、历史视图

### DoD

- [x] 每次提交答案后，`AngleTestResult` 写入 SwiftData（复用 P2 的 LocalAngleTestRepository）
- [x] 角度 Tab 内「历史」入口：显示近期平均误差趋势（Canvas 折线图，每组 5 题）
- [x] 分别展示角袋/中袋误差趋势（Picker 分段切换）
- [x] 历史数据在 App 重启后保持（SwiftData 持久化）

---

## T-P5-05 进球点对照表（F11）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P5-01
- **产出物**：`Features/AngleTraining/Views/ContactPointTableView.swift`

### DoD

- [x] 交互式滑块（0°–90°，步进 1°）：拖动时目标球示意图实时更新接触点位置
- [x] 数值显示：当前角度 + 偏移百分比（sin(α)×100%）
- [x] 完整静态对照表（13 个标准角度：0°/10°/15°/20°/25°/30°/35°/40°/45°/49°/60°/75°/90°）
- [x] 每行含小型球面示意图（Canvas 标注接触点 + 袋口方向箭头）
- [x] 原理说明：简要解释 `偏移 = sin(α) × R`

---

## T-P5-06 Freemium 每日次数限制

- **负责角色**：Data Engineer
- **前置依赖**：T-P5-02
- **产出物**：`Features/AngleTraining/AngleUsageLimiter.swift`

### DoD

- [x] 免费用户每日测试上限：20 题
- [x] 达到上限时显示引导订阅提示（crown.fill 按钮 + 说明文字）
- [x] 每日计数在本地重置（通过日期比较，不依赖服务器）
- [x] 付费用户无限制（isPremium flag，P7 接入 StoreKit 后生效）

---

## QA-P5 P5 验收

- **负责角色**：QA Reviewer

### 验收要点

- [ ] **纯离线**：断网状态下角度 Tab 完整可用（测试 + 对照表）
- [ ] **角度计算正确性**：手动验证 30°（偏移应 ≈ 50%R）、45°（偏移 ≈ 70.7%R）
- [ ] **自适应权重**：连续答错某个角度区间后，该区间出题频率明显增加（可通过日志验证）
- [ ] **滑块流畅度**：对照表滑块拖动时接触点实时更新，无明显卡顿
- [ ] **每日限制**：免费用户第 21 题出现引导，重置后第二天可再答 20 题

---

## ADR 记录区
