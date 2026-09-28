import XCTest
import SceneKit
@testable import QiuJi

/// SceneKit metres: X/Z are the table plane, Y points up. These tests compare
/// actual camera output and node writes, without relying on cache internals.
@MainActor
final class Daily3DCameraPerformanceTests: XCTestCase {
    private final class CountingCameraNode: SCNNode {
        var positionWrites = 0
        override var position: SCNVector3 {
            didSet { positionWrites += 1 }
        }
    }

    private struct Fixture {
        let node: CountingCameraNode
        let rig: CameraRig
    }

    private func fixture(optimized: Bool) -> Fixture {
        let node = CountingCameraNode()
        node.camera = SCNCamera()
        let rig = CameraRig(cameraNode: node, tableSurfaceY: 0.8, config: .dailyClearance)
        rig.usesShotAwareCamera = true
        rig.usesRailCameraControls = true
        rig.viewportSize = CGSize(width: 844, height: 390)
        rig.avoidsRedundantPerspectiveWrites = optimized
        return Fixture(node: node, rig: rig)
    }

    private func assertSameCamera(_ candidate: Fixture, _ reference: Fixture,
                                  file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(candidate.node.simdTransform, reference.node.simdTransform, file: file, line: line)
        XCTAssertEqual(candidate.node.camera?.fieldOfView, reference.node.camera?.fieldOfView, file: file, line: line)
        XCTAssertEqual(candidate.node.camera?.usesOrthographicProjection,
                       reference.node.camera?.usesOrthographicProjection, file: file, line: line)
        XCTAssertEqual(candidate.node.camera?.orthographicScale,
                       reference.node.camera?.orthographicScale, file: file, line: line)
        XCTAssertEqual(candidate.rig.currentYaw, reference.rig.currentYaw, file: file, line: line)
        XCTAssertEqual(candidate.rig.currentZoom, reference.rig.currentZoom, file: file, line: line)
        XCTAssertTrue(SCNVector3EqualToVector3(candidate.rig.currentPivot, reference.rig.currentPivot),
                      file: file, line: line)
        XCTAssertEqual(candidate.rig.playerView, reference.rig.playerView, file: file, line: line)
        XCTAssertEqual(candidate.rig.isTransitioning, reference.rig.isTransitioning, file: file, line: line)
    }

    private func advance(_ candidate: Fixture, _ reference: Fixture, frames: Int = 120,
                         file: StaticString = #filePath, line: UInt = #line) {
        // Vary frame intervals so cached output cannot hide a change in damping input.
        let intervals: [Float] = [1 / 60, 1 / 120, 1 / 30, 1 / 59]
        for frame in 0..<frames {
            let dt = intervals[frame % intervals.count]
            candidate.rig.update(deltaTime: dt)
            reference.rig.update(deltaTime: dt)
            assertSameCamera(candidate, reference, file: file, line: line)
        }
    }

    func testStationaryPerspectiveDuringPlaybackAvoidsRepeatedCameraWrites() {
        let candidate = fixture(optimized: true), reference = fixture(optimized: false)
        for item in [candidate, reference] {
            XCTAssertTrue(item.rig.observeWholeTable())
            item.rig.snapToTarget()
        }
        advance(candidate, reference, frames: 1)
        candidate.node.positionWrites = 0
        reference.node.positionWrites = 0

        // A running ball replay keeps calling update even when the camera is stationary.
        advance(candidate, reference, frames: 240)
        XCTAssertEqual(candidate.node.positionWrites, 0)
        XCTAssertEqual(reference.node.positionWrites, 240)
    }

    func testFirstGestureAndSubToleranceTargetChangesMatchEveryReferenceFrame() {
        let candidate = fixture(optimized: true), reference = fixture(optimized: false)
        advance(candidate, reference, frames: 3)
        let originalPosition = candidate.node.position
        for item in [candidate, reference] { item.rig.handleHorizontalSwipe(delta: 22) }
        advance(candidate, reference, frames: 1)
        XCTAssertFalse(SCNVector3EqualToVector3(candidate.node.position, originalPosition))
        advance(candidate, reference)
        for item in [candidate, reference] { item.rig.handleVerticalSwipe(delta: -18) }
        advance(candidate, reference)
        for item in [candidate, reference] { item.rig.handlePinch(scale: 1.12) }
        advance(candidate, reference)
        for item in [candidate, reference] {
            item.rig.observe(at: SCNVector3(0.35, 0.828575, -0.12))
        }
        advance(candidate, reference)

        for item in [candidate, reference] {
            item.rig.snapToTarget()
            // Smaller than hasPendingDamping's 1e-5 floor: do not swallow it.
            item.rig.targetPivot.x += 0.000002
        }
        let beforeSmallMove = candidate.rig.currentPivot.x
        advance(candidate, reference, frames: 1)
        XCTAssertNotEqual(candidate.rig.currentPivot.x, beforeSmallMove)
        advance(candidate, reference)
    }

    func testPlayerButtonsInterruptedTransitionsAndResizeMatchReference() {
        let candidate = fixture(optimized: true), reference = fixture(optimized: false)
        let cue = SCNVector3(-0.4, 0.828575, 0.1), aim = SCNVector3(1, 0, 0)
        for item in [candidate, reference] {
            item.rig.updateCuePose(strike: cue, aim: aim, elevation: 0.08)
            XCTAssertTrue(item.rig.enterPlayerView(.firstPerson, cue: cue, aim: aim))
        }
        advance(candidate, reference)
        for item in [candidate, reference] {
            XCTAssertTrue(item.rig.enterPlayerView(.thirdPerson, cue: cue, aim: aim))
        }
        advance(candidate, reference, frames: 9)
        for item in [candidate, reference] { item.rig.handleHorizontalSwipe(delta: -12) }
        advance(candidate, reference)
        XCTAssertNil(candidate.rig.playerView)
        XCTAssertFalse(candidate.rig.isTransitioning)
        for item in [candidate, reference] { XCTAssertTrue(item.rig.observeWholeTable()) }
        advance(candidate, reference)
        for item in [candidate, reference] { item.rig.viewportSize = CGSize(width: 390, height: 844) }
        advance(candidate, reference)
    }

    func testTopDownRoundTripAndPerspectiveRestoreRemainEquivalent() {
        let candidate = fixture(optimized: true), reference = fixture(optimized: false)
        for item in [candidate, reference] {
            XCTAssertTrue(item.rig.observeWholeTable())
            item.rig.snapToTarget()
        }
        advance(candidate, reference, frames: 1)
        let candidateState = candidate.rig.capturePerspectiveState()
        let referenceState = reference.rig.capturePerspectiveState()
        for rotated in [false, true] {
            for item in [candidate, reference] {
                item.node.positionWrites = 0
                item.rig.topDownPanOffset = CGPoint(x: 0.1, y: -0.05)
                item.rig.topDownOrthographicScale = 1.2
                for _ in 0..<5 {
                    if rotated { item.rig.applyTopDown2DRotated() }
                    else { item.rig.applyTopDown2D() }
                }
                XCTAssertEqual(item.node.positionWrites, 5, "2D retains its original update path")
            }
            assertSameCamera(candidate, reference)
            // Direct perspective update must repair the output changed by top-down mode.
            advance(candidate, reference, frames: 1)
            XCTAssertEqual(candidate.node.camera?.usesOrthographicProjection, false)
        }
        candidate.rig.restorePerspectiveState(candidateState)
        reference.rig.restorePerspectiveState(referenceState)
        advance(candidate, reference)
    }

    func testExternalCameraChangesAndReplacementAreNotHiddenByCache() {
        let candidate = fixture(optimized: true), reference = fixture(optimized: false)
        advance(candidate, reference, frames: 2)
        for item in [candidate, reference] { item.node.position = SCNVector3(0.2, 2, -0.3) }
        advance(candidate, reference, frames: 1)
        for item in [candidate, reference] { item.node.camera?.fieldOfView = 17 }
        advance(candidate, reference, frames: 1)
        for item in [candidate, reference] { item.node.camera?.usesOrthographicProjection = true }
        advance(candidate, reference, frames: 1)
        for item in [candidate, reference] { item.node.camera = SCNCamera() }
        advance(candidate, reference, frames: 1)
        for item in [candidate, reference] { item.rig.setAimYaw(0.4) }
        advance(candidate, reference, frames: 1)
        for item in [candidate, reference] {
            item.rig.translatePivot(deltaXZ: SCNVector3(0.03, 0, -0.02), immediate: true)
        }
        advance(candidate, reference, frames: 1)
    }

    func testOptimizationIsExplicitAndCanBeDisabled() {
        let node = CountingCameraNode()
        node.camera = SCNCamera()
        let rig = CameraRig(cameraNode: node, tableSurfaceY: 0.8)
        XCTAssertFalse(rig.avoidsRedundantPerspectiveWrites)
        node.positionWrites = 0
        for _ in 0..<3 { rig.update(deltaTime: 1 / 60) }
        XCTAssertEqual(node.positionWrites, 3)
        rig.avoidsRedundantPerspectiveWrites = true
        rig.update(deltaTime: 1 / 60)
        node.positionWrites = 0
        for _ in 0..<3 { rig.update(deltaTime: 1 / 60) }
        XCTAssertEqual(node.positionWrites, 0)
        rig.avoidsRedundantPerspectiveWrites = false
        for _ in 0..<3 { rig.update(deltaTime: 1 / 60) }
        XCTAssertEqual(node.positionWrites, 3)
    }
}
