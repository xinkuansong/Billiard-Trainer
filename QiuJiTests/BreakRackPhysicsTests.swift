import XCTest
import SceneKit
@testable import QiuJi

/// 中八 15 球开球的物理可行性验证（P17「球形生成器」前置去风险）。
///
/// 目标：在写任何 UI / 生成器之前，先用真实输出回答一个最大未知——
/// **项目 13 的 `EventDrivenEngine` 能否把一记 15 球开球跑到「完全停稳、不出界、不互穿、确定性」？**
///
/// 摆球几何移植自 `01.billiard_app` 的 `setupRackLayout`（同台面几何、同引擎血统）：
/// 15 球三角阵、`gap = 1mm`（01 实测：间隙过大动量传不下去 → 只撞动顶角球）、母球在开球区。
///
/// 这不是回归测试，而是**特性刻画 + blocker 探测**：跑多档开球速度，打印事件数 / 停稳速度 /
/// 进袋数 / 最小球距，并断言可行性硬约束。若断言变红（如事件数触顶 maxEvents → 快照被截断、
/// 终态仍高速 → 未停稳、终态互穿），就是 livesim 路线在动 UI 前必须先解决的 blocker。
final class BreakRackPhysicsTests: XCTestCase {

    private let R = BallPhysics.radius
    private var surfaceY: Float { BTTablePhysics.surfaceY }

    /// 开球缝隙（米）。与 `RackLayout.gap` 同源：开球三角须近似冻结（紧贴），过大间隙动量传不下去
    /// → 母球留太多能量、球堆不炸（见 `test_break15Ball_gapSweep` 实测，1mm 仅 ~5/15 散开、0.2mm ~10/15）。
    private let gap: Float = 0.0002

    // MARK: - Rack geometry（移植 01 setupRackLayout）

    /// 标准中八 15 球三角阵 + 母球（SceneKit 世界系，球心 Y = surfaceY + R）。
    /// 置球点 footSpot = −innerLength/4（左半区），三角向 −X 展开；母球在 +innerLength/4 开球线后。
    private func buildRack() -> (cue: SCNVector3, objects: [SCNVector3]) {
        buildRack(gap: gap)
    }

    /// 可变缝隙版本（诊断「球开不开」是否缝隙过大所致）。
    private func buildRack(gap: Float) -> (cue: SCNVector3, objects: [SCNVector3]) {
        let rowOffset = (R * 2 + gap) * sqrt(3.0) / 2.0
        let footSpotX = -TablePhysics.innerLength / 4
        let headX = TablePhysics.innerLength / 4
        let y = surfaceY + R

        var slots: [SCNVector3] = []
        for row in 0..<5 {
            for col in 0...row {
                let x = footSpotX - Float(row) * rowOffset
                let zStart = Float(row) * (R + gap / 2)
                let z = zStart - Float(col) * (R * 2 + gap)
                slots.append(SCNVector3(x, y, z))
            }
        }
        return (SCNVector3(headX, y, 0), slots)
    }

    /// 跑一记开球，返回引擎（含 recorder + resolvedEvents），供调用方读终态。
    private func runBreak(velocity: Float, lateral: Float = 0,
                          spinX: Float = 0, spinY: Float = 0,
                          maxEvents: Int, maxTime: Float) -> EventDrivenEngine {
        let (cue, objects) = buildRack()
        // 母球可在开球区横向偏移（仍瞄向 −X 砸向球堆顶角）。
        let cuePos = SCNVector3(cue.x, cue.y, cue.z + lateral)
        let strike = CueBallStrike.executeStrike(
            aimDirection: SCNVector3(-1, 0, 0), velocity: velocity, spinX: spinX, spinY: spinY)

        let engine = EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBallQiuJi(surfaceY: surfaceY))
        engine.setBall(BallState(position: cuePos, velocity: strike.velocity,
                                 angularVelocity: strike.angularVelocity, state: .sliding, name: "cue"))
        for (i, p) in objects.enumerated() {
            engine.setBall(BallState(position: p, velocity: SCNVector3Zero,
                                     angularVelocity: SCNVector3Zero, state: .stationary, name: "_\(i + 1)"))
        }
        engine.simulate(maxEvents: maxEvents, maxTime: maxTime, highFidelityBounds: true)
        return engine
    }

    private func speedXZ(_ v: SCNVector3) -> Float { sqrtf(v.x * v.x + v.z * v.z) }
    private func distXZ(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        sqrtf((a.x - b.x) * (a.x - b.x) + (a.z - b.z) * (a.z - b.z))
    }

    // MARK: - 0. 球架几何自检（移植正确性）

    /// 摆好的球架本身：15 颗目标球、互不重叠（最小球距应 ≈ 2R+gap）、全在台内。
    func test_rackGeometry_isValid() {
        let (cue, objects) = buildRack()
        XCTAssertEqual(objects.count, 15, "三角阵应为 15 颗目标球")

        let all = [cue] + objects
        var minDist = Float.greatestFiniteMagnitude
        for i in 0..<all.count {
            for j in (i + 1)..<all.count {
                minDist = min(minDist, distXZ(all[i], all[j]))
            }
        }
        XCTAssertGreaterThanOrEqual(minDist, 2 * R - 1e-5,
            "球架初始互穿，最小球距 \(minDist * 1000)mm < 2R=\(2 * R * 1000)mm")

        let halfL = TablePhysics.innerLength / 2 - R
        let halfW = TablePhysics.innerWidth / 2 - R
        for (i, p) in objects.enumerated() {
            XCTAssertLessThanOrEqual(abs(p.x), halfL, "目标球 \(i + 1) 出界 X=\(p.x)")
            XCTAssertLessThanOrEqual(abs(p.z), halfW, "目标球 \(i + 1) 出界 Z=\(p.z)")
        }
        print(String(format: "[BREAK-rack] 15 球三角阵就绪，最小球距 %.2fmm（= 2R+gap 期望 %.2fmm）",
                     minDist * 1000, (2 * R + gap) * 1000))
    }

    // MARK: - 1. 多档开球速度特性刻画 + 可行性断言

    func test_break15Ball_characterizeAcrossSpeeds() {
        let speeds: [Float] = [3.0, 4.0, 5.0, 6.0, 7.0]
        let maxEvents = 8000
        let maxTime: Float = 30

        print("[BREAK] 15 球开球特性（gap=\(gap * 1000)mm, maxEvents=\(maxEvents), maxTime=\(maxTime)s）")
        print("   v(m/s)  events    potted   maxV(m/s)  minDist(mm)  settled")

        for v in speeds {
            let engine = runBreak(velocity: v, maxEvents: maxEvents, maxTime: maxTime)
            let balls = engine.getAllBalls()
            let alive = balls.filter { $0.state != .pocketed }
            let potted = balls.count - alive.count
            let maxV = alive.map { speedXZ($0.velocity) }.max() ?? 0

            var minDist = Float.greatestFiniteMagnitude
            for i in 0..<alive.count {
                for j in (i + 1)..<alive.count {
                    minDist = min(minDist, distXZ(alive[i].position, alive[j].position))
                }
            }
            let events = engine.resolvedEvents.count
            let settled = maxV < 0.05

            print(String(format: "   %5.1f   %5d     %3d      %8.3f    %8.2f     %@",
                         v, events, potted, maxV,
                         minDist == .greatestFiniteMagnitude ? 0 : minDist * 1000,
                         settled ? "YES" : "NO"))

            // —— 可行性硬约束 ——
            // (a) 事件数未触顶：否则模拟被 maxEvents 截断，终态快照里有球还在动 = 脏数据。
            XCTAssertLessThan(events, maxEvents,
                "v=\(v): 事件数触顶 \(maxEvents) → 模拟被截断，开球快照不可信（需调高预算或引擎扛不住）")
            // (b) 全部停稳：没有球残留运动。
            XCTAssertLessThan(maxV, 0.3,
                "v=\(v): 终态仍有球高速 \(maxV) m/s → 未停稳")
            // (c) 不出界：未进袋球都在可玩区内（留 2cm 容差）。
            let halfL = TablePhysics.innerLength / 2 - R + 0.02
            let halfW = TablePhysics.innerWidth / 2 - R + 0.02
            for b in alive {
                XCTAssertLessThanOrEqual(abs(b.position.x), halfL, "v=\(v) 球 \(b.name) 终态出界 X=\(b.position.x)")
                XCTAssertLessThanOrEqual(abs(b.position.z), halfW, "v=\(v) 球 \(b.name) 终态出界 Z=\(b.position.z)")
            }
            // (d) 不互穿：终态任意两未进袋球球心距 ≥ 2R（留 3mm 数值容差，与既有不变量一致）。
            if alive.count >= 2 {
                XCTAssertGreaterThan(minDist, 2 * R - 0.003,
                    "v=\(v): 终态球互穿，最小球距 \(minDist * 1000)mm")
            }
        }
    }

    // MARK: - 2. 开球级联中的全程互穿（最危险时刻：密堆首次炸开）

    /// 球堆炸开的头几十毫秒是 CCD 最严苛的时刻（多体近同时碰撞，FL-022 血统）。
    /// 抽样全程帧，断言任意两未进袋球的球心距不低于 2R（容差与既有 overlap 不变量一致）。
    func test_break15Ball_noOverlapDuringCascade() {
        let engine = runBreak(velocity: 5.0, maxEvents: 8000, maxTime: 30)
        let rec = engine.getTrajectoryRecorder()

        // 收集去重时间戳。
        var seen = Set<Int>()
        var times: [Float] = []
        for (_, frames) in rec.framesByBallName {
            for f in frames {
                let key = Int((f.time * 5000).rounded())
                if seen.insert(key).inserted { times.append(f.time) }
            }
        }
        times.sort()

        let names = engine.getAllBalls().map { $0.name }
        let tol: Float = 0.003
        var worst: Float = 0
        for ts in times {
            var alive: [SCNVector3] = []
            for n in names {
                guard let f = rec.stateAt(ballName: n, time: ts), f.state != .pocketed else { continue }
                alive.append(f.position)
            }
            for i in 0..<alive.count {
                for j in (i + 1)..<alive.count {
                    let d = distXZ(alive[i], alive[j])
                    worst = max(worst, max(0, 2 * R - d))
                    XCTAssertGreaterThanOrEqual(d, 2 * R - tol,
                        "t=\(ts): 开球级联中球互穿 \((2 * R - d) * 1000)mm")
                }
            }
        }
        print(String(format: "[BREAK-overlap] 全程最坏穿透 %.2fmm（应 ≤ %.1fmm）", worst * 1000, tol * 1000))
    }

    // MARK: - 2b. 散布度诊断（不变量过 ≠ 真炸开：验证动量是否真传遍球堆）

    /// 通过的不变量只证明「引擎不崩」，不证明「球真的散开」。此诊断量化开球后球堆的铺开程度：
    /// 每球相对摆位的位移、铺开包围盒、移动超过阈值的球数。若多数球几乎没动（位移≈0、
    /// 包围盒≈球堆原尺寸），就是 01 警告的「动量传不下去」哑火，livesim 直接出脏球形。
    func test_break15Ball_diagnoseSpread() {
        let velocities: [Float] = [4.0, 6.0, 8.0]
        for v in velocities {
            let (cue, objects) = buildRack()
            let cuePos = SCNVector3(cue.x, cue.y, cue.z + 0.04)   // 略偏，制造非正中开球
            let strike = CueBallStrike.executeStrike(
                aimDirection: SCNVector3(-1, 0, 0), velocity: v, spinX: 0, spinY: 0)
            let engine = EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBallQiuJi(surfaceY: surfaceY))
            engine.setBall(BallState(position: cuePos, velocity: strike.velocity,
                                     angularVelocity: strike.angularVelocity, state: .sliding, name: "cue"))
            for (i, p) in objects.enumerated() {
                engine.setBall(BallState(position: p, velocity: SCNVector3Zero,
                                         angularVelocity: SCNVector3Zero, state: .stationary, name: "_\(i + 1)"))
            }
            engine.simulate(maxEvents: 8000, maxTime: 30, highFidelityBounds: true)

            let balls = engine.getAllBalls()
            var travels: [Float] = []
            var minX = Float.greatestFiniteMagnitude, maxX = -Float.greatestFiniteMagnitude
            var minZ = Float.greatestFiniteMagnitude, maxZ = -Float.greatestFiniteMagnitude
            var pocketed = 0
            for (i, start) in objects.enumerated() {
                guard let b = balls.first(where: { $0.name == "_\(i + 1)" }) else { continue }
                if b.state == .pocketed { pocketed += 1; continue }
                travels.append(distXZ(b.position, start))
                minX = min(minX, b.position.x); maxX = max(maxX, b.position.x)
                minZ = min(minZ, b.position.z); maxZ = max(maxZ, b.position.z)
            }
            let mean = travels.isEmpty ? 0 : travels.reduce(0, +) / Float(travels.count)
            let maxT = travels.max() ?? 0
            let moved10 = travels.filter { $0 > 0.10 }.count
            let moved30 = travels.filter { $0 > 0.30 }.count
            let bboxX = (maxX - minX), bboxZ = (maxZ - minZ)
            let cueFinal = balls.first(where: { $0.name == "cue" })
            let cueTravel = cueFinal.map { distXZ($0.position, cuePos) } ?? 0

            print(String(format: """
            [BREAK-spread v=%.1f] 进袋 %d · 均位移 %.0fmm · 最大位移 %.0fmm · 移动>10cm %d/15 · 移动>30cm %d/15
                铺开包围盒 X=%.0fcm Z=%.0fcm（台面 X=254cm Z=127cm；球堆原尺寸约 X=10cm Z=12cm）
                母球位移 %.0fmm（终位 x=%.2f z=%.2f）
            """, v, pocketed, mean * 1000, maxT * 1000, moved10, moved30,
                 bboxX * 100, bboxZ * 100, cueTravel * 1000,
                 cueFinal?.position.x ?? 0, cueFinal?.position.z ?? 0))
        }
    }

    // MARK: - 2c. 缝隙扫描（诊断「球开不开」根因：gap 过大 → 母球留太多能量、球堆不炸）

    /// 母球**对准顶角球心**全砸（与 App `aimAtApex` 一致，非诊断里的薄打），扫不同 gap 看散布。
    /// 关键观测：母球终位移（理想：全砸后母球应大量卸能、行程短）+ 移动球数 + 铺开包围盒。
    func test_break15Ball_gapSweep() {
        let gaps: [Float] = [0.0001, 0.0002, 0.0003, 0.0005, 0.001, 0.002]
        let v: Float = 7.0
        // 多个小瞄准偏角 + 微塞采样，平掉单杆混沌噪声，看 gap 的真实趋势。
        let aimDegs: [Float] = [-1.5, -0.8, 0, 0.8, 1.5]
        print("[GAP-SWEEP] 母球对准顶角全砸 v=\(v)m/s，每 gap 对 \(aimDegs.count) 个瞄准偏角取均值")
        print("   gap(mm)  avgMoved>30cm  avgMeanTravel(mm)  avgCueTravel(mm)  avgBboxX(cm)  worstMinDist(mm) allSettled")
        for g in gaps {
            var sumMoved30 = 0, sampleCount = 0
            var sumMean: Float = 0, sumCue: Float = 0, sumBbox: Float = 0
            var worstMinDist = Float.greatestFiniteMagnitude
            var allSettled = true
            for deg in aimDegs {
                let (cue, objects) = buildRack(gap: g)
                let aim = SCNVector3(-1, 0, 0).rotatedY(deg * .pi / 180)
                let strike = CueBallStrike.executeStrike(aimDirection: aim, velocity: v, spinX: 0, spinY: 0)
                let engine = EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBallQiuJi(surfaceY: surfaceY))
                engine.setBall(BallState(position: cue, velocity: strike.velocity,
                                         angularVelocity: strike.angularVelocity, state: .sliding, name: "cue"))
                for (i, p) in objects.enumerated() {
                    engine.setBall(BallState(position: p, velocity: SCNVector3Zero,
                                             angularVelocity: SCNVector3Zero, state: .stationary, name: "_\(i + 1)"))
                }
                engine.simulate(maxEvents: 8000, maxTime: 30, highFidelityBounds: true)

                let balls = engine.getAllBalls()
                let alive = balls.filter { $0.state != .pocketed }
                var travels: [Float] = []
                var minX = Float.greatestFiniteMagnitude, maxX = -Float.greatestFiniteMagnitude
                for (i, start) in objects.enumerated() {
                    guard let b = balls.first(where: { $0.name == "_\(i + 1)" }), b.state != .pocketed else { continue }
                    travels.append(distXZ(b.position, start))
                    minX = min(minX, b.position.x); maxX = max(maxX, b.position.x)
                }
                var minDist = Float.greatestFiniteMagnitude
                for i in 0..<alive.count {
                    for j in (i + 1)..<alive.count { minDist = min(minDist, distXZ(alive[i].position, alive[j].position)) }
                }
                sumMoved30 += travels.filter { $0 > 0.30 }.count
                sumMean += travels.isEmpty ? 0 : travels.reduce(0, +) / Float(travels.count)
                sumCue += balls.first(where: { $0.name == "cue" }).map { distXZ($0.position, cue) } ?? 0
                sumBbox += (maxX - minX)
                worstMinDist = min(worstMinDist, minDist)
                if (alive.map { speedXZ($0.velocity) }.max() ?? 0) >= 0.05 { allSettled = false }
                sampleCount += 1
            }
            let n = Float(sampleCount)
            print(String(format: "   %5.2f      %5.1f/15        %6.0f             %6.0f            %5.0f        %6.2f         %@",
                         g * 1000, Float(sumMoved30) / n, sumMean / n * 1000, sumCue / n * 1000,
                         sumBbox / n * 100, worstMinDist * 1000, allSettled ? "YES" : "NO"))
        }
    }

    // MARK: - 3. 确定性（同一开球跑两次终态逐球一致）

    func test_break15Ball_deterministic() {
        func finals() -> [(name: String, pos: SCNVector3)] {
            let e = runBreak(velocity: 5.0, lateral: 0.05, maxEvents: 8000, maxTime: 30)
            return e.getAllBalls().map { ($0.name, $0.position) }.sorted { $0.0 < $1.0 }
        }
        let a = finals(), b = finals()
        XCTAssertEqual(a.count, b.count, "两次开球球数不一致 \(a.count) vs \(b.count)")
        for (x, y) in zip(a, b) {
            XCTAssertEqual(x.name, y.name)
            XCTAssertEqual(x.pos.x, y.pos.x, accuracy: 1e-4, "\(x.name) 终态 X 运行间不一致")
            XCTAssertEqual(x.pos.z, y.pos.z, accuracy: 1e-4, "\(x.name) 终态 Z 运行间不一致")
        }
        print("[BREAK-determinism] 同一开球两次终态逐球一致（≤1e-4 m）")
    }
}
