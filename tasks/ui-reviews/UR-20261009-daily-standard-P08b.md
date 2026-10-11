# P08b · 加塞吃库图谱 · 每日核心模板逐图复审

日期：2026-10-09。审阅者：GPT-6-astra / astra_teaching。只读App；本报告不改变用户审批。

14张全部复审。标题当前4+2断行不符合10-09新增均分规则；此外独立检查到八档命中高度风险以及高低杆盘未接透明度的适用性待定。后两项不冒充已确认旧标准缺陷。

## 范围与方法

- 已目视 14/14 张，未看0张；设备记录：phone 7、se 2、ipad 5。
- 原审批快照：changes 1、approved 13；已通过与待审图片均纳入。
- 逐图清单与原路径：[coverage-P08b.json](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/coverage-P08b.json)；输入索引：[P08b.json](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/P08b.json)。
- 实际方法：联系表14张记录、另开整图0张记录、原分辨率crop复核3张记录（有交集）。先按EXIF旋转至正确阅读方向；A-oriented仅方向归一，A-crops不重采样。联系表只用于整体初筛，具体可见问题均有整图/原像素crop。
- PNG像素不直接当pt。源码尺寸为逻辑pt；没有运行App、构建、测试、模拟器、Figma或触摸验证。文件名中的“拖动/返回/自动/时间”不是本轮动态证据。

## 采用的标准与适用矩阵

[CURRENT.md](/Users/song/projects/13.billiard_trainer/tasks/daily-adaptive/CURRENT.md)与[CORE-TEMPLATE-C56.md](/Users/song/projects/13.billiard_trainer/tasks/table-page-adaptation/CORE-TEMPLATE-C56.md)决定现行组件版本；[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md)、[基础布局与自适应标准.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/基础布局与自适应标准.md)与[每日清台完整标准与跨页面复用分析.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md) §5–6/10提供推广边界。[提示与弹窗规范.md](/Users/song/projects/13.billiard_trainer/docs/design/feedback/提示与弹窗规范.md)按后续C38/B6覆盖旧居中规则。

动作常态应使用中性黑24%轻底/白细边，按下浅绿；不是所有背景绝对透明。普通ⓘ提示无底无边，规则说明顶部、动作独立桌心；主动重开/换玩法确认依DC12/C43保留紧凑磨砂卡。教学常驻读数不当作定时Toast删除。场景深色HUD与普通设置sheet分开判断。

|域|适用性与本页结论|
|---|---|
|标题|新增要求；六字现为4+2，应先量单行，再按3+3，见S01。|
|安全区/窗口|适用；手机/SE/iPad横竖未见必要控件裁切；窄窗缺证。|
|球库|保留编辑业务差异；单排球库，临时2D不是完整2D编辑承诺。|
|仪表/教学读数|保留差异；切角/八档左右塞/数量/杆速，高低杆是另轴，不新增方向尺。|
|动作/选中禁用|保留差异；八档选择色与杆法角色色有语义；无每日整杆执行动作。|
|相机/临时俯视|适用；四相机键、临时俯视、3D打点均有图。|
|菜单/展开面板|适用；菜单显示前置；有高低杆盘但透明度未opt-in，见S03。|
|ⓘ提示/决策/结果|证据不足；底部statusText玻璃路径没有显态；教学说明已收菜单不算Toast。|
|深浅色|保留场景深色HUD；P08b-07浅色系统下的深色设置是场景菜单，不是普通sheet。|
|跨状态行为|8/8、1/8及高1%静态可见；不证明微调精度/关闭透传/连续轨迹。|
|桌体/几何|适用；完整2D与图谱线可读，白盘遮住局部桌面属模态覆盖。|
|可访问性/容量|需确认假设；紧排八档命中高度见S02，不能仅因用户通过认定达标。|

## 问题与待核事项

### P08b-S01 · 六字标题目前4+2分行

- 分类：**用户新增要求**；P2。影响呈现一致性、可读性或核验完整性；无已证实的崩溃/不可操作路径，不升P1。
- 实际现状：原像素标题第一行“加塞吃库”，第二行“图谱”，不是三字加三字。
- 标准：[REVIEWS.md:269](/Users/song/projects/13.billiard_trainer/tasks/table-page-adaptation/REVIEWS.md:269)10-09新增标题规则；[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md) DC03
- 源码（静态路径）：[CushionEnglishAtlasView.swift:13](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/CushionEnglishAtlasView.swift:13)硬编码“加塞吃库\n图谱”
- 建议与范围：量实际字体与可用标题区，能单行则单行；放不下时采用“加塞吃/库图谱”，保持统一字号与安全区，不用自动压缩字形代替规则。 影响：P08b全部设备；共享标题组件需统一处理奇偶字。
- 证据：[P08b-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08b/r01/final/phone/p08b-2d-874.png)。对应实际观察crop/整图见coverage。
- 边界：旧稿的固定换行不能倒推为违反当时未存在的均分规则。

### P08b-S02 · 八档左右塞按钮命中高度仍需验证

- 分类：**需确认假设**；P2。影响呈现一致性、可读性或核验完整性；无已证实的崩溃/不可操作路径，不升P1。
- 实际现状：原像素可见八档紧排；源码每项宽44、高最大32，圆盘最大28，尚无实际命中框证据。
- 标准：[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md) DC06/23；[每日清台完整标准与跨页面复用分析.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md) §5.4
- 源码（静态路径）：[CushionEnglishAtlasView.swift:72](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/CushionEnglishAtlasView.swift:72) rowHeight；:115 frame44×rowHeight
- 建议与范围：核AX与实点相邻档位，重点SE；需要时重排，不叠加互相覆盖的44热区。 影响：P08b八档；P08a同构风险。
- 证据：[P08b-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08b/r01/final/phone/p08b-2d-874.png)。对应实际观察crop/整图见coverage。
- 边界：不宣称不可操作；这是静态风险而不是触摸测试结果。

### P08b-S03 · 高低杆盘固定不透明，是否继承透明度需明确

- 分类：**需确认假设**；P2。影响呈现一致性、可读性或核验完整性；无已证实的崩溃/不可操作路径，不升P1。
- 实际现状：打点白盘不透明；菜单只有视图/网格/教学说明，没有透明度入口。盘面本身完整，底层仪表没有被删除。
- 标准：[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md) DC11；[每日清台完整标准与跨页面复用分析.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md) §4/6明确透明度偏好需逐页opt-in
- 源码（静态路径）：[BTTeachingTablePage.swift:196](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Components/BTTeachingTablePage.swift:196)透明度仅planning分支；:390非planning discOpacity=1
- 建议与范围：先明确本教学页是否继承每日白盘透明度；若适用，接同一白盘填充与菜单合同，保留只调高低杆的业务限制。 影响：P08b 2D/3D展开盘与SE/iPad。
- 证据：[P08b-03](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08b/r01/final/phone/p08b-spin-2d-874.png)；[P08b-07](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08b/r01/final/phone/p08b-settings-light-874.png)。对应实际观察crop/整图见coverage。
- 边界：规范要求先决定opt-in，当前没有独立确认记录，故不把缺入口直接判为旧标准偏差。

### P08b-G01 · 覆盖缺口

**证据缺口；P2为补证优先级，不计已确认产品缺陷。** 缺底部教学状态/不可行提示的真实显态、窄窗、完整Light/Dark配对、按下与触摸/微调连续过程。CushionEnglishAtlasView.swift:28–35仍为底部Text+btHudGlass；普通引导与常驻教学解释需逐文案分类，不能仅因使用共享HUD断言已符合ⓘ无底标准。

依据：[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md) DC21–26、[每日清台完整标准与跨页面复用分析.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md) §3/5.3/5.4。当前证据范围就是下列逐图原路径；需补对应状态/过程或实际窗口测量，不能根据本报告宣布已验收。当前相关静态路径：[CushionEnglishAtlasView.swift:28](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/CushionEnglishAtlasView.swift:28)。

## 用户意见逐条回应

**P08b-01 原话：**

> 加塞吃库图谱标题，感觉可以做成两行，是不是我们的标题换行规则有问题：1. 能一行的一行；2. 不能一行的，偶数用双行，两行文字数字相同，奇数用双行，中间的那个文字放到右侧，介于两个行的中间居中

同意。当前是4+2，六字放不下一行时应3+3；并将“先尝试单行、奇数中间字右置”作为新统一规则处理，不沿用此页手写换行。见S01。

## 非用户意见图的独立发现与保留项

用户只点标题；本轮仍检查了全部已通过盘面/菜单/SE/iPad图，独立记录命中高度与透明度适用性。四向中的左右控制缺席属于八档左右塞、另调高低杆的业务设计，不判为盘按钮缺失。

## 逐图观察记录

|ID/原图|状态说明|实际方法|结论/问题|
|---|---|---|
|[P08b-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08b/r01/final/phone/p08b-2d-874.png)|手机 · 切角与八档左右塞|contact-sheet, crop|切角、八档、数量、杆速和当前相机/打点状态已检查；标题新规则见S01，业务限制保留。 关联：P08b-S01, P08b-S02|
|[P08b-02](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08b/r01/final/phone/p08b-3d-874.png)|3D · 每日清台相机与四按钮|contact-sheet|切角、八档、数量、杆速和当前相机/打点状态已检查；标题新规则见S01，业务限制保留。|
|[P08b-03](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08b/r01/final/phone/p08b-spin-2d-874.png)|2D · 只选高低杆的大打点盘|contact-sheet, crop|切角、八档、数量、杆速和当前相机/打点状态已检查；标题新规则见S01，业务限制保留。 关联：P08b-S03|
|[P08b-04](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08b/r01/final/phone/p08b-spin-3d-874.png)|3D · 同一打点盘|contact-sheet|切角、八档、数量、杆速和当前相机/打点状态已检查；标题新规则见S01，业务限制保留。|
|[P08b-05](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08b/r01/final/phone/p08b-temporary-topdown-874.png)|临时俯视 · 进球线与角度|contact-sheet|切角、八档、数量、杆速和当前相机/打点状态已检查；标题新规则见S01，业务限制保留。|
|[P08b-06](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08b/r01/final/phone/p08b-last-track-874.png)|最后一档保留，数量在列表下方|contact-sheet|切角、八档、数量、杆速和当前相机/打点状态已检查；标题新规则见S01，业务限制保留。|
|[P08b-07](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08b/r01/final/phone/p08b-settings-light-874.png)|浅色系统 · 共用深色设置，教学说明收纳其中|contact-sheet, crop|切角、八档、数量、杆速和当前相机/打点状态已检查；标题新规则见S01，业务限制保留。 关联：P08b-S03|
|[P08b-08](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08b/r01/final/se/p08b-2d-667.png)|SE · 八档全显，无滚动|contact-sheet|切角、八档、数量、杆速和当前相机/打点状态已检查；标题新规则见S01，业务限制保留。|
|[P08b-09](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08b/r01/final/se/p08b-spin-2d-667.png)|SE · 高低杆盘|contact-sheet|切角、八档、数量、杆速和当前相机/打点状态已检查；标题新规则见S01，业务限制保留。|
|[P08b-10](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08b/r01/final/ipad/p08b-2d-1210.png)|iPad 横屏 · 2D|contact-sheet|切角、八档、数量、杆速和当前相机/打点状态已检查；标题新规则见S01，业务限制保留。|
|[P08b-11](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08b/r01/final/ipad/p08b-spin-3d-1210.png)|iPad · 3D高低杆盘|contact-sheet|切角、八档、数量、杆速和当前相机/打点状态已检查；标题新规则见S01，业务限制保留。|
|[P08b-12](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08b/r01/final/ipad/p08b-temporary-topdown-1210.png)|iPad · 临时俯视角标|contact-sheet|切角、八档、数量、杆速和当前相机/打点状态已检查；标题新规则见S01，业务限制保留。|
|[P08b-13](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08b/r01/final/ipad/p08b-portrait-2d-834.png)|iPad 竖屏 · 2D|contact-sheet|切角、八档、数量、杆速和当前相机/打点状态已检查；标题新规则见S01，业务限制保留。|
|[P08b-14](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P08b/r01/final/ipad/p08b-portrait-3d-834.png)|iPad 竖屏 · 3D|contact-sheet|切角、八档、数量、杆速和当前相机/打点状态已检查；标题新规则见S01，业务限制保留。|

## 交付边界

本轮仅审阅并记录，没有修改App、原图、用户审批、共享进度或返工日志。源码与截图可能来自不同批次：源码结论标为静态路径，截图只证明该帧。后续修复应按功能页补齐对照，触摸、时序、相机手感、真机性能分别验收。
