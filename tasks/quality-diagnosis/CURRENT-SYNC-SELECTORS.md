# 当前同步选择、owner 与权益：最小已有测试审计

2026-09-07，snapshot-003。只读审计与选择器准备；**本文件不表示已运行或通过**。只新增本文，未改业务/测试、未注册或操作模拟器。

## 当前变化及选取原则

相比 snapshot-002，AuthState 新增每账号云同步明确选择及 `syncChoiceRevision`、会话代次；AccountDataCoordinator 在推/拉 await 前后校验选择代次、身份和 owner；SubscriptionManager 新增绑定 AuthState、同步清理权益和迟到结果隔离。选择下列 14 个有不同判别力的已有方法，不复跑原 61 项。

执行前必须使用完整精确 selector；不要给整个 target/class。当前源路径都在 snapshot-003 的 `QiuJiTests`。每行的“预期”是已审读的断言，不代表真实服务端证据。

## 第一组：AuthStateTests，7 项

所有方法前缀 `QiuJiTests/AuthStateTests/`。

| 精确方法名 | 独立预期与当前改动关联 | 替身与限制 |
|---|---|---|
| `testSyncChoiceIsPerAccountAndPersistsAcrossAuthStateInstances` | 初次 A 默认关闭且询问；A 拒绝后切 B 仍询问；B 开启后返回 A 保持关闭/不再问；新 AuthState 再进 B 保持开启/不再问。直接验证按账号持久化新选择。 | UUID defaults suite、独立 CurrentOwnerContext、mock 认证和凭据；新实例同进程，不是 App 冷启动或磁盘安装迁移。 |
| `testBootstrapRestoresNormalizedServerUser` | mock 恢复账号后，不展示明确选择弹框且云同步默认关闭，后端获取恰一次；区别恢复登录与明确登录的新入口。 | MockBackend/MockCredentials；未注入 ownerContext，使用 `.shared`，因此有全局 owner 副作用。 |
| `testLateBootstrapCannotReplaceUserWhoJustLoggedIn` | 延迟旧恢复期间 login new-user，等待返回后当前仍 new-user；针对 sessionGeneration。 | mock fetch 100ms 延迟，等待 fetchCount 后登录；不是 continuation 严格扣住返回，繁忙调度可能旧请求早已结束而测试仍绿，不能单凭该方法证明竞态覆盖。使用共享 owner。 |
| `testProLogoutClearsEntitlementsAndReloginRefreshesPurchase` | 登录后有永久权益；退出即时清 product IDs/snapshots/状态；再读仍锁定，游客恢复购买返回 false 和登录提示；重登重新解锁。 | 注入字面永久权益、禁 transaction listener 与 DEBUG overrides，mock auth/凭据/独立 owner。不调用真实购买；游客 restore 被 guard 拦截。 |
| `testProIsClearedForExpiredSessionAndAccountDeletion` | 分别 invalidateSession 与 finishAccountDeletion 后清除 Pro，随后刷新不能复活。覆盖两条身份结束分支。 | 同上。删号为本地 finish 调用，不是实际远端账号删除/本地迁移事务。 |
| `testGuestColdLaunchCannotReuseAppleEntitlement` | 游客 premium false，权益 loader 调用次数严格为 0。直接验证新游客权限门控。 | 同上。“ColdLaunch”实际是新对象，不是系统进程重启；不验证 Apple 账户关联规则。 |
| `testProLateEntitlementResultCannotUnlockLoggedOutSession` | login 自动刷新和显式刷新均被 continuation 挂起，退出后才释放永久权益，最终仍 false/空 products。针对 sessionRevision。 | 有严格先后证据，但 `while pending.count < 2` 无测试内超时，主控须有外层运行超时/保留终止证据；不含 A→B 或关闭后重新登录同 A 的 ABA 竞态。 |

这 7 项不包括一般并发 bootstrap/logout、普通无 token、旧 profile 字段格式、网络错误全部排列；这些与本轮新增门控不具独立增益。

## 第二组：V53AccountDataCoordinatorTests，6 项

所有方法前缀 `QiuJiTests/V53AccountDataCoordinatorTests/`。

| 精确方法名 | 独立预期与当前改动关联 | 替身与限制 |
|---|---|---|
| `test_cloudSyncDeclined_blocksLoginForegroundAndKeepsQueue` | 未选择/拒绝、前台同步、再次登录均 0 上传/0 拉取，账号队列仍 1；开启后 1 上传/2 拉取。直接检验新增显式选择总闸。 | 真内存模型+计数 mock；0/1/2 为服务调用次数，不是 HTTP 抓包或服务端持久化。 |
| `test_disableWhileDownloading_discardsResponseAndStopsNextRequest` | 请求挂起时关闭；释放后本地 session 空、sessions anchor nil、angle 请求 0。针对 await 后 revision guard。 | continuation 控制 mock；尚未检查 angle anchor、队列或已经发出的请求撤销；等待请求没有内置超时。 |
| `test_delayedRestoreFromA_isDiscardedAfterSwitchToB` | A 拉取挂起→login B→释放 A，目标 clientID 0 行，当前 owner B。验证 owner/session guard 与选择共同工作。 | B 未开启同步，因而多道 guard 同时改变；不能单独证明“B 同步也开启”或 A→B→A。 |
| `test_loginWithGuestData_waitsForConsentAndUploadsNothing` | 已开启云同步但有游客数据时，先迁移询问，0 上传/0 拉取，guest owner 不变。验证两级选择不被混为一项同意。 | 直接调用 coordinator 默认 `offerGuestMigration=true`，不经过 App 通知路由。 |
| `test_declineMigration_onlyPullsAccount_andLeavesGuestData` | 开启同步后拒绝合并，0 上传、2 拉取，guest owner 与 guest 队列 1 均保留。区别“拒绝云同步”与“拒绝游客合并”。 | 拉取返回空，不能证明真实账号数据并入；直接 coordinator。 |
| `test_confirmMigration_transfersOnce_thenUploadsAccountQueue` | 开启并同意合并，guest 数据 owner 变 account；连续确认两次仅上传 1 次，两 owner 队列均 0。验证新增总闸没有破坏原幂等合并。 | 真内存 transfer+mock 上传，只有一条 session，不能外推全部类型或真实上传成功。 |

该类 setup 用 UUID suite、独立 owner、mock AuthCredentialStore/AuthBackend；配置真正内存 context，替换 **共享** SyncQueueManager/SyncRestoreService 的 backend/context/defaults。tearDown 恢复 Live backend 与 standard defaults，但不把共享 context 还原为原宿主。必须串行，建议该组独立宿主进程，与正常磁盘/UI 播种隔离；不并行执行共享单例测试。

不选 `test_pendingDeletionCleanupRetriesOnNextConfigure`：补偿重试逻辑本次不是新增选择/迟到响应路径；既有证据可保留，当前文件变化不能因此把它自动算新版本通过。

## 第三组：owner 队列，1 项

完整 selector：`QiuJiTests/V53OwnerIsolationTests/test_queueProcessesOnlyCurrentAccountOwner`。

先创建 A/B/guest 各一条真实内存 session 与队列，login A，mock 实际记录上传 ID 必须仅 A；A 队列 0，B/guest 各 1。这是启用同步后的 owner 边界对照，不能由前述纯计数替代。

注意此方法直接调用 `SyncQueueManager.processQueue`，没有开启 cloudSync；当前底层方法只检查登录、owner 和传入 shouldContinue，云同步选择由 coordinator 传 guard 实现。因此它是**底层 owner 测试，不是“默认关闭却仍上传”的缺陷复现**。AuthState 使用默认 live backend/KeychainCredentialStore 构造，但本方法仅 login，不 bootstrap/logout/clear，已审调用路径不读写 Keychain、不发认证网络；仍不可泛称所有依赖均为 mock。

## 专用内存宿主是否足够

**不足以单独保证网络或 Keychain 隔离。** `-v50.inMemoryStore` 只切换 QiuJiApp 的模型容器。真实宿主仍创建默认 AuthState（Keychain 凭据）、调用 bootstrap，创建 shared SubscriptionManager 并监听 StoreKit；测试的局部依赖注入没有替换宿主这些对象。

执行条件应为专用全新、从未真实登录/购买的诊断模拟器，测试宿主启动前有效传入内存标志，且没有 `-v53.authenticatedProfileFixture`（该标志使 coordinator 提前 return，会让本组门控测试失去有效性）、没有强制 Pro/其他数据 fixture。无既有凭据使宿主 bootstrap 在 token guard 返回；这属于专用环境前提，不需读取 Secrets/Token 内容来验证。若必须证明零网络，另设测试专用拦截/网络证据，本文件没有提供该证明。

局部 AuthState 的 login/setCloudSyncEnabled 向全局 NotificationCenter 发通知。App 的订阅回调拿的是**宿主自己的 AuthState**，不是测试的 mock state；在专用未登录宿主下身份 guard 应返回，但串行/新环境前提不可省。AuthState 部分方法使用 CurrentOwnerContext.shared，会污染专用宿主 owner；建议上述三组分独立进程，并禁止同一设备混用 DATA1/千条正常磁盘证据。AuthState tearDown 仅 removeSuite，不是 removePersistentDomain，因此 UUID suite 残留只限专用容器，勿称所有 defaults 全部还原。

## 必须交代或补齐的缺口

1. **上传进行中关闭/换号/关闭再开启**：现有严格延迟只覆盖下载。应补两个队列项，挂起第一上传，关闭/切号后释放，验证不发第二项、不开始 restore、账号归属/锚点不乱。当前 Queue 会在已发出的第一上传成功后删除该 item，这可能是合理确认成功语义，不能预设关闭必须撤销已到服务端请求。关闭再开启要检验 revision 防 ABA，而不是仅 bool 当前 true。
2. **晚到失败与 ABA**：当前 bootstrap 是成功+100ms；还缺可控 continuation 的 authRequired/network failure 在新登录后的处理，以及 A→B→A。权益也缺 A→B、同 A 重登和旧结果回流；应使用字面不同权益快照，不依赖真实 StoreKit。
3. **App 通知/UI 编排**：QiuJiApp `.didCompleteLogin` 实际 `offerGuestMigration:false`，`.didChangeCloudSync` 才用默认 true；本单测直接调用不覆盖此差异。现有 `QiuJiUITests/P8_ProfileSettingsUITests/testCloudSyncChoiceAndSettingsPersist` 是身份 fixture UI，可补提示/设置持久化，但 `-v53.authenticatedProfileFixture` 禁网络，不证明上传/拉取或真实认证。
4. **真实权益服务边界**：上述 4 项权益测试全部 literal loader。已有 `QiuJiTests/V53ProfilePreferencesTests/testRestoreLoadingTransitionsPreserveExistingEntitlementLabel` 可以另在专用 StoreKit 环境补当前 manager + local StoreKit 恢复加载状态。它会 `SKTestSession.resetToDefaultState/clearTransactions/buyProduct`，使用默认 AuthState 并发布 login，**不纳入本组安全无购买队列**；需明确专用虚拟交易环境，真实 Sandbox/Apple 身份仍另计。
5. **持久性与实际端到端**：新实例 defaults 不是卸载/安装/重启；内存 owner + fake upload 不是服务器隔离。不得用本轮绿色关闭 QD007/QD008 或宣称云同步整体可靠，真实数据库复验独立记账。

优先执行本表 14 项后，按实际新失败决定补上述局部竞态测试；未补的内容如实列盲区，不扩展成全部旧测试再跑。
