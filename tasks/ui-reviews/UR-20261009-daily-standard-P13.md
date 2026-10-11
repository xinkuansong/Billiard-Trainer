# P13 · 拍照建球形 · 每日标准逐功能复审

审阅日期：2026-10-09；审阅者：GPT-6-astra（C组）；只审不改。

本页10条截图记录全部目视完成；联系表逐图初筛，提出视觉问题的图另用原图或原分辨率局部复核。清单见[coverage-P13.json](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/coverage-P13.json)。原图可能由不同历史轮次组合；当前源码只作静态路径支持，不冒充截图同期构建或实测。

## 范围与结论

设备/状态：phone · extraction-confirm-portrait-return；phone · extraction-confirm；phone · extraction-to-composer；se · extraction-confirm-portrait-return；se · extraction-confirm；se · extraction-to-composer；ipad · extraction-confirm-landscape；ipad · extraction-confirm-portrait-return；ipad · extraction-confirm；ipad · extraction-to-composer。

发现0项：没有从现有截图确认新的视觉偏差；覆盖不足列在下文，不宣布完整验收通过。

本页已通过的截图同样纳入复审。未进行新的触摸、动画、性能、物理准确性或真机体验验证。

## 标准来源与适用性

依据[CURRENT.md](/Users/song/projects/13.billiard_trainer/tasks/daily-adaptive/CURRENT.md)、[CORE-TEMPLATE-C56.md](/Users/song/projects/13.billiard_trainer/tasks/table-page-adaptation/CORE-TEMPLATE-C56.md)、[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md)、[基础布局与自适应标准.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/基础布局与自适应标准.md)、[每日清台完整标准与跨页面复用分析.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md)及[提示与弹窗规范.md](/Users/song/projects/13.billiard_trainer/docs/design/feedback/提示与弹窗规范.md)。提示采用后半修订及C38/B6：说明顶部、动作桌心；不恢复旧“全部居中”或整块面板。字号以当前Typography/token与页内规范为准。

| 领域 | 判定 | 本页适用说明 |
|---|---|---|
| 标题 | 适用 | 步骤4/确认球位有层级，返回与动作可见。 |
| 安全区 | 适用 | 三个尺寸确认/返回图无明确边缘截断，触摸未验。 |
| 球库 | 差异保留 | 照片标记编号面板属于选择工具，不能机械改每日固定槽。 |
| 仪表 | 不适用 | 此阶段校准/确认不需要杆速和击球点。 |
| 动作 | 差异保留 | 重新标记及送入菜单按提取流程；“送入…”是源码完整菜单标题。 |
| 相机 | 不适用 | 照片确认2D预览无四机位要求。 |
| 菜单 | 差异保留 | 送入多个业务目的地是合法菜单语义；展开态未给。 |
| 提示 | 差异保留 | 步骤说明、球数是常驻操作上下文；不改普通Toast。 |
| 主题 | 差异保留 | 当前场景工具深色；同状态主题样本不足，不能据此宣布主题故障。 |
| 状态行为 | 证据不足 | 确认/返回与球数变化样本已看；选择照片、标定、实际送入未运行。 |
| 几何/投影 | 适用 | 确认预览桌体与球可见；照片到坐标映射真实性未由截图验证。 |

静态抽查仅用于解释适用性，不证明当前截图同期行为。[57-ui-reviewer.mdc](/Users/song/projects/13.billiard_trainer/.cursor/rules/57-ui-reviewer.mdc)为视觉检查规则；[Typography.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/DesignSystem/Typography.swift)以真实token为准。

静态抽查：[BallExtractionView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/BallExtraction/Views/BallExtractionView.swift:391)场景预览；[BallExtractionView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/BallExtraction/Views/BallExtractionView.swift:440)提供多个送入目的地，451行文案明确写作“送入…”，因此没有把该省略号误报为布局裁字。


## 问题与证据

没有新增已证实的视觉偏差；以下证据缺口仍开放。

## 用户意见逐条回应

本manifest没有待回应的文字意见；approved/未审状态均已独立看图，不作为免检依据。

## 逐图覆盖

| 截图 | 实际观察方法 | 结论 |
|---|---|---|
| [P13-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r3/phone/extraction-confirm-portrait-return.png) · phone · extraction-confirm-portrait-return | contact-sheet | 确认球位/返回态桌体、球、球数与底部标记入口可见；“送入…”是菜单文案，非自动截断证据。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P13-02](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r3/phone/extraction-confirm.png) · phone · extraction-confirm | contact-sheet, original | 确认球位/返回态桌体、球、球数与底部标记入口可见；“送入…”是菜单文案，非自动截断证据。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P13-03](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r3/phone/extraction-to-composer.png) · phone · extraction-to-composer | contact-sheet | 确认球位/返回态桌体、球、球数与底部标记入口可见；“送入…”是菜单文案，非自动截断证据。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P13-04](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/se/extraction-confirm-portrait-return.png) · se · extraction-confirm-portrait-return | contact-sheet | 确认球位/返回态桌体、球、球数与底部标记入口可见；“送入…”是菜单文案，非自动截断证据。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P13-05](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/se/extraction-confirm.png) · se · extraction-confirm | contact-sheet | 确认球位/返回态桌体、球、球数与底部标记入口可见；“送入…”是菜单文案，非自动截断证据。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P13-06](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/se/extraction-to-composer.png) · se · extraction-to-composer | contact-sheet | 确认球位/返回态桌体、球、球数与底部标记入口可见；“送入…”是菜单文案，非自动截断证据。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P13-07](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r3/ipad/extraction-confirm-landscape.png) · ipad · extraction-confirm-landscape | contact-sheet | 确认球位/返回态桌体、球、球数与底部标记入口可见；“送入…”是菜单文案，非自动截断证据。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P13-08](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r3/ipad/extraction-confirm-portrait-return.png) · ipad · extraction-confirm-portrait-return | contact-sheet | 确认球位/返回态桌体、球、球数与底部标记入口可见；“送入…”是菜单文案，非自动截断证据。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P13-09](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r3/ipad/extraction-confirm.png) · ipad · extraction-confirm | contact-sheet | 确认球位/返回态桌体、球、球数与底部标记入口可见；“送入…”是菜单文案，非自动截断证据。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P13-10](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r3/ipad/extraction-to-composer.png) · ipad · extraction-to-composer | contact-sheet | 确认球位/返回态桌体、球、球数与底部标记入口可见；“送入…”是菜单文案，非自动截断证据。 本图未新增可确定的视觉偏差；不等于全功能验收。 |

## 证据缺口与后续验收

缺步骤1–3、照片权限/系统选择器、裁剪与四角标定、球号冲突/移除、送入菜单展开及实际目标页闭环；仅审当前10图，不能据此宣布完整提取流程通过。

本轮仅生成报告与覆盖清单，未修改App、原图、用户审批或共享任务状态。
