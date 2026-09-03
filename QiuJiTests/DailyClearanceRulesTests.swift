import XCTest
@testable import QiuJi

final class DailyClearanceRulesTests: XCTestCase {
    private var fullEightBallTable: Set<String> { Set((1...15).map { "_\($0)" }) }

    private func facts(first: String?,
                       pocketed: [String] = [],
                       cuePocketed: Bool = false,
                       rail: Bool = true,
                       table: Set<String>) -> ShotFacts {
        ShotFacts(
            firstContactKey: first,
            pocketedKeys: pocketed,
            cuePocketed: cuePocketed,
            railOrPocketAfterContact: rail,
            tableKeysBefore: table
        )
    }

    func test_gameMapsAllFiveRackLayouts() {
        XCTAssertEqual(DailyClearanceGame.chineseEightBall.rackGame, .chineseEightBall)
        XCTAssertEqual(DailyClearanceGame.nineBall.rackGame, .nineBall)
        XCTAssertEqual(DailyClearanceGame.sixBall.rackGame, .zhuifen(balls: 6))
        XCTAssertEqual(DailyClearanceGame.fiveBall.rackGame, .zhuifen(balls: 5))
        XCTAssertEqual(DailyClearanceGame.fourBall.rackGame, .zhuifen(balls: 4))
    }

    func test_initialDefaultFollowsLegacySportOnlyAtMigration() {
        XCTAssertEqual(DailyClearanceGame.initialDefault(for: .chinese8), .chineseEightBall)
        XCTAssertEqual(DailyClearanceGame.initialDefault(for: .nineBall), .nineBall)
        XCTAssertEqual(DailyClearanceGame.initialDefault(for: .both), .chineseEightBall)
    }

    func test_chineseEight_openTablePotAssignsGroup() {
        var engine = DailyClearanceRulesEngine(game: .chineseEightBall)
        let ruling = engine.judge(facts(first: "_3", pocketed: ["_3"], table: fullEightBallTable))
        XCTAssertFalse(ruling.foul)
        XCTAssertEqual(engine.state.assignedGroup, .solid)
        XCTAssertEqual(engine.state.status, .active)
    }

    func test_chineseEight_wrongFirstContactIsFoulWithoutRotation() {
        var engine = DailyClearanceRulesEngine(
            game: .chineseEightBall,
            state: DailyClearanceRuleState(assignedGroup: .solid)
        )
        let ruling = engine.judge(facts(first: "_9", table: fullEightBallTable))
        XCTAssertTrue(ruling.foul)
        XCTAssertTrue(ruling.ballInHand)
        XCTAssertEqual(engine.state.assignedGroup, .solid)
        XCTAssertEqual(engine.state.status, .active)
    }

    func test_chineseEight_groupClearedLegalEightCompletes() {
        var engine = DailyClearanceRulesEngine(
            game: .chineseEightBall,
            state: DailyClearanceRuleState(assignedGroup: .solid)
        )
        let ruling = engine.judge(facts(first: "_8", pocketed: ["_8"], table: ["_8", "_9"]))
        XCTAssertTrue(ruling.completed)
        XCTAssertEqual(engine.state.status, .completed)
    }

    func test_chineseEight_earlyEightFails() {
        var engine = DailyClearanceRulesEngine(
            game: .chineseEightBall,
            state: DailyClearanceRuleState(assignedGroup: .solid)
        )
        let ruling = engine.judge(facts(first: "_2", pocketed: ["_8"], table: ["_2", "_8"]))
        XCTAssertTrue(ruling.failed)
        XCTAssertEqual(engine.state.status, .failed)
    }

    func test_chineseEight_foulEightFails() {
        var engine = DailyClearanceRulesEngine(
            game: .chineseEightBall,
            state: DailyClearanceRuleState(assignedGroup: .solid)
        )
        let ruling = engine.judge(facts(
            first: "_8",
            pocketed: ["_8"],
            cuePocketed: true,
            table: ["_8", "_9"]
        ))
        XCTAssertTrue(ruling.foul)
        XCTAssertTrue(ruling.failed)
        XCTAssertFalse(ruling.ballInHand)
    }

    func test_nineBallLowestContactAndLegalComboNineCompletes() {
        var engine = DailyClearanceRulesEngine(game: .nineBall)
        XCTAssertEqual(engine.legalTargetKeys(tableKeys: ["_1", "_4", "_9"]), ["_1"])
        let ruling = engine.judge(facts(
            first: "_1",
            pocketed: ["_9"],
            table: ["_1", "_4", "_9"]
        ))
        XCTAssertTrue(ruling.completed)
        XCTAssertEqual(engine.state.status, .completed)
    }

    func test_nineBallWrongFirstContactIsContinuingFoul() {
        var engine = DailyClearanceRulesEngine(game: .nineBall)
        let ruling = engine.judge(facts(first: "_4", table: ["_1", "_4", "_9"]))
        XCTAssertTrue(ruling.foul)
        XCTAssertTrue(ruling.ballInHand)
        XCTAssertEqual(engine.state.status, .active)
    }

    func test_nineBallScratchIsContinuingFoul() {
        var engine = DailyClearanceRulesEngine(game: .nineBall)
        let ruling = engine.judge(facts(
            first: "_1",
            cuePocketed: true,
            table: ["_1", "_9"]
        ))
        XCTAssertTrue(ruling.foul)
        XCTAssertTrue(ruling.ballInHand)
        XCTAssertEqual(engine.state.status, .active)
    }

    func test_nineBallFoulTerminalPocketFails() {
        var engine = DailyClearanceRulesEngine(game: .nineBall)
        let ruling = engine.judge(facts(
            first: "_4",
            pocketed: ["_9"],
            table: ["_1", "_4", "_9"]
        ))
        XCTAssertTrue(ruling.foul)
        XCTAssertTrue(ruling.failed)
        XCTAssertFalse(ruling.ballInHand)
        XCTAssertEqual(engine.state.status, .failed)
    }
}
