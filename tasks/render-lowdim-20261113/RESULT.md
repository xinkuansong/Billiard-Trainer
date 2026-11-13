# 3D 渲染研究：当前结果与可复现实验入口

**2026-11-13 正式接入更新**：用户已授权将 guard 与不可变文本缓存推广到相关 App 场景。共享入口、非 DEBUG 安装及缓存已完成接线，覆盖 27 组消费者；非 DEBUG App 编译通过，20 项接入与页面检查全部通过（0失败/0跳过）；完整 Release 仍受既有 API 配置阻塞。当前实现与验证状态以[推广记录](ROLLOUT.md)和[覆盖清单](ROLLOUT-COVERAGE.md)为准。以下 R1–R32 是历史研究证据，不再表示优化仅限每日/DEBUG。

2026-11-13。**当前选择仍是guard组合。R23已补齐两个真实开球案例：1,194帧R/guard/重复/恢复画面逐像素一致，含实际进袋、收球轨道和生产旋转尾段。18个真实状态各9轮GPU对照全部更快；开球初态配对中位约−17.8%，散开后的状态约−40.3%～−49.8%。** 精确原生selector 1/1 Passed、0跳过，独立分析通过。完整证据见本文R23及[逐轮记录](ITERATIONS.md)。

这证明完整生产SceneKit场景在所测球态下的直接渲染收益，**不等于整页FPS或完整交互净收益**。研究阶段默认/Release为原R，guard当时保留为DEBUG试用候选；此限制已由上述新授权推广接线替代。进入/资源验证结果见下文。完整页面活动净收益、多视图持续时序与长期生命周期仍待验，不能缩为设备边界。

**最新资源结果：R25发现并改善了重复进入的额外内存。缓存验证成功的不可变shader文本后，同一新构建各20次真实页面进退，候选相对R的末5次页面内phys_footprint增量从前轮约47.3MiB降至本轮1.516MiB（0.154%），首页增量1.422MiB，延后约43秒增量1.859MiB；本轮32MiB和10%两个门槛均通过。** 两臂末段约1.3–1.4MiB范围内波动，不等于长期泄漏排除或所有设备保证。所有原配置/源码SHA回退检查保留，16项合同测试通过；R19整次17项中首帧稳定性测试仍失败，不能写成17/17。旧约47MiB失败结果保留，未靠修改预算过关。跨构建下降不能单独归因全部差额的分配来源。[复验报告](../../output/render-lowdim-20261113/native-page-lifecycle-r3/REPORT.md)。

**最新R32：8组真实整页固定相机操作已完成，取得一个满足预设可比条件的BAAB。该周期reported GPU均值从4.151降到3.936ms（−5.18%），On-Glass呈现区间均值17.444→17.454ms，基本不变。** GPU P95/P99反为+1.95%/+6.08%，R两臂均值相差16.51%；因此只报告本次观察，尚不认定稳定整页净收益或流畅度改善。统计为各臂指标的配方内均值，非合并帧分位。288次CUA调用中App实际收到287次，03漏一次使第一ABBA无效，未补样；其余7组逐drawable内窗覆盖均大于99.9997%。[全部原值与两个周期](../../output/render-lowdim-20261113/native-page-metalperf-r1/analysis-r2/summary.json)、[独立输入/CPU审查](../../output/render-lowdim-20261113/native-page-metalperf-r1/INDEPENDENT-REVIEW.md)。

R26已核HUD、临时俯视和隐藏恢复；R27–R30原失败保留。R31通过系统自带metalperftrace取得完整来源，R32固定600ms操作中保留自然idle及60/30调度；相机相位、活动占比仍有小差异。CPU包围区间31–40秒不等，不能当同10秒窗口的净CPU对照；本轮也不覆盖持续多视图/击球求解/移动设备。初版消费器的跨来源时钟错误已留证并修正，不改协议或重采。[本轮报告](../../output/render-lowdim-20261113/native-page-metalperf-r1/analysis-r2/REPORT.md)与[逐轮记录](ITERATIONS.md)。本轮结束追加采集，默认R保持，后续只处理真实未闭合范围，不扩充已完成的shader/动态图像/20次进退实验。用户指出进度慢是合理的：近期主要成果是测量与结论边界，本轮没有新增生产优化代码。

## 现在解决的具体问题

目前最有价值的发现不是场景有很多模型，而是台呢片元重复执行了大量本可排除的球遮挡检查。生产几何被抬到物理床面 Y=.8，世界坐标重建后仍有微米级浮点误差。原程序对 `p.y<.8` 保守地把全部活动球放入遮挡 mask；散台真实可见 near 输入中，7,393/7,995 个落入这个分支。

本轮保留实际接收坐标、两灯积分、near/far 64/8采样、滤波、法线、BRDF和累积顺序，用带有限域守卫的保守界排除不可能贡献的球。旧整体圆锥判定与新逐球支持界组合，在进入逐灯采样前减少无效遮挡工作。没有降低球态更新频率，也没有引入跨帧近似缓存。

这是经测试支持的局部成本原因，**不是已经量出整页耗时占比**。球房其他材质、球反射、SceneKit内部pass、SwiftUI、真实呈现和预测计算仍有各自成本。

## 为什么保留这个候选

先前的方向矩、全台空间字段、分离dispatch、支持域格子均已做过实际实验。部分在近影密集样本上快，在完整栅格或真实输入下却更慢；空间字段还有插值误差和显存成本。这些路线保留了源码和反证，没有通过挑选有利样本晋级。

当前优先候选是 **guarded cone + safe-hoisted**：

- 原始单灯/整体圆锥判定与新逐球界互补；在当前灯/采样条件下有实数几何保守界，不改可见光照公式。有限域Float32实现通过下列对拍，尚无穷尽或形式证明。
- 接收点或球态超出已核对域时恢复原直接路径。支持源、灯几何、采样或槽数变化时，CPU安装门禁同样回退原请求配方。
- 没有新增纹理、GPU buffer、生成pass或CPU逐帧球态缓存。着色器局部寄存器/编译后程序资源没有独立测量，不能称“所有资源零增量”。
- 原版和plain候选仍保留，可以在同一构建中继续做直接对照。

## 正确性证据

| 层级 | 已取得的证据 | 不能由此推出 |
|---|---|---|
| 实际片元数学 | 516,599个真实可见输入，最终光照通道逐位一致 | 任意浮点输入形式证明 |
| 域和编译边界 | guard在fastMath开/关各40配置、49,664输入通过；原域外反例与错误回退版本保留 | 两种编译设置间参考本身逐位相同 |
| 真实材质画面 | 5固定机位+12移动帧、重复/恢复及11组相邻帧差分一致；覆盖图证明候选实际执行 | 完整App动态呈现节奏 |
| 完整真实开球 | R23两案例共1,194帧逐像素一致；落袋后shadow权重归零、capacity16及节点/材质身份保持，18状态162轮均更快 | 全App实时FPS、任意轨迹或所有设备 |
| 两台原生Mac GPU | 同包三臂6配置/主机，7,776测量帧，1,296测量末目标检查通过 | 所有iPhone GPU的相同比例收益 |
| 生产App | r6本地38项37过/1测试谓词误报；只修测试后r7定向1/1过，0跳过。5项页面与2项完整场景通过，45张页面图已审 | 全App回归、最低iOS17兼容或正式发布达标 |

数值证据与原失败详见[公式审查](../../output/render-lowdim-20261113/support-legacy-comparison-r1/REPORT.md)。有26个配置标签对应13份重复数据，未把它们作为26份独立随机输入。

## 原生 GPU 对照

固定包ID：`d053ea94206c08ef95cb13f557cf3417157d66af8cdff74472b25171e2ea4b3f`。同一实际USDZ台呢、normal=.65、几何抬升、MSAA4、HDR、曝光−.1。R、plain、guard三对直接比较，每对9轮交错ABBA/BAAB；每pair每臂108个独立同步render。没有删异常点。

下表为 guard 相对原 R 的配对中位 GPU command 耗时变化，负数表示更快：

| 固定场景 | M5 Pro | M4 |
|---|---:|---:|
| 两球近景700×400 | −4.87% | −3.67% |
| 两球近景1400×800 | −4.50% | −4.67% |
| 两球近景2800×1600 | −4.53% | −4.11% |
| 16球散台700×400 | −44.71% | −34.05% |
| 16球散台1400×800 | −43.49% | −42.52% |
| 16球散台2800×1600 | −46.13% | −46.25% |

相对plain，guard在M5的中位改善约4.9%–7.4%，M4约2.8%–6.6%。M4低分辨率有反向轮次，最大端点漂移24.22%；M5原R/plain的一组漂移100.24%，也完整保留。个别尾分位变差，不能说“所有帧都更快”。

这是两种球态/相机组合各自的像素规模曲线；近景与散台相机不同，不能将两行差异解释成单独改变球数的纯扩展曲线。真实逐帧P50/P95/P99、CPU编码/同步墙钟和所有配对分布见[跨机详表](../../output/render-lowdim-20261113/native-scene-guardcombo-cross-host-r1/REPORT.md)。

![两种 GPU、两类场景的像素规模与逐帧 GPU 成本](../../output/render-lowdim-20261113/cost-curves-r1/cloth-gpu-cost-curves.png)

图中每点是同一 R/guard 配对臂108个原始帧的P50，24点共2592帧，全部从原始GPU时间戳重算。它与上表“每轮配对变化的中位数”是不同统计量，不能直接用图上两点相除复原上表百分比。[原始数值、来源SHA](../../output/render-lowdim-20261113/cost-curves-r1/source-values.json)与[绘图脚本](../../output/render-lowdim-20261113/cost-curves-r1/plot_cost_curves.py)均保留。

场景是原生SceneKit真实台呢隔离场景，没有完整生产球房/R球反射/SwiftUI，因此表中收益不能乘到整页，也不能用耗时倒数称为App FPS。Simulator只用于生产代码接线和画面验证，不用其GPU时间或allocatedSize排名。

## 安装与资源成本

缓存前的DEBUG实现会校验源SHA并每次变换字符串。此前M5纯CPU暖态单次中位：原R约0.094ms、off约0.114ms、plain约4.187ms、guard约5.064ms，guard配对新增约4.973ms。R25现改为加锁复用已验证的不可变guard源码/声明；每次仍检查配置、输入和输出SHA并重新生成本次State，失败不缓存，默认R/Release/plain不变。没有增加scene或逐帧状态缓存。旧约5ms不能再作为当前暖命中的实测值；新的实际进入成本另由R24记录。

guard完整surface从21,205增加到27,463 UTF-8字节。源码长度不是GPU内存。原生宿主三档显式render target资源约13.24/50.77/201.65MB，包含MSAA、depth和readback，三臂共用；它不是候选新增资源，更不是整个App显存。SceneKit内部HDR/纹理/驱动缓存未枚举。

详见[实际Swift构造成本](../../output/render-lowdim-20261113/support-guard-live-cpu-r2/REPORT.md)。未测shader首次编译或完整App冷启动分位，不将约5ms描述为完整首次进入增量。

R24最后一次有界采集已完成72次真实VM/scene异步进入：应用资源冷/暖各9轮ABBA，108个首帧GPU计时及144个计时外图像对照，原生selector 1/1通过且离线独立复算接受成本数据。缓存后的guard相对R，VM setup配对增量中位冷+1.421ms、暖+1.029ms；setup到probe安装中位冷+18.614ms、暖+1.029ms，最坏冷轮仍+225.469ms。不能据中位数宣称所有冷进入更快，也不把VM/离屏目标当SwiftUI完整首屏或首可交互P95。[72次原值及分位](../../output/render-lowdim-20261113/native-entry-analysis-r5/summary.md)。

首帧稳定性单独保留未解决状态：36次R自身对照、36次guard对R及两组恢复，各有1次1像素/1色阶差异；每个非零PNG已独立解码。没有新增像素容差，没有用R自身误差豁免guard，`qualityAccepted=false`、`promotionAllowed=false`。三份probe纹理/SH/floor在全部72次一致，暖缓存真实对象身份、场景/renderer释放及所有源/状态硬检查通过。R23的1,194帧严格证明只保持原范围，不扩大为首帧全等。结束本阶段首帧采集，不再为了得到全PASS追加同类修订。 独立原图审查进一步确认两entry均为远侧绿色边缘同一像素的同向变化，当前机位/72次进入范围未观察到候选独有的可见差异；这是单独的产品可见性判断，原零容差数值合同仍未通过，不作全设备/全视角保证。

## 页面接入与回退

- 默认/Release：原R。普通训练页配置会清除实验请求。
- `-daily3D.safeClothSupport`：原plain safe-r3，保留其原有语义。
- `-daily3D.guardClothSupport`：当前guard组合。只在DEBUG、每日配置中显式启用。
- 两开关同时出现：回退原配方，原因`conflicting-support-flags`。
- 非R、非reference采样、非16槽、merge/factor/prototype/balance冲突或源漂移：回退原请求程序，不只把开关文字记成“已生效”。
- 诊断记录请求、实际安装版本、容量、采样和回退原因。桌缓存、probe缓存包含候选身份；容量扩张后重新判定。off的probe身份恒定，避免给默认路径增加扩容重烘焙。
- 正式2D、3D和临时俯视会消费同场景材质，三者都纳入页面核对；未修改物理、相机或产品设置项。

回归状态、快照、失败修复与实际截图入口见[页面检查表](PAGE-CHECKLIST.md)。本地iPad Pro13/iOS26.3.1的38个目标方法已有通过证据：r6为37过/1失败，r7只修测试谓词后定向1/1通过，所有App构建输入与r6相同。r5、r6原失败不改写为通过。

三房间风格×三配方共36张模式/恢复截图，以及两候选方向/击球6图、回退3图，共45图与对应状态已核对。guard生产完整球房4配置的12组图像对照全部RGBA精确一致，红控有效。页面截图是定性审查和状态证据，不是逐像素对拍或FPS结论。方向用例也不替代精确杆向增益、物理准确性或用户手感验收。

Release边界：原生成核心已做Release条件编译/输出校验，但完整Release App尚未构建。补充构建预飞发现冻结源不含被忽略的`Secrets.xcconfig`，现有发布脚本又要求合法生产HTTPS API配置；未填虚构配置或绕过门禁。纯注释include overlay的[受管编译计划](../../output/render-lowdim-20261113/release-app-build-r6-plan/plan.json)已保存，未执行，不记成构建通过或实际构建失败。

## 复现入口与下一步

原生独立实验：[最小复现说明](../../output/render-lowdim-20261113/native-scene-guardcombo-report-preflight-r1/REPRODUCE.md)与`scripts/research/cloth_lowdim_20261113/native_scene_run.py`、`native_scene_compare.py`。原始包保存三份完整程序及素材清单，GPU运行按主机串行协调。

App关键选择器：`DailyClothSupportExperimentTests`、`ClothSupportPerformanceResearchTests/testProductionInstalledGuardComboFullSceneImageEquality`、`ClothSupportPageResearchUITests`。使用项目受管模拟器/远端统一队列，实际命令保存在页面检查表链接的JSON内。

当前选择guard组合继续后续验证，不再扩张已测且未满足本轮准入条件的低维/空间字段实现，这不代表否定整个算法家族。已有跨规模、跨GPU和画质证据足以支持本轮候选排序；下一项有价值的工作是验证它在完整页面成本中的占比，而非继续堆同类微基准。

最低iOS17、整页原生GPU占比、实际呈现、长期资源趋势和持续交互仍待后续实测。截至R15，用户明确手机和Mac mini暂不方便，彼时未继续连接远端或占用手机；后续本Mac原生与手机手动试用的新授权/结果见下方R16。远端r6作业状态未知、不重复提交，约1GiB原生实验临时副本尚未删除；其性能原件此前已完整回传校验。后续补验继续采用固定输入配对和多档硬件证据，不让单手机状态成为算法优劣的唯一标准。

“最佳”指这次候选集合与已测条件中最有依据的选择，不是所有可能架构的全局最优。


2026-11-13后续：用户要求手机手动试用，已将已验证r7源码的Debug -O包成功构建、签名、覆盖安装并用guard参数启动到iPhone16Pro，首页与存活进程已核；此为部署和试用交付，不是手机性能/温升结果。现有数据保留，强退后图标重启恢复R。[交付证据](../../output/render-lowdim-20261113/phone-preview-r7/SUMMARY.md)。完整原生研究仍继续，手机留给用户操作。


## R16新增：完整生产场景原生成本

已在M5 Pro的Designed for iPad原生App中完成r9构建与精确测试1/1、0跳过。两档分辨率共864测量帧、144同末目标检查、20PNG独立核对（12组RGBA完全相同），GPU校准重/轻负载比26.149。

| 固定场景 | 像素 | R GPU帧P50 ms | guard GPU帧P50 ms | 九轮配对变化中位 |
|---|---:|---:|---:|---:|
| 两球瞄准视角 | 700×400 | 0.4262 | 0.4270 | +0.57% |
| 16球散台全桌 | 700×400 | 0.8759 | 0.4873 | −44.15% |
| 两球瞄准视角 | 1400×800 | 0.7570 | 0.7480 | −2.14% |
| 16球散台全桌 | 1400×800 | 1.7236 | 0.8693 | −49.99% |

16球两档均9/9更快；两球变化小且1400基线组内漂移最高39.03%，不认定可靠净收益。表中P50和配对百分比属于不同统计量。此次含真实生产球房、球模型/材质及R probe；仍不包含页面更新/预测/HUD/present、首编或guard probe生成，不把GPU span倒数当FPS。[完整原值、CPU与漂移](../../output/render-lowdim-20261113/native-production-r9-analysis/REPORT.md)。

## 2026-11-13 暂停断点

用户先要求当前阶段收尾后停止，随后明确将研究目标设为 paused。本轮不再开展采集、构建或下一轮实验。手机保持已交付状态，未再次启动或操作；Mac mini 仍不连接。

本机整页烟测 run `aab7c302ec2149a9ae569debe7e9738d` 在测试开始前被 Xcode 拒绝：`UI tests are not supported on My Mac (Designed for iPad)`。实际执行0项、0阶段标记、recorder未启动；[原始日志](../../output/local-test-runs/aab7c302ec2149a9ae569debe7e9738d/evidence/tests.log)与[结果](../../output/local-test-runs/aab7c302ec2149a9ae569debe7e9738d/evidence/result.json)保留，不认定候选失败或页面通过。诊断关闭后按生命周期回收该轮work，原exit_code=1保留；实际可用空间变化−4096字节，不宣称释放了显著空间。

CUA随后尝试打开 r9 的 `Debug-iphoneos/球迹.app` 原始产物，LaunchServices返回 `-10661 kLSExecutableIncorrectFormat: No compatible executable was found`；未成功打开窗口，未采集trace。该结果只证明这个直接启动入口不可用，不否定已经通过的Xcode原生unit宿主。CUA会话已结束。

恢复时先解决受支持的原生App安装/包装/启动入口，再做短时Game Performance结构烟测；确认真实App PID、实际3D工作与非空数据表后才进入正式整页R/guard配对。不得重复执行已证不支持的原生UI XCTest，不能把启动命令返回或模板存在当采集成功。既有fixture的SwiftData内存模式不隔离全部UserDefaults；使用前须核对清台草稿与会员等持久副作用。

保留的r9产品属于受管run `599cb6efc8f14aca9cc9f04092ad44a7`，state=complete且hold非空，供恢复后继续；其冻结输入SHA为 `82f6dc2d0cfad3480a8ef7c88c9068d328fb7d169ffc0d07d5ae8bcfd36702ff`。没有提交、推送或改变正式R默认。


2026-11-13恢复：用户要求从上述断点继续整页性能验证、每轮记录并持续优化。先核受支持的原生启动入口及数据隔离，再做短采集结构验证；原暂停事实与失败证据保留，未将其改写为成功。手机和Mac mini继续保持先前授权边界。

## R17新增：真实页面与轻量采集链路

已通过Xcode实际生成的outer wrapper进入本机原生App、完成首次引导并从训练首页进入每日清台3D。实际PID2918的executable SHA与r9一致；无fixture/reset/虚拟会员/diagnostics参数，展示16球开球准备，未击球。正常UI产生的引导和3D偏好写入不描述为“全隔离”。本轮结束时已正常退出App并核实进程消失。

两次短采集分别保留：

| 运行 | 已取得事实 | 性能边界 |
| --- | --- | --- |
| r1 `9625f2...`，离线恢复`79463ce...` | 原录制封存等待超时；副本恢复TOC与12表。App CPU/footprint可读，App GPU事件0；六次相机操作晚于真实窗口1.55秒 | 原run仍failed；没有活动负载或候选收益，不能用其它进程的88,739条GPU事件补数 |
| r2 `cf10c021...` | 真实收到Darwin开始通知；通知后约11.49–15.50秒完成六次相机切换，AX选中均成功，前后杆数0 | 保存阶段ENOSPC；无summary/TOC/核心表，实际覆盖未证实，不计性能 |

r2的owner8100/recorder8107已退出，但收尾写盘失败留下`run.json state=running`；这不是仍在正常采集的证明。主控用cwd/fd证明DTServiceHub8121归属后，将约12GiB ktrace同卷移存到原run/work，再只终止该owned服务；服务退出、无句柄，原文件及SHA、约41MiB partial trace当时均保留，run已protect hold。r1单个约12GiB、无句柄的中间ktrace另已按hash/inode检查回收，原最终trace及恢复证据不动。见[失败与恢复记录](../../output/render-lowdim-20261113/native-trace-storage-recovery-r1/REPORT.md)、[r1回收收据](../../output/render-lowdim-20261113/native-trace-storage-recovery-r1/retired-r1-ktrace.json)及[r2服务恢复收据](../../output/render-lowdim-20261113/native-trace-storage-recovery-r1/r2-service-recovery.json)。原含环境元信息的证据只在私有目录保留，分享报告仅白名单字段。

后续已对r2 raw作无损压缩：**12,916,584,376B → 1,637,281,564B**，流式解压的长度与SHA均和原件一致，才删除冗余raw；gz、partial trace、日志与原失败/hold状态保留。收据确认其余保留证据前后hash一致，完成时`df`可用约32GiB，不把压缩视为原录制成功。[无损压缩与恢复收据](../../output/render-lowdim-20261113/native-failed-r2-lossless-compression-r1/recovery-receipt.json)。

原r1/r2失败保持原状态；以下记录后续轻模板和正常系统启动入口，不把新成功补回旧run。

状态保护run `5f460463924f402bb2367732db2eec99`在Data根首次open即EPERM，尚未复制、未产生完整备份或执行恢复。精确defaults导出仅得到不可核实的空字典，未采用为回退材料。已结束这一阶段保护探索，不改权限、不遗漏用户文件；后续沿正常用户每日盘面，仅加诊断/guard进程flag，不使用reset、fixture、premium或合成身份。[真实失败与当前范围](../../output/render-lowdim-20261113/native-page-state-isolation-r1/SCRIPT-REVIEW.md)。

`xctrace --launch`运行`bd0c920cfda447648cdd4e39f0075c60` exit54，涉及两个不同App PID：14506的崩溃报告为签名无效，14503存活但停在dyld启动且未进入正常页面，不能混为同一次崩溃或渲染卡顿。主控只对已核14503收尾并确认消失，随后通过系统`open -a <outer> --args ...`正常启动，核新PID16480及四诊断flags，再由CUA实际进入首页/每日3D。[启动失败审计](../../output/render-lowdim-20261113/native-launch-diagnostics-smoke-r1-analysis/REPORT.md)。

独立attach运行`41536a261eb445ccac77fd803ce0d6ec`使用Time Profiler＋Activity Monitor＋os_signpost，20秒录制，recorder exit0、trace封存、TOC与导出正常完成。六次真实UI动作仅1次完整落在窗口、1次部分重叠、4次窗外；这不等于完整连续相机流程通过。当前仅得到CPU轻链路，缺GPU/time-info表，不据此报整页GPU或FPS。

独立原始样本审查取得1,541个各1ms的Time Profiler running样本：`updatePocketAccessibility` inclusive命中1,111个（72.096%），`dragProbeValue`76个（4.932%），两者调用栈有重叠，不能相加。四诊断flags中额外的`-3dDrag.probe`触发渲染更新中的可访问性重建，`-renderProfileProbe`遍历节点/材质并检查shader字符串；这是探针负担证据，**不是生产页面CPU分布或guard净收益**。signpost去重9事件、0完整interval，其中8事件在TOC内；Activity末样本早于实际输入，CPU累计量/footprint不作活动全程均值。[独立白名单报告](../../output/render-lowdim-20261113/native-direct-smoke-r3-analysis/REPORT.md)及[复算数据](../../output/render-lowdim-20261113/native-direct-smoke-r3-analysis/analysis.json)已冻结，本轮不准入性能比较。

## R18：首对正常页面CPU采集已分析，不作排名

新进程移除`-3dDrag.probe`、`-renderProfileProbe`、`-dailyLayout.probe`，仅保留`-daily3D.diagnostics`；guard臂再加其候选flag。使用原有每日存档：中八、manualRacked、16球、0杆，没有fixture/reset/premium或身份覆盖。两臂同一二进制及真实盘面，configuration事件确认R/off与guard有效安装、无fallback；它们在idle后记录selectedFPS=60、scheduledFPS=30，不能据此证明活动段呈现60 FPS。

首对各录60秒：R run `5de45c13328e4806b0402ead0ff217b3`、PID18031；guard run `6f4cb8edda3b4a3480ba7b35b2f2edde`、PID18875。两臂各24次相机选择均完整落在各自TOC窗口，顺序相同、AX选中与0杆有收据。每臂却仅导出45条目标事件，input/firstRender/wake为sequence11–24，缺前10次input及orbit Begin，完整stage均为0。真实动作落窗与完整阶段验收是不同事实。[冻结报告](../../output/render-lowdim-20261113/native-page-cpu-pair-r1/analysis/REPORT.md)、[复算数据](../../output/render-lowdim-20261113/native-page-cpu-pair-r1/analysis/analysis.json)、[R动作](../../output/render-lowdim-20261113/native-page-cpu-pair-r1/reference-actions.json)、[guard动作](../../output/render-lowdim-20261113/native-page-cpu-pair-r1/guard-actions.json)。

描述性24动作粗ROI的包围区间CPU计数为R **3,611.846ms**、guard **3,663.794ms（+1.44%）**，而Running样本权重为3,344/3,595ms（+7.51%）。仅取可见input11至orbit End的14动作尾段，CPU计数为2,176.440/2,141.298ms（**−1.61%**），样本权重反为1,899/2,143ms（+12.85%）。粗ROI起点来自外部CUA墙钟、计数区间多含不同边缘时间；单对顺序R→guard无反向重复，计数与抽样不能互换，不同边界也不支持稳定方向。**rankingAllowed=false，不把这些百分比称为改善或退步结论。**

去掉额外probe后，它们不再主导采样；每次动作后的整树AX查询仍有明显成本，递归属性读取inclusive权重约占R **34.0%**、guard **30.9%**，约三分之一，相关栈有重叠不能相加。因此采到的是页面加自动化读取的CPU，不能当生产净CPU；它也没有GPU或present数据。**尚未完成ABBA、完整页净收益或连续多球运动结论。**

## R19：活动完整，系统GPU汇总可读，标准关联仍缺失

首个guard run `5d64f8b942ef464ab7b57da459e2e7dd`附加PID18875，使用Metal System Trace＋os_signpost、60秒录制/70秒滚动窗口，入口空间门槛20GiB。虽将四项CPU采集选项设为false，该模板仍自带CPU采样，不能称纯GPU或无采集开销；20GiB也是启动门槛，不是已测峰值上界。

24次点击采用事先观察位置的固定批次，每次hold400ms，中间不做整树AX查询，末尾仅做一次AX读回。[动作收据](../../output/render-lowdim-20261113/native-gpu-capability-r1-ui/actions.json)仅逐项记录`clickReturned`，`perActionSelectedStateVerified=false`；最终为thirdPerson、3D、0杆。冻结分析另核到24条连续App input、24条firstRender/wake及完整**11.627789秒orbit**；这证明实际输入和活动区间，仍不等于逐项AX选中或显示FPS。

采集正常封存；目标PID标准GPU、CB与frame-assignment表均为0行，不能拿其他进程/driver GPU补数。但目标PID的FramePacing实际有一个Shared Image Queue、**61组系统汇总（10非零、51零）**；重复视图及相同Begin/End payload均只计一次，保留全部原值。系统reported GPU与显示指标可用于同条件对照，但Shared Image Queue不是MTLCommandQueue，层Name为空，不能证明覆盖全部页面合成；汇总不能恢复逐CB时间、分位数或精确FPS。[冻结分析](../../output/render-lowdim-20261113/native-gpu-capability-r1-analysis/REPORT.md)、[完整字段](../../output/render-lowdim-20261113/native-gpu-capability-r1-analysis/analysis.json)、[第一方语义审查](../../output/render-lowdim-20261113/native-gpu-metric-semantics-r1/REPORT.md)。该轮只采guard，后续R参考臂见R20。

## R20：参考臂分析完成，系统汇总差异仍不排名

R run `eb7a99936a4844ea8e1bb9e24444b16f`、PID25915正常exit0、封存和导出。实际24条input（sequence1–24）、firstRender/wake各24，安装为off/R/reference、16、MSAA4、scale2。但第4/16/23次点击实际wall包络为1005/1035/1020ms，R分成4个完整orbit（合计11.922213707秒）和3段中间idle（1.314707083秒），包络13.236936333秒；guard仅1个连续orbit（11.627788583秒）。相同点击脚本不等于同一实际活动负载。[分析报告](../../output/render-lowdim-20261113/native-gpu-reference-r1-analysis/REPORT.md)、[原始字段](../../output/render-lowdim-20261113/native-gpu-reference-r1-analysis/analysis.json)。

按系统报告的Frames计数加权，OnGPU均值R **5.304352728ms**（14非零组、708帧），guard **5.048226891ms**（10组、559帧），描述性差值**−4.8286%**。此外guard此前已完成R18的24次相机动作，R是新进程首24次动作，预热不匹配。`rankingAllowed=false`；这一差值不证明整页净收益、台呢独占成本、逐帧分位或FPS。两臂观察到的层尺寸同为2660×1996 pixels，但Shared Image Queue不是MTLQueue，标准GPU/CB目标行仍0，不能声称所有合成都已覆盖。[带边界的对照数据](../../output/render-lowdim-20261113/native-gpu-reference-r1-analysis/comparison.json)。

本run的精确owned work缓冲已回收，664份封存证据的hash前后验证不变，未触碰App；收据完成时可用空间**31.30GiB**。[清理收据](../../output/render-lowdim-20261113/native-gpu-reference-r1-cleanup/receipt.json)。

## R21：官方逐drawable首对已分析，覆盖不足，不排名

两臂同一r9 App、新进程各24次预热及24次测量，轻Time Profiler＋Activity Monitor＋os_signpost模板下，官方逐帧环境选项实际生效。系统`OnGlassDrawableInterval`配对R426/guard566，无字段不匹配或未配对端点，重复视图去重。完整落在实际orbit内的严格样本为415/564，reported OnGPU均值**4.574→4.326ms**，仅作描述；OnGlass均值**16.664/16.668ms**，没有显示明显节奏改善，不换算FPS。[冻结报告](../../output/render-lowdim-20261113/native-page-perframe-r1/analysis/REPORT.md)及[逐drawable原值](../../output/render-lowdim-20261113/native-page-perframe-r1/analysis/pair-analysis.json)。

严格样本的显示时长只覆盖R活动的**62.23%**、guard的**81.82%**；R另有一次idle/wake，实际镜头时间构成不同。边界carrier及Drawable ID跳变均保留，不能解释成真实卡顿、漏帧数量或完整页面排名；输入时间标签也不证明GPU执行时的精确相机姿态。CPU计数包围区间为2303.607/2436.732ms，未见下降，但含不同边缘时间，不能与GPU相加或归因候选。`rankingAllowed=false`。[覆盖补充](../../output/render-lowdim-20261113/native-page-perframe-r1/analysis/coverage-amendment.json)。本阶段停止扩建或追查采集，转向真实rack与scatter的同场景验证。

## R22：真实rack补验证通过，球态布局影响收益

冻结[r10 manifest](../../output/render-lowdim-20261113/ios-snapshot-r10/manifest.json)`8f202f4d…`、受管run `e9a1154d959e461da08e6ecee1d40359`的精确native选择器**1/1 Passed、0 skip**，严格分析通过。5个固定场景共1080测量帧、180次harness报告的同末目标检查；25张PNG独立解码，各场景R/candidate、repeat、restore三组RGBA完全一致，红控有效，GPU校准重/轻比27.1657。生产3439个输入与r9的SHA和可执行位一致，无增删改，沿用原快照排除范围。[验收与全部原值](../../output/render-lowdim-20261113/native-production-r10-rack-analysis/summary.json)。

同为**1400×800、16球overview**，rack的R/guard GPU帧P50为**0.972208/0.819313ms**，九轮配对变化中位**−16.0115%**，9/9更快，范围−26.1792%至−11.4386%；最大R端点漂移36.766%保留，P50比值与配对中位不是同一统计量。scatter1400同轮配对为**−50.9605%**，scatter700为−41.1860%，均9/9更快；两球分别+0.7812%/−0.9111%，不认定收益。主控另打开rack原图核真实球房、绿色台呢和球堆，四张R/candidate/repeat/restored PNG的文件SHA相同。

这支持**相同球数、不同分布会有不同成本和优化收益**，固定rack场景也取得下降。测量仍是完整生产SceneKit固定场景与同一R反射probe，未包含SwiftUI页面、probe生成、镜头切换、动态球或呈现FPS；不能把scatter约50%的收益推广到这些路径。


## R23：真实开球、进袋与旋转尾段完成

同一原生M5 Pro / Designed for iPad、1400×800、MSAA4、Debug-O完整生产场景。两个已有回归案例各只求解一次，直接运行生产SCNActions；每个60Hz时间点用同一球态做R→guard→guard重复→R恢复，全程不赋回姿态或重建轨迹。9个均匀状态到达时各跑9轮ABBA/BAAB，记录真实command GPU时间戳。

| 案例 | 完整帧数 | 初态GPU配对中位变化 | 后续八状态配对中位变化 | 更快轮次 |
|---|---:|---:|---:|---:|
| 旋转尾段 | 547 | −17.81% | −45.53%～−48.11% | 81/81 |
| 进袋与收球轨道 | 647 | −17.77% | −40.34%～−49.81% | 81/81 |

共3,888计时帧、648次测量末目标检查；1,194帧及相邻帧差分完全一致。24张保留PNG已独立解码；主控目视核末态真实球房、散台及袋外轨道中的1号球。最差单轮仍为−14.13%，参考臂端点最大漂移69.54%原样保留，不能声称每个单帧或所有未来场景都更快。两球近景仍沿R22“不认定可靠收益”。

这是实际动态球态的渲染对照；各计时点暂停推进动作时间，测量CPU动作更新、读回、校验、首次编译/反射生成、SwiftUI及真实呈现不在GPU区间内。同一R反射probe由两臂共享，仍不声称候选独立probe生成成本已闭合。生产spin-tail时间映射照常使用，未删去尾段；开球收尾后的业务交付/刮杆补球不属于这项图像对照。

原生构建、精确selector **1/1 Passed、0失败/跳过**：run `b50521edbd584bdea0300aa890caf580`，冻结快照`70ef7962b453857e3a901a701f1d3b6605c3049ee94f7cde7613ba55a77ed3c6`。生产输入与r10一致，仅测试变化。主控运行[独立分析](../../output/render-lowdim-20261113/native-dynamic-r16-analysis/REPORT.md)通过；[完整原值/来源/边界](../../output/render-lowdim-20261113/native-dynamic-r16-analysis/summary.json)，摘要SHA `1e4a0b84c18b37cafd55e58b0a93ea4a97ba56cfe4f23bba0a183a4c7fa23b16`。

本轮前几次测试入口失败、无袋案例误设、姿态重放失败、内存上限终止及编译修正均留在ITERATIONS，不抹为通过。最终逐帧autorelease释放后，17个每2秒RSS样本的观测最大约1.13GiB，宿主正常结束；这只修复测试同步循环的对象累积，不代表生产App节省了同等内存，也不是完整生命周期/显存峰值结论。[离散RSS记录](../../output/render-lowdim-20261113/native-dynamic-r16-memory/summary.json)。
