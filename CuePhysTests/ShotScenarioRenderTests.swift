//
//  ShotScenarioRenderTests.swift
//  QiuJiTests
//
//  P10 物理可视化诊断（Track B-2）：把「分离角与走位」页的击球求解结果渲染成
//  **2D 顶视诊断图**（PNG 接触表），用于肉眼核对不同袋口/切角/塞/力度下的真实
//  轨迹、进袋判定与喉腔/jaw 几何是否自洽——SceneKit 照相级渲染会遮住几何，故这里
//  用纯 CoreGraphics 把库边、jaw 直线段、jaw 圆弧、喉腔侧/后壁、落袋孔、袋口标记、
//  幽灵球、瞄准点、母球/目标球真实轨迹一并画出。
//
//  运行：
//    xcodebuild test -scheme QiuJi \
//      -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
//      -only-testing:QiuJiTests/ShotScenarioRenderTests
//
//  输出目录：build/shot_probe/*.png（每张是一个 cols×rows 的接触表）。
//

import XCTest
import UIKit
import SceneKit
@testable import QiuJi

final class ShotScenarioRenderTests: XCTestCase {

    private let outputDir = "/Users/song/projects/13.billiard_trainer/build/shot_probe"
    private let sY = BTTablePhysics.surfaceY
    private var R: Float { AngleSceneCalculator.ballRadius }

    // MARK: - 场景定义

    private struct Scenario {
        var title: String
        var cue: SCNVector3
        var target: SCNVector3
        var pocketIndex: Int
        var velocity: Float
        var spinX: Float = 0
        var spinY: Float = 0
    }

    /// 给定目标球位置、目标袋、切球角（度）与母球-幽灵球距离，反推母球位置。
    /// cut 正方向：把进球线（target→pocket）逆时针旋转 cut 得到撞击线方向。
    private func placeCue(target: SCNVector3, pocketIndex: Int, cutDeg: Float, dist: Float = 0.4) -> SCNVector3 {
        let pocket = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: target, pocketIndex: pocketIndex, surfaceY: sY)
        let ghost = AngleSceneCalculator.ghostBallPosition(
            targetBall: target, pocket: pocket, ballRadius: R)
        let pdx = pocket.x - target.x, pdz = pocket.z - target.z
        let pl = max(sqrtf(pdx * pdx + pdz * pdz), 1e-5)
        let pd = SCNVector3(pdx / pl, 0, pdz / pl)
        let th = cutDeg * .pi / 180
        let strikeDir = SCNVector3(pd.x * cosf(th) - pd.z * sinf(th), 0,
                                   pd.x * sinf(th) + pd.z * cosf(th))
        let raw = SCNVector3(ghost.x - strikeDir.x * dist, sY + R, ghost.z - strikeDir.z * dist)
        // 钳到可玩区（球心矩形）：避免贴库目标球 + 大切角把母球摆到台外（非法摆位 → 母球打不到
        // 目标球，objMin 恒为静止距离）。钳制后仍保持远离目标球，是合法可击打的近似摆位。
        let halfL = AngleSceneCalculator.innerLength / 2 - R - 0.01
        let halfW = AngleSceneCalculator.innerWidth / 2 - R - 0.01
        return SCNVector3(max(-halfL, min(halfL, raw.x)), sY + R, max(-halfW, min(halfW, raw.z)))
    }

    // MARK: - 矩阵 1：角袋（右上 idx1）切角 × 力度（无塞）

    func test_render_corner_cutVsSpeed() throws {
        try ensureDir()
        let pocketIndex = 1
        let cuts: [Float] = [0, 15, 30, 45, 55]
        let vels: [Float] = [2.4, 3.3, 4.4, 5.8]
        // 目标球放在右上袋附近击球区一侧。idx1=(+1.30,-0.665)，target 在 -z 上方一点。
        let target = SCNVector3(0.55, sY + R, -0.10)
        var grid: [[Scenario]] = []
        for cut in cuts {
            var row: [Scenario] = []
            for v in vels {
                let cue = placeCue(target: target, pocketIndex: pocketIndex, cutDeg: cut)
                row.append(Scenario(title: String(format: "角袋 cut%.0f° v%.1f", cut, v),
                                    cue: cue, target: target, pocketIndex: pocketIndex, velocity: v))
            }
            grid.append(row)
        }
        try renderSheet("01_corner_cut_x_speed", grid: grid)
    }

    // MARK: - 矩阵 2：中袋（下中 idx5）切角 × 力度（无塞）

    func test_render_middle_cutVsSpeed() throws {
        try ensureDir()
        let pocketIndex = 5
        let cuts: [Float] = [0, 15, 30, 45]
        let vels: [Float] = [1.6, 2.4, 3.3, 4.4, 5.8]
        let target = SCNVector3(0.0, sY + R, 0.18)
        var grid: [[Scenario]] = []
        for cut in cuts {
            var row: [Scenario] = []
            for v in vels {
                let cue = placeCue(target: target, pocketIndex: pocketIndex, cutDeg: cut)
                row.append(Scenario(title: String(format: "中袋 cut%.0f° v%.1f", cut, v),
                                    cue: cue, target: target, pocketIndex: pocketIndex, velocity: v))
            }
            grid.append(row)
        }
        try renderSheet("02_middle_cut_x_speed", grid: grid)
    }

    // MARK: - 矩阵 3：塞（spin）变化 × 力度（固定角袋近直球）

    func test_render_spin_x_speed() throws {
        try ensureDir()
        let pocketIndex = 1
        let target = SCNVector3(0.55, sY + R, -0.10)
        let spins: [(String, Float, Float)] = [
            ("无塞", 0, 0), ("左塞0.6", 0.6, 0), ("右塞0.6", -0.6, 0),
            ("高杆0.6", 0, 0.6), ("低杆0.6", 0, -0.6)
        ]
        let vels: [Float] = [3.3, 4.4, 5.8]
        var grid: [[Scenario]] = []
        for (lbl, sx, syp) in spins {
            var row: [Scenario] = []
            for v in vels {
                let cue = placeCue(target: target, pocketIndex: pocketIndex, cutDeg: 25)
                row.append(Scenario(title: "\(lbl) v\(String(format: "%.1f", v))",
                                    cue: cue, target: target, pocketIndex: pocketIndex,
                                    velocity: v, spinX: sx, spinY: syp))
            }
            grid.append(row)
        }
        try renderSheet("03_spin_x_speed", grid: grid)
    }

    // MARK: - 矩阵 4：典型业务球形（drill / 默认 / 各袋直球）

    func test_render_canonicalLayouts() throws {
        try ensureDir()
        func sc(_ t: String, cueN: CGPoint, tgtN: CGPoint, pk: Int, v: Float) -> Scenario {
            Scenario(title: t,
                     cue: AngleSceneCalculator.normalizedToScene(point: cueN, surfaceY: sY),
                     target: AngleSceneCalculator.normalizedToScene(point: tgtN, surfaceY: sY),
                     pocketIndex: pk, velocity: v)
        }
        var grid: [[Scenario]] = []
        // 默认开箱球形（与 placeBallsAtDefaults 一致），自动选袋（先固定右上 idx1）。
        let defCue = SCNVector3(-0.35, sY + R, 0.22)
        let defTgt = SCNVector3(0.55, sY + R, -0.18)
        grid.append([
            Scenario(title: "默认球形 v3.3", cue: defCue, target: defTgt, pocketIndex: 1, velocity: 3.3),
            sc("c002近直 br v3.3", cueN: CGPoint(x: 0.30, y: 0.25), tgtN: CGPoint(x: 0.75, y: 0.40), pk: 3, v: 3.3),
            // 左上角袋直球：cue 在右下，target 偏左上。
            Scenario(title: "左上角袋直 v3.3",
                     cue: SCNVector3(0.0, sY + R, 0.10), target: SCNVector3(-0.55, sY + R, -0.10),
                     pocketIndex: 0, velocity: 3.3),
        ])
        grid.append([
            // 各角袋近直球（4 角）
            Scenario(title: "右下角袋直 v3.3",
                     cue: SCNVector3(0.0, sY + R, -0.10), target: SCNVector3(0.55, sY + R, 0.10),
                     pocketIndex: 3, velocity: 3.3),
            Scenario(title: "左下角袋直 v3.3",
                     cue: SCNVector3(0.0, sY + R, -0.10), target: SCNVector3(-0.55, sY + R, 0.10),
                     pocketIndex: 2, velocity: 3.3),
            Scenario(title: "上中袋直 v3.3",
                     cue: SCNVector3(0.0, sY + R, 0.20), target: SCNVector3(0.0, sY + R, -0.18),
                     pocketIndex: 4, velocity: 3.3),
        ])
        try renderSheet("04_canonical_layouts", grid: grid)
    }

    // MARK: - 渲染：贴库/近袋位置类 + 近库塞×力度

    func test_render_cushionAndPocketProximity() throws {
        try ensureDir()
        func s(_ label: String, _ tx: Float, _ tz: Float, _ pk: Int, cut: Float, v: Float) -> Scenario {
            let tgt = SCNVector3(tx, sY + R, tz)
            return Scenario(title: label, cue: placeCue(target: tgt, pocketIndex: pk, cutDeg: cut, dist: 0.45),
                            target: tgt, pocketIndex: pk, velocity: v)
        }
        let grid: [[Scenario]] = [
            [s("近长库上→上中 cut35", 0.2, -0.55, 4, cut: 35, v: 3.3),
             s("近长库下→下中 cut35", -0.2, 0.55, 5, cut: 35, v: 3.3)],
            [s("近短库右→右上 cut40", 1.05, 0.10, 1, cut: 40, v: 3.3),
             s("近短库左→左上 cut40", -1.05, -0.10, 0, cut: 40, v: 3.3)],
            [s("近角袋RU→右上 cut50", 1.05, -0.45, 1, cut: 50, v: 4.4),
             s("近中袋下→下中 cut30", 0.12, 0.50, 5, cut: 30, v: 3.3)],
            [s("半台斜→右上 cut55", 0.4, -0.2, 1, cut: 55, v: 4.4),
             s("开阔中心→左上 cut45", 0.0, 0.0, 0, cut: 45, v: 5.8)],
        ]
        try renderSheet("06_cushion_pocket_proximity", grid: grid)
    }

    func test_render_spinNearCushion() throws {
        try ensureDir()
        let target = SCNVector3(0.0, sY + R, 0.50)   // 近下长库，打下中袋（近直），看塞对走位影响
        let pk = 5
        let spins: [(String, Float, Float)] = [
            ("无塞", 0, 0), ("高杆", 0, 0.7), ("低杆", 0, -0.7), ("左塞", 0.7, 0), ("右塞", -0.7, 0)
        ]
        let vels: [Float] = [2.4, 3.3, 4.4]
        var grid: [[Scenario]] = []
        for (lbl, sx, sy) in spins {
            var row: [Scenario] = []
            for v in vels {
                let cue = placeCue(target: target, pocketIndex: pk, cutDeg: 20, dist: 0.45)
                row.append(Scenario(title: "\(lbl) v\(String(format: "%.1f", v))",
                                    cue: cue, target: target, pocketIndex: pk, velocity: v, spinX: sx, spinY: sy))
            }
            grid.append(row)
        }
        try renderSheet("07_spin_near_cushion", grid: grid)
    }

    // MARK: - 综合排列组合矩阵（位置类×袋口×切角×力度×塞）

    /// 大规模组合覆盖：目标球/母球靠长库/短库/袋口/开阔 × 多袋口 × 多切角 × 5 档力度 × 塞（高低左右）。
    /// 核心不变量（用户定义）：可行球的目标球应**沿进球线方向**离开（进球线方向对）——
    /// 进袋最好；力度不足/太薄可如实未进；但**绝不允许「方向错的多库翻袋」**（未进且初始方向偏离
    /// 进球线 > 25° = BAD）。打印分类统计 + 逐条列出 BAD 与刮杆，供回归核对。
    func test_diag_combinatorialMatrix() {
        struct Pos { let label: String; let p: SCNVector3 }
        func t(_ l: String, _ x: Float, _ z: Float) -> Pos { Pos(label: l, p: SCNVector3(x, sY + R, z)) }
        // 目标球位置类 + 各自一个合理可行袋。
        let targets: [(Pos, Int)] = [
            (t("开阔中心", 0, 0), 1),
            (t("近长库上", 0.2, -0.55), 4),
            (t("近长库下", -0.2, 0.55), 5),
            (t("近短库右", 1.05, 0.10), 1),
            (t("近短库左", -1.05, -0.10), 0),
            (t("近角袋RU", 1.05, -0.45), 1),
            (t("近中袋下", 0.12, 0.50), 5),
            (t("半台斜", 0.4, -0.2), 1),
        ]
        let cuts: [Float] = [20, 45, 65]
        let forces: [Float] = [1.6, 3.3, 5.8]
        let spins: [(String, Float, Float)] = [
            ("无塞", 0, 0), ("高杆", 0, 0.7), ("低杆", 0, -0.7), ("左塞", 0.7, 0), ("右塞", -0.7, 0)
        ]

        var total = 0, potted = 0, dirOKMiss = 0, scratch = 0, noMove = 0
        var bad: [String] = []
        print("\n===DIAG-COMBINATORIAL===")
        for (tg, pk) in targets {
            for cut in cuts {
                let cue = placeCue(target: tg.p, pocketIndex: pk, cutDeg: cut, dist: 0.45)
                for f in forces {
                    for (sl, sx, sy) in spins {
                        total += 1
                        let pred = ShotPredictor.predict(ShotInput(
                            cueBall: cue, targetBall: tg.p, pocketIndex: pk,
                            velocity: f, spinX: sx, spinY: sy, surfaceY: sY))
                        guard pred.feasible else { continue }
                        if pred.cuePocketed { scratch += 1 }
                        if pred.objectPocketed { potted += 1; continue }
                        // 未进：检查目标球初始方向是否对（进球线方向）。
                        guard let de = objInitialDirErrDeg(pred, target: tg.p) else { noMove += 1; continue }
                        if de <= 25 { dirOKMiss += 1 }
                        else {
                            bad.append(String(format: "  ⚠️BAD %@→袋%d cut%.0f f%.1f %@: 方向偏%.0f° objMin%.0fmm",
                                              tg.label, pk, cut, f, sl, de, objMinDist(pred, pocketIndex: pk) * 1000))
                        }
                    }
                }
            }
        }
        print(String(format: "总计%d: 进袋%d / 方向对未进%d / 球几乎不动%d / 刮杆%d / ⚠️方向错(翻袋)%d",
                     total, potted, dirOKMiss, noMove, scratch, bad.count))
        bad.forEach { print($0) }
        print("===END-DIAG===\n")
        XCTAssertTrue(bad.count <= 2, "出现 \(bad.count) 例方向错的多库翻袋解（应≈0）")
    }

    /// 目标球轨迹初始段方向 vs 进球线(target→pocketAimPoint) 的夹角（度）。nil = 球未移动。
    private func objInitialDirErrDeg(_ pred: ShotPrediction, target: SCNVector3) -> Float? {
        guard pred.objectPath.count >= 2 else { return nil }
        let a = pred.objectPath[0], b = pred.objectPath[1]
        let dx = b.x - a.x, dz = b.z - a.z
        let l = sqrtf(dx * dx + dz * dz)
        guard l > 1e-4 else { return nil }
        let pdx = pred.pocketAimPoint.x - target.x, pdz = pred.pocketAimPoint.z - target.z
        let pl = sqrtf(pdx * pdx + pdz * pdz)
        guard pl > 1e-4 else { return nil }
        let dot = max(-1, min(1, (dx * pdx + dz * pdz) / (l * pl)))
        return acosf(dot) * 180 / .pi
    }

    // MARK: - 诊断：切角扫描（用户报告 >60° 失效变多库翻袋）

    /// 中台目标球 → 同一角袋，切角 0→85° 扫描；目标球进袋路线**恒为 target→pocket 直线**，
    /// 大切角只是动量小/throw 大，理应加力可进、绝不该变多库翻袋。打印 + 出图核对。
    func test_render_cutSweep_longShot() throws {
        try ensureDir()
        let pocketIndex = 1
        let target = SCNVector3(0.0, sY + R, 0.0)   // 台面中心
        let cuts: [Float] = [30, 45, 55, 65, 75, 85]
        let vels: [Float] = [3.3, 5.8]
        var grid: [[Scenario]] = []
        for cut in cuts {
            var row: [Scenario] = []
            for v in vels {
                let cue = placeCue(target: target, pocketIndex: pocketIndex, cutDeg: cut, dist: 0.45)
                row.append(Scenario(title: String(format: "中台 cut%.0f° v%.1f", cut, v),
                                    cue: cue, target: target, pocketIndex: pocketIndex, velocity: v))
            }
            grid.append(row)
        }
        try renderSheet("05_cutSweep_longShot", grid: grid)
    }

    /// 通用进袋着陆景观：对失败用例扫描瞄准偏移，看是否存在求解器漏掉的直接进袋带。
    func test_diag_landscape_failingCases() {
        let cases: [(String, SCNVector3, Int, Float, Float)] = [
            ("中台→idx1 cut15 v5.8", SCNVector3(0, sY + R, 0), 1, 15, 5.8),
            ("中台→idx0 cut30 v5.8", SCNVector3(0, sY + R, 0), 0, 30, 5.8),
            ("中台→idx0 cut75 v5.8", SCNVector3(0, sY + R, 0), 0, 75, 5.8),
        ]
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: sY)
        print("\n===DIAG-LANDSCAPE-FAILING=== (offset -6..+6 /0.5, P=进选定袋 直接进, b=吃库进)")
        for (label, target, pk, cut, v) in cases {
            let pocket = AngleSceneCalculator.pocketPositions(surfaceY: sY)[pk]
            let cue = placeCue(target: target, pocketIndex: pk, cutDeg: cut, dist: 0.45)
            let pAim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pk, surfaceY: sY)
            let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: pAim, ballRadius: R)
            let baseAim = unit(from: cue, to: ghost)
            var line = label + ": "
            var off: Float = -6
            while off <= 6.001 {
                let strike = CueBallStrike.executeStrike(aimDirection: rotY(baseAim, off * .pi / 180), velocity: v, spinX: 0, spinY: 0, elevation: 0)
                let engine = EventDrivenEngine(tableGeometry: geometry)
                engine.setBall(BallState(position: SCNVector3(cue.x, sY + R, cue.z), velocity: strike.velocity, angularVelocity: strike.angularVelocity, state: .sliding, name: ShotInput.cueBallName))
                engine.setBall(BallState(position: SCNVector3(target.x, sY + R, target.z), velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero, state: .stationary, name: ShotInput.targetBallName))
                engine.simulate(maxEvents: 500, maxTime: 15)
                var pid: String?
                var cushions = 0
                for ev in engine.resolvedEvents {
                    switch ev {
                    case .ballCushion(let b, _, _) where b == ShotInput.targetBallName: if pid == nil { cushions += 1 }
                    case .pocket(let b, let p) where b == ShotInput.targetBallName: pid = p
                    default: break
                    }
                }
                let mark: String
                if pid == "pocket_\(pk)" { mark = cushions == 0 ? "P" : "b" } else { mark = "." }
                line += mark
                off += 0.5
            }
            print(line)
            // offset 0 细查：目标球碰后方向 vs 进球线方向、球-球碰撞次数（双击检测）。
            let strike0 = CueBallStrike.executeStrike(aimDirection: baseAim, velocity: v, spinX: 0, spinY: 0, elevation: 0)
            let e0 = EventDrivenEngine(tableGeometry: geometry)
            e0.setBall(BallState(position: SCNVector3(cue.x, sY + R, cue.z), velocity: strike0.velocity, angularVelocity: strike0.angularVelocity, state: .sliding, name: ShotInput.cueBallName))
            e0.setBall(BallState(position: SCNVector3(target.x, sY + R, target.z), velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero, state: .stationary, name: ShotInput.targetBallName))
            e0.simulate(maxEvents: 500, maxTime: 15)
            var bbCount = 0
            var firstBBTime: Float?
            for (ev, t) in zip(e0.resolvedEvents, e0.resolvedEventTimes) {
                if case .ballBall = ev { bbCount += 1; if firstBBTime == nil { firstBBTime = t } }
            }
            // 目标球碰后方向
            let rec = e0.getTrajectoryRecorder()
            var objDirDeg = Float(-999)
            if let ct = firstBBTime, let frames = rec.framesByBallName[ShotInput.targetBallName]?.sorted(by: { $0.time < $1.time }) {
                for f in frames where f.time >= ct - 1e-5 && f.velocity.length() > 0.01 {
                    objDirDeg = atan2f(f.velocity.z, f.velocity.x) * 180 / .pi; break
                }
            }
            let pl = sqrtf((pocket.x - target.x) * (pocket.x - target.x) + (pocket.z - target.z) * (pocket.z - target.z))
            let pockDirDeg = atan2f(pocket.z - target.z, pocket.x - target.x) * 180 / .pi
            print(String(format: "    @offset0: 球-球碰撞%d次 目标球碰后方向%.1f° vs 进球线%.1f° (差%.1f°) 袋距%.2fm",
                         bbCount, objDirDeg, pockDirDeg, objDirDeg - pockDirDeg, pl))
        }
        print("===END-DIAG===\n")
    }

    /// 复现用户截图（目标球近中心、母球下方、选左上角袋 idx0，切角 ~50° 未进）+ 左上袋切角扫描。
    func test_diag_screenshotRepro() {
        print("\n===DIAG-SCREENSHOT-REPRO===")
        // 截图近似坐标（由像素估算）。
        let target = SCNVector3(-0.10, sY + R, -0.10)
        let cue = SCNVector3(0.34, sY + R, 0.23)
        for pk in [0, 1, 2, 3, 4, 5] {
            let pred = ShotPredictor.predict(ShotInput(cueBall: cue, targetBall: target,
                pocketIndex: pk, velocity: 3.3, spinX: 0, spinY: 0, surfaceY: sY))
            print(String(format: "  pocket%d: feasible=%@ cut=%.0f° objPotted=%@ cuePot=%@ objMin=%.0fmm",
                         pk, pred.feasible ? "Y" : "N", pred.cutAngleDeg ?? -1,
                         pred.objectPocketed ? "进" : "✗", pred.cuePocketed ? "Y" : "N",
                         objMinDist(pred, pocketIndex: pk) * 1000))
        }
        // 左上角袋 idx0 切角扫描（target 中心，clean 摆位）。
        print("  -- idx0 左上角袋 切角扫描（target 中心，clean cue）--")
        let t2 = SCNVector3(0.0, sY + R, 0.0)
        for cut in [Float(30), 45, 55, 65, 75] {
            let c2 = placeCue(target: t2, pocketIndex: 0, cutDeg: cut, dist: 0.45)
            let pred = ShotPredictor.predict(ShotInput(cueBall: c2, targetBall: t2,
                pocketIndex: 0, velocity: 5.8, spinX: 0, spinY: 0, surfaceY: sY))
            print(String(format: "  idx0 cut%.0f° v5.8: objPotted=%@ cuePot=%@ objMin=%.0fmm",
                         cut, pred.objectPocketed ? "进" : "✗", pred.cuePocketed ? "Y" : "N",
                         objMinDist(pred, pocketIndex: 0) * 1000))
        }
        print("===END-DIAG===\n")
    }

    /// 纯文本切角扫描：打印 objectPocketed / 落袋前撞库数 / objMin / cuePot，定位 cliff。
    func test_diag_cutSweep() {
        let pocketIndex = 1
        let target = SCNVector3(0.0, sY + R, 0.0)
        print("\n===DIAG-CUT-SWEEP=== (中台→右上角袋 idx1)")
        for cut in [Float(0), 15, 30, 40, 50, 55, 60, 65, 70, 75, 80, 85] {
            var line = String(format: "cut%2.0f°:", cut)
            for v in [Float(3.3), 5.8] {
                let cue = placeCue(target: target, pocketIndex: pocketIndex, cutDeg: cut, dist: 0.45)
                let pred = ShotPredictor.predict(ShotInput(cueBall: cue, targetBall: target,
                    pocketIndex: pocketIndex, velocity: v, spinX: 0, spinY: 0, surfaceY: sY))
                line += String(format: " | v%.1f:%@%@(om%.0f)", v,
                               pred.objectPocketed ? "进" : "✗",
                               pred.cuePocketed ? "母进" : "",
                               objMinDist(pred, pocketIndex: pocketIndex) * 1000)
            }
            print(line)
        }
        print("===END-DIAG===\n")
    }

    // MARK: - 诊断：进袋着陆景观（offset 扫描）

    /// 对一个固定球形/袋口/力度，手动扫描瞄准偏移 offset，打印目标球：
    /// 引擎是否进袋、轨迹到袋心最近(raw)、终点到袋心、是否飞出台面。
    /// 用于判断「某力度未进」是求解器漏掉了进球带，还是物理上确实进不去。
    func test_diag_corner_landscape() {
        let pocketIndex = 1
        let target = SCNVector3(0.55, sY + R, -0.10)
        let pocket = AngleSceneCalculator.pocketPositions(surfaceY: sY)[pocketIndex]
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: sY)
        let captureWindow = AngleSceneCalculator.pocketDropRadius(index: pocketIndex) - R + 0.003

        print("\n===DIAG-CORNER-LANDSCAPE=== (cut15, captureWin=\(String(format: "%.1f", captureWindow*1000))mm)")
        for v in [Float(2.4), 3.3, 4.4] {
            let cue = placeCue(target: target, pocketIndex: pocketIndex, cutDeg: 15)
            let pAim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: sY)
            let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: pAim, ballRadius: R)
            let baseAim = unit(from: cue, to: ghost)
            print(String(format: "-- v%.1f --  offset扫描(°): potted/minRaw/finalD/left", v))
            var line = ""
            var off: Float = -3
            while off <= 3.001 {
                let aim = rotY(baseAim, off * .pi / 180)
                let res = simObject(cue: cue, target: target, aim: aim, velocity: v, geometry: geometry, pocket: pocket)
                let mark = res.pocketed ? "P" : (res.minRaw <= captureWindow ? "p" : ".")
                line += String(format: " %+.2f:%@%.0f/%.0f%@", off, mark, res.minRaw*1000, res.finalD*1000, res.leftTable ? "L" : "")
                off += 0.5
            }
            print(line)
        }
        print("===END-DIAG===\n")
    }

    /// 直接核对 predict() 的判定与其 clamped 轨迹真值（对比引擎是否进袋）。
    func test_diag_predict_vs_engine() {
        let pocketIndex = 1
        let target = SCNVector3(0.55, sY + R, -0.10)
        let pocket = AngleSceneCalculator.pocketPositions(surfaceY: sY)[pocketIndex]
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: sY)
        print("\n===DIAG-PREDICT-VS-ENGINE=== (cut15 corner idx1)")
        for v in [Float(2.4), 3.3, 4.4, 5.8] {
            let cue = placeCue(target: target, pocketIndex: pocketIndex, cutDeg: 15)
            let pred = ShotPredictor.predict(ShotInput(cueBall: cue, targetBall: target,
                pocketIndex: pocketIndex, velocity: v, spinX: 0, spinY: 0, surfaceY: sY))
            // clamped 轨迹真值
            var clMin = Float.greatestFiniteMagnitude
            var clFinal = target
            if let fr = pred.recorder?.framesByBallName[ShotInput.targetBallName]?.sorted(by: { $0.time < $1.time }) {
                for f in fr {
                    let dx = f.position.x - pocket.x, dz = f.position.z - pocket.z
                    clMin = min(clMin, sqrtf(dx * dx + dz * dz)); clFinal = f.position
                }
            }
            let engPot = pred.recorder?.isBallPocketed(ShotInput.targetBallName) ?? false
            let cfd = sqrtf((clFinal.x - pocket.x) * (clFinal.x - pocket.x) + (clFinal.z - pocket.z) * (clFinal.z - pocket.z))
            print(String(format: "v%.1f: objPotted=%@ simPotted=%@ enginePotted=%@ clampMin=%.0fmm clampFinal=%.0fmm",
                         v, pred.objectPocketed ? "Y" : "N", pred.simObjectPotted ? "Y" : "N",
                         engPot ? "Y" : "N", clMin * 1000, cfd * 1000))
        }
        print("===END-DIAG===\n")
    }

    private struct ObjSim {
        var minRaw: Float
        var finalD: Float
        var pocketed: Bool
        var leftTable: Bool
    }

    /// 复刻 solveAimOffset 的短模拟评分，打印每个粗扫 offset 的 pottedSelected/score。
    func test_diag_solver_scoring() {
        let pocketIndex = 1
        let target = SCNVector3(0.55, sY + R, -0.10)
        let pocket = AngleSceneCalculator.pocketPositions(surfaceY: sY)[pocketIndex]
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: sY)
        print("\n===DIAG-SOLVER-SCORING=== (cut15 corner idx1, short sim 140ev/7s)")
        for v in [Float(3.3)] {
            let cue = placeCue(target: target, pocketIndex: pocketIndex, cutDeg: 15)
            let pAim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: sY)
            let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: pAim, ballRadius: R)
            let baseAim = unit(from: cue, to: ghost)
            print("v\(v): offset:potSel/objMin/pocketId")
            var line = ""
            var off: Float = -2
            while off <= 2.001 {
                let aim = rotY(baseAim, off * .pi / 180)
                let s = solverShot(cue: cue, target: target, aim: aim, velocity: v, geometry: geometry, pocket: pocket, pocketIndex: pocketIndex)
                line += String(format: " %+.1f:%@%.0f/%@", off, s.pottedSelected ? "P" : ".", s.objMin * 1000, s.pocketId ?? "-")
                off += 0.5
            }
            print(line)
        }
        print("===END-DIAG===\n")
    }

    /// 完整复刻 solveAimOffset 三遍扫描 + 评分，打印各阶段所选 offset 与 score。
    func test_diag_full_solver() {
        let pocketIndex = 1
        let target = SCNVector3(0.55, sY + R, -0.10)
        let pocket = AngleSceneCalculator.pocketPositions(surfaceY: sY)[pocketIndex]
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: sY)
        let v: Float = 3.3
        let cue = placeCue(target: target, pocketIndex: pocketIndex, cutDeg: 15)
        let pAim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: sY)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: pAim, ballRadius: R)
        let baseAim = unit(from: cue, to: ghost)

        func scoreFn(_ off: Float) -> (Float, Bool, Float) {
            let aim = rotY(baseAim, off)
            let s = solverShot(cue: cue, target: target, aim: aim, velocity: v, geometry: geometry, pocket: pocket, pocketIndex: pocketIndex, ev: 500, t: 15)
            let score: Float = s.pottedSelected ? (-10 + abs(off) * 1e-3) : (s.objMin + abs(off) * 1e-4)
            return (score, s.pottedSelected, s.objMin)
        }
        let deg = Float.pi / 180
        func bestOf(center: Float, halfRange: Float, step: Float) -> Float {
            var bo = center, bs = Float.greatestFiniteMagnitude
            var o = center - halfRange
            while o <= center + halfRange + 1e-6 {
                let (s, _, _) = scoreFn(o)
                if s < bs { bs = s; bo = o }
                o += step
            }
            return bo
        }
        print("\n===DIAG-FULL-SOLVER=== v\(v) cut15 corner (500/15)")
        // 粗扫近 0 的样本
        var s2 = "coarse near0:"
        for k in -4...8 {
            let off = Float(k) * 0.2 * deg
            let (_, p, om) = scoreFn(off)
            s2 += String(format: " %.1f:%@%.0f", off / deg, p ? "P" : ".", om * 1000)
        }
        print(s2)
        let c = bestOf(center: 0, halfRange: 12 * deg, step: 0.2 * deg)
        let m = bestOf(center: c, halfRange: 0.3 * deg, step: 0.05 * deg)
        let f = bestOf(center: m, halfRange: 0.06 * deg, step: 0.01 * deg)
        print(String(format: "coarse=%.3f° mid=%.3f° fine=%.3f°", c / deg, m / deg, f / deg))
        let (sc, pot, omin) = scoreFn(f)
        print(String(format: "final offset=%.3f° score=%.3f potted=%@ objMin=%.0fmm", f / deg, sc, pot ? "Y" : "N", omin * 1000))
        print("===END-DIAG===\n")
    }

    /// 实验：去除喉腔弹珠箱 + 调大落袋捕获半径（漏斗模型）后的进袋带连续性。
    /// 同时验证「过力度薄切」仍未进（jaw 闸口仍在）。
    func test_diag_funnel_experiment() {
        let pocketIndex = 1
        let target = SCNVector3(0.55, sY + R, -0.10)
        let pocket = AngleSceneCalculator.pocketPositions(surfaceY: sY)[pocketIndex]
        let cushions = TableGeometry.chineseEightBallCushions(y: sY)
        let centers = AngleSceneCalculator.pocketPositions(surfaceY: sY)

        func makeGeometry(cornerR: Float, middleR: Float) -> TableGeometry {
            var pockets: [Pocket] = []
            for (i, c) in centers.enumerated() {
                pockets.append(Pocket(id: "pocket_\(i)", center: SCNVector3(c.x, sY, c.z),
                                      radius: i < 4 ? cornerR : middleR, isCorner: i < 4))
            }
            // 无喉腔箱：只用基础库（直库 + jaw 直线段 + jaw 圆弧 + 中袋圆角）。
            return TableGeometry(linearCushions: cushions.linear, circularCushions: cushions.circular, pockets: pockets)
        }

        let baseAimFor: (Float) -> SCNVector3 = { cutDeg in
            let cue = self.placeCue(target: target, pocketIndex: pocketIndex, cutDeg: cutDeg)
            let pAim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: self.sY)
            let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: pAim, ballRadius: self.R)
            return self.unit(from: cue, to: ghost)
        }

        func makeGeometryNoArc(cornerR: Float, middleR: Float) -> TableGeometry {
            var pockets: [Pocket] = []
            for (i, c) in centers.enumerated() {
                pockets.append(Pocket(id: "pocket_\(i)", center: SCNVector3(c.x, sY, c.z),
                                      radius: i < 4 ? cornerR : middleR, isCorner: i < 4))
            }
            return TableGeometry(linearCushions: cushions.linear, circularCushions: [], pockets: pockets)
        }

        func bandStr(_ geo: TableGeometry, cut: Float, v: Float) -> String {
            let cue = placeCue(target: target, pocketIndex: pocketIndex, cutDeg: cut)
            let base = baseAimFor(cut)
            var band = ""
            var off: Float = -1.0
            while off <= 2.0001 {
                let s = solverShot(cue: cue, target: target, aim: rotY(base, off * .pi / 180),
                                   velocity: v, geometry: geo, pocket: pocket, pocketIndex: pocketIndex, ev: 500, t: 15)
                band += s.pottedSelected ? "P" : "."
                off += 0.1
            }
            return band   // offset -1.0 .. +2.0 step 0.1
        }

        print("\n===DIAG-FUNNEL-EXPERIMENT=== (offset -1.0..+2.0 /0.1)")
        for cornerR in [Float(0.075), 0.090, 0.105] {
            let geoArc = makeGeometry(cornerR: cornerR, middleR: 0.082)
            let geoNoArc = makeGeometryNoArc(cornerR: cornerR, middleR: 0.082)
            print(String(format: "cornerR=%.0fmm:  arc cut15v3.3: %@", cornerR * 1000, bandStr(geoArc, cut: 15, v: 3.3)))
            print(String(format: "             noArc cut15v3.3: %@", bandStr(geoNoArc, cut: 15, v: 3.3)))
            print(String(format: "               arc cut30v3.3: %@", bandStr(geoArc, cut: 30, v: 3.3)))
            print(String(format: "               arc cut45v3.3: %@", bandStr(geoArc, cut: 45, v: 3.3)))
        }
        print("===END-DIAG===\n")
    }

    /// 短模拟(140/7) vs 全模拟(500/15) 在 v3.3 cut15 的进袋带对比。
    func test_diag_band_compare() {
        let pocketIndex = 1
        let target = SCNVector3(0.55, sY + R, -0.10)
        let pocket = AngleSceneCalculator.pocketPositions(surfaceY: sY)[pocketIndex]
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: sY)
        let v: Float = 3.3
        let cue = placeCue(target: target, pocketIndex: pocketIndex, cutDeg: 15)
        let pAim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: sY)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: pAim, ballRadius: R)
        let baseAim = unit(from: cue, to: ghost)
        _ = (cue, baseAim, v)
        print("\n===DIAG-BAND-COMPARE=== cut15 production geo, full500/15, offset -1.0..+2.0/0.1")
        for cutDeg in [Float(15)] {
            for vel in [Float(2.4), 3.3, 4.4, 5.8] {
                let c = placeCue(target: target, pocketIndex: pocketIndex, cutDeg: cutDeg)
                let pA = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: sY)
                let gh = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: pA, ballRadius: R)
                let ba = unit(from: c, to: gh)
                var line = String(format: "cut%2.0f v%.1f: ", cutDeg, vel)
                var off: Float = -1.0
                while off <= 2.0001 {
                    let fu = solverShot(cue: c, target: target, aim: rotY(ba, off * .pi / 180), velocity: vel,
                                        geometry: geometry, pocket: pocket, pocketIndex: pocketIndex, ev: 500, t: 15)
                    line += fu.pottedSelected ? "P" : "."
                    off += 0.1
                }
                print(line)
            }
        }
        print("===END-DIAG===\n")
    }

    // MARK: - 吃库后立即冻结诊断（穿库安全网误伤 / 真实穿库）

    /// 扫描多种摆位，找出「母球吃库后仍很快却被钳制冻结」的场景。
    /// 对每个场景：跑 predict 得到 clamped 轨迹 + 有效时长；另跑原始引擎得到未钳制轨迹，
    /// 沿时间采样找出母球第一次离开可玩区（= 钳制触发点）及其速度。
    func test_diag_cushionFreeze() {
        struct Case { let title: String; let cue: SCNVector3; let target: SCNVector3; let pocket: Int; let v: Float }
        // 覆盖角袋/中袋 + 不同切角 + 母球碰后会撞短库/长库的摆位。
        var cases: [Case] = []
        let targets: [(SCNVector3, Int, String)] = [
            (SCNVector3(-0.30, sY + R, -0.05), 0, "左上角idx0"),
            (SCNVector3(0.55, sY + R, -0.10), 1, "右上角idx1"),
            (SCNVector3(0.0, sY + R, 0.18), 5, "下中idx5"),
            (SCNVector3(0.30, sY + R, 0.05), 3, "右下角idx3"),
        ]
        for (tg, pk, name) in targets {
            for cut in [Float(0), 9, 20, 35, 50] {
                for v in [Float(3.3), 4.4, 5.8] {
                    let cue = placeCue(target: tg, pocketIndex: pk, cutDeg: cut)
                    cases.append(Case(title: String(format: "%@ cut%.0f v%.1f", name, cut, v),
                                      cue: cue, target: tg, pocket: pk, v: v))
                }
            }
        }

        print("\n===DIAG-CUSHION-FREEZE=== (检查 predict 自身钳制轨迹是否「仍快却冻结」)")
        var badCount = 0
        for c in cases {
            let pred = ShotPredictor.predict(ShotInput(cueBall: c.cue, targetBall: c.target,
                pocketIndex: c.pocket, velocity: c.v, spinX: 0, spinY: 0, surfaceY: sY))
            // 在 predict 的钳制轨迹里找母球「上一帧很快(>0.3m/s) → 本帧变静止」的突停，且突停点
            // 不在袋口嘴内 = 误冻结（吃库立停）。落袋/正常减速到停不算。
            let cl = pred.recorder?.framesByBallName[ShotInput.cueBallName]?.sorted { $0.time < $1.time } ?? []
            var bad: (t: Float, prevSpeed: Float, pos: SCNVector3)?
            for i in 1..<max(cl.count, 1) {
                let prev = cl[i - 1], cur = cl[i]
                let nearPocket = AngleSceneCalculator.pocketPositions(surfaceY: sY).contains { pk in
                    let dx = cur.position.x - pk.x, dz = cur.position.z - pk.z
                    return dx * dx + dz * dz <= 0.14 * 0.14
                }
                if cur.state == .stationary && prev.velocity.length() > 0.3 && !nearPocket {
                    bad = (cur.time, prev.velocity.length(), cur.position); break
                }
            }
            if let b = bad {
                badCount += 1
                print(String(format: "[%@] 仍快却冻结@t=%.2fs prevSpeed=%.2fm/s pos=(%.3f,%.3f) effDur=%.2f",
                             c.title, b.t, b.prevSpeed, b.pos.x, b.pos.z, pred.duration))
            }
        }
        print("误冻结场景数=\(badCount)/\(cases.count)")
        print("===END-DIAG===\n")
        // 回归守卫：吃库后仍高速却被穿库安全网误冻结 = 0（FL：吃库后立即停住）。
        XCTAssertEqual(badCount, 0, "吃库后仍高速却被误冻结的场景应为 0")
    }

    /// 深挖单个失败场景：dump 母球原始 recorder 事件帧 + 引擎 resolvedEvents（看是真穿库还是深反弹）。
    func test_diag_cushionFreeze_detail() {
        let target = SCNVector3(-0.30, sY + R, -0.05)
        let pocketIndex = 0
        let v: Float = 5.8
        let cue = placeCue(target: target, pocketIndex: pocketIndex, cutDeg: 20)
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: sY)
        let pAim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: sY)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: pAim, ballRadius: R)
        let aim = unit(from: cue, to: ghost)
        let strike = CueBallStrike.executeStrike(aimDirection: aim, velocity: v, spinX: 0, spinY: 0, elevation: 0)
        let engine = EventDrivenEngine(tableGeometry: geometry)
        engine.setBall(BallState(position: SCNVector3(cue.x, sY + R, cue.z), velocity: strike.velocity,
                                 angularVelocity: strike.angularVelocity, state: .sliding, name: ShotInput.cueBallName))
        engine.setBall(BallState(position: SCNVector3(target.x, sY + R, target.z), velocity: SCNVector3Zero,
                                 angularVelocity: SCNVector3Zero, state: .stationary, name: ShotInput.targetBallName))
        engine.simulate(maxEvents: 500, maxTime: 15.0)
        let rec = engine.getTrajectoryRecorder()
        print("\n===DIAG-FREEZE-DETAIL=== cue=(\(cue.x),\(cue.z))")
        print("-- resolved events (cue/cushion/pocket) --")
        for (e, t) in zip(engine.resolvedEvents, engine.resolvedEventTimes) {
            switch e {
            case .ballCushion(let b, _, _): print(String(format: "  t=%.3f ballCushion %@", t, b))
            case .pocket(let b, let p): print(String(format: "  t=%.3f POCKET %@ -> %@", t, b, p))
            case .ballBall: print(String(format: "  t=%.3f ballBall", t))
            default: break
            }
        }
        print("-- cue recorder frames near z=±0.606 (|z|>0.58) --")
        if let fr = rec.framesByBallName[ShotInput.cueBallName]?.sorted(by: { $0.time < $1.time }) {
            for f in fr where abs(f.position.z) > 0.58 || abs(f.position.x) > 1.21 {
                print(String(format: "  t=%.3f pos=(%.4f,%.4f) vel=(%.2f,%.2f) |v|=%.2f state=%@",
                             f.time, f.position.x, f.position.z, f.velocity.x, f.velocity.z,
                             f.velocity.length(), String(describing: f.state)))
            }
        }
        print("===END-DIAG===\n")
    }

    /// 诊断「母球进袋（失误）」是否真实：扫描含加塞的曲线走位摆位，对每个上报 `cuePocketed`
    /// 的场景，检查母球**显示用钳制轨迹**到各袋心的最近距离与吃球瞬间的速度/入射角。
    /// - 假阳性：上报进袋但显示轨迹从未进入任一袋的捕获窗（判进画面不进）。
    /// - 漏斗吞快球：母球以高速、掠角擦过中袋嘴被纯几何捕获（物理上应翻袋而过）。
    func test_diag_cueScratch() {
        struct Case { let title: String; let cue: SCNVector3; let target: SCNVector3; let pocket: Int
                      let v: Float; let sx: Float; let sy: Float }
        var cases: [Case] = []
        // 含加塞（左右塞致曲线走位，复现截图中母球弧线擦中袋）+ 多袋口 + 力度。
        let targets: [(SCNVector3, Int, String)] = [
            (SCNVector3(-0.30, sY + R, -0.05), 0, "左上角idx0"),
            (SCNVector3(0.30, sY + R, 0.05), 3, "右下角idx3"),
            (SCNVector3(-0.10, sY + R, -0.18), 4, "上中idx4"),
            (SCNVector3(0.10, sY + R, 0.18), 5, "下中idx5"),
        ]
        for (tg, pk, name) in targets {
            for cut in [Float(9), 25, 45] {
                for v in [Float(3.3), 4.4, 5.8] {
                    for (sx, sy, sp) in [(Float(0), Float(0), "无塞"),
                                         (Float(0.5), 0, "右塞"), (Float(-0.5), 0, "左塞"),
                                         (Float(0), 0.5, "高杆"), (Float(0), -0.5, "低杆")] {
                        cases.append(Case(title: "\(name) cut\(Int(cut)) v\(v) \(sp)",
                                          cue: placeCue(target: tg, pocketIndex: pk, cutDeg: cut),
                                          target: tg, pocket: pk, v: v, sx: sx, sy: sy))
                    }
                }
            }
        }

        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: sY)
        var report = "===DIAG-CUE-SCRATCH=== (扫描 母球进袋判定 真实性)\n"
        var scratchCount = 0, falsePos = 0, funnelFast = 0
        for c in cases {
            let pred = ShotPredictor.predict(ShotInput(cueBall: c.cue, targetBall: c.target,
                pocketIndex: c.pocket, velocity: c.v, spinX: c.sx, spinY: c.sy, surfaceY: sY))
            guard pred.feasible, pred.cuePocketed else { continue }
            scratchCount += 1
            // 显示用钳制轨迹里母球到各袋心的最近距离 + 该最近帧的速度。
            let cf = pred.recorder?.framesByBallName[ShotInput.cueBallName]?
                .sorted { $0.time < $1.time } ?? []
            var best: (idx: Int, d: Float, speed: Float) = (-1, .greatestFiniteMagnitude, 0)
            for f in cf {
                for (pi, p) in pockets.enumerated() {
                    let dx = f.position.x - p.x, dz = f.position.z - p.z
                    let d = sqrtf(dx * dx + dz * dz)
                    if d < best.d { best = (pi, d, f.velocity.length()) }
                }
            }
            let win = AngleSceneCalculator.pocketDropRadius(index: best.idx) - R + 0.004
            let isMiddle = best.idx >= 4
            // 显示轨迹到任一袋心都进不了捕获窗 = 判进但画面不进（假阳性）。
            if best.d > win + 1e-4 {
                falsePos += 1
                report += String(format: "[假阳性] %@ → 上报进袋但钳制轨迹最近袋心 idx%d d=%.1fmm > win=%.1fmm\n",
                                 c.title, best.idx, best.d * 1000, win * 1000)
            } else if isMiddle && best.speed > 1.2 {
                funnelFast += 1
                report += String(format: "[漏斗吞快球] %@ → idx%d(中袋) 捕获时母球 |v|=%.2fm/s (掠袋嘴被纯几何吞)\n",
                                 c.title, best.idx, best.speed)
            }
        }
        report += "总上报母球进袋=\(scratchCount)/\(cases.count) | 假阳性(判进画面不进)=\(falsePos) | 中袋吞快球=\(funnelFast)\n"
        report += "===END-DIAG===\n"
        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        try? report.write(toFile: outputDir + "/diag_cue_scratch.txt", atomically: true, encoding: .utf8)
        print(report)
    }

    private func solverShot(cue: SCNVector3, target: SCNVector3, aim: SCNVector3, velocity: Float,
                            geometry: TableGeometry, pocket: SCNVector3, pocketIndex: Int,
                            ev: Int = 140, t: Float = 7.0)
        -> (pottedSelected: Bool, objMin: Float, pocketId: String?) {
        let strike = CueBallStrike.executeStrike(aimDirection: aim, velocity: velocity, spinX: 0, spinY: 0, elevation: 0)
        let engine = EventDrivenEngine(tableGeometry: geometry)
        engine.setBall(BallState(position: SCNVector3(cue.x, sY + R, cue.z), velocity: strike.velocity,
                                 angularVelocity: strike.angularVelocity, state: .sliding, name: ShotInput.cueBallName))
        engine.setBall(BallState(position: SCNVector3(target.x, sY + R, target.z), velocity: SCNVector3Zero,
                                 angularVelocity: SCNVector3Zero, state: .stationary, name: ShotInput.targetBallName))
        engine.simulate(maxEvents: ev, maxTime: t)
        let rec = engine.getTrajectoryRecorder()
        var minD = Float.greatestFiniteMagnitude
        if let fr = rec.framesByBallName[ShotInput.targetBallName] {
            for f in fr { let dx = f.position.x - pocket.x, dz = f.position.z - pocket.z; minD = min(minD, sqrtf(dx*dx+dz*dz)) }
        }
        var pid: String?
        for ev in engine.resolvedEvents { if case .pocket(let b, let p) = ev, b == ShotInput.targetBallName { pid = p } }
        return (pid == "pocket_\(pocketIndex)", minD, pid)
    }

    private func simObject(cue: SCNVector3, target: SCNVector3, aim: SCNVector3, velocity: Float,
                           geometry: TableGeometry, pocket: SCNVector3) -> ObjSim {
        let strike = CueBallStrike.executeStrike(aimDirection: aim, velocity: velocity, spinX: 0, spinY: 0, elevation: 0)
        let engine = EventDrivenEngine(tableGeometry: geometry)
        engine.setBall(BallState(position: SCNVector3(cue.x, sY + R, cue.z), velocity: strike.velocity,
                                 angularVelocity: strike.angularVelocity, state: .sliding, name: ShotInput.cueBallName))
        engine.setBall(BallState(position: SCNVector3(target.x, sY + R, target.z), velocity: SCNVector3Zero,
                                 angularVelocity: SCNVector3Zero, state: .stationary, name: ShotInput.targetBallName))
        engine.simulate(maxEvents: 200, maxTime: 8.0)
        let rec = engine.getTrajectoryRecorder()
        var minRaw = Float.greatestFiniteMagnitude
        var finalPos = target
        let halfL = AngleSceneCalculator.innerLength / 2, halfW = AngleSceneCalculator.innerWidth / 2
        var leftTable = false
        if let frames = rec.framesByBallName[ShotInput.targetBallName]?.sorted(by: { $0.time < $1.time }) {
            for f in frames {
                let dx = f.position.x - pocket.x, dz = f.position.z - pocket.z
                minRaw = min(minRaw, sqrtf(dx * dx + dz * dz))
                finalPos = f.position
                // 离开内框 + 袋口嘴(0.12) 视为离台
                if abs(f.position.x) > halfL - R + 0.006 && abs(f.position.z) > halfW - R + 0.006 {
                    let near = AngleSceneCalculator.pocketPositions(surfaceY: sY).contains { pk in
                        let ex = f.position.x - pk.x, ez = f.position.z - pk.z
                        return ex * ex + ez * ez <= 0.12 * 0.12
                    }
                    if !near { leftTable = true }
                }
            }
        }
        let fdx = finalPos.x - pocket.x, fdz = finalPos.z - pocket.z
        return ObjSim(minRaw: minRaw, finalD: sqrtf(fdx * fdx + fdz * fdz),
                      pocketed: rec.isBallPocketed(ShotInput.targetBallName), leftTable: leftTable)
    }

    private func unit(from a: SCNVector3, to b: SCNVector3) -> SCNVector3 {
        let dx = b.x - a.x, dz = b.z - a.z
        let l = max(sqrtf(dx * dx + dz * dz), 1e-5)
        return SCNVector3(dx / l, 0, dz / l)
    }
    private func rotY(_ v: SCNVector3, _ a: Float) -> SCNVector3 {
        SCNVector3(v.x * cosf(a) - v.z * sinf(a), 0, v.x * sinf(a) + v.z * cosf(a))
    }

    // MARK: - 渲染核心

    private func ensureDir() throws {
        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
    }

    /// 接触表：grid[row][col] 各画一个顶视小桌，合成一张大 PNG。
    private func renderSheet(_ name: String, grid: [[Scenario]]) throws {
        let cols = grid.map { $0.count }.max() ?? 1
        let rows = grid.count
        let cellW: CGFloat = 580
        let cellH: CGFloat = 360   // 含顶部 50 文字带
        let pageW = cellW * CGFloat(cols)
        let pageH = cellH * CGFloat(rows)

        // 先求解所有场景（含真实模拟），再绘制（避免在绘制 closure 内做重活）。
        var preds: [[ShotPrediction]] = []
        for row in grid {
            preds.append(row.map { ShotPredictor.predict(ShotInput(
                cueBall: $0.cue, targetBall: $0.target, pocketIndex: $0.pocketIndex,
                velocity: $0.velocity, spinX: $0.spinX, spinY: $0.spinY, surfaceY: sY)) })
        }

        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: pageW, height: pageH), format: fmt)
        let img = renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(UIColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1).cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: pageW, height: pageH))
            for (ri, row) in grid.enumerated() {
                for (ci, scn) in row.enumerated() {
                    let origin = CGPoint(x: CGFloat(ci) * cellW, y: CGFloat(ri) * cellH)
                    drawCell(cg, origin: origin, w: cellW, h: cellH, scn: scn, pred: preds[ri][ci])
                }
            }
        }
        guard let data = img.pngData() else { throw NSError(domain: "render", code: 1) }
        let path = "\(outputDir)/\(name).png"
        try data.write(to: URL(fileURLWithPath: path))
        print("SHOT-RENDER wrote \(path) (\(Int(pageW))x\(Int(pageH)))")

        // 控制台文本备份（便于无图时核对）。
        for (ri, row) in grid.enumerated() {
            for (ci, scn) in row.enumerated() {
                let p = preds[ri][ci]
                print(String(format: "  [%@] feasible=%@ objPotted=%@ cuePot=%@ cut=%.1f objMin=%.1fmm",
                             scn.title, p.feasible ? "Y" : "N", p.objectPocketed ? "Y" : "N",
                             p.cuePocketed ? "Y" : "N", p.cutAngleDeg ?? -1,
                             objMinDist(p, pocketIndex: scn.pocketIndex) * 1000))
            }
        }
    }

    private func objMinDist(_ p: ShotPrediction, pocketIndex: Int) -> Float {
        let pocket = AngleSceneCalculator.pocketPositions(surfaceY: sY)[pocketIndex]
        var minD = Float.greatestFiniteMagnitude
        if let frames = p.recorder?.framesByBallName[ShotInput.targetBallName] {
            for f in frames {
                let dx = f.position.x - pocket.x, dz = f.position.z - pocket.z
                minD = min(minD, sqrtf(dx * dx + dz * dz))
            }
        }
        return minD
    }

    // 世界范围（含袋口落孔）。
    private let xRange: Float = 1.40
    private let zRange: Float = 0.76

    private func drawCell(_ cg: CGContext, origin: CGPoint, w: CGFloat, h: CGFloat,
                          scn: Scenario, pred: ShotPrediction) {
        let headerH: CGFloat = 50
        let plotRect = CGRect(x: origin.x + 8, y: origin.y + headerH,
                              width: w - 16, height: h - headerH - 8)

        // 世界→像素映射（X 横、Z 纵；Z 向下为正）。
        func P(_ x: Float, _ z: Float) -> CGPoint {
            let px = plotRect.minX + CGFloat((x + xRange) / (2 * xRange)) * plotRect.width
            let py = plotRect.minY + CGFloat((z + zRange) / (2 * zRange)) * plotRect.height
            return CGPoint(x: px, y: py)
        }
        func P3(_ v: SCNVector3) -> CGPoint { P(v.x, v.z) }

        // 背景（台呢绿）
        cg.setFillColor(UIColor(red: 0.10, green: 0.22, blue: 0.16, alpha: 1).cgColor)
        cg.fill(plotRect)

        let geo = TableGeometry.chineseEightBallQiuJi(surfaceY: sY)

        // 落袋孔（半透明深色圆）+ 视觉标记圈（黄）
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: sY)
        for (i, pc) in pockets.enumerated() {
            let drop = AngleSceneCalculator.pocketDropRadius(index: i)
            let c = P(pc.x, pc.z)
            let rpx = CGFloat(drop / (2 * xRange)) * plotRect.width
            let rpy = CGFloat(drop / (2 * zRange)) * plotRect.height
            cg.setFillColor(UIColor.black.withAlphaComponent(0.55).cgColor)
            cg.fillEllipse(in: CGRect(x: c.x - rpx, y: c.y - rpy, width: 2 * rpx, height: 2 * rpy))
            let mr = AngleSceneCalculator.pocketMarkerRadius(index: i)
            let mrx = CGFloat(mr / (2 * xRange)) * plotRect.width
            let mry = CGFloat(mr / (2 * zRange)) * plotRect.height
            cg.setStrokeColor(UIColor.yellow.withAlphaComponent(0.6).cgColor)
            cg.setLineWidth(1)
            cg.strokeEllipse(in: CGRect(x: c.x - mrx, y: c.y - mry, width: 2 * mrx, height: 2 * mry))
            // 选定袋高亮
            if i == scn.pocketIndex {
                cg.setStrokeColor(UIColor.cyan.withAlphaComponent(0.9).cgColor)
                cg.setLineWidth(2)
                cg.strokeEllipse(in: CGRect(x: c.x - mrx - 2, y: c.y - mry - 2,
                                            width: 2 * mrx + 4, height: 2 * mry + 4))
            }
        }

        // 线性库（白）；喉腔壁会是其中较短的段，自然画出。
        cg.setStrokeColor(UIColor.white.withAlphaComponent(0.85).cgColor)
        cg.setLineWidth(1.4)
        for seg in geo.linearCushions {
            cg.beginPath()
            cg.move(to: P3(seg.start)); cg.addLine(to: P3(seg.end))
            cg.strokePath()
        }
        // 圆弧库（jaw 弧 + 中袋圆角）——折线近似。
        cg.setStrokeColor(UIColor.white.withAlphaComponent(0.7).cgColor)
        cg.setLineWidth(1.2)
        for arc in geo.circularCushions {
            let steps = 24
            var a0 = arc.startAngle, a1 = arc.endAngle
            if a1 < a0 { a1 += 2 * .pi }
            cg.beginPath()
            for s in 0...steps {
                let a = a0 + (a1 - a0) * Float(s) / Float(steps)
                let pt = P(arc.center.x + arc.radius * cosf(a), arc.center.z + arc.radius * sinf(a))
                if s == 0 { cg.move(to: pt) } else { cg.addLine(to: pt) }
            }
            cg.strokePath()
        }

        // jaw 尖端（红点）
        let jaws = AngleSceneCalculator.pocketJaws(surfaceY: sY)
        cg.setFillColor(UIColor.red.withAlphaComponent(0.8).cgColor)
        for jw in jaws {
            for p in [jw.0, jw.1] {
                let c = P3(p)
                cg.fillEllipse(in: CGRect(x: c.x - 2, y: c.y - 2, width: 4, height: 4))
            }
        }

        // 进球线（目标球→瞄准点，橙虚线）
        cg.setStrokeColor(UIColor(red: 1, green: 0.6, blue: 0.1, alpha: 0.5).cgColor)
        cg.setLineWidth(1)
        cg.setLineDash(phase: 0, lengths: [4, 3])
        cg.beginPath(); cg.move(to: P3(scn.target)); cg.addLine(to: P3(pred.pocketAimPoint)); cg.strokePath()
        cg.setLineDash(phase: 0, lengths: [])

        // 母球轨迹（白实线）
        strokePath(cg, pred.cuePath.map(P3), color: UIColor.white, width: 2.2)
        // 目标球轨迹（橙实线）
        strokePath(cg, pred.objectPath.map(P3), color: UIColor(red: 0.98, green: 0.62, blue: 0.12, alpha: 1), width: 2.4)

        // 幽灵球（黄圈）
        let gpx = CGFloat(R / (2 * xRange)) * plotRect.width
        let gpy = CGFloat(R / (2 * zRange)) * plotRect.height
        let g = P3(pred.ghost)
        cg.setStrokeColor(UIColor.yellow.withAlphaComponent(0.8).cgColor)
        cg.setLineWidth(1)
        cg.strokeEllipse(in: CGRect(x: g.x - gpx, y: g.y - gpy, width: 2 * gpx, height: 2 * gpy))

        // 母球（白实心）、目标球（橙实心）
        func ball(_ v: SCNVector3, _ color: UIColor) {
            let c = P3(v)
            cg.setFillColor(color.cgColor)
            cg.fillEllipse(in: CGRect(x: c.x - gpx, y: c.y - gpy, width: 2 * gpx, height: 2 * gpy))
            cg.setStrokeColor(UIColor.black.withAlphaComponent(0.6).cgColor)
            cg.setLineWidth(0.8)
            cg.strokeEllipse(in: CGRect(x: c.x - gpx, y: c.y - gpy, width: 2 * gpx, height: 2 * gpy))
        }
        ball(scn.cue, .white)
        ball(scn.target, UIColor(red: 0.95, green: 0.55, blue: 0.05, alpha: 1))

        // 边框
        cg.setStrokeColor(UIColor.white.withAlphaComponent(0.2).cgColor)
        cg.setLineWidth(1)
        cg.stroke(plotRect)

        // 顶部文字
        let result: String
        let resultColor: UIColor
        if !pred.feasible { result = "不可行"; resultColor = .systemGray }
        else if pred.cuePocketed { result = "母球进袋✗"; resultColor = .systemRed }
        else if pred.objectPocketed { result = "进袋✓"; resultColor = .systemGreen }
        else { result = "未进袋✗"; resultColor = .systemOrange }
        let line1 = scn.title
        let line2 = String(format: "%@  cut=%.0f°  objMin=%.0fmm  cuePath=%d objPath=%d",
                           result, pred.cutAngleDeg ?? -1,
                           objMinDist(pred, pocketIndex: scn.pocketIndex) * 1000,
                           pred.cuePath.count, pred.objectPath.count)
        drawText(line1, at: CGPoint(x: origin.x + 10, y: origin.y + 6), size: 17, color: .white, bold: true)
        drawText(line2, at: CGPoint(x: origin.x + 10, y: origin.y + 28), size: 14, color: resultColor)
    }

    private func strokePath(_ cg: CGContext, _ pts: [CGPoint], color: UIColor, width: CGFloat) {
        guard pts.count >= 2 else { return }
        cg.setStrokeColor(color.cgColor)
        cg.setLineWidth(width)
        cg.setLineJoin(.round)
        cg.beginPath()
        cg.move(to: pts[0])
        for p in pts.dropFirst() { cg.addLine(to: p) }
        cg.strokePath()
    }

    private func drawText(_ s: String, at p: CGPoint, size: CGFloat, color: UIColor, bold: Bool = false) {
        let attr: [NSAttributedString.Key: Any] = [
            .font: bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size),
            .foregroundColor: color
        ]
        (s as NSString).draw(at: p, withAttributes: attr)
    }
}
