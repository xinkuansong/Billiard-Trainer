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
/// This is an in-memory projection; no new SwiftData schema is introduced so
/// existing data remains untouched and no migration is required.
struct AngleTrainingSession: Identifiable, Hashable {
    let id: String              // stable: "<quizType>_<firstResultId>"
    let quizType: String        // "geometric" | "scene2D" | "scene3D" | "table2D"
    let startDate: Date
    let endDate: Date
    let results: [AngleTestResult]

    var questionCount: Int { results.count }

    var durationMinutes: Int {
        max(1, Int(endDate.timeIntervalSince(startDate).rounded() / 60))
    }

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

    var quizTypeNameZh: String {
        AngleQuizType(rawValue: quizType).displayNameZh
    }

    static func == (lhs: AngleTrainingSession, rhs: AngleTrainingSession) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Stable mapping between the persisted `quizType` string and a human
/// display name. Kept in one place so renames stay consistent across views.
enum AngleQuizType {
    case geometric, scene2D, scene3D, table2D, unknown

    init(rawValue: String) {
        switch rawValue {
        case "geometric": self = .geometric
        case "scene2D":   self = .scene2D
        case "scene3D":   self = .scene3D
        case "table2D":   self = .table2D
        default:          self = .unknown
        }
    }

    var displayNameZh: String {
        switch self {
        case .geometric: return "几何角度训练"
        case .scene2D:   return "2D 瞄准训练"
        case .scene3D:   return "3D 瞄准训练"
        case .table2D:   return "球台角度练习"
        case .unknown:   return "角度训练"
        }
    }

    var iconSystemName: String {
        switch self {
        case .geometric: return "ruler.fill"
        case .scene2D:   return "square.grid.2x2.fill"
        case .scene3D:   return "rotate.3d.fill"
        case .table2D:   return "scope"
        case .unknown:   return "scope"
        }
    }
}

enum AngleSessionInference {
    /// Consecutive answers closer than this window are merged into one
    /// training session. Chosen to tolerate short pauses (reading the result,
    /// tapping "next") while still splitting genuinely separate sittings.
    static let gap: TimeInterval = 30 * 60
}

/// Unified row item that can represent either a drill-based `TrainingSession`
/// or an inferred `AngleTrainingSession` in the daily history list.
enum HistoryDayItem: Identifiable {
    case session(TrainingSession)
    case angle(AngleTrainingSession)

    var id: String {
        switch self {
        case .session(let s): return "session_\(s.id.uuidString)"
        case .angle(let a):   return "angle_\(a.id)"
        }
    }

    var date: Date {
        switch self {
        case .session(let s): return s.date
        case .angle(let a):   return a.endDate
        }
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

    @Published var sessions: [TrainingSession] = []
    @Published var angleSessions: [AngleTrainingSession] = []
    @Published var selectedDate: Date = Date()
    @Published var currentMonth: Date = Date()
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var categoryMapping: [String: String] = [:]

    // MARK: - Computed

    var datesWithSessions: Set<DateComponents> {
        let cal = Calendar.current
        var comps = Set(sessions.map {
            cal.dateComponents([.year, .month, .day], from: $0.date)
        })
        for s in angleSessions {
            comps.insert(cal.dateComponents([.year, .month, .day], from: s.startDate))
        }
        return comps
    }

    /// Mixed list of training sessions + angle training sessions for the
    /// currently selected date, sorted newest-first. Each angle-training
    /// burst (same quizType, gap < 30min) is one row — exactly the same
    /// granularity as a drill-based `TrainingSession`.
    var selectedDateItems: [HistoryDayItem] {
        let cal = Calendar.current
        var items: [HistoryDayItem] = []
        items.append(contentsOf: sessions
            .filter { cal.isDate($0.date, inSameDayAs: selectedDate) }
            .map(HistoryDayItem.session))
        items.append(contentsOf: angleSessions
            .filter { cal.isDate($0.startDate, inSameDayAs: selectedDate) }
            .map(HistoryDayItem.angle))
        return items.sorted { $0.date > $1.date }
    }

    /// Kept for backwards source compatibility (tests/previews); mirrors the
    /// training-session subset of `selectedDateItems`.
    var selectedDateSessions: [TrainingSession] {
        sessions.filter {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
        }.sorted { $0.date > $1.date }
    }

    var hasAnySessions: Bool {
        !sessions.isEmpty || !angleSessions.isEmpty
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

    func displayName(for session: TrainingSession) -> String {
        primaryCategory(for: session).trainingNameZh
    }

    func categoryForDate(_ date: Date) -> DrillCategory? {
        let daySessions = sessions.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
        guard let first = daySessions.first else { return nil }
        return primaryCategory(for: first)
    }

    /// Short label shown on the calendar grid for the given day. Falls back
    /// to the angle-training indicator (`"角度"`) when the day only contains
    /// angle sessions with no drill-based training session.
    func markerLabel(for date: Date) -> String? {
        if let category = categoryForDate(date) {
            return category.shortNameZh
        }
        let cal = Calendar.current
        let hasAngle = angleSessions.contains { cal.isDate($0.startDate, inSameDayAs: date) }
        return hasAngle ? "角度" : nil
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
        do {
            sessions = try await repo.fetchAll()
        } catch {
            errorMessage = "加载训练记录失败"
        }

        let angleRepo = LocalAngleTestRepository(context: context)
        do {
            let results = try await angleRepo.fetchAll()
            angleSessions = Self.inferAngleSessions(results)
        } catch {
            // Silently degrade: angle session inference failure shouldn't
            // block the main training-session history from rendering.
            angleSessions = []
        }
    }

    /// Split a flat list of `AngleTestResult`s into one `AngleTrainingSession`
    /// per continuous training burst. Two answers belong to the same session
    /// when they share a `quizType` AND the gap between them is below
    /// `AngleSessionInference.gap` (default 30 min).
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
