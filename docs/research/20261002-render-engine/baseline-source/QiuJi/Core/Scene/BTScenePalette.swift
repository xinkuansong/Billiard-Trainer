import UIKit

/// SceneKit-side UIColor palette (isolated from SwiftUI Design Tokens).
/// C17 / D2：约束描边氰色等仅在此单点定义，禁止在 VM 内再写字面量。
enum BTScenePalette {
    /// 落区 / 过点 / 防守目标环等约束描边氰色（Silu / PlanThree / Snooker）。
    static let constraintCyan = UIColor(red: 0.2, green: 0.85, blue: 0.95, alpha: 0.95)
}
