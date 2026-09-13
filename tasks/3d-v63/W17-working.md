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
- W17-B/D 接手时必须在默认路径补回三处呈现断言（见第二批清单注释），并处理 `testExportSettledFrames…` 的长期 skip。
- 生产代码对 `collectionTailsByBallName` / `confirmedCaptures` 的四处读取（`TrajectoryPlayback` L243/247/253/444）均为可选安全，平面记录下退回 pre-v63 的「吸到袋心」视觉腿；未做真机或页面目测。
- 所有改动未提交（工作树含其他会话产出）。
