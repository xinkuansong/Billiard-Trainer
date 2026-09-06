# B4 账号、同步与权益安全执行准备

2026-09-05。依据 `COVERAGE-PLAN.md` SC25/26/29–33；额外检查设置/数据导出是否真实存在。实现与测试均来自冻结 `build/quality-diagnosis/snapshot-002`。只读审查，未运行单测、网络、购买、登录、注销或导出；仅新增本文件。

## 执行结论

可以先运行下面 41 个**受控专用模拟器、串行、无真实凭证**方法级白名单。这不是“文件名含Mock就安全”：已经检查注入点、默认参数、全局通知、宿主监听和写盘目标。测试仍可能影响宿主的内存owner/共享服务，因此不能与B1/B2/B3同进程或同模拟器并行，更不能放到用户真实安装容器。

必须满足的运行前提：

1. 确认专用测试宿主没有真实账号/refresh token（只检查存在性，不输出秘密）、当前auth为游客或未登录；保持同一snapshot-002。只检查或准备隔离容器，不清理用户使用中的Keychain/数据库。
2. 关闭测试并行；按下方小组分进程更稳妥，组结束终止宿主，避免异步通知或restore backend还原后遗留任务。
3. 明确unit启动的宿主也会跑QiuJiApp生命周期。若已有真实凭证，启动bootstrap就可能联网；这与方法内部Mock无关，未达前提不能运行这些hosted单测。
4. 保存原始日志和实际选择器，出现真实服务URL/鉴权请求迹象先停止该组、保留脱敏证据；不把联网失败当模拟用例预期成功。

## 风险链核实

| 位置（均相对snapshot-002） | 已核实行为 | 安全解释及剩余限制 |
|---|---|---|
| `QiuJi/Data/Services/AuthState.swift:124`起 | 默认backend=BackendSyncService.shared、credentials=KeychainAuthCredentialStore、defaults=.standard、owner=.shared | `AuthState()`不是隔离对象。仅创建不必然立即网络，但bootstrap/logout会触及默认实现。 |
| AuthState `:210`–`:221` | login改变owner并发NotificationCenter.didCompleteLogin | 即使backend注入Mock也会全局通知。 |
| `QiuJi/App/QiuJiApp.swift:66`–`:69`、`:105`–`:111` | 宿主bootstrap，并监听任何didCompleteLogin后调用宿主coordinator | Mock login可能碰到真实宿主；不是测试实例私有通知。 |
| `AccountDataCoordinator.swift:158`–`:161` | isCurrent要求宿主auth登录、userID匹配、owner匹配 | 无凭证游客宿主可挡测试假账号通知。不能在真实已登录宿主上依赖“ID应该碰不上”假设。 |
| `APIClientProfileTests.swift:45`–`:69`、`:90`–`:101` | ephemeral session，protocolClasses=[StubURLProtocol]，canInit恒true，stub耗尽直接didFail；baseURL unit.test，TokenStore为内存字典 | 所选APIClient测试的传输和token路径完整替身，不请求真实unit.test，不访问Keychain；全局宿主生命周期另按前提控制。 |
| `AuthStateTests.swift:71`起 | UUID defaults，MockBackend和MockCredentials明确注入，但未传ownerContext，默认shared | 不操作真实Keychain，但改共享owner且触发通知；只在空宿主串行。tearDown removeSuite不是删除持久domain，可能留测试suite，隔离容器可接受但不能称零残留。 |
| `V53AccountDataCoordinatorTests.swift:19`–`:37` | UUID defaults/local owner/内存库，auth backend+credentials及sync/restore后端全部Mock | 方法传输受控；tearDown还原Live后端和.standard，需避免并行/遗留任务。 |
| `V53OwnerIsolationTests.swift:47` | queue测试AuthState(defaults:ownerContext:)仍默认凭证/backend，虽queue backend被Mock替换 | 首轮白名单暂不包含该方法；需单独核对所有实际调用及宿主凭证。其余列出方法不调用默认auth登录。不是宣称它一定真实联网。 |
| `V53ProfilePreferencesTests.swift:108`、`:175`、`:202` | 明确注入头像backend与UUID temporary directory；删除只针对新目录内合成缓存 | 可运行；:108临时目录未见defer清理，UUID defaults也不逐一清理，记录测试容器残留，不触碰真实头像。 |
| `V36W2DeleteSyncTests.swift:50`、V36W3部分方法`:317/:344` | 默认AuthState并login，shared owner/queue/restore，部分Mock替身 | 本首轮不整class运行。V36分页/删除恢复仍重要，留第二小批作逐方法传输审计，不能因此删掉SC26覆盖。 |
| `V53ProfilePreferencesTests.swift:284`–`:344` | SKTestSession Products，reset/clearTransactions、buy/expire，restorePurchases调用StoreKit服务 | 是本地交易变更，需单独本地StoreKit组，不能混同只读测试，也不能当真实Sandbox购买证据。 |
| `SettingsView.swift:340`起 | 确认注销调用BackendSyncService.shared.deleteAccount | UI真实注销不在白名单；仅合成/受控账号且后端指向明确测试环境才执行。不得点用户账号确认注销。 |

## 场景映射与有效预期

| SC | 有效预期 | 本首轮对应与缺口 |
|---|---|---|
| 25 owner隔离 | v53/EXP-A01：guest/A/B不串资料、记录、收藏、计划、队列；迟到响应不覆盖当前账号 | V53Owner部分 + Profile迟到头像/账号响应；只是内存/Mock证据，真实HTTP鉴权、全部UI查询、真实切换仍缺。 |
| 26 迁移恢复 | v53/EXP-A02：同意前不上传、拒绝保留guest、确认幂等；恢复不能漏页或复活已删数据 | Coordinator同意/拒绝/重复确认+转移回滚；尚缺499/500/501/1000及增量游标/重复ID/删除恢复，必须随后覆盖现有V36与隔离后端；不能以DTO roundtrip替代分页。 |
| 29 鉴权 | v53/EXP-A03：后端会话成功才登录；网络错误与鉴权失效分开；退出本地凭证及界面清理 | AuthState Mock bootstrap/logout + APIClient401 refresh/retry；真实Apple首次/再次授权、Keychain跨进程、撤销授权不由此证明。 |
| 30 资料 | v53/EXP-A04：服务端响应为真源，部分更新不清其他字段；失败不假成功；头像revision与迟到响应正确 | ProfileContract/APIClient/ProfilePrefs；真实相册裁切上传、缓存重启、后端数据库实际保留与真机联网仍缺。 |
| 31 注销隐私 | v53+docs08：注销服务/凭证/本地资料按约定处理、失败可重试，法律入口有效且日志不泄密 | Coordinator pendingDeletionCleanup 与缓存删除测试只证明本地清理；并不证明服务端账号删除。注意当前本地清理可能转为guest而非抹除训练，须对照有效决策，不凭“注销”一词猜全部删库。Legal URL测试只验配置字符串，不证明页面HTTP和内容合规。 |
| 32 门控 | docs08：Free/Pro入口、过期与额度变化不绕过 | 本组仅权益状态展示；B1 forced Free/Pro门控是辅助证据。需正常入口各类型/额度跨日/到期UI，不能用mock profile代替真实权益。 |
| 33 购买 | docs08：商品失败/取消/pending/购买/恢复与权益更新 | 本首轮不买；下方本地StoreKit条件组可覆盖商品/月年过期/终身恢复。真实Sandbox、取消/pending、联网失败另列条件，不能宣称已完成。 |

设置补充：冻结 `QiuJi/Features/Profile/Views/SettingsView.swift:254` 的“数据导出”标“即将推出”。本次未找到真实文件导入入口，不把云端同步恢复等同文件备份/导入导出。若首发明确承诺此功能，需要追踪决策并登记未实现；否则只检查入口诚实不可误操作，不新增功能。

## 首轮白名单（41 项，未执行）

每行前加 `-only-testing:`；选择器使用XCTest class名称，不用整target。建议API/DTO → Auth → Coordinator/Owner → Profile分组，各组结束后终止宿主。

```text
QiuJiTests/ProfileContractTests/testUserDTODecodesNormalizedProfileShape
QiuJiTests/ProfileContractTests/testUserDTODecodesLegacyResponseWithoutNewOptionalFields
QiuJiTests/ProfileContractTests/testProfileUpdateEncodesOnlySpecifiedFields
QiuJiTests/APIClientProfileTests/testJSON2xxDecodesProfile
QiuJiTests/APIClientProfileTests/test400PreservesServerMessage
QiuJiTests/APIClientProfileTests/test401WithoutRefreshTokenBecomesAuthRequired
QiuJiTests/APIClientProfileTests/testExpiredAccessTokenRefreshesAndRetriesOriginalRequest
QiuJiTests/APIClientProfileTests/test5xxPreservesStatusAndMessage
QiuJiTests/APIClientProfileTests/testInvalidJSONSurfacesDecodingFailure
QiuJiTests/APIClientProfileTests/testRawJPEGUploadAndRead
QiuJiTests/AuthStateTests/testBootstrapWithoutTokenReturnsStableGuestAfterOnboarding
QiuJiTests/AuthStateTests/testBootstrapRestoresNormalizedServerUser
QiuJiTests/AuthStateTests/testDefinitiveAuthFailureClearsCredentialsAndSignsOut
QiuJiTests/AuthStateTests/testTemporaryNetworkFailureDoesNotClearCredentialsOrClaimAccount
QiuJiTests/AuthStateTests/testConcurrentBootstrapOnlyFetchesOnce
QiuJiTests/AuthStateTests/testConcurrentLogoutRevokesOnceAndAlwaysClearsLocalSession
QiuJiTests/V53AccountDataCoordinatorTests/test_loginWithGuestData_waitsForConsentAndUploadsNothing
QiuJiTests/V53AccountDataCoordinatorTests/test_declineMigration_onlyPullsAccount_andLeavesGuestData
QiuJiTests/V53AccountDataCoordinatorTests/test_confirmMigration_transfersOnce_thenUploadsAccountQueue
QiuJiTests/V53AccountDataCoordinatorTests/test_delayedRestoreFromA_isDiscardedAfterSwitchToB
QiuJiTests/V53AccountDataCoordinatorTests/test_pendingDeletionCleanupRetriesOnNextConfigure
QiuJiTests/V53OwnerIsolationTests/test_deviceGuestOwner_isStableAcrossContextRestart
QiuJiTests/V53OwnerIsolationTests/test_restoreSameClientID_isSeparatedByAccountOwner
QiuJiTests/V53OwnerIsolationTests/test_ownerTransfer_isIdempotent_andMovesQueueWithData
QiuJiTests/V53OwnerIsolationTests/test_ownerTransfer_saveFailure_rollsBackEveryType
QiuJiTests/V53ProfilePreferencesTests/testLoggedInDisplayNameCommitsOnlyServerResponse
QiuJiTests/V53ProfilePreferencesTests/testFailedDisplayNameDoesNotShowFalseSuccess
QiuJiTests/V53ProfilePreferencesTests/testDisplayNameValidationMatchesServerTwentyCharacterLimit
QiuJiTests/V53ProfilePreferencesTests/testGuestProfilesAreSeparatedByOwner
QiuJiTests/V53ProfilePreferencesTests/testLegacyGlobalProfileMigratesOnlyToDeviceGuest
QiuJiTests/V53ProfilePreferencesTests/testCanonicalServerYearsPlayingRestoresWithoutFallback
QiuJiTests/V53ProfilePreferencesTests/testAvatarUploadUpdatesRevisionAndFailureRollsBackPreview
QiuJiTests/V53ProfilePreferencesTests/testStaleAccountResponseCannotReplaceCurrentAuthenticatedUser
QiuJiTests/V53ProfilePreferencesTests/testDeletedAccountProfileCacheIsRemovedWithoutTouchingGuest
QiuJiTests/V53ProfilePreferencesTests/testDeletedAccountAvatarCacheRemovesAllRevisionsAndKeepsOtherOwners
QiuJiTests/V53ProfilePreferencesTests/testLateAvatarUploadFromADoesNotOverwriteLoadedAvatarForB
QiuJiTests/V53ProfilePreferencesTests/testAppearanceResolutionHonorsOverrideThenPreference
QiuJiTests/V53ProfilePreferencesTests/testLegalLinksFailClosedUnlessTheyAreRealHTTPSURLs
QiuJiTests/V53ProfilePreferencesTests/testEntitlementSnapshotShowsExpirationAndLifetimeTruthfully
QiuJiTests/V53ProfilePreferencesTests/testReminderPermissionDeniedDoesNotSchedule
QiuJiTests/V53ProfilePreferencesTests/testReminderAllowedSchedulesAndDisableCancels
```

## 单独的本地StoreKit条件组（未执行）

仅当专用模拟器、Products.storekit可被SKTestSession加载且测试本地配置确已生效时运行，记录本地交易重置/清理。不是外部真实消费。若配置初始化失败应停在错误，不改用真实购买兜底。

```text
QiuJiTests/V53ProfilePreferencesTests/testStoreKitConfigurationLoadsMonthlyYearlyAndLifetimeProducts
QiuJiTests/V53ProfilePreferencesTests/testStoreKitLocalSubscriptionsPurchaseAndExpire
QiuJiTests/V53ProfilePreferencesTests/testStoreKitLocalLifetimePurchaseSurvivesRestore
```

真实外部条件待列：Apple测试身份及真机系统授权、受控后端/数据库与可删除合成账号、网络错误控制、App Store Sandbox产品与测试账号、真机通知权限/到点提醒。当前不能以历史部署或旧H项通过代替本轮前提核实。不创建/删除真实账号、不读出秘密，也不为完成诊断购买或发布。

## 选择器指纹

SHA-256：`0437d50934d11e072ed270afa213ada5a6f119d46dc509a756f0ced2ae7f9032`（每行selector+LF）。源文件哈希如下，执行前不匹配须重审。

```text
d19b26e53d4b59d611893e28367ada8ee3c51fbb6deb7e0a98839a91a7d380fe  QiuJiTests/ProfileContractTests.swift
f1647e3964b63bab014808b531f4889ce9adf5dd6729ab99be7f3de11df0ac92  QiuJiTests/APIClientProfileTests.swift
f271799d90ba4ca85210aad8026a6d5f5d9af8eabbcc265603bcd63cf247d7d7  QiuJiTests/AuthStateTests.swift
4cc23ab7349121de3e56df35b28463b196425b0736b7dab786c3c308e061ebb0  QiuJiTests/V53AccountDataCoordinatorTests.swift
c7db78156d9dfe2a08920bfdc4ff5434d32985ed30059e26d68138672a4e2ee0  QiuJiTests/V53OwnerIsolationTests.swift
c46d6c8ae2917b84b8495ab0f8499ba2b7177790f121cd9b1e5073290467882a  QiuJiTests/V53ProfilePreferencesTests.swift
```
