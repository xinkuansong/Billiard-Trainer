import XCTest
import SceneKit
@testable import QiuJi

final class BankKickParallelRailTests: XCTestCase {
    func testEverySequenceUpToFourContacts() {
        let walls: [BankShotCalculator.Rail] = [.left,.right,.near,.far]
        let opposite: [BankShotCalculator.Rail: BankShotCalculator.Rail] =
            [.left:.right,.right:.left,.near:.far,.far:.near]
        var sequences: [[BankShotCalculator.Rail]] = [[]]
        for _ in 0...4 {
            for sequence in sequences {
                let expected = zip(sequence,sequence.dropFirst()).contains { opposite[$0.0] == $0.1 }
                XCTAssertEqual(BankKickRouteQuality.hasConsecutiveParallelRails(sequence),expected)
            }
            sequences = sequences.flatMap { prefix in walls.map { prefix + [$0] } }
        }
    }

    func testEventScopeAndBothValidationPaths() {
        let cue = ShotInput.cueBallName, target = ShotInput.targetBallName
        let hit = ShotEvent(time:1,kind:.ballBall(ballA:cue,ballB:target))
        let pot = ShotEvent(time:5,kind:.pocket(ball:target,pocketId:"pocket_0"))
        func rail(_ index: Int, _ ball: String) -> ShotEvent {
            let normals: [Int:SCNVector3] = [0:.init(0,0,1),2:.init(0,0,-1),4:.init(1,0,0),5:.init(-1,0,0),8:.init(1,0,0)]
            return .init(time:2,kind:.ballCushion(ball:ball),contactNormal:normals[index],cushionIndex:index)
        }
        let cases: [([ShotEvent],Bool)] = [
            ([hit,rail(0,target),rail(2,target),pot],true),
            ([hit,rail(4,target),rail(5,target),rail(4,target),pot],true),
            ([hit,rail(0,target),rail(8,target),rail(2,target),pot],true),
            ([hit,rail(0,target),rail(0,target),pot],false),
            ([hit,rail(0,target),rail(4,target),rail(2,target),pot],false),
            ([rail(0,target),rail(2,target),hit,rail(4,target),pot],false),
            ([hit,rail(0,cue),rail(2,cue),rail(4,target),pot],false),
            ([hit,rail(0,"obstacle"),rail(2,"obstacle"),rail(4,target),pot],false),
            ([hit,rail(0,target),pot,rail(2,target)],false)
        ]
        for (events,rejected) in cases {
            var p = ShotPrediction(); p.termination = .settled; p.simObjectPotted = true
            p.events = events; p.objectRailContacts = [.left]
            XCTAssertTrue(BankKickValidity.bank(p),"Recommendation filtering is distinct from physical validity")
            XCTAssertEqual(BankRouteQuality.hasConsecutiveParallelRails(events:events),rejected)
            XCTAssertEqual(BankRouteQuality.accepts(p),!rejected)
            XCTAssertEqual(BankRouteQuality.accepts(BankKickValidation(p)),!rejected)
        }
        XCTAssertEqual(KickRouteQuality.rejection(events:[rail(0,cue),rail(2,cue),hit]),.consecutiveParallelRails)
        XCTAssertEqual(KickRouteQuality.rejection(events:[rail(4,cue),rail(5,cue),rail(4,cue),hit]),.consecutiveParallelRails)
        XCTAssertNil(KickRouteQuality.rejection(events:[rail(0,cue),rail(4,cue),hit,rail(5,cue)]))
        XCTAssertNil(KickRouteQuality.rejection(events:[rail(0,cue),hit,rail(2,cue)]))
    }
}
