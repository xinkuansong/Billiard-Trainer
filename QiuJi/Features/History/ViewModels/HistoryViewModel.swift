import Foundation
import SwiftData

@MainActor
final class HistoryViewModel: ObservableObject {

    // MARK: - Published State

    @Published var sessions: [TrainingSession] = []
    @Published var selectedDate: Date = Date()
    @Published var currentMonth: Date = Date()
    @Published var isLoading = false
    @Published var errorMessage: String?

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

    var currentMonthSessions: [TrainingSession] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: currentMonth),
              let start = cal.date(from: cal.dateComponents([.year, .month], from: currentMonth)),
              let end = cal.date(byAdding: .day, value: range.count, to: start) else { return [] }
        return sessions.filter { $0.date >= start && $0.date < end }
    }

    // MARK: - Calendar Helpers

    var monthTitle: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy年M月"
        return fmt.string(from: currentMonth)
    }

    var weeksInMonth: [[Date?]] {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: currentMonth)
        guard let firstOfMonth = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: firstOfMonth) else { return [] }

        let firstWeekday = (cal.component(.weekday, from: firstOfMonth) + 5) % 7 // Mon = 0

        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in range {
            if let date = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        while days.count % 7 != 0 { days.append(nil) }

        return stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
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

        let repo = LocalTrainingSessionRepository(context: context)
        do {
            sessions = try await repo.fetchAll()
        } catch {
            errorMessage = "加载训练记录失败"
        }
    }
}
