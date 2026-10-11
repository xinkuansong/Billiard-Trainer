# P02 自由击球 · 每日标准逐功能复审

评审日期：2026-10-09。审阅者：GPT-6-astra（B组）。仅审阅，未改生产代码，未启动模拟器，未执行动态交互、构建或测试。

## 范围与结论

已目视 48/48 张记录，无未看图；逐图方法、证据路径、既有用户状态见 [output/table-page-adaptation/standards-audit-20261009/coverage-P02.json](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/coverage-P02.json)。联系表每6图一页；提出问题的代表图使用原尺寸crop复核。

设备与状态（逐图完整列表在coverage）：ipad, phone, se；包括原索引所列横屏、3D/临时2D及iPad状态；不把缺失状态当已验证。

确认/候选问题 2 项，均P2：视觉一致性、信息负担或新增需求；没有足够实测证据将行为问题提升为P1。

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

### P02-S01 · 开球停稳的完成/重开未形成桌心处置组

- 分类：用户新增要求；P2（影响一致性/信息理解；无运行阻断证据）。
- 可见事实与边界：说明已是顶部ⓘ白字无底板；重开仍在左上，完成仍占右下击球位。此处审的是开球停稳处置，不是主动重开/放弃进度的确认卡。
- 标准依据：docs/design/daily-clearance/每日清台设计规范.md DC20/C38；CURRENT.md「说明上方、动作桌心」
- 当前源码静态定位：QiuJi/Features/PositionPlay/Views/FreePlayView.swift:1793–1818、1836起、1952、2014。截图可能早于当前工作树，未以源码替代截图结论。
- 建议与影响范围：保留顶部说明，停稳时以独立桌心动作组提供完成/重开；不恢复整块有底板提示。涉及15球和9球开球分支。
- 截图：[P02-19](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P02/r01/final/phone/settled-15-2d.png)；[P02-20](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P02/r01/final/phone/settled-9-2d.png)；[P02-37](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P02/r01/final/se/settled-15-2d.png)；[P02-38](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P02/r01/final/se/settled-9-2d.png)
- 原尺寸复核：[P02-19-top](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/B-P02-19-top.png)；[P02-19-right](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/B-P02-19-right.png)

### P02-S02 · 和局结果重复显示两次

- 分类：既有标准偏差；P2（影响一致性/信息理解；无运行阻断证据）。
- 可见事实与边界：常驻比分胶囊与下方提示均显示「和局(0:0)」。比分本身有业务意义，问题是同一结果重复。
- 标准依据：docs/design/daily-clearance/每日清台设计规范.md DC19 信息去重、场景提示；DC20说明语义
- 当前源码静态定位：QiuJi/Features/PositionPlay/Views/FreePlayView.swift:1798–1802、954–985。截图可能早于当前工作树，未以源码替代截图结论。
- 建议与影响范围：终局时保留一个明确结果说明；比分胶囊和结果文案去重，不应据此删除对局中的比分模块。
- 截图：[P02-10](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P02/r01/final/phone/continued-shot.png)
- 原尺寸复核：[P02-10-top](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/B-P02-10-top.png)

## 用户意见逐条回应

**P02-19** 原话：

> 开球的完成和重开，按照每日清台里的按键提示吧

同意。说明已经符合ⓘ无底板，缺的是完成/重开的桌心动作组；见S01。

## 新发现与证据缺口

本次并未只审用户意见图：新增发现为P02-S02。

未运行：点击/长按/手势、3D编辑和临时2D退出恢复、弹层点击透传、精确边界触控、动态字号、VoiceOver、主题切换。图集未覆盖全部更多子层与全部状态的Light/Dark配对；这些列为证据缺口，不判为实际故障。没有新增页面或删改旧通过状态。

跨页共用源码的结论仍需主控按同一原图独立核验。本文建议不构成生产实施授权。
