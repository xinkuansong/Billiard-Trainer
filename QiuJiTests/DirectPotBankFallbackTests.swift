import XCTest
import SceneKit
@testable import QiuJi

/// 直击失败 → 翻袋备选闸门与装配（复用 `BankKickSolvePipeline.solveBank`）。
final class DirectPotBankFallbackTests: XCTestCase {

    private let sY = BTTablePhysics.surfaceY
    private var R: Float { BallPhysics.radius }

    func test_cancelledBankSearchDiscardsWholeCatalog() {
        let cancellation = PredictionCancellation()
        cancellation.cancel()
        let result = DirectPotBankFallback.solveBankAlternatives(
            cue: SCNVector3(-0.5, sY + R, -0.2),
            object: SCNVector3(0.1, sY + R, 0.1), pocketIndex: 1,
            surfaceY: sY, power: 3.6, cancellation: cancellation)
        XCTAssertTrue(result.isEmpty)
    }

    func test_bankCancellationDuringSearchAndFreshRetry() {
        let cancellation = PredictionCancellation()
        let started = expectation(description: "background solve started")
        let finished = expectation(description: "cancelled search returned")
        let y = sY, r = R
        DispatchQueue.global(qos: .userInitiated).async {
            started.fulfill()
            let result = DirectPotBankFallback.solveBankAlternatives(
                cue: SCNVector3(-0.5, y + r, -0.2),
                object: SCNVector3(0.1, y + r, 0.1), pocketIndex: 1,
                surfaceY: y, power: 3.6,
                spinXValues: Array(repeating: 0, count: 100), cancellation: cancellation)
            XCTAssertTrue(result.isEmpty, "Cancellation must not return a partial catalog")
            finished.fulfill()
        }
        wait(for: [started], timeout: 5)
        cancellation.cancel()
        wait(for: [finished], timeout: 5)
        let fresh = DirectPotBankFallback.solveBankAlternatives(
            cue: SCNVector3(-0.5, y + r, -0.2),
            object: SCNVector3(0.1, y + r, 0.1), pocketIndex: 1,
            surfaceY: y, power: 3.6, spinXValues: [0], cancellation: PredictionCancellation())
        XCTAssertFalse(fresh.isEmpty, "Cancelling one request must not poison the next")
    }

    /// Same production search with/without a live token, then invalidate after 5 ms.
    /// Timings are diagnostic wall time, not a device energy measurement or a CI threshold.
    func test_bankCancellationCostComparison() {
        let cue = SCNVector3(-0.5, sY + R, -0.2)
        let object = SCNVector3(0.1, sY + R, 0.1)
        for trial in 0..<5 {
            let start = CACurrentMediaTime()
            let baseline = DirectPotBankFallback.solveBankAlternatives(
                cue: cue, object: object, pocketIndex: 1, surfaceY: sY, power: 3.6)
            let baselineMS = (CACurrentMediaTime() - start) * 1000
            let liveStart = CACurrentMediaTime()
            let live = DirectPotBankFallback.solveBankAlternatives(
                cue: cue, object: object, pocketIndex: 1, surfaceY: sY, power: 3.6,
                cancellation: PredictionCancellation())
            let liveMS = (CACurrentMediaTime() - liveStart) * 1000
            XCTAssertEqual(baseline.map(\.rails), live.map(\.rails))
            XCTAssertEqual(baseline.map(\.spinX), live.map(\.spinX))
            let token = PredictionCancellation()
            let cancelledStart = CACurrentMediaTime()
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.005) {
                token.cancel()
            }
            let cancelled = DirectPotBankFallback.solveBankAlternatives(
                cue: cue, object: object, pocketIndex: 1, surfaceY: sY, power: 3.6,
                cancellation: token)
            let cancelledMS = (CACurrentMediaTime() - cancelledStart) * 1000
            // A completed catalog is also legal if the full solve beats cancellation.
            XCTAssertTrue(cancelled.isEmpty || cancelled.count == baseline.count)
            print("BANK_CANCEL_COST trial=\(trial) baselineMS=\(baselineMS) liveMS=\(liveMS) cancelledMS=\(cancelledMS) returned=\(cancelled.count)")
        }
    }

    // MARK: - Gates

    func test_shouldAttemptBank_onlyWhenDirectInfeasible() {
        var bad = ShotPrediction()
        bad.feasible = false
        XCTAssertTrue(DirectPotBankFallback.shouldAttemptBank(afterDirect: bad))

        var ok = ShotPrediction()
        ok.feasible = true
        ok.simObjectPotted = false
        XCTAssertFalse(
            DirectPotBankFallback.shouldAttemptBank(afterDirect: ok),
            "直击几何可行时不跑翻袋（即使未进袋）"
        )
    }

    func test_isDirectPotInfeasible_matchesKnownObtuseLayout() {
        // 与 PhysicsEngineTests.test_predictor_infeasibleAngle_flagged 同盘面。
        let target = SCNVector3(0, sY + R, 0)
        let cue = SCNVector3(-0.2, sY + R, 0)
        XCTAssertTrue(
            DirectPotBankFallback.isDirectPotInfeasible(
                cue: cue, target: target, pocketIndex: 0, surfaceY: sY)
        )
        var input = ShotInput(
            cueBall: cue, targetBall: target, pocketIndex: 0,
            velocity: 3.0, spinX: 0, spinY: 0, surfaceY: sY
        )
        let pred = ShotPredictor.predict(input)
        XCTAssertFalse(pred.feasible)
        XCTAssertTrue(DirectPotBankFallback.shouldAttemptBank(afterDirect: pred))
    }

    func test_emptySolveMessage_distinguishesBankMiss() {
        let pos = "未找到解（试着放大区域或换目标袋口）"
        XCTAssertEqual(
            DirectPotBankFallback.emptySolveMessage(
                directInfeasible: true, bankAttempted: true, bankEmpty: true,
                positionHint: pos),
            "直击角度过大，且暂无翻袋备选（换袋口或移动球位）"
        )
        XCTAssertEqual(
            DirectPotBankFallback.emptySolveMessage(
                directInfeasible: false, bankAttempted: false, bankEmpty: false,
                positionHint: pos),
            pos
        )
    }

    // MARK: - Pipeline reuse

    func test_solveBankAlternatives_matchesPipelineOnTypicalBoard() {
        let cue = SCNVector3(-0.5, sY + R, -0.2)
        let object = SCNVector3(0.1, sY + R, 0.1)
        let viaFallback = DirectPotBankFallback.solveBankAlternatives(
            cue: cue, object: object, pocketIndex: 1, surfaceY: sY, power: 3.6,
            spinXValues: [0], cancellation: PredictionCancellation()
        )
        let viaPipeline = BankKickSolvePipeline.solveBank(
            cue: cue, object: object, pocketIndex: 1, surfaceY: sY, power: 3.6,
            spinXValues: [0]
        )
        XCTAssertEqual(viaFallback.count, viaPipeline.count)
        XCTAssertFalse(viaFallback.isEmpty, "典型翻袋盘面应有解")
        for (a, b) in zip(viaFallback, viaPipeline) {
            XCTAssertEqual(a.rails, b.rails)
            XCTAssertEqual(a.cushions, b.cushions)
            XCTAssertEqual(a.prediction.simObjectPotted, b.prediction.simObjectPotted)
        }
    }

    func test_asPositionPlaySolutions_marksUnsatisfiedConstraintAndBankPrefix() {
        let cue = SCNVector3(-0.5, sY + R, -0.2)
        let object = SCNVector3(0.1, sY + R, 0.1)
        let banks = DirectPotBankFallback.solveBankAlternatives(
            cue: cue, object: object, pocketIndex: 1, surfaceY: sY, power: 3.6,
            spinXValues: [0]
        )
        guard let first = banks.first else {
            XCTFail("典型盘面应有翻袋解"); return
        }
        let sols = DirectPotBankFallback.asPositionPlaySolutions(
            [first], targetKey: "solid_1", pocket: "topRight", velocity: 3.6)
        XCTAssertEqual(sols.count, 1)
        XCTAssertFalse(sols[0].satisfiesConstraint, "翻袋备选不得声称满足走位约束")
        XCTAssertTrue(sols[0].summary.hasPrefix("翻袋备选"))
        XCTAssertTrue(sols[0].potted)
        XCTAssertEqual(sols[0].shot.targetKey, "solid_1")
        XCTAssertEqual(sols[0].shot.pocket, "topRight")
    }

    /// 直击不可行盘面：必须尝试翻袋；有解则 feasible+进袋，无解则诚实空目录。
    func test_obtuseDirect_bankFallbackHonest() {
        let target = SCNVector3(0, sY + R, 0)
        let cue = SCNVector3(-0.2, sY + R, 0)
        XCTAssertTrue(
            DirectPotBankFallback.isDirectPotInfeasible(
                cue: cue, target: target, pocketIndex: 0, surfaceY: sY)
        )
        let banks = DirectPotBankFallback.solveBankAlternatives(
            cue: cue, object: target, pocketIndex: 0, surfaceY: sY, power: 3.6,
            spinXValues: [0]
        )
        for sol in banks {
            XCTAssertTrue(sol.prediction.feasible)
            XCTAssertTrue(sol.prediction.simObjectPotted)
            XCTAssertGreaterThanOrEqual(sol.cushions, 1)
            let text = DirectPotBankFallback.statusSummary(sol, index: 0, total: banks.count)
            XCTAssertTrue(text.contains("翻袋备选"))
        }
    }
}


final class DirectPredictionCancellationTests: XCTestCase {
    private let y = BTTablePhysics.surfaceY

    func testCancelledJobsDoNotPublishPartialShots() {
        let token = PredictionCancellation(); token.cancel()
        let board = BoardSnapshot(onTable: ["cueBall": .init(x: 0.5, y: 0.35), "_1": .init(x: 0.5, y: 0.15)])
        for aim in [nil, CanvasPoint(x: 0, y: -1)] {
            let shot = PlannedShot(targetKey: "_1", pocket: "topCenter", velocity: 2, freeAim: aim)
            XCTAssertNil(PositionPlayShotSolver.solve(before: board, shot: shot, surfaceY: y, cancellation: token))
        }
        let cancelled = ShotPredictor.simulateFree(cueBall: SCNVector3(0, y + BallPhysics.radius, 0),
            aimDir: SCNVector3(1, 0, 0), velocity: 3, spinX: 0, spinY: 0,
            surfaceY: y, balls: [], cancellation: token)
        XCTAssertEqual(cancelled.termination, .cancelled)
        XCTAssertFalse(cancelled.feasible)
        XCTAssertFalse(cancelled.hasFinalTableState)
        XCTAssertNil(cancelled.recorder)
    }

    func testCancellationStopsAnAlreadyAdvancingEngine() {
        let engine = EventDrivenEngine(tableGeometry: .chineseEightBallQiuJi(surfaceY: y))
        engine.setBall(BallState(position: SCNVector3(0, y + BallPhysics.radius, 0),
            velocity: SCNVector3(3, 0, 0.5), angularVelocity: SCNVector3Zero,
            state: .sliding, name: "cueBall"))
        var checks = 0
        engine.predictionCancellationRequested = { checks += 1; return checks == 6 }
        let termination = engine.simulatePrediction(model: .planarReference, maxTime: 15, highFidelityBounds: true)
        XCTAssertEqual(termination, .cancelled)
        XCTAssertEqual(checks, 6)
        let recorder = engine.getTrajectoryRecorder()
        XCTAssertGreaterThan(recorder.duration, 0, "Must interrupt actual simulated motion, not just reject before entry")
        XCTAssertLessThan(recorder.duration, 15)
        XCTAssertGreaterThan(recorder.framesByBallName["cueBall"]?.count ?? 0, 1)
    }

    func testLiveCancellationTokenPreservesCompleteTrajectories() throws {
        let board = BoardSnapshot(onTable: ["cueBall": .init(x: 0.5, y: 0.35), "_1": .init(x: 0.5, y: 0.15),
                                            "_2": .init(x: 0.25, y: 0.3)])
        for aim in [nil, CanvasPoint(x: 0, y: -1)] {
            for power in [1.5, 3.0, 5.0] {
                let shot = PlannedShot(targetKey: "_1", pocket: "topCenter", velocity: power,
                    spinX: 0.15, spinY: -0.2, freeAim: aim)
                let original = try XCTUnwrap(PositionPlayShotSolver.solve(before: board, shot: shot, surfaceY: y))
                let live = try XCTUnwrap(PositionPlayShotSolver.solve(before: board, shot: shot, surfaceY: y,
                    cancellation: PredictionCancellation()))
                XCTAssertEqual(original.termination, live.termination)
                XCTAssertTrue(live.hasFinalTableState)
                XCTAssertEqual(original.simObjectPotted, live.simObjectPotted)
                let a = try XCTUnwrap(original.recorder), b = try XCTUnwrap(live.recorder)
                XCTAssertEqual(a.framesByBallName.keys.sorted(), b.framesByBallName.keys.sorted())
                for name in a.framesByBallName.keys {
                    let left = try XCTUnwrap(a.framesByBallName[name]), right = try XCTUnwrap(b.framesByBallName[name])
                    XCTAssertEqual(left.count, right.count)
                    for (x, z) in zip(left, right) {
                        XCTAssertEqual(x.time, z.time)
                        XCTAssertEqual(x.state, z.state)
                        XCTAssertEqual([x.position.x,x.position.y,x.position.z,x.velocity.x,x.velocity.y,x.velocity.z,
                            x.angularVelocity.x,x.angularVelocity.y,x.angularVelocity.z,x.angularVelocity.w],
                            [z.position.x,z.position.y,z.position.z,z.velocity.x,z.velocity.y,z.velocity.z,
                             z.angularVelocity.x,z.angularVelocity.y,z.angularVelocity.z,z.angularVelocity.w])
                    }
                }
            }
        }
    }
}
