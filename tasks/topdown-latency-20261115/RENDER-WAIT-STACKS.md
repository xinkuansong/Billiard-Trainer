# 临时俯视长等待：按异常时间窗核对调用栈

2026-11-15。用户要求继续抓渲染阶段长等待，先定位根因，不改正式代码。本轮新增隔离诊断脚本，正式 QiuJi / 工程 / CuePhysWeChat 源码未改。

## 当前可下的结论

**本轮已在模拟器重现并抓到新的自然长帧同期栈**：保持 App 二进制不变，仅暂移 App 私有 Metal 缓存，30 次出现 9 次 >100 ms（最大 540.95 ms），恢复原缓存后 30 次全部 <54 ms。8 份实际慢帧采样均在 didRender 之前开始，均出现编译等待与主线程 renderer 锁等待，详 §4。

原慢包的具体卡顿窗口内，也已经确认 **SceneKit 渲染线程同步请求 Metal 程序/管线编译并等待；主线程同时在临时俯视属性更新、场景同步处等待 SceneKit 锁**。这是实际异常窗口中的栈，不再只是全轮累计权重。CPU 复制整棵树不是当前已测长等待的主要去向。

模拟器先前唯一一次 1339.61 ms 首帧，现从系统日志补到同期约 866.95 ms 的管线编译；仍没有这一次的 App 同期栈，也没有 App 级管线标识，不能把全部 1303.62 ms 渲染间隔归给编译。

**尚未定位：**原真机包为什么比独立重建包更容易触发、哪一个 shader/descriptor/cache key 不同、是否对应近期某次提交。不能宣称增量缓存损坏、依赖优化导致异常，或重建等于修复。

## 1. 原慢包：真实卡顿窗口内的等待链

原 trace：`output/topdown-latency-device-20261115/open-01/capture.trace`、`open-02-standalone/capture.trace`。App UUID 与保存原包匹配。后者脱离 Xcode 启动，无前者的 Metal 调试注入；用户当轮明确反馈忽快忽慢。

新增提取脚本 `scripts/research/topdown_latency_20261115/analyze_hang_windows.py` 以 potential-hangs 区间筛选已符号化样本；结果 `output/topdown-latency-device-20261115/specific-hang-windows.json` 保留每个样本时间、线程、原权重、完整栈。单次样本权重不是点击到首帧耗时，不能跨线程相加。末尾截断的 9.51 秒 severe hang 继续排除。

| trace | 区间起点（相对录制） | potential hang | 主线程样本 | 管线创建样本 | 编译调度样本 |
|---|---:|---:|---:|---:|---:|
| open-01 | 27.612771 s | 1098.590 ms | 1 | 12 | 21 |
| standalone | 25.471422 s | 459.538 ms | 1 | 3 | 4 |
| standalone | 29.205384 s | 639.118 ms | 9 | 2 | 5 |
| standalone | 31.805823 s | 522.746 ms | 10 | 2 | 2 |
| standalone | 35.506516 s | 481.946 ms | 1 | 3 | 4 |

管线/编译两列会重叠，不是独立次数，更不是耗时占比。

### standalone 的 639.118 ms 窗口

区间 29.205384333–29.844502750 s，App PID 52651。渲染线程 `0xb802c3` 在 29.335135458 s 的实际栈（以下由调用者向等待点排列）：

```text
SCNView._drawAtTime
  → SCNRenderer._drawScene / _renderSceneWithEngineContext
  → SCNMTLRenderContext.drawRenderElement / _executeDrawCommand
  → SCNMTLResourceManager.renderResourceForProgramDesc
  → newRenderPipelineStateWithDesc
  → SCNMTLLibraryManager.libraryForProgramDesc
  → AGXG17FamilyDevice.newLibraryWithSource
  → MTLLibraryBuilder.newLibraryWithSource
  → MTLCompilerScheduler.buildRequest
  → dispatch_sync / __DISPATCH_WAIT_FOR_QUEUE__
```

同一线程 29.666780208 s 转为创建实际 GPU 管线：

```text
SCNMTLResourceManager._createPipelineStateWithDescriptor
  → AGXG17FamilyDevice.newRenderPipelineStateWithDescriptor
  → AGX.createFragmentProgramVariant / compileFunction_Impl
  → MTLCompiler.compileFunctionRequestInternal
  → MTLCompilerScheduler.buildRequest
  → dispatch_sync / __DISPATCH_WAIT_FOR_QUEUE__
```

同期编译工作线程栈为 `MTLCompilerScheduler.createBlockWithData → MTLSchedulerRequest.generateXPCBlock → xpc_connection_send_message_with_reply_sync → mach_msg`。这表明请求正在同步等待编译服务回复；trace 未直接测出编译服务内部 CPU 工作量。

主线程 29.673412583 s 的栈：

```text
Coordinator.renderUpdate
  → updateTemporaryTopDownOverlay
  → updateMergedOverlay
  → SCNView.setBackgroundColor
  → SCNView._adjustBackingLayerPixelFormat
  → pthread_mutex_fairshare_lock_slow
  → __psynch_mutexwait
```

之后 29.711068208 s 等待 `SCNRenderer.autoenablesDefaultLighting` 的锁；29.739815500–29.840339791 s 可见 `synchronizeTemporaryTopDownScene → mirror → SCNNode.simdTransform / opacity → C3DSceneLock → mutexwait`。

因此同步函数慢样本包含**等渲染相关锁**，不能直接解释为 158 个节点的 CPU 遍历很重。当前采集没有锁地址/owner 的完整调度因果数据，不能声称已证明每个 mutex 的持有者就是上述渲染线程。

open-01 的 1098.590 ms 窗口也对应主线程 `setBackgroundColor → _adjustBackingLayerPixelFormat → mutexwait` 与渲染侧同步编译。该轮有调试注入，因此以 standalone 作为不依赖 Xcode 注入的更强证据。

## 2. 模拟器 1.34 秒事件：补齐系统编译时间线

原事件：`output/local-test-runs/eb59133f37894e8995c30fe4bc14c340/evidence/arm2-B/samples/activation-10.json`，同一 B 二进制第 10 次打开。此轮无系统采样器，不能事后补造 App 调用栈。

从宿主 unified log 按原 wall time 找到目标模拟器的 `SimMetalHost__QiuJi_Preview_09__36123`，其编译服务 PID 38800 记录 `MTLBuildFunctions - pipeline` BEGIN/SUCCESS。

| 北京时间 | 事件 |
|---|---|
| 15:17:51.978025 | 临时俯视 begin |
| 15:17:52.014018 | willRender |
| 15:17:52.397643 | SimMetalHost 开始连接编译服务 |
| 15:17:52.405021 | launchd 启动编译服务 |
| 15:17:52.426055 | 管线编译 BEGIN |
| 15:17:53.293009 | SUCCESS，服务报告 866.949916 ms |
| 15:17:53.317635 | didRender |

1303.62 ms 渲染区间可拆为：编译 BEGIN 前 **412.04 ms 未归因**，日志覆盖编译 **866.95 ms**，编译结束到 didRender **24.63 ms**。同期建树 1.35 ms，首帧前同步合计 1.31 ms。编译 ParentProcessName 指向该模拟器的 Metal host，**没有标出此 App 的具体管线**；时间高度吻合，但不能排除 host 服务其他进程的可能。

证据：`output/topdown-latency-device-20261115/slow-simulator-system-log.json`、`baseline-compiler-log.json`、`slow-simulator-compiler-alignment.json`。15:11–15:21 查询范围内该 host 仅找到这一对编译 BEGIN/SUCCESS。

## 3. 触发式复捕：先验证捕捉器，再测自然长帧

探针仅在隔离 App 副本写 first-will/first-did 的 56 字节标记；宿主确认会话、PID、模拟器及包路径，超过 100 ms 尚未 didRender 才启动 `sample`。常规帧无持续系统采样；标记写入本身仍有扰动，不能称完全无侵入。

先单独用 `-topDown.watchdogSmoke` 给第一次 willRender 加 600 ms 人工等待，验证所抓栈确实是 `scnview-renderer → TemporaryTopDownLatencyProbe.renderer(willRenderScene) → NSThread.sleepForTimeInterval`。人工延迟样本与真实测试分离，不算问题复现。

| 运行 | 有效自然开关 | 节奏 | didRender 中位数 | 最大值 | 自然触发栈 |
|---|---:|---|---:|---:|---:|
| `4c67edfd5c61421db2d68d83f1d5db6e` | 120 | 关闭后 1 秒 | 37.01 ms | 55.09 ms | 0 |
| `846c84601522450abfecca170c11c4fa` | 90 | 关闭后 0/100/300 ms 轮换 | 21.26 ms | 53.33 ms | 0 |

两轮共 210 个自然样本，真实运行未带 smoke 参数；7 个 UI 用例通过且每轮 30 份 JSON 完整。全部安装二进制 SHA 为 `241b9a28b93b6aba004fca90c5aa39a22dbe82718318c88edabe61a33c9d99aa`。快速轮只更换 UI Runner，覆盖恢复的是上一轮完整 App。didRender 仍不是屏幕呈现时间。

首个运行 `5044f2f8ff544e5cb5dc59f1d95bb9e0` 捕捉器自检失败：Xcode 重装后容器 UUID 变化，监控器仍读旧目录。修订为运行中持续重新查询容器后，自检成功；原失败保留、不计真实性能。此轮实际执行 Python 已加载旧代码，后续编辑不当作其原始脚本快照；修订后运行已在启动时冻结 runner.py。

## 4. 同一二进制的缓存干预：已抓到新的长帧栈

Apple 说明系统 shader 缓存可跨运行复用，未命中时需要编译；参见 [Build GPU binaries with Metal](https://developer.apple.com/videos/play/wwdc2020/10615/)。这说明“重复测试后来都快”可以与缓存有关，**并不证明本问题的缓存键、失效原因或原包缓存损坏**。

本机该 App 私有 `Library/Caches/com.xinkuan.qiuji/com.apple.metal/functions.data` 创建于 10 月 12 日，干预前最后修改于本次 15:18:26；Xcode 更换容器 UUID 后缓存数据仍延续。

运行 `29fa6995e90c46c8addcecb865a624d0` 复用以上完全相同的 App 与 rapid UI Runner，SHA 再次核对一致。只在 App 停止时备份、暂移它自己容器内的 `com.apple.metal` 与 `com.apple.metalfe`，随后恢复原件再测。系统共享缓存、其他 App、正式源码均不改。

| 条件 | 次数 | >100 ms | didRender 中位数 | 最大值 | 成功触发采样 |
|---|---:|---:|---:|---:|---:|
| App 私有 Metal 缓存暂移 | 30 | 9 | 21.42 ms | 540.95 ms | 8 |
| 恢复原缓存（逐文件摘要一致） | 30 | 0 | 21.56 ms | 53.25 ms | 0 |

慢的打开编号为 2/3/4/5/7/8/9/14/25，说明这个条件可以形成“同一进程内忽快忽慢”，不是仅进程首次打开。第 5 次 143.39 ms 未被触发式 sampler 及时抓到，其他 8 次都有栈。100 ms 只是诊断阈值，不是用户验收阈值。触发后系统采样会扰动剩余时间，表中约 500 ms 不能作为完全无采样的耗时基准；触发前已经存在 >100 ms 等待。

以第 2 次为例：begin 北京时间 16:05:57.055043，建树完成 +2.101 ms，willRender +19.062 ms，didRender +540.947 ms。sample 实际开始于 16:05:57.254，即 begin +198.957 ms，仍处于本次 521.885 ms 的渲染等待内。实际 App PID 75769、路径与 marker 一致，采样 exit 0；launch arguments 没有 smoke 参数。

该栈里，渲染线程经过 `SCNMTLResourceManager.newRenderPipelineStateWithDesc → SCNMTLLibraryManager.libraryForProgramDesc → MTLLibraryBuilder.newLibraryWithSource → MTLCompilerScheduler.buildRequest → dispatch_sync`；还捕到后续 `_createPipelineStateWithDescriptor → MTLCompiler.newRenderPipelineStateWithDescriptorInternal → compileFunctionRequestInternal → MTLCompilerScheduler`。主线程同时为 `renderUpdate → updateTemporaryTopDownOverlay → updateMergedOverlay → SCNView.setBackgroundColor → _adjustBackingLayerPixelFormat → __psynch_mutexwait`，与原慢包真机异常窗口相符。

证据在该 run 的 `evidence/cache-empty/triggered-stacks/`，代表文件 `38308DCF-DB5B-41FE-92F5-706BAFCA509A-activation-2.txt`（主线程约行 51–59，编译链约行 623–651）。`matched-render-stacks.json` 按实际 sample 报告时间与 first-did 对齐，8 份均在慢帧完成前开始；不是仅凭采样发起时间宣称命中。栈统计计数仍不转换成独立精确耗时。

这证明 **App 私有编译缓存的状态足以在同一诊断二进制上改变异常出现**，无需改变主 App 优化级别或业务源码。它不证明真机原包的私有缓存当时缺失/损坏，也未证明安装 UUID 就是缓存键。

### 进一步拆分：只改变 library/function 缓存仍可复现

运行 `35054a92d9ee46a89b4232f0e07e8872` 继续使用完全相同 App/Runner，只暂移 `com.apple.metal` 四个 library/function 文件，保留 `com.apple.metalfe` 前端模块缓存及系统共享缓存。

| 条件 | 次数 | >100 ms | didRender 中位数 | 最大值 | 命中慢帧的栈 |
|---|---:|---:|---:|---:|---:|
| 仅 library/function 缓存暂移 | 15 | 6 | 22.61 ms | 536.38 ms | 4 |
| 原 library/function 缓存恢复 | 15 | 0 | 21.14 ms | 42.88 ms | 0 |

4 次采样分别命中第 3/4/6/12 次，实际开始均早于对应 didRender；均包含上述编译等待和 backgroundColor/renderer 锁等待，sampler exit 0。15 个真实事件均无 smoke 参数。两轮 UI 用例通过、安装 SHA 一致。此结果把可复现因素进一步收窄到 **App 私有编译后 library/function 缓存**，前端模块缓存缺失不是本次复现的必要条件。

独立收尾核对当前模拟器缓存与第一轮备份，两个目录共 7 文件 SHA 全部相同（含未暂移的 frontend module 文件），见该 run 的 `final-independent-cache-check.json`。原1.34秒帧与这两次缓存干预慢帧仍是不同事件，不能把新栈冒称为旧帧补录。采样没有给出 renderer 实例地址、mutex owner、具体 shader/descriptor/cache key，因此对它们不作已证实断言。

结束时原缓存逐文件 SHA 恢复一致，见 `final-cache-restore.json`。可复现 App/Runner/xctestrun 与原正常缓存已另存 `output/topdown-latency-device-20261115/products/simulator-render-repro/`，2727 个文件摘要已保存；无需为下一轮重新构建改变二进制。此对照不等于 GPU 全冷缓存，不能外推成真机原包身份差异已解决。

## 剩余判别任务

1. 已取得新慢帧的首帧事件与 App 渲染等待栈；剩余需关联编译请求标识，定位具体 shader/descriptor/cache key。不要仅按函数名出现就判异常。
2. 在可复现条件下，仅改变构建身份或已确认缓存因素，证明原包/重建版的发生率差异；当前模拟器结果不足以结束这一步。
3. 未获得上述证据前不做正式性能修复，不移除已有防崩溃的 geometry 独立复制，也不以降低画质掩盖等待。


## 本轮收尾核验

五个本轮工作目录（5044 / 4c67 / 846c / 29fa / 3505，对应上文完整ID）均经 local-test-lifecycle complete 后为 reclaimed，原失败退出码与所有 evidence 保留。复现归档2727文件重新读取校验全匹配。借用 iPad 已 Shutdown、租约释放，未删除设备或用户数据。正式 QiuJi / QiuJi.xcodeproj / CuePhysWeChat 的 git diff 为空；本轮改动限研究脚本、诊断记录与采集规则。原真机包、独立重建真机包、trace及正常缓存原件继续保留。

补查新第2次慢帧的宿主Compiler unified log返回0条，文件保留；不把日志缺失解释为没有编译。本次直接证据来自同PID、同包、时间重合的App栈及缓存干预对照。历史1.34秒事件的宿主编译日志与新事件严格分开。


### 续查：具体 shader 及实际缓存哈希

外部LLDB对保留的同一模拟器App读取实际生成的Metal源码/选项。五类shader的变化仅为灯光排列及阴影纹理编号（每族7–8个源码变体，编译选项一致）；源灯光对象与复制顺序6轮相同。空缓存/原缓存成功对照有36个完全相同输入，编译行为不同；39个实际Metal library哈希在原缓存与新编译索引精确匹配。已确认运行时变体与缓存复用机制，尚缺原/新真机两包各自的逐请求shader/hash快照，不能将模拟器诊断结果冒充两真机包因果闭合。详 [SHADER-CACHE-ATTRIBUTION.md](SHADER-CACHE-ATTRIBUTION.md)。正式App代码未改，调试器轮不作为耗时基准。
