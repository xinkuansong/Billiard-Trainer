import XCTest
import SceneKit
import UIKit
@testable import QiuJi

/// Renders the verified spec-v5 five-ball solution to an MP4.
///
/// Nothing here searches or tunes. The solution is read from the saved artefact
/// (`solution-events.json`), replayed through the production entry point
/// `ShotPredictor.simulateFree`, and the replay is asserted event-for-event against the artefact
/// before a single frame is drawn. If the replay disagrees the test fails and no video is written:
/// a rendered video of a shot that is not the saved solution would be worse than no video.
///
/// Opt-in: without `SIX_V5_VIDEO_DIR` and `SIX_V5_SOLUTION_JSON` the tests skip.
final class SixPocketV5VideoTests: XCTestCase {
    // Coordinate contract, identical to the search suites: SceneKit XZ horizontal, Y up, metres;
    // portrait screen up = +X, right = +Z. Surface plane at y = 0.8, ball centres at y + radius.
    private let y: Float = 0.8
    /// Balls on the table and the pocket each one owns, as parallel arrays, before the omission.
    private var numbers = [1, 2, 3, 4, 5, 8]
    private var pocketIndices = [1, 3, 5, 2, 0, 4]
    private var omittedBall: Int?

    /// Same omission as `SixPocketV4RefineTests`: drop the ball and its pocket from both arrays so
    /// placement, the expected pot set and the obstacle list all follow from these two arrays.
    /// The emptied pocket stays in the geometry and stays a cue-pocketing risk.
    private func applyOmission(_ ball: Int?) {
        numbers = [1, 2, 3, 4, 5, 8]
        pocketIndices = [1, 3, 5, 2, 0, 4]
        omittedBall = nil
        guard let ball, let index = numbers.firstIndex(of: ball) else { return }
        numbers.remove(at: index)
        pocketIndices.remove(at: index)
        omittedBall = ball
    }

    private var geometry: TableGeometry { .chineseEightBallQiuJi(surfaceY: y) }
    private var cueName: String { ShotInput.cueBallName }
    private func key(_ ball: Int) -> String { "_\(ball)" }
    private func pocketID(_ ball: Int) -> String {
        geometry.pockets[pocketIndices[numbers.firstIndex(of: ball)!]].id
    }

    /// Ball spots for a common pocket-centre distance `d`, byte-for-byte the construction the v5
    /// solver used (`SixPocketV4RefineTests.positions(_:)`): corner balls sit on the 45° bisector,
    /// side balls on the pocket's centre line.
    private func positions(_ d: Float) -> [SCNVector3] {
        let g = geometry
        return pocketIndices.map { i in
            let p = g.pockets[i].center
            if g.pockets[i].isCorner {
                let o = d / sqrtf(2)
                return SCNVector3(p.x - (p.x > 0 ? o : -o), y + BallPhysics.radius,
                                  p.z - (p.z > 0 ? o : -o))
            }
            return SCNVector3(0, y + BallPhysics.radius, p.z - (p.z > 0 ? d : -d))
        }
    }

    // MARK: - Harness

    private func env(_ k: String) -> String? {
        ProcessInfo.processInfo.environment[k] ?? ProcessInfo.processInfo.environment["TEST_RUNNER_" + k]
    }
    private func output() throws -> URL {
        guard let path = env("SIX_V5_VIDEO_DIR") else { throw XCTSkip("Opt-in v5 video render") }
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func write(_ value: Any, _ name: String, to out: URL) throws {
        try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
            .write(to: out.appendingPathComponent(name), options: .atomic)
    }
    private func solutionJSON() throws -> [String: Any] {
        guard let path = env("SIX_V5_SOLUTION_JSON") else { throw XCTSkip("SIX_V5_SOLUTION_JSON not supplied") }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw XCTSkip("solution JSON is not an object: \(path)")
        }
        return object
    }

    /// Everything the render needs, already checked against the saved solution.
    private struct LoadedSolution {
        var q: [Float]                       // cueX, cueZ, aimRadians, cueSpeed, spinX, spinY
        var distance: Float
        var places: [SCNVector3]
        var expectedPotOrder: [String]       // ball keys, in the order the artefact drops them
        var expectedPocketIDs: [String: String]
        var expectedPotTimes: [String: Float]
    }

    private func load() throws -> LoadedSolution {
        let saved = try solutionJSON()
        let parameters = try XCTUnwrap(saved["parameters"] as? [String: NSNumber])
        let q: [Float] = try ["cueX", "cueZ", "aimRadians", "cueSpeed", "spinX", "spinY"].map {
            try XCTUnwrap(parameters[$0]).floatValue
        }
        let d = try XCTUnwrap((saved["distanceMetres"] as? NSNumber)?.floatValue)
        applyOmission((saved["omitBall"] as? NSNumber).map { $0.intValue }.flatMap { $0 == 0 ? nil : $0 })
        XCTAssertEqual(omittedBall, 4, "spec v5 solution omits ball 4")
        XCTAssertEqual(numbers, [1, 2, 3, 5, 8])

        // The cue start in `parameters` and the one recorded separately must be the same point.
        let cueXZ = try XCTUnwrap((saved["cueStartXZ"] as? [NSNumber])?.map { $0.floatValue })
        XCTAssertEqual(cueXZ.count, 2)
        XCTAssertEqual(cueXZ[0], q[0])
        XCTAssertEqual(cueXZ[1], q[1])

        // Fixture agreement: the spots this test computes must be the spots the solver used.
        let places = positions(d)
        let savedPositions = try XCTUnwrap(saved["ballPositions"] as? [String: [NSNumber]])
        XCTAssertEqual(Set(savedPositions.keys), Set(numbers.map(key)))
        for (i, ball) in numbers.enumerated() {
            let spot = try XCTUnwrap(savedPositions[key(ball)]).map { $0.floatValue }
            XCTAssertEqual(places[i].x, spot[0], accuracy: 1e-6, "ball \(ball) x")
            XCTAssertEqual(places[i].z, spot[1], accuracy: 1e-6, "ball \(ball) z")
            // Each ball really does sit d from its own pocket centre.
            let centre = geometry.pockets[pocketIndices[i]].center
            XCTAssertEqual(hypotf(places[i].x - centre.x, places[i].z - centre.z), d, accuracy: 1e-6)
        }

        // Pot order, pockets and times, straight out of the artefact's resolved event list.
        var order: [String] = []
        var pockets: [String: String] = [:]
        var times: [String: Float] = [:]
        for row in try XCTUnwrap(saved["resolvedEvents"] as? [[String: Any]])
        where (row["kind"] as? String) == "pocket" {
            let ball = try XCTUnwrap(row["ball"] as? String)
            order.append(ball)
            pockets[ball] = try XCTUnwrap(row["pocket"] as? String)
            times[ball] = try XCTUnwrap((row["time"] as? NSNumber)?.floatValue)
        }
        XCTAssertEqual(order, ["_5", "_3", "_2", "_8", "_1"], "artefact pot order changed")
        // Cross-check: the pocket each ball fell into is the pocket the fixture assigns it.
        for ball in numbers {
            XCTAssertEqual(pockets[key(ball)], pocketID(ball),
                           "artefact pocket for ball \(ball) disagrees with the fixture assignment")
        }
        XCTAssertNil(pockets[cueName], "artefact shows the cue ball pocketed")
        XCTAssertEqual(saved["termination"] as? String, "settled")
        return LoadedSolution(q: q, distance: d, places: places, expectedPotOrder: order,
                              expectedPocketIDs: pockets, expectedPotTimes: times)
    }

    /// Production entry point, exactly as `SixPocketV4RefineTests.testProductionReplay` calls it.
    private func replay(_ s: LoadedSolution) -> ShotPrediction {
        ShotPredictor.simulateFree(
            cueBall: SCNVector3(s.q[0], y + BallPhysics.radius, s.q[1]),
            aimDir: SCNVector3(cosf(s.q[2]), 0, sinf(s.q[2])),
            velocity: s.q[3], spinX: s.q[4], spinY: s.q[5], surfaceY: y,
            balls: s.places.enumerated().map { ObstacleBall(name: key(numbers[$0.offset]), position: $0.element) },
            maxEvents: 4000, maxTime: 90, includePresentation: true)
    }

    /// Asserts the production replay reproduces the saved solution. Returns the pot order it
    /// measured so the caller can record it.
    @discardableResult
    private func assertReplayMatches(_ s: LoadedSolution, _ prediction: ShotPrediction) throws -> [String] {
        XCTAssertEqual(Set(prediction.pocketedBalls), Set(numbers.map(key)))
        XCTAssertFalse(prediction.cuePocketed, "cue ball pocketed in the production replay")
        XCTAssertTrue(prediction.hasFinalTableState)
        XCTAssertEqual(String(describing: prediction.termination),
                       "Optional(QiuJi.EventDrivenEngine.Termination.settled)")
        let recorder = try XCTUnwrap(prediction.recorder)
        XCTAssertFalse(recorder.isBallPocketed(cueName))
        let entries = recorder.pocketEntries.sorted { $0.time < $1.time }
        XCTAssertEqual(entries.map { $0.ball.name }, s.expectedPotOrder, "pot order differs from the artefact")
        for entry in entries {
            XCTAssertEqual(entry.pocketID, s.expectedPocketIDs[entry.ball.name],
                           "\(entry.ball.name) fell into \(entry.pocketID)")
            // The capture snapshot is taken at the boundary crossing, marginally before the
            // engine's pocket event, so this is a tolerance on agreement, not on identity.
            XCTAssertEqual(entry.time, try XCTUnwrap(s.expectedPotTimes[entry.ball.name]), accuracy: 0.05,
                           "\(entry.ball.name) dropped at a different time than the artefact")
        }
        return entries.map { $0.ball.name }
    }

    // MARK: - Replay-only gate

    /// Cheap standalone check of clause 1: the fixture and the production replay agree with the
    /// artefact. Runs without SceneKit or the encoder so a disagreement is diagnosed on its own.
    func testSolutionReplayMatchesArtifact() throws {
        let out = try output()
        let s = try load()
        let prediction = replay(s)
        let order = try assertReplayMatches(s, prediction)
        try write(["omitBall": omittedBall ?? 0, "targetBalls": numbers,
                   "distanceMetres": s.distance, "parameters": s.q,
                   "replayPocketedBalls": prediction.pocketedBalls.sorted(),
                   "replayPotOrder": order,
                   "replayPocketIDs": s.expectedPocketIDs,
                   "replayCuePocketed": prediction.cuePocketed,
                   "replayTermination": String(describing: prediction.termination),
                   "replayDurationSeconds": prediction.duration],
                  "replay-check.json", to: out)
    }

    // MARK: - Video

    /// Piecewise slow motion. The first second of physics carries three pots, so it is rendered at
    /// 0.25×; everything after it — the long 8-ball and 1-ball rolls — at 0.5×. The map is
    /// continuous and strictly increasing, and per-frame spin advance uses the actual physics
    /// delta between consecutive frames, so the seam needs no special handling.
    private struct TimeWarp {
        let slowRate: Float = 0.25
        let mainRate: Float = 0.5
        let slowPhysicsSpan: Float = 1.0
        var slowWallSpan: Double { Double(slowPhysicsSpan / slowRate) }
        /// Physics seconds elapsed after `w` wall seconds of playback (w measured from impact).
        func physics(_ w: Double) -> Float {
            guard w > 0 else { return 0 }
            if w < slowWallSpan { return Float(w) * slowRate }
            return slowPhysicsSpan + Float(w - slowWallSpan) * mainRate
        }
        /// Inverse: wall seconds needed to reach physics time `t`.
        func wall(_ t: Float) -> Double {
            t <= slowPhysicsSpan ? Double(t / slowRate)
                                 : slowWallSpan + Double((t - slowPhysicsSpan) / mainRate)
        }
    }

    @MainActor
    func testV5FiveBallVideo() async throws {
        let out = try output()
        let s = try load()

        // Clause 1 first: never render a shot that is not the saved solution.
        let prediction = replay(s)
        let potOrder = try assertReplayMatches(s, prediction)
        let recorder = try XCTUnwrap(prediction.recorder)

        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: false, mobileRendering: true)
        XCTAssertEqual(scene.surfaceY, y, "scene surface moved away from the solved plane")
        XCTAssertTrue(scene.applyTableStyle(.charcoal, showsSights: true))
        XCTAssertTrue(scene.applyClothColor(.tournamentBlue))
        scene.hideAllBalls()
        scene.hideCueStick()

        let cue = SCNVector3(s.q[0], y + BallPhysics.radius, s.q[1])
        let aim = SCNVector3(cosf(s.q[2]), 0, sinf(s.q[2]))
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: y + BallPhysics.radius)
        let names = [cueName] + numbers.map(key)
        scene.setCueBallHomeOrientation(BallSpinIntegrator.identityOrientation)
        scene.showBall(key: PositionPlayBall.cueKey, scenePosition: cue)
        for (i, p) in s.places.enumerated() { scene.showBall(key: key(numbers[i]), scenePosition: p) }
        // Ball 4 is not on this table: its spot must stay empty for the whole video.
        XCTAssertNil(scene.visibleBalls()["_4"])
        XCTAssertEqual(scene.visibleBalls().count, numbers.count + 1)

        let camera = try XCTUnwrap(scene.cameraNode)
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.projectionDirection = .vertical
        camera.camera?.orthographicScale = 1.68
        camera.camera?.wantsExposureAdaptation = false
        camera.position = SCNVector3(0, y + 4, 0)
        camera.look(at: SCNVector3(0, y, 0), up: SCNVector3(1, 0, 0), localFront: SCNVector3(0, 0, -1))

        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene
        renderer.pointOfView = camera
        renderer.delegate = scene.contactOcclusion
        renderer.autoenablesDefaultLighting = false

        let size = CGSize(width: 1080, height: 1920), fps = 60
        let warp = TimeWarp()
        // One second of still table, then the cue stroke at the main rate, then the shot.
        let impact = 1.0 + CueStroke.totalDuration(velocity: s.q[3]) / Double(warp.mainRate)
        let motionEnd = max(prediction.duration, playback.collectionPresentationEnd)
            + Float(TrajectoryPlayback.pocketSettleDuration)
        let frameCount = Int(ceil((impact + warp.wall(motionEnd) + 1.0) * Double(fps)))

        let export = env("SIX_V5_VIDEO_EXPORT") != "0"
        let videoURL = out.appendingPathComponent("five-ball-v5-1080p.mp4")
        let writer: VideoWriter? = export ? try VideoWriter(url: videoURL, size: size, fps: fps) : nil

        // Key frames kept as PNGs for the visual check: the still table, impact, each pot, the end.
        var keyTimes: [Double] = [0, impact]
        for ball in potOrder {
            keyTimes.append(impact + warp.wall(try XCTUnwrap(s.expectedPotTimes[ball])) + 0.25)
        }
        keyTimes.append(Double(frameCount - 1) / Double(fps))
        let keyIndices = Set(keyTimes.map { max(0, min(frameCount - 1, Int(($0 * Double(fps)).rounded()))) })

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let compositor = UIGraphicsImageRenderer(size: size, format: format)
        let entries = Dictionary(uniqueKeysWithValues: recorder.pocketEntries.map { ($0.ball.name, $0) })
        var lastOmega: [String: SCNVector3] = [:]
        var previousPhysics: Float = 0
        var ledger: [[String: Any]] = []
        // Warm-up snapshots: the first SCNRenderer frame of a freshly built scene is not settled.
        for _ in 0..<3 { _ = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X) }

        for i in 0..<frameCount {
            let wall = Double(i) / Double(fps)
            let t = max(0, min(motionEnd, warp.physics(wall - impact)))
            let dt = max(0, t - previousPhysics)
            previousPhysics = t
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0
            SCNTransaction.disableActions = true
            for name in names {
                let nodeKey = name == cueName ? PositionPlayBall.cueKey : name
                let node = try XCTUnwrap(scene.allBallNodes[nodeKey])
                guard let state = playback.stateAt(ballName: name, time: min(t, prediction.duration)) else { continue }
                node.position = state.position
                node.opacity = 1
                if let opacity = playback.collectionOpacity(ballName: name, time: t),
                   let presented = playback.stateAt(ballName: name, time: t) {
                    node.position = presented.position
                    node.opacity = opacity
                } else if let entry = entries[name], t >= entry.time {
                    let pocket = TrajectoryPlayback.nearestPocket(to: entry.ball.position, surfaceY: y + BallPhysics.radius)
                    let legs = TrajectoryPlayback.solvePocketEntry(capture: entry.ball.position,
                                                                   velocity: entry.ball.velocity,
                                                                   pocketCenter: pocket.center,
                                                                   pocketRadius: pocket.radius, speedScale: 1)
                    let elapsed = Double(t - entry.time), end = TrajectoryPlayback.pocketEntryDuration(legs)
                    node.position = TrajectoryPlayback.pocketEntryPosition(start: entry.ball.position, legs: legs, at: elapsed)
                    node.opacity = CGFloat(max(0, min(1, 1 - (elapsed - end - TrajectoryPlayback.pocketPauseDuration)
                                                         / TrajectoryPlayback.pocketFadeDuration)))
                }
                if wall >= impact {
                    let previous = lastOmega[name] ?? state.angularVelocity
                    BallSpinIntegrator.advance(node: node, from: previous, to: state.angularVelocity, dt: dt)
                    lastOmega[name] = state.angularVelocity
                }
            }
            if wall < impact {
                let pull = CueStroke.pullBack(at: max(0, (wall - 1) * Double(warp.mainRate)), velocity: s.q[3])
                scene.updateCueStick(cueBallPosition: CueStroke.strikePosition(cue: cue, aim: aim,
                                                                              spinX: Double(s.q[4]),
                                                                              spinY: Double(s.q[5])),
                                     aimDirection: aim, pullBack: pull, elevationOverride: 0)
            } else {
                scene.hideCueStick()
            }
            SCNTransaction.commit()
            SCNTransaction.flush()

            let pots = recorder.pocketEntries.filter { $0.time <= t }.count
            XCTAssertNil(scene.visibleBalls()["_4"], "ball 4 became visible at frame \(i)")
            if i % fps == 0 || keyIndices.contains(i) {
                let visible = names.map { name -> [String: Any] in
                    let node = scene.allBallNodes[name == cueName ? PositionPlayBall.cueKey : name]!
                    return ["name": name, "position": [node.position.x, node.position.y, node.position.z],
                            "opacity": node.opacity, "hidden": node.isHidden]
                }
                ledger.append(["frame": i, "time": wall, "simulationTime": t, "potted": pots,
                               // The omitted ball keeps a node in the scene registry; what the
                               // video must show is that it is never made visible.
                               "ballFourVisible": scene.visibleBalls()["_4"] != nil, "balls": visible])
            }
            // Every frame is rendered and encoded. Sampling only some frames produced a missing
            // ball in an earlier round (five-ball-video-r3 REPORT), so no frame is skipped here.
            let raw = renderer.snapshot(atTime: wall, with: size, antialiasingMode: .multisampling4X)
            let image = compositor.image { context in
                UIColor.black.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                raw.draw(in: CGRect(origin: .zero, size: size))
                ("一杆进五球" as NSString).draw(at: CGPoint(x: 66, y: 42),
                    withAttributes: [.font: UIFont.boldSystemFont(ofSize: 40), .foregroundColor: UIColor.white])
                ("去 4 号球  ·  0.25× / 0.5× 慢放" as NSString).draw(at: CGPoint(x: 68, y: 108),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 26), .foregroundColor: UIColor.lightGray])
                let label = wall < impact ? "五球各距自己袋口等距  ·  仅击打一次母球" : "已进 \(pots) / 5"
                (label as NSString).draw(at: CGPoint(x: 68, y: 1810),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 30, weight: .medium),
                                     .foregroundColor: UIColor.white])
            }
            if keyIndices.contains(i) {
                try XCTUnwrap(image.pngData()).write(to: out.appendingPathComponent(String(format: "frame-%04d.png", i)))
            }
            if let writer { try writer.append(try XCTUnwrap(image.cgImage)) }
            if i % 120 == 0 { print("V5 VIDEO frame=\(i)/\(frameCount)"); await Task.yield() }
        }
        if let writer { try await writer.finish() }

        if export {
            let attributes = try FileManager.default.attributesOfItem(atPath: videoURL.path)
            XCTAssertGreaterThan(attributes[.size] as? Int ?? 0, 0, "encoder produced an empty file")
        }
        try write(["manifestSchema": "v2",
                   "width": 1080, "height": 1920, "fps": fps, "frames": frameCount,
                   "duration": Double(frameCount) / Double(fps),
                   "impactTime": impact,
                   "playbackRates": ["firstPhysicsSecond": warp.slowRate, "remainder": warp.mainRate],
                   "slowPhysicsSpanSeconds": warp.slowPhysicsSpan,
                   "omitBall": omittedBall ?? 0, "targetBalls": numbers,
                   "distanceMetres": s.distance, "parameters": s.q,
                   "pottedBalls": prediction.pocketedBalls.sorted(), "potOrder": potOrder,
                   "pocketIDs": s.expectedPocketIDs,
                   "scratch": prediction.cuePocketed,
                   "productionReplayCompleted": prediction.hasFinalTableState,
                   "simulationDuration": prediction.duration,
                   "motionEndSeconds": motionEnd,
                   "keyFrameIndices": keyIndices.sorted(),
                   "exported": export, "ledger": ledger],
                  "video-manifest.json", to: out)
    }
}
