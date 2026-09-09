# SC36：同进程十轮实际击球、回放、重打诊断准备

2026-09-08，Test Engineer。草稿未注册、编译、运行；未操作设备、创建盘面fixture、录制或制作资产。仅交付 `RepeatedShotDiagnosticUITests.swift` 和本文。

原严格策略方法（保留，不选入下一批）：`RepeatedShotDiagnosticUITests/testTenActualShotReplayRedoCyclesInOneAppLaunch`。专用runner环境 `QD_REPEATED_SHOT_AUTH=DEDICATED_DIAGNOSTIC_SIMULATOR`，QD_SHOT_DIR，兼容TEST_RUNNER_前缀。主控管理实际UDID、隔离构建与同机UI串行。

## 与现有证据的区别及冻结源

- `PerformanceDiagnosticUITests.testTenToolEntryExitCyclesInOneExplicitAppLaunch`是10次进出自由击球、打开/关闭打点；没有击球与回放，不可充当本次10轮证据。其XCTMemoryMetric、CPU、Clock是整块聚合，不是逐轮泄漏鉴定。
- `ToolDiagnosticUITests.strikeAndReplay`已核：点击回放后直接ready(replay)，存在按钮可能瞬间仍可用而漏掉真实开始观察的风险。本草稿不复制这个弱oracle；必须观察忙态与真实状态文字，再等待结束，不能用ready瞬间通过跳过回放。
- 冻结 `AngleHomeView.swift:223`：“自由击球”免费正常入口，分类 `angleHomeTab_打`，不用forcePremium。
- `PositionPlayViewModel.setupScene/applyDefaultLayout:184–205`：正式默认母球(0.30,0.30)、1号(0.62,0.20)、2号(0.78,0.34)，选1号并正常求解。草稿不注入坐标，不点开球，不编辑球形。
- `FreePlayView.swift:230–240`：击球→vm.play；“重打”→replayCurrent；“回放”→replayLastShot。isPlaying时主按钮变“击球中”、不可用，回放/重打不可用。
- `PositionPlayViewModel.play:1076+`：有效预测与recorder检查通过后isPlaying=true，先“运杆…”；`launchBalls`才把statusText改为“击球中…”，启动真实轨迹动作。结束时canReplay、canPlayback=true。草稿以按钮忙态加**navStatus.subtitle精确“击球中…”**确认已走到实际球动画，不能仅凭运杆开始判定整杆已发生。
- `replayLastShot:1338+`：isPlaying=true，statusText“回放上一杆…”，使用同份recorder重播；finishPlayback恢复after、isPlaying=false、重求解。草稿同时核回放特有状态与禁用回放，再核忙态/回放状态消失且回放与重打重新可用。
- `replayCurrent:1304+`：非录制态恢复lastShot.before及参数，清lastShot/context，canReplay/canPlayback=false。草稿每轮正常重打，确认击球可用且回放/重打禁用；下一轮不退页面。
- `BTShotPageChrome.swift`真实按钮文案与navStatus.subtitle标识；只读状态文字不要求hittable。

## 原严格方法与证据（保持不变）

一个明确的app.launch，正常进入自由击球后留在同页10轮；没有launchClean自动启动恢复或循环间页面重进。启动只跳过引导、清debugPremium、内存库、跟随外观；不强制权益、无身份fixture。初始默认盘和回放/重打禁用须断言。

每轮：确认初始可击球→点击一次击球→观察真实球动画开始→观察结束且回放/重打可用→点击一次回放→观察回放开始→观察回放结束→点击重打→恢复可击球且旧回放清空。起始状态最多6秒观察，结束最多45秒。没有观察到开始就保留失败，不转为“短动画视为通过”。所有10轮完成才计本方法完成。

JSON用ProcessInfo.systemUptime单调时钟，记录逐轮tap、busy观测、结束观测、重打结束与phase。每个阶段写一份唯一event JSON，后续失败不覆盖已得样本；terminal保留未完成轮的phase和已采到时间。JSON含ISO墙钟与systemUptime，便于和宿主采样对齐；报告口径为UI操作/AX观察耗时，含XCTest通信、等待和期间报告IO，不是纯物理引擎/渲染耗时。

PNG/AX：初始默认盘，1/5/10轮各击球后、回放后、重打后，以及失败/正常terminal。PNG先写再查AX，避免AX失败丢图。整轮时间包括证据IO，不能把关键轮截图开销当性能退化。未使用measure重复驱动业务块；可由主控后续加一个iterationCount=1的聚合XCTMemoryMetric旁证，但不能改变十轮语义。

## 真实开始状态的可观察边界

源中有明确busy与状态文字，因而可以写硬oracle；但XCUITest的tap/AX空闲等待可能让短动画在查询前完成，特别是默认盘每轮时长较短。**尚未实跑，不能保证此Runtime能采到全部开始状态。** 一旦发生，归为开始状态观察不足，保留原失败、时间线和可用录屏；不得删busy断言、增加循环重试、放慢/改盘来补绿。

若主控从同一次xcresult录屏能逐轮确认球运动和回放，则作为独立视觉证据补充并明确自动断言失败原因；这不自动令失败selector通过。确需更稳定事件时应另提只读诊断观测方案，不在本任务改生产或添加假状态。默认球形恢复只有正常重打路径、按钮状态及关键轮可见图证；AX没有所有球坐标契约，不能声称逐轮数值相同/几何正确已认证。

## 主控独立PID与内存采样方案（未执行）

1. 同机只允许此批UI运行。按专用UDID取得真实App容器/可执行路径，配合宿主进程完整命令匹配 **QiuJi App进程**，排除QiuJiUITests-Runner、xcodebuild、Simulator壳和其他UDID的同名App。不能仅 `pgrep QiuJi` 随便取第一个PID。
2. 在方法启动前准备宿主只读采样器，App出现后记录PID、进程start time、完整可执行路径；每约1秒记录墙钟+宿主单调时钟、PID、start time、RSS及可取得的CPU指标，写独立CSV/JSONL，直至terminal证据之后。逐行flush保留故障前样本。可使用macOS ps的`pid,lstart,rss,vsz,comm`读取**已核实PID**；主控先核本机实际列支持，不能把虚拟地址空间VSZ当内存占用。
3. 采样须含入页稳定期、每轮阶段、最后重打后稳定期。以JSON墙钟/uptime标记对齐；若需要额外稳定观察，可在测试结束前给定单次有界窗口并如实标注，不重复10轮或重新启动。PID消失/更换或start time变化立即记录断点，不把新进程后续样本接成连续十轮。
4. 只有完整PID/start-time时间线才足以声明“同一进程”；一个launch语句与app.state前台仅证明脚本意图，不排除系统重启。缺采样则报告“一个显式launch，PID连续性未独立确认”。
5. RSS是驻留内存代理，缓存、SceneKit/驱动、渲染池和采样开销均可能影响；报告起点、各轮稳定点、终点、峰值和可见趋势，**不凭十轮上升或XCTMemoryMetric聚合值宣布泄漏**。若明显增长且无法回落，列待查问题与复现窗口；真正泄漏归因须后续Allocations/Leaks/VM证据，不能本批臆测。

本批没有性能预算/SLA阈值，不以某个绝对秒数判性能合格；超时用于有界场景执行。10轮UI动作通过也不证明真机帧率、触感、热量、长时间稳定性或所有盘面都可靠。


## 主控审核后的伴随策略：必须逐轮视频验收

新增同文件第二方法 `RepeatedShotDiagnosticUITests/testTenShotReplayRedoCyclesForRequiredVideoReview`。原 `testTenActualShotReplayRedoCyclesInOneAppLaunch` 的方法体及全部busy断言保留，下一批**只选择 ForRequiredVideoReview**，不运行整个class；否则会发生两次独立启动、两套十轮，不能混为一套证据。

背景：本机XCTest在tap前后可能等待约60秒，tap也可能直到动画结束才返回，原严格方法可能第一轮就错失瞬态。伴随方法不伪装观测到了busy，也不把ready瞬间返回称为播放开始。它保留一次launch、一次正常入页、10轮各一次击球/回放/重打、明确前置和终态、单调时钟及原有关键图证；tap后加固定1秒UI调度间隔，再核结束控件。**这1秒不是动画证据，也不保证回放发生；真正运动完全交由下面的视频硬验收。** ready即刻满足时依然保持video verdict pending，不提前计回放通过。

伴随方法JSON明确 `evidenceStrategy=operations-and-terminal-states-with-required-video-review`，每轮 `shotVideoVerdict`/`replayVideoVerdict` 都是 `pending-required-review`，完成phase为 `operations-completed-video-pending`。报告用terminal-state观察时刻，不写busy已观测。方法绿色只说明十轮操作及终态控制断言通过，不代表SC36实际20次运动完成。

### 下一批必须取得的外部证据

1. 主控在运行前确认该精确selector成功执行时也能保留**完整xcresult视频**，不能依赖仅失败录屏。记录视频附件文件、所属方法、原始时间/PTS、编码帧率/时长。若配置无法保留完整视频，应先解决录制证据路径，不用运行后只有PNG替代。没有完整视频或录像有缺口时，该策略不达标。
2. 以runner日志tap事件及逐轮event JSON的时刻和顺序，建立“第n轮击球”“第n轮回放”“第n轮重打”的视频PTS区间。时间对齐要有可验证锚点（比如最初进入自由击球及第一下击球），不能把systemUptime数值直接当视频秒数；记录实际偏移与对齐误差。
3. **逐一核对10次击球**：每轮点击前的默认球局；随后确实有运杆/出杆与球的位置持续变化，直至静止；列开始运动帧、至少一张明确位移中的帧、静止结束帧的PTS/帧号或导出路径。不能只凭“击球中”文字、点按钮手势或首尾两张同图判运动存在。
4. **逐一核对10次回放**：必须在对应本轮击球之后、重打之前，看到恢复该杆击打前状态、再次运杆/球运动，并回到该杆后局面。记录回放区间及开始/运动/结束帧；这些帧不能复用上一段实际击球的帧，不能把重打导致的瞬间摆球误认成回放。必要时连续播放该片段，孤立一张变化图不等于完整回放。
5. **逐一核对10次重打**：在该轮回放结束后回到初始默认母球+1号+2号局面，下一轮从这里开始。记录重打后帧，与初始盘面及上一轮重打图对照。只要求可见恢复，不宣称像素级/数值几何一致。第10轮重打后也必须有证据。
6. 单独形成外部审阅表，恰10行，列iteration、shot区间/运动帧/settled帧/判定、replay区间/运动帧/settled帧/判定、redo后帧、异常/缺证原因。必须20个动作都明确通过，任一pending/不可见/未运动均不能称本策略达标；有异常原始证据保留，不删该轮重新编号。
7. 外部审阅结论引用原runner JSON与视频，不改写原始pending JSON冒充当时自动断言已证实。方法退出码、10个operations-completed-video-pending样本、20段视频运动核验、10次默认盘恢复和同PID时间线分别报告。PID采样仍依上节，视频并不能替代PID连续性证明。

关键PNG仍用于界面/局面审阅与失败排查，不能替代连续视频。人工/主控逐帧证据缺失时最终状态必须写“10轮操作已执行，实际击球/回放视频验收未完成”；不能写“十轮击球与回放通过”。该伴随方法尚未编译运行，视频是否完整可得也待主控确认。

### 主控补充：成功运行录像的独立保证

主控已核本机 `xcrun simctl io help`：支持 `recordVideo --codec=h264 <new-file>`，首帧处理后stderr给 `Recording started`，向该自有recordVideo进程发送SIGINT后等待退出才能得到完成文件。`xcodebuild -help`及当前scheme未发现可直接保证成功用例保留录像的配置，因此不应盲目依赖默认xcresult策略。

可在**新的专用设备、测试启动之前**启动这一个只采集画面的诊断录像，确认Recording started再运行唯一十轮selector；测试结束后只停止本次自有录像PID并等待文件完成。不用`--force`，不覆盖旧视频，不向模拟器发送点击/键盘或切换其他设备。录像与测试日志/JSON共同归档，取代“必须是xcresult视频”的载体限制，但保留全部逐轮运动和重打验收要求。它是测试证据，不是正式制作资产。记录器自身开销必须写入性能口径；不得把带录屏样本当无扰动帧率/CPU基准。没有完整连续视频仍不达标。

当前只核CLI帮助并通过RepeatedShot草稿Swift语法解析（exit0），未启动录像/测试，未typecheck或工程编译。下一选择伴随方法前须先实际建立录像与PID采样边界，不能跳过。
