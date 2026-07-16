import Foundation

/// Tracks daily free-tier question count. Premium users bypass the limit.
/// App pages share `AngleUsageLimiter.shared`; tests may construct isolated instances
/// (optionally with a custom `UserDefaults` suite).
final class AngleUsageLimiter: ObservableObject {

    static let dailyLimit = 20

    /// Process-wide limiter so all quiz pages observe the same in-memory count (C23).
    static let shared: AngleUsageLimiter = {
        applyUITestLaunchHooksIfNeeded()
        return AngleUsageLimiter()
    }()

    @Published private(set) var questionsUsedToday: Int
    @Published var isPremium: Bool = false

    var remainingToday: Int { max(0, Self.dailyLimit - questionsUsedToday) }
    var isLimitReached: Bool { !isPremium && questionsUsedToday >= Self.dailyLimit }

    private let defaults: UserDefaults

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.string(forKey: PracticeStorageKey.angleUsageDate) ?? ""
        let today = Self.todayString()
        if saved == today {
            questionsUsedToday = defaults.integer(forKey: PracticeStorageKey.angleUsageCount)
        } else {
            questionsUsedToday = 0
            defaults.set(today, forKey: PracticeStorageKey.angleUsageDate)
            defaults.set(0, forKey: PracticeStorageKey.angleUsageCount)
        }
    }

    func recordQuestion() {
        questionsUsedToday += 1
        defaults.set(questionsUsedToday, forKey: PracticeStorageKey.angleUsageCount)
        defaults.set(Self.todayString(), forKey: PracticeStorageKey.angleUsageDate)
    }

    private static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    /// UITest launch hooks（生产无对应 arg 时永不触发）：
    /// - `-w7.forceDailyLimit` → 已满额（full 主卡）
    /// - `-w7.forceDailyLimitNear` → 剩 1 次（提交后进结果区 compact）
    private static func applyUITestLaunchHooksIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        let defaults = UserDefaults.standard
        if args.contains("-w7.forceDailyLimit") {
            defaults.set(todayString(), forKey: PracticeStorageKey.angleUsageDate)
            defaults.set(dailyLimit, forKey: PracticeStorageKey.angleUsageCount)
        } else if args.contains("-w7.forceDailyLimitNear") {
            defaults.set(todayString(), forKey: PracticeStorageKey.angleUsageDate)
            defaults.set(dailyLimit - 1, forKey: PracticeStorageKey.angleUsageCount)
        }
    }
}
