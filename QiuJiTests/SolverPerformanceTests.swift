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
}
