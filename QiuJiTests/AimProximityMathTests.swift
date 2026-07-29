import XCTest
import SceneKit
@testable import QiuJi

final class AimProximityMathTests: XCTestCase {

    private let r: CGFloat = 0.028575

    /// Coordinate contract: planar X→x, Z→y (meters).

    func test_contactBoundary_isTwoR() {
        let cue = CGPoint(x: 0, y: 0)
        let dir = CGPoint(x: 1, y: 0)
        // Target on +X, offset = 0 → contact.
        let onLine = AimProximityMath.advance(
            cue: cue, direction: dir, target: CGPoint(x: 0.4, y: 0),
            ballRadius: r, previouslyNear: false)
        XCTAssertEqual(onLine.band, .contact)
        XCTAssertEqual(onLine.offset, 0, accuracy: 1e-9)

        // Offset just under 2R → still contact.
        let under = AimProximityMath.advance(
            cue: cue, direction: dir, target: CGPoint(x: 0.4, y: 2 * r - 1e-4),
            ballRadius: r, previouslyNear: false)
        XCTAssertEqual(under.band, .contact)

        // Offset just over 2R but under 3R → skim (near miss).
        let skim = AimProximityMath.advance(
            cue: cue, direction: dir, target: CGPoint(x: 0.4, y: 2 * r + 1e-4),
            ballRadius: r, previouslyNear: false)
        XCTAssertEqual(skim.band, .skim)
    }

    func test_hysteresis_enterExit() {
        let cue = CGPoint(x: 0, y: 0)
        let dir = CGPoint(x: 1, y: 0)
        // Between 3R and 3.5R: enter from far = still far; stay near if already near.
        let mid = CGPoint(x: 0.4, y: 3.2 * r)
        let fromFar = AimProximityMath.advance(
            cue: cue, direction: dir, target: mid,
            ballRadius: r, previouslyNear: false)
        XCTAssertEqual(fromFar.band, .far)

        let stay = AimProximityMath.advance(
            cue: cue, direction: dir, target: mid,
            ballRadius: r, previouslyNear: true)
        XCTAssertEqual(stay.band, .skim)

        let exit = AimProximityMath.advance(
            cue: cue, direction: dir, target: CGPoint(x: 0.4, y: 3.6 * r),
            ballRadius: r, previouslyNear: true)
        XCTAssertEqual(exit.band, .far)
    }

    func test_ballBehindCue_neverNear() {
        let cue = CGPoint(x: 0, y: 0)
        let dir = CGPoint(x: 1, y: 0)
        // Behind cue, offset 0 — must not use offsetDistance alone.
        let behind = AimProximityMath.advance(
            cue: cue, direction: dir, target: CGPoint(x: -0.3, y: 0),
            ballRadius: r, previouslyNear: true)
        XCTAssertFalse(behind.forward)
        XCTAssertEqual(behind.band, .far)
    }

    func test_userGhost_nilWhenSkim() {
        let cue = CGPoint(x: 0, y: 0)
        let dir = CGPoint(x: 1, y: 0)
        let ghost = AimProximityMath.userGhost(
            cue: cue, direction: dir,
            target: CGPoint(x: 0.5, y: 2.2 * r),
            ballRadius: r)
        XCTAssertNil(ghost)
    }

    func test_userGhost_straightShot() {
        let cue = CGPoint(x: 0, y: 0)
        let dir = CGPoint(x: 1, y: 0)
        let target = CGPoint(x: 0.5, y: 0)
        let ghost = AimProximityMath.userGhost(
            cue: cue, direction: dir, target: target, ballRadius: r)
        XCTAssertNotNil(ghost)
        // Ghost is 2R before target along aim.
        XCTAssertEqual(ghost!.x, 0.5 - 2 * r, accuracy: 1e-5)
        XCTAssertEqual(ghost!.y, 0, accuracy: 1e-5)
    }
}

final class AimWheelGainTests: XCTestCase {

    func test_mmCalibration_atHalfMeter() {
        let dpp = AimWheelGain.degreesPerPoint(distanceMeters: 0.5)
        let mm = AimWheelGain.millimetersPerPoint(degreesPerPoint: dpp, distanceMeters: 0.5)
        XCTAssertEqual(mm, AimWheelGain.targetMillimetersPerPoint, accuracy: 1e-3)
        // ~0.0458°/pt at 0.5 m
        XCTAssertEqual(dpp, 0.04584, accuracy: 1e-3)
    }

    func test_farShot_finerThanNear_inDegrees() {
        let near = AimWheelGain.degreesPerPoint(distanceMeters: 0.3)
        let far = AimWheelGain.degreesPerPoint(distanceMeters: 1.0)
        XCTAssertLessThan(far, near)
        // Same mm/pt at both distances (above min lever).
        let mmNear = AimWheelGain.millimetersPerPoint(degreesPerPoint: near, distanceMeters: 0.3)
        let mmFar = AimWheelGain.millimetersPerPoint(degreesPerPoint: far, distanceMeters: 1.0)
        XCTAssertEqual(mmNear, mmFar, accuracy: 1e-3)
    }

    func test_minLever_capsGain() {
        let tiny = AimWheelGain.degreesPerPoint(distanceMeters: 0.01)
        let atFloor = AimWheelGain.degreesPerPoint(distanceMeters: AimWheelGain.minLeverMeters)
        XCTAssertEqual(tiny, atFloor, accuracy: 1e-6)
        XCTAssertLessThanOrEqual(tiny, AimWheelGain.maxDegreesPerPoint)
    }

    func test_legacyDefault_unchanged() {
        XCTAssertEqual(AimWheelGain.defaultDegreesPerPoint, 0.15, accuracy: 1e-6)
        let mm = AimWheelGain.millimetersPerPoint(
            degreesPerPoint: 0.15, distanceMeters: 0.5)
        XCTAssertEqual(mm, 1.309, accuracy: 0.01)
    }
}

/// v23 W2：轮增益杠杆臂（母球→首碰球 / 空杆前方最近球）。
final class AimLeverTests: XCTestCase {

    private let y: Float = 0

    func test_lever_isFirstContactBall_notNearest() {
        let cue = SCNVector3(0, y, 0)
        // 正前方 0.9 m 处目标球；侧后方 0.3 m 处另一颗更近但不在射线上。
        let balls = [
            (key: "ahead", pos: SCNVector3(0.9, y, 0)),
            (key: "aside", pos: SCNVector3(-0.3, y, 0.05)),
        ]
        let lever = AngleSceneCalculator.aimLeverMeters(
            cue: cue, dir: SCNVector3(1, 0, 0), balls: balls)
        XCTAssertEqual(try XCTUnwrap(lever), 0.9, accuracy: 1e-4)
    }

    func test_lever_missShot_usesNearestBallAhead() {
        let cue = SCNVector3(0, y, 0)
        // 两颗都在前方但都不在走廊内（横向偏出 2R 很多）：取较近者。
        let balls = [
            (key: "near", pos: SCNVector3(0.5, y, 0.4)),
            (key: "far", pos: SCNVector3(1.2, y, 0.4)),
        ]
        let lever = AngleSceneCalculator.aimLeverMeters(
            cue: cue, dir: SCNVector3(1, 0, 0), balls: balls)
        XCTAssertEqual(try XCTUnwrap(lever), hypotf(0.5, 0.4), accuracy: 1e-4)
    }

    func test_lever_nilWhenTableEmpty_keepsLegacyGain() {
        let lever = AngleSceneCalculator.aimLeverMeters(
            cue: SCNVector3(0, y, 0), dir: SCNVector3(1, 0, 0), balls: [])
        XCTAssertNil(lever)
    }

    func test_lever_ballsOnlyBehind_stillReturnsDistance() {
        let balls = [(key: "behind", pos: SCNVector3(-0.6, y, 0))]
        let lever = AngleSceneCalculator.aimLeverMeters(
            cue: SCNVector3(0, y, 0), dir: SCNVector3(1, 0, 0), balls: balls)
        XCTAssertEqual(try XCTUnwrap(lever), 0.6, accuracy: 1e-4)
    }
}
