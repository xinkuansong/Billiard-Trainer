import XCTest
import SceneKit
@testable import QiuJi

final class KBallBankTests: XCTestCase {
    func testBundledParameterBankAndBoundedCache() throws {
        let bank = try KBallBankStore.load()
        var ids = Set<String>(), counts: [Int: Int] = [:]
        for entry in bank.index.layouts {
            let layout = try bank.layout(entry)
            for q in layout.questions {
                XCTAssertTrue(ids.insert(q.id).inserted)
                counts[q.rail, default: 0] += 1
                XCTAssertEqual(q.railsBeforeK.count, q.rail - (q.timing == .before ? 1 : 0))
            }
            XCTAssertLessThanOrEqual(bank.decodedShardCount, 2)
        }
        XCTAssertEqual(ids.count, 11458)
        XCTAssertEqual(counts, [1: 3872, 2: 7242, 3: 344])
        bank.clearCache(); XCTAssertEqual(bank.decodedShardCount, 0)
    }

    func testKJudgementUsesCueContactsAndAllowsScratchAndLatePot() {
        let cue = ShotInput.cueBallName, a = ShotInput.targetBallName, b = TwoBallQuestionPreparer.secondBallName
        let hitA = ShotEvent(time: 1, kind: .ballBall(ballA: a, ballB: cue))
        let hitB = ShotEvent(time: 2, kind: .ballBall(ballA: cue, ballB: b))
        let potA = ShotEvent(time: 3, kind: .pocket(ball: a, pocketId: "pocket_4"))
        let scratch = ShotEvent(time: 4, kind: .pocket(ball: cue, pocketId: "pocket_0"))
        XCTAssertNil(KBallJudgement.failure(events: [hitA, hitB, potA, scratch], complete: true, pocket: 4))
        XCTAssertEqual(KBallJudgement.failure(events: [hitB, hitA, potA], complete: true, pocket: 4), .firstContact)
        XCTAssertEqual(KBallJudgement.failure(events: [hitA, hitB, potA], complete: true, pocket: 3), .pocket)
        XCTAssertEqual(KBallJudgement.failure(events: [hitA, hitB, potA], complete: false, pocket: 4), .incomplete)
        let indirect = ShotEvent(time: 2, kind: .ballBall(ballA: a, ballB: b))
        XCTAssertEqual(KBallJudgement.failure(events: [hitA, indirect, potA], complete: true, pocket: 4), .missingK)
    }

    func testObservedRailBeforeAndAfterAcrossAllWalls() {
        for railID in 0..<6 {
            for ordinal in 1...3 {
                let before = kBallRailPrediction(railID: railID, priorRails: Array(repeating: railID, count: ordinal - 1), approaching: true)
                let after = kBallRailPrediction(railID: railID, priorRails: Array(repeating: railID, count: ordinal), approaching: false)
                XCTAssertEqual(KBallJudgement.observedRail(before, railID: railID), ordinal)
                XCTAssertEqual(KBallJudgement.observedRail(after, railID: railID), ordinal)
            }
        }
    }

    func testRailFactsIgnoreJawsOtherBallsAndEventsOutsideFirstKInterval() {
        let cue = ShotInput.cueBallName
        var shot = kBallRailPrediction(railID: 4, priorRails: [5], approaching: true)
        shot.events.insert(.init(time: 0, kind: .ballCushion(ball: cue), cushionIndex: 4), at: 0)
        shot.events.insert(.init(time: 1.8, kind: .ballCushion(ball: cue), cushionIndex: 7), at: 3)
        shot.events.insert(.init(time: 1.9, kind: .ballCushion(ball: ShotInput.targetBallName), cushionIndex: 4), at: 4)
        shot.events.append(.init(time: 4, kind: .ballCushion(ball: cue), cushionIndex: 4))
        shot.events.append(.init(time: 5, kind: .ballBall(ballA: cue, ballB: TwoBallQuestionPreparer.secondBallName)))
        XCTAssertEqual(KBallJudgement.observedRail(shot, railID: 4), 2)
        shot.events.insert(.init(time: 1.95, kind: .ballCushion(ball: cue)), at: 5)
        XCTAssertNil(KBallJudgement.observedRail(shot, railID: 4))
        let leavingWrongWall = kBallRailPrediction(railID: 4, priorRails: [5], approaching: false)
        XCTAssertEqual(KBallJudgement.observedRail(leavingWrongWall, railID: 4), 0)
        let leavingOtherHalf = kBallRailPrediction(railID: 0, priorRails: [1], approaching: false)
        XCTAssertEqual(KBallJudgement.observedRail(leavingOtherHalf, railID: 0), 1)
    }

    func testIncomingContactFactsFailClosedWhenAbsentOrBWasAlreadyHit() throws {
        let shot = kBallRailPrediction(railID: 4, priorRails: [5], approaching: true)
        let recorder = try XCTUnwrap(shot.recorder)
        let cue = ShotInput.cueBallName, a = ShotInput.targetBallName, b = TwoBallQuestionPreparer.secondBallName
        XCTAssertEqual(recorder.firstBallContacts[cue]?.other.name, a)
        XCTAssertEqual(recorder.firstBallContacts[b]?.time, 2)
        let first = try XCTUnwrap(recorder.firstBallContacts[b])
        var later = first.other; later.velocity = .init(-2, 0, 0)
        recorder.recordBallContact(time: 5, a: later, b: first.incoming)
        XCTAssertEqual(recorder.firstBallContacts[b]?.other.velocity.x, first.other.velocity.x)
        var missing = shot; missing.recorder = TrajectoryRecorder()
        XCTAssertNil(KBallJudgement.observedRail(missing, railID: 4))
        let early = TrajectoryRecorder()
        var target = first.other
        target = .init(position: target.position, velocity: target.velocity,
                       angularVelocity: target.angularVelocity, state: target.state, name: a)
        early.recordBallContact(time: 1.5, a: target, b: first.incoming)
        early.recordBallContact(time: 2, a: first.other, b: first.incoming)
        missing.recorder = early
        XCTAssertNil(KBallJudgement.observedRail(missing, railID: 4))
    }

    func testReferenceReconstructionAcrossObservedRailsAndTiming() throws {
        let bank = try KBallBankStore.load()
        let profile = AccuracyTipSelector.renderedProfile()
        var covered = Set<String>()
        for entry in bank.index.layouts {
            let layout = try bank.layout(entry)
            for question in layout.questions {
                let key = "\(question.rail)-\(question.timing.rawValue)"
                guard !covered.contains(key) else { continue }
                let prediction = try KBallQuestionPreparer.solve(layout: layout, question: question,
                    input: .init(), surfaceY: BTTablePhysics.surfaceY, profile: profile, reference: true)
                XCTAssertNil(KBallJudgement.failure(prediction, pocket: layout.board.pocket, question: question), question.id)
                covered.insert(key)
            }
            if covered.count == 6 { break }
        }
        XCTAssertEqual(covered.count, 6)
    }
}

/// Deterministic event facts for rule tests, independent of bank route labels.
func kBallRailPrediction(railID: Int, priorRails: [Int], approaching: Bool, pocket: Int = 4) -> ShotPrediction {
    let cue = ShotInput.cueBallName, a = ShotInput.targetBallName, b = TwoBallQuestionPreparer.secondBallName
    let normal = TableGeometry.chineseEightBallCushions(y: 0).linear[railID].normal
    let velocity = SCNVector3(normal.x * (approaching ? -1 : 1), 0, normal.z * (approaching ? -1 : 1))
    func ball(_ name: String, _ v: SCNVector3 = .init(0, 0, 0)) -> BallState {
        .init(position: .init(0, 0, 0), velocity: v, angularVelocity: .init(0, 0, 0), state: .sliding, name: name)
    }
    let recorder = TrajectoryRecorder()
    recorder.recordBallContact(time: 1, a: ball(cue, velocity), b: ball(a))
    recorder.recordBallContact(time: 2, a: ball(cue, velocity), b: ball(b))
    var result = ShotPrediction()
    result.termination = .settled; result.recorder = recorder
    result.strikeDirection = .init(1, 0, 0)
    result.finalPositions = [cue: .init(0, 0, 0)]
    result.events = [.init(time: 1, kind: .ballBall(ballA: cue, ballB: a))]
    for (i, rail) in priorRails.enumerated() {
        result.events.append(.init(time: 1 + Float(i + 1) / Float(priorRails.count + 1), kind: .ballCushion(ball: cue), cushionIndex: rail))
    }
    result.events.append(.init(time: 2, kind: .ballBall(ballA: cue, ballB: b)))
    result.events.append(.init(time: 3, kind: .pocket(ball: a, pocketId: "pocket_\(pocket)")))
    return result
}
