import Foundation

struct HistoryAccessController {
    static let freeDaysLimit = 60

    static func isAccessible(_ session: TrainingSession, isPremium: Bool) -> Bool {
        if isPremium { return true }
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -freeDaysLimit, to: Date()) else {
            return true
        }
        return session.date >= cutoff
    }

    static func cutoffDate() -> Date {
        Calendar.current.date(byAdding: .day, value: -freeDaysLimit, to: Date()) ?? Date.distantPast
    }
}
