import Foundation
import UserNotifications

enum TrainingReminderAuthorization: Equatable {
    case notDetermined
    case allowed
    case denied
}

@MainActor
protocol TrainingReminderCenter: AnyObject {
    func authorization() async -> TrainingReminderAuthorization
    func requestAuthorization() async throws -> Bool
    func schedule(hour: Int, minute: Int) async throws
    func schedule(hour: Int, minute: Int, weekdays: Set<Int>) async throws
    func cancel()
}

extension TrainingReminderCenter {
    func schedule(hour: Int, minute: Int, weekdays: Set<Int>) async throws {
        try await schedule(hour: hour, minute: minute)
    }
}

@MainActor
final class SystemTrainingReminderCenter: TrainingReminderCenter {
    enum Failure: Error { case restorationFailed }
    static let requestIdentifier = "qiuji.training.daily-reminder"
    private let center = UNUserNotificationCenter.current()

    func authorization() async -> TrainingReminderAuthorization {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .allowed
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        @unknown default: return .denied
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func schedule(hour: Int, minute: Int) async throws {
        try await schedule(hour: hour, minute: minute, weekdays: Set(1...7))
    }

    func schedule(hour: Int, minute: Int, weekdays: Set<Int>) async throws {
        let previous = await center.pendingNotificationRequests().filter { Self.identifiers.contains($0.identifier) }
        let content = UNMutableNotificationContent()
        content.title = "今天练一会儿球吧"
        content.body = "打开球迹，继续完成你的每周训练目标。"
        content.sound = .default
        do {
            for weekday in weekdays.sorted() {
                let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: minute, weekday: weekday), repeats: true)
                try await center.add(UNNotificationRequest(identifier: "\(Self.requestIdentifier).\(weekday)", content: content, trigger: trigger))
            }
            let retained = Set(weekdays.map { "\(Self.requestIdentifier).\($0)" })
            center.removePendingNotificationRequests(withIdentifiers: Self.identifiers.filter { !retained.contains($0) })
        } catch {
            center.removePendingNotificationRequests(withIdentifiers: Self.identifiers)
            do { for request in previous { try await center.add(request) } }
            catch {
                center.removePendingNotificationRequests(withIdentifiers: Self.identifiers)
                throw Failure.restorationFailed
            }
            throw error
        }
    }

    static var identifiers: [String] { [requestIdentifier] + (1...7).map { "\(requestIdentifier).\($0)" } }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: Self.identifiers)
    }
}

@MainActor
final class TrainingReminderScheduler {
    enum EnableResult: Equatable {
        case scheduled
        case permissionDenied
        case failed(String)
    }

    static let shared = TrainingReminderScheduler()
    private let center: any TrainingReminderCenter
    private var updating = false

    init(center: (any TrainingReminderCenter)? = nil) {
        self.center = center ?? SystemTrainingReminderCenter()
    }

    func authorization() async -> TrainingReminderAuthorization {
        await center.authorization()
    }

    func enable(at date: Date, calendar: Calendar = .current, weekdays: Set<Int> = Set(1...7)) async -> EnableResult {
        guard !updating else { return .failed("提醒正在更新，请稍后重试") }
        updating = true
        defer { updating = false }
        guard !weekdays.isEmpty, weekdays.isSubset(of: Set(1...7)) else { return .failed("请至少选择一天") }
        do {
            let status = await center.authorization()
            let allowed: Bool
            switch status {
            case .allowed:
                allowed = true
            case .notDetermined:
                allowed = try await center.requestAuthorization()
            case .denied:
                allowed = false
            }
            guard allowed else { return .permissionDenied }
            let components = calendar.dateComponents([.hour, .minute], from: date)
            try await center.schedule(hour: components.hour ?? 19, minute: components.minute ?? 0, weekdays: weekdays)
            return .scheduled
        } catch SystemTrainingReminderCenter.Failure.restorationFailed {
            UserPreferences.shared.persistReminder(enabled: false)
            return .failed("提醒未生效，请重新保存提醒设置。")
        } catch {
            return .failed("提醒设置失败，请稍后重试")
        }
    }

    /// No permission prompt during lifecycle reconciliation.
    func reconcile() async {
        let prefs = UserPreferences.shared
        guard prefs.reminderEnabled, !updating else { return }
        guard await center.authorization() == .allowed else {
            center.cancel()
            prefs.persistReminder(enabled: false)
            return
        }
        if case .failed = await enable(at: prefs.localReminderTime, weekdays: prefs.reminderWeekdays) {
            center.cancel()
            prefs.persistReminder(enabled: false)
        }
    }

    func disable() {
        center.cancel()
    }
}
