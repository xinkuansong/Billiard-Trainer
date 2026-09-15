import AVFoundation
import XCTest
@testable import QiuJi

@MainActor
final class TrainingMusicTests: XCTestCase {
    func testPreferencesDefaultIndependentlyAndPersistExplicitChoices() throws {
        let suite = "TrainingMusicTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = UserPreferences(defaults: defaults)
        XCTAssertFalse(prefs.backgroundMusicEnabled)
        XCTAssertFalse(prefs.soundEffectsEnabled)
        prefs.backgroundMusicEnabled = false
        prefs.soundEffectsEnabled = true
        let restored = UserPreferences(defaults: defaults)
        XCTAssertFalse(restored.backgroundMusicEnabled)
        XCTAssertTrue(restored.soundEffectsEnabled)
        restored.backgroundMusicEnabled = true
        XCTAssertTrue(UserPreferences(defaults: defaults).backgroundMusicEnabled)
        XCTAssertTrue(UserPreferences(defaults: defaults).soundEffectsEnabled)
    }

    func testUpgradingPreservesEitherSavedShotPreference() throws {
        let suite = "TrainingMusicTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        for saved in [false, true] {
            defaults.set(saved, forKey: "soundEffectsEnabled")
            let prefs = UserPreferences(defaults: defaults)
            XCTAssertFalse(prefs.backgroundMusicEnabled)
            XCTAssertEqual(prefs.soundEffectsEnabled, saved)
        }
    }

    func testVisiblePagesShareOnePlayerAndLastDeparturePauses() {
        let output = MockTrainingMusicPlayback()
        var creations = 0
        let music = TrainingMusicPlayer(enabled: true, applicationActive: true,
            makePlayer: { creations += 1; return output }, activateSession: {})
        let first = UUID(), second = UUID()
        XCTAssertFalse(music.isPlaying)
        music.enter(first)
        music.enter(first)
        music.enter(second)
        XCTAssertEqual(output.starts, 1)
        XCTAssertEqual(creations, 1)
        music.leave(first)
        XCTAssertTrue(music.isPlaying)
        music.leave(second)
        XCTAssertFalse(music.isPlaying)
        music.enter(first)
        XCTAssertEqual(creations, 1, "Resume the existing loop instead of restarting the track")
        XCTAssertEqual(output.starts, 2)
    }

    func testBackgroundRestAndSettingCannotStartHiddenPage() {
        let output = MockTrainingMusicPlayback()
        let music = TrainingMusicPlayer(enabled: false, applicationActive: true,
            makePlayer: { output }, activateSession: {})
        let owner = UUID()
        music.enter(owner)
        XCTAssertFalse(music.isPlaying)
        music.setEnabled(true)
        XCTAssertTrue(music.isPlaying)
        music.setApplicationActive(false)
        XCTAssertFalse(music.isPlaying)
        music.setEnabled(false)
        music.setEnabled(true)
        XCTAssertFalse(music.isPlaying)
        music.setApplicationActive(true)
        XCTAssertTrue(music.isPlaying)
        music.setResting(true)
        XCTAssertFalse(music.isPlaying)
        music.leave(owner)
        music.setResting(false)
        XCTAssertFalse(music.isPlaying)
        music.setApplicationActive(false)
        music.setApplicationActive(true)
        XCTAssertFalse(music.isPlaying)
    }

    func testInterruptionRespectsResumeFlagAndPreference() {
        let output = MockTrainingMusicPlayback()
        let music = TrainingMusicPlayer(enabled: true, applicationActive: true,
            makePlayer: { output }, activateSession: {})
        music.enter(UUID())
        music.beginInterruption()
        XCTAssertFalse(music.isPlaying)
        music.endInterruption(shouldResume: false)
        XCTAssertFalse(music.isPlaying)
        music.endInterruption(shouldResume: true)
        XCTAssertTrue(music.isPlaying)
        music.beginInterruption()
        music.setEnabled(false)
        music.endInterruption(shouldResume: true)
        XCTAssertFalse(music.isPlaying)
    }

    func testFailedActivationCanRecoverOnNextEntry() {
        let output = MockTrainingMusicPlayback()
        var fail = true
        let music = TrainingMusicPlayer(enabled: true, applicationActive: true,
            makePlayer: { output }, activateSession: {
                if fail { throw NSError(domain: "AudioTest", code: 1) }
            })
        let owner = UUID()
        music.enter(owner)
        XCTAssertFalse(music.isPlaying)
        fail = false
        music.leave(owner)
        music.enter(owner)
        XCTAssertTrue(music.isPlaying)
    }

    func testBundledLoopDecodesToExactlySixtySeconds() async throws {
        let url = try XCTUnwrap(TrainingMusicPlayer.resourceURL())
        let file = try AVAudioFile(forReading: url)
        XCTAssertEqual(file.processingFormat.channelCount, 2)
        XCTAssertEqual(file.processingFormat.sampleRate, 44_100)
        XCTAssertEqual(file.length, 2_646_000)
        let audio = try AVAudioPlayer(contentsOf: url)
        XCTAssertEqual(audio.duration, 60, accuracy: 0.001)
        audio.numberOfLoops = -1
        XCTAssertTrue(audio.prepareToPlay())
        try AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
        try AVAudioSession.sharedInstance().setActive(true)
        defer { audio.stop() }
        XCTAssertTrue(audio.play())
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertGreaterThan(audio.currentTime, 0)
        audio.pause()
        XCTAssertFalse(audio.isPlaying)
        let pausedAt = audio.currentTime
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(audio.currentTime, pausedAt, accuracy: 0.001)
    }

    func testMediaServicesResetRecreatesPlayerOnlyWhenNeeded() {
        var creations = 0
        let music = TrainingMusicPlayer(enabled: true, applicationActive: true,
            makePlayer: { creations += 1; return MockTrainingMusicPlayback() }, activateSession: {})
        let owner = UUID()
        music.enter(owner)
        music.resetMediaServices()
        XCTAssertTrue(music.isPlaying)
        XCTAssertEqual(creations, 2)
        music.leave(owner)
        music.resetMediaServices()
        XCTAssertFalse(music.isPlaying)
        XCTAssertEqual(creations, 2)
    }
}
