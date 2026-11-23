import XCTest
import CoreGraphics
@testable import QiuJi

/// v11 Y2 / v12 Z4：「旋转与加塞」教学路径不变量。
/// 半球锁 90/60/120；切角扫描下示意角仍为教学折线（见 `build/z4-evidence/`）。
final class SpinAndEnglishGeometryTests: XCTestCase {

    func testSeparationInvariants_halfBallScene() {
        let scene = SpinAndEnglishGeometry.scene()
        let stun = SpinAndEnglishGeometry.separationDegrees(scene: scene, state: .stun)
        let follow = SpinAndEnglishGeometry.separationDegrees(scene: scene, state: .follow)
        let draw = SpinAndEnglishGeometry.separationDegrees(scene: scene, state: .draw)

        XCTAssertEqual(stun, 90, accuracy: 1e-6, "stun = 90° (T02)")
        XCTAssertEqual(follow, 60, accuracy: 1e-6, "follow ≈ 60° from n (T01 30° from aim at θ=30°)")
        XCTAssertEqual(draw, 120, accuracy: 1e-6, "draw ≈ 120° from n (T03)")
        XCTAssertLessThan(follow, 90)
        XCTAssertGreaterThan(draw, 90)

        let t = SpinAndEnglishGeometry.tangentDir(scene: scene)
        let dotTN = t.x * scene.potDir.x + t.y * scene.potDir.y
        XCTAssertEqual(dotTN, 0, accuracy: 1e-9, "tangent ⊥ line of centers")

        let followFromAim = SpinAndEnglishGeometry.followAngleFromAimDegrees(scene: scene)
        XCTAssertEqual(followFromAim, 30, accuracy: 1e-6, "T01: follow ≈ 30° from aim at half-ball")
    }

    func testMiscueLimitMatchesCuePhysics() {
        XCTAssertEqual(CuePhysics.miscueLimitFraction, 0.5, accuracy: 0,
                       "打滑极限须引 CuePhysics 真源")
    }

    /// Z4：切角扫描 — 示意分离角相对 n 固定为教学折线 90/60/120（非精确物理分离角）。
    func testTeachingFoldLines_constantAcrossCutAngles() {
        let angles: [CGFloat] = [5, 15, 30, 45, 60, 75]
        for theta in angles {
            let scene = SpinAndEnglishGeometry.scene(cutAngleDeg: theta)
            let stun = SpinAndEnglishGeometry.separationDegrees(scene: scene, state: .stun)
            let follow = SpinAndEnglishGeometry.separationDegrees(scene: scene, state: .follow)
            let draw = SpinAndEnglishGeometry.separationDegrees(scene: scene, state: .draw)
            XCTAssertEqual(stun, 90, accuracy: 1e-5, "θ=\(theta) stun teaching fold")
            XCTAssertEqual(follow, 60, accuracy: 1e-5, "θ=\(theta) follow teaching fold")
            XCTAssertEqual(draw, 120, accuracy: 1e-5, "θ=\(theta) draw teaching fold")

            let t = SpinAndEnglishGeometry.tangentDir(scene: scene)
            let dotTN = t.x * scene.potDir.x + t.y * scene.potDir.y
            XCTAssertEqual(dotTN, 0, accuracy: 1e-8, "θ=\(theta) tangent ⊥ n")
        }

        // 仅半球：follow 相对瞄准线 ≈ 30°；其他切角下 follow_vs_aim = |60−θ|，不当作 T01 口诀。
        let half = SpinAndEnglishGeometry.scene(cutAngleDeg: 30)
        XCTAssertEqual(SpinAndEnglishGeometry.followAngleFromAimDegrees(scene: half),
                       30, accuracy: 1e-5)
        let thin = SpinAndEnglishGeometry.scene(cutAngleDeg: 15)
        XCTAssertEqual(SpinAndEnglishGeometry.followAngleFromAimDegrees(scene: thin),
                       45, accuracy: 1e-5)
    }

    func testSceneCutAngleMatchesAimingMethodsGeometry() {
        let theta: CGFloat = 42
        let a = SpinAndEnglishGeometry.scene(cutAngleDeg: theta)
        let b = AimingMethodsGeometry.scene(cutAngleDeg: theta)
        XCTAssertEqual(a.cutAngleDeg, b.cutAngleDeg, accuracy: 1e-9)
        XCTAssertEqual(a.cue.x, b.cue.x, accuracy: 1e-9)
        XCTAssertEqual(a.ghost.y, b.ghost.y, accuracy: 1e-9)
    }
}
