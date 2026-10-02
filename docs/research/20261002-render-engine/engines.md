# 引擎选型与迁移架构独立研究

研究日期：2026-10-02（Asia/Shanghai）。角色：iOS Architect / 渲染引擎选型与迁移架构师。第一轮独立研究，未阅读同伴报告。本轮仅静态源码、SDK 与官方资料核验；未构建、加依赖、安装或运行手机负载。

## 1. 独立结论

**当前推荐继续优化 SceneKit；仅在 §9 所列的现有宿主、SCNProgram 与资源准备候选不能满足目标，而且残余受限项有测量证据时，才用专用 Metal 渲染原型验证替代价值。Filament 保留为成熟 PBR 备选。最低 iOS 17 不变时，不推荐 RealityKit 完整替换当前共享渲染系统。** 这是一项有条件的架构推荐，不是已测出最低功耗的排名。首轮候选次序已按交叉审计收紧，达标即可停止迁移研究。

原因来自需求和能力边界，而非引擎新旧：球迹是原生 SwiftUI 中受控的小型台球场景，已有自有物理和可查询回放。主要需要精确可控的相机、台呢/球材质、动态球影、停绘与确定性离屏输出。更通用的引擎附带的世界模拟、AR、内容编辑功能并不直接改善这些工作负载。专用 Metal 最容易使提交、pass、资源驻留和静态帧生命周期明确，但开发团队也要承担完整渲染正确性和资源工具链。

**最强反对理由**：现有热点很可能仍主要来自自编台呢阴影公式和采样量；将同一积分原封不动迁入 Metal，片元计算与带宽未必减少，甚至可能因失去现有优化而更差。若现有 SceneKit 同画质优化已经满足长期使用目标，自研引擎的机会成本会高于收益。Filament 可以减少通用 PBR 基建维护，却也可能只是把原公式换一个宿主。

## 2. 基线和当前工作面

代码证据使用 `baseline-source/`，其根目录记为 **B**，真实路径为 `/Users/song/projects/13.billiard_trainer/docs/research/20261002-render-engine/baseline-source/`。`baseline.json` 记录 HEAD `b69aa749b12a4e322da1bbca1a78536349531c47`、2026-10-02 08:10:51 +08:00 的 dirty 状态与源码哈希；不是仅凭 HEAD 推断运行版本。

| 已确认事实 | 基线证据 | 对选型的含义 |
|---|---|---|
| `AngleTrainingScene` 继承 `SCNScene`，每日清台配置 `.reflection`，其他消费者仍用共享默认 | B `QiuJi/Core/Scene/AngleTrainingScene.swift:7,14,28–38` | 应以真实生产 profile 对比，不能拿旧 reference 的反射成本当新收益 |
| 视图使用 4× MSAA 和用户帧率请求 | B `QiuJi/Core/Scene/AngleSceneView.swift:86–100` | AA/尺寸/帧率相同才比较成本 |
| 当前已检查动画、相机阻尼、手势，停 DisplayLink / SCNView 播放并热状态调度 | B `QiuJi/Core/Scene/AngleSceneView.swift:385–425` | 停绘不是只有 Metal 才能实现；必须测所有消费者是否正确接入 |
| 2D 用真正正交投影 | B `QiuJi/Core/Scene/CameraRig.swift:1393–1406` | 透视相机长焦不等价，不能用它规避 API 缺口 |
| 球拾取使用 SceneKit hitTest，并考虑前景遮挡与可交互对象 | B `QiuJi/Core/Scene/AngleSceneView.swift:611–647,904–958` | 引擎有 raycast 不代表原交互语义自动等价 |
| 教学视频显式维护 clock、frameDt，用 SCNRenderer 在指定时间/尺寸取帧 | B `QiuJi/Core/Media/SequenceVideoExporter.swift:1077–1096` | 当前帧截图不是确定性离屏渲染的替代 |
| 缩略图、图解与反射探针也用离屏 SceneKit | B `QiuJi/Core/Scene/DrillThumbnailRenderer.swift:30–37`; `TableFigureRenderer.swift:112–120`; `RoomReflectionProbe.swift:344–362` | 只改每日清台会形成双渲染工具链 |
| USDZ 加载缓存原型并 clone，实例几何/材质浅拷贝隔离 | B `QiuJi/Core/Scene/TableModelLoader.swift:33–39,73–105,309–316` | 需要重建或明确保留资产加载/隔离契约 |
| 自定义 shaderModifiers 管线包含直接球影支持域、逐球数组和台呢采样 | B `QiuJi/Core/Scene/MobileReferenceLighting.swift:309–329,379–456,879–901` | 应先验证算法/采样成本，而非假设框架内部必然是主因 |

另读取当前工作区（未在 B 中）的三份生产文件，读取日期同上，不能冒称冻结哈希证据：`QiuJi/Core/Physics/SimulationWorker.swift:7,19–30,83` 只接值快照且不持有节点；`QiuJi/Core/Physics/TrajectoryPlayback.swift:42–58,100,472` 包含 SCNNode / SCNAction 消费；`QiuJi/Core/Rack/BreakFlowRunner.swift:113,157–196` 也持有节点和交互动作。结论是**物理求解边界可以保留，但呈现消费者不是已经完全独立于 SceneKit**。迁移要拆呈现接口，不能把重写物理求解器作为必要工作，也不能承诺零业务迁移。

10-01 的既有代码优化计划（B `tasks/RENDER-CODE-OPTIMIZATION-PLAN-20261001.md:1–42`）明确维持 SceneKit、画质和物理不变。本文比较后续战略路线，不授权突破该实施计划的固定边界。

## 3. 版本核验：RealityKit 的 iOS 17 边界

本机 SDK：`/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk`。RealityKit swiftinterface 头声明 target `arm64e-apple-ios26.2`，因此**依据符号的 availability 标注判最低版本，不把 SDK target 当最低系统**。下表源位置均为 `System/Library/Frameworks/<框架>.framework/Modules/<框架>.swiftmodule/arm64e-apple-ios.swiftinterface`。

| API | iOS 最低版本 | iOS 17 结论及证据 |
|---|---:|---|
| `ARView` / `.nonAR` | 13 | 纯虚拟场景可用，无需 AR 跟踪；RealityKit:677–680,1109；[官方 nonAR](https://developer.apple.com/documentation/realitykit/arview/cameramode-swift.enum/nonar) |
| `PerspectiveCamera` / `PerspectiveCameraComponent` | 13 | 可控透视相机；RealityFoundation:5945–5951,13825–13835 |
| `CustomMaterial` / SurfaceShader / GeometryModifier | 15 | 可用；RealityFoundation:11587–11618；[官方 CustomMaterial](https://developer.apple.com/documentation/realitykit/custommaterial) |
| `ARView.renderCallbacks` / PostProcessContext | 15 | 可访问已渲染 color/depth 和 command buffer 做后处理；RealityKit:20–43；[官方 RenderCallbacks](https://developer.apple.com/documentation/realitykit/arview/rendercallbacks-swift.struct) |
| `ARView.hitTest` / project / ray | 13 | 可用，CollisionComponent 碰撞代理语义须验证；RealityKit:453–475 |
| `ARView.snapshot(saveToHDR:completion:)` | 13（所属 ARView 标注） | 异步截图，无显式 time/size 参数；RealityKit:677–680,809–811。官网当前 OverloadGroup 的 markdown 仅列 macOS，采用 iOS SDK 的 UIImage 类型签名作为该项证据 |
| `RealityView` | 18 | **不能用于 iOS 17 路径**；_RealityKit_SwiftUI:426–434；[官方 RealityView](https://developer.apple.com/documentation/realitykit/realityview) |
| `OrthographicCameraComponent` | 18 | **iOS 17 没有这项公开正交投影能力**；RealityFoundation:10763–10776；[官方正交相机](https://developer.apple.com/documentation/realitykit/orthographiccameracomponent) |
| `RealityRenderer` | 18 | **iOS 17 不能用该公开 Metal 渲染器做受控离屏**；RealityFoundation:2115–2210；[官方 RealityRenderer](https://developer.apple.com/documentation/realitykit/realityrenderer) |
| `LowLevelMesh` / `LowLevelTexture` | 18 | 不能回溯至 iOS 17；RealityFoundation:10297–10298,10968–10983 |
| `RealityViewRenderingEffects.customPostProcessing` | 26 | 新 RealityView 后处理；_RealityKit_SwiftUI:714–735。不要误说 iOS 17 没有任何后处理，ARView 的 15+ 回调确实存在 |

CustomMaterial 可处理材质输入/顶点，不是任意 render graph / 自定义 buffer layout。其公开 Custom 参数为一个 SIMD4<Float> 与一个自定义纹理（RealityFoundation:11633–11644）；台呢多球位置等需要不同参数传输设计。可以用纹理承载数据或改写材质，不等于完全做不到；但 iOS 17 不可引用 LowLevelTexture 来证明可直接无复制更新。材质设置、光源阴影、非 AR 环境 IBL 有公开接口；各效应是否能与现有积分严格匹配仍待原型。[官方自定义材质说明](https://developer.apple.com/documentation/realitykit/modifying-realitykit-rendering-using-custom-materials)

`ARView.RenderOptions` 提供禁用 HDR、运动模糊、景深、grounding shadows 等（RealityKit:382–425）。未在已读公开、受支持 API 中找到 `SCNView.preferredFramesPerSecond`、MSAA sampleCount 或明确停止/单帧绘制的等价接口。SDK 出现 `__preferredFrameRate` / `__enableAutomaticFrameRate` 等内部符号，**不作为可上线的配置能力**。取消 update 订阅或暂停 ARSession 也不能据此证明非 AR 渲染器已经停绘。这是证据边界，不是“RealityKit 必然耗电”的结论。

完整统一迁移的两个硬缺口是正交和确定性离屏；可以保持 SceneKit 负责 2D/导出，但此时要接受两个材质、光照、球影、相机和资源生命周期实现，维护成本及跨画面一致性验收增加。离屏截图不能通过墙钟等待改称指定时间渲染。

## 4. 四条路线能力比较

| 需求 | SceneKit 优化 | 专用 Metal / MetalKit | RealityKit（iOS 17） | Filament（v1.77.2） |
|---|---|---|---|---|
| SwiftUI 原生嵌入 | 现有 SCNView wrapper | MTKView wrapper 要实现 | ARView wrapper 可用 | UIView/CAMetalLayer + C++桥接要实现 |
| 正交 + 透视 + 精确矩阵 | 已有 | 自有矩阵 | 透视有；公开正交18+ | Camera ORTHO / custom projection |
| 任意时刻离屏/视频帧 | 现有 SCNRenderer | 显式采样状态并 render 到 texture/pixel buffer | screenshot；受控 RealityRenderer18+ | 手动采样状态，RenderTarget 或 Metal CVPixelBuffer SwapChain；编码同步待验 |
| 球/台呢自定义着色 | 现有 shaderModifiers/SCNProgram | 完整 MSL 管线 | CustomMaterial15+，框架管线内 | 自定义材质、uniform数组/纹理；MSL须译到其材质语言 |
| 同帧多球位置参数 | 已有，仍需性能核实 | 自管不可变在途 buffers | 参数空间受限，需重设计 | MaterialInstance uniform数组可用 |
| AA 可控 | 当前4× MSAA，另有TAA公开API | sampleCount，按支持表查询 | ARView 不提供等价 sampleCount 公共配置 | MSAA / 后处理AA / TAA 可配 |
| 阴影/反射/曝光 | 现有效果 | 每个效果都要实现/验证 | 原生效果；非现有公式直接等价 | 成熟PBR和阴影；非现有公式直接等价 |
| 拾取/遮挡 | 当前几何hitTest | ray-sphere/平面 + BVH或ID buffer需实现 | collision代理hitTest | View.pick 异步有延迟；CPU拾取可自建 |
| 静止无绘制 / 活跃帧调度 | 已接入，逐消费者核实 | MTKView 事件/显式绘制控制 | 无已确认公开单帧/停绘等价控制 | 应用掌握begin/render/end，可以不提交 |
| USDZ 现有资产 | 直接消费 | ModelIO或离线转换/自有资源格式 | USD资源自然适配；材质重建 | gltfio消费glTF/GLB，USDZ须转换或自有网格加载 |
| 物理与规则 | 保留 | 保留、换呈现适配 | 保留、不挂引擎PhysicsBody | 保留 |
| 核心维护风险 | 弃用和框架黑盒 | 自研正确性、资源、驱动差异 | 17能力缺口和黑盒 | C++/工具版本、包体、资产转换 |

表中“可控”仅表示公开可实现，不表示已测更快或效果更好。

### SceneKit

Apple WWDC25 明确宣布 SceneKit 弃用并建议新项目使用 RealityKit，同时指出现有应用短期无需担心；未给公开移除日期。**弃用是长期维护风险，不是当前无法运行或迁移必有省电收益。** [Apple WWDC25 迁移说明](https://developer.apple.com/videos/play/wwdc2025/288/)

本机 Headers：`SceneKit.framework/Headers/SCNRenderer.h:44,57,70–89` 分别支持 Metal renderer（iOS9）、指定 time/commandBuffer/pass（9）、update/render 拆分（11）及指定尺寸AA的snapshot（10）；`SCNSceneRenderer.h:178` TAA（13）；`SCNView.h:76–79,141–146` 连续渲染与帧率控制。均覆盖17。保留场景组织但改用 `SCNRenderer + MTKView` 也是可研究的中间路线，能控制宿主提交，但不自动消除内部渲染/材质成本；只有测出现有双回调或调度为热点才值得尝试。[官方 SCNRenderer](https://developer.apple.com/documentation/scenekit/scnrenderer)

### 专用 Metal

MTKView 从 iOS9 可用，支持定时、事件触发、显式 draw 三种模式。其 depth、MSAA和 drawable管理可以保留原生嵌入。对静止瞄准场景，控制最后一帧、无持续GPU提交、交互唤醒的契约清晰；对动态场景，应减少真正的工作量，例如匹配画质的球影域、预计算、实例化、统一buffer及适当pass融合，而非只换 API。[官方 MTKView](https://developer.apple.com/documentation/metalkit/mtkview)

iOS17 原型使用传统 MTLCommandQueue / MTLCommandBuffer，按GPU family/feature表检查格式、MSAA和存储支持；**不能以 Metal4 为基础**。本机 `Metal.framework/Headers/MTL4CommandQueue.h:52` 与 `MetalKit/MTKView.h:170` 都标 iOS26。所谓 memoryless/pass fusion 优势也是设计与硬件条件，需要相同画质下实测，不能默认一定优于 SceneKit 或 Filament。[Apple GPU 特性表](https://developer.apple.com/metal/feature-sets/)

### Filament

查询并读取官方版本 tag，避免主分支漂移：v1.77.2，官方发布于 **2026-09-28 20:59:51 UTC**；GitHub API提供 `filament-v1.77.2-ios.tgz`（32,090,066 bytes压缩发行包，**不是App增加包体**）。[官方发布页](https://github.com/google/filament/releases/tag/v1.77.2)

官方 iOS 说明推荐 Metal、描述 Metal iOS11+及模拟器阴影限制；当前版本样例 `ios/samples/app-template.yml:10` deploymentTarget 为12.1，说明构建平台门槛覆盖17，**本轮未证明该发行包在本项目链接/运行成功**。集成路径是静态库/xcframework和 C++/Objective-C++，没有把社区Swift wrapper当官方低风险依赖。[官方 iOS样例说明](https://github.com/google/filament/blob/v1.77.2/ios/samples/README.md) [样例模板](https://github.com/google/filament/blob/v1.77.2/ios/samples/app-template.yml)

公开 API 已读原始头文件：

- `View.h:152,300,338–375,456,470,541,633,895–966`：render target、阴影、MSAA/AA/TAA、AO、bloom、动态分辨率及异步拾取均可配。[View API](https://github.com/google/filament/blob/v1.77.2/filament/include/filament/View.h)
- `Renderer.h:220,325–367,561–593`：帧调度配置、beginFrame的跳帧契约、render/readPixels/endFrame。readPixels官方警示明显成本，不能默认作为省电视频通道。[Renderer API](https://github.com/google/filament/blob/v1.77.2/filament/include/filament/Renderer.h)
- `Camera.h:169–172,237,337`：正交/透视及自定义projection。[Camera API](https://github.com/google/filament/blob/v1.77.2/filament/include/filament/Camera.h)
- `SwapChain.h:53–55,183–193`：CAMetalLayer与 Metal-only BGRA CVPixelBuffer，可调查直接送AVAssetWriter路径；资源Retain/Release有契约。[SwapChain API](https://github.com/google/filament/blob/v1.77.2/filament/include/filament/SwapChain.h)
- `MaterialInstance.h:162–200` 公开 uniform 数组；无需断言它只能单值设置。[MaterialInstance API](https://github.com/google/filament/blob/v1.77.2/filament/include/filament/MaterialInstance.h)
- `AssetLoader.h:116,178` gltfio资产加载；USDZ导入不能直接假定。[AssetLoader API](https://github.com/google/filament/blob/v1.77.2/libs/gltfio/include/gltfio/AssetLoader.h)
- `FilamentView.mm:29,49–52,71–76,90–104,118–138` 官方样例使用CADisplayLink/CAMetalLayer/ObjC++。样例默认60Hz不是框架强制连续渲染；应用负责暂停、页面拆除和resize。[官方 iOS View](https://github.com/google/filament/blob/v1.77.2/ios/samples/hello-pbr/hello-pbr/FilamentView.mm)

维护工作包括 matc / cmgen / gltfio 与运行库版本冻结、材质包编译、IBL/色调映射校准、对象销毁顺序、桥接线程所有权及真实新增包体审计。它有实际控制能力，不能凭“通用引擎”淘汰；但球迹已自编关键着色效果，成熟通用PBR的边际收益需证明。动态分辨率、换AA或关闭效果只能进入“同预算提高观感”的另一个实验，不能污染同画质能耗比较。

## 5. 迁移工作量：按工作面估算，不给无依据工期

| 工作面 | SceneKit优化 | Metal完整替换 | Filament完整替换 | RealityKit17完整替换 |
|---|---|---|---|---|
| 数据/物理求解 | 不改 | 保留值输入与输出 | 同左 | 同左 |
| 实时呈现消费者 | 局部热点修改 | 重写节点/动作消费、时间/取消 | 重写Entity/transform/动作适配 | 重写Entity/动画适配 |
| 相机与交互 | 保留 | 迁数值数学，投影/遮挡/拾取新适配 | 同左并处理异步pick | 正交缺口，不能统一 |
| 资产/材质 | 保留，算法验收 | 导入/纹理/法线/色彩/IBL、所有着色效果 | USDZ→glTF或网格；材质语言/PBR校准 | USD保留；CustomMaterial及传参重写 |
| 阴影与反射 | 优化现有公式 | 明确重实现 | 原公式移植或新效果画质批准 | 参数受限与原生效果差异 |
| 视频/图解/缩略图 | 保留 | 定时state+render+encoder重接 | 离屏swapchain/同步/encoder重接 | 确定性离屏缺口；保留旧引擎 |
| 生命周期 | 验已有停绘/唤醒 | 在途资源、resize、前后台、销毁全建 | Engine/View/SwapChain资源销毁与桥接 | 黑盒帧调度证据需补 |
| 验收 | 局部正确性+完整场景真机 | 图像/动态/输入/页面/视频全矩阵 | 同左+工具链/包体/许可证 | 全矩阵+双引擎一致性 |

这里“大/小”取决于触及契约数量，不能换算成人日。现有相机近距离投影、袋内透明度、球杆淡出、六袋皮革高亮、回球支架、时间结束和旧任务取消都是可观察产品行为；原型不是完整迁移。

若保持 SceneKit 导出而只移每日清台，短期可限制风险，但需要两套 GPU 资源缓存、两套材质校准、两套测试与后续修复。应明列双管线过渡期限和最终出口，不把一页更快直接称共享引擎替换完成。

Unity/Godot/Unreal 本轮不进入原型：没有已确认跨平台产品目标、大规模内容编辑或复杂游戏系统需求足以抵偿引擎运行时和原生桥接迁移。**不声称它们必然耗电更高**；有对应新产品需求时再重新评估。

## 6. 最小原型与可证伪问题

以下均是后续建议，本轮没有实施授权或实测结果。

**P0 共同夹具**：冻结视觉资产及带版本的静态数值几何/材质输入、相机矩阵、每个呈现时刻的球位/姿态/opacity、杆姿、袋高亮和回球状态。使用同一轨迹记录，物理不重复求解；建立真实全页与孤立renderer两种宿主，防止把UI/求解成本归错给引擎。静止、单球、多球开球、低机位、落袋、相机拖动、2D/3D切换、离屏导出分列。

**P1 SceneKit**：先实施已有方案允许的一个已证热点，每日清台以 **SCN-daily-R** 对当前生产 R 比较，按 R → 一项候选 → R 复测；共享消费者以 **SCN-shared-A** 单列比较，不混池。保留对应基线原采样/AA/分辨率。若判定剩余成本来自片元公式，把优先级转向算法研究，而非框架重写。首轮此处“原 A”的基线措辞已按交叉审计更正。

**P2 Metal**：一个独立渲染宿主，加载实际桌体/球/杆与房间，复现当前材质和同帧动态球影；两个真实投影；显式静止停绘；一个拖动拾取和一次落袋；输出一段同时间轴离屏视频。第一版原公式作为算法不变量，只回答“宿主/提交开销是否降低”。第二版允许画质等价的算法改变，单独回答“降低真正工作量是否可行”。两版不能混算收益。

**P3 Filament 条件竞争**：若 Metal 的通用PBR/资产维护成为主要风险，则用同夹具做 Filament prototype；关闭未在基线出现的后处理，显式同分辨率/AA。验证材质迁移、BGRA离屏、冷热资源、拾取延迟和已公布最低系统。以实际包体/启动/驻留内存说明依赖成本。

**RealityKit 重新进入条件**：用户接受把最低系统提升至18+，或接受明确长期双管线，并且实际证明其视觉/能耗/维护优势。18+仍需核实正交在所选宿主有效、明确frame采样/离屏进度和静止提交情况；API存在不是能耗结果。

## 7. 升级、放弃和证据停止条件

1. **升级到引擎迁移**：SceneKit现有同画质方案后仍不满足真实目标；残余热点归属明确；Metal/Filament在全页场景中重复配对收益超过基线波动且呈现P95/内存/启动无退化；画质和动态时序验收通过。只减少setter或command buffer时间不够。
2. **留在SceneKit**：经已授权优化后画质/长期使用目标达标；候选只在孤立renderer获益，或优势来自减采样/尺寸/帧率；没有稳定收益则结束迁移候选，记录实际瓶颈。
3. **放弃某原型**：需要重写物理才能表现等价、缺少正交或指定时刻离屏、动态阴影滞后一帧、iOS17无法上线、资源持续增长或两轮受控迭代仍无稳定全页收益。不可不断放宽画质或把“未来API可能支持”当完成。
4. **能耗用词**：没有整机瓦数/焦耳或合适的功耗测量证据，不说最低能耗。GPU busy/帧执行时间、CPU时间、thermal状态和表面温度分别报告；同画质“更快”仅是能耗可能下降的机制证据。

尚缺：当前冻结版本的受控真机GPU归属、完整实际呈现、页面占空比、长期热/功耗、三引擎同画质原型。**研究完成不等于这些验收已通过。**

## 8. 主控可复核的决定性命题

- RealityKit17：非AR与CustomMaterial成立；正交/RealityRenderer最低18是两个具体公开API缺口，不能泛化为不支持3D，也不能用最新WWDC覆盖版本差异。
- Filament：有实质公开控制和官方iOS发行路径，不是只有Android；候选被降低优先级的理由是本项目迁移/维护收益尚未证明。
- 专用Metal：拥有最多可解释控制，但**同公式搬家不自动降耗**；推荐对照验证而不是直接全量重写。
- SceneKit：现有集成成本最低且保留用户认可画面；弃用意味着规划退出路径，未支持“今天必须切换”的结论。

本文外部事实查询日期均为2026-10-02；动态Filament来源固定v1.77.2，Apple版本以官网markdown和本机availability双证据核验。未引用论坛传闻作为技术依据。

## 9. 交叉回应：将引擎迁移理由收紧到可测缺口

2026-10-02第二轮。已阅读 `pipeline.md` 和 `assets.md` 全文，并接收独立评审的反例。下面更新首轮的候选优先级解释，不以角色结论一致作为验证。本轮仍没有实现或性能/画质实测。

### 9.1 SCNProgram / SCNRenderer 已有控制后，专用 Metal 还增加什么？

**承认并修正推荐力度**：首轮“下一阶段用专用Metal原型”的建议应理解为受限条件下的挑战实验，不应自动排在保留SceneKit的SCNProgram/宿主对照之前。保留宿主已能验证很多此前看似必须迁移的机会。

主控和pipeline提出的两个能力成立，已独立读本机头文件核实：`SCNShadable.h:67–71` 指定program会覆盖对象原材质设置和shaderModifiers；`:273,280,290` Metal vertex/fragment与buffer binding标注 **iOS9**（不是把方法归为类iOS8）；`:23–26`支持frame/node/shadable频率。`SCNRenderer.h:57,70–77`又能让应用掌握更新时间和提交commandBuffer/passDescriptor。shader尾部、KVC接口与外部调度首先有更窄的调查路径。[SCNShadable](https://developer.apple.com/documentation/scenekit/scnshadable) [buffer binding](https://developer.apple.com/documentation/scenekit/scnprogram/handlebinding(ofbuffernamed:frequency:handler:)) [SCNRenderer](https://developer.apple.com/documentation/scenekit/scnrenderer)

专用Metal的**剩余新增控制面**是：按领域帧快照直接管理数据布局/实例提交，不再依赖SCNNode的呈现树和对象调度；完全拥有跨对象的pass编排、GPU缓冲/纹理驻留、在途同步与离屏输出，能联合优化算法和资源。这些机制可能消除SceneKit中仍存在的分类、遍历、内部pass或导入资源成本。**它们不是已经确认的瓶颈，也不是“SCNProgram不能绑定buffer/写完整shader”的证据。** SCNRenderer外部可控不代表应用控制其全部内部pass；反过来，内部控制缺失也不证明实际有多余pass。

| 可证伪命题 | 明确观测与对照 | 最强反例 / 不迁移条件 |
|---|---|---|
| H-M1：SceneKit节点/动作/材质提交仍消耗显著CPU | 当前R与优化SceneKit比较，保存完整页CPU栈、对象/分配/调用计数、输入延迟；同帧快照与同算法Metal再比 | SCNProgram/buffer binding与正确activity已把这些成本降至噪声；剩余是SwiftUI/物理或GPU积分。此时不靠引擎迁移处理 |
| H-M2：不可控制的内部pass/attachment导致可观GPU或带宽成本 | frame capture识别具体pass及其作用，证明画质不依赖；SCNProgram台呢和SCNRenderer宿主都无法去除，再用Metal移除该项 | pass实际必需，或SCNProgram已经消除；Metal只是漏渲染效果/降AA。此时不迁移 |
| H-M3：SceneKit资源布局/提交约束妨碍已证明有效的算法 | 同算法、同资产的两宿主比较实际draw/tiler/带宽/驻留；再将算法改动作为独立轴 | 现有compute+纹理或SCNProgram就能实现相同候选；收益来自算法，与宿主无关。保留SceneKit实现算法 |
| H-M4：现有宿主不能满足可验的呈现/离屏时序 | 对比SCNView、受控SCNRenderer和Metal实际present及指定时刻输出；运行交互/取消/resize和视频完整流程 | SCNRenderer中间路线已满足目标，或差异来自错误时间采样而不是宿主。停止完整迁移 |

**明确不迁移**：现有SceneKit生命周期、资源准备和最窄shader/宿主候选通过冻结画质及完整页目标后，结束以节能为理由的全量引擎迁移；不强行再做Metal原型求一个排名。只有余下受限项达到预先冻结的实用收益阈值，才扩大迁移。SceneKit弃用仍需长期兼容性监测和价值类型边界整理，但不能转化为无限期的省电重写。

### 9.2 Filament 为什么放在 Metal 后面，是否应该撤销新引擎动机？

首轮次序是本项目的**研究投入优先次序，不是效果/能耗实测排名**。不能据此称Filament“次优引擎”。它具备公开可用的PBR、阴影、正交、自定义材质、资源工具及离屏控制；iOS集成和发行也确实存在。若目标是新增完整通用PBR能力、支持多种动态灯/材质/后处理，Filament可省去自研大量基础工作，值得提前。

首轮先考虑Metal挑战的具体理由是，pipeline和assets都证明当前核心材质为领域自定义输出，房间为已照明constant，物理也独立。此时我们可以先保留既有MSL语义调查宿主开销，而Filament需先承担matc材质语言转换、USDZ/多索引转换、色彩/输出和桥接成本；它的默认PBR能力并不能保证复制球迹的已接受效果。**这一判断会被工程原型成本和视觉对照推翻，不是框架本身缺陷。**

| 判断 | 可以推翻它的证据 | 下一步 / 停止条件 |
|---|---|---|
| H-F1：专用Metal维护范围在本场景内可控 | Metal需要大量通用PBR、灯光、资产导入、后处理维护；Filament用受支持接口以较小差异实现相同材质/原生互动/视频 | 将Filament提前为首要替代候选。以真实工作面和部署维护计费，不猜工期 |
| H-F2：Filament标准渲染仍需大量自定义重做 | 使用其unlit/custom材质和公开参数能严格达到已冻结参照，且API/工具版本与17运行兼容验证完成 | 原“材质迁移较重”判断被削弱，重新比较两候选；不因我们已有MSL而排斥它 |
| H-F3：新宿主能带来值得付费的净收益 | 资产准备/LOD/现有宿主优化后已达目标，或所有候选差异在噪声内 | **撤销以能耗优化为目的的新引擎原型/迁移动机**；只保留长期弃用风险研究 |
| H-F4：大桌体是资源优化的主要机会 | assets约95%源等价复杂度来自两个桌mesh，但GPU实际由片元ALU限速，几何消融无稳定收益 | 不把源几何数量当结论。停止盲目减面，调查真正GPU热点 |

“大桌体/准备优化足够”要分别解释：离线probe主要解决冷进入峰值，不能单独证明10分钟动态能耗已达标；LOD若实际降低tiler/带宽并保持认可画质，又使完整页长期使用满足目标，则无需继续换宿主。若只是冷启动更快而动态帧仍受台呢积分限制，撤销的是“导入峰值必须换引擎”的动机，动态算法研究可以继续。

### 9.3 新候选与10-01既有方案的范围归属

既有方案固定生产区域为Core/Scene，保持物理、视觉资产、采样/精度、shader接口、相机与架构；其S1–S3重点是已确认重复工作和同公式计算复用。**画面看起来一样并不自动使一个候选属于既有方案。**

| 候选 | 是否能计入10-01原方案实施 | 本轮建议的归属与边界 |
|---|---|---|
| 同shader接口下减少已证重复读取/写入；原采样、浮点顺序与同帧语义不变 | 允许范围内，再按S0证据决定 | 原方案CPU/公式复用批次；收益只记真实变化 |
| 新SCNProgram替换台呢surface modifier | **不能自动计入** | 新shader管线/绑定候选；虽保留SceneKit，也覆盖原material/modifier行为，应另卡冻结输出空间、材质、阴影和iOS17边界 |
| `SCNRenderer + MTKView`替代现有SCNView宿主 | **不能自动计入** | 新宿主/调度候选；动作更新、帧时钟、输入/resize/取消与页面生命周期均需独立验收 |
| 桌体LOD、分区、衍生USDZ、删源纹理、换GPU格式 | **不属于原固定资产/精度范围** | 新资产候选，保留母版和物理数值几何；LOD/压缩是画质预算路线，不能默认位等价 |
| 新离线probe/SH/GGX/LUT资源与版本化加载 | **不自动属于原方案** | 新资源准备/缓存候选；冻结算法、色彩、键/失效及输出对拍，重点验冷成本；不能顺便改房间尺寸/灯光/反射模型 |
| 对同一未改资源已有准备过程做已证等价的代码级去重/预热调度 | 可在确认不突破固定边界后纳入 | 仍需任务卡指明和失败传播/线程时序核实；不拿“离线化”泛称遮盖资源格式变化 |
| LTC、S/RS、降采样、shadow texture重采样、half等近似 | **不属于保持原公式/精度路线** | 独立画质预算研究；必须先取得明确参照和相应质量验收，不冒称原方案完成 |

本轮用户授权是研究与讨论，上表都是后续候选归属建议，没有把它们变为已批准生产实施或已验证收益。

### 9.4 对首轮与评审措辞的修正

- §6的“P1对比原A”容易误导，正式执行应为**每日清台当前生产R → 一项候选 → R复测**；共享消费者按其真实A基线单独比较。A/reference只能是明确标注的算法/其他消费者参考，不能作为每日迁移收益的基准。
- “推荐SceneKit”是当前已有画质/集成、迁移风险与证据成本下的近期开工路线，并没有证明其画质最好或能耗最低。
- RealityKit17不适合统一替换源于两个具体能力边界，**不是已证明能耗劣势**。非AR、CustomMaterial和ARView后处理能力仍成立。
- 真机Power Profiler的数值不能自动标瓦数/焦耳；测量口径遵循独立评审，能耗代理与实际呈现/热状态分列。本轮不增加任何“实测省电”声明。

下一轮可决策的不是“四个名称谁赢”，而是：先验证哪一项可观察成本；哪项最窄候选能去掉它；在现有宿主无法完成且净收益足以偿还迁移成本时，才让完整引擎替代进入实施。
