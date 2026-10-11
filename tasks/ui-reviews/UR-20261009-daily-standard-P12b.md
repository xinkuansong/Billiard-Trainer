# P12b · 瞄准点图解测验 · 每日标准逐功能复审

审阅日期：2026-10-09；审阅者：GPT-6-astra（C组）；只审不改。

本页10条截图记录全部目视完成；联系表逐图初筛，提出视觉问题的图另用原图或原分辨率局部复核。清单见[coverage-P12b.json](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/coverage-P12b.json)。原图可能由不同历史轮次组合；当前源码只作静态路径支持，不冒充截图同期构建或实测。

## 范围与结论

设备/状态：phone · quiz-point-initial；phone · quiz-point-next；phone · quiz-point-result；se · quiz-point-initial；se · quiz-point-next；se · quiz-point-result；ipad · quiz-point-initial；ipad · quiz-point-landscape；ipad · quiz-point-next；ipad · quiz-point-result。

发现2项：P12b-S01 P2 测验宿主目前固定深色，未提供所要求的浅/深差异；P12b-S02 P2 偏移以毫米显示，但未给出球半径的尺度参照

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

### P12b-S01 · P2 · 测验宿主目前固定深色，未提供所要求的浅/深差异

- 分类：用户新增要求。
- 可见现状/路径：全组截图均为黑色宿主；原图确认题目、操作区、统计卡均深色。当前源码显式将页面colorScheme设为dark，支持用户关于没有模式差异的观察。
- 标准：2026-10-09用户原话优先；P12既有页面契约曾明确黑底使用暗色token，因此不倒推为此前未遵守旧稿。
- 源码：当前静态路径：[AimPointTrainingView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/AimPointTrainingView.swift:219)。本轮未运行主题切换。
- 证据：P12b-01 [quiz-point-initial.png](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r2/phone/quiz-point-initial.png)
- 建议：确认并实施本轮新增的浅/深宿主方案：题目、统计和操作卡按主题变化，球桌图面可保留稳定材质；同窗口同状态成对验图。
- 范围与边界：本测验整页宿主；已通过的换题、答题、结果状态也应纳入后续主题验收。

### P12b-S02 · P2 · 偏移以毫米显示，但未给出球半径的尺度参照

- 分类：用户新增要求。
- 可见现状/路径：原图显示“当前偏移 0.0 mm”，球体图示与数值之间没有R/直径解释；整组初始、下一题、结果也未呈现半径量纲参照。
- 标准：2026-10-09用户要求“在某个地方加上球半径的说明吧，不然用户对距离没概念”；属于新增教学说明。
- 源码：[AimPointTrainingView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/AimPointTrainingView.swift:29)已从引擎半径派生ballRadiusMM；[AimPointTrainingView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/AngleTraining/Views/AimPointTrainingView.swift:293)的题目/当前偏移展示未使用半径说明。
- 证据：P12b-01 [quiz-point-initial.png](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r2/phone/quiz-point-initial.png)
- 建议：在当前偏移或题目说明旁增加常驻简短球半径说明，数值取现有ballRadiusMM，必要时展示“偏移≈xR”；不要独立硬编码另一套尺寸。
- 范围与边界：全部题目与答案复盘；不是需要定时消失的普通提示。

## 用户意见逐条回应

- P12b-01「没有深色和浅色的差异，此外，在某个地方加上球半径的说明吧，不然用户对距离没概念」：同意，主题观察有强制dark源码支持；按用户新增要求处理，不追溯定性旧稿违规。半径说明缺失也成立，见S02；应取引擎真源数值。

## 逐图覆盖

| 截图 | 实际观察方法 | 结论 |
|---|---|---|
| [P12b-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r2/phone/quiz-point-initial.png) · phone · quiz-point-initial | contact-sheet, original | 已看本图题目/统计/操作与结果区域；宿主为深色，常驻题目/结果卡不按临时Toast判错。 明确问题：P12b-S01,P12b-S02。 |
| [P12b-02](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r2/phone/quiz-point-next.png) · phone · quiz-point-next | contact-sheet | 已看本图题目/统计/操作与结果区域；宿主为深色，常驻题目/结果卡不按临时Toast判错。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P12b-03](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r2/phone/quiz-point-result.png) · phone · quiz-point-result | contact-sheet | 已看本图题目/统计/操作与结果区域；宿主为深色，常驻题目/结果卡不按临时Toast判错。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P12b-04](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/se/quiz-point-initial.png) · se · quiz-point-initial | contact-sheet | 已看本图题目/统计/操作与结果区域；宿主为深色，常驻题目/结果卡不按临时Toast判错。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P12b-05](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/se/quiz-point-next.png) · se · quiz-point-next | contact-sheet, original | 已看本图题目/统计/操作与结果区域；宿主为深色，常驻题目/结果卡不按临时Toast判错。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P12b-06](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/se/quiz-point-result.png) · se · quiz-point-result | contact-sheet | 已看本图题目/统计/操作与结果区域；宿主为深色，常驻题目/结果卡不按临时Toast判错。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P12b-07](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r2/ipad/quiz-point-initial.png) · ipad · quiz-point-initial | contact-sheet | 已看本图题目/统计/操作与结果区域；宿主为深色，常驻题目/结果卡不按临时Toast判错。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P12b-08](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r2/ipad/quiz-point-landscape.png) · ipad · quiz-point-landscape | contact-sheet | 已看本图题目/统计/操作与结果区域；宿主为深色，常驻题目/结果卡不按临时Toast判错。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P12b-09](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r2/ipad/quiz-point-next.png) · ipad · quiz-point-next | contact-sheet | 已看本图题目/统计/操作与结果区域；宿主为深色，常驻题目/结果卡不按临时Toast判错。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P12b-10](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r2/ipad/quiz-point-result.png) · ipad · quiz-point-result | contact-sheet | 已看本图题目/统计/操作与结果区域；宿主为深色，常驻题目/结果卡不按临时Toast判错。 本图未新增可确定的视觉偏差；不等于全功能验收。 |

## 证据缺口与后续验收

未运行系统主题切换、键盘焦点/边界、连续答题计分或VoiceOver。无同窗同题浅/深成对图。P12b-05已原图核对：标题与说明均为向左切，初筛缩略图误读已撤回，不形成问题。

本轮仅生成报告与覆盖清单，未修改App、原图、用户审批或共享任务状态。
