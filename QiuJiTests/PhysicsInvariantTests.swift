import XCTest
import SceneKit
@testable import QiuJi

/// 物理不变量护栏（D-C1）+ 确定性护栏（D-C3）。
///
/// 区别于既有的「事后回归/诊断」测试（`test_diag_*`/`scan*`/`*_report`），本套件用
/// **批量随机化击球**断言一组**物理不变量**——它们与具体球形无关，是任何正确的事件驱动
/// 引擎都必须恒满足的硬约束：
///   1. 能量耗散单调（总动能不超过初始；摩擦 + 非弹性碰撞只会移除能量）。
///   2. 不重叠（任意两颗未进袋球的球心距 ≥ 2R）。
///   3. 不出界（生产钳制轨迹始终落在可玩区或袋口嘴内）。
///   4. 确定性（同一输入重复 predict / simulate 逐帧一致）。
///
/// 这是后续任何重构（拆 `EventDrivenEngine`、下沉显示闸门）的安全网：重构若破坏守恒律或
/// 引入非确定性，这里会立刻变红，而不必靠肉眼看 PNG 发现。
///
/// 随机性用**可复现的 SplitMix64 种子 PRNG**，失败可精确重放。
final class PhysicsInvariantTests: XCTestCase {

    private let R = BallPhysics.radius
    private let mass = BallPhysics.mass
    /// 实心球转动惯量 I = 2/5 m R²。
    private var inertia: Float { 0.4 * mass * R * R }
    private var surfaceY: Float { BTTablePhysics.surfaceY }

    // MARK: - 1. 能量耗散单调（D-C1）

    /// 批量随机单杆（母球 + 1 目标球）：每一帧的系统总动能（平动 + 转动）都不应超过初始
    /// 总动能（含 2% 浮点 + 数值容差）。摩擦与非弹性碰撞只能耗散能量，引擎绝不应「造能」。
    func test_invariant_energyNeverExceedsInitial() {
        var rng = SeededRNG(seed: 0xB17A_2D05)
        let trials = 250
        var worstRatio: Float = 0
        for t in 0..<trials {
            let cue = randomBallPos(&rng)
            var target = randomBallPos(&rng)
            // 避免初始重叠。
            var guardCount = 0
            while horizontalDist(cue, target) < 3 * R && guardCount < 20 {
                target = randomBallPos(&rng); guardCount += 1
            }
            let aim = randomUnitXZ(&rng)
            let velocity = rng.float(in: 1.5...5.5)
            let (sx, sy) = randomSpinWithinMiscue(&rng)
            let strike = CueBallStrike.executeStrike(aimDirection: aim, velocity: velocity, spinX: sx, spinY: sy)

            let engine = EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBallQiuJi(surfaceY: surfaceY))
            engine.setBall(BallState(position: SCNVector3(cue.x, surfaceY + R, cue.z),
                                     velocity: strike.velocity, angularVelocity: strike.angularVelocity,
                                     state: .sliding, name: "cue"))
            engine.setBall(BallState(position: SCNVector3(target.x, surfaceY + R, target.z),
                                     velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero,
                                     state: .stationary, name: "obj"))
            engine.simulate(maxEvents: 500, maxTime: 15)

            let rec = engine.getTrajectoryRecorder()
            let initialE = systemEnergy(rec, at: 0)
            guard initialE > 1e-6 else { continue }

            // 收集所有时间戳并逐帧求和（多球同一时刻在不同帧列表里）。
            for ts in frameTimes(rec) {
                let e = systemEnergy(rec, at: ts)
                let ratio = e / initialE
                worstRatio = max(worstRatio, ratio)
                XCTAssertLessThanOrEqual(ratio, 1.02,
                    "trial \(t) t=\(ts): 总动能 \(e) J 超过初始 \(initialE) J（造能，违反耗散律）")
            }
        }
        print(String(format: "[INV-energy] %d 次随机单杆，最坏 E/E0 = %.4f（应 ≤ 1.02）", trials, worstRatio))
    }

    // MARK: - 2. 不重叠（D-C1）

    /// 批量随机多球（母球 + 2 静止球）：模拟全程任意两颗未进袋球的球心距 ≥ 2R − 容差。
    /// 引擎的 `separateOverlappingBalls` + 碰撞 CCD 应保证球不互穿。
    func test_invariant_noBallOverlapDuringSimulation() {
        var rng = SeededRNG(seed: 0x5EED_0001)
        let trials = 200
        let tol: Float = 0.003   // 允许 ≤3mm 数值穿透（引擎跟踪 maxBallBallPenetration 通常 <1mm）
        var worstPenetration: Float = 0
        for t in 0..<trials {
            var positions: [SCNVector3] = []
            for _ in 0..<3 {
                var p = randomBallPos(&rng)
                var guardCount = 0
                while positions.contains(where: { horizontalDist($0, p) < 2.2 * R }) && guardCount < 40 {
                    p = randomBallPos(&rng); guardCount += 1
                }
                positions.append(p)
            }
            let aim = randomUnitXZ(&rng)
            let velocity = rng.float(in: 2.0...5.5)
            let strike = CueBallStrike.executeStrike(aimDirection: aim, velocity: velocity, spinX: 0, spinY: 0)

            let engine = EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBallQiuJi(surfaceY: surfaceY))
            let names = ["cue", "o1", "o2"]
            for (i, p) in positions.enumerated() {
                engine.setBall(BallState(position: SCNVector3(p.x, surfaceY + R, p.z),
                                         velocity: i == 0 ? strike.velocity : SCNVector3Zero,
                                         angularVelocity: i == 0 ? strike.angularVelocity : SCNVector3Zero,
                                         state: i == 0 ? .sliding : .stationary, name: names[i]))
            }
            engine.simulate(maxEvents: 600, maxTime: 15)

            let rec = engine.getTrajectoryRecorder()
            for ts in frameTimes(rec) {
                var alive: [SCNVector3] = []
                for n in names {
                    guard let f = rec.stateAt(ballName: n, time: ts), f.state != .pocketed else { continue }
                    alive.append(f.position)
                }
                for i in 0..<alive.count {
                    for j in (i + 1)..<alive.count {
                        let d = horizontalDist(alive[i], alive[j])
                        let penetration = max(0, 2 * R - d)
                        worstPenetration = max(worstPenetration, penetration)
                        XCTAssertGreaterThanOrEqual(d, 2 * R - tol,
                            "trial \(t) t=\(ts): 球互穿 \(penetration * 1000)mm（球心距 \(d * 1000)mm < 2R=\(2 * R * 1000)mm）")
                    }
                }
            }
        }
        print(String(format: "[INV-overlap] %d 次随机多球，最坏穿透 %.2fmm（应 ≤ %.1fmm）",
                     trials, worstPenetration * 1000, tol * 1000))
    }

    // MARK: - 3. 不出界（D-C1，生产钳制轨迹）

    /// 批量随机可进球形：`ShotPredictor.predict` 产出的**显示轨迹**（cuePath/objectPath，
    /// 经 `clampedRecorder` 穿库安全网）的每个点都应落在可玩区或袋口嘴内——即所画的线绝不
    /// 飞出台面。守护 FL-018 穿库钳制不被重构破坏。
    func test_invariant_productionPathsStayInBounds() {
        var rng = SeededRNG(seed: 0xB0_1D5_EED)
        let trials = 150
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)
        var feasibleCount = 0
        var worstOut: Float = 0
        for t in 0..<trials {
            let cue = randomBallPos(&rng)
            var target = randomBallPos(&rng)
            var guardCount = 0
            while horizontalDist(cue, target) < 4 * R && guardCount < 20 {
                target = randomBallPos(&rng); guardCount += 1
            }
            let pocketIndex = Int(rng.next() % 6)
            let velocity = rng.float(in: 1.6...5.8)
            let pred = ShotPredictor.predict(ShotInput(
                cueBall: SCNVector3(cue.x, surfaceY + R, cue.z),
                targetBall: SCNVector3(target.x, surfaceY + R, target.z),
                pocketIndex: pocketIndex, velocity: velocity, spinX: 0, spinY: 0, surfaceY: surfaceY))
            guard pred.feasible else { continue }
            feasibleCount += 1
            for p in pred.cuePath + pred.objectPath {
                let inBounds = boundsContains(p, halfL: halfL, halfW: halfW, pockets: pockets, margin: 0.02)
                if !inBounds {
                    worstOut = max(worstOut, outDistance(p, halfL: halfL, halfW: halfW, pockets: pockets))
                }
                XCTAssertTrue(inBounds,
                    "trial \(t) 袋\(pocketIndex): 显示轨迹点 (\(p.x),\(p.z)) 飞出可玩区+袋口嘴（越界 \(outDistance(p, halfL: halfL, halfW: halfW, pockets: pockets) * 1000)mm）")
            }
        }
        print(String(format: "[INV-bounds] %d 次随机，可行 %d 条，最坏越界 %.1fmm（应 0）",
                     trials, feasibleCount, worstOut * 1000))
        XCTAssertGreaterThan(feasibleCount, 5, "随机球形可行样本过少，护栏无意义")
    }

    // MARK: - 4. 确定性（D-C3）

    /// 同一 `ShotInput` 重复 predict 多次，轨迹应逐帧严格一致（含加塞 + 多球障碍）。
    /// 浮点 + 事件优先级排序 + 字典遍历若引入非确定性，烘焙缩略图/序列回放会静默漂移。
    func test_determinism_predictIsRepeatable() {
        let sY = surfaceY
        let inputs: [ShotInput] = [
            ShotInput(cueBall: SCNVector3(-0.2, sY + R, 0.0), targetBall: SCNVector3(0.4, sY + R, 0.0),
                      pocketIndex: 1, velocity: 3.3, spinX: 0, spinY: 0, surfaceY: sY),
            ShotInput(cueBall: SCNVector3(-0.2, sY + R, 0.0), targetBall: SCNVector3(0.4, sY + R, 0.0),
                      pocketIndex: 1, velocity: 4.4, spinX: 0.5, spinY: -0.3, surfaceY: sY),
            ShotInput(cueBall: SCNVector3(0.0, sY + R, -0.20), targetBall: SCNVector3(0.0, sY + R, 0.30),
                      pocketIndex: 5, velocity: 3.3, spinX: 0, spinY: 0, surfaceY: sY,
                      obstacles: [ObstacleBall(name: "_3", position: SCNVector3(-0.9, sY + R, 0.40))]),
        ]
        for (idx, input) in inputs.enumerated() {
            let a = ShotPredictor.predict(input)
            let b = ShotPredictor.predict(input)
            let c = ShotPredictor.predict(input)
            XCTAssertEqual(a.feasible, b.feasible); XCTAssertEqual(b.feasible, c.feasible)
            XCTAssertEqual(a.objectPocketed, b.objectPocketed, "input\(idx) objectPocketed 不确定")
            XCTAssertEqual(a.cuePocketed, b.cuePocketed, "input\(idx) cuePocketed 不确定")
            assertPathsIdentical(a.cuePath, b.cuePath, label: "input\(idx) cuePath a/b")
            assertPathsIdentical(b.cuePath, c.cuePath, label: "input\(idx) cuePath b/c")
            assertPathsIdentical(a.objectPath, b.objectPath, label: "input\(idx) objectPath a/b")
            // 发现（D-C3 坐实）：位置轨迹运行间稳定到 <1e-5 m（上方断言已守），但**派生标量
            // 分离角**实测带 ~1e-4° 量级运行间抖动——求解器 `solveAimOffset` 做 ~75 次短模拟按
            // 评分择优，评分极接近时浮点求和顺序（引擎字典遍历）可令选中的瞄准偏移差一丝，
            // 经接触瞬间速度→acos 放大到角度。这是引擎/求解器层的**微小非确定性**（非混沌发散：
            // 混沌会差到度级，此处仅 1e-4°）。护栏锁在 0.02° 的现实包络：守住「不退化为真发散」，
            // 同时如实记录当前抖动水平。若后续把求解/引擎遍历改为确定性顺序，可收紧回 1e-6。
            if let sa = a.separationAngleDeg, let sb = b.separationAngleDeg {
                XCTAssertEqual(sa, sb, accuracy: 0.02, "input\(idx) 分离角运行间发散过大（疑似非确定性恶化）")
            }
        }
    }

    /// 裸引擎层确定性：同一初始条件 simulate 两次，记录帧逐帧一致。
    func test_determinism_rawEngineIsRepeatable() {
        func run() -> TrajectoryRecorder {
            let engine = EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBallQiuJi(surfaceY: surfaceY))
            let strike = CueBallStrike.executeStrike(aimDirection: SCNVector3(1, 0, 0), velocity: 3.3, spinX: 0.3, spinY: 0.5)
            engine.setBall(BallState(position: SCNVector3(-0.5, surfaceY + R, 0.05),
                                     velocity: strike.velocity, angularVelocity: strike.angularVelocity,
                                     state: .sliding, name: "cue"))
            engine.setBall(BallState(position: SCNVector3(0.2, surfaceY + R, 0.0),
                                     velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero,
                                     state: .stationary, name: "obj"))
            engine.simulate(maxEvents: 500, maxTime: 15)
            return engine.getTrajectoryRecorder()
        }
        let r1 = run(), r2 = run()
        for name in ["cue", "obj"] {
            let f1 = r1.framesByBallName[name] ?? []
            let f2 = r2.framesByBallName[name] ?? []
            XCTAssertEqual(f1.count, f2.count, "\(name) 帧数不确定 \(f1.count) vs \(f2.count)")
            for i in 0..<min(f1.count, f2.count) {
                XCTAssertEqual(f1[i].time, f2[i].time, accuracy: 1e-6, "\(name)[\(i)] 时间不确定")
                XCTAssertEqual(f1[i].position.x, f2[i].position.x, accuracy: 1e-5, "\(name)[\(i)] x 不确定")
                XCTAssertEqual(f1[i].position.z, f2[i].position.z, accuracy: 1e-5, "\(name)[\(i)] z 不确定")
            }
        }
    }

    // MARK: - 5. 自由球减速单调（D-C1，中心击打无旋）

    /// 中心击打（无旋）单球在**首次吃库前**速度应严格单调非增——纯滑动→滚动摩擦只减速，
    /// 绝不应出现「速度回升/造能」。吃库后因 Han 模型可能把旋转转回线速度，故只验首库前。
    func test_invariant_singleBallCenterHit_speedMonotonicBeforeCushion() {
        var rng = SeededRNG(seed: 0xDECE_1E11)
        let trials = 200
        var worstJump: Float = 0
        for t in 0..<trials {
            let pos = randomBallPos(&rng)
            let aim = randomUnitXZ(&rng)
            let velocity = rng.float(in: 1.5...5.5)
            let strike = CueBallStrike.executeStrike(aimDirection: aim, velocity: velocity, spinX: 0, spinY: 0)
            let engine = EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBallQiuJi(surfaceY: surfaceY))
            engine.setBall(BallState(position: SCNVector3(pos.x, surfaceY + R, pos.z),
                                     velocity: strike.velocity, angularVelocity: strike.angularVelocity,
                                     state: .sliding, name: "cue"))
            engine.simulate(maxEvents: 800, maxTime: 30)
            // 首次吃库时刻（之后不验单调）。
            var firstCushion = Float.greatestFiniteMagnitude
            for (e, ts) in zip(engine.resolvedEvents, engine.resolvedEventTimes) {
                if case .ballCushion = e { firstCushion = min(firstCushion, ts) }
            }
            let frames = (engine.getTrajectoryRecorder().framesByBallName["cue"] ?? []).sorted { $0.time < $1.time }
            var prev = Float.greatestFiniteMagnitude
            for f in frames where f.time < firstCushion - 1e-4 {
                let s = sqrtf(f.velocity.x * f.velocity.x + f.velocity.z * f.velocity.z)
                if prev < Float.greatestFiniteMagnitude { worstJump = max(worstJump, s - prev) }
                XCTAssertLessThanOrEqual(s, prev + 0.02,
                    "trial \(t) t=\(f.time): 中心球首库前速度回升 \(prev)→\(s)（造能/异常加速）")
                prev = s
            }
        }
        print(String(format: "[INV-decel] %d 次中心球首库前最坏速度回升 %.3f m/s（应 ≤ 0.02）", trials, worstJump))
    }

    // MARK: - 6. 模拟收敛（D-C1，无失控）

    /// 充分时长后所有球都应停住或进袋——不应有球永远高速跑（失控）。
    func test_invariant_simulationConverges_noRunaway() {
        var rng = SeededRNG(seed: 0x7E40_1147)
        let trials = 150
        var worstFinalSpeed: Float = 0
        for t in 0..<trials {
            var positions: [SCNVector3] = []
            for _ in 0..<3 {
                var p = randomBallPos(&rng); var g = 0
                while positions.contains(where: { horizontalDist($0, p) < 2.2 * R }) && g < 40 { p = randomBallPos(&rng); g += 1 }
                positions.append(p)
            }
            let strike = CueBallStrike.executeStrike(aimDirection: randomUnitXZ(&rng), velocity: rng.float(in: 2.0...5.8), spinX: 0, spinY: 0)
            let engine = EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBallQiuJi(surfaceY: surfaceY))
            let names = ["cue", "o1", "o2"]
            for (i, p) in positions.enumerated() {
                engine.setBall(BallState(position: SCNVector3(p.x, surfaceY + R, p.z),
                                         velocity: i == 0 ? strike.velocity : SCNVector3Zero,
                                         angularVelocity: i == 0 ? strike.angularVelocity : SCNVector3Zero,
                                         state: i == 0 ? .sliding : .stationary, name: names[i]))
            }
            engine.simulate(maxEvents: 3000, maxTime: 30)
            let rec = engine.getTrajectoryRecorder()
            for n in names {
                guard let last = rec.framesByBallName[n]?.last else { continue }
                if last.state == .pocketed { continue }
                let s = sqrtf(last.velocity.x * last.velocity.x + last.velocity.z * last.velocity.z)
                worstFinalSpeed = max(worstFinalSpeed, s)
                XCTAssertLessThan(s, 0.3, "trial \(t) 球 \(n) 终态仍高速 \(s) m/s（模拟未收敛/失控）")
            }
        }
        print(String(format: "[INV-converge] %d 次随机多球，最坏终态速度 %.3f m/s（应 < 0.3）", trials, worstFinalSpeed))
    }

    // MARK: - 7. 球-球碰撞守恒律（D-C1，组件级随机批量）

    /// 球-球碰撞应守恒**线动量**（等质量 ⇒ vA+vB 不变，摩擦为内力不改总动量），
    /// 且**总动能不增**（恢复系数 + 摩擦耗散）。随机切角 + 随机入射旋转批量验证。
    func test_invariant_ballBallCollision_conservesMomentumAndDissipatesEnergy() {
        var rng = SeededRNG(seed: 0x3043_C0F1)
        let trials = 600
        var worstMomErr: Float = 0
        var worstEnergyRatio: Float = 0
        for t in 0..<trials {
            let cut = rng.float(in: 0...(75 * .pi / 180))
            let v0 = rng.float(in: 1.0...5.0)
            let posA = SCNVector3(0, surfaceY, 0)
            let posB = SCNVector3(2 * R * cosf(cut), surfaceY, 2 * R * sinf(cut))
            let velA = SCNVector3(v0, 0, 0)
            // 随机入射旋转（量级覆盖高/低/侧塞）。
            let angA = SCNVector3(rng.float(in: -30...30), rng.float(in: -50...50), rng.float(in: -30...30))
            let res = CollisionResolver.resolveBallBallPure(
                posA: posA, posB: posB, velA: velA, velB: SCNVector3Zero,
                angVelA: angA, angVelB: SCNVector3Zero)

            // 线动量（等质量，约去 m）：vA+vB 守恒。
            let pinX = velA.x, pinZ = velA.z
            let poutX = res.velA.x + res.velB.x, poutZ = res.velA.z + res.velB.z
            let momErr = sqrtf((poutX - pinX) * (poutX - pinX) + (poutZ - pinZ) * (poutZ - pinZ))
            worstMomErr = max(worstMomErr, momErr)
            XCTAssertLessThan(momErr, 1e-2, "trial \(t) cut=\(cut * 180 / .pi)°: 线动量不守恒 Δ=\(momErr) m/s")

            // 总动能（平动+转动）不增。
            let keIn = 0.5 * mass * (velA.x * velA.x + velA.z * velA.z)
                + 0.5 * inertia * (angA.x * angA.x + angA.y * angA.y + angA.z * angA.z)
            let keOut = ke(res.velA, res.angVelA) + ke(res.velB, res.angVelB)
            let ratio = keOut / max(keIn, 1e-6)
            worstEnergyRatio = max(worstEnergyRatio, ratio)
            XCTAssertLessThanOrEqual(ratio, 1.01, "trial \(t): 碰撞总动能增加 KEout/KEin=\(ratio)")
        }
        print(String(format: "[INV-collision] %d 次随机球-球：最坏动量误差 %.4f m/s，最坏 KEout/KEin %.4f", trials, worstMomErr, worstEnergyRatio))
    }

    // MARK: - 8. 静止球被触碰前保持不动（D-C1）

    /// 静止球只能因**球-球碰撞**获得速度——在首个涉及它的碰撞/进袋事件之前，其位置必须恒定
    /// （无幽灵碰撞/数值漂移）。注：母球高速会绕库飞回撞到任意位置的静止球，故不能假设"身后=永不碰"，
    /// 而是断言"被触碰前不动"——这才是与轨迹无关的真不变量。
    func test_invariant_stationaryBallStaysPutUntilTouched() {
        var rng = SeededRNG(seed: 0x57A7_1C00)
        let trials = 150
        var worstDriftBeforeTouch: Float = 0
        for t in 0..<trials {
            var positions: [SCNVector3] = []
            for _ in 0..<2 {
                var p = randomBallPos(&rng); var g = 0
                while positions.contains(where: { horizontalDist($0, p) < 3 * R }) && g < 40 { p = randomBallPos(&rng); g += 1 }
                positions.append(p)
            }
            let cue = positions[0], rest = positions[1]
            let strike = CueBallStrike.executeStrike(aimDirection: randomUnitXZ(&rng), velocity: rng.float(in: 2.0...5.0), spinX: 0, spinY: 0)
            let engine = EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBallQiuJi(surfaceY: surfaceY))
            engine.setBall(BallState(position: cue, velocity: strike.velocity, angularVelocity: strike.angularVelocity, state: .sliding, name: "cue"))
            engine.setBall(BallState(position: rest, velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero, state: .stationary, name: "rest"))
            engine.simulate(maxEvents: 1500, maxTime: 25)
            // 首个涉及 rest 的碰撞/进袋时刻。
            var firstTouch = Float.greatestFiniteMagnitude
            for (e, ts) in zip(engine.resolvedEvents, engine.resolvedEventTimes) {
                switch e {
                case .ballBall(let a, let b): if a == "rest" || b == "rest" { firstTouch = min(firstTouch, ts) }
                case .pocket(let ball, _): if ball == "rest" { firstTouch = min(firstTouch, ts) }
                default: break
                }
            }
            let frames = engine.getTrajectoryRecorder().framesByBallName["rest"] ?? []
            for f in frames where f.time < firstTouch - 1e-4 {
                let drift = horizontalDist(f.position, rest)
                worstDriftBeforeTouch = max(worstDriftBeforeTouch, drift)
                XCTAssertLessThan(drift, 0.005, "trial \(t): 静止球被触碰前漂移 \(drift * 1000)mm（疑似幽灵碰撞）")
            }
        }
        print(String(format: "[INV-static] %d 次，被触碰前最坏漂移 %.2fmm（应 < 5mm）", trials, worstDriftBeforeTouch * 1000))
    }

    // MARK: - Helpers

    /// 单球总动能（平动 + 转动）。
    private func ke(_ v: SCNVector3, _ w: SCNVector3) -> Float {
        0.5 * mass * (v.x * v.x + v.y * v.y + v.z * v.z) + 0.5 * inertia * (w.x * w.x + w.y * w.y + w.z * w.z)
    }

    /// 系统总动能（平动 + 转动），仅计未进袋球，在给定时刻取每球最近帧。
    private func systemEnergy(_ rec: TrajectoryRecorder, at time: Float) -> Float {
        var total: Float = 0
        for (_, frames) in rec.framesByBallName {
            guard !frames.isEmpty else { continue }
            let f = nearestFrame(frames, time: time)
            guard f.state != .pocketed else { continue }
            let v2 = f.velocity.x * f.velocity.x + f.velocity.y * f.velocity.y + f.velocity.z * f.velocity.z
            let w2 = f.angularVelocity.x * f.angularVelocity.x + f.angularVelocity.y * f.angularVelocity.y + f.angularVelocity.z * f.angularVelocity.z
            total += 0.5 * mass * v2 + 0.5 * inertia * w2
        }
        return total
    }

    /// 给定时刻取 ≤time 的最后一帧（保持取值与录制时刻一致，不做插值，避免引入额外能量）。
    private func nearestFrame(_ frames: [BallFrame], time: Float) -> BallFrame {
        var last = frames[0]
        for f in frames {
            if f.time > time + 1e-6 { break }
            last = f
        }
        return last
    }

    /// 录制器中所有球的去重时间戳（升序）。
    private func frameTimes(_ rec: TrajectoryRecorder) -> [Float] {
        var set = Set<Int>()
        var times: [Float] = []
        for (_, frames) in rec.framesByBallName {
            for f in frames {
                let key = Int((f.time * 10000).rounded())
                if set.insert(key).inserted { times.append(f.time) }
            }
        }
        return times.sorted()
    }

    private func boundsContains(_ p: SCNVector3, halfL: Float, halfW: Float, pockets: [SCNVector3], margin: Float) -> Bool {
        if abs(p.x) <= halfL - R + margin && abs(p.z) <= halfW - R + margin { return true }
        let mouth: Float = 0.12 + margin
        for pk in pockets {
            let dx = p.x - pk.x, dz = p.z - pk.z
            if dx * dx + dz * dz <= mouth * mouth { return true }
        }
        return false
    }

    private func outDistance(_ p: SCNVector3, halfL: Float, halfW: Float, pockets: [SCNVector3]) -> Float {
        let ox = max(0, abs(p.x) - (halfL - R))
        let oz = max(0, abs(p.z) - (halfW - R))
        let rectOut = sqrtf(ox * ox + oz * oz)
        var pocketOut = Float.greatestFiniteMagnitude
        for pk in pockets {
            let dx = p.x - pk.x, dz = p.z - pk.z
            pocketOut = min(pocketOut, max(0, sqrtf(dx * dx + dz * dz) - 0.12))
        }
        return min(rectOut, pocketOut)
    }

    private func assertPathsIdentical(_ a: [SCNVector3], _ b: [SCNVector3], label: String) {
        XCTAssertEqual(a.count, b.count, "\(label) 点数不一致 \(a.count) vs \(b.count)")
        for i in 0..<min(a.count, b.count) {
            XCTAssertEqual(a[i].x, b[i].x, accuracy: 1e-5, "\(label)[\(i)] x")
            XCTAssertEqual(a[i].z, b[i].z, accuracy: 1e-5, "\(label)[\(i)] z")
        }
    }

    private func horizontalDist(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dx = a.x - b.x, dz = a.z - b.z
        return sqrtf(dx * dx + dz * dz)
    }

    /// 随机生成可玩区内的球心（XZ，留 1.5R 边距防贴库初始化）。
    private func randomBallPos(_ rng: inout SeededRNG) -> SCNVector3 {
        let halfL = AngleSceneCalculator.innerLength / 2 - 1.5 * R
        let halfW = AngleSceneCalculator.innerWidth / 2 - 1.5 * R
        return SCNVector3(rng.float(in: -halfL...halfL), surfaceY + R, rng.float(in: -halfW...halfW))
    }

    private func randomUnitXZ(_ rng: inout SeededRNG) -> SCNVector3 {
        let a = rng.float(in: 0...(2 * .pi))
        return SCNVector3(cosf(a), 0, sinf(a))
    }

    /// 在打滑极限（0.5R 圆盘）内随机取打点（spinX, spinY ∈ 单位盘，幅值 ≤ miscueLimit）。
    private func randomSpinWithinMiscue(_ rng: inout SeededRNG) -> (Float, Float) {
        let limit = CuePhysics.miscueLimitFraction
        let r = sqrtf(rng.float(in: 0...1)) * limit
        let a = rng.float(in: 0...(2 * .pi))
        return (r * cosf(a), r * sinf(a))
    }
}

/// 可复现的 SplitMix64 PRNG（测试专用，失败可用 seed 精确重放）。
struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 均匀浮点 [0,1)。
    mutating func unit() -> Float {
        return Float(next() >> 40) / Float(1 << 24)
    }

    mutating func float(in range: ClosedRange<Float>) -> Float {
        return range.lowerBound + unit() * (range.upperBound - range.lowerBound)
    }
}
