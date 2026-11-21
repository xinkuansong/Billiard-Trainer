# R6整合预检（R5通过前不启动实施）

真源：[v66.7](../../问题集合_v66.md) §5–§8。当前R5候选验证中；此文件是后续接线与验收设计，不算R6进度。R3/R4截图与数值只能支持对应源，最终改动须按影响重新验证。

## 性能与连续性

- 保留R0固定样本、误差预算和R1同机20暖态原始数据。新档分离后的端到端输入→可见预览、点击→出杆首帧必须实际计时，不能拿函数返回或球开始移动时间冒充出杆首帧。
- 待查成本：TrajectoryRecorder.spatialStateAt对每次240Hz查询使用last(where:)遍历局部区间；16球冻结P95曾为143.155ms。可考虑有序区间二分，但必须维持端点/同刻优先级及无序/嵌套旧语义，先对照真实recorder输出与基线，不改物理迭代阈值。
- 16球solve P95原为939.099ms，编码411.541ms；编码已在R5候选下沉后台，但求解与路径整理仍需测量。普通预览≤200ms、有效命中首帧≤100ms、普通未命中≤350ms、16球≤1s为原提案目标，不事后改阈值。
- R5重进仍同步读取历史文件，需记录大载荷启动成本；被取消的预写文件可能留未引用孤儿，不能把无引用文件当已提交历史。验证离页释放/静置任务和资源边界。
- R1已定位落台交回状态过时，真实重力/滚动误差已从毫米级降至4–5µm；原生动作时钟无重复/回退。最终还需逐段核物理事件/呈现/相机，不据SCNAction节奏宣称GPU或真机验收。

## 原生补齐

- 标准手机、SE3最低Runtime、iPad横竖和真实系统缩窗回程；R3已覆盖默认/75°横屏与四输入，补75°竖屏、近库/角袋、布局保存重进、透明度0/50/100/回中微调、慢放中切镜头和快速连点。
- 原生缩窗参考DailyAdaptivePanelUITests.testV4RealPadWindowResizePreservesIntent及P01系统拖右下角流程，必须同时看到OS窗口与App内容尺寸变化；DEBUG viewport不替代真缩窗。
- R5已有原生飞台/返回/重打/后台测试候选，最终用同源源码再验。几何附件从实际生产回收函数生成后出图，不能只拿独立Python近似图作App证据。
- 浅深色/按钮形状/减少动态按实际触达项采样，原图审查与自动化分别记录。真机、实球材料/扎杆曲率标定、用户认可独立留待复验。

## V01–V09和集成

- V01显式空间入口仍只允许SpatialPracticeViewModel，appDefault保持planarReference；保留旧九族并发/取消逐值对照。
- V03复核走位/翻袋/颗星/两球/防守真实调用族，不只测底层。V05/V09重跑BoardMemoryTests、SharedShotReplayCameraTests和实际序列旧格式入口；现有旧相机三失败已有R0同源复现，保持原失败身份。
- V07必须真实旧页A→本页→旧页A并继续操作/击球：准度、正式分离角与走位、每日、自定义、至少一个求解页。可复用BoardMemoryUITests实际搜索导航、table.scene世界坐标探针；不能以重启后七页读回替代交错返回。
- 主工作区有v67相机并行改动，CameraRig对v66基线的净diff为0。最终只整合v66拥有的差分，保留并行源和用户数据；对合并后的实际源码冻结构建/验收，不能拿隔离worktree测试冒充集成测试。
- 本地8台核心模拟器在2026-11-17本次预检均Booted/待人工复验，设备总数19（临时上限已占）；不覆盖、不新建替代设备。继续Mac mini单worker FIFO，不插队。原始失败、重跑、source SHA、xcresult及资源关闭状态逐项记账。


## 录制与旧页路由补查

- Xcode默认只保留失败UI的系统录像，native-4失败附件确有mp4；成功流程目前只有手工PNG/JSON不能冒称已有视频。Apple WWDC25《Record, replay, and review: UI automation with Xcode》说明测试配置可保留全部录像（https://developer.apple.com/videos/play/wwdc2025/344/）。XcodeGen当前官方ProjectSpec Test Action支持 `deleteScreenshotsWhenEachTestSucceeds: false` 与 `preferredScreenCaptureFormat: screenRecording`；本机IDEFoundation确有systemAttachmentLifetime/keepAlways枚举。可在独立验收快照启用保留全部，核产物真的含成功录像；不需要绕过FIFO另起录制进程。正式App构建配置保持不变，验收配置与生产差分单列。
- V07路由已重查：CustomFormationPractice/CustomFormationPracticeView.swift，真实搜索“自定义球形”→formation.builtin.B4443000-0000-4000-8000-000000000001→formation.start→共享FreePlay，dailyClearance.back先回球形选择再“返回”出页面；不使用缺失的CustomFormation/Views路径。准度仍经settings.start，正式分离角与走位走composer，另每日与走位求解。
- 旧序列格式可用SequenceEnginePersistenceTests（BatchSequenceReplayRegressionTests.swift:189）真实decode/reencode/SequenceReplayResolver，不调用会跳过且可能渲全库的PositionPlaySequenceExportRunnerTests。
- 当前预合并比对：main HEAD仍5a21b7fd；本轮23文件中只有pbxproj与AngleTrainingScene有main并行差分，实际hunk分别为新增显式抬杆/球杆tip inset与v67机位恢复，尚未合入。最终仍须重新检查漂移。

## 等待R5崩溃复验期间的计时落点复核

- 实际预览链：VM.updateInput→schedulePrediction→55ms合并等待→后台solve/freeze→MainActor接触音timeline→renderRoutes。普通目标必须把55ms和主线程/绘制成本算进去；16球不能只引用R1求解939ms。
- 现有TableFrameReceipt以revision隔离已经在途的帧，FrameDelegate在willRender/didRender触发；可用于节点已挂接后的真正渲染完成回执。它仍不保证球杆已经位移，出杆首帧需进一步核球杆presentation世界变换确实离开点击时基线，不能拿球触球或开始play代替。DEBUG采样仅本页启用，测App实际接收输入/按钮动作后的延迟，XCTest命令耗时不等于产品交互延迟。
- 既有SpatialPracticeContinuityTests.testRecordOnlyWarmLatency固定四负载21轮（首轮冷、后20暖）仍可直接同机对照；原统计包括旧整档编码，R5实际后台不可变历史需另量，不能混作当前关键路径。
- R5新发现的跨renderer动态NSData风险已用本页显式副本策略候选处理，R6必须同时关注临时俯视的球影跟随及shader原值保持；不能仅看不崩溃。旧默认共享身份和真实移动球影回归已加入native-9。

- V07准度入口在TrainingViewMergeUITests/SixTrainingUnifiedUITests：accuracy.start→accuracy.strike。答题页重进是否生成新题须按自身合同断言，不能强套自由摆球记忆；应比较设置、无空间抬杆/菜单泄露、原有击球可继续。正式分离角与走位/走位求解已有BoardMemoryUITests真实搜索和table.scene世界坐标读回，可直接比较before/after；每日从trainingHome.dailyClearance进，自定义选内置4443再formation.start，返回有两层。
- 集成只读预演（当前0e3be7a6对main 5a21b7fd工作区）：24个拥有文件，仅pbxproj及AngleTrainingScene与main实际内容分歧，git merge-file均0冲突；preview与SHA保存output/v66-rework/integration-dry-run。最终合并必须重核SHA，不能直接消费过时preview。

- R5飞台终点诊断后新增只读检查项：freeze当前times集合含uniform240Hz与区间端点，但未显式包含spatialDomainExits.time；同时hidden比较把Float样本时间升为Double，须核边界时刻舍入与首隐藏帧。R6按事件时间/轨迹连续性合同验证，不因R5存档通过自动判呈现采样通过。

- 帧计时接线补查：TableFrameReceipt.arm只有一个回调槽，生产首帧恢复已使用它；性能探针不能直接arm同一个对象抢走原回调。须用独立、默认未启用的DEBUG观测通道，在真实didRender时读球杆presentation；异步MainActor消费延迟与渲染时间分列，旧页默认无探针。
