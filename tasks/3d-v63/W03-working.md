# W03 辅助线投影：代码核对

状态：W02已完成，W03贴面几何与共享轨迹接入进行中。本批完整DoD保持问题集合v63，不能将入口审计标为W03实现完成。

## 已核实共享链路

- AngleTrainingScene.addCueTrajectory：实线碰前/虚线碰后，按cueSplitIndex区分。addObjectTrajectory：本球色虚线。两者消费addLine/addDashedPolyline。
- TrajectoryRenderer及SequenceVideoExporter消费上述共享方法；不可只改实时页而漏导出。
- AngleTrainingScene.addSeparationAngleLine和setIdealObjectLine使用addDashedLine，当前仍球心高度。
- 训练页另有setupVisualizationNodes/updateVisualization/updateLineNode持久节点，不能仅改addLine便宣称训练线接入。当前训练测试还验证材质multiply颜色与标签，换几何需保留这一显示契约。
- BreakFlowRunner的前瞄准线和杆后参考线，PositionPlayViewModel的自由方向线，以及Silu/PlanThree等直接消费者须逐项分类；三维球面标记、杆轴与未来飞行路径保持空间高度。
- 调用点清单：output/3d-v63/W03/line-consumers.json，2026-09-12当前源码检索，行号后续按方法名重定位。

## 实施边界

坐标为XZ台面、Y向上、米。投影生成显示副本，不改预测数组、碰撞点或评分向量。贴面带状几何须正常深度测试，不用悬浮圆柱或永远穿透的叠加层替代。空间路径保留空间弧长，平面线按投影弧长分段。

袋口裁剪不能直接把旧捕获圆当成已核实的可见台呢边界：生产物理口圈与视觉支撑仍须区分。优先核对实际台呢边界和既有几何数据，形成可验证遮罩/裁剪依据；内矩形过早截断或未校准圆圈都不能作为最终验收。

## 后续

先建立显式平面/空间绘制契约与几何验证，再接共享轨迹及持久训练节点；同机位原样/投影对照，标准/SE/iPad覆盖低角度、密集和近袋，保留W02低角度原图作为悬浮线基线。不扩改球杆或假想球高度。


## 首轮实现与证据

TableAssistSurface（暂与TrajectoryRenderer同文件）从当前TaiNi多索引通道中读取水平台呢面、耳切三角化凹面；以带状四边形裁剪台呢三角形，保留实际空洞，不读取物理捕获圆决定显示边界。采用Double做平面裁剪，输出朝上的世界三角形。每Scene缓存一次，setupTable重建时失效，失败显式Logger报告并暂回退原空间线，不能将回退视作投影验收。

footprint-r1：4单测/0失败，TEST SUCCEEDED，exec43033已退出。模型实测sourceY=0.7947377m、physicalY=0.8m，509三角形/投影面积3.8102065m²（含库下方，不能当有效击球区面积）；六袋心4mm探测覆盖面积均0。before/projected角袋原图已打开：投影线贴面并受库边遮挡，不再跨过库边悬浮。此测量不是物理支撑校准；高度差由现有MobileClothAlignment路径处理。

AngleTrainingScene新增AssistLinePlacement.spatial/table，默认保留空间；共享cue/object轨迹、分离线、idealObjectLine显式table。空间虚线改为实际空间弧长，台面使用水平弧长。当前表面视觉偏移1mm为样片候选，后续低角度/不同设备验证；不参与物理。

projected-r1已启动，exec session58773，当前包含10个helper/语义单测及分离角完整UI，结果待收取。该轮构建后又新增空间/台面独立契约测试，以及自由方向实时预览/开球前向线的table接入；后续需要覆盖这些增量。训练持久节点、其他直连线、密集/多设备、性能及最终视觉仍未完成。


projected-r1完成：10单测+1UI，0失败，TEST SUCCEEDED，exec58773退出0。已实看低角度近袋最新原图：黑色进球虚线由悬浮圆柱变为台呢带状线，袋口处停止；对照W02低角度原图。当前不宣称所有辅助线/设备/密集状态已视觉验收。原图副本与哈希在projected-standard-r1。

projected-r2已启动（exec session84077）：TableAssistSurfaceV63Tests（含新增空间/投影契约）、BreakFlowRunnerV6Tests、自由击球15/9球完整UI。该轮覆盖自由瞄准实时预览与开球前向线增量；结果待收取。开球杆后参考短线保留空间高度，与杆轴例外一致。

## 训练持久线接入前检查

旧断言：`let cylinder = try XCTUnwrap(line.geometry as? SCNCylinder)`，随后用圆柱局部±height/2转换到世界坐标，断言最大X等于innerLength/2。贴面三角网格替代圆柱后类型解包会失败，端点契约本身仍成立；替代检查读取实际网格世界顶点，保留最大X断言，并补贴面高度与假想球球心高度验证。不得删除白色、球径、ghost位置断言。此记录在修改该断言之前写入。

projected-r2已核对日志末尾：TEST SUCCEEDED，自由击球UI 1项0失败；不据此宣称W03全量完成。

## 训练持久线首轮结果

AngleTrainingScene的进球/瞄准持久线改为实际台呢裁剪网格；为网格补沿原始线方向的UV，保留原虚线纹理、multiply球号色与长度节距。完全裁掉时用空几何保留材质，重新进入台面后仍可恢复样式。90°释义虚线和角度弧也使用投影几何；球面接触点、ghost和杆轴未压平。该改动会增加几何重建，性能与不变输入缓存仍需测量。

training-r1：9单测0失败、TEST SUCCEEDED、exec94947退出0。原白线到库边断言改读网格世界顶点并通过；原球径/白色/ghost位置保留，新增ghost高度与贴面高度检查。相机/方向及全部球号颜色回归通过。6张附件导出到output/3d-v63/W03/training-r1-attachments；已打开6号3D、3号2D原图，虚线和颜色仍可见，假想球保持空间球体。此处是SCNRenderer固定夹具，不当实际页面、多设备或当前渲染专项外观验收。

下一步：补裁空后恢复、释义线/角度弧投影及UV连续的契约测试；审计其余直接线消费者/平面圈与网格，补标准/SE/iPad低角度密集样片；测量重复更新成本，再完成W03全部DoD。无存活测试进程。

## 直接消费者与更新成本

2026-09-12：逐处读代码后，新增35个平面绘线调用的显式table接入，涉及SceneStroke圈/矩形、Silu/PlanThree瞄准及约束、BatchAuthoring十字/均分线、Snooker防守连线、瞄准点训练四类线、两个图谱，以及BankShot/Diamond自由瞄准与参考路线。BankShot/Diamond的库面接触法线保留空间高度，触点金点不压平。并未因此完成这些页面的W10–W15接入验收。

consumers-r1：19测试0失败/TEST SUCCEEDED，补充裁空后恢复材质与几何、UV按原始距离保持连续、训练辅助全部贴面但空间标记保留、约束圈/矩形高度。固定模拟器Debug更新成本100个热身后样本p50=4.7206ms/p95=4.9514ms。检查显示每条短线都重复扫描计算509个三角形边界。仅缓存静态包围盒并保留原精确裁剪后，bounds-r1同一设备/用例p50=2.1674ms/p95=2.2920ms，38测试0失败/TEST SUCCEEDED。两次原始xcresult及JSON附件已保留，不能将此CPU更新耗时当真机帧率验收。

consumers-ui-r1正在运行，exec80722：S2的Silu/PlanThree/Snooker入口布局及ShotSimulation完整3D试点流程；结果待收取。源码哈希记录于output/3d-v63/W03/consumers-source-hashes.json。

未完成的共享显示边界：tableGrid仍采用圆柱；PlanThree扇形fill仍禁用深度测试，需要与其新贴面轮廓一并校对；角度文字仍在原高度，应按可读锚点方案审查。尚未完成SE/iPad的密集、低角度及各类线覆盖，不得以本轮19/38测试称W03完成。

consumers-ui-r1工具结果4项通过，但打开原图后确认PlanThree/Snooker停在Pro弹窗，两个入口不能算页面回归通过。原始证据保留。根因为launchClean默认清除Pro、旧openCard仅判断卡片存在，未验证目标台面；现使用既有-forcePremium夹具并增加table.scene可见可点和非Pro弹窗断言。截图写盘从旧docs路径迁到output/3d-v63/W03/page-layout，失败显式XCTFail；不再污染设计基线。Silu与3D试点原图已审，补测两个被弹窗拦截入口。

verify-gate首轮未通过：新增TrajectoryRendererTests写盘未登记。补登记固定footprint输出、覆盖/保留范围，第二轮FAIL=0（142个写盘文件）；未放宽门禁。

consumers-ui-r2完成：2项0失败，TEST SUCCEEDED，exec87690退出0；两个402pt原图已打开，确认真实打三角色选择台面和防守球形/选球圈，非Pro弹窗。FL-059记录并同步测试规则、UI规格；只关闭测试覆盖缺口。S2固定输出现在在output，原r1 xcresult保留。当前无存活测试/门禁进程。下一步仍为网格、扇形fill/标签的贴面深度策略和三设备密集近袋样片。

## 网格与填充接入

本轮将ribbon的核心裁剪抽为凸多边形与真实台呢相交，正/反绕序归一化；扇形沿原triangleStrip拆为同样的三角区域后再裁剪，不改求解落区。AngleTrainingScene.makeTableFill保持深度读取、禁用深度写入，填充显示高于台呢0.5mm，线高于台呢1mm，作为候选层间偏移等待低视角样片验证；均不影响物理高度。

4x8网格改用同一贴面线；不再用父节点Y作为缓存有效依据，模型重载显式失效，保留偏好先于模型加载的重建路径。新增测试验证加载前开网格→模型加载后重建、10条网格、开关复用、填充深度/高度、两种绕序孔洞面积，以及实际屏宽的密集线/近袋填充原图。

fills-r1运行中，exec69451；标准模拟器，TableAssistSurfaceV63Tests+PlanThreeSectorSolverTests+TrainingAssistSceneTests。结果待收取；SE/iPad尚未运行。本轮尚未完成W03。

fills-r1标准22测通过；fills-se-r1紧凑屏16测通过；fills-ipad-r1共16测通过、TEST SUCCEEDED。三设备密集/近袋六张原图均已打开：填充与圈线在袋口裁剪并被库边遮挡，网格贴面；但远端细线弱、角度数字随观察方向倒置仍待处理，不宣称视觉验收。它们是实际模拟器屏宽下的SCNView固定夹具，不是整页UI验收。

核对AngleSceneView发现正式页面antialiasingMode=multisampling4X，密集夹具此前使用SCNView默认设置。仅给该夹具补相同4X采样，保留所有r1原图；fills-aa-r1标准补拍运行中（exec session75662，最近轮询确认仍在编译），再决定细线是否需要显示策略变化。文字倒置不依赖抗锯齿，仍须解决。

## 数字朝向与抗锯齿复核

fills-aa-r1已完成，1测试/TEST SUCCEEDED，exec75662退出0。两张4X抗锯齿标准屏图已打开，与r1相比网格断续显著减轻，因此不直接加粗全局线宽。原图仍保留；多设备需要使用同一4X配置补拍。

AngleTrainingScene为角度值标签保留原平面yaw，3D时只对其字形父节点使用SCNBillboardConstraint(all)，子字形取消lay-flat；回2D撤约束并恢复yaw/pitch。保留wedge锚点、字符串、理论计算与其他线标签。API依据Apple官方SCNBillboardConstraint/freeAxes文档（https://developer.apple.com/documentation/scenekit/scnbillboardconstraint）；不新增相机事件循环。

labels-r1：17测0失败、TEST SUCCEEDED、exec22832退出0。新测试在实际SCNRenderer渲染后的presentation世界矩阵中验证四个观察方向字形右/上与相机右/上对齐（dot>0.99），并验证2D往返、原字符串和XZ锚点。已打开方向0/3及密集全桌三图，90°不再倒置。随后也打开方向1/2原图，四个方向数字均正向可读；原附件均在labels-r1-attachments。

仍有可见缺口：密集夹具中一条训练进球线与另一条同路线重合，两种颜色交错，可能由共面深度竞争及不同虚线节距共同造成。先分离同节距重合和不同节距重合样例，再决定深度写入/绘制层级；不能靠抬高物理Y或全局关深度测试解决。SE/iPad需复核数字朝向与4X样片，实际页面及W03最终gate仍待。

labels-se-r1两用例通过，exec32086退出0，TEST SUCCEEDED；覆盖数字四方向/模式恢复和4X密集样片，附件已导出，原图待审。

labels-ipad-r1已启动，exec session73687，数字四方向/恢复与4X密集样片两个用例；下轮先轮询该handle，不重复启动。SE两张新密集图尚未打开：70DDF29B-366F-4F24-84F6-E1D2B5896047.png（近袋）、96F6D9B7-A23D-4F93-BC4C-22A887FE0535.png（全桌），均在labels-se-r1-attachments。W03保留进行中，不因字形修正宣称整体完成。


## 共面深度策略接入（2026-09-12）
labels-ipad-r1已终态成功，两项0失败；SE/iPad原低角度/全桌图已复看。overlap-r1诊断一项通过，同向/反向实线及混合节距虚线六图留存；反向实线与混合虚线四图已审，明确深度写入会使重合片面颜色竞争。

生产改为TableAssistLayer固定语义层级，贴台材料只读深度。训练持久线保留材料时同步此策略，网格/参考线低于路线、当前瞄准线高于路线。depth-policy-r1共18测0失败，TEST SUCCEEDED，exec77265退出0；生产混合虚线及全桌/低角度密集原图已审。库边仍遮挡，斜向碎片竞争消除；不同节距仍在间隙露出下层颜色，不能误认作需要抹去的错误。

新增接口及规则已写DR-143。depth-policy-se-r1正在执行，exec97388，随后需iPad同样补测。最终实际页与gate尚待，W03保持进行中。


测试选择器校正：depth-policy-se-r1和depth-policy-ipad-r1均终态成功，但实际各只执行1项重合线用例。命令误写testDenseTableAssistsRenderEvidence（不存在），不能计入密集样片。已核对源码正确名testDenseProjectedAssistsRenderEvidence；depth-dense-se-r2一项0失败/TEST SUCCEEDED，375pt全桌和近袋两图已打开。depth-dense-ipad-r2正在执行，exec94064。后续每次按实际执行计数/用例ID核对，不能仅看TEST SUCCEEDED。


depth-dense-ipad-r2一项0失败/TEST SUCCEEDED，exec94064退出0；744pt全桌/近袋两图已打开。三设备六张最终密集图均已审。verify-gate-depth-policy FAIL=0（142写盘文件）、verify-doc-size-depth-policy通过，git diff --check通过。最终实际分离角与走位完整UI正执行，depth-ui-r1，exec57192；不要重启，先轮询。W03收尾审计尚未完成，所有后续物理/页面/高度批次保留。


depth-ui-r1终态成功，exec57192退出0，实际S2_ShotPagesLayoutUITests/testShotSimulation3DPilot一项0失败，覆盖观察菜单/低机位/前后台及模式往返/打点/击球/回放/重打。入口进袋、低近袋、回放重打三张实际页原图已打开：贴台线保留实体遮挡，球杆与球体空间关系仍在；页面HUD/FPS不是本批新增，模拟器显示60FPS不构成真机性能证明。当前无本任务存活构建/测试进程。

下一步：W03逐条收尾审计与验收文档（原样/投影对拍、六类线/空间例外、预测数据不变、三设备样片、消费者范围均需对应既存证据），通过后转W04运行时记录与接管时间契约。不要重新跑已经通过的同范围测试，除非新增改动或发现缺口。生产/测试源码本轮快照见depth-policy-source-hashes.json；本轮CPU更新p50=2.23ms、p95=2.42ms，仅Debug模拟器样本。
