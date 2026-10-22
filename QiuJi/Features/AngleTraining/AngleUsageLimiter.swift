import Foundation
import Combine

/// Tracks daily free-tier question count. Premium users bypass the limit.
/// Prediction pages share `shared`; the three 2D scene trainings each own an allowance.
/// Tests may construct isolated instances
/// (optionally with a custom `UserDefaults` suite).
final class AngleUsageLimiter: ObservableObject {

    static let dailyLimit = 20

    /// Process-wide limiter so all quiz pages observe the same in-memory count (C23).
    static let shared: AngleUsageLimiter = {
        applyUITestLaunchHooksIfNeeded()
        return AngleUsageLimiter()
    }()

    // Scene training has independent daily allowances; prediction tools retain shared.
    static let angleTraining = AngleUsageLimiter(namespace: "scene2D")
    static let aimPointTraining = AngleUsageLimiter(namespace: "aimPoint2D")
    static let accuracyTraining = AngleUsageLimiter(namespace: "accuracy2D")
    static let separationTraining = AngleUsageLimiter(namespace: "separationPractice2D")
    static func training(route: String) -> AngleUsageLimiter {
        if route.hasPrefix("separationPractice") { return separationTraining }
        if route.hasPrefix("accuracy") { return accuracyTraining }
        if route.hasPrefix("aimPoint") { return aimPointTraining }
        return angleTraining
    }
    private let countKey: String
    private let dateKey: String
    private let ledgerKey: String

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
         calendar: @escaping () -> Calendar = { .autoupdatingCurrent }, namespace: String? = nil) {
        countKey = namespace.map { "sceneTraining.usage.\($0).count" } ?? PracticeStorageKey.angleUsageCount
        dateKey = namespace.map { "sceneTraining.usage.\($0).day" } ?? PracticeStorageKey.angleUsageDate
        ledgerKey = namespace.map { "sceneTraining.usage.\($0).ledger" } ?? "accuracyPractice.usageLedger.v1"
        #if DEBUG
        if namespace != nil {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-w7.forceDailyLimit") || args.contains("-w7.forceDailyLimitNear") {
                defaults.set(Self.todayString(now: now(), calendar: calendar()), forKey: dateKey)
                defaults.set(args.contains("-w7.forceDailyLimit") ? Self.dailyLimit : Self.dailyLimit - 1, forKey: countKey)
            }
        }
        #endif
        self.defaults = defaults
        self.now = now
        self.calendar = calendar
        let saved = defaults.string(forKey: dateKey) ?? ""
        let today = Self.todayString(now: now(), calendar: calendar())
        storedDay = today
        if saved == today {
            storedCount = max(0, defaults.integer(forKey: countKey))
        } else {
            storedCount = 0
            defaults.set(today, forKey: dateKey)
            defaults.set(0, forKey: countKey)
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
        defaults.set(today, forKey: dateKey)
        defaults.set(0, forKey: countKey)
    }

    func recordQuestion() {
        refreshDay()
        storedCount += 1
        defaults.set(storedCount, forKey: countKey)
        defaults.set(storedDay, forKey: dateKey)
    }

    /// Restoring or receiving a repeated result callback must not consume twice.
    /// Old-day attempts never consume today's allowance.
    func recordQuestion(attemptID: UUID, submittedAt: Date) {
        refreshDay()
        guard Self.todayString(now: submittedAt, calendar: calendar()) == storedDay else { return }
        let key = ledgerKey
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
