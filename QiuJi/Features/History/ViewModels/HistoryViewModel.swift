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
    @Published var selectedDate: Date = Date()
    @Published var currentMonth: Date = Date()
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var categoryMapping: [String: String] = [:]

    // MARK: - Computed

    var datesWithSessions: Set<DateComponents> {
        Set(sessions.map {
            Calendar.current.dateComponents([.year, .month, .day], from: $0.date)
        })
    }

    var selectedDateSessions: [TrainingSession] {
        sessions.filter {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
        }.sorted { $0.date > $1.date }
    }

    var hasAnySessions: Bool {
        !sessions.isEmpty
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
    }
}
