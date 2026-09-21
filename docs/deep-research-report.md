# iOS 台球专用高画质低功耗 Renderer：Visual Fidelity / Watt 深度研究报告

## Executive Summary

> 证据标记：**[官方事实]** = Apple/Qualcomm/厂商公开资料；**[公开案例]** = 可核查的游戏/引擎技术分享；**[合理推断]** = 从架构与项目数据推导；**[本项目建议]** = 针对这个台球 App 的设计结论。
> 性能百分比如果没有公开 benchmark 或你自己的 A/B 数据，本文不会把它写成既成事实。

1. **最大的架构机会不是“更低分辨率”，而是“不画不需要画的帧”。** 你的场景大量时间相机、球、灯光、房间全部不变，因此“持续 60 FPS 全场景 redraw”在 Visual Fidelity/Watt 上是根本错误的工作模型。MTKView 本身提供 `isPaused` 与 `enableSetNeedsDisplay` 这类按需绘制机制；Apple 当前的游戏性能方法也把长时间功耗、thermal state 和 sustained performance 放到核心位置。**静止时应让 3D renderer 进入 0-command-buffer 的 idle，而不是把一张缓存纹理继续每秒画 60 次。** citeturn22view0turn22view1turn20view4

2. **每个球面像素约 64 次环境反射采样，是当前架构中最值得直接删除的设计之一。** 如果这 64 次是在运行时对环境做 GGX/importance sampling，那么它本质上是在每帧重复一个非常适合预积分的积分。实时 PBR 的经典方案是 prefiltered environment map + split-sum IBL + BRDF/DFG LUT：昂贵积分搬到离线/预处理阶段，运行时通常只需一个或少数 cubemap fetch 加一个 LUT。Brian Karis 的 UE4 SIGGRAPH 工作是这一模式的经典来源。citeturn22search10 **[本项目建议]** 对树脂球采用“1 次 prefiltered cubemap + 1 次 BRDF LUT + 1 个廉价直接高光”，必要时再做 box projection；不要保留 64-tap 路径作为默认。

3. **球影是已经有项目实证的 P0。** 你自己的数据表明关闭直接球影后 GPU frame time 曾下降约 **24%**。这比任何理论分析都更有价值。固定球半径、球心高度、台面、灯具的场景根本没有必要让每个阴影像素做约 `8×4=32` 次面积光采样。**[本项目建议]** 改成球体到平面的解析投影 + analytic 2D SDF/ellipse + 预拟合 penumbra LUT；它可以保留接触硬化和宽柔边，但把 32-tap 阴影积分从实时 fragment shader 中移除。

4. **Apple GPU 上首先应该减少 System Memory traffic，而不是把 TBDR 当成“带宽免费的 GPU”。** Apple 明确说明其 GPU 是 TBDR：有 on-chip tile memory，但最终资源仍位于统一系统内存；每个 tile 会执行 load、可见性/fragment 工作和 store。Apple 还明确建议合并 render encoder，因为多余 pass 会增加 memory bandwidth；`memoryless` attachment 专门用于只存在于片上 tile memory 的临时 render target。citeturn23view1turn20view1turn20view2

5. **4× MSAA 不应成为第一批牺牲品。** 在你的画面里，球轮廓、球杆和桌边是高价值几何边缘。正确方向首先是让 multisample color/depth 成为 memoryless transient attachment，只 resolve 一次，depth 不需要就 `.dontCare` store，MSAA surface 本身不要回写内存。Apple 明确提供 `multisampleResolve` 与 `storeAndMultisampleResolve` 等语义。citeturn20view0turn20view1 **2×/4× 应 A/B，而不是默认“优化成 2×”。**

6. **最合适的主 renderer 是非常窄的 specialized forward renderer，而不是通用 deferred/Forward+。** 你只有极少动态对象和极少灯光；G-buffer、复杂 light list、通用 shadow atlas、实时 reflection probe 更新都是多余自由度。Fortnite 的公开 GDC 移动渲染资料也显示其移动路径使用过 Forward Renderer，但这只能作为“顶级商业移动项目采用专用移动路径”的定性案例，不能据此推断你的具体实现。citeturn18search0turn18search15

7. **2D 俯视模式应该和 3D simulation 共用状态，但不要共用完整 3D render path。** 一个真正的 2.5D renderer 可以把球桌变成预烘焙背景，把每个球变成 procedural sphere impostor，把球影变成解析 SDF quad，球杆变成 capsule/quad；甚至仍然可以根据球的实际旋转重建 sphere UV，所以不必退化成“假 2D”。它直接删除房间、深度复杂度、通用材质、昂贵反射和通用阴影等整类工作。

8. **GPU frame time 不是热量的充分指标。** Apple 的 GPU Counter 能分别看到 ALU、Texture Sampler、Tile Memory Load/Store、main-memory bytes、occupancy、fragment invocations 等；Apple 当前 iOS 工具还提供 Power Profiler 的 CPU/GPU/display power impact。Apple 特别强调 long gameplay measurement，而不是只看一个冷机 GPU ms。citeturn20view3turn23view1turn20view4turn23view4 Qualcomm 对移动 tile architecture 的公开资料也直接把减少 memory bandwidth 与 low-power 设计联系起来。citeturn13search0turn13search2

9. **MetalFX / Dynamic Resolution 应是最后的 thermal safety valve，而不是解决这个问题的第一性架构。** Apple 官方确实把 MetalFX 作为减少渲染像素、提升性能/功耗效率的手段，并支持动态 resolution change；但你的 renderer 有大量更“无损”的特殊化空间，应先消灭 64-tap reflection、32-tap shadow、静态 redraw 和全 3D top-view。citeturn20view5turn23view4turn23view5

**一句话的最终架构结论：**

```text
                 Scene / Simulation State
                         │
                    Dirty Graph
       ┌─────────────────┼──────────────────┐
       │                 │                  │
    Static Idle       3D Dynamic        Top-View 2.5D
   no 3D frame            │                  │
       │                  ▼                  ▼
 UI / Aim only      Baked Static World   Baked Table
       │            + Specialized Balls  + Sphere Impostors
       │            + Analytic Shadows   + SDF Shadows
       │            + Prefiltered IBL    + Procedural Cue
       │                  │                  │
       │          Single Forward HDR Pass    │
       │          memoryless MSAA/depth      │
       │                  │                  │
       └──────────────► Resolve ◄────────────┘
                          │
                     Tonemap / EDR
                          │
                    UI / Aim Overlay
                          │
                       Present
```

这比“把当前通用 3D renderer 再调快 20%”更接近顶级移动团队会采用的方案。

## 行业顶级移动 Renderer 的共同原则

**原则：把工作留在 tile/on-chip，只有真正需要跨 pass 存活的数据才进入系统内存。** Apple 对其 GPU 的描述非常明确：Apple GPU 是 tile-based deferred renderer；tiling 阶段处理几何并 bin 到 tiles，rendering 阶段逐 tile 做 load、visibility、fragment processing 和 store。GPU core 拥有 dedicated tile memory，资源最终则位于 unified system memory/DRAM。Apple 因此把 memory bandwidth、tile load/store、texture/buffer reads 都作为核心 GPU counters。citeturn23view1

这也是为什么 Apple 的 Metal Best Practices 明确要求：

- 不需要保留 render target 内容时，使用 `.dontCare`；Apple 文档直接说明这种 action “没有相关成本”。
- multisample texture 只要 resolved 结果时，使用 `multisampleResolve`，而不是把 multisample surface 也 store。
- 尽量合并 compatible render encoders；Apple 明确指出，删除不必要的 encoder 可以减少 memory bandwidth 并提高性能。
- 临时 attachment 可以使用 iOS 的 `.memoryless` storage，使其只存在于 on-chip tile memory。citeturn20view0turn20view1turn20view2

这几个原则对你比“大场景 occlusion system”重要得多。

**Qualcomm/Adreno 得出了相同的移动端设计方向。** Qualcomm 的官方开发资料明确说明 Adreno 为 low-power、memory-bandwidth-limited devices 使用 tile-based rendering；Qualcomm 2026 关于 Tile Memory Heap/HPM 的资料又明确把“让数据保留在 GPU 本地”与降低 memory bandwidth 和 power 联系起来。它不是 Apple API 建议，但说明这种“片上局部性优先”不是 Apple 独有的特殊癖好，而是移动 GPU 的普遍经济模型。citeturn13search0turn13search2

Arm 方面，本次检索找到了官方 Mali GPU/OpenGL ES application development guide 与相关 rendering-strategy 资料入口，但没有获得足以支撑本文具体百分比的公开定量 benchmark；因此本文**不把任何具体 bandwidth/power 百分比归因于 Arm**，只把其 tile/mobile rendering 指南作为定性旁证。citeturn11search0

**原则：先查真正的 limiter，不能因为 shader 很长就武断认定 ALU-bound。** Apple 的 GPU counter 工作流首先看 Performance Limiters。一个 64-sample reflection shader可能是 Texture Sampler-bound，也可能因为 GGX importance sampling、normal transforms、LOD/BRDF 数学而变成 ALU-bound，甚至可能受 memory/cache 与 register pressure 共同影响；只看 shader 源码不能可靠判定。Apple 的工具能够看到 ALU、texture read/write、tile load/store、buffer traffic、LLC、occupancy 等，而且支持 encoder/draw-call 级关联。citeturn20view3turn23view0

Apple 在 WWDC20 的公开案例很值得借鉴：Digital Legends 的 *Respawnables Heroes* 一个旧 build 在 GPU Capture 中约为 **12.82 ms GPU time**；Apple 团队发现 deferred phase 的 ALU 压力以及一个 `RGBA16Float` cubemap 的 memory traffic，随后使用更多 FP16 和 block-compressed texture 等多项优化，Apple 报告最终游戏可以在 iPad Pro 上稳定运行 **120 FPS**。Apple 没有公布每项优化分别贡献了多少，因此不能把 120 FPS 归因于某一个技巧。citeturn23view0turn23view1

这还有一个与你高度相关的细节：那个案例正好发现了 **floating-point cubemap** 带宽问题。Apple 直接建议检查 main-memory bytes 和 texture traffic，并指出 block-compressed HDR environment map 能显著降低 footprint/bandwidth。citeturn23view1 对一个大量读取环境 cubemap 的台球 shader，这比“减少几百个三角形”更值得优先审计。

**原则：预积分稳定的光照，而不是每个像素重新积分。** 实时 PBR 领域经典的 split-sum IBL 把环境光的 specular convolution 预过滤进 roughness mip chain，并把剩余 BRDF 部分预积分成 LUT；Brian Karis 的 *Real Shading in Unreal Engine 4* 是这一工程模式最经典的公开来源之一。citeturn22search10

你的场景甚至比通用 UE4 场景更适合这样做，因为：

- 房间基本固定；
- 台面固定；
- 灯具基本固定；
- 球半径和球心高度固定；
- 树脂球 roughness/F0 的自由度很小；
- 球只是位置、旋转、视角发生变化。

换句话说，**一个顶级团队不会只把 UE/Unity 的通用 PBR 搬过来，而会进一步“编译掉”这些固定自由度。**

**原则：对持续性能优化的是 Energy/Frame × Frames/Second × Time，而不是单帧最快。** Apple 2025 的官方游戏性能方法明确要求先在 long gameplay period 中观察，再对局部问题用 Metal tools 分析，最终才做 power 和 device scaling；Metal Performance HUD 会显示 frame pacing 和 thermal context，iOS Power Profiler 则能观察 CPU、GPU 和 display power impact。citeturn20view4turn23view4

因此两个 renderer 即使都是 60 FPS、都是 6 ms GPU，也可能有完全不同的发热表现：

```text
Renderer A:
6 ms GPU
大量 DRAM traffic
高 texture activity
每秒固定执行 60 次
静止也执行

Renderer B:
6 ms GPU during interaction
低 attachment traffic
预过滤 texture
静止时不提交 GPU frame
```

对于你的使用模式，B 的 session-level energy 很可能远低于 A。这里“很可能”是**架构推断**，最终必须由 Power Profiler 和 30 分钟 thermal test 验证。

**原则：移动版可以拥有与桌面版完全不同的 rendering path。** Fortnite 在 GDC 2019 的公开移动图形资料中列出了 mobile Forward Renderer；Samsung 同期也公开确认与 Epic 合作进行了 Fortnite mobile 的技术工作。公开资料只能支持“Fortnite 有专用移动渲染路径/Forward path”这一层，不能用来声称它内部用了与你相同的 reflection/shadow 技术。citeturn18search0turn18search15

对于你列出的其他商业游戏，本次研究的证据边界如下：

| 游戏 | 本次检索得到的可信公开 renderer 证据 | 是否足以推断本项目技术 |
|---|---|---|
| Fortnite Mobile | 有 GDC/Khronos/Samsung 的移动渲染公开资料，可确认 Forward mobile path | **部分可参考** |
| 王者荣耀 | 找到 Qualcomm/Honor of Kings 公开活动，但检索到的当前材料重点是 on-device AI，而非本文需要的 renderer internals | **不足** citeturn18search2 |
| PUBG Mobile | GDC Vault 能检索到 PUBG Mobile 技术分享，但本次找到的具体条目与可破坏系统等相关，不能证明 reflection/shadow 架构 | **不足** citeturn18search1 |
| Genshin Impact / 崩坏：星穹铁道 | **没有找到足够可信、可核实的一手公开资料来支持本文所需的移动 reflection/shadow/power pipeline 结论** | **不推测** |
| Delta Force Mobile | **没有找到足够可信公开 renderer internals** | **不推测** |
| COD Mobile | **没有找到足够可信公开 renderer internals** | **不推测** |
| Warframe Mobile | **没有找到足够可信公开资料支撑本文具体技术结论** | **不推测** |
| Resident Evil / Death Stranding iPhone | Apple 有 high-end game/iPhone porting 与 MetalFX、sustained-performance 方法资料，但本次没有找到可靠公开材料披露这些游戏各自具体的 reflection/shadow implementation | **只参考平台方法，不推测内部 renderer** citeturn23view5 |

这是一个重要结论：**不应把“某 AAA 游戏在 iPhone 上运行”倒推出它一定用了某种 shadow、SSR 或 probe 技术。**

## 当前台球 Renderer 最可能的瓶颈排序

这里需要分两种排序：

**动态帧 GPU 时间排名**，即球在移动、相机在操作时什么最可能让一帧变贵；

**整段训练 session 的能耗排名**，即什么最可能真正让手机持续发热。

两者并不完全相同。

| 优先级 | 模块 | 判断 | 依据 |
|---|---|---|---|
| **P0** | 持续静态 redraw | Session Energy 第一嫌疑 | 大量时间世界完全不变，却仍可能每秒提交完整 3D frame |
| **P0** | 球影 8×4 area-light sampling | 已证实高成本 | **项目实测：关闭直接球影 GPU frame time 曾下降约 24%** |
| **P0** | 球面约 64 次 environment sampling | 极高风险 | 与 prefiltered/split-sum 方向相反；成本与 visible ball pixels 直接相乘 |
| **P0** | Top-view 仍跑完整 3D renderer | 结构性浪费 | 俯视模式删除不了 room、full PBR、shadow/reflection 等整类成本 |
| **P1** | HDR + 4× MSAA attachment/store/resolve | 必须审计，不应盲删 | Apple TBDR 上是否昂贵强烈取决于 memoryless、store action、pass 边界 |
| **P1** | 多 render pass / intermediate texture | 可能直接推高 bandwidth | Apple 明确建议 merge encoders 以降低 bandwidth citeturn20view2 |
| **P1** | 默认实时 SSAO / 全屏后处理 | 静态场景价值低 | Apple HSR 对 opaque 有利，但 full-screen pass 本身仍产生 fragment/attachment 工作 citeturn23view0 |
| **P1** | RGBA16F 环境纹理/中间 texture traffic | 需 GPU Counter 验证 | Apple 公开案例直接发现 float cubemap 的 bandwidth 问题 citeturn23view1 |
| **P1** | Shader precision / register pressure | 次于算法级删除，但值得做 | Apple WWDC20 示例中 FP16 throughput 高于 FP32；occupancy 还会受内部资源影响 citeturn23view0turn21view3 |
| **P2** | draw-call batching / 16 球 instancing | 好做但不应抢 P0 资源 | 对 <= 十几个球，CPU/draw 数不会天然成为最大 fragment bottleneck |
| **P2** | occlusion culling | 很低 ROI | 世界极小且固定；Apple GPU 本身有 opaque HSR citeturn23view0 |
| **P2** | Forward+ / clustered lights | 基本不需要 | 灯光数量极少，通用多灯管理解决了不存在的问题 |
| **P2** | VRS / variable shading | 可研究但不应成为主方案 | 你的收益远小于直接删除静态 frame、64-tap reflection 和 32-tap shadow |
| **P2** | MetalFX / dynamic resolution | thermal fallback | Apple 官方支持并强调其性能价值，但不应该掩盖当前算法浪费 citeturn23view4turn20view5 |

### 哪些指标最可能与“发热”直接相关

**GPU frame time：重要，但不够。** 它回答的是“GPU 完成这一帧用了多长时间”，并不直接告诉你这一时间里 ALU、texture unit、system memory、tile stores 分别消耗了多少功率。

**Main-memory / DRAM traffic：非常重要。** Apple 将 Memory Bandwidth 作为核心 counter，并建议只 load 当前 pass 需要的数据、只 store 后续 pass 需要的数据；Qualcomm 也把减少 memory bandwidth 与移动端 power optimization 直接联系起来。citeturn23view1turn13search2 对你的 renderer，应特别检查：

```text
Bytes Read From Main Memory
Bytes Written To Main Memory
Texture read traffic
Tile memory load/store
HDR intermediate writes
MSAA stores
Resolve traffic
cubemap traffic
```

**Fragment workload：非常重要，而且很可能比 vertex workload 更关键。** 这是针对你项目的推断：场景只有桌子、房间、十几个球，但每个球面像素最多执行 64 次反射处理，shadow 像素又执行约 32 次灯光采样，因此 fragment work 明显比“再减少几百个球体 vertices”更值得调查。Apple GPU Counter 可以直接比较 fragment invocation、pixels stored、ALU、texture limiter 等。citeturn20view3turn23view0

一个非常有用的项目级公式是：

```text
当前球面环境采样 / frame ≈ VisibleBallPixels × 64

60 FPS 时：
环境采样 / second ≈ VisibleBallPixels × 3,840
```

若改成：

```text
1 × prefiltered cubemap
1 × BRDF LUT
```

那么**仅“环境采样次数”这一项**从 64 降到 2，即降低：

```text
(64 - 2) / 64 = 96.875%
```

即使保留 2 个 cubemap fetch + LUT，总环境相关 fetch 也比 64-tap 路径少一个数量级。**这不是“GPU frame time 降 96.9%”**；球只覆盖部分屏幕，而且旧 shader 同时包含 ALU、cache、其他材质工作。但它足以说明这里有算法级别，而不是微优化级别的机会。

同理：

```text
当前球影核心采样数 ≈ ShadowPixels × 32
```

解析 SDF 方案可以把“面积光 Monte Carlo/离散积分”的实时采样项变成 0，或只保留 1 次 penumbra LUT。这里的采样层面也是约 **96.9%–100% 减少**，但最终 whole-frame 收益应以你已有的 **24% shadow-off delta** 为上界参考，而不是把采样比例直接当成 frame-time 比例。

**Texture utilization：对 reflection 特别关键。** 64 个 cubemap samples 即使部分 hit cache，也可能让 texture unit、L1/LLC 与 memory hierarchy 保持高活动；但若每次 sample 还伴随 GGX/Hammersley/random-direction 计算，也可能反而 ALU-bound。Apple 明确要求通过 limiter counter 判断，而不是猜。citeturn23view0turn23view1

**Register pressure / occupancy：需要看，但不要把“occupancy 越高越好”当 KPI。** Apple 明确说明高 occupancy 或低 occupancy 本身都不必然代表问题；低 occupancy 可能来自 shader 耗尽内部资源，也可能只是 workload 本身不需要更多并发。应该把它和 ALU、texture、memory limiter 一起看。citeturn21view3

**CPU frame time 也可能产生明显热量。** 如果静态画面仍每秒做 scene traversal、uniform update、physics-to-render sync、command encoding、drawable acquisition 和 present，那么即便 GPU shader 已变轻，CPU 仍有持续工作。顶级方案应让“scene static”同时停止**CPU renderer update 与 GPU submission**。

**Drawable / frame pacing 也属于功耗架构。** Apple 建议 drawable 尽量晚获取、尽快释放，因为 drawable 数量有限，等待可用 drawable 会阻塞 CPU；Apple 也明确把 stable presentation/frame pacing 作为目标。citeturn2search8turn2search4

所以你的热量 audit 不应只是：

```text
GPU ms?
```

而应该是：

```text
CPU ms / GPU ms
        +
ALU / Texture limiter
        +
Fragment invocations
        +
Main-memory read/write
        +
Tile load/store
        +
Render-target bytes/frame
        +
Command encoders / passes
        +
Frames actually rendered / second
        +
Power Profiler CPU/GPU impact
        +
Thermal state over 30 min
```

## 推荐的最终架构

我会把 renderer 从“普通小型 PBR 游戏场景”改造成一个**状态驱动的台球专用 renderer**。

```text
┌───────────────────────────────────────────────────────┐
│                  Physics / Game State                 │
│ position / rotation / cue / camera / training state  │
└──────────────────────┬────────────────────────────────┘
                       │
                 Render Dirty Graph
                       │
       ┌───────────────┼─────────────────────┐
       │               │                     │
 world dirty?      overlay dirty?        top view?
 camera dirty?     aim line?                 │
 ball dirty?       UI only?                  │
       │               │                     │
       ▼               ▼                     ▼
 Full 3D Frame   Overlay-only update    2.5D Renderer
       │                                     │
       ▼                                     ▼
┌──────────────────┐                ┌──────────────────┐
│ Static World     │                │ Baked table      │
│ baked lighting   │                │ background       │
│ baked AO         │                └────────┬─────────┘
└────────┬─────────┘                         │
         │                           sphere impostors
 analytic shadow quads                       │
         │                           analytic shadows
         ▼                                   │
┌──────────────────┐                         │
│ Ball Specialized │                         │
│ Shader           │                         │
│                  │                         │
│ Prefiltered IBL  │                         │
│ BRDF LUT         │                         │
│ direct highlight│                         │
└────────┬─────────┘                         │
         │                                   │
      Cue / rare dynamic geometry            │
         │                                   │
         └───────────────┬───────────────────┘
                         ▼
             Main HDR Forward Render Pass
             memoryless MSAA / depth
                         │
                    single resolve
                         │
                     tonemap
                         │
             separate UI / aim overlay
                         │
                       present
```

Apple 对 tile memory、memoryless attachment、load/store 与 encoder merging 的官方建议正好支持这种“少 pass、短 attachment lifetime、一次 resolve”的设计。citeturn20view0turn20view1turn20view2turn23view1

**Static World。** 房间、桌体、台呢、木框、皮袋的光照自由度极低，因此 diffuse/indirect component 尽量 bake。真实运行时主要保留 camera transform、球、球杆以及少量必要的 view-dependent specular。SSAO 对固定世界尤其不划算：固定桌体/房间 AO 应直接进入 lightmap、vertex data 或 baked texture；球-桌接触暗化由专用球影解决。这里无需通用实时 SSAO。

**主场景用 Forward，而不是 Deferred。** 一两个主要灯，不需要大 G-buffer；Forward+ 也没有足够多 lights 来回收它自己的管理成本。目标不是实现“最先进的通用 engine”，而是构造最低状态空间的 renderer。

### 球面反射的专用设计

你的 64-sample 路径应该被拆成三个视觉任务，而不是继续用一个昂贵 Monte-Carlo-like shader 一次性解决：

```text
环境整体形状
    → prefiltered environment cubemap

树脂 Fresnel / roughness response
    → preintegrated BRDF LUT

头顶灯具的高亮与“树脂感”
    → one cheap direct specular / fitted area-light highlight
```

**环境层。** 房间 reflection probe 离线/加载期生成 GGX-prefiltered mip chain。运行时：

```metal
R = reflect(-V, N)
lod = roughnessToMip(roughness)
env = sample(prefilteredProbe, R, lod)
dfg = sample(brdfLUT, float2(NdotV, roughness))

specularIBL = env * combineFresnel(F0, dfg)
```

经典 split-sum IBL 的核心就是把这个积分预先分离/预过滤，而不是每个可见 fragment 再取几十个环境样本。citeturn22search10

对于你的球，甚至可以再进一步：

- 树脂球 roughness 范围很窄，可以使用非常少的 roughness mip 区域；
- F0 基本是固定 dielectric material parameter，可以做 shader specialization；
- 若 roughness 最终确定为一个固定值，2D BRDF LUT 甚至可以实验性简化成 `N·V → response` 的 1D LUT；
- normal、view vector 和反射 vector 保留精度，而很多材质中间项可尝试 `half`；Apple WWDC20 的硬件示例明确指出 FP16 算术 throughput 高于 FP32，但应以当前设备 counter 和图像误差为准。citeturn23view0

**Local reflection。** 球高度完全固定是一个巨大优势。不要做实时 SSR 或每球动态 reflection probe。建议顺序是：

```text
优先：
Single static probe
    +
box/parallax correction

如果桌边局部 parallax 仍明显：
2～4 个 table-space static probes
    +
按球心位置选择/极低成本 blend

仍然不够：
为木框/灯具增加独立 analytic/local term

不推荐：
per-ball realtime cubemap
SSR
64-sample runtime environment integration
```

SSR 在这里通常是错误的交换：为了十几个小球上的反射，引入 depth/history/intermediate texture、屏幕外缺失和 temporal invalidation。**[本项目建议]** 只有当 A/B 明确证明某个重要局部反射完全无法由 probe/parallax correction 重建时才考虑。

**直接高光。** 树脂球“看起来贵”的核心往往不是 64 个 environment samples，而是清楚的 ceiling-light shape、Fresnel edge 和局部高光。对于固定灯具，可以用一个经过离线高质量参考图拟合的 closed-form/lookup specular response，而不是 32/64 个随机采样。这样做的原则是：

> **用有限的计算预算直接拟合人眼识别“树脂球”的关键 cue，而不是用大量积分去追求通用物理正确。**

这是高度约束场景最值得利用的地方。

### 球影的专用设计

这里不建议 shadow map + PCSS，也不建议全局 SDF。**最适合的是“解析投影几何 + 解析 2D SDF + 离线拟合 penumbra”。**

对于 directional light，半径为 `r` 的球体沿固定方向投到平面，轮廓是椭圆。令球心为：

```text
C = (cx, cy, r)
```

光线投影方向为单位向量：

```text
d = (dx, dy, dz)
```

则投到 `z=0` 平面上的中心可以由直线和平面交点直接计算：

```text
Pxy = Cxy - (r / dz) * dxy
```

投影椭圆的一个半轴保持约 `r`，沿 light tilt 方向的另一个半轴会按 `1 / |dz|` 拉伸。这是简单的解析几何结果；无需 shadow map。

然后 fragment shader 不再做：

```text
for light sample in 32 samples:
    trace/test...
```

而是做类似：

```text
local = shadowTransform * (worldXY - shadowCenter)
sd = ellipseSDF(local)

contact  = contactProfile(sd)
penumbra = penumbraProfile(sd)

shadowAlpha = combine(contact, penumbra)
```

为了模拟矩形面积灯而不是理想方向光，推荐**离线生成 ground-truth**：

```text
Offline:
固定球半径
× 固定高度
× 实际 ceiling rectangle
× 若干 table XY positions
× 1024/4096 light samples

→ 拟合：
ellipse transform
contact width
penumbra width
peak opacity
asymmetry parameter
```

运行时每球只需要一小组参数。

因为球半径、高度和灯具都不变，这些参数甚至可以变成：

```text
table position → shadow parameters
```

的小 LUT。

这比 runtime temporal accumulation 更合理：你已经知道完整问题空间，为什么要每次播放时再通过多帧噪声收敛？

最终一个球影建议只需一个 instanced quad：

```text
16 balls
→ 16 projected quads
→ one draw call
→ analytic ellipse SDF
→ optional 1D LUT
→ alpha blend
```

接触部分和柔边可以在一个 shader 中完成。

**PCF / PCSS** 可以保留给真正不符合解析模型的物体，例如球杆或极少量动态 room geometry；不要让十几个数学上完全相同的球走通用 shadow atlas 路径。

你已经有一个非常强的收益估计锚点：

```text
Current full frame     = 100%
Shadow disabled        ≈ 76%
Measured shadow delta  ≈ 24%
```

新 analytic shadow 不会免费，因此不能承诺 24%。但一个合理的 A/B 成功目标是：

> **恢复 shadow-off delta 的至少一半，同时视觉上与 reference shadow 难以区分。**

也就是项目验收目标约为 **whole-frame GPU time -12% 或更多**；这是**工程目标，不是已测结果**。如果它最终回收 15–20 个百分点，也并不意外，但在真机数据出来之前不应写成预期事实。

### 静态状态的 Renderer Scheduler

这一部分可能是 session-level Visual Fidelity/Watt 最大的提升。

状态机建议：

```text
STATE_MOVING
balls moving / camera moving
→ full 3D at 60 Hz

STATE_CAMERA_SETTLING
camera inertia / zoom
→ full 3D at display cadence

STATE_AIM_ONLY
world/camera/balls unchanged
aim line / guides updating
→ cached 3D + overlay only

STATE_UI_ONLY
3D completely unchanged
UI animation only
→ UIKit / Core Animation layer only

STATE_IDLE
nothing visual changed
→ MTKView paused
→ no command buffer
→ no drawable
→ no 3D CPU update
```

MTKView 官方 API 暴露 `isPaused` 和 `enableSetNeedsDisplay`，因此按需 invalidate 是 MetalKit 支持的使用模型，而不是 hack。citeturn22view0turn22view1

这里最重要的技术细节是：

**不要把“event-driven”错误实现成：**

```text
static 3D scene
→ copy to texture
→ every 16.67 ms draw fullscreen cached texture
→ present
```

这依然每秒：

- acquire drawable；
- encode command buffer；
- sample texture；
- shade native-resolution fullscreen pixels；
- store drawable；
- present。

它只是把复杂 3D frame 变成了一个仍然持续耗电的 full-screen pass。

更好的顺序是：

```text
首选：
完全不提交新 frame

只有 aim/UI 变化：
由独立 overlay layer 更新

只有必须在 Metal 内进行 depth-aware overlay 时：
缓存 resolved color/depth
+ 小型 overlay path
```

也就是说，**cache texture 是第二优先级；“根本不 redraw”才是第一优先级。**

UI 与 3D 应当逻辑/合成上分层。瞄准线如果只是桌面空间几何，可以直接：

```text
world table coordinate
→ existing camera matrix
→ screen coordinate
→ 2D overlay
```

它不需要重跑 room PBR、cubemap、球影和 tonemap。

如果 aim line 必须被球遮挡，也不代表必须 full redraw。你可以缓存 scene depth/ball screen masks，或根据球的 screen-space circle analytically clip aim overlay。

### 俯视模式的独立 2.5D Renderer

这应该是正式 architecture，不是 quality preset。

```text
Shared:
physics
ball transforms
ball rotations
cue state
training logic

3D renderer:
perspective experience

2.5D renderer:
top-down training experience
```

2.5D table：

```text
one/few baked textured quads
```

2.5D ball：

```text
one screen/world-aligned quad per ball

local xy inside unit circle
z = sqrt(1 - x² - y²)
N = normalize(x, y, z)
```

于是仍然得到**真正的球面 normal**，而不是平的 sprite。可以继续计算 Fresnel、高光和一个 prefiltered environment sample。

更进一步，球的条纹和号码也不用固定在 sprite 上。利用真实 ball rotation matrix，把 impostor ray 命中的 local normal 逆变换回球体 object space，再从 sphere coordinates 获取 UV：

```text
screen impostor hit
→ reconstructed sphere normal
→ inverse ball rotation
→ spherical UV
→ existing ball texture
```

这样 top view 的球在滚动时仍然拥有正确的号码/条纹旋转，但完全不需要真正 rasterize sphere geometry。

球影：

```text
analytic SDF ellipse
```

球杆：

```text
procedural capsule / textured quad
```

房间：

```text
不存在
```

general 3D shadow map：

```text
不存在
```

generic reflection path：

```text
不存在或极简
```

因此它节省的不是某个 shader 的 10%，而是**删除整类 rendering work**。

### Main render pass 与 attachment 布局

一个合理目标：

```text
Render Pass: Scene
  colorMSAA      = memoryless, HDR, 4x
  depthMSAA      = memoryless, 4x
  resolvedHDR    = private single-sample

  load:
    color = clear/dontCare as appropriate
    depth = clear

  draws:
    static opaque
    analytic shadow quads
    balls
    cue

  store:
    colorMSAA → multisampleResolve only
    depth     → dontCare

Render Pass: Final
  input:
    resolvedHDR

  output:
    drawable

  operations:
    tonemap / EDR transform
    minimal final composition

UI:
  separate overlay where practical
```

Apple 的文档明确支持这一思想：memoryless 用于 on-chip temporary render targets，而 multisample attachment 在不需要保留 MSAA data 时可只 resolve，不 store multisampled contents。citeturn20view0turn20view1

如果现有 renderer 是：

```text
depth prepass
→ opaque
→ shadow mask
→ lighting
→ reflection
→ SSAO
→ composite
→ HDR post
→ MSAA/resolve
→ UI
```

那么应逐 pass 检查“为什么它必须是独立 encoder/texture”。Apple 明确建议能 merge 的 encoder 尽量 merge，因为不必要的 encoder 增加 bandwidth。citeturn20view2

但也不要为了“一个 pass”硬塞所有东西。**目标不是 encoder count = 1，而是避免没有必要的跨-pass materialization。**

## 当前架构与推荐架构对比

| 模块 | 当前方法 | 推荐方法 | 视觉风险 | 实现复杂度 | 性能/功耗判断 | A/B |
|---|---|---|---|---|---|---|
| 球 environment reflection | 每 visible ball pixel 最多约 64 samples | GGX prefiltered cubemap + split-sum BRDF LUT；默认 1 cubemap + 1 LUT | 中；主要是 local parallax/inter-ball reflection | 中 | **采样数量级下降；P0** | **必须** |
| 树脂灯光高光 | 多环境/area-light samples 中自然形成 | 独立 fitted/analytic direct highlight | 中低；需调出“树脂感” | 中 | 让昂贵通用积分专门化 | **必须** |
| Local reflection | probe cached，但球仍大量运行时运算 | static probe + box/parallax correction；必要时极少 local probes | 中 | 中 | 显著降低 texture/ALU work | **必须** |
| SSR | 若未来考虑 | 默认不加入 | 低；主要损失屏幕内局部互反射 | 低 | 避免 depth/history/full-screen 工作 | 不需要，除非视觉验证失败 |
| 球影 | 约 8×4 area-light samples | analytic projected ellipse/SDF + fitted penumbra LUT | 中低 | 中 | 项目已有 **shadow-off -24% GPU** 强证据 | **最高优先** |
| Shadow map / PCSS | 通用方案候选 | 球不用；只给 cue/特殊对象 | 低 | 低 | 避免 kernel sampling / atlas work | 是 |
| SSAO | 部分场景关闭 | 静态 room/table bake AO；ball contact 归入 analytic shadow | 中低 | 低-中 | 删除 full-screen pass 的潜力 | **是** |
| 静止画面 | 持续 full 3D | pause + dirty invalidation | 主要风险是 stale frame bug | 中 | **静态 app 3D GPU work 理论上可接近 0** | **最高优先** |
| Aim line | 可能触发完整 3D | independent 2D/Metal overlay | 低 | 中 | 避免 aim-only full redraw | **是** |
| UI | 与 3D 同 cadence | 独立 UIKit/Core Animation/overlay cadence | 低 | 中 | 降低 3D frame count | 是 |
| 2D top view | full 3D camera change | dedicated 2.5D renderer | 中 | 中高 | 删除多个 workload classes | **必须** |
| Static world lighting | 实时 PBR 为主 | baked diffuse/AO + minimal view-dependent specular | 中低 | 中 | 降 fragment ALU/texture | 是 |
| Render path | 通用 PBR | specialized forward | 低 | 中 | 少 attachment/pass/light management | 是 |
| HDR | 保留 | **保留**，但 audit format/intermediates | 无 | 低 | 不以牺牲 HDR 为第一手段 | 是 |
| 4× MSAA | 当前 4× | 先保留；memoryless + resolve-only；2×只做 A/B | 2×有 silhouette 风险 | 低 | TBDR 上必须实测真实成本 | **必须** |
| Depth/MSAA attachments | 需 audit | memoryless；不用的 depth store `.dontCare` | 无 | 低 | Apple 官方推荐方向 citeturn20view0turn20view1 | 是 |
| Render passes | 未知 | frame graph audit + merge compatible encoders | 无 | 中 | Apple 明确指出可降低 bandwidth citeturn20view2 | 是 |
| Environment texture | HDR probe | private/compressed format，评估 ASTC HDR/device support | 低-中 | 中 | Apple 案例显示 env cubemap bandwidth 值得重点查 citeturn23view1 | 是 |
| Shader precision | PBR 默认 precision | critical vector 用 float；安全中间值用 half | 低-中 | 中 | Apple 示例硬件 FP16 吞吐更高 citeturn23view0 | 是 |
| Instancing | 未知 | 16 balls one PSO / instanced where clean | 无 | 低 | CPU cleanliness > P0 GPU gain | 后做 |
| Dynamic Resolution | 原生 | 只作为 thermal/device fallback | 有清晰度风险 | 中 | Apple/MetalFX 官方支持 citeturn23view4turn20view5 | 是 |
| MetalFX | 未使用/未知 | P2；老设备或 thermal governor | temporal artifacts 需查 | 中 | 不作为第一阶段架构修复 | 是 |

这里尤其要强调 MSAA：**Apple TBDR 并不等于“4× MSAA 免费”。** 4× 会增加 tile storage 需求、coverage/raster work，具体 shader 是否 per-sample 执行又取决于 pipeline；但如果 attachment memoryless 并且只 resolve final color，它又可能避免传统 immediate-mode GPU 那种巨大的 off-chip multisample-buffer traffic。因此唯一专业答案是：

> **先把 MSAA 的 attachment/store 架构做对，再测 2×/4×，而不是把 4× 当成原罪。**

## Renderer Audit Checklist

下面这张表可以直接交给工程师逐项过代码和 GPU Capture。

| Audit 域 | 必查项 | 理想状态 / 需要回答的问题 |
|---|---|---|
| **Frame Graph** | 每帧所有 render/compute/blit pass 列表 | 每一个 pass 为什么必须独立？有没有为了方便而 materialize intermediate？ |
| **Frame Graph** | pass dependencies | 哪些 dependency 实际阻止 encoder fusion？ |
| **Encoder** | render command encoder 数量 | 能否 merge？Apple 明确指出不必要 encoder 会提高 bandwidth。citeturn20view2 |
| **Attachment** | color/depth/stencil storage mode | transient depth/MSAA 是否 `.memoryless`？citeturn20view1 |
| **Attachment** | loadAction | 全覆盖是否误用 `.load`？不需要 previous contents 是否仍 load？ |
| **Attachment** | storeAction | depth/stencil 是否无意义 `.store`？Apple 建议无需保存时 `.dontCare`。citeturn20view0 |
| **MSAA** | multisample surface store | 是否只需要 resolve 却仍 store 4× attachment？ |
| **MSAA** | resolve pass | 是否在额外 encoder 中做本可同 pass 完成的 resolve？citeturn20view0 |
| **HDR** | intermediate formats | 有多少 RGBA16F full-resolution buffers？每个真的需要 64-bit/pixel 吗？ |
| **HDR** | lifetime | HDR intermediate 是否跨越比实际需要更多的 pass？ |
| **Texture** | reflection cubemap format | 是否 uncompressed RGBA16F？是否 private/compressed？Apple 案例应重点参考。citeturn23view1 |
| **Texture** | ASTC / normal / roughness | static texture 是否使用适合设备的 block compression？ |
| **Texture** | mip chain | reflection roughness 是否真正通过 prefiltered mip 使用，而不是 runtime 64 samples？ |
| **Texture** | residency / creation | 有没有每帧创建 texture/buffer/pipeline？Metal 建议持久复用昂贵对象。citeturn2search12 |
| **Reflection** | environment sample count | Ball shader 的 cube samples/draw、samples/pixel 实际是多少？ |
| **Reflection** | runtime GGX integration | 是否仍运行 sample loop？应优先消失 |
| **Reflection** | local probes | probe 是静态、按需还是每帧更新？ |
| **Reflection** | SSR | 为什么需要？它解决的具体可见 artifact 是什么？ |
| **Ball Shader** | ALU limiter | 64-tap 取消前后 ALU limiter 如何变化？ |
| **Ball Shader** | Texture Sampler limiter | cubemap 优化前后如何变化？ |
| **Ball Shader** | FP32/FP16 | 哪些值安全使用 half？Apple 建议用 counter/图像测试验证。citeturn23view0 |
| **Ball Shader** | branches | 是否有 per-pixel dynamic material branch？可否 function constant/specialized PSO？ |
| **Ball Shader** | registers | 复杂 loop 去除后 occupancy/register pressure 是否改善？ |
| **Shadow** | samples/pixel | 当前是否确实达到 32 次 area-light samples？ |
| **Shadow** | draw area | 阴影 shader 实际覆盖多少屏幕 pixels？ |
| **Shadow** | analytic replacement | 能否用 one instanced quad + ellipse SDF？ |
| **Shadow** | shadow atlas | 十几个球为什么需要通用 shadow map？ |
| **Shadow** | contact | 接触暗化是否可直接并入 analytic profile？ |
| **Static Work** | camera stable | 稳定后是否仍调用 draw？ |
| **Static Work** | balls sleeping | physics/render dirty flag 是否能停止 full frame？ |
| **Static Work** | reflection probe | static scene 时是否仍有任何 probe/update compute？ |
| **Static Work** | uniforms | 无变化对象是否仍每帧 memcpy/update？ |
| **Static Work** | command buffers | idle state command buffers/sec 应趋近 0 |
| **Static Work** | drawable | idle 是否仍调用 `currentDrawable`？Apple 建议尽量晚获取 drawable。citeturn2search8 |
| **UI** | aim updates | aim-only 是否触发 scene redraw？ |
| **UI** | animation | UI 是否能独立于 3D cadence？ |
| **2D Mode** | room draw | 应为 0 |
| **2D Mode** | sphere mesh | 是否可以 impostor？ |
| **2D Mode** | reflection/shadow | 是否仍进入完整 3D path？ |
| **CPU** | scene traversal | idle 是否仍做 cull/sort/build draw list？ |
| **CPU** | pipeline switches | 固定场景是否有不必要 PSO/material churn？ |
| **CPU** | allocations | 每帧 heap/object allocation 是否为 0 或接近 0？ |
| **CPU/GPU Sync** | waits | CPU 是否等待 GPU resource reuse？ |
| **Buffers** | dynamic uniforms | 是否使用合理的 ring/triple buffering，而非频繁等待或创建？Apple 推荐多缓冲动态数据以避免 idle。citeturn2search20 |
| **Opaque** | HSR effectiveness | fragment invocations / pixels stored 是否异常？Apple 可用 counters 直接测。citeturn23view0 |
| **Transparency** | shadow/blend | blending 是否产生大面积 overdraw？ |
| **Post FX** | full-screen passes | 每个 pass 的 perceptual value 是否足以支付 native-resolution fragment cost？ |
| **Bandwidth** | main-memory read/write | 每 frame / second 的趋势是什么？ |
| **Bandwidth** | tile load/store | pass 合并前后变化多少？ |
| **Profiler** | top limiter | 每个关键 scenario 是 ALU、Texture、Memory、Raster 还是 CPU bound？ |
| **Profiler** | per-draw GPU time | ball / shadow / room / post 各占多少？ |
| **Profiler** | thermal state | nominal → fair → serious 的时间点在哪里？ |
| **Profiler** | Power Profiler | CPU/GPU/display power-impact 时间曲线是否随优化同步下降？Apple iOS 提供这些图。citeturn23view4 |

Audit 完之后，每个 GPU frame 最好能够用一张简单账单解释：

```text
Frame 3D Dynamic
--------------------------
Static world       x ms
Ball shader        x ms
Ball shadow        x ms
Cue                x ms
Resolve            x ms
Tonemap             x ms
UI                  x ms

Main memory read   x MB
Main memory write  x MB
Fragment invokes   x M
Texture reads      x
Top limiter        Texture / ALU / ...
```

如果团队只能告诉你“总 GPU = 8 ms”，这个 profiling 粒度还不够。

## Benchmark 与 A/B 实验矩阵

专业 benchmark 必须同时回答两个问题：

> **瞬时性能有没有变快？**

以及：

> **半小时后同样的视觉质量还能不能保持？**

Apple 当前的官方游戏优化工作流明确要求长时间观察、结合 thermal state、Metal Performance HUD、Instruments 与 Metal debugger；iOS Power Profiler 可以观察 CPU/GPU/display power impact。citeturn20view4turn23view4

### 测试环境

固定：

```text
同一台物理 iPhone
同一 iOS build
同一 App build / compiler flags
同一屏幕亮度
同一房间环境温度
相同 battery state 范围
关闭充电
固定 network/background 条件
Low Power Mode 状态一致
相同 thermal starting state
```

不要在一个刚刚跑完 30 分钟 benchmark 的热设备上马上跑下一 variant。

Apple 的 Metal Performance HUD 本身会显示 thermal context、FPS/frame pacing 等，而 `ProcessInfo` 提供 thermal-state API，可以把 thermal timeline 写进你自己的 benchmark log。citeturn20view4turn5search0

如果应用能够**合法地作为 game 使用相关 capability**，可以单独做一组 Sustained Execution Mode 测试。Apple 说明该模式让应用从启动起就在更接近长时间 steady-state 的性能 profile 下运行，方便针对 sustained performance 调优。不要让训练 App 的架构依赖这一 capability；如果产品类别/entitlement 不适用，就以普通系统 steady state 为准。citeturn23view4turn23view5

### 测试场景

不要只有一个平均场景。至少建立这些 deterministic replay：

| Scenario | 内容 | 主要暴露问题 |
|---|---|---|
| **Idle-3D** | 标准 3D 构图，相机/球/灯全部静止 | static redraw / session power |
| **Aim-Only** | 世界完全静态，只持续移动瞄准线 | overlay architecture |
| **Balls-Moving** | 10–16 球持续运动的 deterministic replay | shadow + transforms + reflection |
| **Ball-Closeup** | 一个/几个球占据较大屏幕面积，相机动 | ball reflection fragment shader |
| **Camera-Orbit** | 球静止，持续绕台运动相机 | IBL/parallax/room rendering |
| **Top-View** | 当前完整 3D top view | 2.5D 对照基线 |
| **Worst Post-FX** | 所有当前默认 post effect 开启 | attachment/fullscreen bandwidth |
| **Normal Training** | 真实用户操作 replay | 最终 session validation |

### 时间点

每个 variant 至少记录：

```text
Cold / first stable window
5 min
15 min
30 min
```

30 分钟测试真正关心的不只是：

```text
60 → 58 FPS?
```

而是：

```text
GPU 6.0 → 8.5 ms?
CPU 2.5 → 3.4 ms?
presentation misses?
thermal nominal → serious?
clock/performance state changed?
power impact?
```

### 必须记录的指标

| 类别 | 指标 |
|---|---|
| Presentation | FPS、presentation interval、dropped/missed frames、P95/P99 frame time |
| CPU | average / P95 / P99 CPU frame time、encoder CPU time、renderer thread utilization |
| GPU | average / P95 / P99 GPU frame time |
| GPU limiter | ALU、Texture Sampler、Memory、Tile Load/Store 等 top limiter |
| Fragment | rasterized pixels、fragment shader invocations、pixels stored、overdraw ratio |
| Vertex | vertex utilization / vertex occupancy |
| Texture | texture read activity、cubemap draw 的 texture traffic |
| Memory | bytes read/written from main memory |
| Attachments | tile load/store、resolve、intermediate-target traffic |
| Shader | FP16/FP32 utilization、occupancy、热点 draw-call GPU time |
| Thermal | `ProcessInfo.thermalState` timeline |
| Power | Instruments Power Profiler CPU/GPU/display power impact |
| Stability | thermal throttling 后 sustained FPS/GPU ms |
| Quality | reference screenshots、difference heatmap、人工 blind A/B |

Apple 明确说明 GPU counter 中的 memory bandwidth 是 System Memory 到 GPU 的 transfer，并提供 per-encoder/per-draw 的 main-memory bytes 等信息；这类数据应该进入 benchmark 表，而不是只记录 FPS。citeturn23view1

对于**真正的 Watt 数值**需要谨慎：Apple 公开资料明确提供的是 Power Profiler 的 CPU/GPU/display **power impact** 图表。citeturn23view4 如果项目必须得到实验室级 “W” 和 FPS/W，应该使用校准过的硬件功耗测试环境；简单读取 USB-C 输入功率会混入充电、电池管理和系统其他负载，不能把它直接等价成 renderer GPU watts。

### A/B 实验矩阵

| Variant | 只改变什么 | 最重要场景 | 首要 KPI | 成功条件 |
|---|---|---|---|---|
| **A0 Reference** | 当前默认高画质 | 全部 | baseline | 所有后续比较基准 |
| **A1 Reflection Split-Sum** | 64 sample → prefiltered IBL + BRDF LUT | Ball-Closeup / Camera-Orbit | ball draw GPU ms、texture/ALU limiter | 球 shader 时间显著下降；视觉 blind A/B 合格 |
| **A2 Reflection + Local Correction** | A1 + box/local-probe correction | Camera-Orbit | visual fidelity vs A1 | 仅在视觉收益明显时保留 |
| **B1 Analytic Shadow** | 32-sample shadow → ellipse SDF | Balls-Moving | shadow GPU time、whole frame | 目标至少回收 shadow-off 24% delta 的约一半 |
| **B2 Penumbra LUT** | B1 + offline-fitted penumbra | Balls-Moving | visual error | 接近 reference area shadow，成本仍接近 B1 |
| **C1 Event-Driven** | static full redraw → invalidate only | Idle-3D | GPU submissions/sec、power、thermal | idle 3D command-buffer rate接近 0 |
| **C2 Overlay Separation** | aim-only 不触发 3D | Aim-Only | full 3D frames/sec | aim 60 Hz、scene 0 Hz |
| **D1 2.5D Renderer** | top view 走独立 renderer | Top-View | GPU ms、bandwidth | 相对当前 3D top-view 显著降低；建议把 ≥50% 作为工程目标而非预测 |
| **E1 Memoryless/MSAA Audit** | attachment storage/action only | Balls-Moving | bytes written、tile store、GPU ms | 视觉完全相同、bandwidth 下降 |
| **E2 Encoder Fusion** | merge compatible passes | Worst Post-FX | main-memory traffic、GPU ms | store/load 明显下降 |
| **F1 MSAA 4×** | optimized 4× | all | baseline optimized quality | 首选 fidelity baseline |
| **F2 MSAA 2×** | 仅改 2× | all | GPU/bandwidth/power vs quality | 只有 sustained power 收益足够大才考虑 |
| **G1 MetalFX Spatial** | lower internal pixels + upscale | thermal stress | GPU ms/power/quality | 仅作为 device/thermal tier |
| **G2 MetalFX Temporal** | temporal upscale | dynamic 3D | stability/ghosting/quality | 球快速运动/细瞄准线无明显 artifact |
| **H1 Dynamic Resolution** | thermal governor | 15–30 min | sustained FPS / thermal | 只在架构优化后仍需要时启用 |

MetalFX 是 Apple 官方提供的平台优化 upscaler；官方资料称 spatial 模式偏向更大的 performance benefit，temporal 模式偏向最高质量，当前 Apple 资料还明确支持 runtime dynamic resolution changes。citeturn20view5turn23view4turn23view5

但对这个项目，推荐实验顺序必须是：

```text
Reflection
Shadow
Static redraw
Render-pass bandwidth
2.5D
        ↓
确认仍需要额外 headroom
        ↓
MetalFX / dynamic resolution
```

而不是反过来。

### 如何判断“视觉质量基本没降”

建议建立固定 reference suite：

```text
R1 近距离 8-ball 黑球高光
R2 白球靠近木库边
R3 多球相邻、复杂反射
R4 球在袋口附近
R5 球影正下方 contact
R6 球影远端 penumbra
R7 camera grazing angle
R8 top view numbers/stripes rotation
```

每项保存：

```text
Current high-quality reference
New renderer
Absolute difference
Zoomed crop
```

再做 blind A/B。

不要单独用 SSIM/PSNR 决定结果，因为一个高光位置变化几个像素可能产生很大的 numerical difference，却几乎没有 perceptual cost；反过来，阴影接触点稍微“漂浮”即使图像指标很好，人眼也非常敏感。

## 最终技术路线

**一周内：先拿掉三个最高置信度的结构性浪费。**

第一步不是重写 engine，而是给当前 renderer 建立证据基线。用 Metal Performance HUD、Metal System Trace、GPU Capture/GPU Counters 和 Power Profiler 固定记录：

```text
Ball draw GPU ms
Shadow GPU ms
room/table GPU ms
post GPU ms

ALU limiter
Texture limiter
main-memory read/write
fragment invocations
tile load/store

Idle power impact
5 / 15 / 30 min thermal state
```

Apple 官方工作流同样建议先 long-session observe，再 isolate，再用 GPU tools 诊断。citeturn20view4turn20view3

随后优先交付三件事：

```text
Current 64-sample reflection
        ↓
prefiltered cubemap + BRDF LUT prototype

Current 32-sample ball shadow
        ↓
analytic projected SDF shadow prototype

Current permanent render loop
        ↓
dirty state + MTKView event-driven idle
```

这三个项目都有很强的第一性理由，其中 shadow 还有你自己的 **24% whole-frame delta** 作为直接证据。

同一阶段完成一个 attachment audit：

```text
depth:
memoryless?
store = dontCare?

4x MSAA:
memoryless?
resolve-only?
accidental store?

HDR intermediates:
how many?
why?

render encoders:
which can merge?
```

这部分风险低，而且有 Apple 官方明确最佳实践支持。citeturn20view0turn20view1turn20view2

这一阶段**不要先做**：

```text
VRS
complex occlusion system
GPU-driven indirect renderer
Forward+
dynamic shadow atlas redesign
large ECS/render graph rewrite
```

这些都不是当前 evidence 指向的 top bottleneck。

**一个月内：把 prototype 变成台球专用 production renderer。**

Reflection 正式化为：

```text
Offline / Load Time
-------------------
Static room/table probe
→ GGX prefilter mip chain
→ compressed/private GPU resource
→ BRDF/DFG LUT

Runtime Ball
------------
normal
view
reflect vector
→ optional box correction
→ 1/few environment samples
→ BRDF LUT
→ fitted direct resin highlight
```

同时建立球材质 offline reference：用高采样 path tracer 或你现在的 64-tap shader 作为“ground truth”，让新 shader 去拟合它，而不是靠肉眼随意调参。这样旧高成本 shader 就从“生产 renderer”转变成**reference renderer**——这其实是它最有价值的位置。

Shadow 正式化为：

```text
Offline reference
→ real rectangle light × sphere
→ table-position parameter sweep
→ fitted penumbra/contact model

Runtime
→ ball XY
→ shadow affine transform
→ one instanced quad
→ analytic SDF
→ fitted penumbra
```

然后拆分 update domains：

```text
Physics timestep      independent
Ball render transform 60 Hz while moving
Camera                60 Hz while interacting
Room lighting          0 Hz
Reflection probe       0 Hz
Static world           dirty-only
Aim overlay            60 Hz if user is dragging
UI                     own cadence
Full 3D                0 Hz while idle
```

接着交付独立 top-view 2.5D renderer：

```text
same simulation
same ball texture assets
same ball rotations

different rendering:
baked table
sphere impostor balls
analytic shadow
procedural cue
no room
no general 3D lighting path
```

这一阶段再做 shader-level tuning：

- `half`/FP16 仅用于经过 visual validation 的中间变量；Apple 的公开 counter 资料说明 precision choice 确实可能影响 throughput。citeturn23view0
- 通过 function constants / specialized PSO 删除运行时材质分支。
- 16 个球整理为 instanced/same-PSO draw，主要降低 CPU/encoder 状态杂音。
- static textures 用适当 ASTC；environment HDR compression 在目标 GPU family 上验证。
- 删除 runtime shader/pipeline compilation。Apple 的高端 iPhone 技术分享特别建议 ahead-of-time shader compilation，因为移动设备上的 runtime compilation 既可能 hitch，也不利于功耗。citeturn23view5

**长期架构：从“frame loop”升级为“render invalidation system”。**

真正顶级的最终设计不是一套越来越复杂的 graphics settings，而是一套明确知道“什么变了”的 renderer：

```text
Dirty.WorldStatic
Dirty.Camera
Dirty.Balls
Dirty.BallLighting
Dirty.Cue
Dirty.AimOverlay
Dirty.UI
Dirty.TopView
```

scheduler 根据 dirty mask 决定：

```text
Nothing dirty
    → submit nothing

UI dirty
    → UI only

Aim dirty
    → overlay only

Balls dirty
    → dynamic 3D / 2.5D

Camera dirty
    → full scene

Lighting/probe dirty
    → rare cache rebuild
```

这会把你与典型“游戏引擎每帧遍历世界然后看看有什么能省”的思路彻底区分开来。

长期再加入**thermal-aware quality governor**。Apple 提供 thermal state API；当前游戏性能资料也建议持续关注 thermal 状态和 long-play consistency。citeturn5search0turn23view4 governor 的优先级不要设计成：

```text
thermal high
→ immediately ruin image quality
```

而应该是：

```text
Level 0
Specialized renderer
event-driven
analytic shadows
prefiltered IBL
optimized attachments
native res
4x MSAA

        ↓ thermal/performance pressure

Level 1
nonessential post FX reduced
rare update rates reduced

        ↓

Level 2
MSAA 4x → 2x, only if A/B proved worthwhile

        ↓

Level 3
MetalFX / modest dynamic resolution

        ↓

Level 4
lower dynamic frame target only as last resort
```

Apple 官方确实把 MetalFX、动态分辨率、不同 display cadence 作为 performance/power scaling 手段，但它们更适合在根本 renderer 已经高效之后做最后一级 device/thermal scaling。citeturn23view4turn23view5

最终应该追踪的北极星指标不是：

```text
Peak FPS
```

也不是：

```text
Cold GPU ms
```

而是类似：

```text
Visual Fidelity / Watt
Visual Fidelity / Joule per training session
P99 frame time after 30 min
Time-to-thermal-throttle
Main-memory bytes / rendered frame
Full 3D frames / user-visible state change
```

对这个项目而言，最理想的最终行为是：

```text
用户转动相机 / 球运动
→ 高质量 native-resolution 60 FPS
→ 4x MSAA
→ HDR
→ PBR resin balls
→ soft convincing ball shadows

球停止、相机停止
→ render one final correct frame
→ 3D renderer stops

只移动瞄准线
→ 60 Hz lightweight overlay
→ static 3D scene untouched

切换 top view
→ specialized 2.5D pipeline
→ no room renderer
→ no generic shadow/reflection path
```

这才是这个高度受约束的台球场景真正应该追求的“行业顶级移动 Renderer”形态：**不是不断降低画质来换温度，而是让昂贵的 GPU 工作只发生在画面确实需要它的时刻，并把能够预计算、解析化、缓存化、专用化的部分全部从实时路径中移走。** Apple 自己关于 TBDR、tile memory、load/store、GPU counters、Power Profiler 和 sustained execution 的公开方法论，与这一方向高度一致。citeturn23view1turn20view0turn20view2turn20view4