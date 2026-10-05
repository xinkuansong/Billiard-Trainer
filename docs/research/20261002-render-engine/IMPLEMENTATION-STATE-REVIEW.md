# W1/W2 相机接入独立审查

日期：2026-10-02。范围：现有代码的只读审查与最小实施清单。没有修改生产代码、构建或运行测试；以下是代码可判定事实与候选接入要求，不能作为实施PASS。用户已授权开始可回退工作profile与实际截图审查，不代表所有待裁定镜头政策已获批。

## 1. 可判定根因与写入面

| 入口（当前源码行） | 当前行为 | 候选必须隔离的影响 |
|---|---|---|
| CameraRig.swift:336 updateCuePose | 存杆数据后，只要shot-aware且FP数据改变，即调用enterPlayerView(FP,0.18s) | 训练数据更新可以重建站位与转场；不能在manual时改eyeAnchor/viewBase/headYaw |
| CameraRig.swift:379 enterPlayerView / :1221 smoothToPose | 先清playerView/reference/orbit等，再启动转场；enterPlayerView随后重新赋模式 | 暂时清模式是旧控制器副作用；候选mode/owner/motion须独立，切镜请求需明确来源 |
| CameraRig.swift:896 beginManualOrbit | 通知VM取消pending，再清playerView/reference，并切observation | 横滑FP会隐式变成普通轨道；仅增加owner而保留该清理仍不成立 |
| CameraRig.swift:773/787/834 | 水平改yaw，垂直改elevation或pitchOffset，pinch改距离/FOV，某支缩远调用全桌 | 新TP垂直/捏合应进入同一s映射；FP水平只转头。保留旧分支会增加隐藏自由度/切模式 |
| CameraRig.swift:875 beginObservationPinch | 根据pinch附近候选球改pivot/yaw/distance | 不能把旧自动取球中心直接接入固定轨道；任务锚点是显式候选能力，不能偷偷改变s的语义 |
| CameraRig.swift:928/962/978 | observe球/袋、每日全桌、普通全桌直接改轨道与目标；全桌内部也调用beginManualOrbit | 同名入口含显式按钮与后台resize；必须传请求来源，不能把resize计成manual操作 |
| CameraRig.swift:479 viewportSize | 仅全桌状态resize会observeWholeTable(yaw:targetYaw)，随后恢复turn速度 | 重拟合仍会触发manual通知、清模式等；普通/FP状态也没有候选profile反解与代次 |
| CameraRig.swift:534–618 PerspectiveState | 保存模式、轨道、transform、FOV、smooth origin/target/progress、overview转速等，恢复后续跑 | 保存的是可继续执行的旧动画，不是只有眼位；没有owner/request/profile/context代次 |
| CameraRig.swift:1300/1392/1404/1421/1442/1509 | update写position/euler/FOV；2D写正交；snap/translate直接落姿态 | 新候选应由同一rig出口写相机；不能再建第二控制器和旧update并行 |
| AngleTrainingScene.swift:612/641 | 两个摆杆路径调用updateCuePose | 杆的真实geometry更新要保留；镜头是否响应必须由rig候选owner判定 |
| AngleTrainingScene.swift:1110–1211 | invalidation在rail host直接return；saved视角在2D进出/显式restore时恢复 | 需分“保持实际眼位”与“旧杆entry有效”，不能只删saved来解决过期问题 |
| AngleTrainingScene.swift:1222/1305 | SCNTransaction直接写相机；completion由cameraTransitionID拒旧，但仍会apply2D或snapToAimPose | 已有transitionID是局部门禁，不覆盖手动/shot/profile；候选不应走旧aim落点 |
| AngleTrainingScene.swift:1382 | lockCueBallScreenAnchor可translatePivot | 候选固定眼位/轨道不能被HUD锚点另写，须明确禁用或经过统一求解 |
| PositionPlayViewModel.swift:58–80 | 回调只改busy Bool；显式requestPlayerView先discardSaved，再立即enter | busy需要对应当前request，而非任意旧结束回调；请求失败不能误消合法saved |
| PositionPlayViewModel.swift:824/:1552 | 选球置pendingCameraTarget，recompute后requestPlayerView(TP) | 新host必须拆开选球业务与切镜；manual取消一次pending不阻止后续选球再次产生请求 |
| PositionPlayViewModel.swift:1754/:1802/:1838 | 非每日contact、每日capture、settlement触发FP→TP | 事件需shot+request+owner门禁，保留当前有效时点语义；capture/settlement不重复抢镜 |
| PositionPlayViewModel.swift:431/:449/:1994 | 每日撤销、重打恢复历史PerspectiveState；缺省回enterAiming | 明确用户恢复动作可接纳旧眼位，但以新request/context解释，不能复活旧自动转场 |
| PositionPlayViewModel.swift:2043–2091 | 上一杆回放100ms Task、运杆完成、球动画完成只检查isPlaying | 取消后新播放令isPlaying再真，旧回调可能恢复旧局面并触发recompute；需播放代次 |
| FreePlayView.swift:241/254/1554/1563 | 新rack、部分非每日break边界、全桌按钮/初次3D均有镜头请求 | 显式按钮、新上下文初始化、旧业务onChange不能混作同一种接管权限 |

补充：smoothToPose并非所有调用都用候选FP/TP；enterAiming、enterObservation、setAimYaw、snapToAimPose等是旧教学/其他host接口。不要全局改其业务语义。

## 2. 四文件之外的最小必要接入

**AngleSceneView.swift是实际输入与帧推进边界。** :362赋viewport；:589推进rig，再可能锁母球屏幕锚点。:812–813同次pan对水平/垂直都调用，未轴锁时两个delta均为0，两个旧方法仍接管manual；结束分支也落入后续处理。候选必须只在有效非零意图时接管，未轴锁/结束/取消不能改变mode或owner。:859 pinch先调用beginObservationPinch，:861再handlePinch；候选应旁路旧重定pivot，FP未定义pinch不能落入旧FOV/orbit分支。

**CueStroke.swift:244是自动FP→TP实际门禁。** 当前只检查3D/rail/FP/原母球与aim匹配，再enterPlayerView(TP)。现在manual常因playerView被清而碰巧拒绝；保留FP模式后会重新放行，所以新owner检查不可遗漏。不能只在三个VM调用点各加一个if而保留该helper可直接抢镜。

**ShotPlayerCameraButtons的消费面需核查**：选中状态应来自稳定mode，busy来自当前motion/request，不能以playerView=nil表达manual。这是既有按钮接入，不新增整套相机UI。

## 3. 最小隔离与实施顺序

1. 在现有CameraRig中增加独立opt-in候选配置（本批仅每日清台），别复用usesRailCameraControls：自由练球也开启该flag。保留旧host/导出路径。纯profile函数产θ/s到eye/gaze/FOV与逆解；新增state置于rig内，别设并行写camera的第二对象。
2. state至少含mode3D、owner、motion、displaySpace、θ/s/headYaw、FP eyeAnchor/viewBase与entry有效性、scene/shot generation、requestRevision、viewport/profile revision。request来源区分explicitView、manualInput、trainingContext、shotBoundary、restore与resize。训练数据可更新，只有允许的请求进入pose出口。
3. 先在候选分支实现接管：从当前实际可见姿态起步、拒绝零意图；FP冻结eye/viewBase只更新headYaw，TP反解当前r→s再推进θ/s；停止当前自动运动且新request使旧completion失效。既有SCNTransaction在model层已到target，capturePerspectiveState里的cameraNode.transform不等于屏幕presentation；若候选仍可中断它，必须读其实际presentation并同步rig状态，不能默认smooth cache涵盖外部transaction。
4. 将updateCuePose改为候选context入口：manual保眼位/基准/头角，automatic仅按本批明确策略响应；新母球/新杆使旧entry失效但不后台搬站。移除候选selectTarget→pendingCameraTarget→TP副作用；保存杆数据、预测结果、真实球/袋选择与反馈，不能以“取消recompute”隔离镜头。
5. 对capture/settlement helper集中检查：当前shot generation、仍3D、automatic拥有、当前FP entry对该杆有效、事件未消费。延迟请求创建时与消费时都检查；消费不能借用新杆上下文。取消/重开先增加generation，清请求再清动作；明确重打以新请求采纳历史眼位，不恢复旧请求有效性。首版保现有事件时点，事件合并细则不擅自扩成新产品策略。
6. 2D只挂起候选3D状态，保mode/owner与实际pose；在2D不由相机update推进隐藏3D运动。恢复须检查context/profile/viewport；不变且仍合法可恢复可继续运动，不匹配则旧自动target失效、保可用实际眼位并从新profile反解，而非无条件resume。明确restore动作是新request；不要直接继承历史owner token或自动回调。2D→3D候选不要走旧snapToAimPose；无需新增2D语言。
7. resize/HUD变更递增profile revision。manual保实际eye/FOV后合法反解新s，FP保eye/headYaw并报告裁切；automatic可重新规划。相机和同帧projection/picking使用真实view/projection/viewport，别只把名义profile参数填进CameraFrame。viewport未有效前不要猜aspect；没有解时保合法帧/明确候选受限，不伪装观察PASS。
8. VM播放回调增加独立playback generation，并用于100ms Task、runCueStroke completion、球动作completion、finishPlayback；不能只复用isPlaying。每日cancelDailyAttempt已有strokeGeneration，但普通回放路径缺门禁。生命周期退出/背景调用stop的下游须确认同代次取消，不凭onDisappear文字推定正确。
9. FreePlayView在setup后仅每日opt-in；初次3D/新rack入口成为明确初始化请求，恢复已有视角优先；全桌按钮是显式请求。保持训练/力度/打点、放置、solver和预测不受相机影响。使用可检查工作profile，不声称固定H/FOV/台心或FP出杆归正/读袋方式已由用户选定。

## 4. 接入前后可判定检查

- W1：同profile θ接缝连续、s单调/逆解、边界反向不积累、实际room安全眼位与连接路径；FP只有headYaw不能间接转杆或移动eye。固定profile不保证可读性，属于W2实际截图职责。
- W2：FP横滑后仍FP；选球/袋/aim/打点变化保manual眼位和viewBase；有效capture后转一次、settlement不再抢镜；manual发生于任何等待后旧事件拒绝；取消旧回放再开新杆旧completion不得落盘。
- W2：3D→2D→resize/选球→3D；转场中手动接管；重打/撤销先新generation再恢复；首layout为zero→有效；全桌resize不产生假manual。实际帧/拾取/HUD证据按正式C/S/V标准，不把纯state断言当视觉PASS。
- W1/W2不需要为了代码审查先上真机；也不把它们的通过写成帧率/能耗通过。新profile能否覆盖常规观察范围、用户手感与画质须保留实际截图及操控出口，有限姿态样本不代替连续安全证明。

结论：可以立即实施上述最小候选隔离。最危险的遗漏是只保留playerView却不改CueStroke门禁、只阻止pending却保updateCuePose重入、以及恢复旧PerspectiveState动画与只检查isPlaying的旧回调。当前所有实施与行为检查均未验证。

## 5. 候选已落盘后的记忆与布局复审

以下针对本次读取的TwoViewCamera.swift / CameraRig.swift候选，覆盖前文旧源码行号结论；不声称主控随后串行修订与测试已通过。

**当前仍重置的情况。** TwoViewCamera只有一份active state，没有按FP/TP保存的有效记忆；:133 enterThirdPerson总设置owner=automatic、progress/targetProgress=1，CameraRig.swift:464还把当前FP gaze yaw作为新TP yaw，丢失此前TP θ/s。:146 enterFirstPerson总覆盖base并令headYaw=0，CameraRig.swift:466每次按当前杆/viewport重新生成FP，普通切换与显式归正因此无法区别。同模式重复按钮也走相同重置。全桌按钮设远端可属于明确默认请求，自动capture/settlement另有时点语义，不能把它们全部改成恢复记忆。

**当前布局路径。** CameraRig.swift:87仅automatic TP重建profile，而且调用enterThirdPerson把s重设为1并可用最新训练数据改anchor；manual TP、所有FP都被guard排除。manual眼位暂时不动是正确的，但profile.viewport/readableInsets及布局有效性仍旧，后续操作与范围声明没有重校验。:686恢复2D/撤销snapshot也直接采用旧profile，不校验当前viewport/HUD；新layout更新在恢复之前发生时不会自动重发。restore冻结当前pose并清旧connector，比继续旧动画安全，但不能证明新布局下同样可读。

**最小可实施修正。** 在TwoViewCamera内加两份可选ModeMemory，存实际pose及TP profile/θ/s、FP base/headYaw和有效context key；切出前保存实际状态，不保存待兑现自动请求。Snapshot包含这两份记忆，保证2D/撤销恢复的一致性。CameraRig入口区分switchMode（同上下文有效记忆）、resetFirstPerson（按最新杆重建且头角归零）、overview（明确全桌默认）、shotBoundary（当前已授权事件）；避免所有入口调用相同enter重置函数。切到记忆姿态由当前pose建立connector，不能直接restore瞬移；requestRevision增加且旧回调失效，旧owner token不复活。新上下文缺有效记忆才用默认。

memory有效性按scene/shot generation、母球实体/站位语义与profile可用性判断；普通aim/打点/选球更新不能机械清除同上下文manual FP base，旧entry可另标失效。恢复历史眼位不等于它仍是新杆瞄准机位。切镜是否授予automatic应在入口明确，而非让memory字段或updateCuePose决定。

把buildProfile与enterThirdPerson拆开。manual布局更新保存实际eye/orientation/FOV和owner，更新viewport/insets/revision，在相同任务anchor与固定lens下重校验几何域：合法时从实际水平半径与θ反解新s并对齐current/target，不保旧归一化s造成跳镜；FP保base/eye/headYaw。当前farAxes只由room/anchor决定，若仅viewport/HUD改变且不换anchor，几何r域可能不变，仍须更新布局与可读性判定。不能直接调用candidate得到新FOV后无声套用manual；不能以旧profile留存宣称C10完成。域无解/越界保安全实际帧并标受限或显式退避，常规观察能力仍需V02验，不由该标记PASS。

恢复snapshot时先检查当前布局再激活输入；不在restore内部自动恢复旧target或后台搬FP。automatic TP允许明确重规划；manual TP保持实际pose的重校验不应触发onManualCameraControl或相机切换。inactive FP/TP记忆也延迟重校验，不能首次切回才突然套用过期FOV/anchor。

对应规格：主方案§2表“切换3D模式：有效记忆或默认；同上下文可恢复”、§4的context/resize规则；C08验manual FP训练更新不夺权，C10直接验2D与resize保实际pose/FOV并反解，C09验切回记忆的connector，C04/S02验无假输入和旧请求。FP↔TP记忆本身没有独立C编号，宜在既有V05生命周期序列明确加入“TP近端手动→FP转头→TP→FP、重复模式按钮、2D中resize再回”，并由V02/V07核对真实主体/HUD与设备布局；不能把C10的2D通过代称FP↔TP记忆通过。以上是代码可判定缺口及修正建议，未运行测试/构建/模拟器。

### 5.1 context key与失效来源的最小建议

分开三种身份：`ViewingContextKey = sceneSessionID + viewingGeneration + cueEntityID + cuePlacementRevision`；`TaskRevision = taskKind + selectedSubjectIDs + selectedPocketID + relevantContextRevision`；`LayoutRevision = viewport + readableInsets + geometry/profileRevision`。均为建议结构，名字可适配现有实现。sceneSession由实际scene/rig建立或替换递增；viewingGeneration在新rack、新有效shot观看上下文、取消/重开、明确恢复另一历史board时建立，不用每次recompute生成。cueEntity用boardKey/稳定实体ID，cuePlacementRevision只由明确重新摆母球/替换母球站位产生，不对动画中每帧母球位置哈希。shot业务generation用于旧事件拒绝，可与viewingGeneration关联，但两者生命周期需明确。

| 变更来源 | 活跃手动pose | 两模式记忆/entry | 布局与观察验收 |
|---|---|---|---|
| 同上下文FP↔TP、2D往返、普通重复模式按钮 | 从实际pose连续转到有效记忆；同模式不归零 | 保留两份记忆；重复请求不等于resetFP | 当前layout重校验后用，C09/C10/V05 |
| 显式归正/resetFP | 明确动作允许从当前pose连续重建 | 最新杆轴重建FP base、headYaw=0；不删TP记忆 | 新FP entry重新验V02；不改业务aim |
| 同杆选目标/袋、aim/power/spin/预测更新 | manual保持eye/base/headYaw或TP pose | 不因TaskRevision改动抹记忆；FP entry关联可变为stale；旧观察记忆不自动宣称新任务adequate | 新主体/袋按V02重验；明确“本杆标准构图”请求可重建任务profile，区别于普通切换 |
| 新rack/新杆/母球明确移位、取消或恢复另一board | 先拒旧事件；不凭后台更新自动重站 | 建新ViewingContextKey，旧记忆不作新杆入口；历史board的显式恢复可采纳其pose为新请求，不能采纳旧token | 新入口默认与实际安全需重验，保旧pose只称继续观察 |
| resize/safe-area/HUD显示变化 | manual保实际pose/FOV，FP保base/头角 | 不清两模式记忆；布局有效性标stale，首次激活前重校验并反解controls | 更新LayoutRevision；几何合法不等于当前HUD可读，C10/V07/V02分判 |
| 房间/桌体transform、安全包络或profile规则变化 | 保留前先检实际安全；危险时走明确退避 | 旧几何profile失效，不以旧s套新范围；允许保已验证安全实际pose再反解 | C05/C09重校验；纯材质/曝光变化不销毁几何记忆，但V07视觉证据需更新 |

同上下文的普通切模式优先有效记忆；“当前杆瞄准归正”“全桌”“本杆标准”是不同显式请求。至少先在入口区分，不能让一个FP按钮既声称恢复头转又无条件headYaw=0。TaskRevision过期意味着旧记忆不能为新任务出具adequate证据，不等于后台有权搬走manual镜头；这样可同时守住C08与V02。

## 6. ModeMemory/context/layout修订后独立反例（源码复审）

本段针对新增ModeMemory、switchToRememberedMode、revalidateLayout及VM播放代次的版本；没有运行构建/测试，不把主控自报10＋6测试通过当反例覆盖。前文缺独立记忆/完全忽略manual布局/回放三个节点只查isPlaying的问题已有对应代码修订。

**[P1] 手动FP的中间记忆恢复完成后，首次横滑可能搬眼。** 构造：手动FP眼位E已记忆→TP→恢复FP到一半M→切去TP（saveActiveMemory记住pose=M、owner=manual，但firstPersonBase.eye仍E）→再次恢复FP并等待完成，pose=M、suspendedPose=true、memoryDestination=nil→横滑。TwoViewCamera.swift:288的takeManualControl先resumeExplicitMotion创建connector，却因wasManual=true且wasRestoringMemory=false跳过重基准；update随后将目标eye设为firstPersonBase.eye=E，在转头时把M搬回E，违反C07/实际接管要求。最小修正：首次从suspended中间FP姿态接管时也据实际pose重建冻结base（或正确分解头角）；区分已有manual连续connector，避免每个delta重复重基准。需增加此序列的eye不变断言，而非只测稳定FP记忆。

**[P1] 新context只清缓存，旧转场仍兑现。** TwoViewCamera.swift:216 setViewingContext清first/thirdMemory，但不取消connector/memoryDestination、不增加requestRevision。构造：自动FP/TP转场或记忆恢复到25%→loadBoard/非播放cue.place创建新context→下一update仍沿旧connector达到旧entry/memory.pose。外部三播放回调的strokeGeneration门禁不能阻止rig内部这条旧运动。最小修正：context变更使旧自动/记忆请求失效、递增requestRevision并hold实际pose；清connector/memoryDestination并suspend或对齐实际controls，新的显式请求再规划。需保manual可见pose，不能借取消自动目标把它强制重站。对应S02/C09与主方案上下文失效要求。

**已修订而未发现新确定故障。** layout独立记录最新viewport/insets并保lens，restore/切回记忆也套当前layout，修复了此前manual被guard忽略；room-derived r域没有变化时保s无需额外逆解。replayLastShot的100ms Task、运杆完成与球动画完成均检查新generation；旧代次不能仅因isPlaying再次变true通过这些门禁。

**仍未放行但不冒充本轮引入bug。** containsSubjects只证明保存subject点处于声明可读矩形，不能证明真实遮挡、尺寸、当前选球任务adequate或全域安全；TaskRevision/FP entry有效性及真实HUD图仍须V02/V07。普通重复模式按钮走显式reset是当前代码刻意政策，须与用户取舍/文档一致；不因缺独立按钮自动当实现错误。记忆connector路径的实体安全、真实原尺寸可读性与触控手感仍未由此只读审查验证。

## 7. 主控修后复核与实际验证追记

两个§6 P1已修：setViewingContext增revision、清connector/memoryDestination、对齐target并冻结actual；FP suspended记忆接管存在eye/base差异时从实际pose重基准。独立review子智能体只读再次核对修复保留，并检查新FP world→table receiver segment坐标、yaw及entry-only求解，无新的必要P1；未自行运行测试。

主控visual-repair-r3实际15新核心（含两反例）、32旧相机、4进袋、1scratch及5原生UI通过，17新图全部实审。功能通过不关闭FL-098观看用途问题；完整边界见`tasks/ui-reviews/UR-20261002-two-view-camera.md`与实施记录。


## 8. v0.2续审：摆球编辑与布局无解hold
只读复审发现moveDailyCue、dragMoved、nudgeBall直接改母球position，绕过place上下文失效。已在真实位移写入前统一使旧entry/模式memory失效，同失效任务后续delta不重复换context，actual眼位不动。新增真实VM用例覆盖三入口与零位移，合法CanvasPoint.y域[0,0.5]；首版夹具越界失败保留。

legalPose失败不能仅清connector并保持旧控制参数：若实际停在FP→TP中间pose，下一请求可能直接跳轨道。现失败分支suspendedPose=true、revision递增；下一有效输入resumeExplicitMotion从actual建connector，TP再反解yaw/s。新定向用例检查非法HUD→hold→恢复布局→反向首帧→manual终态；独立源码复核确认修正链已切断原反例。模式记忆恢复historical actual（可为非轨道中间pose）继续以actual connector进行，manual接管撤销目的。旧pose在新布局是否可读与页面反馈仍属C10/V07未闭合，不因此改变完整验收状态。未进行新能耗测量。
