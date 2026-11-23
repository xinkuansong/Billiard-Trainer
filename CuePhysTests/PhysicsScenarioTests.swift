import XCTest
import SceneKit
@testable import QiuJi

/// 真实台球场景断言（D-C1/C2 扩面）——把审计「测试覆盖缺口矩阵」里列出的、此前只在
/// 诊断里 print 或完全没覆盖的**真实球理现象**钉成机器断言：
///   - 跟/定/缩杆（follow/stun/draw）母球落点次序
///   - 击球力度 → 走位路程单调
///   - 加塞引起的目标球偏移（collision throw by english）
///   - 带塞吃库变线（side spin → 反弹切向偏移）
///   - 连续多库（吃 ≥2 库仍不出界 + 整体减速）
///   - 组合球（母球→一库→二库的能量传递）
///   - 清晰球进袋矩阵（切角 × 力度，断言进袋或沿正确进球线）
///
/// 这些是「真实场景复杂度」的护栏：不再靠肉眼看 PNG / 控制台数字判断走位与杆法是否合理。
final class PhysicsScenarioTests: XCTestCase {

    private let R = BallPhysics.radius
    private var surfaceY: Float { BTTablePhysics.surfaceY }

    // MARK: - 跟/定/缩杆母球落点次序

    /// 正面直球：缩杆(draw)母球回拉、定杆(stun)停在接触点附近、跟杆(follow)继续前进。
    /// 断言三者母球最终 x 的严格次序：draw < stun < follow。
    func test_scenario_drawStunFollow_cueFinalOrdering() {
        func cueFinalX(spinY: Float) -> Float {
            let cue = SCNVector3(-0.5, surfaceY + R, 0)
            let target = SCNVector3(0.0, surfaceY + R, 0)   // 正前方正面球
            let strike = CueBallStrike.executeStrike(aimDirection: SCNVector3(1, 0, 0), velocity: 3.0, spinX: 0, spinY: spinY)
            let engine = EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBallQiuJi(surfaceY: surfaceY))
            engine.setBall(BallState(position: cue, velocity: strike.velocity, angularVelocity: strike.angularVelocity, state: .sliding, name: "cue"))
            engine.setBall(BallState(position: target, velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero, state: .stationary, name: "obj"))
            engine.simulate(maxEvents: 600, maxTime: 20)
            return engine.getTrajectoryRecorder().framesByBallName["cue"]?.last?.position.x ?? 0
        }
        let draw = cueFinalX(spinY: -1)
        let stun = cueFinalX(spinY: 0)
        let follow = cueFinalX(spinY: 1)
        print(String(format: "\n[场景] 杆法母球落点 x：缩杆 %.3f < 定杆 %.3f < 跟杆 %.3f", draw, stun, follow))
        XCTAssertLessThan(draw, stun - 0.02, "缩杆母球应比定杆更靠后（回拉）")
        XCTAssertLessThan(stun, follow - 0.02, "跟杆母球应比定杆更靠前（前送）")
        XCTAssertLessThan(draw, 0.0, "缩杆母球应回拉到接触点之后（x<0）")
    }

    // MARK: - 力度 → 走位路程单调

    /// 中心球沿长轴击打：杆头速度越大，母球总滚动路程越长（严格单调非减）。
    func test_scenario_strikeSpeed_rollDistanceMonotonic() {
        func pathLength(velocity: Float) -> Float {
            let strike = CueBallStrike.executeStrike(aimDirection: SCNVector3(1, 0, 0), velocity: velocity, spinX: 0, spinY: 0)
            let engine = EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBallQiuJi(surfaceY: surfaceY))
            engine.setBall(BallState(position: SCNVector3(-1.15, surfaceY + R, 0.07),
                                     velocity: strike.velocity, angularVelocity: strike.angularVelocity,
                                     state: .sliding, name: "cue"))
            engine.simulate(maxEvents: 1200, maxTime: 40)
            var len: Float = 0
            let frames = (engine.getTrajectoryRecorder().framesByBallName["cue"] ?? []).sorted { $0.time < $1.time }
            for i in 1..<max(frames.count, 1) {
                let d = frames[i].position - frames[i - 1].position
                len += sqrtf(d.x * d.x + d.z * d.z)
            }
            return len
        }
        let speeds: [Float] = [1.6, 2.4, 3.3, 4.4, 5.8]
        let lens = speeds.map { pathLength(velocity: $0) }
        print("\n[场景] 力度→走位路程：" + zip(speeds, lens).map { String(format: "%.1f→%.2fm", $0, $1) }.joined(separator: "  "))
        for i in 1..<lens.count {
            XCTAssertGreaterThan(lens[i], lens[i - 1] - 0.05, "力度 \(speeds[i]) 走位路程 \(lens[i])m 不应短于更轻的 \(speeds[i-1])（\(lens[i-1])m）")
        }
        XCTAssertGreaterThan(lens.last! - lens.first!, 1.0, "大力 vs 轻推路程差应显著（>1m）")
    }

    // MARK: - 加塞引起目标球偏移（squirt 移接触点 + collision throw 复合）

    /// 同一切球，左塞 / 右塞 / 无塞下目标球碰后方向应不同——加塞经 ①squirt 偏斜母球改变接触点
    /// ②碰撞 throw 共同改变目标球出射方向。本测试只守**定性属性**（加塞确实改变目标球方向），
    /// **不**断言幅值——幅值的真实标定依赖俯拍视频（见 PHYSICS-DEBT D-B1，属人工 backlog）。
    func test_scenario_englishThrow_changesObjectDirection() {
        func objectDirDeg(spinX: Float) -> Float {
            // 母球沿 +x 直行，目标球在 z 方向偏 2R·sin(cut) → 接触发生在 ~cut 切角。
            let cut: Float = 25 * .pi / 180
            let cue = SCNVector3(-0.5, surfaceY + R, 0)
            let target = SCNVector3(0.3, surfaceY + R, 2 * R * sinf(cut))
            let strike = CueBallStrike.executeStrike(aimDirection: SCNVector3(1, 0, 0), velocity: 3.5, spinX: spinX, spinY: 0)
            let engine = EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBallQiuJi(surfaceY: surfaceY))
            engine.setBall(BallState(position: cue, velocity: strike.velocity, angularVelocity: strike.angularVelocity, state: .sliding, name: "cue"))
            engine.setBall(BallState(position: target, velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero, state: .stationary, name: "obj"))
            engine.simulate(maxEvents: 400, maxTime: 8)
            // 取首次球-球碰撞后目标球的方向。
            var contactT = Float.greatestFiniteMagnitude
            for (e, ts) in zip(engine.resolvedEvents, engine.resolvedEventTimes) {
                if case .ballBall = e { contactT = min(contactT, ts) }
            }
            let frames = (engine.getTrajectoryRecorder().framesByBallName["obj"] ?? []).sorted { $0.time < $1.time }
            for f in frames where f.time >= contactT - 1e-5 && (f.velocity.x * f.velocity.x + f.velocity.z * f.velocity.z) > 0.01 {
                return atan2f(f.velocity.z, f.velocity.x) * 180 / .pi
            }
            return .nan
        }
        let none = objectDirDeg(spinX: 0)
        let left = objectDirDeg(spinX: 0.5)
        let right = objectDirDeg(spinX: -0.5)
        print(String(format: "\n[场景] 加塞 throw 目标球方向°：右塞 %.2f / 无塞 %.2f / 左塞 %.2f", right, none, left))
        XCTAssertFalse(none.isNaN || left.isNaN || right.isNaN, "应发生球-球碰撞并取到目标球方向")
        XCTAssertGreaterThan(abs(left - right), 0.3, "左/右塞应让目标球方向产生可测的 throw 差异")
        XCTAssertNotEqual(left, none, accuracy: 0.0, "加塞应改变目标球方向（相对无塞）")
    }

    // MARK: - 带塞吃库变线（side spin → 反弹切向偏移）

    /// 同一入射速度撞库，带侧旋 vs 无旋，反弹切向分量应不同（吃库变线被建模）。
    func test_scenario_cushionEnglish_shiftsRebound() {
        let normal = SCNVector3(1, 0, 0)                 // 库面法向 +x（球沿 -x 入射）
        let incoming = SCNVector3(-3, 0, 1.0)            // 斜向撞库
        let noSpin = CollisionResolver.resolveCushionCollisionPure(velocity: incoming, angularVelocity: SCNVector3Zero, normal: normal)
        let withSpin = CollisionResolver.resolveCushionCollisionPure(velocity: incoming, angularVelocity: SCNVector3(0, 40, 0), normal: normal)
        // 切向 = z 分量（库面法向沿 x）。
        let tanNo = noSpin.velocity.z
        let tanSpin = withSpin.velocity.z
        print(String(format: "\n[场景] 吃库变线：无旋反弹切向 vz=%.3f，带侧旋 vz=%.3f", tanNo, tanSpin))
        XCTAssertGreaterThan(abs(tanSpin - tanNo), 0.05, "侧旋应改变吃库后的切向分量（吃库变线）")
        // 两种情况法向都应反弹（vx 由负转正）。
        XCTAssertGreaterThan(noSpin.velocity.x, 0, "无旋应正常反弹")
        XCTAssertGreaterThan(withSpin.velocity.x, 0, "带旋应正常反弹")
    }

    // MARK: - 连续多库

    /// 母球以浅角射向角袋方向，应连续吃 ≥2 库且全程不出界、整体减速。
    func test_scenario_multiCushion_staysInBoundsAndDecelerates() {
        let strike = CueBallStrike.executeStrike(aimDirection: SCNVector3(1, 0, 0.55), velocity: 5.5, spinX: 0, spinY: 0)
        let engine = EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBallQiuJi(surfaceY: surfaceY))
        engine.setBall(BallState(position: SCNVector3(-1.0, surfaceY + R, -0.3),
                                 velocity: strike.velocity, angularVelocity: strike.angularVelocity,
                                 state: .sliding, name: "cue"))
        engine.simulate(maxEvents: 1500, maxTime: 40)
        var cushionCount = 0
        for e in engine.resolvedEvents { if case .ballCushion = e { cushionCount += 1 } }
        let frames = (engine.getTrajectoryRecorder().framesByBallName["cue"] ?? []).sorted { $0.time < $1.time }
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)
        var maxOut: Float = 0
        for f in frames {
            if abs(f.position.x) <= halfL - R + 0.02 && abs(f.position.z) <= halfW - R + 0.02 { continue }
            var nearPocket = false
            for pk in pockets { let dx = f.position.x - pk.x, dz = f.position.z - pk.z; if dx * dx + dz * dz <= 0.14 * 0.14 { nearPocket = true; break } }
            if nearPocket { continue }
            let ox = max(0, abs(f.position.x) - (halfL - R)), oz = max(0, abs(f.position.z) - (halfW - R))
            maxOut = max(maxOut, sqrtf(ox * ox + oz * oz))
        }
        let v0 = sqrtf(strike.velocity.x * strike.velocity.x + strike.velocity.z * strike.velocity.z)
        let vEnd = frames.last.map { sqrtf($0.velocity.x * $0.velocity.x + $0.velocity.z * $0.velocity.z) } ?? 0
        print(String(format: "\n[场景] 连续多库：吃库 %d 次，最坏越界 %.1fmm，速度 %.2f→%.2f m/s", cushionCount, maxOut * 1000, v0, vEnd))
        XCTAssertGreaterThanOrEqual(cushionCount, 2, "该浅角强力球应连续吃 ≥2 库")
        XCTAssertLessThan(maxOut, 0.03, "多库全程不应出界（>30mm）")
        XCTAssertLessThan(vEnd, v0, "多库后整体应减速")
    }

    // MARK: - 组合球

    /// 母球→一库→二库（三球一线的组合球）：二库应被串动、母球未直接碰二库。
    func test_scenario_combinationShot_transfersToSecondBall() {
        let cue = SCNVector3(-0.5, surfaceY + R, 0)
        let ball1 = SCNVector3(0.0, surfaceY + R, 0)
        let ball2 = SCNVector3(0.0 + 2 * R + 0.002, surfaceY + R, 0)   // 紧贴一库正前方
        let strike = CueBallStrike.executeStrike(aimDirection: SCNVector3(1, 0, 0), velocity: 4.0, spinX: 0, spinY: 0)
        let engine = EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBallQiuJi(surfaceY: surfaceY))
        engine.setBall(BallState(position: cue, velocity: strike.velocity, angularVelocity: strike.angularVelocity, state: .sliding, name: "cue"))
        engine.setBall(BallState(position: ball1, velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero, state: .stationary, name: "b1"))
        engine.setBall(BallState(position: ball2, velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero, state: .stationary, name: "b2"))
        engine.simulate(maxEvents: 800, maxTime: 20)
        let rec = engine.getTrajectoryRecorder()
        let b2Final = rec.framesByBallName["b2"]?.last?.position ?? ball2
        let b2Move = sqrtf((b2Final.x - ball2.x) * (b2Final.x - ball2.x) + (b2Final.z - ball2.z) * (b2Final.z - ball2.z))
        // 母球不应直接碰到二库（应先碰一库）。
        var cueHitB2Directly = false
        for e in engine.resolvedEvents {
            if case .ballBall(let a, let b) = e, (a == "cue" && b == "b2") || (a == "b2" && b == "cue") { cueHitB2Directly = true }
        }
        print(String(format: "\n[场景] 组合球：二库位移 %.1fmm，母球直碰二库=%@", b2Move * 1000, cueHitB2Directly ? "是" : "否"))
        XCTAssertGreaterThan(b2Move, 0.05, "组合球应把二库串动 >50mm")
        XCTAssertFalse(cueHitB2Directly, "组合球母球应先碰一库、不直接碰二库")
    }

    // MARK: - 清晰球进袋矩阵（切角 × 力度，断言进袋）

    /// 台面中心球到两角袋，切角 0/15/30/45 × 力度 2.4/3.3/4.4/5.8 共 32 组清晰球，
    /// 都应真实进袋（守 ADR-P10-03 v3.1「清晰球进袋或沿正确进球线、零翻袋坏解」）。
    func test_scenario_pottingMatrix_clearShots_allPot() {
        let sY = surfaceY
        let target = SCNVector3(0.0, sY + R, 0.0)
        var potted = 0, total = 0
        var failures: [String] = []
        for pocketIndex in [0, 1] {
            let pocket = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: sY)
            let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: pocket, ballRadius: R)
            let pdx = pocket.x - target.x, pdz = pocket.z - target.z
            let pl = sqrtf(pdx * pdx + pdz * pdz)
            let pd = SCNVector3(pdx / pl, 0, pdz / pl)
            for cutDeg in [Float(0), 15, 30, 45] {
                let th = cutDeg * .pi / 180
                let strikeDir = SCNVector3(pd.x * cosf(th) - pd.z * sinf(th), 0, pd.x * sinf(th) + pd.z * cosf(th))
                let cue = SCNVector3(ghost.x - strikeDir.x * 0.45, sY + R, ghost.z - strikeDir.z * 0.45)
                for v in [Float(2.4), 3.3, 4.4, 5.8] {
                    total += 1
                    let pred = ShotPredictor.predict(ShotInput(
                        cueBall: cue, targetBall: target, pocketIndex: pocketIndex,
                        velocity: v, spinX: 0, spinY: 0, surfaceY: sY))
                    if pred.feasible && pred.objectPocketed { potted += 1 }
                    else { failures.append(String(format: "袋%d cut%.0f v%.1f(feasible=%@,pot=%@)", pocketIndex, cutDeg, v, pred.feasible ? "Y" : "N", pred.objectPocketed ? "Y" : "N")) }
                }
            }
        }
        print(String(format: "\n[场景] 清晰球进袋矩阵：%d/%d 进袋", potted, total))
        if !failures.isEmpty { print("  未进：" + failures.joined(separator: " | ")) }
        XCTAssertEqual(potted, total, "清晰球矩阵应全部进袋（未进：\(failures.joined(separator: " | "))）")
    }
}
