# P11-2 · 瞄准修正 · 每日标准逐功能复审

审阅日期：2026-10-09；审阅者：GPT-6-astra（C组）；只审不改。

本页5条截图记录全部目视完成；联系表逐图初筛，提出视觉问题的图另用原图或原分辨率局部复核。清单见[coverage-P11-2.json](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/coverage-P11-2.json)。原图可能由不同历史轮次组合；当前源码只作静态路径支持，不冒充截图同期构建或实测。

## 范围与结论

设备/状态：手机 / 瞄准修正 / portrait-top；手机 / 瞄准修正 / portrait-figure；小屏 / 瞄准修正 / portrait-top；iPad / 瞄准修正 / portrait-top；iPad / 瞄准修正 / landscape-figure。

发现2项：P11-2-S01 P2 必要操作说明使用过淡的三级文字；P11-2-S02 P2 滚动后的导航标题与绿色教学图形成低对比叠放

本页已通过的截图同样纳入复审。未进行新的触摸、动画、性能、物理准确性或真机体验验证。

## 标准来源与适用性

依据[CURRENT.md](/Users/song/projects/13.billiard_trainer/tasks/daily-adaptive/CURRENT.md)、[CORE-TEMPLATE-C56.md](/Users/song/projects/13.billiard_trainer/tasks/table-page-adaptation/CORE-TEMPLATE-C56.md)、[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md)、[基础布局与自适应标准.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/基础布局与自适应标准.md)、[每日清台完整标准与跨页面复用分析.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md)及[提示与弹窗规范.md](/Users/song/projects/13.billiard_trainer/docs/design/feedback/提示与弹窗规范.md)。提示采用后半修订及C38/B6：说明顶部、动作桌心；不恢复旧“全部居中”或整块面板。字号以当前Typography/token与页内规范为准。

| 领域 | 判定 | 本页适用说明 |
|---|---|---|
| 标题 | 适用 | 原生阅读导航，已查首屏/滚动态；低对比问题见本页发现。 |
| 安全区 | 适用 | 已看返回与标题可见；滚动图片可延展，交互区无新增明确裁切；触摸未验。 |
| 球库 | 不适用 | 阅读插图不是可自由摆球的15球库。 |
| 仪表 | 差异保留 | 切角/高低杆等教学控件按文章用途，非每日双尺。 |
| 动作 | 差异保留 | 返回、滑条、正文链接保留阅读语义；无击球60pt要求。 |
| 相机 | 不适用 | 正文2D插图不承诺四机位场景操作。 |
| 菜单 | 不适用 | 未呈现每日更多菜单；不因缺菜单判偏差。 |
| 提示 | 差异保留 | 说明、误区、公式与图例是必要教学内容，不改短暂无底板Toast。 |
| 主题 | 适用 | 组内有浅底手机/iPad与深底SE；不同内容/窗口不能替代同状态主题成对验收。 |
| 状态行为 | 证据不足 | 首屏/滚动/横屏截图已看；不证明滑条联动、后台恢复、VoiceOver与手势。 |
| 几何/投影 | 适用 | 插图球体和文字按原图核对；不把教学局部示意强套整桌2:1或六袋全景。 |

静态抽查仅用于解释适用性，不证明当前截图同期行为。[57-ui-reviewer.mdc](/Users/song/projects/13.billiard_trainer/.cursor/rules/57-ui-reviewer.mdc)为视觉检查规则；[Typography.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/DesignSystem/Typography.swift)以真实token为准。

阅读壳与文本语义：[LearnDocChrome.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/LearnDocChrome.swift:29)限制阅读宽度；其教学段落/卡片不是临时提示。[TheoryPageChrome.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Theory/TheoryPageChrome.swift:225)统一球理页导航壳。


## 问题与证据

### P11-2-S01 · P2 · 必要操作说明使用过淡的三级文字

- 分类：既有标准偏差。
- 可见现状/路径：原分辨率局部确认：切角/联动控件下的操作说明在浅底上接近背景，阅读需要明显辨认；该文字解释控制作用与边界，不能视为可忽略装饰。P11-1符号图例描述也有相同问题。
- 标准：57-ui-reviewer.mdc 的可读性/无障碍检查；基础布局标准§4.2要求正常文字、不整体缩字；此处是常驻教学说明，不适用DC19临时提示消失规则。
- 源码：[LearnControlStrip.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/LearnControlStrip.swift:119)；[Contents.json](/Users/song/projects/13.billiard_trainer/QiuJi/Resources/Assets.xcassets/btTextTertiary.colorset/Contents.json)（light/dark均30% alpha）。
- 证据：P11-2-01 [reading-2-portrait-top.png](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P11/r01/final/phone/reading-2-portrait-top.png)
- 建议：保留教学说明的常驻语义，提高对应说明token/局部颜色对比度；在同一内容的浅/深主题和普通/大字号复核。不要改成短暂Toast。
- 范围与边界：本页切角或联动参数说明；多个P11页共用LearnControlStrip，修改时需逐页回看。

### P11-2-S02 · P2 · 滚动后的导航标题与绿色教学图形成低对比叠放

- 分类：既有标准偏差。
- 可见现状/路径：导航区下方进入绿色球桌教学图时，绿色标题直接落在深绿图面上，标题识别明显弱于白色正文背景时。这里评的是当前截图上的对比度，不推定滚动机制失效。
- 标准：DC03标题可读及安全区；BL03顶栏可见主体协调；阅读页保留原生导航语义，不机械套15球顶栏。
- 源码：[AimingCorrectionView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/AimingCorrectionView.swift:31)；[TheoryPageChrome.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Theory/TheoryPageChrome.swift:229)（标题入口；最终导航材质根因尚未定位，不把入口当修复点）。
- 证据：P11-2-05 [reading-2-landscape-figure.png](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P11/r01/ipad-reboot-retest/reading-2-landscape-figure.png)
- 建议：让导航标题在图文滚动背景变化时保持稳定对比度，可用正确导航材质或自适应前景；保留返回与单行阅读标题。
- 范围与边界：本页滚动图文及iPad横屏所示状态；未测试动态过渡。

## 用户意见逐条回应

本manifest没有待回应的文字意见；approved/未审状态均已独立看图，不作为免检依据。

## 逐图覆盖

| 截图 | 实际观察方法 | 结论 |
|---|---|---|
| [P11-2-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P11/r01/final/phone/reading-2-portrait-top.png) · 手机 / 瞄准修正 / portrait-top | contact-sheet, crop | 已看本图图文层级、导航、说明与插图比例。原尺寸说明局部复核完成。 明确问题：P11-2-S01。 |
| [P11-2-02](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P11/r01/final/phone/reading-2-portrait-figure.png) · 手机 / 瞄准修正 / portrait-figure | contact-sheet, crop | 已看本图图文层级、导航、说明与插图比例。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P11-2-03](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P11/r01/final/se/reading-2-portrait-top.png) · 小屏 / 瞄准修正 / portrait-top | contact-sheet | 已看本图图文层级、导航、说明与插图比例。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P11-2-04](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P11/r01/ipad-reboot-retest/reading-2-portrait-top.png) · iPad / 瞄准修正 / portrait-top | contact-sheet | 已看本图图文层级、导航、说明与插图比例。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P11-2-05](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P11/r01/ipad-reboot-retest/reading-2-landscape-figure.png) · iPad / 瞄准修正 / landscape-figure | contact-sheet, original | 已看本图图文层级、导航、说明与插图比例。横向原图已仅旋转、无重采样查看。 明确问题：P11-2-S02。 |

## 证据缺口与后续验收

全篇所有滚动段落未逐段提供；截图中的静态滑条值不证明联动正确。除manifest明确的字号样本外，不扩称最大辅助字号通过。iPad横屏原图以旋转存储，已无重采样旋转查看，不误报成运行时方向错误。

本轮仅生成报告与覆盖清单，未修改App、原图、用户审批或共享任务状态。
