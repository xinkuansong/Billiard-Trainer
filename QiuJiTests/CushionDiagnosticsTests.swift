import XCTest
import SceneKit
@testable import QiuJi

/// 库边碰撞速度诊断 —— 把 Han 2005 闭式库边模型在不同入射角 / 速度 / 旋转下的
/// 「入射速度 → 反弹速度」逐条打印出来，便于分析「吃库后速度衰减」是否合理。
///
/// 运行：`xcodebuild ... test -only-testing:QiuJiTests/CushionDiagnosticsTests`
/// 输出见控制台（每行：入射角/入射速度/反弹速度/速度保留率/入射角/反弹角）。
final class CushionDiagnosticsTests: XCTestCase {

    private let R = BallPhysics.radius
    private let M = BallPhysics.mass

    /// 单纯库边模型：固定法向 +x（库面在 -x 侧），球以速度 S、相对法向夹角 θ 入射。
    /// 不含台呢摩擦、不含球-球，只看一次吃库的速度变化。
    func test_cushion_speedRetention_byAngleAndSpeed() {
        let normal = SCNVector3(1, 0, 0)  // 指向台内
        let speeds: [Float] = [2.0, 4.0, 6.0]
        let anglesFromNormalDeg: [Float] = [0, 15, 30, 45, 60, 75]

        print("\n=== Han2005 库边速度诊断（无旋转，e_c=\(TablePhysics.cushionRestitution), f_c=\(TablePhysics.cushionFriction), h=\(TablePhysics.cushionHeight)) ===")
        print("入射角°(距法向)  入射速度  反弹速度   保留率   反弹角°(距法向)")
        for S in speeds {
            for degFromNormal in anglesFromNormalDeg {
                let th = degFromNormal * .pi / 180
                // 朝 -x 方向接近库（法向分量），切向沿 +z。
                let v = SCNVector3(-S * cosf(th), 0, S * sinf(th))
                let r = CollisionResolver.resolveCushionCollisionPure(
                    velocity: v, angularVelocity: SCNVector3Zero, normal: normal
                )
                let sOut = sqrtf(r.velocity.x * r.velocity.x + r.velocity.z * r.velocity.z)
                let ratio = sOut / S
                // 反弹角（距法向）：反弹速度与法向(+x) 的夹角。
                let outFromNormal = atan2f(abs(r.velocity.z), abs(r.velocity.x)) * 180 / .pi
                print(String(format: "  %5.0f          %5.2f     %5.2f    %5.1f%%      %5.1f",
                             degFromNormal, S, sOut, ratio * 100, outFromNormal))
            }
            print("  ----")
        }
    }

    /// 带旋转（高杆 / 侧塞）吃库的速度变化，观察旋转对反弹速度/方向的影响。
    func test_cushion_speedRetention_withSpin() {
        let normal = SCNVector3(1, 0, 0)
        let S: Float = 4.0
        let th: Float = 45 * .pi / 180
        let v = SCNVector3(-S * cosf(th), 0, S * sinf(th))

        // 自然滚动角速度量级参考（v/R）。
        let wRoll = S / R
        let cases: [(String, SCNVector3)] = [
            ("无旋转",      SCNVector3Zero),
            ("上旋(跟)",    SCNVector3(0, 0, -wRoll)),      // 绕 -z（行进 +x 时的前滚）
            ("下旋(缩)",    SCNVector3(0, 0,  wRoll)),
            ("左侧塞",      SCNVector3(0,  wRoll * 0.5, 0)),// 绕竖直轴
            ("右侧塞",      SCNVector3(0, -wRoll * 0.5, 0))
        ]

        print("\n=== Han2005 库边（45° 入射, S=\(S) m/s）旋转影响 ===")
        print("情形       反弹速度  保留率   反弹角°(距法向)")
        for (name, w) in cases {
            let r = CollisionResolver.resolveCushionCollisionPure(
                velocity: v, angularVelocity: w, normal: normal
            )
            let sOut = sqrtf(r.velocity.x * r.velocity.x + r.velocity.z * r.velocity.z)
            let outFromNormal = atan2f(abs(r.velocity.z), abs(r.velocity.x)) * 180 / .pi
            print(String(format: "%@   %5.2f    %5.1f%%      %5.1f", name, sOut, sOut / S * 100, outFromNormal))
        }
    }

    /// 诊断「瞄准线/假想球错位」与「母球轨迹出台」两个截图问题：
    /// 打印几何假想球 vs 实际碰撞时母球中心的偏差，以及母球轨迹是否越出内框。
    func test_shotPredictor_ghostAndPathDiagnostics() {
        let surfaceY: Float = BTTablePhysics.surfaceY
        let r = AngleSceneCalculator.ballRadius
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2

        // 复现默认球形（与 ShotSimulationViewModel.placeBallsAtDefaults 一致）。
        let cue = SCNVector3(-0.35, surfaceY + r, 0.22)
        let target = SCNVector3(0.55, surfaceY + r, -0.18)

        let spins: [Float] = [0, 0.3, 0.6, -0.6]
        for spinX in spins {
            // 选最优袋（与 selectBestPocket 同逻辑的简化：取切角最小且可行的袋）。
            let pocketCount = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY).count
            var bestPocket = 0
            var bestAngle = Double.greatestFiniteMagnitude
            for i in 0..<pocketCount {
                let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: i, surfaceY: surfaceY)
                guard AngleSceneCalculator.isFeasible(cueBall: cue, targetBall: target, pocket: aim) else { continue }
                let a = AngleSceneCalculator.cutAngle(cueBall: cue, targetBall: target, pocket: aim)
                if a < bestAngle { bestAngle = a; bestPocket = i }
            }

            let input = ShotInput(
                cueBall: cue, targetBall: target, pocketIndex: bestPocket,
                velocity: StrokePhysics.SpeedLevel.medium.velocity, spinX: spinX, spinY: 0, surfaceY: surfaceY
            )
            let pred = ShotPredictor.predict(input)

            let aimPoint = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: bestPocket, surfaceY: surfaceY)
            let geomGhost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: aimPoint, ballRadius: r)

            // 几何假想球 vs 实际碰撞母球中心。
            let ghostDelta: Float
            if let fc = pred.firstContact {
                let dx = fc.x - geomGhost.x, dz = fc.z - geomGhost.z
                ghostDelta = sqrtf(dx * dx + dz * dz)
            } else {
                ghostDelta = -1
            }

            // 母球轨迹包围盒 vs 内框 + R（越界即出台/穿模）。
            var maxX: Float = 0, maxZ: Float = 0
            for p in pred.cuePath {
                maxX = max(maxX, abs(p.x)); maxZ = max(maxZ, abs(p.z))
            }
            let outX = maxX - (halfL + r)
            let outZ = maxZ - (halfW + r)

            print(String(format: "\n[spinX=%.1f, pocket=%d] feasible=%@ pocketed=%@",
                         spinX, bestPocket, pred.feasible ? "Y" : "N", pred.objectPocketed ? "Y" : "N"))
            print(String(format: "  几何假想球=(%.3f,%.3f) 实际碰撞母球中心=%@ 偏差=%.1fmm",
                         geomGhost.x, geomGhost.z,
                         pred.firstContact.map { String(format: "(%.3f,%.3f)", $0.x, $0.z) } ?? "nil",
                         ghostDelta * 1000))
            print(String(format: "  母球轨迹点数=%d 包围盒|x|max=%.3f(内框%.3f) |z|max=%.3f(内框%.3f) 越界x=%.1fmm 越界z=%.1fmm",
                         pred.cuePath.count, maxX, halfL + r, maxZ, halfW + r, outX * 1000, outZ * 1000))
            if outX > 0.001 || outZ > 0.001 {
                print("  ⚠️ 母球轨迹越出内框（出台/穿模）")
            }
        }
    }

    /// 扫描多种球位/袋口/塞，找出「母球轨迹越出内框（穿模）」的场景并打印细节。
    func test_shotPredictor_scanForOutOfBoundsCuePath() {
        let surfaceY: Float = BTTablePhysics.surfaceY
        let r = AngleSceneCalculator.ballRadius
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let pocketCount = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY).count

        // 目标球扫描网格（含贴近左右/上下库）。
        let txs: [Float] = [-1.0, -0.5, 0, 0.5, 1.0]
        let tzs: [Float] = [-0.58, -0.3, 0, 0.3, 0.58]   // ±0.58 接近 ±halfW(0.635)−R
        let cues: [SCNVector3] = [
            SCNVector3(-0.9, surfaceY + r, 0.4),
            SCNVector3(0.6, surfaceY + r, 0.45),
            SCNVector3(0.0, surfaceY + r, 0.5),
            SCNVector3(-0.4, surfaceY + r, -0.4)
        ]
        let spins: [Float] = [0, 0.6, -0.6]

        var worst: (out: Float, desc: String)?
        var oobCount = 0
        var total = 0

        for tx in txs {
            for tz in tzs {
                let target = SCNVector3(tx, surfaceY + r, tz)
                for cue in cues {
                    if AngleSceneCalculator.ballsOverlap(cue, target) { continue }
                    // 选最优可行袋。
                    var bestPocket = -1
                    var bestAngle = Double.greatestFiniteMagnitude
                    for i in 0..<pocketCount {
                        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: i, surfaceY: surfaceY)
                        guard AngleSceneCalculator.isFeasible(cueBall: cue, targetBall: target, pocket: aim) else { continue }
                        let a = AngleSceneCalculator.cutAngle(cueBall: cue, targetBall: target, pocket: aim)
                        if a < bestAngle { bestAngle = a; bestPocket = i }
                    }
                    guard bestPocket >= 0 else { continue }
                    for spinX in spins {
                        total += 1
                        let input = ShotInput(
                            cueBall: cue, targetBall: target, pocketIndex: bestPocket,
                            velocity: StrokePhysics.SpeedLevel.medium.velocity, spinX: spinX, spinY: 0, surfaceY: surfaceY
                        )
                        let pred = ShotPredictor.predict(input)
                        guard pred.feasible else { continue }
                        var maxX: Float = 0, maxZ: Float = 0
                        for p in pred.cuePath { maxX = max(maxX, abs(p.x)); maxZ = max(maxZ, abs(p.z)) }
                        let out = max(maxX - (halfL + r), maxZ - (halfW + r))
                        if out > 0.005 {
                            oobCount += 1
                            let desc = String(format: "t=(%.2f,%.2f) cue=(%.2f,%.2f) pocket=%d spin=%.1f cuePocketed=%@ |x|=%.3f |z|=%.3f out=%.0fmm",
                                              tx, tz, cue.x, cue.z, bestPocket, spinX,
                                              pred.cuePocketed ? "Y" : "N", maxX, maxZ, out * 1000)
                            if worst == nil || out > worst!.out { worst = (out, desc) }
                            if oobCount <= 12 { print("  OOB: \(desc)") }
                        }
                    }
                }
            }
        }
        print(String(format: "\n[扫描] 总样本=%d 越界=%d (%.1f%%)", total, oobCount, total > 0 ? Float(oobCount) / Float(total) * 100 : 0))
        if let w = worst { print("  最严重：\(w.desc)") }

        // 回归护栏：钳制安全网应把任何「穿库飞出」限制在袋口嘴附近（≤ ~0.15m 越界）。
        // 修复前最严重可达 3.1m（4.4m 母球中心），若回归到米级说明安全网失效。
        if let w = worst {
            XCTAssertLessThan(w.out, 0.18, "母球轨迹越界过大，疑似穿库安全网失效：\(w.desc)")
        }
    }

    /// 与旧模型（Mathavan 2010 冲量积分，已停用）对照同一组入射，量化差异。
    func test_cushion_HanVsMathavan() {
        let S: Float = 4.0
        let anglesFromNormalDeg: [Float] = [15, 30, 45, 60, 75]

        print("\n=== Han 2005 vs Mathavan 2010（S=\(S) m/s, 无旋转）速度保留率对照 ===")
        print("入射角°(距法向)   Han保留率   Mathavan保留率")
        for degFromNormal in anglesFromNormalDeg {
            let th = degFromNormal * .pi / 180

            // Han：经右手接触系（与引擎实际调用一致）。
            let v = SCNVector3(-S * cosf(th), 0, S * sinf(th))
            let han = CollisionResolver.resolveCushionCollisionPure(
                velocity: v, angularVelocity: SCNVector3Zero, normal: SCNVector3(1, 0, 0)
            )
            let hanOut = sqrtf(han.velocity.x * han.velocity.x + han.velocity.z * han.velocity.z)

            // Mathavan：直接调用旧模型（vx=切向, vy=法向）。
            let m = CushionCollisionModel.solve(
                vx: S * sinf(th), vy: S * cosf(th),
                omega_x: 0, omega_y: 0, omega_z: 0,
                mu_s: TablePhysics.clothFriction, mu_w: TablePhysics.cushionFriction,
                ee: TablePhysics.cushionRestitution, h: TablePhysics.cushionHeight,
                R: R, M: M
            )
            let mOut = sqrtf(m.vx * m.vx + m.vy * m.vy)

            print(String(format: "  %5.0f           %5.1f%%        %5.1f%%",
                         degFromNormal, hanOut / S * 100, mOut / S * 100))
        }
    }
}
