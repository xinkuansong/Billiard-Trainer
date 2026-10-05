# W1/W2相机几何最小接入复核

2026-10-02；基线提交712c3b3a，工作区正在由主控实施，以下行号为本轮读取位置。角色为iOS Architect，采用项目适配与geometry-spatial-reasoning技能。只读生产源码，独占本文件；未构建、运行设备、新增测试或生成新相机截图。静态Python算术已执行，属于候选推导，不是实际场景验收。

**建议：W1先实现纯值轨道/FP状态及唯一实际pose出口；W2再接每日宿主。安全轨道、远端全桌构图、当前一杆可读是三项独立结果。不能把固定32°或旧dailyFOV与房间椭圆直接组合后宣布全桌可用。** 源码尺寸算术已经给出反例；最终profile必须从真实包络/HUD推导，并用用户要求的实际页面截图判断。

## 1. 坐标、尺寸与证据

- 世界坐标米制，X–Z水平，Y向上；θ=atan2(eye.z−C.z,eye.x−C.x)，θ=0从+X看桌，π/2从+Z看桌。内部θ不wrap，展示时规范到[−π,π)；s=0近、1远。不要使用SCNNode.eulerAngles.y冒充这个θ。
- C建议为(0,scene.surfaceY+BallPhysics.radius,0)，H为相对真实地板的眼高，绝对eye.y=floorY+H。台面Y、球心Y和眼高不得混用。当前球半径0.028575，台面规格0.8，故示例C.y=0.828575。
- [几何Steering](/Users/song/projects/13.billiard_trainer/.kiro/steering/table-geometry.md)与[AngleSceneCalculator](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/AngleSceneCalculator.swift:10)的2540×1270mm有效台面只用于球位；不是相机避让的可见外框。物理袋心、marker中心、实际皮革/台呢袋嘴也不能互换。
- [CameraRig](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/CameraRig.swift:627)外框兜底半长/半宽为1.4055/0.7995m；[AngleTrainingScene](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/AngleTrainingScene.swift:736)装桌后使用世界包围盒角点覆盖。**本轮没有运行USDZ读取，示例不是本次新资产实测值。** W1输入应接运行时包络，取不到则标fallback/unproven。
- [TableModelLoader](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/TableModelLoader.swift:126)按外框目标与实模型比例取平均uniformScale，最后结果不必精确等于目标X/Z。禁止用2.54+库厚度等推算结果替代装桌后的世界界。
- [BakedTrainingRoom](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/BakedTrainingRoom.swift:8)源8×6m、墙内35cm的安全半轴3.65/2.65m。它只给外墙边界；[房间生成器](/Users/song/projects/13.billiard_trainer/scripts/blender/build_training_rooms.py:83)还有座椅、杆架、屏风和高杆，需按真实资源/变换核对，不能据半轴证明家具净空。

## 2. W1最小纯值模型

直接在Core/Scene的相机专用纯值文件实现，不依赖SCNNode、求解器或View，不另建ECS/全引擎抽象。

```swift
struct ThirdPersonProfile {
  let key: ProfileKey // asset/transform/envelope/lens/viewport/HUD revisions
  let center, floorY, eyeHeight, verticalFOV, zNear, zFar: /* 单位明确的值 */
  let innerEllipse, outerEllipse: EllipseXZ
  let safety: SafetyScope // 不等于coverage
  let framing: FramingScope // unknown / declared task+domain / limited
}
struct ThirdPersonControls { var thetaUnwrapped: Double; var s: Double }
struct FirstPersonEntry {
  let eyeAnchor, baseForward, verticalFOV: /* 世界值 */
  let shotContextRevision: UInt64 // 失效不自动重站
  var headYaw: Double
}
```

Profile构造返回有效/退化/未知及原因；`pose(controls)`、`inverse(actualPose)`只计算值。state同时保存mode FP/TP、owner auto/manual、motion stable/transition/connector、display 3D/2D-suspended和ownerEpoch。轨道与FP都生成同一`CameraPose(eye,orientation,lens)`；CameraRig只保留一个commit实际节点的方法。

稳定TP：d=(cosθ,0,sinθ)，`r=exp((1−s)ln rNear(θ)+s ln rFar(θ))`，eye=C.xz+r·d、eye.y=floorY+H，orientation朝C且worldUp=+Y。lens固定在该profile；俯角为−atan2(eye.y−C.y,r)，不是独立输入。鼠标/手指增量只写target θ/s，actual按统一运动时钟追随；不能把眼位直线插值当作轨道上的阻尼。

逆解：θ由实际eye相对C的XZ得出，并选择距内部θ最近的2π分支；r=hypot(dx,dz)，s=ln(r/rNear)/ln(rFar/rNear)。仅当eye.y、orientation、lens及r都满足当前profile时称逆解成功；换profile且实际pose不在轨道上时需connector，不能只求出s就瞬移。

## 3. 从真实包络推导连续安全轨道

第一版可用保守构造，先证明它，之后再减少过度保守；不要为每个球形全局搜索机位。

1. 从装桌后的可见节点世界包围体取静态桌体XZ矩形半轴A/B，保存Y范围和资产变换revision。若中心不是原点，先统一C与包络中心；非对称包络用相对C两侧绝对最大值保守扩大，不能暗改C。
2. 相机不是必须模拟人体球体，但near clip矩形要考虑。若垂直FOV为V、aspect=W/H，则近裁面全部点距eye≤`cClip=zNear·sqrt(1+tan²(V/2)+(aspect·tan(V/2))²)`。取c=cClip+明确数值余量；它只覆盖近裁面，不保证整个视锥没有遮挡。
3. 桌矩形扩至(A+c,B+c)，内椭圆半轴`aNear=√2(A+c), bNear=√2(B+c)`。所有扩张矩形点满足椭圆二次式≤1，因为最大值在四角且等于1。r≥内椭圆径向边界即在扩张桌体之外；相切处包含数值余量。
4. 外椭圆半轴`aFar=roomSafeX, bFar=roomSafeZ`，其内部必在房安全矩形内。`rEllipse(θ)=1/sqrt(cos²θ/a²+sin²θ/b²)`；若aNear<aFar且bNear<bFar，全部θ均有rNear<rFar，周期光滑且径向区间连通。两参数曲面位于外椭圆内/内椭圆外，可直接证明桌体XZ与外墙眼位安全。
5. 这是**静态桌/墙代理的安全证明**，没有证明所有家具、动态杆、眼高/天花板或转场安全。W2用真实世界包络补这些域；动态球遮挡不应改变轨道key，但动态杆的实际碰撞风险需另查。保守包络拒绝一个入口不等于产品无解。

用上述source兜底尺寸、候选V=32°、zNear=0.01、874×402，cClip=0.012127973m；示例加1µm仅作为Double算术余量，生产余量须覆盖SceneKit Float变换/资产不确定度，不直接照搬。得到近半轴2.004830/1.147817m、远半轴3.65/2.65m。**32°为检验旧配置的候选，不是选择了新默认。**

| θ | rNear m | rFar m | H=1.7、C.y=0.828575时近/远俯角绝对值 |
|---|---:|---:|---:|
| 0° | 2.004830 | 3.650000 | 23.492790° / 13.427809° |
| 45° | 1.408716 | 3.032668 | 31.740731° / 16.031792° |
| 90° | 1.147817 | 2.650000 | 37.205849° / 18.202914° |

H=1.7来自当前每日TP基础眼位`surfaceY+0.90`，仅用于候选计算。世界眼高不变但画面桌沿/地面会变化；不能声称屏幕地面高度稳定。外椭圆比房矩形角区保守，如确有构图收益可后续用有证明的圆角矩形/超椭圆，但不能拿smooth(raw clamp)作净空证明。

## 4. 远端构图的真实数值反例与推导

固定H与台心时，令h=H−C.y，L=√(r²+h²)，cθ=r/L，sθ=h/L。对相对C的点(x,dy,z)：q=x cosθ+z sinθ；相机右向坐标u=x sinθ−z cosθ；上向v=−sθ q+cθ dy；正深度D=L−cθ q−sθ dy。投影为u/(D·aspect·tan(V/2))、v/(D·tan(V/2))。数值计算用|u|，左右基向量符号统一不改变本节拟合值。

在上述远椭圆，代理包络取外框X/Z角点、Y∈[0.8,0.85715]。各pose的整画幅必要VFOV为`2atan(max(|v|/D,|u|/(D·aspect)))`。包络角点得到的条件是该凸盒入视锥，不是袋口/球轮廓无遮挡；它还未纳入真实库顶Y。

| viewport | θ | 仅整画幅必要VFOV | 保守中央矩形代理必要VFOV |
|---|---:|---:|---:|
| 874×402 | 0° | 17.5748° | 23.7684° |
| 874×402 | 45° | 30.7689° | 39.2811° |
| 874×402 | 90° | 35.4732° | 47.0592° |
| 1366×1024 | 0° | 28.2816° | 33.7643° |
| 1366×1024 | 45° | 46.2692° | 54.4660° |
| 1366×1024 | 90° | 55.0646° | 64.2519° |

矩形代理用FreePlayView源60pt两列、44pt顶栏、Spacing.xs=4、假设trailingSafeArea=0，水平可用宽=W−232；为台心居中取上下各44pt，故qx=(W−232)/W，qy=(H−88)/H。它是**解释尺寸影响的保守示例，不是实际HUD采集**；真实非矩形Ω可有更大可用区域，也可能因spin/反馈更差。

有限0.01°采样发现上述代理所需VFOV最大约47.1526°（874×402）及64.3668°（1366×1024），在θ≈272.74°。此扫描只找反例，不是整圈连续证明；不能把四个标准方向中的最大值当全域最大值。

该计算足以否证“固定32°＋这条远椭圆就保证常规全桌”；甚至不扣HUD，较窄画幅θ90也失败。**不推荐直接把VFOV升到65°解决：目标球会变小，低机位透视和袋嘴可读仍失败。** 候选H从1.7升至2.4m时，同θ90整画幅必要VFOV降为30.4092°/47.7817°，说明高度有作用，也说明高眼位并非跨画幅万能解；2.4m不是推荐人眼高度。

可落地profile推导流程：先给定任务/H舒适范围/lens可接受范围→读实际桌与room包络及Ω→用解析/区间方法给候选开放域的投影约束→选择有限且连续的rNear/rFar与默认入口→实际截图比较→冻结profile。普通轨道不依赖球形；本杆入口允许从当前一杆上下文做**一次显式构图评价/任务请求**，不让recompute持续改镜头。

第一片可用同一安全轨道承载测试入口θ=0或π、s=1，874×402/V32在该代理上有全桌入框余量；**没有实际新图，不能据此称入口效果适用。** 工作近景、长台/贴库/六袋可达、其他θ/HUD/设备仍须逐任务验证。若普通入口不adequate，优先修HUD或明确有界工作构图偏移，再择一调整H/lens；不能以limited标签或2D把常规失败放行。

## 5. FP固定eye/headYaw的最小算法

显式首次进入/归正时读取本杆真实strike/aim/elevation，构造entry；随后选球、袋、力度/塞、求解完成只标记entryContext过期，不重新生成眼位/baseForward/lens。模式按钮恢复该mode memory与“按新杆归正”分开。

当前[dailyPlayerPose](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/CameraRig.swift:159)用杆轴后0.90m、轴上方0.13m生成eye，FP例eye=(strike.x−0.90cosα·aim.x, strike.y+0.90sinα+0.13, strike.z−0.90cosα·aim.z)。可作为entry候选起点；0.90/0.13是旧实现经验值，不是安全证明。根据实际杆网格半径、最大回杆、near clip以及库/房包络检查再接受；高杆与贴库不能只沿旧参数重用。

固定eye后，baseForward为世界单位向量；headYaw定义水平bearing增加：β=atan2(forward.z,forward.x)，β=βBase+headYaw，保持baseForward.y。对应SceneKit右手Y轴quaternion为`Q=rotation(+Y,−headYaw)·QBase`，或直接以旋转后的forward/worldUp求orientation。例baseForward=(1,0,0)，headYaw=+π/2得到(0,0,1)，eye不动；不要把headYaw传入绕pivot的targetYaw。

头转可把袋口移入画面，不能改变同眼位实体遮挡。头转界/gain由任务与实际端点图选择；FP竖滑/pinch尚未确定，首片不得沿用旧变pitch/FOV当默认新政策。出杆是否自动归正/切镜属政策，不能让几何helper暗自决定。

## 6. W2必须隔离的旧写入链

| 当前源码链 | 最小接入建议 |
|---|---|
| [selectTarget](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PositionPlay/ViewModels/PositionPlayViewModel.swift:824)记录pendingCameraTarget，求解后[1552](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PositionPlay/ViewModels/PositionPlayViewModel.swift:1552)自动request TP | 新每日path只更新shot context；entry/归正/明确auto镜头事件才写请求，manual不被迟到求解夺权 |
| [updateCuePose](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/CameraRig.swift:336)杆向改变自动enter FP | 新path只更新业务杆姿与entry stale状态，不调用重站 |
| [beginManualOrbit](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/CameraRig.swift:896)清playerView=nil | 新path保FP/TP mode，只改ownerEpoch/owner；零delta/轴未判定不接管 |
| [handlePan](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/AngleSceneView.swift:793)旧轴锁后调用旧水平/竖直方法 | 新path在同一命中/拖球路由后转为θ/s或headYaw输入；明确斜滑政策；可移动球能力先于命中，不重写摆球解算 |
| [pinch](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/AngleSceneView.swift:850)按手指附近球重设观察pivot，再改FOV/距离 | 新path禁用subject pivot；若采用pinch，则仅映射TP同一s，FP按显式政策，不成为隐第三种控制 |
| [renderUpdate](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/AngleSceneView.swift:589)rig update后[594](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/AngleSceneView.swift:594)可能lockCueBallScreenAnchor | 新path禁止二次translate；唯一actual commit后冻结CameraFrame，投影/标签/拾取同帧读取 |
| [viewport.didSet](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/CameraRig.swift:479)只wholeTable重新拟合；2D/3D另有SCNTransaction | resize/HUD revision先保持实际pose，合法才逆解新s；不保旧s导致瞬移。2D suspend存actual/mode/owner，恢复或connector单一拥有者 |

FreePlayView传给新host真实SCNView bounds/drawable scale与HUD几何，而非中央stage aspect；projectionDirection显式vertical。Ω使用实际顶栏/仪表/圆形按钮/反馈/spin遮罩与主体padding，visual mask与touch mask分开。宿主可先提供保守区域并标proxy，不能把它当真实HUD已验收。

## 7. 连续性、connector与完成边界

θ/s阻尼在合法参数域内推进，发布profile时证明近远分离及周期性；端点clamp不积累隐藏输入，反向增量立即生效。固定TP eye.y/lens只限稳定态；两模式connector允许改变H/lens，但整条路径要安全。旧`smoothToPose`在pivot/radius/height上独立插值并逐帧room clamp，不能直接当新轨道安全connector。

FP→TP入口、resize后轨道失效、转場中用户接管可能从轨道外actualPose开始。先冻结实际pose/速度/owner，再验证候选connector对膨胀桌/墙/家具/杆包络的连续净空；无路径先保pose/报告待连接，不能把最近θ/s投影后立即写回。可尝试经有证明的公共净空高度/绕行段，但“先抬高”也要有资产高度和天花板依据。

W1的完成最多是纯值构造、映射、逆解与所声明静态代理域成立；W2完成需要唯一写入者、业务事件/代次隔离、原生手势、实际截图和常规任务可达证明。新截图矩阵沿[观看范围分析](/Users/song/projects/13.billiard_trainer/docs/research/20261002-render-engine/CAMERA-COVERAGE-ANALYSIS.md)覆盖长台、贴库/高杆、六袋、第三球遮挡、回放关键时刻、2D/resize与HUD叠层。没有实体/HUD图和用户效果观察前，不宣称全部入口合适、无遮挡或新相机已通过。

## 8. 主控新TwoViewCamera候选代码即时复核

追加范围：[TwoViewCamera.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/TwoViewCamera.swift)与本轮CameraRig新增接入，版本为动态工作区读取快照。此节是源码风险复核，不是运行缺陷复现；主控后续修复应按实际diff重核，不把下面问题永久归于最终代码。

1. **朝向基向量成立。** 22–27的right=(sinθ,0,−cosθ)、up=(−cosθsinα,cosα,−sinθsinα)、back=(cosθcosα,sinα,sinθcosα)满足单位正交、right×up=back；静态Python在0/45/90/180/270°算det约1、叉积最大误差5.56e−17。forward=−back，pitch为负时向下；不要再把right换成反号造成左手矩阵。FP217–218的bearing+headYaw也与本报告约定一致。
2. **优先修连续输入的重启连接。** 183–195在connector存在期间，每次horizontal/vertical/pinch都会重取actual yaw/progress、重置target，并把elapsed清零。于是先前增量不再累计；在60Hz下每次0.25s连接仅走smootherstep(1/15)=0.00267457，再乘首层阻尼0.12482668，单步角反馈约原增量的0.00033386（局部小角近似，不是设备响应实测）。仅在第一次接管原自动连接/恢复held pose时建立连接；后续增量累加同一target，不重启时间。owner已manual不应反复做重新逆解。
3. **半径逆解不能无条件clamp。** 56–57把r<near映成s=0，把r>far映成s=1；它可用于明确的投影目标，不能叫actualPose合法逆解。还须验证eyeY、lens、orientation、正半径、profile key和near<far，返回exact/needsConnector/invalid。否则转场中接管会把任意空间pose连接到一个未经安全验证的边界姿态。
4. **near=0.90未由TP包络/任务推导。** 74借旧FP杆轴后退数，不能称TP解剖站位推导。若采用本报告的外包络轨道，就使用真实桌体+c构造near边界；若有意让TP在桌上空接近，则另以真实桌顶Y/杆/近裁面证明该眼高区间净空，并从主体尺寸推导near。桌上空眼位不自动不安全，但不能继承外包络证明。
5. **720方位点拟合只发布候选。** 83–98远端拟合没有连续误差上界，也没有近端主体可读/遮挡证明。1.012倍率是否覆盖方位遗漏需界证据；FOV≤100仅数值限制，不是用户批准的镜头质量上限。`isWholeTable`应标任务意图/采样fit，而非完整覆盖已证。wholeTable点集Y=bed..bed+2R也不包住真实库顶/袋嘴。
6. **恢复必须接当前layout key。** 234–249原样恢复profile并held actual，这一步避免立即跳镜有价值；但2D期间resize/HUD改变后，旧viewport/insets/lens仍留在profile。当前CameraRig的layout refresh只允许automatic TP，manual旧key将长期保留。应冻结actual并记录profile stale，首个明确输入用当前layout重建/合法逆解；不要在resume阶段无条件回旧轨道。安全key失效与单纯构图key失效分开处理。
7. **直线connector不是净空证书。** 30–34/224直接插值眼位和slerp；两端在内椭圆外，连线仍可能穿其内部，或经过杆/家具。需检查整段对膨胀真实包络的净空；无证据的连接保留candidate状态。slerp可临时产生roll，若产品要持续worldUp也需单独检查。
8. **按任务锁定工作anchor，不能偷偷变普通轨道。** 新CameraRig115–142在非wholeTable时以球/袋嘴点集bbox中心作anchor，且源每次进入会重新生成lens。可以实现本报告C“显式工作构图”，但不能同时声称所有TP都固定台心/不依赖球形。明确entry语义和profile版本；横滑/竖滑、选球/recompute、manual resize均不能重建它。基础TP依旧用台心；工作profile仅明确请求建立并冻结。

补充数值纪律：Double保存unwrapped θ/s与逆解，末端才转Float；使用angleDelta作轨道阻尼会在target−actual超过π时选择反向短绕，若要求累计手势保持方向，应按未wrap差值推进并限速。mode entry应区分恢复记忆/新entry/显式归正；当前enterFirstPerson每次headYaw归零、enterThirdPerson每次s=1，只适合作为新entry，不能直接当模式记忆恢复。

当前新增guard已经绕过updateCuePose自动FP重站、beginObservationPinch换pivot，并让allowsCueScreenAnchor在新path返回false；这些方向正确，§6是旧链检查清单，不表示修后仍存在。还需继续核对VM求解/事件、2D/resize与唯一actual commit；不能仅因多处添加guard判W2通过。

## 9. 实施追记：入口视线与任务尺度

主控实现TP实际任务包络入口进度，以及FP仅explicit entry使用真实table子树segment检查有限接触/下缘ROI，抬眼后冻结eye/lens。FP ray端点转换到receiver坐标，包含Wood/BlackWood与库体，不复用只含TaiNi/Leather的物理patch代理。独立专项看过旧fixture3/13真实下缘遮挡，确认只改pitch/FOV不能解决。

实际r3核心/原生UI和17新图结论由主控给出：接触区改善，TP远侧母球尺度仍不足、近推关注未闭合。ROI样点、二分搜索、720heading fit都不是完整可见带或连续全域证书，不将本文件源码审查改写成W1/W2放行。


## 10. v0.2主控修订与独立复核：冻结任务的径向视锥约束

X/Z水平、Y向上、米制。冻结anchor与眼高差h>0；点相对anchor为(x,dy,z)，q=x cosθ+z sinθ，u=x sinθ−z cosθ，L=√(r²+h²)。深度D=(r²−qr+h²−hdy)/L，竖直坐标v=(rdy−hq)/L。实际竖直/水平FOV与创建时HUD域固定。

顶边T要求T(r²−qr+h²−hdy)−rdy+hq≥0；底边B要求B(r²−qr+h²−hdy)+rdy−hq≥0。取正二次式最大非负根之后的分支；负判别式保顶点而非直接0，给出连续保守下界（不是无条件C1/速度保证）。水平要求Hside(r²−qr+h²−hdy)≥|u|L。D对r的导数分子g=r³+(h²+hdy)r−qh²；h+dy>0时g严格递增，先移至g≥0分支，再二分其唯一水平下界。各点取最大，保护冻结两球AABB；12pt为屏幕留白。

独立复核确认上述符号/分支条件成立，并指出两处必修：nil不能回退至已不合法far；仅冻结insets而替换viewport会改变轨道。主控已增加railViewport、生产legalPose检查与实际pose hold。后续状态复核要求转场hold置suspendedPose并增revision，下一有效输入从实际中间姿态重建connector。常规合法profile的有限角采样/实图不是全域连续mesh安全证明。

入口候选比较当前、72方位、两球连线两侧；优先近似投影圆盘分开，再最大化较小球的近似投影直径，近似同分偏向当前heading。球贴近时仅追求直径会增加遮挡，故轮廓分离必须先于尺寸。真实table/第三球遮挡和HUD中央浮层仍需实图。全桌不采用工作任务的两球约束。

源代码中的near数学无解用NaN表示，生产update不提交这种pose；候选720方位检查不证明中间角均合法，因此每次操作仍校验。冻结旧轨道不意味着新布局可读，新布局无解时hold；旧profile保护的是入口时的球位置，摆球编辑使旧entry/记忆失效，下次明确进入才重建。转场路径、C1/vMax、所有合法球形/设备与页面受限反馈尚未完成。
