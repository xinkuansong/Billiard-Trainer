import Foundation
import SwiftData

enum HistoryTab: String, CaseIterable {
    case history = "历史"
    case statistics = "统计"
}

struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date
    let isCurrentMonth: Bool
}

/// A single "angle training session" — a contiguous burst of
/// `AngleTestResult` entries of the same `quizType`. Sessions are split when
/// the gap between consecutive answers exceeds `AngleSessionInference.gap`.
///
/// ⚠️ v29 W6 起这**不再是历史页的数据源**：历史页只读 `kind="cognitive"` 的真会话
/// （见 `CognitiveSessionItem`）。本投影只剩一个消费者——W5 的
/// `CognitiveSessionBackfill`，它用同一口径给无归属的历史成绩补建会话。
/// 因此这里是「回填分组口径」的真源，不可删。
struct AngleTrainingSession: Identifiable, Hashable {
    let id: String              // stable: "<quizType>_<firstResultId>"
    let quizType: String        // "geometric" | "scene2D" | "scene3D" | "table2D"
    let startDate: Date
    let endDate: Date
    let results: [AngleTestResult]

    var questionCount: Int { results.count }

    static func == (lhs: AngleTrainingSession, rhs: AngleTrainingSession) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// 历史页里的一条**认知练习记录** = 一条 `kind="cognitive"` 的真 `TrainingSession`
/// 加上归属它的 `AngleTestResult`（契约 §4.1 / §5.3）。
///
/// v29 W6：取代 `AngleTrainingSession` 内存投影成为历史页的呈现载体。分组不再由
/// 「同 quizType ≤30 分钟」在展示时推断，而是直接来自 W5 落库的会话归属，
/// 因此展示与落库口径不可能漂移。
///
/// ⛔ 名称取 `TrainingSession.note` 的**快照**（W5 写入即冻结，契约 §6.5），
/// 不用 quizType 回查当前文案表。
struct CognitiveSessionItem: Identifiable, Hashable {
    /// 真会话 id。
    let id: UUID
    /// 会话名快照。
    let displayNameZh: String
    /// 题目自带的测验类型，仅用于图标等表现细节（成绩本体字段，非内容回查）。
    let quizType: String
    let startDate: Date
    let endDate: Date
    /// 会话时长真字段（`TrainingSession.totalDurationMinutes`），不再由首末题推算。
    let durationMinutes: Int
    let results: [AngleTestResult]

    var questionCount: Int { results.count }

    var averageError: Double {
        guard !results.isEmpty else { return 0 }
        return results.map(\.error).reduce(0, +) / Double(results.count)
    }

    var bestError: Double {
        results.map(\.error).min() ?? 0
    }

    /// "Accurate" answers = absolute error ≤ 3°. Matches the rule used in
    /// `AngleHistoryViewModel` for consistent accuracy stats across views.
    var accurateCount: Int {
        results.filter { $0.error <= 3 }.count
    }

    var accurateRate: Double {
        guard !results.isEmpty else { return 0 }
        return Double(accurateCount) / Double(results.count)
    }

    /// 由真会话 + 其归属成绩装配。`results` 会按时间升序归一。
    static func make(session: TrainingSession, results: [AngleTestResult]) -> CognitiveSessionItem {
        let sorted = results.sorted { $0.date < $1.date }
        let quizType = sorted.first?.quizType ?? ""
        // 快照优先；W5 之前不存在 cognitive 会话，故 note 为空只可能是异常数据，
        // 此时退回题目自带的 quizType 文案（仍不回查内容库）。
        let name = session.note.isEmpty
            ? AngleQuizType(rawValue: quizType).displayNameZh
            : session.note
        return CognitiveSessionItem(
            id: session.id,
            displayNameZh: name,
            quizType: quizType,
            startDate: session.date,
            endDate: sorted.last?.date ?? session.date,
            durationMinutes: session.totalDurationMinutes,
            results: sorted
        )
    }

    static func == (lhs: CognitiveSessionItem, rhs: CognitiveSessionItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// 历史页里的一条**工具使用记录** = 一条 `kind="tool"` 的真 `TrainingSession`。
///
/// ⛔ 契约 §5.3：只有日期与时长，没有任何成败字段，不进任何准确率聚合、不计周目标。
struct ToolSessionItem: Identifiable, Hashable {
    let id: UUID
    /// 工具名快照（W5 存入 `TrainingSession.note`）。
    let displayNameZh: String
    let date: Date
    let durationMinutes: Int

    static func make(session: TrainingSession) -> ToolSessionItem {
        ToolSessionItem(
            id: session.id,
            displayNameZh: session.note.isEmpty ? "工具使用" : session.note,
            date: session.date,
            durationMinutes: session.totalDurationMinutes
        )
    }
}

/// Stable mapping between the persisted `quizType` string and a human
/// display name. Kept in one place so renames stay consistent across views.
enum AngleQuizType {
    case geometric, scene2D, scene3D, table2D
    case aimPoint, aimPoint2D, aimPoint3D
    case unknown

    init(rawValue: String) {
        switch rawValue {
        case "geometric":  self = .geometric
        case "scene2D":    self = .scene2D
        case "scene3D":    self = .scene3D
        case "table2D":    self = .table2D
        case "aimPoint":   self = .aimPoint
        case "aimPoint2D": self = .aimPoint2D
        case "aimPoint3D": self = .aimPoint3D
        default:           self = .unknown
        }
    }

    var displayNameZh: String {
        switch self {
        // T-P18-50 页名=卡名：卡与页统一为「角度预测」。
        case .geometric:  return "角度预测"
        case .scene2D:    return "2D 角度训练"
        case .scene3D:    return "3D 角度训练"
        case .table2D:    return "球台角度练习"
        case .aimPoint:   return "瞄准点训练"
        case .aimPoint2D: return "2D 瞄准点训练"
        case .aimPoint3D: return "3D 瞄准点训练"
        case .unknown:    return "角度训练"
        }
    }

    /// 误差是否以毫米计（瞄准点训练家族），否则以角度计。
    var usesMMError: Bool {
        switch self {
        case .aimPoint, .aimPoint2D, .aimPoint3D: return true
        default: return false
        }
    }

    var iconSystemName: String {
        switch self {
        case .geometric:  return "ruler.fill"
        case .scene2D:    return "square.grid.2x2.fill"
        case .scene3D:    return "rotate.3d.fill"
        case .table2D:    return "scope"
        case .aimPoint:   return "smallcircle.filled.circle"
        case .aimPoint2D: return "dot.scope"
        case .aimPoint3D: return "dot.scope"
        case .unknown:    return "scope"
        }
    }
}

enum AngleSessionInference {
    /// Consecutive answers closer than this window are merged into one
    /// training session. Chosen to tolerate short pauses (reading the result,
    /// tapping "next") while still splitting genuinely separate sittings.
    static let gap: TimeInterval = 30 * 60
}

/// 日列表的统一行载体，三种 `kind` 各一路（契约 §5.3）。
enum HistoryDayItem: Identifiable {
    /// `kind="drill"` 的真实球台训练。
    case session(TrainingSession)
    /// `kind="cognitive"` 的屏内认知练习。
    case cognitive(CognitiveSessionItem)
    /// `kind="tool"` 的工具使用活跃度，⛔ 无成绩。
    case tool(ToolSessionItem)

    var id: String {
        switch self {
        case .session(let s):   return "session_\(s.id.uuidString)"
        case .cognitive(let c): return "cognitive_\(c.id.uuidString)"
        case .tool(let t):      return "tool_\(t.id.uuidString)"
        }
    }

    var date: Date {
        switch self {
        case .session(let s):   return s.date
        case .cognitive(let c): return c.endDate
        case .tool(let t):      return t.date
        }
    }
}

/// 日历格上的标记。`tool` 与训练分开，前者只表示「这天用过工具」。
enum HistoryDayMarker: Equatable {
    /// 训练标记（drill 分类简称，或认知练习）。
    case training(String)
    /// 工具活跃标记：淡色，⛔ 不代表训练量、不代表成绩。
    case toolActivity(String)

    var label: String {
        switch self {
        case .training(let l), .toolActivity(let l): return l
        }
    }

    var isToolActivity: Bool {
        if case .toolActivity = self { return true }
        return false
    }
}

extension DrillCategory {
    var shortNameZh: String {
        switch self {
        case .fundamentals: return "基础"
        case .accuracy:     return "准度"
        case .cueAction:    return "杆法"
        case .separation:   return "分离"
        case .positioning:  return "走位"
        case .forceControl: return "控力"
        case .specialShots: return "特殊"
        case .combined:     return "综合"
        }
    }

    var trainingNameZh: String {
        switch self {
        case .fundamentals: return "基础功训练"
        case .accuracy:     return "准度练习"
        case .cueAction:    return "杆法专项训练"
        case .separation:   return "分离角训练"
        case .positioning:  return "走位训练"
        case .forceControl: return "控力训练"
        case .specialShots: return "特殊球路训练"
        case .combined:     return "综合训练"
        }
    }
}

@MainActor
final class HistoryViewModel: ObservableObject {

    // MARK: - Published State

    /// 全部会话（三种 kind 混在一起，按 `date` 倒序）。按 kind 分流见下面三个计算属性。
    @Published var sessions: [TrainingSession] = []
    /// `kind="cognitive"` 的真会话（含其归属成绩），v29 W6 起取代内存投影。
    @Published var cognitiveSessions: [CognitiveSessionItem] = []
    /// `kind="tool"` 的真会话，只有日期与时长。
    @Published var toolSessions: [ToolSessionItem] = []
    @Published var selectedDate: Date = Date()
    @Published var currentMonth: Date = Date()
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// 诊断用：仍无 `sessionId` 归属的历史成绩条数。正常应为 0（W5 的
    /// `CognitiveSessionBackfill` 在 App 启动时幂等回填）。>0 说明回填还没跑成功，
    /// 这些成绩暂时不会出现在历史页——留计数而不静默，便于排查。
    @Published var unassignedCognitiveResultCount = 0

    private var categoryMapping: [String: String] = [:]

    // MARK: - Kind 分流（契约 §5.3）

    /// 真实球台训练。历史页的「训练记录」行与日历分类标记只认这一类。
    var drillSessions: [TrainingSession] {
        sessions.filter { $0.kind == TrainingSessionKind.drill }
    }

    // MARK: - Computed

    var datesWithSessions: Set<DateComponents> {
        let cal = Calendar.current
        var comps = Set(drillSessions.map {
            cal.dateComponents([.year, .month, .day], from: $0.date)
        })
        for s in cognitiveSessions {
            comps.insert(cal.dateComponents([.year, .month, .day], from: s.startDate))
        }
        for t in toolSessions {
            comps.insert(cal.dateComponents([.year, .month, .day], from: t.date))
        }
        return comps
    }

    /// 所选日期的记录行，新的在前。三种 kind 各自成行：一条 drill 训练、
    /// 一条认知练习会话、一条工具使用，粒度一致。
    var selectedDateItems: [HistoryDayItem] {
        let cal = Calendar.current
        var items: [HistoryDayItem] = []
        items.append(contentsOf: drillSessions
            .filter { cal.isDate($0.date, inSameDayAs: selectedDate) }
            .map(HistoryDayItem.session))
        items.append(contentsOf: cognitiveSessions
            .filter { cal.isDate($0.startDate, inSameDayAs: selectedDate) }
            .map(HistoryDayItem.cognitive))
        items.append(contentsOf: toolSessions
            .filter { cal.isDate($0.date, inSameDayAs: selectedDate) }
            .map(HistoryDayItem.tool))
        return items.sorted { $0.date > $1.date }
    }

    /// Kept for backwards source compatibility (tests/previews); mirrors the
    /// drill-session subset of `selectedDateItems`.
    var selectedDateSessions: [TrainingSession] {
        drillSessions.filter {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
        }.sorted { $0.date > $1.date }
    }

    var hasAnySessions: Bool {
        !drillSessions.isEmpty || !cognitiveSessions.isEmpty || !toolSessions.isEmpty
    }

    // MARK: - Category Helpers

    func categoryForDrill(_ drillId: String) -> String {
        categoryMapping[drillId] ?? "combined"
    }

    func primaryCategory(for session: TrainingSession) -> DrillCategory {
        var counts: [String: Int] = [:]
        for entry in session.drillEntries {
            let cat = categoryForDrill(entry.drillId)
            counts[cat, default: 0] += 1
        }
        let topCat = counts.max(by: { $0.value < $1.value })?.key ?? "combined"
        return DrillCategory(rawValue: topCat) ?? .combined
    }

    /// 历史行标题。⛔ 契约 §6.5：一律取 `DrillEntry.drillNameZh` **快照**，
    /// 不用 `drillId` 回查当前内容——drill 改名或下架后历史记录仍按当年名字显示。
    /// （v29 W6 前这里返回的是 `primaryCategory(...).trainingNameZh`，即由 `drillId`
    /// 回查内容表得到的分类名，属活引用，与该裁定冲突。）
    func displayName(for session: TrainingSession) -> String {
        let names = session.drillEntries
            .sorted { $0.orderIndex < $1.orderIndex }
            .map(\.drillNameZh)
            .filter { !$0.isEmpty }
        guard let first = names.first else { return "训练记录" }
        return names.count == 1 ? first : "\(first) 等 \(names.count) 项"
    }

    /// 行上的分类副标签。分类是唯一没有快照字段的维度（见
    /// `StatisticsViewModel.categoryForDrill` 注释），内容删除后退化为「综合」，
    /// 但它只是辅助归类，标题与达标线仍走快照。
    func categoryLabel(for session: TrainingSession) -> String? {
        guard !session.drillEntries.isEmpty else { return nil }
        return primaryCategory(for: session).shortNameZh
    }

    /// 当天的 drill 训练主分类。⛔ 只看 `kind="drill"`：cognitive / tool 没有
    /// `DrillEntry`，混进来会被 `primaryCategory` 的兜底算成「综合」。
    func categoryForDate(_ date: Date) -> DrillCategory? {
        let daySessions = drillSessions.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
        guard let first = daySessions.first else { return nil }
        return primaryCategory(for: first)
    }

    /// 日历格标记。优先级：drill 分类 > 认知练习 > 工具活跃（淡色）。
    func marker(for date: Date) -> HistoryDayMarker? {
        if let category = categoryForDate(date) {
            return .training(category.shortNameZh)
        }
        let cal = Calendar.current
        if cognitiveSessions.contains(where: { cal.isDate($0.startDate, inSameDayAs: date) }) {
            return .training("角度")
        }
        if toolSessions.contains(where: { cal.isDate($0.date, inSameDayAs: date) }) {
            return .toolActivity("工具")
        }
        return nil
    }

    // MARK: - Session Helpers

    func totalSets(for session: TrainingSession) -> Int {
        session.drillEntries.reduce(0) { $0 + $1.sets.count }
    }

    func timeRange(for session: TrainingSession) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "HH:mm"
        let start = fmt.string(from: session.date)
        let endDate = Calendar.current.date(
            byAdding: .minute,
            value: session.totalDurationMinutes,
            to: session.date
        ) ?? session.date
        let end = fmt.string(from: endDate)
        return "\(start)-\(end)"
    }

    // MARK: - Calendar Helpers

    var monthTitle: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy年M月"
        return fmt.string(from: currentMonth)
    }

    /// Always returns 6 rows (42 cells) including prev/next month filler dates
    var weeksInMonth: [[CalendarDay]] {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: currentMonth)
        guard let firstOfMonth = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: firstOfMonth) else { return [] }

        let firstWeekday = (cal.component(.weekday, from: firstOfMonth) + 5) % 7 // Mon = 0

        var days: [CalendarDay] = []

        for i in (0..<firstWeekday).reversed() {
            if let d = cal.date(byAdding: .day, value: -(i + 1), to: firstOfMonth) {
                days.append(CalendarDay(date: d, isCurrentMonth: false))
            }
        }

        for day in range {
            if let d = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(CalendarDay(date: d, isCurrentMonth: true))
            }
        }

        while days.count < 42 {
            if let lastDate = days.last?.date,
               let d = cal.date(byAdding: .day, value: 1, to: lastDate) {
                days.append(CalendarDay(date: d, isCurrentMonth: false))
            }
        }

        return stride(from: 0, to: 42, by: 7).map { Array(days[$0..<$0 + 7]) }
    }

    func hasSession(on date: Date) -> Bool {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return datesWithSessions.contains(comps)
    }

    func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    func isSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }

    // MARK: - Month Navigation

    func previousMonth() {
        if let prev = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = prev
        }
    }

    func nextMonth() {
        if let next = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = next
        }
    }

    // MARK: - Data Loading

    func loadSessions(context: ModelContext) async {
        isLoading = true
        defer { isLoading = false }

        let drills = await DrillContentService.shared.loadFallbackDrills()
        var map: [String: String] = [:]
        for drill in drills {
            map[drill.id] = drill.category
        }
        categoryMapping = map

        let repo = LocalTrainingSessionRepository(context: context)
        var allSessions: [TrainingSession] = []
        do {
            allSessions = try await repo.fetchAll()
            sessions = allSessions
            errorMessage = nil
        } catch {
            sessions = []
            errorMessage = "加载训练记录失败"
        }

        toolSessions = allSessions
            .filter { $0.kind == TrainingSessionKind.tool }
            .map(ToolSessionItem.make)

        let angleRepo = LocalAngleTestRepository(context: context)
        do {
            let results = try await angleRepo.fetchAll()
            cognitiveSessions = Self.assembleCognitiveSessions(
                sessions: allSessions, results: results
            )
            unassignedCognitiveResultCount = results.filter { $0.sessionId == nil }.count
        } catch {
            // Silently degrade: 认知成绩读取失败不应连带打掉主训练记录的渲染。
            cognitiveSessions = []
            unassignedCognitiveResultCount = 0
        }
    }

    /// 把 `kind="cognitive"` 的真会话与归属它的成绩装配成展示行，按结束时间倒序。
    ///
    /// ⛔ 不做任何时间间隔推断：归属完全来自 `AngleTestResult.sessionId`（W5 落库 +
    /// 一次性回填）。仍无归属的成绩不在此显示——它们由 `CognitiveSessionBackfill`
    /// 在启动时补建会话，条数记在 `unassignedCognitiveResultCount` 里。
    static func assembleCognitiveSessions(
        sessions: [TrainingSession],
        results: [AngleTestResult]
    ) -> [CognitiveSessionItem] {
        let bySessionId = Dictionary(grouping: results.compactMap { r -> (UUID, AngleTestResult)? in
            guard let sid = r.sessionId else { return nil }
            return (sid, r)
        }, by: { $0.0 }).mapValues { $0.map(\.1) }

        return sessions
            .filter { $0.kind == TrainingSessionKind.cognitive }
            .map { CognitiveSessionItem.make(session: $0, results: bySessionId[$0.id] ?? []) }
            .sorted { $0.endDate > $1.endDate }
    }

    /// Split a flat list of `AngleTestResult`s into one `AngleTrainingSession`
    /// per continuous training burst. Two answers belong to the same session
    /// when they share a `quizType` AND the gap between them is below
    /// `AngleSessionInference.gap` (default 30 min).
    ///
    /// ⚠️ v29 W6：**历史页已不再调用本方法**。唯一消费者是
    /// `CognitiveSessionBackfill`——给 W5 之前的无归属成绩补建会话时需要这套分组口径。
    /// 它同时是 `CognitiveSessionRecorder` 实时口径的同源真源，勿删。
    static func inferAngleSessions(
        _ results: [AngleTestResult],
        gap: TimeInterval = AngleSessionInference.gap
    ) -> [AngleTrainingSession] {
        guard !results.isEmpty else { return [] }

        // Group by quizType first, then split each group on time gaps.
        let byType = Dictionary(grouping: results) { $0.quizType }

        var sessions: [AngleTrainingSession] = []
        for (quizType, items) in byType {
            let sorted = items.sorted { $0.date < $1.date }

            var current: [AngleTestResult] = []
            for r in sorted {
                if let last = current.last,
                   r.date.timeIntervalSince(last.date) > gap {
                    sessions.append(Self.makeSession(quizType: quizType, results: current))
                    current = [r]
                } else {
                    current.append(r)
                }
            }
            if !current.isEmpty {
                sessions.append(Self.makeSession(quizType: quizType, results: current))
            }
        }

        return sessions.sorted { $0.endDate > $1.endDate }
    }

    private static func makeSession(
        quizType: String,
        results: [AngleTestResult]
    ) -> AngleTrainingSession {
        let start = results.first?.date ?? Date()
        let end = results.last?.date ?? start
        let anchorId = results.first.map { $0.id.uuidString } ?? UUID().uuidString
        return AngleTrainingSession(
            id: "\(quizType)_\(anchorId)",
            quizType: quizType,
            startDate: start,
            endDate: end,
            results: results
        )
    }
}
