import XCTest
import SceneKit
@testable import QiuJi

/// P17「球形生成器」Core 验证：`RackLayout`（摆架规则 + 几何 + 确定性）与
/// `BreakSimulator`（开球产出合法、停稳、确定性的散开板）。
///
/// 开球物理本身的可行性（停稳/不出界/不互穿/确定性跨速度）已由 `BreakRackPhysicsTests` 刻画；
/// 本套聚焦**生成器契约**：球号按玩法规则落位、球架不互穿在界、同 seed 同架、开球结果是
/// 一块合法可玩的归一化 `BoardSnapshot`。
final class RackGeneratorTests: XCTestCase {

    private let R = BallPhysics.radius

    private func distXZ(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        sqrtf((a.x - b.x) * (a.x - b.x) + (a.z - b.z) * (a.z - b.z))
    }

    /// 母球在球架默认开球点上做 +z 横移，制造非正中开球（瞄准方向由 `breakShot` 自动锁顶球）。
    private func offsetCue(_ rack: Rack, _ dz: Float) -> SCNVector3 {
        SCNVector3(rack.cue.x, rack.cue.y, rack.cue.z + dz)
    }

    private func assertRackValid(_ rack: Rack, file: StaticString = #filePath, line: UInt = #line) {
        let all = [rack.cue] + rack.balls.map { $0.position }
        var minDist = Float.greatestFiniteMagnitude
        for i in 0..<all.count {
            for j in (i + 1)..<all.count { minDist = min(minDist, distXZ(all[i], all[j])) }
        }
        XCTAssertGreaterThanOrEqual(minDist, 2 * R - 1e-5,
            "球架互穿，最小球距 \(minDist * 1000)mm", file: file, line: line)
        let halfL = TablePhysics.innerLength / 2 - R
        let halfW = TablePhysics.innerWidth / 2 - R
        for b in rack.balls {
            XCTAssertLessThanOrEqual(abs(b.position.x), halfL, "球 \(b.number) 出界 X", file: file, line: line)
            XCTAssertLessThanOrEqual(abs(b.position.z), halfW, "球 \(b.number) 出界 Z", file: file, line: line)
        }
    }

    private func assertBoardLegal(_ board: BoardSnapshot, file: StaticString = #filePath, line: UInt = #line) {
        let pts = board.onTable.values.map {
            AngleSceneCalculator.normalizedToScene(point: CGPoint(x: $0.x, y: $0.y),
                                                   surfaceY: BTTablePhysics.surfaceY)
        }
        var minDist = Float.greatestFiniteMagnitude
        for i in 0..<pts.count {
            for j in (i + 1)..<pts.count { minDist = min(minDist, distXZ(pts[i], pts[j])) }
        }
        if pts.count >= 2 {
            XCTAssertGreaterThan(minDist, 2 * R - 0.003,
                "散开板互穿，最小球距 \(minDist * 1000)mm", file: file, line: line)
        }
        for p in board.onTable.values {
            XCTAssert(p.x >= -0.01 && p.x <= 1.01, "归一化 x 出界 \(p.x)", file: file, line: line)
            XCTAssert(p.y >= -0.01 && p.y <= 0.51, "归一化 y 出界 \(p.y)", file: file, line: line)
        }
    }

    // MARK: - Rack rules

    func test_eightBallRack_rulesAndGeometry() {
        let rack = RackLayout.make(.chineseEightBall, seed: 1)
        XCTAssertEqual(rack.balls.count, 15, "中八应摆 15 颗")
        XCTAssertEqual(rack.balls[4].number, 8, "8 号应在第 3 排中点")
        let c1 = rack.balls[10].number, c2 = rack.balls[14].number
        XCTAssertTrue((c1 < 8 && c2 > 8) || (c1 > 8 && c2 < 8),
            "底两角应一花一色，实得 \(c1) / \(c2)")
        XCTAssertEqual(Set(rack.balls.map { $0.number }), Set(1...15), "球号应 1...15 不重不漏")
        assertRackValid(rack)
    }

    func test_nineBallRack_anchors() {
        let rack = RackLayout.make(.nineBall, seed: 2)
        XCTAssertEqual(rack.balls.count, 9, "9 球应摆 9 颗")
        XCTAssertEqual(rack.balls[0].number, 1, "1 号在钻石顶角")
        XCTAssertEqual(rack.balls[4].number, 9, "9 号在钻石中心")
        XCTAssertEqual(rack.balls[8].number, 2, "2 号在钻石尾点")
        XCTAssertEqual(Set(rack.balls.map { $0.number }), Set(1...9))
        assertRackValid(rack)
    }

    func test_zhuifenRacks() {
        // 9 球系少球：固定带 9 号、1 号在 apex（球号集非连续 1...n）。
        let expected: [Int: Set<Int>] = [
            4: [1, 2, 3, 9],
            5: [1, 2, 3, 4, 9],
            6: [1, 2, 3, 4, 5, 9]
        ]
        for n in [4, 5, 6] {
            let rack = RackLayout.make(.zhuifen(balls: n), seed: UInt64(n))
            XCTAssertEqual(rack.balls.count, n, "\(n) 球应摆 \(n) 颗")
            XCTAssertEqual(rack.balls[0].number, 1, "1 号应在最前（apex）")
            XCTAssertEqual(Set(rack.balls.map { $0.number }), expected[n]!,
                "\(n) 球号集应为 \(expected[n]!.sorted())")
            assertRackValid(rack)
        }
        // 9 号锚点（按玩法）：4 球底正对 apex、6 球底排中点、5 球在尾。
        XCTAssertEqual(RackLayout.make(.zhuifen(balls: 4), seed: 4).balls[3].number, 9,
            "4 球：9 号在底（正对 1）")
        XCTAssertEqual(RackLayout.make(.zhuifen(balls: 5), seed: 5).balls[4].number, 9,
            "5 球：9 号在尾")
        XCTAssertEqual(RackLayout.make(.zhuifen(balls: 6), seed: 6).balls[4].number, 9,
            "6 球：9 号在底排中点")
    }

    // MARK: - Determinism

    func test_sameSeed_sameRack() {
        let a = RackLayout.make(.chineseEightBall, seed: 42)
        let b = RackLayout.make(.chineseEightBall, seed: 42)
        XCTAssertEqual(a.balls.map { $0.number }, b.balls.map { $0.number },
            "同 seed 应产出完全一致的球号排布")
    }

    func test_differentSeed_differentRack() {
        let a = RackLayout.make(.chineseEightBall, seed: 1).balls.map { $0.number }
        let b = RackLayout.make(.chineseEightBall, seed: 2).balls.map { $0.number }
        XCTAssertNotEqual(a, b, "不同 seed 应产出不同排布")
    }

    // MARK: - Break simulation

    func test_breakEightBall_producesLegalSettledBoard() {
        let rack = RackLayout.make(.chineseEightBall, seed: 7)
        let res = BreakSimulator.breakShot(rack: rack, cuePosition: offsetCue(rack, 0.03), power: 5.0)
        XCTAssertTrue(res.settled, "开球应完全停稳（未被 maxEvents 截断）")
        let expected = 16 - res.pocketed.count   // 母球 + 15 目标球 − 落袋
        XCTAssertEqual(res.board.onTable.count, expected,
            "散开板球数应 = 16 − 落袋 \(res.pocketed.count)")
        assertBoardLegal(res.board)
        print("[RACKGEN-break8] 落袋 \(res.pocketed) · 在桌 \(res.board.onTable.count) · 刮杆 \(res.cueScratched) · 8onBreak \(res.eightOnBreak)")
    }

    func test_breakNineBall_producesLegalSettledBoard() {
        let rack = RackLayout.make(.nineBall, seed: 11)
        let res = BreakSimulator.breakShot(rack: rack, cuePosition: offsetCue(rack, 0.03), power: 5.0)
        XCTAssertTrue(res.settled, "9 球开球应完全停稳")
        XCTAssertEqual(res.board.onTable.count, 10 - res.pocketed.count)
        assertBoardLegal(res.board)
        XCTAssertFalse(res.eightOnBreak, "9 球不应触发 8-on-break 标志")
    }

    func test_break_deterministic() {
        let rack = RackLayout.make(.chineseEightBall, seed: 7)
        let a = BreakSimulator.breakShot(rack: rack, cuePosition: offsetCue(rack, 0.03), power: 5.0)
        let b = BreakSimulator.breakShot(rack: rack, cuePosition: offsetCue(rack, 0.03), power: 5.0)
        XCTAssertEqual(a.pocketed, b.pocketed, "两次开球落袋集应一致")
        XCTAssertEqual(a.board.onTable.count, b.board.onTable.count)
        for (k, p) in a.board.onTable {
            guard let q = b.board.onTable[k] else {
                XCTFail("球 \(k) 在第二次开球缺失"); continue
            }
            XCTAssertEqual(p.x, q.x, accuracy: 1e-4, "\(k) 终位 x 运行间不一致")
            XCTAssertEqual(p.y, q.y, accuracy: 1e-4, "\(k) 终位 y 运行间不一致")
        }
    }
}
