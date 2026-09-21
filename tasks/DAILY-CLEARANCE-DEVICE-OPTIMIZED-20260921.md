# 每日清台优化构建真机复测（进行中）

2026-09-21，iPhone 16 Pro，连接 UDID 00008140-0009682918A2201C。用户确认已恢复正常温度后安装。构建为 Debug + SWIFT_OPTIMIZATION_LEVEL=-O，不是 Release；包含取消过期预测及严重热状态 30 FPS 策略。通过新增 `scripts/Makefile build-device-profile` 构建，BUILD SUCCEEDED，devicectl 安装启动成功，PID 6808，未卸载或清数据。主执行文件 SHA256：70531e63feb8686c66e94473f51f03055bae67dc7b91e78c287735e815ae3b25。

## 当前数据

采集 Time Profiler + Activity Monitor + Thermal State，CPU 100%表示一个核。均值为累计 CPU time 增量 / 样本墙钟；峰值为相邻样本区间差分。不是 GPU 利用率或功耗。

| 场景 | CPU有效跨度 | CPU均值 | 区间峰值 | footprint首/末/峰MiB | 系统热状态 |
|---|---:|---:|---:|---|---|
| 2D球停稳静止，15秒录制 | 14.31秒 | 2.35% | 20.81% | 1015.85 / 1016.03 / 1016.05 | Nominal |
| 2D用户确认正常瞄准击球，40秒录制 | 39.19秒 | 2.60% | 8.42% | 1092.35 / 1019.66 / 1092.35 | 全段Fair |

用户在第二段后报告“温热”，并再次确认在录制提示之后实际瞄准、击球并看到球运动。第二段采样负载与操作描述仍有未解释差异：time-profile 967个1ms样本覆盖1–40秒，主要为帧调度，updateFramePacing包含310ms、节点枚举228ms，未捕获明确的预测/球运动渲染热点。已复核仍为同一主进程6808。**不能用这段均值对比旧包25.09%就宣称性能或发热改善约90%；不能将此样本当作已验证有效的连续击球负载。** 下一步单独GPU采集，核对真实渲染活动。

静止显示帧调度遍历节点有持续成本，但其绝对量小，尚不支持它是明显烫手主因。Nominal和Fair是系统热压力等级，不是机身温度读数。两次采样初始热状态不同，不能归因于本次40秒动作。

## 采集限制与证据

xctrace XML导出间歇SIGSEGV：Activity/Thermal重试得到有效XML；第二段time-profile虽返回-11，已写完可解析967行XML，保留返回码与原文件；第一段time-profile三次均无有效XML。导出器崩溃不是手机App崩溃。

证据：`build/daily-performance-device-optimized-20260921/`，含build-context.json、binary.json、source.patch、build.log、install.json、launch.json、两份trace、录制日志、XML及metrics.json。GPU复测待用户准备；3D主动场景、持续功耗和长时间降温仍未完成。未提交/发布。

## 追加：2D GPU 30秒采集

独立串行 `Game Performance + Thermal State`，仍附加PID6808。录制启动后提示用户正常瞄准击球，30秒到时停止，未再发起负载。数据确认球迹存在大量GPU执行，解决“是否有真实渲染活动”的本段证据缺口，但不能反推前一CPU窗口为何缺失操作栈。

GPU XML共19565行；只取球迹6808、Active、event-depth=0，排除backboardd、无归属及嵌套事件，4474区间。有效GPU事件约1.96–31.18秒。各通道内区间并集与时长求和相符：

| 通道 | 区间数 | 执行累计 | 区间P95 / 最大 | 平均提交至开始延迟 |
|---|---:|---:|---:|---:|
| Fragment | 1933 | 9063.75ms | 15.27 / 18.99ms | 7.67ms |
| Vertex | 1915 | 1700.89ms | 1.73 / 5.44ms | 2.03ms |
| Compute | 626 | 14.90ms | 0.043 / 0.224ms | 0.87ms |

这是GPU通道执行区间，**不是完整帧耗时/帧率，也不是硬件利用率、带宽或瓦数**；跨通道不能相加当整帧。片元累计约为顶点5.3倍，片元区间长尾明显，支持优先检查材质、阴影、多pass和实际渲染像素负担，尚不能指认某一shader。此时热压力高，也可能影响耗时，不能与旧包片段做优化比例比较。

Thermal State从该trace开头到31.18秒全段Serious。用户在之前CPU段后反馈温热；GPU段尚无追加触感反馈。已经告知停止加压并冷却，**优化构建仍出现严重热压力，降温验收未通过**。状态起始已Serious，因此不能宣称是这30秒GPU录制造成升温，也不能排除连接/采集扰动。

GPU/thermal XML导出返回-11但文件完整可解析；command-buffer XML1974行有效。displayed-surfaces及allocated-size三次导出均失败，不报告本轮帧统计或GPU分配内存。证据位于2d-gpu.trace、2d-gpu/*.xml、gpu-metrics.json及各attempt.log。`git diff --check`通过。下一步应先在可重复同球形下做渲染参数单变量对照，再以冷却真机验证；3D主动测量未做，避免继续加热。
