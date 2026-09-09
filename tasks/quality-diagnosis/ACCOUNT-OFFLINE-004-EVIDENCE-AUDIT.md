# SC24 / 29 / 30 / 31 本机证据与可执行性审计

2026-09-08，独立Test Engineer只读审计。仅写本文；未运行设备、网络、测试或构建，未修改业务、fixture、快照或共享台账。依据 [B4结果](B4.md)、[首批选择器与隔离审核](B4-PREPARATION.md)、[删除同步/恢复选择器](B4-SYNC-PREPARATION.md)、[003同步结果](CURRENT-SYNC-RESULT.md)、[003精确方法及限制](CURRENT-SYNC-SELECTORS.md)、B2以及本次核读的snapshot004源。**可安全设计/执行不是已经执行，通过只引用对应历史运行。**

## 结论与版本边界

本机仍有有用的正常UI分支：游客本地编辑/保存与返回、已有身份fixture下资料保存失败、注销确认取消和注销失败/再次失败、退出后本地游客状态、法律页配置与未发布状态。这些不应统一推给人工。另一方面，当前fixture不能从离线切到成功响应，因此不能用它关闭上传/恢复成功链；真实Apple凭据/撤销和指定部署账号的端到端另列外部。

旧B4的41+20方法是snapshot002隔离证据，003的14方法是内存/替身更新证据；不等于004全数重跑。旧build原件可用性限制见 [证据可用性](EVIDENCE-AVAILABILITY-20260907.md)，历史运行记录保留，但当前不能宣称这些原件逐份可重核。本次确认相关004入口和方法体含下述断言，未完成全文件字节漂移对照；需要当前版本结论时按变更影响精准复验，不整批重跑赚方法数。

尤其注意：**B4第二批的delete8是训练/角度同步删除队列测试，不是8条账号注销成功测试。** `finishAccountDeletion()`单独调用也不是远端删号。backend004真Mongo的QD007/008仍只覆盖训练/角度归属与恢复数量，不能算 `/user/account` 删除和 `/user/profile` 更新的真实服务证据。

## 已有真实执行过的隔离方法：可核销哪一层

以下选择器省略共同前缀 `QiuJiTests/`，均可在frozen004 `QiuJiTests/<类>.swift` 找到；本次没有执行。

| 场景 | 精确方法与历史执行归属 | 实质证据 / 不外推 |
|---|---|---|
| SC24 保存失败重试 | `V54TrainingTransactionTests/test_injectedSaveFailure_rollsBackEverything_andSameBlockCanRetry`，旧B2 | 给真实VM的saveAction首次throw，断言无session/queue、队列回pending、游标未进；第二次真实context.save后各1。是事务入口受控故障，不是文件系统真的写失败，也不是UI点重试或杀进程。 |
| SC24 上传失败重试 | `V54TrainingTransactionTests/test_uploadFailureKeepsAtomicQueue_andRetryCarriesProvenance`，旧B2 | 内存session+队列，RetryBackend失败留1→允许成功后0，2次上传尝试且来源payload保持。不是实际HTTP网络恢复。该方法用默认AuthState并发通知，空专用宿主前提不可省。 |
| SC24 删除重试 | `V36W2DeleteSyncTests/test_networkError_keepsItemForRetry`、`test_serverError_5xx_keepsItemForRetry`、`test_serverError_401_keepsItemForRetry`、`test_permanentFailure_4xx_dequeuesWithoutRetry`，B4-002 | 替身结果决定留队/出队；401不是该方法内部真实刷新token证据。删除对象是训练/角度记录，不是账户。 |
| SC24 恢复失败不改锚点 | `V36W3RestoreSyncTests/test_fetchFailure_doesNotAdvanceAnchor`、`test_deletedSession_isNotResurrected_whileDeleteItemPending`、`test_restore_sameBatchTwice_doesNotDuplicateEntities`，B4-002 | 隔离恢复与删除竞态；不同方法共用不等于一条正常UI端到端，`test_deleteSucceeded_thenRestore_doesNotResurrect`远端空是预设。 |
| SC29 无token/临时故障 | `AuthStateTests/testBootstrapWithoutTokenReturnsStableGuestAfterOnboarding`、`testDefinitiveAuthFailureClearsCredentialsAndSignsOut`、`testTemporaryNetworkFailureDoesNotClearCredentialsOrClaimAccount`、`testConcurrentLogoutRevokesOnceAndAlwaysClearsLocalSession`，B4-001 | MockBackend/MockCredentials+UUID偏好；区分临时网络失败与确认认证失效、并发退出只撤销一次并清本地。不是Apple登录、真实Keychain跨进程或实际远端撤销。 |
| SC29 HTTP错误/刷新 | `APIClientProfileTests/test401WithoutRefreshTokenBecomesAuthRequired`、`testExpiredAccessTokenRefreshesAndRetriesOriginalRequest`、`test400PreservesServerMessage`、`test5xxPreservesStatusAndMessage`、`testInvalidJSONSurfacesDecodingFailure`，B4-001 | ephemeral URLSession+全拦截StubURLProtocol、内存token，过APIClient请求路径；未发真实unit.test或部署请求。 |
| SC29 身份结束后权益 | `AuthStateTests/testProLogoutClearsEntitlementsAndReloginRefreshesPurchase`、`testProIsClearedForExpiredSessionAndAccountDeletion`、`testProLateEntitlementResultCannotUnlockLoggedOutSession`，003 Auth组 | 字面权益loader，不调用真实购买；迟到权益有continuation顺序，但等待缺方法内超时。删除路径只是本地finish。 |
| SC30 修改失败 / 服务响应真源 | `V53ProfilePreferencesTests/testLoggedInDisplayNameCommitsOnlyServerResponse`、`testFailedDisplayNameDoesNotShowFalseSuccess`、`testDisplayNameValidationMatchesServerTwentyCharacterLimit`，B4-001 | 成功只采后端归一化响应；失败保旧昵称；20接受/21拒绝。不是正常输入UI、真实网络更新。 |
| SC30 头像 / 迟到响应 | `V53ProfilePreferencesTests/testAvatarUploadUpdatesRevisionAndFailureRollsBackPreview`、`testStaleAccountResponseCannotReplaceCurrentAuthenticatedUser`、`testLateAvatarUploadFromADoesNotOverwriteLoadedAvatarForB`，B4-001 | 注入头像后端、合成UIImage、UUID临时目录；迟到回流不得替换新身份。无相册选择/裁剪取消UI或真实上传。 |
| SC31 本地补偿 / 分owner清理 | `V53AccountDataCoordinatorTests/test_pendingDeletionCleanupRetriesOnNextConfigure`、`V53OwnerIsolationTests/test_ownerTransfer_saveFailure_rollsBackEveryType`，B4-001 | 删除标记后的本地补偿、迁移事务回滚；不证明完整Settings的“远端成功→本地迁移失败→下次启动”的正常UI链。 |
| SC31 缓存与法律配置 | `V53ProfilePreferencesTests/testDeletedAccountProfileCacheIsRemovedWithoutTouchingGuest`、`testDeletedAccountAvatarCacheRemovesAllRevisionsAndKeepsOtherOwners`、`testLegalLinksFailClosedUnlessTheyAreRealHTTPSURLs`，B4-001 | 独立偏好/临时目录的指定账号清理、B/guest保留；法律URL校验不等于当前包配置和网页正文可访问。 |

003协调器6方法已证云同步拒绝、下载在途关闭、A响应晚到B、游客合并选择及确认幂等，精确表见CURRENT-SYNC-SELECTORS。**上传在途关闭/ABA、晚到失败排列仍缺**，但可以用现有协议/continuation在隔离单测中补，不需要真实账号或新增生产入口。

## 004现成入口怎样隔离，不能怎样用

所有生产路径以下相对frozen004 `source/QiuJi/`。

| 现成入口 | 已核源行为 | 可安全承担当次正常UI / 限制 |
|---|---|---|
| `AuthState.bootstrap` 的 `-v53.authenticatedProfileFixture`（Data/Services/AuthState.swift:177） | 生成`v53-server-user` / 服务端球友；avatarRevision=nil；不读真实登录成功结果。 | 仅新专用设备、保留fixture输入。让已登录页面可达；不能当真实Apple/后端认证。 |
| `APIClient.requestData`（Data/Services/APIClient.swift:121）同flag | **构造请求/传输前**throw `URLError(.notConnectedToInternet)`，覆盖经APIClient的profile/avatar/delete/logout请求。 | 可安全触发真实页面错误处理，不会到该APIClient真实endpoint。这是源路径保障，不是全App网络抓包证明（StoreKit/第三方URLSession另论）。 |
| `AccountDataCoordinator`同flag（:139/:156） | 上传和恢复入口直接return。 | “打开云同步后不发请求”在fixture下是主动跳过；不能当队列重试/恢复成功、关闭总闸或零丢失证据。 |
| `-syncChoice.explicitLogin` | bootstrap fixture清该合成ID的选择key，再login弹明确选择。 | 适合仅设置/提示UI；不能当选择跨启动本来保持。重启若继续传此flag会再次清选择，后续持久化方法须按原测试实际移除它。 |
| `-v50.inMemoryStore` | 仅切换App模型容器，不替换AuthState默认Keychain、API session、单例服务或所有偏好。 | 不是网络/凭据隔离。宿主必须新建、无真实凭据；单测mock login全局通知可触及宿主，必须串行分进程。 |
| APIClient init(baseURL/session/tokenStore)、OwnerProfileStore init(backend/defaults)、AvatarStore init(backend/directory) | 已有依赖注入供局部对象/宿主测试使用。BackendSyncService默认持有APIClient.shared。 | 可不改业务补精确P/U方法；独立测试对象注入不会自动传进真实正常导航实例。不能在XCUITest Runner里安装URLProtocol就声称截获App进程。 |
| ActiveTrainingViewModel init(saveAction:) | 可注入保存闭包；正常训练View调用VM默认保存，未见本次核读路径有启动flag安装首错后成功闭包。 | U/P失败恢复已测。正常UI本地保存错误不能靠破坏磁盘或把文件设只读构造；无现成UI注入口是可观察性限制，非缺Apple账号。 |
| AppConfig.apiBaseURL | 读Bundle `API_BASE_URL`，缺值/非法可回退`https://api.qiuji.app`；无本次确认的运行时切到loopback成功服务开关。 | 不因旧Release空API配置就推定绝不会外连。若将来用新隔离构建配置/诊断宿主连接本地服务，必须先核host、ATS、credential/fixture互斥和所有默认依赖；这是待设计的本机集成，不是当前已可直接运行正常UI。 |

## 不改业务即可继续的有限UI分支

1. **SC30正常资料失败**：新专用身份fixture启动，核账号header确为服务端球友→我的/个人信息→`personalInfo.displayNameButton`→实际昵称字段→`personalInfo.displayNameSave`。输入合法不同名字，应走OwnerProfileStore的backend.updateProfile→APIClient固定离线；保存不假成功，旧昵称不被替换、错误可关闭。具体错误显示以实际AX为准，不硬编URLError系统本地化。再次点保存只能再次失败；**没有成功恢复**。游客同路径20/21字符本地校验、正常昵称保存/重入可另测；已有旧UI证据按B5/结果核销，勿重复同质例。
2. **SC30头像取消/失败**：`personalInfo.avatarPicker`是真PhotosPicker，`AvatarCropView`是真裁剪。仅打开再取消可本机做；上传失败需要专用相册中一张已授权合成图，再正常选择/裁剪/确认，身份fixture请求固定失败，验证预览回滚。不能因为fixture头像初始nil就声称头像删除/旧revision缓存已覆盖；初始化带头像和迟到成功目前仅协议层证据。没有合成图就明确输入条件，不访问用户相册。
3. **SC31注销取消/失败再试**：身份fixture→设置“注销账号”→确认面板先“取消”，账号仍在；重新打开点“确认注销”→`SettingsView.deleteAccount`调 `/user/account` 被APIClient前置离线截断→“注销失败”alert，实际“重试/取消”。重试仍失败、关闭后仍保持该合成账号；失败前不会进入本地迁移/清缓存。此路径**可以安全执行**，不是删除真实账号，也不能称注销成功。执行前必须核fixture实际生效；禁止在真实账号/无flag环境点确认。
4. **SC29退出本地收尾**：ProfileView“退出登录”调AuthState.logout→backend.logout。fixture把API请求截断；BackendSyncService.logout吞远端失败，AuthState仍清本地会话。可核当进程身份/页面/权益不残留；重启继续带fixture会重新注入账号，**不能据此测试退出后真启动仍游客**，须在重新启动时移除身份flag且保持专用设备/不清数据，明确这是去除诊断输入后游客恢复，不是服务端撤销。
5. **SC24正常本地路径**：游客正常浏览Bundle内容、录入保存/重启读回已在训练与其它旅程有局部证据，但不是断网实验。身份fixture能取得强制离线下同类本地可用UI，却跳过队列push/pull；不得将它记为“恢复连接后只补传待上传项”。下一必要补证优先隔离队列在途失败/关闭的P层，不重复制造同样的正常磁盘保存。
6. **SC31法律/配置/日志**：LoginView只在terms与privacy均有效时提供Link，否则有未发布提示；About/当前包Info.plist、隐私清单、日志打印路径仍可只读静态核对。`testLegalLinks…`不关闭这些项。审日志只检查已授权诊断run并脱敏，不输出凭据；真实发布URL连通性/正文合规则另需读取实际页面，本审计没有访问网络。

本次仅静态确认上述入口可达条件，菜单/alert/键盘真实AX和原始图像仍需运行后核对。首错留证，不用空catch/取消断言适配。正常点击可做不意味着错误文案、状态或保存行为已正确。

## 不应伪造的成功链与真正外部条件

- **UI固定离线→成功恢复**：当前身份flag不能在同进程关闭API前置throw，重启去掉flag又不会保留真实认证凭据。不能简单“重启正常App”声称已连通恢复，更不能偷偷把baseURL切生产。已有协议替身可先关闭失败/成功的逻辑缺口；正常UI成功集成还需主控有界设计的隔离测试宿主/本地服务适配，记录它与正式App依赖图的差别。它属于**本机尚未准备的注入/观察能力**，不是自动外部化。
- **SC31远端删号成功后本地补偿链**：当前Settings无注入成功deleteAccount的正常UI入口；fixture恒失败无法到成功路径。已有清理标记/owner迁移/头像缓存U/P可复用，整链若需当前真实HTTP证据可在新隔离后端合成账号上设计；不得删用户账号或把训练记录delete8改称账号delete8。
- **SC29真实Apple认证/撤销、Keychain与服务器refresh生命周期**：需要指定测试身份和设备/环境；fake bootstrap替代不了Apple返回与真实后端token交换。`LoginView`正常入口明确“微信与手机号登录暂未开放”；虽然`PhoneLoginView`存在延时后匿名登录代码，本次未见LoginView连接到它，不能拿该未开放页面绕过真实认证或直接当正常账号缺陷。
- **SC30真实资料/头像上传与跨设备缓存、SC24真实部署恢复、SC31真实账号生命周期**：需要明确可变更/可删除合成测试账号、受控服务与隔离数据，才能做到端到端；仍不排除先用本地真实HTTP/数据库服务补协议层。已有QD007/008无需为此再次重复相同数量/归属反例。

建议主控先复用现成身份fixture完成“资料失败、注销取消/失败重试、退出”一个小批并独立图审，再按当前变更决定是否精准补上传在途/恢复的协议层反例。无法在现有App实例注入成功响应应明确列为本机观察能力缺口，保持原SC子项未知；既不能全部写“待人工”，也不能因旧mock已绿就把四场景整体关闭。
