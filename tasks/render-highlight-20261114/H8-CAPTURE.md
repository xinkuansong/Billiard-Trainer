# 编译后GPU程序捕获与剩余归因

2026-11-14。H6/H7没有合格候选后，只补诊断捕获，不再重复性能排名。

已用Metal `MTLCaptureManager` 的`gpuTraceDocument`目的地各捕获1帧：C1基线、逐灯mask、距离平方复用版；实际1400×800台呢近景，预热8帧，真实原生渲染命令完成。捕获记录包含程序/绑定/资源，不能仅凭生成了gputrace就声称取得寄存器、指令数、占用率或根因。

最初断点：命令行工具不可用，Xcode操作受Mac锁屏阻挡。用户解锁后已完成下述实际程序核查；原断点已解除。

## 捕获原件与收尾

原生gputrace内部含符号链接（分别26/70/115个，全部指向本捕获内部）。生命周期按既有规则拒绝对该evidence直接收尾，状态曾为`evidence-error`；没有放宽规则。随后把原件移到本run工作目录，并按原路径、文件内容和链接目标打包，逐个文件SHA-256与链接名读回比对通过，再调用生命周期complete。

证据目录：`output/local-test-runs/211530f53393439b8f21ed7fce1e6c41/evidence/`。

- `baseline.gputrace.tar.gz`：70,288,324字节。
- `lamp-mask.gputrace.tar.gz`：70,363,606字节。
- `squared.gputrace.tar.gz`：70,461,634字节。
- `capture-archives.json`保存每个归档SHA-256、所有成员文件SHA-256/符号链接目标及校验结果。
- `results.json`保留最初捕获路径；路径迁移以后以归档及`capture-archives.json`为准。

研究捕获入口已改为原始gputrace写work、验证归档写evidence，避免后续同类收尾冲突；原生捕获只运行这一次，没有为此重跑候选性能。

收尾读回：run状态`reclaimed`、原执行退出码0，归档及全部留存文件哈希通过；本次回收记录的文件系统可用空间增量为767,873,024字节（约732MiB），不是以目录逻辑大小代替实际释放量。

## 解锁后核查结果

本轮只回放已有捕获，未重跑H6/H7的性能排名。Xcode执行Full/Overlapping分析，Performance State为Medium。核查run：`output/local-test-runs/d8ecaf31957e4ba48c6c810dbeb7c101/`。CSV由Xcode导出；着色器表与绑定对应关系由UI读回，明确标为人工转录，见`evidence/xcode-observations.json`及[结构化汇总](H8-results.json)。

三份对应的台呢均为command buffer 3、render encoder 2、API call 27，Triangle、UInt32、58,830 indices；基线pipeline 2，另两份pipeline 7。绑定同时包含`contactUniforms`、`bakedRailAO`、两张`temporalField`、法线和粗糙度纹理，确认比较的是C1台呢。不能按`commonprofile_frag`名称或整个捕获资源总量认定对象。

| 台呢片元程序指标 | C1基线 | 逐灯mask | 距离平方缓存 |
|---|---:|---:|---:|
| Xcode Shader Cost | 86.47% | 87.12% | 88.81% |
| Allocated Registers / High Register | 252 / 252 | 252 / 252 | 230 / 230 |
| Spilled Bytes | 272 | 272 | 512 |
| SIMD Groups | 37,094 | 37,094 | 37,134 |

Cost是本次捕获的着色器归因，不是整App或能耗占比；寄存器数量下降也不能单独判定更好，平方版同时增加了溢出。

| 主渲染encoder计数器（包含台呢与其他桌体draw） | C1基线 | 逐灯mask | 距离平方缓存 |
|---|---:|---:|---:|
| FS ALU Instructions | 3,037,562,416 | 2,936,570,496 | 3,512,643,888 |
| 相对基线变化 | — | −3.32% | +15.64% |
| FS Invocations | 1,132,800 | 1,132,832 | 1,132,864 |
| FS Occupancy | 20.85% | 19.55% | 18.47% |
| F32 Limiter | 75.48% | 71.26% | 66.09% |
| Instruction Throughput Limiter | 67.68% | 63.88% | 63.40% |
| Texture Filtering Limiter | 20.31% | 20.61% | 17.24% |
| L1 Stack Residency | 53.45% | 49.35% | 60.74% |

平方版的Stack L1 Read/Write Bandwidth导出原值从110.09/263.87增至462.24/965.03。CSV没有附单位，保留原值，不擅自标为GB/s。三个版本的Register Pressure Influence、L1 Cache Pressure Influence及Memory Request Stalls Influence均为0；不能隐去这些反证并宣布整个场景已经证实“受寄存器占用率限制”。

**可以下的结论：**本捕获台呢片元是主要成本；基线浮点运算/指令吞吐仍有较高负担。平方复用版虽然源码减少重复点积，执行指令反而增加15.64%，编译溢出272→512 bytes，栈读写指标上升，足以解释为何不能用源码运算数量预测它的净收益。逐灯版只减约3.32%指令、未减溢出，与此前收益有限相符。

**尚未证明：**没有取得每一源码行的可靠分账，不能认定272 bytes全部来自`shadowBalls[16]`；也没有对H6的高光分组版捕获，不能把平方版机制套到全部失败候选。Xcode回放总时间分别1.20/3.33/2.30ms，没有平衡AA/AB，不能替换H6/H7的配对结果或计算优化百分比。后两捕获含此前创建的资源，内存总量同样不能直接比较。

下一项有代码依据的假设：当前`MobileReferenceLighting.swift`生成逐片元`float4 shadowBalls[16]`，后续按动态index读取；H7还原地改写它。尝试从原256-byte常量buffer直接取球，取消线程本地数组，而非继续预存几何量。仍需真实画面及净收益验证，不能因这个解释直接接入生产。

指标解释参考Apple：[新Metal分析工具](https://developer.apple.com/videos/play/tech-talks/111374/)（limiter与utilization、occupancy需结合判断）；[Metal Compute on MacBook Pro](https://developer.apple.com/videos/play/tech-talks/10580/)（寄存器压力、spill与编译统计）。

证据保留：三份`*-counters.csv`、UI转录、分析脚本及哈希；平方版另导出勾选Embed performance data的` squared-profiled.gputrace`并验证归档。基线与逐灯的首次分析未嵌入归档，保留原始捕获和CSV/转录，不冒称有同样的嵌入原件。临时Xcode捕获窗口均已关闭，原项目窗口保留。

收尾状态补记：分析run `d8ecaf31957e4ba48c6c810dbeb7c101` 已 complete、退出码0；Xcode/GPU进程仍持有工作目录，生命周期记 `cleanup_deferred`，不同于已reclaimed的最初捕获run。原项目仍在运行，未为回收退出Xcode。后续H9已找到零spill且通过性能门槛的候选并接入，见[H9交付](H9-DELIVERY.md)。
