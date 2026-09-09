import XCTest
import SwiftData
@testable import QiuJi

/// Snapshot-003 diagnostic. Failures preserve the QD012 product expectation.
/// This is real VM save/fetch in a private in-memory store, not process/disk restoration.
@MainActor
final class CurrentPartialSaveDiagnosticTests: XCTestCase {
    func testEarlyEndFiveOfFifteenCountsOnlyExplicitlyCompletedGroup() throws {
        try verifySave(plannedGroups: 8, completedMade: [5], expectedGroups: 1,
                       expectedMade: 5, expectedTargets: 15)
    }

    func testEarlyEndExplicitZeroGroupRetainsItsFifteenAttemptsOnly() throws {
        try verifySave(plannedGroups: 8, completedMade: [0], expectedGroups: 1,
                       expectedMade: 0, expectedTargets: 15)
    }

    func testFullyCompletedZeroGroupIsNotDiscarded() throws {
        try verifySave(plannedGroups: 1, completedMade: [0], expectedGroups: 1,
                       expectedMade: 0, expectedTargets: 15)
    }

    private func verifySave(plannedGroups: Int, completedMade: [Int], expectedGroups: Int,
                            expectedMade: Int, expectedTargets: Int,
                            file: StaticString = #filePath, line: UInt = #line) throws {
        let schema = ModelContainerFactory.currentSchema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TrainingSession>()), 0, file: file, line: line)
        let vm = ActiveTrainingViewModel(mode: .free, liveActivityManager: PartialSaveSilentActivity())
        defer { vm.stopRestTimer(); vm.cleanup() }
        vm.restDuration = 0
        vm.drills = [ActiveDrill(drillId: "qd012-private-fixture", nameZh: "提前结束诊断",
                                 sets: plannedGroups, ballsPerSet: 15)]
        vm.drillNotes = [""]
        vm.drillSetsData = [(1...plannedGroups).map { DrillSetData(id: $0, targetBalls: 15) }]
        let marker = "QD012-current-" + UUID().uuidString
        vm.trainingNote = marker
        XCTAssertFalse(vm.hasStartedTraining, file: file, line: line)
        for (index, made) in completedMade.enumerated() {
            vm.drillSetsData[0][index].madeBalls = made
            vm.completeSet(drillIndex: 0, setIndex: index)
        }
        XCTAssertTrue(vm.hasStartedTraining, file: file, line: line)
        XCTAssertEqual(vm.drillSetsData[0].filter(\.isCompleted).count, completedMade.count, file: file, line: line)
        XCTAssertEqual(vm.drillSetsData[0].filter { !$0.isCompleted }.count,
                       plannedGroups - completedMade.count, file: file, line: line)
        XCTAssertTrue(vm.drillSetsData[0].dropFirst(completedMade.count).allSatisfy {
            !$0.isCompleted && $0.madeBalls == 0 && $0.targetBalls == 15
        }, file: file, line: line)
        vm.endTraining()
        XCTAssertEqual(vm.trainingPhase, .note, file: file, line: line)
        vm.submitNote()
        XCTAssertEqual(vm.trainingPhase, .summary, file: file, line: line)
        vm.saveTraining(context: context)
        XCTAssertNil(vm.saveError, file: file, line: line)
        XCTAssertTrue(vm.didSaveSuccessfully, file: file, line: line)

        // A fresh context prevents merely examining the VM input rows. Same memory store,
        // intentionally not described as a restart or durable-disk proof.
        let reader = ModelContext(container)
        reader.autosaveEnabled = false
        let sessions = try reader.fetch(FetchDescriptor<TrainingSession>())
        XCTAssertEqual(sessions.count, 1, file: file, line: line)
        let session = try XCTUnwrap(sessions.first, file: file, line: line)
        XCTAssertEqual(session.note, marker, file: file, line: line)
        XCTAssertEqual(session.drillEntries.count, 1, file: file, line: line)
        let entry = try XCTUnwrap(session.drillEntries.first, file: file, line: line)
        let sets = entry.sets.sorted { $0.setNumber < $1.setNumber }
        let allStoredSets = try reader.fetch(FetchDescriptor<DrillSet>())
        let observed: [String: Any] = [
            "marker": marker, "plannedGroups": plannedGroups,
            "explicitlyCompletedMade": completedMade,
            "storedSetNumbers": sets.map(\.setNumber),
            "storedMade": sets.map(\.madeBalls), "storedTargets": sets.map(\.targetBalls),
            "storedSuccessRate": entry.successRate,
            "expectedGroups": expectedGroups, "expectedMade": expectedMade,
            "expectedTargets": expectedTargets,
            "storage": "private-in-memory-fresh-context-not-disk-restart"
        ]
        let data = try JSONSerialization.data(withJSONObject: observed, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "QD012-save-observation"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertEqual(allStoredSets.count, sets.count, "No hidden/orphan groups", file: file, line: line)
        XCTAssertEqual(sets.count, expectedGroups, "Uncompleted plans must not become completed result groups", file: file, line: line)
        XCTAssertEqual(sets.map(\.setNumber), Array(1...expectedGroups), file: file, line: line)
        XCTAssertEqual(sets.reduce(0) { $0 + $1.madeBalls }, expectedMade, file: file, line: line)
        XCTAssertEqual(sets.reduce(0) { $0 + $1.targetBalls }, expectedTargets,
                       "Untouched groups must not dilute the completed result denominator", file: file, line: line)
        XCTAssertEqual(entry.successRate, Double(expectedMade) / Double(expectedTargets),
                       accuracy: 0.000001, file: file, line: line)
        let first = try XCTUnwrap(sets.first, file: file, line: line)
        XCTAssertEqual(first.madeBalls, completedMade[0], file: file, line: line)
        XCTAssertEqual(first.targetBalls, 15, "Explicitly completed zero scores remain valid attempts", file: file, line: line)
    }
}

@MainActor
private final class PartialSaveSilentActivity: RestTimerLiveActivityManaging {
    func startActivity(drillName: String, state: RestTimerAttributes.ContentState) {}
    func updateActivity(state: RestTimerAttributes.ContentState) {}
    func endActivity() {}
    func activateBackgroundAudio() {}
    func deactivateBackgroundAudio() {}
}
