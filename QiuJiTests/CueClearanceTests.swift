//
//  CueClearanceTests.swift
//  QiuJiTests
//
//  Geometry / clearance unit tests for cue elevation, collision guard,
//  follow-through clamp. Evidence drafts: build/cue-clearance-evidence/
//
//  Run:
//    xcodebuild test -scheme QiuJi \
//      -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
//      -only-testing:QiuJiTests/CueClearanceTests
//

import XCTest
import SceneKit
@testable import QiuJi

final class CueClearanceTests: XCTestCase {

    private let r = AngleSceneCalculator.ballRadius
    private let y: Float = 0.8286  // tableSurfaceY + R

    // MARK: - A. Elevation / occlusion

    /// Draft (build/cue-clearance-evidence): ball 6 cm directly behind → elev ≈ 31.13°.
    func test_elevation_ballSixCmBehind() {
        let cue = SCNVector3(0, y, 0)
        let aim = SCNVector3(1, 0, 0)  // back = −X
        let obstacle = SCNVector3(-0.06, y, 0)
        let result = CueStick.requiredElevation(
            cueBallPosition: cue, aimDirection: aim, obstacleCenters: [obstacle]
        )
        guard case .angle(let elev) = result else {
            return XCTFail("expected angle, got blocked")
        }
        // Numerical draft: atan2(R + shaftR(0.06) + 0.002, 0.06) ≈ 0.543 rad ≈ 31.13°
        XCTAssertEqual(elev, 0.543379, accuracy: 0.01,
                       "6cm-behind elev should match draft (~31.13°)")
        XCTAssertGreaterThan(elev, CueStick.minElevationRadians)
        XCTAssertLessThan(elev, CueStick.maxElevationRadians)
    }

    /// Lateral 10 cm at s=6 cm → no ball occlusion → cushion/min baseline.
    func test_elevation_farLateralNoOcclusion() {
        let cue = SCNVector3(0, y, 0)
        let aim = SCNVector3(1, 0, 0)
        let obstacle = SCNVector3(-0.06, y, 0.10)
        let withBall = CueStick.requiredElevation(
            cueBallPosition: cue, aimDirection: aim, obstacleCenters: [obstacle]
        )
        let baseline = CueStick.requiredElevation(
            cueBallPosition: cue, aimDirection: aim, obstacleCenters: []
        )
        XCTAssertEqual(withBall, baseline, "far lateral must not raise elevation")
    }

    /// Legal max ball occlusion: centres 2R apart on the back axis → ~32.3°, never blocked.
    func test_elevation_legalTouchingBehind_belowSixty() {
        let cue = SCNVector3(0, y, 0)
        let aim = SCNVector3(1, 0, 0)
        let obstacle = SCNVector3(-2 * r, y, 0)  // legal touching behind
        let result = CueStick.requiredElevation(
            cueBallPosition: cue, aimDirection: aim, obstacleCenters: [obstacle]
        )
        guard case .angle(let elev) = result else {
            return XCTFail("legal touching-behind must not block; got \(result)")
        }
        // Draft: atan2(R+tipR+0.002, 2R) ≈ 32.26° = 0.563 rad
        XCTAssertEqual(elev, 0.563, accuracy: 0.02)
        XCTAssertLessThan(elev, CueStick.maxElevationRadians)
    }

    /// Synthetic overlapping centres (s=0.02 < 2R) → elev > 60° → `.blocked`.
    ///
    /// **Not a legal layout**: centre distance 2 cm ≪ 2R = 5.715 cm (balls would interpenetrate).
    /// On any legal board, ball occlusion peaks ≈32.3° at s=2R, so `.blocked` is unreachable
    /// from ball occlusion alone (see DR-027). This case only exercises the defensive branch.
    func test_elevation_closeObstacleBlocked() {
        let cue = SCNVector3(0, y, 0)
        let aim = SCNVector3(1, 0, 0)
        let obstacle = SCNVector3(-0.02, y, 0)
        let result = CueStick.requiredElevation(
            cueBallPosition: cue, aimDirection: aim, obstacleCenters: [obstacle]
        )
        XCTAssertEqual(result, .blocked)
    }

    // MARK: - B. Collision guard — separation latch

    /// Soft/normal forward departure from the **strike point** must NOT false-trigger.
    /// Uses the same tipOffset vs (R+tipR+margin) envelope that caused the v≲1.4 regression.
    /// Evidence: build/cue-clearance-evidence/rework_latch_draft.txt
    func test_collision_softForward_noFalsePositive() {
        let strike = SCNVector3(0, y, 0)
        let aim = SCNVector3(1, 0, 0)
        let elev: Float = 0.05
        let endPull = CueStroke.followThroughPull
        let velocities: [Float] = [0.4, 0.6, 0.8, 1.0, 1.2, 1.5, 2.0, 3.0]
        for v in velocities {
            let tStar = CueClearance.firstCollisionTime(
                strikePosition: strike,
                aimDirection: aim,
                elevation: elev,
                endPull: endPull,
                holdDuration: 1.5,
                ballsAt: { t in
                    // Cue starts at strike (τ=0 contact envelope) and coasts +aim then stops.
                    ["cue": Self.ballForwardThenStop(t: t, v: v, y: self.y)]
                }
            )
            XCTAssertNil(tStar, "v=\(v) forward-only must not false-trigger (separation latch)")
        }
    }

    /// After separating forward, cue draws back into the held shaft → non-nil t*.
    func test_collision_drawBackAfterSeparate_captured() {
        let strike = SCNVector3(0, y, 0)
        let aim = SCNVector3(1, 0, 0)
        let elev: Float = 0.05
        let tStar = CueClearance.firstCollisionTime(
            strikePosition: strike,
            aimDirection: aim,
            elevation: elev,
            endPull: CueStroke.followThroughPull,
            holdDuration: 1.5,
            ballsAt: { t in
                ["cue": Self.ballDrawBack(t: t, y: self.y)]
            }
        )
        XCTAssertNotNil(tStar, "draw-back after separation must be captured")
        if let t = tStar {
            XCTAssertGreaterThan(t, 0.15, "must not fire in the contact envelope")
            XCTAssertLessThan(t, 1.7)
        }
    }

    /// Object ball starts outside (latch armed) and returns into the shaft.
    func test_collision_objectBallReturnsIntoShaft() {
        let strike = SCNVector3(0, y, 0)
        let aim = SCNVector3(1, 0, 0)
        let elev: Float = 0.05
        let tStar = CueClearance.firstCollisionTime(
            strikePosition: strike,
            aimDirection: aim,
            elevation: elev,
            endPull: CueStroke.followThroughPull,
            holdDuration: 1.5,
            ballsAt: { t in
                [
                    "cue": SCNVector3(0.20, self.y, 0),  // parked clear of tip
                    "object": SCNVector3(0.50 - 0.40 * Float(t), self.y, 0)
                ]
            }
        )
        XCTAssertNotNil(tStar, "returning object ball into shaft must be detected")
    }

    // MARK: - B2. SceneKit euler cross-check

    /// `CueClearance.shaftSegment` must match a real `SCNNode` with the same
    /// `position` + `eulerAngles = (−elev, yaw, 0)` as the render path.
    func test_shaftSegment_matchesSceneKitNode() {
        let cases: [(yawDeg: Float, elevDeg: Float, pull: Float)] = [
            (0, 5, 0),
            (37, 30, -0.05),
            (-120, 15, CueStroke.followThroughPull)
        ]
        let scene = SCNScene()
        let node = SCNNode()
        scene.rootNode.addChildNode(node)

        for c in cases {
            let yaw = c.yawDeg * .pi / 180
            let elev = c.elevDeg * .pi / 180
            // Reconstruct aim/back from yaw the same way CueStick does:
            // yaw = atan2(back.x, back.z), back = −aim.
            let back = SCNVector3(sin(yaw), 0, cos(yaw))
            let aim = SCNVector3(-back.x, 0, -back.z)
            let pivot = SCNVector3(0.12, y, -0.07)

            node.position = pivot
            node.eulerAngles = SCNVector3(-elev, yaw, 0)

            let tipZ = CueClearance.tipOffset + c.pull
            let buttZ = tipZ + CueClearance.shaftLength
            let scnTip = node.convertPosition(SCNVector3(0, 0, tipZ), to: nil)
            let scnButt = node.convertPosition(SCNVector3(0, 0, buttZ), to: nil)
            let seg = CueClearance.shaftSegment(
                strikePosition: pivot, aimDirection: aim,
                elevation: elev, pullBack: c.pull
            )
            XCTAssertEqual(seg.tip.x, scnTip.x, accuracy: 1e-5, "tip.x yaw=\(c.yawDeg) elev=\(c.elevDeg)")
            XCTAssertEqual(seg.tip.y, scnTip.y, accuracy: 1e-5, "tip.y")
            XCTAssertEqual(seg.tip.z, scnTip.z, accuracy: 1e-5, "tip.z")
            XCTAssertEqual(seg.butt.x, scnButt.x, accuracy: 1e-5, "butt.x")
            XCTAssertEqual(seg.butt.y, scnButt.y, accuracy: 1e-5, "butt.y")
            XCTAssertEqual(seg.butt.z, scnButt.z, accuracy: 1e-5, "butt.z")
        }
    }

    // MARK: - C. Follow-through clamp

    func test_followThrough_clampedByForwardBall() {
        let cue = SCNVector3(0, y, 0)
        let aim = SCNVector3(1, 0, 0)
        let obstacle = SCNVector3(2 * r + 0.01, y, 0)
        let clamped = CueStroke.clampedFollowThroughPull(
            cueBallPosition: cue, aimDirection: aim, obstacleCenters: [obstacle]
        )
        XCTAssertEqual(clamped, -0.01, accuracy: 1e-5)
        XCTAssertGreaterThan(clamped, CueStroke.followThroughPull)

        let tipPast = -(CueClearance.tipOffset + clamped)
        let obstacleSurface = (2 * r + 0.01) - r
        XCTAssertLessThan(tipPast, obstacleSurface)
        let tipPos = SCNVector3(tipPast, y, 0)
        let dist = abs(tipPos.x - obstacle.x)
        XCTAssertGreaterThanOrEqual(dist, r + CueClearance.tipRadius - 1e-4)
    }

    func test_followThrough_noObstacleUnclamped() {
        let cue = SCNVector3(0, y, 0)
        let aim = SCNVector3(1, 0, 0)
        let pull = CueStroke.clampedFollowThroughPull(
            cueBallPosition: cue, aimDirection: aim, obstacleCenters: []
        )
        XCTAssertEqual(pull, CueStroke.followThroughPull, accuracy: 1e-6)
    }

    // MARK: - Regression: pullBack literals (v=1.5)

    /// Nail concrete samples from `build/cue-clearance-evidence/rework_latch_draft.txt`
    /// so curve edits are caught (not a self-derived recompute of the same formula).
    func test_regression_pullBackLiteralSamples_v1_5() {
        let v: Float = 1.5
        // d = 0.05 + 0.035·1.5 = 0.1025; total = 0.5 + 0.12 + 2d/v = 0.7566…
        let samples: [(t: Double, expected: Float)] = [
            (0.0,      0.0),
            (0.125,    0.016015625),
            (0.25,     0.05125),
            (0.375,    0.086484375),
            (0.5,      0.1025),          // end of backswing
            (0.56,     0.1025),          // mid pause
            (0.62,     0.1025),          // end pause
            (0.70,     0.06737805),      // mid forward
            (0.756667, 0.0),             // contact
        ]
        for s in samples {
            let p = CueStroke.pullBack(at: s.t, velocity: v)
            XCTAssertEqual(p, s.expected, accuracy: 1e-5, "t=\(s.t)")
        }
        XCTAssertEqual(
            CueStroke.followThrough(at: CueStroke.followThroughDuration),
            CueStroke.followThroughPull, accuracy: 1e-6
        )
    }

    // MARK: - Shaft radius smoke

    func test_shaftRadius_monotoneTipToButt() {
        let rTip = CueClearance.shaftRadius(atDistanceAlongBack: r)
        let rMid = CueClearance.shaftRadius(atDistanceAlongBack: r + 0.5)
        let rButt = CueClearance.shaftRadius(
            atDistanceAlongBack: r + CueClearance.maxPullBack + CueClearance.shaftLength
        )
        XCTAssertEqual(rTip, CueClearance.tipRadius, accuracy: 1e-5)
        XCTAssertEqual(rButt, CueClearance.buttRadius, accuracy: 1e-5)
        XCTAssertLessThan(rTip, rMid)
        XCTAssertLessThan(rMid, rButt)
    }

    // MARK: - Trajectory helpers (realistic contact-neighbourhood kinematics)

    /// Coast +aim with constant decel over 0.4 s, then rest (never returns to origin).
    private static func ballForwardThenStop(t: TimeInterval, v: Float, y: Float) -> SCNVector3 {
        let stopT: Float = 0.4
        let a = v / stopT
        let tf = Float(t)
        let x: Float
        if tf <= stopT {
            x = v * tf - 0.5 * a * tf * tf
        } else {
            x = v * stopT - 0.5 * a * stopT * stopT
        }
        return SCNVector3(x, y, 0)
    }

    /// Forward for 0.25 s at 1.2 m/s (separates from tip), then reverse at 0.55 m/s into shaft.
    private static func ballDrawBack(t: TimeInterval, y: Float) -> SCNVector3 {
        let tRev: Float = 0.25
        let vFwd: Float = 1.2
        let vBack: Float = 0.55
        let tf = Float(t)
        let x: Float
        if tf < tRev {
            x = vFwd * tf
        } else {
            x = vFwd * tRev - vBack * (tf - tRev)
        }
        return SCNVector3(x, y, 0)
    }
}
