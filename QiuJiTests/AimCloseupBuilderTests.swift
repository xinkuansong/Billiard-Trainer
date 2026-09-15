import XCTest
import SceneKit
@testable import QiuJi

/// v23 W3：自由瞄准页特写快照构建（层集 / 多球切换 / 擦身打空）。
///
/// 坐标契约：平面点 = `CGPoint(x: worldX, y: worldZ)`，米。母球置原点、方向 +X，
/// 于是「前方」= x 增大方向，横向偏移写在 y 上。
final class AimCloseupBuilderTests: XCTestCase {

    private let r: CGFloat = 0.028575
    private let cue = CGPoint(x: 0, y: 0)
    private let dir = CGPoint(x: 1, y: 0)
    private let railEnd = CGPoint(x: 1.3, y: 0)

    private func build(
        _ balls: [AimCloseupBuilder.Ball], previouslyNear: Bool = false
    ) -> AimCloseupBuilder.Result {
        AimCloseupBuilder.freeAim(
            cue: cue, direction: dir, balls: balls, ballRadius: r, railEnd: railEnd,
            halfLength: CGFloat(ShotTableLayout.defaultHalfLength),
            halfWidth: CGFloat(ShotTableLayout.defaultHalfWidth),
            previouslyNear: previouslyNear)
    }

    // MARK: - 层集（只画主场景有的层）

    func test_contact_buildsAimLineGhostAndContactDot_noPotOrAuxLine() throws {
        let target = CGPoint(x: 0.6, y: 0)
        let result = build([AimCloseupBuilder.Ball(pos: target, number: 8)])
        let snap = try XCTUnwrap(result.snapshot)

        XCTAssertTrue(result.isNear)
        XCTAssertEqual(snap.band, .contact)
        XCTAssertEqual(snap.focus, target)
        XCTAssertEqual(snap.targetBallNumber, 8)
        XCTAssertFalse(snap.showMissCaption)

        // 正撞 ⇒ 假想球在目标球正后方 2R。
        let ghost = try XCTUnwrap(snap.ghost)
        XCTAssertEqual(hypot(ghost.x - target.x, ghost.y - target.y), 2 * r, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(snap.aimLine).end, ghost,
                       "接触时瞄准线止于假想球，而非库边")

        // 接触点在两球连线上、离两球心各一个半径。
        let contact = try XCTUnwrap(snap.contactMarker)
        XCTAssertEqual(hypot(contact.x - ghost.x, contact.y - ghost.y), r, accuracy: 1e-6)
        XCTAssertEqual(hypot(contact.x - target.x, contact.y - target.y), r, accuracy: 1e-6)

        // 本页场景无进球线/垂线 ⇒ HUD 不得发明。
        XCTAssertNil(snap.potLine)
        XCTAssertNil(snap.auxLine)
        XCTAssertNil(snap.aimPointMarker)
        XCTAssertFalse(snap.ghostShowsAimPoint, "场景的假想球圈不带瞄准点十字")
    }

    // MARK: - 近区判定

    func test_far_yieldsNoSnapshot() {
        // 横向偏 5R ⇒ 出 3R 进入带。
        let result = build([AimCloseupBuilder.Ball(pos: CGPoint(x: 0.6, y: r * 5))])
        XCTAssertNil(result.snapshot)
        XCTAssertFalse(result.isNear)
    }

    func test_skimBand_showsMissCaption_andLineRunsToRail() throws {
        // 垂距 2.5R：在近区（<3R）但已无接触（≥2R）。
        let result = build([AimCloseupBuilder.Ball(pos: CGPoint(x: 0.6, y: r * 2.5))])
        let snap = try XCTUnwrap(result.snapshot)
        XCTAssertEqual(snap.band, .skim)
        XCTAssertTrue(snap.showMissCaption)
        XCTAssertNil(snap.ghost)
        XCTAssertNil(snap.contactMarker)
        XCTAssertEqual(try XCTUnwrap(snap.aimLine).end, railEnd)
    }

    func test_ballBehindCue_neverFramed() {
        let result = build([AimCloseupBuilder.Ball(pos: CGPoint(x: -0.4, y: 0))])
        XCTAssertNil(result.snapshot)
    }

    func test_hysteresis_keepsNearBetweenEnterAndExit() throws {
        // 3.2R：> enter(3R) 但 < exit(3.5R) ⇒ 仅在「上一帧已近」时保持。
        let ball = AimCloseupBuilder.Ball(pos: CGPoint(x: 0.6, y: r * 3.2))
        XCTAssertNil(build([ball], previouslyNear: false).snapshot)
        XCTAssertNotNil(build([ball], previouslyNear: true).snapshot)
    }

    // MARK: - 多球（E1：锁首碰，不叠 HUD）

    func test_multiBall_framesFirstContact_notTheFartherOneOnSameLine() throws {
        let near = CGPoint(x: 0.5, y: 0)
        let far = CGPoint(x: 0.9, y: 0)
        let snap = try XCTUnwrap(build([
            AimCloseupBuilder.Ball(pos: far, number: 3),
            AimCloseupBuilder.Ball(pos: near, number: 1),
        ]).snapshot)
        XCTAssertEqual(snap.focus, near, "同一条线上应取先被碰到的那颗")
        XCTAssertEqual(snap.targetBallNumber, 1)
    }

    func test_multiBall_contactBeatsSkim() throws {
        // 一颗擦身（2.5R）、一颗更远但真接触 ⇒ 取接触那颗。
        let skim = CGPoint(x: 0.4, y: r * 2.5)
        let hit = CGPoint(x: 0.8, y: r * 0.5)
        let snap = try XCTUnwrap(build([
            AimCloseupBuilder.Ball(pos: skim, number: 2),
            AimCloseupBuilder.Ball(pos: hit, number: 9),
        ]).snapshot)
        XCTAssertEqual(snap.focus, hit)
        XCTAssertEqual(snap.band, .contact)
        XCTAssertFalse(snap.showMissCaption)
    }

    /// 「多球换目标时构图正确切换」：瞄准方向转向另一颗，焦点/球号随之切换。
    func test_aimSwitch_movesFocusToTheNewlyAimedBall() throws {
        let ballA = AimCloseupBuilder.Ball(pos: CGPoint(x: 0.6, y: 0), number: 1)
        let ballB = AimCloseupBuilder.Ball(pos: CGPoint(x: 0.42, y: 0.42), number: 5)
        let balls = [ballA, ballB]

        func snapshot(direction: CGPoint) throws -> AimCloseupSnapshot {
            try XCTUnwrap(AimCloseupBuilder.freeAim(
                cue: cue, direction: direction, balls: balls, ballRadius: r, railEnd: railEnd,
                halfLength: CGFloat(ShotTableLayout.defaultHalfLength),
                halfWidth: CGFloat(ShotTableLayout.defaultHalfWidth),
                previouslyNear: true).snapshot)
        }

        let towardA = try snapshot(direction: CGPoint(x: 1, y: 0))
        XCTAssertEqual(towardA.targetBallNumber, 1)

        let towardB = try snapshot(direction: CGPoint(x: 1, y: 1))
        XCTAssertEqual(towardB.targetBallNumber, 5)
        XCTAssertNotEqual(towardA.focus, towardB.focus)
        XCTAssertNotEqual(towardA.focusNorm, towardB.focusNorm, "定位锚点须随焦点切换")
    }

    // MARK: - 取景

    func test_framing_isTightAndCueDropsOutWhenFar() throws {
        let target = CGPoint(x: 0.6, y: 0)
        let snap = try XCTUnwrap(build([AimCloseupBuilder.Ball(pos: target)]).snapshot)
        XCTAssertEqual(snap.halfWorld, r * AimCloseupBuilder.halfWorldMultiple, accuracy: 1e-9)
        XCTAssertNil(snap.cue, "母球远在取景外 ⇒ 不画（否则会画到圈外被裁）")

        let hugging = try XCTUnwrap(build([
            AimCloseupBuilder.Ball(pos: CGPoint(x: r * 2.2, y: 0))
        ]).snapshot)
        XCTAssertNotNil(hugging.cue, "贴球时母球进取景 ⇒ 应画")
    }
}

/// v23 W3：特写显隐门（近区 ∧ 正在改瞄准）。
@MainActor
final class AimCloseupGateTests: XCTestCase {

    private let r: CGFloat = 0.028575

    private func nearResult() -> AimCloseupBuilder.Result {
        AimCloseupBuilder.freeAim(
            cue: CGPoint(x: 0, y: 0), direction: CGPoint(x: 1, y: 0),
            balls: [AimCloseupBuilder.Ball(pos: CGPoint(x: 0.5, y: 0), number: 8)],
            ballRadius: r, railEnd: CGPoint(x: 1.3, y: 0),
            halfLength: CGFloat(ShotTableLayout.defaultHalfLength),
            halfWidth: CGFloat(ShotTableLayout.defaultHalfWidth),
            previouslyNear: false)
    }

    func test_nearAloneDoesNotShow_untilAimChanges() {
        var published: AimCloseupSnapshot??  = nil
        let gate = AimCloseupGate()
        gate.onSnapshotChange = { published = $0 }

        gate.update(nearResult())
        XCTAssertNil(published ?? nil, "只是近区、没在改瞄准 ⇒ 不上屏（A3）")
        XCTAssertTrue(gate.isNear, "isNear 仍需回传给下一帧滞回")

        gate.noteAimChanged()
        XCTAssertNotNil(published ?? nil, "近区 ∧ 正在改瞄准 ⇒ 上屏")
    }

    func test_reset_hidesAndClearsNear() {
        var published: AimCloseupSnapshot??  = nil
        let gate = AimCloseupGate()
        gate.onSnapshotChange = { published = $0 }
        gate.update(nearResult())
        gate.setDragging(true)
        XCTAssertNotNil(published ?? nil)

        gate.reset()
        XCTAssertNil(published ?? nil, "离开自由模式 / 播放中 ⇒ 立即收起")
        XCTAssertFalse(gate.isNear)
    }

    func test_draggingWithoutNearBand_staysHidden() {
        var emissions = 0
        let gate = AimCloseupGate()
        gate.onSnapshotChange = { _ in emissions += 1 }
        gate.setDragging(true)
        gate.update(AimCloseupBuilder.Result(snapshot: nil, isNear: false))
        XCTAssertEqual(emissions, 0, "远区拖轮不得闪出空 HUD")
    }
    func test_dragPause_retainsCloseupUntilRelease() async throws {
        for source in [AimCloseupGate.DragSource.table, .wheel] {
            let gate = AimCloseupGate()
            var visible = false
            gate.onSnapshotChange = { visible = $0 != nil }
            gate.update(nearResult())
            gate.setDragging(true, source: source)
            gate.noteAimChanged()
            try await Task.sleep(for: .milliseconds(450))
            XCTAssertTrue(visible, "Holding still must not end the gesture: \(source)")
            gate.setDragging(false, source: source)
            XCTAssertTrue(visible, "Release retains the existing sticky window")
            try await Task.sleep(for: .milliseconds(450))
            XCTAssertFalse(visible)
        }
    }

    func test_overlappingGestures_waitsForLastRelease() async throws {
        let gate = AimCloseupGate()
        var visible = false
        gate.onSnapshotChange = { visible = $0 != nil }
        gate.update(nearResult())
        gate.setDragging(true, source: .table)
        gate.setDragging(true, source: .wheel)
        gate.setDragging(false, source: .table)
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertTrue(visible)
        gate.setDragging(false, source: .wheel)
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertFalse(visible)
    }

    func test_regrabCancelsPendingHide() async throws {
        let gate = AimCloseupGate()
        var visible = false
        gate.onSnapshotChange = { visible = $0 != nil }
        gate.update(nearResult())
        gate.noteAimChanged()
        gate.setDragging(true)
        gate.noteAimChanged()
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertTrue(visible)
        gate.reset()
    }

    func test_nearBandExitAndReentry_whileHolding() async throws {
        let gate = AimCloseupGate()
        var visible = false
        gate.onSnapshotChange = { visible = $0 != nil }
        gate.update(nearResult())
        gate.setDragging(true)
        gate.update(.init(snapshot: nil, isNear: false))
        XCTAssertFalse(visible)
        try await Task.sleep(for: .milliseconds(450))
        gate.update(nearResult())
        XCTAssertTrue(visible, "Reentering the band during the same drag restores the loupe")
        gate.reset()
    }

    func test_resetClearsHeldSources_andTapStillExpires() async throws {
        let gate = AimCloseupGate()
        var visible = false
        gate.onSnapshotChange = { visible = $0 != nil }
        gate.update(nearResult())
        gate.setDragging(true, source: .table)
        gate.reset()
        gate.update(nearResult())
        gate.noteAimChanged()
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertFalse(visible, "A stale held source must not survive reset")
    }

}

@MainActor
final class AimPointCloseupLifecycleTests: XCTestCase {
    func test_tableAndWheelHold_thenRelease() async throws {
        let suiteName = "AimPointCloseupLifecycleTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let limiter = AngleUsageLimiter(defaults: defaults)
        limiter.isPremium = true
        let vm = AimPointSceneQuizViewModel(limiter: limiter)
        vm.setupScene(cameraMode: .topDown2DRotated)
        for table in [true, false] {
            if table { vm.setAimTableDragging(true) }
            else { vm.setAimWheelDragging(true) }
            vm.nudgeAim(byDegrees: 0)
            XCTAssertNotNil(vm.closeupSnapshot)
            try await Task.sleep(for: .milliseconds(450))
            XCTAssertNotNil(vm.closeupSnapshot)
            if table { vm.setAimTableDragging(false) }
            else { vm.setAimWheelDragging(false) }
            try await Task.sleep(for: .milliseconds(450))
            XCTAssertNil(vm.closeupSnapshot)
        }
    }
}

@MainActor
final class AimDragCoordinatorTests: XCTestCase {
    private final class Pan: UIPanGestureRecognizer {
        var simulatedState: UIGestureRecognizer.State = .possible
        override var state: UIGestureRecognizer.State {
            get { simulatedState }
            set { simulatedState = newValue }
        }
    }

    func test_endCancelAndFailure_reportReleaseEvenWhenInteractionDisabled() {
        for end in [UIGestureRecognizer.State.ended, .cancelled, .failed] {
            let scene = AngleTrainingScene()
            let coordinator = AngleSceneView.Coordinator(scene: scene, cameraMode: .topDown2DRotated, interactionMode: .tapsOnly)
            let view = SCNView(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
            view.scene = scene
            coordinator.scnView = view
            var events: [Bool] = []
            coordinator.onAimNudged = { _ in }
            coordinator.onAimDragActiveChanged = { events.append($0) }
            let pan = Pan()
            pan.simulatedState = .began
            coordinator.handlePan(pan)
            XCTAssertEqual(events, [true])
            coordinator.interactionMode = .none
            coordinator.gesturesEnabled = false
            pan.simulatedState = end
            coordinator.handlePan(pan)
            coordinator.endAimDrag()
            XCTAssertEqual(events, [true, false], "Terminal event must release exactly once: \(end)")
        }
    }
}

final class IdealObjectDirectionTests: XCTestCase {
    func testSixPocketRaysAndRailStops() throws {
        let table = TableGeometry.chineseEightBallQiuJi(surfaceY: 0)
        for pocket in table.pockets {
            // Corner entry follows the 45-degree throat bisector. A ray from
            // table center has a shallower entry and contacts a jaw first.
            let target = pocket.isCorner
                ? CGPoint(x: CGFloat(pocket.center.x) - (pocket.center.x > 0 ? 0.4 : -0.4),
                          y: CGFloat(pocket.center.z) - (pocket.center.z > 0 ? 0.4 : -0.4)) : .zero
            let ghost = CGPoint(x: 2 * target.x - CGFloat(pocket.center.x),
                                y: 2 * target.y - CGFloat(pocket.center.z))
            if pocket.isCorner {
                let shallow = try XCTUnwrap(IdealObjectDirection.preview(
                    target: .zero, ghost: CGPoint(x: -CGFloat(pocket.center.x), y: -CGFloat(pocket.center.z))))
                XCTAssertEqual(shallow.termination, .cushion)
            }
            let preview = try XCTUnwrap(IdealObjectDirection.preview(target: target, ghost: ghost))
            XCTAssertEqual(preview.termination, .pocket(pocket.id))
            XCTAssertEqual(hypot(preview.line.end.x - CGFloat(pocket.center.x),
                                 preview.line.end.y - CGFloat(pocket.center.z)), CGFloat(pocket.radius), accuracy: 0.0001)
        }
        let straight = try XCTUnwrap(IdealObjectDirection.preview(target: .zero, ghost: CGPoint(x: -1, y: 0)))
        XCTAssertEqual(straight.termination, .cushion)
        XCTAssertEqual(straight.line.end.x, CGFloat(AngleSceneCalculator.innerLength / 2 - BallPhysics.radius), accuracy: 0.0001)
        XCTAssertNil(IdealObjectDirection.preview(target: .zero, ghost: .zero))
    }


    @MainActor
    func testGeometryRenderAndInteractiveCost() throws {
        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: false)
        scene.hideAllBalls()
        let size = CGSize(width: 700, height: 400)
        scene.setCameraMode(.topDown2D, animated: false)
        scene.cameraRig?.fitLandscapeTable(viewSize: size)
        scene.cameraRig?.applyTopDown2D()
        let table = TableGeometry.chineseEightBallQiuJi(surfaceY: 0)
        for pocket in table.pockets {
            let t = pocket.isCorner
                ? CGPoint(x: CGFloat(pocket.center.x) - (pocket.center.x > 0 ? 0.4 : -0.4),
                          y: CGFloat(pocket.center.z) - (pocket.center.z > 0 ? 0.4 : -0.4)) : .zero
            let g = CGPoint(x: 2*t.x-CGFloat(pocket.center.x), y: 2*t.y-CGFloat(pocket.center.z))
            let preview = try XCTUnwrap(IdealObjectDirection.preview(target: t, ghost: g))
            func world(_ p: CGPoint) -> SCNVector3 {
                SCNVector3(Float(p.x), scene.surfaceY + BallPhysics.radius, Float(p.y))
            }
            _ = scene.addDashedLine(from: world(preview.line.start), to: world(preview.line.end), color: .lightGray)
        }
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene
        renderer.pointOfView = scene.cameraNode
        let attachment = XCTAttachment(image: renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X))
        attachment.name = "v61-six-pocket-geometry"
        attachment.lifetime = .keepAlways
        add(attachment)
        let start = Date()
        for _ in 0..<1000 {
            _ = IdealObjectDirection.preview(target: .zero, ghost: CGPoint(x: -1, y: -0.3))
        }
        print("v61 geometry average ms: \(Date().timeIntervalSince(start))")
        // A thousand queries must fit comfortably inside one second on simulator.
        XCTAssertLessThan(Date().timeIntervalSince(start), 1)
    }

    func testRaySymmetryFiniteAndOnDirection() throws {
        for degree in stride(from: 0, to: 360, by: 2) {
            let angle = Double(degree) * .pi / 180
            let target = CGPoint(x: 0.12, y: 0.08)
            let ghost = CGPoint(x: target.x - cos(angle), y: target.y - sin(angle))
            let a = try XCTUnwrap(IdealObjectDirection.preview(target: target, ghost: ghost))
            let b = try XCTUnwrap(IdealObjectDirection.preview(target: CGPoint(x: -target.x, y: -target.y),
                                                               ghost: CGPoint(x: -ghost.x, y: -ghost.y)))
            XCTAssertEqual(a.line.end.x, -b.line.end.x, accuracy: 0.002)
            XCTAssertEqual(a.line.end.y, -b.line.end.y, accuracy: 0.002)
            let dx = a.line.end.x - target.x, dy = a.line.end.y - target.y
            XCTAssertEqual(dx * sin(angle) - dy * cos(angle), 0, accuracy: 0.0001)
            XCTAssertGreaterThan(dx * cos(angle) + dy * sin(angle), 0)
        }
    }
}

@MainActor
final class PerspectiveBallDragCoordinatorTests: XCTestCase {
    private final class Pan: UIPanGestureRecognizer {
        var simulatedState: UIGestureRecognizer.State = .possible
        var point: CGPoint = .zero
        override var state: UIGestureRecognizer.State {
            get { simulatedState }
            set { simulatedState = newValue }
        }
        override func location(in view: UIView?) -> CGPoint { point }
        override func translation(in view: UIView?) -> CGPoint { .zero }
    }

    private func fixture() -> (AngleTrainingScene, SCNView, SCNNode, AngleSceneView.Coordinator) {
        let scene = AngleTrainingScene()
        let ball = SCNNode(geometry: SCNSphere(radius: CGFloat(AngleSceneCalculator.ballRadius)))
        ball.position = SCNVector3(0, scene.surfaceY + AngleSceneCalculator.ballRadius, 0)
        scene.rootNode.addChildNode(ball)
        let camera = SCNNode(); camera.camera = SCNCamera()
        camera.position = SCNVector3(0, ball.position.y + 2, 2)
        camera.look(at: ball.position)
        scene.rootNode.addChildNode(camera)
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        view.scene = scene; view.pointOfView = camera
        view.layoutIfNeeded(); SCNTransaction.flush(); _ = view.snapshot()
        let coordinator = AngleSceneView.Coordinator(scene: scene, cameraMode: .perspective3D, interactionMode: .cameraControl)
        coordinator.scnView = view; coordinator.draggableBallNodes = [ball]
        return (scene, view, ball, coordinator)
    }

    func testPerspectiveDragMovesOnTableAndReleasesForEveryTerminalState() {
        for terminal in [UIGestureRecognizer.State.ended, .cancelled, .failed] {
            let (scene, view, ball, coordinator) = fixture()
            let projected = view.projectPoint(ball.position)
            XCTAssertEqual(projected.x, 195, accuracy: 1)
            XCTAssertEqual(projected.y, 350, accuracy: 1)
            let original = ball.position
            let pan = Pan(); pan.point = CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
            var begins = 0, ends = 0, drops = 0
            coordinator.onDragBegan = { _ in begins += 1 }
            coordinator.onDragMoved = { node, point in node.position = point }
            coordinator.onDragEnded = { _ in ends += 1 }
            coordinator.onDragEndedAt = { _, _ in drops += 1 }
            pan.simulatedState = .began; coordinator.handlePan(pan)
            pan.point.x += 70; pan.simulatedState = .changed; coordinator.handlePan(pan)
            pan.point.x += 50; coordinator.handlePan(pan)
            XCTAssertGreaterThan(ball.position.x, original.x)
            XCTAssertEqual(ball.position.y, scene.surfaceY + AngleSceneCalculator.ballRadius, accuracy: 0.00001)
            coordinator.gesturesEnabled = false
            coordinator.interactionMode = .none
            pan.simulatedState = terminal; coordinator.handlePan(pan)
            coordinator.endBallDrag()
            XCTAssertEqual(begins, 1); XCTAssertEqual(ends, 1)
            XCTAssertEqual(drops, terminal == .ended ? 1 : 0)
        }
    }

    func testHiddenAndOccludedBallsCannotBeGrabbed() {
        let (scene, view, ball, coordinator) = fixture()
        let projected = view.projectPoint(ball.position)
        let point = CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
        XCTAssertTrue(coordinator.hitTestBall(at: point) === ball)
        ball.isHidden = true
        XCTAssertNil(coordinator.hitTestBall(at: point))
        ball.isHidden = false
        let blocker = SCNNode(geometry: SCNBox(width: 0.4, height: 0.4, length: 0.4, chamferRadius: 0))
        blocker.position = SCNVector3(0, ball.position.y + 1, 1)
        scene.rootNode.addChildNode(blocker)
        SCNTransaction.flush(); _ = view.snapshot()
        XCTAssertNil(coordinator.hitTestBall(at: point), "Cannot grab through foreground geometry")
    }

    func testFingerAllowanceChoosesNearestBallRegardlessOfArrayOrder() {
        let (scene, view, ball, coordinator) = fixture()
        let other = ball.clone(); other.position.x = 0.25; scene.rootNode.addChildNode(other)
        SCNTransaction.flush(); _ = view.snapshot()
        let p = view.projectPoint(other.position)
        let point = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y) + 18)
        for candidates in [[ball, other], [other, ball]] {
            coordinator.draggableBallNodes = candidates
            XCTAssertTrue(coordinator.hitTestBall(at: point) === other)
        }
    }

    func testSelectedBallKeepsNearbyDragAllowanceAndDirectHitSwitchesBall() {
        let (scene, view, ball, coordinator) = fixture()
        let other = ball.clone(); other.position.x = 0.15; scene.rootNode.addChildNode(other)
        coordinator.draggableBallNodes = [other, ball]
        SCNTransaction.flush(); _ = view.snapshot()
        let first = view.projectPoint(ball.position)
        let second = view.projectPoint(other.position)
        coordinator.handleTap(at: CGPoint(x: CGFloat(first.x), y: CGFloat(first.y)))
        let nearby = CGPoint(x: CGFloat(second.x), y: CGFloat(second.y) + 18)
        XCTAssertTrue(coordinator.hitTestBall(at: nearby) === ball, "A nearby gesture keeps the selected ball")
        coordinator.handleTap(at: CGPoint(x: CGFloat(second.x), y: CGFloat(second.y)))
        XCTAssertTrue(coordinator.hitTestBall(at: nearby) === other, "A direct ball hit switches selection")
        coordinator.handleTap(at: CGPoint(x: 10, y: 10))
        XCTAssertTrue(coordinator.hitTestBall(at: nearby) === other, "Empty-space tap returns to nearest-ball selection")
    }

    func testReadOnlySceneNeverStartsBallDrag() {
        let (_, view, ball, coordinator) = fixture()
        let p = view.projectPoint(ball.position)
        let pan = Pan(); pan.point = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y)); pan.simulatedState = .began
        var began = false
        coordinator.onDragBegan = { _ in began = true }
        coordinator.interactionMode = .none
        coordinator.handlePan(pan)
        XCTAssertFalse(began)
    }
}
