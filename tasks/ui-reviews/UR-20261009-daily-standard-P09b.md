# P09b · 3D角度 · 每日核心模板逐图复审

日期：2026-10-09。审阅者：GPT-6-astra / astra_teaching。只读App；本报告不改变用户审批。

20张全部复审。按钮常绿与普通训练设置强制深色为已证实静态偏差；输入键盘当前也锁深色，但其旧场景HUD语义与用户新增跟随主题要求应分开。另发现更多菜单“显示”未前置。本页图册全为标准手机，无SE/iPad。

## 范围与方法

- 已目视 20/20 张，未看0张；设备记录：phone 20。
- 原审批快照：changes 4、approved 16；已通过与待审图片均纳入。
- 逐图清单与原路径：[coverage-P09b.json](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/coverage-P09b.json)；输入索引：[P09b.json](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/P09b.json)。
- 实际方法：联系表20张记录、另开整图0张记录、原分辨率crop复核5张记录（有交集）。先按EXIF旋转至正确阅读方向；A-oriented仅方向归一，A-crops不重采样。联系表只用于整体初筛，具体可见问题均有整图/原像素crop。
- PNG像素不直接当pt。源码尺寸为逻辑pt；没有运行App、构建、测试、模拟器、Figma或触摸验证。文件名中的“拖动/返回/自动/时间”不是本轮动态证据。

## 采用的标准与适用矩阵

[CURRENT.md](/Users/song/projects/13.billiard_trainer/tasks/daily-adaptive/CURRENT.md)与[CORE-TEMPLATE-C56.md](/Users/song/projects/13.billiard_trainer/tasks/table-page-adaptation/CORE-TEMPLATE-C56.md)决定现行组件版本；[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md)、[基础布局与自适应标准.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/基础布局与自适应标准.md)与[每日清台完整标准与跨页面复用分析.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md) §5–6/10提供推广边界。[提示与弹窗规范.md](/Users/song/projects/13.billiard_trainer/docs/design/feedback/提示与弹窗规范.md)按后续C38/B6覆盖旧居中规则。

动作常态应使用中性黑24%轻底/白细边，按下浅绿；不是所有背景绝对透明。普通ⓘ提示无底无边，规则说明顶部、动作独立桌心；主动重开/换玩法确认依DC12/C43保留紧凑磨砂卡。教学常驻读数不当作定时Toast删除。场景深色HUD与普通设置sheet分开判断。

|域|适用性与本页结论|
|---|---|
|标题|适用；现为单行3D角度/2D角度，无标题挤压。|
|安全区/窗口|适用；首次设置竖屏、球桌横屏图均完整；本manifest无SE/iPad。|
|球库|保留题目差异；15槽可见但题目拥有目标/袋口，不授予每日摆球能力。|
|仪表/教学读数|保留差异；题号/成绩/答案/误差是常驻训练内容，不应全改为短Toast；无方向/杆速调节需求。|
|动作/选中禁用|既有偏差；常绿答题/下一题与plain样式见S01；辅助圆形是新增要求。|
|相机/临时俯视|适用；四视角、临时俯视、辅助显隐、结果返回都有静态图；无杆速尺时按动作列与桌心布局，不虚报杆速对齐。|
|菜单/展开面板|既有偏差；训练设置排在显示上方，见S04；固定模式不需要视图项。|
|ⓘ提示/决策/结果|适用；结果结构需持续可读；本组未见普通信息Toast，不能证明ⓘ规范全面达标。|
|深浅色|设置sheet应跟随主题见S02；场景键盘旧为刻意深色，新增跟随主题要求见S03。|
|跨状态行为|只能核对若干前后帧；答题正确性、重复提交、返回不丢题、色变时序、触觉均未动态复测。|
|桌体/几何|适用；2D六袋/3D本杆主体可读；独立桌体渲染与含HUD原生图分开计数。|
|可访问性/容量|证据不足；本manifest没有SE/iPad、最大字号、实际触摸或VoiceOver。|

## 问题与待核事项

### P09b-S01 · 答题/下一题常态实绿，未继承每日按下反馈

- 分类：**既有标准偏差**；P2。影响呈现一致性、可读性或核验完整性；无已证实的崩溃/不可操作路径，不升P1。
- 实际现状：原像素显示答题为浅绿实底深字；结果下一题使用同源样式。辅助/隐藏是52×44圆角矩形，选中仅变绿字。主动作是普通点击，不是需要常绿保留的主动重开确认卡主按钮。
- 标准：[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md) DC09/12；[HUDStyle.swift:133](/Users/song/projects/13.billiard_trainer/QiuJi/Core/DesignSystem/HUDStyle.swift:133) BTHUDPressStyle/BTHUDControlBackground
- 源码（静态路径）：[SceneAimingView.swift:321](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/SceneAimingView.swift:321)辅助直接背景+.plain；:348 primaryAction直接HUDStyle.accent+.plain
- 建议与范围：主动作继承常态中性轻底/白细边和按下浅绿；按用户新增意见把辅助改圆形并保留开关语义，不把选中与按下混为一态。 影响：2D/3D观察答题、结果下一题/完成。
- 证据：[P09b-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/angles/3D-assist.png)；[P09b-16](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/angles/3D-temporary-result.png)。对应实际观察crop/整图见coverage。
- 边界：“没有背景颜色”按现行黑24%轻底解释，不能错误改成完全透明；按下变化由静态样式路径核查，未实触。

### P09b-S02 · 普通训练设置被强制深色

- 分类：**既有标准偏差**；P2。影响呈现一致性、可读性或核验完整性；无已证实的崩溃/不可操作路径，不升P1。
- 实际现状：原像素首次训练设置为黑底白字。仅暗截图不能证明故障，但源码在首次入口、sheet和List三处显式锁dark，系统浅色不会作用于这一路。
- 标准：[Colors.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/DesignSystem/Colors.swift)语义颜色；[SKILL.md](/Users/song/projects/13.billiard_trainer/.cursor/skills/swiftui-design-system/SKILL.md)普通设置Light/Dark；场景HUD例外不覆盖原生训练设置List
- 源码（静态路径）：[SceneAimingView.swift:44](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/SceneAimingView.swift:44)首次preferredColorScheme(.dark)；:431设置sheet；:463内容environment(.dark)
- 建议与范围：移除普通设置子树强制深色，保留语义token与场景HUD本身的深色；复核首次竖屏与训练中sheet两条入口。 影响：P09a/P09b共用设置内容。
- 证据：[P09b-03](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/angles/3D-initial-settings.png)。对应实际观察crop/整图见coverage。
- 边界：原图没有Light/Dark配对，因此结论是当前源码明确锁深色，非截图证明系统当时是浅色。

### P09b-S03 · 答题键盘当前锁深色；跟随主题属于用户新增要求

- 分类：**用户新增要求**；P2。影响呈现一致性、可读性或核验完整性；无已证实的崩溃/不可操作路径，不升P1。
- 实际现状：原像素键盘深灰面板、数字白字、空输入提交变暗；不是系统键盘，而是NumericKeypadHUD。源代码明确usesSceneStyle:true且environment.dark。
- 标准：[HUDStyle.swift:25](/Users/song/projects/13.billiard_trainer/QiuJi/Core/DesignSystem/HUDStyle.swift:25)旧场景面板刻意固定深底；本页用户10-09新意见
- 源码（静态路径）：[SceneAimingView.swift:245](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/SceneAimingView.swift:245)usesSceneStyle:true与:255强制dark；[NumericKeypadHUD.swift:78](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/NumericKeypadHUD.swift:78)场景固定panelBackground
- 建议与范围：按新要求单独让输入面板及键帽跟随系统主题；保留题面位置、44键高、禁用提交、取消与遮挡拦截，不扩大为所有3D HUD变浅色。 影响：P09a/P09b共用输入面板。
- 证据：[P09b-04](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/angles/3D-input.png)。对应实际观察crop/整图见coverage。
- 边界：同意“当前不区分”的静态事实；旧规范允许场景深色，故不回溯为此前主题实现错误。

### P09b-S04 · 更多菜单把训练设置放在显示之前

- 分类：**既有标准偏差**；P2。影响呈现一致性、可读性或核验完整性；无已证实的崩溃/不可操作路径，不升P1。
- 实际现状：原像素菜单首项为训练设置，其后才是显示标题与台面网格；二者都可读，无截字。
- 标准：[每日清台完整标准与跨页面复用分析.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md) §5.2 C51菜单r5显示前置；[CORE-TEMPLATE-C56.md](/Users/song/projects/13.billiard_trainer/tasks/table-page-adaptation/CORE-TEMPLATE-C56.md)
- 源码（静态路径）：[SceneAimingView.swift:225](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/SceneAimingView.swift:225)settingsItems顺序
- 建议与范围：保持“更多→训练设置”已确认层级，调整为显示组在前、训练设置业务入口在后；固定2D/3D训练仍不新增视图切换。 影响：P09a/P09b共享更多菜单。
- 证据：[P09b-05](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/angles/3D-more.png)。对应实际观察crop/整图见coverage。
- 边界：这是非用户意见图中的独立发现；10-08确认了训练设置层级，不等同明确豁免显示前置顺序。

### P09b-G01 · 覆盖缺口

**证据缺口；P2为补证优先级，不计已确认产品缺陷。** 缺SE/iPad、窄窗、最大字号、浅深主题对照、完成20题/限额/取消或离页恢复、按下态与触控。临时2D结果/回到原机位等静态图不证明连续恢复、相机手感或性能。

依据：[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md) DC21–26、[每日清台完整标准与跨页面复用分析.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md) §3/5.3/5.4。当前证据范围就是下列逐图原路径；需补对应状态/过程或实际窗口测量，不能根据本报告宣布已验收。当前相关静态路径：[SceneAimingView.swift:299](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/SceneAimingView.swift:299)。

## 用户意见逐条回应

**P09b-01 原话：**

> 按键问题，同2D

同意与2D同源。主动作常绿为既有偏差，辅助改圆是新增形状要求；通过共享actionColumn/primaryAction一并处理，见S01。

**P09b-03 原话：**

> 深色和浅色问题，同2D角度

同意，需要和2D一起处理。源码三处强制dark，普通设置不能借场景HUD例外锁深色，见S02。

**P09b-04 原话：**

> 键盘问题同2D角度

同意当前键盘锁深色。旧场景面板有刻意深色设计，按本次新要求局部适配键盘，不整体翻转场景HUD，见S03。

**P09b-16 原话：**

> 下一题按键样式，同其他的按键

同意。下一题沿用同一常绿primaryAction，临时2D结果也应继承普通动作常态/按下样式，见S01；不需改题目结果本身。

## 非用户意见图的独立发现与保留项

重新审了用户通过的更多、换题、结果、重新自由练习及返回状态：S04菜单顺序为独立发现；常绿主动作也扩展到结果/下一题，而非只处理用户圈出的观察态。成绩与误差为常驻内容，保留层级，不因C38全部移动桌心或消失。

## 逐图观察记录

|ID/原图|状态说明|实际方法|结论/问题|
|---|---|---|
|[P09b-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/angles/3D-assist.png)|angles · 3D-assist|contact-sheet, crop|题目/结果读数、单行标题、球库和当前场景已查；主动作常态及共享菜单差异见本页S01/S04。 关联：P09b-S01|
|[P09b-02](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/angles/3D-first-person.png)|angles · 3D-first-person|contact-sheet|题目/结果读数、单行标题、球库和当前场景已查；主动作常态及共享菜单差异见本页S01/S04。|
|[P09b-03](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/angles/3D-initial-settings.png)|angles · 3D-initial-settings|contact-sheet, crop|训练设置List可见、选项与操作可读；强制深色为当前源码已证实路径，见S02。 关联：P09b-S02|
|[P09b-04](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/angles/3D-input.png)|angles · 3D-input|contact-sheet, crop|输入面板与取消/数字键完整，空输入提交为禁用外观；锁深色及新增主题要求见S03。 关联：P09b-S03|
|[P09b-05](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/angles/3D-more.png)|angles · 3D-more|contact-sheet, crop|菜单内容可读；训练设置先于显示，独立发现S04；不把缺少模式切换判为错误。 关联：P09b-S04|
|[P09b-06](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/angles/3D-next.png)|angles · 3D-next|contact-sheet|题目/结果读数、单行标题、球库和当前场景已查；主动作常态及共享菜单差异见本页S01/S04。|
|[P09b-07](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/angles/3D-observe.png)|angles · 3D-observe|contact-sheet|题目/结果读数、单行标题、球库和当前场景已查；主动作常态及共享菜单差异见本页S01/S04。|
|[P09b-08](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/angles/3D-player-observation.png)|angles · 3D-player-observation|contact-sheet|题目/结果读数、单行标题、球库和当前场景已查；主动作常态及共享菜单差异见本页S01/S04。|
|[P09b-09](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/angles/3D-restarted-free.png)|angles · 3D-restarted-free|contact-sheet|题目/结果读数、单行标题、球库和当前场景已查；主动作常态及共享菜单差异见本页S01/S04。|
|[P09b-10](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/angles/3D-result-return.png)|angles · 3D-result-return|contact-sheet|题目/结果读数、单行标题、球库和当前场景已查；主动作常态及共享菜单差异见本页S01/S04。|
|[P09b-11](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/angles/3D-result.png)|angles · 3D-result|contact-sheet|题目/结果读数、单行标题、球库和当前场景已查；主动作常态及共享菜单差异见本页S01/S04。|
|[P09b-12](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/angles/3D-return-to-aim.png)|angles · 3D-return-to-aim|contact-sheet|题目/结果读数、单行标题、球库和当前场景已查；主动作常态及共享菜单差异见本页S01/S04。|
|[P09b-13](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/angles/3D-temporary-assist-hidden.png)|angles · 3D-temporary-assist-hidden|contact-sheet|题目/结果读数、单行标题、球库和当前场景已查；主动作常态及共享菜单差异见本页S01/S04。|
|[P09b-14](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/angles/3D-temporary-assist-restored.png)|angles · 3D-temporary-assist-restored|contact-sheet|题目/结果读数、单行标题、球库和当前场景已查；主动作常态及共享菜单差异见本页S01/S04。|
|[P09b-15](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/angles/3D-temporary-assist.png)|angles · 3D-temporary-assist|contact-sheet|题目/结果读数、单行标题、球库和当前场景已查；主动作常态及共享菜单差异见本页S01/S04。|
|[P09b-16](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/angles/3D-temporary-result.png)|angles · 3D-temporary-result|contact-sheet, crop|题目/结果读数、单行标题、球库和当前场景已查；主动作常态及共享菜单差异见本页S01/S04。 关联：P09b-S01|
|[P09b-17](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/angles/3D-temporary-return.png)|angles · 3D-temporary-return|contact-sheet|题目/结果读数、单行标题、球库和当前场景已查；主动作常态及共享菜单差异见本页S01/S04。|
|[P09b-18](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/angles/3D-temporary-top-down.png)|angles · 3D-temporary-top-down|contact-sheet|题目/结果读数、单行标题、球库和当前场景已查；主动作常态及共享菜单差异见本页S01/S04。|
|[P09b-19](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/angles/3D-training-settings.png)|angles · 3D-training-settings|contact-sheet|训练设置List可见、选项与操作可读；强制深色为当前源码已证实路径，见S02。|
|[P09b-20](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/angles/3D-whole-table.png)|angles · 3D-whole-table|contact-sheet|题目/结果读数、单行标题、球库和当前场景已查；主动作常态及共享菜单差异见本页S01/S04。|

## 交付边界

本轮仅审阅并记录，没有修改App、原图、用户审批、共享进度或返工日志。源码与截图可能来自不同批次：源码结论标为静态路径，截图只证明该帧。后续修复应按功能页补齐对照，触摸、时序、相机手感、真机性能分别验收。
