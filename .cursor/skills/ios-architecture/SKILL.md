# iOS Architecture Skill

## 触发场景

在以下情况读取并遵循本技能：
- 设计新 Feature 模块结构
- 讨论 ViewModel 与 Repository 的边界
- 评估是否引入新 SPM 依赖
- 重构现有代码分层

## 标准项目结构

```
BilliardTrainer/
├── App/
│   ├── BilliardTrainerApp.swift    # @main
│   └── AppRouter.swift             # 跨 Tab 路由
├── Features/
│   ├── Training/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Models/                 # Feature 专属 DTO（非 SwiftData）
│   ├── DrillLibrary/
│   ├── AngleTraining/
│   ├── History/
│   └── Profile/
├── Core/
│   ├── DesignSystem/
│   │   ├── Colors.swift
│   │   ├── Typography.swift
│   │   └── Spacing.swift
│   ├── Components/                 # BTDrillCard, BTEmptyState, BTLoadingView...
│   └── Extensions/
├── Data/
│   ├── Models/                     # @Model SwiftData 实体
│   ├── Repositories/
│   │   ├── Protocols/              # DrillRepositoryProtocol 等
│   │   ├── Local/                  # LocalDrillRepository
│   │   └── Remote/                 # CloudKitDrillRepository, LeanCloudUserRepository
│   └── Services/
│       ├── CloudKitService.swift
│       ├── LeanCloudService.swift
│       └── AuthService.swift
└── Resources/
    └── Drills/                     # Bundle 内 fallback JSON
```

## MVVM 分层规则

```
View
  └── 读取 @Observable ViewModel 状态
  └── 调用 ViewModel 方法（用户意图）

ViewModel
  └── 调用 Repository Protocol（不直接访问网络/SwiftData）
  └── 暴露 @Published 状态给 View

Repository Protocol
  ├── LocalRepository（SwiftData，离线主存储）
  └── RemoteRepository（CloudKit / LeanCloud，后台同步）
```

## 错误处理模式

```swift
enum AppError: LocalizedError {
    case networkUnavailable
    case syncFailed(String)
    case contentNotFound
    case authRequired
    // ...
    var errorDescription: String? { /* 用户可读中文描述 */ }
}
```

ViewModel 中：
```swift
func loadDrills() async {
    do {
        drills = try await repository.fetchDrills()
    } catch {
        errorState = AppError.from(error)  // 转译为 AppError
    }
}
```

## SPM 依赖评估清单

引入新依赖前必须回答：
1. 是否有系统 API 可以替代？（优先系统 API）
2. 该库是否维护活跃（近 6 个月有 commit）？
3. License 是否兼容商业使用（MIT / Apache）？
4. 会否显著增加二进制大小（>1MB 需在 ADR 中记录原因）？

## 性能要求

- 启动时间目标：冷启动 < 2 秒（iPhone 12 级别设备）
- 主线程规则：SwiftData 查询可在主线程小批量执行；批量操作（>100条）使用 `ModelActor`
- 内存：长列表使用 `LazyVStack` / `List`，避免一次性渲染全部数据
