# SceneKit 灯光排列变化：内部字典与编译等待

2026-11-15。用户要求继续定位、不改正式代码。本轮仅修改外部诊断脚本、读取系统框架和运行已封存的诊断 App。模拟器二进制仍为 `241b9a28b93b6aba004fca90c5aa39a22dbe82718318c88edabe61a33c9d99aa`，没有重新构建 App。

## 已经定位的原因

**当前模拟器 SceneKit 的全局灯光程序顺序来自以内部灯光节点地址为键的 CFDictionary 枚举。每次临时俯视重建会生成新节点；即使灯光类型、源对象和加入顺序完全一致，字典枚举得到的次序仍会变化。SceneKit 把这一顺序直接用于灯光 program hash 数组和 shader 生成，形成不同缓存输入。**

这里的“排列”不是已证实的按地址大小排序，也不是根据亮度/距离排序。实际路径是无序字典的枚举；键值、插入/冲突状态会影响其内部布局。不能把“源 SCNLight 地址”与“作为字典键的 C3DNode 地址”混为一谈。

本轮独立证明：复制输入顺序 → 实际内部节点注册 → 字典回调枚举 → 全局灯光列表 → 实际 shader 程序 → source 编译请求。原包卡顿现场的编译等待栈与此机制相符，但**原 iPhone 包为何比独立重建包更容易命中这个条件仍未完成直接对照**。现有真机旧 trace 没有 shader 输入/内部节点键；iOS 原二进制不能直接运行在模拟器。不能将模拟器结果冒充两份真机包的逐请求证据。

## 1. 当前系统框架的具体实现

读取安装 Runtime 内实际 SceneKit Mach-O，不猜私有 API 或字段。运行时校验 UUID `745BE90A-D181-3FAE-AA9C-63ACA13CF1AD` 后才读取布局；本结论限定此 iOS 26.3.1 arm64 Simulator 框架。

静态原件、SHA、符号和反汇编：`output/topdown-latency-device-20261115/scenekit-light-order/`。

| 实际函数 | 可核对的行为 |
|---|---|
| `C3DLightingSystemCreate` | 在 `0x147750–0x147760` 以 capacity=0、key/value callbacks=NULL 创建 CFDictionary，保存于 lightingSystem+0x20 |
| `C3DLightingSystemAdd` | x1 是 C3DNode；在 `0x147a60–0x147a6c` 以该节点地址为 key、编码后的类型/数组索引为 value 写入字典 |
| 同一 Add 函数 | 全局灯变化时清空 global count/hash 数组，在 `0x147a8c–0x147a9c` 对该字典调用 `CFDictionaryApplyFunction` |
| `__appendGlobalLight` | 过滤非全局灯，按回调到达顺序追加 encoded index 和 `C3DLightGetProgramHashCode`；没有灯光类型重排步骤 |
| `C3DLightingSystemEnumerateGlobalLights` | 按已生成的 encoded index 顺序取得 node/light 数组 |
| `C3DLightingSystemGetGlobalLightHashCodeForCaching` 的 block | 按原顺序比较/复制 32 字节 program hash 数组；顺序不同即数组不同 |

CFDictionary 空 key callback 的指针键语义也可见 [Apple 公开 CFDictionary.h](https://github.com/apple-oss-distributions/CF/blob/main/CFDictionary.h)。公开文档只是 API 语义依据；具体 SceneKit 调用、内存布局及运行结果以上述当前系统原件为准，未将旧开源实现当作当前 iOS 源码。

## 2. 稳定复现：6 次相同入口，6 种内部全局排列

成功冷缓存轮 `9ec7411c22104c72ab985037e40cf0bc`：暂移 App 私有 library/function 缓存；frontend/global 系统缓存未动；完成 6 次开关，1 个 UI selector 实际通过，退出码 0，安装 SHA 一致，原缓存逐文件恢复。

30 次 `SCNLight.copyWithZone` 入口对应同样的 5 个源对象。30 次实际 `C3DLightingSystemAdd` 都来自 `makeTemporaryTopDownRenderScene → synchronizeTemporaryTopDownScene → C3DTransactionFlush` 调用栈，每组注册顺序完全相同：

`ambient → spot → directional → area → area`

但是实际全局列表如下。ambient 不进入这四个全局灯的 shader 列表。

| 打开次数 | 内部全局灯顺序 | 实际新 library 请求 | 其中进入 source 编译的不同源码数 |
|---:|---|---:|---:|
| 1 | 聚光、方向、区域、区域 | 0 | 0 |
| 2 | 聚光、区域、方向、区域 | 1 | 1 |
| 3 | 方向、区域、区域、聚光 | 5 | 5 |
| 4 | 聚光、区域、区域、方向 | 5 | 5 |
| 5 | 方向、区域、聚光、区域 | 5 | 5 |
| 6 | 区域、方向、区域、聚光 | 5 | 5 |

六组内部列表均与同一 lightingSystem 最后一批字典枚举回调完全一致（过滤 ambient 后逐个 node 地址一致）。发生新 library 请求的五次里，21 条 shader 的灯光调用次序全部与各自内部列表一致。

原始材料：该 run 的 `evidence/shader-capture/requests.jsonl`、`*.metal`、`samples/`；逐轮机器核对为 `evidence/light-dictionary-analysis.json`。诊断脚本为 `scripts/research/topdown_latency_20261115/analyze_light_dictionary.py`。

第 1 次没有新 library 请求不代表没有灯光，也不代表空缓存干预失效：进入临时俯视前，主 3D 场景已经编译过一些同样的排列。**同一次启动里，前面快、后面换到新排列才编译**，已在本轮观察到。此轮进程总计 52 次 library API、465 次编译调度回调；465 含重载/worker，不能当作独立编译次数或耗时。

## 3. 与原包慢的关系及证据强度

已建立的机制链：

```
临时俯视重新创建内部灯光节点
  → 新的指针键进入无序字典
  → 全局灯光枚举排列变化
  → 有序 program hash / 生成 shader 变化
  → 对应缓存不存在时进入同步编译
  → render 线程等编译，主线程又等 renderer 锁
```

最后两步不是只靠本轮调试器推断：前轮同一模拟器二进制在私有缓存暂移后复现长帧，恢复缓存后消失，已取得 12 份长帧同期编译/锁等待栈；原 iPhone 慢包也抓到相同调用链。详见 `RENDER-WAIT-STACKS.md`。前轮 cold/warm 有 36 个完全相同的源码+编译选项输入，冷轮进入编译、暖轮不进入；39 个真实 Metal library hash 已与缓存磁盘索引匹配，见 `SHADER-CACHE-ATTRIBUTION.md`。

**这证明了原包所表现等待的一条具体可复现机制，并解释了相同业务源码在不同运行中有不同快慢；还不能证明原/重建两包的概率差完全由该机制造成。**缺少两份真机包在同一受控缓存条件下的节点、program hash、Metal key 记录。构建引起的内存分配变化、既有缓存覆盖差异仍是待区分因素；不宣称增量构建损坏、UUID 改变缓存键、微信优化差异致慢或某次近期提交是根因。

## 4. 诊断边界与返工

- 所有 LLDB 轮都会暂停、求值并改变分配时序，因此本轮证明输入/顺序/缓存行为，不提供自然出现频率、点击至显示耗时或两包性能倍率。并行其他工作也不影响这里的身份/源码核对，但进一步禁止把本轮当耗时基准。
- `d015414e75bf4a87b8e0cdf4eb57d11e` 首轮 3 次 UI 开关成功，实际枚举和 shader 顺序证据保留。其复制返回地址跟踪出现一条延后回调与下一次 copy 错关联；返回对象地址字段不用于本报告。后续改在真实 C3DLightingSystemAdd 捕获内部 node/light/type，不再使用 copy 返回断点。
- `88732aee141e4e0fa95b5cd166376003` 的临时字典重放探针在释放缓冲区表达式处，因 LLDB 未知 free 返回类型被拒绝。此轮诊断失败，原件保留；已明确函数签名，r2 成功。本失败不归因 App，也不计作有效冷缓存对照。
- 临时字典重放只创建独立字典，不写原 SceneKit 字典/节点。相同 keys 换插入顺序可能改变冲突布局；不能据此宣称生产插入顺序有变化。生产实际注册顺序已逐轮采集且相同。

## 5. 已将排列变化精确重算出来

进一步读取同 Runtime 的 CoreFoundation 原件（身份/哈希/表见 `scenekit-light-order/corefoundation-identity.json`），定位到：

- `__CFDictionaryCreateGeneric` 以 `0x2001` flags 创建 CFBasicHash；该位型选线性探测。
- `__CFBasicHashFindBucket_Linear` 在 hash callback 为空时直接保留指针整数，以 `key % bucketCount` 定位起始槽，冲突后递增槽并回绕。
- 实际 bucketSizes 表开头为 `0,3,7,13…`，capacity 表为 `0,3,6,11…`。本场景固定五个节点：最初 3 槽，第 4 个键时扩至 7 槽，按旧槽遍历重插入，再插入新键。
- 枚举遍历槽位，不能用节点插入顺序或节点地址数值排序代替。

使用**实际捕到的节点地址和注册顺序**，用独立 Python 重算槽位：6 次真实 SceneKit 字典枚举 **6/6 完全一致**；同轮独立临时字典正/反插入共 12 次，**12/12 完全一致**。另一个进程 `d5e08869cc734292a405e2b12f3def8b` 在后续探针失败前已完整记录一组注册/枚举，该组 **1/1 也与数值模型一致**；这条局部只读证据不将该失败轮追认为整轮通过。

脚本 `scripts/research/topdown_latency_20261115/replay_light_pointer_hash.py`；各 run 的 `evidence/pointer-hash-replay.json` 保留预测与实际数组。按实际注册时间分组，避免同一进程释放后地址复用把两次场景误合并。

这使原因进一步具体化：**新 C3DNode 地址改变哈希槽与冲突布局，进而改变全局灯顺序。**无需假定灯光强度、距离或业务数组变化，也未发现必须依靠随机种子才能解释这些记录。模型只覆盖这次五键、无删除的创建过程，不冒称完整复现 CFDictionary 的全部行为。

附加暖缓存重放 `d5e08869…` 因 LLDB 局部变量名 `d2` 与系统符号撞名被拒绝，保留失败及缓存恢复结果；修订使用任务唯一前缀变量。模拟器生命周期曾因其他 Mac 原生构建运行而拒绝启动，未绕过共享保护、未终止其他工作。

## 6. 本轮成功暖/冷数据的逐输入复核与收尾

用两份**成功**采集数据比较：暖缓存 `d015414e…`（3次打开）和冷缓存 `9ec7411…`（6次打开）共有 **32 个完全相同的完整源码+编译选项输入**。这32个输入在冷轮均有实际 source 编译调度栈，在暖轮均无。暖轮总共3个编译回调属于临时俯视前的 pipeline 阶段，不能写成整个进程绝不编译；临时俯视的10个新 library API请求没有source编译。

比较原件：`output/topdown-latency-device-20261115/scenekit-light-order/cold-warm-input-comparison.json`。两轮诊断断点集合不同，不能比较耗时或将此组说成完全同探针的单变量性能实验；这里只逐输入核对复用，单变量耗时证据沿用前轮缓存移出/恢复实验。

额外“相同keys三次新字典”扩展未取得成功整轮，且所需哈希机制已由6+12条精确数值复演闭合，故不继续扩大实验。默认采集脚本恢复到9ec7411成功轮的原件（SHA `94d243d77bf2a0ad570f7baec142608753008d3f28278ae1c29abf2bbbfa989a`），不遗留未经实跑的扩展为默认。

四轮临时work均已通过生命周期complete回收，成功/失败原始证据均保留。归还后独立核对 App 私有原缓存7个文件全部逐字相同（`scenekit-light-order/final-cache-check.json`）。本轮已关机并释放租约；最终盘点时设备已由另一个任务 `shot-simulation-v9-20261115` 于17:14接手启动，未再干预其设备/缓存。未改全局缓存，未处理其他任务的构建/设备。工作区存在其他并行任务的正式源码修改；本调查只使用冻结二进制，未改动或回退那些文件。
