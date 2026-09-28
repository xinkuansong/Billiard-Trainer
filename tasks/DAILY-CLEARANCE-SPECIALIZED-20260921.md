# 每日清台专用渲染执行记录

真源：[持续性能 v2](问题集合_每日清台持续性能_v2.md)。用户已授权连续执行。正式默认保持 reference，直到 B7 通过；本报告只记录已取得证据。

## B1 基准（2026-09-21）

- 源码 SHA256、HEAD 与调用清单：`build/daily-specialized-20260921/baseline/{manifest,consumers}.json`；保留原有脏工作区，不以 HEAD 代替实际源码。
- 当前 reference：原生尺寸、MSAA4、活动60FPS、既有事件驱动静止调度。R/S/RS 只改变指定着色路径；平衡32样本候选不混入基准。
- 改前 `testBalancedSamplingVisuals`：1测、0失败，7.263秒；144张图已复制到 baseline，近景原图已目视。已有近景夹具包含紧密双球，只作视觉压力，后续新增合法多球盘面。
- 生产链：FreePlayView → PositionPlayViewModel.setupScene → AngleTrainingScene → MobileReferenceLighting / MobileContactOcclusion → AngleSceneView。完整共享消费者见 consumers.json，包括动作库场景、角度/瞄准/走位/三球/思路/斯诺克/编辑与视频导出。

### 资源账单

| 项 | 源码事实 | 生命周期／可控性 | 硬件待补 |
|---|---|---|---|
| 球房探针 | 512×256 RGBA16Float、普通mip、shared、shaderRead；约1.333MiB纹素，不含分配对齐 | RoomStyle三种风格按需缓存＋neutral；切台呢只改uniform；不每帧生成 | allocatedSize、实际读带宽 |
| 探针生成 | 六个128²房间面＋一个隐藏球桌地板面；CPU转线性/SH，blit普通mip并等待 | 首次风格加载；固定rig变化需算法版本/缓存失效；现有快照8bit限制HDR来源，half不会恢复丢失范围 | 峰值临时资源及耗时 |
| 球反射 | 64 GGX样本，每样本房间＋台呢相交＋两灯板 | 号码球roughness .05，白球等 .34；同材质参数安装路径 | 具体fragment计数／ALU |
| 台呢直接影 | 每灯板近处8×4，远处2×2，两灯板；循环内照明/高光/遮挡耦合 | presentation球位/高度/opacity；打包float4矩阵，仅变化上传 | shader耗时与带宽 |
| 接触AO | inverseDistance³，全局非有限支撑 | 保留同帧更新，不随相机重烘 | 成本待隔离 |
| MSAA／depth／HDR | SCNView MSAA4，内部格式/pass/load-store由SceneKit生成 | 未发现可安全直接改attachment生命周期的产品入口 | capture记录格式、尺寸、storage/load/store/resolve；不凭推测填值 |
| SSAO | 移动路径关闭 | 保持 | capture确认实际状态 |
| 场景提交 | contentIsAnimating/手势/动作/相机唤醒，静止暂停DisplayLink | 保持；nil调用者需按页面确认 | App合成器与场景提交分开计 |

### 固定场景与记录契约

2D/3D/近景/掠射，白球与号码球，合法稀疏盘面/球堆/贴库，腾空与入袋、三房间风格与台呢颜色。正常运动取生产物理录制，准备和预热不计入计量段。

每段JSON须含：源码指纹、构建优化级别、设备/OS、实际profile、模式/相机/盘面/seed、分辨率/MSAA/FPS、计量起止与样本数、CPU墙钟/CPU busy分列、GPU命令跨度/执行计数分列、帧间隔p50/p95/>25ms、内存、thermal起止、充电/亮度/室温状态。不可用字段置null并给原因。至少两有效交错基准对；漂移>5%拒绝性能结论；持续测试只对赢家运行。

## 当前进度

B1～B4核心电脑验证完成；B6电脑回归已完成。SceneKit内部pass、硬件指标和持续验收留B7；温升改善未验证。

## B2 预积分资源

新增 PrefilteredReflection，256样本GGX预过滤、128²RG16F材质响应LUT；同device共用LUT/compute pipeline，每probe懒生成一次，失败打印原因并回退。三风格缓存＋neutral有界，台呢颜色不烘入新资源。512×256 RGBA16F链纹素1,398,104字节＋共享LUT65,536字节；allocatedSize模拟器返回0，硬件值留B7。

iOS26资源两测0失败；iOS17全RoomReflectionProbeTests 10项、1个既有可选出图跳过、0失败（5.472秒），包含常量HDR、方向/接缝/粗糙度、三风格三轮复用及临时资源释放。iOS17首次pipeline生成286.8ms，已热pipeline房间预过滤1.85～2.45ms，均为模拟器数据，不外推手机。初始getBytes读回非零mip返回base局部，改为blit sourceLevel读取后原断言通过，失败日志保留，详见build内b2-notes。

B3执行中；正式默认仍A。

## B3 反射替换

候选R以预过滤房间查询＋Smith/Fresnel LUT替换完整64迭代，灯板为GGX slope CDF的可分离矩形近似，台呢保留前向相交及边界软化，台下恢复floor。shader往返还原逐字断言；资源失败恢复原integral。Debug -specializedRendering R显式启用，普通/Release仍A。

三房间×5机位/状态×A/R×6运动帧=180图，iOS26与17各一测零失败（18.442s/19.523s）。iOS26近景A/R、整帧、15场景总览已目视，号码/花色/球缘保留，无洋红替代色；全帧MAE最高0.01881/255（背景占比高，不能当球面误差上界）。iOS17同矩阵已生成，B6继续实际页面/更多球形/动画同帧验证。下降夹具只验证遮挡前后，不冒称看到了被台面遮住的支架球，B6须补可见台下近景。

B4开始，B3扩展消费回归随B6闭合；真实GPU收益与温升仍待B7。

## B4 解析条带球影 S1

用球体切锥与矩形灯板相交代替逐光样本/逐球检测：Z方向可见区间及照度解析积分，X方向8点Gauss-Legendre。先按真实球高和灯板支撑范围排除无贡献球；同帧uniform保持。未遮挡漫反射取既有矩形固体角；台呢高光单独保留既有远区2×2积分，遮蔽用每灯板visibility近似调制，接触AO原样。无新增逐帧中间贴图/pass。

离线脚本 `scripts/research/sphere_panel_visibility.py`：2880组合，128²与256²每灯板射线参照，收敛误差p95 .000600/max .001958。比较4/8/12条带后选8：遮挡比例RMSE .005991、p95 .002740、最大 .104974；最大值保留为已知近接触边界误差，不用背景均值掩盖。多球使用分球visibility乘积，非精确遮挡并集；近接触由原AO保护，最终接受还需真实画面/手机。

iOS26视觉1测通过12.118秒；iOS17视觉＋SCNAction同帧＋参数无变化不重发，共3测0失败16.561秒。每系统144张，覆盖稀疏/合法密集/贴库/腾空，A/S/RS、2D/近景、6运动帧。原图与对照已审，无编译替代色、异常黑块、明显接触脱离；运动末帧与同姿态复画最大通道差≤3，13帧均不同。台面以上/非平面接收存在近似边界，B6补袋口与用户页。

S1核心电脑验证已通过；暂未触发B5（无已证实视觉否决，手机净成本待测）。B6进行中。


## B6 组合回归

- iOS26扩展单元：33项、1个既有可选出图跳过、0失败，165.834秒。包含球贴、台呢、球桌共享材质、组合后的实际普通击球2D/3D阶段、袋口下方可见球体和风格切换。新增60组Metal float解析球影与离线double同算法对照通过；它证明实现一致，不消除8条带近似本身的误差。
- iOS17补充：3项、0失败，73.280秒；组合材质/袋口、数值对照、10次生产Coordinator创建/拆卸均通过。10轮每轮静止3秒绘制0帧、退出后存活场景0；资源数无泄漏证据。进程总内存含框架缓存，不能用模拟器allocatedSize=0断言没有显存。
- iPhone iOS26真实每日清台：2D/3D普通击球各1项，共2项0失败66.027秒。实际材质标记确认R/S均启用；击球后回到静止调度。诊断AX扫描仅在-renderProfileProbe显式打开，手机计时不得开启。
- 初次页面用例失败为测试入口两处假设错误：2D没有3D FPS文案、文件名大小写在Mac冲突；改为实际调度状态并隔离目录后原功能断言通过，失败日志保留。
- ROI图和原始数值：build/daily-specialized-20260921/b6-roi-{comparison.png,metrics.json}。反射近景ROI MAE0.0366/255、峰值40、改变像素3.28%；密集球堆组合ROI MAE0.4692/255、峰值76、改变像素28.32%、差异>8像素2.79%。这是明确矩形局部的差异定位，仍含局部台呢，不是全球面误差上界或感知分数。已目视A/R、A/S、A/RS；高光、号码、接触感保留，有局部高光和重叠球影变化。
- 全仓 make verify-gate 本次exit0；git diff --check通过。旧报告中的历史门禁失败不沿用为本次结果。
- iPad/旧系统实际页面与同构建诊断流程最终结果见下；手机发现结果仍unavailable，尚未安装本轮候选或启动手机负载。


### 真机交接准备

- 同包入口：Debug `-specializedRendering A/R/S/RS`；普通启动A；用于实际材质断言的`-renderProfileProbe`不得带入性能采样。每一variant都保持native/MSAA4/活动60FPS。
- 独立固定盘面成本入口：`RenderQualityV62Tests/testSpecialized2DDeviceCost`、`testSpecialized3DDeviceCost`；顺序A/R/A/S/A/RS/A/RS/A/S/A/R/A。热门控每段前Nominal，达到Serious/Critical停止；段间至少15秒且等待Nominal。仍需用户确认外壳冷却，不能拿热状态代替。
- 分析器：`scripts/research/analyze_specialized_render.py INPUT_DIR --output FILE`；拒绝缺样本、非Nominal、尺寸/设备不一及前后基准漂移>5%的配对。单profile少于2有效对时百分比输出null。合成校验已证明30%已知输入、漂移拒绝和缺数据拒绝三个分支；合成百分比不是实测收益。
- Instruments模板已确认包含Metal System Trace、Game Performance、Time Profiler和Animation Hitches。Mac导出沿用既有已验证的export进程局部绕过，不将环境变量注入App。
- B7仍须真实轨迹/完整用户页补CPU忙碌、呈现时间、pass/attachment、计数，以及赢家未充电20分钟持续验收。固定盘面2秒片段不是B7全部证据。


普通生产VM击球阶段（iOS26模拟器，非真机收益）：2D两杆运动6.332/5.788秒、绘制380/348次；3D两杆6.353/5.770秒、绘制381/346次。对应前后3秒静止窗口均0绘制。CPU busy原始秒数保存在b6-26-normal*-phases.json，未与同条件A配对，故不给CPU降幅。视觉审查见[UR-20260921](ui-reviews/UR-20260921-daily-specialized-rendering.md)。


### B6最终电脑验收

- 冻结后的实际页面矩阵：iPhone iOS26 4/4（111.222秒）、iPad mini A17 Pro iOS26.3 4/4（117.204秒）、iPhone iOS17 4/4（100.265秒），全部0失败。每端覆盖正常2D击球、正常3D击球、三轮视角往返/后台恢复、结算夹具后再开局；最后一项不是实打整盘清台。24张图片均解码、尺寸/哈希/非空/单端不重复校验通过；完整代表帧与联系表已目视。
- 组合版iOS26生命周期10轮：每轮静止3秒0绘制、退出后0存活场景；进程footprint约292.8～293.1MiB，末轮比首轮约+0.11MiB，没有本轮持续累积证据。iOS17同用例已通过；不拿不同宿主两组绝对内存横向比较。
- 离屏导出普通配置A的原生离屏路径和useAppAppearance路径均生成360×680代表帧，已目视；没有改视频默认配置。初次断言误把球桌区360×640当最终画幅，修为已有`options.outputSize`后通过。该测试修正不改变任何生产代码/UI用例；两条首轮错用文件名作为类名的拖球/阻尼selector也已纠正，复跑确认三项实际执行、0失败（final-core26-r2）。首轮失败日志完整保留，未当整轮通过。
- 固定盘面成本流程2D/3D各13段全部完成，方法各通过（66.992/66.969秒）。**模拟器命令跨度未出现显著收益**：2D R/S/RS分别约慢3.21%/2.15%/1.46%；3D R约快1.35%、S/RS约慢1.25%/0.23%。跨度中位数本身约0.42～0.47ms，且为Debug覆盖率宿主、Apple iOS simulator GPU，不能外推A18 Pro。此处只证明采集/输出/配对路径可用，不是优化收益验收；不得隐去负数或按采样次数替代结果。
- 原始成本片段/截图及分析在`build/daily-specialized-20260921/simulator-cost/`；`test-index.json`保留各轮通过/失败方法；最终生产/UI源码与冻结矩阵一致，只有上述导出测试断言变更，分别记录`final-source.json`和`delivery-source.json`。

**B6电脑范围完成，B7待真机。** B5未触发：暂没有电脑视觉否决，尚缺手机S1成本证据；不能因模拟器未见收益就宣称手机有效或立即扩写所有条件分支。B7切换正式默认时，还须显式复核视频导出保持既有参考配置，不能只改全局profile后忽略其共享消费者。


### 真机包与收尾

`make test TEST_ACTION=build-for-testing`、generic/platform=iOS、独立build/SpecializedDevice、Swift -O、覆盖率关闭：TEST BUILD SUCCEEDED，codesign严格验证通过。安装产物、bundle版本、二进制SHA/UUID和xctestrun路径见`build/daily-specialized-20260921/device-artifact.json`；这是Debug优化编译对照包，不冒充Release默认交付。手机仍不可连接，未安装、未采集本轮真机数据。全仓门禁和文档体积门禁通过，diff检查通过；本轮模拟器诊断门文件已移除，没有持续录制或自动高负载任务。B7未完成，整体方案不能标完成。


### 2026-09-21 15:44 无线安装与候选启动

用户明确要求无线应用到手机。devicectl核实iPhone16 Pro/iOS27、transportType=localNetwork、tunnelState=connected，已通过无线原位安装冻结的优化编译包（安装前SHA256与device-artifact匹配）。以`-specializedRendering RS`启动成功，PID9364仍在运行；未使用数据重置/测试夹具/AX材质扫描参数。安装/连接/启动/进程证据分别见wireless-*.json。当前RS仅对这次指定参数启动有效，划掉重启会回到普通A；不是正式默认切换。已询问本轮未充电和冷却状态，尚待回复，未开始负载/温升采集。B7连接阻塞已解除，性能和持续验收仍未完成。


### 2026-09-21 16:00 两分钟无线真实操作：热验收未通过

用户确认未充电、初始正常或温热；已在此前玩过并经历短录制，不是冷机配对基线。沿用RS候选、PID9364、iPhone16 Pro/iOS27、native/MSAA4/活动60FPS。16:00:21.296～16:02:22.184录制120.888秒，启动确认后提示操作，用户确认十几杆、结束“明显发糖了”（按上下文记录明显发烫）。已提示停止操作/冷却，无继续设备负载。此前40秒重测用户明确未击球，归为静止；断连及归属不完整记录保留，不作为有效操作对照。

证据目录：`build/daily-specialized-20260921/wireless-live/`；原始`rs-3d-two-minutes.trace`、`two-minute-session.json`、`two-minutes/analysis.json`及XML保留。可复算脚本`analyze_two_minutes.py`。导出使用仅作用于导出进程的线程池绕过，7张表均解析成功。

| 项目 | 本轮事实及口径 |
|---|---|
| 系统热状态 | 第99.689秒首次Fair，短暂回Nominal；99.794秒后持续Fair至结束，共约21.10秒Fair。未出现Serious/Critical；Fair不等于测得外壳温度或证明降频 |
| 应用CPU | PID9364，119次记录/118个有效百分比；累计CPU时间差÷119.585秒=25.67%，单个核心满负荷为100%；采样p95 36.33%，最高38.69%。不是整机CPU，也不是物理引擎独占 |
| GPU记录覆盖 | 虽指定180秒窗口，Metal明细实际仅62.339～120.886秒，共58.547秒；不能当完整两分钟，也不能把前半段缺失算空闲。原因尚未确定 |
| 应用GPU执行区间 | PID9364、Active、depth0去重合并，后58.547秒有26.762秒执行，覆盖45.71%。这是跟踪事件时间覆盖，不是硬件利用率/功耗计数 |
| 分通道 | Fragment合并19.728秒（窗口33.70%），Vertex8.100秒（13.83%），Compute0.107秒（0.18%）；通道重叠，百分比不能相加当整机利用率 |
| 应用内存 | physical footprint起点1098.66MiB、终点1265.97MiB、峰值1280.00MiB。包含压缩记账，非纯驻留内存；后半段Metal已分配峰值476.28MiB。单段上升不能证明泄漏，也不能都归因于新反射资源 |
| 帧率/帧间隔 | displayed surfaces有3089条，但尚未建立应用图层归属并分离静止停绘；不据此宣称60FPS或计算掉帧率 |

结论：本轮存在真实温升，持续体验未通过；不能宣布发热解决。应用GPU渲染仍是明确成本来源，Fragment执行时间高于Vertex/Compute，但本trace没有shader级反射/阴影分项，也没有CPU调用栈，不能证明S1、反射或物理引擎分别占多少。无同条件A对照，不能给优化降幅；这是全进程Metal+Activity+Thermal工具采集，额外记录/无线传输开销未量化，不能把热状态变化全算给普通游戏或全归咎工具。亮度、室温、电量、外壳温度、瓦数未知。

B7维持进行中，正式默认仍A。下一步应先补可复现的同场景A/R/S/RS短时分项账单、查明Metal保留窗口限制及内存资源归属，再对筛选赢家进行与重采样分离的低扰动持续验收；手机明显发烫时不继续压测。本轮不足以单独触发B5或宣称达到物理极限。


### 2026-09-21 电脑端重新配对：RS未证明收益

用户要求先电脑端确认有效。已用Swift -O/coverage NO构建，在iOS26.3模拟器原生1206×2622/MSAA4/60FPS完成两轮A/R/A/S/A/RS/A/RS/A/S/A/R/A，2D/3D共52段、每轮实际2测试0失败。RS有效配对各4组：GPU命令跨度配对变化中位数2D慢7.31%、3D慢11.12%；CPU编码墙钟有效配对2D两组慢9.71%、3D三组慢5.57%。R单项无一致收益；S 2D慢3.11%（3对）、3D仅1对有效，不给结论。5%基准漂移排除，无效样本不填收益。不能外推手机，但足以否决“电脑已经证明有效”。普通/Release保持A，候选不晋级；先定位候选新增成本和测量路径，不再凭算法采样数减少宣称优化成功。详见`build/daily-specialized-20260921/computer-recheck/REPORT.md`及两轮原始结果；诊断门已移除，本轮未修改生产代码。


## 2026-09-21 计量与算法结论纠偏

旧模拟器RS负结果保留，但不足以证明R/S算法本身无效。原生Metal指定夹具实测R约省88.5%、16球S约省27.5%；新局部阴影L单项省24.59%～48.10%，接入SceneKit完整单球场景却在2D/3D慢10.29%/11.13%，因此拒绝晋级。计量路径drawable、实际材质源码与失败夹具均已留证；详[纠偏报告](DAILY-CLEARANCE-CORRECTION-20260921.md)。完整场景与持续温升目标仍未达成，正式默认A未变。
