# 每日清台原机位无线负载实测

2026-11-26，北京时间。用户要求测当前安装版本的真实操作CPU/GPU，核查库边效果、相机与轨迹计算增量；保持画质和帧率。角色：Test Engineer。

## 测试条件与方法

- iPhone 16 Pro / iOS 27.2.1，用户确认已进入每日清台原3D机位、温度正常、未充电。直接连接手机Wi-Fi IPv4，通过已配对lockdown、CoreDeviceProxy、进程内RSD连接Instruments DVT；没有LLDB附加、重装、重新构建或App偏好变更。
- CuePhys本轮PID693，各段采集前后PID一致。CPU为App进程的sysmontap数据，500ms采样；100%表示一个CPU核满载。累积user/system CPU时间差与实读Mach timebase `125/3`交叉核验，结果接近样本均值。
- Graphics为约1Hz的**全设备**GPU计数器；不是App独占GPU时间、不是功率。CoreAnimationFramesPerSecond是系统屏幕更新率，不能当作SceneKit逐帧呈现或严格掉帧率。
- 正式操作前7秒静止预检成功，CPU进程归属正确、GPU数据可读。第一轮瞄准用户明确说没有操作，`aim-01`保留但从操作结果排除。第二轮用户确认完成约30秒连续瞄准，随后反馈正常或轻微温热；击球轮反馈4–5杆、温度正常。
- 两轮正式记录各60秒，包含等待指令、实际操作与停止前后。未对触摸事件插桩；指令/回复只有宿主时间，不能视为精确手指起止。下面活跃段是根据计数器变化选出的连续时间窗，并非声称用户精确操作了相同时长。首个Graphics样本不覆盖完整周期，排除。

## 结果

| 场景与记录窗 | App CPU均值 | 全设备GPU均值 | 系统屏幕更新率均值 |
|---|---:|---:|---:|
| 静止预检，`idle-smoke-01` +1至6.8秒 | 0.30% | 0% | 0 |
| 连续瞄准活跃段，`aim-02` +19至59.8秒 | 56.89% | 75.46% | 55.76/s |
| 瞄准前段，+20至37秒 | 64.62% | 59.47% | 59.29/s |
| 瞄准高GPU段，+39至57秒 | 49.00% | 93.56% | 51.44/s |
| 正常击球活跃段，`shots-01` +2至47.8秒 | 24.05% | 57.02% | 56.04/s |
| 击球后静止，+54至59.8秒 | 0.51% | 0% | 0 |

瞄准高GPU段设备利用率90%–96%，屏幕更新率44–58/s。该段确实存在高图形负载与更新率下降，但本轮没有热状态/表面温度测量，用户也没有报告明显发热，不能把下降归因于热降频。普通击球整段均值包含每杆等待、动画/交互差异，不代表每个动画帧都维持某个固定帧率。

停止后CPU、GPU能回落，支持本次所测状态的休眠仍有效；不覆盖所有页面/切镜/后台路径。不能用这些短记录外推长时间温升。

## 后续修改的证据

1. **完整轨迹计算频率确实提高。** `a2d6037a`（2026-11-23）把`PositionPlayViewModel.livePreviewInterval`从1/15改为1/24秒，并去掉P01自由瞄准的`!immediateAimGeometry`排除条件，使其在拖动时进入限频完整物理预览。15到24是调度上限增加60%，不等于实际求解次数、CPU或发热增加60%；仍有单任务合并和慢求解限流。
2. **24Hz已编进此前实读安装包对应二进制。** 本地Debug-iphoneos/CuePhys可执行文件SHA256为`0970932e50327c07c62d0b33ce0bb968c9b8b3cd3260957d4fc396433fdc952c`，与本会话此前手机实读完全一致。离线反汇编`scheduleLiveTrajectoryPreview`，地址`0x100d28ec4`附近构造double位模式`0x3fa5555555555555`，数值0.041666666666666664秒，即1/24；没有为此再次附加手机调试器。此为编译逻辑证据，不是实时求解次数计数。
3. **预览不仅做计算，也更新绘制。** 当前源码`requestLiveTrajectoryPreview`→`scheduleLiveTrajectoryPreview`→`launchSolveIfIdle`执行`PositionPlayShotSolver.solve`；返回的预览可调用`drawTrajectory`并刷新瞄准几何。相机与完整物理预览同步运行。因此轨迹求解、轨迹节点更新与相机引发的持续渲染，都是下一轮应分离的开销。
4. **库边效果有附加着色工作，但尚未测出独立成本。** 先前手机实际台呢surface相对H18-R7只多出库边效果片段，原优化没有被覆盖；新增床面查表采样/库侧光照仍是额外GPU工作。本轮没有关闭库边的同场景A/B，不能声称它导致或不导致高GPU负载。
5. **当前原机位不命中LTC近景分支的证据仍成立于先前相机快照。** 高出台面约0.65m、俯角约15°，超出原LTC适用域；固定灯预计算和球影优化仍接入。未在连续操作中重新读取每帧机位，不能把先前静态快照扩展为所有操作帧的LTC命中率。

## 结论与剩余范围

已经取得当前安装包的无线真实操作负载，发现连续瞄准比本次普通击球更重，并确认后续24Hz完整预览调度已编译进对应二进制。没有发现本次静止状态持续空转；未复现用户描述的明显发烫。不能仅凭当前负载与源码差异证明相对旧安装包的性能回退，更不能给库边/相机/轨迹各自分配GPU百分比。

下一步若继续定位，应在保持同一画质、帧率与相机/球形的条件下取得CPU调用栈、实际求解/轨迹更新次数，并做受控成本对照。优先检查完整求解及轨迹重建是否做了可复用工作，再查相机和材质的独立成本。本轮没有改生产代码、画质、帧率或LTC阈值，没有运行无关构建/XCTest，也不宣称已修复发热。

## 证据

- 原始采样、元数据、用户指令时间与脚本：[wireless目录](../output/render-regression-20261126/wireless/)。`idle-smoke-01`、`aim-02`、`recovery-01`、`shots-01`；无操作轮`aim-01`同样保留。
- [统计摘要及精确时间窗](../output/render-regression-20261126/wireless/metrics-summary.json)、[匹配二进制核对](../output/render-regression-20261126/wireless/installed-preview-scheduler-audit.json)、[调度函数反汇编](../output/render-regression-20261126/wireless/installed-preview-scheduler-disassembly.txt)。
- [已装优化核查与无线恢复过程](RENDER-REGRESSION-20261126.md)。Xcode自动发现仍未恢复；无线直连DVT已通过实际进程查询和多段CPU/GPU采样验证。

## 完整一局追加测试（约15杆）

用户要求按平时节奏打一整局。沿用同一无线采集链路、同一安装包和PID693，画质、帧率均未调整。录制先启动再发操作指令；用户反馈原话为“结束了，大概打了15杆，温度正常，有点微烫”。这记录的是主观温感，未测得表面温度、功耗或热降频状态。

- 原始记录351.65秒；从发出开始提示到收到完成回复324.20秒，随后保留17.73秒有效恢复样本。回复时间包含操作结束后等待和输入延迟，**不是精确游戏用时**。
- 录制正常以`operator_stop`结束，exit 0，CPU原始消息1342条、Graphics 349条，`streamErrors=[]`，采集前后PID均693。操作指令至回复窗口内有618个有效CPU样本、321个Graphics样本；Graphics采样间隔中位1.007秒、最大1.347秒。
- 后半段已出现长时间低负载，因此不能只用整段均值代表击球负载。下表时间均相对开始提示；中段是计数器选窗，没有触摸或逐杆事件标记。

| 记录窗口 | App CPU均值（单核100%） | 全设备GPU均值 | 系统屏幕更新率均值 |
|---|---:|---:|---:|
| 提示至完成回复，324.20秒（含较长静止） | 14.05% | 38.36% | 28.83/s |
| 前3分钟，含正常操作和间歇 | 24.92% | 67.99% | 51.15/s |
| 中段+60至150秒，持续较高负载 | 29.65% | 86.01% | 58.19/s |
| 后段+210至320秒，主要静止 | 0.58% | 0.97% | 1.10/s |
| 完成回复后的17.73秒恢复观察 | 0.64% | 0% | 0 |

第1/2/3分钟GPU均值分别47.58% / 82.78% / 73.36%；CPU分别22.89% / 29.38% / 22.53%。全窗口共78个约1秒样本的GPU利用率达到90%及以上（占321个样本的24.3%，不是连续78秒），峰值96%。这确认正常一局也能出现较长的高GPU占用，中段屏幕更新率仍约58/s；全窗28.83/s被静止休眠拉低，不能解读为游戏只有29帧。

**本轮结论：** 原静止休眠路径在这一局结束后仍有效，未观察到停手后CPU/GPU持续空转；操作中的图形负载偏高，用户感到微烫。GPU利用率不是功耗，负载上升可能同时受场景和频率调节影响；没有GPU频率/功率、温度和调用栈，不能认定为热降频，也不能确定库边、相机和轨迹各自贡献。此前确认的24Hz完整轨迹预览增量仍是应优先分离验证的CPU/节点更新候选，但完整一局本身不证明它导致了相对旧版的温升回退。

没有继续要求用户重复长局，也没有重装或修改生产代码。下一步定位仍为同机位/球形/画质/帧率下的函数级采样与受控对照；保留当前安装包原始基线。

证据：[完整一局原始记录](../output/render-regression-20261126/wireless/full-game-01/)、[全窗与逐分钟统计](../output/render-regression-20261126/wireless/full-game-01/session-summary.json)、[操作和静止选窗统计](../output/render-regression-20261126/wireless/full-game-01/selected-windows.json)、[Graphics时间序列](../output/render-regression-20261126/wireless/full-game-01/graphics-timeline.csv)。

## 函数级采样续测：预检通过，正式操作待就绪

用户已授权继续函数级采样与对照，保持画质和帧率。当前未修改生产代码、偏好或安装包，也未附加LLDB。

无线CoreProfile预检8秒成功，PID693前后一致，得到37个原始数据块、1份stackshot、11,590,656字节kdebug数据。stackshot中CuePhys UUID `9BD0FE11-8578-3583-AAE0-7514CBB8003C`与已核验二进制一致，可用本地同包符号解析至`PositionPlayViewModel.launchSolveIfIdle`、`PositionPlayShotSolver.solve`、`ShotPredictor`、`EventDrivenEngine`等函数。

重要方法校验：请求timer trigger并不意味着返回的所有栈均是均匀定时CPU样本。原始App栈3969个，其中3429个来自flags25、27个来自flags17的PET调度触发；它们会过度表示线程切换，不能直接用于CPU时间占比。按XNU的`SAMPLE_FLAG_PEND_USER`、`SAMPLE_FLAG_SYSTEM`、`SAMPLE_FLAG_NON_INTERRUPT`和`SAMPLE_FLAG_CONTINUATION`语义，关联同线程延迟用户栈，仅保留来源flags1/33，得到513个定时用户栈。该映射仍须在正式采样中与同步sysmontap CPU核对，不把单个样本数量乘请求间隔直接当精确耗时。

预检有28个定时栈包含完整求解、25个包含物理引擎，但**没有约定操作与稳定球形，不能将它们作为正式占比或24Hz成本结论**。脚本已加入同步CPU/Graphics采样，下一步待用户确认原机位、温度正常且未充电后，录制停手—连续瞄准—停手对照。开始提示必须晚于采集启动确认。

现包的`livePreviewInterval`为编译常量，普通轨迹显示设置不等价于停用完整求解。先取得24Hz路径函数成本；15Hz对照如需诊断构建，应固定同一源码与构建配置，仅改变预览调度参数，并恢复原基线。不能拿当前脏工作区新包直接对比旧安装包来归因频率，也不能用降显示帧率或降低画质替代对照。

证据：[预检原始数据和筛选结果](../output/render-regression-20261126/wireless/cpu-smoke-01/)、[采样脚本](../output/render-regression-20261126/wireless/profile_cpu.py)、[函数分析脚本](../output/render-regression-20261126/wireless/analyze_cpu.py)。脚本语法编译通过；正式有控制的函数占比、实际求解次数与15Hz对照尚未完成。

采样口径参考：[Apple XNU action.h](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kperf/action.h)、[kptimer.c](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kperf/kptimer.c)、[pet.c](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kperf/pet.c)；配置参考[pymobiledevice3 CoreProfile实现](https://github.com/doronz88/pymobiledevice3/blob/master/pymobiledevice3/services/dvt/instruments/core_profile_session_tap.py)与[py-ios-device调用示例](https://github.com/YueChen-C/py-ios-device/blob/main/ios_device/cli/base.py)。对应源码快照保存在wireless/reference-*，当前系统行为以本轮原始trace为准。

## 函数级正式采样：连续瞄准与静止对照

用户确认温度正常、未充电、停在每日清台原机位后启动`cpu-aim-01`。先检查实际数据增长、PID和stackshot，再提示连续左右瞄准；用户确认“已完成约30秒瞄准并停手”。总录制108.11秒，开始提示位于+26.19秒，完成回复位于+88.40秒。回复延迟与操作时长并不等价；按实测计数器选择下面稳定窗口，不将它们称为精确触摸起止。+0至15秒存在短暂活动，未纳入静止基线。

录制正常退出，PID693前后一致，508个数据块、186,075,840字节原始trace、1份stackshot，`telemetryErrors=[]`，未触发存储保护。没有LLDB、重装、画质或帧率调整，没有修改生产代码。系统CPU/GPU采样与函数采样同步进行。

### 采样口径与交叉校验

- 依据同线程的kperf pending来源，将延迟用户栈关联回原始timer时刻。全记录排除PET来源flags25的38,012个栈及flags17的67个栈，只保留flags1/33的6422个定时App栈。
- 以stackshot的`mach_absolute_time`、`usecs_since_epoch`和实际timebase 125/3对齐时间，CPU则用sysmontap的`EndMachAbsTime`。主分析窗为录制+40至80秒，共5367个定时样本；该窗最大用户栈延迟约4.37ms。
- 主窗CPU样本均值66.97%，累积user/system CPU差核验67.51%；定时样本按名义5ms折算67.09%。三者接近，支持用定时样本比例估计函数CPU份额；它仍是统计估计，不是每次函数入口/出口精确计时。
- 全部1561个完整求解样本都包含`launchSolveIfIdle`后台闭包。求解与主线程结果处理样本无交集，下面这两项可相加。物理引擎、圆弧碰撞、四次方程和轨迹绘制与父调用存在嵌套，不能重复相加。

### 静止／瞄准／恢复对照

| 窗口（相对录制开始） | App CPU均值 | 全设备GPU均值 | 系统屏幕更新率 |
|---|---:|---:|---:|
| 静止，+17至33秒 | 0.83% | 0% | 0/s |
| 连续瞄准稳定活动，+40至80秒 | 66.97% | 79.35% | 53.28/s |
| 停手恢复，+90至107秒 | 0.64% | 0% | 0/s |

CPU的100%仍指一个核满载。静止及恢复窗均没有采到完整求解或主线程结果更新栈；有限样本不能证明绝对零调用，但与低CPU和零GPU一起支持休眠有效。

### 24Hz调度版本下，预览路径占多少CPU

| 函数范围 | 定时样本数 | 占App CPU采样 | 折合单核CPU百分点（估计） |
|---|---:|---:|---:|
| 完整求解`PositionPlayShotSolver.solve`及子调用 | 1561 | 29.09% | 19.48 |
| 主线程接收／应用求解结果闭包及子调用 | 136 | 2.53% | 1.70 |
| 上述两项合计，无重复样本 | 1697 | **31.62%** | **21.18** |

这相当于当前操作段中，两条可明确归属的路径约使用0.21个CPU核，约每秒210ms CPU时间。它是当前24Hz调度策略下的成本估计，**不是证实每秒恰好求解24次，也不是24Hz相对15Hz的增量**。异步触发的后续SwiftUI/SceneKit提交与GPU执行不一定保留求解调用栈，因此这也不是预览全部间接成本的上限。

同一操作段拆成前段+40至58秒和后段+60至80秒，完整求解的CPU样本份额分别28.42%和30.00%，结果处理分别2.54%和2.56%，份额较一致；但两段球路、输入节奏与系统状态没有锁定，不作为重复实验。

完整求解中主要采到`ShotPredictor.simulateFree`→`EventDrivenEngine.simulatePrediction/simulate`。物理引擎路径占App样本26.61%，其中圆弧库边碰撞时间计算7.83%、`QuarticSolver.boundedRealRoots`7.53%，后两者大幅嵌套。这里的“圆弧库边碰撞”是CPU物理计算，**不是库边材质效果的GPU着色**。下一步应优先检查碰撞候选筛选、圆弧求根和重复物理预测能否复用；不能混称为库边视觉效果开销。

`drawTrajectory`/`TrajectoryRenderer`相关栈占2.40%，与结果处理等路径重叠；`CameraRig`栈占2.03%，仅表示直接CPU调用链，不包含相机更新触发的后续渲染。其余约68% App CPU尚未完整分解，不可全归为渲染，也不可忽略。

### GPU与当前结论的边界

瞄准前段GPU61.67%、系统更新59.22/s；后段GPU93.95%、更新48/s，同时App CPU从82.93%降至53.61%。这说明后段图形负载和更新率也值得独立检查；本轮没有GPU函数/着色器计时、温度或频率读数，不能把它认定为热降频或给预览分配GPU占比。函数级采样会增加工具开销，不能把本轮与先前仅计数器采样的差异当成App回退。

本轮已完成原包函数级采样与静止对照，确认完整预览直接调用链约占三分之一App CPU。**15Hz与24Hz同条件对照、真实求解次数、每次求解耗时及GPU独立归因仍未完成**；目前没有必要先降低画质或显示帧率，也没有据此修改生产实现。

证据：[正式trace与元数据](../output/render-regression-20261126/wireless/cpu-aim-01/)、[窗口统计](../output/render-regression-20261126/wireless/cpu-aim-01/window-summary.json)、[函数统计](../output/render-regression-20261126/wireless/cpu-aim-01/function-summary.json)、[原始事件核验](../output/render-regression-20261126/wireless/cpu-aim-01/trace-audit.json)。复现分析脚本为`analyze_cpu.py`和`summarize_cpu_windows.py`，均与原始证据保存在wireless目录。
