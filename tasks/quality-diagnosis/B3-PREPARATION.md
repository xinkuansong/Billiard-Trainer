# B3 内容与工具准备（snapshot-002，只读）

2026-09-05。范围 SC15–22/27/28。只读正常入口、代表测试断言与写盘点；未运行测试、未生成资产、未验证几何数值或实际UI。主控B1未结束，本文件不表示B3已开始。代码/测试输入来自冻结 `build/quality-diagnosis/snapshot-002`；产品规格引用当前仓库 docs/04 与已记录数据契约，发生新裁定时单独记版本，不能擅自改变被测快照。

## 有效预期、正常入口与主要限制

以下入口是代码路由存在，不是本轮已操作可达。入口源码为snapshot的 `QiuJi/Features/AngleTraining/Views/AngleHomeView.swift:157`–`:235`，目的页见 `QiuJi/App/MainTabView.swift:184`–`:231`。用户面默认进入“练习”Tab，再选学/练/打/解；有Pro门控的入口先区分Free引导与受控Pro工具行为，深链只作辅助，不替代正常路由。

| SC | 有效预期来源与可断言语义 | 正常入口/页面 | 本轮小批证据与仍缺项 |
|---|---|---|---|
| 15 完整性 | 契约§1/2/7：索引可解码、引用与实际包一致，来源不被静默丢弃 | 动作库→分类/搜索→详情 | 索引全量加载 + TutorialFigures实际Bundle解码。内容门禁C1无export证据仍未解决，图存在不证明是最新图；下架ID需实际包与可达性核实。 |
| 16 浏览收藏 | F1/F2：搜索/分类/球种筛选正确，收藏可恢复；不能串owner | 动作库Tab→搜索/筛选/收藏 | 本小批没有收藏UI或收藏持久测试选择器，不填通过。后续选已知结果集合，收藏退出重进和取消；账号隔离留B4。 |
| 17 教学 | 契约§1.1/6.5与内容规范：正文/逐杆图/球形对应，单位与实际训练意图一致 | 动作库→动作详情→精讲；练习→学/理教学页 | 本小批只证明加载与引用，不证明教学正确。后续至少12课分层逐图/文/序列复核；候选c001/c012/c016/c022/c042/c053/c065/c068/c070/c073/c076/c085，正式选择前核实快照分类/免费/多形标签，再确保所有要求分层。 |
| 18 试打 | F1+契约：选中球形进入对应盘面，返回不串形；无序列合法fallback；下架课不恢复 | 动作库→详情→上手试打→返回 | BoardStore全量解码/范围 + c042多形 + 无序列fallback；缺正常UI选择多形、精讲返回、手势、下架路由。 |
| 19 认知 | 契约§5.3：真实答题结果记cognitive，与tool/drill区分；保存失败保留答案与可重试 | 练习→练→角度预测/2D角度/3D角度/瞄准点/2D瞄准点/3D瞄准点 | 4 VM失败路径对应6页面共用逻辑，不能算6页UI均测过。需每页完成/取消/重复结束→记录核对，并检查额度与场景切换；本小批注入失败仓储。 |
| 20 分离/翻袋/反射 | F12/18/19：控制参数影响实际结果，成功/无解如实；显示库序应来自最终引擎结果 | 学→分离角图谱；打→分离角与走位(ShotSimulationView)；解→翻袋(BankShotView)/反射(DiamondSystemView) | 图谱切片、Bank/Kick典型解非空且排序/终验、瞄准金样。图谱不代替ShotSimulation全参数UI；理想/真实反射模式、力度打点、无解、下一解还需正常UI与独立数值核对。 |
| 21 编排/开球 | F13/16：摆球身份/数量正确，seed可重现且换局变化；击打终位合法、撤回恢复 | 打→自由走位(PositionPlayComposerView)/自由击球(FreePlayView)；开球控件在工具内 | Rack种子与9球真实开球终位断言；缺手动摆球、逐杆切换、撤回、两工具互送盘面、所有玩法UI。不能用架球布局正确代替开球动力学。 |
| 22 求解/防守 | F14/15：落区约束满足与降级区分，不把最接近当成功；防守目标/遮挡来自实际终位 | 解→思路训练(SiluTrainerView)/打一走二想三(PlanThreeView)/防守(SnookerTacticsView) | 思路大落区有解/不可达降级 + 防守非法输入/遮挡样本。三球逆推尚未列入小批，必须后续PlanThree正常/无解与独立第三杆目标验证；缺UI标记降级一致性。 |
| 27 拍照 | F17：手动4角校准、点标/选号、人工确认后送工具；自动识别不作为本轮既有承诺 | 打→拍照建球形(BallExtractionView，Pro) | Homography角点/逆变换/退化 + 实际Bundle权限文案。真机拍摄/TCC允许拒绝/相册取消/球号冲突/确认送工具需独立测试，权限字符串存在不等于权限流程可用。 |
| 28 音效回放 | F20：原速事件回放、不变调、尊重静音与偏好；素材待补齐 | 各工具击球回放 + 我的偏好音效开关 | TrajectoryPlayback尾段自然停稳断言，不能证明音频时序。本快照Audio目录仅3份Markdown无音频；ShotSoundBank.swift:11、:77明确缺资源no-op。归为素材条件缺失/预期降级，非本轮复现播放Bug。真机静音/听感/打断恢复待素材可用后测。 |

旧规格提醒：docs/04 F18描述纯镜像，但当前BankKick测试对引擎终验/最终库序有更具体约束，应再定位对应已接受后续裁定；不因旧一句话要求移除真实物理。F15旧称斯诺克，实际入口名“防守”，不要按旧标题寻找不存在按钮。界面中的“自由走位”是用户可达编排工具，与“批量出片台”分开。

## 首轮小批：34 个方法级选择器

只给一轮代表小批，不是B3完整覆盖；先等待B1释放专用宿主。每行前加 `-only-testing:`，串行执行，记录独立RUN、M/DATA、源码与选择器哈希。若求解耗时异常保留输出，不把print性能方法充当断言。

```text
QiuJiTests/DrillContentValidationTests/test_allIndexedDrills_loadSuccessfully
QiuJiTests/DrillContentValidationTests/test_index_allIdsUnique
QiuJiTests/DrillContentValidationTests/test_allDrills_haveNonEmptyRequiredFields
QiuJiTests/TutorialFiguresBundleTests/test_referencedTutorialImages_allResolveFromBundle
QiuJiTests/TutorialFiguresBundleTests/test_bundleTutorialFigures_containsNoPNGMasters
QiuJiTests/TutorialFiguresBundleTests/test_bundleTutorialFigures_countMatchesReferencedSet
QiuJiTests/TutorialFiguresBundleTests/test_publishedFigure_decodesAtSourceResolution
QiuJiTests/DrillTryoutBoardStoreTests/test_c042_loadsMultiFormationsAlignedWithSequence
QiuJiTests/DrillTryoutBoardStoreTests/test_drillWithoutSequences_fallsBackToShotIntent
QiuJiTests/DrillTryoutBoardStoreTests/test_allBundledBoards_decodeAndInRange
QiuJiTests/AngleResultSaveFailureTests/test_geometricAngle_saveFailure_setsErrorAndKeepsAnswer
QiuJiTests/AngleResultSaveFailureTests/test_aimingQuiz_saveFailure_setsErrorAndKeepsAnswer
QiuJiTests/AngleResultSaveFailureTests/test_aimPointTraining_saveFailure_setsErrorAndKeepsAnswer
QiuJiTests/AngleResultSaveFailureTests/test_aimPointSceneQuiz_saveFailure_setsErrorAndKeepsAnswer
QiuJiTests/AngleResultSaveFailureTests/test_retryFailedSaves_clearsErrorWhenRepositoryRecovers
QiuJiTests/SeparationAngleAtlasTests/testPathSlice_startsAtBallBall_endsAtFirstCueCushion
QiuJiTests/SeparationAngleAtlasTests/testPathSlice_lowPowerDraw_noCushion_fallsBackToStopPoint
QiuJiTests/BankKickDifficultyTests/test_solveBank_typicalBoard_sortedAndAssembled
QiuJiTests/BankKickDifficultyTests/test_solveKick_typicalBoard_sortedAndAssembled
QiuJiTests/BankKickDifficultyTests/test_ghostAlongFinalAim_straightOnGold
QiuJiTests/PositionPlaySolverTests/test_region_circle_signedDistance_goldenSamples
QiuJiTests/PositionPlaySolverTests/test_restRegion_pottable_landsInRegion_andSorted
QiuJiTests/PositionPlaySolverTests/test_restRegion_unreachable_returnsClosestDegraded
QiuJiTests/SnookerSolverTests/test_solveSnooker_invalidInputs_returnEmpty
QiuJiTests/SnookerSolverTests/test_defenseCoverage_multiBallSample
QiuJiTests/RackGeneratorTests/test_eightBallRack_rulesAndGeometry
QiuJiTests/RackGeneratorTests/test_sameSeed_sameRack
QiuJiTests/RackGeneratorTests/test_breakNineBall_producesLegalSettledBoard
QiuJiTests/HomographyTests/test_cornersMapExactly
QiuJiTests/HomographyTests/test_roundTripThroughInverse
QiuJiTests/HomographyTests/test_degenerateQuadReturnsNil
QiuJiTests/PhotoPermissionInfoPlistTests/test_cameraUsageDescription_present
QiuJiTests/PhotoPermissionInfoPlistTests/test_photoLibraryUsageDescription_present
QiuJiTests/TrajectoryPlaybackSettleTests/testPlaybackRunsToNaturalSettleNoTailTruncation
```

## 实质断言与安全审查

- DrillContentValidation `:45` 对索引加载失败ID输出详情；TutorialFiguresBundle `:28` 拒绝空引用并逐图实际UIImage解码，`:44`排PNG母版，`:52`核对引用集。均只读资源，不重建图。
- PositionPlaySolver `:93` 要求解非空、满足约束解存在、potted/余量/最终停点；`:123`不可达降级。BankKick `:118`要求典型解非空，最终实际进袋、库序与预测一致，且非贴库不误标。不能只保留排序循环而丢掉非空断言。
- Homography `:27`角点残差、`:40`往返、`:76`退化nil；是数值转换验证，不是真照片识别效果。
- AngleResultSaveFailure `:34`使用UUID独立UserDefaults额度，`:54`起失败仓储保留答案与错误；无真实网络。独立suite未见清理，最多留在专用模拟器测试容器，禁止复用真实账户容器；不是仓库写盘。
- 选中方法未见write/createDirectory/removeItem等资源写回；各类setup只读Bundle或配置测试对象。`BankKickDifficultyTests.test_x4_renderBankAndKickSolutionFrames`（`:418`起）明确固定输出PNG，**不选整个class**。其余Bake/Export/Seed/截图制作类不在清单。
- 模拟器专属“批量出片台”（AngleHome `:209`–`:216`）虽可见仍是制作入口，**本轮排除且不点击录制/导出**；不能把“全入口”误解为授权写资产。
- 几何专项按已读 geometry-spatial-reasoning技能处理：SceneKit X–Z水平/Y上/m；Canvas归一化[0,1]×[0,0.5]。本次只列现有测试语义，无独立数值计算/目视验证，不声称几何通过。后续正式复核须用快照转换函数及table-geometry契约核对，不能直接以portrait屏幕上下推断world轴方向。

## 后续必须补齐但不在首轮小批

1. 全部正常工具入口的“进入→操作→返回”UI；每工具至少正常+边界/无解，并验证标签来自实测，不以生成图片代替运行。
2. 12课教学分层与逐杆独立核对；确认无序列课fallback教学/记录可用。
3. 三球逆推、自由编排撤回、反射理想/真实模式、6认知页面正常保存到历史。
4. 实际包下架资源、搜索/计划/路由不可达性；C1/C2无比较源继续标证据缺口。
5. 真机相机权限和音频素材/静音听感；模拟器与字符串检查不能代替。

## 输入指纹

清单SHA-256：`76c98bdc728ce9ddd28f82cb0a1f9cb8f40dc588cbff424a7ba14109f4a79d69`（selector每行LF结尾）。

```text
227ca328f5159cd9b2d449c92c9083bd506bbffcf2896a6c3c351ccda3056a81  QiuJiTests/DrillContentValidationTests.swift
8283ee140bc7a0d06975c825a56bfe2bc021138e41933e022dd249fbf20ebb08  QiuJiTests/TutorialFiguresBundleTests.swift
f6470075cb71d7e726fbc6c24c63e319fecb0f0cdd7a177befcd4ced61d7be2f  QiuJiTests/DrillTryoutBoardStoreTests.swift
f7b13ba6f9285f04195b14b3015c42c9869808f7639c1d06c969cadd9168c04d  QiuJiTests/AngleResultSaveFailureTests.swift
d8001119670ea0aea14dadfb5cc0b9a4acdea8054be9f34341b53625ba4033ef  QiuJiTests/SeparationAngleAtlasTests.swift
891b2ccb29e908505d2ea1c544f21b84b1ec693e0ca679d8c986c16a8f096d51  QiuJiTests/BankKickDifficultyTests.swift
52a45315d22b391f4f3241c30eedf7e1223fd7044cf71ba57f1cc8615cae745e  QiuJiTests/PositionPlaySolverTests.swift
83e55a0bb34a75b6e50118227750efef7fe1a507c7d1fbc0daae37078f6a15d9  QiuJiTests/SnookerSolverTests.swift
c8889fd80f2146002a6e6b4cf2cdbb9248d5024257d33d7a211b77505d3c77fa  QiuJiTests/RackGeneratorTests.swift
166fc20d56a058fec34ebda719f9339dd6b99ee602cad9dc1f4dc27861c4ad50  QiuJiTests/HomographyTests.swift
f2d7ed4abaa5507d2d0b94738a47f822f366f8fbe898a16ff72e5eee8d781c10  QiuJiTests/PhotoPermissionInfoPlistTests.swift
5e3bf6dca29102169a0746526446e5262563ba2458ee39648c35eb0ed14fe8b9  QiuJiTests/TrajectoryPlaybackSettleTests.swift
```
