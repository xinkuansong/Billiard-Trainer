# 诊断问题与证据缺口台账

## 最新新增 QD-031：资料离线保存提示直接显示系统错误码（P2）

2026-09-08 snapshot004，formal-004-avatar-boundary-001正常选合成图→裁切→使用，固定离线API前置抛出notConnectedToInternet。完整失败PNG/AX显示“个人资料未保存”及“未能完成操作。（NSURLErrorDomain 错误-1009。）”，仅有“知道了”。用户无法从提示直接知道是离线以及可以联网后重试；没有发现本例数据丢失，默认头像恢复及再次操作已验。

根因路径：冻结QiuJi/Data/Services/AvatarStore.swift:118将error.localizedDescription赋给errorMessage，PersonalInfoView.swift:57–65直接展示。OwnerProfileStore.swift:139也直接透传，既有ACCOUNT-FAILURE-004-RESULT记录昵称失败-1009；本条以当前头像完整图为已复核实证，不声称所有网络错误必有同样文本。

预期依据为项目QA网络失败应有友好提示的约定，以及诊断异常恢复范围。建议修复阶段对离线、超时等错误提供明确中文原因与重试建议，保留现有旧值回滚；本次不改业务。证据：archive/quality-diagnosis/runs/formal-004-avatar-boundary-001/screenshots/avatar-boundary-F3964B09-34AF-40C0-AAF8-20C7BF8D4A80-12-upload-failure-before-dismiss-or-cleanup.png及同名txt，详AVATAR-004-RESULT.md。

截至 2026-09-05：QD-007/008 已在隔离路由执行中复现缺口，实际数据库/客户端影响仍待验证；其余区分测试、文档和资产问题。

| ID | 类别/影响 | 证据与现象 | 状态/下一步 |
|---|---|---|---|
| QD-001 | 测试缺口，高可信；可能漏报历史 UI 故障 | P6_HistoryStatsUITests 月份导航、星期标签缺少有效结果断言，统计入口缺失可 return；见摸底报告 §3C | 已静态确认；不能计作对应行为通过，安排独立 UI 验证 |
| QD-002 | 证据边界，高可信 | V54TrainingTransactionTests 的 restart 样本在同一内存容器重新 fetch，不是杀进程磁盘恢复 | 检查其他持久化用例并补完整旅程证据，非认定持久化出错 |
| QD-003 | 文档漂移，高可信 | 契约 §8.8 旧“不能推进”与当前推进实现/§9.2 并存；后端规范 Jest 与实际 node:test 不同 | 按现行决策和实测定预期，不改历史文档 |
| QD-004 | 测试前提，高可信 | launchClean 跳过 onboarding 且仅重置 Debug Premium，不清空所有数据 | 普通套件不能证明首次使用或清空数据状态；用专用设备/明确 fixture |
| QD-005 | 测试运行风险，筛查级可信 | 133 个文件匹配写盘模式，含正式路径/旧绝对路径类别 | 使用逐项审核选择器；保留制作开关原状态，不整 target 盲跑 |
| QD-006 | 内容证据缺口，待语义核对 | RUN-001 内容 gate FAIL 0，但 C1 95 提示、I7 11 提示、I9 3 豁免/5 提示 | 审计提示类型与来源，暂不当作产品缺陷或忽略 |

产品缺陷确认后记录独立复现、预期依据、影响、版本和证据，并按用户影响排序。不得用修复或删除失败用例关闭本专题记录。


## QD-007：训练更新端点允许请求体变更 owner（高优先级风险）

- 预期：已认证用户可修改自己的训练内容，不能自行把数据归属写成另一个账号。
- RUN-003 使用账号 A token，对 A 的记录 PUT userId=B；实际路由在 owner=A 查询后把原始 body 直接传给 findOneAndUpdate，HTTP 200 返回 B。
- 根因证据：backend/src/routes/trainingSession.js PUT /:id 的更新对象为 req.body；TrainingSession schema 的 userId 非 immutable。查询限定归属不等同禁止更新归属。
- 影响：可能把自身记录转入其他已知账号的数据集，污染归属；不是已证明能读取或修改 B 的原有记录，也不声称当前 App UI 会发送该字段。
- 可信度：路由层高，真实 MongoDB 持久化待验证。建议首发前修复并补真实数据库隔离回归；本轮不修复。

## QD-008：超过500条的全量恢复缺少分页（高优先级数据完整性风险）

- 预期：账号历史恢复应可遍历全部数据，不应无提示遗漏上限外记录。
- RUN-003：501条不同日期记录，GET 返回500；按客户端最大 updatedAt 继续 after 请求返回0，合并仍500。
- 根因链：训练与角度 GET limit(500)、按 date 倒序；SyncRestoreService 只请求一次并按最大 updatedAt 推进锚点，没有下一页协议。
- 影响：长时间使用/换设备恢复时较早记录可能无法恢复，后续增量也补不回该样本。服务端原数据未被删除，不应表述为永久删除。
- 可信度：路由算法复现 + 客户端静态链路高；真实数据库/501条真客户端恢复未执行。需补集成验证和分页方案，当前不修改。

## QD-009：下架盘面进入 Debug 包（资产残留，影响待定）

- RUN-002 构建包中实测存在 c002/c006/c007/c062/c066 六份盘面 JSON，清单见 EXECUTIONS.md。
- 正式动作索引和 Drill JSON 不含它们，上游保留符合裁定；包内存在不等同公开入口可达。
- 下一步核对下架裁定范围、正常入口和 Release 包；不擅自删除。


## QD-010：游客权益测试被旧文案断言提前中断

- RUN-004 的 V50StateMatrixUITests.swift:43 要求独立 StaticText“游客模式”；当前 ProfileView 展示“游客模式 · 点击登录”，并给 profile.login 设置组合 AX label。
- 实测 profile.login 存在，下一条旧文本断言失败；其后的免费动作门控/forced Pro 解锁尚未执行。
- 分类：测试失配，高可信；不据此认定游客或权益功能失败。应通过独立诊断用例或实际 UI 核验补齐，保留原失败。

## QD-011：正常训练诊断漏切单项视图

- FORMAL-B1-001在“标记完成”不可达处失败；录屏20秒表明实际仍为总览，底栏提供切换入口。
- 分类：新增诊断测试步骤缺失，高可信；不是已证明的App完成按钮缺陷。后续保存/重启未执行。
- 002补正常切换与AX/画面核对，保留001原始失败，不改业务代码。

## QD-012：提前结束把未操作组保存并展示为已完成（P1）

- FORMAL-B1-003同唯一备注：训练中1/8组，保存并重启后历史8组全部绿勾；截图已由主控与独立审查目视。
- 保存遍历全部录入行，DrillSet/DTO无完成状态；历史无条件打勾，统计累加全部组及目标次数。与历史“完成组数”及真实成绩契约不符。
- 影响：夸大已完成组数，非零成绩可能被未操作行分母稀释。当前已实测0分样本，非零FORMAL-B2-002运行中；同步影响尚未实传。
- 可信度高。详PARTIAL-TRAINING-FINDING.md；保留完成但全失败的0分组，后续修复不能简单过滤0。本轮不修复。

QD-012补证：FORMAL-B2-002首组5/15、仅1/8组完成；历史实际5/120、4%、8组全绿勾。同marker QD-3A760F98，真实重启后重复确认。历史准确率影响已实测；统计页仍待UI核对。

QD-007/008正式复验：FORMAL-B4-ROUTES已在snapshot002真实路由+临时依赖+模型替身复现。训练PUT owner变更200；两类历史的501/1000与同updatedAt样本截断500，499/500对照完整。详B4.md与result.json。仍无真实Mongo或真客户端恢复证明。

## QD-013～018：12课教学分层抽样发现

详细证据及逐课边界见CONTENT-SAMPLE-REVIEW.md，独立计算/源hash位于content-sample。主控已复核c070原文、c022两图速度、c042第6杆及c085第3杆图片和数值。

| ID | 分类/优先级 | 已确认范围及限制 |
|---|---|---|
| QD-013 | 内容缺陷 P2，CS01 | c070前文要求清一色→黑八→另一色，计分却清己方+黑八即胜；同课自相矛盾，无需套外部规则。 |
| QD-014 | 内容缺陷 P2，CS02 | c022称换形力度不变，序列/params/两图实际2.1和1.4m/s。 |
| QD-015 | 内容方向冲突 P2，CS03 | c042第6杆自检称上半台为失败，after.x=.697913及示范图路线在上半台；按当前竖屏坐标核对，不推断动态回旋因果。 |
| QD-016 | 内容方向/口令 P2，CS04 | c085第3杆3号球实为左上却写右上；第4杆约一皮头与spin折算3.818mm不同，口头皮头定义待专家统一。 |
| QD-017 | 预期待确认，CS05 | c065/c070正文每组10局，默认剂量分别8×15/8×8，填写表自身也冲突；清台球数采集承诺未验，不擅定正确数字。 |
| QD-018 | 文档/工具漂移，CS06 | 中袋旧归一化坐标与当前代码/米制表相差15.072mm；不据此认定全部引擎或教学角度错误。 |

本抽样查12课/115杆参数/130引用，实际看20图；未把其余110图或全库教学记为通过。

## QD-019：最大辅助字号下搜索图标放大并被裁切（P2）

- 冻结snapshot-002，M2 SE3/iOS17.0 Light，系统content_size从large改为accessibility-extra-extra-extra-large并读回。FORMAL-B5-M2-AX5-ROOT五根1方法通过，但动作库及练习搜索栏放大镜明显放大，上下被固定栏裁切；默认字号对照完整。
- 主控与独立审查均已目视。证据：formal-b5-m2-ax5-root/screenshots/root-library.png、root-practice.png，对照m2-light-root同名文件；B5-M2-AX5-REVIEW.md。
- 共享BTLibrarySearchBar固定44pt高并clip，Image没有显式固定字体；多数字体Token则为Font.system(size:)，表现为图标放大而正文多数保持原尺寸。
- 确认范围：上述两搜索栏的可见裁切，不据此认定搜索输入功能失败。另记可访问性体验限制：代表根页正文未明显响应系统最大字号；当前可点击/未溢出不等同大字阅读支持，是否修改固定字体体系留后续产品/修复决策。
- 不改业务；待iPad同条件对照确定波及范围，VoiceOver实听尚未完成。

## QD-020：击球音效四类资源全部缺失（未交付能力，首发范围待裁定）

- 主控只读枚举冻结QiuJi及实际Debug球迹.app，支持的caf/wav/m4a/mp3/aiff均0文件；Audio内只有CREDITS、RECORDING-PLAN及副本三份Markdown。见build/quality-diagnosis/audio-resource-observation.json。
- ShotSoundBank所需sfx_cue_strike/sfx_ball_hit/sfx_cushion/sfx_pocket四池均无候选；bank.play缺池直接return。UI默认启用击球音效，不代表存在声音。当前不能进行音效样本解码/听感交付验收。
- 资产说明已明确等待实录，分类为已有准备计划尚未交付的能力，而非未知播放引擎崩溃；是否必须首发具备按产品范围裁定。不能以视觉回放通过或优雅静音关闭此缺口。
- 详AUDIO-DIAGNOSTIC-REVIEW.md。静音开关、休息后台共享AudioSession的风险仅静态分析，未伪称真机实听/中断恢复复现。独立资源测试草稿已注册未执行，Release包待检查。本轮不制作或替换素材。

## QD-021：冻结Release产物API地址为空（P1，发布配置阻碍）

- FORMAL-B5-RELEASE-001实际Info.plist API_BASE_URL非未展开变量，但为空、无scheme/host；构建-O且xcode0。证据package-audit.json和RELEASE-RESULT.md。
- B0 source-before/formal-baseline的Secrets哈希一致，4838复制输入drift/mismatch为空；未见有意脱敏记录。不支持把此结果解释为诊断自行删空。没有读取或展示Secrets内容。
- 已证实的是该冻结Release产物没有可用的绝对API地址配置；尚未实启请求、未确认原赋值/展开/覆盖具体根因，不外推当前工作区或真实部署配置。AppConfig对URL(string:)的宽松解析不能替代scheme/host校验。
- 两个法律链接亦空，保持未上线的准备状态；微信延期入口不要求提前实现。该项不触发业务修复、秘密查看或发布。

## Release产物补证（既有问题）

- QD009六份retired盘面全部存在于实际Release包，正常用户可达性结论仍依CREATION-RETIRED-REACHABILITY，不把存在等同可达。
- QD020实际Release支持格式音频数仍为0，只有三份Audio工作文档；进一步支持资源缺口，不代表播放/听感验收。
- Release二进制精确命中-v50.inMemoryStore、-deeplink.settings、-w7.forceDailyLimit及Near；源码对应无DEBUG隔离，归为测试入口残留风险。尚未证明普通用户可触发或远程可利用；forcePremium相关精确串未命中。不将此静态证据当已复现运行故障。

### QD007/008真实数据库补证（FORMAL-B4-REAL-MONGO-001）

官方MongoDB8.0.29临时独立实例，真实冻结Express/Mongoose模型五项2通过3失败，Node退出1：QD007实际PUT200后数据库owner=B，A列表0/B列表1；两端点500条均完整、501条均首批500且after0、缺最旧1条。实例启动时核验自有PID/dbpath/空库，结束日志确认shutdown complete。没有真实账户/部署连接，仍不等于App客户端端到端同步；旧模型替身证据不删除。见本轮node-test.log/inputs.json/shutdown-evidence.json。


### QD012 当前快照复验（2026-09-07）

[当前版保存复验](CURRENT-PARTIAL-RESULT.md)：snapshot-003 实际 3 方法，2 失败/1 对照通过。仅完成一组后仍保存八组，5/15 被稀释为 5/120；零分完成组仍应保留。缺陷继续开放，未修复。


## QD-022：统计平均训练的计算周期与显示单位不一致（P2）

2026-09-07，snapshot-003；DATA1真实磁盘UI001的月/年截图与当前源码双重确认，未修复。

- 月滚动区间105分钟（1.75小时），头部显示“平均训练0.4小时/月”；计算为105/(60×4)=0.4375，已按4周折算却仍标月。
- 年滚动区间185分钟（3.0833小时），头部显示“0.1小时/年”；计算为185/(60×52)=0.05929，已按52周折算却仍标年。
- `StatisticsViewModel.averageDurationHoursPerPeriod`（200行）与`periodLabel`（382–384行）存在口径/量纲不一致。图表均值线又独立按bar平均（StatisticsView.swift:307），并非共享同一指标。
- 用户影响：切换统计范围后，平均训练数字看似骤降，难以正确理解投入量；总分钟/天数/组数本批仍正确，不能扩大为所有统计错误。
- 预期最低要求：平均值、单位与图表说明采用明确一致的周期。最终要展示周均、月均还是周期总量需产品口径裁定，本诊断不自行修公式或改标签。
- 证据：formal-resume-data1-ui-001/screenshots 中 `statistics-月-before-bind` 与 `statistics-年-before-bind` PNG/AX；主控与独立图审均实际查看。原UI测试没有平均值断言，其通过不覆盖本问题。

### QD012 当前正常磁盘补证（2026-09-07）

CURRENT-JOURNEY-RESULT.md：首组5/15通过实际数字键盘输入、提前结束并保存，两行编号心得完整重启读回；总结及重启历史实际8组、5/120、4%，七个未操作组仍为0/15绿勾。UI001失败在已保存后误等首页按钮，UI002只读补验1/1通过，二者分别保留；该测试定位失败不改变QD012实际画面证据。计时未启动，不证明计时可靠。


## 2026-09-08 主控核验：QD-007 / QD-008 新后端实证

已独立读取 formal-004-real-mongo-001 的 node-test.log、exit.json、shutdown-evidence.json 及 mongod.log。5项实际执行为2通过3失败，Node退出1；不是全部通过。QD-007实际持久化owner由A变B，A读取0条/B读取1条；QD-008的training和angle各自500条完整、501条缺最旧1条。服务器原记录未删除。原始日志确认自有Mongo正常关闭，资料见 [MONGO-004-RESULT.md](MONGO-004-RESULT.md)。这是backend004当前源的隔离数据库证据，不是实际用户账号或iOS恢复端到端验证；两问题保持开放，列为首发前优先修复及补测。旧章节的“真实Mongo待验证”仅表示当时状态。

## QD-023：瞄准点成绩的毫米值在历史详情标为角度（P2）

2026-09-08，snapshot004，认知正常保存批局部实证，未修复。

- 预期：瞄准点题型使用距离误差，题面/反馈/历史的数值单位应一致，不能把毫米误读为角度。
- 源码：AimPointSceneTrainingView.swift:241–242将sCorrect/sUser乘1000存入actualAngle/userAngle，errorMM也按毫米；普通AimPointTrainingView.swift:92–93存correctMM/userMM。AngleSessionDetailView.swift:154–155无题型分支地格式化为%.0f°，平均误差/最佳成绩同样显示°。
- 实际：formal-004-cognitive-save-001的3D瞄准点单方法已通过保存及一题历史读回；主控实际查看history-one-answer-07E0D388-198D-4E58-A74A-002099AAD484.png，标题3D瞄准点训练、总题数1、实际49°/你答0°、平均和最佳49.5°。这里只证明当前3D画面，普通/2D的源码共享风险不能代替各自截图。
- 用户影响：用户无法正确理解偏差大小和训练进步，可能将距离误差当成方向误差；不表示此次记录丢失或数据库数值被改坏。
- 证据位于该run/screenshots和实际xcresult；整批仍在执行，当前不预报全部通过。另2D默认0°断言失败独立调查，不用此单位问题解释未核实的数字差异。

QD023补证：主控查看2D保存失败方法原录屏50秒帧，2D瞄准点一题历史实际55°/你答-0°、平均55.2°，同样将毫米标为角度。该方法失败原因是测试精确0°不匹配-0°，不能称2D丢记录；原失败保留，归档补帧见archive/quality-diagnosis/cognitive-save001-review。

QD023普通题型补证：主控实际打开formal-004-cognitive-save-001普通瞄准点history-one-answer-33F3BEE3-1EBF-4A1E-B0D1-DDD82120E607.png，平均/最佳43.8°、实际44°/你答0°，确认普通题型也受影响；同图pocket原始none直接显示，另记为展示观察，未扩大为成绩丢失。

## QD-024：已结束训练的展示时段从保存时刻向未来延伸（P2）

2026-09-08，snapshot004，未修复。来源为模版连续链007的独立历史图审，不改变该测试方法当前仍在运行的状态。

- 预期：已经结束并保存的训练，其“时段”不应显示为尚未发生的未来训练；保存时间、训练开始时间和累计活跃时长应有明确区别。
- 实际：007正常完成6组30/90并保存后，主控实际查看 `history-before-template-delete.png`，状态栏12:45，历史摘要为29分钟、时段12:40–13:09；对应AX的列表行也为12:40-13:09。run开始于12:04:00，截图附件日志t2500.06s，与查看时刻相符。不是测试把计划结束时间预填成13:09。
- 源码链：`TrainingSession.swift`初始化`date = Date()`；`ActiveTrainingViewModel.saveTraining`在保存时创建session，设置`totalDurationMinutes = elapsedSeconds / 60`，未赋实际开练时刻；`TrainingDetailView.timeRange`把`session.date`直接当开始，再加累计分钟作为结束。因而长训练保存后立即查看会显示未来结束时间。
- 用户影响：历史时段不能准确解释本次训练何时发生；本例成绩30/90与6组读回正确，不据此声称成绩损坏或记录丢失。暂停/休息跨度与训练实际起止如何建模，留待修复设计；不能简单假定活跃分钟等于墙钟跨度。
- 证据：`archive/quality-diagnosis/observations/qd024-template007/`保留实际PNG/AX、3份冻结源及SHA/时间线manifest。是活run中已发生的独立观察，不是run终态归档。尚无本例磁盘或真实同步层验证。
- 后续补测建议：短/长训练各自记录开练、暂停恢复、结束和保存时刻；历史展示的起止与所定义时间口径一致，结束不晚于保存；跨日和延后保存另列边界。本专题仅记录，不修业务。


## QD-025：待批准购买同时显示“购买失败”和“处理中”（P3）

2026-09-08，snapshot004，未修复。

- 预期：待批准是尚未完成的交易状态，提示应区别于已失败，避免用户误以为需重复购买。
- 实际：本地SKTestSession askToBuy实际交易pending=true，正常App购买后alert标题“购买失败”、正文“购买正在处理中，请稍候”。主控目视pending-message-and-local-transaction.png；对应AX和交易状态完整归档。
- 来源链：StoreKitService将pending映射purchasePending错误，SubscriptionManager一般错误分支传文案，订阅页通用购买失败标题；当前测试特意保留真实标题断言以取证，不代表该体验符合预期。
- 影响与边界：状态解释矛盾，可能让用户重复尝试；本例没有提前解锁，批准后实时刷新及实际图谱操作通过。尚未测试用户重复点购买是否产生重复待批准，不推断重复扣款。
- 证据：archive/quality-diagnosis/runs/formal-004-storekit-pending-001，1/1通过77.775秒，1393归档文件；本地商店，不外推真实Apple家庭审批。
- 后续：独立呈现待批准文案和后续说明，再测批准/拒绝、离开重入与重复操作。诊断不修复业务。


### QD009/020/021 Release004当前补证（2026-09-08）

实际Release004优化包重新核实API地址空、法律链接空、音频格式文件0、六份下架盘面残留；不是旧报告转述。新档案991文件、当前冻结5350源变化/缺失均0。权限/隐私/扩展存在不改变上述问题状态，详见[Release004](RELEASE-004-RESULT.md)。


## QD-026：上一杆回放沿用下一杆选袋标记（P2）

2026-09-08，snapshot004，未修复。正常自由击球默认球形，击球后自动选择下一杆，再点击回放。实际十轮抽帧均见黄球回放向左上袋运动，而红色选袋标记仍在右中袋。球体运动正常回放的证据不等于覆盖层正确。

主控复核冻结PositionPlayViewModel.swift:1332–1352，回放保存选中态、清selectionNodes及轨迹，但未隐藏独立pocketMarkers；:718–721用当前selectedPocketIndex更新标记。AngleTrainingScene.swift:1349–1356确认selected才显示标记。用户因此同时看到上一杆动画和下一杆提示，可能误解目标袋。没有证据表明物理轨迹、进袋判断或保存数据出错。

证据：archive/quality-diagnosis/observations/formal-004-repeated-shot-001，原视频、120抽帧、逐轮图审及SHA归档；独立审计REPLAY-OVERLAY-004-AUDIT.md。没有找到自由击球明确规定隐藏/切换标记的规格条文，结论是图像与源码相互支持的显示上下文不一致。后续修复可隐藏回放中的标记或临时显示上杆目标；需保持回放结束后当前局面和下一杆选择，仅记录不实施。


## QD-027：删除训练后统计时长仍包含已删除记录（P2）

2026-09-08，snapshot004，未修复。formal-004-data-refresh-ui-001 实际1方法失败110.220秒，make2；不是通过后追加的猜测。

- 预期：本周A20分钟/B30分钟，删除A后本周总时长应由50降为30，组数由3降为1。
- 实际：正常历史编辑A心得、重新打开确认、正常删除A后，历史仅B30分钟，动作卡已练4→2；统计总时长仍50分钟，组数已为1。主控目视前后完整统计PNG及删除后历史、动作卡；时长图及小时摘要也仍沿用50分钟。
- 独立磁盘：B/C UUID、日期、成绩、时长与删除前账本完全一致；A和两条entry/set已删除，现2sessions/2entries/2sets/0answers，孤儿0。另有A update/delete两条待同步操作，符合LocalTrainingSessionRepository正常enqueue路径，不说队列0或同步已完成。
- 源码支持：StatisticsView.swift:70仅vm.sessions为空且无error时loadSessions；StatisticsViewModel.swift:417加载普通数组，totalDurationMinutes从filteredSessions聚合。保活统计页没有随本例删除重新取列表；子关系变化可更新组数而旧session仍贡献时长。此为源码支持的刷新原因，未通过修改代码验证修复。
- 用户影响：删除后统计仍高估训练量，历史、动作卡和统计互相不一致；本例不属于磁盘删除失败。是否冷启动恢复另由独立补验确认。
- 证据：archive/quality-diagnosis/runs/formal-004-data-refresh-ui-001（1471文件，实际14-49-39 xcresult）；observations/data-refresh-001-before及data-refresh-001-after-failure（数据库/偏好/SQL/SHA）。本例为专用模拟器合成账本上的正常UI操作，不证明真实服务或全设备。
- 补测：删除后同页重入/跨Tab/冷启动的天数、时长、组数、趋势一致；新增/改时长/最后一条删除及周月边界另验。本次不修业务。原方法后面的目标3→5/重启未执行，必须独立补验，不能算通过。


## QD-028：游客修改每周目标后训练首页仍显示旧目标（P2）

2026-09-08，snapshot004，未修复。独立data-goal-companion001实际1失败83.501秒，1395文件归档（15-03-29 xcresult）。目标页正常点5天，主控目视已选5天、1/5；回到训练首页，实际AX仍“本周训练 1 / 3 天，连续训练 1 天”。测试要求1/5，未找到后滚动12次失败；终态PNG位于首页下方，不能冒称该PNG直接显示顶部旧值，旧值来自真实AX。

独立外部偏好已写ownerProfile.guest:c24e68e8-857e-47c4-9cc5-82165b40a01a.weeklyGoalDays=5；五张业务表与先前删除后副本逐行完全相同。因此本例是跨页面更新问题，不能说目标没保存。

源码：TrainingHomeView与ProfileView分别持有独立OwnerProfileStore StateObject。游客setWeeklyGoalDays只更新当前store并persistAll；load(from:)只接受account owner，训练页对auth变化调用该函数不会为guest从defaults重读。首页displayedWeeklyGoalDays使用自身profile.weeklyGoalDays，支持其保留旧3的原因。尚未修改代码验证修复。影响是目标页和首页训练进度口径矛盾；账号用户/所有资料字段不外推。

证据：archive/quality-diagnosis/runs/formal-004-data-goal-companion-001，observations/data-goal-companion-001-after包含原偏好/数据库/verification.json/SHA。当前冷启动独立只读补验正在执行，不先宣称重启恢复。原统计QD027独立保留，两个失败方法都不能算通过。


QD027/028冷启动独立补证：formal-004-data-goal-cold-001实际1/1通过94.581秒、111文件归档。PID60083→60354，home1/5/goal5及统计30分钟1组正常，主控目视两关键图；外部五张表逐行不变、偏好5。说明本例重启恢复显示，原持续进程刷新失败仍开放，并未修复。

## QD-029：双球形精讲滚动后主线程持续布局忙，UI查询超时（P1，根因未定）

2026-09-08，snapshot004，正常Free游客、iPhone17Pro/iOS26.2专用模拟器。formal-004-c042-tutorial-006实际1失败498.452秒、make2；1230文件及实际15-52-20 xcresult已归档。不是001–005定位/诊断代码错误的重复归类。

- 正常入口：动作库搜索初级蛇彩→详情→精讲→球形1第八杆→球形2开局→第五杆。第193.16秒为露出第五杆图注上滚，194.29秒进入idle等待，254.32秒警告；344.36/375.38/406.41秒查询重试，436.75秒因UI查询超时失败。最终XCTest teardown在496.94秒正常调用terminate；没有主控提前杀掉App。
- 已保存两次App74085三秒调用栈（15:58:00与15:59:40），主线程均主要执行SwiftUI ViewGraph/AttributeGraph/LazyVStack布局；一次ps实测CPU100.8%。这些是离散采样，不能写成整段CPU持续100%或泄漏认证。主线程实际忙支持UI响应问题，不是仅找错文字。
- 原录像497.71秒；主控查看200/300/400秒抽帧，页面停留在同一第五杆画面；终态完整PNG第五杆配图和图注可见。时间线/原视频/样本SHA均保留。静态画面本身不证明卡死，需结合持续AX无响应与App主线程样本。
- 候选关联：多球形保留两份ScrollView、长图LazyVStack布局。源码和栈支持关联，但没有定位到唯一业务行；不能认定隐藏F1必为根因，也不能外推所有iOS/真机。详C042-TUTORIAL-006-HANG-AUDIT.md（主控已全文复核）。
- 用户影响：本例长图阅读过程中无法继续完成交互链；回F1位置保留与返回尚未验证。P1为阻断阅读的修复优先级，不代表所有用户必现。
- 已确认的独立内容证据：录像100/135/190秒完整图片分别对应manual01_s08、manual02_initial、manual02_s05；三图并非缺图/串图。此前PNG因图注单独揭露导致图顶裁切，不用它们冒充完整图审。
- 后续最多两个同冻结正常UI对照：直接F2到第五杆；先深读F1再F2到第五杆。两者都保留F1子树，不能称前者单ScrollView。若同类忙复现即取证停止，不改产品、不扩大超时到绿。本轮已足够保留问题和未完成分支；真机重现与根因在修复阶段进一步确认。

证据：archive/quality-diagnosis/runs/formal-004-c042-tutorial-006；observations/c042-tutorial-006-attachments及c042-tutorial-006-review。无业务修复、无发布。

## QD-030：照片导入页承诺自动提取，当前流程实际要求手动标球（P2，文案与能力不符）

2026-09-08 snapshot004，正常练习→打→拍照建球形，formal-004-photo-picker-001 1/1通过28.664秒；主控完整入口PNG/AX已审。页面明确显示“自动提取球号与位置”，但本入口BallExtractionView.loadPhoto只加载UIImage、恢复默认角点、清空marks进入calibrate；下一步markStep要求用户先选球号再点照片，未调用球检测/识别。

- 预期依据：docs/04-功能规划.md F17验收明确手拖四角、点标每球+选号；tasks/phases/P15-photo-ball-extraction.md阶段1为零感知几何竖切，阶段2自动球检测仍后续。按有效规格应准确说明辅助录入能力，不让用户以为上传后已自动识别。
- 用户影响：从入口文案预期自动识别，进入后却需逐球手工操作；可能误认为识别失败或不了解下一步。此为承诺/引导偏差，不把尚未规划交付的识别算法作为必须补实现的缺陷。
- 证据：archive/quality-diagnosis/runs/formal-004-photo-picker-001/screenshots/photo-normal-photo-entry-5C3FD747-5E7F-41BF-B996-ADD7E2B5AE19.png及同名txt；冻结源Features/BallExtraction/Views/BallExtractionView.swift:139、:273、:702。尚未完成完整选图/标球链不影响对现有文案与明确实现的比对；不声称自动识别准确率已测试。
- 建议后续修复优先说明手动标定/标球方式，并复核入口承诺；不在本次诊断改文案或实现识别。


## QD-032：当地日期变化后存活的免费额度实例未刷新（P2，服务层已复现）

2026-09-08 snapshot004，formal-004-quota-day-001：唯一方法失败0.764秒，make2，1366文件含xcresult和五阶段JSON归档。独立UUID defaults、新专用内存宿主，不改业务或系统时钟。

- UTC−12下实际当地日2026-09-07，20次正常recordQuestion后used20/remaining0/已限额；持久键同日20。
- 仅测试进程默认时区切UTC+14，实际当地日2026-09-09；新DateFormatter偏移和显式Gregorian/POSIX日期对照均通过。**创建新对象前**，原对象仍remaining0/已限额。
- 同一独立defaults新建对象正常重置used0/remaining20/未限额，持久键也写新日0；原对象仍20/0/已限额。失败发生在新旧实例一致性的产品断言，而非日期前提。
- 第五阶段确认进程时区恢复Asia/Shanghai，随后抛错；测试仅清理自己的UUID domain。

根因限定：AngleUsageLimiter.init比较日期并重置，remainingToday/isLimitReached仅查看缓存questionsUsedToday，recordQuestion递增时没有先核日期；App页使用长寿命shared。有效规格docs08免费每天20次。潜在用户影响为App持续运行、当地日变化后仍被旧额度限制；用户重启新建对象可能恢复。**没有真实等待午夜、没有系统时区变更通知或SwiftUI刷新实测**，因此不宣称所有跨午夜场景已复现，也不推断时区旅行的产品政策细节。

后续修复方向：明确每日额度使用的日历/时区政策，统一存活实例和持久状态的换日更新，再用正常跨日/前后台UI验证。当前只记录，不修业务、不将失败改绿。详QUOTA-DAY-004-RESULT.md。


## QD-033：图片查看器两种横向手势未翻页（P2，模拟器交互异常已复现，根因待确认）

2026-09-08 snapshot004，正常游客c001精讲首图打开真实六图查看器。iPhone17Pro/iOS26.2专用249B8998-B4A5-4F3C-ACED-173D0C290355。预期依据DrillTutorialView的TabView分页/n-N实现及SC02典型操作/SC18精讲图集行为。

- gesture001：双击放大和复位有完整PNG实证；复位后图内一次横拖，12秒内页码仍1/6，整方法失败52.700秒。
- swipe001独立新进程、不缩放：对真实CollectionView标准swipeLeft，日志明确事件派发，12秒内仍1/6、图片不变，失败54.802秒。随后关闭正常、回原精讲位置≤2pt通过，保留末尾分页失败断言。
- 潜在影响：在查看器内无法顺畅横滑查看下一图，需要关闭回正文再逐图打开；本轮没有验证该替代操作整链。
- 确认边界：目前为两种XCTest输入的模拟器实测，真实触控/其他Runtime未验证；没有认定所有用户必现或唯一业务根因。候选路径为TabView分页与ZoomableContainer的拖动/缩放手势竞争；需解锁后有限手动对照及修复阶段调查。
- 不继续相同手势追绿，不改业务。查看器打开/缩放复位/关闭位置保持分别有局部有效证据，切第二图仍失败。前两次observer定位错误独立保留，非本问题反例。详IMAGE-VIEWER-004-RESULT.md及7张完整图SHA记录。

## QD-034：每日清台完成后重入出现默认盘，HUD仍为0球（P2）

- 实证：2026-09-09，专用iOS26.2，正常四球实际5杆0犯规完成；返回首页再进入，仍显示“今日已清台/剩余0球/5杆0犯规”，台面却出现母球及1、2号球，“击球”AX为enabled。见DAILY-ENDING-004-RESULT.md及observations/daily-resume-20260909-001/05-completed-reentry-default-board.png，连续录像保留重入过程。
- 用户影响：完成状态与可见盘面、操作状态矛盾，可能让用户误以为仍有球未清；未实测异常盘再击球，不推断统计污染或完成丢失。独立completion磁盘正确，再来新局后原完成记录逐字段保持。
- 源码依据：冻结FreePlayView.onAppear先vm.setupScene，PositionPlayViewModel.setupScene→applyDefaultLayout放母球+1/2；DailyClearanceController.start在只有completion时仅设置statusText；strikeEnabled只检isPlaying/isComputing/isFeasible，没有完成态限制。该路径与实际画面一致；未修复。
- 最小复验：正常清台→首页→重入，完成摘要、盘面及动作可用性按产品预期一致；再来启动真实新局且保留当日完成。仅显示何种结束盘可裁定，不应让默认示例盘伪装成已完成盘。
