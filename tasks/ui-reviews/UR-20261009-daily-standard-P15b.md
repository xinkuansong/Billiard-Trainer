# P15b · 训练记录球桌 · 每日标准逐功能复审

审阅日期：2026-10-09；审阅者：GPT-6-astra（C组）；只审不改。

本页9条截图记录全部目视完成；联系表逐图初筛，提出视觉问题的图另用原图或原分辨率局部复核。清单见[coverage-P15b.json](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/coverage-P15b.json)。原图可能由不同历史轮次组合；当前源码只作静态路径支持，不冒充截图同期构建或实测。

## 范围与结论

设备/状态：phone · record-table-2d；phone · record-table-3d；phone · record-table-portrait-return；se · record-table-2d；se · record-table-3d；se · record-table-portrait-return；ipad · record-table-2d；ipad · record-table-3d；ipad · record-table-portrait-return。

发现0项：没有从现有截图确认新的视觉偏差；覆盖不足列在下文，不宣布完整验收通过。

本页已通过的截图同样纳入复审。未进行新的触摸、动画、性能、物理准确性或真机体验验证。

## 标准来源与适用性

依据[CURRENT.md](/Users/song/projects/13.billiard_trainer/tasks/daily-adaptive/CURRENT.md)、[CORE-TEMPLATE-C56.md](/Users/song/projects/13.billiard_trainer/tasks/table-page-adaptation/CORE-TEMPLATE-C56.md)、[每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md)、[基础布局与自适应标准.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/基础布局与自适应标准.md)、[每日清台完整标准与跨页面复用分析.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台完整标准与跨页面复用分析.md)及[提示与弹窗规范.md](/Users/song/projects/13.billiard_trainer/docs/design/feedback/提示与弹窗规范.md)。提示采用后半修订及C38/B6：说明顶部、动作桌心；不恢复旧“全部居中”或整块面板。字号以当前Typography/token与页内规范为准。

| 领域 | 判定 | 本页适用说明 |
|---|---|---|
| 标题 | 适用 | 宿主详情/记录标题与信息架构保留。 |
| 安全区 | 适用 | 嵌入播放与底部业务操作按宿主滚动布局核；下方内容在折叠外不自动算裁切。 |
| 球库 | 不适用 | 嵌入演示/训练记录不是每日自由选球；试打另按目标场景评。 |
| 仪表 | 差异保留 | 演示HUD/播放读数不能机械换成可操作双尺。 |
| 动作 | 差异保留 | 播放、暂停、2D/3D、开始训练/试打各有业务含义。 |
| 相机 | 差异保留 | 嵌入3D播放机位不直接强加每日四机位HUD。 |
| 菜单 | 差异保留 | 宿主工具按详情/记录语义，未展示完整菜单展开。 |
| 提示 | 差异保留 | 精讲、试打目标、成绩是必要内容；不能按临时提示拆掉所有底板。 |
| 主题 | 证据不足 | 本组主要浅色宿主，场景内深HUD合理；缺同状态浅/深成对图。 |
| 状态行为 | 证据不足 | 2D/3D/暂停/返回静态样本已看；不证明播放、计分、场景状态保留。 |
| 几何/投影 | 适用 | 嵌入桌按容器展示；iPad首屏下方桌未全露出是滚动文档位置，不等于投影越界。 |

静态抽查仅用于解释适用性，不证明当前截图同期行为。[57-ui-reviewer.mdc](/Users/song/projects/13.billiard_trainer/.cursor/rules/57-ui-reviewer.mdc)为视觉检查规则；[Typography.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/DesignSystem/Typography.swift)以真实token为准。

静态抽查：[DrillRecordView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/Training/Views/DrillRecordView.swift:342)球台示意是可折叠文档区块；366行使用DrillSceneView，加载前有fit烘焙桌后备。故不按全屏每日页强制追加球库/仪表，也不把折叠或滚动位置等同投影丢失。


## 问题与证据

没有新增已证实的视觉偏差；以下证据缺口仍开放。

## 用户意见逐条回应

本manifest没有待回应的文字意见；approved/未审状态均已独立看图，不作为免检依据。

## 逐图覆盖

| 截图 | 实际观察方法 | 结论 |
|---|---|---|
| [P15b-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/phone/record-table-2d.png) · phone · record-table-2d | contact-sheet | 已看记录计分上下文、嵌入球桌和播放/模式控件；滚动折叠外内容不直接判投影裁切。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P15b-02](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/phone/record-table-3d.png) · phone · record-table-3d | contact-sheet | 已看记录计分上下文、嵌入球桌和播放/模式控件；滚动折叠外内容不直接判投影裁切。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P15b-03](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/phone/record-table-portrait-return.png) · phone · record-table-portrait-return | contact-sheet | 已看记录计分上下文、嵌入球桌和播放/模式控件；滚动折叠外内容不直接判投影裁切。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P15b-04](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/se/record-table-2d.png) · se · record-table-2d | contact-sheet | 已看记录计分上下文、嵌入球桌和播放/模式控件；滚动折叠外内容不直接判投影裁切。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P15b-05](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/se/record-table-3d.png) · se · record-table-3d | contact-sheet | 已看记录计分上下文、嵌入球桌和播放/模式控件；滚动折叠外内容不直接判投影裁切。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P15b-06](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/se/record-table-portrait-return.png) · se · record-table-portrait-return | contact-sheet | 已看记录计分上下文、嵌入球桌和播放/模式控件；滚动折叠外内容不直接判投影裁切。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P15b-07](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/ipad/record-table-2d.png) · ipad · record-table-2d | contact-sheet | 已看记录计分上下文、嵌入球桌和播放/模式控件；滚动折叠外内容不直接判投影裁切。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P15b-08](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/ipad/record-table-3d.png) · ipad · record-table-3d | contact-sheet | 已看记录计分上下文、嵌入球桌和播放/模式控件；滚动折叠外内容不直接判投影裁切。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P15b-09](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/ipad/record-table-portrait-return.png) · ipad · record-table-portrait-return | contact-sheet | 已看记录计分上下文、嵌入球桌和播放/模式控件；滚动折叠外内容不直接判投影裁切。 本图未新增可确定的视觉偏差；不等于全功能验收。 |

## 证据缺口与后续验收

未运行记录保存、评分操作、播放/切换/旋转连续过程；未提供主题对照或最大辅助字号。不得因首屏可见下方半桌就推定整桌无法滚动查看。

本轮仅生成报告与覆盖清单，未修改App、原图、用户审批或共享任务状态。
