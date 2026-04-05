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

- [ ] `tasks/test-plans/TP-P2.md` 已编写并由用户在设备上执行

### 验收要点（QA Reviewer）

- [ ] **离线场景**：断网后创建训练记录，SwiftData 写入成功，UI 正常
- [ ] **恢复联网**：网络恢复后 SyncQueue 自动上传后端；Drill 内容 OTA（若已实现）后台静默刷新
- [ ] **空数据**：首次启动无本地数据时，fallback JSON 可加载
- [ ] **匿名用户**：未登录时训练记录可创建，登录后数据迁移无重复
- [ ] **错误处理**：后端请求失败时用户看到友好提示，不崩溃

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
