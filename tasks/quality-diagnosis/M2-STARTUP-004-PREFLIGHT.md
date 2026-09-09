# M2 普通首次启动与通知拒绝补验

2026-09-08；仅 Test Engineer 草稿，未注册、构建、运行、操作设备或改业务。唯一方法：`QiuJiUITests/M2StartupPermissionDiagnosticUITests/testOrdinaryM2EmptyGuestStartupAndFirstNotificationDenialSurvivePageReentry`。语法 parse 退出 0，不代表类型检查或运行通过。

## 调用链与既有证据

冻结 `QiuJi/App/RootView.swift:10–17` 普通分支直接 `MainTabView`，`:64–65` 的 OnboardingView 仅显式 `-intro.preview` 深链。`MainTabView.swift` 挂载训练与我的 Tab；本方法只给语言参数，按实际首页 `trainingHome.freeRecord`、空态文案与训练 Tab 验收，不再把叶子 OnboardingView 存在当首次路由。

`Features/Training/Views/TrainingHomeView.swift:1923–1960` 空态含“选择一个计划开始训练”和正常自由训练 CTA；队列源卡 ID 来源 `:739`。首次要求源卡数 0，但不把 UI 空态说成磁盘 SQL 空库证明。

`ProfileView.swift:312` 训练目标正常行 → `TrainingGoalView`。后者 `:226–276` 给提醒开关及权限说明真实 ID，`:298–319` 调用 Scheduler 后 permissionDenied 写 reminderEnabled=false 并显示错误；`:324–334` 页面刷新从实际权限更新 denied 说明。失败 alert 为“无法开启提醒”/“知道了”。因此断言实际系统双选项→拒绝→App 解释→off/denied→正常页面重入仍 off/denied 有独立源码依据。

既有 `NOTIFICATION-004-RESULT.md` 的 iPhone17Pro/iOS26.2 deny-ui-001 1/1、47.384s 和独立 OS denied/0/false；deny-retry-ui-001 1/1、35.974s 已证明主环境拒绝与重试。本次仅补 SE3/iOS17 普通磁盘启动的权限代表，复用 SystemBoundary 的真实双选项/错误/状态语义，不重复允许、改时间、重试或其他五根页/训练/工具矩阵。删除 launchClean、内存、force 与外观覆盖参数；不调用任何权限 reset/grant。

## 主控运行前置

- 新专用 iPhone SE (3rd generation)、iOS17、普通 large、Light；空磁盘/Keychain、未决定通知权限。主控保存创建设备及设置读回记录、实际安装包哈希。测试自身校验 runner OS major17 和指定 UDID；不把授权字符串当设备型号、实际视觉颜色或空库物证。
- `QD_M2_STARTUP_AUTHORIZATION=NEW_SE3_IOS17_LARGE_LIGHT_EMPTY_DISK_UNDECIDED`。
- `QD_EXPECTED_DEVICE_UDID` 合法 UUID，必须等于 runner `SIMULATOR_UDID`。
- `QD_SHOT_DIR` 绝对目录；新建唯一 `m2-startup-<UUID>` 子目录并输出路径。env 均兼容 `TEST_RUNNER_` 前缀。
- App 参数仅 `-AppleLanguages (zh-Hans) -AppleLocale zh_CN`，空 launchEnvironment。无业务数据/身份/Pro/intro/内存/外观 flag，无真实账号操作。不宣称整个普通 App 启动完全不发系统或内容请求。

## 严格操作与观察

1. 普通 launch foreground；唯一训练 Tab 已选，空态真实 CTA 完整可见，队列卡 0；PNG/AX。
2. 唯一我的 Tab → 实际游客、无 accountHeader；正常唯一训练目标行露出并进入。
3. `trainingGoal.reminderEnabled` 唯一实际开关，0/可操作；`trainingGoal.reminderAuthorization` 精确“首次开启时会请求系统通知权限”。缺该前置立即失败，不能消除权限重新制造初态。
4. 开启只一次；筛出同时唯一含允许/不允许（或 Allow/Don't Allow）的 alert，优先 SpringBoard host；再核通知语义。两 host 可能映射同一系统 alert，不误算两次弹框。先完整 PNG 与 app AX + system alerts AX，再只点唯一拒绝。
5. App“无法开启提醒”先拍图，唯一“知道了”关闭；实际 off、denied、无时间选择器；截图。
6. 当前唯一“训练目标”NavigationBar 内精确 label“返回”→我的 Tab/游客→正常重入，off/denied 且无系统双选项；截图。

iOS17“返回”依据实际归档 `formal-004-m2-ax5-template-boundary-004/screenshots/template-boundary-C9AB6134-2C1C-482F-9BA4-B7093F23180D-8-reopened-same-uuid-full-name-one-action-review-required.txt:16–17`：编辑模版导航栏按钮 label 返回。它证明该 Runtime 存在此返回呈现，**不证明训练目标页已观察**；草稿只在当前唯一目标导航栏精确匹配，若实际不同须原地取证，由主控有限适配，不能猜首按钮。

正文滚动需实际唯一 ScrollView，按目标 frame 在导航栏上方或 TabBar 下方决定短幅方向，最多 10 步；没有唯一容器或目标 AX 就失败。目标点击前完整可见而非仅 hittable。没有固定屏幕坐标。常规条件等待 12s，进程 foreground15s；不固定睡眠制造成功。

所有捕获先完整 PNG 后完整 App/系统 alert AX，失败在 terminate 前保留；teardown 再拍终态然后 terminate，保留沙盒与 denied 状态。正常结束不改变系统权限。此单方法不替代独立 OS pending 查询、通知送达、真实音频、授权允许或其余 M2 矩阵；最终图审仍由主控执行。
