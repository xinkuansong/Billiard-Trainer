# P2 — Data Layer（数据层）

> **目标**：SwiftData 全量 Schema、CloudKit 公开库内容拉取、自建后端用户数据同步、离线优先策略。
> **人工前置**：H-14 ✅（腾讯云服务器）、H-16 ✅（MongoDB）、H-07 ✅（CloudKit 容器）
> **前置 Phase**：P1 通过 QA

---

## T-P2-01 SwiftData Schema（全量实体）

- **负责角色**：Data Engineer
- **前置依赖**：T-P1-01
- **产出物**：`Data/Models/` 下所有 `@Model` 文件

### DoD

- [ ] 以下实体全部定义完成：`TrainingSession`、`DrillEntry`、`DrillSet`、`AngleTestResult`、`UserActivePlan`、`DrillFavorite`
- [ ] `ModelContainer` 在 `QiuJiApp` 中统一初始化，通过 `.modelContainer()` 注入
- [ ] 内存测试 Container（`isStoredInMemoryOnly: true`）已定义，供 Preview 和测试使用
- [ ] 所有关系（`@Relationship`）的 `deleteRule` 已显式设置（`TrainingSession` → `DrillEntry` → `DrillSet` 均为 `.cascade`）
- [ ] 编译通过，模拟器可启动

---

## T-P2-02 Local Repository 实现

- **负责角色**：Data Engineer
- **前置依赖**：T-P2-01
- **产出物**：`Data/Repositories/Protocols/`、`Data/Repositories/Local/`

### DoD

- [ ] `TrainingSessionRepositoryProtocol` 定义：`create`、`fetchAll`、`fetchByDate`、`update`、`delete`
- [ ] `LocalTrainingSessionRepository` 实现上述协议（使用 SwiftData `ModelContext`）
- [ ] `DrillFavoriteRepository` 实现收藏的增删查
- [ ] `AngleTestRepository` 实现角度测试历史的写入与按时间段查询
- [ ] 所有操作在主线程可安全调用（小批量）；批量操作提供 `ModelActor` 版本
- [ ] XCTest 基础测试：创建 Session → 读取 → 删除，断言数量正确

---

## T-P2-03 CloudKit 公开库内容拉取

- **负责角色**：Data Engineer
- **人工前置**：H-07 ✅（CloudKit 容器已创建，Schema 已部署）
- **前置依赖**：T-P2-01
- **产出物**：`Data/Services/CloudKitContentService.swift`

### DoD

- [ ] `CloudKitContentService.fetchAllDrills()` 可从公开库拉取 `DrillContent` 记录
- [ ] `fetchDrillsUpdatedAfter(date:)` 支持增量拉取
- [ ] App 启动时后台触发静默拉取（不阻塞 UI）
- [ ] 网络失败时降级到 Bundle fallback JSON，不崩溃
- [ ] CloudKit 容器 identifier 通过 `xcconfig` 注入（不硬编码）

---

## T-P2-04 Bundle Fallback JSON 结构

- **负责角色**：Content Engineer
- **前置依赖**：无（可并行）
- **产出物**：`Resources/Drills/index.json`、`Resources/Plans/index.json`

### DoD

- [ ] `Resources/Drills/index.json` 格式：`{"version": 1, "drills": ["drill_c001", ...]}`
- [ ] `Resources/Plans/index.json` 格式同上
- [ ] 至少包含 5 条示例 Drill JSON（用于开发阶段预览，P3 前完整生产）
- [ ] `CloudKitContentService` 的 `loadFallbackDrills()` 可成功解析

---

## T-P2-05 后端用户数据同步

- **负责角色**：Data Engineer
- **人工前置**：H-14 ✅（服务器已部署）、H-16 ✅（MongoDB 已创建）
- **前置依赖**：T-P1-07, T-P2-01
- **产出物**：`Data/Services/BackendSyncService.swift`

### DoD

- [ ] `BackendSyncService.syncSession(_:)` 调用 `POST /training-sessions`，上传本地 `TrainingSession`
- [ ] `BackendSyncService.fetchUserSessionsAfter(date:)` 调用 `GET /training-sessions?after=` 拉取增量数据
- [ ] 登录后触发一次性迁移：将匿名本地数据批量上传（`POST /training-sessions/batch`）
- [ ] 请求携带 JWT（`Authorization: Bearer`），401 时触发 token 刷新
- [ ] 数据仅关联当前登录用户（服务端按 JWT 隔离）

---

## T-P2-06 匿名用户本地模式

- **负责角色**：Data Engineer
- **前置依赖**：T-P2-01, T-P2-05
- **产出物**：`Data/Services/AuthState.swift` 更新

### DoD

- [ ] 未登录时：训练记录正常写入 SwiftData 本地；不触发后端上传
- [ ] 登录时：提示「登录后数据将同步云端」，用户确认后触发迁移上传
- [ ] 「我的」Tab 未登录状态显示登录引导，而非空白

---

## T-P2-07 SyncQueue（后台同步队列）

- **负责角色**：Data Engineer
- **前置依赖**：T-P2-05
- **产出物**：`Data/Models/SyncPendingItem.swift`、`Data/Services/SyncQueueManager.swift`

### DoD

- [ ] `SyncPendingItem` @Model 已定义（entityType、entityId、operation、createdAt）
- [ ] 每次写入本地数据后，自动加入 SyncQueue
- [ ] App 前台恢复时（`scenePhase == .active`）触发后台处理队列
- [ ] 队列处理成功后清除对应条目；失败时保留（下次重试）

---

## QA-P2 P2 验收

- **负责角色**：QA Reviewer
- **前置依赖**：T-P2-01 至 T-P2-07 全部完成

### 验收要点

- [ ] **离线场景**：断网后创建训练记录，SwiftData 写入成功，UI 正常
- [ ] **恢复联网**：网络恢复后 SyncQueue 自动上传后端，CloudKit 内容静默刷新
- [ ] **空数据**：首次启动无本地数据时，fallback JSON 可加载
- [ ] **匿名用户**：未登录时训练记录可创建，登录后数据迁移无重复
- [ ] **错误处理**：后端请求失败时用户看到友好提示，不崩溃

---

## ADR 记录区

### ADR-001（继承自 P1）

见 `tasks/phases/P1-foundation.md ADR-001`：LeanCloud → 自建 REST API，影响 T-P2-05 同步服务名称与实现。
