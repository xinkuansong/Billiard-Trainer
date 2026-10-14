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

extension AdjustmentDraftLayerTests {
    func testPlanningPagesRejectIncompletePrediction() {
        let silu = SiluTrainerViewModel()
        let plan = PlanThreeViewModel()
        let snooker = SnookerTacticsViewModel()
        let complete = ShotPredictor.simulateFree(
            cueBall: SCNVector3(0, BTTablePhysics.surfaceY + BallPhysics.radius, 0),
            aimDir: SCNVector3(1, 0, 0), velocity: 0.3, spinX: 0, spinY: 0,
            surfaceY: BTTablePhysics.surfaceY, balls: [])
        XCTAssertTrue(complete.hasFinalTableState)
        for termination: EventDrivenEngine.Termination? in [nil, .timeLimit, .eventLimit, .interestResolved, .failed("test")] {
            var partial = complete
            partial.termination = termination
            XCTAssertFalse(silu.acceptCompletePrediction(partial))
            XCTAssertFalse(plan.acceptCompletePrediction(partial))
            XCTAssertFalse(snooker.acceptCompletePrediction(partial))
            XCTAssertTrue(silu.statusText.contains("未完成"))
            XCTAssertTrue(plan.statusText.contains("未完成"))
            XCTAssertTrue(snooker.statusText.contains("未完成"))
        }
        XCTAssertTrue(silu.acceptCompletePrediction(complete))
        XCTAssertTrue(plan.acceptCompletePrediction(complete))
        XCTAssertTrue(snooker.acceptCompletePrediction(complete))
    }
}

@MainActor
final class RemainingPredictionLifecycleTests: XCTestCase {
    func testLatestQueueKeepsOneRunningAndOnePendingIntent() async {
        let scheduler = LatestPredictionScheduler<Int>()
        let started = expectation(description: "first started")
        let final = expectation(description: "latest delivered")
        let release = DispatchSemaphore(value: 0)
        var delivered: [Int] = []
        scheduler.submit(compute: {
            started.fulfill()
            _ = release.wait(timeout: .now() + 5)
            return 1
        }, receive: { value, latest in if latest { delivered.append(value) } })
        await fulfillment(of: [started], timeout: 2)
        for value in 2...31 {
            scheduler.submit(compute: { value }, receive: { result, latest in
                if latest { delivered.append(result); final.fulfill() }
            })
            XCTAssertTrue(scheduler.isRunning)
            XCTAssertEqual(scheduler.pendingCount, 1)
        }
        release.signal()
        await fulfillment(of: [final], timeout: 3)
        XCTAssertEqual(delivered, [31])
        XCTAssertFalse(scheduler.isRunning)
        XCTAssertEqual(scheduler.pendingCount, 0)
    }

    func testInvalidationWaitsForUncancellableWorkAndRejectsItsResult() async {
        let scheduler = LatestPredictionScheduler<Int>()
        let started = expectation(description: "old started")
        let final = expectation(description: "new context")
        let release = DispatchSemaphore(value: 0)
        scheduler.submit(compute: {
            started.fulfill(); _ = release.wait(timeout: .now() + 5); return 1
        }, receive: { _, _ in XCTFail("Old page must not receive a callback") })
        await fulfillment(of: [started], timeout: 2)
        scheduler.invalidate()
        XCTAssertTrue(scheduler.isRunning, "Cancellation does not end real physics work")
        scheduler.submit(compute: { 2 }, receive: { value, latest in
            XCTAssertEqual(value, 2); XCTAssertTrue(latest); final.fulfill()
        })
        XCTAssertEqual(scheduler.pendingCount, 1)
        release.signal()
        await fulfillment(of: [final], timeout: 3)
    }

    func testAngleDiagramSuspendsDragAndInvalidatesRandomization() async throws {
        let vm = AngleDynamicViewModel()
        vm.setupScene()
        let cue = try XCTUnwrap(vm.scene.cueBallNode)
        let scale = cue.scale
        vm.dragBegan(node: cue)
        XCTAssertTrue(vm.isDragging)
        vm.randomizeBalls()
        vm.suspendTeachingActivity()
        XCTAssertFalse(vm.isDragging)
        XCTAssertEqual(cue.scale.x, scale.x, accuracy: 0.000001)
        XCTAssertFalse(cue.hasActions)
        // A late randomization callback must not replace a newer explicit choice.
        vm.selectedPocketIndex = -1
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertEqual(vm.selectedPocketIndex, -1)
        vm.resumeTeachingActivity()
        XCTAssertFalse(vm.isDragging)
        XCTAssertTrue(vm.cutAngleDegrees.isFinite)
    }

    func testAuthoringSuspensionPreservesRecordingAndLatestIntent() async throws {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        vm.clearTable()
        vm.usesContinuousTrajectoryPreview = true
        let y = vm.scene.surfaceY + BallPhysics.radius
        vm.placeFromPalette(PositionPlayBall.cueKey, atWorld: SCNVector3(-0.5, y, 0))
        vm.placeFromPalette("_1", atWorld: SCNVector3(0, y, 0))
        vm.aimMode = .free
        vm.handleTableTap(world: SCNVector3(0.5, y, 0))
        vm.startRecording()
        vm.renameSequence("Lifecycle fixture")
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let recorded = try encoder.encode(vm.sequence)
        vm.updateSpin(x: 0.12, y: 0.18)
        vm.suspendAuthoringActivity()
        XCTAssertFalse(vm.isPlaying)
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(try encoder.encode(vm.sequence), recorded)
        XCTAssertEqual(vm.spinX, 0.12)
        XCTAssertEqual(vm.spinY, 0.18)
        vm.resumeAuthoringActivity()
        let deadline = Date().addingTimeInterval(15)
        while vm.isComputing, Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        let shot = try XCTUnwrap(vm.solvedShot)
        XCTAssertEqual(shot.shot.spinX, 0.12)
        XCTAssertEqual(shot.shot.spinY, 0.18)
        vm.play()
        XCTAssertTrue(vm.isPlaying, "Fixture must start a real shot before suspension")
        vm.suspendAuthoringActivity()
        XCTAssertFalse(vm.isPlaying)
        XCTAssertEqual(try encoder.encode(vm.sequence), recorded, "Interrupted shots must not enter the recorded sequence")
        vm.clearTable()
    }

    func testBatchArchiveRoundTripRestoresEditingIntentInIsolatedDirectory() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source = root.appendingPathComponent("content/position_play/sequences/drill_c001__manual01-半台直线球 · 球形1-5杆.json")
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        var fixture = try decoder.decode(PositionPlaySequence.self, from: Data(contentsOf: source))
        fixture.steps = Array(fixture.steps.prefix(1))
        XCTAssertEqual(fixture.steps.count, 1)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: folder) }
            catch { XCTFail("Temporary archive cleanup failed: \(error)") }
        }
        let other = try BatchSequenceArchive.archive(fixture, drillId: "drill_c001", imageStem: "manual02", directory: folder.path)
        let otherBytes = try Data(contentsOf: other)
        let previous = try BatchSequenceArchive.archive(fixture, drillId: "drill_c001", imageStem: "manual01", directory: folder.path)
        fixture.name = "Remaining regression renamed"
        let saved = try BatchSequenceArchive.archive(fixture, drillId: "drill_c001", imageStem: "manual01", directory: folder.path)
        XCTAssertFalse(FileManager.default.fileExists(atPath: previous.path))
        XCTAssertEqual(try Data(contentsOf: other), otherBytes, "Replacing one formation must preserve another")
        let restored = try decoder.decode(PositionPlaySequence.self, from: Data(contentsOf: saved))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        XCTAssertEqual(try encoder.encode(restored.steps), try encoder.encode(fixture.steps))
        let vm = PositionPlayViewModel(); vm.setupScene(); vm.usesContinuousTrajectoryPreview = true
        defer { vm.suspendAuthoringActivity(); vm.clearTable() }
        let replay = vm.loadSequenceForEditing(restored)
        XCTAssertEqual(replay.total, 1); XCTAssertEqual(replay.replayed, 1)
        XCTAssertTrue(vm.isRecording)
        XCTAssertEqual(vm.sequence.name, fixture.name)
        XCTAssertEqual(try encoder.encode(vm.sequence.steps[0].shot), try encoder.encode(fixture.steps[0].shot))
        XCTAssertTrue(vm.canReplay, "Restored final step must remain available for re-editing")
    }

    func testBatchSolverSuspensionPreservesConstraintAndClearsBusyMessage() async throws {
        let vm = PositionPlayViewModel(); vm.setupScene()
        let solver = BatchShotSolver()
        solver.toolDrag(start: CanvasPoint(x: 0.3, y: 0.3), current: CanvasPoint(x: 0.6, y: 0.6),
                        ended: true, scene: vm.scene, surfaceY: vm.scene.surfaceY)
        solver.solve(composer: vm) { _ in XCTFail("Suspended solve must not apply its result") }
        XCTAssertTrue(solver.isComputing, "Fixture must enter the real solve")
        solver.suspend()
        XCTAssertFalse(solver.isComputing)
        XCTAssertTrue(solver.hasConstraint)
        XCTAssertTrue(solver.statusText.contains("已暂停"))
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertTrue(solver.statusText.contains("已暂停"))
        vm.clearTable()
    }

    func testOrdinaryFreePlayRankingComparisonUsesSameBoards() throws {
        let y = BTTablePhysics.surfaceY + AngleSceneCalculator.ballRadius
        var rows: [[String: Any]] = []
        for (index, cueXZ) in [(-0.65, 0.1), (-0.4, -0.3), (0.5, 0.3), (0.2, -0.1)].enumerated() {
            let cue = SCNVector3(Float(cueXZ.0), y, Float(cueXZ.1))
            let balls: [(String, SCNVector3)] = [("_1", SCNVector3(-0.1, y, 0.2)), ("_2", SCNVector3(0.3, y, -0.15))]
            let candidates = Dictionary(uniqueKeysWithValues: balls.map { key, position in
                (key, (0..<6).compactMap { pocket in
                    AngleSceneCalculator.dailyPocketCandidate(cue: cue, target: position, targetKey: key,
                        pocketIndex: pocket, obstacles: balls.filter { $0.0 != key }.map { $0.1 }, surfaceY: BTTablePhysics.surfaceY)
                })
            })
            let ordered = balls.sorted {
                AngleSceneCalculator.horizontalDistance(cue, $0.1) < AngleSceneCalculator.horizontalDistance(cue, $1.1)
            }.map { $0.0 }
            let original = candidates[ordered[0]]?.min { $0.targetPocketDistance < $1.targetPocketDistance }
            let proposed = AngleSceneCalculator.recommendDailyTarget(orderedKeys: ordered) { candidates[$0] ?? [] }
            let candidateRows = candidates.values.flatMap { $0 }.map { c -> [String: Any] in
                ["target": c.targetKey, "pocket": c.pocketIndex, "cut": c.cutDegrees,
                 "targetPocketDistance": c.targetPocketDistance, "score": c.score]
            }
            XCTAssertFalse(candidateRows.isEmpty)
            rows.append(["board": index, "cue": [cue.x, cue.z], "candidates": candidateRows,
                         "original": original.map { "\($0.targetKey):\($0.pocketIndex)" } ?? "none",
                         "proposed": proposed.map { "\($0.targetKey):\($0.pocketIndex)" } ?? "none"])
        }
        let data = try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "ordinary-free-play-ranking-comparison"; attachment.lifetime = .keepAlways; add(attachment)
        print("RANKING_COMPARISON " + String(decoding: data, as: UTF8.self))
    }

    func testBreakSuspensionPreservesRackSeedAndInput() async throws {
        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: false)
        let runner = BreakFlowRunner(scene: scene, game: .zhuifen(balls: 4), seed: 42)
        runner.rackUp()
        runner.velocity = 2
        runner.spinX = 0.1; runner.spinY = 0.1
        let positions = scene.allBallNodes.filter { !$0.value.isHidden }.mapValues(\.position)
        runner.breakNow()
        runner.suspendActivity()
        XCTAssertFalse(runner.isBusy)
        XCTAssertEqual(runner.phase, .racked)
        XCTAssertEqual(runner.seed, 42)
        XCTAssertEqual(runner.velocity, 2)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(runner.phase, .racked)
        for key in positions.keys {
            let before = try XCTUnwrap(positions[key])
            let after = try XCTUnwrap(scene.allBallNodes[key]).position
            XCTAssertEqual(before.x, after.x, accuracy: 0.00001)
            XCTAssertEqual(before.z, after.z, accuracy: 0.00001)
        }
        runner.resumeActivity()
        XCTAssertFalse(runner.isBusy)
        runner.cancel()
    }

    func testAtlasSuspensionRejectsResultsAndResumesBothPages() async throws {
        let separation = SeparationAngleAtlasViewModel()
        let english = CushionEnglishAtlasViewModel()
        separation.setupScene(); english.setupScene()
        separation.suspendTeachingActivity(); english.suspendTeachingActivity()
        try await Task.sleep(for: .milliseconds(800))
        XCTAssertFalse(separation.isComputing); XCTAssertFalse(english.isComputing)
        separation.resumeTeachingActivity(); english.resumeTeachingActivity()
        let deadline = Date().addingTimeInterval(45)
        while (separation.isComputing || english.isComputing), Date() < deadline {
            try await Task.sleep(for: .milliseconds(25))
        }
        XCTAssertFalse(separation.isComputing); XCTAssertFalse(english.isComputing)
    }

    func testDrillSuspensionCannotRestartFromOldTimer() async throws {
        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c078")
        let drill = try XCTUnwrap(loaded)
        let controller = DrillSceneController()
        controller.setup(drill: drill)
        controller.play()
        controller.suspendPlayback()
        let pausedState = controller.playbackState
        XCTAssertFalse(controller.isPlaying)
        try await Task.sleep(for: .seconds(2))
        XCTAssertEqual(controller.playbackState, pausedState)
        XCTAssertFalse(controller.scene.allBallNodes.values.contains { $0.hasActions })
    }

    private func verifyFreePreview<VM: SolverStageHosting>(_ vm: VM,
        prediction: () -> ShotPrediction?) async throws {
        vm.setupScene()
        vm.toggleMode()
        for i in 0..<30 {
            vm.nudgeFreeAim(byDegrees: 0.15)
            vm.updateFreeSpin(x: Double(i) / 150, y: -Double(i) / 200)
        }
        vm.updateFreeSpin(x: 0.2, y: -0.15)
        XCTAssertFalse(vm.canFreeStrike, "A changed input must wait for its own result")
        let deadline = Date().addingTimeInterval(30)
        while prediction() == nil, Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        let preview = try XCTUnwrap(prediction())
        let cue = try XCTUnwrap(vm.scene.cueBallNode)
        let target = try XCTUnwrap(vm.scene.targetBallNodes.first)
        let direct = ShotPredictor.simulateFree(cueBall: cue.position, aimDir: preview.aimDirection,
            velocity: Float(vm.reflectionPower), spinX: Float(vm.spinX), spinY: Float(vm.spinY),
            surfaceY: vm.scene.surfaceY, balls: [ObstacleBall(name: "_8", position: target.position)])
        XCTAssertEqual(preview.duration, direct.duration, accuracy: 0.0001)
        XCTAssertEqual(preview.pocketedBalls, direct.pocketedBalls)
        for (key, point) in preview.finalPositions {
            let actual = try XCTUnwrap(direct.finalPositions[key])
            XCTAssertEqual(point.x, actual.x, accuracy: 0.00001)
            XCTAssertEqual(point.z, actual.z, accuracy: 0.00001)
        }
        vm.stopForDismissal()
        XCTAssertFalse(vm.canFreeStrike)
        vm.resumeTeachingActivity()
        let resumed = Date().addingTimeInterval(30)
        while prediction() == nil, Date() < resumed { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertNotNil(prediction())
        vm.toggleMode()
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertNil(prediction(), "Free preview cannot survive a mode change")
        vm.stopForDismissal()
    }

    func testBankFreePreviewMatchesActualPhysicsAndSurvivesLifecycle() async throws {
        let vm = BankShotViewModel()
        try await verifyFreePreview(vm, prediction: { vm.freePreviewPrediction })
    }
    func testDiamondFreePreviewMatchesActualPhysicsAndSurvivesLifecycle() async throws {
        let vm = DiamondSystemViewModel()
        try await verifyFreePreview(vm, prediction: { vm.freePreviewPrediction })
    }
}

@MainActor
final class PlanningInformationStateTests: XCTestCase {
    func testRejectedTargetPersistsUntilRelevantSelectionChanges() throws {
        let vm = SnookerTacticsViewModel(); vm.setupScene()
        defer { vm.stopForDismissal() }
        vm.placeFromPalette("_8")
        vm.activeTool = .selectTarget
        let selected = vm.selectedTargetKey
        vm.selectBall(node: try XCTUnwrap(vm.scene.allBallNodes["_8"]))
        XCTAssertEqual(vm.selectedTargetKey, selected)
        XCTAssertEqual(vm.informationEvent.kind, .failure)
        let failure = vm.informationEvent.id
        vm.activeTool = .none
        XCTAssertEqual(vm.informationEvent.id, failure, "Switching tools does not fix an illegal selection")
        vm.activeTool = .selectTarget
        vm.selectBall(node: try XCTUnwrap(vm.scene.allBallNodes["_1"]))
        XCTAssertEqual(vm.informationEvent.kind, .context)
        XCTAssertNotEqual(vm.informationEvent.id, failure)
    }

    func testIncompletePredictionsHavePersistentTypedFailuresOnAllThreePages() {
        let silu = SiluTrainerViewModel(), plan = PlanThreeViewModel(), defense = SnookerTacticsViewModel()
        var prediction = ShotPredictor.simulateFree(
            cueBall: SCNVector3(0, BTTablePhysics.surfaceY + BallPhysics.radius, 0),
            aimDir: SCNVector3(1, 0, 0), velocity: 0.3, spinX: 0, spinY: 0,
            surfaceY: BTTablePhysics.surfaceY, balls: [])
        prediction.termination = .timeLimit
        XCTAssertFalse(silu.acceptCompletePrediction(prediction))
        XCTAssertFalse(plan.acceptCompletePrediction(prediction))
        XCTAssertFalse(defense.acceptCompletePrediction(prediction))
        for event in [silu.informationEvent, plan.informationEvent, defense.informationEvent] {
            XCTAssertEqual(event.kind, .failure)
            XCTAssertFalse(event.text.isEmpty)
            let notice = BTTeachingInformation(text: event.text, kind: .readout, showsSymbol: false)
            XCTAssertTrue(notice.isVisible(spinPadPresented: true))
            XCTAssertNil(notice.effectiveSymbol)
        }
        XCTAssertEqual(BTTeachingInformation(text: "Other page").effectiveSymbol, "info.circle")
    }

    func testCriticalCautionsUseSolutionFactsRatherThanSummaryCopy() {
        let prediction = ShotPredictor.simulateFree(
            cueBall: SCNVector3(0, BTTablePhysics.surfaceY + BallPhysics.radius, 0),
            aimDir: SCNVector3(1, 0, 0), velocity: 0.3, spinX: 0, spinY: 0,
            surfaceY: BTTablePhysics.surfaceY, balls: [])
        let solution = PositionPlaySolution(
            shot: PlannedShot(targetKey: "_1", pocket: "corner_1", velocity: 1, spinX: 0, spinY: 0),
            prediction: prediction, cushionCount: 2, potted: true, margin: 0, summary: "任意文案",
            satisfiesConstraint: false, beyondCushionBudget: true, beyondSpinBudget: true, isBankFallback: true)
        XCTAssertEqual(PlanningSolutionDetails.cautions(solution, defense: false), "翻袋备选 · 未满足约束 · 进阶 · 需横塞")
        XCTAssertTrue(PlanningSolutionDetails.cautions(solution, defense: true).contains("未完全斯诺克"))
        XCTAssertEqual(PlanningSolutionDetails.cautions(nil, defense: false), "")
    }
}
