# P04 思路训练 · 每日标准逐功能复审

评审日期：2026-10-09。审阅者：GPT-6-astra（B组）。仅审阅，未改生产代码，未启动模拟器，未执行动态交互、构建或测试。

## 范围与结论

已目视 28/28 张记录，无未看图；逐图方法、证据路径、既有用户状态见 [output/table-page-adaptation/standards-audit-20261009/coverage-P04.json](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/coverage-P04.json)。联系表每6图一页；提出问题的代表图使用原尺寸crop复核。

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

### P04-S01 · 普通状态提示仍为黑色胶囊，且固定位置未避开iPad上中袋

- 分类：既有标准偏差；P2（影响一致性/信息理解；无运行阻断证据）。
- 可见事实与边界：普通操作/恢复状态和常驻解参数共用黑色30%胶囊、微号字；前者无ⓘ。iPad横屏提示条与上中袋发生重叠，原尺寸局部已复核。本页常驻解参数有业务价值，应与普通通知分流，而不是全部定时消失。
- 标准依据：docs/design/daily-clearance/每日清台设计规范.md DC19、DC20；docs/design/daily-clearance/基础布局与自适应标准.md BL09；tasks/table-page-adaptation/CORE-TEMPLATE-C56.md 提示复用
- 当前源码静态定位：QiuJi/Features/PositionPlay/Views/SiluTrainerView.swift:24；QiuJi/Core/Components/BTTeachingTablePage.swift:163–168。截图可能早于当前工作树，未以源码替代截图结论。
- 建议与影响范围：把普通通知接入dailyInformation式ⓘ白字无底板、统一上方位置；常驻解参数保持必要信息，位置按有效桌面/安全区计算，不固定stage顶部36pt。
- 截图：[P04-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P04/r01/final-r8/phone/silu-2d.png)；[P04-21](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P12/r01/final-r4/orientation-regression/silu-2d.png)
- 原尺寸复核：[P04-01-top](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/B-P04-01-top.png)；[P04-21-top](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/B-P04-21-top.png)

### P04-S02 · 主击球和迷你打点槽未取当前模板的尺寸参数

- 分类：既有标准偏差；P2（影响一致性/信息理解；无运行阻断证据）。
- 可见事实与边界：源码在已使用DailyLayoutMetrics.Foundation的相同容器中仍把主动作写死52pt，迷你打点槽沿用44pt默认值。模板Foundation分支strikeSize=60；topDiameter有48/56容量档。差异是源码pt证据，不是PNG像素等于pt；不把教学左侧44pt辅助按钮一并判错。
- 标准依据：docs/design/daily-clearance/每日清台设计规范.md DC07–10；docs/design/daily-clearance/基础布局与自适应标准.md BL04–08；tasks/table-page-adaptation/CORE-TEMPLATE-C56.md 当前组件尺寸
- 当前源码静态定位：QiuJi/Core/Components/BTTeachingTablePage.swift:111–115、151–156、355–359；QiuJi/Core/Components/BTShotInstrumentColumn.swift:47、77–79；QiuJi/Features/PositionPlay/Views/DailyLayoutMetrics.swift:89–90；DailyLayoutMetrics.swift:186–198（roomy/144/120容量档）。截图可能早于当前工作树，未以源码替代截图结论。
- 建议与影响范围：主动作/迷你盘用Foundation实际容量参数并同窗对比；标准手机与iPad有足够现成60列，优先恢复主次层级。紧凑窗口另按容量档验收，不机械放大到溢出。
- 截图：[P04-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P04/r01/final-r8/phone/silu-2d.png)
- 原尺寸复核：[P04-01-right](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/B-P04-01-right.png)

### P04-S03 · 临时2D主动作禁用后仍呈可用白字

- 分类：既有标准偏差；P2（影响一致性/信息理解；无运行阻断证据）。
- 可见事实与边界：临时2D截图中主击球仍白字，而当前源码disabled包含temporaryTopDownActive，opacity只包含primaryEnabled。截图证明外观，源码证明禁用分支；未实际点击验证。
- 标准依据：docs/design/daily-clearance/每日清台设计规范.md DC12/C54 启用/禁用状态一致
- 当前源码静态定位：QiuJi/Core/Components/BTTeachingTablePage.swift:151–156（共用主按钮）；QiuJi/Features/PositionPlay/Views/SiluTrainerView.swift 操作区。截图可能早于当前工作树，未以源码替代截图结论。
- 建议与影响范围：用同一有效可用条件驱动disabled和外观/无障碍；若未来授权临时2D击打，需整体改交互合同而不是只放亮。
- 截图：[P04-10](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P04/r01/final-r8/phone/silu-temporary2d.png)
- 原尺寸复核：[P04-10-right](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/B-P04-10-right.png)

### P04-S04 · 四字标题硬换行；隐藏菜单/多解入口缺可发现性

- 分类：用户新增要求；P2（影响一致性/信息理解；无运行阻断证据）。
- 可见事实与边界：「思路/训练」源码强制两行13；摆球Menu与普通单击按钮同样44方框；下一解是普通Button，没有长按多解入口。
- 标准依据：tasks/table-page-adaptation/CORE-TEMPLATE-C56.md 现行单行15/双行13；2026-10-09用户新增标题及长按规则
- 当前源码静态定位：QiuJi/Features/PositionPlay/Views/SiluTrainerView.swift:20、99–109。截图可能早于当前工作树，未以源码替代截图结论。
- 建议与影响范围：四字先按单行排版；菜单增加可发现提示，保留点击可用性。多解长按属于新增能力，不能只改外观暗示不存在的操作。
- 截图：[P04-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P04/r01/final-r8/phone/silu-2d.png)
- 原尺寸复核：[P04-01-top](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/B-P04-01-top.png)

### P04-S05 · 开球方向尺与杆速尺使用不同宽高合同

- 分类：既有标准偏差；P2（影响一致性/信息理解；无运行阻断证据）。
- 可见事实与边界：方向尺调用仅frame44宽，BTAimWheel.visibleWidth默认nil取容器宽，因此有效尺体44；右侧compactPowerBarWidth=32。方向尺独立高度min176，与Foundation144/120有效尺长、顶部打点槽未成对齐组。
- 标准依据：docs/design/daily-clearance/每日清台设计规范.md DC07/08；docs/design/daily-clearance/基础布局与自适应标准.md BL06 双尺有效宽32及配对
- 当前源码静态定位：QiuJi/Features/PositionPlay/Views/SiluTrainerView.swift:89–94；QiuJi/Core/Components/BTAimWheel.swift:31、55、82；QiuJi/Core/Components/BTTeachingTablePage.swift:355–359。截图可能早于当前工作树，未以源码替代截图结论。
- 建议与影响范围：开球分支使用同一Foundation尺长、32有效宽和成对上下槽；SE14也属于该分支，不从单张相机朝向推断开球动态错误。
- 截图：[P04-04](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P04/r01/final-r8/phone/silu-break-ready.png)；[P04-14](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P04/r01/final/se/silu-break-ready.png)
- 原尺寸复核：[P04-04-top](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/B-P04-04-top.png)

### P04-S06 · 增加新球后不会显式退出落区/点约束工具

- 分类：用户新增要求；P2（影响一致性/信息理解；无运行阻断证据）。
- 可见事实与边界：截图只能看到编辑工具外观；静态placeFromPalette两入口都添加球、刷新与失效解，没有activeTool=.none。处在非摆球工具时新增球后可能继续该工具，符合用户指出的状态缺口。
- 标准依据：2026-10-09 P04-01第3条；tasks/table-page-adaptation/CORE-TEMPLATE-C56.md 保留功能动作语义
- 当前源码静态定位：QiuJi/Features/PositionPlay/ViewModels/SiluTrainerViewModel.swift:250–260、276–297；同文件:504–519（invalidateSolutions/resetParamDisplay也未更改activeTool）。截图可能早于当前工作树，未以源码替代截图结论。
- 建议与影响范围：点击和拖入新增球统一切回摆球；仅定位/脉冲既有球不应无条件改变工具。未运行手势测试。
- 截图：[P04-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P04/r01/final-r8/phone/silu-2d.png)
- 原尺寸复核：[P04-01-top](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/B-P04-01-top.png)

### P04-S07 · 解说明过长且打点展开仍压着说明

- 分类：既有标准偏差；P2（影响一致性/信息理解；无运行阻断证据）。
- 可见事实与边界：原尺寸P04-09中整条解说明横跨打点卡上沿，文字与半透明卡交叠。截短到不吃库是用户新增要求；展开打点时普通提示抑制/避让属于现行标准。
- 标准依据：docs/design/daily-clearance/每日清台设计规范.md DC19 展开态信息让位；2026-10-09 P04-02
- 当前源码静态定位：QiuJi/Features/PositionPlay/Views/SiluTrainerView.swift:24–30；QiuJi/Core/Components/BTTeachingTablePage.swift:163、180；QiuJi/Features/PositionPlay/ViewModels/SiluTrainerViewModel.swift:703–712。截图可能早于当前工作树，未以源码替代截图结论。
- 建议与影响范围：打点展开时隐藏非必要通知；解摘要按用户指定保留到库数/不吃库，内部求解难度/容错数据不删除。
- 截图：[P04-09](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P04/r01/final-r8/phone/silu-spin.png)；[P04-19](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P04/r01/final/se/silu-spin.png)
- 原尺寸复核：[P04-09-center](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/B-P04-09-center.png)

### P04-S08 · 3D/临时2D编辑能力需按新增要求扩展

- 分类：用户新增要求；P2（影响一致性/信息理解；无运行阻断证据）。
- 可见事实与边界：用户P05-05明确要求思路训练等同类页支持3D及临时2D摆球/落区。本页工具仍按3D禁用，共用planning.overlay还排除临时2D，球库新增也禁3D。截图只显示状态，能力范围由源码静态门禁支持。
- 标准依据：2026-10-09 P05-05跨页新增要求
- 当前源码静态定位：QiuJi/Features/PositionPlay/Views/SiluTrainerView.swift:99–103；QiuJi/Core/Components/BTTeachingTablePage.swift:124–128、399–427。截图可能早于当前工作树，未以源码替代截图结论。
- 建议与影响范围：将编辑模式、相机手势和临时投影能力一起设计；不能只删除disabled使按钮看似可用。功能扩展未经运行验证。
- 截图：[P04-01](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P04/r01/final-r8/phone/silu-2d.png)；[P04-10](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P04/r01/final-r8/phone/silu-temporary2d.png)
- 原尺寸复核：[P04-01-top](/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/standards-audit-20261009/B-P04-01-top.png)

## 用户意见逐条回应

**P04-01** 原话：

> 1. 思路训练四个字一行放不下吗？
> 2. 像摆球这种，里面藏了其他按键的，样式需要调整下，能够体现出，它是可以长按的，需要和其他的只能点击的有些区别；
> 3. 当处于非摆球状态时，如果用户从球库中增加了新球，那么应该自动变成摆球模式；
> 4. 对于多解的情况，也要做成支持长按的样式
> 5. 怎么感觉击球按钮变小了呢；
> 6. 其他的地方一起检查

逐条：①同意单行优先（S04）；②菜单可发现性同意，但现为可点击Menu，不是已存在的长按专用入口（S04）；③静态路径支持自动回摆球缺口（S06）；④下一解目前普通Button，新增长按选择能力再给相应外观（S04）；⑤源码52pt确认比模板Foundation60pt小（S02）；⑥全28图已看，新增提示/盘/禁用外观见S01/S03/S07。

**P04-02** 原话：

> 1. 解的文字提示不要那么长，到不吃库就行，后面的都不需要

同意短摘要到不吃库。属用户新增信息减量，不回溯成旧业务错误；见S07。

**P04-04** 原话：

> 方向条样式不对

同意。有效宽44/32与独立尺长有源码证据，见S05。

**P04-14** 原话：

> 开球时

结合P04-04理解为SE开球方向条，同一分支问题成立。截图不足以证明击球动力学/相机运动问题。

## 新发现与证据缺口

本次并未只审用户意见图：新增发现为P04-S01、P04-S02、P04-S03、P04-S05、P04-S07。

未运行：点击/长按/手势、3D编辑和临时2D退出恢复、弹层点击透传、精确边界触控、动态字号、VoiceOver、主题切换。图集未覆盖全部更多子层与全部状态的Light/Dark配对；这些列为证据缺口，不判为实际故障。没有新增页面或删改旧通过状态。

跨页共用源码的结论仍需主控按同一原图独立核验。本文建议不构成生产实施授权。
