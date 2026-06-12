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
