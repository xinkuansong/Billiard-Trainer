import XCTest
import SceneKit
import AVFoundation
@testable import QiuJi

@MainActor
final class ShotAudioTests: XCTestCase {
    func testPrepareRecoversLostSessionWhileEngineRemainsRunningWithoutMusic() throws {
        let engine = AVAudioEngine()
        var sessionAvailable = false
        let bank = ShotSoundBank(engine: engine, activateSession: {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
            sessionAvailable = true
        })
        defer { bank.stopAll(); engine.stop() }
        bank.prepare()
        XCTAssertTrue(engine.isRunning)
        XCTAssertTrue(sessionAvailable)
        // The shared session can be relinquished independently of the engine.
        // Model that state without relying on simulator-specific interruption behavior.
        sessionAvailable = false
        bank.prepare()
        XCTAssertTrue(engine.isRunning)
        XCTAssertTrue(sessionAvailable, "Shot playback must recover its own session; music must not be required")
    }

    func testInstalledShotSamplesDecodeWithoutPreviewAndMissingPreviewFallsBack() throws {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        for kind in ShotSoundKind.allCases {
            let bundled = try XCTUnwrap(ShotSoundBank.resourceURL(name: kind.assetPrefix))
            XCTAssertTrue(bundled.path.hasPrefix(Bundle.main.bundlePath))
            XCTAssertEqual(ShotSoundBank.resourceURL(name: kind.assetPrefix, previewDirectory: missing), bundled)
            let file = try AVAudioFile(forReading: bundled)
            XCTAssertGreaterThan(file.length, 0)
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                       frameCapacity: AVAudioFrameCount(file.length)))
            try file.read(into: buffer)
            let samples = try XCTUnwrap(buffer.floatChannelData)[0]
            let peak = (0..<Int(buffer.frameLength)).map { abs(samples[$0]) }.max() ?? 0
            XCTAssertGreaterThan(peak, 0, "Bundled \(kind) must contain audio")
        }
        XCTAssertNil(ShotSoundBank.resourceURL(name: "missing-sound-" + UUID().uuidString))
    }

    func testLocalPreviewOverrideStillWinsWhenPresent() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: directory) }
            catch { XCTFail("Could not remove preview test directory: \(error)") }
        }
        let name = ShotSoundKind.cueStrike.assetPrefix
        let bundled = try XCTUnwrap(ShotSoundBank.resourceURL(name: name))
        let preview = directory.appendingPathComponent(name + ".caf")
        try FileManager.default.copyItem(at: bundled, to: preview)
        XCTAssertEqual(ShotSoundBank.resourceURL(name: name, previewDirectory: directory), preview)
    }

    func testBundledSamplesProduceMixerAudioAndMuteStopsNewSounds() async throws {
        let defaults = UserDefaults.standard
        let oldPreview = defaults.object(forKey: "shotAudioPreviewEnabled")
        let oldEnabled = UserPreferences.shared.soundEffectsEnabled
        defaults.set(false, forKey: "shotAudioPreviewEnabled")
        UserPreferences.shared.soundEffectsEnabled = true
        let engine = AVAudioEngine()
        let bank = ShotSoundBank(engine: engine)
        let capture = ShotMixerCapture()
        bank.prepare()
        XCTAssertTrue(engine.isRunning)
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { buffer, _ in
            capture.append(buffer)
        }
        defer {
            bank.stopAll()
            engine.mainMixerNode.removeTap(onBus: 0)
            engine.stop()
            defaults.set(oldPreview, forKey: "shotAudioPreviewEnabled")
            UserPreferences.shared.soundEffectsEnabled = oldEnabled
        }
        // Exercise the actual production buffer loader, player pool and gain path.
        for kind in ShotSoundKind.allCases where kind.outputGainScale > 0 {
            bank.stopAll()
            try await Task.sleep(for: .milliseconds(200))
            capture.reset()
            bank.play(kind: kind, speed: 6)
            try await Task.sleep(for: .seconds(1))
            let measured = capture.measurement()
            XCTAssertGreaterThan(measured.frames, 0, "Audio render callback must run")
            XCTAssertGreaterThan(measured.peak, 0.0001, "No rendered audio for \(kind)")
            print("[BundledShotAudio] \(kind) frames=\(measured.frames) peak=\(measured.peak)")
        }
        bank.stopAll()
        try await Task.sleep(for: .milliseconds(200))
        UserPreferences.shared.soundEffectsEnabled = false
        capture.reset()
        bank.play(kind: .cueStrike, speed: 6)
        try await Task.sleep(for: .milliseconds(500))
        let muted = capture.measurement()
        XCTAssertGreaterThan(muted.frames, 0)
        XCTAssertEqual(muted.peak, 0, "Muted playback must not schedule sound")
    }

    func testBundledMetalControlsDecodeHaveDistinctTimbresAndShortFadedTails() throws {
        var signatures: [[Float]] = []
        let directory = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/control-metal-20261001")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for control in ShotSoundBank.Control.allCases {
            let url = try XCTUnwrap(ShotSoundBank.controlResourceURL(for: control), "Missing bundled \(control.assetName)")
            let file = try AVAudioFile(forReading: url)
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                       frameCapacity: AVAudioFrameCount(file.length)))
            try file.read(into: buffer)
            let samples = try XCTUnwrap(buffer.floatChannelData)[0]
            let frames = Int(buffer.frameLength)
            let duration = Double(frames) / buffer.format.sampleRate
            XCTAssertGreaterThan(duration, 0.025)
            XCTAssertLessThan(duration, ShotDragDetents.soundMinimumInterval,
                              "Each metal click finishes before the next one can interrupt it")
            var peak: Float = 0
            for frame in 0..<frames {
                XCTAssertTrue(samples[frame].isFinite)
                peak = max(peak, abs(samples[frame]))
            }
            XCTAssertGreaterThan(peak, 0.1)
            XCTAssertLessThan(peak, 0.28)
            XCTAssertEqual(samples[0], 0)
            XCTAssertEqual(samples[frames - 1], 0)
            signatures.append(Array(UnsafeBufferPointer(start: samples, count: 128)))
            let output = try AVAudioFile(forWriting: directory.appendingPathComponent(control.assetName + ".caf"),
                                         settings: buffer.format.settings)
            try output.write(from: buffer)
        }
        XCTAssertNotEqual(signatures[0], signatures[1], "Aim and power use distinct accepted audition samples")
    }

    func testPreviewOptInSurvivesRelaunchWithoutOverridingLaterMute() {
        let name = "ShotAudioPreviewTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        UserPreferences.configureLocalAudioPreview(defaults: defaults, arguments: [])
        XCTAssertFalse(defaults.bool(forKey: "shotAudioPreviewEnabled"))
        XCTAssertFalse(defaults.bool(forKey: "soundEffectsEnabled"))
        UserPreferences.configureLocalAudioPreview(defaults: defaults, arguments: ["-shotAudioPreview"])
        XCTAssertTrue(defaults.bool(forKey: "shotAudioPreviewEnabled"))
        XCTAssertTrue(defaults.bool(forKey: "soundEffectsEnabled"))
        UserPreferences.configureLocalAudioPreview(defaults: defaults, arguments: [])
        XCTAssertTrue(UserPreferences(defaults: defaults).soundEffectsEnabled)
        XCTAssertTrue(defaults.bool(forKey: "shotAudioPreviewEnabled"))
        defaults.set(false, forKey: "soundEffectsEnabled")
        UserPreferences.configureLocalAudioPreview(defaults: defaults, arguments: [])
        XCTAssertFalse(UserPreferences(defaults: defaults).soundEffectsEnabled)
    }

    func testSoundPreferenceReadsLaunchArgumentStringAndDefaultsOff() {
        let name = "ShotAudioTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertFalse(UserPreferences(defaults: defaults).soundEffectsEnabled)
        defaults.set("YES", forKey: "soundEffectsEnabled")
        XCTAssertTrue(UserPreferences(defaults: defaults).soundEffectsEnabled)
    }

    func testGainIsSilentForZeroNegativeAndInvalidIntensity() {
        for kind in ShotSoundKind.allCases {
            for intensity: Float in [0, -1, .nan, .infinity] {
                XCTAssertEqual(ShotSoundBank.gain(for: kind, intensity: intensity), 0)
            }
        }
    }

    func testGainIsContinuousMonotonicAndBounded() {
        for kind in ShotSoundKind.allCases {
            var previous: Float = 0
            for i in 0...1000 {
                let gain = ShotSoundBank.gain(for: kind, intensity: Float(i) / 1000)
                XCTAssertGreaterThanOrEqual(gain, previous)
                XCTAssertLessThanOrEqual(gain, 1)
                XCTAssertLessThan(gain - previous, 0.04)
                previous = gain
            }
            XCTAssertEqual(ShotSoundBank.gain(for: kind, intensity: 2), previous)
        }
        XCTAssertLessThan(ShotSoundBank.gain(for: .cushion, intensity: 1), ShotSoundBank.gain(for: .ballHit, intensity: 1))
    }

    func testGrazingContactExcludesTangentialSpeed() {
        XCTAssertEqual(ShotAudioScheduler.normalSpeed(SCNVector3(3,0,4), normal: SCNVector3(0,0,2)), 4, accuracy: 1e-6)
        XCTAssertEqual(ShotAudioScheduler.normalSpeed(SCNVector3(3,0,0), normal: SCNVector3(0,0,1)), 0)
        XCTAssertEqual(ShotAudioScheduler.normalSpeed(SCNVector3(3,0,4), normal: nil), 5)
        XCTAssertEqual(ShotAudioScheduler.normalSpeed(SCNVector3(3,0,4), normal: SCNVector3Zero), 5)
    }

    func testPreEventVelocityDoesNotReadClearedOrReflectedEventFrame() {
        func frame(_ time: Float, _ x: Float) -> BallFrame {
            BallFrame(time: time, position: SCNVector3Zero, velocity: SCNVector3(x,0,0), angularVelocity: SCNVector4(0,0,0,0), state: .sliding)
        }
        let frames = [frame(0,3),frame(0.5,2),frame(1,0),frame(1,-1)]
        XCTAssertEqual(ShotAudioScheduler.preEventVelocity(frames, at: 1).x, 2)
        XCTAssertEqual(ShotAudioScheduler.preEventVelocity(frames, at: 0).x, 3)
        XCTAssertEqual(ShotAudioScheduler.preEventVelocity(frames, at: 1.1).x, -1)
        XCTAssertEqual(ShotAudioScheduler.preEventVelocity(frames, at: -1).length(), 0)
        XCTAssertEqual(ShotAudioScheduler.preEventVelocity([], at: 1).length(), 0)
    }
}

private final class ShotMixerCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var frames = 0
    private var peak: Float = 0

    func append(_ buffer: AVAudioPCMBuffer) {
        guard let channels = buffer.floatChannelData else { return }
        var maximum: Float = 0
        for channel in 0..<Int(buffer.format.channelCount) {
            for frame in 0..<Int(buffer.frameLength) {
                maximum = max(maximum, abs(channels[channel][frame]))
            }
        }
        lock.lock()
        frames += Int(buffer.frameLength)
        peak = max(peak, maximum)
        lock.unlock()
    }

    func reset() {
        lock.lock()
        frames = 0
        peak = 0
        lock.unlock()
    }

    func measurement() -> (frames: Int, peak: Float) {
        lock.lock()
        defer { lock.unlock() }
        return (frames, peak)
    }
}


extension ShotAudioTests {
    func testSeparatingAndTangentialContactsAreSilent() {
        let n = SCNVector3(0,0,1)
        XCTAssertEqual(ContactSoundEvent.approach(SCNVector3(3,0,4), normal: n), 0)
        XCTAssertEqual(ContactSoundEvent.approach(SCNVector3(3,0,-4), normal: n), 4)
        XCTAssertEqual(ContactSoundEvent.approach(SCNVector3(3,0,0), normal: n), 0)
    }

    func testSpeedCurvesKeepBreakHeadroomAndQuietTouches() {
        XCTAssertLessThan(ShotSoundBank.gain(for: .ballHit, speed: 0.2), 0.001,
                          "An isolated very slow ball contact must be nearly silent")
        XCTAssertLessThan(ShotSoundBank.gain(for: .ballHit, speed: 0.5), 0.005)
        XCTAssertLessThan(ShotSoundBank.gain(for: .ballHit, speed: 1), 0.015)
        XCTAssertLessThan(ShotSoundBank.gain(for: .ballHit, speed: 1.5), 0.05)
        XCTAssertEqual(ShotSoundBank.gain(for: .ballHit, speed: 6), 0.425, accuracy: 1e-6,
                       "The accepted strong-impact gain must remain unchanged")
        XCTAssertEqual(ShotSoundBank.gain(for: .ballHit, speed: 10), 0.5, accuracy: 1e-6)
        for kind: ShotSoundKind in [.cushion, .jaw] {
            XCTAssertLessThan(ShotSoundBank.gain(for: kind, speed: 0.6), 0.02, "Slow rubber contacts must stay quiet")
        }
        XCTAssertLessThan(ShotSoundBank.gain(for: .pocket, speed: 0.6), 0.006, "The louder pocket base sample needs lower gain for gentle leather contacts")
        XCTAssertLessThan(ShotSoundBank.gain(for: .cueStrike, speed: 4.5), ShotSoundBank.gain(for: .cueStrike, speed: 8))
        for kind in ShotSoundKind.allCases {
            var previous: Float = 0
            for step in 0...1200 {
                let gain = ShotSoundBank.gain(for: kind, speed: Float(step)/100)
                XCTAssertGreaterThanOrEqual(gain, previous)
                XCTAssertLessThan(gain-previous, 0.02)
                previous = gain
            }
        }
    }

    func testPocketRecordingPlaysOncePerBallWithoutRemovingJawContacts() {
        let recorder = TrajectoryRecorder()
        recorder.hasContactSoundFacts = true
        recorder.recordContactSound(.init(time: 0.8, ball: "one", other: "jaw", surface: .jaw, approachSpeed: 1))
        recorder.recordContactSound(.init(time: 0.9, ball: "one", other: "liner", surface: .liner, approachSpeed: 0.4))
        recorder.pocketContactSounds["one"] = [
            .init(time: 1, ball: "one", other: "pocket_0", surface: .liner, approachSpeed: 0.3),
            .init(time: 1.1, ball: "one", other: "pocket_0", surface: .liner, approachSpeed: 1),
            .init(time: 1.13, ball: "one", other: "pocket_0", surface: .liner, approachSpeed: 0.2),
            .init(time: 1.2, ball: "one", other: "pocket_0", surface: .rail, approachSpeed: 1)
        ]
        recorder.pocketContactSounds["two"] = [
            .init(time: 1.11, ball: "two", other: "pocket_0", surface: .liner, approachSpeed: 0.8)
        ]
        let timeline = ShotAudioScheduler.timeline(recorder: recorder, cueSpeed: 0)
        XCTAssertEqual(timeline.filter { $0.kind == .pocket }.map(\.time), [1.1, 1.11])
        XCTAssertEqual(timeline.filter { $0.kind == .jaw }.count, 1)
        XCTAssertEqual(timeline.filter { $0.kind == .rail }.count, 0)
        XCTAssertEqual(recorder.pocketContactSounds["one"]?.count, 4, "Playback filtering must not erase physical contacts")
    }

    func testVoiceAllocationProtectsStrongerActiveImpact() {
        XCTAssertEqual(ShotSoundBank.voiceIndex(ends: [2,0], weights: [0.8,0.2], now: 1, incoming: 0.1), 1)
        XCTAssertNil(ShotSoundBank.voiceIndex(ends: [2,2], weights: [0.8,0.2], now: 1, incoming: 0.1))
        XCTAssertEqual(ShotSoundBank.voiceIndex(ends: [2,2], weights: [0.8,0.2], now: 1, incoming: 0.4), 1)
    }

    func testBreakRecordsRealContactsAndDenseTransfer() throws {
        let rack = RackLayout.make(.chineseEightBall, seed: 42, surfaceY: 0.8)
        let result = BreakSimulator.breakShot(rack: rack, power: 8)
        XCTAssertTrue(result.settled)
        let facts = result.recorder.contactSounds
        XCTAssertTrue(result.recorder.hasContactSoundFacts)
        XCTAssertGreaterThan(facts.filter { $0.surface == .ball }.count, 10)
        XCTAssertGreaterThan(Set(facts.filter { $0.surface == .ball }.map(\.ball)).count, 3)
        XCTAssertTrue(facts.contains { $0.surface == .cushion })
        XCTAssertTrue(facts.allSatisfy { $0.approachSpeed.isFinite && $0.approachSpeed > 0 })
        let timeline = ShotAudioScheduler.timeline(recorder: result.recorder, cueSpeed: 8)
        XCTAssertEqual(timeline.first?.kind, .cueStrike)
        XCTAssertEqual(timeline.first?.speed, 8)
        let first = try XCTUnwrap(facts.first { $0.surface == .ball })
        let audible = timeline.filter { $0.kind == .ballHit }
        XCTAssertEqual(audible.first, .init(time: first.time, kind: .ballHit, speed: first.approachSpeed))
        XCTAssertLessThan(audible.count, facts.filter { $0.surface == .ball }.count)
        let lateFacts = facts.filter { $0.surface == .ball && $0.time > first.time + 0.020 }
        XCTAssertEqual(audible.filter { $0.time > first.time + 0.020 },
                       lateFacts.map { .init(time: $0.time, kind: .ballHit, speed: $0.approachSpeed) })
        XCTAssertEqual(result.recorder.contactSounds.count, facts.count, "Audio must preserve physical facts")
        print("[Audio R2 break] contacts=\(facts.count) ball=\(facts.filter { $0.surface == .ball }.count)")
    }

    func testGeometryLabelsSeparateStraightJawAndLiner() {
        let table = TableGeometry.chineseEightBallQiuJi(surfaceY: 0.8)
        XCTAssertEqual(table.linearCushions.filter { $0.soundSurface == .cushion }.count, 6)
        XCTAssertGreaterThan(table.linearCushions.filter { $0.soundSurface == .jaw }.count, 0)
        XCTAssertGreaterThan(table.linearCushions.filter { $0.soundSurface == .liner }.count, 0)
        XCTAssertFalse(table.circularCushions.isEmpty)
    }

    func testRuleCaptureAloneDoesNotCreateAnImpact() {
        let recorder = TrajectoryRecorder()
        let timeline = ShotAudioScheduler.timeline(recorder: recorder, cueSpeed: 0,
            legacyEvents: [ShotEvent(time: 1, kind: .pocket(ball: "one", pocketId: "pocket_0"))])
        XCTAssertTrue(timeline.isEmpty)
    }

    func testSlowPocketFallSoundsFollowPresentationAndOccupancy() throws {
        let table = TableGeometry.chineseEightBallQiuJi(surfaceY: 0.8)
        for pocket in table.pockets {
            let recorder = TrajectoryRecorder()
            let ball = BallState(position: SCNVector3(pocket.center.x, 0.8+BallPhysics.radius, pocket.center.z),
                velocity: SCNVector3(0.01,0,0), angularVelocity: SCNVector3Zero, state: .rolling, name: "one")
            recorder.recordPocketEntry(ball: ball, pocketID: pocket.id, time: 1, source: .event, geometry: table)
            PocketNetPresentation.attach(to: recorder)
            let contacts = try XCTUnwrap(recorder.pocketContactSounds["one"])
            let landing = try XCTUnwrap(contacts.first { $0.surface == .rail })
            XCTAssertGreaterThan(landing.time, 1)
            XCTAssertGreaterThan(landing.approachSpeed, 0.1, "Gravity-driven arrival must not use the 0.01 m/s table entry speed")
            XCTAssertTrue(contacts.contains { $0.surface == .railStop })
            let timeline = ShotAudioScheduler.timeline(recorder: recorder, cueSpeed: 0)
            XCTAssertFalse(timeline.contains { $0.kind == .rail || $0.kind == .railStop })
            for speed: Float in [0.1, 1, 3, 12] {
                XCTAssertEqual(ShotSoundBank.gain(for: .rail, speed: speed), 0)
                XCTAssertEqual(ShotSoundBank.gain(for: .railStop, speed: speed), 0)
            }
            PocketNetPresentation.attach(to: recorder)
            XCTAssertEqual(timeline, ShotAudioScheduler.timeline(recorder: recorder, cueSpeed: 0), "Repeated layout must not duplicate sounds")
            PocketNetPresentation.attach(to: recorder, preOccupied: [pocket.id: 1])
            let occupied = try XCTUnwrap(recorder.pocketContactSounds["one"])
            XCTAssertTrue(occupied.contains { $0.surface == .pocketBall })
            XCTAssertFalse(occupied.contains { $0.surface == .railStop })
            XCTAssertTrue(ShotAudioScheduler.timeline(recorder: recorder, cueSpeed: 0).contains { $0.kind == .pocketBall })
        }
    }
}

extension ShotAudioTests {
    private func packedAudioRecorder() -> TrajectoryRecorder {
        let recorder = TrajectoryRecorder()
        recorder.hasContactSoundFacts = true
        appendPackedFrame(recorder, time: 0)
        appendPackedFrame(recorder, time: 1)
        return recorder
    }

    private func appendPackedFrame(_ recorder: TrajectoryRecorder, time: Float, bOffset: Float = 0) {
        let d = 2 * BallPhysics.radius + RackLayout.gap
        for (name, x) in [(PositionPlayBall.cueKey, time == 0 ? -1 : -d),
                          ("a", Float(0)), ("b", d + bOffset), ("c", 2 * d),
                          ("outside", Float(1))] {
            recorder.recordFrame(ballName: name, frame: BallFrame(time: time,
                position: SCNVector3(x, 0.8 + BallPhysics.radius, 0), velocity: SCNVector3Zero,
                angularVelocity: SCNVector4(0, 0, 0, 0), state: .stationary))
        }
    }

    private func addAudioContact(_ recorder: TrajectoryRecorder, _ time: Float,
                                 _ a: String, _ b: String, surface: ContactSoundEvent.Surface = .ball) {
        recorder.recordContactSound(.init(time: time, ball: a, other: b, surface: surface, approachSpeed: 6))
    }

    func testPackedTransferKeepsFirstHitOtherContactsAndLateCollisions() {
        let recorder = packedAudioRecorder()
        addAudioContact(recorder, 1, PositionPlayBall.cueKey, "a")
        addAudioContact(recorder, 1, "a", "b")
        addAudioContact(recorder, 1.001, "b", "c")
        addAudioContact(recorder, 1.002, "a", PositionPlayBall.cueKey)
        addAudioContact(recorder, 1.003, "a", "outside")
        addAudioContact(recorder, 1.004, "a", "c") // Initially non-adjacent, even in the same rack.
        addAudioContact(recorder, 1.005, "b", "rail", surface: .cushion)
        addAudioContact(recorder, 1.006, "c", "jaw", surface: .jaw)
        addAudioContact(recorder, 1.007, "c", "collected", surface: .pocketBall)
        addAudioContact(recorder, 1.019, "b", "a")
        addAudioContact(recorder, 1.021, "a", "b")
        let timeline = ShotAudioScheduler.timeline(recorder: recorder, cueSpeed: 0)
        XCTAssertEqual(timeline.filter { $0.kind == .ballHit }.map(\.time), [1, 1.003, 1.004, 1.021])
        XCTAssertEqual(timeline.filter { $0.kind != .ballHit }.map(\.kind), [.cushion, .jaw, .pocketBall])
        XCTAssertEqual(recorder.contactSounds.count, 11)
    }

    func testSeparatedNeighborsStayAudibleWhenTheyRecollideInsideWindow() {
        let recorder = packedAudioRecorder()
        appendPackedFrame(recorder, time: 1.003, bOffset: 0.01)
        appendPackedFrame(recorder, time: 1.005)
        addAudioContact(recorder, 1, PositionPlayBall.cueKey, "a")
        addAudioContact(recorder, 1.001, "a", "b")
        addAudioContact(recorder, 1.006, "b", "a")
        addAudioContact(recorder, 1.007, "a", "b")
        XCTAssertEqual(ShotAudioScheduler.timeline(recorder: recorder, cueSpeed: 0).map(\.time), [1, 1.006, 1.007])
    }

    func testRackSuppressionFailsOpenWithoutGeometryAndDoesNotAffectOrdinaryShots() {
        let recorder = TrajectoryRecorder()
        recorder.hasContactSoundFacts = true
        addAudioContact(recorder, 1, PositionPlayBall.cueKey, "a")
        addAudioContact(recorder, 1.001, "a", "b")
        XCTAssertEqual(ShotAudioScheduler.timeline(recorder: recorder, cueSpeed: 0).count, 2)
        // Two object balls are a combination, not a packed multi-ball break.
        let d = 2 * BallPhysics.radius
        for (name, x) in [("a", Float(0)), ("b", d)] {
            recorder.recordFrame(ballName: name, frame: .init(time: 0, position: SCNVector3(x, 0.8, 0),
                velocity: SCNVector3Zero, angularVelocity: SCNVector4(0, 0, 0, 0), state: .stationary))
        }
        XCTAssertEqual(ShotAudioScheduler.timeline(recorder: recorder, cueSpeed: 0).count, 2)
        let nonCue = packedAudioRecorder()
        addAudioContact(nonCue, 0.9, "a", "b")
        addAudioContact(nonCue, 1, PositionPlayBall.cueKey, "a")
        addAudioContact(nonCue, 1.001, "b", "c")
        XCTAssertEqual(ShotAudioScheduler.timeline(recorder: nonCue, cueSpeed: 0).count, 3)
    }

    func testUnreachedRackContactIsNotMistakenForCueTransferAndSortingIsStable() {
        let recorder = packedAudioRecorder()
        // Input can be out of time order. At equal times preserve the solver order.
        addAudioContact(recorder, 1.004, "b", "c")
        addAudioContact(recorder, 1, PositionPlayBall.cueKey, "a")
        addAudioContact(recorder, 1.001, "b", "c") // No preceding path from the head.
        addAudioContact(recorder, 1.002, "a", "b")
        XCTAssertEqual(ShotAudioScheduler.timeline(recorder: recorder, cueSpeed: 0).map(\.time), [1, 1.001])
    }

    func testRealBreakAudioAcrossRackSizesSpeedsAndSeeds() throws {
        for game: RackGame in [.chineseEightBall, .nineBall, .zhuifen(balls: 4), .zhuifen(balls: 5), .zhuifen(balls: 6)] {
            for seed: UInt64 in [1, 42] {
                for speed: Float in [2, 8] {
                    let result = BreakSimulator.breakShot(rack: RackLayout.make(game, seed: seed), power: speed)
                    XCTAssertTrue(result.settled)
                    let facts = result.recorder.contactSounds
                    let balls = facts.filter { $0.surface == .ball }
                    let first = try XCTUnwrap(balls.first)
                    let timeline = ShotAudioScheduler.timeline(recorder: result.recorder, cueSpeed: speed)
                    let audible = timeline.filter { $0.kind == .ballHit }
                    XCTAssertEqual(audible.first, .init(time: first.time, kind: .ballHit, speed: first.approachSpeed))
                    XCTAssertLessThan(audible.count, balls.count, "\(game), seed \(seed), speed \(speed)")
                    XCTAssertEqual(audible.filter { $0.time > first.time + 0.020 },
                        balls.filter { $0.time > first.time + 0.020 }.map {
                            .init(time: $0.time, kind: .ballHit, speed: $0.approachSpeed)
                        })
                    XCTAssertEqual(timeline.filter { $0.kind == .cushion }.count,
                                   facts.filter { $0.surface == .cushion }.count)
                    XCTAssertEqual(result.recorder.contactSounds.count, facts.count)
                    print("[RackAudio] game=\(game) seed=\(seed) speed=\(speed) ballFacts=\(balls.count) audible=\(audible.count) early=\(audible.filter { $0.time <= first.time + 0.020 }.count)")
                }
            }
        }
    }
}
