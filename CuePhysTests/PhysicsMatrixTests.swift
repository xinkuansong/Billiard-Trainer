import XCTest
import SceneKit
@testable import QiuJi

/// 系统化组合矩阵（D-C1/C2 大规模扩面）——以**确定性网格**枚举数百~上千个不同球形/袋口/
/// 切角/力度/塞组合，逐例断言「生产合约」，失败时打印**精确复现参数**（不是随机批量的"最坏值"，
/// 而是可定位到具体哪一格崩了）。这是真实台球复杂度护栏的主力：P10/P11 的返工史几乎全在
/// 进袋/走位这块，量级必须到几百才扛得住"改一处崩一处"。
///
/// 两张矩阵：
///   1. `solverPottingContract` — 完整 `ShotPredictor.predict` 闭环求解，断言 ADR-P10-03 v3.1
///      合约：可行球进袋或沿正确进球线、轨迹不出界、画面=物理（进袋则显示轨迹抵达袋口）。
///   2. `rawGeometryLaunchLine` — 裸引擎幽灵球直瞄（中心球），断言目标球**出射方向**恒沿
///      进球线（仅 throw 几度偏差），覆盖全台几何 + 统计穿库逃逸率（回归守 8%→2.7%）。
final class PhysicsMatrixTests: XCTestCase {

    private let R = BallPhysics.radius
    private var surfaceY: Float { BTTablePhysics.surfaceY }

    // MARK: - 矩阵 1：求解器进袋合约（完整 predict）

    /// 6 目标球位 × 6 袋口 × 3 切角 × 2 力度 = 216 组（几何不可行者跳过）。
    /// 逐例断言：可行 ⇒ 母球/目标球显示轨迹全在可玩区+袋口嘴内；进袋 ⇒ 目标球显示轨迹末端
    /// 落在选定袋落袋窗内（画面=物理）。统计进袋率并打印未进清单（复现用）。
    func test_matrix_solverPottingContract() {
        let sY = surfaceY
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: sY)
        let targets: [SCNVector3] = [
            SCNVector3(0.0, sY + R, 0.0),     // 中心
            SCNVector3(0.6, sY + R, 0.0),     // 右半台
            SCNVector3(-0.6, sY + R, 0.0),    // 左半台
            SCNVector3(0.3, sY + R, 0.3),     // 偏角
            SCNVector3(-0.3, sY + R, -0.3),   // 偏角
            SCNVector3(0.9, sY + R, 0.2),     // 近右长库
        ]
        var total = 0, feasible = 0, potted = 0
        var boundsViolations: [String] = []
        var displayMismatches: [String] = []
        var notPotted: [String] = []
        var objBankPots: [String] = []     // 目标球吃库后才进袋（含贴库滚进，含撞库点距离）
        var grossBanks: [String] = []       // 远处真翻袋坏解（撞库点离目标袋 >0.4m）
        var cuePreBank: [String] = []       // 母球碰目标球前先吃库（绕库/kick 坏解）

        for (ti, target) in targets.enumerated() {
            for pocketIndex in 0..<6 {
                let pocket = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: sY)
                let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: pocket, ballRadius: R)
                let pdx = pocket.x - target.x, pdz = pocket.z - target.z
                let pl = sqrtf(pdx * pdx + pdz * pdz)
                guard pl > 1e-3 else { continue }
                let pd = SCNVector3(pdx / pl, 0, pdz / pl)
                for cutDeg in [Float(10), 25, 40] {
                    for sign in [Float(1), -1] {
                        let th = cutDeg * .pi / 180 * sign
                        let strikeDir = SCNVector3(pd.x * cosf(th) - pd.z * sinf(th), 0, pd.x * sinf(th) + pd.z * cosf(th))
                        let cue = SCNVector3(ghost.x - strikeDir.x * 0.45, sY + R, ghost.z - strikeDir.z * 0.45)
                        // 跳过母球出界或与目标球重叠的无效摆位。
                        if abs(cue.x) > halfL - R || abs(cue.z) > halfW - R { continue }
                        if horizontalDist(cue, target) < 2.2 * R { continue }
                        for v in [Float(2.8), 4.2] {
                            total += 1
                            let id = "t\(ti)p\(pocketIndex)c\(Int(cutDeg))s\(sign > 0 ? "+" : "-")v\(v)"
                            let pred = ShotPredictor.predict(ShotInput(
                                cueBall: cue, targetBall: target, pocketIndex: pocketIndex,
                                velocity: v, spinX: 0, spinY: 0, surfaceY: sY))
                            guard pred.feasible else { continue }
                            feasible += 1
                            // 合约 1：显示轨迹不出界。
                            for p in pred.cuePath + pred.objectPath where !boundsContains(p, halfL: halfL, halfW: halfW, pockets: pockets, margin: 0.02) {
                                boundsViolations.append(id); break
                            }
                            // 合约 2：进袋 ⇒ 目标球显示轨迹末端落在选定袋落袋窗内。
                            if pred.objectPocketed {
                                potted += 1
                                if let last = pred.objectPath.last {
                                    let pc = pockets[pocketIndex]
                                    let d = sqrtf((last.x - pc.x) * (last.x - pc.x) + (last.z - pc.z) * (last.z - pc.z))
                                    let window = AngleSceneCalculator.pocketDropRadius(index: pocketIndex) + 0.01
                                    if d > window { displayMismatches.append("\(id)(末端距袋\(Int(d * 1000))mm)") }
                                }
                                // 合约 3：目标球落袋前若吃库（objectCushionCount>0），定位撞库点离目标袋距离——
                                // 贴库滚进袋角（≤0.4m，benign）vs 远处真翻袋坏解（FAIL）。
                                if pred.objectCushionCount > 0 {
                                    let bend = objectBendDistanceToPocket(pred.recorder, pocket: pockets[pocketIndex])
                                    objBankPots.append(String(format: "\(id)(吃库\(pred.objectCushionCount)@%.0fmm)", bend * 1000))
                                    if bend > 0.4 { grossBanks.append(String(format: "\(id)(撞库点离袋%.0fmm)", bend * 1000)) }
                                }
                                // 合约 4：母球碰到目标球前不吃库（权威字段，否则是绕库/kick 坏解）。
                                if pred.cueCushionsBeforeContact > 0 { cuePreBank.append("\(id)(母球先吃库\(pred.cueCushionsBeforeContact))") }
                            } else {
                                notPotted.append(id)
                            }
                        }
                    }
                }
            }
        }
        print(String(format: "\n[矩阵1·求解器] 共 %d 组，可行 %d，进袋 %d（进袋率 %.0f%%）",
                     total, feasible, potted, feasible > 0 ? Double(potted) / Double(feasible) * 100 : 0))
        if !notPotted.isEmpty { print("  可行未进(沿线停袋前，正常)：\(notPotted.count) 组") }
        print("  [线干净诊断] 母球接触前先吃库：\(cuePreBank.count) 组；目标球落袋前吃库：\(objBankPots.count) 组（其中远处真翻袋坏解 \(grossBanks.count) 组）")
        if !objBankPots.isEmpty { print("    目标吃库样本：\(objBankPots.prefix(12).joined(separator: ", "))") }
        if !cuePreBank.isEmpty { print("    母球绕库样本：\(cuePreBank.prefix(12).joined(separator: ", "))") }
        XCTAssertGreaterThan(feasible, 100, "可行样本应达百量级")
        XCTAssertTrue(boundsViolations.isEmpty, "出界违例（轨迹飞出台面）：\(boundsViolations.prefix(10).joined(separator: ", "))")
        XCTAssertTrue(displayMismatches.isEmpty, "画面≠物理（报进袋但显示轨迹未抵达袋口）：\(displayMismatches.prefix(10).joined(separator: ", "))")
        // 你的合约：直球求解里母球碰目标球前不吃库、目标球不应「远处翻袋」进。
        XCTAssertTrue(cuePreBank.isEmpty, "母球碰目标球前先吃库（绕库/kick 坏解）：\(cuePreBank.prefix(10).joined(separator: ", "))")
        XCTAssertTrue(grossBanks.isEmpty, "目标球远处翻袋进袋（>0.4m 撞库改向的坏解）：\(grossBanks.prefix(10).joined(separator: ", "))")
    }

    // MARK: - 矩阵 2：裸引擎出射方向沿进球线（全台几何，大规模）

    /// 目标球位网格（5×3）× 6 袋口 × 切角 0..50（6）× 力度（3）= 上千组中心球幽灵球直瞄。
    /// 逐例断言：目标球**出射方向**与进球线（目标球→袋心）夹角 ≤ 12°（中心球仅 throw 偏差），
    /// 即全台任意几何下进球线方向都正确（守 ADR-P10-03 v3.1「零翻袋坏解」）。
    /// 同时统计穿库逃逸率（回归守护 8%→2.7%）。
    func test_matrix_rawGeometryLaunchLine() {
        let sY = surfaceY
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: sY)

        var targets: [SCNVector3] = []
        for tx in stride(from: Float(-0.9), through: 0.9, by: 0.45) {
            for tz in stride(from: Float(-0.4), through: 0.4, by: 0.4) {
                targets.append(SCNVector3(tx, sY + R, tz))
            }
        }

        var total = 0, evaluated = 0, escapes = 0
        var worstDirErr: Float = 0
        var dirViolations: [String] = []

        for (ti, target) in targets.enumerated() {
            for pocketIndex in 0..<6 {
                let pocket = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: sY)
                let aimLine = unit(SCNVector3(pocket.x - target.x, 0, pocket.z - target.z))
                let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: pocket, ballRadius: R)
                guard aimLine.x != 0 || aimLine.z != 0 else { continue }
                for cutDeg in [Float(0), 10, 20, 30, 40, 50] {
                    for sign in [Float(1), -1] {
                        if cutDeg == 0 && sign < 0 { continue }
                        let th = cutDeg * .pi / 180 * sign
                        let strikeDir = SCNVector3(aimLine.x * cosf(th) - aimLine.z * sinf(th), 0, aimLine.x * sinf(th) + aimLine.z * cosf(th))
                        let cue = SCNVector3(ghost.x - strikeDir.x * 0.4, sY + R, ghost.z - strikeDir.z * 0.4)
                        if abs(cue.x) > halfL - R || abs(cue.z) > halfW - R { continue }
                        if horizontalDist(cue, target) < 2.2 * R { continue }
                        for v in [Float(2.4), 3.6, 5.0] {
                            total += 1
                            let strike = CueBallStrike.executeStrike(aimDirection: unit(SCNVector3(ghost.x - cue.x, 0, ghost.z - cue.z)), velocity: v, spinX: 0, spinY: 0)
                            let engine = EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBallQiuJi(surfaceY: sY))
                            engine.setBall(BallState(position: cue, velocity: strike.velocity, angularVelocity: strike.angularVelocity, state: .sliding, name: "cue"))
                            engine.setBall(BallState(position: target, velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero, state: .stationary, name: "obj"))
                            engine.simulate(maxEvents: 500, maxTime: 12)

                            // 逃逸统计（任一球记录帧远离可玩区+袋口嘴）。
                            if didEscape(engine, halfL: halfL, halfW: halfW, pockets: pockets) { escapes += 1 }

                            // 出射方向：首次球-球碰撞后目标球方向 vs 进球线。
                            var contactT = Float.greatestFiniteMagnitude
                            for (e, ts) in zip(engine.resolvedEvents, engine.resolvedEventTimes) {
                                if case .ballBall = e { contactT = min(contactT, ts) }
                            }
                            guard contactT < .greatestFiniteMagnitude else { continue }
                            let frames = (engine.getTrajectoryRecorder().framesByBallName["obj"] ?? []).sorted { $0.time < $1.time }
                            var launchDir: SCNVector3?
                            for f in frames where f.time >= contactT - 1e-5 && (f.velocity.x * f.velocity.x + f.velocity.z * f.velocity.z) > 0.04 {
                                launchDir = f.velocity; break
                            }
                            guard let dir = launchDir else { continue }
                            evaluated += 1
                            let err = angleDeg(dir, aimLine)
                            worstDirErr = max(worstDirErr, err)
                            if err > 12 { dirViolations.append(String(format: "t\(ti)p\(pocketIndex)c%.0f%@v%.1f(err%.1f°)", cutDeg, sign > 0 ? "+" : "-", v, err)) }
                        }
                    }
                }
            }
        }
        let escapeRate = total > 0 ? Double(escapes) / Double(total) * 100 : 0
        print(String(format: "\n[矩阵2·裸引擎几何] 共 %d 组，评估出射方向 %d 组，最坏方向误差 %.1f°，逃逸率 %.1f%%（%d/%d）",
                     total, evaluated, worstDirErr, escapeRate, escapes, total))
        if !dirViolations.isEmpty { print("  方向越界(>12°)：\(dirViolations.prefix(12).joined(separator: ", "))") }
        XCTAssertGreaterThan(evaluated, 300, "评估样本应达数百量级")
        XCTAssertTrue(dirViolations.isEmpty, "目标球出射方向偏离进球线 >12°（疑似翻袋坏解/几何错位）：\(dirViolations.prefix(12).joined(separator: ", "))")
        XCTAssertLessThan(escapeRate, 6.0, "穿库逃逸率 \(escapeRate)% 回归超阈（应 ≤6%，当前基线 ~2.7%）")
    }

    // MARK: - 矩阵 3：直球求解不选 kick 退化解 + 运行间宏观确定性（回归守 FL）

    /// 回归守护：先前 t3p5/t3p4/t4p4 等球形的求解器会在「干净直击」与「母球绕 4 库再碰目标球」
    /// 两个完全不同的解之间运行间随机翻转（cuePreBank 0↔4、分离角跨 2°、偶尔打丢）——根因是
    /// 最优区(−10)未要求「母球碰目标球前 0 吃库」，让歪打正着的 kick 解与直击解打平 + 引擎遍历
    /// 浮点非确定性。修复后 `solveAimOffset` 最优区强制 `cueCushionsBeforeContact == 0`。
    /// 本用例对历史翻转球形各连跑 20 次，断言：母球碰目标球前恒 0 吃库、进袋稳定、分离角宏观稳定。
    func test_matrix_solverPicksDirectNotKick_deterministic() {
        let sY = surfaceY
        let cases: [(SCNVector3, Int, Float, Float)] = [
            (SCNVector3(0.3, sY + R, 0.3), 5, 10, 2.8),   // t3p5
            (SCNVector3(0.3, sY + R, 0.3), 4, 40, 4.2),   // t3p4
            (SCNVector3(-0.3, sY + R, -0.3), 4, 10, 2.8), // t4p4
        ]
        for (idx, c) in cases.enumerated() {
            let (target, pocketIndex, cutDeg, v) = c
            let pocket = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: sY)
            let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: pocket, ballRadius: R)
            let pdx = pocket.x - target.x, pdz = pocket.z - target.z
            let pl = max(sqrtf(pdx * pdx + pdz * pdz), 1e-5)
            let pd = SCNVector3(pdx / pl, 0, pdz / pl)
            let sign: Float = idx == 0 ? 1 : (idx == 1 ? -1 : 1)
            let th = cutDeg * .pi / 180 * sign
            let strikeDir = SCNVector3(pd.x * cosf(th) - pd.z * sinf(th), 0, pd.x * sinf(th) + pd.z * cosf(th))
            let cue = SCNVector3(ghost.x - strikeDir.x * 0.45, sY + R, ghost.z - strikeDir.z * 0.45)
            var maxPre = 0
            var pottedCount = 0
            var sepMin = Float.greatestFiniteMagnitude, sepMax = -Float.greatestFiniteMagnitude
            let runs = 20
            for _ in 0..<runs {
                let p = ShotPredictor.predict(ShotInput(cueBall: cue, targetBall: target, pocketIndex: pocketIndex, velocity: v, spinX: 0, spinY: 0, surfaceY: sY))
                maxPre = max(maxPre, p.cueCushionsBeforeContact)
                if p.objectPocketed { pottedCount += 1 }
                if let s = p.separationAngleDeg { sepMin = min(sepMin, Float(s)); sepMax = max(sepMax, Float(s)) }
            }
            let sepSpread = sepMax - sepMin
            print(String(format: "[矩阵3·确定性] case%d：cuePreBank max=%d，进袋 %d/%d，分离角跨度 %.2f°", idx, maxPre, pottedCount, runs, sepSpread))
            XCTAssertEqual(maxPre, 0, "case\(idx): 求解器仍选到母球绕库 kick 解（cuePreBank=\(maxPre)）")
            XCTAssertEqual(pottedCount, runs, "case\(idx): 进袋不稳定 \(pottedCount)/\(runs)（运行间翻转）")
            XCTAssertLessThan(sepSpread, 0.5, "case\(idx): 分离角运行间跨度 \(sepSpread)°（宏观非确定性未消除）")
        }
    }

    // MARK: - Helpers

    /// 从求解器的权威显示轨迹里找目标球「转向最急的点」（≈撞库反弹处），返回它到目标袋的距离。
    /// 用于区分「贴库滚进所瞄袋角」(近，benign) 与「远处撞库改向的翻袋坏解」(远，FAIL)。
    private func objectBendDistanceToPocket(_ recorder: TrajectoryRecorder?, pocket: SCNVector3) -> Float {
        guard let frames = recorder?.framesByBallName[ShotInput.targetBallName]?.sorted(by: { $0.time < $1.time }), frames.count >= 3 else { return 0 }
        var prevDir: SCNVector3?
        var worstTurn: Float = -1
        var bendPos = pocket
        for i in 1..<frames.count {
            let d = SCNVector3(frames[i].position.x - frames[i - 1].position.x, 0, frames[i].position.z - frames[i - 1].position.z)
            if (d.x * d.x + d.z * d.z) < 1e-6 { continue }
            let dir = unit(d)
            if let pv = prevDir {
                let turn = angleDeg(dir, pv)
                if turn > worstTurn { worstTurn = turn; bendPos = frames[i - 1].position }
            }
            prevDir = dir
        }
        guard worstTurn > 10 else { return 0 } // 无明显转向（直线进袋）→ 视作 0 距离（benign）。
        return sqrtf((bendPos.x - pocket.x) * (bendPos.x - pocket.x) + (bendPos.z - pocket.z) * (bendPos.z - pocket.z))
    }

    private func didEscape(_ engine: EventDrivenEngine, halfL: Float, halfW: Float, pockets: [SCNVector3]) -> Bool {
        for (_, frames) in engine.getTrajectoryRecorder().framesByBallName {
            for f in frames {
                if f.state == .pocketed { continue }
                if abs(f.position.x) <= halfL - R + 0.02 && abs(f.position.z) <= halfW - R + 0.02 { continue }
                var nearPocket = false
                for pk in pockets { let dx = f.position.x - pk.x, dz = f.position.z - pk.z; if dx * dx + dz * dz <= 0.14 * 0.14 { nearPocket = true; break } }
                if !nearPocket { return true }
            }
        }
        return false
    }

    private func boundsContains(_ p: SCNVector3, halfL: Float, halfW: Float, pockets: [SCNVector3], margin: Float) -> Bool {
        if abs(p.x) <= halfL - R + margin && abs(p.z) <= halfW - R + margin { return true }
        let mouth: Float = 0.12 + margin
        for pk in pockets { let dx = p.x - pk.x, dz = p.z - pk.z; if dx * dx + dz * dz <= mouth * mouth { return true } }
        return false
    }

    private func angleDeg(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let da = unit(a), db = unit(b)
        let dot = max(-1, min(1, da.x * db.x + da.z * db.z))
        return acosf(dot) * 180 / .pi
    }

    private func unit(_ v: SCNVector3) -> SCNVector3 {
        let len = sqrtf(v.x * v.x + v.z * v.z)
        guard len > 1e-6 else { return SCNVector3(1, 0, 0) }
        return SCNVector3(v.x / len, 0, v.z / len)
    }

    private func horizontalDist(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dx = a.x - b.x, dz = a.z - b.z
        return sqrtf(dx * dx + dz * dz)
    }
}
