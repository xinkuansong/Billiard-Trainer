import Foundation
import Combine

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

    @Published private var storedCount: Int
    private var storedDay: String
    var questionsUsedToday: Int { storedDay == dayKey() ? storedCount : 0 }
    @Published var isPremium: Bool = false

    var remainingToday: Int { max(0, Self.dailyLimit - questionsUsedToday) }
    var isLimitReached: Bool { !isPremium && questionsUsedToday >= Self.dailyLimit }

    private let defaults: UserDefaults
    private let now: () -> Date
    private let calendar: () -> Calendar
    private var dayObservation: AnyCancellable?

    // MARK: - Init

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init,
         calendar: @escaping () -> Calendar = { .autoupdatingCurrent }) {
        self.defaults = defaults
        self.now = now
        self.calendar = calendar
        let saved = defaults.string(forKey: PracticeStorageKey.angleUsageDate) ?? ""
        let today = Self.todayString(now: now(), calendar: calendar())
        storedDay = today
        if saved == today {
            storedCount = max(0, defaults.integer(forKey: PracticeStorageKey.angleUsageCount))
        } else {
            storedCount = 0
            defaults.set(today, forKey: PracticeStorageKey.angleUsageDate)
            defaults.set(0, forKey: PracticeStorageKey.angleUsageCount)
        }
        dayObservation = NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .merge(with: NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshDay() }
    }

    /// Explicit lifecycle mutation; computed reads never publish during SwiftUI rendering.
    func refreshDay() {
        let today = dayKey()
        guard storedDay != today else { return }
        storedDay = today
        storedCount = 0
        defaults.set(today, forKey: PracticeStorageKey.angleUsageDate)
        defaults.set(0, forKey: PracticeStorageKey.angleUsageCount)
    }

    func recordQuestion() {
        refreshDay()
        storedCount += 1
        defaults.set(storedCount, forKey: PracticeStorageKey.angleUsageCount)
        defaults.set(storedDay, forKey: PracticeStorageKey.angleUsageDate)
    }

    /// Restoring or receiving a repeated result callback must not consume twice.
    /// Old-day attempts never consume today's allowance.
    func recordQuestion(attemptID: UUID, submittedAt: Date) {
        refreshDay()
        guard Self.todayString(now: submittedAt, calendar: calendar()) == storedDay else { return }
        let key = "accuracyPractice.usageLedger.v1"
        let saved = defaults.dictionary(forKey: key)
        var ids = (saved?["day"] as? String) == storedDay ? (saved?["ids"] as? [String] ?? []) : []
        guard !ids.contains(attemptID.uuidString) else { return }
        ids.append(attemptID.uuidString)
        defaults.set(["day": storedDay, "ids": ids], forKey: key)
        recordQuestion()
    }

    private func dayKey() -> String { Self.todayString(now: now(), calendar: calendar()) }

    private static func todayString(now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: now)
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
