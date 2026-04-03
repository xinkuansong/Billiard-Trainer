import XCTest
import SwiftData
@testable import QiuJi

@MainActor
final class StatisticsViewModelTests: XCTestCase {

    private var vm: StatisticsViewModel!

    override func setUp() {
        super.setUp()
        vm = StatisticsViewModel()
    }

    override func tearDown() {
        vm = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func test_initial_state() {
        XCTAssertEqual(vm.timeRange, .week)
        XCTAssertTrue(vm.sessions.isEmpty)
        XCTAssertFalse(vm.isLoading)
    }

    // MARK: - filteredSessions (week)

    func test_filteredSessions_week_includes_recent() {
        let cal = Calendar.current
        let today = Date()
        let threeDaysAgo = cal.date(byAdding: .day, value: -3, to: today)!
        let tenDaysAgo = cal.date(byAdding: .day, value: -10, to: today)!

        vm.sessions = [
            makeSession(date: today),
            makeSession(date: threeDaysAgo),
            makeSession(date: tenDaysAgo),
        ]
        vm.timeRange = .week

        XCTAssertEqual(vm.filteredSessions.count, 2)
    }

    // MARK: - filteredSessions (month)

    func test_filteredSessions_month_includes_last_30_days() {
        let cal = Calendar.current
        let today = Date()
        let twentyDaysAgo = cal.date(byAdding: .day, value: -20, to: today)!
        let sixtyDaysAgo = cal.date(byAdding: .day, value: -60, to: today)!

        vm.sessions = [
            makeSession(date: today),
            makeSession(date: twentyDaysAgo),
            makeSession(date: sixtyDaysAgo),
        ]
        vm.timeRange = .month

        XCTAssertEqual(vm.filteredSessions.count, 2)
    }

    // MARK: - filteredSessions (year)

    func test_filteredSessions_year_includes_recent_months() {
        let cal = Calendar.current
        let today = Date()
        let sixMonthsAgo = cal.date(byAdding: .month, value: -6, to: today)!
        let twoYearsAgo = cal.date(byAdding: .year, value: -2, to: today)!

        vm.sessions = [
            makeSession(date: today),
            makeSession(date: sixMonthsAgo),
            makeSession(date: twoYearsAgo),
        ]
        vm.timeRange = .year

        XCTAssertEqual(vm.filteredSessions.count, 2)
    }

    // MARK: - trainingDays

    func test_trainingDays_counts_unique_days() {
        let today = Date()
        vm.sessions = [
            makeSession(date: today),
            makeSession(date: today.addingTimeInterval(3600)),
        ]
        vm.timeRange = .week

        XCTAssertEqual(vm.trainingDays, 1)
    }

    func test_trainingDays_multiple_days() {
        let cal = Calendar.current
        let today = Date()
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

        vm.sessions = [
            makeSession(date: today),
            makeSession(date: yesterday),
        ]
        vm.timeRange = .week

        XCTAssertEqual(vm.trainingDays, 2)
    }

    func test_trainingDays_empty() {
        XCTAssertEqual(vm.trainingDays, 0)
    }

    // MARK: - totalDurationMinutes

    func test_totalDurationMinutes_sums_all() {
        let today = Date()
        let s1 = makeSession(date: today, durationMinutes: 30)
        let s2 = makeSession(date: today, durationMinutes: 45)
        vm.sessions = [s1, s2]
        vm.timeRange = .week

        XCTAssertEqual(vm.totalDurationMinutes, 75)
    }

    func test_totalDurationMinutes_excludes_out_of_range() {
        let cal = Calendar.current
        let today = Date()
        let tenDaysAgo = cal.date(byAdding: .day, value: -10, to: today)!

        vm.sessions = [
            makeSession(date: today, durationMinutes: 30),
            makeSession(date: tenDaysAgo, durationMinutes: 60),
        ]
        vm.timeRange = .week

        XCTAssertEqual(vm.totalDurationMinutes, 30)
    }

    // MARK: - formattedDuration

    func test_formattedDuration_minutes_only() {
        let today = Date()
        vm.sessions = [makeSession(date: today, durationMinutes: 45)]
        vm.timeRange = .week

        XCTAssertEqual(vm.formattedDuration, "45m")
    }

    func test_formattedDuration_hours_and_minutes() {
        let today = Date()
        vm.sessions = [makeSession(date: today, durationMinutes: 90)]
        vm.timeRange = .week

        XCTAssertEqual(vm.formattedDuration, "1h30m")
    }

    func test_formattedDuration_zero() {
        vm.timeRange = .week
        XCTAssertEqual(vm.formattedDuration, "0m")
    }

    // MARK: - totalSets

    func test_totalSets_counts_all_drill_sets() {
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext

        let session = TrainingSession(ballType: "chinese8")
        session.date = Date()
        session.totalDurationMinutes = 30

        let entry = DrillEntry(drillId: "drill_c001", drillNameZh: "测试")
        entry.sets = [
            DrillSet(setNumber: 1, targetBalls: 10, madeBalls: 7),
            DrillSet(setNumber: 2, targetBalls: 10, madeBalls: 8),
        ]
        session.drillEntries = [entry]

        context.insert(session)
        try! context.save()

        vm.sessions = [session]
        vm.timeRange = .week

        XCTAssertEqual(vm.totalSets, 2)
    }

    // MARK: - frequencyData

    func test_frequencyData_week_has_7_points() {
        vm.timeRange = .week
        XCTAssertEqual(vm.frequencyData.count, 7)
    }

    func test_frequencyData_month_has_4_points() {
        vm.timeRange = .month
        XCTAssertEqual(vm.frequencyData.count, 4)
    }

    func test_frequencyData_year_has_12_points() {
        vm.timeRange = .year
        XCTAssertEqual(vm.frequencyData.count, 12)
    }

    func test_frequencyData_week_counts_today_session() {
        let today = Date()
        vm.sessions = [makeSession(date: today)]
        vm.timeRange = .week

        let data = vm.frequencyData
        let todayPoint = data.last!
        XCTAssertEqual(todayPoint.count, 1)
    }

    func test_frequencyData_week_empty_sessions() {
        vm.timeRange = .week
        let data = vm.frequencyData
        let total = data.reduce(0) { $0 + $1.count }
        XCTAssertEqual(total, 0)
    }

    // MARK: - categorySuccessRates

    func test_categorySuccessRates_empty_sessions() {
        vm.timeRange = .week
        XCTAssertTrue(vm.categorySuccessRates.isEmpty)
    }

    func test_categorySuccessRates_computes_correctly() {
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext

        let session = TrainingSession(ballType: "chinese8")
        session.date = Date()
        session.totalDurationMinutes = 30

        let entry = DrillEntry(drillId: "drill_c001", drillNameZh: "半台直线球")
        entry.sets = [
            DrillSet(setNumber: 1, targetBalls: 10, madeBalls: 8),
            DrillSet(setNumber: 2, targetBalls: 10, madeBalls: 6),
        ]
        session.drillEntries = [entry]

        context.insert(session)
        try! context.save()

        vm.sessions = [session]
        vm.timeRange = .week

        let rates = vm.categorySuccessRates
        XCTAssertFalse(rates.isEmpty)

        let accuracyRate = rates.first { $0.id == "accuracy" }
        XCTAssertNotNil(accuracyRate)
        XCTAssertEqual(accuracyRate!.rate, 0.7, accuracy: 0.001)
        XCTAssertEqual(accuracyRate!.totalSets, 2)
    }

    func test_categorySuccessRates_sorted_by_rate_descending() {
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext

        let session = TrainingSession(ballType: "chinese8")
        session.date = Date()
        session.totalDurationMinutes = 60

        let entry1 = DrillEntry(drillId: "drill_c001", drillNameZh: "半台直线球")
        entry1.sets = [DrillSet(setNumber: 1, targetBalls: 10, madeBalls: 5)]

        let entry2 = DrillEntry(drillId: "drill_c006", drillNameZh: "握杆稳定性")
        entry2.sets = [DrillSet(setNumber: 1, targetBalls: 10, madeBalls: 9)]

        session.drillEntries = [entry1, entry2]

        context.insert(session)
        try! context.save()

        vm.sessions = [session]
        vm.timeRange = .week

        let rates = vm.categorySuccessRates
        XCTAssertEqual(rates.count, 2)
        XCTAssertGreaterThanOrEqual(rates[0].rate, rates[1].rate)
    }

    func test_categorySuccessRates_uses_nameZh() {
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext

        let session = TrainingSession(ballType: "chinese8")
        session.date = Date()
        session.totalDurationMinutes = 30

        let entry = DrillEntry(drillId: "drill_c006", drillNameZh: "握杆稳定性")
        entry.sets = [DrillSet(setNumber: 1, targetBalls: 10, madeBalls: 8)]
        session.drillEntries = [entry]

        context.insert(session)
        try! context.save()

        vm.sessions = [session]
        vm.timeRange = .week

        let rates = vm.categorySuccessRates
        let fundamentals = rates.first { $0.id == "fundamentals" }
        XCTAssertNotNil(fundamentals)
        XCTAssertEqual(fundamentals!.nameZh, "基础功")
    }

    // MARK: - StatisticsTimeRange enum

    func test_timeRange_allCases() {
        XCTAssertEqual(StatisticsTimeRange.allCases.count, 3)
        XCTAssertEqual(StatisticsTimeRange.week.rawValue, "周")
        XCTAssertEqual(StatisticsTimeRange.month.rawValue, "月")
        XCTAssertEqual(StatisticsTimeRange.year.rawValue, "年")
    }

    // MARK: - FrequencyDataPoint / CategorySuccessRate structs

    func test_frequencyDataPoint_properties() {
        let point = FrequencyDataPoint(label: "周一", date: Date(), count: 3)
        XCTAssertEqual(point.label, "周一")
        XCTAssertEqual(point.count, 3)
        XCTAssertNotNil(point.id)
    }

    func test_categorySuccessRate_properties() {
        let rate = CategorySuccessRate(id: "accuracy", nameZh: "准度训练", rate: 0.85, totalSets: 10)
        XCTAssertEqual(rate.id, "accuracy")
        XCTAssertEqual(rate.nameZh, "准度训练")
        XCTAssertEqual(rate.rate, 0.85)
        XCTAssertEqual(rate.totalSets, 10)
    }

    // MARK: - Time range switching

    func test_changing_timeRange_affects_filteredSessions() {
        let cal = Calendar.current
        let today = Date()
        let tenDaysAgo = cal.date(byAdding: .day, value: -10, to: today)!

        vm.sessions = [
            makeSession(date: today),
            makeSession(date: tenDaysAgo),
        ]

        vm.timeRange = .week
        let weekCount = vm.filteredSessions.count

        vm.timeRange = .month
        let monthCount = vm.filteredSessions.count

        XCTAssertEqual(weekCount, 1)
        XCTAssertEqual(monthCount, 2)
    }

    // MARK: - Helpers

    private func makeSession(date: Date, durationMinutes: Int = 30) -> TrainingSession {
        let session = TrainingSession(ballType: "chinese8")
        session.date = date
        session.totalDurationMinutes = durationMinutes
        return session
    }
}
