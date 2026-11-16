# 临时俯视打开延迟采样结果

2026-11-15。结论状态为本轮采样完成、异常根因未定位。用户明确症状是进入临时 2D 后等待球桌出现，iPhone 17 Pro 模拟器的分离角与走位也发生，通常首次打开更慢。现场重复打开及重新启动 App 后首次打开，用户均确认本轮正常。

本文依次保留初轮与真机续查历史。最新构建差异和 120 次模拟器测量见 [BUILD-COMPARISON.md](BUILD-COMPARISON.md)：重建方式 B 第 10 次也出现 1339.61 ms 首帧，其中 1303.62 ms 在 willRender–didRender，建树 1.35 ms；另 60 次带调用栈复测未再出现长首帧。已核主 App 均 -O，但微信 Swift Package 原包 -Onone、重建包 -O。尚未锁定原包为何更易触发，不能将此前正常反馈等同“重建即修复”。

## 对照结果

同一台本机 iPad Pro 13 M4、iOS 26.3.1，Debug -O，A 为 11 月 12 日 `259a2116b`，B 为 `dd6476979`。使用相同探针、UI helper 和本机忽略资源，顺序 B/A/A/B，每轮五次打开，后两次含拖球。四轮测试均通过，20 份 JSON 完整，安装包可执行文件 SHA 与对应构建产物一致。

| 指标 | A 旧版 | B 当前版 |
|---|---:|---:|
| 首帧 didRender 回调中位数 | 36.94 ms | 39.70 ms |
| 首帧回调范围 | 21.47–133.93 ms | 25.75–55.43 ms |
| 两次 App 进程内首次打开 | 36.15 / 51.67 ms | 50.12 / 54.95 ms |
| 建树中位数 | 1.10 ms | 1.17 ms |
| 挂载时刻中位数 | 7.25 ms | 7.82 ms |
| 各次稳态同步中位数再取中位 | 0.141 ms | 0.125 ms |
| 单次同步等待 SCNTransaction 锁最大值 | 0.00275 ms | 0.00988 ms |

每次打开都只建树一次。初始镜像 158 个节点、复制 103 个几何体；同一次打开不反复整树重建。拖动期间会少量创建/替换预测线节点，符合动态同步行为。统计中的数秒最大帧间隔包含测试主动等待及按需渲染停帧，不能据此判断拖动卡顿。

此结果不支持已测条件下出现持续的建树/同步性能回退。首帧前的大部分时间在挂载之后，但没有捕获用户描述的长等待，不能把这段正常调度时间命名为异常根因。

## 手机原安装包现场

借用用户明确指出的 `AE86244C-EE61-4585-882F-E39B892214DB`，保留其数据与安装包。先记录当前页面一次关闭再打开；随后通过 Xcode 的 Run Without Building 重启同一产品，用户进入 3D 页面后采集首次打开。两次 20 秒调用栈与录屏均完成，用户均确认正常。冷启动采样 App SHA256 为 `2d42f3d85cffaaf05c5223f0a2d0ecbec1f7be93b7458c61a413dd6e183fe85f`。

现场进程由 debugserver 启动，启用 `MTL_DEBUG_LAYER=1`、Metal interposer 和 GPU capture。栈中可见 `updateMergedOverlay → SCNView.setBackgroundColor → _adjustBackingLayerPixelFormat` 的锁等待，也有少量同步/事务提交等待。这是观察到的工作，尚不足以证明异常长等待来自这些函数。原采样中大量 AX 调用来自自动化读控件，需要排除，不能归因于普通用户操作。

Xcode 控制台显示 StaticClothIrradiance 因模拟器不支持 32-bit float filtering 而回退。该路径下 C1 固定光场与依赖它的 H9 分支不能直接当作此次模拟器回退原因。11 月 13 日的 guard-combo shader 仍是需要在真实异常首次编译样本中核验的候选。

## 证据边界

- 探针仅注入受管源码副本，工作区生产 Swift 文件和用户手机安装包未加入探针。脚本在 `scripts/research/topdown_latency_20261115/`，以后可复现注入。
- 计时从 CameraRig 激活临时俯视开始，不含物理触摸到按钮 action 的分发延迟。didRender 是渲染回调，不是屏幕呈现时间。
- A/B UI helper 会先规范到普通 2D 再进入 3D，可能预热正交投影相关渲染资源。它能比较建树和同步成本，不能作为完全冷着色器缓存的对照。手机补充采样未先切普通 2D，但也没有清除系统或驱动缓存。
- 无采样对照未运行，不能精确声称探针零开销。探针计时/计数/内存事件有成本，关闭俯视后写文件。系统调用栈采样与录屏也有额外负载。
- 无真机测量、全页面性能验收或性能修复结论。下一条有效证据应是异常首次打开当次的阶段时间与渲染线程调用栈，特别区分 shader/pipeline 准备、视图初始化、事务锁和输入分发。

## 证据位置与夹具返工

- 最终 A/B 原件 `output/local-test-runs/7d0ac51c29c549748da930f52a2e9bd1/evidence/`，含四个 xcresult、身份校验、20 份采样、summary.csv。截图从 xcresult 的工作副本导出并已查看，确认临时俯视实际显示。
- 手机原件 `output/topdown-latency-live-20261115/`，含 warm 现场与 `cold-debug/`。后者保留 PID、包指纹、采样起止与原始退出码。
- 首轮 `f1273e8fa0694cf1958bd2034e867960` 的历史构建失败源于当前单测引用新版诊断字段。只移除 Testables 不足以隔离，补移除 BuildAction 的单测目标后构建通过。
- 第二轮 `09b8e5d0da1f44d7b50bfe91137b2358` 缺少 UI helper 证据目录环境变量，测试体未开始。补入 `TEST_RUNNER_DAILY_ADAPTIVITY_DIR`。
- 第三轮 `48d6ac869dea4308bcf8512f2ce1338d` UI 测试通过，导出失败源于使用测试前的容器路径，Xcode 重装后容器 UUID 已变化。改为测试后重新查询。失败不计入最终 A/B。

TP16/17/29/30 本轮只观察模式、同步和创建/释放相关链路，未改交互合同；TP35 按以上证据边界报告，未开展整页视觉或设备矩阵验收。

四轮受管任务均已执行 complete，状态 reclaimed，保留原退出码及证据。两版临时源码/构建和 xcresult 检查副本已回收，首轮记录释放约 4.03 GB。借用的 iPad 已关机释放租约；手机保留原安装包和本轮用户查看的俯视现场，采样进程已结束、租约已释放。


## 真机续查（2026-11-15）

用户确认 iPhone 16 Pro 最新安装包仍慢。当前设备 iOS 27.2 (24B119)，CoreDevice 实查为 wired；保留现有连接，本轮不是温升对照。安装版本 1.0.0(1)，bundle com.xinkuan.qiuji，进程 52550，包容器 C806CC0B-794B-4516-BFCC-A8D893E0F4C8。版本号重复，具体源码提交尚未匹配。

按 PID 和进程名附加的三次短烟测均在录制开始前失败（xctrace 找不到目标）；原始日志保留。改用 5 秒 Time Profiler 全进程采样后成功，已导出 time-profile 并核对球迹 PID、包路径、设备及真实样本。启用等待线程，未加 GPU 仪器。45 秒操作轮已收到 started 通知，用户确认两次打开都明显慢；当前等待 trace 封存，尚不构成根因结论。证据：`output/topdown-latency-device-20261115/`。

模拟器此前未启用 C1/H9 实际分支；真机是否启用以及 shader 首次准备耗时仍需由本次记录确认，不能仅凭设备类型断言。

用户进一步纠正：操作轮中实际点击接近 10 次，期间有快有慢；不能按指示的“两次”假定真实次数或分配慢点。脱离 Xcode 重启同一安装包后仍有明显慢。两轮应作为多次开关的间歇性问题采样，精确点击/首帧标记尚缺。


### 已取得的真机调用链（仍不是逐次首帧计时）

两轮45秒原始trace均正常封存（exit0）。`open-01` 原Xcode运行实例 PID52550；`open-02-standalone` 同一安装包经devicectl无测试参数重启 PID52651。运行App UUID `DB22B0A9-EF02-3413-9838-48A7BB2704E0` 与本机产品匹配，SHA见 `build-identity.json`；没有重装/替换二进制。用户报告后一轮也间歇性慢，不能只归因Xcode注入。后轮导出已不见前轮的MTLDebug/GPUToolsCapture调用链。

- 后轮potential-hangs表记录4段：459.54、639.12、522.75、481.95ms。这是工具的响应卡顿区间，不是逐次点击到球桌显示的端到端时间。
- 后轮主线程反复进入 `renderUpdate → updateTemporaryTopDownOverlay → updateMergedOverlay`，等待点包括 `SCNView.setBackgroundColor → _adjustBackingLayerPixelFormat`、`SCNRenderer.autoenablesDefaultLighting` 和同步树内 `SCNNode.simdWorldTransform → C3DSceneLock`，以及事务flush。
- 同期渲染侧出现 `SCNMTLResourceManager.newRenderPipelineStateWithDesc → MTLCompilerScheduler` 的同步编译请求等待，还有 `CAMetalLayer.nextDrawable` 等待。
- 后轮 `setBackgroundColor` 栈的累计采样权重约1799ms，pipeline preparation约1817ms；这些是跨多次打开、可重叠的线程采样权重，**不能相加或当作单次耗时**。建树仅3个被采到的样本/约30ms权重；没有证据把主要长等待归因于CPU反复拷贝整树。
- 系统与App符号均按UUID匹配后用atos解析，保留原XML、符号映射验证与样本JSON。原导出出现dylib-overlap警告，记录保留；不将末尾截断的9.51秒Severe Hang当作已证实的开桌时间。

下一步：受管隔离诊断包细分SCNView创建、属性设置、同步、will/didRender，并为每次打开编号；之后按同包启动参数对照最近材质路径。正式源码未改。诊断注入的前两次预检因同文件另有frames计数器而拒绝非唯一锚点（未进入构建），r3已限定探针类作用域；两个失败工作目录已请求complete，原日志保留。


### 原包与独立构建对照出现差异（14:22之后）

受管诊断构建 `7006e3cc799440e490a1f038b7ef0a54` BUILD SUCCEEDED。默认C1/guard-combo实际启用，采到12次完整打开：首次didRender回调128.42ms，其余31.39–65.01ms，158节点/103geometry初建；用户确认这一轮都快。回调不是on-glass时间。关闭探针并重启同一诊断二进制，用户仍确认都快（未启动xctrace）。

随后覆盖恢复之前的原安装包，恢复副本SHA与原UUID匹配产品一致，无启动参数、无xctrace。用户确认原包仍会忽快忽慢。因而不能把此前异常全部归因于采样器，也不能把诊断版正常当作修复。

原包与诊断包均使用Swift -O /同Xcode与SDK。2675个包内文件仅7处不同：主可执行文件、扩展/签名及Assets.car；assetutil核共同资产内容摘要一致，诊断包多出8个非球桌资源变体（generic构建未对手机thin）。3D独立资源文件一致。正用完全未注入探针的原源码另做独立构建 `4e47044533394fed910450b736181827`，用于区分重建产物与探针关闭后仍可能改变编译/执行时序的影响。尚未判定历史增量构建缓存或某次提交为根因。


原源码独立重建 `4e47044533394fed910450b736181827` BUILD SUCCEEDED；四个俯视相关源码文件与当前仓库逐字一致，没有计时探针或性能修复。设备安装后用户确认“这版都快”。新包UUID `E7EBF4E8-0A5E-3590-BD75-6ECAEB0C5381`，SHA见clean-identity.json。原/新包核心俯视函数符号地址相同，共同cstring包含的渲染着色器文本相同；可执行段并非全字节一致，不能据此声称所有代码完全相同或断言增量缓存损坏。原包实际编译日志也确认 -O，排除简单的优化级别差异。下一轮仍用原慢包、无系统采样、仅临时 -rendering.referenceCloth 对照最近材质默认分支。


## 本轮真机结论与现场收尾

| 对照 | 系统采样器 | 用户反馈 |
|---|---|---|
| 原安装包默认材质，Xcode启动 | Time Profiler | 慢；实际多次开关，不能按两次解释 |
| 同原包脱离Xcode启动 | Time Profiler | 间歇性快慢 |
| 独立构建诊断包，探针开启 | 无 | 都快；12次didRender回调31.39–128.42ms |
| 同诊断包，探针关闭 | 无 | 都快 |
| 恢复原包默认材质 | 无 | 仍会忽快忽慢 |
| 原源码独立重建，没有探针 | 无 | 都快 |
| 原慢包 `-rendering.referenceCloth` | 无 | 仍会忽快忽慢 |

旧材质对照是当前二进制中的参考材质路径，不等于安装了历史版本；它同时关闭 guard-combo/C1/H9，其他当前代码保留。反馈支持“最近材质默认优化不是异常出现的必要条件”，不证明所有最近修改均无影响。

已定位的调用链包含临时层属性更新的renderer锁等待、树同步的scene锁等待及渲染管线准备；**尚未确认原包为何更易触发，也未定位引入问题的具体提交**。不能将重建版正常宣称为源码修复，亦不能把采样权重当单次打开时间。历史模拟器ABBA仍只支持正常样本范围。

手机最终回装并无诊断参数启动了用户确认正常的原源码独立重建版（UUID见clean-identity.json；回执final-clean-install.json/final-clean-launch.json）。没有正式源码性能修改，没有降画质/帧率。两份对照App作为复现产物保存于 `output/topdown-latency-device-20261115/products/`，全文件SHA清单manifest.json；原始trace/失败日志、逐次JSON、构建源和回执均保留。受管构建源/DerivedData已请求complete，具体回收状态以run.json为准。后续应从原慢包的现场等待入手，保留这一可复现对照，避免重新构建后暂时正常掩盖触发条件。


## 续查更新：已命中新慢帧的编译等待栈（16:13）

本轮先以触发式采样验证210次正常开关；随后同一诊断二进制与Runner，只暂移/恢复App私有Metal缓存，30次9慢（最大541ms）→30次全快（最大53ms）。进一步只改library/function缓存，15次6慢（最大536ms）→15次全快（最大43ms）。两种干预共12份栈在对应didRender之前开始，实际栈为SceneKit创建library/pipeline的同步编译等待，主线程同时等待renderer/scene锁；无人工延迟参数。正式代码未改，缓存原件逐文件恢复。此前“尚无慢帧同期栈”仅适用于原1.34秒事件，新事件已经取得；原1.34秒事件另从系统日志匹配到867ms编译。

这将可复现条件收窄到App私有编译缓存，不能据此认定原真机包缓存损坏、具体构建差异或提交为根因。原包为何比重建包更易触发、具体shader/descriptor键尚未闭环。逐次事件、完整栈、采样窗口独立对齐、产物身份和限制见 [RENDER-WAIT-STACKS.md](RENDER-WAIT-STACKS.md)。同一诊断App/Runner/xctestrun及原正常缓存归档于 `output/topdown-latency-device-20261115/products/simulator-render-repro/`，用于继续诊断，避免下一轮重新构建改变身份。


### 续查：具体 shader 及实际缓存哈希

外部LLDB对保留的同一模拟器App读取实际生成的Metal源码/选项。五类shader的变化仅为灯光排列及阴影纹理编号（每族7–8个源码变体，编译选项一致）；源灯光对象与复制顺序6轮相同。空缓存/原缓存成功对照有36个完全相同输入，编译行为不同；39个实际Metal library哈希在原缓存与新编译索引精确匹配。已确认运行时变体与缓存复用机制，尚缺原/新真机两包各自的逐请求shader/hash快照，不能将模拟器诊断结果冒充两真机包因果闭合。详 [SHADER-CACHE-ATTRIBUTION.md](SHADER-CACHE-ATTRIBUTION.md)。正式App代码未改，调试器轮不作为耗时基准。
