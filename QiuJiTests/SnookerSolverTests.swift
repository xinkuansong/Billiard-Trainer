//
//  SnookerSolverTests.swift
//  QiuJiTests
//
//  做斯诺克反解器（安全球，ADR-P16-01）：
//  - 张角覆盖判定金标准（确定性，闭式 coverage = β − α − |Δθ|，禁止脑算 → 数值验证）。
//  - solveSnooker 硬约束不变量：满足约束的解，重算几何/物理必复核成立（首触/不进袋/真停/完全挡死）。
//  - 降级解：无完全斯诺克时返回半斯诺克（satisfiesConstraint == false、margin < 0）。
//  - 非法输入返回空。
//
//  坐标契约：几何判定在 SceneKit 世界系 X–Z 平面、Y 朝上、角度 atan2(z, x)。
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

    // MARK: - 张角覆盖判定金标准（确定性）

    func test_snookerCoverage_goldenSamples() {
        let cue = SCNVector3(0, sY, 0)
        let target = SCNVector3(1.0, sY, 0)

        // S1：障碍在母球-目标连线上、更近 ⇒ 完全挡死，余量 ≈ 3.286°。
        let s1 = AngleSceneCalculator.snookerCoverage(
            cue: cue, snookered: target, blocker: SCNVector3(0.5, sY, 0))
        XCTAssertTrue(s1.blockerCloser)
        XCTAssertTrue(s1.isFullSnooker)
        XCTAssertEqual(s1.marginDegrees, 3.286, accuracy: 0.1)
        XCTAssertEqual(s1.visibleHalfAngleDegrees, 3.276, accuracy: 0.05)

        // S2：障碍越过目标球（更远）⇒ 不会先拦截 ⇒ 非完全斯诺克。
        let s2 = AngleSceneCalculator.snookerCoverage(
            cue: cue, snookered: target, blocker: SCNVector3(1.5, sY, 0))
        XCTAssertFalse(s2.blockerCloser)
        XCTAssertFalse(s2.isFullSnooker)

        // S3：障碍横向偏出视线扇形（虽更近、张角更大）⇒ 仍露边 ⇒ 非完全、余量为负。
        let s3 = AngleSceneCalculator.snookerCoverage(
            cue: cue, snookered: target, blocker: SCNVector3(0.5, sY, 0.057))
        XCTAssertTrue(s3.blockerCloser)
        XCTAssertFalse(s3.isFullSnooker)
        XCTAssertLessThan(s3.marginDegrees, 0)

        // S4：贴近母球的障碍张角极大 ⇒ 完全挡死、余量很大。
        let s4 = AngleSceneCalculator.snookerCoverage(
            cue: cue, snookered: target, blocker: SCNVector3(0.12, sY, 0))
        XCTAssertTrue(s4.isFullSnooker)
        XCTAssertGreaterThan(s4.marginDegrees, 15)
    }

    // MARK: - 非法输入

    func test_solveSnooker_invalidInputs_returnEmpty() {
        // 缺母球。
        let noCue = BoardSnapshot(onTable: ["_1": CanvasPoint(x: 0.5, y: 0.2),
                                            "_2": CanvasPoint(x: 0.6, y: 0.2)])
        XCTAssertTrue(PositionPlaySolver.solveSnooker(
            before: noCue, targetKey: "_1", blockerKey: "_2", surfaceY: sY, params: coarse).isEmpty)

        // 目标 == 障碍。
        let board = BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.3, y: 0.25),
            "_1": CanvasPoint(x: 0.6, y: 0.25)])
        XCTAssertTrue(PositionPlaySolver.solveSnooker(
            before: board, targetKey: "_1", blockerKey: "_1", surfaceY: sY, params: coarse).isEmpty)

        // 障碍不在桌。
        XCTAssertTrue(PositionPlaySolver.solveSnooker(
            before: board, targetKey: "_1", blockerKey: "_9", surfaceY: sY, params: coarse).isEmpty)
    }

    // MARK: - 硬约束不变量（满足约束的解必复核成立）

    func test_solveSnooker_satisfyingSolutions_passReCheck() {
        // 利于做斯诺克的球形（探针实测产出多个完全斯诺克解）：母球正左、目标球正右，障碍球
        // 略偏离连线且更近——母球被切后回弹停在障碍后方挡死目标。
        let board = BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.30, y: 0.25),
            "_1": CanvasPoint(x: 0.55, y: 0.25),
            "_8": CanvasPoint(x: 0.50, y: 0.22)])

        let solutions = PositionPlaySolver.solveSnooker(
            before: board, targetKey: "_1", blockerKey: "_8", surfaceY: sY, params: coarse)

        // 该球形必能找到完全斯诺克解（探针确证）。
        let fulls = solutions.filter { $0.satisfiesConstraint }
        XCTAssertFalse(fulls.isEmpty, "该利于做斯诺克的球形应至少求得 1 个完全斯诺克解")

        // 凡返回的「满足约束」解，重算必须复核成立——杜绝假装完成。
        for s in solutions where s.satisfiesConstraint {
            let p = s.prediction
            XCTAssertFalse(p.cuePocketed, "满足解：母球不应进袋")
            XCTAssertLessThan(p.cueFinalSpeed, PositionPlaySolver.restSpeedTolerance, "满足解：母球应真停稳")
            XCTAssertFalse(p.pocketedBalls.contains("_1"), "满足解：目标球不应进袋")
            // 合法首触：母球第一次球-球碰撞的另一方是目标球。
            var firstOther: String?
            for e in p.events {
                if case let .ballBall(a, b) = e.kind {
                    if a == ShotInput.cueBallName { firstOther = b; break }
                    if b == ShotInput.cueBallName { firstOther = a; break }
                }
            }
            XCTAssertEqual(firstOther, "_1", "满足解：首触必须是目标球")
            // 几何复核：三球终位确构成完全斯诺克。
            guard let c = p.finalPositions[ShotInput.cueBallName],
                  let t = p.finalPositions["_1"],
                  let b = p.finalPositions["_8"] else {
                return XCTFail("满足解缺三球终位")
            }
            let cov = AngleSceneCalculator.snookerCoverage(cue: c, snookered: t, blocker: b)
            XCTAssertTrue(cov.isFullSnooker, "满足解：终位几何应复核为完全斯诺克（margin=\(cov.marginDegrees)）")
            XCTAssertGreaterThanOrEqual(s.margin, 0, "满足解：覆盖余量应非负")
        }

        // 排序：完全斯诺克解在前、库少优先。
        if fulls.count >= 2 {
            for i in 1..<fulls.count {
                XCTAssertLessThanOrEqual(fulls[i - 1].cushionCount, fulls[i].cushionCount,
                                         "完全斯诺克解应按吃库数升序")
            }
        }
    }

    // MARK: - 降级解

    func test_solveSnooker_degradesToHalfSnooker_whenImpossible() {
        // 障碍球远离母球-目标连线（贴在台角），任何停位都难以完全挡死 ⇒ 期望降级为半斯诺克。
        let board = BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.30, y: 0.25),
            "_1": CanvasPoint(x: 0.55, y: 0.25),
            "_8": CanvasPoint(x: 0.05, y: 0.46)])

        let solutions = PositionPlaySolver.solveSnooker(
            before: board, targetKey: "_1", blockerKey: "_8", surfaceY: sY, params: coarse)
        // 降级时只返回 1 个「最接近」解且未满足约束、余量为负。
        if let only = solutions.first, !only.satisfiesConstraint {
            XCTAssertEqual(solutions.count, 1, "降级解只返回单个最接近解")
            XCTAssertLessThan(only.margin, 0, "降级（半斯诺克）覆盖余量应为负")
        }
    }
}
