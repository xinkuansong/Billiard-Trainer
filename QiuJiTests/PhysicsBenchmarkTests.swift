import XCTest
import SceneKit
@testable import QiuJi

/// 2D 物理引擎「体检表」基准套件（go/no-go 探针）。
///
/// 参考值取自公开台球物理（Dr. Dave / Alciatore TP 系列、pooltool 默认模型）：
///   - 90° 法则：定杆切球分离角 ≈ 90°（throw 令略小）。
///   - 30° 法则：自然滚动母球切球后稳定方向 ≈ 30°（业余实用区 ~27–34°）。
///   - squirt：典型杆头侧塞挤偏 1–3°。
///   - 库边：Han 2005 闭式解，e_c=0.85；反弹角≈入射角（略偏长）。
///
/// 设计原则：带容差的「band」断言，不是精确相等；每个测试先 print 一张
/// 「实测 / 参考 / 是否达标」表（XCTest 捕获 stdout），再断言。
/// 几何敏感项（E 进袋）同时跑 CAD 版 `chineseEightBall()` 与 USDZ 版
/// `chineseEightBallQiuJi()` 做对比，凸显双真源差异。
final class PhysicsBenchmarkTests: XCTestCase {

    private let R = BallPhysics.radius
    private var surfaceY: Float { BTTablePhysics.surfaceY }

    // MARK: - A. 击打模型（CueBallStrike，组件级，确定性）

    func test_A_strike_squirt_band() {
        print("\n[A] squirt 挤偏角（左塞 a>0 应向右偏=负；量级参考 0.3–4°）")
        print("  a      squirt°   符号OK  量级OK")
        var lastMag: Float = 0
        var monotonic = true
        for a in [Float(0.2), 0.4, 0.6] {
            let sq = CueBallStrike.squirtAngle(a: a)            // 弧度，负=右偏
            let deg = sq * 180 / .pi
            let signOK = sq < 0                                 // 左塞→右偏
            let magOK = abs(deg) >= 0.3 && abs(deg) <= 4.0
            if abs(deg) < lastMag - 0.01 { monotonic = false }
            lastMag = abs(deg)
            print(String(format: "  %.1f    %7.3f      %@      %@",
                         a, deg, signOK ? "✓" : "✗", magOK ? "✓" : "✗"))
            XCTAssertTrue(signOK, "左塞 a=\(a) 应向右偏（squirt<0）")
            XCTAssertTrue(magOK, "squirt 量级异常 a=\(a) → \(deg)°")
        }
        XCTAssertTrue(monotonic, "squirt 量级在 a≤0.6 应随 |a| 单调增")
        XCTAssertEqual(CueBallStrike.squirtAngle(a: 0), 0, accuracy: 1e-6)
    }

    func test_A_strike_spin_band() {
        print("\n[A] 击打旋转量级（高杆 b=1 / 低杆 b=-1 / 中心 b=0）")
        print("  打点      |w| rad/s   说明")
        let top = CueBallStrike.executeStrike(aimDirection: SCNVector3(1, 0, 0), velocity: 2, spinX: 0, spinY: 1)
        let draw = CueBallStrike.executeStrike(aimDirection: SCNVector3(1, 0, 0), velocity: 2, spinX: 0, spinY: -1)
        let center = CueBallStrike.executeStrike(aimDirection: SCNVector3(1, 0, 0), velocity: 2, spinX: 0, spinY: 0)
        let naturalRoll = top.velocity.length() / R
        print(String(format: "  高杆      %7.1f    过量上旋(>v/R=%.1f), w.z<0", top.angularVelocity.length(), naturalRoll))
        print(String(format: "  低杆      %7.1f    反向旋转 w.z>0", draw.angularVelocity.length()))
        print(String(format: "  中心      %7.3f    应≈0", center.angularVelocity.length()))
        XCTAssertGreaterThan(top.angularVelocity.length(), 40)
        XCTAssertLessThan(top.angularVelocity.length(), 220)
        XCTAssertLessThan(top.angularVelocity.z, -1)
        XCTAssertGreaterThan(abs(top.angularVelocity.z), naturalRoll)
        XCTAssertGreaterThan(draw.angularVelocity.z, 1)
        XCTAssertLessThan(center.angularVelocity.length(), 1e-2)
    }

    // MARK: - B. 球-球碰撞（CollisionResolver，组件级，确定性）

    func test_B_ballBall_90degree_acrossCuts() {
        // 厚球(小切角)+慢速时 throw 最大，分离角可低到 ~80°（真实物理，非 bug），
        // 故 band 取 79–90.5°（Dr. Dave: stun 分离角 = 90° − throw 偏移）。
        print("\n[B] 定杆分离角 vs 切球角（参考 ≈90°，throw 令略小；band 79–90.5°）")
        print("  切球角°   分离角°   达标")
        for cutDeg in [Float(15), 30, 45, 60] {
            let cut = cutDeg * .pi / 180
            let posA = SCNVector3(0, surfaceY, 0)
            let posB = SCNVector3(2 * R * cosf(cut), surfaceY, 2 * R * sinf(cut))
            let res = CollisionResolver.resolveBallBallPure(
                posA: posA, posB: posB,
                velA: SCNVector3(2, 0, 0), velB: SCNVector3Zero,
                angVelA: SCNVector3Zero, angVelB: SCNVector3Zero
            )
            let sep = angleDeg(res.velA, res.velB)
            let ok = sep >= 79 && sep <= 90.5
            print(String(format: "  %5.0f    %7.1f      %@", cutDeg, sep, ok ? "✓" : "✗"))
            XCTAssertTrue(ok, "切角 \(cutDeg)° 分离角 \(sep)° 超出 79–90.5°")
        }
    }

    func test_B_ballBall_throw_band() {
        print("\n[B] cut-induced throw（目标球偏离撞击线，参考 ≤6°；band ≤8°）")
        print("  切球角°   throw°   达标")
        for cutDeg in [Float(15), 30, 45, 60] {
            let cut = cutDeg * .pi / 180
            let posA = SCNVector3(0, surfaceY, 0)
            let line = SCNVector3(cosf(cut), 0, sinf(cut))     // 撞击线（连心线）方向
            let posB = SCNVector3(2 * R * cosf(cut), surfaceY, 2 * R * sinf(cut))
            let res = CollisionResolver.resolveBallBallPure(
                posA: posA, posB: posB,
                velA: SCNVector3(2, 0, 0), velB: SCNVector3Zero,
                angVelA: SCNVector3Zero, angVelB: SCNVector3Zero
            )
            let throwDeg = angleDeg(res.velB, line)
            let ok = throwDeg <= 8
            print(String(format: "  %5.0f    %6.2f      %@", cutDeg, throwDeg, ok ? "✓" : "✗"))
            XCTAssertTrue(ok, "切角 \(cutDeg)° throw \(throwDeg)° 偏大")
        }
    }

    func test_B_ballBall_headOn_transfer() {
        let posA = SCNVector3(0, surfaceY, 0)
        let posB = SCNVector3(2 * R, surfaceY, 0)
        let v: Float = 2
        let res = CollisionResolver.resolveBallBallPure(
            posA: posA, posB: posB,
            velA: SCNVector3(v, 0, 0), velB: SCNVector3Zero,
            angVelA: SCNVector3Zero, angVelB: SCNVector3Zero
        )
        print(String(format: "\n[B] 正面定杆传速（e_b=%.2f）: 母球残速 %.3f / 目标球 %.3f（参考 0.025v / 0.975v）",
                     BallPhysics.restitution, res.velA.x, res.velB.x))
        XCTAssertEqual(res.velA.x, 0.025 * v, accuracy: 0.05)
        XCTAssertEqual(res.velB.x, 0.975 * v, accuracy: 0.05)
        XCTAssertEqual(res.velB.z, 0, accuracy: 1e-3)
    }

    // MARK: - C. 库边碰撞（Han2005，组件级，确定性）

    func test_C_cushion_speedRetention_band() {
        let normal = SCNVector3(1, 0, 0)
        print("\n[C] Han2005 库边速度保留率（e_c=\(TablePhysics.cushionRestitution)，无旋转；band 0.40–1.00，法向0°≈e_c）")
        print("  入射角°   S(m/s)   保留率   反弹角°   达标")
        for S in [Float(2), 4] {
            for deg in [Float(0), 15, 30, 45, 60, 75] {
                let th = deg * .pi / 180
                let v = SCNVector3(-S * cosf(th), 0, S * sinf(th))
                let r = CollisionResolver.resolveCushionCollisionPure(velocity: v, angularVelocity: SCNVector3Zero, normal: normal)
                let sOut = sqrtf(r.velocity.x * r.velocity.x + r.velocity.z * r.velocity.z)
                let ratio = sOut / S
                let outDeg = atan2f(abs(r.velocity.z), abs(r.velocity.x)) * 180 / .pi
                var ok = ratio >= 0.40 && ratio <= 1.0
                if deg == 0 { ok = ok && ratio >= 0.70 && ratio <= 0.95 }
                print(String(format: "  %5.0f    %5.1f    %5.1f%%   %6.1f      %@",
                             deg, S, ratio * 100, outDeg, ok ? "✓" : "✗"))
                XCTAssertGreaterThanOrEqual(ratio, 0.40, "保留率过低 入射\(deg)° S\(S)")
                XCTAssertLessThanOrEqual(ratio, 1.0, "保留率>1 入射\(deg)° S\(S)")
                if deg == 0 {
                    XCTAssertTrue(ratio >= 0.70 && ratio <= 0.95, "法向入射保留率应≈e_c，实测 \(ratio)")
                }
            }
        }
    }

    func test_C_cushion_reboundAngle_band() {
        let normal = SCNVector3(1, 0, 0)
        let S: Float = 4
        print("\n[C] 反弹角 vs 入射角（无旋转，参考 ≈入射角，库边略偏长；band |Δ|≤25°）")
        print("  入射角°   反弹角°   Δ°   达标")
        for deg in [Float(15), 30, 45, 60] {
            let th = deg * .pi / 180
            let v = SCNVector3(-S * cosf(th), 0, S * sinf(th))
            let r = CollisionResolver.resolveCushionCollisionPure(velocity: v, angularVelocity: SCNVector3Zero, normal: normal)
            let outDeg = atan2f(abs(r.velocity.z), abs(r.velocity.x)) * 180 / .pi
            let delta = abs(outDeg - deg)
            let ok = delta <= 25
            print(String(format: "  %5.0f    %6.1f   %5.1f   %@", deg, outDeg, delta, ok ? "✓" : "✗"))
            XCTAssertLessThanOrEqual(delta, 25, "反弹角偏离入射角过大 入射\(deg)° 反弹\(outDeg)°")
        }
    }

    // MARK: - D. 走位（端到端 EventDrivenEngine）

    func test_D_stun_tangentLine_90() {
        // 母球沿 +x 定杆，连心线 30°；碰后母球应沿切线（≈与目标球方向成 90°）。
        let cut: Float = 30 * .pi / 180
        let cue = SCNVector3(-0.6, surfaceY + R, 0)
        let target = SCNVector3(0, surfaceY + R, 2 * R * sinf(cut))
        let engine = runEngine(geometry: TableGeometry.chineseEightBallQiuJi(surfaceY: surfaceY),
                               cue: cue, target: target, aimDir: SCNVector3(1, 0, 0),
                               velocity: 2, spinX: 0, spinY: 0)
        guard let ct = firstContactTime(engine) else { return XCTFail("未发生球-球碰撞") }
        let rec = engine.getTrajectoryRecorder()
        let cueV = velocityAfter(rec, ball: "cue", time: ct)
        let objV = velocityAfter(rec, ball: "obj", time: ct)
        guard let cueV, let objV else { return XCTFail("缺少碰后速度") }
        let sep = angleDeg(cueV, objV)
        print(String(format: "\n[D] 定杆切球 90°法则（端到端）: 分离角 %.1f°（band 80–98°）", sep))
        XCTAssertTrue(sep >= 80 && sep <= 98, "端到端定杆分离角 \(sep)° 超出 80–98°")
    }

    func test_D_follow_naturalAngle_30rule() {
        // 自然滚动母球（state=.rolling, w=v/R）半球切击；碰后重新进入滚动时的方向
        // 与原方向夹角 ≈ 30°（30° 法则）。
        let cut: Float = 32 * .pi / 180
        let cue = SCNVector3(-0.5, surfaceY + R, 0)
        let target = SCNVector3(0, surfaceY + R, 2 * R * sinf(cut))
        let v: Float = 2
        let engine = EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBallQiuJi(surfaceY: surfaceY))
        let vel = SCNVector3(v, 0, 0)
        let wRoll = SCNVector3(0, 1, 0).cross(vel) * (1.0 / R)   // 自然滚动角速度
        engine.setBall(BallState(position: cue, velocity: vel, angularVelocity: wRoll, state: .rolling, name: "cue"))
        engine.setBall(BallState(position: target, velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero, state: .stationary, name: "obj"))
        engine.simulate(maxEvents: 400, maxTime: 15)
        guard let ct = firstContactTime(engine) else { return XCTFail("未发生球-球碰撞") }
        let rec = engine.getTrajectoryRecorder()
        // 碰后第一帧 state==.rolling 的方向（已稳定）。
        var settledDir: SCNVector3?
        if let frames = rec.framesByBallName["cue"]?.sorted(by: { $0.time < $1.time }) {
            for f in frames where f.time > ct + 1e-4 {
                if f.state == .rolling && f.velocity.length() > 0.05 { settledDir = f.velocity; break }
            }
        }
        let natural = settledDir.map { angleDeg($0, SCNVector3(1, 0, 0)) } ?? -1
        print(String(format: "\n[D] 跟杆自然角 30°法则（端到端）: %.1f°（参考 ~30°，band 18–45°）", natural))
        XCTAssertTrue(natural >= 18 && natural <= 45, "自然角 \(natural)° 偏离 30° 法则区间")
    }

    func test_D_draw_pullsBack() {
        // 低杆直球：母球碰后应回拉（最终 x < 接触点 x）。
        let cue = SCNVector3(-0.35, surfaceY + R, 0)
        let target = SCNVector3(0, surfaceY + R, 0)
        let engine = runEngine(geometry: TableGeometry.chineseEightBallQiuJi(surfaceY: surfaceY),
                               cue: cue, target: target, aimDir: SCNVector3(1, 0, 0),
                               velocity: 2.5, spinX: 0, spinY: -1)
        let rec = engine.getTrajectoryRecorder()
        let cueFinal = rec.framesByBallName["cue"]?.last?.position.x ?? 0
        print(String(format: "\n[D] 低杆回拉: 母球最终 x=%.3f（接触≈%.3f，应回拉到更负）", cueFinal, -2 * R))
        XCTAssertLessThan(cueFinal, -0.05, "低杆未回拉，最终 x=\(cueFinal)")
    }

    func test_D_rollDistance_report() {
        // 中速(3.3 m/s)中心球总滚动路径长度（含吃库）。揭示摩擦标定：路径越长=越滑。
        let engine = EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBallQiuJi(surfaceY: surfaceY))
        let strike = CueBallStrike.executeStrike(aimDirection: SCNVector3(1, 0, 0),
                                                 velocity: StrokePhysics.SpeedLevel.medium.velocity,
                                                 spinX: 0, spinY: 0)
        engine.setBall(BallState(position: SCNVector3(-1.2, surfaceY + R, 0.05),
                                 velocity: strike.velocity, angularVelocity: strike.angularVelocity,
                                 state: .sliding, name: "cue"))
        engine.simulate(maxEvents: 600, maxTime: 30)
        let rec = engine.getTrajectoryRecorder()
        var pathLen: Float = 0
        if let frames = rec.framesByBallName["cue"]?.sorted(by: { $0.time < $1.time }) {
            for i in 1..<frames.count {
                let d = frames[i].position - frames[i - 1].position
                pathLen += sqrtf(d.x * d.x + d.z * d.z)
            }
        }
        let realistic = pathLen >= 1.5 && pathLen <= 8
        print(String(format: "\n[D] 中速(3.3m/s)总滚动路径: %.2f m（现实参考 ~1.5–8 m；需标定: %@）",
                     pathLen, realistic ? "否" : "是"))
        // 仅做宽松健全性断言（标定问题不阻断 go/no-go）。
        XCTAssertTrue(pathLen >= 0.3 && pathLen <= 80, "滚动路径异常 \(pathLen) m")
    }

    // MARK: - E. 进袋（端到端，几何敏感，CAD vs QiuJi 对比）

    /// E-geom（**诊断**，非 go/no-go 闸门）：直接幽灵球瞄准（不经求解器），隔离「几何 + 内核」。
    /// 朴素瞄准把目标球打向 USDZ 袋心，跑 CAD 与 QiuJi 两套几何对比。
    ///
    /// 发现（探针）：朴素瞄准在两套几何下都会在袋口「rattle」——CAD 的洞心偏标记 ~17mm；
    /// QiuJi 虽袋心 = 标记，但 jaw 圆弧仍取自 CAD 坐标、与 USDZ 洞心残留 ~17mm 错位，
    /// 故贴角球被 jaw 弹出而非落袋（13.4mm 捕获窗很窄）。真正可靠进袋靠 **闭环求解器**
    /// （见 `test_E_solver_pottingBattery`，已 5/5）。jaw↔洞心对齐留作 P10 标定。
    ///
    /// 断言（真不变量，非闸门）：QiuJi 几何**绝不把目标球打进错误的袋**（无假性落袋）。
    func test_E_geom_pottingBattery_CADvsQiuJi() {
        let target = SCNVector3(0.2, surfaceY + R, -0.05)
        let pocketIndex = 1                                  // ASC 右上角袋
        let expected = "pocket_\(pocketIndex)"
        let marker = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)[pocketIndex]
        let cad = TableGeometry.chineseEightBall()
        let qiuji = TableGeometry.chineseEightBallQiuJi(surfaceY: surfaceY)

        print("\n[E-geom·诊断] 幽灵球直瞄进袋（瞄向 USDZ 袋心）: CAD vs QiuJi（朴素瞄准，非闸门）")
        print("  切球角°   CAD结果        QiuJi结果   QiuJi到标记mm")
        var qjPotted = 0
        for cutDeg in [Float(0), 15, 30, 45, 55] {
            let (cue, aimDir) = makeLayout(target: target, pocketIndex: pocketIndex, cutDeg: cutDeg, cueDist: 0.4)
            let cadRun = runEngine(geometry: cad, cue: cue, target: target, aimDir: aimDir,
                                   velocity: StrokePhysics.SpeedLevel.hard.velocity, spinX: 0, spinY: 0)
            let qjRun = runEngine(geometry: qiuji, cue: cue, target: target, aimDir: aimDir,
                                  velocity: StrokePhysics.SpeedLevel.hard.velocity, spinX: 0, spinY: 0)
            let cadPid = objectPocketId(cadRun) ?? "none"
            let cadDist = minObjDist(cadRun, to: marker) * 1000
            let qjPid = objectPocketId(qjRun) ?? "none"
            let qjDist = minObjDist(qjRun, to: marker) * 1000
            if qjPid == expected { qjPotted += 1 }
            print(String(format: "  %5.0f    %@(%.0fmm偏)   %@   %.0f",
                         cutDeg, cadPid, cadDist, qjPid, qjDist))
            // 真不变量：QiuJi 若落袋，必须是选定袋（绝不假性落入别的袋）。
            XCTAssertTrue(qjPid == "none" || qjPid == expected,
                          "QiuJi 切角 \(cutDeg)° 落入错误袋 \(qjPid)")
        }
        print(String(format: "  → QiuJi 朴素瞄准进袋 %d/5（其余袋口 rattle；可靠进袋见 E-solver）", qjPotted))
    }

    /// E-solver：完整 ShotPredictor 管线（含闭环瞄准求解），断言真实模拟进袋 simObjectPotted。
    func test_E_solver_pottingBattery() {
        let target = SCNVector3(0.2, surfaceY + R, -0.05)
        let pocketIndex = 1
        print("\n[E-solver] ShotPredictor 端到端进袋（simObjectPotted=真实模拟）")
        print("  切球角°   feasible   simPotted   cutAngle°")
        for cutDeg in [Float(0), 15, 30, 45, 55] {
            let (cue, _) = makeLayout(target: target, pocketIndex: pocketIndex, cutDeg: cutDeg, cueDist: 0.4)
            let input = ShotInput(cueBall: cue, targetBall: target, pocketIndex: pocketIndex,
                                  velocity: StrokePhysics.SpeedLevel.hard.velocity,
                                  spinX: 0, spinY: 0, surfaceY: surfaceY)
            let pred = ShotPredictor.predict(input)
            print(String(format: "  %5.0f    %@         %@          %.1f",
                         cutDeg, pred.feasible ? "✓" : "✗", pred.simObjectPotted ? "✓" : "✗",
                         pred.cutAngleDeg ?? -1))
            XCTAssertTrue(pred.simObjectPotted, "ShotPredictor 切角 \(cutDeg)° 真实模拟未进袋")
        }
    }

    /// 假阳性：目标球被打向长库中段（非袋口），不得判进袋。
    func test_E_falsePositive_noPhantomPot() {
        let target = SCNVector3(0.6, surfaceY + R, 0.3)
        let cue = SCNVector3(0.6, surfaceY + R, -0.2)         // 母球在目标球 -z 侧
        let engine = runEngine(geometry: TableGeometry.chineseEightBallQiuJi(surfaceY: surfaceY),
                               cue: cue, target: target, aimDir: SCNVector3(0, 0, 1),   // 把目标球推向 +z 长库中段
                               velocity: 3, spinX: 0, spinY: 0)
        let pid = objectPocketId(engine)
        print("\n[E] 假阳性检查: 目标球推向长库中段 → 进袋? \(pid ?? "none")（应 none）")
        XCTAssertNil(pid, "目标球进了不该进的袋 \(pid ?? "")")
    }

    // MARK: - Helpers

    private func angleDeg(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let da = hdir(a), db = hdir(b)
        let dot = max(-1, min(1, da.x * db.x + da.z * db.z))
        return acosf(dot) * 180 / .pi
    }

    private func hdir(_ v: SCNVector3) -> SCNVector3 {
        let len = sqrtf(v.x * v.x + v.z * v.z)
        guard len > 1e-5 else { return SCNVector3(1, 0, 0) }
        return SCNVector3(v.x / len, 0, v.z / len)
    }

    private func runEngine(
        geometry: TableGeometry, cue: SCNVector3, target: SCNVector3,
        aimDir: SCNVector3, velocity: Float, spinX: Float, spinY: Float,
        maxEvents: Int = 400, maxTime: Float = 15
    ) -> EventDrivenEngine {
        let strike = CueBallStrike.executeStrike(aimDirection: aimDir, velocity: velocity, spinX: spinX, spinY: spinY)
        let engine = EventDrivenEngine(tableGeometry: geometry)
        engine.setBall(BallState(position: SCNVector3(cue.x, surfaceY + R, cue.z),
                                 velocity: strike.velocity, angularVelocity: strike.angularVelocity,
                                 state: .sliding, name: "cue"))
        engine.setBall(BallState(position: SCNVector3(target.x, surfaceY + R, target.z),
                                 velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero,
                                 state: .stationary, name: "obj"))
        engine.simulate(maxEvents: maxEvents, maxTime: maxTime)
        return engine
    }

    private func firstContactTime(_ engine: EventDrivenEngine) -> Float? {
        for (e, t) in zip(engine.resolvedEvents, engine.resolvedEventTimes) {
            if case .ballBall = e { return t }
        }
        return nil
    }

    private func velocityAfter(_ rec: TrajectoryRecorder, ball: String, time: Float) -> SCNVector3? {
        guard let frames = rec.framesByBallName[ball]?.sorted(by: { $0.time < $1.time }) else { return nil }
        for f in frames where f.time >= time - 1e-5 { return f.velocity }
        return frames.last?.velocity
    }

    /// 目标球("obj")的进袋事件袋号（nil = 未进）。
    private func objectPocketId(_ engine: EventDrivenEngine) -> String? {
        for e in engine.resolvedEvents {
            if case .pocket(let ball, let pid) = e, ball == "obj" { return pid }
        }
        return nil
    }

    /// 目标球轨迹到给定标记点的最近水平距离（米）。
    private func minObjDist(_ engine: EventDrivenEngine, to marker: SCNVector3) -> Float {
        var minD = Float.greatestFiniteMagnitude
        if let frames = engine.getTrajectoryRecorder().framesByBallName["obj"] {
            for f in frames {
                let dx = f.position.x - marker.x
                let dz = f.position.z - marker.z
                minD = min(minD, sqrtf(dx * dx + dz * dz))
            }
        }
        return minD
    }

    /// 为给定目标球/袋/切球角构造母球位置与瞄准方向（直接幽灵球瞄准）。
    private func makeLayout(target: SCNVector3, pocketIndex: Int, cutDeg: Float, cueDist: Float) -> (cue: SCNVector3, aimDir: SCNVector3) {
        let pocket = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: surfaceY)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: pocket, ballRadius: R)
        let pd = hdir(SCNVector3(pocket.x - target.x, 0, pocket.z - target.z))   // 进球线方向
        let theta = cutDeg * .pi / 180
        let strikeDir = SCNVector3(pd.x * cosf(theta) - pd.z * sinf(theta), 0, pd.x * sinf(theta) + pd.z * cosf(theta))
        let cue = SCNVector3(ghost.x - strikeDir.x * cueDist, surfaceY + R, ghost.z - strikeDir.z * cueDist)
        let aimDir = hdir(SCNVector3(ghost.x - cue.x, 0, ghost.z - cue.z))
        return (cue, aimDir)
    }
}
