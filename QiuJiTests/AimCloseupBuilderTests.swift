import XCTest
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
}
