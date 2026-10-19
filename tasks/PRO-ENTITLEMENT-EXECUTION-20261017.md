# Pro 闭环执行记录

真源：[方案 v1.2](PRO-ENTITLEMENT-PLAN-20261017.md)。本记录仅说明已经实现和实际验证的范围，不替代未完成批次的 DoD。

## 补验进行中（2026-10-19）

用户已授权借用 iOS17 SE、iPad、默认开发机及安装测试版的 iPhone16 Pro。最初将“两个账号”理解为A/B球迹账号，用户后续澄清没有第二个球迹账号；用户随后已创建并登录专用Apple沙盒账号，尚未进行新购买。当前收费范围已由后续 DR408r5 扩为 **11 工具路由、12 项权益**；下方10-17的九工具记录保留为历史证据。

- SE / iOS17.0 的真实 **本地 SKTestSession** 交易5项通过：月/年购买到期、终身恢复、待批准及撤销、恢复中权益标签、月订阅升级终身并存恢复。这里“真实”指实际 StoreKit 测试交易，不是 Apple 沙盒服务器成交。证据：`output/pro-implementation-20261019/se-storekit-summary.json`。
- 扩展回归发现并修复 iOS17 数据事务问题，详见 FL-180。原失败断言保留，三类回归 **43/43通过、0跳过**：`output/pro-implementation-20261019/se-rollback-r4-summary.json`。完整定向回归 **334/334通过，0失败、0跳过**，18类、包含6项本地StoreKit用例：`output/pro-implementation-20261019/se-core-final-r2-summary.json`。
- 主工作区存在其他任务并发修改，曾导致一次混合版本编译失败；本轮采用私有冻结源码 `output/pro-implementation-20261019/frozen-r2`，每次运行保存源文件哈希及 source_changed。修复同步到主工作区；测试结论仅覆盖对应冻结版本。
- SE 三商品实际页面购买及冷启恢复 **3/3通过**（`se-ui-transactions-r1` 的其余1项撤销测试首轮进入首页而非目标深链，后续r7三页面撤销复验通过；不改写首轮失败记录）。SE的12项UI用例现分批通过（矩阵8项+r6品牌1项+三商品3项；r7撤销重复验证不重复计数）。iPad结果见下文；真机A断网冷启单功能已按用户反馈通过，真机沙盒与A/B隔离仍未通过。此前默认机 StoreKit 环境失败不再等同全部本地交易不可验证。H-09 法律链接仍独立待发布。


### ASC 只读核查结论（2026-10-19）

- 球迹App ID 6761309682：月/年/终身实际产品ID均为`com.xinkuan.qiuji.premium.*`并与源码一致；均“准备提交”，销售范围均为所有国家或地区。H-04旧占位ID已按实查更正，不再把文档漂移视为后台ID错误。当前价格配置存在，本轮未读取中国大陆具体金额，不改变价格。
- **明确沙盒前置阻塞**：商务页只有免费App协议“有效（新协议可用）”；提示需更新法律实体信息后签署付费App协议，并提示新版Apple Developer Program许可协议待账户持有人接受。尚无生效的付费协议证据。Apple官方要求付费协议生效后进行沙盒内购测试，须用户亲自处理实体/法律声明，随后重试目录；当前不宣布已成交或整个Pro完成。
- **独立配置问题**：同一个QiuJi Premium群组内月度level 1、年度level 2；同Pro权益仅时长不同应放在同一级，以免套餐切换被误判升级/降级。尚未改ASC，修复应与协议解决后的真实换套餐验收一并记录。群组显示名称区域仅见创建入口；账单宽限期仅见设置入口，均不记已经配置或验收。
- 操作均只读，未接受协议、填法律实体、改商品、改价格或提交审核。证据：`output/pro-implementation-20261019/asc-catalog-audit.json`。官方依据：[沙盒准备](https://developer.apple.com/help/app-review/before-submitting-for-review/configure-in-app-purchases/)、[同权益订阅级别](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/auto-renewable-subscription-information/)。

### 10-19 环境与测试证据注意事项

- 沙盒商品加载阻塞：用户反馈“暂时无法获取购买方案”；当前Release源码该文案对应Product.products空列表（超时/异常另有文案），未据此确定网络或后台根因。H-04历史已完成清单仍写`com.yourname.billiardtrainer.premium.*`，当前代码为`com.xinkuan.qiuji.premium.*`，需以ASC实际商品为准，不能将文档差异当成后台ID错误。Edge沙盒列表可见，但转到App页被重定向登录，等待用户重新验证后只读核查商品/地区/协议。r8仅冷启动采集未触发商品页加载，不把缺少商品日志解释为成功。

- 最新：新沙盒登录后恢复仍为终身，诊断包r6确认该交易 `environment=Xcode`，不是新Apple沙盒成交。隔离工程QiuJiSandboxDiagnostic已在Xcode核对Run=Release、StoreKit Configuration=None，并在iPhone执行Run Without Building；随后独立冷启动诊断r7返回有效权益count=0，旧本地终身交易已不再出现。空权益不证明沙盒成交，仍待手机免费页/商品价格反馈及真实沙盒购买。证据：`device-diag-r6-transactions.log`、`device-diag-r7-transactions.log`、`sandbox-run-transition.json`（均在本轮output目录）。
- 手机当前为临时诊断Release r6，基于包含序号修复的r5，仅私有副本增加无身份信息的交易环境日志；主项目未加入诊断，未清训练数据/购买历史。正常r5保留为`device-release-r5.app`，诊断结束后覆盖恢复。SE/两台iPad此前均观察到Shutdown，无擦除/删除/解保。

- 13寸iPad初轮门控/布局 **2/2功能通过**，截图另发现最大字号权益01折行（不把功能绿当视觉绿）；共享序号栏改为固有宽度+原最小宽度。原设备`ipad13-number-r2` **1/1通过**并目视改后，SE相邻`se-number-r8` **2/2通过**，普通/最大字号原图已核。这些为重复聚焦复验，不累计进12项唯一SE用例。
- 最终`verify-gate-final-r9`仍停在其他任务的`CustomFormationSyncIntegrationTests.swift`写盘登记缺项；内容/资源/DTO/文案通过，未改其他任务基线。

- iPad mini实际系统由结果包记录为iOS26.3.1（Runtime目录名26.3）：核心所选328项为 **325通过/3失败/0跳过**，3项均依赖StoreKit商品，返回空商品或Product为nil；原失败保留。另有6项交易在运行前显式排除。门控11路由与横竖屏/最大辅助字号布局 **2/2通过**，已目视普通/大字竖屏及大字横屏原图，按钮可达，无新增横向截断；付费布局使用明确fixture，不证明成交。
- 默认本机Release的空API行现已修正（Git忽略文件，其余秘密配置未改变）。r4不带API命令行覆盖，构建/签名/API检查通过；r3/r4源码一致，签名后SHA不同。手机保留已装r3，避免中断人工测试。此前r2/r3记录为修正前历史；本机修正不等于发布配置/法律链接验收完成。

- iPhone16 Pro的Release r3已安装并正常启动，签名/API/强制会员标记检查通过。用户报告A显示终身、Apple沙盒尚未登录；随后按断网强退冷启步骤确认A身份/终身/单个Pro功能均正常，该范围按用户反馈通过。后续r6核定当前终身交易为Xcode本地环境，因此该离线结果仅为真机客户端单功能行为证据，不算Apple沙盒离线验收；新购买及A/B隔离未记通过。
- iPad mini / iOS26.3的终身StoreKit探测实际失败：SKInternalErrorDomain 3、notEntitled。后续核心回归明确排除6个真实交易用例，期望328项；这6项保留SE通过证据，iPad端不记通过或用强制会员替代交易。

- 真机Release：r2编译与签名通过，但包内`API_BASE_URL`为空；主工作区及冻结Secrets均为空。安装命令已发出但未启动该包。r3显式传入项目当前后端地址重建，再验证签名、bundle与真实API值通过；这仅是本次验收构建，不代表默认Release配置可发布。强制Pro、虚拟身份及Pro测试路由标记未检出；`subscription.preview`外观字符串仍存在，源码实际预览目的地分支在DEBUG内，不声称所有测试字符串均消失。

- `se-revocation-copy-r7` **1/1通过**，真实本地退款后动作/统计/工具均锁回，已登录统计/工具显示“购买 Pro 或恢复已有的 Apple 购买权益”；未登录分支保留登录提示。此前将两种拒绝状态合并成同一句文案，现仅按既有accessDecision区分文案，不改变授权。已目视同设备改前/改后统计锁态原图。
- 本轮主工作区`verify-gate-r8`：内容/资源/DTO/文案通过，写盘面因另一任务新增`CustomFormationSyncIntegrationTests.swift`未登记而失败。冻结副本不含完整content/docs，不能用于全仓门禁；`verify-gate-frozen-r8`缺上下文失败不解释为App内容回归。

- `se-brand-r6` **1/1通过**，12项权益的免费浅/深与已购状态全部遍历；原`se-ui-final-r5`失败保留。修正测试：限定滚动区域并按精确identifier匹配，避免全App字符串别名查询触发iOS17 AX placeholder日志及诊断崩溃；没有关闭诊断或删除断言。已目视顶栏/商品/状态及末项原图。
- 缓存后续：另一组测试退出后再清4项原授权缓存，累计14项2.512GiB；两段df净增2.191GiB，结束时可用3.494GiB。Products/Logs均保留，2项本轮开始前已不存在未计入回收量。

- `se-ui-final-r5` 正常落盘：**9项中8通过、1失败、0跳过**，source_changed为空。11路由免费/已购、真实入口、辅助字号、购买页、三页面退款锁回及2D额度/3D门禁通过；品牌权益列表用例SIGSEGV，系统日志限流/运行时诊断回调在崩溃栈中，根因未定，不能记全组通过。
- 用户要求先盘点缓存；[盘点报告](../output/pro-implementation-20261019/BUILD-CACHE-INVENTORY.md)列出约3.92GiB候选缓存。用户批准后复核：2项已不存在、4项因另一组测试活动而保留；删除其余10项1.727GiB，df净增1.512GiB至2.828GiB。旧Products、快照、测试证据与活动目录保留。

- `se-ui-transactions-r1` 4项中3商品页面购买/恢复通过；撤销用例首轮被StoreKit测试辅助启动带到首页，补充显式终止再按测试路由启动。
- `se-ui-revocation-r2` 的动作详情解锁/退款锁回已执行，随后统计页断言错误限定为 `Other`，实际 AX 为 `ScrollView`。改为按标识查找任意元素，保留解锁出现、退款锁回及原内容消失三项断言。
- `se-ui-matrix-r3` 原始日志为7项、6通过/1失败（品牌页进程退出）；磁盘同时不足，Xcode未能写汇总，结果包返回unknown/0，**不能据此记矩阵通过**。收尾滞留后发送SIGINT释放本轮进程。测试结束后、结果包收尾期间更新了UI测试源，result记录source_changed一项；编译时源保留于 `OnboardingProUITests-ui-r3.swift`。后续以r5重新运行作为最终证据。
- 真机首次 `build-device-profile` 被No space left on device中断，尚未安装；保存编译日志和恢复后的结果元数据。只清理本次失败构建生成的ModuleCache与Intermediates；更早本轮覆盖率数据经逐文件SHA校验打包保留，再移除未压缩副本，未清理设备/训练数据/媒体/其他任务输出。
- 加强 `revealProElement`：超出查找上限必须失败，扩大屏内滚动步幅。仅 isHittable 不足以证明屏外元素可见。新补 iPad 横竖屏与辅助字号用例；付费状态布局fixture单独命名，不替代StoreKit交易验收。

## 当前结论（2026-10-17 21:43）

B01–B08 代码已接入。B09 本地验证已通过 320 项定向 iOS 单元测试与 3 项 UI 测试，真实 StoreKit 交易因默认机系统测试环境故障未验收；辅助字号布局补测与最终完整 Release 模拟器构建均通过。B10 真机沙盒尚未执行，不能把整个 Pro 方案记为完成。以下 B01 记录是历史阶段状态，由本节与后续最新记录覆盖。

| 最新验证 | 实际结果 | 证据 |
|---|---|---|
| 定向 iOS 单元回归 r7 | **320/320 通过，失败0，跳过0**；18个测试类 | [结果摘要](../output/pro-implementation-20261017/b09/runtime-core-final-r7-summary.json) · [完整命令](../output/pro-implementation-20261017/b09/runtime-core-final-r7-command.json) · [日志](../output/pro-implementation-20261017/b08/runtime-core-final-r7.log) |
| iPhone 17 Pro UI r5 | **2/2通过**：九工具免费锁态；购买页浅深色、三商品选择、取消登录后保留选择 | [结果摘要](../output/pro-implementation-20261017/b08/runtime-final-r5-summary.json) · [截图](../output/pro-implementation-20261017/b09/phone-ui/manifest.json) |
| 辅助字号 UI | **1/1通过**：浅深纵向方案、选择与底栏、诚实法律状态可达；正式链接仍未发布 | [摘要](../output/pro-implementation-20261017/b09/large-final-summary.json) · [截图](../output/pro-implementation-20261017/b09/large-final/manifest.json) |
| 全仓 verify-gate | **通过**：内容、资源、DTO、文案、路由与写盘面 | [日志](../output/pro-implementation-20261017/b09/verify-gate-final.log) |
| verify-doc-size / git diff --check | **通过** | 不扩大100KB进度阈值 |
| 完整 Release 模拟器构建 | **通过**；最终二进制未发现强制Pro/测试路由标记，非真机Archive | [日志](../output/pro-implementation-20261017/b09/release-build-final.log) · [二进制检查](../output/pro-implementation-20261017/b09/release-debug-marker-check.json) |
| 实际 StoreKit 购买/恢复/批准/撤销 | **未通过环境准备，不记通过** | 下节详述 |
| 真机、第二设备恢复、用户视觉验收 | **未执行** | [待执行清单](test-plans/TP-PRO-20261017.md) |

r7 通过数不包含明确从运行 selector 排除的5个真实 StoreKit 用例：`testProStoreKitMonthlyCanUpgradeLifetimeAndRestoreBoth`、`testProStoreKitPendingApprovalAndRevocation`、`testRestoreLoadingTransitionsPreserveExistingEntitlementLabel`、`testStoreKitLocalLifetimePurchaseSurvivesRestore`、`testStoreKitLocalSubscriptionsPurchaseAndExpire`。它们没有被删除、改为 XCTSkip 或改成强制 Pro；结果中的 skipped=0 仅描述所选320项，不能解释为商店验收全部完成。两个注入购买结果测试验证状态机，不证明 Apple 成交。

### 回归失败与修复轨迹

- r1/r3 旧 fixture 使用不存在的动作/计划 ID，或未开始课程就直接写成绩。服务已要求真实内容身份和课程许可，因此领域算法测试显式注入授权，计划夹具换为真实免费计划；权限拒绝另有独立测试，原剂量/顺序/原子保存断言保留。
- r3 的崩溃归因核对 `.ips`：一处付费内容被拒后数组下标越界；另一处显示在 AuthState 测试名下，实际来自前一条几何题重试任务的全局同步队列。重试用例原先看到同步清空的 unsavedResults 就结束，未等异步持久化。改为记录型仓储，等待真实 saved.count=1，避免遗留任务与失效 SwiftData fixture；不改生产同步行为。
- 几何题误差测试改为逐题 nextQuestion，保留所有阈值断言；重复提交独立用例确认只计一次。r4 仍暴露另一个 `uitest` 假计划引起的下标崩溃，修复后 r5 142项与 r6 320项全过，均无崩溃重启。
- 路由签名只更新逐项审查过的变化；同期 OnboardingStyleLab 是 DEBUG 预览；新增写盘登记核对 OnboardingProUITests 的显式输出变量与附件行为，没有盲目重建全基线。

### StoreKit 环境限制

默认开发机为 iOS 26.3.1（23D8133），Xcode 26.2。SKTestSession 配置保存/清理均报 SKInternalErrorDomain Code=3，实际购买报 notEntitled，Ask to Buy 路径可等待不返回。恢复普通签名后同样复现，未添加虚构 StoreKit entitlement。Apple DTS 已确认同类系统问题（FB22237318），见 [官方讨论](https://developer.apple.com/forums/thread/826971)。这是与本机现象匹配的环境解释，不证明 App 购买链路本身正确。

r2 pending 运行已停止；r3 结束后的诊断子进程因产生大体积诊断而受控中止，结果包最终正常落盘。后续使用 `-collect-test-diagnostics never`，保留测试结果、日志和截图。未清理其他任务设备或数据。除已授权默认机外，iOS17 SE 与 iPad 保留机尚未获本轮覆盖安装授权，因此未使用；未自动下载安装其他 Runtime。

### 验收矩阵覆盖边界

| 方案用例 | 当前已证实 | 仍缺证据 |
|---|---|---|
| T01–T03 权益竞态/会话/商品 | loader 乱序、退出换号、白名单/撤销与状态机 XCTest | 三种真实成交与恢复 |
| T04–T05 生命周期/宽限期 | 请求合并、有效权益刷新保留、宽限期字段语义 | 实际后台到期与真实续订宽限期 |
| T06–T07 离线/owner | 真实 AuthState 使用 MockBackend 的可信身份、失效/退出/换号；owner 数据回归 | 真机断网冷启与两个真实球迹账号 |
| T08 工具路由 | 九路由分类与默认手机九目的地免费锁态 | 实际购买后的九目的地、文章互链与页面内到期 UI |
| T09–T11 内容/排课/续练 | 服务拒绝零写入、未知内容拒绝、已开始课程可存/下一课拒绝、重建 VM 拒绝、owner变更不可保存、原事务回归 | picker/精讲/试打完整 UI 与真机最小化恢复 |
| T12–T14 统计/历史 | 历史边界、DST、统计/历史 VM；入口构建前门控源码核对 | 多数据形态统计 UI 与降级历史编辑实机 |
| T15 额度 | 额度11测、重复提交与入口共享最后一题、跨日/时区/降级 | 四入口完整 UI 连续答题 |
| T16–T20 购买 | 取消/pending/确认中互斥、会话改变不误报成功；购买页选择与登录取消 UI | 本地真实购买/恢复/批准/拒绝/撤销/订阅并存与沙盒 |
| T21 Release/显示 | 完整Release构建；普通手机浅深/辅助字号布局截图与 AX 查询、全gate | 小屏/iPad/VoiceOver实际朗读、用户视觉验收 |

本轮没有发布、提交或推送；也未变更产品收费标记。45个相关源码的当前指纹见 [manifest](../output/pro-implementation-20261017/b09/source-snapshot-manifest.json)。工作区同时存在其他任务更改，阶段基线比较仅供审阅，不等于可以直接单独应用的纯本任务补丁。

### 收尾补充：确认中订单与法律页面

购买已完成但权益查询尚未收敛时，只能恢复/刷新，不允许通过“已取消”清掉等待状态重新付款。重选仅用于 Ask to Buy pending 的明确取消/拒绝；状态机回归增加确认中不可重置断言。

辅助字号 UI 第一次失败是 XCTest 对屏幕外卡片误报 isHittable，修正测试先确认卡片完整在固定底栏上方；第二次定位到正式法律链接未配置。实际 Debug/Release Info.plist 的 LEGAL_TERMS_URL 与 LEGAL_PRIVACY_URL 为空，显示“法律文件链接待发布”。这对应既有 [H-09](HUMAN-REQUIRED.md)，不能伪造 URL 或把未发布草稿当正式政策。辅助字号测试改为验证“正式链接或诚实未发布状态”的布局；法律发布仍独立未验收，不因 UI 测试通过而关闭。H-26 旧“终身不显示管理订阅”已按 D06 同步纠正。

## B00：产品方向与基线

2026-10-17 用户授权“好的，开始吧”，并对六项建议回复“采用这些建议”。D01–D06 的方向已确认，已同步方案、`docs/08` 当前规则增量和 `docs/00` 决策记录。D04 跨重启续练时效、D03 工具摘要等细则随对应批次明确。

本轮重新扫描 Bundle：74 动作，44 免费/30 Pro；12 计划，3 免费/9 Pro；计划索引/正文付费标记冲突 0；免费计划引用付费动作 0。未调整任何内容价格或收费标记。[扫描结果](../output/pro-implementation-20261017/b01/catalog-recheck.json)。

## B01：核心代码已实现，完整验收未关闭

### 实际改动

- `SubscriptionManager` 同时使用会话版本和请求版本，防止旧权益查询覆盖新结果。请求取消后即使底层仍返回，也必须通过版本检查。
- 启动、登录与回前台查询可合并同一在途读取；购买/恢复/交易更新仍要求新读取，不能错误复用购买前的旧查询。
- 有效权益在刷新中保留；查询完成后才切换。退出/换号立即清空，旧账号结果不得覆盖新账号的查询状态。
- 新增 `hasResolvedEntitlements` / `isRefreshingEntitlements`，区分尚未查询和已确认免费；新 `ProAccessPolicy` 提供共享权限判断及有效 Pro 商品过滤。页面接入属于 B03 等后续批次，尚未完成。
- `StoreKitService` 与 manager 接收端都只认可三种 Pro 商品，忽略未知与撤销商品；保留 StoreKit 已验证的当前宽限期权益，不以过去的 expirationDate 单独误杀。
- `QiuJiApp` 回前台新增权益刷新，独立于同步/提醒任务，不等待网络同步结束才查询权益。
- `AuthStateTests` 新增 8 项定向用例；原“退出后的晚到结果不能解锁”测试保留全部断言，将无限 yield 等待改为两个有超时的启动屏障。因为登录读取现在可与生命周期读取合并，必须先确认登录查询已启动，再显式发起第二个查询，才能保持原先验证两条晚到结果的前提。

修改生产文件仅 `StoreKitService.swift`、`SubscriptionManager.swift`、`QiuJiApp.swift`；测试修改 `AuthStateTests.swift`。未改真实 AuthState、owner 数据模型、排课、历史、购买 UI、额度或页面门控。已有其他任务修改保留。[本批独立 patch](../output/pro-implementation-20261017/b01/owned-changes.patch)。

### 实证结果

| 检查 | 结果 | 边界/证据 |
|---|---|---|
| Debug iOS `build-for-testing` | **成功** | App/测试目标实际编译；最终日志 [build-debug-final.log](../output/pro-implementation-20261017/b01/build-debug-final.log)，不是测试运行 |
| macOS 核心隔离 XCTest，Debug | **10/10 通过** | 8 新用例 + 2 原审计反例；[最终日志](../output/pro-implementation-20261017/b01/host-tests-final.log) |
| macOS 核心隔离 XCTest，Release | **10/10 通过** | 相同 10 项，用 Release 条件编译；[日志](../output/pro-implementation-20261017/b01/host-release-tests.log) |
| iOS Release 核心 typecheck | **通过** | 真实 iOS Simulator SDK、无 `-D DEBUG`，仅两核心文件与 Auth publisher 替身；[日志](../output/pro-implementation-20261017/b01/ios-release-core-typecheck.log) |
| 当前 iOS XCTest 运行 | **0 项，受阻** | 受管池达到 8 总量/每型号2台；[管理器日志](../output/pro-implementation-20261017/b01/managed-run.log) |
| 真机/真实 StoreKit 沙盒 | **未执行** | 没有真实购买、退款、宽限期或离线整链证据 |
| 完整 iOS Release 构建 | **未执行** | 本轮仅核心 Release 验证；构建后磁盘约余1.6GiB，不扩增大型构建产物 |
| `verify-doc-size`、改动文件 `git diff --check` | **通过** | 未提高100KB阈值，原进度历史保留 |
| 全仓 `verify-gate` | **未通过** | 内容/资源/DTO/文案子门禁通过后，因已有 `OnboardingStyleLab.swift` 路由表层登记缺失停止；未更新无关路由基线。[日志](../output/pro-implementation-20261017/b01/verify-gate.log) |

隔离测试严格边界：核心两个源文件为生产文件字节相同副本；使用最小 `AuthState` publisher 替身与注入的权益 loader，没有模拟成真实登录或真实 StoreKit 成功。新测试方法体从当前 `AuthStateTests` 提取，宿主工厂替换为 fixture；生产 AuthState 的完整联动尚未执行。宽限期用例证明“已验证的当前权益不被 expirationDate 误过滤”，不证明真实宽限期商店配置已验收。[指纹与范围](../output/pro-implementation-20261017/b01/manifest.json) · [可复验源码包](../output/pro-implementation-20261017/b01/host-sources.zip)。

受管池两个 idle iPad 均有用户录制现场保留原因，未安装或启动测试 App；对其中一台仅通过管理器执行 `/usr/bin/true` 做借用检查并结束租约，不作为可覆盖测试设备使用。未删除、擦除或重启设备。

### B01 DoD 对照

- [x] 两种同会话返回乱序不覆盖新结果；账号切换旧结果不覆盖新状态。
- [x] 生命周期合并与交易强制刷新分别有测试；刷新中保留当前有效权益。
- [x] 三商品白名单、撤销过滤、未知与有效商品混合、宽限期字段语义有核心测试。
- [x] 当前 iOS App/测试目标编译成功；核心 Release 条件编译和测试通过。
- [ ] 真实 AuthState 相关 iOS 单测执行及完整 iOS Release 构建。
- [ ] 实际前后台/StoreKit 生命周期运行验证；真实宽限期按 B09/B10 环境补齐。

**此前阶段结论：B01 维持“实现完成、验收未关闭”，不记整个 Pro 方案完成。** B02–B06/B08 尚未实施；B07 额度修复尚未开始，可作为独立批次推进。下一步优先取得可用于测试的受管设备运行 `QiuJiTests/AuthStateTests`，以及方案列出的 StoreKit 定向用例；保持录制/人工评审设备现状。


## 2026-10-17 继续实施（B02–B09，验收进行中）

用户恢复磁盘空间并明确授权默认开发机 iPhone 17 Pro（AE86244C）安装测试版；沿用生命周期入口独占借用，不覆盖其他保留设备。以下为当前代码变化，不等同测试通过。

- B02：Keychain 最小可信账号身份，离线 owner 与在线 API 认证分离，退出/失效清除；个人页可识别离线身份并重新连接。ADR-P7-01 见 P7。
- B03：9 个 Pro AngleRoute 统一分类，MainTab 目的地懒构建门禁；检查中、需登录、需购买分别处理；遮罩内容隐藏于无障碍树。
- B04：动作选择、模板新增/激活、精讲/试打以及服务层共享 ProContentAccess；未知动作不默认为免费。
- B05：排课与结转先整体校验再写；只有实际开始的课程获得当前进程的续练许可，下一课和重新进入重新检查；记录保存检查 owner 和会话版本。
- B06：历史含今天与此前59个本地自然日，认知详情/球台详情/编辑使用相同规则；统计和角度趋势在构建前门控；工具只读摘要仍保留。
- B07：存活对象跨午夜、回前台、时区变化刷新额度；补几何题重复提交和瞄准点提交时共享限额检查。
- B08：取消、pending、确认中、已解锁分开；购买/恢复互斥并检查会话代次；等待确认期间所有商品暂停新购买，明确取消/拒绝后可重选，重选本身不授予权益。状态页与购买页共享真实权益；月/年可升级终身，系统管理入口始终保留。
- B09：新增服务拒绝零写入、当前课/下一课/重启、账号切换、重复答题、StoreKit 批准/撤销与升级测试，回归进行中。

集成编译发现同期自定义球形两处独立 Swift 编译错误，做最小修正：`CustomFormationSession` 初始化从 template 取初始球 key；`CustomFormationLibrary` 错误描述改穷尽 switch。未改该任务产品行为。xcodegen 纳入同期新增 Swift 文件，原工程备份保留在 b02/before。

已知验证记录：b05/build.log 为 Debug iOS 测试目标编译成功；b08/runtime-core 首轮编译因旧测试订阅 `$isLoading` 失败，改为实际交易状态 `$isTransacting` 后重跑。当前 b08/runtime-regression 尚未出最终结果；不记已执行数/通过数。
