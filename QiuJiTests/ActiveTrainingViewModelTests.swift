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
        let vm = ActiveTrainingViewModel(mode: .plan(drills: []))
        XCTAssertTrue(vm.isPlanMode)
    }

    // MARK: - Formatted time

    func test_formattedTime_zero() {
        let vm = ActiveTrainingViewModel(mode: .free)
        XCTAssertEqual(vm.formattedTime, "00:00")
    }

    func test_formattedTime_65_seconds() {
        let vm = ActiveTrainingViewModel(mode: .free)
        vm.elapsedSeconds = 65
        XCTAssertEqual(vm.formattedTime, "01:05")
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
        vm.ballsMadeRecords = [[7, 8]]
        XCTAssertEqual(vm.overallSuccessRate, 0.75, accuracy: 0.001)
    }

    func test_drillSummaries_sorted_by_success_rate() {
        let vm = makeVMWithDrills(count: 2, sets: 1, ballsPerSet: 10)
        vm.ballsMadeRecords = [[3], [8]]
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
        vm.ballsMadeRecords = [[7, 8]]
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
        XCTAssertEqual(entry?.sets.first?.madeBalls, 7)
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
        vm.currentSetIndices = vm.drills.map { _ in 0 }
        vm.ballsMadeRecords = vm.drills.map { Array(repeating: 0, count: $0.sets) }
        return vm
    }
}
