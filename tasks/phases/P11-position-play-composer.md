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

### ADR-P11-02 — 编排台交互/布局重构（击球状态机 + 完整拖拽 + 真实球面）

- **日期**：2026-06-05
- **状态**：✅ 已采纳（用户体验反馈后定稿）。
- **背景**：首版编排台 `play()` 为「预览」，击打后自动复位回起点，与「逐杆编排」心智冲突；「重置」破坏性地清空整条序列；球库为单行数字 token、点击放置/长按移除；顶部状态栏占位且「是否进袋」用整条文字；球库半透明压在球桌上。用户逐条反馈要求修正。
- **决策**：
  1. **击球状态机（保留两个按钮）**：`PositionPlayViewModel` 新增 `pendingBefore`（本杆击打前快照，未击球时随桌面同步刷新）与 `hasStruck`。「击球」(`play`) 播真实动画后球停在 `finalPositions` 终局、进袋球离场（`finishStrike`），不再复位；任何编辑入口（拖球/选目标/换袋/调力度打点）若 `hasStruck` 先 `restorePendingBefore()` 软回退再重算，避免从终局二次求解。「记录」(`recordStep`) 以 `pendingBefore` 为 before、引擎结果为 after。「重打」(`replayCurrent`) 仅把桌面退回本杆击打前，不触动已记录的杆；原「清空并重来」(`resetAll`) 降级进右上更多菜单。
  2. **完整拖拽**：球库球可拖到桌面任意点落位（SwiftUI `DragGesture` → 经 `TableProjector.unproject` 反投影到台面 → `clampMultiBall`）；桌上球拖回球库区域松手即移除（`AngleSceneView.onDragEndedAt` 带结束屏幕坐标，与球库 frame 比对）。保留「点球面快速上桌 / 点桌上球选目标 / 点袋口选袋」。
  3. **真实球面球库**：新增 `Core/Scene/BallFaceRenderer`，进编排台时离屏（`SCNRenderer.snapshot`）逐颗烘焙 USDZ 球面圆形小图并内存缓存，双行 `LazyHGrid` 展示，替代数字 token。
  4. **夹角浮标贴目标球**：移除顶部状态栏；夹角 + 选中环用 SwiftUI overlay 经 `TableProjector.project` 跟随目标球屏幕投影显示；可行性用环色（灰=不可行）、母球进袋用红点表达，去掉整条文字提示。
  5. **布局不挡桌**：球库改为实心底栏在 `VStack` 流内，球桌区独占上方铺满，互不遮挡；顶视相机取景留余量。
- **理由**：用最小跨层桥接（`TableProjector`、`onDragEndedAt`）满足编排所需的拖拽与浮标，不改物理/序列模型；球面缩略图复用既有离屏渲染范式。
- **影响**：改 `AngleSceneView.swift`（新增 `TableProjector`、`onDragEndedAt`，旧 `onDragEnded` 签名不变，其它调用方零改动）、`PositionPlayViewModel.swift`、`PositionPlayComposerView.swift`；新增 `Core/Scene/BallFaceRenderer.swift`。
- **替代方案**：① 击球即记录（合并为一个按钮）——用户选择保留「击球/记录」分离，未采纳；② 球库仅点击放置 + 拖出移除（折中）——用户选择完整拖拽，未采纳；③ 用自绘 asset 球杆图标——改用 SwiftUI `Shape`（`CueStickShape`）免资源管线。
- **迭代修正（同日，用户运行后反馈）**：
  1. **球库球面空白**——`BallFaceRenderer` 相机距球约 0.28（米）小于 `SCNCamera` 默认 `zNear=1.0`，球被近裁剪面切掉。修正 `cam.zNear=0.001`/`zFar=100`。（注：此修复不充分，真正根因见 ADR-P11-03 ④。）
  2. **角度不跟随目标球 + 击球后不消失 + 风格对齐「角度与打点」**——撤销「夹角浮标贴目标球」（投影跟随的环+药丸），改为场景顶部**固定胶囊 chip**（复用 `AngleDynamicView` 的 `metricItem`/厚度名样式，绑定 `cutAngleDeg`，击球后仍保留；母球进袋以红点+「母球进袋」内联表达）。
  3. **新增随机球形**——侧栏「随机」按钮 → sheet 滑条选目标球数（1–15，不含母球），`PositionPlayViewModel.randomLayout` 随机不重复球号 + `randomSpreadPositions` 安全内区自适应间距分散摆放；母球为自由球保留现状由用户自摆。
  4. **球桌占比偏小**——顶视 `topDownOrthographicScale` 由 `innerLength*0.62` 收紧到 `*0.54`，球桌更充满场景区。

### ADR-P11-03 — 编排台一致性契约 + 自由瞄准模式 + 状态反馈体系（系统性审查后整改）

- **日期**：2026-06-10
- **状态**：✅ 已采纳（用户确认审查结论后实施）。
- **背景**：对编排台做系统性审查发现 15 项问题，按根因归并为四类：①「击球→记录」依赖 UI 选中态（目标球进袋后 `selectedTargetKey` 被清空 → 记录静默失效，P0）+ 记录无 `isComputing` 闸（竞态可录入与陈旧预测错配的步，P1）；②预览/随机/清空直接改写工作桌面但不处理序列链（链断裂，P0/P1）；③反馈链断裂（`statusText` 写而不显、求解中无指示、已击球待记录无可视化、障碍挡线无原因）；④能力边界（每杆必须进袋 → 无法编排安全球/轻推走位；力度下限 1.2 m/s 过高、m/s 不直觉；球库球面图不显示）。
- **决策**：
  1. **求解上下文打包（一致性契约）**：`PositionPlayViewModel.SolvedShot = (before 快照, PlannedShot 作者意图, ShotPrediction)` 在求解派发时原子打包，「击球/记录」只消费它，与 UI 选中态、求解竞态彻底解耦；`recordStep`/`play` 增加 `!isComputing` 闸；预览/清空走 `invalidatePendingPredict()`（generation 递增）作废在途解。
  2. **只读预览模式**：时间轴点按 = 进入 `previewingStepIndex` 只读预览（保存 `boardBeforePreview`，顶部黄色横幅 + 「返回编排」），预览中一切编辑/击球/记录入口 guard 禁用；退出恢复工作桌面。回退（截断重录）移入长按 context menu + 确认对话框；新增逐杆备注（长按编辑，播放器状态卡展示）。
  3. **自由瞄准模式（非进袋球）**：`AimMode.pocket/.free` 顶部分段切换。自由模式不选目标球/袋口，点桌面/球/袋口设定瞄准方向（`AngleSceneView` 新增 `onTableTapped` 反投影回调）；引擎走新增 `ShotPredictor.simulateFree`（直瞄真实模拟、恒 feasible、全部在桌球参与碰撞、输出 `extraBallPaths` 被带动球轨迹）。模型 `PlannedShot.freeAim: CanvasPoint?`（归一化系方向向量，旧数据解码为 nil 向后兼容；自由杆 `targetKey`/`pocket` 为空串）。新增 `PositionPlayShotSolver` 统一三处单杆离线求解（编排台/序列播放器/视频导出器，原各自重复实现已删）；含自由杆的序列不可导出 Drill JSON（`canExport` 闸 + 菜单禁用说明），MP4/GIF/播放器不受限。**坐标契约**：以代码真源 `AngleSceneCalculator.sceneToNormalized` 为准（canvasY 增 = sceneZ 增；`innerLength=2×innerWidth` ⇒ 方向向量两系间均匀缩放符号保持），金标准样例钉入 `PositionPlayFreeAimTests`。⚠️ 发现 `table-geometry.md` 文档写 `canvasY=(0.635−z)/2.54`（符号相反），与代码矛盾，待文档侧修正（双真源问题，同 D-A4 性质）。
  4. **球面图修复（#15 真根因）**：USDZ 球节点 pivot ≠ 网格中心（`visualCenter` 即为此而生），旧实现把节点原点当球心取景 → 取景框里没有球。改为按克隆体 `boundingSphere`（场景系转换）取景+定半径；并把材质改 `lightingModel = .constant` 无光照直出贴图（离屏单 omni 下 PBR 高光过曝成白月牙）；姿态矩阵出图人工核对选定 `defaultOrientation=(π,0,π/2)` 使号码尽量朝相机，球库 token 叠加号码徽标兜底（各球贴图布局不一）。`BallFaceRenderDiagTests` 出图 + 中心覆盖率>0.5 量化断言。
  5. **状态反馈**：`statusText` 上屏（角度胶囊下方状态行，求解中转菊花）；已击球待记录 = 「击球」键变「已击球」禁用 + 「记录」键绿色高亮描边；障碍挡线启发式提示（球心距瞄准线/进球线 < 2R → 「N 号球挡住线路」，复用 `ShotPredictor.segmentPointDistanceXZ`，仅提示不判定）。
  6. **破坏性操作纪律**：随机/清空桌面在有已记录步时 = 「开始新序列」（新 id 防 upsert 误覆盖已存序列，名称保留），均需确认（随机 sheet 红色警示 + 红按钮、清空/重来 confirmationDialog）；工具栏拆分「分享菜单（保存/导出）」与「更多菜单（重命名/清空/重来）」；退出页面自动存草稿（`onDisappear` 按 id upsert，stepCount>0 才存）。
  7. **力度友好化**：滑条范围 1.2–6.0 → **0.5–6.0 m/s**（支持轻推），场景区左下常驻内联力度滑条（不再必须开设置 sheet），数值旁加档名（轻推/轻/中/中大/大力）；设置键加塞点指示小红点。
- **验证**：`make build` ✅；新增 `PositionPlayFreeAimTests` 5/5 ✅（坐标契约金标准 + 直瞄方向/出界不变量 + 挡球位移 + Codable 兼容）、`BallFaceRenderDiagTests` ✅（PNG 出图 `build/ball_faces/` 人工核对 + 覆盖率断言）；`PhysicsEngineTests` 20/23——3 失败（largeCut/objectPath/sideSpin 进袋精度）经 git stash 在 HEAD 复跑全过，确认源自工作区**在途的库边物理整合改动**（923b9a6 后未提交部分），与本轮编排台改动无关（本轮对 `ShotPredictor` 仅做纯新增）。
- **影响**：改 `ShotPredictor.swift`（+`simulateFree`/`extraBallPaths`/`segmentPointDistanceXZ` internal）、`PositionPlayModels.swift`（`PlannedShot.freeAim`）、`PositionPlayViewModel.swift`（重写）、`PositionPlayComposerView.swift`（重写）、`AngleSceneView.swift`（+`onTableTapped`）、`BallFaceRenderer.swift`（重写取景）、`PositionPlaySequencePlayer(.swift/View)`、`SequenceVideoExporter.swift`、`PositionPlayDrillExporter.swift`（`canExport`）；新增 `Core/PositionPlay/PositionPlayShotSolver.swift`、`QiuJiTests/PositionPlayFreeAimTests.swift`、`QiuJiTests/BallFaceRenderDiagTests.swift`。
- **替代方案**：①自由瞄准用角度拨盘输入——不如点桌面直观，未采纳；②自由杆导出 JSON 时折算最近袋——语义造假，未采纳（禁导出 + 说明）；③每球建姿态表保证号码全朝相机——维护成本高，改号码徽标兜底。
- **遗留**：拖动中逐帧重解的跟手度优化（既有债，见 ADR-P11-01 遗留）；自由模式瞄准方向的可视化拖杆（当前点按设定，必要时迭代）。

### ADR-P11-04 — 连续击打状态机 + 录制开关 + 离线 JSON 复现管线（操作简化轮）

- **日期**：2026-06-11
- **状态**：✅ 已采纳（用户逐条提出 11 项需求并对 3 个分叉拍板：录制结束只分享 JSON / 离线脚本本轮一起做 / 时间轴整条拿掉）。
- **背景**：用户反馈编排台仍偏复杂、与真实打球心智不符：①击球后被击球与母球都复位不合理；②记录功能难理解；③球库占屏过高、上下檐深灰空白太大；④设置/随机按钮冗余；⑤进球线短、进袋瞬间消失；⑥击球无运杆过程。
- **决策**：
  1. **连续击打状态机（取代 ADR-P11-02 的软回退模型）**：删除 `hasStruck`/`pendingBefore` 软回退与只读预览整套；击球后桌面**前进为新真相**——进袋球离场回库、母球停在走位终点；自动选中下一杆 = **距母球最近的目标球** + **该球可进袋袋口中距其最近**者（`autoSelectTarget`/`selectBestPocket` 由「最小切角」改「最近距离 + 可行闸」）；「重打」（`lastShotBefore`）才把桌面退回上一杆击打前（#6/#7）。
  2. **录制 = 开关（#11）**：删除逐杆「记录」按钮、时间轴（预览/回退/备注）、保存到我的序列、MP4/GIF/Drill JSON 导出菜单、退出自动草稿。「录制」第一次点 = 以当前桌面为开局开新序列，此后每次击球在 `finishStrike` 自动记一杆（仍消费 `SolvedShot` 上下文）；「重打」一并撤回刚录的杆；第二次点 = 结束并分享**序列 JSON**（iso8601、prettyPrinted）。视频/GIF 改离线复现：新增 `QiuJiTests/PositionPlaySequenceExportRunnerTests` + `make position-export`——读 `build/position_play_sequences/*.json` → `SequenceVideoExporter` 物理引擎逐 Step 复现 → `build/position_play_export/<名>.mp4+.gif`。
  3. **球库微边框（#1/#2/#3）**：固定两行序（第一行母球+1–7、第二行 8–15，每行 8 槽不滚动）；只显示**在库**球、按固定序补位（上桌即消失、后球向前流动；回库按号序插回）；球 32pt、去说明文案与时间轴，球库栏高度减半以上。
  4. **控制行（#4/#5）**：力度滑条移到球桌与球库之间的常驻一行，左侧 `SpinMiniIcon`（缩小母球 + 当前打点红斑，与 `BTSpinPad` 同向约定）点击弹打点盘 sheet；删除「设置」「随机」按钮及随机球形逻辑。
  5. **进球线与进袋观感（#8/#9）**：新增 `PositionPlayShotSolver.extendPathToPocketRim`——目标球进袋时把真实轨迹末端沿「末点→袋心」补到**袋口圆（视觉标记）边缘**（落袋吸心已达袋内则不动；jaw/袋弧碰撞由真实模拟轨迹自带）；`TrajectoryPlayback` 进袋改「停顿 0.35s → 淡出 0.25s」（`pocketPauseDuration/pocketFadeDuration` 常量，编排台/分离角/视频导出同源），编排台收杆结算与导出器运动帧均补尾段等待。
  6. **运杆动画（#10）**：`play()` 先跑 `runStrokeAnimation`——回杆距离 `d = a + k·v`（a=0.05m 最小回杆、k=0.035s），smoothstep 回杆 0.5s → 停顿 0.12s → **匀加速出杆**（`a_accel = v²/(2d)`、前推时长 `2d/v`，触球瞬间杆速恰为目标速度），经 `CueStick.update(pullBack:)`（`AngleTrainingScene.updateCueStick` 透传）逐帧驱动；触球瞬间收杆、清线、进入球体回放。
- **验证**：`make build` ✅；新增 runner 端到端 ✅（示例 2 杆 JSON → 11.8s MP4 + GIF，抽帧确认进球线延伸入袋口圆、进袋停顿淡出）；`PositionPlayFreeAimTests` 5/5 ✅；`PhysicsEngineTests` 20/23——3 失败（largeCut/objectPath/sideSpin）与 ADR-P11-03 记录的**工作区在途库边物理整合**同组既有失败，与本轮显示层/状态机改动无因果（本轮未触碰引擎求解路径）。
- **影响**：重写 `PositionPlayViewModel.swift`/`PositionPlayComposerView.swift`；改 `PositionPlayShotSolver.swift`（+`extendPathToPocketRim`）、`TrajectoryPlayback.swift`（进袋停顿）、`SequenceVideoExporter.swift`（线延伸+停顿淡出+复用节点 opacity 复原）、`AngleTrainingScene.swift`（`updateCueStick` 透传 `pullBack`）、`scripts/Makefile`（`position-export`）；新增 `QiuJiTests/PositionPlaySequenceExportRunnerTests.swift`。删除（编排台侧）：预览/时间轴/备注/回退、随机球形、保存/导出菜单、`load(sequence:)`。
- **替代方案**：①击球后仍软回退、由「记录」推进（旧模型）——与真实打球心智冲突，废弃；②录制 JSON 同时存「我的序列」——用户选只分享 JSON；③Python 复刻物理引擎做离线渲染——双引擎漂移风险，改用 XCTest runner 复用同一 Swift 引擎。
- **遗留**：~~`PositionPlaySequencePlayerView`/「我的序列」页因编排台不再保存而成孤岛（待用户决定去留）~~ → ADR-P11-05 移除；~~自动选袋未含障碍球遮挡判定~~ → ADR-P11-05 补齐；运杆动画期间不可中断（短时长可接受）。

### ADR-P11-05 — 移除「走位训练/我的序列」孤岛链路 + 自动选袋障碍球遮挡闸

- **日期**：2026-06-11
- **状态**：✅ 已采纳（用户拍板「移除，加上障碍球遮挡判定」，收口 ADR-P11-04 两项遗留）。
- **背景**：ADR-P11-04 后编排台不再保存序列，「走位训练」页（列已存序列→多杆播放器）成不可达孤岛；自动选袋的可行闸只有「切角<89° + 母球不挡进球线」，障碍球挡路时仍会选中该袋。
- **决策**：
  1. **移除孤岛链路**：删 `PositionPlayTrainingView`/`PositionPlaySequencePlayerView`/`PositionPlaySequencePlayer`/`PositionPlaySequenceStore`/`PositionPlaySequenceEntity` 五文件；`ModelContainerFactory.allModels` 去掉 `PositionPlaySequenceEntity`（**SwiftData Schema 变更**：纯减实体、不动既有实体，旧库该表数据成孤儿数据无碍读写，无需 MigrationPlan）；`AngleRoute` 删 `.positionPlayTraining` + 角度页「走位训练」卡片；编排台卡片副标题改为「可录制分享击球序列」。序列消费路径收敛为唯一一条：录制分享 JSON → `make position-export` 离线复现。
  2. **障碍球遮挡闸**：`AngleSceneCalculator` 新增通用 `isPathBlocked(from:to:obstacles:clearance:)`——X–Z 平面点到线段距离 < 2R 即遮挡（运动球心沿线、碰撞条件中心距 2R；投影钳 [0,1]，贴端点也算挡=保守闸）。`selectBestPocket` 可行判定追加：其余在桌球（除母球/目标球）不得挡「母球→假想球（`ghostBallPosition`，真源 2R 退距）」与「目标球→进球点（`effectivePocketAimPoint`）」两段路径；全袋不可行时仍退回最近袋口（用户可手选）。
- **验证**：`make build` ✅；`PositionPlayFreeAimTests` **6/6**（新增 `test_isPathBlocked_goldenSamples` 金标准 5 例：中点旁 0.03<2R 挡 / 0.06>2R 不挡 / 延长线外不挡 / 贴端点挡 / 空障碍不挡）；lint 0。
- **影响**：删 5 文件（见上）+ `ModelContainerFactory.swift`/`MainTabView.swift`/`AngleHomeView.swift`；改 `AngleSceneCalculator.swift`（+`isPathBlocked`）/`PositionPlayViewModel.swift`（`selectBestPocket` 加遮挡闸）；`xcodegen` 重生工程。
- **替代方案**：①「我的序列」改为录制结束时自动入库——用户已在 ADR-P11-04 拍板只分享 JSON，弃；②遮挡判定跑物理模拟——自动选袋需对 6 袋快速循环，几何闸 O(袋×球) 即时完成，且最终可行性仍由 `recompute` 的真实物理求解兜底。
- **遗留**：遮挡闸为直线几何近似（不含借擦/翻袋路线）；薄切球母球实际走弧线，直线「母球→假想球」判挡偏保守——被误判挡住时用户可手动点袋强选。

### ADR-P11-06 — 零遮挡布局（左栏+右下操作列）+ 重打全量恢复 + 进袋沉入 + 打点回中

- **日期**：2026-06-11
- **状态**：✅ 已采纳（用户逐条提出 5 项体验问题）。
- **背景**：①重打只复位球、不恢复目标/袋口/速度/打点；②模式切换、角度胶囊、状态行、侧边按钮全是球桌叠层，遮挡台面与袋口；③顶视 scale 1.3716 < 实测外框半长 1.4055，上下木框被裁切；④进袋球在落袋孔捕获点（视觉袋口圆之外）即停顿淡出，观感「刚到袋口就消失」，引擎吸心跳帧也不可见；⑤击球后打点残留、打点盘 sheet 背景过大。
- **决策**：
  1. **重打全量恢复（#1）**：`lastShotBefore: BoardSnapshot` 升级为 `lastShot:(before, PlannedShot)`；`replayCurrent` 先恢复 velocity/spinX/spinY/aimMode（自由杆还原 `freeAimDir`、袋口杆还原 `selectedTargetKey`+`selectedPocketIndex`），再 `applyBoard(before)`——applyBoard 见选择有效不触发自动重选。
  2. **零遮挡布局（#2/#3）**：删除全部球桌叠层。左侧 56pt 信息栏（进袋/自由竖排切换、切角°+厚薄、母球进袋警示、录制指示）；状态行+序列名上移导航栏 principal（黑底白字）；底部条 = 控制行+球库（球 30pt）+右下操作列（击球胶囊 + 录制/重打圆钮）。**取景**：实测 USDZ 外框半长 1.4055（新增 `test_diag_tableOuterBounds` 实测并断言契约），`composerTopDownScale = 1.416` 上下木框完整可见；左栏吃掉的是原左右空margin，球桌像素尺寸基本不变（pt/world 仅 −1% 级）。
  3. **进袋沉入（#4）**：启用 `pocketSinkDuration = 0.22s`——pocketed 帧已被引擎吸心到袋心，但捕获发生在落袋孔边缘（0.070/0.075m，视觉袋口圆 0.042/0.043m 之外）。`TrajectoryPlayback.action` 进袋瞬间改由「easeOut move 至袋心 → 停顿 0.35 → 淡出 0.25」子动作接管（逐帧求值不再覆盖位置）；`SequenceVideoExporter` 运动帧同源实现（potFrom 记捕获点、easeOut 插值）；编排台收尾 tail 用 `pocketSettleDuration`。jaw/袋弧碰撞本就在真实轨迹帧中，沉入只补「捕获点→袋心」段。
  4. **打点回中 + 紧凑打点盘（#5）**：`finishStrike` 在 `isPlaying` 复位前清 spinX/spinY（didSet 不触发重算）；打点盘 sheet 去标题、盘面 128pt、detent 290→204。
- **验证**：`make build` ✅；`PositionPlayFreeAimTests` 7/7（含外框实测契约）；`make position-export` 端到端 ✅ + 抽帧确认球肉眼可见沉入袋口圆后停顿淡出（f011–f013）；新增 `testPositionPlayComposerOnly` UI 截图——pp01 布局（左栏/完整外框/右下操作列）、pp02 击球后（进袋回库+自动选下一杆+母球进袋警示上左栏）、pp03 重打后与 pp01 完全一致（桌面+11°+选袋全恢复）；lint 0。
- **影响**：`PositionPlayViewModel.swift`（lastShot/replayCurrent/finishStrike/取景常量）、`PositionPlayComposerView.swift`（布局重构）、`TrajectoryPlayback.swift`（沉入接管）、`SequenceVideoExporter.swift`（沉入同源）、`QiuJiTests/PositionPlayFreeAimTests.swift`（+外框契约）、`QiuJiUITests/ScreenshotTourUITests.swift`（+编排台截图测试）；恢复被 xcodegen 删除的 `QiuJiUITour.xcscheme`。
- **遗留**：小屏（375pt 宽）下左右木框边缘可能贴边/微裁（中袋标记仍可见）；运杆动画期间不可中断（继承 P11-04）。

### ADR-P11-07 — 进袋入洞段 v2（匀速冲洞+远端袋弧碰撞）+ 场景页统一设计语言

- **日期**：2026-06-12
- **状态**：✅ 已采纳（用户反馈 ADR-P11-06 沉入动画「还没靠近圆弧就开始减速、停在袋口」与预期完全不符；并提供 12 张截图要求统一设计语言 + 角度Tab首页重排）。
- **背景**：①ADR-P11-06 的 easeOut 沉入有两处根因错误：引擎 CCD 深入/jaw-settle 落袋路径**不吸心**（pocketed 帧 = 捕获点本身，实测样例捕获距袋心 0.0692/0.0792m），旧实现 move 目标取 `s.position` ⇒ **零位移**，球停在袋口原地淡出；且 easeOut 全程减速、不符合「带速冲洞」物理直觉。②场景页设计语言漂移：分离角是大块结果卡、反射/翻袋用系统 segmented 灰条、编排台标题白色；角度预测页整页浅色旧风格；角度Tab首页平铺列表与训练/动作库的彩色卡片语言格格不入。
- **决策**：
  1. **进袋入洞段 v2（显示层，回放/导出同源）**：`TrajectoryPlayback.solvePocketEntry(capture:velocity:pocketCenter:pocketRadius:speedScale:)`——球以**进袋时真实水平速度**（下限 0.4m/s×回放倍率）**匀速**冲洞，绝不提前减速；速度射线与「球心可达弧」（袋口圆半径 − 0.3R）求**远交点**=远端袋弧碰撞点，撞弧后 0.12s easeOut 回落袋心；射线不穿圆（慢速 settle）则匀速直滑袋心。袋心/半径由 `nearestPocket(to:)` 按最近袋口查找（**不再信任 pocketed 帧位置**，根因修复）。回放侧 `SCNAction` 路标序列驱动；导出侧 `pocketEntryPosition(start:legs:at:)` 同源逐帧求值。开口前的 jaw/袋弧碰撞本就在真实轨迹帧中，入洞段只接管「捕获点→洞内」。
  2. **场景页统一设计语言**（黑底 + 品牌绿 inline 标题 + 顶部指标胶囊 + 胶囊分段 + 右下 FAB）：新增 `BTChipRow` 共享控件（选中实底胶囊、未选 white 0.12，超宽横滚），反射/翻袋的库数与「理想/真实」、翻袋袋口行全部替换系统 segmented；分离角大块结果卡改为与「角度与打点/2D/3D」同款单行指标胶囊（夹角+状态+计算中）；编排台导航标题改品牌绿。
  3. **角度预测页暗色重做**：黑底；统计四格下沉为顶部指标胶囊（次数/正确率/平均误差/剩余）；「换题/显示参考」改画布下方胶囊操作行（FAB 方案与表单按钮重叠，弃）；重置统计上移导航栏图标；输入/结果/限免卡改 white 0.06 暗卡。
  4. **角度Tab首页卡片化**：对齐训练/动作库语言——学习/工具为整行卡（彩色渐变图标块 48pt），训练/进阶为双列彩色封面卡（76pt 渐变封面 + 大图标 + 角标 chip）；每入口固定品牌色渐变。
- **验证**：`make build` ✅；新增 `test_diag_pocketEntryLegs` 数值探针（实测捕获点距袋心 0.0792m、入洞两段路标 0.021s+0.12s）✅；`make position-export` 端到端 ✅ + 30fps 抽帧确认：球 4.0m/s 匀速冲入洞（2 帧跨越捕获→洞内）、落袋心停顿、于袋心淡出（白圈标记透出）；新增 `testUnifiedDesignPages` UI 截图回归 ✅（u01/u02 首页卡片化、u03 角度预测暗色、u04 分离角胶囊、u05/u06 反射翻袋胶囊分段）；lint 0。
- **影响**：`TrajectoryPlayback.swift`（入洞段求解器+同源求值器，删 `pocketSinkDuration` easeOut 方案）、`SequenceVideoExporter.swift`（同源入洞）、`ReflectionModeControl.swift`（+`BTChipRow`）、`DiamondSystemView.swift`/`BankShotView.swift`（胶囊分段）、`ShotSimulationView.swift`（指标胶囊）、`GeometricAngleQuizView.swift`（暗色重做）、`AngleHomeView.swift`（卡片化重写）、`PositionPlayComposerView.swift`（标题绿）、`QiuJiTests/PocketBehaviorDiagTests.swift`（+入洞探针）、`QiuJiUITests/ScreenshotTourUITests.swift`（+统一设计回归）。
- **替代方案**：①入洞段直接调真实物理引擎模拟洞内运动——洞内三维落体超出 2D 桌面引擎域，显示层几何近似即可；②角度预测保留浅色卡片风——与 2D/3D 训练页同属一组训练入口，用户明确要求统一，弃。
- **遗留**：入洞「远端袋弧」为圆弧近似（未区分角袋/中袋喉腔形状差异）；记录/我的两个 Tab 首页未在本轮截图范围内，后续如有漂移再统一。

### ADR-P11-08 — 2D 球桌统一自适应取景 + 角度首页海报卡重排 + 场景 FAB 组件化

- **日期**：2026-06-12
- **状态**：✅ 已采纳（用户反馈 ADR-P11-07 后角度首页仍「简陋如小学生作品」且需要不断下滑；多张 2D 球桌页截图对比球桌位置/占比不一致、编排台不居中、按钮风格不统一，要求多轮截图打磨）。
- **背景**：①各 2D 球桌页用各自硬编码正交 scale（编排台 1.416、其余页另一套），顶部控件高度不同导致球桌出现位置、屏占比页页不同，编排台还因 60pt 左栏整体偏右；②角度首页虽已卡片化但仍是「整行小卡+双列中卡」长列表，单屏装不下三组内容；③各页右下浮动按钮自绘（尺寸/底色/阴影各异）。
- **决策**：
  1. **统一自适应取景（根因修复，替代所有硬编码 scale）**：`AngleTrainingScene` 装桌后遍历层级实测球桌世界包围盒（半长/半宽），回填 `CameraRig.tableOuterHalfLength/Width`（USDZ 实测 1.4055/0.7995 作兜底默认）；`CameraRig.fitRotatedTable(viewSize:)` 按视口宽高比取双轴约束最大值 `max(半长×1.012, 半宽×1.012×H逆比)` 为正交 scale——任何视口下球桌完整可见、双轴居中、留 1.2% 防裁边余量。`AngleSceneView` 增 `autoFitsRotatedTable` 开关，渲染循环逐帧适配（视口变化即重取景）。分离角/反射/翻袋/2D瞄准/角度与打点/编排台 6 页全部启用；删除 `composerTopDownScale` 等页内常量。
  2. **编排台去左栏**：信息全部上移顶部单行（进袋/自由 `BTChipRow(scrollable:false)` + 切角/厚薄胶囊 + 母球进袋/录制指示 pill），球桌区占满全宽 → 水平真居中。
  3. **`BTSceneFAB` 组件**：统一 56pt 圆形浮动按钮（primary 品牌绿渐变 / neutral white 0.16，统一描边+阴影+字号），替换分离角/反射/翻袋/2D瞄准 4 页自绘 FAB；翻袋/反射删除顶部教学文案行省纵向空间。
  4. **角度首页三分段海报墙**：`BTSegmentedTab`（学习/训练/工具，带 `accessibilityIdentifierPrefix` 供测试精确定位）+ 双列 `AnglePosterCard`（渐变封面+大字水印+底部标题+角标 chip，与训练页 `BTPlanCover` 同语言）；每分段 ≤4 卡单屏放完，消除长列表滑动。
  5. **打点盘 sheet 加显式关闭钮**（右上 ✕，`accessibilityLabel("关闭打点")`）——原先只能下滑关闭且拖动手势会被打点盘吞掉（UI 测试中拖动误设了低杆 100%，真实用户同样可能误触）。
- **验证**：`testScenePopups` ✅（p01 分离角 HUD / p02 编排台打点盘+✕ / p03 反射真实模式滑条 / p04 角度预测统计胶囊）；`testUnifiedDesignPages` ✅（u01–u02b 首页三分段海报墙、u03–u06 各 2D 页球桌全宽居中+FAB 统一，逐张人工核验）；`PositionPlayFreeAimTests` 7/7 ✅（外框契约改为「实测包围盒回填 + fitRotatedTable 多视口覆盖断言」）；lint 0。
- **测试基建教训（FL 级）**：本轮 UI 测试反复假失败的根因是**同机另一会话并行对同名模拟器（iPhone 17 Pro）跑 xcodebuild test**——每次重装 App 把 UI 测试中的 App 进程杀掉（日志特征：installcoordinationd "proceeding with install" + App "voluntary exit"）。解法：UI 截图测试改用独立设备（iPhone 17，`-destination id=16F181F1`）彻底隔离；`launchClean` 用 `app.state == .runningForeground` 进程态校验替代 AX 查询兜底（AX 查询在主线程繁忙时误判会反杀健康进程）。
- **影响**：`CameraRig.swift`（+实测尺寸/`fitRotatedTable`）、`AngleTrainingScene.swift`（+包围盒实测回填）、`AngleSceneView.swift`（+`autoFitsRotatedTable`）、6 个场景页启用自适应、`PositionPlayViewModel.swift`（删 scale 常量）、`PositionPlayComposerView.swift`（去左栏+顶部信息行+打点盘✕）、新增 `BTSceneFAB.swift`、`AngleHomeView.swift`（海报墙重写）、`BTSegmentedTab.swift`（+AX 前缀）、`ReflectionModeControl.swift`（`BTChipRow` +scrollable 开关）、`GeometricAngleQuizView.swift`（统计胶囊左对齐）、`project.yml`（QiuJiUITour scheme 固化）、UI 测试与帮助器更新。
- **替代方案**：①继续逐页手调 scale 常量——治标，视口/控件高度一变即回归，弃；②首页保持单列表加分组折叠——仍需滑动且与训练页语言不一致，弃。
- **遗留**：iPad/横屏未专门核验（自适应公式本身视口无关，理论可用）；记录/我的 Tab 首页设计语言未在本轮范围。

### ADR-P11-09 — 分离角页底部控制条对齐编排台 + 打点盘 sheet 半透明材质统一

- **日期**：2026-06-12
- **状态**：✅ 已采纳（用户反馈：分离角与走位的打点/速度调整位置与样式参考走位编排台；打点弹层背景用分离角的半透明材质更舒服；功能按键全部移到屏幕最下方、样式与编排台一致）。
- **背景**：ADR-P11-08 后分离角页仍是「右侧竖排 FAB + 点调整弹 HUD（打点盘 + 5 档速度）」的独立交互，与编排台「底部控制行（打点小图标 + 连续力度滑条）+ 操作钮」语言不一致；编排台打点盘 sheet 用纯色 `Color(white:0.1)` 底，观感比分离角 HUD 的半透明材质生硬。
- **决策**：
  1. **分离角页改底部控制条**：删右侧 FAB 列与「击球设置」HUD（含 `HUDHeightKey` 高度上报机制），改为与编排台同款底部条——`BTSpinMiniIcon`(28pt，点击弹打点盘 sheet) + 连续力度 `Slider`(0.5–6.0 m/s，btPrimary) + 档名读数 + 「重置」圆钮(43×42, white 0.14) + 「击球」胶囊(92×42, btPrimary, 球杆图标)，底条 `Color(white:0.11)` + 顶部分隔线，与编排台逐像素同款。
  2. **速度模型升级**：`ShotSimulationViewModel.speedLevel`（5 档枚举）→ 连续 `velocity: Double = 3.3`，与编排台同一交互；`StrokePhysics.SpeedLevel` 保留供物理/测试锚点用。
  3. **打点盘改共享浮层卡片 `BTSpinPadCard`（弃系统 sheet）**：删分离角页私有 `SpinPadView`（与 `BTSpinPad` 同源重复）；新共享卡片（标题「打点」+ ✕ + `BTSpinPad` 128pt + 读数 + 回中，`ultraThinMaterial` 圆角卡）**浮在球桌底缘**（ZStack bottom 对齐 + spring 进出场），两页同一组件。**关键发现（两轮迭代）**：系统 sheet 方案 ①`environment(\.colorScheme,.dark)` 不影响 `presentationBackground` 材质解析（首轮白底）；②改 `preferredColorScheme(.dark)` 后材质又因 sheet 底下是纯黑安全区+压暗层而**显得过深**（用户打回「颜色太深」）——半透明材质的观感取决于底下内容，要透出球桌绿色就必须浮在球桌上方，与旧「击球设置」HUD 同位。
  4. **组件下沉**（消灭编排台私有副本，供两页共享）：`SpinMiniIcon`→`BTSpinMiniIcon`、`CueStickShape`、`powerName`→`PowerDisplay.name`、`spinReadout`→`SpinDisplay.readout`、打点盘卡片→`BTSpinPadCard` 全部迁入 `Core/Components/BTSpinPad.swift`。
- **验证**：`make build` ✅；`testScenePopups` ✅ 三轮截图核验（p00 底部条样式与编排台一致、p01/p02 两页打点盘浮层卡透出球桌绿色 + ✕/回中/读数可见；第一轮材质解析成亮色、第二轮 sheet 底过深，第三轮浮层卡通过）；lint 0。
- **影响**：`ShotSimulationView.swift`（底部条重写，删 HUD/侧边 FAB/私有打点盘）、`ShotSimulationViewModel.swift`（连续速度）、`PositionPlayComposerView.swift`（删私有组件副本与 spinPadSheet，改浮层卡）、`BTSpinPad.swift`（+`BTSpinPadCard`/`BTSpinMiniIcon`/`CueStickShape`/`PowerDisplay`/`SpinDisplay`）、`ScreenshotTourUITests.swift`（调整→打点流程）。
- **替代方案**：①保留 5 档速度按钮塞进底部条——横向放不下且与编排台滑条交互不一致，弃；②系统 sheet + 暗色材质——sheet 底下纯黑+压暗层使材质过深，被用户打回，弃；③sheet 底材跟编排台改纯色——用户明确点名半透明材质更舒服，反向统一，弃。
- **遗留**：分离角页 `BTSceneFAB` 已不再被本页使用（反射/翻袋/2D瞄准仍在用，组件保留）。

### ADR-P11-10 — 教学素材生产管线落点：录制直写内容库 + 录制入口模拟器限定 + 生成视频走 OTA

- **日期**：2026-06-12
- **状态**：✅ 已采纳（用户三项拍板：①录制 JSON 由 App 直写仓库固定目录、弃 share sheet 搬运；②管线生成的教学视频走 OTA、不再往 Bundle 塞；③录制入口暂不对用户开放）。
- **背景**：基于击打序列 JSON 规划图片/GIF/视频生产管线时确认：序列 JSON（意图+前后快照，不存轨迹）数据充分；但采集链路是「share sheet → AirDrop → 手动归档」纯手工；JSON 散落 `build/`（不进 git，丢了无法重渲）；Bundle 内 `Resources/Videos/` 已 257MB 实拍视频，再塞生成视频包体失控；录制是内容生产功能、对终端用户无完整闭环。
- **决策**：
  1. **内容库真相源**：新建 `content/position_play/sequences/`（进 git，附 README 约定）；序列文件命名 `seq_<UUID前8位>-<名称>-<N>杆.json`，`seq_<id8>` 为稳定资产键（与 `PositionPlayDrillExporter` 的 `drill_pp_<id8>` 对齐），后续 mp4/gif/png 产物沿用同名前缀。预留 `meta/` 放教学文案 sidecar（标题/每杆讲解/产物变体清单），文案迭代与录制解耦。
  2. **录制直写（弃 share sheet）**：新增 `PositionPlaySequenceArchive`（整体 `#if targetEnvironment(simulator)`）——模拟器进程以宿主用户身份运行、可直写 Mac 文件系统，录制结束 JSON 直接落内容库并 banner 提示文件名；删除编排台 share 流程（`exportURL`/`showShare`/sheet）与已无使用方的 `Core/Components/ShareSheet.swift`。仓库绝对路径硬编码与 `PositionPlaySequenceExportRunnerTests` 同一约定，且仅模拟器构建编译、不进真机产物。
  3. **录制入口模拟器限定**：编排台「录制」按钮 `#if targetEnvironment(simulator)` 编译条件隐藏——真机/发布版无此入口（采集工作流本就依赖模拟器直写，编译闸即产品开关，无需运行时 flag）。
  4. **`make position-export` 收件箱同步**：渲染前自动把 `content/position_play/sequences/*.json` 同步进 `build/position_play_sequences/` 收件箱（收件箱保留，临时试渲可直接丢文件）；runner 测试本身零改动。
  5. **产物分发策略（命中 ADR 触发：内容分发/数据同步策略）**：管线生成的教学视频 mp4 走自建 REST OTA（ADR-002 内容通道，**依赖 H-14 服务器**）；进 Bundle 的只允许小体积资产——静帧教学图 → `Resources/DrillTutorials/`、封面 → `Resources/DrillThumbnails/`、动画预览走帧序列 → `Resources/Previews/<id>/frame_*.png`（App 内不消费 GIF/APNG 文件，站外分享素材另行分发）。
- **验证**：`make xcodegen` ✅ + `make build` ✅（BUILD SUCCEEDED，模拟器目标含新增直写代码）；lint 0。**直写链路已实录走通**（2026-06-12 晚，用户模拟器实录 3 条序列均落 `content/position_play/sequences/`）。
- **同日补修（用户实录反馈）**：「先录完 → 再命名」时已写盘文件不随重命名更新（文件在结束录制瞬间用当时名字写死）。修复：①`archive` 改为同 `seq_<id8>` 前缀旧文件先清再写（一条序列只留一份，覆盖改名/重录杆数变化）；②编排台「重命名保存」后若序列已录制完成（`!isRecording && stepCount > 0`）自动重新归档 + banner 提示；录制中重命名不处理（结束时本就按最新名字归档）。`make build` ✅、lint 0。
- **影响**：新增 `content/position_play/README.md`、`QiuJi/Features/PositionPlay/Services/PositionPlaySequenceArchive.swift`；改 `PositionPlayComposerView.swift`（录制按钮/归档/删 share 流程）、`scripts/Makefile`（同步步骤+帮助文案）、`QiuJiTests/PositionPlaySequenceExportRunnerTests.swift`（注释）；删 `Core/Components/ShareSheet.swift`；`xcodegen` 重生工程。
- **替代方案**：①保留 share sheet 真机录制——搬运链路长且 JSON 不自动归档，弃（真机采集需求出现时再走 H-14 服务器上传接口）；②录制开关用运行时 flag/隐藏手势——编译闸更简单且与直写能力边界天然一致，弃；③生成视频过渡期进 Bundle——257MB 前车之鉴，仅允许少量关键视频例外且须显式拍板，默认弃。
- **遗留**：~~管线主体待做——渲染矩阵、preset、`showTrajectories`~~ → ADR-P11-11 落地；仍待做：出片前「重模拟 vs `after` 快照」一致性校验门、序列 JSON `engineVersion` 版本戳、`meta/` sidecar schema（clean 变体按需声明机制）；OTA 通道被 H-14 阻塞。

### ADR-P11-11 — 教学素材渲染矩阵：默认配方 + 渲染风格双档 + 轨迹线「击球前预告、出杆即清」

- **日期**：2026-06-12
- **状态**：✅ 已采纳（与用户两轮澄清后逐项确认：①「分辨率」=输出像素尺寸，与"球被放大"的 `ballScale=1.6` 是两个参数，后者只该用于卡片素材，其余产物必须真实比例；②轨迹线应为击球前预告、出杆后消失，而非全程挂线——与编排台 App 内行为一致）。
- **背景**：ADR-P11-10 后管线只出整段 mp4+gif（640×320 / 球放大 1.6 / 轨迹线全程可见），与教学素材需求（真实比例、高清、逐杆拆解、击球前预告线）不符；且产物未按消费场景（动作库卡片 / 图文精讲 / 教学视频 / 站外分享）分型。
- **决策**：
  1. **渲染风格双档**：`Options` preset 化——`teaching()`（默认，1280×640@30、`ballScale=1` 真实比例）/ `card()`（640×320、`ballScale=1.6`，仅封面与卡片动画帧）/ `gif()`（480×240@12、真实比例）。
  2. **轨迹线契约**：`showTrajectories=true`（默认）= 每杆设置静帧（0.6s）显示白色母球线 + 橙色进球线（延伸至袋口圆边缘），**出杆瞬间清除**，运动帧无线；`false` = clean 版全程无线（按需出片，不进默认配方）。`initialHold` 默认 0（连续录制序列开局 == 首杆 before，避免双重静帧）。
  3. **默认配方**（每条序列 → `build/position_play_export/seq_<id8>/`）：`cover.png`（卡片风格，首杆+预告线）、`preview/frame_01..12.png`（卡片风格整段抽样）、`initial/final.png` + `sNN_still.png`（真实风格教学静帧）、`full.mp4` + `sNN.mp4`（真实风格高清）、`full.gif`（分享）。单杆切片 = `subSequence`（`initial=step.before, steps=[step]`，Step 自含零新逻辑）。
  4. **结构**：`SequenceVideoExporter` 抽 `RenderContext`（场景/渲染器/USDZ 装载收口一处，静帧/封面/预览帧/逐帧视频共用）；新增 `renderStills` / `renderCover` / `renderPreviewFrames` / `subSequence` 四个出口；runner 按配方组织目录并写 PNG。
- **验证**：`make build` ✅；`make position-export` 实跑用户实录 3 条序列（1/2/3 杆）全部出齐——目录结构与配方一致（3 杆条目：6 静帧 + cover + 12 预览帧 + full.mp4/gif + 3 单杆 mp4，共 10MB）；规格核验 `ffprobe`：full/sNN.mp4 1280×640、gif 480×240、cover 640×320；抽帧核验：单杆设置帧有预告线（白线含吃库折点、橙线进顶中袋）、运动帧无线且球已沿线位移、cover 球径明显大于真实风格同帧（1.6×）。lint 0。
- **影响**：重写 `QiuJi/Core/Media/SequenceVideoExporter.swift`（Options preset + RenderContext + 4 新出口 + 轨迹出杆即清）、`QiuJiTests/PositionPlaySequenceExportRunnerTests.swift`（默认配方出片 + PNG 写盘）、`content/position_play/README.md`（产物约定）。
- **替代方案**：①全矩阵盲出（(1+N)×2×3 档位）——一条 3 杆序列几十个文件，弃，clean/单杆 GIF 等留给 meta 清单按需声明；②轨迹线全程挂线（原实现）——运动中球本就沿线走，线是冗余噪声，且与编排台行为不一致，弃；③`_traj`/`_clean` 文件名后缀——轨迹行为统一为「击球前预告」后默认产物无需后缀，仅按需 clean 版加 `_clean`。
- **遗留**：一致性校验门（重模拟 vs `after`）与 `engineVersion` 版本戳仍未做（出片正确性当前依赖引擎与录制时一致）；发布回填（Resources/OTA 拷贝改名对接 drill JSON）待 meta sidecar 一起做；`make position-export` 日志被缺失的 `xcpretty` 吞掉（管道 `| xcpretty || true`），排障需直跑 xcodebuild 或装 xcpretty。

### ADR-P11-12 — 轨迹线样式真源 + 假想球补全 + 教学视频 60fps 原速

- **日期**：2026-06-12
- **状态**：✅ 已采纳（用户三项反馈：①导出素材没有假想球；②进球线颜色随目标球球色、瞄准线/进球线全场景变细；③导出视频观感卡顿——确认为渲染参数问题而非模拟器性能问题）。
- **背景**：ADR-P11-11 首版产物评审发现三个问题。卡顿根因：30fps × 1.3 倍速 ⇒ 帧间物理步长 43ms，中速球在 1280px 宽画面一帧跳 ~60px，离线渲染无运动模糊，肉眼即卡（App 内 120Hz 屏不暴露此问题）。线样式此前散落 6 处硬编码（编排台 0.0035 / 导出器 0.006 / 动作库 0.005~0.006 / 翻袋 0.004~0.0045…），进球线一律橙色与目标球无关联。
- **决策**：
  1. **`TrajectoryStyle` 真源**（`Core/Components/PoolBallFace.swift`，与 `PoolBallStyle` 色板同文件）：`aimRadius=0.0025`（瞄准线白）/ `potRadius=0.0030`（进球线）/ `compactRadius=0.0045`（缩略图等低分辨率，太细会碎成虚点）；`potColor(for: targetKey)` = 目标球标准球色（9..15 花色取主色），**黑 8 例外用亮灰**（深绿台呢上黑线不可见），自由球/无目标语义同此兜底。联动球路径（`extraBallPaths`）各随其球色。
  2. **接入场景**：走位编排台、素材导出器、分离角页、动作库详情/缩略图全部改走真源（动作库目标球为黑 8 → 进球线由橙改亮灰）；翻袋/颗星/角度测验页**只统一线宽不跟球色**（黄/绿/青是路线教学色，非「目标球进球线」语义）。
  3. **假想球补全**：编排台 App 内预览与导出器（视频设置帧 + 教学静帧 + 封面）在袋口模式显示假想球（复用 `setupVisualizationNodes` 的 ghost 节点，出杆随预告线一起清除，导出器经 `hideAimDecorations()` 收口）；卡片风格 ghost 随 `ballScale` 同步放大。
  4. **教学视频 60fps + 原速**：`Options` 默认 `fps 30→60`、`playbackSpeed 1.3→1.0`（帧间步长 43ms→17ms）；GIF preset 保留 12fps×1.3（预览媒介控体积）。
- **验证**：`make position-export` 实跑 3 条序列，xcresult `Passed (1/1)`；`ffprobe` full.mp4 = 1280×640@60fps；抽帧核验：设置帧有假想球 + 进球线随球色（2 号目标=蓝线、1 号=黄线）、线宽明显变细、运动帧无线无 ghost；台面竖直细白线为球台开球线（USDZ 自带），非残留轨迹。lint 0。
- **影响**：`PoolBallFace.swift`（+`TrajectoryStyle`）、`SequenceVideoExporter.swift`（preset/ghost/球色线）、`PositionPlayViewModel.swift`、`ShotSimulationViewModel.swift`、`DrillSceneView.swift`、`DrillThumbnailRenderer.swift`、`BankShotViewModel.swift`、`SceneAngleViewModel.swift`。
- **替代方案**：①保留 30fps 提高倍速补帧插值——离线渲染本就逐帧重模拟，直接提采样率成本为零，插值弃；②黑 8 进球线用描边黑线——实现复杂且小尺寸下仍发糊，亮灰例外更简单直接，弃；③翻袋/颗星路线也跟球色——那些线是「路线讲解」不是「目标球轨迹」，改色破坏既有教学色语义，弃。
- **遗留**：动作库既有已烘焙缩略图 PNG（橙线）与新规则（亮灰线）不一致，待下次批量重烘焙统一；60fps 渲染时长约为 30fps 两倍（3 条序列 ~98s，可接受）。

### ADR-P11-13 — 教学素材击球参数 HUD（打点 + 力度条）+ 导出暗色背景

- **日期**：2026-06-13
- **状态**：✅ 已采纳（用户拍板：①瞄准点/接触点不做（意义不大）；②打点无盘面/卡片背景但必须显示百分比读数；③样式与 App 内一致；④背景采用方案 1——导出场景背景改暗色）。
- **背景**：教学视频只回答「球往哪走」，不回答「这杆怎么打的」；打点（spinX/spinY）与力度（velocity）是走位教学核心输入，JSON 已有、零采集成本。原导出帧四周白底，App 暗色主题白字读数放上去不可读。
- **决策**：
  1. **HUD 条**：teaching 档画面底部追加 80px 暗色条（输出 1280×640 → **1280×720，16:9**），内容 = `BTSpinMiniIcon` 球面（无卡片底）+ `SpinDisplay.readout` 百分比读数 + 力度胶囊条（量程与编排台滑条同 0.5–6.0 m/s，`btPrimary` 填充）+ `PowerDisplay.name` 档名与 m/s 数值。**每杆常驻（设置帧→收尾帧），换杆更新**——观众看球运动时需要对照杆法；与「出杆即清」的预告线生命周期不同。
  1b. **打点图标真实比例（用户复评修正）**：`BTSpinMiniIcon` 原本只有归一化画法（满塞红点到图标边缘）——App 内 28pt 小按钮可读性优先没问题（真实比例由点开的打点盘呈现），但教学素材上图标本身就是「往哪打」的指令，红点贴边会教人滑杆。给组件加 `trueScale` 模式：与 `BTSpinPad` 同一几何（红斑 = 皮头中心摆放位置 spin/拉心系数、斑径 = 皮头/母球真实比例、打滑极限虚线圈 ≈0.68R），HUD 用真实比例（图标加大到 56px），App 内按钮保持归一化不动。百分比读数语义两处本就一致（占打滑极限/满塞），无需改。
  2. **组件即真源**：HUD 经 SwiftUI `ImageRenderer` 直接复用 App 组件（`BTSpinMiniIcon`/`SpinDisplay`/`PowerDisplay`）渲染成图、CoreGraphics 合成到帧上，App 改样式导出自动跟，零样式漂移。
  3. **导出背景改暗色**：`RenderContext` 设 `scene.background = .black`（与 App 场景页 `Color.black` 一致），HUD 白字可读 + 视频观感与 App 统一；所有导出产物（含 gif/card）统一暗底。
  4. **范围**：`Options.showShotHUD`（teaching 默认开；gif/card 关——小尺寸糊成噪点）；`sNN_still` 教学静帧带 HUD（1280×720，天然成「带完整击球参数的单杆教学图」）；`initial/final` 纯布局图不带（1280×640）；编排台 App 内不加（打点盘/滑条本身在屏上）。
- **验证**：`make position-export` 实跑 3 条序列 xcresult `Passed`（含真实比例修正后重跑）；规格核验：full/sNN.mp4 1280×720@60、sNN_still 1280×720、initial 1280×640、cover 640×320、gif 480×240；抽帧核验：HUD 显示「高43% · 右1% | 轻推 0.8 m/s」与「低79% · 左31% | 中 3.3 m/s」均与该杆 JSON 参数一致，真实比例版红斑落在打滑极限虚线圈内（低杆贴圈下缘 + 略左），运动帧 HUD 常驻、暗底白字可读。lint 0。**首版坑**：`ImageRenderer` 离屏渲染把 HStack 文本压窄成竖排折行（「轻/推/0…」）——HUD 视图须 `.fixedSize()` 按理想宽度展开。
- **影响**：`SequenceVideoExporter.swift`（Options +`showShotHUD`/`outputSize` + `ShotHUDView` + `makeHUDImage`/`composeWithHUD` + 场景黑底）、`BTSpinPad.swift`（`BTSpinMiniIcon` +`trueScale` 模式）、`content/position_play/README.md`（产物规格更新）。
- **替代方案**：①HUD 画进 3D 场景——2D 参数面板进 SceneKit 受相机约束且别扭，弃；②CoreGraphics 照画一份组件——App 改样式导出漂移，弃；③白底 + HUD 深色衬底——与 App 暗色语言割裂且属补丁，弃；④瞄准点/接触点标注——用户判定教学意义不大，不做。
- **遗留**：HUD 目前只含打点/力度，目标球/袋口等本杆意图信息若教学文案需要，留给 meta sidecar 文字层而非画面层。

### ADR-P11-14 — 序列出片首次接入动作库（drill_c042 demo）+ 图文精讲「应用课」模板

- **日期**：2026-06-13
- **状态**：已实施（demo 验收）
- **背景**：媒体管线产物（带 HUD 教学视频/单杆静帧）此前只落在 `build/position_play_export/`，未接入动作库消费端。用户拍板：现有 drill 视频后续整体替换，选一个语义契合的 drill 实测「录制 → 出片 → 内容接入」整链路；同时用户反馈现有图文精讲「太干巴巴」——纯文字四段、配图与击球参数脱钩。
- **决策**：
  1. **载体**：选 `drill_c042` 初级蛇彩走位（subcategory snakeDrill，与 3 杆序列 `seq_f4ded688` 的中线连续清台语义契合）。`shotIntent` 换为序列真实 3 杆（含 obstacles），`animation` 用首杆 composer 数据（source: composer），`videos` 替换 5 条旧 take 为 `full.mp4`（1280×720@60 带 HUD），缩略图随全量烘焙更新。
  2. **图文精讲「应用课」模板**（多杆走位类 drill 适用，技术类 drill 四段结构不变）：技术原理（理论锚点）→ 开局与击球顺序（initial 布局图 + 顺序规划逻辑）→ 逐杆精讲（每杆一节：为什么/怎么打/自检，配带 HUD 的 sNN 静帧，打点读数与 HUD 同口径=占打滑极限百分比）→ 常见错误与纠正 → 进阶练习。
  3. **工程修正**：`DrillTutorials` 由普通 group 改为 folder reference（project.yml excludes + type: folder），否则 `Bundle.main.url(subdirectory: "DrillTutorials")` 解析不到子目录（drill_c005 配图为潜在受害者）。
  4. **临时项**：`isPremium` 由 true 临时改 false 供 demo 验收（无订阅时精讲/视频区被锁），**发布前回滚**。
- **验证**：全量缩略图重烘焙 xcresult Passed（c042 缩略图为新布局首杆真算轨迹）；UI 测试 `testDrillC042TutorialDemo` 截图 8 张核验：详情页 live 场景/打点盘/力度条 0.8、视频区 full.mp4 首帧缩略图、精讲 7 节逐节配图正常（HUD 读数「高43% · 右1% | 轻推 0.8 m/s」等与 JSON 一致）。
- **影响**：`Drills/positioning/drill_c042.json`（重写）、`Resources/Videos/drill_c042/`（take_01–05 删除 → full.mp4）、`Resources/DrillTutorials/drill_c042_{initial,s01,s02,s03}.png`（新增）、`project.yml`（DrillTutorials folder ref）、`ScreenshotTourUITests.swift`（+临时验收测试）。
- **替代方案**：①新建 `drill_pp_<id8>` 不动存量——会让 demo 游离在分类/计划体系外，且用户已确认旧视频整体替换，弃；②`shotIntent` 批量从存量 drill 转序列出片——用户判定存量 shotIntent 数据精度不可靠，示范击球以编排台人工录制为准，不做。
- **遗留**：a) `isPremium` 回滚；b) 临时 UI 测试到验收完成后移除或转正；c) 「应用课」模板回写 content-engineering SKILL 的 SOP（待用户确认模板定稿）；d) 其余 71 个 drill 的示范击球录制排期。

### ADR-P11-15 — 3D 静态斜视角教学视频（短边沿长轴）+ 透视自动取景 + 双分辨率档（与 2D 并存）

- **日期**：2026-06-18
- **状态**：已实施（端到端跑通 + 抽帧验收）
- **背景**：现有教学视频是 SceneKit 3D 场景用**顶视正交相机**拍的「2D 视频」；用户希望同时出 **3D 斜视角视频**用于 App 内竖屏播放。底层 `CameraRig` 早已支持透视（`Scene3DAimingView` 在用），缺口是导出器 `RenderContext` 把相机钉死成顶视正交、且整段相机不动。
- **决策**（用户拍板 4 点）：
  1. **主用途竖屏 + 短边默认**：相机在一端短库后方、沿长轴看进去的**静态斜视角**（默认 +X 端看向 −X，俯角 30°、竖直 FOV 46°）。
  2. **看全桌面 = 自动取景不变量**：新增 `SequenceVideoExporter.solvePerspectiveCamera`——固定俯角 + FOV，沿后退方向二分推距离使球桌**外框 8 角点**全入框（6% 余量）。球恒在 playfield 内 ⇒ 外框装下即所有在桌球可见（与球形无关，静态机位成立）。禁 magic number（呼应几何技能）。FOV 锁竖直方向（`projectionDirection = .vertical`）使 fit 数学确定。
  3. **2D 与 3D 并存**：2D 现有产物（stills/cover/preview/gif/full.mp4）全保留；3D **只新增视频**（`full_3d.mp4` + `sNN_3d.mp4` 手机档；`full_3d@1440.mp4` 高分档仅整段）。
  4. **双分辨率**：手机档 720×1280（OTA，App 内播放）、高分档 **1440×2560**（外站备用，不进 Bundle）。
  - **3D 专属契约**：① studio 光照（`enhancedRendering`，IBL + 接地阴影，与 `Scene3DAimingView` 同源）使球立体接地；② 进袋球到达袋心后沿 Y **下沉 7cm 再淡出**（仅导出层加 Y，不动物理）避免平面凭空淡掉穿帮；③ 轨迹线 `lineRadiusScale=1.3` 补远端变细；④ HUD 条高竖版随宽等比（720→80、1440→160）。
- **验证**：`make build` BUILD SUCCEEDED；新增 `SequencePerspectiveFitTests` 5/5（8 角点投影全入框 + 取景最小可行 maxRatio>0.97 + 近库不遮挡近端球 + 端点镜像，覆盖 5 俯角×3 FOV 批量不变量）；`make position-export` 4 序列端到端跑通，产出 `full_3d.mp4`(720×1360)/`full_3d@1440.mp4`(1440×2720)/per-shot；抽帧核验（seq_f4ded688）：全台可见、近库不挡球、studio 阴影立体、轨迹线/假想球/球杆/HUD 正常、进袋球沉入侧袋（t=8.7 蓝球入袋、t=9.0 已没）。
- **影响**：`Core/Media/SequenceVideoExporter.swift`（CameraMode/Perspective3DConfig/solvePerspectiveCamera/3D 分支/落袋 Y 下沉/HUD 条高）、`QiuJiTests/PositionPlaySequenceExportRunnerTests.swift`（追加 3D 产物）、`QiuJiTests/SequencePerspectiveFitTests.swift`（新增）、`content/position_play/README.md` + content-engineering SKILL（渲染矩阵）。
- **物理边界（诚实标注）**：仍是 **2D 平面物理**（球恒在球面高度），3D 只换相机——**跳球/扎杆腾空** 出不来，需扩物理引擎到三维（不在本 ADR 范围）。
- **接入 demo（2026-06-18）**：`full_3d.mp4`（手机档 720×1360）已拷入 `Resources/Videos/drill_c042/`，`drill_c042.json` `videos` 追加 `{id:"full3d",file:"full_3d.mp4"}` 与既有 2D `full` **并存**；`make build` ✅ + bundle 内含两 mp4；`testDrillC042TutorialDemo` 通过，截图 `c042-02-detail-video` 确认详情页「视频示范 **2 段**」（第1段 2D 顶视 / 第2段 3D 斜视角），第2段缩略图由真实 `full_3d.mp4` AVAsset 解码渲染 ⇒ 播放器同路径可播。注意：`scripts/import-videos-to-app.py` 仅服务项目 15 的真机录屏（`take_NN.mp4`）且会重写 `videos`，**不适用**本 demo 的合成渲染视频，c042 走手工接入（与 ADR-P11-14 的 `full.mp4` 一致）。
- **遗留**：a) 俯角下界（近库遮挡）用近似库顶坐标 (x≈1.34, y≈0.85)，已抽帧确认 30° 安全；b) ~~3D 视频接入 drill `videos` 字段消费~~ → drill_c042 已接入（见上）；OTA 通道（依赖 H-14）仍待做，其余 drill 的 3D 视频接入待批量出片后排期；c) 动态镜头（跟拍/环绕）为后续增强，本轮只做静态；d) 详情页缩略图标签为「第 N 段」泛化命名，无 2D/3D 文字区分（两段缩略图视觉可辨；如需文字标签须给 `DrillVideo` 加 `title` 字段+UI，超本轮范围）。
