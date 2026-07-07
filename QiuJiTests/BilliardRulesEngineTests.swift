import XCTest
@testable import QiuJi

/// 规则引擎单测（条 15.10）：中式八球开放/定边/犯规/8 号胜负 + 追分计分/首触/终局。
/// 规则依据：docs/research/20260707-中八追分规则调研.md。
@MainActor
final class BilliardRulesEngineTests: XCTestCase {

    /// 中八全量球键（不含母球）。
    private var fullTable: Set<String> { Set((1...15).map { "_\($0)" }) }

    private func facts(first: String?,
                       pocketed: [String] = [],
                       cuePocketed: Bool = false,
                       rail: Bool = true,
                       table: Set<String>) -> ShotFacts {
        ShotFacts(firstContactKey: first, pocketedKeys: pocketed,
                  cuePocketed: cuePocketed, railOrPocketAfterContact: rail,
                  tableKeysBefore: table)
    }

    // MARK: - 中式八球

    func test_eightBall_openTable_potAssignsGroupAndContinues() {
        let engine = ChineseEightBallRules()
        let r = engine.judge(facts(first: "_3", pocketed: ["_3"], table: fullTable))
        XCTAssertFalse(r.foul)
        XCTAssertEqual(r.nextPlayer, .a, "进球继续击球")
        XCTAssertEqual(engine.groupOfA, .solid, "开放局打进全色 → A 持全色")
    }

    func test_eightBall_wrongFirstContact_isFoulBallInHand() {
        let engine = ChineseEightBallRules()
        _ = engine.judge(facts(first: "_3", pocketed: ["_3"], table: fullTable))  // A 定全色
        // A 首触花色 → 犯规，B 自由球。
        let r = engine.judge(facts(first: "_9", table: fullTable.subtracting(["_3"])))
        XCTAssertTrue(r.foul)
        XCTAssertTrue(r.ballInHand)
        XCTAssertEqual(r.nextPlayer, .b)
    }

    func test_eightBall_noPotNoFoul_passesTurn() {
        let engine = ChineseEightBallRules()
        let r = engine.judge(facts(first: "_5", table: fullTable))
        XCTAssertFalse(r.foul)
        XCTAssertEqual(r.nextPlayer, .b)
    }

    func test_eightBall_scratch_isFoul() {
        let engine = ChineseEightBallRules()
        let r = engine.judge(facts(first: "_5", cuePocketed: true, table: fullTable))
        XCTAssertTrue(r.foul)
        XCTAssertTrue(r.ballInHand)
    }

    func test_eightBall_noRailAfterContact_isFoul() {
        let engine = ChineseEightBallRules()
        let r = engine.judge(facts(first: "_5", rail: false, table: fullTable))
        XCTAssertTrue(r.foul)
        XCTAssertEqual(r.foulReason, "触球后无球碰库")
    }

    func test_eightBall_openTable_firstContactEight_isFoul() {
        let engine = ChineseEightBallRules()
        let r = engine.judge(facts(first: "_8", table: fullTable))
        XCTAssertTrue(r.foul)
    }

    func test_eightBall_earlyEight_losesGame() {
        let engine = ChineseEightBallRules()
        _ = engine.judge(facts(first: "_3", pocketed: ["_3"], table: fullTable))  // A 定全色
        // A 本方球未清空就打进 8 号 → B 胜。
        let r = engine.judge(facts(first: "_2", pocketed: ["_8"],
                                   table: fullTable.subtracting(["_3"])))
        XCTAssertTrue(r.gameOver)
        XCTAssertEqual(r.winner, .b)
    }

    func test_eightBall_legalEightAfterClearing_wins() {
        let engine = ChineseEightBallRules()
        _ = engine.judge(facts(first: "_3", pocketed: ["_3"], table: fullTable))  // A 定全色
        // 桌面只剩 8 号与花色（A 的全色已清空），A 合法打进 8 号 → A 胜。
        let table: Set<String> = ["_8", "_9", "_10"]
        let r = engine.judge(facts(first: "_8", pocketed: ["_8"], table: table))
        XCTAssertTrue(r.gameOver)
        XCTAssertEqual(r.winner, .a)
    }

    func test_eightBall_scratchOnEight_losesGame() {
        let engine = ChineseEightBallRules()
        _ = engine.judge(facts(first: "_3", pocketed: ["_3"], table: fullTable))  // A 定全色
        let table: Set<String> = ["_8", "_9"]
        let r = engine.judge(facts(first: "_8", pocketed: ["_8"],
                                   cuePocketed: true, table: table))
        XCTAssertTrue(r.gameOver)
        XCTAssertEqual(r.winner, .b, "打进 8 号同杆母球落袋 → 判负")
    }

    // MARK: - 追分

    func test_zhuifen_scoreByBallNumber_andContinue() {
        let engine = ZhuifenRules()
        let table: Set<String> = ["_1", "_2", "_3", "_9"]
        let r = engine.judge(facts(first: "_1", pocketed: ["_1"], table: table))
        XCTAssertFalse(r.foul)
        XCTAssertEqual(engine.scoreA, 1)
        XCTAssertEqual(r.nextPlayer, .a, "进球继续击球")
    }

    func test_zhuifen_wrongFirstContact_isFoulNoScore() {
        let engine = ZhuifenRules()
        let table: Set<String> = ["_1", "_2", "_9"]
        let r = engine.judge(facts(first: "_2", pocketed: ["_2"], table: table))
        XCTAssertTrue(r.foul)
        XCTAssertEqual(engine.scoreA, 0, "犯规不计分")
        XCTAssertEqual(r.nextPlayer, .b)
        XCTAssertTrue(r.ballInHand)
    }

    func test_zhuifen_ninePocketed_endsGame_higherScoreWins() {
        let engine = ZhuifenRules()
        var table: Set<String> = ["_1", "_2", "_9"]
        _ = engine.judge(facts(first: "_1", pocketed: ["_1", "_2"], table: table))  // A +3
        table = ["_9"]
        // A 借最小号（9 即最小）打进 9 号 → 终局，A 3:0 胜。
        let r = engine.judge(facts(first: "_9", pocketed: ["_9"], table: table))
        XCTAssertTrue(r.gameOver)
        XCTAssertEqual(engine.scoreA, 12)
        XCTAssertEqual(r.winner, .a)
    }

    func test_zhuifen_foulNine_endsGameWithoutScore() {
        let engine = ZhuifenRules()
        let table: Set<String> = ["_1", "_9"]
        // 首触 9（非最小号）犯规且 9 落袋：不计分，仍终局，0:0 和局。
        let r = engine.judge(facts(first: "_9", pocketed: ["_9"], table: table))
        XCTAssertTrue(r.foul)
        XCTAssertTrue(r.gameOver)
        XCTAssertNil(r.winner)
        XCTAssertEqual(engine.scoreA, 0)
    }

    func test_zhuifen_turnPassesOnMiss() {
        let engine = ZhuifenRules()
        let table: Set<String> = ["_1", "_9"]
        let r = engine.judge(facts(first: "_1", table: table))
        XCTAssertFalse(r.foul)
        XCTAssertEqual(r.nextPlayer, .b)
    }
}
