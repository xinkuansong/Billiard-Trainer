import AVFoundation
import Combine
import UIKit

@MainActor
protocol TrainingMusicPlaying: AnyObject {
    var isPlaying: Bool { get }
    func play() -> Bool
    func pause()
}

extension AVAudioPlayer: TrainingMusicPlaying {}

/// One loop shared by visible exercise pages. The audio session is shared with
/// shot effects and the rest timer, so pausing music never deactivates it.
@MainActor
final class TrainingMusicPlayer {
    static let shared: TrainingMusicPlayer = {
        let service = TrainingMusicPlayer(
            enabled: UserPreferences.shared.backgroundMusicEnabled,
            applicationActive: UIApplication.shared.applicationState == .active,
            makePlayer: {
                guard let url = resourceURL() else { throw MusicError.missingResource }
                let player = try AVAudioPlayer(contentsOf: url)
                player.numberOfLoops = -1
                player.volume = 0.55
                player.prepareToPlay()
                return player
            },
            activateSession: {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.ambient, options: .mixWithOthers)
                try session.setActive(true)
            }
        )
        service.observeSystem()
        return service
    }()

    private enum MusicError: Error { case missingResource }
    private let makePlayer: () throws -> TrainingMusicPlaying
    private let activateSession: () throws -> Void
    private var player: TrainingMusicPlaying?
    private var owners: Set<UUID> = []
    private var enabled: Bool
    private var applicationActive: Bool
    private var interrupted = false
    private var resting = false
    private var subscriptions: Set<AnyCancellable> = []

    var isPlaying: Bool { player?.isPlaying == true }

    init(enabled: Bool, applicationActive: Bool,
         makePlayer: @escaping () throws -> TrainingMusicPlaying,
         activateSession: @escaping () throws -> Void) {
        self.enabled = enabled
        self.applicationActive = applicationActive
        self.makePlayer = makePlayer
        self.activateSession = activateSession
    }

    static func resourceURL(in bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: "quiet_table", withExtension: "caf", subdirectory: "Audio/Music")
    }

    func enter(_ owner: UUID) {
        if owners.isEmpty { interrupted = false }
        owners.insert(owner)
        reconcile()
    }

    func leave(_ owner: UUID) {
        owners.remove(owner)
        reconcile()
    }

    func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
        if enabled { interrupted = false }
        reconcile()
    }

    func setApplicationActive(_ active: Bool) {
        applicationActive = active
        reconcile()
    }

    func setResting(_ resting: Bool) {
        self.resting = resting
        reconcile()
    }

    func beginInterruption() {
        interrupted = true
        reconcile()
    }

    func endInterruption(shouldResume: Bool) {
        interrupted = !shouldResume
        reconcile()
    }

    func resetMediaServices() {
        player = nil
        reconcile()
    }

    private func reconcile() {
        guard enabled, applicationActive, !interrupted, !resting, !owners.isEmpty else {
            player?.pause()
            return
        }
        guard !isPlaying else { return }
        do {
            try activateSession()
            if player == nil { player = try makePlayer() }
            if player?.play() != true { print("[TrainingMusic] Playback could not start") }
        } catch {
            print("[TrainingMusic] Playback failed: \(error)")
        }
    }

    private func observeSystem() {
        UserPreferences.shared.$backgroundMusicEnabled
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.setEnabled($0) }
            .store(in: &subscriptions)
        observe(UIApplication.willResignActiveNotification) { $0.setApplicationActive(false) }
        observe(UIApplication.didBecomeActiveNotification) { $0.setApplicationActive(true) }
        observe(AVAudioSession.mediaServicesWereResetNotification) { $0.resetMediaServices() }
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
                if type == .began {
                    self?.beginInterruption()
                } else {
                    let options = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                    self?.endInterruption(shouldResume: AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume))
                }
            }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
                if raw == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                    self?.beginInterruption()
                }
            }.store(in: &subscriptions)
    }

    private func observe(_ name: Notification.Name, action: @escaping (TrainingMusicPlayer) -> Void) {
        NotificationCenter.default.publisher(for: name)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                action(self)
            }.store(in: &subscriptions)
    }
}
