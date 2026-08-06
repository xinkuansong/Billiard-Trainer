import Foundation

/// `TrainingSession.kind` 的取值真源（契约 §5.3）。
///
/// 用命名常量而非 `enum` 存储：`kind` 在 schema 里是 `String`（W3 轻量迁移的前提），
/// 未知取值必须能原样读回而不是解析失败。
enum TrainingSessionKind {
    /// 真实球台成绩 —— 训练 Tab 正式训练流程。计入准确率与周目标。
    static let drill = "drill"
    /// 屏内认知测验 —— 练习 Tab「练」分区。计入准确率（与 drill 分开展示）与周目标。
    static let cognitive = "cognitive"
    /// 工具使用活跃度 —— 「打/解」分区与动作库试打。⛔ 只记日期与时长，不记任何成败（契约 §5.3）。
    static let tool = "tool"

    /// 计入训练量与周目标的会话类型（契约 §5.3 表：`tool` 两列均为 ❌）。
    static let goalCounting: Set<String> = [drill, cognitive]

    /// 该会话是否计入周目标与统计页训练量。⛔ `tool` 恒为 false。
    static func countsTowardGoal(_ kind: String) -> Bool {
        goalCounting.contains(kind)
    }

    /// 该会话是否可以进入准确率聚合。⛔ `tool` 恒为 false（引擎判定的进袋不是真实球技）。
    static func countsTowardAccuracy(_ kind: String) -> Bool {
        kind == drill || kind == cognitive
    }
}
