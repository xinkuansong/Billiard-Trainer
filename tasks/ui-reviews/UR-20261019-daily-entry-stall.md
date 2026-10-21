# 每日清台转屏停顿：初步诊断（2026-10-19）

状态（10-20）：本轮修复及定向回归完成，原速浅深录屏已交付；待用户观看/真机复验。3项单测、标准手机2项UI、SE/iOS17共3项UI、iPad1项UI通过。早期SE测试操作衔接失败已保留并闭环（FL-164 r7），不作为App半屏复现。

用户反馈：进入每日清台由竖屏转横屏时慢、露白底、旋转观感差，偶发只显示半屏。尚未提供设备/系统/安装构建及半屏是否自行恢复。

## 证据与判断

- 旧测试失败发生在已进入横屏球桌之后，查询未展开菜单中的freeplay.cameraMode；它不运行在正常用户使用路径中，不能直接导致入口卡住。
- 源码：FreePlayView.onAppear同步setupScene与草稿恢复；DailyTableOrientation在viewDidAppear请求方向。前者可能占用导航/旋转所需的主线程。
- 实采图标任务r3构建（独立预览bundle，同模拟器iPhone17Pro/iOS26.3）：8秒/2ms线程采样中，2124次主线程样本里1055次在setupScene，606次在refreshRoomReflectionProbe→RoomReflectionProbe.probe/bake，含SceneKit同步snapshot。这证明该进入过程确有主线程同步场景准备，不能当作真机耗时或精确墙钟比例。
- 原生视频看到首页等待、每日页先竖屏排版、随后旋转；未复现最终持续半屏，不把白底或半屏根因直接归为上述耗时。
- 采样目录output/daily-entry-stall-20261019：entry.sample.txt、sample-command.log、attachments/E8EBE026-0CFD-4362-8ABF-03B7AD6B50EE.mp4、entry-contact.png。

## 本轮测试边界与环境

- run/test.log执行2项、1失败。失败是新专项测试的landscapeReady额外限制back.minX<60；它不适用于有横屏安全区的标准手机。先前phone-r2通过的是加该限制之前的测试；SE通过不证明此限制适用于其他机型。此次失败不作为半屏复现或通过证据，后续需改为实际窗口内可见/可命中的判断，保留完整布局断言。
- 启动时本机空间不足，Xcode报告无法创建默认测试日志目录；随后仅删除本会话DailyIcon DerivedData中的Intermediates.noindex与ModuleCache.noindex。保留编译产物/日志/测试证据，未清历史目录或设备。此环境和采样开销不适合宣称稳定入口耗时。
- 测试结束独立预览包已卸载，借用设备恢复关机，原App/数据未覆盖。

## 后续定位范围

1. 在空间充足环境、正式点击入口下记录cold/warm、2D/3D、真实待开球与草稿恢复的方向事件、window/host/scene尺寸和首帧；对齐半屏出现时的实际窗口层级。
2. 将昂贵反射准备与导航/旋转动画分离，保持现有材质/球形/草稿语义；必须有同条件前后采样，不能以固定延时掩盖。
3. 根据实际底层容器补齐转场背景和最终几何收敛；不凭推测重建整个页面，也不直接恢复10-06已撤回的准备页/双门控方案。

## 10-19 开始修复（尚未验收）

- 用户补充：白底主要在浅色模式可见，深色模式未看到。页面外层浅色宿主露底仍是待动态确认的解释。
- 每日清台页面显式启用异步反射准备：在主线程复制独立静态节点/材质，串行后台烘焙与预过滤，主线程按请求代次、外观输入和缓存代次校验后安装；离线渲染/原同步消费者保持原行为。
- 方向控制器不再在SwiftUI导航push中途提交几何请求，等待实际出现和转场完成；根据真实scene方向确认结果，系统失败允许在下一次真实布局有限重试，转屏完成强制父容器布局收敛。iPad仍允许双方向。
- FreePlay页面最外层补不透明黑底覆盖safe area，不改变首页外观偏好。
- 新增真实待开球Light/Dark各3次进入返回，以及异步反射外观过期/缓存清除测试；修正旧UI测试对菜单内2D/3D按钮的访问。尚未执行这些测试。
- 已执行：6个变更Swift文件的`swiftc -frontend -parse`零退出；`git diff --check`对本轮独占文件零退出。
- 当前空间：本机约942MiB；Mac mini约3.6GiB。已通过SSH核实机器、Xcode26.2、队列无running/queued且无xcodebuild进程。
- 已向用户发出清理许可问题，尚未收到回答。具体候选仅为Mac mini `/Users/song/simulator-work/queue/jobs/queue-verify-a-r1/build` 和 `queue-verify-b-r1/build`（各约1.3GB，任务均succeeded）；未删除。源码、evidence和模拟器均不在候选范围。
- 本轮输出：`output/daily-entry-fix-20261019/before/`保存修改前关键源，`baseline-manifest.json`保存捕获前全源码指纹。`snapshot-r1`是未提交队列的早期冻结快照，晚于它另有方向回调与测试输出路径修订，**不能用于最终验收**；后续重新冻结最新源码。
- 后续：空间释放→冻结同条件baseline与fixed快照→标准手机真实Light/Dark入口及2D/3D草稿返回→SE/iOS17与iPad方向相邻回归→提取原生进入返回视频、逐帧核白底/半屏并给用户观看。任何构建或测试失败保留原始证据再修，不把旧图标测试当作本轮通过。

## 用户授权清理后继续

用户明确允许核查并清理已结束任务的可重建构建缓存。核实远端队列与租约后，仅清理12个成功任务的24个Intermediates.noindex/ModuleCache.noindex目录，共8029MiB，保留Products、source、evidence及全部模拟器。精确清单：output/daily-entry-fix-20261019/cache-cleanup.json。初次常规上传受本机临时tar空间限制失败，未入队；改为流式tar传入同一队列_ingest/worker，未绕过FIFO、源码校验或设备租约。

r2固定快照4726d235已入队。baseline-r2曾混入并行图标改动，已在排队态取消；baseline-r4改从r2冻结源码复制，对照仅QiuJiApp.swift与FreePlayView.swift不同，统一关闭本轮异步入口/方向/底色更改后入队，不作为共享工作区回退。

## 10-20 标准手机与同条件对照

- r3快照 `f3da1c27e71bde0d0db025cb04c7af9518bfe5f3a4e9256f36e96c3a84b1b684`，iPhone17/iOS26.2，5 passed/0 failed/0 skipped。3项RoomReflectionProbe测试验证异步配置、过期外观拒绝、缓存失效与旧同步消费者；2项UI包含真实待开球Light/Dark各3次进入返回，另2次带3D切换与返回。
- 19张终态原生截图已逐张目视：球桌及控件完整、首页Light/Dark恢复正确。原图及回传33项SHA核对：`output/daily-entry-fix-20261019/review-phone17/`；终态viewport均为618×342pt，对应874×402pt窗口，其余空间为HUD，未停留在竖屏视口。
- 对照快照 `ae56a251f4e46e42a5ae308c4b938c2dbb57ded18404e197a8ed92d99faba6a8` 从r3冻结源码产生，仅QiuJiApp.swift、FreePlayView.swift两文件不同（旧方向策略、同步入口反射、旧底色）。同型号/Runtime、相同UI用例1项通过，6次进入返回。
- **转屏证据升级**：修前6次进入均记录UISceneErrorDomain Code101：请求landscapeRight时控制器仍仅支持portrait；修后同6次0次错误。证明旧请求时机与导航的方向支持更新冲突；修前本轮仍最终恢复横屏，不能将它伪称为已复现持续半屏终态。
- 点击至XCTest确认横屏可操作：修前Light [8.028,3.697,3.521]s / Dark [6.175,3.515,3.238]s；修后Light [6.473,4.184,3.542]s / Dark [3.908,3.736,3.541]s。首入有改善，暖进入无稳定加速。单组Debug模拟器且含XCTest等待，不能推广为真机时延/稳定百分比。
- 原生日志首次viewport.make至场景配置：修前Light3.317s/Dark1.627s，修后0.632s/0.496s；首次make至方向请求修前5.039s/2.989s，修后2.927s/1.291s。原始JSONL和计算结果为`probe-*-phone17.jsonl`、`timing-probe-comparison.json`，不把阶段时差当纯CPU耗时。
- r2初次构建成功但设备阶段被同型号保留上限阻止，无测试执行；其他预排任务及时取消，未清旧模拟器。后换有名额iPhone17；SE17/iPad11寸后续单元尚未运行。录屏用已有池设备的独占租约与独立bundle，须等待统一worker锁空闲。
- 用户授权后仅清成功结束任务的Intermediates/ModuleCache，共64目录、约20.15GiB；源码、Products、evidence和既有模拟器保留。三份精确清单存于本轮output/cache-cleanup*.json。

## 原生转场复核（10-20）

- 在同一已有iPhone17Pro/iOS26.2借用设备，以独立`com.xinkuan.qiuji.entryreview`包分别跑修后/对照的同一真实球堆入口用例；两轮各1项UI通过（各6次往返）。仅录屏用预览包安装/卸载，原App及数据保留、设备恢复原Booted状态，租约已释放。
- `recording/fixed-raw.mp4` 64.927秒、1206×2622，SHA256 `c2608c66d49fdae147ebe415f40f3e304c80c36116b7a6585f6bcea8efd19ec8`；对照`baseline-raw.mp4` SHA256 `90acc49b2422766b4cdedd8b7405afb847157978c68aabb7d0b85bc6f15e39f4`。均由XCTest原生屏幕录制回传并校验。
- 复核整段每2秒联系表，并加密查看首次进入、继续清台和返回的转场帧：修后旋转空隙为黑底，没有观察到白色空白页或持续半屏；浅色首页正常的白底以及系统push边缘仍然保留。页面会先完成push再旋转，并非消除了所有旋转过程。两种外观测试之间的退出/重启属于测试切换，不作为页面入口闪白。
- 交付片段`light-entry-return.mp4`取原片6–33秒、`dark-entry-return.mp4`取39–64秒，覆盖首次/继续清台与返回；仅裁去测试启动/外观重启段、等比缩放、压缩，未加速、插帧、遮挡或剪掉流程中的等待。转换参数见`recording/provenance.json`。
- 本机空间恢复后切换至本机构建r3固定快照补测。2646文件逐一SHA校验与r3一致，证据`local-source-verification.json`；当前6个目标Swift源与r3相同。构建输出独占`build/DailyEntryFix-20261020`，不使用其他任务旧产物。

## 本机兼容性补测（进行中）

- r3固定App源码本机构建通过。SE/iOS17：真实Light/Dark六次往返与深链2项通过；旧3D重复返回用例在关闭菜单紧接点击返回时失败，独立重跑同样失败。失败后仍为667×375完整3D画面，不是半屏；完整xcresult、原生录屏和触摸事件均保留在`local-se17/`及`local-se17-isolate/`。
- 不删除返回断言：r4仅将两处测试中的固定坐标关闭菜单改为点实际关闭控件，等待菜单层消失并断言2D/3D菜单项已不存在、返回可命中，后续再验证是否真正回到首页。App修复源码仍与r3相同。该同步问题尚待复测，不提前归因为测试误报。
- iPad10/iOS26.3：2D和3D竖→横→竖、保持rendererID及返回首页1项通过；7张原图目视完整，证据`local-ipad/`。借用设备均恢复原关机状态并保留数据。
- 本地增量构建一次误从共享仓库发起，已在产物完成前主动中断，不作为验证；重新从已核实的私有源码目录发起构建。最终只使用后者产物，原始日志各自保留。

## 最终收尾（10-20）

- r4仅测试同步改动，4个App目标源及RoomReflectionProbeTests与r3相同；私有工作副本与当前6目标源SHA相同，`final-target-source-check.json`。已验证范围不包含共享工作区内其他并行改动。
- SE补测r4：`testPortraitHomeEntryAndRepeatedReturn` 1 passed/0 failed/0 skipped，实际关闭菜单并等待退出后，两次进入→3D→返回首页成功，7图目视通过。此前真实Light/Dark往返与深链2项通过仍有效；两次初始失败结果保留，不计为成功。
- iPad更新测试后再验1 passed/0 failed/0 skipped，2D/3D各竖→横→竖全程同rendererID、最后返回首页；7图目视通过。证据`local-se17-r4/`、`local-ipad-r4/`各包含原始xcresult、日志、录像、截图、summary.json。
- SE及iPad借用租约全部释放并恢复原Shutdown状态；原App、用户数据、已有设备保留。`local-inventory-after.json`记录收尾。修后标准手机原生录屏使用的App源码与最终实现相同，UI测试的菜单等待修订不改变其画面。
- 定向覆盖：3单测 + 标准手机2UI + SE3UI（其中3D返回最终r4）+ iPad1UI（最终r4）；另有修前同条件对照和双方原生录屏执行。不是全仓回归，也没有真机安装、真机时延/手感验收或本任务发版。
- 性能结论保持有限：同条件模拟器首入主线程场景配置阶段明显缩短，暖进入无稳定加速；偶发持续半屏未复现，但旧方向请求被拒绝的时序冲突已消除，所测往返最终尺寸均正确。浅色旋转空隙黑底、首页外观恢复已从原生录屏抽帧复核。
