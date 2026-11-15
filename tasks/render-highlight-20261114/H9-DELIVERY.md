# H9：球位常量直接读取与逐灯遮挡复用

2026-11-14。接续 [H8 编译核查](H8-CAPTURE.md)和 [H9 事前计划](H9-PLAN.md)。本轮找到通过既定门槛的候选，已默认接入共享 App 台呢入口；生产分支构建和编译程序复核通过。

## 改动与适用范围

原程序将 16 个球位从四个矩阵常量复制成片元局部数组，再按动态索引读球。H9 在着色器中把同一份 256-byte 输入声明为 `float4 contactBalls[16]`，直接从 constant 地址空间读取。CPU 端提交格式和字节不变；实际 GPU 哨兵检查确认新旧声明读取的 16×4 分量与 CPU 输入完全一致。

同时保留原有逐灯、逐球的保守锥体判定结果，以两个掩码供各灯采样循环使用，避免每个灯样本重新检查属于另一盏灯的球。域外、退化灯几何仍使用完整原掩码；余下球按原升序相乘。64/8 光样本、BRDF、高光、法线、粗糙度、球影滤波、AO、HDR/4xMSAA 与现有 C1 场不变。

实现放在 `StaticClothIrradiance.swift` 的 `ClothShadowProgram`，由 `MobileReferenceLighting.refreshClothLighting` 在成功安装 C1 后调用。输入、输出 shader 均核对 SHA-256，不匹配则继续使用 C1。无需新增纹理、逐帧准备、CPU 球位上传或页面开关；额外文本处理只在材质准备/重建时发生。

- Debug 和生产分支默认启用。Debug 可用 `-rendering.noConstantClothBalls` 回到 C1；`-rendering.referenceCloth` 回原参考配方；生产分支忽略诊断参数。
- 范围沿共享 R/guard-combo/C1 配方，包括分离角与走位、每日清台及其余同配方 3D 消费者，来源清单沿 [B4](../render-activity-20261113/B4-COVERAGE.md)。本轮实际运行共享刷新函数，不把源码覆盖写成逐页新验收。
- 当前精确资格为 16 个球位槽。自定义球导致容量扩至 32 等不支持配方时保留既有回退；固定灯、资产或源身份不符亦不强套优化。
- TP16/17/29/30 继承模式、相机及资源合同；TP35 分列本机材质视觉、程序/构建检查和未验的真机/用户体验。没有页面布局或业务行为改变。

## R1 与 R2：性能判定

比较基线均为**已经启用 C1 的版本**。Apple M5 Pro 原生 SceneKit 真实 USDZ 台呢材质；含桌体其他材质，没有物理球模型、SwiftUI 页面或真实击球。每个镜头 6 组 AA、6 组 AB，交替 ABBA/BAAB；表内为每组均值的相对变化中位数。负值表示 GPU command buffer 时间下降，不是功耗下降。

| 候选及尺寸 | 近景 AB / AA | 俯视 AB / AA | 低位 AB / AA | 判定 |
|---|---:|---:|---:|---|
| R1 只改 constant array，700×400 | −3.59% / +0.31% | −1.44% / +0.45% | −2.68% / −0.16% | 未过近景 5% 门槛 |
| R2 加逐灯 mask，700×400 | −6.08% / −0.78% | −3.10% / −1.16% | −1.66% / −3.06% | 近景通过；其余不退化 |
| R2，1400×800 | −7.50% / −0.26% | −7.24% / +1.46% | −4.22% / +1.03% | 近景通过；其余不退化 |

沿事前规则：近景收益必须大于 max(5%, abs AA)，非目标镜头回退不得超过 max(3%, abs AA)。700 低位 AB 小于 AA 漂移，不认定其有可辨收益。扩展分辨率后仍通过，未通过重复试验筛选最好的一次。

结构化原始统计：[R1](H9-R1-results.json)、[R2](H9-R2-results.json)、[R2 1400](H9-R2-1400-results.json)，含每组 CPU 编码、同步墙钟和 GPU 时间，不用源码算式数量冒充成本比例。R1 生成器首次失败和修复另见 [R1 记录](H9-R1.md)，不删除失败证据。

## 画面及生产接入核验

三轮初筛各 18 组输入 AA/AB 均为零差。扩展 1400×800 共 **74 组**：六色×三机位×两球态 36 组；法线 0/1、粗糙度 0.05/1 的近景两球态 8 组；空球、仅第 16 槽、16 球重叠/半透明、零高度、台面以下、锥体界限/灯以上、X/Z 域外及权重 1 的十类边界×三机位 30 组。最大通道差 0，AA 变化像素 0。原始 PNG/BGRA 与逐项数值均保留，有限测试不等于所有输入形式证明。

生产合同检查直接抽取当前接触 AO 生成段、灯具/高光生成器和**完整共享材质刷新函数**，编译当前 `StaticClothIrradiance` 与 `DailyClothSupportExperiment`。场景状态使用明确的最小容器，真实 SCNMaterial 接收刷新结果；未使用完整 App 宿主。Debug/非DEBUG 各执行默认、C1 对照、原参考、禁用场四种启动模式；每模式验证 16 与 32 槽、PBR 保留，五种未知/重复/已转换源全部拒绝。

实际共享函数产生的 H9 源码与实测候选逐字一致；Debug C1 对照与实测基线逐字一致。两种构建条件均默认开启；非DEBUG 不受上述对照参数影响。故本轮没有再重跑相同 74 组排名/画面来代替集成检查。

| 身份 | SHA-256 |
|---|---|
| C1 完整 surface 输入 | `56fde5864ef300c78e7026f890f58c753710fce194bcee9c6dcd778117552d83` |
| H9 完整 surface 输出 | `14a880284fffc793f01d0357b0a625559101609d7986c9ac0cac72e7085efa4f` |

## 编译程序复核

同一轮捕获、同一机器、1400×800，Xcode Full / Overlapping / Medium。两份台呢均核到 command buffer 3、render encoder 2、API 27、58,830 个 UInt32 三角形索引；资源含原球位 buffer、rail AO、两张 C1 场及法线/粗糙度。基线 pipeline 2，H9 pipeline 7，未按函数同名猜测对象。

| 指标 | C1 基线 | H9 |
|---|---:|---:|
| 台呢 fragment allocated / high registers | 252 / 252 | 252 / 252 |
| 台呢 fragment spilled bytes | 272 | **0** |
| 台呢 fragment SIMD groups | 37,094 | 37,094 |
| Xcode Shader Cost | 86.43% | 88.36% |
| 主 encoder FS ALU instructions | 3,025,750,384 | 2,933,399,824（−3.05%） |
| 主 encoder FS invocations | 1,132,864 | 1,132,896 |
| 主 encoder FS occupancy | 20.22% | 69.41% |
| 主 encoder Stack L1 read / write bandwidth 原值 | 105.90 / 253.85 | 6.85 / 9.35 |
| 主 encoder L1 stack residency | 51.70% | 4.78% |

H8 单独逐灯 mask 仍有 272 bytes spill，H9 组合变为 0；与本轮实际配对 GPU 收益共同支持减少动态局部球位数组的方向。并未获得逐源码行归因，也不能把所有收益仅归给某条指令。主 encoder 含其他桌体材质，非台呢独占计数。CSV 未标栈带宽单位，因此保留原值；两个版本 Register Pressure Influence 仍为 0，不将 occupancy 提升夸大成已经证明的唯一瓶颈。Cost 占比升高也不表示绝对耗时升高。

单次回放 1.20 / 1.12 ms 仅留档，不用于计算收益；性能以 R2 平衡对照为准。两份均通过 File → Export 勾选 Embed performance data 保存完整统计原件，并逐成员校验归档；另保留原始捕获、CSV 和明确标为 UI 转录的 shader 表。[编译结果](H9-compiled-results.json)。

## 构建与门禁

完整 iOS App 构建 `BUILD SUCCEEDED`，签名深度严格校验、C1 资产 SHA 和构建前后源身份通过。沿既有受管入口，以 Debug 配置清空 Swift DEBUG 条件，实际 swiftc 命令无 `-DDEBUG`，覆盖生产 Swift 分支；没有更改尚未就绪的 Release API/HTTPS 配置，**不是正式 Release Archive 或真机运行验收**。

当前实际类型的 Debug/非DEBUG 资源测试仍通过默认开关、纹理读回、资源共享/释放以及缺失、损坏、截断后的同进程恢复。`verify-gate` 通过，日志 `output/render-highlight-20261114/h9-integration/verify-gate.log`。本轮没有再次运行旧 GPU 排名或借用用户手机。

最终读回核对当前构建源身份、74组逐项变化像素、8组启动/编译条件合同、留存文本证据哈希、Python语法与差分检查均通过；文档体积99KB、当前状态9条通过。[集成机器结果](H9-integration-results.json)。

## 证据索引

以下均位于 `output/local-test-runs/<ID>/evidence/`：

| 项目 | Run ID |
|---|---|
| R1 | `2bd005751c8f44fd8eb4685c0cea17da` |
| R2 700 | `a618ceca525f46099ec89b8b2fb45682` |
| R2 1400 | `f3b55af0fd5b4aff900025099e474daa` |
| 扩展 74 组与 ABI | `e20798afc1d24a04a6a908a8a51c23bf` |
| 当前生产共享刷新合同 | `ed3af66384c0418ea87e5fc20fbff591` |
| 当前 iOS 生产 Swift 分支构建 | `2414749fdf1e475f844de025fd381d93` |
| H9 编译程序捕获与 Xcode 分析 | `5ccbc38c30c94924a2266f5a6e148d29` |

前六项均已由生命周期回收临时工作目录，原始证据与哈希保留。H9 分析窗口已关闭，用户原有 QiuJi 项目窗口及运行会话保持。

H9 捕获 run 已明确 complete、退出码 0，含统计原件的两份归档均验证成功；生命周期因 Xcode/GPU 工具仍引用工作目录而记 `cleanup_deferred`，尚未回收。没有为清缓存退出用户 Xcode 或终止共享进程；后续受管任务会重试。H8 分析目录同样已 complete 但暂缓回收，两者不影响源码交付或证据留存。

2026-11-14后续更新：用户明确批准退出Xcode并回收临时副本。H10期间释放对应孤立GPU回放进程后，H8/H9两项均由生命周期工具回收，状态`reclaimed`，归档证据与哈希保留；QiuJi项目已重新打开。[收尾记录](H10-R2.md)。上述暂缓状态为历史断点。

## 边界与后续

尚未取得整页/手机 GPU 收益、连续击球温升和最低 iOS 的实际绘制结果；7.50% 不能改写为手机省电率，也不与旧 C1 19.7% 简单相加。本轮不改变帧率、画质档位或物理算法。far 完整高光预积分/LTC、其余材质与剩余 CPU 维护仍未实现；前面失败候选不推广。
