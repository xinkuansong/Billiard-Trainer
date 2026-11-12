import Foundation
import UserNotifications

@MainActor
protocol RestNotificationCenter {
    func allowed(requestPermission: Bool) async -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func remove(_ identifier: String)
}

@MainActor
private final class SystemRestNotificationCenter: RestNotificationCenter {
    private let center = UNUserNotificationCenter.current()
    private var prompt: Task<Bool, Never>?

    func allowed(requestPermission: Bool) async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .notDetermined:
            if let prompt { return await prompt.value }
            guard requestPermission, !Task.isCancelled else { return false }
            let request = Task { (try? await center.requestAuthorization(options: [.alert, .sound])) == true }
            prompt = request
            let granted = await request.value
            prompt = nil
            return granted
        default: return false
        }
    }

    func add(_ request: UNNotificationRequest) async throws { try await center.add(request) }
    func remove(_ identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}

/// Each revision owns its notification ID, so a late add cannot overwrite the
/// latest deadline or remove the notification for a newly started rest.
@MainActor
final class RestCompletionReminder {
    private let center: any RestNotificationCenter
    private var identifier: String?
    private var scheduling: Task<Void, Never>?
    private var permissionRequested = false

    init(center: (any RestNotificationCenter)? = nil) {
        self.center = center ?? SystemRestNotificationCenter()
    }

    func schedule(at end: Date, requestPermission: Bool) {
        let mayPrompt = requestPermission || permissionRequested
        cancel()
        permissionRequested = mayPrompt
        let id = "cuephys.rest." + UUID().uuidString
        identifier = id
        scheduling = Task { [center] in
            guard !Task.isCancelled, await center.allowed(requestPermission: mayPrompt), !Task.isCancelled else { return }
            let seconds = end.timeIntervalSinceNow
            guard seconds > 0 else { return }
            let content = UNMutableNotificationContent()
            content.title = "组间休息结束"
            content.body = "可以开始下一组训练了。"
            content.sound = UNNotificationSound(named: .init(rawValue: "complete.wav"))
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
            do {
                try await center.add(.init(identifier: id, content: content, trigger: trigger))
            } catch {
                if !Task.isCancelled { print("[RestTimer] Notification scheduling failed") }
            }
            if Task.isCancelled { center.remove(id) }
        }
    }

    func cancel() {
        scheduling?.cancel()
        scheduling = nil
        permissionRequested = false
        if let identifier { center.remove(identifier) }
        identifier = nil
    }
}
