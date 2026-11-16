# 临时俯视：具体 shader、灯光排列与缓存复用

2026-11-15，北京时间 16:27 起。延续用户“先定位、不要改代码”的要求：正式 App/工程/依赖源码不改，使用前轮原封保存的模拟器诊断 App，以外部 LLDB 读取实际调用参数。该二进制 SHA 始终为 `241b9a28b93b6aba004fca90c5aa39a22dbe82718318c88edabe61a33c9d99aa`。

## 结论及未闭环部分

**已定位一个具体的 shader 变体来源：临时俯视重建窗口中，SceneKit 对同类灯光组合生成了不同顺序的着色代码，阴影纹理参数编号也随之变化。这些是真正不同的 Metal library 哈希；缓存缺少相应记录时，同步编译发生，已有缓存时复用。**

这不是“源码看起来一样，所以只是猜测缓存”的推断。证据包含完整 Metal 输入源码、编译选项、调用栈、Metal 实际传入的 256 位 library 哈希，以及该哈希在原缓存和新编译缓存中的精确字节位置。

**未闭环：原 iPhone 二进制为什么比独立重建版更容易慢。**两包旧 trace 只有调用栈，没有逐请求 shader/选项/hash，也没有分别归属两包的缓存快照。当前取到的是同一模拟器二进制的运行时证据，不能将其冒充原/新真机包逐键对照。尚未证明哪个链接地址、依赖优化、安装 UUID 或最近提交改变了排列分布/缓存覆盖。

## 1. 实际生成的变化，不是业务源码变更

6 次相同页面、相同初始球形的临时俯视中，实际捕到以下两个版本（只摘排列部分）：

```metal
// 一个版本
_lightingContribution.add_directional(scn_lights[0]);
_lightingContribution.add_area_rectangle(scn_lights[1], u_areaLightBakedDataTexture);
_lightingContribution.add_spot(scn_lights[2], u_shadowTexture2, u_shadowKernel, 8);
_lightingContribution.add_area_rectangle(scn_lights[3], u_areaLightBakedDataTexture);

// 另一个版本
_lightingContribution.add_area_rectangle(scn_lights[0], u_areaLightBakedDataTexture);
_lightingContribution.add_area_rectangle(scn_lights[1], u_areaLightBakedDataTexture);
_lightingContribution.add_directional(scn_lights[2]);
_lightingContribution.add_spot(scn_lights[3], u_shadowTexture3, u_shadowKernel, 8);
```

同族 shader 还改变函数形参中的 `u_shadowTexture2/3` 名字。其余源码逐字核对：只移除这些灯光贡献行并统一阴影纹理编号，就归为同一源码组；每组预处理宏和其他实际编译选项一致。这个归一化仅用于定位差异，不声称换序后浮点计算完全等价，也不拿归一化值冒充 Metal 真正的缓存键。

四个成功的归属采集运行中，5 个 shader 族各观察到 7、7、7、7、8 个不同灯光排列源码版本，**每族只有一组编译选项**。灯光种类数量均为 1 方向光、2 矩形区域光、1 聚光灯。

## 2. 具体 shader 族

完整源码与 SHA 在各 run 的 `evidence/shader-capture/*.metal`，实际宏/选项与 pipeline descriptor 在 `requests.jsonl`，整理结果 `shader-analysis.json`。

| shader 族 | 示例源码 SHA 前缀 | 源码字节 | 与产品源码的对应证据 |
|---|---|---:|---|
| TaiNi 台呢接触遮蔽/纤维 | `0d115b09d15a` | 177775 | `QiuJiContactUniforms`、`bakedRailAO`、`clothFiber`；`MobileTableRendering.swift` 168–231 的目标明确为 `material.name == "TaiNi"` |
| 通用 PBR，无自定义表面代码、无 UV0 输出 | `fb3af1ca785d` | 151042 | 生成程序与宏已保存；可由多个材质共用，不捏造唯一物体归属 |
| 通用 PBR，带 diffuse UV0 | `167bac431935` | 151148 | 与上一类的源码差异为 texcoord0 声明、顶点输出和 diffuseTexcoord 赋值；材质唯一归属未抓取 |
| White 材质袋口体积遮蔽/库边瞄准点 | `91458cdcca7f` | 155500 | `pocketVolume.sample`、`sightWorld`；`MobileTableRendering.swift` 329–351 明确作用于 White，颜色逻辑见 `TableAppearance.swift` 48–65 |
| 球杆淡出 | `ec885c770d5c` | 151108 | `cueFadeOpacity` 与乘 alpha 语句，对应 `CueStick.swift` 569–573 |

这是**模拟器实际分支**的 shader 集合。真机 C1 等能力路径可能改变台呢程序，不能说 iPhone 的五类逐字相同；此前原慢包旧材质仍慢，也说明不能只归因最近台呢配方。

## 3. 编译与复用：同一精确输入的对照

以完整源码 SHA + 解析后的宏字典 + 实际选项 description 的非宏字段构成诊断输入指纹。去掉选项对象地址与字典打印顺序，保留有效设置。该指纹是我们用于比较的输入标识，尚不是 Metal 私有哈希。

| 运行 | 私有 library/function 缓存 | UI 开关 | library API 调用 | pipeline 创建入口 | 编译调度回调命中 | 整轮结果 |
|---|---|---:|---:|---:|---:|---|
| `5893d088f6464320bdf590fdb641c738` | 暂移 | 6 | 52 | 161 | 477 | 通过，缓存恢复 |
| `155dcb442b714e9b9b029a3c55532ec3` | 原缓存 | 6 | 47 | 126 | 0 | 通过，缓存恢复 |

477 是断点回调数，包括两个 `buildRequest` 重载和异步 block；**不是 477 次独立编译，不是耗时**。两轮灯光排列集合不同，因此也不能用 52/47 或 161/126 算性能提升。

关键是两轮有 **36 个完整源码及选项均相同的输入**：空缓存轮在 source 编译栈中进入调度器，原缓存轮没有进入。比如 `6d215c65001b…` 台呢及同组其他四类，在空缓存轮第 6 次打开出现，在原缓存轮第 1 次打开出现，输入一致，编译行为不同。

空缓存轮第 1、2、4、6 次遇到新排列时，各出现 5 类 shader 的 source 编译请求；第 3 次只新增球杆那一类，第 5 次没有新的 library 编译。这与“已经开过，但后面仍可能慢”的模式相符：一次打开不一定覆盖所有排列。这里只统计 stack 中明确含 `MTLLibraryBuilder.newLibraryWithSource` 的同步调度调用，并按同线程最新 library 入口关联；不把异步 worker 的旧线程状态强行关联 shader，也不把纯 pipeline 编译归给最后一次 library。

所有调试器运行都暂停过进程、读取过对象，**不能作为首帧性能数据**。耗时依据仍是上一轮未附加调试器的触发式采样和缓存对照，见 RENDER-WAIT-STACKS.md。

## 4. Metal 实际 library 哈希与磁盘缓存逐字匹配

运行 `fd327383e7794060b86aa7194a99421b`，同一包，暂移私有 library/function 缓存，3 次开关，正常结束。断点放在 `MTLLibraryBuilder::newLibraryWithRequestDataAndHash`，候选参数内存实际读取后再验证，而不是仅凭 C++ 名字假定参数寄存器。

- 39 次直接函数入口，39 个不同 256 位值；x2 所指 32 字节全部在干预前保留的 `libraries.list` 中精确找到。
- 39 个值也全部在该轮新生成的 `libraries.list` 中精确找到。
- x0/x1/x3/x4 候选没有这种匹配。因此将 x2 的值认定为本调用使用且实际落入 library 索引的哈希，有独立磁盘证据。
- 额外的 39 次同名 block 命中分开保留，不冒充直接函数入口。

台呢的两个真实例子：

| 灯光顺序 | 源码 SHA 前缀 | 实际 Metal library hash | 原索引字节偏移 | 新索引字节偏移 |
|---|---|---|---:|---:|
| 方向、区域、聚光、区域 | `0d115b09d15a` | `e386e10604e560bc1c82a60668b7aa01ea1d531a2a28ebbee8b8c8d8c199896f` | 21620 | 2972 |
| 区域、聚光、区域、方向 | `4bc6cd0f0f60` | `529184052161a09b8380f22ce9f35754218a6f4725124234e7e882c7e39b2d04` | 21452 | 3252 |

39 个匹配见该 run 的 `actual-cache-key-matches.json`；新索引与文件摘要在 `generated-cache-index/`；原索引来自前轮已经保留的 `products/simulator-render-repro/original-private-metal-cache/`。这些键在本轮 LLDB 介入前已存在于原缓存，因此不是这轮调试器修改 shader 源码制造出的假键。但调试器可能影响分配时序和排列出现频率，不能用调试轮估计自然概率。

此处锁定的是 **library 的缓存哈希**，并未声称已经解出全部 GPU pipeline/function 内部键。另一次灯光跟踪轮在进入临时俯视前出现过 pipeline 编译回调，而临时俯视阶段无编译；library 可复用不等于所有 pipeline 状态永久不会编译。

## 5. 灯光复制输入稳定，生成程序排列变化

运行 `91758fd5a6da40eaa23636ec1f40ebed` 捕获 `SCNLight.copyWithZone`，仅以调用栈包含 `makeTemporaryTopDownRenderScene` 的记录分析。6 次都复制同样 5 个源对象，顺序固定：

`ambient → spot → directional → area → area`

对应源地址每轮也相同：`0x10b481130 / 0x10b499200 / 0x10b496780 / 0x10b3f4aa0 / 0x10b3f4fb0`。地址只用于这一进程内的对象归属，不跨运行比较。

而请求到 Metal 的新 shader 排列为：第 1 次 `聚光/方向/区域/区域`，第 2 次 `区域/聚光/区域/方向`，第 4 次 `方向/聚光/区域/区域`，第 5 次 `方向/区域/区域/聚光`。第 3/6 次没有新的 library API 调用，不能误记为没有灯光。原始及提取证据见 `light-copy-order.json`。

因此不是业务每次改变灯光数组输入顺序；顺序差异出现在复制灯光并新建渲染场景后的 SceneKit 生成阶段。实际私有排序算法、是否依据地址/内部标识及其与两个真机二进制布局的联系仍未知，不能把“地址排序”写成事实。

现有代码每次关闭释放 overlay，下次新建 SCNView/镜像场景；镜像时 `copy.light = source.light?.copy()`。该行 git blame 为 2026-10-05，区域光创建为 9-16、聚光设置为 9-14，均非这几天新加。只能说现有生命周期给变体重建提供条件，不能据此指定近期回归提交。

## 采集返工与边界

- 首个单条 shader 烟测 `6670a45e9d9945e083a1dfb93f82bc64` 成功读取真实源码，是 PrefilteredReflection 初始化 compute shader；不把它误认成临时俯视慢 shader。
- 首个完整原缓存轮 `5feec96039264540a67c18310d3cc242` 完成6次开关和48条源码采集，但 LLDB 截住 XCTest 的 SIGTERM，测试收尾失败。保留失败，不记整轮通过。后续显式不在 SIGTERM 停顿，cold/warm-r2/hash/灯光轮均正常结束。
- 第一轮灯光返回断点在 callback 返回 false 时并未自动销毁，产生 source=null 的过期回调；保留原始噪声，不计作新复制。source 非空返回与入口关联，主要顺序结论只使用30个真实复制入口。缓存的首次 intensity 可能早于灯光初始化完成，因此全部 intensity 字段排除。后续脚本显式删除返回断点并只捕临时场景复制；`60ba7d43ee9c4e5fbba0e0233695df4a` 两次开关通过，10 个复制入口/10 个非空返回、0 个空关联，验证修订有效。
- 同一 App 的 shader 输入与缓存复用机制已经取得证据；原真机包/重建包的逐请求差异仍缺两包对应输入和缓存键快照。保存的 iOS 真机二进制不能直接在模拟器运行；不通过“模拟器新构建”冒充原包。
- 源码/宏/descriptor 原件、真实断点位置数、命令、各 run 退出状态、安装 SHA、缓存恢复摘要均保留。没有性能修复，没有移除 geometry 独立复制、改变灯光或降低画质。


## 最终核验与下一步边界

7个本轮run都核过实际安装SHA、逐次JSON、未携带人工smoke参数和缓存恢复；其中warm首轮收尾失败原样保留，另外6轮整体通过。独立读取当前App缓存与调试器介入前原件比较，library/function及frontend module两目录共7文件SHA全部相同，见 `output/topdown-latency-device-20261115/shader-capture-final-cache-check.json`。冷/暖36个相同输入的逐项映射另存 `shader-input-comparison.json`。正式QiuJi/工程/CuePhysWeChat的git diff为空。

library请求以App PID、线程、调用栈及临时俯视marker时间归属；当前没有将每一条请求进一步绑定到某个SCNRenderer实例地址，因此不声称已区分每条请求来自主3D还是俯视renderer。它们在同一打开窗口内的实际源码、编译行为与缓存键差异均有原件，下一轮如需renderer实例归属应另加只读对象跟踪。

原/新真机包的最终差异判断仍需要两包运行时输入与cache记录；目前最有证据的解释路径是“灯光排列变体与已有缓存覆盖不同”，不是已证明某个Swift优化设置或构建缓存坏了。不能通过模拟器上的另一次重建替代原件证据。只保留诊断与分析，没有进行修复。

收尾：上述7个本轮受管work目录均已complete/reclaimed，失败退出码和evidence保留；原复现App与真机两包原件未动。借用iPad已关机并归还租约，未删设备或用户数据。


### 续查：SceneKit内部字典枚举已定位

当前框架的全局灯顺序来自以C3DNode地址为键、空callbacks的CFDictionary枚举。实际6轮源复制/内部注册顺序一致，却有6种全局排列，字典回调→内部列表逐地址相符，21次新shader请求与该排列一致并进入source编译。新证据将此前“私有排列依据未知”收窄到具体容器和消费链；原/重建真机包的概率差仍待直接记录。复制返回断点身份字段发现延后错关联，后续以实际C3DLightingSystemAdd为准，旧返回字段不作身份结论。详见[灯光字典与根因边界](LIGHT-DICTIONARY-ROOT-CAUSE.md)。
