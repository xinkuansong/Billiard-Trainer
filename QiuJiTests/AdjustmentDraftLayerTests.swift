//
//  AdjustmentDraftLayerTests.swift
//  QiuJiTests
//
//  问题集合 v8 · X6 / K13：微调草稿层钉子单测。
//
//  钉死契约：
//  1. 微调后 `solutions[idx]` 原值不变（不污染解序列）
//  2. `nextSolution` 循环回位展示原解（草稿丢弃）
//  3. 展示/击打路径（`currentSolution` / `makeUndoContext`）走微调值
//
//  三页覆盖：Silu / PlanThree / Snooker。
//

import XCTest
import SceneKit
@testable import QiuJi

@MainActor
final class AdjustmentDraftLayerTests: XCTestCase {

    private func waitForIdle(_ isComputing: @escaping () -> Bool, timeout: TimeInterval = 45) {
        let exp = expectation(description: "idle")
        func poll() {
            if !isComputing() { exp.fulfill(); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { poll() }
        }
        poll()
        wait(for: [exp], timeout: timeout)
    }

    private func assertShotEqual(_ a: PlannedShot, _ b: PlannedShot, _ label: String,
                                 file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(a.velocity, b.velocity, accuracy: 1e-9, "\(label) velocity", file: file, line: line)
        XCTAssertEqual(a.spinX, b.spinX, accuracy: 1e-9, "\(label) spinX", file: file, line: line)
        XCTAssertEqual(a.spinY, b.spinY, accuracy: 1e-9, "\(label) spinY", file: file, line: line)
        XCTAssertEqual(a.targetKey, b.targetKey, "\(label) targetKey", file: file, line: line)
        XCTAssertEqual(a.pocket, b.pocket, "\(label) pocket", file: file, line: line)
    }

    // MARK: - Silu

    func test_silu_adjustDraft_doesNotMutateCatalog_andCycleRestoresOriginal() {
        let vm = SiluTrainerViewModel()
        vm.setupScene()
        vm.activeTool = .region
        vm.regionShape = .rect
        vm.toolDrag(startNormalized: CanvasPoint(x: 0.34, y: 0.24),
                    currentNormalized: CanvasPoint(x: 0.56, y: 0.40), ended: true)
        XCTAssertTrue(vm.hasConstraint)

        vm.solve()
        waitForIdle({ vm.isComputing })
        guard !vm.solutions.isEmpty, let catalog0 = vm.currentSolution else {
            return XCTFail("Silu 真实求解应产出解")
        }
        let idx = vm.currentIndex
        let catalogShot = catalog0.shot
        let catalogSummary = catalog0.summary

        // Fine-tune: vertical + side spin (full axes; miscue clamp is UI-only).
        let tweakSX = 0.22
        let tweakSY = -0.18
        let tweakV = min(catalogShot.velocity + 0.4, 5.0)
        vm.adjustCurrentSolution(velocity: tweakV, spinX: tweakSX, spinY: tweakSY)
        waitForIdle({ vm.isComputing })

        // 1) Catalog immutable.
        XCTAssertTrue(vm.solutions.indices.contains(idx))
        assertShotEqual(vm.solutions[idx].shot, catalogShot, "catalog after adjust")
        XCTAssertEqual(vm.solutions[idx].summary, catalogSummary)

        // 3) Display / strike path uses draft.
        guard let draft = vm.currentSolution else {
            return XCTFail("微调后应有 currentSolution（草稿）")
        }
        XCTAssertEqual(draft.shot.spinX, tweakSX, accuracy: 1e-9)
        XCTAssertEqual(draft.shot.spinY, tweakSY, accuracy: 1e-9)
        XCTAssertEqual(draft.shot.velocity, tweakV, accuracy: 1e-9)
        XCTAssertEqual(vm.spinX, tweakSX, accuracy: 1e-9)
        XCTAssertEqual(vm.spinY, tweakSY, accuracy: 1e-9)
        XCTAssertEqual(vm.velocity, tweakV, accuracy: 1e-9)

        let strikeCtx = vm.makeUndoContext(shot: draft.shot, prediction: draft.prediction)
        assertShotEqual(strikeCtx.snapshot.shot, draft.shot, "strike snapshot uses draft")
        assertShotEqual(strikeCtx.snapshot.solutions[idx].shot, catalogShot, "snapshot catalog intact")

        // 2) Cycle back → original catalog (draft discarded).
        let n = vm.solutions.count
        for _ in 0..<n { vm.nextSolution() }
        XCTAssertEqual(vm.currentIndex, idx)
        assertShotEqual(vm.solutions[idx].shot, catalogShot, "catalog after cycle")
        guard let shown = vm.currentSolution else {
            return XCTFail("循环回位应展示解")
        }
        assertShotEqual(shown.shot, catalogShot, "display after cycle = catalog")
        XCTAssertEqual(vm.spinX, catalogShot.spinX, accuracy: 1e-9)
        XCTAssertEqual(vm.spinY, catalogShot.spinY, accuracy: 1e-9)
        XCTAssertEqual(vm.velocity, catalogShot.velocity, accuracy: 1e-9)
    }

    func test_silu_furtherAdjust_basesOnDraft() {
        let vm = SiluTrainerViewModel()
        vm.setupScene()
        vm.activeTool = .region
        vm.regionShape = .rect
        vm.toolDrag(startNormalized: CanvasPoint(x: 0.34, y: 0.24),
                    currentNormalized: CanvasPoint(x: 0.56, y: 0.40), ended: true)
        vm.solve()
        waitForIdle({ vm.isComputing })
        guard !vm.solutions.isEmpty else { return XCTFail("Silu 应有解") }

        let catalogShot = vm.solutions[vm.currentIndex].shot
        vm.adjustCurrentSolution(spinX: 0.20)
        waitForIdle({ vm.isComputing })
        guard let draft1 = vm.currentSolution else { return XCTFail("首次微调应有草稿") }
        XCTAssertEqual(draft1.shot.spinX, 0.20, accuracy: 1e-9)

        let v2 = min(catalogShot.velocity + 0.5, 5.0)
        vm.adjustCurrentSolution(velocity: v2)
        waitForIdle({ vm.isComputing })
        // Second tweak keeps prior draft spinX.
        guard let draft2 = vm.currentSolution else { return XCTFail("二次微调应有草稿") }
        XCTAssertEqual(draft2.shot.spinX, 0.20, accuracy: 1e-9)
        XCTAssertEqual(draft2.shot.velocity, v2, accuracy: 1e-9)
        assertShotEqual(vm.solutions[vm.currentIndex].shot, catalogShot, "catalog still intact")
    }

    // MARK: - PlanThree

    func test_planThree_adjustDraft_doesNotMutateCatalog_andCycleRestoresOriginal() {
        let vm = PlanThreeViewModel()
        vm.setupScene()
        // Same pot-only board as PlanThreeSectorSolverTests (known solvable via coarse grid).
        let before = BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.5, y: 0.36),
            "_1": CanvasPoint(x: 0.5, y: 0.16)])
        vm.loadBoard(before)
        vm.armRole(.ball1)
        if let node = vm.scene.allBallNodes["_1"] { vm.selectBall(node: node) }
        vm.armRole(.pocket1)
        vm.selectPocket(at: 5)
        guard let constraint = vm.currentConstraint() else {
            return XCTFail("pot-only 应有约束")
        }
        // Seed catalog via known-solvable coarse search (VM.solve `.standard` may miss under CI time);
        // adjust still exercises the real forward draft path on this VM.
        let coarse = PositionPlaySolver.SearchParams(
            spinXValues: [-0.3, 0, 0.3],
            spinYValues: [-0.3, 0, 0.3],
            velocityMin: 1.0, velocityMax: 5.0, velocityStep: 1.0,
            marginBase: 0.0, marginPerCushion: 0.04,
            passTolerance: 2 * AngleSceneCalculator.ballRadius, passMinSpeed: 0.2)
        let seeded = PositionPlaySolver.solve(
            before: before, targetKey: "_1", pocket: "topCenter",
            constraint: constraint, surfaceY: BTTablePhysics.surfaceY, params: coarse)
        guard !seeded.isEmpty else { return XCTFail("coarse pot-only 应产出解以种入 catalog") }
        let catalog0 = seeded[0]
        let snap = SolveShotSnapshot(
            before: before, shot: catalog0.shot, prediction: catalog0.prediction,
            solutions: seeded, currentIndex: 0, draft: nil,
            velocity: catalog0.shot.velocity, spinX: catalog0.shot.spinX, spinY: catalog0.shot.spinY,
            allowSideSpin: true, basicPositionOnly: false)
        vm.restore(from: PlanThreeViewModel.UndoContext(
            snapshot: snap, ball1Key: "_1", ball2Key: nil, ball3Key: nil,
            pocket1Index: 5, pocket2Index: -1, armedRole: nil))
        XCTAssertFalse(vm.solutions.isEmpty)

        let idx = vm.currentIndex
        let catalogShot = vm.solutions[idx].shot
        let catalogSummary = vm.solutions[idx].summary

        let tweakSX = 0.18
        let tweakSY = 0.25
        let tweakV = min(catalogShot.velocity + 0.3, 5.0)
        vm.adjustCurrentSolution(velocity: tweakV, spinX: tweakSX, spinY: tweakSY)
        waitForIdle({ vm.isComputing })

        assertShotEqual(vm.solutions[idx].shot, catalogShot, "PlanThree catalog after adjust")
        XCTAssertEqual(vm.solutions[idx].summary, catalogSummary)

        guard let draft = vm.currentSolution else {
            return XCTFail("PlanThree 微调后应有草稿")
        }
        XCTAssertEqual(draft.shot.spinX, tweakSX, accuracy: 1e-9)
        XCTAssertEqual(draft.shot.spinY, tweakSY, accuracy: 1e-9)
        XCTAssertEqual(draft.shot.velocity, tweakV, accuracy: 1e-9)

        let strikeCtx = vm.makeUndoContext(shot: draft.shot, prediction: draft.prediction)
        assertShotEqual(strikeCtx.snapshot.shot, draft.shot, "PlanThree strike uses draft")
        assertShotEqual(strikeCtx.snapshot.solutions[idx].shot, catalogShot, "PlanThree snapshot catalog")

        let n = vm.solutions.count
        for _ in 0..<n { vm.nextSolution() }
        XCTAssertEqual(vm.currentIndex, idx)
        guard let shown = vm.currentSolution else { return XCTFail("循环回位应有解") }
        assertShotEqual(shown.shot, catalogShot, "PlanThree cycle → catalog")
        XCTAssertEqual(vm.spinX, catalogShot.spinX, accuracy: 1e-9)
        XCTAssertEqual(vm.spinY, catalogShot.spinY, accuracy: 1e-9)
    }

    // MARK: - Snooker

    func test_snooker_adjustDraft_doesNotMutateCatalog_andCycleRestoresOriginal() {
        let vm = SnookerTacticsViewModel()
        vm.setupScene()
        XCTAssertTrue(vm.canSolve, "默认盘面应可求解")

        vm.solve()
        waitForIdle({ vm.isComputing }, timeout: 90)
        guard !vm.solutions.isEmpty, let catalog0 = vm.currentSolution else {
            return XCTFail("Snooker 默认盘面应产出防守解")
        }
        let idx = vm.currentIndex
        let catalogShot = catalog0.shot
        let catalogSummary = catalog0.summary

        let tweakSX = -0.20
        let tweakSY = 0.15
        let tweakV = max(catalogShot.velocity - 0.2, 0.8)
        vm.adjustCurrentSolution(velocity: tweakV, spinX: tweakSX, spinY: tweakSY)
        waitForIdle({ vm.isComputing })

        assertShotEqual(vm.solutions[idx].shot, catalogShot, "Snooker catalog after adjust")
        XCTAssertEqual(vm.solutions[idx].summary, catalogSummary)

        guard let draft = vm.currentSolution else {
            return XCTFail("Snooker 微调后应有草稿")
        }
        XCTAssertEqual(draft.shot.spinX, tweakSX, accuracy: 1e-9)
        XCTAssertEqual(draft.shot.spinY, tweakSY, accuracy: 1e-9)
        XCTAssertEqual(draft.shot.velocity, tweakV, accuracy: 1e-9)

        let strikeCtx = vm.makeUndoContext(shot: draft.shot, prediction: draft.prediction)
        assertShotEqual(strikeCtx.snapshot.shot, draft.shot, "Snooker strike uses draft")
        assertShotEqual(strikeCtx.snapshot.solutions[idx].shot, catalogShot, "Snooker snapshot catalog")

        let n = vm.solutions.count
        for _ in 0..<n { vm.nextSolution() }
        XCTAssertEqual(vm.currentIndex, idx)
        assertShotEqual(vm.currentSolution!.shot, catalogShot, "Snooker cycle → catalog")
        XCTAssertEqual(vm.spinX, catalogShot.spinX, accuracy: 1e-9)
        XCTAssertEqual(vm.spinY, catalogShot.spinY, accuracy: 1e-9)
    }
}
