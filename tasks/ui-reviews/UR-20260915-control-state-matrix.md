# 现有控件显隐与相机条件矩阵

本表记录当前源码行为，不是新设计，也不表示这些状态已全部截图。与图册合读：先区分隐藏、禁用、只读、布局占位，再讨论是否调整。

| 页面/组件 | 触发状态 | 现有规则 | 恢复与后续 | 源码 | 盘点含义 |
|---|---|---|---|---|---|
| 内嵌球桌回放 | playing | 先显示控制，2秒后隐藏 | 点台面重新显示并重启计时；idle/paused/pausingAfterShot显示 | [DrillSceneView.swift:786](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/DrillSceneView.swift:786) | 已有自动收起，不应重新发明；需连续画面验证 |
| 对象观察菜单 | 母球/目标球不存在或隐藏 | 对应菜单项保留但禁用 | 对象存在后恢复可用 | [BTShotPageChrome.swift:546](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Components/BTShotPageChrome.swift:546) | 禁用和隐藏不是同一规则 |
| 对象观察菜单 | 没有目标袋 | 目标袋菜单项不创建 | 有pocketIndex才出现；越界则禁用 | [BTShotPageChrome.swift:551](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Components/BTShotPageChrome.swift:551) | 并非所有页面都应该提供目标袋视角 |
| 对象观察菜单 | 不能返回当前瞄准 | 回到瞄准保留但禁用 | 宿主canReturnToAim恢复后可用 | [BTShotPageChrome.swift:560](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Components/BTShotPageChrome.swift:560) | 各宿主入口与对象存在条件要分别确认 |
| 试打序列 | 序列模式 | 打点盘isReadOnly；2D仪表与3D上方读数位置不同 | 暂停状态允许打开读数面板；不能编辑参数 | [PositionPlayComposerView.swift:282](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PositionPlay/Views/PositionPlayComposerView.swift:282) | 查看详细参数仍是功能，不能直接删掉 |
| 试打模式切换 | isPlaying或isSequencePlaying | 模式选择禁用 | 停止后恢复；切换关闭打点盘 | [PositionPlayComposerView.swift:591](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PositionPlay/Views/PositionPlayComposerView.swift:591) | 当前是禁用，不是自动消失 |
| 手动击球 | 自由瞄准模式 | 出现瞄准微调轮 | 进袋模式不显示这只手动方向轮 | [PositionPlayComposerView.swift:324](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PositionPlay/Views/PositionPlayComposerView.swift:324) | 需要区分相机旋转与出杆方向微调 |
| 翻袋/反射 | 切换2D/3D | 关闭打点盘；3D隐藏球库，显示观察菜单 | 返回2D恢复球库；3D禁止台面拖球/选袋 | [SolverStageChrome.swift:234](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/SolverStageChrome.swift:234) | 当前源码及09-15小屏原图；旧iPad图不代表新行为 |
| 角度Scene测验 | observing且有题且未结束 | 可答题；3D观察菜单可用 | inputting/结果/结束时观察菜单禁用 | [SceneAimingView.swift:159](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/SceneAimingView.swift:159) | 键盘不能遮住答题所需对象，需专门题面组图 |
| 瞄准点Scene测验 | aiming且额度未尽 | 观察与提交操作可用 | showingResult/striking改变底部反馈；观察菜单禁用 | [AimPointSceneTrainingView.swift:727](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/AimPointSceneTrainingView.swift:727) | 判分与击球验证是两个状态 |
| 几何角度预测 | 输入中 | 近期表现透明、AX隐藏、禁止命中但保留占位 | 退出输入恢复；键盘只在输入且无结果/额度未满时可用 | [GeometricAngleQuizView.swift:47](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/GeometricAngleQuizView.swift:47) | 已有防止题面跳动的规则 |
| 照片校准 | 四角校准无效 | 下一步禁用 | 校准有效后进入标球；可重新选图、切近端长短库 | [BallExtractionView.swift:198](/Users/song/projects/13.billiard_trainer/QiuJi/Features/BallExtraction/Views/BallExtractionView.swift:198) | 缺实图：不能判定角点/放大镜是否挡手 |
| 瞄准修正教学 | 可用左右塞范围接近零 | 左右塞控件禁用 | 高低杆改变有效范围；计算读数/忙/错误分支切换 | [AimingCorrectionView.swift:49](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/AimingCorrectionView.swift:49) | 教学联动参数，不是击球模式控件 |

## 相机焦点核查口径

| 用户当前任务 | 必须看清的对象 | 截图时必须同时记录 |
|---|---|---|
| 看全局球形 | 桌边、袋、相关球的空间关系 | 是否完整入镜；UI实际遮挡范围 |
| 进袋瞄准 | 母球、目标球、目标袋及方向关系 | 目标袋是否出画；母球是否被手控面板覆盖 |
| 走位规划 | 本杆目标、落区/落点/过点、后续角色球 | 约束是否被球/桌沿/UI挡住；3D是否仍可辨认 |
| 开球 | 母球、整架球、出杆方向 | 摆架/击出/停稳三种构图，不共用一个结论 |
| 回放与验证 | 正在运动的球、结果发生处 | UI收起后如何暂停；停稳后何时恢复 |
| 教学比较 | 参与比较的路线及图例 | 单选/多选、路线出画与颜色辨识 |

这些是后续截图的核查字段，不预设一种固定球桌占比，也不先决定删哪个视角。
