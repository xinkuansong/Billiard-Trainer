# 页面、状态与版本清单

更新：2026-10-08。**B01/B02历史基线保留；当前E00先整理完整图层现状矩阵，B03候选延后。** 原有38个P-ID继续作为页面族；117条运行与设计充分度见§8，粗稿版本映射见§9。设计、运行和用户选择分别记录。

当前五 Tab 的显示名称以 `QiuJi/App/AppRouter.swift:10` 为准：训练、动作库、练习、记录、我的；不是早期文档的“角度/历史”。符号行号核对日期同上，执行前重查。

## 正式盘点与原始记录入口

| 域 | 可读报告 | 逐项 JSON | 负责范围 |
|---|---|---|---|
| 训练 | [B01-T](inventory/B01-T.md) | [T记录](../../output/app-interface-redesign/B01/T/inventory.json) | P02–P13；共享选择器、心得正文、分享、补记、提醒唯一登记 |
| 动作库与教学 | [B01-L](inventory/B01-L.md) | [L记录](../../output/app-interface-redesign/B01/L/inventory.json) | P14–P18；含12篇理论与6张教学阅读页 |
| 记录与我的 | [B01-P](inventory/B01-P.md) | [P记录](../../output/app-interface-redesign/B01/P/inventory.json) | P19–P35；含账号、设置子页、系统调用与法律外链 |
| 全局/条件/交界 | [B01-SHELL](inventory/B01-SHELL.md) | [SHELL记录](../../output/app-interface-redesign/B01/SHELL/inventory.json) | P01/P36/P37/P38；系统锁屏与灵动岛、注册路由、内部工具 |

格式、所有权及分类规则见 [盘点协议](inventory/README.md)。每个子项都有真实入口、源码符号/行号、现有状态、保护区、共享消费者、版本来源、v58映射和B02下一动作。设计/原生/用户验收状态单独记录。

## B01 源码盘点分母（2026-10-08）

**117个覆盖条目 / 38个页面族；不是117个页面，也不是运行或设计完成率。** 按当前源码冻结盘点v1；新增/遗漏按新版本增补，不静默改分母。

| 类别 | 条数 | 解释 |
|---|---:|---|
| screen | 49 | 独立正文/页面内容；其中TheoryIndex生产触发未定位，普通生产页面内容为48 |
| modal | 17 | 独立模态内容；同View多入口不重复 |
| dialog | 27 | 确认/错误反馈；含1个无置值者的条件残留提醒alert |
| shell | 3 | 全局Tab/会话壳、两种共享心得正文的宿主包装 |
| component | 1 | App自定义记分数字键盘 |
| system | 9 | 授权/购买/评分/通知及App自绘LiveActivity；系统可能不展示，条件分别记录 |
| external | 7 | 系统设置/订阅管理/邮件/法律外链与两个球桌工作包边界，边界族不穷尽内部页 |
| internal | 4 | 手机号测试页、模拟器工作室、测试宿主集合、模拟器Pro控制 |

域分母：T 38、L 26、P 45、SHELL 8；范围分类 included 58、mixed 38、external 15、conditional 6。范围标签说明设计责任；系统是否一定出现另看source_status，不能用scope替代可达性。

B01冻结快照中全部运行状态为unrun；后续B02状态单独记录，不回改历史盘点JSON。51个路由注册分支与35个Root测试参数是入口证据数，不加到页面分母。字段/来源检查见 [验证数据](../../output/app-interface-redesign/B01/inventory-validation.json)；设计/源码/运行/体验四层继续分别记录。

## B02 启动记录（历史；当前见§8/§9）

- T：已构建并安装独立模拟器版本，真实入口采集中。[逐项覆盖](../../output/app-interface-redesign/B02/T/coverage.json) / [原图与来源](../../output/app-interface-redesign/B02/T/screenshot-manifest.json)；A023/A025。运行覆盖与B01源码清单分列；未采集状态不算通过。
- L/P：71条采集准备已成文，均未运行。[L准备](../../output/app-interface-redesign/B02/L/preparation.md) / [P准备](../../output/app-interface-redesign/B02/P/preparation.md)；A024。
- 当时尚无新Figma粗稿、精稿或App改造。完整当前阶段以[CURRENT](CURRENT.md)为准。

## 1. 计数和状态口径

- P-ID 稳定标识页面或明确命名的页面族，不按入口次数计页；同一页面从不同入口可达，入口各自记录。
- 一行可能含同一文件的弹层或一个页面族，**下方页面族表的行数不是 App 页数**。B01 已分配独立子 ID；共享正文的不同宿主包装单列shell，不重复算screen/modal。系统UI验证触发/返回，不由本包重绘。
- `纳入`＝通用界面；`混合`＝外围可设计，球桌/渲染/业务保护区单列；`外部`＝只引用原专项；`待核`＝生产可达性/范围未定。
- 各条“源码入口位于/条件可达/未定位”以页级JSON为准；B02运行覆盖独列，未采集页面仍待核。当前粗稿版本另列§9，源码盘点不自动推动设计批准或实现。

## 2. 稳定页面族与入口摘要

源码路径简写：`T/`=`QiuJi/Features/Training/Views/`；`D/`=`QiuJi/Features/DrillLibrary/Views/`；`P/`=`QiuJi/Features/Profile/Views/`；`H/`=`QiuJi/Features/History/Views/`；`A/`=`QiuJi/Features/AngleTraining/`。这些是现有目录别名，不是拟创建目录。

| P-ID | 当前入口/页面族 | 已读源码锚点 | 关键状态/范围 | 归属建议 |
|---|---|---|---|---|
| P01 | 五 Tab 导航、跨 Tab 训练胶囊/恢复、全屏会话壳 | `QiuJi/App/MainTabView.swift:7/72/79`；`AppRouter.swift:42` | 纳入；导航栈、训练开始/最小化/恢复；共享状态保持 | B03/B05 公共批 |
| P02 | 训练首页与今日内容选择 | `T/TrainingHomeView.swift:89/177/2029` | 混合；加载、本周、无安排、待练/进行中/完成、勾选排序、弹层/失败；每日卡仅入口样式 | B04/B06-T；R01 |
| P03 | 训练计划货架 | `T/PlanListView.swift:18/45`；`T/Utilities/TrainingHelpView.swift:6` | 混合；帮助→浏览训练计划；首页自身也有货架，不假设有旧“全部计划”按钮 | R01 |
| P04 | 官方计划详情与编排今天弹层 | `T/PlanDetailView.swift:4/24/52/143` | 混合；主按钮四态、课程四态、展开/选课/订阅/失败；动作缩略图保护 | R01 |
| P05 | 我的模版创建/编辑与项目设置 | `T/CustomPlanBuilderView.swift:19/51/66` | 混合；空、名称、增删排序、保存失败；共用动作选择器 | R02 |
| P06 | 动作选择器 | `T/ActiveTrainingView.swift:894`；调用 `CustomPlanBuilderView.swift:51` | 混合；搜索、选/取消、多选；与会话同文件，不能并写 | R02/R05 唯一所有者 |
| P07 | 训练会话与单项记录外壳 | `T/ActiveTrainingView.swift:22/237`；`DrillRecordView.swift:48` | 混合；总览、组输入、休息、最小化、结束确认、精讲；保留内嵌球桌与手势边界 | R05 |
| P08 | 会话心得与训练总结 | `T/TrainingNoteView.swift:3`；`TrainingSummaryView.swift:377` | 纳入；输入/跳过、保存中/成功/失败、生成分享前保存；保存幂等保持 | R06 |
| P09 | 分享训练 | `T/TrainingShareView.swift:4/16`；调用 `H/TrainingDetailView.swift:115` | 纳入；主题/字体/成功率、相册权限/保存失败；微信闭包未实现不能记已可用 | R06，历史只消费 |
| P10 | 训练心得列表、按日阅读/编辑 | `T/Utilities/TrainingNotesView.swift:54` | 纳入；搜索、无记录/无命中、免费范围、编辑失败；正文保持 | R06 |
| P11 | 补记训练/编辑补记 | `T/Utilities/ManualTrainingView.swift:23`；调用 `H/TrainingDetailView.swift:67` | 纳入；日期/球种/时长/内容/心得、老日期确认、失败 | R06，历史只消费 |
| P12 | 训练提醒 | `T/Utilities/TrainingReminderView.swift:16`；调用 `P/TrainingGoalView.swift:224` | 纳入；时间/星期/开关、授权拒绝/调度失败；独立页面，非设置声音分区 | R11，训练/目标共同入口 |
| P13 | 使用帮助 | `T/Utilities/TrainingHelpView.swift:6` | 纳入；折叠问答、计划/设置/关于跳转 | R12 |
| P14 | 动作库列表、搜索、筛选 | `D/DrillListView.swift:4/33/235/300` | 混合；加载、无内容/无筛选命中/无搜索命中、收藏与已练次数、返回位置；缩略图资产保护 | R03 |
| P15 | 动作详情、球形选择、加入今日/模版 | `D/DrillDetailView.swift:4/157/167/170` | 混合；三 Tab/收藏/计划多入口、锁态、收藏、错误；嵌入球桌与试打目的地保护 | R04 唯一所有者 |
| P16 | 精讲阅读与全屏媒体 | `D/DrillTutorialView.swift:24/77/475` | 混合；单/多球形、滚动记忆、图片/视频分页/缩放、缺图回退；正文和教学资产保护 | R04；记录页也调用 |
| P17 | 练习首页“学/理/练/打/解” | `A/Views/AngleHomeView.swift:138/169/269` | 混合；搜索/分区/主题/无结果、订阅；专用球桌目的地外部 | R09 |
| P18 | 教学阅读外壳、6张学页与12篇理论 | `QiuJi/App/MainTabView.swift:233`；`A/Theory/TheoryIndexView.swift:11` | 混合；正文容器/阅读导航可设计；交互图与计算控制保护；目录 View 已注册但生产触发待核 | R09；P18-01–19见L报告 |
| P19 | 记录日历/当日记录与详情弹层 | `H/HistoryCalendarView.swift:8/24/59/76` | 纳入；加载/错误/重试、空、日期、免费范围；训练详情实际主点击走 sheet | R07 |
| P20 | 统计 | `H/StatisticsView.swift:5/15/80` | 纳入；无数据/免费遮罩/Pro、周期与图表；与记录宿主同时保活 | R08；不并写 P19 宿主 |
| P21 | 训练详情、心得编辑、删除反馈 | `H/TrainingDetailView.swift:30/67/115/120/123` | 混合；普通/补记、来源跳转、分享/编辑/删除/失败；跨目录消费 P09/P11 | R07 |
| P22 | 训练数据编辑 | `H/TrainingDataEditorView.swift:176` | 纳入；数值合法性、键盘、保存/取消/失败；不改统计口径 | R07 |
| P23 | 认知/角度训练记录详情 | `H/HistoryCalendarView.swift:76`→`AngleSessionDetailView` | 纳入；认知类型、时长、题数、误差和逐题明细；统计口径保护，运行待B02 | R07 与球桌专项交界 |
| P24 | 我的首页 | `P/ProfileView.swift:31/67/86/94/97` | 纳入；游客/登录、本月概览、退出、登录后数据合并与同步失败 | B04/B06-P；R10 |
| P25 | 个人信息、照片选择/裁剪 | `P/PersonalInfoView.swift:4/46`→`AvatarCropView` | 纳入；姓名/头像/球种/水平等资料，键盘/权限/异步保存失败 | R10 |
| P26 | 训练目标 | `P/TrainingGoalView.swift:76/178/224` | 纳入；owner 目标与统计，跳提醒；周目标不在当前设置主页面 | R10；P12 归 R11 |
| P27 | 我的收藏 | `P/FavoriteDrillsView.swift:4/49`；`ProfileView.swift:82` | 混合；加载/空/动作卡，跳共用动作详情；封面/球图保护 | R03 |
| P28 | 登录、数据合并与同步反馈 | `P/LoginView.swift:3/13`；`ProfileView.swift:86` | 纳入；Apple 登录/游客、忙碌/错误、sheet 关闭后应用资料；合并反馈由 Profile 承载 | R10 |
| P29 | 购买订阅/恢复购买 | `P/SubscriptionView.swift:4/59`；`ProfileView.swift:337` | 纳入；加载/失败、方案、购买/恢复、登录；多域复用，不能按入口重复实施 | R12；P28 冻结后接入 |
| P30 | 订阅状态管理 | `P/SubscriptionStatusView.swift:3` | 纳入；有权益从我的 push，状态细项 B01-P 补齐 | R12 |
| P31 | 认识球迹/产品介绍 | `P/OnboardingView.swift:5/61`；`ProfileView.swift:97` | 纳入；生产可达介绍 sheet、分页/跳过/继续/开始；不假设是强制首次启动门槛 | R12 |
| P32 | 关于与反馈 | `P/AboutView.swift:4/94` | 纳入；版本/法律信息等，协议/隐私有效性条件；条款文案不借 UI 重写 | R12 |
| P33 | 全局设置（我的→设置） | `P/SettingsView.swift:3/18/103/118/190/232/273/335/403` | 混合；完整当前分区见 §3；外观/音效等为内联控件，不虚构独立页面 | B04/B06-P；R11 |
| P34 | 球房风格/球桌风格/台呢颜色三个选择页 | `P/SettingsView.swift:135`→三个 SelectionView；`P/AppearanceCombinationPreview.swift:5/13` | 混合；列表/选中态/预览容器可设计；独立 SceneKit 预览/材质/相机保护；球房已无 DEBUG 限制 | R11；已拆子ID见P报告 |
| P35 | 球贴纸/球杆外观两个选择页 | `P/BallStickerSettingsView.swift:20`；`CueStyleSettingsView.swift:41` | 混合；列表与 Bundle PNG 预览，不能将换预览图等同生产资产修改 | R11；已拆子ID见P报告 |
| P36 | 每日清台及其更多/设置面板 | `QiuJi/Features/PositionPlay/Views/FreePlayView.swift`→`DailyHUDPanel` | 外部；全局设置与每日局内设置不是同页 | [每日 CURRENT](../daily-adaptive/CURRENT.md) |
| P37 | 其他球桌/相机/击球/求解/专用训练页面 | `QiuJi/App/MainTabView.swift:153` 起的实际目的地 | 外部及交界；原工作包有页面表，嵌入阅读/结果外壳按 §2 判归属 | [球桌清单](../table-page-adaptation/PAGE-INVENTORY.md) |
| P38 | PhoneLogin/测试预览/批量工作室/开发者区 | `QiuJi/App/RootView.swift:112/116`；`MainTabView.swift:214`；`SettingsView.swift:29/299` | 条件/内部；手机号仅测试启动参数入口，工作室仅模拟器，设置开发者仅 DEBUG+模拟器；不计普通生产必达页 | SHELL条件分类，不自动重设计 |

## 3. 全局设置源码现状（2026-10-08）

顺序：外观 → 球桌帧率 → 声音 → 教学辅助 → 每日清台 → 开发者（仅 DEBUG+模拟器）→ 装备外观组 → 数据管理 → 账号安全（仅登录）。

- 声音：背景音乐与击球音效两个独立开关（`:190`）；属于本页分区。
- 装备外观组（`:135`）：球房、球桌、台呢、贴纸、球杆五个目的页，再有颗星参考点开关。
- 数据管理（`:335`）：登录后云同步与条件式立即同步；清缓存对所有用户；“数据导出/即将推出”为静态占位，不算可操作导出流程。
- 确认/错误（`:51` 起）：清缓存、注销确认、注销忙碌遮罩、失败重试。
- 球种资料在个人信息、周目标在训练目标、法律信息在关于。早期 PROGRESS T-P8-05 的历史描述不作为当前内容清单。

以上来自源码，未确认用户当前安装包/最新 Figma 或运行画面。来自另一会话的设置反馈不归入本工作包反馈台账。

## 4. 现行版本记录（B01/B02 必填）

每页/子页追加：P-ID、真实入口链、源码 HEAD+dirty/hash/核对时间、最近有效设计 file/node/版本及确认、最近原生 build/设备/截图、版本差异、采用依据、当前阶段、成果 A-ID、未覆盖状态与下一动作。**原生视觉按B02的实际构建逐轮登记；未采条目仍待核，没有把历史截图或相同HEAD当作最新运行版本。**

入口状态分两列：B01 填“生产代码入口已定位/条件可达/未定位”；B02 另填“原生导航已验证/失败/未运行”，附截图和运行版本。前者不能自动勾选后者。

静态状态最低集按适用项选择：常态/加载/空/失败重试、游客/登录、免费/Pro、长文/大字号、键盘、选择/禁用/忙碌、完成与返回恢复。状态不适用需写理由，未采集不能记不适用。

## 5. B02 待验证与设计前交接

- 从真实五Tab入口验证主路径；测试深链只补难构造状态。每条JSON的next_action和unknown owner给出具体采集动作。
- 训练优先：首页/今日选择→会话记分→休息/最小化恢复→心得/总结/分享；自定义记分键盘、系统通知与锁屏活动分别取证。
- 内容优先：动作库搜索/筛选→详情Free/Pro→多球形/加入训练→精讲/媒体；教学/理论全部逐页身份核验，保护图解交互。
- 记录与我的优先：空/有数据/免费范围、详情编辑/来源跳转、账号与资料、完整设置滚动及五个外观子页。P21来源面包屑会切Tab并重置路径，源码本身没有dismiss调用，须实跑sheet宿主与返回链。
- TheoryIndex生产入口仍未定位；TrainingGoal残留提醒错误alert未找到置值者。两者保留条件状态，不伪造正常入口；B03再明确保留/排除或改造去向。
- 旧v58没有已完成页级审核包；找到的旧PNG/矩阵只作历史线索。当前源码哈希相同也不能证明全部依赖与运行环境相同。
- 所有B02截图附源码/构建、设备Runtime、窗口安全区、外观字号、数据/权限/入口；老巡游存在缺失跳过逻辑，不能用PASS推导逐页全覆盖。


## 6. B02 r2原生证据增量（2026-10-08）

- T：首轮37＋本轮15＝52张编号原图，49有效、3失败目标；38条累计29部分/9未采，仍DoD3/5。[r2覆盖](../../output/app-interface-redesign/B02/r2/T/coverage.json)列本轮7项实际覆盖与剩余。
- L：35张编号原图，33有效、1系统遮挡、1失败；26条中8部分/18未采，仍DoD4/5。[覆盖](../../output/app-interface-redesign/B02/r2/L/coverage.json)与[独立审查](../../output/app-interface-redesign/B02/r2/review/L-review.md)绑定实际范围。浅谈球感真实P18-19，旧P18-18文件名只作alias；瞄准点对照表、两代表文章末尾/CTA未采。
- P：45项已审准备，运行仍unrun；下一执行批从记录/我的/设置真实入口开始。SHELL条件流程仍按独立条目保留，不能从某个Tab截图推定全部系统入口通过。
- 新轮次继承T r2固定安装包，明确695构建前记录与2302构建中枚举的时序；当前并行源码存在2项漂移。逐图相邻采后几何不等于截图同时或sheet内部几何。
- 图册、元数据修订与全部原始证据见[统一浏览](../../output/app-interface-redesign/B02/index.html)和[A027–A031](ARTIFACTS.md)。本轮没有新的Figma粗稿、设计批准或App改造。

## 7. B02 r3原生证据增量（2026-10-08）

- P：65张编号原图，63像素有效（1AX受限）、2目标失败；完整证据图62。45原ID逐项对应，19部分采集/26未采，未将游客/免费锁定/商店未配置态记成全态完成。[覆盖](../../output/app-interface-redesign/B02/r3/P/coverage.json)给出实际态、未采原因与下一动作。
- 来源链统一归P21-01；P21-02心得包装/P21-03删除确认/P21-04失败仍未采。官方、模版、动作库三类经正常记录Tab进入，点击后原详情sheet不自动关闭，显式关闭后才见正确目标；返回有证据。现象转入B03导航设计，不重复补采或声称已修复。
- 介绍固定深色、无权限/登录条件；收藏没有用户筛选；全局设置导出仅静态占位。B02后续不虚构这些状态。介绍“涨球记”与关于/登录“球迹”的文案差异作为公共契约输入。
- r3使用新构建与5108项四时点来源记录，保留旧图版本；实际代码/Info/Assets hash相等。新图每张有相邻采后窗口/安全区读数，不能当sheet或键盘内部量测。
- SHELL八项仍按正常外壳/系统/受保护/调试条件分别整合；[设计前收口卡](batches/B02-CLOSEOUT.md)限定剩余工作。紧凑手机/iPad横竖变窗、系统Dark与大字号风险组合尚未收齐。
- 本轮全部成果[A032–A036](ARTIFACTS.md)，新Figma与App改造仍未开始。


## 8. B02 r4最终整合与设计前交接（2026-10-08）

前面的逐轮数字保留为历史检查点；当前覆盖真源为[117条JSON](../../output/app-interface-redesign/B02/r4/coverage/coverage.json)和[证据地图](../../output/app-interface-redesign/B02/r4/map.html)。T38=29部分/9未采、L26=9/17、P45=23/22、SHELL8=3/5；合计64 partial/53 unrun/0 complete。所有原ID及未采原因保留。

设计充分度另记：59 sufficient、39 conditional_unknown、16 external_protected、3 needs_evidence。结合有限历史复用与r4代表风险，B02设计前DoD已完成；不等同117条全功能、全设备或真机验收。新增46图中37覆盖实际态、9失败意图保留；统一索引A037–A042。

真实窄窗、正常商品和P21-02/P23/P25-02分别在相应契约/页面设计前补；P18-01生产入口仍待定位。其余未采状态按JSON的destination/next_action交接。Figma全局地图可从[B03-A](batches/B03-A.md)开始，不将这些状态删项或假定通过。r1未知几何不能回填，新几何契约使用r2/r3/r4测量及具体限制。版本/资源/失败修订详见[独立终审](../../output/app-interface-redesign/B02/r4/review/review.md)。

## 9. B03-A r1粗稿版本映射（2026-10-08）

[本轮评审入口](../../output/app-interface-redesign/B03-A/r1/index.html)与[主控复核](../../output/app-interface-redesign/B03-A/r1/root-review.md)绑定A043–A046。六张本地粗稿通过独立第二轮复审，具体方向/样板仍未获用户选择；Figma node及编辑能力见设计交付记录，不能用本地生成编号代替。

| 页面族 | r1板号/候选 | 当前用途与后续 |
|---|---|---|
| P01五Tab；P14动作库/P17练习/P19记录 | 01五Tab总览、02地图 | 全局层级与路径候选；其余独特页面仍按R包设计 |
| P02训练首页＋今日选择 | 03训练A/B与两项已选sheet；01用A | 样板候选；B03-B定契约后由B04-T覆盖具体状态/尺寸 |
| P24我的、P33通用设置 | 04我的A/B、设置前后两段；01用B | 样板候选；完整设置可滚动外壳，不等同登录/Pro/交易或子装备稿完成 |
| P02/P24宽窗口代表 | 05横屏训练、竖屏我的 | 容量和阅读宽度候选；真实窄窗/双向resize仍须前置补证 |
| 其他P-ID与全部117条状态 | 02仅地图；00改前六截面 | 尚无逐项精调；不能按六画板推算页面完成率或原生通过率 |

窗口、安全区引用B02实测并保留时间/容器限制；本轮未改运行覆盖JSON，未修改生产App。原版、候选及所有修订见本批manifest；保留当前和历史数据各自语义。

## 10. E00 现状矩阵（当前）

原117 ID完整映射到 [T](../../output/app-interface-redesign/E00/r1/T/matrix.json)、[LP](../../output/app-interface-redesign/E00/r1/LP/matrix.json)、[SHELL](../../output/app-interface-redesign/E00/r1/SHELL/matrix.json)。53格有限历史证据、722待采、265条件未知、130不适用；1170是基础核对槽，不是页面数/截图义务/完成率。实际完整页面迁入0；字体/插件环境已在E00-r2恢复并实际复验。设置外观组件frame4:8为源绑定试点，不计整页；9区140层素材准备见E01。完整滚动、关键状态、源与安装包新鲜度和窄窗均单列。

每条保留真实来源、外观/窗口、普通UI分层、渲染保护和后续小批。当前P24-01/P33-01先入E01样板；其余仍按域矩阵候选排期，不从“矩阵完成”推进到页面已重建。
