//
//  AnalyticAimParityTests.swift
//  QiuJiTests
//
//  B2 — 解析瞄准层对拍验证（先于替换线上路径，方案 §3 B2「对拍验证先行」）。
//
//  两层对拍：
//  1. **评分函数层**：同一 (input, offset) 上 `positionAimScoreAnalytic` vs
//     `positionAimScore`（整程模拟口径）逐点比较——偏差直接反映解析模型 vs
//     引擎模拟的物理保真差，与搜索方法无关（归因的最小单元）。
//  2. **求解结果层**：`positionAimOffsetAnalytic` vs `positionAimOffset`（同为
//     黄金分割、同括号同容差）在随机盘面 × 力度 × 塞的 aimOffset 偏差分布；
//     偏差 > 0.05° 的案例用「模拟评分交叉裁判」归因——用**模拟自己的评分**评
//     解析解，若解析解不劣（regret ≈ 0），则偏差来自评分景观的平坦谷底/孪生
//     极小，无物理危害；若 regret 显著，才是解析模型失真，逐案打印归因。
//
//  坐标契约：canvas 归一化 x∈[0,1]→场景X，y∈[0,0.5]→场景Z（origin 左上、Y 向下）。
//

import XCTest
import SceneKit
@testable import QiuJi

final class AnalyticAimParityTests: XCTestCase {

    private let sY = BTTablePhysics.surfaceY
    private let deg = Float.pi / 180

    private func scene(_ x: Double, _ y: Double) -> SCNVector3 {
        PositionPlaySolver.scenePoint(CanvasPoint(x: x, y: y), surfaceY: sY)
    }

    /// 确定性 RNG（SplitMix64）：随机抽样可复现，偏差案例可回放归因。
    private struct SplitMix64: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    private struct Scenario {
        let input: ShotInput
        let ctx: ShotPredictor.AimContext
        let tag: String
    }

    /// 随机生成可行盘面（prepareAim 闸门通过）：位置全幅覆盖（含近库），
    /// 力度 0.9–5.4，spinX ∈ ±0.6，spinY ∈ ±0.5，约 1/3 案例带 2–4 颗障碍球。
    private func makeScenarios(count: Int, seed: UInt64) -> [Scenario] {
        var rng = SplitMix64(state: seed)
        var out: [Scenario] = []
        var attempts = 0
        while out.count < count && attempts < count * 40 {
            attempts += 1
            let cue = scene(Double.random(in: 0.05...0.95, using: &rng),
                            Double.random(in: 0.05...0.45, using: &rng))
            let target = scene(Double.random(in: 0.05...0.95, using: &rng),
                               Double.random(in: 0.05...0.45, using: &rng))
            // 母球-目标球至少隔 3 个球径，避免贴脸摆位的退化盘面。
            guard cue.distanceXZ(to: target) > 6 * BallPhysics.radius else { continue }

            var obstacles: [ObstacleBall] = []
            if Int.random(in: 0..<3, using: &rng) == 0 {
                let n = Int.random(in: 2...4, using: &rng)
                for i in 0..<n {
                    let p = scene(Double.random(in: 0.05...0.95, using: &rng),
                                  Double.random(in: 0.05...0.45, using: &rng))
                    guard p.distanceXZ(to: cue) > 3 * BallPhysics.radius,
                          p.distanceXZ(to: target) > 3 * BallPhysics.radius else { continue }
                    obstacles.append(ObstacleBall(name: "_\(i + 2)", position: p))
                }
            }

            let pocketIndex = Int.random(in: 0...5, using: &rng)
            let velocity = Float.random(in: 0.9...5.4, using: &rng)
            let spinX = Float.random(in: -0.6...0.6, using: &rng)
            let spinY = Float.random(in: -0.5...0.5, using: &rng)

            let input = ShotInput(
                cueBall: cue, targetBall: target, pocketIndex: pocketIndex,
                velocity: velocity, spinX: spinX, spinY: spinY,
                surfaceY: sY, obstacles: obstacles
            )
            var result = ShotPrediction()
            guard let ctx = ShotPredictor.prepareAim(input, into: &result) else { continue }
            let tag = String(
                format: "#%d cue=(%.3f,%.3f) tgt=(%.3f,%.3f) pkt=%d v=%.2f sx=%.2f sy=%.2f obs=%d",
                out.count, cue.x, cue.z, target.x, target.z,
                pocketIndex, velocity, spinX, spinY, obstacles.count
            )
            out.append(Scenario(input: input, ctx: ctx, tag: tag))
        }
        return out
    }

    /// 第 1 层：评分函数逐点对拍。对每个盘面在括号内扫固定 offset 网格，
    /// 两套评分同为有效候选时角度误差应对齐；有效性判定（命中/碰前吃库）应一致。
    func test_scoreFunction_pointwiseParity() {
        let scenarios = makeScenarios(count: 25, seed: 0xB2_0001)
        XCTAssertGreaterThanOrEqual(scenarios.count, 20, "可行盘面生成不足")

        var comparedPoints = 0
        var validityMismatch = 0
        var maxValidDiffDeg: Float = 0
        var diffs: [Float] = []

        for sc in scenarios {
            for offDeg: Float in [-8, -4, -2, -1, -0.5, 0, 0.5, 1, 2, 4, 8] {
                let off = offDeg * deg
                let sSim = ShotPredictor.positionAimScore(input: sc.input, context: sc.ctx, offset: off)
                let sAna = ShotPredictor.positionAimScoreAnalytic(input: sc.input, context: sc.ctx, offset: off)
                comparedPoints += 1

                let simValid = sSim < 99
                let anaValid = sAna < 99
                if simValid != anaValid {
                    validityMismatch += 1
                    print("⚠️ [B2 对拍·评分] 有效性不一致 @\(sc.tag) off=\(offDeg)° sim=\(sSim) ana=\(sAna)")
                    continue
                }
                if simValid {
                    let dDeg = abs(sSim - sAna) / deg
                    diffs.append(dDeg)
                    maxValidDiffDeg = max(maxValidDiffDeg, dDeg)
                    if dDeg > 0.05 {
                        print("⚠️ [B2 对拍·评分] 角误差偏差 \(String(format: "%.4f", dDeg))° " +
                              "@\(sc.tag) off=\(offDeg)° sim=\(sSim) ana=\(sAna)")
                    }
                }
            }
        }

        let sorted = diffs.sorted()
        let p50 = sorted.isEmpty ? 0 : sorted[sorted.count / 2]
        let p95 = sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, Int(Float(sorted.count) * 0.95))]
        print("📊 [B2 对拍·评分] 点数=\(comparedPoints) 有效对比=\(diffs.count) " +
              "有效性不一致=\(validityMismatch) | 角误差偏差 P50=\(String(format: "%.4f", p50))° " +
              "P95=\(String(format: "%.4f", p95))° max=\(String(format: "%.4f", maxValidDiffDeg))°")

        // 有效性判定不一致 ≤ 2%（允许边界档位上事件排序的浮点竞态）。
        XCTAssertLessThanOrEqual(Float(validityMismatch), Float(comparedPoints) * 0.02,
                                 "有效/无效判定与模拟大面积不一致——解析模型的事件检测失真")
        // 有效候选上角误差评分偏差：P95 ≤ 0.05°（评分口径的物理保真要求）。
        XCTAssertLessThanOrEqual(p95, 0.05, "解析评分与模拟评分 P95 偏差超阈值")
    }

    /// 第 2 层：求解结果对拍 + 模拟评分交叉裁判归因。
    func test_solvedOffset_parity_withCrossJudgeAttribution() {
        let scenarios = makeScenarios(count: 40, seed: 0xB2_0002)
        XCTAssertGreaterThanOrEqual(scenarios.count, 30, "可行盘面生成不足")

        var devDegs: [Float] = []
        var regressions = 0     // 解析解经模拟裁判后确实更差（真失真）
        var lostSolutions = 0   // 模拟有有效解、解析解落在无效区
        var bothInvalid = 0

        for sc in scenarios {
            let offSim = ShotPredictor.positionAimOffsetSimulated(input: sc.input, context: sc.ctx)
            let offAna = ShotPredictor.positionAimOffsetAnalytic(input: sc.input, context: sc.ctx)
            let devDeg = abs(offSim - offAna) / deg

            // 交叉裁判：用模拟自己的评分评两个解。
            let simAtSim = ShotPredictor.positionAimScore(input: sc.input, context: sc.ctx, offset: offSim)
            let simAtAna = ShotPredictor.positionAimScore(input: sc.input, context: sc.ctx, offset: offAna)

            if simAtSim >= 99 && simAtAna >= 99 {
                bothInvalid += 1    // 括号内本就无有效解，偏差无意义
                continue
            }
            devDegs.append(devDeg)

            if simAtSim < 99 && simAtAna >= 99 {
                lostSolutions += 1
                print("❌ [B2 对拍·求解] 解析丢失有效解 @\(sc.tag) " +
                      "offSim=\(offSim / deg)° offAna=\(offAna / deg)°")
                continue
            }
            let regret = simAtAna - simAtSim   // >0 = 解析解按模拟口径更差（rad）
            if devDeg > 0.05 {
                let regretDeg = regret / deg
                let verdict = regretDeg <= 0.05 ? "平坦谷底/孪生极小（无害）" : "解析模型失真"
                print("⚠️ [B2 对拍·求解] Δoffset=\(String(format: "%.4f", devDeg))° " +
                      "regret=\(String(format: "%.4f", regretDeg))° → \(verdict) @\(sc.tag)")
                if regretDeg > 0.05 { regressions += 1 }
            }
        }

        let sorted = devDegs.sorted()
        let p50 = sorted.isEmpty ? 0 : sorted[sorted.count / 2]
        let p95 = sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, Int(Float(sorted.count) * 0.95))]
        let maxDev = sorted.last ?? 0
        print("📊 [B2 对拍·求解] 有效对比=\(devDegs.count) 双无效跳过=\(bothInvalid) | " +
              "Δoffset P50=\(String(format: "%.4f", p50))° P95=\(String(format: "%.4f", p95))° " +
              "max=\(String(format: "%.4f", maxDev))° | 丢解=\(lostSolutions) 真失真=\(regressions)")

        XCTAssertEqual(lostSolutions, 0, "解析求解把模拟可行解丢进无效区")
        // 真失真（regret > 0.05°）≤ 5%：偏差主体必须是无害的平坦谷底。
        XCTAssertLessThanOrEqual(Float(regressions), Float(max(devDegs.count, 1)) * 0.05,
                                 "解析解经模拟裁判后显著更差的案例过多")
        XCTAssertGreaterThan(devDegs.count, 20, "有效对比样本过少")
    }
}
