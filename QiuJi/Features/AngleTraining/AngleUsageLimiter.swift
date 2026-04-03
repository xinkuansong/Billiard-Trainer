import Foundation

/// Tracks daily free-tier question count. Premium users bypass the limit.
final class AngleUsageLimiter: ObservableObject {

    static let dailyLimit = 20

    @Published private(set) var questionsUsedToday: Int
    @Published var isPremium: Bool = false

    var remainingToday: Int { max(0, Self.dailyLimit - questionsUsedToday) }
    var isLimitReached: Bool { !isPremium && questionsUsedToday >= Self.dailyLimit }

    // MARK: - Storage keys

    private static let countKey = "AngleUsage_count"
    private static let dateKey  = "AngleUsage_date"

    // MARK: - Init

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.dateKey) ?? ""
        let today = Self.todayString()
        if saved == today {
            questionsUsedToday = UserDefaults.standard.integer(forKey: Self.countKey)
        } else {
            questionsUsedToday = 0
            UserDefaults.standard.set(today, forKey: Self.dateKey)
            UserDefaults.standard.set(0, forKey: Self.countKey)
        }
    }

    func recordQuestion() {
        questionsUsedToday += 1
        UserDefaults.standard.set(questionsUsedToday, forKey: Self.countKey)
        UserDefaults.standard.set(Self.todayString(), forKey: Self.dateKey)
    }

    private static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
