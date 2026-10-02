# 主控独立证据核对

2026-10-02。此文件记录主控直接检查的证据，不代表候选已运行或迁移已批准。

## 当前代码

1. 开始时 HEAD 为 b69aa749b12a4e322da1bbca1a78536349531c47，工作区存在房间/相机/测试增量；baseline.json 保存时点。源码快照只包含 Core/Scene、Core/Media 和列出的配置/文档，不包含整个仓库或完整构建资产。
2. AngleTrainingScene.configureDailyClearanceRendering 明确选 R；MobileReferenceLighting.specializedProfile 普通共享入口默认 A。filteredBallShader 替换 GGX 循环，PrefilteredReflection 执行一次预滤波；不能把旧 A 的 64 次反射移除成本说成当前每日仍可获得的收益。
3. AngleSceneView 的 contentIsAnimating 为可选、默认 nil；活动条件用 nil→true。该默认值提示未显式传动画状态的页面可能持续活动，但具体页面还要查调用与 SCNActions。不能把全 App 静止停绘当作已覆盖事实。
4. SimulationWorker 消费值类型快照，不持 SCNNode；但 TrajectoryPlayback 含 SCNNode/SCNAction，BreakFlowRunner 含节点与动作。物理算法可以保持，呈现消费适配并非零改动。不能把 import SceneKit 次数当物理耦合成本。
5. SequenceVideoExporter 使用 AngleTrainingScene 与 SCNRenderer。迁移若暂保旧导出器必须计入双管线维护及一致性验证；最终共用帧状态不等于已实现跨引擎一致画质。
6. consumer-evidence.json 保存后续工作区 16 处 AngleSceneView 调用及各 owning source 哈希：2 处显式 contentIsAnimating、14 处省略。FreePlay 的每日入口已显式接入；未实测各页实际重绘，不能用省略默认解释每日动态热。
7. 当前 PROGRESS、ROOM-SIZE-STUDY 与 BakedTrainingRoom 后续核实为用户选定 8×6m / 3.6m 的试用集成。开始快照与当前完整运行版本分开；其他任务记录的测试/装机不是本轮验证。
8. 资产交叉回应已完整阅读并直接核对：probe bake 保留 table/room/light，使用独立相机关闭 HDR/adaptation；保留材质仍可能含 MobileReferenceLighting:365,575–589 内嵌的曝光派生高光映射。setup 首次 probe 在用户桌主题/台呢色之前；后续 style 首次 miss 的有效材料/动态 uniform 状态须验证。隐藏球节点不直接清理材质接触数据，但本轮没有像素反例，不宣称已证 bug。未来缓存键以规范捕获实际输入为准，不能一概纳入或排除所有曝光/主题。

主控另外独立读取当前 TaiQiuZhuo.usdz ZIP/PNG 头和 usdcat 的面数组：SHA256 为 0e011ae72889d56a97255d8d69f2a7c0615ad779340ab64b938c2947817b48d1，104244229 bytes、41 PNG、105381896 像素，面扇等价 499298 三角形。结果见 host-asset-check.json / host-geometry-check.json，与资产报告一致。没有由此推算实际驻留、draws 或瓶颈。

## 历史原始数据

已直接读取 build/daily-bottleneck-ranking-20260921/gpu3d-attempt2-analysis.json、gpu2d-analysis.json、cpu3d-summary.json。GPU 数据明确标为固定场景 command-buffer spans，不是整页帧时间/瓦数；15球、1206×2622、MSAA4、Apple A18 Pro，主要段120–121样本。3D CPU文件连续瞄准264回调/6.634秒、播放443/12.177秒，同时求解次数分别0/0；这是旧夹具数据，不证明当前全页性能。

scripts/research/analyze_daily_3d_frames.py 当前说明真实trace曾出现 swap 早于所关联 GPU completion；present 关联只为candidate，门禁不放行。必须先修复测量归属或采用独立有效呈现指标，不能借用旧候选统计宣布60FPS。

## 官方事实复核

- Apple WWDC25 官方明确 SceneKit 软弃用/维护模式，现有 App 继续运行，未宣布硬弃用时间。长期方向需评估，无法据此推导立即重写或 RealityKit 更省电。查询 2026-10-02：[官方迁移说明](https://developer.apple.com/videos/play/wwdc2025/288/)。
- Apple 性能指南分别讨论 CPU/GPU 时间线与帧节奏；低电量减少画质/帧率是可选策略，不能用作本轮同画质胜出的依据。查询 2026-10-02：[性能与设置](https://developer.apple.com/documentation/metal/improving-your-games-graphics-performance-and-settings)、[Metal性能分析](https://developer.apple.com/documentation/xcode/analyzing-the-performance-of-your-metal-app/)。
- 本机 Xcode iPhoneOS26.2 SDK MTKView.h 显示 MTKView 自 iOS9 可用，enableSetNeedsDisplay/paused/draw 支持事件驱动；currentMTL4RenderPassDescriptor 标 iOS26。本轮 iOS17 原型不以 Metal4 为基础。SDK可用性不证明实际设备预算。
- 主控直接核实 SCNShadable.h 精确方法：vertex/fragment 与 handleBinding 为 iOS9；RealityFoundation swiftinterface 的 RealityRenderer、OrthographicCameraComponent 为 iOS18。不是按 SDK26.2 target 或类元数据推最低版本。
- Power Profiler、Apple GPU tile-based rendering 与 Metal memory footprint 官方 Markdown 全文已保存 primary-sources/。Power Profiler 系统电池能量比例/小时与应用 power impact 分开，充电/工具连接影响不能忽略；tile-memory 优势来自具体设计，SceneKit 同样使用 Metal，不能仅凭底层 API 名字归因。

## 收口边界

管线、引擎明确接受：SCNProgram/受控 SCNRenderer/资产优化若已达目标，应结束当下节能驱动的全面迁移。评审仍拒绝最低能耗或最佳画质放行。本轮结论是需求与投入适配推荐；当前 R 的 limiter、有效实际呈现、净能耗差异由后续实验决定。

## 独立评审需要挑战的命题

1. 如果换 Metal 后仍逐像素运行相同积分，开销为什么会降低？要求指出减少工作/带宽/提交的机制，不能只说控制更多。
2. 如果当前 SceneKit 已能承载同一算法，为什么要迁移？要求用控制能力、实测上限或维护风险证明边际价值。
3. 如果 RealityKit 新版可行，iOS17 的低机位/正交2D/离屏/暂停能力是否仍成立？查 SDK 和能力接口，不把新版发布说明回溯。
4. 如果房间几何旧消融收益很小，资产路线为何重要？区分持续GPU、首次加载、纹理驻留、烘焙和质量，避免归为主发热源。
5. 同画质比较和同预算提高画质分开。算法近似采用可读性、阴影接触/运动稳定和色彩约束，不把像素零差强制套给完整新渲染器，也不以主观好看放过削减效果。
6. 20秒GPU短窗口、10–20分钟热态、真实电能/代理指标各自报告。没有功率数据则只能选最有潜力路线，不能命名最低能耗冠军。
