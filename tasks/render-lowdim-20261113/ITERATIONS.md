# 3D 渲染持续研究记录

日期：2026-11-13。状态：**R23完整生产动态画质与GPU对照、R24进入成本、R25重复进入资源及R26页面功能已取得证据。R32完成8组真实整页固定相机操作：第一ABBA因缺一次App输入无效；第二BAAB可比较，reported GPU均值约下降5.18%，呈现间隔基本不变，尾分位与基线波动不支持稳定整页净收益。** 每轮保留原始结果与边界；本轮结束追加采集，研究目标尚未标记整体完成。

最新结果入口：[候选选择、量化收益、接入与边界](RESULT.md)。

沿用 [handoff](HANDOFF.md) 的画质、物理、交互、120 帧和资源目标。这里的“最好”指在同条件下经过证据比较的最佳候选；无法证明所有可能实现中的全局最优。每轮保留原始结果，失败候选不进入正式默认。局部数学、真实材质、完整场景、完整页面和真机持续表现分别判定。

**用户后续修订**：性能优劣以[通用评价口径](EVALUATION.md)为主，单台手机型号/电池/温升不是主判断标准。原120Hz和温升门槛用于对应使用条件的补充体验验证，不作为单设备算法裁决。当前手机暂不方便，继续所有其他验证。

当前正式 R 仍为默认和有效回退。已新增每日场景的显式 DEBUG 研究入口及安装状态诊断，本地页面/缓存验证闭合；Release、未带开关的默认程序、模型、物理和相机配置保持。完整Release构建因发布配置缺项未执行。

## 当前结论与下一步

- **尚无已经验证的整页性能改进**。当前最有希望的候选已转为保守遮挡范围收紧，保持原灯采样和全部光照公式，不再先假定方向矩是必经路径。
- 分离 dispatch、全台 18 层字段、两版逐像素方向矩，在当前全台世界栅格中都没有稳定净收益。保留实现和失败证据，不能挑选近影密集样本中的有利行冒充整页效果。
- 已提取 516,599 个真实可见台呢输入；原始 texel 法线远比实际过滤法线陡。K2/K4/K8 在真实材质上的画面误差较小，但完整生成成本仍没有普遍净收益。
- 发现实际床面世界 Y 重建略低于 .8 时，原保守 mask 会检查所有球。中间版本plain在两台原生 Mac、三档分辨率的16球材质场景有32%–43%收益，两球约1%额外开销；两套iOS生产场景图像对照通过。这是plain历史结果，不是最终组合或完整App呈现帧率。
- 历史整体cone与新mask的有限域守卫组合已完成双机同轮三臂比较，当前优先选择它；相对plain中位再省约2.8%–7.4%，低像素仍有反向轮次，不声称所有帧获益。严格/快速浮点边界返工和失败证据保留。
- 最终guard相对R的隔离台呢配对中位GPU耗时，两球减少约3.7%–4.9%，16球减少约34%–46%；45张页面图已审，38目标方法均有通过证据。P3所选页面功能接入矩阵通过；完整成本、连续多视图和长期生命周期未完成，最低iOS17仍待补。P0整页trace、P4持续表现同样未完成。动态字段因未获净收益没有进入生产接入，不为完成原计划而继续扩大未满足准入条件的实现。
- R17–R30原失败保留。R31用系统自带metalperftrace确认逐drawable来源；R32取得一个有效BAAB，均值下降但尾分位未一致改善，不能稳定排名或推广为FPS提升。用户随后质疑再次测试，主控撤销新增实验安排；当前只基于已有证据整理交付和未验边界，不自动把每个未验项转为下一轮测试。

## R1：生产参考与方向矩点值

详见 [首轮报告](REPORT.md)。4,608 点与生产生成 Metal 对拍，最大绝对差约 3.6×10⁻⁶；K32 单样本分组退化控制吻合。K8 在 raw 配对材质域的近档高光相对误差 P95 约 2.4%–2.9%，不等于像素误差。

近影倾向、交错输入的混合消费者变慢；只选适用点时变快。下一步必须改变组织并计入额外成本，不能只统计适用点。

### R1 参数解释的补充核对

原报告的 `normal.intensity=1` 是 USDZ **刚导入**状态。生产 `MaterialFactory.enhanceClothMaterials(...preservesClothResponse:true)` 随后设为 **0.65**，并应用 multiply tint。原始贴图数据保留为压力域，不再用于描述最终表面法线分布。

生产还在 `MobileClothAlignment.apply` 中用 geometry modifier 将默认原床面约 Y=.794738 抬至物理 Y=.8。实际最终 shader 必须同时保留 surface 和 geometry modifier；仅复制 surface 不足以复现生产台呢及 rail AO。

## R2：GPU 分类与分离消费

假设：交错样本中的混合回退成本可以通过分类与专用 dispatch 降低。

实现：同 command buffer 内清零计数 → GPU 分类索引 → GPU indirect args → 专用候选和原参考消费。所有阶段计成本，没有中间 CPU 读回。

结果：8×24,576 输入全部通过分类覆盖/唯一性、候选输出对拍与 fallback 逐位一致。每 command 8 次完整编码，9 轮 ABBA/BAAB。

| 输入 | 单球 split 变化 | 散台 split 变化 |
|---|---:|---:|
| 原近影交错夹具 | −28.33% | −38.03% |
| 同夹具按空间排序 | −17.56% | −31.25% |
| 全台栅格行顺序 | +72.79% | +1.46% |

全台栅格候选比例仅 0.93% / 23.77%，而近影夹具是 64.06% / 70.31%。同样记录只重排位置，naive mixed 也会从变慢反转为变快。具体硬件根因缺少 counters，不指定为已证实的寄存器或分支问题。

决定：否决全域无条件分类的这版执行组织；保留专用消费作为机制对照。继续真实覆盖与更简单候选。

证据：[split-r3/REPORT.md](../../output/render-lowdim-20261113/split-r3/REPORT.md)、`split-r2` 原短采样、`split-r3` 全部原值与源码快照。

## R3：全台空间场与半精度

假设：将方向矩按世界位置复用，可以偿还字段生成和采样成本。

实现：18 层 RGBA16F（MV、M0、16 组）；端点网格覆盖床面 X±1.27/Z±.635/Y=.8。每个 texel 始终用原高采样灯网格，实际接收点独立判 near/guard，避免插入远档采样的不连续表示。生成和消费在同一 command buffer；每次完整迭代都重新生成字段。

### 数值与存储

独立 CPU 检查 5 类球态、128/256/512 宽、FP32/FP16。256×128 的遮挡比值最大绝对误差：单球 .0261、球架 .0737、散台 .0252、重叠 .0410、边缘/高度 .0258；部分球架最坏点在球的平面投影下，不把它们冒充可见像素，但球外也存在误差。

这些空间误差大于只做点值 K8 的漫反射误差。FP16 相对 FP32 的变化小得多，主问题是空间近似，不能靠更高存储精度解决。

256×128 纹理实测分配 4,751,360 字节；三份 14,254,080 字节尚未计其他新增资源。512×256 单份 18,956,288 字节，已超过 16 MiB 护栏。

第一版隐式 half 写入与 NumPy 最近舍入不一致；第二版显式 half4 转换并补 RGBA32F 控制。硬件双线性也存在可测的权重离散误差，不能默认 CPU 连续权重模型与 GPU 相同。完整细节保留在原生报告。

### 包含生成的 GPU 总成本

同输入、每 command 8 次完整生成与消费、9 轮交错配对；Apple M5 Pro，非 iOS：

| 全台行顺序 | 接收点 | R ms | 字段总 ms | 变化 |
|---|---:|---:|---:|---:|
| 单球 | 24,576 | .1074 | .2361 | +118.24% |
| 散台 | 24,576 | .2713 | .4720 | +72.81% |
| 单球 | 393,216 | 1.1039 | 1.3728 | +25.10% |
| 散台 | 393,216 | 3.5547 | 4.5832 | +28.34% |

大规模、近影倾向且空间排序的输入可以快约 49%–51%，但不能替代全台成本。所有 fallback 逐位一致；独立 CPU/Metal RGBA32F 全字段最大误差约 2.19×10⁻⁵。

决定：当前全台 18 层组织不晋级。继续低存储表示、真实片元输入与局部场的必要性比较。

证据：[原生字段报告](../../output/render-lowdim-20261113/field-gpu-ordered-r2/REPORT.md)、[CPU 空间矩阵](../../output/render-lowdim-20261113/spatial-r1/results.json)。

## R4：局部支持域加密

假设：球影只占局部区域，在每个球的保守支持范围生成小纹理，可用较少 texel 得到更高局部分辨率。

实现：每个 tile 都计算**所有球**的完整遮挡；按最小包含 tile 选择，不把已分组的单球光照相乘。32/48/64 方形网格，FP16、双线性，仅 CPU 数值研究。

结果：64×64 每球 tile 下，比值 P95 单球 .00267、球架 .00873、散台 .00368、重叠 .00387、边缘 .00249。比全台256网格改善，但最坏值仍不能忽略，而且分辨率变化的单点最大误差不保证单调下降。16 球的 64 网格单份 9 MiB；三份将超预算。48 网格单份 5.0625 MiB，三份接近预算且还未计其他资源。

决定：保留作为误差/内存权衡证据；未证明 GPU 净收益，不立刻扩写此路线。tile 接缝、移动、覆盖版本、真实像素尚待研究。

证据：[local-field-r1/results.json](../../output/render-lowdim-20261113/local-field-r1/results.json)。

## R5：逐像素原地分组，避免空间插值

假设：保留64次原遮挡计算，仅将近区高光由64次BRDF减至16次，可能不需要空间场。

已运行两个版本：16个长期存活方向矩；2个滚动方向矩、每完成一组立即消费。同公式、原样漫反射、原 far/guard 回退。

初步结果：两版全台栅格均退步；滚动版单球约 +44.5%、散台约 +36.8%。原交错夹具约 +50%，空间排序近影夹具约 −0.6% / +1.1%，没有稳定净收益。候选与独立 CPU 对拍、漫反射不变、fallback 逐位一致。

决定：减少 BRDF 次数本身不构成性能成果。继续更少分组与实际过滤后材质域，不重复扩大 K8 原型。

证据：`output/render-lowdim-20261113/inline-r1/`、`inline-r2/`；详细报告整理中。

## R6：真实材质和 iOS 生产场景

macOS 隔离 SceneKit harness 已实际加载默认 USDZ、真实法线/粗糙贴图、production contact/cloth surface、PBR、HDR和灯。红色控制证明替换生效；参考恢复作为稳定性检查。

首版 `visual-r1` 漏了生产 geometry lift，明确保留为准备失败，不作为最终生产材质画质结论。第二版补齐后正在复验。Float32诊断常量 (.25,.5,.75) 校准精确，避免PNG颜色空间误读；原始surface normal实测接近竖直，和原texel分布有显著差异，最终统计以修订后数据为准。

独立新增 [ClothLowDimResearchTests.swift](../../QiuJiTests/ClothLowDimResearchTests.swift)，直接实例化生产 `AngleTrainingScene`，固定真实停稳球局，核实际可见球集合、最终材质和原R源码，捕获全台/低位/袋口/2D回归四机位。测试附件保留原图、候选、红色控制、恢复与像素统计。测试通过仅表示夹具有效和恢复成功，不自动宣布候选画质接受或性能达标。

远端快照首轮检测到复制期间漂移并拒绝发布，保留日志；复核未发布副本与当前源一致后重新冻结，未跳过校验。源码快照/构建/测试及资源收尾结果继续追加。

完成结果：Mac mini / Xcode26.2 / iOS26.2，作业 `cloth-lowdim-ios-r1-20261113` 实际定向 1/1 通过、0 跳过。快照 `e93497f1fa24cac267537e014c075ccfb3efe450c316c24694ae6fe929cc8f12`；真实完整生产场景 4 机位中 K8 相对 R 最大 RGB 差均为 1/255，重复 R 与恢复完全相同。不同通道数变化分别为全台704、低位3833、袋口2531、俯视872。此项证明实际接线和图像差异，不是性能或用户画质接受。原始附件/日志在 `output/render-lowdim-20261113/ios-scene-r1/`，远端作业证据回传核验后已完成资源收尾。

macOS 修订夹具 `visual-r2` 的 5 机位使用真实 USDZ 台呢及生产 geometry lift；仍是隔离场景，白球和部分其他表面为诊断配置。K2/K4/K8 每图最大差均为1码值；实际过滤法线倾角中位约 .84°–1.50°、P95约1.45°–4.14°。提取全部可见 TaiNi 片元，不按 near 条件挑点，共516,599条 Float32 输入，并保留屏幕索引、床面标记、球态和相机。

## R7：真实像素域的更少方向矩

固定 K2/K4/K8 直接内联与冻结字段消费者分别测量。K2 在五机位核心 GPU 成本变化为 −6.83%、−11.84%、+58.20%、−9.56%、−4.68%；台边明显退步，不能视为普遍改进。K4/K8 多数平或更慢。冻结 K4 消费者可明显更快，但不计字段生成，只作为理想上限，不作为候选总成本。

第一版生成矩中的面板面积系数重复，独立 CPU 对拍拦截；修订后通过。失败与修订版本均保留，不用修订结果覆盖原失败。证据：[pixel-lowk-r3/REPORT.md](../../output/render-lowdim-20261113/pixel-lowk-r3/REPORT.md)。

决定：低维路线先保留研究证据，优先排除原遮挡路径的不必要工作，再以更快的正确基线重新评价近似方案。

## R8：只缓存候选球支持域

假设：不缓存光照，只缓存粗格子球候选 mask，再在真实片元上运行原精确支持判断，降低存储和插值风险。

68 配置原生检查全部16输出通道逐位相等，没有漏候选；资源仅2,176或8,320字节。但实际五机位仍无净收益，台边约+55%，其余平或约+6%。增加格子查询没有偿还成本。证据：[support-grid-actual-r1/REPORT.md](../../output/render-lowdim-20261113/support-grid-actual-r1/REPORT.md)。

决定：此版组织不晋级，不因资源很小而宣称有效。

## R9：实际接收高度与保守球 mask

### 根因与候选

生产几何已抬到物理 Y=.8，但片元世界坐标重建存在约数微米 Float32 误差。原 `p.y<.8` 直接把所有活动球加入 mask。真实散台 near 片元7,995个中，7,393个落在该分支；平均每个 near 片元检查14.87球。理想 Y=.8 网格不能暴露这一成本。

这延续10月11日已研究的保守支持域方向，并非首次想到支持域优化。旧`support-full-height`用四个圆锥平面判定整个接收点是否可跳过球影，保留原球mask；本次改为逐球收紧below-bed mask。旧版曾有短测收益，持续手机对照混入温度/顺序因素，既不能据此否决，也不能直接拿旧机毫秒与本次排序。最终应把旧版实际源码放进相同输入/输出合同的对照，再决定是否组合或替代。

候选保持接收坐标、原 near/far 选择、64/8灯采样、遮挡滤波、BRDF与累积顺序，只收紧 below-bed mask。域外、负Y、高球导致界不成立时仍保留旧 all-active 行为。没有新增纹理、生成 pass、CPU 球态缓存或可见画质近似。

第一版直接扩大旧高度公式，在实际像素中逐位一致且更快，但独立审查找到桌外两球反例，单灯样本遮挡可差约.02273；因此该版否决。新界显式计入过滤圆盘的竖向范围，证明及有限域条件见[推导](../../output/render-lowdim-20261113/support-height-audit/PROOF.md)。180万生成状态中，592,557个实际被排除组合检查全部64灯样本，独立双精度几何与 Float32 生产表达式均未发现漏遮挡；随机检查不是任意浮点输入的形式证明。

### 数值、画面与成本

`support-height-safe-r2` 的516,599个真实输入中，12个光照数值通道逐位一致、near选择逐位一致；mask只减不增。Apple M5 Pro、9轮ABBA/BAAB核心计算的配对变化：

| 真实片元夹具 | GPU 核心耗时变化 |
|---|---:|
| 少球低位 | +2.27% |
| 少球近位 | +1.63% |
| 少球台边 | +5.71% |
| 16球球架全台 | −40.61% |
| 16球散台全台 | −65.05% |

这些仅是核心计算，**不是完整场景或 FPS 改善**。少球开销必须继续处理，不能只保留多球有利行。

`visual-height-safe-r3` 的5固定机位和12冻结移动帧全部与R逐像素相同；原参考重复、恢复、11对连续帧差分也相同，覆盖图证明剔球实际执行。此结果仍属macOS真实台呢隔离场景。

### 浮点边界返工与下一轮

原生压力在36配置/49,458点通过后，被负最小subnormal Y的域外mask合同拦下；光照仍相等。最小实验确认即使关闭fast math，GPU浮点比较也可能把负subnormal按零处理，原位模式仍保留。已添加 `as_type<uint>(p.y)` 符号位保守守卫，并补负零/负normal边界；不放宽域外断言，旧失败保留。修订后整轮压力与相同实渲序列继续复验。

并行准备真正的生产 SceneKit 完整场景显式 Metal command 测量：2/16球 × 700×400/1400×800，原生产房间、球、HDR、MSAA4。同一实际计时目标读回、红色控制、恢复和逐像素断言共同排除空画面或替换未生效。GPU批均值不称为屏幕帧时间；CPU编码与同步墙钟分别记录。

修订完成：`support-height-native-stress-r2` 全部39配置、49,661输入通过，包含原subnormal反例、负零、最大负subnormal、最小负normal及极端域外。`visual-height-safe-r4` 重跑17帧全等，证据绑定带符号位守卫的新helper；旧r3不能被当作新源码的证据。

## R10：跳过未消费的 mask，核对诊断本身的成本

假设：原 `shadowPossible=false` 区域完全不消费球mask，可以跳过构造；near区域先用旧支持界短路，再调用新界，避免少球额外算术。保持独立二段构造，不把该改法未经核对套进另一个 `mergedSupport` 实验。

`near-only` 对照只跳过far mask，近区原样；`safe-near-first` 同时采用安全界与谓词前置。后者在五机位诊断核心计时中为−1.96%、−2.70%、+2.68%、−42.49%、−66.31%。少球每轮变化有正有负，和基线波动同量级，不能据此宣称稳定获益。多球九轮均显著变快，但仍是核心测试。

独立审查指出：该核心为验证而输出 `shadowMask`，会使正式着色器far区域不使用的工作在测试中仍保持活跃。因此 `near-only` 的核心时间尤其不能直接推广生产；准备只输出最终漫反射/高光的独立计时入口，同时保留原诊断入口做数值验证，完整SceneKit测量仍为必要证据。

39配置/49,661点新合同复验通过：所有光照与near逐位相同；far诊断mask明确为0、其余15通道仍相同；near域外仍保留原全部16通道。`visual-height-safe-r5` 同17帧图像、重复/恢复及连续差分全部相等。该轮只改变谓词顺序和far跳过，helper未修改；[源码差异审查](../../output/render-lowdim-20261113/visual-height-safe-r5/source-review.json)证明原R surface保持不变。

下一候选只把接收点域判定从每球调用中提出一次，不重排任何浮点支持界表达式；独立审查通过，待相同压力和无诊断计时。不引入按机型、按测试夹具或任意球数阈值的特判。

完整生产场景首轮已入统一队列：`cloth-support-ios-r1-20261113`，快照`13c4af3959523b8c844d93fa53dab7a18279902bff6eef9a739abdce172ccae0`，先固定plain safe-r3-signbit。其结果与后续near-first/hoist分开，不混称同版本。

无诊断入口已完成：[support-lighting-r2/REPORT.md](../../output/render-lowdim-20261113/support-lighting-r2/REPORT.md)。四候选×五机位均先核对旧diagnostic，再核对只输出corrected/S的新六通道，全部逐位相等。plain safe多球仍约−42%/−65%，near-only多数接近零。近位、低位、库边的几个百分点不构成四候选通用排名。hoist与near-first在39组压力输入的全部16通道也逐位相同。

补充fastMath=true独立压力：plain safe与hoist分别39配置/49,661点全部严格通过。每种编译设置内部候选与其参考等价；不同设置间原参考在精确边界也可能变化，不声称跨编译选项逐位相同。

## R11：完整场景宿主阻塞与修复

首轮iOS工程构建通过，但首个 `render(8)` 预热阻塞，没有得到任何候选性能数据。线程采样确认等待于SceneKit `beginFrame` semaphore：旧测试把多次SCNRenderer render装进未提交的同一个command buffer。裸compute的批量组织不能直接套给有内部在途帧资源的SceneKit。见[FL-260](../FAILURE-LOG.md#fl-260--scenekit-完整场景计时宿主延迟提交导致等待2026-11-13)。

只中断核实身份的本作业xcodebuild；原快照、栈、日志及失败结果已回传并哈希验证，远端本作业临时设备、源码与构建已按生命周期关闭回收，失败没有改记为通过。原件在 `output/render-lowdim-20261113/ios-support-scene-r1-failed/`。

宿主r4改为**每帧独立command立即commit/wait**，每帧前用独立sentinel清理防旧图复用。六帧批次保存全部原始GPU起止/耗时、CPU编码/提交等待；清理时间排除在这些值外，包含测试记账的总墙钟另列。实际相机HDR/曝光/SSAO值也进入metadata。原plain-safe候选及严格画面断言不变。

先用最小macOS真实SCNRenderer/MSAA4/HDR做32连续帧+4红控+4恢复，共40帧全部完成、GPU时间为正、恢复图逐位相同，避免未验证宿主再次长时间占队列。该烟测只验提交组织。随后以新冻结快照在Mac mini和本地空闲large-pad核心角色运行同四配置；本地其他已启动/人工保留设备不动。

新快照`a88cbd21931ba2bbd83823e9fbd3c8a2fc9d3724ae4ddbdaffd6c9e4918de5ea`。本地run `883803f517cf4d2fb06fd41a5f7a87e4` 已实际1/1通过、0跳过，四配置RGBA逐像素相同，红控/恢复成功；前后源码一致，工作目录自动回收、large-pad租约已释放。实际原图已查看。

但是本轮不能拿Simulator的GPU字段做排名：像素数4倍而报告GPU span约.15–.24ms几乎不变，allocatedSize全为0；9轮GPU变化符号分散，和漂移同量级。Apple官方也明确限制Simulator性能测量。完整场景正确性通过与GPU计量可用性分开结论，不因为XCTest通过就宣布性能通过。

同步render调用及指定CB等待的墙钟（不含clear/readback）在2球两分辨率约+1.8%，16球约−31%/−38%、各9/9轮降低。这是该模拟宿主的流程成本观察；未证明SceneKit/Simulator内部全部GPU工作均被该区间覆盖，不称纯GPU收益或App FPS。raw及边界见[本地汇总](../../output/render-lowdim-20261113/ios-scene-local-r4/summary.json)。下一轮转原生macOS真实台呢SceneKit场景与旧候选同条件对照，避免扩大不可靠计时。

远端 r2 同快照在 iPhone 17 Pro / iOS 26.2 实际 1/1 通过、0 跳过，四配置 RGBA 最大差为0，36次/配置末目标校验、红控及恢复通过。原图已查看；[回传原件](../../output/render-lowdim-20261113/ios-support-scene-r2/evidence/test-details.json)与哈希收据保存，远端队列完成回收。导出附件使用 xcresult 副本，不改回传原件。两套 Simulator 的计时均不参与算法排名。

## R12：原生 GPU 跨机器与像素规模

将真实 USDZ 台呢、完整几何抬升、原纹理/法线/AO、HDR、MSAA4 和 plain safe-r3 冻结成同一个可移植包，先用 512×512 原生片元负载32/1024循环校准 GPU timestamp，再测两球近景/16球散台 × 700×400、1400×800、2800×1600。每次render独立提交完成，同一末目标读回；每配置9组ABBA/BAAB、每批6帧，CPU编码/同步墙钟/GPU跨度分列。包 ID `1236812d79b82ea62381bdc00b0d33a047738f030e7c94accd6d81793638d981`。

| 场景、目标尺寸 | M5 Pro配对GPU变化 | M4配对GPU变化 |
|---|---:|---:|
| 两球近景700×400 | +1.48% | +0.77% |
| 两球近景1400×800 | +1.30% | +1.42% |
| 两球近景2800×1600 | +1.28% | +0.63% |
| 16球散台700×400 | −42.44% | −31.84% |
| 16球散台1400×800 | −40.74% | −41.00% |
| 16球散台2800×1600 | −42.11% | −43.32% |

两机每配置的原版/重复/候选/恢复全部逐位一致，红控生效；各自216次测量末目标核对通过。校准重/轻比为26.08×、27.05×，原场景耗时随像素增长，实际 target allocatedSize 可用。三尺寸显式目标含MSAA/depth/readback分别约13.24、50.77、201.65 MB；这些是宿主共用目标，不是候选新增资源，候选没有新增纹理/缓冲。

多球收益在两种实体GPU与三档像素数中重现；两球约1%的开销保留，未宣称所有场景更快。原始结果、配对范围及漂移见[双机对照](../../output/render-lowdim-20261113/native-scene-cross-host-r1/comparison.json)。M4为Mac16,10/10核GPU/16GB/macOS26.2，M5 Pro为macOS27.2，各自在机器内比较，不按绝对时间跨机排名。

范围严格限定：这是真实台呢的原生 SceneKit 隔离场景，其他导入材质与白色诊断球保留，没有完整生产球房/球反射/SwiftUI调度；也没有实际呈现与持续温升。新7:4画幅不同于旧3:2实际像素抽样，不套用旧51.6万输入的操作次数。下一轮验证历史cone与新mask能否组合、减少少球代价；同时补DEBUG实际页面和最低Runtime接线。

## R13：旧圆锥支持域与新逐球界组合

重新提取历史真实生成器：旧方法判断某接收点是否可能被任一灯下的球遮挡；新方法收紧逐球mask。两者作用层级不同，因此组合有机会在多球保持收益，同时消除少球新增算术。保持原64/8采样、全局E/E0修正、高光和球的相乘次序，不包含BRDF factoring或mergedSupport。

直接组合在真实输入中相同，但独立域外GPU压力找到负极端接收坐标反例。第一版有限域回退又因另开完整reference分支导致fastMath下末位差异，均否决并保留失败。修订保持一条原transport/BRDF路径：仅在经过核对的接收点/球域内应用组合，域外恢复原mask并强制保留shadow路径。40配置、49,664点在fastMath开/关分别通过；其中26个标签是13份重复数据，不冒充独立随机样本。

候选准确身份为 `legacy-cone-plus-safe-hoisted-finite-domain-guard`，完整surface SHA `ca5acc70043f0da620e2c6501188063c78027c8e26b62233d128ced01f81aabd`。5固定机位+12移动帧、重复/恢复及11对相邻帧差分全部逐像素一致，覆盖图确认实际跳过遮挡工作。见[公式、失败与画质报告](../../output/render-lowdim-20261113/support-legacy-comparison-r1/REPORT.md)。有限压力与图像通过不等于任意浮点输入的形式证明。

完整材质三臂使用新冻结包 `d053ea94206c08ef95cb13f557cf3417157d66af8cdff74472b25171e2ea4b3f`。R/P/C三组直接pair轮换，每pair九轮ABBA/BAAB；每臂每pair108个独立同步帧，保存真实逐帧P50/P95/P99、CPU编码/同步墙钟与显式资源。M5 Pro先完成3888测量帧、648次测量末目标校验，全图BGRA相同：

| 场景 | 组合相对R | 组合相对plain safe |
|---|---:|---:|
| 两球近景700×400 | −4.87% | −5.35% |
| 两球近景1400×800 | −4.50% | −7.39% |
| 两球近景2800×1600 | −4.53% | −6.62% |
| 16球散台700×400 | −44.71% | −4.89% |
| 16球散台1400×800 | −43.49% | −5.57% |
| 16球散台2800×1600 | −46.13% | −7.34% |

C/P直接比较54组全部更快；R/P两球700有一组100.24%端点漂移，完整保留，不删除异常或拿约1%变化抢排名。C/P最坏端点漂移14.04%，跨硬件复验仍必要。[逐帧分位、原始时序与限制](../../output/render-lowdim-20261113/native-scene-guardcombo-m5pro-r1/REPORT.md)。本轮仍是离屏真实台呢材质，尚不是完整App收益；M4三臂待当前页面测试释放GPU后执行，不能将旧plain双机证据借给新组合。

M4同包复验完成：C/P在两球700/1400/2800分别−4.26%/−4.59%/−5.72%，散台分别−5.52%/−2.78%/−6.63%；相对R两球约−3.67%至−4.67%，散台−34.05%/−42.52%/−46.25%。两机合计7,776测量帧、1,296测量末目标检查全部严格通过。M4低分辨率有反向轮次，最大端点漂移24.22%；两机2800宽C/P每轮均更快。不能把中位节省外推为所有尾分位改善，个别GPU/render-wall P99变差也保留。[跨机原始分布](../../output/render-lowdim-20261113/native-scene-guardcombo-cross-host-r1/REPORT.md)。

因此组合列为当前优先候选，正在增加独立DEBUG开关保留plain可复现。没有改变正式R默认。页面候选、缓存身份、冲突回退和快照单独记录，不能拿plain的旧页面证据当作guard通过。

## R14：实际页面接入与安装成本

plain接入r5快照`b1affea5...`完整工程构建通过；实际30项为27通过、3失败、0跳过。新实验10项逻辑全部通过，实际击球及balanced回退通过；生产完整场景四配置仍逐像素一致。失败为根页深链没有导航祖先、既有诊断用例与当前frame receipt合同不符、旧桌复用截图写仓库路径被沙盒拒绝。三项均保留原失败，按实际合同修测试，不改产品导航、必要回调或画面容差，见[FL-261](../FAILURE-LOG.md#fl-261--根页深链不能验返回上级2026-11-13)。

实际原图已检查：原3D、临时俯视及plain真实击球后静止均有完整桌/球/球房与控件，没有红控残留或空目标；失败矩阵只走了首个reference风格，不能据此认定三风格全部通过。原件完整回传，导出使用clone，临时设备和队列工作目录已关闭回收。

纯CPU实际Swift字符串构造：M5 Pro暖态单次中位原R0.094ms、DEBUG off0.114ms、plain4.315ms；九轮配对新增约4.156ms，576次输出均核对。发生在每次材质安装/容量刷新边界，不逐帧执行，也不代表完整启动或GPU编译成本。完整surface源码从21,205增至22,650 UTF-8字节，不是GPU内存增量。[构造报告](../../output/render-lowdim-20261113/support-program-cpu-r2/REPORT.md)。新guard接入须另测，不能继承此毫秒值。

下一冻结版同时验证reference/plain/guard真实首页进入返回、三房间风格、2D/3D/临时层、后台恢复、实际击球、缓存/容量回退与最低iOS17。详细状态见[页面检查表](PAGE-CHECKLIST.md)。

guard已作为独立DEBUG开关接入，CPU完整surface与已验黄金逐字一致；864次源码生成输出全部核对，单次构造中位约5.064ms（相对R配对新增4.973ms），只在安装边界。新r6快照`b7e367d1...`共4455输入，38方法已提交远端队列；随后SSH网络中断，原作业实际状态待核，不能认定未跑或盲目重投。继续用本地空闲受管large-pad验证同一不可变源码，其余已启动/保留设备不动。最低Runtime及远端收尾状态单列，不由网络失败推断产品失败。

## R15：本地页面复验、测试谓词修正与证据收口

用户确认Mac mini暂不方便，本轮不再尝试连接；原远端作业保留，最低iOS17与远端临时资源收尾待恢复。本地large-pad/iOS26.3.1完整构建通过，r6实际38项为37通过、1失败、0跳过；[原汇总](../../output/render-lowdim-20261113/page-local-r6-analysis/test-summary.json)与封存xcresult分开保留，导出只使用APFS clone。

5项页面用例全部通过：三种房间风格×原版/plain/guard，正式2D/3D、临时俯视、后台恢复、真实首页进入/返回；两候选各自的方向尺与真实击球；balanced及双flag冲突回退。方向用例证明没有误击、结束后可休眠，未断言精确杆向增益。页面图不作为性能排名或逐像素等价证据。

guard实际安装程序放入完整R球房的4配置均通过。独立复核20张PNG、12组RGBA对照全部max=0，红控改变像素数与报告一致；两轮交错的32个测量末目标检查通过。程序SHA等于跨硬件黄金，实际场景包括房间、真实球材质、台呢法线/几何修正。[原图及封存完整性复核](../../output/render-lowdim-20261113/page-local-r6-guard-review-r1/review.json)；1597个原证据文件逐项SHA未变。该对照保留R房间/probe，guard专属probe与cache另由单测/UI覆盖。

唯一失败为新缓存测试将guard注释中的plain函数名误判为函数存在，恰好对应五序列中三次后臂guard，见[FL-262](../FAILURE-LOG.md#fl-262--shader注释命中不能证明安装了另一配方2026-11-13)。只把测试改为确切定义锚点及独立完整surface SHA，节点复用、释放、并发隔离与probe断言全部保留；生产源码不改。CPU重现三次旧误报，新五序列谓词通过，r7快照`ade5961f...`完整构建后真实缓存方法1/1通过、0跳过（8.908秒），[结果](../../output/local-test-runs/247fbbe3fb1f4a2797b9c2acee7c5511/evidence/test-summary.json)。当前38个目标方法均有通过证据，r6原汇总仍保持37/1/0。

成本曲线由同一R/guard直接配对的2592帧重算，24个P50与原汇总逐值一致，已加入[结果入口](RESULT.md)。完整Release App构建预飞缺发布配置，未执行必败构建、未填假值或绕过门禁；它不影响已经取得的原生Mac材质性能证据，但不能记成Release构建通过。

三风格页面36图与击球/回退9图共45图已实际审查，配套状态一致，未见候选独有缺球、洋红、空白或错层；检查方式和每张原图见页面检查表。r6/r7本地工作目录均已按生命周期回收，证据保留；核心iPad保留，未操作其他在用/人工保留设备。远端作业回传、最低系统、发布配置及完整移动端性能边界保留，正式R未变。


## R16：原生 iPad App 的完整场景与页面验证（完整场景通过；整页采集暂停待续）

独立[完成度审计](../../output/render-lowdim-20261113/goal-completion-audit-r1/AUDIT.md)确认，已有数据不足以宣称整页净收益；页面功能矩阵与完整P3并非一回事。17帧是离散位置画质，当前仍缺连续球/相机运动、多视图活动、冷路径和20次进退资源趋势。保留这些目标，不把它们缩为指定手机的验收。

本机`xcodebuild -showdestinations`实际列出兼容的My Mac / Designed for [iPad,iPhone]。初查现有5份开发签名档均未包含本机；用户随后明确允许通过Xcode登记本机并更新开发签名档。只读[可行性报告](../../output/render-lowdim-20261113/ios-on-mac-feasibility-r1/REPORT.md)保留更新前状态。使用冻结r7完整App，通过受管入口执行正常自动签名的原生构建/测试；不改Catalyst、不绕过签名、不连接手机或Mac mini。运行ID `b25795f6ddcc49b79cb52d2b21163bb9`：首次构建因UI runner所引用的开发签名档文件缺失而失败；后查主App和通配新签名档已包含本Mac。该计划引用失效文件已取证，不能据此断言Apple内部竞态根因；没有生成旧UUID假文件或关闭签名。失败日志/计划保留，工作目录已按生命周期回收；未来以当前签名档生成新构建计划。详见[签名诊断](../../output/render-lowdim-20261113/native-signing-profile-diagnosis-r1/diagnosis.json)。

先以既有完整生产场景图像方法验证原生宿主，再为GPU校准/9组配对与实际页面分阶段trace新增独立选择器。结果须分别标为原生iOS-on-Mac完整SceneKit场景和完整页面，不能混用隔离材质、Simulator或手机结论。纯SCNScene归档重放是备用路线，因直接原生入口正在推进而暂停，尚未实现或取证。

用户随后要求安装到手机试用。已重新发现并核实当前iPhone16Pro通过局域网连接，授权只用于安装/手动体验，不在此时跑性能或温升测试。使用已验证r7完整App源码构建Debug -O（主App build，无UI测试runner）；新run `c45e6ee61c5d4f298cdbb0fa4f546b89`实际BUILD SUCCEEDED且完整codesign验证通过，devicectl安装/启动均已成功，启动PID43469读回仍在，截图确认训练首页；输入hash一致且工作目录自动回收。见[手机试用交付](../../output/render-lowdim-20261113/phone-preview-r7/SUMMARY.md)。本次仅以`-daily3D.guardClothSupport`启动，不加fixture、reset、虚拟会员或帧率覆盖；保留现有用户数据/偏好。开关仅当前进程生效，强退后从图标重启恢复R。


R16续：r8快照`355efdd5...`仅新增原生测量测试/启动器，App生产输入与r7一致。新计划使用现有有效开发签名档、Debug -O；run `f4e78df318df49069f0991ce4ca734af`越过前轮签名故障，但编译旧unit测试时暴露仅模拟器工具的漏guard（FL-263），未运行GPU。原失败与r8冻结输入保留，工作目录已回收。

已限定修复4个内容制作测试的方法平台边界，模拟器原body/全部断言逐字不变；非适用平台显式skip，不能把这些skip冒充性能目标通过。另收紧新native报告完成位：XCTest已有非throw失败时不可标completed；报告消费者仍须核对应xcresult精确selector真实Passed且0failure/skip。r9快照`82f6dc2d0cfad3480a8ef7c88c9068d328fb7d169ffc0d07d5ae8bcfd36702ff`（4458输入）正在受管run `599cb6efc8f14aca9cc9f04092ad44a7`构建；本条未声称运行成功。[平台修正复核](../../output/render-lowdim-20261113/fl263-test-platform-review-r1/review.json)。


R16本机原生完整场景结果：r9受管run `599cb6efc8f14aca9cc9f04092ad44a7`完整build及精确native selector 1/1通过、0跳过（12.521秒），FL-263原生构建返工闭合。Apple M5Pro原生校准比26.149、864测量帧、144同末目标检查、20张PNG独立复核通过；16球700/1400配对中位−44.15%/−49.99%，两档均9/9更快。两球+0.57%/−2.14%处于小变化/明显漂移范围，不认定可靠收益。真实房间/球材质/R probe都在，仍排除SwiftUI、活动更新与present；[完整报告](../../output/render-lowdim-20261113/native-production-r9-analysis/REPORT.md)。签名build明确hold供下一步页面采集，手机仍留给用户试用。


R16暂停收尾：原生UI整页schema smoke `aab7c302ec2149a9ae569debe7e9738d` 被Xcode在执行前明确拒绝，Designed for iPad目标不支持UI测试。0 tests/0 markers、recorder未启动，未产生性能证据。原失败保留，该轮work已受管回收；r9签名产品明确hold待续。直接用CUA打开原始Debug-iphoneos App又被LaunchServices以不兼容可执行格式拒绝，不能据此推断已通过的原生unit宿主无效。用户已将goal设为paused，停止进一步调查/采集；完整断点与恢复前提见[结果入口](RESULT.md#2026-11-13-暂停断点)。


## R17：恢复整页采集，原生安装包装与真实页面（进行中）

恢复后确认r9签名build仍完整hold。原生UI XCTest的0项平台拒绝按FL-264记录。只读定位Xcode实际生成的 `.XCInstall/%E7%90%83%E8%BF%B9.app` 外壳：内层2689文件与r9原始App逐字一致；原始iOS `.app` 的LaunchServices失败不代表包装入口失败。[入口调查](../../output/render-lowdim-20261113/native-launch-resume-r1/REPORT.md)。

主控通过CUA成功启动outer，并按实际系统转址选择inner窗口，见到了真实首次引导及训练首页。未填写可选个人资料，跳过后从首页进入每日清台并切到3D；原生图确认16球开球准备的球房/桌面/控件可见。当前PID2918，实际translocated executable SHA `72292637d98539c85696f70e3563f2409e996c8e18fb5677a9db759e83d8a0ec` 与r9匹配；没有fixture/reset/虚拟会员/诊断参数，未击球。引导和3D显示选择沿正常UI写入本机测试App；不宣称全部操作无持久副作用。

先对当前R页面做仅相机活动的短录制，验证真实App GPU/CPU采集能力。无diagnostics启动的本轮不要求凭空出现daily3D阶段标记，也不能据此给整页候选收益或FPS。正式配对前仍须核UserDefaults/Keychain与fixture写入边界、确定重放盘面和真实诊断关联。

R17首轮实际采集 `9625f2e275fd43e98ed17714bde21ab2`：20秒Game Performance＋Activity Monitor已按时结束录制，但r1将录制和封存共用120秒上限，追加SIGINT/60秒等待后仍未退出，结果保持failed，见FL-265。录制器随后结束，正常退出码未知；最终trace约661MiB，但独立约12GiB临时ktrace仍残留，不能把最终trace变小理解为临时文件已回收，也不能把文件存在当正常完成。离线恢复另用受管run `79463ce95df94c9190c7ff2c8a5e3001` clone，原失败及原件不改。

恢复TOC可读，实际窗口08:35:43.394–08:36:08.407（Asia/Shanghai，25.013190秒）；六次CUA镜头切换始于08:36:09.957，全部在窗口结束之后，本轮采到这些操作的数量为0。保留[实际UI时间记录](../../output/render-lowdim-20261113/native-direct-smoke-r1-ui/actions.json)，不以界面动作成功冒充活动采集通过。无diagnostics参数，缺App阶段signposts不是候选问题。r2准备接收真实开始通知、区分封存等待、将可变trace先放work、确认正常退出及稳定后再进入证据；未运行前不记通过。

### R17-r2：真实开始通知与保存阶段磁盘耗尽

r2启动器冻结SHA `e521aa5407c053a3b0b54e63b71455cb26593b9048491e7c0e6c7595bd1c1e43`，受管run `cf10c0216571482dae4500991aeea227`。本轮使用环境白名单，记录/export与上轮含继承环境的私有原件分开；App仍为PID2918的原R，无diagnostics参数，未击球。

实际收到Darwin recording-start通知，wall=`1794530976.629557`；随后六次真实CUA相机切换位于`1794530988117–1794530992127`毫秒（通知后约11.49–15.50秒），每次AX选中状态均为true，前后杆数均0。[完整动作记录](../../output/render-lowdim-20261113/native-direct-smoke-r2-ui/actions.json)保留。这证明真实操作在通知之后发生，**尚不能代替TOC/time-info证明采集覆盖，也不代表多球运动**。

recorder8107日志报告达到20秒上限并进入保存，随后抛出 `Could not trim file: No space left on device`。owner8100与recorder8107均已退出；收尾写盘失败使原run.json仍残留`state=running`，并非仍有正常录制任务。没有summary、TOC或核心表，不计性能、不报FPS，也不将r1恢复数据移作r2结果。

### 存储恢复与保留边界

只核查两次录制的临时文件，没有全盘清理。r1的`instrumentsKmeglh.ktrace`无打开句柄、旧recorder已亡，创建时间距r1真实结束仅1.529ms；元数据和限定时段统一日志没有直接文件名映射，因此归属保留为强时间关联。主控在核SHA、inode、路径和无句柄后只删除这一个中间文件；最终trace、原失败日志、恢复副本与12张导出表保留。[回收收据](../../output/render-lowdim-20261113/native-trace-storage-recovery-r1/retired-r1-ktrace.json)记录12,930,478,080 allocated bytes、删除前后实际可用空间和文件SHA；未改旧seal或虚报原录制通过。

r2的`instrumentsJB9rLS.ktrace`最初由DTServiceHub8121以fd3u打开，其cwd直接指向r2/work，归属已证，未按无主文件删除。主控确认owner8100/recorder8107已亡后，将它同卷rename到该run的`work/failed-recorder.ktrace`，只对已归属的服务8121发送TERM；服务已退出且无句柄，12,916,584,376 bytes原件完整SHA保留，约41MiB partial trace也保留。run已protect hold，未修订陈旧running字段来冒充正常完成，未删除或压缩r2失败原件。[服务恢复收据](../../output/render-lowdim-20261113/native-trace-storage-recovery-r1/r2-service-recovery.json)。原生App2918另已通过正常UI退出并核实进程消失。原私有trace/TOC仍受权限保护，分享报告不含环境名值。

此时下一步为轻CPU模板的录制/封存/导出、任务私有TMPDIR与空间门禁，以及显式signpost配置和受支持的带参数启动；后续实际执行如下，原r2失败不回写成成功。[存储恢复详情](../../output/render-lowdim-20261113/native-trace-storage-recovery-r1/REPORT.md)。

### R17后续：状态保护失败，正常系统启动与轻CPU链路跑通

保护run `5f460463924f402bb2367732db2eec99`在Data根首次`open`即EPERM（errno1），没有到子目录/xattr/hash/cp；未产生完整备份、未恢复用户数据。精确defaults导出虽然exit0，却只返回0-key空字典，物理文件不可读因而无法验证，不能用作回退。保留原失败，不改权限/绕保护、不自动排除文件。主控结束保护探索，改沿正常用户每日开球准备盘面，不加reset/fixture/premium/合成身份；未来可重复fixture的状态保护明确待办。[诊断与边界](../../output/render-lowdim-20261113/native-page-state-isolation-r1/SCRIPT-REVIEW.md)。

带诊断参数的`xctrace --launch`运行`bd0c920cfda447648cdd4e39f0075c60` recorder exit54。签名无效的崩溃报告属于PID14506；实际translocated PID14503仍在但未推进正常启动，样本停在dyld，不能说它就是14506的崩溃，也不能称业务渲染死锁。主控精确TERM14503并核消失，保留失败。随后改由系统`open -a <已验证outer wrapper> --args`启动；实际PID16480 argv包含`-daily3D.diagnostics -3dDrag.probe -renderProfileProbe -dailyLayout.probe`，CUA真实首页与每日3D可交互。新启动成功不覆盖旧launch失败。[两个PID的独立审计](../../output/render-lowdim-20261113/native-launch-diagnostics-smoke-r1-analysis/REPORT.md)。

独立attach r3：run `41536a261eb445ccac77fd803ce0d6ec`，Time Profiler＋Activity Monitor＋os_signpost、20秒/30秒窗口。实际通知已收、recorder exit0、进程身份前后一致、trace稳定封存、TOC及核心导出完成；4张非空表，另4项空/失败，GPU与time-info schema不在该轻模板输出。由此只证明原生真实App的轻CPU采集链路，不能输出GPU成本或显示FPS。[采集原汇总](../../output/local-test-runs/41536a261eb445ccac77fd803ce0d6ec/evidence/summary.json)。

六次CUA相机动作的实际覆盖为1完整、1部分、4窗外，不能称整段操作采集完成。独立样本审查有1,541个1ms running样本；`updatePocketAccessibility` inclusive为1,111（72.096%），`dragProbeValue`76（4.932%），存在栈重叠，禁止相加或当self time。源码路径为renderUpdate尾部在dragProbe开关下重建可访问性，renderProfileProbe再遍历hierarchy/材质、做shader字符串检查。这个额外探针负担足以使本轮不能用于生产CPU净收益，不能据此认定生产瓶颈已转移。

signpost表去重后9事件、0完整interval，其中8事件在TOC内；Activity末累计采样早于实际输入，故CPU累计量/footprint仅能描述活动前边界，不能当整段相机活动平均。真实UI收据见[六次动作](../../output/render-lowdim-20261113/native-direct-smoke-r3-ui/actions.json)；[独立白名单报告](../../output/render-lowdim-20261113/native-direct-smoke-r3-analysis/REPORT.md)与[复算数据](../../output/render-lowdim-20261113/native-direct-smoke-r3-analysis/analysis.json)已冻结。这一轮选择是移除额外探针后重新取同等动作对照，而不是从污染数据直接宣布guard收益。

## R18：首对正常页面CPU采集分析完成，不作排名

移除`3dDrag.probe`、`renderProfileProbe`、`dailyLayout.probe`，新R进程仅保留`daily3D.diagnostics`；guard另加候选flag。正常原存档为中八manualRacked、16球、0杆，未fixture/reset/premium/改身份。实际二进制/原盘面和2048×1600窗口一致；configuration确认R/off与guard生效无fallback，均capacity16、MSAA4、contentScale2。配置事件在idle后，selectedFPS60/scheduledFPS30不能证明活动呈现60FPS。本阶段没有重新开启失败的保护或变更App源码。

首R run `5de45c13328e4806b0402ead0ff217b3`，PID18031；guard run `6f4cb8edda3b4a3480ba7b35b2f2edde`，PID18875。两臂各60秒录制、70秒滚动窗口，实际各完成24次相机选择（`firstPerson/global/thirdPerson/global/firstPerson/thirdPerson`×4），次序完全一致，每次记录AX选中、杆数0和外部时间。[reference-actions.json](../../output/render-lowdim-20261113/native-page-cpu-pair-r1/reference-actions.json)与[guard-actions.json](../../output/render-lowdim-20261113/native-page-cpu-pair-r1/guard-actions.json)只描述UI操作，不把派发到读回间隔称render time。两个原汇总均complete、recorder exit0、前后进程身份一致、traceSealed、TOC和导出完成。冻结分析确认每臂24次均完整落窗，但每臂目标signpost仅45事件，input/firstRender/wake仅sequence11–24，缺1–10与orbit Begin，完整stage均0。其它signpost已覆盖前段，缺口原因未明，不补造事件，不把CUA覆盖替代App阶段合同。[分析报告](../../output/render-lowdim-20261113/native-page-cpu-pair-r1/analysis/REPORT.md)及[带输入SHA的结果](../../output/render-lowdim-20261113/native-page-cpu-pair-r1/analysis/analysis.json)。

保留两种描述性ROI：①CUA首动作至orbit End，CPU计数包围区间R3611.846ms/guard3663.794ms（+1.44%），Running样本3344/3595ms（+7.51%）；②共同可见input11至orbit End尾段，CPU计数2176.440/2141.298ms（−1.61%），样本1899/2143ms（+12.85%）。前者ROI长12.047977/12.156905秒，计数包围区间各多含约1.1秒且边缘构成不同；后者也非完整stage。计数和抽样不同方向、单次顺序R→guard无反向重复，不能排名。`rankingAllowed=false`、`exact24InputROIValidated=false`、`completeStageComparisonAllowed=false`、`gpuTimingAvailable=false`。

额外probe不再主导，但每次CUA读回整树AX仍进入CPU：递归属性读取inclusive样本R1137/guard1112ms，占粗ROI样本约34.0%/30.9%，相关AX栈有重叠不能相加。该轮不是人类操作下的生产净CPU，也不能将SceneKit/Metal命名CPU栈当GPU耗时。整个App离散footprint约1.18GiB，约1.45MiB差不归因为候选独占内存或确切峰值。未得到稳定CPU优势不等于shader GPU优化失败；下一步独立核GPU能力并减少动作中AX查询。

本条是执行进展，**不是最终结论**：没有完成ABBA，没有完整页CPU/GPU净收益，没有呈现FPS或连续多球动态/长期内存生命周期结论。既有固定场景GPU结果保持原范围。

## R19：减少AX查询，完整活动与系统GPU汇总已核

首guard run `5d64f8b942ef464ab7b57da459e2e7dd`，PID18875，Metal System Trace＋os_signpost、60秒录制/70秒滚动窗口。四项CPU选项显式false，但模板自带CPU采样，不能称纯GPU；入口20GiB空间门槛只用于准入，不宣称约束全局XPC临时峰值。仍沿正常用户盘面与process flags，没有fixture/reset/会员或身份改写。

在已观察的按钮位置执行固定24次点击，每次hold400ms，中途不做整树AX读取，最后仅一次AX核状态。逐项收据为`clickReturned`，不等于每项已选中；`perActionSelectedStateVerified=false`，最终读回thirdPerson、3D、0杆。[实际动作](../../output/render-lowdim-20261113/native-gpu-capability-r1-ui/actions.json)明确要求每个输入仍由App signpost交叉核验，显示的60FPS文字也不是present实测。

录制已完成并保存，[summary](../../output/local-test-runs/5d64f8b942ef464ab7b57da459e2e7dd/evidence/summary.json)中recorder exit0、sameProcessBeforeAfter、traceSealed与TOC为true；9张非空、2项空/失败。冻结分析核目标PID共78条Daily3D事件，input/firstRender/wake各24、sequence25–48，完整orbit为11.860244125–23.488032708秒，长**11.627788583秒**。活动scheduledFPS60、结束后30，guard有效无fallback；这不把点击返回或配置FPS当作呈现证明。[原始分析](../../output/render-lowdim-20261113/native-gpu-capability-r1-analysis/REPORT.md)。

标准GPU/CB/frame-assignment表目标PID均0行，其他PID/driver区间不补入。系统FramePacing却有真实单层非零指标：Shared Image Queue ID505924121392，61组（10非零、51零），重复视图和相同Begin/End字段各只计一次；[analysis.json](../../output/render-lowdim-20261113/native-gpu-capability-r1-analysis/analysis.json)保留全组计数/均值/min/max/stddev。可比较同条件系统reported指标，但该ID不是MTLCommandQueue，空层名也不能证明涵盖所有页面合成；不能从汇总造逐CB区间、P95或精确FPS，发布组边界未等同于底层帧ROI。本轮仅guard，不能排名。

只读[语义审查](../../output/render-lowdim-20261113/native-gpu-metric-semantics-r1/REPORT.md)确认公开SDK无`SCNSceneRenderer.currentCommandBuffer`，取消该接线假设，不用KVC/swizzle或替换渲染器。安装Instruments已有启动时逐帧指标选项；当前仍保留本轮默认聚合事实，不写成逐帧已取得。层尺寸结构化单位为pixels（2660×1996），原叙述points矛盾保留，不额外乘scale。

### r2失败证据后续无损压缩

在保留原失败/hold、partial trace和日志的前提下，r2 raw **12,916,584,376B**压为gz **1,637,281,564B**。流式解压长度及SHA与原raw一致，相关保留证据前后hash一致后才删除冗余raw；可从gz恢复，未把旧失败改成成功。完成时df可用约32GiB。[压缩/验证/恢复收据](../../output/render-lowdim-20261113/native-failed-r2-lossless-compression-r1/recovery-receipt.json)。这更新此前“当时未压缩”的存储状态，原返工记录仍保留。

## R20：R参考臂完成，实际节奏与预热差异阻止排名

run `eb7a99936a4844ea8e1bb9e24444b16f`、PID25915，采用同方法60秒采集；recorder exit0、trace正常封存。24次预观察点击中间无整树AX查询，末尾读回thirdPerson、3D、0杆；[动作收据](../../output/render-lowdim-20261113/native-gpu-reference-r1-ui/actions.json)与真实App事件核到24 input sequence1–24、24 firstRender/wake，配置off/R/reference、capacity16、MSAA4、scale2。[冻结报告](../../output/render-lowdim-20261113/native-gpu-reference-r1-analysis/REPORT.md)及[完整分析](../../output/render-lowdim-20261113/native-gpu-reference-r1-analysis/analysis.json)。

实际第4/16/23点击wall包络为1005/1035/1020ms，产生4段完整orbit合计11.922213707秒、中间3段idle合计1.314707083秒，整体包络13.236936333秒；guard为1段连续orbit11.627788583秒。因此相同计划脚本没有生成完全相同的活动/idle分布，不能直接配成统一ROI。

系统Frames计数加权的reported OnGPU均值R5.304352728ms（14非零组/708帧）、guard5.048226891ms（10组/559帧），guard相对R为−4.828597396%。这是原系统汇总的描述性复算；OnGlass另按Intervals加权，不混分母、不删零组、不反推P95/FPS。另有预热差异：guard PID18875此前已完成R18的24动作，R PID25915为新进程首24动作，`matchedWarmupHistory=false`。主控独立复算均值相符，仍`rankingAllowed=false`。[comparison.json](../../output/render-lowdim-20261113/native-gpu-reference-r1-analysis/comparison.json)。两臂单层尺寸同为2660×1996，标准GPU/CB目标行仍0；不能推出整页所有合成、台呢独占或逐CB硬件成本。

本run已在验证owner/recorder退出、精确服务归属和无句柄后清理冗余work缓冲；664份sealed evidence hash前后不变，App未触碰，收据最终df约31.30GiB。[回收收据](../../output/render-lowdim-20261113/native-gpu-reference-r1-cleanup/receipt.json)。

## R21：一致预热的官方逐drawable首对已分析

两臂同一r9 App，新进程各完成24动作预热及24测量动作，轻Time Profiler＋Activity Monitor＋os_signpost模板下官方逐帧选项实际生效。目标`OnGlassDrawableInterval`端点配对R426/guard566，字段无不匹配、无未配对端点，重复视图去重。严格落在实际orbit内的样本R415/guard564，reported OnGPU均值**4.573736/4.326376ms**；OnGlass均值**16.663978/16.668444ms**，没有明显节奏改善，不换算FPS。[冻结报告](../../output/render-lowdim-20261113/native-page-perframe-r1/analysis/REPORT.md)、[原值与统计](../../output/render-lowdim-20261113/native-page-perframe-r1/analysis/pair-analysis.json)。

严格显示时长仅覆盖活动的**R62.23%/guard81.82%**；R为两段orbit并多一次idle/wake，guard为一段，样本与镜头时间构成不同。t=0及跨边界carrier、Drawable ID跳变原样保留，不解释成真实卡顿或漏帧，也不把严格筛选当全活动覆盖。CPU计数包围区间2303.607/2436.732ms未见下降，但边缘时间不同，独立列示。全部仅作描述，`rankingAllowed=false`，不声称完整页净收益。[覆盖补充](../../output/render-lowdim-20261113/native-page-perframe-r1/analysis/coverage-amendment.json)。本轮结束采集扩建与追查，下一步直接验证真实rack与scatter的同场景成本。

## R22：1400×800真实rack固定场景通过

仅在原生矩阵追加16球rack overview，保留真实RackLayout、完整生产球房、原画质控制与9轮配对；默认5项/可选7项的consumer合同与语法检查通过。冻结[r10快照](../../output/render-lowdim-20261113/ios-snapshot-r10/manifest.json)`8f202f4d…`、run `e9a1154d959e461da08e6ecee1d40359`真实构建测试完成，精确selector **1/1 Passed、0 skip**。主控运行严格analyzer通过：5场景1080计时帧、180次harness同末目标检查，25PNG独立解码，各场景三组RGBA精确一致且红控有效，GPU重/轻校准27.1657。生产3439输入与r9同SHA/可执行位、无增删改，范围沿用快照过滤。[完整验收与原始统计](../../output/render-lowdim-20261113/native-production-r10-rack-analysis/summary.json)。

1400×800同overview：rack R/guard帧P50 **0.972208334/0.819312525ms**，九轮配对中位**−16.0115%**、9/9更快，范围−26.1792%至−11.4386%；R端点最大漂移36.766%保留，不混用帧P50和配对统计。scatter1400配对−50.9605%、scatter700−41.1860%，各9/9；两球+0.7812%/−0.9111%不认定收益。主控打开rack原图核真实球房、绿色台呢、球堆；R/candidate/repeat/restored四PNG文件SHA均为`9358d5…`。

本轮确认固定rack也有效，且相同16球的rack与scatter不能视为同一成本。结论仅适用于这些完整生产SceneKit固定场景、同一R反射probe；不包含SwiftUI页面、probe生成、镜头切换、动态球或呈现FPS，不能把scatter约50%推广为整页收益。

## R23：完整真实开球动态验证

复用现有种子`1972274182705165791`、力度10及生产`BreakSimulator`／`TrajectoryPlayback.action`，只求解一次；拟以60Hz覆盖真实运动、落袋轨道和最终旋转尾段，逐帧比较R与guard，并在九个真实状态各做九轮ABBA/BAAB。GPU计时只代表这些状态的直接渲染成本，不包含物理解算、动作捕获、SwiftUI或呈现FPS。生产代码与r10完全一致，新增仅测试。

r11快照`0f2718ee…`，run `7bc7e55099a94680b9b5e7b97b3c2356`构建成功，测试1项失败：三帧动作时钟回调为空，尚未进入物理解算或动态图像验证。最小macOS对照中，无事务flush的两个时间起点都无回调；加flush后均为0、1/60、2/60。确定测试同步渲染前未提交隐式动画事务，不能解释成候选画质或性能失败。[四组原始对照](../../output/render-lowdim-20261113/native-dynamic-r11-failure/clock-probe.log)。

r12仅在时钟探针及生产动作注册后各加一次`SCNTransaction.flush()`，保留原时钟、完整轨迹和全部断言；新快照`e03dc39d…`。首次增量入口在只读工作副本写入前失败，未启动构建或测试；后续仅临时开放该已登记工作副本的单个测试文件写入并恢复原权限，未修改任何封存快照/旧证据。run `9458612082b34c818fce07697c68087d`构建成功，时钟门禁通过；测试1项失败于案例预设：真实物理已settled、时长16.338579秒，却没有落袋。原回归只保证spin-tail，错误地假设它也进球；本轮未进入动态图像/性能比较。

据此保留原旋转案例，另采用既有`testRealBreakKeepsRailsThroughDeliveryAndCancelledRerack`中的种子`1180286254055038828`覆盖真实进袋与轨道。两个案例分别要求自己的真实覆盖条件、都跑完整时间线和逐帧图像；不是删除落袋门禁或人为制造轨迹。下一次结果待回填。

r13快照`43024438…`、run `3ef409ca0382452a8035ddaa2582edb6`构建成功；spin-tail真实动作捕获547帧及逐帧物理位置、uniform校验通过，随后R姿态重放首帧的节点精确一致断言失败。此时尚未比较guard，不产生画质或性能结论。保留[失败附件](../../output/render-lowdim-20261113/native-dynamic-r13-failure/attachments/manifest.json)。下一修订移除姿态保存再应用：直接在每个真实动作时间点对同一球态进行R/guard/重复/恢复渲染，严格校验同刻节点与像素不变；不放宽精度阈值，九个状态的GPU配对也在实际到达该帧时完成。

r14快照`f9e5dcc5…`、run `ef05f590ad134ebd97b9e5ab98ecb748`采用直接同刻对拍。spin-tail完成547帧全像素/状态校验及9个计时点；第二个pocket-rail计划647帧，执行到约第160帧/第3计时点时进程被杀，整项XCTest仍为失败，不作为两案例通过。kernel明确PID46680于11:23:26因`per-process-limit`、16777222KB被jetsam终止，并非画面断言或watchdog。[测试失败摘要](../../output/render-lowdim-20261113/native-dynamic-r14-failure/summary.json)、[系统原始日志](../../output/render-lowdim-20261113/native-dynamic-r14-failure/process-system.log)。下一修订为同步长循环逐帧/逐案例设置autorelease释放边界，保持全部采样和断言；这是测试宿主生命周期修正，不能据此声称生产App本身存在同等内存增长。

r15仅加每帧/每案例autorelease pool；快照`99f79cd5…`、run `bf8617fe5a834ed7a0335778529042a0`编译失败，8条错误都来自pool闭包内`verifyCurrent`局部函数失去MainActor推断，测试未启动、RSS样本0。r16仅给该函数显式`@MainActor`，快照`70ef7962…`、run `b50521edbd584bdea0300aa890caf580`重跑；完整验证及RSS结果待回填。以上故障均保留原日志，不把parse通过称为build通过。

**r16最终通过**：构建及精确selector 1/1 Passed、0失败/跳过，来源/工作副本哈希一致；旧r11共2164份封存证据SHA未变。主控运行独立consumer通过，547+647=1194帧全像素/同刻节点/当前uniform一致，24张保留PNG独立解码，两个真实案例分别完整覆盖spin-tail和1号球进袋/轨道。18状态各9轮、3888计时帧、648末目标检查，162/162轮guard更快；初态配对中位−17.81%/−17.77%，之后分别−45.53%～−48.11%和−40.34%～−49.81%；最差单轮−14.13%，R端点最大漂移69.54%未剔除。[分析与原始结果](../../output/render-lowdim-20261113/native-dynamic-r16-analysis/REPORT.md)。这是完整生产场景实际球态的直接渲染成本，不是整页FPS或连续实时播放耗时。

主控打开pocket-rail末帧确认真实球房、散台和袋外轨道1号球。逐帧释放后，17次每2秒RSS观测最大1,186,784KiB（约1.13GiB），宿主正常退出；这不是连续绝对峰值或生产App显存改善。[RSS原始记录](../../output/render-lowdim-20261113/native-dynamic-r16-memory/summary.json)。保留guard为当前最有依据的DEBUG候选，结束同类算法与采集扩张；未闭合的页面进入/反射资源成本及设备/发布边界单列，不把本轮比例扩写成整页收益。

`verify-gate` exit0、`verify-doc-size`通过，最终快照与r10比较仅测试文件变化。r16任务work及五个已诊断失败的空work已回收，所有失败/成功证据保留；共用r11构建已解除hold并关闭，但原生`.XCInstall` wrapper权限导致部分work回收延迟，未修改wrapper权限。r9为后续页面成本对照保留的App未触碰。下一步只补实际进入场景/反射生成的冷暖成本，不重跑已闭合的动态图像或扩张逐帧采集工具。

## R24：实际异步进入链的冷暖成本（成本采集完成，首帧稳定性未解决）

假设：guard每次安装约5ms的字符串构造与独立probe身份可能抵消部分进入体验；必须包含候选自己的反射生成，不能沿用R23共用R probe的成本。源码核实实际路径为`FreePlayView.onAppear → configureDailyClearanceRendering(asynchronousReflection:true) → PositionPlayViewModel.setupScene(loadsDefaultLayout:false)`，异步probe在setup返回后仍可能未安装。

新测试复用该VM/scene路径，不调用DailyClearanceController或改写存档/偏好；以现有实际外观、固定rack/镜头进行9轮ABBA/BAAB，每slot为应用资源缓存冷进入和其紧接的同variant暖进入，共72次。分别记录setup返回、初次GPU目标帧、probe发布和就绪后完整目标帧，不把重叠时间相加。暖状态须核真实台对象及probe复用，冷状态不冒称OS/驱动或新进程全冷。候选与R各自生成真实probe，检查纹理/SH及完整首帧图像。

本项不含SwiftUI布局、存档恢复或屏幕present，因此仍不能替代原合同的完整页面活动净收益和20次真实页面进退；它解决进入链中的VM/场景/反射/首个GPU目标成本缺口，最终结果见后续r20记录。

r17快照`02aa35a7…`、run `2387c770f9e543269e2741ac7d487642`构建通过，首R cold之后R warm全图黄金失败；候选尚未运行。冷暖R相差324,182像素、最大通道8，集中地毯，probe三纹理/SH/floor相同。不能按跨cache状态共用画面黄金。r18快照`bc01678e…`、run `2094e2e722cf47bd9e67b36ca91a62b9`按冷暖分别比较后，首candidate cold与R cold仍有3个1-LSB像素差，位于近侧中袋装饰；地毯与cold R一致，不能沿用上一失败的解释。两次严格失败均保留，不作为72次通过或性能排名。[r17附件](../../output/render-lowdim-20261113/native-entry-r17-failure/attachments/manifest.json)、[r18附件](../../output/render-lowdim-20261113/native-entry-r18-failure/attachments/manifest.json)。下一修订在记录每次自身真实probe/首帧成本后，对同一scene/球态/probe做R表面参考对拍，仍要求全RGBA零差；跨scene图像差仅描述，不添加容差。各自probe跨全部进入严格相等继续保留。

## R25：真实页面20次进退与内存增量

复用r9同一App（二进制SHA `72292637…`），各臂新进程，正常进入已有每日清台后返回，不击球、不重置存档或偏好；每个页面/首页均存AX状态和目标PID的`footprint`、RSS，所有页面保持0杆。此为实际进程资源验证，不用AX操作耗时声称首屏延迟或FPS。

首轮R→guard各20次，80有效循环点。末5页面中位差46.250MiB，但guard后段与构建重叠、首进入进程年龄不同、无固定退页等待，不能归因或宣称门槛通过。保留原结果及一次已退出旧PID的采样失败，后者不计入循环。[首轮报告](../../output/render-lowdim-20261113/native-page-lifecycle-r1/REPORT.md)。

复验反向guard→R，同新进程初始首页采样年龄27秒、首次页面30秒，固定AX后2秒采样，无并行构建或GPU测试；80循环点加4个初始/延后点全部有效。末5页面中位R983.737/guard1031.018MiB，差**47.281MiB、4.81%**；首页R814.252/guard861.502MiB，差47.250MiB、5.80%。最后退页后约40.8秒两臂各下降约72MiB，差仍47.781MiB、6.44%。末段局部平台不等于排除泄漏；**32MiB绝对门槛未通过，10%比例本次低于门槛，二者分别保留**。两App均正常退出。[复验报告及84样本](../../output/render-lowdim-20261113/native-page-lifecycle-r2/REPORT.md)。

首次页面两者仅差约0.922MiB，差距随反复进入形成。下一针对性假设为重复`guardedCore`字符串构造引起分配器高水位；尚未取得guard分类，不能归因shader、驱动或泄漏。最小试验仅缓存验证成功的不可变guard文本，每次仍执行配置/容量/源SHA/采样等门禁并重建State，不缓存scene或逐帧状态。必须以实际20次页面循环重验效果，不能仅凭“新增缓存很小”宣称解决。


r19快照`f28dc1f7…`、run `964fa8086d144373be3896a7f16df41e`完成缓存改动构建；DailyClothSupportExperimentTests全部16项通过，含热缓存无效输入回退、64次混合并发与完整surface黄金。R24到cycle3/slot3/reference/warm时，**R对R自身**仍有1像素、最大通道1的首帧差异，因此整次17项为16过/1失败。已记录23条完整进入，不能作为72次成功或画质通过；[原失败附件](../../output/render-lowdim-20261113/native-entry-r19-failure/attachments/manifest.json)保持不变。最后一次r20采用明确分离合同：成本采集保持72/原时序与全部状态、probe、源码、释放硬闸，像素差异不设容差、逐项保留PNG/count/max/hash，`timingCompleted`与`qualityAccepted`分别报告，任何非零仍画质未解决且不允许据此晋级。此后结束首帧探针扩张，不为追全PASS继续改判定。

**缓存版真实页面复验通过本轮资源预算**：r19 App SHA`12e77252…`，guard/R各20次，84点全有效；两臂初始首页进程年龄36秒、首页面约39秒，AX后固定2秒，无本任务构建或GPU测试重叠。末5页面中位R986.018/guard987.533MiB，差**1.516MiB、0.154%**；首页差1.422MiB、0.174%；约43.2秒延后首页差1.859MiB、0.250%。三口径均满足32MiB AND10%，末5范围约1.2–1.4MiB，无持续阶梯形增长的本次迹象，不作长期无泄漏保证。相对r2，guard页面下降43.484MiB、R增加2.281MiB；跨构建差额仅描述，类别快照不能把全部下降确定归因某种分配器/driver机制。[独立报告与84点](../../output/render-lowdim-20261113/native-page-lifecycle-r3/REPORT.md)。两App正常退出，原R9预览App未替换，手机未操作。


**R24一次有界成本采集完成**：r20快照`72a35a8c…`、run `b580bffa8b5f4eef99ba27aa428365f2`，构建及selector1/1过、0跳过；guard生产代码与r19相同，仅测试计量合同分离。72entries、108独立首帧计时draw、144计时外control，冷暖各9ABBA；三texture/SH/floor全同、暖台/probe身份和每次VM/scene/renderer释放硬闸通过。独立r5 consumer返回`timing_accepted_quality_unresolved`，summary SHA`85e1b020…`。VM setup配对中位冷+1.421ms/0.110%、暖+1.029ms/0.564%；probe安装receipt冷+18.614ms/1.146%、暖+1.029ms/0.563%。最坏冷probe轮+225.469ms完整保留。暖setup→首离屏目标帧配对中位−0.715ms，但不是完整App首屏/用户交互延迟。[独立成本报告](../../output/render-lowdim-20261113/native-entry-analysis-r5/summary.md)。

画质没有改判通过：R自身、G对R、R恢复、G恢复四组各36次中各有1次非零，均1像素/最大通道1；全部异常图及hash/count独立核验，`qualityAccepted=false`、`promotionAllowed=false`。R19旧失败保留；r20成功表示成本采集及其硬合同完成，不表示旧的零差画质合同被满足。到此结束首帧实验扩展；当前最佳DEBUG候选保留guard+不可变文本缓存，默认/Release仍R，完整页面活动净收益和其余设备/发布边界仍未被本轮取代。


本阶段收尾：`verify-gate` exit0、`verify-doc-size`通过（PROGRESS仍在100KiB门槛内）、范围内diff空白检查通过。r18/r19/r20临时work已按生命周期回收，原exit1/1/0及全部封存证据保留；共用r17构建/当前缓存版原生App因后续整页验证明确保留，未回收其他任务设备或模拟器。r9旧App也保持原状态，未操作手机。下一步按完整页面活动成本和未完成合同继续，不能把本阶段收尾称为整体目标完成。


## R26：真实页面连续相机采集失败与页面状态补验

上一阶段是实质进展：文本缓存和20次进退资源复验完成，R24成本采集完成。当前回到完整SwiftUI页面的CPU/目标SceneKit层GPU/OnGlass分阶段对照，不再扩首帧探针。只读复核R21确认：drawable端点全部配对成功，但约2.09秒的长carrier缺中间逐drawable值，不能拿区间交集约100%填满冒称GPU样本完整，也不能事后挑末组六输入排名。

零生产代码改动：复用原生App、既有轻量runner与官方逐帧环境变量；正常已有16球开球盘面/0杆，三相机按钮200ms按压、批量中不做AX读取。过渡中再次点击是合法生产重定向，不冒称每次到达终点或逐GPU姿态完全相同。预先固定8臂ABBA+BAAB、各新进程24动作预热/84测量动作，窗口只取首测量orbit的+3至+13秒，首orbit不足15秒或覆盖/节奏/配置不满足即不排名；坏臂保留，不向后搜有利窗口，不按结果追加轮次。[事前协议](../../output/render-lowdim-20261113/native-page-continuous-r1/protocol.json)。r20 App SHA`5aceca1b…`；冻结源与r19唯一差异为测试文件，生产缓存代码逐字相同，不能冒称二进制仍为r19 SHA。

### R24可见画质评审的范围澄清

独立审查已打开R24全部6张异常原图：两个entry（暖guard和暖R自身）的四组差分均在1400×800的同一像素(348,292)，RGBA由[33,73,32,255]变为[33,72,31,255]，各entry的Rcontrol与restore互相逐位相同。位置在远侧长库左端/左上角袋右侧绿色边缘；正常尺度原图未观察到候选独有可见变化。产品目标是保持可见画质，EVALUATION同时要求差异量化；据此单独记录该机位/样本范围的可见审查结论，不将研究自设全bit一致合同扩大成用户的额外要求。原`qualityAccepted=false`、`promotionAllowed=false`、所有非零数值和PNG永久保留，不设新容差、不改consumer、不宣称SceneKit内部原因已查明，也不据此推广全部机位/连续多视图或设备。

### R26实际结果：首臂无效，停止后续盲采

reference PID69607、run `f9e4af3c23374c449476812f900fee75`正常封存，84次相机操作约20.23秒，结束仍为原盘面/0杆；但App输入/firstRender/wake各只采到65个，sequence44–108，缺前19个25–43。orbit只有结束、没有开始，无法建立协议要求的首orbit及+3..13秒窗口。369对drawable端点配对成功不弥补缺失锚点。首臂标记invalid，余7臂没有继续，未选择后段窗口或补出性能排名。[无效判定](../../output/render-lowdim-20261113/native-page-continuous-r1/analysis/01-reference.json)、[完整解析事件](../../output/render-lowdim-20261113/native-page-continuous-r1/analysis/01-reference-parser-detail.json)。

录制开始通知后15.745秒才发首动作，不能将原因简单解释成未等待开始。Time Profiler从trace+1.148秒有CPU，FramePacing在+17.044秒有非零端点，daily首事件到+21.581秒才出现；动态子系统何时完整就绪仍未知。没有把事件缺失称为App卡顿或真实丢帧。

独立一次25秒就绪余量校准已事前记录，但CUA在首动作执行前因外部界面状态变化拒绝操作；刷新仍为原0杆静止页，所剩录制窗口不足完整84输入，因此未发部分批次。run `1affaf3a551d44559e727b3aa9d595b2`已正常封存；[中断事实](../../output/render-lowdim-20261113/native-page-continuous-calibration-r1/INTERRUPTION.json)保留，不将它算作余量方案通过或失败，也不拼回原8臂。按本轮有界决定停止追采集，转做已有真实页面路径验证。没有新增生产或采集框架代码。

### R26实际页面状态补验

同一缓存版guard进程PID70775，现有Chinese8开球盘面。正常打开/关闭打点面板（不改打点）、打开/关闭临时俯视、系统隐藏并恢复原窗口、正常返回训练首页；7张原图和对应AX存于[实际页面证据](../../output/render-lowdim-20261113/native-page-state-r1/summary.json)。所有桌面步骤仍0杆、杆速10，原盘面保留；静置后主场景FPS标签恢复“静止”。当前临时俯视确为独立SCNView路径，未冒用旧snapshot分支。只读AppKit确认隐藏时`hidden=true/active=false`，恢复后实际透视画面完整；返回首页后正常退出，PID已不存在。

本项只证明本机当前配置的实际功能/画面状态；主诊断没有overlay layer标识，不能把主场景静止标签当全部合成GPU为零，也不证明持续多视图成本。正常隐藏/返回可能保存累计活动时长，未称存档字节不变。完整页面活动净收益仍待有效测量；手机、远端和默认/Release均未动。

中断校准的trace另作明确的描述性静止观察，不作为原协议成功：固定trace+30..50秒，对应AM真实包围区间29.904498083..50.450506166秒，CPU累计81.600458ms/20.546008083秒，约0.39716%单核；17个窗口内footprint样本约915.83..915.85MiB，首末+16KiB。全trace daily输入0，窗口内FramePacing事件/OnGlass端点0，没有拿旧显示carrier当持续绘制。无参考臂，且该trace没有配置事件，所以仅称启动请求为guard的本机实际静止页观察，不能独立证明本次guard已安装或GPU零开销。[静止观察](../../output/render-lowdim-20261113/native-page-idle-observation-r1/REPORT.md)。

7张原图独立逐张审查未见窗口内空白、明显缺球、材质异常或恢复错层；范围和未覆盖项见[视觉复核](../../output/render-lowdim-20261113/native-page-state-r1/REVIEW.md)。本轮`verify-gate`、`verify-doc-size`和范围内空白检查通过，未改生产源码。两个目标App均已退出；首trace受管work已回收，中断校准trace已complete但仍有进程/句柄引用而保留work，封存证据全部保留；收据见`native-page-state-r1/cleanup/`。共用构建仍按后续验证用途保留，没有清理其他任务设备。

## R27：固定静候25秒不能解决首段日志缺失

上一轮属于实质进展：页面状态补验完成，静止观察和无效采集边界落盘。本轮独立协议重新冻结8臂，先执行reference首臂；run `781d9179145c4fa4a7706264bb02f175`、PID73896、同SHA`5aceca1b…`，通知后实际25.099374秒才发首测量动作，24次预热/84测量均完整，批次20.286秒。系统表仍仅67个输入/回调（sequence42–108），缺前17个25–41；orbit只有End，没有Begin。617对drawable配对无错不弥补正式锚点缺失。按协议停止其余7臂、不输出固定ROI或排名；App正常退出。[原协议与STOP](../../output/render-lowdim-20261113/native-page-continuous-r2/protocol.json)、[无效首臂](../../output/render-lowdim-20261113/native-page-continuous-r2/analysis/01-reference.json)。

两次静候15.745/25.099秒仍分别缺动作开始后的4.577/4.093秒；只证明延长静候未解决，不宣称已定位系统内部原因。下一次仅改变既有预热顺序：把24相机预热放进同次录制，预热后静置3秒，再开始84正式输入。测量条件/源码/runner不改；原坏臂永不拼回。

## R28：录制内预热完成，正式操作被过期AX元素中断

独立[r3事前协议](../../output/render-lowdim-20261113/native-page-continuous-r3/protocol.json)，run `b5b6e7241ac740eb8f5c811ee8c08ef4`、PID75563。录制内24动作预热完成，耗时5.833秒；正式批次开始后CUA报`element ID is no longer valid`，刷新显示第一人称已选中、仍0杆。原函数仅成功结束时写动作数组，所以部分成功动作数量没有CUA逐项收据，不能猜测补写。没有续点凑84，也不把部分批次作为正式ROI。trace正常封存、同PID/同binary核过，剩余7臂不执行。[中断记录](../../output/render-lowdim-20261113/native-page-continuous-r3/INTERRUPTION.json)。

这次是自动化元素句柄失效，未发现生产点击功能失败；后续若继续该路径，须先验证截图中稳定相机按钮的坐标点击能力，避免为每个动作加整树AX读取而污染CPU/连续时序。录制内预热是否解决日志首段缺失，由此封存记录的实际序号和orbit独立检查，不能从“24预热操作成功”推断。

封存记录的[部分解析](../../output/render-lowdim-20261113/native-page-continuous-r3/analysis/partial-analysis.json)确认：预热只捕到21–24，但正式序号25已捕到、wasIdle=1，随后orbit Begin/End完整，持续8.597791375秒；正式实际日志25–53共29个输入及对应回调。它支持“录制内预热后正式起点可被捕获”，仍不满足84输入和15秒活动，未算正式ROI/排名。实际日志29个不是补写29份缺失CUA收据。

## R29：稳定坐标操作下的固定真实页面对照（采集完成，未获得有效排名）

三相机按钮由实际截图定位并逐一点击后核AX选中状态；连续84次200ms坐标点击全部完成（42.879秒），另12次100ms均完成（5.019秒）。据此事前固定每新进程24次录制内预热、3秒静止、60次100ms正式动作（10个既定六动作循环，sequence25–84），适配60秒录制窗口。固定首正式orbit至少15秒、+3..13秒ROI及全部覆盖/节奏/配置闸不变；仍8臂ABBA+BAAB，首臂无效就终止后续，旧r1–r3从不拼回。[事前协议](../../output/render-lowdim-20261113/native-page-continuous-r4/protocol.json)。

只更换现有CUA点击的目标定位，生产代码和采集runner不改；两个动作批次内部均无AX查询，错误时保存成功/未完成动作且不续跑。原始事件全部保留，离线正式统计仅选预先声明的25–84，drawable动作标签按真实sequence区分预热与正式，避免旧按事件索引映射的错位。首臂PID77553、run `fb78c3ed416d415b841fd0b076a8292c`已正常封存：24预热10.287秒、60正式24.236秒、0杆/静止恢复；事件及ROI完整性由独立消费器核定，不能从点击成功提前称性能有效。

截图编码勘误：本机CUA这些原图实际为JPEG 2048×1600；R26/R27中部分文件沿旧习惯命名为`.png`，未转码、未编辑，原始bytes/hash保留。文件扩展名不作为像素精确对拍证据；R23/R24的测试生成PNG不受此勘误影响。R29新截图使用`.jpg`后缀。

R29离线结果：正式sequence25–84共60个输入及对应firstRender/wake完整，预热1–24也完整；首正式orbit起点24.734623秒，固定ROI为trace+26.868343708至36.868343708秒。原严格覆盖为99.6244716%，保留269条reported GPU样本。原协议仍判无效：16对同layer/drawable ID/payload的End比Begin早41–42ns；另16条104–246ms的OnGlass区间伴随后续drawable ID跳6–15。身份匹配证明不能简单称“缺End”，重排也不能消除负区间；长carrier同样不能据此定性为真实App卡顿或丢帧。按慢区间拒绝整臂还可能引入选择偏差，因此没有继续余7臂或修改旧结果来取得排名。[原判定与逐项审查](../../output/render-lowdim-20261113/native-page-continuous-r4/analysis/endpoint-carrier-audit.json)。

## R30：官方Metal HUD八臂真实页面对照（全部采完，两个cycle均不可比较）

本轮不改生产代码，复用同一缓存版原生App SHA`5aceca1b…`。停止扩张xctrace/FramePacing解析，改用Apple公开的`MTL_HUD_ENABLED=1`与`MTL_HUD_LOG_ENABLED=1`输出、只读App诊断流和公开`proc_pid_rusage`端点。独立能力检查确认真实M5 Pro、2660×1996、Composited页面和完整stderr逐帧对；它只证明通道可用，不计R/G收益。[能力记录](../../output/render-lowdim-20261113/native-metal-hud-capability-r1/SUMMARY.json)。

事前冻结[八臂协议](../../output/render-lowdim-20261113/native-page-hud-r1/protocol.json)，SHA`aa1422b2d0c44af3f5aee1c451e4f15987b0f41d30a356c2638a3fbd2d6f48d6`：R/G/G/R、G/R/R/G，每臂独立新进程，24次预热、3秒静置、96次正式相机按钮操作，100ms按压、350ms预定起始间隔；固定正式首动作+5至+15秒的**日志输出时间窗口**。窗口不是精确GPU执行ROI，也不保证全量唯一帧。所有reported interval/GPU pairs（含零值、长值、推断帧号缺口和重叠）保留，不据耗时剔除。各臂只改变DEBUG候选参数，实际安装配置、容量16、reference采样、MSAA4、scale2、60fps目标和尺寸逐项核验。

8臂均完成24+96次动作，合计768次正式动作；实际输入/firstRender/wake序号25–120完整，窗口内活动连续，结束均恢复静止/0杆。全部App正常退出，8个本任务日志进程正常结束；没有操作手机、远端、其他任务进程或改变默认R。每臂CPU端点、所有动作实际起止、原始stdout/stderr/NDJSON、入口及结束JPEG、AX、进程SHA和退出收据均保留。

**结果：两个cycle均未满足事前可比性要求，不得给出整页净收益排名。** 01/05/08臂达到单臂日志完整性门槛；02/03/04/06/07固定窗口分别仅2/2/2/4/2条官方HUD日志，低于至少8条要求。独立计数确认stderr条数、unified条数、成功关联条数完全一致，stderr-only为0，时间差最大约1.112ms；缺失已出现在App输出侧，不是consumer关联遗漏。当前证据不能确定官方输出变稀的内部原因，更不能把它直接解释成实际无渲染/掉帧。

实际自动操作节奏也失配：01/05/06/08平均约350.01ms，02/03/04/07分别452.80/434.08/427.29/410.74ms。ABBA块各臂均值max/min=1.294、BAAB=1.173，均高于1.10；P95比约1.348/1.208，也高于1.20。保留所有慢臂，不从01/05/08挑数重组有利对照，不追加替换样本。它说明当前自动化输入不能保证既定节奏，不证明候选增加了相应CPU/GPU成本。

CPU采用实际96-byte rusage V0的user/system Mach ticks与本机`mach_timebase_info=125/3`换算；SDK定义、Apple XNU调用链及同次`ps`读数交叉核过。各臂CPU delta只对应实际采样包围段，包含不等长的动作前/后AX及工具间隔，不作为同一10秒GPU窗口或相同工作时长的收益。phys_footprint只为端点，不能称峰值显存。

消费器冻结SHA`a45fddf2047f95945e2df50766ca3dea71b9c91aec3fb898e531011709e48985`；前两次纯文件格式/同消息时间关联修正的原失败及源码保留，未重采、未改性能门槛。最终[全部八臂及两个cycle](../../output/render-lowdim-20261113/native-page-hud-r1/analysis-r3/summary.json) SHA`d03bd4a27e5dfcb8e597f3de5581f3b152f80d83b14d2ae32284bb268b87941a`。本轮关闭采集，不继续用相同失败链路盲重试，也不复跑已成立的R23画质/GPU和R25资源验证。下一步必须先明确能控制输入与取得完整样本的实际页面测量方式；在此之前，整页提升仍为未证实，当前最佳DEBUG候选及其已验证范围不变。

本轮效率复盘：R26–R30大量时间消耗在采集工具、日志语义与自动化的排障，不能计为生产性能改进。用户指出进度慢后，主控将八臂采集与离线消费分开、固定组数并保留全部失败；后续不再以修工具数量或累计轮次作为进展指标，只报告新增代码收益、有效验证及明确未解决项。

R30收尾：独立审查再次核过8臂进程身份、768个实际输入及对应回调、16份CPU端点换算和两组节奏失配，见[独立复核](../../output/render-lowdim-20261113/native-page-hud-r1/INDEPENDENT-REVIEW.md)。`verify-gate` exit0、`verify-doc-size`通过（PROGRESS 100KB）、范围内diff空白检查通过；本轮guard生产源码SHA仍`75185108d0a56d5b090faec77088404910b7ee6a55f1bf4c161462b18f2bfbb8`。没有提交、推送或发布。研究目标仍未完成，不能将本轮采集收尾标记为整体达成。

## R31：系统逐drawable来源验证（能力通过，不计性能收益）

本机官方`/usr/bin/metalperftrace`及随系统安装的手册提供历史Metal统计导出；HUD手册明确旧console日志已弃用且指标不完整。[原始手册副本与SHA](../../output/render-lowdim-20261113/native-metalperftrace-capability-r1/local-primary-docs.json)保留。对R30两个旧PID直接取历史数据，没有重启App；原console稀疏窗口仍有非空系统统计桶，因此旧日志缺失不能解释为没有渲染。未开逐帧标志的导出只有约1秒统计桶，不能从其汇总值推算逐帧P95，也不将这些不同边界的历史窗口补为R30有效对照。

单R烟测改用进程局部`METAL_PERFORMANCE_PER_FRAME_SIGNPOSTS=1`、HUD开启、console日志关闭，24次预热后36次相机操作按600ms调度。真实input/wake/firstRender序号25–60齐全，唯一App/layer导出489条原始On-Glass区间；相邻间隔均1 Mach tick，固定+5…+15秒内窗由原始时间覆盖。该来源没有drawable序号，身份为PID/layer/起止MCT，不能称帧编号连续。零GPU、零CB及长区间全部保留。

烟测内窗实际含orbit 9.584113秒、idle 0.415557秒，selectedFPS60、scheduledFPS随状态60/30变化；这是固定相机操作加自然休眠，不能写成10秒持续饱和。正式第一臂前即据此冻结R32混合负载协议，旧连续活动草稿保留，未读正式性能结果后改准入条件。[独立输入与阶段审查](../../output/render-lowdim-20261113/native-page-metalperf-smoke-r1/SMOKE-INDEPENDENT.md)。本轮仅验证来源与操作能力，无R/guard排名；App/stream均退出，未修改生产、系统全局HUD设置或用户盘面。

## R32：真实页面八组固定操作对照（一个有效BAAB，尚无稳定整页净收益）

事前协议SHA`4b0b2818197c6d589f24bcc95a129edbaad18a3b412c54f28d5769fdeef74cf7`；同二进制SHA`5aceca1b029e84c7c3cddf172f3f375820ac04230ec113f6db7a5ca12327e4f7`，新进程依次R/G/G/R、G/R/R/G，8组均24次预热、36次正式操作、600ms固定调度。原生M5 Pro/macOS27.2、每日中八manualRacked 16球、2660×1996、MSAA4、scale2、selectedFPS60，guard实际安装无回退；全组末态0杆。没有fixture/reset/会员或偏好覆盖，正常导航仍可保存时长。

288次正式CUA调用均返回，实际App输入/回调只有287次：03-guard缺一次，原36输入合同使第一ABBA无效；缺口在GPU内窗之后也不能事后豁免，不补样、不替换。其余7组及第二BAAB的输入、节奏、身份、配置和尺寸满足原要求。[独立复核](../../output/render-lowdim-20261113/native-page-metalperf-r1/INDEPENDENT-REVIEW.md)。

8份官方历史导出均exit0。消费者初版错误地把frame来源的Date/MCT偏移套到unified log的machTimestamp，跨来源差6–13ms导致全拒；原源码/失败结果保留。修订只让App阶段和配置采用其原生带时区timestamp，frame仍按原有Date/MCT映射和≤1ms门槛校验，没有放宽协议、改变帧值或重采。具体跨来源时钟机制未证明，不能声称共享同一Mach偏移。修订后7组固定10秒窗口覆盖均大于99.9997%，所有零/长值原样保留；03仍按输入合同无效。

第二BAAB为05G/06R/07R/08G，四臂分别566/565/581/580个起点落窗的drawable。下表先计算每臂统计量，再对同配方两臂取均值，非合并帧的分位数；GPU是这些drawable的reported metadata，并非所有GPU执行恰好落在10秒内。

| 指标（ms） | R两臂均值 | guard两臂均值 | 变化 |
|---|---:|---:|---:|
| reported GPU均值 | 4.151265 | 3.936361 | −5.18% |
| reported GPU P50 | 4.045063 | 3.851417 | −4.79% |
| reported GPU P95 | 5.768416 | 5.880917 | +1.95% |
| reported GPU P99 | 6.709083 | 7.116833 | +6.08% |
| On-Glass区间均值 | 17.443606 | 17.453545 | +0.057% |
| On-Glass区间P95 | 26.937958 | 26.855771 | −0.31% |

**结论：本次有效周期观察到平均GPU成本下降，但不足以认定稳定整页净收益，也没有呈现节奏的明确改善。** 06R→07R的GPU均值从3.834734到4.467796ms，相差16.51%，大于约5.18%的配方差；GPU尾分位方向也不一致。相机输入相位约有0.17–0.20秒差，guard比R多约65.339ms orbit/10秒（0.653个百分点）；它们是固定操作工作负载的实际差异，限制纯shader归因，不新设事后失败门槛。首周期01/02的零GPU与长区间较多，全部原件保留，不挑后段快组把两个周期拼成通过。

CPU仍是各批动作及实际前后等待的进程累计差：全8组包围31.020–39.661秒，与GPU10秒内窗不同，不能据此声明净CPU改善或与GPU相加。frame CPU walltime同样不是进程CPU用量。每组另列内窗完整1秒统计桶的呈现/跳过计数、GPU总量及真实桶长，不能与drawable起点队列混分母。[消费结果与全部原值](../../output/render-lowdim-20261113/native-page-metalperf-r1/analysis-r2/summary.json)。

本轮只测完整页面的固定相机操作与自然idle，没有击球/求解、持续临时俯视、多视图压力、20分钟温升或移动设备性能结论。默认/Release仍R；没有生产代码改动。所有8个App和日志进程均退出、原始trace/导出/动作/CPU收据保留。本轮结束追加采集；不重跑R23/R25，不为追到显著性扩建工具。阶段结果可交付，整体目标尚未标记完成，未覆盖项继续与已证范围分开记录。

收尾验证：主控直接从7份原始overview按冻结窗口独立复算样本数、GPU均值及P50/P95/P99，与消费结果一致；该复算复用已审查的时间映射，不冒称第二套时钟校准。[复算收据](../../output/render-lowdim-20261113/native-page-metalperf-r1/root-arithmetic-check.json)。`verify-gate`、`verify-doc-size`与范围内diff检查均exit0，guard生产源码SHA仍为`75185108d0a56d5b090faec77088404910b7ee6a55f1bf4c161462b18f2bfbb8`；未新增App构建或重跑既有测试，不将文档门禁当性能通过。[检查收据](../../output/render-lowdim-20261113/native-page-metalperf-r1/final-checks.json)。

R32后工作调整：自动续接时仅阅读了原handoff与当前代码，尚未启动新实验。用户提出“怎么又要测”后，主控撤销新增验证安排及相关委派；当前基于现有结果收口。未验项保留为结论边界，不能因此自动扩张测试，也不能据此假报完成或把候选改为正式默认。


## 正式推广：按用户新授权接入所有相关场景

2026-11-13。用户在研究阶段收口后明确要求“把他们应用到app里，相关的场景都用”“确保不要有遗漏”。本轮是有边界的生产推广，不恢复原持续研究目标，也不再增加性能对照轮次。共享默认、非DEBUG安装、桌缓存/probe身份和显式原R对照已接通；覆盖27组调用方，生产增量5文件+31/−42。验证和已知构建环境限制以[ROLLOUT.md](ROLLOUT.md)为准。
