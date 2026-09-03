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
    func cancel()
}

@MainActor
final class SystemTrainingReminderCenter: TrainingReminderCenter {
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
        center.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
        let content = UNMutableNotificationContent()
        content.title = "今天练一会儿球吧"
        content.body = "打开球迹，继续完成你的每周训练目标。"
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: hour, minute: minute),
            repeats: true
        )
        try await center.add(UNNotificationRequest(
            identifier: Self.requestIdentifier,
            content: content,
            trigger: trigger
        ))
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
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

    init(center: (any TrainingReminderCenter)? = nil) {
        self.center = center ?? SystemTrainingReminderCenter()
    }

    func authorization() async -> TrainingReminderAuthorization {
        await center.authorization()
    }

    func enable(at date: Date, calendar: Calendar = .current) async -> EnableResult {
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
            try await center.schedule(hour: components.hour ?? 19, minute: components.minute ?? 0)
            return .scheduled
        } catch {
            return .failed("提醒设置失败，请稍后重试")
        }
    }

    func disable() {
        center.cancel()
    }
}
