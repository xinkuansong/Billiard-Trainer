# 最终优化版本真机集中验证

2026-09-21，用户重新连接手机并明确授权测试，确认正常温度。iPhone16Pro/iOS27，最终模拟器验收源码SHA无漂移；make build-device-profile成功（Debug -O），覆盖安装成功，不卸载清数据。启动参数仅本进程renderFrameRate=60，原画质/采样/MSAA保持。

证据目录：`build/daily-final-device-20260921/`，包含源码补丁/哈希、构建日志、设备信息、安装启动JSON与主程序SHA。主程序SHA256：cf840ea1859f9e6ee75dfc795d471fa0d3f35053ccfc2a9a87ddfc531b11a689。

当前：2D静止20秒与正常操作40秒已录制，用户确认约6杆并反馈开始有些发烫；停止继续加压，3D待手机冷却及后续采集。分析区分进程归属和有效事件窗口。旧短时独立渲染候选数据不能当作本轮整页对照。

App PID：7881。启动参数第一次缺少分隔符被CLI拒绝，补--后成功，未形成额外录制。

## 2D集中采样
- 静止：用户确认球停稳，Game Performance + Activity Monitor + Thermal State附加PID7881，20秒录制成功；有效CPU跨度19.36秒，平均2.64%（单核100%），相邻样本峰22.25%，footprint首/末/峰1107.58/1045.61/1116.22MiB；全段Nominal。GPU表未捕获属于App的Active depth0区间，不能写成硬件GPU利用率为0。
- 正常操作：用户回复开始后启动40秒同组合录制，工具确认启动后提示操作，到时提示停止；录制成功，用户回忆约6杆；热状态全40.717秒为Nominal。此分级不等于机身不热，未采到表面温度数值。
- 用户反馈“开始有些发烫了”，已停止进一步负载，未进行3D测试；用户补充确认录制期间约6杆。不能声称发热已解决或与旧版有可量化温降。


## 已有记录分析及缺口

- `activity-monitor-process-live`、`metal-gpu-intervals`、`time-profile` 各3次导出均SIGSEGV（-11），目录导出也exit139；原trace和失败日志保留。这是Mac导出进程失败，不能记为App崩溃。当前无可信的操作段CPU均值、GPU耗时或调用栈归因。
- `displayed-surfaces-interval.xml`有效515行，其中513行明确标识球迹PID7881，但只保留30.209–40.694秒末段。495行显示驻留16.67ms，13行33.34ms，另有12.5/20.84/300.05/383.40/1100.19ms各1行。长驻留也可能是静止按需渲染；缺少逐时刻运动标注，不能直接判为掉帧，更不能给整40秒平均FPS。统计见`2d-active/display-summary.json`。
- `metal-command-buffer-completed.xml`有效1484行，但没有执行时长字段；提交完成数量不能代替GPU时间或利用率。
- GUI回退曾打开正确trace，但随后窗口转到旧`2d-active-confirmed`（PID6138）；未从旧窗口引用本轮CPU/GPU结果。
- 结论：已确认静止CPU低、40秒约6杆仍有主观发热；当前不足以量化最终整页CPU/GPU收益，也不能证明物理引擎是主要热源。先解决已有记录的读取问题，再决定最小范围补采；不因导出失败立即要求用户重做整套测试。

导出故障进一步定位：本轮063822崩溃报告为EXC_BAD_ACCESS/SIGSEGV，栈为objc_release → XRRemoteDevice.setCachedBaseSymbolsPath → baseSymbolsPath → FileStatus.isSystemFramework → ProcessLoader.load，故障落在Xcode真机符号加载路径。摘要归档export-crash-summary.json；这是读取阻塞的定位，不是游戏发热根因。GUI替代读取未取得当前CPU/GPU数值，不据此补造结论。

## 局域网、不充电复验（进行中）

用户确认已冷却、已拔线且无无线充电、2D静止。devicectl确认localNetwork/connected；原优化包重新启动PID7958，60fps启动参数。新证据独立存wireless/，不覆盖旧trace。已创建并校验ios-device-performance技能（Skill is valid!），项目适配器已接入。Instruments按PID和名称附加分别报告找不到进程，而devicectl确认PID仍存活；改用5秒全进程采样预检，尚未要求用户击球。

无线预检结果：5秒Time Profiler + Activity Monitor + Thermal State全进程录制成功，probe-system.trace已保存；toc和CPU表导出均exit139。070414崩溃栈仍为objc_release → FileStatus.isSystemFramework → ProcessLoader.load。无线传输已验证，但CPU/GPU分析链路未通过；停止追加采样、未录操作段，不能提供不充电温升结果。用户无需继续保持页面，先处理Mac工具读取故障。


## Mac读取恢复（2026-09-21）

用户补充：拔线无线运行仍发烫；未提供这一段精确时长/杆数，不与原6杆采样混合。当前仅离线处理，无新增手机负载。

- Xcode 26.2（17C52），macOS 26.4。仅在导出进程设置`LIBDISPATCH_COOPERATIVE_POOL_STRICT=1`后，同一2d-active.trace目录、CPU40行、GPU10696行、Time Profiler3182行全部exit0/有效XML。无线5秒probe的CPU1441行也成功。重复CPU导出逐字节一致，见read-recovery/verification.json。未修改Xcode安装、全局环境或被测App。
- 结论：已验证可用的离线读取绕过；栈和绕过结果提示符号加载并发相关故障，尚未证明Apple内部具体根因。恢复脚本复用了原attempt1路径，三个表的attempt1被成功输出替换；attempt2/3和原整体失败日志、崩溃摘要、trace仍保留。
- 原40秒约6杆采样：CPU有效跨度38.839秒，均值20.83%（单核100%）、相邻样本峰41.37%；footprint峰1224.69MiB；全段Nominal。
- CPU调用栈只覆盖30.177–40.714秒，PID7881权重3182ms，SCNView.drawAtTime包含1368ms（43.0%），PositionPlayShotSolver.solve包含47ms（1.48%），EventDrivenEngine.simulate包含41ms（1.29%）。这些是包含子调用的采样权重，不能相加；仍有未符号化地址，末段也不能外推六杆全程。当前证据支持优先排查渲染路径，不能证明物理完全无关。
- GPU有效窗口30.180–40.716秒，App归属depth0 Active区间：Fragment累计4073.67ms、区间p95 7.73ms/max11.97ms；Vertex累计1256.71ms；Compute16.06ms。不是整帧时长/整机利用率，通道可能重叠，不能直接合计为GPU负载百分比。
- 工具读取缺口已恢复；不充电整页操作对照、3D及持续温升验证仍未完成。


## 渲染热点细分（已有trace离线分析，无追加真机负载）

证据：read-recovery/render-cpu-breakdown.json、render-submission-summary.json，以及新增导出的metal-application-encoders-list、metal-application-intervals、metal-application-command-buffer-submissions；全部串行协作池导出exit0。

- GPU末段10.535954秒，PID7881 depth0 Active的所有通道取区间并集5.200653秒（该窗口49.36%），Fragment并集4.073669秒，Vertex1.256707秒，Compute0.016055秒。此处是App归属的时间覆盖率，不是GPU硬件利用率/功耗，包含静止间隔；不同通道不可直接相加。
- SceneKit四类encoder各516次：Render Command 0编码累计418.62ms；Compute Command 1累计24.75ms；Render Command 2累计517.03ms；Render Command 3累计29.51ms。主要4-encoder提交516次，各工作线程有效编码中位约1.88–1.99ms。encoder数量不等于draw call数量，通用标签不能据此确定具体材质。
- root-layer 21次，编码累计2.363ms、中位0.0975ms；仅代表这条Metal编码路径，不是完整SwiftUI CPU开销。没有证据把主要编码成本归因于页面HUD。
- IOKit叶采样533ms中，501ms位于独立GPU命令队列提交路径；另27ms在SceneKit材质/几何渲染资源缓存替换、Metal Buffer析构路径。SCNView绘制1368ms中，仅28ms同时匹配IOKit叶/具名等待路径。不能把全部SCN绘制权重解释成等待，也不能把IOKit trap都解释成纯CPU计算。
- 源码核对：AngleTrainingScene相机模式会在2D隐藏reference_room、groundVisualNode、tableContactShadowNode，当前没有“2D仍绘制房间”的证据。原阴影采样/物理精度/60fps/MSAA保持。

优先级：先将主要Render Command映射到实际材质/绘制项，区分台呢光照、球面反射、原生PBR和后处理；随后做等画质的同场景对照。当前trace无足够shader级归因，不能断言4.07秒片元全来自球影，也不能据通用encoder标签直接删渲染通道。材质资源缓存替换值得单独定位，但27ms采样不足以作为首要热源。物理预测目前低于渲染，排在后面。此次只深化诊断，未凭推测更改产品着色器，未宣称新增降温收益。

后续参数提交优化、跨系统回归和最新无线安装状态见 [渲染跟进报告](DAILY-CLEARANCE-RENDER-FOLLOWUP-20260921.md)。原采样数字属于之前的构建，不作为新参数合并后的性能结果。
