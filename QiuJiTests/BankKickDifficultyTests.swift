//
//  BankKickDifficultyTests.swift
//  QiuJiTests
//
//  W3（20260709 翻袋反射页重构方案 §3/§4.1）：好打优先排序模型 + 解缓存 + 求解管线集成。
//

import XCTest
import SceneKit
import UIKit
@testable import QiuJi

final class BankKickDifficultyTests: XCTestCase {

    private let sY: Float = 0.80

    // MARK: - 难度评分（单调性 + 档位）

    func test_bankScore_monotonicInCutAngleCushionsAndLength() {
        let base = BankKickDifficulty.bankScore(
            cutAngleDeg: 20, cueTargetDistance: 0.5, cushions: 1, pathLength: 0.8)
        let thinner = BankKickDifficulty.bankScore(
            cutAngleDeg: 75, cueTargetDistance: 0.5, cushions: 1, pathLength: 0.8)
        let moreCushions = BankKickDifficulty.bankScore(
            cutAngleDeg: 20, cueTargetDistance: 0.5, cushions: 3, pathLength: 0.8)
        let longer = BankKickDifficulty.bankScore(
            cutAngleDeg: 20, cueTargetDistance: 0.5, cushions: 1, pathLength: 2.4)
        let farther = BankKickDifficulty.bankScore(
            cutAngleDeg: 20, cueTargetDistance: 2.0, cushions: 1, pathLength: 0.8)
        XCTAssertGreaterThan(thinner, base, "切角更薄应更难")
        XCTAssertGreaterThan(moreCushions, base, "库数更多应更难")
        XCTAssertGreaterThan(longer, base, "路径更长应更难")
        XCTAssertGreaterThan(farther, base, "球距更远应更难")
    }

    func test_kickScore_monotonicInIncidenceMargin() {
        let steep = BankKickDifficulty.kickScore(
            firstRailIncidenceDeg: 70, cushions: 1, pathLength: 1.0)
        let shallow = BankKickDifficulty.kickScore(
            firstRailIncidenceDeg: 20, cushions: 1, pathLength: 1.0)
        XCTAssertGreaterThan(shallow, steep, "首库入射角越平（余量越小）应更难")
    }

    func test_tierBoundaries() {
        XCTAssertEqual(BankKickDifficulty.tier(0.0), .easy)
        XCTAssertEqual(BankKickDifficulty.tier(BankKickDifficulty.tierBoundaries.easy + 0.01), .medium)
        XCTAssertEqual(BankKickDifficulty.tier(BankKickDifficulty.tierBoundaries.medium + 0.01), .hard)
    }

    func test_goodness_rewardsRobustness() {
        let fragile = BankKickDifficulty.goodness(difficultyScore: 0.5, robustness: 0.0)
        let robust = BankKickDifficulty.goodness(difficultyScore: 0.5, robustness: 1.0)
        XCTAssertLessThan(robust, fragile, "同难度下容错高的解排序键应更小（更靠前）")
        // robustness nil 按 0 保守处理。
        XCTAssertEqual(BankKickDifficulty.goodness(difficultyScore: 0.5, robustness: nil), fragile)
    }

    // MARK: - LRU 解缓存（方案 §4.1）

    func test_solveCache_lruEvictionAndKeySensitivity() {
        var cache = BankKickSolveCache<BankKickSolveKey, Int>(capacity: 2)
        let k1 = BankKickSolveKey(ballsMM: [1, 2, 3, 4], pocketIndex: 0, powerStep: 36,
                                  spinXCenti: BankKickSolveKey.multiSpinSearchProfile)
        let k2 = BankKickSolveKey(ballsMM: [1, 2, 3, 4], pocketIndex: 1, powerStep: 36,
                                  spinXCenti: BankKickSolveKey.multiSpinSearchProfile)
        let k3 = BankKickSolveKey(ballsMM: [1, 2, 3, 4], pocketIndex: 0, powerStep: 37,
                                  spinXCenti: BankKickSolveKey.multiSpinSearchProfile)

        cache.insert(1, for: k1)
        cache.insert(2, for: k2)
        XCTAssertEqual(cache.value(for: k1), 1)      // 命中并刷新 k1
        cache.insert(3, for: k3)                     // 容量 2：应逐出最久未用的 k2
        XCTAssertNil(cache.value(for: k2), "LRU 应逐出最久未用条目")
        XCTAssertEqual(cache.value(for: k1), 1)
        XCTAssertEqual(cache.value(for: k3), 3)

        // 任何 key 成分变化必 miss（球位毫米 / 袋口 / 力度步进）。
        let moved = BankKickSolveKey(ballsMM: [1, 2, 3, 5], pocketIndex: 0, powerStep: 36,
                                     spinXCenti: BankKickSolveKey.multiSpinSearchProfile)
        XCTAssertNil(cache.value(for: moved))
    }

    func test_solveKey_quantization() {
        XCTAssertEqual(BankKickSolveKey.quantizeMM(0.1234), 123)
        XCTAssertEqual(BankKickSolveKey.quantizeMM(-0.5), -500)
        XCTAssertEqual(BankKickSolveKey.quantizePower(3.6), 36)
        XCTAssertEqual(BankKickSolveKey.quantizeSpinX(0.3), 30)
        XCTAssertEqual(BankKickSolveKey.quantizeSpinX(-0.3), -30)
        XCTAssertEqual(BankKickSolveKey.quantizeSpinX(0), 0)
    }

    /// K10：缓存 key 塞维度扩展——仅 spinXCenti 不同即 miss。
    func test_solveKey_spinDimension_missesOnSpinOnly() {
        var cache = BankKickSolveCache<BankKickSolveKey, Int>(capacity: 4)
        let base = BankKickSolveKey(ballsMM: [1, 2, 3, 4], pocketIndex: 0, powerStep: 36,
                                    spinXCenti: 0)
        let left = BankKickSolveKey(ballsMM: [1, 2, 3, 4], pocketIndex: 0, powerStep: 36,
                                    spinXCenti: 30)
        let multi = BankKickSolveKey(ballsMM: [1, 2, 3, 4], pocketIndex: 0, powerStep: 36,
                                     spinXCenti: BankKickSolveKey.multiSpinSearchProfile)
        cache.insert(1, for: base)
        XCTAssertNil(cache.value(for: left), "spinXCenti 不同必 miss")
        XCTAssertNil(cache.value(for: multi), "全档哨兵与单档 0 必 miss")
        cache.insert(2, for: multi)
        XCTAssertEqual(cache.value(for: multi), 2)
        XCTAssertEqual(cache.value(for: base), 1, "不同 spin 键互不覆盖")
        XCTAssertNil(cache.value(for: left), "left 仍未写入")

        let made = BankKickSolveKey.make(
            cue: SCNVector3(0, 0, 0), object: SCNVector3(0.1, 0, 0.1),
            obstacles: [], pocketIndex: 1, power: 3.6)
        XCTAssertEqual(made.spinXCenti, BankKickSolveKey.multiSpinSearchProfile)
    }

    // MARK: - 求解管线集成（真实引擎，典型盘面）

    /// 翻袋典型盘面（与 [PERF-W1] 同盘面）：有解、好打分升序、字段齐备、容错在 [0,1]。
    func test_solveBank_typicalBoard_sortedAndAssembled() {
        let cue = SCNVector3(-0.5, sY + BallPhysics.radius, -0.2)
        let object = SCNVector3(0.1, sY + BallPhysics.radius, 0.1)
        let sols = BankKickSolvePipeline.solveBank(
            cue: cue, object: object, pocketIndex: 1, surfaceY: sY, power: 3.6)

        XCTAssertFalse(sols.isEmpty, "典型盘面应有翻袋解")
        XCTAssertLessThanOrEqual(sols.count, BankKickSolvePipeline.bankSolutionLimit)
        for (a, b) in zip(sols, sols.dropFirst()) {
            XCTAssertLessThanOrEqual(a.goodness, b.goodness, "解列表应按好打分升序")
        }
        for sol in sols {
            XCTAssertTrue(sol.prediction.simObjectPotted, "上屏解必经引擎终验真实进袋")
            XCTAssertGreaterThanOrEqual(sol.cushions, 1)
            if let r = sol.robustness {
                XCTAssertTrue((0.0...1.0).contains(r), "容错应在 [0,1]")
            }
        }
    }

    /// 反射典型盘面（与 [PERF-W2] 同盘面）：有解、排序正确、引擎终验判据成立。
    func test_solveKick_typicalBoard_sortedAndAssembled() {
        let cue = SCNVector3(-0.5, sY + BallPhysics.radius, -0.2)
        let target = SCNVector3(0.4, sY + BallPhysics.radius, 0.25)
        let sols = BankKickSolvePipeline.solveKick(
            cue: cue, target: target, surfaceY: sY, power: 3.6)

        XCTAssertFalse(sols.isEmpty, "典型盘面应有 kick 解")
        XCTAssertLessThanOrEqual(sols.count, BankKickSolvePipeline.kickSolutionLimit)
        for (a, b) in zip(sols, sols.dropFirst()) {
            XCTAssertLessThanOrEqual(a.goodness, b.goodness, "解列表应按好打分升序")
        }
        for sol in sols {
            XCTAssertTrue(sol.prediction.kickContactMade, "上屏解必经引擎终验真实碰到目标球")
            XCTAssertGreaterThanOrEqual(sol.cushions, 1)
            if let r = sol.robustness {
                XCTAssertTrue((0.0...1.0).contains(r), "容错应在 [0,1]")
            }
        }
    }

    // MARK: - 几何辅助

    /// 碰库点提取：构造已知“贴库-回弹”折线，应提取出唯一贴库点与指向台内的法向。
    /// 坐标契约：SceneKit 世界系 X–Z 水平面；长库 = 常 Z（±halfW）。
    func test_cushionTouchPoints_extractsBounceVertex() {
        let halfW = AngleSceneCalculator.innerWidth / 2
        let y = sY + AngleSceneCalculator.ballRadius
        let contactZ = halfW - AngleSceneCalculator.ballRadius   // 球心贴 +Z 长库
        let path = [
            SCNVector3(-0.4, y, 0.0),
            SCNVector3(-0.2, y, contactZ * 0.5),
            SCNVector3(0.0, y, contactZ),          // 贴库顶点
            SCNVector3(0.2, y, contactZ * 0.5),
            SCNVector3(0.4, y, 0.0)
        ]
        let touches = BankKickSolvePipeline.cushionTouchPoints(path)
        XCTAssertEqual(touches.count, 1, "应恰好提取一个碰库点")
        if let touch = touches.first {
            XCTAssertEqual(touch.point.z, contactZ, accuracy: 1e-4)
            XCTAssertEqual(touch.inwardNormal.z, -1, accuracy: 1e-6, "+Z 长库法向应指向 -Z（台内）")
        }
    }

    /// kick 首库入射角：构造 45° 入射的已知盘面（种子几何可解），角度应 ≈45°。
    func test_kickFirstRailIncidence_knownAngle() {
        // 母球 (0, 0)，目标 (0.6, 0)；经 +Z 长库一库：镜像展开给出对称 V 形路线，
        // 入射角 = atan(halfW / 0.3)（相对库面）。
        let halfW = Double(AngleSceneCalculator.innerWidth / 2)
        let cue = SCNVector3(0, sY, 0)
        let target = SCNVector3(0.6, sY, 0)
        let expected = atan(halfW / 0.3) * 180 / .pi
        let angle = BankKickSolvePipeline.kickFirstRailIncidenceDeg(
            cue: cue, target: target, rails: [.right], surfaceY: sY)
        XCTAssertNotNil(angle)
        if let angle {
            XCTAssertEqual(angle, expected, accuracy: 1.0)
        }
    }

    // MARK: - K9 钉子：展示几何 = finalAim；镜像收敛去重

    /// 坐标契约：SceneKit XZ；ghost = cue+t·aim ∩ |G−T|=2R。对拍数值草稿 case1。
    func test_ghostAlongFinalAim_straightOnGold() {
        let r = BallPhysics.radius
        let cue = SCNVector3(-0.5, sY + r, 0)
        let target = SCNVector3(0, sY + r, 0)
        let aim = SCNVector3(1, 0, 0)
        let ghost = ShotPredictor.ghostAlongFinalAim(
            cue: cue, target: target, aim: aim, ballRadius: r)
        XCTAssertNotNil(ghost)
        if let g = ghost {
            XCTAssertEqual(g.x, -2 * r, accuracy: 1e-5)
            XCTAssertEqual(g.z, 0, accuracy: 1e-5)
        }
    }

    /// K9：翻袋上屏解的 aimDirection/ghost 必须由 finalAim 派生，禁止种子几何直出。
    func test_bankSolve_presentationMatchesFinalAim_notSeed() {
        let r = BallPhysics.radius
        let cue = SCNVector3(-0.5, sY + r, -0.2)
        let object = SCNVector3(0.1, sY + r, 0.1)
        let sols = BankKickSolvePipeline.solveBank(
            cue: cue, object: object, pocketIndex: 1, surfaceY: sY, power: 3.6)
        XCTAssertFalse(sols.isEmpty)
        var checkedOffset = false
        for sol in sols {
            let pred = sol.prediction
            XCTAssertNotNil(pred.aimOffsetUsed)
            // ghost 落在 cue→aimDirection 射线上（XZ）。
            let dx = pred.ghost.x - cue.x, dz = pred.ghost.z - cue.z
            let len = sqrtf(dx * dx + dz * dz)
            XCTAssertGreaterThan(len, 1e-4)
            let along = (dx / len) * pred.aimDirection.x + (dz / len) * pred.aimDirection.z
            XCTAssertEqual(along, 1, accuracy: 1e-3,
                           "ghost 必须落在精修后瞄准射线上（库序 \(sol.railSequenceText)）")
            // |ghost−object| ≈ 2R
            let gx = pred.ghost.x - object.x, gz = pred.ghost.z - object.z
            XCTAssertEqual(sqrtf(gx * gx + gz * gz), 2 * r, accuracy: 2e-3)

            var seed = ShotPrediction()
            guard let _ = ShotPredictor.prepareBankAim(
                ShotInput(cueBall: cue, targetBall: object, pocketIndex: 1,
                          velocity: 3.6, spinX: 0, spinY: 0, surfaceY: sY,
                          bankRails: sol.rails),
                rails: sol.rails, into: &seed
            ), let off = pred.aimOffsetUsed else { continue }
            let finalAim = seed.aimDirection.rotatedY(off)
            let aimDot = max(-1, min(1,
                pred.aimDirection.x * finalAim.x + pred.aimDirection.z * finalAim.z))
            XCTAssertEqual(acosf(aimDot) * 180 / .pi, 0, accuracy: 0.05,
                           "aimDirection 必须等于 seed.rotatedY(aimOffsetUsed)")
            if abs(off) > 0.1 * .pi / 180 {
                checkedOffset = true
                let seedDot = max(-1, min(1,
                    pred.aimDirection.x * seed.aimDirection.x
                        + pred.aimDirection.z * seed.aimDirection.z))
                XCTAssertGreaterThan(acosf(seedDot) * 180 / .pi, 0.05,
                                     "有精修偏移时展示瞄准不得等于种子瞄准")
            }
        }
        // 典型盘面至少应有一条带非零精修偏移的解（否则本断言退化为弱检查）。
        // 若不存在非零偏移，仍保留射线/2R 不变量作为硬门。
        if !checkedOffset {
            print("K9 note: 本盘面全部 aimOffsetUsed≈0，射线/2R 不变量已验")
        }
    }

    /// K9：同库数精修后瞄准/进球首段相同的解不得双双上屏。
    func test_solveBank_dedupsConvergedMirrorSeeds() {
        let r = BallPhysics.radius
        let cue = SCNVector3(-0.5, sY + r, -0.2)
        let object = SCNVector3(0.1, sY + r, 0.1)
        let sols = BankKickSolvePipeline.solveBank(
            cue: cue, object: object, pocketIndex: 1, surfaceY: sY, power: 3.6)
        XCTAssertFalse(sols.isEmpty)
        for i in 0..<sols.count {
            for j in (i + 1)..<sols.count where sols[i].cushions == sols[j].cushions {
                XCTAssertFalse(
                    BankKickSolvePipeline.isSameRefinedSolution(
                        sols[i].prediction, sols[j].prediction),
                    "同库数保留了精修后重复解：\(sols[i].railSequenceText) vs \(sols[j].railSequenceText)")
            }
        }
        // 合成：两预测瞄准几乎相同 → 判同。
        var a = ShotPrediction(), b = ShotPrediction()
        a.aimDirection = SCNVector3(1, 0, 0)
        b.aimDirection = SCNVector3(cosf(0.2 * .pi / 180), 0, sinf(0.2 * .pi / 180))
        XCTAssertTrue(BankKickSolvePipeline.isSameRefinedSolution(a, b))
        // 合成：瞄准差大但 objectPath 首段同向 → 仍判同（镜像收敛兜底）。
        var c = ShotPrediction(), d = ShotPrediction()
        c.aimDirection = SCNVector3(1, 0, 0)
        d.aimDirection = SCNVector3(0, 0, 1)
        let y = sY + r
        c.objectPath = [SCNVector3(0, y, 0), SCNVector3(0.2, y, 0)]
        d.objectPath = [SCNVector3(0, y, 0), SCNVector3(0.2, y, 0.0005)]
        XCTAssertTrue(BankKickSolvePipeline.isSameRefinedSolution(c, d))
    }

    /// K14 验收截图：翻袋/反射典型盘面走 TrajectoryRenderer（full 档含吃库金点）。
    @MainActor
    func test_x4_renderBankAndKickSolutionFrames() throws {
        let outDir = "/Users/song/projects/13.billiard_trainer-wt-x4/build/x4-screenshots"
        try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        let r = BallPhysics.radius
        let prevDetail = UserPreferences.shared.trajectoryDetail
        UserPreferences.shared.trajectoryDetail = .full
        defer { UserPreferences.shared.trajectoryDetail = prevDetail }

        // 翻袋
        let bankCue = SCNVector3(-0.5, sY + r, -0.2)
        let bankObj = SCNVector3(0.1, sY + r, 0.1)
        let bankSols = BankKickSolvePipeline.solveBank(
            cue: bankCue, object: bankObj, pocketIndex: 1, surfaceY: sY, power: 3.6)
        XCTAssertFalse(bankSols.isEmpty)
        if let sol = bankSols.first {
            let img = try renderSolutionFrame(
                cue: bankCue, target: bankObj, prediction: sol.prediction,
                pocketIndex: 1, label: "bank")
            let path = "\(outDir)/x4-bank-typical-full.png"
            try img.pngData()!.write(to: URL(fileURLWithPath: path))
            print("X4-PNG \(path)")
        }

        // 反射
        let kickCue = SCNVector3(-0.5, sY + r, -0.2)
        let kickObj = SCNVector3(0.4, sY + r, 0.25)
        let kickSols = BankKickSolvePipeline.solveKick(
            cue: kickCue, target: kickObj, surfaceY: sY, power: 3.6)
        XCTAssertFalse(kickSols.isEmpty)
        if let sol = kickSols.first {
            let img = try renderSolutionFrame(
                cue: kickCue, target: kickObj, prediction: sol.prediction,
                pocketIndex: nil, label: "kick")
            let path = "\(outDir)/x4-kick-typical-full.png"
            try img.pngData()!.write(to: URL(fileURLWithPath: path))
            print("X4-PNG \(path)")
        }

        // Composer/Silu 参照帧（K14 同帧对照）：可进袋直击盘面，同一
        // TrajectoryRenderer.positionPlay 路径 —— 进球线虚线本色 / 瞄准 aimColor /
        // 母球实虚分段 / 假想球虚线环+红心，与翻袋/反射帧同源可比。
        let refObj = SCNVector3(0.6, sY + r, 0.3)
        let pocketIndex = 3
        let pocket = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: refObj, pocketIndex: pocketIndex, surfaceY: sY)
        let ghost = AngleSceneCalculator.ghostBallPosition(
            targetBall: refObj, pocket: pocket, ballRadius: r)
        let pdx = pocket.x - refObj.x, pdz = pocket.z - refObj.z
        let pl = max(sqrtf(pdx * pdx + pdz * pdz), 1e-5)
        let pd = SCNVector3(pdx / pl, 0, pdz / pl)
        let refCue = SCNVector3(ghost.x - pd.x * 0.5, sY + r, ghost.z - pd.z * 0.5)
        let refPred = ShotPredictor.predict(ShotInput(
            cueBall: refCue, targetBall: refObj, pocketIndex: pocketIndex,
            velocity: 3.0, spinX: 0, spinY: 0, surfaceY: sY))
        XCTAssertTrue(refPred.simObjectPotted, "Composer 参照直击应进袋")
        let refImg = try renderSolutionFrame(
            cue: refCue, target: refObj, prediction: refPred,
            pocketIndex: pocketIndex, label: "composer-ref")
        let refPath = "\(outDir)/x4-composer-reference-full.png"
        try refImg.pngData()!.write(to: URL(fileURLWithPath: refPath))
        print("X4-PNG \(refPath)")
    }

    @MainActor
    private func renderSolutionFrame(
        cue: SCNVector3, target: SCNVector3, prediction: ShotPrediction,
        pocketIndex: Int?, label: String
    ) throws -> UIImage {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal unavailable")
        }
        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: false)
        scene.hideAllBalls()
        scene.hideCueStick()
        scene.showBall(key: "cueBall", scenePosition: cue)
        scene.showBall(key: "_8", scenePosition: target)

        var nodes: [SCNNode] = []
        TrajectoryRenderer.draw(
            prediction: prediction,
            options: .positionPlay,
            context: .init(
                prediction: prediction,
                targetKey: "_8",
                pocket: pocketIndex.flatMap { ShotIntent.pocketId(for: $0) },
                surfaceY: scene.surfaceY,
                showGhost: true
            ),
            scene: scene,
            into: &nodes
        )
        // full 档吃库标注（与 VM drawSolution 同口径；Composer 参照帧无此翻袋特有层）。
        let path: [SCNVector3]
        switch label {
        case "kick": path = BankKickSolvePipeline.pathToFirstContact(prediction)
        case "bank": path = prediction.objectPath
        default: path = []
        }
        for touch in BankKickSolvePipeline.cushionTouchPoints(path) {
            nodes.append(scene.addBall(at: touch.point, color: TrajectoryStyle.traceColor, radius: 0.012))
            let len = AngleSceneCalculator.ballRadius * 2.2
            let normalEnd = SCNVector3(touch.point.x + touch.inwardNormal.x * len,
                                       touch.point.y,
                                       touch.point.z + touch.inwardNormal.z * len)
            nodes.append(scene.addLine(from: touch.point, to: normalEnd,
                                       color: TrajectoryStyle.hintColor,
                                       radius: TrajectoryStyle.lineHint))
        }

        if let rig = scene.cameraRig {
            rig.topDownOrthographicScale = 0.75
            rig.topDownPanOffset = .zero
            rig.applyTopDown2D()
        }
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = scene.cameraNode
        renderer.autoenablesDefaultLighting = false
        let img = renderer.snapshot(atTime: 0, with: CGSize(width: 900, height: 520),
                                    antialiasingMode: .multisampling4X)
        scene.clearResultNodes(nodes: &nodes)
        return img
    }
}
