import XCTest
import SwiftData
@testable import QiuJi

@MainActor
final class ActiveTrainingViewModelTests: XCTestCase {

    // MARK: - Free mode init

    func test_freeMode_initial_state() {
        let vm = ActiveTrainingViewModel(mode: .free)
        XCTAssertTrue(vm.drills.isEmpty)
        XCTAssertEqual(vm.currentDrillIndex, 0)
        XCTAssertEqual(vm.elapsedSeconds, 0)
        XCTAssertFalse(vm.isTimerRunning)
        XCTAssertFalse(vm.isTimerSkipped)
        XCTAssertEqual(vm.trainingPhase, .active)
        XCTAssertTrue(vm.trainingNote.isEmpty)
        XCTAssertNil(vm.saveError)
        XCTAssertFalse(vm.didSaveSuccessfully)
        XCTAssertFalse(vm.isPlanMode)
    }

    func test_planMode_isPlanMode() {
        let vm = ActiveTrainingViewModel(mode: .plan(drills: [], planId: "plan_beginner_12w"))
        XCTAssertTrue(vm.isPlanMode)
    }

    // MARK: - Formatted time

    func test_formattedTime_zero() {
        let vm = ActiveTrainingViewModel(mode: .free)
        XCTAssertEqual(vm.formattedTime, "00:00:00")
    }

    func test_formattedTime_65_seconds() {
        let vm = ActiveTrainingViewModel(mode: .free)
        vm.elapsedSeconds = 65
        XCTAssertEqual(vm.formattedTime, "00:01:05")
    }

    // MARK: - Progress

    func test_progress_empty_drills() {
        let vm = ActiveTrainingViewModel(mode: .free)
        XCTAssertEqual(vm.progress, 0)
        XCTAssertTrue(vm.progressText.isEmpty)
    }

    // MARK: - Timer

    func test_skipTimer() {
        let vm = ActiveTrainingViewModel(mode: .free)
        vm.skipTimer()
        XCTAssertTrue(vm.isTimerSkipped)
        XCTAssertFalse(vm.isTimerRunning)
    }

    func test_unskipTimer() {
        let vm = ActiveTrainingViewModel(mode: .free)
        vm.skipTimer()
        vm.unskipTimer()
        XCTAssertFalse(vm.isTimerSkipped)
    }

    func test_startTimer_when_skipped_does_not_start() {
        let vm = ActiveTrainingViewModel(mode: .free)
        vm.skipTimer()
        vm.startTimer()
        XCTAssertFalse(vm.isTimerRunning)
    }

    func test_pauseTimer_stops() {
        let vm = ActiveTrainingViewModel(mode: .free)
        vm.startTimer()
        XCTAssertTrue(vm.isTimerRunning)
        vm.pauseTimer()
        XCTAssertFalse(vm.isTimerRunning)
    }

    func test_toggleTimer() {
        let vm = ActiveTrainingViewModel(mode: .free)
        vm.toggleTimer()
        XCTAssertTrue(vm.isTimerRunning)
        vm.toggleTimer()
        XCTAssertFalse(vm.isTimerRunning)
    }

    // MARK: - Drill navigation

    func test_goToDrill_valid_index() {
        let vm = makeVMWithDrills(count: 3)
        vm.goToDrill(at: 2)
        XCTAssertEqual(vm.currentDrillIndex, 2)
    }

    func test_goToDrill_negative_ignored() {
        let vm = makeVMWithDrills(count: 3)
        vm.goToDrill(at: -1)
        XCTAssertEqual(vm.currentDrillIndex, 0)
    }

    func test_goToDrill_out_of_bounds_ignored() {
        let vm = makeVMWithDrills(count: 3)
        vm.goToDrill(at: 5)
        XCTAssertEqual(vm.currentDrillIndex, 0)
    }

    // MARK: - Recording: increment / decrement

    func test_incrementBalls() {
        let vm = makeVMWithDrills(count: 1)
        vm.incrementBalls()
        XCTAssertEqual(vm.currentBallsMade, 1)
    }

    func test_incrementBalls_caps_at_ballsPerSet() {
        let vm = makeVMWithDrills(count: 1, ballsPerSet: 3)
        for _ in 0..<10 {
            vm.incrementBalls()
        }
        XCTAssertEqual(vm.currentBallsMade, 3)
    }

    func test_decrementBalls_at_zero() {
        let vm = makeVMWithDrills(count: 1)
        vm.decrementBalls()
        XCTAssertEqual(vm.currentBallsMade, 0)
    }

    func test_decrementBalls() {
        let vm = makeVMWithDrills(count: 1)
        vm.incrementBalls()
        vm.incrementBalls()
        vm.decrementBalls()
        XCTAssertEqual(vm.currentBallsMade, 1)
    }

    // MARK: - Complete set

    func test_completeCurrentSet_advances_set() {
        let vm = makeVMWithDrills(count: 1, sets: 3)
        XCTAssertEqual(vm.currentSetIndex, 0)
        vm.completeCurrentSet()
        XCTAssertEqual(vm.currentSetIndex, 1)
    }

    func test_completeCurrentSet_last_set_advances_drill() {
        let vm = makeVMWithDrills(count: 2, sets: 1)
        vm.completeCurrentSet() // complete drill 0's only set
        XCTAssertEqual(vm.currentDrillIndex, 1)
    }

    func test_isCurrentDrillAllSetsCompleted() {
        let vm = makeVMWithDrills(count: 1, sets: 2)
        XCTAssertFalse(vm.isCurrentDrillAllSetsCompleted)
        vm.completeCurrentSet()
        XCTAssertFalse(vm.isCurrentDrillAllSetsCompleted)
        vm.completeCurrentSet()
        XCTAssertTrue(vm.isCurrentDrillAllSetsCompleted)
    }

    // MARK: - End training flow

    func test_endTraining_transitions_to_note() {
        let vm = ActiveTrainingViewModel(mode: .free)
        vm.endTraining()
        XCTAssertEqual(vm.trainingPhase, .note)
    }

    func test_skipNote_clears_note_goes_to_summary() {
        let vm = ActiveTrainingViewModel(mode: .free)
        vm.trainingNote = "some text"
        vm.skipNote()
        XCTAssertTrue(vm.trainingNote.isEmpty)
        XCTAssertEqual(vm.trainingPhase, .summary)
    }

    func test_submitNote_goes_to_summary() {
        let vm = ActiveTrainingViewModel(mode: .free)
        vm.trainingNote = "great session"
        vm.submitNote()
        XCTAssertEqual(vm.trainingPhase, .summary)
        XCTAssertEqual(vm.trainingNote, "great session")
    }

    // MARK: - Summary statistics

    func test_totalSets() {
        let vm = makeVMWithDrills(count: 2, sets: 3)
        XCTAssertEqual(vm.totalSets, 6)
    }

    func test_overallSuccessRate_no_drills() {
        let vm = ActiveTrainingViewModel(mode: .free)
        XCTAssertEqual(vm.overallSuccessRate, 0)
    }

    func test_overallSuccessRate_calculated() {
        let vm = makeVMWithDrills(count: 1, sets: 2, ballsPerSet: 10)
        vm.drillSetsData[0][0].madeBalls = 7
        vm.drillSetsData[0][1].madeBalls = 8
        XCTAssertEqual(vm.overallSuccessRate, 0.75, accuracy: 0.001)
    }

    func test_drillSummaries_sorted_by_success_rate() {
        let vm = makeVMWithDrills(count: 2, sets: 1, ballsPerSet: 10)
        vm.drillSetsData[0][0].madeBalls = 3
        vm.drillSetsData[1][0].madeBalls = 8
        let summaries = vm.drillSummaries
        XCTAssertEqual(summaries.count, 2)
        XCTAssertGreaterThanOrEqual(summaries[0].successRate, summaries[1].successRate)
    }

    // MARK: - Save training (SwiftData)

    func test_saveTraining_success() {
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        SyncQueueManager.shared.configure(context: context)

        let vm = makeVMWithDrills(count: 1, sets: 2, ballsPerSet: 10)
        vm.drillSetsData[0][0].madeBalls = 7
        vm.drillSetsData[0][1].madeBalls = 8
        vm.trainingNote = "test note"
        vm.elapsedSeconds = 120

        vm.saveTraining(context: context)

        XCTAssertTrue(vm.didSaveSuccessfully)
        XCTAssertNil(vm.saveError)

        let sessions = try? context.fetch(FetchDescriptor<TrainingSession>())
        XCTAssertEqual(sessions?.count, 1)

        let session = sessions?.first
        XCTAssertEqual(session?.note, "test note")
        XCTAssertEqual(session?.totalDurationMinutes, 2) // 120 / 60
        XCTAssertEqual(session?.drillEntries.count, 1)

        let entry = session?.drillEntries.first
        XCTAssertEqual(entry?.sets.count, 2)
        let sortedSets = entry?.sets.sorted { $0.setNumber < $1.setNumber }
        XCTAssertEqual(sortedSets?.first?.madeBalls, 7)
    }

    func test_saveTraining_empty_drills() {
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext

        let vm = ActiveTrainingViewModel(mode: .free)
        vm.saveTraining(context: context)

        XCTAssertTrue(vm.didSaveSuccessfully)
        let sessions = try? context.fetch(FetchDescriptor<TrainingSession>())
        XCTAssertEqual(sessions?.count, 1)
        XCTAssertEqual(sessions?.first?.drillEntries.count, 0)
    }

    // MARK: - v29 W4: 新字段落库实证

    /// W4 唯一硬证据：一次真实 `saveTraining` 后，读回的 session/entry/set
    /// 必须在每个新字段上都拿到**非默认值**（不是「编译过了」也不是「UI 上看着对」）。
    func test_saveTraining_persistsW4Fields_withNonDefaultValues() throws {
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        SyncQueueManager.shared.configure(context: context)

        let vm = ActiveTrainingViewModel(
            mode: .plan(drills: [], planId: "plan_beginner_12w")
        )
        vm.drills = [
            ActiveDrill(drillId: "drill_c065", nameZh: "Ghost Game 对抗", sets: 2, ballsPerSet: 10,
                        category: "combined", subcategory: "ghostGame",
                        standardCriteria: "10局Ghost Game中赢3局以上"),
            ActiveDrill(drillId: "drill_c053", nameZh: "中袋角度精准", sets: 1, ballsPerSet: 10,
                        category: "accuracy", subcategory: "sidePocket",
                        standardCriteria: "每个球形10球进6球"),
        ]
        vm.drillSetsData = [
            [
                DrillSetData(id: 1, madeBalls: 4, targetBalls: 10, isCompleted: true, duration: 95.4),
                DrillSetData(id: 2, madeBalls: 6, targetBalls: 10, isCompleted: true, duration: 130.0),
            ],
            [
                DrillSetData(id: 1, madeBalls: 7, targetBalls: 10, isCompleted: true, duration: 61.2,
                             formationToken: "manual02", formationName: "中袋角度精准 · 球形2"),
            ],
        ]
        vm.drillNotes = ["开球后清台率偏低", "薄球容易吃厚"]
        vm.trainingNote = "整体状态不错"
        vm.elapsedSeconds = 1800

        vm.saveTraining(context: context)
        XCTAssertTrue(vm.didSaveSuccessfully)
        XCTAssertNil(vm.saveError)

        let sessions = try context.fetch(FetchDescriptor<TrainingSession>())
        let session = try XCTUnwrap(sessions.first)

        // session.kind / planId
        XCTAssertEqual(session.kind, "drill")
        XCTAssertEqual(session.planId, "plan_beginner_12w")

        let entries = session.drillEntries.sorted { $0.orderIndex < $1.orderIndex }
        XCTAssertEqual(entries.count, 2)

        // DrillEntry.orderIndex / note / criteriaText
        XCTAssertEqual(entries.map(\.orderIndex), [0, 1])
        XCTAssertEqual(entries[0].note, "开球后清台率偏低")
        XCTAssertEqual(entries[1].note, "薄球容易吃厚")
        XCTAssertEqual(entries[0].criteriaText, "10局Ghost Game中赢3局以上")
        XCTAssertEqual(entries[1].criteriaText, "每个球形10球进6球")

        // DrillSet.durationSeconds / unitLabel / passMade,passTotal
        let ghostSets = entries[0].sets.sorted { $0.setNumber < $1.setNumber }
        XCTAssertEqual(ghostSets.map(\.durationSeconds), [95, 130])
        XCTAssertEqual(ghostSets.map(\.unitLabel), ["局", "局"])       // ghostGame → 局
        XCTAssertEqual(ghostSets.map(\.passMade), [0, 0])              // D-v29-1：未设定
        XCTAssertEqual(ghostSets.map(\.passTotal), [0, 0])
        XCTAssertNil(ghostSets[0].formationToken)                      // 未选球形保持 nil

        // DrillSet.formationToken / formationName（多球形 drill）
        let sidePocketSet = try XCTUnwrap(entries[1].sets.first)
        XCTAssertEqual(sidePocketSet.formationToken, "manual02")
        XCTAssertEqual(sidePocketSet.formationName, "中袋角度精准 · 球形2")
        XCTAssertEqual(sidePocketSet.unitLabel, "球")
        XCTAssertEqual(sidePocketSet.durationSeconds, 61)

        // 落库实证输出（W4 完成标准 3 的证据来源）
        print("[W4-EVIDENCE] session.kind=\(session.kind) planId=\(session.planId ?? "nil")")
        for entry in entries {
            print("[W4-EVIDENCE] entry order=\(entry.orderIndex) drill=\(entry.drillId) "
                  + "note=\"\(entry.note)\" criteria=\"\(entry.criteriaText)\"")
            for set in entry.sets.sorted(by: { $0.setNumber < $1.setNumber }) {
                print("[W4-EVIDENCE]   set#\(set.setNumber) made=\(set.madeBalls)/\(set.targetBalls) "
                      + "unit=\(set.unitLabel) duration=\(set.durationSeconds.map(String.init) ?? "nil") "
                      + "formation=\(set.formationToken ?? "nil")/\(set.formationName ?? "nil") "
                      + "pass=\(set.passMade)/\(set.passTotal)")
            }
        }
    }

    /// 自由训练不得被误算成计划训练（W7 推进判定的前提）。
    func test_saveTraining_freeMode_leavesPlanIdNil() throws {
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        SyncQueueManager.shared.configure(context: context)

        let vm = makeVMWithDrills(count: 1, sets: 1, ballsPerSet: 10)
        vm.saveTraining(context: context)

        let session = try XCTUnwrap(try context.fetch(FetchDescriptor<TrainingSession>()).first)
        XCTAssertNil(session.planId)
        XCTAssertEqual(session.kind, "drill")
    }

    // MARK: - v29 W4: 单位语义

    func test_unitLabel_derivedFromSubcategory() {
        XCTAssertEqual(DrillUnitLabel.label(category: "combined", subcategory: "ghostGame"), "局")
        XCTAssertEqual(DrillUnitLabel.label(category: "combined", subcategory: "runOut"), "次")
        XCTAssertEqual(DrillUnitLabel.label(category: "specialShots", subcategory: "escape"), "次")
        XCTAssertEqual(DrillUnitLabel.label(category: "combined", subcategory: "snakeDrill"), "球")
        XCTAssertEqual(DrillUnitLabel.label(category: "accuracy", subcategory: "straight"), "球")
        XCTAssertEqual(DrillUnitLabel.label(category: "", subcategory: ""), "球")
    }

    // MARK: - v29 W4: 球形选项

    /// 单球形 drill 不出选择 UI（返回空数组）；多球形返回全部球形。
    func test_formationOptions_singleFormationDrillReturnsEmpty() throws {
        let all = DrillTryoutBoardStore.formations(for: "drill_c001")
        try XCTSkipIf(all.isEmpty, "drill_c001 无 Bundle 序列")
        XCTAssertEqual(all.count, 1)
        XCTAssertTrue(ActiveTrainingViewModel.formationOptions(for: "drill_c001").isEmpty)
    }

    func test_formationOptions_multiFormationDrillReturnsAll() throws {
        let all = DrillTryoutBoardStore.formations(for: "drill_c053")
        try XCTSkipIf(all.count < 2, "drill_c053 非多球形")
        let options = ActiveTrainingViewModel.formationOptions(for: "drill_c053")
        XCTAssertEqual(options.count, all.count)
        XCTAssertEqual(options.map(\.token), all.map(\.token))
        XCTAssertFalse(options.contains { $0.token.isEmpty })
    }

    // MARK: - Cleanup

    func test_cleanup_stops_timer() {
        let vm = ActiveTrainingViewModel(mode: .free)
        vm.startTimer()
        XCTAssertTrue(vm.isTimerRunning)
        vm.cleanup()
        XCTAssertFalse(vm.isTimerRunning)
    }

    // MARK: - Helpers

    private func makeVMWithDrills(count: Int, sets: Int = 3, ballsPerSet: Int = 10) -> ActiveTrainingViewModel {
        let vm = ActiveTrainingViewModel(mode: .free)
        for i in 0..<count {
            let drill = ActiveDrill(
                drillId: "drill_test_\(i)",
                nameZh: "测试动作\(i)",
                sets: sets,
                ballsPerSet: ballsPerSet
            )
            vm.drills.append(drill)
        }
        vm.drillSetsData = vm.drills.map { drill in
            (1...drill.sets).map { setNum in
                DrillSetData(id: setNum, targetBalls: drill.ballsPerSet)
            }
        }
        vm.drillNotes = vm.drills.map { _ in "" }
        return vm
    }
}
