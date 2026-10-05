import XCTest
import SceneKit
@testable import QiuJi

final class TwoViewCameraTests: XCTestCase {
    private func profile() throws -> TwoViewCamera.RailProfile {
        try XCTUnwrap(TwoViewCamera.RailProfile.candidate(
            anchor: SIMD3(0, 0.8, 0), halfExtents: SIMD2(1.4055, 0.7995),
            viewport: CGSize(width: 874, height: 402),
            insets: UIEdgeInsets(top: 44, left: 116, bottom: 24, right: 116)))
    }

    // Independent perspective projection of the declared outer-table envelope.
    // These checks do not certify sightlines through the actual USDZ mesh.
    private func projected(_ point: SIMD3<Float>, in pose: TwoViewCamera.Pose,
                           viewport: CGSize) -> CGPoint? {
        let local = pose.orientation.inverse.act(point - pose.eye)
        guard -local.z > 0.01 else { return nil }
        let tangent = tan(pose.fov * .pi / 360)
        let x = local.x / (-local.z * tangent * Float(viewport.width / viewport.height))
        let y = local.y / (-local.z * tangent)
        return CGPoint(x: CGFloat(x + 1) * viewport.width / 2,
                       y: CGFloat(1 - y) * viewport.height / 2)
    }

    private func tableEnvelope(_ rail: TwoViewCamera.RailProfile) -> [SIMD3<Float>] {
        var points: [SIMD3<Float>] = []
        for x in [-rail.tableHalfExtents.x, rail.tableHalfExtents.x] {
            for z in [-rail.tableHalfExtents.y, rail.tableHalfExtents.y] {
                for y in [Float(0), 0.12] { points.append(rail.anchor + SIMD3(x, y, z)) }
            }
        }
        return points
    }

    private func readableRect(_ rail: TwoViewCamera.RailProfile) -> CGRect {
        CGRect(x: rail.readableInsets.left, y: rail.readableInsets.top,
               width: rail.viewport.width - rail.readableInsets.left - rail.readableInsets.right,
               height: rail.viewport.height - rail.readableInsets.top - rail.readableInsets.bottom)
    }

    private func settle(_ camera: TwoViewCamera) {
        for _ in 0..<180 { camera.update(deltaTime: 1 / 60) }
    }

    private func settle(_ rig: CameraRig) {
        for _ in 0..<180 { rig.update(deltaTime: 1 / 60) }
    }

    func testTableRailHasFiniteMonotonicHeightPitchAndInvertibleRetreatAcrossFullTurn() throws {
        let rail = try profile()
        for angle in stride(from: -Float.pi, through: Float.pi, by: 0.025) {
            var previousRadius: Float = 0
            var previousHeight: Float = 0
            var previousDepression: Float = -.pi
            for step in 0...20 {
                let s = Float(step) / 20
                let pose = rail.pose(yaw: angle, progress: s)
                let radius = hypot(pose.eye.x - rail.anchor.x, pose.eye.z - rail.anchor.z)
                let depression = asin(-pose.forward.y)
                XCTAssertTrue([pose.eye.x, pose.eye.y, pose.eye.z, radius, depression, pose.fov].allSatisfy(\.isFinite))
                XCTAssertEqual(simd_length(pose.orientation.vector), 1, accuracy: 0.00001)
                XCTAssertGreaterThanOrEqual(radius + 0.00001, previousRadius)
                XCTAssertGreaterThanOrEqual(pose.eye.y + 0.00001, previousHeight)
                XCTAssertGreaterThanOrEqual(depression + 0.00001, previousDepression)
                previousRadius = radius; previousHeight = pose.eye.y; previousDepression = depression
                XCTAssertEqual(pose.fov, rail.fov)
                XCTAssertLessThanOrEqual(abs(pose.eye.x), BakedTrainingRoom.cameraSafeHalfExtents.x + 0.00001)
                XCTAssertLessThanOrEqual(abs(pose.eye.z), BakedTrainingRoom.cameraSafeHalfExtents.y + 0.00001)
                XCTAssertEqual(rail.progress(yaw: angle, radius: radius), s, accuracy: 0.00001)
                XCTAssertNotNil(rail.legalPose(yaw: angle, progress: s))
            }
            let near = rail.pose(yaw: angle, progress: 0), far = rail.pose(yaw: angle, progress: 1)
            XCTAssertLessThan(near.eye.y, far.eye.y - 0.01)
            XCTAssertLessThan(asin(-near.forward.y), asin(-far.forward.y) - 0.01)
        }
    }

    func testPositiveDownwardDragRetreatsAndBoundaryDoesNotAccumulateHiddenInput() throws {
        let rail = try profile()
        let camera = TwoViewCamera(pose: rail.pose(yaw: .pi, progress: 1))
        camera.enterThirdPerson(rail, yaw: .pi, duration: 0.1)
        settle(camera)
        camera.vertical(delta: 5000)
        camera.vertical(delta: -100)
        settle(camera)
        XCTAssertEqual(camera.progress, 0.8, accuracy: 0.00001)
        camera.vertical(delta: 100)
        settle(camera)
        XCTAssertEqual(camera.progress, 1, accuracy: 0.00001)
        XCTAssertEqual(camera.mode, .thirdPerson)
    }

    func testContinuousPanDuringConnectorAccumulatesInsteadOfRestartingEachDelta() throws {
        let rail = try profile()
        let camera = TwoViewCamera(pose: rail.pose(yaw: .pi, progress: 0.5))
        camera.enterThirdPerson(rail, yaw: .pi, duration: 1)
        camera.update(deltaTime: 0.1)
        let startYaw = atan2(camera.pose.eye.z, camera.pose.eye.x)
        for _ in 0..<10 {
            camera.horizontal(delta: 20)
            camera.update(deltaTime: 0.01)
        }
        settle(camera)
        XCTAssertEqual(TwoViewCamera.angleDelta(startYaw, camera.yaw), 0.5, accuracy: 0.00001)
        XCTAssertEqual(camera.owner, .manual)
    }

    func testFirstPersonHeadTurnKeepsEyeLensAndModeAndRejectsVerticalInput() {
        let base = TwoViewCamera.Pose.looking(eye: SIMD3(-1, 1.15, 0), yaw: .pi, pitch: -0.2, fov: 32)
        let camera = TwoViewCamera(pose: base)
        camera.enterFirstPerson(base, duration: 0.1)
        settle(camera)
        XCTAssertFalse(camera.vertical(delta: 100))
        camera.horizontal(delta: 400)
        settle(camera)
        XCTAssertEqual(camera.pose.eye, base.eye)
        XCTAssertEqual(camera.pose.fov, base.fov)
        XCTAssertEqual(camera.mode, .firstPerson)
        XCTAssertGreaterThan(simd_length(camera.pose.forward - base.forward), 0.5)
    }

    func testZeroAndInvalidInputsCannotAcquireOwnershipOrCancelTransition() throws {
        let rail = try profile()
        let camera = TwoViewCamera(pose: rail.pose(yaw: .pi, progress: 0.5))
        camera.enterThirdPerson(rail, yaw: .pi, duration: 1)
        let revision = camera.requestRevision
        XCTAssertFalse(camera.horizontal(delta: 0))
        XCTAssertFalse(camera.vertical(delta: 0))
        XCTAssertFalse(camera.horizontal(delta: .nan))
        XCTAssertFalse(camera.pinch(scale: 1))
        XCTAssertFalse(camera.pinch(scale: 0))
        XCTAssertEqual(camera.requestRevision, revision)
        XCTAssertEqual(camera.owner, .automatic)
        XCTAssertTrue(camera.isTransitioning)
    }

    func testMidTransitionSnapshotRestoresVisiblePoseWithoutResumingOldTarget() throws {
        let rail = try profile()
        let camera = TwoViewCamera(pose: rail.pose(yaw: 0, progress: 0.2))
        camera.enterThirdPerson(rail, yaw: .pi / 2, duration: 1)
        camera.update(deltaTime: 0.3)
        let snapshot = camera.snapshot()
        camera.update(deltaTime: 0.7)
        camera.restore(snapshot)
        camera.update(deltaTime: 2)
        XCTAssertEqual(camera.pose.eye, snapshot.pose.eye)
        XCTAssertEqual(camera.pose.orientation.vector, snapshot.pose.orientation.vector)
        XCTAssertFalse(camera.hasPendingMotion)
        let visibleBearing = atan2(snapshot.pose.eye.z - rail.anchor.z, snapshot.pose.eye.x - rail.anchor.x)
        camera.horizontal(delta: 20)
        XCTAssertEqual(camera.pose.eye, snapshot.pose.eye)
        settle(camera)
        XCTAssertEqual(camera.mode, snapshot.mode)
        XCTAssertEqual(TwoViewCamera.angleDelta(visibleBearing, camera.yaw), 0.05, accuracy: 0.00001,
                       "Manual takeover must recover table orbit bearing from the visible eye, not gaze yaw.")
    }

    func testInvalidReadableViewportDoesNotPretendToFitSubjects() {
        XCTAssertNil(TwoViewCamera.RailProfile.candidate(anchor: SIMD3(0, 0.8, 0),
            halfExtents: SIMD2(1.4055, 0.7995), viewport: CGSize(width: 300, height: 300),
            insets: UIEdgeInsets(top: 0, left: 151, bottom: 0, right: 0)))
    }

    func testModeSwitchRestoresIndependentVisiblePosesAndExplicitEntryResetsHead() throws {
        let rail = try profile()
        let base = TwoViewCamera.Pose.looking(eye: SIMD3(-1, 1.15, 0), yaw: .pi, pitch: -0.2, fov: 32)
        let camera = TwoViewCamera(pose: rail.pose(yaw: .pi, progress: 1))
        camera.enterThirdPerson(rail, yaw: .pi, duration: 0.1)
        settle(camera)
        camera.vertical(delta: -200)
        camera.horizontal(delta: 100)
        settle(camera)
        let third = camera.pose
        camera.enterFirstPerson(base, duration: 0.1)
        settle(camera)
        camera.horizontal(delta: 100)
        settle(camera)
        let first = camera.pose
        XCTAssertTrue(camera.switchToRememberedMode(.thirdPerson, duration: 0.1))
        settle(camera)
        XCTAssertEqual(camera.pose.eye, third.eye)
        XCTAssertEqual(camera.pose.orientation.vector, third.orientation.vector)
        XCTAssertEqual(camera.owner, .manual)
        XCTAssertTrue(camera.switchToRememberedMode(.firstPerson, duration: 0.1))
        settle(camera)
        XCTAssertEqual(camera.pose.eye, first.eye)
        XCTAssertEqual(camera.pose.orientation.vector, first.orientation.vector)
        camera.enterFirstPerson(base, duration: 0.1)
        settle(camera)
        XCTAssertEqual(camera.headYaw, 0)
        XCTAssertEqual(camera.pose.eye, base.eye)
        XCTAssertEqual(camera.pose.orientation.vector, base.orientation.vector)
    }

    func testNewShotContextPreservesTableMemoryButInvalidatesFirstPersonReentry() throws {
        let rail = try profile()
        let camera = TwoViewCamera(pose: rail.pose(yaw: .pi, progress: 1))
        camera.enterThirdPerson(rail, yaw: .pi, duration: 0.1)
        settle(camera)
        camera.horizontal(delta: 100)
        settle(camera)
        let third = camera.pose
        let base = TwoViewCamera.Pose.looking(eye: SIMD3(-1, 1.15, 0), yaw: .pi, pitch: -0.2, fov: 32)
        camera.enterFirstPerson(base, duration: 0.1)
        settle(camera)
        camera.horizontal(delta: 100)
        settle(camera)
        let visible = camera.pose
        camera.setViewingContext(UUID())
        camera.update(deltaTime: 1)
        XCTAssertEqual(camera.pose.eye, visible.eye)
        XCTAssertEqual(camera.pose.orientation.vector, visible.orientation.vector)
        XCTAssertEqual(camera.owner, .manual)
        XCTAssertTrue(camera.switchToRememberedMode(.thirdPerson, duration: 0.1))
        settle(camera)
        XCTAssertEqual(camera.pose.eye, third.eye)
        XCTAssertEqual(camera.pose.orientation.vector, third.orientation.vector)
        XCTAssertFalse(camera.switchToRememberedMode(.firstPerson, duration: 0.1))
    }

    func testManualLayoutChangeAndSnapshotRestoreKeepActualEyeLensAndUpdateReadableDomain() throws {
        let rail = try profile()
        let camera = TwoViewCamera(pose: rail.pose(yaw: .pi, progress: 1))
        camera.enterThirdPerson(rail, yaw: .pi, duration: 0.1)
        settle(camera)
        camera.vertical(delta: -100)
        settle(camera)
        let snapshot = camera.snapshot()
        let viewport = CGSize(width: 500, height: 400)
        let insets = UIEdgeInsets(top: 44, left: 116, bottom: 24, right: 116)
        camera.revalidateLayout(viewport: viewport, insets: insets)
        XCTAssertEqual(camera.profile?.viewport, viewport)
        XCTAssertEqual(camera.pose.eye, snapshot.pose.eye)
        XCTAssertEqual(camera.pose.fov, snapshot.pose.fov)
        XCTAssertEqual(camera.progress, snapshot.progress)
        camera.restore(snapshot)
        XCTAssertEqual(camera.profile?.viewport, viewport)
        XCTAssertEqual(camera.profile?.readableInsets, insets)
        XCTAssertEqual(camera.pose.eye, snapshot.pose.eye)
        XCTAssertEqual(camera.owner, .manual)
    }

    func testRestoredManualFirstPersonMidConnectorAcceptsHeadTurnWithoutMovingVisibleEye() throws {
        let rail = try profile()
        let camera = TwoViewCamera(pose: rail.pose(yaw: .pi, progress: 1))
        camera.enterThirdPerson(rail, yaw: .pi, duration: 0.1)
        settle(camera)
        let base = TwoViewCamera.Pose.looking(eye: SIMD3(-1, 1.15, 0), yaw: .pi, pitch: -0.2, fov: 32)
        camera.enterFirstPerson(base, duration: 0.1)
        settle(camera)
        camera.horizontal(delta: 100)
        settle(camera)
        XCTAssertTrue(camera.switchToRememberedMode(.thirdPerson, duration: 0.1))
        settle(camera)
        XCTAssertTrue(camera.switchToRememberedMode(.firstPerson, duration: 1))
        camera.update(deltaTime: 0.5)
        let halfway = camera.pose
        XCTAssertTrue(camera.switchToRememberedMode(.thirdPerson, duration: 0.1))
        settle(camera)
        XCTAssertTrue(camera.switchToRememberedMode(.firstPerson, duration: 0.1))
        settle(camera)
        XCTAssertEqual(camera.pose.eye, halfway.eye)
        camera.horizontal(delta: 100)
        settle(camera)
        XCTAssertEqual(camera.pose.eye, halfway.eye)
        XCTAssertGreaterThan(simd_length(camera.pose.forward - halfway.forward), 0.1)
    }

    func testNewContextCancelsOldFirstPersonConnectorAndHoldsActualPose() throws {
        let rail = try profile()
        let camera = TwoViewCamera(pose: rail.pose(yaw: 0, progress: 0.5))
        let base = TwoViewCamera.Pose.looking(eye: SIMD3(-1, 1.15, 0), yaw: .pi, pitch: -0.2, fov: 32)
        camera.enterFirstPerson(base, duration: 1)
        camera.update(deltaTime: 0.25)
        let visible = camera.pose
        let revision = camera.requestRevision
        camera.setViewingContext(UUID())
        camera.update(deltaTime: 3)
        XCTAssertEqual(camera.pose.eye, visible.eye)
        XCTAssertEqual(camera.pose.orientation.vector, visible.orientation.vector)
        XCTAssertFalse(camera.hasPendingMotion)
        XCTAssertGreaterThan(camera.requestRevision, revision)
    }

    func testFarOverviewProjectsWholeTableInsideActualHUDAndNearCanCropFarSide() throws {
        let rail = try profile()
        let rect = readableRect(rail).insetBy(dx: -0.01, dy: -0.01)
        var nearCrops = false
        for step in 0..<144 {
            let theta = Float(step) * 2 * .pi / 144
            let far = rail.pose(yaw: theta, progress: 1)
            for corner in tableEnvelope(rail) {
                let p = try XCTUnwrap(projected(corner, in: far, viewport: rail.viewport))
                XCTAssertTrue(rect.contains(p), "theta=\(theta), point=\(corner), screen=\(p)")
            }
            let near = rail.pose(yaw: theta, progress: 0)
            if tableEnvelope(rail).contains(where: { point in
                guard let p = projected(point, in: near, viewport: rail.viewport) else { return true }
                return !rect.contains(p)
            }) { nearCrops = true }
            XCTAssertNotNil(rail.legalPose(yaw: theta, progress: 0))
            let entry = rail.entryProgress(yaw: theta)
            XCTAssertGreaterThanOrEqual(entry, 0)
            XCTAssertLessThanOrEqual(entry, 1)
        }
        XCTAssertTrue(nearCrops, "Advancing must allow the low table-side perspective instead of enforcing an overview everywhere.")
    }

    func testNearRailFirstPersonEntryRaisesEyeBeforeFramingAndManualHeadKeepsThatEye() throws {
        let cue = SIMD3<Float>(-1.229, 0.828575, -0.4)
        let strike = cue - SIMD3(BallPhysics.radius, 0, 0)
        let reference = TwoViewCamera.Pose.looking(eye: SIMD3(-2.129, 0.998, -0.4),
            yaw: .pi, pitch: -0.2, fov: 26)
        var lastProtected: [SIMD3<Float>] = []
        func clear(_ eye: SIMD3<Float>, _ points: [SIMD3<Float>]) -> Bool {
            lastProtected = points
            return points.allSatisfy { point in
                let fraction = (-1.27 - point.x) / (eye.x - point.x)
                return fraction <= 0 || fraction >= 1
                    || point.y + fraction * (eye.y - point.y) > 0.837
            }
        }
        XCTAssertFalse(clear(reference.eye, [strike]))
        let entry = try XCTUnwrap(TwoViewCamera.firstPersonEntry(reference: reference, cue: cue,
            strike: strike, target: SIMD3(-0.4, cue.y, -0.03),
            viewport: CGSize(width: 874, height: 402),
            insets: UIEdgeInsets(top: 44, left: 116, bottom: 24, right: 116),
            maximumEyeY: 2.6, clear: clear))
        XCTAssertEqual(entry.eye.x, reference.eye.x)
        XCTAssertEqual(entry.eye.z, reference.eye.z)
        XCTAssertGreaterThan(entry.eye.y, 1.4)
        XCTAssertTrue(clear(entry.eye, [strike]))
        // The four-sample protection contract is separate from the full ball framing ROI.
        _ = TwoViewCamera.firstPersonEntry(reference: entry, cue: cue, strike: strike, target: nil,
            viewport: CGSize(width: 874, height: 402), insets: .zero, maximumEyeY: 2.6, clear: clear)
        XCTAssertEqual(lastProtected.count, 4)
        XCTAssertTrue(lastProtected.contains(strike))
        XCTAssertEqual(lastProtected.filter { $0.y < cue.y }.count, 3)
        XCTAssertTrue(lastProtected.contains { $0.z < cue.z })
        XCTAssertTrue(lastProtected.contains { $0.z > cue.z })
        let hud = CGRect(x: 116, y: 44, width: 874 - 232, height: 402 - 68)
        for center in [cue, SIMD3(-0.4, cue.y, -0.03)] {
            for x in [-BallPhysics.radius, BallPhysics.radius] {
                for y in [-BallPhysics.radius, BallPhysics.radius] {
                    for z in [-BallPhysics.radius, BallPhysics.radius] {
                        let point = try XCTUnwrap(projected(center + SIMD3(x, y, z), in: entry,
                                                           viewport: CGSize(width: 874, height: 402)))
                        XCTAssertTrue(hud.contains(point))
                    }
                }
            }
        }
        XCTAssertGreaterThan(entry.forward.x, 0, "Eye left of the cue must look toward it, not reverse the aim yaw.")
        let camera = TwoViewCamera(pose: reference)
        camera.enterFirstPerson(entry, duration: 0.1)
        settle(camera)
        camera.horizontal(delta: 100)
        settle(camera)
        XCTAssertEqual(camera.pose.eye, entry.eye)
        XCTAssertEqual(camera.pose.fov, entry.fov)
    }

    func testFirstPersonEntryRejectsHostReportedOcclusionInsteadOfOnlyWideningLens() {
        let reference = TwoViewCamera.Pose.looking(eye: SIMD3(-1, 1, 0), yaw: .pi, pitch: -0.2, fov: 26)
        XCTAssertNil(TwoViewCamera.firstPersonEntry(reference: reference,
            cue: SIMD3(0, 0.828575, 0), strike: SIMD3(-0.028575, 0.828575, 0),
            target: SIMD3(0.5, 0.828575, 0), viewport: CGSize(width: 874, height: 402),
            insets: .zero, maximumEyeY: 2.6, clear: { _, _ in false }))
    }
    func testTableRailIsPeriodicAndContinuousAcrossAxesAndWrapWithoutGazeSnaps() throws {
        let rail = try profile()
        for progress in [Float(0), 0.3, 0.7, 1] {
            let a = rail.pose(yaw: -.pi, progress: progress)
            let b = rail.pose(yaw: .pi, progress: progress)
            XCTAssertLessThan(simd_length(a.eye - b.eye), 0.00001)
            XCTAssertLessThan(simd_length(a.forward - b.forward), 0.00001)
            for boundary in [-Float.pi, -.pi / 2, 0, .pi / 2, .pi] {
                let before = rail.pose(yaw: boundary - 0.0001, progress: progress)
                let after = rail.pose(yaw: boundary + 0.0001, progress: progress)
                XCTAssertLessThan(simd_length(before.eye - after.eye), 0.003)
                XCTAssertLessThan(simd_length(before.forward - after.forward), 0.003)
            }
            var prior = rail.pose(yaw: -.pi, progress: progress)
            for theta in stride(from: -Float.pi + 0.007, through: Float.pi, by: 0.007) {
                let next = rail.pose(yaw: theta, progress: progress)
                // A dense regression net supplements the analytic periodic profile;
                // its finite sample count is not a proof of all-domain mesh safety.
                XCTAssertLessThan(simd_length(next.eye - prior.eye), 0.07)
                XCTAssertLessThan(simd_length(next.forward - prior.forward), 0.04)
                prior = next
            }
        }
    }

    func testTableFramingUsesCentralBandAndMayOffsetGazeFromOrbitBearing() throws {
        let rail = try profile()
        let rect = readableRect(rail)
        var foundOffset = false
        for step in 0..<144 {
            let theta = Float(step) * 2 * .pi / 144
            for s in [Float(0.5), 1] {
                let pose = rail.pose(yaw: theta, progress: s)
                let projectedCenter = try XCTUnwrap(projected(rail.anchor, in: pose, viewport: rail.viewport))
                // Candidate comfort band: central 60% of HUD-free width; no hard centre lock.
                XCTAssertGreaterThanOrEqual(projectedCenter.x, rect.minX + rect.width * 0.2)
                XCTAssertLessThanOrEqual(projectedCenter.x, rect.maxX - rect.width * 0.2)
                let gazeBearing = atan2(-pose.forward.z, -pose.forward.x)
                let offset = abs(TwoViewCamera.angleDelta(theta, gazeBearing))
                XCTAssertLessThanOrEqual(offset, 12 * .pi / 180 + 0.0001)
                if offset > 0.005 { foundOffset = true }
            }
        }
        XCTAssertTrue(foundOffset, "The horizontal gaze must be released from a rigid radial look-at.")
    }

    func testPreservingLensChangesReadableDomainWithoutChangingExistingRailCurve() throws {
        let rail = try profile()
        let resized = rail.preservingLens(viewport: CGSize(width: 402, height: 874), insets: .zero)
        for theta in stride(from: -Float.pi, through: Float.pi, by: 0.2) {
            for s in [Float(0), 0.3, 1] {
                let before = rail.pose(yaw: theta, progress: s), after = resized.pose(yaw: theta, progress: s)
                XCTAssertEqual(after.eye, before.eye)
                XCTAssertEqual(after.orientation.vector, before.orientation.vector)
                XCTAssertEqual(after.fov, before.fov)
            }
        }
        XCTAssertEqual(resized.viewport, CGSize(width: 402, height: 874))
        XCTAssertEqual(resized.readableInsets, .zero)
    }

    func testUnsupportedLayoutHoldsLastVisiblePoseAndCancelsRequestedRailMotion() throws {
        let rail = try profile()
        let camera = TwoViewCamera(pose: rail.pose(yaw: 1, progress: 0.5))
        camera.enterThirdPerson(rail, yaw: 1, duration: 0.1, progress: 0.5)
        settle(camera)
        let held = camera.pose
        camera.revalidateLayout(viewport: CGSize(width: 100, height: 100),
            insets: UIEdgeInsets(top: 40, left: 60, bottom: 40, right: 60))
        camera.horizontal(delta: 100)
        settle(camera)
        XCTAssertEqual(camera.pose.eye, held.eye)
        XCTAssertEqual(camera.pose.orientation.vector, held.orientation.vector)
        XCTAssertTrue(camera.railMotionLimited)
        XCTAssertFalse(camera.hasPendingMotion)
    }

    @MainActor
    func testRealCueMovementInvalidatesShotContextWithoutMovingActualPose() throws {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        vm.loadBoard(BoardSnapshot(onTable: [PositionPlayBall.cueKey: CanvasPoint(x: 0.6, y: 0.35),
                                            "_1": CanvasPoint(x: 0.3, y: 0.15)]))
        defer { vm.cancelDailyAttempt() }
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        let cue = try XCTUnwrap(vm.scene.cueBallNode)
        rig.usesTwoViewCameraControls = true
        rig.viewportSize = CGSize(width: 874, height: 402)
        for edit in 0...2 {
            XCTAssertTrue(rig.enterPlayerView(.thirdPerson, cue: cue.position,
                aim: SCNVector3(-1, 0, 0), duration: 0.1))
            for _ in 0..<180 { rig.update(deltaTime: 1 / 60) }
            let before = try XCTUnwrap(rig.twoViewSnapshot)
            // No physical displacement may revoke the valid context.
            vm.dragMoved(node: cue, worldPosition: cue.position)
            XCTAssertEqual(rig.twoViewSnapshot?.context, before.context)
            switch edit {
            case 0:
                vm.dragMoved(node: cue, worldPosition: SCNVector3(cue.position.x + 0.1, cue.position.y, cue.position.z))
            case 1:
                XCTAssertTrue(vm.moveDailyCue(node: cue,
                    world: SCNVector3(cue.position.x - 0.1, cue.position.y, cue.position.z), placement: .anywhere))
            default:
                XCTAssertTrue(vm.nudgeBall(key: PositionPlayBall.cueKey, direction: .right))
            }
            let after = try XCTUnwrap(rig.twoViewSnapshot)
            XCTAssertNotEqual(after.context, before.context)
            XCTAssertNil(after.firstPersonMemory)
            XCTAssertEqual(after.shotProfile?.anchor, before.shotProfile?.anchor)
            XCTAssertEqual(after.shotProfile?.tableHalfExtents, before.shotProfile?.tableHalfExtents)
            XCTAssertNil(after.thirdPersonMemory)
            XCTAssertEqual(after.pose.eye, before.pose.eye)
            XCTAssertEqual(after.pose.orientation.vector, before.pose.orientation.vector)
            XCTAssertFalse(rig.hasPendingDamping)
        }
    }

    func testLeftRightAndDollyRoundTripsDoNotConfuseGazeYawWithOrbitBearing() throws {
        let rail = try profile()
        let theta: Float = 0.7, s: Float = 0.5
        let initial = rail.pose(yaw: theta, progress: s)
        let camera = TwoViewCamera(pose: initial)
        camera.enterThirdPerson(rail, yaw: theta, duration: 0.1, progress: s)
        settle(camera)
        camera.horizontal(delta: 150)
        settle(camera)
        camera.horizontal(delta: -150)
        settle(camera)
        XCTAssertEqual(TwoViewCamera.angleDelta(theta, camera.yaw), 0, accuracy: 0.00001)
        XCTAssertLessThan(simd_length(camera.pose.eye - initial.eye), 0.00001)
        XCTAssertLessThan(simd_length(camera.pose.forward - initial.forward), 0.00001)
        camera.vertical(delta: 100)
        settle(camera)
        camera.vertical(delta: -100)
        settle(camera)
        XCTAssertEqual(camera.progress, s, accuracy: 0.00001)
        XCTAssertLessThan(simd_length(camera.pose.eye - initial.eye), 0.00001)
        XCTAssertLessThan(simd_length(camera.pose.forward - initial.forward), 0.00001)
        camera.pinch(scale: 1.03)
        settle(camera)
        camera.pinch(scale: 1 / 1.03)
        settle(camera)
        XCTAssertEqual(camera.progress, s, accuracy: 0.00001)
        XCTAssertLessThan(simd_length(camera.pose.eye - initial.eye), 0.00001)
        XCTAssertLessThan(simd_length(camera.pose.forward - initial.forward), 0.00001)
        let visible = camera.pose
        camera.vertical(delta: 0)
        camera.horizontal(delta: 0)
        camera.pinch(scale: 1)
        camera.update(deltaTime: 10)
        XCTAssertEqual(camera.pose.eye, visible.eye)
        XCTAssertEqual(camera.pose.orientation.vector, visible.orientation.vector)
    }

    @MainActor
    private func awaitShotAim(_ vm: PositionPlayViewModel) async throws -> SCNVector3 {
        let deadline = Date().addingTimeInterval(10)
        while (vm.isComputing || vm.currentPlayerAim == nil), Date() < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertFalse(vm.isComputing, "Shot solver did not finish: \(vm.statusText)")
        return try XCTUnwrap(vm.currentPlayerAim, "Shot did not produce an aim: \(vm.statusText)")
    }

    @MainActor
    func testTargetPocketAndBallChangesInvalidateShotReturnWithoutRestoringPermanentThirdPersonMemory() async throws {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        vm.loadBoard(BoardSnapshot(onTable: [PositionPlayBall.cueKey: CanvasPoint(x:0.6,y:0.35),
            "_1":CanvasPoint(x:0.3,y:0.15),"_2":CanvasPoint(x:0.7,y:0.15)]))
        defer { vm.cancelDailyAttempt() }
        vm.cameraMode = .perspective3D
        vm.enablePlayerCameraControls()
        let rig=try XCTUnwrap(vm.scene.cameraRig),cue=try XCTUnwrap(vm.scene.cueBallNode)
        rig.usesTwoViewCameraControls=true; rig.viewportSize=CGSize(width:874,height:402)
        rig.setTwoViewReadableInsets(UIEdgeInsets(top:44,left:116,bottom:24,right:116))
        XCTAssertTrue(vm.selectTarget(key:"_1"))
        let aim=try await awaitShotAim(vm)
        XCTAssertTrue(rig.enterPlayerView(.thirdPerson,cue:cue.position,aim:aim,duration:0.1)); settle(rig)
        XCTAssertTrue(rig.prepareTemporaryObservation(cue:cue.position,aim:aim))
        rig.handleVerticalSwipe(delta:-60); settle(rig)
        let observed=try XCTUnwrap(rig.twoViewSnapshot)
        XCTAssertNotNil(observed.shotProfile); XCTAssertNil(observed.profile)
        XCTAssertNil(observed.thirdPersonMemory)
        XCTAssertTrue(vm.selectTarget(key:"_2"))
        let changed=try XCTUnwrap(rig.twoViewSnapshot)
        XCTAssertNotEqual(changed.context,observed.context)
        XCTAssertNil(changed.firstPersonMemory); XCTAssertNil(changed.thirdPersonMemory)
        XCTAssertEqual(changed.pose.eye,observed.pose.eye)
        XCTAssertEqual(changed.pose.orientation.vector,observed.pose.orientation.vector)
        let newAim=try await awaitShotAim(vm)
        XCTAssertTrue(rig.prepareTemporaryObservation(cue:cue.position,aim:newAim))
        let fresh=try XCTUnwrap(rig.twoViewSnapshot)
        XCTAssertEqual(fresh.shotProfile?.context,fresh.context)
        XCTAssertEqual(fresh.pose.eye,observed.pose.eye)
        rig.endTemporaryObservation(); settle(rig)
        let returned=try XCTUnwrap(rig.twoViewSnapshot)
        XCTAssertEqual(returned.pose.eye,fresh.pose.eye)
        XCTAssertEqual(returned.pose.orientation.vector,fresh.pose.orientation.vector)
        XCTAssertFalse(returned.temporaryObserving)
        XCTAssertNil(returned.thirdPersonMemory)
        XCTAssertFalse(vm.scene.cameraNode.camera!.usesOrthographicProjection)
    }

    @MainActor
    func testPageObservationReleaseKeepsThirdPersonAndExplicitButtonRecenters() async throws {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        vm.loadBoard(BoardSnapshot(onTable: [PositionPlayBall.cueKey: CanvasPoint(x:0.6,y:0.35),
            "_1":CanvasPoint(x:0.3,y:0.15)]))
        defer { vm.cancelDailyAttempt() }
        vm.cameraMode = .perspective3D
        vm.enablePlayerCameraControls()
        let rig=try XCTUnwrap(vm.scene.cameraRig)
        rig.usesTwoViewCameraControls=true; rig.viewportSize=CGSize(width:874,height:402)
        rig.setTwoViewReadableInsets(UIEdgeInsets(top:44,left:116,bottom:24,right:116))
        XCTAssertTrue(vm.selectTarget(key:"_1"))
        _ = try await awaitShotAim(vm)
        vm.requestPlayerView(.thirdPerson); settle(rig)
        let baseline=try XCTUnwrap(rig.twoViewSnapshot).pose
        vm.beginCameraObservation()
        rig.handleVerticalSwipe(delta:-100); settle(rig)
        let held=try XCTUnwrap(rig.twoViewSnapshot).pose
        XCTAssertGreaterThan(simd_length(held.eye-baseline.eye),0.01)
        vm.endCameraObservation(); settle(rig)
        let released=try XCTUnwrap(rig.twoViewSnapshot).pose
        XCTAssertEqual(released.eye,held.eye)
        XCTAssertEqual(released.orientation.vector,held.orientation.vector)
        vm.requestPlayerView(.thirdPerson); settle(rig)
        XCTAssertLessThan(simd_length(try XCTUnwrap(rig.twoViewSnapshot).pose.eye-baseline.eye),0.001)
    }

    @MainActor
    func testShotNearShortRailProtectsRenderedBallSilhouettesFromTableGeometry() async throws {
        let vm=PositionPlayViewModel(); vm.setupScene()
        func normalized(_ x: Float,_ z: Float) -> CanvasPoint {
            let p=AngleSceneCalculator.sceneToNormalized(position:SCNVector3(x,0,z))
            return CanvasPoint(x:Double(p.x),y:Double(p.y))
        }
        vm.loadBoard(BoardSnapshot(onTable:[PositionPlayBall.cueKey:normalized(-1.229,-0.4),
                                           "_1":normalized(-0.4,-0.03)]))
        defer { vm.cancelDailyAttempt() }
        vm.cameraMode = .perspective3D; vm.enablePlayerCameraControls()
        let rig=try XCTUnwrap(vm.scene.cameraRig)
        rig.usesTwoViewCameraControls=true; rig.viewportSize=CGSize(width:874,height:402)
        rig.setTwoViewReadableInsets(UIEdgeInsets(top:44,left:130,bottom:0,right:130))
        XCTAssertTrue(vm.selectTarget(key:"_1")); vm.selectPocket(at:3)
        _ = try await awaitShotAim(vm)
        vm.requestPlayerView(.thirdPerson); settle(rig)
        let rail=try XCTUnwrap(rig.twoViewSnapshot?.shotProfile)
        let clear=try XCTUnwrap(rig.twoViewTableSightlinesClear)
        for offset: Float in [-0.2,0.2] {
            let p=rail.pose(yaw:rail.defaultYaw+offset,progress:0.5)
            XCTAssertNotNil(rail.legalPose(yaw:rail.defaultYaw+offset,progress:0.5),
                            "Visibility correction must retain useful lateral observation: offset=\(offset) eye=\(p.eye) forward=\(p.forward) fov=\(p.fov) default=\(rail.defaultPose.eye) contains=\(rail.containsSubjects(in:p))")
        }
        let balls=try [vm.scene.cueBallNode,vm.scene.allBallNodes["_1"]].map {
            let p=try XCTUnwrap($0).position; return SIMD3(p.x,p.y,p.z)
        }
        for i in 0...20 {
            let pose=rail.pose(yaw:rail.defaultYaw,progress:Float(i)/40)
            XCTAssertTrue(clear(pose.eye,TwoViewCamera.ballSilhouettes(eye:pose.eye,centers:balls)),
                          "Actual table blocks the ball outline at near progress \(Float(i)/40)")
        }
    }

    func testSharedLegacyHostDoesNotAcquireCandidateStateOrAdaptivePitch() {
        let node = SCNNode(); node.camera = SCNCamera()
        let rig = CameraRig(cameraNode: node, tableSurfaceY: 0.8)
        rig.viewportSize = CGSize(width: 874, height: 402)
        rig.usesRailCameraControls = true
        XCTAssertFalse(rig.usesTwoViewCameraControls)
        XCTAssertTrue(rig.observeWholeTable(yaw: .pi / 2))
        rig.snapToTarget()
        XCTAssertNil(rig.twoViewSnapshot)
        XCTAssertEqual(node.eulerAngles.x, -45 * .pi / 180, accuracy: 0.00001)
    }

    func testInitialAutomaticShotEntryRebuildsLatestViewportAndHUDBeforeFirstUpdateAndCompletes() throws {
        let node = SCNNode(); node.camera = SCNCamera()
        let rig = CameraRig(cameraNode:node,tableSurfaceY:0.8,config:.dailyClearance)
        rig.usesTwoViewCameraControls = true
        rig.viewportSize = CGSize(width:402,height:874)
        rig.setTwoViewReadableInsets(UIEdgeInsets(top:44,left:24,bottom:24,right:24))
        let cue = SCNVector3(0,0.8+BallPhysics.radius,0), aim = SCNVector3(1,0,0.6)
        XCTAssertTrue(rig.enterPlayerView(.thirdPerson,cue:cue,aim:aim,duration:0.4))
        let initial = try XCTUnwrap(rig.twoViewSnapshot)
        let originalMatrix = node.transform
        var completions = 0
        rig.onPlayerTransitionEnded = { completions += 1 }
        // No-op context / inputs do not discard the pending entry intent.
        rig.setTwoViewViewingContext(initial.context)
        rig.handleHorizontalSwipe(delta:0); rig.handleVerticalSwipe(delta:0); rig.handlePinch(scale:1)
        let latestViewport = CGSize(width:874,height:402)
        let latestInsets = UIEdgeInsets(top:44,left:130,bottom:0,right:130)
        rig.viewportSize = latestViewport
        rig.setTwoViewReadableInsets(latestInsets)
        let latest = try XCTUnwrap(rig.twoViewSnapshot)
        let profile = try XCTUnwrap(latest.shotProfile)
        XCTAssertEqual(profile.railViewport,latestViewport)
        XCTAssertEqual(profile.railInsets,latestInsets)
        XCTAssertTrue(profile.layoutMatchesRail)
        XCTAssertEqual(latest.pose.eye,initial.pose.eye)
        XCTAssertTrue(SCNMatrix4EqualToMatrix4(node.transform,originalMatrix))
        XCTAssertTrue(rig.hasPendingDamping)
        XCTAssertFalse(rig.twoViewOwnerIsManual)
        XCTAssertEqual(completions,0)
        XCTAssertGreaterThan(simd_length(initial.pose.eye-profile.defaultPose.eye),0.1)
        settle(rig)
        XCTAssertFalse(rig.hasPendingDamping)
        XCTAssertLessThan(simd_length(node.simdPosition-profile.defaultPose.eye),0.00001)
        XCTAssertLessThan(simd_length(node.simdOrientation.vector-profile.defaultPose.orientation.vector),0.00001)
        XCTAssertEqual(node.camera!.fieldOfView,CGFloat(profile.defaultPose.fov),accuracy:0.00001)
        XCTAssertEqual(completions,1)
        settle(rig)
        XCTAssertEqual(completions,1)
    }

    func testPendingShotEntryCancellationByContextOrUnusableLayoutReleasesBusyWithoutClaimingArrival() throws {
        for cancelByContext in [true,false] {
            let node = SCNNode(); node.camera = SCNCamera()
            let rig = CameraRig(cameraNode:node,tableSurfaceY:0.8,config:.dailyClearance)
            rig.usesTwoViewCameraControls = true; rig.viewportSize = CGSize(width:874,height:402)
            XCTAssertTrue(rig.enterPlayerView(.thirdPerson,cue:SCNVector3(0,0.8+BallPhysics.radius,0),
                aim:SCNVector3(1,0,0),duration:0.4))
            let actual = try XCTUnwrap(rig.twoViewSnapshot).pose
            var completions = 0
            rig.onPlayerTransitionEnded = { completions += 1 }
            if cancelByContext { rig.setTwoViewViewingContext(UUID()) }
            else { rig.setTwoViewReadableInsets(UIEdgeInsets(top:44,left:600,bottom:0,right:600)) }
            XCTAssertEqual(completions,1)
            XCTAssertFalse(rig.hasPendingDamping)
            XCTAssertEqual(rig.twoViewSnapshot?.pose.eye,actual.eye)
            // A cancelled request cannot spring back when the layout becomes valid later.
            rig.setTwoViewReadableInsets(UIEdgeInsets(top:44,left:116,bottom:24,right:116))
            settle(rig)
            XCTAssertEqual(rig.twoViewSnapshot?.pose.eye,actual.eye)
            XCTAssertEqual(rig.twoViewSnapshot?.pose.orientation.vector,actual.orientation.vector)
            XCTAssertEqual(completions,1)
        }
    }

    func testManualTakeoverOfPendingShotEntryKeepsActualPoseOnLaterLayoutChanges() throws {
        let node = SCNNode(); node.camera = SCNCamera()
        let rig = CameraRig(cameraNode:node,tableSurfaceY:0.8,config:.dailyClearance)
        rig.usesTwoViewCameraControls = true; rig.viewportSize = CGSize(width:874,height:402)
        let cue = SCNVector3(0,0.8+BallPhysics.radius,0), aim = SCNVector3(1,0,0)
        XCTAssertTrue(rig.enterPlayerView(.thirdPerson,cue:cue,aim:aim,duration:0.4))
        var completions = 0
        rig.onPlayerTransitionEnded = { completions += 1 }
        XCTAssertTrue(rig.prepareTemporaryObservation(cue:cue,aim:aim))
        let held = try XCTUnwrap(rig.twoViewSnapshot)
        XCTAssertTrue(held.temporaryObserving)
        XCTAssertTrue(rig.twoViewOwnerIsManual)
        XCTAssertEqual(completions,1)
        rig.viewportSize = CGSize(width:1194,height:834)
        rig.setTwoViewReadableInsets(UIEdgeInsets(top:80,left:180,bottom:80,right:180))
        settle(rig)
        XCTAssertEqual(rig.twoViewSnapshot?.pose.eye,held.pose.eye)
        XCTAssertEqual(rig.twoViewSnapshot?.pose.orientation.vector,held.pose.orientation.vector)
        XCTAssertFalse(rig.hasPendingDamping)
        XCTAssertEqual(completions,1)
    }

    func testRigLayoutChangeWaitsForEffectiveGestureThenReconnectsEachInputFromActualPose() throws {
        // Exercise the facade, not only core revalidation: all three input routes must
        // rebuild the creation domain, while layout and ineffective input do not.
        let originalSize = CGSize(width: 874, height: 402)
        let originalInsets = UIEdgeInsets(top: 44, left: 116, bottom: 24, right: 116)
        let nextSize = CGSize(width: 1194, height: 834)
        let nextInsets = UIEdgeInsets(top: 80, left: 180, bottom: 80, right: 180)
        for gesture in 0..<3 {
            let node = SCNNode(); node.camera = SCNCamera()
            let rig = CameraRig(cameraNode: node, tableSurfaceY: 0.8, config: .dailyClearance)
            rig.usesTwoViewCameraControls = true
            rig.viewportSize = originalSize
            rig.setTwoViewReadableInsets(originalInsets)
            var manualCallbacks = 0
            rig.onManualCameraControl = { manualCallbacks += 1 }
            XCTAssertTrue(rig.enterPlayerView(.thirdPerson, cue: SCNVector3(0.3, 0.828575, 0.2),
                aim: SCNVector3(-1, 0, 0), duration: 0.1))
            settle(rig)
            let original = try XCTUnwrap(rig.twoViewSnapshot)
            let originalProfile = try XCTUnwrap(original.shotProfile)
            let visible = node.simdPosition
            rig.viewportSize = nextSize
            rig.setTwoViewReadableInsets(nextInsets)
            let revalidated = try XCTUnwrap(rig.twoViewSnapshot)
            let revalidatedProfile = try XCTUnwrap(revalidated.shotProfile)
            XCTAssertEqual(revalidated.pose.eye, original.pose.eye)
            XCTAssertEqual(revalidated.pose.orientation.vector, original.pose.orientation.vector)
            XCTAssertEqual(node.simdPosition, visible)
            XCTAssertEqual(revalidatedProfile.viewport, nextSize)
            XCTAssertEqual(revalidatedProfile.railViewport, originalProfile.railViewport)
            XCTAssertEqual(revalidatedProfile.railInsets, originalProfile.railInsets)
            XCTAssertFalse(revalidatedProfile.layoutMatchesRail)
            let revision = rig.twoViewRequestRevision
            rig.handleHorizontalSwipe(delta: 0)
            rig.handleVerticalSwipe(delta: 0)
            rig.handlePinch(scale: 1)
            rig.update(deltaTime: 1 / 60)
            XCTAssertEqual(rig.twoViewRequestRevision, revision)
            XCTAssertEqual(rig.twoViewSnapshot?.shotProfile?.railViewport, originalSize)
            XCTAssertEqual(rig.twoViewSnapshot?.pose.eye, original.pose.eye)
            XCTAssertFalse(rig.twoViewOwnerIsManual)
            XCTAssertEqual(manualCallbacks, 0)
            switch gesture {
            case 0: rig.handleHorizontalSwipe(delta: 40)
            case 1: rig.handleVerticalSwipe(delta: 30)
            default: rig.handlePinch(scale: 1.04)
            }
            let requested = try XCTUnwrap(rig.twoViewSnapshot)
            let requestedProfile = try XCTUnwrap(requested.shotProfile)
            XCTAssertEqual(requestedProfile.railViewport, nextSize)
            XCTAssertEqual(requestedProfile.railInsets, nextInsets)
            XCTAssertTrue(requestedProfile.layoutMatchesRail)
            XCTAssertEqual(requested.pose.eye, original.pose.eye)
            XCTAssertEqual(requested.pose.orientation.vector, original.pose.orientation.vector)
            XCTAssertEqual(node.simdPosition, visible)
            XCTAssertTrue(rig.twoViewOwnerIsManual)
            XCTAssertEqual(manualCallbacks, 1)
            rig.update(deltaTime: 1 / 120)
            XCTAssertLessThan(simd_length(node.simdPosition - visible), 0.03,
                              "First input must reconnect from the actual displayed eye, not snap to the new curve.")
            settle(rig)
            let settled = try XCTUnwrap(rig.twoViewSnapshot)
            XCTAssertFalse(rig.hasPendingDamping)
            XCTAssertEqual(settled.mode, .thirdPerson)
            XCTAssertEqual(settled.owner, .manual)
            XCTAssertGreaterThan(simd_length(settled.pose.eye - original.pose.eye), 0.0001)
            XCTAssertLessThan(simd_length(node.simdPosition - settled.pose.eye), 0.00001)
            XCTAssertTrue([node.simdPosition.x, node.simdPosition.y, node.simdPosition.z].allSatisfy(\.isFinite))
        }
        // Explicit shot entry follows the changed cue/aim; repeated identical entry is stable.
        let node=SCNNode(); node.camera=SCNCamera()
        let rig=CameraRig(cameraNode:node,tableSurfaceY:0.8,config:.dailyClearance)
        rig.usesTwoViewCameraControls=true; rig.viewportSize=originalSize
        rig.setTwoViewReadableInsets(originalInsets)
        XCTAssertTrue(rig.enterPlayerView(.thirdPerson,cue:SCNVector3(0,0.828575,0),
            aim:SCNVector3(1,0,0),duration:0.1)); settle(rig)
        let first=try XCTUnwrap(rig.twoViewSnapshot)
        XCTAssertTrue(rig.enterPlayerView(.thirdPerson,cue:SCNVector3(0,0.828575,0),
            aim:SCNVector3(0,0,1),duration:0.1)); settle(rig)
        let changed=try XCTUnwrap(rig.twoViewSnapshot)
        XCTAssertGreaterThan(simd_length(changed.pose.eye-first.pose.eye),0.1)
        for _ in 0..<3 {
            XCTAssertTrue(rig.enterPlayerView(.thirdPerson,cue:SCNVector3(0,0.828575,0),
                aim:SCNVector3(0,0,1),duration:0.1)); settle(rig)
            let current=try XCTUnwrap(rig.twoViewSnapshot)
            XCTAssertEqual(current.pose.eye,changed.pose.eye)
            XCTAssertEqual(current.pose.orientation.vector,changed.pose.orientation.vector)
            XCTAssertNil(current.thirdPersonMemory)
        }
    }

    func testLimitedMidTransitionResumesFromVisibleEyeWhenLayoutBecomesUsable() throws {
        let rail = try profile()
        let base = TwoViewCamera.Pose.looking(eye: SIMD3(-1.5, 1.1, 0), yaw: .pi, pitch: -0.1, fov: 32)
        let camera = TwoViewCamera(pose: base)
        camera.enterThirdPerson(rail, yaw: 1, duration: 1, progress: 0.6)
        camera.update(deltaTime: 0.25)
        let visible = camera.pose
        XCTAssertGreaterThan(simd_length(visible.eye - rail.pose(yaw: 1, progress: 0.6).eye), 0.01)
        let revision = camera.requestRevision
        camera.revalidateLayout(viewport: CGSize(width: 100, height: 100),
            insets: UIEdgeInsets(top: 40, left: 60, bottom: 40, right: 60))
        XCTAssertEqual(camera.pose.eye, visible.eye)
        XCTAssertGreaterThan(camera.requestRevision, revision)
        XCTAssertTrue(camera.railMotionLimited)
        XCTAssertFalse(camera.hasPendingMotion)
        let heldRevision = camera.requestRevision
        camera.update(deltaTime: 0.1)
        XCTAssertEqual(camera.pose.eye, visible.eye)
        XCTAssertEqual(camera.requestRevision, heldRevision)
        camera.revalidateLayout(viewport: rail.viewport, insets: rail.readableInsets)
        camera.horizontal(delta: -40)
        XCTAssertEqual(camera.pose.eye, visible.eye)
        camera.update(deltaTime: 1 / 120)
        XCTAssertLessThan(simd_length(camera.pose.eye - visible.eye), 0.01)
        XCTAssertTrue(camera.isTransitioning)
        settle(camera)
        XCTAssertTrue(camera.pose.eye.y.isFinite)
        XCTAssertGreaterThan(simd_length(camera.pose.eye - visible.eye), 0.01)
        XCTAssertEqual(camera.owner, .manual)
        XCTAssertFalse(camera.railMotionLimited)
    }

    private func shotProfile(context: UUID, reversed: Bool = false) throws -> TwoViewCamera.ShotRailProfile {
        let sign: Float = reversed ? -1 : 1
        let reference = TwoViewCamera.Pose.looking(eye: SIMD3(-1.65*sign,1.7,0),
            yaw: reversed ? 0 : .pi, pitch: -atan2(0.871425,1.65), fov: 55)
        return try XCTUnwrap(TwoViewCamera.ShotRailProfile.candidate(defaultPose: reference,
            cue: SIMD3(0,0.828575,0), target: SIMD3(0.6*sign,0.828575,0.2),
            pocket: SIMD3(1.312*sign,0.8,0.677),
            pocketMouth: [SIMD3(1.282*sign,0.8,0.657),SIMD3(1.332*sign,0.8,0.697)],
            anchor: SIMD3(0,0.8,0),halfExtents: SIMD2(1.4055,0.7995),
            viewport: CGSize(width:874,height:402),
            insets: UIEdgeInsets(top:44,left:116,bottom:24,right:116),context:context))
    }

    func testShotDefaultKeepsAlongCueEyeLensAndProjectsBothBallEnvelopesAndPocketMouth() throws {
        let rail = try shotProfile(context:UUID()), p=rail.defaultPose
        XCTAssertEqual(p.eye,SIMD3(-1.65,1.7,0)); XCTAssertEqual(p.fov,55)
        XCTAssertGreaterThan(p.forward.x,0)
        XCTAssertEqual(p.forward.z,0,accuracy:0.000001)
        XCTAssertEqual(rail.defaultProgress,0.5)
        XCTAssertEqual(rail.pose(yaw:rail.defaultYaw,progress:0.5).eye,p.eye)
        let rect=CGRect(x:116,y:44,width:642,height:334)
        let radius=BallPhysics.radius
        var points: [SIMD3<Float>] = [SIMD3(1.282,0.8,0.657),SIMD3(1.332,0.8,0.697)]
        for ball in [SIMD3<Float>(0,0.828575,0),SIMD3<Float>(0.6,0.828575,0.2)] {
            for x in [-radius,radius] { for y in [-radius,radius] { for z in [-radius,radius] {
                points.append(ball+SIMD3(x,y,z))
            } } }
        }
        for point in points { XCTAssertTrue(rect.contains(try XCTUnwrap(projected(point,in:p,viewport:rail.viewport)))) }
        let near=rail.pose(yaw:rail.defaultYaw,progress:0)
        XCTAssertLessThan(near.eye.y,p.eye.y)
        XCTAssertLessThanOrEqual(asin(-near.forward.y),asin(-p.forward.y)+0.00001)
        XCTAssertNotNil(rail.legalPose(yaw:rail.defaultYaw,progress:0))
    }

    func testShotObservationReleaseFreezesActualAndExplicitResetCanBeInterrupted() throws {
        let id=UUID(), rail=try shotProfile(context:id)
        let camera=TwoViewCamera(pose:rail.defaultPose)
        camera.setViewingContext(id)
        XCTAssertTrue(camera.enterShotThirdPerson(rail,duration:0.1)); settle(camera)
        XCTAssertTrue(camera.beginTemporaryObservation()); XCTAssertTrue(camera.vertical(delta:-100)); settle(camera)
        let held=camera.pose
        XCTAssertTrue(camera.temporaryObserving)
        XCTAssertLessThan(held.eye.y,rail.defaultPose.eye.y)
        settle(camera); XCTAssertEqual(camera.pose.eye,held.eye)
        camera.endTemporaryObservation(duration:0.8); settle(camera)
        XCTAssertEqual(camera.pose.eye,held.eye)
        XCTAssertEqual(camera.pose.orientation.vector,held.orientation.vector)
        XCTAssertFalse(camera.hasPendingMotion)
        XCTAssertEqual(camera.owner,.manual)
        camera.resetTemporaryObservation(duration:0.8); camera.update(deltaTime:0.2)
        let duringReturn=camera.pose
        XCTAssertTrue(camera.beginTemporaryObservation())
        settle(camera)
        XCTAssertEqual(camera.pose.eye,duringReturn.eye)
        XCTAssertEqual(camera.pose.orientation.vector,duringReturn.orientation.vector)
        camera.endTemporaryObservation(duration:0.1); settle(camera)
        XCTAssertEqual(camera.pose.eye,duringReturn.eye)
        camera.resetTemporaryObservation(duration:0.1); settle(camera)
        XCTAssertEqual(camera.pose.eye,rail.defaultPose.eye)
        XCTAssertEqual(camera.pose.orientation.vector,rail.defaultPose.orientation.vector)
        XCTAssertFalse(camera.temporaryObserving)
    }

    func testShotContextChangeCancelsOldReturnAndRebaseHoldsUntilExplicitEntry() throws {
        let first=UUID(), second=UUID(), rail=try shotProfile(context:first)
        let camera=TwoViewCamera(pose:rail.defaultPose)
        camera.setViewingContext(first); XCTAssertTrue(camera.enterShotThirdPerson(rail,duration:0.1)); settle(camera)
        XCTAssertTrue(camera.vertical(delta:-100)); settle(camera)
        camera.resetTemporaryObservation(); camera.update(deltaTime:0.1)
        let actual=camera.pose
        camera.setViewingContext(second); settle(camera)
        XCTAssertEqual(camera.pose.eye,actual.eye)
        XCTAssertFalse(camera.vertical(delta:-10))
        let replacement=try shotProfile(context:second,reversed:true)
        XCTAssertTrue(camera.rebaseShotThirdPersonPreservingPose(replacement))
        XCTAssertEqual(camera.pose.eye,actual.eye)
        settle(camera)
        XCTAssertEqual(camera.pose.eye,actual.eye)
        XCTAssertTrue(camera.enterShotThirdPerson(replacement,duration:0.1)); settle(camera)
        XCTAssertEqual(camera.pose.eye,replacement.defaultPose.eye)
        XCTAssertNil(camera.snapshot().thirdPersonMemory)
    }

    func testShotLayoutChangeCannotRelabelOldCurveOrFinishOldReturn() throws {
        let id=UUID(), rail=try shotProfile(context:id)
        let camera=TwoViewCamera(pose:rail.defaultPose)
        camera.setViewingContext(id); XCTAssertTrue(camera.enterShotThirdPerson(rail,duration:0.1)); settle(camera)
        camera.resetTemporaryObservation(); camera.update(deltaTime:0.1)
        let actual=camera.pose
        camera.revalidateLayout(viewport:CGSize(width:402,height:874),insets:.zero)
        XCTAssertFalse(try XCTUnwrap(camera.shotProfile).layoutMatchesRail)
        XCTAssertFalse(camera.horizontal(delta:20)); camera.endTemporaryObservation(); settle(camera)
        XCTAssertEqual(camera.pose.eye,actual.eye)
    }

    func testThirdPersonReleaseStopsOutstandingInputAndNextAxisKeepsExactProgress() throws {
        let id=UUID(), rail=try shotProfile(context:id)
        let camera=TwoViewCamera(pose:rail.defaultPose)
        camera.setViewingContext(id)
        XCTAssertTrue(camera.enterShotThirdPerson(rail,duration:0.1)); settle(camera)
        XCTAssertTrue(camera.vertical(delta:-107))
        camera.update(deltaTime:1/60)
        let released=camera.pose, progress=camera.progress
        camera.endTemporaryObservation(); settle(camera)
        XCTAssertEqual(camera.pose.eye,released.eye)
        XCTAssertEqual(camera.pose.orientation.vector,released.orientation.vector)
        XCTAssertFalse(camera.hasPendingMotion)
        XCTAssertTrue(camera.rebaseShotThirdPersonPreservingPose(rail))
        XCTAssertTrue(camera.beginTemporaryObservation()); settle(camera)
        XCTAssertEqual(camera.progress,progress)
        XCTAssertEqual(camera.pose.eye,released.eye)
        XCTAssertTrue(camera.horizontal(delta:20)); settle(camera)
        XCTAssertEqual(camera.progress,progress)
        let turned=camera.pose
        camera.endTemporaryObservation(); settle(camera)
        XCTAssertEqual(camera.pose.eye,turned.eye)
        XCTAssertEqual(camera.pose.orientation.vector,turned.orientation.vector)
        XCTAssertGreaterThan(simd_length(turned.eye-released.eye),0.001)
    }

    func testShotRightDragMovesForwardReferenceToScreenRightInBothTableDirections() throws {
        for reversed in [false,true] {
            let id=UUID(), rail=try shotProfile(context:id,reversed:reversed)
            let camera=TwoViewCamera(pose:rail.defaultPose)
            camera.setViewingContext(id)
            XCTAssertTrue(camera.enterShotThirdPerson(rail,duration:0.1)); settle(camera)
            let target=SIMD3<Float>(reversed ? -0.6 : 0.6,0.828575,0.2)
            let before=try XCTUnwrap(projected(target,in:camera.pose,viewport:rail.viewport))
            XCTAssertTrue(camera.horizontal(delta:40)); settle(camera)
            let after=try XCTUnwrap(projected(target,in:camera.pose,viewport:rail.viewport))
            XCTAssertGreaterThan(after.x,before.x)
        }
    }

    func testLandscapeDefaultUsesLowerCueAnchorWhenShotEnvelopeAllowsIt() throws {
        let rail=try shotProfile(context:UUID())
        let p=try XCTUnwrap(projected(SIMD3(0,0.828575,0),in:rail.defaultPose,viewport:rail.viewport))
        let fraction=(p.y-rail.readableInsets.top)/(rail.viewport.height-rail.readableInsets.top-rail.readableInsets.bottom)
        XCTAssertEqual(fraction,0.70,accuracy:0.02)
        XCTAssertEqual(p.x,rail.viewport.width/2,accuracy:0.1)
        XCTAssertTrue(rail.containsSubjects(in:rail.defaultPose))
    }


    private func clippedClothFraction(pose: TwoViewCamera.Pose, viewport: CGSize, insets: UIEdgeInsets) throws -> CGFloat {
        let rect=CGRect(x:insets.left,y:insets.top,width:viewport.width-insets.left-insets.right,
                        height:viewport.height-insets.top-insets.bottom)
        let corners=[SIMD3<Float>(-1.27,0.8,-0.635),SIMD3<Float>(1.27,0.8,-0.635),
                     SIMD3<Float>(1.27,0.8,0.635),SIMD3<Float>(-1.27,0.8,0.635)]
        var polygon=try corners.map { try XCTUnwrap(projected($0,in:pose,viewport:viewport)) }
        for edge in 0..<4 {
            let boundary=[rect.minX,rect.maxX,rect.minY,rect.maxY][edge]
            func coordinate(_ p:CGPoint)->CGFloat { edge<2 ? p.x : p.y }
            func inside(_ p:CGPoint)->Bool { edge==0 || edge==2 ? coordinate(p)>=boundary : coordinate(p)<=boundary }
            var result:[CGPoint]=[]
            guard !polygon.isEmpty else { return 0 }
            for i in polygon.indices {
                let a=polygon[i],b=polygon[(i+1)%polygon.count]
                if inside(a) { result.append(a) }
                if inside(a) != inside(b) {
                    let t=(boundary-coordinate(a))/(coordinate(b)-coordinate(a))
                    result.append(CGPoint(x:a.x+(b.x-a.x)*t,y:a.y+(b.y-a.y)*t))
                }
            }
            polygon=result
        }
        guard polygon.count>=3 else { return 0 }
        let doubled=polygon.indices.reduce(CGFloat(0)) { sum,i in
            let a=polygon[i],b=polygon[(i+1)%polygon.count]; return sum+a.x*b.y-a.y*b.x
        }
        return abs(doubled)/(2*rect.width*rect.height)
    }

    func testShotFarRetainsBaselineSubjectScaleAndClippedClothAreaWithDistinctShotExtents() throws {
        let rail=try shotProfile(context:UUID()), base=rail.defaultPose
        let far=try XCTUnwrap(rail.legalPose(yaw:rail.defaultYaw,progress:1))
        XCTAssertTrue(rail.hasRetreatRoom(yaw:rail.defaultYaw))
        // The candidate admits equality at its 0.10m retreat / 0.05m eye-rise boundaries.
        XCTAssertGreaterThanOrEqual(rail.farRadius(yaw:rail.defaultYaw),hypot(base.eye.x,base.eye.z)+0.10)
        XCTAssertGreaterThanOrEqual(far.eye.y,base.eye.y+0.05)
        XCTAssertGreaterThan(asin(-far.forward.y),asin(-base.forward.y)+0.02)
        let baselineArea=try clippedClothFraction(pose:base,viewport:rail.viewport,insets:rail.readableInsets)
        let farArea=try clippedClothFraction(pose:far,viewport:rail.viewport,insets:rail.readableInsets)
        XCTAssertGreaterThanOrEqual(farArea+0.00001,max(baselineArea*0.8,min(baselineArea,0.35)))
        let focal=Float(rail.viewport.height)/(2*tan(base.fov * .pi/360)),r=BallPhysics.radius
        func pixels(_ p:TwoViewCamera.Pose)->Float {
            [SIMD3<Float>(0,0.828575,0),SIMD3<Float>(0.6,0.828575,0.2)]
                .map { 2*r*focal/(simd_dot($0-p.eye,p.forward)+r) }.min()!
        }
        XCTAssertGreaterThanOrEqual(pixels(far)+0.00001,pixels(base)*0.8)
        let other=try XCTUnwrap(TwoViewCamera.ShotRailProfile.candidate(
            defaultPose:.looking(eye:SIMD3(-1.05,1.7,0),yaw:.pi,pitch:-atan2(0.871425,1.65),fov:55),
            cue:SIMD3(0.6,0.828575,0),target:SIMD3(1,0.828575,0.2),pocket:SIMD3(1.312,0.8,0.677),
            anchor:SIMD3(0,0.8,0),halfExtents:SIMD2(1.4055,0.7995),viewport:rail.viewport,
            insets:rail.readableInsets,context:UUID()))
        XCTAssertTrue(other.hasRetreatRoom(yaw:other.defaultYaw))
        XCTAssertGreaterThan(abs(other.farRadius(yaw:other.defaultYaw)-rail.farRadius(yaw:rail.defaultYaw)),0.05)
    }

    func testTemporaryTopDownCanonicalOppositeOrientationsMaxFitAndAmbiguousOrientationMemory() throws {
        let cases: [(CGSize, UIEdgeInsets)] = [
            (CGSize(width:874,height:402), UIEdgeInsets(top:44,left:116,bottom:24,right:116)),
            (CGSize(width:402,height:874), UIEdgeInsets(top:116,left:24,bottom:116,right:44))
        ]
        let halfLength: Float = 1.4055, halfWidth: Float = 0.7995
        for (viewport,insets) in cases {
            let landscape = viewport.width >= viewport.height
            var directions: [SIMD3<Float>] = []
            let yaws: [Float] = landscape ? [.pi/2,-.pi/2] : [0,.pi]
            for yaw in yaws {
                let reference = TwoViewCamera.Pose.looking(eye:SIMD3(3*cos(yaw),1.7,3*sin(yaw)),
                    yaw:yaw,pitch:-0.5,fov:40)
                let frame = try XCTUnwrap(CameraRig.temporaryTopDownFrame(referencePose:reference,
                    viewport:viewport,insets:insets,halfLength:halfLength,halfWidth:halfWidth))
                directions.append(frame.up)
                XCTAssertEqual(frame.up.y,0)
                XCTAssertEqual(landscape ? abs(frame.up.z) : abs(frame.up.x),1)
                XCTAssertEqual(landscape ? frame.up.x : frame.up.z,0)
                let right = SIMD3<Float>(-frame.up.z,0,frame.up.x)
                let metresPerPixel = Float(2*frame.scale/viewport.height)
                let fitRect = frame.readableRect.insetBy(dx:4,dy:4)
                var minX = CGFloat.infinity, maxX = -CGFloat.infinity
                var minY = CGFloat.infinity, maxY = -CGFloat.infinity
                for x in [-halfLength,halfLength] { for z in [-halfWidth,halfWidth] {
                    let offset = SIMD3(x,0.8,z)-frame.center
                    let screen = CGPoint(x:viewport.width/2+CGFloat(simd_dot(offset,right)/metresPerPixel),
                        y:viewport.height/2-CGFloat(simd_dot(offset,frame.up)/metresPerPixel))
                    XCTAssertGreaterThanOrEqual(screen.x,fitRect.minX-0.001)
                    XCTAssertLessThanOrEqual(screen.x,fitRect.maxX+0.001)
                    XCTAssertGreaterThanOrEqual(screen.y,fitRect.minY-0.001)
                    XCTAssertLessThanOrEqual(screen.y,fitRect.maxY+0.001)
                    minX = min(minX,screen.x); maxX = max(maxX,screen.x)
                    minY = min(minY,screen.y); maxY = max(maxY,screen.y)
                } }
                // At least one dimension saturates the available canonical fit, not an arbitrary diagonal envelope.
                let unusedWidth = fitRect.width-(maxX-minX), unusedHeight = fitRect.height-(maxY-minY)
                XCTAssertLessThan(min(abs(unusedWidth),abs(unusedHeight)),0.001)
                XCTAssertEqual(frame.eye-frame.target,SIMD3(0,5,0))
            }
            XCTAssertLessThan(simd_length(directions[0]+directions[1]),0.000001)
        }
        let endOn = TwoViewCamera.Pose.looking(eye:SIMD3(3,0.8,0),yaw:0,pitch:0,fov:40)
        let remembered = SIMD3<Float>(0,0,1)
        let stable = try XCTUnwrap(CameraRig.temporaryTopDownFrame(referencePose:endOn,
            viewport:cases[0].0,insets:cases[0].1,halfLength:halfLength,halfWidth:halfWidth,previousUp:remembered))
        XCTAssertEqual(stable.up,remembered)
        XCTAssertNil(CameraRig.temporaryTopDownFrame(referencePose:endOn,viewport:.zero,
            insets:.zero,halfLength:halfLength,halfWidth:halfWidth))
    }

    func testTemporaryTopDownHoldLayoutAndReleaseDoNotWriteMainPerspectiveCamera() throws {
        let node = SCNNode(); node.camera = SCNCamera()
        let rig = CameraRig(cameraNode:node,tableSurfaceY:0.8,config:.dailyClearance)
        rig.usesTwoViewCameraControls = true
        rig.viewportSize = CGSize(width:874,height:402)
        rig.setTwoViewReadableInsets(UIEdgeInsets(top:44,left:116,bottom:24,right:116))
        // Holding before core creation must also suppress the legacy update path's camera writes.
        node.position = SCNVector3(0,1.7,3)
        let uninitializedMatrix = node.transform
        XCTAssertTrue(rig.beginTemporaryTopDown(aim:SCNVector3(1,0,0)))
        rig.update(deltaTime:1/60)
        XCTAssertTrue(SCNMatrix4EqualToMatrix4(node.transform,uninitializedMatrix))
        rig.endTemporaryTopDown()
        XCTAssertTrue(rig.enterPlayerView(.thirdPerson,cue:SCNVector3(0,0.828575,0),
            aim:SCNVector3(1,0,0),duration:0.1)); settle(rig)
        let before = try XCTUnwrap(rig.twoViewSnapshot)
        let matrix = node.transform, lens = try XCTUnwrap(node.camera).fieldOfView
        let scale = node.camera!.orthographicScale
        XCTAssertTrue(rig.beginTemporaryTopDown(aim:SCNVector3(1,0,1)))
        XCTAssertNotNil(rig.temporaryTopDownOverlayFrame)
        XCTAssertEqual(rig.temporaryTopDownReferenceSource,"TP actual")
        for _ in 0..<30 { rig.update(deltaTime:1/60) }
        rig.viewportSize = CGSize(width:402,height:874)
        rig.setTwoViewReadableInsets(UIEdgeInsets(top:116,left:24,bottom:116,right:44))
        rig.update(deltaTime:1/60)
        let overlay = try XCTUnwrap(rig.temporaryTopDownOverlayFrame)
        XCTAssertEqual(abs(overlay.up.x),1)
        XCTAssertTrue(SCNMatrix4EqualToMatrix4(node.transform,matrix))
        XCTAssertEqual(node.camera!.fieldOfView,lens)
        XCTAssertEqual(node.camera!.orthographicScale,scale)
        XCTAssertFalse(node.camera!.usesOrthographicProjection)
        XCTAssertEqual(rig.twoViewSnapshot?.pose.eye,before.pose.eye)
        rig.endTemporaryTopDown()
        XCTAssertNil(rig.temporaryTopDownOverlayFrame)
        XCTAssertTrue(SCNMatrix4EqualToMatrix4(node.transform,matrix))
        XCTAssertEqual(node.camera!.fieldOfView,lens)
        XCTAssertFalse(node.camera!.usesOrthographicProjection)
    }

    func testFirstPersonTopDownUsesThisShotsThirdPersonReferenceRatherThanTemporaryHeadYaw() throws {
        let node = SCNNode(); node.camera = SCNCamera()
        let rig = CameraRig(cameraNode:node,tableSurfaceY:0.8,config:.dailyClearance)
        rig.usesTwoViewCameraControls = true; rig.viewportSize = CGSize(width:874,height:402)
        // This camera-only fixture has no table subtree. Supply its empty-scene sightline contract;
        // the real host supplies mesh ray queries and is covered by the screenshot/scene validation.
        rig.twoViewTableSightlinesClear = { _, _ in true }
        rig.setTwoViewReadableInsets(UIEdgeInsets(top:44,left:116,bottom:24,right:116))
        let cue = SCNVector3(0,0.8+BallPhysics.radius,0), aim = SCNVector3(1,0,0.6)
        XCTAssertTrue(rig.enterPlayerView(.thirdPerson,cue:cue,aim:aim,duration:0.1)); settle(rig)
        let reference = try XCTUnwrap(rig.twoViewSnapshot?.shotProfile).defaultPose
        let expected = try XCTUnwrap(CameraRig.temporaryTopDownFrame(referencePose:reference,
            viewport:rig.viewportSize,insets:UIEdgeInsets(top:44,left:116,bottom:24,right:116),
            halfLength:1.4055,halfWidth:0.7995))
        XCTAssertTrue(rig.enterPlayerView(.firstPerson,cue:cue,aim:aim,duration:0.1)); settle(rig)
        XCTAssertEqual(rig.twoViewMode,.firstPerson)
        XCTAssertTrue(rig.prepareTemporaryObservation(cue:cue,aim:aim))
        rig.handleHorizontalSwipe(delta:-300); settle(rig)
        let before = node.transform
        XCTAssertTrue(rig.beginTemporaryTopDown(aim:aim))
        XCTAssertEqual(rig.temporaryTopDownReferenceSource,"shot TP default")
        XCTAssertEqual(TwoViewCamera.angleDelta(atan2(-reference.forward.z,-reference.forward.x),
            rig.temporaryTopDownReferenceYaw),0,accuracy:0.00001)
        XCTAssertEqual(try XCTUnwrap(rig.temporaryTopDownOverlayFrame).up,expected.up)
        XCTAssertTrue(SCNMatrix4EqualToMatrix4(node.transform,before))
        rig.endTemporaryTopDown()
        XCTAssertTrue(SCNMatrix4EqualToMatrix4(node.transform,before))
    }

    func testDailyAlongCueEntryReusesNearRailAndShortShotSetbackWithoutOffAxisYawOrFixedWideLens() throws {
        let y: Float = 0.8+BallPhysics.radius
        let layouts = [CGSize(width:874,height:402),CGSize(width:1194,height:834)]
        let samples: [(SCNVector3,SCNVector3,Float,Float)] = [
            (SCNVector3(0,y,0),SCNVector3(0.8,y,0),1.65,1.65),
            (SCNVector3(0,y,0),SCNVector3(0.06,y,0),0.90,1.10),
            (SCNVector3(-1.23,y,0),SCNVector3(0.6,y,0),1.04,1.07)
        ]
        var longShotLenses: [Float] = []
        for viewport in layouts {
            for (cue,target,minimum,maximum) in samples {
                let pose = try XCTUnwrap(CameraRig.dailyPlayerPose(view:.thirdPerson,cue:cue,strike:cue,
                    aim:SCNVector3(1,0,0),elevation:0.05,surfaceY:0.8,viewport:viewport,
                    context:[cue,target],fitsObservationContext:false,centersCueAxis:true))
                let eye = SIMD3<Float>(pose.pivot.x+cos(pose.yaw)*pose.radius,0.8+pose.height,
                    pose.pivot.z+sin(pose.yaw)*pose.radius)
                let setback = cue.x-eye.x
                XCTAssertGreaterThanOrEqual(setback,minimum-0.00001)
                XCTAssertLessThanOrEqual(setback,maximum+0.00001)
                XCTAssertEqual(eye.y,1.70,accuracy:0.00001)
                XCTAssertEqual(eye.z,cue.z,accuracy:0.00001)
                XCTAssertEqual(TwoViewCamera.angleDelta(.pi,pose.yaw),0,accuracy:0.00001)
                XCTAssertLessThan(pose.fov,55)
                if minimum == 1.65 { longShotLenses.append(pose.fov) }
            }
        }
        XCTAssertGreaterThan(abs(longShotLenses[0]-longShotLenses[1]),5)
    }

    func testShotRigUsesAdaptiveAlongCueEyeAndLensAndPocketRemainsInsideActualHUD() throws {
        let viewport = CGSize(width:874,height:402)
        let insets = UIEdgeInsets(top:44,left:116,bottom:24,right:116)
        let cue = SCNVector3(0,0.8+BallPhysics.radius,0), target = SCNVector3(0.06,cue.y,0)
        let pocket = AngleSceneCalculator.pocketMarkerPositions(surfaceY:0.8)[1]
        let physicalHole = AngleSceneCalculator.pocketPositions(surfaceY:0.8)[1]
        let jaws = AngleSceneCalculator.pocketJaws(surfaceY:0.8+BTTablePhysics.cushionHeight)[1]
        let dropRadius = AngleSceneCalculator.pocketDropRadius(index:1)
        var mouth = [jaws.0,jaws.1]
        for i in 0..<16 {
            let angle = Float(i)*Float.pi/8
            mouth.append(physicalHole+SCNVector3(cos(angle)*dropRadius,0,sin(angle)*dropRadius))
        }
        let reference = try XCTUnwrap(CameraRig.dailyPlayerPose(view:.thirdPerson,cue:cue,strike:cue,
            aim:SCNVector3(1,0,0),elevation:0.05,surfaceY:0.8,viewport:viewport,
            context:[cue,target],fitsObservationContext:false,pocket:pocket,
            pocketRadius:AngleSceneCalculator.pocketMarkerRadius(index:1),pocketMouth:mouth,centersCueAxis:true))
        let node = SCNNode(); node.camera = SCNCamera()
        let rig = CameraRig(cameraNode:node,tableSurfaceY:0.8,config:.dailyClearance)
        rig.usesTwoViewCameraControls = true; rig.viewportSize = viewport
        rig.setTwoViewReadableInsets(insets)
        rig.observationCandidates = [cue,target]; rig.observationPocket = (1,pocket)
        XCTAssertTrue(rig.enterPlayerView(.thirdPerson,cue:cue,aim:SCNVector3(1,0,0),duration:0.1)); settle(rig)
        let rail = try XCTUnwrap(rig.twoViewSnapshot?.shotProfile)
        XCTAssertLessThan(cue.x-rail.defaultPose.eye.x,1.10)
        XCTAssertEqual(rail.defaultPose.eye.y,1.70,accuracy:0.00001)
        XCTAssertEqual(rail.defaultPose.fov,reference.fov,accuracy:0.00001)
        XCTAssertLessThan(rail.defaultPose.fov,55)
        XCTAssertEqual(TwoViewCamera.angleDelta(.pi,atan2(-rail.defaultPose.forward.z,-rail.defaultPose.forward.x)),0,accuracy:0.00001)
        let rect = CGRect(x:insets.left,y:insets.top,width:viewport.width-insets.left-insets.right,
            height:viewport.height-insets.top-insets.bottom)
        for point in [cue,target,pocket] {
            XCTAssertTrue(rect.contains(try XCTUnwrap(projected(SIMD3(point.x,point.y,point.z),in:rail.defaultPose,viewport:viewport))))
        }
    }

    func testNativeSelectionAndFourFormationDefaultsHaveActualRetreatInsteadOfProgressOnly() throws {
        // Inputs captured from the failed native UI round, with the owning calculator's physical mouth.
        // This is a regression set, not a full-domain visibility or mesh certificate.
        let cases: [(String,SIMD3<Float>,Float,Float,SIMD2<Float>,SIMD2<Float>)] = [
            ("selection",SIMD3(-2.1552453,1.7,-0.20521179),-3.094148,0.48612761,SIMD2(-0.508,-0.127),SIMD2(0,-0.0762)),
            ("long-table",SIMD3(-2.5917153,1.7,-0.91477704),-2.7847373,0.48706296,SIMD2(-1.05,-0.34),SIMD2(0.8,0.36)),
            ("near-short",SIMD3(-2.7294912,1.7,-1.0751146),-2.7187977,0.48706314,SIMD2(-1.229,-0.40),SIMD2(-0.4,-0.03)),
            ("near-long",SIMD3(-1.5007739,1.7,-1.767999),-2.3453536,0.48706287,SIMD2(-0.35,-0.592),SIMD2(0.45,0.2)),
            ("large-cut",SIMD3(-2.8428545,1.7,-0.66101587),-3.0862482,0.48706293,SIMD2(-1.2,-0.57),SIMD2(1.2,-0.38))
        ]
        let hole=AngleSceneCalculator.pocketPositions(surfaceY:0.8)[3]
        let marker=AngleSceneCalculator.pocketMarkerPositions(surfaceY:0.8)[3]
        let jaws=AngleSceneCalculator.pocketJaws(surfaceY:0.8+BTTablePhysics.cushionHeight)[3]
        var mouth=[SIMD3<Float>(jaws.0.x,jaws.0.y,jaws.0.z),SIMD3<Float>(jaws.1.x,jaws.1.y,jaws.1.z)]
        for i in 0..<16 {
            let angle=Float(i)*Float.pi/8,radius=AngleSceneCalculator.pocketDropRadius(index:3)
            mouth.append(SIMD3(hole.x+cos(angle)*radius,hole.y,hole.z+sin(angle)*radius))
        }
        for (name,eye,heading,pitch,cueXZ,targetXZ) in cases {
            let id=UUID()
            let rail=try XCTUnwrap(TwoViewCamera.ShotRailProfile.candidate(
                defaultPose:.looking(eye:eye,yaw:heading,pitch:-pitch,fov:55),
                cue:SIMD3(cueXZ.x,0.8+BallPhysics.radius,cueXZ.y),
                target:SIMD3(targetXZ.x,0.8+BallPhysics.radius,targetXZ.y),
                pocket:SIMD3(marker.x,marker.y,marker.z),pocketMouth:mouth,
                anchor:SIMD3(0,0.8,0),halfExtents:SIMD2(1.4055,0.7995),
                viewport:CGSize(width:874,height:402),insets:UIEdgeInsets(top:44,left:130,bottom:0,right:130),context:id),name)
            XCTAssertTrue(rail.hasRetreatRoom(yaw:rail.defaultYaw),name)
            let far=try XCTUnwrap(rail.legalPose(yaw:rail.defaultYaw,progress:1),name)
            XCTAssertGreaterThan(hypot(far.eye.x-eye.x,far.eye.z-eye.z),0.09,name)
            XCTAssertGreaterThan(far.eye.y,eye.y+0.045,name)
            XCTAssertGreaterThan(asin(-far.forward.y),asin(-rail.defaultPose.forward.y)+0.02,name)
            let gaze=atan2(-far.forward.z,-far.forward.x)
            XCTAssertLessThanOrEqual(abs(TwoViewCamera.angleDelta(heading,gaze)),15 * .pi/180+0.0001,name)
            XCTAssertEqual(TwoViewCamera.angleDelta(rail.defaultYaw,atan2(far.eye.z,far.eye.x)),0,accuracy:0.00001,name)
            let camera=TwoViewCamera(pose:rail.defaultPose)
            camera.setViewingContext(id); XCTAssertTrue(camera.enterShotThirdPerson(rail,duration:0.1)); settle(camera)
            XCTAssertTrue(camera.vertical(delta:212)); settle(camera)
            XCTAssertGreaterThan(hypot(camera.pose.eye.x-eye.x,camera.pose.eye.z-eye.z),0.01,name)
            XCTAssertFalse(camera.railMotionLimited,name)
        }
    }


}

final class SimpleCueCameraTests: XCTestCase {
    private let viewport = CGSize(width: 874,height: 402)
    private func shot(distance: Float = 1.65, angle: Float = 0) -> TwoViewCamera.SimpleShot {
        let cue = SIMD3<Float>(0.3,0.8+BallPhysics.radius,-0.1)
        return .init(cue:cue,strike:cue,aim:SIMD3(cos(angle),0,sin(angle)),
                     surfaceY:0.8,viewport:viewport,distance:distance)
    }
    func testFixedCurveProjectionAndMonotonicPostureAcrossAllHeadings() {
        for angle in stride(from: -Float.pi, through: Float.pi, by: Float(0.17)) {
            var lastHeight:Float = 0, lastPitch:Float = -.pi
            for d in stride(from:Float(0.2),through:4,by:0.04) {
                let s=shot(distance:d,angle:angle), p=s.pose
                let local=p.orientation.inverse.act(s.cue-p.eye)
                let tangent: Float = tan(p.fov * Float.pi / 360)
                let y: Float = (1 - local.y / (-local.z * tangent)) / 2
                XCTAssertEqual(local.x,0,accuracy:0.00001)
                XCTAssertEqual(y,0.67,accuracy:0.00001)
                XCTAssertGreaterThan(p.eye.y,lastHeight)
                XCTAssertGreaterThan(asin(-p.forward.y),lastPitch)
                lastHeight=p.eye.y;lastPitch=asin(-p.forward.y)
            }
        }
        XCTAssertEqual(shot().pose.eye.y-0.8,0.65,accuracy:0.00001)
    }
    func testRelativeTravelIsReversibleAndReleaseDoesNotDrift() {
        let s=shot(), c=TwoViewCamera(pose:s.pose)
        c.enterSimpleShot(s,duration:0)
        c.vertical(delta:100)
        XCTAssertEqual(c.simpleShot!.distance,1.65*exp2(200/402),accuracy:0.0001)
        c.endTemporaryObservation()
        let stopped=c.pose
        for _ in 0..<120 { c.update(deltaTime:1/60) }
        XCTAssertEqual(c.pose.transform,stopped.transform)
        c.vertical(delta:-100)
        XCTAssertEqual(c.simpleShot!.distance,1.65,accuracy:0.00001)
    }
    func testManualAimChangesYawButPreservesDistanceHeightPitchAndLens() {
        let s=shot(distance:1.17), c=TwoViewCamera(pose:s.pose)
        c.enterSimpleShot(s,duration:0)
        let p=c.pose
        c.updateSimpleShot(cue:s.cue,strike:s.strike,aim:SIMD3(0,0,1))
        XCTAssertEqual(c.pose.eye.y,p.eye.y)
        XCTAssertEqual(c.pose.forward.y,p.forward.y,accuracy:0.00001)
        XCTAssertEqual(c.pose.fov,p.fov)
        XCTAssertEqual(c.simpleShot?.distance,s.distance)
        let local=c.pose.orientation.inverse.act(s.cue-c.pose.eye)
        XCTAssertEqual(local.x,0,accuracy:0.00001)
        XCTAssertEqual(c.snapshot().simpleShot?.aim,SIMD3(0,0,1))
        let saved=c.snapshot()
        c.enterFirstPerson(p,duration:0.1)
        c.restore(saved)
        XCTAssertEqual(c.pose.transform,saved.pose.transform)
    }
    @MainActor
    func testInterruptedBallFeedbackRestoresEachImportedScale() throws {
        let scene = AngleTrainingScene(); scene.setupScene()
        for node in scene.allBallNodes.values {
            let base = node.simdScale
            TableBallPulse.pulse(node)
            node.simdScale = base * 1.4 // Interrupt at an intermediate feedback scale.
            TableBallPulse.beginDrag(node)
            XCTAssertEqual(node.simdScale, base)
            node.simdScale = base * 1.07
            TableBallPulse.endDrag(node)
            TableBallPulse.restore(node)
            XCTAssertEqual(node.simdScale, base)
            XCTAssertFalse(node.hasActions)
        }
    }
    func testEntryReleaseCompletesWithoutLeavingStaleRailPose() {
        let shot = TwoViewCamera.SimpleShot(cue: SIMD3(0,BallPhysics.radius,0),
            strike: SIMD3(0,BallPhysics.radius,0), aim: SIMD3(1,0,0),
            surfaceY: 0, viewport: CGSize(width:874,height:402))
        let camera = TwoViewCamera(pose: .looking(eye:SIMD3(0,2,3),yaw:0,pitch:-0.5,fov:40))
        camera.enterSimpleShot(shot,duration:0.3)
        camera.update(deltaTime:0.05)
        XCTAssertTrue(camera.vertical(delta:-50))
        camera.endTemporaryObservation()
        camera.update(deltaTime:0.3)
        XCTAssertFalse(camera.isTransitioning)
        XCTAssertEqual(camera.pose.transform,camera.simpleShot!.pose.transform)
        let pose = camera.pose
        camera.update(deltaTime:1)
        XCTAssertEqual(camera.pose.transform,pose.transform)
    }
    @MainActor
    func testActualModelBallScaleDiagnostic() throws {
        let scene=AngleTrainingScene();scene.setupScene()
        for (key,node) in scene.allBallNodes.sorted(by:{$0.key<$1.key}) {
            let bounds=node.boundingSphere
            print("BALL-SCALE ",key,node.scale,bounds.radius)
        }
        XCTAssertNotNil(scene.cueBallNode)
    }
}


final class MergedCameraTests: XCTestCase {
    func testNearEndpointAndRangeReverseWithoutAccumulatedInput() {
        let near = TwoViewCamera.Pose.looking(eye: SIMD3(-0.82,1.12,0), yaw: .pi, pitch: -0.08, fov: 34)
        var shot = TwoViewCamera.SimpleShot(cue: SIMD3(0,0.829,0), strike: SIMD3(0,0.829,0),
            aim: SIMD3(1,0,0), surfaceY: 0.8, viewport: CGSize(width:874,height:402),
            nearPose: near, usesMergedRange: true)
        let baseline = shot.pose
        shot.move(points: -10000)
        XCTAssertEqual(shot.distance,0.9)
        XCTAssertEqual(simd_length(shot.pose.eye-near.eye),0,accuracy:0.000001)
        XCTAssertEqual(shot.pose.fov,near.fov)
        XCTAssertEqual(simd_length(shot.pose.forward-near.forward),0,accuracy:0.000001)
        shot.move(points: 1)
        XCTAssertGreaterThan(shot.distance,0.9)
        shot.move(points: 10000)
        XCTAssertEqual(shot.distance,2)
        shot.move(points: -1)
        XCTAssertLessThan(shot.distance,2)
        shot.distance = 1.65
        XCTAssertEqual(simd_length(shot.pose.eye-baseline.eye),0,accuracy:0.000001)
        var previous = near
        for d in stride(from:Float(0.9),through:2,by:0.002) {
            shot.distance = d
            XCTAssertLessThan(simd_length(shot.pose.eye-previous.eye),0.012)
            XCTAssertLessThan(abs(shot.pose.fov-previous.fov),0.3)
            previous = shot.pose
        }
    }

    @MainActor
    func testOverlayMappingAgreesWithSceneKitProjection() throws {
        let viewport = CGSize(width:874,height:402)
        for yaw: Float in [Float.pi/2,-Float.pi/2] {
            let frame = try XCTUnwrap(CameraRig.temporaryTopDownFrame(referencePose:
                .looking(eye: SIMD3(0,2,3),yaw:yaw,pitch:-0.5,fov:35),viewport:viewport,
                insets:UIEdgeInsets(top:44,left:100,bottom:20,right:120),halfLength:1.4055,halfWidth:0.7995))
            let scene = SCNScene(), camera = SCNNode()
            camera.camera = SCNCamera()
            camera.camera?.usesOrthographicProjection = true
            camera.camera?.projectionDirection = .vertical
            camera.camera?.orthographicScale = frame.orthographicScale
            camera.simdPosition = frame.eye
            camera.look(at:SCNVector3(frame.target.x,frame.target.y,frame.target.z),
                up:SCNVector3(frame.up.x,frame.up.y,frame.up.z),localFront:SCNVector3(0,0,-1))
            scene.rootNode.addChildNode(camera)
            let renderer = SCNRenderer(device:nil,options:nil)
            renderer.scene = scene; renderer.pointOfView = camera
            _ = renderer.snapshot(atTime:0,with:viewport,antialiasingMode:.none)
            for point in [SIMD3<Float>(0,0.829,0),SIMD3(-1,0.829,-0.5),SIMD3(1,0.829,0.5)] {
                let actual = renderer.projectPoint(SCNVector3(point.x,point.y,point.z))
                let mapped = frame.screen(point:point,viewport:viewport)
                XCTAssertEqual(CGFloat(actual.x),mapped.x,accuracy:0.01)
                XCTAssertEqual(viewport.height-CGFloat(actual.y),mapped.y,accuracy:0.01)
            }
        }
    }

    func testMergedNearMatchesExistingFirstPersonEntry() throws {
        for elevation: Float in [0.05,0.4,0.8] {
            func makeRig(merged: Bool) -> (CameraRig, SCNNode) {
                let node = SCNNode(); node.camera = SCNCamera()
                let rig = CameraRig(cameraNode:node,tableSurfaceY:0.8,config:.dailyClearance)
                rig.viewportSize = CGSize(width:874,height:402)
                rig.usesTwoViewCameraControls = true; rig.usesSimpleCueCamera = merged; rig.usesMergedCamera = merged
                rig.twoViewTableSightlinesClear = { _,_ in true }
                rig.setTwoViewReadableInsets(UIEdgeInsets(top:40,left:80,bottom:20,right:120))
                return (rig,node)
            }
            let cue = SCNVector3(0,0.829,0), aim = SCNVector3(1,0,0)
            let (old, oldNode) = makeRig(merged:false), (merged,newNode) = makeRig(merged:true)
            for rig in [old,merged] { rig.updateCuePose(strike:cue,aim:aim,elevation:elevation,cue:cue) }
            XCTAssertTrue(old.enterPlayerView(.firstPerson,cue:cue,aim:aim,duration:0.1))
            for _ in 0..<60 { old.update(deltaTime:1/60) }
            XCTAssertTrue(merged.enterPlayerView(.thirdPerson,cue:cue,aim:aim,duration:0))
            merged.handleVerticalSwipe(delta:-10000)
            merged.update(deltaTime:1/60)
            XCTAssertLessThan(simd_length(oldNode.simdPosition-newNode.simdPosition),0.00001)
            XCTAssertLessThan(1-abs(simd_dot(oldNode.simdOrientation.vector,newNode.simdOrientation.vector)),0.00001)
            XCTAssertEqual(oldNode.camera!.fieldOfView,newNode.camera!.fieldOfView,accuracy:0.001)
        }
    }

    func testOrthographicPickingRoundtripAcrossOppositeOrientations() throws {
        for yaw: Float in [Float.pi/2,-Float.pi/2] {
            let viewport = CGSize(width:874,height:402)
            let frame = try XCTUnwrap(CameraRig.temporaryTopDownFrame(referencePose:
                .looking(eye: SIMD3(0,2,3),yaw:yaw,pitch:-0.5,fov:35),viewport:viewport,
                insets:UIEdgeInsets(top:44,left:100,bottom:20,right:120),halfLength:1.4055,halfWidth:0.7995))
            for x: Float in [-1.2,0,1.2] { for z: Float in [-0.6,0,0.6] {
                let world = SIMD3(x,Float(0.8),z)
                let roundtrip = frame.world(at:frame.screen(point:world,viewport:viewport),viewport:viewport)
                XCTAssertLessThan(simd_length(world-roundtrip),0.000001)
            } }
        }
    }

    func testGlobalOwnershipSurvivesCueUpdatesAndOverlayRoundtrip() throws {
        let node = SCNNode(); node.camera = SCNCamera()
        let rig = CameraRig(cameraNode:node,tableSurfaceY:0.8,config:.dailyClearance)
        rig.usesShotAwareCamera = true; rig.usesRailCameraControls = true
        rig.usesTwoViewCameraControls = true; rig.usesSimpleCueCamera = true; rig.usesMergedCamera = true
        rig.twoViewTableSightlinesClear = { _,_ in true }
        rig.viewportSize = CGSize(width:874,height:402)
        let cue = SCNVector3(0,0.829,0), aim = SCNVector3(1,0,0)
        rig.updateCuePose(strike:cue,aim:aim,elevation:0.05,cue:cue)
        XCTAssertTrue(rig.enterPlayerView(.thirdPerson,cue:cue,aim:aim,duration:0))
        rig.update(deltaTime:1)
        XCTAssertTrue(rig.enterMergedGlobal(aim:aim))
        for _ in 0..<240 { rig.update(deltaTime:1/60) }
        rig.handleHorizontalSwipe(delta:100)
        for _ in 0..<180 { rig.update(deltaTime:1/60) }
        let matrix = node.simdTransform
        rig.updateCuePose(strike:cue,aim:SCNVector3(0,0,1),elevation:0.05,cue:cue)
        XCTAssertEqual(node.simdTransform,matrix)
        XCTAssertTrue(rig.mergedGlobalActive)
        XCTAssertTrue(rig.beginTemporaryTopDown(aim:aim))
        for _ in 0..<10 { rig.update(deltaTime:1/60) }
        rig.endTemporaryTopDown()
        rig.update(deltaTime:1/60)
        XCTAssertEqual(node.simdTransform,matrix)
        XCTAssertTrue(rig.mergedGlobalActive)
        XCTAssertTrue(rig.enterPlayerView(.firstPerson,cue:cue,aim:aim,duration:0))
        XCTAssertFalse(rig.mergedGlobalActive)
        XCTAssertEqual(rig.playerView,.thirdPerson)
    }
}
