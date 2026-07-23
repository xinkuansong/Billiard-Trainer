//
//  BankFrozenRailDiagTests.swift
//  QiuJiTests
//
//  诊断（临时）：贴库翻袋预反射种子的实际出解率矩阵。
//  枚举贴库球位 × 母球位 × 袋口，跑 solveBank，落盘统计报告。
//

import XCTest
import SceneKit
@testable import QiuJi

final class BankFrozenRailDiagTests: XCTestCase {

    private let sY: Float = 0.80

    /// 假设验证：扎库（预反射）种子的真实最优瞄准是否落在 ±8° 搜索窗之外。
    /// 对代表盘面的预反射库序做 ±20° 宽域 bankAimScore 扫描，报告进袋 offset 分布。
    func test_frozenSeed_wideScan_dump() throws {
        let r = BallPhysics.radius
        let halfW = AngleSceneCalculator.innerWidth / 2
        let y = sY + r
        let obj = SCNVector3(0.3, y, -halfW + r)
        let cue = SCNVector3(0, y, 0)
        let deg = Float.pi / 180

        var report = "宽域扫描：贴左库 x=0.3 母球台心，预反射库序，offset ∈ [-20°,20°] 步长0.5°\n"
        for pocket in 0..<6 {
            for rails in BankShotCalculator.candidateRailSequences(maxCushions: 3) {
                var input = ShotInput(
                    cueBall: cue, targetBall: obj, pocketIndex: pocket,
                    velocity: 3.6, spinX: 0, spinY: 0, surfaceY: sY)
                input.bankRails = rails
                var probe = ShotPrediction()
                guard let ctx = ShotPredictor.prepareBankAim(input, rails: rails, into: &probe),
                      probe.bankFrozenRailSeed else { continue }
                var pottedOffsets: [Float] = []
                var o: Float = -20
                while o <= 20 {
                    let s = ShotPredictor.bankAimScore(
                        offset: o * deg, input: input, context: ctx, rails: rails)
                    if s < 0 { pottedOffsets.append(o) }
                    o += 0.5
                }
                let seq = rails.map(\.label).joined(separator: "→")
                if pottedOffsets.isEmpty {
                    // 补充：全域最优分（<100 = 命中目标球但未进袋，值≈最近距+惩罚；≥100 = 无效）
                    var best: Float = .greatestFiniteMagnitude
                    var bestOff: Float = 0
                    var oo: Float = -20
                    while oo <= 20 {
                        let s = ShotPredictor.bankAimScore(
                            offset: oo * deg, input: input, context: ctx, rails: rails)
                        if s < best { best = s; bestOff = oo }
                        oo += 0.5
                    }
                    report += "P\(pocket) [\(seq)]: 全域无进袋 最优分=\(best)@\(bestOff)°\n"
                } else {
                    let inside = pottedOffsets.filter { abs($0) <= 8 }
                    report += "P\(pocket) [\(seq)]: 进袋offsets=\(pottedOffsets) 窗内=\(inside.count)/\(pottedOffsets.count)\n"
                }
            }
        }
        let path = "/Users/song/projects/13.billiard_trainer/build/frozen-rail-logs/widescan.txt"
        try report.write(toFile: path, atomically: true, encoding: .utf8)
        print(report)
    }

    /// 标签诚实性：抽查全部「扎库」解与非扎库解，核对引擎事件里目标球首个吃库
    /// 是否为所贴库（扎库解应是；非扎库解不应是——否则文案与轨迹不一致）。
    func test_frozenSeed_labelHonesty_dump() throws {
        let r = BallPhysics.radius
        let halfW = AngleSceneCalculator.innerWidth / 2
        let y = sY + r

        var report = "标签诚实性核查（目标球首个 cushion 事件 vs 扎库标签）\n"
        var zhaTotal = 0, zhaCorrect = 0, plainTotal = 0, plainButZha = 0
        for x: Float in [-0.8, -0.3, 0.3, 0.8] {
            let obj = SCNVector3(x, y, -halfW + r)   // 贴左库（z=-halfW 侧）
            for cue in [SCNVector3(0, y, 0), SCNVector3(0.3, y, 0.3)] {
                for pocket in 0..<6 {
                    let sols = BankKickSolvePipeline.solveBank(
                        cue: cue, object: obj, pocketIndex: pocket, surfaceY: sY, power: 3.6)
                    for sol in sols {
                        // 目标球实际出发方向 ≈ 球心连线（object − 终解 ghost）。
                        // 贴左库（z=-halfW）时 dz<0 即扎向自库。
                        let g = sol.prediction.ghost
                        let dz = obj.z - g.z
                        let firstRailIsOwn: Bool? = dz < -1e-4 ? true : false
                        if sol.usedFrozenRailSeed {
                            zhaTotal += 1
                            if firstRailIsOwn == true { zhaCorrect += 1 }
                            else {
                                report += "扎库解但首库非自库: x=\(x) cue=(\(cue.x),\(cue.z)) P\(pocket) 库序[\(sol.railSequenceText)] 首库own=\(String(describing: firstRailIsOwn))\n"
                            }
                        } else {
                            plainTotal += 1
                            if firstRailIsOwn == true {
                                plainButZha += 1
                                report += "非扎库解但首库是自库: x=\(x) cue=(\(cue.x),\(cue.z)) P\(pocket) 库序[\(sol.railSequenceText)]\n"
                            }
                        }
                    }
                }
            }
        }
        report += "\n扎库解=\(zhaTotal) 其中首库确为自库=\(zhaCorrect)\n"
        report += "非扎库解=\(plainTotal) 其中首库其实是自库=\(plainButZha)\n"
        let path = "/Users/song/projects/13.billiard_trainer/build/frozen-rail-logs/honesty.txt"
        try report.write(toFile: path, atomically: true, encoding: .utf8)
        print(report)
    }

    /// 拓扑探针：对已知进袋 offset 构建全保真预测，dump 实际主库序 vs 声明库序。
    func test_topologyProbe_dump() throws {
        let r = BallPhysics.radius
        let halfW = AngleSceneCalculator.innerWidth / 2
        let y = sY + r
        let obj = SCNVector3(0.3, y, -halfW + r)
        let cue = SCNVector3(0, y, 0)
        let deg = Float.pi / 180

        var report = "拓扑探针：贴左库 x=0.3 母球台心\n"
        for pocket in 0..<6 {
            for rails in BankShotCalculator.candidateRailSequences(maxCushions: 3) {
                var input = ShotInput(
                    cueBall: cue, targetBall: obj, pocketIndex: pocket,
                    velocity: 3.6, spinX: 0, spinY: 0, surfaceY: sY)
                input.bankRails = rails
                var seedPred = ShotPrediction()
                guard let ctx = ShotPredictor.prepareBankAim(input, rails: rails, into: &seedPred)
                else { continue }
                var o: Float = -10
                while o <= 10 {
                    let s = ShotPredictor.bankAimScore(
                        offset: o * deg, input: input, context: ctx, rails: rails)
                    if s < 0 {
                        let pred = ShotPredictor.buildPrediction(
                            finalAim: ctx.aimDir.rotatedY(o * deg), context: ctx, input: input,
                            result: seedPred, maxEvents: 500, maxTime: 15,
                            includePresentation: false, searchEarlyStop: true)
                        let seq = rails.map(\.label).joined(separator: "→")
                        let actual = pred.objectRailContacts.map(\.label).joined(separator: "→")
                        let pre = seedPred.bankFrozenRailSeed
                            ? " 预反射(\(seedPred.bankFrozenRailSeedRail?.label ?? "?"))" : ""
                        report += "P\(pocket) 声明[\(seq)]\(pre) off=\(o)° potted=\(pred.simObjectPotted) 实际[\(actual)] 实测吃库=\(pred.objectCushionCount)\n"
                    }
                    o += 0.5
                }
            }
        }
        let path = "/Users/song/projects/13.billiard_trainer/build/frozen-rail-logs/topology.txt"
        try report.write(toFile: path, atomically: true, encoding: .utf8)
        print(report)
    }

    /// 定点探针：修复前存在的「扎库→右库」解（P0，塞+0.3）——预反射解的实际主库序里
    /// 首弹自库是否被记录为主库事件（拓扑校验是否过杀扎库解）。
    func test_frozenSeed_ownRailEventProbe_dump() throws {
        let r = BallPhysics.radius
        let halfW = AngleSceneCalculator.innerWidth / 2
        let y = sY + r
        let obj = SCNVector3(0.3, y, -halfW + r)
        let cue = SCNVector3(0, y, 0)
        let deg = Float.pi / 180

        var report = "定点探针：贴左库 x=0.3 母球台心 塞∈{0,±0.3} 预反射库序全袋扫描\n"
        for sx: Float in [-0.3, 0, 0.3] {
            for pocket in 0..<6 {
                for rails in BankShotCalculator.candidateRailSequences(maxCushions: 3) {
                    var input = ShotInput(
                        cueBall: cue, targetBall: obj, pocketIndex: pocket,
                        velocity: 3.6, spinX: sx, spinY: 0, surfaceY: sY)
                    input.bankRails = rails
                    var seedPred = ShotPrediction()
                    guard let ctx = ShotPredictor.prepareBankAim(input, rails: rails, into: &seedPred),
                          seedPred.bankFrozenRailSeed else { continue }
                    var o: Float = -10
                    while o <= 10 {
                        let pred = ShotPredictor.buildPrediction(
                            finalAim: ctx.aimDir.rotatedY(o * deg), context: ctx, input: input,
                            result: seedPred, maxEvents: 500, maxTime: 15,
                            includePresentation: false, searchEarlyStop: true)
                        if pred.simObjectPotted, pred.cueCushionsBeforeContact == 0 {
                            let seq = rails.map(\.label).joined(separator: "→")
                            let actual = pred.objectRailContacts.map(\.label).joined(separator: "→")
                            report += "塞\(sx) P\(pocket) 声明[\(seq)]+预反射(\(seedPred.bankFrozenRailSeedRail?.label ?? "?")) off=\(o)° 实际[\(actual)] 实测吃库=\(pred.objectCushionCount)\n"
                        }
                        o += 0.5
                    }
                }
            }
        }
        let path = "/Users/song/projects/13.billiard_trainer/build/frozen-rail-logs/ownrail.txt"
        try report.write(toFile: path, atomically: true, encoding: .utf8)
        print(report)
    }

    /// 地面真值：袋口坐标 + 问题解的出发方向/豁免判据逐项 dump。
    func test_groundTruth_pocketsAndDeparture_dump() throws {
        let r = BallPhysics.radius
        let halfW = AngleSceneCalculator.innerWidth / 2
        let halfL = AngleSceneCalculator.innerLength / 2
        let y = sY + r
        var report = "halfL=\(halfL) halfW=\(halfW)\n袋口坐标：\n"
        for (i, p) in AngleSceneCalculator.pocketPositions(surfaceY: sY).enumerated() {
            report += "P\(i): x=\(p.x) z=\(p.z)\n"
        }
        let obj = SCNVector3(0.3, y, -halfW + r)
        let cue = SCNVector3(0, y, 0)
        for pocket in [0, 2] {
            let sols = BankKickSolvePipeline.solveBank(
                cue: cue, object: obj, pocketIndex: pocket, surfaceY: sY, power: 3.6)
            for sol in sols {
                let dep = sol.prediction.objectDepartureDir
                report += "P\(pocket) [\(sol.railSequenceText)] 塞=\(sol.spinX) dep=(\(dep?.x ?? .nan), \(dep?.z ?? .nan)) actual=\(sol.prediction.objectRailContacts.map(\.label))\n"
            }
        }
        let path = "/Users/song/projects/13.billiard_trainer/build/frozen-rail-logs/groundtruth.txt"
        try report.write(toFile: path, atomically: true, encoding: .utf8)
        print(report)
    }

    /// 重复解核查：单盘面解列表逐条 dump（标签 / 库数 / 终瞄方向 / 实测吃库 / 加塞），
    /// 看「扎库→X」与「自库→X」是否同一物理解双双上屏。
    func test_frozenBoard_solutionList_dump() throws {
        let r = BallPhysics.radius
        let halfW = AngleSceneCalculator.innerWidth / 2
        let y = sY + r
        let obj = SCNVector3(0.3, y, -halfW + r)
        let cue = SCNVector3(0, y, 0)

        var report = "盘面：贴左库 x=0.3 母球台心\n"
        for pocket in 0..<6 {
            let sols = BankKickSolvePipeline.solveBank(
                cue: cue, object: obj, pocketIndex: pocket, surfaceY: sY, power: 3.6)
            guard !sols.isEmpty else { continue }
            report += "P\(pocket):\n"
            for sol in sols {
                let aim = sol.prediction.aimDirection
                let deg = atan2(aim.z, aim.x) * 180 / .pi
                report += String(
                    format: "  [%@] 库数=%d 实测吃库=%d 瞄准=%.2f° 塞=%.1f 难度=%.1f\n",
                    sol.railSequenceText, sol.cushions,
                    sol.prediction.objectCushionCount, deg, sol.spinX, sol.difficultyScore)
            }
        }
        let path = "/Users/song/projects/13.billiard_trainer/build/frozen-rail-logs/board.txt"
        try report.write(toFile: path, atomically: true, encoding: .utf8)
        print(report)
    }

    func test_frozenRailMatrix_dump() throws {
        let r = BallPhysics.radius
        let halfW = AngleSceneCalculator.innerWidth / 2
        let halfL = AngleSceneCalculator.innerLength / 2
        let y = sY + r

        // 贴左长库（Z=-halfW）多个 x 位（避开中袋口 x=0 退化位）+ 贴底短库（X=-halfL）一位。
        // 每个贴库位配一个对照位（同 x，离库 50mm）量化「贴库 vs 正常」出解率差距。
        var objects: [(String, SCNVector3)] = []
        for x: Float in [-0.8, -0.3, 0.3, 0.8] {
            objects.append(("贴左库 x=\(x)", SCNVector3(x, y, -halfW + r)))
            objects.append(("对照50mm x=\(x)", SCNVector3(x, y, -halfW + r + 0.05)))
        }
        objects.append(("贴底库 z=0", SCNVector3(-halfL + r, y, 0)))
        objects.append(("对照底50mm z=0", SCNVector3(-halfL + r + 0.05, y, 0)))
        // 近库但非贴库（15mm 气口）——现实里用户常摆到这种位置。
        objects.append(("近左库15mm x=0.3", SCNVector3(0.3, y, -halfW + r + 0.015)))

        let cues: [(String, SCNVector3)] = [
            ("台心", SCNVector3(0, y, 0)),
            ("中偏上", SCNVector3(0.3, y, 0.3)),
            ("中偏下近库", SCNVector3(-0.3, y, -0.35))
        ]

        var report = "袋序: 0左上 1右上 2左下 3右下 4上中 5下中\n"
        var frozenBoards = 0, frozenWith = 0, ctrlBoards = 0, ctrlWith = 0
        var frozenSeedSols = 0, totalSols = 0
        for (oName, obj) in objects {
            let isFrozenRow = BankShotCalculator.isFrozenToAnyRail(obj)
            for (cName, cue) in cues {
                var line = "\(oName) | 母球\(cName): "
                for pocket in 0..<6 {
                    // 复刻 App 真实路径：默认三档塞全搜（VM recompute 同口径）。
                    let sols = BankKickSolvePipeline.solveBank(
                        cue: cue, object: obj, pocketIndex: pocket,
                        surfaceY: sY, power: 3.6)
                    if isFrozenRow {
                        frozenBoards += 1
                        if !sols.isEmpty { frozenWith += 1 }
                    } else {
                        ctrlBoards += 1
                        if !sols.isEmpty { ctrlWith += 1 }
                    }
                    totalSols += sols.count
                    let fz = sols.filter(\.usedFrozenRailSeed).count
                    frozenSeedSols += fz
                    line += "P\(pocket)=\(sols.count)(扎\(fz)) "
                }
                report += line + "\n"
            }
        }
        report += "\n贴库盘面=\(frozenBoards) 有解=\(frozenWith) (\(frozenBoards > 0 ? 100 * frozenWith / frozenBoards : 0)%)\n"
        report += "对照盘面=\(ctrlBoards) 有解=\(ctrlWith) (\(ctrlBoards > 0 ? 100 * ctrlWith / ctrlBoards : 0)%)\n"
        report += "总解=\(totalSols) 扎库解=\(frozenSeedSols)\n"

        // ── 阶段归因（贴库代表盘面）：每条库序落在哪一层失败 ──
        report += "\n[阶段归因] 贴库 x=0.3 母球台心 → 各袋（库序: 种子nil/切角占位/未进袋/进袋）\n"
        let diagObj = SCNVector3(0.3, y, -halfW + r)
        let diagCue = SCNVector3(0, y, 0)
        for pocket in 0..<6 {
            var noSeed = 0, gated = 0, notPotted = 0, potted = 0
            var preUsed = 0
            for rails in BankShotCalculator.candidateRailSequences(maxCushions: 3) {
                var input = ShotInput(
                    cueBall: diagCue, targetBall: diagObj, pocketIndex: pocket,
                    velocity: 3.6, spinX: 0, spinY: 0, surfaceY: sY)
                input.bankRails = rails
                var seedProbe = ShotPrediction()
                if ShotPredictor.prepareBankAim(input, rails: rails, into: &seedProbe) == nil {
                    if seedProbe.infeasibleReason.contains("种子") { noSeed += 1 } else { gated += 1 }
                    continue
                }
                if seedProbe.bankFrozenRailSeed { preUsed += 1 }
                let pred = ShotPredictor.predict(input)
                if pred.simObjectPotted { potted += 1 } else { notPotted += 1 }
            }
            report += "P\(pocket): 无种子=\(noSeed) 切角/占位淘汰=\(gated) 预反射激活=\(preUsed) 有种子未进袋=\(notPotted) 进袋=\(potted)\n"
        }

        let path = "/Users/song/projects/13.billiard_trainer/build/frozen-rail-logs/matrix.txt"
        try report.write(toFile: path, atomically: true, encoding: .utf8)
        print(report)
    }
}
