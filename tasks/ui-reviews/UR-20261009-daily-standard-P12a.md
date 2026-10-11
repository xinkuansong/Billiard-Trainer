# P12a · 角度预测测验 · 每日标准逐功能复审

审阅日期：2026-10-09；审阅者：GPT-6-astra（C组）；只审不改。

本页13条截图记录全部目视完成；联系表逐图初筛，提出视觉问题的图另用原图或原分辨率局部复核。清单见[coverage-P12a.json](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/coverage-P12a.json)。原图可能由不同历史轮次组合；当前源码只作静态路径支持，不冒充截图同期构建或实测。

## 范围与结论

设备/状态：phone · quiz-angle-initial；phone · quiz-angle-keypad；phone · quiz-angle-next；phone · quiz-angle-result；se · quiz-angle-initial；se · quiz-angle-keypad；se · quiz-angle-next；se · quiz-angle-result；ipad · quiz-angle-initial；ipad · quiz-angle-keypad；ipad · quiz-angle-landscape；ipad · quiz-angle-next；ipad · quiz-angle-result。

发现1项：P12a-S01 P2 测验宿主目前固定深色，未提供所要求的浅/深差异

本页已通过的截图同样纳入复审。未进行新的触摸、动画、性能、物理准确性或真机体验验证。

## 标准来源与适用性

依据[CURRENT.md](/Users/song/projects/13.billiard_trainer/tasks/daily-adaptive/CURRENT.md)、[CORE-TEMPLATE-C56.md](/Users/song/projects/13.billiard_trainer/tasks/table-page-adaptation/CORE-TEMPLATE-C56.md)、[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md)、[基础布局与自适应标准.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/基础布局与自适应标准.md)、[每日清台完整标准与跨页面复用分析.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md)及[提示与弹窗规范.md](/Users/song/projects/13.billiard_trainer/docs/design/feedback/提示与弹窗规范.md)。提示采用后半修订及C38/B6：说明顶部、动作桌心；不恢复旧“全部居中”或整块面板。字号以当前Typography/token与页内规范为准。

| 领域 | 判定 | 本页适用说明 |
|---|---|---|
| 标题 | 适用 | 测验名和返回清楚；保留题目类导航。 |
| 安全区 | 适用 | 所给初始/换题/结果及键盘样本主操作可见；触摸未验。 |
| 球库 | 不适用 | 随机题的单球/双球示意，不是自由摆球。 |
| 仪表 | 差异保留 | 角度输入或假想球拖动替代击球仪表。 |
| 动作 | 差异保留 | 换题/答题/提交/下一题保持测验流程。 |
| 相机 | 不适用 | 二维教学示意无每日四机位要求。 |
| 菜单 | 差异保留 | 复位及题目动作按测验语义，不强加显示菜单。 |
| 提示 | 差异保留 | 题目、成绩、误差、说明均是常驻教学/结果，不当普通Toast拆除卡片。 |
| 主题 | 用户新增要求 | 静态代码固定dark；需新增宿主主题差异。 |
| 状态行为 | 证据不足 | 已看前后题/结果；不证明输入校验、拖动范围、累计成绩与方向算法。 |
| 几何/投影 | 适用 | 球图可见；P12b半径参照为新增要求，不更改物理半径。 |

静态抽查仅用于解释适用性，不证明当前截图同期行为。[57-ui-reviewer.mdc](/Users/song/projects/13.billiard_trainer/.cursor/rules/57-ui-reviewer.mdc)为视觉检查规则；[Typography.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/DesignSystem/Typography.swift)以真实token为准。


## 问题与证据

### P12a-S01 · P2 · 测验宿主目前固定深色，未提供所要求的浅/深差异

- 分类：用户新增要求。
- 可见现状/路径：全组截图均为黑色宿主；原图确认题目、操作区、统计卡均深色。当前源码显式将页面colorScheme设为dark，支持用户关于没有模式差异的观察。
- 标准：2026-10-09用户原话优先；P12既有页面契约曾明确黑底使用暗色token，因此不倒推为此前未遵守旧稿。
- 源码：当前静态路径：[GeometricAngleQuizView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/GeometricAngleQuizView.swift:78)。本轮未运行主题切换。
- 证据：P12a-01 [quiz-angle-initial.png](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r2/phone/quiz-angle-initial.png)
- 建议：确认并实施本轮新增的浅/深宿主方案：题目、统计和操作卡按主题变化，球桌图面可保留稳定材质；同窗口同状态成对验图。
- 范围与边界：本测验整页宿主；已通过的换题、答题、结果状态也应纳入后续主题验收。

## 用户意见逐条回应

- P12a-01「是不是没有深色和浅色模式」：同意，主题观察有强制dark源码支持；按用户新增要求处理，不追溯定性旧稿违规。
- P12a-04「是不是没有浅色和深色模式的区分」：同意，主题观察有强制dark源码支持；按用户新增要求处理，不追溯定性旧稿违规。

## 逐图覆盖

| 截图 | 实际观察方法 | 结论 |
|---|---|---|
| [P12a-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r2/phone/quiz-angle-initial.png) · phone · quiz-angle-initial | contact-sheet, original | 已看本图题目/统计/操作与结果区域；宿主为深色，常驻题目/结果卡不按临时Toast判错。 明确问题：P12a-S01。 |
| [P12a-02](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r2/phone/quiz-angle-keypad.png) · phone · quiz-angle-keypad | contact-sheet | 已看本图题目/统计/操作与结果区域；宿主为深色，常驻题目/结果卡不按临时Toast判错。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P12a-03](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r2/phone/quiz-angle-next.png) · phone · quiz-angle-next | contact-sheet | 已看本图题目/统计/操作与结果区域；宿主为深色，常驻题目/结果卡不按临时Toast判错。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P12a-04](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r2/phone/quiz-angle-result.png) · phone · quiz-angle-result | contact-sheet | 已看本图题目/统计/操作与结果区域；宿主为深色，常驻题目/结果卡不按临时Toast判错。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P12a-05](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/se/quiz-angle-initial.png) · se · quiz-angle-initial | contact-sheet | 已看本图题目/统计/操作与结果区域；宿主为深色，常驻题目/结果卡不按临时Toast判错。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P12a-06](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/se/quiz-angle-keypad.png) · se · quiz-angle-keypad | contact-sheet | 已看本图题目/统计/操作与结果区域；宿主为深色，常驻题目/结果卡不按临时Toast判错。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P12a-07](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/se/quiz-angle-next.png) · se · quiz-angle-next | contact-sheet | 已看本图题目/统计/操作与结果区域；宿主为深色，常驻题目/结果卡不按临时Toast判错。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P12a-08](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/se/quiz-angle-result.png) · se · quiz-angle-result | contact-sheet | 已看本图题目/统计/操作与结果区域；宿主为深色，常驻题目/结果卡不按临时Toast判错。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P12a-09](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r2/ipad/quiz-angle-initial.png) · ipad · quiz-angle-initial | contact-sheet | 已看本图题目/统计/操作与结果区域；宿主为深色，常驻题目/结果卡不按临时Toast判错。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P12a-10](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r2/ipad/quiz-angle-keypad.png) · ipad · quiz-angle-keypad | contact-sheet | 已看本图题目/统计/操作与结果区域；宿主为深色，常驻题目/结果卡不按临时Toast判错。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P12a-11](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r2/ipad/quiz-angle-landscape.png) · ipad · quiz-angle-landscape | contact-sheet | 已看本图题目/统计/操作与结果区域；宿主为深色，常驻题目/结果卡不按临时Toast判错。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P12a-12](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r2/ipad/quiz-angle-next.png) · ipad · quiz-angle-next | contact-sheet | 已看本图题目/统计/操作与结果区域；宿主为深色，常驻题目/结果卡不按临时Toast判错。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P12a-13](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r2/ipad/quiz-angle-result.png) · ipad · quiz-angle-result | contact-sheet | 已看本图题目/统计/操作与结果区域；宿主为深色，常驻题目/结果卡不按临时Toast判错。 本图未新增可确定的视觉偏差；不等于全功能验收。 |

## 证据缺口与后续验收

键盘图仅证明当前输入面板可见，不证明不同键盘、辅助字号、非法值与计分逻辑；未运行主题切换。

本轮仅生成报告与覆盖清单，未修改App、原图、用户审批或共享任务状态。
