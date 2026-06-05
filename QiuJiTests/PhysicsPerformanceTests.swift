import XCTest
import SceneKit
@testable import QiuJi

/// 物理求解性能门槛（D-C4）。
///
/// 此前 predict 性能（单杆 ~150–200ms、满台数百 ms）仅在 `PROGRESS.md` 口头记录，无自动断言；
/// 后续任何改动若拖慢求解（如提高搜索保真度、增加事件数）都无 CI 告警。本套件钉死**绝对预算**
/// 上限，捕获数量级回归（而非微基准）。预算取得**宽松**以容忍 CI/模拟器机器抖动；同时打印实测
/// 中位数，便于人工据真实硬件逐步收紧。
///
/// 注：阈值偏宽是有意的——目标是「不让一次重构把单杆求解从 200ms 拖到 1s+ 而无人察觉」，
/// 而非精确测速。真要做微基准请在固定真机上跑 `measure {}` 指标。
final class PhysicsPerformanceTests: XCTestCase {

    private let R = BallPhysics.radius
    private var surfaceY: Float { BTTablePhysics.surfaceY }

    /// 单杆 predict（典型可进球形）中位耗时应在预算内。
    func test_perf_singlePredict_withinBudget() {
        let sY = surfaceY
        let input = ShotInput(
            cueBall: SCNVector3(-0.2, sY + R, 0.0),
            targetBall: SCNVector3(0.4, sY + R, 0.0),
            pocketIndex: 1, velocity: 3.3, spinX: 0, spinY: 0, surfaceY: sY)
        let median = medianPredictMs(input, warmup: 2, samples: 7)
        let budgetMs: Double = 800
        print(String(format: "[PERF-single] 单杆 predict 中位 %.0fms（预算 %.0fms，PROGRESS 记录 ~150–200ms）", median, budgetMs))
        XCTAssertLessThan(median, budgetMs, "单杆 predict 中位 \(median)ms 超预算 \(budgetMs)ms（疑似性能回归）")
    }

    /// 满台 predict（母球 + 8 障碍球，走位编排器场景）中位耗时应在预算内。
    func test_perf_fullTablePredict_withinBudget() {
        let sY = surfaceY
        let obstacleSpots: [SCNVector3] = [
            SCNVector3(-0.6, sY + R, 0.30), SCNVector3(-0.3, sY + R, -0.25),
            SCNVector3(0.1, sY + R, 0.40), SCNVector3(0.7, sY + R, 0.20),
            SCNVector3(0.9, sY + R, -0.30), SCNVector3(-0.9, sY + R, -0.10),
            SCNVector3(0.5, sY + R, -0.45), SCNVector3(-0.1, sY + R, -0.50),
        ]
        let obstacles = obstacleSpots.enumerated().map { ObstacleBall(name: "_\($0.offset + 1)", position: $0.element) }
        let input = ShotInput(
            cueBall: SCNVector3(-0.4, sY + R, 0.0),
            targetBall: SCNVector3(0.3, sY + R, 0.05),
            pocketIndex: 1, velocity: 3.3, spinX: 0, spinY: 0, surfaceY: sY,
            obstacles: obstacles)
        let median = medianPredictMs(input, warmup: 1, samples: 5)
        let budgetMs: Double = 3000
        print(String(format: "[PERF-fulltable] 满台(母球+8障碍) predict 中位 %.0fms（预算 %.0fms）", median, budgetMs))
        XCTAssertLessThan(median, budgetMs, "满台 predict 中位 \(median)ms 超预算 \(budgetMs)ms")
    }

    /// Xcode 性能指标基线（供本地/真机回归对比，不设硬阈值，仅记录）。
    func test_perf_singlePredict_measureMetric() {
        let sY = surfaceY
        let input = ShotInput(
            cueBall: SCNVector3(-0.2, sY + R, 0.0),
            targetBall: SCNVector3(0.4, sY + R, 0.0),
            pocketIndex: 1, velocity: 3.3, spinX: 0, spinY: 0, surfaceY: sY)
        measure { _ = ShotPredictor.predict(input) }
    }

    // MARK: - Helpers

    private func medianPredictMs(_ input: ShotInput, warmup: Int, samples: Int) -> Double {
        for _ in 0..<warmup { _ = ShotPredictor.predict(input) }
        var times: [Double] = []
        for _ in 0..<samples {
            let t0 = CFAbsoluteTimeGetCurrent()
            _ = ShotPredictor.predict(input)
            times.append((CFAbsoluteTimeGetCurrent() - t0) * 1000)
        }
        times.sort()
        return times[times.count / 2]
    }
}
