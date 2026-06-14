//
//  PositionPlaySolverTests.swift
//  QiuJiTests
//
//  走位反解器（思路训练器，ADR-P13-01）：
//  - 落区有符号距离 SDF 金标准（确定性，禁止脑算 → 数值验证）。
//  - 情形 A（落区）：可落区解 + 进袋硬约束 + 库少优先排序 + 无解最接近降级。
//  - 情形 B（K 球过点）：求得速度分段且代表解母球确经过 P。
//
//  坐标契约（代码真源 `AngleSceneCalculator`）：归一化 x∈[0,1] 右增、y∈[0,0.5] 下增；
//  normalizedToScene：x→sceneX（×innerLength）、y→sceneZ（×2·innerWidth）。两轴缩放均 2.54m（均匀）。
//

import XCTest
import SceneKit
@testable import QiuJi

final class PositionPlaySolverTests: XCTestCase {

    private let sY = BTTablePhysics.surfaceY
    private var R: Float { AngleSceneCalculator.ballRadius }

    /// 测试用粗网格（提速）。
    private var coarse: PositionPlaySolver.SearchParams {
        PositionPlaySolver.SearchParams(
            spinXValues: [-0.3, 0, 0.3],
            spinYValues: [-0.3, 0, 0.3],
            velocityMin: 1.0, velocityMax: 5.0, velocityStep: 1.0,
            marginBase: 0.0, marginPerCushion: 0.04,
            passTolerance: 2 * AngleSceneCalculator.ballRadius, passMinSpeed: 0.2
        )
    }

    // MARK: - 落区 SDF 金标准（确定性）

    func test_region_circle_signedDistance_goldenSamples() {
        // 中心 norm(0.5,0.25)→scene(0,0)；半径 norm 0.1 → scene 0.254m（均匀缩放 ×2.54）。
        let region = SolveRegion.circle(center: CanvasPoint(x: 0.5, y: 0.25), radius: 0.1)
        let scale = AngleSceneCalculator.innerLength
        XCTAssertEqual(Double(SolveRegion.sceneScale), Double(scale), accuracy: 1e-6)

        // 圆心：signed = -radius。
        let atCenter = region.signedDistanceMeters(fromScene: SCNVector3(0, sY, 0), surfaceY: sY)
        XCTAssertEqual(atCenter, -0.1 * scale, accuracy: 1e-4)
        // 边界上：signed ≈ 0。
        let onEdge = region.signedDistanceMeters(fromScene: SCNVector3(0.1 * scale, sY, 0), surfaceY: sY)
        XCTAssertEqual(onEdge, 0, accuracy: 1e-4)
        // 区外 0.5m：signed = 0.5 - 0.254。
        let outside = region.signedDistanceMeters(fromScene: SCNVector3(0.5, sY, 0), surfaceY: sY)
        XCTAssertEqual(outside, 0.5 - 0.1 * scale, accuracy: 1e-4)
        XCTAssertTrue(region.contains(scene: SCNVector3(0.05, sY, 0), surfaceY: sY))
        XCTAssertFalse(region.contains(scene: SCNVector3(0.5, sY, 0), surfaceY: sY))
    }

    func test_region_rect_signedDistance_goldenSamples() {
        // 中心 scene(0,0)；半宽 norm0.1→0.254m(X)、半高 norm0.05→0.127m(Z)。
        let region = SolveRegion.rect(center: CanvasPoint(x: 0.5, y: 0.25),
                                      halfWidth: 0.1, halfHeight: 0.05)
        let scale = AngleSceneCalculator.innerLength
        // 中心：signed = -min(hw,hh) = -0.127。
        let c = region.signedDistanceMeters(fromScene: SCNVector3(0, sY, 0), surfaceY: sY)
        XCTAssertEqual(c, -0.05 * scale, accuracy: 1e-4)
        // X 方向区外：dx=0.3-0.254=0.046，dz<0 ⇒ signed=0.046。
        let outX = region.signedDistanceMeters(fromScene: SCNVector3(0.3, sY, 0), surfaceY: sY)
        XCTAssertEqual(outX, 0.3 - 0.1 * scale, accuracy: 1e-4)
        // 对角外：dx=0.046, dz=0.2-0.127=0.073 ⇒ signed=hypot。
        let diag = region.signedDistanceMeters(fromScene: SCNVector3(0.3, sY, 0.2), surfaceY: sY)
        XCTAssertEqual(diag, hypotf(0.3 - 0.1 * scale, 0.2 - 0.05 * scale), accuracy: 1e-4)
    }

    // MARK: - 情形 A：落区

    func test_restRegion_pottable_landsInRegion_andSorted() {
        // 直球：cue 下、target 上、上中袋，沿 -Z 直线进袋。落区 = 覆盖大半台面的大圆。
        let before = BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.5, y: 0.35),
            "_1": CanvasPoint(x: 0.5, y: 0.15)
        ])
        let region = SolveRegion.circle(center: CanvasPoint(x: 0.5, y: 0.25), radius: 0.4)
        let solutions = PositionPlaySolver.solve(
            before: before, targetKey: "_1", pocket: "topCenter",
            constraint: .restRegion(region), surfaceY: sY, params: coarse)

        XCTAssertFalse(solutions.isEmpty, "应至少有一个解")
        // 库少优先：cushionCount 非降序。
        for i in 1..<max(1, solutions.count) {
            XCTAssertLessThanOrEqual(solutions[i - 1].cushionCount, solutions[i].cushionCount,
                                     "解列表应按吃库数升序（库少优先）")
        }
        // 至少一个满足约束的解：进袋 + 停点在区内 + 余量非负。
        let satisfied = solutions.filter { $0.satisfiesConstraint }
        XCTAssertFalse(satisfied.isEmpty, "大落区下应有满足约束的解")
        for s in satisfied {
            XCTAssertTrue(s.potted, "满足约束的解必进袋（硬约束）")
            XCTAssertGreaterThanOrEqual(s.margin, -1e-4, "区内解余量应非负")
            // 复核：停点确在落区内。
            if let stop = s.prediction.finalPositions[ShotInput.cueBallName] {
                XCTAssertTrue(region.contains(scene: stop, surfaceY: sY), "停点应落在落区内")
            }
        }
    }

    func test_restRegion_unreachable_returnsClosestDegraded() {
        // 落区放在台面外（norm x=1.5），母球永远停不进去 ⇒ 必走最接近降级。
        let before = BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.5, y: 0.35),
            "_1": CanvasPoint(x: 0.5, y: 0.15)
        ])
        let region = SolveRegion.circle(center: CanvasPoint(x: 1.5, y: 0.25), radius: 0.02)
        let solutions = PositionPlaySolver.solve(
            before: before, targetKey: "_1", pocket: "topCenter",
            constraint: .restRegion(region), surfaceY: sY, params: coarse)

        XCTAssertEqual(solutions.count, 1, "无可行解时应返回单个最接近降级解")
        XCTAssertFalse(solutions[0].satisfiesConstraint, "降级解不满足约束")
        XCTAssertLessThan(solutions[0].margin, 0, "区外降级解余量为负")
    }

    // MARK: - 情形 B：K 球过点

    func test_passThrough_findsSegment_cuePassesPoint() {
        // 直球进上中袋；P 置于目标球与袋口之间的进球延长线上。跟杆使母球过 P。
        let before = BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.5, y: 0.35),
            "_1": CanvasPoint(x: 0.5, y: 0.15)
        ])
        // P：target(scene z=-0.254) 与 上中袋(z≈-0.688) 之间，z=-0.4 → norm y=(−0.4+0.635)/2.54≈0.0925。
        let pPoint = CanvasPoint(x: 0.5, y: 0.0925)
        let params = PositionPlaySolver.SearchParams(
            spinXValues: [-0.3, 0, 0.3],
            spinYValues: [-0.3, 0, 0.3],
            velocityMin: 1.0, velocityMax: 5.0, velocityStep: 0.5,
            marginBase: 0.0, marginPerCushion: 0.04,
            passTolerance: 2 * AngleSceneCalculator.ballRadius, passMinSpeed: 0.2)

        let solutions = PositionPlaySolver.solve(
            before: before, targetKey: "_1", pocket: "topCenter",
            constraint: .passThrough(point: pPoint, vMin: 0.3), surfaceY: sY, params: params)

        XCTAssertFalse(solutions.isEmpty, "跟杆直球应能求得过 P 的速度分段")
        // 库少优先排序。
        for i in 1..<max(1, solutions.count) {
            XCTAssertLessThanOrEqual(solutions[i - 1].cushionCount, solutions[i].cushionCount)
        }
        // 代表解：进袋 + 母球轨迹确经过 P（容差内）。
        let pScene = PositionPlaySolver.scenePoint(pPoint, surfaceY: sY)
        let best = solutions[0]
        XCTAssertTrue(best.potted, "过点解仍需进选定袋（硬约束）")
        let path = best.prediction.cuePath
        var minD = Float.greatestFiniteMagnitude
        for i in 0..<max(1, path.count - 1) where path.count >= 2 {
            minD = min(minD, ShotPredictor.segmentPointDistanceXZ(a: path[i], b: path[i + 1], p: pScene))
        }
        XCTAssertLessThan(minD, params.passTolerance + 1e-3, "代表解母球轨迹应在容差内经过 P")
    }

    // MARK: - 快速路径正确性：predictForPositionSolve 黄金分割瞄准 == predict 网格瞄准

    /// 走位反解快速路径（黄金分割轻量瞄准）与共享 `predict`（三级网格瞄准）在进袋判定上必须一致——
    /// 这是「内层瞄准提速但不改物理/不漏不误」的硬校验（ADR-P13-01）。
    func test_fastPath_matchesPredict_potOutcome() {
        let cue = PositionPlaySolver.scenePoint(CanvasPoint(x: 0.5, y: 0.35), surfaceY: sY)
        let target = PositionPlaySolver.scenePoint(CanvasPoint(x: 0.5, y: 0.15), surfaceY: sY)
        guard let pocketIndex = ShotIntent.pocketIndex(for: "topCenter") else {
            return XCTFail("topCenter 袋口非法")
        }
        let spins: [(Float, Float)] = [(0, 0), (0.3, 0), (-0.3, 0), (0, 0.4), (0, -0.4), (0.3, 0.3), (-0.3, -0.3)]
        let velocities: [Float] = [1.5, 2.5, 3.5, 4.5]
        var compared = 0
        for (sx, sy) in spins {
            for v in velocities {
                let input = ShotInput(cueBall: cue, targetBall: target, pocketIndex: pocketIndex,
                                      velocity: v, spinX: sx, spinY: sy, surfaceY: sY, obstacles: [])
                let ref = ShotPredictor.predict(input)
                let fast = ShotPredictor.predictForPositionSolve(input)
                XCTAssertEqual(ref.feasible, fast.feasible, "可行性应一致 spin(\(sx),\(sy)) v\(v)")
                guard ref.feasible else { continue }
                XCTAssertEqual(ref.objectPocketed, fast.objectPocketed,
                               "进袋判定应一致 spin(\(sx),\(sy)) v\(v)")
                // 都进袋且吃库结构相同时，母球停点应接近（黄金分割 0.05° vs 网格 0.02°）。
                if ref.objectPocketed, fast.objectPocketed,
                   ref.cueCushionCount == fast.cueCushionCount,
                   let rc = ref.finalPositions[ShotInput.cueBallName],
                   let fc = fast.finalPositions[ShotInput.cueBallName] {
                    let d = AngleSceneCalculator.horizontalDistance(rc, fc)
                    XCTAssertLessThan(d, 0.2, "同库结构下母球停点应接近 spin(\(sx),\(sy)) v\(v)：差 \(d)m")
                }
                compared += 1
            }
        }
        XCTAssertGreaterThan(compared, 0, "应至少比对一组")
    }

    // MARK: - 真实耗时测量（生产网格 + 并行）

    /// 用 App 实际生产参数测两类求解的真实墙钟耗时，并打印到测试日志。
    /// 断言放宽（仅防卡死），目的是给「求解要多久」一个可复核的数字，而非性能闸门。
    func test_perf_productionParams_printsWallClock() {
        let before = BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.5, y: 0.35),
            "_1": CanvasPoint(x: 0.5, y: 0.15)
        ])

        let region = SolveRegion.circle(center: CanvasPoint(x: 0.5, y: 0.25), radius: 0.4)
        let t0 = Date()
        let aSolutions = PositionPlaySolver.solve(
            before: before, targetKey: "_1", pocket: "topCenter",
            constraint: .restRegion(region), surfaceY: sY, params: .standard)
        let aElapsed = Date().timeIntervalSince(t0)
        print("⏱️ [PERF] 情形A 落区 .standard（285 候选 + 57 记忆化瞄准，并行）= \(String(format: "%.2f", aElapsed))s，解数=\(aSolutions.count)")

        let pPoint = CanvasPoint(x: 0.5, y: 0.0925)
        let t1 = Date()
        let bSolutions = PositionPlaySolver.solve(
            before: before, targetKey: "_1", pocket: "topCenter",
            constraint: .passThrough(point: pPoint, vMin: 0.3), surfaceY: sY, params: .passThrough)
        let bElapsed = Date().timeIntervalSince(t1)
        print("⏱️ [PERF] 情形B 过点 .passThrough（9 combo × 37 vel 候选 + 记忆化瞄准，并行）= \(String(format: "%.2f", bElapsed))s，解数=\(bSolutions.count)")

        XCTAssertLessThan(aElapsed, 120, "情形A 求解不应卡死")
        XCTAssertLessThan(bElapsed, 120, "情形B 求解不应卡死")
    }
}
