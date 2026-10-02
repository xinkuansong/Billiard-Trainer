# 两视角相机的观看范围分析

2026-10-02；专项架构复核。仅分析当前代码、方案和已经生成的历史原图；未构建、运行设备或生成新截图。本报告提出推荐，不把眼高/FOV、取景中心、切镜时机或具体数值当作用户已经批准。

**结论：两种3D模式可以保留，但“固定世界眼高＋固定FOV＋朝固定台心的轨道”应先作为普通TP的候选，不应先成为所有观看任务的硬限制。** 用户要求各种情形观察范围合适；若长台、贴库或真实袋口在允许轨道内无法看清，必须调整构图政策，再看实际页面比较效果。仅提示受限、继续退远或建议切2D，都不能把该3D任务算作成功。

## 1. 先定义看什么，再定义固定什么

“必见”指执行该任务时当前画面应可读；“可操作到达”指通过有限、明确操作可到达合适画面，不能拿它替代关键事件发生时的必见；“可牺牲”指允许暂时出框的上下文。以下为推荐验收口径，须由产品裁定。

| 观看任务 | 必见 | 可操作到达 | 可牺牲 |
|---|---|---|---|
| FP沿杆瞄准 | 母球、杆头/接触关系、当前目标球与瞄准方向；两球轮廓和接触点有可读尺寸 | 转头读真实目标袋、必要库段；回杆轴姿态 | 非相关球、其他五袋、完整桌框 |
| FP转头观察 | 当前转向主体；朝向变化不改变母/目标/袋或冻结击球方向 | 左右可达袋口与周边；显式归正 | 原杆轴画面可暂时离屏；不要求一次看完整长台 |
| TP整桌上下文 | 桌面边界、六个真实袋位、各在台球的大体位置；不等于每个号码同时可读 | 绕桌分辨被球/库挡住的局部；接近辨号码和接触 | 房间装饰、桌腿和球杆后半段；不能牺牲某袋并仍称完整全桌 |
| TP当前一杆工作近景 | 母/目标球轮廓、选定真实袋口及必要线路端点；贴库时库边/接触关系 | 进退与绕桌使关键主体可读，袋口检查可与厚薄检查分次完成 | 无关远库、其他球、其他五袋、完整桌框 |
| TP击球/回放 | 已确定的关键运动主体及碰撞/入袋结果在事件窗口可辨；镜头不能到事件后才就位 | 暂停/seek后细看，能力需实际提供 | 非关键运动球的细节；开球全盘动态另列，不能承诺所有球同时清楚 |
| 2D读全盘 | 完整有效台面、六袋、在台球位置与关系、当前选择/路线；无遮挡的二维关系阅读 | 允许的放大/平移用于局部，并有明确全盘恢复 | 房间透视、杆后真实视差；不代替失败的3D袋口/贴库观察 |

FP“目标袋必见于初始同一帧”与“明确转头可看袋”是两个政策，不能互换。本报告推荐允许分次观察，但历史用户要求能看目标袋；若转头仍不可达，则FP袋口任务失败。号码最小尺寸、可见轮廓比例、关键线路哪些段必见尚未冻结，不能用球心入框代替。

## 2. 已打开的历史原图与能支持的结论

这些图片均为旧相机实现，**不代表新轨道已经生成、通过或优于旧实现**。全页面图含原生HUD；离屏图没有原生HUD，分开使用。工具显示可能旋转/缩放，数值采用旁文件而非显示图猜像素。

| 实际目视证据 | 本轮观察 | 不可推出 |
|---|---|---|
| [标准工作观察](/Users/song/projects/13.billiard_trainer/build/daily-camera-formations-20261001/final/formation-1-standard.png)＋[退远](/Users/song/projects/13.billiard_trainer/build/daily-camera-formations-20261001/final/formation-1-far.png)，2026-10-01，全页面 | 中央两球和选定角袋清楚；前景与侧边桌框被裁。退远仍是工作近景，另一球仍在下边界外 | “远端”不自动等于全桌；两球可读不证明各球可读 |
| [第一人称](/Users/song/projects/13.billiard_trainer/build/daily-pocket-camera-20261001/focused/camera-first-person.png)，全页面 | 母球/目标球、杆轴关系集中清楚；目标袋不像中央两球一样明确，右侧HUD/边缘需独立核对 | 橙色线路朝袋方向不证明真实袋嘴可读；固定眼位yaw可否解决待具体轨道图 |
| [第三人称](/Users/song/projects/13.billiard_trainer/build/daily-pocket-camera-20261001/focused/camera-third-person.png)，全页面 | 两球、线路与远部上下文可见；近端桌边被裁 | 按钮叫第三人称不证明承担全桌任务 |
| [旧全局35°](/Users/song/projects/13.billiard_trainer/build/daily-camera-20261001-r2/after/overview-angle-35.png)，全页面 | 整桌外框/六个袋位在画幅内；近端角袋和右侧区域邻近或叠入仪表/按钮区域 | 包围框入屏不证明六袋均避开HUD；35°不是新方案默认 |
| [第三球遮挡反例](/Users/song/projects/13.billiard_trainer/build/daily-camera-coverage-audit-20261001/third-ball-occlusion.png)，真实模型离屏 | 整桌能入图，前景第三球仍遮住目标球一部分轮廓 | 没有HUD，不可用于原生页面安全区通过；遮挡不由放大FOV自动消除 |
| [2D全页面](/Users/song/projects/13.billiard_trainer/build/control-metal-20261001/ui/enabled-2d.png)，2026-10-01 | 台面/六袋和两球位置完整；左右仪表分布在桌外，上部反馈文字仍覆盖台内 | 不能代表密集开球、spin面板、分屏/字号/所有设备2D都清楚 |

[标准旁文件](/Users/song/projects/13.billiard_trainer/build/daily-camera-formations-20261001/final/formation-1-standard.txt)记录874×402视口、FOV35.7037°、眼高1.7m；[退远旁文件](/Users/song/projects/13.billiard_trainer/build/daily-camera-formations-20261001/final/formation-1-far.txt)同FOV但眼高1.8307104m，某球中心Y436.15超过402。故这组旧图不能证明固定世界眼高的新进退效果。

历史[FL-094 r3/r4/r5/r6](/Users/song/projects/13.billiard_trainer/tasks/FAILURE-LOG.md:869)分别揭示：静帧通过但手势失败；用户否决整套改版；袋口/杆穿越/手动状态不足；投影样本不保证实体与生命周期覆盖。新的大矩阵数量不能抵消任一实际用途失败。

[覆盖审计](/Users/song/projects/13.billiard_trainer/tasks/DAILY-CAMERA-COVERAGE-AUDIT-20261001.md:9)的3072是1024布局×3比例，原生页面14独立球形。第三球反例43.864%是440条有效目标轮廓射线的命中比例，**不是实际图像被挡像素比例**。7.34～32.03pt为历史近似投影直径，也没有获得“最小仍清楚”的用户批准。

## 3. 代码揭示的画幅、镜头与包络契约

| 证据 | 对新方案的约束 |
|---|---|
| [CameraRig.dailyFOV](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/CameraRig.swift:137)由aspect、26/56°水平限额、18/40°上限生成FOV | 当前镜头随画幅改变，不是跨设备一个常数；不得把旧图不同配置视为固定镜头比较 |
| [SCNCamera SDK](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks/SceneKit.framework/Headers/SCNCamera.h:49)说明projectionDirection默认vertical；[setupCamera](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/AngleTrainingScene.swift:681)未显式设置轴 | 新profile显式声明.vertical，CameraFrame保存实际投影；固定VFOV时HFOV=2atan(aspect·tan(VFOV/2))，画幅改变必然改变横向范围 |
| [wholeTableOrbit](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/CameraRig.swift:998)用外框角点与球半径高度拟合距离；1028–1031限房间后扩大FOV | 旧逻辑能换镜头求入框，不证明新固定FOV轨道在房间内有解。角点球半径包络也不代表完整库顶、袋嘴、杆或实际遮挡 |
| [tableScreenScale](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/CameraRig.swift:1061)为裁剪前投影包围框最大跨度 | 相同scale不保证相同画面覆盖、中心位置、可读面积或HUD净空；不能继续把共同scale当“观察范围相同” |
| [roomSafeDailyRadius](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/CameraRig.swift:1467)使用8×6m房间安全范围 | 只约束眼到边界，不证明相机体积、家具/桌库/杆和转场安全；新包络应来自实际资产变换，不能只读注释当几何证书 |
| [dailyLandscapeBody](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PositionPlay/Views/FreePlayView.swift:1274)3D全屏ignoresSafeArea，2D位于中央stage；顶栏44与两侧60列为覆盖结构 | 中央stage尺寸不是3D渲染viewport。HUD坐标必须转换到真实3D drawable；用sceneSize算3D aspect会改变错误的镜头 |
| [近景/spin/反馈](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PositionPlay/Views/FreePlayView.swift:1292)位于独立叠层；[相机按钮](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PositionPlay/Views/FreePlayView.swift:1477)播放/计算时禁用 | HUD随状态变；当前不能以“播放时点另一模式就能看”补关键事件不可见。是否开放回放镜头操作必须明定 |
| [2D投影](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/CameraRig.swift:1392)正交、顶视并有旋转适配 | 2D承担全盘有合理几何基础；仍须检验实际stage、HUD、scale与平移恢复，不由正交名称自动通过 |

稳定世界眼高只保证eye.y不变，朝台心看时俯角仍随距离变化；屏幕地面/桌沿位置不会自动稳定。若用户要屏幕地面稳定，需要额外构图约束，它与同时保持台心注视可能冲突。应通过对照图选择，而非把两种“稳定”混用。

## 4. 固定轨道何时不能保证任务

定义允许眼位/姿态集合D={γ(θ,s), s∈[0,1]}及实际镜头；每项任务需要在D内存在满足主体入框、可读尺寸、HUD净空和任务相关无遮挡的姿态。整桌远端若要求任意θ都可读，则比“存在一个合适θ”更强。必须明确采用哪一项。

1. **长台/纵向跨度：**近端台心构图把非中心一杆置于侧缘；为同时包住母球、远目标和袋退远会缩小目标球。固定FOV时可能不存在同时满足入框和最小球尺寸的距离，有限房间又限制最远点。二维投影中心或两球连线不是足够判据。
2. **贴库/贴袋：**世界眼高固定仍可能在某方位沿库顶掠射；真实库边、皮革、袋口内壁挡住母球接触处/袋嘴。后退只改变透视，不保证越过遮挡。FP固定眼位转头只换方向，不改变实体遮挡关系；库挡住的目标不能靠headYaw露出来。
3. **六袋：**外框角点拟合不能保证袋嘴表面可读。近端袋容易被库顶遮住或落到左右仪表；远袋嘴变得扁小。TP全桌应至少明确六袋位置；需要查看某袋实际开口时，应允许进退/绕桌达到，而非承诺六袋嘴同时无遮挡。
4. **拥挤球形：**球堆存在多个互遮，某个球轮廓可被另一球遮住，而两段理想击球通道仍空。任何单机位“所有球同时无遮挡”均不应成为承诺；可达姿态与实际可辨的关键主体才是任务指标。
5. **画幅/HUD变化：**固定VFOV在更窄横向画幅可能丢端点；在另一画幅即使入屏也可能压住新增HUD。整条θ轨道若穿过无构图解区域，只做各角度clamp会产生跳变/不可逆进退；有限角采样不能证明全路径安全。
6. **动态过程：**入袋前后或反弹关键点可能分布在工作近景之外。拍摄“球进袋后的终态”不能证明入袋过程可读；相机要在关键窗口前完成合理构图。默认追踪每颗球则增加运动、状态与求解复杂度，不能未经政策设计就添加。

## 5. 有效viewport不是一个中央矩形

令Ω为真实drawable矩形扣除当前HUD视觉遮罩后的可读域。遮罩由顶栏、球库、方向/力度仪表、圆形击球按钮、相机按钮、反馈/近景/spin叠层的实际形状构成；按实际定位、圆角/圆形和状态映射，可为非矩形、带孔区域。

- 可交互命中区域与视觉遮挡分开。透明容器不应整块扣除；半透明仪表后的袋口也不能因alpha<1就认为可读。必要文字/刻度、对比干扰和主体安全padding采用任务规则。
- 判球轮廓/号码区、真实袋嘴包络及必要线路段与Ω的关系，不能只判球心或袋标记中心在中央65%。接近HUD时也需保证手指操作不会持续遮住工作主体；此项最终用原生触控观察。
- Θ/s合法域、投影镜头与HUD版本一起生成。尺寸/字号/spin/反馈变化可使此前构图失效；实际相机先保持连续，再进入明确的调整/受限状态，不能静默重算目标夺回manual。
- CameraFrame保存actual view/projection、viewport、HUD layout revision；标签/投影/取景评价消费同帧。相机构图变化不意味着阴影场V需要重算，但近景精度要重新判断。

## 6. 最小调整候选与推荐顺序

先保持用户明确的两模式、TP上下进退、两模式横滑。以下不是同时实施的要求，也不增加第三个3D模式；每次只改最小一个自由条件，用同场景实际图比较。

| 顺序 | 候选 | 能解决/不能解决 | 连续性与产品边界 |
|---|---|---|---|
| A | 修正真实drawable/HUD域；适度重排挡住袋口的已有控件 | 不改变镜头即减少画面遮挡；不能解决真实球/库遮挡或长台视角不足 | HUD策略需设计确认，不能为了相机静默删关键控件 |
| B | 以有限房间内的全桌远端为TP基础profile，明确近端承担工作近景；重新选H/FOV常数 | 可改进总体覆盖，不保证工作主体够大或所有θ都可行 | 用实际矩形桌、袋嘴、可见球包络，不用无限rFar；θ/s连续，s=0近/1远保持 |
| C | 当前一杆显式“工作构图”请求，允许有界look-at/构图偏移，普通轨道仍以台心为基准 | 固定眼高/FOV下把偏中心一杆移入净空区；不能消除同眼位实体遮挡 | 推荐优先尝试此项；在entry/显式归正时锁定，不随选袋/球位噪声自动追中心，不另开自由pitch控制 |
| D | 若C仍失败，提供少量有界任务profile，对眼高或FOV择一做有限调整 | 适度抬眼改善库挡/袋嘴，有限lens改善跨度；各有透视/尺寸代价 | 新增profile参数是修订候选，不冒称固定H/FOV；同profile进退仍稳定眼高，跨profile用安全连续connector |
| E | FP明确进入/归正时选择有界entry站位/眼高，随后固定眼位headYaw；必要袋口检查交TP工作画面 | 站位可改善杆/库净空，headYaw让侧向主体到画面内；转头本身不改善实体遮挡 | 两模式保持；不自动随aim移动FP。若FP任务定义要求该袋可达却做不到，先改entry/profile，不记通过 |

**优先建议：A→B→C，再视真实图决定是否需要D/E。** 固定台心通常比固定眼高更容易先放宽，且不新增手势轴；但C不能用一杆最优搜索取代普通轨道。若工作构图必须频繁变中心、镜头重站或s反解失效，说明这项候选不适配，回到有限profile或重新定义轨道；不以追踪补丁层层叠加。

最强反例是“固定H/FOV/台心在所有冻结任务与真实HUD图中已经足够”：那就保留三项固定，不引入C/D/E。另一反例是球堆导致任一允许眼位都不能同时分离关键球：此时组合看图/转头/绕桌分次观察可以诚实表达，但不能伪称同帧无遮挡或把2D当作3D通过证据。

## 7. 方案验收应增加的实际图像判定

当前[主方案](/Users/song/projects/13.billiard_trainer/tasks/TWO-VIEW-CAMERA-RENDER-PLAN-20261002.md)与[验收C05/C06](/Users/song/projects/13.billiard_trainer/tasks/TWO-VIEW-CAMERA-RENDER-ACCEPTANCE-20261002.md:41)已有声明可行域与受限机制。用户此次强调实际截图，应把“任务能否完成”补成独立门槛；受限结果正确不能代替观看能力通过。**本轮不执行下列新截图/测试，这是实施后的证据计划。**

| 代表情形 | 必留原生页面图/过程 | 具体看什么 |
|---|---|---|
| 长台直球、对角跨度、偏台端一杆 | FP初始/向袋转头；TP近、中、远，同球形比较A/B/C候选 | 两球够大、袋嘴可读、端点无HUD截断；不靠缩小全部主体通过 |
| 母球贴长库/短库、角袋与中袋邻近 | 真实杆姿下FP归正与转头；TP两侧可达工作图 | 库/杆是否遮住接触关系，袋嘴而非图标是否可读 |
| 六袋逐袋、球簇/反例第三球 | TP全桌远端＋逐袋工作视角；球堆分次观察图 | 六袋位置与被遮关系；关键球轮廓能否到达清楚姿态 |
| 回放碰撞/反弹/进袋/开球 | 同一关键时刻前中后的连续原帧和转场片段 | 球与镜头同clock，关键事件没有离框/晚切；终态图不能代替过程 |
| 横屏窄/宽、iPad/分屏、2D期间resize、HUD叠层 | 相同任务实际页面，恢复与中途接管端点图 | Ω、镜头轴、真实viewport一致；没有漂移、跳镜或恢复丢袋 |
| 2D全盘与局部恢复 | 稀疏/密集、反馈/spin打开、放大返回全盘 | 台内位置和六袋可读，标记不遮关键关系，2D能力独立通过 |

每图记录commit/资产/profile、实际pose/lens/viewport/HUD状态、球/袋/shot与时间；原图＋关键ROI放大，使用同布局前后对照。效果由实际图/交互和用户观察裁定；数学安全、日志、截图和手感分别记账。当前所有新轨道覆盖结论仍为未验证，不能把历史局部通过回填新方案。
