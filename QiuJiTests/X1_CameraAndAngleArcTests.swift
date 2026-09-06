import XCTest
import SceneKit
@testable import QiuJi

/// X1 / K3–K4：前向楔形角弧数值钉子 + enterAiming 确定性中档进场。
final class X1_CameraAndAngleArcTests: XCTestCase {

    // MARK: - K3 forward wedge

    /// 坐标契约：SceneKit XZ 水平、Y 上；水平角 atan2(z,x)。
    /// 前向楔形成员方向与瞄准前向点积应为正；旧 aStart+π 背向侧点积为负。
    func testK3_forwardWedgeBisector_onStrikeSide() {
        let cases: [(sx: Float, sz: Float, deg: Float)] = [
            (1, 0, 45),
            (1, 0.2, 30),
            (0, 1, -40),
        ]
        for c in cases {
            let sLen = sqrtf(c.sx * c.sx + c.sz * c.sz)
            let sx = c.sx / sLen, sz = c.sz / sLen
            let aStart = atan2f(sz, sx)
            let aEnd = aStart + c.deg * .pi / 180
            var delta = aEnd - aStart
            if delta > .pi { delta -= 2 * .pi }
            if delta < -.pi { delta += 2 * .pi }

            let fwdMid = aStart + delta * 0.5
            let backMid = fwdMid + .pi
            let fwdDot = cosf(fwdMid) * sx + sinf(fwdMid) * sz
            let backDot = cosf(backMid) * sx + sinf(backMid) * sz
            XCTAssertGreaterThan(fwdDot, 0,
                                 "forward mid should sit on strike-forward side (deg=\(c.deg))")
            XCTAssertLessThan(backDot, 0,
                              "legacy aStart+π mid should sit on backward side (deg=\(c.deg))")
        }
    }

    // MARK: - K4 enterAiming → zoom 0.5

    func testK4_enterAiming_settlesAtMidZoom() {
        let cam = SCNNode()
        cam.camera = SCNCamera()
        let rig = CameraRig(cameraNode: cam, tableSurfaceY: 0.80)
        // Simulate "previous question left far" (v5 stand).
        rig.targetZoom = 1
        rig.snapToTarget()
        XCTAssertEqual(rig.zoom, 1, accuracy: 0.01)

        rig.enterAiming(
            cueBallPosition: SCNVector3(0, 0.8286, 0),
            targetDirection: SCNVector3(1, 0, 0)
        )
        // Drive the 0.6s smooth to completion.
        var steps = 0
        while rig.isTransitioning && steps < 120 {
            rig.update(deltaTime: 1.0 / 60.0)
            steps += 1
        }
        XCTAssertFalse(rig.isTransitioning, "smoothToPose should finish within 2s")
        XCTAssertEqual(rig.zoom, 0.5, accuracy: 0.01,
                       "Each question must settle at the requested midpoint zoom=0.5")
        XCTAssertEqual(cam.camera?.fieldOfView ?? 0, 45, accuracy: 0.01)
        XCTAssertEqual(cam.position.y, 1.775, accuracy: 0.001)
        XCTAssertEqual(cam.eulerAngles.x, -27.75 * .pi / 180, accuracy: 0.001)
        let settledPosition = cam.position
        // Continue normal rendering after the entry animation to catch pose snapping.
        for _ in 0..<60 { rig.update(deltaTime: 1.0 / 60.0) }
        XCTAssertEqual(cam.position.x, settledPosition.x, accuracy: 0.001)
        XCTAssertEqual(cam.position.y, settledPosition.y, accuracy: 0.001)
        XCTAssertEqual(cam.position.z, settledPosition.z, accuracy: 0.001)
        XCTAssertEqual(cam.eulerAngles.x, -27.75 * .pi / 180, accuracy: 0.001)
    }

    func testK4_enterAiming_fromNear_settlesAtMidZoom() {
        let cam = SCNNode()
        cam.camera = SCNCamera()
        let rig = CameraRig(cameraNode: cam, tableSurfaceY: 0.80)
        rig.targetZoom = 0
        rig.snapToTarget()

        rig.enterAiming(
            cueBallPosition: SCNVector3(-0.4, 0.8286, 0.1),
            targetDirection: SCNVector3(0.8, 0, -0.2)
        )
        var steps = 0
        while rig.isTransitioning && steps < 120 {
            rig.update(deltaTime: 1.0 / 60.0)
            steps += 1
        }
        XCTAssertEqual(rig.zoom, 0.5, accuracy: 0.01)
    }
}
