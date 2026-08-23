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
            ActiveDrill(drillId: "drill_c053", nameZh: "中袋角度球", sets: 1, ballsPerSet: 10,
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

    // MARK: - v31 W2: 多球形组展开

    /// 自由训练加入多球形 drill：组序列按「球形 1 轮 1 → … → 球形 N 轮 M」展开，
    /// 且逐组预填对应球形（替代旧行为「全部预填第一个球形」）。
    func test_addDrill_multiFormation_expandsWithPerSetFormationToken() throws {
        let content = try XCTUnwrap(DrillContentService.decodeDrillFromBundle(id: "drill_c013"))
        let perFormation = try XCTUnwrap(content.sets.perFormation)
        try XCTSkipIf(perFormation.count < 2, "drill_c013 非多球形")

        let vm = ActiveTrainingViewModel(mode: .free)
        vm.addDrill(content)

        let sets = vm.drillSetsData[0]
        let expectedTokens = perFormation.flatMap {
            Array(repeating: $0.token, count: $0.defaultRounds)
        }
        XCTAssertEqual(sets.map(\.formationToken), expectedTokens)
        XCTAssertEqual(sets.map(\.targetBalls),
                       perFormation.flatMap {
                           Array(repeating: $0.ballsPerRound, count: $0.defaultRounds)
                       })
        XCTAssertEqual(sets.map(\.id), Array(1...sets.count))
        XCTAssertFalse(sets.contains { $0.formationName == nil })

        print("[W2-EVIDENCE] free-mode c013 sets: "
              + sets.map { "#\($0.id) \($0.formationToken ?? "nil")/\($0.targetBalls)" }
                  .joined(separator: " | "))
    }

    /// 逐球形球数异构时，每组 target 跟着自己的球形走。
    /// W2 后 c053 两球形均为 bpr=15 不再异构；改锚仍异构的 c069（sequence 10 + repetition 15），与 W4 同口径。
    func test_addDrill_heterogeneousFormations_perSetTargets() throws {
        let content = try XCTUnwrap(DrillContentService.decodeDrillFromBundle(id: "drill_c069"))
        let perFormation = try XCTUnwrap(content.sets.perFormation)
        XCTAssertGreaterThan(Set(perFormation.map(\.ballsPerRound)).count, 1,
                             "drill_c069 应为逐球形球数异构")

        let vm = ActiveTrainingViewModel(mode: .free)
        vm.addDrill(content)

        XCTAssertEqual(vm.drillSetsData[0].map(\.targetBalls),
                       perFormation.flatMap {
                           Array(repeating: $0.ballsPerRound, count: $0.defaultRounds)
                       })
    }

    /// 计划训练：`TodayDrillItem.plannedSets` 原样落到录入行（含逐组球形与球数）。
    func test_loadDrills_planMode_usesPlannedSets() async {
        let planned = [
            PlannedTrainingSet(formationToken: "manual01", formationName: "球形1",
                               targetBalls: 8, mode: .sequence),
            PlannedTrainingSet(formationToken: "manual02", formationName: "球形2",
                               targetBalls: 9, mode: .repetition),
            PlannedTrainingSet(formationToken: "manual02", formationName: "球形2",
                               targetBalls: 9, mode: .repetition),
        ]
        let item = TodayDrillItem(
            id: "focused_drill_c013", drillId: "drill_c013", nameZh: "底袋小角度",
            phaseType: "focused", phaseZh: "专项训练", phaseIcon: "target",
            plannedSets: planned, volumeText: "2 球形 · 3 轮 · 共 26 球", isCompleted: false
        )
        let vm = ActiveTrainingViewModel(mode: .plan(drills: [item], planId: "plan_test"))
        await vm.loadDrills()

        XCTAssertEqual(vm.drills.count, 1)
        XCTAssertEqual(vm.drills[0].plannedSets, planned)
        XCTAssertEqual(vm.drillSetsData[0].map(\.targetBalls), [8, 9, 9])
        XCTAssertEqual(vm.drillSetsData[0].map(\.formationToken),
                       ["manual01", "manual02", "manual02"])
    }

    /// 手动「加一组」复制当前位置（首个未完成组），而非末组。
    func test_addSet_copiesCurrentActiveSet() {
        let vm = ActiveTrainingViewModel(mode: .free)
        vm.drills = [ActiveDrill(
            drillId: "drill_c013", nameZh: "多球形",
            plannedSets: [
                PlannedTrainingSet(formationToken: "manual01", formationName: "球形1",
                                   targetBalls: 8, mode: .repetition),
                PlannedTrainingSet(formationToken: "manual02", formationName: "球形2",
                                   targetBalls: 13, mode: .repetition),
            ]
        )]
        vm.drillSetsData = [[
            DrillSetData(id: 1, targetBalls: 8, formationToken: "manual01", formationName: "球形1"),
            DrillSetData(id: 2, targetBalls: 13, formationToken: "manual02", formationName: "球形2"),
        ]]
        // 当前位置 = 组1（未完成），即使末组是球形2
        vm.addSet(drillIndex: 0)

        let added = vm.drillSetsData[0][2]
        XCTAssertEqual(added.id, 3)
        XCTAssertEqual(added.targetBalls, 8)
        XCTAssertEqual(added.formationToken, "manual01")
    }

    /// 全部完成后「加一组」回落末组（同 token / 同球数）。
    func test_addSet_whenAllCompleted_fallsBackToLast() {
        let vm = ActiveTrainingViewModel(mode: .free)
        vm.drills = [ActiveDrill(
            drillId: "drill_c013", nameZh: "多球形",
            plannedSets: [
                PlannedTrainingSet(formationToken: "manual01", formationName: "球形1",
                                   targetBalls: 8, mode: .repetition),
                PlannedTrainingSet(formationToken: "manual02", formationName: "球形2",
                                   targetBalls: 13, mode: .repetition),
            ]
        )]
        vm.drillSetsData = [[
            DrillSetData(id: 1, madeBalls: 8, targetBalls: 8, isCompleted: true,
                         formationToken: "manual01", formationName: "球形1"),
            DrillSetData(id: 2, madeBalls: 13, targetBalls: 13, isCompleted: true,
                         formationToken: "manual02", formationName: "球形2"),
        ]]
        vm.addSet(drillIndex: 0)
        let added = vm.drillSetsData[0][2]
        XCTAssertEqual(added.targetBalls, 13)
        XCTAssertEqual(added.formationToken, "manual02")
    }

    /// 结构化加组（v34 后续）：指定球形与杆号，新组插到同球形分节末尾而非整表末尾。
    func test_addSet_withChoice_insertsIntoFormationSection() {
        let vm = ActiveTrainingViewModel(mode: .free)
        vm.drills = [ActiveDrill(
            drillId: "drill_c013", nameZh: "多球形",
            plannedSets: [
                PlannedTrainingSet(formationToken: "manual01", formationName: "球形1",
                                   targetBalls: 8, mode: .repetition),
                PlannedTrainingSet(formationToken: "manual02", formationName: "球形2",
                                   targetBalls: 13, mode: .repetition),
            ]
        )]
        vm.drillSetsData = [[
            DrillSetData(id: 1, targetBalls: 8, formationToken: "manual01", formationName: "球形1",
                         mode: .repetition, shotIndex: 1, isFormationLocked: true),
            DrillSetData(id: 2, targetBalls: 13, formationToken: "manual02", formationName: "球形2",
                         mode: .repetition, shotIndex: 1, isFormationLocked: true),
        ]]
        let choice = DrillAddSetChoice(
            token: "manual01", name: "球形1", mode: .repetition, shotCount: 5, targetBalls: 8
        )
        vm.addSet(drillIndex: 0, choice: choice, shotIndex: 3)

        let sets = vm.drillSetsData[0]
        XCTAssertEqual(sets.count, 3)
        // 插在球形1分节末尾（index 1），不是整表末尾。
        let added = sets[1]
        XCTAssertEqual(added.formationToken, "manual01")
        XCTAssertEqual(added.shotIndex, 3)
        XCTAssertEqual(added.targetBalls, 8)
        XCTAssertEqual(added.id, 3, "id 取 max+1，避免与既有组撞号")
        XCTAssertFalse(added.isFormationLocked, "手动加组球形可改选")
        // 原球形2组顺延到末尾。
        XCTAssertEqual(sets[2].formationToken, "manual02")
    }

    /// 加组选项：按计划组序列聚合出每球形一项，带模式与序列杆数。
    func test_addSetChoices_aggregatesPerFormation() async throws {
        let content = try XCTUnwrap(DrillContentService.decodeDrillFromBundle(id: "drill_c026"))
        let vm = ActiveTrainingViewModel(mode: .free)
        vm.addDrill(content)

        let choices = vm.addSetChoices(at: 0)
        XCTAssertEqual(choices.count, 3, "c026 三球形应各出一项：\(choices.map(\.id))")
        XCTAssertTrue(choices.allSatisfy { $0.mode == .repetition })
        // 序列杆数来自 DrillBoards 序列文件（manual01=5 / manual02=7 / manual03=5 杆）。
        XCTAssertEqual(choices.map(\.shotCount), [5, 7, 5])
        print("[v34后续-EVIDENCE] c026 addSetChoices: "
              + choices.map { "\($0.id) mode=\($0.mode.map(String.init(describing:)) ?? "nil") shots=\($0.shotCount) balls=\($0.targetBalls)" }
                  .joined(separator: " | "))
    }

    /// 计划组序列 → 录入行：重复型逐组带真实杆位 shotIndex，且球形锁定。
    func test_makeSetData_assignsShotIndexAndLocksFormation() async {
        let planned = [
            PlannedTrainingSet(formationToken: "manual01", formationName: "球形1",
                               targetBalls: 8, mode: .repetition),
            PlannedTrainingSet(formationToken: "manual01", formationName: "球形1",
                               targetBalls: 8, mode: .repetition),
            PlannedTrainingSet(formationToken: "manual02", formationName: "球形2",
                               targetBalls: 9, mode: .sequence),
        ]
        let item = TodayDrillItem(
            id: "focused_drill_c013", drillId: "drill_c013", nameZh: "底袋小角度",
            phaseType: "focused", phaseZh: "专项训练", phaseIcon: "target",
            plannedSets: planned, volumeText: "", isCompleted: false
        )
        let vm = ActiveTrainingViewModel(mode: .plan(drills: [item], planId: "plan_test"))
        await vm.loadDrills()

        let sets = vm.drillSetsData[0]
        XCTAssertEqual(sets.map(\.shotIndex), [1, 2, nil],
                       "重复型逐组杆位递增；走位链无杆位")
        XCTAssertTrue(sets.allSatisfy(\.isFormationLocked), "计划自带组球形应锁定")
    }

    /// c026 计划路径：plannedSets 必须带 token，供训练页分节。
    func test_c026_planMode_plannedSetsCarryFormationTokens() async throws {
        let content = try XCTUnwrap(DrillContentService.decodeDrillFromBundle(id: "drill_c026"))
        let options = TrainingDoseResolver.formationOptions(forDrillId: "drill_c026")
        XCTAssertGreaterThan(options.count, 1)
        let resolved = TrainingDoseResolver.resolve(content: content, formationOptions: options)
        let tokens = Set(resolved.plannedSets.compactMap(\.formationToken))
        XCTAssertGreaterThan(tokens.count, 1, "多球形应快照 token：\(resolved.plannedSets)")

        let item = TodayDrillItem(
            id: "uitest_c026", drillId: "drill_c026", nameZh: content.nameZh,
            phaseType: "focused", phaseZh: "专项", phaseIcon: "target",
            plannedSets: resolved.plannedSets,
            volumeText: resolved.volumeText(unitLabel: "球"),
            isCompleted: false
        )
        let vm = ActiveTrainingViewModel(mode: .plan(drills: [item], planId: "uitest"))
        await vm.loadDrills()
        let setTokens = Set(vm.drillSetsData[0].compactMap(\.formationToken))
        XCTAssertEqual(setTokens, tokens)
    }

    /// R12（杆位口径）：重复型多球形进度「球形 x/y · 第 m/n 杆 · 第 k 颗」。
    func test_currentSetProgressText_repetitionMultiFormation() {
        let vm = ActiveTrainingViewModel(mode: .free)
        vm.drills = [ActiveDrill(
            drillId: "drill_c026", nameZh: "厚球分离角",
            plannedSets: [
                PlannedTrainingSet(formationToken: "t1", formationName: "球形1",
                                   targetBalls: 15, mode: .repetition),
                PlannedTrainingSet(formationToken: "t1", formationName: "球形1",
                                   targetBalls: 15, mode: .repetition),
                PlannedTrainingSet(formationToken: "t2", formationName: "球形2",
                                   targetBalls: 15, mode: .repetition),
            ]
        )]
        vm.drillSetsData = [[
            DrillSetData(id: 1, madeBalls: 15, targetBalls: 15, isCompleted: true,
                         formationToken: "t1", formationName: "球形1"),
            DrillSetData(id: 2, madeBalls: 3, targetBalls: 15,
                         formationToken: "t1", formationName: "球形1"),
            DrillSetData(id: 3, targetBalls: 15, formationToken: "t2", formationName: "球形2"),
        ]]
        vm.currentDrillIndex = 0
        XCTAssertEqual(vm.currentSetProgressText, "球形 1/2 · 第 2/2 杆 · 第 4 颗")
    }

    /// R12（杆位口径）：走位链报「第 r 遍 · 第 k/n 杆」。
    func test_currentSetProgressText_sequenceReportsRoundOnly() {
        let vm = ActiveTrainingViewModel(mode: .free)
        vm.drills = [ActiveDrill(
            drillId: "drill_c039", nameZh: "直线球组合走位",
            plannedSets: [
                PlannedTrainingSet(formationToken: nil, formationName: nil,
                                   targetBalls: 8, mode: .sequence),
                PlannedTrainingSet(formationToken: nil, formationName: nil,
                                   targetBalls: 8, mode: .sequence),
            ]
        )]
        vm.drillSetsData = [[
            DrillSetData(id: 1, madeBalls: 8, targetBalls: 8, isCompleted: true),
            DrillSetData(id: 2, madeBalls: 2, targetBalls: 8),
        ]]
        // 第 2 遍进行中，已进 2 杆 ⇒ 当前是链内第 3/8 杆
        XCTAssertEqual(vm.currentSetProgressText, "第 2 遍 · 第 3/8 杆")
    }

    /// R12：单球形不显示「球形 x/y」。
    func test_currentSetProgressText_singleFormationOmitsFormationLevel() {
        let vm = ActiveTrainingViewModel(mode: .free)
        vm.drills = [ActiveDrill(
            drillId: "drill_c001", nameZh: "半台直线球",
            plannedSets: [
                PlannedTrainingSet(formationToken: nil, formationName: nil,
                                   targetBalls: 15, mode: .repetition),
                PlannedTrainingSet(formationToken: nil, formationName: nil,
                                   targetBalls: 15, mode: .repetition),
            ]
        )]
        vm.drillSetsData = [[
            DrillSetData(id: 1, targetBalls: 15),
            DrillSetData(id: 2, targetBalls: 15),
        ]]
        let text = vm.currentSetProgressText
        XCTAssertFalse(text.contains("球形"))
        XCTAssertEqual(text, "第 1/2 杆 · 第 1 颗")
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
