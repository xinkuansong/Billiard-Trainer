# P15a · 内容详情球桌 · 每日标准逐功能复审

审阅日期：2026-10-09；审阅者：GPT-6-astra（C组）；只审不改。

本页16条截图记录全部目视完成；联系表逐图初筛，提出视觉问题的图另用原图或原分辨率局部复核。清单见[coverage-P15a.json](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/coverage-P15a.json)。原图可能由不同历史轮次组合；当前源码只作静态路径支持，不冒充截图同期构建或实测。

## 范围与结论

设备/状态：phone · detail-2d；phone · detail-3d；phone · detail-paused；phone · detail-portrait-return；phone · detail-to-tryout；se · detail-2d；se · detail-3d；se · detail-paused；se · detail-portrait-return；se · detail-to-tryout；ipad · detail-2d-landscape；ipad · detail-2d；ipad · detail-3d；ipad · detail-paused；ipad · detail-portrait-return；ipad · detail-to-tryout。

发现1项：P15a-S01 P1 iPad从详情进入试打的球桌严重偏出屏幕

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
| 几何/投影 | 适用 | 试打iPad越界见S01；记录页桌在滚动内容中露出部分须结合滚动位置，不能误报。 |

静态抽查仅用于解释适用性，不证明当前截图同期行为。[57-ui-reviewer.mdc](/Users/song/projects/13.billiard_trainer/.cursor/rules/57-ui-reviewer.mdc)为视觉检查规则；[Typography.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Core/DesignSystem/Typography.swift)以真实token为准。


## 问题与证据

### P15a-S01 · P1 · iPad从详情进入试打的球桌严重偏出屏幕

- 分类：既有标准偏差（交付截图）。
- 可见现状/路径：原图中球桌主体移到左上屏幕外，仅桌体部分边缘、球杆及一小块场景可见；界面控件仍在屏内。正常试打应能看到完整操作球桌，此图不能作为可接受的iPad试打交付。
- 标准：DC01/02与BL§2、§5、§8：真实球桌主体完整、投影与窗口适配需分状态验收；P1是交付画面失去关键内容，不推定稳定运行故障。
- 源码：[DrillDetailView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/DrillLibrary/Views/DrillDetailView.swift:164)进入PositionPlayComposerView；[PositionPlayComposerView.swift](/Users/song/projects/13.billiard_trainer/QiuJi/Features/PositionPlay/Views/PositionPlayComposerView.swift:44)嵌入FreePlayView。截图为final-r3，不等于当前源码轮次；未复现。
- 证据：P15a-16 [detail-to-tryout.png](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r3/ipad/detail-to-tryout.png)
- 建议：追查final-r3/ipad/detail-to-tryout.png捕获时点、容器尺寸和进入后投影更新，补稳定进入/旋转/返回截图；若可复现再定位修复。详情普通2D图或用户approved记录不能替代该状态。
- 范围与边界：iPad详情→试打交付；手机/SE对应图正常，运行时原因及持续性待验。

## 用户意见逐条回应

本manifest没有待回应的文字意见；approved/未审状态均已独立看图，不作为免检依据。

## 逐图覆盖

| 截图 | 实际观察方法 | 结论 |
|---|---|---|
| [P15a-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r3/phone/detail-2d.png) · phone · detail-2d | contact-sheet | 已看详情图文/嵌入球桌或试打目标页；暂停与模式只按截图状态核对，不推断动作成功。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P15a-02](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r3/phone/detail-3d.png) · phone · detail-3d | contact-sheet | 已看详情图文/嵌入球桌或试打目标页；暂停与模式只按截图状态核对，不推断动作成功。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P15a-03](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r3/phone/detail-paused.png) · phone · detail-paused | contact-sheet | 已看详情图文/嵌入球桌或试打目标页；暂停与模式只按截图状态核对，不推断动作成功。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P15a-04](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r3/phone/detail-portrait-return.png) · phone · detail-portrait-return | contact-sheet | 已看详情图文/嵌入球桌或试打目标页；暂停与模式只按截图状态核对，不推断动作成功。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P15a-05](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r3/phone/detail-to-tryout.png) · phone · detail-to-tryout | contact-sheet | 已看详情图文/嵌入球桌或试打目标页；暂停与模式只按截图状态核对，不推断动作成功。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P15a-06](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/se/detail-2d.png) · se · detail-2d | contact-sheet | 已看详情图文/嵌入球桌或试打目标页；暂停与模式只按截图状态核对，不推断动作成功。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P15a-07](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/se/detail-3d.png) · se · detail-3d | contact-sheet | 已看详情图文/嵌入球桌或试打目标页；暂停与模式只按截图状态核对，不推断动作成功。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P15a-08](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/se/detail-paused.png) · se · detail-paused | contact-sheet | 已看详情图文/嵌入球桌或试打目标页；暂停与模式只按截图状态核对，不推断动作成功。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P15a-09](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/se/detail-portrait-return.png) · se · detail-portrait-return | contact-sheet | 已看详情图文/嵌入球桌或试打目标页；暂停与模式只按截图状态核对，不推断动作成功。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P15a-10](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/se/detail-to-tryout.png) · se · detail-to-tryout | contact-sheet | 已看详情图文/嵌入球桌或试打目标页；暂停与模式只按截图状态核对，不推断动作成功。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P15a-11](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r3/ipad/detail-2d-landscape.png) · ipad · detail-2d-landscape | contact-sheet | 已看详情图文/嵌入球桌或试打目标页；暂停与模式只按截图状态核对，不推断动作成功。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P15a-12](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r3/ipad/detail-2d.png) · ipad · detail-2d | contact-sheet | 已看详情图文/嵌入球桌或试打目标页；暂停与模式只按截图状态核对，不推断动作成功。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P15a-13](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r3/ipad/detail-3d.png) · ipad · detail-3d | contact-sheet | 已看详情图文/嵌入球桌或试打目标页；暂停与模式只按截图状态核对，不推断动作成功。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P15a-14](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r3/ipad/detail-paused.png) · ipad · detail-paused | contact-sheet | 已看详情图文/嵌入球桌或试打目标页；暂停与模式只按截图状态核对，不推断动作成功。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P15a-15](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r3/ipad/detail-portrait-return.png) · ipad · detail-portrait-return | contact-sheet | 已看详情图文/嵌入球桌或试打目标页；暂停与模式只按截图状态核对，不推断动作成功。 本图未新增可确定的视觉偏差；不等于全功能验收。 |
| [P15a-16](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r3/ipad/detail-to-tryout.png) · ipad · detail-to-tryout | contact-sheet, original | 已看详情图文/嵌入球桌或试打目标页；暂停与模式只按截图状态核对，不推断动作成功。 明确问题：P15a-S01。 |

## 证据缺口与后续验收

未运行播放、暂停、2D/3D切换和旋转恢复。未给浅/深及最大辅助字号同状态样本；详情→试打iPad必须补正，当前final-r3交付图不代表后续轮次已修复。

本轮仅生成报告与覆盖清单，未修改App、原图、用户审批或共享任务状态。
