# 两视角相机：轨道算法、状态与联合帧契约

2026-10-02；专项正式方案输入，文档设计，生产未实施。只写本文；未改代码、构建、运行设备或新测试。基于当前CameraRig、AngleSceneView、AngleTrainingScene、PositionPlayViewModel、CueStroke及[联合契约](CAMERA-RENDER-CONTRACT.md)。本文建议不等于参数/事件政策已经获批。

## 1. 已确认方向与推荐选项

**已确认方向**：3D只保留第一人称与第三人称；2D负责直观全盘；第三人称上下滑动沿统一算法轨道前后进退；两种3D视角均支持左右滑动。本文推荐先接每日清台，其他训练/导出推广范围单独列明；实施范围不是用户已确认项。

**本文推荐、尚未裁定**：第三人称固定world眼高及VFOV，默认观察中心固定在床面几何中心；上滑近/放大，下滑远/缩小；第一人称固定眼位转头；自动切镜时机仍由产品选择。pinch是否映射同一个轨道s、第一人称是否接受上下输入，也待裁定，不沿用旧FOV/俯角手势作默认。

固定world眼高指`eyeY=floorY+hTP`，不指屏幕地板高度不动。朝固定桌心看时，前进自然改变pitch和透视；若同时要求地板/桌沿屏幕锚定，需要另加构图约束，可能与固定FOV/近端位置冲突。不能用旧35°、0.95秒、8%/15%护栏代替新产品参数。

10-01[通用相机方案](../../../tasks/DAILY-CAMERA-GENERAL-ALGORITHM-20261001.md)未实施；复用其实际几何/HUD、所有权、无解和过渡方法，不继承旧三视角或每球形全局机位搜索。[进袋回切](../../../tasks/DAILY-POCKET-CAMERA-20261001.md)是现有兼容政策，不是新语言最终时机。

## 2. 第三人称两参数轨道

以实际加载球桌的床面中心为`C`；使用米制正交table-local水平X/Z轴及world-up Y（资产缩放先体现在几何描述，不重复缩放u），不用本杆球/袋/ghost重新定义中心。参数只有`θ,s`，稳定态定义：

```text
u(θ) = (cosθ, 0, sinθ)                  // table-local，转换到world
r(θ,s) = (1-s) rNear(θ) + s rFar(θ)
E(θ,s) = C.xz + r(θ,s) u(θ), Y=floorY+hTP
Q(θ,s) = lookAt(E, C, worldUp)
VFOV = fTP;  aspect来自实际viewport
s=0最近端，s=1最远端，0≤s≤1
```

`θ=0`眼位在桌心的+X方向，`θ=π/2`在+Z方向；内部保存unwrapped θ，只有存档/交换才规约到`[0,2π)`，不把SceneKit Euler yaw直接当此θ。左右输入正负方向是统一策略参数。推荐`Δs=kv*Δy/viewportHeight`，因此UIKit负Δy上滑变近；`Δθ=kh*Δx/viewportWidth`。敏感度未冻结。

pitch由`atan2(eyeY-C.y,r)`和朝向自动产生，不单独clamp pitch/距离/FOV再拼姿态。固定key时线性r映射严格单调，可从实际r反算`s=(r-rNear)/(rFar-rNear)`；进退是同一曲线的逆操作。s越界增量丢弃，不累计隐藏overscroll，回滑立即响应。阻尼/限速施加在unwrapped θ、s上，再生成姿态，不能分别阻尼XYZ导致穿过边界。

### 2.1 有明确安全含义的几何基线

实际矩形桌体投影、房间变换和安全margin来自资产描述；8×6m是当前房间包络输入，不复制为所有scene的常量。固定眼高还须满足floor/ceiling和相机安全半径约束。先在该水平层建立保守安全轨道：

- 近边界：以C为中心，取包住所有静态桌体/库/皮革投影与相机安全margin的矩形半长宽`a,b`；取包住它的椭圆轴`AN=√2 a, BN=√2 b`。其径向界`rN=1/sqrt(cos²θ/AN²+sin²θ/BN²)`连续光滑；在其外不会进入该投影包络。它是保守排除域，可能牺牲本可安全的近景，不能称最佳轨道。
- 远边界：在按相机半径/margin侵蚀后的矩形房间内取内接椭圆，中心O、轴`AF,BF`。把`C+r*u`变换到room-local，对`((x-Ox)/AF)²+((z-Oz)/BF)²=1`解正根得到rF；C必须严格位于该椭圆内。偏心/旋转通过真实变换处理，不能假定球桌与房间同轴同心。
- room-local记`q=C-O`，`A=u.x²/AF²+u.z²/BF²`、`B=2(q.x*u.x/AF²+q.z*u.z/BF²)`、`D=q.x²/AF²+q.z²/BF²-1<0`，则`rF=(-B+sqrt(B²-4AD))/(2A)`；A>0、D<0确保正根存在。B≥0时用等价`-2D/(B+sqrt(B²-4AD))`避免相减消去，并要求C有严格室内margin。near外、far内且`rN<rF`的径向段构成候选安全域。
- 这两条椭圆解决矩形角点直接min/max径向界的速度折角；不是最终美学形状。可以换经证明的rounded边界，不能按四边各拟合一条曲线再在角点跳接。

若包络与房间可证明嵌套，普通轨道可连续绕桌一圈；若某方位`rN≥rF`，只有该保守构造没有轨道，不能据此声称真实房间数学无解。可用精确rounded包络放宽，或只开放已验证连续方位分量；不跳过非法扇区、不突然抬眼高/改FOV。

### 2.2 HUD、构图及连续边界

轨道描述只在几何/viewport/HUD/policy变化时生成，不因选球选袋或每帧球位重做机位搜索。要求分开：硬安全、近端允许裁桌、远端上下文/最小桌面尺度、HUD视觉遮罩；3D不承诺每球形所有球/袋/路线无遮挡，整盘阅读交2D。远端是否强制全桌入框是待裁定质量政策，房间/FOV不足时应报告`limitedFraming`。

以真实投影的球桌固定几何/构图参照定义`g_k(θ,r,viewport,HUD)≥0`。沿每个θ求**连通合法径向分量**，不假设所有投影/HUD约束对r全局单调；再选在θ上可连续延伸的同一分量。不能只解near/far两个点就认为中间可用。中心被HUD遮住时，固定中心/FOV政策可能无法达标，应返回受限，不能暗改成跟球中心。

在已证明根分支连续的域，多个lower/upper界可用向域内的smooth-max/smooth-min连接：`Lε=ε log Σ exp(Lk/ε)≥max Lk`、`Uε=-ε log Σ exp(-Uk/ε)≤min Uk`（稳定logsumexp实现）。这保持保守边界，ε为米制参数；若平滑后无间隙，收缩开放域或返回受限，不放松安全。重新生成轨道必须检查整段投影/安全及非空性，而不是独立角度clamp。

**路径证明边界**：椭圆包含关系/径向根可以解析判定；其他连续域用几何扫掠或区间包络证明`g≥0`，以整个θ/s区间为单位。有限角度/动画帧采样只能找反例或作为种子，不是全路径证书。不能完成证明的区域不承诺全域开放，输出`notCertified`/受限原因；并不增加用户诊断toast。动态球杆/其他实体变化另由输出安全守卫处理，静态轨道证书不自动覆盖它们。

## 3. 第一人称：站位与转头分开

推荐显式进入第一人称时，根据本次杆轴/打点/杆姿和安全域产生一次合法眼位`EFP`与基准方向`QFP`；保留当前几何方法作为adapter，眼高、setback、镜头重新列policy，不沿用现有数值即称定稿。普通横滑只改变头yaw`ψ`，眼位不变，pitch/FOV默认保持该entry值；旋转绕world-up且保持零roll。yaw可有舒适范围，但范围待裁定。

转头改变视线，不改击球aim/power/spin，也不绕母球搬站位。`回到杆轴`是显式意图或已裁定事件，不让下一杆推荐悄悄把头转回。用户选球/袋只更新业务上下文；需要重新站位时须明确请求。已进入手动控制后，后台cue pose更新不能无条件重建眼位。

第一人称entry可能被球桌/杆/房间限制；不能靠换成第三人称冒充成功。当前眼位若被动态实体侵入，暂停运动本身不能解决碰撞，需要已验证退避路径或明确受限政策；不宣称固定EFP全时安全。普通相机流程不调用进球solver作可观察准入。

## 4. 最小状态、版本与提交权

保留既有CameraRig/VM/宿主职责，先增加小值类型，不拆完整新引擎。建议状态：

```text
displaySpace = twoD | threeD
mode3D = firstPerson | thirdPerson
owner = automatic | manual; ownerEpoch
motion = stable | transition(pathID,startTime,actualOrigin,target) | manualConnector
third = {θUnwrapped,s,trackKey}; first = {EFP,QFP,ψ,entryKey}
suspended3D = {actualEye,Q,lens,mode,owner,controls,keys,wasTransitioning}
sessionGeneration, shotGeneration, requestRevision, cameraRevision, seekEpoch
```

mode与owner不可混用。当前`beginManualOrbit`把`playerView=nil`，实际兼作“手动不再自动回切”的标志；新语言不能沿用nil造成第三种隐含3D模式。`automatic`也不表示未经用户请求：按钮选模式可启动自动安全转场，随后手势接管成为manual。[CameraRig.swift:896–926](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/CameraRig.swift:896)

trackKey包含静态几何/房间/眼高/FOV/policy/viewport/HUD，不包含球袋选择；第一人称entryKey包含本次明确杆姿请求。cameraRevision表示实际姿态，blockerRevision仍只看球心/高度/有效opacity。相机改变只影响材质视角、投影和表示误差选择，不自动重算V；资源不足时用本帧原公式，不改镜头限制观看能力。

同一frame owner消费输入→推进一次运动/SceneKit action→取得最终presentation→固定`CameraFrame {E,Q,view,projection,projectionType,viewport,zNear,zFar,time,versions}`→编码。HUD/project/unproject/hitTest与渲染用该实际状态。DisplayLink只唤醒，不是另一套剧情时钟；SceneKit callback不假定主线程，采样/提交区间无其他owner写节点。[AngleSceneView.swift:539–607](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/AngleSceneView.swift:539)

## 5. 事件表与跨模式行为

| 事件 | 推荐状态/动作 | 提交约束 |
|---|---|---|
| 显式进第三人称 | mode=TP；同key恢复有效θ/s，否则统一几何entry；从实际E/Q规划转场 | 目标轨道/安全有效，ownerEpoch/requestRevision匹配 |
| 显式进第一人称 | mode=FP；解析当前明确杆姿entry，重置ψ；从实际姿态转场 | entry结果匹配当前请求，不保留旧失效目标 |
| 手势开始 | owner=manual，递增epoch；从实际显示姿态建立current/target；取消旧自动路径 | 不拿尚未到达的target接管 |
| TP稳定横/纵滑 | 只变θ/s；沿同一合法分量执行；零增量不变 | 不改中心/眼高/FOV，不跳越非法区 |
| FP稳定横滑 | 只变ψ、EFP保持；纵向/pinch按待裁定policy | 不改变击球意图 |
| 转场中接管 | 保留实际E/Q/lens；取消旧path；进入manualConnector，从该点施加手势并安全连接对应模式域 | off-track姿态不立即投影到γ；无安全connector则保持姿态/限制增量，不跳镜 |
| 手势结束 | 保留manual及实际控制值；可有明确有限阻尼，无自动重居中 | 旧automatic回调无权限 |
| 选球/袋、后台推荐 | 更新击球事实；TP轨道中心不变；不抢manual | 只有明确新相机意图能更换entry/owner |
| resize/HUD变更 | 重建track约束；manual保持实际E/Q/VFOV，更新aspect及可行边界；automatic可重新求entry/轨道 | 不可能同时保证原姿态与全桌入框；受限时不暗改镜头 |
| 进2D | 保存实际3D快照和owner；取消path并递增epoch；displaySpace=2D | 不保存target冒充实际、不继续后台自动转镜 |
| 回3D | 同key恢复实际快照；manual保留；automatic若旧转场未完/输入变更，从冻结姿态新代次规划 | 不续旧path剩余进度；变更key先检查安全 |
| 击球capture/settle | 根据已裁定事件policy申请转镜；当前兼容默认是指定目标/自由非母球capture，无capture杆末 | shotGeneration+ownerEpoch+eventID匹配；不读最终进球布尔提前切镜 |
| 取消/重开/重打 | 撤销旧事件游标与path；重打恢复本杆实际相机快照；重开entry另由policy | session/shot generation递增；旧回调不写新局 |
| 暂停/seek/GPU跳帧 | 暂停冻结映射；seek增epoch按policy重置/抑制事件；跳帧后消费有效时间区间 | 一次event语义，不能因没draw该时刻漏事件，也不依赖GPU completion转镜 |

**稳定态固定眼高的范围**：FP↔TP转场可改变眼高；manualConnector也可暂在轨道外，但必须保留实际接管姿态、受安全路径限制，完成才满足稳定模式域。否则转场中接管与“立即强制固定眼高”会冲突。connector不是第三种可选视角，也不是新增独立height手势。

manual resize后当前点若在新构图域外，零输入保持，不继续恶化受限项；接受改善方向或显式复位。若真实安全域发生改变、当前点本身不安全，应另执行经过验证的退避/受限处理，不能把“保持姿态”当安全证明。轨道key变更时用实际r反算新s（若合法），禁止沿用旧s使位置突然变化。

## 6. 转场与事件时钟

目标E/Q/lens与path分开：有合法终点不能证明直线、SLERP或中间帧都合法。稳定TP轨道内运动沿γ；跨FP/TP或2D恢复使用固定安全域中的connector，若直达段穿桌/杆则用经验证的中间段，失败返回受限、不隐式改目标模式。朝向使用world-up基，lens在tan-half域连续；相反视线/近俯视由确定性table轴处理。速度/时长依实际路程约束，参数未定。[CameraRig.swift:1221–1253,1276–1338](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/CameraRig.swift:1221)

事件使用`{sessionGeneration,shotGeneration,eventID,eventTime,ownerEpoch,policyVersion}`及消费游标。正常播放按上次→本次有效呈现时钟区间处理；多个事件同帧按时间与稳定序号执行。向前seek是否重放是policy，不等于正常经过；消费camera事件不能反向改变物理时间。资源准备和GPU背压只影响draw，不决定剧情事件发生。

当前VM已将capture事件wait与母球回放放在同action group，并检查strokeGeneration；`CueStroke.transitionPlayerCameraForShot`还核对原始杆轴引用。增量迁移先把其事件转成同clock请求，保留现有actions，不全量重写回放/媒体。[PositionPlayViewModel.swift:1737–1755](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PositionPlay/ViewModels/PositionPlayViewModel.swift:1737)、[CueStroke.swift:241–251](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/CueStroke.swift:241)

## 7. 分批修改与交付边界

| 批次 | 拟改范围 | 实施后需成立 |
|---|---|---|
| C1 状态/CameraFrame | CameraRig mode-owner拆开；AngleSceneView输入事件；VM请求/generation；AngleTrainingScene实际挂起快照 | 两种mode无nil隐态；实际姿态接管；取消/恢复不被旧回调写；与render snapshot同帧 |
| C2 TP轨道 | 小型TrackDescriptor/纯几何函数；替换daily上下/左右控制，保留其他宿主adapter | s端点/逆操作、θ周期连续、固定world眼高/FOV；room/HUD受限分量和证明边界明确 |
| C3 FP与安全connector | 固定entry眼位+headYaw；从实际姿态转场/中途手动连接；2D/resize恢复 | 转头不改aim；转场不跳镜/穿实体；manual不被后台推荐接管 |
| C4 事件与联合接入 | VM/CueStroke事件统一clock；投影/拾取/标签适配最终CameraFrame；单消费端接渲染场 | capture/settle/跳帧/seek的一次语义；camera与blocker版本分开，域外用原公式 |

现有源码证据：`CameraRig.swift:774–866`目前横滑改yaw、纵滑改pitch/elevation、pinch改lens/distance；`:556–614`保存恢复含运动target/progress，需改为实际挂起语义；`AngleTrainingScene.swift:1122–1158,1222–1358`保存/事务转场需与owner协调；`PositionPlayViewModel.swift:58–94`发布模式/上下文；`:1783–1789`当前杆末回切。代码行号核对日2026-10-02，不据旧报告宣布新方案已经落地。

开始实施前冻结的是控制含义与契约，不需要先跑设备找架构：用户已确认两种3D与轨道方向功能；眼高/FOV数值、上滑方向、第一人称headYaw、pinch/纵向、自动切镜时机及推广范围仍列为产品决策。实施后的数学不变量、连续路径、真实HUD和设备手感验证是交付关口；本文没有执行或宣称通过这些验证。

## 8. 与主稿交叉收口

以[两视角相机语言与渲染架构主稿](../../../tasks/TWO-VIEW-CAMERA-RENDER-PLAN-20261002.md)作为后续实施口径，以上独立草案按以下结论校准：

- 主稿选择对数径向映射`r=rNear*(rFar/rNear)^s`，统一`s=0近、s=1远`；合法时反解`s=log(r/rNear)/log(rFar/rNear)`。本文§2线性r保留为备选，不与对数r并列成为同时实施要求；两者都要求`0<rNear<rFar`及整段合法。
- resize/HUD/trackKey变化先保留实际E/Q/lens；实际姿态在新轨道上合法时才反解新s，不能保留旧s导致瞬移。manual控制权继续保留；受限输入/安全变化处理沿用§5，不以更新key暗中重居中。
- 状态统一为`owner=automatic/manual`，`motion=stable/transition/connector`；本文manualConnector只是`connector + owner=manual`的旧草案命名，不是第三个owner或第三种3D模式。2D属于独立display挂起，保存实际3D姿态与权限，取消旧路径。
- 模式进入、headYaw记忆与显式归正是不同事件。§5“进入FP重置ψ”不再作为无条件政策：普通entry按有效entry/headYaw记忆恢复，显式归正才按当前杆轴校正；重站需明确请求。FP的aim/cue pose数据更新不自动改EFP或清空手动headYaw。
- “先每日清台”仅是本文推荐的受限接入范围，已在§1纠正，不能写成用户确认全部训练/媒体推广或确认先实施每日。眼高/FOV数值、手势方向、headYaw与切镜时机的产品状态仍按主稿区分，不因报告达成一致视为用户批准。
