import Foundation
import UserNotifications
import Combine

/// Retained for cold-launch notification responses as well as an already running app.
final class TrainingReminderNavigation: NSObject, UNUserNotificationCenterDelegate, ObservableObject, @unchecked Sendable {
    static let shared = TrainingReminderNavigation()
    @Published private(set) var pending = false

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        guard response.notification.request.identifier.hasPrefix("qiuji.training.daily-reminder") else {
            completionHandler(); return
        }
        DispatchQueue.main.async {
            self.pending = true
            completionHandler()
        }
    }

    @MainActor func consume(router: AppRouter) {
        guard pending else { return }
        router.selectedTab = .training
        // Keep the current training VM and minimized session intact.
        router.trainingPath = .init()
        pending = false
    }
}
