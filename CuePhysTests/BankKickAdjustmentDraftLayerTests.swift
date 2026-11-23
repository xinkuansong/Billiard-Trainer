//
//  BankKickAdjustmentDraftLayerTests.swift
//  QiuJiTests
//
//  问题集合 v8 · X5 / K11：翻袋/反射微调草稿层钉子单测（对齐 X6 AdjustmentDraftLayerTests）。
//
//  钉死契约：
//  1. 微调后 catalog（solutions/displayed[idx]）原值不变
//  2. nextSolution 循环回位展示原解（草稿丢弃）
//  3. 展示/击打路径（currentSolution）走微调值
//

import XCTest
import SceneKit
@testable import QiuJi

@MainActor
final class BankKickAdjustmentDraftLayerTests: XCTestCase {

    private func waitForIdle(_ isBusy: @escaping () -> Bool, timeout: TimeInterval = 60) {
        let exp = expectation(description: "idle")
        func poll() {
            if !isBusy() { exp.fulfill(); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { poll() }
        }
        poll()
        wait(for: [exp], timeout: timeout)
    }

    func test_modeChangeCancelsOwnedSolveInBothPages() async throws {
        let models: [any SolverStageHosting] = [BankShotViewModel(), DiamondSystemViewModel()]
        for vm in models {
            vm.setupScene()
            XCTAssertTrue(vm.isSolving)
            vm.toggleMode()
            try await Task.sleep(for: .milliseconds(250))
            XCTAssertFalse(vm.isSolving)
            XCTAssertFalse(vm.hasSolution, "Changing mode cancels even a pending automatic search")
            vm.stopForDismissal()
        }
    }

    // MARK: - Bank

    func test_bank_adjustDraft_doesNotMutateCatalog_andCycleRestoresOriginal() {
        let vm = BankShotViewModel()
        vm.setupScene()
        waitForIdle({ vm.isSolving })
        if !vm.hasSolution {
            for p in 0..<6 {
                vm.selectPocket(p)
                waitForIdle({ vm.isSolving })
                if vm.hasSolution { break }
            }
        }
        guard vm.hasSolution, let catalog0 = vm.catalogSolution else {
            return XCTFail("翻袋应产出解")
        }
        let idx = vm.currentIndex
        let catalogSpinX = catalog0.spinX
        let catalogSpinY = catalog0.spinY
        let catalogRails = catalog0.rails
        let catalogAim = catalog0.prediction.aimDirection

        let tweakSX = 0.22
        let tweakSY = -0.18
        let tweakV = min(vm.reflectionPower + 0.3, Double(CushionReflectionSettings.maxPower))
        // Burst while the first real prediction is still in flight. The final
        // complete intent must win without changing the immutable catalog.
        for i in 0..<30 {
            vm.adjustCurrentSolution(velocity: 2 + Double(i) / 100,
                                     spinX: Double(i) / 200, spinY: -Double(i) / 200)
        }
        vm.adjustCurrentSolution(velocity: tweakV, spinX: tweakSX, spinY: tweakSY)
        vm.adjustCurrentSolution(spinX: tweakSX)
        vm.adjustCurrentSolution(spinY: tweakSY)
        vm.adjustCurrentSolution(velocity: tweakV)
        waitForIdle({ vm.isSolving })

        // 1) Catalog immutable.
        guard let catalogAfter = vm.catalogSolution else { return XCTFail("catalog 应仍在") }
        XCTAssertEqual(catalogAfter.spinX, catalogSpinX, accuracy: 1e-6)
        XCTAssertEqual(catalogAfter.spinY, catalogSpinY, accuracy: 1e-6)
        XCTAssertEqual(catalogAfter.railSequenceText, catalog0.railSequenceText)
        XCTAssertEqual(catalogAfter.prediction.aimDirection.x, catalogAim.x, accuracy: 1e-5)
        XCTAssertEqual(catalogAfter.prediction.aimDirection.z, catalogAim.z, accuracy: 1e-5)
        _ = catalogRails // retained for future rail-level asserts

        // 3) Display / strike path uses draft.
        guard let draft = vm.currentSolution else { return XCTFail("微调后应有 currentSolution") }
        XCTAssertEqual(draft.spinX, Float(tweakSX), accuracy: 1e-5)
        XCTAssertEqual(draft.spinY, Float(tweakSY), accuracy: 1e-5)
        XCTAssertEqual(vm.spinX, Double(Float(tweakSX)), accuracy: 1e-9)
        XCTAssertEqual(vm.spinY, Double(Float(tweakSY)), accuracy: 1e-9)
        XCTAssertEqual(vm.reflectionPower, tweakV, accuracy: 1e-9)

        guard let strikeCtx = vm.makeSolveUndo() else { return XCTFail("应能捕获 undo") }
        XCTAssertEqual(strikeCtx.struckSpinX, Double(Float(tweakSX)), accuracy: 1e-9)
        XCTAssertEqual(strikeCtx.solutions[idx].spinX, catalogSpinX, accuracy: 1e-6,
                       "snapshot catalog intact")

        vm.restoreSolve(from: strikeCtx)
        XCTAssertEqual(vm.currentSolution?.robustness, draft.robustness)
        XCTAssertEqual(vm.currentSolution?.cushions, draft.cushions)
        XCTAssertEqual(vm.currentSolution?.pathLength, draft.pathLength)
        XCTAssertEqual(vm.currentSolution?.spinX, draft.spinX)

        // 2) Cycle back → original catalog (draft discarded).
        let n = max(vm.solutionCount, 1)
        for _ in 0..<n { vm.nextSolution() }
        XCTAssertEqual(vm.currentIndex, idx)
        guard let shown = vm.currentSolution, let catalogFinal = vm.catalogSolution else {
            return XCTFail("循环回位应展示解")
        }
        XCTAssertEqual(shown.spinX, catalogFinal.spinX, accuracy: 1e-6)
        XCTAssertEqual(shown.spinY, catalogFinal.spinY, accuracy: 1e-6)
        XCTAssertEqual(vm.spinX, Double(catalogSpinX), accuracy: 1e-9)
        XCTAssertEqual(vm.spinY, Double(catalogSpinY), accuracy: 1e-9)
        var filtered = strikeCtx
        func copy(count: Int) -> BankEngineSolution {
            .init(rails: catalog0.rails, seedRails: catalog0.seedRails, prediction: catalog0.prediction,
                  cushions: count, difficultyScore: catalog0.difficultyScore, difficultyTier: catalog0.difficultyTier,
                  robustness: catalog0.robustness, pathLength: catalog0.pathLength,
                  spinX: catalog0.spinX, spinY: catalog0.spinY, usedFrozenRailSeed: catalog0.usedFrozenRailSeed)
        }
        let one = copy(count: 1), three = copy(count: 3)
        filtered.solutions = Array(repeating: one, count: 20) + [three]
        filtered.cushions = 3; filtered.currentIndex = 0; filtered.struckSolution = nil
        vm.restoreSolve(from: filtered)
        XCTAssertEqual(vm.solutionCount, 1, "Filter the full catalog before applying the display limit")
        XCTAssertEqual(vm.currentCushions, 3)
    }

    // MARK: - Diamond / Kick

    func test_diamond_adjustDraft_doesNotMutateCatalog_andCycleRestoresOriginal() {
        let vm = DiamondSystemViewModel()
        vm.setupScene()
        waitForIdle({ vm.isSolving })
        guard vm.hasSolution, let catalog0 = vm.catalogSolution else {
            return XCTFail("反射默认盘面应产出解")
        }
        let idx = vm.currentIndex
        let catalogSpinX = catalog0.spinX
        let catalogSpinY = catalog0.spinY
        let catalogRails = catalog0.rails

        let tweakSX = -0.20
        let tweakSY = 0.15
        let tweakV = max(vm.reflectionPower - 0.2, Double(CushionReflectionSettings.minPower))
        // Burst while the first real prediction is still in flight. The final
        // complete intent must win without changing the immutable catalog.
        for i in 0..<30 {
            vm.adjustCurrentSolution(velocity: 2 + Double(i) / 100,
                                     spinX: Double(i) / 200, spinY: -Double(i) / 200)
        }
        vm.adjustCurrentSolution(velocity: tweakV, spinX: tweakSX, spinY: tweakSY)
        vm.adjustCurrentSolution(spinX: tweakSX)
        vm.adjustCurrentSolution(spinY: tweakSY)
        vm.adjustCurrentSolution(velocity: tweakV)
        waitForIdle({ vm.isSolving })

        guard let catalogAfter = vm.catalogSolution else { return XCTFail("catalog 应仍在") }
        XCTAssertEqual(catalogAfter.spinX, catalogSpinX, accuracy: 1e-6)
        XCTAssertEqual(catalogAfter.spinY, catalogSpinY, accuracy: 1e-6)
        XCTAssertEqual(catalogAfter.railSequenceText, catalog0.railSequenceText)
        _ = catalogRails

        guard let draft = vm.currentSolution else { return XCTFail("微调后应有草稿") }
        XCTAssertEqual(draft.spinX, Float(tweakSX), accuracy: 1e-5)
        XCTAssertEqual(draft.spinY, Float(tweakSY), accuracy: 1e-5)
        XCTAssertEqual(vm.spinX, Double(Float(tweakSX)), accuracy: 1e-9)
        XCTAssertEqual(vm.reflectionPower, tweakV, accuracy: 1e-9)

        guard let strikeCtx = vm.makeSolveUndo() else { return XCTFail("应能捕获 undo") }
        XCTAssertEqual(strikeCtx.struckSpinX, Double(Float(tweakSX)), accuracy: 1e-9)
        XCTAssertEqual(strikeCtx.solutions[idx].spinX, catalogSpinX, accuracy: 1e-6)

        vm.restoreSolve(from: strikeCtx)
        XCTAssertEqual(vm.currentSolution?.robustness, draft.robustness)
        XCTAssertEqual(vm.currentSolution?.cushions, draft.cushions)
        XCTAssertEqual(vm.currentSolution?.pathLength, draft.pathLength)
        XCTAssertEqual(vm.currentSolution?.spinX, draft.spinX)

        let n = max(vm.solutionCount, 1)
        for _ in 0..<n { vm.nextSolution() }
        XCTAssertEqual(vm.currentIndex, idx)
        XCTAssertEqual(vm.currentSolution!.spinX, catalogSpinX, accuracy: 1e-6)
        XCTAssertEqual(vm.spinX, Double(catalogSpinX), accuracy: 1e-9)
        var filtered = strikeCtx
        func copy(count: Int) -> KickEngineSolution {
            .init(rails: catalog0.rails, seedRails: catalog0.seedRails, prediction: catalog0.prediction,
                  cushions: count, difficultyScore: catalog0.difficultyScore, difficultyTier: catalog0.difficultyTier,
                  robustness: catalog0.robustness, pathLength: catalog0.pathLength,
                  spinX: catalog0.spinX, spinY: catalog0.spinY)
        }
        let one = copy(count: 1), three = copy(count: 3)
        filtered.solutions = Array(repeating: one, count: 20) + [three]
        filtered.cushions = 3; filtered.currentIndex = 0; filtered.struckSolution = nil
        vm.restoreSolve(from: filtered)
        XCTAssertEqual(vm.solutionCount, 1, "Filter the full catalog before applying the display limit")
        XCTAssertEqual(vm.currentCushions, 3)
    }
}
