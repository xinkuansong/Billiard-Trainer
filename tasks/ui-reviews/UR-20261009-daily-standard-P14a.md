# P14a · 内部编排 · 球形选择 · 每日标准逐功能复审

审阅日期：2026-10-09；审阅者：GPT-6-astra（C组）；只审不改。

本页7条截图记录全部目视完成；联系表逐图初筛，提出视觉问题的图另用原图或原分辨率局部复核。清单见[coverage-P14a.json](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/coverage-P14a.json)。原图可能由不同历史轮次组合；当前源码只作静态路径支持，不冒充截图同期构建或实测。

## 范围与结论

设备/状态：phone · batch-picker-portrait-return；phone · batch-picker；se · batch-picker-portrait-return；se · batch-picker；ipad · batch-picker-landscape；ipad · batch-picker-portrait-return；ipad · batch-picker。

发现0项：没有从现有截图确认新的视觉偏差；覆盖不足列在下文，不宣布完整验收通过。

本页已通过的截图同样纳入复审。未进行新的触摸、动画、性能、物理准确性或真机体验验证。

## 标准来源与适用性

依据[CURRENT.md](/Users/song/projects/13.billiard_trainer/tasks/daily-adaptive/CURRENT.md)、[CORE-TEMPLATE-C56.md](/Users/song/projects/13.billiard_trainer/tasks/table-page-adaptation/CORE-TEMPLATE-C56.md)、[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md)、[基础布局与自适应标准.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/基础布局与自适应标准.md)、[每日清台完整标准与跨页面复用分析.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md)及[提示与弹窗规范.md](/Users/song/projects/13.billiard_trainer/docs/design/feedback/提示与弹窗规范.md)。提示采用后半修订及C38/B6：说明顶部、动作桌心；不恢复旧“全部居中”或整块面板。字号以当前Typography/token与页内规范为准。

| 领域 | 判定 | 本页适用说明 |
|---|---|---|
| 标题 | 适用 | 内部编排标题、关闭及新增入口可见。 |
| 安全区 | 适用 | 空源图区布局可见；触摸边界未验。 |
| 球库 | 不适用 | 当前是来源/球形选择页，尚未进入球桌编辑。 |
| 仪表 | 不适用 | 选择球形页无需击球仪表。 |
| 动作 | 差异保留 | 新增球形/关闭保留内部工作流。 |
| 相机 | 不适用 | 无场景机位。 |
| 菜单 | 差异保留 | 新增源与原生confirmationDialog保留，展开态未给。 |
| 提示 | 差异保留 | 无源图引导为常驻空态信息，不强改短暂Toast。 |
| 主题 | 差异保留 | 内部工具固定深色既有页契约；未新增用户主题意见。 |
| 状态行为 | 证据不足 | 7图均空来源起点；已有存档/克隆/删除未提供。 |
| 几何/投影 | 不适用 | 当前图没有球桌，空态未加载球桌符合此选择页语义。 |

静态抽查仅用于解释适用性，不证明当前截图同期行为。[57-ui-reviewer.mdc](/Users/song/projects/13.billiard_trainer/.cursor/rules/57-ui-reviewer.mdc)为视觉检查规则；[Typography.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/DesignSystem/Typography.swift)以真实token为准。

静态抽查：[BatchBallExtractionView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/BatchDrillStudio/BatchBallExtractionView.swift:63)新增来源使用confirmationDialog；[BatchBallExtractionView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/BatchDrillStudio/BatchBallExtractionView.swift:156)存在无源图引导，376行允许无图新增进入编排台。现有空态符合该选择页合同。


## 问题与证据

没有新增已证实的视觉偏差；以下证据缺口仍开放。

## 用户意见逐条回应

本manifest没有待回应的文字意见；approved/未审状态均已独立看图，不作为免检依据。

## 逐图覆盖

| 截图 | 实际观察方法 | 结论 |
|---|---|---|
| [P14a-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r8/phone/batch-picker-portrait-return.png) · phone · batch-picker-portrait-return | contact-sheet | 无源图起点、新增卡片和说明可见；此选择页无球桌符合其状态语义，已有存档流程未在本图展示。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P14a-02](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r8/phone/batch-picker.png) · phone · batch-picker | contact-sheet | 无源图起点、新增卡片和说明可见；此选择页无球桌符合其状态语义，已有存档流程未在本图展示。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P14a-03](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r8/se/batch-picker-portrait-return.png) · se · batch-picker-portrait-return | contact-sheet | 无源图起点、新增卡片和说明可见；此选择页无球桌符合其状态语义，已有存档流程未在本图展示。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P14a-04](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r8/se/batch-picker.png) · se · batch-picker | contact-sheet | 无源图起点、新增卡片和说明可见；此选择页无球桌符合其状态语义，已有存档流程未在本图展示。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P14a-05](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r8/ipad/batch-picker-landscape.png) · ipad · batch-picker-landscape | contact-sheet | 无源图起点、新增卡片和说明可见；此选择页无球桌符合其状态语义，已有存档流程未在本图展示。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P14a-06](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r8/ipad/batch-picker-portrait-return.png) · ipad · batch-picker-portrait-return | contact-sheet | 无源图起点、新增卡片和说明可见；此选择页无球桌符合其状态语义，已有存档流程未在本图展示。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P14a-07](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r8/ipad/batch-picker.png) · ipad · batch-picker | contact-sheet | 无源图起点、新增卡片和说明可见；此选择页无球桌符合其状态语义，已有存档流程未在本图展示。 本图未新增可确定的视觉偏差；不等于全功能验收。 |

## 证据缺口与后续验收

缺新增方式选择、已有存档列表、克隆、删除确认及返回列表状态；不能把P14a合法空源图与P14b应有球桌却全黑混为一谈。

本轮仅生成报告与覆盖清单，未修改App、原图、用户审批或共享任务状态。
