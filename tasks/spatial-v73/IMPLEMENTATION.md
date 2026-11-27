# v73.3 双模式实施记录

2026-11-26（北京时间）。用户授权B0–B5逐批实施与验证；方案不变。

## B0 · 共用判题与空间事实（已通过）

- 新增Core/Training下SpatialQuizJudgement、SpatialQuizPhysics：两模式共用判题；统一显式空间模拟入口；只读消费原始事件/接触/终态，无物理参数修改。
- 名称映射：cueBall→母球、_8→障碍、_1…_7/_9…_15→目标。输入和证据身份分别校验。
- 时间组继承既有firstCueContact的1e-6秒，首次接触连通组排除同时黑八；碰球/碰库同组但无因果证据时未确认。
- 表面映射来自PocketGeometryAsset.surfaceRoles。静态接触索引前段为布/胶边/袋内皮革；后段为SpatialPracticeGeometry附加桌外表面及地板；wood/exterior不作为胶边。桌外接触/离域/未入袋终态离台保留失败，不调用自由页回收。
- 空间网格胶边必须有接触前局部区间，法向入射速度>0；落地返回平面求解后的胶边使用成功冲量同时记录的接触前入射事实及真实库段几何；初始t=0支撑不计吃库。来源geometryID/表面索引/原事件序号保留；未知或缺失证据未确认。
- 实际首杆/示范的页面接线尚待B2/B3；B0提供唯一共用入口与可执行参考见证，不把未来消费者算作已验证。
- 真源夹具：扎杆b9eb3986/research-masse-00001；跳球331c6e24/one-00001-jump-c01；共同sourceLayoutID target-59-m054-d6，正式球号映射后重算。测试不改研究原件。
- 执行：`make -f scripts/Makefile sim-test SIM_TASK=v73-b0-spatial ONLY_TESTING=CuePhysTests/SpatialQuizTests TEST_CODE_COVERAGE=NO`。
- 设备：本地standard-phone，AE86244C-EE61-4585-882F-E39B892214DB，经fleet独占租约；未触碰研究占用设备。
- r1编译失败（测试表达式过复杂）已拆分；r2发现落地返回平面求解后的三次胶边缺少适配，已按真实成功冲量事实补齐，未改引擎。r3的14项通过；r4的16项新测试＋4项既有空间回归共20项全部通过。原失败与重跑证据均保留；[本轮证据](../../output/local-test-runs/63cb30bfa1644915bbe3c85a4377214a/evidence)。临时构建为本批回归保留，闭环后complete。

## 后续批次

B1已通过；B2已通过；B3已通过；B4已通过；B5已通过（工程验收）；依赖与DoD以根目录问题集合_v73.md为准。

### B0 验收补充

最终运行fleet任务`v73-b0-spatial-r4`，原始命令与20项结果见evidence/r4.log，完整结果r4.xcresult。真实无进袋吃库、空间桌外接触、未知几何拒收、既有平面模型稳定性均通过。规则版本spatial-quiz-v1；无UI/真机证据。玩家首答/复练和示范的消费者接线是B2/B3交付，B0验证其唯一共同物理入口，不虚报页面已实现。

## B1 · 冻结双题库与加载（已通过）

冻结研究候选及每条参考的输入/审核依赖，当前研究任务继续运行。B1只报告实际抽查，B5再全量核验正式清单。

- 快照：扎杆1196、跳球8146题；snapshot下独立候选清单、来源manifest与逐题压缩包约168MB，App双gzip合计约1.18MB，仅参数入包。freeze.py从快照可重复导出并验证所有依赖SHA。
- `SpatialQuizBankTests`3/3通过；扎杆44、跳球40分层参考均通过真实空间判题与实际CueStick.clearanceProfile可达性。球号14种覆盖、同源布局跨模式、距离/s/q/侧向/近库覆盖；并测资源缺失/错误模式/SHA损坏、无放回及条件不足。
- 受管standard-phone任务v73-b1-bank；原始b1-r1.log/xml/xcresult位于同轮evidence目录，构建源码身份见B1-source-identity.json。project.yml folder reference与生成工程已实际打包加载。全9342候选的正式验收仍在B5，84题不冒充全库。

## B2 · 会话状态与持久化（已通过）

- SpatialQuizRecord/Session与LocalSpatialQuizRepository共用两模式状态、版本化LZFSE载荷、TrainingSession事务与额度receipt。冻结输入先落盘，同attemptID重试；首答/最新杆/示范分离，共用PracticeDemonstrationProgress。
- r1测试夹具的MainActor标注编译失败已修正；r2的7项通过；r3的9项通过，含两模式循环、首/次成功、三次失败、保存失败、重复回调、技术未确认、重启及owner变更、末题结果、无限续段、真实磁盘损坏保留与生产repository批次回滚。
- r3代表真实路径压缩载荷约136/151KB；合成空间长路径压力验证超1.45MB拒存，530502/529409字节两模式载荷触发512KB原子续段，故障保持旧局。状态测试的判题事实为隔离夹具，不冒充物理复核；B0/B1另有真实物理证据。
- 原始b2-r1/r2/r3.log及xcresult在同轮evidence；无UI验证。

## B3 · 双页面与横尺复用（已通过）

先采集现有自由页原生基线，随后按共享壳/摄像机/渲染配置接线，逐阶段核权限。

### B3阶段证据（尚未关闭）

- 自由页改前基线b3-before通过1项原生测试；共享抽取BTSpatialElevationWheel、SpatialCueElevation、SpatialShotRendering，旧自由页仅委托同算法。b3-build-r3编译及16项物理回归通过。
- b3-ui-r1失败保留：渲染枚举实际rawValue为R，测试误写reflection；第二用例被模拟器Apple账户提示遮挡，未操作账户设置。修正断言和系统提示“以后”处理后，b3-ui-r2两项双模式原生操作均通过（正常入口/四输入横尺/临时俯视只读/设置取消；实际成功、示范、回放和重打）。脚本在运行中编辑导致结束处读取偏移报引号错误；xcodebuild原始结果为TEST SUCCEEDED，helper已通过zsh -n。
- r2相机截图采集时未等待转镜完成，不能作为第一人称最终机位证据；后续增加真实cameraDiagnostics的mode及moving=false守卫。r2默认布局、设置、成功结果已实看原图；其余图不预支通过。
- b3-ui-r3扩展真实三次低速未碰球与模板保留/默认恢复。布局用例在恢复默认后下一次菜单打开失败，保留现场；需复核菜单实际状态与点击，不删除布局断言。
- 增补重进/重打的共享机位书签恢复、计算停止保留冻结输入、无效结果转技术未确认。当前编译版本与后续源码增补分开记录；完整B3及跨尺寸仍未完成。

### B3 跨尺寸与合同复核

- b3-ui-r4：标准手机4/4通过，包含两个模式真实成功、连续三次真实未碰球、个人模板/默认/重新应用、等转镜结束后取图。r3菜单失败由AX目标点击落点不可靠引起，改为实际已测按钮中心点击后原模板断言全部保留并通过；无菜单生产代码改动。
- 相机合同复核撤回“重进入页恢复任意书签”：按v73§7.1.1和TP17恢复题与输入后默认第三人称；书签仅服务重打/回放现场。b3-pad-r2与b3-compact-floor-r2分别1/1通过，覆盖M/J退出重进仍是原题且实际机位thirdPerson。
- b3-pad-r1在SBMainWorkspace preflight Busy阶段未能启动Runner；r2在同设备正常通过。compact-phone被研究租约占用，未使用；改用空闲compact-phone-floor（iOS17.0）。floor-r1附件采集误查设置页不存在的scene诊断节点，修成仅在场景存在时采集；页面上的相机状态断言继续强制。floor-r2通过。
- B3-pad-r2及B3-compact-floor-r2原图已检查：M/J各自默认横尺，iPad横竖各一幅，文字/横尺/主动作完整，无控件重叠；标准手机M/J高抬杆第一人称、真实失败、示范与跳球重打原图已看。临时俯视外透明透出球房，遵循11月25日TP16覆盖。
- 原生20条诊断汇总：evidence/B3-runtime-wiring.json；两尺寸M/J实际recipe=liveReference、profile=R、p01=true；第一人称moving=false，真实cueLift约53.09°/55.33°，cueAddressAlignment约1。未把临时叠层当作多主宿主。
- 复核补齐首答精确输入与事件事实，避免最近复练替换后失去首答证据；新增编码往返后首答input/facts不变断言。b3-regression-r1正在验证；其逻辑测试宿主首启遇到preflight Busy，UI继续执行，逻辑用例需另跑，不能记全绿。

- b3-logic-r2：10.887s完成9项空间会话回归；准度记录5项通过，既有需显式请求的诊断导出1项跳过（不是新功能通过项）。新增首答input/facts不可覆盖断言通过。
- b3-regression-r1整轮启动preflight Busy导致逻辑宿主/7个UI均未进入页面，退出失败。拆分后b3-logic-r2成功，b3-ui-regression-r2横尺/贴库自动抬杆2项通过；自由页添球测试继承旧本地空间档案，原_3已在桌（数量4不增加），准度重入已直接恢复题目而原测试仍等start按钮。已保留B3-accuracy-reentry-live.png证明实际位于准度原题。测试接入既有SPATIAL_TEST_SESSION独立域，准度入口显式等待设置或球桌再核相同状态；未删业务断言。r2已主动中止（130），避免继续运行继承旧空间档案的用例；r3用隔离域复跑。

### B3 收尾回归

- b3-ui-regression-r3：5/6通过。自由页添移球/实际击球/重打/回放/开球/飞台恢复和准度往返均通过；双新页四输入、唯一主宿主、三个球draggable=false、临时俯视前后同rendererID、后台/重进入题保持通过。10条真实宿主快照见evidence/B3-host-identity.json。
- 唯一失败为旧自由页打点微调测试硬写0.01；现行SpinPadMath.step为0.5/100=0.005，生产BTSpinPad无本次改动。修正预期仍以同精度验证，b3-free-final完整重跑中。b3-ui-regression-r2被中止导致xcresult未封口，保留原日志，不宣称其附件可导出。
- b3-final-logic：11项空间状态＋10项既有额度测试共21/21通过；包含权益降级后已答题继续复练、提前结束后查看末题不能再开新题、跨日与最后额度、重复凭证恢复。
- 原生视觉报告：../ui-reviews/UR-20261126-spatial-quiz.md。补看r4扎杆重打及r3自由页默认横尺，角度/横尺/左右HUD完整；未改题面尺寸或相机取景算法。源码快照evidence/B3-source-identity.json。
- b3-free-final微调断言已通过，随后暴露XCUI滑块近似拖动：请求50%实际到56%。加入依据实际normalizedSliderPosition反馈修正的原生拖动，仍严格断言0/50/100%，未写生产偏好或放宽阈值；b3-free-final-r2重跑。
- 后续r2/r3实证否定上述补偿方案：系统拖动来回越过中点，不能将XCUI近似目标当产品精确值合同。已撤回补偿循环，保留0/100%精确端点；中间值改核实际AX百分比与View传给共用打点盘的真实opacity一致（仅容许整数百分比四舍五入误差），并保留回中/微调/保存断言。此为测试前提修正，不是产品透明度算法改动。r4 Runner preflight Busy，r5真实菜单AX激活在布局取消后未打开；revealMenu增加实际可见按钮中心点击及菜单存在守卫。r6因本轮预启动设备尚未关机未入测，已以独占生命周期回收本轮开机状态；预启动wrapper现在finally归还，仅关闭自己在租约内启动的设备。
- 额度复查修正不限题权益失效门控：已完成题仍可查看/重打/回放/示范，继续新题才提示Pro；状态层同步阻止绕过，新增降级后首答/额度保持测试，待下轮验证。

- B3最终门禁：b3-free-final-r7 1/1通过（134秒）；连同r2横尺/贴库、r3四项旧页＋双新页、r4四项双模式、pad/floor和21项状态/额度回归，B3全部DoD关闭。B5最终矩阵与性能仍未验。

## B4 · 历史、owner与同步（已通过）

沿现有TrainingSession和透明payload协议，不新增schema或改变同步同意门禁；按本段首答摘要展示，旧规则结果冻结，兼容性仅决定能否继续活动练习。

- b4-data-r1：39/39通过（6项新增集成＋11项空间状态＋22项既有历史）。两模式历史/本月活动与草稿边界、旧判定/题库冻结、损坏与不兼容记录不阻断合法续练、已知载荷owner内外迁移与失败回滚、未知载荷保留、真实DTO/base64编码均验证。
- B4-http-mongo：使用Swift测试导出的实际DTO（扎杆331192B、跳球250456B压缩空间轨迹）调用现有Express路由与本机一次性MongoDB；两kind与未知kind共21个操作合同检查通过。503重试、同ID上传幂等、Mongo原字节、分页读取、更新、账号隔离和重复删除；报告evidence/B4-http-mongo.json，原始日志同名.log。无生产URL/凭证/数据，HTTP与Mongo已关闭。
- Swift生产队列/Restore的失败重试与待删防复活、双模式原生历史展示仍在补验；B4未提前关闭。

- b4-sync-r1：1/1通过，调用真实SyncQueueManager/SyncRestoreService，窄网络协议注入断网/删除失败；新两kind与未知kind上传重试、DTO恢复、待删防复活、重试删除均过。与上述真实本机HTTP/Mongo为两个互补层，不冒称生产云端端到端验证。
- 原生历史r1搜索入口返回时Tab不可点击；r2改正常进阶入口已进入历史并找到行，子文本断言因SwiftUI AX聚合层级不符失败。新历史行显式children.combine，验证完整标题/本段首答摘要的读屏语义，r3补验中。

- b4-history-ui-r3：1/1通过，两个模式真实击球后重打、退出并进历史，完整摘要AX验证通过。两张历史原图已查看，标题/首答题数/成功率/时长正确。B4关闭。

## B5 · 全库与联合验收（已通过，原失败历程保留）

- 当前冻结题库9342题全参考复验运行中（b5-full-bank-r1）；逐条可达性、完整性和当前判据，不做扰动测试，不改在途研究。

- b5-full-bank-r1：9342/9342完成，扎杆1196/1196通过；跳球8131通过、13失败（12目标离台、1母球进袋）、2技术未确认（invalidInput）。全量门禁按实情失败，原结果保留。15条逐题身份/实际输入/判定保存在B5-qualification；没有把技术失败说成无解。下一轮额外复算失败题的完整事件事实以复核排除依据。
- freeze.py校验审核报告对应原候选包SHA、全ID集合与计数后导出正式包：扎杆1196、跳球8131，合计9327。manifest新增verification；研究snapshot和在途研究不写。b5-final-bank用重打包后的当前构建再次跑全库及判题/状态/集成/额度。
- B5-pad-r1因测试辅助函数NSStringFromCGRect在当前SDK已更名而编译失败，已用NSCoder.string(for:)替换；r2实际75°第一人称、横竖与只读拖放通过，诊断viewport的SwiftUI本地化千位逗号导致解析长度3，已改Text(verbatim:)并保留真实窗口/内容尺寸双断言，r3运行中。
- PROGRESS超过既有100KB门禁，按原文归档11月22日CB-01预览与首批候选六条历史，并保留导航链接；在途研究状态不改。verify-doc-size现通过，未抬高阈值。

- b5-final-bank：51/51测试通过，正式包扎杆1196/1196、跳球8131/8131全部当前引擎通过，失败0、未确认0。原排除15题另复现并保留完整事实：12题在确认进袋前已有桌外表面接触、1题母球进袋、2题共享接触求解invalidInput；未改引擎或研究原数据。
- b5-floor-quota-r1：两模式iOS17.0 SE真实第1–15题、末题重打/总结、逐次配额和购买页取消通过1/1。已看扎杆深色设置/末题、跳球总结原图，控件和文本完整。
- b5-background-r1：两模式击球、1/4回放、示范后台/返回通过1/1；原首次提交与玩家轨迹保持。native runtime记录离页后quizVM/quizWorker均为0。
- b5-close-r1：新增真实VM即时取消→原pending重算→首答一次→VM释放及无审核manifest拒绝，2/2单元通过。原生尺寸复核确认共用壳在最大化后真实renderer从[0,0,1210,834]变为[0,32,1210,802]，不是仅诊断格式问题；根因共用iPad额外安全区用了普通padding，背景ignoresSafeArea不能越过这段padding。
- 共用BTTeachingTablePage改为safeAreaPadding，HUD避让不变，背景可填满真实窗口。b5-close-r2双模式真实缩窗/恢复1/1通过，renderer完整恢复[0,0,1210,834]。旧自由页测试仍比较会被iPadOS改变的外层内容安全区，因此改为同时强制实际OS窗口与SceneKit渲染区域完整恢复，保留缩窗时实际SwiftUI内容改变断言，正在补验。
- r1性能测试错误要求八次原生反向拖动完全抵消，实际连续输入残差0.0028°；未量化或更改产品输入，改为重进同冻结夹具后验证精确参考输入再击球。r2同设备/同窗/同三球/同参考输入4组运行通过，静止renderer休眠，退出VM/worker为0。新页杆姿首帧与自由页完整预测首帧含不同工作量，不能将两者当同口径提速；r3补独立杆姿帧回执，使共用渲染回调提供同口径比较，完整预测时间另列。

- b5-close-r3最终：77/77共用相机单元通过（P01 28、TwoView 49），3/3原生通过（M/J高抬杆、真实pinch推进/复位、只读与真实缩窗；旧自由页缩窗回程；同条件四组性能）。原生renderer正确填满1210×834，静止休眠、退出VM/worker及宿主释放。实测与边界见PERFORMANCE.md。
- b5-phone-final：2/2通过，双页真实入口/四输入/三相机/取消设置/重进，以及旧准度从空间页返回后继续答题。
- b5-menus-final：1/1通过（两模式），透明度0/1/中间值及浮层关闭不改输入；实际上一杆路线开/关、冻结详情、正常速度、结束总结不改首答。两张详情原图已核。
- 门禁初轮准确拦截新增路由未登记；审阅两新路由/订阅sheet并登记SpatialQuizView/Settings、两份临时测试写盘面，签名只更新AngleHomeView及新增SpatialQuizView。verify-gate复跑通过（66历史截图/101路由/211写盘面；历史截图未冒充本轮新截图）。
- 共用安全区DR-471/FL-288、统一规范TP03/30与来源、组件技能/UI实施约定均回填；B5正式交付、源码/构建身份、状态边界见DELIVERY.md。所有物理源码SHA与原全量复验一致；最终App内题包与源码资源逐字节一致。
