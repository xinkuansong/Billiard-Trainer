import XCTest
import SceneKit
@testable import QiuJi

/// 直击失败 → 翻袋备选闸门与装配（复用 `BankKickSolvePipeline.solveBank`）。
final class DirectPotBankFallbackTests: XCTestCase {

    private let sY = BTTablePhysics.surfaceY
    private var R: Float { BallPhysics.radius }

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
            spinXValues: [0]
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
