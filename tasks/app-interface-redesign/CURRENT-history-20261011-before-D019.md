# 全 App 通用界面｜当前进度

更新：2026-10-11（Asia/Shanghai，接续原会话恢复）。唯一恢复入口。当前先把 App 现状整理成完整可编辑图册，重设计暂缓。用户 D015 授权连续执行，各批完成后直接接下一批。

## 最新状态

- **D018：同模板仅内容不同的动作不逐个制作。** [范围独审已通过](../../output/app-interface-redesign/E17/r1/review/prep/template-dedup-r1-independent/checks.json)。按模板＋结构/交互差异＋代表样例组织；尺寸/主题验证在模板层做。练习次数0→正数、教程标记无→有保留结构代表，换数值或文案复用；[执行覆盖表已复核](../../output/app-interface-redesign/template-dedup-r1/COVERAGE.md)。[10/30/40窄范围](../../output/app-interface-redesign/template-dedup-r1/other-domains-r1/REPORT.md)亦已有限独审：计划/课程/卡片/日期只换内容复用，存在/锁/展开/空错加载分支保留。另保留高级动作已解锁/未解锁徽标代表；旧成果与ID保留，计数不自动增加。

- **实际 Figma 已验 174 态：154 基础＋20 条件，14 页面族。** 10训练首页标准浅深两态、使用帮助浅默认及40五窗口记录/统计浅深二十态已验；20的P05、P14 Pad竖Light共2态待修；10的P03浅色共1态已建待验，均不计通过。
- **离线登记 r102：86 包、329 条记录、430 外层文件校验通过。** 登记内108已验、3已建待验、218未建；12包含已验，76包含未验，E16与E12部分通过所以两组有交集。该登记和全图册174实际状态分开统计；[r102待验检查点已独审](../../output/app-interface-redesign/E17/r1/review/prep/root-registry-r102-current-manifest-independent-r1/checks.json)。
- **原生参照 568 张。** P16小屏浅深各21张原图、完整层源及source-only库存独审通过并登记；缺真实目标页的源包仍不准直接导入。
- **当前：D018最小模板覆盖表已复核，后续按共享模板与真实分支执行；P17小屏Light完整采集已结束、设备Shutdown，16张完整原图及四项收尾已独审，首尾加入原生图库。** 40五窗口P19/P20浅深二十态均已审，二十态备份83CRC独审通过。30首态58背景路径、17副标题及编辑复原已独审，94.08MB本地.fig/136CRC通过。
- **阅读字体仍在定位：** P14 Pad竖Light已建3 editable＋7 REF；218文字中两句×3视图换行碰撞。只读实测自然宽663/693pt，源容器656pt；AUTO行高仍换成两行。完整枚举9499条中SF Pro Regular赋值六次均hasMissingFont；保持字体HOLD，继续查原生字run与可用映射，不通过缩字、挪图掩盖。20.17MB.fig/64CRC已保存，原件不改。
- **UI现场：40 Pad八态已完成并独审通过。** 44张导出图逐图审查、文字/媒体/编辑复原通过，末态选区已恢复；8.49MB完整二十态.fig、83个ZIP成员CRC通过。没有重跑锁屏前首态，原检查点保留。
- **当前桌面恢复：** 10-11已接原插件完成17/17组，全部落盘、SHA/字节校验与保存握手完成，终态无错误。原21帧不变，新7PNG与28媒体完整；7PNG已独审目视。原插件已关闭、旧票不重跑。完整恢复独审已通过；三属性实际编辑复原、原图字节复原及28/8/28保护通过并完成保存握手，最终独审收口；封面底角/卡阴影修复工具准备中；P03仍待验，174不增。
- **后续接续：** 10标准批次首态P13浅默认及21帧/6Section/24媒体只读恢复已验，174态保留。新remaining9通过17生成/9UI模型并独审后单次启动，但index0 P03浅色生成中Figma标签页崩溃，无回执、未Continue；结构独审确认新增2Section/7frame，旧21帧与metadata原样；P03只计已建待验。标签页已Reload，旧注册移除、票已消费；接续分段核PNG/媒体/源与probe。149.9MB代码与崩溃同现，原因未证；并行改进载荷与重复内存持有，不重跑或降保护。
- **全App后续：** 补动作库横屏、动作详情与精讲多窗口缺口；训练/练习/记录域优先消费已有源。系统、条件及球相关边界单列，不把页面目录或截图直接算可编辑交付。

**完成率口径：** 108/329≈32.8%仅已登记交付记录，不能称全App完成率；全App分母仍待页面/条件去重与覆盖映射。117条目/1170格也不是完成率分母。[分母独审](../../output/app-interface-redesign/E17/r1/review/prep/progress-denominator-independent-r1/checks.json)。P18-19浅谈球感复用现有Page1:5旧编号P18-01，不能重复新建；TheoryIndexView另列。

当前[展示清单](../../output/app-interface-redesign/as-is-current-manifest.json)随图库生成；旧as-is-manifest.json仅为历史快照，不再作为当前数字。

## 成果入口

| 内容 | 入口 | 范围 |
|---|---|---|
| 已验统一图册 | [实际 Figma 174 态](../../output/app-interface-redesign/as-is-index.html) | 按页面筛选，可跳实际画板；本地链接/导出校验通过 |
| 本地 Figma 备份入口 | [按功能域查找八份 .fig](../../output/app-interface-redesign/local-figma-files-r4/index.html) | r4八文件完整性、11条本地链接及标注已独审；00历史索引、20待修明确标记，云/回导未验 |
| 10训练最新恢复备份 | [3个已验状态](../../output/app-interface-redesign/E12/r1/figma/domain10-remaining-ten-partial-readonly-recovery-actual-r1/10-training-20261010-three-states-recovered.fig) / [另含P03待验内容](../../output/app-interface-redesign/E12/r1/figma/domain10-remaining-nine-crash-structure-readonly-actual-r1/10-training-20261010-three-accepted-plus-p03-partial.fig) | 两份完整本地文件分别通过52/45项ZIP CRC；后者不等于P03已验，云端/回导未验 |
| 五窗口与浅深矩阵 | [离线覆盖矩阵](../../output/app-interface-redesign/offline-coverage.html) | 86 包、329 记录；缺口、来源和实际导入状态分别显示 |
| 原生与待采队列 | [568 张参照与批次队列](../../output/app-interface-redesign/as-is-queue.html) | 原生截图、已审层源和待采状态分列 |
| 待导入注册 | [r102 注册表](../../output/app-interface-redesign/pending-figma-import-registry.json) / [校验](../../output/app-interface-redesign/import-prep-audit/root-registry-r102/checks.json) | 每包源文件、SHA、验收及执行限制 |
| 文件命名与归属 | [FIGMA-ORGANIZATION](FIGMA-ORGANIZATION.md) | 00/10/20/30/40/50/60/70 功能域分文件 |
| 剩余证据索引快照 | [全App矩阵报告](../../output/app-interface-redesign/E17/r1/review/prep/whole-app-remaining-matrix-r1/REPORT.md) | r70时点117条目；旧层、新层、原生及实际Figma分列，1170格不是剩余任务数 |
| 全量中间成果 | [ARTIFACTS](ARTIFACTS.md) / [DECISIONS](DECISIONS.md) | 每批成果、失败原件、决定和验收入口 |
| 页面范围与执行计划 | [PAGE-INVENTORY](PAGE-INVENTORY.md) / [PLAN](PLAN.md) / [EXECUTION](EXECUTION.md) | 保留原页面 ID 和球相关专项边界 |
| 本次整理前完整历史 | [CURRENT 历史快照](CURRENT-history-20261010-0538.md) | 保留所有时间点和原链接；当前状态以本页及 active-run 为准 |

## Figma 文件与下一动作

| 文件 | 当前实际成果 | 下一动作 |
|---|---|---|
| [00 总索引与规范](https://www.figma.com/design/Ea42AbmIyS7ct4Oeg3kcAH) | 原生中文 Text/Shape 小样、既有索引与本地备份 | 按实际已验状态更新域导航 |
| [10 训练](https://www.figma.com/design/wXUomC7Fqu7kzFU3ze9pzq) | 标准浅深首页与浅色帮助默认3态共9可编辑＋12REF已验；5包60态离线准备 | P03浅色已建待图像/媒体与编辑复原验收；通过后仅接真实剩余8态，旧批不重跑；[原view-only空文件](https://www.figma.com/design/HvRcUTgkOOv0UAr50oFrcl)保留，旧票未消费 |
| [20 动作库与阅读](https://www.figma.com/design/CAWCbamjl7yhA6x46j0Lg1) | 19 个分类页；P05 原件整页 HOLD；独立字体近似排版候选有限通过 | 继续原生与层源；普通正文真实字体/换行验收未过前不批量导入 |
| [30 练习](https://www.figma.com/design/cjYkfghflyDSqJ6Fy1Okbm) | 小屏Light首态3editable/29REF、17副标题与58背景路径已验；完整.fig已存 | 按已修源继续其他态，逐态实际读回与PNG验收 |
| [40 记录与统计](https://www.figma.com/design/qW93kADAdnXDh3Qwz0o6GD) | 五窗口P19/P20浅深二十态已有限验收，原失败保留history6:5；二十态8.49MB.fig/83CRC独审通过 | 补目录与导航；后续只补真实非空/条件分支，日期与记录内容实例复用 |
| [50 我的与账号](https://www.figma.com/design/oifs8o6gXuPBdP3uZouIgC) | 个人信息、昵称、订阅等已按批验收，实际结果见统一图册 | 保留精确视觉/云端/回导等独立限制 |
| [60 设置与外观](https://www.figma.com/design/K1kxfOSxXAVBw861ArXbwP) | 五窗口浅深，内容及编辑复原已验 | 保留原生参照及系统视觉待验项 |
| [70 引导与通用界面](https://www.figma.com/design/9wFav4Ab14VZLcm8CPAjhE) | 60态已验，目录60实际链接及71Text流布局已验；67,035,501B完整.fig/184CRC通过 | 保留云端持久化和回导未验边界 |

## 验收边界与资源

- 普通文字、颜色和控件保留完整编辑图层；球桌/教学图按原生完整独立图保留，不重绘或连同外围 UI 烘焙。
- 导航按本页实际调用链取色：P14使用系统inline全局brandGreen，P15/P16调用阅读principal为btText。P14错误的黑色nav候选r3已撤回，r2与登记包保持有效；不按相近页面名称批量统一。
- P05 已完成 188 项有限修复，69 项未选内容不变；6 个正文换行实例仍影响整页。独立 flow 候选保留原件，不能冒充原布局通过。共同阅读字体/换行 HOLD 尚未解除。
- 精确系统字体、SF 符号、系统材质、云端持久化、新备份回导按批分别验；本地 .fig CRC/hash 不等于云同步或回导通过。当前 Figma MCP 额度受限，不改套餐或权限。
- 最新只读源码观察为11:29：冻结5119中5115同、4改（母球材料/纹理处理两Swift、测试、XcodeUI状态），新增70缓存/元数据。普通界面文字/布局未发现变化；教学图间接材料依赖像素等价未验，旧图册继续保留冻结版本，不静默换基线。[报告](../../output/app-interface-redesign/source-impact/20261010-noon-r1/report.md) / [独审](../../output/app-interface-redesign/E17/r1/review/prep/source-impact-noon-r1/checks.json)。
- 五窗口：375×667、402×874、440×956、834×1210、1210×834 pt，各浅深色。不同冻结包保留来源日期，不混称同一版本。
- 内置浏览器 file:// 自动预览被策略拒绝，HTML 仅静态结构/链接验证；实际 PNG 目视检查另有证据，不绕过策略。
- 原生设备只有专用 F2/小屏/大屏/Pad 由本任务串行使用，精确 UUID/状态见 active-run；每轮独立检查并在结束后释放。禁止操作其他会话设备或清理缓存。
- E18 实际持有对象/鉴权诊断未完成，相关 UI 不运行；P19 球感两幅底图仍缺，typedOptional children=0 不证明 nil。保留失败和后续限制，不阻塞其他页面。
- 球相关继续 [每日清台](../daily-adaptive/CURRENT.md) 与 [球桌页专项](../table-page-adaptation/PLAN.md)。本任务不改 App 源码，不执行登录、购买、发布或提交。

## 批次状态（活动总表）


四态：⏳待开始、🔄进行中、⚠️返工、✅本批DoD完成；保存、云端、图层验收及用户体验分别记录。

| 批次 | 状态 | 实际结果与下一动作 |
|---|---|---|
| B00 / B01-T/L/P | ✅ | 立案及117条源码盘点完成，历史原稿保留 |
| B02-T/L/P / 收口 | ✅ | 设计前基线DoD完成；64 partial/53 unrun/0 complete，非全设备验收 |
| [E00](batches/E00.md) | 🔄 | 矩阵/方法与文件准备已成；[r2](batches/E00-r2.md) 原生Text/插件已恢复并复验，外观组件与本地.fig已成；E01当前页已完成新构建取证，专用设备已释放 |
| [E01](batches/E01.md) | 🔄 | [P24](batches/E01-P24.md)已采10图并生成两主题原生草稿，定点修复及双主题复原已验，50/00新本地备份已存；[E01-P33-L](batches/E01-P33-L.md) Light/Dark各六图/八区原生可编辑内容已独审，精确视觉未过；浅深色备份恢复六帧像素一致 |
| [E02](batches/E02.md) | ✅ 限定内容DoD | 新冻结构建补齐四窗口浅深16状态，48可编辑/46参照Frame、16编辑复原通过；三份.fig已存CRC/hash通过。精确视觉NOT_PASS，新回导/云端未验 |
| [E03](batches/E03.md) | ✅ 限定内容DoD | P25–P30入口盘点；P26/P27/P28标准窗口浅深六状态，18可编辑/8参照帧及6编辑复原通过，00/50新.fig已存CRC/hash通过；精确视觉NOT_PASS |
| [E04](batches/E04.md) | ✅ 限定内容DoD | 24状态/74可编辑/34参照独审通过；24编辑复原、修后00/50备份完整性通过；Pad宿主箭头12实例已修 |
| [E05](batches/E05.md) | ✅ 限定内容DoD | 标准窗2基础＋2编辑条件、12可编辑/6REF、4编辑复原独审通过；12处折行已修。00/50两份最终.fig完整性通过 |
| [E06](batches/E06.md) | ✅ 限定内容DoD | 16状态62可编辑/46REF、16编辑复原及独审通过；00说明51:71/50说明23:10602和两份最终.fig CRC/hash已验；精确视觉/云端/新回导未验 |
| E-T/L/P/SHELL / E90 | ⏳ | 按原ID/风险组合滚动小批；各域队列仅候选，未派发取证 |
| [E07](batches/E07.md) | ✅ 限定内容DoD | 4状态8editable/8REF、192Text、媒体蒙版与4复原/2前景补证独审通过；00/50新说明及两份.fig完整性已核，精确视觉/云端/新回导未验 |
| [E08](batches/E08.md) | ✅16态限定DoD完成 | 原10态修订与后6态新增均独审；全部编辑复原与55.18MB完整.fig CRC已验，计入总图册150，精确视觉/云端/回导未验 |
| [E09](batches/E09.md) | ✅ 限定内容DoD | 标准12状态/34原图及完整24视图/24REF层源限定独审通过；r3限定源复用成立，70已实际导入12态24editable24REF188Text；4处L3实际已修并独审，20媒体实读与修后.fig已验，12态计入86 |
| [E10](batches/E10.md) | 🔄48态已验 | 手机24＋Pad竖横浅深24，内容/源媒体/编辑复原通过；66.96MB完整.fig/184CRC已验，目录收口中；精确字体/云/回导未验 |
| [E11](batches/E11.md) | ✅标准4空态限定内容已验 | 标准4空态已实际导入并独审，与E13合计五窗口20态；186来源匹配；非空状态未采 |
| [E12](batches/E12.md) | 🔄标准层源独审 | 8默认态及4条件共60原图已限定独审；r1–r3制作问题保留，r4旧通过因轨道新问题撤回，r5 12态36view40REF已限定独审；历史源FAIL保留 |
| [E13](batches/E13.md) | ✅其余窗口16空态限定内容已验 | 手机8态与Pad8态均实际导入并独审，连同E11标准4态共20态；完整.fig已存，目录待补；精确系统视觉/云端/回导未验 |
| [E14](batches/E14.md) | 🔄 动作库Pad竖浅深已审 | 标准P14两态、P15/P16四态及小屏浅深完整层已审；大屏浅深各26原图及层源、Pad竖浅深各34原图及层源独审通过，Dark已登记r32。Pad横Light新冻结单态候选并行，latest比较仍PENDING |
| [E15](batches/E15.md) | 🔄待实际Figma | 四窗口281原图、48状态记录/144view完整离线层源均限定独审；与E12合计五窗口60离线状态记录。10标准浅深两态已实际验收，其余窗口仍待导入 |
| [E16](batches/E16.md) | 🔄手机修订已审/Pad层源已审 | 三手机263原图已审；每包14处开发卡裁剪修订已独审，已更新3包导入源；Pad竖95原图/22态层源已审；r4采后来源缺失边界保留；横屏r2采4图后Lazy高度变化阻断，source/install/Shutdown齐；r3已采43图抵达尾部，但4卡缺完整可见证据而阻断；finally来源/安装/owned Shutdown齐，步长跨过完整可见区间已定位，四卡14原图补采已结束并Shutdown，合57原件37卡完整覆盖/首双尾已独审，完整层源1态3view57REF已独审登记；解五卡32原图16:20:37释放，原生与1态3view32REF完整层源已独审登记 |
| [E18](batches/E18.md) | 🔄实际self诊断阻断 | 实际Keychain返回-34018，UI仍阻断。r5实际self返回Generic4097，真实持有对象身份仍未证；r6新身份诊断获限定许可待跑，UI仍禁止；此前finally来源/安装及owned Shutdown齐 |
| [E17](batches/E17.md) | 🔄逐页采集/制层 | 三法则及05–12浅深完整层源均已审登记；P12浅深各20原图/1态，Light字重r2修复已审。13浅深各15原图与完整层源亦已审登记；学习页排队；球感底图仍partial |
| [B03-A](batches/B03-A.md) | 🔄 | 六板候选保留，按D011延后；当前不再等旧A/B提问 |
| B03-B / B04–B07 | ⏳ | E阶段完成后恢复方向选择、精调、组件和代码样板 |
| R01–R12 / B90–B91 | ⏳ | 原重设计推广与最终回归队列保留，未开始 |


## 恢复顺序

1. 读 active-run，先确认进行中的原生 session，不重用已消费的单次票。
2. 完成当前原生采集 → 独立验收 → 完整层源 → 独立验收 → 精确导入闭包 → 注册表/矩阵/台账更新，再接下一批。
3. 当前先补10 P03待验态及旧内容的PNG/媒体恢复，再按真实remaining-only接续；40五窗口空态已全验，转目录与真实分支。30三态范围已审，20字体证据单独HOLD。所有已导入状态先查节点，不能盲重跑。
4. 持续执行至授权范围完成；阻塞某域时继续独立工作，不逐批等待“继续”。
