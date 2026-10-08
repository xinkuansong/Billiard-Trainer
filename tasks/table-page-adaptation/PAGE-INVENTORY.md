# 页面清单与推广顺序

2026-10-06首次盘点；2026-10-08补充间接消费者与复用审计。以下是入口／组件事实与建议排期，不是全部页面的视觉验收。基于 `MainTabView.destination`、`RootView` 测试入口，以及 `AngleSceneView`、`BTTableFigure`、`BTShotInstrumentColumn` 的调用方；后续每页采集实际入口、权限、模式与状态。不能只凭类名认定界面相同。当前渲染/相机差异见[完整标准与分析](../../docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md)。

源码前缀均相对仓库根目录，便于执行者用 `rg` 定位符号。

## 1. 交互球桌页

| ID／顺序 | 页面／路由 | 类型与源码锚点 | 保留差异／首轮重点 |
|---|---|---|---|
| D00 外部依赖 | 每日清台 | `PositionPlay/Views/FreePlayView.swift` 的 `entryMode: .dailyClearance` | 独立工作包，现行状态从CURRENT读取；旧W0/X不是当前实施状态 |
| P01 首个试点 | 分离角与走位／`.shotSimulation` | `AngleTraining/Views/ShotSimulationView.swift` | 最多两目标球、无开球；进袋／自由、摆球、轨迹、打点／杆速、击球和回放 |
| P02 第二消费者 | 自由击球／`.freePlay` | `PositionPlay/Views/FreePlayView.swift` 普通分支 | 开球、球库、对局；与每日同文件，实施前协调并保护两个分支 |
| P03 | 自由走位／`.positionPlayComposer`，另有详情试打入口 | `PositionPlay/Views/PositionPlayComposerView.swift` | 选球选袋、约束、下一解；独立入口和带内容试打入口都需覆盖 |
| P04 | 思路训练／`.positionPlaySolver` | `PositionPlay/Views/SiluTrainerView.swift` | 目标区域编辑、求解与自由操作、开球交付；不能被统一 HUD 隐去任务工具 |
| P05 | 打一走二想三／`.planThree` | `PositionPlay/Views/PlanThreeView.swift` | 角色球／袋选择、步骤推进、约束与撤销；步骤栏容量专项 |
| P06 | 防守／`.snookerTactics` | `SnookerTactics/Views/SnookerTacticsView.swift` | 本仓库防守页面，非另一个 snooker 项目；保留障碍和规划操作 |
| P07a／b | 翻袋解球／`.bankShot`；颗星解球／`.diamondSystem` | `AngleTraining/Views/BankShotView.swift`、`DiamondSystemView.swift` → `SolverStageChrome.swift` | 成对评估共享容器；求解／自由、库数、方案与障碍球，业务差异分别验 |
| P08a／b | 分离角图谱／`.separationAngleAtlas`；加塞吃库图谱／`.cushionEnglishAtlas` | `AngleTraining/Views/SeparationAngleAtlasView.swift`、`CushionEnglishAtlasView.swift` | 演示参数、读数、视图切换；保留教学标注可读性 |
| P09a／b | 2D／3D 角度训练 | `AngleTraining/Views/SceneAimingView.swift`，`.sceneAiming2D/3D` | 两个固定视角入口，成绩分记；题目、键盘、提交、答案／总结／限额 |
| P10a／b | 2D／3D 瞄准点训练 | `AngleTraining/Views/AimPointSceneTrainingView.swift`，`.aimPointScene2D/3D` | 两个入口均采集；命中选择、反馈与相机权限按实际代码核实 |

上表源码均位于 `QiuJi/Features/`。P03 以路由对应页面为范围，面向用户的标题以采集时实际显示为准。

## 2. 嵌入、读取与内部编辑场景

| 分组 | 源码候选 | 排期规则 |
|---|---|---|
| 教学阅读 | `ContactPointTableView`、`AimingPrincipleView`、`AimingMethodsView`、`AimingCorrectionView`、`SpinAndEnglishView`、`BallFeelView`、`TheoryT01/T02/T03View` | 按图文阅读宽度、标注和滚动关系适配，不套全屏双尺 |
| 交互教学（当前 AD01） | `AngleDynamicView` | 2026-10-08 用户指定下一批；拖球/选袋/多球遮挡，继承核心顶部/场景/设置，保留五项教学读数。见 [AD01](AD01-ANGLE-DYNAMIC.md) |
| 测验 | `GeometricAngleQuizView`、`AimPointTrainingView` | 先实际盘点交互与图解占比，再归入答题模板 |
| 拍照摆球／提取 | `BallExtraction/Views/BallExtractionView.swift`、`BatchDrillStudio/BatchBallExtractionView.swift` | 保留原图／球桌映射、校正和确认步骤；不自动扩成图像识别改造 |
| 批量编排内部工具 | `BatchDrillStudio/BatchAuthoringView.swift` | MainTabView 中批量工作室入口有模拟器条件；按真实可用入口验证，不列为普通用户全设备交付 |
| 内容详情／训练中的球桌 | `DrillDetailView`、`DrillRecordView` → `DrillSceneView`；`BTPracticeCover` → `BTTableFigure` | 10-08补齐上述源码链；教程静态资产/嵌套入口仍需逐页巡游，静态配图与原生交互分别登记，不声称已穷尽 |
| 独立预览与离线输出 | `AppearanceCombinationPreview`、`DrillThumbnailRenderer`、`TableFigureRenderer`、`BallFaceRenderer`、`SequenceVideoExporter` | 分别记录mobile/plain/studio配置、固定镜头及缓存；共享资产不等于每日完整渲染配置 |

## 3. 共用层影响清单

- `BTShotInstrumentColumn` 当前直接调用方：FreePlay、ShotSimulation、PlanThree、SiluTrainer、PositionPlayComposer、SnookerTactics、BatchAuthoring、SeparationAngleAtlas、CushionEnglishAtlas、SolverStageChrome、BreakFlowRunner、ShotControlBar。实施时用 `rg -l 'BTShotInstrumentColumn' QiuJi --glob '*.swift'` 重查。
- `SolverStageChrome` 是翻袋／颗星页面的共同入口，两个消费者都要保留。
- `AngleSceneView`、相机与投影跨多页使用；修改前按符号调用图扩展回归，不能只测 P01。
- 业务状态继续由已有 ViewModel 管理；本方案不新建通用业务控制器。

## 4. 优先级的调整规则

P01 用来跑通设计—实施—用户反馈闭环，P02 检验复用。后续按同类收益与依赖决定，每次只启动已具备任务卡的一页／同一共享容器下的成对页面。若 P02 与每日改动冲突，可先做 P03 的盘点与提案；改变实现顺序记录原因，不凭排期跳过依赖。
