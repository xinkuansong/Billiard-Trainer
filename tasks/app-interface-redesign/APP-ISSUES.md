# 现有App问题与改进台账

2026-10-11；用户明确要求“现有app中不合理的，也要记录下来”。本台账记录原生现状的问题与有依据的改进建议；Figma复建误差仍归对应批次R项，两者互相链接。历史记录不等于本轮修复或用户批准；当前处理授权见下方D025。入口：[PLAN](PLAN.md)、[CURRENT](CURRENT.md)。

## 当前轮次：LIVE-20261012-R1（D025 / PLAN v5.1）

本轮重新开始，旧条目是复查线索，旧确认/修复/验收状态保留为历史，不自动代表本轮结果。复现旧问题时沿用APP-I编号并追加本轮子记录；新问题继续递增编号。每项本轮记录包含原话/图、基线、设备/方向/主题、实际与预期、根因/影响、修复、AI检查、交给用户的验证范围及用户结论。

正式执行中的明确缺陷已经获准修复，不逐项重复请示；新的视觉方向/业务规则取舍单独决定。用户确认后才关闭本轮问题，未通过继续修。Figma绑定仅是旧证据，不是本轮前置；下方v4衔接及旧问题说明为历史。

## v4.0 衔接

当前按D023/PLAN v4.0使用Figma原生图片图册驱动；评论绑定captureId/原图hash与版本，修后保留旧意见、标待复审。截图有效、Figma已导入、用户认可和问题已修分别记录。以下I001–I007保留原证据和未修状态；旧Wxx去向为历史，当前对应：I001/I003/I005/I007→N03，I002→N08，I004→N08，I006→N04。旧版本现象须在新基线复核；源码疑点不能直接算当前App缺陷。截图有效与问题关闭分计，Figma修订不再是问题修复前置。

## 1. 每页必做的检查

在读取原生基线与同态对比时检查：信息层级/文案理解、主要操作及点击区域、滚动/键盘/安全区/固定层、布局密度与跨尺寸、浅深色/跨页一致性、加载/空/错/禁用/忙碌反馈、返回与状态保持、可访问性。只对实际观察范围给结论：静态图可证明遮挡，不足以证明真实点击失效或读屏不可用。

每个页面族收口报告增加“App现状问题”栏：已检查范围、发现的APP-I编号、未检查部分。无充分证据的疑点标待验证，不写成确定bug；没有做检查写未检查，不能填“无问题”。源码与规范冲突可记文档问题，不冒充用户体验缺陷。

## 2. 一条问题要记什么

稳定编号`APP-I001…`；类型（缺陷/体验改进/一致性/可访问性/规范漂移）；P-ID/入口；发现版本与设备/窗口/主题/业务状态；原始截图或源码证据；实际现象；用户影响；期望或建议及其依据；确定程度；优先级与理由；是否需视觉/业务决定；关联Figma/任务；负责人；状态；修复版本与复验结论。

优先级：P0数据/核心流程严重不可用；P1高频核心操作受阻或关键信息不可读；P2局部易用性/一致性问题；P3可选精修。分级基于已知影响，点击/保存未测时注明暂定，不凭截图认定丢数据。主控统一归属，跨页同根因一条主问题＋消费者列表。

流程：待验证→证据确认→待设计决定或待实施授权→候选/已选→已修待验→已关闭。原生缺陷保留在现状参照，优化候选另区，不把问题当设计系统标准。每个包结束汇总；同一规则已获用户确认时后续直接复用，不逐页重新问。新的视觉/业务取舍先给具体可审查方案再提决定。

关闭必须有修后版本和原状态复验，必要时受影响消费者复验；“记录完成”“Figma修了”“测试跑了”都不能单独关App问题。

## 3. 当前条目

| ID | 页面/类型 | 现象与证据 | 影响/优先级 | 状态、建议与去向 |
|---|---|---|---|---|
| APP-I001 | P02自建空态；布局缺陷 | DS01 r8大屏Light原生核对确认“＋自由”与创建CTA区域遮挡；[r8报告](../../output/app-interface-redesign/DS01/r8/REPORT.md)中的U-01及原始原生图 | 两个操作的视觉辨识受影响；P2暂定，实际点击命中未在本次重验，若确认核心操作被阻提升P1 | **历史证据已确认，未修复**。现状保留，候选检查固定层/滚动安全区与空态CTA关系，避免只加魔法offset；W02记录具体候选，App实施另授权；U-01“来源疑点关闭”不等于本问题关闭 |
| APP-I002 | P31/P29；规范漂移 | 当前OnboardingView生产body L100强制dark，SubscriptionView当前body未见同样强制；旧UI-IMPLEMENTATION-SPEC§主题摘要称介绍light/订阅dark，与源不符；[源码核查](SOURCE-ANCHORS-v2.md) | 会使复建生成错误主题或错误验收；P2（维护风险），未证明App实际外观有缺陷 | **源码/旧摘要差异确认，运行主题待核**。W23/W22核真实启动链、当前原生和有效设计决定后修订规范依据；不在本轮改App主题 |
| APP-I003 | P02/P03共用模版卡；局部视觉缺陷 | r8原生大屏Light一卡、未安排、零历史：卡片白色背景纵向357px=119pt；封面顶12pt、边112pt，下沿124pt超过卡底，底部被裁约5pt。[原始截图](../../output/app-interface-redesign/DS01/r8/native/one-card-light-top.png)、[分析裁图](../../output/app-interface-redesign/DS01/r9/native-card-analysis-crop.png)；`BTDrillCard.swift`的`BTTemplateHeaderLayout`以文字决定父高，外层又clipShape，与现象一致 | 封面下圆角消失，卡片视觉规则不一致；P2局部视觉问题，不涉及已证实的点击/数据错误 | **现有原图与当前源码确认，未修复**。复建保留现状；优化候选可比较“卡高至少封面高+上下内边距”与“封面随文字有效高度缩小”，需展示同一卡有/无徽标、3/4/5行及小屏对比后决定；本轮不改App |

| APP-I004 | P26-02；维护残留/待核 | `TrainingGoalView.swift:83,111–117` reminderError仅见声明、读取及清空；本轮rg查本文件未见置入错误字符串 | 易把不可达alert计入已实现错误流程；P3维护风险，未证明用户可见故障 | **源码疑点，运行不可达性未作完整证明**。保留条件义务，W19核是否应移除残留或恢复真实触发；不强造错误状态、不改App |

| APP-I005 | P03；导航/覆盖维护疑点 | 冻结E14/r1/build-r2源码全仓仅有planList枚举、destination及恢复ID；未搜到进入planList的导航写入。r15原生首页更多菜单为训练心得/补记/提醒/帮助，无计划列表入口 | 可能把历史不可达页当当前覆盖任务，P3待核；未证明应删除或用户路径故障 | **入口疑点，未改App**。保留旧页面，查历史参照的进入方式并确认产品是否仍保留；不得为了通过核对注入路由后称正常可达。证据：[r15报告](../../output/app-interface-redesign/DS01/r15/REPORT.md) |

| APP-I006 | P09/P02；统计文案/完成口径待核 | r22正常UI建立8×15一卡，只启动计时、没有标记组或进球即结束；摘要“完成项目1/总组数8”且每组有勾，保存后今日全部完成、周训练+1。原始sample-summary-zero-recorded.png及Practice状态图；TrainingSummaryView.statsGrid使用drillCount/totalSets | 计划剂量与实际完成量容易混读，P2建议待核；计时训练是否允许不逐组记录属于产品决定，不直接断言数据错误 | **运行现象确认，业务期望待澄清，未修App**。W09/W11区分“本次训练包含/计划组数”和实际完成口径，展示候选后再决定 |

| APP-I007 | P02；自动化/可访问性标识维护 | r22相同模版保存一次后再加入今日安排，待练和已完成两行的accessibilityIdentifier都为trainingHome.scheduleItem.C53462D5-FF5C-4E51-962F-B7610079FABB，描述与状态不同；源码itemView按sourceId生成标识 | selector可能命中错误条目，P3；VoiceOver影响未验，不断言读屏故障 | **实际重复标识确认，未修App**。W02建议以schedule item唯一id构成标识并保留来源字段；修后测试分别选两条 |

历史DS01 R-01卡片高度、R-02内容/尾屏、R-03同态数据属于Figma/证据问题，保留[收口卡](batches/DS01-serial-closure.md)，不混入已确认原生缺陷数。普通Pad横向运行支持目前是验证缺口，不能直接记录为已证实App不支持。

## 4. 与方案、Figma的连接

- PLAN各W包DoD均包含本台账检查与更新；共用组件问题附全部消费者，后续优化优先评估一次修改的影响。
- Figma `98｜核对与差异`显示APP-I编号/截图/影响；`90｜优化候选`关联具体方案，不把待改原生问题混成复建误差。
- CURRENT仅摘要高优先级及下一动作，不重复维护完整问题正文。每次状态变化同步此处与所属任务卡，不新建孤立“最新问题清单”。

## 5. 版本

v1 / 2026-10-11：按用户要求建立全App现存问题记录机制；种子条目取自r8已有实证与本次源码核查，未重新运行App、未修代码。


## 6. 原生截图批次 N01/N02 新发现（2026-10-11）

来源 `output/app-native-audit/f75cbafd-r2/roots/review.json`，每项绑定原图 SHA 与实际 Figma 节点见导入映射。已记录，不等于已修复。

| ID | 页面/现象 | 范围、影响与证据 | 状态/下一步 |
|---|---|---|---|
| APP-I008 | P24 深色头像/登录卡仍为大块白底黑字 | 五窗口深色均可见，与其余深色卡片不一致；P2 视觉一致性候选。例 `roots/standard/portrait-dark/P24-default-top.png` | 现象确认；是否保留品牌白卡须设计决定，不断言文字不可读 |
| APP-I009 | P24 同屏“解锁球迹 Pro”与“Pro 已解锁，状态待刷新”并存 | 五窗口测试夹具均可见；本批使用 `-forcePremium`，P2 暂定 | **仅测试 override 下确认**；N08 分开真实免费/Pro 数据后再判断产品缺陷，不能外推真实付费账号 |
| APP-I010 | P14/P17/P24 首屏状态栏与 P02/P19 不一致 | 标准/大屏及 Pad 的时钟和系统图标不可见，训练/记录可见；小屏对应栏可见。两种主题均出现；P2 一致性疑点 | 原图现象确认；需核宿主的状态栏策略或自动化环境，未断言系统栏颜色 bug |
| APP-I011 | P02 Pad 周训练背景球体明显放大裁切，横屏更明显 | `roots/pad/landscape-light/P02-default-top.display.png`；原始 EXIF 横图保留；P3 裁图/跨宽度建议 | 待设计评审；属于实际原生布局，不对截图缩放重绘来掩盖 |

N01 空模版末屏已能看见“新建模版”，不能据首屏在固定栏下就认定无法操作。I001 历史大屏状态与本次不同，不凭这次图自动关闭。N01 Pad 横屏滚动后空态装饰上沿被固定头部裁切，先随截图评审；未证明功能受阻。小屏记录页空态 CTA 仍需真实滚动核对，列 N07 待补。

### APP-I005 补充核验（2026-10-11，N03 首轮）

“训练 → 更多 → 使用帮助 → 怎样安排今天的训练？ → 浏览训练计划”已在标准浅色模拟器实际打开 P03；因此旧记录“未找到正常入口”已被新证据补充，不应继续当成全局不可达。证据：`output/app-native-audit/f75cbafd-r3/plan-entry-preview/standard/portrait-light/P03-official-top.png` 与 AX。随后点 P03 的“新建”，5 秒后仍显示训练计划，返回按钮却标为“新建模版”，未出现 `customPlanNameField`；按真实入口异常待查，不能断言编辑器全局不可达。失败 xcresult/视频/AX 保留于同批目录。采集改从首页“我的模版 → 新建模版”正常入口继续，未修改 App 导航代码。

### APP-I012 补记训练空用时重复单位（2026-10-11，r8）

- **原图现象确认，P3文案/表单疑点，未修复**：标准402×874浅色，补记训练默认空表单的“训练用时”右侧同时显示“分钟 分钟”（占位与固定单位）。需评审占位是否应为数字示例；当前不改码也不后处理截图。
- 正常入口：训练→更多→补记训练。证据：`output/app-native-audit/f75cbafd-r8/training-preview/standard/portrait-light-training-manual-static/P11-default-scroll00.png`及同名AX/JSON。其余尺寸主题待矩阵；用户未验收。

### APP-I013 未记录成绩的课程结束后显示全部项目/组数已完成（2026-10-11，r8）

- **原图现象确认，P2口径待核，未改码**：正常开始基本功第1课，仅运行约3秒并暂停/恢复，没有任何记分或完成组操作；结束→跳过心得后，训练总结显示“完成项目2项”“总组数15组”，明细15组均0/15且绿色完成勾，分享预览亦记15组。需核实已完成与已安排口径，不以截图擅自决定统计语义。
- 独立内存夹具single只准备课程；状态流程、原图、AX及测试日志：`output/app-native-audit/f75cbafd-r8/training-retry-table/standard/portrait-light-session-plan-summary/`，重点`P08-03-summary-scroll00.png`及scroll01–04；尚未验证持久化或其他设备。

### APP-I014 小屏记录卡时间范围被拆行（2026-10-11，r9）

- **原图现象确认，P2局部可读性，未修复**：375×667浅色，有心得记录卡右侧的`19:30–20:15`被排成`19:30–20`与下一行`:15`，分钟与小时分离。标准402×874同fixture深色在单行，其他尺寸/主题待核；未证明点击或数据错误。
- 证据：`output/app-native-audit/f75cbafd-r9/matrix-small/small/portrait-light-history-populated/P19-populated-scroll01.png`与scroll02，联系图`small-review-part2/contact-375x667-000.jpg`。截图保留真实问题。后续修复候选应保留完整时间语义并检查长分类/多项标题挤压，不能通过改短测试数据规避。

### APP-I015 小屏免费统计页首屏升级按钮在可视区外（2026-10-11，r9）

- **原生现象确认，P2信息/操作发现性建议，未修复**：375×667浅色、有训练记录的免费状态，Pro提示纵向靠下，首屏说明受到底部Tab区域遮挡，解锁按钮需滚动后完整出现；已通过连续滚动看到完整按钮，因此不认定按钮不可达或点击失效。
- 证据：`output/app-native-audit/f75cbafd-r9/matrix-small/small/portrait-light-statistics-free/P20-free-populated-scroll00.png`与scroll01–05（实际路径以review-part3清单为准）。是否将升级提示放入首个可视区域需设计评审；不通过裁图或重排截图掩盖现状。

APP-I013与APP-I006为相同完成口径问题的新基线/课程场景补充证据，问题数量不重复累计；保留两个编号以维持既有截图引用。

2026-10-11 r9补验：APP-I014、APP-I015均在375×667深色同fixture复现，分别见`matrix-small/small/portrait-dark-history-populated/P19-populated-scroll01.png`及`portrait-dark-statistics-free/P20-free-populated-scroll00.png`；联系图`small-review-part4`。APP-I012分钟占位重复在标准深色亦出现（`matrix-standard/standard/portrait-dark-training-manual-static/P11-default-scroll00.png`）。仍未修复。

2026-10-11 r12补验：APP-I012空分钟重复也在440×956浅/深明确出现（r10/matrix-large/large/*-training-manual-static/P11-default-scroll00.png）。截图问题另列：Pad订阅弹层误滚背景为测试覆盖缺口，非App缺陷，原首屏有效但不算完整长页。

### APP-I016 统计平均训练时长与单位不一致（2026-10-11，r12）

- **原图与冻结源码确认，P2统计可读性，未修复**：标准402×874浅色，同一180分钟数据在月视图显示“0.8小时/月”，年视图显示“0.1小时/年”。冻结f75cbafd `StatisticsViewModel.averageDurationHoursPerPeriod` 月除4、年除52，实际归一成近似每周时长；`periodLabel`仍标小时/月、小时/年。数值和单位口径不一致。
- 证据：`output/app-native-audit/f75cbafd-r12/combined-preview/standard/portrait-light-statistics-periods/P20-pro-month-scroll00.png`、`P20-pro-year-scroll00.png`；ViewModel约200/380行，View约290行。
- 用户影响：可能把该区间训练频率读低4倍/52倍。建议评审统一为平均每周或改为当前区间总量，并核图中均值线口径；统计定义需产品确认。本轮只记录，其他尺寸与主题待矩阵补验。


### APP-I017 瞄准方法平行线示意图母球标签左侧裁切（2026-10-11，r13）

- **原生画面确认，P2局部教学可读性，未修复**：402×874深色、默认30°，P18-15“平行线瞄准法”图中左边母球位于图边缘，母球标签左侧文字被图的裁剪边界截去；相邻连续视口均可见，不是截图裁剪。图示关系仍可阅读，未据此认定教学几何计算错误。
- 证据：`output/app-native-audit/f75cbafd-r13/next-standard/standard/portrait-dark-reading-p18-15/P18-15-default-scroll08.png`；具体SHA与路径见同批`next-standard-review/review.json`、联系图004第三列及005第一列。
- 建议：后续修复批为图中标注预留边距或根据边界调整标签锚点，并复验极端角度及五窗口；本轮只保留问题。

2026-10-11 r13补验：APP-I016在Pad1210×834深色月/年图同样可见，`pad-review-part4`联系图122/127；统计单位问题未修复。

### APP-I018 登录首页长昵称与装饰球区域重叠（2026-10-11，r16）

- **原生夹具画面确认，P2布局疑点，未修复**：402×874浅色，冻结版本内置20字离线账号昵称在“我的”首页换成两行，第一行末尾与右侧9号装饰球的上缘相接/局部重叠。姓名没有为球体预留独立宽度。短昵称无此现象；其他尺寸主题继续核验，未据此认定账号数据丢失。
- 证据：`output/app-native-audit/f75cbafd-r16/pilot/standard/portrait-light-profile-longname-offline/P24-authenticated-longname-scroll00.png`，同名AX/元数据保留；原图SHA在`r16/pilot-review/review.json`。冻结`ProfileView.swift:128–153`的姓名VStack后接最小间隔Spacer，装饰球通过overlay绘制而不占布局宽度。
- fixture：现有`-v53.authenticatedProfileFixture -v53.longNicknameFixture`，走正常Root owner重建；APIClient拒绝真实网络，仅用于界面状态。建议后续修复批为装饰球保留真实布局宽度，并复核长昵称/字体与五窗口；当前只记录。

### APP-I019 部分理论长页滚动文字透过导航栏干扰标题（2026-10-11，r17）

- **原生视觉现象，P3待设计评审，未修复**：440×956浅色的母球速度分级、反向规划、关键球原理在中段滚动时，正文/图表透过顶部材质，与页标题、返回按钮及状态栏处在同一区域。标题仍可读，但背景干扰明显；相邻30°/90°/切线法则使用更平整的顶部遮罩，表现不一致。不是过渡帧，稳定帧检查已通过；未据此判断点击或数据故障。
- 证据：`output/app-native-audit/f75cbafd-r14/large-resume/large/portrait-light-reading-p18-05/P18-05-default-scroll03.png`；P18-06 scroll01与P18-07 scroll03同批可见。AI按正常逻辑尺寸逐张核对，r17/large-review-part2联系图86/90/95。
- 建议：后续设计评审比较统一导航背景/滚动边缘遮罩的候选，复验浅深和其他窗口；本轮只记录真实现状。

2026-10-11 r17补验：APP-I019在P18-08–14同样出现；瞄准原理P18-14-default-scroll01绿色球台图透过导航栏，绿色页标题对比度显著下降，升级为P2可读性问题（原记录保留）。证据位于r14/large-resume/large/portrait-light-reading-p18-14，同批联系图138。

### APP-I020 旋转打点示意图标注与球面打点重叠（2026-10-11，r17）

- **原生画面确认，P2图示可读性，未修复**：440×956浅色，P18-17“打点如何产生旋转”图内，高杆/低杆/左塞/右塞文字及圆点图例直接叠在母球打点和虚线环上，标签与定位点没有独立空间。不同滚动视口一致。
- 证据：`output/app-native-audit/f75cbafd-r14/large-resume/large/portrait-light-reading-p18-17/P18-17-default-scroll05.png`与scroll06；r17/large-review-part2联系图161/162。建议后续分离图例与球面标记并复验五窗口，本轮不改App。

### APP-I021 瞄准修正定性速查含低对比度内部技术注记（2026-10-11，r17）

- **原生画面确认，P3内容与可读性待评审，未修复**：440×956浅色，P18-16“定性速查”每行副注有`z1 CIT 慢>快`、`z1 bias 高>中`等内部草稿标记；灰色小字在白底上很淡。主说明可读，未量测对比度或判定WCAG符合性。
- 证据：`output/app-native-audit/f75cbafd-r14/large-resume/large/portrait-light-reading-p18-16/P18-16-default-scroll15.png`；r17/large-review-part2联系图157。建议后续确认这些技术标记是否面向普通用户，若保留则提供清楚解释和可读样式。

2026-10-11 r17 Pad补验：APP-I019在834×1210竖屏深色P18-05/06中段同样可见，正文透过顶部材质；证据r16/pad-resume/pad/portrait-dark-reading-p18-05/P18-05-default-scroll01.png及P18-06-default-scroll03.png，pad-review-part7联系图022/030。浅色P18-05–08也已逐图看到相同现象（pad-review-part6）。

### APP-I022 瞄准原理几何推导图公式叠在目标球上（2026-10-11，r17）

- **原生画面确认，P2图示可读性，未修复**：834×1210竖屏深色，P18-14“几何推导（速查）”中黄色`d = 2R·sin(θ)`横跨黄色目标球下部，与球面同色且和三角形标注集中，公式难辨。正文另有完整公式，未据此判断几何计算错误。
- 证据：`output/app-native-audit/f75cbafd-r16/pad-resume/pad/portrait-dark-reading-p18-14/P18-14-default-scroll03.png`及scroll04，`r17/pad-review-part7`联系图091/092。建议后续将尺寸公式移至球体外并为引线/角度保留空间，复验其他窗口；本轮保留原图。

2026-10-11 r17 Pad深色补验：APP-I020在834×1210的P18-17-default-scroll02/03仍可见图例覆盖球面标记；APP-I021在P18-16-default-scroll08/09中可见灰暗草稿技术注记。原图均位于r16/pad-resume/pad/portrait-dark-reading-p18-*，联系图118/119和113/114。P18-15平行线图在此Pad宽度未见APP-I017的左侧标签裁切，不代表手机问题已修复。

- 2026-10-11 r17 Pad浅色补证：APP-I022同样出现在`f75cbafd-r16/pad-resume/pad/portrait-light-reading-p18-14/P18-14-default-scroll03.png`与scroll04（part7联系图184/185）。APP-I019同页scroll01/04/05绿色导航标题在台面背景上对比不足；APP-I020见P18-17浅色scroll02/03（210/211）；APP-I021见P18-16浅色scroll08/09（205/206）。P18-15 Pad浅色未观察到手机上的左标签裁切，不能据此关闭APP-I017。均为原生现状记录，未修App。

- 2026-10-11 r17大屏深色补证：440×956同样出现APP-I019导航透字/绿底绿标题（P18-14 scroll01/05）、APP-I020旋转图例覆盖打点（P18-17 scroll04/05/06）、APP-I021技术注记过暗（P18-16 scroll13–15）、APP-I022公式叠球（P18-14 scroll05/06/07）。原图位于`f75cbafd-r14/large-resume/large/portrait-dark-reading-p18-*`，large-review-part3联系图070/072/073、092/093、088/089。未改生产App。


### APP-I023 iPad横屏知识页阅读栏宽度不一致（2026-10-11，r17）

- **原生视觉现象，P3待设计评审，未修复**：1210×834横屏，P18-02–04及P18-14–17主要正文居中约688pt宽；P18-05–13正文卡片接近全窗宽，长段落单行跨度明显更长。属于同一知识阅读域的布局一致性和阅读舒适性候选，未测用户阅读效率，不断言功能受阻。
- 证据：`output/app-native-audit/f75cbafd-r16/pad-resume/pad/landscape-light-reading-p18-06/P18-06-default-scroll00.png`（part8联系图066）与同批P18-14-default-scroll00（159）、P18-15-default-scroll00（172）；深色P18-05亦可见。截图以原生逻辑尺寸核对，原图未缩改。
- 建议：评审统一正文最大阅读宽度，图区是否放宽单独决定；后续修复批再实施，本轮只记录。

2026-10-11 r17横屏浅色补证：APP-I019在P18-14 scroll01/05/10仍有绿底绿标题；APP-I022公式叠球见scroll05–07；APP-I020见P18-17 scroll04–06；APP-I021见P18-16 scroll13–17。原图均在`f75cbafd-r16/pad-resume/pad/landscape-light-reading-p18-*`，part8联系图160/164–166/169、208–210、199–203。用户未验收，生产App未改。

2026-10-11 r17横屏深色补证：APP-I022公式叠球见P18-14 scroll05–07（part9联系图72–74）；APP-I020图例覆盖见P18-17 scroll04–06（117–119）；APP-I021灰暗内部注记见P18-16 scroll13–17（108–112）；APP-I023宽栏见P18-09至13，对照P18-14起居中窄栏。原图位于`f75cbafd-r16/pad-resume/pad/landscape-dark-reading-p18-*`；没有修生产App。


### APP-I024｜iPad 横屏确认弹出层与触发行相距较远

- **原图现象确认，P3操作关联性待评审，未修复**：1210×834 横屏深色，设置下部清除缓存和首页模版删除的确认浮层均出现在顶部中央；浮层箭头未指向实际触发行。模版删除在浅色也一致。正文可读、删除对象有名称，未认定功能无法使用；后续核确认弹层挂载位置与 iPad 锚定策略。
- 证据：`/Users/song/projects/13.billiard_trainer/output/app-native-audit/f75cbafd-r16/next-pad/pad/landscape-dark-settings-cache-confirm/P33-02-cache-confirm.display.png`。
- 证据：`/Users/song/projects/13.billiard_trainer/output/app-native-audit/f75cbafd-r16/next-pad/pad/landscape-dark-template-delete-confirm/P02-04-delete-confirm.display.png`。
- 证据：`/Users/song/projects/13.billiard_trainer/output/app-native-audit/f75cbafd-r16/next-pad/pad/landscape-light-template-delete-confirm/P02-04-delete-confirm.display.png`。

2026-10-11 r18小屏深色补证：APP-I017见P18-15 scroll10/11平行线图左侧母球标签；APP-I019见P18-14与18中段透字及绿底绿标题；APP-I020见P18-17 scroll08/09图例叠球；APP-I022见P18-14 scroll10/11公式叠球。原图位于`f75cbafd-r13/next-small/small/portrait-dark-reading-p18-*`，r18/small-review-part3全部128张已核对。未改生产App。

2026-10-11 r18补验：APP-I024也出现在Pad竖屏Light/Dark的清缓存与删除模版确认，顶部浮层与原按钮相距较远，证据`r16/next-pad/pad/portrait-{light,dark}-settings-cache-confirm`及`template-delete-confirm`；part2联系图005/009/019/023。另P05编辑模版列表底部直角裁断视觉需复查，固定List高度源码为每条80pt；只记录疑点，不声称功能故障。

2026-10-11 r18账号矩阵补证：APP-I018长昵称与装饰球重叠在375×667、440×956深浅均可见，原图`r16/account-phone-matrix/{small,large}/portrait-{light,dark}-profile-longname-offline/P24-authenticated-longname-scroll00.png`；APP-I024不限Pad，手机注销账号确认也浮在顶部，触发注销行仍在底部（同矩阵settings-account-offline/P33-03-delete-account-confirm.png）。全部为离线fixture；未执行注销，未修App。

### APP-I025 小屏模版编辑的动作名称明显截断（2026-10-11，r19）

- **原生现象，P3待评审，未修复**：375×667浅色，新建模版已选中袋直线出杆/底袋直线出杆，行内名称仅显示「中袋直…」「底袋直…」，右侧菜单和拖动柄之间仍有较多占位。两动作可由前段区分，但完整名称不可见；不能据此断言功能不可用。
- 证据：`output/app-native-audit/f75cbafd-r18/interaction-slot1/small/portrait-light-template-picker-selections/P05-01-new-with-drills.png`，r19/interaction-phone-review-part2联系图002。
- 后续评审动作行的缩略图/标题/菜单/拖动柄宽度分配与长名称规则，本轮不改App。

2026-10-11 r19交互补证：APP-I025小屏深色在`r18/interaction-slot1/small/portrait-dark-template-picker-selections/P05-01-new-with-drills.png`仍可见动作名称截断；大屏浅色与Pad可显示完整名称，不能关闭小屏问题。APP-I020在Pad横屏浅色后旋/前旋正文scroll04–06仍图例叠球，APP-I021在同环境高低杆正文scroll13–15仍有低对比技术注记（r19/interaction-tail-slot2/unique-content-review）。P18-18目标90°实拍89°单列为采集状态不达标，未登记为App缺陷。

### APP-I026 Pad横屏计划列表仍为两列大封面（2026-10-11，r20）

- **原生现象确认，P3设计评审候选，未修复**：1210×834浅/深色的官方计划列表保持两列，首屏完整可见2张计划卡，图像占主要高度；同一12期列表需约12个重叠采集视口核至末项。视口数不是用户滑动次数，不据此断言操作障碍。
- 证据：`output/app-native-audit/f75cbafd-r20/search-slot2/pad/landscape-light-plan-list-full/P03-01-official-and-template-full-scroll00.display.png`及浅深scroll00–11；源`QiuJi/Features/Training/Views/PlanListView.swift:117`使用两个flexible列。连续核对已确认12期均可见，未漏采内容。
- 待评审：大窗口是否增加列数或限制封面尺寸，提高同屏计划信息量；保留当前两列也需明确设计决定。本轮只记问题，用户决定/修复提交/复验均待定。


### APP-I027｜本轮详情准备入口缺返回键与顶栏标题（LIVE-20261012-R1）

- **P1评审入口缺陷＋正常App标题缺陷／用户复验通过，已关闭**。用户原话：“怎么感觉你进去的页面有点问题呢？为什么会没有返回键和标题呢？”原图原样保存在`output/app-live-review/LIVE-20261012-R1/L02/APP-I027/user-1.png`和`user-2.png`。
- 模拟器03 iPhone16ProMax浅色、基线`live-route-d54204c2`、c001半台直线球；对照图为中袋直线出杆、1/8杆，具体设备/版本未知。两图内容不同，不能拿内容差异直接判为布局缺陷。
- 已核根因路径：控制器`drill-detail`仍传`-deeplink.drillDetail`，RootView创建独立NavigationStack并以详情为根，未走真实动作库导航栈。返回键缺失；05 iPad11竖屏经真实动作库→c001实测：返回键存在，顶栏标题仍空。标题是独立的正常路径问题；源码使用初始为空、加载后更新的自定义principal，未提供navigationTitle；具体系统渲染机制尚未证明。此前已知返回链缺口仍交付为READY，属于准备验收失误。
- 修复：将调试请求接入真实MainTab动作库路由，校验目标ID和版本能力；不靠补画返回按钮伪装正常导航；标题候选使用原生navigationTitle，保留既有inline样式和收藏按钮，需原生两入口验证。理论入口保持回归。
- 验收：同一动作同一模式，真实标题/返回键可见；返回动作库、再次点卡进入、精讲返回，十环境标题/返回核验，浅深代表回归。用户确认前不关闭。


APP-I027修复交付（2026-10-12）：新基线`live-nav-1bf95354`十台已安装，真实MainTab动作库栈直达，系统导航标题取实际动作名。8聚焦XCTest、33Python、gate通过，独立源码复核无剩余阻断；十台浅色标题/返回目视通过（04显示区域异常另记），03/05深色通过，03理论入口回归通过。真实点击返回受CUA窗口定位错误阻挡，已交用户手动确认返回列表→正常点c001→精讲往返；**已修待用户复验，不关闭**。证据`output/app-live-review/LIVE-20261012-R1/L02/APP-I027/delivery.json`。

APP-I027用户复验（2026-10-12）：用户在收到“返回动作库→打开半台直线球→查看精讲→返回详情”的验证清单后回复“可以了”，据此关闭本条导航问题。未指明实际操作设备，不补写具体设备通过；不将此确认扩大为详情全文、十台排版或APP-I028通过。回执：`output/app-live-review/LIVE-20261012-R1/L02/APP-I027/user-acceptance.json`。

### APP-I028｜04号模拟器系统红条与内容显示区域异常（LIVE-20261012-R1）
- **环境/宿主疑点，P2待定位**：04 iPhone13mini浅色，顶部红色`rdar:45025538`，App四周黑色区域、有效高度缩小。simctl原图及CUA窗口都可见，非仅截图裁剪问题；本轮单台重新启动App一次仍待完整复核。不据此归因生产App或导航修改。
- 原图：`output/app-live-review/LIVE-20261012-R1/L02/APP-I027/native/04-13mini.png`，后态`04-after-retry.png`。返回键/标题在异常区域内可见，但04整体排版验收阻塞。
- 其余设备可继续APP-I027人工复验；当前保持用户控制，后续获控制时段再查04状态，不自动重启模拟器或删数据。


APP-I028追加用户反馈（2026-10-12）：用户本轮指出04小屏上下区域过宽，原图见`output/app-live-review/LIVE-20261012-R1/L02/layout-feedback/user-1.png`。Apple论坛https://developer.apple.com/forums/thread/807280有相同mini红条与异常分辨率一手报告，并提供Developer Display Zoom Larger Text→Default临时恢复办法；本地设置App也显示相同红条，暂无充分证据归因App页面。04已进入系统设置；两次CUA滚动均无变化，转请用户手动切换，未擦除/重启模拟器/修改系统框架，其余九台不动。

APP-I028字号疑问补查（2026-10-12）：用户反馈04“看起来是大字号”。只读查询04/03/02的 `simctl ui content_size` 均为 `large`，没有04单独调大系统文字档位的证据；显示缩放状态未从偏好文件得到确定值。原图仍有红条/黑边，偏大观感暂与异常显示区域一并调查，不以此缩小App字体。原图及查询回执：`output/app-live-review/LIVE-20261012-R1/L02/layout-feedback/font-check/`。保留USER_REVIEW，未改任何设置。

APP-I028再次卡死（2026-10-12 15:05–15:08）：04的launchctl显示SpringBoard无PID、退出信号5；15:03:07、15:03:47、15:05:10三份系统崩溃报告的coalition均匹配04 UDID，主线程在`BKSDisplayServicesStart`触发EXC_BREAKPOINT/SIGTRAP。确认本次系统界面进程连续崩溃，具体显示服务触发原因未定；不能归因字体或App详情代码。保留报告后仅04执行一次shutdown→boot，bootstatus完成，重新打开drill_c001；SpringBoard/App PID存在，原生截图已见详情，但红条/黑边仍在，未验证长期稳定或点击响应，不记修复通过。其余九台未操作。证据：`output/app-live-review/LIVE-20261012-R1/L02/layout-feedback/hang-repeat/`；启动回执`output/simulator-preview/20261012-150807-988847`。恢复后交还USER_REVIEW，停止重复重启/切缩放；04继续BLOCKED_ENVIRONMENT，建议后续独立验证新建同型环境或其他runtime，未执行替换/删除。

### APP-I029｜动作详情宽屏左右留白过大
- **P2布局反馈／实现中**。用户原话：“屏幕两侧的空白区域需要自动扩展到两侧，但是现在有些屏幕会扩展到两侧，有些不会”。03/09原图见本轮`layout-feedback/user-2.png`、`user-3.png`。
- 源码：DrillDetail正文与底栏均调用learnDocumentWidth，限制720pt；来源为旧球桌适配P15明确决定，不是随机设备故障。本次用户要求覆盖为详情局部随窗口宽度扩展，保留正常页边距与球桌比例；不外推到训练记录/文章阅读。
- 当前基线live-nav-1bf95354；待源码修订、构建和十环境代表复验，未交付。

### APP-I030｜动作详情重复标题与等级徽章位置
- **P2设计修订／实现中**。用户要求移除红框正文标题，并明确回复“是，放在灰色标签行右侧”；原图`layout-feedback/user-5.png`，原话/澄清及全部附件SHA在feedback.json。
- 目标：保留导航标题，删除球桌下重复动作名；L0入门置球种/分类标签行右侧，窄宽度或大字号时保持可读、不挤出屏幕。仅详情，保留内容和操作行为。
- 未构建/交付/用户确认。


2026-10-12交付：APP-I029/030已实现并构建成功，十台安装`live-layout-b948a5be`，浅色原图已审，等待用户复验；深色/极端字号/RTL/页尾交互及多标签原生仍为未验边界，详见`layout-feedback/delivery.json`。APP-I028在用户切换显示缩放后卡死；保留数据仅重启04，回放按钮点击后变为暂停，响应恢复；红条与黑边重现，仍开放。通用自适应技能已联网调研，建议补充现有DS，研究文件在docs/research/20261012-通用自适应布局技能调研.md；尚未修改技能。

APP-I030追加交付（2026-10-12，DR-373 r2）：用户要求交换上下顺序，标签含L0置说明上方；间距仍12pt，字体/右侧等级/换行不变。九台更新`live-order-fcee80be`，04旧包保留；构建和独立源码复核通过，六台首屏顺序已审，三台横屏需下滑复验。用户未确认，继续待复验。证据`output/app-live-review/LIVE-20261012-R1/L02/metadata-order/delivery.json`。用户提供SE截图的黑区为机身额头/下巴，原生750×1334图没有04那种内部黑边；APP-I028仍未解决。

### APP-I031｜固定字体与iPad阅读层级待评估
- 用户询问字号是否固定、iPad是否合适；源码确认详情说明15pt、要点16pt、小标题17pt、标签/等级11pt，来自Typography.swift固定Font.system(size:)。导航/其他页面不可据此全部概括为固定字体。
- 状态：待评审/方案，未修改字体。iPad并排缩小显示会影响视觉判断；需正常查看比例核说明/标签可读性，并另核真实Dynamic Type增长。不能只按设备分辨率统一放大，也不能凭系统字体名宣称已支持动态字号。
- 影响：若迁移共享token须审计消费者；先根据本页实机/正常比例反馈确定调整，不夹带到标签顺序变更。证据：本轮Typography/BTLevelBadge源码检查及metadata-order的iPad原图。

APP-I028跨页/干净实例补查（2026-10-12）：用户新图中04动作库列表同样有红条和上下黑区，证据`L02/metadata-swap/user-04-library.png`。主控新建同型同runtime临时设备D00F83A0-3D2A-4063-8793-D02B5973D85A，未安装球迹，在系统桌面/设置即见同一rdar:45025538红条，确认至少红条与系统显示异常可脱离App独立复现；不将此断言扩大为所有黑区根因已完全定位或卡死已在新实例复现。新实例已Shutdown，原04未修改/删除，仍BLOCKED_ENVIRONMENT；下一步应验证其他runtime/等价环境，不重复擦除或切显示缩放。完整证据`output/app-live-review/LIVE-20261012-R1/L02/metadata-swap/`。

APP-I030 r3（2026-10-12）：按用户试样要求将等级置左、灰色标签组靠右，灰标签内部顺序及换行保留，整行仍在说明上方。九台安装live-swap-053353d3，04旧包保留；构建/独立源码复核通过，SE和13寸Pad c001及SE c082原图已审。窄屏多行换行临界等边界见metadata-swap/delivery.json，用户尚未确认。

APP-I028用户澄清与替换（2026-10-12）：用户红框是App内浅灰区（导航上方、按钮下方），此前将之混称外黑边不准确。使用已有诊断参数实测mini window320×568pt，新标准iPhone13为390×844pt；probe内容view安全区0不是window安全区测量，底栏源码有12pt垂直padding，未改生产布局。用户要求换刘海屏模拟器，已将04换为iPhone13/iOS26.3，窗口移至CU34P2C；无红条/内部黑边，回放响应可见。新04正常启动到c001，旧mini与临时mini均Shutdown保留数据，APP-I028旧环境问题不关闭。对照/回执及旧矩阵备份：`output/app-live-review/LIVE-20261012-R1/L02/inset-clarification/`。

### APP-I032｜球桌2D入口不易识别为可切换
- 用户要求“左上角的2D按钮，做成一个2D/3D按键点击切换的，不然玩家都不知道”。
- DR-374：同时显示2D / 3D，当前模式语义绿色及浅背景，整体点击往返切换；保留原相机、回放与AX契约。影响DrillSceneView的动作详情、训练记录展开球桌。
- 源码已改，构建成功，独立源码复核无阻断；正在模拟器核验，用户验收待定。证据：L02/camera-toggle/。

APP-I032 r2：用户看过初版后要求删除「全桌」入口，2D/3D更紧凑；已移除额外按钮、缩小标签水平内距及间距，不改初次3D取景。最终构建与原生补验中。

APP-I032 r3：用户要求FPS移到3D画面内部右上角，明确不是工具栏。复用原FPS状态源，仅移动DrillSceneView的显示，保留其他场景默认位置、采样/调度与手势。与紧凑2D/3D、移除全桌一起复验。

APP-I032 r3交付（2026-10-12）：十台安装live-camera-9540c23b并启动c001，构建/独立源码复核/diff/doc-size通过。04最终版原生2D→3D→2D→3D，右上画面内FPS随读数更新，2D隐藏，未见全桌按钮；停在3D供用户审阅。r2 SE/Pad13浅色紧凑入口已核；最终版记录页/深色/极端字号及右上手势未原生验证。已修待用户复验，不关闭。证据`L02/camera-toggle/delivery.json`。

APP-I032用户复验（2026-10-12）：用户回复“可以了，继续按方案顺序往下看吧”，确认当前交付的紧凑2D/3D、移除全桌及3D画面内右上FPS效果，本条用户反馈关闭；未明确设备范围，不扩写为十设备/双模式或共享记录页均已验。进入同批L02 c001精讲准备，其他未闭环项目保留。

### APP-I033｜精讲标题重复与顶部命名
- 用户要求顶部“精讲”改为动作标题，移除正文动作名及“图文分步精讲”；截图为03浅色半台直线球，原图`L02/tutorial-header/user.png`。用户同时确认02/10已手动进入，记录为手动准备成功，不扩成全文/双模式验收。
- DR-375：共享DrillTutorialView使用实际动作名作为原生inline导航标题，正文直接开始章节，删除阅读类型副标题（含技术/规则变体同一header）；保留返回、球形切换及媒体行为。影响动作详情与训练记录入口。
- 已实施，构建与原生复验中，用户复验待定。

APP-I033用户续改（2026-10-12）：用户“看着可以了”，标题去重效果已认可；提供绿色精讲标题和红框黑色动作详情标题，要求详情改同样绿色。DR-375 r2将两页动作标题统一btPrimary，非全App标题批量变色；绿色最终版构建/交付中。原图`L02/tutorial-header/user-green-reference.png`、`user-detail-title.png`。

APP-I033交付与范围（2026-10-12）：最终live-title-2f00ba14十台安装，独立源码复核/构建/diff/doc-size通过；04详情绿标题、返回收藏原图已核，8台精讲标题/章节AX核验。用户确认标题去重及精讲内容“看着没问题”，要求直接下一步，现已转P16-02图片。内容/去重反馈已接受；最终绿色细节、长标题/深色/共享记录页不扩写为全范围验收。证据`L02/tutorial-header/delivery.json`，新交接`L02/c001-media-light/handoff.json`。

### APP-I034｜新建模版名称看不出可编辑
- 用户反馈预填“从动作库…”看起来是静态文字；同时明确此前输入/键盘操作已测试无问题。原图`L02/template-name-field/user.png`、原话feedback.json。
- DR-376：名称上方增加“模版名称 · 可修改”，输入使用系统圆角边框，保留原预填值、创建/空名处理和AX id，并补可编辑提示。仅动作详情加入训练弹层，不推广未审页面。
- 已交付待用户复验：live-name-c7dd2f1a十台安装，8台弹层已打开；02/10需手动点加入训练。SE点击名称即出现键盘，表单展开后标签/输入框/创建按钮文字可见。构建与独立源码复核通过；未改名或提交。证据`L02/template-name-field/delivery.json`。用户此前键盘/输入测试认可保留。

APP-I034 r2（2026-10-12）：用户要求文字整段选中高亮，非附加标签与边框。改为仅本名称字段开始编辑后原生selectAll；不自动弹键盘，不在持续输入中重选。构建/独立复核通过，01-SE实看仅文字高亮；按q替换原名为Q，再按w为Qw，取消测试未提交。中文组合输入未验；工具Unicode输入/剪贴板同步结果不可靠，不作中文通过证据。最终十设备部署状态见`L02/template-name-selection/delivery.json`，待用户复验。

APP-I034 r2复验未通过（2026-10-12）：四部手机有键盘未显示/未全选；用户确认“点按名称时全选并弹出键盘”，随后要求先装真机。04通过Simulator软件键盘菜单恢复显示但未全选，根因未闭环；当前版本真机构建中，暂无新代码修订。反馈与四图`L02/template-name-device/`。

APP-I034真机交接（2026-10-12）：iPhone16Pro/iOS27.0.1已安装启动device-select-4847c4a4，无fixture或数据重置启动参数。当前工作区r2源码构建、无新修订；只确认安装启动，用户键盘/全选结果待回报。回执`L02/template-name-device/delivery.json`。

APP-I034 r3（2026-10-12）：用户确认键盘/全选两项真机也存在，不关闭。改为局部UIKit稳定字段，首次点击先获取焦点再设置完整选区；编辑中交回系统，失焦重入可全选，组合草稿同步避免旧名提交。Astra诊断与Sol复核完成，构建与原生复验中。证据`L02/template-name-focus-r3/`。

APP-I034 r3交付：十模拟器live-focus-dc25a795、真机device-focus-51d66a17已更新启动；04完整键盘/选区/替换追加/重入与中文候选创建有证据，01/03软件键盘设置恢复后重入通过。02控制缺口未验，05准备被用户前台操作打断后停止。真机结果待用户，不关闭；详见`L02/template-name-focus-r3/delivery.json`。

APP-I034定位纠正：用户“只有03”指窗口E03-Profile-Standard，实际评审02。02全文已选中，Simulator软件键盘处于隐藏显示状态；菜单Toggle Software Keyboard后键盘出现且全选保留，无代码变更。02输入/重入待用户，AX控制缺口仍在。证据`L02/template-name-focus-r3/02-followup.json`。

APP-I034用户通过（2026-10-12）：用户在02恢复软件键盘后回复“可以了，继续按方案顺序往下看吧”，名称全选/键盘反馈关闭（CLOSED_USER_ACCEPTED）。不扩大为未测深色/VoiceOver。继续L02已包含模版及重复加入评审。


APP-I034深色复开（2026-10-13，READY_FOR_RETEST，环境恢复）：用户反馈名称全选但键盘不显示。03原图复现后，Simulator菜单Toggle Software Keyboard恢复；取消→重开→点名称验证全选+键盘。01/04/05/06/07/08/09经同一菜单恢复后AX键盘按键可见，02原图确认键盘+全选；10停详情且控制无效，待手动。不改产品代码/重启/重装/提交；未证明隐藏偏好的触发来源或主题因果，未测本轮真机。证据L02/template-dark/keyboard/recovery.json；深色用户复验及创建/重复加入仍待完成。浅色历史用户验收保留。

APP-I034持久键盘策略（2026-10-13）：用户要求查清反复隐藏并一次处理。前次只用Toggle Software Keyboard恢复显示，十台仍未显式关闭硬件连接；本次通过菜单关闭十台Connect Hardware Keyboard并逐UDID读回false。03脚本open-page后点名称、切浅色取消重进、再切深色重进、07 iPad重进均出现键盘/完整选区。脚本加入只读策略预检，默认/异常不猜测、组内一台失败则启动前整组拒绝；36项离线测试与独立源码复核通过。未改App，未重启整个Simulator，未证明历史每次隐藏的确切触发事件；10持久配置已核但仍需手动进入输入框。用户深色复验待定，保持READY_FOR_RETEST。证据L02/template-dark/keyboard-policy/delivery.json；控制器约定scripts/simulator-preview/KEYBOARD.md。

APP-I034深色用户确认（2026-10-13）：用户在持久键盘策略及创建/已包含/重复加入交接后回复“可以了，继续吧”，当前反馈CLOSED_USER_ACCEPTED。未逐台点名，不能扩大为十台功能实测、真机或整个Simulator重启验证。D027起按完整流程与代表设备推进，证据L02/flow-v52/handoff.json。

### APP-I035｜订阅页解锁按钮无反馈
- **P1交互缺陷／修复中**。用户确认所有设备、两处入口均试过，并澄清“能打开订阅页，但点里面的解锁没有效果”。原话与01原生截图：`L02/APP-I035/feedback.json`、`01-before.jpg`。
- 当前live-focus-dc25a795、十台forceNonPremium游客。无StoreKit商品时底栏显示绿色解锁Pro却disabled；DEBUG模拟开关按持久位显示并无条件dismiss，实际强制免费/游客权限拒绝解锁，造成假成功反馈。订阅页入口已证正常，不修改sheet链。
- 最小修复仅SubscriptionView：无有效商品改可点击重新加载，加载/已Pro明确禁用状态；强制免费、强制Pro、游客分别解释模拟功能限制，避免无效setter和dismiss；保留权益、鉴权、登出隔离。
- 需构建、独立复核及手机/iPad原生验证，再交用户复验；真实付费交易未测试，不因本修复宣布IAP可用。

APP-I035交付（2026-10-12，DR-378）：十台`live-subscription-74307116`已安装；构建、独立复核、gate、7权益测试通过。手机/iPad浅深色原生样张已审，01关闭重进仍锁定；点击重试后迅速回无商品状态，未独立截获重试瞬间转圈，不声称成功取得商品或购买。五台订阅页到达，02/05/06/08/10手动入口待补。恢复全浅色并交还用户，**已修待用户复验**，真实StoreKit交易不计完成。证据`L02/APP-I035/delivery.json`。

APP-I035用户复验（2026-10-12）：用户明确“可以了，提示和返回都没问题，继续按方案顺序往下看吧”，提示/返回反馈问题关闭。用户未逐台指明，不扩成真实购买、全登录状态或锁定收藏通过。回执`L02/APP-I035/user-acceptance.json`。


### APP-I036｜多球形达标目标分项展示（2026-10-13）
- **P2设计改进／CLOSED_USER_ACCEPTED**。用户认可c053内容、切换、精讲和加入训练；批准各球形目标与末项要求分别编号，不加“共同要求：”，各项末尾不要句号。
- DR-379：c053显式三项；详情按换行拆非空项，多项普通序号、自然换行及悬挂缩进；单项保留正文。只整理本条内容，不按标点猜测，也未批量迁移旧动作。
- TrainingDataEditorView取消criteriaText两行截断，允许完整显示新快照；不改历史数据/保存/计分。独立源码复核及最终构建通过，01/03/07与浅深代表显示已核；最终去句号版十台安装，03原生确认；控制权已交还用户。08横屏目标区、历史编辑新快照尚未原生核验。
- 原图、反馈及交付证据：`L02/APP-I036/`。待用户复验，不关闭。

APP-I036用户复验（2026-10-13）：用户“可以了，没问题，继续按方案顺序往下看吧”，目标分项/无前缀/无句末句号获认可并关闭。未逐台指明，不扩大历史编辑页或全库验收。证据L02/APP-I036/user-acceptance.json。

### APP-I037｜动作类型筛选与难度画像文案精简（2026-10-13）
- **P2设计改进／CLOSED_USER_ACCEPTED**。用户确认深色分类/筛选/搜索和无结果恢复正常，要求精讲类型→动作类型；单杆技术课/应用课/规则流程课去课；移除这项动作难在哪。两原图与feedback位于L02/APP-I037/。
- DR-380：仅可见文案和雷达副标题移除，不改分类标识/匹配、内容数据、雷达算法或计分；构建/复核/实际画面验证中。

APP-I037交付（2026-10-13）：十台live-copy-bf5aef48已安装；构建/gate/独立源码复核通过，03菜单浅深、01/07雷达浅深已目视核对。01/07雷达、03菜单供复验，其余首页。原类型ID/规则/雷达数据不变；待用户确认。L02/APP-I037/delivery.json。

APP-I037用户复验（2026-10-13）：用户明确三处均无问题，关闭；回执L02/APP-I037/user-acceptance.json。

2026-10-13 D027范围补验：用户明确07普通字号、详情两侧宽度和底部按钮无问题（APP-I029普通iPad竖屏反馈已接受；APP-I031该设备常规字号可读性已接受），回执L02/flow-v52/scroll-layout-acceptance.json。其他尺寸/大字号/缩窗/RTL边界保留，未据此改字体或关闭全部矩阵；APP-I030徽章排列未新增明确确认。

### APP-I038｜精讲深滚动及返回时主线程懒布局持续运行导致无响应（2026-10-13）

- P1，CLOSED_USER_ACCEPTED / 03和07用户复验通过。以下初始故障记录保留：用户原话“03卡死了”；设备16ProMax/iOS26.3，live-copy-bf5aef48深色。前态c042精讲滚到第八杆之后，主控点返回后快照超时，用户随后报告卡死。不能仅由顺序证明自动控制为根因。
- 实证：03 App PID7303两次约105%CPU，SpringBoard PID14953仍运行；3秒采样118/118主线程样本位于导航返回过渡布局调用链，117进入SwiftUI hosting render/AttributeGraph/LazyStack布局。截图仍在精讲底部，非名称输入页。确认为App主线程忙于布局，具体SwiftUI触发条件未定位；不能套旧04系统红条故障结论。
- 留证后仅stop/launch03 App，未重启模拟器/擦除/重装/改码，其余九台未动。临时内存模版/今日安排因重开丢失已事先告知；历史验收保留。新PID28100，c042详情AX可读；实际响应检查见recovery.json。
- 10-13根因隔离：旧版重入后仅球形1、连续6次向上滑动即在第八杆图附近复现（PID28100，约98.6%CPU，174/174主线程采样进入hosting事务/反复LazySubviewPlacements）。因此切球形、隐藏第二ScrollView、导航返回都不是必要条件；直接问题区为有限图文正文的懒布局测量/放置不收敛，未声称精确证明SwiftUI内部算法循环边。
- DR-381候选：只将正文LazyVStack改VStack及对应注释，保留样式、外层容器、多球形各自阅读位和退出重进回顶。基线live-tutorial-757f3f17，03原路径8次滑动至页尾并返回成功；首轮XCTest4/4（旧R1+c071及未变R2/c001），最终补强R1同进程两轮至第八杆/页尾/反向/返回+最长c078另2/2通过。07位置/重入与最长c078亦通过；首次c07836次上限到第15杆未达尾，保留失败，72次上限复跑原断言通过。03/07已核安装SHA并恢复深色c042详情；尚未用户验收，状态FIXED_PENDING_USER，先前临时恢复记载保留为历史。
- 资源边界：c078采样footprint898.8M/peak976.4M，主线程为XCTest查询/事件循环而非旧懒布局占满；未做同前提旧新内存对照，不能宣称内存改善或低内存设备性能通过。有限文档普通栈例外写回UI规则，列表规则不变。
- 正常L02评审暂停；03/07 c042首球形与切换条目进入RETEST_PENDING，历史回执保留。修复后用户仅需复验相关深滚动/切球形/返回重进，未验空名分支不因此通过。
- 证据：output/app-live-review/LIVE-20261012-R1/L02/hang-03-20261013/（app-sample.txt、before.jpg）。

APP-I038用户复验（2026-10-13）：03/07读到末尾、切球形、返回再进入均正常且未再卡死，按本次范围关闭；详见hang-03-20261013/user-acceptance.json，不扩大为其他环境或性能结论。

### APP-I039｜精讲回顶/到底箭头快捷操作（2026-10-13）
- P2设计改进，CLOSED_USER_ACCEPTED。用户要求两枚箭头，一键回最上方及到底；按后续明确指示放右下角上下排列，页尾留出控件空间，仅控制当前球形，其余阅读位置保留。沿用DR-381普通栈及DR-076独立滚动。
- 验证范围：03浅色/07深色，页首页尾可达、切球形各自位置和重进回顶；03旧卡死路径定向回归。用户复验另记，未关闭。证据L02/APP-I039。

APP-I039交付：最终右下竖排版live-tutorial-arrows-eb3d113e已装03/07；03浅色c042和07深色c001/c042共3次定向UI测试通过，首尾原图及独立源码/截图复核归档。末段按控件高度避让；切球形阅读位和重进回顶正常。早期工具栏版R1深滚动通过仅作历史回归，不替代最终位置验收。两台恢复c042详情，用户点查看精讲复验箭头位置/手感；不推进下一项。证据L02/APP-I039/delivery.json。

APP-I039用户复验（2026-10-13）：03和07箭头位置、回顶、到底均正常，按明确范围关闭。回执L02/APP-I039/user-acceptance.json。随后用户要求暂停，停止下一项细分检查。

### APP-I040｜使用帮助问句增加语义图标（2026-10-13）
- P2设计改进，CLOSED_USER_ACCEPTED。用户明确批准日历/方框笔/书本/铃铛/云同步小号绿色线性图标，无背景；正文及原生箭头保持。
- 仅TrainingHelpView标签；构建、十台安装/启动/二进制及主题读回完成。01浅/04深/09浅折叠和首问展开六图目视及独立复核通过，其他七台待用户自行进入；用户审美确认待回执，不记P13已通过。
- 证据：output/app-live-review/LIVE-20261012-R1/L03/APP-I040/REVIEW.md。路由相邻7行签名随标签改变，导航逐行审计未变，仅更新对应签名；原失败日志保留。

APP-I040 r2：补「关于与反馈」绿色info.circle，与五问句同列；导航仍AboutView。十台更新，04深/09浅原图核对通过，待用户认可；证据L03/APP-I040/r2。

APP-I040用户验收（2026-10-13）：使用帮助各设备图标及展开显示均无问题，含r2关于与反馈图标，按十设备指定主题范围关闭。回执L03/visual-v53/training-help-user-acceptance.json；下一P10训练心得由用户切页。
