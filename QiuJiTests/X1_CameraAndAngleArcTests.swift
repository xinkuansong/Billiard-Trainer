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

@MainActor
final class AngleDiagramAnnotationTests: XCTestCase {
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
    private var size: CGSize { is2K ? CGSize(width:1440,height:2560) : CGSize(width:1080,height:1920) }
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

    private func makeCapture(targetXZ: SIMD2<Float> = SIMD2<Float>(0, 0.10), pocketIndex: Int = 5) throws -> Capture {
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
            let distance: Float = 5.10
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

    private func setAngle(_ degrees: Double, _ c: Capture, centerDistance: Float? = nil) throws -> [String: Any] {
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
        XCTAssertLessThanOrEqual(direction.x, 0.00001)
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

    private func base(_ c: Capture, time: Double) -> UIImage {
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
            for label in angleLabels {
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

    private func drawTracks(_ c: Capture, nodes: inout [SCNNode], precise: Bool = false) throws -> [Int] {
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
                let steps=max(1,Int(ceil((end-contact.time)*240)))
                for step in 0...steps {
                    let time=contact.time+(end-contact.time)*Float(step)/Float(steps)
                    let state=try XCTUnwrap(recorder.stateAt(ballName:ShotInput.cueBallName,time:time))
                    path.append(state.position)
                }
            }
            counts.append(path.count)
            if path.count >= 2 {
                c.scene.addDashedPolyline(path,color:SeparationAngleAtlasGeometry.trackColor(at:i),
                    radius:TrajectoryStyle.lineMain,placement:.table,into:&nodes)
            }
        }
        SCNTransaction.flush()
        return counts
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

    private func composeDirectAtlas(_ shot:UIImage, angle:Double, parameters: String = "杆速 3 m/s  ·  球心距 60 cm", parameterBackground: Bool = true) -> UIImage {
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        return UIGraphicsImageRenderer(size:size,format:format).image { ctx in
            shot.draw(in:CGRect(origin:.zero,size:size))
            ctx.cgContext.scaleBy(x:size.width/1080,y:size.width/1080)
            func label(_ value:String,_ rect:CGRect,_ font:CGFloat,_ color:UIColor = .white) {
                let p=NSMutableParagraphStyle();p.alignment = .center
                (value as NSString).draw(in:rect,withAttributes:[.font:UIFont.systemFont(ofSize:font,weight:.semibold),.foregroundColor:color,.paragraphStyle:p])
            }
            let y:CGFloat=is3D ? 460 : 390
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
                SeparationAngleAtlasGeometry.trackColor(at:i).setFill()
                UIBezierPath(ovalIn:CGRect(x:x+33,y:y+33-CGFloat(spins[i])*43,width:20,height:20)).fill()
            }
            let parameterY:CGFloat=is3D ? 355 : 508
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
    private func seriesPredictions(_ c: Capture, speed: Float) throws -> [ShotPrediction] {
        let cue=try XCTUnwrap(c.scene.cueBallNode).position
        let d=simd_normalize(SIMD2<Float>(c.ghost.x-cue.x,c.ghost.z-cue.z))
        return SeparationAngleAtlasGeometry.spinYLevels().map { spin in
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
        let c=try makeCapture(targetXZ:distanceEpisode ? SIMD2<Float>(-0.78,0.46) : SIMD2<Float>(0,0.10),pocketIndex:distanceEpisode ? 2 : 5)
        let writer=try VideoWriter(url:dir.appendingPathComponent("\(kind)-2k-silent.mp4"),size:size,fps:fps)
        var rows:[[String:Any]]=[];var nodes:[SCNNode]=[];var previous:Float = -1
        var counts:[Int]=[];var pockets:[String]=[]
        for frame in 0..<780 {
            try autoreleasepool {
                let progress=Float(min(720,max(0,frame-30)))/720
                let speed:Float=distanceEpisode ? 3 : start+(end-start)*progress
                let distance:Float=distanceEpisode ? 0.8+0.8*progress : 0.6
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
