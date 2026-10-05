> **最新状态：桌参照轨道 v1.5 开发候选已实现（FL-099）**。新版62核心回归通过，6原生UI用例分别复验通过，46原图主控逐张实看；完整阶段和生产替换未放行。新版证据见§8及UR-20261002-table-rail-camera；§1–7保留被打回候选的历史，不用于新版验收。

# 两视角相机：每日清台桌参照轨道 v1.5

日期：2026-10-02。状态：v1.5桌参照轨道开发切片完成，新版证据见§8；完整W1/W2未放行。§1–7保留v0.1/v0.2历史及失败记录。用户授权先保存现有代码到GitHub，再开始实施。

## 1. 已保存的基线与实施范围

基线提交 `712c3b3adb6ac545ad483e18bd149b55c9f4f4c5` 已推送 `origin/main`，远端refs核对一致。126个代码、资源与文档文件入库；`tmp/`和忽略构建产物保留本地。基线Debug构建、gate、doc-size通过；这次保存不是全产品验收或发布。

候选只由每日清台DEBUG参数 `-dailyClearance.twoViewCamera` 启用。普通启动、其它交互宿主、视频导出继续原相机路径。实施中的代码尚未提交；同工作区其它会话的变更不属于本候选。

先把相机观看状态与训练事实隔离，建立可审查的实页交互，再推进世界球影/角响应的渲染改造。当前没有修改材质公式、物理内核或求解器，不计GPU/能耗收益。

## 2. 工作配置（候选，不代表所有政策已获用户确认）

| 项目 | v0.1采用值与来源 | 适用边界 |
|---|---|---|
| 世界坐标 | 米制，X/Z台面，Y向上；真实运行时桌外框，8×6m房间 | 房间墙内代理边界X±3.65/Z±2.65，不能等同家具/connector安全证书 |
| TP轨道 | 固定世界眼高=台呢Y+0.90m；极坐标椭圆远端、对数进度s=0近/1远 | 0.90m仅为基础下界；本杆近端按冻结两球AABB、眼高/镜头、创建时HUD/viewport求各方位可行下界；尚未完成全域mesh安全证明 |
| TP关注点 | 全桌复位取台心；明确本杆入口取两球实体与真实袋嘴包络中心，并冻结profile | 这是对“固定台心”推荐的工作替代；不会因滑动/捏合悄悄换中心，效果须逐任务验收 |
| TP入口进度（最新源码） | 先比较当前方位、72个方位和两球连线两侧方位：优先两球近似投影圆盘分开，再最大化较小球投影尺度；按完整任务（含袋嘴）可行半径选入口 | 仅explicit entry；manual/模式记忆不重选。有限候选/投影代理不证明全局最优、真实无遮挡或精读能力 |
| TP镜头 | profile创建时按实际viewport、中央HUD可读区域及720个远端方位采样选择固定垂直FOV；最大100°为拒绝构造的临时上界 | 不是连续构图/无遮挡证明；不因手势自动变焦。宽镜头畸变与主体尺度仍待核验 |
| TP输入 | 上滑靠近、下滑后退；s增量dy/500；pinch同s；横滑0.0025rad/pt | 候选手感，真机未确认；斜滑双轴，不复用旧轴锁/取球pivot |
| FP入口（返修） | 保原杆轴eyeXZ，以当前实际table子树segment检查4个接触/下缘ROI，必要时抬眼；眼高候选上界台呢+1.8m，球包络/HUD拟合固定entry镜头（≤70°） | 有限ROI不等于全可见轮廓；眼高搜索无全域单调/最小证明，极端无解页面政策未闭合；用户未确认姿态/镜头舒适度 |
| FP输入 | 固定实际entry眼位，横滑仅headYaw，限±72°；竖滑/pinch无动作 | entry继续消费实际杆轴/抬角；转头不改aim/power/spin/选球袋 |
| 转场 | 实际pose起点，位置插值与quaternion slerp，五次平滑；普通entry沿用0.95s（减弱动态0.1s） | 目前没有冻结全路径vMax/ωMax，也未证明转场不穿实体 |
| 复位与记忆 | 同观看上下文FP↔TP恢复各自实际机位；重复已选FP明确归正；全桌复位明确重建全桌TP并选可读入口 | 切入记忆仍走实际pose connector。新杆/取消/回放及母球重新摆放使旧entry记忆失效，不后台搬动当前manual眼位 |
| 2D往返 | 保存实际pose、mode、owner与控制状态；回来冻结该实际pose到下一有效输入 | 当前投影空间切换直接完成，没有宣称平滑3D/2D转场；上下文改变后的观察用途要重新审查 |
| layout/HUD | 从实际中央stage窗口rect换算SCNView insets；resize保实际eye/FOV、owner及创建时railViewport/railInsets，独立更新新布局有效性 | 四边矩形不代表中央打点盘/动态特写完整遮挡mask；固定镜头新布局可能无法装下原主体 |

GPU峰值16MiB与研究验收表的性能/误差建议没有因相机候选改变。世界眼高稳定不等于屏幕地板位置固定。

## 3. 实施内容与所有权

- `TwoViewCamera`分开mode、owner、手势目标与实际pose；零/无效输入不能夺权，边界不积累隐藏输入；连续手势不重启connector。模式记忆保存实际帧，2D恢复不继续兑现旧目标。
- `CameraRig`把新路径的实际transform/FOV提交收口；新路径禁用母球屏幕锚定、旧pinch改pivot和旧orbit更新。其它宿主仍走原控制器。
- `PositionPlayViewModel`在新路径不再由选球/预测完成自动进入TP；杆姿数据更新不重建manual FP。进袋与停稳相机请求校验本杆generation及相机requestRevision，manual优先。
- 上一杆回放的延迟运杆、触球和终态completion增加generation校验，防止取消后旧回调落入替代杆；没有改轨迹物理结果。
- 每日候选显示FP/TP两个mode与单独“全桌复位”动作；真实UIKit输入与实际presentation pose诊断用于审查。2D仍是显示空间切换。

## 4. 实际检查与尝试记录

| 尝试/证据 | 实际结果 | 能证明什么 |
|---|---|---|
| `build/camera-two-view-20261002/baseline-build.log`、`baseline-push.log` | 基线构建与推送成功 | 基线可追溯，不是新候选验收 |
| `core-tests.log`首轮编译 | 测试代码Float.pi类型歧义，修正后13项通过 | 留存失败；轨道/输入7项＋原相机6项 |
| `ui-first.xcresult` | 3项原生UI通过；6附件存在横屏App-local裁切/黑边 | 功能子证据保留，**图像无效，不用于视觉PASS** |
| `ui-screen.xcresult`、`screenshots-screen/manifest.json` | 改完整屏幕采集后3项通过，6张完整实页图主控已审 | 仅selection球形的全桌、本杆TP/近推/斜拖/2D恢复、FP/头转 |
| `core-final.log` | 16项中1个精确quaternion归正断言失败，差约2e−8 | endpoint/零头角存在不必要重构；未放宽断言，改为精确采用端点/base |
| `core-repaired.log` | 新核心10项＋旧相机6项，16项0失败 | 新增模式记忆、上下文失效、manual layout与snapshot恢复子证据 |
| 同次额外旧播放selector | 类名选择错误，执行0项 | 不计通过；改为真正测试类重跑 |
| [`final-host.log`](/Users/song/projects/13.billiard_trainer/build/camera-two-view-20261002/final-host.log)、`final-host.xcresult` | 5项legacy core通过（进袋时序4＋scratch生命周期1）；5项UI通过，0失败；分别结束于12:55/12:57 | UI覆盖实际姿态记忆/重复FP归正、长台/近库/大切角、头转不移眼位、TP斜拖与2D恢复、两命名视角与全桌复位；不是全部核心/视觉门槛 |
| [`screenshots-host/manifest.json`](/Users/song/projects/13.billiard_trainer/build/camera-two-view-20261002/screenshots-host/manifest.json) | 17张完整屏幕原图；其中球形反例由主控目视审查 | 采集方式有效，仍发现TP主体尺度与FP真实库体遮挡反例，不能据UI通过勾选视觉PASS |
| [`final-repair.log`](/Users/song/projects/13.billiard_trainer/build/camera-two-view-20261002/final-repair.log)、`final-repair.xcresult` | 12项新core＋6项旧X1＋5项legacy＝23项core通过；5项UI通过，0失败；分别结束于13:01/13:04 | 两项独立复审P1的定向核心用例已通过，旧相机/进袋/回放回归通过；本轮最新图像审查与完整阶段验收待回填 |
| `final-repair`之后的源码 | 新core第13项`testTaskEntryUsesReadableSubjectEnvelopeInsteadOfUnconditionallyRetreatingToRoomBoundary`及TP`entryProgress`已加入；FP一般几何策略由主控修订中 | 当时未验证，随后visual-repair-r3独立构建/运行；不可倒推上一轮已包含这些更改 |

补充：`visual-repair.log`编译因SCNNode segment options为String字典失败；r2因SIMD组合表达式type-check失败。保留两次失败，修正API键及拆分表达式后，`visual-repair-r3.log`/结果包成功：15新核心＋32旧相机＋4进袋＋1scratch＝52核心，5原生UI，0失败。

最终[视觉审查](ui-reviews/UR-20261002-two-view-camera.md)与`build/camera-two-view-20261002/implementation-verification.json`已落盘；后者保存本地未提交源码SHA-256与实际测试归属。`screenshots-final/manifest.json`含17新候选整屏图＋1旧路径离屏图，后者不计新候选；[原图查看页](/Users/song/projects/13.billiard_trainer/output/camera-two-view-20261002/index.html)复制字节/哈希一致，17图主控全部实看。测试成功与视觉能力分列，不合并勾选38项。

### 已知失败与修复状态

| 问题 | 状态与证据 | 尚不能推出的结论 |
|---|---|---|
| 首轮App-local附件裁切/黑边 | 已更换`XCUIScreen.main.screenshot()`；6张screen与17张host完整图可用 | 采集修复不等于构图通过 |
| 精确quaternion端点重构误差 | 已采用精确端点/base；`core-repaired`16项通过 | 不代替随后新状态与新几何复验 |
| 独立复审P1：观看上下文失效后旧connector继续兑现旧目标 | 已修；`final-repair`中`testNewContextCancelsOldConnectorAndHoldsActualPose`通过 | 定向用例不覆盖全部异步生命周期、连续路径安全 |
| 独立复审P1：FP记忆在connector中间恢复实际eye后，head turn又回到旧base eye | 已修；`final-repair`中`testRestoredManualFirstPersonMidConnectorAcceptsHeadTurnWithoutMovingVisibleEye`通过 | 不证明所有布局、上下文与转场组合均闭合 |
| `final-host`长台/近库/大切角3个TP场景球太小 | 主控目视确认；entryProgress已在r3复验并实看，台面增大，但远侧母球仍小；FL-098保持开放 | 包络入框仍可能主体太小、HUD遮挡或实体遮挡，当前不标已修 |
| `final-host` FP fixture 3/13真实库体遮住母球下缘 | 主控目视确认；真实table视线入口已在r3复验/实看，接触区明显改善；fixture3最低轮廓仍紧邻库沿，完整ROI不计PASS | 不能把真实遮挡当离屏，也不能用投影点入框证明下缘可见；当前不标已修 |

## 5. 阶段门槛与下一步

W1/W2尚未放行：C05/C09的连续mesh/connector安全与速度界缺证；C06无解/真实遮挡的页面状态还未闭合；C10的布局失效退避与变化上下文恢复、V01–V08完整球形/六袋/各设备/浮层/生命周期/真机手感仍未完成。FP/TP记忆的有限子证据不等于完整C10。

世界球影场、FrameSnapshot同帧draw/拾取契约、Metal资源slots与角响应方法还未实施，S04之后及R/P验收保持UNVERIFIED。当前SceneKit承载路径没有转为新引擎，也未建立“大幅优化/最低能耗”结论。

下一步继续闭合TP远侧主体尺度、近推关注对象与FP近库完整可读区域的实际反例，再补安全/布局/生命周期覆盖；候选达到W2门槛前保留DEBUG入口。后续W3计算域切片沿已定方法推进，不重复启动与当前改动无关的设备基线。

## 6. v0.1历史复验与完整ID状态（最新证据见§7）

- 最新构建/检查：`visual-repair-r3.xcresult`及同名log。实际15新核心、32旧相机、4legacy进袋、1scratch，52项0失败；原生UI5项0失败。旧相机32项未启用candidate，仅作为旧路径回归，不宣称新路径覆盖其全部夹具。
- 实际设备：iOS26.3，08FC41A5-57EA-4262-847B-5B297CF101EB，横屏874×402pt；新原图17张，selection、fixture0/3/13、头转、近推/斜滑、2D、双mode记忆/归正。真机/iPad/小屏与完整浮层没有复验。
- 独立复审：旧context/mid-connector FP P1修复保留；新FP坐标/yaw/单一entry求解无新的必修P1。有限ROI、eyeY单调性、全部HUD/无解页面与连续路径安全仍缺。
- 源码归属/哈希：`implementation-verification.json`；未提交工作区，基线仍712c3b3a。当前没有再次push候选。
- 最终gate FAIL0/WARN0、doc-size（PROGRESS99KB/10行，hub48KB/10行）、diff --check通过；后续仅补事实文档，无新代码更改。

| 完整ID | 状态 | 当前证据与缺口 |
|---|---|---|
| C01–C04/C07–C08、S01–S03 | UNVERIFIED（有局部通过） | 输入/实际pose/记忆及source one-writer、legacy播放回归；尚非完整业务异步/手感/采样全部域 |
| C05–C06/C09–C11 | UNVERIFIED | 连续真实实体/connector安全、速度界、无解页面、resize退避及真机动作未闭合 |
| V02 | FAIL（本次常规TP精读域） | 原图远侧母球仍偏小；FP接触改善不证明完整ROI |
| V01/V03–V08 | UNVERIFIED（有局部图像） | 近推母球出画，关注意图未冻结；六袋/全部球形/动态事件/各设备/HUD/转场序列缺证 |
| S04–S06、R01–R08、P01–P05 | UNVERIFIED | 世界影场、CameraFrame同帧draw/拾取与Metal依赖尚未实施，未测新性能/能耗 |

表按完整验收层列，不将本轮函数/设备子证据冒充完整PASS。38项实际清单以验收契约为准；W1/W2未放行，W3–W6未开始。

## 7. v0.2：任务入口与两球近端（本轮）

### 从观看任务修订算法

- 工作TP入口冻结两球球体AABB为近推的保护对象；目标袋嘴参与默认本杆构图，近推没有承诺袋嘴始终入框。全桌复位仍以台心/全桌包络构造，不新增第三种mode。
- 入口优先能分开两球近似投影轮廓的方向，再比较较小球的近似投影直径；两球连线两侧是通用解析候选，另比较72方位和当前方向。只在明确进入时选一次，不运行后台镜头搜索。投影圆盘不是实体遮挡证书。
- 固定高度/镜头下，近端由视锥不等式推导：上下边是二次式的外分支，水平深度在导数非负分支求边界，再取各点下界最大值。12pt为构图留白候选，不是视觉可读阈值；负判别式保二次式顶点，避免直接归零造成边界跳变。数学域详见几何复审§10。
- 轨道使用创建时viewport/insets；resize只校验当前布局。无可行运动时保持实际pose并撤销该请求，不能用已不合法的far代替安全结果；转场中的hold必须从实际中间pose重新接管。页面受限反馈仍待完整C06闭合。
- 母球自由球移动、普通拖球、微调的真实位移使旧entry/FP/TP记忆失效；同一失效任务的后续delta不重复换revision。当前manual眼位保持；下次明确本杆入口才用新球形重建。正在运动的球不因此由后台重新选镜。
- 稳定控制状态的update直接返回，不重复求近端；建profile/操作期间算法仍有计算成本。本轮没有能耗测量，不将这一局部避免重复计算换算为全App收益。

### 尝试与证据

`build/camera-two-view-20261002-r2/framing.xcresult`：54核心中1个布局冻结用例失败，5UI通过；原因是只冻结insets，viewport仍参与轨道重算。`framing-repaired.xcresult`：56核心中新增摆球用例出现3条断言失败，5UI通过；测试误用了CanvasPoint.y=0.6（合法域[0,0.5]），触发钳制/边界拒绝。改为合法球形，没有放宽断言或更改球物理。两次失败保留。

本轮补拍同源fixture0/3/13与新覆盖4（近长库）/8（中袋）/12（贴球）的FP、TP默认、TP近端；原生整屏图与功能断言继续分列。最终证据如下，中间批次不代替最终源码证据。

目前完整W1/W2、38项与渲染R/P仍未放行。两球同框并不能保证用户能精读接触侧；长台/大跨度场景在固定H/FOV且保两球的前提下，近推余量可能很小，不能靠丢母球制造放大效果。本轮未修改正式默认、资产、物理或渲染材质。


### 最终复验与原图审查

- 最新源码对应 `build/camera-two-view-20261002-r2/hold-final.log` / `hold-final.xcresult`：21新核心＋32旧相机＋4旧进袋时序＋1scratch＝58核心、5原生UI，全部0失败。旧相机32项关闭candidate，只证明旧路径回归。此前 `framing-final` 为57核心＋5UI通过；独立复审发现转场中无解hold再接管可能跳回理想轨道，修复实际pose重建connector及requestRevision后新增第21项复验，保留全部尝试。
- 同一隔离设备08FC41A5-57EA-4262-847B-5B297CF101EB、iOS26.3，横屏874×402pt；最终29张 `XCUIScreen.main` 原生整屏图，主控全部逐张实看。原图保留2622×1206内容与EXIF方向，复制SHA-256一致。[前后对照与29图](/Users/song/projects/13.billiard_trainer/output/camera-two-view-20261002-r2/index.html)、[来源/哈希](/Users/song/projects/13.billiard_trainer/output/camera-two-view-20261002-r2/screenshots.json)。
- TP六种球形默认入口与近推均保留完整两球；贴球默认入口两轮廓分开，旧斜滑/2D往返的母球出画反例本帧已消除。长台主体较v0.1均衡，但精读尺度仍不足；默认与近端差异很小，不据此判V02/V03通过。FP近短库、近长库及大切角下缘仍紧邻/局部受真实库体遮挡，保持U-01开放。模式记忆前后图与实际pose断言一致，全桌复位帧六袋可辨；非本杆球仍可能被HUD遮挡，完整V07不放行。
- 项目gate FAIL0/WARN0；最终doc-size通过（PROGRESS99KB/10条、hub48KB/10条），git diff --check通过；源码哈希见 `build/camera-two-view-20261002-r2/implementation-verification.json`。基线HEAD仍712c3b3a；候选未提交、未再次push、未转正。

下一切片先解决观看任务冲突：远隔两球的关系总览与局部精读不能由同一个固定锚点近推同时保证；需在现有TP mode内明确用户局部关注及保留参照的政策，再解决FP完整接触轮廓。连续真实实体安全、全部HUD/生命周期、真机手感与完整38项仍缺；渲染R/P没有新实现或能耗收益结论。


## 8. v1.5 桌参照轨道实施与复验（本轮）

撤销§2/§7的球形profile与固定眼高策略。新入口只消费实际桌中心、桌外框、房间安全边界及viewport/HUD；θ为眼位方位，镜头水平朝向独立派生。近端同时靠近、降低、放平；后退恢复全桌观察。FP仍沿杆入口与固定眼位转头，TP记忆不再随shot context丢失。真实选球/袋/自由瞄准变化清FP旧记忆但保TP；layout变化保持实际pose，下一有效TP输入重建创建域并从实际pose重接。

首版配置55°镜头、96周期C1缓存节点、近端距桌外框工作余量0.40m/眼高台面+0.38m，远端最高世界Y3.25m；这些是候选配置，未证明家具/库网格及connector的连续安全。上方历史v0.2测试不用于新版。

| 新版尝试 | 实际结果与处理 |
|---|---|
| `build/table-rail-camera-20261002/core-first.log/.xcresult` | 62核心执行，61通过、1失败。失败为新增VM测试错误地把重复选球→重新推荐袋→手选原袋当no-op；真实意图已变化。已按真实同袋点击与重新推荐两条义务修测试，未放宽TP保持/FP失效断言，待回跑。 |
| `ui-first.log/.xcresult` | 1原生序列未完成，真实手势转θ0停在约0.02493rad，未达0.01误差。UIKit识别前行程未传给相机；测试helper改为从实际θ变化测量遗漏行程，再补偿下一手势，保原误差。不是改变生产灵敏度。 |
| `screenshots-first`原生失败录屏与`first-far-native-frame.png` | 原帧确认far最低眼高策略把台面压扁、空地多；独立实际HUD数值草稿也显示短端纵深不足。正在把far由room半径/最低H改成联合r/h/pitch构图目标；未把全桌入框记作舒服。 |

### 最终算法与实际行为

far用距离/眼高/俯角联合构图：八个外桌上表面包络角落需落实际HUD可读区内，同时软偏好35°俯角与台布投影面积占可读区25%。后者按台布四边形实际面积计算，不用外接框代替；均为候选偏好，没有承诺所有方位恰好25%。25个半径×9个俯角及一次3×3细化只在profile创建时求解；96周期C1节点缓存，手势/帧更新插值并校验，不逐帧搜索最优机位。水平gaze基于连续台面参照与HUD派生，平滑限制±12°，不以某个角/袋argmin选焦点。

首次TP与「全桌复位」进度s=1；普通模式切换恢复自己实际机位。上滑减s，靠近/降眼/放平；下滑加s，后退/升眼/俯看。横滑改θ，同一profile派生r/h/pitch/gaze。选球、选袋、真实摆球、自由瞄准清除过期FP记忆，保留TP桌机位；重新进入TP不会因为本杆变了重选视线。布局变化先hold实际机位，下一有效输入重建并从实际pose接回；零/无效输入不抢所有权。

### 最终验证与来源

| 批次 | 实际结果 |
|---|---|
| `core-joint.log/.xcresult` | 62核心0失败，联合构图算法；首次入口当时s=.72，不代表最终入口已验。 |
| `ui-joint.log/.xcresult` | 新连续轨道原生UI 1项0失败，17整屏原图；主控与独立QA全部实看。原生录屏`table-rail-joint-native.mp4`保留，显式全桌复位后轨道与最终一致；不是最终首次入口证据。 |
| `final-host.log/.xcresult` | 最终生产源码62核心0失败（25新轨道＋32旧相机＋4进袋＋1scratch），6UI中5通过、1失败，综合包状态TEST FAILED保留。失败在FP明确复位测试把实际heading与SceneKit EulerY混比；此前实际mode往返姿态断言已通过。 |
| `memory-repaired.log/.xcresult` | 仅统一上述测试三处读取为实际heading，原误差/姿态/意图断言不变，生产源码无改动；独立build后受影响UI 1项0失败。其余5项不重复计数。最终6个不同UI用例各有通过记录，不宣称单个综合包全绿。 |

原设备08FC41A5-57EA-4262-847B-5B297CF101EB / iOS26.3 / 横屏874×402pt。最终查看页选取`final-host`的41图与`memory-repaired`的5图，46张均主控逐张实看；独立QA另审17连续图与18球形图，TP未见本切片必修P1。复制原PNG字节/EXIF及SHA-256一致；旧路径离屏图、失败memory旧4图、SpringBoard截屏均保留但不计46候选图。

[原图查看页](/Users/song/projects/13.billiard_trainer/output/table-rail-camera-20261002/index.html)、[来源与哈希](/Users/song/projects/13.billiard_trainer/output/table-rail-camera-20261002/screenshots.json)、[逐组判定](ui-reviews/UR-20261002-table-rail-camera.md)。676个源码文件的`source-final-tests.json`与复验后清单仅UI测试文件不同；生产源码哈希一致，`implementation-verification.json`记录测试分批归属。

实际短库far：Y2.585m/俯角35°/r2.704m；near：Y1.180m/俯角6.78°/r2.147m。near绕至长库约11.92°；长库far为Y2.321m/35°/r2.056m，斜向far为Y2.155m/35°/r2.395m。不是把同一个far世界高度强加所有方位。近端15°→90°序列台心投影在HUD可读宽度约50%→52.63%→50%，这只衡量台心投影点，不是台面面积重心；全过程原姿态见`native-sequence-actual.json`。

### 视觉边界与下一步

六种球形TP首次远端及短/长/斜far六袋/外桌完整，near有明显低位靠近感，允许桌角、部分预测线落HUD或出画；fixture13 near黄球下缘受前库边部分遮挡、fixture12并球轮廓相贴，不能宣称所有近景对象无遮挡。FP3/4/13母球最低轮廓仍被库体切去一部分，保留FL-098。TP本方向完成不关闭整个相机视觉返工，FL-099等待用户实际舒适度及完整门槛。

有限384θ×5s preflight、核心采样、原生截图序列均不构成连续真实mesh/connector安全、速度界、所有HUD/生命周期、iPad/小屏/真机手感证书。完整38项及W1/W2未放行；世界影场/帧快照/角响应与渲染R/P未实施。本轮不改shader/资产/物理，不计GPU或能耗收益；候选仍只在每日DEBUG参数启用，尚未提交或再次push。

收尾检查：`gate-final.log` FAIL0/WARN0；`doc-size-final.log`通过（PROGRESS100KB/10条、Hub49KB/10条）；`git diff --check`通过。仅打开本地原图查看页供审阅，并在上述隔离模拟器启动DEBUG候选；其它会话的cover/CueStroke/开球研究及设备不动。用户可试上滑靠近、下滑退远、横滑绕桌、全桌复位及FP转头；正式默认未替换。

### 真机试用安装（2026-10-03）

用户授权“装手机上”。通过`make build-device-profile`在隔离`build/table-rail-camera-device-20261003/`构建Debug/-O，真实输出BUILD SUCCEEDED；安装到连接的iPhone16Pro（com.xinkuan.qiuji，1.0.0/1）成功。携带`-deeplink.dailyClearance -dailyClearance.twoViewCamera`前台启动，PID9238，随后设备进程清单确认仍在运行。未卸载、未清数据、未注入测试球形。每日入口默认2D，用户点3D试新TP/FP；开关仅本次启动参数生效，结束进程后普通图标重启不保证保持候选。构建前后8个关键源文件哈希无漂移。证据：build.log、install.json、launch.json、processes.json、source-build.json；初次启动参数解析和进程URL过滤尝试失败留在执行记录，修正后成功。本次只证明构建/安装/启动，不新增视觉、手感、能耗或完整验收结论。

10-03 02:43用户再次要求重装：增量真机构建BUILD SUCCEEDED，覆盖安装与携带相同候选参数启动成功，PID9960随后复核在运行；证据保存在`build/table-rail-camera-device-20261003/reinstall/`。未清数据或改实现，体验待用户试用。

## 9. 2026-10-03 DR-348 v2 临时观察语言

范围：按用户10-03实际试用反馈和[方案§0](TWO-VIEW-CAMERA-RENDER-PLAN-20261002.md)替换候选交互。上轮只交付图标预览，未接入本轮交互；本轮主控实现rig/VM/host与临时俯视呈现，engines负责ShotRailProfile/核心回归，pipeline负责图标/长按/页面，review负责真实UI输入与独立状态复核。三个子智能体共享工作区、分文件写入、主控串行构建，未改物理或材质。

### 9.1 实现约束

SceneKit XZ水平/Y上/米；台呢高度取实际scene。标准沿杆眼位复用dailyPlayerPose的1.65m/至少+0.90m；不复用旧全桌profile默认。ShotRailProfile按context、实际两球/袋嘴、杆姿、viewport/HUD创建并缓存72方位C1样本；有界联合r/H/pitch求解在创建时运行，持续输入不做全域搜索。近端保护当前任务ROI并降眼/放平。退远不强制全桌，工作目标为较小球≥基准80%，HUD裁剪台呢面积≥max(基准80%,min(基准,35%))；无可行远端明确motionLimited，不假装端点冻结满足观察需求。

主轴判定12pt/1.25、整手势锁定；持触停止输入仍保持实际姿态，释放取当前杆默认 .95s连接（减少动态效果 .1s），回程触摸由actual反解接管。FP左右同样临时转头并回当前杆轴。长按原生UIControl 250ms启动，短点无效；实际正交相机screen-up=杆向，HUD不对称余量联合拟合桌外框，不走周转轨道。room/ground可见性按快照恢复，持久cameraMode与击球意图不变。

### 9.2 验证记录（进行中）

首次构建在ShotRailProfile的SIMD/Float长表达式出现Swift类型推导失败，未执行用例；engines拆式/显式类型后重建。失败原日志 `build/temporary-shot-camera-20261003/core-test.log` / `core.xcresult` 保留。重建、UI持触录屏、原图与真机安装结果随后逐项填入，不复用旧版绿灯。

首轮原生UI：6条中5通过/1失败，实际selection退远位移约0，scenario0/4为LIMITED；失败归FL-100，不回填通过。主控与独立review实看四球形TP/FP默认、三图标与LP返回等12附件原图及15校准录屏帧；确认图标/LP持触高亮及松手3D恢复，既有FP近库下缘/袋口可读性仍开放。取帧首次错误选择Press后的注入前idle，第二次受录像整秒metadata与首帧偏移抽晚；错误衍生帧隔离在before-touch-extraction/late-extraction，原视频/xcresult不动，正确帧依据序列和实际高亮状态复核；不作精确触控时延证据。

FL-100修复：真实数学草稿证明单固定gaze/35°姿态在selection有不可行域；far改默认近域r/H细采、完整合法俯角候选、±15°有界构图朝向及局部细化，增加抬高/偏转代价，θ仍不变，默认沿杆机位与80%球/台呢护栏保持。新5-shot核心回归覆盖selection/0/3/4/13实际XYZ移动与尺度，不以progress代替。最终生产源码核心69项初跑68通过/1测试边界失败：候选允许眼高=基准+.05m，而旧断言写严格>，改为>=且保持下限，无生产修改；相关类再验。最终原生6项包重跑中；首次失败及修复包均保留。


### 9.3 v2最终定向记录（后续v2.1覆盖临时俯视）

核心69项初跑68通过/1测试边界失败，改测试严格>为允许边界>=后TwoView32全部通过，生产代码不变，因此69唯一相关核心项在两个包中全部通过；不宣称单个69绿包。最终原生6项全部通过，紧凑iPhoneSE3 iOS26.3.1另2项通过。verify-gate、doc-size、diff通过；iPhone16Pro Debug/-O最终签名构建、严格codesign、覆盖安装和带候选参数启动成功，PID10352由进程清单复核。build/temporary-shot-camera-20261003与build/temporary-shot-camera-device-20261003保存成功与失败日志。

独立review实际逐张看15最终保持帧＋36标准原生附件，共51图；确认四球形实际退远、回沿杆与两模式LP释放恢复。旧FP3/4/13母球下缘实体遮挡仍在，3/4目标袋顶部边界仍在，部分临时观察HUD/球袋舒适度边界仍需用户体验；未测手机能耗或证明连续域安全。该LP是黑底、杆向up版本，用户后续否决其呈现方式，不能用于v2.1叠层PASS。

## 10. DR-348 v2.1 旧站位适配＋推荐TP＋透明俯视叠层

用户已确认开始。职责：engines独占CameraRig与TwoView核心测试；pipeline独占AngleSceneView/AngleTrainingScene叠层；review独占原生UI测试；主控独占VM推荐请求、FreePlay诊断参数、RecommendedShotCameraTests与文档。构建与设备串行由主控执行。新要求真源为方案§0/ADR-P18-07。

根因：makeShotRail未传目标袋绕过旧dailyObservationPose缩距/镜头适配，并把垂直FOV固定55°；自动推荐只换业务目标，没有新版明确的选球相机事件；旧临时俯视改主camera并hide room，导致黑底且桌朝向随杆任意斜转。

修订：恢复旧站位/主体lens适配但保沿杆yaw；推荐有效求解后一次TP（功率/打点普通重算不触发），检查target/pocket/context及用户取消；独立克隆正交快照、桌外透明、原3D保持，标准双朝向/HUD最大fit。一次snapshot或layout重建，持有不重复离屏draw。正在构建/截图验证，未宣称v2.1完成。

基准图：output/temporary-shot-camera-20261003/final/held/10、11（旧黑底），默认四球形及退远原图同目录；新证据将存build/shot-camera-overlay-20261003与output/shot-camera-overlay-20261003。

首轮记录：device Debug/-O BUILD SUCCEEDED，但未安装；core首次重复MainActor测试标注编译失败（0项），修正后r2实际76项/1方法4断言失败，纯相机fixture缺FP视线查询hook，补齐并增加FP模式断言后r3实际76项全部通过，生产源码不变。原生首轮8项4通过/4失败，后者均在初始化strikeEnabled等待失败，未进入透明叠层或推荐场景；独立复审确认FL-101：晚到HUD布局同步取消初始自动TP connector，而VM busy未结束，实际镜头停旧pose。正在修复默认入口续接与取消回调，再执行新生产包，旧76绿包不放行修后生产。失败原录屏、xcresult/AX与导出附件全部保留；原Runtime列表名26.3，xcresult实际版本26.3.1/23D8133，以结果元数据为准。

FL-101修后core-r4实际79项全部通过（TwoView39+推荐3+旧32+进袋4+scratch1）。原生ui-r2实际8项6过2失败：首次加载、四球形TP/FP/真实退远、分轴与真实杆末推荐均通过；力度输入1.50→1.57实际改变，但静止FP的DEBUG AX求解计数没刷新，补诊断变化时单次force采样（不唤醒持续绘制）；长按在SCNNode.clone触发PocketLeatherMarker初始化SIGTRAP，归FL-102，用基础SCNNode冻结渲染树替换动态clone。真实桌复制回归初次已不崩溃，但42个世界矩阵bitwise相等断言失败，正用独立逐元素1e-5上限输出实际误差后复验；其余源不变/层级断言保留。该包37原生PNG+13保持录屏帧共50张由独立review全部实看，无新增TP视觉P1；LP只beforehold，不计叠层通过。四球形实际退远眼高增量+.223/+.368/+.152/+.199m；FP3/4/13下缘/部分袋口旧边界保留。当前手机仍显示unavailable，已请求连接，尚未安装v2.1。

复制回归r2仍1项42失败，实际max=0.99999994，已证明不是舍入误差；全为未渲染fixture新加袋口presentation世界矩阵仍identity。fixture先真实SCNRenderer呈现并严格前置核对model/presentation后，r3实际1项通过，复制逐元素最大误差0，源变换/材质不变断言仍在，生产复制算法不改。核心相关80唯一项分别通过（79＋复制1），不宣称单一80包。focused原生手选/力度项通过，LP首次真实透明图已生成但诊断bbox Y反向断言失败；独立SCNRenderer底左像素坐标现映射为UIKit顶左，取景/image零改，正在复跑原断言。首张LP原始PNG角alpha=0、alpha0像素1345406；原生合成和四邻帧经独立review确认大桌六袋/HUD内、底下3D房间保留及释放还原。仅0/TP首样例，不代替完整LP/小屏验收。

LP-r2首TP持有及释放所有断言通过（main matrix/FOV delta0，room可见，一次snapshot无resident renderer，window bbox fit）。随后静止→FP转场15秒失败，FL-103：FreePlay activity漏VM cameraTransitionBusy且connector尚未写node，无渲染事件唤醒。仅候选把busy纳入activity，原callback false恢复idle；原native LP方法断言全部保留并完整重跑r3。

定向收尾：完整LP-r3标准1/0（4holds），SE最终icon＋LP 2/0（4holds）；main矩阵/FOV差0、room保留、每次hold1snapshot/no resident renderer、原actual/shot intent恢复与两短库±X方向全过。独立review标准16有效PNG＋12邻帧、SE17PNG＋8邻帧全实看，无新增视觉P1；原误抽前触帧REJECTED与旧raw01不计有效证据。8张原透明PNG四角alpha0均数值验证；旧FP与袋口透出下层物件边界保留，报告UR-20261003-shot-camera-overlay。最终device Debug/-O BUILD SUCCEEDED、严格codesign通过，source-final与最终native/SE/device消费一致；实际覆盖安装CoreDevice1011失败，设备仍unavailable，无新PID/真机体验结论。

最后activity唤醒修正后的手选/力度与真实击球杆末推荐同包ui-recommendation-final实际2/0，target2本杆TP/default与FP力度不抢镜原断言通过。该包新增原生截图保存在recommendation-final-attachments，不用早期before图代替新消费。

2026-10-03 08:34 无线复装：用户指定局域网。devicectl details确认manualPairing/paired，但tunnelState unavailable、DDI不可用；按已有hostname重连返回CoreDevice4000，按已识别UDID安装仍1011；Bonjour开发服务未发现在线设备。最终包严格codesign再次通过，未重编译/卸载/清数据/冒充启动；已请求同Wi-Fi解锁亮屏，待连接恢复。输出wireless-device-info.json、wireless-reconnect.log、install-wireless.log及wireless-devices-final.json在原build证据目录。

2026-10-03 08:40 有线复装成功：设备实时transportType=wired、tunnelState=connected、DDI可用。最终v2.1签名包覆盖安装成功（bundle com.xinkuan.qiuji，安装实例E6C5CFDA-22B9-429D-9131-DB647220A454），带每日清台/候选参数启动，PID10990由实际进程清单复核；保留用户数据，无fixture/reset/premium参数。证据install-wired.json/log、launch-wired.json/log、processes-wired.json/log与wired-device-info.json。此前无线失败历史保留；手机手感待用户体验，不视为能耗/视觉全矩阵通过。
