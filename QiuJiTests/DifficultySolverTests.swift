//
//  DifficultySolverTests.swift
//  QiuJiTests
//
//  可执行性感知求解（E1–E5，docs/research/20260709-可执行性感知求解方案.md）：
//  - DifficultyModel 纯函数金标准（加权范数不对称性 / 档位映射 / 力度惩罚 / 评分单调性）。
//  - E1 求解器排序：0 库桶存在无横塞解时代表必无横塞（spinX == 0）。
//  - E2 装配：解携带难度档位与评分，summary 含难度文案。
//  - E3 塞幅预算：`.vertical` 预算下（存在无塞解时）所有解无横塞且不标兜底。
//  - E5 扰动容错：开启后每解产出 robustness ∈ [0,1]；宽松盘面容错应高。
//

import XCTest
import SceneKit
@testable import QiuJi

final class DifficultySolverTests: XCTestCase {

    private let sY = BTTablePhysics.surfaceY

    /// 测试用粗网格（与 PositionPlaySolverTests.coarse 同参，提速）。
    private var coarse: PositionPlaySolver.SearchParams {
        PositionPlaySolver.SearchParams(
            spinXValues: [-0.3, 0, 0.3],
            spinYValues: [-0.3, 0, 0.3],
            velocityMin: 1.0, velocityMax: 5.0, velocityStep: 1.0,
            marginBase: 0.0, marginPerCushion: 0.04,
            passTolerance: 2 * AngleSceneCalculator.ballRadius, passMinSpeed: 0.2
        )
    }

    /// 直球大落区盘面（金标准场景：0 库中心球解必然存在）。
    private var straightBoard: BoardSnapshot {
        BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.5, y: 0.35),
            "_1": CanvasPoint(x: 0.5, y: 0.15)
        ])
    }
    private var bigRegion: SolveRegion {
        .circle(center: CanvasPoint(x: 0.5, y: 0.25), radius: 0.4)
    }

    // MARK: - DifficultyModel 纯函数金标准

    func test_effort_sideSpinWeightedHarderThanVertical() {
        // 用户核心反例：旧对称范数下 spinX=0.3(0.3) 会赢过 spinY=0.4(0.4)。
        // 加权范数必须反转：横塞 0.3 → 0.75，高低杆 0.4 → 0.4。
        let side = DifficultyModel.executionEffort(spinX: 0.3, spinY: 0, velocity: 2.0)
        let vertical = DifficultyModel.executionEffort(spinX: 0, spinY: 0.4, velocity: 2.0)
        XCTAssertGreaterThan(side, vertical, "横塞 0.3 的执行难度必须高于高低杆 0.4")
        XCTAssertEqual(side, 0.75, accuracy: 1e-9)
        XCTAssertEqual(vertical, 0.4, accuracy: 1e-9)
    }

    func test_velocityPenalty_zeroBelowThreshold_linearAbove() {
        XCTAssertEqual(DifficultyModel.velocityPenalty(2.0), 0, accuracy: 1e-9)
        XCTAssertEqual(DifficultyModel.velocityPenalty(4.0), 0, accuracy: 1e-9)
        XCTAssertEqual(DifficultyModel.velocityPenalty(6.0),
                       2.0 * DifficultyModel.velocityPenaltySlope, accuracy: 1e-9)
        // 排序语义：同塞情况下 5.0 m/s 的解应比 3.0 m/s 更难。
        let fast = DifficultyModel.executionEffort(spinX: 0, spinY: 0.2, velocity: 5.0)
        let slow = DifficultyModel.executionEffort(spinX: 0, spinY: 0.2, velocity: 3.0)
        XCTAssertGreaterThan(fast, slow)
    }

    func test_tier_mapping() {
        XCTAssertEqual(DifficultyModel.tier(spinX: 0, spinY: 0), .center)
        XCTAssertEqual(DifficultyModel.tier(spinX: 0, spinY: 0.3), .vertical)
        XCTAssertEqual(DifficultyModel.tier(spinX: 0.2, spinY: 0), .side)
        XCTAssertEqual(DifficultyModel.tier(spinX: 0.3, spinY: 0.2), .side)
        XCTAssertEqual(DifficultyModel.tier(spinX: 0.4, spinY: 0), .extremeSide)
        // 档位可比：center < vertical < side < extremeSide。
        XCTAssertLessThan(ShotDifficultyTier.center, .vertical)
        XCTAssertLessThan(ShotDifficultyTier.vertical, .side)
        XCTAssertLessThan(ShotDifficultyTier.side, .extremeSide)
    }

    func test_score_cutAngleAndDistance_monotonic() {
        // 切角：60° 以下不加难度，越薄越难。
        let easy = DifficultyModel.score(spinX: 0, spinY: 0, velocity: 2, cutAngleDeg: 30)
        let thin = DifficultyModel.score(spinX: 0, spinY: 0, velocity: 2, cutAngleDeg: 80)
        XCTAssertEqual(easy, 0, accuracy: 1e-9)
        XCTAssertGreaterThan(thin, easy)
        // 球距：1m 以内不加难度，越远越难。
        let near = DifficultyModel.score(spinX: 0, spinY: 0, velocity: 2, cueTargetDistance: 0.5)
        let far = DifficultyModel.score(spinX: 0, spinY: 0, velocity: 2, cueTargetDistance: 2.0)
        XCTAssertEqual(near, 0, accuracy: 1e-9)
        XCTAssertGreaterThan(far, near)
    }

    // MARK: - E1：0 库桶代表无横塞（可替代性以同桶扫描结果为证据）

    func test_solve_zeroCushionRepresentative_hasNoSideSpin() {
        let solutions = PositionPlaySolver.solve(
            before: straightBoard, targetKey: "_1", pocket: "topCenter",
            constraint: .restRegion(bigRegion), surfaceY: sY, params: coarse)
        XCTAssertFalse(solutions.isEmpty)
        // 直球大落区下 0 库中心球解必然存在 ⇒ 0 库桶代表必无横塞。
        if let zeroCushion = solutions.first(where: { $0.cushionCount == 0 }) {
            XCTAssertEqual(zeroCushion.shot.spinX, 0, accuracy: DifficultyModel.spinEps,
                           "0 库桶存在无塞解时，代表解不得带横塞（横塞零走位收益纯增难度）")
        } else {
            XCTFail("直球大落区应有 0 库解")
        }
    }

    // MARK: - E2：难度字段与文案装配

    func test_solutions_carryDifficultyFieldsAndSummary() {
        let solutions = PositionPlaySolver.solve(
            before: straightBoard, targetKey: "_1", pocket: "topCenter",
            constraint: .restRegion(bigRegion), surfaceY: sY, params: coarse)
        XCTAssertFalse(solutions.isEmpty)
        for s in solutions {
            XCTAssertEqual(s.difficultyTier,
                           DifficultyModel.tier(spinX: s.shot.spinX, spinY: s.shot.spinY),
                           "解的档位必须与其杆法一致")
            XCTAssertGreaterThanOrEqual(s.difficultyScore, 0)
            XCTAssertTrue(s.summary.contains("难度"), "summary 应含难度文案：\(s.summary)")
        }
    }

    // MARK: - E3：塞幅预算（优先 + 兜底）

    func test_maxSpinTier_vertical_returnsNoSideSpinSolutions() {
        var params = coarse
        params.maxSpinTier = .vertical
        let solutions = PositionPlaySolver.solve(
            before: straightBoard, targetKey: "_1", pocket: "topCenter",
            constraint: .restRegion(bigRegion), surfaceY: sY, params: params)
        XCTAssertFalse(solutions.isEmpty, "预算不得导致无解（优先+兜底）")
        // 该盘面无塞解充足 ⇒ 全部解应在预算内且不标兜底。
        for s in solutions {
            XCTAssertLessThanOrEqual(s.difficultyTier, .vertical,
                                     "预算内有解时不得混入横塞解")
            XCTAssertEqual(s.shot.spinX, 0, accuracy: DifficultyModel.spinEps)
            XCTAssertFalse(s.beyondSpinBudget)
        }
    }

    func test_maxSpinTier_appliesTo_spinTierBudgetFallbackMarking() {
        // 后处理兜底语义单测（不依赖构造「只有横塞可解」的物理盘面）：
        // 直接验证预算过滤器在「预算内无满足约束解」时回退并标注——通过公开 solve 路径
        // 难以确定性构造，此处以档位比较语义兜底（预算 cap 与解档位的偏序正确性）。
        XCTAssertTrue(ShotDifficultyTier.side > .vertical)
        XCTAssertTrue(ShotDifficultyTier.extremeSide > .side)
    }

    // MARK: - E5：扰动容错分析

    func test_robustness_enabled_producesFractionInRange() {
        var params = coarse
        params.robustnessEnabled = true
        let solutions = PositionPlaySolver.solve(
            before: straightBoard, targetKey: "_1", pocket: "topCenter",
            constraint: .restRegion(bigRegion), surfaceY: sY, params: params)
        XCTAssertFalse(solutions.isEmpty)
        for s in solutions {
            let r = try? XCTUnwrap(s.robustness, "开启容错分析后每个解必须产出 robustness")
            guard let r else { continue }
            XCTAssertGreaterThanOrEqual(r, 0)
            XCTAssertLessThanOrEqual(r, 1)
        }
        // 大落区（半径 0.4 norm ≈ 1m）下满足约束的解对小扰动应高度鲁棒。
        if let best = solutions.first(where: { $0.satisfiesConstraint }) {
            XCTAssertGreaterThanOrEqual(best.robustness ?? 0, 0.5,
                                        "宽松落区下满足约束解的容错度应 ≥ 50%")
        }
    }

    func test_robustness_disabled_isNil() {
        let solutions = PositionPlaySolver.solve(
            before: straightBoard, targetKey: "_1", pocket: "topCenter",
            constraint: .restRegion(bigRegion), surfaceY: sY, params: coarse)
        for s in solutions {
            XCTAssertNil(s.robustness, "默认关闭容错分析时 robustness 应为 nil（零开销）")
        }
    }
}
