//
//  PositionPlayUndoSnapshotTests.swift
//  QiuJiTests
//
//  问题集合 v5 · V3（G17 上一杆完整恢复）：反解页「上一杆」快照往返（snapshot → restore）
//  逐字段一致性验证。
//
//  覆盖两条路径：
//  - Test A（确定性）：手工构造完整 `SolveShotSnapshot`（含 N 个解），走 VM 真实 `restore(from:)`，
//    断言恢复后每个字段与快照一致——证明「球形/约束/解/打点/力度/目标或角色」逐字段还原、且**不重解**。
//  - Test B（真实管线）：驱动真实反解 `solve()` → `makeUndoContext()` 捕获 → 抹除状态 → `restore()`，
//    断言真实解集与选择模型在往返后计数/取值一致——证明 `play()` 用的同一处捕获逻辑可无损还原。
//

import XCTest
import SceneKit
@testable import QiuJi

@MainActor
final class PositionPlayUndoSnapshotTests: XCTestCase {

    // MARK: - Helpers

    /// 构造一个可用于快照的最小 `PositionPlaySolution`（往返测试只关心其被原样搬运，不跑物理）。
    private func stubSolution(velocity: Double, spinX: Double, spinY: Double) -> PositionPlaySolution {
        var pred = ShotPrediction()
        pred.feasible = true
        pred.duration = 1.0
        let shot = PlannedShot(targetKey: "_1", pocket: "topRight",
                               velocity: velocity, spinX: spinX, spinY: spinY)
        return PositionPlaySolution(
            shot: shot, prediction: pred, cushionCount: 1, potted: true,
            margin: 0.12, summary: "stub", satisfiesConstraint: true,
            beyondCushionBudget: false, difficultyScore: 0, difficultyTier: .center,
            beyondSpinBudget: false, robustness: nil)
    }

    private func waitForSolveIdle(_ isComputing: @escaping () -> Bool, timeout: TimeInterval = 15) {
        let exp = expectation(description: "solve idle")
        func poll() {
            if !isComputing() { exp.fulfill(); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { poll() }
        }
        poll()
        wait(for: [exp], timeout: timeout)
    }

    // MARK: - Test A · 思路训练：确定性快照往返

    func test_silu_restore_reproducesEveryField() {
        let vm = SiluTrainerViewModel()
        vm.setupScene()

        // 期望快照：非默认球形 + 非默认目标/袋口 + 落区约束 + 2 个解 + 非默认打点/力度/选项。
        let before = BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.28, y: 0.32),
            "_1": CanvasPoint(x: 0.64, y: 0.18),
            "_5": CanvasPoint(x: 0.44, y: 0.34)
        ])
        let draft: SolveConstraintDraft = .region(.rect(
            center: CanvasPoint(x: 0.45, y: 0.30), halfWidth: 0.12, halfHeight: 0.08))
        let solutions = [
            stubSolution(velocity: 3.4, spinX: 0.20, spinY: -0.10),
            stubSolution(velocity: 2.1, spinX: -0.05, spinY: 0.30)
        ]
        let snap = SolveShotSnapshot(
            before: before, shot: solutions[1].shot, prediction: solutions[1].prediction,
            solutions: solutions, currentIndex: 1, draft: draft,
            velocity: 2.1, spinX: -0.05, spinY: 0.30,
            allowSideSpin: false, basicPositionOnly: true)   // basicPositionOnly 与默认 false 不同 → 触发 didSet 失效，验证恢复顺序
        let ctx = SiluTrainerViewModel.UndoContext(
            snapshot: snap, selectedTargetKey: "_1", selectedPocketIndex: 5)

        // 抹除当前状态（模拟击打后局面），再恢复。
        vm.clearTable()
        vm.restore(from: ctx)

        // 球形逐字段一致。
        XCTAssertEqual(Set(vm.onTableKeys), Set(before.onTable.keys), "在桌球集合应与快照一致")
        let restored = vm.currentSnapshot().onTable
        for (key, pt) in before.onTable {
            let r = restored[key]
            XCTAssertNotNil(r, "\(key) 应恢复上桌")
            XCTAssertEqual(r?.x ?? -9, pt.x, accuracy: 0.01, "\(key).x 应还原")
            XCTAssertEqual(r?.y ?? -9, pt.y, accuracy: 0.01, "\(key).y 应还原")
        }
        // 目标/袋口。
        XCTAssertEqual(vm.selectedTargetKey, "_1")
        XCTAssertEqual(vm.selectedPocketIndex, 5)
        // 约束还在。
        XCTAssertTrue(vm.hasConstraint, "约束应还原（hasConstraint）")
        // 解还在（免重解）：计数/档位一致，且不在计算中。
        XCTAssertEqual(vm.solutions.count, 2, "解集应原样还原")
        XCTAssertEqual(vm.currentIndex, 1, "当前解档位应还原")
        XCTAssertFalse(vm.isComputing, "恢复后不应触发重新求解")
        // 打点/力度指示（当前解）。
        XCTAssertEqual(vm.velocity, 2.1, accuracy: 1e-9)
        XCTAssertEqual(vm.spinX, -0.05, accuracy: 1e-9)
        XCTAssertEqual(vm.spinY, 0.30, accuracy: 1e-9)
        // 求解选项。
        XCTAssertFalse(vm.allowSideSpin, "allowSideSpin 应还原为 false")
        XCTAssertTrue(vm.basicPositionOnly, "basicPositionOnly 应还原为 true")
    }

    // MARK: - Test A · 打一走二想三：确定性快照往返（含 ①②③ 角色）

    func test_planThree_restore_reproducesRolesAndSolve() {
        let vm = PlanThreeViewModel()
        vm.setupScene()

        let before = BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.22, y: 0.30),
            "_1": CanvasPoint(x: 0.50, y: 0.16),
            "_2": CanvasPoint(x: 0.70, y: 0.34),
            "_3": CanvasPoint(x: 0.86, y: 0.16)
        ])
        let draft: SolveConstraintDraft = .passPoint(CanvasPoint(x: 0.62, y: 0.28))
        let solutions = [stubSolution(velocity: 2.8, spinX: 0.10, spinY: 0.15)]
        let snap = SolveShotSnapshot(
            before: before, shot: solutions[0].shot, prediction: solutions[0].prediction,
            solutions: solutions, currentIndex: 0, draft: draft,
            velocity: 2.8, spinX: 0.10, spinY: 0.15,
            allowSideSpin: true, basicPositionOnly: true)
        let ctx = PlanThreeViewModel.UndoContext(
            snapshot: snap, ball1Key: "_1", ball2Key: "_2", ball3Key: "_3",
            pocket1Index: 5, pocket2Index: 2, armedRole: nil)

        vm.clearTable()
        vm.restore(from: ctx)

        XCTAssertEqual(Set(vm.onTableKeys), Set(before.onTable.keys))
        // ①②③ 角色指派逐字段还原。
        XCTAssertEqual(vm.ball1Key, "_1")
        XCTAssertEqual(vm.ball2Key, "_2")
        XCTAssertEqual(vm.ball3Key, "_3")
        XCTAssertEqual(vm.pocket1Index, 5)
        XCTAssertEqual(vm.pocket2Index, 2)
        XCTAssertNil(vm.armedRole, "已齐（armedRole=nil）应还原")
        // 约束 + 解还在。
        XCTAssertTrue(vm.hasConstraint)
        XCTAssertEqual(vm.solutions.count, 1)
        XCTAssertEqual(vm.currentIndex, 0)
        XCTAssertFalse(vm.isComputing)
        // 打点/力度。
        XCTAssertEqual(vm.velocity, 2.8, accuracy: 1e-9)
        XCTAssertEqual(vm.spinX, 0.10, accuracy: 1e-9)
        XCTAssertEqual(vm.spinY, 0.15, accuracy: 1e-9)
        XCTAssertTrue(vm.basicPositionOnly)
    }

    // MARK: - Test A · 防守（V8）：确定性快照往返（含目标球选择模型）

    func test_snooker_restore_reproducesEveryField() {
        let vm = SnookerTacticsViewModel()
        vm.setupScene()

        // 期望快照：非默认球形 + 目标球 + 2 个解 + 非默认打点/力度/选项。防守页无约束草稿（draft=nil）。
        let before = BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.24, y: 0.30),
            "_1": CanvasPoint(x: 0.52, y: 0.24),
            "_2": CanvasPoint(x: 0.44, y: 0.20),
            "_9": CanvasPoint(x: 0.40, y: 0.16)
        ])
        let solutions = [
            stubSolution(velocity: 2.8, spinX: 0.15, spinY: -0.10),
            stubSolution(velocity: 1.9, spinX: 0.0, spinY: 0.20)
        ]
        let snap = SolveShotSnapshot(
            before: before, shot: solutions[1].shot, prediction: solutions[1].prediction,
            solutions: solutions, currentIndex: 1, draft: nil,
            velocity: 1.9, spinX: 0.0, spinY: 0.20,
            allowSideSpin: false, basicPositionOnly: true)   // 与默认（true/false）不同 → 验证恢复顺序
        let ctx = SnookerTacticsViewModel.UndoContext(snapshot: snap, selectedTargetKey: "_1")

        vm.clearTable()
        vm.restore(from: ctx)

        // 球形逐字段一致。
        XCTAssertEqual(Set(vm.onTableKeys), Set(before.onTable.keys), "在桌球集合应与快照一致")
        let restored = vm.currentSnapshot().onTable
        for (key, pt) in before.onTable {
            let r = restored[key]
            XCTAssertNotNil(r, "\(key) 应恢复上桌")
            XCTAssertEqual(r?.x ?? -9, pt.x, accuracy: 0.01, "\(key).x 应还原")
            XCTAssertEqual(r?.y ?? -9, pt.y, accuracy: 0.01, "\(key).y 应还原")
        }
        // 目标球（本页选择模型）。
        XCTAssertEqual(vm.selectedTargetKey, "_1")
        // 对方球组推断随目标球还原（_1 全色 → 对方花色 _9）。
        XCTAssertEqual(Set(vm.opponentKeys), Set(["_9"]))
        XCTAssertTrue(vm.canSolve, "目标 + 对方球齐 ⇒ 可求解")
        // 解还在（免重解）。
        XCTAssertEqual(vm.solutions.count, 2, "解集应原样还原")
        XCTAssertEqual(vm.currentIndex, 1, "当前解档位应还原")
        XCTAssertFalse(vm.isComputing, "恢复后不应触发重新求解")
        // 打点/力度指示。
        XCTAssertEqual(vm.velocity, 1.9, accuracy: 1e-9)
        XCTAssertEqual(vm.spinX, 0.0, accuracy: 1e-9)
        XCTAssertEqual(vm.spinY, 0.20, accuracy: 1e-9)
        // 求解选项。
        XCTAssertFalse(vm.allowSideSpin, "allowSideSpin 应还原为 false")
        XCTAssertTrue(vm.basicPositionOnly, "basicPositionOnly 应还原为 true")
    }

    // MARK: - Test B · 思路训练：真实反解管线的捕获 → 恢复无损

    func test_silu_realSolvePipeline_captureAndRestore() {
        let vm = SiluTrainerViewModel()
        vm.setupScene()   // 默认摆好母球 + _1，自动选目标/最优袋

        // 画一块可行落区并真实求解。
        vm.activeTool = .region
        vm.regionShape = .rect
        vm.toolDrag(startNormalized: CanvasPoint(x: 0.34, y: 0.24),
                    currentNormalized: CanvasPoint(x: 0.56, y: 0.40), ended: true)
        XCTAssertTrue(vm.hasConstraint, "落区应就绪")

        vm.solve()
        waitForSolveIdle({ vm.isComputing })

        // 记录击打前真实状态。
        let targetBefore = vm.selectedTargetKey
        let pocketBefore = vm.selectedPocketIndex
        let solCountBefore = vm.solutions.count
        let idxBefore = vm.currentIndex
        let velBefore = vm.velocity
        let boardBefore = vm.currentSnapshot().onTable

        guard let sol = vm.currentSolution else {
            return XCTFail("真实求解未产出解（几何不可解？调整落区）")
        }
        // 用 play() 同一处捕获逻辑。
        let ctx = vm.makeUndoContext(shot: sol.shot, prediction: sol.prediction)

        // 抹除后恢复。
        vm.clearTable()
        XCTAssertEqual(vm.solutions.count, 0, "clearTable 应清空解")
        vm.restore(from: ctx)

        // 无损还原：真实解集与选择模型往返一致，且未重解（同步就绪、非计算态）。
        XCTAssertFalse(vm.isComputing, "恢复后应立即就绪，无需重新求解")
        XCTAssertEqual(vm.solutions.count, solCountBefore, "真实解集计数应往返一致")
        XCTAssertEqual(vm.currentIndex, idxBefore)
        XCTAssertEqual(vm.selectedTargetKey, targetBefore)
        XCTAssertEqual(vm.selectedPocketIndex, pocketBefore)
        XCTAssertEqual(vm.velocity, velBefore, accuracy: 1e-9)
        XCTAssertTrue(vm.hasConstraint, "约束应往返保留")
        XCTAssertEqual(Set(vm.onTableKeys), Set(boardBefore.keys), "球形应往返保留")
    }

    // MARK: - V9（翻袋 / 反射）：求解模式「上一杆」完整快照往返（G17，条 17.5）

    /// 场景系球形逐键 x/z 近似相等。
    private func assertSceneBoardEqual(_ a: [String: SCNVector3], _ b: [String: SCNVector3],
                                       _ msg: String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(Set(a.keys), Set(b.keys), "\(msg) 在桌球集合应一致", file: file, line: line)
        for (k, v) in a {
            guard let w = b[k] else { XCTFail("\(msg) 缺 \(k)", file: file, line: line); continue }
            XCTAssertEqual(v.x, w.x, accuracy: 1e-4, "\(msg) \(k).x", file: file, line: line)
            XCTAssertEqual(v.z, w.z, accuracy: 1e-4, "\(msg) \(k).z", file: file, line: line)
        }
    }

    /// 反射解球器：真实反解 → 捕获求解快照 → 抹除 → 恢复，逐字段一致且不重解。
    func test_reflection_solveUndo_restoresEveryField() {
        let vm = DiamondSystemViewModel()
        vm.setupScene()   // 默认摆球即自动反解
        waitForSolveIdle({ vm.isSolving })

        guard vm.hasSolution, let ctx = vm.makeSolveUndo() else {
            return XCTFail("反射默认球形未产出解（几何不可解？）")
        }
        let solCountBefore = ctx.solutions.count
        let idxBefore = ctx.currentIndex
        let cushionsBefore = ctx.cushions
        let powerBefore = ctx.struckPower
        let boardBefore = ctx.board

        // 抹除当前求解状态（重置回默认，触发再求解），再恢复。
        vm.reset()
        waitForSolveIdle({ vm.isSolving })
        vm.restoreSolve(from: ctx)

        XCTAssertFalse(vm.isSolving, "恢复后不应触发重新求解（免重解）")
        XCTAssertTrue(vm.hasSolution, "解应原样还原")
        XCTAssertEqual(vm.reflectionPower, powerBefore, accuracy: 1e-9, "力度应还原")
        guard let ctx2 = vm.makeSolveUndo() else { return XCTFail("恢复后应可再次捕获快照") }
        XCTAssertEqual(ctx2.solutions.count, solCountBefore, "解集计数应往返一致")
        XCTAssertEqual(ctx2.currentIndex, idxBefore, "当前解档位应还原")
        XCTAssertEqual(ctx2.cushions, cushionsBefore, "库数选择应还原")
        assertSceneBoardEqual(ctx2.board, boardBefore, "反射球形")
    }

    /// 翻袋解球器：真实反解 → 捕获求解快照（含袋口）→ 抹除 → 恢复，逐字段一致且不重解。
    func test_bankShot_solveUndo_restoresEveryField() {
        let vm = BankShotViewModel()
        vm.setupScene()
        waitForSolveIdle({ vm.isSolving })
        // 默认袋口可能无解：逐个袋口找有解的那个。
        if !vm.hasSolution {
            for p in 0..<6 {
                vm.selectPocket(p)
                waitForSolveIdle({ vm.isSolving })
                if vm.hasSolution { break }
            }
        }
        guard vm.hasSolution, let ctx = vm.makeSolveUndo() else {
            return XCTFail("翻袋各袋口均未产出解（几何不可解？）")
        }
        let pocketBefore = ctx.pocket
        let solCountBefore = ctx.solutions.count
        let idxBefore = ctx.currentIndex
        let powerBefore = ctx.struckPower
        let boardBefore = ctx.board

        vm.reset()   // 复位到默认（袋口 0，触发再求解）
        waitForSolveIdle({ vm.isSolving })
        vm.restoreSolve(from: ctx)

        XCTAssertFalse(vm.isSolving, "恢复后不应触发重新求解（免重解）")
        XCTAssertTrue(vm.hasSolution, "解应原样还原")
        XCTAssertEqual(vm.selectedPocket, pocketBefore, "袋口应还原")
        XCTAssertEqual(vm.reflectionPower, powerBefore, accuracy: 1e-9, "力度应还原")
        guard let ctx2 = vm.makeSolveUndo() else { return XCTFail("恢复后应可再次捕获快照") }
        XCTAssertEqual(ctx2.solutions.count, solCountBefore, "解集计数应往返一致")
        XCTAssertEqual(ctx2.currentIndex, idxBefore, "当前解档位应还原")
        XCTAssertEqual(ctx2.pocket, pocketBefore, "袋口应还原（快照）")
        assertSceneBoardEqual(ctx2.board, boardBefore, "翻袋球形")
    }
}
