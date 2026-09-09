# SC02 用户入口反向证据索引

2026-09-08。只读旧ENTRY-COVERAGE-AUDIT、ROOT-REACHABILITY、LEARNING-004-RESULT、CREATION-RETIRED-REACHABILITY、FINAL-SC01-19/20-38及各相关最新RESULT；仅新增本文。未执行测试、操作设备或重审全部图像。旧入口清单中的“10/36已操作”和各早期未测项均是历史检查点，不作为当前计数。

C＝004现存专项归档/结果；H＝旧报告记录执行但当前部分原件无法重核；S＝源码可达性/排除审计，不是UI操作通过。表中报告和run有组合简称（含省略终号前连字符）；精确名称以对应RESULT的selector/归档链接为准，不能机械拼成文件路径。归档根为`archive/quality-diagnosis/runs/`；D为`tasks/quality-diagnosis/`。归档中的selectors、tested-sources、xcode-test.log及xcresult保持真实整方法终态。失败中已到达阶段可以列证据，但不改成整链passed。

此索引回答“用户从哪个入口能查到什么测试证据”，不证明每页全部功能、每个导流CTA或全尺寸全通过。返回只写实际验证的层级，未指定返回证据不从相邻页面推断。

## 五个根与训练入口

| 用户入口 | 有效报告 / RUN | 到达、操作与返回边界 |
|---|---|---|
| 普通首次打开App | M2-STARTUP-004-RESULT / C m2-startup-deny001；SETTINGS-004-RESULT / settings-boundary002 | 普通新磁盘直接训练首页与游客；Root普通为MainTabView，不必经预览Onboarding。H B1-001旧逐页引导与重启不重复保留，不验收当前并行引导改版。 |
| 训练/动作库/练习/记录/我的五Tab | MATRIX-004-RESULT / C m1-light-roots-detail001、m1-dark-roots-detail001；H B5 M2/iPad及ROOT-REACHABILITY | 五根实际进入与代表浅深图，不能据此核销下表二级入口。 |
| 训练→自由训练→选动作→录分→结束心得→保存 | CURRENT-JOURNEY-RESULT / H snapshot003 resume-current-journey-ui001/002；B0-B1/B2 / H B1-003、B2-002；C plan/template正常录分另见下 | 正常c012数字输入5/15、两行心得保存、真实重启历史；原保存后立即回首页预期失配保留。QD012保存未完成组分母错误；真实UI磁盘失败重试未建立，不借正常保存称通过。 |
| 官方计划货架→详情/启用/编排→课程 | PLAN-TEMPLATE/PLAN-CONTINUATION-004-RESULT / C plan-timer003、plan-continuation002 | 首课加入/展开开始，完整15组225/225保存，首课完成/第二当前；A→B→A游标保持。回货架与编排切换为实际操作；不等于所有计划整课。 |
| 今日安排三种来源及菜单 | TODAY-QUEUE-004-RESULT / C today-queue005 | 计划A/自建T/自由L正常加入重复守卫，上下移/首项禁上移，仅删pending L，A/T保留；打开L源详情再回队列。开始由plan-timer003另证，不冒充本方法已训练。 |
| 我的模版货架→新建/编辑→剂量设置→加入今日→删源 | TEMPLATE-CONTINUATION/TEMPLATE-BOUNDARY-004-RESULT / C template-continuation007、template-boundary001、m2-ax5-template-boundary004 | 真实改名/遍数、录6组30/90、删本次模版、历史原名/成绩保持且来源不可点；空名/无动作拒存、64字完整值/正常退出/磁盘重启。QD024时段问题保留。 |
| 活动训练→暂停/休息/+30/整场或休息缩小→恢复→结束 | TIMER/REST-BACKGROUND-004-RESULT / C plan-timer003、rest-background-zero001 | 单调时钟及9状态图；后台自然跨零、回来清除休息，新休息可倒计时；结束到心得。不是系统锁屏LiveActivity或长期漂移验证。 |
| 训练→每日清台→继续/重开 | DAILY-NORMAL/DAILY-SHOT-004-RESULT；FINAL-SC20-38 / C daily-normal001、daily-legal-shot001、daily-rerack001及manual-break后续 | 实际自动开球、合法1杆、返回首页/重入字段保持，取消重开保旧、确认换seed/manualRacked。部分方法取消/自动预期失配保留；2026-09-09正常四球5杆0犯清台、首页完成/重入/再来保留完成已补，见DAILY-ENDING-004-RESULT.md；QD034重入默认盘不一致，正常失败终态未验。 |

## 练习页36个正式卡片

真实分区学9/理12/练6/打4/解5；不是36个完整场景通过。以下正常卡入口归SC02，并分别关联SC17–23/27/28/32。

学习run缩写：L0=learning-shells001，L1=learning-remainder001，L2=learning-remainder002，L3=learning-remainder003。均C，完整标题/交互及返回依据LEARNING-004-RESULT与LEARNING-004-REMAINDER-VISUAL-REVIEW。L1菜单原失败由L3独立补验，不重复计入口。

| 分区 / 卡片 → route | 有效RUN / 报告 | 实际到达操作与返回边界 |
|---|---|---|
| 学·瞄准原理 → aimingPrinciple | C L0 | 下段厚薄示意/数值可见，返回；不是全教学认证。 |
| 学·瞄准方法 → aimingMethods | C L1 | 滑块改变至65°、返回。 |
| 学·瞄准修正 → aimingCorrection | C L1 | 实战启示下段、返回。 |
| 学·旋转与加塞 → spinAndEnglish | C L1 | 杆法切换/斯登切线读数、返回。 |
| 学·角度与瞄准 → angleDynamic | C L1失败局部 + L3补验 | 球库/显示菜单实际打开，正常关闭及返回由L3完成；未宣称所有拖球几何。 |
| 学·分离角图谱 → separationAngleAtlas | C L0；ENTITLEMENT-004-RESULT / entitlement-boundary001 | 轨迹隐藏恢复7/8→8/8及返回；另本地月购/到期门控。不等于每轨迹动力学。 |
| 学·加塞吃库图谱 → cushionEnglishAtlas | C L1 | 实际轨迹开关恢复及返回。 |
| 学·浅谈球感 → ballFeel | C L1 | 指定下段读取/返回；不推所有外链导流。 |
| 学·瞄准点对照表 → contactPointTable | C L2 | 规定对照内容到达/返回。 |
| 理·30°法则 → theoryPage(t01) | C L0 | 滑块/失效边界下段与返回。 |
| 理·90°法则 → theoryPage(t02) | C L2 | 指定下段/返回。 |
| 理·切线法则 → theoryPage(t03) | C L2 | 指定下段/返回。 |
| 理·母球速度分级 → theoryPage(t04) | C L0 | 体系外两端内容/返回。 |
| 理·反向规划 → theoryPage(t05) | C L2 | 指定下段/返回。 |
| 理·关键球原理 → theoryPage(t06) | C L2 | 指定下段/返回。 |
| 理·球团管理 → theoryPage(t07) | C L2；AX5 longread M2/M3 | 指定下段/返回，另有最大辅助字号代表长文；非全部VO。 |
| 理·风险报酬决策矩阵 → theoryPage(t08) | C L3 | 指定下段/返回。 |
| 理·最少加塞原则 → theoryPage(t09) | C L3 | 指定下段/返回。 |
| 理·安全球三维度模型 → theoryPage(t10) | C L3 | 指定下段/返回。 |
| 理·清台5步决策流程 → theoryPage(flow) | C L3 | 指定下段/返回。 |
| 理·清台速查手册 → theoryPage(quickRef) | C L3 | 指定下段/返回。 |
| 练·角度预测 → geometricQuiz | H B3-003；C cognitive-cancel001、quota-boundary001 / COGNITIVE/QUOTA-004-RESULT | H三题17/28/39结束进记录；C未提交退出空史；额度19夹具→实际第20题→被拦→正常本地购买继续，非手答20题。 |
| 练·2D角度 → sceneAiming2D | C cognitive-save001、cancel001、disk-restart002 / COGNITIVE/COGNITIVE-DISK-004-RESULT | 答27保存记录、未提交取消；真实PID重启同题实际15/答27/误差12及SQL关联。 |
| 练·3D角度 → sceneAiming3D | C cognitive-save001、cancel001 | 答38保存/历史及未提交退出；forcedPro，非该卡正常购买全部链。 |
| 练·瞄准点 → aimPointTraining | C cognitive-save001、cancel001 | 默认提交保存/记录及未提交退出；QD023毫米被显示为角度，不是成绩全正确。 |
| 练·2D瞄准点 → aimPointScene2D | C cognitive-save001失败局部、cancel001 | 真实历史1题由录屏核到；0°/-0°断言失配整方法仍失败，取消完成；QD023保留。 |
| 练·3D瞄准点 → aimPointScene3D | C cognitive-save001、cancel001 | 提交保存/历史及未提交退出；默认输入样本不等于全部拖点。 |
| 打·分离角与走位 → shotSimulation | H B3-004 / B3、SOLVER-BOUNDARY-CLOSURE-004-AUDIT | 正常盘击球/回放/重打/返回历史记录；不借其他工具当前图冒充本卡004全重验。声音缺素材QD020。 |
| 打·自由走位 → positionPlayComposer | C composer-continuation001 / COMPOSER-CONTINUATION-004-RESULT；H B3-005 | 正常两杆推进、黄1离台、最近一杆重打恢复第二杆输入；本次结果未声称最后退到练习，H常规返回可分层引用。未录制、非多级撤销。 |
| 打·自由击球 → freePlay | C repeated-shot001、break-mode-observation002、break-delivery001 / PERFORMANCE、BREAK-DELIVERY-004-RESULT | 十轮击球/回放/重打运动；九球玩法→架球→真开球→完成同9ID/中心独立核对。delivery整方法仍失败于额外击球enabled预期，最后回练习未执行；QD026回放袋标记错上下文。 |
| 打·拍照建球形 → ballExtraction | C photo-send-original001、photo-boundary001/002 / PHOTO/PHOTO-BOUNDARY-004-RESULT | 正常PhotosPicker/取消、合成图四角标球、原两球送三工具并返回；退化角拒绝、1改2后送自由走位/返回。QD030文案，真机相机未验。 |
| 解·思路训练 → positionPlaySolver | C tool-constraint-positive001、followup001、silu-shot001 / TOOL-CONSTRAINT、SILU-SHOT-004-RESULT | 矩形完整输入5解，下一解2/5实打/上一杆/无重解3/5；清约束、最近落点141cm边界；返回按各原方法，不认最近解为满足。 |
| 解·打一走二想三 → planThree | C tool-constraint-positive001、followup001 / TOOL-CONSTRAINT-004-RESULT | 五角色完整，默认扇形最近解；自画矩形6解/实际进袋/角色前移/上一杆；正常入口/返回有分层记录，非完整合法零候选。 |
| 解·防守 → snookerTactics | H B3-005 / B3、SOLVER-BOUNDARY-CLOSURE | 默认6解1→2/击球/上一杆/返回；C half-occlusion001只数值层，不充当该页面新UI或全挡求解。 |
| 解·翻袋解球器 → bankShot | C solver-filters002 / SOLVER-FILTERS-004-RESULT；H B3-003 | C自动/1/2/3库筛选、下一解及2/3库真空解、恢复；H自由模式击球/上一杆/返回。 |
| 解·反射解球器 → diamondSystem | C solver-filters002；H B3-004 | C1/2/3库10/5/1解、循环及单解禁切；H击球/上一杆/返回。不强制各模式必须空解。 |

## 动作库、历史、我的二级入口

| 用户入口 | 有效专项 / RUN | 已到达操作和限制 |
|---|---|---|
| 动作库→搜索/走位侧栏/球种菜单/全部重置 | LIBRARY-004、LIBRARY-BOUNDARY-004、LIBRARY-CATEGORY-004-RESULT / C library-search-favorites001、library-boundary001、library-category001 | 无匹配恢复；c009/c012→9球c009→恢复2；完整走位24→直线交集1→重置6。不是仅看根页或遍历全部74UI。 |
| 动作卡→详情→上手试打→返回 | C m1-light/dark-roots-detail001，c042-tryout001 / MATRIX、C042-TRYOUT-004-RESULT | c012正常路径；c042真实选择两形、自由实打/重打/重摆、回详情/库保查询，图与运动不串。未要求完整播放8/5杆新组合。 |
| 详情→精讲→球形切换/长图 | C c042-tutorial006 / C042-TUTORIAL-004-RESULT | 三张两形海报录像已核；QD029布局持续忙498.452s解释回F1/返回未到。前001–005定位/编译失败保留，不能全部当产品缺陷。 |
| 精讲→全屏图片查看器 | C image-viewer-observation003、gesture001、swipe001 / IMAGE-VIEWER-004-RESULT | 正常c001首图1/6、双击放大复位；两种横滑仍1/6为QD033，swipe关闭回原精讲位置≤2pt。未取得第二图，不称图集全部不串。 |
| 详情→收藏 / 我的→我的收藏 | C library-boundary001 | 本次c012收藏重进、真重启，取消后重启空；最终SQL0。owner单测不是此UI切账号证据；收藏仓储补验另见 FAVORITE-OWNER-004-RESULT.md：1/1通过；不等于本行真实账号UI切换。 |
| 详情→加入训练→今日；模版动作选择 | C today-queue005、template-continuation007 | c012实际加入今日、c037由正常Builder选择并编辑剂量；“详情直接加入模版”的每个并列子入口未由这些路线一并证明。 |
| 付费详情→订阅 / 付费计划→确认 | C entitlement-boundary001 / ENTITLEMENT-004-RESULT | 正常本地月购后c039试打、plan_positioning激活确认再取消、图谱操作；到期重新拦截三类。不是实际激活付费计划后完整训练。 |
| 记录→日历切月/空日→训练详情→心得编辑/删除 | C data-refresh-ui001、data-goal-cold001、template-continuation007 / DATA-REFRESH；H B2-005 | 真切月/日期、A备注改名保存重开、删除A级联/保B/C、删源历史冻结。QD024时间、QD027统计不刷；历史数据编辑取消/非法值/删除重启有H证据。 |
| 记录→认知成绩 | C cognitive-save001、disk-restart002；H B3-003 | 上述六题型保存分层、1题磁盘关系；QD023单位错不被“能进入详情”掩盖。 |
| 记录→统计→周/月/年/分类摘要 | H resume-data1-ui001/002；C data-refresh-ui001、data-goal-cold001、thousand-perf-ui002 | 独立七场三范围/千场摘要与正常返回历史；QD022平均周期单位、QD027删后旧时长。不是所有统计图表公式。 |
| 我的游客卡→登录sheet / Apple / 微信 | ACCOUNT-OFFLINE-004-EVIDENCE-AUDIT / H Auth、C相关账户前置 | 游客header正常确认；固定身份fixture不是从Apple/微信登录成功。系统认证及真实身份恢复入口链仍未建立，需指定隔离测试身份/服务条件，不把游客卡可见计登录完成。 |
| 我的→个人信息→改名保存/头像选择裁切 | C account-failure004、avatar-boundary001 / ACCOUNT-FAILURE、AVATAR-004-RESULT | 合成离线身份正常改名失败保旧；选图取消、裁切取消、使用后上传失败回默认并可再次操作/返回重入。QD031直接错误码；非真实头像上传成功。 |
| 我的→训练目标→提醒 | C data-goal-companion001/cold001、m2-startup-deny001、notification系列 / DATA-REFRESH、M2-STARTUP、NOTIFICATION/TIME-004-RESULT | 目标3→5持久化，首页旧值QD028；真实通知允许/拒绝、关闭/重入、独立OS请求。20:17输入未实现、实际20:14保持，不报保存改值；真机送达/跨区未验。 |
| 我的→解锁Pro / 会员状态→恢复购买 | C storekit-cancellation/pending/restore001、entitlement-boundary001 / STOREKIT、ENTITLEMENT-004-RESULT | 正常本地StoreKit购买/取消/pending批准/到期/重启Pro，恢复失败后重试同交易；QD025 pending标题矛盾。固定身份不是真实Apple商店，商品catch未命中、SDK清错重买失败边界仍留。 |
| 我的→偏好设置→击球音效→返回/重启 | C settings-boundary002 / SETTINGS-004-RESULT；release-navigation001 / RELEASE-RUNTIME-004-RESULT | 普通磁盘1→0重入/重启及独立偏好；Release实际优化包正常进入设置再返回。仅该开关不是外观/默认玩法/90°辅助/清缓存全部各点过；QD020无音效素材。 |
| 设置→注销取消/确认/重试；退出登录 | C account-failure004 | 固定离线注销取消、确认失败/再试保身份；正常退出游客、移除fixture真重启游客。未成功删真实账号或服务端资源。 |
| 我的→关于与反馈 | C settings-boundary002 | 版本与安装包一致、法律未发布说明、正常返回。意见反馈/评价外发未点击，属授权排除；没有访问不存在的法律网页。QD021配置范围保留。 |

## 兼容、退役与制作排除

- **theoryIndex**：旧根已取消总卡，保留兼容深链；不是第37个正式练习卡。其单独索引跳页未获当前正常UI证据，不借12理论页替代。
- **TrainingRoute.planList与独立导流**：当前正常货架→详情已实测，不因此声称每个保留planList路由/今日详情箭头/学理页drillDetail导流CTA均操作。按原主要入口而非所有相同目的地全排列；最终需要某条兼容入口时先确认公开触发点，不能凭枚举存在添加新必测矩阵。
- **练习搜索/主题组合、设置其它控件**：旧清单将这些列为横切操作，其每组合并未获得当前精确UI证据。本索引仅列已执行的分区导航和主要页面，不能写所有搜索/外观/默认玩法/辅助线/缓存动作均通过；页面入口已到达与其中每控件行为须分开。无需为SC02入口计数强加全部排列。
- **batchDrillStudio / BatchAuthoring / BatchBallExtraction / export runner**：CREATION-RETIRED-REACHABILITY有ADR-P11-10、D-v46-8与源码调用链依据，内容制作会读/写宿主目录，不属于普通用户诊断执行范围。条件是`targetEnvironment(simulator)`，不是DEBUG；Release模拟器出现不能直接判真机泄漏。普通Composer没有录制/导出调用，不因共享VM就算制作。本文不进入制作台。
- **c002/c006/c007/c062/c066退役内容**：六旧盘面、五ID仍在包为QD009；正常索引/Drill/计划不含，加载不从DrillBoards反向造课程，静态支持普通新用户库/计划/选择器不可达。旧历史、制作侧和任意参数宿主不由此排除；不能删除历史/资产以追绿。
- **Debug/deeplink参数**：属SC37隔离审计；正常Release导航已经执行，不等于残留参数动态对照已做。兼容route/static guard与真机包分发分层，不拿字符串存在证明可触发。

## 使用索引时的硬边界

已证QD029/033可解释后续未达，保留当前模拟器与根因未定范围；Daily正常四球完整终局已补（DAILY-ENDING-004-RESULT.md），保留QD034及正常失败终态未验，不能外推所有玩法。H原件缺失、固定fixture访问、正常业务输入、真实StoreKit本地API、真实服务/真机必须分层。收藏补验终态已由主控审阅，并在SC16/25主表引用；本地内存仓储证据不替代真实账号UI。

本文件仅重建当前入口→证据关系，不新增测试计划、不重排原38场景、不以36卡或五根计算质量覆盖百分比。主报告应链接本索引与两个FINAL-SC表，用户可从任一入口反查已看到什么、哪里失败、哪里尚未验证。
