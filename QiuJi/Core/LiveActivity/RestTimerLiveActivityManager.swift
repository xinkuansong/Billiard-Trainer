import ActivityKit
import UserNotifications
import Foundation

@MainActor
protocol RestTimerLiveActivityManaging: AnyObject {
    func startActivity(drillName: String, state: RestTimerAttributes.ContentState)
    func updateActivity(state: RestTimerAttributes.ContentState)
    func endActivity()
    func setMusicResting(_ resting: Bool)
    func scheduleReminder(at end: Date, requestPermission: Bool)
    func cancelReminder()
}

@MainActor
final class RestTimerLiveActivityManager: RestTimerLiveActivityManaging {
    static let shared = RestTimerLiveActivityManager()
    private var currentActivity: Activity<RestTimerAttributes>?
    private let reminder = RestCompletionReminder()

    private init() {}

    // MARK: - Live Activity

    func startActivity(drillName: String, state: RestTimerAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        endAllStaleActivities()

        let attributes = RestTimerAttributes(drillName: drillName)

        do {
            let activity = try Activity<RestTimerAttributes>.request(
                attributes: attributes,
                content: .init(state: state, staleDate: state.endDate),
                pushType: nil
            )
            currentActivity = activity
            #if DEBUG
            print("[RestTrace] event=start id=\(activity.id) now=\(Date().timeIntervalSince1970) end=\(state.endDate.timeIntervalSince1970) total=\(state.totalSeconds)")
            #endif
        } catch {
            print("[LiveActivity] Failed to start: \(error.localizedDescription)")
        }
    }

    func updateActivity(state: RestTimerAttributes.ContentState) {
        guard let activity = currentActivity else { return }
        Task {
            await activity.update(.init(state: state, staleDate: state.endDate))
            #if DEBUG
            print("[RestTrace] event=update-completed id=\(activity.id) now=\(Date().timeIntervalSince1970) end=\(state.endDate.timeIntervalSince1970) total=\(state.totalSeconds)")
            #endif
        }
    }

    func endActivity() {
        guard let activity = currentActivity else { return }
        let finalState = RestTimerAttributes.ContentState(
            endDate: Date(),
            totalSeconds: activity.content.state.totalSeconds
        )
        Task {
            await activity.end(
                .init(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
            #if DEBUG
            print("[RestTrace] event=end-completed id=\(activity.id) now=\(Date().timeIntervalSince1970)")
            #endif
        }
        currentActivity = nil
    }

    func setMusicResting(_ resting: Bool) {
        TrainingMusicPlayer.shared.setResting(resting)
    }

    func scheduleReminder(at end: Date, requestPermission: Bool) {
        reminder.schedule(at: end, requestPermission: requestPermission)
    }

    func cancelReminder() {
        reminder.cancel()
    }

    private func endAllStaleActivities() {
        for activity in Activity<RestTimerAttributes>.activities {
            Task {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }
}
