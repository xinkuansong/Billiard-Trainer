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
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 874, height: 402))
        view.scene = vm.scene
        view.pointOfView = vm.scene.cameraNode
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        rig.viewportSize = view.bounds.size
        for cycle in 0..<3 {
            vm.nextQuestion()
            for _ in 0..<1200 { rig.update(deltaTime: 1 / 120) }
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
            vm.requestSurfaceOverview()
            for _ in 0..<1200 { rig.update(deltaTime: 1 / 120) }
            XCTAssertTrue(rig.overviewControlSelected)
            vm.beginCameraObservation()
            vm.endCameraObservation()
            vm.applyAimingPoseIfNeeded()
            for _ in 0..<1200 { rig.update(deltaTime: 1 / 120) }
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

    @MainActor
    func testTrainingSingleLineTitlesFitExistingReservation() {
        let font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        for title in ["2D角度", "3D角度", "2D瞄准点", "3D瞄准点"] {
            let width = (title as NSString).size(withAttributes: [.font: font]).width
            print("Training title width: \(title) = \(width) / 60pt")
            XCTAssertLessThanOrEqual(width, 60)
        }
    }

    @MainActor
    func testAimPointUsesSharedCameraAndTemporaryStateWithoutChangingAnswer() throws {
        let suite = "p10-camera-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName:suite))
        defer { defaults.removePersistentDomain(forName:suite) }
        let limiter = AngleUsageLimiter(defaults:defaults); limiter.isPremium = true
        let vm = AimPointSceneQuizViewModel(limiter:limiter)
        vm.setupScene(cameraMode:.perspective3D)
        defer { vm.stopTraining() }
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        rig.viewportSize = CGSize(width:874,height:402)
        vm.applyAimingPoseIfNeeded()
        XCTAssertTrue(rig.usesTwoViewCameraControls)
        let question = try XCTUnwrap(vm.question)
        vm.nudgeAim(byDegrees:2)
        let aim = try XCTUnwrap(vm.currentPlayerAim)
        for mode: CameraRig.PlayerView in [.firstPerson,.thirdPerson] {
            XCTAssertTrue(vm.requestPlayerView(mode,animated:false))
            XCTAssertEqual(vm.currentPlayerAim?.x,aim.x)
            XCTAssertEqual(vm.currentPlayerAim?.z,aim.z)
        }
        vm.beginTemporaryTopDown()
        XCTAssertTrue(vm.temporaryTopDownActive)
        let revision = vm.topDownContentRevision
        vm.nudgeAim(byDegrees:1)
        XCTAssertGreaterThan(vm.topDownContentRevision,revision)
        vm.endTemporaryTopDown()
        XCTAssertFalse(vm.temporaryTopDownActive)
        XCTAssertEqual(vm.question?.cueBall,question.cueBall)
        XCTAssertTrue(vm.sessionResults.isEmpty)
        XCTAssertFalse(try XCTUnwrap(vm.scene.cueStick).rootNode.isHidden)
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

@MainActor
final class AngleDiagramAnnotationTests: XCTestCase {
    func testAtlasAngleUsesSharedOverlayWithoutLineNames() throws {
        let vm = SeparationAngleAtlasViewModel(); vm.setupScene()
        let scene = vm.scene
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 874, height: 402))
        view.scene = scene; view.pointOfView = scene.cameraNode
        let rig = try XCTUnwrap(scene.cameraRig)
        rig.viewportSize = view.bounds.size
        scene.setCameraMode(.topDown2D, animated: false)
        rig.snapToTarget(); SCNTransaction.flush()
        let overlay = DiagramLabelOverlay()
        let g = try XCTUnwrap(scene.diagramLabelGeometry)
        XCTAssertEqual(scene.pocketLineNode?.isHidden, false)
        XCTAssertEqual(scene.angleArcNode?.isHidden, false)
        for showNames in [false, true, false] {
            scene.updateVisualization(cueBall: g.cue, targetBall: g.target, pocket: g.pocket,
                                      showLineLabels: showNames)
            overlay.update(scene: scene, in: view)
            let labels = view.subviews.compactMap { $0 as? UILabel }
            XCTAssertFalse(try XCTUnwrap(labels.first { $0.accessibilityIdentifier == "angleDiagram.label.0" }).isHidden)
            XCTAssertEqual(labels.filter { !$0.isHidden }.count, showNames ? 3 : 1)
            XCTAssertEqual(labels.first?.text, "\(Int(vm.cutAngleDegrees.rounded()))°")
        }
    }

    func testDiagramCacheTracksRendererProjectionEvenWhenSceneCameraIsUnchanged() throws {
        let vm = SeparationAngleAtlasViewModel(); vm.setupScene()
        let scene = vm.scene
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 874, height: 402))
        view.scene = scene; view.pointOfView = scene.cameraNode
        let rig = try XCTUnwrap(scene.cameraRig)
        rig.viewportSize = view.bounds.size
        scene.setCameraMode(.topDown2D, animated: false)
        rig.snapToTarget(); SCNTransaction.flush()
        let overlay = DiagramLabelOverlay()
        overlay.update(scene: scene, in: view)
        let camera = try XCTUnwrap(scene.cameraNode).clone()
        camera.camera = try XCTUnwrap(scene.cameraNode?.camera?.copy() as? SCNCamera)
        scene.rootNode.addChildNode(camera)
        view.pointOfView = camera
        // The renderer's actual projection can change without changing the scene's cached camera inputs.
        for shift: Float in [0.12, -0.08, 0] {
            camera.position.x = try XCTUnwrap(scene.cameraNode).position.x + shift
            SCNTransaction.flush()
            overlay.update(scene: scene, in: view)
            let d = overlay.diagnostic(in: view, scene: scene)
            let actual = try XCTUnwrap(d["arcStart"] as? [CGFloat])
            let expected = try XCTUnwrap(d["expectedArcStart"] as? [CGFloat])
            XCTAssertEqual(actual[0], expected[0], accuracy: 0.01)
            XCTAssertEqual(actual[1], expected[1], accuracy: 0.01)
        }
    }

    func testTemporaryTeachingLabelsUseOverlayProjectionWithoutMutatingMainScene() throws {
        let vm = SeparationAngleAtlasViewModel(); vm.setupScene()
        let scene = vm.scene
        let rig = try XCTUnwrap(scene.cameraRig)
        let size = CGSize(width: 874, height: 402)
        rig.viewportSize = size
        vm.setCameraMode(.perspective3D)
        vm.beginTemporaryTopDown()
        let frame = try XCTUnwrap(rig.temporaryTopDownOverlayFrame)
        let main = SCNView(frame: CGRect(origin: .zero, size: size))
        main.scene = scene; main.pointOfView = scene.cameraNode
        let mainLabels = DiagramLabelOverlay()
        mainLabels.update(scene: scene, in: main)
        let sourcePose = try XCTUnwrap(scene.cameraNode).simdWorldTransform
        let arcs = try XCTUnwrap(scene.angleArcNode).childNodes.filter { $0.name == "diagramTableArc" }
        XCTAssertFalse(arcs.isEmpty)
        XCTAssertTrue(arcs.allSatisfy { !$0.isHidden })
        let overlay = SCNView(frame: main.bounds)
        overlay.scene = scene.makeTemporaryTopDownRenderScene()
        let camera = SCNNode(); camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = frame.orthographicScale
        camera.camera?.zNear = 0.01; camera.camera?.zFar = 100
        camera.simdPosition = frame.eye
        camera.look(at: SCNVector3(frame.target.x, frame.target.y, frame.target.z),
                    up: SCNVector3(frame.up.x, frame.up.y, frame.up.z), localFront: SCNVector3(0, 0, -1))
        overlay.scene?.rootNode.addChildNode(camera); overlay.pointOfView = camera
        SCNTransaction.flush()
        let labels = DiagramLabelOverlay()
        for _ in 0..<2 {
            labels.update(scene: scene, in: overlay, projectionMode: .topDown2D)
            let result = labels.diagnostic(in: overlay, scene: scene)
            XCTAssertEqual(result["labelHidden"] as? Bool, false)
            XCTAssertEqual(result["arcHidden"] as? Bool, false)
            XCTAssertEqual(overlay.subviews.compactMap { $0 as? UILabel }.filter { !$0.isHidden }.count, 1)
            XCTAssertEqual(try XCTUnwrap(scene.cameraNode).simdWorldTransform, sourcePose)
            XCTAssertTrue(arcs.allSatisfy { !$0.isHidden }, "Overlay labels must not hide main-scene arcs")
            labels.hide()
            XCTAssertEqual(labels.diagnostic(in: overlay, scene: scene)["labelHidden"] as? Bool, true)
        }
        vm.endTemporaryTopDown()
    }

    func testAimRaySplitsAtVisibleRadiusAcrossDirections() throws {
        let r = AngleSceneCalculator.ballRadius
        for degrees in stride(from: 0, to: 360, by: 15) {
            let a = Float(degrees) * .pi / 180
            let u = SCNVector3(cosf(a), 0, sinf(a))
            for offset in [Float(0), r * 0.5, r * 0.999, r * 1.01, r * 1.5] {
                let target = SCNVector3(u.x * 0.5 - u.z * offset, 0.8, u.z * 0.5 + u.x * offset)
                let hit = AngleSceneCalculator.aimRayTargetEntry(from: SCNVector3(0, 0.8, 0),
                    toward: SCNVector3(u.x, 0.8, u.z), target: target)
                if offset > r {
                    XCTAssertNil(hit, "Visible line misses disk even though a moving ball could collide")
                } else {
                    let point = try XCTUnwrap(hit)
                    XCTAssertEqual(hypotf(point.x-target.x, point.z-target.z), r, accuracy: 1e-5)
                    XCTAssertEqual(point.x*u.z-point.z*u.x, 0, accuracy: 1e-5)
                    XCTAssertLessThan(point.x*u.x+point.z*u.z, 0.5)
                }
            }
        }
        XCTAssertNil(AngleSceneCalculator.aimRayTargetEntry(from: SCNVector3Zero,
            toward: SCNVector3(1,0,0), target: SCNVector3(-0.5,0,0)))
        XCTAssertNil(AngleSceneCalculator.aimRayTargetEntry(from: SCNVector3Zero,
            toward: SCNVector3(0.1,0,0), target: SCNVector3(0.5,0,0)))
    }

    func testSegmentRectangleClipping() {
        let rect = CGRect(x: 10, y: 10, width: 20, height: 20)
        XCTAssertTrue(DiagramLabelOverlay.segment(.zero, CGPoint(x: 40,y: 40), intersects: rect))
        XCTAssertTrue(DiagramLabelOverlay.segment(CGPoint(x: 0,y: 10), CGPoint(x: 40,y: 10), intersects: rect))
        XCTAssertFalse(DiagramLabelOverlay.segment(CGPoint(x: 0,y: 9), CGPoint(x: 40,y: 9), intersects: rect))
        XCTAssertFalse(DiagramLabelOverlay.segment(.zero, CGPoint(x: 9,y: 9), intersects: rect))
    }

    func testSmallAngleLabelMovesLocallyAsAngleChanges() throws {
        let scene = AngleTrainingScene(); scene.usesAdaptiveDiagramLabels = true
        scene.setupScene(); scene.setupVisualizationNodes()
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 402, height: 650))
        view.scene = scene; view.pointOfView = scene.cameraNode
        let overlay = DiagramLabelOverlay()
        let rig = try XCTUnwrap(scene.cameraRig)
        rig.viewportSize = view.bounds.size
        scene.setCameraMode(.topDown2DRotated, animated: false)
        rig.fitRotatedTable(viewSize: view.bounds.size); rig.applyTopDown2DRotated()
        rig.snapToTarget(); SCNTransaction.flush()
        let y = scene.surfaceY + AngleSceneCalculator.ballRadius
        let target = SCNVector3(0.25, y, 0), pocket = SCNVector3(1.27, y, 0)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: pocket,
                                                          ballRadius: AngleSceneCalculator.ballRadius)
        var previous: CGPoint?
        var previousWasSide = false
        for degrees in 1...20 {
            let a = Float(degrees) * .pi / 180
            let cue = SCNVector3(ghost.x - 0.65*cosf(a), y, ghost.z - 0.65*sinf(a))
            scene.hideAllBalls()
            scene.showBall(key: PositionPlayBall.cueKey, scenePosition: cue)
            scene.showBall(key: "_8", scenePosition: target)
            scene.setCurrentTargetNumber(8)
            scene.updateVisualization(cueBall: cue, targetBall: target, pocket: pocket)
            SCNTransaction.flush(); overlay.update(scene: scene, in: view)
            let label = try XCTUnwrap(view.subviews.compactMap { $0 as? UILabel }.first {
                $0.accessibilityIdentifier == "angleDiagram.label.0" && !$0.isHidden
            })
            let gs = view.projectPoint(ghost), cs = view.projectPoint(cue)
            let ts = view.projectPoint(target), ps = view.projectPoint(pocket)
            let aim = atan2(CGFloat(gs.y-cs.y), CGFloat(gs.x-cs.x))
            let pot = atan2(CGFloat(ps.y-ts.y), CGFloat(ps.x-ts.x))
            let sweep = atan2(sin(pot-aim), cos(pot-aim))
            let direction = atan2(label.center.y-CGFloat(gs.y), label.center.x-CGFloat(gs.x))
            let delta = atan2(sin(direction-aim), cos(direction-aim))
            let isSide = delta * sweep < 0 || abs(delta) > abs(sweep) + 0.001
            if let previous, previousWasSide && isSide {
                XCTAssertLessThan(hypot(label.center.x-previous.x, label.center.y-previous.y), 16,
                                  "Side label jumped at \(degrees) degrees")
            }
            previousWasSide = isSide
            XCTAssertEqual(label.layer.shadowOpacity, 0)
            previous = label.center
        }
    }

    func testDiagramLabelsAcrossAnglesDistancesAndCameraModes() throws {
        let scene = AngleTrainingScene(); scene.usesAdaptiveDiagramLabels = true
        scene.setupScene(); scene.setupVisualizationNodes()
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 402, height: 650))
        view.scene = scene; view.pointOfView = scene.cameraNode
        let overlay = DiagramLabelOverlay()
        let rig = try XCTUnwrap(scene.cameraRig)
        rig.viewportSize = view.bounds.size
        let y = scene.surfaceY + AngleSceneCalculator.ballRadius
        var cases = 0
        for mode: AngleTrainingScene.CameraMode in [.topDown2DRotated, .perspective3D] {
            scene.setCameraMode(mode, animated: false)
            if mode == .perspective3D { _ = rig.observeWholeTable() }
            else { rig.fitRotatedTable(viewSize: view.bounds.size); rig.applyTopDown2DRotated() }
            rig.snapToTarget(); SCNTransaction.flush(); view.layoutIfNeeded()
            for targetZ: Float in [0, 0.54, -0.54] {
                for degrees: Float in [0, 10, 29, 30, 60, 85] {
                    for distance: Float in [0.09, 0.65] {
                        let a = degrees * .pi / 180
                        let target = SCNVector3(0.25,y,targetZ)
                        let pocket = SCNVector3(1.27,y,targetZ)
                        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: pocket,
                            ballRadius: AngleSceneCalculator.ballRadius)
                        let cue = SCNVector3(ghost.x-distance*cosf(a),y,ghost.z-distance*sinf(a))
                        // Mirror the inward direction near the lower rail to retain legal table layouts.
                        guard abs(cue.z) < 0.60 else { continue }
                        scene.hideAllBalls()
                        scene.showBall(key: PositionPlayBall.cueKey, scenePosition: cue)
                        scene.showBall(key: "_8", scenePosition: target)
                        scene.setCurrentTargetNumber(8)
                        scene.updateVisualization(cueBall: cue, targetBall: target, pocket: pocket)
                        SCNTransaction.flush()
                        overlay.update(scene: scene, in: view)
                        let labels = view.subviews.compactMap { $0 as? UILabel }.filter { !$0.isHidden }
                        XCTAssertEqual(labels.count, 3, "Missing label \(view.subviews.compactMap { $0 as? UILabel }.filter { $0.isHidden }.compactMap { $0.text }): mode=\(mode), z=\(targetZ), angle=\(degrees), distance=\(distance)")
                        if degrees > 0 {
                            let valueLabel = try XCTUnwrap(labels.first { $0.accessibilityIdentifier == "angleDiagram.label.0" })
                            let gs = view.projectPoint(ghost), cs = view.projectPoint(cue)
                            let ts = view.projectPoint(target), ps = view.projectPoint(pocket)
                            let aimAngle = atan2(CGFloat(gs.y-cs.y), CGFloat(gs.x-cs.x))
                            let potAngle = atan2(CGFloat(ps.y-ts.y), CGFloat(ps.x-ts.x))
                            let sweep = atan2(sin(potAngle-aimAngle), cos(potAngle-aimAngle))
                            let direction = atan2(valueLabel.center.y-CGFloat(gs.y), valueLabel.center.x-CGFloat(gs.x))
                            let delta = atan2(sin(direction-aimAngle), cos(direction-aimAngle))
                            XCTAssertLessThanOrEqual(hypot(valueLabel.center.x-CGFloat(gs.x),
                                                          valueLabel.center.y-CGFloat(gs.y)), 60.01,
                                                     "Small wedges must use a local side label, not a distant value")
                            XCTAssertGreaterThanOrEqual(cos(delta-sweep/2), -0.001,
                                                        "A side fallback must not flip to the opposite angle")
                            let arc = try XCTUnwrap(view.layer.sublayers?.first { $0.name == "angleDiagram.arc" } as? CAShapeLayer)
                            if mode == .perspective3D {
                                XCTAssertTrue(arc.isHidden)
                                let segments = scene.angleArcNode?.childNodes.filter { $0.name == "diagramTableArc" } ?? []
                                XCTAssertEqual(segments.count, 24)
                                for segment in segments {
                                    XCTAssertFalse(segment.isHidden)
                                    XCTAssertTrue(try XCTUnwrap(segment.geometry?.firstMaterial).readsFromDepthBuffer)
                                }
                            } else {
                                XCTAssertFalse(arc.isHidden)
                                XCTAssertNotNil(arc.path)
                            }
                        }
                        for (index, label) in labels.enumerated() {
                            XCTAssertTrue(view.bounds.contains(label.frame))
                            for other in labels.dropFirst(index+1) { XCTAssertFalse(label.frame.intersects(other.frame)) }
                        }
                        if targetZ == 0, distance == 0.65, degrees == 30 {
                            let image = UIGraphicsImageRenderer(bounds: view.bounds).image { _ in
                                view.snapshot().draw(in: view.bounds)
                                for label in labels {
                                    guard let context = UIGraphicsGetCurrentContext() else { continue }
                                    context.saveGState(); context.translateBy(x: label.frame.minX, y: label.frame.minY)
                                    label.layer.render(in: context); context.restoreGState()
                                }
                            }
                            let attachment = XCTAttachment(image: image)
                            attachment.name = "angle-diagram-\(mode)"; attachment.lifetime = .keepAlways; add(attachment)
                        }
                        cases += 1
                    }
                }
            }
        }
        XCTAssertGreaterThan(cases, 40)
    }

    func testAllThreePagesUpdateCueBeforeDragEnds() throws {
        let angle = AngleDynamicViewModel(); angle.setupScene()
        let separation = SeparationAngleAtlasViewModel(); separation.setupScene()
        let cushion = CushionEnglishAtlasViewModel(); cushion.setupScene()
        let pages: [(AngleTrainingScene, (SCNNode) -> Void, (SCNNode, SCNVector3) -> Void, (SCNNode) -> Void)] = [
            (angle.scene, angle.dragBegan, angle.dragMoved, angle.dragEnded),
            (separation.scene, separation.dragBegan, separation.dragMoved, separation.dragEnded),
            (cushion.scene, cushion.dragBegan, cushion.dragMoved, cushion.dragEnded)
        ]
        for (scene, begin, move, end) in pages {
            let cue = try XCTUnwrap(scene.cueBallNode)
            let target = try XCTUnwrap(scene.allBallNodes.values.first { !$0.isHidden && $0 !== cue })
            let stick = try XCTUnwrap(scene.cueStick?.rootNode)
            for ball in [cue, target] {
                begin(ball)
                XCTAssertFalse(stick.isHidden)
                for _ in 0..<3 {
                    let previous = stick.simdTransform
                    move(ball, SCNVector3(ball.position.x - 0.015, ball.position.y, ball.position.z + 0.01))
                    XCTAssertFalse(stick.isHidden)
                    XCTAssertNotEqual(stick.simdTransform, previous, "Cue must update before dragEnded")
                    XCTAssertEqual(stick.position.x, cue.position.x, accuracy: 0.001)
                    XCTAssertEqual(stick.position.z, cue.position.z, accuracy: 0.001)
                }
                end(ball)
                XCTAssertFalse(stick.isHidden)
            }
        }
    }

    func testAnglePageCueFollowsDragAndHidesWithNoTarget() throws {
        let vm = AngleDynamicViewModel(); vm.setupScene()
        let cueStick = try XCTUnwrap(vm.scene.cueStick)
        XCTAssertFalse(cueStick.rootNode.isHidden)
        let cue = try XCTUnwrap(vm.scene.cueBallNode)
        vm.dragBegan(node: cue)
        XCTAssertFalse(cueStick.rootNode.isHidden)
        vm.dragMoved(node: cue, worldPosition: SCNVector3(cue.position.x-0.03,cue.position.y,cue.position.z))
        XCTAssertFalse(cueStick.rootNode.isHidden)
        vm.dragEnded(node: cue)
        XCTAssertFalse(cueStick.rootNode.isHidden)
        if let key = vm.selectedTargetKey { vm.removeFromTable(key) }
        XCTAssertTrue(cueStick.rootNode.isHidden)
        XCTAssertNil(vm.scene.diagramLabelGeometry)
    }
}

// MARK: - Opt-in 4K teaching capture (runs inside the iOS Simulator)

@MainActor
final class AngleAimingVideoCaptureTests: XCTestCase {
    private var size = CGSize(width: 2160, height: 3840)
    private var spatialVideoLabels = false

    private func outputDirectory() throws -> URL {
        let env = ProcessInfo.processInfo.environment
        let path = env["ANGLE_CAPTURE_DIR"] ?? env["TEST_RUNNER_ANGLE_CAPTURE_DIR"]
        guard let path, !path.isEmpty else {
            throw XCTSkip("Set TEST_RUNNER_ANGLE_CAPTURE_DIR to opt into media export")
        }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("frames"), withIntermediateDirectories: true)
        return directory
    }

    private struct Capture {
        let vm: AngleDynamicViewModel
        let renderer: SCNRenderer
        let labelView: SCNView
        let labels: DiagramLabelOverlay
        let target: SCNVector3
        let aim: SCNVector3
        let ghost: SCNVector3
        let cameraTransform: simd_float4x4
    }

    private func makeCapture(_ mode: String) throws -> Capture {
        let vm = AngleDynamicViewModel()
        vm.setupScene()
        let scene = vm.scene
        scene.applyTableStyle(.standard, showsSights: true)
        scene.applyClothColor(.green) // Standard green cloth for the exported video (user request 2026-09-15).
        let y = scene.surfaceY + AngleSceneCalculator.ballRadius
        let target = SCNVector3(0, y, 0.1)
        try XCTUnwrap(vm.targetNode).position = target
        XCTAssertEqual(scene.currentTargetNumber, 8)
        vm.selectPocket(at: 3) // Portrait upper-right corner (+X, +Z).
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: 3, surfaceY: scene.surfaceY)
        XCTAssertGreaterThan(aim.x, 0)
        XCTAssertGreaterThan(aim.z, 0)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: aim, ballRadius: AngleSceneCalculator.ballRadius)
        scene.setCueBallHomeOrientation(simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)))
        scene.setCameraMode(mode == "2d" ? .topDown2D : .perspective3D, animated: false)
        let node = try XCTUnwrap(scene.cameraNode)
        let camera = try XCTUnwrap(node.camera)
        camera.projectionDirection = .vertical
        camera.zNear = 0.01
        camera.zFar = 100
        camera.wantsExposureAdaptation = false
        if mode == "2d" {
            camera.usesOrthographicProjection = true
            camera.orthographicScale = 1.70
            // Reserve the portrait header above the complete table.
            let center = SCNVector3(0.24, scene.surfaceY, 0)
            node.position = SCNVector3(center.x, scene.surfaceY + 3, center.z)
            node.look(at: center, up: SCNVector3(1, 0, 0), localFront: SCNVector3(0, 0, -1))
        } else {
            camera.usesOrthographicProjection = false
            camera.fieldOfView = 40
            let elevation = Float(35 * Double.pi / 180)
            let distance: Float = 5.10
            let center = SCNVector3(0, scene.surfaceY, 0)
            node.position = SCNVector3(-distance * cos(elevation), center.y + distance * sin(elevation), 0)
            node.look(at: center, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
        }
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene
        renderer.pointOfView = node
        renderer.autoenablesDefaultLighting = false
        renderer.delegate = scene.contactOcclusion
        SCNTransaction.flush()
        let labelView = SCNView(frame: CGRect(x: 0, y: 0, width: 360, height: 360*size.height/size.width))
        labelView.scene = scene
        labelView.pointOfView = node
        labelView.layoutIfNeeded()
        return Capture(vm: vm, renderer: renderer, labelView: labelView, labels: DiagramLabelOverlay(),
                       target: target, aim: aim, ghost: ghost, cameraTransform: node.simdTransform)
    }

    private func setAngle(_ degrees: Double, in capture: Capture) throws -> [String: Any] {
        let scene = capture.vm.scene
        let a = Float(degrees * .pi / 180)
        let n = simd_normalize(SIMD2<Float>(capture.aim.x - capture.target.x, capture.aim.z - capture.target.z))
        let side = SIMD2<Float>(n.y, -n.x)
        let direction = n * cos(a) + side * sin(a)
        let cue = SCNVector3(capture.ghost.x - 0.52 * direction.x, capture.target.y,
                            capture.ghost.z - 0.52 * direction.y)
        let ball = try XCTUnwrap(scene.cueBallNode)
        ball.position = cue
        capture.vm.updateCalculations()
        // Rendering a theoretical endpoint does not relax production feasibility.
        scene.updateVisualization(cueBall: cue, targetBall: capture.target, pocket: capture.aim,
                                  showLineLabels: true, extendStrikeLineToRail: true)
        scene.updateCueStick(cueBallPosition: cue,
                             aimDirection: SCNVector3(capture.ghost.x-cue.x, 0, capture.ghost.z-cue.z))
        let measured = capture.vm.cutAngleDegrees
        XCTAssertEqual(measured, degrees, accuracy: 0.01)
        XCTAssertLessThan(abs(cue.x) + AngleSceneCalculator.ballRadius, 1.27)
        XCTAssertLessThan(abs(cue.z) + AngleSceneCalculator.ballRadius, 0.635)
        XCTAssertGreaterThan(AngleSceneCalculator.horizontalDistance(cue, capture.target), 2 * AngleSceneCalculator.ballRadius)
        XCTAssertFalse(try XCTUnwrap(scene.ghostBallNode).isHidden)
        XCTAssertFalse(try XCTUnwrap(scene.cueStick).rootNode.isHidden)
        XCTAssertEqual(scene.cameraNode.simdTransform, capture.cameraTransform)
        SCNTransaction.flush()
        return ["requestedDegrees": degrees, "measuredDegrees": measured,
                "cue": [cue.x, cue.y, cue.z], "target": [capture.target.x, capture.target.y, capture.target.z],
                "aim": [capture.aim.x, capture.aim.y, capture.aim.z]]
    }

    private func image(_ capture: Capture, time: Double) throws -> UIImage {
        let shot = capture.renderer.snapshot(atTime: time, with: size, antialiasingMode: .multisampling4X)
        XCTAssertEqual(shot.cgImage?.width, Int(size.width))
        XCTAssertEqual(shot.cgImage?.height, Int(size.height))
        if !spatialVideoLabels { capture.labels.update(scene: capture.vm.scene, in: capture.labelView) }
        let labels = spatialVideoLabels ? [] : capture.labelView.subviews.compactMap { $0 as? UILabel }
        let overlayScale = Float(size.width / capture.labelView.bounds.width)
        if spatialVideoLabels {
            let nodes = try XCTUnwrap(capture.vm.scene.rootNode.childNode(withName: "videoSpatialLabels", recursively: false))
                .childNodes.filter { $0.geometry is SCNText }
            XCTAssertEqual(nodes.count, 3)
            XCTAssertTrue(nodes.allSatisfy { !$0.isHidden && ($0.geometry as! SCNText).extrusionDepth > 0 })
            XCTAssertTrue(nodes.contains { ($0.geometry as! SCNText).string as? String == "接触点" })
            XCTAssertTrue(nodes.contains { ($0.geometry as! SCNText).string as? String == "瞄准点" })
        } else {
            XCTAssertEqual(labels.count, 3)
            XCTAssertTrue(labels.allSatisfy { !$0.isHidden }, "All three production annotations must be visible")
            XCTAssertTrue(labels.contains { $0.text == "瞄准线" })
            XCTAssertTrue(labels.contains { $0.text == "进球线" })
        }
        // Compare the real SceneKit projections before compositing the production overlay.
        // SCNRenderer uses bottom-left projection coordinates; SCNView uses UIKit top-left.
        for world in [capture.target, capture.ghost, try XCTUnwrap(capture.vm.scene.cueBallNode).position] {
            let sourcePoint = capture.renderer.projectPoint(world)
            let overlayPoint = capture.labelView.projectPoint(world)
            XCTAssertEqual(sourcePoint.x / overlayScale, overlayPoint.x, accuracy: 0.1)
            XCTAssertEqual((Float(size.height) - sourcePoint.y) / overlayScale, overlayPoint.y, accuracy: 0.1)
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let degrees = capture.vm.cutAngleDegrees
        let titleFont = UIFont.monospacedDigitSystemFont(ofSize: 30, weight: .medium)
        let metricFont = UIFont.monospacedDigitSystemFont(ofSize: 25, weight: .regular)
        // Stable compact width covers every numeric state and the longest thickness name.
        let titleWidth = ("切角 89.0°" as NSString).size(withAttributes: [.font: titleFont]).width
        let metricWidth = ("横移 57.1mm" as NSString).size(withAttributes: [.font: metricFont]).width
        let thicknessWidth = 68 + ("极薄球" as NSString).size(withAttributes: [.font: metricFont]).width
        let panelWidth = max(titleWidth, metricWidth, thicknessWidth) + 48
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            // The 2D scene is transparent outside the table; paint the black backdrop explicitly
            // so the composite is genuinely opaque instead of carrying alpha=0 pixels downstream.
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            shot.draw(in: CGRect(origin: .zero, size: size))
            let cg = context.cgContext
            cg.saveGState()
            cg.scaleBy(x: CGFloat(overlayScale), y: CGFloat(overlayScale))
            // Capture only the UIKit annotations; the Metal scene already exists at native 4K.
            for layer in capture.labelView.layer.sublayers ?? [] {
                guard let shape = layer as? CAShapeLayer, shape.name == "angleDiagram.arc",
                      !shape.isHidden, let path = shape.path else { continue }
                cg.addPath(path)
                cg.setStrokeColor(shape.strokeColor ?? UIColor.white.cgColor)
                cg.setLineWidth(shape.lineWidth)
                cg.setLineCap(.round)
                cg.strokePath()
            }
            for label in labels {
                cg.saveGState()
                cg.translateBy(x: label.frame.minX, y: label.frame.minY)
                label.layer.render(in: cg)
                cg.restoreGState()
            }
            cg.restoreGState()
            let panelScale = min(size.width/1080, size.height/1920)
            cg.scaleBy(x: panelScale, y: panelScale)
            // Panel origin in 1080×1920 coordinates. User request (2026-09-15): keep the readout
            // out of social-media overlay zones — 2D sits on the cloth left of the cue-ball arc,
            // 3D sits on the floor between the sofa and the far end of the table.
            let panelOrigin = size.width >= size.height ? CGPoint(x: 68, y: 96)
                : (capture.vm.scene.currentCameraMode == .perspective3D
                ? CGPoint(x: 68, y: 392) : CGPoint(x: 216, y: 1250))
            cg.translateBy(x: panelOrigin.x - 96, y: panelOrigin.y - 96)
            UIColor.black.withAlphaComponent(0.64).setFill()
            UIBezierPath(roundedRect: CGRect(x: 96, y: 96, width: panelWidth, height: 188), cornerRadius: 16).fill()
            let text = String(format: "切角 %4.1f°", degrees)
            (text as NSString).draw(at: CGPoint(x: 120, y: 108), withAttributes: [
                .font: titleFont, .foregroundColor: UIColor.white
            ])
            let diameter: CGFloat = 25
            let offset = diameter * CGFloat(sin(degrees * .pi / 180))
            let targetCircle = UIBezierPath(ovalIn: CGRect(x: 145, y: 149, width: diameter, height: diameter))
            UIColor.black.setFill()
            targetCircle.fill()
            UIColor.lightGray.setStroke()
            targetCircle.lineWidth = 1
            targetCircle.stroke()
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: 145-offset, y: 149, width: diameter, height: diameter)).fill()
            (capture.vm.thicknessName as NSString).draw(at: CGPoint(x: 188, y: 146), withAttributes: [
                .font: metricFont, .foregroundColor: UIColor.white
            ])
            let rows = [String(format: "d/R %.2f", capture.vm.dOverR),
                        String(format: "横移 %.1fmm", capture.vm.displacementMM),
                        String(format: "偏移 %.0f%%", capture.vm.offsetPercent)]
            for (index, row) in rows.enumerated() {
                (row as NSString).draw(at: CGPoint(x: 120, y: 178 + 32 * index), withAttributes: [
                    .font: metricFont, .foregroundColor: UIColor.white
                ])
            }
        }
    }

    private func projectionRecord(_ capture: Capture) throws -> [String: Any] {
        let scene = capture.vm.scene
        let right = scene.cameraNode.convertVector(SCNVector3(1, 0, 0), to: nil)
        let r = AngleSceneCalculator.ballRadius
        var record: [String: Any] = [:]
        for (name, node) in [("cue", try XCTUnwrap(scene.cueBallNode)), ("target", try XCTUnwrap(capture.vm.targetNode))] {
            let p = scene.visualCenter(of: node)
            let left = capture.renderer.projectPoint(SCNVector3(p.x-right.x*r, p.y-right.y*r, p.z-right.z*r))
            let rightP = capture.renderer.projectPoint(SCNVector3(p.x+right.x*r, p.y+right.y*r, p.z+right.z*r))
            let center = capture.renderer.projectPoint(p)
            let diameter = hypot(rightP.x-left.x, rightP.y-left.y)
            XCTAssertGreaterThanOrEqual(diameter / 2, 28, "1080p ball size; pulled-back room view requested")
            XCTAssertGreaterThan(center.x, Float(size.width)*0.05)
            XCTAssertLessThan(center.x, Float(size.width)*0.95)
            XCTAssertGreaterThan(center.y, Float(size.height)*0.05)
            XCTAssertLessThan(center.y, Float(size.height)*0.95)
            record[name] = ["projectedCenter": [center.x, center.y, center.z], "diameter4K": diameter]
        }
        record["cameraPosition"] = [scene.cameraNode.position.x, scene.cameraNode.position.y, scene.cameraNode.position.z]
        record["fieldOfView"] = scene.cameraNode.camera?.fieldOfView
        record["orthographicScale"] = scene.cameraNode.camera?.orthographicScale
        return record
    }

    /// Opt-in stills only: same production layout, four eye heights along the cue axis.
    func testFirstPersonHeightComparison() async throws {
        let output = try outputDirectory()
        let env = ProcessInfo.processInfo.environment
        let compareWidth = (env["ANGLE_COMPARE_WIDTH"] ?? env["TEST_RUNNER_ANGLE_COMPARE_WIDTH"]) == "1"
        let heights: [Float] = compareWidth ? [0.20, 0.20, 0.20, 0.20] : [0.10, 0.20, 0.30, 0.45]
        let fieldsOfView: [Double] = compareWidth ? [50, 75, 105, 140] : [50, 50, 50, 50]
        var records: [[String: Any]] = []
        for angle in (compareWidth ? [30.0, 60.0, 89.0] : [30.0, 60.0]) {
            var thumbnails: [UIImage] = []
            for (index, height) in heights.enumerated() {
                let thumbnail = try autoreleasepool { () throws -> UIImage in
                    let capture = try makeCapture("3d")
                    var record = try setAngle(angle, in: capture)
                    let scene = capture.vm.scene
                    let cue = try XCTUnwrap(scene.cueBallNode).position
                    let direction = simd_normalize(SIMD2<Float>(capture.ghost.x-cue.x, capture.ghost.z-cue.z))
                    let camera = scene.cameraNode!
                    camera.camera!.fieldOfView = fieldsOfView[index]
                    camera.position = SCNVector3(cue.x - 0.65*direction.x, scene.surfaceY + height,
                                                 cue.z - 0.65*direction.y)
                    camera.look(at: capture.ghost, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
                    XCTAssertEqual(camera.position.y-scene.surfaceY, height, accuracy: 0.00001)
                    XCTAssertEqual(AngleSceneCalculator.horizontalDistance(camera.position, cue), 0.65, accuracy: 0.00001)
                    SCNTransaction.flush()
                    _ = try image(capture, time: 0)
                    let shot = try image(capture, time: 0)
                    let name = compareWidth ? "first-person-\(Int(angle))-fov-\(Int(fieldsOfView[index])).png"
                        : "first-person-\(Int(angle))-height-\(Int((height*100).rounded()))cm.png"
                    try XCTUnwrap(shot.pngData()).write(to: output.appendingPathComponent("frames/"+name))
                    record["heightAboveClothM"] = height
                    record["horizontalBackDistanceM"] = 0.65
                    record["image"] = name
                    record["projection"] = try projectionRecord(capture)
                    let pocket = capture.renderer.projectPoint(capture.aim)
                    record["pocketPixel"] = [pocket.x, pocket.y, pocket.z]
                    record["pocketCenterInFrame"] = pocket.x > 0 && pocket.x < Float(size.width)
                        && pocket.y > 0 && pocket.y < Float(size.height) && pocket.z > 0 && pocket.z < 1
                    records.append(record)
                    print("FIRST_PERSON_HEIGHT \(name)")
                    let format = UIGraphicsImageRendererFormat()
                    format.scale = 1
                    format.opaque = true
                    return UIGraphicsImageRenderer(size: CGSize(width: 540, height: 960), format: format).image { _ in
                        shot.draw(in: CGRect(x: 0, y: 0, width: 540, height: 960))
                    }
                }
                thumbnails.append(thumbnail)
                await Task.yield()
            }
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let sheet = UIGraphicsImageRenderer(size: CGSize(width: 2160, height: 1040), format: format).image { ctx in
                UIColor.black.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 2160, height: 1040))
                for (index, thumb) in thumbnails.enumerated() {
                    let x = CGFloat(index)*540
                    let title = compareWidth
                        ? String(format: "%@ · 视场 %.0f° · 切角 %.0f°", ["A", "B", "C", "D"][index], fieldsOfView[index], angle)
                        : String(format: "%@ · 台面上方 %.0f cm · %.0f°", ["A", "B", "C", "D"][index], heights[index]*100, angle)
                    (title as NSString).draw(at: CGPoint(x: x+20, y: 25), withAttributes: [
                        .font: UIFont.systemFont(ofSize: 26, weight: .semibold), .foregroundColor: UIColor.white
                    ])
                    thumb.draw(at: CGPoint(x: x, y: 80))
                }
            }
            let prefix = compareWidth ? "width" : "height"
            try XCTUnwrap(sheet.pngData()).write(to: output.appendingPathComponent("\(prefix)-comparison-\(Int(angle)).png"))
        }
        try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent(compareWidth ? "width-comparison.json" : "height-comparison.json"))
    }

    func testFirstPersonAspectComparison() async throws {
        let output = try outputDirectory()
        let env = ProcessInfo.processInfo.environment
        let mobileFrame = (env["ANGLE_MOBILE_FRAME"] ?? env["TEST_RUNNER_ANGLE_MOBILE_FRAME"]) == "1"
        let originalSize = size
        defer { size = originalSize }
        var records: [[String: Any]] = []
        let formats: [(String, CGSize, Double)] = mobileFrame ? [
            ("4x5", CGSize(width: 2160, height: 2700), 80),
            ("3x4", CGSize(width: 2160, height: 2880), 80)
        ] : [
            ("4x3", CGSize(width: 2880, height: 2160), 75),
            ("16x9", CGSize(width: 3840, height: 2160), 75),
            ("2x1", CGSize(width: 3840, height: 1920), 70)
        ]
        for angle in [30.0, 60.0, 89.0] {
            for (name, dimensions, fov) in formats {
                try autoreleasepool {
                    size = dimensions
                    let capture = try makeCapture("3d")
                    var record = try setAngle(angle, in: capture)
                    let scene = capture.vm.scene
                    let cue = try XCTUnwrap(scene.cueBallNode).position
                    let u = simd_normalize(SIMD2<Float>(capture.ghost.x-cue.x, capture.ghost.z-cue.z))
                    let camera = scene.cameraNode!
                    camera.position = SCNVector3(cue.x-0.65*u.x, scene.surfaceY+0.20, cue.z-0.65*u.y)
                    camera.camera!.fieldOfView = fov
                    var lookTarget = capture.ghost
                    if mobileFrame {
                        // Keep the eye position; turn toward the angular midpoint of aim and pocket.
                        let toPocket = simd_normalize(SIMD2<Float>(capture.aim.x-camera.position.x, capture.aim.z-camera.position.z))
                        let viewDirection = simd_normalize(u + toPocket)
                        lookTarget = SCNVector3(camera.position.x+1.17*viewDirection.x,
                                               capture.ghost.y, camera.position.z+1.17*viewDirection.y)
                        record["yawFromAimDegrees"] = acos(max(-1, min(1, simd_dot(u, viewDirection))))*180/Float.pi
                    }
                    camera.look(at: lookTarget, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
                    SCNTransaction.flush()
                    _ = try image(capture, time: 0)
                    let shot = try image(capture, time: 0)
                    let filename = "aspect-\(name)-\(Int(angle)).png"
                    try XCTUnwrap(shot.pngData()).write(to: output.appendingPathComponent("frames/"+filename))
                    record["format"] = name
                    record["image"] = filename
                    record["size"] = [size.width, size.height]
                    record["verticalFOV"] = fov
                    record["projection"] = try projectionRecord(capture)
                    let p = capture.renderer.projectPoint(capture.aim)
                    record["pocketNormalized"] = [p.x/Float(size.width), p.y/Float(size.height), p.z]
                    records.append(record)
                    print("FIRST_PERSON_ASPECT \(filename)")
                }
                await Task.yield()
            }
        }
        try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("aspect-comparison.json"))
    }

    private func updateSpatialVideoLabels(_ capture: Capture, darkAnnotations: Bool = false, yellowAnnotations: Bool = false) throws -> [[String: Any]] {
        let scene = capture.vm.scene
        let camera = scene.cameraNode!
        scene.angleArcNode?.childNode(withName: "angleValueLabel", recursively: true)?.removeFromParentNode()
        let root: SCNNode
        if let existing = scene.rootNode.childNode(withName: "videoSpatialLabels", recursively: false) {
            root = existing
        } else {
            root = SCNNode(); root.name = "videoSpatialLabels"; scene.rootNode.addChildNode(root)
        }
        let contact = try XCTUnwrap(scene.contactDotNode).worldPosition
        let aim = try XCTUnwrap(scene.ghostBallNode?.childNode(withName: "ghostAimDot", recursively: true)).worldPosition
        let darkNeutral = UIColor(white: 0.18, alpha: 1)
        let specs: [(String, String, SCNVector3, SIMD2<Float>, UIColor)] = [
            ("angle", String(format: "%.1f°", capture.vm.cutAngleDegrees), capture.target, SIMD2(-70, 70), yellowAnnotations ? .white : (darkAnnotations ? darkNeutral : .white)),
            ("contact", "接触点", contact, SIMD2(125, 65), yellowAnnotations ? UIColor(red: 1, green: 0.82, blue: 0.06, alpha: 1) : darkAnnotations ? UIColor(hue: 0.3905, saturation: 0.82, brightness: 0.36, alpha: 1) : UIColor(red: 0.65, green: 1, blue: 0.77, alpha: 1)),
            ("aim", "瞄准点", aim, SIMD2(145, 18), darkAnnotations ? UIColor(hue: 0.025, saturation: 0.8, brightness: 0.50, alpha: 1) : UIColor(red: 1, green: 0.83, blue: 0.8, alpha: 1))
        ]
        var rectangles: [CGRect] = []
        var records: [[String: Any]] = []
        for (id, title, anchor, offset, color) in specs {
            let textNode: SCNNode
            if let existing = root.childNode(withName: id, recursively: false) { textNode = existing }
            else {
                let text = SCNText(string: title, extrusionDepth: 2.5)
                text.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
                text.flatness = 0.12
                text.chamferRadius = 0.18
                let front = SCNMaterial(); front.lightingModel = .constant; front.diffuse.contents = color
                let edge = SCNMaterial(); edge.lightingModel = .lambert
                edge.diffuse.contents = UIColor(red: 0.10, green: 0.19, blue: 0.24, alpha: 1)
                text.materials = [front, edge, edge, front, edge]
                textNode = SCNNode(geometry: text); textNode.name = id
                textNode.castsShadow = false; root.addChildNode(textNode)
            }
            let geo = textNode.geometry as! SCNText
            if geo.string as? String != title { geo.string = title }
            let (lo, hi) = geo.boundingBox
            textNode.pivot = SCNMatrix4MakeTranslation((lo.x+hi.x)/2, (lo.y+hi.y)/2, 0)
            let pixel = capture.renderer.projectPoint(anchor)
            let s = Float(size.width/1080)
            let location = SCNVector3(pixel.x+offset.x*s, pixel.y+offset.y*s, pixel.z)
            textNode.position = capture.renderer.unprojectPoint(location)
            let eyeLocal = camera.convertPosition(anchor, from: nil)
            let worldPerPixel = 2 * (-eyeLocal.z) * tan(Float(camera.camera!.fieldOfView)*Float.pi/360) / Float(size.height)
            let scale = worldPerPixel*s*27/max(hi.y-lo.y, 1)
            textNode.scale = SCNVector3(scale, scale, scale)
            // A small yaw exposes the bevel and extrusion while keeping the face readable.
            textNode.simdOrientation = camera.simdOrientation * simd_quatf(angle: -0.16, axis: SIMD3(0, 1, 0))
            let corners = [SCNVector3(lo.x,lo.y,0), SCNVector3(hi.x,lo.y,0),
                           SCNVector3(lo.x,hi.y,Float(geo.extrusionDepth)), SCNVector3(hi.x,hi.y,Float(geo.extrusionDepth))]
                .map { local in
                    // Explicit glyph-to-world mapping includes its font-unit pivot exactly once.
                    let centered = SIMD3(local.x-(lo.x+hi.x)/2, local.y-(lo.y+hi.y)/2, local.z)
                    let world = textNode.simdPosition + textNode.simdOrientation.act(centered * scale)
                    return capture.renderer.projectPoint(SCNVector3(world.x, world.y, world.z))
                }
            let actualCenter = capture.renderer.projectPoint(textNode.position)
            XCTAssertEqual(actualCenter.x, location.x, accuracy: 0.1)
            XCTAssertEqual(actualCenter.y, location.y, accuracy: 0.1)
            let x0 = corners.map(\.x).min()!, x1 = corners.map(\.x).max()!
            let y0 = corners.map(\.y).min()!, y1 = corners.map(\.y).max()!
            let rect = CGRect(x: CGFloat(x0), y: CGFloat(y0), width: CGFloat(x1-x0), height: CGFloat(y1-y0))
            XCTAssertGreaterThan(x0, 24); XCTAssertLessThan(x1, Float(size.width)-24)
            XCTAssertGreaterThan(y0, 24); XCTAssertLessThan(y1, Float(size.height)-24)
            for other in rectangles { XCTAssertFalse(rect.insetBy(dx: -8, dy: -8).intersects(other)) }
            for ball in [try XCTUnwrap(scene.cueBallNode), try XCTUnwrap(capture.vm.targetNode)] {
                let center = capture.renderer.projectPoint(ball.worldPosition)
                let right = camera.convertVector(SCNVector3(AngleSceneCalculator.ballRadius,0,0), to: nil)
                let edge = capture.renderer.projectPoint(SCNVector3(ball.worldPosition.x+right.x,ball.worldPosition.y+right.y,ball.worldPosition.z+right.z))
                let radius = CGFloat(hypot(edge.x-center.x,edge.y-center.y))
                let ballRect = CGRect(x: CGFloat(center.x)-radius, y: CGFloat(center.y)-radius, width: radius*2, height: radius*2)
                XCTAssertFalse(rect.insetBy(dx: -8, dy: -8).intersects(ballRect), "\(id) must not cover a ball")
            }
            rectangles.append(rect)
            root.childNode(withName: id+"Leader", recursively: false)?.removeFromParentNode()
            if id != "angle" {
                let endPixel = SCNVector3(Float(rect.minX)-7, Float(rect.midY), pixel.z)
                let end = capture.renderer.unprojectPoint(endPixel)
                let delta = SIMD3(end.x-anchor.x,end.y-anchor.y,end.z-anchor.z)
                let cylinder = SCNCylinder(radius: 0.0006, height: CGFloat(simd_length(delta)))
                let material = SCNMaterial(); material.lightingModel = .constant; material.diffuse.contents = color
                cylinder.materials = [material]
                let leader = SCNNode(geometry: cylinder); leader.name = id+"Leader"; leader.castsShadow = false
                leader.position = SCNVector3((end.x+anchor.x)/2,(end.y+anchor.y)/2,(end.z+anchor.z)/2)
                leader.simdOrientation = simd_quatf(from: SIMD3(0,1,0), to: simd_normalize(delta))
                root.addChildNode(leader)
            }
            records.append(["id":id,"text":title,"anchor":[anchor.x,anchor.y,anchor.z],
                            "pixelBounds":[rect.minX,rect.minY,rect.width,rect.height],"extrusionDepth":geo.extrusionDepth])
        }
        SCNTransaction.flush()
        return records
    }

    /// Second real scene camera; a fixed world span prevents breathing zoom during rotation.
    private func contactInset(_ capture: Capture, renderer: SCNRenderer, camera: SCNNode,
                              base: UIImage, time: Double) throws -> (UIImage, [String: Any]) {
        let scene = capture.vm.scene
        let env = ProcessInfo.processInfo.environment
        let aimAligned = (env["ANGLE_INSET_AIM_ALIGNED"] ?? env["TEST_RUNNER_ANGLE_INSET_AIM_ALIGNED"]) == "1"
        let showsAngle = (env["ANGLE_INSET_ANGLE_VALUE"] ?? env["TEST_RUNNER_ANGLE_INSET_ANGLE_VALUE"]) == "1"
        let rasterScale: CGFloat = aimAligned ? 2 : 1
        let viewport = CGSize(width: 480, height: 320)
        let box = CGRect(x: 560, y: 100, width: 480, height: aimAligned ? 320 : 364)
        let mainCamera = try XCTUnwrap(scene.cameraNode)
        let center = SIMD3<Float>((capture.target.x+capture.ghost.x)/2,
                                  scene.surfaceY+AngleSceneCalculator.ballRadius/2,
                                  (capture.target.z+capture.ghost.z)/2)
        camera.simdOrientation = mainCamera.simdOrientation
        camera.simdPosition = center + camera.simdOrientation.act(SIMD3<Float>(0,0,0.65))
        if aimAligned {
            let cue = try XCTUnwrap(scene.cueBallNode).position
            let aimDirection = simd_normalize(SIMD2<Float>(capture.ghost.x-cue.x,capture.ghost.z-cue.z))
            let mainForward = mainCamera.simdOrientation.act(SIMD3<Float>(0,0,-1))
            let horizontalLength = sqrt(1-mainForward.y*mainForward.y)
            let forward = SIMD3<Float>(aimDirection.x*horizontalLength,mainForward.y,aimDirection.y*horizontalLength)
            camera.simdPosition = center-forward*0.65
            camera.look(at: SCNVector3(center.x,center.y,center.z), up: SCNVector3(0,1,0), localFront: SCNVector3(0,0,-1))
            let actual = camera.simdOrientation.act(SIMD3<Float>(0,0,-1))
            XCTAssertEqual(simd_dot(simd_normalize(SIMD2(actual.x,actual.z)),aimDirection),1,accuracy:0.00001)
        }
        camera.camera!.usesOrthographicProjection = true
        camera.camera!.projectionDirection = .vertical
        camera.camera!.orthographicScale = 0.08
        camera.camera!.zNear = 0.01; camera.camera!.zFar = 100
        camera.camera!.wantsExposureAdaptation = false
        let rasterSize = CGSize(width: viewport.width*rasterScale, height: viewport.height*rasterScale)
        func project(_ world: SCNVector3) -> SCNVector3 {
            let p = renderer.projectPoint(world)
            return SCNVector3(p.x/Float(rasterScale),p.y/Float(rasterScale),p.z)
        }
        func unproject(_ p: SCNVector3) -> SCNVector3 {
            renderer.unprojectPoint(SCNVector3(p.x*Float(rasterScale),p.y*Float(rasterScale),p.z))
        }
        let labels = try XCTUnwrap(scene.rootNode.childNode(withName: "videoSpatialLabels", recursively: false))
        // Validate main-frame safety in UIKit coordinates, including original 3D labels.
        for world in [capture.target, capture.ghost, capture.aim, try XCTUnwrap(scene.cueBallNode).position] {
            let p = capture.renderer.projectPoint(world)
            let rect = CGRect(x: CGFloat(p.x)-50, y: size.height-CGFloat(p.y)-50, width: 100, height: 100)
            XCTAssertFalse(box.intersects(rect), "Inset must avoid main balls and pocket for every frame")
        }
        for node in labels.childNodes where node.geometry is SCNText {
            let p = capture.renderer.projectPoint(node.worldPosition)
            XCTAssertFalse(box.intersects(CGRect(x: CGFloat(p.x)-80, y: size.height-CGFloat(p.y)-25, width: 160, height: 50)))
        }
        XCTAssertFalse(box.intersects(CGRect(x: 51, y: 294, width: 170, height: 150)), "Avoid original metrics")
        let arcHidden = scene.angleArcNode?.isHidden ?? true
        labels.isHidden = true; scene.angleArcNode?.isHidden = true
        let detailLabels = SCNNode(); detailLabels.name = "videoInsetLabels"
        scene.rootNode.addChildNode(detailLabels)
        defer {
            detailLabels.removeFromParentNode()
            labels.isHidden = false; scene.angleArcNode?.isHidden = arcHidden
            SCNTransaction.flush()
        }
        SCNTransaction.flush()
        _ = renderer.snapshot(atTime: time, with: rasterSize, antialiasingMode: .multisampling4X)
        let contact = try XCTUnwrap(scene.contactDotNode).worldPosition
        let aim = try XCTUnwrap(scene.ghostBallNode?.childNode(withName: "ghostAimDot", recursively: true)).worldPosition
        let projectedCenter = project(SCNVector3(center.x, center.y, center.z))
        XCTAssertEqual(projectedCenter.x, Float(viewport.width)/2, accuracy: 0.1)
        XCTAssertEqual(projectedCenter.y, Float(viewport.height)/2, accuracy: 0.1)
        let right = camera.simdOrientation.act(SIMD3<Float>(AngleSceneCalculator.ballRadius,0,0))
        let targetPixel = project(capture.target)
        let edgeWorld = SCNVector3(capture.target.x+right.x,capture.target.y+right.y,capture.target.z+right.z)
        let edgePixel = project(edgeWorld)
        let diameterPixels = 2*hypot(edgePixel.x-targetPixel.x,edgePixel.y-targetPixel.y)
        XCTAssertEqual(diameterPixels, Float(viewport.height)*AngleSceneCalculator.ballRadius/0.08, accuracy: 0.1)
        let mainTarget = capture.renderer.projectPoint(capture.target)
        let mainEdge = capture.renderer.projectPoint(edgeWorld)
        let relativeMagnification = diameterPixels/(2*hypot(mainEdge.x-mainTarget.x,mainEdge.y-mainTarget.y))
        var points: [String: [Float]] = [:]
        var annotations: [(String, SCNVector3, Float, Float)] = [("contact", contact, 375, 72), ("aim", aim, 375, 246)]
        if showsAngle { annotations.append(("angle", capture.target, 90, 76)) }
        for (id, anchor, labelX, topY) in annotations {
            let p = project(anchor)
            XCTAssertGreaterThan(p.x, 30); XCTAssertLessThan(p.x, Float(viewport.width)-30)
            XCTAssertGreaterThan(p.y, 30); XCTAssertLessThan(p.y, Float(viewport.height)-30)
            points[id] = [p.x, Float(viewport.height)-p.y]
            let source = try XCTUnwrap(labels.childNode(withName: id, recursively: false))
            let text = try XCTUnwrap(source.geometry?.copy() as? SCNText)
            // Camera-facing inset annotations are overlay geometry: their screen placement
            // can cross below the cloth plane, so test depth only for the real scene objects.
            text.materials = text.materials.map { original in
                let material = original.copy() as! SCNMaterial
                material.readsFromDepthBuffer = false; material.writesToDepthBuffer = false
                return material
            }
            let node = SCNNode(geometry: text); node.renderingOrder = 200
            let (lo, hi) = text.boundingBox
            node.pivot = SCNMatrix4MakeTranslation((lo.x+hi.x)/2, (lo.y+hi.y)/2, 0)
            let scale = Float(0.16/viewport.height)*25/(hi.y-lo.y)
            node.scale = SCNVector3(scale,scale,scale)
            node.simdOrientation = camera.simdOrientation * simd_quatf(angle: -0.16, axis: SIMD3(0,1,0))
            node.position = unproject(SCNVector3(labelX, Float(viewport.height)-topY, p.z))
            node.castsShadow = false; detailLabels.addChildNode(node)
            let projectedLabel = project(node.position)
            XCTAssertEqual(projectedLabel.x, labelX, accuracy: 0.1)
            XCTAssertEqual(projectedLabel.y, Float(viewport.height)-topY, accuracy: 0.1)
            if id == "angle" { continue }
            let end = unproject(SCNVector3(325, Float(viewport.height)-topY, p.z))
            let delta = SIMD3(end.x-anchor.x,end.y-anchor.y,end.z-anchor.z)
            let geometry = SCNCylinder(radius: 0.00035, height: CGFloat(simd_length(delta)))
            geometry.materials = [try XCTUnwrap(text.materials.first)]
            let leader = SCNNode(geometry: geometry); leader.renderingOrder = 199
            leader.position = SCNVector3((end.x+anchor.x)/2,(end.y+anchor.y)/2,(end.z+anchor.z)/2)
            leader.simdOrientation = simd_quatf(from: SIMD3(0,1,0), to: simd_normalize(delta))
            leader.castsShadow = false; detailLabels.addChildNode(leader)
        }
        SCNTransaction.flush()
        let detail = renderer.snapshot(atTime: time, with: rasterSize, antialiasingMode: .multisampling4X)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let result = UIGraphicsImageRenderer(size: size, format: format).image { context in
            base.draw(at: .zero)
            let cg = context.cgContext
            cg.saveGState()
            UIBezierPath(roundedRect: box, cornerRadius: 18).addClip()
            UIColor(white: 0.07, alpha: 1).setFill(); context.fill(box)
            detail.draw(in: CGRect(x: box.minX, y: box.minY+(aimAligned ? 0 : 44), width: viewport.width, height: viewport.height))
            if !aimAligned { ("接触区域 · 局部放大" as NSString).draw(at: CGPoint(x: box.minX+18, y: box.minY+10),
                withAttributes: [.font: UIFont.systemFont(ofSize: 21, weight: .semibold), .foregroundColor: UIColor.white]) }
            cg.restoreGState()
            UIColor.white.withAlphaComponent(0.85).setStroke()
            let border = UIBezierPath(roundedRect: box, cornerRadius: 18); border.lineWidth = 2; border.stroke()
        }
        return (result, ["screenRect":[box.minX,box.minY,box.width,box.height],
                         "orthographicScale":0.08,"points":points,"aimAligned":aimAligned,"showsAngle":showsAngle,"rasterSize":[rasterSize.width,rasterSize.height],
                         "ballDiameterPixels":diameterPixels,"relativeMagnification":relativeMagnification,
                         "cameraPosition":[camera.position.x,camera.position.y,camera.position.z]])
    }

    /// Review movie at native phone resolution, with opt-in user-requested 3D annotations.
    func testExportFirstPersonMobilePreview() async throws {
        let output = try outputDirectory()
        let env = ProcessInfo.processInfo.environment
        let revised = (env["ANGLE_REVISION2"] ?? env["TEST_RUNNER_ANGLE_REVISION2"]) == "1"
        let showsInset = (env["ANGLE_CONTACT_INSET"] ?? env["TEST_RUNNER_ANGLE_CONTACT_INSET"]) == "1"
        let greenCloth = (env["ANGLE_GREEN_CLOTH"] ?? env["TEST_RUNNER_ANGLE_GREEN_CLOTH"]) == "1"
        let yellowAnnotations = (env["ANGLE_YELLOW_ANNOTATIONS"] ?? env["TEST_RUNNER_ANGLE_YELLOW_ANNOTATIONS"]) == "1"
        let darkAnnotations = (env["ANGLE_DARK_ANNOTATIONS"] ?? env["TEST_RUNNER_ANGLE_DARK_ANNOTATIONS"]) == "1"
        let stillsOnly = (env["ANGLE_STILLS_ONLY"] ?? env["TEST_RUNNER_ANGLE_STILLS_ONLY"]) == "1"
        let heightString = env["ANGLE_EYE_HEIGHT"] ?? env["TEST_RUNNER_ANGLE_EYE_HEIGHT"] ?? "0.20"
        let eyeHeight = try XCTUnwrap(Float(heightString), "Eye height must be expressed in metres above the cloth")
        XCTAssertGreaterThan(eyeHeight, 0)
        let originalSize = size
        size = CGSize(width: 1080, height: 1440)
        defer { size = originalSize; spatialVideoLabels = false }
        let capture = try makeCapture("3d")
        let scene = capture.vm.scene
        if revised {
            XCTAssertTrue(scene.applyTableStyle(.charcoal, showsSights: true))
            scene.applyClothColor(greenCloth ? .green : .tournamentBlue)
            XCTAssertTrue(try XCTUnwrap(scene.cueStick).applyStyle(.inkDragon))
            XCTAssertEqual(scene.cueStick?.style, .inkDragon)
            spatialVideoLabels = true
            if darkAnnotations {
                let ghost = try XCTUnwrap(scene.ghostBallNode)
                let dashes = ghost.childNodes.filter { $0.geometry is SCNCylinder && $0.name != "ghostAimDot" }
                XCTAssertEqual(dashes.count, 16)
                for dash in dashes {
                    let geometry = try XCTUnwrap(dash.geometry?.copy() as? SCNGeometry)
                    let ink = SCNMaterial()
                    ink.lightingModel = .constant
                    ink.diffuse.contents = yellowAnnotations ? UIColor(red: 1, green: 0.82, blue: 0.06, alpha: 1) : UIColor(hue: 0.3899, saturation: 0.82, brightness: 0.40, alpha: 1)
                    geometry.materials = [ink]
                    dash.geometry = geometry
                }
            }
        }
        let camera = scene.cameraNode!
        let insetCamera = SCNNode(); insetCamera.camera = SCNCamera()
        let insetRenderer = SCNRenderer(device: nil, options: nil)
        if showsInset {
            scene.rootNode.addChildNode(insetCamera)
            insetRenderer.scene = scene; insetRenderer.pointOfView = insetCamera
            insetRenderer.autoenablesDefaultLighting = false
            insetRenderer.delegate = scene.contactOcclusion
        }
        let writer = stillsOnly ? nil : try VideoWriter(url: output.appendingPathComponent("first-person-3x4-preview.mp4"), size: size, fps: 60)
        var records: [[String: Any]] = []
        for frame in 0..<900 {
            if stillsOnly && ![0, 240, 424, 480, 720, 899].contains(frame) { continue }
            try autoreleasepool {
                let time = Double(frame)/60
                let angle = max(0, min(89, (time-1)*89/12))
                // The legacy layout helper verifies its original fixed camera before this
                // preview applies the separately measured moving eye pose.
                camera.simdTransform = capture.cameraTransform
                var record = try setAngle(angle, in: capture)
                let cue = try XCTUnwrap(scene.cueBallNode).position
                let u = simd_normalize(SIMD2<Float>(capture.ghost.x-cue.x, capture.ghost.z-cue.z))
                camera.position = SCNVector3(cue.x-0.65*u.x, scene.surfaceY+eyeHeight, cue.z-0.65*u.y)
                camera.camera!.fieldOfView = 80
                let toPocket = simd_normalize(SIMD2<Float>(capture.aim.x-camera.position.x, capture.aim.z-camera.position.z))
                let viewDirection = simd_normalize(u + toPocket)
                camera.look(at: SCNVector3(camera.position.x+1.17*viewDirection.x, capture.ghost.y,
                                           camera.position.z+1.17*viewDirection.y),
                            up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
                XCTAssertEqual(camera.position.y-scene.surfaceY, eyeHeight, accuracy: 0.00001)
                XCTAssertEqual(AngleSceneCalculator.horizontalDistance(camera.position, cue), 0.65, accuracy: 0.00001)
                SCNTransaction.flush()
                if revised {
                    // Initialize renderer viewport before measuring native text positions.
                    if frame == 0 { _ = capture.renderer.snapshot(atTime: time, with: size, antialiasingMode: .multisampling4X) }
                    if yellowAnnotations {
                        // Export-only copies keep the production marker materials untouched.
                        let nodes = [try XCTUnwrap(scene.contactDotNode)] + (scene.angleArcNode?.childNodes.filter { $0.geometry != nil && !($0.geometry is SCNText) } ?? [])
                        for node in nodes {
                            let geometry = try XCTUnwrap(node.geometry?.copy() as? SCNGeometry)
                            geometry.materials = geometry.materials.map { source in
                                let material = source.copy() as! SCNMaterial
                                material.diffuse.contents = UIColor(red: 1, green: 0.82, blue: 0.06, alpha: 1)
                                return material
                            }
                            node.geometry = geometry
                        }
                    }
                    record["spatialLabels"] = try updateSpatialVideoLabels(capture, darkAnnotations: darkAnnotations, yellowAnnotations: yellowAnnotations)
                }
                if frame == 0 { _ = try image(capture, time: time) }
                var shot = try image(capture, time: time)
                if showsInset {
                    let inset = try contactInset(capture, renderer: insetRenderer, camera: insetCamera, base: shot, time: time)
                    shot = inset.0; record["contactInset"] = inset.1
                }
                var projected: [String: [Float]] = [:]
                for (name, world) in [("cue", cue), ("target", capture.target), ("pocket", capture.aim)] {
                    let p = capture.renderer.projectPoint(world)
                    projected[name] = [p.x/Float(size.width), p.y/Float(size.height), p.z]
                    XCTAssertGreaterThan(p.x, Float(size.width)*0.05, name)
                    XCTAssertLessThan(p.x, Float(size.width)*0.95, name)
                    XCTAssertGreaterThan(p.y, Float(size.height)*0.05, name)
                    XCTAssertLessThan(p.y, Float(size.height)*0.95, name)
                }
                record["frame"] = frame
                record["time"] = time
                record["projected"] = projected
                record["cameraPosition"] = [camera.position.x, camera.position.y, camera.position.z]
                record["eyeHeightAboveClothM"] = eyeHeight
                record["darkAnnotations"] = darkAnnotations
                record["yellowAnnotations"] = yellowAnnotations
                records.append(record)
                if stillsOnly {
                    try XCTUnwrap(shot.pngData()).write(to: output.appendingPathComponent("frames/frame-\(frame).png"))
                } else { try writer?.append(XCTUnwrap(shot.cgImage)) }
            }
            if frame % 60 == 0 { print("FIRST_PERSON_PREVIEW frame \(frame)/900") }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        try await writer?.finish()
        try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("preview-frames.json"))
    }

    func testGeometryAndKeyframes() async throws {
        let output = try outputDirectory()
        var records: [[String: Any]] = []
        for mode in ["2d", "3d"] {
            let capture = try makeCapture(mode)
            for i in 0...890 {
                _ = try setAngle(Double(i)/10, in: capture)
                if i % 100 == 0 { await Task.yield() }
            }
            for angle in [0.0, 30, 60, 89] {
                var record = try setAngle(angle, in: capture)
                // Warm pipeline and synchronize presentation before capturing evidence.
                _ = try image(capture, time: 0)
                let shot = try image(capture, time: 0)
                let name = "\(mode)-\(Int(angle))-4k.png"
                try XCTUnwrap(shot.pngData()).write(to: output.appendingPathComponent("frames/"+name))
                record["mode"] = mode
                record["image"] = name
                record["projection"] = try projectionRecord(capture)
                records.append(record)
                print("ANGLE_CAPTURE keyframe \(name)")
                await Task.yield()
            }
        }
        try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("keyframes.json"))
    }

    private func export(_ mode: String) async throws {
        let output = try outputDirectory()
        let capture = try makeCapture(mode)
        _ = try setAngle(0, in: capture)
        _ = try image(capture, time: 0)
        _ = try image(capture, time: 0)
        let writer = try VideoWriter(url: output.appendingPathComponent("angle-aiming-\(mode)-4k.mp4"), size: size, fps: 60)
        var records: [[String: Any]] = []
        for frame in 0..<900 {
            try autoreleasepool {
                let t = Double(frame)/60
                let degrees = max(0, min(89, (t-1)*89/12))
                var record = try setAngle(degrees, in: capture)
                let shot = try image(capture, time: t)
                record["projection"] = try projectionRecord(capture)
                record["frame"] = frame
                record["time"] = t
                records.append(record)
                try writer.append(XCTUnwrap(shot.cgImage))
            }
            if frame % 60 == 0 { print("ANGLE_CAPTURE \(mode) frame \(frame)/900") }
            // Do not starve the simulator host's main run loop while exporting.
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        try await writer.finish()
        try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("\(mode)-frames.json"))
    }

    func testExport2D() async throws { try await export("2d") }
    func testExport3D() async throws { try await export("3d") }
}

// MARK: - Separate silent opening and bridge assets; opt-in media export only.
@MainActor
final class SeparationIntroVideoCaptureTests: XCTestCase {
    private var is2K: Bool { (ProcessInfo.processInfo.environment["SEPARATION_2K"] ?? ProcessInfo.processInfo.environment["TEST_RUNNER_SEPARATION_2K"]) == "1" }
    private var is3D: Bool { (ProcessInfo.processInfo.environment["SEPARATION_VIEW"] ?? ProcessInfo.processInfo.environment["TEST_RUNNER_SEPARATION_VIEW"]) == "3d" }
    private var size: CGSize {
        let env = ProcessInfo.processInfo.environment
        if (env["SEPARATION_4K"] ?? env["TEST_RUNNER_SEPARATION_4K"]) == "1" { return CGSize(width:2160,height:3840) }
        return is2K ? CGSize(width:1440,height:2560) : CGSize(width:1080,height:1920)
    }
    private let distance: Float = 0.60
    private let fps = 60

    private func output() throws -> URL {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["SEPARATION_INTRO_DIR"] ?? env["TEST_RUNNER_SEPARATION_INTRO_DIR"], !path.isEmpty else {
            throw XCTSkip("Opt-in video export: TEST_RUNNER_SEPARATION_INTRO_DIR")
        }
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.appendingPathComponent("frames"), withIntermediateDirectories: true)
        return url
    }

    private struct Capture {
        let scene: AngleTrainingScene
        let renderer: SCNRenderer
        let labelView: SCNView
        let labels: DiagramLabelOverlay
        let target: SCNVector3
        let aim: SCNVector3
        let ghost: SCNVector3
        let transform: simd_float4x4
    }

    private func makeCapture(targetXZ: SIMD2<Float> = SIMD2<Float>(0, 0.10), pocketIndex: Int = 5, fitsCurrentRoom: Bool = false) throws -> Capture {
        let scene = AngleTrainingScene()
        scene.setupScene()
        scene.setupVisualizationNodes()
        scene.usesAdaptiveDiagramLabels = true
        let env = ProcessInfo.processInfo.environment
        let currentAppearance = (env["SEPARATION_CURRENT_APPEARANCE"] ?? env["TEST_RUNNER_SEPARATION_CURRENT_APPEARANCE"]) == "1"
        XCTAssertTrue(scene.applyTableStyle(currentAppearance ? .charcoal : .standard, showsSights: true))
        let greenCloth = (env["SEPARATION_GREEN_CLOTH"] ?? env["TEST_RUNNER_SEPARATION_GREEN_CLOTH"]) == "1"
        scene.applyClothColor(currentAppearance && !greenCloth ? .tournamentBlue : .green)
        if currentAppearance {
            XCTAssertTrue(try XCTUnwrap(scene.cueStick).applyStyle(.inkDragon))
            XCTAssertEqual(scene.cueStick?.style, .inkDragon)
        }
        scene.hideAllBalls()
        let target = SCNVector3(targetXZ.x, scene.surfaceY + AngleSceneCalculator.ballRadius, targetXZ.y)
        scene.showBall(key: "_8", scenePosition: target)
        scene.setCurrentTargetNumber(8)
        scene.showBall(key: PositionPlayBall.cueKey, scenePosition: SCNVector3(-0.6, target.y, 0))
        scene.setCueBallHomeOrientation(simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)))
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: scene.surfaceY)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: aim, ballRadius: AngleSceneCalculator.ballRadius)
        scene.setCameraMode(is3D ? .perspective3D : .topDown2D, animated: false)
        let node = try XCTUnwrap(scene.cameraNode)
        let camera = try XCTUnwrap(node.camera)
        camera.usesOrthographicProjection = true
        camera.projectionDirection = .vertical
        camera.orthographicScale = 1.72
        camera.zNear = 0.01
        camera.zFar = 100
        camera.wantsExposureAdaptation = false
        let center = SCNVector3(0.20, scene.surfaceY, 0)
        node.position = SCNVector3(center.x, scene.surfaceY + 3, center.z)
        node.look(at: center, up: SCNVector3(1, 0, 0), localFront: SCNVector3(0, 0, -1))
        if is3D {
            camera.usesOrthographicProjection=false;camera.fieldOfView=40
            let elevationText = env["SEPARATION_CAMERA_ELEVATION"] ?? env["TEST_RUNNER_SEPARATION_CAMERA_ELEVATION"] ?? "35"
            let elevationDegrees = try XCTUnwrap(Float(elevationText))
            XCTAssertTrue(elevationDegrees.isFinite && elevationDegrees > 0 && elevationDegrees < 90)
            let elevation = elevationDegrees * .pi / 180
            let referenceDistance: Float = 5.10
            let distance = fitsCurrentRoom ? min(referenceDistance, BakedTrainingRoom.cameraSafeHalfExtents.x / cos(elevation)) : referenceDistance
            if fitsCurrentRoom {
                // Preserve the near rail's projected width, so moving inside the
                // current room does not crop the table's front corners.
                let nearOffset = Float(try XCTUnwrap(scene.cameraRig).tableOuterHalfLength) * cos(elevation)
                let referenceDepth = referenceDistance - nearOffset
                let currentDepth = distance - nearOffset
                XCTAssertGreaterThan(currentDepth, 0)
                camera.fieldOfView = CGFloat(2 * atan(referenceDepth / currentDepth * tan(Float(20) * .pi / 180)) * 180 / .pi)
            }
            let focus=SCNVector3(0,scene.surfaceY,0)
            node.position=SCNVector3(-distance*cos(elevation),focus.y+distance*sin(elevation),0)
            node.look(at:focus,up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
        }
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene
        renderer.pointOfView = node
        renderer.autoenablesDefaultLighting = false
        renderer.delegate = scene.contactOcclusion
        let labelView = SCNView(frame:CGRect(x:0,y:0,width:360,height:640))
        labelView.scene = scene; labelView.pointOfView = node; labelView.layoutIfNeeded()
        return Capture(scene: scene, renderer: renderer, labelView:labelView, labels:DiagramLabelOverlay(), target: target, aim: aim, ghost: ghost, transform: node.simdTransform)
    }

    private func setAngle(_ degrees: Double, _ c: Capture, centerDistance: Float? = nil, requiresNegativeX: Bool = true) throws -> [String: Any] {
        let distance = centerDistance ?? self.distance
        let a = Float(degrees * .pi / 180)
        let n = simd_normalize(SIMD2<Float>(c.aim.x-c.target.x, c.aim.z-c.target.z))
        let side = SIMD2<Float>(-n.y, n.x) // Incoming -X: downward departure in portrait.
        let direction = n*cos(a) + side*sin(a)
        let diameter = 2 * AngleSceneCalculator.ballRadius
        // Solve |G - L*direction - T| = fixed center-to-center distance.
        let length = -diameter*cos(a) + sqrt(distance*distance - pow(diameter*sin(a), 2))
        let cue = SCNVector3(c.ghost.x-length*direction.x, c.target.y, c.ghost.z-length*direction.y)
        try XCTUnwrap(c.scene.cueBallNode).position = cue
        c.scene.updateVisualization(cueBall: cue, targetBall: c.target, pocket: c.aim,
                                    showAngleAnnotations: true, showOverlapMarkers: false, showLineLabels: false, extendStrikeLineToRail: true)
        c.scene.updateCueStick(cueBallPosition: cue, aimDirection: SCNVector3(direction.x, 0, direction.y))
        let measured = AngleSceneCalculator.cutAngle(cueBall: cue, targetBall: c.target, pocket: c.aim)
        XCTAssertEqual(measured, degrees, accuracy: 0.001)
        XCTAssertEqual(AngleSceneCalculator.horizontalDistance(cue, c.target), distance, accuracy: 0.00001)
        XCTAssertLessThan(abs(cue.x)+AngleSceneCalculator.ballRadius, AngleSceneCalculator.innerLength/2)
        XCTAssertLessThan(abs(cue.z)+AngleSceneCalculator.ballRadius, AngleSceneCalculator.innerWidth/2)
        if requiresNegativeX { XCTAssertLessThanOrEqual(direction.x, 0.00001) }
        XCTAssertEqual(c.scene.cameraNode.simdTransform, c.transform)
        XCTAssertFalse(try XCTUnwrap(c.scene.cueStick).rootNode.isHidden)
        SCNTransaction.flush()
        return ["degrees": measured, "distanceM": AngleSceneCalculator.horizontalDistance(cue, c.target),
                "cue": [cue.x, cue.y, cue.z], "target": [c.target.x,c.target.y,c.target.z]]
    }

    private func projected(_ world: SCNVector3, _ c: Capture) -> CGPoint {
        let p = c.labelView.projectPoint(world)
        return CGPoint(x:CGFloat(p.x)*3,y:CGFloat(p.y)*3)
    }

    private func base(_ c: Capture, time: Double, drawsAngleText: Bool = true, renderSize: CGSize? = nil) -> UIImage {
        let size = renderSize ?? self.size
        c.labels.update(scene:c.scene,in:c.labelView)
        let shot = c.renderer.snapshot(atTime:time,with:size,antialiasingMode:.multisampling4X)
        let angleLabels = c.labelView.subviews.compactMap { $0 as? UILabel }.filter { $0.accessibilityIdentifier == "angleDiagram.label.0" }
        XCTAssertEqual(angleLabels.count,1)
        XCTAssertTrue(angleLabels.allSatisfy { !$0.isHidden && ($0.text?.hasSuffix("°") ?? false) })
        for world in [c.target,c.ghost] {
            let r = c.renderer.projectPoint(world); let v = c.labelView.projectPoint(world)
            XCTAssertEqual(r.x/Float(size.width/360),v.x,accuracy:0.1)
            XCTAssertEqual(Float(size.height)/(Float(size.width/360))-r.y/Float(size.width/360),v.y,accuracy:0.1)
        }
        let format = UIGraphicsImageRendererFormat(); format.scale=1; format.opaque=true
        return UIGraphicsImageRenderer(size:size,format:format).image { ctx in
            UIColor.black.setFill(); ctx.fill(CGRect(origin:.zero,size:size))
            shot.draw(in:CGRect(origin:.zero,size:size))
            let cg=ctx.cgContext; cg.saveGState(); cg.scaleBy(x:size.width/360,y:size.width/360)
            for layer in c.labelView.layer.sublayers ?? [] {
                guard let shape=layer as? CAShapeLayer,shape.name == "angleDiagram.arc",!shape.isHidden,let path=shape.path else { continue }
                cg.addPath(path);cg.setStrokeColor(shape.strokeColor ?? UIColor.white.cgColor)
                cg.setLineWidth(shape.lineWidth);cg.setLineCap(.round);cg.strokePath()
            }
            // Compose the production angle only; never compose the two line-name labels.
            for label in angleLabels where drawsAngleText {
                cg.saveGState();cg.translateBy(x:label.frame.minX,y:label.frame.minY)
                label.layer.render(in:cg);cg.restoreGState()
            }
            cg.restoreGState()
        }
    }

    private func compose(_ shot: UIImage, angle: Double, bridgeTime: Double?, simulation: Bool = false, capture: Capture? = nil, animated: Bool = false) -> UIImage {
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        return UIGraphicsImageRenderer(size:size,format:format).image { ctx in
            UIColor.black.setFill();ctx.fill(CGRect(origin:.zero,size:size))
            shot.draw(in:CGRect(origin:.zero,size:size))
            ctx.cgContext.scaleBy(x:size.width/1080,y:size.width/1080)
            func text(_ value:String,_ rect:CGRect,_ fontSize:CGFloat,_ color:UIColor = .white) {
                let p=NSMutableParagraphStyle();p.alignment = .center
                (value as NSString).draw(in:rect,withAttributes:[.font:UIFont.systemFont(ofSize:fontSize,weight:.semibold),.foregroundColor:color,.paragraphStyle:p])
            }
            func box(_ r:CGRect) {
                UIColor.black.withAlphaComponent(0.82).setFill()
                UIBezierPath(roundedRect:r,cornerRadius:18).fill()
            }
            let gold=UIColor(red:1,green:0.84,blue:0.35,alpha:1)
            if simulation {
                let spins=SeparationAngleAtlasGeometry.spinYLevels()
                let legendOffset:CGFloat = is3D ? 293 : 0
                text("高",CGRect(x:96,y:220+legendOffset,width:60,height:46),30)
                text("低",CGRect(x:925,y:220+legendOffset,width:60,height:46),30)
                for i in 0..<8 {
                    let x=CGFloat(175+i*96)
                    UIColor.white.setFill();UIBezierPath(ovalIn:CGRect(x:x,y:207+legendOffset,width:55,height:55)).fill()
                    SeparationAngleAtlasGeometry.trackColor(at:i).setFill()
                    UIBezierPath(ovalIn:CGRect(x:x+21,y:228+legendOffset-CGFloat(spins[i])*27.5,width:13,height:13)).fill()
                }
            }
            if bridgeTime != nil, let c=capture,let cueNode=c.scene.cueBallNode {
                let cue=projected(cueNode.position,c);let target=projected(c.target,c)
                let dx=target.x-cue.x,dy=target.y-cue.y
                let len=max(1,hypot(dx,dy));let n=CGPoint(x:dy/len,y:-dx/len)
                let from=CGPoint(x:cue.x+n.x*65,y:cue.y+n.y*65)
                let to=CGPoint(x:target.x+n.x*65,y:target.y+n.y*65)
                let mid=CGPoint(x:(from.x+to.x)/2,y:(from.y+to.y)/2)
                let panelOffset:CGFloat = is3D ? -160 : 0
                let t = bridgeTime ?? 0
                func ramp(_ start:Double,_ duration:Double = 0.4)->CGFloat {
                    if !animated { return 1 }
                    let p = min(1,max(0,(t-start)/duration));return CGFloat(p*p*(3-2*p))
                }
                let exit:CGFloat = animated ? 1-ramp(11.4,0.5) : 1
                let cg=ctx.cgContext
                let clipLegend = is3D
                func path(_ points:[CGPoint],_ progress:CGFloat) {
                    guard progress > 0,points.count>1 else{return}
                    let lengths=zip(points,points.dropFirst()).map{hypot($1.x-$0.x,$1.y-$0.y)}
                    var remaining=lengths.reduce(0,+)*progress
                    cg.saveGState()
                    if clipLegend {
                        let mask=CGMutablePath();mask.addRect(CGRect(x:0,y:0,width:1080,height:1920))
                        for i in 0..<8 { mask.addEllipse(in:CGRect(x:CGFloat(175+i*96)-3,y:497,width:61,height:61)) }
                        cg.addPath(mask);cg.clip(using:.evenOdd)
                    }
                    cg.beginPath();cg.move(to:points[0])
                    for i in lengths.indices {
                        let q=min(1,remaining/max(0.001,lengths[i]))
                        cg.addLine(to:CGPoint(x:points[i].x+(points[i+1].x-points[i].x)*q,y:points[i].y+(points[i+1].y-points[i].y)*q))
                        remaining-=lengths[i];if remaining<=0{break}
                    }
                    cg.strokePath();cg.restoreGState()
                }
                cg.saveGState();cg.setAlpha(exit);cg.setStrokeColor(gold.cgColor);cg.setLineWidth(2.5)
                let shaft=CGPoint(x:cue.x-dx/len*72,y:cue.y-dy/len*72)
                path([shaft,CGPoint(x:340,y:575+panelOffset)],ramp(0.3,0.5))
                cg.saveGState();cg.setAlpha(exit*ramp(0.65))
                box(CGRect(x:160,y:410+panelOffset,width:370,height:165))
                text("球杆速度固定",CGRect(x:175,y:430+panelOffset,width:340,height:55),37)
                cg.restoreGState()
                cg.saveGState();cg.setAlpha(exit*ramp(2.0))
                let speedScale:CGFloat = 1+0.08*(1-ramp(2.0))
                cg.translateBy(x:345,y:523+panelOffset);cg.scaleBy(x:speedScale,y:speedScale);cg.translateBy(x:-345,y:-(523+panelOffset))
                text("3 m/s",CGRect(x:175,y:493+panelOffset,width:340,height:60),44,gold);cg.restoreGState()
                let distanceProgress=ramp(4.0,0.5)
                path([from,to],distanceProgress)
                cg.saveGState();cg.setAlpha(exit*distanceProgress)
                for point in [from,to] {
                    path([CGPoint(x:point.x-n.x*10,y:point.y-n.y*10),CGPoint(x:point.x+n.x*10,y:point.y+n.y*10)],1)
                }
                cg.setLineDash(phase:0,lengths:[6,6]);path([cue,from],1);path([target,to],1)
                cg.setLineDash(phase:0,lengths:[]);cg.restoreGState()
                path([mid,CGPoint(x:745,y:mid.y-55),CGPoint(x:745,y:575+panelOffset)],ramp(4.2,0.5))
                cg.saveGState();cg.setAlpha(exit*ramp(4.5))
                box(CGRect(x:560,y:410+panelOffset,width:370,height:165))
                text("两球球心距固定",CGRect(x:575,y:430+panelOffset,width:340,height:55),35);cg.restoreGState()
                cg.saveGState();cg.setAlpha(exit*ramp(6.2))
                let distanceScale:CGFloat = 1+0.08*(1-ramp(6.2))
                cg.translateBy(x:745,y:523+panelOffset);cg.scaleBy(x:distanceScale,y:distanceScale);cg.translateBy(x:-745,y:-(523+panelOffset))
                text("60 cm",CGRect(x:575,y:493+panelOffset,width:340,height:60),44,gold)
                cg.restoreGState();cg.restoreGState()
            }
        }
    }

    private func degrees(_ t: Double) -> Double {
        let p = min(1, max(0, t/(299.0/60.0)))
        return 60*(p*p*(3-2*p))
    }

    private func drawTracks(_ c: Capture, nodes: inout [SCNNode], precise: Bool = false, colors: [UIColor] = SeparationAngleAtlasGeometry.trackColors, pathObserver: (([SCNVector3]) -> Void)? = nil) throws -> [Int] {
        c.scene.clearResultNodes(nodes: &nodes)
        let cue = try XCTUnwrap(c.scene.cueBallNode).position
        let d = simd_normalize(SIMD2<Float>(c.ghost.x-cue.x,c.ghost.z-cue.z))
        var counts: [Int] = []
        for (i,spin) in SeparationAngleAtlasGeometry.spinYLevels().enumerated() {
            let pred = ShotPredictor.simulateFree(cueBall:cue,aimDir:SCNVector3(d.x,0,d.y),velocity:3,
                spinX:0,spinY:spin,surfaceY:c.scene.surfaceY,
                balls:[ObstacleBall(name:ShotInput.targetBallName,position:c.target)])
            guard SeparationAngleAtlasGeometry.hasCompleteSlice(pred) else {
                throw NSError(domain:"SeparationIntroCapture",code:1,userInfo:[NSLocalizedDescriptionKey:"Incomplete simulation: cut=\(AngleSceneCalculator.cutAngle(cueBall:cue,targetBall:c.target,pocket:c.aim)), spin index \(i), termination=\(String(describing:pred.termination))"])
            }
            var path = SeparationAngleAtlasGeometry.pathAfterContactToFirstCueCushion(pred)
            if precise, let recorder=pred.recorder, let contact=SeparationAngleAtlasGeometry.firstBallBallEvent(in:pred.events) {
                let end=SeparationAngleAtlasGeometry.firstCueCushionAfterBallBall(in:pred.events)?.time ?? pred.duration
                path=[]
                // Recorder.stateAt is a ceiling-record lookup and may return a post-cushion
                // frame. Evaluate the actual requested instant and clamp the final sample.
                let playback=TrajectoryPlayback(recorder:recorder,surfaceY:cue.y)
                let steps=max(1,Int(ceil((end-contact.time)*240)))
                for step in 0...steps {
                    let time = step == steps ? end : min(end,contact.time+(end-contact.time)*Float(step)/Float(steps))
                    XCTAssertLessThanOrEqual(time,end)
                    let state=try XCTUnwrap(playback.stateAt(ballName:ShotInput.cueBallName,time:time))
                    path.append(state.position)
                }
            }
            pathObserver?(path)
            counts.append(path.count)
            if path.count >= 2 {
                c.scene.addDashedPolyline(path,color:colors[i],
                    radius:TrajectoryStyle.lineMain,placement:.table,into:&nodes)
            }
        }
        SCNTransaction.flush()
        return counts
    }

    func testFirstCushionSamplingBoundary() throws {
        let dir=try output(),c=try makeCapture()
        var rows:[[String:Any]]=[]
        for angle in [15.0,30,60,89] {
            _=try setAngle(angle,c)
            let cue=try XCTUnwrap(c.scene.cueBallNode).position
            let d=simd_normalize(SIMD2<Float>(c.ghost.x-cue.x,c.ghost.z-cue.z))
            for (i,spin) in SeparationAngleAtlasGeometry.spinYLevels().enumerated() {
                let p=ShotPredictor.simulateFree(cueBall:cue,aimDir:SCNVector3(d.x,0,d.y),velocity:3,spinX:0,spinY:spin,surfaceY:c.scene.surfaceY,balls:[ObstacleBall(name:ShotInput.targetBallName,position:c.target)])
                guard let end=SeparationAngleAtlasGeometry.firstCueCushionAfterBallBall(in:p.events) else {continue}
                let r=try XCTUnwrap(p.recorder),play=TrajectoryPlayback(recorder:r,surfaceY:cue.y)
                let before=try XCTUnwrap(play.stateAt(ballName:ShotInput.cueBallName,time:end.time.nextDown))
                let exact=try XCTUnwrap(play.stateAt(ballName:ShotInput.cueBallName,time:end.time))
                let contact=try XCTUnwrap(SeparationAngleAtlasGeometry.firstBallBallEvent(in:p.events))
                let steps=max(1,Int(ceil((end.time-contact.time)*240)))
                let legacyLastTime=contact.time+(end.time-contact.time)*Float(steps)/Float(steps)
                let old=try XCTUnwrap(r.stateAt(ballName:ShotInput.cueBallName,time:legacyLastTime))
                let jump=AngleSceneCalculator.horizontalDistance(before.position,exact.position)
                XCTAssertLessThan(jump,0.001,"Boundary discontinuity angle=\(angle), spin=\(i)")
                rows.append(["angle":angle,"spin":i,"cushionTime":end.time,"legacyLastTime":legacyLastTime,"oldLookupTime":old.time,"oldOvershootM":AngleSceneCalculator.horizontalDistance(old.position,exact.position),"endpointJumpM":jump])
            }
        }
        XCTAssertFalse(rows.isEmpty)
        try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]).write(to:dir.appendingPathComponent("boundary-audit.json"))
    }

    func testSimulationContinuityProbe() throws {
        _ = try output();let c=try makeCapture()
        _ = try setAngle(41.4,c)
        let cue=try XCTUnwrap(c.scene.cueBallNode).position
        let d=simd_normalize(SIMD2<Float>(c.ghost.x-cue.x,c.ghost.z-cue.z))
        for limit:Float in [15,30] {
            let pred=ShotPredictor.simulateFree(cueBall:cue,aimDir:SCNVector3(d.x,0,d.y),velocity:3,spinX:0,
                spinY:SeparationAngleAtlasGeometry.spinYLevels()[2],surfaceY:c.scene.surfaceY,
                balls:[ObstacleBall(name:ShotInput.targetBallName,position:c.target)],maxTime:limit)
            print("SEPARATION_PROBE limit=\(limit) duration=\(pred.duration) termination=\(String(describing:pred.termination)) speed=\(pred.cueFinalSpeed) events=\(pred.events.count) contact=\(String(describing:SeparationAngleAtlasGeometry.firstBallBallEvent(in:pred.events))) cushion=\(String(describing:SeparationAngleAtlasGeometry.firstCueCushionAfterBallBall(in:pred.events))) end=\(String(describing:pred.cuePath.last))")
        }
    }

    func testKeyframes() throws {
        let dir = try output(); let c = try makeCapture()
        for a in [0.0, 30, 45, 60] { _ = try setAngle(a, c) }
        for (name,a,t) in [("hook-start",0.0,Double?.none),("hook-end",60.0,Double?.none),("bridge-constraints",60.0,Optional(1.0))] {
            _ = try setAngle(a,c); _ = base(c,time:0)
            let image = compose(base(c,time:0),angle:a,bridgeTime:t,capture:c)
            try XCTUnwrap(image.pngData()).write(to: dir.appendingPathComponent("frames/\(name).png"))
        }
        var nodes: [SCNNode] = []
        for angle in [0.0,30,60] {
            _ = try setAngle(angle,c)
            let counts = try drawTracks(c,nodes:&nodes)
            _ = base(c,time:0)
            let image = compose(base(c,time:0),angle:angle,bridgeTime:nil,simulation:true)
            try XCTUnwrap(image.pngData()).write(to:dir.appendingPathComponent("frames/simulation-\(Int(angle)).png"))
            print("SEPARATION_INTRO simulation keyframe \(angle), counts \(counts)")
        }
        print("SEPARATION_INTRO keyframes complete")
    }

    func testExportBoth() async throws {
        let dir = try output(); let c = try makeCapture()
        var records: [[String:Any]] = []
        _ = try setAngle(0,c); _ = base(c,time:0); _ = base(c,time:0)
        let hook = try VideoWriter(url:dir.appendingPathComponent("01-opening-silent.mp4"),size:size,fps:fps)
        for frame in 0..<300 {
            try autoreleasepool {
                let t = Double(frame)/Double(fps); let a = degrees(t)
                var record = try setAngle(a,c); record["frame"] = frame; records.append(record)
                try hook.append(XCTUnwrap(compose(base(c,time:t),angle:a,bridgeTime:nil).cgImage))
            }
            if frame % 60 == 0 { print("SEPARATION_INTRO hook \(frame)/300") }
            try await Task.sleep(nanoseconds:1_000_000)
        }
        try await hook.finish()
        _ = try setAngle(0,c)
        var nodes:[SCNNode] = []
        _ = try drawTracks(c,nodes:&nodes)
        _ = base(c,time:0)
        let annotated = compose(base(c,time:0),angle:0,bridgeTime:0,simulation:true,capture:c)
        try XCTUnwrap(annotated.pngData()).write(to:dir.appendingPathComponent("02-simulation-first-frame.png"))
        try JSONSerialization.data(withJSONObject:records,options:[.prettyPrinted,.sortedKeys]).write(to:dir.appendingPathComponent("geometry.json"))
        print("SEPARATION_INTRO both silent videos complete")
    }
    func testExportAnimatedTransition() async throws {
        let dir=try output();let c=try makeCapture()
        _ = try setAngle(0,c);var nodes:[SCNNode]=[]
        _ = try drawTracks(c,nodes:&nodes);_ = base(c,time:0)
        let still=base(c,time:0)
        let writer=try VideoWriter(url:dir.appendingPathComponent("transition-silent.mp4"),size:size,fps:fps)
        for frame in 0..<720 {
            try autoreleasepool {
                let image=compose(still,angle:0,bridgeTime:Double(frame)/60,simulation:true,capture:c,animated:true)
                try writer.append(XCTUnwrap(image.cgImage))
            }
            try await Task.sleep(nanoseconds:1_000_000)
        }
        try await writer.finish()
    }

    private func composeDirectAtlas(_ shot:UIImage, angle:Double, parameters: String = "杆速 3 m/s  ·  球心距 60 cm", parameterBackground: Bool = true, trackColors: [UIColor] = SeparationAngleAtlasGeometry.trackColors, legendY: CGFloat? = nil, infoY: CGFloat? = nil, outputSize: CGSize? = nil) -> UIImage {
        let size = outputSize ?? self.size
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        return UIGraphicsImageRenderer(size:size,format:format).image { ctx in
            shot.draw(in:CGRect(origin:.zero,size:size))
            ctx.cgContext.scaleBy(x:size.width/1080,y:size.width/1080)
            func label(_ value:String,_ rect:CGRect,_ font:CGFloat,_ color:UIColor = .white) {
                let p=NSMutableParagraphStyle();p.alignment = .center
                (value as NSString).draw(in:rect,withAttributes:[.font:UIFont.systemFont(ofSize:font,weight:.semibold),.foregroundColor:color,.paragraphStyle:p])
            }
            let y:CGFloat=legendY ?? (is3D ? 460 : 390)
            let spins=SeparationAngleAtlasGeometry.spinYLevels()
            label("高",CGRect(x:105,y:y+23,width:55,height:50),34)
            label("低",CGRect(x:930,y:y+23,width:55,height:50),34)
            for i in 0..<8 {
                let x=CGFloat(171+i*94)
                UIColor.white.setFill();UIBezierPath(ovalIn:CGRect(x:x,y:y,width:86,height:86)).fill()
                let env = ProcessInfo.processInfo.environment
                if (env["SEPARATION_SPIN_CROSSHAIR"] ?? env["TEST_RUNNER_SEPARATION_SPIN_CROSSHAIR"]) == "1" {
                    let cross = UIBezierPath()
                    cross.move(to: CGPoint(x: x, y: y + 43))
                    cross.addLine(to: CGPoint(x: x + 86, y: y + 43))
                    cross.move(to: CGPoint(x: x + 43, y: y))
                    cross.addLine(to: CGPoint(x: x + 43, y: y + 86))
                    let cg = ctx.cgContext
                    cg.saveGState()
                    cg.setStrokeColor(UIColor(red: 0.82, green: 0.10, blue: 0.14, alpha: 1).cgColor)
                    cg.setLineWidth(1)
                    cg.setLineCap(.butt)
                    cg.setLineDash(phase: 0, lengths: [])
                    cg.addPath(cross.cgPath)
                    cg.strokePath()
                    cg.restoreGState()
                }
                trackColors[i].setFill()
                UIBezierPath(ovalIn:CGRect(x:x+33,y:y+33-CGFloat(spins[i])*43,width:20,height:20)).fill()
            }
            let parameterY:CGFloat=infoY ?? (is3D ? 355 : 508)
            if parameterBackground {
                UIColor.black.withAlphaComponent(0.78).setFill()
                UIBezierPath(roundedRect:CGRect(x:190,y:parameterY,width:700,height:68),cornerRadius:16).fill()
            }
            label(parameters,CGRect(x:200,y:parameterY+12,width:680,height:48),34)
            if angle >= 89.99 {
                label("90°：擦边极限",CGRect(x:340,y:parameterY+78,width:400,height:45),29)
            }
        }
    }

    // Opt-in trilogy parameter study. CueBallStrike's velocity is cue-tip speed.
    private func seriesPredictions(_ c: Capture, speed: Float, spins: [Float]? = nil) throws -> [ShotPrediction] {
        let cue=try XCTUnwrap(c.scene.cueBallNode).position
        let d=simd_normalize(SIMD2<Float>(c.ghost.x-cue.x,c.ghost.z-cue.z))
        return (spins ?? SeparationAngleAtlasGeometry.spinYLevels()).map { spin in
            ShotPredictor.simulateFree(cueBall:cue,aimDir:SCNVector3(d.x,0,d.y),velocity:speed,
                spinX:0,spinY:spin,surfaceY:c.scene.surfaceY,
                balls:[ObstacleBall(name:ShotInput.targetBallName,position:c.target)])
        }
    }

    private func seriesPocket(_ pred: ShotPrediction) -> String? {
        for event in pred.events {
            if case .pocket(let ball,let pocketId)=event.kind, ball==ShotInput.targetBallName { return pocketId }
        }
        return nil
    }

    private func seriesPaths(_ predictions: [ShotPrediction], _ c: Capture, nodes: inout [SCNNode]) throws -> [Int] {
        c.scene.clearResultNodes(nodes:&nodes)
        var counts:[Int]=[]
        for (i,pred) in predictions.enumerated() {
            XCTAssertTrue(SeparationAngleAtlasGeometry.hasCompleteSlice(pred),"Incomplete spin \(i): \(String(describing:pred.termination))")
            let recorder=try XCTUnwrap(pred.recorder)
            let contact=try XCTUnwrap(SeparationAngleAtlasGeometry.firstBallBallEvent(in:pred.events))
            var end=SeparationAngleAtlasGeometry.firstCueCushionAfterBallBall(in:pred.events)?.time ?? pred.duration
            for event in pred.events where event.time>=contact.time {
                if case .pocket(let ball,_)=event.kind,ball==ShotInput.cueBallName { end=min(end,event.time) }
            }
            let steps=max(1,Int(ceil((end-contact.time)*240)))
            var path:[SCNVector3]=[]
            for step in 0...steps {
                let t=contact.time+(end-contact.time)*Float(step)/Float(steps)
                path.append(try XCTUnwrap(recorder.stateAt(ballName:ShotInput.cueBallName,time:t)).position)
            }
            counts.append(path.count)
            c.scene.addDashedPolyline(path,color:SeparationAngleAtlasGeometry.trackColor(at:i),radius:TrajectoryStyle.lineMain,placement:.table,into:&nodes)
        }
        SCNTransaction.flush()
        return counts
    }

    private func seriesImage(_ c: Capture, speed: Float, distance: Float, distanceEpisode: Bool, time: Double) throws -> UIImage {
        let text=distanceEpisode ? String(format:"杆速 3 m/s  ·  球心距 %.0f cm",distance*100) : "球心距 60 cm"
        let image=composeDirectAtlas(base(c,time:time),angle:15,parameters:text,parameterBackground:distanceEpisode)
        let cue=projected(try XCTUnwrap(c.scene.cueBallNode).position,c)
        let target=projected(c.target,c)
        if !distanceEpisode {
            // Center in the visible ball-to-ball segment, in the existing 1080-wide UIKit viewport.
            let midpoint=CGPoint(x:(cue.x+target.x)/2,y:(cue.y+target.y)/2)
            let value=String(format:"杆速 %.2f m/s",speed) as NSString
            let attributes:[NSAttributedString.Key:Any] = [
                .font:UIFont.monospacedDigitSystemFont(ofSize:30,weight:.semibold),
                .foregroundColor:UIColor.white
            ]
            let extent=value.size(withAttributes:attributes)
            let dx=target.x-cue.x,dy=target.y-cue.y
            let length=hypot(dx,dy)
            let normal=CGPoint(x:dy/length,y:-dx/length)
            let side:CGFloat=normal.y <= 0 ? 1 : -1
            // Keep the entire horizontal text box clear of the line, anchored to its midpoint.
            let clearance=(abs(normal.x)*extent.width+abs(normal.y)*extent.height)/2+12
            let center=CGPoint(x:midpoint.x+normal.x*side*clearance,y:midpoint.y+normal.y*side*clearance)
            let origin=CGPoint(x:center.x-extent.width/2,y:center.y-extent.height/2)
            let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
            return UIGraphicsImageRenderer(size:size,format:format).image { context in
                image.draw(in:CGRect(origin:.zero,size:size))
                context.cgContext.scaleBy(x:size.width/1080,y:size.width/1080)
                value.draw(at:origin,withAttributes:attributes)
            }
        }
        let dx=target.x-cue.x,dy=target.y-cue.y,len=hypot(dx,dy)
        let normal=CGPoint(x:dy/len,y:-dx/len)
        let offset:CGFloat=48
        let a=CGPoint(x:cue.x+normal.x*offset,y:cue.y+normal.y*offset)
        let f=UIGraphicsImageRendererFormat();f.scale=1;f.opaque=true
        return UIGraphicsImageRenderer(size:size,format:f).image { ctx in
            image.draw(in:CGRect(origin:.zero,size:size))
            let cg=ctx.cgContext;cg.scaleBy(x:size.width/1080,y:size.width/1080)
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.85).cgColor);cg.setLineWidth(2.5)
            // Right-side curly brace opens toward the two balls; local v follows their center line.
            func point(_ u:CGFloat,_ v:CGFloat)->CGPoint {
                CGPoint(x:a.x+normal.x*u+dx/len*v,y:a.y+normal.y*u+dy/len*v)
            }
            let width:CGFloat=18
            let half=len/2
            cg.setLineCap(.round);cg.setLineJoin(.round)
            cg.move(to:point(0,0))
            cg.addCurve(to:point(width,half*0.32),control1:point(width,0),control2:point(width,half*0.10))
            cg.addCurve(to:point(width,half*0.70),control1:point(width,half*0.42),control2:point(width,half*0.60))
            cg.addCurve(to:point(width*2,half),control1:point(width,half*0.92),control2:point(width*2,half*0.92))
            cg.addCurve(to:point(width,half*1.30),control1:point(width*2,half*1.08),control2:point(width,half*1.08))
            cg.addCurve(to:point(width,half*1.68),control1:point(width,half*1.40),control2:point(width,half*1.58))
            cg.addCurve(to:point(0,len),control1:point(width,half*1.90),control2:point(width,len))
            cg.strokePath()
            let mid=point(width,half)
            let numberRect=CGRect(x:mid.x-59,y:mid.y-23,width:118,height:46)
            UIColor.black.withAlphaComponent(0.78).setFill()
            UIBezierPath(roundedRect:numberRect,cornerRadius:8).fill()
            let paragraph=NSMutableParagraphStyle();paragraph.alignment = .center
            (String(format:"%.0f cm",distance*100) as NSString).draw(in:numberRect.insetBy(dx:3,dy:6),withAttributes:[.font:UIFont.monospacedDigitSystemFont(ofSize:28,weight:.semibold),.foregroundColor:UIColor.white,.paragraphStyle:paragraph])
        }
    }

    func testSearchSeriesParameters() async throws {
        let dir=try output();let speedCapture=try makeCapture()
        _=try setAngle(15,speedCapture)
        var searchRows:[[String:Any]]=[]
        func evaluate(_ speed:Float) throws -> Bool {
            let predictions=try seriesPredictions(speedCapture,speed:speed)
            let pockets=predictions.map{seriesPocket($0) ?? "none"}
            let all=pockets.allSatisfy{$0=="pocket_5"}
            searchRows.append(["cueSpeedMps":speed,"targetPockets":pockets,"allEightPotted":all])
            return all
        }
        var coarse:Float?
        for i in 1...100 {
            let speed=Float(i)*0.05
            if try evaluate(speed) { coarse=speed;break }
            if i % 10==0 { print("SERIES_SEARCH speed=\(speed)") }
            await Task.yield()
        }
        let upper=try XCTUnwrap(coarse,"No all-eight passing cue speed in 0.05...5m/s")
        var minimum=upper
        let lowerStep=max(1,Int(((upper-0.05)*1000).rounded()))
        for step in lowerStep...Int((upper*1000).rounded()) {
            if try evaluate(Float(step)/1000) { minimum=Float(step)/1000;break }
        }
        let start=(minimum*100).rounded(.up)/100
        XCTAssertTrue(try evaluate(start))
        let distanceCapture=try makeCapture(targetXZ:SIMD2<Float>(-0.78,0.46),pocketIndex:2)
        var keyframes:[[String:Any]]=[];var nodes:[SCNNode]=[]
        for (kind,c,values) in [("speed",speedCapture,[start,(start+5)/2,5]),("distance",distanceCapture,[Float(0.8),1.2,1.6])] {
            for (index,value) in values.enumerated() {
                let speed:Float=kind=="speed" ? value : 3
                let distance:Float=kind=="distance" ? value : 0.6
                var record=try setAngle(15,c,centerDistance:distance)
                let predictions=try seriesPredictions(c,speed:speed)
                record["counts"]=try seriesPaths(predictions,c,nodes:&nodes)
                record["targetPockets"]=predictions.map{seriesPocket($0) ?? "none"}
                record["kind"]=kind;record["speed"]=speed
                _=base(c,time:0)
                let image=try seriesImage(c,speed:speed,distance:distance,distanceEpisode:kind=="distance",time:0)
                try XCTUnwrap(image.pngData()).write(to:dir.appendingPathComponent("frames/\(kind)-\(index).png"))
                keyframes.append(record)
            }
        }
        let report:[String:Any]=["coarseStepMps":0.05,"fineStepMps":0.001,"minimumPassingMps":minimum,"videoStartMps":start,"videoEndMps":5,"distanceStartM":0.8,"distanceEndM":1.6,"search":searchRows,"keyframes":keyframes]
        try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:dir.appendingPathComponent("search.json"))
        print("SERIES_SEARCH_RESULT min=\(minimum), display=\(start)")
    }

    func testPreflightSeriesSpeed() async throws {
        let dir=try output();let env=ProcessInfo.processInfo.environment
        let path=try XCTUnwrap(env["SEPARATION_SEARCH"] ?? env["TEST_RUNNER_SEPARATION_SEARCH"])
        let search=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:path))) as? [String:Any])
        let start=try XCTUnwrap(search["videoStartMps"] as? NSNumber).floatValue
        let end=try XCTUnwrap(search["videoEndMps"] as? NSNumber).floatValue
        let c=try makeCapture();_=try setAngle(15,c)
        var failures:[[String:Any]]=[]
        for frame in 0...720 {
            let speed=start+(end-start)*(Float(frame)/720)
            let predictions=try seriesPredictions(c,speed:speed)
            for (i,pred) in predictions.enumerated() {
                if !SeparationAngleAtlasGeometry.hasCompleteSlice(pred) || seriesPocket(pred) != "pocket_5" {
                    failures.append(["step":frame,"speed":speed,"spinIndex":i,"targetPocket":seriesPocket(pred) ?? "none","termination":String(describing:pred.termination)])
                }
            }
            if frame % 120==0 { print("SERIES_PREFLIGHT \(frame)/720") }
            await Task.yield()
        }
        try JSONSerialization.data(withJSONObject:failures,options:[.prettyPrinted,.sortedKeys]).write(to:dir.appendingPathComponent("speed-preflight-failures.json"))
        XCTAssertTrue(failures.isEmpty,"Incomplete parameter samples: \(failures)")
    }

    private var oneCushionColors: [UIColor] {
        let colorHex: [UInt32] = [0xFF625C, 0xFFA43A, 0xFFE867, 0xFF9DDA,
                                   0x78E7FF, 0x61B3FF, 0xB4ABFF, 0xED78FF]
        let colors = colorHex.map { value in
            UIColor(red: CGFloat((value >> 16) & 255) / 255,
                    green: CGFloat((value >> 8) & 255) / 255,
                    blue: CGFloat(value & 255) / 255, alpha: 1)
        }
        return colors
    }

    private func oneCushionTracks(_ c: Capture, nodes: inout [SCNNode], draw: Bool,
                                  includePaths: Bool = false, spins: [Float]? = nil, palette: [UIColor]? = nil, stopAtRecollision: Bool = false, suppliedPredictions: [ShotPrediction]? = nil) throws -> [[String: Any]] {
        let levels = spins ?? SeparationAngleAtlasGeometry.spinYLevels()
        let colors = palette ?? oneCushionColors
        c.scene.clearResultNodes(nodes: &nodes)
        let predictions = try suppliedPredictions ?? seriesPredictions(c, speed: 3, spins: levels)
        var rows: [[String: Any]] = []
        for (index, prediction) in predictions.enumerated() {
            let recorder = try XCTUnwrap(prediction.recorder)
            let contact = try XCTUnwrap(SeparationAngleAtlasGeometry.firstBallBallEvent(in: prediction.events))
            let cushions = prediction.events.filter { event in
                guard event.time > contact.time else { return false }
                if case .ballCushion(let name) = event.kind { return name == ShotInput.cueBallName }
                return false
            }
            // Portrait left = -Z. Only the straight left long cushion permits a rebound.
            // The cushion event carries no rail ID; identify its actual recorded centre position.
            var firstRail = "none"
            var firstPosition: [Float] = []
            if let first = cushions.first {
                let p = try XCTUnwrap(recorder.stateAt(ballName: ShotInput.cueBallName, time: first.time)).position
                firstPosition = [p.x, p.y, p.z]
                let leftZ = -AngleSceneCalculator.innerWidth / 2 + AngleSceneCalculator.ballRadius
                if abs(p.z - leftZ) < 0.002 {
                    firstRail = "left-long"
                } else if p.x > 1.20 {
                    firstRail = "upper-short-or-jaw"
                } else {
                    firstRail = "other-cushion"
                }
            }
            let cutoff = firstRail == "left-long" ? cushions.dropFirst().first : cushions.first
            var end = cutoff?.time ?? prediction.duration
            var ending = cutoff == nil ? "stopped" : (firstRail == "left-long" ? "second-cushion" : "first-non-left-cushion")
            for event in prediction.events where event.time >= contact.time && event.time < end {
                if case .pocket(let name, _) = event.kind, name == ShotInput.cueBallName {
                    end = event.time
                    ending = "pocket"
                }
            }
            let recollision = prediction.events.first { event in
                guard event.time > contact.time + 0.00001 else { return false }
                if case .ballBall(let a, let b) = event.kind {
                    return a == ShotInput.cueBallName || b == ShotInput.cueBallName
                }
                return false
            }
            if stopAtRecollision, let event = recollision, event.time < end {
                end = event.time
                ending = "second-ball-contact"
            }
            if cutoff == nil && ending == "stopped" { XCTAssertTrue(prediction.hasFinalTableState) }
            let steps = max(1, Int(ceil((end - contact.time) * 240)))
            let path = try (0...steps).map { step in
                try XCTUnwrap(recorder.stateAt(ballName: ShotInput.cueBallName,
                    time: contact.time + (end - contact.time) * Float(step) / Float(steps))).position
            }
            if draw {
                c.scene.addDashedPolyline(path, color: colors[index],
                    radius: TrajectoryStyle.lineMain, placement: .table, into: &nodes)
            }
            var row: [String: Any] = ["spinIndex": index, "spinY": levels[index],
                "targetPocket": seriesPocket(prediction) ?? "none", "ending": ending,
                "firstCushionTime": cushions.first?.time ?? -1, "firstRail": firstRail,
                "firstCushionPosition": firstPosition, "endTime": end,
                "pointCount": path.count]
            if stopAtRecollision { row["secondBallContactTime"] = recollision?.time ?? -1 }
            if includePaths { row["path"] = path.map { [$0.x, $0.y, $0.z] } }
            rows.append(row)
        }
        XCTAssertEqual(rows.count, levels.count)
        return rows
    }

    func testDiagnoseContinuousSpinAim() throws {
        let dir = try output()
        let c = try makeCapture(targetXZ: SIMD2<Float>(-0.64, -0.20), pocketIndex: 0)
        _ = try setAngle(15, c, centerDistance: 0.60, requiresNegativeX: false)
        let cue = try XCTUnwrap(c.scene.cueBallNode).position
        var rows: [[String: Any]] = []
        for spin: Float in [-0.5, -0.07, -0.06, -0.05, -0.04, 0, 0.5] {
            let free = try XCTUnwrap(seriesPredictions(c, speed: 3, spins: [spin]).first)
            let solved = ShotPredictor.predict(ShotInput(cueBall: cue, targetBall: c.target,
                pocketIndex: 0, velocity: 3, spinX: 0, spinY: spin, surfaceY: c.scene.surfaceY))
            let appSolved = ShotPredictor.predictForPositionSolve(ShotInput(cueBall: cue, targetBall: c.target,
                pocketIndex: 0, velocity: 3, spinX: 0, spinY: spin, surfaceY: c.scene.surfaceY))
            XCTAssertTrue(appSolved.simObjectPotted, "App solver missed spin \(spin)")
            for (mode, pred) in [("geometric", free), ("solved", solved), ("app-solver", appSolved)] {
                var events: [[String: Any]] = []
                for event in pred.events {
                    var row: [String: Any] = ["time": event.time, "kind": String(describing: event.kind)]
                    for name in [ShotInput.cueBallName, ShotInput.targetBallName] {
                        if let state = pred.recorder?.stateAt(ballName: name, time: event.time) {
                            row[name] = [state.position.x, state.position.y, state.position.z]
                        }
                    }
                    events.append(row)
                }
                rows.append(["mode": mode, "spinY": spin, "events": events,
                    "aim": [pred.aimDirection.x, pred.aimDirection.y, pred.aimDirection.z],
                    "targetPocket": seriesPocket(pred) ?? "none", "simObjectPotted": pred.simObjectPotted])
            }
        }
        try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
            .write(to: dir.appendingPathComponent("aim-diagnostics.json"))
    }

    func testExportContinuousSpinPreview() async throws {
        let dir = try output()
        let c = try makeCapture(targetXZ: SIMD2<Float>(-0.64, -0.20), pocketIndex: 0, fitsCurrentRoom: true)
        let fixed = try setAngle(15, c, centerDistance: 0.60, requiresNegativeX: false)
        let cue = try XCTUnwrap(c.scene.cueBallNode).position
        let d = simd_normalize(SIMD3<Float>(c.ghost.x-cue.x, 0, c.ghost.z-cue.z))
        var direction = SCNVector3(d)
        var solvedContact = c.ghost
        var lineSurfaceY = c.scene.surfaceY + 0.001
        let solved = (0...900).map { step in
            ShotPredictor.predictForPositionSolve(ShotInput(cueBall: cue, targetBall: c.target,
                pocketIndex: 0, velocity: 3, spinX: 0, spinY: -0.5+Float(step)/900, surfaceY: c.scene.surfaceY))
        }
        XCTAssertTrue(solved.allSatisfy { $0.simObjectPotted }, "Every spin must pot selected pocket")
        print("SOLVER_SWEEP pots=\(solved.filter { $0.simObjectPotted }.count)/901")
        let insetScene = AngleTrainingScene(); insetScene.setupScene()
        insetScene.hideAllBalls()
        insetScene.showBall(key: PositionPlayBall.cueKey, scenePosition: cue)
        XCTAssertTrue(insetScene.applyTableStyle(.charcoal, showsSights: true))
        insetScene.applyClothColor(.green)
        XCTAssertTrue(try XCTUnwrap(insetScene.cueStick).applyStyle(.inkDragon))
        let camera = SCNNode(); camera.camera = SCNCamera()
        camera.camera!.usesOrthographicProjection = true
        camera.camera!.orthographicScale = 0.08
        camera.camera!.zNear = 0.001; camera.camera!.zFar = 100
        camera.camera!.wantsExposureAdaptation = false
        let right = SIMD3<Float>(-d.z, 0, d.x)
        let focus = SIMD3<Float>(cue) - d * 0.025
        camera.simdPosition = focus - right * 0.30
        camera.look(at: SCNVector3(focus), up: SCNVector3(0,1,0), localFront: SCNVector3(0,0,-1))
        let insetForward = camera.simdOrientation.act(SIMD3<Float>(0,0,-1))
        let insetScreenRight = camera.simdOrientation.act(SIMD3<Float>(1,0,0))
        XCTAssertEqual(insetForward.y, 0, accuracy: 0.00001)
        XCTAssertEqual(simd_dot(insetForward, d), 0, accuracy: 0.00001)
        XCTAssertGreaterThan(simd_dot(insetScreenRight, -d), 0.999)
        insetScene.rootNode.addChildNode(camera)
        let insetRenderer = SCNRenderer(device:nil,options:nil)
        insetRenderer.scene = insetScene; insetRenderer.pointOfView = camera
        insetRenderer.delegate = insetScene.contactOcclusion
        var elevation: Float = 0.05
        for spin in [-0.5, 0.0, 0.5] {
            let strike = CueStroke.strikePosition(cue: cue, aim: direction, spinX: 0, spinY: spin)
            guard case .angle(let needed) = CueStick.requiredElevation(cueBallPosition: strike, aimDirection: direction,
                obstacleCenters: [c.target]) else { XCTFail("Cue clearance blocked"); return }
            elevation = max(elevation, needed)
        }
        var nodes:[SCNNode]=[]
        var records:[[String:Any]]=[]
        let env=ProcessInfo.processInfo.environment
        let keys=(env["TEST_RUNNER_SEPARATION_KEYFRAMES"] ?? env["SEPARATION_KEYFRAMES"]) == "1"
        let frames = keys ? [0,285,456,510,735,960] : Array(0..<1020)
        let writer = keys ? nil : try VideoWriter(url:dir.appendingPathComponent("spin-15deg-preview.mp4"),size:size,fps:60,averageBitRate:is2K ? 32_000_000 : nil)
        var lastStep = -1
        var tracks:[[String:Any]]=[]
        for frame in frames {
            try autoreleasepool {
                let step=min(900,max(0,frame-60)), spin = -0.5+Double(step)/900
                let current=UIColor.white
                if step != lastStep {
                    let pred = solved[step]
                    direction = pred.aimDirection
                    let firstContact = try XCTUnwrap(SeparationAngleAtlasGeometry.firstBallBallEvent(in: pred.events))
                    solvedContact = try XCTUnwrap(pred.recorder?.stateAt(ballName: ShotInput.cueBallName, time: firstContact.time)).position
                    let ballContacts = pred.events.filter { if case .ballBall = $0.kind { return true }; return false }
                    XCTAssertEqual(ballContacts.count, 1, "Unexpected recollision at spin \(spin)")
                    tracks=try oneCushionTracks(c,nodes:&nodes,draw:true,spins:[Float(spin)],palette:[current],suppliedPredictions:[pred])
                    c.scene.strikeLineNode?.isHidden = true
                    c.scene.pocketLineNode?.isHidden = true
                    c.scene.addDashedPolyline([c.aim, c.target], color: .black,
                        radius: TrajectoryStyle.lineMain, placement: .table, into: &nodes)
                    let rail = AngleSceneCalculator.rayToInnerRail(from: cue, dir: direction, inset: 0)
                    let aimNode = c.scene.setFreeAimPreviewLine(AimCloseupSegment(
                        start: CGPoint(x: CGFloat(cue.x), y: CGFloat(cue.z)),
                        end: CGPoint(x: CGFloat(solvedContact.x), y: CGFloat(solvedContact.z))))
                    c.scene.rootNode.childNode(withName: "strikeContinuation", recursively: true)?.isHidden = true
                    c.scene.addDashedPolyline([solvedContact, rail], color: .white,
                        radius: TrajectoryStyle.lineMain, placement: .table, into: &nodes)
                    aimNode?.geometry?.materials = c.scene.strikeLineNode?.geometry?.materials ?? []
                    if let node = aimNode, let src = node.geometry?.sources(for: .vertex).first {
                        lineSurfaceY = src.data.withUnsafeBytes { bytes in
                            let o = src.dataOffset
                            let v = SCNVector3(bytes.loadUnaligned(fromByteOffset:o,as:Float.self),
                                bytes.loadUnaligned(fromByteOffset:o+4,as:Float.self),
                                bytes.loadUnaligned(fromByteOffset:o+8,as:Float.self))
                            return node.convertPosition(v,to:nil).y
                        }
                    }
                    c.scene.ghostBallNode?.position = solvedContact
                    let sd = SIMD3<Float>(direction), sr = SIMD3<Float>(-sd.z, 0, sd.x)
                    let sf = SIMD3<Float>(cue) - sd * 0.025
                    camera.simdPosition = sf - sr * 0.30
                    camera.look(at: SCNVector3(sf), up: SCNVector3(0,1,0), localFront: SCNVector3(0,0,-1))
                    lastStep=step
                }
                let strike=CueStroke.strikePosition(cue:cue,aim:direction,spinX:0,spinY:spin)
                c.scene.updateCueStick(cueBallPosition:strike,aimDirection:direction,pullBack:0.006,elevationOverride:elevation)
                insetScene.updateCueStick(cueBallPosition:strike,aimDirection:direction,pullBack:0.006,elevationOverride:elevation)
                // Translate the real tip mesh along its axis until first sphere contact.
                // Do not use the nominal cue-axis point as the curved tip's contact point.
                let stick = try XCTUnwrap(insetScene.cueStick)
                let forward = stick.rootNode.simdOrientation.act(SIMD3<Float>(0,0,-1))
                let center = SIMD3<Float>(cue)
                let radius = AngleSceneCalculator.ballRadius
                var advance = Float.infinity
                var closest = SIMD3<Float>.zero
                var candidates = 0
                stick.rootNode.enumerateChildNodes { node, _ in
                    guard let src = node.geometry?.sources(for:.vertex).first,
                          src.usesFloatComponents, src.bytesPerComponent == 4 else { return }
                    src.data.withUnsafeBytes { bytes in
                        for i in 0..<src.vectorCount {
                            let o=src.dataOffset+i*src.dataStride
                            let local=SCNVector3(bytes.loadUnaligned(fromByteOffset:o,as:Float.self),
                                bytes.loadUnaligned(fromByteOffset:o+4,as:Float.self),
                                bytes.loadUnaligned(fromByteOffset:o+8,as:Float.self))
                            let point=SIMD3<Float>(node.convertPosition(local,to:nil))
                            let q=point-center, longitudinal=simd_dot(q,forward)
                            let perpendicular=q-forward*longitudinal
                            let radial=simd_length_squared(perpendicular)
                            if radial < radius*radius {
                                let travel = -longitudinal-sqrt(radius*radius-radial)
                                if travel < advance { advance=travel; closest=point }
                                candidates += 1
                            }
                        }
                    }
                }
                XCTAssertGreaterThan(candidates,0);XCTAssertTrue(advance.isFinite)
                stick.rootNode.simdPosition += forward*advance
                let contact=closest+forward*advance
                let contactResidual=simd_length(contact-center)-radius
                XCTAssertEqual(contactResidual,0,accuracy:0.00001)
                XCTAssertEqual(c.scene.cueStick!.rootNode.eulerAngles.x,-elevation,accuracy:0.00001)
                XCTAssertEqual(insetScene.cueStick!.rootNode.eulerAngles.x,-elevation,accuracy:0.00001)
                SCNTransaction.flush()
                let time=Double(frame)/60
                let main=base(c,time:time,drawsAngleText:false)
                let insetPixels = 420 * size.width / 1080
                let inset=insetRenderer.snapshot(atTime:time,with:CGSize(width:insetPixels,height:insetPixels),antialiasingMode:.multisampling4X)
                let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
                let image=UIGraphicsImageRenderer(size:size,format:format).image { ctx in
                    UIColor.black.setFill();ctx.fill(CGRect(origin:.zero,size:size))
                    let cg=ctx.cgContext;cg.scaleBy(x:size.width/1080,y:size.width/1080)
                    main.draw(in:CGRect(x:0,y:0,width:1080,height:1920))
                    func text(_ value:String,_ x:CGFloat,_ y:CGFloat,_ font:CGFloat,_ color:UIColor = .white) {
                        (value as NSString).draw(at:CGPoint(x:x,y:y),withAttributes:[.font:UIFont.systemFont(ofSize:font,weight:.semibold),.foregroundColor:color])
                    }
                    cg.setFillColor(UIColor.black.withAlphaComponent(0.88).cgColor)
                    cg.addPath(UIBezierPath(roundedRect:CGRect(x:190,y:355,width:700,height:70),cornerRadius:18).cgPath);cg.fillPath()
                    text("杆速 3 m/s · 球心距 60 cm",269,371,34)
                    let disk=CGRect(x:230,y:450,width:180,height:180)
                    cg.setFillColor(UIColor.white.cgColor);cg.fillEllipse(in:disk)
                    cg.setStrokeColor(UIColor(red:0.82,green:0.1,blue:0.14,alpha:1).cgColor);cg.setLineWidth(1.2)
                    cg.move(to:CGPoint(x:320,y:450));cg.addLine(to:CGPoint(x:320,y:630))
                    cg.move(to:CGPoint(x:230,y:540));cg.addLine(to:CGPoint(x:410,y:540));cg.strokePath()
                    cg.setFillColor(UIColor.systemRed.cgColor)
                    cg.fillEllipse(in:CGRect(x:309,y:540-CGFloat(spin)*90-11,width:22,height:22))
                    let box=CGRect(x:655,y:435,width:210,height:210)
                    cg.saveGState();UIBezierPath(roundedRect:box,cornerRadius:14).addClip();inset.draw(in:box);cg.restoreGState()
                    cg.setStrokeColor(UIColor(white:0.6,alpha:1).cgColor);cg.setLineWidth(1)
                    cg.addPath(UIBezierPath(roundedRect:box,cornerRadius:14).cgPath);cg.strokePath()
                    @MainActor func screen(_ world:SCNVector3) -> CGPoint {
                        return projected(world,c)
                    }
                    @MainActor func onTable(_ p: SCNVector3) -> CGPoint { screen(SCNVector3(p.x,lineSurfaceY,p.z)) }
                    let cp=onTable(cue), gp=onTable(solvedContact), tp=onTable(c.target), pp=onTable(c.aim)
                    func leader(_ title:String,_ anchor:CGPoint,_ label:CGPoint,_ ink:UIColor) {
                        cg.setStrokeColor(ink.cgColor);cg.setLineWidth(1.2);cg.setLineCap(.butt)
                        cg.move(to:anchor);cg.addLine(to:CGPoint(x:label.x-5,y:label.y+10));cg.strokePath()
                        text(title,label.x,label.y,22,ink)
                    }
                    text("15°",screen(c.target).x-150,screen(c.target).y+25,32)
                    let am=CGPoint(x:(cp.x+gp.x)/2,y:(cp.y+gp.y)/2)
                    leader("瞄准线",am,CGPoint(x:am.x+35,y:am.y+38),.white)
                    let pm=CGPoint(x:tp.x+(pp.x-tp.x)*0.6,y:tp.y+(pp.y-tp.y)*0.6)
                    leader("进球线",pm,CGPoint(x:pm.x+58,y:pm.y+14),.black)
                    let noteStyle = NSMutableParagraphStyle(); noteStyle.alignment = .center
                    let noteShadow = NSShadow(); noteShadow.shadowColor = UIColor.black.withAlphaComponent(0.6)
                    noteShadow.shadowBlurRadius = 2; noteShadow.shadowOffset = CGSize(width:0,height:1)
                    ("注：仅保留母球吃一库轨迹" as NSString).draw(
                        in:CGRect(x:120,y:1710,width:840,height:40),
                        withAttributes:[.font:UIFont.systemFont(ofSize:28,weight:.medium),
                            .foregroundColor:UIColor.white,.paragraphStyle:noteStyle,.shadow:noteShadow])
                }
                if keys || [0,285,456,510,735,960].contains(frame) {
                    try XCTUnwrap(image.pngData()).write(to:dir.appendingPathComponent("frames/frame-\(frame).png"))
                }
                try writer?.append(XCTUnwrap(image.cgImage))
                var row=fixed;row["frame"]=frame;row["spinY"]=spin;row["cueElevation"]=elevation
                row["contactResidualM"]=contactResidual;row["contactPosition"]=[contact.x,contact.y,contact.z];row["insetCueAdvanceM"]=advance
                row["tracks"]=tracks;row["cueTipSpeedMps"]=3;row["version"]="spin-continuous-r10-native-2k-note"
                row["renderWidth"]=size.width;row["renderHeight"]=size.height
                let eye = c.scene.cameraNode.position
                row["cameraPosition"]=[eye.x,eye.y,eye.z]
                row["cameraVerticalFov"]=c.scene.cameraNode.camera!.fieldOfView
                row["tableOuterHalfLength"]=c.scene.cameraRig!.tableOuterHalfLength
                row["solvedAimDirection"]=[direction.x,direction.y,direction.z]
                row["aimCorrectionDegrees"]=Double(acos(min(1,max(-1,simd_dot(d,SIMD3<Float>(direction))))))*180 / .pi
                row["selectedPocketPotted"]=solved[step].simObjectPotted
                records.append(row)
            }
            if frame % 60 == 0 { print("SPIN_EXPORT \(frame)/1020") }
            await Task.yield()
        }
        if keys {
            var diagnostics:[[String:Any]]=[]
            for n in -15...5 {
                let spin=Float(n)/100
                let pred=try XCTUnwrap(seriesPredictions(c,speed:3,spins:[spin]).first)
                var events:[[String:Any]]=[]
                for e in pred.events {
                    let state=pred.recorder?.stateAt(ballName:ShotInput.cueBallName,time:e.time)
                    events.append(["time":e.time,"kind":String(describing:e.kind),
                        "cuePosition":state.map{[$0.position.x,$0.position.y,$0.position.z]} ?? []])
                }
                diagnostics.append(["spinY":spin,"events":events,"targetPocket":seriesPocket(pred) ?? "none"])
            }
            try JSONSerialization.data(withJSONObject:diagnostics,options:[.prettyPrinted,.sortedKeys])
                .write(to:dir.appendingPathComponent("kink-diagnostics.json"))
        }
        try await writer?.finish()
        try JSONSerialization.data(withJSONObject:records,options:[.sortedKeys]).write(to:dir.appendingPathComponent("geometry.json"))
    }

    func testOneCushionLeftTargetPreview() throws {
        let dir = try output()
        let c = try makeCapture(targetXZ: SIMD2<Float>(-0.64, -0.20), pocketIndex: 0)
        var geometry = try setAngle(30, c, centerDistance: 0.60, requiresNegativeX: false)
        var nodes: [SCNNode] = []
        let rows = try oneCushionTracks(c, nodes: &nodes, draw: true, includePaths: true)
        geometry["tracks"] = rows
        geometry["cueTipSpeedMps"] = 3
        geometry["version"] = "one-cushion-left-target-r3-no-markers"
        try JSONSerialization.data(withJSONObject: geometry, options: [.prettyPrinted, .sortedKeys])
            .write(to: dir.appendingPathComponent("geometry.json"))
        XCTAssertTrue(rows.allSatisfy { ($0["targetPocket"] as? String) == "pocket_0" })
        SCNTransaction.flush()
        _ = base(c, time: 0)
        _ = base(c, time: 0)
        let image = composeDirectAtlas(base(c, time: 0), angle: 30, trackColors: oneCushionColors)
        try XCTUnwrap(image.pngData()).write(to: dir.appendingPathComponent("preview.png"))
    }

    func testOneCushionMissDiagnostics() throws {
        let dir = try output()
        let c = try makeCapture(targetXZ: SIMD2<Float>(-0.64, -0.20), pocketIndex: 0)
        var rows: [[String: Any]] = []
        for angle in [9.5, 10.0, 15.0, 23.5, 24.0] {
            _ = try setAngle(angle, c, centerDistance: 0.60, requiresNegativeX: false)
            for (index, prediction) in try seriesPredictions(c, speed: 3).enumerated() where index == 4 {
                let recorder = try XCTUnwrap(prediction.recorder)
                let frames = recorder.framesByBallName[ShotInput.targetBallName] ?? []
                rows.append(["degrees": angle, "spinIndex": index,
                    "targetPocket": seriesPocket(prediction) ?? "none",
                    "termination": String(describing: prediction.termination),
                    "events": prediction.events.map { String(describing: $0) },
                    "targetFrames": frames.map { ["t": $0.time, "p": [$0.position.x, $0.position.y, $0.position.z], "v": [$0.velocity.x, $0.velocity.y, $0.velocity.z]] },
                    "aim": [c.aim.x, c.aim.y, c.aim.z]])
            }
        }
        try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys])
            .write(to: dir.appendingPathComponent("miss-diagnostics.json"))
    }

    private func oneCushionImage(_ c: Capture, angle: Double, time: Double,
                                 tracks: [[String: Any]], legendY: CGFloat? = nil, infoY: CGFloat? = nil, potLabelAbove: Bool = false) throws -> UIImage {
        let image = composeDirectAtlas(base(c, time: time, drawsAngleText: false), angle: angle,
            trackColors: oneCushionColors, legendY: legendY ?? (is3D ? nil : 170), infoY: infoY ?? (is3D ? nil : 60))
        let cueWorld = try XCTUnwrap(c.scene.cueBallNode).position
        let cue = projected(cueWorld, c), ghost = projected(c.ghost, c)
        let target = projected(c.target, c), pocket = projected(c.aim, c)
        func unit(_ p: CGPoint) -> CGPoint {
            let length = max(0.001, hypot(p.x, p.y))
            return CGPoint(x: p.x / length, y: p.y / length)
        }
        let pot = unit(CGPoint(x: pocket.x - target.x, y: pocket.y - target.y))
        let incoming = unit(CGPoint(x: ghost.x - cue.x, y: ghost.y - cue.y))
        let bisector = unit(CGPoint(x: pot.x + incoming.x, y: pot.y + incoming.y))
        let anglePoint: CGPoint
        if angle < 25 {
            anglePoint = CGPoint(x: target.x + pot.x * 105 - pot.y * 65,
                                 y: target.y + pot.y * 105 + pot.x * 65)
        } else {
            anglePoint = CGPoint(x: ghost.x + bisector.x * 200,
                                 y: ghost.y + bisector.y * 200)
        }
        let aimAnchor = CGPoint(x: (cue.x + ghost.x) / 2, y: (cue.y + ghost.y) / 2)
        let aimPoint = CGPoint(x: aimAnchor.x + incoming.y * 78,
                               y: aimAnchor.y - incoming.x * 78)
        let potAnchor = CGPoint(x: target.x + (pocket.x - target.x) * 0.55,
                                y: target.y + (pocket.y - target.y) * 0.55)
        let potPoint = potLabelAbove
            ? CGPoint(x: potAnchor.x, y: potAnchor.y - 80)
            : CGPoint(x: potAnchor.x + 105, y: potAnchor.y + 30)
        let labels: [(String, CGPoint, CGFloat, UIColor, CGPoint?)] = [
            (String(format: "%.0f°", angle), anglePoint, 32, .white, nil),
            ("瞄准线", aimPoint, 28, .white, aimAnchor),
            ("进球线", potPoint, 28, .black, potAnchor)
        ]
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            image.draw(in: CGRect(origin: .zero, size: size))
            context.cgContext.scaleBy(x: size.width / 1080, y: size.width / 1080)
            for (text, center, fontSize, color, anchor) in labels {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
                    .foregroundColor: color]
                let extent = (text as NSString).size(withAttributes: attributes)
                let rect = CGRect(x: center.x - extent.width / 2, y: center.y - extent.height / 2,
                                  width: extent.width, height: extent.height)
                XCTAssertGreaterThanOrEqual(rect.minX, 8)
                XCTAssertLessThanOrEqual(rect.maxX, 1072)
                XCTAssertFalse(rect.insetBy(dx: -16, dy: -16).contains(cue))
                XCTAssertFalse(rect.insetBy(dx: -16, dy: -16).contains(target))
                if let anchor {
                    let end = CGPoint(x: min(max(anchor.x, rect.minX - 6), rect.maxX + 6),
                                      y: min(max(anchor.y, rect.minY - 6), rect.maxY + 6))
                    context.cgContext.setStrokeColor(color.cgColor)
                    context.cgContext.setLineWidth(1.5)
                    context.cgContext.move(to: anchor)
                    context.cgContext.addLine(to: end)
                    context.cgContext.strokePath()
                }
                (text as NSString).draw(in: rect, withAttributes: attributes)
            }
        }
    }

    func testExportOneCushionVideo() async throws {
        let dir = try output()
        let c = try makeCapture(targetXZ: SIMD2<Float>(-0.64, -0.20), pocketIndex: 0)
        var nodes: [SCNNode] = []
        let env = ProcessInfo.processInfo.environment
        if (env["SEPARATION_KEYFRAMES"] ?? env["TEST_RUNNER_SEPARATION_KEYFRAMES"]) == "1" {
            var rows: [[String: Any]] = []
            for angle in [0.0, 16, 24, 25, 30, 60] {
                var row = try setAngle(angle, c, centerDistance: 0.60, requiresNegativeX: false)
                let tracks = try oneCushionTracks(c, nodes: &nodes, draw: true, includePaths: true)
                SCNTransaction.flush()
                _ = base(c, time: 0, drawsAngleText: false)
                let image = try oneCushionImage(c, angle: angle, time: 0, tracks: tracks)
                try XCTUnwrap(image.pngData()).write(to: dir.appendingPathComponent("frames/key-\(Int(angle)).png"))
                row["tracks"] = tracks; rows.append(row)
            }
            try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys])
                .write(to: dir.appendingPathComponent("keyframes.json"))
            return
        }
        var preflight: [[String: Any]] = []
        var misses: [[String: Any]] = []
        for step in 0...1080 {
            try autoreleasepool {
                let angle = Double(step) / 18
                var row = try setAngle(angle, c, centerDistance: 0.60, requiresNegativeX: false)
                let tracks = try oneCushionTracks(c, nodes: &nodes, draw: false)
                row["step"] = step
                row["tracks"] = tracks
                preflight.append(row)
                for track in tracks where (track["targetPocket"] as? String) != "pocket_0" {
                    misses.append(["step": step, "degrees": angle, "track": track])
                }
            }
            if step % 120 == 0 { print("ONE_CUSHION_PREFLIGHT \(step)/1080") }
            await Task.yield()
        }
        try JSONSerialization.data(withJSONObject: preflight, options: [.sortedKeys])
            .write(to: dir.appendingPathComponent("preflight.json"))
        try JSONSerialization.data(withJSONObject: misses, options: [.prettyPrinted, .sortedKeys])
            .write(to: dir.appendingPathComponent("target-misses.json"))
        // A fixed geometric aim does not guarantee pocketing for every spin.
        // Preserve real jaw rebounds in the geometry ledger; no outcome caption requested.
        let writer = try VideoWriter(url: dir.appendingPathComponent("one-cushion-\(is3D ? "3d" : "2d")-2k60-silent.mp4"), size: size, fps: fps)
        var records: [[String: Any]] = []
        var lastStep = -1
        var tracks: [[String: Any]] = []
        for frame in 0..<1170 {
            try autoreleasepool {
                let step = min(1080, max(0, frame - 45))
                let angle = Double(step) / 18
                var row = try setAngle(angle, c, centerDistance: 0.60, requiresNegativeX: false)
                if step != lastStep {
                    tracks = try oneCushionTracks(c, nodes: &nodes, draw: true)
                    lastStep = step
                }
                SCNTransaction.flush()
                if frame == 0 { _ = base(c, time: 0); _ = base(c, time: 0) }
                let image = try oneCushionImage(c, angle: angle, time: Double(frame) / 60, tracks: tracks)
                try writer.append(XCTUnwrap(image.cgImage))
                if [0, 225, 333, 477, 495, 585, 765, 945, 1125].contains(frame) {
                    try XCTUnwrap(image.pngData()).write(to: dir.appendingPathComponent("frames/frame-\(frame).png"))
                }
                row["frame"] = frame
                row["tracks"] = tracks
                row["cueTipSpeedMps"] = 3
                row["version"] = "one-cushion-video-r7-leader-labels"
                records.append(row)
            }
            if frame % 60 == 0 { print("ONE_CUSHION_EXPORT \(frame)/1170") }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        try await writer.finish()
        try JSONSerialization.data(withJSONObject: records, options: [.sortedKeys])
            .write(to: dir.appendingPathComponent("geometry.json"))
    }

    func testDistanceRangeDiagnostics() throws {
        let dir=try output()
        let c=try makeCapture(targetXZ:SIMD2<Float>(-0.78,0.46),pocketIndex:2)
        var rows:[[String:Any]]=[]
        for step in [182,183,184,204,205,206] {
            let d:Float=1.8+(0.5-1.8)*Float(step)/720
            _=try setAngle(15,c,centerDistance:d)
            for (index,p) in try seriesPredictions(c,speed:3).enumerated() {
                let frames=try XCTUnwrap(p.recorder).framesByBallName[ShotInput.targetBallName] ?? []
                let moving=frames.filter{abs($0.velocity.x)+abs($0.velocity.z)>0.001}
                let samples=frames.map { f -> [String:Any] in
                    ["t":f.time,"p":[f.position.x,f.position.y,f.position.z],"v":[f.velocity.x,f.velocity.y,f.velocity.z]]
                }
                let cueSamples=(p.recorder?.framesByBallName["cueBall"] ?? []).map { f -> [String:Any] in
                    ["t":f.time,"p":[f.position.x,f.position.y,f.position.z],"v":[f.velocity.x,f.velocity.y,f.velocity.z]]
                }
                rows.append(["step":step,"distance":d,"spinIndex":index,"pocket":seriesPocket(p) ?? "none",
                    "termination":String(describing:p.termination),"duration":p.duration,
                    "events":p.events.map{String(describing:$0)},"targetFrames":samples,"cueFrames":cueSamples,
                    "firstVelocity":moving.first.map{[$0.velocity.x,$0.velocity.y,$0.velocity.z]} ?? [],
                    "aim":[c.aim.x,c.aim.y,c.aim.z]])
            }
        }
        try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]).write(to:dir.appendingPathComponent("diagnostics.json"))
    }

    func testExportSeriesEpisode() async throws {
        let dir=try output();let env=ProcessInfo.processInfo.environment
        print("SERIES_CROSSHAIR value=\(env["SEPARATION_SPIN_CROSSHAIR"] ?? env["TEST_RUNNER_SEPARATION_SPIN_CROSSHAIR"] ?? "unset")")
        let kind=try XCTUnwrap(env["SEPARATION_EPISODE"] ?? env["TEST_RUNNER_SEPARATION_EPISODE"])
        XCTAssertTrue(["speed","distance"].contains(kind))
        let searchPath=try XCTUnwrap(env["SEPARATION_SEARCH"] ?? env["TEST_RUNNER_SEPARATION_SEARCH"])
        let search=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:searchPath))) as? [String:Any])
        let start=try XCTUnwrap(search["videoStartMps"] as? NSNumber).floatValue
        let end=try XCTUnwrap(search["videoEndMps"] as? NSNumber).floatValue
        let distanceEpisode=kind=="distance"
        let distanceStart = try XCTUnwrap(Float(env["SEPARATION_DISTANCE_START"] ?? env["TEST_RUNNER_SEPARATION_DISTANCE_START"] ?? "0.8"))
        let distanceEnd = try XCTUnwrap(Float(env["SEPARATION_DISTANCE_END"] ?? env["TEST_RUNNER_SEPARATION_DISTANCE_END"] ?? "1.6"))
        XCTAssertTrue(distanceStart.isFinite && distanceEnd.isFinite && distanceStart > 0 && distanceEnd > 0)
        let c=try makeCapture(targetXZ:distanceEpisode ? SIMD2<Float>(-0.78,0.46) : SIMD2<Float>(0,0.10),pocketIndex:distanceEpisode ? 2 : 5)
        if distanceEpisode && (env["SEPARATION_DISTANCE_PREFLIGHT"] ?? env["TEST_RUNNER_SEPARATION_DISTANCE_PREFLIGHT"]) == "1" {
            var preflight:[[String:Any]]=[];var previewNodes:[SCNNode]=[]
            for step in 0...720 {
                let d=distanceStart+(distanceEnd-distanceStart)*Float(step)/720
                var record=try setAngle(15,c,centerDistance:d)
                let predictions=try seriesPredictions(c,speed:3)
                let pockets=predictions.map{seriesPocket($0) ?? "none"}
                record["targetPockets"]=pockets
                record["pathPointCounts"]=try seriesPaths(predictions,c,nodes:&previewNodes)
                XCTAssertTrue(pockets.allSatisfy{$0=="pocket_2"},"Distance \(d): \(pockets)")
                preflight.append(record)
                if [0,360,720].contains(step) {
                    _=base(c,time:0)
                    try XCTUnwrap(seriesImage(c,speed:3,distance:d,distanceEpisode:true,time:0).pngData())
                        .write(to:dir.appendingPathComponent("frames/preflight-\(step).png"))
                }
            }
            try JSONSerialization.data(withJSONObject:preflight,options:[.prettyPrinted,.sortedKeys]).write(to:dir.appendingPathComponent("preflight.json"))
            return
        }
        let writer=try VideoWriter(url:dir.appendingPathComponent("\(kind)-2k-silent.mp4"),size:size,fps:fps)
        var rows:[[String:Any]]=[];var nodes:[SCNNode]=[];var previous:Float = -1
        var counts:[Int]=[];var pockets:[String]=[]
        for frame in 0..<780 {
            try autoreleasepool {
                let progress=Float(min(720,max(0,frame-30)))/720
                let speed:Float=distanceEpisode ? 3 : start+(end-start)*progress
                let distance:Float=distanceEpisode ? distanceStart+(distanceEnd-distanceStart)*progress : 0.6
                var record=try setAngle(15,c,centerDistance:distance)
                let value=distanceEpisode ? distance : speed
                if previous != value {
                    let predictions=try seriesPredictions(c,speed:speed)
                    counts=try seriesPaths(predictions,c,nodes:&nodes)
                    pockets=predictions.map{seriesPocket($0) ?? "none"}
                    if frame==0 && !distanceEpisode { XCTAssertTrue(pockets.allSatisfy{$0=="pocket_5"}) }
                    previous=value
                }
                if frame==0 { _=base(c,time:0) }
                let image=try seriesImage(c,speed:speed,distance:distance,distanceEpisode:distanceEpisode,time:Double(frame)/60)
                try writer.append(XCTUnwrap(image.cgImage))
                if [0,210,390,570,750].contains(frame) { try XCTUnwrap(image.pngData()).write(to:dir.appendingPathComponent("frames/final-\(frame).png")) }
                record["frame"]=frame;record["cueSpeedMps"]=speed;record["targetPockets"]=pockets;record["pathPointCounts"]=counts;rows.append(record)
            }
            if frame % 60==0 { print("SERIES_EXPORT \(kind) \(frame)/780") }
            try await Task.sleep(nanoseconds:1_000_000)
        }
        try await writer.finish()
        try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]).write(to:dir.appendingPathComponent("geometry.json"))
    }

    func testDirectContactAudit() throws {
        let dir=try output();let c=try makeCapture();var rows:[[String:Any]]=[]
        for angle in [75.0,80,85,89] {
            _ = try setAngle(angle,c);let cue=try XCTUnwrap(c.scene.cueBallNode).position
            let d=simd_normalize(SIMD2<Float>(c.ghost.x-cue.x,c.ghost.z-cue.z))
            for (i,spin) in SeparationAngleAtlasGeometry.spinYLevels().enumerated() {
                let pred=ShotPredictor.simulateFree(cueBall:cue,aimDir:SCNVector3(d.x,0,d.y),velocity:3,spinX:0,spinY:spin,surfaceY:c.scene.surfaceY,balls:[ObstacleBall(name:ShotInput.targetBallName,position:c.target)])
                let contact=SeparationAngleAtlasGeometry.firstBallBallEvent(in:pred.events)?.time ?? -1
                let rail=pred.events.first { if case .ballCushion(let name) = $0.kind {return name==ShotInput.cueBallName};return false }?.time ?? -1
                rows.append(["angle":angle,"spin":i,"contact":contact,"firstRail":rail])
            }
        }
        try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]).write(to:dir.appendingPathComponent("contact-audit.json"))
        _ = try setAngle(80,c);var nodes:[SCNNode]=[]
        _ = try drawTracks(c,nodes:&nodes,precise:true);_ = base(c,time:0)
        try XCTUnwrap(composeDirectAtlas(base(c,time:0),angle:80).pngData()).write(to:dir.appendingPathComponent("precise-80.png"))
    }

    func testDirectAtlasProbe() throws {
        let dir=try output();let c=try makeCapture();var nodes:[SCNNode]=[]
        var failures:[String]=[]
        for step in 0...720 {
            let angle=Double(step)/8
            _ = try setAngle(angle,c)
            do { _ = try drawTracks(c,nodes:&nodes,precise:true) }
            catch { failures.append("\(angle): \(error)") }
            if [0,240,480,640,720].contains(step) {
                _ = base(c,time:0)
                let im=composeDirectAtlas(base(c,time:0),angle:angle)
                try XCTUnwrap(im.pngData()).write(to:dir.appendingPathComponent("frames/direct-\(step).png"))
            }
        }
        try failures.joined(separator:"\n").write(to:dir.appendingPathComponent("probe-failures.txt"),atomically:true,encoding:.utf8)
        XCTAssertTrue(failures.isEmpty,"Incomplete angles: \(failures)")
    }

    /// Still-only camera selection. Cue-relative close cameras; distant trajectory ends may leave the frame.
    func testAimFollowingCameraOptions() async throws {
        let dir = try output()
        XCTAssertTrue(is3D)
        let c = try makeCapture()
        let camera = try XCTUnwrap(c.scene.cameraNode)
        let rawSize = CGSize(width: 1440, height: 2240)
        let finalSize = CGSize(width: 1440, height: 2560)
        let cropX: Float = 0
        let header: CGFloat = 320
        c.labelView.frame = CGRect(x: 0, y: 0, width: 360, height: 560)
        c.labelView.layoutIfNeeded()
        struct Slice {
            let angle: Double
            let cue: SCNVector3
            let direction: SIMD2<Float>
            let points: [SCNVector3]
            let counts: [Int]
        }
        var slices: [Slice] = []
        var nodes: [SCNNode] = []
        for degree in 0...60 {
            _ = try setAngle(Double(degree), c)
            let cue = try XCTUnwrap(c.scene.cueBallNode).position
            var points = [cue, c.target, c.ghost, c.aim]
            let counts = try drawTracks(c, nodes: &nodes, precise: true, colors: oneCushionColors) { points.append(contentsOf: $0) }
            slices.append(Slice(angle: Double(degree), cue: cue,
                direction: simd_normalize(SIMD2(c.ghost.x-cue.x, c.ghost.z-cue.z)), points: points, counts: counts))
            if degree % 15 == 0 { print("CAMERA_OPTIONS_PHYSICS \(degree)/60") }
            await Task.yield()
        }
        let candidates: [(String, String, Float, Float, Float)] = [
            ("D", "随瞄准横移", 1.10, 0.70, 62)
        ]
        func sideOffset(_ slice: Slice) -> Float {
            let t = Float(slice.angle / 60)
            return 0.30 * t * t * (3 - 2 * t)
        }
        func pose(_ slice: Slice, height: Float, back: Float) -> (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>, SIMD3<Float>) {
            let side = SIMD3(-slice.direction.y, Float(0), slice.direction.x) * sideOffset(slice)
            let eye = side + SIMD3(slice.cue.x-slice.direction.x*back, slice.cue.y+height, slice.cue.z-slice.direction.y*back)
            let focus = side + SIMD3(slice.cue.x + slice.direction.x * 0.30, slice.cue.y, slice.cue.z + slice.direction.y * 0.30)
            let forward = simd_normalize(focus-eye)
            let right = simd_normalize(simd_cross(forward, SIMD3<Float>(0,1,0)))
            let up = simd_cross(right, forward)
            return (eye, forward, right, up)
        }
        func pixel(_ point: SCNVector3, pose: (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>, SIMD3<Float>), fov: Float) -> SIMD3<Float> {
            let delta = SIMD3(point.x,point.y,point.z)-pose.0
            let depth = simd_dot(delta,pose.1)
            let focal = Float(rawSize.height)/(2*tan(fov * .pi/360))
            return SIMD3(Float(rawSize.width)/2 + simd_dot(delta,pose.2)/depth*focal-cropX,
                         Float(rawSize.height)/2 - simd_dot(delta,pose.3)/depth*focal, depth)
        }
        var variants: [[String: Any]] = []
        for (id, title, height, back, fov) in candidates {
            print("CAMERA_OPTION \(id) height=\(height) back=\(back) fov=\(fov)")
            var sampleRows: [[String: Any]] = []
            for slice in slices {
                let p = pose(slice,height:height,back:back)
                XCTAssertEqual(p.0.y-slice.cue.y,height,accuracy:0.00001)
                let horizontal = simd_normalize(SIMD2(p.1.x,p.1.z))
                XCTAssertEqual(simd_dot(horizontal,slice.direction),1,accuracy:0.00001)
                var lo = SIMD2<Float>(repeating: .greatestFiniteMagnitude)
                var hi = SIMD2<Float>(repeating: -.greatestFiniteMagnitude)
                for point in slice.points {
                    let q = pixel(point,pose:p,fov:fov)
                    lo=simd_min(lo,SIMD2(q.x,q.y));hi=simd_max(hi,SIMD2(q.x,q.y))
                }
                // The revised brief requires the cue/contact cluster, not first-cushion endpoints.
                for point in slice.points.prefix(3) {
                    let q = pixel(point,pose:p,fov:fov)
                    XCTAssertGreaterThan(q.z,0)
                    XCTAssertGreaterThan(q.x,48); XCTAssertLessThan(q.x,1392)
                    XCTAssertGreaterThan(q.y,48); XCTAssertLessThan(q.y,2192)
                }
                var row: [String:Any] = ["angle":slice.angle,"cue":[slice.cue.x,slice.cue.y,slice.cue.z],
                    "camera":[p.0.x,p.0.y,p.0.z],"sideOffsetM":sideOffset(slice),"cuePixelX":pixel(slice.cue,pose:p,fov:fov).x,"coverageBounds":[lo.x,lo.y,hi.x,hi.y],"pathPointCounts":slice.counts]
                if (0.0...60.0).contains(slice.angle) {
                    camera.simdTransform=c.transform
                    _=try setAngle(slice.angle,c)
                    _=try drawTracks(c,nodes:&nodes,precise:true,colors:oneCushionColors)
                    camera.camera!.fieldOfView=CGFloat(fov)
                    camera.position=SCNVector3(p.0.x,p.0.y,p.0.z)
                    camera.look(at:SCNVector3(p.0.x+p.1.x,p.0.y+p.1.y,p.0.z+p.1.z),up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
                    SCNTransaction.flush()
                    _=base(c,time:0,drawsAngleText:false,renderSize:rawSize)
                    let raw=base(c,time:0,drawsAngleText:false,renderSize:rawSize)
                    // Cross-check the fit calculation against the actual renderer viewport.
                    for point in [slice.cue,c.target,c.ghost,c.aim] {
                        let actual=c.renderer.projectPoint(point)
                        let expected=pixel(point,pose:p,fov:fov)
                        XCTAssertEqual(actual.x-cropX,expected.x,accuracy:0.2)
                        XCTAssertEqual(Float(rawSize.height)-actual.y,expected.y,accuracy:0.2)
                    }
                    let focal=Float(rawSize.height)/(2*tan(fov * .pi/360))
                    row["cueDiameterPixels"]=2*AngleSceneCalculator.ballRadius*focal/pixel(slice.cue,pose:p,fov:fov).z
                    let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
                    let layout=UIGraphicsImageRenderer(size:finalSize,format:format).image { context in
                        UIColor(white:0.045,alpha:1).setFill();context.fill(CGRect(origin:.zero,size:finalSize))
                        context.cgContext.saveGState()
                        context.cgContext.clip(to:CGRect(x:0,y:header,width:1440,height:2240))
                        raw.draw(at:CGPoint(x:-CGFloat(cropX),y:header))
                        context.cgContext.restoreGState()
                    }
                    let image=composeDirectAtlas(layout,angle:slice.angle,
                        parameters:String(format:"切角 %.0f°  ·  杆速 3 m/s  ·  球距 60 cm",slice.angle),
                        parameterBackground:false,trackColors:oneCushionColors,legendY:112,infoY:20,outputSize:finalSize)
                    let file="frames/\(id)-\(Int(slice.angle)).png"
                    try XCTUnwrap(image.pngData()).write(to:dir.appendingPathComponent(file))
                    row["file"]=file
                }
                sampleRows.append(row)
            }
            camera.simdTransform=c.transform
            variants.append(["id":id,"title":title,"heightAboveCueM":height,"backFromCueM":back,"verticalFOV":fov,"samples":sampleRows])
        }
        let manifest: [String:Any] = ["revision":"camera-slide-r11","stillsOnly":true,"size":[1440,2560],
            "rawRenderSize":[1440,2240],"cropLeft":0,"mainViewport":[0,320,1440,2240],
            "focus":"0.30m ahead of cue at ball-center height; distant track endpoints may be cropped","cameraSideM":"0 to 0.30, smoothstep(angle/60), camera and focus translate together","angleScanStep":1,"variants":variants]
        try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys]).write(to:dir.appendingPathComponent("manifest.json"))
    }

    /// Opt-in V003 camera study: orbit with the physical aiming direction.
    func testExportAimFollowingAtlasPreview() async throws {
        let dir = try output()
        XCTAssertTrue(is3D)
        let env = ProcessInfo.processInfo.environment
        let stillsOnly = (env["SEPARATION_FOLLOW_STILLS"] ?? env["TEST_RUNNER_SEPARATION_FOLLOW_STILLS"]) == "1"
        let c = try makeCapture()
        let camera = try XCTUnwrap(c.scene.cameraNode)
        let optics = try XCTUnwrap(camera.camera)
        var focus = SCNVector3(0, c.scene.surfaceY, 0)
        let eyeHeight: Float = 1.10
        let cameraBack: Float = 1.65
        optics.fieldOfView = 44
        let rawSize = CGSize(width: 1440, height: 1916)
        let outputSize = CGSize(width: 1440, height: 2280)
        c.labelView.frame = CGRect(x: 0, y: 0, width: 360, height: 479)
        c.labelView.layoutIfNeeded()
        let count = 540
        let samples = [0, 150, 270, 390, 539]
        let writer = stillsOnly ? nil : try VideoWriter(url: dir.appendingPathComponent("aim-follow-3d-2k60-silent.mp4"), size: outputSize, fps: fps)
        var nodes: [SCNNode] = []
        var records: [[String: Any]] = []
        var previousAngle: Double = -1
        var counts: [Int] = []
        for frame in 0..<count {
            if stillsOnly && !samples.contains(frame) { continue }
            try autoreleasepool {
                let time = Double(frame) / Double(fps)
                let progress = min(1, max(0, (time - 0.5) / 8))
                // Continuous absolute-time orbit, with zero end velocity/acceleration.
                let eased = progress * progress * progress * (10 - 15 * progress + 6 * progress * progress)
                let angle = 60 * eased
                camera.simdTransform = c.transform
                var record = try setAngle(angle, c)
                let cue = try XCTUnwrap(c.scene.cueBallNode).position
                let aim = simd_normalize(SIMD2<Float>(c.ghost.x - cue.x, c.ghost.z - cue.z))
                // simulator-video/references/aiming-cameras.md: fixed offset from cue, zero side.
                focus = SCNVector3(cue.x, c.scene.surfaceY, cue.z)
                camera.position = SCNVector3(cue.x - aim.x * cameraBack, c.scene.surfaceY + eyeHeight,
                                            cue.z - aim.y * cameraBack)
                camera.look(at: focus, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
                let forward = camera.simdOrientation.act(SIMD3<Float>(0, 0, -1))
                let horizontalForward = simd_normalize(SIMD2<Float>(forward.x, forward.z))
                XCTAssertEqual(simd_dot(horizontalForward, aim), 1, accuracy: 0.00001)
                XCTAssertEqual(camera.position.y - focus.y, eyeHeight, accuracy: 0.00001)
                if angle != previousAngle {
                    counts = try drawTracks(c, nodes: &nodes, precise: true, colors: oneCushionColors)
                    previousAngle = angle
                }
                SCNTransaction.flush()
                if frame == 0 { _ = base(c, time: 0, renderSize: rawSize) }
                let raw = base(c, time: time, drawsAngleText: false, renderSize: rawSize)
                let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
                let layout = UIGraphicsImageRenderer(size: outputSize, format: format).image { context in
                    UIColor(white: 0.045, alpha: 1).setFill()
                    context.fill(CGRect(origin: .zero, size: outputSize))
                    context.cgContext.saveGState()
                    context.cgContext.clip(to: CGRect(x: 0, y: 644, width: 1440, height: 1636))
                    raw.draw(at: CGPoint(x: 0, y: 644 - 280))
                    context.cgContext.restoreGState()
                }
                let image = composeDirectAtlas(layout, angle: angle,
                    parameters: String(format: "切角 %.1f°  ·  杆速 3 m/s  ·  球距 60 cm", angle),
                    parameterBackground: false, trackColors: oneCushionColors, legendY: 250, infoY: 140, outputSize: outputSize)
                try writer?.append(XCTUnwrap(image.cgImage))
                if samples.contains(frame) {
                    try XCTUnwrap(image.pngData()).write(to: dir.appendingPathComponent("frames/follow-\(frame).png"))
                }
                record["frame"] = frame; record["time"] = time
                record["camera"] = [camera.position.x, camera.position.y, camera.position.z]
                record["aimDirectionXZ"] = [aim.x, aim.y]
                record["focus"] = [focus.x, focus.y, focus.z]
                record["cameraBackFromCueM"] = cameraBack
                record["projectedOutput"] = ["cue": cue, "target": c.target, "ghost": c.ghost, "pocket": c.aim].mapValues { world in
                    let pixel = c.renderer.projectPoint(world)
                    return [Double(pixel.x), Double(rawSize.height) - Double(pixel.y) - 280 + 644]
                }
                record["pathPointCounts"] = counts
                record["revision"] = "follow-aim-r6"
                records.append(record)
            }
            if frame % 60 == 0 { print("FOLLOW_ATLAS \(frame)/\(count)") }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        try await writer?.finish()
        let manifest: [String: Any] = ["revision": "follow-aim-r6", "stillsOnly": stillsOnly,
            "size": [outputSize.width, outputSize.height], "rawRenderSize": [1440, 1916], "cropTop": 280, "mainViewport": [0, 644, 1440, 1636], "fps": fps, "duration": 9,
            "angleRange": [0, 60], "eyeHeightAboveClothM": eyeHeight, "cameraBackFromCueM": cameraBack, "focus": "cue projected onto cloth", "sideM": 0,
            "fieldOfView": 44, "appearance": ["charcoal", "green", "inkDragon"],
            "trajectoryEnd": "first cue cushion or simulation end", "frames": records]
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
            .write(to: dir.appendingPathComponent("manifest.json"))
    }

    /// User reference layout: retain the original aspect/camera and only relocate the two HUD rows.
    func testReferenceHUDStill() async throws {
        let dir = try output(), c = try makeCapture()
        _ = try setAngle(30,c)
        var nodes: [SCNNode] = []
        _ = try drawTracks(c,nodes:&nodes,precise:true,colors:oneCushionColors)
        _ = base(c,time:0)
        let image = try oneCushionImage(c,angle:30,time:0,tracks:[],legendY:450,infoY:345,potLabelAbove:true)
        try XCTUnwrap(image.pngData()).write(to:dir.appendingPathComponent("reference-hud-30.png"))
    }

    private func cameraFacingAtlasImage(_ c: Capture, angle: Double, rawSize: CGSize) throws -> UIImage {
        let cue = try XCTUnwrap(c.scene.cueBallNode).position
        let y = c.scene.surfaceY + 0.002
        var annotationNodes: [SCNNode] = []
        defer { annotationNodes.forEach { $0.removeFromParentNode() } }
        // This video ends the pot guide exactly at the ghost center; the shared
        // training scene deliberately draws a longer reverse extension.
        let originalPot = try XCTUnwrap(c.scene.pocketLineNode)
        originalPot.isHidden = true
        let pot = c.scene.addLine(from:c.aim,to:c.ghost,color:.black,
                                  radius:TrajectoryStyle.lineMain,placement:.table,layer:.aiming)
        let potMaterial = try XCTUnwrap(originalPot.geometry?.firstMaterial?.copy() as? SCNMaterial)
        let potLength = AngleSceneCalculator.horizontalDistance(c.aim,c.ghost)
        potMaterial.diffuse.contentsTransform = SCNMatrix4MakeScale(1,max(1,potLength/AngleTrainingScene.dashStripePeriod),1)
        pot.geometry?.materials = [potMaterial]
        annotationNodes.append(pot)
        var labels: [(String,SCNVector3,UIColor,CGFloat)] = []
        func label(_ text: String, x: Float, z: Float, color: UIColor, width: CGFloat) {
            // Retain the accepted 1080-design font sizes; project the world anchor each frame.
            labels.append((text,SCNVector3(x,y,z),color,text.hasSuffix("°") ? 32 : 28))
        }
        func leader(_ x: Float,_ z: Float,_ endX: Float,_ color: UIColor) {
            annotationNodes.append(c.scene.addLine(from:SCNVector3(x,y,z),to:SCNVector3(endX,y,z),color:color,radius:0.001,placement:.table,layer:.aiming))
        }
        let ax=(cue.x+c.ghost.x)/2, az=(cue.z+c.ghost.z)/2
        // Keep the accepted anchor until it approaches the cue ball; then slide sideways
        // around a 20cm world-space exclusion circle without changing text size/style.
        let aimX=ax+0.30
        var aimZ=az
        let dx=aimX-cue.x,dz=aimZ-cue.z
        let clearance: Float=0.20
        if dx*dx+dz*dz < clearance*clearance {
            aimZ=cue.z+sqrt(max(0,clearance*clearance-dx*dx))
        }
        label("瞄准线",x:aimX,z:aimZ,color:.white,width:0.32)
        let direction=simd_normalize(SIMD2<Float>(aimX-ax,aimZ-az))
        annotationNodes.append(c.scene.addLine(from:SCNVector3(ax,y,az),to:SCNVector3(aimX-direction.x*0.08,y,aimZ-direction.y*0.08),color:.white,radius:0.001,placement:.table,layer:.aiming))
        let px=c.target.x+(c.aim.x-c.target.x)*0.55,pz=c.target.z+(c.aim.z-c.target.z)*0.55
        label("进球线",x:px+0.30,z:pz,color:.black,width:0.32)
        leader(px,pz,px+0.22,.black)
        label(String(format:"%.0f°",angle),x:c.ghost.x-0.20,z:c.ghost.z+0.24,color:.white,width:0.22)
        c.scene.angleArcNode?.isHidden=true
        let u=simd_normalize(SIMD2<Float>(c.ghost.x-cue.x,c.ghost.z-cue.z))
        let n=simd_normalize(SIMD2<Float>(c.aim.x-c.target.x,c.aim.z-c.target.z))
        let start=atan2(u.y,u.x),delta=atan2(u.x*n.y-u.y*n.x,simd_dot(u,n))
        for k in 0..<30 {
            let a=start+delta*Float(k)/30,b=start+delta*Float(k+1)/30
            annotationNodes.append(c.scene.addLine(from:SCNVector3(c.ghost.x+0.14*cos(a),y,c.ghost.z+0.14*sin(a)),to:SCNVector3(c.ghost.x+0.14*cos(b),y,c.ghost.z+0.14*sin(b)),color:.white,radius:0.001,placement:.table,layer:.aiming))
        }
        SCNTransaction.flush()
        _=c.renderer.snapshot(atTime:0,with:rawSize,antialiasingMode:.multisampling4X)
        let raw=c.renderer.snapshot(atTime:0,with:rawSize,antialiasingMode:.multisampling4X)
        let image=composeDirectAtlas(raw,angle:angle,trackColors:oneCushionColors,legendY:450,infoY:345,outputSize:rawSize)
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        let result=UIGraphicsImageRenderer(size:rawSize,format:format).image { _ in
            image.draw(at:.zero)
            for (text,anchor,color,fontSize) in labels {
                let q=c.renderer.projectPoint(anchor)
                let attributes: [NSAttributedString.Key:Any] = [.font:UIFont.systemFont(ofSize:fontSize*rawSize.width/1080,weight:.semibold),.foregroundColor:color]
                let extent=(text as NSString).size(withAttributes:attributes)
                let rect=CGRect(x:CGFloat(q.x)-extent.width/2,y:rawSize.height-CGFloat(q.y)-extent.height/2,width:extent.width,height:extent.height)
                XCTAssertTrue(CGRect(origin:.zero,size:rawSize).contains(rect))
                (text as NSString).draw(in:rect,withAttributes:attributes)
            }
        }
        return result
    }

    func testCameraFacingLabelStill() async throws {
        let dir=try output(),c=try makeCapture()
        _=try setAngle(30,c)
        var nodes:[SCNNode]=[]
        _=try drawTracks(c,nodes:&nodes,precise:true,colors:oneCushionColors)
        let image=try cameraFacingAtlasImage(c,angle:30,rawSize:CGSize(width:2160,height:3840))
        try XCTUnwrap(image.pngData()).write(to:dir.appendingPathComponent("camera-facing-labels-30.png"))
    }

    func testExportAcceptedAtlas2K() async throws {
        let dir=try output(),c=try makeCapture()
        let renderSize=CGSize(width:1440,height:2560)
        let writer=try VideoWriter(url:dir.appendingPathComponent("separation-atlas-2k60-silent.mp4"),size:renderSize,fps:60,averageBitRate:28_000_000)
        var tracks:[SCNNode]=[],rows:[[String:Any]]=[]
        var previous:Double = -1,counts:[Int]=[]
        for frame in 0..<780 {
            try autoreleasepool {
                let angle=min(89,max(0,(Double(frame-30)*712/720).rounded()/8))
                var row=try setAngle(angle,c)
                if angle != previous {counts=try drawTracks(c,nodes:&tracks,precise:true,colors:oneCushionColors);previous=angle}
                let image=try cameraFacingAtlasImage(c,angle:angle,rawSize:renderSize)
                try writer.append(XCTUnwrap(image.cgImage))
                if [0,150,270,510,670,750].contains(frame) {try XCTUnwrap(image.pngData()).write(to:dir.appendingPathComponent("frames/final-\(frame).png"))}
                row["frame"]=frame;row["pathPointCounts"]=counts;rows.append(row)
            }
            if frame % 60 == 0 { print("ACCEPTED_2K \(frame)/780") }
            await Task.yield()
        }
        try await writer.finish()
        try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]).write(to:dir.appendingPathComponent("geometry.json"))
    }

    /// Original V003 camera/timeline with current production appearance and annotation palette.
    func testRemasterOriginalAtlas() async throws {
        let dir = try output()
        let c = try makeCapture()
        var nodes: [SCNNode] = []
        let env = ProcessInfo.processInfo.environment
        let stills = (env["SEPARATION_KEYFRAMES"] ?? env["TEST_RUNNER_SEPARATION_KEYFRAMES"]) == "1"
        let selectedFrames = [0,150,270,510,670,750]
        let writer: VideoWriter? = stills ? nil : try VideoWriter(url:dir.appendingPathComponent("atlas-original-4k60-silent.mp4"),size:size,fps:60,averageBitRate:55_000_000)
        var records: [[String: Any]] = []
        var previous: Double = -1
        var counts: [Int] = []
        for frame in 0..<780 {
            if stills && !selectedFrames.contains(frame) { continue }
            try autoreleasepool {
                let angle = min(89,max(0,(Double(frame-30)*712/720).rounded()/8))
                var record = try setAngle(angle,c)
                if previous != angle { counts = try drawTracks(c,nodes:&nodes,precise:true,colors:oneCushionColors); previous=angle }
                if frame == 0 { _ = base(c,time:0) }
                let image = try oneCushionImage(c,angle:angle,time:Double(frame)/60,tracks:[],legendY:240,infoY:140,potLabelAbove:true)
                if let writer { try writer.append(XCTUnwrap(image.cgImage)) }
                if selectedFrames.contains(frame) { try XCTUnwrap(image.pngData()).write(to:dir.appendingPathComponent("frames/final-\(frame).png")) }
                record["frame"]=frame;record["pathPointCounts"]=counts
                let camera = try XCTUnwrap(c.scene.cameraNode)
                record["camera"]=[camera.position.x,camera.position.y,camera.position.z]
                record["fov"]=camera.camera!.fieldOfView
                records.append(record)
            }
            if frame % 60 == 0 { print("ORIGINAL_REMASTER \(frame)/780") }
            await Task.yield()
        }
        if let writer { try await writer.finish() }
        try JSONSerialization.data(withJSONObject:records,options:[.prettyPrinted,.sortedKeys]).write(to:dir.appendingPathComponent("geometry.json"))
    }

    func testExportDirectAtlas() async throws {
        let dir=try output();let c=try makeCapture();var nodes:[SCNNode]=[]
        let writer=try VideoWriter(url:dir.appendingPathComponent("atlas-0-89-2k-silent.mp4"),size:size,fps:fps)
        var records:[[String:Any]]=[];var previous:Double = -1;var counts:[Int]=[]
        for frame in 0..<780 {
            try autoreleasepool {
                let angle=min(89,max(0,(Double(frame-30)*712/720).rounded()/8))
                var record=try setAngle(angle,c)
                if previous != angle { counts=try drawTracks(c,nodes:&nodes,precise:true);previous=angle }
                if frame==0 {_ = base(c,time:0)}
                let image=composeDirectAtlas(base(c,time:Double(frame)/60),angle:angle)
                try writer.append(XCTUnwrap(image.cgImage))
                if [0,270,510,670,750].contains(frame) {
                    try XCTUnwrap(image.pngData()).write(to:dir.appendingPathComponent("frames/final-\(frame).png"))
                }
                record["frame"]=frame;record["pathPointCounts"]=counts;records.append(record)
            }
            if frame % 60 == 0 { print("DIRECT_ATLAS \(frame)/780") }
            try await Task.sleep(nanoseconds:1_000_000)
        }
        try await writer.finish()
        try JSONSerialization.data(withJSONObject:records,options:[.prettyPrinted,.sortedKeys]).write(to:dir.appendingPathComponent("geometry.json"))
    }

    func testExportSimulation() async throws {
        let dir = try output(); let c = try makeCapture()
        var nodes:[SCNNode] = []; var records:[[String:Any]] = []
        let writer = try VideoWriter(url:dir.appendingPathComponent("simulation-source-silent.mp4"),size:size,fps:fps)
        var previousAngle:Double = -1; var counts:[Int] = []
        for frame in 0..<900 {
            try autoreleasepool {
                let t = Double(frame)/60
                let angle = max(0,min(60,(t-0.5)*60/14))
                var record = try setAngle(angle,c)
                if angle != previousAngle {
                    counts = try drawTracks(c,nodes:&nodes)
                    previousAngle = angle
                }
                if frame == 0 { _ = base(c,time:t) }
                try writer.append(XCTUnwrap(compose(base(c,time:t),angle:angle,bridgeTime:nil,simulation:true).cgImage))
                record["frame"] = frame; record["pathPointCounts"] = counts; records.append(record)
            }
            if frame % 30 == 0 { print("SEPARATION_INTRO simulation \(frame)/900") }
            try await Task.sleep(nanoseconds:1_000_000)
        }
        try await writer.finish()
        try JSONSerialization.data(withJSONObject:records,options:[.prettyPrinted,.sortedKeys]).write(to:dir.appendingPathComponent("simulation-source-geometry.json"))
    }

}

/// Opt-in native 2D still for the middle-pocket parallel-contact aiming lesson.
@MainActor
final class ParallelContactAimingCaptureTests: XCTestCase {
    func testMiddlePocket2DPreview() throws {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["PARALLEL_CAPTURE_DIR"] ?? env["TEST_RUNNER_PARALLEL_CAPTURE_DIR"] else {
            throw XCTSkip("Set TEST_RUNNER_PARALLEL_CAPTURE_DIR to export the preview")
        }
        let output = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let vm = AngleDynamicViewModel()
        vm.setupScene()
        let scene = vm.scene
        scene.applyTableStyle(.standard, showsSights: true)
        scene.applyClothColor(.green)
        let radius = AngleSceneCalculator.ballRadius
        let y = scene.surfaceY + radius
        let target = SCNVector3(0, y, 0.23)
        try XCTUnwrap(vm.targetNode).position = target
        vm.selectPocket(at: 5)
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: 5, surfaceY: scene.surfaceY)
        let n = simd_normalize(SIMD2<Float>(aim.x-target.x, aim.z-target.z))
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: aim, ballRadius: radius)
        let angle = Float(35 * Double.pi / 180)
        let side = SIMD2<Float>(-n.y, n.x)
        let direction = n*cos(angle) + side*sin(angle)
        let cue = SCNVector3(ghost.x-0.34*direction.x, y, ghost.z-0.34*direction.y)
        try XCTUnwrap(scene.cueBallNode).position = cue
        vm.updateCalculations()
        scene.setCameraMode(.topDown2D, animated: false)
        scene.updateVisualization(cueBall: cue, targetBall: target, pocket: aim,
                                  showAngleAnnotations: false, showOverlapMarkers: true,
                                  showLineLabels: false, extendStrikeLineToRail: false)
        scene.updateCueStick(cueBallPosition: cue, aimDirection: SCNVector3(ghost.x-cue.x, 0, ghost.z-cue.z))
        let a = AngleSceneCalculator.contactPointPosition(targetBall: target, pocket: aim)
        let b = SCNVector3(cue.x+radius*n.x, y, cue.z+radius*n.y)
        let ab = SIMD2<Float>(a.x-b.x, a.z-b.z)
        let cg = SIMD2<Float>(ghost.x-cue.x, ghost.z-cue.z)
        XCTAssertEqual(ab.x, cg.x, accuracy: 0.000001)
        XCTAssertEqual(ab.y, cg.y, accuracy: 0.000001)
        XCTAssertEqual(AngleSceneCalculator.horizontalDistance(ghost, target), 2*radius, accuracy: 0.000001)
        XCTAssertEqual(vm.cutAngleDegrees, 35, accuracy: 0.01)
        let cameraNode = try XCTUnwrap(scene.cameraNode)
        let camera = try XCTUnwrap(cameraNode.camera)
        camera.usesOrthographicProjection = true
        camera.projectionDirection = .vertical
        camera.orthographicScale = 0.57
        camera.zNear = 0.01
        camera.zFar = 100
        camera.wantsExposureAdaptation = false
        let center = SCNVector3(0, scene.surfaceY, 0.20)
        cameraNode.position = SCNVector3(center.x, center.y+3, center.z)
        cameraNode.look(at: center, up: SCNVector3(0,0,1), localFront: SCNVector3(0,0,-1))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene
        renderer.pointOfView = cameraNode
        renderer.delegate = scene.contactOcclusion
        renderer.autoenablesDefaultLighting = false
        SCNTransaction.flush()
        let size = CGSize(width: 1440, height: 2560)
        _ = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
        let shot = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
        func project(_ p: SCNVector3) -> CGPoint {
            let q = renderer.projectPoint(p)
            return CGPoint(x: CGFloat(q.x), y: size.height-CGFloat(q.y))
        }
        let cp = project(cue), ap = project(a), bp = project(b), gp = project(ghost), tp = project(target)
        let screenAB = CGPoint(x: ap.x-bp.x, y: ap.y-bp.y)
        let screenCG = CGPoint(x: gp.x-cp.x, y: gp.y-cp.y)
        XCTAssertEqual(screenAB.x, screenCG.x, accuracy: 0.1)
        XCTAssertEqual(screenAB.y, screenCG.y, accuracy: 0.1)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let result = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            shot.draw(in: CGRect(origin: .zero, size: size))
            let g = ctx.cgContext
            func line(_ p: CGPoint, _ q: CGPoint, _ color: UIColor, dashed: Bool = false) {
                g.saveGState()
                g.setStrokeColor(color.cgColor)
                g.setLineWidth(4)
                g.setLineDash(phase: 0, lengths: dashed ? [15,12] : [])
                g.move(to: p); g.addLine(to: q); g.strokePath()
                g.restoreGState()
            }
            func label(_ text: String, _ point: CGPoint, color: UIColor = .white, fontSize: CGFloat = 32) {
                let shadow = NSShadow(); shadow.shadowColor = UIColor.black; shadow.shadowBlurRadius = 5
                (text as NSString).draw(at: point, withAttributes: [.font: UIFont.systemFont(ofSize: fontSize, weight: .semibold), .foregroundColor: color, .shadow: shadow])
            }
            let yellow = UIColor.systemYellow, cyan = UIColor.cyan
            line(project(SCNVector3(cue.x-0.09*n.x,y,cue.z-0.09*n.y)),
                 project(SCNVector3(cue.x+0.44*n.x,y,cue.z+0.44*n.y)), yellow, dashed: true)
            line(bp, ap, cyan)
            // The constructed line coincides with the original production aiming line.
            // Keep the production white line; avoid drawing a duplicate over it.
            for p in [ap,bp] {
                UIColor.systemRed.setFill()
                let dot = UIBezierPath(ovalIn: CGRect(x:p.x-9,y:p.y-9,width:18,height:18)); dot.fill()
                UIColor.white.setStroke(); dot.lineWidth=2; dot.stroke()
            }
            label("平行线切球瞄准法", CGPoint(x:65,y:70), fontSize:32)
            label("中袋 · 切角 35°", CGPoint(x:65,y:120), fontSize:26)
            label("进球线", CGPoint(x:tp.x+36,y:tp.y-190))
            label("目标球接触点", CGPoint(x:ap.x+80,y:ap.y-20))
            line(ap,CGPoint(x:ap.x+66,y:ap.y),.white)
            label("瞄准点", CGPoint(x:gp.x+100,y:gp.y-10))
            line(gp,CGPoint(x:gp.x+86,y:gp.y+10),.white)
            label("假想球", CGPoint(x:gp.x+100,y:gp.y+70))
            label("母球接触点", CGPoint(x:bp.x+80,y:bp.y-15))
            line(bp,CGPoint(x:bp.x+65,y:bp.y),.white)
            label("平行虚线", CGPoint(x:cp.x-185,y:cp.y-570),color:yellow)
            let mid = CGPoint(x:(ap.x+bp.x)/2,y:(ap.y+bp.y)/2)
            label("接触点连线", CGPoint(x:mid.x+75,y:mid.y-20),color:cyan)
            line(mid,CGPoint(x:mid.x+60,y:mid.y),cyan)
            let aimMid=CGPoint(x:cp.x*0.7+gp.x*0.3,y:cp.y*0.7+gp.y*0.3)
            label("瞄准线", CGPoint(x:aimMid.x+90,y:aimMid.y-20))
            line(aimMid,CGPoint(x:aimMid.x+75,y:aimMid.y),.white)
            label("接触点连线 ∥ 瞄准线", CGPoint(x:460,y:2360),fontSize:32)
        }
        try XCTUnwrap(result.pngData()).write(to: output.appendingPathComponent("parallel-middle-2d.png"))
        let points:[String:SCNVector3] = ["cue":cue,"target":target,"ghost":ghost,"aim":aim,"targetContact":a,"cueContact":b]
        let records = points.mapValues { ["world":[$0.x,$0.y,$0.z],"pixel":[Float(project($0).x),Float(project($0).y)]] }
        try JSONSerialization.data(withJSONObject: records, options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("geometry.json"))
        print("PARALLEL_CAPTURE \(output.path)/parallel-middle-2d.png")
    }
}

/// V013 reuses V009 r9 labels/metrics, with left framing and a fixed overhead overview.
extension AngleAimingVideoCaptureTests {
    private func parallelSegment(_ a: SCNVector3, _ b: SCNVector3, color: UIColor, root: SCNNode) {
        let d=SIMD3<Float>(b.x-a.x,b.y-a.y,b.z-a.z),length=simd_length(d)
        guard length>0.000001 else{return}
        let geo=SCNCylinder(radius:0.0008,height:CGFloat(length));geo.radialSegmentCount=8
        let mat=SCNMaterial();mat.lightingModel = .constant;mat.diffuse.contents=color
        geo.materials=[mat]
        let node=SCNNode(geometry:geo);node.castsShadow=false
        node.position=SCNVector3((a.x+b.x)/2,(a.y+b.y)/2,(a.z+b.z)/2)
        node.simdOrientation=simd_quatf(from:SIMD3<Float>(0,1,0),to:d/length);root.addChildNode(node)
    }
    private func parallelExtraLabel(_ text:String,anchor:SCNVector3,offset:SIMD2<Float>,color:UIColor,
                                    capture:Capture,root:SCNNode) throws {
        let geo=SCNText(string:text,extrusionDepth:2.5);geo.font=UIFont.systemFont(ofSize:24,weight:.semibold)
        geo.flatness=0.12;geo.chamferRadius=0.18
        let mat=SCNMaterial();mat.lightingModel = .constant;mat.diffuse.contents=color
        let edge=SCNMaterial();edge.diffuse.contents=UIColor(white:0.15,alpha:1)
        geo.materials=[mat,edge,edge,mat,edge]
        let node=SCNNode(geometry:geo);node.castsShadow=false
        let (lo,hi)=geo.boundingBox
        node.pivot=SCNMatrix4MakeTranslation((lo.x+hi.x)/2,(lo.y+hi.y)/2,0)
        let p=capture.renderer.projectPoint(anchor)
        node.position=capture.renderer.unprojectPoint(SCNVector3(p.x+offset.x,p.y+offset.y,p.z))
        let camera=capture.vm.scene.cameraNode!
        let local=camera.convertPosition(anchor,from:nil)
        let worldPixel=2 * (-local.z)*tan(Float(camera.camera!.fieldOfView)*Float.pi/360)/Float(size.height)
        let scale=worldPixel*23/max(1,hi.y-lo.y)
        node.scale=SCNVector3(scale,scale,scale)
        node.simdOrientation=camera.simdOrientation*simd_quatf(angle:-0.16,axis:SIMD3<Float>(0,1,0))
        root.addChildNode(node)
        let end=capture.renderer.unprojectPoint(SCNVector3(p.x+offset.x-(offset.x>0 ? 68 : -68),p.y+offset.y,p.z))
        parallelSegment(anchor,end,color:color,root:root)
        let center=capture.renderer.projectPoint(node.position)
        XCTAssertGreaterThan(center.x,85);XCTAssertLessThan(center.x,Float(size.width)-85)
        XCTAssertGreaterThan(center.y,45);XCTAssertLessThan(center.y,Float(size.height)-45)
    }
    private func parallelCutPlane(_ capture:Capture) throws -> SCNNode {
        let root=SCNNode(),r=AngleSceneCalculator.ballRadius
        let cue=try XCTUnwrap(capture.vm.scene.cueBallNode).position
        let a=AngleSceneCalculator.contactPointPosition(targetBall:capture.target,pocket:capture.aim)
        let n=simd_normalize(SIMD3<Float>(capture.aim.x-capture.target.x,0,capture.aim.z-capture.target.z))
        let b=SIMD3<Float>(cue.x,cue.y,cue.z)+r*n
        let av=SIMD3<Float>(a.x,a.y,a.z),d=simd_normalize(av-b),up=SIMD3<Float>(0,1,0)
        let normal=simd_normalize(simd_cross(d,up))
        let plane=SCNPlane(width:CGFloat(simd_length(av-b)+0.12),height:0.095)
        let material=SCNMaterial();material.lightingModel = .constant
        material.diffuse.contents=UIColor.cyan.withAlphaComponent(0.24);material.isDoubleSided=true
        material.writesToDepthBuffer=false;plane.materials=[material]
        let node=SCNNode(geometry:plane);node.castsShadow=false
        node.simdPosition=(av+b)/2;node.simdPosition.y=capture.vm.scene.surfaceY+0.0475
        node.simdOrientation=simd_quatf(simd_float3x3(columns:(d,up,normal)));root.addChildNode(node)
        for center in [SIMD3<Float>(cue.x,cue.y,cue.z),SIMD3<Float>(capture.target.x,capture.target.y,capture.target.z)] {
            let distance=simd_dot(center-av,normal)
            XCTAssertLessThan(abs(distance),r+0.000001)
            let foot=center-distance*normal,rho=sqrt(max(0,r*r-distance*distance))
            for index in 0..<64 {
                let t=Float(index)*2*Float.pi/64,q=Float(index+1)*2*Float.pi/64
                let p0=foot+rho*(cos(t)*d+sin(t)*up),p1=foot+rho*(cos(q)*d+sin(q)*up)
                parallelSegment(SCNVector3(p0.x,p0.y,p0.z),SCNVector3(p1.x,p1.y,p1.z),color:.cyan,root:root)
                root.childNodes.last?.geometry?.materials.forEach{$0.readsFromDepthBuffer=false;$0.writesToDepthBuffer=false}
                root.childNodes.last?.renderingOrder=210
            }
        }
        return root
    }
    private func parallelDiagramInset(_ capture:Capture,renderer:SCNRenderer,camera:SCNNode,base:UIImage,time:Double) throws -> (UIImage,[String:Any]) {
        let env=ProcessInfo.processInfo.environment
        let minimal=(env["PARALLEL_MINIMAL_PREVIEW"] ?? env["TEST_RUNNER_PARALLEL_MINIMAL_PREVIEW"]) == "1"
        let wide=size.width>1080
        let s=capture.vm.scene,box=wide ? CGRect(x:760,y:40,width:640,height:640):CGRect(x:520,y:40,width:520,height:560)
        let raster=CGSize(width:box.width*2,height:box.height*2)
        let cueNode=try XCTUnwrap(s.cueBallNode),targetNode=try XCTUnwrap(capture.vm.targetNode)
        let originalCue=cueNode.position,originalTarget=targetNode.position
        let r=AngleSceneCalculator.ballRadius,y=originalCue.y
        let target=SCNVector3(capture.aim.x,y,capture.aim.z+0.20)
        let ghost=AngleSceneCalculator.ghostBallPosition(targetBall:target,pocket:capture.aim,ballRadius:r)
        let angle=Float(capture.vm.cutAngleDegrees * Double.pi/180)
        let length = -2*r*cos(angle)+sqrt(0.20*0.20-pow(2*r*sin(angle),2))
        let cue=SCNVector3(ghost.x-length*sin(angle),y,ghost.z+length*cos(angle))
        cueNode.position=cue;targetNode.position=target
        defer{cueNode.position=originalCue;targetNode.position=originalTarget;SCNTransaction.flush()}
        XCTAssertEqual(AngleSceneCalculator.horizontalDistance(cue,target),0.20,accuracy:0.000001)
        camera.position=SCNVector3(-0.055,s.surfaceY+3,capture.aim.z+0.21)
        camera.look(at:SCNVector3(-0.055,s.surfaceY,capture.aim.z+0.21),up:SCNVector3(0,0,-1),localFront:SCNVector3(0,0,-1))
        camera.camera!.usesOrthographicProjection=true;camera.camera!.projectionDirection = .vertical
        camera.camera!.orthographicScale=0.30;camera.camera!.zNear=0.01;camera.camera!.zFar=100
        let nodes=[s.cueStick?.rootNode,s.ghostBallNode,s.perpLineNode,s.strikeLineNode,s.angleArcNode,s.contactDotNode,
                   s.rootNode.childNode(withName:"videoSpatialLabels",recursively:false),
                   s.rootNode.childNode(withName:"parallelExtras",recursively:false),
                   s.rootNode.childNode(withName:"parallelShortPotLine",recursively:false)].compactMap{$0}
        let hidden=nodes.map{$0.isHidden};nodes.forEach{$0.isHidden=true}
        defer{for (node,value) in zip(nodes,hidden){node.isHidden=value};SCNTransaction.flush()}
        SCNTransaction.flush()
        let shot=renderer.snapshot(atTime:time,with:raster,antialiasingMode:.multisampling4X)
        func project(_ p:SCNVector3)->CGPoint{let v=renderer.projectPoint(p);return CGPoint(x:CGFloat(v.x),y:raster.height-CGFloat(v.y))}
        let n=simd_normalize(SIMD2<Float>(capture.aim.x-target.x,capture.aim.z-target.z))
        let a=AngleSceneCalculator.contactPointPosition(targetBall:target,pocket:capture.aim)
        let b=SCNVector3(cue.x+AngleSceneCalculator.ballRadius*n.x,cue.y,cue.z+AngleSceneCalculator.ballRadius*n.y)
        let ap=project(a),bp=project(b),cp=project(cue),gp=project(ghost),tp=project(target),pp=project(capture.aim)
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        let detail=UIGraphicsImageRenderer(size:raster,format:format).image{ctx in
            UIColor.black.setFill();ctx.fill(CGRect(origin:.zero,size:raster));shot.draw(at:.zero)
            let g=ctx.cgContext
            func line(_ p:CGPoint,_ q:CGPoint,_ color:UIColor,dashed:Bool=false){g.setStrokeColor(color.cgColor);g.setLineWidth(4);g.setLineDash(phase:0,lengths:dashed ? [12,9]:[]);g.move(to:p);g.addLine(to:q);g.strokePath()}
            line(tp,pp,.black,dashed:true)
            let guideTop=project(SCNVector3(cue.x,y,minimal ? -AngleSceneCalculator.innerWidth/2:cue.z-0.16)),guideBottom=project(SCNVector3(cue.x,y,cue.z+0.04))
            line(guideTop,guideBottom,.red,dashed:true)
            line(cp,gp,.white)
            line(bp,ap,.cyan)
            var leaders:[(CGPoint,CGPoint)]=[]
            func leader(_ points:[CGPoint],_ color:UIColor){
                for (p,q) in zip(points,points.dropFirst()){line(p,q,color);leaders.append((p,q))}
            }
            func text(_ string:String,_ pos:CGPoint,_ color:UIColor,_ fontSize:CGFloat=34){
                let attrs:[NSAttributedString.Key:Any]=[.font:UIFont.systemFont(ofSize:fontSize,weight:.semibold),.foregroundColor:color]
                let width=(string as NSString).size(withAttributes:attrs).width
                (string as NSString).draw(at:pos,withAttributes:attrs)
                XCTAssertGreaterThan(pos.x,10);XCTAssertLessThan(pos.x+width,raster.width-10)
            }
            for point in [ap,bp]{UIColor.red.setFill();UIBezierPath(ovalIn:CGRect(x:point.x-6,y:point.y-6,width:12,height:12)).fill()}
            text("目标球接触点",CGPoint(x:ap.x+80,y:ap.y-50),.red)
            leader([ap,CGPoint(x:ap.x+65,y:ap.y-30)],.red)
            text("母球接触点",CGPoint(x:bp.x-280,y:bp.y+30),.red)
            leader([bp,CGPoint(x:bp.x-95,y:bp.y+50)],.red)
            let mid=CGPoint(x:(ap.x+bp.x)/2,y:(ap.y+bp.y)/2)
            if minimal {
                let pos=CGPoint(x:guideTop.x+15,y:ap.y-100)
                text("接触点连线",pos,.cyan,30)
                leader([mid,CGPoint(x:pos.x+75,y:pos.y+40)],.cyan)
            } else {
            let labelY=guideTop.y-75
            text("接触点连线",CGPoint(x:guideTop.x-270,y:labelY),.cyan)
            leader([mid,CGPoint(x:guideTop.x+25,y:labelY+20),CGPoint(x:guideTop.x-85,y:labelY+20)],.cyan)
            }
            func crosses(_ a:CGPoint,_ b:CGPoint,_ c:CGPoint,_ d:CGPoint)->Bool{
                func cross(_ p:CGPoint,_ q:CGPoint,_ r:CGPoint)->CGFloat{(q.x-p.x)*(r.y-p.y)-(q.y-p.y)*(r.x-p.x)}
                return cross(a,b,c)*cross(a,b,d) < -0.1 && cross(c,d,a)*cross(c,d,b) < -0.1
            }
            let teaching=[(tp,pp),(cp,gp),(bp,ap),(guideTop,guideBottom)]
            for (p,q) in leaders{for (u,v) in teaching{XCTAssertFalse(crosses(p,q,u,v),"Inset leader crosses teaching line")}}
            for i in leaders.indices{for j in leaders.indices where j>i{XCTAssertFalse(crosses(leaders[i].0,leaders[i].1,leaders[j].0,leaders[j].1))}}
        }
        for point in [cp,tp,pp]{XCTAssertGreaterThan(point.x,35);XCTAssertLessThan(point.x,raster.width-35);XCTAssertGreaterThan(point.y,35);XCTAssertLessThan(point.y,raster.height-35)}
        let result=UIGraphicsImageRenderer(size:size,format:format).image{ctx in
            base.draw(at:.zero);ctx.cgContext.saveGState();UIBezierPath(roundedRect:box,cornerRadius:18).addClip();detail.draw(in:box)
            ctx.cgContext.restoreGState();UIColor.white.setStroke();let border=UIBezierPath(roundedRect:box,cornerRadius:18);border.lineWidth=2;border.stroke()
        }
        return(result,["view":"2d-compact-diagram","cueTargetDistanceM":0.20,"targetPocketDistanceM":0.20,"angleDegrees":capture.vm.cutAngleDegrees,"parallelGuide":true,"leadersCrossing":false,"screenRect":[box.minX,box.minY,box.width,box.height],"lineWidthPixels":2,"cue":[cp.x/2,cp.y/2],"target":[tp.x/2,tp.y/2],"pocket":[pp.x/2,pp.y/2]])
    }
    private func parallelCleanInset(_ capture:Capture,renderer:SCNRenderer,camera:SCNNode,base:UIImage,time:Double) throws -> (UIImage,[String:Any]) {
        let env=ProcessInfo.processInfo.environment
        if (env["PARALLEL_COMPACT_INSET"] ?? env["TEST_RUNNER_PARALLEL_COMPACT_INSET"]) == "1" {
            return try parallelDiagramInset(capture,renderer:renderer,camera:camera,base:base,time:time)
        }
        let wide=size.width>1080
        let s=capture.vm.scene,box=wide ? CGRect(x:760,y:40,width:640,height:640):CGRect(x:520,y:40,width:520,height:560)
        let raster=CGSize(width:box.width*2,height:box.height*2)
        camera.position=SCNVector3(-0.13,s.surfaceY+3,-0.25)
        camera.look(at:SCNVector3(-0.13,s.surfaceY,-0.25),up:SCNVector3(0,0,-1),localFront:SCNVector3(0,0,-1))
        camera.camera!.usesOrthographicProjection=true;camera.camera!.projectionDirection = .vertical
        camera.camera!.orthographicScale=0.58;camera.camera!.zNear=0.01;camera.camera!.zFar=100
        let nodes=[s.ghostBallNode,s.perpLineNode,s.strikeLineNode,s.angleArcNode,s.contactDotNode,
                   s.rootNode.childNode(withName:"videoSpatialLabels",recursively:false),
                   s.rootNode.childNode(withName:"parallelExtras",recursively:false),
                   s.rootNode.childNode(withName:"parallelShortPotLine",recursively:false)].compactMap{$0}
        let hidden=nodes.map{$0.isHidden};nodes.forEach{$0.isHidden=true}
        defer{for (node,value) in zip(nodes,hidden){node.isHidden=value};SCNTransaction.flush()}
        SCNTransaction.flush()
        let shot=renderer.snapshot(atTime:time,with:raster,antialiasingMode:.multisampling4X)
        func project(_ p:SCNVector3)->CGPoint{let v=renderer.projectPoint(p);return CGPoint(x:CGFloat(v.x),y:raster.height-CGFloat(v.y))}
        let cue=try XCTUnwrap(s.cueBallNode).position
        let n=simd_normalize(SIMD2<Float>(capture.aim.x-capture.target.x,capture.aim.z-capture.target.z))
        let a=AngleSceneCalculator.contactPointPosition(targetBall:capture.target,pocket:capture.aim)
        let b=SCNVector3(cue.x+AngleSceneCalculator.ballRadius*n.x,cue.y,cue.z+AngleSceneCalculator.ballRadius*n.y)
        let ap=project(a),bp=project(b),cp=project(cue),gp=project(capture.ghost),tp=project(capture.target),pp=project(capture.aim)
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        let detail=UIGraphicsImageRenderer(size:raster,format:format).image{ctx in
            UIColor.black.setFill();ctx.fill(CGRect(origin:.zero,size:raster));shot.draw(at:.zero)
            let g=ctx.cgContext
            func line(_ p:CGPoint,_ q:CGPoint,_ color:UIColor,dashed:Bool=false){g.setStrokeColor(color.cgColor);g.setLineWidth(4);g.setLineDash(phase:0,lengths:dashed ? [12,9]:[]);g.move(to:p);g.addLine(to:q);g.strokePath()}
            line(tp,pp,.black,dashed:true)
            let delta=CGPoint(x:gp.x-cp.x,y:gp.y-cp.y)
            line(cp,CGPoint(x:gp.x+delta.x*0.55,y:gp.y+delta.y*0.55),.white)
            line(bp,ap,.cyan)
            func label(_ text:String,_ anchor:CGPoint,_ offset:CGPoint,_ color:UIColor){
                let pos=CGPoint(x:anchor.x+offset.x,y:anchor.y+offset.y)
                let attrs:[NSAttributedString.Key:Any]=[.font:UIFont.systemFont(ofSize:34,weight:.semibold),.foregroundColor:color]
                let width=(text as NSString).size(withAttributes:attrs).width
                line(anchor,CGPoint(x:offset.x<0 ? pos.x+width+8:pos.x-8,y:pos.y+20),color)
                (text as NSString).draw(at:pos,withAttributes:attrs)
                XCTAssertGreaterThan(pos.x,10);XCTAssertLessThan(pos.x+width,raster.width-10)
            }
            for point in [ap,bp]{UIColor.red.setFill();UIBezierPath(ovalIn:CGRect(x:point.x-6,y:point.y-6,width:12,height:12)).fill()}
            label("目标球接触点",ap,CGPoint(x:55,y:-25),.red)
            label("母球接触点",bp,CGPoint(x:-240,y:60),.red)
            label("接触点连线",CGPoint(x:(ap.x+bp.x)/2,y:(ap.y+bp.y)/2),CGPoint(x:80,y:60),.cyan)
        }
        for point in [cp,tp,pp]{XCTAssertGreaterThan(point.x,35);XCTAssertLessThan(point.x,raster.width-35);XCTAssertGreaterThan(point.y,35);XCTAssertLessThan(point.y,raster.height-35)}
        let result=UIGraphicsImageRenderer(size:size,format:format).image{ctx in
            base.draw(at:.zero);ctx.cgContext.saveGState();UIBezierPath(roundedRect:box,cornerRadius:18).addClip();detail.draw(in:box)
            ctx.cgContext.restoreGState();UIColor.white.setStroke();let border=UIBezierPath(roundedRect:box,cornerRadius:18);border.lineWidth=2;border.stroke()
        }
        return(result,["view":"2d-clean","screenRect":[box.minX,box.minY,box.width,box.height],"lineWidthPixels":2,"cue":[cp.x/2,cp.y/2],"target":[tp.x/2,tp.y/2],"pocket":[pp.x/2,pp.y/2]])
    }
    private func parallelOverviewInset(_ capture:Capture,renderer:SCNRenderer,camera:SCNNode,
                                       base:UIImage,time:Double,degrees:Double) throws -> (UIImage,[String:Any]) {
        let scene=capture.vm.scene
        let env=ProcessInfo.processInfo.environment
        let cutting=(env["PARALLEL_CUT_PLANE"] ?? env["TEST_RUNNER_PARALLEL_CUT_PLANE"]) == "1"
        let box=CGRect(x:640,y:70,width:400,height:480),raster=CGSize(width:800,height:960)
        camera.position=SCNVector3(-0.27,scene.surfaceY+3,-0.15)
        camera.look(at:SCNVector3(-0.27,scene.surfaceY,-0.15),up:SCNVector3(0,0,-1),localFront:SCNVector3(0,0,-1))
        if cutting {
            camera.position=SCNVector3(0.73,scene.surfaceY+3,1.45)
            camera.look(at:SCNVector3(-0.27,scene.surfaceY,-0.15),up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
        }
        camera.camera!.usesOrthographicProjection=true;camera.camera!.projectionDirection = .vertical
        camera.camera!.orthographicScale=cutting ? 0.75:0.67;camera.camera!.zNear=0.01;camera.camera!.zFar=100
        camera.camera!.wantsExposureAdaptation=false
        let labels=try XCTUnwrap(scene.rootNode.childNode(withName:"videoSpatialLabels",recursively:false))
        for world in [capture.target,capture.ghost,capture.aim,try XCTUnwrap(scene.cueBallNode).position] {
            let p=capture.renderer.projectPoint(world)
            XCTAssertFalse(box.intersects(CGRect(x:CGFloat(p.x)-35,y:size.height-CGFloat(p.y)-35,width:70,height:70)))
        }
        let arcHidden=scene.angleArcNode?.isHidden ?? true
        labels.isHidden=true;scene.angleArcNode?.isHidden=true
        let contactLine=scene.rootNode.childNode(withName:"parallelContactConnector",recursively:true)
        let cutRoot=cutting ? try parallelCutPlane(capture):nil
        if let cutRoot {scene.rootNode.addChildNode(cutRoot);contactLine?.isHidden=true}
        defer{cutRoot?.removeFromParentNode();contactLine?.isHidden=false; labels.isHidden=false;scene.angleArcNode?.isHidden=arcHidden;SCNTransaction.flush()}
        SCNTransaction.flush()
        let detail=renderer.snapshot(atTime:time,with:raster,antialiasingMode:.multisampling4X)
        var points:[String:[Float]]=[:]
        let cuePosition = try XCTUnwrap(scene.cueBallNode).position
        let overviewPoints: [(String, SCNVector3)] = [("cue",cuePosition),("target",capture.target),("pocket",capture.aim)]
        for (id,world) in overviewPoints {
            let p=renderer.projectPoint(world)
            XCTAssertGreaterThan(p.x,30);XCTAssertLessThan(p.x,Float(raster.width)-30)
            XCTAssertGreaterThan(p.y,30);XCTAssertLessThan(p.y,Float(raster.height)-30)
            points[id]=[p.x/2,(Float(raster.height)-p.y)/2]
        }
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        let result=UIGraphicsImageRenderer(size:size,format:format).image{context in
            base.draw(at:.zero);context.cgContext.saveGState()
            UIBezierPath(roundedRect:box,cornerRadius:18).addClip();detail.draw(in:box)
            context.cgContext.restoreGState();UIColor.white.withAlphaComponent(0.85).setStroke()
            let border=UIBezierPath(roundedRect:box,cornerRadius:18);border.lineWidth=2;border.stroke()
        }
        return(result,["screenRect":[box.minX,box.minY,box.width,box.height],"orthographicScale":cutting ? 0.75:0.67,
                       "view":cutting ? "oblique-cut-plane":"2d-overhead","points":points,"rasterSize":[800,960]])
    }
    private func parallelFlatFrame(_ capture:Capture,time:Double) throws -> UIImage {
        let renderer=capture.renderer,s=capture.vm.scene
        let cue=try XCTUnwrap(s.cueBallNode).position
        let n=simd_normalize(SIMD2<Float>(capture.aim.x-capture.target.x,capture.aim.z-capture.target.z))
        let b=SCNVector3(cue.x+AngleSceneCalculator.ballRadius*n.x,cue.y,cue.z+AngleSceneCalculator.ballRadius*n.y)
        let a=AngleSceneCalculator.contactPointPosition(targetBall:capture.target,pocket:capture.aim)
        let shot=renderer.snapshot(atTime:time,with:size,antialiasingMode:.multisampling4X)
        func project(_ world:SCNVector3)->CGPoint{let p=renderer.projectPoint(world);return CGPoint(x:CGFloat(p.x),y:size.height-CGFloat(p.y))}
        for world in [cue,capture.target,capture.aim] {
            let p=project(world);XCTAssertGreaterThan(p.x,45);XCTAssertLessThan(p.x,size.width-45)
            XCTAssertGreaterThan(p.y,100);XCTAssertLessThan(p.y,size.height-100)
        }
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        return UIGraphicsImageRenderer(size:size,format:format).image{context in
            UIColor.black.setFill();context.fill(CGRect(origin:.zero,size:size));shot.draw(at:.zero)
            let red=UIColor(red:0.95,green:0.08,blue:0.12,alpha:1),g=context.cgContext
            let canvasWidth=size.width
            func label(_ text:String,_ anchor:CGPoint,_ offset:CGPoint,_ color:UIColor) {
                let pos=CGPoint(x:anchor.x+offset.x,y:anchor.y+offset.y)
                let font=UIFont.systemFont(ofSize:24,weight:.semibold)
                let attributes:[NSAttributedString.Key:Any]=[.font:font,.foregroundColor:color]
                let width=(text as NSString).size(withAttributes:attributes).width
                let end=CGPoint(x:offset.x<0 ? pos.x+width+8:pos.x-8,y:pos.y+14)
                g.setStrokeColor(color.cgColor);g.setLineWidth(1.5);g.move(to:anchor);g.addLine(to:end);g.strokePath()
                (text as NSString).draw(at:pos,withAttributes:attributes)
                XCTAssertGreaterThan(pos.x,20);XCTAssertLessThan(pos.x+width,canvasWidth-20)
            }
            UIColor.black.withAlphaComponent(0.72).setFill()
            UIBezierPath(roundedRect:CGRect(x:45,y:45,width:290,height:94),cornerRadius:14).fill()
            let title=String(format:"切角 %.1f°",capture.vm.cutAngleDegrees)
            (title as NSString).draw(at:CGPoint(x:65,y:59),withAttributes:[.font:UIFont.systemFont(ofSize:30,weight:.semibold),.foregroundColor:UIColor.white])
            ("两球球心距 60 cm" as NSString).draw(at:CGPoint(x:65,y:103),withAttributes:[.font:UIFont.systemFont(ofSize:21),.foregroundColor:UIColor.white])
            label("接触点",project(a),CGPoint(x:65,y:-30),red)
            label("瞄准点",project(capture.ghost),CGPoint(x:65,y:35),UIColor.systemYellow)
            label("母球接触点",project(b),CGPoint(x:-185,y:-50),red)
            let midpoint=SCNVector3((a.x+b.x)/2,a.y,(a.z+b.z)/2)
            label("接触点连线",project(midpoint),CGPoint(x:65,y:55),UIColor.cyan)
            let guide=SCNVector3(cue.x+n.x*0.27,cue.y,cue.z+n.y*0.27)
            label("平行虚线",project(guide),CGPoint(x:-160,y:-30),red)
        }
    }
    func testParallelFollowVideo() async throws {
        let out=try outputDirectory(),env=ProcessInfo.processInfo.environment
        let stills=(env["PARALLEL_STILLS"] ?? env["TEST_RUNNER_PARALLEL_STILLS"]) == "1"
        let flat=(env["TEST_RUNNER_PARALLEL_FULL_2D"] ?? env["PARALLEL_FULL_2D"]) == "1"
        let close=(env["PARALLEL_CLOSE_PREVIEW"] ?? env["TEST_RUNNER_PARALLEL_CLOSE_PREVIEW"]) == "1"
        let grid=(env["PARALLEL_CAMERA_GRID"] ?? env["TEST_RUNNER_PARALLEL_CAMERA_GRID"]) == "1"
        let wide=(env["PARALLEL_WIDE_PREVIEW"] ?? env["TEST_RUNNER_PARALLEL_WIDE_PREVIEW"]) == "1"
        let minimal=(env["PARALLEL_MINIMAL_PREVIEW"] ?? env["TEST_RUNNER_PARALLEL_MINIMAL_PREVIEW"]) == "1"
        let ballDistance:Float=close ? 0.40:0.60
        let elevated=(env["PARALLEL_ELEVATED_PREVIEW"] ?? env["TEST_RUNNER_PARALLEL_ELEVATED_PREVIEW"]) == "1"
        let defaultCameraBack:Float=wide ? 0.35:elevated ? 0.65:(close ? 0.325:0.65)
        let defaultEyeHeight:Float=wide ? 0.75:elevated ? 0.55:(close ? 0.225:0.45)
        let originalSize=size
        size=CGSize(width:wide ? 1440:1080,height:1440);spatialVideoLabels=true
        defer{size=originalSize;spatialVideoLabels=false}
        let legacy=try makeCapture(flat ? "2d":"3d"),vm=legacy.vm,s=vm.scene
        XCTAssertTrue(s.applyTableStyle(.charcoal,showsSights:true));s.applyClothColor(.green)
        XCTAssertTrue(try XCTUnwrap(s.cueStick).applyStyle(.inkDragon));XCTAssertEqual(s.cueStick?.style,.inkDragon)
        let r=AngleSceneCalculator.ballRadius,y=s.surfaceY+r
        let target=SCNVector3(0,y,-0.23)
        try XCTUnwrap(vm.targetNode).position=target;vm.selectPocket(at:4)
        let aim=AngleSceneCalculator.effectivePocketAimPoint(targetBall:target,pocketIndex:4,surfaceY:s.surfaceY)
        let ghost=AngleSceneCalculator.ghostBallPosition(targetBall:target,pocket:aim,ballRadius:r)
        let capture=Capture(vm:vm,renderer:legacy.renderer,labelView:legacy.labelView,labels:legacy.labels,
                            target:target,aim:aim,ghost:ghost,cameraTransform:legacy.cameraTransform)
        let yellow=UIColor(red:1,green:0.82,blue:0.06,alpha:1)
        let annotationRed=UIColor(red:0.95,green:0.08,blue:0.12,alpha:1)
        for dash in try XCTUnwrap(s.ghostBallNode).childNodes where dash.geometry is SCNCylinder && dash.name != "ghostAimDot" {
            let geo=try XCTUnwrap(dash.geometry?.copy() as? SCNGeometry),mat=SCNMaterial()
            mat.lightingModel = .constant;mat.diffuse.contents=yellow;geo.materials=[mat];dash.geometry=geo
        }
        let root=SCNNode(),extraLabels=SCNNode();root.name="parallelExtras";s.rootNode.addChildNode(root);s.rootNode.addChildNode(extraLabels)
        let detailCamera=SCNNode();detailCamera.camera=SCNCamera();s.rootNode.addChildNode(detailCamera)
        let detailRenderer=SCNRenderer(device:nil,options:nil);detailRenderer.scene=s;detailRenderer.pointOfView=detailCamera
        detailRenderer.autoenablesDefaultLighting=false;detailRenderer.delegate=s.contactOcclusion
        let shortPotLine=s.addDashedLine(from:target,to:aim,color:.black,radius:TrajectoryStyle.lineMain,
                                            dash:0.018,gap:0.012,placement:.table,layer:.aiming)
        shortPotLine.name="parallelShortPotLine"
        let writer=stills ? nil : try VideoWriter(url:out.appendingPathComponent(flat ? "parallel-middle-2d-18s.mp4":"parallel-middle-3d-18s.mp4"),size:size,fps:60)
        let n=simd_normalize(SIMD2<Float>(aim.x-target.x,aim.z-target.z)),side=SIMD2<Float>(-n.y,n.x)
        var rows:[[String:Any]]=[]
        for index in 0..<1080 {
            if grid && !(510...518).contains(index) {continue}
            if close && !grid && index != 510 {continue}
            if stills && !grid && ![0,200,360,510,660,820,960,1079].contains(index){continue}
            try autoreleasepool {
                let gridIndex=grid ? index-510:0
                let cameraBack:Float=grid ? [Float(0.35),0.45,0.55][gridIndex%3]:defaultCameraBack
                let eyeHeight:Float=grid ? [Float(0.55),0.65,0.75][gridIndex/3]:defaultEyeHeight
                let t=grid ? 8.5:Double(index)/60,degrees=89*(1-max(0,min(1,(t-1)/15)))
                let a=Float(degrees*Double.pi/180),d=n*cos(a)+side*sin(a),diameter=2*r
                let length = -diameter*cos(a)+sqrt(ballDistance*ballDistance-pow(diameter*sin(a),2))
                let cue=SCNVector3(ghost.x-length*d.x,y,ghost.z-length*d.y)
                try XCTUnwrap(s.cueBallNode).position=cue;vm.updateCalculations()
                s.updateVisualization(cueBall:cue,targetBall:target,pocket:aim,showAngleAnnotations:true,
                                      showOverlapMarkers:true,showLineLabels:false,extendStrikeLineToRail:true)
                s.setFreeAimPreviewLine(nil);s.setIdealObjectLine(nil)
                s.pocketLineNode?.isHidden=true
                s.updateCueStick(cueBallPosition:cue,aimDirection:SCNVector3(d.x,0,d.y))
                let camera=s.cameraNode!
                camera.position=SCNVector3(cue.x-cameraBack*d.x,s.surfaceY+eyeHeight,cue.z-cameraBack*d.y)
                camera.camera!.fieldOfView=80
                let toPocket=simd_normalize(SIMD2<Float>(aim.x-camera.position.x,aim.z-camera.position.z))
                let baseView=simd_normalize(d+toPocket)
                let screenRight=SIMD2<Float>(-baseView.y,baseView.x)
                let framingYaw=Float(15*Double.pi/180)
                let view=baseView*cos(framingYaw)+screenRight*sin(framingYaw)
                camera.look(at:SCNVector3(camera.position.x+(grid || wide ? cameraBack+0.52:(close && !elevated ? 0.585:1.17))*view.x,ghost.y,camera.position.z+(grid || wide ? cameraBack+0.52:(close && !elevated ? 0.585:1.17))*view.y),
                            up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
                if flat {
                    camera.position=SCNVector3(-0.27,s.surfaceY+3,-0.15)
                    camera.look(at:SCNVector3(-0.27,s.surfaceY,-0.15),up:SCNVector3(0,0,-1),localFront:SCNVector3(0,0,-1))
                    camera.camera!.usesOrthographicProjection=true;camera.camera!.orthographicScale=0.80
                } else {
                XCTAssertEqual(camera.position.y-s.surfaceY,eyeHeight,accuracy:0.000001)
                XCTAssertEqual(AngleSceneCalculator.horizontalDistance(camera.position,cue),cameraBack,accuracy:0.000001)
                }
                let contact=AngleSceneCalculator.contactPointPosition(targetBall:target,pocket:aim)
                let b=SCNVector3(cue.x+r*n.x,y,cue.z+r*n.y)
                let v=SIMD2<Float>(contact.x-b.x,contact.z-b.z),w=SIMD2<Float>(ghost.x-cue.x,ghost.z-cue.z)
                XCTAssertEqual(v.x,w.x,accuracy:0.000001);XCTAssertEqual(v.y,w.y,accuracy:0.000001)
                XCTAssertEqual(AngleSceneCalculator.horizontalDistance(cue,target),ballDistance,accuracy:0.000001)
                XCTAssertEqual(vm.cutAngleDegrees,degrees,accuracy:0.002)
                XCTAssertLessThan(abs(cue.x)+r,AngleSceneCalculator.innerLength/2)
                XCTAssertLessThan(abs(cue.z)+r,AngleSceneCalculator.innerWidth/2)
                root.childNodes.forEach{$0.removeFromParentNode()};extraLabels.childNodes.forEach{$0.removeFromParentNode()}
                parallelSegment(b,contact,color:.cyan,root:root)
                root.childNodes.last?.name="parallelContactConnector"
                let guideLength=minimal ? (cue.z+AngleSceneCalculator.innerWidth/2):0.347
                let dashCount=minimal ? Int(ceil((guideLength+0.06)/0.016)):26
                for i in 0..<dashCount {
                    let lo:Float = -0.06+Float(i)*0.016,hi=min(lo+0.009,guideLength)
                    parallelSegment(SCNVector3(cue.x+n.x*lo,y,cue.z+n.y*lo),SCNVector3(cue.x+n.x*hi,y,cue.z+n.y*hi),color:annotationRed,root:root)
                }
                let ball=SCNSphere(radius:0.003);ball.segmentCount=16
                let mat=SCNMaterial();mat.lightingModel = .constant;mat.diffuse.contents=annotationRed
                mat.readsFromDepthBuffer=false;mat.writesToDepthBuffer=false;ball.materials=[mat]
                let point=SCNNode(geometry:ball);point.position=b;point.castsShadow=false;point.renderingOrder=100;root.addChildNode(point)
                for node in [try XCTUnwrap(s.contactDotNode)] + (s.angleArcNode?.childNodes.filter{$0.geometry != nil && !($0.geometry is SCNText)} ?? []) {
                    let geo=try XCTUnwrap(node.geometry?.copy() as? SCNGeometry)
                    geo.materials=geo.materials.map{original in let m=original.copy() as! SCNMaterial;m.diffuse.contents = node === s.contactDotNode ? annotationRed : yellow;return m};node.geometry=geo
                }
                SCNTransaction.flush()
                if index==0 || close {_=capture.renderer.snapshot(atTime:t,with:size,antialiasingMode:.multisampling4X)}
                var spatial:[[String:Any]]=[]
                var inset:(UIImage,[String:Any])
                if flat {
                    s.angleArcNode?.isHidden=true
                    inset=(try parallelFlatFrame(capture,time:t),["view":"2d-fullscreen"])
                } else {
                if minimal {
                    s.angleArcNode?.isHidden=true;s.ghostBallNode?.isHidden=true;s.perpLineNode?.isHidden=true
                    try parallelExtraLabel("目标球接触点",anchor:contact,offset:SIMD2(-160,25),color:annotationRed,capture:capture,root:extraLabels)
                } else {
                spatial=try updateSpatialVideoLabels(capture,darkAnnotations:true,yellowAnnotations:true)
                let nativeLabels=try XCTUnwrap(s.rootNode.childNode(withName:"videoSpatialLabels",recursively:false))
                for id in ["contact","contactLeader"] {
                    let node=try XCTUnwrap(nativeLabels.childNode(withName:id,recursively:false))
                    let geo=try XCTUnwrap(node.geometry?.copy() as? SCNGeometry)
                    geo.materials=geo.materials.map{source in let material=source.copy() as! SCNMaterial;material.diffuse.contents=annotationRed;return material}
                    node.geometry=geo
                }
                }
                try parallelExtraLabel("母球接触点",anchor:b,offset:minimal ? SIMD2(-200,75):SIMD2(-135,elevated ? 160:110),color:annotationRed,capture:capture,root:extraLabels)
                let midpoint=SCNVector3((b.x+contact.x)/2,y,(b.z+contact.z)/2)
                try parallelExtraLabel("接触点连线",anchor:midpoint,offset:minimal ? SIMD2(-160,50):SIMD2(150,20),color:.cyan,capture:capture,root:extraLabels)
                let guide=SCNVector3(cue.x+n.x*0.07,y,cue.z+n.y*0.07)
                let cuePixel=capture.renderer.projectPoint(cue),guidePixel=capture.renderer.projectPoint(guide)
                let guideOffset=SIMD2<Float>(cuePixel.x-guidePixel.x+145,cuePixel.y-guidePixel.y+(elevated ? 60:100))
                if !minimal {try parallelExtraLabel("平行虚线",anchor:guide,offset:guideOffset,color:annotationRed,capture:capture,root:extraLabels)}
                var extraRects:[CGRect]=[]
                for node in extraLabels.childNodes {
                    guard let text=node.geometry as? SCNText else{continue}
                    let (lo,hi)=text.boundingBox,p=capture.renderer.projectPoint(node.position)
                    let width=CGFloat(23*(hi.x-lo.x)/max(hi.y-lo.y,1))
                    let rect=CGRect(x:CGFloat(p.x)-width/2,y:CGFloat(p.y)-14,width:width,height:28)
                    for other in extraRects{XCTAssertFalse(rect.insetBy(dx:-5,dy:-5).intersects(other),"New labels overlap at \(degrees)")}
                    extraRects.append(rect)
                }
                SCNTransaction.flush()
                let base:UIImage
                if minimal {
                    _=capture.renderer.snapshot(atTime:t,with:size,antialiasingMode:.multisampling4X)
                    base=capture.renderer.snapshot(atTime:t,with:size,antialiasingMode:.multisampling4X)
                } else {
                    _=try image(capture,time:t)
                    base=try image(capture,time:t)
                }
                extraLabels.isHidden=true;SCNTransaction.flush()
                if close {
                    inset=try parallelCleanInset(capture,renderer:detailRenderer,camera:detailCamera,base:base,time:t)
                } else {
                    inset=try parallelOverviewInset(capture,renderer:detailRenderer,camera:detailCamera,base:base,time:t,degrees:degrees)
                }
                extraLabels.isHidden=false;SCNTransaction.flush()
                }
                let cueX=capture.renderer.projectPoint(cue).x/Float(size.width)
                let ghostX=capture.renderer.projectPoint(ghost).x/Float(size.width)
                if !flat { XCTAssertLessThan(cueX,0.48);XCTAssertLessThan(ghostX,0.48) }
                for p in [cue,target,aim] {
                    let pixel=capture.renderer.projectPoint(p)
                    XCTAssertGreaterThan(pixel.x,54);XCTAssertLessThan(pixel.x,1026)
                    XCTAssertGreaterThan(pixel.y,72);XCTAssertLessThan(pixel.y,1368)
                }
                rows.append(["cameraBackM":cameraBack,"eyeHeightM":eyeHeight,"frame":index,"time":t,"degrees":vm.cutAngleDegrees,"distanceM":AngleSceneCalculator.horizontalDistance(cue,target),
                             "cue":[cue.x,cue.y,cue.z],"target":[target.x,target.y,target.z],"ghost":[ghost.x,ghost.y,ghost.z],
                             "targetContact":[contact.x,contact.y,contact.z],"cueContact":[b.x,b.y,b.z],"parallelResidualM":simd_length(v-w),
                             "mainCueX":cueX,"mainGhostX":ghostX,"pocketIndex":4,
                             "camera":[camera.position.x,camera.position.y,camera.position.z],"spatialLabels":spatial,"inset":inset.1])
                if minimal {
                    let cropped=try XCTUnwrap(inset.0.cgImage?.cropping(to:CGRect(x:240,y:0,width:1200,height:1440)))
                    inset.0=UIImage(cgImage:cropped)
                }
                if stills {try XCTUnwrap(inset.0.pngData()).write(to:out.appendingPathComponent("frames/frame-\(index).png"))}
                else {try writer?.append(XCTUnwrap(inset.0.cgImage))}
            }
            if index%60==0{print("PARALLEL_FOLLOW \(index)/1080")}
            try await Task.sleep(nanoseconds:1_000_000)
        }
        try await writer?.finish()
        try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent(stills ? "stills.json":"frames.json"))
    }
}

extension AngleAimingVideoCaptureTests {
    func testParallelTwoPhasePortrait() async throws {
        let out=try outputDirectory(),env=ProcessInfo.processInfo.environment
        let stills=(env["PARALLEL_STILLS"] ?? env["TEST_RUNNER_PARALLEL_STILLS"]) == "1"
        let vm=AngleDynamicViewModel();vm.setupScene();let s=vm.scene
        XCTAssertTrue(s.applyTableStyle(.charcoal,showsSights:true));s.applyClothColor(.green)
        s.setCameraMode(.topDown2D,animated:false)
        let r=AngleSceneCalculator.ballRadius,y=s.surfaceY+r
        let pocket=AngleSceneCalculator.effectivePocketAimPoint(targetBall:SCNVector3(0,y,-0.23),pocketIndex:4,surfaceY:s.surfaceY)
        let camera=try XCTUnwrap(s.cameraNode)
        camera.position=SCNVector3(-0.10,s.surfaceY+3,pocket.z+0.40)
        camera.look(at:SCNVector3(-0.10,s.surfaceY,pocket.z+0.40),up:SCNVector3(0,0,-1),localFront:SCNVector3(0,0,-1))
        camera.camera!.usesOrthographicProjection=true;camera.camera!.projectionDirection = .vertical
        camera.camera!.orthographicScale=0.92;camera.camera!.zNear=0.01;camera.camera!.zFar=100
        let renderer=SCNRenderer(device:nil,options:nil);renderer.scene=s;renderer.pointOfView=camera
        renderer.autoenablesDefaultLighting=false;renderer.delegate=s.contactOcclusion
        s.cueStick?.rootNode.isHidden=true
        let canvas=CGSize(width:1080,height:1920)
        let writer=stills ? nil:try VideoWriter(url:out.appendingPathComponent("parallel-2d-two-phase-18s.mp4"),size:canvas,fps:60)
        struct State {
            let cue:SCNVector3,target:SCNVector3,ghost:SCNVector3,a:SCNVector3,b:SCNVector3,guide:SCNVector3,tail:SCNVector3
            let cut:Double,rotation:Double,orientation:Float
        }
        func state(_ index:Int)->State {
            let time=Double(index)/60,cut=15+30*min(1,time/9),rotation=30*max(0,min(1,(time-9)/(9-1.0/60)))
            let angle=Float(cut*Double.pi/180),orientation=Float(rotation*Double.pi/180)
            func rotate(_ x:Float,_ z:Float)->SCNVector3{SCNVector3(pocket.x+x*cos(orientation)-z*sin(orientation),y,pocket.z+x*sin(orientation)+z*cos(orientation))}
            let length = -2*r*cos(angle)+sqrt(0.40*0.40-pow(2*r*sin(angle),2))
            let target=rotate(0,0.4),ghost=rotate(0,0.4+2*r),cue=rotate(-length*sin(angle),0.4+2*r+length*cos(angle))
            let n=simd_normalize(SIMD2<Float>(pocket.x-target.x,pocket.z-target.z))
            let a=SCNVector3(target.x-r*n.x,y,target.z-r*n.y),b=SCNVector3(cue.x+r*n.x,y,cue.z+r*n.y)
            let toRail=(-AngleSceneCalculator.innerWidth/2-cue.z)/n.y
            let guide=SCNVector3(cue.x+n.x*toRail,y,-AngleSceneCalculator.innerWidth/2)
            let tail=SCNVector3(cue.x-n.x*0.04,y,cue.z-n.y*0.04)
            return State(cue:cue,target:target,ghost:ghost,a:a,b:b,guide:guide,tail:tail,cut:cut,rotation:rotation,orientation:orientation)
        }
        _=renderer.snapshot(atTime:0,with:canvas,antialiasingMode:.multisampling4X)
        var projectionTarget=state(0).target
        func project(_ v:SCNVector3)->CGPoint{CGPoint(x:540+CGFloat(v.x-projectionTarget.x)*1920/1.84,y:960+CGFloat(v.z-projectionTarget.z)*1920/1.84)}
        func rail(_ st:State)->SCNVector3 {
            AngleSceneCalculator.rayToInnerRail(from:st.cue,dir:SCNVector3(st.ghost.x-st.cue.x,0,st.ghost.z-st.cue.z),inset:0)
        }
        func cross(_ p:CGPoint,_ q:CGPoint,_ r:CGPoint)->CGFloat{(q.x-p.x)*(r.y-p.y)-(q.y-p.y)*(r.x-p.x)}
        func intersects(_ a:CGPoint,_ b:CGPoint,_ c:CGPoint,_ d:CGPoint)->Bool {
            let rx=b.x-a.x,ry=b.y-a.y,sx=d.x-c.x,sy=d.y-c.y
            let den=rx*sy-ry*sx
            if abs(den)<0.001{return false}
            let t=((c.x-a.x)*sy-(c.y-a.y)*sx)/den
            let u=((c.x-a.x)*ry-(c.y-a.y)*rx)/den
            let marginA=1/max(1,hypot(rx,ry)),marginB=1/max(1,hypot(sx,sy))
            return t>marginA && t<1-marginA && u>marginB && u<1-marginB
        }
        let font=UIFont.systemFont(ofSize:28,weight:.semibold)
        let names=["目标球接触点","母球接触点","接触点连线"]
        let colors:[UIColor]=[.red,.red,.cyan]
        let textSizes=names.map{($0 as NSString).size(withAttributes:[.font:font])}
        let states=(0..<1080).map(state)
        struct Layout {let rect:CGRect;let path:[CGPoint]}
        func plan(_ st:State,_ id:Int,_ offset:CGPoint,_ bend:Int)->Layout? {
            projectionTarget=st.target
            let ap=project(st.a),bp=project(st.b),cp=project(st.cue),tp=project(st.target)
            let anchor=id==0 ? ap:id==1 ? bp:CGPoint(x:(ap.x+bp.x)/2,y:(ap.y+bp.y)/2)
            let angle=CGFloat(st.orientation)
            let pos=CGPoint(x:anchor.x+offset.x*cos(angle)-offset.y*sin(angle),y:anchor.y+offset.x*sin(angle)+offset.y*cos(angle))
            if id==2 && cross(bp,ap,pos)>=0{return nil}
            let ts=textSizes[id],rect=CGRect(x:pos.x-ts.width/2,y:pos.y-ts.height/2,width:ts.width,height:ts.height)
            guard CGRect(x:28,y:50,width:1024,height:1820).contains(rect) else{return nil}
            let ballPixels=CGFloat(r)*1920/1.84
            for p in [cp,tp,project(pocket)] {if rect.insetBy(dx:-12,dy:-12).intersects(CGRect(x:p.x-ballPixels,y:p.y-ballPixels,width:2*ballPixels,height:2*ballPixels)){return nil}}
            let end=CGPoint(x:min(max(anchor.x,rect.minX-8),rect.maxX+8),y:min(max(anchor.y,rect.minY-8),rect.maxY+8))
            var path=[anchor,end]
            if bend==1 {path=[anchor,CGPoint(x:anchor.x,y:end.y),end]}
            if bend==2 {path=[anchor,CGPoint(x:end.x,y:anchor.y),end]}
            if bend==3 {
                let g=project(st.guide),p=project(pocket)
                path=[anchor,CGPoint(x:g.x+35,y:min(g.y,p.y)-45),CGPoint(x:end.x,y:min(g.y,p.y)-45),end]
            }
            if bend==4 {path=[anchor,ap,CGPoint(x:end.x,y:ap.y),end]}
            if bend==5 {path=[]}
            let lines=[(tp,project(pocket)),(cp,project(rail(st))),(bp,ap),(project(st.guide),project(st.tail))]
            let corners=[CGPoint(x:rect.minX-5,y:rect.minY-5),CGPoint(x:rect.maxX+5,y:rect.minY-5),CGPoint(x:rect.maxX+5,y:rect.maxY+5),CGPoint(x:rect.minX-5,y:rect.maxY+5)]
            for (u,v) in lines {
                if rect.contains(u) || rect.contains(v){return nil}
                for j in 0..<4 {if intersects(u,v,corners[j],corners[(j+1)%4]){return nil}}
                for (p,q) in zip(path,path.dropFirst()){if intersects(p,q,u,v){return nil}}
            }
            // Avoid crossing the other ball, and leave a contact anchor outward.
            for (p,q) in zip(path,path.dropFirst()) {
                for step in 1..<20 {
                    let t=CGFloat(step)/20,point=CGPoint(x:p.x+(q.x-p.x)*t,y:p.y+(q.y-p.y)*t)
                    for ball in [cp,tp] {if hypot(point.x-ball.x,point.y-ball.y)<ballPixels-2{return nil}}
                }
            }
            return Layout(rect:rect,path:path)
        }
        // One relative layout for the whole movie: no per-frame label jumps.
        var selected:[(CGPoint,Int)]=[]
        let samples=stride(from:0,to:1080,by:4).map{states[$0]}+[states[1079]]
        for id in 0..<3 {
            var candidates:[(CGPoint,Int,Double)]=[]
            for x in stride(from:-360,through:360,by:40) {for z in stride(from:-300,through:300,by:40) {
                if abs(x)+abs(z)<100 {continue}
                for bend in (id==1 ? [0,1,2]:[0,1,2,5]) {
                    let preference=(id==0 && x<0 || id==1 && x>0) ? 70.0:0.0
                    candidates.append((CGPoint(x:x,y:z),bend,hypot(Double(x),Double(z))+Double(bend)*100+preference))
                }
            }}
            candidates.sort{$0.2<$1.2}
            var best:(CGPoint,Int)?
            for c in candidates {
                var valid=true
                for st in samples {
                    guard let layout=plan(st,id,c.0,c.1) else{valid=false;break}
                    for previous in 0..<selected.count {
                        guard let other=plan(st,previous,selected[previous].0,selected[previous].1) else{valid=false;break}
                        if layout.rect.insetBy(dx:-10,dy:-10).intersects(other.rect){valid=false;break}
                        for (p,q) in zip(layout.path,layout.path.dropFirst()){for (u,v) in zip(other.path,other.path.dropFirst()){if intersects(p,q,u,v){valid=false}}}
                    }
                    if !valid{break}
                }
                if valid{best=(c.0,c.1);break}
            }
            selected.append(try XCTUnwrap(best,"No continuous label layout for \(names[id])"))
        }
        var records:[[String:Any]]=[]
        for index in 0..<1080 {
            if stills && ![0,270,539,540,810,1079].contains(index){continue}
            try autoreleasepool {
                let st=states[index],time=Double(index)/60
                projectionTarget=st.target
                camera.position=SCNVector3(st.target.x,s.surfaceY+3,st.target.z)
                camera.look(at:SCNVector3(st.target.x,s.surfaceY,st.target.z),up:SCNVector3(0,0,-1),localFront:SCNVector3(0,0,-1))
                let aimEnd=rail(st)
                let hit=AngleSceneCalculator.aimRayTargetEntry(from:st.cue,toward:aimEnd,target:st.target)
                try XCTUnwrap(s.cueBallNode).position=st.cue;try XCTUnwrap(vm.targetNode).position=st.target
                for node in [s.ghostBallNode,s.strikeLineNode,s.pocketLineNode,s.contactDotNode,s.perpLineNode,s.angleArcNode,s.cueStick?.rootNode].compactMap({$0}){node.isHidden=true}
                let a=SIMD2<Float>(st.a.x-st.b.x,st.a.z-st.b.z),b=SIMD2<Float>(st.ghost.x-st.cue.x,st.ghost.z-st.cue.z)
                XCTAssertLessThan(simd_length(a-b),0.000001)
                XCTAssertEqual(AngleSceneCalculator.horizontalDistance(st.cue,st.target),0.4,accuracy:0.000001)
                XCTAssertEqual(AngleSceneCalculator.horizontalDistance(st.target,pocket),0.4,accuracy:0.000001)
                let n=simd_normalize(SIMD2<Float>(pocket.x-st.target.x,pocket.z-st.target.z))
                let measured=Double(acos(max(-1,min(1,simd_dot(simd_normalize(b),n)))))*180/Double.pi
                XCTAssertEqual(measured,st.cut,accuracy:0.002)
                s.hideAllVisualization()
                SCNTransaction.flush();let shot=renderer.snapshot(atTime:time,with:canvas,antialiasingMode:.multisampling4X)
                let layouts=try (0..<3).map{try XCTUnwrap(plan(st,$0,selected[$0].0,selected[$0].1))}
                let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
                let result=UIGraphicsImageRenderer(size:canvas,format:format).image{ctx in
                    UIColor.black.setFill();ctx.fill(CGRect(origin:.zero,size:canvas));shot.draw(at:.zero)
                    let g=ctx.cgContext
                    func line(_ p:CGPoint,_ q:CGPoint,_ color:UIColor,dashed:Bool=false){g.setStrokeColor(color.cgColor);g.setLineWidth(3);g.setLineDash(phase:0,lengths:dashed ? [12,10]:[]);g.move(to:p);g.addLine(to:q);g.strokePath()}
                    line(project(st.target),project(pocket),.black,dashed:true)
                    line(project(st.guide),project(st.tail),.red,dashed:true)
                    line(project(st.cue),project(hit ?? aimEnd),.white)
                    if let hit {line(project(hit),project(aimEnd),.white,dashed:true)}
                    line(project(st.b),project(st.a),.cyan)
                    for p in [project(st.a),project(st.b)]{UIColor.red.setFill();UIBezierPath(ovalIn:CGRect(x:p.x-6,y:p.y-6,width:12,height:12)).fill()}
                    for id in 0..<3 {
                        let l=layouts[id]
                        for (p,q) in zip(l.path,l.path.dropFirst()){line(p,q,colors[id])}
                        (names[id] as NSString).draw(at:l.rect.origin,withAttributes:[.font:font,.foregroundColor:colors[id]])
                    }
                }
                let actualTarget=renderer.projectPoint(st.target)
                XCTAssertEqual(actualTarget.x,540,accuracy:0.05);XCTAssertEqual(actualTarget.y,960,accuracy:0.05)
                for p in [st.cue,st.target,pocket] {let q=project(p);XCTAssertGreaterThan(q.x,55);XCTAssertLessThan(q.x,1025);XCTAssertGreaterThan(q.y,90);XCTAssertLessThan(q.y,1830)}
                records.append(["frame":index,"time":time,"cutDegrees":measured,"clockwiseDegrees":st.rotation,
                                "cue":[st.cue.x,st.cue.y,st.cue.z],"target":[st.target.x,st.target.y,st.target.z],"pocket":[pocket.x,pocket.y,pocket.z],
                                "ghost":[st.ghost.x,st.ghost.y,st.ghost.z],"cueContact":[st.b.x,st.b.y,st.b.z],"targetContact":[st.a.x,st.a.y,st.a.z],
                                "targetPixel":[actualTarget.x,actualTarget.y],"aimRail":[aimEnd.x,aimEnd.y,aimEnd.z],"aimBlocked":hit != nil,
                                "parallelResidualM":simd_length(a-b),"labelRects":layouts.map{[$0.rect.minX,$0.rect.minY,$0.rect.width,$0.rect.height]}])
                if stills{try XCTUnwrap(result.pngData()).write(to:out.appendingPathComponent("frames/frame-\(index).png"))}
                else{try writer?.append(XCTUnwrap(result.cgImage))}
            }
            if index%120==0{print("TWO_PHASE \(index)/1080")}
            try await Task.sleep(nanoseconds:1_000_000)
        }
        try await writer?.finish()
        try JSONSerialization.data(withJSONObject:records,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent(stills ? "stills.json":"frames.json"))
        print("LABEL_LAYOUT \(selected)")
    }
}

extension AngleAimingVideoCaptureTests {
    func testParallelTwoPhaseFirstPerson() async throws {
        let out=try outputDirectory(),env=ProcessInfo.processInfo.environment
        let stills=(env["PARALLEL_STILLS"] ?? env["TEST_RUNNER_PARALLEL_STILLS"]) == "1"
        let vm=AngleDynamicViewModel();vm.setupScene();let s=vm.scene
        XCTAssertTrue(s.applyTableStyle(.charcoal,showsSights:true));s.applyClothColor(.green)
        s.setCameraMode(.topDown2D,animated:false)
        XCTAssertTrue(try XCTUnwrap(s.cueStick).applyStyle(.inkDragon))
        let r=AngleSceneCalculator.ballRadius,y=s.surfaceY+r
        let pocket=AngleSceneCalculator.effectivePocketAimPoint(targetBall:SCNVector3(0,y,-0.23),pocketIndex:4,surfaceY:s.surfaceY)
        let camera=try XCTUnwrap(s.cameraNode)
        camera.position=SCNVector3(-0.10,s.surfaceY+3,pocket.z+0.40)
        camera.look(at:SCNVector3(-0.10,s.surfaceY,pocket.z+0.40),up:SCNVector3(0,0,-1),localFront:SCNVector3(0,0,-1))
        camera.camera!.usesOrthographicProjection=false;camera.camera!.fieldOfView=80;camera.camera!.projectionDirection = .vertical
        camera.camera!.orthographicScale=0.92;camera.camera!.zNear=0.01;camera.camera!.zFar=100
        let renderer=SCNRenderer(device:nil,options:nil);renderer.scene=s;renderer.pointOfView=camera
        renderer.autoenablesDefaultLighting=false;renderer.delegate=s.contactOcclusion
        s.cueStick?.rootNode.isHidden=true
        let canvas=CGSize(width:1080,height:1920)
        let writer=stills ? nil:try VideoWriter(url:out.appendingPathComponent("parallel-3d-two-phase-18s.mp4"),size:canvas,fps:60)
        struct State {
            let cue:SCNVector3,target:SCNVector3,ghost:SCNVector3,a:SCNVector3,b:SCNVector3,guide:SCNVector3,tail:SCNVector3
            let cut:Double,rotation:Double,orientation:Float
        }
        func state(_ index:Int)->State {
            let time=Double(index)/60,cut=15+30*min(1,time/9),rotation=30*max(0,min(1,(time-9)/(9-1.0/60)))
            let angle=Float(cut*Double.pi/180),orientation=Float(rotation*Double.pi/180)
            func rotate(_ x:Float,_ z:Float)->SCNVector3{SCNVector3(pocket.x+x*cos(orientation)-z*sin(orientation),y,pocket.z+x*sin(orientation)+z*cos(orientation))}
            let length = -2*r*cos(angle)+sqrt(0.40*0.40-pow(2*r*sin(angle),2))
            let target=rotate(0,0.4),ghost=rotate(0,0.4+2*r),cue=rotate(-length*sin(angle),0.4+2*r+length*cos(angle))
            let n=simd_normalize(SIMD2<Float>(pocket.x-target.x,pocket.z-target.z))
            let a=SCNVector3(target.x-r*n.x,y,target.z-r*n.y),b=SCNVector3(cue.x+r*n.x,y,cue.z+r*n.y)
            let toRail=(-AngleSceneCalculator.innerWidth/2-cue.z)/n.y
            let guide=SCNVector3(cue.x+n.x*toRail,y,-AngleSceneCalculator.innerWidth/2)
            let tail=SCNVector3(cue.x-n.x*0.04,y,cue.z-n.y*0.04)
            return State(cue:cue,target:target,ghost:ghost,a:a,b:b,guide:guide,tail:tail,cut:cut,rotation:rotation,orientation:orientation)
        }
        _=renderer.snapshot(atTime:0,with:canvas,antialiasingMode:.multisampling4X)
        var projectionTarget=state(0).target
        func setCamera(_ st:State) {
            let d=simd_normalize(SIMD2<Float>(st.ghost.x-st.cue.x,st.ghost.z-st.cue.z))
            camera.position=SCNVector3(st.cue.x-0.35*d.x,s.surfaceY+0.75,st.cue.z-0.35*d.y)
            camera.look(at:st.target,up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
            SCNTransaction.flush()
        }
        func project(_ v:SCNVector3)->CGPoint{let p=renderer.projectPoint(v);return CGPoint(x:CGFloat(p.x),y:canvas.height-CGFloat(p.y))}
        func rail(_ st:State)->SCNVector3 {
            AngleSceneCalculator.rayToInnerRail(from:st.cue,dir:SCNVector3(st.ghost.x-st.cue.x,0,st.ghost.z-st.cue.z),inset:0)
        }
        func cross(_ p:CGPoint,_ q:CGPoint,_ r:CGPoint)->CGFloat{(q.x-p.x)*(r.y-p.y)-(q.y-p.y)*(r.x-p.x)}
        func intersects(_ a:CGPoint,_ b:CGPoint,_ c:CGPoint,_ d:CGPoint)->Bool {
            let rx=b.x-a.x,ry=b.y-a.y,sx=d.x-c.x,sy=d.y-c.y
            let den=rx*sy-ry*sx
            if abs(den)<0.001{return false}
            let t=((c.x-a.x)*sy-(c.y-a.y)*sx)/den
            let u=((c.x-a.x)*ry-(c.y-a.y)*rx)/den
            let marginA=1/max(1,hypot(rx,ry)),marginB=1/max(1,hypot(sx,sy))
            return t>marginA && t<1-marginA && u>marginB && u<1-marginB
        }
        let font=UIFont.systemFont(ofSize:28,weight:.semibold)
        let names=["目标球接触点","母球接触点","接触点连线"]
        let colors:[UIColor]=[.red,.red,.cyan]
        let textSizes=names.map{($0 as NSString).size(withAttributes:[.font:font])}
        let states=(0..<1080).map(state)
        struct Layout {let rect:CGRect;let path:[CGPoint]}
        func plan(_ st:State,_ id:Int,_ offset:CGPoint,_ bend:Int)->Layout? {
            projectionTarget=st.target;setCamera(st)
            let ap=project(st.a),bp=project(st.b),cp=project(st.cue),tp=project(st.target)
            let anchor=id==0 ? ap:id==1 ? bp:CGPoint(x:(ap.x+bp.x)/2,y:(ap.y+bp.y)/2)
            let angle=CGFloat(st.orientation)
            let pos=CGPoint(x:anchor.x+offset.x*cos(angle)-offset.y*sin(angle),y:anchor.y+offset.x*sin(angle)+offset.y*cos(angle))
            if id==2 && cross(bp,ap,pos)>=0{return nil}
            let ts=textSizes[id],rect=CGRect(x:pos.x-ts.width/2,y:pos.y-ts.height/2,width:ts.width,height:ts.height)
            guard CGRect(x:28,y:50,width:1024,height:1820).contains(rect) else{return nil}
            let ballPixels:CGFloat=40
            for p in [cp,tp,project(pocket)] {if rect.insetBy(dx:-12,dy:-12).intersects(CGRect(x:p.x-ballPixels,y:p.y-ballPixels,width:2*ballPixels,height:2*ballPixels)){return nil}}
            let end=CGPoint(x:min(max(anchor.x,rect.minX-8),rect.maxX+8),y:min(max(anchor.y,rect.minY-8),rect.maxY+8))
            var path=[anchor,end]
            if bend==1 {path=[anchor,CGPoint(x:anchor.x,y:end.y),end]}
            if bend==2 {path=[anchor,CGPoint(x:end.x,y:anchor.y),end]}
            if bend==3 {
                let g=project(st.guide),p=project(pocket)
                path=[anchor,CGPoint(x:g.x+35,y:min(g.y,p.y)-45),CGPoint(x:end.x,y:min(g.y,p.y)-45),end]
            }
            if bend==4 {path=[anchor,ap,CGPoint(x:end.x,y:ap.y),end]}
            if bend==5 {path=[]}
            let lines=[(tp,project(pocket)),(cp,project(rail(st))),(bp,ap),(project(st.guide),project(st.tail))]
            let corners=[CGPoint(x:rect.minX-5,y:rect.minY-5),CGPoint(x:rect.maxX+5,y:rect.minY-5),CGPoint(x:rect.maxX+5,y:rect.maxY+5),CGPoint(x:rect.minX-5,y:rect.maxY+5)]
            for (u,v) in lines {
                if rect.contains(u) || rect.contains(v){return nil}
                for j in 0..<4 {if intersects(u,v,corners[j],corners[(j+1)%4]){return nil}}
                for (p,q) in zip(path,path.dropFirst()){if intersects(p,q,u,v){return nil}}
            }
            // Avoid crossing the other ball, and leave a contact anchor outward.
            for (p,q) in zip(path,path.dropFirst()) {
                for step in 1..<20 {
                    let t=CGFloat(step)/20,point=CGPoint(x:p.x+(q.x-p.x)*t,y:p.y+(q.y-p.y)*t)
                    for ball in [cp,tp] {if hypot(point.x-ball.x,point.y-ball.y)<ballPixels-2{return nil}}
                }
            }
            return Layout(rect:rect,path:path)
        }
        // One relative layout for the whole movie: no per-frame label jumps.
        var selected:[(CGPoint,Int)]=[]
        let samples=stride(from:0,to:1080,by:4).map{states[$0]}+[states[1079]]
        for id in 0..<3 {
            var candidates:[(CGPoint,Int,Double)]=[]
            for x in stride(from:-360,through:360,by:40) {for z in stride(from:-300,through:300,by:40) {
                if abs(x)+abs(z)<100 {continue}
                for bend in (id==1 ? [0,1,2]:[0,1,2,5]) {
                    let preference=(id==0 && x<0 || id==1 && x>0) ? 70.0:0.0
                    candidates.append((CGPoint(x:x,y:z),bend,hypot(Double(x),Double(z))+Double(bend)*100+preference))
                }
            }}
            candidates.sort{$0.2<$1.2}
            var best:(CGPoint,Int)?
            for c in candidates {
                var valid=true
                for st in samples {
                    guard let layout=plan(st,id,c.0,c.1) else{valid=false;break}
                    for previous in 0..<selected.count {
                        guard let other=plan(st,previous,selected[previous].0,selected[previous].1) else{valid=false;break}
                        if layout.rect.insetBy(dx:-10,dy:-10).intersects(other.rect){valid=false;break}
                        for (p,q) in zip(layout.path,layout.path.dropFirst()){for (u,v) in zip(other.path,other.path.dropFirst()){if intersects(p,q,u,v){valid=false}}}
                    }
                    if !valid{break}
                }
                if valid{best=(c.0,c.1);break}
            }
            selected.append(try XCTUnwrap(best,"No continuous label layout for \(names[id])"))
        }
        var records:[[String:Any]]=[]
        for index in 0..<1080 {
            if stills && ![0,270,539,540,810,1079].contains(index){continue}
            try autoreleasepool {
                let st=states[index],time=Double(index)/60
                projectionTarget=st.target
                setCamera(st)
                let aimEnd=rail(st)
                let hit=AngleSceneCalculator.aimRayTargetEntry(from:st.cue,toward:aimEnd,target:st.target)
                try XCTUnwrap(s.cueBallNode).position=st.cue;try XCTUnwrap(vm.targetNode).position=st.target
                for node in [s.ghostBallNode,s.strikeLineNode,s.pocketLineNode,s.contactDotNode,s.perpLineNode,s.angleArcNode,s.cueStick?.rootNode].compactMap({$0}){node.isHidden=true}
                let a=SIMD2<Float>(st.a.x-st.b.x,st.a.z-st.b.z),b=SIMD2<Float>(st.ghost.x-st.cue.x,st.ghost.z-st.cue.z)
                XCTAssertLessThan(simd_length(a-b),0.000001)
                XCTAssertEqual(AngleSceneCalculator.horizontalDistance(st.cue,st.target),0.4,accuracy:0.000001)
                XCTAssertEqual(AngleSceneCalculator.horizontalDistance(st.target,pocket),0.4,accuracy:0.000001)
                let n=simd_normalize(SIMD2<Float>(pocket.x-st.target.x,pocket.z-st.target.z))
                let measured=Double(acos(max(-1,min(1,simd_dot(simd_normalize(b),n)))))*180/Double.pi
                XCTAssertEqual(measured,st.cut,accuracy:0.002)
                s.hideAllVisualization()
                s.updateCueStick(cueBallPosition:st.cue,aimDirection:SCNVector3(st.ghost.x-st.cue.x,0,st.ghost.z-st.cue.z))
                s.cueStick?.rootNode.isHidden=false
                SCNTransaction.flush();let shot=renderer.snapshot(atTime:time,with:canvas,antialiasingMode:.multisampling4X)
                let layouts=try (0..<3).map{try XCTUnwrap(plan(st,$0,selected[$0].0,selected[$0].1))}
                let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
                let result=UIGraphicsImageRenderer(size:canvas,format:format).image{ctx in
                    UIColor.black.setFill();ctx.fill(CGRect(origin:.zero,size:canvas));shot.draw(at:.zero)
                    let g=ctx.cgContext
                    func line(_ p:CGPoint,_ q:CGPoint,_ color:UIColor,dashed:Bool=false){g.setStrokeColor(color.cgColor);g.setLineWidth(3);g.setLineDash(phase:0,lengths:dashed ? [12,10]:[]);g.move(to:p);g.addLine(to:q);g.strokePath()}
                    line(project(st.target),project(pocket),.black,dashed:true)
                    line(project(st.guide),project(st.tail),.red,dashed:true)
                    line(project(st.cue),project(hit ?? aimEnd),.white)
                    if let hit {line(project(hit),project(aimEnd),.white,dashed:true)}
                    line(project(st.b),project(st.a),.cyan)
                    for p in [project(st.a),project(st.b)]{UIColor.red.setFill();UIBezierPath(ovalIn:CGRect(x:p.x-6,y:p.y-6,width:12,height:12)).fill()}
                    for id in 0..<3 {
                        let l=layouts[id]
                        for (p,q) in zip(l.path,l.path.dropFirst()){line(p,q,colors[id])}
                        (names[id] as NSString).draw(at:l.rect.origin,withAttributes:[.font:font,.foregroundColor:colors[id]])
                    }
                }
                XCTAssertEqual(camera.position.y-s.surfaceY,0.75,accuracy:0.000001)
                XCTAssertEqual(AngleSceneCalculator.horizontalDistance(camera.position,st.cue),0.35,accuracy:0.000001)
                let actualTarget=renderer.projectPoint(st.target)
                XCTAssertEqual(actualTarget.x,540,accuracy:0.05);XCTAssertEqual(actualTarget.y,960,accuracy:0.05)
                for p in [st.cue,st.target,pocket] {let q=project(p);XCTAssertGreaterThan(q.x,55);XCTAssertLessThan(q.x,1025);XCTAssertGreaterThan(q.y,90);XCTAssertLessThan(q.y,1830)}
                records.append(["frame":index,"time":time,"cutDegrees":measured,"clockwiseDegrees":st.rotation,
                                "cue":[st.cue.x,st.cue.y,st.cue.z],"target":[st.target.x,st.target.y,st.target.z],"pocket":[pocket.x,pocket.y,pocket.z],
                                "ghost":[st.ghost.x,st.ghost.y,st.ghost.z],"cueContact":[st.b.x,st.b.y,st.b.z],"targetContact":[st.a.x,st.a.y,st.a.z],
                                "camera":[camera.position.x,camera.position.y,camera.position.z],"targetPixel":[actualTarget.x,actualTarget.y],"aimRail":[aimEnd.x,aimEnd.y,aimEnd.z],"aimBlocked":hit != nil,
                                "parallelResidualM":simd_length(a-b),"labelRects":layouts.map{[$0.rect.minX,$0.rect.minY,$0.rect.width,$0.rect.height]}])
                if stills{try XCTUnwrap(result.pngData()).write(to:out.appendingPathComponent("frames/frame-\(index).png"))}
                else{try writer?.append(XCTUnwrap(result.cgImage))}
            }
            if index%120==0{print("TWO_PHASE \(index)/1080")}
            try await Task.sleep(nanoseconds:1_000_000)
        }
        try await writer?.finish()
        try JSONSerialization.data(withJSONObject:records,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent(stills ? "stills.json":"frames.json"))
        print("LABEL_LAYOUT \(selected)")
    }
}

extension AngleAimingVideoCaptureTests {
    func testParallelSinglePhaseRoom() async throws {
        let out=try outputDirectory(),env=ProcessInfo.processInfo.environment
        let final2K=(env["TEST_RUNNER_PARALLEL_FINAL_2K"] ?? env["PARALLEL_FINAL_2K"]) == "1" || FileManager.default.fileExists(atPath:out.appendingPathComponent(".final-2k").path)
        let renderScale:CGFloat=final2K ? 4.0/3.0:1
        let frameCount=final2K ? 900:1080
        let closeups=(env["TEST_RUNNER_PARALLEL_CLOSEUPS"] ?? env["PARALLEL_CLOSEUPS"]) == "1"
        let options=(env["TEST_RUNNER_PARALLEL_LABEL_OPTIONS"] ?? env["PARALLEL_LABEL_OPTIONS"]) == "1"
        let stills=(env["PARALLEL_STILLS"] ?? env["TEST_RUNNER_PARALLEL_STILLS"]) == "1"
        let vm=AngleDynamicViewModel();vm.setupScene();let s=vm.scene
        XCTAssertTrue(s.applyTableStyle(.charcoal,showsSights:true));s.applyClothColor(.green)
        s.setCameraMode(.perspective3D,animated:false)
        s.installReferenceRoom(style:.tournament)
        XCTAssertFalse(try XCTUnwrap(s.rootNode.childNode(withName:"reference_room",recursively:false)).isHidden)
        XCTAssertTrue(try XCTUnwrap(s.cueStick).applyStyle(.inkDragon))
        let r=AngleSceneCalculator.ballRadius,y=s.surfaceY+r
        let bearing=try XCTUnwrap(Float(env["TEST_RUNNER_PARALLEL_BEARING"] ?? env["PARALLEL_BEARING"] ?? ""))
        let ballDistance=Float(env["TEST_RUNNER_PARALLEL_DISTANCE"] ?? env["PARALLEL_DISTANCE"] ?? "0.50")!
        let pocket=AngleSceneCalculator.effectivePocketAimPoint(targetBall:SCNVector3(0,y,-0.23),pocketIndex:4,surfaceY:s.surfaceY)
        let camera=try XCTUnwrap(s.cameraNode)
        camera.position=SCNVector3(-0.10,s.surfaceY+3,pocket.z+0.40)
        camera.look(at:SCNVector3(-0.10,s.surfaceY,pocket.z+0.40),up:SCNVector3(0,0,-1),localFront:SCNVector3(0,0,-1))
        camera.camera!.usesOrthographicProjection=false;camera.camera!.fieldOfView=80;camera.camera!.projectionDirection = .vertical
        camera.camera!.orthographicScale=0.92;camera.camera!.zNear=0.01;camera.camera!.zFar=100
        let renderer=SCNRenderer(device:nil,options:nil);renderer.scene=s;renderer.pointOfView=camera
        renderer.autoenablesDefaultLighting=false;renderer.delegate=s.contactOcclusion
        s.cueStick?.rootNode.isHidden=true
        let canvas=CGSize(width:closeups ? 1200:1080,height:1920)
        let renderCanvas=CGSize(width:(closeups ? 1320:1080)*renderScale,height:1920*renderScale)
        let cropX:CGFloat=closeups ? 120:0
        let outputCanvas=CGSize(width:canvas.width*renderScale,height:canvas.height*renderScale)
        let writer=stills ? nil:try VideoWriter(url:out.appendingPathComponent(final2K ? "parallel-3d-room-0-90-15s-2k.mp4":"parallel-3d-room-0-90-18s.mp4"),size:outputCanvas,fps:60,averageBitRate:final2K ? 48_000_000:closeups ? 36_000_000:nil)
        struct State {
            let cue:SCNVector3,target:SCNVector3,ghost:SCNVector3,a:SCNVector3,b:SCNVector3,guide:SCNVector3,tail:SCNVector3
            let cut:Double,rotation:Double,orientation:Float
        }
        func state(_ index:Int)->State {
            let cut=90*Double(index)/Double(frameCount-1),rotation=0.0
            let angle=Float(cut*Double.pi/180),orientation=bearing*Float.pi/180
            func rotate(_ x:Float,_ z:Float)->SCNVector3{SCNVector3(pocket.x+x*cos(orientation)-z*sin(orientation),y,pocket.z+x*sin(orientation)+z*cos(orientation))}
            let length = -2*r*cos(angle)+sqrt(ballDistance*ballDistance-pow(2*r*sin(angle),2))
            let target=rotate(0,0.4),ghost=rotate(0,0.4+2*r),cue=rotate(-length*sin(angle),0.4+2*r+length*cos(angle))
            let n=simd_normalize(SIMD2<Float>(pocket.x-target.x,pocket.z-target.z))
            let a=SCNVector3(target.x-r*n.x,y,target.z-r*n.y),b=SCNVector3(cue.x+r*n.x,y,cue.z+r*n.y)
            let toRail=(-AngleSceneCalculator.innerWidth/2-cue.z)/n.y
            let guide=SCNVector3(cue.x+n.x*toRail,y,-AngleSceneCalculator.innerWidth/2)
            let tail=SCNVector3(cue.x-n.x*0.04,y,cue.z-n.y*0.04)
            return State(cue:cue,target:target,ghost:ghost,a:a,b:b,guide:guide,tail:tail,cut:cut,rotation:rotation,orientation:orientation)
        }
        _=renderer.snapshot(atTime:0,with:renderCanvas,antialiasingMode:.multisampling4X)
        var projectionTarget=state(0).target
        func setCamera(_ st:State) {
            let d=simd_normalize(SIMD2<Float>(st.ghost.x-st.cue.x,st.ghost.z-st.cue.z))
            camera.position=SCNVector3(st.cue.x-0.35*d.x,s.surfaceY+0.75,st.cue.z-0.35*d.y)
            camera.look(at:st.target,up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
            SCNTransaction.flush()
        }
        func project(_ v:SCNVector3)->CGPoint{let p=renderer.projectPoint(v);return CGPoint(x:CGFloat(p.x)/renderScale-cropX,y:canvas.height-CGFloat(p.y)/renderScale)}
        func rail(_ st:State)->SCNVector3 {
            AngleSceneCalculator.rayToInnerRail(from:st.cue,dir:SCNVector3(st.ghost.x-st.cue.x,0,st.ghost.z-st.cue.z),inset:0)
        }
        func cross(_ p:CGPoint,_ q:CGPoint,_ r:CGPoint)->CGFloat{(q.x-p.x)*(r.y-p.y)-(q.y-p.y)*(r.x-p.x)}
        func intersects(_ a:CGPoint,_ b:CGPoint,_ c:CGPoint,_ d:CGPoint)->Bool {
            let rx=b.x-a.x,ry=b.y-a.y,sx=d.x-c.x,sy=d.y-c.y
            let den=rx*sy-ry*sx
            if abs(den)<0.001{return false}
            let t=((c.x-a.x)*sy-(c.y-a.y)*sx)/den
            let u=((c.x-a.x)*ry-(c.y-a.y)*rx)/den
            let marginA=1/max(1,hypot(rx,ry)),marginB=1/max(1,hypot(sx,sy))
            return t>marginA && t<1-marginA && u>marginB && u<1-marginB
        }
        let font=UIFont.systemFont(ofSize:28,weight:.semibold)
        let names=["目标球接触点","母球接触点","接触点连线"]
        let colors:[UIColor]=[.red,.red,.cyan]
        let textSizes=names.map{($0 as NSString).size(withAttributes:[.font:font])}
        let states=(0..<frameCount).map(state)
        struct Layout {let rect:CGRect;let path:[CGPoint]}
        func plan(_ st:State,_ id:Int,_ offset:CGPoint,_ bend:Int)->Layout? {
            projectionTarget=st.target;setCamera(st)
            let ap=project(st.a),bp=project(st.b),cp=project(st.cue),tp=project(st.target)
            let anchor=id==0 ? ap:id==1 ? bp:CGPoint(x:(ap.x+bp.x)/2,y:(ap.y+bp.y)/2)
            let angle=CGFloat(st.orientation)
            let pos=CGPoint(x:anchor.x+offset.x*cos(angle)-offset.y*sin(angle),y:anchor.y+offset.x*sin(angle)+offset.y*cos(angle))
            if id==2 && cross(bp,ap,pos)>=0{return nil}
            let ts=textSizes[id],rect=CGRect(x:pos.x-ts.width/2,y:pos.y-ts.height/2,width:ts.width,height:ts.height)
            guard CGRect(x:28,y:50,width:1024,height:1820).contains(rect) else{return nil}
            func screenRadius(_ center:SCNVector3)->CGFloat {
                let right=camera.simdWorldTransform.columns.0
                let q=project(SCNVector3(center.x+r*right.x,center.y+r*right.y,center.z+r*right.z)),p=project(center)
                return hypot(q.x-p.x,q.y-p.y)
            }
            let ballPixels=screenRadius(st.cue)
            for p in [cp,tp,project(pocket)] {if rect.insetBy(dx:-12,dy:-12).intersects(CGRect(x:p.x-ballPixels,y:p.y-ballPixels,width:2*ballPixels,height:2*ballPixels)){return nil}}
            let end=CGPoint(x:min(max(anchor.x,rect.minX-8),rect.maxX+8),y:min(max(anchor.y,rect.minY-8),rect.maxY+8))
            var path=[anchor,end]
            if bend==1 {path=[anchor,CGPoint(x:anchor.x,y:end.y),end]}
            if bend==2 {path=[anchor,CGPoint(x:end.x,y:anchor.y),end]}
            if bend==3 {
                let g=project(st.guide),p=project(pocket)
                path=[anchor,CGPoint(x:g.x+35,y:min(g.y,p.y)-45),CGPoint(x:end.x,y:min(g.y,p.y)-45),end]
            }
            if bend==4 {path=[anchor,ap,CGPoint(x:end.x,y:ap.y),end]}
            if bend==5 {path=[]}
            func floorProject(_ p:SCNVector3)->CGPoint{project(SCNVector3(p.x,s.surfaceY+0.002,p.z))}
            let lines=[(floorProject(st.target),floorProject(pocket)),(floorProject(st.cue),floorProject(rail(st))),(floorProject(st.b),floorProject(st.a)),(floorProject(st.guide),floorProject(st.tail))]
            let corners=[CGPoint(x:rect.minX-5,y:rect.minY-5),CGPoint(x:rect.maxX+5,y:rect.minY-5),CGPoint(x:rect.maxX+5,y:rect.maxY+5),CGPoint(x:rect.minX-5,y:rect.maxY+5)]
            for (u,v) in lines {
                if rect.contains(u) || rect.contains(v){return nil}
                for j in 0..<4 {if intersects(u,v,corners[j],corners[(j+1)%4]){return nil}}
                for (p,q) in zip(path,path.dropFirst()){if intersects(p,q,u,v){return nil}}
            }
            // Avoid crossing the other ball, and leave a contact anchor outward.
            for (p,q) in zip(path,path.dropFirst()) {
                for step in 1..<20 {
                    let t=CGFloat(step)/20,point=CGPoint(x:p.x+(q.x-p.x)*t,y:p.y+(q.y-p.y)*t)
                    for (ball,radius) in [(cp,screenRadius(st.cue)),(tp,screenRadius(st.target))] {if hypot(point.x-ball.x,point.y-ball.y)<radius-2{return nil}}
                }
            }
            return Layout(rect:rect,path:path)
        }
        // One relative layout for the whole movie: no per-frame label jumps.
        var selected:[(CGPoint,Int)]=[]
        let samples=stride(from:0,to:frameCount,by:4).map{states[$0]}+[states[frameCount-1]]
        for id in 0..<3 {
            var candidates:[(CGPoint,Int,Double)]=[]
            for x in stride(from:-360,through:360,by:40) {for z in stride(from:-300,through:300,by:40) {
                if abs(x)+abs(z)<100 {continue}
                for bend in [0,1,2,5] {
                    let preference=(id==0 && x<0 || id==1 && x>0) ? 70.0:0.0
                    candidates.append((CGPoint(x:x,y:z),bend,hypot(Double(x),Double(z))+Double(bend)*100+preference))
                }
            }}
            candidates.sort{$0.2<$1.2}
            var best:(CGPoint,Int)?
            for c in candidates {
                var valid=true
                for st in samples {
                    guard let layout=plan(st,id,c.0,c.1) else{valid=false;break}
                    for previous in 0..<selected.count {
                        guard let other=plan(st,previous,selected[previous].0,selected[previous].1) else{valid=false;break}
                        if layout.rect.insetBy(dx:-10,dy:-10).intersects(other.rect){valid=false;break}
                        for (p,q) in zip(layout.path,layout.path.dropFirst()){for (u,v) in zip(other.path,other.path.dropFirst()){if intersects(p,q,u,v){valid=false}}}
                    }
                    if !valid{break}
                }
                if valid{best=(c.0,c.1);break}
            }
            selected.append(try XCTUnwrap(best,"No continuous label layout for \(names[id])"))
        }
        let detailCamera=SCNNode();detailCamera.camera=SCNCamera();detailCamera.camera!.usesOrthographicProjection=true;detailCamera.camera!.projectionDirection = .vertical;detailCamera.camera!.orthographicScale=0.04;detailCamera.camera!.wantsDepthOfField=false;detailCamera.camera!.zNear=0.01;detailCamera.camera!.zFar=10
        s.rootNode.addChildNode(detailCamera)
        let detailRenderer=SCNRenderer(device:nil,options:nil);detailRenderer.scene=s;detailRenderer.pointOfView=detailCamera;detailRenderer.autoenablesDefaultLighting=false;detailRenderer.delegate=s.contactOcclusion
        var teachingNodes:[SCNNode]=[]
        var records:[[String:Any]]=[]
        for index in 0..<frameCount {
            if stills && ![0,frameCount/4,frameCount/2-1,frameCount/2,frameCount*3/4,frameCount-1].contains(index){continue}
            try autoreleasepool {
                let st=states[index],time=Double(index)/60
                projectionTarget=st.target
                setCamera(st)
                let aimEnd=rail(st)
                let hit=AngleSceneCalculator.aimRayTargetEntry(from:st.cue,toward:aimEnd,target:st.target)
                try XCTUnwrap(s.cueBallNode).position=st.cue;try XCTUnwrap(vm.targetNode).position=st.target
                vm.selectPocket(at:4)
                XCTAssertEqual(s.pocketSelectionDescription,"5号袋：目标")
                for node in [s.ghostBallNode,s.strikeLineNode,s.pocketLineNode,s.contactDotNode,s.perpLineNode,s.angleArcNode,s.cueStick?.rootNode].compactMap({$0}){node.isHidden=true}
                let a=SIMD2<Float>(st.a.x-st.b.x,st.a.z-st.b.z),b=SIMD2<Float>(st.ghost.x-st.cue.x,st.ghost.z-st.cue.z)
                XCTAssertLessThan(simd_length(a-b),0.000001)
                XCTAssertEqual(AngleSceneCalculator.horizontalDistance(st.cue,st.target),ballDistance,accuracy:0.000001)
                XCTAssertEqual(AngleSceneCalculator.horizontalDistance(st.target,pocket),0.4,accuracy:0.000001)
                let n=simd_normalize(SIMD2<Float>(pocket.x-st.target.x,pocket.z-st.target.z))
                let measured=atan2(abs(Double(b.x)*Double(n.y)-Double(b.y)*Double(n.x)),Double(b.x)*Double(n.x)+Double(b.y)*Double(n.y))*180/Double.pi
                XCTAssertEqual(measured,st.cut,accuracy:0.002)
                XCTAssertLessThanOrEqual(abs(st.cue.z)+r,AngleSceneCalculator.innerWidth/2+0.000001)
                XCTAssertLessThanOrEqual(abs(st.cue.x)+r,AngleSceneCalculator.innerLength/2+0.000001)
                s.hideAllVisualization()
                s.updateCueStick(cueBallPosition:st.cue,aimDirection:SCNVector3(st.ghost.x-st.cue.x,0,st.ghost.z-st.cue.z))
                s.cueStick?.rootNode.isHidden=false
                teachingNodes.forEach{$0.removeFromParentNode()};teachingNodes=[]
                func floorLine(_ from:SCNVector3,_ to:SCNVector3,_ color:UIColor,_ dashed:Bool=false) {
                    let node=dashed ? s.addDashedLine(from:from,to:to,color:color,radius:0.0012,dash:0.018,gap:0.012,placement:.table,layer:.aiming):s.addLine(from:from,to:to,color:color,radius:0.0012,placement:.table,layer:.aiming)
                    teachingNodes.append(node)
                }
                floorLine(st.target,pocket,.black,true)
                floorLine(st.guide,st.tail,options ? UIColor(red:1,green:0.52,blue:0.06,alpha:1):.red,true)
                floorLine(st.cue,hit ?? aimEnd,.white)
                if let hit {floorLine(hit,aimEnd,.white,true)}
                let direction=simd_normalize(SIMD2<Float>(st.a.x-st.b.x,st.a.z-st.b.z))
                let connectorEnd=options ? SCNVector3(st.a.x+0.025*direction.x,st.a.y,st.a.z+0.025*direction.y):st.a
                floorLine(st.b,connectorEnd,.cyan)
                SCNTransaction.flush();let wideShot=renderer.snapshot(atTime:time,with:renderCanvas,antialiasingMode:.multisampling4X)
                let shot=UIImage(cgImage:try XCTUnwrap(wideShot.cgImage?.cropping(to:CGRect(origin:CGPoint(x:cropX*renderScale,y:0),size:outputCanvas))),scale:renderScale,orientation:.up)
                let layouts=try (0..<3).map{try XCTUnwrap(plan(st,$0,selected[$0].0,selected[$0].1))}
                let format=UIGraphicsImageRendererFormat();format.scale=renderScale;format.opaque=true
                var result=UIGraphicsImageRenderer(size:canvas,format:format).image{ctx in
                    UIColor.black.setFill();ctx.fill(CGRect(origin:.zero,size:canvas));shot.draw(at:.zero)
                    let g=ctx.cgContext
                    func line(_ p:CGPoint,_ q:CGPoint,_ color:UIColor,dashed:Bool=false){g.setStrokeColor(color.cgColor);g.setLineWidth(3);g.setLineDash(phase:0,lengths:dashed ? [12,10]:[]);g.move(to:p);g.addLine(to:q);g.strokePath()}
                    for p in [project(st.a),project(st.b)]{UIColor.red.setFill();UIBezierPath(ovalIn:CGRect(x:p.x-6,y:p.y-6,width:12,height:12)).fill()}
                    for id in 0..<3 {
                        let l=layouts[id]
                        for (p,q) in zip(l.path,l.path.dropFirst()){line(p,q,colors[id])}
                        (names[id] as NSString).draw(at:l.rect.origin,withAttributes:[.font:font,.foregroundColor:colors[id]])
                    }
                }
                XCTAssertEqual(camera.position.y-s.surfaceY,0.75,accuracy:0.000001)
                XCTAssertEqual(AngleSceneCalculator.horizontalDistance(camera.position,st.cue),0.35,accuracy:0.000001)
                let actualTarget=renderer.projectPoint(st.target)
                XCTAssertEqual(actualTarget.x/Float(renderScale)-Float(cropX),540,accuracy:0.05);XCTAssertEqual(actualTarget.y/Float(renderScale),960,accuracy:0.05)
                for p in [st.cue,st.target,pocket] {let q=project(p);XCTAssertGreaterThan(q.x,55);XCTAssertLessThan(q.x,1025);XCTAssertGreaterThan(q.y,90);XCTAssertLessThan(q.y,1830)}
                records.append(["frame":index,"time":time,"cutDegrees":measured,"clockwiseDegrees":st.rotation,
                                "cue":[st.cue.x,st.cue.y,st.cue.z],"target":[st.target.x,st.target.y,st.target.z],"pocket":[pocket.x,pocket.y,pocket.z],
                                "ghost":[st.ghost.x,st.ghost.y,st.ghost.z],"cueContact":[st.b.x,st.b.y,st.b.z],"targetContact":[st.a.x,st.a.y,st.a.z],
                                "pocketSelection":s.pocketSelectionDescription,"camera":[camera.position.x,camera.position.y,camera.position.z],"targetPixel":[actualTarget.x/Float(renderScale)-Float(cropX),actualTarget.y/Float(renderScale)],"aimRail":[aimEnd.x,aimEnd.y,aimEnd.z],"aimBlocked":hit != nil,
                                "parallelResidualM":simd_length(a-b),"labelRects":layouts.map{[$0.rect.minX,$0.rect.minY,$0.rect.width,$0.rect.height]}])
                if options {
                    @MainActor func floorPoint(_ p:SCNVector3)->CGPoint{project(SCNVector3(p.x,s.surfaceY+0.002,p.z))}
                    func mix(_ p:SCNVector3,_ q:SCNVector3,_ t:Float)->SCNVector3{SCNVector3(p.x+(q.x-p.x)*t,p.y+(q.y-p.y)*t,p.z+(q.z-p.z)*t)}
                    let guideDirection=simd_normalize(SIMD2<Float>(st.guide.x-st.cue.x,st.guide.z-st.cue.z))
                    let guideAnchor=SCNVector3(st.cue.x+5*r*guideDirection.x,s.surfaceY+0.002,st.cue.z+5*r*guideDirection.y)
                    let anchors=[floorPoint(mix(st.target,pocket,0.5)),project(st.a),floorPoint(mix(st.b,st.a,0.58)),project(st.b),floorPoint(mix(st.cue,st.ghost,0.62)),floorPoint(guideAnchor)]
                    let cuePixel=project(st.cue),targetPixel=project(st.target)
                    let middleY=(cuePixel.y+targetPixel.y)/2
                    var boxes:[CGRect]=[]
                    var detailShots:[UIImage]=[]
                    var signedOffsets:[Float]=[]
                    var detailPointOffsets:[Float]=[]
                    if closeups {
                        let d=simd_normalize(SIMD2<Float>(st.a.x-st.b.x,st.a.z-st.b.z)),right=SIMD2<Float>(-d.y,d.x)
                        teachingNodes.forEach{$0.isHidden=true};s.cueStick?.rootNode.isHidden=true
                        for (center,contact) in [(st.target,st.a),(st.cue,st.b)] {
                            detailCamera.position=SCNVector3(center.x,s.surfaceY+3,center.z)
                            detailCamera.look(at:center,up:SCNVector3(d.x,0,d.y),localFront:SCNVector3(0,0,-1))
                            SCNTransaction.flush()
                            detailShots.append(detailRenderer.snapshot(atTime:time,with:CGSize(width:960*renderScale,height:960*renderScale),antialiasingMode:.multisampling4X))
                            detailPointOffsets.append(simd_dot(SIMD2<Float>(contact.x-center.x,contact.z-center.z),d))
                            signedOffsets.append(simd_dot(SIMD2<Float>(center.x-st.b.x,center.z-st.b.z),right))
                        }
                        teachingNodes.forEach{$0.isHidden=false};s.cueStick?.rootNode.isHidden=false
                        XCTAssertEqual(signedOffsets[0],-signedOffsets[1],accuracy:0.000001)
                        XCTAssertLessThanOrEqual(signedOffsets[0],0.000001);XCTAssertGreaterThanOrEqual(signedOffsets[1],-0.000001)
                        XCTAssertEqual(r-abs(signedOffsets[0]),r-abs(signedOffsets[1]),accuracy:0.000001)
                        // Translate each crop so the same world line has one screen-space x.
                        let commonLineX:CGFloat=980
                        boxes=signedOffsets.enumerated().map{j,offset in
                            CGRect(x:commonLineX+CGFloat(offset)*3000-120,y:middleY+(j==0 ? -250:10),width:240,height:240)
                        }
                        let lineXs=boxes.enumerated().map{$0.element.midX-CGFloat(signedOffsets[$0.offset])*3000}
                        XCTAssertEqual(lineXs[0],lineXs[1],accuracy:0.001)
                        records[records.count-1]["insetLineScreenX"]=lineXs
                        records[records.count-1]["insetRects"]=boxes.map{[$0.minX,$0.minY,$0.width,$0.height]}
                        records[records.count-1]["insetSignedOffsetsM"]=signedOffsets
                        records[records.count-1]["insetCapThicknessM"]=signedOffsets.map{r-abs($0)}
                        records[records.count-1]["insetScalePixelsPerM"]=3000
                        records[records.count-1]["insetNativeRenderSize"]=[960*renderScale,960*renderScale]
                        records[records.count-1]["insetContactPixels"]=boxes.enumerated().map{j,box in [commonLineX,box.midY-CGFloat(detailPointOffsets[j])*3000]}
                        records[records.count-1]["guideAnnotationDistanceM"]=5*r
                        let teachingSegments=[(floorPoint(st.target),floorPoint(pocket)),(floorPoint(st.cue),floorPoint(aimEnd)),(floorPoint(st.b),floorPoint(connectorEnd)),(floorPoint(st.guide),floorPoint(st.tail))]
                        records[records.count-1]["teachingScreenSegments"]=teachingSegments.map{[[$0.0.x,$0.0.y],[$0.1.x,$0.1.y]]}

                    }
                    for variant in (stills && !closeups ? [1,2,3]:[1]) {
                        var option=parallelLabelOptions(shot:shot,anchors:anchors,cuePoint:project(st.b),targetPoint:project(st.a),pocketPoint:project(pocket),teaching:[(floorPoint(st.target),floorPoint(pocket)),(floorPoint(st.cue),floorPoint(aimEnd)),(floorPoint(st.b),floorPoint(connectorEnd)),(floorPoint(st.guide),floorPoint(st.tail))],variant:variant,reserved:boxes,smallPoints:closeups)
                        if closeups {
                            let composed=option
                            option=UIGraphicsImageRenderer(size:canvas,format:format).image{ctx in
                                composed.draw(at:.zero)
                                for j in 0..<2 {
                                    let box=boxes[j],g=ctx.cgContext
                                    g.saveGState();UIBezierPath(roundedRect:box,cornerRadius:18).addClip();ctx.cgContext.interpolationQuality = .high;detailShots[j].draw(in:box)
                                    let lineX=box.midX-CGFloat(signedOffsets[j])*3000
                                    g.setStrokeColor(UIColor.cyan.cgColor);g.setLineWidth(3);g.move(to:CGPoint(x:lineX,y:box.minY+8));g.addLine(to:CGPoint(x:lineX,y:box.maxY-8));g.strokePath()
                                    let dot=CGPoint(x:lineX,y:box.midY-CGFloat(detailPointOffsets[j])*3000)
                                    (j==0 ? UIColor.red:UIColor(red:1,green:0.52,blue:0.06,alpha:1)).setFill()
                                    UIBezierPath(ovalIn:CGRect(x:dot.x-4.5,y:dot.y-4.5,width:9,height:9)).fill()
                                    g.restoreGState()
                                    UIColor(white:1,alpha:0.65).setStroke();let border=UIBezierPath(roundedRect:box,cornerRadius:18);border.lineWidth=1.5;border.stroke()
                                }
                            }
                        }
                        if stills {try XCTUnwrap(option.pngData()).write(to:out.appendingPathComponent("frames/option-\(variant)-frame-\(index).png"))}
                        if variant==1 {result=option}
                    }
                }
                if stills{try XCTUnwrap(result.pngData()).write(to:out.appendingPathComponent("frames/frame-\(index).png"))}
                else{try writer?.append(XCTUnwrap(result.cgImage))}
            }
            if index%120==0{print("TWO_PHASE \(index)/\(frameCount)")}
            try await Task.sleep(nanoseconds:1_000_000)
        }
        try await writer?.finish()
        try JSONSerialization.data(withJSONObject:records,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent(stills ? "stills.json":"frames.json"))
        print("LABEL_LAYOUT \(selected)")
    }
}

extension AngleAimingVideoCaptureTests {
    private func parallelLabelOptions(shot:UIImage,anchors:[CGPoint],cuePoint:CGPoint,targetPoint:CGPoint,pocketPoint:CGPoint,teaching:[(CGPoint,CGPoint)],variant:Int,reserved:[CGRect]=[],smallPoints:Bool=false)->UIImage {
        let canvas=shot.size,orange=UIColor(red:1,green:0.52,blue:0.06,alpha:1)
        let titles=["进球线","目标球接触点","接触点连线","母球接触点","瞄准线","过母球中心\n平行于进球线"]
        let details=["","","","","",""]
        let colors:[UIColor]=[.white,.red,.cyan,orange,.white,orange]
        let font=UIFont.systemFont(ofSize:variant==1 ? 40:42,weight:.semibold)
        let small=UIFont.systemFont(ofSize:30,weight:.medium)
        let fixedA:[CGPoint]=[CGPoint(x:80,y:760),CGPoint(x:140,y:1020),CGPoint(x:90,y:1190),CGPoint(x:160,y:1550),CGPoint(x:740,y:1090),CGPoint(x:55,y:1740)]
        let fixedC:[CGPoint]=[CGPoint(x:55,y:830),CGPoint(x:55,y:1020),CGPoint(x:55,y:1220),CGPoint(x:55,y:1510),CGPoint(x:730,y:1190),CGPoint(x:55,y:1740)]
        var positions=fixedA
        if variant>=1 {
            positions=[CGPoint(x:max(35,anchors[0].x-310),y:anchors[0].y-100),CGPoint(x:targetPoint.x-360,y:targetPoint.y+60),CGPoint(x:anchors[2].x-380,y:anchors[2].y+25),CGPoint(x:cuePoint.x-330,y:cuePoint.y+100),CGPoint(x:anchors[4].x+95,y:anchors[4].y-60),CGPoint(x:55,y:1740)]
        }
        // Share the object-relative layout across styles for a fair comparison.
        let format=UIGraphicsImageRendererFormat();format.scale=shot.scale;format.opaque=true
        return UIGraphicsImageRenderer(size:canvas,format:format).image{ctx in
            shot.draw(at:.zero)
            let g=ctx.cgContext
            for (point,color) in [(targetPoint,UIColor.red),(cuePoint,orange)] {
                let radius:CGFloat=smallPoints ? 4.5:7
                color.setFill();UIBezierPath(ovalIn:CGRect(x:point.x-radius,y:point.y-radius,width:radius*2,height:radius*2)).fill()
            }
            var occupied:[CGRect]=reserved.map{$0.insetBy(dx:-12,dy:-12)},leaders:[(CGPoint,CGPoint)]=[]
            func crossing(_ a:CGPoint,_ b:CGPoint,_ c:CGPoint,_ d:CGPoint)->Bool {
                let rx=b.x-a.x,ry=b.y-a.y,sx=d.x-c.x,sy=d.y-c.y,den=rx*sy-ry*sx
                if abs(den)<0.001{return false}
                let t=((c.x-a.x)*sy-(c.y-a.y)*sx)/den,u=((c.x-a.x)*ry-(c.y-a.y)*rx)/den
                return t>0.015 && t<0.985 && u>0.015 && u<0.985
            }
            func cuts(_ a:CGPoint,_ b:CGPoint,_ r:CGRect)->Bool {
                let c=[CGPoint(x:r.minX,y:r.minY),CGPoint(x:r.maxX,y:r.minY),CGPoint(x:r.maxX,y:r.maxY),CGPoint(x:r.minX,y:r.maxY)]
                return r.contains(a) || r.contains(b) || (0..<4).contains{crossing(a,b,c[$0],c[($0+1)%4])}
            }
            for id in (smallPoints ? [5,0,2,4]:[5,1,0,2,3,4]) {
                let paragraph=NSMutableParagraphStyle();paragraph.lineSpacing=7
                let attr:[NSAttributedString.Key:Any]=[.font:font,.foregroundColor:colors[id],.paragraphStyle:paragraph]
                let width:CGFloat=id==5 ? 300:max((titles[id] as NSString).size(withAttributes:[.font:font]).width,(details[id] as NSString).size(withAttributes:[.font:small]).width)+4
                let height:CGFloat=id==5 ? 115:details[id].isEmpty ? 65:105
                let anchor=anchors[id]
                var best:(CGRect,[CGPoint],CGFloat)?
                for dx in stride(from:id==5 ? 0:-350,through:id==5 ? 0:350,by:25) {for dy in stride(from:id==5 ? 0:-350,through:id==5 ? 0:350,by:25) {
                    let r=CGRect(x:positions[id].x+CGFloat(dx),y:positions[id].y+CGFloat(dy),width:width,height:height)
                    if !CGRect(x:28,y:70,width:1024,height:1790).contains(r){continue}
                    let guardRect=r.insetBy(dx:-16,dy:-12)
                    if occupied.contains(where:{$0.intersects(guardRect)}){continue}
                    if [cuePoint,targetPoint,pocketPoint].contains(where:{guardRect.intersects(CGRect(x:$0.x-45,y:$0.y-45,width:90,height:90))}){continue}
                    if teaching.contains(where:{cuts($0.0,$0.1,guardRect)}){continue}
                    if leaders.contains(where:{cuts($0.0,$0.1,guardRect)}){continue}
                    let end=CGPoint(x:anchor.x<r.minX ? r.minX-10:anchor.x>r.maxX ? r.maxX+10:min(max(anchor.x,r.minX),r.maxX),y:anchor.y<r.minY ? r.minY-10:anchor.y>r.maxY ? r.maxY+10:anchor.y)
                    var routes=[[anchor,end],[anchor,CGPoint(x:end.x,y:anchor.y),end],[anchor,CGPoint(x:anchor.x,y:end.y),end]]
                    if id==5 {
                        let textBounds=(titles[id] as NSString).boundingRect(with:CGSize(width:width,height:height),options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:attr,context:nil)
                        let textCenterEnd=CGPoint(x:r.minX+ceil(textBounds.width)+10,y:r.minY+textBounds.height/2)
                        routes=[[anchor,textCenterEnd]]
                    }
                    for path in routes {
                        var penalty:CGFloat=0
                        for (a,b) in zip(path,path.dropFirst()) {
                            for line in teaching+leaders {if crossing(a,b,line.0,line.1){penalty+=100000}}
                            for box in occupied {if cuts(a,b,box){penalty+=100000}}
                        }
                        let length=zip(path,path.dropFirst()).reduce(CGFloat(0)){$0+hypot($1.0.x-$1.1.x,$1.0.y-$1.1.y)}
                        let proximity:CGFloat=id==1 ? max(0,abs(r.minY-anchor.y)-100)*1000:0
                        let score=penalty+proximity+hypot(CGFloat(dx),CGFloat(dy))+length*0.3+CGFloat(path.count)*5
                        if best == nil || score<best!.2 {best=(r,path,score)}
                    }
                }}
                guard let chosen=best else{XCTFail("No option layout for \(id), variant \(variant)");continue}
                let rect=chosen.0,path=chosen.1
                occupied.append(rect.insetBy(dx:-12,dy:-10));leaders.append(contentsOf:zip(path,path.dropFirst()).map{($0.0,$0.1)})
                if variant != 1 {
                    UIColor(white:0.025,alpha:variant==3 ? 0.76:0.58).setFill()
                    UIBezierPath(roundedRect:rect.insetBy(dx:-12,dy:-10),cornerRadius:12).fill()
                }
                (titles[id] as NSString).draw(in:rect,withAttributes:attr)
                if !details[id].isEmpty {(details[id] as NSString).draw(at:CGPoint(x:rect.minX,y:rect.minY+55),withAttributes:[.font:small,.foregroundColor:UIColor.white])}
                g.setStrokeColor(colors[id].cgColor);g.setLineWidth(2);g.setLineDash(phase:0,lengths:[])
                g.move(to:path[0]);for p in path.dropFirst(){g.addLine(to:p)};g.strokePath()
                colors[id].setFill();UIBezierPath(ovalIn:CGRect(x:anchor.x-4,y:anchor.y-4,width:8,height:8)).fill()
            }
        }
    }
}

@MainActor
final class RailPlayerCameraTests: XCTestCase {
    func testAllQuadrantsPlaceEyesOutsideRailAndKeepHeightIndependentOfCuePosition() throws {
        for cue in [SCNVector3(0, 0.828575, 0), SCNVector3(1.2, 0.828575, 0.6),
                    SCNVector3(-1.2, 0.828575, -0.6)] {
            for index in 0..<16 {
                let angle = Float(index) * .pi / 8
                let aim = SCNVector3(cos(angle), 0, sin(angle))
                for view in [CameraRig.PlayerView.firstPerson, .thirdPerson] {
                    let pose = try XCTUnwrap(CameraRig.playerPose(view: view, cue: cue, aim: aim,
                        surfaceY: 0.8, halfLength: 1.4055, halfWidth: 0.7995))
                    let eyeX = pose.pivot.x + cos(pose.yaw) * pose.radius
                    let eyeZ = pose.pivot.z + sin(pose.yaw) * pose.radius
                    XCTAssertTrue(abs(eyeX) > 1.4055 || abs(eyeZ) > 0.7995)
                    XCTAssertLessThan((eyeX - cue.x) * aim.x + (eyeZ - cue.z) * aim.z, 0)
                    XCTAssertEqual(pose.height, view == .firstPerson ? 0.16 : 0.84, accuracy: 0.0001)
                    XCTAssertLessThan(pose.pitch, 0)
                }
            }
        }
        XCTAssertNil(CameraRig.playerPose(view: .firstPerson, cue: SCNVector3Zero,
            aim: SCNVector3Zero, surfaceY: 0.8, halfLength: 1.4, halfWidth: 0.8))
    }

    func testFirstPersonTransitionRetainsExactPoseAndManualTakeoverDoesNotResumeIt() throws {
        let node = SCNNode()
        node.camera = SCNCamera()
        let rig = CameraRig(cameraNode: node, tableSurfaceY: 0.8, config: .dailyClearance)
        rig.usesRailCameraControls = true
        let cue = SCNVector3(0.3, 0.828575, 0.2), aim = SCNVector3(1, 0, 0)
        XCTAssertTrue(rig.enterPlayerView(.firstPerson, cue: cue, aim: aim))
        for _ in 0..<80 { rig.update(deltaTime: 1 / 60) }
        XCTAssertEqual(node.position.y, 0.96, accuracy: 0.001)
        let before = node.simdTransform
        for _ in 0..<80 { rig.update(deltaTime: 1 / 60) }
        XCTAssertEqual(node.simdTransform, before)
        XCTAssertTrue(rig.isPlayerViewFor(cue: cue, aim: aim))
        let saved = rig.capturePerspectiveState()
        rig.enterPlayerView(.thirdPerson, cue: cue, aim: aim)
        rig.update(deltaTime: 0.2)
        let live = node.position
        rig.handleHorizontalSwipe(delta: 0)
        rig.update(deltaTime: 1 / 60)
        XCTAssertLessThan((node.position - live).length(), 0.001)
        XCTAssertNil(rig.playerView)
        XCTAssertFalse(rig.isTransitioning)
        rig.restorePerspectiveState(saved)
        XCTAssertEqual(rig.playerView, .firstPerson)
        XCTAssertEqual(node.position.y, 0.96, accuracy: 0.001)
    }

    func testRailOpticalZoomInspectsFarBallsWithoutCrossingCushion() {
        let node = SCNNode(); node.camera = SCNCamera()
        let rig = CameraRig(cameraNode: node, tableSurfaceY: 0.8)
        rig.usesRailCameraControls = true
        rig.enterPlayerView(.firstPerson, cue: SCNVector3(0, 0.828575, 0), aim: SCNVector3(1, 0, 0))
        rig.update(deltaTime: 2)
        let eye = node.position
        rig.handlePinch(scale: 100)
        rig.snapToTarget()
        XCTAssertEqual(node.camera?.fieldOfView, 18)
        XCTAssertLessThan((node.position - eye).length(), 0.001)
        rig.handlePinch(scale: 0.01)
        rig.snapToTarget()
        XCTAssertEqual(node.camera?.fieldOfView, 42)
    }
}

// V015: opt-in native still; keep V013's camera and label treatment.
extension AngleAimingVideoCaptureTests {
    private func makePipeScene() throws -> AngleDynamicViewModel {
        let vm = AngleDynamicViewModel(); vm.setupScene()
        let scene = vm.scene
        XCTAssertTrue(scene.applyTableStyle(.charcoal, showsSights: true))
        scene.applyClothColor(.green)
        scene.setCameraMode(.perspective3D, animated: false)
        scene.installReferenceRoom(style: .tournament)
        XCTAssertTrue(try XCTUnwrap(scene.cueStick).applyStyle(.inkDragon))
        return vm
    }

    func testPipeAimingPreview() throws {
        let out = try outputDirectory(), vm = try makePipeScene()
        let (image,record) = try pipeFrame(vm:vm,degrees:44.5)
        try XCTUnwrap(image.pngData()).write(to:out.appendingPathComponent("pipe-44.5.png"))
        try JSONSerialization.data(withJSONObject:record,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("geometry.json"))
    }

    func testPipeAimingDarkRedPreviews() throws {
        let out = try outputDirectory()
        let variants: [(String, UIColor)] = [
            ("A-muted-red", UIColor(red: 0.72, green: 0.10, blue: 0.12, alpha: 1)),
            ("B-deep-red", UIColor(red: 0.55, green: 0.08, blue: 0.10, alpha: 1))
        ]
        for (name, color) in variants {
            let vm = try makePipeScene()
            let (image, data) = try pipeFrame(vm: vm, degrees: 44.5, ghostColor: color, blackPot: true)
            try XCTUnwrap(image.pngData()).write(to: out.appendingPathComponent("\(name).png"))
            var record = data; record["variant"] = name; record["potColor"] = "black"; record["labelColor"] = "white"
            try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys]).write(to: out.appendingPathComponent("\(name).json"))
        }
    }

    func testPipeAimingVideo() async throws {
        let out = try outputDirectory(), vm = try makePipeScene()
        let keyframes = FileManager.default.fileExists(atPath:out.appendingPathComponent(".keyframes").path)
        let selected = [0,225,449,450,675,899]
        let writer = keyframes ? nil : try VideoWriter(url:out.appendingPathComponent("pipe-aiming-0-89-2k60-15s.mp4"),size:CGSize(width:1600,height:2560),fps:60,averageBitRate:48_000_000)
        var records: [[String:Any]] = []
        for index in 0..<900 {
            if keyframes && !selected.contains(index) {continue}
            try autoreleasepool {
                let degrees = 89*Double(index)/899
                let (image,data) = try pipeFrame(vm:vm,degrees:degrees,ghostColor:UIColor(red:0.72,green:0.10,blue:0.12,alpha:1),blackPot:true)
                var record = data; record["frame"] = index;record["time"] = Double(index)/60;record["stillOnly"] = keyframes;record["ghostRingColor"] = "A-muted-red";record["potColor"] = "black";record["labelColor"] = "white"
                records.append(record)
                if selected.contains(index) {try XCTUnwrap(image.pngData()).write(to:out.appendingPathComponent("frames/frame-\(index).png"))}
                try writer?.append(XCTUnwrap(image.cgImage))
            }
            if index%60 == 0 {print("PIPE_FRAME \(index)/900")}
            try await Task.sleep(nanoseconds:1_000_000)
        }
        try await writer?.finish()
        try JSONSerialization.data(withJSONObject:records,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent(keyframes ? "keyframes.json":"frames.json"))
    }

    private func pipeFrame(vm:AngleDynamicViewModel,degrees:Double,ghostColor:UIColor = .red,blackPot:Bool = false) throws -> (UIImage,[String:Any]) {
        let scene = vm.scene
        scene.rootNode.childNodes.filter { $0.name == "tableProjectedAssist" || $0.name == "pipeDetailCamera" || $0.name == "pipeDashedCenter" }.forEach { $0.removeFromParentNode() }
        let r = AngleSceneCalculator.ballRadius, y = scene.surfaceY + r
        let pocket = AngleSceneCalculator.effectivePocketAimPoint(targetBall: SCNVector3(0,y,-0.23), pocketIndex: 4, surfaceY: scene.surfaceY)
        let angle = Float(degrees * Double.pi / 180)
        let length = -2*r*cos(angle) + sqrt(0.5*0.5-pow(2*r*sin(angle),2))
        let target = SCNVector3(pocket.x,y,pocket.z+0.4)
        let ghost = SCNVector3(target.x,y,target.z+2*r)
        let cue = SCNVector3(ghost.x-length*sin(angle),y,ghost.z+length*cos(angle))
        let contact = SCNVector3(target.x,y,target.z+r)
        let direction = simd_normalize(SIMD3<Float>(ghost.x-cue.x,0,ghost.z-cue.z))
        vm.selectPocket(at: 4)
        scene.clearPocketHighlights()
        XCTAssertEqual(scene.pocketSelectionDescription,"未选择目标袋")
        try XCTUnwrap(scene.cueBallNode).position = cue
        try XCTUnwrap(vm.targetNode).position = target
        scene.hideAllVisualization()
        scene.updateCueStick(cueBallPosition: cue, aimDirection: SCNVector3(direction))
        scene.cueStick?.rootNode.isHidden = false
        let camera = try XCTUnwrap(scene.cameraNode)
        camera.camera!.usesOrthographicProjection = false
        camera.camera!.fieldOfView = 80
        camera.camera!.projectionDirection = .vertical
        camera.camera!.zNear = 0.01; camera.camera!.zFar = 100
        camera.position = SCNVector3(cue.x-0.35*direction.x,scene.surfaceY+0.75,cue.z-0.35*direction.z)
        camera.look(at: target, up: SCNVector3(0,1,0), localFront: SCNVector3(0,0,-1))
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene; renderer.pointOfView = camera
        renderer.autoenablesDefaultLighting = false; renderer.delegate = scene.contactOcclusion
        let gold = blackPot ? UIColor.black : UIColor(red: 1, green: 0.68, blue: 0.12, alpha: 1)
        // Miter the two ball-width strips at their shared centerline junction G.
        // Each boundary terminates at its corresponding boundary intersection.
        let potDirection = simd_normalize(SIMD3<Float>(pocket.x-ghost.x,0,pocket.z-ghost.z))
        let aimSide = SIMD3<Float>(-direction.z,0,direction.x)
        let potSide = SIMD3<Float>(-potDirection.z,0,potDirection.x)
        let jointNormal = simd_normalize(direction+potDirection)
        let miter = (aimSide+potSide)*r/(1+simd_dot(aimSide,potSide))
        let junction = SIMD3<Float>(ghost.x,ghost.y,ghost.z)
        let aimEnd = ghost, potStart = ghost
        var clothY: Float = scene.surfaceY
        func pipe(_ a: SCNVector3, _ b: SCNVector3, color: UIColor, incoming: Bool) throws {
            let u = simd_normalize(SIMD3<Float>(b.x-a.x,0,b.z-a.z))
            let side = SIMD3<Float>(-u.z,0,u.x)
            let extensionLength: Float = 0.15
            let extendedA = incoming ? a : SCNVector3(a.x-u.x*extensionLength,a.y,a.z-u.z*extensionLength)
            let extendedB = incoming ? SCNVector3(b.x+u.x*extensionLength,b.y,b.z+u.z*extensionLength) : b
            let fill = scene.addLine(from:extendedA,to:extendedB,color:color.withAlphaComponent(0.20),radius:r,placement:.table,layer:incoming ? .reference:.fill)
            let oldGeometry = try XCTUnwrap(fill.geometry)
            let source = try XCTUnwrap(oldGeometry.sources(for:.vertex).first)
            XCTAssertEqual(source.bytesPerComponent,4)
            let vertices: [SIMD3<Float>] = source.data.withUnsafeBytes { raw in
                (0..<source.vectorCount).map { index in
                    let offset = source.dataOffset+index*source.dataStride
                    return SIMD3<Float>(raw.loadUnaligned(fromByteOffset:offset,as:Float.self),raw.loadUnaligned(fromByteOffset:offset+4,as:Float.self),raw.loadUnaligned(fromByteOffset:offset+8,as:Float.self))
                }
            }
            let sign: Float = incoming ? -1:1
            func distance(_ v: SIMD3<Float>) -> Float {sign*simd_dot(v-junction,jointNormal)}
            var clipped: [SCNVector3] = []
            for index in stride(from:0,to:vertices.count,by:3) {
                let triangle = Array(vertices[index..<index+3])
                var polygon: [SIMD3<Float>] = []
                for edge in 0..<3 {
                    let p = triangle[edge], q = triangle[(edge+1)%3]
                    let dp = distance(p), dq = distance(q)
                    if dp >= 0 {polygon.append(p)}
                    if (dp >= 0) != (dq >= 0) {polygon.append(p+(q-p)*(dp/(dp-dq)))}
                }
                if polygon.count >= 3 {
                    for j in 1..<polygon.count-1 {clipped += [SCNVector3(polygon[0]),SCNVector3(polygon[j]),SCNVector3(polygon[j+1])]}
                }
            }
            XCTAssertFalse(clipped.isEmpty)
            for v in clipped {XCTAssertGreaterThanOrEqual(distance(SIMD3<Float>(v.x,v.y,v.z)),-0.000001)}
            let geometry = SCNGeometry(sources:[SCNGeometrySource(vertices:clipped)],elements:[SCNGeometryElement(indices:(0..<clipped.count).map(Int32.init),primitiveType:.triangles)])
            geometry.materials = oldGeometry.materials;fill.geometry = geometry
            let bounds = fill.boundingBox
            XCTAssertEqual(bounds.min.y,bounds.max.y,accuracy:0.00001)
            clothY = bounds.min.y
            for edgeSign: Float in [-1,1] {
                let joint = junction+miter*edgeSign
                let endpoint = incoming ? SIMD3<Float>(a.x,a.y,a.z)+side*r*edgeSign : SIMD3<Float>(b.x,b.y,b.z)+side*r*edgeSign
                _ = scene.addLine(from:SCNVector3(endpoint),to:SCNVector3(joint),color:color,radius:0.0005,placement:.table,layer:.aiming)
                XCTAssertEqual(abs(simd_dot(joint-junction,aimSide)),r,accuracy:0.000001)
                XCTAssertEqual(abs(simd_dot(joint-junction,potSide)),r,accuracy:0.000001)
            }
        }
        try pipe(potStart,pocket,color:gold,incoming:false)
        try pipe(cue,aimEnd,color:.white,incoming:true)
        func floor(_ p: SCNVector3) -> SCNVector3 {SCNVector3(p.x,clothY,p.z)}
        scene.addDashedLine(from: potStart, to: pocket, color: .black, radius: 0.0008, dash: 0.018, gap: 0.012, placement: .table, layer: .aiming).name = "pipeDashedCenter"
        _ = scene.addLine(from: cue, to: aimEnd, color: .white, radius: 0.0006, placement: .table, layer: .aiming)
        let ghostRing = try XCTUnwrap(scene.ghostBallNode)
        ghostRing.position = SCNVector3(ghost.x,clothY+r,ghost.z)
        ghostRing.isHidden = false
        for segment in ghostRing.childNodes where segment.name != "ghostAimDot" {
            segment.geometry?.materials.forEach { $0.diffuse.contents = ghostColor }
        }
        ghostRing.childNode(withName:"ghostAimDot",recursively:true)?.isHidden = true
        XCTAssertFalse(ghostRing.isHidden)
        XCTAssertTrue(try XCTUnwrap(ghostRing.childNode(withName:"ghostAimDot",recursively:true)).isHidden)
        XCTAssertEqual(ghostRing.childNodes.filter { !$0.isHidden }.count,16)
        let canvas = CGSize(width:1200,height:1920), scale: CGFloat = 4/3
        let renderSize = CGSize(width:1760,height:2560)
        SCNTransaction.flush()
        _ = renderer.snapshot(atTime:0,with:renderSize,antialiasingMode:.multisampling4X)
        let wide = renderer.snapshot(atTime:0,with:renderSize,antialiasingMode:.multisampling4X)
        let shot = UIImage(cgImage:try XCTUnwrap(wide.cgImage?.cropping(to:CGRect(x:160,y:0,width:1600,height:2560))),scale:scale,orientation:.up)
        func project(_ p: SCNVector3) -> CGPoint {
            let v = renderer.projectPoint(p)
            return CGPoint(x:CGFloat(v.x)/scale-120,y:1920-CGFloat(v.y)/scale)
        }
        let detailCamera = SCNNode(); detailCamera.name = "pipeDetailCamera"; detailCamera.camera = SCNCamera()
        detailCamera.camera!.usesOrthographicProjection = true
        detailCamera.camera!.orthographicScale = 0.080
        detailCamera.camera!.projectionDirection = .vertical
        detailCamera.camera!.zNear = 0.01; detailCamera.camera!.zFar = 10
        detailCamera.position = SCNVector3(contact.x,scene.surfaceY+3,contact.z)
        detailCamera.look(at:contact,up:SCNVector3(direction),localFront:SCNVector3(0,0,-1))
        scene.rootNode.addChildNode(detailCamera)
        let detailRenderer = SCNRenderer(device:nil,options:nil)
        detailRenderer.scene = scene; detailRenderer.pointOfView = detailCamera
        detailRenderer.autoenablesDefaultLighting = false; detailRenderer.delegate = scene.contactOcclusion
        SCNTransaction.flush()
        let detail = detailRenderer.snapshot(atTime:0,with:CGSize(width:1440,height:1440),antialiasingMode:.multisampling4X)
        let detailPoint = detailRenderer.projectPoint(contact)
        XCTAssertEqual(detailPoint.x,720,accuracy:0.2); XCTAssertEqual(detailPoint.y,720,accuracy:0.2)
        let inset = CGRect(x:859,y:644,width:306,height:306)
        let cueInset = CGRect(x:859,y:970,width:306,height:306)
        let upperAxisX = CGFloat(detailRenderer.projectPoint(ghost).x)/1440*inset.width+inset.minX
        // Keep the same transverse camera offset from the aiming axis, so all
        // three pipe lines align across the two equally scaled crops.
        let transverseOffset = simd_dot(SIMD3<Float>(contact.x-ghost.x,0,contact.z-ghost.z),aimSide)
        let cueFocus = SCNVector3(cue.x+aimSide.x*transverseOffset,y,cue.z+aimSide.z*transverseOffset)
        detailCamera.position = SCNVector3(cueFocus.x,scene.surfaceY+3,cueFocus.z)
        detailCamera.look(at:cueFocus,up:SCNVector3(direction),localFront:SCNVector3(0,0,-1))
        SCNTransaction.flush()
        let cueDetail = detailRenderer.snapshot(atTime:0,with:CGSize(width:1440,height:1440),antialiasingMode:.multisampling4X)
        let lowerAxisX = CGFloat(detailRenderer.projectPoint(cue).x)/1440*cueInset.width+cueInset.minX
        XCTAssertEqual(upperAxisX,lowerAxisX,accuracy:0.02)
        XCTAssertEqual(inset.size,cueInset.size)
        XCTAssertEqual((inset.minY+cueInset.maxY)/2,canvas.height/2,accuracy:0.001)
        let format = UIGraphicsImageRendererFormat(); format.scale = scale; format.opaque = true
        let image = UIGraphicsImageRenderer(size:canvas,format:format).image { ctx in
            UIColor.black.setFill();ctx.fill(CGRect(origin:.zero,size:canvas));shot.draw(at:.zero)
            let g = ctx.cgContext
            func label(_ text: String, position: CGPoint, anchor: CGPoint, color: UIColor) {
                let font = UIFont.systemFont(ofSize:40,weight:.semibold)
                let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 7
                let attributes: [NSAttributedString.Key:Any] = [.font:font,.foregroundColor:color,.paragraphStyle:paragraph]
                let bounds = (text as NSString).boundingRect(with:CGSize(width:450,height:180),options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:attributes,context:nil)
                let rect = CGRect(origin:position,size:CGSize(width:ceil(bounds.width)+2,height:ceil(bounds.height)))
                (text as NSString).draw(in:rect,withAttributes:attributes)
                let end = CGPoint(x:anchor.x>rect.midX ? rect.maxX+10:rect.minX-10,y:rect.midY)
                g.setStrokeColor(color.cgColor);g.setLineWidth(2);g.move(to:end);g.addLine(to:anchor);g.strokePath()
                color.setFill();UIBezierPath(ovalIn:CGRect(x:anchor.x-3,y:anchor.y-3,width:6,height:6)).fill()
            }
            func midpoint(_ a: SCNVector3,_ b: SCNVector3,_ t: Float) -> SCNVector3 {SCNVector3(a.x+(b.x-a.x)*t,a.y+(b.y-a.y)*t,a.z+(b.z-a.z)*t)}
            label("进球管道",position:CGPoint(x:70,y:795),anchor:project(floor(midpoint(target,pocket,0.5))),color:blackPot ? .white : gold)
            label("瞄准管道",position:CGPoint(x:100,y:1240),anchor:project(floor(midpoint(cue,ghost,0.50))),color:.white)
            let side = SIMD3<Float>(-direction.z,0,direction.x)
            let anchor = midpoint(cue,ghost,0.23)
            label("管道宽度\n等于球直径",position:CGPoint(x:55,y:1720),anchor:project(floor(SCNVector3(anchor.x-r*side.x,anchor.y,anchor.z-r*side.z))),color:.white)
            for (box,shot) in [(inset,detail),(cueInset,cueDetail)] {
                g.saveGState();UIBezierPath(roundedRect:box,cornerRadius:18).addClip()
                g.interpolationQuality = .high; shot.draw(in:box)
                g.restoreGState()
                UIColor(white:1,alpha:0.65).setStroke();let border=UIBezierPath(roundedRect:box,cornerRadius:18);border.lineWidth=1.5;border.stroke()
            }
        }
        XCTAssertEqual(image.cgImage?.width,1600);XCTAssertEqual(image.cgImage?.height,2560)
        XCTAssertEqual(AngleSceneCalculator.horizontalDistance(cue,target),0.5,accuracy:0.000001)
        XCTAssertEqual(AngleSceneCalculator.horizontalDistance(ghost,target),2*r,accuracy:0.000001)
        XCTAssertEqual(AngleSceneCalculator.horizontalDistance(contact,target),r,accuracy:0.000001)
        XCTAssertEqual(AngleSceneCalculator.horizontalDistance(contact,ghost),r,accuracy:0.000001)
        let measured = atan2(abs(direction.x),-direction.z)*180/Float.pi
        XCTAssertEqual(measured,Float(degrees),accuracy:0.001)
        let record: [String:Any] = ["cutDegrees":measured,"plannedRange":[0,89],"size":[1600,2560],"ballRadiusM":r,"cue":[cue.x,cue.y,cue.z],"target":[target.x,target.y,target.z],"ghost":[ghost.x,ghost.y,ghost.z],"contact":[contact.x,contact.y,contact.z],"insetRect":[inset.minX,inset.minY,inset.width,inset.height],"cameraHeightM":0.75,"cameraBackM":0.35,"stillOnly":true,"pipePlacement":"cloth","pipeClothY":clothY,"aimEnd":[aimEnd.x,aimEnd.y,aimEnd.z],"potStart":[potStart.x,potStart.y,potStart.z],"pipeWidthM":2*r,"insetOrthographicScale":0.080,"ghostRingVisible":true,"contactDotVisible":false,"cueInsetRect":[cueInset.minX,cueInset.minY,cueInset.width,cueInset.height],"insetAxisX":[upperAxisX,lowerAxisX],"insetGroupMidY":(inset.minY+cueInset.maxY)/2]
        return (image,record)
    }
}

@MainActor
final class RecommendedShotCameraTests: XCTestCase {
    private func configuredModel() throws -> PositionPlayViewModel {
        let vm = PositionPlayViewModel()
        vm.scene.configureDailyClearanceRendering()
        vm.usesAutomaticPocketFallback = true
        vm.usesDailyShotRanking = true
        vm.setupScene()
        vm.legalAimTargets = { _ in ["_2"] }
        vm.loadBoard(BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.6, y: 0.35),
            "_1": CanvasPoint(x: 0.3, y: 0.15),
            "_2": CanvasPoint(x: 0.7, y: 0.15)
        ]))
        vm.cameraMode = .perspective3D
        vm.enablePlayerCameraControls()
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        rig.usesTwoViewCameraControls = true
        rig.viewportSize = CGSize(width: 874, height: 402)
        rig.setTwoViewReadableInsets(UIEdgeInsets(top: 44, left: 116, bottom: 24, right: 116))
        return vm
    }

    private func awaitSolution(_ vm: PositionPlayViewModel) async throws {
        let deadline = Date().addingTimeInterval(10)
        while (vm.isComputing || vm.currentPlayerAim == nil), Date() < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertFalse(vm.isComputing, vm.statusText)
        XCTAssertNotNil(vm.currentPlayerAim, vm.statusText)
        XCTAssertTrue(vm.isFeasible, vm.statusText)
    }

    private func settle(_ rig: CameraRig) {
        for _ in 0..<180 { rig.update(deltaTime: 1 / 60) }
    }

    func testNewRecommendationEntersLatestShotThirdPersonOnlyAfterSolve() async throws {
        let vm = try configuredModel()
        defer { vm.cancelDailyAttempt() }
        vm.legalAimTargets = { _ in ["_1"] }
        vm.refreshLegalAimSelection()
        try await awaitSolution(vm)
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        settle(rig)
        let count = vm.twoViewAutomaticThirdPersonEntryCount
        XCTAssertGreaterThan(count, 0)
        vm.requestPlayerView(.firstPerson)
        settle(rig)
        XCTAssertEqual(rig.twoViewMode, .firstPerson)
        vm.legalAimTargets = { _ in ["_2"] }
        vm.refreshLegalAimSelection()
        XCTAssertEqual(rig.twoViewMode, .firstPerson, "Do not enter using the previous prediction")
        try await awaitSolution(vm)
        settle(rig)
        XCTAssertEqual(vm.selectedTargetKey, "_2")
        XCTAssertEqual(rig.twoViewMode, .thirdPerson)
        XCTAssertEqual(vm.twoViewAutomaticThirdPersonEntryCount, count + 1)
        let aim = try XCTUnwrap(vm.currentPlayerAim)
        let forward = try XCTUnwrap(rig.twoViewSnapshot).pose.forward
        let horizontal = SIMD2(forward.x, forward.z)
        XCTAssertGreaterThan(simd_dot(simd_normalize(horizontal), simd_normalize(SIMD2(aim.x, aim.z))), 0.9999)
    }

    func testPowerRecomputeDoesNotRepeatedlyTakeOverFirstPerson() async throws {
        let vm = try configuredModel()
        defer { vm.cancelDailyAttempt() }
        vm.legalAimTargets = { _ in ["_1"] }
        vm.refreshLegalAimSelection()
        try await awaitSolution(vm)
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        settle(rig)
        vm.requestPlayerView(.firstPerson)
        settle(rig)
        let count = vm.twoViewAutomaticThirdPersonEntryCount
        vm.velocity += 0.2
        try await awaitSolution(vm)
        settle(rig)
        XCTAssertEqual(rig.twoViewMode, .firstPerson)
        XCTAssertEqual(vm.twoViewAutomaticThirdPersonEntryCount, count)
        vm.refreshLegalAimSelection()
        try await awaitSolution(vm)
        XCTAssertEqual(vm.twoViewAutomaticThirdPersonEntryCount, count)
    }

    func testExplicitViewSelectionSupersedesPendingRecommendation() async throws {
        let vm = try configuredModel()
        defer { vm.cancelDailyAttempt() }
        vm.legalAimTargets = { _ in ["_1"] }
        vm.refreshLegalAimSelection()
        try await awaitSolution(vm)
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        settle(rig)
        let count = vm.twoViewAutomaticThirdPersonEntryCount
        vm.legalAimTargets = { _ in ["_2"] }
        vm.refreshLegalAimSelection()
        vm.requestPlayerView(.firstPerson)
        try await awaitSolution(vm)
        settle(rig)
        XCTAssertEqual(vm.selectedTargetKey, "_2")
        XCTAssertEqual(rig.twoViewMode, .firstPerson)
        XCTAssertEqual(vm.twoViewAutomaticThirdPersonEntryCount, count)
    }
}

@MainActor
final class DailyShotCameraTests: XCTestCase {
    let viewport = CGSize(width: 874, height: 402)

    private var coverageAuditDirectory: URL {
        URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/daily-camera-coverage-audit-20261001")
    }

    private struct CoverageMeasurement: Codable {
        let outsideViewportCenters: Int
        let outsideSafeCenters: Int
        let outsideSafeSurfaceSamples: Int
        let cueDiameterPoints: Float
        let targetDiameterPoints: Float
        let pitchDegrees: Double
        let fov: Double
        let eye: [Float]
        let screenCenters: [[Float]]
    }

    private struct CoverageRow: Codable {
        var sequence = ""
        var fixture = -1
        var measurements: [String: CoverageMeasurement] = [:]
        var scalars: [String: Double] = [:]
        var vectors: [String: [Float]] = [:]
    }

    private func writeCoverageAudit<T: Encodable>(_ value: T, name: String) throws {
        try FileManager.default.createDirectory(at: coverageAuditDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: coverageAuditDirectory.appendingPathComponent(name + ".json"))
    }

    /// Diagnostic evidence, not a passing visual acceptance gate.
    /// Records combinations that the independent-layout projection matrix omitted.
    func testCaptureCameraCoverageStateCombinations() throws {
        var rows: [CoverageRow] = []
        func measurement(_ view: SCNView, _ camera: SCNNode,
                         _ fixture: PocketObservationFixture) throws -> CoverageMeasurement {
            SCNTransaction.flush(); view.layoutIfNeeded()
            let pocket = AngleSceneCalculator.pocketMarkerPositions(surfaceY: 0.8)[fixture.pocket]
            let projections = [fixture.cue, fixture.target, pocket].map { view.projectPoint($0) }
            let outside = projections.filter {
                $0.z <= 0 || $0.z >= 1 || $0.x < 0 || $0.y < 0
                    || $0.x > Float(view.bounds.width) || $0.y > Float(view.bounds.height)
            }.count
            let safe = view.bounds.insetBy(dx: view.bounds.width*0.175, dy: view.bounds.height*0.175)
            func isSafe(_ p: SCNVector3) -> Bool {
                p.z > 0 && p.z < 1 && safe.contains(CGPoint(x: CGFloat(p.x), y: CGFloat(p.y)))
            }
            let outsideSafe = projections.filter { !isSafe($0) }.count
            var surfacePoints: [SCNVector3] = []
            for center in [fixture.cue, fixture.target] {
                for latitude in 0...8 {
                    let phi = Float(latitude)*Float.pi/8
                    for longitude in 0..<16 {
                        let theta = Float(longitude)*Float.pi/8
                        surfacePoints.append(center+SCNVector3(sin(phi)*cos(theta),cos(phi),sin(phi)*sin(theta))*BallPhysics.radius)
                    }
                }
            }
            let hole = AngleSceneCalculator.pocketPositions(surfaceY: 0.8)[fixture.pocket]
            let jaws = AngleSceneCalculator.pocketJaws(surfaceY: 0.837)[fixture.pocket]
            surfacePoints += [jaws.0, jaws.1]
            for step in 0..<64 {
                let angle = Float(step)*Float.pi/32
                let offset = SCNVector3(cos(angle),0,sin(angle))
                surfacePoints.append(pocket+offset*AngleSceneCalculator.pocketMarkerRadius(index: fixture.pocket))
                surfacePoints.append(hole+offset*AngleSceneCalculator.pocketDropRadius(index: fixture.pocket))
            }
            let unsafeSamples = surfacePoints.map { view.projectPoint($0) }.filter { !isSafe($0) }.count
            let right = camera.convertVector(SCNVector3(1,0,0), to: nil).normalized()*BallPhysics.radius
            func diameter(_ center: SCNVector3) -> Float {
                let a = view.projectPoint(center-right), b = view.projectPoint(center+right)
                return hypot(a.x-b.x,a.y-b.y)
            }
            return CoverageMeasurement(outsideViewportCenters: outside,
                outsideSafeCenters: outsideSafe, outsideSafeSurfaceSamples: unsafeSamples,
                cueDiameterPoints: diameter(fixture.cue), targetDiameterPoints: diameter(fixture.target),
                pitchDegrees: Double(camera.eulerAngles.x) * 180 / Double.pi,
                fov: Double(try XCTUnwrap(camera.camera).fieldOfView),
                eye: [camera.position.x, camera.position.y, camera.position.z],
                screenCenters: projections.map { [$0.x, $0.y, $0.z] })
        }
        for size in [viewport, CGSize(width: 667, height: 375), CGSize(width: 1366, height: 1024)] {
            for (index, fixture) in pocketObservationFixtures.enumerated() {
                for delta: Float in [-10000, -120, 120, 10000] {
                    let (view, rig, camera) = dailyRig(size: size)
                    try enterPocketObservation(fixture, rig: rig)
                    let baseline = try measurement(view, camera, fixture)
                    XCTAssertEqual(baseline.outsideViewportCenters, 0)
                    rig.handlePinch(scale: 2); rig.snapToTarget()
                    rig.handleVerticalSwipe(delta: delta)
                    for _ in 0..<120 { rig.update(deltaTime: 1/60) }
                    rig.handlePinch(scale: 0.5); rig.snapToTarget()
                    let wide = try measurement(view, camera, fixture)
                    let pitchBefore = camera.eulerAngles.x
                    // The actual recognizer calls this for a horizontal-only event too.
                    rig.handleVerticalSwipe(delta: 0)
                    for _ in 0..<120 { rig.update(deltaTime: 1/60) }
                    let afterZero = try measurement(view, camera, fixture)
                    var row = CoverageRow()
                    row.sequence = "detail-look-wide-zeroVertical"; row.fixture = index
                    row.vectors["viewport"] = [Float(size.width), Float(size.height)]
                    row.scalars["verticalDelta"] = Double(delta)
                    row.measurements["standard"] = baseline; row.measurements["wide"] = wide
                    row.measurements["afterZeroVertical"] = afterZero
                    row.scalars["zeroVerticalPitchChangeDegrees"] = abs(Double(camera.eulerAngles.x-pitchBefore)) * 180 / Double.pi
                    rows.append(row)
                }
            }
        }
        let pairs = [(viewport, CGSize(width: 1366, height: 1024)),
                     (CGSize(width: 1366, height: 1024), CGSize(width: 667, height: 375)),
                     (CGSize(width: 1194, height: 834), viewport)]
        let thinCue = SCNVector3(1.229, 0.828575, 0.4)
        let thinTargets = [SCNVector3(1.185053, 0.828575, 0.353953),
                           SCNVector3(1.180853, 0.828575, 0.356053)]
        let resizeFixtures = pocketObservationFixtures + thinTargets.map { target in
            let hole = AngleSceneCalculator.pocketPositions(surfaceY: 0.8)[0]
            let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: hole, ballRadius: BallPhysics.radius)
            return PocketObservationFixture(cue: thinCue, target: target, pocket: 0,
                                            aim: (ghost-thinCue).normalized(), elevation: 0.05)
        }
        for (from, to) in pairs {
            for (index, fixture) in resizeFixtures.enumerated() {
                for via2D in [false, true] {
                    let (view, rig, camera) = dailyRig(size: from)
                    try enterPocketObservation(fixture, rig: rig)
                    let saved = rig.capturePerspectiveState()
                    if via2D { rig.applyTopDown2D() }
                    view.frame = CGRect(origin: .zero, size: to)
                    rig.viewportSize = to
                    if via2D { rig.restorePerspectiveState(saved) }
                    rig.snapToTarget()
                    let result = try measurement(view, camera, fixture)
                    var row = CoverageRow()
                    row.sequence = via2D ? "observe-2D-resize-restore" : "observe-resize"; row.fixture = index
                    row.vectors["fromViewport"] = [Float(from.width), Float(from.height)]
                    row.vectors["toViewport"] = [Float(to.width), Float(to.height)]
                    row.measurements["result"] = result
                    rows.append(row)
                }
            }
        }
        // A small legal layout perturbation must be measured in the real rig,
        // independently of the numerical candidate-search port.
        var previousEye: SCNVector3?
        for z: Float in [0.353853, 0.353953] {
            let cue = SCNVector3(1.229, 0.828575, 0.4)
            let target = SCNVector3(1.185053, 0.828575, z)
            let hole = AngleSceneCalculator.pocketPositions(surfaceY: 0.8)[0]
            let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: hole, ballRadius: BallPhysics.radius)
            let fixture = PocketObservationFixture(cue: cue, target: target, pocket: 0,
                                                  aim: (ghost-cue).normalized(), elevation: 0.05)
            let (view, rig, camera) = dailyRig(size: CGSize(width: 1194, height: 834))
            try enterPocketObservation(fixture, rig: rig)
            let result = try measurement(view, camera, fixture)
            let movement = previousEye.map { (camera.position-$0).length() } ?? Float(0)
            var row = CoverageRow()
            row.sequence = "candidate-boundary-perturbation"
            row.scalars["targetZ"] = Double(z)
            row.vectors["aim"] = [fixture.aim.x, fixture.aim.z]
            row.scalars["eyeEndpointChangeMeters"] = Double(movement)
            row.measurements["result"] = result
            rows.append(row)
            previousEye = camera.position
        }
        XCTAssertEqual(rows.count, 230, "Every diagnostic combination must actually execute")
        try writeCoverageAudit(rows, name: "state-combinations")
        print("[CameraCoverageAudit] state diagnostic rows=\(rows.count); results are measurements, not visual acceptance")
    }

    /// Search non-overlapping third balls outside both ideal straight shot
    /// corridors, then independently ray-test the target silhouette.
    func testCaptureCameraCoverageThirdBallOcclusion() throws {
        let r = BallPhysics.radius
        func dot(_ a: SCNVector3, _ b: SCNVector3) -> Float { a.x*b.x+a.y*b.y+a.z*b.z }
        func distanceToSegment(_ point: SCNVector3, _ a: SCNVector3, _ b: SCNVector3) -> Float {
            let segment = b-a
            let t = max(0, min(1, dot(point-a, segment)/max(0.000001, dot(segment, segment))))
            return (point-(a+segment*t)).length()
        }
        func firstSphereHit(eye: SCNVector3, direction: SCNVector3, center: SCNVector3) -> Float? {
            let v = eye-center, b = dot(v, direction), c = dot(v, v)-r*r
            let discriminant = b*b-c
            guard discriminant >= 0 else { return nil }
            let t = -b-sqrt(discriminant)
            return t > 0 ? t : nil
        }
        var evidence: [CoverageRow] = []
        var worst: (fixture: PocketObservationFixture, blocker: SCNVector3, camera: SCNNode, fraction: Float)?
        var candidateCount = 0
        for (index, fixture) in pocketObservationFixtures.enumerated() {
            let (view, rig, camera) = dailyRig()
            try enterPocketObservation(fixture, rig: rig)
            let eye = camera.position, target = fixture.target
            let forward = (target-eye).normalized()
            let right = SCNVector3(-forward.z, 0, forward.x).normalized()
            let up = SCNVector3(right.y*forward.z-right.z*forward.y,
                               right.z*forward.x-right.x*forward.z,
                               right.x*forward.y-right.y*forward.x).normalized()
            var rays: [(SCNVector3, Float)] = []
            for u in -12...12 {
                for v in -12...12 where u*u+v*v <= 144 {
                    let direction = (target-eye+right*(Float(u)*r/12)+up*(Float(v)*r/12)).normalized()
                    if let hit = firstSphereHit(eye: eye, direction: direction, center: target) { rays.append((direction, hit)) }
                }
            }
            XCTAssertGreaterThan(rays.count, 300)
            let hole = AngleSceneCalculator.pocketPositions(surfaceY: 0.8)[fixture.pocket]
            let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: hole, ballRadius: r)
            var bestFraction: Float = 0
            var bestBlocker = target
            var bestClearances: [Float] = []
            for distance: Float in [2*r+0.0001, 0.075, 0.10, 0.15, 0.25, 0.40] {
                for step in 0..<180 {
                    let angle = Float(step)*Float.pi/90
                    let blocker = target+SCNVector3(cos(angle)*distance, 0, sin(angle)*distance)
                    guard abs(blocker.x)+r <= 1.27, abs(blocker.z)+r <= 0.635,
                          (blocker-fixture.cue).length() >= 2*r else { continue }
                    let cueClear = distanceToSegment(blocker, fixture.cue, ghost)
                    let potClear = distanceToSegment(blocker, target, SCNVector3(hole.x,target.y,hole.z))
                    guard cueClear > 2*r+0.001, potClear > 2*r+0.001 else { continue }
                    candidateCount += 1
                    let blocked = rays.filter {
                        guard let first = firstSphereHit(eye: eye, direction: $0.0, center: blocker) else { return false }
                        return first < $0.1
                    }.count
                    let fraction = Float(blocked)/Float(rays.count)
                    if fraction > bestFraction {
                        bestFraction = fraction; bestBlocker = blocker
                        bestClearances = [cueClear, potClear]
                    }
                }
            }
            SCNTransaction.flush(); view.layoutIfNeeded()
            let targetScreen = view.projectPoint(target)
            XCTAssertGreaterThan(targetScreen.z, 0); XCTAssertLessThan(targetScreen.z, 1)
            XCTAssertTrue(view.bounds.contains(CGPoint(x: CGFloat(targetScreen.x), y: CGFloat(targetScreen.y))))
            var row = CoverageRow()
            row.sequence = "third-ball-occlusion"; row.fixture = index
            row.scalars["candidateTargetOccludedFraction"] = Double(bestFraction)
            row.scalars["pocket"] = Double(fixture.pocket)
            row.scalars["silhouetteRaySamples"] = Double(rays.count)
            row.vectors["blocker"] = [bestBlocker.x,bestBlocker.y,bestBlocker.z]
            row.vectors["eye"] = [eye.x,eye.y,eye.z]
            row.vectors["cue"] = [fixture.cue.x,fixture.cue.y,fixture.cue.z]
            row.vectors["target"] = [target.x,target.y,target.z]
            row.vectors["targetScreen"] = [targetScreen.x,targetScreen.y,targetScreen.z]
            row.vectors["idealStraightCorridorClearances"] = bestClearances
            evidence.append(row)
            if bestFraction > (worst?.fraction ?? 0) { worst = (fixture,bestBlocker,camera,bestFraction) }
        }
        var summary = CoverageRow()
        summary.sequence = "summary"; summary.scalars["candidates"] = Double(candidateCount)
        try writeCoverageAudit([summary]+evidence, name: "third-ball-occlusion")
        if let worst {
            let scene = AngleTrainingScene()
            scene.configureDailyClearanceRendering(); scene.setupScene()
            scene.setCameraMode(.perspective3D, animated: false)
            scene.applyBallLayout(cueBallPosition: worst.fixture.cue, targetBallNumber: 1,
                                  targetPosition: worst.fixture.target)
            scene.showBall(key: "_3", scenePosition: worst.blocker)
            scene.hideCueStick()
            scene.cameraNode.transform = worst.camera.transform
            scene.cameraNode.camera?.usesOrthographicProjection = false
            scene.cameraNode.camera?.fieldOfView = worst.camera.camera!.fieldOfView
            scene.cameraNode.camera?.zNear = 0.001
            let renderer = SCNRenderer(device: nil, options: nil)
            renderer.scene = scene; renderer.pointOfView = scene.cameraNode
            SCNTransaction.flush()
            let picture = renderer.snapshot(atTime: 0, with: viewport, antialiasingMode: .multisampling4X)
            try XCTUnwrap(picture.pngData()).write(to: coverageAuditDirectory.appendingPathComponent("third-ball-occlusion.png"))
            let attachment = XCTAttachment(image: picture); attachment.name = "camera-audit-third-ball-model-render"
            attachment.lifetime = .keepAlways; add(attachment)
        }
        print("[CameraCoverageAudit] third-ball candidates=\(candidateCount), worst sampled occlusion=\(worst?.fraction ?? 0); ideal corridor clearance is not physical solver validation")
    }

    func testEyeStaysAboveActualShaftAcrossElevationsAndHeadings() throws {
        for degrees in [3.0, 15, 23, 32, 60] {
            let elevation = Float(degrees * .pi / 180)
            for i in 0..<16 {
                let yaw = Float(i) * .pi / 8
                let aim = SCNVector3(cos(yaw), 0, sin(yaw))
                let cue = SCNVector3(0.2, 0.828575, -0.1)
                let strike = CueStroke.strikePosition(cue: cue, aim: aim, spinX: 0.3, spinY: -0.4)
                let pose = try XCTUnwrap(CameraRig.dailyPlayerPose(view: .firstPerson,
                    cue: cue, strike: strike, aim: aim, elevation: elevation,
                    surfaceY: 0.8, viewport: viewport))
                let eye = SCNVector3(pose.pivot.x + cos(pose.yaw) * pose.radius,
                    0.8 + pose.height, pose.pivot.z + sin(pose.yaw) * pose.radius)
                let stick = CueStick()
                stick.update(cueBallPosition: strike, aimDirection: aim, elevation: elevation)
                let shaft = stick.rootNode.convertPosition(SCNVector3(0, 0, 0.9), to: nil)
                XCTAssertEqual(eye.x, shaft.x, accuracy: 0.0001)
                XCTAssertEqual(eye.z, shaft.z, accuracy: 0.0001)
                XCTAssertEqual(eye.y - shaft.y, 0.13, accuracy: 0.0001)
                XCTAssertLessThan(pose.pitch, 0)
            }
        }
    }

    func testHorizontalLensIsBoundedOnPhoneAndTablet() {
        for size in [viewport, CGSize(width: 1194, height: 834), CGSize(width: 402, height: 640)] {
            let fov = CameraRig.dailyFOV(viewport: size)
            let horizontal = 2 * atan(tan(fov * .pi / 360) * Float(size.width / size.height)) * 180 / .pi
            XCTAssertLessThanOrEqual(horizontal, 56.001)
            XCTAssertLessThanOrEqual(fov, 40)
            XCTAssertLessThan(CameraRig.dailyFOV(viewport: size, close: true), fov)
        }
    }

    func testTargetFocusPinchKeepsEyeAndZoomKeepsPivotAtFarLimit() throws {
        let camera = SCNNode(); camera.camera = SCNCamera()
        let rig = CameraRig(cameraNode: camera, tableSurfaceY: 0.8, config: .dailyClearance)
        rig.usesShotAwareCamera = true; rig.usesRailCameraControls = true; rig.viewportSize = viewport
        let cue = SCNVector3(-0.5, 0.828575, 0), target = SCNVector3(0.3, 0.828575, 0.1)
        XCTAssertTrue(rig.enterPlayerView(.thirdPerson, cue: cue, aim: target - cue, focus: target))
        rig.update(deltaTime: 2)
        XCTAssertLessThan((rig.currentPivot - target).length(), 0.001)
        let eye = camera.position
        rig.beginObservationPinch(at: cue)
        rig.snapToTarget()
        XCTAssertLessThan((camera.position - eye).length(), 0.001)
        rig.handlePinch(scale: 2); rig.snapToTarget()
        XCTAssertLessThan((rig.currentPivot - cue).length(), 0.001)
        XCTAssertLessThan((camera.position - eye).length(), 0.001)
        let yaw = rig.targetYaw
        rig.handleHorizontalSwipe(delta: 100)
        XCTAssertLessThan(abs(rig.targetYaw - yaw), 0.25)
        rig.handlePinch(scale: 0.1); rig.snapToTarget()
        rig.handlePinch(scale: 0.9); rig.snapToTarget()
        XCTAssertLessThan((rig.currentPivot - cue).length(), 0.001)
        XCTAssertEqual(rig.currentYaw, rig.targetYaw, accuracy: 0.001)
        XCTAssertFalse(rig.keepsWholeTableFramed)
    }

    func testCuePoseUpdatesFirstPersonButNeverStealsManualObservation() throws {
        let camera = SCNNode(); camera.camera = SCNCamera()
        let rig = CameraRig(cameraNode: camera, tableSurfaceY: 0.8, config: .dailyClearance)
        rig.usesShotAwareCamera = true; rig.viewportSize = viewport
        let cue = SCNVector3(0, 0.828575, 0), aim = SCNVector3(1, 0, 0)
        rig.updateCuePose(strike: cue, aim: aim, elevation: 0.05)
        rig.enterPlayerView(.firstPerson, cue: cue, aim: aim); rig.update(deltaTime: 2)
        let low = camera.position.y
        rig.updateCuePose(strike: cue, aim: aim, elevation: 0.4); rig.update(deltaTime: 2)
        XCTAssertGreaterThan(camera.position.y, low + 0.2)
        let state = rig.capturePerspectiveState()
        rig.handleHorizontalSwipe(delta: 40); rig.snapToTarget()
        let manual = camera.simdTransform
        rig.updateCuePose(strike: cue, aim: aim, elevation: 0.1); rig.update(deltaTime: 2)
        XCTAssertEqual(camera.simdTransform, manual)
        rig.restorePerspectiveState(state)
        XCTAssertEqual(rig.playerView, .firstPerson)
    }
}

extension DailyShotCameraTests {
    func testRaisedCueGazeKeepsBothBallsInViewWithoutLoweringEye() throws {
        let cue = SCNVector3(-1.234, 0.828575, -0.457), target = SCNVector3(-0.406, 0.828575, -0.127)
        let aim = (target - cue).normalized()
        let pose = try XCTUnwrap(CameraRig.dailyPlayerPose(view: .firstPerson, cue: cue,
            strike: cue, aim: aim, elevation: 0.40, surfaceY: 0.8, viewport: viewport, context: [cue, target]))
        let camera = SCNNode()
        camera.position = SCNVector3(pose.pivot.x + cos(pose.yaw) * pose.radius,
            0.8 + pose.height, pose.pivot.z + sin(pose.yaw) * pose.radius)
        camera.eulerAngles = SCNVector3(pose.pitch, atan2(cos(pose.yaw), sin(pose.yaw)), 0)
        for point in [cue, target] {
            let p = camera.convertPosition(point, from: nil)
            XCTAssertLessThan(p.z, 0)
            let vertical = p.y / -p.z / tan(pose.fov * .pi / 360)
            XCTAssertLessThan(abs(vertical), 0.8, "Both balls stay inside the usable vertical field")
        }
        XCTAssertGreaterThan(camera.position.y, 1.25)
    }
}

extension DailyShotCameraTests {
    func testReplacingUnstartedPoseUsesVisibleOrigin() {
        let camera = SCNNode(); camera.camera = SCNCamera()
        let rig = CameraRig(cameraNode: camera, tableSurfaceY: 0.8, config: .dailyClearance)
        rig.usesShotAwareCamera = true; rig.viewportSize = viewport
        let cue = SCNVector3(0, 0.828575, 0), aim = SCNVector3(1, 0, 0)
        rig.enterPlayerView(.firstPerson, cue: cue, aim: aim); rig.update(deltaTime: 2)
        let eye = camera.position
        rig.enterPlayerView(.firstPerson, cue: cue, aim: SCNVector3(0.98, 0, 0.2))
        rig.enterPlayerView(.thirdPerson, cue: cue, aim: aim)
        rig.update(deltaTime: 0)
        XCTAssertLessThan((camera.position - eye).length(), 0.001)
    }
}

/// Opt-in still using production table, balls and pocket/contact geometry.
@MainActor
final class ClockAimingPreviewCaptureTests: XCTestCase {
    func testNativeClockPreview() throws {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["TEST_RUNNER_CLOCK_PREVIEW_DIR"] ?? env["CLOCK_PREVIEW_DIR"] else {
            throw XCTSkip("Set TEST_RUNNER_CLOCK_PREVIEW_DIR")
        }
        let out = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let vm = AngleDynamicViewModel(); vm.setupScene()
        let scene = vm.scene
        XCTAssertTrue(scene.applyTableStyle(.charcoal, showsSights: true))
        scene.applyClothColor(.green)
        let r = AngleSceneCalculator.ballRadius, y = scene.surfaceY + r
        let target = SCNVector3(0.70, y, -0.05), cue = SCNVector3(0.24, y, 0.10)
        try XCTUnwrap(vm.targetNode).position = target
        try XCTUnwrap(scene.cueBallNode).position = cue
        vm.selectPocket(at: 1); vm.updateCalculations()
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: 1, surfaceY: scene.surfaceY)
        let n = simd_normalize(SIMD2<Float>(aim.x-target.x, aim.z-target.z))
        let a = AngleSceneCalculator.contactPointPosition(targetBall: target, pocket: aim)
        let b = SCNVector3(cue.x+r*n.x, y, cue.z+r*n.y)
        XCTAssertEqual(a.x-target.x, -(b.x-cue.x), accuracy: 0.000001)
        XCTAssertEqual(a.z-target.z, -(b.z-cue.z), accuracy: 0.000001)
        scene.setCameraMode(.topDown2D, animated: false)
        scene.hideCueStick()
        for node in [scene.ghostBallNode, scene.pocketLineNode, scene.strikeLineNode, scene.contactDotNode, scene.angleArcNode, scene.perpLineNode] { node?.isHidden = true }
        let cameraNode = try XCTUnwrap(scene.cameraNode), camera = try XCTUnwrap(scene.cameraNode.camera)
        camera.usesOrthographicProjection = true; camera.projectionDirection = .vertical
        camera.zNear = 0.01; camera.zFar = 100; camera.wantsExposureAdaptation = false
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene; renderer.pointOfView = cameraNode
        renderer.delegate = scene.contactOcclusion; renderer.autoenablesDefaultLighting = false
        func positionCamera(_ center: SCNVector3, _ scale: Double) {
            camera.orthographicScale = scale
            cameraNode.position = SCNVector3(center.x, center.y+3, center.z)
            cameraNode.look(at: center, up: SCNVector3(1,0,0), localFront: SCNVector3(0,0,-1))
            SCNTransaction.flush()
        }
        func project(_ p: SCNVector3, _ height: CGFloat) -> CGPoint {
            let q = renderer.projectPoint(p)
            return CGPoint(x: CGFloat(q.x), y: height-CGFloat(q.y))
        }
        func clock(_ point: SCNVector3, _ center: SCNVector3) -> String {
            var hours = Double(atan2(point.z-center.z, point.x-center.x)) * 6 / .pi
            if hours < 0 { hours += 12 }
            let total = Int((hours*60).rounded()) % 720
            return String(format: "%d:%02d", total/60 == 0 ? 12 : total/60, total%60)
        }
        let targetTime = clock(a,target), cueTime = clock(b,cue)
        let mainSize = CGSize(width: 1100, height: 1500)
        positionCamera(SCNVector3(0.53,scene.surfaceY,0),1.05)
        _ = renderer.snapshot(atTime: 0, with: mainSize, antialiasingMode: .multisampling4X)
        let main = renderer.snapshot(atTime: 0, with: mainSize, antialiasingMode: .multisampling4X)
        let ap = project(a,1500), bp = project(b,1500), tp = project(target,1500), cp = project(cue,1500), pp = project(aim,1500)
        let left = project(SCNVector3(target.x,y,-0.59),1500), right = project(SCNVector3(target.x,y,0.59),1500)
        let closeSize = CGSize(width: 440,height: 440)
        var details: [(UIImage,CGPoint)] = []
        for (center,point) in [(target,a),(cue,b)] {
            positionCamera(center,0.043)
            let image = renderer.snapshot(atTime: 0, with: closeSize, antialiasingMode: .multisampling4X)
            details.append((image,project(point,440)))
        }
        let size = CGSize(width:1700,height:1500), format = UIGraphicsImageRendererFormat()
        format.scale=1; format.opaque=true
        let result = UIGraphicsImageRenderer(size:size,format:format).image { context in
            let g = context.cgContext
            UIColor(red:0.055,green:0.075,blue:0.07,alpha:1).setFill(); context.fill(CGRect(origin:.zero,size:size))
            main.draw(at:.zero)
            func line(_ p:CGPoint,_ q:CGPoint,_ color:UIColor,_ dashed:Bool=false) {
                g.saveGState(); g.setStrokeColor(color.cgColor);g.setLineWidth(3)
                g.setLineDash(phase:0,lengths:dashed ? [12,10]:[])
                g.move(to:p);g.addLine(to:q);g.strokePath();g.restoreGState()
            }
            func dot(_ p:CGPoint) {
                UIColor.systemRed.setFill();let shape=UIBezierPath(ovalIn:CGRect(x:p.x-7,y:p.y-7,width:14,height:14));shape.fill()
                UIColor.white.setStroke();shape.lineWidth=1.5;shape.stroke()
            }
            func text(_ value:String,_ x:CGFloat,_ y:CGFloat,_ font:CGFloat=30,_ color:UIColor = .white) {
                let shadow=NSShadow();shadow.shadowColor=UIColor.black;shadow.shadowBlurRadius=4
                (value as NSString).draw(at:CGPoint(x:x,y:y),withAttributes:[.font:UIFont.systemFont(ofSize:font,weight:.semibold),.foregroundColor:color,.shadow:shadow])
            }
            line(left,right,UIColor.white.withAlphaComponent(0.65),true)
            line(tp,pp,.systemYellow)
            line(tp,ap,.systemYellow)
            dot(ap);dot(bp)
            text("平行于短边库边",right.x-270,tp.y-48,27)
            text("目标球接触点 · 约 \(targetTime)",tp.x+52,tp.y+60,27)
            text("母球固定 · 接触点约 \(cueTime)",cp.x-160,cp.y+65,27)
            text("钟表瞄准法",1150,55,48)
            text("真实球桌 · 俯视预览",1150,125,27,.lightGray)
            for i in 0..<2 {
                let origin=CGPoint(x:1180,y:i == 0 ? 280:900)
                details[i].0.draw(at:origin)
                dot(CGPoint(x:origin.x+details[i].1.x,y:origin.y+details[i].1.y))
            }
            text("目标球：约 \(targetTime)",1190,225,32)
            text("相差 6 小时",1190,760,42,.systemYellow)
            text("母球：约 \(cueTime)",1190,845,32)
            text("球面不画钟表，只认接触点",1140,1400,27)
            text("移动目标球，重新读取接触点方向",95,1400,30)
        }
        try XCTUnwrap(result.pngData()).write(to:out.appendingPathComponent("clock-aiming-native.png"))
        let record:[String:Any] = ["targetTime":targetTime,"cueTime":cueTime,"cue":[cue.x,cue.y,cue.z],"target":[target.x,target.y,target.z],"aim":[aim.x,aim.y,aim.z],"renderer":"AngleTrainingScene / SCNRenderer","screenUp":"+X","screenRight":"+Z"]
        try JSONSerialization.data(withJSONObject:record,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("geometry.json"))
    }
}

extension ClockAimingPreviewCaptureTests {
    func testClockPerspectiveKeyframes() async throws {
        let env=ProcessInfo.processInfo.environment
        guard let path=env["TEST_RUNNER_CLOCK_KEYFRAMES_DIR"] ?? env["CLOCK_KEYFRAMES_DIR"] else { throw XCTSkip("Opt-in keyframes") }
        let out=URL(fileURLWithPath:path);try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
        let smilePath=env["TEST_RUNNER_CLOCK_SMILE_PATH"] ?? env["CLOCK_SMILE_PATH"]
        let smileImage=try smilePath.map { try XCTUnwrap(UIImage(contentsOfFile:$0)) }
        let showCutAngle=env["TEST_RUNNER_CLOCK_CUT_ANGLE"] == "1" || env["CLOCK_CUT_ANGLE"] == "1"
        let vm=AngleDynamicViewModel();vm.setupScene();let s=vm.scene
        XCTAssertTrue(s.applyTableStyle(.charcoal,showsSights:true));s.applyClothColor(.green)
        s.setCameraMode(.perspective3D,animated:false);s.installReferenceRoom(style:.tournament)
        XCTAssertTrue(try XCTUnwrap(s.cueStick).applyStyle(.inkDragon))
        let r=AngleSceneCalculator.ballRadius,y=s.surfaceY+r,cue=SCNVector3(0,s.surfaceY+AngleSceneCalculator.ballRadius,0.48)
        let camera=try XCTUnwrap(s.cameraNode),cam=try XCTUnwrap(camera.camera)
        cam.projectionDirection = .vertical;cam.zNear=0.01;cam.zFar=100;cam.wantsExposureAdaptation=false
        let renderer=SCNRenderer(device:nil,options:nil);renderer.scene=s;renderer.pointOfView=camera
        renderer.delegate=s.contactOcclusion;renderer.autoenablesDefaultLighting=false
        let canvas=CGSize(width:1500,height:2100),renderCanvas=CGSize(width:2000,height:2800),small=CGSize(width:640,height:640)
        let renderScale:CGFloat=4.0/3.0
        let format=UIGraphicsImageRendererFormat();format.scale=renderScale;format.opaque=true
        let fixedCuePose=s.cueBallHomeOrientation
        var records:[[String:Any]]=[]
        func project(_ p:SCNVector3,_ h:CGFloat)->CGPoint{let q=renderer.projectPoint(p);return CGPoint(x:CGFloat(q.x)/renderScale,y:h-CGFloat(q.y)/renderScale)}
        // Solve the endpoint against the production cut-angle calculation; keep cue and pocket fixed.
        try XCTUnwrap(s.cueBallNode).position=cue
        var lower:Float=0,upper:Float=0.46
        for _ in 0..<32 {
            let candidate=(lower+upper)/2
            try XCTUnwrap(vm.targetNode).position=SCNVector3(candidate,y,-0.18)
            vm.selectPocket(at:4);vm.updateCalculations()
            if vm.cutAngleDegrees<60 {lower=candidate} else {upper=candidate}
        }
        let endpoint=(lower+upper)/2
        let video=env["TEST_RUNNER_CLOCK_VIDEO"] == "1" || env["CLOCK_VIDEO"] == "1"
        let fps=60, frameCount=1080
        let writer=video ? try VideoWriter(url:out.appendingPathComponent("clock-aiming-2k60-18s.mp4"),size:renderCanvas,fps:fps,averageBitRate:40_000_000):nil
        let positions: [Float] = video ? (0..<frameCount).map { frame in
            let u=max(0,min(1,(Double(frame)/Double(fps)-1)/16))
            let eased=u*u*(3-2*u)
            return endpoint*Float(2*eased-1)
        } : [-endpoint,-endpoint/2,0,endpoint/2,endpoint]
        for (index,x) in positions.enumerated() {
          try autoreleasepool {
            let target=SCNVector3(x,y,-0.18)
            try XCTUnwrap(vm.targetNode).position=target;try XCTUnwrap(s.cueBallNode).position=cue
            vm.selectPocket(at:4);vm.updateCalculations()
            s.setCueBallHomeOrientation(fixedCuePose)
            if index == 0 || index == positions.count-1 {XCTAssertEqual(vm.cutAngleDegrees,60,accuracy:0.01)}
            let pocket=AngleSceneCalculator.effectivePocketAimPoint(targetBall:target,pocketIndex:4,surfaceY:s.surfaceY)
            let n=simd_normalize(SIMD2<Float>(pocket.x-target.x,pocket.z-target.z))
            let ghost=AngleSceneCalculator.ghostBallPosition(targetBall:target,pocket:pocket,ballRadius:r)
            let a=AngleSceneCalculator.contactPointPosition(targetBall:target,pocket:pocket),b=SCNVector3(cue.x+r*n.x,y,cue.z+r*n.y)
            XCTAssertEqual(a.x-target.x,-(b.x-cue.x),accuracy:0.000001);XCTAssertEqual(a.z-target.z,-(b.z-cue.z),accuracy:0.000001)
            s.updateCueStick(cueBallPosition:cue,aimDirection:SCNVector3(ghost.x-cue.x,0,ghost.z-cue.z))
            for node in [s.ghostBallNode,s.pocketLineNode,s.strikeLineNode,s.contactDotNode,s.angleArcNode,s.perpLineNode] {node?.isHidden=true}
            s.rootNode.childNode(withName:"strikeContinuation",recursively:true)?.isHidden=true
            let extras=SCNNode();s.rootNode.addChildNode(extras)
            let pot=s.addDashedLine(from:target,to:pocket,color:.black,radius:0.0013,dash:0.018,gap:0.012,placement:.table,layer:.aiming);extras.addChildNode(pot)
            let rail=AngleSceneCalculator.rayToInnerRail(from:cue,dir:SCNVector3(ghost.x-cue.x,0,ghost.z-cue.z),inset:0)
            let entry=AngleSceneCalculator.aimRayTargetEntry(from:cue,toward:rail,target:target)
            let aimLine=s.addLine(from:cue,to:entry ?? rail,color:.white,radius:0.0012,placement:.table,layer:.aiming);extras.addChildNode(aimLine)
            if let entry {
                let continuation=s.addDashedLine(from:entry,to:rail,color:.white,radius:0.0012,dash:0.018,gap:0.012,placement:.table,layer:.aiming)
                extras.addChildNode(continuation)
            }
            // The potting line and aim line intersect at the ghost-ball center.
            let aimDirection=simd_normalize(SIMD2<Float>(ghost.x-cue.x,ghost.z-cue.z))
            let potHeading=atan2(n.y,n.x)
            let aimHeading=atan2(aimDirection.y,aimDirection.x)
            let arcSweep=atan2(sin(aimHeading-potHeading),cos(aimHeading-potHeading))
            if showCutAngle {
                XCTAssertEqual(Double(abs(arcSweep)*180 / .pi),vm.cutAngleDegrees,accuracy:0.01)
                extras.addChildNode(s.addDashedLine(from:ghost,to:target,color:.black,radius:0.0013,dash:0.009,gap:0.006,placement:.table,layer:.aiming))
                if abs(arcSweep)>0.001 {
                    for segment in 0..<48 {
                        let h0=potHeading+arcSweep*Float(segment)/48
                        let h1=potHeading+arcSweep*Float(segment+1)/48
                        let p0=SCNVector3(ghost.x+0.14*cos(h0),s.surfaceY,ghost.z+0.14*sin(h0))
                        let p1=SCNVector3(ghost.x+0.14*cos(h1),s.surfaceY,ghost.z+0.14*sin(h1))
                        extras.addChildNode(s.addLine(from:p0,to:p1,color:.systemYellow,radius:0.0016,placement:.table,layer:.aiming))
                    }
                }
            }
            for (axisIndex,center) in [target,cue].enumerated() {
                let axisEnd=SCNVector3(center.x,s.surfaceY,center.z+(axisIndex==0 ? -0.12:0.12))
                extras.addChildNode(s.addLine(from:SCNVector3(center.x,s.surfaceY,center.z),to:axisEnd,color:.white,radius:0.0012,placement:.table,layer:.aiming))
                extras.addChildNode(s.addLine(from:SCNVector3(center.x-0.055,s.surfaceY,center.z),to:SCNVector3(center.x+0.055,s.surfaceY,center.z),color:.white,radius:0.0012,placement:.table,layer:.aiming))
            }
            XCTAssertTrue(abs(abs(rail.x)-AngleSceneCalculator.innerLength/2)<0.0001 || abs(abs(rail.z)-AngleSceneCalculator.innerWidth/2)<0.0001)
            cam.usesOrthographicProjection=false;cam.fieldOfView=76
            camera.position=SCNVector3(0,s.surfaceY+1.02,0.98)
            camera.look(at:SCNVector3(0,s.surfaceY,-0.05),up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
            SCNTransaction.flush()
            _=renderer.snapshot(atTime:0,with:renderCanvas,antialiasingMode:.multisampling4X)
            let base=renderer.snapshot(atTime:0,with:renderCanvas,antialiasingMode:.multisampling4X)
            let railLeft=project(SCNVector3(-0.5,s.surfaceY,-0.635),canvas.height)
            let railRight=project(SCNVector3(0.5,s.surfaceY,-0.635),canvas.height)
            XCTAssertEqual(railLeft.y,railRight.y,accuracy:0.01)
            let ap=project(a,canvas.height),bp=project(b,canvas.height),cp=project(cue,canvas.height),tp=project(target,canvas.height)
            XCTAssertTrue(CGRect(origin:.zero,size:canvas).insetBy(dx:25,dy:25).contains(cp));XCTAssertTrue(CGRect(origin:.zero,size:canvas).insetBy(dx:25,dy:25).contains(tp))
            let potAnchor=project(SCNVector3((target.x+pocket.x)/2,s.surfaceY+0.002,(target.z+pocket.z)/2),canvas.height)
            let aimAnchor=project(SCNVector3(cue.x*0.55+ghost.x*0.45,s.surfaceY+0.002,cue.z*0.55+ghost.z*0.45),canvas.height)
            let axisSegments=[target,cue].map { center in
                (project(SCNVector3(center.x-0.055,s.surfaceY+0.002,center.z),canvas.height),project(SCNVector3(center.x+0.055,s.surfaceY+0.002,center.z),canvas.height))
            }
            let twelveLabel=project(SCNVector3(target.x,s.surfaceY+0.002,target.z-0.12),canvas.height)
            let sixLabel=project(SCNVector3(cue.x,s.surfaceY+0.002,cue.z+0.12),canvas.height)
            let angleMid=potHeading+arcSweep/2
            let cutLabel=project(SCNVector3(ghost.x+0.20*cos(angleMid),s.surfaceY+0.002,ghost.z+0.20*sin(angleMid)),canvas.height)
            extras.isHidden=true;s.hideCueStick()
            var details:[UIImage]=[],contactPixels:[CGPoint]=[],angles:[Double]=[],minutes:[Int]=[]
            for (center,contact) in [(target,a),(cue,b)] {
                cam.usesOrthographicProjection=true;cam.orthographicScale=0.064
                camera.position=SCNVector3(center.x,center.y+3,center.z)
                camera.look(at:center,up:SCNVector3(0,0,-1),localFront:SCNVector3(0,0,-1));SCNTransaction.flush()
                details.append(renderer.snapshot(atTime:0,with:small,antialiasingMode:.multisampling4X));contactPixels.append(project(contact,480))
                let theta=Double(atan2(contact.x-center.x,-(contact.z-center.z)));angles.append(theta)
                let positive=theta<0 ? theta+2 * .pi:theta
                minutes.append((Int((positive/(2 * .pi)*720/5).rounded())*5)%720)
            }
            XCTAssertEqual((minutes[1]-minutes[0]+720)%720,360)
            let axisAngles=angles.map { acos(min(1,abs(cos($0)))) * 180 / Double.pi }
            XCTAssertEqual(axisAngles[0],axisAngles[1],accuracy:0.001)
            XCTAssertTrue(axisAngles.allSatisfy { $0 >= 0 && $0 <= 90 })
            let image=UIGraphicsImageRenderer(size:canvas,format:format).image { context in
                base.draw(in:CGRect(origin:.zero,size:canvas));let g=context.cgContext
                func line(_ p:CGPoint,_ q:CGPoint,_ color:UIColor,_ width:CGFloat=2) {g.setStrokeColor(color.cgColor);g.setLineWidth(width);g.move(to:p);g.addLine(to:q);g.strokePath()}
                func text(_ value:String,_ p:CGPoint,_ size:CGFloat=30,_ color:UIColor = .white,centered:Bool=false) {
                    let shadow=NSShadow();shadow.shadowColor=UIColor.black;shadow.shadowBlurRadius=1
                    let attr:[NSAttributedString.Key:Any]=[.font:UIFont.systemFont(ofSize:size,weight:.semibold),.foregroundColor:color,.shadow:shadow]
                    let width=(value as NSString).size(withAttributes:attr).width
                    (value as NSString).draw(at:CGPoint(x:centered ? p.x-width/2:p.x,y:p.y),withAttributes:attr)
                }
                func dot(_ p:CGPoint,_ color:UIColor) {color.setFill();let shape=UIBezierPath(ovalIn:CGRect(x:p.x-6,y:p.y-6,width:12,height:12));shape.fill();UIColor.white.setStroke();shape.lineWidth=1.5;shape.stroke()}
                line(ap,bp,.cyan,2.5)
                if showCutAngle {
                    text(String(format:"%.0f°",vm.cutAngleDegrees),CGPoint(x:cutLabel.x,y:cutLabel.y-70),34,.systemYellow,centered:true)
                }
                text("12点",CGPoint(x:twelveLabel.x,y:twelveLabel.y-38),27,.white,centered:true)
                text("6点",CGPoint(x:sixLabel.x,y:sixLabel.y+10),27,.white,centered:true)
                dot(ap,.systemRed);dot(bp,.systemOrange)
                func leader(_ title:String,_ anchor:CGPoint,_ label:CGPoint,_ color:UIColor) {
                    text(title,label,34,color)
                    let labelWidth=(title as NSString).size(withAttributes:[.font:UIFont.systemFont(ofSize:34,weight:.semibold)]).width
                    let end=CGPoint(x:label.x < anchor.x ? label.x+labelWidth+14:label.x-14,y:label.y+22)
                    line(anchor,end,color,2)
                    color.setFill();g.fillEllipse(in:CGRect(x:anchor.x-3.5,y:anchor.y-3.5,width:7,height:7))
                }
                for (left,right) in axisSegments {
                    text("9点",CGPoint(x:left.x-42,y:left.y-16),27,.white,centered:true)
                    text("3点",CGPoint(x:right.x+32,y:right.y-16),27,.white,centered:true)
                }
                leader("进球线",potAnchor,CGPoint(x:potAnchor.x+(target.x>0 ? -240:80),y:potAnchor.y-60),.black)
                let contactMid=CGPoint(x:ap.x*0.5+bp.x*0.5,y:ap.y*0.5+bp.y*0.5)
                let fraction=(aimAnchor.y-ap.y)/(bp.y-ap.y)
                let contactAtAimX=ap.x+(bp.x-ap.x)*fraction
                let contactOnRight=contactAtAimX>aimAnchor.x+1
                let contactLabel=CGPoint(x:contactOnRight ? min(contactMid.x+80,795):contactMid.x-300,y:contactMid.y-45)
                let aimLabel=CGPoint(x:contactOnRight ? aimAnchor.x-230:aimAnchor.x+90,y:aimAnchor.y+25)
                leader("接触点连线",contactMid,contactLabel,.cyan)
                leader("瞄准线",aimAnchor,aimLabel,.white)
                UIColor.black.withAlphaComponent(0.90).setFill()
                UIBezierPath(roundedRect:CGRect(x:35,y:365,width:520,height:128),cornerRadius:18).fill()
                text("瞄准流程：",CGPoint(x:45,y:1400),showCutAngle ? 28:34,.white)
                smileImage?.draw(in:CGRect(x:showCutAngle ? 185:220,y:showCutAngle ? 1391:1395,width:50,height:50))
                let aimingSteps=["1. 定目标球接触点；","2. 定目标球接触点时间；","3. 定母球时间；","4. 定母球接触点；","5. 定瞄准线方向"]
                for (stepIndex,step) in aimingSteps.enumerated() {
                    text(step,CGPoint(x:45,y:(showCutAngle ? 1450:1460)+CGFloat(stepIndex)*(showCutAngle ? 48:56)),showCutAngle ? 24:30,.white)
                }
                text("注：母球与目标球的接触点，",CGPoint(x:55,y:383),34,.white)
                text("对应的钟表时间相差6小时。",CGPoint(x:55,y:435),34,.white)
                let offset = -tan(angles[0])*350
                let centers=[CGPoint(x:1190-offset/2,y:650),CGPoint(x:1190+offset/2,y:1000)]
                let linkColor=UIColor.cyan
                line(centers[0],centers[1],linkColor.withAlphaComponent(0.8),2)
                for i in 0..<2 {
                    let center=centers[i],box=CGRect(x:center.x-170,y:center.y-170,width:340,height:340)
                    let color:UIColor=i==0 ? .systemRed:.systemOrange
                    let panel=CGRect(x:box.minX,y:box.minY-(i==0 ? 54:0),width:box.width,height:box.height+54)
                    g.saveGState();UIBezierPath(roundedRect:panel,cornerRadius:20).addClip()
                    UIColor.black.setFill();context.fill(panel)
                    details[i].draw(in:box);g.restoreGState()
                    UIColor.white.withAlphaComponent(0.85).setStroke();let border=UIBezierPath(roundedRect:panel,cornerRadius:20);border.lineWidth=2;border.stroke()
                    for tick in 0..<60 {
                        let t=Double(tick)*2 * .pi/60,outer:CGFloat=108,inner:CGFloat=tick%5==0 ? 94:101
                        line(CGPoint(x:center.x+sin(t)*inner,y:center.y-cos(t)*inner),CGPoint(x:center.x+sin(t)*outer,y:center.y-cos(t)*outer),UIColor.white.withAlphaComponent(tick%5==0 ? 1:0.75),tick%5==0 ? 3:1.5)
                    }
                    for hour in 1...12 {
                        let t=Double(hour)*Double.pi/6
                        text(String(hour),CGPoint(x:center.x+sin(t)*129,y:center.y-cos(t)*129-14),26,.white,centered:true)
                    }
                    let theta=angles[i]
                    line(CGPoint(x:center.x-sin(theta)*158,y:center.y+cos(theta)*158),CGPoint(x:center.x+sin(theta)*158,y:center.y-cos(theta)*158),linkColor,2)
                    dot(CGPoint(x:box.minX+contactPixels[i].x*340/480,y:box.minY+contactPixels[i].y*340/480),color)
                    let m=minutes[i],hour=m/60
                    text(String(format:"%@ · 约%d点%02d分",i==0 ? "目标球":"母球",hour,m%60),CGPoint(x:box.minX+16,y:i==0 ? panel.minY+12:box.maxY+12),25,.white)
                }

            }
            if let writer {
                try writer.append(XCTUnwrap(image.cgImage))
                if index % 60 == 0 { print("CLOCK_VIDEO_FRAME \(index)/\(frameCount)") }
            } else {
                try XCTUnwrap(image.pngData()).write(to:out.appendingPathComponent(String(format:"keyframe-%02d.png",index+1)))
            }
            records.append(["frame":index+1,"cue":[cue.x,cue.y,cue.z],"target":[target.x,target.y,target.z],"cutAngle":vm.cutAngleDegrees,"clockMinutes":minutes,"axisAnglesDegrees":axisAngles,"aimRail":[rail.x,rail.y,rail.z],"aimOccluded":entry != nil,"cuePixel":[cp.x,cp.y],"targetPixel":[tp.x,tp.y]])
            extras.removeFromParentNode()
          }
          if video { try await Task.sleep(nanoseconds:1_000_000) }
        }
        try await writer?.finish()
        try JSONSerialization.data(withJSONObject:records,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("geometry.json"))
    }
}

extension DailyShotCameraTests {
    private func dailyRig(size: CGSize? = nil) -> (SCNView, CameraRig, SCNNode) {
        let view = SCNView(frame: CGRect(origin: .zero, size: size ?? viewport))
        let scene = SCNScene(), node = SCNNode(); node.camera = SCNCamera()
        scene.rootNode.addChildNode(node); view.scene = scene; view.pointOfView = node
        let rig = CameraRig(cameraNode: node, tableSurfaceY: 0.8, config: .dailyClearance)
        rig.usesShotAwareCamera = true; rig.usesRailCameraControls = true
        rig.viewportSize = view.bounds.size
        return (view, rig, node)
    }

    /// Independent SceneKit projection checks the production projection calculation's axes/lens.
    private func projectedTableScale(_ view: SCNView, _ rig: CameraRig) -> Float {
        SCNTransaction.flush(); view.layoutIfNeeded()
        let x = Float(rig.tableOuterHalfLength), z = Float(rig.tableOuterHalfWidth)
        let points = [(-x,-z),(x,-z),(x,z),(-x,z)].map {
            view.projectPoint(SCNVector3($0.0, 0.8, $0.1))
        }
        let width = (points.map(\.x).max()! - points.map(\.x).min()!) / Float(view.bounds.width)
        let height = (points.map(\.y).max()! - points.map(\.y).min()!) / Float(view.bounds.height)
        return max(width,height)
    }

    func testDailyOverviewChoosesBothLongRailsAndShortestTurn() {
        for degree in stride(from: -359, through: 359, by: 7) {
            let yaw = Float(degree) * .pi / 180
            let result = CameraRig.dailyOverviewYaw(currentYaw: yaw, aimDirection: SCNVector3(1,0,0))
            let delta = atan2(sin(result-yaw), cos(result-yaw))
            XCTAssertLessThanOrEqual(abs(delta), .pi/2 + 0.00001)
            XCTAssertEqual(abs(result), .pi/2, accuracy: 0.00001)
            if abs(sin(yaw)) > 0.00001 { XCTAssertEqual(result > 0, sin(yaw) > 0) }
        }
        XCTAssertEqual(CameraRig.dailyOverviewYaw(currentYaw: 0, aimDirection: SCNVector3(0,0,1)), -.pi/2)
        XCTAssertEqual(CameraRig.dailyOverviewYaw(currentYaw: .pi, aimDirection: SCNVector3(0,0,-1)), .pi/2)
    }

    func testDailyOverviewHasConstantSpeedAcrossFrameRatesAndDirections() {
        for fps in [30,60,120] {
            for degree in [-120, -60, 60, 120] {
                let (_, rig, _) = dailyRig()
                rig.observeWholeTable(yaw: Float(degree) * .pi/180); rig.snapToTarget()
                let start = rig.currentYaw
                rig.observeDailyWholeTable(aimDirection: SCNVector3(1,0,0))
                let direction: Float = rig.targetYaw > start ? 1 : -1
                for frame in 1...(fps/4) {
                    rig.update(deltaTime: 1/Float(fps))
                    XCTAssertEqual(rig.currentYaw, start + direction * .pi/3 * Float(frame)/Float(fps), accuracy: 0.00001)
                }
                for _ in 0..<fps { rig.update(deltaTime: 1/Float(fps)) }
                XCTAssertEqual(rig.currentYaw, rig.targetYaw, accuracy: 0.00001)
            }
        }
    }

    func testDailyOverviewRoundTripAndManualInterruptContinueFromVisibleYaw() {
        let (_, rig, _) = dailyRig()
        rig.observeWholeTable(yaw: .pi/6); rig.snapToTarget()
        rig.observeDailyWholeTable(aimDirection: nil); rig.update(deltaTime: 0.2)
        let state = rig.capturePerspectiveState(), yaw = rig.currentYaw
        rig.applyTopDown2D(); rig.restorePerspectiveState(state); rig.update(deltaTime: 0.1)
        XCTAssertEqual(rig.currentYaw-yaw, .pi/30, accuracy: 0.00001)
        let visible = rig.currentYaw
        rig.handleHorizontalSwipe(delta: -20)
        XCTAssertEqual(rig.targetYaw, visible - 0.05, accuracy: 0.00001)
        rig.snapToTarget()
        rig.update(deltaTime: 0.2)
        XCTAssertEqual(rig.currentYaw, visible - 0.05, accuracy: 0.00001)
    }

    func testDailyObservationZoomIsContinuousWithStricterCapThanOverviewMinimumScale() throws {
        for size in [viewport, CGSize(width:1194,height:834), CGSize(width:402,height:640)] {
            let (view, rig, camera) = dailyRig(size:size)
            rig.observeWholeTable(yaw: .pi/2); rig.snapToTarget()
            let defaultDistance = rig.orbitDistance
            rig.handlePinch(scale:0.01); rig.snapToTarget()
            let wallDistance = BakedTrainingRoom.cameraSafeHalfExtents.y / cos(rig.orbitElevation)
            XCTAssertEqual(rig.orbitDistance,min(defaultDistance*1.08,wallDistance),accuracy:0.0002,
                           "Room clearance takes precedence over the 8% retreat allowance")
            if defaultDistance * 1.08 >= wallDistance {
                XCTAssertEqual(camera.position.z,BakedTrainingRoom.cameraSafeHalfExtents.y,accuracy:0.0002)
                XCTAssertEqual(rig.currentPivot.x,0,accuracy:0.0001)
                XCTAssertEqual(rig.currentPivot.z,0,accuracy:0.0001)
            }
            let minimumScale = projectedTableScale(view, rig)
            let limitEye = camera.position
            rig.handlePinch(scale:0.1); rig.snapToTarget()
            XCTAssertLessThan((camera.position-limitEye).length(),0.0001)
            for degree in [-120,-45,45,120] {
                let heading = Float(degree)*Float.pi/180
                let cue = SCNVector3(-0.5,0.828575,0.1), aim = SCNVector3(cos(heading),0,sin(heading))
                XCTAssertTrue(rig.enterPlayerView(.thirdPerson,cue:cue,aim:aim,focus:cue))
                rig.update(deltaTime:2)
                let pivot = rig.currentPivot, yaw = rig.currentYaw, elevation = rig.orbitElevation
                let startDistance = rig.orbitDistance
                rig.handlePinch(scale:0.98); rig.snapToTarget()
                XCTAssertLessThanOrEqual(rig.orbitDistance/startDistance,1/0.98+0.0001,"Small pinch cannot cause a full-table refit")
                rig.handlePinch(scale:0.01); rig.snapToTarget()
                XCTAssertLessThan((rig.currentPivot-pivot).length(),0.00001)
                XCTAssertEqual(rig.currentYaw,yaw,accuracy:0.00001)
                XCTAssertEqual(rig.orbitElevation,elevation,accuracy:0.00001)
                XCTAssertLessThanOrEqual(rig.orbitDistance, startDistance * 1.15 + 0.0002,
                                         "Observation may retreat at most 15% from its standard pose")
                XCTAssertGreaterThanOrEqual(projectedTableScale(view,rig),minimumScale - 0.0002,
                                             "Observation's stricter cap must still respect the global minimum table scale")
                XCTAssertFalse(rig.keepsWholeTableFramed)
            }
        }
    }
}

extension DailyShotCameraTests {
    func testDailyDollyZoomReversesAndSurvivesPerspectiveRoundTrip() throws {
        let (_, rig, camera) = dailyRig()
        let cue = SCNVector3(-0.5,0.828575,0.1)
        rig.enterPlayerView(.thirdPerson,cue:cue,aim:SCNVector3(1,0,0)); rig.update(deltaTime:2)
        let baseDistance = rig.orbitDistance, baseEye = camera.position
        let baseFOV = try XCTUnwrap(camera.camera).fieldOfView
        rig.handlePinch(scale:0.5); rig.snapToTarget()
        XCTAssertGreaterThan(rig.orbitDistance,baseDistance)
        let state = rig.capturePerspectiveState()
        rig.applyTopDown2D(); rig.restorePerspectiveState(state)
        rig.handlePinch(scale:2); rig.snapToTarget()
        XCTAssertEqual(rig.orbitDistance,baseDistance,accuracy:0.0001)
        // The outgoing gesture reached the far clamp, so its unused fraction is discarded.
        // Continue inwards to verify that optical zoom resumes after dolly is undone.
        for _ in 0..<5 { rig.handlePinch(scale:2); rig.snapToTarget() }
        XCTAssertEqual(rig.orbitDistance,baseDistance,accuracy:0.0001)
        XCTAssertLessThan((camera.position-baseEye).length(),0.0001)
        XCTAssertLessThan(try XCTUnwrap(camera.camera).fieldOfView,baseFOV)
    }

    func testLowObservationCanZoomOutByVisibleSpanAndOverviewTurnKeepsCornersVisible() throws {
        let (view, rig, camera) = dailyRig()
        rig.observeWholeTable(yaw:.pi/2); rig.snapToTarget()
        rig.handlePinch(scale:1.3); rig.snapToTarget()
        rig.handleVerticalSwipe(delta:-1000); rig.snapToTarget()
        let lowDistance = rig.orbitDistance
        let fov = try XCTUnwrap(camera.camera).fieldOfView
        let span = projectedTableScale(view,rig)
        rig.handlePinch(scale:0.95); rig.snapToTarget()
        XCTAssertGreaterThan(try XCTUnwrap(camera.camera).fieldOfView,fov,
                             "The low eye at a wall can shrink continuously through its optical zoom range")
        XCTAssertEqual(projectedTableScale(view,rig)/span,0.95,accuracy:0.0002,
                       "Actual SceneKit projection must shrink by the requested pinch fraction")
        XCTAssertEqual(rig.orbitDistance,lowDistance,accuracy:0.0002)
        XCTAssertLessThanOrEqual(abs(camera.position.z),BakedTrainingRoom.cameraSafeHalfExtents.y+0.0001)
        for degree in [0,30,45,150,180,-30,-150] {
            rig.observeWholeTable(yaw:Float(degree)*Float.pi/180); rig.snapToTarget()
            rig.observeDailyWholeTable(aimDirection:SCNVector3(0,0,1))
            for _ in 0..<180 {
                rig.update(deltaTime:1/120)
                SCNTransaction.flush()
                for x in [-Float(rig.tableOuterHalfLength),Float(rig.tableOuterHalfLength)] {
                    for z in [-Float(rig.tableOuterHalfWidth),Float(rig.tableOuterHalfWidth)] {
                        let p = view.projectPoint(SCNVector3(x,0.8,z))
                        XCTAssertGreaterThanOrEqual(p.x,0); XCTAssertLessThanOrEqual(p.x,Float(view.bounds.width))
                        XCTAssertGreaterThanOrEqual(p.y,0); XCTAssertLessThanOrEqual(p.y,Float(view.bounds.height))
                    }
                }
            }
        }
    }
}

extension DailyShotCameraTests {
    func testDailyFirstPersonZoomAndChangedPinchSubjectStayReversible() throws {
        for cue in [SCNVector3(-1,0.828575,0.45), SCNVector3(0.7,0.828575,-0.35)] {
            for i in 0..<8 {
                let (_, rig, camera) = dailyRig()
                let yaw = Float(i)*Float.pi/4, aim = SCNVector3(cos(yaw),0,sin(yaw))
                rig.enterPlayerView(.firstPerson,cue:cue,aim:aim); rig.update(deltaTime:2)
                rig.handlePinch(scale:0.01); rig.snapToTarget()
                XCTAssertTrue(rig.orbitDistance.isFinite)
                XCTAssertLessThan(rig.orbitDistance,10)
                let farEye = camera.position
                let subject = SCNVector3(cue.x*0.5,0.828575,cue.z*0.5)
                rig.beginObservationPinch(at:subject); rig.snapToTarget()
                XCTAssertLessThan((camera.position-farEye).length(),0.0002,"Changing pinch subject keeps the visible eye")
                let farDistance = rig.orbitDistance
                let state = rig.capturePerspectiveState()
                rig.applyTopDown2D(); rig.restorePerspectiveState(state)
                for _ in 0..<8 { rig.handlePinch(scale:2); rig.snapToTarget() }
                XCTAssertLessThanOrEqual(rig.orbitDistance,farDistance)
                XCTAssertLessThan(((camera.position-subject).normalized()-(farEye-subject).normalized()).length(),0.0002)
                XCTAssertLessThan((rig.currentPivot-subject).length(),0.0001)
                XCTAssertEqual(try XCTUnwrap(camera.camera).fieldOfView,
                               Double(CameraRig.dailyFOV(viewport:viewport,close:true)),accuracy:0.0001)
            }
        }
    }
}

extension DailyShotCameraTests {
    func testRepeatedOverviewDuringPlayerDepartureDoesNotSnapDistance() {
        let (_, rig, _) = dailyRig()
        rig.enterPlayerView(.firstPerson,cue:SCNVector3(-0.5,0.828575,0.1),aim:SCNVector3(1,0,0))
        rig.update(deltaTime:2)
        rig.observeDailyWholeTable(aimDirection:nil); rig.update(deltaTime:0.1)
        let visibleDistance = rig.orbitDistance
        rig.observeDailyWholeTable(aimDirection:nil)
        XCTAssertEqual(rig.orbitDistance,visibleDistance,accuracy:0.00001)
        rig.update(deltaTime:1/120)
        XCTAssertLessThan(rig.orbitDistance-visibleDistance,0.25,"Repeated global intent must not mistake an unfinished departure for a fully framed table")
    }
}

extension DailyShotCameraTests {
    func testDailyOverviewUses35DegreesAndSharedHostsKeep45Degrees() throws {
        XCTAssertEqual(CameraRig.Config.dailyClearance.standPitchRad,-35 * .pi / 180,accuracy:0.00001)
        XCTAssertEqual(CameraRig.Config.default.standPitchRad,-45 * .pi / 180,accuracy:0.00001)
        XCTAssertEqual(AimingCameraConfig.standPitchRad,-45 * .pi / 180,accuracy:0.00001)
        for size in [viewport,CGSize(width:1194,height:834),CGSize(width:402,height:640)] {
            for (config,degrees) in [(CameraRig.Config.dailyClearance,Float(35)),(.default,Float(45))] {
                let camera = SCNNode(); camera.camera = SCNCamera()
                let rig = CameraRig(cameraNode:camera,tableSurfaceY:0.8,config:config)
                // Shared shot-aware hosts must keep their 45° global pitch too.
                rig.usesShotAwareCamera = true; rig.usesRailCameraControls = true
                rig.viewportSize = size
                for yaw: Float in [-.pi/2,.pi/2] {
                    XCTAssertTrue(rig.observeWholeTable(yaw:yaw))
                    rig.snapToTarget()
                    XCTAssertEqual(rig.orbitElevation,degrees * .pi / 180,accuracy:0.00001)
                    XCTAssertEqual(camera.eulerAngles.x,-degrees * .pi / 180,accuracy:0.00001)
                    XCTAssertEqual(rig.currentYaw,yaw,accuracy:0.00001)
                    XCTAssertEqual(rig.currentPivot.x,0,accuracy:0.00001)
                    XCTAssertEqual(rig.currentPivot.z,0,accuracy:0.00001)
                }
            }
        }
    }

    func testSharedShotAwareHostKeepsExistingZoomBoundary() {
        XCTAssertFalse(CameraRig.Config.default.usesDailyZoomBoundary)
        XCTAssertTrue(CameraRig.Config.dailyClearance.usesDailyZoomBoundary)
        let camera = SCNNode(); camera.camera = SCNCamera()
        let rig = CameraRig(cameraNode:camera,tableSurfaceY:0.8)
        rig.viewportSize=viewport; rig.usesRailCameraControls=true; rig.usesShotAwareCamera=true
        rig.enterPlayerView(.thirdPerson,cue:SCNVector3(0.5,0.828575,0.1),aim:SCNVector3(1,0,0))
        rig.update(deltaTime:2)
        rig.handlePinch(scale:0.9); rig.snapToTarget()
        XCTAssertTrue(rig.keepsWholeTableFramed,"Only the daily config changes the legacy shrink-boundary intent")
        XCTAssertEqual(rig.currentPivot.x,0,accuracy:0.00001)
        XCTAssertEqual(rig.currentPivot.z,0,accuracy:0.00001)
    }
}

extension DailyShotCameraTests {
    /// SceneKit metres: X/Z table plane, Y up. These expectations come from
    /// the standard shot-relative stance, independently of context fitting.
    func testDailyObservationStandardEyeDoesNotRetreatToFitLongBallContext() throws {
        for cue in [SCNVector3(-1.2,0.828575,-0.56), SCNVector3(1.2,0.828575,0.56)] {
            for i in 0..<8 {
                let (_, rig, camera) = dailyRig()
                let heading = Float(i) * .pi / 4
                let aim = SCNVector3(cos(heading),0,sin(heading))
                let target = SCNVector3(-cue.x, cue.y, -cue.z)
                let strike = cue + SCNVector3(0,0.003,0)
                let elevation: Float = 0.40
                rig.updateCuePose(strike:strike,aim:aim,elevation:elevation)
                for context in [[SCNVector3](), [cue,target]] {
                    rig.observationCandidates = context
                    XCTAssertTrue(rig.enterPlayerView(.thirdPerson,cue:cue,aim:aim,focus:target))
                    rig.update(deltaTime:2)
                    let expected = SCNVector3(strike.x-aim.x*1.65,
                        max(0.8+0.90,strike.y+1.65*tan(elevation)+0.35),strike.z-aim.z*1.65)
                    XCTAssertLessThan((camera.position-expected).length(),0.0002,
                                      "Long-ball context must not dolly the standard observation eye away")
                    XCTAssertLessThan((rig.currentPivot-target).length(),0.0001)
                }
            }
        }
    }

    func testExplicitDailyObservationReentryResetsZoomAndVerticalOrbit() throws {
        let cue = SCNVector3(-0.55,0.828575,0.12), aim = SCNVector3(1,0,0)
        let target = SCNVector3(0.65,cue.y,0.12)
        for zoom: Float in [0.01,100] {
            for vertical: Float in [-160,160] {
                let (_, rig, camera) = dailyRig()
                rig.observationCandidates = [cue,target]
                XCTAssertTrue(rig.enterPlayerView(.thirdPerson,cue:cue,aim:aim,focus:target))
                rig.update(deltaTime:2)
                let eye = camera.position, rotation = camera.eulerAngles
                let distance = rig.orbitDistance
                let fov = try XCTUnwrap(camera.camera).fieldOfView
                rig.handlePinch(scale:zoom); rig.handleVerticalSwipe(delta:vertical)
                for _ in 0..<120 { rig.update(deltaTime:1/60) }
                XCTAssertGreaterThan((camera.position-eye).length(),0.01,
                                     "The fixture must actually change observation before reentry")
                XCTAssertTrue(rig.enterPlayerView(.thirdPerson,cue:cue,aim:aim,focus:target))
                rig.update(deltaTime:2)
                XCTAssertLessThan((camera.position-eye).length(),0.0002,
                                  "An explicit observation request resets the current observation directly")
                XCTAssertLessThan((camera.eulerAngles-rotation).length(),0.0002)
                XCTAssertEqual(try XCTUnwrap(camera.camera).fieldOfView,fov,accuracy:0.0001)
                rig.handlePinch(scale:zoom); rig.handleVerticalSwipe(delta:vertical)
                for _ in 0..<120 { rig.update(deltaTime:1/60) }
                for departure in [CameraRig.PlayerView.firstPerson,.thirdPerson] {
                    if departure == .firstPerson {
                        XCTAssertTrue(rig.enterPlayerView(.firstPerson,cue:cue,aim:aim))
                        rig.update(deltaTime:2)
                    } else {
                        XCTAssertTrue(rig.observeDailyWholeTable(aimDirection:aim))
                        rig.update(deltaTime:2)
                    }
                    XCTAssertTrue(rig.enterPlayerView(.thirdPerson,cue:cue,aim:aim,focus:target))
                    rig.update(deltaTime:2)
                    XCTAssertLessThan((camera.position-eye).length(),0.0002)
                    XCTAssertLessThan((camera.eulerAngles-rotation).length(),0.0002)
                    XCTAssertEqual(rig.orbitDistance,distance,accuracy:0.0002)
                    XCTAssertEqual(try XCTUnwrap(camera.camera).fieldOfView,fov,accuracy:0.0001)
                    rig.handlePinch(scale:zoom); rig.handleVerticalSwipe(delta:vertical)
                    for _ in 0..<120 { rig.update(deltaTime:1/60) }
                }
            }
        }
    }

    func testDailyObservationMaximumRetreatTracksEachNewStandardPose() throws {
        let (_, rig, camera) = dailyRig()
        for (cue,aim,elevation) in [
            (SCNVector3(-0.4,0.828575,0.1),SCNVector3(1,0,0),Float(0.05)),
            (SCNVector3(0.4,0.828575,-0.1),SCNVector3(0,0,1),Float(0.40))
        ] {
            rig.updateCuePose(strike:cue,aim:aim,elevation:elevation)
            XCTAssertTrue(rig.enterPlayerView(.thirdPerson,cue:cue,aim:aim))
            rig.update(deltaTime:2)
            let distance = rig.orbitDistance, pivot = rig.currentPivot
            let direction = (camera.position-pivot).normalized()
            rig.handlePinch(scale:0.01)
            for _ in 0..<120 {
                rig.update(deltaTime:1/60)
                XCTAssertLessThanOrEqual((camera.position-pivot).length(),distance*1.15+0.0002)
            }
            XCTAssertEqual(rig.orbitDistance,distance*1.15,accuracy:0.0002)
            let farEye = camera.position
            rig.handlePinch(scale:0.01); rig.snapToTarget()
            XCTAssertLessThan((camera.position-farEye).length(),0.0002)
            XCTAssertLessThan(((camera.position-pivot).normalized()-direction).length(),0.0002)
            rig.handlePinch(scale:1.02); rig.snapToTarget()
            XCTAssertLessThan((camera.position-pivot).length(),distance*1.15-0.001,
                              "A reverse pinch must leave the far boundary immediately")
        }
    }

    func testDailyCameraStaysInsideRoomDuringCornerShotsAndExtremeGesturesEveryFrame() throws {
        // All room styles share an 8m x 6m shell. The 0.35m inset keeps the
        // perspective eye away from opaque walls instead of allowing it outside.
        for cueX: Float in [-1.20,1.20] {
            for cueZ: Float in [-0.56,0.56] {
                for i in 0..<8 {
                    let (_, rig, camera) = dailyRig()
                    let cue = SCNVector3(cueX,0.828575,cueZ)
                    let target = SCNVector3(-cueX,cue.y,-cueZ)
                    let heading = Float(i)*Float.pi/4, aim = SCNVector3(cos(heading),0,sin(heading))
                    rig.observationCandidates = [cue,target]
                    func advance(_ frames: Int = 120) {
                        for _ in 0..<frames {
                            rig.update(deltaTime:1/60)
                            XCTAssertTrue(camera.position.x.isFinite && camera.position.y.isFinite && camera.position.z.isFinite)
                            XCTAssertLessThanOrEqual(abs(camera.position.x),BakedTrainingRoom.cameraSafeHalfExtents.x+0.0001,"cue=\(cue) heading=\(i)")
                            XCTAssertLessThanOrEqual(abs(camera.position.z),BakedTrainingRoom.cameraSafeHalfExtents.y+0.0001,"cue=\(cue) heading=\(i)")
                        }
                    }
                    for mode in [CameraRig.PlayerView.thirdPerson,.firstPerson] {
                        XCTAssertTrue(rig.enterPlayerView(mode,cue:cue,aim:aim,focus:mode == .thirdPerson ? target:nil))
                        advance()
                        for vertical: Float in [-10000,10000] {
                            rig.handlePinch(scale:0.01); rig.handleVerticalSwipe(delta:vertical)
                            advance()
                            for _ in 0..<8 {
                                rig.handleHorizontalSwipe(delta:Float.pi/4/0.0025)
                                advance(30)
                            }
                            rig.handlePinch(scale:100); advance()
                        }
                    }
                    XCTAssertTrue(rig.observeDailyWholeTable(aimDirection:aim)); advance()
                    rig.handleVerticalSwipe(delta:-10000); rig.handlePinch(scale:0.01); advance()
                    for _ in 0..<8 { rig.handleHorizontalSwipe(delta:Float.pi/4/0.0025); advance(30) }
                }
            }
        }
    }
}

extension DailyShotCameraTests {
    private struct PocketObservationFixture {
        let cue: SCNVector3
        let target: SCNVector3
        let pocket: Int
        let aim: SCNVector3
        let elevation: Float
    }

    /// Frozen UI review inputs. Heading and elevation are actual solver outputs
    /// from twelve-before/formation-N-standard.txt, not camera fit expectations.
    private var pocketObservationFixtures: [PocketObservationFixture] {
        let rows: [(Float,Float,Float,Float,Int,Float,Float)] = [
            (-1.05,-0.34,0.80,0.36,3,3.4984474,0.06898956),
            (0.25,0.04,0.58,0.22,3,3.6326256,0.05),
            (-0.65,0.48,0.05,0.05,4,2.6547203,0.050740503),
            (-1.229,-0.40,-0.40,-0.03,3,3.5647497,0.33228528),
            (-0.35,-0.592,0.45,0.20,3,3.9383836,0.2533375),
            (1.05,0.34,-0.80,-0.36,0,0.35685492,0.06898956),
            (0.25,-0.30,1.20,0.32,3,3.6811137,0.05),
            (0.35,0.592,-0.45,-0.20,0,0.7967913,0.2533375),
            (-0.80,-0.12,-0.12,0.30,5,3.6448588,0.05),
            (0.80,0.12,0.12,-0.30,4,0.5032666,0.05),
            (-0.95,-0.55,0.70,-0.52,1,3.1667185,0.052206136),
            (0.75,-0.40,-0.55,0.25,2,5.820463,0.05)
        ]
        return rows.map { x,z,tx,tz,pocket,yaw,elevation in
            PocketObservationFixture(cue:SCNVector3(x,0.8+BallPhysics.radius,z),
                target:SCNVector3(tx,0.8+BallPhysics.radius,tz),pocket:pocket,
                aim:SCNVector3(-cos(yaw),0,-sin(yaw)),elevation:elevation)
        }
    }

    private func enterPocketObservation(_ fixture: PocketObservationFixture, rig: CameraRig) throws {
        let pocket = AngleSceneCalculator.pocketMarkerPositions(surfaceY:0.8)[fixture.pocket]
        rig.observationCandidates = [fixture.cue,fixture.target]
        rig.observationPocket = (fixture.pocket,pocket)
        rig.updateCuePose(strike:fixture.cue,aim:fixture.aim,elevation:fixture.elevation)
        XCTAssertTrue(rig.enterPlayerView(.thirdPerson,cue:fixture.cue,aim:fixture.aim,focus:fixture.cue))
        rig.update(deltaTime:2)
    }

    /// SceneKit projects physical surface samples independently of the camera
    /// solver's angular basis or padding calculation.
    private func assertPocketObservationSurfacesInsideSafeRegion(
        _ fixture: PocketObservationFixture, view: SCNView, label: String, sphereResolution: Int = 12,
        safeFraction: CGFloat = 0.65
    ) {
        SCNTransaction.flush(); view.layoutIfNeeded()
        let inset = (1-safeFraction)/2
        let safe = view.bounds.insetBy(dx:view.bounds.width*inset,dy:view.bounds.height*inset)
        func check(_ point: SCNVector3, subject: String) {
            let p = view.projectPoint(point)
            XCTAssertTrue(p.x.isFinite && p.y.isFinite && p.z.isFinite,"\(label) \(subject)")
            XCTAssertGreaterThan(p.z,0,"\(label) \(subject)")
            XCTAssertLessThan(p.z,1,"\(label) \(subject)")
            XCTAssertGreaterThanOrEqual(CGFloat(p.x),safe.minX-0.05,"\(label) \(subject)")
            XCTAssertLessThanOrEqual(CGFloat(p.x),safe.maxX+0.05,"\(label) \(subject)")
            XCTAssertGreaterThanOrEqual(CGFloat(p.y),safe.minY-0.05,"\(label) \(subject)")
            XCTAssertLessThanOrEqual(CGFloat(p.y),safe.maxY+0.05,"\(label) \(subject)")
        }
        for (subject,center) in [("cue",fixture.cue),("target",fixture.target)] {
            check(center,subject:subject)
            for latitude in 0...sphereResolution {
                let phi = Float(latitude)*Float.pi/Float(sphereResolution)
                for longitude in 0..<(sphereResolution*2) {
                    let theta = Float(longitude)*Float.pi/Float(sphereResolution)
                    let offset = SCNVector3(sin(phi)*cos(theta),cos(phi),sin(phi)*sin(theta))*BallPhysics.radius
                    check(center+offset,subject:subject)
                }
            }
        }
        let pocket = AngleSceneCalculator.pocketMarkerPositions(surfaceY:0.8)[fixture.pocket]
        let radius = AngleSceneCalculator.pocketMarkerRadius(index:fixture.pocket)
        check(pocket,subject:"pocket")
        for i in 0..<32 {
            let angle = Float(i)*Float.pi/16
            check(pocket+SCNVector3(cos(angle)*radius,0,sin(angle)*radius),subject:"pocket rim")
        }
        // CAD drop-hole and cushion jaws are independent of the offset marker.
        let hole = AngleSceneCalculator.pocketPositions(surfaceY:0.8)[fixture.pocket]
        let holeRadius = AngleSceneCalculator.pocketDropRadius(index:fixture.pocket)
        for step in 0..<64 {
            let angle = Float(step)*Float.pi/32
            check(hole+SCNVector3(cos(angle)*holeRadius,0,sin(angle)*holeRadius),subject:"CAD hole rim")
        }
        let jaws = AngleSceneCalculator.pocketJaws(surfaceY:0.837)[fixture.pocket]
        for jaw in [jaws.0,jaws.1] {
            check(jaw,subject:"CAD jaw")
            for offset in [SCNVector3(0.003,0,0),SCNVector3(-0.003,0,0),
                           SCNVector3(0,0.003,0),SCNVector3(0,-0.003,0),
                           SCNVector3(0,0,0.003),SCNVector3(0,0,-0.003)] {
                check(jaw+offset,subject:"CAD jaw margin")
            }
        }
    }

    func testDailyPocketObservationFramesBothBallsAndPocketSurfacesAcrossTwelveFormations() throws {
        XCTAssertEqual(pocketObservationFixtures.count,12)
        for size in [viewport,CGSize(width:1194,height:834)] {
            for (index,fixture) in pocketObservationFixtures.enumerated() {
                let (view,rig,camera) = dailyRig(size:size)
                try enterPocketObservation(fixture,rig:rig)
                assertPocketObservationSurfacesInsideSafeRegion(fixture,view:view,label:"size=\(size) fixture=\(index)")
                let fov = try XCTUnwrap(camera.camera).fieldOfView
                XCTAssertGreaterThan(fov,Double(CameraRig.dailyFOV(viewport:size)),"Observation uses a wider lens than global")
                let aspect = Float(size.width/size.height)
                let baselineFOV = min(Float(45),2*atan(tan(35 * Float.pi/180)/aspect)*180/Float.pi)
                XCTAssertGreaterThanOrEqual(fov,Double(baselineFOV)-0.0001)
                let setback = hypot(camera.position.x-fixture.cue.x,camera.position.z-fixture.cue.z)
                XCTAssertLessThanOrEqual(setback,1.6502,"Fit expands the lens instead of retreating the standard eye")
                XCTAssertGreaterThanOrEqual(camera.position.y,1.6999)
            }
        }
    }

    func testNearRailPocketObservationClearsLowerVisibleBallEdgeByIndependentSightline() throws {
        for index in [3,4,7] {
            let fixture = pocketObservationFixtures[index]
            let (_,rig,camera) = dailyRig()
            try enterPocketObservation(fixture,rig:rig)
            let eye = camera.position
            XCTAssertLessThan(hypot(eye.x-fixture.cue.x,eye.z-fixture.cue.z),1.64,
                              "Near-rail baseline fixture \(index) must move the eye closer")
            // Allow the bottom 10% of one radius at the cloth contact point;
            // check the remaining visible lower outline against actual rail Y.
            let edge = fixture.cue-SCNVector3(0,BallPhysics.radius*0.9,0)
            var crossings: [SCNVector3] = []
            for (origin,destination,extent) in [(eye.x,edge.x,Float(1.27)),(eye.z,edge.z,Float(0.635))] {
                for boundary in [-extent,extent] where abs(destination-origin)>0.000001 {
                    let t = (boundary-origin)/(destination-origin)
                    guard t>0, t<1 else { continue }
                    let point = eye+(edge-eye)*t
                    if abs(point.x)<=1.27001 && abs(point.z)<=0.63501 { crossings.append(point) }
                }
            }
            XCTAssertFalse(crossings.isEmpty,"The fixture must actually look across a cushion")
            for crossing in crossings {
                XCTAssertGreaterThanOrEqual(crossing.y,0.837-0.00002,
                                            "fixture=\(index): the visible lower outline clears the rail nose")
            }
        }
    }

    func testPocketObservationVerticalLookKeepsEyeThrough2DRestoreAndExplicitReset() throws {
        for (index,fixture) in pocketObservationFixtures.enumerated() {
            let (_,rig,camera) = dailyRig()
            try enterPocketObservation(fixture,rig:rig)
            let eye = camera.position, standardPitch = camera.eulerAngles.x
            for delta: Float in [30,-30] {
                try enterPocketObservation(fixture,rig:rig)
                let state = rig.capturePerspectiveState()
                rig.applyTopDown2D(); rig.restorePerspectiveState(state)
                rig.handleVerticalSwipe(delta:delta)
                for _ in 0..<120 {
                    rig.update(deltaTime:1/60)
                    XCTAssertLessThan((camera.position-eye).length(),0.0002,"fixture=\(index): vertical look keeps eye after 2D")
                }
                XCTAssertGreaterThan(abs(camera.eulerAngles.x-standardPitch),0.0001,"Vertical input must actually change gaze")
                try enterPocketObservation(fixture,rig:rig)
                XCTAssertEqual(camera.eulerAngles.x,standardPitch,accuracy:0.0001)
                XCTAssertLessThan((camera.position-eye).length(),0.0002)
            }
        }
    }

    func testPocketObservationZoomAndLookAreDiscardedOnExplicitReentry() throws {
        for fixture in pocketObservationFixtures {
            for zoom: Float in [0.01,100] {
                let (_,rig,camera) = dailyRig()
                try enterPocketObservation(fixture,rig:rig)
                let standardEye = camera.position, standardRotation = camera.eulerAngles
                let standardFOV = try XCTUnwrap(camera.camera).fieldOfView
                let standardDistance = rig.orbitDistance
                let pivot = rig.currentPivot
                rig.beginObservationPinch(at:fixture.target)
                rig.snapToTarget()
                XCTAssertLessThan((rig.currentPivot-pivot).length(),0.0001,"Pinch must not replace the three-subject gaze center")
                XCTAssertLessThan((camera.position-standardEye).length(),0.0002)
                rig.handlePinch(scale:zoom); rig.snapToTarget()
                let zoomEye = camera.position
                rig.handleVerticalSwipe(delta:60)
                for _ in 0..<120 {
                    rig.update(deltaTime:1/60)
                    XCTAssertLessThan((camera.position-zoomEye).length(),0.0002)
                }
                let changed = rig.capturePerspectiveState()
                rig.applyTopDown2D(); rig.restorePerspectiveState(changed)
                XCTAssertLessThan((camera.position-zoomEye).length(),0.0002)
                try enterPocketObservation(fixture,rig:rig)
                XCTAssertLessThan((camera.position-standardEye).length(),0.0002)
                XCTAssertLessThan((camera.eulerAngles-standardRotation).length(),0.0002)
                XCTAssertEqual(try XCTUnwrap(camera.camera).fieldOfView,standardFOV,accuracy:0.0001)
                XCTAssertEqual(rig.orbitDistance,standardDistance,accuracy:0.0002)
            }
        }
    }

    func testSharedHostAndDailyWithoutPocketRetainVerticalOrbit() throws {
        let fixture = pocketObservationFixtures[1]
        for (config,hasPocket) in [(CameraRig.Config.default,true),(.dailyClearance,false)] {
            let camera = SCNNode(); camera.camera = SCNCamera()
            let rig = CameraRig(cameraNode:camera,tableSurfaceY:0.8,config:config)
            rig.viewportSize = viewport; rig.usesShotAwareCamera = true; rig.usesRailCameraControls = true
            rig.observationCandidates = [fixture.cue,fixture.target]
            if hasPocket { rig.observationPocket=(fixture.pocket,AngleSceneCalculator.pocketMarkerPositions(surfaceY:0.8)[fixture.pocket]) }
            rig.updateCuePose(strike:fixture.cue,aim:fixture.aim,elevation:fixture.elevation)
            XCTAssertTrue(rig.enterPlayerView(.thirdPerson,cue:fixture.cue,aim:fixture.aim))
            rig.update(deltaTime:2)
            let eye = camera.position
            rig.handleVerticalSwipe(delta:40)
            for _ in 0..<120 { rig.update(deltaTime:1/60) }
            XCTAssertGreaterThan((camera.position-eye).length(),0.01,"Only Daily with a pocket uses fixed-eye vertical look")
        }
    }

    func testGeneratedSixPocketLayoutsKeepNaturalLensPhysicalSurfacesAndSightlines() throws {
        let physicalPockets = AngleSceneCalculator.pocketPositions(surfaceY:0.8)
        let r = BallPhysics.radius
        var counts = [Int](repeating:0,count:6)
        var nearRailCount = 0, shortCount = 0, thinCount = 0
        var maximumVerticalFOV: Double = 0, maximumHorizontalFOV: Double = 0
        func isLegalCenter(_ point: SCNVector3) -> Bool {
            abs(point.x)+r <= 1.27 && abs(point.z)+r <= 0.635
        }
        let sizes = [viewport,CGSize(width:667,height:375),CGSize(width:1366,height:1024)]
        for size in sizes {
            let (view,rig,camera) = dailyRig(size:size)
            let beforeCount = counts.reduce(0,+)
            for pocket in 0..<6 {
                for x: Float in [-1.18,-0.65,0,0.65,1.18] {
                    for z: Float in [-0.56,-0.30,0,0.30,0.56] {
                        let target = SCNVector3(x,0.8+r,z)
                        let pot = (physicalPockets[pocket]-SCNVector3(x,0.8,z)).normalized()
                        let ghost = target-pot*(2*r)
                        guard isLegalCenter(target), isLegalCenter(ghost) else { continue }
                        for gap: Float in [0.12,0.60,1.40] {
                            for degrees: Float in [-75,-45,-15,0,15,45,75] {
                                let angle = degrees*Float.pi/180
                                let aim = SCNVector3(pot.x*cos(angle)-pot.z*sin(angle),0,
                                                    pot.x*sin(angle)+pot.z*cos(angle))
                                let cue = ghost-aim*gap
                                guard isLegalCenter(cue), (target-cue).length()>2*r,
                                      (target.x-cue.x)*aim.x+(target.z-cue.z)*aim.z>0 else { continue }
                                XCTAssertEqual((target-ghost).length(),2*r,accuracy:0.00001)
                                XCTAssertEqual((ghost-cue).length(),gap,accuracy:0.00001)
                                let fixture = PocketObservationFixture(cue:cue,target:target,pocket:pocket,
                                                                      aim:aim,elevation:0.05)
                                try enterPocketObservation(fixture,rig:rig)
                                let label = "viewport=\(size) pocket=\(pocket) target=(\(x),\(z)) gap=\(gap) cut=\(degrees)"
                                assertPocketObservationSurfacesInsideSafeRegion(fixture,view:view,label:label,sphereResolution:4)
                                let eye = camera.position
                                let fov = try XCTUnwrap(camera.camera).fieldOfView
                                XCTAssertTrue(eye.x.isFinite && eye.y.isFinite && eye.z.isFinite && fov.isFinite,label)
                                XCTAssertGreaterThan(fov,0,label)
                                XCTAssertLessThanOrEqual(fov,55.0001,"Bounded natural vertical lens: \(label)")
                                let horizontalFOV = 2*atan(tan(fov*Double.pi/360)*Double(size.width/size.height))*180/Double.pi
                                XCTAssertLessThanOrEqual(horizontalFOV,85.0001,"Bounded natural horizontal lens: \(label)")
                                maximumHorizontalFOV = max(maximumHorizontalFOV,horizontalFOV)
                                maximumVerticalFOV = max(maximumVerticalFOV,fov)
                                let setback = hypot(eye.x-cue.x,eye.z-cue.z)
                                XCTAssertLessThanOrEqual(setback,1.7002,label)
                                XCTAssertGreaterThan(setback,0,label)
                                XCTAssertLessThanOrEqual(abs(eye.x),BakedTrainingRoom.cameraSafeHalfExtents.x+0.0001,label)
                                XCTAssertLessThanOrEqual(abs(eye.z),BakedTrainingRoom.cameraSafeHalfExtents.y+0.0001,label)
                                // Independent straight shaft geometry: the head stays
                                // above the shot's shaft at the eye's backwards station.
                                let station = (cue.x-eye.x)*aim.x+(cue.z-eye.z)*aim.z
                                XCTAssertLessThanOrEqual(station,1.6502,"Local side fallback cannot increase backwards retreat: \(label)")
                                let shaftY = cue.y+station*tan(fixture.elevation)
                                XCTAssertGreaterThanOrEqual(eye.y-shaftY,0.3499,label)
                                let edge = cue-SCNVector3(0,r*0.9,0)
                                for (start,end,extent) in [(eye.x,edge.x,Float(1.27)),(eye.z,edge.z,Float(0.635))] {
                                    for boundary in [-extent,extent] where abs(end-start)>0.000001 {
                                        let t = (boundary-start)/(end-start)
                                        guard t>0, t<1 else { continue }
                                        let crossing = eye+(edge-eye)*t
                                        if abs(crossing.x)<=1.27001 && abs(crossing.z)<=0.63501 {
                                            XCTAssertGreaterThanOrEqual(crossing.y,0.837-0.00002,label)
                                        }
                                    }
                                }
                                counts[pocket] += 1
                                if min(1.27-abs(cue.x),0.635-abs(cue.z))<0.075 { nearRailCount += 1 }
                                if gap == 0.12 { shortCount += 1 }
                                if abs(degrees) == 75 { thinCount += 1 }
                            }
                        }
                    }
                }
            }
            XCTAssertEqual(counts.reduce(0,+)-beforeCount,1024,"Each aspect ratio must run the entire layout set")
        }
        XCTAssertEqual(counts,[567,567,567,567,402,402],"Every six-pocket family must actually run")
        XCTAssertEqual(counts.reduce(0,+),3072)
        XCTAssertGreaterThan(nearRailCount,0); XCTAssertEqual(shortCount,1824); XCTAssertGreaterThan(thinCount,0)
        print("[DailyPocketObservationGenerated] cases=\(counts.reduce(0,+)) perPocket=\(counts) nearRail=\(nearRailCount) short=\(shortCount) thin=\(thinCount) maximumVerticalFOV=\(maximumVerticalFOV) maximumHorizontalFOV=\(maximumHorizontalFOV)")
    }

    func testShortStraightPairsImproveActualEyeAngularSeparationWithoutUnnecessaryRetreatChanges() throws {
        let r = BallPhysics.radius
        let holes = AngleSceneCalculator.pocketPositions(surfaceY:0.8)
        func separation(eye: SCNVector3, cue: SCNVector3, target: SCNVector3) -> Double {
            let a = cue-eye, b = target-eye
            let al = sqrt(Double(a.x)*Double(a.x)+Double(a.y)*Double(a.y)+Double(a.z)*Double(a.z))
            let bl = sqrt(Double(b.x)*Double(b.x)+Double(b.y)*Double(b.y)+Double(b.z)*Double(b.z))
            let cosine = (Double(a.x)*Double(b.x)+Double(a.y)*Double(b.y)+Double(a.z)*Double(b.z))/(al*bl)
            return acos(max(-1,min(1,cosine)))/(asin(Double(r)/al)+asin(Double(r)/bl))
        }
        for size in [viewport,CGSize(width:667,height:375),CGSize(width:1366,height:1024)] {
            for (target,pocket) in [(SCNVector3(0.62,0.8+r,-0.30),4),
                                    (SCNVector3(-0.62,0.8+r,0.30),5)] {
                let aim = (holes[pocket]-SCNVector3(target.x,0.8,target.z)).normalized()
                for gap: Float in [0.002,0.12] {
                    let cue = target-aim*(2*r+gap)
                    XCTAssertGreaterThan((target-cue).length(),2*r,"Counterexample must not overlap balls")
                    let fixture = PocketObservationFixture(cue:cue,target:target,pocket:pocket,aim:aim,elevation:0.05)
                    let (view,rig,camera) = dailyRig(size:size)
                    try enterPocketObservation(fixture,rig:rig)
                    let ratio = separation(eye:camera.position,cue:cue,target:target)
                    let setback = hypot(camera.position.x-cue.x,camera.position.z-cue.z)
                    if gap == 0.002 {
                        let previousEye = cue-aim*1.65+SCNVector3(0,1.7-cue.y,0)
                        XCTAssertLessThan(separation(eye:previousEye,cue:cue,target:target),0.50,
                                          "This fixture must expose the old severe outline overlap")
                        XCTAssertGreaterThanOrEqual(ratio,0.65-0.00005,
                                                    "Actual eye rays must improve the two physical ball outlines")
                        XCTAssertLessThan(setback,1.1,"Short pair requires a closer standing position")
                    } else {
                        XCTAssertGreaterThan(ratio,1.3)
                        XCTAssertEqual(setback,1.65,accuracy:0.0002,
                                       "A separated pair keeps the ordinary standard eye")
                    }
                    assertPocketObservationSurfacesInsideSafeRegion(fixture,view:view,
                        label:"short-pair size=\(size) pocket=\(pocket) gap=\(gap)")
                }
            }
        }
    }

    func testActualCADPocketMouthAndBallSurfacesStayClearThroughFixedEyeVerticalLimitsAnd2DRestore() throws {
        for size in [viewport,CGSize(width:667,height:375),CGSize(width:1366,height:1024)] {
            for (index,fixture) in pocketObservationFixtures.enumerated() {
                let (view,rig,camera) = dailyRig(size:size)
                try enterPocketObservation(fixture,rig:rig)
                assertPocketObservationSurfacesInsideSafeRegion(fixture,view:view,
                    label:"CAD standard size=\(size) fixture=\(index)")
                let standardEye = camera.position, standardPitch = camera.eulerAngles.x
                for delta: Float in [-10000,10000] {
                    try enterPocketObservation(fixture,rig:rig)
                    let standardState = rig.capturePerspectiveState()
                    rig.applyTopDown2D(); rig.restorePerspectiveState(standardState)
                    rig.handleVerticalSwipe(delta:delta)
                    for _ in 0..<120 {
                        rig.update(deltaTime:1/60)
                        XCTAssertLessThan((camera.position-standardEye).length(),0.0002,
                                          "Viewing the CAD mouth cannot lower or move the head")
                    }
                    XCTAssertGreaterThan(abs(camera.eulerAngles.x-standardPitch),0.0001,
                                         "The extreme swipe must actually change gaze")
                    assertPocketObservationSurfacesInsideSafeRegion(fixture,view:view,
                        label:"CAD vertical size=\(size) fixture=\(index) delta=\(delta)",safeFraction:0.82)
                    let adjustedState = rig.capturePerspectiveState()
                    rig.applyTopDown2D(); rig.restorePerspectiveState(adjustedState)
                    assertPocketObservationSurfacesInsideSafeRegion(fixture,view:view,
                        label:"CAD restored size=\(size) fixture=\(index) delta=\(delta)",safeFraction:0.82)
                    XCTAssertLessThan((camera.position-standardEye).length(),0.0002)
                }
            }
        }
    }

    func testOpticallyZoomedPocketObservationAllowsFixedEyeDetailLookAfter2DRestoreAndResetsOnEntry() throws {
        let fixture = pocketObservationFixtures[1]
        for size in [viewport,CGSize(width:667,height:375),CGSize(width:1366,height:1024)] {
            let (_,rig,camera) = dailyRig(size:size)
            try enterPocketObservation(fixture,rig:rig)
            let standardEye = camera.position, standardRotation = camera.eulerAngles
            let standardFOV = try XCTUnwrap(camera.camera).fieldOfView
            let standardDistance = rig.orbitDistance
            for delta: Float in [-120,120] {
                try enterPocketObservation(fixture,rig:rig)
                rig.handlePinch(scale:2); rig.snapToTarget()
                let detailEye = camera.position, detailPitch = camera.eulerAngles.x
                let detailFOV = try XCTUnwrap(camera.camera).fieldOfView
                XCTAssertLessThan(detailFOV,standardFOV*0.75,"The fixture must actually enter optical detail zoom")
                XCTAssertLessThan((detailEye-standardEye).length(),0.0002,"Optical zoom keeps the standard eye")
                let zoomedState = rig.capturePerspectiveState()
                rig.applyTopDown2D(); rig.restorePerspectiveState(zoomedState)
                XCTAssertEqual(try XCTUnwrap(camera.camera).fieldOfView,detailFOV,accuracy:0.0001)
                rig.handleVerticalSwipe(delta:delta)
                for _ in 0..<120 {
                    rig.update(deltaTime:1/60)
                    XCTAssertLessThan((camera.position-detailEye).length(),0.0002,
                                      "Detail inspection changes gaze while keeping the head fixed")
                }
                XCTAssertGreaterThan(abs(camera.eulerAngles.x-detailPitch),0.03,
                                     "Zoomed inspection must not be trapped by the three-subject wide framing limits")
                let adjustedPitch = camera.eulerAngles.x
                let inspectedState = rig.capturePerspectiveState()
                rig.applyTopDown2D(); rig.restorePerspectiveState(inspectedState)
                XCTAssertEqual(camera.eulerAngles.x,adjustedPitch,accuracy:0.0001)
                XCTAssertEqual(try XCTUnwrap(camera.camera).fieldOfView,detailFOV,accuracy:0.0001)
                rig.handleVerticalSwipe(delta:-delta)
                for _ in 0..<120 {
                    rig.update(deltaTime:1/60)
                    XCTAssertLessThan((camera.position-detailEye).length(),0.0002)
                }
                XCTAssertGreaterThan(abs(camera.eulerAngles.x-adjustedPitch),0.03,
                                     "2D restore must retain detail inspection gesture semantics")
                try enterPocketObservation(fixture,rig:rig)
                XCTAssertLessThan((camera.position-standardEye).length(),0.0002)
                XCTAssertLessThan((camera.eulerAngles-standardRotation).length(),0.0002)
                XCTAssertEqual(try XCTUnwrap(camera.camera).fieldOfView,standardFOV,accuracy:0.0001)
                XCTAssertEqual(rig.orbitDistance,standardDistance,accuracy:0.0002)
            }
        }
    }

    func testPocketObservationFreezesEntrySubjectsThroughMetadataChangesAnd2DRestore() throws {
        for index in [0,1,4] {
            let fixture = pocketObservationFixtures[index], next = pocketObservationFixtures[7]
            let (_,reference,referenceCamera) = dailyRig()
            let (_,candidate,candidateCamera) = dailyRig()
            try enterPocketObservation(fixture,rig:reference)
            try enterPocketObservation(fixture,rig:candidate)
            candidate.observationCandidates = [next.cue,next.target]
            candidate.observationPocket = (next.pocket,AngleSceneCalculator.pocketMarkerPositions(surfaceY:0.8)[next.pocket])
            for delta: Float in [80,-80] {
                reference.handleVerticalSwipe(delta:delta); candidate.handleVerticalSwipe(delta:delta)
                for _ in 0..<120 {
                    reference.update(deltaTime:1/60); candidate.update(deltaTime:1/60)
                    XCTAssertLessThan((candidateCamera.position-referenceCamera.position).length(),0.0002)
                    XCTAssertLessThan((candidateCamera.eulerAngles-referenceCamera.eulerAngles).length(),0.0002,
                                      "Pending metadata must not change the active observation gaze limits")
                    XCTAssertEqual(try XCTUnwrap(candidateCamera.camera).fieldOfView,
                                   try XCTUnwrap(referenceCamera.camera).fieldOfView,accuracy:0.0001)
                }
                let candidateState = candidate.capturePerspectiveState()
                let referenceState = reference.capturePerspectiveState()
                candidate.applyTopDown2D(); reference.applyTopDown2D()
                candidate.restorePerspectiveState(candidateState); reference.restorePerspectiveState(referenceState)
            }
            try enterPocketObservation(next,rig:reference)
            try enterPocketObservation(next,rig:candidate)
            XCTAssertLessThan((candidateCamera.position-referenceCamera.position).length(),0.0002,
                              "An explicit new entry must replace the frozen context")
            XCTAssertLessThan((candidateCamera.eulerAngles-referenceCamera.eulerAngles).length(),0.0002)
        }
    }
}
