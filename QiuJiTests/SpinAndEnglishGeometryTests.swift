import XCTest
import CoreGraphics
@testable import QiuJi

/// v11 Y2：「旋转与加塞」教学路径不变量（对齐 `build/y2-evidence/y2-geometry-draft.txt`）。
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
    }

    func testMiscueLimitMatchesCuePhysics() {
        XCTAssertEqual(CuePhysics.miscueLimitFraction, 0.5, accuracy: 0,
                       "打滑极限须引 CuePhysics 真源")
    }
}
