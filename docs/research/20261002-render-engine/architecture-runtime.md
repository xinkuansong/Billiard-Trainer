# 渲染运行时结构：帧所有权、失效依赖与台呢遮挡计算域

日期：2026-10-02。独立首轮；读取当前 owning source 和本机 SDK，未读取其他新架构报告。只写本文；未改生产代码、增加依赖、构建或运行设备。遵循本项目 iOS 架构角色，最低 iOS 17，物理契约不变。

**建议先实现一个范围明确的新候选：只把明确的平面台呢接收面的逐光样本球遮挡，移到内容版本失效的世界空间场；首版 blockerRevision 变化时有界全场生成，不变则复用，第二阶段再加局部 tile；保留每个样本的 visibility、原逐球乘积、原微法线/视角 BRDF 和例外接收面的原路径。以帧快照和受控 SceneKit 提交保证场与球同帧。** 这比先替换整个引擎或全面替换 SCNAction 的工作面更小。其结构收益是把重复的光线—球几何查询，从每个可见像素转换为世界网格点；快照、时钟、协议拆分本身不构成主要 GPU 收益。空间采样仍引入近似，64 通道场也有带宽成本，本文不会把复杂度比称为 FPS 或能耗倍数。

## 1. 当前事实与真正的耦合

以下行号均来自 2026-10-02 当前源码。MobileReferenceLighting、MobileTableRendering、AngleSceneView、AngleTrainingScene、CameraRig、RoomReflectionProbe、PrefilteredReflection、SequenceVideoExporter 与前轮 baseline-source 逐文件比较相同；TrajectoryPlayback、BreakFlowRunner 直接读取当前文件。

| 当前事实 | 源码 | 架构含义 |
|---|---|---|
| SwiftUI 更新调用球桌/台呢/球贴/球杆样式与房间安装 | `QiuJi/Core/Scene/AngleSceneView.swift:179–219` | 这是调用入口耦合，不能说每次都重烘焙；各样式已有 guard。新增设计应传播明确的变化，而非清空一切缓存 |
| 每次 setupScene 都 setupTable/camera/light，并创建 contactOcclusion、装材料/房间，随后再应用 requested table/cloth | `AngleTrainingScene.swift:208–258` | 业务 scene 重建会重新安装静态呈现部分；房间捕获发生在本次 requested 外观应用之前。应从已解析的最终静态描述建立资源，不能把顺序当缓存键 |
| 同房间 style 的 installReferenceRoom 直接返回 | `AngleTrainingScene.swift:953–979` | 相机移动没有在这里导致 probe 重新烘焙；问题是其他影响捕获的输入没有进入键/失效图 |
| 主线程 DisplayLink 用系统 timestamp 差推进 CameraRig；SceneKit 另一个呈现阶段应用球的 actions | `AngleSceneView.swift:539–590`；`TrajectoryPlayback.swift:473–550` | 两套更新相位。当前并不等于已经发现掉帧根因，但计算场不能从主线程旧球位产生，再与渲染线程新球位显示 |
| 接触数据在 didApplyAnimations 读取 presentation.position/opacity，并按组比较 | `MobileTableRendering.swift:238–277` | 相位有重要语义；不可改为动画前读 model node。已有不可变 Data 批量上传与无变化 return，不能重复包装为新优化 |
| FrameDelegate 用 NSLock 保护 counter、contact 引用及合并的 idle 通知 | `AngleSceneView.swift:1124–1177` | 锁没有把整个 SCNNode 树或 resource 内容变成线程安全；不能据此任意后台修改场景 |
| 已有 activity、暂停 DisplayLink、SCNView.isPlaying、rendersContinuously=false、热状态帧率策略 | `AngleSceneView.swift:369–425` | 停绘已有。新方案应保留，并把 pending resource completion 纳入一次性 invalidation，而非再发明无条件循环 |
| CameraRig 已按输入/实际 transform 检查跳过冗余写入 | `CameraRig.swift:1514–1542` | “相机 transform 写缓存”已有；相机移动仍会触发当前台呢 fragment 中整套遮挡计算 |
| 台呢 p 来自 contactWorld，visibility 对每个 light sample 逐球相乘；微法线和相机参与加权 diffuse/specular | `MobileReferenceLighting.swift:379–455,869–905` | visibility 的几何函数与 view 无关，BRDF 不无关；可以移动前者，不能预平均 visibility 后替换全部积分 |
| 每像素已有球 support/mask；R 使用反射预滤波，已有原型与公式重排 | `MobileReferenceLighting.swift:372–455,918–961` | 新结构须在当前 R 上增加，不能把 mask、prefilter、constant 台呢 debug prototype 或已存在公式提取当新工作 |
| probe 以 RoomStyle 缓存，miss 在锁外 bake，捕获时改 live scene 可见性并创建相机，六面+地板 snapshot | `RoomReflectionProbe.swift:285–365` | 相同键并发 miss 可能重复准备；捕获内容实际上还依赖桌体/外观/灯/坐标/算法。不是任意 scene rebuild 都必须重算，也不是只按房间名就足够 |
| prefilter/program/LUT 缓存已有；首次 GPU 准备有 commit/waitUntilCompleted | `PrefilteredReflection.swift:17–76`；`RoomReflectionProbe.swift:183–203` | 这是资源准备路径，不是每帧工作。去阻塞主要改善准备/切换，不能作为台呢逐像素 GPU 大收益的解释 |
| BreakFlowRunner 给每个 node 运行 playback.action，另以 Task.sleep 收尾 | `BreakFlowRunner.swift:355–387` | 暂停/取消/速率发生变化时，墙钟收尾与实际播放时刻可能分离；先统一呈现完成条件，保留物理自然静止与袋/回球尾段 |
| 导出用 motionFrame×frameSimDt 手动取 stateAt、逐步积分球旋转，另有 snapshot.clock 自增 | `SequenceVideoExporter.swift:583–658,752,1091–1096` | 多时钟有明确映射，但映射散落。应把 timeline time、simulation time、presentation tail time 写入同一取样上下文，不能只把几个 Double 改同名 |

**可以现在判定的错误依赖**：台呢每帧 fragment 的遮挡几何查询与相机帧更新绑在一起，即使球与灯完全不变仍重算；probe 键缺失实际捕获输入；静态资源安装与业务 scene 重建共用生命周期；输出时钟、模拟时钟和呈现尾段的换算不集中。**不能据此判定**：当前发生了多少次重复 bake、CPU 锁争用、GPU wait 占多少时间或某时钟已经产生用户可见错误。

## 2. 拟建模块及狭窄边界

保留 `AngleTrainingScene`、SceneKit assets、现有视觉 actions 与独立物理。拟增 `QiuJi/Core/Rendering/`，先是 app 内目录，不引入新 SPM/第三方引擎。

| 模块/文件 | 职责与禁止越界 |
|---|---|
| `RenderClock.swift` | 唯一推进与取样上下文；live/export 各有独立 session，共享换算规则，不共享墙钟起点 |
| `RenderFrameSnapshot.swift` | 不含 SCNNode/SCNMaterial 的帧值；从同一相位采集，供遮挡场、着色绑定、HUD 与出口使用 |
| `SceneKitPresentationAdapter.swift` | 暂保留 action/presentation 采样与 SceneKit 节点身份映射；后续逐消费者提取共享呈现 sampler |
| `LightingDependencyGraph.swift` | 内容版本、空间脏区域与资源 key；不以 frameID 或业务 view 重建作为全量失效原因 |
| `RenderAssetCatalog.swift` | 静态几何/最终材质/room/receiver 语义描述，以及 immutable 资源句柄；不保存游戏状态 |
| `BedVisibilityField.swift` | 固定灯样本、平面接收面的逐样本 visibility；管理 support、脏 tile、采样布局与例外 fallback |
| `RenderResourceStore.swift` | preparing/resident/failed/retired、single-flight、device 隔离、GPU 使用完毕回收；不后台写 SCNNode |
| `SceneKitRenderBackend.swift` | 接收 prepared frame，更新/渲染顺序、buffer/property 绑定、输出 attachment；不推断物理/训练业务 |

建议协议草案（不是本轮实现或已验证 API）：

```swift
protocol RenderClockSource { func sample() -> RenderSampleContext }
protocol PresentationSampler {
    func sample(at: RenderSampleContext, into: inout PresentationValues)
}
protocol FrameCollector { func freeze(at: RenderSampleContext) -> RenderFrameSnapshot }
protocol LightingPlanner {
    func plan(_ frame: RenderFrameSnapshot, previous: LightingScheduledState) -> LightingUpdatePlan
}
protocol RenderBackend {
    func submit(_ frame: PreparedRenderFrame, target: RenderTargetDescriptor)
}
```

`PresentationSampler` 的第一个实现允许继续调用已有 `TrajectoryPlayback.stateAt`，也允许 `FrameCollector` 由 SceneKit post-animation 呈现值补齐。它不接管求解器/预测器，不改物理时间步。`RenderBackend` 不暴露“重建世界”、ECS entity 或业务 callback 给外界。物理返回值 → 呈现 sampler/现有 action → snapshot 的边界是迁移点；实际 actions 消费者有 SCNNode，不能声称仅加一个 protocol 就已解耦。

## 3. RenderFrameSnapshot：字段与版本

建议最小字段：

```text
RenderSampleContext
  sessionID, generation, frameID
  timelineTime, previousTimelineTime, timelineDelta
  simulationTime, presentationTailTime, tailTimeDomain, playbackSpeed
  seekEpoch, playbackPhase, renderTime
RenderFrameSnapshot
  sampleContext
  camera { worldFromCamera, projection, viewport, outputExposure, projectionMode }
  table { worldFromTable, bedPlane, radius, receiverDomainID }
  balls[] { stableID, worldCenter, orientation, actualRadius,
            visibilityWeight, opacity, isVisible, receiverClass, poseVersion }
  lights { geometryVersion, radianceVersion, sampleLayoutVersion, panels[] }
  assets { geometryVersion, materialVersion, roomVersion, probeKey }
  lightingInputVersions { ballOcclusion, receiverGeometry, fieldLayout, shaderAlgorithm }
  cue/rail/overlay presentation handles or value arrays
```

`visibilityWeight` 第一个 adapter 必须复用现有 `0.85 * presentation.opacity * clamp(height/radius,0,1)`，球高度的编码和 shader 的中心约定也必须成对保留（`MobileTableRendering.swift:249–253` 与 `MobileReferenceLighting.swift:388`）。snapshot 同时保留真实位置，禁止让这一历史编码冒充一般球 transform。若未来允许不同球半径，compute/shader/现有硬编码必须一起版本化；首切片只支持当前半径与已确认的 table-local 映射。

`frameID` 标记提交，不意味着照明变化：球只旋转会变 orientation/pose，而不会使球体遮挡场失效；同球心/高度/权重的场可跨多个 camera frame 复用。隐藏/移除/复位/重建必须以 stableID 和 membershipVersion 删除旧 support，不能比较数组 index 后把另一颗球当未变化。camera 与场引用共享当前 snapshot，但场的 key 只含它实际依赖的输入。

`PreparedRenderFrame` 持有 frame snapshot、field 的内容版本/编码计划、probe/material handles、frame uniform slot。它不能指向“后台稍后会覆盖”的 CPU Data；每个已提交 slot 至 GPU completion 才复用。字段是内部值协议，不必一次把所有 UI 传入数据搬过来。

## 4. 灯光失效图：哪一条边真的存在

| 输出/缓存 | 必需输入 | 不应造成失效的变化 |
|---|---|---|
| light sample positions、cellArea、filter footprint 规格 | emitter geometry + sampleLayoutVersion + receiver mapping | 相机、球旋转、台呢颜色、曝光；radiance 变化也无需改几何 |
| bed `T_s(x,z)` 逐样本 visibility | 球心/高度/visibilityWeight/membership、灯几何/样本、接收面平面/世界变换、算法/布局 | 相机、球旋转、贴纸、台呢 albedo/roughness、灯纯 radiance/gain（几何不变） |
| bed 未遮挡几何响应/宏观法线灯权重 | 灯几何 + receiver 几何/宏观法线 | 动球、相机；若预乘 radiance 则 radiance 也必须入键 |
| fragment diffuse/specular/nap | `T_s` + 当前微法线/roughness/albedo + 当前 view + radiance | 不可缓存成仅与 world position 相关的单一最终 RGB |
| contact AO | 当前球遮挡编码 + receiver 位置 + 当前算法 | camera；首切片继续用当前公式，不给无限尾函数凭空设有限 support |
| room cube/equirect/SH/floor capture | 最终静态 room/table 几何和材质、灯、capture centre/axis/色域、capture algorithm | 普通相机移动/viewport、动态球/cue（捕获排除） |
| prefiltered env | sourceProbe 内容 + filter 算法/规格 + device | camera、球位、只是 scene 实例重建 |
| shared response LUT | BRDF/积分算法+规格+device | sourceProbe、room、camera、球位 |

表中“静态”是相对该输出的语义，不是“不再可修改”。桌布换色若进入 probe capture 就应失效该 probe；它不影响纯球遮挡几何。房间改色若改变 emitters/radiance 则沿相应边传播，不能只刷新贴图。当前 SH/reflection 的布面反弹有现成 `applyClothColor → applyClothBounce` 路径（`AngleTrainingScene.swift:59–68`），新依赖图需保留其颜色响应，避免无变化房间 style guard 拦截了必要更新。

ProbeKey 草案：`roomAssetHash + tableGeometryHash + capturedMaterialHash + lightRigHash + capturePose + captureColorConvention + captureAlgorithmVersion`。PrefilterKey 再加入 probe 内容摘要、尺寸/mip/滤波算法/device；响应 LUT 单独 key。材质最终应用后构建静态捕获描述；不继续用 live scene 的“暂隐藏所有动态节点”做后台 bake。第一阶段仍可在原 owner 上同步创建隔离的 capture scene，之后按 descriptor 只在资源准备阶段使用它。把原函数包进 Task 并保留对 live scene 的隐藏/删节点，是增加并发风险，不是架构优化。

## 5. 单时钟与兼容现有 actions

目标是同一帧的相机、球、回球、袋尾段、遮挡与媒体出口都收到同一个 `RenderSampleContext`。**时间单位仍可不同，但转换只有一处**：global timeline time 用于相机/停留段；simulationTime 通过该杆 start/speed 映射；presentationTailTime 按 tailTimeDomain 保留当前政策——legacy 入袋腿/淡出使用实秒，已有 collectionOpacity 使用模拟时间（`TrajectoryPlayback.swift:272–276`），不能趁抽象改变行为；renderTime 是传给 SceneKit 的单调系统时间映射。暂停时 simulation/tail 不自行前进，seek 要增 seekEpoch/reset 转角积分游标；不能用一次大 dt 从旧旋转积分到跳转帧。

增量顺序：

1. 保留现有 live `SCNAction.customAction`、CameraRig damping 公式和 export 手动节点路径；各入口接受同一时间映射描述，记录该帧实际取样时刻，先不把 SCNAction 全删掉。DisplayLink 是唤醒源，不是第二个业务时钟。
2. 从 `TrajectoryPlayback` 抽出已有 `stateAt`/collectionOpacity/入袋腿/旋转积分的共享呈现 adapter；先替换导出循环里一段球 pose，live action 调相同 adapter。导出额外下沉是目前有意的消费者视觉差异（`SequenceVideoExporter.swift:636–643`），用显式 PresentationPolicy 保留，不当物理差异修掉。
3. rail timeline、cue stroke、camera transition 依次接同 context；BreakFlowRunner 的完成判断改看自然静止 + 现有尾段的 presentation endpoint，墙钟 sleep 最多是唤醒提示，不负责提前钉球终点。取消、背景和 generation 必须阻止旧回调给新局写节点。
4. 导出先仍使用 `snapshot(atTime:)`，但由 frameContext.renderTime 供时，不再在截图成功/重试/HUD 分支里暗自推进业务 clock。随后需要共享 compute 时再走显式 offscreen attachment，保留截图出口作为兼容路径。

不能许诺实时与任意导出帧率的旋转现在已数值相同：当前积分依赖帧间 omega/步长。共享函数减少实现分叉；若需要 seek-safe orientation，可单独增加 recorder 对齐的预积分/累积姿态表，但这是下一阶段呈现工作，不涉及改物理，也不应假冒本轮已实现。

## 6. 一个 owner 与明确的提交次序

先选择主线程作为单一 scene 变更 owner，避免为了“异步”把大量 SCNNode/CameraRig/UIKit 移到不同线程。SceneKit delegate 不能假定在主线程；其 collector 只读取该受控更新相位并产生不可变值，不调用 UIKit，不允许其他 owner 同时改节点；提交只消费匹配本次 renderTime/generation 的完整值。需要实施后确认宿主回调相位，不能拿现有 FrameDelegate 的引用锁替代整个树的所有权。CPU worker 可以准备纯 value/asset bytes，GPU compute 处理快照 buffer；不得携带可变 scene。这个选择以正确性和小工作面为目的，不声称主线程化有性能收益。

受控宿主每次提交的顺序：

1. drain 当前 generation 的输入/资源完成事件；应用业务节点变更；从 RenderClock 冻结本帧时间，CameraRig 按相同 dt 推进。资源完成只申请一次帧。
2. `SCNRenderer.update(atTime: context.renderTime)` 评估现有 actions 等；现有 contact 的 didApplyAnimations 兼容路径先保留，新增 field 的 collector 则在全部更新结束后读取最终 presentation，不能直接把动画后 callback 的早期快照当最终状态。当前检索 Scene/TrajectoryPlayback/BreakFlowRunner/SequenceVideoExporter 的约束赋值只有 `AngleTrainingScene.swift:2567–2571` 的 label billboard，未见球位约束；仍以最终采样处理未来约束及导入内容。
3. 以实际 snapshot 计算内容版本差异；首版有变更则有界全场生成，第二阶段才计算 old/new support 脏区。资源句柄与 uniform slot 固定。没有变更则没有 field compute。
4. 一个 app-owned commandBuffer 先 encode field compute，endEncoding；再 `SCNRenderer.render(withViewport:commandBuffer:passDescriptor:)`；不要再调用含 update 的 `render(atTime:...)`，以免本帧 action 推进两次。最后 present（或 offscreen encode）并 commit。
5. completion 释放 uniform slots/retired resources，更新 completedVersion，并按需通知新帧；不是 CPU waitUntilCompleted 后才继续业务。

本机 SDK 核实：`SCNRenderer.h:70–77` 的 `updateAtTime` 与不更新动画/物理/粒子的 `renderWithViewport` 均 iOS 11；显式 commandBuffer/passDescriptor 入口 iOS 9。`SCNSceneRenderer.h:332–365` 明确 animation 前 update、animation 后 didApply、constraints 后 didApplyConstraints（后者 iOS 11）。`SCNShadable.h:273–290` 全 Metal vertex/fragment/buffer binding iOS 9。均覆盖 iOS 17。[SCNRenderer 官方文档](https://developer.apple.com/documentation/scenekit/scnrenderer)；[SCNProgram 官方文档](https://developer.apple.com/documentation/scenekit/scnprogram)。证据为本机 `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks/SceneKit.framework/Headers/`，读取日 2026-10-02。

因此 SCNRenderer + 小 compute + 原 SceneKit geometry 是本切片的充分候选承载，不要求先替换整个引擎。选择它是为了应用可排列 compute → draw，并非先声称 SCNView 双时钟就是 GPU 热点。SCNView 独立 compute queue 后立即绑定未完成纹理不能保证同帧；只做一帧延迟又让球/影错位，不能作为默认捷径。

### 在途资源的实际规则

- 首版每个 RenderSession 有独立可变 field texture，同一 Metal queue 的 commandBuffer 按 `compute(k) → draw(k) → compute(k+1) → draw(k+1)` 使用同一纹理。**自动同步的必要条件是 tracked resource 且直接绑定到 encoder**，不能仅凭 commit 次序宣称读写已串行。device 创建默认 tracked，heap 默认 untracked；首版不使用 heap/untracked。CPU snapshot/uniform buffer 用在途 slot，不在旧 GPU 读取时覆盖。[Apple Resource synchronization](https://developer.apple.com/documentation/metal/resource-synchronization)，全文已由主控保存在 `primary-sources/metal-resource-synchronization.md`，本角色于 2026-10-02 读取。
- compute 端能直接绑定；SCNMaterialProperty 对 SceneKit 内部资源绑定是否满足直接追踪，不能由公开 high-level API 推定。若适配器不能落实这一条件，需在 app-owned commandBuffer 上显式 event 排列 compute 完成→render 开始、render 完成→下一次修改，或采用独立场版本并正确同步生产者/消费者。**成立的条件是能在真实读场的消费命令之前插入 wait，并覆盖真实写场与最后读场的 signal/wait 边界**，只在 compute 后 signal 不成立；若 SceneKit 内部另有不可覆盖的命令流，该方案不能放行。独立纹理也不能省掉其第一次 compute→draw 依赖。`MTLCommandBuffer.h:409,416` / `MTLDevice.h:910` 核实普通 MTLEvent 的 GPU signal/wait/newEvent 为 iOS12，覆盖17，只证明 API 可表达，未证明本宿主适配已经通过。必要时改成床面 SCNProgram/可控局部 draw 以落实消费绑定与等待，条件仍不能满足就停用 field、回退原公式，不展示旧版场。
- 同一个 field texture 的旧内容不用每帧全量复制：前帧 draw 在该 queue 上先完成读取，后帧 compute 才更新脏 tile。若引入另一 queue、并行 export、异步 capture，则必须另用 texture/session 或显式事件同步；不能仅凭 CPU lock 判安全。
- `scheduledVersion` 与 `completedVersion` 分开。compute+draw 计划提交成功才推进 scheduled；commandBuffer 失败/取消使该 session 场失效，下次重建。界面不能拿未来 scheduled 内容当已完成 CPU-readable 图。
- resize/切换 grid/device/room 时建立新 immutable resource key；旧 draw 保留旧资源到 completion。最新 generation 完成才切换句柄，迟到结果允许入同 key 的 cache，禁止覆盖当前其他 key。缺资源首版走当前直接着色，不能显示旧球影冒充最新。
- Probe/Prefilter Store 对同 key single-flight；failed 保存具体错误/输入key并提供受控 retry，避免每帧重试。共享 device LUT 与 env 是 immutable，动态 field 不是全局 room cache。

## 7. 静态/动态语义资产

不依据 `TaiNi` 材质名把所有共享材料一键切到平面算法。建议导入后建立 receiver catalog，首版可来自已有模型的人工可审计 manifest：

| 语义 | 光照路径 |
|---|---|
| `bedPlanar`：经几何确认、位于实际台呢平面的三角形；袋口缺面正确排除 | world-space visibility field + 当前法线/roughness/视角公式 |
| `railCloth` / `pocketFacing` / 非平面台呢 | 继续原 direct shader/contact/pocket AO；不能投影到 bed 代替真实 p |
| `staticTable`、room/floor | 静态 asset/probe 描述；动态球遮挡是否进入它们是各自算法政策，不能因名字“静态”直接删效果 |
| `ballDynamic`、cue、return rail dynamic inventory | 同帧 snapshot/现有 SceneKit 呈现；球旋转只影响球材质，不使球形遮挡场失效 |

只按 shader 内 `abs(y-surfaceY)` 截取的方式已有 contact AO 局部分支；新方案需覆盖具体 geometry primitive，并避免插值跨 bed/rail/pocket 语义边界。首切片不要求离线重做桌体，但若共用材料跨语义，要复制 material/binding 或分出正确 geometry element，不改变球桌位置/袋口几何。probe scene 可以重用 immutable 几何描述与最终材质配置，不能共用会被 live 改写的 SCNNode。

## 8. 最窄第一切片：逐样本 bed visibility 场

**切片名称：BedVisibilityField-v1；只覆盖一个 canonical 平面 bed，不处理球面反射、rail、pocket AO、cue、return 和所有 exporter 重写。** 先在每日当前 R 接一条局部候选路径；shared A 消费者单独启用/回归，不能把不同基线混池。新架构不属于 10-01 的相同资产/相同公式/精度/接口约束实施。

定义 `T_s(x,z) = ∏_b (1 - opacity_b * blocked_s,b(x,z))`。`blocked` 复用当前 equal-area sample disk 的 filterRadius/smoothstep、样本位置与球高度/权重编码；按稳定球序计算整个乘积。对照当前公式，T 与 n、v、球自转、albedo 无关。fragment 继续每个样本取得 T_s，再乘该样本的 weighted、D/G/F 并累计，最后保留当前解析 diffuse 校正与 nap 输出。不能把 `mean(T)` 乘到 E 或 S，更不能把两个球的独立平均遮挡相乘。

首版布局可先取 256×128 世界网格、64 个 R32Float 通道作为设计例：两个灯各 8×4 样本，基础存储 `256*128*64*4 = 8 MiB`，另加 uniform/index/例外开销；没有承诺该分辨率已够清晰。64 slice 纹理/分组 RGBA 纹理绑定的具体 shaderModifier 声明需要实施时选择可编译方案。首次不引入 R16 量化、mip、时间 jitter、平均可见度或粗镜面；只考察空间采样这一近似。支持域外保留当前 2×2/每灯无影路径，场仅供有影的 8×4/每灯积分使用，不能把两种样本位置当同一数组。

**首版生成规则**：blockerRevision、receiver/light/layout/algorithm key 任一变化，就完整生成当前有限 grid 的 64 通道；遮挡状态不变则复用。每次完整生成覆盖无影点的 T=1，因此没有旧阴影遗留/轮转 dirty 补齐。AO 保留现有独立公式，其尾部不能照搬 direct-shadow support。

**第二阶段局部更新规则**：用现有保守 support（含 sample footprint）形成每球 old ∪ new 覆盖，并增加插值 texel/边界 halo 后取 tile；整帧计划与 snapshot 内容一致。每个脏 tile 从当前全部相交球候选重算 T，不用除法“撤销旧球”——旧 T 为零/遮挡重叠时不可逆。离场/淡出/抬球都进入变化检测。球高接近灯、support 无法可靠限制时升级全 bed 更新，必要时回到当前直接路径。不能证明网格点对应 support conservative 时全场重算/回退，不能仅以经验半径裁掉阴影。

第二阶段同一纹理里未受影响 tile 保留旧内容，旧内容仍然是当前 snapshot 下正确的场（该 tile 的所有实际依赖未变）。初次和完全失效先初始化 T=1，再更新有 support 部分；清掉离场旧阴影也必须更新旧区域。球心/高度/权重不变而相机移动，两阶段场 compute 均为0；fragment 仍计算视角与粗糙度响应。若渲染暂停、求解结果换局或新 asset generation，应比较状态/key 而非漏掉一次事件。

### 复杂度与新增成本

设 N 为实际 bed 着色像素，q 为需 64-sample 阴影积分的比例，S=64，c(x) 为经过当前 support 后的球候选数；U 为本帧脏世界网格点，c_t 为 tile 候选数。只写主要遮挡项：

```text
旧：  N*q*S*平均c * C_rayBall
新：  U*S*平均c_t * C_rayBall + N*q*S*C_fieldRead + C_tilePlan + C_resource
```

首版发生失效时取 `U=G=256*128`，并有完整写入 `G*S*4 bytes` 的成本；无变化时 U=0。第二阶段才取脏点 U≤G。两边相同的 BRDF/光权重计算不能算省掉；现有 mask 已减少候选，不能旧项偷用16颗全扫描。相机单独移动时 U=0，但新增 field 读取可能与旧近影候选稀少情况下的算术竞争；256×128 不等于实际屏幕投影质量，插值也是实质近似。可提前从 source/资产/计划算 N 的设计上界、grid bytes、support 覆盖公式与 U 上界，设备时间/净能量收益留作实施后的结果。

在同一 world position、同样样本、同序 float 运算时迁移 T 查询是积分的精确拆分；从 world 网格插值回像素时不再精确。尤其接触边、窄半影、球重叠、袋口边界、相机放大可能失真。保留直接路径是局部质量 fallback，而非用一帧旧场掩盖同步失败。若空间场读带宽高于被替代算术，下一候选可以是法线响应基/宏观 irradiance + 小 residual，但必须另立近似模型，不能把它偷偷塞进本切片。

## 9. 承载层选择与实施阶段

台呢 fragment 首版优先改局部 shaderModifier，使当前 n/v/roughness 与输出标定可追溯；compute 只生成 T_s。已有 constant-material debug prototype 表明尾部简化已有人试验，它不等于新 field 已实现。若 modifier 的纹理数组声明/资源绑定成为具体障碍，才为 `bedPlanar` 上 SCNProgram：完整保留 UV、normal、变换、depth/AA/颜色与材质采样，只接管这一个接收面。SCNProgram 不要求所有球、桌体、回球同步迁移，SCNRenderer 仍渲染其他对象。

| 顺序/拟提交 | 修改范围 | 完成后检查（不作为开始前门槛） |
|---|---|---|
| 1. `FrameContext + scene adapter` | 加 value/context；保留 actions；集中时钟映射/采样阶段，原 contact 同帧路径仍可运行 | 暂停/取消/seek、同一 frameID 的 pose/uniform、FL-076 不复发；物理结果不变 |
| 2. `ReceiverCatalog + dependency keys` | canonical bed manifest；将静态描述与业务状态分开；field key 与 probe key 建立实际边 | 相机/自转无 field invalidation，换球高/淡出有；衣色/room/table 捕获依赖正确 |
| 3. `SceneKit controlled submit + field v1` | 一个受控 session 的 SCNRenderer update/render；显式同步 compute→draw；仅 bed 路径，blockerRevision变化有界全场生成 | 原 direct 与 field 同帧对照；所有样本乘积/重叠/高球/边界；静态 camera-motion 场不重算；在途内容无混帧 |
| 4. `ResourceStore / isolated probe` | 完成事件驱动的准备/切换，immutable resource keys；拆 live scene bake 依赖 | 准备失败/重试/取消/换room；旧资源至completion才释放；不更改物理与全桌几何 |
| 5. `Shared presentation sampling increment` | 先一个导出球pose段，再live action adapter，再rail/cue/camera消费者 | 同context同policy一致；现有3D导出下沉政策不丢；六袋/回球/尾段与音频取消完整 |

第一可交付的结构候选是 **1–3 合在一个受限页面/接收面的切片**，不是先完成所有抽象、probe 重构或导出重写才开始。1–2 是使新计算域不混帧/不漏失效的必要基础；它们独立改善可维护性，但本身不承诺显著降耗。4–5 可以后续落地，不能拿它们的范围反过来阻塞第一场算法实现。

实施后验证顺序先正确性，再画质，再计数/耗时/能量：先确认同帧、失效与例外，再检查相机放大/接触边/球重叠视觉差异，再核对 `U=0`、脏 tile 数与 GPU pass 工作减少。出现带宽交叉点不利或需要像素级网格才能保住要求画质时，撤销 field 或收缩为局部用途；这仍不构成全面换引擎的理由。若 SceneKit 载体能正确表达这套 compute/资源/着色，就结束宿主迁移讨论。

### 首版资源预算与编码选择（按主控/评审消息收紧）

- 首切片只接一个 interactive RenderSession，已有 exporter 继续原路径；后续共用 clock 先于共用 mutable field。**沿用原方案新增 GPU 资源总峰值 ≤16 MiB，不另增产品预算。** 包括 active/retired field、边界 collar、certificate、frame inputs、额外临时/替换资源及其他本切片新增 GPU 分配。原先24 MiB field+1 MiB inputs只是未批准草案，已撤销，不能称为符合原验收限制。
- frame input buffers 上限1 MiB也计入16 MiB总额，不是额外额度；256×128×64×R32的8 MiB只是 field texel设计值。分配前保守预算、分配后按 allocatedSize核对，不能忽略布局、其他新增buffer或瞬时峰值。后续若新增probe/输出attachments/准备资源，也必须显式统计其新增峰值，不能由本文的首切片授权排除它们。
- key变化若 old active/retired + new field + 其他新增资源可能超过16 MiB，先用当前R直接公式，异步 retire→GPU completion→release 后才分配新field；不先分配再声称旧场马上会释放。等待期间不CPU wait，不用旧影配新球。无法在预算内完成保守 admission 就维持原路径。
- 三个普通 frame input slots + 一个保留的直接公式 fallback slot；每slot最大256 KiB。可用条件是该slot最后一次 GPU 使用已完成且当前generation/尺寸可用。field内容选择标记 `{session,generation,frameID,blockerRevision,fieldKey,scheduledComputeToken}`；静止帧可共享同一个有效场，但不能借前帧球buffer。每次 encode 都将该 selection 固定，不在 update→freeze→bind→encode 区间 await/reenter业务任务；该区间没有任何另一owner的scene/material写入。
- field/key分配失败、超预算、绑定/同步无法成立，或新场不匹配当前快照时，用保留slot编码当前R直接公式。若包括保留slot在内都在途，则跳过本次GPU提交，由后续时钟采样追上；不CPU wait，也不覆写在途uniform。保留slot是保证常见field失败可回退，不是无限帧积压时的无上限资源承诺。
- 未来若改成三张field纹理轮转，首版每个取得的可写slot必须 full generation；其 frame/version 必须匹配这次 selection。只有实现每slot内容版本、累积失效集合或明确旧→新拷贝后，才允许 dirty patch。不能拿当前单queue单field的“未脏内容仍正确”证明轮转slot也正确。

## 10. 事实、推断与实施后未知

- **当前事实**：时钟/阶段、缓存/guard、逐样本遮挡乘积、n/v 参与积分、probe 键与 live scene bake；上文均可由当前代码直接确认。公开 iOS 17 具备提出的 SceneKit 提交接口。
- **结构推断**：camera-independent visibility 可独立成函数；内容依赖明确后同状态跨相机帧复用；同 queue compute→draw 可表达同帧；保留物理/已有 actions 的局部接入范围比全面渲染器重写小。这些支持本轮给出方案，不需要先做新设备测试。
- **实施后未知**：实际 field 分辨率/格式与 shader binding、空间插值可接受性、质量 fallback 覆盖、场读取 vs 算术的交叉点、SceneKit 实际呈现资源绑定行为、GPU/CPU毫秒与整机能量。不能把缺少这些结果变成“现在没有架构可建议”，也不能把理论机制变成最低能耗承诺。
