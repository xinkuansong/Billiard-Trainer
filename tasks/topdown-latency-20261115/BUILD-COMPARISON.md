# 原包与独立重建版差异核验

2026-11-15，继续诊断，未实施正式性能修复。用户改为要求模拟器验证；不再操作离线真机。前轮真机快慢反馈和调用栈见 RESULTS.md。

## 已确认的构建差异

两份原件保留在 `output/topdown-latency-device-20261115/products/`，身份以 manifest.json 为准。逐模块读取实际编译命令，不能只看主工程设置：

| 模块 | 原慢包 | 独立重建快包 |
|---|---|---|
| QiuJi | `-O` | `-O` |
| QiuJiLiveActivityExtension | `-O` | `-O` |
| CuePhysWeChat | `-Onone` | `-O` |

原因是重建命令的全局 `SWIFT_OPTIMIZATION_LEVEL=-O` 也传给 Swift Package；主工程自身的优化配置不等于依赖包配置。原先“优化级别相同”只对主 App 成立，不能扩展为整个包。证据为 `module-optimization-comparison.json`（含原始命令）。

Mach-O `__text` 减少 23,576 字节。按符号表中相邻代码地址计算范围，共同代码符号中 101,060 个范围长度相同，105 个不同；原包独有 69 个，重建版独有 19 个。**所有以 `_$s5QiuJi` 标识的主模块代码符号均无增删、无范围长度变化**。变化包含 CuePhysWeChat 与 Swift/Foundation 通用辅助函数，不能把“整个二进制字节不同”当作俯视代码发生变化的证据；符号范围长度一致也不等于全程序语义等价。

## 俯视关键机器码

对照 updateMergedOverlay、makeTemporaryTopDownRenderScene、synchronizeTemporaryTopDownScene 及相关镜像/闭包共 6 段函数。保存原始反汇编，解析调用 stub、Objective-C 类引用、全局符号及字符串引用；不直接抹去所有数字比较。

- updateMergedOverlay：719 条指令；镜像建场景 121 条；递归 mirror 629 条。已解析差异均为链接地址/引用位置变化，未发现不同的业务操作或调用目标。
- synchronizeTemporaryTopDownScene：425 条指令，除链接引用外保留一处立即数差异 `82 → 150`，是调用 `_swift_isEscapingClosureAtFileLocation` 的长度参数，恰好对应原仓库与隔离构建的源码绝对路径长度；行号、列号及调用目标一致。该差异不是节点遍历数量或同步次数。
- 这是一项针对关键函数的机器码核对，不是全程序形式化等价证明。脚本报告保留未归一化差异，未把它们自动判作相同。

证据：`text-symbol-size-comparison.json`、`render-function-*-original.asm` / `*-clean.asm`、`render-function-comparison.json`；脚本在 `scripts/research/topdown_latency_20261115/compare_*.py`。

两份 Assets.car 分别 222/230 项，共同资源内容摘要无差异。重建版多 8 项 BrandLogoMark、AppIcon、IntroSpinPad 尺寸/设备变体；原包按设备裁剪，重建版 generic 构建。前轮独立 3D 资源 SHA 核对一致。新证据为 `original-clean-asset-comparison.json`。没有据此推断 GPU/驱动内部缓存一致。

两包 `otool -L` 的链接库列表与 codesign entitlements 也一致，原始结果在 `link-signing-comparison.json`。UUID、签名摘要和链接布局不同是事实；它们是否改变驱动/管线缓存行为未验证。

## 验证设计与边界

模拟器使用同一份当前源码、同一份隔离探针、同一个 UI 测试 Runner，A 继承项目设置，B 全局 `-O`。A/B/B/A 每轮全新 App 进程、15 次开关；直接从 3D 进入，取消此前普通 2D 预热。实际包 SHA、首次 begin 时间、15 个采样文件均校验。探针只存在于受管源码副本。

iPad 运行：`output/local-test-runs/eb59133f37894e8995c30fe4bc14c340/`。首轮测试体通过后 Xcode 额外诊断停在 collectSimulatorDiagnostics；仅终止本轮子进程 simctl diagnose（有 PID/命令记录），xcodebuild 最终 exit 0。后轮加 `-collect-test-diagnostics never`，不改变 App 或采样逻辑。

此对照是重现两种构建方式，**不是把保存的 iPhone 真机二进制安装进模拟器**。didRender 为回调时间，不是屏幕实际呈现时间；未清理宿主 GPU 缓存。模拟器能力分支按采样记录判定，不能将模拟器正常外推成真机根因已排除。

## 首轮结果：重建方式 B 也出现一次长首帧

四轮均 exit 0，60 个逐次文件完整、安装 SHA 匹配：

| 轮次 | 中位 didRender | 最小–最大 | 进程内首次打开 |
|---|---:|---:|---:|
| A1 | 23.87 ms | 21.30–51.26 ms | 51.26 ms |
| B1 | 37.67 ms | 22.84–1339.61 ms | 52.92 ms |
| B2 | 37.22 ms | 21.43–50.75 ms | 50.62 ms |
| A2 | 37.47 ms | 23.04–53.50 ms | 36.21 ms |

**B1 第 10 次打开异常：**开始后 8.44 ms 建树完成，8.72 ms 挂载，35.99 ms willRender，1339.61 ms didRender。建树阶段 1.35 ms，首帧前两次同步合计 1.31 ms，backgroundColor 设置 0.020 ms；1303.62 ms 落在 willRender 与 didRender 之间。该次仅建树一次，158 节点/103 geometry；C1 实际 false，guard-combo 实际 true。首轮没有系统采样器，因此没有该 1.30 秒的线程栈，不能直接将其命名为 shader 编译或等同真机同一根因。

这打破了“B 构建方式只能快”的假设：同一 B 二进制、同一进程前后打开大多正常，异常发生在第 10 次，不能只归因进程首次建树。已有差异仍可能影响发生概率，但没有证明微信依赖优化级别导致延迟。iPad 首帧/末次截图已导出，已查看 A1 首次截图确认俯视球桌实际呈现；不是完整视觉验收。

计划补干净 iPhone 17 Pro 时，生命周期管理器返回本机临时容量已满；未创建、未启动设备、未运行手机测试。保留拒绝记录 `86024eead91f45cb8217f750af64c986` 并已 complete/reclaimed。没有清理或占用其他任务设备。

转在同一已复现的 iPad 复用原 A/B 产品，加入每秒一窗、5 ms 间隔的宿主 `sample`，按 wall time 与慢帧关联。运行 `5be94e07b7e64a748cb1e90b32a801b8`，采样会影响时序，不能与无系统采样轮混为同一条件。

四轮又完成 60 次，全部 exit 0、安装 SHA 匹配。A1/B1/B2/A2 的首帧中位数依次 37.72/37.44/39.56/39.11 ms，最大 58.53/59.37/71.47/58.34 ms。197 个宿主采样窗口均 exit 0；未复现 >100 ms 首帧。正常窗口也可见 pipeline preparation、SceneKit 锁和 nextDrawable，因此**仅出现这些函数名不能证明某次长等待的原因**。原 1.34 秒异常仍没有同期调用栈。

计划继续集中 B 包复捕时，两次租约预检被另一个 Designed for iPad/macOS 构建判为共享环境占用（`2e9bcfa365f34487a66920666d4255f9`、`bb82410f114c4e5db5ae9c976ff7b7df`）。未启动测试，不计入样本，不绕过保护；两个拒绝记录均已 complete/reclaimed。后轮与首轮共 **120 次有效测量**，不是 180 次。前轮 Xcode 附加诊断收尾、临时手机容量拒绝、追加 B 复捕拒绝均独立记账，没有把它们写成 App 性能失败。

本轮没有正式 App/工程/依赖源码修改。保留两份真机原件、逐次数据、调用栈、命令、隔离探针源、截图与二进制比较；受管工作目录按核验结束回收。下一项有判别力的证据是慢帧同期渲染线程栈，或在可复现原包上只改变一个构建/运行身份因素的结果；当前模拟器重建对照不足以证明原真机包的触发机制。

收尾已实查：两个有效运行及三个预检拒绝运行的工作目录均为 reclaimed，原退出码保留；iPad 为 Shutdown、未删除设备或数据。原真机产品与 evidence 未回收。正式 QiuJi / QiuJi.xcodeproj / CuePhysWeChat 无本轮源码差异。

当前已确认“同源码构建产物为何不同”的一部分，尚未证明“哪一处差异导致原包更容易慢”。SceneKit 属性/场景锁等待和 Metal pipeline 准备仍是已有真机异常样本的直接等待链；增量缓存损坏、UUID 缓存键等均没有单变量因果证据。


## 续查更新：已命中新慢帧的编译等待栈（16:13）

本轮先以触发式采样验证210次正常开关；随后同一诊断二进制与Runner，只暂移/恢复App私有Metal缓存，30次9慢（最大541ms）→30次全快（最大53ms）。进一步只改library/function缓存，15次6慢（最大536ms）→15次全快（最大43ms）。两种干预共12份栈在对应didRender之前开始，实际栈为SceneKit创建library/pipeline的同步编译等待，主线程同时等待renderer/scene锁；无人工延迟参数。正式代码未改，缓存原件逐文件恢复。此前“尚无慢帧同期栈”仅适用于原1.34秒事件，新事件已经取得；原1.34秒事件另从系统日志匹配到867ms编译。

这将可复现条件收窄到App私有编译缓存，不能据此认定原真机包缓存损坏、具体构建差异或提交为根因。原包为何比重建包更易触发、具体shader/descriptor键尚未闭环。逐次事件、完整栈、采样窗口独立对齐、产物身份和限制见 [RENDER-WAIT-STACKS.md](RENDER-WAIT-STACKS.md)。同一诊断App/Runner/xctestrun及原正常缓存归档于 `output/topdown-latency-device-20261115/products/simulator-render-repro/`，用于继续诊断，避免下一轮重新构建改变身份。


### 续查：具体 shader 及实际缓存哈希

外部LLDB对保留的同一模拟器App读取实际生成的Metal源码/选项。五类shader的变化仅为灯光排列及阴影纹理编号（每族7–8个源码变体，编译选项一致）；源灯光对象与复制顺序6轮相同。空缓存/原缓存成功对照有36个完全相同输入，编译行为不同；39个实际Metal library哈希在原缓存与新编译索引精确匹配。已确认运行时变体与缓存复用机制，尚缺原/新真机两包各自的逐请求shader/hash快照，不能将模拟器诊断结果冒充两真机包因果闭合。详 [SHADER-CACHE-ATTRIBUTION.md](SHADER-CACHE-ATTRIBUTION.md)。正式App代码未改，调试器轮不作为耗时基准。
