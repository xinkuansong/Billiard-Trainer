# SC24/25 上传剩余边界预飞 — snapshot004

2026-09-08。按30/55规则与Data/Test Engineer角色只读审计；用户只诊断优先，不修复到绿。仅读原冻结服务及V53/V54/V36/Auth相关测试体、历史结果/选择器，不联网/运行测试/操作设备、不改业务或台账。本文件不是新增测试实现或通过结果。

## 结论

真正未被既有证据关闭的是**多项上传在途时失效及后续只重试未确认项**。上传失败分类、单项失败再试、owner静态过滤、关闭同步总闸和下载迟到丢弃均已有历史实测，不能重复用这些方法凑上传在途覆盖。

建议最多新增两个独立方法：先一条稳定账号多项失败重试，后一个有限表覆盖关闭/关闭再开/账号ABA下的上传迟到结果。下载迟到不等价上传迟到；普通App没有可切换的成功注入口不意味着这些P层必须人工。原SC24/25没有要求把所有错误×所有owner×全部实体做笛卡尔积。

## 实际控制链及不可误设的oracle

源均在archive/quality-diagnosis/snapshot-004/source/QiuJi/Data/Services/：

1. **SyncQueueManager.swift**（不是先前准备文中提到的UploadQueueService，后者不存在）：私有init，真实共享单例。可注入SyncBackend与ModelContext。processQueue(authState:shouldContinue:)先检查登录和当前owner，按SyncPendingItem.createdAt排序取本owner快照；每项发请求前检查shouldContinue、登录及userID。上传DTO从真实TrainingSession/AngleTestResult读取。
2. await process之后没有再用shouldContinue否定本项结果：成功→删除该队列项；永久4xx→删除并日志；retryLater→保留。循环下一项才重新检查门禁；最后真实context.save。**关闭后已发出且成功的项允许出队**，不把关闭解释为撤销已到服务器的请求。
3. **普通retryLater不break**。稳定账号下首项失败，后续项仍可能成功，这符合当前“逐项保留重试”的实现/现有契约；原范围没有规定网络首错必须停止全部。不能预设失败后第二项一定不发；只有门禁失效才应挡后续请求。
4. classify把400…499中除401/408/429外归永久，其余网络/5xx/解码等保留。队列不会因AppError.authRequired直接invalidateSession；token刷新/注销属于APIClient/AuthState层，不借“迟到失败”强行要求在这层退出当前B。
5. **AccountDataCoordinator.swift pushThenPull**捕获choiceRevision，传入Queue的closure同时核syncChoiceRevision、cloudSyncEnabled、operation generation、身份及owner；Queue完成后再次核revision/generation才pull。syncActiveAccount未开启时会beginOperation使旧轮失效；正常handleCompletedLogin也有其完整门禁，不能跳过它伪造“新一轮”。
6. **AuthState.swift**setCloudSyncEnabled每次递增syncChoiceRevision并post通知；login递增sessionGeneration、换owner并加载对应同步偏好，不直接说明coordinator generation已推进。A→B→A必须明确是否交付正常coordinator身份事件，否则旧请求恢复时仅比较当前A/true可能不足。不能手工调用私有代次或追加无依据setCloudSyncEnabled来让ABA测试天然通过。
7. auth.setCloudSyncEnabled(true)设置pendingMigration=true。测试必须通过实际coordinator正常入口清除/处理该状态（无guest数据），不能在pendingMigration guard处return却记录“上传被正确拦截”。
8. 固定身份-v53.authenticatedProfileFixture使coordinator push/pull直接return；不能用于本批。它只适合正常UI固定离线失败，不是恢复开关。

## 已运行证据逐条复用

历史来源D=tasks/quality-diagnosis；对应旧build/quality-diagnosis/formal-b2-001、formal-b4-001/002及formal-resume-current-sync-*当前原件可用性依EVIDENCE-AVAILABILITY说明，不能当本次重新打开xcresult。D/B2.md/B2-SELECTORS.md、B4.md、CURRENT-SYNC-RESULT.md有明确整组终态；本次实际读冻结004方法体确认其断言范围，不把当前源码当历史相同hash的证明。

| 精确selector（均QiuJiTests/前缀） | 已有真实断言及历史执行 | 与剩余上传的差别 |
|---|---|---|
| V54TrainingTransactionTests/test_uploadFailureKeepsAtomicQueue_andRetryCarriesProvenance | B2-001历史171全过所选方法；一training session/一create项，首轮RetryBackend失败留1；allowSuccess第二轮队列空，uploaded.count=2且scheduleItem/sourceKind/payload/progressEffect保持 | uploaded计尝试而非2次成功；没有多项、明确in-flight barrier、开关/切owner |
| V36W2DeleteSyncTests/test_networkError_keepsItemForRetry | B4-002 delete8全过；delete项两轮均失败、队列1、backend delete累计2 | 是删除请求、两次失败，没有失败→成功或上传迟到 |
| V36W2DeleteSyncTests/test_serverError_5xx_keepsItemForRetry 与 test_serverError_401_keepsItemForRetry | B4-002；503/401各留队 | 不证明真实HTTP刷新token，更不是在途事件 |
| V36W2DeleteSyncTests/test_permanentFailure_4xx_dequeuesWithoutRetry | B4-002；400出队，第二轮不再调用，总1 | 永久失败分类已测，不需要所有HTTP码再铺矩阵 |
| V36W2DeleteSyncTests/test_processQueue_deleteItem_callsDeleteEndpointAndDequeues 与 test_processQueue_deleteItem_doesNotRequireLocalEntity | 删除后create+delete，两项收敛且不上传不存在实体；孤立delete仍发删除 | 队列多项存在不等于多项上传失败重试 |
| V53OwnerIsolationTests/test_queueProcessesOnlyCurrentAccountOwner | B4-002及003 owner1/1 0.715s；A/B/guest各一，login A只发A，A0/B1/guest1 | 直接Queue调用，无云同步选择closure；不是默认关闭仍上传缺陷，也没in-flight切换 |
| V53AccountDataCoordinatorTests/test_cloudSyncDeclined_blocksLoginForegroundAndKeepsQueue | 003 Coordinator6/6 0.907s；拒绝时0upload/0fetch且queue1，开启后1upload/2fetch | 总闸静态已测；没有上传await期间开关 |
| V53AccountDataCoordinatorTests/test_disableWhileDownloading_discardsResponseAndStopsNextRequest | 同上；fetchSessions continuation挂起，关闭后释放，session0、sessions anchor nil、angle fetch0 | 明确下载，不可冒充上传迟到；等待没有方法内超时限制 |
| V53AccountDataCoordinatorTests/test_delayedRestoreFromA_isDiscardedAfterSwitchToB | 同上；A fetch挂起→B→释放，A dto未落盘/current owner B | B未开同步，多道guard变化；无上传/ABA |
| V53AccountDataCoordinatorTests/test_loginWithGuestData_waitsForConsentAndUploadsNothing、test_declineMigration_onlyPullsAccount_andLeavesGuestData、test_confirmMigration_transfersOnce_thenUploadsAccountQueue | 同上；迁移询问0upload/fetch、拒绝仅2fetch且guest保留、确认两次仅1上传、owner转移后队列0 | 正常迁移同意与幂等已测，不增加多项失败/上传迟到证据 |
| V36W3RestoreSyncTests/test_fetchFailure_doesNotAdvanceAnchor、test_deletedSession_isNotResurrected_whileDeleteItemPending、test_restore_sameBatchTwice_doesNotDuplicateEntities | B4-002 restore11全过；失败不进锚、待删不复活、重复批不重建 | 恢复层，不是上传await期间失效 |
| AuthStateTests/testLateBootstrapCannotReplaceUserWhoJustLoggedIn | 003 Auth7/7 1.043s；旧成功fetch延迟100ms，新login后仍新用户 | 非严格continuation，旧成功可能先结束；不是上传、不是晚到失败 |
| AuthStateTests/testProLateEntitlementResultCannotUnlockLoggedOutSession | 003；两次字面权益loader都挂起，logout后释放仍Free/空 | 是权益成功迟到，不能代上传failure；while等待无内部timeout，不能照抄 |

旧方法中存在try? context.fetch、默认AuthState或无超时等待的实现/测试限制照实保留，本次不修改。真实Mongo004的QD007/008与本协议测试互不覆盖，不因为P层补过就撤销服务缺陷。

## 最小下一selector与字面预期（尚无实现/注册）

### 1. 先跑稳定账号的一条多项反例

建议：`QiuJiTests/UploadBoundaryDiagnosticTests/testMultiItemInFlightFailureRetriesOnlyUnacknowledgedItem`。

- 使用真实ModelContainerFactory.makeInMemoryContainer，mainContext与独立ModelContext读回；UUID defaults/独立CurrentOwnerContext、AuthSessionBackend和AuthCredentialStore替身。真coordinator配置后由正常登录/开启同步入口开始，无guest迁移样本干扰。
- A内3个独立训练session及3个create项，固定字面createdAt严格升序S0/S1/S2，payload各唯一；另B、guest各一项作为不串owner对照。不能只靠插入顺序或毫秒碰巧不同决定排序。
- SyncBackend actor记attempt、success、failure及DTO clientId/provenance。S0立即确认成功，S1明确进入checked continuation后通知测试“requested”，S2正常成功。等待requested后保存第一份事件和真实队列，不用Task.sleep猜在途。
- 放行S1明确networkError后await整轮结束；预期请求顺序[S0,S1,S2]，成功[S0,S2]、失败[S1]，A只剩S1，B/guest原项与实体保持。**不要求S2被首错拦住**。恢复fetch可发生，返回空且单独记录，不能预设普通上传失败必阻断pull。
- 将S1 backend改成功，开启新正常syncActiveAccount轮；增量attempt只有S1，最终A0/B1/guest1；S0/S2各成功1、S1失败1成功1，全部原session/provenance未变。第二轮后再独立context读回/证据文件，判“只补传未确认”。
- 它补SC24主要剩余而不重跑旧一项retry方法；仍是协议/服务层，不是真实HTTP或正常App恢复网络。

### 2. 再用有限表核上传失效边界

建议：`QiuJiTests/UploadBoundaryDiagnosticTests/testInFlightUploadInvalidationStopsOldBatchAcrossDisableAndABA`。

每行独立容器/defaults/actor/新coordinator，不复用第一方法残留；A两项U1/U2，B与guest对照各1，固定createdAt。U1明确挂起，U2尚未发。只做以下4行，不扩全部实体/错误码：

| 行 | 挂起期间事件 | 放行U1 | 旧轮结束字面预期 |
|---|---|---|---|
| disable-success | A关同步 | success | U1已确认出队；U2仍在；U2未发、restore两接口均0；身份A、同步false |
| disable-failure | A关同步 | networkError | U1/U2均在，U2未发、restore0；身份不被失败改写 |
| sync-ABA-failure | A关再开，实际syncChoiceRevision前后不等，当前true | networkError | 旧轮不能因当前bool恢复true而继续U2/pull；U1/U2保留；随后单独新轮才可重试成功 |
| account-ABA-failure | 正常login B并交付coordinator的B身份事件（B同步默认false），再正常login A；旧请求放行前不启动A新同步轮 | networkError | 原A轮generation失效，U1/U2保留、B/guest不变，不让旧失败签出当前A；旧轮0后续上传/拉取，之后正常A新事件再重试 |

账户ABA行明确是**身份事件已按B→A顺序分阶段交付**的服务测试：记录每个事件、operation调用起止，不声称覆盖App通知自动调度/并发重入。不能仅login B→login A再认为测试已包含coordinator事件，也不能把setCloudSyncEnabled任意多调用当替代身份代次。若实施时发现正常handleCompletedLogin(B)会触发迁移/其他请求，先按真实API精确处理并记录，不能靠私改generation或降低0请求断言。

表中sync-ABA的“重新开同步”会设置pendingMigration；完成旧轮后新轮按handleCompletedLogin/真实无guest处理路径再开始，不允许因pendingMigration提前return而假记重试成功。account-ABA对B默认false是有限样本，不声称B也开启且并发上传的矩阵已测；原SC未要求无限排列。真机/真实账号不是这些方法的前置。

迟到**认证bootstrap**失败在新登录后的处理另属SC29：本批不加第3个认证测试，也不借上传networkError结果宣称该层被覆盖。若主控仍需该项，可后续仅一严格continuation的authRequired反例；与本批上传状态判据不同。

## 注入和宿主隔离的可执行性

- SyncBackend三个函数：uploadSession(TrainingSessionDTO)、uploadAngleTest(AngleTestDTO)、deleteSession(clientId:String)，均async throws、协议Sendable；用actor替身。现有CoordinatorSyncBackend/RetryBackend为测试文件private，不能跨文件直接引用；新增独立受控actor是必要测试代码，不改业务。未使用的angle/delete若发生必须记录并使断言失败，不能静默空实现吞调用。
- SyncRestoreBackend同样actor记录两个fetch，返回空数组；按每行允许/禁止数核验，两anchors都读回。不要让LiveSyncRestoreBackend意外兜底发网。
- 三个共享对象（SyncQueueManager、SyncRestoreService及其defaults/context）必须串行独立宿主。context无公开getter，不能假称tearDown还原原context：保留容器生命周期到任务全结束，末尾可配置单独空内存容器并恢复原backend/defaults，退出专用宿主；与DATA1/千场/UI磁盘设备隔离。
- 宿主需全新无凭据/无真实购买，初始化前-v50.inMemoryStore，**无authenticatedProfileFixture、forcePremium或实体播种flag**。测试局部auth完全注入；其NotificationCenter事件可能被App全局观察，宿主自己的auth仍游客，须先核guard。inMemory不等于零网络，不能省掉auth凭据和restore backend隔离。
- continuation必须有有界requested/finished等待及失败释放策略：超时先记录事件/队列，然后resume一次抛明确诊断错误，await任务结束再cleanup。不能while无界，也不能仅Task.cancel未释放continuation后恢复Live backend。结构化task-group超时若仍等待不可取消continuation并不能解挂，须独立释放通道。
- 所有关键前置guard+throw；真实context.save/fetch用try不吞错。事件原件仅UUID、owner合成名、operation、单调时序、结果类别和必要payload摘要，禁止真实token/userInfo全量。先保存事件/队列/独立context快照，再cleanup。
- 编写/注册运行均未做。主控应先审方法1，单跑终态后决定方法2；如果出现新真实失败，保留它，不继续横向扩大或修生产。

## 不误报完成的收口

现有证据足以不再重跑V54单项重试、V36删除分类、V53下载关闭与静态owner；它们与上述两方法的增益清楚不同。补两方法后仍只关闭SC24/25有限服务边界，不关闭真实iOS→部署HTTP→多设备恢复、也不覆盖SDK权益或auth bootstrap所有竞态。没有正常UI成功注入口应保留本机依赖注入层次限制，而不是“只能人工”；真实端到端需要指定合成测试账号/受控服务且另授权，不能偷偷连生产。
