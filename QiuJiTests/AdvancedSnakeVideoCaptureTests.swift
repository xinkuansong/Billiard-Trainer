import XCTest
import SceneKit
import UIKit
@testable import QiuJi

@MainActor
final class AdvancedSnakeVideoCaptureTests: XCTestCase {
    private func output() throws -> URL {
        let env = ProcessInfo.processInfo.environment
        let path = env["SNAKE_CAPTURE_DIR"] ?? env["TEST_RUNNER_SNAKE_CAPTURE_DIR"]
        guard let path else { throw XCTSkip("Opt-in video capture") }
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func source() throws -> PositionPlaySequence {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let dir = root.appendingPathComponent("content/position_play/sequences")
        let file = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .first { $0.lastPathComponent.hasPrefix("drill_c071__manual02-") })
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PositionPlaySequence.self, from: Data(contentsOf: file))
    }

    func testPreflight() throws {
        let out = try output()
        let seq = try source()
        let scene = AngleTrainingScene(); scene.setupScene()
        XCTAssertEqual(seq.steps.count, 15)
        XCTAssertEqual(seq.steps[0].before.onTable.count, 16)
        var rows: [[String: Any]] = []
        for (i, step) in seq.steps.enumerated() {
            let pred = try XCTUnwrap(PositionPlayShotSolver.solve(before: step.before, shot: step.shot, surfaceY: scene.surfaceY))
            var delta: Float = 0
            for (key, point) in step.after.onTable {
                let name = PositionPlayShotSolver.predName(boardKey: key, shot: step.shot)
                if let p = pred.finalPositions[name] {
                    let expected = PositionPlayShotSolver.scenePoint(point, surfaceY: scene.surfaceY)
                    delta = max(delta, hypot(p.x - expected.x, p.z - expected.z))
                }
            }
            rows.append(["shot": i+1, "feasible": pred.feasible, "objectPocketed": pred.objectPocketed,
                         "cuePocketed": pred.cuePocketed, "completed": pred.hasFinalTableState,
                         "potted": pred.pocketedBalls, "duration": pred.duration, "savedRestDeltaMeters": delta])
            print("SNAKE PREFLIGHT \(i+1): pot=\(pred.objectPocketed) scratch=\(pred.cuePocketed) delta=\(delta)")
            XCTAssertTrue(pred.feasible && pred.objectPocketed && !pred.cuePocketed && pred.hasFinalTableState, "Shot \(i+1)")
        }
        try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
            .write(to: out.appendingPathComponent("preflight.json"))
    }

    private func continuousSequence(at out: URL) throws -> PositionPlaySequence {
        var seq = try source()
        let scene = AngleTrainingScene(); scene.setupScene()
        var board = seq.steps[0].before
        var calibration: [[String: Any]] = []
        for i in seq.steps.indices {
            let original = seq.steps[i].shot
            var shot = original
            let verticalLimit = sqrt(max(0, pow(Double(CuePhysics.miscueLimitFraction), 2)-original.spinX*original.spinX))
            let desiredPoint = try XCTUnwrap(seq.steps[i].after.onTable[PositionPlayBall.cueKey])
            let desired = PositionPlayShotSolver.scenePoint(desiredPoint, surfaceY: scene.surfaceY)
            func evaluate(_ candidate: PlannedShot) -> (ShotPrediction, Float)? {
                guard abs(candidate.spinY) <= verticalLimit else { return nil }
                guard let p = PositionPlayShotSolver.solve(before: board, shot: candidate, surfaceY: scene.surfaceY),
                      p.hasFinalTableState, let rest = p.finalPositions[ShotInput.cueBallName] else { return nil }
                let penalty: Float = p.feasible && p.objectPocketed && !p.cuePocketed && p.pocketedBalls.count == 1 ? 0 : 10
                return (p, hypot(rest.x-desired.x, rest.z-desired.z)+penalty)
            }
            var best = try XCTUnwrap(evaluate(shot))
            // Coupled speed/spin corrections use numerical endpoint derivatives.
            // A line search accepts a correction only when real simulated error falls.
            for _ in 0..<12 where best.1 > 0.0005 && best.1 < 1 {
                var v = shot; v.velocity += 0.005
                var s = shot; s.spinY += 0.005
                guard let pv = evaluate(v)?.0.finalPositions[ShotInput.cueBallName],
                      let ps = evaluate(s)?.0.finalPositions[ShotInput.cueBallName],
                      let p = best.0.finalPositions[ShotInput.cueBallName] else { break }
                let a = (pv.x-p.x)/0.005, b = (ps.x-p.x)/0.005
                let c = (pv.z-p.z)/0.005, d = (ps.z-p.z)/0.005
                let det = a*d-b*c
                if abs(det) < 0.00001 { break }
                let ex = desired.x-p.x, ez = desired.z-p.z
                let dv = max(-0.2, min(0.2, (d*ex-b*ez)/det))
                let ds = max(-0.15, min(0.15, (a*ez-c*ex)/det))
                var improved = false
                for alpha in [1.0, 0.5, 0.25, 0.125] {
                    var candidate = shot
                    candidate.velocity = max(0.3, min(4, shot.velocity+Double(dv)*alpha))
                    candidate.spinY = max(-verticalLimit, min(verticalLimit, shot.spinY+Double(ds)*alpha))
                    if let result = evaluate(candidate), result.1 < best.1 {
                        shot = candidate; best = result; improved = true; break
                    }
                }
                if !improved { break }
            }
            // Refit only this video's copy to the authored next-shot position.
            // All candidates run the production solver; no fabricated endpoints.
            for scale in [1.0, 0.5, 0.25, 0.125, 0.0625] where best.1 > 0.001 {
                for _ in 0..<3 {
                    var improved = false
                    for (dv, ds) in [(0.08*scale,0.0),(-0.08*scale,0.0),(0.0,0.04*scale),(0.0,-0.04*scale)] {
                        var candidate = shot
                        candidate.velocity = max(0.3, min(4, candidate.velocity+dv))
                        candidate.spinY = max(-verticalLimit, min(verticalLimit, candidate.spinY+ds))
                        if let result = evaluate(candidate), result.1 < best.1 {
                            shot = candidate; best = result; improved = true
                        }
                    }
                    if !improved || best.1 <= 0.001 { break }
                }
            }
            let pred = best.0
            XCTAssertLessThanOrEqual(hypot(shot.spinX, shot.spinY), Double(CuePhysics.miscueLimitFraction)+1e-9)
            calibration.append(["shot": i+1, "originalVelocity": original.velocity,
                                "velocity": shot.velocity, "originalSpinY": original.spinY,
                                "spinY": shot.spinY, "stopErrorMeters": best.1])
            try JSONSerialization.data(withJSONObject: calibration, options: [.prettyPrinted, .sortedKeys])
                .write(to: out.appendingPathComponent("calibration.json"))
            print("SNAKE CONTINUOUS \(i+1): pot=\(pred.objectPocketed) scratch=\(pred.cuePocketed) error=\(best.1)")
            guard pred.feasible && pred.objectPocketed && !pred.cuePocketed && pred.hasFinalTableState else {
                throw NSError(domain: "SnakeCapture", code: i+1, userInfo: [NSLocalizedDescriptionKey: "Continuous shot \(i+1) cannot clear"])
            }
            let potted = Set(pred.pocketedBalls)
            var next = BoardSnapshot()
            for key in board.onTable.keys {
                let name = PositionPlayShotSolver.predName(boardKey: key, shot: shot)
                if !potted.contains(name) {
                    let p = try XCTUnwrap(pred.finalPositions[name])
                    let point = AngleSceneCalculator.sceneToNormalized(position: p)
                    next.onTable[key] = CanvasPoint(x: point.x, y: point.y)
                }
            }
            XCTAssertEqual(next.onTable.count, 15-i)
            seq.steps[i].before = board; seq.steps[i].after = next
            seq.steps[i].shot = shot
            board = next
        }
        XCTAssertEqual(Set(board.onTable.keys), Set([PositionPlayBall.cueKey]))
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(seq).write(to: out.appendingPathComponent("continuous-sequence.json"))
        try JSONSerialization.data(withJSONObject: calibration, options: [.prettyPrinted, .sortedKeys])
            .write(to: out.appendingPathComponent("calibration.json"))
        return seq
    }

    private func options() -> SequenceVideoExporter.Options {
        var o = SequenceVideoExporter.Options.teachingVideo3D()
        o.useAppAppearance = true
        o.tableStyle = .charcoal; o.clothColor = .tournamentBlue; o.cueStyle = .inkDragon
        o.showAimingHUD = true; o.transparentAimingHUD = true
        o.showShotHUD = false; o.overlaySequenceProgress = true
        o.aimingHUDObserver = { rect, balls in
            XCTAssertTrue(CGRect(x:0,y:0,width:1440,height:2560).contains(rect))
            XCTAssertFalse(balls.contains { $0.intersects(rect) }, "Aiming HUD must not cover balls")
        }
        o.size = CGSize(width:1440,height:2560); o.fps = 120
        o.observeHold = 0.6; o.aimingHold = 2; o.setupHold = 0.45; o.tailHold = 0.7
        o.cameraTransitionDuration = 1.25
        o.aimingFieldOfView = 52
        var camera = SequenceVideoExporter.Perspective3DConfig()
        camera.pitchDeg = 50; camera.fovDeg = 58; camera.nearEnd = .minusX
        camera.fitMargin = 0.10
        o.cameraMode = .perspective3D(camera)
        return o
    }

    private func frozenSequence(at out: URL) throws -> PositionPlaySequence {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PositionPlaySequence.self,
            from: Data(contentsOf:out.appendingPathComponent("continuous-sequence.json")))
    }

    func testTransitions() async throws {
        let out = try output()
        var seq = try frozenSequence(at:out)
        seq.steps = Array(seq.steps.prefix(3))
        var o = options()
        var previous: simd_float4x4?
        var maxPositionDelta: Float = 0, maxAngleDelta: Float = 0
        o.cameraFrameObserver = { pose, _ in
            if let p = previous {
                let delta = simd_length(p.columns.3-pose.columns.3)
                let angle = 2*acos(min(1,abs(simd_dot(simd_quatf(p).vector,simd_quatf(pose).vector))))
                maxPositionDelta = max(maxPositionDelta,delta)
                maxAngleDelta = max(maxAngleDelta,angle)
                XCTAssertLessThan(delta,0.10,"Camera position must remain continuous")
                XCTAssertLessThan(angle,0.06,"Camera direction must remain continuous")
            }
            previous = pose
        }
        let video = try await SequenceVideoExporter.exportVideo(sequence:seq,options:o)
        try FileManager.default.copyItem(at:video,to:out.appendingPathComponent("transition-preview.mp4"))
        print("CAMERA CONTINUITY maxDelta=\(maxPositionDelta)m maxAngle=\(maxAngleDelta)rad")
    }

    func testKeyframes() throws {
        let out = try output()
        let seq = try frozenSequence(at: out)
        let frames = SequenceVideoExporter.renderStills(sequence: seq, options: options())
        XCTAssertEqual(frames.count, 17)
        for frame in frames {
            let data = try XCTUnwrap(UIImage(cgImage: frame.image).pngData())
            try data.write(to: out.appendingPathComponent("\(frame.name).png"))
        }
    }

    func testExport() async throws {
        let out = try output()
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let seq = try decoder.decode(PositionPlaySequence.self,
            from: Data(contentsOf: out.appendingPathComponent("continuous-sequence.json")))
        XCTAssertEqual(seq.steps.count, 15)
        var o = options()
        let fps = o.fps
        var settled: [UUID: [String: SCNVector3]] = [:]
        var observed = Set<UUID>()
        o.settledFrameObserver = { id, positions in
            settled[id] = positions
            let index = seq.steps.firstIndex { $0.id == id }!
            XCTAssertEqual(positions.count, 15-index, "Actual settled shot \(index+1)")
            XCTAssertNotNil(positions[PositionPlayBall.cueKey])
        }
        o.observationFrameObserver = { id, positions in
            guard observed.insert(id).inserted,
                  let index = seq.steps.firstIndex(where: { $0.id == id }), index > 0,
                  let previous = settled[seq.steps[index-1].id] else { return }
            XCTAssertEqual(Set(previous.keys), Set(positions.keys))
            for (key, p) in previous {
                guard let q = positions[key] else { continue }
                XCTAssertLessThan(hypot(p.x-q.x, p.z-q.z), 0.00001, "No reset between shots \(index)/\(index+1)")
            }
        }
        var cameraFrames: [[String:Any]] = []
        var previousPose: simd_float4x4?
        var maxPositionDelta: Float = 0, maxAngleDelta: Float = 0
        o.cameraFrameObserver = { pose, fov in
            if let previous = previousPose {
                let delta = simd_length(previous.columns.3-pose.columns.3)
                let angle = 2*acos(min(1,abs(simd_dot(simd_quatf(previous).vector,simd_quatf(pose).vector))))
                maxPositionDelta = max(maxPositionDelta,delta)
                maxAngleDelta = max(maxAngleDelta,angle)
                XCTAssertLessThan(delta,0.10)
                XCTAssertLessThan(angle,0.06)
            }
            previousPose = pose
            let p = pose.columns.3
            let q = simd_quatf(pose).vector
            cameraFrames.append(["position":[p.x,p.y,p.z],"orientation":[q.x,q.y,q.z,q.w],"fov":fov])
        }
        var count = 0
        var phases: [[String: Any]] = []
        var last = ""
        o.phaseFrameObserver = { id, phase in
            let index = seq.steps.firstIndex { $0.id == id }.map { $0+1 } ?? 0
            let key = "\(index)-\(phase)"
            if key != last {
                phases.append(["shot": index, "phase": phase, "frame": count, "time": Double(count)/Double(fps)])
                print("SNAKE FRAME \(count) \(key)")
                last = key
            }
            count += 1
        }
        let video = try await SequenceVideoExporter.exportVideo(sequence: seq, options: o)
        try FileManager.default.copyItem(at: video, to: out.appendingPathComponent("advanced-snake-15ball-2k120.mp4"))
        XCTAssertEqual(phases.filter { $0["phase"] as? String == "aim" }.count, 15)
        XCTAssertEqual(phases.filter { $0["phase"] as? String == "to-aim" }.count, 15)
        XCTAssertEqual(phases.filter { $0["phase"] as? String == "from-aim" }.count, 15)
        XCTAssertEqual(phases.filter { $0["phase"] as? String == "to-observe" }.count, 14)
        try JSONSerialization.data(withJSONObject:["frames":cameraFrames,"maxPositionDelta":maxPositionDelta,
            "maxAngleDelta":maxAngleDelta],options:[.sortedKeys])
            .write(to:out.appendingPathComponent("camera-frames.json"))
        XCTAssertEqual(settled.count, 15)
        XCTAssertEqual(observed.count, 15)
        try JSONSerialization.data(withJSONObject: ["frames": count, "fps": o.fps, "phases": phases], options: [.prettyPrinted, .sortedKeys])
            .write(to: out.appendingPathComponent("timeline.json"))
    }
}
