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

    /// T01 图读数：偏折角必须与 contract `theorem-tags.json` T01 的 `key_data` 对得上。
    /// （旧实现把半球特例的 60° 写死在 `departureDir(.follow)` 里，标签又写死「约 30°」，
    /// 导致拖切角时图不动、读数说谎——这里逐档钉死。）
    func testRollingDeflectionMatchesTheoremContract() {
        let deflect = SpinAndEnglishGeometry.rollingDeflectionDegrees(cutAngleDeg:)

        // 端点：正撞与极薄都不偏。
        XCTAssertEqual(deflect(0), 0, accuracy: 1e-9, "θ=0° 直球不偏折")
        XCTAssertEqual(deflect(90), 0, accuracy: 1e-9, "θ=90° 极薄不偏折")

        // contract key_data：极值 33.7° @ 切角 28.1°。
        XCTAssertEqual(deflect(28.1), 33.7, accuracy: 0.1, "极值应 ≈33.7°")
        var peak: (angle: CGFloat, theta: CGFloat) = (0, 0)
        for step in 0...900 where deflect(CGFloat(step) / 10) > peak.angle {
            peak = (deflect(CGFloat(step) / 10), CGFloat(step) / 10)
        }
        XCTAssertEqual(peak.theta, 28.1, accuracy: 0.2, "极值应出现在切角 ≈28.1°")

        // contract valid_cut_range_deg = [14, 49]：整段贴着 30° 走（27°–34°）。
        for step in 140...490 {
            let angle = deflect(CGFloat(step) / 10)
            XCTAssertGreaterThan(angle, 27, "θ=\(CGFloat(step) / 10)° 应仍在 30° 恒定区间下沿之上")
            XCTAssertLessThan(angle, 34, "θ=\(CGFloat(step) / 10)° 不应超过理论极值")
        }

        // 半球：口诀说 30°，实际 33.7°——页内表与图都按实际值走，别再写死 30°。
        XCTAssertEqual(deflect(CGFloat(AngleSceneCalculator.halfBall.cutAngleDegrees)),
                       33.7, accuracy: 0.1, "半球实际偏折 ≈33.7°（口诀取整才是 30°）")
    }

    /// T01 图核心：滚动线相对**原瞄准线**偏 δ(θ)，且与 contract `alternative_method`
    /// 「5/7 沿切线 + 2/7 沿原瞄准线」的向量合成逐档一致（两条独立推导互证）。
    func testRollingFollowDirMatchesFiveSeventhsVectorModel() {
        for theta in thetas {
            let scene = SpinAndEnglishGeometry.scene(cutAngleDeg: theta)
            let dir = SpinAndEnglishGeometry.rollingFollowDir(scene: scene)
            let aim = scene.aimDir
            let tangent = SpinAndEnglishGeometry.tangentDir(scene: scene)

            // 5/7 切线分量 + 2/7 原瞄准线分量。
            let alongTangent = aim.x * tangent.x + aim.y * tangent.y
            var model = CGPoint(x: 5.0 / 7 * alongTangent * tangent.x + 2.0 / 7 * aim.x,
                                y: 5.0 / 7 * alongTangent * tangent.y + 2.0 / 7 * aim.y)
            let len = hypot(model.x, model.y)
            model = CGPoint(x: model.x / len, y: model.y / len)

            XCTAssertEqual(dir.x, model.x, accuracy: 1e-9, "θ=\(theta) 滚动方向应等于 5/7+2/7 合成（x）")
            XCTAssertEqual(dir.y, model.y, accuracy: 1e-9, "θ=\(theta) 滚动方向应等于 5/7+2/7 合成（z）")
            XCTAssertEqual(hypot(dir.x, dir.y), 1, accuracy: 1e-9, "θ=\(theta) 应为单位向量")

            // 图上标注的角 = 瞄准线与滚动线的实际夹角。
            let cosA = max(-1, min(1, dir.x * aim.x + dir.y * aim.y))
            XCTAssertEqual(acos(cosA) * 180 / .pi,
                           SpinAndEnglishGeometry.rollingDeflectionDegrees(cutAngleDeg: theta),
                           accuracy: 1e-6, "θ=\(theta) 标签读数应等于图上实际夹角")

            // 滚动线永远落在切线与瞄准线之间（自然滚动被摩擦拽回瞄准线一侧）。
            let sep = SpinAndEnglishGeometry.separationDegrees(scene: scene, state: .stun)
            XCTAssertEqual(sep, 90, accuracy: 1e-6)
            let fromN = acos(max(-1, min(1, dir.x * scene.potDir.x + dir.y * scene.potDir.y)))
                * 180 / .pi
            XCTAssertGreaterThan(fromN, theta, "θ=\(theta) 滚动线应在瞄准线的切线一侧")
            XCTAssertLessThan(fromN, 90, "θ=\(theta) 滚动线不应越过切线")
        }
    }

    /// 页面主张「拖切角时滚动线会跟着动」：方向必须真随 θ 变（旧实现固定在 n+60°，不动）。
    func testRollingFollowDirTracksCutAngle() {
        var previous: CGPoint?
        for theta in thetas {
            let dir = SpinAndEnglishGeometry.rollingFollowDir(
                scene: SpinAndEnglishGeometry.scene(cutAngleDeg: theta)
            )
            if let previous {
                XCTAssertGreaterThan(hypot(dir.x - previous.x, dir.y - previous.y), 1e-3,
                                     "θ=\(theta) 滚动线方向应随切角变化")
            }
            previous = dir
        }
    }

    /// T01 图（`RollThirtyDegreeFigure`）θ 全域取景：母球、滚动线终点、瞄准线延长端都不出框。
    func testRollFigurePointsStayInsideViewport() {
        let center = CGPoint(x: 0.40, y: -0.16)
        let halfHeight: CGFloat = 0.36
        let halfWidth = halfHeight * 1.3

        for theta in thetas {
            let scene = SpinAndEnglishGeometry.scene(cutAngleDeg: theta)
            let aim = scene.aimDir
            let points: [CGPoint] = [
                scene.cue,
                scene.ghost,
                scene.target,
                SpinAndEnglishGeometry.objectBallEnd(scene: scene),
                SpinAndEnglishGeometry.rollingFollowEnd(scene: scene, length: 0.28),
                CGPoint(x: scene.ghost.x + aim.x * 0.20, y: scene.ghost.y + aim.y * 0.20),
            ]
            for p in points {
                XCTAssertLessThanOrEqual(abs(p.x - center.x), halfWidth, "θ=\(theta) 点 \(p) 横向出框")
                XCTAssertLessThanOrEqual(abs(p.y - center.y), halfHeight, "θ=\(theta) 点 \(p) 纵向出框")
            }
        }
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
