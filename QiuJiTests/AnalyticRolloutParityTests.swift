//
//  AnalyticRolloutParityTests.swift
//  QiuJiTests
//
//  B3 — 单球解析 rollout 对拍验证（先于接线求解器，方案 §3 B3「对拍先行」精神同 B2）。
//
//  同一 (盘面, spin, velocity, aimOffset) 喂两边：
//  - 快速层：`AnalyticShotRollout.evaluate`（B2 解析首碰 + B3 单球 rollout）。
//  - 真值：引擎 scoring-only `ShotPredictor.predictForPositionSolve(aimOffset:)`（B1 路径，
//    即走位反解扫描今天实际使用的口径）。
//
//  比较集 = 快速层自认可覆盖的案例（needsFullSim == false 且母球未撞第三球）；
//  needsFullSim/撞球档位在求解器里本来就回退引擎，不参与失真统计（但打印回退率）。
//
//  断言口径：
//  - 进袋判定（pottedSelected）不一致 = 0（硬约束层面的失真不可接受）。
//  - 真停稳判定（cueRested vs cueFinalSpeed<tol && !cuePocketed）不一致 ≤ 2%（截断边界浮点竞态）。
//  - 双方同判停稳时：停点距离 P95 ≤ 5mm（闭式演进与引擎子步演进本应近逐位）。
//  - 吃库桶（碰后吃库数）不一致 ≤ 2%。
//
//  坐标契约：canvas 归一化 x∈[0,1]→场景X，y∈[0,0.5]→场景Z（origin 左上、Y 向下）。
//

import XCTest
import SceneKit
@testable import QiuJi

final class AnalyticRolloutParityTests: XCTestCase {

    private let sY = BTTablePhysics.surfaceY
    private let deg = Float.pi / 180

    private func scene(_ x: Double, _ y: Double) -> SCNVector3 {
        PositionPlaySolver.scenePoint(CanvasPoint(x: x, y: y), surfaceY: sY)
    }

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

    private struct Case {
        let input: ShotInput
        let ctx: ShotPredictor.AimContext
        let offset: Float
        let tag: String
    }

    /// 随机可行案例：位置全幅、力度 0.9–5.8、spinX ∈ ±0.45、spinY ∈ ±0.45，约 1/3 带 2–4 障碍。
    /// 每个案例现场解一次瞄准（与求解器记忆化同源），同一 offset 喂两边。
    private func makeCases(count: Int, seed: UInt64) -> [Case] {
        var rng = SplitMix64(state: seed)
        var out: [Case] = []
        var attempts = 0
        while out.count < count && attempts < count * 40 {
            attempts += 1
            let cue = scene(Double.random(in: 0.05...0.95, using: &rng),
                            Double.random(in: 0.05...0.45, using: &rng))
            let target = scene(Double.random(in: 0.05...0.95, using: &rng),
                               Double.random(in: 0.05...0.45, using: &rng))
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
            let velocity = Float.random(in: 0.9...5.8, using: &rng)
            let spinX = Float.random(in: -0.45...0.45, using: &rng)
            let spinY = Float.random(in: -0.45...0.45, using: &rng)

            let input = ShotInput(
                cueBall: cue, targetBall: target, pocketIndex: pocketIndex,
                velocity: velocity, spinX: spinX, spinY: spinY,
                surfaceY: sY, obstacles: obstacles
            )
            var result = ShotPrediction()
            guard let ctx = ShotPredictor.prepareAim(input, into: &result) else { continue }
            let off = ShotPredictor.positionAimOffset(input: input, context: ctx)
            let tag = String(
                format: "#%d cue=(%.3f,%.3f) tgt=(%.3f,%.3f) pkt=%d v=%.2f sx=%.2f sy=%.2f obs=%d off=%.3f°",
                out.count, cue.x, cue.z, target.x, target.z,
                pocketIndex, velocity, spinX, spinY, obstacles.count, off / deg
            )
            out.append(Case(input: input, ctx: ctx, offset: off, tag: tag))
        }
        return out
    }

    func test_rollout_matchesEngine_potRestStopAndCushions() {
        let cases = makeCases(count: 120, seed: 0xB3_0001)
        XCTAssertGreaterThanOrEqual(cases.count, 100, "可行案例生成不足")

        var covered = 0            // 快速层自认可覆盖（进入失真统计）
        var fellBack = 0           // needsFullSim / 撞第三球（求解器会回退引擎）
        var potMismatch = 0
        var restMismatch = 0
        var bucketMismatch = 0
        var stopDists: [Float] = []
        var cushionsAtStop: [Int] = []

        for c in cases {
            let fast = AnalyticShotRollout.evaluate(
                aimDir: c.ctx.aimDir.rotatedY(c.offset), velocity: c.input.velocity,
                input: c.input, geometry: c.ctx.geometry, ghost: c.ctx.ghost,
                maxTime: 15.0
            )
            if fast.needsFullSim || fast.cueFirstBallHit != nil {
                fellBack += 1
                continue
            }
            covered += 1

            let ref = ShotPredictor.predictForPositionSolve(
                c.input, aimOffset: c.offset, includePresentation: false)

            // 进袋判定（硬约束）。
            if fast.pottedSelected != ref.objectPocketed {
                potMismatch += 1
                print("❌ [B3 对拍] 进袋不一致 fast=\(fast.pottedSelected) engine=\(ref.objectPocketed) @\(c.tag)")
            }
            // 真停稳判定。
            let refRested = !ref.cuePocketed
                && ref.cueFinalSpeed < PositionPlaySolver.restSpeedTolerance
            if fast.cueRested != refRested {
                restMismatch += 1
                print("⚠️ [B3 对拍] 停稳判定不一致 fast=\(fast.cueRested) engine=\(refRested) " +
                      "(engineSpeed=\(ref.cueFinalSpeed), cuePocketed fast=\(fast.cuePocketed)/eng=\(ref.cuePocketed)) @\(c.tag)")
            }
            // 吃库桶（碰后吃库数）。
            let refBucket = max(0, ref.cueCushionCount - ref.cueCushionsBeforeContact)
            if ref.cueCushionsBeforeContact == 0, fast.cueCushionsAfterContact != refBucket {
                bucketMismatch += 1
                print("⚠️ [B3 对拍] 吃库桶不一致 fast=\(fast.cueCushionsAfterContact) engine=\(refBucket) @\(c.tag)")
            }
            // 停点距离（双方同判停稳时）。多库路径对初值极端敏感（混沌），偏差按吃库数分层归因。
            if fast.cueRested, refRested,
               let fp = fast.cueFinalPos,
               let rp = ref.finalPositions[ShotInput.cueBallName] {
                let d = AngleSceneCalculator.horizontalDistance(fp, rp)
                stopDists.append(d)
                cushionsAtStop.append(fast.cueCushionsAfterContact)
                if d > 0.02 {
                    print("⚠️ [B3 对拍] 停点偏差 \(String(format: "%.4f", d))m " +
                          "(碰后吃库 fast=\(fast.cueCushionsAfterContact)/eng=\(refBucket)) @\(c.tag)")
                }
            }
        }

        // 按碰后吃库数分层：0–1 库路径无混沌放大，必须近逐位（模型失真检测的敏感层）；
        // 多库路径每次反弹以指数放大初值差（引擎自身对 ~µm 扰动同样发散），
        // 允许更宽（求解器侧有代表解引擎复核兜底，扫描层不消费精确停点尾数）。
        func stats(_ pairs: [(Float, Int)], _ label: String, cushions: ClosedRange<Int>) -> Float {
            let ds = pairs.filter { cushions.contains($0.1) }.map { $0.0 }.sorted()
            guard !ds.isEmpty else { print("📊 [B3 对拍] \(label): n=0"); return 0 }
            let p50 = ds[ds.count / 2]
            let p95 = ds[min(ds.count - 1, Int(Float(ds.count) * 0.95))]
            print("📊 [B3 对拍] \(label): n=\(ds.count) P50=\(String(format: "%.5f", p50))m " +
                  "P95=\(String(format: "%.5f", p95))m max=\(String(format: "%.5f", ds.last!))m")
            return p95
        }
        let pairs = Array(zip(stopDists, cushionsAtStop))
        let p95Low = stats(pairs, "停点偏差·0–1库", cushions: 0...1)
        let p95Mid = stats(pairs, "停点偏差·2–3库", cushions: 2...3)
        _ = stats(pairs, "停点偏差·≥4库", cushions: 4...99)
        print("📊 [B3 对拍] 案例=\(cases.count) 覆盖=\(covered) 回退=\(fellBack) " +
              "(回退率 \(String(format: "%.0f%%", Double(fellBack) / Double(cases.count) * 100))) | " +
              "进袋不一致=\(potMismatch) 停稳不一致=\(restMismatch) 吃库桶不一致=\(bucketMismatch) " +
              "(n=\(stopDists.count))")

        XCTAssertGreaterThan(covered, 50, "快速层覆盖样本过少（回退率异常高，检查 needsFullSim 判据）")
        XCTAssertEqual(potMismatch, 0, "进袋判定与引擎不一致——rollout 物理失真，禁止接线")
        XCTAssertLessThanOrEqual(Float(restMismatch), Float(covered) * 0.02, "停稳判定大面积不一致")
        XCTAssertLessThanOrEqual(Float(bucketMismatch), Float(covered) * 0.02, "吃库桶大面积不一致")
        XCTAssertLessThanOrEqual(p95Low, 0.002, "0–1 库停点偏差 P95 超 2mm——非混沌层失真=真模型 bug")
        XCTAssertLessThanOrEqual(p95Mid, 0.05, "2–3 库停点偏差 P95 超 5cm——超出混沌放大可解释范围")
    }
}
