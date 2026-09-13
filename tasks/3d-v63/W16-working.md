# W16 平台与性能验收（进行中）

## 浅色证据纠正（2026-09-14）

- 当前源码核实：RootView.uiTestDeepLinkColorScheme对未传覆盖参数的深链默认.dark；S1_FreePlayLayoutUITests原setUp仅传forcePremium/deeplink.freePlay。因此该类此前标注的light仅证明系统设置，不能当作App浅色验收，原截图/功能结果保留。此结论不外推到其他测试类。
- setUp现显式传既有-v51.followSystemAppearance，解除测试宿主的深色覆盖。FreePlayView工作区仍按现有代码固定dark（背景和局部environment），BTShotPageChrome亦声明fixed dark workspace；这不是本次发现的产品缺陷，不据此改色。该参数只让外层宿主恢复跟随系统，不能宣称球桌页变为浅色。
- 专用SE/iOS17设备实读light/accessibility-extra-extra-extra-large，freeplay-light-ax5-r1正在用当前源码执行完整15/9球开球、观察、击球往返、交付、续打、重打与取消。修改仅在测试入口，无生产行为改动。

## 当前补验：2D开球后首次进入3D（SE / iOS17 / AX5）

- 本轮启动前实际读回专用51383D5F设备的accessibility-extra-extra-extra-large/light，无并行xcodebuild。只用当前源码构建，未使用旧测试产物。
- first-3d-se-ax5-r1/r2各执行1项失败（14.643s/14.520s）：模式已切3D，菜单可见，但父Menu的isHittable=false。r2控件树确认其为嵌套Button，矩形在屏幕内，非控件缺失或Disabled。
- r3保留原断言，以菜单中心物理点击取证；实际出现freeplay.observe.table及其余三个菜单项，原父元素断言仍失败。由此确认“父元素可点击标志”不能代表实际菜单操作，不据此修改生产布局。
- 测试改为真实点击菜单→断言查看全桌选项可点击→选择→菜单消失且模式仍3D。r4/session52028 exit0，实际1项16.231s/0失败。两张原图已打开（r4-attachments/3EEA1C7F、63DDBF19）：四个菜单文字在最大字号下完整，3D运杆画面球桌与母球可见。仅此流程，不代表整杆停稳、全部镜头或真机性能验收。
- VoiceOver未补齐：当前XCTest公开接口仅有slider/picker调整，不能直接派发自定义adjustable动作；本机idb启动报Python3.14缺event loop。未修改工具环境。r2实际AX树显示运杆时瞄准微调Disabled，但仍不证明VoiceOver增减与禁用动作派发。
- 本轮只修改测试并保留r1–r3原失败，生产代码未改；W07失败、其余平台和H01–H04范围不变。

真源：问题集合_v63.md §8 W16。范围保持标准/紧凑/iPad、Light/Dark、iOS17最低系统、最大字号、VoiceOver、真机触控/内存/场景退出/复杂开球与持续发热。模拟器FPS不作为真机性能证明。

2026-09-13核实project.yml最低版本17.0，本机有17.0与26.3 Runtime。新建本任务专用SE模拟器QiuJi-v63-iOS17（51383D5F-38C6-4D36-9FBF-B9B622AE45C7），避免覆盖其他专题设备。ios17-r1/session90433验证真实场景三轮销毁与每日清台三轮2D/3D进度往返；此项不覆盖真实开球全部流程。

已有关联证据：W10 DR-270三轮weak释放与SE真实详情播放退出重入36.188s通过，详W10-working。W11–W15已有本地批次验收，不能视为完整平台验收。

未完成：最低系统上述结果确认与其余关键流程、最大字号/VoiceOver、最终平台截图、真机触控与内存/持续性能。W07求解性能约37秒的缺口仍未解决，不能因布局或模拟器渲染正常而关闭。

ios17-r1/session90433终态0：真实场景三轮释放1项1.746s；每日清台三轮2D/3D保持2杆1次犯规UI1项13.745s通过。BF6E63F5 3D原图已核，模式/HUD/观察入口显示正常。进度输入夹具含旧坐标，仅作状态/控件证明，不作物理球位正确性。当前无活跃句柄。

最大字号：ax5-r1启动前simctl设置失败（设备Shutdown），主动中止session28375终态73，不计AX5验收。待终止完成后boot/bootstatus成功，实际读回accessibility-extra-extra-extra-large并设置light；ax5-r2验证每日清台三轮往返及完成/失败2D/3D操作。

ax5-r2/session44938终态0，完成/失败21.471s、三轮往返13.006s功能断言通过；测试后仍读回AX5。但B1018842/7DBE3357原图显示结果按钮巨大且截为“再来…”/“重…”，视觉不接受。DR-271改为辅助功能字号纵排，结果栏随ScaledMetric增加高度，保留大字；普通字号横排。ax5-r3/session33454复验中。另发现BTAimWheel只有accessibilityLabel没有adjustableAction，需补VoiceOver调整及播放态禁用约束，尚未实现。

ax5-r3/session33454终态0：完成/失败两模式实际1项21.012s通过；C2A3A713/9E9BC962原图已核，重新开球/再来一局四字完整，纵排不重叠且按钮在屏幕内。AX5保留大字，不缩字号；两结果的终局场景让出底栏空间。ax5-gate-r1/session24451退出0，verify-gate/doc-size/diff通过。普通字号最终回归及VoiceOver微调输入仍待验。专用iOS17设备保持AX5/light，下一轮使用前先读回设置。无活跃句柄。

VoiceOver微调候选：BTAimWheel增加adjustableAction，增减使用当前degreesPerPoint（相当于一次1pt拖动）并成对调用拖动生命周期；环境disabled时拒绝。六个使用处将原allowsHitTesting边界同步为disabled；瞄准点训练按phase显示无需重复条件。aim-ax-build-r1/session51891终态0 BUILD SUCCEEDED（xcpretty缺失后脚本原生fallback成功）。aim-ax-r1/session28336通过UIHostingController实际AX树寻找元素并调用increment/decrement，验证灵敏度及禁用状态，运行中。

aim-ax-r1/session28336终态65：UIHostingController普通UIView/AX容器遍历未发现SwiftUI虚拟无障碍元素，未执行increment/decrement，不能判断产品动作。撤去该不适用宿主测试，保留原失败xcresult，换实际App XCUI无障碍树检查Slider角色、标签与启用状态；aim-ax-r2/session14027运行中。动作回调和真机VoiceOver尚未声称通过。

aim-ax-r2/session14027终态65：真实AX树FE4433AA已核，shotStage.aimWheel存在且标签正确，但SwiftUI将自定义adjustable视图映射为Other而非Slider。测试误假定角色，不能强行改产品为有限范围Slider。后续仅以真实Other检查可发现性，明确不把该检查作为increment/decrement执行证明；完整VoiceOver手势仍待验。

aim-ax-r3/session74148终态0：实际App Other元素、标签和启用状态检查1项通过。aim-ax-gate-r1/session22337退出0；Debug BUILD SUCCEEDED，diff检查通过。DR-272增减/生命周期/disabled源码已接，当前通过范围仅构建与AX可发现性，不宣称已实测VoiceOver调整及禁用时的动作派发。该缺口保持W16未完成，后续继续普通字号回归及其他平台事项。无活跃句柄。

iPad普通字号复验：11A0F6DD实际读回large/light；ipad-daily-r1/session13926运行完成/失败结果2D/3D与手动重开→待开球恢复→直接再重开→真实交付→重启恢复，验证DR-271默认横排和DR-269在iPad业务流程。未把其他设备字号状态外推到本机。

ipad-daily-r1/session13926终态0：结果26.122s、手动重开/实际交付/重启42.917s，两项69.039s通过。E6CB37D3/95B3E1C6结果、26EEA84F真实交付三原图已核：普通字号横排文字完整，交付全桌球形/余8球/0杆显示。结果fixture仅作布局，实际开球不注入结果。DR-271常规字号iPad回归接受；真机/VoiceOver/其他页面完整平台仍未完成。无活跃句柄。

真机防守单项基准启动：devicectl已确认iPhone16Pro connected，UDID 00008140-0009682918A2201C，系统26.6.2；详情JSON保留device-details-current.json。defense-device-r1/session44078独立DerivedData-Device，Debug -O、无覆盖率、只选Snooker默认盘面测试。Makefile test固定覆盖率YES，沿用本任务直接xcodebuild测量配置；不改变工程构建设置。构建/安装/实际测试结果分别待核，当前不能声称已安装或通过真机基准。

20:03真机启动等待：defense-device-r1/session44078仍存活，Xcode明确报“device is locked / Unlock iPhone to Continue”，等待destination ready。未执行测试、无真机耗时结果；不要把启动等待判成产品失败或重启同一测试。需要用户解锁手机。

defense-device-r1/session44078终态0：锁屏等待后同一进程自行恢复，实际iPhone16Pro/iOS26.6.2运行1项70.448s通过，内部systemUptime求解68.763s，5组PlannedShot与模拟器逐条相同，首触/母球不进袋/完整停稳断言通过。成功包含设备构建、测试宿主安装和真实执行；不是触控/帧率/温度验收。配置Debug -O、无代码覆盖率，仍含DEBUG诊断；未取得本机优化前基线，不能把模拟器48%套用至手机。68.76秒不可作为手机性能达标，W07/W16保持未完成。

Release手机对照defense-device-release-r1/session79732构建中：同连接手机、同SnookerSolverTests默认盘面，Release/ENABLE_TESTABILITY/无覆盖率；只临时排除其他QiuJiTests源以避开历史Debug观察接口编译依赖，排除清单与App文件名交集为空，名单存defense-device-release-r1-exclusions.txt。未修改/删除测试原文，不代表完整Release套件。核心四文件SHA256留存defense-device-release-r1-source.sha256。启动时另一模拟器测试只剩shell收尾，随后pgrep精确xcodebuild仅38195（本轮），其日志已TEST SUCCEEDED，未停止他人进程。
Debug手机诊断：rollout79.35ms、coarse10889.56ms、refine57184.18ms；1912次引擎跨线程累计406577ms不是墙钟，不能与68.763s相加。细评仍是主要墙钟阶段。Release结果尚未取得。

20:09 Release编译/签名已完成到测试启动预检；session79732仍存活，Xcode报device locked并等待解锁。无Release手机测试结果，勿重新启动并行测试；继续观察同一handle。

Release真机r1主动暂缓：持续锁屏预检未执行测试，向本轮PID38195发送SIGINT，日志TEST INTERRUPTED，等待清理后session79732终态73且PID已不存在。保留Release构建/xcresult/排除清单；这不是产品测试失败，也无Release手机时间。待用户手机可用再运行，不自动反复安装/等待。

## DR-282 — 轨迹按钮点击区域与放置带一致（2026-09-13）
- 根因：SE/iOS17/AX5实页点2D/3D的(337,87)点，实际轨迹档位全→双，模式未切换；轨迹按钮点击区域进入上一行。原失败保留shot-se-ax5-r1.xcresult，实际1项失败。
- 修复：BTTrajectoryDetailChip标签显式minHeight 44/contentShape；btChipBandPlacement高度至少44点，容纳点击区域。外观胶囊仍使用原尺寸，无相机/物理修改。
- 复验：shot-se-ax5-r2实际1项74.802s、0失败，包含切换、观察/旋转/缩放、后台恢复、瞄准/击点、击球/回放/重置。70D2/9433/C25E三原图已查看：模式、底部操作与击点面板在屏幕内。仅此设备/流程，不外推所有共享消费者或真机VoiceOver/FPS。
- 门禁：chip-hit-gate-r1日志全部通过；共享消费者普通字号复验待补。W16仍未完成。
- 已应用至：tasks/UI-IMPLEMENTATION-SPEC.md §DR-282组件契约与Changelog。

DR-282普通字号补验：chip-ipad-r1/session35955 exit0，实际自由走位入口19.743s、分离角完整3D流程91.619s，共2项111.362s、0失败。iPad字号实读large；C4E78253/3A755280/5280897F原图已查看，轨迹按钮与模式行分开、击点操作与底栏文字可见。自由走位只覆盖入口布局，不能称其完整交互回归。小屏after-replay原图6F6521CD也已查看。所有本轮测试终态；其余共享消费者/真机/VoiceOver及W07失败仍待验。
