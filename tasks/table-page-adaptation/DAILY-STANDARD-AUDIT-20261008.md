# 每日清台标准与跨页复用审计 — 2026-10-08

源码：`09118e2dc7d8105e55a338f8fd0afaf1753840c8`。App源码改动：0；本轮不是生产迁移。

主文档：[每日清台完整标准与跨页面复用分析](../../docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md)。

## 结果与范围

- 37项定向单元测试实际执行并通过，0失败、0跳过；第一批35项，补充相机/材质隔离2项。按日志方法名和Executed核对。
- 测试前后361份QiuJi Swift源码SHA-256无变化。没有新建测试或修改生产实现。
- 独立模拟器：Daily-Standard-Audit-20261008，iPhone 17 Pro / iOS 26.3，UDID `1D02D993-A84E-4376-9AE8-3465A6DD9967`。测试使用Debug、关闭coverage，未与其他xcodebuild并行。
- 不是GPU像素验收、真实窗口UI操作、全页面/最低Runtime回归、真机性能或VoiceOver。历史B8证据单独引用，不计本轮测试数。

## 执行清单

|批次|测试类|实际通过数|
|---|---|---:|
|1|`ContinuousTrajectoryPreviewTests`|1|
|1|`Daily3DTrajectoryVisibilityTests`|1|
|1|`DailyAimSelectionTests`|4|
|1|`DailyLayoutMetricsTests`|18|
|1|`DailyPreviewWorkTests`|3|
|1|`OrbitInputV63Tests`|1|
|1|`PerspectiveStateV63Tests`|3|
|1|`PocketSelectionUXTests`|1|
|1|`RenderQualityV62Tests`|2|
|1|`RoomReflectionProbeTests`|1|
|2|`CameraSurfaceTests`|1|
|2|`ClothAppearanceTests`|1|

## 完整方法名

- `ContinuousTrajectoryPreviewTests/testSpinPreviewInvalidatesOnLeavingAndOtherHostsStayDiscrete`：通过
- `Daily3DTrajectoryVisibilityTests/testPreferencePersistsWithoutChangingSharedDetail`：通过
- `DailyAimSelectionTests/testBlockedPocketTemporarilyFallsBackAndNextLegalTargetRestoresPocket`：通过
- `DailyAimSelectionTests/testDirectionAdjustmentIsTemporaryButExplicitFreeModePersistsAcrossSelection`：通过
- `DailyAimSelectionTests/testIllegalSelectionPreservesAllAimInputsAndEmptyLegalSetRejectsEverything`：通过
- `DailyAimSelectionTests/testUnavailableExplicitPocketAcceptsIntentAndSwitchesFree`：通过
- `DailyLayoutMetricsTests/testBothStyleCapacityBoundariesRespectTMinusOneTAndTPlusOne`：通过
- `DailyLayoutMetricsTests/testCameraLaneUsesSafeCapacityAndRulerAxis`：通过
- `DailyLayoutMetricsTests/testControlCapacityPreservesProAndFitsSEWithoutShorteningRulers`：通过
- `DailyLayoutMetricsTests/testControlPaddingNeverSpendsMoreHeightThanAvailableAcrossDisplayPixels`：通过
- `DailyLayoutMetricsTests/testDailyCardUsesAvailableInnerSpaceAndLeavesSharedDefaultUnchanged`：通过
- `DailyLayoutMetricsTests/testDailySpinCardFitsInnerRailsAndStopsGrowingAtReferenceSize`：通过
- `DailyLayoutMetricsTests/testFewerBallsAndMoreSafeSpaceNeverDemandMoreWidth`：通过
- `DailyLayoutMetricsTests/testFoundationKeepsRealRatioSymmetricLanesAndBoundedControls`：通过
- `DailyLayoutMetricsTests/testFoundationReferenceCapacitiesAndSafeArea`：通过
- `DailyLayoutMetricsTests/testFullRowsKeepVisibleTitleAndActualBallHitsClearOfActions`：通过
- `DailyLayoutMetricsTests/testInvalidControlProposalsRemainFiniteAndReportInsufficientCapacity`：通过
- `DailyLayoutMetricsTests/testOverflowReservesFixedActionsAndACompleteTargetSlot`：通过
- `DailyLayoutMetricsTests/testPaletteWrapPreservesAllSlotsWithoutReducingBallFaces`：通过
- `DailyLayoutMetricsTests/testQualifiedProAndUninsetSmallPhonePreserveDesignIntent`：通过
- `DailyLayoutMetricsTests/testSettingsAnchorAndCapacityKeepSpinCardCentred`：通过
- `DailyLayoutMetricsTests/testSettingsViewportRespectsMeasuredStrikeWithoutMovingNaturalContent`：通过
- `DailyLayoutMetricsTests/testSpaceProtectsReferenceAndUsesDockOnlyForLargerProportionalTable`：通过
- `DailyLayoutMetricsTests/testWidthRoundTripHasNoHistoryAndTinyWidthsStayFinite`：通过
- `DailyPreviewWorkTests/testGeometryDependenciesIgnorePowerButInvalidateForAimAndBoard`：通过
- `DailyPreviewWorkTests/testRetainedLinesReuseNodesMaterialsAndUnchangedGeometry`：通过
- `DailyPreviewWorkTests/testUnrelatedUpdatesDoNotExtendRenderWindowButActivityDoes`：通过
- `OrbitInputV63Tests/testWholeTableFitsActualViewportAcrossYawAndSizes`：通过
- `PerspectiveStateV63Tests/testQuizSubmittedAnswerAndScoreSurviveSharedCameraSwitch`：通过
- `PerspectiveStateV63Tests/testRepeatedModeRequestDoesNotRestoreStaleObservation`：通过
- `PerspectiveStateV63Tests/testSequencePreparationKeepsStepAndIntentAcrossModes`：通过
- `PocketSelectionUXTests/testParameterUpdatesUseCachedGeometryAndNeverRewriteIntent`：通过
- `RenderQualityV62Tests/testDailyRenderingProfilesAreSceneLocal`：通过
- `RenderQualityV62Tests/testRoomCacheIsolation`：通过
- `RoomReflectionProbeTests/testPrefilterRoomStyleCacheAndRelease`：通过
- `CameraSurfaceTests/testDailyProductionDefaultAndOtherHostIsolation`：通过
- `ClothAppearanceTests/testIsolationRestorationAndShadowBindingsAcrossPipelines`：通过

## 可复核证据

- [结构化结果和方法耗时](../../output/daily-standard-reuse-audit-20261008/verification.json)
- [词法调用清单与源码指纹](../../output/daily-standard-reuse-audit-20261008/source-inventory.json)
- [首批原始日志](../../output/daily-standard-reuse-audit-20261008/tests.log)
- [补充隔离原始日志](../../output/daily-standard-reuse-audit-20261008/isolation-tests.log)
- [复跑命令](../../output/daily-standard-reuse-audit-20261008/reproduce.sh)：使用同一专用UDID；未来复跑前确认设备仍存在及无在途测试。

- xcresult：`/Users/song/projects/13.billiard_trainer/build/DerivedData/Logs/Test/Test-QiuJi-2026.10.08_00-18-16-+0800.xcresult`
- xcresult：`/Users/song/projects/13.billiard_trainer/build/DerivedData/Logs/Test/Test-QiuJi-2026.10.08_00-20-37-+0800.xcresult`

调用清单按源码词法匹配，排除了整行注释，仍可能包含声明和Preview；不能把匹配数量当产品页面数量。人工复核确认每日配置生产调用仅在FreePlayView每日分支；enablePlayerCameraControls消费者包括FreePlayView、ShotSimulationView和PositionPlayComposerView。

## 后续证据缺口

主文档R01–R10逐项登记。优先验证room-style probe首入顺序、临时俯视派生视图生命周期、稳定宿主与scene身份合同，再建立每日/P01同条件原生对照。当前只证明所选逻辑合同，未关闭所有渲染、摄像头与手感风险。

## 文档验证

57处新增/修改本地文件链接检查通过；361份Swift指纹未变；`git diff --check`、`make -f scripts/Makefile verify-doc-size`通过。PROGRESS旧头部摘要已移入受版本管理的`tasks/archive/PROGRESS-当前状态-归档.md`，保留历史而未提高体积上限。专用模拟器已确认Shutdown；没有关闭用户原有模拟器。
