import XCTest
import SceneKit
@testable import QiuJi

/// X1 / K3–K4：前向楔形角弧数值钉子 + enterAiming 确定性中档进场。
final class X1_CameraAndAngleArcTests: XCTestCase {

    @MainActor
    func testAimPointQuestionCyclesKeepBallsVisibleAndObservationPreservesAim() throws {
        let suite = "v63.question-camera." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let limiter = AngleUsageLimiter(defaults: defaults)
        limiter.isPremium = true
        let vm = AimPointSceneQuizViewModel(limiter: limiter)
        vm.setupScene(cameraMode: .perspective3D)
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 375, height: 480))
        view.scene = vm.scene
        view.pointOfView = vm.scene.cameraNode
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        rig.viewportSize = view.bounds.size
        for cycle in 0..<3 {
            vm.nextQuestion()
            rig.snapToTarget()
            SCNTransaction.flush()
            let question = try XCTUnwrap(vm.question)
            let cue = try XCTUnwrap(vm.scene.cueBallNode)
            let target = try XCTUnwrap(vm.scene.targetBallNodes.first)
            for node in [cue, target] {
                XCTAssertNotNil(node.parent)
                XCTAssertFalse(node.isHidden)
                XCTAssertGreaterThan(node.opacity, 0)
                let projected = view.projectPoint(vm.scene.visualCenter(of: node))
                XCTAssertTrue(view.bounds.contains(CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))), "cycle=\(cycle), point=\(projected)")
                XCTAssertGreaterThan(projected.z, 0)
                XCTAssertLessThan(projected.z, 1)
            }
            vm.nudgeAim(byDegrees: 2)
            let cuePose = cue.simdTransform
            let targetPose = target.simdTransform
            let stick = try XCTUnwrap(vm.scene.cueStick?.rootNode)
            let aimPose = stick.simdTransform
            XCTAssertTrue(rig.observeWholeTable())
            rig.observe(at: vm.scene.visualCenter(of: target))
            vm.applyAimingPoseIfNeeded()
            rig.snapToTarget()
            XCTAssertEqual(cue.simdTransform, cuePose)
            XCTAssertEqual(target.simdTransform, targetPose)
            XCTAssertEqual(stick.simdTransform, aimPose)
            XCTAssertEqual(vm.question?.cueBall, question.cueBall)
            XCTAssertEqual(vm.question?.targetBall, question.targetBall)
            XCTAssertEqual(vm.phase, .aiming)
            XCTAssertTrue(vm.sessionResults.isEmpty)
            XCTAssertNil(vm.lastErrorMM)
        }
    }

    /// World X/Z table plane, Y up, metres. Verify SceneKit's actual projection,
    /// independently of the fit solver's hand-written basis vectors.
    @MainActor
    func testWholeTableFitProjectsCenterAndOuterCornersIntoViewport() {
        for size in [CGSize(width: 375, height: 480), CGSize(width: 402, height: 630), CGSize(width: 744, height: 850)] {
            let view = SCNView(frame: CGRect(origin: .zero, size: size))
            let scene = SCNScene()
            let camera = SCNNode()
            camera.camera = SCNCamera()
            scene.rootNode.addChildNode(camera)
            view.scene = scene
            view.pointOfView = camera
            let rig = CameraRig(cameraNode: camera, tableSurfaceY: 0.8)
            rig.viewportSize = size
            for index in 0..<8 {
                let yaw = Float(index) * .pi / 4
                // Composer replaces a 94pt palette with a 46pt observation bar.
                rig.viewportSize = CGSize(width: size.width, height: size.height - 48)
                XCTAssertTrue(rig.observeWholeTable(yaw: yaw))
                rig.viewportSize = size
                rig.snapToTarget()
                SCNTransaction.flush()
                view.layoutIfNeeded()
                let center = view.projectPoint(SCNVector3(0, 0.8 + BallPhysics.radius, 0))
                let label = "size=\(size) yaw=\(yaw)"
                XCTAssertEqual(CGFloat(center.x), size.width / 2, accuracy: 1, label)
                XCTAssertEqual(CGFloat(center.y), size.height / 2, accuracy: 1, label)
                for x in [-Float(rig.tableOuterHalfLength), Float(rig.tableOuterHalfLength)] {
                    for z in [-Float(rig.tableOuterHalfWidth), Float(rig.tableOuterHalfWidth)] {
                        let p = view.projectPoint(SCNVector3(x, 0.8, z))
                        XCTAssertGreaterThanOrEqual(p.x, 0, label)
                        XCTAssertLessThanOrEqual(CGFloat(p.x), size.width, label)
                        XCTAssertGreaterThanOrEqual(p.y, 0, label)
                        XCTAssertLessThanOrEqual(CGFloat(p.y), size.height, label)
                        XCTAssertGreaterThan(p.z, 0, label)
                        XCTAssertLessThan(p.z, 1, label)
                    }
                }
            }
        }
    }

    func testWholeTableResizeDoesNotOverrideManualCamera() {
        let camera = SCNNode()
        camera.camera = SCNCamera()
        let rig = CameraRig(cameraNode: camera, tableSurfaceY: 0.8)
        rig.viewportSize = CGSize(width: 402, height: 584)
        XCTAssertTrue(rig.observeWholeTable(yaw: 0.7))
        rig.snapToTarget()
        rig.handlePinch(scale: 1.2)
        rig.handleHorizontalSwipe(delta: 20)
        rig.snapToTarget()
        let position = camera.position
        let yaw = rig.targetYaw
        let saved = rig.capturePerspectiveState()
        rig.viewportSize = CGSize(width: 402, height: 632)
        rig.snapToTarget()
        XCTAssertEqual(camera.position.x, position.x, accuracy: 0.00001)
        XCTAssertEqual(camera.position.y, position.y, accuracy: 0.00001)
        XCTAssertEqual(camera.position.z, position.z, accuracy: 0.00001)
        rig.restorePerspectiveState(saved)
        rig.viewportSize = CGSize(width: 375, height: 480)
        rig.snapToTarget()
        XCTAssertEqual(rig.targetYaw, yaw, accuracy: 0.00001)
        XCTAssertEqual(camera.position.x, position.x, accuracy: 0.00001)
        XCTAssertEqual(camera.position.y, position.y, accuracy: 0.00001)
        XCTAssertEqual(camera.position.z, position.z, accuracy: 0.00001)
    }

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
