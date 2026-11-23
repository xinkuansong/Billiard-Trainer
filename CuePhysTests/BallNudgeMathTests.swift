import XCTest
@testable import QiuJi

final class BallNudgeMathTests: XCTestCase {

    /// rotated 顶视契约：屏幕↑=+X、屏幕→=+Z（见 CameraRig.applyTopDown2DRotated）。
    func test_delta_mapsScreenDirectionsToWorldXZ() {
        let s = BallNudgeMath.fineStepMeters
        XCTAssertEqual(s, 0.0005, accuracy: 1e-9, "步进须为 0.5mm")

        let up = BallNudgeMath.delta(for: .up)
        XCTAssertEqual(up.dx, s, accuracy: 1e-9)
        XCTAssertEqual(up.dz, 0, accuracy: 1e-9)

        let down = BallNudgeMath.delta(for: .down)
        XCTAssertEqual(down.dx, -s, accuracy: 1e-9)
        XCTAssertEqual(down.dz, 0, accuracy: 1e-9)

        let left = BallNudgeMath.delta(for: .left)
        XCTAssertEqual(left.dx, 0, accuracy: 1e-9)
        XCTAssertEqual(left.dz, -s, accuracy: 1e-9)

        let right = BallNudgeMath.delta(for: .right)
        XCTAssertEqual(right.dx, 0, accuracy: 1e-9)
        XCTAssertEqual(right.dz, s, accuracy: 1e-9)
    }

    func test_delta_customStep() {
        let d = BallNudgeMath.delta(for: .up, stepMeters: 0.001)
        XCTAssertEqual(d.dx, 0.001, accuracy: 1e-9)
        XCTAssertEqual(d.dz, 0, accuracy: 1e-9)
    }
}
