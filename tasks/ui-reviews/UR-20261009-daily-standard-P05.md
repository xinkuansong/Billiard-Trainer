# P05 打一走二想三 · 每日标准逐功能复审

评审日期：2026-10-09。审阅者：GPT-6-astra（B组）。仅审阅，未改生产代码，未启动模拟器，未执行动态交互、构建或测试。

## 范围与结论

已目视 29/29 张记录，无未看图；逐图方法、证据路径、既有用户状态见 [output/table-page-adaptation/standards-audit-20261009/coverage-P05.json](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/coverage-P05.json)。联系表每6图一页；提出问题的代表图使用原尺寸crop复核。

设备与状态（逐图完整列表在coverage）：ipad, phone, se；包括原索引所列横屏、3D/临时2D及iPad状态；不把缺失状态当已验证。

确认/候选问题 8 项，均P2：视觉一致性、信息负担或新增需求；没有足够实测证据将行为问题提升为P1。

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

### P05-S01 · 普通状态提示仍为黑色胶囊，且固定位置未避开iPad上中袋

- 分类：既有标准偏差；P2（影响一致性/信息理解；无运行阻断证据）。
- 可见事实与边界：普通操作/恢复状态和常驻解参数共用黑色30%胶囊、微号字；前者无ⓘ。iPad横屏提示条与上中袋发生重叠，原尺寸局部已复核。本页常驻解参数有业务价值，应与普通通知分流，而不是全部定时消失。
- 标准依据：docs/design/daily-clearance/每日清台设计规范.md DC19、DC20；docs/design/daily-clearance/基础布局与自适应标准.md BL09；tasks/table-page-adaptation/CORE-TEMPLATE-C56.md 提示复用
- 当前源码静态定位：QiuJi/Features/PositionPlay/Views/PlanThreeView.swift:24；QiuJi/Core/Components/BTTeachingTablePage.swift:163–168。截图可能早于当前工作树，未以源码替代截图结论。
- 建议与影响范围：把普通通知接入dailyInformation式ⓘ白字无底板、统一上方位置；常驻解参数保持必要信息，位置按有效桌面/安全区计算，不固定stage顶部36pt。
- 截图：[P05-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P05/r01/final-r2/phone/planthree-2d.png)；[P05-21](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/orientation-regression/planthree-2d.png)
- 原尺寸复核：[P05-01-top](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/B-P05-01-top.png)；[P05-21-extra](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/B-P05-21-extra.png)

### P05-S02 · 主击球和迷你打点槽未取当前模板的尺寸参数

- 分类：既有标准偏差；P2（影响一致性/信息理解；无运行阻断证据）。
- 可见事实与边界：源码在已使用DailyLayoutMetrics.Foundation的相同容器中仍把主动作写死52pt，迷你打点槽沿用44pt默认值。模板Foundation分支strikeSize=60；topDiameter有48/56容量档。差异是源码pt证据，不是PNG像素等于pt；不把教学左侧44pt辅助按钮一并判错。
- 标准依据：docs/design/daily-clearance/每日清台设计规范.md DC07–10；docs/design/daily-clearance/基础布局与自适应标准.md BL04–08；tasks/table-page-adaptation/CORE-TEMPLATE-C56.md 当前组件尺寸
- 当前源码静态定位：QiuJi/Core/Components/BTTeachingTablePage.swift:111–115、151–156、355–359；QiuJi/Core/Components/BTShotInstrumentColumn.swift:47、77–79；QiuJi/Features/PositionPlay/Views/DailyLayoutMetrics.swift:89–90；DailyLayoutMetrics.swift:186–198（roomy/144/120容量档）。截图可能早于当前工作树，未以源码替代截图结论。
- 建议与影响范围：主动作/迷你盘用Foundation实际容量参数并同窗对比；标准手机与iPad有足够现成60列，优先恢复主次层级。紧凑窗口另按容量档验收，不机械放大到溢出。
- 截图：[P05-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P05/r01/final-r2/phone/planthree-2d.png)
- 原尺寸复核：[P05-01-right](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/B-P05-01-right.png)

### P05-S03 · 临时2D主动作禁用后仍呈可用白字

- 分类：既有标准偏差；P2（影响一致性/信息理解；无运行阻断证据）。
- 可见事实与边界：临时2D截图中主击球仍白字，而当前源码disabled包含temporaryTopDownActive，opacity只包含primaryEnabled。截图证明外观，源码证明禁用分支；未实际点击验证。
- 标准依据：docs/design/daily-clearance/每日清台设计规范.md DC12/C54 启用/禁用状态一致
- 当前源码静态定位：QiuJi/Core/Components/BTTeachingTablePage.swift:151–156（共用主按钮）；QiuJi/Features/PositionPlay/Views/PlanThreeView.swift 操作区。截图可能早于当前工作树，未以源码替代截图结论。
- 建议与影响范围：用同一有效可用条件驱动disabled和外观/无障碍；若未来授权临时2D击打，需整体改交互合同而不是只放亮。
- 截图：[P05-09](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P05/r01/final-r2/phone/planthree-temporary2d.png)；[P05-19](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P05/r01/final-r2/se/planthree-temporary2d.png)；[P05-28](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/orientation-regression/planthree-temporary2d.png)
- 原尺寸复核：[P05-09-extra](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/B-P05-09-extra.png)

### P05-S04 · 六字标题2+4断行、计划/落区菜单及求解图标需统一

- 分类：用户新增要求；P2（影响一致性/信息理解；无运行阻断证据）。
- 可见事实与边界：当前标题「打一/走二想三」为2+4；计划/落区菜单无展开标志。P05求解sparkles触发计算，而P07同名target是模式切换，不能仅为图标一致而混淆语义。
- 标准依据：2026-10-09 P05-01及最新全局标题规则
- 当前源码静态定位：QiuJi/Features/PositionPlay/Views/PlanThreeView.swift:20、99–109、161起；QiuJi/Features/AngleTraining/Views/SolverStageChrome.swift:223。截图可能早于当前工作树，未以源码替代截图结论。
- 建议与影响范围：按用户六字两行要求3+3排；菜单标明可展开/长按；区分求解动作与求解模式后统一相同语义的图标。
- 截图：[P05-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P05/r01/final-r2/phone/planthree-2d.png)
- 原尺寸复核：[P05-01-top](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/B-P05-01-top.png)

### P05-S05 · 3D及临时2D摆球/落区能力仍受多层阻断

- 分类：用户新增要求；P2（影响一致性/信息理解；无运行阻断证据）。
- 可见事实与边界：P05反馈要求把编辑能力扩展到3D及临时2D；现工具在cameraMode为3D时禁用，角色选择也禁用，共用planning.overlay仅在非3D且非临时2D显示，球库添加也禁3D。静态路径支持缺口，未运行触摸。
- 标准依据：2026-10-09 P05-05；tasks/table-page-adaptation/CORE-TEMPLATE-C56.md 临时2D与3D交互合同
- 当前源码静态定位：QiuJi/Features/PositionPlay/Views/PlanThreeView.swift:99–103、161起；QiuJi/Core/Components/BTTeachingTablePage.swift:124–128、301–335、399–427；QiuJi/Features/PositionPlay/ViewModels/SiluTrainerViewModel.swift:250–260；QiuJi/Features/PositionPlay/ViewModels/PlanThreeViewModel.swift:403–431。截图可能早于当前工作树，未以源码替代截图结论。
- 建议与影响范围：先明确操作矩阵：普通3D的相机手势与摆球/落区互斥进入编辑，临时2D投影编辑需开放对应节点和约束overlay；本组P04/P06同类门禁一并检查，不能只去掉按钮disabled。
- 截图：[P05-05](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P05/r01/final-r2/phone/planthree-replayed.png)；[P05-09](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P05/r01/final-r2/phone/planthree-temporary2d.png)
- 原尺寸复核：[P05-01-top](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/B-P05-01-top.png)

### P05-S06 · 开球时仍显示旧计划角色，打点展开时两条文字压住盘

- 分类：既有标准偏差；P2（影响一致性/信息理解；无运行阻断证据）。
- 可见事实与边界：开球新球架上方仍显示①球1/②球2/③球3角色摘要；打点展开P05-18恢复通知和角色摘要穿过盘上部。旧角色不一定被错误执行，但在不同任务状态继续可见会混淆。
- 标准依据：docs/design/daily-clearance/每日清台设计规范.md DC19 信息去重、展开态让位；tasks/table-page-adaptation/CORE-TEMPLATE-C56.md 按状态保留业务语义
- 当前源码静态定位：QiuJi/Features/PositionPlay/Views/PlanThreeView.swift:24–30；QiuJi/Core/Components/BTTeachingTablePage.swift:163、180。截图可能早于当前工作树，未以源码替代截图结论。
- 建议与影响范围：开球时抑制与当前模式无关角色摘要；打点展开只保留确有需要且不覆盖盘的读数。
- 截图：[P05-03](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P05/r01/final-r2/phone/planthree-break.png)；[P05-13](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P05/r01/final-r2/se/planthree-break.png)；[P05-18](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P05/r01/final-r2/se/planthree-spin.png)
- 原尺寸复核：[P05-03-top](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/B-P05-03-top.png)；[P05-18-center](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/B-P05-18-center.png)

### P05-S07 · 清台完成消息出现方框问号字形

- 分类：既有标准偏差；P2（影响一致性/信息理解；无运行阻断证据）。
- 可见事实与边界：原尺寸截图「清台完成」后显示带问号方框，无法呈现源码中的🎉。属于可见输出缺陷；不推定字体缓存等根因。
- 标准依据：.cursor/skills/swiftui-design-system/SKILL.md 图标/文案可读性
- 当前源码静态定位：QiuJi/Features/PositionPlay/ViewModels/PlanThreeViewModel.swift:864、1514–1515。截图可能早于当前工作树，未以源码替代截图结论。
- 建议与影响范围：采用稳定的SF Symbol成功符号或纯文案；最终设备复验字形。
- 截图：[P05-04](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P05/r01/final-r2/phone/planthree-cleared.png)；[P05-14](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P05/r01/final-r2/se/planthree-cleared.png)
- 原尺寸复核：[P05-04-top](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/B-P05-04-top.png)

### P05-S08 · 开球方向尺沿用44pt宽及独立高度

- 分类：既有标准偏差；P2（影响一致性/信息理解；无运行阻断证据）。
- 可见事实与边界：开球方向尺默认visibleWidth=nil取frame44，右侧杆速32；左尺独立min176高度，与右尺Foundation144/120容量档及上下槽不同。
- 标准依据：docs/design/daily-clearance/每日清台设计规范.md DC07/08；docs/design/daily-clearance/基础布局与自适应标准.md BL06
- 当前源码静态定位：QiuJi/Features/PositionPlay/Views/PlanThreeView.swift:89–94；QiuJi/Core/Components/BTAimWheel.swift:31、55、82；QiuJi/Core/Components/BTTeachingTablePage.swift:355–359。截图可能早于当前工作树，未以源码替代截图结论。
- 建议与影响范围：开球分支按同一Foundation配对尺长、有效32宽；保留计划业务按钮而不单边压缩尺体。
- 截图：[P05-03](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P05/r01/final-r2/phone/planthree-break.png)；[P05-13](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P05/r01/final-r2/se/planthree-break.png)；[P05-23](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/orientation-regression/planthree-break.png)
- 原尺寸复核：[P05-03-top](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/B-P05-03-top.png)

## 用户意见逐条回应

**P05-01** 原话：

> 1. 计划已选齐这个按键加一个可长按的样式；
> 2. 落区的也是；
> 3. 把我们这些页面里的求解的图标样式统一下吧，现在好像不同的地方有不同的选择；
> 4. 6个字标题，两行
> 5. 打一的按键感觉有点小

逐条：①②同意菜单展开可发现性；③同语义图标应统一，但P07求解是模式开关需先分清；④同意6字两行，当前2+4应3+3（S04）；⑤52pt固定尺寸问题成立（S02）。

**P05-05** 原话：

> 这些按键，应该在3D模式，和3D模式下的临时2D都应该可以使用，像摆球，落区，等等，你来分析下，像思路训练等里面也需要支持

静态路径支持当前能力缺口；是用户新增能力范围，影响工具禁用、球库、节点选择、约束投影及相机手势，见S05。

## 新发现与证据缺口

本次并未只审用户意见图：新增发现为P05-S01、P05-S02、P05-S03、P05-S06、P05-S07、P05-S08。

未运行：点击/长按/手势、3D编辑和临时2D退出恢复、弹层点击透传、精确边界触控、动态字号、VoiceOver、主题切换。图集未覆盖全部更多子层与全部状态的Light/Dark配对；这些列为证据缺口，不判为实际故障。没有新增页面或删改旧通过状态。

跨页共用源码的结论仍需主控按同一原图独立核验。本文建议不构成生产实施授权。
