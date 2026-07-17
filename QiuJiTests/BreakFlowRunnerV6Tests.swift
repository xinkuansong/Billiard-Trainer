import XCTest
import SceneKit
import Metal
@testable import QiuJi

/// 问题集合 v5 · V6（G18）+ v8 · X3（K6–K8）验证：
/// - 随机性只保留球堆间距；去隐藏随机塞；默认力度 6 m/s
/// - K6：手动交付状态机 + seed 随机/跨局异局
/// - K7：`breakNow` 传入真实 spin（非恒 0）
/// - K8：瞄准线接 `AimLineGeometry`（接触红点 / 未接触到库边）截图落盘
final class BreakFlowRunnerV6Tests: XCTestCase {

    private func positions(_ game: RackGame, seed: UInt64) -> [SCNVector3] {
        RackLayout.make(game, seed: seed).balls.map { $0.position }
    }

    /// 两组球位的最大逐球逐轴偏差（X–Z 平面）。
    private func maxDelta(_ a: [SCNVector3], _ b: [SCNVector3]) -> Float {
        guard a.count == b.count else { return .greatestFiniteMagnitude }
        var m: Float = 0
        for (p, q) in zip(a, b) { m = max(m, max(abs(p.x - q.x), abs(p.z - q.z))) }
        return m
    }

    private var evidenceDir: URL {
        // worktree 根：…/QiuJiTests → …/
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let dir = root.appendingPathComponent("build/x3-screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - 球堆间距：唯一保留的随机源（seed 驱动、确定性）

    func test_sameSeed_identicalRackSpacing() {
        let a = positions(.chineseEightBall, seed: 42)
        let b = positions(.chineseEightBall, seed: 42)
        XCTAssertEqual(a.count, b.count)
        XCTAssertLessThan(maxDelta(a, b), 1e-6,
            "同 seed 球堆位置（含间距 jitter）应逐球完全一致（确定性 / WYSIWYG）")
    }

    func test_differentSeed_perturbsRackSpacing_boundedByJitterRadius() {
        let a = positions(.chineseEightBall, seed: 1)
        let b = positions(.chineseEightBall, seed: 2)
        let d = maxDelta(a, b)
        XCTAssertGreaterThan(d, 0, "异 seed 应扰动球堆间距（球位不同）——间距是唯一随机源")
        XCTAssertLessThanOrEqual(d, 2 * RackLayout.jitterRadius + 1e-6,
            "球位扰动幅度不得超过 jitterRadius 上界（不互穿护栏）")
    }

    // MARK: - 去随机塞：固定瞄准/力度/无塞 ⇒ 开球确定性

    func test_break_deterministic_noHiddenRandomSpin() {
        let rack = RackLayout.make(.chineseEightBall, seed: 7)
        let aim = BreakSimulator.aimAtApex(rack: rack, from: rack.cue)
        let a = BreakSimulator.breakShot(rack: rack, aimDirection: aim, power: 6.0)
        let b = BreakSimulator.breakShot(rack: rack, aimDirection: aim, power: 6.0)
        XCTAssertEqual(a.pocketed, b.pocketed, "同 rack/瞄准/力度 两次开球落袋集应一致（无随机塞）")
        XCTAssertEqual(a.board.onTable.count, b.board.onTable.count)
        for (k, p) in a.board.onTable {
            guard let q = b.board.onTable[k] else { XCTFail("球 \(k) 在第二次开球缺失"); continue }
            XCTAssertEqual(p.x, q.x, accuracy: 1e-4, "\(k) 终位 x 运行间不一致（疑有隐藏随机）")
            XCTAssertEqual(p.y, q.y, accuracy: 1e-4, "\(k) 终位 y 运行间不一致（疑有隐藏随机）")
        }
    }

    /// 瞄准方向可控：不同瞄准（如偏 6°）应产出不同散局（证明 aimDirection 真正参与开球）。
    func test_break_aimDirectionAffectsOutcome() {
        let rack = RackLayout.make(.chineseEightBall, seed: 7)
        let straight = BreakSimulator.aimAtApex(rack: rack, from: rack.cue)
        let skewed = AngleSceneCalculator.rotatedAim(straight, byDegrees: 6)
        let a = BreakSimulator.breakShot(rack: rack, aimDirection: straight, power: 6.0)
        let b = BreakSimulator.breakShot(rack: rack, aimDirection: skewed, power: 6.0)
        var differs = a.pocketed != b.pocketed
        if !differs {
            for (k, p) in a.board.onTable {
                if let q = b.board.onTable[k],
                   abs(p.x - q.x) > 1e-3 || abs(p.y - q.y) > 1e-3 { differs = true; break }
            }
        }
        XCTAssertTrue(differs, "改变开球瞄准方向应改变散局（瞄准真正参与开球）")
    }

    // MARK: - 默认力度 6 m/s

    @MainActor
    func test_defaultBreakVelocity_isSix() {
        XCTAssertEqual(BreakFlowRunner.defaultBreakVelocity, 6.0, accuracy: 1e-9,
            "G18：开球默认力度常量应为 6 m/s（替代固定 7.0）")
        let scene = AngleTrainingScene()
        let runner = BreakFlowRunner(scene: scene, game: .chineseEightBall, seed: 1)
        XCTAssertEqual(runner.velocity, 6.0, accuracy: 1e-9,
            "runner 实例默认力度应为 6 m/s（参与开球速度）")
    }

    // MARK: - K6：手动交付状态机

    @MainActor
    func test_manualDeliver_settleStateMachine() {
        let scene = AngleTrainingScene()
        scene.setupScene()
        let runner = BreakFlowRunner(scene: scene, game: .chineseEightBall, seed: 11)
        XCTAssertFalse(runner.autoDeliverOnSettle,
                       "K6：默认手动交付（autoDeliverOnSettle == false）")
        runner.rackUp()
        XCTAssertEqual(runner.phase, .racked)
        XCTAssertFalse(runner.showsConfirm)

        var delivered: BoardSnapshot?
        runner.onSettled = { delivered = $0 }

        let board = BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.75, y: 0.25),
            "_1": CanvasPoint(x: 0.4, y: 0.2),
        ])
        runner.applySettledBoardForTesting(board)

        XCTAssertEqual(runner.phase, .settled, "手动交付：停稳进 .settled，不立刻 onSettled")
        XCTAssertTrue(runner.showsConfirm, "settled 时应显示「完成」")
        XCTAssertNil(delivered, "未点「完成」前不得交付宿主")

        runner.confirmSettled()
        XCTAssertNotNil(delivered, "点「完成」后应交付散局")
        XCTAssertEqual(delivered?.onTable.count, 2)
    }

    @MainActor
    func test_autoDeliver_callsOnSettledImmediately() {
        let scene = AngleTrainingScene()
        scene.setupScene()
        let runner = BreakFlowRunner(scene: scene, game: .chineseEightBall, seed: 12)
        runner.autoDeliverOnSettle = true
        var delivered = false
        runner.onSettled = { _ in delivered = true }
        runner.applySettledBoardForTesting(BoardSnapshot(onTable: [:]))
        XCTAssertTrue(delivered, "autoDeliverOnSettle=true 时应立即 onSettled")
        XCTAssertNotEqual(runner.phase, .settled, "自动交付不停留在 .settled")
        XCTAssertFalse(runner.showsConfirm)
    }

    // MARK: - K6：seed 随机性

    @MainActor
    func test_sameRunner_reRack_producesDifferentRack() {
        let scene = AngleTrainingScene()
        scene.setupScene()
        let runner = BreakFlowRunner(scene: scene, game: .chineseEightBall, seed: 1)
        runner.rackUp()
        let seedBefore = runner.seed
        let before = positions(.chineseEightBall, seed: seedBefore)
        runner.reRack()
        XCTAssertEqual(runner.seed, seedBefore &+ 1, "reRack 应 seed++")
        let after = positions(.chineseEightBall, seed: runner.seed)
        XCTAssertGreaterThan(maxDelta(before, after), 0,
                             "同 runner reRack 后球堆应异局（seed 驱动 jitter）")
        XCTAssertEqual(runner.phase, .racked)
        XCTAssertFalse(runner.showsConfirm)
    }

    @MainActor
    func test_newRunners_firstRackNotAlwaysIdentical() {
        let scene = AngleTrainingScene()
        scene.setupScene()
        var seeds = Set<UInt64>()
        var racks: [[SCNVector3]] = []
        for _ in 0..<8 {
            let runner = BreakFlowRunner(scene: scene, game: .chineseEightBall)
            seeds.insert(runner.seed)
            racks.append(positions(.chineseEightBall, seed: runner.seed))
        }
        XCTAssertGreaterThan(seeds.count, 1,
                             "新 runner 初值 seed 不得恒为同一值（旧行为 seed≡1）")
        var anyDiff = false
        for i in 1..<racks.count {
            if maxDelta(racks[0], racks[i]) > 0 { anyDiff = true; break }
        }
        XCTAssertTrue(anyDiff, "新 runner 首局球堆不得恒同（跨 runner 异 seed）")
    }

    // MARK: - K7：spin 传入 breakNow

    @MainActor
    func test_breakNow_passesNonZeroSpin() {
        let scene = AngleTrainingScene()
        scene.setupScene()
        let runner = BreakFlowRunner(scene: scene, game: .chineseEightBall, seed: 3)
        runner.rackUp()
        runner.spinX = 0.35
        runner.spinY = -0.22
        runner.breakNow()
        XCTAssertNotNil(runner.lastBreakSpin, "breakNow 应记录传入 spin")
        XCTAssertEqual(runner.lastBreakSpin!.x, 0.35, accuracy: 1e-6,
                       "K7：breakNow 不得恒传 spinX=0")
        XCTAssertEqual(runner.lastBreakSpin!.y, -0.22, accuracy: 1e-6,
                       "K7：breakNow 不得恒传 spinY=0")
        // 取消异步回放，避免测试收尾时场景仍在跑。
        runner.cancel()
    }

    func test_breakSimulator_spinAffectsOutcome() {
        let rack = RackLayout.make(.chineseEightBall, seed: 7)
        let aim = BreakSimulator.aimAtApex(rack: rack, from: rack.cue)
        let a = BreakSimulator.breakShot(rack: rack, aimDirection: aim, power: 6.0,
                                         spinX: 0, spinY: 0)
        let b = BreakSimulator.breakShot(rack: rack, aimDirection: aim, power: 6.0,
                                         spinX: 0.4, spinY: -0.3)
        var differs = a.pocketed != b.pocketed
        if !differs {
            for (k, p) in a.board.onTable {
                if let q = b.board.onTable[k],
                   abs(p.x - q.x) > 1e-3 || abs(p.y - q.y) > 1e-3 { differs = true; break }
            }
        }
        XCTAssertTrue(differs, "BreakSimulator.breakShot 的 spin 参数应影响散局")
    }

    // MARK: - K8：瞄准线两态截图（接触红点 / 未接触到库边）

    @MainActor
    func test_k8_aimLine_touchAndMiss_screenshots() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal unavailable — skip K8 aim-line screenshots")
        }
        let scene = AngleTrainingScene()
        scene.setupScene()
        let runner = BreakFlowRunner(scene: scene, game: .chineseEightBall, seed: 21)
        runner.rackUp()

        // 默认锁顶球：垂距 ≈ 0 < R ⇒ 接触态（线停球面 + 红点）。
        let touchPNG = try snapshotPNG(scene: scene, device: device)
        let touchURL = evidenceDir.appendingPathComponent("x3-k8-aim-touch-reddot.png")
        try touchPNG.write(to: touchURL)
        print("X3 K8 wrote \(touchURL.path)")

        // 大幅偏转瞄准 ⇒ 垂距 ≥ R ⇒ 未接触，线延伸库边、无红点。
        runner.nudgeAim(byDegrees: 28)
        let missPNG = try snapshotPNG(scene: scene, device: device)
        let missURL = evidenceDir.appendingPathComponent("x3-k8-aim-miss-to-rail.png")
        try missPNG.write(to: missURL)
        print("X3 K8 wrote \(missURL.path)")

        // 数值不变量：锁顶球应 touches；大偏转应 miss（与草稿一致）。
        let rack = RackLayout.make(.chineseEightBall, seed: 21)
        let cue = rack.cue
        let apex = rack.balls.max { $0.position.x < $1.position.x }!.position
        let aimTouch = BreakSimulator.aimAtApex(rack: rack, from: cue)
        let railTouch = AngleSceneCalculator.rayToInnerRail(from: cue, dir: aimTouch)
        let resTouch = AimLineGeometry.resolve(
            cue: CGPoint(x: CGFloat(cue.x), y: CGFloat(cue.z)),
            dir: CGPoint(x: CGFloat(aimTouch.x), y: CGFloat(aimTouch.z)),
            target: CGPoint(x: CGFloat(apex.x), y: CGFloat(apex.z)),
            ballRadius: CGFloat(AngleSceneCalculator.ballRadius),
            railEnd: CGPoint(x: CGFloat(railTouch.x), y: CGFloat(railTouch.z)))
        XCTAssertTrue(resTouch.touchesBall, "锁顶球瞄准应接触顶球（红点态）")
        XCTAssertNotNil(resTouch.contactPoint)

        let aimMiss = AngleSceneCalculator.rotatedAim(aimTouch, byDegrees: 28)
        let railMiss = AngleSceneCalculator.rayToInnerRail(from: cue, dir: aimMiss)
        let resMiss = AimLineGeometry.resolve(
            cue: CGPoint(x: CGFloat(cue.x), y: CGFloat(cue.z)),
            dir: CGPoint(x: CGFloat(aimMiss.x), y: CGFloat(aimMiss.z)),
            target: CGPoint(x: CGFloat(apex.x), y: CGFloat(apex.z)),
            ballRadius: CGFloat(AngleSceneCalculator.ballRadius),
            railEnd: CGPoint(x: CGFloat(railMiss.x), y: CGFloat(railMiss.z)))
        XCTAssertFalse(resMiss.touchesBall, "偏转 28° 应未接触顶球（延伸库边态）")
        XCTAssertEqual(resMiss.lineEnd.x, CGFloat(railMiss.x), accuracy: 1e-5)
        XCTAssertEqual(resMiss.lineEnd.y, CGFloat(railMiss.z), accuracy: 1e-5)
    }

    @MainActor
    private func snapshotPNG(scene: AngleTrainingScene, device: MTLDevice) throws -> Data {
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = scene.cameraNode
        renderer.autoenablesDefaultLighting = false
        let img = renderer.snapshot(atTime: 0, with: CGSize(width: 900, height: 600),
                                    antialiasingMode: .multisampling4X)
        guard let png = img.pngData() else {
            struct E: Error {}
            throw E()
        }
        return png
    }
}
