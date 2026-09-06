# 诊断问题与证据缺口台账

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
