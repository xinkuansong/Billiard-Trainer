//
//  ScoringOnlyConsistencyTests.swift
//  QiuJiTests
//
//  B1 — scoring-only + 引擎早停「不改物理」逐条验证
//  （docs/research/20260708-反解求解器性能优化方案.md §3 B1 完成标准）。
//
//  验证两件事：
//  1. `predictForPositionSolve(includePresentation: false)`（scoring-only + 早停）与
//     默认全保真路径在**求解器消费的全部物理量**上逐条一致：进袋/吃库/母球末速/
//     母球与目标球终位。早停判据是保守的（兴趣球停稳且残余运动能量预算不可能触及），
//     事件序列在早停点前逐位相同 ⇒ 应精确相等（Float 容差仅防跨平台舍入）。
//  2. `simulateFree` 的 scoring-only + earlyStopBallNames 对斯诺克三兴趣球
//     （母球/目标球/blocker）同样成立。
//

import XCTest
import SceneKit
@testable import QiuJi

final class ScoringOnlyConsistencyTests: XCTestCase {

    private let sY = BTTablePhysics.surfaceY
    private let eps: Float = 1e-5

    private func scene(_ x: Double, _ y: Double) -> SCNVector3 {
        PositionPlaySolver.scenePoint(CanvasPoint(x: x, y: y), surfaceY: sY)
    }

    /// 多球盘面 × 塞/力度网格：scoring-only 与全保真的求解器消费量逐条一致。
    func test_positionSolve_scoringOnly_matchesFullPhysics() {
        let cue = scene(0.50, 0.35)
        let target = scene(0.50, 0.15)
        let obstacles: [ObstacleBall] = [
            ObstacleBall(name: "_2", position: scene(0.25, 0.30)),
            ObstacleBall(name: "_3", position: scene(0.75, 0.28)),
            ObstacleBall(name: "_5", position: scene(0.68, 0.40)),
            ObstacleBall(name: "_8", position: scene(0.85, 0.15)),
        ]
        guard let pocketIndex = ShotIntent.pocketIndex(for: "topCenter") else {
            return XCTFail("袋口名非法")
        }

        var compared = 0
        for spinX: Float in [-0.3, 0, 0.3] {
            for spinY: Float in [-0.4, 0, 0.4] {
                for velocity: Float in [0.9, 1.8, 2.7, 3.6, 4.5, 5.4] {
                    let input = ShotInput(
                        cueBall: cue, targetBall: target, pocketIndex: pocketIndex,
                        velocity: velocity, spinX: spinX, spinY: spinY,
                        surfaceY: sY, obstacles: obstacles
                    )
                    let full = ShotPredictor.predictForPositionSolve(input)
                    let scoring = ShotPredictor.predictForPositionSolve(input, includePresentation: false)
                    guard full.feasible else { continue }
                    compared += 1
                    let tag = "spin=(\(spinX),\(spinY)) v=\(velocity)"
                    XCTAssertTrue(full.hasFinalTableState, "Full simulation incomplete @\(tag): \(String(describing: full.termination))")
                    if !full.hasFinalTableState, let recorder = full.recorder {
                        for name in recorder.framesByBallName.keys.sorted() {
                            print("[W07 incomplete] \(tag) \(name) tail=\(Array(recorder.framesByBallName[name]!.suffix(2))) local=\(String(describing: recorder.localIntervalsByBallName[name]?.last))")
                        }
                    }
                    XCTAssertTrue(scoring.hasResolvedSearchState, "Search incomplete @\(tag): \(String(describing: scoring.termination))")

                    // 同一瞄准（同为确定性黄金分割解）。
                    XCTAssertEqual(full.aimOffsetUsed!, scoring.aimOffsetUsed!, accuracy: eps,
                                   "aimOffset 漂移 @\(tag)")
                    // 判定量逐条一致。
                    XCTAssertEqual(full.objectPocketed, scoring.objectPocketed, "objectPocketed @\(tag)")
                    XCTAssertEqual(full.cuePocketed, scoring.cuePocketed, "cuePocketed @\(tag)")
                    XCTAssertEqual(full.cueCushionCount, scoring.cueCushionCount, "cueCushionCount @\(tag)")
                    XCTAssertEqual(full.cueCushionsBeforeContact, scoring.cueCushionsBeforeContact,
                                   "cueCushionsBeforeContact @\(tag)")
                    XCTAssertEqual(full.objectCushionCount, scoring.objectCushionCount,
                                   "objectCushionCount @\(tag)")
                    XCTAssertEqual(full.cueFinalSpeed, scoring.cueFinalSpeed, accuracy: eps,
                                   "cueFinalSpeed @\(tag)")
                    if abs(full.cueFinalSpeed-scoring.cueFinalSpeed) > eps {
                        for (label, prediction) in [("full", full), ("scoring", scoring)] {
                            let frames = prediction.recorder?.framesByBallName[ShotInput.cueBallName] ?? []
                            print("[W07 scoring mismatch] \(tag) \(label) termination=\(String(describing: prediction.termination)) tail=\(Array(frames.suffix(3)))")
                        }
                    }
                    // 兴趣球终位一致（早停保守判据的核心承诺）。
                    for name in [ShotInput.cueBallName, ShotInput.targetBallName] {
                        let a = full.finalPositions[name]
                        let b = scoring.finalPositions[name]
                        XCTAssertEqual(a != nil, b != nil, "finalPositions[\(name)] 存在性 @\(tag)")
                        if let a, let b {
                            XCTAssertEqual(a.x, b.x, accuracy: eps, "\(name).x @\(tag)")
                            XCTAssertEqual(a.z, b.z, accuracy: eps, "\(name).z @\(tag)")
                        }
                    }
                    // scoring-only 确实跳过了展示量（防回归为全量后处理）。
                    XCTAssertTrue(scoring.cuePath.isEmpty && scoring.objectPath.isEmpty,
                                  "scoring-only 不应产出轨迹折线 @\(tag)")
                }
            }
        }
        XCTAssertGreaterThan(compared, 30, "有效对比样本过少，网格设置有误")
        print("[B1] positionSolve scoring-only 已比较样本 = \(compared)")
    }

    /// 斯诺克自由模拟：scoring-only + 三兴趣球早停 vs 全保真，兴趣球结果逐条一致。
    func test_simulateFree_earlyStop_matchesFullPhysics_forInterestBalls() {
        let cue = scene(0.30, 0.25)
        let balls: [ObstacleBall] = [
            ObstacleBall(name: "_1", position: scene(0.55, 0.25)),
            ObstacleBall(name: "_8", position: scene(0.50, 0.22)),
            ObstacleBall(name: "_4", position: scene(0.70, 0.35)),
            ObstacleBall(name: "_6", position: scene(0.20, 0.12)),
        ]
        let interest: Set<String> = [ShotInput.cueBallName, "_1", "_8"]

        var compared = 0
        for offDeg: Float in [-3, -1, 0, 1, 3] {
            for velocity: Float in [0.8, 1.6, 2.6, 3.8] {
                let ang = atan2f(scene(0.55, 0.25).z - cue.z, scene(0.55, 0.25).x - cue.x)
                    + offDeg * .pi / 180
                let aimDir = SCNVector3(cosf(ang), 0, sinf(ang))
                let full = ShotPredictor.simulateFree(
                    cueBall: cue, aimDir: aimDir, velocity: velocity,
                    spinX: 0.2, spinY: -0.2, surfaceY: sY, balls: balls)
                let scoring = ShotPredictor.simulateFree(
                    cueBall: cue, aimDir: aimDir, velocity: velocity,
                    spinX: 0.2, spinY: -0.2, surfaceY: sY, balls: balls,
                    includePresentation: false, earlyStopBallNames: interest)
                compared += 1
                let tag = "off=\(offDeg)° v=\(velocity)"
                XCTAssertTrue(full.hasFinalTableState, "Full simulation incomplete @\(tag): \(String(describing: full.termination))")
                XCTAssertTrue(scoring.hasResolvedSearchState, "Search incomplete @\(tag): \(String(describing: scoring.termination))")

                XCTAssertEqual(full.cuePocketed, scoring.cuePocketed, "cuePocketed @\(tag)")
                XCTAssertEqual(full.cueFinalSpeed, scoring.cueFinalSpeed, accuracy: eps,
                               "cueFinalSpeed @\(tag)")
                for name in interest {
                    XCTAssertEqual(full.pocketedBalls.contains(name),
                                   scoring.pocketedBalls.contains(name),
                                   "pocketed[\(name)] @\(tag)")
                    let a = full.finalPositions[name]
                    let b = scoring.finalPositions[name]
                    XCTAssertEqual(a != nil, b != nil, "finalPositions[\(name)] 存在性 @\(tag)")
                    if let a, let b, !scoring.pocketedBalls.contains(name) {
                        XCTAssertEqual(a.x, b.x, accuracy: eps, "\(name).x @\(tag)")
                        XCTAssertEqual(a.z, b.z, accuracy: eps, "\(name).z @\(tag)")
                    }
                }
                // 母球首触对象一致（斯诺克合法首触硬约束的消费量）。
                func firstTouch(_ p: ShotPrediction) -> String? {
                    for e in p.events {
                        if case let .ballBall(a, b) = e.kind {
                            if a == ShotInput.cueBallName { return b }
                            if b == ShotInput.cueBallName { return a }
                        }
                    }
                    return nil
                }
                XCTAssertEqual(firstTouch(full), firstTouch(scoring), "首触对象 @\(tag)")
                // 母球吃库数一致。
                func cueCushions(_ p: ShotPrediction) -> Int {
                    p.events.reduce(0) { acc, e in
                        if case let .ballCushion(ball) = e.kind, ball == ShotInput.cueBallName {
                            return acc + 1
                        }
                        return acc
                    }
                }
                XCTAssertEqual(cueCushions(full), cueCushions(scoring), "母球吃库数 @\(tag)")
            }
        }
        print("[B1] simulateFree 早停已比较样本 = \(compared)")
    }
}


extension ScoringOnlyConsistencyTests {
    func test_presentationSpinTail_matchesUnboundedPlanarReference() throws {
        func makeEngine() -> EventDrivenEngine {
            let engine = EventDrivenEngine(tableGeometry: .chineseEightBallQiuJi(surfaceY: sY))
            for (index, spin) in [Float(20), -40].enumerated() {
                engine.setBall(BallState(position: SCNVector3(Float(index) * 0.4, sY + BallPhysics.radius, 0),
                    velocity: SCNVector3Zero, angularVelocity: SCNVector3(0, spin, 0),
                    state: .spinning, name: "spin\(index)"))
            }
            return engine
        }
        let bounded = makeEngine(), reference = makeEngine()
        let stop = bounded.simulatePrediction(model: .appDefault, maxTime: 1)
        XCTAssertEqual(stop, .timeLimit)
        XCTAssertEqual(bounded.currentTime, 1)
        XCTAssertEqual(bounded.completePlanarSpinTail(after: stop, surfaceY: sY), .settled)
        XCTAssertEqual(reference.simulate(maxTime: 10), .settled)
        XCTAssertEqual(bounded.currentTime, reference.currentTime, accuracy: 1e-5)
        let actual = TrajectoryPlayback(recorder: bounded.getTrajectoryRecorder(), surfaceY: sY + BallPhysics.radius)
        let expected = TrajectoryPlayback(recorder: reference.getTrajectoryRecorder(), surfaceY: sY + BallPhysics.radius)
        for name in ["spin0", "spin1"] {
            for time in stride(from: Float(0), through: bounded.currentTime, by: Float(0.1)) {
                let a = try XCTUnwrap(actual.stateAt(ballName: name, time: time))
                let b = try XCTUnwrap(expected.stateAt(ballName: name, time: time))
                XCTAssertEqual(a.position.x, b.position.x, accuracy: 1e-6)
                XCTAssertEqual(a.position.z, b.position.z, accuracy: 1e-6)
                XCTAssertEqual(a.angularVelocity.y, b.angularVelocity.y, accuracy: 1e-4)
            }
        }
    }

    func test_presentationSpinTail_preservesIncompleteMotionAndEventLimit() {
        for moving in [true, false] {
            let engine = EventDrivenEngine(tableGeometry: .chineseEightBallQiuJi(surfaceY: sY))
            engine.setBall(BallState(position: SCNVector3(0, sY + BallPhysics.radius, 0),
                velocity: moving ? SCNVector3(1, 0, 0) : SCNVector3Zero,
                angularVelocity: SCNVector3(0, 20, 0),
                state: moving ? .sliding : .spinning, name: "cue"))
            let reason: EventDrivenEngine.Termination = moving ? .timeLimit : .eventLimit
            XCTAssertEqual(engine.completePlanarSpinTail(after: reason, surfaceY: sY), reason)
            XCTAssertEqual(engine.currentTime, 0)
            XCTAssertEqual(engine.getTrajectoryRecorder().duration, 0)
        }
    }
}


extension ScoringOnlyConsistencyTests {
    func test_directAimCandidatePruning_preservesSelectedPrediction() throws {
        let pocket = try XCTUnwrap(ShotIntent.pocketIndex(for: "topCenter"))
        let middle = ShotInput(cueBall: scene(0.5, 0.35), targetBall: scene(0.5, 0.15),
            pocketIndex: pocket, velocity: 1.2, spinX: 0, spinY: 0, surfaceY: sY)
        var corner = middle
        corner.cueBall = scene(0.65, 0.32); corner.targetBall = scene(0.83, 0.13)
        corner.pocketIndex = try XCTUnwrap(ShotIntent.pocketIndex(for: "topRight"))
        var weak = middle; weak.velocity = 0.15
        var blocked = middle
        blocked.obstacles = [ObstacleBall(name: "_2", position: scene(0.5, 0.25))]
        _ = ShotPredictor.predict(middle) // Geometry initialization is not steady-state search time.
        var oldTime = 0.0, newTime = 0.0, compared = 0
        for (name, fixture) in [("middle", middle), ("corner", corner), ("weak", weak), ("blocked", blocked)] {
            for spin: Float in [-0.3, 0, 0.3] {
                var input = fixture; input.spinX = spin
                let begin = ProcessInfo.processInfo.systemUptime
                let baseline = ShotPredictor.predict(input, useAimCandidatePruning: false)
                let split = ProcessInfo.processInfo.systemUptime
                let pruned = ShotPredictor.predict(input, useAimCandidatePruning: true)
                let end = ProcessInfo.processInfo.systemUptime
                oldTime += split - begin; newTime += end - split; compared += 1
                let tag = "\(name), spin=\(spin)"
                XCTAssertEqual(pruned.feasible, baseline.feasible, tag)
                XCTAssertEqual(pruned.termination, baseline.termination, tag)
                XCTAssertEqual(pruned.aimDirection.x, baseline.aimDirection.x, tag)
                XCTAssertEqual(pruned.aimDirection.z, baseline.aimDirection.z, tag)
                XCTAssertEqual(pruned.simObjectPotted, baseline.simObjectPotted, tag)
                XCTAssertEqual(pruned.cuePocketed, baseline.cuePocketed, tag)
                XCTAssertEqual(pruned.cueFinalSpeed, baseline.cueFinalSpeed, tag)
                XCTAssertEqual(pruned.duration, baseline.duration, tag)
                // The chosen full simulation must remain identical, including
                // complete recorded states and rule-visible event chronology.
                for key in baseline.recorder?.framesByBallName.keys.sorted() ?? [] {
                    XCTAssertEqual(String(describing: pruned.recorder?.framesByBallName[key]),
                                   String(describing: baseline.recorder?.framesByBallName[key]), tag)
                }
                XCTAssertEqual(String(describing: pruned.events), String(describing: baseline.events), tag)
            }
        }
        XCTAssertEqual(compared, 12)
        print("[W07 pruning] compared=\(compared) baseline=\(oldTime)s pruned=\(newTime)s")
    }
}


extension ScoringOnlyConsistencyTests {
    func test_directCandidateRejection_respectsFirstBallContactBoundary() {
        for model: EventDrivenEngine.SimulationModel in [.planarReference, .spatialPockets] {
            for hasEarlierContact in [false, true] {
                let engine = EventDrivenEngine(tableGeometry: .chineseEightBallQiuJi(surfaceY: sY))
                engine.setBall(BallState(position: SCNVector3(0, sY + BallPhysics.radius, 0),
                    velocity: SCNVector3(1, 0, 0), angularVelocity: SCNVector3(0, 0, -1 / BallPhysics.radius),
                    state: .rolling, name: "cue"))
                if hasEarlierContact {
                    engine.setBall(BallState(position: SCNVector3(0.3, sY + BallPhysics.radius, 0),
                        velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero,
                        state: .stationary, name: "other"))
                }
                let termination = engine.simulatePrediction(model: model, maxTime: 15,
                    rejectCushionBeforeAnyContactFor: "cue")
                if hasEarlierContact {
                    XCTAssertNotEqual(termination, .candidateRejected)
                    XCTAssertTrue(engine.resolvedEvents.contains {
                        if case .ballBall = $0 { return true }; return false
                    })
                } else {
                    XCTAssertEqual(termination, .candidateRejected)
                    XCTAssertTrue(engine.resolvedEvents.contains {
                        if case .ballCushion(let name, _, _) = $0 { return name == "cue" }; return false
                    })
                    XCTAssertLessThan(engine.currentTime, 15)
                }
            }
        }
    }
}
