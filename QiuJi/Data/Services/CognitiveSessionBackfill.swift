import Foundation
import SwiftData

/// 给 W5 之前落库的 `AngleTestResult`（`sessionId == nil`）补建归属的 cognitive 会话。
///
/// 分组口径复用 `HistoryViewModel.inferAngleSessions`（同 `quizType` 且间隔 ≤ 30 分钟为一组），
/// 与 `CognitiveSessionRecorder` 的实时口径同源，因此回填结果与实时落库结果形状一致。
///
/// **幂等**：只处理 `sessionId == nil` 的记录。第一次跑完所有历史记录都有归属，
/// 再跑一次扫到 0 条、建 0 个会话。因此 UserDefaults 标志丢失也不会重复建会话。
@MainActor
enum CognitiveSessionBackfill {

    /// 一次性回填已执行过的标志。仅用于跳过无谓的全表扫描，正确性不依赖它。
    static let completedFlagKey = "v29.w5.cognitiveSessionBackfillCompleted"

    struct Report: Equatable {
        /// 本次扫到的无归属历史成绩条数。
        let orphanResults: Int
        /// 新建的 cognitive 会话数。
        let createdSessions: Int
        /// 被赋上 `sessionId` 的成绩条数。
        let assignedResults: Int

        var isNoOp: Bool { orphanResults == 0 }

        var summary: String {
            "orphanResults=\(orphanResults) createdSessions=\(createdSessions) assignedResults=\(assignedResults)"
        }
    }

    /// 执行回填。可反复调用（幂等）。
    @discardableResult
    static func run(context: ModelContext) throws -> Report {
        // 迁移维护任务有意扫描全部 owner：每条孤儿成绩会在其自己的 owner 域补会话。
        // `#Predicate` 对可选 UUID 的 nil 比较在 SwiftData 上行为不稳，故在内存筛 nil。
        let all = try context.fetch(FetchDescriptor<AngleTestResult>())
        let orphans = all.filter { $0.sessionId == nil }
        guard !orphans.isEmpty else {
            return Report(orphanResults: 0, createdSessions: 0, assignedResults: 0)
        }

        // 不同 owner 即使题型和时间相邻也绝不能推断成同一 cognitive 会话。
        let inferred = Dictionary(grouping: orphans, by: \.ownerKey)
            .values
            .flatMap { HistoryViewModel.inferAngleSessions(Array($0)) }

        var createdSessions = 0
        var assignedResults = 0
        for group in inferred {
            let session = CognitiveSessionRecorder.makeSession(
                quizType: group.quizType,
                start: group.startDate,
                end: group.endDate,
                ownerKey: group.results.first?.ownerKey ?? DeviceGuestIdentity.ownerKey()
            )
            context.insert(session)
            createdSessions += 1
            for result in group.results {
                result.sessionId = session.id
                assignedResults += 1
            }
        }
        try context.save()

        // 回填出的历史会话不入同步队列：这些成绩本体（`AngleTestResult`）在当年落库时
        // 已各自入过队，补建的会话只是本地归属重建。首启一次性推送数百条历史会话
        // 收益不明而风险实在（队列洪峰），需要时另立批次按「历史数据补传」处理。
        return Report(orphanResults: orphans.count,
                      createdSessions: createdSessions,
                      assignedResults: assignedResults)
    }

    /// 启动时调用：标志未置位才跑，跑完置位。
    @discardableResult
    static func runOnceIfNeeded(context: ModelContext,
                                defaults: UserDefaults = .standard) -> Report? {
        guard !defaults.bool(forKey: completedFlagKey) else { return nil }
        do {
            let report = try run(context: context)
            defaults.set(true, forKey: completedFlagKey)
            print("[CognitiveSessionBackfill] \(report.summary)")
            return report
        } catch {
            // 不置位，下次启动重试；⛔ 不吞掉可见性——失败要留痕。
            print("[CognitiveSessionBackfill] failed: \(error.localizedDescription)")
            return nil
        }
    }
}
