# Snapshot004 代表矩阵剩余证据审计

2026-09-08。只读核对 PLAN-v2 M1–M5、REMAINING-PRIORITIES-004 包5、B5各图审和相关实际测试体；没有运行测试、改变设备设置、注册工程或修改共享台账。本报告不作新的图像通过结论；引用历史逐图审阅时明确标识。不是全App可访问性通过。

## 最小收尾结论

1. M1 Dark：4个现有方法覆盖空五根、正常详情/试打返回、训练休息弹层、真实工具/打点层。仅Dark不能完成“同状态浅深对照”：优先找对应Light原图；当前旧B5原件不可直接复核，若确无原图，给同4方法补一轮Light建立当前配对，不重跑全部训练保存或物理旅程。
2. iPad AX5：必须补代表长文实际下段与返回。旧模板保存重开、昵称键盘保存返回已有成功证据，不列全链未执行。模板键盘展开时的取景仍缺，可用一个短输入观察补取；不能用已收键盘的模板图片冒充。
3. 紧凑 AX5：必须补模板入口→输入→保存→返回重开，沿当前已成功的TemplateBoundary正常入口、有界实测导航触摸，不再原样运行旧more.isHittable失败。该方法现有取景同样缺输入时键盘，最小诊断适配是在输入完毕、回车前取PNG/AX并核字段/返回控件未被遮挡。代表长文下段在此组合也缺，和iPad共用一个理论方法各执行一次，不扩成21页。
4. QD019同类搜索图标裁切已证实；截图再次看见即关联已有问题，不以修复到绿作为诊断结束条件。c042布局持续忙已有QD029，不拿它当AX5长文补验用例。

## 历史证据与可复用范围

| 原组合 | 已执行证据 | 不得扩大/尚缺 |
|---|---|---|
| M1 Light iPhone17Pro/26.2 | B5.md、B5-M1-LIGHT-REVIEW：RTFSO 5/5、113.024s | 代表布局fixture不等于正常端到端全功能；旧Light原图缺失时报告不能代替当前实际配对图 |
| M2 SE3/17.0 Light | B5-M2-LIGHT-REVIEW、B5.md：根1/1 23.690s；后续正常保存重启1/1 42.314s、唯一备注QD-92DCA1BC；计时和杆法实际图审 | 不重做保存；真实权限/第二runtime引导仍应按B1和后续真实run另核，不能用新26.2的SE代替17.0 |
| M3 mini/26.2 Light | 根1/1 37.528s；core3/3 138.746s；理论导航1/1 30.009s；旋转请求1/1 26.404s，B5-M3-LIGHT-REVIEW | 软件键盘在正常训练录入时实际可见，已满足普通字号代表键盘证据；原App仅portrait，旋转请求后保持portrait不是新增横屏支持 |
| M4 M3 Dark | B5-M3-DARK-REVIEW：4/4 122.107s，13图/4frames，根/详情/休息/工具 | 报告明确Light同名休息图未配齐，不能宣称该状态已浅深成对；最小补配仅O的Light，不重做整iPadDark |
| M4 M1 Dark | B5.md：用户暂停，make2/xcode75 | 不是产品失败，也不是整组通过；保留未完成 |
| M5紧凑AX5 | B5-M2-AX5-REVIEW、B5.md：根1/1、core4/4；正常输入保存重启、计时/浮标/工具；昵称输入已过 | 模板旧input001/002因more.isHittable失败，不核销模板。根页不是长文下段 |
| M5 iPad AX5 | B5-M3-AX5-REVIEW：根1/1 29.842s、core2/2 103.137s、理论导航1/1 32.295s；正常训练输入/磁盘重启；追加模板1/1 50.093s及昵称1/1 34.643s | 理论只前三部分；模板3图均已收键盘；昵称是游客本地，无云或进程重启含义 |

特别核销：formal-extra-m3-ax5-input-001实际只有MenuHit一个方法，错误昵称selector导致0 tests；昵称由formal-extra-m3-ax5-nickname-002补成功，不能写001为2/2。模板唯一名诊断模版77D7B791，保存重开同名、c012/8组1动作；昵称诊断CE30DB51，展开软件键盘和完成按钮均实图审过。

旧B5/extra原始run在当前archive/quality-diagnosis/runs清单中未找到；旧理论外部目录/private/tmp/qiuji-v50/quality-b5/formal-b5-m3-ax5-theory/shots也不存在。历史报告保留的终态/逐图记录可引用为已执行，不能改写未执行；但不能称本次重新打开这些原件复核。004新原件存在：archive/quality-diagnosis/runs/formal-004-learning-remainder-002（含Theory07实际PNG/AX及tested-sources），formal-004-template-boundary-001及observations/template-boundary-001-disk。两者目前证明普通iPhone，不代替矩阵。

## 精确选择器与实际断言

以下均以QiuJiUITests/为target前缀；只选列出的个别方法，禁止整类扫跑。

| 代号/selector（接target前缀） | 方法体实际行为/前提 | 最小用途 |
|---|---|---|
| R QualityDiagnosticUITests/testFiveRootsReachable | launchClean内存游客forceNonPremium；逐Tab要求真实根节点、5图；仅exists不保证整页滚完 | M1 Dark五根 |
| D QualityDiagnosticUITests/testLibraryDetailTryoutAndReturn | 正常搜索c012、详情、点试打、rearrange、返回详情和搜索；有详情等待3秒图；没有击球断言 | M1 Dark正常详情与返回、工具入口 |
| O V51ResponsiveLayoutUITests/testRestOverlayAndSessionLocalMinimizeRemainReachable | 内存forcePremium+activeTraining fixture+followSystemAppearance；真实休息按钮、组间休息层、最小化、44pt restPill、无跨Tab resume；有两阶段PNG/frame | M1 Dark训练/弹层；M3缺失Light休息配对仅此方法 |
| S V51ResponsiveLayoutUITests/testCompactShotStageRailsAndPaletteDoNotOverlap | 内存forcePremium、deeplink.freePlay、followSystemAppearance；等已就绪切自由瞄准、轨道底缘/高度、4个球44pt不相交、打开关闭打点盘，两图 | M1 Dark工具和打点层，不证明实际击球/物理 |
| L LearningTourDiagnosticUITests/testTheory07ClustersLowerScope | 正常理入口→球团管理，滚至“什么时候可以松、什么时候别破”和“本方没有清台路径时，球团反而是宝贵的母球藏身资源”，lower-content图，再返回理分类/原卡；004 remainder002实际28.295s通过 | iPad AX5及紧凑AX5各一次，代表长文下段/返回 |
| B TemplateBoundaryDiagnosticUITests/testInvalidDraftsLongNameAndOneDrillTemplateSurviveProcessRestart | 普通磁盘游客非会员；空名/空动作禁用，64字独立名+c037正常仅保存，同UUID重开及进程重启，精确全文和3组1动作；正常返回；004普通iPhone147.352s成功并独立SQL | 紧凑AX5一次，保留强保存/返回断言；输入时键盘图需小范围诊断适配 |

R/D源：tasks/quality-diagnosis/QualityDiagnosticUITests.swift。O/S源：archive/quality-diagnosis/snapshot-004/source/QiuJiUITests/V51ResponsiveLayoutUITests.swift。L源：tasks/quality-diagnosis/LearningTourDiagnosticUITests.swift，真实运行体可对照archive/quality-diagnosis/runs/formal-004-learning-remainder-002/tested-sources/QiuJiUITests/LearningTourDiagnosticUITests.swift。B源：tasks/quality-diagnosis/TemplateBoundaryDiagnosticUITests.swift。运行前主控按实际scheme/snapshot注册核对，tasks文件存在不等于已注册；LearningTour/MenuHit不在冻结source同名UITests目录，不能猜已被当前工程包含。

T V51ResponsiveLayoutUITests/testActiveTrainingTimerIsSingleLineAndClearsActions可作为M1Dark长计时要求的精确补项：100h fixture、单行/44pt、不相交，暂停/跳过三态。原包5最小训练/层已有O，T不是要求重跑全部F/S/C。若验收要求Dark也保留原M1长计时同状态，单加T，不扩大其他状态。

不得替换：旧DeviceMatrix根方法及V50StateMatrix使用旧开始训练/自由记录节点；V51的testTrainingNumericKeyboardHidesChromeAndKeepsScore、testTrainingInputHidesChromeAndNoteReturnsToSession硬编码forceLight，不能用来证明Dark。ScreenshotTour的testV50IPadTheoryT07NavigationRegression只导航顶部，不能代L；componentProbe是组件宿主，不能代真实工具。MenuHit的旧template方法虽然iPad跑过，其firstMatch“新建模版”可能是图标，且旧more触达不适合紧凑补验。

## 必要诊断前提/允许的小范围适配

- R/D必须传QD_FOLLOW_APPEARANCE=1（支持TEST_RUNNER前缀），QD_SHOT_DIR存在的全新绝对叶目录；capture不会自行建目录且同名覆盖风险由每run独立目录隔离。O/S使用V50_SHOT_DIR（支持前缀），不是V51_SHOT_DIR；没有变量会静默不输出外部图片，应在主控启动前硬核目录并验产物。四方法各有启动，可顺序同设备，但不并发。
- L正常Light/AX5即可，不宣称Dark。当前reveal用app上下110/90的固定留白+单向滚动，visible以节点可见条件判断，不保证长段全文同屏。若矩阵视口造成失败，只允许依据实际ScrollView/window/nav/tabbar frame做有界双向观察适配；分段长文可以多图连续阅读，不放宽成exists，也不强求超过视口的整篇单屏。保留精确下段内容与正常返回oracle。PNG/AX实际核下段、返回及字号效果；不认证教学正确性。
- B要求QD_TEMPLATE_BOUNDARY=NEW_DEDICATED_DISK_GUEST_SIMULATOR、QD_TEMPLATE_DEVICE_UDID精确匹配SIMULATOR_UDID、QD_SHOT_DIR全新绝对目录，均支持TEST_RUNNER前缀。起始空模板；不可借已有D31093A8模板设备满足“新空磁盘”guard。字段输入追加回车后即收键盘，现有long-name图不能证明键盘展开适配。若主控准备最小新伴随方法，可只保留一次有效模板链并在回车前capture：完整name值、实际keyboard存在、字段可见、可用返回/完成不被键盘挡，然后正常收键盘→保存→重开同name/c037→返回。对紧凑屏需保留CTA真实命中，不能点猜坐标。此报告没有新增/修改测试源。
- iPad已存在普通训练及昵称的真实键盘证据，模板保存返回无需再造一套完整成功链。若原M5要求模板专属键盘也必须覆盖，可仅新增正常空草稿→输唯一短名→保留键盘PNG/AX→正常返回丢弃→确认无新增卡的一方法；这补的是模板键盘观察，不代已存在保存证据。不可把该短观察绿称模板保存再次成功。
- forcePremium、activeTraining、inMemory皆只代表受控布局宿主，报告与正常输入磁盘链区分；不算真实购买或真实计划安排。输入用独立标记，不读写其他测试账号。

## 设备现状与排队边界

本次只读xcrun simctl list devices --json：旧M1 439DA53C-2E95-441E-8BD0-A6F8DA6F616D、M2 DACB4EED-91D5-403A-A7C5-10DA70779987、M3 5F88194A-942A-4A20-A5C7-976DDFBF5D07均未列出，不能沿历史“Shutdown”直接复用。当前清单没有iPad；列出的SE均iOS26.2，不能冒充M2/17.0。

可候选只读状态：QiuJi-v51-iPhone-SE-iOS26-AX 27B26F23-5701-4775-A8C5-82E604502D7B为Shutdown/available；它只可作追加26.2紧凑观察，型号/脏数据/当前字号仍未核，不满足原M2 runtime或B新空磁盘授权。D31093A8-5F62-4D98-A99F-40EC578366E6（QD004-TemplateBoundary）Shutdown但已有已验证模板，应保留，不复用清空。当前多个004专用设备Booted，各有其他领域证据，不自动授权用于矩阵。最稳妥由主控新建M1/iPad/SE原组合专用设备；若17.0 runtime目前不可用，记录具体runtime条件缺失，不能删原M2范围。本子任务没有创建/boot/关机设备。

每run开头保存设备型号/runtime/UDID、appearance和content_size实际读回（AX5应为accessibility-extra-extra-extra-large），图片再确认视觉环境；仅目录含dark/ax5不足。串行UI，产物独立目录，不使用会清理既有archive的截图辅助器。若资源不足停在真实前置，不启动并行矩阵争抢主控UI。

## 有界执行顺序及剩余外侧事项

先M1当前Light/Dark必要配对（R/D/O/S，长计时要求另加T）；随后两种AX5设备各L；紧凑B链一次；iPad模板键盘短观察仅在模板专属键盘验收仍要求时补；M3 Light O仅补缺配图。逐批看图/AX：实际颜色、真正下段、键盘及保存返回，以已发现QD019结束同类问题分支，不追绿。

包5还提到M2权限和第二runtime引导：B0-B1.md当前明确主设备iPhone17Pro/26.2，不能由此核销17.0引导。该二项不在本轮三组核心选择器中，仍保留精确runtime和全新权限状态前置；应由主控先核已有原run选择器/终态，再决定各一次正常拒绝说明或引导，不因为本报告没有列方法就取消原范围。M6真实VO、真机手感及系统实达不由本矩阵覆盖。最终记已验/已证实问题/未验/前置不可用，不能把缺原件等同旧测试没执行，亦不能把方法数当覆盖百分比。
