# 性能诊断草稿方法与边界

2026-09-05，仅编写 `PerformanceDiagnosticUITests.swift`，**未编译、未运行**。不修改业务/既有诊断文件、不操作模拟器、不生成制作资产。

## 方法

| selector（前缀QiuJiUITests/PerformanceDiagnosticUITests/） | 操作 | 输出 |
|---|---|---|
| testFiveProcessColdLaunchObservations | 同一配置5次terminate确认notRunning→launch→前台→真实trainingHome.freeTraining可操作 | 每次launch调用耗时、launch至CTA查询完成耗时；5张ready图；逐次写累计JSON与keepAlways附件 |
| testTenToolEntryExitCyclesInOneExplicitAppLaunch | 只显式launch一次，正常练习→打→自由击球，10轮进入并等navStatus已就绪→打开/关闭打点盘→真实返回原卡 | 10轮进入/返回延迟、20张入口弹层/返回图、累计JSON；一个10轮测量块的XCTClock/App CPU/App内存指标 |

两方法均中文、跳过引导、forcePremium、跟随系统、独立内存库；无预置训练、无deeplink、无登录、无文件资源制作。截图/JSON由 `QD_SHOT_DIR` / `TEST_RUNNER_QD_SHOT_DIR`指定，每测试实例UUID防跨运行混淆。JSON在每成功样本后更新累计结果，后续失败不丢先前样本；附件保留每次快照。文件I/O失败明确XCTFail/抛出，不能产生无报告的绿结果。

## 数字具体代表什么

- “冷启动”仅指**进程已退出后的启动**。没有重启OS、清文件缓存、重装App或抹掉UserDefaults，首次安装冷缓存与后4次热文件缓存可能不同。不能声称5次完全相同的系统冷启动。
- 使用单调 `ProcessInfo.systemUptime`，避免系统时间调整；`launchCallSeconds`含XCUITest launch API开销，`launchThroughCTAQuerySeconds`还含AX查询/等待，不是纯产品启动时间或首帧渲染时间。应原样报告口径，勿拿它与产品冷启动SLA直接比。
- 工具进出由正常UI操作驱动、无循环间terminate/launch代码；XCTest失败不做恢复重启。因此它比重启10次独立工具测试更适合观察累积问题。严格“同PID”仍需主控运行前后及循环时间线的宿主侧进程证据；app.state前台不等于PID连续性。
- XCTMemoryMetric/XCTCPUMetric显式针对App，而非UI runner。但只测一个10轮完整块的聚合指标，**没有每轮内存曲线，不能据此判定泄漏或不存在泄漏**。需要主控独立按相同时间线采样App进程内存，记录开始/各轮/结束与静置后的回落。
- 当前测量块含截图/附件/AX/文件写盘，这些会扰动应用帧调度与总体墙钟。这里以可追溯诊断为先；若发现性能嫌疑，应在同业务/状态下另做少截图的聚焦测量，不把诊断采证开销当产品开销。
- 输入数据是空内存库，**不覆盖1000条历史/统计压力**。动作库1000计次fixture也不等于1000条完整训练记录场景；大数据需要独立数据生成、条数/分布验证后再测。

## 运行与裁定

- 主控将文件作为诊断叠加层加入snapshot测试目标、记录哈希；先编译再用两个方法级selector，各自独立日志/xcresult/输出。不用整UI target。
- 默认先M1/iOS26.2，M2/iOS17.0或M3/iPad用于差异复核。测试时不并行其他UI或CUA，不掺入外部构建高负载；必须记录机器负载/Runtime/设备/Debug或Release/安装与预热状态。
- 模拟器的SceneKit、文件缓存、CPU/内存与真机不同。仅输出样本数、逐次值、中位数/最大值及观测环境，不作真机功耗/热/流畅度结论。
- 30秒ready等待是用例防挂起窗口，不是验收SLA；超时先区分路由/AX/渲染/环境，不直接下性能定论。
- 当前无已锁定硬性能阈值。不加“<2秒”“<100MB”等未经产品/平台口径确认的断言。测试绿只表示5次/10轮完整执行及采证成功，性能数值仍待分析。
- 当前工具状态文字与打点AX依据snapshot既有V51测试，仍可能有新鲜设备初始化/AX暴露差异。若失败，保留原始输出并取证；不加入无限重试、不改业务迎合测试。
- 同进程10轮只覆盖进入/弹层操作/返回，**不覆盖10轮击球回放**。这是本次授权草稿的具体范围；COVERAGE-PLAN里反复工具回放需另用真实可重复盘面、等待完成和回放后的场景契约，避免之前“进球后击球应禁用”误判。
