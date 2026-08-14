# P2 — Data Layer（数据层）

> **目标**：SwiftData 全量 Schema、Drill 内容（Bundle + 未来自建 API OTA）、自建后端用户数据同步、离线优先策略。
> **人工前置**：H-14 ✅（腾讯云服务器）、H-16 ✅（MongoDB 同机部署，2026-03-29）；H-07 ~~CloudKit~~ ✅ 已取消（ADR-002）
> **前置 Phase**：P1 通过 QA

---

## T-P2-01 SwiftData Schema（全量实体）

- **负责角色**：Data Engineer
- **前置依赖**：T-P1-01
- **产出物**：`Data/Models/` 下所有 `@Model` 文件

### DoD

- [x] 以下实体全部定义完成：`TrainingSession`、`DrillEntry`、`DrillSet`、`AngleTestResult`、`UserActivePlan`、`DrillFavorite`
- [x] `ModelContainer` 在 `QiuJiApp` 中统一初始化，通过 `.modelContainer()` 注入
- [x] 内存测试 Container（`isStoredInMemoryOnly: true`）已定义，供 Preview 和测试使用
- [x] 所有关系（`@Relationship`）的 `deleteRule` 已显式设置（`TrainingSession` → `DrillEntry` → `DrillSet` 均为 `.cascade`）
- [x] 编译通过，模拟器可启动

---

## T-P2-02 Local Repository 实现

- **负责角色**：Data Engineer
- **前置依赖**：T-P2-01
- **产出物**：`Data/Repositories/Protocols/`、`Data/Repositories/Local/`

### DoD

- [x] `TrainingSessionRepositoryProtocol` 定义：`create`、`fetchAll`、`fetchByDate`、`update`、`delete`
- [x] `LocalTrainingSessionRepository` 实现上述协议（使用 SwiftData `ModelContext`）
- [x] `DrillFavoriteRepository` 实现收藏的增删查
- [x] `AngleTestRepository` 实现角度测试历史的写入与按时间段查询
- [x] 所有操作在主线程可安全调用（小批量）；批量操作提供 `ModelActor` 版本（当前数据量 @MainActor 足够，P8 视需求升级）
- [x] XCTest 基础测试：创建 Session → 读取 → 删除，断言数量正确
- [x] XCTest：DrillFavorite 增删查、isFavorited 判断
- [x] XCTest：AngleTestResult 写入、按时间段查询

---

## T-P2-03 ~~CloudKit 公开库内容拉取~~（已取消，ADR-002）

- **状态**：✅ 已取消（2026-03-29）
- **替代方案**：
  - **当前**：`Data/Services/DrillContentService.swift` 从 Bundle 加载 `Resources/Drills/`（与 T-P2-04 一致）
  - **后续**：在 **T-P2-05** 实现自建后端 `GET /drills?updatedAfter=`（及计划 JSON 若需 OTA），由 `DrillContentService` 或专用 `ContentSyncService` 合并远端与本地缓存
- **取消原因**：与 ADR-001 自建 REST API 统一栈；避免 CloudKit 公开库 + 后端双通道、H-07 额外运维

---

## T-P2-04 Bundle Fallback JSON 结构

- **负责角色**：Content Engineer
- **前置依赖**：无（可并行）
- **产出物**：`Resources/Drills/index.json`、`Resources/Plans/index.json`

### DoD

- [x] `Resources/Drills/index.json` 格式：`{"version": 1, "drills": ["drill_c001", ...]}`
- [x] `Resources/Plans/index.json` 格式同上
- [x] 至少包含 5 条示例 Drill JSON（用于开发阶段预览，P3 前完整生产）
- [x] `DrillContentService` 的 `loadFallbackDrills()` 可成功解析

---

## T-P2-05 后端用户数据同步

- **负责角色**：Data Engineer
- **人工前置**：H-14 ✅（服务器已部署）、H-16 ✅（MongoDB 同机部署完成）
- **前置依赖**：T-P1-07, T-P2-01
- **产出物**：`Data/Services/BackendSyncService.swift`

### DoD

- [x] `BackendSyncService.syncSession(_:)` 调用 `POST /training-sessions`，上传本地 `TrainingSession`
- [x] `BackendSyncService.fetchUserSessionsAfter(date:)` 调用 `GET /training-sessions?after=` 拉取增量数据
- [x] （ADR-002）服务端提供或文档化 Drill / 计划公开只读接口（如 `GET /drills?updatedAfter=`），供客户端在 `DrillContentService` 或专用同步类中实现 OTA（可与用户数据接口同域）
- [x] 登录后触发一次性迁移：将匿名本地数据批量上传（`POST /training-sessions/batch`）
- [x] 请求携带 JWT（`Authorization: Bearer`），401 时触发 token 刷新
- [x] 数据仅关联当前登录用户（服务端按 JWT 隔离）

---

## T-P2-06 匿名用户本地模式

- **负责角色**：Data Engineer
- **前置依赖**：T-P2-01, T-P2-05
- **产出物**：`Data/Services/AuthState.swift` 更新

### DoD

- [x] 未登录时：训练记录正常写入 SwiftData 本地；不触发后端上传
- [x] 登录时：提示「登录后数据将同步云端」，用户确认后触发迁移上传
- [x] 「我的」Tab 未登录状态显示登录引导，而非空白

---

## T-P2-07 SyncQueue（后台同步队列）

- **负责角色**：Data Engineer
- **前置依赖**：T-P2-05
- **产出物**：`Data/Models/SyncPendingItem.swift`、`Data/Services/SyncQueueManager.swift`

### DoD

- [x] `SyncPendingItem` @Model 已定义（entityType、entityId、operation、createdAt）
- [x] 每次写入本地数据后，自动加入 SyncQueue
- [x] App 前台恢复时（`scenePhase == .active`）触发后台处理队列
- [x] 队列处理成功后清除对应条目；失败时保留（下次重试）

---

## QA-P2 P2 验收

- **负责角色**：QA Reviewer + Test Engineer
- **前置依赖**：T-P2-01 至 T-P2-07 全部完成

### 自动化测试（Test Engineer）

- [x] `QiuJiTests/` 测试 target 已创建
- [x] SwiftData Model 单元测试（`TrainingSession`、`DrillEntry`、`DrillSet` 级联关系）
- [x] Repository CRUD 测试（Session、Favorite、AngleTest 各覆盖 happy path + 空状态）
- [x] `DrillContentService` Bundle 解析测试（index 加载、单 drill 加载、不存在 ID 返回 nil）
- [x] `SyncQueueManager` enqueue/count 测试
- [x] 所有测试使用 `ModelContainerFactory.makeInMemoryContainer()` — 不污染真实数据
- [x] `xcodebuild test` 全部通过

### 人工测试计划

- [x] `tasks/test-plans/TP-P2.md` 已编写并由用户在设备上执行（2026-04-10，31/31 项完成；3 issue 已修复：FL-001/FL-002/B-03）

### 验收要点（QA Reviewer）

- [x] **离线场景**：断网后创建训练记录，SwiftData 写入成功，UI 正常（TP-P2 流程 3 全项通过）
- [x] **恢复联网**：网络恢复后 SyncQueue 自动上传后端（TP-P2 流程 8；FL-001 已修复 xcconfig URL 截断问题）
- [x] **空数据**：首次启动无本地数据时，fallback JSON 可加载（TP-P2 S-01/S-04/E-01/E-03 通过）
- [x] **匿名用户**：未登录时训练记录可创建，登录后数据迁移无重复（TP-P2 流程 1/2/6 通过；FL-002 已修复迁移 Alert 时序）
- [x] **错误处理**：后端请求失败时用户看到友好提示，不崩溃（TP-P2 流程 9 通过）

### QA 验收结论

- **状态**：✅ 附条件通过（2026-04-10）
- **条件**：用户重新构建后在设备上确认 FL-001（流程 8 后端连通性）、FL-002（流程 6 迁移 Alert）、B-03（训练 Tab 计划列表）修复生效
- **自动化**：235/235 通过
- **人工测试**：31/31 通过；发现 3 issue（P1×1 + P2×2），全部代码修复完成 + Code Review 确认正确

---

## ADR 记录区

### ADR-001（继承自 P1）

见 `tasks/phases/P1-foundation.md ADR-001`：LeanCloud → 自建 REST API，影响 T-P2-05 同步服务名称与实现。

### ADR-002 — 取消 CloudKit 公开库，内容走 Bundle + 自建 API

- **状态**：已采纳（2026-03-29）
- **背景**：原计划用 CloudKit Public Database 分发只读 Drill / OfficialPlan，用户私有数据走自建 REST API（ADR-001）。客户端从未集成 CloudKit API；`CloudKitContentService` 仅为 Bundle 加载器（已重命名为 `DrillContentService`）。
- **决策**：不再创建 CloudKit 容器（H-07 取消）。公开内容的分发与热更新统一由自建后端提供；客户端以 **Bundle JSON 为离线保底**，联网时通过 REST 增量拉取（在 T-P2-05 或后续子任务中落地 `GET /drills` 等）。
- **后果**：
  - 减少 Apple 侧 Schema/部署与「双云」心智负担；
  - 内容更新依赖自有服务可用性（与训练数据同步同一运维面）；
  - QA-P2「内容静默刷新」验收改为针对自建 API（实现后），非 CloudKit。
- **不适用**：不引入 CloudKit Private Database 作为用户数据存储（与 ADR-001 一致）。

### ADR-003 — SwiftData 版本化 schema（V1/V2）+ 轻量迁移，落地契约 §4.1 字段扩展

- **状态**：已采纳（2026-08-06，问题集合 v29 W3）
- **背景**：
  - `ModelContainerFactory` 原先用裸 `Schema(allModels)` 建容器，**无 `VersionedSchema`、无 `SchemaMigrationPlan`**。
    历史上新增 `AngleTestResult.quizType` / `errorMM` 靠「带默认值属性 + SwiftData 隐式轻量迁移」侥幸通过，
    没有版本标识，也没有任何迁移的实证测试——下一次结构性变更没有护栏。
  - `.kiro/steering/content-data-contract.md` §4.1 定稿了一批字段扩展（会话分类 `kind`、
    训练心得 / 顺序 / 达标说明快照、球形归属与显示名快照、单位语义、达标线快照、每组用时、
    角度成绩的会话归属），命中 `00-orchestrator.mdc` ADR 强制触发清单两项：
    **SwiftData Schema 结构性变更** + **新增 `MigrationPlan`**。
- **决策**：
  1. 新增 `QiuJiSchemaV1`（`QiuJi/Data/Models/QiuJiSchemaV1.swift`）——把**字段扩展前**已发布的
     `TrainingSession` / `DrillEntry` / `DrillSet` / `AngleTestResult` 形态以**嵌套类型冻结为历史快照**
     （版本 `1.0.0`）；未变更的 5 个模型（`UserActivePlan` / `DrillFavorite` / `SyncPendingItem` /
     `CustomPlan` / `CustomPlanDrill`）直接复用顶层类型，V1 与 V2 共享同一形状。
  2. 新增 `QiuJiSchemaV2`（版本 `2.0.0`）= 当前顶层模型集，并新增
     `QiuJiMigrationPlan`：`stages = [.lightweight(V1 → V2)]`。
  3. `ModelContainerFactory.makeContainer()` / `makeInMemoryContainer()` 改为
     `ModelContainer(for: currentSchema, migrationPlan: QiuJiMigrationPlan.self, ...)`；
     新增 `makeContainer(at:)` 作为测试接缝（迁移测试用它打开旧库）。
  4. 按契约 §4.1 加字段，**全部可选或带默认值**以走轻量迁移：
     `TrainingSession.kind = "drill"`；`DrillEntry.orderIndex = 0` / `note = ""` / `criteriaText = ""`；
     `DrillSet.formationToken?` / `formationName?` / `unitLabel = "球"` / `passMade = 0` / `passTotal = 0` /
     `durationSeconds?`；`AngleTestResult.sessionId?`。
- **迁移策略与默认值语义**：
  - 轻量迁移（无 `willMigrate`/`didMigrate` 自定义阶段）：新增列由 SwiftData 就地加到既有表，
    旧行取默认值，**不触碰任何既有列与关系**。
  - 旧数据的默认值语义须与历史事实相符：旧库会话一律是训练 Tab 产生的真实球台成绩 → `kind = "drill"`；
    旧库组次一律按球计数 → `unitLabel = "球"`；`passMade/passTotal = 0` 表示「未设定达标线」；
    球形归属与每组用时旧库确实不存在 → 可选为 `nil`（不编造）。
- **实证（红线「数据零丢失」不得以删库重建绕过）**：
  `QiuJiTests/SwiftDataMigrationTests.swift` 用 V1 schema 写一个**落盘**旧库（2 session / 2 entry /
  4 set / 3 angle），再用当前容器打开同一文件，断言：条数与全部字段值不变、
  session↔entry↔set 关系图完整、新字段取默认值；并用 `SQLite3` 直读 `PRAGMA table_info`
  证明迁移前该文件**没有** `ZKIND`/`ZDURATIONSECONDS`/`ZSESSIONID` 列、迁移后有且是旧列的超集
  （即同一物理文件就地加列，而非删库重建）。另有一例证明迁移后写入新字段可持久化。
- **后果**：
  - 后续每次结构性变更必须新增 `QiuJiSchemaVn` + 一个 stage，`QiuJiSchemaV1` 作为历史快照**禁止再修改**；
  - 代价是 App 二进制里长期保留 V1 的模型副本（Apple 官方迁移范式的既有代价，可接受）；
  - 新字段本批**只落 schema，不接任何写入与 UI**（W4 训练录入 / W5 练习与 tool / W6 统计读取）；
    `BackendSyncService` 的 DTO 未变更，同步语义保持原状（新字段是否上传由 W4/W5 决定）。
- **回滚考虑**：
  - 代码回滚（恢复裸 `Schema`）安全：新增列在旧代码下只是未映射属性，SwiftData 忽略即可，
    既有数据仍可读；但**已写入新字段的值会不可见**（不会被删除）。
  - 不提供 V2 → V1 的降级迁移：轻量迁移不可逆方向上没有语义损失需求，且 App 不支持降级安装。
  - 若日后必须把某个新字段改成非可选/无默认值，则不能再走轻量迁移，须新增自定义阶段并单独 ADR。

### ADR-004（ADR-v31-01）— SwiftData V3：自定义计划改存强度系数，V2→V3 自定义迁移折算轮数

- **状态**：已采纳（2026-08-09，问题集合 v31 W0）
- **场景**：
  - 契约 §6.6（裁定 D14）定：drill JSON 是训练剂量唯一真源，计划（官方 + 自定义）
    **不再存裸 `sets`/`ballsPerSet`**，只存强度系数，实际球数在激活训练时由内容解析、
    落 `DrillSet` 时快照冻结。
  - 持久化侧 `CustomPlanDrill` 存着 `sets` / `ballsPerSet` 两个裸球数字段，与该裁定直接冲突。
  - 命中 `00-orchestrator.mdc` ADR 强制触发清单两项：**SwiftData Schema 结构性变更** +
    **`MigrationPlan` 变更**。
- **选项**：
  - A：保留旧字段，新增 `roundsPerFormation` 并存 —— 两套真源并行，正是 D14 要消灭的形态；
  - B：轻量迁移直接删旧字段、新字段取默认值 1 —— 用户已建计划的强度信息全部丢失；
  - C：新增 V3 + **自定义迁移阶段**，用旧值折算出轮数后写入新字段。
- **决策**：选 **C**。
  1. 新增 `QiuJiSchemaV3`（版本 `3.0.0`，`QiuJi/Data/Models/QiuJiSchemaV3.swift`）= 当前顶层模型集；
     `ModelContainerFactory.currentSchema` 指向 V3。
  2. `CustomPlanDrill`：`sets` / `ballsPerSet` → `roundsPerFormation: Int = 1`（默认值同时是迁移存储默认值）。
  3. `CustomPlan` / `CustomPlanDrill` 的**旧形状下沉为 `QiuJiSchemaV2` 的嵌套历史快照**
     （V1 与 V2 同形，故 `QiuJiSchemaV1.models` 一并改引 `QiuJiSchemaV2.CustomPlan(Drill)`）。
     沿用 ADR-003 的历史快照范式：V1/V2 嵌套类型冻结、禁止再修改。
  4. `QiuJiMigrationPlan.stages` = `[.lightweight(V1→V2), .custom(V2→V3, willMigrate:didMigrate:)]`。
- **原因（为什么不能是轻量迁移）**：`roundsPerFormation` 的值要由旧 `sets` 与该 drill 的**球形数**
  算出，而旧列在 V3 形态里已不存在——轻量迁移没有读旧值的时机。故 `willMigrate` 先按行 id
  记下折算结果（`CustomPlanDoseMigration.pendingRounds`），`didMigrate` 再写回新列。
- **折算规则**：`rounds = max(1, sets / 球形数)`，无球形声明按 1 球形算（即 `rounds = sets`）。
  球形数取 `DrillContentService.formationCount(forDrillId:)`：优先 `sets.perFormation.count`
  （v31 内容批 W1x 落地后为权威），回落 `tutorial.formations.count`，再回落 1。
  下限 1 轮：短序列多球形（如 2 组 3 球形）折算为 0 时钳到 1，宁可多练不可归零。
- **实证（红线「数据零丢失」不得以删库重建绕过）**：
  `QiuJiTests/SwiftDataMigrationTests.swift` 新增两例，沿用 ADR-003 的 v29 W3 验证法——
  用 V2 schema 写落盘旧库（1 计划 / 3 条目，分别覆盖单球形 6/1、双球形 6/2、三球形 2/3 三种取整分支），
  用当前容器打开同一文件，断言：计划与条目条数、名称、`drillId`、`drillNameZh`、`order` 全部不变，
  三条 `roundsPerFormation` 分别为 6 / 3 / 1；并用 `PRAGMA table_info` 证明迁移前
  `ZCUSTOMPLANDRILL` 有 `ZSETS`/`ZBALLSPERSET` 无 `ZROUNDSPERFORMATION`、迁移后有新列且
  身份列俱在（同一物理文件就地改列）。另一例证明迁移后写入可持久化。
- **后果**：
  - `DrillTrainingPlanService` / `CustomPlanBuilderViewModel` / `TrainingHomeViewModel` 的
    每组球数改为从内容侧 `defaultBallsPerSet` 回落取值——这是 **W0 的过渡实现**，
    W2 会改为按 `perFormation` 逐球形派生；
  - 迁移期间会读 Bundle drill JSON（`formationCount`），迁移不再是纯数据库操作；
    内容缺失时回落 1 球形，等价于 `rounds = sets`，不会失败；
  - `CustomPlanDoseMigration.pendingRounds` 是 `nonisolated(unsafe)` 静态字典，
    仅在一次迁移的 will/did 之间存活并在 `didMigrate` 清空。
- **回滚考虑**：不提供 V3 → V2 降级（App 不支持降级安装）。代码回滚会使 `roundsPerFormation`
  列变成未映射属性，旧代码读不到强度信息且 `sets`/`ballsPerSet` 已不存在，等价于用户自定义
  计划的量值全部回落默认——故一旦发版，回滚需配套写反向迁移。
- **日期**：2026-08-09

### ADR-005（ADR-v31-02）— 新增 `TrainingDoseResolver`：剂量解析收敛为 Data 层单一通路

- **状态**：已采纳（2026-08-09，问题集合 v31 W2）
- **场景**：契约 §6.6 定「计划只存强度系数，实际球数在激活训练时由内容解析」。该解析
  同时被 4 个消费方需要：`TrainingHomeViewModel`（今日课表）、`ActiveTrainingViewModel`
  （录入展开与落库）、`CustomPlanBuilderViewModel`（自定义计划录入预览）、动作库/计划详情
  的展示文案。命中 ADR 强制触发清单的**跨模块边界**一项：新增一条 Data → Features 的
  公共通路（含新值类型 `PlannedTrainingSet` / `ResolvedDose`）。
- **选项**：
  - A：各 ViewModel 各自解析 —— 四份口径必然漂移（v29 的「全部预填第一个球形」就是这么来的）；
  - B：塞进 `DrillContentService` —— 该服务职责是内容加载与解码，混入计划语义会让内容侧
    单测被计划格式牵连；
  - C：新增独立无状态解析器 `QiuJi/Data/Services/TrainingDoseResolver.swift`。
- **决策**：选 **C**。`TrainingDoseResolver.resolve(content:dose:legacySets:legacyBallsPerSet:formationOptions:)`
  是唯一入口，输出 `ResolvedDose`（球形组列表）与派生 `plannedSets`（展开后的组序列）。
  1. **展开顺序**固定为球形 1 轮 1 → … → 球形 N 轮 M，顺序以内容 `perFormation` 声明序为准
     （球形即难度阶梯，契约 §6.6 推论 2）；
  2. **逐组 `targetBalls`** = 该球形 `ballsPerRound`，异构球形逐组不同；
  3. **单球形不带 token**（`formationToken`/`formationName` 保持 nil，契约 §4.1），
     `formationOptions(forDrillId:)` 仍只在 >1 球形时返回非空；
  4. **三条路径**：旧格式计划条目（`sets`/`ballsPerSet` 非 nil）→ 同构兼容路径，不做球形展开；
     有 `perFormation` → 逐球形展开；无 `perFormation`（8 条无序列 drill）→ 汇总兜底
     `defaultSets`/`defaultBallsPerSet`。
- **后果**：
  - `TodayDrillItem` / `ActiveDrill` / `CustomDrillItem` 均改为携带 `[PlannedTrainingSet]`，
    原先单一的 `sets`/`ballsPerSet` 退化为派生只读属性 —— 这是表达异构多球形的必要条件；
  - 展示文案统一由 `ResolvedDose.volumeText(unitLabel:)` / `compactVolumeText` 产出，
    同构「N 轮 × N 球/杆」、异构「N 球形 · N 轮 · 共 N 球」；
  - `PlanDrillRef.legacyVolume` 不再是多球形展开路径，仅供 W3 重写前的旧格式官方计划兜底；
  - W3 重写官方计划、W5 删 `PlanDrillRef.sets/ballsPerSet` 后，本 ADR 第 4 条的
    「旧格式路径」应随之删除。
- **日期**：2026-08-09

### ADR-006（ADR-v34-01）— 剂量口径全库重定（15 颗/位置）与 `roundsPerFormation` 倍数语义（B 方案，不做 Schema V4）

- **状态**：已采纳（2026-08-11，问题集合 v34 W0；用户逐项拍板 R1–R13）
- **场景**：
  - v31 的剂量口径（总量护栏 40–60 球/drill，D13）与用户实际训练强度不符。用户以
    `tasks/训练量填写表.md`（2026-08-11 03:03 定稿，逐球形手填）重定全库：重复型
    **每位置 15 颗 × 轮数 = 杆数（轮 = 位置）**，走位链 **每轮球数 = 杆数 × N 轮**，
    总量 4150 → 9493 球（×2.3）。
  - 「位置全覆盖」新口径下，`roundsPerFormation` 的旧语义（每球形轮数，覆盖
    `defaultRounds`）会**砍位置**，与新口径冲突。
  - 命中 ADR 强制触发清单：**数据同步策略变更**（剂量真源口径与门禁契约重定）+
    **跨模块边界**（`TrainingDoseResolver` 输出语义变更影响全部 4 个消费方，W4 落地）。
- **选项**（`roundsPerFormation` 归宿）：
  - A：Schema V4 迁移，字段改名/重造，语义显式化 —— 又一轮自定义迁移，成本高，
    且 V3 刚上线（ADR-004）；
  - B：**字段保留、默认 1，语义重定义为「整个动作重复几遍（倍数）」** —— 位置永远
    全覆盖，无迁移（既有 V3 数据值多为 1，`max(1, defaultSets)` 写入方同批改掉）；
  - C：删字段，计划一律完整剂量 —— 丢掉「一课重复 2 遍」的表达能力。
- **决策**：选 **B**（用户 2026-08-11「B 吧」，契约 D17）。
  1. 展开 = 内容侧完整剂量 × 倍数；`dose.formations` 按 token 选球形能力保留，但逐球形
     `rounds` 不得低于该球形 `defaultRounds`（低于 = 砍位置 = I11 FAIL）；
  2. 官方计划 JSON **一律不写** `roundsPerFormation`（完整剂量即默认 1 倍，重复靠
     计划内多次编排该动作，v34 R6）；
  3. 门禁同批落地（FL-029 第 3 条：改口径必须同步门禁）：D13 护栏与 D15 阶梯放宽从
     `verify_tutorial_sync.py` 删除，替换为阻塞级**形状约束**（重复型 `bpr ∈ [8,15]`
     默认 15、`defaultRounds == 杆数`，例外凭 `doseNote` 豁免，D18）；I11 加
     `formations[].rounds` 下限校验；`MODEL_SPEC.FormationDose` 与 Swift 侧同步加
     `doseNote: String?`。
- **后果**：
  - `TrainingDoseResolver`（`:139`/`:159` uniform override）、`DrillTrainingPlanService`
    （`max(1, defaultSets)` → 1）、`CustomPlanBuilderViewModel`（stepper 轮数 → 遍数）
    的改造落 **W4**；本 ADR 先锁语义与门禁；
  - **过渡窗口**：形状约束转阻塞后、W2 剂量写回前，存量剂量（v31 口径）触发 I6b FAIL
    属预期，W2 后复核归零；窗口内不 push（pre-push 钩子不触发）；
  - 单次训练时长显著上升（中位 75 球/球形），由 R6/R7 的计划重排（2.5 球/分钟反算
    `minutesPerSession`、课时档 75–150 min）消化，落 W3。
- **回滚考虑**：数值回滚 = 按填写表旧口径重写内容 JSON（git 可回退）；语义回滚只需
  恢复 resolver 的 uniform override 分支，无 schema 迁移连带。
- **日期**：2026-08-11

### ADR-007（ADR-v36-01）— 上行同步补齐 9 个成绩字段：传输层与后端 schema 对齐，双端一律容忍缺字段

- **状态**：已采纳（2026-08-12，问题集合 v36 W1）
- **场景**：命中 ADR 强制触发清单的**数据同步策略变更**。客户端 SwiftData V2 起已落地
  契约 §4.1 的 9 个成绩字段（`DrillSet.formationToken/formationName/unitLabel/passMade/
  passTotal/durationSeconds`、`DrillEntry.orderIndex/note/criteriaText`），但
  `TrainingSessionDTO` 与后端 `drillSetSchema`/`drillEntrySchema` 从未跟上 ⇒ 服务器副本
  有损。其中 `unitLabel` 缺失最危险：恢复时「局/次」会被当成「球」，是**语义错误**而非
  单纯字段丢失。本轮只动传输层与后端，**不做 SwiftData Schema V4**（本地模型字段已齐）。
- **选项**：
  - A：DTO 新字段声明为必填（`decode`）、后端 schema 加 `required` —— 语义最严，但旧后端
    回包缺字段会让解码抛错 → `syncSession` 误判上传失败 → 队列项永不出队、无限重试
    （`BackendSyncService.swift` 既有注释已记录该陷阱，v29 W5 因此确立惯例）；
  - B：**DTO 新字段 `decodeIfPresent` + 默认值，后端登记但给 default、不加 required**；
  - C：只补后端 schema、DTO 待 W3 下行时再补 —— 上行仍有损，Q1 未收口。
- **决策**：选 **B**。
  1. `DrillSetDTO` / `DrillEntryDTO` 各自补显式 `init(from decoder:)`（写 `init` 会抑制
     memberwise init，故同时补显式成员初始化器供编码路径用），新字段全部
     `decodeIfPresent` + 与本地模型一致的默认值（`unitLabel` 默认 `"球"`，
     `passMade/passTotal/orderIndex` 默认 0，`note/criteriaText` 默认 `""`，
     `formationToken/formationName/durationSeconds` 为可选 nil）；
  2. 后端 `drillSetSchema`/`drillEntrySchema` 逐字段登记 —— mongoose 默认 `strict: true`
     会**静默丢弃**未声明字段，不登记等于白传；一律给 default、**不加 required**，与客户端
     的容忍策略对称，旧客户端写入不会被整条拒绝；
  3. 编码路径直接透传，无转换、无兜底改写（服务器副本 = 本地真值）。
- **后果**：
  - 服务器 `TrainingSession` 文档从此含全部成绩字段，为 W3 下行恢复提供无损数据源；
  - 双端「都容忍缺字段」意味着**字段脱节不会报错、只会静默丢数据**——本次正是这样潜伏的。
    机器护栏（DTO CodingKeys ↔ mongoose paths 比对）是 W4/Q5 的必做项，不是可选项；
  - 存量服务器文档旧字段仍缺，取默认值即可（用户已授权本轮部署时清空 MongoDB，W4 执行）；
  - 回归护栏落在 `QiuJiTests/V29W5CognitiveToolSessionTests`：编码侧断言 9 个 key 且
    `unitLabel="局"` 等非默认值原样出现；解码侧模拟旧后端缺全部新字段的回包，断言解码成功
    并取默认值（防「解码失败 → 队列卡死」）。
- **回滚考虑**：纯加字段、无迁移。客户端回滚后新字段被后端保留但无人读；后端回滚后
  `strict: true` 重新丢弃这些字段，客户端解码因 `decodeIfPresent` 不受影响。
- **日期**：2026-08-12

### ADR-008（ADR-v36-02）— 下行恢复：insert-if-absent 合并 + 服务端 `updatedAt` 锚点 + 先推后拉

- **状态**：已采纳（2026-08-12，问题集合 v36 W3 / D-v36-1）
- **场景**：命中 ADR 强制触发清单的**数据同步策略变更**。`fetchSessionsAfter` 定义后全仓库
  零调用方，服务器只是纯写入端备份，换机/重装没有任何代码把数据拉回 SwiftData。本轮补齐
  DTO→实体重建、合并策略、触发时机，**不做 SwiftData Schema V4**（红线）。
- **决策 1：冲突策略 = insert-if-absent，本地永不被远端覆盖。**
  - 备选：按 `updatedAt` 比较取新者 —— **不可行**：本地模型没有修改时间字段，加就要动 Schema
    （红线）；拿不到可信比较依据还覆盖，等于可能用服务端旧副本盖掉刚编辑过的本地记录，
    那是真丢用户数据。
  - 反方向的代价只是「服务端更新的版本晚一点才体现」，而本地任何一次编辑都会入队上传、
    服务端最终被本地覆盖，方向自洽。当前是单设备模型（多设备合并与 D-v36-2 的墓碑同属
    未来需求）。
- **决策 2：增量锚点 = 服务端 `updatedAt` 最大值，存 UserDefaults，按 userId 分键。**
  - 用服务端时钟而非客户端时钟：后端 GET 过滤条件就是 `updatedAt > after`，客户端时钟若快于
    服务端，用本地 `Date()` 当锚点会**静默漏掉**那段时间差内落库的记录。
  - `updatedAt` 不进业务 DTO（W1 已定稿字段集），改用外层信封 `SyncedRecord<Payload>` 承载。
  - 存 UserDefaults 而非新增 SwiftData 实体：锚点是单键值的客户端同步元数据，丢了只会多拉
    一次（合并幂等），为它动 Schema 不划算且撞红线。按 userId 分键，否则换号登录时新账号的
    历史会被判为「早于锚点」而永远拉不到。
  - 锚点只前进不后退；整批无 `updatedAt`（旧后端）或落盘失败时**不推进**——宁可下次重拉。
- **决策 3：同步顺序固定「先推（`processQueue`）后拉（`restore`）」。**
  - 队列里可能挂着未发出的 delete 项，先拉会把刚删掉的记录拉回来（「删除后无法恢复」的承诺
    被打破）。先推则服务端副本已被删除，拉取自然拉不到。
  - 推失败（离线/5xx）时 delete 项保留，故第二道防线：`SyncRestoreService` 合并前收集队列中
    所有 delete 项的 clientId 并跳过。读队列失败时**整轮放弃恢复**，不盲插。
- **决策 4（顺带修复）：下行日期解码改用容忍小数秒的自定义策略。**
  后端 `res.json()` 输出的是 Mongoose `toJSON()` 的 `...T03:00:00.000Z`，而
  `JSONDecoder.DateDecodingStrategy.iso8601` **只认无小数秒形式** —— 沿用它会让每一个含日期的
  响应整条解码失败（下行恢复根本跑不通，且 POST 响应解码也会被误判成上传失败）。
  新增 `APIDateCoding.decodingStrategy` 同时接受两种写法，解析不了时抛带 `codingPath` 的
  `dataCorrupted`，不静默给默认时间（FL-029）。编码侧不变（`.iso8601`，Mongoose 能解析）。
- **触发时机**：登录成功（新增 `.didCompleteLogin` 通知，挂在 `AuthState.login`，覆盖所有登录
  入口）→ 全量拉取；`scenePhase == .active` → 增量拉取。两者都先 `processQueue`。
- **后果**：
  - 服务端记录只能「新增」到本地，永不覆盖/删除本地实体；服务端删除不会下行传播（硬删无墓碑，
    D-v36-2 已认定为未来需求）。
  - `DrillEntry`/`DrillSet` 的本地 id 在恢复时新生成——服务端子文档 `_id: false`，本无 id 可还原，
    且它们不参与跨端标识。
  - 未做端到端实跑（本机无 mongod / 后端未按 W4 重新部署），链路正确性目前只有单测背书。
- **回滚考虑**：新增文件 `SyncRestoreService.swift` + 两个触发点；移除触发点即回到「纯上行」，
  无数据结构变更。
- **日期**：2026-08-12

### ADR-009（ADR-v37-01）— 复习课次允许 `formations[].rounds < defaultRounds`（D-v37-2=B，部分回退 v34 R9）

- **状态**：已采纳（2026-08-13，问题集合 v37 W0；用户拍板 D-v37-2=B）。本 ADR **只锁语义**；
  Swift / `MODEL_SPEC` / `_dose_errors` / `TrainingDoseResolver` 的代码改动落 **v37 W4**。
- **场景**：
  - v34 R9 / ADR-006 定死「位置永远全覆盖」：`formations[].rounds` 不得低于内容
    `defaultRounds`（门禁 `_dose_errors` 下限 FAIL + Resolver 运行时钳到下限）。
  - v37 R5 要求同一动作首次作为主课出现后，在后续课次（一周内的次，可跨周）以递减
    训练量复现。在 R9 口径下，「减量」不能靠调低轮数表达——调低即砍位置 = I11 FAIL。
  - 命中 ADR 强制触发清单：**技术方案部分回退**（动 v34 R9 的下限绝对化）+
    **跨模块边界**（I11 门禁与 `TrainingDoseResolver` 消费方，W4 落地）。
- **选项**：
  - A：球形子集复现（只列部分 token，现行即合法）——零契约破坏，但「同一球形少打几轮」
    无法表达，衰减只能靠少选位置，与「完整动作减量复习」不是同一件事；
  - B：**放宽 §6.6**：显式标记为衰减复现/复习的计划条目允许 `rounds < defaultRounds`；
    该 drill 在本计划中的首次引入课次仍须完整剂量。
- **决策**：选 **B**（用户 2026-08-13 拍板 D-v37-2=B）。
  1. 标记字段定名为 **`PlanDrillDose.decay: Bool`**（可选，缺省 / `false` = 非衰减）。
     挂在剂量对象上，不挂 `PlanDrillRef`，不复用 `SessionPhase.type == "review"`
     （相位「复盘记录」与衰减复现禁止撞名）；
  2. `decay: true` 时 I11 下限与 Resolver 钳制对该条目放宽；`decay` 缺省或 `false`
     时 v34 R9 下限原样生效；
  3. 同一 `drillId` 在一份官方计划中第一次出现的课次不得标 `decay: true`，且必须
     `rounds ≥ defaultRounds`（首次引入不得借例外砍位置）；
  4. 官方计划仍一律不写 `roundsPerFormation`；本例外只放宽 `formations[].rounds` 下限，
     不改倍数语义。
- **后果**：
  - 契约 §6.6 / §7 I11 行已于 **v37 W0** 落盘（契约 2.4）；
  - `_dose_errors` 下限判定、`TrainingDoseResolver` 钳制、`PlanDrillDose` 加字段 +
    `MODEL_SPEC` 同步（FL-029）落 **W4**，与计划 JSON 重写同批生效；
  - W5 I13 再查「同 drill 复现课次剂量单调不增、且减量条目必须带 `decay: true`」；
  - ⛔ 放宽面仅限显式标记条目，禁止把下限改成全局可选。
- **回滚考虑**：语义回滚 = 删 §6.6 例外并把 I11 恢复为无条件下限（契约降回 2.3 该句）；
  代码回滚（W4 之后）= 去掉 `decay` 键并恢复钳制。无 SwiftData Schema 变更，无迁移连带。
- **日期**：2026-08-13
