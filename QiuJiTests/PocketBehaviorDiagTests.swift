//
//  PocketBehaviorDiagTests.swift
//  QiuJiTests
//
//  袋口行为诊断（观察用，配合「分离角与走位」「走位编排台」求解器讨论）。
//
//  目的：用截图直观呈现真实袋口现象,供肉眼分析当前求解器/引擎的表现
//  （**本轮不改求解器**，分支① 强制干净进袋仍在；这是改动前的基线观察）：
//    A. 全角度梯度（走 ShotPredictor.predict = 页面真实行为）：切角 5°→80° 下，
//       目标球进球线 + 母球走位 + 进袋与否 + 分离角。
//    B. 贴库容错梯度（直接发射目标球探袋口）：目标球越贴库，进袋容错窗（瞄准偏移
//       可进区间）越窄；呈现「空心进 / 撞jaw进 / 弹出 / 停半路」四态。
//    C. 力度→rattle（直接发射）：偏向 jaw 的球，力度越大越容易撞 jaw 弹出。
//    D. 目标球旋转撞 jaw（现象5，直接发射 + 竖轴英式）：观察"合理旋转使其撞 jaw 后
//       反弹方向更偏向袋心(导球进袋)"是否成立。
//
//  注：B/C/D 直接发射目标球（无母球），是为了**纯粹探测袋口几何/物理的接受行为**，
//  剥离母球-目标球碰撞这一变量（那属于 A 组与 throw 物理）。
//
//  产出 PNG：build/pocket_diag/*.png
//
//  运行：
//    xcodebuild test -scheme QiuJi \
//      -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
//      -only-testing:QiuJiTests/PocketBehaviorDiagTests
//

import XCTest
import UIKit
import SceneKit
@testable import QiuJi

final class PocketBehaviorDiagTests: XCTestCase {

    /// E. 进袋入洞段数值探针（#4 v2）：样例序列第 1 杆，打印被进袋球的末尾轨迹帧
    /// （时间/位置/速度/状态）与求得的入洞路标，定位「入洞动画不动」问题。
    @MainActor
    func test_diag_pocketEntryLegs() throws {
        let url = URL(fileURLWithPath:
            "/Users/song/projects/13.billiard_trainer/build/position_play_sequences/sample-两杆.json")
        try XCTSkipIf(!FileManager.default.fileExists(atPath: url.path), "无样例序列 JSON，跳过")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let seq = try decoder.decode(PositionPlaySequence.self, from: Data(contentsOf: url))
        let step = seq.steps[0]
        guard let pred = PositionPlayShotSolver.solve(before: step.before, shot: step.shot, surfaceY: sY),
              let recorder = pred.recorder else { return XCTFail("求解失败") }
        print("ENTRY-DIAG potted=\(pred.pocketedBalls) duration=\(pred.duration)")
        for name in pred.pocketedBalls {
            let frames = (recorder.framesByBallName[name] ?? []).sorted { $0.time < $1.time }
            guard let potIdx = frames.firstIndex(where: { $0.state == .pocketed }), potIdx > 0 else {
                print("ENTRY-DIAG \(name) 无进袋前帧"); continue
            }
            for f in frames[max(0, potIdx - 8)...min(frames.count - 1, potIdx + 1)] {
                print(String(format: "ENTRY-DIAG %@ t=%.3f pos=(%.4f, %.4f) v=(%.3f, %.3f)|%.3f| state=%@",
                             name, f.time, f.position.x, f.position.z,
                             f.velocity.x, f.velocity.z, f.velocity.length(), "\(f.state)"))
            }
            let prev = frames[potIdx - 1]
            let pocket = TrajectoryPlayback.nearestPocket(to: prev.position, surfaceY: sY)
            let legs = TrajectoryPlayback.solvePocketEntry(
                capture: prev.position, velocity: prev.velocity,
                pocketCenter: pocket.center, pocketRadius: pocket.radius, speedScale: 1.3
            )
            print(String(format: "ENTRY-DIAG pocketCenter=(%.4f, %.4f) r=%.4f captureDist=%.4f",
                         pocket.center.x, pocket.center.z, pocket.radius,
                         AngleSceneCalculator.horizontalDistance(prev.position, pocket.center)))
            for (i, leg) in legs.enumerated() {
                print(String(format: "ENTRY-DIAG leg%d to=(%.4f, %.4f) dur=%.3f eased=%@",
                             i, leg.to.x, leg.to.z, leg.duration, "\(leg.eased)"))
            }
        }
    }

    private let baseDir = "/Users/song/projects/13.billiard_trainer/build/pocket_diag"
    private let sY = BTTablePhysics.surfaceY
    private var R: Float { AngleSceneCalculator.ballRadius }

    private let xRange: Float = 1.40
    private let zRange: Float = 0.76

    private enum Outcome {
        case cleanPot, jawPot, rattle, short
        var color: UIColor {
            switch self {
            case .cleanPot: return UIColor(red: 0.30, green: 0.85, blue: 0.40, alpha: 1)
            case .jawPot:   return UIColor(red: 0.30, green: 0.80, blue: 0.95, alpha: 1)
            case .rattle:   return UIColor(red: 0.95, green: 0.35, blue: 0.30, alpha: 1)
            case .short:    return UIColor(white: 0.55, alpha: 1)
            }
        }
        var label: String {
            switch self {
            case .cleanPot: return "空心进"
            case .jawPot:   return "撞jaw进"
            case .rattle:   return "弹出"
            case .short:    return "停半路"
            }
        }
    }

    override func setUpWithError() throws {
        try FileManager.default.createDirectory(atPath: baseDir, withIntermediateDirectories: true)
    }

    // MARK: - A. 全角度梯度（ShotPredictor.predict = 页面真实行为）

    func test_A_angleGradient() throws {
        let target = SCNVector3(0.0, sY + R, 0.0)
        let pocketIndex = 1  // 右上角袋
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: sY)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: aim, ballRadius: R)
        let pdx = aim.x - target.x, pdz = aim.z - target.z
        let pl = max(hypotf(pdx, pdz), 1e-5)
        let pdir = SCNVector3(pdx / pl, 0, pdz / pl)

        var panels: [UIImage] = []
        print("\n[A·全角度梯度] target=center 袋=右上角  力度=3.3 无塞")
        for cutDeg in stride(from: Float(5), through: 80, by: 7.5) {
            let th = cutDeg * .pi / 180
            let sd = SCNVector3(pdir.x * cosf(th) - pdir.z * sinf(th), 0, pdir.x * sinf(th) + pdir.z * cosf(th))
            let cue = SCNVector3(ghost.x - sd.x * 0.5, sY + R, ghost.z - sd.z * 0.5)
            let halfL = AngleSceneCalculator.innerLength / 2
            let halfW = AngleSceneCalculator.innerWidth / 2
            guard abs(cue.x) < halfL - R, abs(cue.z) < halfW - R else { continue }

            let pred = ShotPredictor.predict(ShotInput(
                cueBall: cue, targetBall: target, pocketIndex: pocketIndex,
                velocity: 3.3, spinX: 0, spinY: 0, surfaceY: sY))
            let sep = pred.separationAngleDeg.map { String(format: "%.0f°", $0) } ?? "—"
            let head = String(format: "切角 %.0f°  %@", cutDeg, pred.objectPocketed ? "进袋✓" : "未进✗")
            let sub = String(format: "α=%.0f°  分离角=%@%@", pred.cutAngleDeg ?? 0, sep, pred.feasible ? "" : "  不可行")
            print(String(format: "  切角%.0f° | 可行=%@ 进袋=%@ 分离角=%@", cutDeg,
                         pred.feasible ? "Y" : "N", pred.objectPocketed ? "Y" : "N", sep))
            panels.append(tablePanel(size: CGSize(width: 470, height: 320), header: head, subtitle: sub) { cg, xf in
                self.highlightPocket(cg, xf, pocketIndex)
                self.strokePath(cg, pred.objectPath.map(xf.P), color: UIColor(red: 0.98, green: 0.62, blue: 0.12, alpha: 0.95), width: 2.4)
                self.strokePath(cg, pred.cuePath.map(xf.P), color: .white, width: 2.4)
                self.drawBall(cg, xf, target, UIColor(red: 0.95, green: 0.55, blue: 0.05, alpha: 1))
                self.drawBall(cg, xf, cue, .white)
            })
        }
        try composeSheet(panels, cols: 3, filename: "A_angle_gradient.png",
                         title: "A · 全角度梯度（白=母球走位 橙=目标球进球线）")
        XCTAssertFalse(panels.isEmpty)
    }

    // MARK: - B. 贴库容错梯度（直接发射目标球，扫瞄准横移）

    func test_B_railToleranceGradient() throws {
        let pocketIndex = 1
        let pc = AngleSceneCalculator.pocketPositions(surfaceY: sY)[pocketIndex]
        let halfW = AngleSceneCalculator.innerWidth / 2
        let gaps: [Float] = [0.005, 0.02, 0.05, 0.10, 0.18]

        var panels: [UIImage] = []
        print("\n[B·贴库容错梯度] 直接发射目标球 v=1.8  扫瞄准横移 ±90mm")
        for gap in gaps {
            // 目标球起点：袋左侧 0.40m，距上长库 gap。
            let start = SCNVector3(pc.x - 0.40, sY + R, -halfW + R + gap)
            let toC = unit(SCNVector3(pc.x - start.x, 0, pc.z - start.z))
            let perp = SCNVector3(-toC.z, 0, toC.x)  // 垂直进球线（横移瞄点）

            var runs: [(Float, Outcome, [SCNVector3])] = []
            var potOffsets: [Float] = []
            for t in stride(from: Float(-0.09), through: 0.09, by: 0.0075) {
                let aimPoint = SCNVector3(pc.x + perp.x * t, sY, pc.z + perp.z * t)
                let r = launchObject(start: start, aimPoint: aimPoint, speed: 1.8, pocketIndex: pocketIndex)
                let oc = classify(potted: r.potted, objCush: r.objCush, minDist: r.minDist, pocketIndex: pocketIndex)
                runs.append((t, oc, r.path))
                if oc == .cleanPot || oc == .jawPot { potOffsets.append(t) }
            }
            let window = potOffsets.isEmpty ? 0 : (potOffsets.max()! - potOffsets.min()!)
            print(String(format: "  间隙%.0fmm | 进袋窗=%.0fmm | 可进横移[%@]", gap * 1000, window * 1000,
                         potOffsets.isEmpty ? "无" : String(format: "%.0f..%.0f", potOffsets.min()! * 1000, potOffsets.max()! * 1000)))
            let head = String(format: "目标球距库 %.0fmm   进袋窗 %.0fmm", gap * 1000, window * 1000)
            panels.append(tablePanel(size: CGSize(width: 560, height: 340), header: head,
                                     subtitle: "绿=空心进 青=撞jaw进 红=弹出 灰=停/偏") { cg, xf in
                self.highlightPocket(cg, xf, pocketIndex)
                for (_, oc, path) in runs { self.strokePath(cg, path.map(xf.P), color: oc.color.withAlphaComponent(0.75), width: 1.5) }
                self.drawBall(cg, xf, start, UIColor(red: 0.95, green: 0.55, blue: 0.05, alpha: 1))
            })
        }
        try composeSheet(panels, cols: 2, filename: "B_rail_tolerance.png",
                         title: "B · 贴库容错梯度（目标球越贴库，进袋窗越窄）")
        XCTAssertFalse(panels.isEmpty)
    }

    // MARK: - C. 力度 → rattle（直接发射，偏 jaw 瞄准）

    func test_C_powerRattle() throws {
        let pocketIndex = 1
        let pc = AngleSceneCalculator.pocketPositions(surfaceY: sY)[pocketIndex]
        let halfW = AngleSceneCalculator.innerWidth / 2
        let start = SCNVector3(pc.x - 0.40, sY + R, -halfW + R + 0.05)
        let toC = unit(SCNVector3(pc.x - start.x, 0, pc.z - start.z))
        let perp = SCNVector3(-toC.z, 0, toC.x)
        // 偏向 jaw 的瞄点（+55mm 横移，超出 41mm 捕获半径 ⇒ 必擦 jaw）。
        let off: Float = 0.055
        let aimPoint = SCNVector3(pc.x + perp.x * off, sY, pc.z + perp.z * off)

        var panels: [UIImage] = []
        print("\n[C·力度→rattle] 贴库50mm 瞄点偏jaw +55mm  扫力度 1→6 m/s")
        for v in stride(from: Float(1.0), through: 6.0, by: 0.5) {
            let r = launchObject(start: start, aimPoint: aimPoint, speed: v, pocketIndex: pocketIndex)
            let oc = classify(potted: r.potted, objCush: r.objCush, minDist: r.minDist, pocketIndex: pocketIndex)
            print(String(format: "  力度%.1f | %@ (吃jaw%d, 最近袋心%.0fmm)", v, oc.label, r.objCush, r.minDist * 1000))
            let head = String(format: "力度 %.1f m/s  → %@", v, oc.label)
            panels.append(tablePanel(size: CGSize(width: 470, height: 320), header: head,
                                     subtitle: String(format: "撞jaw次数 %d   最近袋心 %.0fmm", r.objCush, r.minDist * 1000)) { cg, xf in
                self.highlightPocket(cg, xf, pocketIndex)
                self.strokePath(cg, r.path.map(xf.P), color: oc.color, width: 2.2)
                self.drawBall(cg, xf, start, UIColor(red: 0.95, green: 0.55, blue: 0.05, alpha: 1))
            })
        }
        try composeSheet(panels, cols: 3, filename: "C_power_rattle.png",
                         title: "C · 力度→rattle（瞄点固定偏jaw +55mm，扫力度）")
        XCTAssertFalse(panels.isEmpty)
    }

    // MARK: - D. 目标球旋转撞 jaw（现象5）

    func test_D_objectSpinJawRebound() throws {
        let pocketIndex = 1
        let pc = AngleSceneCalculator.pocketPositions(surfaceY: sY)[pocketIndex]
        let halfW = AngleSceneCalculator.innerWidth / 2
        let start = SCNVector3(pc.x - 0.40, sY + R, -halfW + R + 0.05)
        let toC = unit(SCNVector3(pc.x - start.x, 0, pc.z - start.z))
        let perp = SCNVector3(-toC.z, 0, toC.x)

        // 先用 0 旋转扫横移，找一个"刚好擦 jaw 弹出/将进未进"的临界瞄点。
        var borderOff: Float = 0.055
        for t in stride(from: Float(0.045), through: 0.075, by: 0.003) {
            let aimPoint = SCNVector3(pc.x + perp.x * t, sY, pc.z + perp.z * t)
            let r = launchObject(start: start, aimPoint: aimPoint, speed: 1.6, pocketIndex: pocketIndex)
            let oc = classify(potted: r.potted, objCush: r.objCush, minDist: r.minDist, pocketIndex: pocketIndex)
            if oc == .rattle || oc == .short { borderOff = t; break }   // 第一个不进的横移 = 临界
        }
        let aimPoint = SCNVector3(pc.x + perp.x * borderOff, sY, pc.z + perp.z * borderOff)
        print(String(format: "\n[D·目标球旋转撞jaw] 临界瞄点=+%.0fmm v=1.6  扫竖轴英式 wUp", borderOff * 1000))

        var panels: [UIImage] = []
        for wUp in stride(from: Float(-120), through: 120, by: 60) {
            let r = launchObject(start: start, aimPoint: aimPoint, speed: 1.6, wUp: wUp, pocketIndex: pocketIndex)
            let oc = classify(potted: r.potted, objCush: r.objCush, minDist: r.minDist, pocketIndex: pocketIndex)
            print(String(format: "  wUp=%+.0f | %@ (吃jaw%d, 最近袋心%.0fmm)", wUp, oc.label, r.objCush, r.minDist * 1000))
            let head = String(format: "竖轴英式 wUp=%+.0f → %@", wUp, oc.label)
            panels.append(tablePanel(size: CGSize(width: 470, height: 320), header: head,
                                     subtitle: String(format: "瞄点+%.0fmm偏jaw  吃jaw%d  最近袋心%.0fmm", borderOff * 1000, r.objCush, r.minDist * 1000)) { cg, xf in
                self.highlightPocket(cg, xf, pocketIndex)
                self.strokePath(cg, r.path.map(xf.P), color: oc.color, width: 2.4)
                self.drawBall(cg, xf, start, UIColor(red: 0.95, green: 0.55, blue: 0.05, alpha: 1))
            })
        }
        try composeSheet(panels, cols: 3, filename: "D_object_spin_jaw.png",
                         title: "D · 目标球竖轴英式撞jaw（绿=进 红=弹出 灰=偏离）")
        XCTAssertFalse(panels.isEmpty)
    }

    // MARK: - E. 求解器 vs 暴力扫瞄准（判决：漏解 还是 物理不可进）

    /// 对每个摆位：①求解器 predict 是否进；②暴力精扫母球击球方向(±12°/0.25°全保真)是否
    /// 存在「干净直接进」的方向。三态判决：求解器进 / 求解器漏解(物理可进但求解器没找到) /
    /// 物理不可进。直接回答"大角度/贴库未进是不是求解器找不到解"。
    func test_E_solverVsBruteForce() throws {
        try angleAxisSolverVsBrute()
        try railAxisSolverVsBrute()
    }

    private func angleAxisSolverVsBrute() throws {
        let target = SCNVector3(0.0, sY + R, 0.0)
        let pocketIndex = 1
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: sY)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: aim, ballRadius: R)
        let pdir = unit(SCNVector3(aim.x - target.x, 0, aim.z - target.z))
        let halfL = AngleSceneCalculator.innerLength / 2, halfW = AngleSceneCalculator.innerWidth / 2

        var panels: [UIImage] = []
        print("\n[E·角度轴] 求解器 vs 暴力扫(±12°/0.25°)  target=center 袋=右上 力度=3.3")
        for cutDeg in stride(from: Float(5), through: 80, by: 7.5) {
            let th = cutDeg * .pi / 180
            let sd = SCNVector3(pdir.x * cosf(th) - pdir.z * sinf(th), 0, pdir.x * sinf(th) + pdir.z * cosf(th))
            let cue = SCNVector3(ghost.x - sd.x * 0.5, sY + R, ghost.z - sd.z * 0.5)
            guard abs(cue.x) < halfL - R, abs(cue.z) < halfW - R else { continue }

            let pred = ShotPredictor.predict(ShotInput(cueBall: cue, targetBall: target, pocketIndex: pocketIndex, velocity: 3.3, spinX: 0, spinY: 0, surfaceY: sY))
            let bf = bruteFindPot(cue: cue, target: target, pocketIndex: pocketIndex, velocity: 3.3)
            let verdict = verdictText(solverPot: pred.objectPocketed, bf: bf)
            print(String(format: "  切角%.0f° | 求解器=%@ | 暴力任意进=%@ 干净进=%@%@ | %@", cutDeg,
                         pred.objectPocketed ? "进" : "未进",
                         bf.foundAny ? "是" : "否", bf.foundClean ? "是" : "否",
                         bf.foundAny ? String(format: "(@%.2f° 任意窗%.2f°)", bf.bestOffsetDeg, bf.anyWindowDeg) : "",
                         verdict.tag))
            let head = String(format: "切角 %.0f°  %@", cutDeg, verdict.tag)
            panels.append(tablePanel(size: CGSize(width: 470, height: 320), header: head, subtitle: verdict.sub) { cg, xf in
                self.highlightPocket(cg, xf, pocketIndex)
                if !pred.objectPocketed, bf.foundAny { self.strokePath(cg, bf.bestPath.map(xf.P), color: UIColor(red: 0.30, green: 0.95, blue: 0.45, alpha: 0.95), width: 2.6) }
                self.strokePath(cg, pred.objectPath.map(xf.P), color: UIColor(red: 0.98, green: 0.62, blue: 0.12, alpha: 0.95), width: 2.2)
                self.strokePath(cg, pred.cuePath.map(xf.P), color: UIColor(white: 1, alpha: 0.85), width: 1.8)
                self.drawBall(cg, xf, target, UIColor(red: 0.95, green: 0.55, blue: 0.05, alpha: 1))
                self.drawBall(cg, xf, cue, .white)
            })
        }
        try composeSheet(panels, cols: 3, filename: "E_angle_solver_vs_brute.png",
                         title: "E1 · 角度轴：橙=求解器 绿=暴力扫到的进袋解(求解器漏的)")
        XCTAssertFalse(panels.isEmpty)
    }

    private func railAxisSolverVsBrute() throws {
        let pocketIndex = 1
        let pc = AngleSceneCalculator.pocketPositions(surfaceY: sY)[pocketIndex]
        let halfW = AngleSceneCalculator.innerWidth / 2
        let gaps: [Float] = [0.005, 0.02, 0.05, 0.10, 0.18, 0.30]

        var panels: [UIImage] = []
        print("\n[E·贴库轴] 求解器 vs 暴力扫  袋=右上 力度=3.0  目标球距袋0.40m 距库gap")
        for gap in gaps {
            let target = SCNVector3(pc.x - 0.40, sY + R, -halfW + R + gap)
            let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: sY)
            let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: aim, ballRadius: R)
            let pdir = unit(SCNVector3(aim.x - target.x, 0, aim.z - target.z))
            guard let cue = placeCue(ghost: ghost, pdir: pdir, cutDeg: 22, dist: 0.45) else { continue }

            let pred = ShotPredictor.predict(ShotInput(cueBall: cue, targetBall: target, pocketIndex: pocketIndex, velocity: 3.0, spinX: 0, spinY: 0, surfaceY: sY))
            let bf = bruteFindPot(cue: cue, target: target, pocketIndex: pocketIndex, velocity: 3.0)
            let verdict = verdictText(solverPot: pred.objectPocketed, bf: bf)
            print(String(format: "  距库%.0fmm | 求解器=%@ | 暴力任意进=%@ 干净进=%@%@ | %@", gap * 1000,
                         pred.objectPocketed ? "进" : "未进",
                         bf.foundAny ? "是" : "否", bf.foundClean ? "是" : "否",
                         bf.foundAny ? String(format: "(@%.2f° 任意窗%.2f°)", bf.bestOffsetDeg, bf.anyWindowDeg) : "",
                         verdict.tag))
            let head = String(format: "距库 %.0fmm  %@", gap * 1000, verdict.tag)
            panels.append(tablePanel(size: CGSize(width: 470, height: 320), header: head, subtitle: verdict.sub) { cg, xf in
                self.highlightPocket(cg, xf, pocketIndex)
                if !pred.objectPocketed, bf.foundAny { self.strokePath(cg, bf.bestPath.map(xf.P), color: UIColor(red: 0.30, green: 0.95, blue: 0.45, alpha: 0.95), width: 2.6) }
                self.strokePath(cg, pred.objectPath.map(xf.P), color: UIColor(red: 0.98, green: 0.62, blue: 0.12, alpha: 0.95), width: 2.2)
                self.strokePath(cg, pred.cuePath.map(xf.P), color: UIColor(white: 1, alpha: 0.85), width: 1.8)
                self.drawBall(cg, xf, target, UIColor(red: 0.95, green: 0.55, blue: 0.05, alpha: 1))
                self.drawBall(cg, xf, cue, .white)
            })
        }
        try composeSheet(panels, cols: 3, filename: "E_rail_solver_vs_brute.png",
                         title: "E2 · 贴库轴：橙=求解器 绿=暴力扫到的进袋解(求解器漏的)")
        XCTAssertFalse(panels.isEmpty)
    }

    // MARK: - F. 近/远 jaw 验证（直接发射目标球做浅角approach + 横扫瞄点）

    /// 目标球以**浅角**接近角袋(approach 偏向一侧 → 有明确近/远 jaw)，横扫瞄点观察引擎里：
    /// 擦**远 jaw** 是否被"兜"进(合法、容错友好)、擦**近 jaw** 是否被磕弹出(应弹出)，
    /// 以及是否出现"擦近 jaw 还侥幸进"的不真实解(若有 → 求解器接受闸门需按近/远收紧)。
    /// 蓝=空心进 绿=擦远jaw进 红=擦近jaw进(⚠️) 灰=弹出/未进。
    func test_F_nearFarJaw() throws {
        let pocketIndex = 1
        let pc = AngleSceneCalculator.pocketPositions(surfaceY: sY)[pocketIndex]
        let halfW = AngleSceneCalculator.innerWidth / 2

        var panels: [UIImage] = []
        print("\n[F·近/远jaw验证] 目标球浅角approach右上角袋 v=1.6 横扫瞄点 ±90mm")
        for gap in [Float(0.04), 0.09, 0.16] {
            // 浅角：目标球在角袋左侧 0.55m、贴上长库 gap → approach 沿长库很浅。
            let start = SCNVector3(pc.x - 0.55, sY + R, -halfW + R + gap)
            let toC = unit(SCNVector3(pc.x - start.x, 0, pc.z - start.z))
            let perp = SCNVector3(-toC.z, 0, toC.x)

            var cClean = 0, cFar = 0, cNear = 0, cRattle = 0
            var runs: [(Outcome, String, SCNVector3?, [SCNVector3])] = []
            for t in stride(from: Float(-0.09), through: 0.09, by: 0.006) {
                let aimPoint = SCNVector3(pc.x + perp.x * t, sY, pc.z + perp.z * t)
                let pr = launchProbe(start: start, aimPoint: aimPoint, speed: 1.6, pocketIndex: pocketIndex)
                var oc: Outcome = .short
                var kind = "—"
                if pr.potted {
                    if let c = pr.contact {
                        kind = classifyJaw(approachFrom: start, pocketCenter: pc, contact: c)
                        if kind == "近jaw" { oc = .rattle; cNear += 1 }      // 红：擦近jaw却进(不真实)
                        else if kind == "远jaw" { oc = .jawPot; cFar += 1 }  // 绿：擦远jaw进(合法)
                        else { oc = .cleanPot; cClean += 1 }                  // 正对→记空心
                    } else { oc = .cleanPot; cClean += 1 }
                } else if pr.minDist <= AngleSceneCalculator.pocketDropRadius(index: pocketIndex) + R {
                    oc = .rattle; cRattle += 1
                }
                runs.append((oc, kind, pr.contact, pr.path))
            }
            let leanDeg = approachLeanDeg(start: start, pocketCenter: pc)
            print(String(format: "  距库%.0fmm(approach偏%.0f°) | 空心%d 远jaw进%d 近jaw进%d 弹出%d",
                         gap * 1000, leanDeg, cClean, cFar, cNear, cRattle))
            let head = String(format: "距库%.0fmm  approach偏%.0f°", gap * 1000, leanDeg)
            let sub = String(format: "空心%d 远jaw进%d 近jaw进%d(⚠️) 弹出%d", cClean, cFar, cNear, cRattle)
            panels.append(tablePanel(size: CGSize(width: 560, height: 360), header: head, subtitle: sub) { cg, xf in
                self.highlightPocket(cg, xf, pocketIndex)
                for (oc, kind, _, path) in runs {
                    let color: UIColor = kind == "近jaw" ? UIColor(red: 0.95, green: 0.30, blue: 0.25, alpha: 0.85)
                        : (oc == .jawPot ? UIColor(red: 0.35, green: 0.9, blue: 0.45, alpha: 0.8)
                        : (oc == .cleanPot ? UIColor(red: 0.35, green: 0.7, blue: 1.0, alpha: 0.8)
                        : UIColor(white: 0.55, alpha: 0.55)))
                    self.strokePath(cg, path.map(xf.P), color: color, width: 1.6)
                }
                // 标注撞 jaw 点：近=红 远=绿
                for (_, kind, contact, _) in runs {
                    guard let c = contact, kind == "近jaw" || kind == "远jaw" else { continue }
                    let p = xf.P(c)
                    cg.setFillColor((kind == "近jaw" ? UIColor.red : UIColor.green).cgColor)
                    cg.fillEllipse(in: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6))
                }
                self.drawBall(cg, xf, start, UIColor(red: 0.95, green: 0.55, blue: 0.05, alpha: 1))
            })
        }
        try composeSheet(panels, cols: 3, filename: "F_near_far_jaw.png",
                         title: "F · 近/远jaw验证（蓝=空心 绿=擦远jaw进 红=擦近jaw进⚠️ 灰=弹出/未进）")
        XCTAssertFalse(panels.isEmpty)
    }

    // MARK: - G. 贴库功率梯度（喉腔袋模型验证，ADR-P10-05）

    /// 直接发射**贴库**目标球沿库边奔角袋，固定瞄向袋心，扫**力度**。
    /// 期望（用户描述的真实物理）：小力 → 撞远jaw 衰减后落孔（进）；大力 → 反复弹撞后壁 → 弹出。
    /// 打印每个 (距库, 力度) 的进/弹出 + 最近袋心距，量化"进袋功率窗口"。
    func test_G_railPowerSweep() throws {
        let pocketIndex = 1
        let pc = AngleSceneCalculator.pocketPositions(surfaceY: sY)[pocketIndex]
        let halfW = AngleSceneCalculator.innerWidth / 2
        print("\n[G·贴库功率梯度] 浅角approach右上角袋(管道法瞄点) 扫力度  (P=进 .=未进, 括号=最近袋心mm)")
        for gap in [Float(0.02), 0.05, 0.10] {
            let start = SCNVector3(pc.x - 0.55, sY + R, -halfW + R + gap)
            let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: start, pocketIndex: pocketIndex, surfaceY: sY)
            var line = String(format: "  距库%3.0fmm: ", gap * 1000)
            for v in stride(from: Float(0.8), through: 3.6, by: 0.4) {
                let pr = launchProbe(start: start, aimPoint: aim, speed: v, pocketIndex: pocketIndex)
                line += String(format: "v%.1f%@(%2.0f) ", v, pr.potted ? "P" : ".", min(pr.minDist * 1000, 99))
            }
            print(line)
        }
        XCTAssertTrue(true)
    }

    // MARK: - G. 穿库飞出追踪（定位引擎逃逸根因）

    /// 朝 6 个袋口扫掠发射目标球（横向偏移 × 力度），抓出「球飞出台面」的 case，
    /// 打印逃逸前最后若干事件（撞了哪片库/喉壁/落袋判定）+ 位置，定位喉腔几何缺口。
    func test_G_escapeTrace() throws {
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: sY)
        // 与 invariant test_invariant_productionPathsStayInBounds 同口径：可玩区(±half∓R)+margin
        // 或袋口嘴(袋心 0.12+margin 圆)内即在界；否则越界。抓亚 50mm 的残留越界。
        let escMargin: Float = 0.02
        func inBounds(_ p: SCNVector3) -> Bool {
            if abs(p.x) <= halfL - R + escMargin && abs(p.z) <= halfW - R + escMargin { return true }
            let mouth: Float = 0.12 + escMargin
            for pk in pockets { let dx = p.x - pk.x, dz = p.z - pk.z; if dx * dx + dz * dz <= mouth * mouth { return true } }
            return false
        }
        func escaped(_ p: SCNVector3) -> Bool { !inBounds(p) }
        // 复现 PhysicsInvariantTests.test_invariant_productionPathsStayInBounds（同种子）以抓真·飞出。
        var rng = SeededRNG(seed: 0xB0_1D5_EED)
        let trials = 150
        let pHalfL = AngleSceneCalculator.innerLength / 2 - 1.5 * R
        let pHalfW = AngleSceneCalculator.innerWidth / 2 - 1.5 * R
        func randPos() -> SCNVector3 {
            SCNVector3(rng.float(in: -pHalfL...pHalfL), sY + R, rng.float(in: -pHalfW...pHalfW))
        }
        var escapes = 0, printed = 0
        print("\n[G·穿库追踪] 复现 invariant 随机球形（求解器选向），抓真·飞出台面")
        for t in 0..<trials {
            let cue = randPos()
            var target = randPos()
            var g = 0
            while hypotf(cue.x - target.x, cue.z - target.z) < 4 * R && g < 20 { target = randPos(); g += 1 }
            let pocketIndex = Int(rng.next() % 6)
            let velocity = rng.float(in: 1.6...5.8)
            let pred = ShotPredictor.predict(ShotInput(
                cueBall: cue, targetBall: target, pocketIndex: pocketIndex,
                velocity: velocity, spinX: 0, spinY: 0, surfaceY: sY))
            guard pred.feasible else { continue }
            // 检查**折线**（cuePath/objectPath，回放外推生成）是否飞出——这正是 invariant 测的对象。
            let cueEsc = pred.cuePath.contains(where: { escaped($0) })
            let objEsc = pred.objectPath.contains(where: { escaped($0) })
            guard cueEsc || objEsc else { continue }
            let eb = cueEsc ? ShotInput.cueBallName : ShotInput.targetBallName
            let path = cueEsc ? pred.cuePath : pred.objectPath
            escapes += 1
            if printed >= 3 { continue }
            printed += 1
            _ = path
            let pc = pockets[pocketIndex]
            print(String(format: "  ── 飞出#%d [%@] trial%d 袋%d(%.3f,%.3f) v%.2f", printed, eb, t, pocketIndex, pc.x, pc.z, velocity))
            guard let rec = pred.recorder, let fr = rec.framesByBallName[eb]?.sorted(by: { $0.time < $1.time }) else { continue }
            print("     原始帧（全部）:")
            for f in fr {
                print(String(format: "       t=%.3f @(%.3f,%.3f) v(%.2f,%.2f) w(%.1f,%.1f,%.1f) 态%@",
                             f.time, f.position.x, f.position.z, f.velocity.x, f.velocity.z,
                             f.angularVelocity.x, f.angularVelocity.y, f.angularVelocity.z, "\(f.state)"))
            }
            // 细采样 stateAt，找出界时刻
            let pb = TrajectoryPlayback(recorder: rec, surfaceY: sY + R)
            print("     stateAt 出界采样:")
            var dt2: Float = 0
            var shown = 0
            while dt2 <= rec.duration + 1e-4 && shown < 8 {
                if let s = pb.stateAt(ballName: eb, time: dt2), escaped(s.position) {
                    print(String(format: "       t=%.3f @(%.3f,%.3f) v(%.2f,%.2f) 态%@",
                                 dt2, s.position.x, s.position.z, s.velocity.x, s.velocity.z, "\(s.motionState)"))
                    shown += 1
                }
                dt2 += 1.0 / 120.0
            }
        }
        print(String(format: "[G·穿库追踪] %d trial，飞出 %d", trials, escapes))
    }

    /// 重放 PhysicsMatrixTests.test_matrix_solverPottingContract 的失败格，定位残留出界球与量级。
    func test_H_matrixEscape() throws {
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: sY)
        func outDist(_ p: SCNVector3) -> Float {
            let ox = max(0, abs(p.x) - (halfL - R + 0.02))
            let oz = max(0, abs(p.z) - (halfW - R + 0.02))
            let rectOut = sqrtf(ox * ox + oz * oz)
            var pktOut = Float.greatestFiniteMagnitude
            for pk in pockets { let dx = p.x - pk.x, dz = p.z - pk.z; pktOut = min(pktOut, max(0, sqrtf(dx * dx + dz * dz) - (0.12 + 0.02))) }
            return min(rectOut, pktOut)
        }
        let targets: [SCNVector3] = [
            SCNVector3(0.0, sY + R, 0.0), SCNVector3(0.6, sY + R, 0.0), SCNVector3(-0.6, sY + R, 0.0),
            SCNVector3(0.3, sY + R, 0.3), SCNVector3(-0.3, sY + R, -0.3), SCNVector3(0.9, sY + R, 0.2),
        ]
        let cases: [(ti: Int, pk: Int, cut: Float, sign: Float, v: Float)] = [
            (3, 3, 40, -1, 2.8), (4, 0, 40, -1, 2.8),
        ]
        for c in cases {
            let target = targets[c.ti]
            let pocket = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: c.pk, surfaceY: sY)
            let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: pocket, ballRadius: R)
            let pdx = pocket.x - target.x, pdz = pocket.z - target.z
            let pl = sqrtf(pdx * pdx + pdz * pdz); let pd = SCNVector3(pdx / pl, 0, pdz / pl)
            let th = c.cut * .pi / 180 * c.sign
            let sd = SCNVector3(pd.x * cosf(th) - pd.z * sinf(th), 0, pd.x * sinf(th) + pd.z * cosf(th))
            let cue = SCNVector3(ghost.x - sd.x * 0.45, sY + R, ghost.z - sd.z * 0.45)
            let pred = ShotPredictor.predict(ShotInput(cueBall: cue, targetBall: target, pocketIndex: c.pk, velocity: v(c.v), spinX: 0, spinY: 0, surfaceY: sY))
            print(String(format: "\n[H] t%dp%dc%.0fs%@v%.1f 袋%d(%.3f,%.3f) 进袋=%@", c.ti, c.pk, c.cut, c.sign > 0 ? "+" : "-", c.v, c.pk, pockets[c.pk].x, pockets[c.pk].z, pred.objectPocketed ? "Y" : "N"))
            for (name, path) in [("cue", pred.cuePath), ("obj", pred.objectPath)] {
                var worst: Float = 0; var worstP = SCNVector3Zero
                for p in path where outDist(p) > worst { worst = outDist(p); worstP = p }
                if worst > 0 { print(String(format: "   %@ 最坏出界 %.1fmm @(%.3f,%.3f)", name, worst * 1000, worstP.x, worstP.z)) }
            }
            // 出界球的原始帧（围绕出界时刻）。
            let eb = pred.cuePath.contains(where: { outDist($0) > 0 }) ? ShotInput.cueBallName : ShotInput.targetBallName
            if let rec = pred.recorder, let fr = rec.framesByBallName[eb]?.sorted(by: { $0.time < $1.time }) {
                print("   出界球[\(eb)]原始帧:")
                for f in fr where outDist(f.position) > -0.03 {
                    print(String(format: "     t=%.3f @(%.3f,%.3f) v(%.2f,%.2f) |v|=%.2f 态%@ 出界%.1fmm",
                                 f.time, f.position.x, f.position.z, f.velocity.x, f.velocity.z,
                                 sqrtf(f.velocity.x * f.velocity.x + f.velocity.z * f.velocity.z), "\(f.state)", outDist(f.position) * 1000))
                }
            }
        }
        XCTAssertTrue(true)
    }
    private func v(_ x: Float) -> Float { x }

    // MARK: - I. 贴库球·力度梯度（复现用户反馈：小力撞库 + 反射角异常）

    /// 复现：贴库目标球瞄角袋，大力直接进、小力却撞长库再反弹，且反射角>入射角。
    /// 走 `ShotPredictor.predict`（= 页面真实行为，含求解器）扫力度，逐档打印：
    ///   · 是否进选定袋；目标球落袋前吃库数；
    ///   · 若吃库：第一次库边碰撞的入射角/反射角（相对最近库面法线，取自 recorder 速度帧）。
    func test_I_lowPowerRailHug() throws {
        let halfW = AngleSceneCalculator.innerWidth / 2
        // 贴上长库（z = -halfW 侧），瞄左上角袋(0)。沿长库朝 -x 方向滚向角袋。
        let target = SCNVector3(-0.55, sY + R, -(halfW - R - 0.002))
        let pocketIndex = 0
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: sY)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: aim, ballRadius: R)
        let pdx = aim.x - target.x, pdz = aim.z - target.z
        let pl = max(hypotf(pdx, pdz), 1e-5)
        let pdir = SCNVector3(pdx / pl, 0, pdz / pl)
        // 34° 切角母球位（取台内）。
        guard let cue = placeCue(ghost: ghost, pdir: pdir, cutDeg: 34, dist: 0.5) else {
            print("[I] 无法摆母球"); XCTAssertTrue(true); return
        }
        _ = (target, aim, ghost, pdir, cue, pocketIndex)
        print(String(format: "\n[I·贴库力度梯度] 落袋孔半径角=%.0fmm jaw尖端到袋心≈%.0fmm", AngleSceneCalculator.pocketDropRadius(index: 0) * 1000, jawTipDist(0) * 1000))
        let halfL = AngleSceneCalculator.innerLength / 2
        let powers: [Float] = [1.4, 1.8, 2.4, 3.0, 3.8, 4.8, 5.8]
        // 网格：贴长库目标，沿长库不同 x（离角袋远近）× 切角 × 符号。找「高力度进、低力度撞库」模式。
        var found = 0
        var tgts: [SCNVector3] = []
        for tx in stride(from: Float(-0.7), through: 0.1, by: 0.2) {
            for tz in stride(from: Float(-0.35), through: 0.2, by: 0.15) {
                tgts.append(SCNVector3(tx, sY + R, tz))
            }
        }
        for tgt in tgts {
            let pkAim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: tgt, pocketIndex: 0, surfaceY: sY)
            let gh = AngleSceneCalculator.ghostBallPosition(targetBall: tgt, pocket: pkAim, ballRadius: R)
            let pvx = pkAim.x - tgt.x, pvz = pkAim.z - tgt.z
            let pll = max(hypotf(pvx, pvz), 1e-5)
            let pdr = SCNVector3(pvx / pll, 0, pvz / pll)
            for cut in stride(from: Float(20), through: 60, by: 10) {
                for sign in [Float(1), -1] {
                    let th = cut * .pi / 180 * sign
                    let sd = SCNVector3(pdr.x * cosf(th) - pdr.z * sinf(th), 0, pdr.x * sinf(th) + pdr.z * cosf(th))
                    let cu = SCNVector3(gh.x - sd.x * 0.5, sY + R, gh.z - sd.z * 0.5)
                    guard abs(cu.x) < halfL - R, abs(cu.z) < halfW - R else { continue }
                    var results: [(v: Float, pot: Bool, cush: Int, b: (pos: SCNVector3, rail: String, incidenceDeg: Float, reflectionDeg: Float)?)] = []
                    for vel in powers {
                        let pred = ShotPredictor.predict(ShotInput(cueBall: cu, targetBall: tgt, pocketIndex: 0, velocity: vel, spinX: 0, spinY: 0, surfaceY: sY))
                        results.append((vel, pred.objectPocketed, pred.objectCushionCount, firstObjCushion(pred.recorder)))
                    }
                    // 模式：高力度干净进(0吃库) 且 低力度吃库（≥1）。
                    let highPot = results.contains { $0.v >= 3.8 && $0.pot && $0.cush == 0 }
                    let lowCush = results.contains { $0.v <= 2.4 && $0.cush > 0 }
                    guard highPot && lowCush else { continue }
                    found += 1
                    print(String(format: "\n  ◆ tgt(%.2f,%.2f) 切%.0f° %@ cue(%.3f,%.3f)", tgt.x, tgt.z, cut, sign > 0 ? "+" : "-", cu.x, cu.z))
                    for r in results {
                        var bs = "无吃库"
                        if let b = r.b {
                            bs = String(format: "吃库@(%.3f,%.3f)%@ 入%.0f°→反%.0f°%@", b.pos.x, b.pos.z, b.rail, b.incidenceDeg, b.reflectionDeg, b.reflectionDeg > b.incidenceDeg + 3 ? "⚠反>入" : "")
                        }
                        print(String(format: "     v%.1f 进=%@ 吃库%d %@", r.v, r.pot ? "Y" : "N", r.cush, bs))
                    }
                    if found >= 6 { print("\n[I] 已采样 6 个模式，停止。"); XCTAssertTrue(true); return }
                }
            }
        }
        if found == 0 { print("[I] 网格内未发现「高力度进/低力度撞库」模式——失败模式或在含塞/其它几何。") }
        XCTAssertTrue(true)
    }

    /// 低力瞄准漂移诊断（用户：小力时瞄准点变错、母球刮袋）。贴长库 OB 向右上角袋(1) 切 ~36°，
    /// 扫 5 档力度，打印每档：瞄准方向角(cue 首段)、碰后 OB 方向角、d_pipe 角、进袋、刮袋、碰前吃库。
    /// 用于鉴别：低力下瞄准角是 throw 补偿的小漂移（OB 仍在管子上、刮袋是力度后果）还是求解器跳偏
    /// （OB 偏离管子）。
    func test_N_lowPowerAimShift() throws {
        let pocketIndex = 1
        // 多个目标球位：贴库(退化)、离库浅切、离库深切，逐个扫力度找复现点。
        let targets: [(String, SCNVector3)] = [
            ("贴库", SCNVector3(0.45, sY + R, -(AngleSceneCalculator.innerWidth / 2 - R - 0.002))),
            ("离库浅", SCNVector3(0.60, sY + R, -0.30)),
            ("离库深", SCNVector3(0.20, sY + R, -0.10)),
            ("中近", SCNVector3(0.85, sY + R, -0.20)),
        ]
        for (tlabel, target) in targets {
            try runOnePlacement(tlabel, target, pocketIndex)
        }
        XCTAssertTrue(true)
    }

    private func runOnePlacement(_ tlabel: String, _ target: SCNVector3, _ pocketIndex: Int) throws {
        let halfW = AngleSceneCalculator.innerWidth / 2
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: sY)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: aim, ballRadius: R)
        let pdx = aim.x - target.x, pdz = aim.z - target.z
        let pl = max(hypotf(pdx, pdz), 1e-5)
        let pdir = SCNVector3(pdx / pl, 0, pdz / pl)
        let pipeDeg = atan2f(pdir.z, pdir.x) * 180 / .pi
        let halfL = AngleSceneCalculator.innerLength / 2
        // 36° 切角，取使母球在台内的符号。
        func placeCue(_ sign: Float) -> SCNVector3? {
            let th = 36 * Float.pi / 180 * sign
            let sd = SCNVector3(pdir.x * cosf(th) - pdir.z * sinf(th), 0, pdir.x * sinf(th) + pdir.z * cosf(th))
            let cu = SCNVector3(ghost.x - sd.x * 0.6, sY + R, ghost.z - sd.z * 0.6)
            return (abs(cu.x) < halfL - R && abs(cu.z) < halfW - R) ? cu : nil
        }
        guard let cue = placeCue(1) ?? placeCue(-1) else { print("[N·\(tlabel)] 母球无法摆台内"); return }
        print(String(format: "\n[N·%@] 目标(%.2f,%.2f) 袋%d d_pipe=%.1f° 母球(%.2f,%.2f)",
                     tlabel, target.x, target.z, pocketIndex, pipeDeg, cue.x, cue.z))
        let speeds: [(String, Float)] = [("轻1.6", 1.6), ("中轻2.4", 2.4), ("中3.3", 3.3), ("中重4.4", 4.4), ("大5.8", 5.8)]
        for (label, v) in speeds {
            let pred = ShotPredictor.predict(ShotInput(cueBall: cue, targetBall: target, pocketIndex: pocketIndex, velocity: v, spinX: 0, spinY: 0, surfaceY: sY))
            // 瞄准方向角：母球轨迹首段方向。
            var aimDeg = Float.nan
            if pred.cuePath.count >= 2 {
                let a = pred.cuePath[0], b = pred.cuePath[1]
                aimDeg = atan2f(b.z - a.z, b.x - a.x) * 180 / .pi
            }
            // 碰后 OB 方向角：目标球轨迹首段方向。
            var objDeg = Float.nan
            if pred.objectPath.count >= 2 {
                let a = pred.objectPath[0], b = pred.objectPath[1]
                objDeg = atan2f(b.z - a.z, b.x - a.x) * 180 / .pi
            }
            print(String(format: "  %@ 瞄=%.1f° OB碰后=%.1f°(管子%.1f° 误差%.1f°) 进=%@ 刮=%@ 碰前吃库=%d",
                         label, aimDeg, objDeg, pipeDeg, objDeg - pipeDeg,
                         pred.objectPocketed ? "Y" : "N", pred.cuePocketed ? "Y" : "N",
                         pred.cueCushionsBeforeContact))
        }
        XCTAssertTrue(true)
    }

    struct Segment { let ax: Float; let az: Float; let bx: Float; let bz: Float
        init(_ ax: Float, _ az: Float, _ bx: Float, _ bz: Float) { self.ax = ax; self.az = az; self.bx = bx; self.bz = bz } }

    /// 点到线段最近点。
    private func closestOnSeg(_ px: Float, _ pz: Float, _ sx: Float, _ sz: Float, _ tx: Float, _ tz: Float) -> (Float, Float) {
        let vx = tx - sx, vz = tz - sz
        let len2 = vx * vx + vz * vz
        if len2 < 1e-9 { return (sx, sz) }
        var t = ((px - sx) * vx + (pz - sz) * vz) / len2
        t = max(0, min(1, t))
        return (sx + vx * t, sz + vz * t)
    }

    /// 段-段最近距离（端点到对段的最小值；本用途下管道擦 jaw 不会真正穿越，足够）。
    private func segDist(_ ax: Float, _ az: Float, _ bx: Float, _ bz: Float,
                         _ cx: Float, _ cz: Float, _ dx: Float, _ dz: Float) -> Float {
        // 相交则距离 0（管道真正穿过 jaw）。
        func ccw(_ ax: Float, _ az: Float, _ bx: Float, _ bz: Float, _ cx: Float, _ cz: Float) -> Float {
            (bx - ax) * (cz - az) - (bz - az) * (cx - ax)
        }
        let d1 = ccw(ax, az, bx, bz, cx, cz), d2 = ccw(ax, az, bx, bz, dx, dz)
        let d3 = ccw(cx, cz, dx, dz, ax, az), d4 = ccw(cx, cz, dx, dz, bx, bz)
        if ((d1 > 0) != (d2 > 0)) && ((d3 > 0) != (d4 > 0)) { return 0 }
        func ptSeg(_ px: Float, _ pz: Float, _ sx: Float, _ sz: Float, _ tx: Float, _ tz: Float) -> Float {
            let vx = tx - sx, vz = tz - sz
            let len2 = vx * vx + vz * vz
            if len2 < 1e-9 { return hypotf(px - sx, pz - sz) }
            var t = ((px - sx) * vx + (pz - sz) * vz) / len2
            t = max(0, min(1, t))
            return hypotf(px - (sx + vx * t), pz - (sz + vz * t))
        }
        return min(min(ptSeg(ax, az, cx, cz, dx, dz), ptSeg(bx, bz, cx, cz, dx, dz)),
                   min(ptSeg(cx, cz, ax, az, bx, bz), ptSeg(dx, dz, ax, az, bx, bz)))
    }

    /// 目标球轨迹「空台拐弯」诊断（用户截图：橙线有明显折角）。
    /// 默认球位 cue(-0.35,0.22) target(0.55,-0.18)，扫各袋×力度，dump objectPath 每个内顶点转角，
    /// 找最大转角顶点，打印其位置、离最近袋/最近主库距离、以及该点离母球轨迹的最近距离
    /// （判别 double-kiss：母球跟上来二次碰撞）。空台（远离库/袋）出现大转角 = 异常。
    func test_P_objectPathKink() throws {
        let cue = SCNVector3(-0.35, sY + R, 0.22)
        let target = SCNVector3(0.55, sY + R, -0.18)
        let mainRails: [(Float, Float, Float, Float)] = [
            (-1.1671, -0.635, -0.035, -0.635), (0.035, -0.635, 1.1671, -0.635),
            (-1.1671, 0.635, -0.035, 0.635), (0.035, 0.635, 1.1671, 0.635),
            (-1.270, -0.5321, -1.270, 0.5321), (1.270, -0.5321, 1.270, 0.5321),
        ]
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: sY)
        let speeds: [(String, Float)] = [("轻1.6", 1.6), ("中3.3", 3.3), ("大5.8", 5.8)]
        print("\n[P·目标球轨迹拐弯] 默认 cue(-0.35,0.22) target(0.55,-0.18)")
        for pk in 0..<6 {
            for (slabel, v) in speeds {
                let pred = ShotPredictor.predict(ShotInput(cueBall: cue, targetBall: target, pocketIndex: pk, velocity: v, spinX: 0, spinY: 0, surfaceY: sY))
                guard pred.feasible else { continue }
                let path = pred.objectPath
                guard path.count >= 3 else { continue }
                // 找最大转角内顶点（先压掉重复/极短段）。
                var maxTurn: Float = 0, kinkIdx = -1
                for i in 1..<(path.count - 1) {
                    let ax = path[i].x - path[i - 1].x, az = path[i].z - path[i - 1].z
                    let bx = path[i + 1].x - path[i].x, bz = path[i + 1].z - path[i].z
                    let la = hypotf(ax, az), lb = hypotf(bx, bz)
                    if la < 0.01 || lb < 0.01 { continue }
                    let dot = max(-1, min(1, (ax * bx + az * bz) / (la * lb)))
                    let turn = acosf(dot) * 180 / .pi
                    if turn > maxTurn { maxTurn = turn; kinkIdx = i }
                }
                guard kinkIdx >= 0 else { continue }
                let k = path[kinkIdx]
                // 拐点离最近袋。
                var dPk = Float.greatestFiniteMagnitude
                for p in pockets { dPk = min(dPk, hypotf(k.x - p.x, k.z - p.z)) }
                // 拐点离最近主库。
                var dRail = Float.greatestFiniteMagnitude
                for (rax, raz, rbx, rbz) in mainRails {
                    dRail = min(dRail, segDist(k.x, k.z, k.x, k.z, rax, raz, rbx, rbz))
                }
                // 拐点离母球轨迹最近距离（double-kiss 判别）。
                var dCue = Float.greatestFiniteMagnitude
                for c in pred.cuePath { dCue = min(dCue, hypotf(k.x - c.x, k.z - c.z)) }
                let flag = (maxTurn > 5 && dPk > 0.10 && dRail > 0.05) ? " ⚠空台拐弯" : ""
                print(String(format: "  袋%d %@ 进=%@ 切%.0f° 段数%d 最大转角%.1f°@(%.2f,%.2f) 离袋%.0f 离库%.0f 离母球轨迹%.0fmm%@",
                             pk, slabel, pred.objectPocketed ? "Y" : "N", pred.cutAngleDeg ?? 0, path.count,
                             maxTurn, k.x, k.z, dPk * 1000, dRail * 1000, dCue * 1000, flag))
            }
        }

        // 截图类：20° 切角进角袋（目标球居中、母球摆在 20° 切位）。
        print("\n[P·20°切进角袋]")
        let shots: [(SCNVector3, Int)] = [
            (SCNVector3(0.0, sY + R, -0.10), 0), (SCNVector3(0.0, sY + R, -0.10), 1),
            (SCNVector3(-0.3, sY + R, -0.05), 0), (SCNVector3(0.3, sY + R, -0.05), 1),
        ]
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        for (tgt, pk) in shots {
            let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: tgt, pocketIndex: pk, surfaceY: sY)
            let gh = AngleSceneCalculator.ghostBallPosition(targetBall: tgt, pocket: aim, ballRadius: R)
            let pvx = aim.x - tgt.x, pvz = aim.z - tgt.z
            let pl = max(hypotf(pvx, pvz), 1e-5)
            let pdr = SCNVector3(pvx / pl, 0, pvz / pl)
            func placeCue(_ sign: Float) -> SCNVector3? {
                let th = 20 * Float.pi / 180 * sign
                let sd = SCNVector3(pdr.x * cosf(th) - pdr.z * sinf(th), 0, pdr.x * sinf(th) + pdr.z * cosf(th))
                let c = SCNVector3(gh.x - sd.x * 0.7, sY + R, gh.z - sd.z * 0.7)
                return (abs(c.x) < halfL - R && abs(c.z) < halfW - R) ? c : nil
            }
            guard let cue2 = placeCue(1) ?? placeCue(-1) else { continue }
            for (slabel, v) in speeds {
                let pred = ShotPredictor.predict(ShotInput(cueBall: cue2, targetBall: tgt, pocketIndex: pk, velocity: v, spinX: 0, spinY: 0, surfaceY: sY))
                guard pred.feasible, pred.objectPath.count >= 3 else { continue }
                let path = pred.objectPath
                var maxTurn: Float = 0, kinkIdx = -1
                for i in 1..<(path.count - 1) {
                    let ax = path[i].x - path[i - 1].x, az = path[i].z - path[i - 1].z
                    let bx = path[i + 1].x - path[i].x, bz = path[i + 1].z - path[i].z
                    let la = hypotf(ax, az), lb = hypotf(bx, bz)
                    if la < 0.01 || lb < 0.01 { continue }
                    let dot = max(-1, min(1, (ax * bx + az * bz) / (la * lb)))
                    let turn = acosf(dot) * 180 / .pi
                    if turn > maxTurn { maxTurn = turn; kinkIdx = i }
                }
                guard kinkIdx >= 0 else { continue }
                let k = path[kinkIdx]
                var dPk = Float.greatestFiniteMagnitude
                for p in pockets { dPk = min(dPk, hypotf(k.x - p.x, k.z - p.z)) }
                var dRail = Float.greatestFiniteMagnitude
                for (rax, raz, rbx, rbz) in mainRails { dRail = min(dRail, segDist(k.x, k.z, k.x, k.z, rax, raz, rbx, rbz)) }
                var dCue = Float.greatestFiniteMagnitude
                for c in pred.cuePath { dCue = min(dCue, hypotf(k.x - c.x, k.z - c.z)) }
                let flag = (maxTurn > 5 && dPk > 0.10 && dRail > 0.05) ? " ⚠空台拐弯" : ""
                print(String(format: "  tgt(%.2f,%.2f)袋%d %@ 进=%@ 切%.0f° 段%d 最大转%.1f°@(%.2f,%.2f) 离袋%.0f 离库%.0f 离母球%.0fmm%@",
                             tgt.x, tgt.z, pk, slabel, pred.objectPocketed ? "Y" : "N", pred.cutAngleDeg ?? 0,
                             path.count, maxTurn, k.x, k.z, dPk * 1000, dRail * 1000, dCue * 1000, flag))
            }
        }
        XCTAssertTrue(true)
    }

    /// 贴库目标球：扫母球角度（改变切角），看反解器把 OB 送上 d_pipe 的稳定性。
    /// 用户现象：同一贴库目标球，移动母球换角度时，有时直线进、有时先吃近端库/jaw。
    /// 取证：逐切角报告 OB 碰后初始方向 vs d_pipe 的误差、碰前吃库次数、是否进、橙线最大拐角。
    func test_Q_nearCushionAimSweep() throws {
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: sY)
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let v: Float = 3.3

        // 全台目标球网格（避开太靠库/太靠袋的退化位），每个目标球对每个可行袋扫母球角度。
        var targets: [SCNVector3] = []
        for xi in stride(from: -1.0 as Float, through: 1.0, by: 0.25) {
            for zi in stride(from: -0.50 as Float, through: 0.50, by: 0.20) {
                targets.append(SCNVector3(xi, sY + R, zi))
            }
        }

        // 分类统计：按「进球点 Case1(袋心干净穿喉) / Case2(偏心擦远jaw)」分桶，统计脏杆率；
        // 「脏」= 碰前吃库(objectCushionCount)>0 且拐角发生在远离袋口处（>15cm，排除袋口合法擦远jaw），
        //        或最大拐角>20°且离袋>12cm（中途折）。重点抓 Case1 却脏的（真问题）。
        var c1ok = 0, c1bad = 0, c2ok = 0, c2bad = 0
        var c1badSamples: [String] = []

        func obInitialDir(_ path: [SCNVector3]) -> SCNVector3? {
            guard let first = path.first else { return nil }
            for p in path {
                let dx = p.x - first.x, dz = p.z - first.z
                let l = hypotf(dx, dz)
                if l > 0.02 { return SCNVector3(dx / l, 0, dz / l) }
            }
            return nil
        }

        for tgt in targets {
            for pk in 0..<6 {
                let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: tgt, pocketIndex: pk, surfaceY: sY)
                let pc = pockets[pk]
                let isCase1 = hypotf(aim.x - pc.x, aim.z - pc.z) < 0.003
                let pvx = aim.x - tgt.x, pvz = aim.z - tgt.z
                let pl = max(hypotf(pvx, pvz), 1e-5)
                let dpipe = SCNVector3(pvx / pl, 0, pvz / pl)
                let gh = AngleSceneCalculator.ghostBallPosition(targetBall: tgt, pocket: aim, ballRadius: R)

                for thDeg in stride(from: -55, through: 55, by: 5) {
                    let th = Float(thDeg) * Float.pi / 180
                    let sd = SCNVector3(dpipe.x * cosf(th) - dpipe.z * sinf(th), 0,
                                        dpipe.x * sinf(th) + dpipe.z * cosf(th))
                    let cue = SCNVector3(gh.x - sd.x * 0.6, sY + R, gh.z - sd.z * 0.6)
                    guard abs(cue.x) < halfL - R, abs(cue.z) < halfW - R else { continue }
                    // 母球不能离目标球太近/重叠。
                    guard hypotf(cue.x - tgt.x, cue.z - tgt.z) > 0.12 else { continue }
                    let pred = ShotPredictor.predict(ShotInput(cueBall: cue, targetBall: tgt, pocketIndex: pk, velocity: v, spinX: 0, spinY: 0, surfaceY: sY))
                    guard pred.feasible else { continue }
                    let path = pred.objectPath
                    guard path.count >= 3 else { continue }

                    var maxTurn: Float = 0, kinkIdx = -1
                    for i in 1..<(path.count - 1) {
                        let ax = path[i].x - path[i - 1].x, az = path[i].z - path[i - 1].z
                        let bx = path[i + 1].x - path[i].x, bz = path[i + 1].z - path[i].z
                        let la = hypotf(ax, az), lb = hypotf(bx, bz)
                        if la < 0.01 || lb < 0.01 { continue }
                        let dot = max(-1, min(1, (ax * bx + az * bz) / (la * lb)))
                        let turn = acosf(dot) * 180 / .pi
                        if turn > maxTurn { maxTurn = turn; kinkIdx = i }
                    }
                    var kinkPk = Float.greatestFiniteMagnitude
                    var dCue = Float.greatestFiniteMagnitude
                    if kinkIdx >= 0 {
                        let k = path[kinkIdx]
                        for p in pockets { kinkPk = min(kinkPk, hypotf(k.x - p.x, k.z - p.z)) }
                        for c in pred.cuePath { dCue = min(dCue, hypotf(k.x - c.x, k.z - c.z)) }
                    }
                    // 中途折（远离袋口的拐角）= 真问题；袋口处擦远jaw或double-kiss排除。
                    let midKink = maxTurn > 20 && kinkPk > 0.12 && dCue > 0.06
                    let preCushionFar = pred.objectCushionCount > 0 && kinkPk > 0.15
                    let bad = midKink || preCushionFar

                    if isCase1 {
                        if bad {
                            c1bad += 1
                            if c1badSamples.count < 20, let od = obInitialDir(path) {
                                let errDeg = acosf(max(-1, min(1, od.x * dpipe.x + od.z * dpipe.z))) * 180 / .pi
                                c1badSamples.append(String(format: "tgt(%.2f,%.2f)袋%d 切%+d° 进=%@ 吃库=%d OB误差%.2f° 拐%.0f°@离袋%.0f离母球%.0f",
                                    tgt.x, tgt.z, pk, thDeg, pred.objectPocketed ? "Y" : "N",
                                    pred.objectCushionCount, errDeg, maxTurn, kinkPk * 1000, dCue * 1000))
                            }
                        } else { c1ok += 1 }
                    } else {
                        if bad { c2bad += 1 } else { c2ok += 1 }
                    }
                }
            }
        }
        print("\n[Q·全台网格 × 扫母球角度] 力度中3.3 无塞")
        print(String(format: "  Case1(袋心干净穿喉): 干净 %d / 中途折脏 %d  (脏率 %.1f%%)",
                     c1ok, c1bad, Float(c1bad) / Float(max(1, c1ok + c1bad)) * 100))
        print(String(format: "  Case2(偏心擦远jaw):  干净 %d / 中途折脏 %d  (脏率 %.1f%%)",
                     c2ok, c2bad, Float(c2bad) / Float(max(1, c2ok + c2bad)) * 100))
        print("  —— Case1 却中途折的样本（真问题，应=0 或极少）：")
        if c1badSamples.isEmpty { print("    （无）") }
        for s in c1badSamples { print("    " + s) }
        XCTAssertTrue(true)
    }

    /// 受控实验：脏杆（真擦 jaw 大拐角）的 OB 碰后方向误差 vs 干净杆，看损失精度是否是元凶。
    /// 用户假设：损失没严格要求 OB 沿管道（正则项把解拉偏 / 方向误差留得太大）。
    /// 判据：rattle = 橙线最大拐角 > 20°（真擦 jaw 弹）。分别统计两组 OB误差均值/最大。
    func test_Q2_lossStrictness() throws {
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: sY)
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let v: Float = 3.3
        var targets: [SCNVector3] = []
        for xi in stride(from: -0.8 as Float, through: 0.8, by: 0.4) {
            for zi in stride(from: -0.5 as Float, through: 0.5, by: 0.25) {
                targets.append(SCNVector3(xi, sY + R, zi))
            }
        }
        var rattleErrs: [Float] = []
        var cleanErrs: [Float] = []
        var rattleSamples: [String] = []
        func obInitialDir(_ path: [SCNVector3]) -> SCNVector3? {
            guard let first = path.first else { return nil }
            for p in path {
                let dx = p.x - first.x, dz = p.z - first.z
                let l = hypotf(dx, dz)
                if l > 0.02 { return SCNVector3(dx / l, 0, dz / l) }
            }
            return nil
        }
        for tgt in targets {
            for pk in 0..<6 {
                let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: tgt, pocketIndex: pk, surfaceY: sY)
                let pvx = aim.x - tgt.x, pvz = aim.z - tgt.z
                let pl = max(hypotf(pvx, pvz), 1e-5)
                let dpipe = SCNVector3(pvx / pl, 0, pvz / pl)
                let gh = AngleSceneCalculator.ghostBallPosition(targetBall: tgt, pocket: aim, ballRadius: R)
                for thDeg in stride(from: -50, through: 50, by: 10) {
                    let th = Float(thDeg) * Float.pi / 180
                    let sd = SCNVector3(dpipe.x * cosf(th) - dpipe.z * sinf(th), 0,
                                        dpipe.x * sinf(th) + dpipe.z * cosf(th))
                    let cue = SCNVector3(gh.x - sd.x * 0.6, sY + R, gh.z - sd.z * 0.6)
                    guard abs(cue.x) < halfL - R, abs(cue.z) < halfW - R,
                          hypotf(cue.x - tgt.x, cue.z - tgt.z) > 0.12 else { continue }
                    let pred = ShotPredictor.predict(ShotInput(cueBall: cue, targetBall: tgt, pocketIndex: pk, velocity: v, spinX: 0, spinY: 0, surfaceY: sY))
                    guard pred.feasible, pred.objectPath.count >= 3 else { continue }
                    let path = pred.objectPath
                    var maxTurn: Float = 0
                    for i in 1..<(path.count - 1) {
                        let ax = path[i].x - path[i - 1].x, az = path[i].z - path[i - 1].z
                        let bx = path[i + 1].x - path[i].x, bz = path[i + 1].z - path[i].z
                        let la = hypotf(ax, az), lb = hypotf(bx, bz)
                        if la < 0.01 || lb < 0.01 { continue }
                        let dot = max(-1, min(1, (ax * bx + az * bz) / (la * lb)))
                        maxTurn = max(maxTurn, acosf(dot) * 180 / .pi)
                    }
                    guard let od = obInitialDir(path) else { continue }
                    let errDeg = acosf(max(-1, min(1, od.x * dpipe.x + od.z * dpipe.z))) * 180 / .pi
                    if maxTurn > 20 {
                        rattleErrs.append(errDeg)
                        if rattleSamples.count < 12 {
                            rattleSamples.append(String(format: "tgt(%.1f,%.1f)袋%d 切%+d° 进=%@ OB误差%.3f° 拐%.0f°",
                                tgt.x, tgt.z, pk, thDeg, pred.objectPocketed ? "Y" : "N", errDeg, maxTurn))
                        }
                    } else {
                        cleanErrs.append(errDeg)
                    }
                }
            }
        }
        func stats(_ a: [Float]) -> String {
            guard !a.isEmpty else { return "n=0" }
            let mean = a.reduce(0, +) / Float(a.count)
            return String(format: "n=%d 均值%.3f° 最大%.3f°", a.count, mean, a.max() ?? 0)
        }
        print("\n[Q2·损失严格性] rattle(拐>20°) vs clean 的 OB碰后方向误差")
        print("  rattle 组：" + stats(rattleErrs))
        print("  clean  组：" + stats(cleanErrs))
        print("  —— rattle 样本：")
        for s in rattleSamples { print("    " + s) }
        XCTAssertTrue(true)
    }

    /// 管道吃近端 jaw 复现（用户实测：选中的管道吃到 jaw，疑近/远端判定选错）。
    /// 对角袋目标球网格，取真实 effectivePocketAimPoint，量管道到两片 jaw 的真实最小距离，
    /// 并复算生产代码的近/远端分类（切点到球心距离），找出「管道吃近端 jaw」的样本。
    func test_R_pipeHitsNearJaw() throws {
        let R = self.R
        let clearance = R + 0.003
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: sY)
        // 角袋 jaw 坐标（与 AngleSceneCalculator.pocketMouths 的 corner() 公式一致）。
        func cornerJaws(_ sx: Float, _ sz: Float) -> (Segment, Segment, (Float, Float)) {
            let longInner = (sx * 1.2414, sz * 0.6658)
            let longOuter = (sx * 1.2823, sz * 0.7067)
            let shortInner = (sx * 1.3008, sz * 0.6064)
            let shortOuter = (sx * 1.3417, sz * 0.6473)
            return (Segment(longInner.0, longInner.1, longOuter.0, longOuter.1),
                    Segment(shortInner.0, shortInner.1, shortOuter.0, shortOuter.1),
                    (longInner.0, longInner.1))  // 不用
        }
        let cornerSigns: [(Int, Float, Float)] = [(0, -1, -1), (1, 1, -1), (2, -1, 1), (3, 1, 1)]
        var hitNear = 0, grazeFarOK = 0, total = 0
        var classifyDisagree = 0
        var samples: [String] = []
        var disagreeSamples: [String] = []
        for (pk, sx, sz) in cornerSigns {
            let pc = pockets[pk]
            let (jaw0, jaw1, _) = cornerJaws(sx, sz)
            for xi in stride(from: -1.0 as Float, through: 1.0, by: 0.1) {
                for zi in stride(from: -0.5 as Float, through: 0.5, by: 0.1) {
                    let tgt = SCNVector3(xi, sY + R, zi)
                    // 跳过太靠袋/出界。
                    if hypotf(xi - pc.x, zi - pc.z) < 0.15 { continue }
                    let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: tgt, pocketIndex: pk, surfaceY: sY)
                    let dx = aim.x - tgt.x, dz = aim.z - tgt.z
                    let len = hypotf(dx, dz)
                    if len < 0.05 { continue }
                    let ux = dx / len, uz = dz / len
                    let pe = (tgt.x + ux * (len + clearance), tgt.z + uz * (len + clearance))
                    // 管道到两片 jaw 的真实最小距离。
                    let dJ0 = segDist(tgt.x, tgt.z, pe.0, pe.1, jaw0.ax, jaw0.az, jaw0.bx, jaw0.bz)
                    let dJ1 = segDist(tgt.x, tgt.z, pe.0, pe.1, jaw1.ax, jaw1.az, jaw1.bx, jaw1.bz)
                    // 复算生产近/远端分类：切点(=jaw 上离袋心最近点)到球心距离，近者=近端。
                    let c0 = closestOnSeg(pc.x, pc.z, jaw0.ax, jaw0.az, jaw0.bx, jaw0.bz)
                    let c1 = closestOnSeg(pc.x, pc.z, jaw1.ax, jaw1.az, jaw1.bx, jaw1.bz)
                    let d0 = hypotf(c0.0 - tgt.x, c0.1 - tgt.z)
                    let d1 = hypotf(c1.0 - tgt.x, c1.1 - tgt.z)
                    let nearIs0 = d0 <= d1
                    let dNear = nearIs0 ? dJ0 : dJ1
                    let dFar = nearIs0 ? dJ1 : dJ0
                    // 独立真值（用户指定判据）：jaw 切点到「袋心-球心连线」的垂距，谁小谁近端。
                    let lpx = pc.x - tgt.x, lpz = pc.z - tgt.z
                    let llen = max(hypotf(lpx, lpz), 1e-6)
                    func perpToLine(_ qx: Float, _ qz: Float) -> Float {
                        abs((qx - tgt.x) * lpz - (qz - tgt.z) * lpx) / llen
                    }
                    let p0 = perpToLine(c0.0, c0.1), p1 = perpToLine(c1.0, c1.1)
                    let lineNearIs0 = p0 <= p1
                    if lineNearIs0 != nearIs0 { classifyDisagree += 1
                        if disagreeSamples.count < 25 {
                            disagreeSamples.append(String(format: "袋%d tgt(%.1f,%.1f) 生产近=%@(d0=%.0f d1=%.0f) | 垂距近=%@(p0=%.1f p1=%.1f)",
                                pk, xi, zi, nearIs0 ? "jaw0" : "jaw1", d0 * 1000, d1 * 1000,
                                lineNearIs0 ? "jaw0" : "jaw1", p0 * 1000, p1 * 1000))
                        }
                    }
                    total += 1
                    // 管道吃近端 jaw（中心线段到近端 jaw < clearance）。
                    if dNear < clearance - 1e-4 {
                        hitNear += 1
                        if samples.count < 25 {
                            samples.append(String(format: "袋%d tgt(%.1f,%.1f) 近端%@ d0=%.0f d1=%.0f | 管道到近jaw=%.1fmm 远jaw=%.1fmm (clearance=%.1f)",
                                pk, xi, zi, nearIs0 ? "=长库jaw" : "=短库jaw", d0 * 1000, d1 * 1000, dNear * 1000, dFar * 1000, clearance * 1000))
                        }
                    } else if dFar < clearance {
                        grazeFarOK += 1
                    }
                }
            }
        }
        print("\n[R·管道吃近端jaw复现] 角袋网格")
        print(String(format: "  总样本 %d | 管道吃近端jaw %d | 仅擦远端jaw(合法) %d", total, hitNear, grazeFarOK))
        print("  —— 吃近端 jaw 样本：")
        if samples.isEmpty { print("    （无）") }
        for s in samples { print("    " + s) }
        print(String(format: "  近/远端分类：生产(切点-球心点距) vs 真值(切点-连线垂距) 不一致 %d / %d", classifyDisagree, total))
        print("  —— 分类不一致样本（生产可能选反）：")
        if disagreeSamples.isEmpty { print("    （无）") }
        for s in disagreeSamples { print("    " + s) }
        XCTAssertTrue(true)
    }

    /// 远/近端 jaw 判定缺陷复现（用户：明显吃了近端 jaw）。
    /// 判据（第一性原理）：合法进球管道中心线必须从两 jaw 内尖之间穿过袋喉；
    /// 若 effectivePocketAimPoint 给出的中心线让两内尖落在「同侧」，说明它瞄到了近端 jaw 面，
    /// 球会被往外弹（情形3 不可行），却被当成可行进球点 —— 这是缺陷。
    /// 对 4 角袋扫目标球位网格，打印所有被判到近端 jaw 的球位（含偏离袋心的进球点）。
    func test_O_nearJawMisclassification() throws {
        // 角袋两 jaw 内尖（与 pocketMouths.corner 一致）：长边侧、短边侧。
        func jawInnerTips(_ idx: Int) -> (long: SCNVector3, short: SCNVector3) {
            let s: [(Float, Float)] = [(-1, -1), (1, -1), (-1, 1), (1, 1)]
            let (sx, sz) = s[idx]
            return (SCNVector3(sx * 1.2414, sY, sz * 0.6658),
                    SCNVector3(sx * 1.3008, sY, sz * 0.6064))
        }
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        // 6 条主库（与 buildPipeGeometry 的 ordinaryObstacles 一致）。
        let mainRails: [(Float, Float, Float, Float)] = [
            (-1.1671, -0.635, -0.035, -0.635), (0.035, -0.635, 1.1671, -0.635),
            (-1.1671, 0.635, -0.035, 0.635), (0.035, 0.635, 1.1671, 0.635),
            (-1.270, -0.5321, -1.270, 0.5321), (1.270, -0.5321, 1.270, 0.5321),
        ]
        for pocketIndex in 0..<4 {
            let tips = jawInnerTips(pocketIndex)
            let pocket = AngleSceneCalculator.pocketPositions(surfaceY: sY)[pocketIndex]
            var nearCount = 0, railCount = 0, fallbackCount = 0, total = 0
            print(String(format: "\n[O·袋%d] 袋心(%.2f,%.2f) 长内尖(%.3f,%.3f) 短内尖(%.3f,%.3f)",
                         pocketIndex, pocket.x, pocket.z, tips.long.x, tips.long.z, tips.short.x, tips.short.z))
            // 扫台面网格（加密 + 贴近库边，覆盖深贴库/极角等管道不可行区）。
            var x = -halfL + R + 0.01
            while x <= halfL - R - 0.01 {
                var z = -halfW + R + 0.005
                while z <= halfW - R - 0.005 {
                    let target = SCNVector3(x, sY + R, z)
                    let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: sY)
                    let dx = aim.x - target.x, dz = aim.z - target.z
                    let dl = hypotf(dx, dz)
                    if dl > 1e-4 {
                        total += 1
                        let ux = dx / dl, uz = dz / dl
                        let clearance = R + 0.003
                        let endX = target.x + ux * (dl + clearance)
                        let endZ = target.z + uz * (dl + clearance)
                        // 与生产一致：判据点 = jaw 与袋口圆圈的切/交点（jaw 段到袋心最近点）。
                        let longOuter = SCNVector3(tips.long.x / 1.2414 * 1.2823, sY, tips.long.z / 0.6658 * 0.7067)
                        let shortOuter = SCNVector3(tips.short.x / 1.3008 * 1.3417, sY, tips.short.z / 0.6064 * 0.6473)
                        func contactPt(_ a: SCNVector3, _ b: SCNVector3) -> SCNVector3 {
                            let vx = b.x - a.x, vz = b.z - a.z
                            let len2 = vx * vx + vz * vz
                            if len2 < 1e-9 { return a }
                            var t = ((pocket.x - a.x) * vx + (pocket.z - a.z) * vz) / len2
                            t = max(0, min(1, t))
                            return SCNVector3(a.x + vx * t, sY, a.z + vz * t)
                        }
                        let cLong = contactPt(tips.long, longOuter)
                        let cShort = contactPt(tips.short, shortOuter)
                        let dLong = hypotf(cLong.x - target.x, cLong.z - target.z)
                        let dShort = hypotf(cShort.x - target.x, cShort.z - target.z)
                        let nearTip = dLong <= dShort ? tips.long : tips.short
                        let nearOuter = dLong <= dShort ? longOuter : shortOuter
                        // (B) 管道是否碰到近端 jaw 段（情形3 不可行却被返回 = bug）。
                        let dNear = segDist(target.x, target.z, endX, endZ, nearTip.x, nearTip.z, nearOuter.x, nearOuter.z)
                        let hitsNearJaw = dNear < R   // 球面实际接触（球心 < R）
                        if hitsNearJaw {
                            nearCount += 1
                            if nearCount <= 5 {
                                print(String(format: "  ⚠ 碰近端jaw 目标(%.2f,%.2f) 管道到近端jaw=%.1fmm(球心<R=%.1f)",
                                             x, z, dNear * 1000, R * 1000))
                            }
                        }
                        // (A) 管道是否碰到任一主库（球心 < R = 实际吃库）。
                        var dRailMin = Float.greatestFiniteMagnitude
                        for (rax, raz, rbx, rbz) in mainRails {
                            dRailMin = min(dRailMin, segDist(target.x, target.z, endX, endZ, rax, raz, rbx, rbz))
                        }
                        let hitsRail = dRailMin < R
                        if hitsRail {
                            railCount += 1
                            if railCount <= 5 {
                                print(String(format: "  ⚠ 吃主库 目标(%.2f,%.2f) 管道到主库=%.1fmm(<R=%.1f)",
                                             x, z, dRailMin * 1000, R * 1000))
                            }
                        }
                        // 兜底袋心：返回点≈袋心，但直瞄袋心其实碰库或碰近端 jaw（未校验 fallback）。
                        let isCenter = hypotf(aim.x - pocket.x, aim.z - pocket.z) < 1e-4
                        if isCenter && (hitsRail || hitsNearJaw) {
                            fallbackCount += 1
                            if fallbackCount <= 5 {
                                print(String(format: "  ⚠ 兜底袋心违例 目标(%.2f,%.2f) 吃库=%@ 碰近端jaw=%@",
                                             x, z, hitsRail ? "Y" : "N", hitsNearJaw ? "Y" : "N"))
                            }
                        }
                    }
                    z += 0.03
                }
                x += 0.04
            }
            print(String(format: "  → 袋%d 网格%d点：碰近端jaw %d | 吃主库 %d | 兜底袋心违例 %d",
                         pocketIndex, total, nearCount, railCount, fallbackCount))
        }
        XCTAssertTrue(true)
    }

    /// 库模型标定探针：自然滚动球以不同入射角（相对法线）撞主长库，测
    ///   ① 反弹瞬时方向（碰后第一帧）② 稳定滚动方向（碰后 0.15s）③ 速度保留率。
    /// 用于对照真实公开数据（滚动球反弹角 ≈ 入射角、略偏宽；速度保留 ~70–75%），
    /// 定位 50–60° 突宽是否为 Han2005 滑/粘分支切换的非物理突变。
    func test_J_isolatedRailReflection() throws {
        let halfW = AngleSceneCalculator.innerWidth / 2
        print("\n[J·库模型标定] 自然滚动球撞主长库(e=0.85,f=0.20,h=37mm)；入/反角均相对法线")
        print("   incN  反弹瞬时  稳定滚动  速度保留   备注")
        let n = SCNVector3(0, 0, 1)
        for incN in stride(from: Float(20), through: 75, by: 5) {
            let fromNormal = incN * .pi / 180
            let dir = SCNVector3(sinf(fromNormal), 0, -cosf(fromNormal))
            let speed: Float = 3.0
            let vIn = SCNVector3(dir.x * speed, 0, dir.z * speed)
            let up = SCNVector3(0, 1, 0)
            let roll = up.cross(vIn) * (1.0 / R)
            let start = SCNVector3(0.0, sY + R, -(halfW - R) + 0.30)
            let engine = EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBallQiuJi(surfaceY: sY))
            engine.setBall(BallState(position: start, velocity: vIn, angularVelocity: roll, state: .rolling, name: "obj"))
            engine.simulate(maxEvents: 60, maxTime: 6)
            let rec = engine.getTrajectoryRecorder()
            guard let frames = rec.framesByBallName["obj"]?.sorted(by: { $0.time < $1.time }) else { continue }
            // 碰撞时刻 = 第一帧 v.z 由负转正。
            var hitIdx: Int?
            for i in 1..<frames.count where frames[i - 1].velocity.z <= 0 && frames[i].velocity.z > 0.02 { hitIdx = i; break }
            func ang(_ f: BallFrame) -> Float? {
                let s = hypotf(f.velocity.x, f.velocity.z)
                guard s > 1e-3 else { return nil }
                let d = SCNVector3(f.velocity.x / s, 0, f.velocity.z / s)
                return acosf(max(-1, min(1, d.x * n.x + d.z * n.z))) * 180 / .pi
            }
            var immDeg: Float = -1, setDeg: Float = -1, retain: Float = -1
            if let hi = hitIdx {
                immDeg = ang(frames[hi]) ?? -1
                retain = hypotf(frames[hi].velocity.x, frames[hi].velocity.z) / speed
                let tSet = frames[hi].time + 0.15
                if let fs = frames.last(where: { $0.time <= tSet }) { setDeg = ang(fs) ?? immDeg }
            }
            let note = setDeg > incN + 8 ? "⚠稳定反>>入" : (immDeg > incN + 8 ? "⚠瞬时偏宽" : "ok")
            print(String(format: "   %3.0f°   %5.0f°    %5.0f°     %4.0f%%    %@", incN, immDeg, setDeg, retain * 100, note))
        }
        XCTAssertTrue(true)
    }

    /// 直接调用 Han2005 闭式解（无引擎/无测量歧义）：自然滚动球撞长库各入射角的精确反弹。
    /// 同时打印含侧旋（throw 后目标球状态）时的反弹，定位真实球宽反射来源。
    func test_K_han2005Direct() throws {
        let speed: Float = 3.0
        let R = BallPhysics.radius
        let M = BallPhysics.mass
        let mu = TablePhysics.cushionFriction, e = TablePhysics.cushionRestitution, h = TablePhysics.cushionHeight
        func solveAt(incN: Float, sideSpin wUpVal: Float) -> (refDeg: Float, retain: Float) {
            // 接触系：N 指向运动(=入库)，T=U×N。法向速度=s·cos，切向=-s·sin（见推导）。
            let a = incN * .pi / 180
            let vN = speed * cosf(a), vT = -speed * sinf(a)
            let wT = vN / R, wN = -vT / R   // 自然滚动耦合
            let r = Han2005CushionModel.solve(vNormal: vN, vTangent: vT, wNormal: wN, wTangent: wT,
                                              wUp: wUpVal, mu: mu, e: e, h: h, R: R, M: M)
            let outSpeed = hypotf(r.vNormal, r.vTangent)
            // 反弹角(相对法线) = atan(|切向|/|法向|)；vNormal≤0(离库)。
            let ref = atan2f(abs(r.vTangent), abs(r.vNormal)) * 180 / .pi
            return (ref, outSpeed / speed)
        }
        print("\n[K·Han2005 闭式解·自然滚动] e=\(e) f=\(mu) h=\(h)m θa=\(String(format: "%.1f", asinf(h/R-1)*180/Float.pi))°")
        print("   incN  反弹角  速度保留")
        for incN in stride(from: Float(20), through: 75, by: 5) {
            let r = solveAt(incN: incN, sideSpin: 0)
            print(String(format: "   %3.0f°  %5.1f°   %4.0f%%  %@", incN, r.refDeg, r.retain * 100, r.refDeg > incN + 6 ? "⚠宽" : ""))
        }
        // 含侧旋（throw 后目标球常带 running/check side，量级 ~速度/R 的若干成）。
        print("   —— 叠加侧旋 wUp=±速度/R×0.5（模拟 throw 后目标球）——")
        for incN in [Float(40), 50, 60] {
            for sgn in [Float(1), -1] {
                let r = solveAt(incN: incN, sideSpin: sgn * speed / R * 0.5)
                print(String(format: "   incN%.0f° 侧旋%@ 反弹%.1f° 保留%.0f%%", incN, sgn > 0 ? "+(running)" : "-(check)", r.refDeg, r.retain * 100))
            }
        }
        XCTAssertTrue(true)
    }

    /// 转引擎直跑一个失败贴库球，dump 目标球撞的每段库（恢复系数区分 喉壁0.45/主库0.85）+ 法线。
    func test_L_whichCushion() throws {
        let halfW = AngleSceneCalculator.innerWidth / 2
        let geo = TableGeometry.chineseEightBallQiuJi(surfaceY: sY)
        let mainCount = TableGeometry.chineseEightBallCushions(y: sY).linear.count
        print("\n[L·撞哪种库] 主库段数=\(mainCount) 总线段=\(geo.linearCushions.count)（其余为喉腔壁）")
        let tgt = SCNVector3(-0.70, sY + R, -0.35)
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: tgt, pocketIndex: 0, surfaceY: sY)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: tgt, pocket: aim, ballRadius: R)
        let pdx = aim.x - tgt.x, pdz = aim.z - tgt.z
        let pl = max(hypotf(pdx, pdz), 1e-5)
        let pdir = SCNVector3(pdx / pl, 0, pdz / pl)
        for vel in [Float(2.4), 3.0, 3.8] {
            guard let cue = placeCue(ghost: ghost, pdir: pdir, cutDeg: 40, dist: 0.5) else { continue }
            // 几何直瞄（不走求解器），复现失败几何。
            let aimDir = unit(SCNVector3(ghost.x - cue.x, 0, ghost.z - cue.z))
            let strike = CueBallStrike.executeStrike(aimDirection: aimDir, velocity: vel, spinX: 0, spinY: 0)
            let engine = EventDrivenEngine(tableGeometry: geo)
            engine.setBall(BallState(position: cue, velocity: strike.velocity, angularVelocity: strike.angularVelocity, state: .sliding, name: "cue"))
            engine.setBall(BallState(position: tgt, velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero, state: .stationary, name: "obj"))
            engine.simulate(maxEvents: 300, maxTime: 12)
            print(String(format: "  v%.1f:", vel))
            for (ev, t) in zip(engine.resolvedEvents, engine.resolvedEventTimes) {
                if case .ballCushion(let b, let idx, let nrm) = ev, b == "obj" {
                    let kind = idx < mainCount ? "主库" : "喉壁"
                    let rest = idx < geo.linearCushions.count ? (geo.linearCushions[idx].restitution ?? -1) : -1
                    print("     t=\(String(format: "%.3f", t)) \(kind)#\(idx) e=\(rest) n(\(String(format: "%.2f", nrm.x)),\(String(format: "%.2f", nrm.z)))")
                }
            }
        }
    }

    // MARK: - S. 母球吃库反弹异常扫描（用户截图：吃左长库后反弹明显不合理，偶发）

    /// 随机扫掠「母球击目标球后走位」场景（直接驱动引擎以拿到事件流；几何直瞄 + 含塞/力度，
    /// 与页面物理同一条路径），逐帧分析**母球**轨迹的急转点并对照引擎事件：
    ///   ① 急转点无对应事件 → 「幽灵反弹」= 碰撞漏检后被 enforceTableBounds 硬钳
    ///      （法向 ×0.5、切向全保留 → 反射角严重偏平行，截图现象候选根因）；
    ///   ② 主库事件但出射法向分量 ≈ 0 → Han 模型 outVNormal>0 被钳 0 → 出射平行库边；
    ///   ③ 急转点对应喉腔壁/jaw/圆弧事件但位置远离袋口 → 撞错段（隐形墙）。
    /// 打印异常样本完整复现参数 + 事件上下文，并出 PNG。
    func test_S_cueRailReboundScan() throws {
        let geo = TableGeometry.chineseEightBallQiuJi(surfaceY: sY)
        let mainCount = 6
        let jawLineEnd = 14            // 6 主库 + 8 jaw 直线段
        let linearCount = geo.linearCushions.count   // 之后为喉腔壁（6 袋 × 3）
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: sY)

        func segKind(_ idx: Int) -> String {
            if idx < mainCount { return "主库#\(idx)" }
            if idx < jawLineEnd { return "jaw直线#\(idx)" }
            if idx < linearCount { return "喉腔壁#\(idx)" }
            return "圆弧#\(idx)"
        }
        func nearestPocketDist(_ p: SCNVector3) -> Float {
            var d = Float.greatestFiniteMagnitude
            for pc in pockets { d = min(d, hypotf(p.x - pc.x, p.z - pc.z)) }
            return d
        }
        /// 最近主库的内向法线（按位置粗判，仅用于主库反射角评估）。
        func railNormal(at p: SCNVector3) -> SCNVector3 {
            let dxl = (halfL - R) - abs(p.x)
            let dzl = (halfW - R) - abs(p.z)
            return dxl < dzl ? SCNVector3(p.x > 0 ? -1 : 1, 0, 0)
                             : SCNVector3(0, 0, p.z > 0 ? -1 : 1)
        }

        struct Anomaly {
            let tag: String
            let detail: String
            let path: [SCNVector3]
            let mark: SCNVector3
        }
        var anomalies: [Anomaly] = []
        var totalBounces = 0
        var ghostN = 0, ghostNearRailN = 0, parallelN = 0, wrongSegN = 0, wideN = 0

        var rng = SeededRNG(seed: 0xCAFE_BABE)
        let spinYs: [Float] = [-0.35, 0, 0.35]
        let spinXs: [Float] = [-0.25, 0, 0.25]
        let trials = 300
        print("\n[S·母球吃库反弹扫描] \(trials) 随机杆（引擎直跑，几何直瞄，含塞/力度）")

        for trial in 0..<trials {
            let cue = SCNVector3(rng.float(in: -(halfL - 2 * R)...(halfL - 2 * R)), sY + R,
                                 rng.float(in: -(halfW - 2 * R)...(halfW - 2 * R)))
            var target = SCNVector3(rng.float(in: -(halfL - 2 * R)...(halfL - 2 * R)), sY + R,
                                    rng.float(in: -(halfW - 2 * R)...(halfW - 2 * R)))
            var g = 0
            while hypotf(cue.x - target.x, cue.z - target.z) < 4 * R && g < 20 {
                target = SCNVector3(rng.float(in: -(halfL - 2 * R)...(halfL - 2 * R)), sY + R,
                                    rng.float(in: -(halfW - 2 * R)...(halfW - 2 * R)))
                g += 1
            }
            let pk = Int(rng.next() % 6)
            let vel = rng.float(in: 2.4...5.8)
            let spinY = spinYs[Int(rng.next() % 3)]
            let spinX = spinXs[Int(rng.next() % 3)]

            // 几何直瞄幽灵球（无求解器，物理路径与页面一致）。
            let aimPt = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pk, surfaceY: sY)
            let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: aimPt, ballRadius: R)
            let aimDir = unit(SCNVector3(ghost.x - cue.x, 0, ghost.z - cue.z))
            let strike = CueBallStrike.executeStrike(aimDirection: aimDir, velocity: vel,
                                                     spinX: spinX, spinY: spinY)
            let engine = EventDrivenEngine(tableGeometry: geo)
            engine.setBall(BallState(position: cue, velocity: strike.velocity,
                                     angularVelocity: strike.angularVelocity, state: .sliding,
                                     name: ShotInput.cueBallName))
            engine.setBall(BallState(position: target, velocity: SCNVector3Zero,
                                     angularVelocity: SCNVector3Zero, state: .stationary,
                                     name: ShotInput.targetBallName))
            engine.simulate(maxEvents: 500, maxTime: 15, highFidelityBounds: true)
            let rec = engine.getTrajectoryRecorder()
            guard let frames = rec.framesByBallName[ShotInput.cueBallName]?
                .sorted(by: { $0.time < $1.time }), frames.count >= 3 else { continue }

            // 母球事件流。
            var cueEvents: [(t: Float, desc: String, idx: Int?)] = []
            for (ev, et) in zip(engine.resolvedEvents, engine.resolvedEventTimes) {
                switch ev {
                case .ballCushion(let b, let idx, _) where b == ShotInput.cueBallName:
                    cueEvents.append((et, segKind(idx), idx))
                case .ballBall(let a, let b) where a == ShotInput.cueBallName || b == ShotInput.cueBallName:
                    cueEvents.append((et, "球球", nil))
                case .pocket(let b, _) where b == ShotInput.cueBallName:
                    cueEvents.append((et, "进袋", nil))
                default: break
                }
            }

            // 逐帧急转点。
            for i in 1..<frames.count {
                let f0 = frames[i - 1], f1 = frames[i]
                let s0 = hypotf(f0.velocity.x, f0.velocity.z)
                let s1 = hypotf(f1.velocity.x, f1.velocity.z)
                guard s0 > 0.08, s1 > 0.05 else { continue }
                let dot = max(-1, min(1, (f0.velocity.x * f1.velocity.x + f0.velocity.z * f1.velocity.z) / (s0 * s1)))
                let turn = acosf(dot) * 180 / .pi
                guard turn > 20 else { continue }
                totalBounces += 1

                // 急转发生在 f0→f1 之间：事件落在该帧间隙（含两端少量余量）才算对应。
                let near = cueEvents.filter { $0.t > f0.time - 0.005 && $0.t < f1.time + 0.005 }
                let p = f1.position
                func repro() -> String {
                    String(format: "trial%d cue(%.3f,%.3f) tgt(%.3f,%.3f) pk%d v%.2f sx%.2f sy%.2f",
                           trial, cue.x, cue.z, target.x, target.z, pk, vel, spinX, spinY)
                }
                func dump(_ tag: String, _ detail: String, forcePrint: Bool = false) {
                    anomalies.append(Anomaly(tag: tag, detail: detail, path: smoothPath(rec, ShotInput.cueBallName), mark: p))
                    guard anomalies.count <= 14 || forcePrint else { return }
                    print("  ⚠ [\(tag)] \(detail)")
                    print("     repro: \(repro())")
                    print(String(format: "     转角%.0f° @(%.3f,%.3f) t=%.3f in v(%.2f,%.2f)|%.2f| out v(%.2f,%.2f)|%.2f| 离袋%.0fmm",
                                 turn, p.x, p.z, f1.time, f0.velocity.x, f0.velocity.z, s0,
                                 f1.velocity.x, f1.velocity.z, s1, nearestPocketDist(p) * 1000))
                    print(String(format: "     in w(%.1f,%.1f,%.1f) out w(%.1f,%.1f,%.1f)",
                                 f0.angularVelocity.x, f0.angularVelocity.y, f0.angularVelocity.z,
                                 f1.angularVelocity.x, f1.angularVelocity.y, f1.angularVelocity.z))
                    let ctx = cueEvents.filter { abs($0.t - f1.time) < 0.25 }
                        .map { String(format: "t%.3f %@", $0.t, $0.desc) }.joined(separator: " | ")
                    print("     近邻事件: \(ctx.isEmpty ? "（无）" : ctx)")
                }

                if near.isEmpty {
                    ghostN += 1
                    // 细分：急转点是否贴在矩形安全框边线（enforceTableBounds 硬钳特征位置）。
                    let distX = AngleSceneCalculator.innerLength / 2 - R - abs(p.x)
                    let distZ = AngleSceneCalculator.innerWidth / 2 - R - abs(p.z)
                    let nearRail = min(distX, distZ) < 0.008
                    if nearRail { ghostNearRailN += 1 }
                    dump("幽灵反弹·无事件", "急转点无任何引擎事件（疑漏检+enforceTableBounds硬钳）", forcePrint: nearRail)
                    continue
                }
                // 主库事件：评估反射几何。
                if let railEv = near.first(where: { ($0.idx ?? 99) < mainCount }), let idx = railEv.idx {
                    let n = geo.linearCushions[idx].normal
                    let vnIn = -(f0.velocity.x * n.x + f0.velocity.z * n.z)   // 入射法向分量（>0 朝库）
                    let vnOut = f1.velocity.x * n.x + f1.velocity.z * n.z     // 出射法向分量（>0 离库）
                    let incDeg = acosf(max(-1, min(1, vnIn / max(s0, 1e-5)))) * 180 / .pi
                    let refDeg = acosf(max(-1, min(1, vnOut / max(s1, 1e-5)))) * 180 / .pi
                    if vnIn > 0.3 * s0 && vnOut < 0.05 * s1 {
                        parallelN += 1
                        dump("平行出射", String(format: "主库#%d 入射法向%.2f 出射法向%.3f（Han钳0?） 入%.0f°→反%.0f°", idx, vnIn, vnOut, incDeg, refDeg))
                    } else if refDeg > incDeg + 25 {
                        wideN += 1
                        dump("反射严重偏宽", String(format: "主库#%d 入%.0f°→反%.0f°", idx, incDeg, refDeg))
                    }
                    continue
                }
                // 非主库段：若发生在远离袋口处 → 隐形墙。
                if let segEv = near.first(where: { $0.idx != nil }), let idx = segEv.idx,
                   nearestPocketDist(p) > 0.18 {
                    wrongSegN += 1
                    dump("远离袋口撞非主库段", "撞 \(segKind(idx)) 但离最近袋 \(Int(nearestPocketDist(p) * 1000))mm")
                }
            }
            _ = railNormal
        }

        print(String(format: "\n[S·汇总] 吃库/急转 %d 次 | 幽灵反弹 %d（其中贴库线 %d）| 平行出射 %d | 反射偏宽 %d | 远袋撞错段 %d",
                     totalBounces, ghostN, ghostNearRailN, parallelN, wideN, wrongSegN))

        // 出 PNG（前 9 个异常）。
        if !anomalies.isEmpty {
            var panels: [UIImage] = []
            for a in anomalies.prefix(9) {
                panels.append(tablePanel(size: CGSize(width: 560, height: 360), header: a.tag, subtitle: a.detail) { cg, xf in
                    self.strokePath(cg, a.path.map(xf.P), color: .white, width: 2.0)
                    let c = xf.P(a.mark)
                    cg.setStrokeColor(UIColor.red.cgColor); cg.setLineWidth(2)
                    cg.strokeEllipse(in: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14))
                })
            }
            try composeSheet(panels, cols: 3, filename: "S_cue_rebound_anomalies.png",
                             title: "S · 母球吃库反弹异常（红圈=急转点）")
        }
        XCTAssertTrue(true)
    }

    /// S2 · 复现截图场景族：38° 切角 + 高杆/大力，目标袋=角袋，渲染母球走位多库路径，
    /// 并打印每次吃库的入/反角与对应库段，肉眼比对截图中「左长库反弹不合理」。
    func test_S2_screenshotLikeFollowShot() throws {
        let geo = TableGeometry.chineseEightBallQiuJi(surfaceY: sY)
        let mainCount = 6
        let jawLineEnd = 14
        let linearCount = geo.linearCushions.count
        func segKind(_ idx: Int) -> String {
            if idx < mainCount { return "主库#\(idx)" }
            if idx < jawLineEnd { return "jaw#\(idx)" }
            if idx < linearCount { return "喉壁#\(idx)" }
            return "弧#\(idx)"
        }
        // 类截图摆位：目标球居中偏上，母球在其下方 38° 切位，目标袋 = 左上角袋(0)。
        let target = SCNVector3(0.10, sY + R, 0.05)
        let pocketIndex = 0
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: sY)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: aim, ballRadius: R)
        let pdir = unit(SCNVector3(aim.x - target.x, 0, aim.z - target.z))
        var panels: [UIImage] = []
        print("\n[S2·类截图场景] 切38° 袋0(左上) 扫 力度×spinY")
        for vel in [Float(4.4), 5.8] {
            for spinY in [Float(0), 0.3, 0.45] {
                guard let cue = placeCue(ghost: ghost, pdir: pdir, cutDeg: 38, dist: 0.6) else { continue }
                let pred = ShotPredictor.predict(ShotInput(
                    cueBall: cue, targetBall: target, pocketIndex: pocketIndex,
                    velocity: vel, spinX: 0, spinY: spinY, surfaceY: sY))
                guard pred.feasible else { continue }
                // 同参数引擎直跑取事件（用 cuePath 首段反推最终瞄向）。
                var launchDir = pred.aimDirection
                if pred.cuePath.count >= 2 {
                    launchDir = unit(SCNVector3(pred.cuePath[1].x - pred.cuePath[0].x, 0,
                                                pred.cuePath[1].z - pred.cuePath[0].z))
                }
                let strike = CueBallStrike.executeStrike(aimDirection: launchDir, velocity: vel, spinX: 0, spinY: spinY)
                let engine = EventDrivenEngine(tableGeometry: geo)
                engine.setBall(BallState(position: cue, velocity: strike.velocity, angularVelocity: strike.angularVelocity, state: .sliding, name: "cueBall"))
                engine.setBall(BallState(position: target, velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero, state: .stationary, name: "object"))
                engine.simulate(maxEvents: 500, maxTime: 15, highFidelityBounds: true)
                print(String(format: "  v%.1f spinY%.2f cue(%.2f,%.2f) 进=%@ 母球吃库%d", vel, spinY, cue.x, cue.z,
                             pred.objectPocketed ? "Y" : "N", pred.cueCushionCount))
                let rec = engine.getTrajectoryRecorder()
                let frames = (rec.framesByBallName["cueBall"] ?? []).sorted { $0.time < $1.time }
                for (ev, et) in zip(engine.resolvedEvents, engine.resolvedEventTimes) {
                    guard case .ballCushion(let b, let idx, let n) = ev, b == "cueBall" else { continue }
                    // 入/出帧。
                    let before = frames.last(where: { $0.time < et - 1e-4 })
                    let after = frames.first(where: { $0.time >= et - 1e-5 && hypotf($0.velocity.x, $0.velocity.z) > 1e-3 })
                    var detail = ""
                    if let b0 = before, let a1 = after {
                        let s0 = hypotf(b0.velocity.x, b0.velocity.z), s1 = hypotf(a1.velocity.x, a1.velocity.z)
                        let vnIn = -(b0.velocity.x * n.x + b0.velocity.z * n.z)
                        let vnOut = a1.velocity.x * n.x + a1.velocity.z * n.z
                        let incDeg = acosf(max(-1, min(1, vnIn / max(s0, 1e-5)))) * 180 / .pi
                        let refDeg = acosf(max(-1, min(1, vnOut / max(s1, 1e-5)))) * 180 / .pi
                        detail = String(format: "入%.0f°→反%.0f° |v| %.2f→%.2f", incDeg, refDeg, s0, s1)
                    }
                    print(String(format: "     t%.2f %@ n(%.2f,%.2f) %@ @(%.3f,%.3f)",
                                 et, segKind(idx), n.x, n.z, detail,
                                 (after ?? before)?.position.x ?? 0, (after ?? before)?.position.z ?? 0))
                }
                panels.append(tablePanel(size: CGSize(width: 560, height: 360),
                                         header: String(format: "v%.1f spinY%.2f", vel, spinY),
                                         subtitle: String(format: "母球吃库%d 进袋=%@", pred.cueCushionCount, pred.objectPocketed ? "Y" : "N")) { cg, xf in
                    self.highlightPocket(cg, xf, pocketIndex)
                    self.strokePath(cg, pred.objectPath.map(xf.P), color: UIColor(red: 0.98, green: 0.62, blue: 0.12, alpha: 0.95), width: 2.0)
                    self.strokePath(cg, pred.cuePath.map(xf.P), color: .white, width: 2.0)
                    self.drawBall(cg, xf, target, UIColor(red: 0.95, green: 0.75, blue: 0.05, alpha: 1))
                    self.drawBall(cg, xf, cue, .white)
                })
            }
        }
        try composeSheet(panels, cols: 3, filename: "S2_screenshot_like.png",
                         title: "S2 · 类截图 38° 高杆走位（白=母球 橙=目标球）")
        XCTAssertTrue(true)
    }

    /// S3 · 两个候选根因的逐帧确证：
    ///  case1 = trial19（幽灵反弹）：dump 急转前后全帧 + 手动复算角弧 CCD 是否漏检；
    ///  case2 = S2 v4.4 spinY0（反131°）：dump 吃库前后全帧，区分「Han 输出朝库内（bug）」
    ///          vs「反弹后高杆回弯再扎库（物理）」。
    func test_S3_frameLevelConfirm() throws {
        let geo = TableGeometry.chineseEightBallQiuJi(surfaceY: sY)
        func segKind(_ idx: Int) -> String {
            if idx < 6 { return "主库#\(idx)" }
            if idx < 14 { return "jaw#\(idx)" }
            if idx < geo.linearCushions.count { return "喉壁#\(idx)" }
            return "弧#\(idx)"
        }

        func runAndDump(label: String, cue: SCNVector3, target: SCNVector3, pk: Int,
                        vel: Float, sx: Float, sy: Float, tWin: ClosedRange<Float>) {
            let aimPt = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pk, surfaceY: sY)
            let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: aimPt, ballRadius: R)
            let aimDir = unit(SCNVector3(ghost.x - cue.x, 0, ghost.z - cue.z))
            let strike = CueBallStrike.executeStrike(aimDirection: aimDir, velocity: vel, spinX: sx, spinY: sy)
            let engine = EventDrivenEngine(tableGeometry: geo)
            engine.setBall(BallState(position: cue, velocity: strike.velocity, angularVelocity: strike.angularVelocity, state: .sliding, name: "cueBall"))
            engine.setBall(BallState(position: target, velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero, state: .stationary, name: "object"))
            engine.simulate(maxEvents: 500, maxTime: 15, highFidelityBounds: true)
            print("\n[S3·\(label)] cue(\(cue.x),\(cue.z)) tgt(\(target.x),\(target.z)) pk\(pk) v\(vel) sx\(sx) sy\(sy)")
            print("  事件（窗内）:")
            for (ev, et) in zip(engine.resolvedEvents, engine.resolvedEventTimes) where tWin.contains(et) {
                switch ev {
                case .ballCushion(let b, let idx, let n) where b == "cueBall":
                    print(String(format: "    t=%.4f 吃库 %@ n(%.3f,%.3f)", et, segKind(idx), n.x, n.z))
                case .ballBall(let a, let b) where a == "cueBall" || b == "cueBall":
                    print(String(format: "    t=%.4f 球球", et))
                case .transition(let b, let f, let t2) where b == "cueBall":
                    print(String(format: "    t=%.4f 转换 %@→%@", et, "\(f)", "\(t2)"))
                default: break
                }
            }
            let frames = (engine.getTrajectoryRecorder().framesByBallName["cueBall"] ?? []).sorted { $0.time < $1.time }
            print("  帧（窗内）:")
            for f in frames where tWin.contains(f.time) {
                print(String(format: "    t=%.4f @(%.4f,%.4f) v(%.3f,%.3f)|%.3f| w(%.1f,%.1f,%.1f) %@",
                             f.time, f.position.x, f.position.z, f.velocity.x, f.velocity.z,
                             hypotf(f.velocity.x, f.velocity.z),
                             f.angularVelocity.x, f.angularVelocity.y, f.angularVelocity.z, "\(f.state)"))
            }
            // case1 附加：取急转前最后一帧，手动复算所有角弧/jaw/短库的 CCD 解。
            if label.hasPrefix("case1") {
                guard let pre = frames.last(where: { $0.time < 0.428 && hypotf($0.velocity.x, $0.velocity.z) > 0.5 }) else { return }
                let a = EngineNumerics.acceleration(for: BallState(position: pre.position, velocity: pre.velocity,
                    angularVelocity: SCNVector3(pre.angularVelocity.x, pre.angularVelocity.y, pre.angularVelocity.z),
                    state: pre.state, name: "cueBall"))
                print(String(format: "  [case1·CCD复算] 起点 t=%.4f @(%.4f,%.4f) v(%.3f,%.3f) a(%.3f,%.3f) 态%@",
                             pre.time, pre.position.x, pre.position.z, pre.velocity.x, pre.velocity.z, a.x, a.z, "\(pre.state)"))
                for (i, arc) in geo.circularCushions.enumerated() {
                    let t = CollisionDetector.ballCircularCushionTime(
                        p: pre.position, v: pre.velocity, a: a, arc: arc, R: R, maxTime: 1.0, pockets: geo.pockets)
                    if let t {
                        print(String(format: "    弧#%d center(%.4f,%.4f) r%.3f [%.0f°..%.0f°] → 命中 t=%.4f", i,
                                     arc.center.x, arc.center.z, arc.radius,
                                     arc.startAngle * 180 / .pi, arc.endAngle * 180 / .pi, t))
                    } else {
                        // 仅打印附近的弧（中心距 < 0.4m）。
                        let d = hypotf(pre.position.x - arc.center.x, pre.position.z - arc.center.z)
                        if d < 0.4 {
                            print(String(format: "    弧#%d center(%.4f,%.4f) [%.0f°..%.0f°] 距%.3f → 无解", i,
                                         arc.center.x, arc.center.z,
                                         arc.startAngle * 180 / .pi, arc.endAngle * 180 / .pi, d))
                        }
                    }
                }
                for (i, seg) in geo.linearCushions.enumerated() {
                    let lineOffset = Double(seg.normal.dot(seg.start))
                    guard let t = CollisionDetector.ballLinearCushionTime(
                        p: pre.position, v: pre.velocity, a: a,
                        lineNormal: seg.normal, lineOffset: lineOffset, R: Double(R), maxTime: 1.0) else { continue }
                    let hitPos = pre.position + pre.velocity * t + a * (0.5 * t * t)
                    let within = EngineNumerics.isWithinLinearCushionSegment(point: hitPos, segment: seg)
                    print(String(format: "    线#%d %@ → t=%.4f @(%.4f,%.4f) 段内=%@", i, segKind(i), t, hitPos.x, hitPos.z, within ? "Y" : "N"))
                }
            }
        }

        // case1：trial19 幽灵反弹（左短库/角弧接缝漏检 → enforceTableBounds 硬钳）。
        runAndDump(label: "case1·幽灵反弹", cue: SCNVector3(-0.534, sY + R, -0.531),
                   target: SCNVector3(-0.979, sY + R, -0.332), pk: 1, vel: 3.34, sx: 0, sy: 0.35,
                   tWin: 0.25...0.85)
        // case2：S2 v4.4 spinY0 的 入29°→反131°（上长库 x≈-0.145）。
        let target2 = SCNVector3(0.10, sY + R, 0.05)
        let aim2 = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target2, pocketIndex: 0, surfaceY: sY)
        let ghost2 = AngleSceneCalculator.ghostBallPosition(targetBall: target2, pocket: aim2, ballRadius: R)
        let pdir2 = unit(SCNVector3(aim2.x - target2.x, 0, aim2.z - target2.z))
        if let cue2 = placeCue(ghost: ghost2, pdir: pdir2, cutDeg: 38, dist: 0.6) {
            runAndDump(label: "case2·反131°", cue: cue2, target: target2, pk: 0,
                       vel: 4.4, sx: 0, sy: 0, tWin: 0.15...0.60)
        }
        XCTAssertTrue(true)
    }

    /// S4 · 完全复刻 S2 跑法（ShotPredictor 补偿瞄向 + 同参数引擎直跑），定位 S2 测得
    /// 「入29°→反131°」与 S3 直瞄跑出「干净 27° 反射」的差异来源：
    ///  ① dump 首次吃库前后全帧（含 w/state），看瞬时出射是否合法；
    ///  ② 对吃库前一帧手动调 resolveCushionCollisionPure，对照引擎实际出射；
    ///  ③ dump 全事件链（两球）直到模拟结束，确认「吃库→远端弧→进袋」链条是否真实存在；
    ///  ④ 对照 pred.cuePath（页面真实渲染数据）在库边附近的折点。
    func test_S4_replicateS2EventChain() throws {
        let geo = TableGeometry.chineseEightBallQiuJi(surfaceY: sY)
        let linearCount = geo.linearCushions.count
        func segKind(_ idx: Int) -> String {
            if idx < 6 { return "主库#\(idx)" }
            if idx < 14 { return "jaw#\(idx)" }
            if idx < linearCount { return "喉壁#\(idx)" }
            return "弧#\(idx)"
        }
        let target = SCNVector3(0.10, sY + R, 0.05)
        let pocketIndex = 0
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: sY)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: aim, ballRadius: R)
        let pdir = unit(SCNVector3(aim.x - target.x, 0, aim.z - target.z))

        for spinY in [Float(0), 0.45] {
            guard let cue = placeCue(ghost: ghost, pdir: pdir, cutDeg: 38, dist: 0.6) else { continue }
            let vel: Float = 4.4
            let pred = ShotPredictor.predict(ShotInput(
                cueBall: cue, targetBall: target, pocketIndex: pocketIndex,
                velocity: vel, spinX: 0, spinY: spinY, surfaceY: sY))
            guard pred.feasible else { continue }
            var launchDir = pred.aimDirection
            if pred.cuePath.count >= 2 {
                launchDir = unit(SCNVector3(pred.cuePath[1].x - pred.cuePath[0].x, 0,
                                            pred.cuePath[1].z - pred.cuePath[0].z))
            }
            let strike = CueBallStrike.executeStrike(aimDirection: launchDir, velocity: vel, spinX: 0, spinY: spinY)
            let engine = EventDrivenEngine(tableGeometry: geo)
            engine.setBall(BallState(position: cue, velocity: strike.velocity, angularVelocity: strike.angularVelocity, state: .sliding, name: "cueBall"))
            engine.setBall(BallState(position: target, velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero, state: .stationary, name: "object"))
            engine.simulate(maxEvents: 500, maxTime: 15, highFidelityBounds: true)

            print(String(format: "\n[S4·spinY%.2f] cue(%.4f,%.4f) launch(%.4f,%.4f) 预测进袋=%@ 母球吃库%d",
                         spinY, cue.x, cue.z, launchDir.x, launchDir.z,
                         pred.objectPocketed ? "Y" : "N", pred.cueCushionCount))

            // ③ 全事件链（两球，到结束）。
            print("  全事件链:")
            for (ev, et) in zip(engine.resolvedEvents, engine.resolvedEventTimes) {
                switch ev {
                case .ballCushion(let b, let idx, let n):
                    print(String(format: "    t=%.4f [%@] 吃库 %@ n(%.3f,%.3f)", et, b, segKind(idx), n.x, n.z))
                case .ballBall(let a, let b):
                    print(String(format: "    t=%.4f 球球 %@×%@", et, a, b))
                case .pocket(let b, let pid):
                    print(String(format: "    t=%.4f [%@] 进袋 %@", et, b, pid))
                case .transition(let b, let f, let t2):
                    print(String(format: "    t=%.4f [%@] 转换 %@→%@", et, b, "\(f)", "\(t2)"))
                }
            }

            // ① 首次吃库前后全帧。
            guard let firstCushionIdx = zip(engine.resolvedEvents, engine.resolvedEventTimes).first(where: {
                if case .ballCushion(let b, _, let _) = $0.0, b == "cueBall" { return true }
                return false
            }) else { continue }
            guard case .ballCushion(_, _, let n1) = firstCushionIdx.0 else { continue }
            let et1 = firstCushionIdx.1
            let frames = (engine.getTrajectoryRecorder().framesByBallName["cueBall"] ?? []).sorted { $0.time < $1.time }
            print(String(format: "  首次吃库 t=%.4f 前后帧:", et1))
            for f in frames where f.time > et1 - 0.03 && f.time < et1 + 0.08 {
                print(String(format: "    t=%.5f @(%.4f,%.4f) v(%.3f,%.3f)|%.3f| w(%.1f,%.1f,%.1f) %@",
                             f.time, f.position.x, f.position.z, f.velocity.x, f.velocity.z,
                             hypotf(f.velocity.x, f.velocity.z),
                             f.angularVelocity.x, f.angularVelocity.y, f.angularVelocity.z, "\(f.state)"))
            }

            // ② 手动复算瞬时出射。
            if let pre = frames.last(where: { $0.time < et1 - 1e-5 }) {
                let r = CollisionResolver.resolveCushionCollisionPure(
                    velocity: pre.velocity,
                    angularVelocity: SCNVector3(pre.angularVelocity.x, pre.angularVelocity.y, pre.angularVelocity.z),
                    normal: n1)
                let s = hypotf(r.velocity.x, r.velocity.z)
                let vn = r.velocity.x * n1.x + r.velocity.z * n1.z
                let refDeg = acosf(max(-1, min(1, vn / max(s, 1e-5)))) * 180 / .pi
                print(String(format: "  [复算] 入帧v(%.3f,%.3f) → 出v(%.3f,%.3f)|%.3f| 出射角%.0f° w出(%.1f,%.1f,%.1f)",
                             pre.velocity.x, pre.velocity.z, r.velocity.x, r.velocity.z, s, refDeg,
                             r.angularVelocity.x, r.angularVelocity.y, r.angularVelocity.z))
            }

            // ④ pred.cuePath 在首库附近折点（页面真实渲染数据）。
            print("  pred.cuePath 库边附近折点:")
            for (i, p) in pred.cuePath.enumerated() where p.z > 0.55 || abs(p.x) > 1.18 {
                print(String(format: "    [%d] (%.4f,%.4f)", i, p.x, p.z))
            }
        }
        XCTAssertTrue(true)
    }

    private func jawTipDist(_ index: Int) -> Float {
        let pc = AngleSceneCalculator.pocketPositions(surfaceY: sY)[index]
        let j = AngleSceneCalculator.pocketJaws(surfaceY: sY)[index]
        let d0 = hypotf(j.0.x - pc.x, j.0.z - pc.z)
        let d1 = hypotf(j.1.x - pc.x, j.1.z - pc.z)
        return (d0 + d1) / 2
    }

    /// 找目标球第一次库边碰撞（速度方向急转处），返回碰撞点 + 最近库面 + 入射/反射角（相对法线）。
    private func firstObjCushion(_ rec: TrajectoryRecorder?)
        -> (pos: SCNVector3, rail: String, incidenceDeg: Float, reflectionDeg: Float)? {
        guard let frames = rec?.framesByBallName[ShotInput.targetBallName]?
            .sorted(by: { $0.time < $1.time }), frames.count >= 3 else { return nil }
        let halfL = AngleSceneCalculator.innerLength / 2, halfW = AngleSceneCalculator.innerWidth / 2
        func vdir(_ i: Int) -> SCNVector3? {
            let vx = frames[i].velocity.x, vz = frames[i].velocity.z
            let s = hypotf(vx, vz); return s > 1e-4 ? SCNVector3(vx / s, 0, vz / s) : nil
        }
        for i in 1..<frames.count {
            guard let inD = vdir(i - 1), let outD = vdir(i) else { continue }
            let dot = max(-1, min(1, inD.x * outD.x + inD.z * outD.z))
            let turn = acosf(dot) * 180 / .pi
            guard turn > 25 else { continue }
            let p = frames[i].position
            // 最近库面法线（内向）。
            let dxL = (halfL - R) - abs(p.x), dzL = (halfW - R) - abs(p.z)
            let isShort = dxL < dzL
            let n: SCNVector3 = isShort ? SCNVector3(p.x > 0 ? -1 : 1, 0, 0)
                                        : SCNVector3(0, 0, p.z > 0 ? -1 : 1)
            let inc = acosf(max(-1, min(1, (-inD.x) * n.x + (-inD.z) * n.z))) * 180 / .pi
            let ref = acosf(max(-1, min(1, outD.x * n.x + outD.z * n.z))) * 180 / .pi
            return (p, isShort ? "短库" : "长库", inc, ref)
        }
        return nil
    }

    /// 直接发射目标球，返回是否进选定袋 + jaw 撞击点(若有) + 最近袋心 + 路径。
    private func launchProbe(start: SCNVector3, aimPoint: SCNVector3, speed: Float, pocketIndex: Int)
        -> (potted: Bool, contact: SCNVector3?, minDist: Float, path: [SCNVector3]) {
        let dir = unit(SCNVector3(aimPoint.x - start.x, 0, aimPoint.z - start.z))
        let v = SCNVector3(dir.x * speed, 0, dir.z * speed)
        let up = SCNVector3(0, 1, 0)
        let roll = up.cross(v) * (1.0 / R)
        let engine = EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBallQiuJi(surfaceY: sY))
        engine.setBall(BallState(position: start, velocity: v, angularVelocity: roll, state: .rolling, name: "obj"))
        engine.simulate(maxEvents: 300, maxTime: 10)
        let rec = engine.getTrajectoryRecorder()
        var objPocketId: String?
        for ev in engine.resolvedEvents { if case .pocket(let b, let pid) = ev, b == "obj", objPocketId == nil { objPocketId = pid } }
        let pc = AngleSceneCalculator.pocketPositions(surfaceY: sY)[pocketIndex]
        var minD = Float.greatestFiniteMagnitude
        if let frames = rec.framesByBallName["obj"] {
            for f in frames { let dx = f.position.x - pc.x, dz = f.position.z - pc.z; minD = min(minD, sqrtf(dx * dx + dz * dz)) }
        }
        let contact = jawContactPoint(rec, ballName: "obj", pocket: pc, within: 0.22)
        return (objPocketId == "pocket_\(pocketIndex)", contact, minD, smoothPath(rec, "obj"))
    }

    private func approachLeanDeg(start: SCNVector3, pocketCenter C: SCNVector3) -> Float {
        let n = unit(C)
        let d = unit(SCNVector3(C.x - start.x, 0, C.z - start.z))
        let lean = abs(d.x * n.z - d.z * n.x)
        return asinf(max(-1, min(1, lean))) * 180 / .pi
    }

    /// 在目标球轨迹上找「离袋 within 内、转向最急(>12°)」的点 ≈ jaw 撞击点。
    private func jawContactPoint(_ rec: TrajectoryRecorder?, ballName: String, pocket: SCNVector3, within: Float) -> SCNVector3? {
        guard let frames = rec?.framesByBallName[ballName]?.sorted(by: { $0.time < $1.time }), frames.count >= 3 else { return nil }
        var prevDir: SCNVector3?
        var bestTurn: Float = 12
        var bestPos: SCNVector3?
        for i in 1..<frames.count {
            let a = frames[i - 1].position, b = frames[i].position
            let dv = SCNVector3(b.x - a.x, 0, b.z - a.z)
            if dv.x * dv.x + dv.z * dv.z < 1e-6 { continue }
            let dir = unit(dv)
            if let pv = prevDir {
                let turn = angleDegXZ(dir, pv)
                let dp = hypotf(a.x - pocket.x, a.z - pocket.z)
                if turn > bestTurn && dp <= within { bestTurn = turn; bestPos = a }
            }
            prevDir = dir
        }
        return bestPos
    }

    /// 近/远 jaw 判定：进球方向 d=unit(C−T)、袋口朝外法线 n=unit(C)(台心在原点)；
    /// approach 横向偏向 s=sign(d×n)，撞点侧 sideP=sign((P−C)×n)；同侧=近jaw，异侧=远jaw。
    private func classifyJaw(approachFrom T: SCNVector3, pocketCenter C: SCNVector3, contact P: SCNVector3) -> String {
        let n = unit(C)
        let d = unit(SCNVector3(C.x - T.x, 0, C.z - T.z))
        let lean = d.x * n.z - d.z * n.x
        let sideP = (P.x - C.x) * n.z - (P.z - C.z) * n.x
        if abs(lean) < 0.08 { return "正对" }
        return (lean > 0) == (sideP > 0) ? "近jaw" : "远jaw"
    }

    private func angleDegXZ(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dot = max(-1, min(1, a.x * b.x + a.z * b.z))
        return acosf(dot) * 180 / .pi
    }

    private struct BruteResult {
        let foundAny: Bool          // 存在能进的瞄准（含撞jaw进）
        let foundClean: Bool        // 存在干净直接进（0吃库）
        let bestOffsetDeg: Float    // 最佳（最近袋心）进袋瞄准偏移
        let anyWindowDeg: Float     // 任意方式进的偏移窗宽
        let cleanWindowDeg: Float   // 干净进的偏移窗宽
        let minDist: Float
        let bestPath: [SCNVector3]
    }

    /// 暴力精扫母球击球方向(绕"母球→effectivePocketAimPoint幽灵球"基准 ±12°/0.25°)，统计两档：
    /// ①任意方式进(含撞jaw再进)；②干净直接进(0吃库)。无塞 ⇒ 与求解器同基准、同保真，仅更细网格
    /// + 直接看是否进。用于判定：求解器未进时，是否其实存在可进瞄准(=求解器漏)，还是物理真不可进。
    private func bruteFindPot(cue: SCNVector3, target: SCNVector3, pocketIndex: Int, velocity: Float) -> BruteResult {
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: sY)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: aim, ballRadius: R)
        let baseAim = unit(SCNVector3(ghost.x - cue.x, 0, ghost.z - cue.z))
        var anyOffsets: [Float] = [], cleanOffsets: [Float] = []
        var best: (off: Float, dist: Float, path: [SCNVector3])?
        var globalMin = Float.greatestFiniteMagnitude
        var off: Float = -12
        while off <= 12 + 1e-6 {
            let aimDir = baseAim.rotatedY(off * .pi / 180)
            let r = runCueShot(cue: cue, target: target, aimDir: aimDir, velocity: velocity, pocketIndex: pocketIndex)
            globalMin = min(globalMin, r.minDist)
            if r.potted {
                anyOffsets.append(off)
                if r.objCush == 0 { cleanOffsets.append(off) }
                if best == nil || r.minDist < best!.dist { best = (off, r.minDist, r.path) }
            }
            off += 0.25
        }
        let anyW = anyOffsets.isEmpty ? 0 : (anyOffsets.max()! - anyOffsets.min()!)
        let cleanW = cleanOffsets.isEmpty ? 0 : (cleanOffsets.max()! - cleanOffsets.min()!)
        return BruteResult(foundAny: !anyOffsets.isEmpty, foundClean: !cleanOffsets.isEmpty,
                           bestOffsetDeg: best?.off ?? 0, anyWindowDeg: anyW, cleanWindowDeg: cleanW,
                           minDist: best?.dist ?? globalMin, bestPath: best?.path ?? [])
    }

    private func verdictText(solverPot: Bool, bf: BruteResult) -> (tag: String, sub: String) {
        if solverPot { return ("求解器进✓", String(format: "干净窗%.2f° 任意窗%.2f°", bf.cleanWindowDeg, bf.anyWindowDeg)) }
        if bf.foundAny { return ("求解器漏解✗", String(format: "可进@%.2f°(任意窗%.2f°/干净窗%.2f°) 求解器漏", bf.bestOffsetDeg, bf.anyWindowDeg, bf.cleanWindowDeg)) }
        return ("物理不可进", String(format: "±12°暴力扫全不进(最近袋心%.0fmm)", bf.minDist * 1000))
    }

    /// 单发母球击球（无塞），返回目标球是否进选定袋 + 撞库前吃库数 + 最近袋心 + 目标球路径。
    private func runCueShot(cue: SCNVector3, target: SCNVector3, aimDir: SCNVector3, velocity: Float, pocketIndex: Int)
        -> (potted: Bool, objCush: Int, minDist: Float, path: [SCNVector3]) {
        let strike = CueBallStrike.executeStrike(aimDirection: aimDir, velocity: velocity, spinX: 0, spinY: 0)
        let engine = EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBallQiuJi(surfaceY: sY))
        engine.setBall(BallState(position: cue, velocity: strike.velocity, angularVelocity: strike.angularVelocity, state: .sliding, name: "cue"))
        engine.setBall(BallState(position: target, velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero, state: .stationary, name: "obj"))
        engine.simulate(maxEvents: 500, maxTime: 12)
        let rec = engine.getTrajectoryRecorder()
        var objPocketId: String?, objCush = 0
        for ev in engine.resolvedEvents {
            switch ev {
            case .ballCushion(let b, _, _) where b == "obj": if objPocketId == nil { objCush += 1 }
            case .pocket(let b, let pid) where b == "obj": if objPocketId == nil { objPocketId = pid }
            default: break
            }
        }
        var minD = Float.greatestFiniteMagnitude
        let pc = AngleSceneCalculator.pocketPositions(surfaceY: sY)[pocketIndex]
        if let frames = rec.framesByBallName["obj"] {
            for f in frames { let dx = f.position.x - pc.x, dz = f.position.z - pc.z; minD = min(minD, sqrtf(dx * dx + dz * dz)) }
        }
        return (objPocketId == "pocket_\(pocketIndex)", objCush, minD, smoothPath(rec, "obj"))
    }

    /// 给目标球摆一个在台面内、朝指定切角的母球位（两符号取在台面内且更靠内侧者）。
    private func placeCue(ghost: SCNVector3, pdir: SCNVector3, cutDeg: Float, dist: Float) -> SCNVector3? {
        let halfL = AngleSceneCalculator.innerLength / 2, halfW = AngleSceneCalculator.innerWidth / 2
        var candidates: [SCNVector3] = []
        for sign in [Float(1), -1] {
            let th = cutDeg * .pi / 180 * sign
            let sd = SCNVector3(pdir.x * cosf(th) - pdir.z * sinf(th), 0, pdir.x * sinf(th) + pdir.z * cosf(th))
            let cue = SCNVector3(ghost.x - sd.x * dist, sY + R, ghost.z - sd.z * dist)
            if abs(cue.x) < halfL - R, abs(cue.z) < halfW - R { candidates.append(cue) }
        }
        return candidates.min(by: { abs($0.z) < abs($1.z) })
    }

    // MARK: - 直接发射目标球 + 分类

    private func launchObject(start: SCNVector3, aimPoint: SCNVector3, speed: Float,
                              wUp: Float = 0, pocketIndex: Int)
        -> (potted: Bool, objCush: Int, minDist: Float, path: [SCNVector3]) {
        let dir = unit(SCNVector3(aimPoint.x - start.x, 0, aimPoint.z - start.z))
        let v = SCNVector3(dir.x * speed, 0, dir.z * speed)
        let up = SCNVector3(0, 1, 0)
        let roll = up.cross(v) * (1.0 / R)               // 自然滚动角速度
        let w = SCNVector3(roll.x, roll.y + wUp, roll.z) // 叠加竖轴英式
        let engine = EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBallQiuJi(surfaceY: sY))
        engine.setBall(BallState(position: start, velocity: v, angularVelocity: w, state: .rolling, name: "obj"))
        engine.simulate(maxEvents: 300, maxTime: 10)
        let rec = engine.getTrajectoryRecorder()

        var objPocketId: String?
        var objCush = 0
        for ev in engine.resolvedEvents {
            switch ev {
            case .ballCushion(let b, _, _) where b == "obj": if objPocketId == nil { objCush += 1 }
            case .pocket(let b, let pid) where b == "obj": if objPocketId == nil { objPocketId = pid }
            default: break
            }
        }
        var minD = Float.greatestFiniteMagnitude
        let pc = AngleSceneCalculator.pocketPositions(surfaceY: sY)[pocketIndex]
        if let frames = rec.framesByBallName["obj"] {
            for f in frames { let dx = f.position.x - pc.x, dz = f.position.z - pc.z; minD = min(minD, sqrtf(dx * dx + dz * dz)) }
        }
        return (objPocketId == "pocket_\(pocketIndex)", objCush, minD, smoothPath(rec, "obj"))
    }

    private func classify(potted: Bool, objCush: Int, minDist: Float, pocketIndex: Int) -> Outcome {
        if potted { return objCush == 0 ? .cleanPot : .jawPot }
        let drop = AngleSceneCalculator.pocketDropRadius(index: pocketIndex)
        return minDist <= drop + R ? .rattle : .short
    }

    private func smoothPath(_ rec: TrajectoryRecorder, _ name: String) -> [SCNVector3] {
        let pb = TrajectoryPlayback(recorder: rec, surfaceY: sY + R)
        let dur = rec.duration
        guard dur > 1e-4 else {
            if let s = pb.stateAt(ballName: name, time: 0) { return [s.position] }
            return []
        }
        var out: [SCNVector3] = []
        var t: Float = 0
        let dt: Float = 1.0 / 120.0
        while t <= dur + 1e-4 {
            if let s = pb.stateAt(ballName: name, time: min(t, dur)) { out.append(s.position) }
            t += dt
        }
        return out
    }

    // MARK: - 渲染

    private struct PanelXform {
        let P: (SCNVector3) -> CGPoint
        let sx: CGFloat
        let sz: CGFloat
    }

    private func tablePanel(size: CGSize, header: String, subtitle: String,
                            draw: (CGContext, PanelXform) -> Void) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 2; fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(UIColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1).cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            let headerH: CGFloat = 40
            let area = CGRect(x: 6, y: headerH, width: size.width - 12, height: size.height - headerH - 6)
            let scale = min(area.width / CGFloat(2 * xRange), area.height / CGFloat(2 * zRange))
            let plotW = scale * CGFloat(2 * xRange), plotH = scale * CGFloat(2 * zRange)
            let plot = CGRect(x: area.midX - plotW / 2, y: area.midY - plotH / 2, width: plotW, height: plotH)
            let sx = plot.width / CGFloat(2 * xRange)
            let sz = plot.height / CGFloat(2 * zRange)
            func P(_ v: SCNVector3) -> CGPoint {
                CGPoint(x: plot.minX + CGFloat(v.x + xRange) * sx, y: plot.minY + CGFloat(v.z + zRange) * sz)
            }
            drawTable(cg, plot: plot, P: P, sx: sx, sz: sz)
            draw(cg, PanelXform(P: P, sx: sx, sz: sz))
            drawText(header, at: CGPoint(x: 8, y: 6), size: 15, color: .white, bold: true)
            drawText(subtitle, at: CGPoint(x: 8, y: 23), size: 11, color: UIColor(white: 0.72, alpha: 1))
        }
    }

    private func drawTable(_ cg: CGContext, plot: CGRect, P: (SCNVector3) -> CGPoint, sx: CGFloat, sz: CGFloat) {
        cg.setFillColor(UIColor(red: 0.10, green: 0.22, blue: 0.16, alpha: 1).cgColor)
        cg.fill(plot)
        let geo = TableGeometry.chineseEightBallQiuJi(surfaceY: sY)
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: sY)
        for (i, pc) in pockets.enumerated() {
            let drop = CGFloat(AngleSceneCalculator.pocketDropRadius(index: i))
            let c = P(pc)
            cg.setFillColor(UIColor.black.withAlphaComponent(0.55).cgColor)
            cg.fillEllipse(in: CGRect(x: c.x - drop * sx, y: c.y - drop * sz, width: 2 * drop * sx, height: 2 * drop * sz))
        }
        cg.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor); cg.setLineWidth(1.0)
        for seg in geo.linearCushions { cg.beginPath(); cg.move(to: P(seg.start)); cg.addLine(to: P(seg.end)); cg.strokePath() }
        cg.setStrokeColor(UIColor.white.withAlphaComponent(0.6).cgColor); cg.setLineWidth(0.9)
        for arc in geo.circularCushions {
            var a0 = arc.startAngle, a1 = arc.endAngle
            if a1 < a0 { a1 += 2 * .pi }
            cg.beginPath()
            for k in 0...24 {
                let a = a0 + (a1 - a0) * Float(k) / 24
                let pt = P(SCNVector3(arc.center.x + arc.radius * cosf(a), sY, arc.center.z + arc.radius * sinf(a)))
                if k == 0 { cg.move(to: pt) } else { cg.addLine(to: pt) }
            }
            cg.strokePath()
        }
        cg.setStrokeColor(UIColor.white.withAlphaComponent(0.18).cgColor); cg.setLineWidth(1); cg.stroke(plot)
    }

    private func highlightPocket(_ cg: CGContext, _ xf: PanelXform, _ index: Int) {
        let pc = AngleSceneCalculator.pocketPositions(surfaceY: sY)[index]
        let drop = CGFloat(AngleSceneCalculator.pocketDropRadius(index: index))
        let c = xf.P(pc)
        cg.setStrokeColor(UIColor.systemYellow.withAlphaComponent(0.9).cgColor); cg.setLineWidth(2)
        cg.strokeEllipse(in: CGRect(x: c.x - drop * xf.sx - 2, y: c.y - drop * xf.sz - 2, width: 2 * drop * xf.sx + 4, height: 2 * drop * xf.sz + 4))
    }

    private func drawBall(_ cg: CGContext, _ xf: PanelXform, _ v: SCNVector3, _ color: UIColor) {
        let c = xf.P(v)
        let rx = CGFloat(R) * xf.sx, rz = CGFloat(R) * xf.sz
        cg.setFillColor(color.cgColor)
        cg.fillEllipse(in: CGRect(x: c.x - rx, y: c.y - rz, width: 2 * rx, height: 2 * rz))
        cg.setStrokeColor(UIColor.black.withAlphaComponent(0.6).cgColor); cg.setLineWidth(0.8)
        cg.strokeEllipse(in: CGRect(x: c.x - rx, y: c.y - rz, width: 2 * rx, height: 2 * rz))
    }

    private func strokePath(_ cg: CGContext, _ pts: [CGPoint], color: UIColor, width: CGFloat) {
        guard pts.count >= 2 else { return }
        cg.setStrokeColor(color.cgColor); cg.setLineWidth(width); cg.setLineJoin(.round)
        cg.beginPath(); cg.move(to: pts[0])
        for p in pts.dropFirst() { cg.addLine(to: p) }
        cg.strokePath()
    }

    private func drawText(_ s: String, at p: CGPoint, size: CGFloat, color: UIColor, bold: Bool = false) {
        (s as NSString).draw(at: p, withAttributes: [
            .font: bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size),
            .foregroundColor: color,
        ])
    }

    private func composeSheet(_ panels: [UIImage], cols: Int, filename: String, title: String) throws {
        guard !panels.isEmpty else { return }
        let cellW = panels[0].size.width, cellH = panels[0].size.height
        let rows = (panels.count + cols - 1) / cols
        let titleH: CGFloat = 34
        let w = cellW * CGFloat(cols)
        let h = cellH * CGFloat(rows) + titleH
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 2; fmt.opaque = true
        let img = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: fmt).image { ctx in
            ctx.cgContext.setFillColor(UIColor(red: 0.04, green: 0.05, blue: 0.06, alpha: 1).cgColor)
            ctx.cgContext.fill(CGRect(x: 0, y: 0, width: w, height: h))
            drawText(title, at: CGPoint(x: 12, y: 8), size: 18, color: .white, bold: true)
            for (i, panel) in panels.enumerated() {
                let x = CGFloat(i % cols) * cellW
                let y = titleH + CGFloat(i / cols) * cellH
                panel.draw(in: CGRect(x: x, y: y, width: cellW, height: cellH))
            }
        }
        guard let data = img.pngData() else { throw NSError(domain: "render", code: 1) }
        let path = "\(baseDir)/\(filename)"
        try data.write(to: URL(fileURLWithPath: path))
        print("WROTE \(path) (\(Int(w))x\(Int(h)))")
    }

    private func unit(_ v: SCNVector3) -> SCNVector3 {
        let len = sqrtf(v.x * v.x + v.z * v.z)
        guard len > 1e-6 else { return SCNVector3(1, 0, 0) }
        return SCNVector3(v.x / len, 0, v.z / len)
    }
}
