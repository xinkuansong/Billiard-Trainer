# v75 页面与绘制覆盖

2026-11-27；W1盘点、W2/W3接入、W4收口。源码扫描见同目录scene-constructors-before.txt、drawing-calls-before.txt、style-calls-before.txt。状态按每批真实验收更新。

|消费者/入口|用途与规格|批次/状态|
|---|---|---|
|`CuePhys/Features/PocketTolerance/PocketToleranceViewModel.swift:7`|容错边界或纯球桌/球体预览，无本轮主路线；保持尺寸|保持，源码复核无相关主线|
|`CuePhys/Core/Media/SequenceVideoExporter.swift:1061`|范围外图解/导出/外观或按钮预览，保持旧默认|保持，W1/W4对照|
|`CuePhys/Features/BankPractice/BankPracticeViewModel.swift:10`|交互平面球桌，主4.5/辅4，细线/标记保留|W2通过；共享几何/代表原生见W2/RESULTS.md|
|`CuePhys/Features/TwoBallPractice/TwoBallPracticeViewModel.swift:10`|交互平面球桌，主4.5/辅4，细线/标记保留|W2通过；共享几何/代表原生见W2/RESULTS.md|
|`CuePhys/Features/ThreeBallPractice/ThreeBallPracticeViewModel.swift:10`|交互平面球桌，主4.5/辅4，细线/标记保留|W2通过；共享几何/代表原生见W2/RESULTS.md|
|`CuePhys/Features/KBallPractice/KBallPracticeViewModel.swift:10`|交互平面球桌，主4.5/辅4，细线/标记保留|W2通过；共享几何/代表原生见W2/RESULTS.md|
|`CuePhys/Features/KickPractice/KickPracticeViewModel.swift:10`|交互平面球桌，主4.5/辅4，细线/标记保留|W2通过；共享几何/代表原生见W2/RESULTS.md|
|`CuePhys/Core/Components/BTGeometricReferenceTool.swift:231`|范围外图解/导出/外观或按钮预览，保持旧默认|保持，W1/W4对照|
|`CuePhys/Core/Components/BTGeometricReferenceTool.swift:236`|范围外图解/导出/外观或按钮预览，保持旧默认|保持，W1/W4对照|
|`CuePhys/Features/SpatialQuiz/SpatialQuizViewModel.swift:10`|交互空间球桌，主4.5/辅4|W3通过；实际网格/三页原生/六视图见W3/RESULTS.md|
|`CuePhys/Core/Scene/DrillThumbnailRenderer.swift:21`|范围外图解/导出/外观或按钮预览，保持旧默认|保持，W1/W4对照|
|`CuePhys/Core/Scene/TableFigureRenderer.swift:107`|范围外图解/导出/外观或按钮预览，保持旧默认|保持，W1/W4对照|
|`CuePhys/Core/Scene/BallFaceRenderer.swift:17`|范围外图解/导出/外观或按钮预览，保持旧默认|保持，W1/W4对照|
|`CuePhys/Features/AngleTraining/Views/AimPointSceneTrainingView.swift:51`|交互平面球桌，主4.5/辅4，细线/标记保留|W2通过；共享几何/代表原生见W2/RESULTS.md|
|`CuePhys/Core/Scene/DrillSceneView.swift:13`|范围外图解/导出/外观或按钮预览，保持旧默认|保持，W1/W4对照|
|`CuePhys/Features/AngleTraining/Views/BallFeelView.swift:259`|容错边界或纯球桌/球体预览，无本轮主路线；保持尺寸|保持，源码复核无相关主线|
|`CuePhys/Features/DefensePractice/DefensePracticeViewModel.swift:19`|交互平面球桌，主4.5/辅4，细线/标记保留|W2通过；共享几何/代表原生见W2/RESULTS.md|
|`CuePhys/Features/SeparationPractice/SeparationPracticeViewModel.swift:18`|交互平面球桌，主4.5/辅4，细线/标记保留|W2通过；共享几何/代表原生见W2/RESULTS.md|
|`CuePhys/Features/AngleTraining/ViewModels/BankShotViewModel.swift:213`|交互平面球桌，主4.5/辅4，细线/标记保留|W2通过；共享几何/代表原生见W2/RESULTS.md|
|`CuePhys/Features/SpatialPractice/SpatialPracticeViewModel.swift:9`|交互空间球桌，主4.5/辅4|W3通过；实际网格/三页原生/六视图见W3/RESULTS.md|
|`CuePhys/Features/AngleTraining/ViewModels/DiamondSystemViewModel.swift:188`|交互平面球桌，主4.5/辅4，细线/标记保留|W2通过；共享几何/代表原生见W2/RESULTS.md|
|`CuePhys/Features/AngleTraining/ViewModels/AimingQuizViewModel.swift:51`|交互平面球桌，主4.5/辅4，细线/标记保留|W2通过；共享几何/代表原生见W2/RESULTS.md|
|`CuePhys/Features/AngleTraining/ViewModels/SeparationAngleAtlasViewModel.swift:13`|交互平面球桌，主4.5/辅4，细线/标记保留|W2通过；共享几何/代表原生见W2/RESULTS.md|
|`CuePhys/Features/Profile/Views/OnboardingStyleLab.swift:211`|范围外图解/导出/外观或按钮预览，保持旧默认|保持，W1/W4对照|
|`CuePhys/Features/AngleTraining/ViewModels/AngleDynamicViewModel.swift:11`|交互平面球桌，主4.5/辅4，细线/标记保留|W2通过；共享几何/代表原生见W2/RESULTS.md|
|`CuePhys/Features/Profile/Views/AppearanceCombinationPreview.swift:79`|范围外图解/导出/外观或按钮预览，保持旧默认|保持，W1/W4对照|
|`CuePhys/Features/AccuracyPractice/AccuracyPracticeViewModel.swift:48`|交互平面球桌，主4.5/辅4，细线/标记保留|W2通过；共享几何/代表原生见W2/RESULTS.md|
|`CuePhys/Features/AngleTraining/ViewModels/CushionEnglishAtlasViewModel.swift:20`|交互平面球桌，主4.5/辅4，细线/标记保留|W2通过；共享几何/代表原生见W2/RESULTS.md|
|`CuePhys/Features/PositionPlay/ViewModels/PositionPlayViewModel.swift:29`|显式传用途：Composer试点；其他正式交互入口W2；默认兼容旧行为|W1通过（真实Composer）；其他使用方W2通过|
|`CuePhys/Features/BallExtraction/ViewModels/BallExtractionViewModel.swift:262`|容错边界或纯球桌/球体预览，无本轮主路线；保持尺寸|保持，源码复核无相关主线|
|`CuePhys/Features/PositionPlay/ViewModels/SiluTrainerViewModel.swift:111`|交互平面球桌，主4.5/辅4，细线/标记保留|W2通过；共享几何/代表原生见W2/RESULTS.md|
|`CuePhys/Features/PositionPlay/ViewModels/PlanThreeViewModel.swift:349`|交互平面球桌，主4.5/辅4，细线/标记保留|W2通过；共享几何/代表原生见W2/RESULTS.md|

## 同宿主路由展开

- PositionPlayComposerView：分离角与走位、DrillDetailView动作试打、BallExtractionView取球确认后的编辑。W1接入同一构造点，后两入口W2回归。
- FreePlayView三个构造器：每日清台/ShotSimulationView、多球2D/3D（MultiBallPracticeView）、蛇彩（SnakePracticeView）。W2显式传用途。
- CustomFormationSession→CustomFormationPracticeView：练习球桌；构建线框是编辑形状边界，保留6mm，不是轨迹。W2显式传用途。
- BatchAuthoringView：交互编辑VM启用新规格；导出独立SequenceVideoExporter场景保持默认。
- SpatialQuizViewModel：扎杆与跳球两种答题配置均须验；自由页独立SpatialPracticeViewModel。

## 绘制角色及排除

- 共同主线路径：AngleTrainingScene预瞄、静态主可视线、addCueTrajectory/addObjectTrajectory及主addDashedPolyline；主半宽按实例。
- addLine/addDashedLine是通用原语，仍保留原0.003默认；交互主调用必须显式传主半宽。
- 两球/三球/分离角/解球/K球等中杆参考显式取辅助半宽；题目目标路线/实际/历史路线取主半宽。翻袋已禁用参考的守卫保留。
- 翻袋/颗星自由试打的选中解暗线、理想目标球方向、几何测量：辅助4mm。
- SceneStroke约束圈/十字、CustomFormation构建边、PlanThree目标多边形、Silu/Batch约束十字：标记/区域，不改。
- AngleDynamicAssistOverlay走廊边、PocketTolerance管道边/中心、准度/翻袋/防守球心线：细基准，不改。
- BallFeelView内Canvas示意图、AnglePrediction/GeometricAngleQuiz/AimPointTrainingView的BTTableFigure、Theory和AimingMethods等：图解保持，不随页面可点击与否自动纳入。
- BTAimCloseupHUD屏幕pt线、图例短线、静态海报/缩略图/图片与视频链：保持。

## 局部规范检查

TP22按业务调整，仅宽度；TP17/TP23继承相机与特写；其余合同无变更。W1原生试点与范围外对照通过，W2/W3/W4按v75逐项完成。

## W4剩余调用逐项结论

`style-calls-final.txt`剩余8处引用全部已分类：SequenceVideoExporter两处仍旧半径缩放，BTTableFigure两处仍旧投影，Widths两处兼容主/辅来源，AngleTrainingScene两处假想球环半径/高度；无漏网交互主线。`constructors-final.txt`中无参数场景仍为图解/内嵌/外观/纯球桌/容错边界，PositionPlayViewModel无参仅两处按钮Preview；全部正式交互宿主显式interactiveTable。

W2路由补充：Composer覆盖分离角与走位/动作试打/取球后编辑；FreePlay的mode/原始球形/序列三构造器覆盖每日清台、模拟、2D/3D多球、蛇彩；CustomFormationSession覆盖自定义练习；BatchAuthoringView只对编辑VM接入，SequenceVideoExporter独立实例默认旧规格。走位/思路/三球规划、K球/三球及其余共享入口以构造器→主/辅绘制调用源码映射和实际几何测试覆盖；未声称这些入口逐一原生截图。

范围外：DrillSceneController/StaticPreview/Thumbnail、TableFigureRenderer、SequenceVideoExporter、Onboarding/Appearance预览保留默认；取球、球感纯场景与PocketTolerance细边界维持原规格。圆环/SceneStroke/约束边界/瞄准特写不迁移，属明确角色排除，不是未实现。

三尺寸原生：SE3有W1平面2D/3D及W4-small三空间侧视；iPhone13有W2全部代表绘制族和W3三空间流程；iPad有W4-pad平面浅深色2D/3D与三空间侧视、双答题轨迹/重打/换题。不是全页面×全尺寸矩阵；真机未测。
