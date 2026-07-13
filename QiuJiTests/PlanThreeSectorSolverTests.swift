//
//  PlanThreeSectorSolverTests.swift
//  QiuJiTests
//
//  问题集合 v5 · V7（Q15.1 扇形默认选区 + Q15.2 <3 球终局）：
//  - 环形扇区 SDF 金标准（内部/外部/弧边界/角边界，含 Python 数值草稿手算对照）；
//  - `PlanThreeSectorSolver.defaultRegion` 真实几何（顶点=②假想球、半径带、角区间）；
//  - 扇形默认落区接入求解：满足约束的解停点确在扇形真实几何内（不外接矩形近似）；
//  - <3 球 pot-only 降级：1 目标球时 currentConstraint 非空、求得进袋解、清台终局。
//
//  坐标契约（代码真源 `AngleSceneCalculator`）：SceneKit 水平面 X–Z、Y 朝上、单位米；
//  bearing = atan2(z, x)（与 rotatedAim/bearingDeg 同口径）。扇形半径带用米（sMin/sMax 物理停球距离）。
//

import XCTest
import SceneKit
@testable import QiuJi

final class PlanThreeSectorSolverTests: XCTestCase {

    private let sY = BTTablePhysics.surfaceY

    /// 测试用粗网格（提速）。
    private var coarse: PositionPlaySolver.SearchParams {
        PositionPlaySolver.SearchParams(
            spinXValues: [-0.3, 0, 0.3],
            spinYValues: [-0.3, 0, 0.3],
            velocityMin: 1.0, velocityMax: 5.0, velocityStep: 1.0,
            marginBase: 0.0, marginPerCushion: 0.04,
            passTolerance: 2 * AngleSceneCalculator.ballRadius, passMinSpeed: 0.2)
    }

    // apex 归一化 (0.5,0.25) → 场景 (0,0)（便于金标准手算）。
    private var apexNorm: CanvasPoint { CanvasPoint(x: 0.5, y: 0.25) }
    private func P(_ r: Float, _ angDeg: Float) -> SCNVector3 {
        let a = angDeg * .pi / 180
        return SCNVector3(r * cosf(a), sY, r * sinf(a))
    }

    // MARK: - 环形扇区 SDF 金标准（Python 数值草稿对照 /tmp/sector_sdf.py，误差 ~1e-8）

    /// 单侧扇区：apex=场景原点、半径带 [0.11,0.55]m、角区间 [−175°,−160°]（15° 张角，中轴 −167.5°）。
    func test_sector_signedDistance_goldenSamples() {
        let loDeg: Float = -175, hiDeg: Float = -160
        let region = SolveRegion.sector(
            apex: apexNorm, radiusMin: 0.11, radiusMax: 0.55,
            intervals: [SolveRegion.SectorAngleInterval(
                lo: Double(loDeg * .pi / 180), hi: Double(hiDeg * .pi / 180))])
        XCTAssertTrue(region.isSector)
        let mid: Float = -167.5

        func sdf(_ p: SCNVector3) -> Float { region.signedDistanceMeters(fromScene: p, surfaceY: sY) }

        // 内部（中轴 r=0.33）：signed = −min(0.33−0.11, 0.55−0.33, 0.33·sin(7.5°)) = −0.043074（手算）。
        XCTAssertEqual(sdf(P(0.33, mid)), -0.043074, accuracy: 1e-4)
        // 内部近内弧（r=0.12）：signed = −(0.12−0.11) = −0.01。
        XCTAssertEqual(sdf(P(0.12, mid)), -0.01, accuracy: 1e-4)
        // 内部近外弧（r=0.54）：signed = −(0.55−0.54) = −0.01。
        XCTAssertEqual(sdf(P(0.54, mid)), -0.01, accuracy: 1e-4)
        // 内孔（r=0.05<rMin，角内）：signed = +(0.11−0.05) = +0.06。
        XCTAssertEqual(sdf(P(0.05, mid)), 0.06, accuracy: 1e-4)
        // 外圈（r=0.70>rMax，角内）：signed = +(0.70−0.55) = +0.15。
        XCTAssertEqual(sdf(P(0.70, mid)), 0.15, accuracy: 1e-4)
        // 角外（r=0.33，偏中轴 +30°，落在角区间外）：signed = +0.126289（Python 草稿）。
        XCTAssertEqual(sdf(P(0.33, mid + 30)), 0.126289, accuracy: 1e-4)
        // 弧边界：内/外弧上 signed ≈ 0。
        XCTAssertEqual(sdf(P(0.11, mid)), 0, accuracy: 1e-4)
        XCTAssertEqual(sdf(P(0.55, mid)), 0, accuracy: 1e-4)
        // 角边界：径向边（θ=lo，r=0.3）上 signed ≈ 0。
        XCTAssertEqual(sdf(P(0.30, loDeg)), 0, accuracy: 1e-3)
        // contains 语义。
        XCTAssertTrue(region.contains(scene: P(0.33, mid), surfaceY: sY))
        XCTAssertFalse(region.contains(scene: P(0.33, mid + 30), surfaceY: sY))
        XCTAssertFalse(region.contains(scene: P(0.70, mid), surfaceY: sY))
    }

    /// 两侧扇区并集（无③号，intervals.count==2）：两侧对称，SDF 取并集（min），落一侧即在区内。
    func test_sector_twoSide_unionMin() {
        let base: Float = 200   // 任取一个基方向 bearing（度）
        let cmin: Float = 5, cmax: Float = 20
        func iv(_ sign: Float) -> SolveRegion.SectorAngleInterval {
            let a = (base + sign * cmin) * .pi / 180, b = (base + sign * cmax) * .pi / 180
            return SolveRegion.SectorAngleInterval(lo: Double(min(a, b)), hi: Double(max(a, b)))
        }
        let region = SolveRegion.sector(
            apex: apexNorm, radiusMin: 0.11, radiusMax: 0.55, intervals: [iv(1), iv(-1)])
        // +侧中轴（base+12.5°）、−侧中轴（base−12.5°）均应在区内。
        XCTAssertTrue(region.contains(scene: P(0.33, base + 12.5), surfaceY: sY), "+侧应在区内")
        XCTAssertTrue(region.contains(scene: P(0.33, base - 12.5), surfaceY: sY), "−侧应在区内")
        // 两侧之间的正中（base 方向，θ=0<cutMin）应在区外（扇形不含 <5° 死区）。
        XCTAssertFalse(region.contains(scene: P(0.33, base), surfaceY: sY), "中间死区应在区外")
    }

    // MARK: - defaultRegion 真实几何

    /// ②号球 (0.3,0.3)、aim2 沿 +Z（进上库方向），无③号 ⇒ 顶点=②假想球、两侧角区间、半径带 [sMin,sMax]。
    func test_defaultRegion_geometry_apexAndIntervals() {
        let r = AngleSceneCalculator.ballRadius
        let t2 = SCNVector3(0.3, sY, 0.3)
        let aim2 = SCNVector3(0.3, sY, 0.635)   // u = (0,+1)
        guard let region = PlanThreeSectorSolver.defaultRegion(
            ball2: t2, aim2: aim2, ball3: nil, surfaceY: sY) else {
            return XCTFail("defaultRegion 应产出扇形")
        }
        guard case let .sector(apex, rMin, rMax, intervals) = region else {
            return XCTFail("应为 .sector")
        }
        // 顶点 = t2 − 2R·u = (0.3, 0.3 − 2R)。经归一化往返核对。
        let apexScene = AngleSceneCalculator.normalizedToScene(
            point: CGPoint(x: apex.x, y: apex.y), surfaceY: sY)
        XCTAssertEqual(apexScene.x, 0.3, accuracy: 1e-4)
        XCTAssertEqual(apexScene.z, 0.3 - 2 * r, accuracy: 1e-4)
        // 半径带 = [sMin, sMax]（米）。
        XCTAssertEqual(Float(rMin), PlanThreeSectorSolver.sMin, accuracy: 1e-6)
        XCTAssertEqual(Float(rMax), PlanThreeSectorSolver.sMax, accuracy: 1e-6)
        // 无③ ⇒ 两侧两个角区间，各 15° 张角。
        XCTAssertEqual(intervals.count, 2)
        for iv in intervals {
            XCTAssertEqual(Float(iv.hi - iv.lo), (20 - 5) * .pi / 180, accuracy: 1e-5)
        }
        // 有③号 ⇒ 单侧一个角区间。
        let t3 = SCNVector3(0.9, sY, 0.3)
        guard case let .sector(_, _, _, one) = PlanThreeSectorSolver.defaultRegion(
            ball2: t2, aim2: aim2, ball3: t3, surfaceY: sY)! else {
            return XCTFail("应为 .sector")
        }
        XCTAssertEqual(one.count, 1, "有③号应收缩到单侧")
    }

    // MARK: - 扇形默认落区接入求解（DoD #2：解落点在扇形真实几何内）

    /// 无自选约束、扇形为默认落区：求解可行，且**满足约束的解**停点确在扇形真实几何内
    /// （不外接矩形近似——直接用扇形 SDF 判定）。
    func test_sectorRegion_satisfiedSolutionsRestInsideSector() {
        // 构造一盘：cue 下方、① 上方、上中袋直球进①；② 决定扇形。
        let cue = CanvasPoint(x: 0.5, y: 0.36)
        let b1 = CanvasPoint(x: 0.5, y: 0.16)
        let b2 = CanvasPoint(x: 0.30, y: 0.30)
        let before = BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: cue, "_1": b1, "_2": b2])

        // ②袋 = 左上角袋（index 0）；扇形几何真源同 VM 路径。
        let pocket2Index = 0
        let t2 = PositionPlaySolver.scenePoint(b2, surfaceY: sY)
        let aim2 = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: t2, pocketIndex: pocket2Index, surfaceY: sY)
        guard let region = PlanThreeSectorSolver.defaultRegion(
            ball2: t2, aim2: aim2, ball3: nil, surfaceY: sY) else {
            return XCTFail("扇形默认落区应产出")
        }

        let sols = PositionPlaySolver.solve(
            before: before, targetKey: "_1", pocket: "topCenter",
            constraint: .restRegion(region), surfaceY: sY, params: coarse)
        XCTAssertFalse(sols.isEmpty, "扇形默认落区应可求解（至少降级解）")

        // 不变量（DoD #2 核心）：任何标注满足约束的解，其母球停点必在扇形真实几何内
        //（不外接矩形近似——直接用扇形 SDF 判定）。"存在满足解" 依赖具体盘面物理，
        // 用真机求解截图取证（见 V7 执行结论），此处只钉死数学不变量。
        for s in sols where s.satisfiesConstraint {
            XCTAssertTrue(s.potted, "满足约束解必进①（硬约束）")
            guard let stop = s.prediction.finalPositions[ShotInput.cueBallName] else {
                return XCTFail("满足约束解应有母球停点")
            }
            XCTAssertTrue(region.contains(scene: stop, surfaceY: sY),
                          "满足约束解停点应在扇形真实几何内（signed=\(region.signedDistanceMeters(fromScene: stop, surfaceY: sY))）")
        }
    }

    // MARK: - <3 球 pot-only 降级（Q15.2）

    /// 台面仅 1 目标球：VM 无自选约束/无② ⇒ currentConstraint 走 pot-only（全台面落区），
    /// 可求得进袋解；清台后终局提示出现。
    @MainActor
    func test_potOnly_singleObjectBall_solvableAndEndgamePrompt() {
        let vm = PlanThreeViewModel()
        vm.setupScene()
        // 只留母球 + _1。
        vm.loadBoard(BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.5, y: 0.36),
            "_1": CanvasPoint(x: 0.5, y: 0.16)]))
        XCTAssertEqual(vm.objectBallCount, 1)

        // 指派 ①=_1 + ①袋（上中袋 index 5）。
        vm.armRole(.ball1)
        if let node = vm.scene.allBallNodes["_1"] { vm.selectBall(node: node) }
        vm.armRole(.pocket1)
        vm.selectPocket(at: 5)

        XCTAssertNil(vm.sectorRegion, "无②球 ⇒ 无扇形")
        XCTAssertTrue(vm.canPotOnly, "1 目标球应走 pot-only")
        XCTAssertTrue(vm.canSolve, "pot-only 下应可求解")
        guard let c = vm.currentConstraint(), case .restRegion = c else {
            return XCTFail("pot-only 应给全台面落区约束")
        }

        // 直接用求解器验证「只打进」可行（VM.solve 走 .standard 较慢，这里等价用 coarse 直解）。
        let sols = PositionPlaySolver.solve(
            before: vm.currentSnapshot(), targetKey: "_1", pocket: "topCenter",
            constraint: c, surfaceY: sY, params: coarse)
        XCTAssertFalse(sols.isEmpty, "1 球 pot-only 应求得进袋解")
        XCTAssertTrue(sols.contains { $0.potted }, "应至少一个进袋解")

        // 终局提示：打进最后一颗目标球（母球留台）后台面无目标球 ⇒ hint 给清台文案。
        vm.removeFromTable("_1")
        XCTAssertEqual(vm.objectBallCount, 0)
        XCTAssertFalse(vm.scene.allBallNodes[PositionPlayBall.cueKey]?.isHidden ?? true, "母球应仍在台")
        XCTAssertTrue(vm.hintForState().contains("清台"), "无目标球（母球留台）应出终局提示")
    }

    // MARK: - 扇形默认 / 自选降级 / 删除恢复 状态机（Q15.1）

    @MainActor
    func test_sectorDefault_dimmedByDraft_restoredOnClear() {
        let vm = PlanThreeViewModel()
        vm.setupScene()
        vm.loadBoard(BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.24, y: 0.30),
            "_1": CanvasPoint(x: 0.52, y: 0.16),
            "_2": CanvasPoint(x: 0.70, y: 0.34)]))
        // 指派 ①球/①袋/②球/②袋。
        vm.armRole(.ball1); if let n = vm.scene.allBallNodes["_1"] { vm.selectBall(node: n) }
        vm.armRole(.pocket1); vm.selectPocket(at: 3)
        vm.armRole(.ball2); if let n = vm.scene.allBallNodes["_2"] { vm.selectBall(node: n) }
        vm.armRole(.pocket2); vm.selectPocket(at: 1)

        XCTAssertNotNil(vm.sectorRegion, "②就绪应有扇形")
        XCTAssertTrue(vm.sectorIsDefaultRegion, "无自选约束 ⇒ 扇形为默认落区（高亮）")
        XCTAssertTrue(vm.canSolve, "扇形默认落区下应可求解")
        // 扇形默认时 currentConstraint 应为扇形。
        if case .restRegion(let r)? = vm.currentConstraint() {
            XCTAssertTrue(r.isSector, "默认落区应为扇形")
        } else { XCTFail("应为 restRegion(sector)") }

        // 用户自画落区 ⇒ 扇形降级（sectorIsDefaultRegion=false），求解用用户约束。
        vm.activeTool = .region
        vm.toolDrag(startNormalized: CanvasPoint(x: 0.40, y: 0.26),
                    currentNormalized: CanvasPoint(x: 0.60, y: 0.40), ended: true)
        XCTAssertTrue(vm.hasConstraint)
        XCTAssertFalse(vm.sectorIsDefaultRegion, "自选约束存在 ⇒ 扇形降级为参考")
        if case .restRegion(let r)? = vm.currentConstraint() {
            XCTAssertFalse(r.isSector, "有自选约束时求解应用用户落区（非扇形）")
        } else { XCTFail("应为 restRegion(rect)") }

        // 删除自选约束 ⇒ 扇形恢复为默认落区。
        vm.clearConstraint()
        XCTAssertFalse(vm.hasConstraint)
        XCTAssertTrue(vm.sectorIsDefaultRegion, "删除自选约束后扇形应恢复为默认落区")
    }
}
