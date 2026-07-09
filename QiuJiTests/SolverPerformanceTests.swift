//
//  SolverPerformanceTests.swift
//  QiuJiTests
//
//  B0 — 反解求解器性能基线（docs/research/20260708-反解求解器性能优化方案.md §3 B0）。
//
//  四条路径各一条独立墙钟 benchmark + 分段计时（PerformanceProfiler 采样标签）：
//  - 情形 A 落区 .standard：带精修 / 不带精修各测一次；
//  - 情形 B 过点 .passThrough；
//  - 做斯诺克 solveSnooker .standard（此前无基线，本文件补）；
//  - 批量出片 BatchShotSolver 等价调用（.standard + 多障碍球盘面，BatchAuthoringView L165 同参数）。
//
//  断言只防卡死（<120s），不是性能闸门——目的是产出可复核、可对比的基线数字。
//  分段口径（均为 DEBUG 采样标签，Release 无插桩）：
//  - Solver.aimMemoization / Solver.candidateEval：candidateMatrix ①②外层墙钟；
//  - Solver.refine：每桶代表解精修（顺序调用，墙钟）；
//  - Solver.passInfo：情形 B 过点回放采样（顺序调用，墙钟）；
//  - Predictor.runShot / Predictor.simulateFree.engine：单次引擎模拟（并行累计 = CPU 时间）；
//  - Predictor.postProcess：buildPrediction/simulateFree 后处理 polyline 等（并行累计 = CPU 时间）。
//  注意：Physics.* 旧标签用 begin/end，在并行热点下计时互相覆盖，数字不可信，忽略即可。
//

import XCTest
import SceneKit
@testable import QiuJi

final class SolverPerformanceTests: XCTestCase {

    private let sY = BTTablePhysics.surfaceY

    override func setUp() {
        super.setUp()
        PerformanceProfiler.reset()
    }

    /// 打印分段报告（只保留本轮基线关心的 Solver.* / Predictor.* 采样标签）。
    private func printSegments(_ tag: String) {
        let report = PerformanceProfiler.reportText()
        let relevant = report
            .split(separator: "\n")
            .filter { $0.contains("Solver.") || $0.contains("Predictor.") || $0.contains("区段") }
            .joined(separator: "\n")
        print("📊 [PERF-SEG] \(tag)\n\(relevant)")
    }

    // MARK: - 情形 A：落区（生产参数 .standard，带/不带精修）

    /// 与 `PositionPlaySolverTests.test_perf_productionParams_printsWallClock` 同盘面，
    /// 但拆出「带精修 / 不带精修」两个口径并打分段占比。
    func test_perf_caseA_restRegion_standard() {
        let before = BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.5, y: 0.35),
            "_1": CanvasPoint(x: 0.5, y: 0.15)
        ])
        let region = SolveRegion.circle(center: CanvasPoint(x: 0.5, y: 0.25), radius: 0.4)

        // ① 不带精修。
        var noRefine = PositionPlaySolver.SearchParams.standard
        noRefine.refineEnabled = false
        PerformanceProfiler.reset()
        let t0 = Date()
        let sols0 = PositionPlaySolver.solve(
            before: before, targetKey: "_1", pocket: "topCenter",
            constraint: .restRegion(region), surfaceY: sY, params: noRefine)
        let e0 = Date().timeIntervalSince(t0)
        print("⏱️ [PERF-B0] 情形A 落区 .standard 无精修 = \(String(format: "%.2f", e0))s，解数=\(sols0.count)")
        printSegments("情形A 无精修")

        // ② 带精修（生产默认）。
        PerformanceProfiler.reset()
        let t1 = Date()
        let sols1 = PositionPlaySolver.solve(
            before: before, targetKey: "_1", pocket: "topCenter",
            constraint: .restRegion(region), surfaceY: sY, params: .standard)
        let e1 = Date().timeIntervalSince(t1)
        print("⏱️ [PERF-B0] 情形A 落区 .standard 带精修 = \(String(format: "%.2f", e1))s，解数=\(sols1.count)")
        printSegments("情形A 带精修")

        XCTAssertFalse(sols1.isEmpty, "生产参数下应有解")
        XCTAssertLessThan(e0, 120, "情形A（无精修）不应卡死")
        XCTAssertLessThan(e1, 120, "情形A（带精修）不应卡死")
    }

    // MARK: - 情形 B：过点（生产参数 .passThrough）

    func test_perf_caseB_passThrough_standard() {
        let before = BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.5, y: 0.35),
            "_1": CanvasPoint(x: 0.5, y: 0.15)
        ])
        let pPoint = CanvasPoint(x: 0.5, y: 0.0925)

        PerformanceProfiler.reset()
        let t0 = Date()
        let sols = PositionPlaySolver.solve(
            before: before, targetKey: "_1", pocket: "topCenter",
            constraint: .passThrough(point: pPoint, vMin: 0.3), surfaceY: sY, params: .passThrough)
        let e = Date().timeIntervalSince(t0)
        print("⏱️ [PERF-B0] 情形B 过点 .passThrough = \(String(format: "%.2f", e))s，解数=\(sols.count)")
        printSegments("情形B 过点")

        XCTAssertFalse(sols.isEmpty, "生产参数下应有解")
        XCTAssertLessThan(e, 120, "情形B 不应卡死")
    }

    // MARK: - 做斯诺克：solveSnooker（生产参数 .standard，此前无基线）

    /// 盘面取 `SnookerSolverTests.test_solveSnooker_satisfyingSolutions_passReCheck` 的
    /// 金标准球形（确证能求出完全斯诺克解），但参数用**生产默认** `SnookerParams.standard`
    /// （21 瞄准 × 15 塞 × 12 力度 ≈ 3780 次全场 simulateFree）。
    func test_perf_snooker_standard() {
        let board = BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.30, y: 0.25),
            "_1": CanvasPoint(x: 0.55, y: 0.25),
            "_8": CanvasPoint(x: 0.50, y: 0.22)])

        PerformanceProfiler.reset()
        let t0 = Date()
        let sols = PositionPlaySolver.solveSnooker(
            before: board, targetKey: "_1", blockerKey: "_8", surfaceY: sY, params: .standard)
        let e = Date().timeIntervalSince(t0)
        print("⏱️ [PERF-B0] 斯诺克 solveSnooker .standard = \(String(format: "%.2f", e))s，解数=\(sols.count)")
        printSegments("斯诺克")

        XCTAssertFalse(sols.isEmpty, "金标准球形应有解")
        XCTAssertLessThan(e, 120, "斯诺克求解不应卡死")
    }

    // MARK: - 批量出片：BatchShotSolver 等价调用（多障碍球盘面）

    /// `BatchShotSolver.solve` 的核心即 `PositionPlaySolver.solve(.standard, maxCushions: nil)`
    /// （BatchAuthoringView.searchParams L165）。批量出片场景区别于上面两球盘面的是**在桌球多**
    /// （drill 截图导入的真实局面），障碍球会进引擎作碰撞体、显著抬高单次模拟成本 ⇒ 单独立基线。
    func test_perf_batchLikeBoard_restRegion() {
        // 8 球盘面：母球 + 目标球 + 6 颗障碍球（散布避开进球线，模拟 drill 中局）。
        let before = BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.50, y: 0.35),
            "_1": CanvasPoint(x: 0.50, y: 0.15),
            "_2": CanvasPoint(x: 0.25, y: 0.30),
            "_3": CanvasPoint(x: 0.75, y: 0.28),
            "_4": CanvasPoint(x: 0.32, y: 0.12),
            "_5": CanvasPoint(x: 0.68, y: 0.40),
            "_6": CanvasPoint(x: 0.15, y: 0.20),
            "_8": CanvasPoint(x: 0.85, y: 0.15)
        ])
        let region = SolveRegion.circle(center: CanvasPoint(x: 0.5, y: 0.28), radius: 0.12)

        PerformanceProfiler.reset()
        let t0 = Date()
        let sols = PositionPlaySolver.solve(
            before: before, targetKey: "_1", pocket: "topCenter",
            constraint: .restRegion(region), surfaceY: sY, params: .standard)
        let e = Date().timeIntervalSince(t0)
        print("⏱️ [PERF-B0] 批量出片等价盘面（8 球 + 落区）= \(String(format: "%.2f", e))s，解数=\(sols.count)")
        printSegments("批量出片等价盘面")

        XCTAssertLessThan(e, 120, "批量出片盘面求解不应卡死")
    }

    // MARK: - W1 翻袋引擎反解（单袋全枚举口径，目标：典型 ≤0.5s / 最坏 ≤1s，以实测为准）

    /// 翻袋反解「单袋全枚举」：对指定袋口枚举全部 1–3 库合法库序（28 条），逐条走
    /// 四层管线（`ShotPredictor.predict` bank 分支）。这正是 W3 UI 单次求解的口径。
    private func bankSolveAllSequences(
        cue: SCNVector3, target: SCNVector3, pocketIndex: Int, velocity: Float,
        obstacles: [ObstacleBall] = []
    ) -> Int {
        var potted = 0
        for rails in BankShotCalculator.candidateRailSequences(maxCushions: 3) {
            let pred = ShotPredictor.predict(ShotInput(
                cueBall: cue, targetBall: target, pocketIndex: pocketIndex,
                velocity: velocity, spinX: 0, spinY: 0, surfaceY: sY,
                obstacles: obstacles, bankRails: rails))
            if pred.feasible, pred.simObjectPotted { potted += 1 }
        }
        return potted
    }

    /// 典型盘面：两球中台、无障碍，单袋（右下角袋）全枚举。
    func test_perf_bankSolve_typicalBoard_singlePocket() {
        let cue = SCNVector3(-0.5, sY + BallPhysics.radius, -0.2)
        let target = SCNVector3(0.1, sY + BallPhysics.radius, 0.1)

        PerformanceProfiler.reset()
        let t0 = Date()
        let potted = bankSolveAllSequences(cue: cue, target: target, pocketIndex: 1, velocity: 3.6)
        let e = Date().timeIntervalSince(t0)
        print("⏱️ [PERF-W1] 翻袋典型盘面 单袋全枚举（28 库序）= \(String(format: "%.3f", e))s，进袋解=\(potted)")
        printSegments("翻袋典型盘面")

        XCTAssertGreaterThan(potted, 0, "典型盘面应有翻袋解")
        XCTAssertLessThan(e, 120, "翻袋求解不应卡死")
    }

    /// 最坏侧盘面：目标球近库 + 4 颗障碍球（歧义回退引擎的比例升高），单袋全枚举。
    func test_perf_bankSolve_worstBoard_obstacles() {
        let cue = SCNVector3(0.6, sY + BallPhysics.radius, 0.35)
        let target = SCNVector3(-0.8, sY + BallPhysics.radius, -0.5)
        let obstacles = [
            ObstacleBall(name: "_2", position: SCNVector3(-0.3, sY + BallPhysics.radius, -0.1)),
            ObstacleBall(name: "_3", position: SCNVector3(0.0, sY + BallPhysics.radius, 0.3)),
            ObstacleBall(name: "_4", position: SCNVector3(-0.6, sY + BallPhysics.radius, 0.2)),
            ObstacleBall(name: "_5", position: SCNVector3(0.3, sY + BallPhysics.radius, -0.35))
        ]

        PerformanceProfiler.reset()
        let t0 = Date()
        let potted = bankSolveAllSequences(
            cue: cue, target: target, pocketIndex: 1, velocity: 4.2, obstacles: obstacles)
        let e = Date().timeIntervalSince(t0)
        print("⏱️ [PERF-W1] 翻袋最坏侧盘面（近库 + 4 障碍）单袋全枚举 = \(String(format: "%.3f", e))s，进袋解=\(potted)")
        printSegments("翻袋最坏侧盘面")

        XCTAssertLessThan(e, 120, "翻袋最坏盘面求解不应卡死")
    }

    // MARK: - W2 反射/kick 引擎反解（全枚举口径，目标：≤0.3s，以实测为准）

    /// kick 反解「全枚举」：全部 1–3 库合法库序（28 条）经 `ShotPredictor.predictKickAll`
    /// 并行走四层管线。这正是 W3 反射页 UI 单次求解的口径（生产同一入口）。
    private func kickSolveAllSequences(
        cue: SCNVector3, target: SCNVector3, velocity: Float,
        obstacles: [ObstacleBall] = []
    ) -> Int {
        ShotPredictor.predictKickAll(ShotInput(
            cueBall: cue, targetBall: target, pocketIndex: 0,
            velocity: velocity, spinX: 0, spinY: 0, surfaceY: sY,
            obstacles: obstacles)).count
    }

    /// 典型解球盘面：两球中台、无障碍，1–3 库全枚举。
    func test_perf_kickSolve_typicalBoard() {
        let cue = SCNVector3(-0.5, sY + BallPhysics.radius, -0.2)
        let target = SCNVector3(0.4, sY + BallPhysics.radius, 0.25)

        PerformanceProfiler.reset()
        let t0 = Date()
        let contacted = kickSolveAllSequences(cue: cue, target: target, velocity: 3.6)
        let e = Date().timeIntervalSince(t0)
        print("⏱️ [PERF-W2] 反射典型盘面 全枚举（28 库序）= \(String(format: "%.3f", e))s，碰到解=\(contacted)")
        printSegments("反射典型盘面")

        XCTAssertGreaterThan(contacted, 0, "典型盘面应有 kick 解")
        XCTAssertLessThan(e, 120, "kick 求解不应卡死")
    }

    /// 最坏侧盘面：被障碍球半包围的解球局（歧义回退比例升高），1–3 库全枚举。
    func test_perf_kickSolve_worstBoard_obstacles() {
        let cue = SCNVector3(0.6, sY + BallPhysics.radius, 0.35)
        let target = SCNVector3(-0.8, sY + BallPhysics.radius, -0.5)
        let obstacles = [
            ObstacleBall(name: "_2", position: SCNVector3(-0.55, sY + BallPhysics.radius, -0.3)),
            ObstacleBall(name: "_3", position: SCNVector3(-0.3, sY + BallPhysics.radius, -0.45)),
            ObstacleBall(name: "_4", position: SCNVector3(0.0, sY + BallPhysics.radius, 0.1)),
            ObstacleBall(name: "_5", position: SCNVector3(-0.2, sY + BallPhysics.radius, 0.25))
        ]

        PerformanceProfiler.reset()
        let t0 = Date()
        let contacted = kickSolveAllSequences(
            cue: cue, target: target, velocity: 4.2, obstacles: obstacles)
        let e = Date().timeIntervalSince(t0)
        print("⏱️ [PERF-W2] 反射最坏侧盘面（障碍半包围）全枚举 = \(String(format: "%.3f", e))s，碰到解=\(contacted)")
        printSegments("反射最坏侧盘面")

        XCTAssertLessThan(e, 120, "kick 最坏盘面求解不应卡死")
    }
}
