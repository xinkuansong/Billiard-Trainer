import XCTest
import SceneKit
@testable import QiuJi

final class KickCenteredRouteTests: XCTestCase {
    private func point(_ x: Float, _ z: Float) -> SCNVector3 {
        .init(x, 0.8 + BallPhysics.radius, z)
    }

    func test_impactUsesIncomingContactAndKnownCutAngles() {
        for angle: Float in [0, 30, 60, 89] {
            let radians = angle * .pi / 180
            let cue = BallState(position: point(0,0), velocity: .init(cosf(radians),0,sinf(radians)),
                angularVelocity: SCNVector3Zero, state: .rolling, name: ShotInput.cueBallName)
            let target = BallState(position: point(2 * BallPhysics.radius,0), velocity: SCNVector3Zero,
                angularVelocity: SCNVector3Zero, state: .stationary, name: ShotInput.targetBallName)
            let recorder = TrajectoryRecorder()
            recorder.recordBallContact(time: 1, a: cue, b: target)
            // Post-impact frames deliberately disagree with the incoming velocity.
            recorder.recordFrame(ballName: cue.name, frame: .init(time: 1, position: cue.position,
                velocity: .init(0,0,1), angularVelocity: SCNVector4(0,0,0,0), state: .rolling))
            var prediction = ShotPrediction(); prediction.recorder = recorder
            XCTAssertEqual(KickRouteQuality.contactOffset(prediction), sinf(radians), accuracy: 0.00001)
        }
    }

    private struct Candidate: RankableSolution {
        var spinX: Float
        var contactError: Float
        var route: BankKickRoute?
        var searchKey: [BankShotCalculator.Rail] = [.left]
        var goodness: Double = 0
        var cushions: Int { route?.rails.count ?? 0 }
        var pathLength: Double = 1
        var prediction = ShotPrediction()
    }

    func test_centeredCandidateWinsAndSpinReductionCannotReplaceItWithThinContact() {
        let route = BankKickRoute(rails: [.left], contacts: [], path: [], pocketID: nil)
        let full = Candidate(spinX: 0.3, contactError: 0.01, route: route)
        let thin = Candidate(spinX: 0, contactError: 0.9, route: route)
        let ranked = BankKickSolvePipeline.rank([thin, full], limit: 16)
        XCTAssertEqual(ranked.count, 1)
        XCTAssertEqual(ranked.first?.spinX, 0.3)
        XCTAssertEqual(BankKickSolvePipeline.rank([thin], limit: 16).count, 1, "Thin-only fallback remains")
        let reduced = BankKickSolvePipeline.minimumSpinRepresentatives([full], spinXValues: [0,0.3]) { seed, spin in
            var trial = seed; trial.spinX = spin; trial.contactError = spin < 10 * BankKickSolvePipeline.minimumSpinStep ? 0.9 : 0.01
            return trial
        }
        XCTAssertEqual(reduced[0].spinX, 0.2, accuracy: 0.00001)
        XCTAssertEqual(reduced[0].contactError, 0.01)
    }

    func test_screenshotApproximationHasOneCenteredRepresentativePerMeasuredSequence() {
        // Coordinates reconstructed approximately from the screenshot, not the original saved shot.
        let solutions = BankKickSolvePipeline.solveKick(cue: point(0.68,0.28), target: point(-1.07,-0.27),
            surfaceY: 0.8, power: 2.4, limit: nil)
        XCTAssertFalse(solutions.isEmpty)
        let keys = solutions.map { $0.rails.map { String(describing: $0) }.joined(separator: ",") }
        XCTAssertEqual(Set(keys).count, solutions.count)
        let lowerRail = solutions.filter { $0.rails == [.right] }
        XCTAssertEqual(lowerRail.count, 1)
        if let solution = lowerRail.first {
            XCTAssertLessThanOrEqual(KickRouteQuality.contactOffset(solution.prediction),
                                     KickRouteQuality.centeredContactTolerance)
        }
        XCTAssertTrue(solutions.allSatisfy { KickRouteQuality.accepts($0.prediction) })
    }

    func test_failedCenteredSearchRetainsKnownValidContactFallbacks() {
        let ordinary = BankKickSolvePipeline.solveKick(cue: point(-0.5,-0.2), target: point(0.4,0.25),
            surfaceY: 0.8, power: 3.6, limit: nil)
        // The user now excludes this previously valid thin-only parallel route.
        XCTAssertFalse(ordinary.contains { $0.rails == [.far,.near] })
        let blocked = BankKickSolvePipeline.solveKick(cue: point(0.68,0.28), target: point(-1.07,-0.27),
            surfaceY: 0.8, power: 2.4, obstacles: [.init(name: "block", position: point(-0.3,0.15))], limit: nil)
        XCTAssertTrue(blocked.contains { $0.rails == [.near,.right,.far] })
        XCTAssertTrue((ordinary + blocked).allSatisfy { KickRouteQuality.accepts($0.prediction) })
    }
}
