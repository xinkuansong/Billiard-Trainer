import XCTest
@testable import QiuJi

/// v7 W1/C1：经典球厚度通称四元组（name ↔ θ ↔ overlap ↔ d/R）数值锁。
final class BallThicknessNamingTests: XCTestCase {

    func testThreeQuarterBall_classicThickness_matchesD1() {
        let t = AngleSceneCalculator.threeQuarterBall
        XCTAssertEqual(t.name, "3/4 球")
        XCTAssertEqual(t.overlap, 0.75, accuracy: 1e-12)
        // sinθ = 1 − overlap = 0.25 → θ ≈ 14.4775° → display 14.5°
        XCTAssertEqual(t.cutAngleDegrees, 14.5, accuracy: 1e-9)
        XCTAssertEqual(t.dOverR, 0.5, accuracy: 1e-12)
        XCTAssertEqual(
            AngleSceneCalculator.thicknessName(cutAngle: 14.5),
            "3/4 球"
        )
    }

    func testClassicQuartet_identities() {
        let cases: [(AngleSceneCalculator.NamedBallThickness, Double, Double)] = [
            (AngleSceneCalculator.fullBall, 0, 0),
            (AngleSceneCalculator.threeQuarterBall, 14.5, 0.5),
            (AngleSceneCalculator.halfBall, 30, 1),
            (AngleSceneCalculator.quarterBall, 48.6, 1.5),
            (AngleSceneCalculator.thinBall, 90, 2),
        ]
        for (named, angle, dOverR) in cases {
            XCTAssertEqual(named.cutAngleDegrees, angle, accuracy: 0.05,
                           "\(named.name) cut angle")
            XCTAssertEqual(named.dOverR, dOverR, accuracy: 1e-9,
                           "\(named.name) d/R")
            let sinTheta = 1 - named.overlap
            XCTAssertEqual(sin(named.cutAngleDegrees * .pi / 180), sinTheta,
                           accuracy: 1e-3,
                           "\(named.name) sinθ = 1−overlap")
        }
    }

    func testFortyEightPointSix_isQuarterBall_notThreeQuarter() {
        XCTAssertEqual(
            AngleSceneCalculator.thicknessName(cutAngle: 48.6),
            "1/4 球"
        )
        XCTAssertNotEqual(
            AngleSceneCalculator.thicknessName(cutAngle: 48.6),
            "3/4 球"
        )
    }

    /// Legacy offset-fraction nicknames must be gone: under classic thickness,
    /// 7.5° is ~7/8 overlap (not 1/4) and 10° is ~0.83 overlap (not 1/3).
    func testSmallCutAngles_noLegacyOffsetFractionNicknames() {
        for angle in [7.5, 10.0] {
            let name = AngleSceneCalculator.thicknessName(cutAngle: angle)
            XCTAssertFalse(name.contains("1/4"), "θ=\(angle)° must not be named 1/4 球")
            XCTAssertFalse(name.contains("1/3"), "θ=\(angle)° must not be named 1/3 球")
        }
        XCTAssertEqual(AngleSceneCalculator.thicknessName(cutAngle: 7.5), "—")
        XCTAssertEqual(AngleSceneCalculator.thicknessName(cutAngle: 10.0), "—")
    }
}
