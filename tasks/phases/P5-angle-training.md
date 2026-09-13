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
- [x] XCTest：`contactPointOffset(45°)` ≈ 0.707（误差 < 0.001）
- [x] XCTest：随机出 100 题，角袋/中袋比例在 55%–65% 之间

---

## T-P5-02 角度测试出题 UI（F10）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P5-01
- **产出物**：`Features/AngleTraining/Views/AngleTestView.swift`
- **设计参考**：`ui_design/tasks/P0-07/stitch_task_p0_07_angletestview_02/screen.png`

### DoD

- [x] 使用 R0 BT* 组件，不自建临时组件
- [x] 布局对照 `tasks/UI-IMPLEMENTATION-SPEC.md` 中对应设计截图
- [x] Light + Dark `#Preview` 通过视觉检查
- [x] 如有组件 API 或设计解读变更，追加 DR/PD 至 `tasks/IMPLEMENTATION-LOG.md` 并更新 `UI-IMPLEMENTATION-SPEC.md` Changelog
- [x] 顶视图球台（`BTAngleTestTable`）展示：目标球（随机位置）、袋口方向标记
- [x] 母球位置随机生成，位于合理击球区域（不贴近袋口）
- [x] 数字键盘输入估计角度（0–90°整数）
- [x] 「确认」按钮提交答案
- [x] 每题显示题号（如「第 5 题 / 共 20 题」）

---

## T-P5-03 角度测试答案动画（F10）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P5-02
- **产出物**：`AngleTestView.swift` 动画部分
- **设计参考**：`ui_design/tasks/P0-07/stitch_task_p0_07_angletestviewresult_02/screen.png`

### DoD

- [x] 使用 R0 BT* 组件，不自建临时组件
- [x] 布局对照 `tasks/UI-IMPLEMENTATION-SPEC.md` 中对应设计截图
- [x] Light + Dark `#Preview` 通过视觉检查
- [x] 如有组件 API 或设计解读变更，追加 DR/PD 至 `tasks/IMPLEMENTATION-LOG.md` 并更新 `UI-IMPLEMENTATION-SPEC.md` Changelog
- [x] 提交后动画：正确击球路线（绿色）高亮，用户答案路线（橙色）对比展示
- [x] 目标球面标注红点（正确接触点位置）
- [x] 显示：用户答案、正确答案、误差值（±X°）
- [x] 误差 ≤ 3° 显示绿色「精准」，3°–10° 显示橙色「接近」，>10° 显示红色「偏差较大」
- [x] 「下一题」按钮，动画消退后出下一题

---

## T-P5-04 角度测试历史记录

- **负责角色**：Data Engineer + SwiftUI Developer
- **前置依赖**：T-P5-03, T-P2-02
- **产出物**：`AngleTestResult` 持久化、历史视图

### DoD

- [x] 使用 R0 BT* 组件，不自建临时组件
- [x] 布局对照 `tasks/UI-IMPLEMENTATION-SPEC.md` 中对应设计截图
- [x] Light + Dark `#Preview` 通过视觉检查
- [x] 如有组件 API 或设计解读变更，追加 DR/PD 至 `tasks/IMPLEMENTATION-LOG.md` 并更新 `UI-IMPLEMENTATION-SPEC.md` Changelog
- [x] 每次提交答案后，`AngleTestResult` 写入 SwiftData
- [x] 角度 Tab 内「历史」入口：显示近期平均误差趋势（折线图，每组 5 题）
- [x] 分别展示角袋/中袋误差趋势
- [x] 历史数据在 App 重启后保持

---

## T-P5-05 进球点对照表（F11）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P5-01
- **产出物**：`Features/AngleTraining/Views/ContactPointTableView.swift`
- **设计参考**：`ui_design/tasks/P1-05/stitch_task_p1_05_contactpointtableview_02/screen.png`

### DoD

- [x] 使用 R0 BT* 组件，不自建临时组件
- [x] 布局对照 `tasks/UI-IMPLEMENTATION-SPEC.md` 中对应设计截图
- [x] Light + Dark `#Preview` 通过视觉检查
- [x] 如有组件 API 或设计解读变更，追加 DR/PD 至 `tasks/IMPLEMENTATION-LOG.md` 并更新 `UI-IMPLEMENTATION-SPEC.md` Changelog
- [x] 交互式滑块（0°–90°，步进 1°）：拖动时目标球示意图实时更新接触点位置
- [x] 数值显示：当前角度 + 偏移百分比（sin(α)×100%）
- [x] 完整静态对照表（13 个标准角度：0°/10°/15°/20°/25°/30°/35°/40°/45°/48.6°/60°/75°/90°）
- [x] 每行含通称标记（全球/二分之一球/四分之三点/极薄球）
- [x] 原理说明：简要解释 `偏移 = sin(α) × R`

---

## T-P5-06 Freemium 每日次数限制

- **负责角色**：Data Engineer
- **前置依赖**：T-P5-02
- **产出物**：`Features/AngleTraining/AngleUsageLimiter.swift`

### DoD

- [x] 免费用户每日测试上限：20 题
- [x] 达到上限时显示引导订阅提示（`BTPremiumLock` 变体）
- [x] 每日计数在本地重置（通过日期比较，不依赖服务器）
- [x] 付费用户无限制

---

## QA-P5 P5 验收

- **负责角色**：QA Reviewer

### 验收要点

- [x] **纯离线**：断网状态下角度 Tab 完整可用（测试 + 对照表）— 全部计算本地，零网络依赖
- [x] **角度计算正确性**：手动验证 30°（偏移应 ≈ 50%R）、45°（偏移 ≈ 70.7%R）— XCTest 覆盖
- [x] **自适应权重**：连续答错某个角度区间后，该区间出题频率明显增加 — AdaptiveQuestionEngine 加权选择已实现
- [x] **滑块流畅度**：对照表滑块 Slider + Canvas 实时渲染 — 无重计算，可流畅拖动
- [x] **每日限制**：免费用户第 21 题出现引导，重置后第二天可再答 20 题 — AngleUsageLimiter + XCTest 覆盖

### 验收结论

✅ **P5 通过** — 代码审查 + 自动化测试（22/22）通过 + 设计对齐修复完成。人工 TP-P5 待 R-UI 后执行。

---

## ADR 记录区

### ADR-P5-01 — v62 移动端渲染管线转正：单一闸门、全交互页默认、球房独立装配（2026-09-14）

- **状态**：已采纳（用户口头裁定「真机上没问题，收口吧」，2026-09-14）。
- **背景**：v62 从 S95 起把「移动基础光照（IBL + 聚光阴影）→ S267 参考光照（面光 + GGX 着色器）→ 表面质感（球杆清漆/袋口皮革/球面）→ 烘焙球房」分四层试点，每层各带闸门（`MobileTableRendering.previewRequested`、`MobileReferenceLighting.requested`、`surfaceFinishesRequested`，全部 `#if DEBUG`，模拟器还要 `-v62.s267Lighting`），并且只由 `FreePlayView`（非每日清台）、`ShotSimulationView`、`SceneAimingView`（仅 3D）三页显式 opt-in。原因是真机 60fps/热/内存预算未验，试点策略此后一直未回收。结果：Release 无人可见；同一页「自由击球」与「每日清台」观感不同；动作库详情、翻袋/颠球、拆球、开球等球桌页仍走旧 3 灯管线；球房被塞在 `applySurfaceFinishes` 里随材质一起装。
- **决策**：
  1. 只保留一个闸门 `MobileTableRendering.isEnabled`：Release 恒为 `true`；Debug 保留 `-v62.legacyRendering` / `V62_LEGACY_RENDERING=1` 作对照诊断逃生口。`MobileReferenceLighting.requested` 退化为该闸门的别名，`previewRequested` / `surfaceFinishesRequested` 及 `-v62.s267Lighting`、`-v62.mobileRendering`、`-v62.legacySurfaceFinishes`、`RENDER_QUALITY_VALIDATION` 分支删除。不存在「移动基础光照但无参考光照」的中间档。
  2. `AngleTrainingScene.setupScene(mobileRendering:)` 默认值改为 `MobileTableRendering.isEnabled`；`PositionPlayViewModel.setupScene` / `AimingQuizViewModel.setupScene` 同步。页面不再逐页 opt-in，`FreePlayView` 每日清台亦纳入；`contentIsAnimating` 节流不再依赖闸门。
  3. 球房 `installReferenceRoom()` 从 `MobileReferenceLighting.applySurfaceFinishes` 移出，成为 `setupScene` 内独立装配步骤（仍仅 `perspective3D` 显示）。设置「球房风格」入口与外观组合预览的 `#if DEBUG` 去除。
  4. 离线渲染器（`DrillThumbnailRenderer`、`TableFigureRenderer`、`BallFaceRenderer`、`SequenceVideoExporter`、`BallFeelView.snapshot`）显式传 `mobileRendering: false`，已烘焙缩略图/导出视频/卡片底图/球面小图产物不变；是否让离线产物跟随外观偏好另立决策。
- **备选与放弃**：a) 保持逐页 opt-in 并逐页补齐 —— 放弃，闸门叠加是不一致的根因；b) Release 默认关、Debug 开 —— 放弃，与用户「真机没问题」裁定相悖，且再次让功能不可见；c) 离线渲染器同样切到移动管线 —— 暂不做，会改变已在包内的 PNG/视频口径，需要重烘焙与内容侧评审。
- **影响**：所有交互式球桌页共享一套光照/材质/球房；2D 视图台呢观感统一到参考光照口径（S267 调色）。功耗方面仅自由击球/击球模拟两页带 `contentIsAnimating` 节流，其余页面沿用连续渲染（未变）。
- **验证**：`make build` BUILD SUCCEEDED；定向单测 `TableAppearanceTests`/`ClothAppearanceTests`/`BallStickerTests`/`TrajectoryRendererTests`/`PocketLeatherIntegrationTests`（跳过 2 项，见下）0 失败。`RenderQualityV62Tests` 结果见 PROGRESS 条目。
- **已知问题（非本 ADR 引入，但被暴露）**：模拟器 iOS 26.3 对主线程连续阻塞约 ≥30s 的测试宿主发 SIGKILL（`legacy 场景 + 45s 忙等` 亦复现，无崩溃报告）。`PocketLeatherIntegrationTests.testArchivedPocketAndFreeSequenceStepsRestoreSelection` 在主线程同步跑 v63 空间物理约 33s（legacy 亦如此），移动管线多出的 ~0.6s 场景装配使其越线；`testNeutralThumbnailAfterSelectedScene` 首帧 `SCNRenderer` 热身约 8s，偶发拉长越线；`testPlanRealSolvePlayAndUndoRestoreLeather` 在 legacy 下同样因求解 >15s 失败。三项应由 v63 线程处理（求解下主线程 / 渲染预热），不在本 ADR 范围。
