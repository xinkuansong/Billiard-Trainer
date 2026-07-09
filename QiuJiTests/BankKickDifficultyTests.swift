//
//  BankKickDifficultyTests.swift
//  QiuJiTests
//
//  W3（20260709 翻袋反射页重构方案 §3/§4.1）：好打优先排序模型 + 解缓存 + 求解管线集成。
//

import XCTest
import SceneKit
@testable import QiuJi

final class BankKickDifficultyTests: XCTestCase {

    private let sY: Float = 0.80

    // MARK: - 难度评分（单调性 + 档位）

    func test_bankScore_monotonicInCutAngleCushionsAndLength() {
        let base = BankKickDifficulty.bankScore(
            cutAngleDeg: 20, cueTargetDistance: 0.5, cushions: 1, pathLength: 0.8)
        let thinner = BankKickDifficulty.bankScore(
            cutAngleDeg: 75, cueTargetDistance: 0.5, cushions: 1, pathLength: 0.8)
        let moreCushions = BankKickDifficulty.bankScore(
            cutAngleDeg: 20, cueTargetDistance: 0.5, cushions: 3, pathLength: 0.8)
        let longer = BankKickDifficulty.bankScore(
            cutAngleDeg: 20, cueTargetDistance: 0.5, cushions: 1, pathLength: 2.4)
        let farther = BankKickDifficulty.bankScore(
            cutAngleDeg: 20, cueTargetDistance: 2.0, cushions: 1, pathLength: 0.8)
        XCTAssertGreaterThan(thinner, base, "切角更薄应更难")
        XCTAssertGreaterThan(moreCushions, base, "库数更多应更难")
        XCTAssertGreaterThan(longer, base, "路径更长应更难")
        XCTAssertGreaterThan(farther, base, "球距更远应更难")
    }

    func test_kickScore_monotonicInIncidenceMargin() {
        let steep = BankKickDifficulty.kickScore(
            firstRailIncidenceDeg: 70, cushions: 1, pathLength: 1.0)
        let shallow = BankKickDifficulty.kickScore(
            firstRailIncidenceDeg: 20, cushions: 1, pathLength: 1.0)
        XCTAssertGreaterThan(shallow, steep, "首库入射角越平（余量越小）应更难")
    }

    func test_tierBoundaries() {
        XCTAssertEqual(BankKickDifficulty.tier(0.0), .easy)
        XCTAssertEqual(BankKickDifficulty.tier(BankKickDifficulty.tierBoundaries.easy + 0.01), .medium)
        XCTAssertEqual(BankKickDifficulty.tier(BankKickDifficulty.tierBoundaries.medium + 0.01), .hard)
    }

    func test_goodness_rewardsRobustness() {
        let fragile = BankKickDifficulty.goodness(difficultyScore: 0.5, robustness: 0.0)
        let robust = BankKickDifficulty.goodness(difficultyScore: 0.5, robustness: 1.0)
        XCTAssertLessThan(robust, fragile, "同难度下容错高的解排序键应更小（更靠前）")
        // robustness nil 按 0 保守处理。
        XCTAssertEqual(BankKickDifficulty.goodness(difficultyScore: 0.5, robustness: nil), fragile)
    }

    // MARK: - LRU 解缓存（方案 §4.1）

    func test_solveCache_lruEvictionAndKeySensitivity() {
        var cache = BankKickSolveCache<BankKickSolveKey, Int>(capacity: 2)
        let k1 = BankKickSolveKey(ballsMM: [1, 2, 3, 4], pocketIndex: 0, powerStep: 36)
        let k2 = BankKickSolveKey(ballsMM: [1, 2, 3, 4], pocketIndex: 1, powerStep: 36)
        let k3 = BankKickSolveKey(ballsMM: [1, 2, 3, 4], pocketIndex: 0, powerStep: 37)

        cache.insert(1, for: k1)
        cache.insert(2, for: k2)
        XCTAssertEqual(cache.value(for: k1), 1)      // 命中并刷新 k1
        cache.insert(3, for: k3)                     // 容量 2：应逐出最久未用的 k2
        XCTAssertNil(cache.value(for: k2), "LRU 应逐出最久未用条目")
        XCTAssertEqual(cache.value(for: k1), 1)
        XCTAssertEqual(cache.value(for: k3), 3)

        // 任何 key 成分变化必 miss（球位毫米 / 袋口 / 力度步进）。
        let moved = BankKickSolveKey(ballsMM: [1, 2, 3, 5], pocketIndex: 0, powerStep: 36)
        XCTAssertNil(cache.value(for: moved))
    }

    func test_solveKey_quantization() {
        XCTAssertEqual(BankKickSolveKey.quantizeMM(0.1234), 123)
        XCTAssertEqual(BankKickSolveKey.quantizeMM(-0.5), -500)
        XCTAssertEqual(BankKickSolveKey.quantizePower(3.6), 36)
    }

    // MARK: - 求解管线集成（真实引擎，典型盘面）

    /// 翻袋典型盘面（与 [PERF-W1] 同盘面）：有解、好打分升序、字段齐备、容错在 [0,1]。
    func test_solveBank_typicalBoard_sortedAndAssembled() {
        let cue = SCNVector3(-0.5, sY + BallPhysics.radius, -0.2)
        let object = SCNVector3(0.1, sY + BallPhysics.radius, 0.1)
        let sols = BankKickSolvePipeline.solveBank(
            cue: cue, object: object, pocketIndex: 1, surfaceY: sY, power: 3.6)

        XCTAssertFalse(sols.isEmpty, "典型盘面应有翻袋解")
        XCTAssertLessThanOrEqual(sols.count, BankKickSolvePipeline.bankSolutionLimit)
        for (a, b) in zip(sols, sols.dropFirst()) {
            XCTAssertLessThanOrEqual(a.goodness, b.goodness, "解列表应按好打分升序")
        }
        for sol in sols {
            XCTAssertTrue(sol.prediction.simObjectPotted, "上屏解必经引擎终验真实进袋")
            XCTAssertGreaterThanOrEqual(sol.cushions, 1)
            if let r = sol.robustness {
                XCTAssertTrue((0.0...1.0).contains(r), "容错应在 [0,1]")
            }
        }
    }

    /// 反射典型盘面（与 [PERF-W2] 同盘面）：有解、排序正确、引擎终验判据成立。
    func test_solveKick_typicalBoard_sortedAndAssembled() {
        let cue = SCNVector3(-0.5, sY + BallPhysics.radius, -0.2)
        let target = SCNVector3(0.4, sY + BallPhysics.radius, 0.25)
        let sols = BankKickSolvePipeline.solveKick(
            cue: cue, target: target, surfaceY: sY, power: 3.6)

        XCTAssertFalse(sols.isEmpty, "典型盘面应有 kick 解")
        XCTAssertLessThanOrEqual(sols.count, BankKickSolvePipeline.kickSolutionLimit)
        for (a, b) in zip(sols, sols.dropFirst()) {
            XCTAssertLessThanOrEqual(a.goodness, b.goodness, "解列表应按好打分升序")
        }
        for sol in sols {
            XCTAssertTrue(sol.prediction.kickContactMade, "上屏解必经引擎终验真实碰到目标球")
            XCTAssertGreaterThanOrEqual(sol.cushions, 1)
            if let r = sol.robustness {
                XCTAssertTrue((0.0...1.0).contains(r), "容错应在 [0,1]")
            }
        }
    }

    // MARK: - 几何辅助

    /// 碰库点提取：构造已知“贴库-回弹”折线，应提取出唯一贴库点与指向台内的法向。
    /// 坐标契约：SceneKit 世界系 X–Z 水平面；长库 = 常 Z（±halfW）。
    func test_cushionTouchPoints_extractsBounceVertex() {
        let halfW = AngleSceneCalculator.innerWidth / 2
        let y = sY + AngleSceneCalculator.ballRadius
        let contactZ = halfW - AngleSceneCalculator.ballRadius   // 球心贴 +Z 长库
        let path = [
            SCNVector3(-0.4, y, 0.0),
            SCNVector3(-0.2, y, contactZ * 0.5),
            SCNVector3(0.0, y, contactZ),          // 贴库顶点
            SCNVector3(0.2, y, contactZ * 0.5),
            SCNVector3(0.4, y, 0.0)
        ]
        let touches = BankKickSolvePipeline.cushionTouchPoints(path)
        XCTAssertEqual(touches.count, 1, "应恰好提取一个碰库点")
        if let touch = touches.first {
            XCTAssertEqual(touch.point.z, contactZ, accuracy: 1e-4)
            XCTAssertEqual(touch.inwardNormal.z, -1, accuracy: 1e-6, "+Z 长库法向应指向 -Z（台内）")
        }
    }

    /// kick 首库入射角：构造 45° 入射的已知盘面（种子几何可解），角度应 ≈45°。
    func test_kickFirstRailIncidence_knownAngle() {
        // 母球 (0, 0)，目标 (0.6, 0)；经 +Z 长库一库：镜像展开给出对称 V 形路线，
        // 入射角 = atan(halfW / 0.3)（相对库面）。
        let halfW = Double(AngleSceneCalculator.innerWidth / 2)
        let cue = SCNVector3(0, sY, 0)
        let target = SCNVector3(0.6, sY, 0)
        let expected = atan(halfW / 0.3) * 180 / .pi
        let angle = BankKickSolvePipeline.kickFirstRailIncidenceDeg(
            cue: cue, target: target, rails: [.right], surfaceY: sY)
        XCTAssertNotNil(angle)
        if let angle {
            XCTAssertEqual(angle, expected, accuracy: 1.0)
        }
    }
}
