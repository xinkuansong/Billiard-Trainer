import XCTest
import SceneKit
@testable import QiuJi

#if DEBUG
/// Factor study: real daily scene and CameraRig, with no production camera changes.
@MainActor
final class DailyCameraFactorCaptureTests: XCTestCase {
    func testCaptureControlledFactors() throws {
        let base = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: base.appendingPathComponent("build/daily-camera-factors-20260929/capture.enabled").path) else {
            throw XCTSkip("Opt-in daily camera factor capture")
        }
        let out = base.appendingPathComponent("output/daily-camera-factors-20260929")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let scene = AngleTrainingScene()
        scene.configureDailyClearanceRendering()
        scene.setupScene()
        XCTAssertTrue(scene.applyTableStyle(.charcoal, showsSights: true))
        XCTAssertTrue(scene.applyClothColor(.green))
        scene.setCameraMode(.perspective3D, animated: false)
        let rig = try XCTUnwrap(scene.cameraRig), camera = try XCTUnwrap(scene.cameraNode)
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene; renderer.pointOfView = camera; renderer.delegate = scene.contactOcclusion
        let y = scene.surfaceY + BallPhysics.radius
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: y)
        let landscape = CGSize(width: 874, height: 402)
        struct Shot {
            let id: String, title: String, cue: SCNVector3, target: SCNVector3, pocket: Int
        }
        func straightFamily(_ id: String, _ title: String, _ bearing: Float, _ distance: Float, _ pocket: Int) -> Shot {
            let pot = SCNVector3(cos(bearing), 0, sin(bearing))
            let aim = SCNVector3(cos(bearing + .pi / 18), 0, sin(bearing + .pi / 18))
            let target = SCNVector3(pockets[pocket].x, y, pockets[pocket].z) - pot * distance
            let ghost = target - pot * (2 * BallPhysics.radius)
            return Shot(id: id, title: title, cue: ghost - aim * 0.55, target: target, pocket: pocket)
        }
        let shots = [
            straightFamily("P1", "母球靠近身后库边", atan(0.3), 1.85, 3),
            straightFamily("P2", "母球位于中段", atan(0.3), 1.10, 3),
            straightFamily("P3", "母球深入台内", atan(0.3), 0.35, 3),
            straightFamily("D2", "偏短轴出杆", .pi / 2, 0.35, 5),
            straightFamily("D3", "斜向出杆", .pi / 4, 0.35, 3),
            Shot(id: "L", title: "长距离球", cue: SCNVector3(-1.05,y,-0.34), target: SCNVector3(0.80,y,0.36), pocket: 3)
        ]
        var records: [[String: Any]] = []
        var layouts: [[String: Any]] = []
        func xyz(_ p: SCNVector3) -> [Float] { [p.x,p.y,p.z] }
        for shot in shots {
            scene.hideAllBalls(); scene.hideCueStick()
            let pocket = SCNVector3(pockets[shot.pocket].x,y,pockets[shot.pocket].z)
            let pot = (pocket-shot.target).normalized()
            let ghost = shot.target-pot*(2*BallPhysics.radius)
            let aim = (ghost-shot.cue).normalized()
            let cut = acos(max(-1,min(1,aim.x*pot.x+aim.z*pot.z)))*180/Float.pi
            let ballDistance = (shot.target-shot.cue).length()
            for p in [shot.cue,shot.target,ghost] {
                XCTAssertLessThan(abs(p.x)+BallPhysics.radius,AngleSceneCalculator.innerLength/2)
                XCTAssertLessThan(abs(p.z)+BallPhysics.radius,AngleSceneCalculator.innerWidth/2)
            }
            XCTAssertGreaterThan(ballDistance,2*BallPhysics.radius)
            XCTAssertEqual((shot.target-ghost).length(),2*BallPhysics.radius,accuracy:0.00001)
            if shot.id != "L" {
                XCTAssertEqual(cut,10,accuracy:0.001)
                XCTAssertEqual(ballDistance,0.6063629,accuracy:0.00001)
                XCTAssertEqual((ghost-shot.cue).length(),0.55,accuracy:0.00001)
            }
            scene.showBall(key:"cueBall",scenePosition:shot.cue)
            scene.showBall(key:"_1",scenePosition:shot.target)
            scene.updateCueStick(cueBallPosition:shot.cue,aimDirection:aim)
            XCTAssertFalse(try XCTUnwrap(scene.cueStick).rootNode.isHidden)
            let aimLine = scene.addLine(from:shot.cue+aim*BallPhysics.radius,to:ghost,color:.white,radius:0.0012)
            let potLine = scene.addLine(from:shot.target+pot*BallPhysics.radius,to:pocket,color:.systemYellow,radius:0.0012)
            let halfL = Float(rig.tableOuterHalfLength), halfW = Float(rig.tableOuterHalfWidth)
            let tx = abs(aim.x)>0.00001 ? ((aim.x>0 ? -halfL:halfL)-shot.cue.x)/(-aim.x) : Float.infinity
            let tz = abs(aim.z)>0.00001 ? ((aim.z>0 ? -halfW:halfW)-shot.cue.z)/(-aim.z) : Float.infinity
            let railDistance = max(0,min(tx,tz))
            layouts.append(["id":shot.id,"title":shot.title,"cue":xyz(shot.cue),"target":xyz(shot.target),
                "ghost":xyz(ghost),"pocket":xyz(pocket),"pocketIndex":shot.pocket,"aim":xyz(aim),
                "ballDistance":ballDistance,"pocketDistance":(pocket-shot.target).length(),"cut":cut,
                "bearing":atan2(aim.z,aim.x)*180/Float.pi,"railDistance":railDistance])
            for profile in CameraRig.DailyPreviewProfile.allCases {
                rig.viewportSize = landscape
                rig.dailyPreviewProfile = profile
                rig.observationCandidates = [shot.cue,shot.target]
                XCTAssertTrue(rig.enterPlayerView(.thirdPerson,cue:shot.cue,aim:aim,focus:shot.target))
                for _ in 0..<120 { rig.update(deltaTime:1/60) }
                let fixedTransform = camera.simdTransform
                let fixedFOV = camera.camera!.fieldOfView
                camera.camera!.projectionDirection = .vertical
                if profile != .current {
                    XCTAssertEqual(camera.position.y-scene.surfaceY,profile == .classic ? 0.84:0.80,accuracy:0.0001)
                    XCTAssertTrue(abs(camera.position.x)>halfL || abs(camera.position.z)>halfW)
                }
                for (orientation,size) in [("H",landscape),("V",CGSize(width:402,height:874))] {
                    try autoreleasepool {
                        // Only the render surface changes. Even A retains its landscape lens here.
                        let pixelSize = CGSize(width:size.width*2,height:size.height*2)
                        SCNTransaction.flush()
                        _ = renderer.snapshot(atTime:0,with:pixelSize,antialiasingMode:.multisampling4X)
                        let image = renderer.snapshot(atTime:0,with:pixelSize,antialiasingMode:.multisampling4X)
                        XCTAssertEqual(camera.simdTransform,fixedTransform)
                        XCTAssertEqual(camera.camera!.fieldOfView,fixedFOV)
                        XCTAssertEqual(camera.simdWorldRight.y,0,accuracy:0.00001)
                        let name = "\(shot.id)-\(profile.rawValue)-\(orientation)"
                        try XCTUnwrap(image.pngData()).write(to:out.appendingPathComponent(name+".png"))
                        // SCNRenderer projection uses bottom-left origin; JSON uses image top-left.
                        func screen(_ p: SCNVector3) -> [Float] {
                            let v = renderer.projectPoint(p)
                            XCTAssertTrue(v.x.isFinite && v.y.isFinite && v.z>0 && v.z<1)
                            return [v.x/2,(Float(pixelSize.height)-v.y)/2]
                        }
                        func diameter(_ p: SCNVector3) -> Float {
                            let right = camera.simdWorldRight*BallPhysics.radius
                            let delta = SCNVector3(right.x,right.y,right.z)
                            return abs(renderer.projectPoint(p+delta).x-renderer.projectPoint(p-delta).x)/2
                        }
                        let center = renderer.projectPoint(rig.currentPivot)
                        XCTAssertEqual(center.x,Float(pixelSize.width/2),accuracy:0.5)
                        XCTAssertEqual(center.y,Float(pixelSize.height/2),accuracy:0.5)
                        let rightAbove = rig.currentPivot+SCNVector3(0,0.1,0)
                        XCTAssertGreaterThan(renderer.projectPoint(rightAbove).y,center.y)
                        let eye = camera.position
                        let horizontalDistance = hypot(eye.x-shot.cue.x,eye.z-shot.cue.z)
                        let forward = camera.simdWorldFront
                        let pitch = asin(min(1,max(-1,-forward.y)))*180/Float.pi
                        let hFOV = 2*atan(tan(Double(fixedFOV)*Double.pi/360)*Double(size.width/size.height))*180/Double.pi
                        records.append(["key":name,"layout":shot.id,"profile":profile.rawValue,"orientation":orientation,
                            "image":name+".png","width":size.width,"height":size.height,"eye":xyz(eye),
                            "eyeAboveTable":eye.y-scene.surfaceY,"distanceToCue":horizontalDistance,
                            "setback":horizontalDistance-railDistance,"pitch":pitch,"verticalFOV":fixedFOV,"horizontalFOV":hFOV,
                            "cueScreen":screen(shot.cue),"targetScreen":screen(shot.target),"pocketScreen":screen(pocket),
                            "cueDiameter":diameter(shot.cue),"targetDiameter":diameter(shot.target)])
                    }
                }
            }
            scene.removeLine(aimLine); scene.removeLine(potLine)
        }
        XCTAssertEqual(records.count,36)
        let payload: [String: Any] = ["layouts":layouts,"renders":records,"surfaceY":scene.surfaceY,
            "tableHalfLength":rig.tableOuterHalfLength,"tableHalfWidth":rig.tableOuterHalfWidth,
            "portraitPolicy":"Frozen landscape pose and vertical FOV; not the portrait App policy"]
        try JSONSerialization.data(withJSONObject:payload,options:[.prettyPrinted,.sortedKeys])
            .write(to:out.appendingPathComponent("parameters.json"))
    }
}
#endif

#if DEBUG
@MainActor
final class DailyCameraPreviewTests: XCTestCase {
    private func fixture(profile: CameraRig.DailyPreviewProfile?, daily: Bool = true) -> (CameraRig, SCNNode) {
        let node = SCNNode(); node.camera = SCNCamera()
        let rig = CameraRig(cameraNode: node, tableSurfaceY: 0.8, config: .dailyClearance)
        rig.usesRailCameraControls = true
        rig.usesShotAwareCamera = daily
        rig.viewportSize = CGSize(width: 874, height: 402)
        rig.dailyPreviewProfile = profile
        rig.enterPlayerView(.thirdPerson, cue: SCNVector3(-1.05, 0.828575, -0.34),
            aim: SCNVector3(1, 0, 0.38), focus: SCNVector3(0.80, 0.828575, 0.36))
        for _ in 0..<120 { rig.update(deltaTime: 1 / 60) }
        return (rig, node)
    }

    func testCurrentOptionAndDisabledPreviewMatchExistingCameraEveryFrame() {
        let (a, an) = fixture(profile: nil), (b, bn) = fixture(profile: .current)
        a.handleVerticalSwipe(delta: 25); b.handleVerticalSwipe(delta: 25)
        a.handleHorizontalSwipe(delta: -30); b.handleHorizontalSwipe(delta: -30)
        a.handlePinch(scale: 1.2); b.handlePinch(scale: 1.2)
        for _ in 0..<120 {
            a.update(deltaTime: 1 / 60); b.update(deltaTime: 1 / 60)
            XCTAssertEqual(an.simdTransform, bn.simdTransform)
            XCTAssertEqual(an.camera?.fieldOfView, bn.camera?.fieldOfView)
        }
    }

    func testStableVerticalLookAndZoomNeverMoveEyeOrChangePivot() {
        for profile in [CameraRig.DailyPreviewProfile.classic, .standing] {
            let (rig, node) = fixture(profile: profile)
            rig.dailyPreviewSteadyInput = true
            let eye = node.simdPosition, pivot = rig.currentPivot
            let originalPitch = node.eulerAngles.x
            rig.handleVerticalSwipe(delta: 60)
            for _ in 0..<100 {
                rig.update(deltaTime: 1 / 60)
                XCTAssertEqual(node.simdPosition, eye)
            }
            XCTAssertLessThan(node.eulerAngles.x, originalPitch)
            rig.beginObservationPinch(at: SCNVector3(0.8, 0.828575, 0.36))
            for scale: Float in [0.01, 1.1, 100, 0.9] {
                rig.handlePinch(scale: scale)
                for _ in 0..<100 { rig.update(deltaTime: 1 / 60) }
                XCTAssertEqual(node.simdPosition, eye)
                XCTAssertTrue(SCNVector3EqualToVector3(rig.currentPivot, pivot))
                XCTAssertGreaterThanOrEqual(node.camera!.fieldOfView, 23.99)
                XCTAssertLessThanOrEqual(node.camera!.fieldOfView, 60.01)
            }
        }
    }

    func testClassicMatchesOldStanceAndStandingHasExpectedEyeHeight() {
        let (classic, a) = fixture(profile: .classic)
        let (standing, b) = fixture(profile: .standing)
        XCTAssertEqual(a.position.y, 1.64, accuracy: 0.0001)
        XCTAssertEqual(b.position.y, 1.60, accuracy: 0.0001)
        XCTAssertEqual(a.camera!.fieldOfView, b.camera!.fieldOfView)
        for (rig, node) in [(classic, a), (standing, b)] {
            XCTAssertTrue(abs(node.position.x) > Float(rig.tableOuterHalfLength)
                || abs(node.position.z) > Float(rig.tableOuterHalfWidth))
            XCTAssertEqual(node.eulerAngles.z, 0, accuracy: 0.000001)
        }
    }

    func testOtherPagesIgnoreProfileAndGlobalStillUsesOriginalVerticalMotion() {
        let (_, baseline) = fixture(profile: nil, daily: false)
        let (_, candidate) = fixture(profile: .standing, daily: false)
        XCTAssertEqual(baseline.simdTransform, candidate.simdTransform)
        let (rig, node) = fixture(profile: .classic)
        rig.dailyPreviewSteadyInput = true
        XCTAssertTrue(rig.observeWholeTable())
        for _ in 0..<120 { rig.update(deltaTime: 1 / 60) }
        let height = node.position.y
        rig.handleVerticalSwipe(delta: 20)
        for _ in 0..<120 { rig.update(deltaTime: 1 / 60) }
        XCTAssertNotEqual(node.position.y, height)
    }
}
#endif

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

/// Opt-in visual comparison; never changes production camera defaults.
@MainActor
final class GlobalCameraPreviewTests: XCTestCase {
    func testSelectedCOverviewKeepsCenterAndDistanceDuringOrbit() throws {
        let scene = AngleTrainingScene()
        scene.configureDailyClearanceRendering()
        scene.setupScene()
        scene.setCameraMode(.perspective3D, animated: false)
        let rig = try XCTUnwrap(scene.cameraRig)
        let camera = try XCTUnwrap(scene.cameraNode)
        rig.viewportSize = CGSize(width: 1170, height: 540)
        let center = SIMD3<Float>(0, scene.surfaceY + BallPhysics.radius, 0)
        XCTAssertTrue(rig.observeWholeTable(yaw: .pi / 2))
        rig.snapToTarget()
        let distance = simd_length(camera.simdPosition - center)
        // Golden from the user-selected r4/C real-scene capture, not the fit implementation.
        XCTAssertEqual(distance, 3.837202, accuracy: 0.002)
        let height = camera.position.y
        let fov = try XCTUnwrap(camera.camera).fieldOfView
        for _ in 0..<24 {
            rig.handleHorizontalSwipe(delta: (.pi / 12) / 0.0025)
            rig.snapToTarget()
            XCTAssertEqual(rig.currentPivot.x, 0, accuracy: 0.0001)
            XCTAssertEqual(rig.currentPivot.z, 0, accuracy: 0.0001)
            XCTAssertEqual(rig.currentPivot.y, center.y, accuracy: 0.0001)
            XCTAssertEqual(simd_length(camera.simdPosition - center), distance, accuracy: 0.0001)
            XCTAssertEqual(camera.position.y, height, accuracy: 0.0001)
            XCTAssertEqual(camera.camera!.fieldOfView, fov, accuracy: 0.0001)
        }
        for _ in 0..<3 {
            XCTAssertTrue(rig.observeWholeTable(yaw: .pi / 2))
            rig.snapToTarget()
            XCTAssertEqual(simd_length(camera.simdPosition - center), distance, accuracy: 0.0001)
        }
        rig.applyTopDown2D()
        XCTAssertTrue(rig.observeWholeTable(yaw: .pi / 2))
        rig.snapToTarget()
        XCTAssertEqual(simd_length(camera.simdPosition - center), distance, accuracy: 0.0001)
    }

    func testCaptureComparison() throws {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["GLOBAL_CAMERA_DIR"] ?? env["TEST_RUNNER_GLOBAL_CAMERA_DIR"] else {
            throw XCTSkip("Opt-in camera preview")
        }
        let out = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let scene = AngleTrainingScene()
        scene.configureDailyClearanceRendering()
        scene.setupScene()
        XCTAssertTrue(scene.applyTableStyle(.charcoal, showsSights: true))
        XCTAssertTrue(scene.applyClothColor(.green))
        scene.setCameraMode(.perspective3D, animated: false)
        scene.hideAllBalls(); scene.hideCueStick()
        let balls: [(String, Float, Float)] = [
            ("cueBall", -0.75, 0.26), ("_1", -0.35, -0.18), ("_2", 0.72, 0.35),
            ("_3", 0.88, -0.40), ("_4", -0.95, -0.43), ("_5", 0.1, 0.48),
            ("_6", 0.42, -0.1), ("_8", 0.14, 0.12), ("_9", -0.55, 0.50)]
        for (key, x, z) in balls {
            scene.showBall(key: key, scenePosition: SCNVector3(x, scene.surfaceY + BallPhysics.radius, z))
            XCTAssertFalse(try XCTUnwrap(scene.allBallNodes[key]).isHidden)
        }
        let size = CGSize(width: 1170, height: 540)
        let rig = try XCTUnwrap(scene.cameraRig)
        rig.viewportSize = size
        XCTAssertTrue(rig.observeWholeTable(yaw: .pi / 2))
        rig.snapToTarget()
        let cam = try XCTUnwrap(scene.cameraNode)
        let pivot = SCNVector3(0, scene.surfaceY + BallPhysics.radius, 0)
        let baseDistance = simd_length(cam.simdPosition - SIMD3<Float>(pivot.x, pivot.y, pivot.z)) / CameraRig.overviewDistanceScale
        let fov = try XCTUnwrap(cam.camera).fieldOfView
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene; renderer.pointOfView = cam
        renderer.delegate = scene.contactOcclusion
        var allDirectionDistance = baseDistance
        for index in 0..<24 {
            XCTAssertTrue(rig.observeWholeTable(yaw: .pi / 2 + Float(index) * .pi / 12))
            rig.snapToTarget()
            allDirectionDistance = max(allDirectionDistance,
                simd_length(cam.simdPosition - SIMD3<Float>(pivot.x, pivot.y, pivot.z)) / CameraRig.overviewDistanceScale)
        }
        let factors: [Float] = [1, 1.10, 1.18, 1.28, allDirectionDistance / baseDistance * 1.05]
        var records: [[String: Any]] = []
        for (variant, factor) in factors.enumerated() {
            let distance = baseDistance * factor
            for frame in 0..<24 {
                let yaw = Float.pi / 2 + Float(frame) * .pi / 12
                let elevation = Float.pi / 4
                SCNTransaction.begin()
                SCNTransaction.disableActions = true
                cam.position = SCNVector3(pivot.x + cos(yaw) * cos(elevation) * distance,
                    pivot.y + sin(elevation) * distance,
                    pivot.z + sin(yaw) * cos(elevation) * distance)
                cam.look(at: pivot, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
                SCNTransaction.commit()
                SCNTransaction.flush()
                let name = "\(variant)-\(frame).png"
                _ = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
                let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
                try XCTUnwrap(image.pngData()).write(to: out.appendingPathComponent(name))
                let center = renderer.projectPoint(pivot)
                XCTAssertEqual(center.x, Float(size.width / 2), accuracy: 1)
                XCTAssertEqual(center.y, Float(size.height / 2), accuracy: 1)
                let bounds = [-1, 1].flatMap { sx in [-1, 1].map { sz in
                    renderer.projectPoint(SCNVector3(Float(sx) * Float(rig.tableOuterHalfLength),
                        pivot.y, Float(sz) * Float(rig.tableOuterHalfWidth)))
                }}
                if variant == 4 {
                    for point in bounds {
                        XCTAssertGreaterThanOrEqual(point.x, 0); XCTAssertLessThanOrEqual(point.x, Float(size.width))
                        XCTAssertGreaterThanOrEqual(point.y, 0); XCTAssertLessThanOrEqual(point.y, Float(size.height))
                    }
                }
                records.append(["image": name, "variant": variant, "rotationDegrees": frame * 15,
                    "distanceFactor": factor, "distanceMeters": distance, "pitchDegrees": 45,
                    "verticalFOVDegrees": fov, "center": [center.x, center.y],
                    "widthFraction": (bounds.map(\.x).max()! - bounds.map(\.x).min()!) / Float(size.width),
                    "heightFraction": (bounds.map(\.y).max()! - bounds.map(\.y).min()!) / Float(size.height)])
            }
        }
        try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
            .write(to: out.appendingPathComponent("parameters.json"))
    }
}

extension GlobalCameraPreviewTests {
    /// Opt-in real SceneKit stills. No application camera defaults are changed.
    func testObserverLandscapeOptions() throws {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["TEST_RUNNER_OBSERVER_OPTIONS_DIR"] ?? env["OBSERVER_OPTIONS_DIR"],
              let input = env["TEST_RUNNER_OBSERVER_SEQUENCE"] ?? env["OBSERVER_SEQUENCE"] else {
            throw XCTSkip("Opt-in observer comparison")
        }
        let out = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let sequence = try decoder.decode(PositionPlaySequence.self, from: Data(contentsOf: URL(fileURLWithPath: input)))
        let step = sequence.steps[6]
        let scene = AngleTrainingScene(); scene.setupScene()
        XCTAssertTrue(scene.applyTableStyle(.charcoal, showsSights: true))
        XCTAssertTrue(scene.applyClothColor(.green))
        scene.setCameraMode(.perspective3D, animated: false)
        let camera = try XCTUnwrap(scene.cameraNode), rig = try XCTUnwrap(scene.cameraRig)
        let size = CGSize(width: 1170, height: 540); rig.viewportSize = size
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene; renderer.pointOfView = camera; renderer.delegate = scene.contactOcclusion
        let prediction = try XCTUnwrap(PositionPlayShotSolver.solve(before: step.before, shot: step.shot, surfaceY: scene.surfaceY))
        let variants: [(String, Float, Float, Float, Float)] = [
            ("A",0.84,0.38,0.35,48), ("B",0.80,0.50,0.60,48),
            ("C",0.80,0.50,0.60,40), ("D",0.80,0.50,0.60,34),
            ("E",0.80,0.50,0.60,74)]
        var records: [[String: Any]] = []
        for layout in ["snake7", "long"] {
            scene.hideAllBalls(); scene.hideCueStick()
            var cue = SCNVector3Zero
            if layout == "snake7" {
                for (key, point) in step.before.onTable {
                    let position = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: point.x, y: point.y), surfaceY: scene.surfaceY)
                    scene.showBall(key: key, scenePosition: position)
                    if key == PositionPlayBall.cueKey { cue = position }
                }
            } else {
                cue = SCNVector3(-0.90,scene.surfaceY+BallPhysics.radius,0.15)
                scene.showBall(key: "cueBall", scenePosition: cue)
                scene.showBall(key: "_1", scenePosition: SCNVector3(0.65,cue.y,-0.15))
                scene.showBall(key: "_8", scenePosition: SCNVector3(0.85,cue.y,0.40))
            }
            let aim = layout == "snake7" ? prediction.aimDirection : (SCNVector3(0.65,cue.y,-0.15)-cue).normalized()
            scene.updateCueStick(cueBallPosition: cue, aimDirection: aim)
            let dx = aim.x / hypot(aim.x,aim.z), dz = aim.z / hypot(aim.x,aim.z)
            let halfL = Float(rig.tableOuterHalfLength), halfW = Float(rig.tableOuterHalfWidth)
            let tx = abs(dx)>0.00001 ? ((dx>0 ? -halfL:halfL)-cue.x)/(-dx) : Float.infinity
            let tz = abs(dz)>0.00001 ? ((dz>0 ? -halfW:halfW)-cue.z)/(-dz) : Float.infinity
            let edge = max(0,min(tx,tz))
            for (id,height,setback,ahead,fov) in variants {
                let distance = edge+setback
                let eye = SCNVector3(cue.x-dx*distance,scene.surfaceY+height,cue.z-dz*distance)
                let look = SCNVector3(cue.x+dx*ahead,scene.surfaceY+(id == "A" ? BallPhysics.radius:0),cue.z+dz*ahead)
                SCNTransaction.begin(); SCNTransaction.disableActions = true
                camera.position = eye
                camera.look(at: look,up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
                camera.camera!.projectionDirection = .vertical
                camera.camera!.fieldOfView = CGFloat(fov)
                SCNTransaction.commit(); SCNTransaction.flush()
                _ = renderer.snapshot(atTime:0,with:size,antialiasingMode:.multisampling4X)
                let image = renderer.snapshot(atTime:0,with:size,antialiasingMode:.multisampling4X)
                let name = "\(layout)-\(id).png"
                try XCTUnwrap(image.pngData()).write(to:out.appendingPathComponent(name))
                let p = renderer.projectPoint(cue)
                XCTAssertTrue(p.x.isFinite && p.y.isFinite && p.z > 0 && p.z < 1)
                if id == "A" {
                    let baseline = try XCTUnwrap(CameraRig.playerPose(view:.thirdPerson,cue:cue,aim:aim,
                        surfaceY:scene.surfaceY,halfLength:halfL,halfWidth:halfW))
                    XCTAssertEqual(baseline.height,height,accuracy:0.00001)
                    XCTAssertEqual(baseline.radius,distance+ahead,accuracy:0.00001)
                    XCTAssertEqual(-baseline.pitch,atan2(eye.y-look.y,distance+ahead),accuracy:0.00001)
                }
                records.append(["layout":layout,"id":id,"image":name,"height":height,"setback":setback,
                    "lookAhead":ahead,"fov":fov,"distance":distance,
                    "pitch":atan2(eye.y-look.y,distance+ahead)*180/Float.pi,
                    "cueScreen":[p.x,p.y],"eye":[eye.x,eye.y,eye.z]])
            }
        }
        try JSONSerialization.data(withJSONObject:records,options:[.prettyPrinted,.sortedKeys])
            .write(to:out.appendingPathComponent("parameters.json"))
    }
}

extension GlobalCameraPreviewTests {
    /// Offline screening matrix only; deliberately retains cropped candidates for review.
    func testObserverScreeningMatrix() throws {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["TEST_RUNNER_OBSERVER_MATRIX_DIR"] ?? env["OBSERVER_MATRIX_DIR"] else {
            throw XCTSkip("Opt-in observer screening matrix")
        }
        let out = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let scene = AngleTrainingScene(); scene.setupScene()
        XCTAssertTrue(scene.applyTableStyle(.charcoal, showsSights: true))
        XCTAssertTrue(scene.applyClothColor(.green))
        scene.setCameraMode(.perspective3D, animated: false)
        let camera = try XCTUnwrap(scene.cameraNode), rig = try XCTUnwrap(scene.cameraRig)
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene; renderer.pointOfView = camera; renderer.delegate = scene.contactOcclusion
        let y = scene.surfaceY + BallPhysics.radius
        let layouts: [(String, SCNVector3, SCNVector3)] = [
            ("L1",SCNVector3(-1.21,y,0.15),SCNVector3(0.80,y,0.15)),
            ("L2",SCNVector3(-0.25,y,0.15),SCNVector3(0.80,y,0.15)),
            ("L3",SCNVector3(-1.21,y,0.15),SCNVector3(-0.71,y,0.15)),
            ("S1",SCNVector3(0.40,y,-0.575),SCNVector3(0.40,y,0.425)),
            ("S2",SCNVector3(0.40,y,-0.10),SCNVector3(0.40,y,0.40)),
            ("D1",SCNVector3(-1.05,y,-0.48),SCNVector3(0.80,y,0.40))]
        var variants: [(String, Float, Float, Float)] = [("OLD",0.84,0.38,0.35)]
        for h: Float in [0.80,0.92] { for s: Float in [0.38,0.50] { for a: Float in [0.35,0.60] {
            variants.append(("P\(variants.count)",h,s,a))
        } } }
        var records: [[String: Any]] = []
        for (layout,cue,target) in layouts {
            scene.hideAllBalls(); scene.hideCueStick()
            for p in [cue,target] {
                XCTAssertLessThan(abs(p.x)+BallPhysics.radius,Float(1.270))
                XCTAssertLessThan(abs(p.z)+BallPhysics.radius,Float(0.635))
            }
            let aim = (target-cue).normalized()
            scene.showBall(key: "cueBall", scenePosition: cue)
            scene.showBall(key: "_8", scenePosition: target)
            scene.updateCueStick(cueBallPosition: cue, aimDirection: aim)
            let line = scene.addLine(from: cue+aim*BallPhysics.radius,
                                     to: target-aim*BallPhysics.radius,color:.white,radius:0.0012)
            let halfL = Float(rig.tableOuterHalfLength), halfW = Float(rig.tableOuterHalfWidth)
            let dx = aim.x, dz = aim.z
            let tx = abs(dx)>0.00001 ? ((dx>0 ? -halfL:halfL)-cue.x)/(-dx) : Float.infinity
            let tz = abs(dz)>0.00001 ? ((dz>0 ? -halfW:halfW)-cue.z)/(-dz) : Float.infinity
            let edge = max(0,min(tx,tz))
            for (id,height,setback,ahead) in variants {
                let distance = edge+setback
                let eye = SCNVector3(cue.x-dx*distance,scene.surfaceY+height,cue.z-dz*distance)
                XCTAssertTrue(abs(eye.x)>halfL || abs(eye.z)>halfW)
                let look = SCNVector3(cue.x+dx*ahead,scene.surfaceY+(id == "OLD" ? BallPhysics.radius:0),cue.z+dz*ahead)
                for fov: Float in (id == "OLD" ? [48] : [40,48,58]) {
                    for (orientation,size) in [("H",CGSize(width:1170,height:540)),("V",CGSize(width:540,height:850))] {
                        try autoreleasepool {
                            rig.viewportSize = size
                            SCNTransaction.begin(); SCNTransaction.disableActions = true
                            camera.position = eye
                            // Explicit yaw/pitch avoids SCNNode.look(at:) roll roundoff near axis-aligned shots.
                            camera.eulerAngles = SCNVector3(-atan2(eye.y-look.y,distance+ahead),atan2(-dx,-dz),0)
                            camera.camera!.projectionDirection = .vertical
                            camera.camera!.fieldOfView = CGFloat(fov)
                            SCNTransaction.commit(); SCNTransaction.flush()
                            _ = renderer.snapshot(atTime:0,with:size,antialiasingMode:.multisampling4X)
                            let image = renderer.snapshot(atTime:0,with:size,antialiasingMode:.multisampling4X)
                            let key = "\(layout)-\(id)-\(Int(fov))-\(orientation)"
                            try XCTUnwrap(image.pngData()).write(to:out.appendingPathComponent(key+".png"))
                            let cp = renderer.projectPoint(cue), tp = renderer.projectPoint(target)
                            let center = renderer.projectPoint(look)
                            XCTAssertEqual(center.x,Float(size.width/2),accuracy:0.5)
                            XCTAssertEqual(center.y,Float(size.height/2),accuracy:0.5)
                            XCTAssertEqual(cp.x,Float(size.width/2),accuracy:0.5)
                            let right = camera.simdWorldRight
                            XCTAssertEqual(right.y,0,accuracy:0.00001)
                            for p in [cp,tp] { XCTAssertTrue(p.x.isFinite && p.y.isFinite && p.z>0 && p.z<1) }
                            func visible(_ p: SCNVector3) -> Bool {
                                p.x>=0 && p.x<=Float(size.width) && p.y>=0 && p.y<=Float(size.height)
                            }
                            if id == "OLD" {
                                let baseline = try XCTUnwrap(CameraRig.playerPose(view:.thirdPerson,cue:cue,aim:aim,surfaceY:scene.surfaceY,halfLength:halfL,halfWidth:halfW))
                                XCTAssertEqual(baseline.radius,distance+ahead,accuracy:0.00001)
                                XCTAssertEqual(-baseline.pitch,atan2(eye.y-look.y,distance+ahead),accuracy:0.00001)
                            }
                            records.append(["key":key,"layout":layout,"profile":id,"orientation":orientation,
                                "height":height,"setback":setback,"ahead":ahead,"fov":fov,
                                "distance":distance,"pitch":atan2(eye.y-look.y,distance+ahead)*180/Float.pi,
                                "shotDistance":(target-cue).length(),"image":key+".png",
                                "cueVisible":visible(cp),"targetVisible":visible(tp),
                                "cueScreen":[cp.x,cp.y],"targetScreen":[tp.x,tp.y],
                                "cue":[cue.x,cue.z],"target":[target.x,target.z],"eye":[eye.x,eye.y,eye.z]])
                        }
                    }
                }
            }
            scene.removeLine(line)
        }
        XCTAssertEqual(records.count,300)
        try JSONSerialization.data(withJSONObject:records,options:[.prettyPrinted,.sortedKeys])
            .write(to:out.appendingPathComponent("parameters.json"))
    }
}
