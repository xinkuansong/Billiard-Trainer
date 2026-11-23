import XCTest
import SceneKit
@testable import QiuJi

final class KickPostContactRuleTests: XCTestCase {
    func test_toolAndPracticeRequireCueOrTargetCushionStrictlyAfterContact() {
        let cue = ShotInput.cueBallName, target = ShotInput.targetBallName
        let before = ShotEvent(time: 1, kind: .ballCushion(ball: cue),
            contactNormal: .init(0,0,1), cushionIndex: 0)
        let hit = ShotEvent(time: 2, kind: .ballBall(ballA: cue, ballB: target))
        let cases: [(String, [ShotEvent], Bool)] = [
            ("no post rail", [], false),
            ("cue rail", [.init(time: 3, kind: .ballCushion(ball: cue), cushionIndex: 0)], true),
            ("target rail", [.init(time: 3, kind: .ballCushion(ball: target), cushionIndex: 2)], true),
            ("simultaneous", [.init(time: 2, kind: .ballCushion(ball: cue), cushionIndex: 0)], false),
            ("earlier time", [.init(time: 1.5, kind: .ballCushion(ball: target), cushionIndex: 0)], false),
            ("other ball", [.init(time: 3, kind: .ballCushion(ball: "obstacle"), cushionIndex: 0)], false),
            ("pocket only", [.init(time: 3, kind: .pocket(ball: target, pocketId: "pocket_0"))], false),
            ("post jaw", [.init(time: 3, kind: .ballCushion(ball: cue), cushionIndex: 6)], true)
        ]
        for (name, tail, expected) in cases {
            var prediction = ShotPrediction()
            prediction.termination = .settled
            prediction.events = [before, hit] + tail
            XCTAssertEqual(BankKickValidity.kick(prediction), expected, name)
            XCTAssertEqual(BankKickValidity.kick(BankKickValidation(prediction)), expected, name)
            XCTAssertEqual(KickRouteQuality.accepts(prediction), expected, name)
            XCTAssertEqual(KickJudgement.failure(events: prediction.events, complete: true,
                walls: [KickWall.from(cushion: 0)!]) == nil, expected, name)
            prediction.cuePocketed = true
            XCTAssertFalse(BankKickValidity.kick(prediction), "Scratch still fails")
            prediction.cuePocketed = false
            prediction.termination = .timeLimit
            XCTAssertFalse(BankKickValidity.kick(prediction), "Incomplete trajectory still fails")
        }
    }
}
