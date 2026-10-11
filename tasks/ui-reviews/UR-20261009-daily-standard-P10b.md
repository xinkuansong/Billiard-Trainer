# P10b · 3D瞄准点 · 每日核心模板逐图复审

日期：2026-10-09。审阅者：GPT-6-astra / astra_teaching。只读App；本报告不改变用户审批。

29张全部复审。方向尺可见宽度44pt、外壳组合未继承每日32pt内尺，是“显得压扁”的有证据原因；尺子本身固定行程，没有题目信息挤短的代码证据。另确认常绿提交和“即将验证”混入左读数，两种固定模式均受影响。

## 范围与方法

- 已目视 29/29 张，未看0张；设备记录：phone 9、se 9、ipad 11。
- 原审批快照：changes 1、approved 28；已通过与待审图片均纳入。
- 逐图清单与原路径：[coverage-P10b.json](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/coverage-P10b.json)；输入索引：[P10b.json](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/P10b.json)。
- 实际方法：联系表29张记录、另开整图0张记录、原分辨率crop复核3张记录（有交集）。先按EXIF旋转至正确阅读方向；A-oriented仅方向归一，A-crops不重采样。联系表只用于整体初筛，具体可见问题均有整图/原像素crop。
- PNG像素不直接当pt。源码尺寸为逻辑pt；没有运行App、构建、测试、模拟器、Figma或触摸验证。文件名中的“拖动/返回/自动/时间”不是本轮动态证据。

## 采用的标准与适用矩阵

[CURRENT.md](/Users/song/projects/13.billiard_trainer/tasks/daily-adaptive/CURRENT.md)与[CORE-TEMPLATE-C56.md](/Users/song/projects/13.billiard_trainer/tasks/table-page-adaptation/CORE-TEMPLATE-C56.md)决定现行组件版本；[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md)、[基础布局与自适应标准.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/基础布局与自适应标准.md)与[每日清台完整标准与跨页面复用分析.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md) §5–6/10提供推广边界。[提示与弹窗规范.md](/Users/song/projects/13.billiard_trainer/docs/design/feedback/提示与弹窗规范.md)按后续C38/B6覆盖旧居中规则。

动作常态应使用中性黑24%轻底/白细边，按下浅绿；不是所有背景绝对透明。普通ⓘ提示无底无边，规则说明顶部、动作独立桌心；主动重开/换玩法确认依DC12/C43保留紧凑磨砂卡。教学常驻读数不当作定时Toast删除。场景深色HUD与普通设置sheet分开判断。

|域|适用性与本页结论|
|---|---|
|标题|适用；短标题单行可读，不新增模式切换标题。|
|安全区/窗口|适用；手机/SE/iPad横竖均有图，系统状态去重可见；窄窗无图。|
|球库|保留题目业务差异；15槽只是题目状态/复用顶栏，不授予摆球编辑。|
|仪表/教学读数|既有偏差；方向尺内宽44，未传32及每日组合外壳；题目堆叠改变组内位置，见S01。|
|动作/选中禁用|既有偏差；提交常绿且plain，见S02；验证中不出现提交属阶段约束。|
|相机/临时俯视|适用；四相机与临时俯视有图；无杆速栏时不强求对齐不存在的仪表。|
|菜单/展开面板|适用；显示/网格/特写共用菜单，无打点能力不需要透明度入口。|
|ⓘ提示/决策/结果|既有偏差；短暂“即将验证”无ⓘ、混在左栏，见S03；误差/偏厚薄继续常驻。|
|深浅色|保留场景深色HUD；菜单同属场景；没有普通设置sheet主题故障证据。|
|跨状态行为|截图可比调整/结果/下一题/返回；不证明1.5秒延迟、真实击球停稳、计分或恢复正确。|
|桌体/几何|适用；2D完整桌框、3D本杆；临时2D含原场景背景不等于重复建台业务。|
|可访问性/容量|证据不足；未做VoiceOver、真实热区、动态字号、低容量及手感测试。|

## 问题与待核事项

### P10b-S01 · 方向尺宽度与外壳未继承每日模板；不是被题目信息压短

- 分类：**既有标准偏差**；P2。影响呈现一致性、可读性或核验完整性；无已证实的崩溃/不可操作路径，不升P1。
- 实际现状：原像素可见方向尺宽、直筒外形，下方方向标签单独黑底；与P01原像素双层窄尺有明显差别。题目/平均误差在尺上，整组对桌心，尺因此处于较低位置。
- 标准：[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md) DC07/08；[基础布局与自适应标准.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/基础布局与自适应标准.md) BL双尺可见32与行程144/120；[每日清台完整标准与跨页面复用分析.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md) §5.2
- 源码（静态路径）：[AimPointSceneTrainingView.swift:681](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/AimPointSceneTrainingView.swift:681)固定frame(width:44,height:f.rulerLength+24)，未传visibleWidth；[BTAimWheel.swift:31](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Components/BTAimWheel.swift:31)默认nil；:55扣标签24；:82取geo宽；[FreePlayView.swift:1886](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PositionPlay/Views/FreePlayView.swift:1886)每日传32、外壳另组装
- 建议与范围：复用每日32pt有效内尺、44pt外框/命中与组合标签外壳。题目/误差应有独立信息锚点或明确分组，不通过扩大尺长掩盖宽度差异。 影响：P10a/b手机/SE/iPad各状态。
- 证据：[P10b-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/phone/point-3D-adjusted.png)。对应实际观察crop/整图见coverage。
- 边界：f.rulerLength固定，组件再扣24后有效行程仍是f.rulerLength（144/容量120）。题目只参与父VStack总高及位置；没有证据证明压缩了尺子或应删题号/误差。

### P10b-S02 · 提交按钮常态实绿且没有共享按下样式

- 分类：**既有标准偏差**；P2。影响呈现一致性、可读性或核验完整性；无已证实的崩溃/不可操作路径，不升P1。
- 实际现状：原像素提交为浅绿实底深字圆形；与每日相邻HUD常态中性轻底不同。非确认卡、非选中开关，不能用常绿选中态解释。
- 标准：[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md) DC09/12；[HUDStyle.swift:133](/Users/song/projects/13.billiard_trainer/QiuJi/Core/DesignSystem/HUDStyle.swift:133)共享按下样式
- 源码（静态路径）：[AimPointSceneTrainingView.swift:695](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/AimPointSceneTrainingView.swift:695)提交52×52，直接HUDStyle.accent，.buttonStyle(.plain)
- 建议与范围：继承常态中性轻底/细边和按下浅绿反馈；保留提交、可提交判定及验证阶段禁用，不扩大为改评分/击球逻辑。 影响：P10a/b的aiming可提交状态。
- 证据：[P10b-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/phone/point-3D-adjusted.png)。对应实际观察crop/整图见coverage。
- 边界：52pt尺寸是当前业务实现；本项证据主要为材质/反馈，不把每日60pt无条件强套所有测验动作。

### P10b-S03 · 短暂验证阶段信息与常驻误差读数混放

- 分类：**既有标准偏差**；P2。影响呈现一致性、可读性或核验完整性；无已证实的崩溃/不可操作路径，不升P1。
- 实际现状：原像素结果左栏依次为误差、数值、偏厚、“即将验证”，没有ⓘ，没有顶部独立信息位；本图属于验证前状态，不是完整停稳后结果。
- 标准：[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md) DC19及C38/B6信息分层；[B6.md](/Users/song/projects/13.billiard_trainer/tasks/daily-adaptive/B6.md)说明顶部/动作桌心
- 源码（静态路径）：[AimPointSceneTrainingView.swift:788](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/AimPointSceneTrainingView.swift:788)questionInformation :795把验证中/即将验证直接写入误差VStack；[FreePlayView.swift:1825](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PositionPlay/Views/FreePlayView.swift:1825)dailyInformation为info.circle无底参考
- 建议与范围：仅把“即将验证/验证中”作为阶段信息送到统一顶部ⓘ无底位置，保留必要显示时长与阶段生命周期；误差数值/偏厚薄继续可读。不要变成系统alert或加彩色卡底。 影响：P10a/b结果预览与击球验证阶段。
- 证据：[P10b-05](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/phone/point-3D-result.png)。对应实际观察crop/整图见coverage。
- 边界：P10a用户意见支持此调整；P10b即使未被指出，同源状态已从已通过图独立发现。常驻分数不是Toast，不机械移动或限时消失。

### P10b-G01 · 覆盖缺口

**证据缺口；P2为补证优先级，不计已确认产品缺陷。** 缺普通信息改版显态、验证中与实际停稳完整序列、20题完成/限额、重复提交/离页恢复、窄窗、最大字号、按下态与Light/Dark环境配对。当前截图文件名“next/return”不证明自动跳题、保分或相机恢复的过程；本轮没有这些动态复验。

依据：[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md) DC21–26、[每日清台完整标准与跨页面复用分析.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md) §3/5.3/5.4。当前证据范围就是下列逐图原路径；需补对应状态/过程或实际窗口测量，不能根据本报告宣布已验收。当前相关静态路径：[AimPointSceneTrainingView.swift:788](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/AimPointSceneTrainingView.swift:788)。

## 用户意见逐条回应

**P10b-01 原话：**

> 瞄准条的问题同2D瞄准点

同意2D/3D同源问题。确认44pt可见宽度与每日32pt不同；固定frame与扣24标签的路径不支持“题目把尺压短”。题目堆叠会移动尺的位置，样式与位置应分开处理。见S01；另独立发现S02/S03。

## 非用户意见图的独立发现与保留项

全部已通过SE/iPad、菜单、结果、临时俯视/返回图均复审。独立把常绿提交及“即将验证”同源问题扩到3D；不是只回应用户提到的方向尺。 更多菜单显示前置、网格和特写能力合理；固定模式不增加自由2D/3D切换。

## 逐图观察记录

|ID/原图|状态说明|实际方法|结论/问题|
|---|---|---|
|[P10b-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/phone/point-3D-adjusted.png)|phone · point-3D-adjusted|contact-sheet, crop|题目/平均误差与方向尺、提交可见；方向尺样式和常绿提交见S01/S02。 关联：P10b-S01, P10b-S02|
|[P10b-02](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/phone/point-3D-aiming.png)|phone · point-3D-aiming|contact-sheet|题目/平均误差与方向尺、提交可见；方向尺样式和常绿提交见S01/S02。|
|[P10b-03](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/phone/point-3D-firstPerson.png)|phone · point-3D-firstPerson|contact-sheet|题目/平均误差与方向尺、提交可见；方向尺样式和常绿提交见S01/S02。|
|[P10b-04](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/phone/point-3D-next.png)|phone · point-3D-next|contact-sheet|题目/平均误差与方向尺、提交可见；方向尺样式和常绿提交见S01/S02。|
|[P10b-05](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/phone/point-3D-result.png)|phone · point-3D-result|contact-sheet, crop|结果前预览可见误差/偏厚薄/即将验证；内尺样式差异和短暂状态混入读数见S01/S03。 关联：P10b-S03|
|[P10b-06](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/phone/point-3D-settings.png)|phone · point-3D-settings|contact-sheet|更多显示组、网格与特写可读；固定模式无视图/打点入口属合理差异。|
|[P10b-07](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/phone/point-3D-temporary-return.png)|phone · point-3D-temporary-return|contact-sheet|临时俯视或返回静态画面主体可见；保留状态不等于动态恢复已验，方向尺样式见S01。|
|[P10b-08](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/phone/point-3D-temporary.png)|phone · point-3D-temporary|contact-sheet|临时俯视或返回静态画面主体可见；保留状态不等于动态恢复已验，方向尺样式见S01。|
|[P10b-09](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/phone/point-3D-thirdPerson.png)|phone · point-3D-thirdPerson|contact-sheet|题目/平均误差与方向尺、提交可见；方向尺样式和常绿提交见S01/S02。|
|[P10b-10](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/se/point-3D-adjusted.png)|se · point-3D-adjusted|contact-sheet|题目/平均误差与方向尺、提交可见；方向尺样式和常绿提交见S01/S02。|
|[P10b-11](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/se/point-3D-aiming.png)|se · point-3D-aiming|contact-sheet|题目/平均误差与方向尺、提交可见；方向尺样式和常绿提交见S01/S02。|
|[P10b-12](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/se/point-3D-firstPerson.png)|se · point-3D-firstPerson|contact-sheet|题目/平均误差与方向尺、提交可见；方向尺样式和常绿提交见S01/S02。|
|[P10b-13](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/se/point-3D-next.png)|se · point-3D-next|contact-sheet|题目/平均误差与方向尺、提交可见；方向尺样式和常绿提交见S01/S02。|
|[P10b-14](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/se/point-3D-result.png)|se · point-3D-result|contact-sheet, crop|结果前预览可见误差/偏厚薄/即将验证；内尺样式差异和短暂状态混入读数见S01/S03。|
|[P10b-15](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/se/point-3D-settings.png)|se · point-3D-settings|contact-sheet|更多显示组、网格与特写可读；固定模式无视图/打点入口属合理差异。|
|[P10b-16](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/se/point-3D-temporary-return.png)|se · point-3D-temporary-return|contact-sheet|临时俯视或返回静态画面主体可见；保留状态不等于动态恢复已验，方向尺样式见S01。|
|[P10b-17](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/se/point-3D-temporary.png)|se · point-3D-temporary|contact-sheet|临时俯视或返回静态画面主体可见；保留状态不等于动态恢复已验，方向尺样式见S01。|
|[P10b-18](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/se/point-3D-thirdPerson.png)|se · point-3D-thirdPerson|contact-sheet|题目/平均误差与方向尺、提交可见；方向尺样式和常绿提交见S01/S02。|
|[P10b-19](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/ipad/point-3D-adjusted.png)|ipad · point-3D-adjusted|contact-sheet|题目/平均误差与方向尺、提交可见；方向尺样式和常绿提交见S01/S02。|
|[P10b-20](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/ipad/point-3D-aiming.png)|ipad · point-3D-aiming|contact-sheet|题目/平均误差与方向尺、提交可见；方向尺样式和常绿提交见S01/S02。|
|[P10b-21](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/ipad/point-3D-firstPerson.png)|ipad · point-3D-firstPerson|contact-sheet|题目/平均误差与方向尺、提交可见；方向尺样式和常绿提交见S01/S02。|
|[P10b-22](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/ipad/point-3D-landscape-return.png)|ipad · point-3D-landscape-return|contact-sheet|题目/平均误差与方向尺、提交可见；方向尺样式和常绿提交见S01/S02。|
|[P10b-23](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/ipad/point-3D-next.png)|ipad · point-3D-next|contact-sheet|题目/平均误差与方向尺、提交可见；方向尺样式和常绿提交见S01/S02。|
|[P10b-24](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/ipad/point-3D-portrait.png)|ipad · point-3D-portrait|contact-sheet|题目/平均误差与方向尺、提交可见；方向尺样式和常绿提交见S01/S02。|
|[P10b-25](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/ipad/point-3D-result.png)|ipad · point-3D-result|contact-sheet|结果前预览可见误差/偏厚薄/即将验证；内尺样式差异和短暂状态混入读数见S01/S03。|
|[P10b-26](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/ipad/point-3D-settings.png)|ipad · point-3D-settings|contact-sheet|更多显示组、网格与特写可读；固定模式无视图/打点入口属合理差异。|
|[P10b-27](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/ipad/point-3D-temporary-return.png)|ipad · point-3D-temporary-return|contact-sheet|临时俯视或返回静态画面主体可见；保留状态不等于动态恢复已验，方向尺样式见S01。|
|[P10b-28](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/ipad/point-3D-temporary.png)|ipad · point-3D-temporary|contact-sheet|临时俯视或返回静态画面主体可见；保留状态不等于动态恢复已验，方向尺样式见S01。|
|[P10b-29](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P10/r01/final/ipad/point-3D-thirdPerson.png)|ipad · point-3D-thirdPerson|contact-sheet|题目/平均误差与方向尺、提交可见；方向尺样式和常绿提交见S01/S02。|

## 交付边界

本轮仅审阅并记录，没有修改App、原图、用户审批、共享进度或返工日志。源码与截图可能来自不同批次：源码结论标为静态路径，截图只证明该帧。后续修复应按功能页补齐对照，触摸、时序、相机手感、真机性能分别验收。
