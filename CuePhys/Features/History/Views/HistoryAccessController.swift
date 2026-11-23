import Foundation

struct HistoryAccessController {
    static let freeDaysLimit = 60

    static func isAccessible(_ session: TrainingSession, isPremium: Bool) -> Bool {
        isAccessible(date: session.reportingDate, isPremium: isPremium)
    }

    static func isAccessible(date: Date, isPremium: Bool, now: Date = Date(),
                             calendar: Calendar = .current) -> Bool {
        isPremium || date >= cutoffDate(now: now, calendar: calendar)
    }

    /// Includes today and the preceding 59 local calendar days, including DST transitions.
    static func cutoffDate(now: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -(freeDaysLimit - 1),
                      to: calendar.startOfDay(for: now)) ?? calendar.startOfDay(for: now)
    }
}
