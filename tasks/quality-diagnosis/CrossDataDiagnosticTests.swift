import XCTest
import SwiftData
@testable import QiuJi

/// Diagnostic draft for snapshot-002. Not compiled or executed by author.
/// No sync, repository, default owner, preferences, or file export calls.
@MainActor
final class CrossDataDiagnosticTests: XCTestCase {
    private let owner = "guest:quality-cross-data"

    private func session(_ kind: String, _ date: Date, _ minutes: Int) -> TrainingSession {
        let value = TrainingSession(kind: kind, ownerKey: owner)
        value.date = date
        value.totalDurationMinutes = minutes
        return value
    }

    private func entry(_ id: String, _ made: Int, _ target: Int, _ unit: String = "球") -> DrillEntry {
        let value = DrillEntry(drillId: id, drillNameZh: id)
        value.sets = [DrillSet(setNumber: 1, targetBalls: target, madeBalls: made, unitLabel: unit)]
        return value
    }

    func testCrossKindMultipleSessionsRollingWeekAgainstLiteralLedger() throws {
        let cal = Calendar.current
        let anchor = Date()
        let today = cal.startOfDay(for: anchor)
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: today)! }
        let a = session("drill", day(0), 20)
        a.drillEntries = [entry("a", 8, 10)]
        let b = session("drill", day(0), 30)
        b.drillEntries = [entry("a", 2, 5)]
        let c = session("cognitive", day(-1), 5)
        let d = session("tool", day(0), 99)
        let e = session("drill", day(-6), 10)
        e.drillEntries = [entry("b", 3, 10, "局")]
        let excluded = session("drill", day(-7), 200)
        let rows = [a, b, c, d, e, excluded]
        let stats = StatisticsViewModel()
        stats.categoryMapping = ["a": "accuracy", "b": "positioning"]
        stats.sessions = rows
        XCTAssertEqual(stats.filteredSessions.count, 4)
        XCTAssertEqual(stats.trainingDays, 3)
        XCTAssertEqual(stats.totalDurationMinutes, 65)
        XCTAssertEqual(stats.totalSets, 3)
        XCTAssertEqual(stats.minutesByKind.tool, 99)
        let accuracy = try XCTUnwrap(stats.categorySuccessRates.first { $0.id == "accuracy" })
        XCTAssertEqual(accuracy.rate, 2.0 / 3.0, accuracy: 0.000001)
        XCTAssertEqual(accuracy.target, 15)
        XCTAssertEqual(TrainingGoalMetrics.daysTrained(rows, since: day(-6), calendar: cal), 3)
        let history = HistoryViewModel()
        history.sessions = rows
        history.toolSessions = [ToolSessionItem.make(session: d)]
        history.cognitiveSessions = [CognitiveSessionItem.make(session: c, results: [])]
        history.selectedDate = today
        XCTAssertEqual(history.selectedDateItems.count, 3) // two drill + one tool
        XCTAssertEqual(history.selectedDateSessions.count, 2)
        XCTAssertEqual(DrillPracticeCounts.make(sessions: rows, ownerKey: owner)["a"], 2)
        XCTAssertTrue(cal.isDate(anchor, inSameDayAs: Date()), "Clock crossed midnight: rerun as invalid fixture timing")
    }

    func testNaturalMonthAndCalendarWeekUseLiteralBoundaryLedger() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        func date(_ month: Int, _ day: Int) -> Date {
            cal.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
        }
        let rows = [session("drill", date(8, 31), 100),
                    session("drill", date(9, 1), 20),
                    session("drill", date(9, 1), 30),
                    session("cognitive", date(9, 2), 5),
                    session("tool", date(9, 3), 99),
                    session("drill", date(9, 4), 10),
                    session("drill", date(10, 1), 200)]
        let month = TrainingGoalMetrics.monthlyOverview(rows, at: date(9, 5), calendar: cal)
        XCTAssertEqual(month.trainingDays, 3)
        XCTAssertEqual(month.durationMinutes, 65)
        XCTAssertEqual(month.longestStreak, 2)
        // Explicit Monday Aug 31 through Saturday Sep 5; no future rows supplied to lower-bound-only API.
        let asOfRows = Array(rows.prefix(6))
        XCTAssertEqual(TrainingGoalMetrics.daysTrained(asOfRows, since: date(8, 31), calendar: cal), 4)
    }

    func testCharacterizeMixedUnitsAndUnfinishedPlannedSetsNotAcceptance() throws {
        let a = session("drill", Calendar.current.startOfDay(for: Date()), 10)
        let balls = entry("a", 8, 10)
        // Persisted shape from early finish: seven untouched zero-made planned sets.
        // DrillSet has no persisted completion bit. This test cannot recover intent.
        balls.sets += (2...8).map { DrillSet(setNumber: $0, targetBalls: 10, madeBalls: 0) }
        a.drillEntries = [balls, entry("b", 1, 2, "局")]
        let stats = StatisticsViewModel()
        stats.categoryMapping = ["a": "combined", "b": "combined"]
        stats.sessions = [a]
        let item = try XCTUnwrap(stats.categorySuccessRates.first)
        XCTAssertEqual(stats.totalSets, 9)
        XCTAssertEqual(item.made, 9)
        XCTAssertEqual(item.target, 82)
        XCTAssertEqual(item.rate, 9.0 / 82.0, accuracy: 0.000001)
        XCTAssertEqual(item.units, Set(["球", "局"]))
        XCTAssertTrue(item.hasMixedUnits)
        // Actual completed work would be 2 sets, separately 8/10 balls and 1/2 games.
        // Passing confirms current lossy behavior; it does NOT close the partial-training finding.
    }

    func testThousandPersistedSessionsIndependentCounts() throws {
        let schema = ModelContainerFactory.currentSchema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext
        let today = Calendar.current.startOfDay(for: Date())
        // 500 drill x2min, 250 cognitive x3min, 250 tool x4min; all on one day.
        for index in 0..<1000 {
            let kind = index < 500 ? "drill" : (index < 750 ? "cognitive" : "tool")
            let row = session(kind, today, index < 500 ? 2 : (index < 750 ? 3 : 4))
            if index < 500 { row.drillEntries = [entry("a", 1, 2)] }
            context.insert(row)
        }
        try context.save()
        let rows = try context.fetch(FetchDescriptor<TrainingSession>())
        XCTAssertEqual(rows.count, 1000)
        let stats = StatisticsViewModel()
        stats.sessions = rows
        stats.categoryMapping = ["a": "accuracy"]
        XCTAssertEqual(stats.filteredSessions.count, 750)
        XCTAssertEqual(stats.trainingDays, 1)
        XCTAssertEqual(stats.totalDurationMinutes, 1750)
        XCTAssertEqual(stats.minutesByKind.tool, 1000)
        XCTAssertEqual(stats.totalSets, 500)
        XCTAssertEqual(try XCTUnwrap(stats.categorySuccessRates.first).rate, 0.5)
        XCTAssertEqual(DrillPracticeCounts.make(sessions: rows, ownerKey: owner)["a"], 500)
        let history = HistoryViewModel()
        history.sessions = rows
        history.cognitiveSessions = rows.filter { $0.kind == "cognitive" }.map {
            CognitiveSessionItem.make(session: $0, results: [])
        }
        history.toolSessions = rows.filter { $0.kind == "tool" }.map { ToolSessionItem.make(session: $0) }
        history.selectedDate = today
        XCTAssertEqual(history.selectedDateItems.count, 1000)
        XCTAssertEqual(history.selectedDateSessions.count, 500)
    }
}
