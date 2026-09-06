import ActivityKit
import AVFoundation
import Foundation

@MainActor
protocol RestTimerLiveActivityManaging: AnyObject {
    func startActivity(drillName: String, state: RestTimerAttributes.ContentState)
    func updateActivity(state: RestTimerAttributes.ContentState)
    func endActivity()
    func activateBackgroundAudio()
    func deactivateBackgroundAudio()
}

@MainActor
final class RestTimerLiveActivityManager: RestTimerLiveActivityManaging {
    static let shared = RestTimerLiveActivityManager()
    private var currentActivity: Activity<RestTimerAttributes>?
    private var silentPlayer: AVAudioPlayer?

    private init() {}

    // MARK: - Live Activity

    func startActivity(drillName: String, state: RestTimerAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        endAllStaleActivities()

        let attributes = RestTimerAttributes(drillName: drillName)

        do {
            let activity = try Activity<RestTimerAttributes>.request(
                attributes: attributes,
                content: .init(state: state, staleDate: state.endDate.addingTimeInterval(5)),
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
            await activity.update(.init(state: state, staleDate: state.endDate.addingTimeInterval(5)))
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

    // MARK: - Background Audio Keep-Alive

    func activateBackgroundAudio() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: .mixWithOthers)
            try session.setActive(true)
        } catch {
            print("[BackgroundAudio] Session error: \(error.localizedDescription)")
        }

        guard silentPlayer == nil else { return }
        let url = silentAudioURL()
        do {
            silentPlayer = try AVAudioPlayer(contentsOf: url)
            silentPlayer?.numberOfLoops = -1
            silentPlayer?.volume = 0.01
            silentPlayer?.play()
        } catch {
            print("[BackgroundAudio] Player error: \(error.localizedDescription)")
        }
    }

    func deactivateBackgroundAudio() {
        silentPlayer?.stop()
        silentPlayer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Private

    private func silentAudioURL() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rest_silence.caf")
        guard !FileManager.default.fileExists(atPath: url.path) else { return url }

        let sampleRate: Double = 44100
        let frameCount = AVAudioFrameCount(sampleRate) // 1 second
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return url }
        buffer.frameLength = frameCount

        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
        } catch {
            print("[BackgroundAudio] Failed to create silence: \(error.localizedDescription)")
        }
        return url
    }

    private func endAllStaleActivities() {
        for activity in Activity<RestTimerAttributes>.activities {
            Task {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }
}
