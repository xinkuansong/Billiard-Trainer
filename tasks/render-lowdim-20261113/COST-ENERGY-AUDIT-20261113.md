# 分离角与走位：代码计算量、CPU归属与能耗模型

2026-11-13。基于当前生产调用链和已有Run3约47秒操作段，未启动新的手机录制。只做分析，不修改生产实现。

## 结论先行

优先方向应由“只盯台呢遮挡”扩展为两条：CPU端减少无变化的UI/场景维护与提交；GPU端减少台呢大面积基础光照/BRDF重复计算。当前证据支持优化优先级，不足以产生经过校准的整机能耗饼图。下面给出实际CPU归属、GPU工作量和可复算的能耗敏感性模型，避免把未知当成不分析的理由。

本次纠错：前一轮回复及PHONE-HEAT记录把正常球反射描述成64采样不准确。FreePlayView配置R，RoomReflectionProbe.install把原积分替换为预过滤反射+响应LUT；仅资源准备失败才回退64采样。不得用基线生成字符串替代最终安装路径。

## 1. CPU按调用链分账

原始XML中PID45483、31≤t<78秒、Running样本15038个、每个1ms，总15.038 CPU秒（跨核累计）。每个样本从叶子向根查找最近已知功能域；Swift/ObjC/内存/系统调用费用归到其最近功能调用者；main、UIApplicationMain和通用thunk不作为业务归属。每个样本仅计一次。此为可审计的启发式归属，不是逐业务功能精确计时。FramePacing单列，不能把它全部认定为产品开销或全部认定为采集开销。

| 功能域 | CPU秒 | 占采样CPU | E核秒 | P核秒 |
|---|---:|---:|---:|---:|
| UI更新与合成CPU端 | 4.714 | 31.35% | 2.907 | 1.807 |
| Metal与GPU驱动CPU端 | 3.527 | 23.45% | 3.192 | 0.335 |
| SceneKit | 3.525 | 23.44% | 3.278 | 0.247 |
| App未解析业务 | 1.347 | 8.96% | 0.851 | 0.496 |
| 系统运行时/未归属 | 1.140 | 7.58% | 1.046 | 0.094 |
| FramePacing采集相关 | 0.482 | 3.21% | 0.462 | 0.020 |
| 音频 | 0.303 | 2.01% | 0.303 | 0.000 |

UI+SceneKit+Metal提交合计78.24%，是CPU工作的主要已识别去向。中途初稿81.45%包含FramePacing，最终已单列，避免把测量相关路径算入产品优化收益。不是GPU硬件占用，也不是整机发热78%。

具体可识别栈：`IOGPUMetalCommandQueue _submitCommandBuffers:count:`最近归属累计1.314 CPU秒，占8.74%；`AG::Graph::UpdateStack::update()`约0.374秒，占2.49%；二者已包含在上表，不能再相加。IOGPUResourceCreate约0.196秒，但不据函数名断言资源泄漏或每帧重建全部资源。

App业务地址未充分符号化。采集UUID为7C384C7A-E75E-302F-A8A4-1242EDBDA8B7；当前默认DerivedData二进制UUID不同，拒绝拿它强行解析。因此8.96%不能直接命名为物理；物理也可能进入其他库路径，不能据此给出严格上限。

## 2. 各环节的代码工作量

| 环节 | 频率与规模 | 生产依据 | 成本判断 |
|---|---|---|---|
| 输入/预测 | 连续拖动预览最多约15次求解启动/秒，一次在途、合并最新意图；离散20ms去抖/普通交互0.5s去抖 | PositionPlayViewModel:1770、1850、288、3897 | 调参时可能明显，击球播放期间recompute提前返回；不是每帧重算整杆 |
| 物理求解 | 事件搜索含球对N(N−1)/2，另有库边/袋口/空间接触及局部积分；不能仅以球对数估完整代价 | EventDrivenEngine:1143、1232；PositionPlayShotSolver | 普通分离角摆球上限2目标球+母球，球对最多3；开球分支另算，不能把全页永久当两球 |
| 播放/旋转 | 每个有轨迹球每显示帧一次状态查询+姿态更新，帧表分支二分O(log K)，空间记录查询另有实现 | TrajectoryPlayback:387、533、692；PositionPlayViewModel:2368 | 播放复用已有recorder，不重新求解整杆 |
| SwiftUI/界面 | 输入与Published变更触发；近景HUD可见时另有60Hz TimelineView，不能因主SCNView休眠就认定HUD也休眠 | BTAimCloseupHUD:198–219；FreePlayView:813 | 已有CPU数据证实UI/合成域重要，但未证明该HUD占31%；本次是否展示HUD未记录 |
| 主帧循环 | 活动时按所选60Hz执行viewport、临时俯视分支、活动性、相机、注释更新；多个函数内有早退/脏检查 | AngleSceneView:1382 | 可优化不变状态维护；不能把函数被调用等同于全部重建 |
| 动画状态扫描 | didRender逐帧检查root及子节点actions/animationKeys，遇到首个活动节点早停；最坏O(节点数) | AngleSceneView:2413 | 明确可审计的重复维护点，未单独取得其耗时 |
| 球uniform | 每渲染帧读容量槽的presentation/位置/opacity；16槽为256字节，变化时按材质提交一次 | MobileTableRendering:269–305 | 60帧对应960槽检查/秒、每材质最多15KiB/s净载荷；API/驱动开销另算，不能把带宽小等于CPU零 |
| 接触AO | 每台呢片元对每个有效球计算rsqrt和衰减乘积；16容量槽w检查，隐藏槽不执行重算 | MobileTableRendering:185–200 | O(台呢片元×有效球)，与软阴影分开；相机动/球不动也重算，没有空间场缓存 |
| 近远判断与guard | 每台呢片元做支持域、必要时mask、有限域/两灯锥判断；最终保留原near/far选择 | DailyClothSupportExperiment:183–298 | 已优化无关球测试，但guard自身有成本；少球收益有限 |
| 台呢灯光/高光 | 两灯合计near64/far8，每次算方向、距离、BRDF和加权；near才进入球遮挡循环 | MobileReferenceLighting:929–962 | 大面积远档仍有固定8次成本；绝不是只有球影处耗算力 |
| 台呢球遮挡 | 真正需遮挡时64×候选球数，含点积、距离、软边smoothstep；guard可整段略过 | MobileReferenceLighting:439–459；DailyClothSupportExperiment | 多球散台曾是强热点，不能把16球优化收益外推此普通少球场景 |
| 解析面光漫反射 | 每次两矩形灯，每灯裁四边并累积可见边的normalize/cross/atan2；普通全可见为8条边 | MobileReferenceLighting:672–699 | far也调用；固定灯/台面位置部分可复用，但法线/材质及视角项需分别处理 |
| 球材质R | 反射响应LUT一次+预过滤环境一次，另有两灯高光、SH9、台呢反弹及两次双灯解析漫反射调用 | MobileReferenceLighting:182–248、876–926；RoomReflectionProbe:237 | 正常路径没有64次环境积分；球面材质并非免费，但不应优先重做已预过滤部分 |
| 房间/桌木/皮革/球杆 | 房间烘焙纹理constant；桌木/皮革/球杆有各自材质/灯光函数，仍需几何与像素处理 | MobileReferenceLighting:337–359、700–808；RoomReflectionProbe | 不应全部归成台呢或全部视为零成本 |
| 反射资源生成 | 缓存键按风格/材质等配置；球位与相机变化不进key；命中复用，生成含渲染/滤波 | RoomReflectionProbe:319–399 | 首次/换配置成本，正常连续击球不按每帧收费 |
| 几何/深度/MSAA/HDR/合成 | 每可见帧；4xMSAA及HDR保留，分辨率与覆盖/重叠决定像素规模 | AngleSceneView:176；AngleTrainingScene:960、981 | MSAA不能机械乘4份完整shader；片元/带宽/resolve等单独建模 |
| 音频、显示、系统 | 击球声离散触发，混音可能持续；屏幕亮度和显示功耗不属于shader | 已有CPU音频样本；亮度未知 | 音频仅2.01%采样CPU，非当前CPU首要项；屏幕能耗未知 |

## 3. 可复算的GPU工作账：远档不能忽略

以此前600×400隔离场景的真实可见台呢输入计数为基础。当前guard保留near/far分支，所以灯光/BRDF次数公式仍适用：`L = 64×near + 8×far = N×(8+56q)`。这是源码级同类工作次数，不是GPU指令、时间或能耗。早期safe候选的球mask计数不冒充当前guard统计。

| 夹具 | 可见台呢输入 | near面积 | 灯光/BRDF求值/帧 | far占同类求值 |
|---|---:|---:|---:|---:|
| single-low | 163,153 | 3.23% | 1,600,568 | 78.91% |
| single-near | 235,377 | 11.71% | 3,427,160 | 48.51% |
| edge-low | 42,952 | 12.02% | 632,688 | 47.78% |
| rack-overview | 37,691 | 3.93% | 384,576 | 75.32% |
| scatter-overview | 37,426 | 21.36% | 747,128 | 31.51% |

两球近景每帧约343万次，在同夹具60Hz条件下约2.06亿次/秒；两球低位约160万次/帧。手机实际分辨率/覆盖未观测，不能把这些数冒充本次手机实际值。相比之下16槽CPU球参数只是每秒960次检查，说明优化应区分“每球一次”和“每片元×采样”的数量级；两种工作单位不能直接求比例。

每次台呢光样本源码含距离sqrt、半角normalize、Smith两项sqrt、Fresnel pow及多次dot/除法；编译器可折叠常量、合并重复子式，不能把源代码运算符数量直接当机器FLOPs。解析漫反射、AO、法线/纹理、内建PBR和输出合成必须另计，不能只算64样本循环。

## 4. 合理的能耗模型与已做的敏感性分析

先分设备子系统，再分业务。不能将CPU秒与GPU秒直接相加当墙钟；能量可以相加，但必须有同设备、相应状态的单位成本。

```text
CPU环节能量估计 = E核活动秒×aE + P核活动秒×aP
GPU环节能量估计 = ALU工作×bA + 特殊函数工作×bS
                 + 纹理访问×bT + 外存字节×bM + tile/resolve工作×bR
总能量 = 各CPU/GPU环节 + 显示/网络/基础功耗/其他系统开销
```

已有数据能校准CPU活动秒与核分布；GPU当前只能建立工作次数，不能校准本手机的各类b系数。既有Mac GPU配对时间用于校验候选方向，不能把Mac系数直接当iPhone能量系数。

下面实际计算aP/aE为1、2、4的敏感性情景。**1/2/4是主动选取的压力假设，不是A18 Pro测得系数、合理区间证明或置信区间；输出只是CPU活动能耗代理，不是App/手机能耗占比。**目的在于检验优先级是否一换权重就翻转。

| 环节 | r=1 | r=2 | r=4 |
|---|---:|---:|---:|
| UI更新与合成CPU端 | 31.3% | 36.2% | 42.2% |
| Metal与GPU驱动CPU端 | 23.5% | 21.4% | 18.9% |
| SceneKit | 23.4% | 20.9% | 17.7% |
| App未解析业务 | 9.0% | 10.2% | 11.8% |
| 系统运行时/未归属 | 7.6% | 6.8% | 5.9% |
| FramePacing采集相关 | 3.2% | 2.8% | 2.3% |
| 音频 | 2.0% | 1.7% | 1.3% |

在这些情景下UI/合成持续是最大的单一CPU域；图形链路CPU合计约78.2%–78.8%。因此即使还没有瓦数，也已有理由优先减少图形更新/提交，不是凭感觉将全部责任推给GPU。该结论不表示这部分CPU都能消除，也不证明物理无成本。

GPU内部先比较同类运算分布（如上表far/near）；ALU、采样、带宽的系数缺少本设备校准，不能把不同种类强行等权凑100%。现有数据不支持一个有依据的整机能耗百分比区间。模型保留这些未知项，而不是编造“GPU占70%、CPU占20%”。

## 5. 用既有实验约束判断，避免重新陷入同一优化

R22/R23两球近景没有可靠净收益；多球散台/开球后的动态球态guard有较大GPU收益。故“继续抠同一少球遮挡mask”不应默认排第一。R23并非整页采集，CPU动作、SwiftUI不在GPU区间，不能用其GPU收益解释本次78%的CPU图形链路。

此前低维/空间场候选已有净成本或误差问题，不能仅凭复用理论宣称重做必然成功。下一候选应更小、指向明确：

1. CPU：检查可见HUD按60Hz无差别更新、每帧动作扫描、重复状态/布局检查，按真实状态版本更新；保留实际运动和输入响应。先明确具体子项，不能承诺省掉全部31% UI成本。
2. GPU：将台呢far路径的无影漫反射/静态灯几何与视角高光分离，优先消除原样重复求值；法线/粗糙度/织物细节与视角相关项保持正确。空间缓存必须计入读写和更新，不能直接照搬被否定的大场方案。
3. 正常R球反射及已烘焙房间不优先重写。uniform文本缓存/打包不再被包装为主要活动期能耗优化。
4. 连续调参预测保持15Hz上限与合并，在业务地址完成匹配符号归属前，不牺牲物理精度或宣称预测是主因。

## 6. 工具选择纠正与后续校准入口（本轮不执行手机操作）

之前只采Time Profiler/Metal事件不足以回答能耗分账，工具选择有缺口。Apple Power Profiler可按CPU/GPU/显示/网络比较目标App的power impact，支持手机端独立录制；其不同机型分值不能直接比较，也不是每个shader的焦耳账。Metal GPU计数器能提供片元、顶点、带宽与pipeline成本，结合代码后才能校准GPU各系数。无需把“必须再测三分钟”设为本次分析或下一优化的前置。

- [Apple Power Profiler](https://developer.apple.com/documentation/xcode/measuring-your-app-s-power-use-with-power-profiler)
- [Apple GPU counters](https://developer.apple.com/documentation/xcode/analyzing-apple-gpu-performance-using-counter-statistics)

## 7. 证据与复算

- 原始短轮XML：`output/phone-heat-20261113/work/formal-time-profile.xml`；原始帧/热状态见PHONE-HEAT记录。
- 脚本：`output/phone-heat-20261113/cost-model/analyze_cost.py`。执行无需手机，不重录，不改原件。
- 完整结果、分组规则、原始XML与生产源SHA：`output/phone-heat-20261113/cost-model/results.json`。
- 原始台呢输入计数：`output/render-lowdim-20261113/support-structural-cost-r1/results.json`。
- 校验：15038样本恰好归属一次、总权重15.038秒、PID一致、状态Running；能耗敏感性各列加总100%。没有完成整机能量校准，不宣称该项通过。

补核：本报告涉及且纳入安装源manifest的5个共享渲染文件SHA均一致（installed-source-check.json）；其他业务文件本轮记录当前SHA，不冒称该旧manifest覆盖所有业务源。
