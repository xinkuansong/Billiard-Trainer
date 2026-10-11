# AD01 · 角度与瞄准 · 每日核心模板逐图复审

日期：2026-10-09。审阅者：GPT-6-astra / astra_teaching。只读App；本报告不改变用户审批。

14张全部复审。角弧紧贴目标球的用户观察有原像素依据，属于新增视觉微调；四视角、临时俯视与iPad横竖的可见主体完整。底部教学提示有源码路径但本组没有显态，不能宣称ⓘ无底规范已覆盖。

## 范围与方法

- 已目视 14/14 张，未看0张；设备记录：phone 9、se 2、ipad 3。
- 原审批快照：changes 1、approved 13；已通过与待审图片均纳入。
- 逐图清单与原路径：[coverage-AD01.json](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/coverage-AD01.json)；输入索引：[AD01.json](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/AD01.json)。
- 实际方法：联系表14张记录、另开整图1张记录、原分辨率crop复核1张记录（有交集）。先按EXIF旋转至正确阅读方向；A-oriented仅方向归一，A-crops不重采样。联系表只用于整体初筛，具体可见问题均有整图/原像素crop。
- PNG像素不直接当pt。源码尺寸为逻辑pt；没有运行App、构建、测试、模拟器、Figma或触摸验证。文件名中的“拖动/返回/自动/时间”不是本轮动态证据。

## 采用的标准与适用矩阵

[CURRENT.md](/Users/song/projects/13.billiard_trainer/tasks/daily-adaptive/CURRENT.md)与[CORE-TEMPLATE-C56.md](/Users/song/projects/13.billiard_trainer/tasks/table-page-adaptation/CORE-TEMPLATE-C56.md)决定现行组件版本；[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md)、[基础布局与自适应标准.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/基础布局与自适应标准.md)与[每日清台完整标准与跨页面复用分析.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md) §5–6/10提供推广边界。[提示与弹窗规范.md](/Users/song/projects/13.billiard_trainer/docs/design/feedback/提示与弹窗规范.md)按后续C38/B6覆盖旧居中规则。

动作常态应使用中性黑24%轻底/白细边，按下浅绿；不是所有背景绝对透明。普通ⓘ提示无底无边，规则说明顶部、动作独立桌心；主动重开/换玩法确认依DC12/C43保留紧凑磨砂卡。教学常驻读数不当作定时Toast删除。场景深色HUD与普通设置sheet分开判断。

|域|适用性与本页结论|
|---|---|
|标题|适用；现有“角度/瞄准”与右侧“与”的奇数结构；单行优先为新增容量要求。|
|安全区/窗口|适用；手机、SE、iPad横竖未見顶栏截断；iPad系统栏存在时模板只留FPS/静止。|
|球库|保留教学编辑差异；单排球库，不套每日合法球组。|
|仪表/教学读数|保留差异；切角、重合图、d/R、横移、偏移是常驻教学内容，不删除为Toast。|
|动作/选中禁用|不适用独立击球；本页拖球教学，没有必要增加每日出杆按钮。|
|相机/临时俯视|适用；四相机态与临时俯视可见，3D局部近景不要求整桌。|
|菜单/展开面板|适用；设置有显示/视图/网格；无打点能力，无需透明度入口。|
|ⓘ提示/决策/结果|证据不足；常驻读数不是提示；底部教学banner静态路径未在本图册呈现。|
|深浅色|保留场景深色HUD；普通阅读/系统sheet不在本页图中。|
|跨状态行为|静态跨状态可比；拖球前后图不等于证明连续更新/恢复无损。|
|桌体/几何|适用；角弧局部拥挤见S01；不改物理球径/角度值。|
|可访问性/容量|证据不足；没有最大字号、实际拖球/袋口热区或VoiceOver实测。|

## 问题与待核事项

### AD01-S01 · 角度弧靠近目标球，外移是合理新增视觉调整

- 分类：**用户新增要求**；P2。影响呈现一致性、可读性或核验完整性；无已证实的崩溃/不可操作路径，不升P1。
- 实际现状：原像素局部可见绿色短弧与黑8球外缘相邻，假想球、两条延长线和28°读数集中于同一局部；未看到文字被裁或角度计算错误。
- 标准：[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md) DC14/15/28；最新AD01-01意见
- 源码（静态路径）：[AngleSceneView.swift:2242](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/AngleSceneView.swift:2242) 2D覆盖层arcRadius=22；[AngleTrainingScene.swift:2631](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Scene/AngleTrainingScene.swift:2631) 3D自适应弧为4.5r
- 建议与范围：按2D与临时俯视屏幕投影分别增加视觉间距，并复核小角度、近球、SE与iPad；保持弧心/夹角/物理计算不变。 影响：AD01显示层；共用角弧消费者需做同球形对照，不能只改3D世界半径。
- 证据：[AD01-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/AD01/r03/final-r2/phone/ad01-2d-874.png)。对应实际观察crop/整图见coverage。
- 边界：支持用户方向；没有未经测量指定新的半径或把22pt当PNG像素。

### AD01-G01 · 覆盖缺口

**证据缺口；P2为补证优先级，不计已确认产品缺陷。** 本组无拖动中、首次可拖提示、未选袋、不可行提示显态。AngleDynamicView.swift:21明确称其为常驻教学状态，:74–100仍构造底部btHudGlass；其中“拖动中/点击袋口”需按DC19逐语义核定，无底/顶部方向不能因“常驻”自动豁免，也不能统一改为定时消失Toast。还缺窄窗、降低透明度、最大字号和持续拖动证据。

依据：[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md) DC21–26、[每日清台完整标准与跨页面复用分析.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md) §3/5.3/5.4。当前证据范围就是下列逐图原路径；需补对应状态/过程或实际窗口测量，不能根据本报告宣布已验收。当前相关静态路径：[AngleDynamicView.swift:21](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/AngleDynamicView.swift:21)；[AngleDynamicView.swift:74](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/AngleDynamicView.swift:74)。

## 用户意见逐条回应

**AD01-01 原话：**

> 角度标注的圆弧的位置稍微向外移动些吧，现在贴的有些太近了

同意外移方向。原像素能确认视觉相近，但没有遮挡到读数或算角错误；2D用22pt屏幕弧、3D用世界半径，需分别校准，不能只调一个全局常量。见S01。

## 非用户意见图的独立发现与保留项

独立检查了全部已通过3D/临时俯视/iPad图，未把上方系统状态栏与模板仅“静止”误报成缺时间电量。AD01-08/09来自其他批次，不能以其标题/几何合格推导当前源码所有瞬态已验。

## 逐图观察记录

|ID/原图|状态说明|实际方法|结论/问题|
|---|---|---|
|[AD01-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/AD01/r03/final-r2/phone/ad01-2d-874.png)|新标题 · 2D|contact-sheet, original, crop|教学读数、单排球库、桌面主体及对应相机状态已查；未见新增静态遮挡。 关联：AD01-S01|
|[AD01-02](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/AD01/r03/final-r2/phone/ad01-3d-874.png)|沿杆观察 · 首次进入 3D|contact-sheet|教学读数、单排球库、桌面主体及对应相机状态已查；未见新增静态遮挡。|
|[AD01-03](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/AD01/r03/final-r2/phone/ad01-first-person-874.png)|第一人称瞄准|contact-sheet|教学读数、单排球库、桌面主体及对应相机状态已查；未见新增静态遮挡。|
|[AD01-04](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/AD01/r03/final-r2/phone/ad01-temporary-topdown-874.png)|临时俯视|contact-sheet|教学读数、单排球库、桌面主体及对应相机状态已查；未见新增静态遮挡。|
|[AD01-05](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/AD01/r03/final-r2/phone/ad01-overview-874.png)|全局观察|contact-sheet|教学读数、单排球库、桌面主体及对应相机状态已查；未见新增静态遮挡。|
|[AD01-06](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/AD01/r03/final-r2/phone/ad01-dragged-874.png)|回到 2D 后实际拖球|contact-sheet|教学读数、单排球库、桌面主体及对应相机状态已查；未见新增静态遮挡。|
|[AD01-07](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/AD01/r03/final-r2/phone-dark/ad01-settings-dark-874.png)|设置 · 深色系统|contact-sheet|教学读数、单排球库、桌面主体及对应相机状态已查；未见新增静态遮挡。|
|[AD01-08](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08a/r03/final/ad01/ad01-temporary-topdown-874.png)|角度与瞄准 · 同构建临时俯视对照|contact-sheet|教学读数、单排球库、桌面主体及对应相机状态已查；未见新增静态遮挡。|
|[AD01-09](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/angles/2D-reference-angle-dynamic.png)|angles · 2D-reference-angle-dynamic|contact-sheet|教学读数、单排球库、桌面主体及对应相机状态已查；未见新增静态遮挡。|
|[AD01-10](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/AD01/r03/final-r2/se/ad01-3d-667.png)|SE · 沿杆观察|contact-sheet|教学读数、单排球库、桌面主体及对应相机状态已查；未见新增静态遮挡。|
|[AD01-11](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/AD01/r03/final-r2/se/ad01-temporary-topdown-667.png)|SE · 临时俯视|contact-sheet|教学读数、单排球库、桌面主体及对应相机状态已查；未见新增静态遮挡。|
|[AD01-12](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/AD01/r03/final-r2/ipad/ad01-portrait-3d-834.png)|iPad 竖屏 · 沿杆观察|contact-sheet|教学读数、单排球库、桌面主体及对应相机状态已查；未见新增静态遮挡。|
|[AD01-13](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/AD01/r03/final-r2/ipad/ad01-portrait-2d-834.png)|iPad 竖屏 · 2D|contact-sheet|教学读数、单排球库、桌面主体及对应相机状态已查；未见新增静态遮挡。|
|[AD01-14](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/AD01/r03/final-r2/ipad/ad01-first-person-1210.png)|iPad 横屏 · 第一人称|contact-sheet|教学读数、单排球库、桌面主体及对应相机状态已查；未见新增静态遮挡。|

## 交付边界

本轮仅审阅并记录，没有修改App、原图、用户审批、共享进度或返工日志。源码与截图可能来自不同批次：源码结论标为静态路径，截图只证明该帧。后续修复应按功能页补齐对照，触摸、时序、相机手感、真机性能分别验收。
