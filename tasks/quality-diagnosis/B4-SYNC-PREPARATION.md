# B4 同步第二小批准备（SC26）

状态：只读审计，未执行。日期：2026-09-05。业务/测试真源均为 `build/quality-diagnosis/snapshot-002/`，下列源码路径省略此前缀；规格依据 `COVERAGE-PLAN.md:32`、`EXPECTATIONS.md` 的 EXP-A02。本文件不将探索 RUN-003 或已准备的方法标成正式通过。

## 推荐执行边界

本批新增 **20 个 XCTest 方法**：V36W2 8、V36W3 11、V53 owner queue 1。与 B4-PREPARATION 的首批 41 方法无重复；迟到响应复用首批已有证据，不追加方法数。若主控已将个别方法加入其它批次，以实际执行登记去重。不要整 target 或整 V53 文件执行，后者还包含磁盘迁移测试。

可在专用、无任何真实凭证的模拟器内串行执行；每个测试类独立启动测试进程，关闭 XCTest 并行执行，不能与 B1/B2/B3 共用宿主/UDID。这里的“可执行”是静态审计结论，不代表实测无外连。必须先确认诊断安装容器的宿主处于 guest；凭证检查只记录是否存在，不读取/展示 token 内容。默认 Keychain 构造不是凭证隔离，不得放到用户真实安装运行或为了测试清除其凭证。

原因与实际副作用：

- `QiuJiTests/V36W2DeleteSyncTests.swift:45–62` 使用内存 SwiftData，但所有方法 setUp 都 `AuthState()` + login。该 init 默认真实 backend、Keychain、standard defaults、shared owner（`QiuJi/Data/Services/AuthState.swift:124–135`）；init 自身不 bootstrap，login 发全局通知（`:210–221`）。测试方法不调用真实鉴权接口或 logout。
- 除仅验证 enqueue 的首方法，其余七个方法均在 processQueue 前把 `SyncQueueManager.shared.backend` 替换为 MockSyncBackend（测试 `:84/106/123/144/161/176/192`）。`SyncQueueManager.swift:44–60` enqueue 只保存本地队列，没有自动异步发网；`:146/163/173` 的上传删除经 backend。首方法虽然后端默认 Live，也未调用 processQueue。
- `QiuJiApp.swift:66–69` 宿主会 bootstrap；`:105–111` 监听全局登录通知。`AccountDataCoordinator.swift:66–71/158–162` 会核对宿主 auth、userId、owner、generation；无凭证 guest 宿主拒绝测试 login 通知的 push/pull。有真实凭证的宿主不满足安全前提。
- V36W2 会改变 shared owner 与 standard defaults 的账号上下文；tearDown 还原 Live 后端但未恢复 shared owner。V36W3 setUp 用 UUID defaults、内存容器、shared account owner；tearDown 恢复 guest/Live/default.standard，`removeSuite` 并非删掉持久域，可能留下 UUID preferences。V53 owner queue 的 UUID 域在 tearDown removePersistentDomain。以上残留仅允许在专用模拟器内，不能声称完全不写盘。
- V36W3 两个删除竞态方法 `:308–354` 也构造默认 AuthState 并 login，但队列先注入失败/成功替身，restore 先注入 MockRestoreBackend。其余 restore 方法同样在调用前注入替身。异步单例状态不可跨测试并发；仅结束独立诊断进程，不调用默认 logout 来“清理”。

## 可复制的方法级选择器

每行作为 `-only-testing:` 的值，不运行整个类。每个选择器必须在 xcresult 中有非零执行记录；测试发现失败需保留原样。

```text
QiuJiTests/V36W2DeleteSyncTests/test_repositoryDelete_enqueuesDeleteItem
QiuJiTests/V36W2DeleteSyncTests/test_processQueue_deleteItem_callsDeleteEndpointAndDequeues
QiuJiTests/V36W2DeleteSyncTests/test_processQueue_deleteItem_doesNotRequireLocalEntity
QiuJiTests/V36W2DeleteSyncTests/test_permanentFailure_4xx_dequeuesWithoutRetry
QiuJiTests/V36W2DeleteSyncTests/test_networkError_keepsItemForRetry
QiuJiTests/V36W2DeleteSyncTests/test_serverError_5xx_keepsItemForRetry
QiuJiTests/V36W2DeleteSyncTests/test_serverError_401_keepsItemForRetry
QiuJiTests/V36W2DeleteSyncTests/test_createItem_stillUploadsSession
QiuJiTests/V36W3RestoreSyncTests/test_restore_sameBatchTwice_doesNotDuplicateEntities
QiuJiTests/V36W3RestoreSyncTests/test_restore_duplicateClientIdWithinOneBatch_insertsOnce
QiuJiTests/V36W3RestoreSyncTests/test_roundTrip_encodeDecodeRebuild_preservesAllFields
QiuJiTests/V36W3RestoreSyncTests/test_deletedSession_isNotResurrected_whileDeleteItemPending
QiuJiTests/V36W3RestoreSyncTests/test_deleteSucceeded_thenRestore_doesNotResurrect
QiuJiTests/V36W3RestoreSyncTests/test_existingLocalSession_isNotOverwrittenByRemote
QiuJiTests/V36W3RestoreSyncTests/test_incrementalAnchor_usesServerUpdatedAt
QiuJiTests/V36W3RestoreSyncTests/test_anchorIsPerUser
QiuJiTests/V36W3RestoreSyncTests/test_fetchFailure_doesNotAdvanceAnchor
QiuJiTests/V36W3RestoreSyncTests/test_angleTestRestore_isIdempotentAndPreservesFields
QiuJiTests/V36W3RestoreSyncTests/test_apiDateDecoding_acceptsFractionalAndPlainISO8601
QiuJiTests/V53OwnerIsolationTests/test_queueProcessesOnlyCurrentAccountOwner
```

| 样本/来源行 | 有效断言 | 不能据此宣称 |
|---|---|---|
| V36W2 `:70/83/104` | 删除入队，调用替身 delete、成功出队，实体不存在仍可删 | 真实服务器删除成功 |
| V36W2 `:122/143/160/174/191` | 4xx永久失败出队、网络/5xx/401留队，create仍上传 | 401刷新鉴权、跨进程离线恢复、永久错误用户提示正确 |
| V36W3 `:208/228/244` | 重复批次/同批重复ID幂等，DTO恢复字段 | Mongo schema持久化不丢字段、501条遍历 |
| V36W3 `:308/336` | pending delete挡恢复；成功删除后空远端不复活 | 第二个测试的远端为空是预设，没有真实请求驱动远端删除；迟到旧响应/另一设备删除均未覆盖 |
| V36W3 `:357/383/406/417` | 已有本地记录不覆盖、服务端时钟锚点、账号锚点隔离、失败不前移 | 完整冲突合并；分页完备性；不同记录同updatedAt时无遗漏 |
| V36W3 `:431/460` | 角度记录幂等/字段、两种日期解码 | 角度服务端分页/日期异常输入 |
| V53 owner `:47–77` | A队列上传，B和guest留队，显式替身；UUID defaults | 上传进行中切账号、响应返回后账号归属仍安全 |

迟到响应已有首批 `V53AccountDataCoordinatorTests/test_delayedRestoreFromA_isDiscardedAfterSwitchToB`（`:124–143`），以挂起恢复、切换B、恢复A响应证明协调器拒绝旧恢复；**不重复计入本批20**。它不能代替上传在途、logout中断或真实 token 轮换。首批 profile/avatar 的迟到响应也仅覆盖相应页面状态。

## QD-007/008 正式路由复跑可行性

可以建立新的独立诊断脚本，复用 snapshot002 的真实 Express 路由与 JWT 中间件，模型用进程内确定性替身，不启动 MongoDB。原 `tasks/quality-diagnosis/backend-route-diagnostic.test.cjs:8–11` 相对引用的是**工作区 backend** 和旧 node_modules，直接重跑不构成 snapshot002 正式证据。建议只对独立诊断脚本适配以下内容，不更改 snapshot 或业务文件：

1. 用显式绝对 `snapshotRoot`、`dependencyRoot`，所有 routes/model/jwt require 指向 snapshot002；Express、Mongoose、jsonwebtoken 的实际解析路径必须落在独立临时依赖树。snapshot002/backend/node_modules 当前不存在，工作区 backend/node_modules 存在，故不能只相信 NODE_PATH：记录并校验所有相关 require.resolve/缓存模块路径，发现回退到工作区依赖即阻止执行。可使用临时目录里的最小后端副本（源文件逐个 SHA-256 与冻结件核对）配临时 node_modules，避免 Node 父目录解析回退；记录副本映射与依赖 lock hash。
2. 依赖版本取 snapshot backend lock；临时安装如必要，须独立目录和 `--ignore-scripts`，不执行项目启动脚本，不读取项目 .env，不引用 server/app 数据库连接入口。安装是准备过程的网络活动，应与仅loopback的测试网络边界分开记录。本轮未安装。
3. 路由导入链为 trainingSession → auth → jwt → config，以及 TrainingSession → mongoose。config仅取环境/计算路径（`backend/src/config/index.js:1–28`）；model构建schema未connect。独立脚本设置临时 JWT key 后才 require；不加载真实凭证。只监听 `127.0.0.1:0`、只对生成的本机URL fetch；server必须finally/after关闭，禁止代理或真实API地址。
4. 替身在挂路由前安装；未模拟的方法应立即失败，不能让 mongoose 缓冲真实操作。记录 model 调用次数；原“unauthenticated request rejected before model access”只有HTTP401断言，需加0次模型调用断言才能支撑该标题。
5. QD-007：`routes/trainingSession.js:90–102` 查询owner但更新直接req.body；`models/TrainingSession.js:59` userId有required/index无immutable。正式断言应允许端点先拒绝危险body，不能先强行访问未发生的 observedUpdate 导致测试自身TypeError；若发生update，再断言过滤器属A且更新对象没有将owner变B。假模型直接merge不是Mongo证据，返回200/B仅证明路由允许危险更新，实际数据库持久化仍待隔离集成验证。
6. QD-008：`routes/trainingSession.js:8–19`、`routes/angleTest.js:8–19` date倒序limit500；客户端 `SyncRestoreService.swift:152–191/198–229/374–380` 每类只拉一次并推进最大updatedAt。原501样本可以正式复跑，但应每个样本重建数组/替身、固定UTC日期，输出首批数/续批数/唯一ID数/缺失ID，499/500作对照，501/1000作越界，并补同updatedAt、date与updatedAt顺序不同。不要把手动第二次after模拟叫真实客户端恢复；它比现有客户端单次请求更宽容，仍漏记录是路由协议缺口证据。

计数：推荐本轮保留四个基础路由子测（无token、另一owner空、owner不可变、501恢复完整性）用于与探索结果比较；其后边界矩阵单列样本数。Node父test容器与子test不要双计，且不得与20个XCTest方法合并成SC覆盖率。探索QD编号保留，正式执行生成新run并记录snapshot指纹、独立脚本hash、依赖版本、stdout/stderr/退出码。预计危险更新/501完整性断言可能红，这是待验证预期，不是本轮执行结果。

## 尚需外部条件或额外受控夹具

真实Mongo隔离库才可确认immutable/strict/索引与持久化更新、owner注入实际影响；501/1000真客户端恢复、断网后重启、上传在途切A/B、logout后迟到响应、设备间删除同步均不在20方法通过的证明范围。禁止复用生产URI或真实账号补这些空白。数据导入导出在首批已记录为未落地入口，不能把云恢复当作导入导出覆盖。
