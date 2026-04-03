import XCTest
import SwiftData
@testable import QiuJi

@MainActor
final class HistoryViewModelTests: XCTestCase {

    private var vm: HistoryViewModel!

    override func setUp() {
        super.setUp()
        vm = HistoryViewModel()
    }

    override func tearDown() {
        vm = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func test_initial_state() {
        XCTAssertTrue(vm.sessions.isEmpty)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - datesWithSessions

    func test_datesWithSessions_empty() {
        XCTAssertTrue(vm.datesWithSessions.isEmpty)
    }

    func test_datesWithSessions_unique_days() {
        let cal = Calendar.current
        let today = Date()
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

        vm.sessions = [
            makeSession(date: today),
            makeSession(date: today),
            makeSession(date: yesterday),
        ]

        XCTAssertEqual(vm.datesWithSessions.count, 2)
    }

    // MARK: - selectedDateSessions

    func test_selectedDateSessions_filters_by_selected_date() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

        let s1 = makeSession(date: today.addingTimeInterval(3600))
        let s2 = makeSession(date: today.addingTimeInterval(7200))
        let s3 = makeSession(date: yesterday)

        vm.sessions = [s1, s2, s3]
        vm.selectedDate = today

        let selected = vm.selectedDateSessions
        XCTAssertEqual(selected.count, 2)
        XCTAssertTrue(selected.allSatisfy { cal.isDate($0.date, inSameDayAs: today) })
    }

    func test_selectedDateSessions_sorted_descending() {
        let today = Calendar.current.startOfDay(for: Date())
        let earlier = today.addingTimeInterval(3600)
        let later = today.addingTimeInterval(7200)

        vm.sessions = [
            makeSession(date: earlier),
            makeSession(date: later),
        ]
        vm.selectedDate = today

        let selected = vm.selectedDateSessions
        XCTAssertEqual(selected.count, 2)
        XCTAssertTrue(selected[0].date > selected[1].date)
    }

    // MARK: - currentMonthSessions

    func test_currentMonthSessions_filters_current_month() {
        let cal = Calendar.current
        let now = Date()
        let lastMonth = cal.date(byAdding: .month, value: -1, to: now)!

        let thisMonthSession = makeSession(date: now)
        let lastMonthSession = makeSession(date: lastMonth)

        vm.sessions = [thisMonthSession, lastMonthSession]
        vm.currentMonth = now

        let result = vm.currentMonthSessions
        XCTAssertEqual(result.count, 1)
        let sessionMonth = cal.component(.month, from: result[0].date)
        let currentMonth = cal.component(.month, from: now)
        XCTAssertEqual(sessionMonth, currentMonth)
    }

    // MARK: - monthTitle

    func test_monthTitle_format() {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 4
        comps.day = 1
        vm.currentMonth = cal.date(from: comps)!

        XCTAssertEqual(vm.monthTitle, "2026年4月")
    }

    // MARK: - weeksInMonth

    func test_weeksInMonth_contains_all_days() {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 4
        comps.day = 1
        vm.currentMonth = cal.date(from: comps)!

        let weeks = vm.weeksInMonth
        let allDays = weeks.flatMap { $0 }.compactMap { $0 }

        XCTAssertEqual(allDays.count, 30)

        for week in weeks {
            XCTAssertEqual(week.count, 7)
        }
    }

    func test_weeksInMonth_february_28_days() {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = 2025
        comps.month = 2
        comps.day = 1
        vm.currentMonth = cal.date(from: comps)!

        let weeks = vm.weeksInMonth
        let allDays = weeks.flatMap { $0 }.compactMap { $0 }
        XCTAssertEqual(allDays.count, 28)
    }

    // MARK: - hasSession

    func test_hasSession_returns_true_for_matching_date() {
        let today = Date()
        vm.sessions = [makeSession(date: today)]
        XCTAssertTrue(vm.hasSession(on: today))
    }

    func test_hasSession_returns_false_for_no_match() {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        vm.sessions = [makeSession(date: today)]
        XCTAssertFalse(vm.hasSession(on: yesterday))
    }

    // MARK: - isToday / isSelected

    func test_isToday_correct() {
        XCTAssertTrue(vm.isToday(Date()))
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertFalse(vm.isToday(yesterday))
    }

    func test_isSelected_matches_selectedDate() {
        let date = Calendar.current.startOfDay(for: Date())
        vm.selectedDate = date
        XCTAssertTrue(vm.isSelected(date))
        XCTAssertTrue(vm.isSelected(date.addingTimeInterval(3600)))

        let other = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        XCTAssertFalse(vm.isSelected(other))
    }

    // MARK: - Month Navigation

    func test_previousMonth() {
        let cal = Calendar.current
        let original = vm.currentMonth
        vm.previousMonth()
        let diff = cal.dateComponents([.month], from: vm.currentMonth, to: original)
        XCTAssertEqual(diff.month, 1)
    }

    func test_nextMonth() {
        let cal = Calendar.current
        let original = vm.currentMonth
        vm.nextMonth()
        let diff = cal.dateComponents([.month], from: original, to: vm.currentMonth)
        XCTAssertEqual(diff.month, 1)
    }

    func test_previousMonth_then_nextMonth_returns_to_same() {
        let cal = Calendar.current
        let originalComps = cal.dateComponents([.year, .month], from: vm.currentMonth)
        vm.previousMonth()
        vm.nextMonth()
        let finalComps = cal.dateComponents([.year, .month], from: vm.currentMonth)
        XCTAssertEqual(originalComps.year, finalComps.year)
        XCTAssertEqual(originalComps.month, finalComps.month)
    }

    // MARK: - loadSessions (SwiftData)

    func test_loadSessions_populates_sessions() async {
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        SyncQueueManager.shared.configure(context: context)

        let repo = LocalTrainingSessionRepository(context: context)
        _ = try! await repo.create(ballType: "chinese8")
        _ = try! await repo.create(ballType: "snooker")

        await vm.loadSessions(context: context)

        XCTAssertEqual(vm.sessions.count, 2)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    func test_loadSessions_empty_database() async {
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext

        await vm.loadSessions(context: context)

        XCTAssertTrue(vm.sessions.isEmpty)
        XCTAssertFalse(vm.isLoading)
    }

    // MARK: - Helpers

    private func makeSession(date: Date) -> TrainingSession {
        let session = TrainingSession(ballType: "chinese8")
        session.date = date
        return session
    }
}
