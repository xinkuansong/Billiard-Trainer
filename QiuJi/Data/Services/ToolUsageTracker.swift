import Foundation
import SwiftData
import SwiftUI

/// 「打/解」分区与动作库试打的 4 个产品入口（契约 §5.3 的 `kind="tool"` 来源）。
enum ToolUsageEntry: String, CaseIterable {
    /// 走位编排台（非试打变体）。
    case freePosition
    /// 自由击球（`FreePlayView`）。
    case freePlay
    /// 训练首页「每日清台」（仍是 tool，只记活跃时长）。
    case dailyClearance
    /// 打一走二想三。
    case planThree
    /// 动作库试打（编排台的试打变体）。
    case drillTryout

    var displayNameZh: String {
        switch self {
        case .freePosition: return "自由走位"
        case .freePlay:     return "自由击球"
        case .dailyClearance: return "每日清台"
        case .planThree:    return "打一走二想三"
        case .drillTryout:  return "动作库试打"
        }
    }
}

/// 按**页面入口**记录工具使用活跃度。
///
/// ⛔ 红线（契约 §5.3）：`tool` 会话只有日期与时长，**不产生 `DrillEntry`、不写任何 made/target**。
/// 引擎判定的进袋不是真实球技，混入统计即污染水平评估。
///
/// **为何埋在页面入口而不是进袋判定点**：编排台 / 自由走位 / 动作库试打共用同一个
/// `PositionPlayViewModel`，在其进袋判定处埋点会让三个入口互相重复计数；而活跃度要的是
/// 「用户在这个工具里待了多久」，与打了几杆无关。
///
/// **时长口径**：
/// - 计时区间 = 页面出现 → 页面消失（或 App 退到后台），后台时间不计入；
/// - 落库值 `totalDurationMinutes` = 秒数除 60 四舍五入，**下限 1 分钟**
///   （沿用 `AngleTrainingSession.durationMinutes` 的既有算法；W3 已冻结 schema，
///   `TrainingSession` 上没有秒级字段，不新增字段）；
/// - 停留 < 5 秒（`minimumDurationSeconds`）视为误触/穿页，**不落库**；
/// - 同一次进出页面落 1 条会话；退到后台再回前台算新一段（各自满 5 秒才各落 1 条）。
enum ToolUsageTracker {

    /// 低于此停留时长视为误触，不落库。
    static let minimumDurationSeconds: TimeInterval = 5

    /// 落一条 `kind="tool"` 会话。停留不足阈值返回 nil（未落库）。
    @MainActor
    @discardableResult
    static func record(entry: ToolUsageEntry,
                       start: Date,
                       end: Date,
                       context: ModelContext) -> TrainingSession? {
        let seconds = end.timeIntervalSince(start)
        guard seconds >= minimumDurationSeconds else { return nil }

        let ownerKey = CurrentOwnerContext.shared.ownerKey
        let session = TrainingSession(kind: TrainingSessionKind.tool, ownerKey: ownerKey)
        session.date = start
        session.note = entry.displayNameZh
        session.totalDurationMinutes = max(1, Int((seconds / 60).rounded()))
        // ⛔ 到此为止：不建 DrillEntry、不写 made/target、不写 planId。

        context.insert(session)
        do {
            try context.save()
        } catch {
            print("[ToolUsageTracker] save failed: \(error.localizedDescription)")
            return nil
        }

        // D-v29-4（2026-08-06 裁定）：tool 时长上传。
        SyncQueueManager.shared.enqueue(entityType: "TrainingSession",
                                        entityId: session.id, operation: "create",
                                        ownerKey: ownerKey)
        return session
    }
}

// MARK: - View 埋点

/// 把一个工具页的「出现 → 消失」计成一条 `kind="tool"` 会话。
private struct ToolUsageSessionModifier: ViewModifier {
    let entry: ToolUsageEntry

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    /// 本段计时的起点；nil = 当前未在计时。
    @State private var startedAt: Date?

    func body(content: Content) -> some View {
        content
            .onAppear { startedAt = Date() }
            .onDisappear { flush() }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    // 回前台且页面仍在：开新一段计时。
                    if startedAt == nil { startedAt = Date() }
                default:
                    // 退到后台/失活：结算当前段，后台时间不计入活跃度。
                    flush()
                }
            }
    }

    private func flush() {
        guard let start = startedAt else { return }
        startedAt = nil
        ToolUsageTracker.record(entry: entry, start: start, end: Date(), context: modelContext)
    }
}

extension View {
    /// 记录本页的工具使用活跃度（`kind="tool"`，只记日期与时长）。
    func toolUsageSession(_ entry: ToolUsageEntry) -> some View {
        modifier(ToolUsageSessionModifier(entry: entry))
    }
}
