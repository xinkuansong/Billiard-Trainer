# SC16/25 收藏按owner查询与增删隔离预飞

2026-09-08。仅新增本文及FavoriteOwnerDiagnosticTests.swift；未注册、构建、运行或操作设备。结论：**当前找到的已执行证据不能精确核销A/B/guest收藏查询隔离，值得补一个本机单元方法**；不是必须真实账号或再跑动作库24卡。

## 旧证据实际覆盖什么

已读B4-PREPARATION精确白名单、B4.md终态、CURRENT-SYNC-SELECTORS及CURRENT-SYNC-RESULT，以及冻结004 LocalDrillFavoriteRepositoryTests、V53OwnerIsolationTests：

- B4-001报告owner等41/41，B4-002另20/20，都是历史H；当前原B4各子目录日志未找到，不能宣称本次逐原日志重核。名单 `V53OwnerIsolationTests/test_ownerTransfer_isIdempotent_andMovesQueueWithData` 的fixture只有guest一条favorite c001迁往account，并断言owner为account；是迁移/幂等证据，不是A/B/guest查询隔离。
- `test_ownerTransfer_saveFailure_rollsBackEveryType`检查迁移rollback；名字EveryType不能作为收藏查询API已经被调用的证据。另restoreSameClientID针对训练数据、queueProcessesOnlyCurrentAccountOwner针对上传队列，不挪作收藏查询。
- CURRENT-SYNC三个批次14方法为Auth7/Coordinator6/ownerQueue1；无LocalDrillFavoriteRepository查询测试。其旧报告通过保留，不再借用“owner”字样核销收藏。
- 现存 `QiuJiTests/LocalDrillFavoriteRepositoryTests.swift` 八方法：add/fetchAll、empty、isFavorited true/false、remove、重复add、删除不存在、多收藏。全部采用默认.shared owner的单owner仓储，未构造A/B/guest。当前已读SELECTORS及R/build run第一层selectors未找到此类执行清单；不能把源码存在算通过。即使这八方法运行，也不验证跨owner。
- 当前 `formal-004-library-boundary-001` UI/SQL正常游客收藏增删与两次进程重启已实测；`formal-004-library-category-001`24卡集合已实测，两者均不切owner。

因此只补明确缺失的本地仓储隔离，既不否定旧迁移证据，也不把它扩大为UI/账号系统全部隔离。搜索限上述明确域与原路径，不宣称扫描了所有历史位置；若主控另有匹配原始run可直接用来替代新增执行。

## 实际生产语义

冻结前缀 `build/quality-diagnosis/snapshot-004/QiuJi/`。

`Data/Repositories/Local/LocalDrillFavoriteRepository.swift`：init显式可注入CurrentOwnerContext（缺省.shared）；add先本owner isFavorited，重复则不插入，新行owner为当前owner；remove同时谓词ownerKey及drillId；fetchAll谓词ownerKey、addedAt倒序；isFavorited同时谓词ownerKey和drillId。均是真实ModelContext读写，无API/SyncQueue调用。排序不是本次缺口，不用墙钟间隔构造排序断言。

`Data/Models/OwnerIdentity.swift:41–66` CurrentOwnerContext可注入UUID defaults；useGuest/useAccount只改该对象ownerKey，无AuthState.login和全局登录通知。`DrillFavorite.swift`记录ownerKey/drillId/addedAt，无单drillId唯一约束（允许不同owner同动作）。因此可以在一个容器、同一个仓储对象切换owner，直接检测动态查询与写入归属，不需要真实账号凭据或production fixture。

## 一个精确方法与独立预期

`QiuJiTests/FavoriteOwnerDiagnosticTests/testSharedAndDistinctFavoritesRemainScopedAcrossGuestABQueriesAndMutations`

1. 一个新内存ModelContainer、新ModelContext、独立CurrentOwnerContext，三个字面owner：随机合成guest、account:qd-favorite-A、account:qd-favorite-B。初始三个fetchAll精确空，四个查询ID均false，独立context总表空。
2. 通过真实repo.add（不直接插表）：guest c001+c009，A c001+c012，B c001+c037；每owner再加c001一次。三owner各2行，总6行，无重复；四ID逐个isFavorited必须匹配所属集合，fetched owner字段亦检查。
3. A删共享c001，再删仅B拥有的c037（A自身不存在）。guest仍c001+c009，A只c012，B仍c001+c037，总5。独立context回读其它owner原addedAt与行保持，防止删后重建假装集合未变。
4. A重新加c001、guest删c009、B删c001。最终guest只c001、A c001+c012、B只c037，总4；再次切guest/A/B读取，精确集合与isFavorited均一致。

每阶段独立ModelContext不带owner谓词读全表，以字面owner|drill配对核数量、重复与完整集合，不让被测fetchAll同时充当oracle。不是“query有结果”或只验总数。每一关键阶段JSON保留实际/期望/owner/布尔查询/全表日期，出现失败先写failure JSON再throw，避免async XCTAssert首错后继续输出成功。预期方法1、执行0。

## 隔离与交付边界

主控审阅后才考虑执行。新专用无凭据宿主；宿主在初始化前`-v50.inMemoryStore`，无authenticatedProfileFixture/forcePremium/forceNonPremium。env支持直接/TEST_RUNNER_前缀：`QD_FAVORITE_OWNER_AUTH=NEW_EMPTY_MEMORY_HOST`、`QD_EXPECTED_DEVICE_UDID`匹配实际SIMULATOR_UDID、绝对`QD_SHOT_DIR`。证据根内新UUID叶目录，拒覆盖。

局部容器全内存，ownerContext不使用.shared，不构造AuthState、不触发登录通知、不配置SyncQueue/真实后端。UUID defaults只保存本次合成guest键；证据留存后defer仅删除本次suite，绝不清用户defaults/库。宿主可能有自身初始化逻辑，因此新无凭据环境前提不能由“内存库”替代，也不声称抓包证明零流量。

`xcrun swiftc -frontend -parse tasks/quality-diagnosis/FavoriteOwnerDiagnosticTests.swift`已退出0、无输出；仅语法检查，不是类型编译/链接或测试通过。没有修改业务、原八方法、snapshot、工程、共享台账。即使未来通过，也只补本地真实仓储按owner查询/增删，**不证明UI刷新、真实登录切换、跨进程/跨设备、迁移全链或云收藏同步**。
