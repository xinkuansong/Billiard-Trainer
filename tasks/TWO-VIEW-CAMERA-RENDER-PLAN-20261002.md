# 两视角相机语言与渲染架构方案

日期：2026-10-02。状态：v1.3 设计建议，已补独立验收契约、截图/观察范围及用户操作意图，待产品裁定与实施；只读代码、历史原图、推导、撰写和审查。没有生产接入、构建、设备测量或性能放行。

配套[验收标准](TWO-VIEW-CAMERA-RENDER-ACCEPTANCE-20261002.md)：逐项定义场景、通过条件、证据与失败退路；硬要求和待裁定数值目标分开。文档完成不代表这些验收项已通过。

用户追加：相机效果必须直接审实际截图，各种场景观察范围要合适。按[截图与观察范围专项](CAMERA-VISUAL-COVERAGE-20261002.md)定义任务、常规支持域、主体大小/实体与HUD遮挡及可达路径。常规任务不能仅用受限提示/2D入口判PASS；固定眼高/FOV/台心推荐若阻碍用途，先修订相机规则，不能删主体。新方案截图尚未生成。

## 1. 要解决的问题与方案主张

当前相机把模式、取景目标、手动控制、距离、俯角、FOV和回放转镜交织在一起；当前台呢又在大量屏幕片元上重复计算相同接收点到灯的球遮挡。仅改变几个画质参数，或把SceneKit整体换成另一引擎，都没有先解决这些结构性重复。

建议保留SceneKit场景、资产和动画能力，逐步建立可控制的帧提交与材质计算路径。相机用两种明确观看意图；渲染按世界内容与观看响应拆分：**世界遮挡联合场消除重复球检测，方向矩与镜面响应分解进一步减少方向求和。** 最终是否需要更广的Metal迁移，由这条路径的承载限制决定。

第一实施域建议为每日清台的交互场景；其他训练页、视频导出逐出口适配。六袋、球/杆、回球、2D读盘与物理能力不因床面优化而减少。这是分阶段接入范围建议，尚未实施。

| 已由用户明确提出 | 本方案推荐，尚待裁定 |
|---|---|
| 3D只保留第一人称和第三人称 | 第三人称台心固定、固定世界眼高和FOV |
| 2D提供直观全盘阅读 | 第三人称用轨道进度s＋绕桌方位θ |
| 第三人称固定算法轨道；上下滑进退、放大缩小 | 上滑靠近、下滑后退；捏合映射同一个s |
| 两种3D模式均支持左右滑动 | 第三人称绕桌；第一人称固定眼位转头，独立headYaw |
| 摄像机语言与渲染优化一起分析 | 手动观察拥有控制权；选球、求解完成不自动夺权 |

旧方案中的35°、0.95秒等数值不成为新语言要求。眼高、FOV、端点、头转范围、灵敏度、转场时长及画质容差均在实施前按本方案的域契约裁定。

## 2. 观看语言与交互

v1.3从用户问题开始：FP帮助“这一杆怎样瞄准”，TP帮助“局面/这一杆/结果是什么”，2D帮助“平面位置与路线怎样”。进入、选球袋、切视角、转头、绕桌、进退、调参数、击球/回放、杆末/重打和2D往返的11类操作见[用户意图展开](CAMERA-VISUAL-COVERAGE-20261002.md#21-从用户操作展开设计)。默认常规任务应直接有合适构图；推近应让明确关注对象更清楚，退远应恢复上下文，绕桌应帮助读空间，过程观察应保关键事件。操作含义、主体锚点和切镜时机仍为具体建议，不把用户视角原则等同全部细则获批。

第三人称负责理解空间关系、观察球桌与击球过程。它不是任意飞行相机；用户只改变θ和s。近端允许局部观察与裁桌，远端在可行的viewport/HUD域内适配全桌。不能承诺近端仍看完整张桌，更不能把“入框”当“没有遮挡”。

第一人称负责杆轴、击球方向与透视观察。眼位由本次站位/杆轴上下文给出，左右滑只改变headYaw；母球、目标球、袋口、aim、power、spin和实际出杆方向不随转头改变。身体绕球移动是不同交互，不隐含在转头中。

| 输入/动作 | 第三人称建议 | 第一人称建议 |
|---|---|---|
| 左右滑 | 改θ，保留归一化s；不改观察中心 | 改headYaw，保留本次eyeAnchor与击球参数 |
| 上下滑 | 改s；s=0最近、s=1最远；上滑令s减小 | 首版无独立升降/进退；其语义仍待裁定 |
| 捏合，如保留 | 也只改s，不另改FOV或pivot | 首版不增加镜头自由度；需要时另行设计 |
| 选球/选袋/求解完成 | 更新训练内容，不夺回手动镜头 | 更新杆轴上下文，保留手动headYaw与owner |
| 切换3D模式 | 转向该模式的有效记忆或默认姿态 | 新杆上下文首次进入用杆轴基准；同上下文可恢复记忆 |
| 明确“回到瞄准” | 显式请求第一人称 | headYaw归零；只改相机 |
| 进入/退出2D | 暂停3D取景，恢复实际状态 | 同左；2D不是第三种3D镜头 |

横滑方向需要在投影坐标中确定“拖动场景”或“头转方向”的一致感受，不能凭世界轴符号脑定。手势轴锁尚未形成意图或delta为0时，不触发manual接管。球拖拽、瞄准与相机滑动须有独立命中/意图路由。

第一人称manual在同一观看上下文内冻结eyeAnchor与viewBase；训练baseAim更新只存业务事实，不旋转相机基准，因此保headYaw不会间接跟随新aim。选到新母球/新杆时旧entry标记失效，但不由后台自动搬站位；显式归正/重新进入第一人称才从最新杆轴重建eye/viewBase。重开等取消上下文的动作按新的generation与entry政策处理。固定旧眼位可能已不在新杆轴后方，必须承认此状态，不能同时声称它仍是新杆的瞄准机位。

是否允许headYaw非零时出杆、是否在显式出杆动作前可中断归正、哪些击球事件自动回到第三人称，是待裁定的观看政策。推荐避免选球时自动归正；首个兼容批次保留既有有效杆事件的时点语义，逐条移入新owner规则，而非顺手重写回放政策。

## 3. 固定算法轨道

### 3.1 坐标与参数

遵循项目坐标契约：SceneKit X–Z水平、Y向上，单位米；床面高度取接收资产与变换真源。θ=0朝+X，θ=π/2朝+Z；内部θ保持unwrapped，计算位置时周期化，避免跨±π倒转。UIKit竖向delta向下为正。

设台心为C、地板高度为Y_floor、推荐眼高H、水平单位方向d(θ)=(cosθ,0,sinθ)。定义连续且周期的近远边界r_n(θ)、r_f(θ)，必须满足0<r_n<r_f。建议使用对数退距：

```text
r(θ,s) = exp((1−s) log r_n(θ) + s log r_f(θ))
eye(θ,s) = (C.x + r cosθ, Y_floor + H, C.z + r sinθ)
orientation = lookAt(eye, C, worldUp)
projection = fixed FOV + current viewport/aspect/clip
∂r/∂s = r log(r_f/r_n) > 0
s = [log r − log r_n]/[log r_f − log r_n]
```

固定H/FOV/台心互相兼容，但俯角随r变化。若高度差为h，则俯角绝对值是atan2(h,r)。**世界眼高稳定不等于地板或桌沿在屏幕上的像素高度稳定。** 若要后者，需要另选构图规则并重新排序固定项；本方案不同时承诺固定俯角、固定屏幕桌沿与全域全桌适配。

对数r使相同s增量对应相同距离比例；它不是精确屏幕缩放因子。横滑保留s时，矩形桌/房间导致r随θ变化，但变化应连续；不承诺所有方位下桌面投影同大。若后续需要屏幕尺度恒定，仅增加有界一维反解，不进行每球形最佳机位全局搜索。

### 3.2 边界从场景语义生成

轨道profile依赖桌/房间资产版本、变换、镜头、眼高、viewport与HUD，不依赖每一组球的位置。相机安全需使用实际视觉几何/保守包络；不能拿物理球桌边界替代房间或库沿可见几何。

候选构造：近端用包住桌及相机安全间隙的连续椭圆边界；远端用安全房间内接的连续椭圆边界。椭圆半轴必须推导到真实包络，不能仅凭“半轴大于桌半宽”宣称包住矩形四角。远端全桌/HUD约束再与安全域相交；得到非空连续可达分量才发布profile。

若真实资产、HUD或特殊角度使这一保守构造无解，应降低该profile可达域或明确构图受限原因；不要插入不连续分支，也不暗改FOV/眼高。平滑边界仍须在合法域内，不得把对raw min/max的平滑当安全证明。有限角度采样只能发现反例，不能证明整圈安全。

安全优先级：数值有限/不穿桌墙是硬约束；选定的眼高/FOV/台心规则其次；完整全桌构图按远端可行域声明。不可行时提供受限状态，用户可绕桌、后退或选择2D；不强制切2D。入框后仍可能球挡球、库挡球，可用轻量可读性状态提示；是否加入显式“查看目标”是独立后续选择。

v1.2补强：上述受限机制仅说明失败处理，不证明观察能力。常规支持域的默认全局/本杆入口必须按任务adequate，允许操作完成的任务必须有reachable截图与路径；provenLimited单列未满足要求。主体可读优先于尚未批准的H/FOV/台心固定项；考虑显式冻结任务锚点等候选须重新裁定profile及渲染域，不悄悄加入自动跟球。

### 3.3 输入与转场

控制目标和实际进度均用θ/s表达；阻尼在参数域推进后重新求γ，不独立插值XYZ而切过安全边界。触端点时丢弃越界输入，反向立即响应，不保留隐藏累积。未触界的等量正反输入返回同一目标；实际平滑收敛后返回同一姿态。

模式切换起点可能不在轨道上。必须从实际姿态建立受约束connector，或保留实际pose直到进入有效轨道；不能投影到最近s/θ后立刻跳镜。connector需覆盖整个路径的安全与渲染域，两端合法不足以证明路径合法。姿态与roll用worldUp规则，近共线退化有确定处理。

本轮[数值草稿](../docs/research/20261002-render-engine/plan-geometry-arithmetic.json)和[轨道示意](../docs/research/20261002-render-engine/plan-rail-diagram.svg)只验证映射、可逆性与俯角关系。示意椭圆不是生产参数，也不是真实场景安全/舒适性证书。

## 4. 状态、所有权与同帧数据

mode、owner、运动阶段与显示空间分离。mode3D只有firstPerson/thirdPerson；owner只有automatic/manual；motion表达stable/transition/manualConnector；displaySpace为3D/2D，另存挂起快照。手势不能像当前beginManualOrbit那样清playerView以隐式取消第一人称。建议扩充现有CameraRig边界，避免引入与其并行写相机的第二控制器。

最小数据链：`CameraIntent → CameraRig实际推进 → CameraFrame → RenderFrameSnapshot`。CameraIntent有mode、θ/s/headYaw、上下文与目标；CameraFrame有实际view/projection及逆矩阵、eye/orientation/lens、viewport/clip、显示/曝光参数、时间与版本；RenderFrameSnapshot再绑定本帧球presentation、blocker、接收/灯/材质版本。draw、project/unproject、拾取、标签共用CameraFrame，不各自取目标姿态或旧SCNView矩阵。

| 变化 | 处理规则建议 |
|---|---|
| 手动接管/转场中接管 | 从实际pose接管，增加ownerEpoch，取消旧自动目标；mode保留；旧回调不能恢复控制 |
| 选球/选袋/aim更新 | 更新训练上下文；manual不被pendingCameraTarget、updateCuePose或recompute完成覆盖；基准杆轴与eyeAnchor/headYaw分开，必要重新站位由明确请求触发 |
| 明确模式/归正动作 | 创建新requestRevision，按当前上下文检查目标；过期请求拒绝 |
| 中途进入2D | 保存实际pose、mode、θ/s/headYaw、owner、上下文及版本；推荐退出恢复可见状态，不继续过期自动转场；目标以实际值重置 |
| 2D期间球/杆上下文改变 | 原记忆不能机械恢复；采用新上下文的安全默认/显式动作，拒绝旧杆事件 |
| resize/HUD改变 | 更新viewport/profile revision；manual先保实际pose/FOV，合法时从实际r反解新s，不机械保旧s造成跳镜；不合法时接受改善方向/显式复位，安全已失效则经验证退避；automatic可重新规划。FP保world eye/headYaw，报告裁剪，不承诺全主体适配 |
| 暂停/取消/重打/离页 | 以sceneGeneration与shotID隔离回调；暂停有效时钟，清理旧请求；GPU完成只回收资源 |
| capture/settlement自动请求 | 只在该杆、该generation且automatic拥有镜头时有效；manual保留；每个事件只消费一次 |
| 背压跳帧跨多个事件 | 逻辑事件仍按有效时间和稳定ID消费；镜头请求合并为最后有效终态；settlement取代同区间capture，避免补播过期中间转镜 |
| seek/快进 | 重建该时点观看状态，抑制已过镜头动画；不向前补播全部切镜；manual在有效上下文内仍保留 |

事件合并/seek是推荐政策，不宣称现有代码已如此。取消或重打先更新generation；同区间旧事件随后全部无效。显示唤醒、仿真、回放和相机转场各有时钟映射；GPU完成不能成为转镜时钟。球/相机推进各一次，掉draw不等于丢逻辑事件。

版本分开：requestRevision/ownerEpoch、actualCameraRevision、presentationRevision、blockerRevision、receiver/rig/layout/algorithm及资源版本。球自转只改变presentation；相机动只改camera和精度需求，不能误作遮挡内容变化。

现有独立姿态写入者必须明确迁移：SCNTransaction模式切换、CameraRig手势、显示回调、母球屏幕锚定、捏合pivot及击球回切。新第三人称不能在γ之后再平移pivot来锁母球；2D和旧页面可各按其政策，但同一host只有一个提交者。

## 5. 渲染算法与相机的配合

### 5.1 世界遮挡联合场：第一切片

对于接收点p、灯样本j与球i，保留当前软影公式：`V_j(p)=Π_i(1−a_i b_ij(p))`。V依赖球位置/高度/opacity、接收chart与灯，不依赖相机或球自转。屏幕外球仍会遮灯，不能从blocker列表删掉。

先在唯一交互session上生成单份持久R32场，blocker变化时完整生成有界床面域；不变时复用。首版保64方向，不直接平均visibility；E保解析矩形照度校准与原epsilon，S保逐sample的visibility×BRDF。far8、AO、非床面接收、球R与纹理/曝光链沿原路径。TaiNi材质不能无条件等同平面床面，库顶/袋口/台下需真实receiver语义。

256×128×64逻辑值8MiB，带collar约8.38MiB，仅容量示例；格距约9.92mm，而当前中心球样本过滤足迹约1.45–3.21mm，不能宣称分辨率够用。cell区间包络/解析梯度界给重建证书，四角差分不是证明；未知或误差超预算的cell用当前公式。

内容有效与精度合格分别判断。相机靠近、微法线LOD或低掠射会改变响应/footprint精度需求，而不使V内容过期。表示不足时退原公式，不能抬镜头、禁近景或减观看能力。

### 5.2 减少方向积分：主要后续收益

第一切片仍保64次BRDF，不能把它说成完整“大幅优化”。随后在实际法线锥满足所有n·l≥0的域内，用方向矩M=ΣqV·l和M0=Σq·l替代漫反射求和；保解析校准与epsilon。条件不成立的域继续原式。

镜面优先研究候选A：`S=S0+Σ_j w_j(V_j−1)BRDF_j`。先求无遮挡响应S0，再只修正受遮挡方向J；J稀疏时减少工作，但J最坏64。S0用LTC/拟合是近似，不等于当前离散64/8精确积分；遗漏近1修正、mask与空间误差分别计账。

候选B是完整可见光角系数场：C_m=ΣqVφ_m，片元用实际n/v/roughness构造核系数并收缩。只有所需rank L显著小于64、投影和旋转成本受控时成立；不预定9项足够。**轨道参数二维不代表BRDF二维**：世界接收点、微法线、roughness、第一人称站位及转场中间姿态仍在拟合域内。

按角核误差和工作账本比较A/B适用域；高频、近景、低掠射或J密集域保原式。具体容差须冻结后再放行，不把专项报告中的p95/max候选数值自动变成批准的外观变化。

### 5.3 成本与可证伪条件

令P为near片元数、N为场texel数、K=64、b为候选球数、u为本帧blocker变化标记。原球检测约PKb；场新增约uNKb及写入/证书，片元仍有PK读取、BRDF、AO和support工作。后续A响应约P·J加S0；B约P·L加核转换，compute还增加NKL投影。所有式子是工作量模型，不是瓦数。

开球u频繁为1、N接近P、少球b小、证书大量无效、近景影区细或J/rank接近64时，缓存/压缩可能净增工作。每种情况都有明确撤销/原式出口；不存在“限定两种视角即可最低能耗”的结论。引擎选择目前是分阶段SceneKit＋受控Metal候选，性能赢家未证明。

### 5.4 GPU预算与真实同步

新增GPU总峰值≤16MiB，包含field/collar/certificate、输入在途slots、metadata、工作资源、active/retired及替换。按actual allocatedSize准入，不按逻辑payload计数；不是每session各16MiB。旧新共存超额则当前帧原式，旧资源异步退役后再准备；不CPU wait，不覆盖在途buffer，不用旧球场配新球。

宿主候选为公开SCNRenderer commandBuffer入口：`update(atTime:)`推进一次，最终动画/约束就绪后freeze，encode field，再用不推进动画的`render(withViewport:commandBuffer:passDescriptor:)`，present/commit。不能随后又调用render(atTime:)双推进。最低iOS17的可用性与同步条件见[既有证据](../docs/research/20261002-render-engine/ARCHITECTURE-PROPOSAL.md)。

tracked且真实direct绑定、同queue才可依赖相应hazard tracking；高层material texture property不证明内部消费边界。无法证明时使用覆盖实际consumer的GPU event/可控绑定方案；仍无法成立则当前公式。compute/draw同帧快照由唯一owner封存，期间不await重入。输入slot满时跳draw而保逻辑推进，不能阻塞主线程或丢事件。

## 6. 静态资源、页面与媒体

首片保现有probe及球R；R已有反射预积分，不能重复记为新收益。后续规范canonical静态捕获，其key含资产/房间/rig、接收、捕获原点/姿态/曝光、shader/预过滤及材质政策；不以首次用户相机状态决定资源。s/θ/headYaw通常不进入静态room probe内容键，反射采样方向仍随实际CameraFrame。

不同session/queue的动态场不共享。首版导出继续当前路径；逐出口适配时采用固定导出时钟update→freeze→field→render，不在snapshot中异步补场。共享只读静态资源也必须完整key匹配。其他训练页不能在未完成owner/投影/拾取迁移时自动启用新host。

## 7. 实施批次与职责

本表是可执行拆分，不自动开始实施。沿用当前会话继承配置，不假称Cursor专有模型可调用；主控负责独立验收，专项文件独占写入，实施如需并行再按真实依赖划分。

| 批次 | 负责人/所需能力 | 变化边界、出口与退路 |
|---|---|---|
| W0 契约裁定 | 主控＋相机架构＋反方；产品状态、几何 | 裁定第8节；冻结profile/owner/误差接口，不将推荐当已批准；本轮文档已形成 |
| W1 轨道与相机状态 | 相机架构；Swift/SceneKit、连续几何、状态机 | CameraRig的纯轨道profile、θ/s/headYaw及实际帧；证明/数值检查周期、单调、逆解、安全域与接管；旧路径可按场景配置回退 |
| W2 交互/生命周期接入 | iOS交互＋状态审查；手势、VM、回放语义 | 仅每日清台：mode保持、选球不夺权、2D/resize、事件合并和投影/拾取一致；清除该host重复姿态写入者；不改击球解算 |
| W3 世界场切片 | 渲染算法＋帧调度；Metal、shader、GPU同步 | 在W1/2提供真实帧与唯一owner后接床面R32/full generation/certificate；同帧、预算、原式出口成立；先不角压缩、全页铺开或导出迁移 |
| W4 响应压缩 | 光照算法＋独立反方；BRDF、误差界、复杂度 | 冻结两模式/转场域后推导条件方向矩，比较S0＋J和角基底；质量/成本不成立的域撤销；不以改变镜头掩盖失败 |
| W5 资源及出口迁移 | 场景资源/媒体架构；缓存版本、固定时钟 | 独立处理canonical，逐页/导出适配；保六袋/回球/非床面；每出口有旧路径 |
| W6 实施后放行 | 主控＋QA/设备性能；图像、帧调度、能量 | 契约/公式/边界正确性→画质→全页面性能与能量；比较实际热和帧表现再作引擎决策；不把本轮分析变设备基线任务 |

每批DoD按[验收标准第7节](TWO-VIEW-CAMERA-RENDER-ACCEPTANCE-20261002.md#7-覆盖矩阵与批次放行)映射到C/S/R/P编号，逐项留证；文档完成不代表实现或设备放行。W3不是省略W4的替代品，W4也不能跳过W3的真实同步与误差边界。

## 8. 需要裁定的少量产品选择

| 选择 | 推荐与理由 | 尚未定的内容 |
|---|---|---|
| 第三人称构图 | 固定世界眼高/FOV/台心，pitch随退距；更少耦合、可逆 | 地板像素稳定是否比上述固定项更优先；H/FOV/近远端/profile |
| 手势方向与缩放 | 上滑近、下滑远；pinch同s；θ绕桌 | 横滑视觉方向、gain、边界反馈；FP竖滑是否需要 |
| 第一人称横滑 | 固定眼位headYaw，保持击球参数 | 头转范围、是否pitch；归正/出杆政策 |
| 自动转镜 | manual优先，显式动作授权接管；旧有效杆事件迁入owner规则 | capture/settlement到底何时切，是否保留既有时点/时长 |
| 质量与推广 | 两模式近景/转场同纳入误差域，先每日清台 | 线性E/S与最终外观容差、viewport/HUD支持域、其他页面顺序 |

这些选择可以在审阅本方案后逐项收口。拒绝某项推荐只改变对应profile或观看政策；不会否定世界球影与观看响应分离的算法方向。

## 9. 本轮证据与状态

- v1.1补充：[验收契约](TWO-VIEW-CAMERA-RENDER-ACCEPTANCE-20261002.md)、[验收标准独立审查](../docs/research/20261002-render-engine/ACCEPTANCE-REVIEW.md)、[文档检查](../docs/research/20261002-render-engine/acceptance-verification.json)。30项实现验收全部未验证，数值建议待冻结。

- [相机/状态专项](../docs/research/20261002-render-engine/PLAN-CAMERA-STATE.md)、[渲染专项](../docs/research/20261002-render-engine/PLAN-RENDER-COUPLING.md)、[独立反方](../docs/research/20261002-render-engine/PLAN-REVIEW.md)。
- [现有联合契约](../docs/research/20261002-render-engine/CAMERA-RENDER-CONTRACT.md)与[架构推导](../docs/research/20261002-render-engine/ARCHITECTURE-PROPOSAL.md)为支持材料；本计划中的未裁定项保持未裁定。
- 当前拥有行为的主要源：CameraRig、AngleSceneView、AngleTrainingScene、PositionPlayViewModel、CueStroke；材质源MobileReferenceLighting/MobileTableRendering；导出源SequenceVideoExporter。具体行证据见专项报告。
- [源码快照](../docs/research/20261002-render-engine/plan-source-hashes.json)、[方案检查结果](../docs/research/20261002-render-engine/plan-verification.json)只证明本轮源码边界、文档与推导检查，不证明性能/设备体验。

完成状态：方案撰写、独立理论审查与资料整理；下一步是裁定第8节并选定W1/W2实施范围。未宣称最好画质、最低瓦数或真机60fps。
