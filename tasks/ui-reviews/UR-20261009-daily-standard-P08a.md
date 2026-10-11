# P08a · 分离角图谱 · 每日核心模板逐图复审

日期：2026-10-09。审阅者：GPT-6-astra / astra_teaching。只读App；本报告不改变用户审批。

11张全部复审，没有足够证据确认新增截图缺陷。已通过图片仍发现八档按钮命中高度的静态风险，需用实际命中框验证；教学提示显态与更多菜单缺图。

## 范围与方法

- 已目视 11/11 张，未看0张；设备记录：phone 5、se 2、ipad 4。
- 原审批快照：approved 11；已通过与待审图片均纳入。
- 逐图清单与原路径：[coverage-P08a.json](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/coverage-P08a.json)；输入索引：[P08a.json](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/P08a.json)。
- 实际方法：联系表11张记录、另开整图0张记录、原分辨率crop复核1张记录（有交集）。先按EXIF旋转至正确阅读方向；A-oriented仅方向归一，A-crops不重采样。联系表只用于整体初筛，具体可见问题均有整图/原像素crop。
- PNG像素不直接当pt。源码尺寸为逻辑pt；没有运行App、构建、测试、模拟器、Figma或触摸验证。文件名中的“拖动/返回/自动/时间”不是本轮动态证据。

## 采用的标准与适用矩阵

[CURRENT.md](/Users/song/projects/13.billiard_trainer/tasks/daily-adaptive/CURRENT.md)与[CORE-TEMPLATE-C56.md](/Users/song/projects/13.billiard_trainer/tasks/table-page-adaptation/CORE-TEMPLATE-C56.md)决定现行组件版本；[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md)、[基础布局与自适应标准.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/基础布局与自适应标准.md)与[每日清台完整标准与跨页面复用分析.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md) §5–6/10提供推广边界。[提示与弹窗规范.md](/Users/song/projects/13.billiard_trainer/docs/design/feedback/提示与弹窗规范.md)按后续C38/B6覆盖旧居中规则。

动作常态应使用中性黑24%轻底/白细边，按下浅绿；不是所有背景绝对透明。普通ⓘ提示无底无边，规则说明顶部、动作独立桌心；主动重开/换玩法确认依DC12/C43保留紧凑磨砂卡。教学常驻读数不当作定时Toast删除。场景深色HUD与普通设置sheet分开判断。

|域|适用性与本页结论|
|---|---|
|标题|适用；“分离/图谱”加右侧“角”保留奇数结构；新单行优先待容量测量。|
|安全区/窗口|适用；手机/SE/iPad横竖可见控件未越界；没有窄窗图。|
|球库|保留编辑业务差异；单排球库，不套每日球组。|
|仪表/教学读数|保留差异；左八档与切角，右杆速；没有方向尺需求，不机械补成双尺。|
|动作/选中禁用|保留差异；八档开关属选中状态，彩色杆法点不是主按钮常绿问题；不增加出杆按钮。|
|相机/临时俯视|适用；3D及临时俯视带线与角标；动态恢复待实测。|
|菜单/展开面板|证据不足；本组没有更多菜单截图；无独立打点盘，透明度不适用。|
|ⓘ提示/决策/结果|证据不足；只看到常驻角度和8/8、1/8；状态提示底部玻璃路径缺显态。|
|深浅色|保留场景深色HUD；无系统主题配对/普通sheet。|
|跨状态行为|8/8与1/8静态结果可见；不证明点击的命中准确率和连续计算。|
|桌体/几何|适用；2D六袋与轨迹图谱可读；教学轨迹事件切片保留。|
|可访问性/容量|需确认假设S01；八档紧排按钮的代码高度小于44，真实热区未测。|

## 问题与待核事项

### P08a-S01 · 八档杆法开关的实际命中高度需要专项核实

- 分类：**需确认假设**；P2。影响呈现一致性、可读性或核验完整性；无已证实的崩溃/不可操作路径，不升P1。
- 实际现状：原像素左栏八个圆盘紧密纵排，最下方为8/8；源码每项行高最大32，视觉圆盘最大28。截图无法证明真实可点范围。
- 标准：[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md) DC06/23；[每日清台完整标准与跨页面复用分析.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md) §5.4区分可见与命中
- 源码（静态路径）：[SeparationAngleAtlasView.swift:64](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/SeparationAngleAtlasView.swift:64) rowHeight上限32；:103 label frame为44×rowHeight
- 建议与范围：补AX框与真实相邻切换命中验证；若不足，按容量调整分布或提供明确替代操作，不能给相邻项叠44热区。 影响：P08a八档，尤其SE；不是说按钮已不可点。
- 证据：[P08a-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08a/r03/final/phone/p08a-2d-874.png)。对应实际观察crop/整图见coverage。
- 边界：这是已通过图以外的独立风险发现；本轮没有触摸或AX采样，不计已确认产品缺陷。

### P08a-G01 · 覆盖缺口

**证据缺口；P2为补证优先级，不计已确认产品缺陷。** 缺更多菜单、普通ⓘ提示与无可行球形等教学状态、浅深主题配对、窄窗/最大字号。SeparationAngleAtlasView.swift:27–34将statusText放底部btHudGlass且无图标，当前图册未见显态；后续按文案区分引导/错误/常驻教学结论，再核DC19无底顶部，不直接把所有教学状态定时消失。

依据：[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md) DC21–26、[每日清台完整标准与跨页面复用分析.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md) §3/5.3/5.4。当前证据范围就是下列逐图原路径；需补对应状态/过程或实际窗口测量，不能根据本报告宣布已验收。当前相关静态路径：[SeparationAngleAtlasView.swift:27](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/SeparationAngleAtlasView.swift:27)。

## 用户意见逐条回应

本页没有非空用户意见。仍按全域检查全部图片。

## 非用户意见图的独立发现与保留项

11张用户全通过仍检查了SE八档、只保留一档、iPad横竖、临时俯视的角标与线，记录S01而非直接沿用“通过”。图谱展示八种结果的业务差异合理，无独立击球/方向尺不算遗漏。

## 逐图观察记录

|ID/原图|状态说明|实际方法|结论/问题|
|---|---|---|
|[P08a-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08a/r03/final/phone/p08a-2d-874.png)|手机 · 标题、切角、八档与数量|contact-sheet, crop|切角、八档、剩余档数、杆速与对应桌面/临时俯视标注已检查，未见新增静态遮挡。 关联：P08a-S01|
|[P08a-02](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08a/r03/final/phone/p08a-3d-874.png)|3D · 共用每日相机|contact-sheet|切角、八档、剩余档数、杆速与对应桌面/临时俯视标注已检查，未见新增静态遮挡。|
|[P08a-03](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08a/r03/final/phone/p08a-temporary-topdown-874.png)|临时俯视 · 线条与角度|contact-sheet|切角、八档、剩余档数、杆速与对应桌面/临时俯视标注已检查，未见新增静态遮挡。|
|[P08a-04](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08a/r03/final/phone/p08a-dragged-874.png)|拖球后 · 角度与轨迹更新|contact-sheet|切角、八档、剩余档数、杆速与对应桌面/临时俯视标注已检查，未见新增静态遮挡。|
|[P08a-05](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08a/r03/final/phone/p08a-last-track-874.png)|保留一档 · 数量在列表下方|contact-sheet|切角、八档、剩余档数、杆速与对应桌面/临时俯视标注已检查，未见新增静态遮挡。|
|[P08a-06](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08a/r03/final/se/p08a-temporary-topdown-667.png)|SE · 临时俯视角标|contact-sheet|切角、八档、剩余档数、杆速与对应桌面/临时俯视标注已检查，未见新增静态遮挡。|
|[P08a-07](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08a/r03/final/se/p08a-2d-667.png)|SE · 八档全显，无滚动|contact-sheet|切角、八档、剩余档数、杆速与对应桌面/临时俯视标注已检查，未见新增静态遮挡。|
|[P08a-08](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08a/r03/final/ipad/p08a-temporary-topdown-1210.png)|iPad · 临时俯视角标|contact-sheet|切角、八档、剩余档数、杆速与对应桌面/临时俯视标注已检查，未见新增静态遮挡。|
|[P08a-09](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08a/r03/final/ipad/p08a-2d-1210.png)|iPad 横屏 · 2D|contact-sheet|切角、八档、剩余档数、杆速与对应桌面/临时俯视标注已检查，未见新增静态遮挡。|
|[P08a-10](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08a/r03/final/ipad/p08a-portrait-2d-834.png)|iPad 竖屏 · 2D|contact-sheet|切角、八档、剩余档数、杆速与对应桌面/临时俯视标注已检查，未见新增静态遮挡。|
|[P08a-11](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08a/r03/final/ipad/p08a-portrait-3d-834.png)|iPad 竖屏 · 3D|contact-sheet|切角、八档、剩余档数、杆速与对应桌面/临时俯视标注已检查，未见新增静态遮挡。|

## 交付边界

本轮仅审阅并记录，没有修改App、原图、用户审批、共享进度或返工日志。源码与截图可能来自不同批次：源码结论标为静态路径，截图只证明该帧。后续修复应按功能页补齐对照，触摸、时序、相机手感、真机性能分别验收。
