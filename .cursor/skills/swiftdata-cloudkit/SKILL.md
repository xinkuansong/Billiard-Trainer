# SwiftData + Drill Content Skill

> **命名说明**：目录名保留 `swiftdata-cloudkit` 仅为历史路径兼容；**产品已取消 CloudKit**（ADR-002），公开内容走 Bundle + 自建 REST API。

## 触发场景

在以下情况读取并遵循本技能：
- 定义或修改 SwiftData `@Model` 实体
- 实现 Drill / 计划内容加载（`DrillContentService`、Bundle JSON）
- 处理本地数据与自建 REST API 同步逻辑

## SwiftData 实体定义

### 核心实体

```swift
// 单次训练会话
@Model final class TrainingSession {
    var id: UUID
    var date: Date
    var ballType: String           // "chinese8" | "nineball"
    var totalDurationMinutes: Int
    var note: String
    var planId: String?            // 关联的官方/自定义计划 ID（可选）
    @Relationship(deleteRule: .cascade) var drillEntries: [DrillEntry]

    init(ballType: String) {
        self.id = UUID(); self.date = Date()
        self.ballType = ballType; self.totalDurationMinutes = 0; self.note = ""
        self.drillEntries = []
    }
}

// 单个 Drill 的训练记录
@Model final class DrillEntry {
    var id: UUID
    var drillId: String            // 对应 Drill JSON 的 id
    var drillNameZh: String        // 冗余存储，防止内容更新后记录失效
    @Relationship(deleteRule: .cascade) var sets: [DrillSet]
    var session: TrainingSession?

    var successRate: Double {
        let total = sets.reduce(0) { $0 + $1.targetBalls }
        let made  = sets.reduce(0) { $0 + $1.madeBalls }
        return total > 0 ? Double(made) / Double(total) : 0
    }
}

// 单组记录
@Model final class DrillSet {
    var id: UUID
    var setNumber: Int
    var targetBalls: Int           // 目标球数（如 15）
    var madeBalls: Int             // 进球数
    var entry: DrillEntry?
}

// 角度测试单题结果
@Model final class AngleTestResult {
    var id: UUID
    var date: Date
    var actualAngle: Double        // 正确角度（5°精度）
    var userAngle: Double          // 用户输入
    var pocketType: String         // "corner" | "side"
    var error: Double { abs(actualAngle - userAngle) }
}

// 用户激活计划
@Model final class UserActivePlan {
    var id: UUID
    var planId: String             // 对应 JSON 计划 ID
    var startDate: Date
    var currentWeek: Int
    var currentDay: Int
}

// 收藏
@Model final class DrillFavorite {
    var drillId: String
    var addedAt: Date
}
```

### Schema 迁移规范

```swift
// 每次 Schema 变更定义迁移方案
let schema = Schema([TrainingSession.self, DrillEntry.self, ...])
let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

// 迁移示例（添加新字段）：使用 MigrationStage.lightweight 处理可选字段新增
```

**规则**：
- 新增字段必须为 `optional` 或有默认值
- 重命名字段必须用 `@Attribute(.originalName("oldName"))` 声明
- 禁止直接删除字段（改为标记废弃：`var _deprecated_field: String? = nil`）

## Drill 内容：Bundle + 自建 API OTA（ADR-002）

**禁止**在应用目标中引入 `CloudKit` / `CKContainer` 做公开内容分发。

当前实现：`DrillContentService`（actor）从 `Resources/Drills/` 读取 `index.json` 与各分类 JSON。

**Bundle Fallback / 离线**：

```swift
// DrillContentService.swift（节选）
func loadFallbackDrills() -> [DrillContent] { ... }
func loadDrillFromBundle(id: String) -> DrillContent? { ... }
```

**未来 OTA**（T-P2-05 或专用任务）：使用 `URLSession` 调用自建后端，例如 `GET /drills?updatedAfter=`，合并进本地缓存；失败时继续使用 Bundle。

## 离线优先同步策略

```
用户操作
  → 立即写入 SwiftData（主线程，立即反馈）
  → 加入同步队列（后台，自建 REST API）

App 前台恢复
  → 后台触发：上传自建后端待同步项
  → （可选）后台触发：Drill 内容增量拉取（实现后）
```

```swift
// SyncQueue：简单的本地待同步队列
@Model final class SyncPendingItem {
    var entityType: String   // "TrainingSession" | "AngleTestResult"
    var entityId: UUID
    var operation: String    // "create" | "update" | "delete"
    var createdAt: Date
}
```

## 测试辅助

```swift
// 内存 Container，用于 Preview 和 XCTest
static var previewContainer: ModelContainer = {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TrainingSession.self, configurations: config)
    // 插入测试数据
    return container
}()
```
