//
//  PocketRefactorDiagTests.swift
//  QiuJiTests
//
//  ADR-P10-09 袋口重建的临时诊断（复现矩阵失败样本，打印轨迹与事件序列）。
//

import XCTest
import SceneKit
@testable import QiuJi

final class PocketRefactorDiagTests: XCTestCase {

    private var surfaceY: Float { BTTablePhysics.surfaceY }
    private var R: Float { BallPhysics.radius }

    /// 复现 t0p2c40s+v4.2：目标球台心，袋2（左下角袋），切角 +40°，v4.2。
    func test_diag_escape_t0p2c40() {
        runCase(target: SCNVector3(0, surfaceY + R, 0), pocketIndex: 2,
                cutDeg: 40, sign: 1, v: 4.2, label: "t0p2c40s+v4.2")
    }

    /// 复现 t0p4c25s-v2.8：目标球台心，袋4（上中袋），切角 -25°，v2.8。
    func test_diag_escape_t0p4c25() {
        runCase(target: SCNVector3(0, surfaceY + R, 0), pocketIndex: 4,
                cutDeg: 25, sign: -1, v: 2.8, label: "t0p4c25s-v2.8")
    }

    /// 直探：左下角袋短边 R105 弧对慢速斜向球的 CCD 是否出事件。
    func test_diag_arcCCD_slowBallIntoShortArc() {
        let sY = surfaceY
        let geo = TableGeometry.chineseEightBallQiuJi(surfaceY: sY)
        let p = SCNVector3(-1.2441, sY + R, 0.5676)
        let speed: Float = 0.09
        let dir = SCNVector3(-0.64, 0, -0.77)
        let v = SCNVector3(dir.x * speed, 0, dir.z * speed)
        // rolling 减速度
        let decel = SpinPhysics.rollingFriction * TablePhysics.gravity
        let a = SCNVector3(-dir.x * decel, 0, -dir.z * decel)

        print("\n=== [arcCCD 直探] p=(\(p.x), \(p.z)) v=(\(v.x), \(v.z)) ===")
        for (i, arc) in geo.circularCushions.enumerated() {
            let dx = p.x - arc.center.x, dz = p.z - arc.center.z
            let d = sqrtf(dx * dx + dz * dz)
            let contact = arc.radius + R
            guard d < contact + 0.05 else { continue }
            let ang = atan2f(dz, dx) * 180 / .pi
            let t = CollisionDetector.ballCircularCushionTime(
                p: p, v: v, a: a, arc: arc, R: R, maxTime: 3.0, pockets: geo.pockets)
            print(String(format: "  arc[%d] c=(%.4f, %.4f) r=%.3f 距=%.4f(contact %.4f) 角=%.1f° 事件t=%@ 角域[%.1f°, %.1f°]",
                         i, arc.center.x, arc.center.z, arc.radius, d, contact, ang,
                         t.map { String(format: "%.4f", $0) } ?? "nil",
                         arc.startAngle * 180 / .pi, arc.endAngle * 180 / .pi))
        }
    }

    /// 对拍 QuarticSolver：慢滚球贴近弧面时的系数（Python np.roots 有 t≈0.028 实根）。
    func test_diag_quarticSolver_slowArcApproach() {
        let cx: Float = -1.3750, cz: Float = 0.5321106
        let D = Double(0.105 + R)
        let px: Float = -1.2441, pz: Float = 0.5676
        var dirx: Float = -0.64, dirz: Float = -0.77
        let n = sqrtf(dirx * dirx + dirz * dirz); dirx /= n; dirz /= n
        let speed: Float = 0.09
        let vx = dirx * speed, vz = dirz * speed
        let decel = SpinPhysics.rollingFriction * TablePhysics.gravity
        let ax = -dirx * decel, az = -dirz * decel
        let dpx = Double(px - cx), dpz = Double(pz - cz)
        let hax = Double(ax) * 0.5, haz = Double(az) * 0.5
        let c4 = hax * hax + haz * haz
        let c3 = 2.0 * (Double(vx) * hax + Double(vz) * haz)
        let c2 = Double(vx * vx + vz * vz) + 2.0 * (dpx * hax + dpz * haz)
        let c1 = 2.0 * (dpx * Double(vx) + dpz * Double(vz))
        let c0 = dpx * dpx + dpz * dpz - D * D
        print("\n=== [quartic 对拍] coeffs=\(c4), \(c3), \(c2), \(c1), \(c0)")
        let roots = QuarticSolver.solveQuartic(a: c4, b: c3, c: c2, d: c1, e: c0)
        print("  swift roots=\(roots.sorted())  (python: 0.0284, 1.8065)")
    }

    /// 复现 largeCut 失败：中台→袋1（右上角袋）cut65° v3.3。
    func test_diag_largeCut65_pocket1() {
        runCase(target: SCNVector3(0, surfaceY + R, 0), pocketIndex: 1,
                cutDeg: 65, sign: 1, v: 3.3, label: "largeCut65-p1")
    }

    /// 65° 薄切在不同力度下的进袋扫描：判断双吻是几何必然还是 v=3.3 窄带巧合。
    func test_diag_largeCut65_velocitySweep() {
        let sY = surfaceY
        let target = SCNVector3(0, sY + R, 0)
        let pocket = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: target, pocketIndex: 1, surfaceY: sY)
        let ghost = AngleSceneCalculator.ghostBallPosition(
            targetBall: target, pocket: pocket, ballRadius: R)
        let pdx = pocket.x - target.x, pdz = pocket.z - target.z
        let pl = sqrtf(pdx * pdx + pdz * pdz)
        let pd = SCNVector3(pdx / pl, 0, pdz / pl)
        let th = Float(65) * .pi / 180
        let strikeDir = SCNVector3(pd.x * cosf(th) - pd.z * sinf(th), 0,
                                   pd.x * sinf(th) + pd.z * cosf(th))
        let cue = SCNVector3(ghost.x - strikeDir.x * 0.45, sY + R, ghost.z - strikeDir.z * 0.45)
        for v in [Float(2.0), 2.4, 2.8, 3.0, 3.3, 3.6, 4.0] {
            let pred = ShotPredictor.predict(ShotInput(
                cueBall: cue, targetBall: target, pocketIndex: 1,
                velocity: v, spinX: 0, spinY: 0, surfaceY: sY))
            let kisses = pred.events.filter { if case .ballBall = $0.kind { return true }; return false }.count
            print(String(format: "  [65°扫描] v=%.1f potted=%@ ballBall次数=%d",
                         v, pred.objectPocketed ? "✅" : "❌", kisses))
            // 第二次球-球接触的几何核实：双方位置/速度 + 目标球离袋距离
            let bb = pred.events.filter { if case .ballBall = $0.kind { return true }; return false }
            if bb.count >= 2, let rec = pred.recorder {
                let t2 = bb[1].time
                for name in ["cueBall", "object"] {
                    if let s = rec.stateAt(ballName: name, time: t2 - 0.001) {
                        print(String(format: "    [双吻前] %@ (%.4f, %.4f) v=(%.3f, %.3f)",
                                     name, s.position.x, s.position.z, s.velocity.x, s.velocity.z))
                    }
                }
                let dx = (rec.stateAt(ballName: "object", time: t2 - 0.001)?.position.x ?? 0) - 1.312
                let dz = (rec.stateAt(ballName: "object", time: t2 - 0.001)?.position.z ?? 0) + 0.677
                print(String(format: "    [双吻时] 目标球距袋心 %.3f m", sqrtf(dx*dx + dz*dz)))
            }
        }
    }

    /// 复现矩阵出界样本 t1p1c40s+v2.8 / t2p0c40s-v2.8。
    func test_diag_escape_t1p1c40() {
        runCase(target: SCNVector3(0.6, surfaceY + R, 0), pocketIndex: 1,
                cutDeg: 40, sign: 1, v: 2.8, label: "t1p1c40s+v2.8")
    }
    func test_diag_escape_t2p0c40() {
        runCase(target: SCNVector3(-0.6, surfaceY + R, 0), pocketIndex: 0,
                cutDeg: 40, sign: -1, v: 2.8, label: "t2p0c40s-v2.8")
    }

    /// 裸引擎复现：长弧反弹后的母球（rolling）应在 ~0.05s 撞 RU 短弧。
    func test_diag_bareEngine_shortArcAfterBounce() {
        let sY = surfaceY
        let geo = TableGeometry.chineseEightBallQiuJi(surfaceY: sY)
        let engine = EventDrivenEngine(tableGeometry: geo)
        var cue = BallState(
            position: SCNVector3(1.1778, sY + R, 0.6069),
            velocity: SCNVector3(1.324, 0, -0.881),
            angularVelocity: SCNVector3Zero,
            state: .rolling, name: "cue")
        // rolling 对应的角速度（滚动无滑：ω = ẑ×v/R 形式，y-up）
        cue.angularVelocity = SCNVector3(cue.velocity.z / R, 0, -cue.velocity.x / R)
        engine.setBall(cue)
        engine.simulate(maxEvents: 40, maxTime: 1.0)
        print("\n=== [裸引擎·短弧] 事件序列：")
        for (i, e) in engine.resolvedEvents.enumerated() {
            print("  [\(i)] t=\(engine.resolvedEventTimes[i]) \(e)")
        }
        if let final = engine.getBall("cue") {
            print("  末态 (\(final.position.x), \(final.position.z)) v=(\(final.velocity.x), \(final.velocity.z)) \(final.state)")
        }
    }

    /// 裸引擎复现：同一状态但 sliding + 侧向表面速度（匹配失败轨迹的摩擦特征：vx 恒、vz 衰减）。
    func test_diag_bareEngine_shortArcSliding() {
        let sY = surfaceY
        let geo = TableGeometry.chineseEightBallQiuJi(surfaceY: sY)
        let engine = EventDrivenEngine(tableGeometry: geo)
        let vel = SCNVector3(1.324, 0, -0.881)
        // 表面速度设为纯 -z（摩擦 → +z，与轨迹 vz 衰减一致）：
        // s = (vx + ωz·R, 0, vz − ωx·R) = (0, 0, -0.5)
        let wz = -vel.x / R
        let wx = (vel.z + 0.5) / R
        let cue = BallState(
            position: SCNVector3(1.1778, sY + R, 0.6069),
            velocity: vel,
            angularVelocity: SCNVector3(wx, 0, wz),
            state: .sliding, name: "cue")
        engine.setBall(cue)
        engine.simulate(maxEvents: 200, maxTime: 1.0, highFidelityBounds: true)
        print("\n=== [裸引擎·短弧·sliding] 事件序列：")
        for (i, e) in engine.resolvedEvents.enumerated() {
            print("  [\(i)] t=\(engine.resolvedEventTimes[i]) \(e)")
        }
        if let final = engine.getBall("cue") {
            print("  末态 (\(final.position.x), \(final.position.z)) v=(\(final.velocity.x), \(final.velocity.z)) \(final.state)")
        }
    }

    /// fastPath vs predict 停点分歧诊断：spin(-0.3,-0.3) v4.5 中袋直球。
    func test_diag_fastPathDivergence_spinNN_v45() {
        let sY = surfaceY
        let cue = PositionPlaySolver.scenePoint(CanvasPoint(x: 0.5, y: 0.35), surfaceY: sY)
        let target = PositionPlaySolver.scenePoint(CanvasPoint(x: 0.5, y: 0.15), surfaceY: sY)
        guard let pocketIndex = ShotIntent.pocketIndex(for: "topCenter") else { return XCTFail() }
        let input = ShotInput(cueBall: cue, targetBall: target, pocketIndex: pocketIndex,
                              velocity: 4.5, spinX: -0.3, spinY: -0.3, surfaceY: sY, obstacles: [])
        let ref = ShotPredictor.predict(input)
        let fast = ShotPredictor.predictForPositionSolve(input)
        for (name, p) in [("predict", ref), ("fastPath", fast)] {
            print("\n  [\(name)] potted=\(p.objectPocketed) cueCushions=\(p.cueCushionCount)")
            if let fc = p.finalPositions[ShotInput.cueBallName] {
                print("  [\(name)] 母球停点 (\(fc.x), \(fc.z))")
            }
            for e in p.events {
                print(String(format: "    t=%.4f %@", e.time, String(describing: e.kind)))
            }
        }
        // 黄金分割实际选中的偏角 + 其邻域细扫（0.01° 步长）看停点梯度。
        let deg = Float.pi / 180
        var tmp = ShotPrediction()
        if let ctx = ShotPredictor.prepareAim(input, into: &tmp) {
            let goldenOff = ShotPredictor.positionAimOffset(input: input, context: ctx)
            print(String(format: "  [golden] 选中偏角=%.4f°", goldenOff / deg))
            var offDeg: Float = goldenOff / deg - 0.06
            while offDeg <= goldenOff / deg + 0.06 {
                let p = ShotPredictor.predictForPositionSolve(input, aimOffset: offDeg * deg)
                let fc = p.finalPositions[ShotInput.cueBallName] ?? SCNVector3Zero
                print(String(format: "  [细扫] off=%+.3f° potted=%@ cushions=%d 停点 (%.4f, %.4f)",
                             offDeg, p.objectPocketed ? "Y" : "N", p.cueCushionCount, fc.x, fc.z))
                offDeg += 0.01
            }
        }
    }

    private func runCase(target: SCNVector3, pocketIndex: Int, cutDeg: Float,
                         sign: Float, v: Float, label: String) {
        let sY = surfaceY
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: sY)
        let pocket = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: target, pocketIndex: pocketIndex, surfaceY: sY)
        let ghost = AngleSceneCalculator.ghostBallPosition(
            targetBall: target, pocket: pocket, ballRadius: R)
        let pdx = pocket.x - target.x, pdz = pocket.z - target.z
        let pl = sqrtf(pdx * pdx + pdz * pdz)
        let pd = SCNVector3(pdx / pl, 0, pdz / pl)
        let th = cutDeg * .pi / 180 * sign
        let strikeDir = SCNVector3(pd.x * cosf(th) - pd.z * sinf(th), 0,
                                   pd.x * sinf(th) + pd.z * cosf(th))
        let cue = SCNVector3(ghost.x - strikeDir.x * 0.45, sY + R, ghost.z - strikeDir.z * 0.45)

        print("\n=== [\(label)] aim=(\(pocket.x), \(pocket.z)) cue=(\(cue.x), \(cue.z)) ===")
        let pred = ShotPredictor.predict(ShotInput(
            cueBall: cue, targetBall: target, pocketIndex: pocketIndex,
            velocity: v, spinX: 0, spinY: 0, surfaceY: sY))
        print("feasible=\(pred.feasible) potted=\(pred.objectPocketed)")

        func audit(_ path: [SCNVector3], name: String) {
            for p in path {
                let inRect = abs(p.x) <= halfL - R + 0.02 && abs(p.z) <= halfW - R + 0.02
                var nearPocket = false
                for pk in pockets {
                    let dx = p.x - pk.x, dz = p.z - pk.z
                    if dx * dx + dz * dz <= 0.14 * 0.14 { nearPocket = true; break }
                }
                if !inRect && !nearPocket {
                    print("  [\(name)] 出界点 (\(p.x), \(p.z))")
                }
            }
            if let last = path.last { print("  [\(name)] 末端 (\(last.x), \(last.z))") }
        }
        audit(pred.cuePath, name: "cue")
        audit(pred.objectPath, name: "obj")

        // 事件序列（含时间），检查逃逸窗口内引擎实际解算了什么。
        for e in pred.events {
            print(String(format: "  [事件] t=%.4f %@", e.time, String(describing: e.kind)))
        }

        // 用记录帧重放：窗口内每帧直接调 CCD，验证探测器在真实状态下能否找到弧碰撞。
        if let rec = pred.recorder, let cueFrames = rec.framesByBallName["cueBall"] {
            let geo = TableGeometry.chineseEightBallQiuJi(surfaceY: sY)
            for f in cueFrames.sorted(by: { $0.time < $1.time }) {
                guard f.time >= 0.46 && f.time <= 0.60 else { continue }
                let st = BallState(
                    position: f.position, velocity: f.velocity,
                    angularVelocity: SCNVector3(f.angularVelocity.x, f.angularVelocity.y, f.angularVelocity.z),
                    state: f.state, name: "cue")
                let a = EngineNumerics.acceleration(for: st)
                var hits: [String] = []
                for (i, arc) in geo.circularCushions.enumerated() {
                    if let t = CollisionDetector.ballCircularCushionTime(
                        p: st.position, v: st.velocity, a: a, arc: arc,
                        R: BallPhysics.radius, maxTime: 0.15, pockets: geo.pockets) {
                        hits.append(String(format: "arc%d@+%.4f", i, t))
                    }
                }
                print(String(format: "  [CCD] t=%.4f (%.4f, %.4f) v=(%.3f, %.3f) a=(%.3f, %.3f) %@ → %@",
                             f.time, f.position.x, f.position.z,
                             f.velocity.x, f.velocity.z, a.x, a.z,
                             String(describing: st.state),
                             hits.isEmpty ? "无" : hits.joined(separator: " ")))
                // 对 arc7（RU 短边 R105）打印四次多项式系数与根，供数值比对
                if hits.isEmpty {
                    let arc = geo.circularCushions[7]
                    let D = Double(arc.radius + BallPhysics.radius)
                    let dpx = Double(st.position.x - arc.center.x)
                    let dpz = Double(st.position.z - arc.center.z)
                    let dvx = Double(st.velocity.x), dvz = Double(st.velocity.z)
                    let hax = Double(a.x) * 0.5, haz = Double(a.z) * 0.5
                    let c4 = hax * hax + haz * haz
                    let c3 = 2.0 * (dvx * hax + dvz * haz)
                    let c2 = dvx * dvx + dvz * dvz + 2.0 * (dpx * hax + dpz * haz)
                    let c1 = 2.0 * (dpx * dvx + dpz * dvz)
                    let c0 = dpx * dpx + dpz * dpz - D * D
                    let dist = (dpx * dpx + dpz * dpz).squareRoot()
                    let roots = QuarticSolver.solveQuartic(a: c4, b: c3, c: c2, d: c1, e: c0)
                    print("    [arc7] dist=\(dist) D=\(D) gap=\(dist - D)")
                    print("    [arc7] coeffs=[\(c4), \(c3), \(c2), \(c1), \(c0)] roots=\(roots)")
                }
            }
        }

        if let rec = pred.recorder {
            for (ballName, frames) in rec.framesByBallName {
                print("  -- \(ballName) 出界邻域帧（|x|>1.23 或 |z|>0.60）：")
                var printed = 0
                for f in frames {
                    guard abs(f.position.x) > 1.23 || abs(f.position.z) > 0.60 else { continue }
                    let sp = sqrtf(f.velocity.x * f.velocity.x + f.velocity.z * f.velocity.z)
                    print(String(format: "     t=%.3f (%.4f, %.4f) v=(%.3f, %.3f)|%.2f %@",
                                 f.time, f.position.x, f.position.z,
                                 f.velocity.x, f.velocity.z, sp,
                                 f.state == .pocketed ? "POCKETED" : ""))
                    printed += 1
                    if printed > 40 { print("     …截断"); break }
                }
            }
        }
    }
}
