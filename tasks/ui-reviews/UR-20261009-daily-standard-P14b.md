# P14b · 内部编排 · 编辑 · 每日标准逐功能复审

审阅日期：2026-10-09；审阅者：GPT-6-astra（C组）；只审不改。

本页13条截图记录全部目视完成；联系表逐图初筛，提出视觉问题的图另用原图或原分辨率局部复核。清单见[coverage-P14b.json](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/coverage-P14b.json)。原图可能由不同历史轮次组合；当前源码只作静态路径支持，不冒充截图同期构建或实测。

## 范围与结论

设备/状态：phone · batch-author-empty；phone · batch-author-free；phone · batch-author-portrait-return；phone · batch-display-menu；se · batch-author-empty；se · batch-author-free；se · batch-author-portrait-return；se · batch-display-menu；ipad · batch-author-empty；ipad · batch-author-free；ipad · batch-author-landscape；ipad · batch-author-portrait-return；ipad · batch-display-menu。

发现4项：P14b-S01 P1 iPad空态交付图的整个球桌舞台全黑；P14b-S02 P2 SE求解按钮与点换按钮出现可见叠压；P14b-S03 P2 SE两个保存去向的核心标签被截断；P14b-S04 P2 场景普通反馈仍走带底板的Toast变体

本页已通过的截图同样纳入复审。未进行新的触摸、动画、性能、物理准确性或真机体验验证。

## 标准来源与适用性

依据[CURRENT.md](/Users/song/projects/13.billiard_trainer/tasks/daily-adaptive/CURRENT.md)、[CORE-TEMPLATE-C56.md](/Users/song/projects/13.billiard_trainer/tasks/table-page-adaptation/CORE-TEMPLATE-C56.md)、[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md)、[基础布局与自适应标准.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/基础布局与自适应标准.md)、[每日清台完整标准与跨页面复用分析.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md)及[提示与弹窗规范.md](/Users/song/projects/13.billiard_trainer/docs/design/feedback/提示与弹窗规范.md)。提示采用后半修订及C38/B6：说明顶部、动作桌心；不恢复旧“全部居中”或整块面板。字号以当前Typography/token与页内规范为准。

| 领域 | 判定 | 本页适用说明 |
|---|---|---|
| 标题 | 适用 | 内部drill标识和下一操作上下文保留；本轮标题新规则按实际单行检查。 |
| 安全区 | 适用 | SE工具相交见S02；命中边界不能由截图判定。 |
| 球库 | 差异保留 | 编排底部双行含母球用于编辑；不能机械移到每日顶部。 |
| 仪表 | 差异保留 | 专用求解/辅助线/点换保留；相邻净空仍受BL09约束。 |
| 动作 | 适用 | 保存去向截断见S03；不把内部编辑强制改成每日规则按钮。 |
| 相机 | 不适用 | 当前2D编排图无四机位合同。 |
| 菜单 | 差异保留 | 已看phone/SE/iPad显示菜单，项目专用显示项可保留。 |
| 提示 | 适用 | 静态路径仍使用带底板Toast，见S04；常驻编排上下文另算。 |
| 主题 | 差异保留 | 内部工具深色合同保留；暂无本页新增主题意见。 |
| 状态行为 | 证据不足 | 空态/自由态/返回态已看，保存、撤回、求解与命中未运行。 |
| 几何/投影 | 适用 | iPad空态全黑是交付失败S01，非合法无源图空态。 |

静态抽查仅用于解释适用性，不证明当前截图同期行为。[57-ui-reviewer.mdc](/Users/song/projects/13.billiard_trainer/.cursor/rules/57-ui-reviewer.mdc)为视觉检查规则；[Typography.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/DesignSystem/Typography.swift)以真实token为准。


## 问题与证据

### P14b-S01 · P1 · iPad空态交付图的整个球桌舞台全黑

- 分类：既有标准偏差（交付截图）。
- 可见现状/路径：原图中上方编排工具、右侧仪表和底部球库存在，中央舞台却完全没有球桌、袋口或母球。该图不能证明可用的空台编辑起点，当前交付证据不可接受。其他手机/SE空态有完整球桌，不能豁免本图。
- 标准：DC01/02、BL§2与§5：场景主体保比例完整可见；截图交付须呈现被验收状态。P1针对交付画面失去核心操作主体，不等同已证实持续生产故障。
- 源码：[BatchAuthoringView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/BatchDrillStudio/BatchAuthoringView.swift:349)初始化；[BatchAuthoringView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/BatchDrillStudio/BatchAuthoringView.swift:645)无条件场景容器。源码未提供“空态故意无桌”的契约；未运行。
- 证据：P14b-09 [batch-author-empty.png](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r8/ipad/batch-author-empty.png)
- 建议：先查明final-r8/ipad/batch-author-empty.png的捕获时点与渲染状态，再补稳定空台首次进入截图；若可复现，定位场景加载/尺寸更新后修复并复验。不能只沿用用户approved状态。
- 范围与边界：当前图册P14b iPad空态交付；运行时持续性、触摸和原因未验。

### P14b-S02 · P2 · SE求解按钮与点换按钮出现可见叠压

- 分类：既有标准偏差。
- 可见现状/路径：原图右上工具区，“点换”胶囊的上缘进入“求解”按钮区域，两块可见背景重叠，标签垂直间距不足。截图足以证明V相交，不能证明实际H命中互抢。
- 标准：BL09可见主体净空与命中路由分开验；内部编辑可保留专用求解工具，仍须避免可见动作叠压。
- 源码：[BatchAuthoringView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/BatchDrillStudio/BatchAuthoringView.swift:292)固定topRowHeight分配；[BatchAuthoringView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/BatchDrillStudio/BatchAuthoringView.swift:638)点换按仪表上方定位。
- 证据：P14b-05 [batch-author-empty.png](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r8/se/batch-author-empty.png)
- 建议：将工具行与场景侧柱纳入共同容量避让，保留两项功能和可读标签；另验实际触摸边界。
- 范围与边界：已确认SE空态；SE其他状态需稳定状态复测，不由一帧推断所有屏幕。

### P14b-S03 · P2 · SE两个保存去向的核心标签被截断

- 分类：既有标准偏差。
- 可见现状/路径：底部显示“保存·选下…”和“保存·下个d…”，无法在可见文字中完整读出两个保存目的地。按钮存在，问题是目的地辨识，不是按钮丢失。
- 标准：BL§4.2正常文字与§5容量重排；57-ui-reviewer文字完整性。内部业务动作可以保留，不应靠截断核心词满足容量。
- 源码：[BatchAuthoringView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/BatchDrillStudio/BatchAuthoringView.swift:719)saveRow；[BatchAuthoringView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/BatchDrillStudio/BatchAuthoringView.swift:759)lineLimit(1)/minimumScaleFactor(0.7)。
- 证据：P14b-05 [batch-author-empty.png](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r8/se/batch-author-empty.png)
- 建议：精简且区分两类保存去向的文案，或为窄宽重新布局保存行；普通字号与大字号分别验图，不继续整行缩小。
- 范围与边界：SE编排底部保存操作；未执行保存，不声称数据去向错误。

### P14b-S04 · P2 · 场景普通反馈仍走带底板的Toast变体

- 分类：既有标准偏差（静态路径）。
- 可见现状/路径：本组没有捕获临时Toast，不能声称截图里已有彩色提示板；但当前点换提示等明确走flash→btToast→BTNoticeContent默认textOnly=false，有背景和边框。
- 标准：DC19、提示与弹窗规范后半修订、C38/B6：场景普通说明用白字+相应符号+阴影，无背景无边框；成功/警示/错误可保留对应符号，不机械全改ⓘ。
- 源码：[BatchAuthoringView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/BatchDrillStudio/BatchAuthoringView.swift:316)；[BatchAuthoringView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/BatchDrillStudio/BatchAuthoringView.swift:785)；[BatchAuthoringView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/BatchDrillStudio/BatchAuthoringView.swift:1047)；[BTToast.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Components/BTToast.swift:34)和[BTToast.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/Components/BTToast.swift:139)
- 证据：无运行截图；明确为当前源码静态路径，不伪造截图证据。
- 建议：后续实施时为场景普通反馈使用无底板变体，保留不同反馈语义；点换操作教学如需常驻，应明确状态语义而非只换颜色。补显示/消失/多消息截图。
- 范围与边界：当前编排页flash调用链；只读静态成立，实际位置、遮挡和生命周期未运行验证。

## 用户意见逐条回应

本manifest没有待回应的文字意见；approved/未审状态均已独立看图，不作为免检依据。

## 逐图覆盖

| 截图 | 实际观察方法 | 结论 |
|---|---|---|
| [P14b-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r8/phone/batch-author-empty.png) · phone · batch-author-empty | contact-sheet | 已看本图工具、舞台、仪表、球库和保存行；菜单图按真实覆盖关系检查。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P14b-02](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r8/phone/batch-author-free.png) · phone · batch-author-free | contact-sheet | 已看本图工具、舞台、仪表、球库和保存行；菜单图按真实覆盖关系检查。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P14b-03](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r8/phone/batch-author-portrait-return.png) · phone · batch-author-portrait-return | contact-sheet | 已看本图工具、舞台、仪表、球库和保存行；菜单图按真实覆盖关系检查。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P14b-04](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r8/phone/batch-display-menu.png) · phone · batch-display-menu | contact-sheet | 已看本图工具、舞台、仪表、球库和保存行；菜单图按真实覆盖关系检查。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P14b-05](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r8/se/batch-author-empty.png) · se · batch-author-empty | contact-sheet, original | 已看本图工具、舞台、仪表、球库和保存行；菜单图按真实覆盖关系检查。 明确问题：P14b-S02,P14b-S03。 |
| [P14b-06](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r8/se/batch-author-free.png) · se · batch-author-free | contact-sheet | 已看本图工具、舞台、仪表、球库和保存行；菜单图按真实覆盖关系检查。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P14b-07](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r8/se/batch-author-portrait-return.png) · se · batch-author-portrait-return | contact-sheet | 已看本图工具、舞台、仪表、球库和保存行；菜单图按真实覆盖关系检查。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P14b-08](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r8/se/batch-display-menu.png) · se · batch-display-menu | contact-sheet | 已看本图工具、舞台、仪表、球库和保存行；菜单图按真实覆盖关系检查。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P14b-09](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r8/ipad/batch-author-empty.png) · ipad · batch-author-empty | contact-sheet, original | 已看本图工具、舞台、仪表、球库和保存行；菜单图按真实覆盖关系检查。 明确问题：P14b-S01。 |
| [P14b-10](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r8/ipad/batch-author-free.png) · ipad · batch-author-free | contact-sheet | 已看本图工具、舞台、仪表、球库和保存行；菜单图按真实覆盖关系检查。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P14b-11](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r8/ipad/batch-author-landscape.png) · ipad · batch-author-landscape | contact-sheet | 已看本图工具、舞台、仪表、球库和保存行；菜单图按真实覆盖关系检查。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P14b-12](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r8/ipad/batch-author-portrait-return.png) · ipad · batch-author-portrait-return | contact-sheet | 已看本图工具、舞台、仪表、球库和保存行；菜单图按真实覆盖关系检查。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P14b-13](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r8/ipad/batch-display-menu.png) · ipad · batch-display-menu | contact-sheet | 已看本图工具、舞台、仪表、球库和保存行；菜单图按真实覆盖关系检查。 本图未新增可确定的视觉偏差；不等于全功能验收。 |

## 证据缺口与后续验收

缺真实求解中/失败/无解、点换提示、保存成功/错误、长按/拖放边界、转屏连续过程与大字号；不得把静态整图正常当作这些操作已验收。

本轮仅生成报告与覆盖清单，未修改App、原图、用户审批或共享任务状态。
