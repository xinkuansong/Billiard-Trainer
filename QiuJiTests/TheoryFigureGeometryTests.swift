import XCTest
import CoreGraphics
@testable import QiuJi

/// v30 W1 返工 r1：球理页说明图所依赖的几何不变量。
///
/// 坐标契约：SceneKit 世界台面米坐标，水平面 X–Z（`CGPoint.x` = X，`.y` = Z），
/// Y 朝上，原点台心，单位米。图（`TheoryT03View.TangentPerpendicularFigure`）
/// 只做「真源点 → 视图点」的投影与描线，故这里锁真源不变量即锁图。
///
/// 图元 ↔ 真源映射（返工汇报同款表）：
/// - 连心线 ← `scene.ghost` → `scene.target`（方向恒 = `scene.potDir`，长度恒 2R）
/// - 切线 ← `SpinAndEnglishGeometry.tangentDir(scene:)`，与 `potDir` 点积恒 0
/// - 直角标记两边 ← 同上两向量 ⇒ 世界直角；投影为均匀缩放线性映射 ⇒ 屏上仍是直角
/// - 接触点 ← `scene.contact`（= 两球心中点，= `scene.targetContact`）
final class TheoryFigureGeometryTests: XCTestCase {

    /// 页级 θ 滑条范围（`LearnControlStrip.Theta.defaultRange` = 5…75）全域扫描。
    private let thetas: [CGFloat] = [5, 12, 20, 30, 42, 55, 68, 75]

    /// 主图核心断言：切线 ⊥ 连心线，且连心线方向 = 进球方向、长度 = 2R。
    func testTangentFigureInvariants_acrossSliderRange() {
        let r = CGFloat(AngleSceneCalculator.ballRadius)
        for theta in thetas {
            let scene = SpinAndEnglishGeometry.scene(cutAngleDeg: theta)
            let n = scene.potDir
            let t = SpinAndEnglishGeometry.tangentDir(scene: scene)

            // 连心线（假想球心 → 目标球心）：方向 = n、长度 = 2R。
            let centers = CGPoint(x: scene.target.x - scene.ghost.x,
                                  y: scene.target.y - scene.ghost.y)
            let centersLen = hypot(centers.x, centers.y)
            XCTAssertEqual(centersLen, 2 * r, accuracy: 1e-9,
                           "θ=\(theta) 两球心距应恒为 2R")
            XCTAssertEqual(centers.x / centersLen, n.x, accuracy: 1e-9,
                           "θ=\(theta) 连心线方向应 = 进球方向 n（x）")
            XCTAssertEqual(centers.y / centersLen, n.y, accuracy: 1e-9,
                           "θ=\(theta) 连心线方向应 = 进球方向 n（z）")

            // 切线 ⊥ 连心线 —— 图上直角标记的唯一依据。
            XCTAssertEqual(t.x * centers.x + t.y * centers.y, 0, accuracy: 1e-9,
                           "θ=\(theta) 切线应垂直于连心线")
            XCTAssertEqual(hypot(t.x, t.y), 1, accuracy: 1e-9, "θ=\(theta) 切线方向应为单位向量")

            // 接触点 = 两球心中点，也是目标球背袋接触点（图上绿点位置）。
            XCTAssertEqual(scene.contact.x, scene.targetContact.x, accuracy: 1e-9)
            XCTAssertEqual(scene.contact.y, scene.targetContact.y, accuracy: 1e-9)
            let toContact = hypot(scene.contact.x - scene.ghost.x,
                                  scene.contact.y - scene.ghost.y)
            XCTAssertEqual(toContact, r, accuracy: 1e-9, "θ=\(theta) 接触点应距假想球心 R")
        }
    }

    /// 页面主张「拖动切角只挪母球，切线不动」：切线方向与 θ 无关。
    func testTangentDirectionIsIndependentOfCutAngle() {
        let base = SpinAndEnglishGeometry.tangentDir(
            scene: SpinAndEnglishGeometry.scene(cutAngleDeg: 30)
        )
        for theta in thetas {
            let t = SpinAndEnglishGeometry.tangentDir(
                scene: SpinAndEnglishGeometry.scene(cutAngleDeg: theta)
            )
            XCTAssertEqual(t.x, base.x, accuracy: 1e-9, "θ=\(theta) 切线方向不应随切角变化")
            XCTAssertEqual(t.y, base.y, accuracy: 1e-9, "θ=\(theta) 切线方向不应随切角变化")
        }

        // 母球确实随 θ 变位（否则滑条无意义）。
        let cue5 = SpinAndEnglishGeometry.scene(cutAngleDeg: 5).cue
        let cue75 = SpinAndEnglishGeometry.scene(cutAngleDeg: 75).cue
        XCTAssertGreaterThan(hypot(cue75.x - cue5.x, cue75.y - cue5.y), 0.2,
                            "母球应随切角明显移动")
    }

    /// 复用的三路径图（`SeparationPathsFigure`）在 θ 全域内三条端点都落在取景窗内，
    /// 取景 = `closeup(center: (0.40, −0.16), halfHeight: 0.36)`，窗口按最小宽高比 1.3 保守估。
    func testSeparationPathEndsStayInsideFigureViewport() {
        let center = CGPoint(x: 0.40, y: -0.16)
        let halfHeight: CGFloat = 0.36
        let conservativeAspect: CGFloat = 1.3
        let halfWidth = halfHeight * conservativeAspect

        for theta in thetas {
            let scene = SpinAndEnglishGeometry.scene(cutAngleDeg: theta)
            var points: [CGPoint] = [scene.cue, scene.ghost, scene.target, scene.contact,
                                     SpinAndEnglishGeometry.objectBallEnd(scene: scene)]
            for state in SpinAndEnglishGeometry.SpinState.allCases {
                points.append(SpinAndEnglishGeometry.pathEnd(scene: scene, state: state))
            }
            // 主图额外画到的两端：切线 ±0.20m、连心线后延 0.13m。
            let t = SpinAndEnglishGeometry.tangentDir(scene: scene)
            let n = scene.potDir
            points.append(CGPoint(x: scene.contact.x + t.x * 0.20, y: scene.contact.y + t.y * 0.20))
            points.append(CGPoint(x: scene.contact.x - t.x * 0.20, y: scene.contact.y - t.y * 0.20))
            points.append(CGPoint(x: scene.ghost.x - n.x * 0.13, y: scene.ghost.y - n.y * 0.13))

            for p in points {
                XCTAssertLessThanOrEqual(abs(p.x - center.x), halfWidth,
                                         "θ=\(theta) 点 \(p) 横向出框")
                XCTAssertLessThanOrEqual(abs(p.y - center.y), halfHeight,
                                         "θ=\(theta) 点 \(p) 纵向出框")
            }
        }
    }

    // MARK: - v30 W2：T01 滚动偏约 30° / T02 滑动分离 90°

    /// T02 图核心：任意 θ 下滑动出发方向 ⊥ 进球方向，分离角恒 90°。
    func testStunSeparationIsNinetyAcrossSliderRange() {
        for theta in thetas {
            let scene = SpinAndEnglishGeometry.scene(cutAngleDeg: theta)
            let sep = SpinAndEnglishGeometry.separationDegrees(scene: scene, state: .stun)
            XCTAssertEqual(sep, 90, accuracy: 1e-6, "θ=\(theta) 滑动分离角应恒为 90°")

            let t = SpinAndEnglishGeometry.tangentDir(scene: scene)
            let stun = SpinAndEnglishGeometry.departureDir(scene: scene, state: .stun)
            XCTAssertEqual(t.x, stun.x, accuracy: 1e-9, "θ=\(theta) 滑动出发 = 切线（x）")
            XCTAssertEqual(t.y, stun.y, accuracy: 1e-9, "θ=\(theta) 滑动出发 = 切线（z）")
            XCTAssertEqual(t.x * scene.potDir.x + t.y * scene.potDir.y, 0, accuracy: 1e-9,
                           "θ=\(theta) 切线应 ⊥ 进球方向")
        }
    }

    /// T01 图核心：半球 θ=30° 时前旋/滚动教学折线相对瞄准线 ≈30°；
    /// 且滚动出发方向随 θ 变化（与「切线不随 θ」对照）。
    func testFollowAngleFromAimAtHalfBallIsAboutThirty() {
        let half = CGFloat(AngleSceneCalculator.halfBall.cutAngleDegrees)
        let scene = SpinAndEnglishGeometry.scene(cutAngleDeg: half)
        let angle = SpinAndEnglishGeometry.followAngleFromAimDegrees(scene: scene)
        XCTAssertEqual(angle, 30, accuracy: 0.5,
                       "半球教学折线相对瞄准线应 ≈30°（T01 口诀）")

        // 路径端点应落在与 T03 相同取景窗内（RollThirtyDegreeFigure 同 closeup）。
        let center = CGPoint(x: 0.40, y: -0.16)
        let halfHeight: CGFloat = 0.36
        let halfWidth = halfHeight * 1.3
        let end = SpinAndEnglishGeometry.pathEnd(scene: scene, state: .follow)
        XCTAssertLessThanOrEqual(abs(end.x - center.x), halfWidth)
        XCTAssertLessThanOrEqual(abs(end.y - center.y), halfHeight)
    }

    /// T04 页表数字必须与代码五档真源一致（防正文手抄漂移）。
    func testAppSpeedLevelsMatchStrokePhysicsConstants() {
        let expected: [(Int, Float)] = [
            (1, 1.6), (2, 2.4), (3, 3.3), (4, 4.4), (5, 5.8),
        ]
        let levels = StrokePhysics.SpeedLevel.allCases
        XCTAssertEqual(levels.count, 5, "App 落地为五档（T04 业余推荐）")
        for (level, pair) in zip(levels, expected) {
            XCTAssertEqual(level.rawValue, pair.0)
            XCTAssertEqual(level.velocity, pair.1, accuracy: 1e-6,
                           "SpeedLevel.\(level) 杆速应与 BTPhysicsConstants 一致")
        }
    }
}
