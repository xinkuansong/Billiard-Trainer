# P11 — 走位编排器与击打序列（Position-Play Composer）

> 自由摆球（母球 + 任意子集 1–15 号）→ 逐杆指定目标球 + 袋口 → 物理引擎真实求解母球走位 → 串成可中途改摆的击打序列；序列可持久化（SwiftData）、导出为 Drill JSON 内容、在 app 内导出 SceneKit 真台视频/GIF。两种形态都挂在「角度」Tab（编排台 → 进阶分组，走位训练 → 训练分组），不进球库。

## 任务清单

| 任务 | 说明 | 状态 |
|------|------|------|
| T-P11-01 | `PositionPlayModels`：BoardSnapshot / PlannedShot / SequenceStep / PositionPlaySequence | ✅（2026-06-05）|
| T-P11-02 | 物理多球：`ShotInput.obstacles` + `ShotPrediction.finalPositions`；`runShot` 放置障碍球；`PhysicsEngineTests` 多球障碍用例 | ✅（2026-06-05，2 例全过）|
| T-P11-03 | `PositionPlayViewModel`：N 球显隐/拖放、目标球选择、obstacles 组装、后台单杆求解与播放 | ✅（2026-06-05）|
| T-P11-04 | `PositionPlayComposerView` + 角度 Tab 进阶入口（`AngleRoute.positionPlayComposer`） | ✅（2026-06-05）|
| T-P11-05 | 序列链与时间轴：逐杆生成 Step、进袋离场回库、中途改摆（截断重录） | ✅（2026-06-05）|
| T-P11-06 | `PositionPlaySequenceEntity`（SwiftData）+ 注册 `ModelContainerFactory` + 导出 Drill JSON | ✅（2026-06-05）|
| T-P11-07 | `Core/Media`：SceneKit 逐帧离屏 + `VideoWriter`（AVAssetWriter）+ GIF + 分享/存相册 | ✅（2026-06-05）|
| T-P11-08 | 走位训练形态 + 多杆序列播放器 + 角度 Tab 训练入口（`AngleRoute.positionPlayTraining`） | ✅（2026-06-05）|

> 落地：`xcodegen` 收纳 14 个新源文件，`make build` ✅、`QiuJiTests/PhysicsEngineTests` 23/23、lint 0。

## DoD

- a. 自由摆球：母球 + 任意子集可上/下桌、拖放合法（不重叠/不压袋）、进袋离场回库。
- b. 单杆求解：每杆只对「选中目标球 + 指定袋口」求解，其余球作障碍真实参与碰撞。
- c. 序列：逐杆链式推进，任意 Step 可改摆并截断重录。
- d. 持久化与导出：序列可保存/重开；可导出符合 `schema.md` 的 Drill JSON。
- e. 视频：可在 app 内导出 mp4/GIF 并分享/存相册。
- f. `make build` 通过、`QiuJiTests` 全绿、lint 0。

---

## ADR 记录区

### ADR-P11-01 — 走位编排器：多球单杆求解 + 序列内容模型 + 视频导出（命中多项 ADR 触发）

- **日期**：2026-06-05
- **状态**：✅ 已采纳（用户多轮澄清后定稿）。
- **背景**：用户提出「类似分离角的页面，桌上自由摆母球 + 任意目标球，逐杆选目标球+袋口、调力度/打点控制母球落点，串成击打序列」，用途为教学视频制作与走位训练。现有「分离角与走位」(`ShotSimulationView`) 已具备拖球/选袋/调参/真实求解/播放，但限定母球 + 1 目标球；物理引擎 `EventDrivenEngine` 本身是 N 球通用引擎，限制仅在 `ShotPredictor` 门面。USDZ 已含母球 + 15 号球（`TableModelLoader` 按键 `cueBall`/`_1`..`_15` 提取，`AngleTrainingScene.allBallNodes` 加载）。
- **决策**：
  1. **多球单杆求解**：`ShotInput` 增 `obstacles`（其余在桌球作静止碰撞体），`ShotPredictor.runShot` 一并 `setBall`；瞄准评分仍只盯 `cueBall`/`object` 两个具名球（零评分改动）。每杆只对「选中目标 + 指定袋口」求解，作者给定力度/打点，引擎只算真实轨迹与落点（不替作者找进袋角，承袭 ADR-P10-01「意图 → 真实轨迹」哲学）。
  2. **序列内容模型**（`Core/PositionPlay/PositionPlayModels`）：`BoardSnapshot`（在桌球键→归一化坐标）/ `PlannedShot` / `SequenceStep`（before/after/potted）/ `PositionPlaySequence`。序列真相 = 一串桌面快照；每杆为快照转移；进袋球离场回库；母球 scratch 走同一离场逻辑（无特殊分支）；任意 Step 可改摆并截断重录。球号无规则语义（不写八球规则引擎）。
  3. **持久化与内容管线**：新增 SwiftData 模型 `PositionPlaySequenceEntity`（现有 `CustomPlan` 只能引用 `drillId`，不能内嵌自定义内容），注册 `ModelContainerFactory`；并导出为符合 `schema.md` 的 Drill JSON（`shotIntent.shots[]` 逐 Step），供内容工程/训练复用。
  4. **多杆回放**：新建专用序列播放器（多杆串播），不改造单杆 `DrillAnimation`/`DrillSceneView`（运行时仅消费第一杆，改造回归风险高）。
  5. **视频导出**（`Core/Media`）：复用 SceneKit USDZ 真台离屏（`DrillThumbnailRenderer` 的 `SCNRenderer` 范式扩为逐帧 `snapshot(atTime:)`）+ `VideoWriter`（AVAssetWriter，从 `DrillShotReconstructionTests` 抽出到 app 模块）+ GIF（`CGImageDestination`）+ 分享/存相册。
  6. **信息架构**：编排台 → 角度 Tab 进阶分组（`AngleRoute.positionPlayComposer`），走位训练 → 角度 Tab 训练分组（`AngleRoute.positionPlayTraining`）；仅扩 `AngleRoute` + `angleDestination` 分发，不动 5 Tab 结构、不进球库。
- **理由**：复用既有引擎/坐标桥/球资源/单杆交互，改动面集中在新模型 + 新页面 + `ShotInput` 小扩展；与 P10 内容管线方向一致（作者描述意图、引擎算真实轨迹），复用度高、回归风险低。
- **影响（命中 ADR 触发）**：
  - **新增 SwiftData 模型**：`PositionPlaySequenceEntity` + `ModelContainerFactory` 注册（迁移：纯新增实体，现有 Schema 向后兼容）。
  - **新内容类型/数据策略**：走位序列内容（持久化 + Drill JSON 导出）。
  - **跨模块边界**：物理引擎多球求解通路（`ShotInput.obstacles`）；新增 `Core/Media` 视频导出模块。
  - 新增文件：`Core/PositionPlay/PositionPlayModels.swift`、`Features/PositionPlay/**`、`Data/Models/PositionPlaySequenceEntity.swift`、`Core/Media/**`；改 `ShotPredictor.swift`、`AngleHomeView.swift`、`MainTabView.swift`、`ModelContainerFactory.swift`、`AngleSceneView.swift`（追加可选 `onBallTapped`）。
- **替代方案**：① 改造 `DrillAnimation`/`DrillSceneView` 支持多杆——回归风险高、与单杆渲染耦合，未采纳；② 走位序列走球库 Tab——用户明确要求放角度 Tab，未采纳；③ 视频用 CoreGraphics 2D（测试现状）——不如 SceneKit 真台直观，作为降级备选保留。
- **遗留 TODO**：多球求解性能（满台单杆 ~数百 ms，编辑模式可接受，跟手度后续优化）；序列云端 OTA（ADR-002 通路）；训练形态评分细化。
