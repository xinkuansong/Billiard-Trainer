# W17 工作记录 — 裁定平面、呈现空间

坐标契约：SceneKit 世界 XYZ、Y-up、米；袋口圈判据来自 `TableGeometry` 平面模型（`AngleSceneCalculator.pocketDropRadius`）。所有测试在 `QiuJi-v63-iOS17` 专用模拟器（`51383D5F-…`）、`SWIFT_OPTIMIZATION_LEVEL=-O` 下运行；日志在 `output/3d-v63/W17/`。

## W17-A — 求解裁定层切回平面判据（2026-09-14，DR-293）

### 变更
- `EventDrivenEngine.SimulationModel.appDefault = .planarReference`；原空间袋口策略保留为显式 `SimulationModel.spatialPockets`（`.localPockets(material: .tablePhysics(clothRestitution: 0.3))`）。`ShotInput` / `simulateFree` / `BreakSimulator.breakShot` / `ReflectionSolverCore` 的默认参数全部跟随，未逐处改调用点。
- `EventDrivenEngine.simulate` 主循环退出前补评一次早停判据：早停是状态谓词而非事件，平面 `.spinning` 纯自旋尾段可跨过 `maxTime` 且不再产生事件，循环内每 8 事件的检查永不触发 ⇒ 兴趣球命运已定却报 `.timeLimit`。w17a-regression-r1 里 `test_positionSolve_scoringOnly_matchesFullPhysics` 在 spin=±0.3、v=5.4 两组即此因失败；补评后通过，全保真路径不受影响（它走 `completePlanarSpinTail`）。
- 测试：以下用例本就在验证空间袋口行为，改为显式 `.spatialPockets`（**W17-C 清单第一批**）：
  - `PhysicsEngineTests`：L532 模型对照循环、五条 H01 腾空用例（`testSpatialStrikeThroughClothProducesFlightAndLanding`、`testMixedEngineInitiallyAirborneBallFollowsGravity`、`testAirborneMainEngineClearsOrHitsObstacleAccordingToHeight`、`testAirborneMainEngineClearsOrHitsRailAccordingToHeight`、`testMainElevatedStrikeLandsAndReleasesAirborneOwnership`）、`test_middlePocketFirstReboundSurfaceEvidence`、`test_defaultPocketLeatherResponseSensitivity`。
  - `TrajectoryRendererTests` L1202 模型对照、`testDefaultPocketEdgeStepSensitivity`；`ScoringOnlyConsistencyTests` L272 模型对照。
  - `BreakFlowRunnerV6Tests.testNineBallPageSeedCompletesAtDefaultPower`（交接间距预算）、`testRecordedSlowFifteenBallBreakCompletes`（collection tail 断言）。
- 测试：以下用例断言的是「默认路径产生空间产物」，该契约已被用户裁定退役，改写为新契约（**W17-C 清单第二批**，均注明 W17-B/D 须补默认路径呈现断言）：
  - `PocketGeometryInjectionV63Tests.testDefaultPredictionUsesPhysicalPocketCapture` → `testDefaultPredictionUsesPlanarVerdictAndSpatialOnlyWhenRequested`：默认 `confirmedCaptures` 为空、`pocketEntries` 非空、`cuePocketed`；显式 `.spatialPockets` 才有物理捕获。
  - `testSpatialSequenceEncodesAtTwoFrameRates` → `testPottedSequenceEncodesAtTwoFrameRates`：前置由「有 collection tail」改为「目标球判进」；两帧率时长一致断言保留。
  - `testTwoCornerShotsExportWithoutRevivingPreviousCapture`：捕获 ID 断言改为平面判进 + `confirmedCaptures` 为空；「上一杆被收的球下一杆不可见」断言保留；tail 比对循环在默认路径下为空转，等 W17-D。
  - `testExportSettledFramesPreservePredictedBoardWhenSavedOutcomeDiffers`：夹具（drill_c039 第 2 杆）在平面默认下与保存结果一致，前提消失 ⇒ `XCTSkipIf` 并写明原因；W17-C 须另找分歧夹具或退役该用例。**这是一条长期 skip，不算通过。**
  - `CueScratchLifecycleV63Tests.testScratchPlaybackRedoAndPaletteRestoreAcrossViews`：删去 `collectionTailsByBallName[cue]` 非空断言（其余回放/规则断言保留）。
- 测试：`testCombinedPocketMaterialsPreserveEntryAndReboundOutcomes` → `testCombinedPocketMaterialsCaptureSlowAndFastEntries`。该用例直接调空间求解器、与 W17-A 无关；inj-ab-old（旧内衬参数）通过、新参数失败 ⇒ 是 DR-292 改变了结果：4 m/s 沿袋口内向进入的球原被刚性内衬弹回（`.returned`），耗能体下被捕获。按用户对内衬的裁定该结果是预期，断言改为两档速度均捕获、有 tail、无 `.returned`，能量单调断言不变。

### 实证
- w17a-regression-r1（切默认后首跑，PhysicsEngine + ScoringOnly + 两开球 + PlaybackSettle）：61 项 5 失败 0 重启 **6.8s**（同选择集 liner-regression-r4 在同一模拟器耗时数百秒）。失败 = 3 条空间证据用例取 nil 记录、开球交接断言、scoring-only 早停两组。
- w17a-regression-r2（加 BreakFlowRunnerV6 全套 + TrajectoryRendererTests）：83 项 1 失败（`testRecordedSlowFifteenBallBreakCompletes` collection tail）→ 改显式模型。
- w17a-full-r1（整个 `QiuJiTests` 目标）：exit 65、12 次重启。与 W17-A 相关的失败已按上表处理；**与 W17-A 无关、既有的失败**（不在本批闭合，逐条留证）：
  - `PocketGeometryV63Tests` 7 条（`testBagMotionConvergesAcrossEnvelopeResolutions` 等）`supportConvergence(stage:"force",contacts:2)`，dt≈1e-15、袋底(0,1,0)+内衬斜面双接触：直接调空间求解器，与默认模型无关；pg-ab-old（内衬旧参数）逐条同样失败；`testBagMotionConvergesAcrossEnvelopeResolutions` 在全部 v63 日志里从未有过通过记录（最早失败 09-13 02:47）。归 W07 空间求解器遗留。
  - `PocketGeometryInjectionV63Tests`：`testMixedCollectionRecordsPhysicalEntryAndStops`（`isBallPocketed` 于捕获时刻）、`testCornerBagFiveConstraintSupportConverges`（1e-12 级）、`testTwoConsecutiveTableBallsEnterAndInteractInsideBundledBag`（同 supportConvergence）三条 inj-ab-old 旧参数下同样失败；`testBundledNumericAssetMatchesAllSixPocketsAndReusesSnapshot`（`localHalfExtent` 0.2086 vs 0.18）最后通过记录为 09-12 23:47。均为 09-13 06:00 之后其他批次引入，未归因，不得记在 W17-A 或 DR-292 上。
  - `TableAssistSurfaceV63Tests` ×4 / `TrainingAssistSceneTests`（0.801 vs 0.7957 台面高度）、`AimCloseup*` ×2、`V53/V54*` 数据层 ×6 及其 10 次重启：与物理无关。
- w17a-injection-r1 / r2：改写后的 6 条（含 CueScratch）全部通过、1 skip、0 重启（r1 里 CueScratch 作为进程首个用例启动 31s 即重启且无输出，r2 单独跑 24s 通过，按首启动抖动处理，不计为通过依据以外的结论）。
- 性能 A/B（同一构建、同一模拟器，仅 `appDefault` 临时切换，`perf-spatial-baseline.log` vs `w17a-injection-r1.log`）：

| 用例 | 空间默认（v63 W03–W16） | 平面默认（W17-A） |
|---|---|---|
| 单杆 predict 中位 | 204 ms | 4 ms |
| 满台（母球+8 障碍）predict 中位 | 6898 ms（预算 3000） | 27 ms |
| UI 进袋预测快路径中位 | 17.4 ms | 2.1 ms |
| 落区 .standard 无/带精修 | 0.36 / 0.35 s | 0.01 / 0.01 s |
| 过点 .passThrough | 0.29 s | 0.01 s |
| 批量出片等价盘面 | 0.20 s | 0.02 s |
| 翻袋典型 / 最坏 | 1.478 / 1.763 s | 0.025 / 0.062 s |
| 反射典型 / 最坏 | 0.161 / 0.721 s（7 / 6 解） | 0.013 / 0.022 s（14 / 9 解） |
| 斯诺克 .standard | 7.51 s（8 解） | 0.63 s（6 解） |

解数差异是两套判据的裁定不同（预期），不是性能指标的一部分；W13 默认防守 20 s 级问题按此量级应随之消失，但未在本批重跑防守用例，不宣称。

### 未做 / 交接
- ~~W17-B/D 接手时必须在默认路径补回三处呈现断言~~（已在 W17-B/D 补回，见下）；`testExportSettledFrames…` 长期 skip 仍在，归 W17-C 遗留。
- ~~平面记录下退回 pre-v63 的「吸到袋心」视觉腿~~（W17-B/D 起默认路径由网兜脚本接管）。未做真机或页面目测。
- W17-A 已随 `a19029aa` 提交。

## W17-B/D — 平面判进后的网兜确定性落位（2026-09-14，DR-294）

### 方案偏离声明（须用户知晓）
方案 v63.13 的 W17-B 写的是「判进后用 `LocalPocketSimulation` 跑 ≤0.3 s 单球下落段」。本批**没有**调用空间求解器，改为脚本化下落（W17-D 本就是脚本），理由：
1. 空间求解器在「袋底 + 内衬斜面双接触」形态下有未闭合的 `supportConvergence` 停滞（本批仅修掉其中 dt≈1e-15 的舍入族，见 DR-295；dt≈2.4e-4 的真实停滞族仍在 4 条用例复现）。W17-B 要跑的正是这一形态，接上就是把已知会抛错的路径接到每次进袋回放上。
2. 平面默认下 App 不再加载 `PocketGeometryAsset`（USDZ 网格 + BVH，首载约 2 s）；为呈现段加载会把首杆进袋回放卡 2 s。
3. 脚本对实时/导出天然同源、确定性、零求解失败，且**使用同一套物理常量**（`TablePhysics.gravity`、`pocketLinerRestitution=0`、`pocketLinerRetention=0.4`）与从资产实测的网兜几何。
空间 B 仍可作为后续替换（tail 结构与来源无关）。这是「有更优路径主动提」而非悄悄改范围；若用户坚持真跑空间求解器，需先闭合 DR-295 之外的停滞族。

### 坐标契约（动代码前钉死）
- SceneKit 世界系，X–Z 水平、Y 朝上、米。台呢面 `surfaceY=0.8`，球心台面高度 0.828575。
- 平面袋心/落袋半径真源：`TableGeometry.chineseEightBallQiuJi(surfaceY:).pockets`（= `TablePhysics.cornerPocketCenterOffsetX/Z` 1.312/0.677、`sidePocketCenterOffsetZ` 0.676；半径 0.042/0.043），与 `AngleSceneCalculator.pocketPositions` 一致（探测核对）。
- ⚠️ `TrajectoryPlayback.surfaceY` 实为**球心平面**（各调用点传 `yLevel = surfaceY + R`），不是台呢面。首版用它算落位差了整整一个 R（端到端用例 y=0.7259 vs 0.6973 抓出）；现改为从 `PocketEntrySnapshot.geometry.pockets[].center.y`（台呢面）取真源。
- 网兜几何（`output/3d-v63/W17/bag-probe.log`，`PocketGeometryAsset.bagEnvelopes()` / `captureBoundaries()` 实测）：网口 y=0.760（深 0.040）；角袋底 0.66874 → 静止球心 0.69731（深 0.10269）；中袋底 0.66802 → 0.69660（深 0.10340）。环均值半径 0.0565→0.0330（角）/0.0579→0.0335（中）；袋轴随深度向台心内倾（角袋底部内移 16.4 mm；中袋网口外扩 14.9 mm）。球心可达半径 = 环半径 − R，袋底仅 ≈4 mm ⇒ 单球对中；网深 3.2R ⇒ 容量 2。

### 变更
- 新增 `QiuJi/Core/Physics/PocketNetPresentation.swift`：`PocketNetProfile`（角/中袋 4 环剖面 + 静止深度，常量注明来源）、`NetPocket.wall(at:)`（板孔→网口漏斗过渡，无台阶）、`slots`（槛 0 袋轴底部；槛 1 叠于其上 2R、向网口轴倾 18 mm）、`descent`（240 Hz 步进：重力；触底不反弹且水平速度 ×retention；触壁投影回、法向速度归零、切向 ×0.4；触后自旋 ×0.4；静止后 0.12 s easeOut 落到槛点）、`shift`（FIFO 下移）、`attach(to:)`（按 `pocketEntries` 时间顺序建队列、容量 2、第 3 球进时最早球 `fadeStart` = 新球进袋时刻，其余下移一槛）。
- `PocketCollectionTail` 新增 `samples`（采样插值）与 `fadeStart`；新 `init(samples:gravity:fadeStart:)`；`sample(at:)` 二分插值。
- `TrajectoryRecorder.recordPlanarCollectionTail`：只允许挂在有 `pocketEntries` 且无 `confirmedCaptures` 的球上，起点时刻须等于进袋快照时刻；允许覆盖（队列下移/淘汰）。
- `TrajectoryPlayback.init` 调 `PocketNetPresentation.attach`（幂等，一个 recorder 只建一次）；`collectionOpacity` 对无 `fadeStart` 的网兜球恒为 1；`action(for:)` 仅对会淡出的 tail 才 `removeFromParentNode`，网兜球节点保留在槛点。
- 测试：新增 `PocketNetPresentationTests` 7 条（剖面 vs 资产 24 环门禁、槛点在网内、6 袋 × 4 速 × 3 角 × 2 槛 = 144 次下落不变量：末点恰为槛点/时间严格递增/高度单调不反弹/不低于槛底/球心不出壁、确定性、回放挂尾、FIFO 三球、端到端默认判进落槛）；补回 W17-A 留下的三处默认路径断言（`testPottedSequenceEncodesAtTwoFrameRates` 改为「网兜球全程可见、不淡出」+ 每帧位置/透明度与回放一致；`testTwoCornerShotsExport…` 每杆 tail 集合 = 目标球；`CueScratch…` 洗袋母球落中袋槛 0）；`BreakFlowRunnerV6Tests` 新增 `testRecordedBreakDefaultPathAttachesNetTails`（默认开球全部进袋球有 tail、每袋可见球 ≤ 容量）。

### 实证
- `net-r2.log`：PocketNetPresentationTests 7/7 通过。
- `w17bd-r2.log`：PocketNetPresentation + 两条导出用例 + PositionPlayFreeAim + BreakFlowRunnerV6 + CueScratchLifecycle 共 41 项 0 失败 0 重启。
- 出图自检（临时 dump → matplotlib，未入库）：角袋 0.4/2.5 m/s、中袋 1.2 m/s 三例侧视 + 俯视：慢球抛物线入网口后沿锥壁滑到袋底；快球飞越孔轴撞对侧网壁后贴壁下滑；全程球心在壁内、末点为槛点；用时 0.31–0.70 s。
- 空间求解器（DR-295 附带）：`w17bd-r1.log` 中 dt≈1e-15 舍入族 3 条消失，`testBagMotionConvergesAcrossEnvelopeResolutions` 首次通过；dt≈2.4e-4 的 `supportConvergence` 真实停滞族仍 4 条（`testCriticalPocketStepConvergence`、`testLoadedPocketSpeedAndStepMatrix`、`testNearPocketMotionFrames`、`testTwoConsecutiveTableBallsEnterAndInteractInsideBundledBag`）、1e-12 级 2 条、`isBallPocketed` 时刻 1 条、`localHalfExtent` 1 条、`testPocketEdgeAndReturnCharacterization` / `testSpatialIndexMatchesExhaustiveMotion` 2 条——全部为既有、与 W17 无关，留证不闭合。

### 未做（诚实清单）
- **跨杆保留（W17-D「八杆序列跨杆保留」）未做**：回放结束时各页面 `finishStrike/finishPlayback/placeStepBoard` 仍按盘面把进袋球 `isHidden = true`（8 处调用点，6 个 ViewModel/View），网兜球在全部球停止的瞬间被隐藏而非淡出。要做需在页面层引入「袋内球状态」并改动 `isHidden` 作为在桌判据的用法，本批未动页面层。
- **W03 空间裁剪例外与截图证据、真机/页面目测未做**：单球样片未经用户实看即铺六袋（用户已裁定「一起实施」，但方案完成标准写的是先看样片）。
- 网口以上板孔段按落袋半径圆柱建模、网壁按环均值圆截面，非 USDZ 真实非圆截面（rmin/rmax 差 ~15%）。
- `testExportSettledFramesPreservePredictedBoardWhenSavedOutcomeDiffers` 仍为长期 skip。

## W17-B/D 返修 — 极坐标真实袋壁 + 只吃水平速度的内衬接触（2026-09-14，DR-297）

### 触发
用户实看 DR-294 版：①球撞皮革后穿进皮革；②撞后垂直下落远慢于重力；③要求「吃掉水平速度后，按重力 + 壁型 + 支架轨迹落到底，多球先进先出不变」。

### 根因（探测实证，`output/3d-v63/W17/leather-probe.log`、`leather-probe-polar.log`）
- 穿模：DR-294 网口以上按「落袋圆（R 42 mm、圆心 = 平面袋心）→ 网口环」漏斗。对皮革 + 库颚 + 网绳做球体-网格洪泛探测（2 mm 网格、5 mm 层）：**角袋皮革杯在台呢高度的球心自由区半径 ≈18 mm、轴心在平面袋心内侧 ≈24 mm**；平面袋心处球体已碰皮革 0.3 mm；落袋圆的角侧远端在皮革里 ≈48 mm。中袋自由区沿库拉长（后壁 30.5 mm、颚口 15 mm），圆拟合 rms 8.6 mm，用单一半径会把竖直后壁拟合成 45° 假斜坡。
- 慢落：`descent` 触壁时对整个切向速度（含 `v.y`）每步 ×0.4，内倾壁上 240 Hz 连乘 ⇒ 角袋 ≈0.07 m/s 蠕动。

### 变更（`PocketNetPresentation.swift`，呈现层，规则/评分/`PocketCollectionTail`/`TrajectoryPlayback` 契约不动）
- `PocketNetProfile.Ring`：深度（**球底**低于台呢）每 5 mm 一环、0–130 mm 共 27 环；每环 (dx,dz) Kasa 拟合轴 + 12 方向（30°，自内向 X 轴向内向 Z 轴）球心可达距离；朝台面开放方向按落袋圆 +2 mm 封顶。删除漏斗与 `mouthDepth`。角/中袋各一表，其余四袋镜像（测试对全部六袋核）。
- `NetPocket`：`axis(at:)` / `reach(at:toward:)` / `surfacePoint` / `wallNormal`（竖向 × 环向切线叉积，壁收窄法向朝下、外扩朝上）；`slots` 槛 1 向自身高度处轴心倾。
- `descent`：重力唯一加速；触壁沿射线投影回星形区；到达冲击（前一步未接触且 `vn > impactSpeed` 0.05）整体切向与自旋 ×0.4（同空间 `linerSink`）；持续接触只去法向分量后分解切平面：沿坡向仅受 Coulomb 摩擦（μ = `cushionFriction` 0.2 × [max(0,−g·n_y) + v_环²/reach]），环向按 `linerGripTime` 0.05 s 衰减；`v.y` 不乘任何系数；`v.y > 0` 钳 0（软裙不抬球）。入袋快照在壁外的初始重叠 60 ms 内线性收回。`settle`/`shift` 末样本精确 = 槛点。

### 实证
- `net-r5.log` PocketNetPresentationTests 9/9：
  - `testProfileMatchesBundledPocketMeshes`：6 袋 × 9 环 × 12 向，轴与 0.9×reach 处球体侵入网格 ≤ 3 mm；reach+6 mm 处（非封顶向）必被挡。
  - `testDescentBodyStaysOutOfTheBundledMeshes`：6 袋 × {0.3,1.2,2.5} m/s × {−0.6,0,0.6} rad，收回期后球体最大侵入 **1.03 mm**（漏斗版同口径最坏 ≈48 mm；单半径圆版 2.8 mm）。
  - `testDescentFallsUnderGravityAfterLinerContact`：到达时水平 1.2→<0.1 m/s 且在 0.1 s 内；离壁步 dvy = −g（1e-6）；近垂直壁（|n_y|<0.2、法向转角<0.1）持续滑动 dvy ≤ −0.8 g；触底角袋 0.1875 s、中袋 0.25 s（自由落体 0.164 s，上限 1.8×）。中袋 1.5× 来自资产网兜网口下方真实内收段（n_y ≈ −0.6，深 65–100 mm）——是壁型，不是阻尼。
  - 其余 6 条（槛点在壁内、144 次下落不变量、确定性、回放挂尾、FIFO 三球、端到端）通过；「球心在壁内」断言改为收回期之后生效。
- `net-related-r1.log`：PocketNetPresentation + TrajectoryRenderer + CueScratchLifecycleV63 + BreakFlowRunnerV6 + PhysicsEngine 共 87 项 0 失败 0 重启。
- 轨迹目测（临时 dump，未入库）：角袋 1.2 m/s 直入——0.0375 s 撞后壁、水平 1.2→0.026、随后 vy 以 g 递增至 −1.49 触底；中袋——网口下 0.65–0.70 s 贴内收段滑行两次被壁型减速再自由落体。

### 未做
- 返修版**仍未经用户实看**（真机/页面）。
- 跨杆保留（页面层 8 处 `isHidden`）、W03 裁剪例外截图、`testExportSettledFrames…` 长期 skip：同 DR-294。
- 极坐标表 2 mm 网格 ±1 mm 噪声未平滑，环间线性插值在中袋内收段有法向折点（触发的是几何重定向，不是阻尼）；若目测有可见抖动，下一步 3 点平滑 reach 表并重跑两条门禁。

## W17-B/D 二次返修 — 穿过网兜底环、沿回球支架滚到挡头（2026-09-14，DR-298）

### 触发
用户实看 DR-297 版：「重力挺像了，但球停在袋网底部，我要的是继续往下滚到支架底部」。用户附图：内置桌型为开口网兜 + 金属回球支架（两根杆从网兜底沿台边斜向下到桌腿处挡头）。

### 根因
DR-294/297 把 `PocketCaptureBoundary.restingCenterY`（捕获边界的球心最低点 = 网兜底环）当槛点地板；支架从未建模。裁定几何被当成了呈现终点。

### 实测（`output/3d-v63/W17/rail-probe.log`，球体-网格支撑探测，六袋）
- 袋下几何按材质分层：`Black` = 支架双杆（y 0.52–0.60）+ 网兜底悬挂件；`Gold` = 挡头（角袋 x ≈ 袋心内侧 0.175–0.20，y 0.48–0.56）+ 悬挂横杆；`MG_Gold` = 桌腿；`White` = 网绳。第一版从台面向下探支撑先撞桌裙/桌腿得到 y=0.722 的假槽线——必须只用杆材质找支撑、再用全部材质核自由。
- 槽线（球心）：沿 `NetPocket.axisX`（内向 X；中袋两侧均 +X）直线，横向偏差 ≤ 3 mm。角袋 s 0.030→0.160：y 0.6190→0.5635；中袋 s 0.015→0.145：y 0.6170→0.5615；斜率 −0.427（23.1°）。挡头接触位角袋 s ≈ 0.162、中袋 s ≈ 0.148。四角袋、两中袋各自镜像一致。
- 底环：沿底环轴心球心 y ∈ [exit−32, exit−17] mm 被 `White` 挡、再往下无白 ⇒ 底环内径 ≈ 50 mm，比球小 ≈2.5 mm（资产瑕疵，真实产品开口）。

### 变更（`PocketNetPresentation.swift`，呈现层）
- `PocketRailProfile{startDrop, slope, stopDistance, firstClearDistance}`：角 (0.1682, −0.427, 0.162, 0.030)，中 (0.1766, −0.427, 0.148, 0.015)。
- `NetPocket`：`rail`、`netExitY`（= 台呢 − `restingDepth`）、`railPoint(atDistance:)`、`railTangent`/`railNormal`、`railDistance(of:)`、`railHeight(under:)`。
- `slots`：支架槛点链——第 1 球靠挡头，之后每球沿斜面 2R 相接直到 `firstClearDistance`；角/中袋各 3 个，FIFO 容量 = `slots.count`（删 `netCapacity`、`upperSlotLean`）。
- `descent` 三段：网兜段（DR-297 不变，去掉地板）→ 球心低于 `netExitY` 自由落体 → 触槽线着陆：零恢复、只留沿杆分量且 `max(0,·)` 不倒滚、横向 V 槽对中 τ=10 ms → a = g·sinθ·5/7 滚下、纯滚动 ω=(n×v)/R → 到槛点死停，末样本精确 = 槛点。

### 实证
- `rail-r6.log` PocketNetPresentationTests 10/10：
  - `testRailProfileMatchesBundledRods`（加载 USDZ）：六袋槽线每 1 cm 站点球体离所有材质 ≤ 1.5 mm、下 4 mm 必在 `Black` 内；槛 1 + 6 mm 碰 `Gold`；底环 exit−25 mm 存在、exit−40 mm 以下无白；脚本支架段（`firstClear`+5 mm、着陆 20 ms 后）球体侵入角袋 0 / 中袋 1.0 mm，着陆瞬态 ≤ 2.0 mm（角袋离轴 7 mm 着陆骑杆 2–3 帧，在底环下方）。
  - `testDescentFallsUnderGravityAfterLinerContact`：离网后有自由落体步（角 22 / 中 17 步）、支架上每步 Δv∥ = g·sinθ·5/7、速度严格沿杆、末样本 = 槛点；全程角袋 0.537 s / 中袋 0.628 s。
  - `testSlotsLieOnTheRail`、216 次下落不变量、FIFO 四球、端到端。
- `rail-related-r1.log`：TrajectoryRenderer 27 + BreakFlow 默认开球挂尾 + 走位 scratch + CueScratchLifecycle 共 35 项 0 失败。

### 未做
- 返修版**仍未经用户实看**。
- 底环穿过为脚本取舍；严格不穿需改资产（底环放大 ≥ 3 mm）。杆间距/杆径未测（横向对中按时间常数）；挡头零恢复无回弹。
- 跨杆保留、W03 裁剪例外、`testExportSettledFrames…` 长期 skip：同 DR-294。

## W17-D 跨杆保留 — 支架驻留 `PocketRailInventory`（2026-09-14，DR-299）

### 触发
用户实看 DR-298 版：「球到支架底端后，只有一颗球也会自动消失」。澄清后的规则：永远只有 16 颗球；进袋球就算进了球库、留在支架上；同一颗球再放回球桌时支架里的它消失、后面的球按顺序前移（1,2,3,4 拿走 2 → 1,3,4）。

### 根因
不是 FIFO。支架球用的是盘面节点，8 处页面 finish 处理器在回放结束把进袋球 `isHidden=true` / 复位重摆，节点被页面拿走。即 DR-294 记录的「跨杆保留未做」。

### 做法
- `Core/Scene/PocketRailInventory.swift`：每 `AngleTrainingScene` 一份；驻留球 = 盘面节点 `clone()`；`Resident{clone, weak source, pocketID, slot}` 按袋 FIFO。
- `TrajectoryPlayback(railInventory:)`：`attach(preOccupied:)` 占位已驻留球于最低槛；`railResidencyAction` 让盘面节点只播台面段并在袋口隐藏，克隆体独立跑网兜/支架段并 `commit`；旧杆驻留球被挤出由 `evict` 同步动画。
- 回桌即离架：克隆体逐帧 `railWatch` 观察源节点 `isOnTable` → `release`（淡出 + 后方前移）；`occupancyByPocket` 先 `reconcile()`。
- 12 个场景回放创建点传 `scene.railInventory`；求解/导出为 `nil`。

### 验证
PocketNetPresentation 14/14（新增 4 条）、BreakFlowRunnerV6 19/19、回放/渲染/导出相关 268 项 0 失败；App `BUILD SUCCEEDED`。

### 补记：两球重叠（同日）
`ShotPredictor` 预览回放先 `attach`（无库存）且幂等 ⇒ 场景回放传库存也不重排。修：`recorder.planarTailOccupancy` + `attach(preOccupied:)` 非 nil 且不同即重排全部平面尾迹；观察改 10 Hz Timer（避免动作迫使永久渲染）。53 项 0 失败。

### 未做
用户实看；导出不含前几杆驻留球；页面「重置」不清支架（桌型重建才清空）。
