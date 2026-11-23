import XCTest
import CoreGraphics
@testable import QiuJi

/// v11 Y1 返工 r1（FL-026）：「瞄准方法」页三定义的几何不变量锁。
/// 口径 = 问题集合 v11.2 §2.1；数值草稿 `build/y1-evidence/y1r1-geometry-draft-selfrun.txt`。
final class AimingMethodsGeometryTests: XCTestCase {

    private let r = AimingMethodsGeometry.ballRadius

    /// ① 恒等式 Pc→Pt == G−C（同向等长），θ 5°–75° 扫描。
    func testContactVectorIdentity_equalsCueToGhost_acrossThetaSweep() {
        for theta in stride(from: 5.0, through: 75.0, by: 5.0) {
            let s = AimingMethodsGeometry.scene(cutAngleDeg: CGFloat(theta))
            let lhs = CGPoint(x: s.targetContact.x - s.cueContact.x,
                              y: s.targetContact.y - s.cueContact.y)
            let rhs = CGPoint(x: s.ghost.x - s.cue.x,
                              y: s.ghost.y - s.cue.y)
            XCTAssertEqual(lhs.x, rhs.x, accuracy: 1e-12, "θ=\(theta)° x 分量")
            XCTAssertEqual(lhs.y, rhs.y, accuracy: 1e-12, "θ=\(theta)° y 分量")
        }
    }

    /// ② 管道相切判定：φ=θ 时两轴最近距 == 2R 且判相切；偏厚/偏薄正确分类。
    func testPipeTangency_distanceEqualsTwoR_andClassification() {
        for theta in [15.0, 30.0, 45.0, 60.0] {
            let s = AimingMethodsGeometry.scene(cutAngleDeg: CGFloat(theta))

            let atTheta = AimingMethodsGeometry.pipeVerdict(scene: s,
                                                            trialAngleDeg: CGFloat(theta))
            XCTAssertEqual(atTheta.distance, 2 * r, accuracy: 1e-9,
                           "θ=\(theta)°: D(φ=θ) 应恰为 2R")
            XCTAssertEqual(atTheta.verdict, .tangent, "θ=\(theta)°: φ=θ 应判相切")

            // 全范围三态扫描：φ<θ 太厚、φ>θ 太薄（含极厚脱靶区消歧，见草稿 P3 附注）。
            for phi in stride(from: 5.0, through: 75.0, by: 2.5) where abs(phi - theta) > 1e-9 {
                let res = AimingMethodsGeometry.pipeVerdict(scene: s,
                                                            trialAngleDeg: CGFloat(phi))
                let expected: AimingMethodsGeometry.PipeVerdict =
                    phi < theta ? .tooThick : .tooThin
                XCTAssertEqual(res.verdict, expected, "θ=\(theta)° φ=\(phi)°")
                if phi > theta {
                    XCTAssertGreaterThan(res.distance, 2 * r, "薄侧应相离 D>2R")
                }
            }

            // 紧邻两侧的距离行为：厚侧相交带内 D<2R（带宽约 7°，草稿实测
            // θ=15/30/45/60 时 φ=θ−2° 均在带内）、薄侧 D>2R。
            let thick = AimingMethodsGeometry.pipeVerdict(scene: s,
                                                          trialAngleDeg: CGFloat(theta - 2))
            let thin = AimingMethodsGeometry.pipeVerdict(scene: s,
                                                         trialAngleDeg: CGFloat(theta + 10))
            XCTAssertLessThan(thick.distance, 2 * r, "θ=\(theta)°: φ=θ−2 应相交 D<2R")
            XCTAssertGreaterThan(thin.distance, 2 * r, "θ=\(theta)°: φ=θ+10 应相离 D>2R")
        }
    }

    /// ③ 碰撞时刻两球心关于接触点 Q 点对称：Q=(G+T)/2=Pt；2Q−T==G。
    func testCollisionSymmetry_centersSymmetricAboutContactPoint() {
        for theta in [10.0, 30.0, 55.0] {
            let s = AimingMethodsGeometry.scene(cutAngleDeg: CGFloat(theta))
            // 碰合动画终点 = 假想球心 G。
            let merged = AimingMethodsGeometry.mergedCueCenter(scene: s, progress: 1)
            XCTAssertEqual(merged.x, s.ghost.x, accuracy: 1e-12)
            XCTAssertEqual(merged.y, s.ghost.y, accuracy: 1e-12)

            // Q = 两球心中点 = Pt。
            XCTAssertEqual(s.contact.x, (s.ghost.x + s.target.x) / 2, accuracy: 1e-12)
            XCTAssertEqual(s.contact.y, (s.ghost.y + s.target.y) / 2, accuracy: 1e-12)
            XCTAssertEqual(s.contact.x, s.targetContact.x, accuracy: 1e-12, "Q == Pt")
            XCTAssertEqual(s.contact.y, s.targetContact.y, accuracy: 1e-12, "Q == Pt")

            // 点对称：2Q − T == G。
            XCTAssertEqual(2 * s.contact.x - s.target.x, s.ghost.x, accuracy: 1e-12)
            XCTAssertEqual(2 * s.contact.y - s.target.y, s.ghost.y, accuracy: 1e-12)

            // 碰合时移动接触点 Pc(1) 与 Pt 重合。
            let pcEnd = AimingMethodsGeometry.movingCueContact(scene: s, progress: 1)
            XCTAssertEqual(pcEnd.x, s.targetContact.x, accuracy: 1e-12)
            XCTAssertEqual(pcEnd.y, s.targetContact.y, accuracy: 1e-12)
        }
    }

    /// 心对点误导角：θ=30°、L=0.42 时 ≈1.84°（草稿 P4 口径）。
    func testMisleadAngle_matchesDraftValue() {
        let s = AimingMethodsGeometry.scene(cutAngleDeg: 30)
        XCTAssertEqual(AimingMethodsGeometry.misleadAngleDeg(scene: s), 1.84, accuracy: 0.05)
    }

    /// 基线几何：|G−T| == 2R、θ 默认 30° == NamedBallThickness.halfBall。
    func testSceneBaseline_ghostDistanceAndDefaultTheta() {
        let s = AimingMethodsGeometry.scene(cutAngleDeg: 30)
        let gt = hypot(s.ghost.x - s.target.x, s.ghost.y - s.target.y)
        XCTAssertEqual(gt, 2 * r, accuracy: 1e-12)
        XCTAssertEqual(AngleSceneCalculator.halfBall.cutAngleDegrees, 30.0, accuracy: 1e-9)
    }

    /// v13 B1：经典厚度 overlap = 1 − sin(θ°) 与 NamedBallThickness / 数值草稿一致。
    func testClassicOverlap_matchesNamedBallThicknessAndDraft() {
        // 草稿金标准：θ=30° → overlap=0.5；θ=45° → 1−√2/2 ≈ 0.292893
        XCTAssertEqual(AimingMethodsGeometry.classicOverlap(cutAngleDegrees: 30),
                       0.5, accuracy: 1e-12)
        XCTAssertEqual(AimingMethodsGeometry.classicOverlap(cutAngleDegrees: 45),
                       1 - sqrt(0.5), accuracy: 1e-12)
        XCTAssertEqual(AimingMethodsGeometry.classicDOverR(cutAngleDegrees: 30),
                       1.0, accuracy: 1e-12)
        XCTAssertEqual(AimingMethodsGeometry.classicDOverR(cutAngleDegrees: 45),
                       sqrt(2.0), accuracy: 1e-12)

        for named in [AngleSceneCalculator.threeQuarterBall,
                      AngleSceneCalculator.halfBall,
                      AngleSceneCalculator.quarterBall] {
            let ov = AimingMethodsGeometry.classicOverlap(
                cutAngleDegrees: named.cutAngleDegrees)
            XCTAssertEqual(ov, named.overlap, accuracy: 1e-3,
                           "\(named.name) θ=\(named.cutAngleDegrees)°")
            let dOverR = AimingMethodsGeometry.classicDOverR(
                cutAngleDegrees: named.cutAngleDegrees)
            XCTAssertEqual(dOverR, named.dOverR, accuracy: 1e-3, named.name)
        }

        // 最近命名厚度（tolerance 2.5°）：30°→半球；~48.6°→1/4 球；45° 无命中。
        XCTAssertEqual(
            AngleSceneCalculator.namedBallThickness(cutAngleDegrees: 30, tolerance: 2.5)?.name,
            "半球")
        XCTAssertEqual(
            AngleSceneCalculator.namedBallThickness(cutAngleDegrees: 49, tolerance: 2.5)?.name,
            "1/4 球")
        XCTAssertNil(
            AngleSceneCalculator.namedBallThickness(cutAngleDegrees: 45, tolerance: 2.5))
    }
}
