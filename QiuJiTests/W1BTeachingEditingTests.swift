import XCTest
import SceneKit
@testable import QiuJi

@MainActor
final class W1BTeachingEditingTests: XCTestCase {
    private final class OverlayPan: UIPanGestureRecognizer {
        var phase: UIGestureRecognizer.State = .possible
        var point: CGPoint = .zero
        override var state: UIGestureRecognizer.State { get { phase } set { phase = newValue } }
        override func location(in view: UIView?) -> CGPoint { point }
        override func translation(in view: UIView?) -> CGPoint { .zero }
    }

    func testTemporaryDragMatchesFingerAllowanceClearanceAndPermissions() throws {
        let window = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first(where: \.isKeyWindow))
        for standard in [false, true] {
            let scene = AngleTrainingScene(); scene.setupScene(mobileRendering: false)
            scene.hideAllBalls()
            scene.showBall(key: "cueBall", scenePosition: SCNVector3(0, scene.surfaceY + BallPhysics.radius, 0))
            let ball = try XCTUnwrap(scene.cueBallNode), rig = try XCTUnwrap(scene.cameraRig)
            rig.usesTwoViewCameraControls = true; rig.usesMergedCamera = true
            rig.viewportSize = CGSize(width: 874, height: 402)
            let view = SCNView(frame: CGRect(origin: .zero, size: rig.viewportSize))
            view.scene = scene; view.pointOfView = scene.cameraNode; window.addSubview(view)
            let coordinator = AngleSceneView.Coordinator(scene: scene, cameraMode: .perspective3D, interactionMode: .cameraControl)
            coordinator.scnView = view; coordinator.draggableBallNodes = [ball]
            coordinator.usesStandardTemporaryTable = standard
            defer { AngleSceneView.dismantleUIView(view, coordinator: coordinator); view.removeFromSuperview() }
            XCTAssertTrue(rig.beginTemporaryTopDown(aim: SCNVector3(-1, 0, 0)))
            coordinator.updateTemporaryTopDownOverlay()
            let overlay = try XCTUnwrap(view.subviews.compactMap { $0 as? SCNView }.first)
            let p = overlay.projectPoint(ball.position)
            let start = overlay.convert(CGPoint(x: CGFloat(p.x), y: CGFloat(p.y) + 30), to: view)
            let pan = OverlayPan(); pan.point = start
            var began = 0, ended = 0
            coordinator.onDragBegan = { _ in began += 1 }
            coordinator.onDragMoved = { node, point in node.position = point }
            coordinator.onDragEnded = { _ in ended += 1 }
            let original = ball.position
            pan.phase = .began; coordinator.handlePan(pan)
            XCTAssertEqual(began, 1, "30pt near grab must work in both temporary render layouts")
            pan.point.x += 30; pan.phase = .changed; coordinator.handlePan(pan)
            XCTAssertEqual(ball.position.x, original.x, accuracy: 0.0001)
            XCTAssertEqual(ball.position.z, original.z, accuracy: 0.0001)
            pan.point.x += 30; coordinator.handlePan(pan)
            pan.point.x += 50; coordinator.handlePan(pan)
            XCTAssertGreaterThan(AngleSceneCalculator.horizontalDistance(original, ball.position), 0.01)
            XCTAssertEqual(ball.position.y, original.y, accuracy: 0.0001)
            coordinator.gesturesEnabled = false
            pan.phase = .cancelled; coordinator.handlePan(pan)
            XCTAssertEqual(ended, 1)
            pan.phase = .began; coordinator.handlePan(pan)
            XCTAssertEqual(began, 1)
            coordinator.gesturesEnabled = true; coordinator.draggableBallNodes = []
            coordinator.handlePan(pan); XCTAssertEqual(began, 1, "Read-only balls must not gain movement permission")
        }
    }

    func testTwoDimensionalClearanceSurvivesCoalescedGestureSamples() throws {
        let window = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first(where: \.isKeyWindow))
        for size in [CGSize(width: 874, height: 402), CGSize(width: 1366, height: 1024)] {
            // Ordinary 2D, legacy temporary overlay, and standard temporary overlay.
            for layout in 0..<3 {
                let scene = AngleTrainingScene(); scene.setupScene(mobileRendering: false)
                scene.hideAllBalls()
                scene.showBall(key: "cueBall", scenePosition: SCNVector3(0, scene.surfaceY + BallPhysics.radius, 0))
                let ball = try XCTUnwrap(scene.cueBallNode), rig = try XCTUnwrap(scene.cameraRig)
                rig.viewportSize = size
                scene.setCameraMode(.topDown2D, animated: false)
                let view = SCNView(frame: CGRect(origin: .zero, size: size))
                view.scene = scene; view.pointOfView = scene.cameraNode; window.addSubview(view)
                let coordinator = AngleSceneView.Coordinator(scene: scene,
                    cameraMode: layout == 0 ? .topDown2D : .perspective3D, interactionMode: .cameraControl)
                coordinator.scnView = view; coordinator.draggableBallNodes = [ball]
                coordinator.onDragMoved = { node, position in node.position = position }
                defer { AngleSceneView.dismantleUIView(view, coordinator: coordinator); view.removeFromSuperview() }
                let renderer: SCNView
                if layout == 0 { renderer = view }
                else {
                    rig.usesTwoViewCameraControls = true; rig.usesMergedCamera = true
                    coordinator.usesStandardTemporaryTable = layout == 2
                    XCTAssertTrue(rig.beginTemporaryTopDown(aim: SCNVector3(-1, 0, 0)))
                    coordinator.updateTemporaryTopDownOverlay()
                    renderer = try XCTUnwrap(view.subviews.compactMap { $0 as? SCNView }.first)
                }
                let original = ball.position
                let projected = renderer.projectPoint(scene.visualCenter(of: ball))
                let start = renderer.convert(CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y)), to: view)
                let sampleSets: [[CGFloat]] = [[30, 54, 80, 120], [120]]
                for samples in sampleSets {
                    ball.position = original
                    let pan = OverlayPan(); pan.point = start; pan.phase = .began
                    coordinator.handlePan(pan)
                    for distance in samples {
                        pan.point = CGPoint(x: start.x + distance, y: start.y)
                        pan.phase = .changed; coordinator.handlePan(pan)
                    }
                    pan.phase = .ended; coordinator.handlePan(pan)
                    let final = renderer.projectPoint(scene.visualCenter(of: ball))
                    XCTAssertEqual(CGFloat(final.x - projected.x), 120 - BTBallDragMetrics.fingerClearance,
                                   accuracy: 0.2, "2D layout \(layout) must preserve 52pt clearance regardless of sample delivery")
                    XCTAssertEqual(ball.position.y, original.y, accuracy: 0.0001)
                }
            }
        }
    }

    func testPlanningPaletteReturnsToPlacementInPerspectiveAndTemporaryViews() throws {
        let silu = SiluTrainerViewModel(); silu.setupScene(); silu.scene.cameraRig?.viewportSize = CGSize(width: 874, height: 402)
        silu.setCameraMode(.perspective3D); silu.activeTool = .region
        silu.placeFromPalette("_3")
        XCTAssertEqual(silu.activeTool, .none)
        XCTAssertTrue(silu.selectableBalls.contains { $0 === silu.scene.allBallNodes["_3"] })
        silu.beginTemporaryTopDown(); XCTAssertTrue(silu.temporaryTopDownActive)
        silu.activeTool = .restPoint; silu.placeFromPalette("_4")
        XCTAssertEqual(silu.activeTool, .none)
        XCTAssertFalse(silu.draggableBalls.isEmpty); XCTAssertFalse(silu.canStrike)
        silu.stopForDismissal()

        let plan = PlanThreeViewModel(); plan.setupScene(); plan.scene.cameraRig?.viewportSize = CGSize(width: 874, height: 402)
        plan.setCameraMode(.perspective3D); plan.beginTemporaryTopDown()
        XCTAssertTrue(plan.temporaryTopDownActive)
        plan.activeTool = .region; plan.placeFromPalette("_4")
        XCTAssertEqual(plan.activeTool, .none)
        plan.armRole(.ball1); plan.selectTarget(key: "_4")
        XCTAssertEqual(plan.ballKey(for: .ball1), "_4")
        plan.armRole(.pocket1); plan.selectPocket(at: 2)
        XCTAssertEqual(plan.pocketIndex(for: .pocket1), 2)
        XCTAssertFalse(plan.canStrike); XCTAssertFalse(plan.draggableBalls.isEmpty)
        plan.stopForDismissal()
    }

    func testDefenseSelectionAndDragRemainAvailableInTemporaryView() throws {
        let vm = SnookerTacticsViewModel(); vm.setupScene(); vm.scene.cameraRig?.viewportSize = CGSize(width: 874, height: 402); vm.setCameraMode(.perspective3D)
        vm.beginTemporaryTopDown(); XCTAssertTrue(vm.temporaryTopDownActive)
        vm.activeTool = .selectTarget; vm.placeFromPalette("_3")
        XCTAssertEqual(vm.activeTool, .none)
        let node = try XCTUnwrap(vm.scene.allBallNodes["_3"])
        vm.activeTool = .selectTarget; vm.selectTarget(key: "_3")
        XCTAssertEqual(vm.selectedTargetKey, "_3")
        vm.activeTool = .none
        let before = node.position
        vm.dragBegan(node: node)
        vm.dragMoved(node: node, worldPosition: SCNVector3(-0.6, before.y, 0.2))
        vm.dragEnded(node: node)
        XCTAssertGreaterThan(AngleSceneCalculator.horizontalDistance(before, node.position), 0.05)
        XCTAssertFalse(vm.canStrike)
        vm.stopForDismissal()
    }

    func testUnsolvedEmptyBoardCanEnterTemporaryAndRestoresCameraPoseAfterEditing() throws {
        let vm = SiluTrainerViewModel(); vm.setupScene(); vm.clearTable(); vm.setCameraMode(.perspective3D)
        let camera = try XCTUnwrap(vm.scene.cameraNode)
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        rig.viewportSize = CGSize(width: 874, height: 402)
        let pose = camera.simdTransform
        XCTAssertNil(vm.currentPlayerAim)
        vm.beginTemporaryTopDown(); XCTAssertTrue(vm.temporaryTopDownActive)
        vm.placeFromPalette("_3"); vm.topDownSelectionChanged = true
        vm.endTemporaryTopDown(); XCTAssertFalse(vm.temporaryTopDownActive)
        for column in 0..<4 { for row in 0..<4 {
            XCTAssertEqual(camera.simdTransform[column][row], pose[column][row], accuracy: 0.00001)
        } }
        vm.stopForDismissal()
    }

    func testRayPlaneRoundTripMatchesRenderedPerspectiveAndInsetOrthographicViews() throws {
        for size in [CGSize(width: 874, height: 402), CGSize(width: 820, height: 1180)] {
            for orthographic in [false, true] {
                let view = SCNView(frame: CGRect(origin: .zero, size: size)); view.scene = SCNScene()
                let camera = SCNNode(); camera.camera = SCNCamera()
                camera.camera?.usesOrthographicProjection = orthographic
                camera.camera?.orthographicScale = 1.8
                camera.camera?.zNear = 0.01; camera.camera?.zFar = 100
                camera.position = orthographic ? SCNVector3(0, 5, 0) : SCNVector3(2, 3, 3)
                camera.look(at: SCNVector3(0, 0.8, 0), up: SCNVector3(0, 0, -1), localFront: SCNVector3(0, 0, -1))
                view.scene?.rootNode.addChildNode(camera); view.pointOfView = camera
                for point in [SCNVector3(-0.8, 0.828575, -0.3), SCNVector3(0.6, 0.828575, 0.4)] {
                    let projected = view.projectPoint(point)
                    let restored = try XCTUnwrap(TableProjector.world(at: CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y)), in: view, planeY: point.y))
                    XCTAssertEqual(restored.x, point.x, accuracy: 0.0001)
                    XCTAssertEqual(restored.z, point.z, accuracy: 0.0001)
                }
            }
        }
    }

    func testBankAndDiamondCatalogSelectionIsRealAndInvalidSelectionIsIgnored() {
        let bank = BankShotViewModel(); bank.setupScene(); idle { bank.isSolving }
        for pocket in 0..<6 where bank.solutionCount < 2 { bank.selectPocket(pocket); idle { bank.isSolving } }
        XCTAssertGreaterThan(bank.solutionCount, 1)
        let lastBank = bank.solutionCount - 1
        bank.selectSolution(at: lastBank); XCTAssertEqual(bank.currentIndex, lastBank)
        bank.selectSolution(at: -1); XCTAssertEqual(bank.currentIndex, lastBank)
        XCTAssertTrue(bank.statusText.hasPrefix("解 \(lastBank + 1)/"))
        XCTAssertFalse(bank.statusText.contains("容错"))
        bank.stopForDismissal()
        let diamond = DiamondSystemViewModel(); diamond.setupScene(); idle { diamond.isSolving }
        XCTAssertGreaterThan(diamond.solutionCount, 1)
        let lastDiamond = diamond.solutionCount - 1
        diamond.selectSolution(at: lastDiamond); XCTAssertEqual(diamond.currentIndex, lastDiamond)
        diamond.selectSolution(at: diamond.solutionCount); XCTAssertEqual(diamond.currentIndex, lastDiamond)
        XCTAssertTrue(diamond.statusText.hasPrefix("解 \(lastDiamond + 1)/"))
        XCTAssertFalse(diamond.statusText.contains("容错"))
        diamond.stopForDismissal()
    }

    func testTemporaryViewBlocksReplayEvenWhenSolveReplayExists() {
        let vm = BankShotViewModel(); vm.setupScene(); idle { vm.isSolving }
        XCTAssertTrue(vm.canStrike)
        vm.strike(); XCTAssertTrue(vm.isPlaying)
        vm.stopStrike(); XCTAssertTrue(vm.canReplaySolve)
        vm.temporaryTopDownActive = true
        vm.replaySolveShot(); XCTAssertFalse(vm.isPlaying)
        vm.undoSolveShot(); XCTAssertTrue(vm.canUndoSolve)
        vm.temporaryTopDownActive = false
        vm.replaySolveShot(); XCTAssertTrue(vm.isPlaying)
        vm.stopStrike(); vm.stopForDismissal()
    }

    func testExpandedRoleReadoutFitsBesideActualSpinCardAcrossCompactAndTabletWindows() {
        for size in [CGSize(width: 667, height: 375), CGSize(width: 874, height: 402),
                     CGSize(width: 1180, height: 820), CGSize(width: 820, height: 1180)] {
            let f = DailyLayoutMetrics.Foundation(size: size, leadingSafeArea: 0, trailingSafeArea: 0,
                halfLength: CameraRig.defaultTableOuterHalfLength, halfWidth: CameraRig.defaultTableOuterHalfWidth,
                instrumentHeight: DailyLayoutMetrics.Controls.initialInstrumentHeight)
            let points = f.table.height / CGFloat(2 * (f.rotated ? CameraRig.defaultTableOuterHalfLength : CameraRig.defaultTableOuterHalfWidth))
            let maximum: CGFloat = size.height >= 600 ? 310 : .greatestFiniteMagnitude
            let layout = BTTeachingPageLayout(stageSize: f.stage.size, rotated: f.rotated,
                pointsPerMetre: points, instruments: .init(foundation: f), spinPadPresented: true,
                displayScale: 3, spinPadMaximumExtent: maximum)
            let lane = layout.expandedReadoutFrame
            XCTAssertTrue(layout.innerRect.contains(lane))
            XCTAssertFalse(lane.intersects(layout.spinPadFrame))
            XCTAssertGreaterThanOrEqual(lane.width, 44)
            let text = "①球:15号球\n第1杆目标袋:右中袋\n②球:14号球\n第2杆目标袋:左中袋\n③球:未选择" as NSString
            let bounds = text.boundingRect(with: CGSize(width: lane.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: UIFont.preferredFont(forTextStyle: .footnote)], context: nil)
            XCTAssertLessThanOrEqual(ceil(bounds.height), lane.height)
        }
    }

    private func idle(_ busy: @escaping () -> Bool) {
        let done = expectation(description: "solver completes")
        func poll() {
            if !busy() { done.fulfill() }
            else { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { poll() } }
        }
        poll(); wait(for: [done], timeout: 90)
    }
}
