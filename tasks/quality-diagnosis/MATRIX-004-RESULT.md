# Snapshot004 代表设备矩阵补测

以 PLAN-v2 和 MATRIX-004-REMAINDER-AUDIT 为范围。只诊断；原38场景不缩减。

## M1 休息/工具浅深色配对

专用 iPhone 17 Pro / iOS 26.2，FFD2DA19-C537-4038-BB52-2B771C7B69F8；两轮系统 appearance 与 large 字号均实际设置并读回，环境记录在 build/quality-diagnosis/resume004/m1-{dark,light}-environment001.json。关闭8台本诊断已终态设备但不擦除数据，不操作其他工作设备。

| 正式运行 | 结果 | 归档 |
|---|---|---|
| formal-004-m1-dark-core-001 | 2/2，39.436秒，runner0/recorder0 | 69文件及observer独立SHA |
| formal-004-m1-light-core-001 | 2/2，41.644秒，runner0/recorder0 | 69文件及observer独立SHA |

相同原V51两个方法：实际休息弹层/最小化44pt按钮、工具瞄准模式切换/轨道底缘和高度/球库触摸区互不相交/打点盘开关。两轮均为forcePremium+内存布局前提（训练activeTraining fixture、工具deeplink），不代表正常保存、购买或击球精度。

主控已分别打开8张完整PNG。休息弹层标题、倒计时、+30与完成按钮完整；最小化后剩余时间按钮处于底栏上方。浅色训练页为浅灰/白卡黑字，深色为黑底深灰卡白字。工具盘面/轨道/球库没有所测重叠，打点盘完整可见；两种系统外观均保持工具黑底，冻结FreePlayView:407/572/741明确dark环境和preferredColorScheme，不能报系统设置未生效。此不是全页对比度或VoiceOver合格认证。

8图尺寸/SHA/背景取样与逐图审阅清单：archive/quality-diagnosis/observations/m1-core-pair-001-review.json。原PNG与xcresult在archive/quality-diagnosis/runs同名目录。未新增产品问题。

原5350生产输入于17:31再核改变0/缺失0，见source-recheck-20260908-1732.json（文件名为计划时刻，内部为实际时刻）。后续仅注册既有QualityDiagnosticUITests类供五根/详情两方法，三个scheme逐字节恢复。

仍待：M1根页/详情浅深配对、两种设备最大辅助字号长文、紧凑模板、iPad缺失配对以及原计划其他子项。iOS17.0已当前查询为available，尚不代表新设备已启动或通过测试。

## M1 五根与正常详情浅深配对终态

Light roots/detail001：2/2，60.366秒，1334文件；Dark roots/detail001：2/2，60.913秒，1340文件。两个observer均runner0/recorder0，原件独立归档。相同QualityDiagnosticUITests原两方法，inMemory+forceNonPremium，normal搜索c012→详情→试打→返回详情→返回原搜索；无改业务或删弱断言。

18张完整PNG主控逐一查看：五根可达、历史为空、我的为游客；动作详情标题/要点/加入训练和上手试打按钮可见，3秒后完整盘面保持，试打为第1/8杆，返回保留原查询和唯一c012。深浅同内容，文字与卡片实际切换；试打固定深色。此条没有点击击球/精讲，不扩大为完整动作旅程或内容正确。

详情立即/3秒图的相同内容属于预定稳定性观察，不能因同画面而删除；SHA/尺寸及18图逐图审阅表见 archive/quality-diagnosis/observations/m1-roots-detail-pair-001-review.json。

M1默认字号浅深色代表配对补齐：休息/工具两轮各2通过（Dark39.436秒、Light41.644秒，各69文件），五根/正常c012详情试打返回两轮各2通过（Light60.366秒1334文件、Dark60.913秒1340文件），共8次方法执行/4个独立方法两外观；26张完整PNG主控逐图审，四run及observer均归档。训练/详情/根页实际浅深切换；工具固定深色有源码依据。仅核销该M1代表组合，SC34仍partial；iPad、紧凑AX5长文/模板、原系统权限/引导等未核销。

下一步依MATRIX-004-REMAINDER-AUDIT补M2/iPad，当前没有测试运行。ENTITLEMENT-AVATAR-004-PREPARATION和RELEASE-RUNTIME-004-PREPARATION主控全文已读；前者A新诊断类由独立agent起草、尚未主控审核/注册/运行，后者仅现包核验与执行准备。

## 紧凑 iOS17 AX5 长文终态

formal-004-m2-ax5-longread-001：1/1，33.186秒，73文件与observer归档，runner0/recorder0。新SE3/iOS17.0 D2C40728-0808-4904-BD6B-0A6097780D00，真实light和accessibility-extra-extra-extra-large设置读回；正常练习→理→球团管理→指定下段→返回。主控完整entered/lower-content/returned三图及AX判据已核，下段“本方没有清台路径时，球团反而是宝贵的母球藏身资源”完整可读，返回原卡；非全文/教学正确认证。返回页搜索图标实际放大裁切，关联已有QD019，不新增同类。

iPad对应新设备C2A0FFC7-6542-4B08-82C2-430A9C6A222C准备中。紧凑模板将复用强保存/重启方法，仅新增QD_TEMPLATE_KEYBOARD_EVIDENCE=1分支：真实输入全名、键盘存在且字段可达时留图，再正常Return，原强保存/重启/同UUID判据不变；旧成功源在原归档保留。未提前计通过。


AX5长文缺口两设备补齐：新SE3/iOS17.0 1/1通过33.186秒73文件，新iPad mini/iOS26.2 1/1通过31.640秒1367文件，均真实最大辅助字号/Light读回；正常球团管理指定下段和返回，6张完整关键PNG主控已审。目录搜索图标裁切关联QD019；不证明所有字体扩展/全文/VO。两个run及observer均归档，SC35仍partial，模板补证继续。

iPad keyboard001实际1失败18.475秒，未进入模板/未输入。完整终态PNG和AX显示顶部五个按钮正常，而无TabBar祖先；原模板helper限定app.tabBars.buttons导致找不到“我的”。失败原件/测试源已归档，非产品输入失败。002仅适配实际五按钮同行的顶部系统导航并强断言selected，保持空模板、键盘输入、退出不保存判据；不使用泛同名点击或猜坐标。


iPad AX5模板键盘短流程002 1/1通过42.725秒，1279文件及observer归档。完整键盘展开/收起/退出空列表三图已审：字段可输入且可达，无动作保存禁用，退出没有新增模板。001入口脚本TabBar限定失败18.475秒/1253文件保留，实际顶部五按钮无TabBar。这里只补输入和取消图证，历史iPad保存重开沿既有证据，不报再次保存通过。


iPad AX5模板键盘短流程002已通过并审3张完整图，输入、收起键盘及退出空列表已验。M2 AX5模板001在已选c037后因iOS17无“关闭”按钮而终态失败44.937秒；1563文件及observer已归档，完整PNG/AX已审，尚未保存。002依据实际Search键适配测试后独立补验中，业务代码未改。


M2 SE3/iOS17最大辅助字号模板004终态1/1通过139.141秒，105文件及observer归档：空名/无动作拒存，64字名称正常保存，同UUID进程重启读回3组1动作已验；独立SQLite备份确认唯一5C844119-150F-4D83-805E-CA30C5C9A8AD、完整名称与关联drill_c037。键盘展开/保存卡片/重开编辑/返回4张完整PNG已审，长名称单行省略而完整值保留，控件可达。001-003脚本系统键盘/搜索状态/离屏列表谓词失配分别44.937/47.392/49.004秒失败，1563/1455/1435文件及observer保留；不记产品失败、不删除原断言证据。SC08/09/35仍partial；完整矩阵、权益头像、Release实际运行及B6审计等原剩余范围继续。


M3 iPad mini/iOS26.2默认large字号休息配对补齐：Light001 1/1通过15.970秒1175文件，Dark001 1/1通过13.886秒1179文件，两run及observer归档；主控4张完整弹层/最小化PNG已审，实际浅深切换、倒计时可见、按钮和44pt休息浮标可达。使用inMemory/forcePremium/activeTraining布局夹具，不外推正常创建训练/实际订阅/系统后台计时。旧Dark原件缺失，故仅补同一短方法Dark建立当前可复核配对；SC34仍partial。
