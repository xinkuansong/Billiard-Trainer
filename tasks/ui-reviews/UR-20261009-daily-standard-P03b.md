# P03b 试打 · 每日标准逐功能复审

评审日期：2026-10-09。审阅者：GPT-6-astra（B组）。仅审阅，未改生产代码，未启动模拟器，未执行动态交互、构建或测试。

## 范围与结论

已目视 14/14 张记录，无未看图；逐图方法、证据路径、既有用户状态见 [output/table-page-adaptation/standards-audit-20261009/coverage-P03b.json](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/coverage-P03b.json)。联系表每6图一页；提出问题的代表图使用原尺寸crop复核。

设备与状态（逐图完整列表在coverage）：phone, se；本页仅手机/SE，无iPad截图。

确认/候选问题 1 项，均P2：视觉一致性、信息负担或新增需求；没有足够实测证据将行为问题提升为P1。

## 标准适用矩阵

| 域 | 本页适用性与检查结果 |
|---|---|
| 标题 | 适用；正常单行15/双行13与紧凑档；10-09新单行优先/均分规则单独归类。 |
| 安全区/桌面 | 适用；未见明确刘海或系统状态栏遮住主操作；不以缩略图估算pt/内框比例。iPad朝向按图核。 |
| 球库 | 适用；15目标球槽及已在桌状态保留；母球槽按业务差异保留。未见本组图确定的丢槽。 |
| 双尺/主动作 | 按状态适用；未提供方向微调的求解页不强加方向尺。自由/开球配对尺检查标准宽高。 |
| 打点盘 | 适用；迷你槽与展开盘分开检查，展开盘保持在有效布面；只读序列允许显示只读盘。 |
| 普通动作 | 适用；中性轻底/白字，启用禁用语义一致；黑24%底不是违规彩底。 |
| 相机/临时2D | 适用；四视角显示与组位置已目视，手势/观察保持只用源码支持，不作运行结论。 |
| 更多/子菜单 | 适用；有展开截图的只核该层；未展开子菜单/透明度滚动/点击透传列证据缺口。 |
| 信息/决策/结果 | 适用；DC20/C38优先于DC19旧居中句；普通ⓘ无底板，带动作说明上方动作桌心；主动重开确认卡保留磨砂底。 |
| 主题/阅读 | 场景深色HUD为标准例外。未有成对Light/Dark宿主状态，不据暗图宣称主题不跟随；试打简报属于阅读内容，保留业务结构。 |
| 状态/恢复/可发现性 | 适用；重打/回放图能证明静态恢复结果，不能证明全部数据恢复正确；长按可发现性为新增要求。 |

权威覆盖：[tasks/table-page-adaptation/CORE-TEMPLATE-C56.md](/Users/song/projects/13.billiard_trainer/tasks/table-page-adaptation/CORE-TEMPLATE-C56.md) → [docs/design/daily-clearance/每日清台设计规范.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/每日清台设计规范.md) DC19/DC20与后续C38/B6 → [docs/design/daily-clearance/基础布局与自适应标准.md](/Users/song/projects/13.billiard_trainer/docs/design/daily-clearance/基础布局与自适应标准.md) BL01–10；[docs/design/feedback/提示与弹窗规范.md](/Users/song/projects/13.billiard_trainer/docs/design/feedback/提示与弹窗规范.md) 后半用户修订。新需求不倒推旧验收错误。

## 问题清单

### P03b-S01 · 试打简报分类标签绿字落在绿色台布玻璃上

- 分类：既有标准偏差；P2（影响一致性/信息理解；无运行阻断证据）。
- 可见事实与边界：局面目标/训练重点/参考打法的绿色分类标签明显弱于相邻白色正文；原尺寸局部确认背景透出台布，降低识别。这里是可阅读简报，不是应限时消失的普通提示。
- 标准依据：docs/design/daily-clearance/每日清台设计规范.md DC12场景文字白色；.cursor/skills/swiftui-design-system/SKILL.md 场景HUD与可读性
- 当前源码静态定位：QiuJi/Features/PositionPlay/Views/DrillTryoutBrief.swift:130–152。截图可能早于当前工作树，未以源码替代截图结论。
- 建议与影响范围：保留结构化教学简报与必要底板，把标签换成场景白字层级或充分对比的文本样式；此报告未宣称数值对比度不达某一阈值。
- 截图：[P03b-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P03/r01/final/phone/tryout-brief.png)；[P03b-06](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P03/r01/final/phone/tryout-returned.png)；[P03b-08](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P03/r01/final/se/tryout-brief.png)；[P03b-13](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P03/r01/final/se/tryout-returned.png)
- 原尺寸复核：[P03b-01-top](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/B-P03b-01-top.png)

## 用户意见逐条回应

本页快照没有带文字的修改意见；所有已通过、未审记录同样纳入目视范围。

## 新发现与证据缺口

本次并未只审用户意见图：新增发现为P03b-S01。

未运行：点击/长按/手势、3D编辑和临时2D退出恢复、弹层点击透传、精确边界触控、动态字号、VoiceOver、主题切换。图集未覆盖全部更多子层与全部状态的Light/Dark配对；这些列为证据缺口，不判为实际故障。没有新增页面或删改旧通过状态。

跨页共用源码的结论仍需主控按同一原图独立核验。本文建议不构成生产实施授权。
