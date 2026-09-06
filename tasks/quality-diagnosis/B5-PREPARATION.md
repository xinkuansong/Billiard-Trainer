# B5 代表设备横向测试准备

2026-09-05，只读审阅 snapshot-002；没有改代码、运行测试或操作模拟器。以下是方法级候选白名单和最小执行组合，**不是通过报告**。主控确认当前B1–B4已跑结果后按同一业务指纹引用，避免重复主基线。

## 先处理两个范围问题

1. **M3“横竖”与当前产品方向契约不同。** snapshot `project.yml:161` 仅 `UIInterfaceOrientationPortrait`，`PhotoPermissionInfoPlistTests.test_supportedOrientations_arePortraitOnly` 与现有 `ScreenshotTourUITests.testV50IPadPortraitOnlyBoundary` 明确只支持竖屏。B5应执行“横屏请求后的行为诊断”：核对是否仍竖屏、无崩溃/遮挡、可返回；不能把保持竖屏当横屏布局通过，也不能擅自修改方向支持。报告列“横屏未支持，当前规格/测试约束”。主控已确认：这是对PLAN-v2 M3“横竖”的有效规格解释修正，执行旋转请求后的受支持布局验证，无需再问用户或新增横屏功能。
2. 旧全套不是安全白名单。`DeviceMatrixUITests.testRootSafeAreaScrollAndPrimaryCTA` 仍找“开始训练/自由记录”；`V50StateMatrixUITests.testFiveRootsAndLongContentAtCurrentContentSize` 仍找 `trainingHome.freeRecord`，当前正常入口用 `trainingHome.freeTraining`。`testProfileAndPlanKeyboardReachability` 仍走旧个人资料假设；`testGuestFreeAndForcedProBoundaries`有已知旧游客标签且强制Light。不要以它们失败直接判产品，也不要调用整个DeviceMatrix/V50StateMatrix。

## 优先白名单：已有断言与独立截图

下表给完整selector；每条单独输出目录，复用相同文件名的截图不会互盖。V51全部只在内存容器/测试宿主或深链操作，无制作资产写盘；其页面级布局证据不能替代正常入口覆盖。

| ID | 完整selector | 覆盖及证据 |
|---|---|---|
| R | QiuJiUITests/QualityDiagnosticUITests/testFiveRootsReachable | 已有五根正常入口、记录空态、5张图；SC02/03/34局部 |
| N | QiuJiUITests/QualityDiagnosticUITests/testNormalFreeTrainingPersistsAfterProcessRestart | 已有正常选动作/输入/保存/重启记录，磁盘独立设备；SC34/35键盘与CTA，保留QD012已知缺陷 |
| D | QiuJiUITests/QualityDiagnosticUITests/testLibraryDetailTryoutAndReturn | 已有正常详情与试打返回，多张图；详情等待渲染/键盘首次提示按已修订诊断前提执行 |
| T | QiuJiUITests/V51ResponsiveLayoutUITests/testActiveTrainingTimerIsSingleLineAndClearsActions | 100小时长计时单行、3操作44pt且不相交、暂停/跳过；3图+frame JSON |
| F | QiuJiUITests/V51ResponsiveLayoutUITests/testMinimizedTrainingClearsAllFiveTabs | 浮标完整在窗口、与五Tab不相交、逐Tab点击、恢复100小时计时；2图+frame JSON |
| S | QiuJiUITests/V51ResponsiveLayoutUITests/testCompactShotStageRailsAndPaletteDoNotOverlap | 自由击球深链→明确已就绪→切自由→侧轨/球库命中区与不相交→打开关闭打点盘；2图+frame JSON |
| O | QiuJiUITests/V51ResponsiveLayoutUITests/testRestOverlayAndSessionLocalMinimizeRemainReachable | 休息弹层→最小化可展开且不冒充跨Tab浮标；2图+frame JSON |
| C | QiuJiUITests/V51ResponsiveLayoutUITests/testResponsiveComponentProbeKeepsPaletteStatusAndChipsReachable | 长状态文案、4模式Chip可达、15球逐点真实更新lastTap；1图+frame JSON，组件宿主限定 |

V51有少量原有有界重启/点击恢复分支；运行日志必须记录是否触发，不能隐去首次路由/AX失败，也不因最终通过直接归因“只是环境”。本轮未修改这些旧行为。

R/N/D现有launch没有 `-v51.followSystemAppearance`，不能仅设simctl就标Light/Dark。执行前在专用设备通过真实偏好页选择“跟随系统”并保留证明，所有重启后核对实际渲染；或由主控为诊断专用helper加入贯穿所有launch的既有followSystemAppearance参数并登记测试叠加层差异。本只读任务不修改helper。V51 T/F/S/O/C已在每个launch显式使用该参数。

## 条件白名单：独立叶目录/补足证据后使用

| ID | 完整selector | 前提与限制 |
|---|---|---|
| L | QiuJiUITests/ScreenshotTourUITests/testV50IPadTheoryT07NavigationRegression | 正常理→球团管理、中文返回存在/英文Back不存在、1图；不证明滚动到底或返回动作实际成功 |
| P | QiuJiUITests/ScreenshotTourUITests/testV50IPadPortraitOnlyBoundary | 发真实landscapeLeft请求后App frame仍竖向，再恢复portrait，1图；方向负向能力边界，非横屏适配 |
| NA | QiuJiUITests/P8_ProfileSettingsUITests/testTrainingReminderRealSystemPromptAllowed | 必须全新通知未决定态；真实SpringBoard/monitor点允许、handledSystemPrompt为true、App状态和开关核对 |
| ND | QiuJiUITests/P8_ProfileSettingsUITests/testTrainingReminderRealSystemPromptDenied | 必须另一个全新未决定设备；真实拒绝、App解释、开关回退；不得预授或把已拒绝当初次弹框 |

L/P的 `resetV47ShotDirectory()` **会递归删除其输出叶目录**。只能给本次新建、空且可删除的 `/private/tmp/qiuji-v50/quality-b5/<RUN>/<method>/shots`，或snapshot内部 `build/v51/quality-b5/<RUN>/<method>/shots`；通过 `TEST_RUNNER_V50_SHOT_DIR`直接注入。不得给父报告目录、旧证据目录、正式截图目录。普通 `build/quality-diagnosis/...`不满足旧helper允许范围，不能直接塞入。运行后保留完整叶目录归档路径/哈希。L/P的launch不强制followSystem，须同R/N/D先钉外观偏好；P故意使用普通磁盘启动，专用设备且标明其数据前提。

NA/ND测试本身无显式成功截图附件。断言确实要求真实系统弹框，但B5需要保留交互证据：先检查xcresult是否保留相关步骤截图/录屏；若没有，应单独增加诊断附件封装后再执行，不能用一张最终设置页截图冒充过程。无需登录/用户账号，不证明通知实际到点送达。不要用无法确认受支持的 `simctl privacy reset notifications` 当已重置；两台新专用设备最明确。

## 可直接补充的安全单测方法

前缀 `QiuJiTests/`，没有UI资产写盘、制作或真实通知权限调用。每个Runtime执行一遍即可，不为Light/Dark/字号重复。

```text
V51ResponsiveLayoutTests/testTimerBoundaryFormatsPreserveFullElapsedTime
V51ResponsiveLayoutTests/testFloatingIndicatorUsesHoursInsteadOfUnboundedMinutes
V51ResponsiveLayoutTests/testCompactStageCapsRailsAt180And45PercentOfTable
V51ResponsiveLayoutTests/testHardAvailableHeightWinsOverVisualMinimum
V51ResponsiveLayoutTests/testCompactRailUsesTableRatioWhenItIsLowerThan180
V51ResponsiveLayoutTests/testNegativeAvailableHeightNeverProducesNegativeRail
V51ResponsiveLayoutTests/testRegularStageRetains264PointMaximum
V51ResponsiveLayoutTests/testPaletteUsesCompactVisualsButAtLeast44PointSlotsOnSE
V51ResponsiveLayoutTests/testPaletteIsWidthCappedAndRegularOnIPad
V51ResponsiveLayoutTests/testPaletteWidthDerivesFromSafePageWidthAcrossTiers
V51ResponsiveLayoutTests/testPaletteContainsCueAndAllFifteenObjectBallsInTwoRows
V51ResponsiveLayoutTests/testPowerMappingRoundTripsAcrossCompactAndRegularRailLengths
V51ResponsiveLayoutTests/testTableGeometryDoesNotDependOnResponsiveChromeTier
V53ProfilePreferencesTests/testReminderPermissionDeniedDoesNotSchedule
V53ProfilePreferencesTests/testReminderAllowedSchedulesAndDisableCancels
PhotoPermissionInfoPlistTests/test_photoLibraryAddUsageDescription_present
PhotoPermissionInfoPlistTests/test_photoLibraryUsageDescription_present
PhotoPermissionInfoPlistTests/test_cameraUsageDescription_present
PhotoPermissionInfoPlistTests/test_developmentRegion_isSimplifiedChinese
PhotoPermissionInfoPlistTests/test_supportedOrientations_arePortraitOnly
```

合计20个方法/Runtime。V53这里只用mock scheduler两项，不运行整个含StoreKit的class。InfoPlist方法证明当前测试宿主产物，默认Debug结果不能代替Release产物。布局数学单测不是视觉正确或真实操作验收。

## 最小代表组合与顺序

设备型号/Runtime由主控已告知可用，本任务未运行simctl核验；执行前动态读设备清单并绑定具体新建UDID，不能按name/OS=latest选择。M2=SE3/iOS17.0；M3=mini A17 Pro/iOS26.2。M1沿用诊断17Pro/iOS26.2。

| 组合 | 初步选择 | 目的 |
|---|---|---|
| M1 Light/large/portrait | 引用同指纹B1–B4的R/N/D；补T/F/S/O中未有证据者 | 主状态基线，不重复所有页面 |
| M2 Light/large/portrait | R、N、T、S | 小屏旧Runtime根页、真实保存输入、长计时、球桌打点弹层 |
| M3 Light/large/portrait | R、N、D、S、L、P | iPad根页/训练键盘/详情/球桌/中文长文入口/旋转请求边界 |
| M4 M1 Dark/large/portrait | R、D、T、S、O | 与Light同fixture对照根页/详情/训练/工具/弹层 |
| M4 M3 Dark/large/portrait | R、D、S、O | iPad同状态浅深对照 |
| M5 M2 Light/AX5/portrait | R、N、T、F、C | 最大辅助字号CTA、真实输入保存、长计时/浮标、长状态和球库 |
| M5 M3 Light/AX5/portrait | R、N、C、L | iPad最大字号根页、输入保存、组件及长文入口 |

按组合先跑1条轻量R确认安装/语言/输出，再启动其余。所有UI串行，每单元独立DerivedData、log、xcresult和截图；也可同UDID串行共享已验证DerivedData但输出永不复用。P单独执行，结束后确认portrait，不把方向状态带到其他方法。M2保存若同RuntimeSwiftData失败，保留原证据，先做最小复现，不把矩阵扩成全部功能测试。

这仍是代表小批，**不是SC02全入口/SC03全部空态/SC34–35全页完成**。SC02主清单由B1–B4已有正常入口补齐；L的长文仅入口截图，长文底部可达/返回需要后续更强方法。M5昵称/模版输入保存、VoiceOver标签顺序/实听仍缺，N只补真实训练心得输入。空收藏、无搜索结果、加载失败与真空态区分同样不能靠R代替。

## 设置与证据核对

现有矩阵脚本采用以下值，主控可用相同命令机制；这里只列形式，不执行：

```text
xcrun simctl ui <UDID> appearance light|dark
xcrun simctl ui <UDID> appearance
xcrun simctl ui <UDID> content_size large|accessibility-extra-extra-extra-large
xcrun simctl ui <UDID> content_size
xcrun simctl ui <UDID> increase_contrast disabled
xcrun simctl ui <UDID> increase_contrast
```

- 每项设置立即回读存档，但读回只证明系统值。用同一设备/状态下实际截图背景、卡片、文字颜色分布和图像亮度交叉核对Light/Dark；SceneKit工具可能设计上始终暗色，不能以工具图不变判故障，根页/设置/弹层用于外观验证。
- 字号必须用同一页面的实际文字行数/字形高度/布局变化与CTA可操作作证。AX树报字号设置不能代替渲染；固定字号控件不必都变大，但正文是否响应需逐项解释。保存默认与AX5原图，别只比较全图哈希。
- 横竖由P真正发XCUIDevice请求并读App内容frame，系统设备orientation和截图像素旋转不等于App支持横屏。现有P没有实际横向页面几何，按能力边界报告。
- 用新鲜叶目录的期望图数/附件名收账，记录业务、诊断文件、project/scheme、selectors哈希与实际退出码。缺图/纯色/旧图不得靠别轮补齐。对正常等价同图需要逐对解释，不能广泛allowlist。
- 不改变/重置用户已有模拟器，测试期间不向Simulator发CUA事件；外部任务焦点干扰另列环境事件。Bold Text/Reduce Motion/Reduce Transparency/Split View未可靠设定和读回则记录缺口，不能用launch参数冒充系统态。

## SC36 性能与稳定性：先记录，后谈阈值

现有 `QiuJiUITests/ScreenshotTourUITests/testV47TrainingAndHistoryPerformanceBaseline` 可作**条件观测**：XCTClock/CPU/App内存/scrolling signpost，训练与记录各静置10秒滚动15秒；不写制作资产。但只1次measure iteration，未注入1000条数据、未测冷启动，沿用磁盘状态且没有通过阈值，不列为性能验收白名单。

COVERAGE要求5次冷启动、1000条列表/统计、10轮工具开关。当前缺固定数据生成/验证、5次launch metric和10轮同进程回放方法，不能重复启动已有工具测试10次冒充内存增长测试。建议主控单独定义本机/编译模式/数据指纹/预热规则和观测窗口，记录中位数、最大值、基线与末值及崩溃事件；对测试宿主与App进程分别取样。有效产品硬阈值未锁定，旧规则“冷启动<2s/55FPS/100MB”不足以直接当本轮验收承诺。模拟器测值不外推真机热/功耗或流畅度。

## SC37 Release 与 SC38 系统行为

- `scripts/Makefile build` **硬编码Debug**，传 `CONFIGURATION=Release`不会改变它；不要把普通make build标Release。现有archive目标才显式Release，但涉及设备签名/Archive成本，不应为只验证模拟器产物而直接借发布流程。
- 主控需在允许的构建入口中明确提供只构建的Release配置路径，真实日志显示Release、产物路径可验证，单独检查App与Extension的Info.plist/权限文案/zh-Hans/API与legal配置/包体和资源列表/制作与Debug入口隔离。不能只grep `#if DEBUG`或看Debug测试通过。此项当前“路径待落定”，本任务不改Makefile、不Archive、不发布。
- SC38的mock两项与真实允许/拒绝UI只覆盖授权/调度调用与回显；实际到点送达、时区改变、后台LiveActivity恢复/结束，仍需真机和具体已有任务状态流程。没有安全审核过的LiveActivity自动化selector就明列缺口，不搜索不到却宣布没有测试。
- M6账号、真权限硬件、音效/静音、通知/LiveActivity实景不在M1–M5通过结论中。
