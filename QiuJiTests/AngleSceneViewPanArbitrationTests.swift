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
