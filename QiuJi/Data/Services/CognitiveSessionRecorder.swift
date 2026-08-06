import Foundation
import SwiftData

/// 把「练」分区的答题归入 `kind="cognitive"` 的 `TrainingSession`（契约 §4.1 / §5.3）。
///
/// **会话边界口径**：同 `quizType` 且与该 quizType 上一道已归属的题间隔 ≤ 30 分钟
/// （`AngleSessionInference.gap`）即同一会话，否则新建。
///
/// 之所以不用「页面退出即封口」：本口径与 `HistoryViewModel.inferAngleSessions` 的历史推断
/// **完全同源**，因此
/// 1. 回填出来的历史会话与实时落库的会话口径一致，可互相反证；
/// 2. W6 把历史页从内存投影换成真 session 后，用户看到的分组不会变。
/// 页面退出后 30 分钟内回到同一页继续答题会并入同一会话——这正是历史页当前的呈现方式。
///
/// 会话时长取「首题到末题」的分钟数（下限 1 分钟），与 `AngleTrainingSession.durationMinutes` 同算法。
@MainActor
final class CognitiveSessionRecorder {

    /// 同一会话内相邻两题的最大间隔。与历史推断共用同一常量，避免两处口径漂移。
    static var gap: TimeInterval { AngleSessionInference.gap }

    /// 回看窗口：从同 quizType 的最近若干条里找「已归属会话」的锚点。
    /// 取 50 是因为 W5 之后每条新成绩落库即带 sessionId，锚点几乎恒为第一条；
    /// 留窗口只为兼容回填之前遗留的 nil 记录夹在中间的情形。
    private static let lookbackLimit = 50

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    struct Resolution {
        let session: TrainingSession
        /// 本次调用新建了会话。
        let isNew: Bool
        /// 本次调用改变了会话时长（复用既有会话且跨过一分钟边界）。
        let durationChanged: Bool

        /// 会话状态有变，需要（重新）入同步队列。
        var needsUpload: Bool { isNew || durationChanged }
    }

    /// 解析 `result` 应归属的 cognitive 会话，必要时新建并插入 `context`（不 `save`，由调用方一并提交）。
    func resolveSession(for result: AngleTestResult) throws -> Resolution {
        if let active = try activeSession(quizType: result.quizType, at: result.date) {
            let updated = Self.durationMinutes(from: active.date, to: result.date)
            let changed = updated != active.totalDurationMinutes
            active.totalDurationMinutes = updated
            return Resolution(session: active, isNew: false, durationChanged: changed)
        }
        let session = Self.makeSession(quizType: result.quizType,
                                      start: result.date,
                                      end: result.date)
        context.insert(session)
        return Resolution(session: session, isNew: true, durationChanged: false)
    }

    /// 构造一条 cognitive 会话。⛔ 不带 `DrillEntry`、不带任何成绩字段——
    /// 成绩本体在 `AngleTestResult`，会话只承载归属与时长。
    static func makeSession(quizType: String, start: Date, end: Date) -> TrainingSession {
        let session = TrainingSession(kind: TrainingSessionKind.cognitive)
        session.date = start
        session.note = AngleQuizType(rawValue: quizType).displayNameZh
        session.totalDurationMinutes = durationMinutes(from: start, to: end)
        return session
    }

    /// 首题到末题的分钟数，下限 1（一次只答一题也算 1 分钟）。
    static func durationMinutes(from start: Date, to end: Date) -> Int {
        max(1, Int((end.timeIntervalSince(start) / 60).rounded()))
    }

    // MARK: - Private

    /// 同 quizType 最近一条已归属会话的题目，若与 `date` 间隔在窗口内则复用其会话。
    private func activeSession(quizType: String, at date: Date) throws -> TrainingSession? {
        var descriptor = FetchDescriptor<AngleTestResult>(
            predicate: #Predicate { $0.quizType == quizType && $0.date <= date },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = Self.lookbackLimit

        let recent = try context.fetch(descriptor)
        guard let anchor = recent.first(where: { $0.sessionId != nil }),
              let sessionId = anchor.sessionId,
              date.timeIntervalSince(anchor.date) <= Self.gap else { return nil }

        var sessionDescriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.id == sessionId }
        )
        sessionDescriptor.fetchLimit = 1
        guard let session = try context.fetch(sessionDescriptor).first,
              session.kind == TrainingSessionKind.cognitive else { return nil }
        return session
    }
}
