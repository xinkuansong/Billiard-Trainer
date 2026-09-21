# 每日清台扩展性能诊断：GPU、帧调度、资源与计算

本报告补充 `DAILY-CLEARANCE-PERFORMANCE-20260920.md` 的短时CPU观察。只修改测试代码；未修改产品画质、帧率策略、求解器或物理参数。

## 方法与可靠性

- 同一专用 iPhone 17 Pro 模拟器，simctl 显示 iOS 26.3，Instruments 识别为 26.3.1 (23D8133)。Mac 为 Apple M5 Pro，Xcode 26.2。Debug / 无代码覆盖率，非手机 Release 性能。
- 新增 RenderQualityV62Tests 三个显式诊断用例，用 build 下的 `run-diagnostics` 文件门控。默认测试不启动这组长诊断，结束后移除门控。
- GPU 矩阵：生产 `AngleTrainingScene.setupScene(mobileRendering:true)`、当前材质/球房；seed=52、杆速8的真实中八开球终态固定盘面。MTKView 承载 SCNRenderer，Metal command buffer 完成后读取 gpuStartTime/gpuEndTime，逐帧保存 CPU 编码时间、draw回调时刻、GPU区间及错误。
- 2D 为固定顶视，3D 为持续匀速观察相机；2D 强制持续绘制用于比较单帧成本，**不等于正常静止页面会持续渲染**。球体位置固定，未包含整页SwiftUI叠层、物理实时预测和进袋动画。这是可重复的渲染组件诊断，不冒称完整每日清台压力场景。
- 每档先预热2秒，主要档位采样10秒；2D/3D持续档各60秒。尺寸取测试窗口点尺寸×屏幕scale；75%档仅降低渲染目标宽高，像素数约为56.25%。基准AA4，room-off仅测试副本隐藏球房。
- FPS 指 draw callback 速率，帧间隔是回调间隔；模拟器SDK不提供此探针使用的 drawable presentation callback，所以**不能称为真正呈现FPS或用户可见掉帧率**。
- GPU指标是 command buffer 区间，可含编码器之间的空闲，不是硬件GPU利用率百分比、shader逐级时间或瓦数。参见 [Apple Metal HUD文档](https://developer.apple.com/documentation/xcode/monitoring-your-metal-apps-graphics-performance/)。
- Metal System Trace 全进程录制成功，导出实际GPU区间；目标负载通过 SimMetalHost 提交，还有 WindowServer/Codex 等其他进程，因此不把整机GPU总量归给球迹。按PID附加失败的日志保留；全进程成功是另一条采集路径。
- Metal HUD 环境变量在本模拟器未得到可用的逐帧日志，不将其视为测量成功。`MTLDevice.currentAllocatedSize` 返回0，记为该路径不可用，不能解释为显存为0。

## 能力限制与原始失败

首轮矩阵执行至2× MSAA时，Metal验证器明确报告 `sampleCount (2) is not supported by device` 并终止测试，xcodebuild退出65。已保存 first-attempt数据、gpu-test.log和xcresult；补上能力检查后，2×档输出unsupported原因，其他支持档位重新执行，不隐藏首次失败。

请求120 FPS在本次模拟器上实际只约60回调/秒。因此该档仅验证请求/实际差异，不是120帧真机性能证明。任何30/60帧对比也仅是这一Mac模拟器的调度结果。

## 资源静态审计

`QiuJi/Resources/TaiQiuZhuo.usdz` 93.696 MiB，42个归档条目（1个约24.79 MiB的usdc + 41张PNG）。如果把所有PNG都简单按RGBA8原尺寸解码，base level约402 MiB；这只是统一解码格式的估算示例（并非含mipmap等开销的上界），实际通道、纹理格式、去重、可见性和mipmap均不同，**不是实测GPU内存**。

TableModelLoader 明确保留进程级原型缓存，各场景clone。RoomReflectionProbe缓存球房反射（512×256贴图、128像素立方体面），不能将一次进出后的全部保留内存直接判为泄漏。应观察重复轮次平台期及场景弱引用。

原始证据：`build/daily-performance-20260920/expanded/`，含测试日志、逐帧JSON、图片、Metal trace/XML、资产清单、源码sha256、summarize.py。


## GPU矩阵实测

固定盘面，Debug -Onone；GPU时间为每帧command buffer区间。所有支持档位command error为0。

| 档位 | 实际回调FPS | GPU中位 / P95（ms） |
|---|---:|---:|
| 2D，30 | 30.00 | 0.335 / 0.403 |
| 2D，60 | 60.00 | 0.307 / 0.434 |
| 2D，请求120 | 60.00 | 0.345 / 0.477 |
| 3D，30 | 30.00 | 0.319 / 0.428 |
| 3D，60 | 59.91 | 0.287 / 0.388 |
| 3D，请求120 | 60.00 | 0.275 / 0.360 |
| 3D，75%宽高 | 60.00 | 0.295 / 0.372 |
| 3D，关闭球房 | 60.00 | 0.296 / 0.412 |
| 2D，持续60秒 | 59.98 | 0.302 / 0.419 |
| 3D，持续60秒 | 60.00 | 0.274 / 0.384 |

基准1206×2622、4×MSAA。2×MSAA不支持。降低分辨率或关闭球房没有表现出明确收益；不能据此建议直接牺牲画质，也不能从这组短样本判断2D或3D谁更省电。60秒内未见持续帧率衰退；不等于长时热稳定性。

## 真实开球回放及尖峰

另一个诊断用例使用生产BreakFlowRunner（seed52、8m/s），真实物理计算和回放；保留MTKView探针，仍非完整页面。先完成Debug两模式，再使用 **Debug配置 + SWIFT_OPTIMIZATION_LEVEL=-O** 重跑四轮，顺序2D/3D/2D/3D。后者不是Release，也不是手机。

| 优化构建轮次 | 回放回调FPS | GPU中位 / P95（ms） | CPU提交路径P95 / 最大（ms） | 最大回调间隔（ms） |
|---|---:|---:|---:|---:|
| 2D，第1轮 | 59.31 | 0.340 / 0.455 | 2.54 / 163.49 | 166.60 |
| 3D，第2轮 | 60.00 | 0.336 / 0.454 | 2.59 / 9.53 | 18.45 |
| 2D，第3轮 | 60.00 | 0.343 / 0.445 | 2.61 / 11.97 | 16.80 |
| 3D，第4轮 | 59.52 | 0.344 / 0.459 | 2.64 / 108.98 | 114.96 |

四轮均正常settled、Metal command error=0。此前Debug的2D也出现166.79ms提交路径尖峰；因此不是仅凭一个异常点下结论，优化构建仍可复现长间隔，且不只2D出现。

**“CPU提交路径”是draw入口、获取drawable/descriptor到SCNRenderer.render返回的墙钟时间，包含潜在等待，不是CPU实际忙碌时间。** GPU区间未同步出现百毫秒尖峰，现有证据只能定位到GPU执行区间之外的提交/等待/调度问题；尚无尖峰时刻的线程栈，不能认定是具体shader、物理、纹理上传、首次编译或CPU算法。下一步应在真机和优化构建中同步采集Time Profiler、线程状态、Metal timeline，定位长帧；也不能把卡顿直接等同于发热。

## 计算成本：固定全盘、目标球及袋口

seed52/53/54各真实开球一次；每盘固定目标球_1，遍历6袋，调用生产PositionPlayShotSolver并在不可行时调用DirectPotBankFallback，带全盘障碍。共18次直线求解、12次翻袋备选搜索。不是手势事件吞吐测试。

| 运算 | Debug -Onone | Debug -O |
|---|---:|---:|
| 开球计算，三盘范围 | 464–493ms | 76–97ms |
| 直线求解，中位 / 最大 | 2.98 / 58.65ms | 0.25 / 10.78ms |
| 翻袋搜索，中位 / 最大 | 368.09 / 720.89ms | 57.30 / 86.36ms |

12次翻袋搜索均返回0条候选。这只说明这批固定球/袋组合的成本，不能推断算法整体命中率。优化构建明显降低开销，禁止拿未优化Debug结果代表发布版；优化后仍值得关注连续拖动、换袋触发的重复工作。代码现有过期结果丢弃不等于在途计算取消；后续可验证合并请求、取消过期计算、缓存相同输入的收益，暂未实施。

## 内存、空闲及生命周期

- 原始实际页面短窗：2D/3D静止CPU单核折算1.52%/1.70%，后台0.48%，退出到首页1.26%，详见初测报告；不是手机CPU百分比。
- 使用生产SCNView与Coordinator进行10轮场景创建/拆除，每轮预热2秒、空闲观察3秒：10轮didRender回调均为0，isPlaying=false；退出等待1秒后弱引用存活场景均为0。未发现这个组件在静止时仍持续绘制或场景对象无法释放。
- 生命周期10轮physical footprint约562.24→568.64MiB，增长6.40MiB；不能因此宣称整页无泄漏或把增长直接判为泄漏。该测试未覆盖完整FreePlayView/ViewModel导航和所有缓存。
- 各60秒持续渲染：2D footprint约612.5→613.7MiB，3D约613.2→615.1MiB。只是短时增量，模拟器运行库、测试宿主和共享纹理均影响绝对数值。
- 纹理资源体量值得真机复核；本次GPU显存接口不可用，未获得真实纹理驻留量、带宽、tile/shader占用或手机内存峰值。

## 验证及复跑

通过scripts/Makefile调用，不改变产品源码。四个诊断方法：testDailySimulatorGPUAndFrameMatrix、testDailySceneIdleAndLifecycle、testDailyFixedPhysicsCosts（RenderQualityV62Tests）和testDailyBreakPlaybackGPU（BreakFlowRunnerV6Tests）。成功日志分别为gpu-test-r2.log（Executed 1 test）、remaining-tests.log（Executed 3 tests）、optimized-tests.log（Executed 2 tests），均0 failures，共4个不同用例、其中2项在优化构建复跑。首次不支持AA2的失败单独保留，不计入通过。

诊断必须先在build/daily-performance-20260920/expanded/创建run-diagnostics空文件；结束移除。使用Makefile的ONLY_TESTING选择方法，TEST_CODE_COVERAGE=NO、专用模拟器destination；优化复跑增加TEST_BUILD_SETTINGS='SWIFT_OPTIMIZATION_LEVEL=-O -parallel-testing-enabled NO'。当前回放用例默认四轮；早期Debug两轮JSON保留在debug-baseline中，避免被复跑覆盖。

原始逐帧结果与汇总：summary.json、break-summary.json、optimized-summary.json；debug-baseline保留未优化物理与生命周期结果；first-attempt保留失败轮。最终源码指纹见test-source-final.sha256。

## 结论与真机补测方案

当前可确认：模拟器上GPU单帧耗时低、空闲组件停止绘制；提交路径存在间歇百毫秒尖峰；共享预测计算有可量化成本；资源和运行内存较大，值得真机测量。**目前没有足够证据锁定手机发热根因，也没有证据支持先统一降低画质。**

真机建议使用用户出现问题的机型与实际发布配置，记录iOS/包版本、环境温度、初始电量、充电状态、亮度及帧率设置。先不接充电进行发热复现，另做连接Instruments的归因测试，记录两者条件差异。相同盘面、相同交互脚本，2D/3D分开各连续15–20分钟、冷却至相近起点后交叉顺序重复至少3次；单次依次覆盖静止、持续瞄准拖动/换袋、连续击球回放、切后台恢复与进出页面。补测指标：

1. GPU：实际呈现帧率和长帧、GPU active时间与队列等待、顶点/片元/带宽瓶颈、draw calls/三角形/纹理驻留；按手机支持的counter采集，不支持项明确标记。
2. CPU：主线程长任务、求解器调用频度和累计CPU、过期计算、SwiftUI更新、提交路径等待；长帧处对应线程栈。
3. 内存：physical footprint峰值、纹理/堆、重复30次进退与Memory Graph保留链，区分共享缓存与泄漏。
4. 能耗与热：Energy/Power工具可用指标、ProcessInfo.thermalState时间线、同条件耗电；有条件用外部温度仪记录机身温度。系统thermalState不是摄氏度，电量下降不是精确瓦数。
5. 策略A/B：默认设置先复现，再分别单改30/60/120帧、渲染比例、阴影/反射/AA；同时验画质和操作延迟，证实收益后再决定自动降载策略。

手机GPU硬件、驱动及热约束与模拟器不同，见 [Apple Simulator Metal说明](https://developer.apple.com/documentation/metal/developing-metal-apps-that-run-in-simulator)。上述真机项目均为待执行，不冒称本次完成。
