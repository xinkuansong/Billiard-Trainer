import XCTest
import SceneKit
@testable import QiuJi

/// Single-finger pan on the SCNView vs. ancestor UIScrollView pans (paging `TabView` in the
/// training pager, vertical `ScrollView` on detail pages). The 3D camera orbit must own a swipe
/// that starts on the table; a dead pan (`interactionMode == .none`) must yield to the pager.
@MainActor
final class AngleSceneViewPanArbitrationTests: XCTestCase {
    private func makeCoordinator(mode: AngleSceneView.InteractionMode,
                                 camera: AngleTrainingScene.CameraMode) -> (AngleSceneView.Coordinator, UIPanGestureRecognizer, SCNView, UIScrollView) {
        let scene = AngleTrainingScene()
        let coordinator = AngleSceneView.Coordinator(scene: scene, cameraMode: camera, interactionMode: mode)
        let scnView = SCNView(frame: CGRect(x: 0, y: 0, width: 320, height: 160))
        let pan = UIPanGestureRecognizer()
        pan.delegate = coordinator
        scnView.addGestureRecognizer(pan)
        coordinator.scnView = scnView
        coordinator.panGesture = pan
        let pager = UIScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 600))
        pager.addSubview(scnView)
        return (coordinator, pan, scnView, pager)
    }

    func test3DCameraControlPanBlocksAncestorPager() {
        let (coordinator, pan, _, pager) = makeCoordinator(mode: .cameraControl, camera: .perspective3D)
        XCTAssertTrue(coordinator.gestureRecognizerShouldBegin(pan))
        XCTAssertTrue(coordinator.gestureRecognizer(pan, shouldBeRequiredToFailBy: pager.panGestureRecognizer),
                      "Paging scroll view must wait for the camera-orbit pan to fail")
    }

    func testTapsOnlyPanStillOwnsBallDragOverPager() {
        let (coordinator, pan, _, pager) = makeCoordinator(mode: .tapsOnly, camera: .topDown2DRotated)
        XCTAssertTrue(coordinator.gestureRecognizerShouldBegin(pan))
        XCTAssertTrue(coordinator.gestureRecognizer(pan, shouldBeRequiredToFailBy: pager.panGestureRecognizer))
    }

    func testInertPanYieldsToAncestorPager() {
        let (coordinator, pan, _, pager) = makeCoordinator(mode: .none, camera: .topDown2D)
        XCTAssertFalse(coordinator.gestureRecognizerShouldBegin(pan),
                       "2D 球台示意 in the training pager has no pan work; swipe must page")
        XCTAssertFalse(coordinator.gestureRecognizer(pan, shouldBeRequiredToFailBy: pager.panGestureRecognizer))
    }

    func testDisabledGesturesYieldToAncestorPager() {
        let (coordinator, pan, _, pager) = makeCoordinator(mode: .cameraControl, camera: .perspective3D)
        coordinator.gesturesEnabled = false
        XCTAssertFalse(coordinator.gestureRecognizerShouldBegin(pan))
        XCTAssertFalse(coordinator.gestureRecognizer(pan, shouldBeRequiredToFailBy: pager.panGestureRecognizer))
    }

    func testOnlyScrollViewPansAreAskedToWait() {
        let (coordinator, pan, scnView, _) = makeCoordinator(mode: .cameraControl, camera: .perspective3D)
        // Sibling recognizers on the SCNView itself (pinch, two-finger pan, taps) keep default arbitration.
        let siblingPan = UIPanGestureRecognizer()
        scnView.addGestureRecognizer(siblingPan)
        XCTAssertFalse(coordinator.gestureRecognizer(pan, shouldBeRequiredToFailBy: siblingPan))
        let pinch = UIPinchGestureRecognizer()
        scnView.addGestureRecognizer(pinch)
        XCTAssertFalse(coordinator.gestureRecognizer(pan, shouldBeRequiredToFailBy: pinch))
        // A non-pan recognizer on an ancestor scroll view (e.g. tap) is not scroll-driving.
        let pager = UIScrollView()
        let tap = UITapGestureRecognizer()
        pager.addGestureRecognizer(tap)
        XCTAssertFalse(coordinator.gestureRecognizer(pan, shouldBeRequiredToFailBy: tap))
        // A plain (non-scroll) ancestor pan is left alone as well.
        let plain = UIView()
        let plainPan = UIPanGestureRecognizer()
        plain.addGestureRecognizer(plainPan)
        XCTAssertFalse(coordinator.gestureRecognizer(pan, shouldBeRequiredToFailBy: plainPan))
    }

    func testDelegateIgnoresRecognizersItDoesNotOwn() {
        let (coordinator, _, scnView, pager) = makeCoordinator(mode: .none, camera: .topDown2D)
        let other = UIPanGestureRecognizer()
        scnView.addGestureRecognizer(other)
        XCTAssertTrue(coordinator.gestureRecognizerShouldBegin(other))
        XCTAssertFalse(coordinator.gestureRecognizer(other, shouldBeRequiredToFailBy: pager.panGestureRecognizer))
    }
}

/// Exercise the production projection and gesture lifecycle, not a duplicate rectangle formula.
@MainActor
final class TableAimBoundaryTests: XCTestCase {
    private final class Pan: UIPanGestureRecognizer {
        var phase: UIGestureRecognizer.State = .possible
        var point: CGPoint = .zero
        override var state: UIGestureRecognizer.State { get { phase } set { phase = newValue } }
        override func location(in view: UIView?) -> CGPoint { point }
        override func translation(in view: UIView?) -> CGPoint { .zero }
    }

    private func fixture(rotated: Bool = false) -> (AngleTrainingScene, SCNView, AngleSceneView.Coordinator, Pan) {
        let scene = AngleTrainingScene()
        scene.setupScene(mobileRendering: false)
        scene.showBall(key: PositionPlayBall.cueKey, scenePosition: SCNVector3(0, scene.surfaceY, 0))
        let rig = scene.cameraRig!
        rig.topDownOrthographicScale = 2.2
        if rotated { rig.applyTopDown2DRotated() } else { rig.applyTopDown2D() }
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: rotated ? 600 : 900, height: rotated ? 900 : 600))
        view.scene = scene; view.pointOfView = scene.cameraNode
        view.layoutIfNeeded(); SCNTransaction.flush(); _ = view.snapshot()
        let coordinator = AngleSceneView.Coordinator(scene: scene,
            cameraMode: rotated ? .topDown2DRotated : .topDown2D, interactionMode: .tapsOnly)
        coordinator.scnView = view
        coordinator.onAimNudged = { _ in }
        let pan = Pan(); view.addGestureRecognizer(pan); coordinator.panGesture = pan
        return (scene, view, coordinator, pan)
    }
    private func screen(_ x: Float, _ z: Float, scene: AngleTrainingScene, view: SCNView) -> CGPoint {
        let p = view.projectPoint(SCNVector3(x, scene.surfaceY, z))
        return CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
    }

    func testFourEdgesFollowBothActualTopDownProjections() {
        for rotated in [false, true] {
            let (scene, view, coordinator, pan) = fixture(rotated: rotated)
            let hx = Float(scene.cameraRig!.tableOuterHalfLength), hz = Float(scene.cameraRig!.tableOuterHalfWidth)
            for (x, z) in [(hx, Float(0)), (-hx, 0), (0, hz), (0, -hz)] {
                let inside = screen(x * 0.99, z * 0.99, scene: scene, view: view)
                let outside = screen(x * 1.04, z * 1.04, scene: scene, view: view)
                XCTAssertTrue(view.bounds.contains(outside), "The renderer includes floor beyond this edge")
                XCTAssertTrue(coordinator.allowsPanStart(at: inside))
                XCTAssertFalse(coordinator.allowsPanStart(at: outside))
                pan.point = outside
                XCTAssertFalse(coordinator.gestureRecognizerShouldBegin(pan))
            }
            XCTAssertFalse(coordinator.allowsPanStart(at: CGPoint(x: CGFloat.nan, y: 0)))
        }
    }

    func testOutsideOriginCannotBecomeAimWhenFingerEntersTable() {
        let (scene, view, coordinator, pan) = fixture()
        var deltas: [Float] = [], active: [Bool] = []
        coordinator.onAimNudged = { deltas.append($0) }
        coordinator.onAimDragActiveChanged = { active.append($0) }
        coordinator.panTouchOrigin = screen(0, Float(scene.cameraRig!.tableOuterHalfWidth) + 0.1, scene: scene, view: view)
        pan.point = screen(0.5, 0.3, scene: scene, view: view)
        XCTAssertFalse(coordinator.gestureRecognizerShouldBegin(pan), "Use touch-down, not recognition location")
        pan.phase = .began; coordinator.handlePan(pan)
        pan.point = screen(0.6, -0.3, scene: scene, view: view)
        pan.phase = .changed; coordinator.handlePan(pan)
        pan.phase = .ended; coordinator.handlePan(pan)
        XCTAssertTrue(deltas.isEmpty); XCTAssertTrue(active.isEmpty)
        XCTAssertNil(coordinator.panTouchOrigin)
    }

    func testInsideOriginContinuesOutsideAndEveryTerminalStateCleansUp() {
        for terminal in [UIGestureRecognizer.State.ended, .cancelled, .failed] {
            let (scene, view, coordinator, pan) = fixture()
            var deltas: [Float] = [], active: [Bool] = []
            coordinator.onAimNudged = { deltas.append($0) }
            coordinator.onAimDragActiveChanged = { active.append($0) }
            pan.point = screen(0.5, 0.2, scene: scene, view: view)
            coordinator.panTouchOrigin = pan.point
            XCTAssertTrue(coordinator.gestureRecognizerShouldBegin(pan))
            pan.phase = .began; coordinator.handlePan(pan)
            XCTAssertTrue(deltas.isEmpty, "Touch-down never changes aim")
            pan.point = screen(0.5, Float(scene.cameraRig!.tableOuterHalfWidth) + 0.15, scene: scene, view: view)
            pan.phase = .changed; coordinator.handlePan(pan)
            XCTAssertEqual(deltas.count, 1); XCTAssertNotEqual(deltas.first, 0)
            pan.phase = terminal; coordinator.handlePan(pan)
            XCTAssertEqual(active, [true, false]); XCTAssertNil(coordinator.panTouchOrigin)
            pan.phase = .changed; coordinator.handlePan(pan)
            XCTAssertEqual(deltas.count, 1)
        }
    }

    func testBallGrabAndOtherInteractionModesKeepTheirPermissions() {
        let (scene, view, coordinator, pan) = fixture()
        let edge = Float(scene.cameraRig!.tableOuterHalfWidth)
        let ball = SCNNode(geometry: SCNSphere(radius: 0.028575))
        ball.position = SCNVector3(0, scene.surfaceY + 0.028575, edge - 0.02)
        scene.rootNode.addChildNode(ball); coordinator.draggableBallNodes = [ball]
        let point = screen(0, edge + 0.02, scene: scene, view: view)
        XCTAssertTrue(coordinator.hitTestBall(at: point) === ball)
        XCTAssertTrue(coordinator.allowsPanStart(at: point), "Existing near-ball grabbing is independent of aiming")
        var grabbed = false, aimed = false
        coordinator.onDragBegan = { _ in grabbed = true }
        coordinator.onAimDragActiveChanged = { aimed = $0 }
        pan.point = point; pan.phase = .began; coordinator.handlePan(pan)
        XCTAssertTrue(grabbed); XCTAssertFalse(aimed)
        pan.phase = .cancelled; coordinator.handlePan(pan)
        coordinator.draggableBallNodes = []
        XCTAssertFalse(coordinator.allowsPanStart(at: point))
        coordinator.cameraMode = .perspective3D
        XCTAssertTrue(coordinator.allowsPanStart(at: point))
        coordinator.cameraMode = .topDown2D; coordinator.onAimNudged = nil
        XCTAssertTrue(coordinator.allowsPanStart(at: point))
    }
}
