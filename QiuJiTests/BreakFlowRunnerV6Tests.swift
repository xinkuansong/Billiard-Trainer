import XCTest
import SceneKit
@testable import QiuJi

/// 问题集合 v5 · V6（G18 开球通用规范）验证：
/// - **随机性只保留球堆间距**：`RackLayout` jitter（seed 驱动、确定性、受 `jitterRadius` 上界锁死）；
/// - **去随机塞**：固定「瞄准 + 力度 + 无塞」时开球是确定性的（不再注入 `breakJitter`）；
/// - `BreakFlowRunner` **默认力度 6 m/s** 且参与开球速度。
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
        // 每颗球在半径 jitterRadius 圆盘内独立偏移，两 seed 逐球逐轴差 ≤ 2·jitterRadius；
        // 该上界即「永不互穿」护栏（见 RackLayout.jitterRadius 推导）。
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
        // 混沌系统：不同开球角必然产出不同散局（至少一颗球终位不同）。
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
        let runner = BreakFlowRunner(scene: scene, game: .chineseEightBall)
        XCTAssertEqual(runner.velocity, 6.0, accuracy: 1e-9,
            "runner 实例默认力度应为 6 m/s（参与开球速度）")
    }
}
