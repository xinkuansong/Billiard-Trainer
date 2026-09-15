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
    private let size = CGSize(width: 2160, height: 3840)

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
        let labelView = SCNView(frame: CGRect(x: 0, y: 0, width: 360, height: 640))
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
        capture.labels.update(scene: capture.vm.scene, in: capture.labelView)
        let labels = capture.labelView.subviews.compactMap { $0 as? UILabel }
        XCTAssertEqual(labels.count, 3)
        XCTAssertTrue(labels.allSatisfy { !$0.isHidden }, "All three production annotations must be visible")
        XCTAssertTrue(labels.contains { $0.text == "瞄准线" })
        XCTAssertTrue(labels.contains { $0.text == "进球线" })
        // Compare the real SceneKit projections before compositing the production overlay.
        // SCNRenderer uses bottom-left projection coordinates; SCNView uses UIKit top-left.
        for world in [capture.target, capture.ghost, try XCTUnwrap(capture.vm.scene.cueBallNode).position] {
            let sourcePoint = capture.renderer.projectPoint(world)
            let overlayPoint = capture.labelView.projectPoint(world)
            XCTAssertEqual(sourcePoint.x / 6, overlayPoint.x, accuracy: 0.1)
            XCTAssertEqual(Float(size.height) / 6 - sourcePoint.y / 6, overlayPoint.y, accuracy: 0.1)
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
            cg.scaleBy(x: 6, y: 6)
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
            cg.scaleBy(x: 2, y: 2)
            // Panel origin in 1080×1920 coordinates. User request (2026-09-15): keep the readout
            // out of social-media overlay zones — 2D sits on the cloth left of the cue-ball arc,
            // 3D sits on the floor between the sofa and the far end of the table.
            let panelOrigin = capture.vm.scene.currentCameraMode == .perspective3D
                ? CGPoint(x: 68, y: 392) : CGPoint(x: 216, y: 1250)
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
