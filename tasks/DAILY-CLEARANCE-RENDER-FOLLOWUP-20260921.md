# 每日清台渲染跟进：参数提交与 Mac 记录读取（2026-09-21）

## 已交付范围

Mac 读取故障已找到可重复的局部绕过：仅对 xctrace export 设置 LIBDISPATCH_COOPERATIVE_POOL_STRICT=1。原 CPU/GPU/Time Profiler 表均能导出并解析，CPU 重复导出一致，无线短录同样成功；保留原 trace 和失败日志，没有更改系统全局环境或 Xcode。默认局域网、确认未充电的流程已写入 ios-device-performance 技能。

本轮生产增量在 MobileContactOcclusion：将四个四球矩阵合并为具名 Metal struct，通过不可变 NSData 一次提交。保留原 SIMD 排列、数值、球影公式、同帧回调及变化检测。四组同时变化时，每个材质的 setter 从 4 次到 1 次（这部分调用减少 75%）；静止帧仍为 0。单组变化原本也是 1 次，不能宣称所有帧都有 75% 收益。不可变副本避免覆写 GPU 在途数据；实际整体耗时收益仍须真机比较。

目标仍是 60fps，分辨率、MSAA4、阴影采样、物理和画质策略均保持。优化包已通过局域网安装，install.json outcome=success；正常 Debug-O 构建及真机自动测试构建均成功。未提交、推送或发布。

## 定位证据与限制

上一最终包真实 2D 操作 40 秒、用户约 6 杆：平均 CPU 20.83%（单核满载=100%）、区间峰值 41.37%。详细栈仅保留末段，SceneKit draw 占该段 CPU 采样权重约 43%，求解器约 1.48%；不能当作完整六杆的归因。

保留的 GPU 窗口 10.54 秒：应用顶层 Active 命令时间并集 5.20 秒，Fragment 并集 4.07 秒。这是时间覆盖，不是硬件利用率或功耗。发现 6115 次 buffer 分配、5919 次释放（均 128KiB）；GPU 分配量窗口首尾相等，不能据此判定泄漏，也未证明都来自 contact uniform。证据支持优先处理渲染提交开销，尚未证明唯一发热根因。

用户已确认无线且未充电游玩仍热；系统 Nominal 不能否定表面温感。尚无摄氏度、瓦数或充电温升占比，不给出估算降温值。

## 验证

- iOS 26.3.1：3 项渲染单测、2 项实际页面 UI 流程通过，0 失败。
- iOS 17：相同 3 项渲染单测通过，0 失败。
- 每个系统六姿态（2D、3D、放大、抬球、台面下、重叠球）原→新→原；24 组 RGBA 对比全部零像素差。
- 动态帧校验同帧球影位置；计数测试验证四组变化 4→1、静止 0 提交。
- 2D 正常击球、3D 自动开球/首杆/重启恢复流程通过。恢复截图回到 2D，证明杆数和盘面持久化，不证明重启保留 3D 相机。现有提示覆盖 FPS、HUD 省略见原 UI 审查，未作为全页面视觉全绿。
- 自动 ABBA 对照程序模拟器实跑 1 项通过：8 段各约 2 秒有效测量、119–121 条 GPU 完成记录、全部零命令错误（不是屏幕呈现帧率证明）。证据 packing-harness-full.log、packing-harness-summary.json；真机构建完成：2D/3D 各 legacy→packed→packed→legacy，固定画质与 60fps，自动球运动，无需用户反复手动击球。合成场景不是完整游戏温升验收。

## 未采用的实验

去重材质绑定：实际生产仅一个材质引用，未获收益；关闭零强度旧阴影请求：部分图出现 1 级通道差、无稳定时长收益；合并阴影 support 扫描：直接参考在 iOS17 一姿态不等价、模拟器时长无稳定收益。均已撤回，失败日志与图像保留。MobileReferenceLighting.swift 恢复为本轮前 SHA256 1f78c0ffe05548376ba11bd34c05099691d2b9b28ce6966c7e017dd745ea165c。

## 证据与剩余项

本轮证据：build/daily-render-followup-20260921/，含 packing-final-ios26-full.log、packing-ios17-final-full.log、packing-pixel-verification.json、packing-device-build.log、device-tests-final-full.log、install.json、原图及失败实验。

原 trace 归因：build/daily-final-device-20260921/read-recovery/。前轮报告：DAILY-CLEARANCE-FINAL-DEVICE-20260921.md。

真机新增自动对照已完成，用户确认未充电且正常温度；结果见下。全仓 gate 原有 6 项无关视频登记漂移未修，不能声称全仓 gate 通过。完整 CPU/GPU 降幅、3D 实页负载和持续温升仍待真机证据，不能将本轮提交次数减少写成整机降幅或发热解决。

收尾：verify-doc-size 与 git diff --check 均通过；shipping-source.patch 和 shipping-sha256.json 保存当前源码及安装包可执行文件摘要，模拟器一次性诊断开关已清除。

## 无线真机自动对照（08:01–08:02）
用户明确确认未充电、正常温度；CoreDevice transportType=localNetwork。A18 Pro / iPhone16Pro，Debug-O；1206×2622、MSAA4、请求60fps。固定生产盘面加合成球运动，2D/3D各ABBA，单段2秒预热+2秒计量，测试共43.145秒；不是完整SwiftUI游戏/物理操作测试。

| 模式 | CPU渲染提交均值：旧→新 | 变化 | GPU命令执行均值：旧→新 | 变化 |
|---|---|---|---|---|
| 2D | 2.630→2.439 ms/帧 | −7.28% | 14.583→14.734 ms/帧 | +1.03% |
| 3D | 2.449→2.225 ms/帧 | −9.15% | 16.723→17.145 ms/帧 | +2.52% |

每段实际呈现约59.99fps，全部962条呈现记录、0次>25ms间隔、0 GPU命令错误。系统thermal各段起止均Nominal，不能等同表面无热。GPU时间从前到后上升（3D旧参考16.06→17.38ms），顺序/温度/频率漂移足以影响结果；本轮没有证明GPU降低，也不能将+2.52%直接归因参数合并。CPU两个新段均低于同模式两个旧段，支持此固定场景下减少提交开销，但不外推全应用CPU百分比。

结论：本轮合并参数对CPU提交有可见收益，60fps保留；GPU仍重，不能把它当作发热问题已解决。物理未在计量段运行，不能用本轮判断完整游戏物理成本。持续游戏温升、功耗及3D完整页面仍未验收。用户测试后温感待回复。

证据：device-packing-run-full.log（Executed 1 test, 0 failures）、device-packing-results/（8段原始JSON及PNG）、device-packing-summary.json、device-packing-comparison.json、device-before-benchmark.json、device-benchmark-context.json。自动测试消费并删除一次性真机开关。

## 用户再次反馈：3D 仍发热
用户在已安装的参数合并版中实际使用3D，明确反馈仍有发热。不能沿用“固定场景60fps/CPU下降”作为热问题关闭依据，也不能将此前冷机短测Nominal外推持续游戏。

当前源码核查：每日清台FreePlayView显式传入vm.isPlaying/breakRunner.isBusy；AngleSceneView检查相机阻尼、过渡和SCNAction后进入静止路径。RoomReflectionProbe按房间风格缓存，未见每帧重烘焙。球面材质仍有64次反射积分，台呢球影附近每个面光源8×4光照/遮挡采样，均为GPU候选而非本轮已确认唯一根因。

公共scene(mobile:)已经显式切换perspective3D；本轮曾仅看外层测试而误判未切3D，追到helper后已立即更正，未据此改生产代码。已有孤立渲染宿主不代表完整SwiftUI页面，新增testNormal3DShotReturnsToIdle验证实页进入/正常一杆后活动状态；其FPS静止标记只反映调度状态，不单独证明实际零绘制或温升。

新增testDaily3DRenderCostIsolation：固定3D相机、原生1206×2622/MSAA4/60fps，原场景→无直接球影→原→球体原生着色→原→无房间→原。四个原场景用于判断时序漂移，所有隔离仅在测试代码；不交付降画质。模拟器1项通过37.229秒，7段119–121帧、0测试失败；不能把模拟器耗时当手机GPU归因。手机当前有发热反馈，本轮未再次施加真机负载、未覆盖安装。证据build/daily-3d-heat-followup-20260921/。

本轮实页回归结果：testNormal3DShotReturnsToIdle 执行1项，0失败，31.493秒；进入与正常击球后，球桌accessibilityValue均为FPS·静止，三秒后仍静止、模式仍3D。已目视page-ui/normal-3d-idle-after.png。首次失败是查询被父容器合并的FPS子控件，保留page-idle-accessibility-failure.log；改读现有table.scene的value，没有改生产代码/等待阈值。另保留一次目标ID误拼的未执行命令日志，不计测试。

3D分项真机测试构建 TEST BUILD SUCCEEDED（device-build-full.log）；本轮尚未安装或运行，等待冷却确认。仅该分项入口可用，后改的实页UI测试定位尚未重建到真机，不声称其真机通过。git diff --check及文档体积门禁见收尾。

## 3D 无线真机分项归因（08:22）
用户确认温度正常并明确授权开始。局域网已核实，沿用未充电确认；无新增电源/温度传感器读数，亮度和电量未知。Debug-O、A18 Pro、1206×2622、MSAA4、60fps、固定3D相机与盘面。每段预热2秒+计量2秒；7段测试37.886秒，Executed 1 test，0 failures；841条呈现记录、各段59.99fps、0次>25ms呈现间隔、0 GPU命令错误。测试结束，不持续运行。

| 顺序 | 变体 | GPU命令跨度均值ms | CPU渲染调用墙钟均值ms | thermal起止 |
|---|---|---:|---:|---|
| 1 | 基准A | 15.747 | 2.243 | Nominal→Nominal |
| 2 | 仅跳过直接球影 | 12.131 | 2.496 | Nominal→Nominal |
| 3 | 基准B | 16.055 | 2.115 | Nominal→Nominal |
| 4 | 球体改原生着色 | 13.526 | 2.063 | Nominal→Nominal |
| 5 | 基准C | 17.728 | 16.271 | Nominal→Nominal |
| 6 | 隐藏房间 | 18.051 | 1.900 | Nominal→Fair |
| 7 | 基准D | 20.255 | 1.947 | Fair→Fair |

第一隔离项相对前后基准均值15.901ms降低23.71%，前后基准仅漂移约1.95%，明确支持直接球影是GPU成本来源。球体原生着色相对前后均值16.891ms降低19.92%，前后基准漂移约10.42%；仍低于两端，但百分比不作精确稳态收益。移除的是整套球体shaderModifiers，包含反射和其他表面处理，不能说已单独证明64次反射积分占19.92%。这两项差异不能相加，也不是已交付优化或瓦数/温升降幅。

房间组跨热状态，18.051ms处在两端17.728/20.255ms之间，不能据此确认独立收益或认定房间无成本。四次基准从15.747升到20.255ms（约28.6%），存在明显时间/温度/频率或队列状态漂移。CPU计量包含currentDrawable等待和renderer.render墙钟；基准C突增到16.27ms不能当纯CPU忙碌时间。GPU时间也是命令buffer执行跨度，可能重叠/交错，不能把它除以16.67ms当硬件利用率；呈现60fps不代表GPU开销低。

结论与下一步：优先在保持原8×4采样和原球面外观的前提下，减少直接球影内层对同一球几何量的重复计算，以及球面着色中不随样本变化的工作；候选必须先做像素和动态等价，再用短时成对基准确认GPU收益。此前已拒绝的不等价support合并、关闭PBR/旧灯光、降采样不重新作为交付方案。完整3D游戏持续温升尚未解决，此轮仅完成归因，不改正式画质。

证据：build/daily-3d-heat-followup-20260921/device-run-full.log、device-results/、device-summary.json、device-comparisons.json、analyze_device.py、device-context.json、device-before.json。诊断门控已由测试入口消费。手机测试宿主沿用相同生产源码，隔离只发生在测试临时场景，正常打开App保留原画质。
