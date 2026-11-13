# guard 正式默认推广覆盖盘点

2026-11-13；QA 源码覆盖复核，**代码已接入，运行验证待补，不是发布通过**。用户授权：将已验证 guard＋不可变文本缓存应用到相关 App 场景。本文件只记录覆盖与验证边界，不恢复旧研究 goal，不安排新的性能研究。生产修改已由主控完成；本文件由 native_reference 独占。

盘点起始 HEAD `259a2116bb084534f9546dd44b5fae72c1b0696a`；工作区本来已有研究与接线差异。本次已按第7节源码身份复核推广后的实现：27组正式R消费者均汇入共享默认路径，未发现源码接入遗漏；这不代表27组均已运行验证。

## 1. 推广边界与共享调用链

适用对象是**当前已经选择 profile R / reference sampling 的正式 liveReference 场景**，不是把所有 AngleTrainingScene 构造都改成R。`SpecializedProfile.reference` 的 rawValue 是 **A**，`reflection` 才是 **R**；名字不能混淆。

共享链：页面/离屏调用方 → `configureReferenceTableRendering()` 或 `setupScene(recipe:.liveReference)` → `setupScene` → `MobileContactOcclusion` 安装原 contact shader → `MobileReferenceLighting.apply` → `refreshClothLighting` → `directShadowProgram` → 原 `directShadowShader`＋已审 guard 变换＋声明 → `TaiNi.surface`。保留原采样、BRDF、累积顺序、AO、材质响应及源SHA回退。

**已修复的起始缺口（历史）**：此前 configureReference 会清空实验请求，只有每日读取 guard 启动参数；Release 的 refreshClothLighting 绕过 Program，请求/state、桌缓存身份、probe身份也被 DEBUG 排除。

**当前实现**：configureReference 在所有配置使用 `.configuredDefault`；非DEBUG固定为 `.guardCombo`，DEBUG默认同样启用guard，并保留 `-rendering.referenceCloth` 原R对照、plain及冲突回退。refreshClothLighting 在所有配置调用同一Program，传入scene请求并记录实际安装状态；不可变文本缓存、桌节点身份、probe身份均不再限于DEBUG。非live recipe仍显式关闭请求，非支持组合/容量/源漂移仍返回原程序。原directShadowShader函数体和guard数学黄金未改。

来源：[AngleTrainingScene.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/AngleTrainingScene.swift:80)、[MobileReferenceLighting.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/MobileReferenceLighting.swift:363)、[默认请求](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/DailyClothSupportExperiment.swift:33)、[profile定义](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/MobileReferenceLighting.swift:166)。

## 2. 当前正式 R 消费者（按直接入口穷举，间接页面合并）

| 消费者 | 源码锚点 | 实际调用与覆盖要求 |
|---|---|---|
| 每日清台 | [FreePlayView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PositionPlay/Views/FreePlayView.swift:573) | configureDailyClearanceRendering(async:true) → configureReference；保留每日相机/规则/异步probe |
| 分离角与走位、试打、蛇彩、多球、自定义球形、编排台 | [FreePlayView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PositionPlay/Views/FreePlayView.swift:576) | 非每日统一 configureReference + configureShotAwareCamera → VM.setupScene；editorModel 也走此 body |
| 批量动作工作台 | [BatchAuthoringView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/BatchDrillStudio/BatchAuthoringView.swift:369) | 独立 composer 配置 reference 后 setup，不经 FreePlay 首入 |
| 角度动态教学 | [AngleDynamicViewModel.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/ViewModels/AngleDynamicViewModel.swift:152) | configureReference → setupScene |
| 角度练习/场景瞄准 | [SceneAimingView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/SceneAimingView.swift:154) | 页面先 configureReference，再 AimingQuizViewModel.setupScene；VM裸入口本身不选R |
| 瞄准点练习 | [AimPointSceneTrainingView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/AimPointSceneTrainingView.swift:106) | configureReference → setupScene |
| 准度练习 | [AccuracyPracticeViewModel.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AccuracyPractice/AccuracyPracticeViewModel.swift:270) | configureReference → setupScene |
| 分离角练习 | [SeparationPracticeViewModel.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/SeparationPractice/SeparationPracticeViewModel.swift:285) | 同上 |
| 两球练习 | [TwoBallPracticeViewModel.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/TwoBallPractice/TwoBallPracticeViewModel.swift:320) | 同上 |
| 三球练习 | [ThreeBallPracticeViewModel.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/ThreeBallPractice/ThreeBallPracticeViewModel.swift:284) | 同上 |
| K球练习 | [KBallPracticeViewModel.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/KBallPractice/KBallPracticeViewModel.swift:252) | 同上 |
| 解球练习 | [KickPracticeViewModel.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/KickPractice/KickPracticeViewModel.swift:260) | 同上 |
| 翻袋练习 | [BankPracticeViewModel.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/BankPractice/BankPracticeViewModel.swift:270) | 同上 |
| 防守练习 | [DefensePracticeViewModel.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/DefensePractice/DefensePracticeViewModel.swift:280) | 同上 |
| 翻袋求解 | [BankShotViewModel.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/ViewModels/BankShotViewModel.swift:289) | configureReference → setupScene |
| 颗星体系/解球工具 | [DiamondSystemViewModel.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/ViewModels/DiamondSystemViewModel.swift:266) | 同上 |
| 思路训练 | [SiluTrainerViewModel.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PositionPlay/ViewModels/SiluTrainerViewModel.swift:258) | 同上 |
| 打一走二想三 | [PlanThreeViewModel.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PositionPlay/ViewModels/PlanThreeViewModel.swift:481) | 同上 |
| 分离角图谱 | [SeparationAngleAtlasViewModel.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/ViewModels/SeparationAngleAtlasViewModel.swift:85) | 同上 |
| 加塞吃库图谱 | [CushionEnglishAtlasViewModel.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/ViewModels/CushionEnglishAtlasViewModel.swift:94) | 同上 |
| 袋口容差 | [PocketToleranceViewModel.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PocketTolerance/PocketToleranceViewModel.swift:40) | 同上 |
| 球形提取预览 | [BallExtractionViewModel.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/BallExtraction/ViewModels/BallExtractionViewModel.swift:298) | setupScene(recipe:.liveReference) |
| 动作详情/训练记录嵌入预览 | [DrillSceneView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/DrillSceneView.swift:117) | liveReference；消费者 DrillDetailView:199 / DrillRecordView:366 |
| 设置外观组合预览 | [AppearanceCombinationPreview.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Profile/Views/AppearanceCombinationPreview.swift:16) | liveReference；独立scene/renderer，不靠每日flag |
| 引导外观选择预览 | [OnboardingStyleLab.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Profile/Views/OnboardingStyleLab.swift:214) | liveReference + tournament |
| 瞄准特写台呢底图 | [TableFigureRenderer.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/TableFigureRenderer.swift:69) | closeupFelt → backdrop(recipe:.liveReference)；BTAimCloseupOverlay:209消费，非第二套动态shader |
| 明确匹配App的视频/静帧导出 | [SequenceVideoExporter.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Media/SequenceVideoExporter.swift:114) | resolvedRenderRecipe=.liveReference：显式recipe、useAppAppearance，及tutorialStills():215；setup:1063 |

以上27组已在推广后重新核对 `configureReferenceTableRendering`、`configureDailyClearanceRendering` 和 `.liveReference` 全部生产调用点，与起始 `AngleTrainingScene()` / setupScene / recipe / MobileReferenceLighting 盘点对应，未发现新增遗漏。FreePlay 的间接消费者另核到 PositionPlayComposerView、CustomFormationPracticeView、SnakePracticeView、MultiBallPracticeView、ShotSimulationView；这些复用页面均继承共享默认，无须各加shader开关。所有正式2D/3D模式继承本场景材质，不只在3D摄像机分支启用。此表表示源码覆盖，实际生效仍取决于R/reference采样/16槽等门禁及材质成功安装。

## 3. 明确保留的非相关/legacy 路径

| 路径 | 原合同及处理 |
|---|---|
| [DrillThumbnailRenderer.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/DrillThumbnailRenderer.swift:24) | 动作缩略图显式 .plainLegacy；不切R、不批量重生成旧图。 |
| [TableFigureRenderer.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/TableFigureRenderer.swift:89) | backdrop默认 .plainLegacy；BTTableFigure:41未传recipe的教学卡沿用旧配方。只有closeupFelt显式liveReference属于推广。 |
| [BallFeelView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/BallFeelView.swift:261) | 球感页面显式 .plainLegacy，保持。 |
| [BallFaceRenderer.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/BallFaceRenderer.swift:19) | 球面小图 mobileRendering:false；随后复制球并转unlit，无台呢，保持。 |
| [SequenceVideoExporter.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Media/SequenceVideoExporter.swift:114) | 显式 .legacyMobile/.teachingPlain/.plainLegacy/.studioLegacy，useTutorialAppearance、默认离屏、studioLook 分支保持；不要让历史导出被全局强制R。 |
| [AngleTrainingScene.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/AngleTrainingScene.swift:91) | 非live recipe显式profile=A；legacyMobile虽用移动基底/参考灯，不等于R，仍应不启guard。 |
| [AngleTrainingScene.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/AngleTrainingScene.swift:43) | 裸AngleTrainingScene/setupScene默认profile来自 specializedProfile（通常A），不能只因mobileRendering=true就改为R。PositionPlay/AimingQuiz正常页由上层配置；其独立测试/裸调用保留原语义。 |
| [BTBallPaletteBar.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Components/BTBallPaletteBar.swift:88) | 球库独立SCNScene/球节点，无台呢生成器；BakedTrainingRoom、模型加载器仅加载资产，不是另外的R默认安装入口。 |

`BTGeometricReferenceTool` 的两个 `AngleTrainingScene()` 为 Preview 参数、没有setup；不因构造出现而判漏接。非R、非reference采样、非16槽、显式legacy、merge/factor/prototype/balance或源漂移仍应保留各自原请求程序，不能“回退”成另一种R材质。

## 4. 容易遗漏的共享路径

| 边界 | 源码事实与推广检查 |
|---|---|
| 非DEBUG安装 · [MobileReferenceLighting.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/MobileReferenceLighting.swift:363) | 已通过与DEBUG相同的Program与文本缓存，显式传入scene请求；完整surface黄金 `ca5acc70043f0da620e2c6501188063c78027c8e26b62233d128ced01f81aabd` 保留。原生成器仍供准确回退/研究基线；非DEBUG构建和完整Release验证状态见第6节。 |
| 请求与缓存 · [DailyClothSupportExperiment.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/DailyClothSupportExperiment.swift:1) | 类型及单槽文本缓存已进入所有配置；非DEBUG固定guard，DEBUG保留显式R、plain及冲突回退。缓存只存成功且不可变source/suffix；每次仍执行profile/采样/容量/源与输出SHA门禁，不缓存scene/state或失败。 |
| 桌节点复用 · [AngleTrainingScene.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/AngleTrainingScene.swift:333) | reusableTableKey在所有配置包含已请求算法身份，原R无该后缀，guard/plain各自隔离；profile/exposure/merge/factor等原键保留。setup重装contact后追加一次光照，袋口marker临时摘下保护原角色/主题的路径保留。 |
| 自定义球扩容 · [AngleTrainingScene.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/AngleTrainingScene.swift:606) | trackBallInstances失败→新MobileContactOcclusion→同一refreshClothLighting；32/48槽走容量门禁，返回原程序并清guard声明、更新state/probe身份。16槽表示uniform容量，不是可见球数量：两球场景仍可合法16槽。最终运行回归待补。 |
| 静态反射probe · [RoomReflectionProbe.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/RoomReflectionProbe.swift:291) | Inputs在所有配置包含实际installed state的probeCacheIdentity，R/guard不互借。prepareBake复制已安装材质、清球uniform，不另生成shader；异步generation/currentInputs校验与缓存上限保留。 |
| 临时俯视 · [AngleTrainingScene.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/AngleTrainingScene.swift:1452) | live overlay与静态截图都用makeTemporaryTopDownRenderScene。topDownGeometry复制几何、共享source.materials，继承guard及同帧uniform，不重跑默认/legacy生成器。同步追踪geometry替换，保持一个源动作时钟。 |
| 两种副视图 · [AngleSceneView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/AngleSceneView.swift:445) | mergedOverlay实时同步；旧temporary snapshot分支:723也使用同复制函数。切换2D/3D或恢复只变投影/视图，不能重设guard请求、球态或独立动画。 |
| 离屏图片缓存 · [TableFigureRenderer.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/TableFigureRenderer.swift:89) | key已有recipe/cloth/room/尺寸；当前缓存仅进程内，固定新默认无需改历史磁盘资产。若同进程工具切换显式R/guard，则必须隔离所选身份，不能用先生成的liveReference图片验证另一配方。 |
| 幂等与重配置 · [MobileReferenceLighting.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/MobileReferenceLighting.swift:306) | apply的S267AreaPanel早退仍不能用来做运行中shader切换；共享配置在setup前设置默认请求，扩容走专门refresh。实际状态由材质安装结果记录，不能只据旗标认定生效。 |
| 无资源/legacy逃生 · [MobileTableRendering.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/MobileTableRendering.swift:10) | DEBUG -v62.legacyRendering、HDR缺失、enhancedRendering均可能关闭移动路径；需明确fallback，不能报告guard生效而没有TaiNi或没有reference程序。 |

## 5. TP局部适用性与验证状态

本次是共享着色默认值/缓存推广，不是页面改版；保留各页既有完整清单，仅复核影响项与依赖。来源为统一规范及变更与来源现行条款（包括2026-10-28同场景正式2D/3D、2026-11-06进入流程约定）。

| 条款 | 局部判定 | 保持的合同与本次状态 |
|---|---|---|
| TP16 | 继承；离线/固定图按业务调整 | 同scene的正式2D/3D及临时俯视使用同已安装材质；不变题目/额度/球局，不把临时视图持久化。静态导出只保留原相机，无须新增切换UI。源码链已核，正式推广后的运行未验。 |
| TP17 | 继承；序列导出按业务调整 | 不改CameraRig、手势、动画或序列镜头时序；shader启用不得重置相机/杆向。源码责任分离已核，最终运行未验。 |
| TP27 | 继承 | 默认优化为内部材质策略，不新增用户偏好、不写旧档、不跨页复制配置；显式legacy与DEBUG原R仍隔离。各页外观/布局偏好保持。共享默认已接入，同值重进/主题变换运行验证待补。 |
| TP29 | 继承 | 共享生成器与不可变文本；scene独立，副视图按现有安全复制；cache按实际配方隔离；物理/几何/球姿态/采样不变。扩容不适用guard时准确回退。静态调用核查完成，最终Release安装/缓存需验证。 |
| TP30 | 继承；内嵌/离屏按业务调整 | 每日异步probe、generation取消、主场景/副视图释放保留；不新增帧循环或驻留scene。其它离屏消费不强制每日进入门控。最终运行未验。 |
| TP35 | 继承 | 本清单是源码覆盖证据，不能把旧DEBUG研究通过写作新正式默认已验；按最终源码记录单测、Release、原生画面及未验范围。此只读盘点不启动模拟器或强制人工Phase流程。 |

条款真源：[TP16/17](/Users/song/projects/13.billiard_trainer/docs/design/table-pages/球桌页面统一规范.md:226)、[TP27/29/30](/Users/song/projects/13.billiard_trainer/docs/design/table-pages/球桌页面统一规范.md:365)、[TP35](/Users/song/projects/13.billiard_trainer/docs/design/table-pages/球桌页面统一规范.md:433)。

## 6. 定向合同与当前验证边界

- `DailyClothSupportExperimentTests` 已按新默认更新：`testProductionDefaultInstallsGoldenGuardAcrossReferenceEntrypoints`、`testProductionDefaultTemporaryTopDownSharesInstalledGuardMaterials`、`testLegacyRecipesKeepSupportExplicitlyDisabled`、`testReferenceReconfigurationRestoresTheProductionDefault` 和 `testDefaultGuardExpansionFallsBackWithoutLeakingDeclarationsOrProbeIdentity` 覆盖新增默认合同；显式原R完整surface由 `testExplicitReferenceCompleteSurfaceRemainsFrozen` 保留。完整guard黄金、unsupported矩阵、64并发文本缓存、桌缓存隔离、32/48扩容、probe复制合同仍在。本文件只核对源码，不预报这些测试通过。
- `RenderQualityV62Tests/testNamedRecipesAndExtractionPreserveGeometryAndAuthoredBoard`、`testAppearancePreviewUsesLiveRecipeAndDismantlesItsRenderer`、`testRealRenderedFramesSurviveLosslessSpoolInLiveAndTeachingRecipes`：对应 recipe、预览和离屏漏项。
- `AngleDynamicAssistTests/testUpdatesInvalidationAndTemporaryViewClone`、`X1_CameraAndAngleArcTests/testTemporaryTeachingLabelsUseOverlayProjectionWithoutMutatingMainScene`：对应复制/副视图不污染源scene。
- 既有 guard 完整场景/页面研究证据证明候选本身；本次正式默认覆盖、Release和非每日调用链不能由旧每日显式flag结果自动替代。本文件没有执行测试、构建、截图、安装或性能采集。

**当前构建边界（主控提供的执行状态）**：完整Release构建被本地开发API配置拦住，尚不能声称Release构建通过。主控正在执行Debug配置并清空 `SWIFT_ACTIVE_COMPILATION_CONDITIONS`，用于验证非DEBUG代码分支；该路径仍使用Debug配置的其它设置，**不等同完整Release构建**。本文件未取得该构建或新默认运行测试的最终结果，实际结果由主控后续回填；源码接入完成与运行验收待补分别记录。

## 7. 推广后静态复核身份

- `QiuJi/Core/Scene/DailyClothSupportExperiment.swift`：`b2e0a0ea31a5eb0e23080378cfd70c0ad9e02e166d169e0e197bdcb2a5767d5e`。
- `QiuJi/Core/Scene/AngleTrainingScene.swift`：`9d52f8437dd0ee4e70b3b93993a302b92f8e6b57228c3eadd3f9e523f3dd21da`。
- `QiuJi/Core/Scene/MobileReferenceLighting.swift`：`045f5ac597c99b3c28cb14e86978bfa135454b98c85b08278333a1aac59203f2`。
- `QiuJi/Core/Scene/RoomReflectionProbe.swift`：`718a894deb0a93ca938d1495c75d54a5cf4a29c10a8d284ec6f5af495277cdf5`。

以上为本次重新计算的推广后工作区源码SHA，不是构建产物SHA或运行通过证明。后续源码变化需重新关联验证结果。


## 主控运行回填（2026-11-13）

非DEBUG App独立编译通过；正常配置20项测试全部通过、0跳过（19合同＋1 UI）。实际材质黄金覆盖每日、普通reference、liveRecipe三类入口；UI在iPad13/iOS26.3.1竖向窗口验证每日/普通自由击球×2D/3D，四份状态均guard生效、同页renderer身份稳定、静止休眠，四张原图已核看。临时俯视、probe复制、缓存和16→32/48扩容由合同测试覆盖。以上补齐本清单相关自动化状态，但不将其他25组页面的源码接线核查冒充逐页UI通过。完整Release API配置、最低iOS17运行及全部页面人工验收仍未通过/未验，详[推广记录](ROLLOUT.md)。
