# 普通 FreePlay 开球交付验收口径

2026-09-08；仅只读冻结004源码与既有 repeated-shot AX，新增本文。没有测试、构建、设备操作，也没有取得新 rack/settled AX。以下分源码语义与已有观测，不宣称新开球链已通过。

## 开球停稳已经补母球，完成不应再补一次

源路径前缀 `build/quality-diagnosis/snapshot-004/QiuJi/`。

`Core/Rack/BreakFlowRunner.swift:329–370` 的 finishBreak：

1. 移除全部开球球节点动作；result.pocketed各球隐藏。
2. 将result.board.onTable存活球重新钉到终点，cuePose=.unchanged。
3. **若cueScratched，立刻在rack.cue补回母球**，同时把该点写入待交付board.onTable。此时仍未点完成。普通目标球落袋不补回；终结球落袋只产生outcome事实/提示，不筛掉整个散局。
4. 默认手动模式保存同一board/outcome，phase=.settled，提示“点完成进入击打”。自动模式才立即deliver。

所以“停稳→完成”比较应包括已经补回的母球；不能拿动画落袋瞬间的无母球状态作接收前基线，也不能要求母球落袋后继续缺席。是否本次实际刮杆只能由真实提示/录像或outcome实测确认，源码分支存在不等于此次命中。即使8号废局提示优先显示、覆盖刮杆提示，源码仍先完成补母球，不能仅依据无刮杆文字排除该事实。

`confirmSettled:378–383` 只取缓存outcome、清缓存并deliver；`deliver:411–414` 依次调用onSettled(board)、onOutcomeSettled(outcome)，无重算物理、重抽seed或改坐标。

## 普通宿主接收：相同集合/位置，允许姿态与预测层变化

`Features/PositionPlay/ViewModels/PositionPlayViewModel.swift:1974–1997`：默认manualDeliver=true；进场保存旧盘、停预测/清轨迹、创建runner、rackUp。onSettled先teardownBreakFlow再loadBoard(board)。`FreePlayView.swift:127` 明确普通入口manualDeliver:true。

`loadBoard:210–220` 非空且非playing才应用；清旧sequence/lastShot/replay上下文，调用applyBoard(snapshot,cuePose:.reseat)。`applyBoard:1498–1510` 先hideAllBalls，再按snapshot.onTable逐IDplace，refreshOnTableKeys；重新选目标/必要时选袋并recompute。**没有重新摆架、换球号、随机位置、clamp坐标或补其它落袋球**。`place:376–382` 只normalizedToScene；`refreshOnTableKeys:333–335` 从allBallNodes的isHidden派生集合。

`AngleSceneCalculator.swift:19–30` 归一化到Scene映射是固定线性XZ换算（Y钉surfaceY+R），往返有Float误差，不能要求屏幕像素逐位相同。`AngleTrainingScene.swift:234–243` showBall写相同XZ、Y钉台面、opacity=1、isHidden=false；`applyPosePolicy:270–281` 目标球重设单位姿态，母球.reseat随机新朝向。**母球红点/mesh包围框大小可变，不应把完全相同宽高当位置不变硬合同。** 目标球在finishBreak的showBall也走resetPose，普通交付原则上保持已落定的目标球姿态。

`FreePlayView.swift:137–143,273–280` 离开开球触发startGame，仅选ChineseEightBallRules/ZhuifenRules及更新HUD；不改board。预测线、选球/选袋标记、规则HUD、底部palette重新出现是正常状态变化，不应要求整个AX节点树或截图一致。

投影：`FreePlayView.swift:261–266` 声明stage高度固定，并提供freeplay.stage；316–320同一AngleSceneView、相同cameraMode、autoFitsRotatedTable=true。`AngleSceneView.swift:288–294` 按实际SCNView.bounds拟合相机。接收代码无主动改变cameraMode；但仍应实测完成前后stage/tableVisual frame稳定，再比较球中心。若viewport变化，先解释布局/投影差异，不能把全桌一起平移误报球坐标改变。源码“高度恒定”注释不是新run截图证据。

## 真实AX：palette和隐藏mesh会制造假球

已读原件：`archive/quality-diagnosis/runs/formal-004-repeated-shot-001/screenshots/repeated-shot-810E2DD0-8651-4047-9C22-4BE922F326AC-initial-default-board-AX.txt` 和 cycle-1-shot-ended-AX.txt。

初始AX第37行freeplay.stage=(0,162,402,584)；tableVisual=(49.6,180.4,302.7,547.2)。SceneKit导出的同级外层语义球根有：

- cueBall=(217.5,543.8,16.5,18.2)，其下是BaiQiu/mesh。
- _1外层=(170.8,389.1,11.1,11.1)，内层同名_1和mesh同框。
- _2外层=(240,310,11.1,11.1)。
- 未在桌的_11外层却=(49.6,180.4,302.7,650.4)，**其内层同名_11仍有(195.5,448.5,11.1,11.1)球大小框**。其它隐藏球同样如此。shot-ended中隐藏根大框甚至变为(49.6,8.9,302.7,718.7)。故对全部descendants筛小frame，会把隐藏mesh误记在桌。
- 第213行以后paletteBall_cueBall、paletteBall__1…都有44×44框，label只是cueBall/_1等。按label或contains匹配会混入球库；按identifier精确`cueBall`、`_1`…可排除paletteBall_前缀。

源码映射依据：`AngleTrainingScene.swift:141–153` 把各提取球根直接addChild到scene.rootNode，并保存allBallNodes；`hideBall/hideAllBalls:285–292` 仅设根isHidden，不删除内层几何。`AngleSceneView.makeUIView:66–72` 使用原生SCNView.scene，当前文件没有自定义AX球列表/可见性过滤器。因此上述树是实际桥接结果，不是业务提供的isHidden布尔或世界坐标读口。

## 最小可用判据与必须等新观察的部分

- 先在新rack、停稳待完成、完成后三阶段各保留完整PNG/AX，确认freeplay.stage与tableVisual、外层SceneKit根结构；不得用旧三球盘frame替代新球架位置。
- 按同一SceneKit容器的**直接球根**与精确ID建表，每ID只取最外层语义根；不能在候选中挑最小框，也不能把同名内层节点算第二球。已有工具firstMatch经验仅在树序已核实前提下可复用。
- 外层球根须为正常球大小且落在真实桌面范围；隐藏根桌面大小/异常大框排除。旧17Pro约11–19pt与小于30pt判据是旧观察尺度，**新rack/settled仍须核图**，不可当全设备恒定球径。不要要求hittable：开球busy/settled交互挂起时可见球不一定能点。
- 停稳阶段以break.confirm真实可用、画面球位置停稳为前提；记录各真实球根ID、中心及table/stage。完成后confirm消失、普通击球/规则状态成立，同样识别出的球ID集合应完全一致，非cue各中心保持；cue需考虑reseed朝向造成包围框轻微偏差，结合PNG球心检查，不能删掉母球检验。
- 若某球根投影与隐藏大框无法区分、被遮罩或AX截断，应原地保留缺口；不能以palette颜色/球总数提示冒充精确桌球集合。任何屏幕容差须由新前后稳定采样与视觉核查确定，本文不凭源码发明毫米/像素阈值。

这里只能得到屏幕投影与ID连续性，不能从AX还原全部BoardSnapshot数值，也不证明真实台球物理准确性。已确认的生产语义是：刮杆在停稳前补回；完成接收保留该散局集合/水平坐标，但重设母球姿态并恢复预测/普通UI。新开球实测证据仍待主控取得。
