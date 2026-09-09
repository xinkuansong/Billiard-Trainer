# B6 全38场景覆盖审计 — snapshot004

2026-09-08，QA Reviewer独立审计；截止本次读到M2 AX5 template004成功及iPad Light rest001运行归档。读取PLAN-v2、原COVERAGE-PLAN、COVERAGE-STATUS.csv（实际为CSV，不存在同名md）、REMAINING-PRIORITIES-004、当前结果与必要测试体/归档。只诊断覆盖，不做Phase发布验收，不修改业务或共享台账；50规则的“人工完成后才Phase验收”不据此阻止本次授权审计。本文不宣称系统诊断完成，也不把38行或方法数转换为百分比。

## 证据口径

- **C 当前可复核**：004实际run目录现存，含原测试源、选择器、日志、xcresult或相应静态/SQL原件；本文核对目录/必要选择器与结果，引用主控已做的图审，不声称本次重新逐图审了所有截图。
- **H 历史实测**：B1/B2/B3/B4/B5及003有明确历史报告；本次对应旧formal目录未在当前run归档/旧build路径找到时标原件不可重核。历史通过不改成未执行，也不将当前源码冒充当时运行体。旧报告自身仍是可读二级记录。
- **L 本机尚未验/前提未准备**：模拟器正常操作、隔离协议/服务、可控本地交易可以继续；缺注入能力不是“只能人工”。
- **E 外部条件**：指定真实测试身份/服务、真实设备和系统实达等；须提供明确条件/步骤，不能算通过。
- **D 已证实问题 / T 测试失配 / O 预期待定**：失败可形成已完成的诊断分支；不需修好到绿，不因相近分支成功抹去失败。

下表精确路径缩写：`R/name` = `archive/quality-diagnosis/runs/name/`；`O/name` = `archive/quality-diagnosis/observations/name/`；`D/name.md` = `tasks/quality-diagnosis/name.md`。数字SC沿原COVERAGE-PLAN，文字简述不替代原要求。未额外要求每题型×每设备×每错误全排列。

## 逐场景结论

| SC / 原要求 | 已达到的子要求与证据 | 尚缺、分类与最小处理 |
|---|---|---|
| 01 首启 | H：D/B0-B1.md的V50StateMatrixUITests/testFirstLaunchCompletionAndRelaunchPersistence，原B1-001引导与重启不重复成功；M1五根另有C：R/formal-004-m1-light-roots-detail-001 | L：原M2/iOS17正常首次引导无对应已确认实测，不用跳引导的矩阵替代。仅补同一首启方法一轮M2，先核当前方法与完整引导页；不重跑M1。 |
| 02 主要入口 | C：R/formal-004-learning-shells-001、learning-remainder-001/002/003（均带formal-004前缀）共21学理实际操作/下段/返回；根页/计划/模板/工具/拍照/账户现有专项旅程。H：D/ENTRY-COVERAGE-AUDIT.md保留最初route表 | L：旧入口表必须与本表反向核销；设置各正常项目、关于/法律未发布说明、实际图片查看器等不能仅根图算已点。与各域剩余合并，不再跑21页或制作导出；制作排除依据D/CREATION-RETIRED-REACHABILITY.md。 |
| 03 空态/加载异常 | C：R/formal-004-library-search-favorites-001无结果→恢复、空收藏；data-refresh-ui001真实空日；template-boundary001空模板；M1根空计划记录；catalog001空商品→重试恢复为局部证据 | L：加载异常不能伪空集合：StoreKit catch未命中，API层离线不能证明每页面加载失败。只对未覆盖的真实loader补一条确定失败/恢复；当前商品错误注入产生empty，停止相同重试，保留观察能力缺口。空态已有实际CTA不再列未验。 |
| 04 主线 | C：R/formal-004-plan-continuation-002正常15组225/225保存→第二课、A→B→A仍第二课；H：D/B2.md、B2-SELECTORS.md的V54 owner唯一主线/事务失败不多active | 原核心UI及服务要求可分层引用；不再15组重跑。E：真实账号跨设备不由该内存UI证明，但属SC25/26，不额外在此建全UI矩阵。H原件不可重核是可信度限制，非新功能缺口。 |
| 05 自由训练 | H：B1/B5正常选c012→录入→保存→历史跨进程、两runtime/iPad；003 D/CURRENT-JOURNEY-RESULT.md正常磁盘5/15及心得；H V54TrainingTransactionTests/test_injectedSaveFailure_rollsBackEverything_andSameBlockCanRetry失败→重试唯一 | D：QD012未完成组进入结果分母有明确反例，无需重现。L：正常UI context.save失败→重试没有现成注入口，现有saveAction层已覆盖原失败逻辑；明确UI层边界，不破坏磁盘造失败、不要求每保存操作再重复。 |
| 06 今日编排 | C：R/formal-004-today-queue-005三源正常加入/重复不增/上下移/首项禁上移/删pending保留其他源；plan-timer003及plan-continuation002正常开始完成。C：calendar-boundary001昨日归档不自动搬移；H started不可删、冻结角色 | 原主要操作与反例可核销；不再写“三源排序/跨日未做”。跨日是注入日历/服务输入，非真实系统改日期；无需等午夜。 |
| 07 课程推进 | C：R/formal-004-schedule-boundary-001两方法直接preview补洞不跳过、review不倒退、pending/inProgress/abandoned不推进、completed才进；plan-continuation002正常UI。H逆序补洞、末课完成、20回调幂等；精确表D/SC07-BOUNDARY-EVIDENCE-AUDIT.md | 本轮约定核心连续eligible规则已分层诊断，无必要再UI逐组复演每反例。旧“复练预习仍全缺”滞后；原件缺失H需在主报告保留，不能说当前全量跑过。 |
| 08 模板 | C：R/formal-004-template-continuation-007改名/剂量×2、正常6组保存、删源历史名/剂量不变；template-boundary001及m2-ax5-template-boundary004空名/无动作拒存、64字+c037保存同UUID重启，SQL保全；today-queue005加入今日/去重 | 本轮创建编辑删除/空长名/来源冻结/代表AX5要求已分层完成；不应继续列长名与模板磁盘未测。H iPad保存重开，C iPad键盘取消另证。跨owner精确归属引用SC25，非再训6组理由。 |
| 09 磁盘 | H：B1/B5及003真实训练PID重启；C：cognitive-disk-restart002一题原值不变+SQL1/1，template-boundary001、m2模板004同UUID，library-boundary001两次收藏重启，data-goal-cold001同账本/目标5 | 原“内存重fetch不算”已通过真实进程与独立SQL补足代表链；并非所有模块杀进程/任意时点掉电保障。SC05失败层限制保留，不扩为每组合写中强杀。 |
| 10 计时休息 | C：R/formal-004-plan-timer-003计时方法91.885s，暂停6→6/继续7→10/缩小/短后台/+30；rest-background-zero001普通后台61秒跨零清除，新休息59→56；D/TIMER-004-RESULT.md | O：休息是否计入训练累计尚无最终裁定，不能自定oracle。E：真机挂起/锁屏活动与长时漂移另列SC38；本机普通后台到零不能仍称未验。 |
| 11 首页entry计次/千条 | H：B2独立多entry字面表、003 DATA1七场跨页、1000/1000/1000磁盘和两条UI；C：data-refresh-ui001删除A后计次4→2，B/C SQL保持 | D：QD012、QD027统计旧时长；L：千条性能明确计时口径见SC36，不能把未做精准耗时说成千条功能没验。不再播种重复同一反例。 |
| 12 日历/详情修改删除 | H：B2-005正常编辑/取消/非法拒绝/删除重启；C：data-refresh-ui001 9/7空日→8/31 C→9/8、A已有备注-EDIT保存重开、删除A级联无孤儿，template007来源冻结，cold001保留B/C | 原切月/空日/备注修改已补，不要按旧审计继续跑。D：QD024结束时间展示、QD027删后统计不刷；失败分支诊断可结束。 |
| 13 统计kind/单位/范围 | H：B2独立三kind/周月/去重表、003 DATA1正常周/月/年与千场统计；C：data-refresh/cold同账本30分钟1组与中断时50分钟1组对照 | D：QD022平均值周期与单位、QD012分母、QD027刷新，保留。没有数值/单位正确的整体通过。L：仅SC36性能口径另补；不重测QD022直到绿。 |
| 14 目标/偏好 | H：同日多场一天/tool排除、OwnerProfileStore隔离规则；C：data-goal-companion001正常3→5磁盘5但首页3，cold001两进程1/5；calendar-boundary001日历提醒参数 | D：QD028同进程不刷。L：若精确目标owner偏好选择器未覆盖，先核现有V53字段语义（本地设备偏好与账号字段不可混为跨设备）；仅一A/B/guest对照确缺才补。E真实第二设备同步不从本机5推断。 |
| 15 全量内容引用解码 | C：R/formal-004-content-bundle-001五方法5/5，74动作/12计划字面顺序/全部盘面解码/引用UIImage；O/content-bundle-001-installed 891文件SHA；O/content-freshness-004脚本、2341资源/169上游/14源双侧hash与门禁原始JSON | 当前完整性及Bundle层可核销，不再重31方法。D QD009退役资产仍进包；O C1 95warn无法证明生成新鲜度，不为告警制作资产。哈希相同不等于真实渲染/教学正确。 |
| 16 库/收藏 | C：R/formal-004-library-boundary-001精确c009/c012搜索→9球仅c009→重置2、收藏/取消跨进程SQL；library-search-favorites001空集合；H owner收藏隔离 | L：原category精确结果集合未由ballType样本替代，至多在权益c039入口合并一个“走位”类别的字面ID集合；不扩所有分类组合。D QD019搜索图标裁切。 |
| 17 教学12课 | H：D/CONTENT-SAMPLE-REVIEW.md 12课8分类、Free7/Pro5、单/多形/无序列，115杆130引用、20图；C：c042教程006视频三张双形真实配图、两AX5球团管理长文下段 | D QD013–018原文字/参数/图形方向与剂量冲突，QD029双ScrollView布局持续忙导致回F1失败。原分层样本已完成诊断，不因有缺陷而要求再抽12课；未审全图/全文教学正确性不伪称。未到回F1由已证卡顿解释，不重同链追绿。 |
| 18 详情/多形试打/退役 | C：R/formal-004-c042-tryout-001两形真实自由击球/重打/重摆/返回，3球/5球图与运动视频；M1 roots-detail浅深c012正常搜索返回；H iPad详情及退役索引/路由静态 | D c042精讲回F1被QD029阻断；原8/5杆全打完不是原SC18每形证明所必需，不自动加成新验收门槛。退役正常索引不可达有静态路径，包存在QD009不等于正常可见。图片查看器若主要入口归SC02合并一次。 |
| 19 六题型成绩 | C：cognitive-save001五新增保存4过/1零符号失配但真实历史存在，旧角度预测链补第六；cancel001六入口未提交退出空史；repository001同对象幂等、协议失败重试、磁盘新容器；disk-restart002真实PID/SQL1结果1session | D QD023毫米/角度单位错，零符号T保留。L真实context.save故障不可注入，但协议失败已有，不篡改业务凑UI；不能把原计划每题型完整保存中断扩大成每题型磁盘/每错误排列。认知磁盘“尚未做”应核销。 |
| 20 分离角/反射 | H：B3真实物理几何单测与典型模式/力度/打点/袋口UI；C学习图谱与slider；solver-filters002翻袋2/3库无解、反射1/2/3库10/5/1解、下一解循环 | L：反射本例未出现无解，且独立方向/接触/反射/理想真实标签需对照原B3精确方法覆盖，不能由切解推物理正确。最小补仍缺工具的一正常/边界，已有翻袋无解不再重复。 |
| 21 编排/开球 | H：B3 seed架球/九球终位、自由走位非录制击球重打；C三球实际进袋/角色前滑/上一杆、daily正常自动开球/1杆及手动散开局部 | L：普通编排真正下一杆/撤回、一次正常玩法切换/球ID与终位；三球角色前滑不代自由编排。手动开球漏“完成”且后续入口失配，完整交付尚缺，停止相同点击，仅有新AX依据再补一次。禁止录制写资产。 |
| 22 求解战术 | H：防守6解1→2/击球/上一杆，典型遮挡服务例；C tool-constraint-positive/followup001思路真实矩形5解、落点近似141cm；三球完整角色自定义矩形6解、实打进袋/停点屏内/撤销 | L：思路实打/下一解、思路/三球真正空解；默认扇形至今近似，不能报满足。独立物理误差/全半遮挡需复用B3精确判例再只补缺例，不把UI余量52cm当精度实证。每类有界一个依据样本，不无限搜无解。 |
| 23 每日清台 | C：daily-normal001实际自动开球重入；daily-legal-shot001合法1杆0犯规14球；daily-rerack001外关闭保持/确认新摆架磁盘；H服务跨日/失败草稿/完成再来幂等 | L：正常完整胜负终态、完成标记/再来；手动散开未完成交付。未完成终态不能因一次合法杆算完成，也不等于功能失败。仅有界正常结局尝试，未达另一终态用明确fixture/U层旁证并保留正常层缺口，不静默取消。 |
| 24 离线/恢复 | H：V54真实事务saveAction失败重试、单项上传失败保队列再成功、V36恢复锚点不推进/删除不复活；C fixed-offline账户错误保旧及本地正常磁盘旅程 | L：完整App离线→恢复成功缺当前可切换注入；fixture提前停止push/pull不能证明只补待传。可以继续一条P层在途多项失败→重试只补未确认，不能统称等人工。固定网络失败≠系统飞行模式；正常本地浏览不单独证明全断网。 |
| 25 owner | H：V53 guest/A/B资料/收藏/计划/队列隔离与迟到响应、00314方法；C R/formal-004-real-mongo-001真实owner请求体改写落库，D/MONGO-004-RESULT.md | D QD007已当前复现，不再重跑同漏洞；L上传在途关闭/ABA与迟到失败未由下载晚到替代，最多与SC24一条隔离边界合并。E真实客户端跨设备身份恢复需指定测试账号/环境。 |
| 26 迁移/大量恢复 | H：同意/拒绝/失败重试、删除队列/重复ID/增量；旧路由499/500/501/1000；C real-mongo001 500对照及501截断，5项2过3失败 | D QD008真实两端点截断已确认，原完整性要求被缺陷否定，诊断不需反复铺1000重现。E部署服务到iOS跨设备端到端需受控测试身份；本地HTTP/数据库已实测不能写全为Mock。 |
| 27 拍照 | C photo-picker001/ select002/ calibration001/ marks001/ send-original001，正常合成图→长库四角≤2pt→母球1号→撤销重做→确认→3工具交付返回；H Homography金样/权限声明 | D QD030自动提取承诺与手动实现冲突。L退化/短库标定拒绝、改号后完整交付（原send001旧AX残留T）、确认编辑；按原要求至多一正常改号+一退化反例。E真机相机允许拒绝/真实采集；合成图不能全部划E。 |
| 28 音效/回放 | C Release实际支持音频格式0，D/RELEASE-004-RESULT.md；H D/AUDIO-DIAGNOSTIC-REVIEW.md事件/排程源；C十轮视觉运动和原速回放旁证 | D QD020缺素材，实际声音/事件听感不能验证；不要生成新音频以消告警。L现有声音开关正常状态持久化如无证据可一次设置观察；E有合法素材后的真机静音/中断/暂停恢复/同步听感，条件明确。 |
| 29 鉴权 | H AuthState/APIClient隔离无token/过期刷新/临时网络/撤销/迟到结果；C account-failure004真实正常UI固定离线、退出和移除fixture重启游客 | E真实Apple签入/撤销/Keychain—服务器刷新，需要指定身份与隔离服务。迟到失败/ABA本机协议层与SC25合并，不把退出游客说成服务器成功撤销。 |
| 30 资料头像 | H V53部分更新/20字符限制/头像revision2成功后蓝图失败回滚/迟到A不盖B/缓存清理；C account-failure004合法昵称保存失败保旧；H B5正常游客昵称保存重进 | L头像系统选择取消、裁切取消、固定离线上传预览回滚正常UI尚未跑；一合成图正常链足够。E真实上传跨设备缓存需要合成账号/受控服务，不能借fixture默认头像nil声称旧revision非nil回滚UI。 |
| 31 注销隐私 | H 删除顺序/本地补偿/分owner缓存、法律URL校验；C account-failure004确认外取消/确认失败重试仍身份，Release实际法律URL空、包隐私清单 | L授权run日志脱敏审计与正常法律未发布页/关于入口尚需收口；删除成功后App恢复缺UI成功注入。E受控远端账号可删除授权与真实注销后请求拒绝；不能把训练删除8例当注销8例。实际法链空按配置缺口，不擅自发布。 |
| 32 门控 | H Free/forcedPro多类UI、AngleUsageLimiter 20题/日期init重置与Pro绕过；C pending批准后图谱实际解锁 | L真实本地月购前后动作/计划/高级工具三类、到期同进程重新拦截草稿尚未执行；额度最后一题与Pro绕过一链另缺，跨日init服务不证明存活进程午夜刷新。不能仅读标签或强制Pro计真实权益。 |
| 33 购买 | C storekit-cancellation001实际付款取消；pending001等待→同id批准/实时Pro；restore001正常月购→进程重启→恢复失败保Pro→clear重试成功且同id；catalog001空商品局部 | D QD025；T/环境SDK purchase错误clear后重试仍失败，L0/L1/L2已对照停止细分。L商品catch尚未确定注入，empty不能代；E真实Sandbox购买/恢复、Apple商店条件。本地恢复已完成，不再重跑。 |
| 34 浅深/设备 | C M1四独立方法两外观26图配对完成；H M2普通训练/记录/工具、M3根/训练/详情/工具/portrait旋转请求及Dark；C m3-light-rest001日志1/1 15.970s make0、xcresult现存 | iPad Light rest本次刚终态，尚未读取到配对图审结论，不能预报成对视觉通过；只等主控收图。H iPad其他旧原图缺失边界保留，不因此重全矩阵。实际产品仅portrait，原横竖按旋转请求/保持portrait裁定，不新增横屏实现要求。 |
| 35 最大字号/VO | C m2/m3-ax5-longread001各实际下段返回；m3-ax5-template-keyboard002键盘→收起→退出空表；m2-ax5-template-boundary004 139.141s同UUID/SQL完整64字与4图；H M2/iPadCTA计时、昵称及iPad模板保存重开 | D QD019搜索图标裁切已证；不反复追绿。约定代表AX5本机链已分层覆盖，不要求全部字体变大或每长度。E真实VO朗读顺序/标签仍需实际辅助技术运行，AX文本不代实听。 |
| 36 性能稳定 | C performance-launch001五PID启动到CTA中位3.705s/max5.801s；repeated-shot001十轮实际击球/回放视频逐轮核、同PID196 RSS；H千条磁盘两条滚动与统计真实读回/AX采样 | L千条列表/统计独立有界耗时口径尚缺，旧7分钟是XCTest/AX开销，不是产品SLA；只补一次测量/归档，不全遍历重铺数据。D QD026回放目标袋标记上下文错；E真机热耗电/内存长期指标，不以RSS不持续涨宣称无泄漏。 |
| 37 Release | C R/formal-004-release-001优化构建-O/DEBUG0、984文件393.2MiB/权限中文配置扩展资源/包hash，D/RELEASE-004-RESULT.md | D QD009退役板、QD020无音频、QD021空API/法律配置；L普通Release真实启动和残留诊断参数影响尚未验，准备D/RELEASE-RUNTIME-004-PREPARATION.md。原SC不要求发布或签名，不追加发布门槛；E真机分发仅单列不借模拟器证明。 |
| 38 通知系统 | C通知允许/拒绝/拒后重试/关闭OS0；time-preprobe/ui/postprobe001真实UI/重进/OS20:14一致，目标17未输入成功；calendar-boundary001 LA DST01:30→03:30/上海17:30→18:30与23h日归档；rest-background-zero001跨零 | T时间滚轮17目标没实现，当前14三层一致，停止无依据变体；不定提醒持久化缺陷。L目标变化是否需重排提醒须按实际协议/既有偏好方法核销，不能把日归档方法当目标调度；E锁屏真实送达/LiveActivity恢复结束/系统挂起，真机且通知授权和有实际活动前置。 |

## 当前原件与方法强度抽查

本次实际读了R/formal-004-schedule-boundary-001/selectors.txt：两个方法为ScheduleBoundaryDiagnosticTests/testFrozenPreviewAfterReorderAndGapCompletionCannotSkipCurrentLesson及testReviewCannotRollbackAndOnlyCompletedEligibleStateAdvances；实际运行/服务输入边界见D/SCHEDULE-BOUNDARY-004-RESULT.md。不把completed直接赋值当UI录完课。

R/formal-004-content-bundle-001/selectors.txt确为DrillContentValidationTests的count74/allIndexed、V21W5PlanContentTests/testOfficialPlanShelfOrderFollowsIndex、DrillTryoutBoardStoreTests/test_allBundledBoards_decodeAndInRange、TutorialFiguresBundleTests/test_referencedTutorialImages_allResolveFromBundle。原Board断言数量下限不是98准确数，由O/content-bundle-001-installed独立SHA补强，不造新测试数。

R/formal-004-m2-ax5-template-boundary-004/selectors.txt为TemplateBoundaryDiagnosticUITests/testInvalidDraftsLongNameAndOneDrillTemplateSurviveProcessRestart。方法有空名/无动作拒存、同UUID完整值和c037剂量重启断言，不是仅截图根页；前3次测试失配原件仍各有xcresult。R/formal-004-m3-light-rest-001/exit.json make0，xcode-test.log末尾1 test/0 failures/15.970s，本次只是终态核对，等配图审查。

此前本独立审计已全文核阅并可复用的断言审查：D/SC07-BOUNDARY-EVIDENCE-AUDIT.md、DATA-SC11-14-EVIDENCE-AUDIT.md、CONTENT-BUNDLE-004-PREPARATION.md、MATRIX-004-REMAINDER-AUDIT.md、ENTITLEMENT-AVATAR-004-PREPARATION.md。后两份早期设备不存在/未执行描述以本表当前新run覆盖；不把准备文档当通过依据。本文不是重新对所有38SC每方法做一次源码全量审查。

## 必须从旧台账扣除的过时缺口

COVERAGE-STATUS.csv每行append保留历史过程，以下旧语句不能再作为下一待办：SC02/20“最后5理论/菜单运行中、其余17入口未验”；SC03/16“未验收藏重启/取消”；SC04/06“开始/排序未验”；SC07“preview/review反例未覆盖”；SC08“空长名/模板重启待核”；SC09/19“认知没有真实PID重启”；SC11/12“目标补验未终态、正常统计UI/千场未验”；SC14“修改目标未验”；SC15“当前Bundle未解码”；SC27“没点图/四角和发送未验”；SC34“新M1Dark尚未跑”；SC35“两设备AX5长文/紧凑模板仍缺”；SC38“日历/DST/普通后台到零未验”。保留旧句为历史，不覆盖原失败，只让下一选择器依据最新终态。

REMAINING-PRIORITIES-004的包1已执行；包5大量减项，iPad rest终态正在由主控收图；包7注入日历已闭合。D/ENTRY-COVERAGE-AUDIT.md仅旧入口地图，不可按其“未测”整表重跑。D/SC07-BOUNDARY-EVIDENCE-AUDIT.md所提两新增反例现在已2/2。D/DATA-SC11-14-EVIDENCE-AUDIT.md A/B均已执行且形成QD027/028和独立cold恢复，不再做第三遍同删除/目标样本。

## 有限下一步清单（诊断，不修到绿）

1. **收当前矩阵尾项**：iPad Light rest配图审查；M2首启若确无证据只一方法；原M2系统权限代表未见准确run则一次拒绝/说明。既有AX5模板/长文及M1Dark不重跑。
2. **权益/头像**：已准备的A三类正常本地购买→到期同进程拦截；额度近满一题链；头像一个合成图选择/裁切取消与固定离线上传回滚。分类精确集合与c039入口并行合并，不穷举。正常购买恢复/SDK错误clear再试不重复。
3. **工具**：思路正常实打/下一解；尚缺工具的真正无解/默认约束代表，使用事前有依据的一个输入；编排真实下一杆/撤回与玩法切换；独立遮挡/反射金样先核旧B3方法再补真正缺例。每工具正常+边界为原范围，不按失败不停枚举。
4. **清台/照片**：只有新AX证据才补一次手动开球→完成交付；正常胜负与完成标记仍要给有限尝试的结果，不能删范围；合成图改号后交付+一退化角反例及图片查看器正常入口，复用已有合成图不制作资产。QD029同精讲链不重跑。
5. **剩余本机服务/隐私**：一条上传在途多项失败重试，旧owner/下载迟到不重复；目标与提醒具体字段oracle先核清，不改系统时间。设置声音、关于/法律等正常入口与已授权run日志脱敏只读审计合并，不能外发反馈/评价或联网真实账号。
6. **Release与千条性能**：当前优化包一次正常启动及严格参数影响对照；千条已有盘可安全识别才一次明确计时/内存口径，否则先记录原件/容器前置，不能用旧XCTest总耗时充SLA。五冷启动/十轮运动不再跑。
7. **主报告与外部清单**：将明确问题按用户影响排优先级，H/C来源分开，所有未完成层列出条件和步骤。主控终态后更新其共享账本；本文件只提供审计，不代替主报告，也不宣布可执行工作已全部结束。

真实外部批至少需要：指定可变更/可删除的测试身份及隔离服务（认证/资料/注销/跨设备迁移）、本地之外的Sandbox账号和实际设备（购买/到期/恢复）、真机相机/授权（采集允许拒绝）、通知授权与真实LiveActivity（锁屏/前后台恢复/结束）、有合法音频素材后的静音/中断/听感、VO实际朗读顺序、真机固定性能观测。未提供条件不调用用户真实账号。声音素材/法律链接等缺失是产品输入缺口，清楚列原因即可，不能伪装成已通过。

结论：本轮已积累足够证据形成有价值的阶段诊断，但仍有本机可执行的原范围缺口；现在不能把B6文档完成当系统诊断目标完成。明确缺陷的分支可以收口，未知/环境/失配要分别留下，不用总体通过率掩盖。
