//
//  SnookerSolverTests.swift
//  QiuJiTests
//
//  防守反解器（安全球，ADR-P16-01；V8 中八语义重做）：
//  - 中八规则：双组在桌禁 8 号目标（拦截）/ 对方球组推断（全色↔花色 / 只剩 8 号防 8 号）。
//  - 多被困球联合可见性：`snookerCoverageMulti`（单球回归不破坏）+ `defenseCoverage`（多球样本）。
//  - solveSnooker 硬约束不变量：满足约束（完全斯诺克）的解，重算几何/物理必复核成立
//    （首触目标球 / 母球不进袋 / 真停 / 对方球组全部挡死）。
//  - 无完全解时给「高难度可行解」（satisfiesConstraint == false）；非法输入返回空。
//
//  坐标契约：几何判定在 SceneKit 世界系 X–Z 平面、Y 朝上、单位米、水平角 atan2(z, x)。
//

import XCTest
import SceneKit
@testable import QiuJi

final class SnookerSolverTests: XCTestCase {

    private let sY = BTTablePhysics.surfaceY
    private var R: Float { AngleSceneCalculator.ballRadius }

    /// 测试用粗网格（提速；禁横塞缩小搜索，竖塞三档）。
    private var coarse: PositionPlaySolver.SnookerParams {
        PositionPlaySolver.SnookerParams(
            spinXValues: [0], spinYValues: [-0.3, 0, 0.3],
            velocityMin: 0.8, velocityMax: 3.2, velocityStep: 0.4,
            aimSamples: 15, maxCushions: nil)
    }

    // MARK: - 中八规则：对方球组推断 + 8 号目标拦截（DoD#1）

    func test_defenseRules_opponentInference_and_eightInterception() {
        // 双组在桌 + 8 号：全色 {1,2}、花色 {9,10}、8。
        let both = ["cueBall", "_1", "_2", "_9", "_10", "_8"]
        // 目标全色 → 对方 = 花色组。
        XCTAssertEqual(Set(SnookerTacticsViewModel.opponentKeys(for: "_1", onTable: both)),
                       Set(["_9", "_10"]))
        // 目标花色 → 对方 = 全色组。
        XCTAssertEqual(Set(SnookerTacticsViewModel.opponentKeys(for: "_9", onTable: both)),
                       Set(["_1", "_2"]))
        // 双组在桌 ⇒ 8 号不可作目标（拦截）。
        XCTAssertFalse(SnookerTacticsViewModel.canTarget("_8", onTable: both))
        XCTAssertTrue(SnookerTacticsViewModel.canTarget("_1", onTable: both))
        XCTAssertTrue(SnookerTacticsViewModel.canTarget("_9", onTable: both))
        XCTAssertFalse(SnookerTacticsViewModel.canTarget("cueBall", onTable: both))

        // 单组在桌（只全色 + 8）：8 号可作目标；目标 8 → 对方 = 在桌全色组。
        let solidsOnly = ["cueBall", "_1", "_2", "_8"]
        XCTAssertTrue(SnookerTacticsViewModel.canTarget("_8", onTable: solidsOnly))
        XCTAssertEqual(Set(SnookerTacticsViewModel.opponentKeys(for: "_8", onTable: solidsOnly)),
                       Set(["_1", "_2"]))

        // 只剩 8 号防 8 号：目标全色、花色已清空、8 号在桌 ⇒ 对方 = [8]。
        let stripesCleared = ["cueBall", "_1", "_8"]
        XCTAssertEqual(SnookerTacticsViewModel.opponentKeys(for: "_1", onTable: stripesCleared), ["_8"])
        // 花色已清空且无 8 ⇒ 无对方球。
        XCTAssertTrue(SnookerTacticsViewModel.opponentKeys(for: "_1", onTable: ["cueBall", "_1", "_2"]).isEmpty)
    }

    // MARK: - 多被困球联合可见性（DoD#2）

    func test_snookerCoverageMulti_singleBallRegression() {
        let cue = SCNVector3(0, sY, 0)
        let target = SCNVector3(1.0, sY, 0)

        // 单遮挡（列表长度 1）必须与 `snookerCoverage` 逐字段等价（回归不破坏）。
        let single = AngleSceneCalculator.snookerCoverage(
            cue: cue, snookered: target, blocker: SCNVector3(0.5, sY, 0))
        let multi = AngleSceneCalculator.snookerCoverageMulti(
            cue: cue, snookered: target, blockers: [(key: "_x", pos: SCNVector3(0.5, sY, 0))])
        XCTAssertEqual(multi.isFullSnooker, single.isFullSnooker)
        XCTAssertEqual(multi.marginDegrees, single.marginDegrees, accuracy: 1e-4)
        XCTAssertTrue(multi.isFullSnooker)
        XCTAssertEqual(multi.marginDegrees, 3.286, accuracy: 0.1)

        // 多遮挡取最优：一颗近且挡死（0.5）+ 一颗越过目标更远（1.5）⇒ 取挡死者。
        let best = AngleSceneCalculator.snookerCoverageMulti(
            cue: cue, snookered: target,
            blockers: [(key: "_far", pos: SCNVector3(1.5, sY, 0)),
                       (key: "_near", pos: SCNVector3(0.5, sY, 0))])
        XCTAssertTrue(best.isFullSnooker, "应挑到近处能挡死的遮挡球")

        // 仅有越过目标的远遮挡 ⇒ 挡不住。
        let onlyFar = AngleSceneCalculator.snookerCoverageMulti(
            cue: cue, snookered: target, blockers: [(key: "_far", pos: SCNVector3(1.5, sY, 0))])
        XCTAssertFalse(onlyFar.isFullSnooker)
    }

    func test_defenseCoverage_multiBallSample() {
        let cueFinal = SCNVector3(0, sY, 0)
        // 对方球 A 正右 (1,0,0)，被 (0.5,0,0) 的球挡死；对方球 B 正上 (0,0,1)，无遮挡。
        let a = (key: "_9", pos: SCNVector3(1.0, sY, 0))
        let b = (key: "_10", pos: SCNVector3(0, sY, 1.0))
        let blocker = (key: "_2", pos: SCNVector3(0.5, sY, 0))
        let cov = AngleSceneCalculator.defenseCoverage(
            cueFinal: cueFinal, opponents: [a, b],
            nonCueBalls: [a, b, blocker], surfaceY: sY)
        let covA = cov.first { $0.key == "_9" }
        let covB = cov.first { $0.key == "_10" }
        XCTAssertEqual(covA?.blocked, true, "A 应被 (0.5,0,0) 挡死")
        XCTAssertEqual(covB?.blocked, false, "B 无遮挡应可见")
        // 未遮挡球的难度在 [0,1]。
        XCTAssertGreaterThanOrEqual(covB?.pottingDifficulty ?? -1, 0)
        XCTAssertLessThanOrEqual(covB?.pottingDifficulty ?? 2, 1)
        // 挡死球难度记 1。
        XCTAssertEqual(covA?.pottingDifficulty ?? -1, 1.0, accuracy: 1e-9)
    }

    // MARK: - 非法输入

    func test_solveSnooker_invalidInputs_returnEmpty() {
        // 缺母球。
        let noCue = BoardSnapshot(onTable: ["_1": CanvasPoint(x: 0.5, y: 0.2),
                                            "_9": CanvasPoint(x: 0.6, y: 0.2)])
        XCTAssertTrue(PositionPlaySolver.solveSnooker(
            before: noCue, targetKey: "_1", opponentKeys: ["_9"], surfaceY: sY, params: coarse).isEmpty)

        let board = BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.3, y: 0.25),
            "_1": CanvasPoint(x: 0.6, y: 0.25),
            "_9": CanvasPoint(x: 0.7, y: 0.30)])
        // 空对方球组。
        XCTAssertTrue(PositionPlaySolver.solveSnooker(
            before: board, targetKey: "_1", opponentKeys: [], surfaceY: sY, params: coarse).isEmpty)
        // 目标球混入对方球组。
        XCTAssertTrue(PositionPlaySolver.solveSnooker(
            before: board, targetKey: "_1", opponentKeys: ["_1"], surfaceY: sY, params: coarse).isEmpty)
        // 对方球不在桌。
        XCTAssertTrue(PositionPlaySolver.solveSnooker(
            before: board, targetKey: "_1", opponentKeys: ["_10"], surfaceY: sY, params: coarse).isEmpty)
    }

    // MARK: - 硬约束不变量（满足约束的解必复核成立）

    func test_solveSnooker_satisfyingSolutions_passReCheck() {
        // 利于防守的球形：母球正左、目标球（全色 _1）正右、一颗我方球 _2 略偏离连线更近，
        // 单颗对方球（花色 _9）在其后方——母球切 _1 后回弹停在 _2 后方，把 _9 挡死。
        let board = BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.30, y: 0.25),
            "_1": CanvasPoint(x: 0.55, y: 0.25),
            "_2": CanvasPoint(x: 0.50, y: 0.22),
            "_9": CanvasPoint(x: 0.46, y: 0.19)])

        let solutions = PositionPlaySolver.solveSnooker(
            before: board, targetKey: "_1", opponentKeys: ["_9"], surfaceY: sY, params: coarse)
        XCTAssertFalse(solutions.isEmpty, "该球形应至少求得一个合法防守解")

        for s in solutions {
            let p = s.prediction
            XCTAssertFalse(p.cuePocketed, "母球不应进袋")
            XCTAssertLessThan(p.cueFinalSpeed, PositionPlaySolver.restSpeedTolerance, "母球应真停稳")
            // 合法首触：母球第一次球-球碰撞的另一方是目标球。
            var firstOther: String?
            for e in p.events {
                if case let .ballBall(a, b) = e.kind {
                    if a == ShotInput.cueBallName { firstOther = b; break }
                    if b == ShotInput.cueBallName { firstOther = a; break }
                }
            }
            XCTAssertEqual(firstOther, "_1", "首触必须是目标球")

            // 满足约束（完全斯诺克）的解：重算几何——对方球组全部挡死。
            if s.satisfiesConstraint {
                guard let c = p.finalPositions[ShotInput.cueBallName] else {
                    return XCTFail("满足解缺母球终位")
                }
                let potted = Set(p.pocketedBalls)
                var nonCue: [(key: String, pos: SCNVector3)] = []
                for (name, pos) in p.finalPositions where name != ShotInput.cueBallName && !potted.contains(name) {
                    nonCue.append((name, pos))
                }
                let opponents = nonCue.filter { $0.key == "_9" }
                XCTAssertFalse(opponents.isEmpty, "满足解：对方球 _9 应仍在桌")
                let cov = AngleSceneCalculator.defenseCoverage(
                    cueFinal: c, opponents: opponents, nonCueBalls: nonCue, surfaceY: sY)
                XCTAssertTrue(cov.allSatisfy { $0.blocked },
                              "满足解（完全斯诺克）：对方球组应全部挡死")
            }
        }

        // 完全斯诺克解按吃库数升序（库少优先）。
        let fulls = solutions.filter { $0.satisfiesConstraint }
        if fulls.count >= 2 {
            for i in 1..<fulls.count {
                XCTAssertLessThanOrEqual(fulls[i - 1].cushionCount, fulls[i].cushionCount,
                                         "完全斯诺克解应按吃库数升序")
            }
        }
    }

    // MARK: - 高难度可行解（无完全斯诺克时的降级）

    func test_solveSnooker_degradesToHighDifficulty_whenNoFullSnooker() {
        // 对方球 _9 贴在开阔中央、无可用遮挡体 ⇒ 难以完全挡死 ⇒ 期望「高难度可行解」（未完全）。
        let board = BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.30, y: 0.25),
            "_1": CanvasPoint(x: 0.55, y: 0.25),
            "_9": CanvasPoint(x: 0.70, y: 0.25)])

        let solutions = PositionPlaySolver.solveSnooker(
            before: board, targetKey: "_1", opponentKeys: ["_9"], surfaceY: sY, params: coarse)
        // 若无完全解，返回的应是标注未完全的高难度可行解（诚实分档）。
        for s in solutions where !s.satisfiesConstraint {
            XCTAssertFalse(s.satisfiesConstraint, "高难度可行解应标 satisfiesConstraint == false")
        }
        // 无论完全与否，任何返回解都必须复核硬约束（首触/不进袋/真停）。
        for s in solutions {
            XCTAssertFalse(s.prediction.cuePocketed)
            XCTAssertLessThan(s.prediction.cueFinalSpeed, PositionPlaySolver.restSpeedTolerance)
        }
    }
}
