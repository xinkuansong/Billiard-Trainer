# 认知保存补证准备（snapshot004，2026-09-08）

状态：**草稿已编写，未编译、未运行、未注册。不得计为测试通过。** 本子任务未操作设备、未运行构建、未修改 snapshot 或生产代码。主控负责独立审查、注册和串行执行。

## 抽查现有证据能力

只读对象均来自 `build/quality-diagnosis/snapshot-004`，并非当前业务工作树。

| 来源 | 已有测试能证明什么（执行仍须查具体 run） | 不能据此声称什么 |
|---|---|---|
| `LocalAngleTestRepositoryTests` 6 方法 | 内存仓储保存、空库、日期范围与删除 | 磁盘重开、重复写入、实际保存失败恢复 |
| `V29W5CognitiveToolSessionTests/test_retriedSave_keepsOriginalSessionId` | 同一对象两次成功调用后 sessionId 不变、会话数 1 | 首次实际失败、结果表仍仅 1 条；原注释“模拟失败重试”不代表制造了保存失败 |
| W5 的三题归一、31 分钟分会话、10 分钟延长、不同 quizType 分会话 | 真实内存仓储分组和时长 | 跨进程持久化、真实账号同步 |
| `AngleResultSaveFailureTests` 前 4 方法 | 协议 stub 一直抛错时 VM 保留答案、错误与待保存队列 | SwiftData `context.save()` 真正失败后的事务状态 |
| `AngleResultSaveFailureTests/test_retryFailedSaves_clearsErrorWhenRepositoryRecovers` | 首次 stub 错误后切换内存仓储，观察 VM 清错 | 本方法未读库；VM `retryFailedSaves` 同步清错后才异步写入，等待 UI 状态为空可能提前结束；且此方法未把 SyncQueue singleton 配置到自己的内存 context |

生产 `LocalAngleTestRepository.save` 直接调用 `ModelContext.save`，没有可注入的 save closure 或 context protocol。`CognitiveSessionRecorder` 先插入/修改会话，由 repository 提交；此处的失败与回滚风险，不能用保存前 throw 的协议 stub 替代。当前不为测试改造生产注入口，也不破坏磁盘文件或塞满设备制造故障。

## 新增最小补证：3 个精确方法

文件：`tasks/quality-diagnosis/CognitiveRepositoryDiagnosticTests.swift`。仅由主控复制到冻结诊断的 `QiuJiTests/` 并注册。

1. `QiuJiTests/CognitiveRepositoryDiagnosticTests/test_sameResultObjectSavedTwice_keepsOneResultAndOneSession`
   - 两次真实仓储保存同一对象，同 result ID；检查结果表 1 条、会话 1 条、归属 ID 不变、无 DrillEntry/DrillSet。
   - 只记录队列条数；重复上传入队不等于重复成绩。
   - **不证明两个不同对象复用同 UUID 也幂等**；模型 `id` 未标 unique，此场景须另行确定调用契约，不擅自把同步重建语义归入 UI 重试。
2. `QiuJiTests/CognitiveRepositoryDiagnosticTests/test_protocolFailureThenRetry_persistsExactlyOneAnswerInRealMemoryRepository`
   - 首次由明确的协议 wrapper 在调用生产仓储前 throw，读库断言结果与会话均 0。
   - 用户同一答案重试，wrapper 转交真实 LocalAngleTestRepository；等待其实际成功返回，再查原 ID、42/35、geometric、会话归属、各 1 条、VM 清错与保留答案。
   - **协议层失败 + 真实内存成功，不是 SQLite 首次写失败后恢复。** wrapper 不是无条件成功 stub。
3. `QiuJiTests/CognitiveRepositoryDiagnosticTests/test_geometricAnswer_reopensIndependentDiskStoreWithOriginalSessionAndValues`
   - 只新建测试宿主 temporaryDirectory 下 `QD-CognitiveRepository-UUID/cognitive.store`，保存 geometric 一题。
   - helper 返回值仅 UUID/Date；替换 SyncQueue 的强引用为新内存 sink，释放原 repository/result/context/container 后重开相同 URL。
   - 断言结果、会话、owner、42/35/7、日期、类型、时长 1、无训练组、两类同步待办分别 1。
   - 保留 store 文件，stdout 先输出绝对路径，成功时附身份文本。**同进程新容器重开，不是杀进程重启、系统崩溃恢复或已发布版本迁移测试。**

## 执行隔离和验收

- 专用游客模拟器、`QiuJiDiagnosticMemoryHost` 与 `-v50.inMemoryStore`；禁止真实登录。测试环境必须设置 `TEST_RUNNER_QD_COGNITIVE_REPOSITORY_ENVIRONMENT=DEDICATED_GUEST_MEMORY_HOST`（实现兼容去前缀）。
- 只选择上述精确 3 方法，禁并行；主控 UI 批结束后再执行。测试不调用 `processQueue` 或任何网络接口；测试将共享队列 context 指向自己的容器并在结束时置空内存 sink。
- 独立 UUID UserDefaults suite / guest owner；不清正式 defaults，不删除临时 store，测试失败也保留路径。业务 UI 会话数据不作为 fixture。
- 方法 3 的文件位于模拟器 App 容器临时目录，不应卸载/清除该设备后再取证；执行后主控从日志提取路径并归档整个该 UUID 目录及哈希。成功附件不是数据库本体备份。
- 保存真实 test exit、三个 test identifier/结果、xcresult、stdout、编译失败（若有）与测试源哈希；预期执行数量 **3**，结果未知。任何失败保留原断言并先判定产品/测试/环境层次。
- 本子任务只做文本静态检查：`git diff --check -- tasks/quality-diagnosis/CognitiveRepositoryDiagnosticTests.swift` exit 0；这不证明 Swift 编译或运行通过。
- 主控应回写公共 PROGRESS / 覆盖台账；子任务按文件范围没有并发修改它们。
