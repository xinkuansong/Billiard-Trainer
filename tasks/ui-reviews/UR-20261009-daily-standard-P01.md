# P01 · 分离角与走位 · 每日核心模板逐图复审

日期：2026-10-09。审阅者：GPT-6-astra / astra_teaching。只读App；本报告不改变用户审批。

11张均已审；用户要求的教学读数精简有明确对应。共享菜单、打点透明度和两种系统外观的场景HUD未见新增静态偏差；尚有iPad及提示状态覆盖缺口。

## 范围与方法

- 已目视 11/11 张，未看0张；设备记录：phone 7、se 4。
- 原审批快照：approved 9、changes 1、pending 1；已通过与待审图片均纳入。
- 逐图清单与原路径：[coverage-P01.json](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/coverage-P01.json)；输入索引：[P01.json](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/P01.json)。
- 实际方法：联系表11张记录、另开整图1张记录、原分辨率crop复核1张记录（有交集）。先按EXIF旋转至正确阅读方向；A-oriented仅方向归一，A-crops不重采样。联系表只用于整体初筛，具体可见问题均有整图/原像素crop。
- PNG像素不直接当pt。源码尺寸为逻辑pt；没有运行App、构建、测试、模拟器、Figma或触摸验证。文件名中的“拖动/返回/自动/时间”不是本轮动态证据。

## 采用的标准与适用矩阵

[CURRENT.md](/Users/song/projects/13.billiard_trainer/tasks/daily-adaptive/CURRENT.md)与[CORE-TEMPLATE-C56.md](/Users/song/projects/13.billiard_trainer/tasks/table-page-adaptation/CORE-TEMPLATE-C56.md)决定现行组件版本；[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md)、[基础布局与自适应标准.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/基础布局与自适应标准.md)与[每日清台完整标准与跨页面复用分析.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md) §5–6/10提供推广边界。[提示与弹窗规范.md](/Users/song/projects/13.billiard_trainer/docs/design/feedback/提示与弹窗规范.md)按后续C38/B6覆盖旧居中规则。

动作常态应使用中性黑24%轻底/白细边，按下浅绿；不是所有背景绝对透明。普通ⓘ提示无底无边，规则说明顶部、动作独立桌心；主动重开/换玩法确认依DC12/C43保留紧凑磨砂卡。教学常驻读数不当作定时Toast删除。场景深色HUD与普通设置sheet分开判断。

|域|适用性与本页结论|
|---|---|
|标题|适用；现有3+3两行标题；10-09单行优先属于新要求，未作自然文字容量实测。|
|安全区/窗口|适用；手机/SE安全区未见遮挡；iPad未提供。|
|球库|保留业务差异；15目标槽和至多两目标球的教学规则，不强套每日球组规则。|
|仪表/教学读数|适用；双尺与杆速读数保留；教学左侧读数按S01更新。|
|动作/选中禁用|适用；击球/重打/回放常态中性，禁用变灰；无按下态证据。|
|相机/临时俯视|适用；3D四视角可见；无本页临时俯视完整状态链。|
|菜单/展开面板|适用；更多、瞄准子菜单、透明度均有图，SE较长菜单需滚动，不能仅凭首屏末行截断判故障。|
|ⓘ提示/决策/结果|适用但缺图；源码dailyInformation为info.circle白字无底；图册未覆盖典型提示与规则处置。|
|深浅色|保留深色场景HUD；SE light/dark文件对照基本一致是场景设计，不是主题失效。|
|跨状态行为|适用但缺证；自动回台图片只显示回台后状态，不证明自动动作和耗时。|
|桌体/几何|适用；2D完整桌框；3D近景按教学两球任务判断，不强制六袋。|
|可访问性/容量|证据不足；没有iPad、最大字号、实际热区和连续交互证据。|

## 问题与待核事项

### P01-S01 · 教学读数尚未采用用户指定的重合图示

- 分类：**用户新增要求**；P2。影响呈现一致性、可读性或核验完整性；无已证实的崩溃/不可操作路径，不升P1。
- 实际现状：原分辨率左栏为“球形1/2”“切角9°”和厚薄文字位置“—”；没有两个球的重合图形。用户要求去掉球形计数，保留切角，重合图下仍保留必要厚薄文字。
- 标准：[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md) DC14；[REVIEWS.md:281](/Users/song/projects/13.billiard_trainer/tasks/table-page-adaptation/REVIEWS.md:281)最新意见
- 源码（静态路径）：[FreePlayView.swift:158](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PositionPlay/Views/FreePlayView.swift:158) simulationReadout用三个Text；[AngleDynamicView.swift:39](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/AngleDynamicView.swift:39)已有ThicknessOverlapIcon参照
- 建议与范围：复用同一切角来源与ThicknessOverlapIcon语义；仅撤去计数展示，不取消最多两目标球限制；无有效接触时清楚表示未知。 影响：P01两种模式及手机/SE/iPad读数。
- 证据：[P01-02](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P01/c56-native-r03/pro-light/-[DailyAdaptivePanelUITests testP01AndDailySharedPanelsAppearance]/p01-2D-more.png)。对应实际观察crop/整图见coverage。
- 边界：现有计数为业务读数，不倒推为违反旧标准；这里是新增展示要求。

### P01-G01 · 覆盖缺口

**证据缺口；P2为补证优先级，不计已确认产品缺陷。** 没有iPad横竖/窄窗、临时俯视、拖盘连续预览、母球落袋提示显态、击球结果与回放过程。P01-03原审批待审保持不变；本轮已看图，不代用户通过。

依据：[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md) DC21–26、[每日清台完整标准与跨页面复用分析.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md) §3/5.3/5.4。当前证据范围就是下列逐图原路径；需补对应状态/过程或实际窗口测量，不能根据本报告宣布已验收。当前相关静态路径：[FreePlayView.swift:1825](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PositionPlay/Views/FreePlayView.swift:1825)。

## 用户意见逐条回应

**P01-02 原话：**

> 球形1/2这种可以直接拿掉，只保留切角和，球与球的重合度展示，而且重合度展示，不要用文字的形式，用两个球重合度的图形展示（然后下面展示必要的重合度文字，像角度与瞄准中的那样）

同意。撤去球形计数，保留切角；重合度使用双球图形，并保留图下必要厚薄名称。不是删除全部文字，也不改两目标球业务上限。见S01。

## 非用户意见图的独立发现与保留项

已通过的P01-05仍检查了44%透明度面板与白盘；未发现隐藏下层控件来避让的证据。P01-09/10的场景深色菜单一致符合刻意的HUD语义。

## 逐图观察记录

|ID/原图|状态说明|实际方法|结论/问题|
|---|---|---|
|[P01-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P01/title-r04/after.png)|修改后 · iPhone 17 Pro|contact-sheet|标题、球库、仪表、按钮和场景HUD已检查；读数变更范围见S01。|
|[P01-02](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P01/c56-native-r03/pro-light/-[DailyAdaptivePanelUITests testP01AndDailySharedPanelsAppearance]/p01-2D-more.png)|修正后 · 同一页面、同一系统外观|contact-sheet, original, crop|标题、球库、仪表、按钮和场景HUD已检查；读数变更范围见S01。 关联：P01-S01|
|[P01-03](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P01/c56-native-r03/pro-light/-[DailyAdaptivePanelUITests testP01AndDailySharedPanelsAppearance]/p01-3D-more.png)|分离角与走位 · 3D设置|contact-sheet|标题、球库、仪表、按钮和场景HUD已检查；读数变更范围见S01。|
|[P01-04](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P01/c56-native-r03/pro-light/-[DailyAdaptivePanelUITests testP01AndDailySharedPanelsAppearance]/p01-2D-aim.png)|瞄准模式子菜单|contact-sheet|标题、球库、仪表、按钮和场景HUD已检查；读数变更范围见S01。|
|[P01-05](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P01/c56-native-r03/pro-light/-[DailyAdaptivePanelUITests testP01AndDailySharedPanelsAppearance]/p01-3D-transparency.png)|打点盘透明度设置|contact-sheet|标题、球库、仪表、按钮和场景HUD已检查；读数变更范围见S01。|
|[P01-06](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P01/c56-native-r03/pro-light/-[DailyAdaptivePanelUITests testP01FifteenSlotsAndAutomaticScratchReturn]/p01-auto-cue-return-2D.png)|2D自动回台 · 最终构建|contact-sheet|标题、球库、仪表、按钮和场景HUD已检查；读数变更范围见S01。|
|[P01-07](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P01/c56-native-r03/pro-light/-[DailyAdaptivePanelUITests testP01FifteenSlotsAndAutomaticScratchReturn]/p01-auto-cue-return-3D.png)|3D自动回台 · 右上状态完整|contact-sheet|标题、球库、仪表、按钮和场景HUD已检查；读数变更范围见S01。|
|[P01-08](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P01/title-r04/after-se.png)|修改后 · iPhone SE|contact-sheet|标题、球库、仪表、按钮和场景HUD已检查；读数变更范围见S01。|
|[P01-09](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P01/c56-native-r03/se-light/-[DailyAdaptivePanelUITests testP01AndDailySharedPanelsAppearance]/p01-2D-more.png)|SE · 浅色系统设置|contact-sheet|标题、球库、仪表、按钮和场景HUD已检查；读数变更范围见S01。|
|[P01-10](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P01/c56-native-r03/se-dark/-[DailyAdaptivePanelUITests testP01AndDailySharedPanelsAppearance]/p01-2D-more.png)|SE · 深色系统设置|contact-sheet|标题、球库、仪表、按钮和场景HUD已检查；读数变更范围见S01。|
|[P01-11](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P01/c56-native-r03/se-light/-[DailyAdaptivePanelUITests testP01AndDailySharedPanelsAppearance]/p01-3D-status.png)|SE · 3D状态区|contact-sheet|标题、球库、仪表、按钮和场景HUD已检查；读数变更范围见S01。|

## 交付边界

本轮仅审阅并记录，没有修改App、原图、用户审批、共享进度或返工日志。源码与截图可能来自不同批次：源码结论标为静态路径，截图只证明该帧。后续修复应按功能页补齐对照，触摸、时序、相机手感、真机性能分别验收。
