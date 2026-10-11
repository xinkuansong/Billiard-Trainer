# D00 · 每日清台 · 每日核心模板逐图复审

日期：2026-10-09。审阅者：GPT-6-astra / astra_teaching。只读App；本报告不改变用户审批。

本图册的两张每日清台对照图未发现可确认的新增静态偏差；它们只证明标准手机2D基础与更多菜单，不能代表每日全状态复审通过。

## 范围与方法

- 已目视 2/2 张，未看0张；设备记录：phone 2。
- 原审批快照：approved 2；已通过与待审图片均纳入。
- 逐图清单与原路径：[coverage-D00.json](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/coverage-D00.json)；输入索引：[D00.json](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/D00.json)。
- 实际方法：联系表2张记录、另开整图1张记录、原分辨率crop复核0张记录（有交集）。先按EXIF旋转至正确阅读方向；A-oriented仅方向归一，A-crops不重采样。联系表只用于整体初筛，具体可见问题均有整图/原像素crop。
- PNG像素不直接当pt。源码尺寸为逻辑pt；没有运行App、构建、测试、模拟器、Figma或触摸验证。文件名中的“拖动/返回/自动/时间”不是本轮动态证据。

## 采用的标准与适用矩阵

[CURRENT.md](/Users/song/projects/13.billiard_trainer/tasks/daily-adaptive/CURRENT.md)与[CORE-TEMPLATE-C56.md](/Users/song/projects/13.billiard_trainer/tasks/table-page-adaptation/CORE-TEMPLATE-C56.md)决定现行组件版本；[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md)、[基础布局与自适应标准.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/基础布局与自适应标准.md)与[每日清台完整标准与跨页面复用分析.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md) §5–6/10提供推广边界。[提示与弹窗规范.md](/Users/song/projects/13.billiard_trainer/docs/design/feedback/提示与弹窗规范.md)按后续C38/B6覆盖旧居中规则。

动作常态应使用中性黑24%轻底/白细边，按下浅绿；不是所有背景绝对透明。普通ⓘ提示无底无边，规则说明顶部、动作独立桌心；主动重开/换玩法确认依DC12/C43保留紧凑磨砂卡。教学常驻读数不当作定时Toast删除。场景深色HUD与普通设置sheet分开判断。

|域|适用性与本页结论|
|---|---|
|标题|适用；短标题单行，返回未压标题。|
|安全区/窗口|适用；标准横屏操作区未见系统遮挡；没有iPad窗口图。|
|球库|适用；1–15固定目标槽单排、整体贴桌；母球不在每日球库。|
|仪表/教学读数|适用；方向/杆速仪表成对，刻度和读数可辨。|
|动作/选中禁用|适用；常态击球为中性轻底；本组无按下态。|
|相机/临时俯视|适用但缺图；只有2D，相机四视角不在本组。|
|菜单/展开面板|适用；显示前置，视图/透明度等收于更多。|
|ⓘ提示/决策/结果|适用但缺图；普通提示、规则处置、主动重开确认、终局均未呈现。|
|深浅色|保留场景深色HUD；本组没有可比较系统主题对。|
|跨状态行为|适用但缺证；无击球、撤销、回放、恢复的过程证据。|
|桌体/几何|适用；2D整桌六袋未见裁切；未做像素换算为pt。|
|可访问性/容量|适用但缺证；没有动态字号、VoiceOver、窄窗与触控测量。|

## 问题与待核事项

没有足够证据确认新增静态偏差。下列覆盖缺口仍保留，不能把“未发现”写成全功能通过。

### D00-G01 · 覆盖缺口

**证据缺口；P2为补证优先级，不计已确认产品缺陷。** 缺少3D四视角、临时2D、打点与透明度显态、普通ⓘ提示、规则决策、主动重开/换玩法确认、成功/失败、iPad横竖及窄窗、深浅色配对。DC12/C43主动确认应保留紧凑磨砂卡；本组没有卡片图，不能据C38宣判所有卡底错误。

依据：[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md) DC21–26、[每日清台完整标准与跨页面复用分析.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md) §3/5.3/5.4。当前证据范围就是下列逐图原路径；需补对应状态/过程或实际窗口测量，不能根据本报告宣布已验收。当前相关静态路径：[FreePlayView.swift:1797](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PositionPlay/Views/FreePlayView.swift:1797)。

## 用户意见逐条回应

本页没有非空用户意见。仍按全域检查全部图片。

## 非用户意见图的独立发现与保留项

已通过的D00-01、02仍逐图检查了球库、双尺、动作和菜单。未把现行模板本身的既有球库小热区例外重新报告为本次新增错误。

## 逐图观察记录

|ID/原图|状态说明|实际方法|结论/问题|
|---|---|---|
|[D00-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P01/title-r04/daily-after.png)|单行对照 · 每日清台|contact-sheet, original|2D桌框、顶栏、左右仪表及当前可见操作无新增静态异常。|
|[D00-02](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P01/c56-native-r03/pro-light/-[DailyAdaptivePanelUITests testP01AndDailySharedPanelsAppearance]/daily-2D-more.png)|每日清台 · 同一共享菜单|contact-sheet|2D桌框、顶栏、左右仪表及当前可见操作无新增静态异常。|

## 交付边界

本轮仅审阅并记录，没有修改App、原图、用户审批、共享进度或返工日志。源码与截图可能来自不同批次：源码结论标为静态路径，截图只证明该帧。后续修复应按功能页补齐对照，触摸、时序、相机手感、真机性能分别验收。
