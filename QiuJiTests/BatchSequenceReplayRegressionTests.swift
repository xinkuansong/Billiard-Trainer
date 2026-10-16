//
//  BatchSequenceReplayRegressionTests.swift
//  QiuJiTests
//
//  批量出片全流程回归（求解器性能优化 B5，方案 §3）：
//  重放 `content/position_play/sequences/` 下全部 drill 序列（覆盖 62 个 drill 的成品出片内容），
//  逐杆走「保存后重进」的同一条链路（`PositionPlayShotSolver.solve` → finalPositions/potted），
//  把结果落成**确定性文本 dump**（build/solver_regression/replay_dump.txt）。
//
//  用法（A/B 对拍）：本工作树（优化后）与 HEAD 基线 worktree 各跑一次本测试，
//  diff 两份 dump——**逐字节一致** = 优化未改变展示物理在全部真实 drill 盘面上的行为。
//
//  断言只做健壮性闸门（每杆可解且 feasible）；与存档 after 的偏差仅统计打印不断言
//  （存档早于 2026-07-06 的 pocketNoseRestitution 0.60→0.70 物理修订，属既有漂移，与本轮优化无关）。
//

import XCTest
import CryptoKit
import SceneKit
@testable import QiuJi

final class BatchSequenceReplayRegressionTests: XCTestCase {

    /// 仓库根（当前树 / 基线 worktree 各自解析到自己的根，dump 互不覆盖）。
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // QiuJiTests/
            .deletingLastPathComponent()   // repo root
    }

    func test_replayAllDrillSequences_deterministicDump() throws {
        let fm = FileManager.default
        let seqDir = repoRoot.appendingPathComponent("content/position_play/sequences")
        let files = (try fm.contentsOfDirectory(atPath: seqDir.path))
            .filter { $0.hasPrefix("drill_c") && $0.hasSuffix(".json") }
            .sorted()
        XCTAssertFalse(files.isEmpty, "未找到 drill 序列：\(seqDir.path)")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let surfaceY = BTTablePhysics.surfaceY

        var lines: [String] = []
        var stepCount = 0
        var outcomeMismatch = 0      // 与存档 potted/flags 不一致的杆数（仅统计）
        var maxRestDriftMM = 0.0     // 与存档 after 的最大球位偏差（仅统计）

        for file in files {
            let data = try Data(contentsOf: seqDir.appendingPathComponent(file))
            let seq = try decoder.decode(PositionPlaySequence.self, from: data)

            for (i, step) in seq.steps.enumerated() {
                stepCount += 1
                guard let pred = PositionPlayShotSolver.solve(
                    before: step.before, shot: step.shot, surfaceY: surfaceY
                ) else {
                    XCTFail("\(file) step[\(i)] 快照/意图不完整，无法求解")
                    continue
                }
                XCTAssertTrue(pred.feasible, "\(file) step[\(i)] 重放不可行：\(pred.infeasibleReason)")

                // 与录制/重放同语义：进袋离场，其余球取 finalPositions（无位移保持 before）。
                let potted = Set(pred.pocketedBalls.map { boardKey(forPredName: $0, shot: step.shot) })
                var after: [String: CGPoint] = [:]
                for key in step.before.onTable.keys where !potted.contains(key) {
                    let predN = PositionPlayShotSolver.predName(boardKey: key, shot: step.shot)
                    if let p = pred.finalPositions[predN] {
                        after[key] = AngleSceneCalculator.sceneToNormalized(position: p)
                    } else if let b = step.before.onTable[key] {
                        after[key] = CGPoint(x: b.x, y: b.y)
                    }
                }

                // 确定性 dump 行（键排序 + 定点格式）。
                let pottedStr = potted.sorted().joined(separator: ",")
                let afterStr = after.keys.sorted().map { k -> String in
                    let p = after[k]!
                    return String(format: "%@=(%.5f,%.5f)", k, p.x, p.y)
                }.joined(separator: " ")
                lines.append("\(file)|s\(i)|cuePot=\(pred.cuePocketed)|objPot=\(pred.objectPocketed)"
                             + "|potted=[\(pottedStr)]|\(afterStr)")

                // 与存档对照（仅统计，不断言——存档物理版本早于既有引擎修订）。
                if Set(step.potted) != potted
                    || step.cuePocketed != pred.cuePocketed
                    || step.objectPocketed != pred.objectPocketed {
                    outcomeMismatch += 1
                }
                for (key, np) in after {
                    guard let sp = step.after.onTable[key] else { continue }
                    // 归一化 x 跨度 = innerLength（2.54m）；y∈[0,0.5] 同尺度。
                    let dx = (Double(np.x) - sp.x) * Double(AngleSceneCalculator.innerLength)
                    let dy = (Double(np.y) - sp.y) * 2.0 * Double(AngleSceneCalculator.innerWidth)
                    maxRestDriftMM = max(maxRestDriftMM, (dx * dx + dy * dy).squareRoot() * 1000)
                }
            }
        }

        let outDir = repoRoot.appendingPathComponent("build/solver_regression")
        try fm.createDirectory(at: outDir, withIntermediateDirectories: true)
        let outFile = outDir.appendingPathComponent("replay_dump.txt")
        try (lines.joined(separator: "\n") + "\n")
            .write(to: outFile, atomically: true, encoding: .utf8)

        print("📼 [B5] 重放 \(files.count) 条序列 / \(stepCount) 杆全部可解可行；"
              + "dump → \(outFile.path)")
        print("📼 [B5] 与存档对照（信息项）：结果不一致 \(outcomeMismatch) 杆，"
              + String(format: "最大球位漂移 %.1fmm", maxRestDriftMM))
    }

    /// `ShotPrediction` 球名 → 桌面键（`PositionPlayShotSolver.predName` 的逆映射）。
    private func boardKey(forPredName name: String, shot: PlannedShot) -> String {
        if name == ShotInput.cueBallName { return PositionPlayBall.cueKey }
        if !shot.isFree, name == ShotInput.targetBallName { return shot.targetKey }
        return name
    }
}

/// Current-engine replay must have no cross-archive state or historical direction inputs.
final class SequenceCurrentEngineReplayTests: XCTestCase {
    func testNoHistoricalDirectionResourcesAreBundled() {
        XCTAssertNil(Bundle.main.url(forResource: "legacy-directions", withExtension: "json", subdirectory: "SequenceReplay"))
    }

    func testInvalidStepCannotBlockAnotherFormationAndIdentityDoesNotChangePhysics() throws {
        let step = try XCTUnwrap(DrillTryoutBoardStore.formations(for: "drill_c001").first?.steps.first)
        var invalid = step
        invalid.before = BoardSnapshot(onTable: [:])
        XCTAssertNil(SequenceReplayResolver.solve(step: invalid, surfaceY: BTTablePhysics.surfaceY))
        var renamed = step
        renamed.id = UUID()
        let actual = try XCTUnwrap(SequenceReplayResolver.solve(step: renamed, surfaceY: BTTablePhysics.surfaceY))
        let expected = try XCTUnwrap(PositionPlayShotSolver.solve(before: step.before, shot: step.shot, surfaceY: BTTablePhysics.surfaceY))
        XCTAssertTrue(actual.feasible)
        XCTAssertEqual(actual.aimDirection.x, expected.aimDirection.x)
        XCTAssertEqual(actual.aimDirection.z, expected.aimDirection.z)
        XCTAssertEqual(Set(actual.pocketedBalls), Set(expected.pocketedBalls))
        for (name, stop) in expected.finalPositions {
            XCTAssertEqual(actual.finalPositions[name]?.x, stop.x)
            XCTAssertEqual(actual.finalPositions[name]?.z, stop.z)
        }
    }

    func testAllBundledShotsUseCurrentEngineAndReachPlaybackEnd() throws {
        let directory = try XCTUnwrap(Bundle.main.resourceURL).appendingPathComponent("DrillBoards")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("drill_c") && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        XCTAssertEqual(files.count, 98)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        var shots = 0, empty = 0
        for file in files {
            let sequence = try decoder.decode(PositionPlaySequence.self, from: Data(contentsOf: file))
            if sequence.steps.isEmpty { empty += 1 }
            for (index, step) in sequence.steps.enumerated() {
                let label = "\(file.lastPathComponent) shot=\(index + 1)"
                shots += 1
                guard let actual = SequenceReplayResolver.solve(step: step, surfaceY: BTTablePhysics.surfaceY) else {
                    XCTFail("\(label): production replay returned nil"); continue
                }
                XCTAssertTrue(actual.feasible, "\(label): \(actual.infeasibleReason)")
                XCTAssertTrue(actual.hasFinalTableState, label)
                XCTAssertGreaterThan(actual.duration, 0.05, label)
                let recorder = try XCTUnwrap(actual.recorder, label)
                let expected = try XCTUnwrap(PositionPlayShotSolver.solve(before: step.before, shot: step.shot, surfaceY: BTTablePhysics.surfaceY), label)
                XCTAssertEqual(actual.aimDirection.x, expected.aimDirection.x, label)
                XCTAssertEqual(actual.aimDirection.z, expected.aimDirection.z, label)
                XCTAssertEqual(Set(actual.pocketedBalls), Set(expected.pocketedBalls), label)
                let playback = TrajectoryPlayback(recorder: recorder, surfaceY: BTTablePhysics.surfaceY + BallPhysics.radius)
                for (name, stop) in expected.finalPositions {
                    XCTAssertEqual(actual.finalPositions[name]?.x, stop.x, label)
                    XCTAssertEqual(actual.finalPositions[name]?.z, stop.z, label)
                    if !recorder.isBallPocketed(name) {
                        let end = try XCTUnwrap(playback.stateAt(ballName: name, time: playback.duration), label)
                        XCTAssertEqual(end.position.x, stop.x, accuracy: 0.000001, label)
                        XCTAssertEqual(end.position.z, stop.z, accuracy: 0.000001, label)
                    }
                }
            }
            print("CURRENT-ENGINE-BUNDLE", file.lastPathComponent, "shots", sequence.steps.count)
        }
        XCTAssertEqual(shots, 629)
        XCTAssertEqual(empty, 3)
        print("CURRENT-ENGINE-BUNDLE total=98 shots=629 empty=3")
    }
}


final class SequenceEnginePersistenceTests: XCTestCase {
    private func firstStep() throws -> SequenceStep {
        try XCTUnwrap(DrillTryoutBoardStore.formations(for: "drill_c001").first?.steps.first)
    }

    func testLegacyTrajectoryFieldIsIgnoredAndNeverEncodedAgain() throws {
        let step = try firstStep()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(step)) as? [String: Any])
        // Even malformed, stale experimental samples must have no influence on playback.
        object["trajectory"] = ["version": -1, "tracks": "obsolete-test-data"]
        let decoded = try JSONDecoder().decode(SequenceStep.self, from: JSONSerialization.data(withJSONObject: object))
        let reencoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)) as? [String: Any])
        XCTAssertNil(reencoded["trajectory"])
        let actual = try XCTUnwrap(SequenceReplayResolver.solve(step: decoded, surfaceY: BTTablePhysics.surfaceY))
        let expected = try XCTUnwrap(PositionPlayShotSolver.solve(before: step.before, shot: step.shot, surfaceY: BTTablePhysics.surfaceY))
        XCTAssertTrue(actual.hasFinalTableState)
        XCTAssertEqual(actual.aimDirection.x, expected.aimDirection.x)
        XCTAssertEqual(actual.aimDirection.z, expected.aimDirection.z)
        XCTAssertEqual(Set(actual.pocketedBalls), Set(expected.pocketedBalls))
        for (name, stop) in expected.finalPositions {
            XCTAssertEqual(actual.finalPositions[name]?.x, stop.x)
            XCTAssertEqual(actual.finalPositions[name]?.z, stop.z)
        }
    }

    func testReplayComputesFromBeforeRatherThanTrustingArchivedAfter() throws {
        var step = try firstStep()
        let expected = try XCTUnwrap(PositionPlayShotSolver.solve(before: step.before, shot: step.shot, surfaceY: BTTablePhysics.surfaceY))
        step.after = BoardSnapshot(onTable: [:])
        step.potted = []; step.cuePocketed = true; step.objectPocketed = false
        let actual = try XCTUnwrap(SequenceReplayResolver.solve(step: step, surfaceY: BTTablePhysics.surfaceY))
        XCTAssertEqual(actual.cuePocketed, expected.cuePocketed)
        XCTAssertEqual(actual.objectPocketed, expected.objectPocketed)
        XCTAssertEqual(Set(actual.finalPositions.keys), Set(expected.finalPositions.keys))
        for (name, stop) in expected.finalPositions {
            XCTAssertEqual(actual.finalPositions[name]?.x, stop.x)
            XCTAssertEqual(actual.finalPositions[name]?.z, stop.z)
        }
    }

    func testAllBundledSequencesContainNoPersistedTrajectory() throws {
        let directory = try XCTUnwrap(Bundle.main.resourceURL).appendingPathComponent("DrillBoards")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("drill_c") && $0.pathExtension == "json" }
        XCTAssertEqual(files.count, 98)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        var count = 0
        for file in files {
            let data = try Data(contentsOf: file)
            let sequence = try decoder.decode(PositionPlaySequence.self, from: data)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let steps = try XCTUnwrap(object["steps"] as? [[String: Any]])
            XCTAssertEqual(sequence.steps.count, steps.count)
            for (encoded, step) in zip(steps, sequence.steps) {
                XCTAssertNil(encoded["trajectory"], file.lastPathComponent)
                XCTAssertTrue(step.recordedDirection?.isValid == true, file.lastPathComponent)
            }
            count += steps.count
        }
        XCTAssertEqual(count, 629)
        XCTAssertNil(Bundle.main.url(forResource: "legacy-trajectories", withExtension: "json", subdirectory: "SequenceReplay"))
    }
}

/// One-time migration reference and exhaustive replay parity; never writes authoring archives.
@MainActor
final class SequenceDirectionMigrationTests: XCTestCase {
    nonisolated private var evidence: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("output/direction-only-replay-20261015")
    }
    override func setUpWithError() throws {
        try super.setUpWithError()
        guard FileManager.default.fileExists(atPath: evidence.appendingPathComponent("source-before").path) else {
            throw XCTSkip("One-time migration audit requires the local pre-migration backup; permanent Bundle contract tests run independently")
        }
    }
    private func sources() throws -> [(URL, PositionPlaySequence)] {
        let files = try FileManager.default.contentsOfDirectory(at: evidence.appendingPathComponent("source-before"), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try files.map { ($0, try decoder.decode(PositionPlaySequence.self, from: Data(contentsOf: $0))) }
    }
    private func fingerprint(_ p: ShotPrediction) throws -> String {
        let recorder = try XCTUnwrap(p.recorder)
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: BTTablePhysics.surfaceY + BallPhysics.radius)
        var bytes = Data()
        func scalar(_ x: Float) { var bits = x.bitPattern.littleEndian; withUnsafeBytes(of: &bits) { bytes.append(contentsOf: $0) } }
        func vector(_ x: SCNVector3) { scalar(x.x); scalar(x.y); scalar(x.z) }
        scalar(p.duration); scalar(playback.duration)
        bytes.append(contentsOf: "\(p.cuePocketed)|\(p.objectPocketed)|\(p.pocketedBalls.sorted())".utf8)
        for name in recorder.framesByBallName.keys.sorted() {
            bytes.append(contentsOf: name.utf8)
            for frame in recorder.framesByBallName[name]! {
                scalar(frame.time); vector(frame.position); vector(frame.velocity)
                scalar(frame.angularVelocity.x); scalar(frame.angularVelocity.y)
                scalar(frame.angularVelocity.z); scalar(frame.angularVelocity.w)
                bytes.append(contentsOf: frame.state.rawValue.utf8)
            }
            if let stop = p.finalPositions[name] { vector(stop) }
            for i in 0...Int(ceil(playback.duration * 120)) {
                let time = min(Float(i) / 120, playback.duration)
                if let state = playback.stateAt(ballName: name, time: time) {
                    vector(state.position); vector(state.velocity); vector(state.angularVelocity)
                    bytes.append(contentsOf: state.motionState.rawValue.utf8)
                }
            }
        }
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
    private func settledBoard(_ prediction: ShotPrediction, before: BoardSnapshot, shot: PlannedShot) -> BoardSnapshot {
        var result: [String: CanvasPoint] = [:]
        for key in before.onTable.keys {
            let name = PositionPlayShotSolver.predName(boardKey: key, shot: shot)
            if prediction.pocketedBalls.contains(name) { continue }
            if let stop = prediction.finalPositions[name] {
                let p = AngleSceneCalculator.sceneToNormalized(position: stop)
                result[key] = CanvasPoint(x: Double(p.x), y: Double(p.y))
            } else { result[key] = before.onTable[key] }
        }
        return BoardSnapshot(onTable: result)
    }
    func testCapturePreMigrationReference() throws {
        let destination = evidence.appendingPathComponent("reference.json")
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw XCTSkip("Immutable pre-migration reference already exists")
        }
        var reference: [String: [String]] = [:]
        var total = 0
        for (file, sequence) in try sources() {
            var hashes: [String] = []
            for step in sequence.steps {
                let p = try XCTUnwrap(PositionPlayShotSolver.solve(before: step.before, shot: step.shot, surfaceY: BTTablePhysics.surfaceY))
                XCTAssertTrue(p.feasible, file.lastPathComponent)
                XCTAssertTrue(p.hasFinalTableState, file.lastPathComponent)
                hashes.append(try fingerprint(p)); total += 1
            }
            reference[file.lastPathComponent] = hashes
        }
        let data = try JSONSerialization.data(withJSONObject: reference, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: destination, options: .withoutOverwriting)
        print("DIRECTION-REFERENCE sources=\(reference.count) shots=\(total)")
    }
}


extension SequenceDirectionMigrationTests {
    func testBuildDirectionMigrationAndVerifyEveryTrajectory() throws {
        let reference = try JSONDecoder().decode([String: [String]].self,
            from: Data(contentsOf: evidence.appendingPathComponent("reference.json")))
        var plan: [String: [[String: Any]]] = [:]
        var count = 0
        for (file, sequence) in try sources() {
            var entries: [[String: Any]] = []
            for (index, original) in sequence.steps.enumerated() {
                let p = try XCTUnwrap(PositionPlayShotSolver.solve(before: original.before,
                    shot: original.shot, surfaceY: BTTablePhysics.surfaceY))
                let label = "\(file.lastPathComponent) #\(index + 1)"
                let currentHash = try fingerprint(p)
                if currentHash != reference[file.lastPathComponent]?[index] {
                    // Existing Dictionary iteration changes simultaneous-event Float rounding.
                    // Reproduce the immutable baseline with the UNCHANGED authoring solver;
                    // never waive a new replay discrepancy or change production physics.
                    var foundBaseline = false
                    var maxStop: Float = 0, maxSample: Float = 0
                    for _ in 0..<100 {
                        var reordered = BoardSnapshot()
                        for key in original.before.onTable.keys.shuffled() {
                            reordered.onTable[key] = original.before.onTable[key]
                        }
                        let control = try XCTUnwrap(PositionPlayShotSolver.solve(before: reordered,
                            shot: original.shot, surfaceY: BTTablePhysics.surfaceY))
                        if try fingerprint(control) == reference[file.lastPathComponent]?[index] { foundBaseline = true }
                        let delta = try difference(p, control)
                        maxStop = max(maxStop, delta.0); maxSample = max(maxSample, delta.1)
                    }
                    XCTAssertTrue(foundBaseline, "Original solver must reproduce baseline: " + label)
                    XCTAssertLessThanOrEqual(maxStop, 0.001, label)
                    XCTAssertLessThanOrEqual(maxSample, 0.001, label)
                    print("DIRECTION-BASELINE-JITTER",label,"maxStopMM",maxStop,"maxSampleMM",maxSample)
                }
                let direction = try XCTUnwrap(p.recordedDirection)
                XCTAssertTrue(direction.isValid, label)
                let decoded = try JSONDecoder().decode(RecordedStrikeDirection.self,
                    from: JSONEncoder().encode(direction))
                XCTAssertEqual(decoded.x.bitPattern, direction.x.bitPattern, label)
                XCTAssertEqual(decoded.z.bitPattern, direction.z.bitPattern, label)
                var step = original; step.recordedDirection = decoded
                let replay = try XCTUnwrap(SequenceReplayResolver.solve(step: step, surfaceY: BTTablePhysics.surfaceY))
                XCTAssertTrue(replay.hasFinalTableState, label)
                XCTAssertEqual(try fingerprint(replay), currentHash, label)
                entries.append(["id": step.id.uuidString, "xBits": direction.x.bitPattern, "zBits": direction.z.bitPattern])
                count += 1
            }
            plan[file.lastPathComponent] = entries
        }
        XCTAssertEqual(count, 639)
        guard testRun?.failureCount == 0 else { return }
        try JSONSerialization.data(withJSONObject: plan, options: [.prettyPrinted, .sortedKeys])
            .write(to: evidence.appendingPathComponent("migration-plan.json"), options: .atomic)
        print("DIRECTION-PARITY files=\(plan.count) shots=\(count) bitExact=true")
    }

    func testContinuousReplayMatchesOriginalSolver() throws {
        var links = 0
        for (file, sequence) in try sources() {
            var oldBoard: BoardSnapshot?, newBoard: BoardSnapshot?
            for (index, original) in sequence.steps.enumerated() {
                let continuous = index > 0 && !SequenceSceneTransition.requiresBoardChange(
                    after: sequence.steps[index - 1].after, before: original.before)
                let oldBefore = continuous ? oldBoard ?? original.before : original.before
                let newBefore = continuous ? newBoard ?? original.before : original.before
                let captured = try XCTUnwrap(PositionPlayShotSolver.solve(before: original.before,
                    shot: original.shot, surfaceY: BTTablePhysics.surfaceY))
                var step = original; step.recordedDirection = captured.recordedDirection
                let old = try XCTUnwrap(PositionPlayShotSolver.solve(before: oldBefore,
                    shot: original.shot, surfaceY: BTTablePhysics.surfaceY))
                let new = try XCTUnwrap(SequenceReplayResolver.solve(step: step, before: newBefore,
                    surfaceY: BTTablePhysics.surfaceY))
                let label = "\(file.lastPathComponent) #\(index + 1) continuous=\(continuous)"
                XCTAssertTrue(old.hasFinalTableState, label)
                XCTAssertTrue(new.hasFinalTableState, label)
                if file.lastPathComponent.hasPrefix("drill_c") {
                    XCTAssertEqual(try fingerprint(new), try fingerprint(old), label)
                } else if try fingerprint(new) != fingerprint(old) {
                    let delta = try difference(old, new)
                    print("DIRECTION-LEGACY-DRAFT", label, "maxStopMM", delta.0, "maxSampleMM", delta.1)
                }
                oldBoard = settledBoard(old, before: oldBefore, shot: step.shot)
                newBoard = settledBoard(new, before: newBefore, shot: step.shot)
                if continuous { links += 1 }
            }
        }
        print("DIRECTION-CONTINUOUS links=\(links)")
    }

    func testMissingOrInvalidDirectionNeverFallsBackToAimSolver() throws {
        var step = try XCTUnwrap(sources().first(where: { !$0.1.steps.isEmpty })?.1.steps.first)
        for invalid: RecordedStrikeDirection? in [nil, .init(x: 0, z: 0), .init(x: .nan, z: 1), .init(x: 2, z: 0)] {
            step.recordedDirection = invalid
            let result = try XCTUnwrap(SequenceReplayResolver.solve(step: step, surfaceY: BTTablePhysics.surfaceY))
            XCTAssertFalse(result.feasible)
            XCTAssertNil(result.recorder)
        }
    }
}


extension SequenceDirectionMigrationTests {
    private func difference(_ a: ShotPrediction, _ b: ShotPrediction) throws -> (Float, Float) {
        let pa = TrajectoryPlayback(recorder: try XCTUnwrap(a.recorder), surfaceY: BTTablePhysics.surfaceY + BallPhysics.radius)
        let pb = TrajectoryPlayback(recorder: try XCTUnwrap(b.recorder), surfaceY: BTTablePhysics.surfaceY + BallPhysics.radius)
        var stop: Float = 0, sample: Float = 0
        func distance(_ x: SCNVector3, _ y: SCNVector3) -> Float {
            sqrtf(powf(x.x-y.x,2)+powf(x.y-y.y,2)+powf(x.z-y.z,2))*1000
        }
        for (name, point) in a.finalPositions {
            stop = max(stop, distance(point, try XCTUnwrap(b.finalPositions[name])))
            for i in 0...Int(ceil(max(pa.duration,pb.duration)*120)) {
                let time = Float(i)/120
                if let x = pa.stateAt(ballName:name,time:time), let y = pb.stateAt(ballName:name,time:time) {
                    sample = max(sample,distance(x.position,y.position))
                }
            }
        }
        return (stop,sample)
    }
    func testDiagnoseCrossProcessBaselineDifferences() throws {
        let reference = try JSONDecoder().decode([String:[String]].self,from:Data(contentsOf:evidence.appendingPathComponent("reference.json")))
        for (file, sequence) in try sources() where file.lastPathComponent.hasPrefix("drill_c031") || file.lastPathComponent.hasPrefix("drill_c060") {
            for (index, step) in sequence.steps.enumerated() where (file.lastPathComponent.hasPrefix("drill_c031") && index < 2) || (file.lastPathComponent.hasPrefix("drill_c060") && index == 7) {
                let base = try XCTUnwrap(PositionPlayShotSolver.solve(before:step.before,shot:step.shot,surfaceY:BTTablePhysics.surfaceY))
                var hashes = Set<String>(), matched = false
                var maxStop: Float = 0, maxSample: Float = 0
                for _ in 0..<60 {
                    var board = BoardSnapshot()
                    for key in step.before.onTable.keys.shuffled() { board.onTable[key] = step.before.onTable[key] }
                    let prediction = try XCTUnwrap(PositionPlayShotSolver.solve(before:board,shot:step.shot,surfaceY:BTTablePhysics.surfaceY))
                    let hash = try fingerprint(prediction); hashes.insert(hash)
                    if hash == reference[file.lastPathComponent]?[index] { matched = true }
                    let delta = try difference(base,prediction)
                    maxStop = max(maxStop,delta.0); maxSample = max(maxSample,delta.1)
                }
                print("DIRECTION-DIAG",file.lastPathComponent,index+1,"variants",hashes.count,"matchedBaseline",matched,"maxStopMM",maxStop,"maxSampleMM",maxSample)
            }
        }
    }
}


extension SequenceDirectionMigrationTests {
    func testMigratedResourcesContainExactDirectionsAndUnchangedContent() throws {
        let root = evidence.deletingLastPathComponent().deletingLastPathComponent()
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        var count = 0
        var maximumDecodedStopMM: Float = 0, maximumDecodedSampleMM: Float = 0
        for (file, original) in try sources() {
            let path = root.appendingPathComponent("content/position_play/sequences").appendingPathComponent(file.lastPathComponent)
            let data = try Data(contentsOf: path)
            let sequence = try decoder.decode(PositionPlaySequence.self, from: data)
            XCTAssertEqual(sequence.steps.count, original.steps.count)
            for (old, step) in zip(original.steps, sequence.steps) {
                let p = try XCTUnwrap(PositionPlayShotSolver.solve(before: old.before, shot: old.shot, surfaceY: BTTablePhysics.surfaceY))
                // Hold dictionary enumeration fixed when comparing the two execution paths.
                // Independent JSON decodes can vary existing simultaneous-event rounding.
                let replay = try XCTUnwrap(SequenceReplayResolver.solve(step: step, before: old.before,
                    surfaceY: BTTablePhysics.surfaceY))
                XCTAssertEqual(try fingerprint(replay), try fingerprint(p), file.lastPathComponent)
                XCTAssertEqual(step.recordedDirection?.x.bitPattern, p.recordedDirection?.x.bitPattern)
                XCTAssertEqual(step.recordedDirection?.z.bitPattern, p.recordedDirection?.z.bitPattern)
                let decodedReplay = try XCTUnwrap(SequenceReplayResolver.solve(step: step, surfaceY: BTTablePhysics.surfaceY))
                XCTAssertEqual(Set(decodedReplay.pocketedBalls), Set(p.pocketedBalls), file.lastPathComponent)
                let delta = try difference(p, decodedReplay)
                maximumDecodedStopMM = max(maximumDecodedStopMM, delta.0)
                maximumDecodedSampleMM = max(maximumDecodedSampleMM, delta.1)
                XCTAssertLessThanOrEqual(delta.0, 0.001, file.lastPathComponent)
                XCTAssertLessThanOrEqual(delta.1, 0.001, file.lastPathComponent)
                count += 1
            }
            if file.lastPathComponent.hasPrefix("drill_c") {
                let bundled = try XCTUnwrap(Bundle.main.resourceURL).appendingPathComponent("DrillBoards").appendingPathComponent(file.lastPathComponent)
                XCTAssertEqual(try Data(contentsOf: bundled), data, file.lastPathComponent)
            }
        }
        XCTAssertEqual(count, 639)
        print("DIRECTION-MIGRATED sourceShots=639 bundleShots=629 sameInputExact=true decodedStopMM=\(maximumDecodedStopMM) decodedSampleMM=\(maximumDecodedSampleMM)")
    }
}


extension SequenceCurrentEngineReplayTests {
    func testRecordedDirectionIsRequiredAndFreeAimIntentCannotOverrideIt() throws {
        var step = try XCTUnwrap(DrillTryoutBoardStore.formations(for: "drill_c001").first?.steps.first)
        for invalid: RecordedStrikeDirection? in [nil, .init(x: 0, z: 0), .init(x: .infinity, z: 0), .init(x: 2, z: 0)] {
            step.recordedDirection = invalid
            let p = try XCTUnwrap(SequenceReplayResolver.solve(step: step, surfaceY: BTTablePhysics.surfaceY))
            XCTAssertFalse(p.feasible)
            XCTAssertNil(p.recorder)
        }
        let before = BoardSnapshot(onTable: [PositionPlayBall.cueKey: .init(x: 0.4, y: 0.25)])
        let shot = PlannedShot(targetKey: "", pocket: "", velocity: 0.45, freeAim: .init(x: 1, y: 0))
        let original = try XCTUnwrap(PositionPlayShotSolver.solve(before: before, shot: shot, surfaceY: BTTablePhysics.surfaceY))
        var free = SequenceStep(before: before, shot: shot, after: before, recordedDirection: original.recordedDirection)
        free.shot.freeAim = .init(x: -1, y: 0)
        let replay = try XCTUnwrap(SequenceReplayResolver.solve(step: free, surfaceY: BTTablePhysics.surfaceY))
        XCTAssertEqual(replay.strikeDirection?.x.bitPattern, original.strikeDirection?.x.bitPattern)
        XCTAssertEqual(replay.strikeDirection?.z.bitPattern, original.strikeDirection?.z.bitPattern)
        XCTAssertEqual(replay.finalPositions[ShotInput.cueBallName]?.x, original.finalPositions[ShotInput.cueBallName]?.x)
        XCTAssertEqual(replay.finalPositions[ShotInput.cueBallName]?.z, original.finalPositions[ShotInput.cueBallName]?.z)
    }
}

/// Metadata migration audit. Never writes production resources from XCTest.
final class ShotAnalysisMigrationTests: XCTestCase {
    private var root: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent() }
    private var evidence: URL { root.appendingPathComponent("output/shot-analysis-20261015") }
    private func sources() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("content/position_play/sequences"), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
    private func decode(_ file: URL) throws -> PositionPlaySequence {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PositionPlaySequence.self, from: Data(contentsOf: file))
    }
    private struct Reference: Codable {
        let potted: [String]
        let samples: [String: [[Float]]]
        let stops: [String: [Float]]
    }
    private func reference(_ p: ShotPrediction) throws -> Reference {
        let recorder = try XCTUnwrap(p.recorder)
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: BTTablePhysics.surfaceY + BallPhysics.radius)
        var samples: [String: [[Float]]] = [:]
        for name in recorder.framesByBallName.keys.sorted() {
            samples[name] = (0...Int(ceil(p.duration * 120))).compactMap { i in
                guard let s = playback.stateAt(ballName: name, time: min(Float(i)/120, p.duration)) else { return nil }
                return [s.position.x, s.position.y, s.position.z]
            }
        }
        return Reference(potted: p.pocketedBalls.sorted(), samples: samples,
            stops: p.finalPositions.mapValues { [$0.x, $0.y, $0.z] })
    }
    func testCaptureAnalysisBaseline() throws {
        guard FileManager.default.fileExists(atPath: evidence.appendingPathComponent("capture-request").path) else {
            throw XCTSkip("Explicit local baseline capture only")
        }
        var result: [String: [Reference]] = [:]
        for file in try sources() {
            result[file.lastPathComponent] = try decode(file).steps.map { step in
                let p = try XCTUnwrap(SequenceReplayResolver.solve(step: step, surfaceY: BTTablePhysics.surfaceY))
                XCTAssertTrue(p.feasible); XCTAssertTrue(p.hasFinalTableState)
                return try reference(p)
            }
        }
        try JSONEncoder().encode(result).write(to: evidence.appendingPathComponent("replay-before.json"), options: .withoutOverwriting)
        print("ANALYSIS BASELINE files=\(result.count) shots=\(result.values.reduce(0) { $0+$1.count })")
    }
}

extension ShotAnalysisMigrationTests {
    private struct Entry: Codable { let id: UUID; let analysis: ShotAnalysis }

    func testGenerateAnalysisAndComparePreChangePlayback() throws {
        guard FileManager.default.fileExists(atPath: evidence.appendingPathComponent("generate-request").path) else {
            throw XCTSkip("Explicit local migration plan only")
        }
        let baseline = try JSONDecoder().decode([String: [Reference]].self,
            from: Data(contentsOf: evidence.appendingPathComponent("replay-before.json")))
        var plan: [String: [Entry]] = [:]
        var total = 0, contacts = 0
        var maxDelta: Float = 0, maxStopDelta: Float = 0, maxTableDelta: Float = 0
        var maxDetail: [String: Any] = [:]
        for file in try sources() {
            let sequence = try decode(file)
            let expected = try XCTUnwrap(baseline[file.lastPathComponent])
            XCTAssertEqual(sequence.steps.count, expected.count)
            var entries: [Entry] = []
            for (index, step) in sequence.steps.enumerated() {
                let label = "\(file.lastPathComponent):\(index+1)"
                let p = try XCTUnwrap(SequenceReplayResolver.solve(step: step, surfaceY: BTTablePhysics.surfaceY), label)
                XCTAssertTrue(p.hasFinalTableState, label)
                let analysis = try XCTUnwrap(ShotAnalysis.make(prediction: p, shot: step.shot, before: step.before), label)
                XCTAssertTrue(analysis.cueTravelDistanceMeters.isFinite)
                XCTAssertGreaterThanOrEqual(analysis.cueTravelDistanceMeters, 0)
                if let impact = analysis.firstContact {
                    contacts += 1
                    XCTAssertNotNil(step.before.onTable[impact.ballKey], label)
                    if let angle = impact.actualCutAngleDegrees { XCTAssertTrue((0...180).contains(angle), label) }
                }
                let actual = try reference(p), old = expected[index]
                XCTAssertEqual(actual.potted, old.potted, label)
                XCTAssertEqual(Set(actual.samples.keys), Set(old.samples.keys), label)
                for key in old.samples.keys {
                    let a = try XCTUnwrap(actual.samples[key]), b = old.samples[key]!
                    XCTAssertEqual(a.count, b.count, label)
                    for (sampleIndex, pair) in zip(a,b).enumerated() {
                        let pocketed = p.recorder!.isBallPocketed(key, at: Double(sampleIndex)/120)
                        for (axis, values) in zip(pair.0,pair.1).enumerated() {
                            let delta = abs(values.0-values.1)
                            if !pocketed { maxTableDelta = max(maxTableDelta,delta) }
                            if delta > maxDelta {
                                maxDelta = delta
                                maxDetail = ["shot":label,"ball":key,"sample":sampleIndex,"axis":axis,"old":values.1,"new":values.0,"pocketed":pocketed]
                            }
                        }
                    }
                }
                for key in old.stops.keys {
                    let a = try XCTUnwrap(actual.stops[key]), b = old.stops[key]!
                    for (x,y) in zip(a,b) {
                        maxStopDelta = max(maxStopDelta,abs(x-y))
                        if !actual.potted.contains(key) { maxTableDelta = max(maxTableDelta,abs(x-y)) }
                    }
                }
                entries.append(Entry(id: step.id, analysis: analysis)); total += 1
            }
            plan[file.lastPathComponent] = entries
        }
        // Existing dictionary-order roundoff: table motion and live stops retain the
        // direction-migration 1 µm bound. Pocket tails amplify it slightly in Y.
        // Raw endpoints of already-potted balls are NOT table stops: legacy-pocket.log
        // reproduces boundary-vs-pocket-centre representation with the ORIGINAL engine.
        // Same-input, metadata-present/absent parity below still requires exact bits.
        XCTAssertLessThanOrEqual(maxTableDelta, 0.000001)
        XCTAssertLessThanOrEqual(maxDelta, 0.00001)
        XCTAssertEqual(total, 639); XCTAssertEqual(plan.count, 103)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode(plan).write(to: evidence.appendingPathComponent("migration-plan.json"), options: .withoutOverwriting)
        let report: [String: Any] = ["files":plan.count,"shots":total,"contacts":contacts,"maxPlaybackPositionDeltaMM":Double(maxDelta)*1000,"maxStopDeltaMM":Double(maxStopDelta)*1000,
            "maxTableDeltaMM":Double(maxTableDelta)*1000,"maxDetail":maxDetail]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted,.sortedKeys]).write(to: evidence.appendingPathComponent("parity.json"))
        print("ANALYSIS PARITY \(report)")
    }

    func testBundledAnalysisIsOptionalAndCannotAffectPlayback() throws {
        let directory = try XCTUnwrap(Bundle.main.resourceURL).appendingPathComponent("DrillBoards")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        var count = 0
        for file in files {
            for step in try decode(file).steps {
                XCTAssertNotNil(step.analysis, file.lastPathComponent)
                let p = try XCTUnwrap(SequenceReplayResolver.solve(step: step, surfaceY: BTTablePhysics.surfaceY))
                var missing = step; missing.analysis = nil
                let q = try XCTUnwrap(SequenceReplayResolver.solve(step: missing, surfaceY: BTTablePhysics.surfaceY))
                XCTAssertTrue(p.hasFinalTableState); XCTAssertTrue(q.hasFinalTableState)
                XCTAssertEqual(try encoder.encode(reference(p)), try encoder.encode(reference(q)))
                // Full engine frames include time, velocity, angular velocity and state.
                XCTAssertEqual(try signal(p), try signal(q))
                count += 1
            }
        }
        XCTAssertEqual(files.count, 98); XCTAssertEqual(count, 629)
        print("ANALYSIS BUNDLE 98 files / 629 shots: metadata present vs absent bit-identical")
    }

    private func signal(_ prediction: ShotPrediction) throws -> String {
        var bytes = Data()
        func scalar(_ x: Float) { var b = x.bitPattern; withUnsafeBytes(of:&b) { bytes.append(contentsOf:$0) } }
        let recorder = try XCTUnwrap(prediction.recorder)
        for key in recorder.framesByBallName.keys.sorted() {
            bytes.append(contentsOf:key.utf8)
            for f in recorder.framesByBallName[key]! {
                for value in [f.time,f.position.x,f.position.y,f.position.z,f.velocity.x,f.velocity.y,f.velocity.z,
                              f.angularVelocity.x,f.angularVelocity.y,f.angularVelocity.z,f.angularVelocity.w] { scalar(value) }
                bytes.append(contentsOf:f.state.rawValue.utf8)
            }
        }
        return SHA256.hash(data:bytes).description
    }
}

final class ShotAnalysisTests: XCTestCase {
    private func prediction(angle: Double, velocity: Float = 2) -> ShotPrediction {
        let recorder = TrajectoryRecorder(); recorder.hasPlanarAnalysisFacts = true
        let cue = BallState(position:SCNVector3Zero, velocity:SCNVector3(velocity,0,0),
            angularVelocity:SCNVector3(0,0,-velocity/BallPhysics.radius),state:.rolling,name:"cueBall")
        let radians = angle * .pi / 180
        let object = BallState(position:SCNVector3(Float(cos(radians))*2*BallPhysics.radius,0,Float(sin(radians))*2*BallPhysics.radius),
            velocity:SCNVector3Zero,angularVelocity:SCNVector3Zero,state:.stationary,name:"object")
        recorder.recordBallContact(time:0.2,a:cue,b:object)
        recorder.recordFrame(ballName:"cueBall",frame:BallFrame(time:0,position:cue.position,velocity:cue.velocity,
            angularVelocity:SCNVector4(0,0,cue.angularVelocity.z,0),state:.rolling))
        recorder.recordFrame(ballName:"cueBall",frame:BallFrame(time:1,position:SCNVector3(1,0,0),velocity:.init(),angularVelocity:.init(),state:.stationary))
        var p = ShotPrediction(); p.termination = .settled; p.recorder = recorder
        p.events = [ShotEvent(time:0.1,kind:.ballCushion(ball:"cueBall"),contactNormal:SCNVector3(1,0,0),cushionIndex:4),
                    ShotEvent(time:0.2,kind:.ballBall(ballA:"object",ballB:"cueBall")),
                    ShotEvent(time:0.2,kind:.ballCushion(ball:"cueBall"),contactNormal:SCNVector3(0,0,-1),cushionIndex:2),
                    ShotEvent(time:0.3,kind:.ballCushion(ball:"cueBall"),contactNormal:SCNVector3(1,0,0),cushionIndex:8)]
        return p
    }
    private var shot: PlannedShot { .init(targetKey:"_8",pocket:"topLeft",velocity:2) }
    func testContactAngleSpinUnitsRailOrderingAndRoundTrip() throws {
        for angle in [0.0,30,45,60,90] {
            let a = try XCTUnwrap(ShotAnalysis.make(prediction:prediction(angle:angle),shot:shot,before:BoardSnapshot()))
            let hit = try XCTUnwrap(a.firstContact)
            XCTAssertEqual(try XCTUnwrap(hit.actualCutAngleDegrees),angle,accuracy:0.00001)
            XCTAssertEqual(hit.ballKey,"_8"); XCTAssertEqual(hit.cueSpeedMetersPerSecond,2)
            XCTAssertEqual(try XCTUnwrap(hit.cueForwardRollRatio),1,accuracy:0.000001)
            XCTAssertEqual(hit.cueClothSlipSpeedMetersPerSecond,0,accuracy:0.000001)
            XCTAssertEqual(a.cueCushionContacts.map(\.phase),["beforeFirstContact","afterFirstContact","afterFirstContact"])
            XCTAssertEqual(a.cueCushionContacts.map(\.mainRail),["negativeX","positiveZ",nil])
            XCTAssertEqual(try JSONDecoder().decode(ShotAnalysis.self,from:JSONEncoder().encode(a)),a)
        }
    }
    func testUndefinedAnglesAndNoCollisionDoNotBecomeZero() throws {
        let still = try XCTUnwrap(ShotAnalysis.make(prediction:prediction(angle:0,velocity:0),shot:shot,before:BoardSnapshot()))
        XCTAssertNil(still.firstContact?.actualCutAngleDegrees)
        XCTAssertNil(still.firstContact?.cueForwardRollRatio)
        XCTAssertNotNil(still.firstContact?.undefinedAngleReason)
        let p = ShotPredictor.simulateFree(cueBall:SCNVector3(0,BTTablePhysics.surfaceY+BallPhysics.radius,0),
            aimDir:SCNVector3(1,0,0),velocity:0.3,spinX:0,spinY:0,surfaceY:BTTablePhysics.surfaceY,balls:[])
        let a = try XCTUnwrap(ShotAnalysis.make(prediction:p,shot:shot,before:BoardSnapshot()))
        XCTAssertNil(a.firstContact); XCTAssertEqual(a.noContactReason,"noCueBallCollision")
        XCTAssertGreaterThan(a.cueTravelDistanceMeters,0)
    }
    func testTravelDistanceIntegratesSpeedAndExcludesPocketSnap() throws {
        let p = prediction(angle:0), recorder = try XCTUnwrap(p.recorder)
        let frames = recorder.framesByBallName["cueBall"]!
        let expected = 2 - Double(SpinPhysics.rollingFriction * TablePhysics.gravity)/2
        XCTAssertEqual(ShotAnalysis.travelDistance(frames:frames,recorder:recorder),expected,accuracy:0.000001)
        let ball = BallState(position:SCNVector3(0.9,0,0),velocity:.init(),angularVelocity:.init(),state:.rolling,name:"cueBall")
        recorder.recordPocketEntry(ball:ball,pocketID:"pocket_0",time:0.5,source:.event,geometry:.chineseEightBallQiuJi(surfaceY:BTTablePhysics.surfaceY))
        let half = 1 - Double(SpinPhysics.rollingFriction * TablePhysics.gravity)*0.125
        XCTAssertEqual(ShotAnalysis.travelDistance(frames:frames,recorder:recorder),half,accuracy:0.000001)
    }
    func testIncompletePredictionDoesNotPublishAnalysisAndMalformedMetadataDoesNotBlockReplay() throws {
        var p = prediction(angle:45); p.termination = .timeLimit
        XCTAssertNil(ShotAnalysis.make(prediction:p,shot:shot,before:BoardSnapshot()))
        let step = try XCTUnwrap(DrillTryoutBoardStore.formations(for:"drill_c001").first?.steps.first)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(step)) as? [String:Any])
        json["analysis"] = ["schemaVersion":"unknown","firstContact":false]
        let decoded = try JSONDecoder().decode(SequenceStep.self,from:JSONSerialization.data(withJSONObject:json))
        XCTAssertNil(decoded.analysis)
        XCTAssertTrue(try XCTUnwrap(SequenceReplayResolver.solve(step:decoded,surfaceY:BTTablePhysics.surfaceY)).hasFinalTableState)
        json.removeValue(forKey:"analysis")
        let legacy = try JSONDecoder().decode(SequenceStep.self,from:JSONSerialization.data(withJSONObject:json))
        XCTAssertNil(legacy.analysis)
        XCTAssertEqual(legacy.recordedDirection?.x,step.recordedDirection?.x)
        XCTAssertTrue(try XCTUnwrap(SequenceReplayResolver.solve(step:legacy,surfaceY:BTTablePhysics.surfaceY)).hasFinalTableState)
    }
}

extension ShotAnalysisTests {
    func testAimAngleUsesPocketLineGhostNotCompensatedStrike() throws {
        let y = BTTablePhysics.surfaceY + BallPhysics.radius
        let target = SCNVector3(0,y,0)
        let pocketShot = PlannedShot(targetKey:"_8",pocket:"topCenter",velocity:2)
        func canvas(_ v: SCNVector3) -> CanvasPoint {
            let p = AngleSceneCalculator.sceneToNormalized(position:v)
            return .init(x:Double(p.x),y:Double(p.y))
        }
        for degrees in [0.0,30,45,60] {
            let radians = degrees * .pi/180
            let cue = SCNVector3(-0.3*Float(sin(radians)),y,2*BallPhysics.radius+0.3*Float(cos(radians)))
            let before = BoardSnapshot(onTable:["cueBall":canvas(cue),"_8":canvas(target)])
            var p = prediction(angle:45)
            p.cutAngleDeg = 123; p.ghost = SCNVector3(100,0,100); p.aimDirection = SCNVector3(-1,0,0)
            let analysis = try XCTUnwrap(ShotAnalysis.make(prediction:p,shot:pocketShot,before:before))
            let aim = try XCTUnwrap(analysis.aim)
            XCTAssertEqual(aim.aimAngleDegrees,degrees,accuracy:0.0001)
            XCTAssertEqual(aim.ghostCenterMeters.x,0,accuracy:0.000001)
            XCTAssertEqual(aim.ghostCenterMeters.z,Double(2*BallPhysics.radius),accuracy:0.000001)
            XCTAssertEqual(try XCTUnwrap(analysis.firstContact?.actualCutAngleDegrees),45,accuracy:0.00001)
            var free = pocketShot; free.freeAim = .init(x:1,y:0)
            let freeAnalysis = try XCTUnwrap(ShotAnalysis.make(prediction:p,shot:free,before:before))
            XCTAssertNil(freeAnalysis.aim)
            XCTAssertEqual(freeAnalysis.noAimReason,"freeAimHasNoPocketLine")
        }
    }

    func testRealEngineCapturesIncomingStateBeforeImpulse() throws {
        let y = BTTablePhysics.surfaceY + BallPhysics.radius
        let p = ShotPredictor.simulateFree(cueBall:SCNVector3(-0.2,y,0),aimDir:SCNVector3(1,0,0),
            velocity:2,spinX:0,spinY:-0.3,surfaceY:BTTablePhysics.surfaceY,
            balls:[ObstacleBall(name:"_8",position:SCNVector3(0,y,0))])
        XCTAssertTrue(p.hasFinalTableState)
        let recorder = try XCTUnwrap(p.recorder), hit = try XCTUnwrap(recorder.firstBallContacts["cueBall"])
        let frame = try XCTUnwrap(recorder.framesByBallName["cueBall"]?.last(where:{$0.time < hit.time}))
        XCTAssertEqual(frame.state,.sliding)
        let expected = AnalyticalMotion.evolveSliding(position:frame.position,velocity:frame.velocity,
            angularVelocity:SCNVector3(frame.angularVelocity.x,frame.angularVelocity.y,frame.angularVelocity.z),dt:hit.time-frame.time)
        XCTAssertEqual(hit.incoming.velocity.x,expected.velocity.x,accuracy:0.000001)
        XCTAssertEqual(hit.incoming.angularVelocity.z,expected.angularVelocity.z,accuracy:0.00001)
        let a = try XCTUnwrap(ShotAnalysis.make(prediction:p,shot:.init(targetKey:"",pocket:"",velocity:2,freeAim:.init(x:1,y:0)),before:.init()))
        XCTAssertEqual(a.firstContact?.ballKey,"_8")
        let normal = hit.other.position - hit.incoming.position, velocity = hit.incoming.velocity
        let independentlyMeasured = atan2(abs(Double(velocity.x)*Double(normal.z)-Double(velocity.z)*Double(normal.x)),
            Double(velocity.x)*Double(normal.x)+Double(velocity.z)*Double(normal.z))*180/Double.pi
        XCTAssertEqual(try XCTUnwrap(a.firstContact?.actualCutAngleDegrees),independentlyMeasured,accuracy:0.000001)
        XCTAssertLessThan(independentlyMeasured,0.0001) // Float contact placement, not a mathematically exact normal.
        XCTAssertLessThan(try XCTUnwrap(a.firstContact?.cueForwardRollRatio),0)
    }
}

extension ShotAnalysisMigrationTests {
    func testDiagnoseLegacyPocketEndpointRepresentation() throws {
        guard FileManager.default.fileExists(atPath:evidence.appendingPathComponent("legacy-diagnostic-request").path) else {
            throw XCTSkip("Explicit pre-instrumentation diagnostic only")
        }
        let baseline = try JSONDecoder().decode([String:[Reference]].self,from:Data(contentsOf:evidence.appendingPathComponent("replay-before.json")))
        var differences: [[String:Any]] = []
        var maxTableDelta: Float = 0
        for file in try sources() {
            for (index,step) in try decode(file).steps.enumerated() {
                let p = try XCTUnwrap(SequenceReplayResolver.solve(step:step,surfaceY:BTTablePhysics.surfaceY))
                let recorder = try XCTUnwrap(p.recorder)
                XCTAssertFalse(recorder.hasPlanarAnalysisFacts,"Must run the original engine without the observation hook")
                let actual = try reference(p), old = baseline[file.lastPathComponent]![index]
                XCTAssertEqual(actual.potted,old.potted)
                for (name,stop) in actual.stops {
                    let expected = try XCTUnwrap(old.stops[name])
                    let delta = zip(stop,expected).map { abs($0-$1) }.max() ?? 0
                    if p.pocketedBalls.contains(name), delta > 0.000001 {
                        differences.append(["file":file.lastPathComponent,"shot":index+1,"ball":name,
                            "deltaMM":Double(delta)*1000,"old":expected,"new":stop,
                            "entrySource":String(describing:recorder.pocketEntries.first(where:{$0.ball.name==name})?.source)])
                    } else if !p.pocketedBalls.contains(name) { maxTableDelta = max(maxTableDelta,delta) }
                }
                for (name,samples) in actual.samples {
                    for (sampleIndex,pair) in zip(samples,old.samples[name]!).enumerated() {
                        if recorder.isBallPocketed(name,at:Double(sampleIndex)/120) { continue }
                        for (a,b) in zip(pair.0,pair.1) { maxTableDelta = max(maxTableDelta,abs(a-b)) }
                    }
                }
            }
        }
        XCTAssertLessThanOrEqual(maxTableDelta,0.000001)
        let report:[String:Any] = ["uninstrumentedEngine":true,"maxTableDeltaMM":Double(maxTableDelta)*1000,"pocketedRawEndpointDifferences":differences]
        try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:evidence.appendingPathComponent("legacy-pocket-diagnostic.json"))
        print("LEGACY-POCKET-DIAGNOSTIC \(report)")
    }
}
