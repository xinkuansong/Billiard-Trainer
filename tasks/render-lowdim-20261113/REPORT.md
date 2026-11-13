# 台呢低维表示探索：首轮原型与证据

日期：2026-11-13（北京时间）。状态：**首轮数学与原生 Metal 消费原型已运行；完整 P0/P1、页面接入、空间字段及真机验收仍在后续范围。**

> 此文保留首轮当时结论。后续实验、参数纠正、失败证据和当前候选统一查[持续研究记录](ITERATIONS.md)；设备/FPS 门槛按用户后续修订采用[通用评价口径](EVALUATION.md)。

用户明确接受探索和尝试。本轮按 [handoff 原件](HANDOFF.md) 推进，保留失败和边界，不把未知当作不开工理由。没有修改正式 App 的 Swift、USDZ、默认 R、物理、相机或帧率配置；新增代码均在 `scripts/research/cloth_lowdim_20261113/`。

## 1. 本轮结论

**继续研究每灯 8 组的方向矩表示，但暂不接入正式页面；放弃“直接把混合回退塞进同一个候选内核就会整体更快”的当前实现。**

支持继续的依据：

- 从当前生产 Swift 生成器直接导出的 Metal 参考，与独立 NumPy 计算在 4,608 个参数样本上吻合，建立了可运行对照。
- 有效半球内的漫反射方向矩保留原采样比值；半球外的反例已复现，必须回退。
- 每灯 8 组意味着近档高光由 64 次 BRDF 降为 16 次，消费者已经用 Metal 实际运行，并非只做离线压缩。
- 使用当前台呢贴图同位置的法线 / 粗糙度后，每灯 8 组的误差显著小于额外低粗糙度压力样本；有继续做最终画面对照的价值。

尚不适合投产的依据：

- 高光是近似，实际可见画质还没验；不能称无损。
- 单独适用区域的冻结数据消费更快，但与直接回退混合执行时，本轮 Mac 内核反而更慢。
- 本轮没有空间纹理采样、插值、FP16、字段生成及动态同帧调度；因此没有完整净收益。
- 原生 SceneKit 材质、HDR / 曝光、真实切线、实际视角、连续运动与真机温升尚未进入验证。

这是一项具体候选的首轮结果，既不证明全部低维路线成功，也不证明低维路线失败。

## 2. 当前源码与基线

起点 HEAD：`259a2116bb084534f9546dd44b5fae72c1b0696a`，工作区已有球库相机交互和连续调参等未提交修改。真实身份以 [source-before.json](../../output/render-lowdim-20261113/source-before.json) 为准；没有覆盖这些修改。

正常 R 配置及当前台呢主要公式与 11 月 12 日现状报告一致。独立核对补充了三点：

1. 两盏灯的 sampled E / unoccluded E **先分别加总，再做全局比值**，最后乘两灯总解析漫反射。不能逐灯各自归一化后相加。
2. 当前和历史 r2 的“关闭直接球影”只将 `if(shadowPossible)` 改为 `if(false)`，保留近 64 / 远 8 的采样分支。该消融没有同时把近档改成远档。
3. packed 球输入是 `(worldX, worldZ, max(R,height), .85×opacity×clamp(height/R,0,1))`；进入 shader 的高度不等同于直接读取下沉球心 Y。原型按 packed 输入消费。

主源：[MobileReferenceLighting.swift](../../QiuJi/Core/Scene/MobileReferenceLighting.swift)、[MobileTableRendering.swift](../../QiuJi/Core/Scene/MobileTableRendering.swift)。历史消融核对点：`RenderQualityV62Tests.testDaily...` 附近 direct-shadow-off 替换及 `output/render-system-audit-20261011/r2/` 保留源码。

坐标：世界米制 X–Z 水平、Y 上；本轮平面样本 Y=.8，正常球 packed 高度 R=.028575。灯尺寸由生产 Float 类型常量进入真实 Swift 生成器，再转 Double，保留该语义；不是把显示的小数直接当精确 Double 替换。部分边缘压力点可能落在实际床面之外，只作公式压力测试，不当作合法接收面覆盖证明。

## 3. 参考入口实际做了什么

[prepare_reference.py](../../scripts/research/cloth_lowdim_20261113/prepare_reference.py) 按唯一符号边界提取当前生产：

- Panel / Rig 与亮度校准；
- 采样 profile；
- `directShadowShader` 的 R 生成逻辑；
- 灯几何及解析矩形灯积分；
- 台呢 shader 核心。

随后实际执行提取的 Swift 生成器，输出 [generated-production-core.json](../../output/render-lowdim-20261113/native-reference/generated-production-core.json)，再将 SceneKit 世界坐标 / 法线 / 相机读取换成显式参数，导出 [reference.metal](../../output/render-lowdim-20261113/native-reference/reference.metal)。生成器保留来源 SHA 和转换列表，锚点不符会失败。

这里取出了实际生成的光照 core，**并未取得 SceneKit 最后编译的完整材质程序**。接触 AO、纹理采样、织物 emission 组合、内建 PBR、曝光 / 色调映射不在该入口；不能将 core 对拍称为整图一致。

[evaluate.swift](../../scripts/research/cloth_lowdim_20261113/evaluate.swift) 在本机 Apple M5 Pro 编译并执行 Metal，fastMath=false 用于数值核对。输出原采样 E0、采样有影 E、解析修正 E、S；保留 near/mask 诊断。

实际 smoke：空场与单球、中心全挡、远处无挡；参考函数封装前后输出逐位一致；候选关闭时逐位回原路径；可见方向矩为零时正确输出零。详见 [原生参考验收](../../output/render-lowdim-20261113/native-reference/validation.json) 和 [候选 smoke](../../output/render-lowdim-20261113/native-reference/moment-smoke.json)。

## 4. 候选：分组方向矩

把每盏灯原来的 8×4 个方向按固定网格分组，研究 K=1、2、4、8、16、32 组 / 灯。

定义 `a_j` 为灯辐射、距离、发光面余弦、面积和 gain 的标量权重，不含 RGB 灯色、不含接收法线余弦与 BRDF：

```text
M_g = Σ组内 (a_j × V_j × l_j)
MV  = Σ全部组 M_g
M0  = Σ全部方向 (a_j × l_j)

漫反射比值 = (n·MV) / (n·M0)  [保留原逐 RGB epsilon]
组高光 ≈ max(0,n·M_g) × BRDF(n,v,normalize(M_g),roughness)
S ≈ 各组高光之和
```

全挡组直接输出 0，避免 normalize(0)。只在灯矩形所有角点都位于接收法线正半球时使用候选；否则直接回退。远档仍使用原两灯 8 样本。K=32 / 灯为每个灯样本独立一组，作为退化一致性控制，不把它称作降维。

优点是消费端真的只需要 2K 次 BRDF。`M_g` 不依赖当前相机 / 法线 / 粗糙度，可以由球态生成后复用。缺点是组代表方向不能严格保留非线性高光，也会改变近档中没有实际球遮挡的基础高光。

本轮没有学习训练集，没有用测试集调整基底。当前是固定分组数值近似；将来如果拟合，仍需独立球局 / 相机留出集。

## 5. 真实材质参数，而非任意假设

[texture_samples.py](../../scripts/research/cloth_lowdim_20261113/texture_samples.py) 用实际 USD 材质绑定和默认 USDZ PNG：

- roughness 绑定 raw R，normal 绑定 raw RGB×2−1；没有平均 roughness 的 RGB。
- macOS SceneKit 实际导入测得两者 intensity=1，mappingChannel=0。
- 当前生产对两者使用相同 UV scale(2,2,1) 与 repeat。
- roughness 范围约 .537255～.992157，中位 .803922。
- 解码法线倾角中位 22.09°、P95 44.62°、最大 52.76°。

[paired.npy](../../output/render-lowdim-20261113/textures/paired.npy) 为 384 组同 texel 的法线 / 粗糙度，含极值和固定 seed 分层抽样，保留原像素坐标与源 SHA。

世界法线暂用显式床面基底 T=+X、B=+Z、N=+Y。**没有证明实际网格切线、UV 方向、mip / 双线性过滤及 SceneKit 最终法线完全如此。**这些数据界定了一层真实资源参数证据，仍不是实际屏幕样本。

原始 .3 / .5 粗糙度样本作为扩大范围的压力测试保留，不拿它们直接否决当前台呢材质。

## 6. 数值结果

最终矩阵：[moments-r5/results.json](../../output/render-lowdim-20261113/moments-r5/results.json)。12 组各 384 点，共 4,608 点：空场、单球、密集球架、散台、重叠影、边缘 / 高度 / 透明度，各配合独立压力参数和真实贴图配对参数。

CPU 与生产生成 Metal 的 E0 / sampled E / S 最大绝对误差约 3.6×10⁻⁶；near/far 逐点一致。K=32 在 CPU 端重建原 S 至浮点求和误差；GPU 消费也单独对拍通过。这证明参考移植和消费链在本轮输入上自洽，不证明最终画质。

### 半球反例

接收点 (.04,.8,0)、球心 (0,.828575,0)，法线朝 +X 倾斜：

| 倾角 | 原采样遮挡比值 | 无保护方向矩 | guard |
|---|---:|---:|---|
| 0° | .752033 | .752033 | 允许 |
| 40° | .893454 | .893454 | 允许 |
| 60° | .978741 | 1.045558 | 回退 |
| 80° | 1.000000 | 1.737040 | 回退 |

该反例说明不能把 max(0,n·l) 无条件移出积分。原始数值见 [horizon-counterexample.json](../../output/render-lowdim-20261113/diagnostics/horizon-counterexample.json)。

### 真实贴图配对范围

下表只统计真正使用候选的点，未用精确回退稀释误差。S 是光照 core 的红通道标量；亮区相对误差使用参考 S≥.001。这里的 .001 只是指标分母过滤，不是画质接受阈值。

| 场景 | 使用候选 / 384 | 近档 guard 回退数 | K4 高光相对误差 P95 | K8 高光相对误差 P95 | K8 高光绝对误差最大 |
|---|---:|---:|---:|---:|---:|
| 单球 | 246 | 42 | 10.39% | 2.71% | .000784 |
| 球架 | 258 | 50 | 10.00% | 2.64% | .001018 |
| 散台 | 270 | 48 | 12.83% | 2.91% | .001823 |
| 重叠影 | 254 | 42 | 10.82% | 2.41% | .002330 |
| 边缘 / 高度 / 透明度 | 252 | 52 | 11.45% | 2.67% | .001444 |

K8 的结果比 K4 值得继续。表中百分比不是最终画面差异；实际 S 还乘 .35 并参与完整材质。报告另存仅候选改变项的线性 proxy，其 K8 最大绝对误差约 .000815；proxy 不含完整材质和显示变换，不作像素验收。

空场全部走原远档，仅证明回退，未作为候选成功样本。近档且 V=1 的样本另列 `unblocked_near_specular_error`，用于暴露基础高光变化。

[截面诊断图](../../output/render-lowdim-20261113/diagnostics/cross-section.png) 显示参考 / K4 / K8 的 S 曲线及近远分支边界。它是数学图，不是 App 截图；曲线差异也提示需验证分支切换的可见跳变。

## 7. 原生 GPU 消费结果

本机 Apple M5 Pro；fastMath=false。每个配置 2 次预热 / pipeline，7 组 A/B/B/A；记录 GPU command span 原值。输入点重复 64 份以扩大工作量，这不是一帧屏幕采样。各配置独立短跑，不能跨配置比较绝对值来推定 K 的严格排名。

**这些测试只测冻结 FP32 moment buffer 的消费，不含生成、纹理采样 / 插值、FP16、空间缓存命中、动态同步、SceneKit 或屏幕呈现。**

真实贴图配对输入，K8 / 灯：

| 输入组织 | 场景 | 点数 | 参考中位 ms | 候选中位 ms | 配置内变化 |
|---|---|---:|---:|---:|---:|
| 近远 / guard 混合，内核分支回退 | 单球 | 24576 | .3996 | .5675 | +42.0% |
| 同上 | 散台 | 24576 | .3962 | .5969 | +50.7% |
| 仅选适用点，全部消费候选 | 单球 | 15744 | .2211 | .0630 | −71.5% |
| 同上 | 散台 | 17280 | .3598 | .0891 | −75.2% |

这支持“廉价消费的机制存在”，同时否定“在当前混合内核里直接替换就自然变快”。分支、并发、寄存器和内存行为都可能有关，本轮没有 GPU counters 证据，**不指定已证实根因**。后续应保留相同有效输入，通过分区 / 分块等方案验证总成本，而不是只保留有利点并宣称整页收益。

同一候选的 GPU 输出与 CPU 消费对拍；disabled 回退与原参考逐位相同。完整时间序列与 buffer 容量见 [混合输入](../../output/render-lowdim-20261113/gpu-texture-r1/results.json)、[适用点单列](../../output/render-lowdim-20261113/gpu-texture-eligible-r1/results.json)。

## 8. 存储并非“组少就一定更小”

若用 RGBA16F 存每个方向矩，256×128：

| 每灯 K | 两灯组数 | 仅组矩单份 | 对照 |
|---|---:|---:|---|
| 4 | 8 | 2 MiB | 小于原 64×FP16 可见度的 4 MiB |
| 8 | 16 | 4 MiB | 与原 64 通道基础量相同，但消费 BRDF 更少 |
| 16 | 32 | 8 MiB | 更大 |
| 32 | 64 | 16 MiB | 退化控制，不是低维方案 |

还需 M0 / MV、有效区、在途副本等；MV 可由组求和，也可冗余保存换计算，均须计成本。本轮 buffer 用 FP32 和显式 MV/M0，只是数值与消费实验，不把上表估算当实际字段驻留。K8 三份组矩已 12 MiB，距离原新增 GPU≤16 MiB 护栏余量有限。

## 9. 下一轮的具体选择

继续 K8 研究候选，按以下顺序取得第一份完整视觉证据：

1. 在真实 SceneKit 台呢上用冻结球态接入候选结果，使用真实切线 / 法线 / 粗糙度及原输出链，拍摄参考、候选和差异；重点看低位、近景、无影高光与 near/far 切换。
2. 用同一数据验证混合回退与分区消费，计入分区构建 / 额外 dispatch / 读写成本。若净成本仍退步，结束这版执行组织。
3. K8 若视觉不够，先看分组高阶信息或基底修正是否能便宜消费；保留 64 通道可见度为更保守对照。不能简单用大幅提高 K 掩盖收益消失。
4. 点值和冻结画面成立后，再做空间分辨率 / FP16 / 插值、真实球轨迹和同帧版本。未到这个阶段，不先迁移整个宿主。

原手稿中最终 P0/P1 还要求完整页面基线、最终材质 / 连续片段等，本轮未将这些未完成项标绿。P2–P4 的实际120、20分钟温升、生命周期、进入速度与能耗验收均未完成。

## 10. 复现与产物

运行时依赖沿用已有 `tools/shot_reconstruction/.venv/bin/python`（NumPy / Pillow），未新增 App / SPM 依赖。生成器本身可用系统 Python + Xcode。完整命令见 [原型 README](../../scripts/research/cloth_lowdim_20261113/README.md)。

输出目录 `output/render-lowdim-20261113/`：

- `native-reference/`：真实 Swift 生成输出、MSL、可执行程序、smoke 与来源；
- `textures/`：USD 绑定、SceneKit 导入属性、同位置贴图样本与来源；
- `moments-r5/`：最终数值矩阵；r2–r4 为较早压力矩阵 / 指标迭代，保留；
- `gpu-texture-r1/`、`gpu-texture-eligible-r1/`：最终本机消费实验；
- `diagnostics/`：曲线与半球反例；
- `source-before.json`、`source-after.json`、`validation.json`：工作区与交付校验。

最初空场夹具赋空列表触发 NumPy shape 错误，修为明确空场初始化；最初提取器 Swift 闭合括号错误已修复并保留 agent 日志。它们是原型准备错误，不将失败运行计为有效实验。本轮没有改变参考、放宽画质标准或通过删除反例让候选“通过”。

## 11. 前一轮状态留档

2026-11-12 3D 渲染现状盘点：已按当前生产调用链、最终 shader 生成、帧调度、资源及历史证据完成[详细核对文档](../../docs/research/20261112-3D渲染现状与既有优化方案核对.md)。区分正常 R、诊断 A/S/RS 与尚未实施的四层空间遮挡方案；核实 8 个直接场景入口均传活动状态、前台热缓存保留、2880 面默认球资源身份。仅新增文档与核对证据，未改生产代码或运行新的性能测试；不宣称持续 120 FPS / 温升达标。下一步结合该现状确定本轮优化方向。
