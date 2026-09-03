import XCTest
import SwiftData
import SwiftUI
import UIKit
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
        // 基准取「今天中午」而不是 `Date()`：用 `Date()` 时 +1h 会在 23:00 后跨到次日，
        // 断言随运行时钟真假不定（2026-08-06 23:21 在未改动的 main 上同样复现失败，
        // 见 build/w6-logs/baseline-flake-main.log）。这里修的是断言前提，不是被测行为。
        let today = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
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

    // MARK: - durationBarData

    func test_durationBarData_week_has_7_points() {
        vm.timeRange = .week
        XCTAssertEqual(vm.durationBarData.count, 7)
    }

    func test_durationBarData_month_has_4_points() {
        vm.timeRange = .month
        XCTAssertEqual(vm.durationBarData.count, 4)
    }

    func test_durationBarData_year_has_12_points() {
        vm.timeRange = .year
        XCTAssertEqual(vm.durationBarData.count, 12)
    }

    func test_durationBarData_week_sums_today_duration() {
        let today = Date()
        vm.sessions = [makeSession(date: today, durationMinutes: 60)]
        vm.timeRange = .week

        let data = vm.durationBarData
        let todayPoint = data.last!
        XCTAssertEqual(todayPoint.hours, 1.0, accuracy: 0.01)
    }

    func test_durationBarData_week_empty_sessions() {
        vm.timeRange = .week
        let data = vm.durationBarData
        let total = data.reduce(0.0) { $0 + $1.hours }
        XCTAssertEqual(total, 0.0)
    }

    // MARK: - successRateBarData
    //
    // ✅ D-v29-2（契约 §5.4）：`successRateBarData` / `overallSuccessRate` /
    // `successRateChange` 已随「删除全局单一准确率」一并下线，故此处原
    // `test_successRateBarData_week_has_7_points` 一并移除——被测能力按裁定不再存在，
    // 不是断言失败后删断言。分组口径的覆盖见
    // `V29W6HistoryStatisticsKindTests` 与下方 `categorySuccessRates` 各条。

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

        vm.categoryMapping = ["drill_c001": "accuracy"]
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

        vm.categoryMapping = ["drill_c001": "accuracy", "drill_c006": "fundamentals"]
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

        vm.categoryMapping = ["drill_c006": "fundamentals"]
        vm.sessions = [session]
        vm.timeRange = .week

        let rates = vm.categorySuccessRates
        let fundamentals = rates.first { $0.id == "fundamentals" }
        XCTAssertNotNil(fundamentals)
        XCTAssertEqual(fundamentals!.nameZh, "基础")
    }

    // MARK: - StatisticsTimeRange enum

    func test_timeRange_allCases() {
        XCTAssertEqual(StatisticsTimeRange.allCases.count, 3)
        XCTAssertEqual(StatisticsTimeRange.week.rawValue, "周")
        XCTAssertEqual(StatisticsTimeRange.month.rawValue, "月")
        XCTAssertEqual(StatisticsTimeRange.year.rawValue, "年")
    }

    // MARK: - Data model structs

    func test_durationBarData_properties() {
        let bar = DurationBarData(label: "周一", date: Date(), hours: 1.5)
        XCTAssertEqual(bar.label, "周一")
        XCTAssertEqual(bar.hours, 1.5)
        XCTAssertNotNil(bar.id)
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

    // MARK: - Profile Monthly Overview

    func test_monthlyOverview_usesCalendarMonthAndTrainingKinds() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))

        func date(_ day: Int, month: Int = 9) -> Date {
            cal.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
        }
        func session(_ kind: String, day: Int, month: Int = 9, minutes: Int) -> TrainingSession {
            let value = TrainingSession(kind: kind)
            value.date = date(day, month: month)
            value.totalDurationMinutes = minutes
            return value
        }

        let sessions = [
            session(TrainingSessionKind.drill, day: 31, month: 8, minutes: 300),
            session(TrainingSessionKind.drill, day: 1, minutes: 30),
            session(TrainingSessionKind.cognitive, day: 2, minutes: 15),
            session(TrainingSessionKind.tool, day: 3, minutes: 99),
            session(TrainingSessionKind.drill, day: 4, minutes: 45),
            session(TrainingSessionKind.drill, day: 4, minutes: 5),
            session(TrainingSessionKind.drill, day: 5, minutes: 10),
            session(TrainingSessionKind.cognitive, day: 6, minutes: 20),
            session(TrainingSessionKind.drill, day: 1, month: 10, minutes: 400),
        ]

        let overview = TrainingGoalMetrics.monthlyOverview(
            sessions,
            at: date(20),
            calendar: cal
        )

        XCTAssertEqual(overview.trainingDays, 5, "同一天多条记录只能算一个训练日")
        XCTAssertEqual(overview.durationMinutes, 125, "只累计本自然月 drill + cognitive")
        XCTAssertEqual(overview.formattedDuration, "2h5m")
        XCTAssertEqual(overview.longestStreak, 3, "9 月 4–6 日为最长连续打卡")
    }

    func test_monthlyOverview_longestStreakDoesNotCrossMonthBoundary() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))

        func date(month: Int, day: Int) -> Date {
            cal.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
        }
        let sessions = [
            makeSession(date: date(month: 8, day: 30)),
            makeSession(date: date(month: 8, day: 31)),
            makeSession(date: date(month: 9, day: 1)),
            makeSession(date: date(month: 9, day: 2)),
        ]

        let overview = TrainingGoalMetrics.monthlyOverview(
            sessions,
            at: date(month: 9, day: 20),
            calendar: cal
        )

        XCTAssertEqual(overview.trainingDays, 2)
        XCTAssertEqual(overview.longestStreak, 2, "自然月边界外的连续日期不能并入本月最长连续")
    }

    func test_renderProfileMonthlyOverviewCard_afterEvidence() throws {
        let card = ProfileMonthlyOverviewCard(
            trainingDays: "5",
            duration: "2h5m",
            longestStreak: "3"
        )
        .frame(width: 358)
        .padding(16)
        .background(Color.btBG)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        try writeEvidence(
            try XCTUnwrap(renderer.uiImage),
            name: "04-profile-monthly-overview-after"
        )
    }

    // MARK: - Helpers

    private func makeSession(date: Date, durationMinutes: Int = 30) -> TrainingSession {
        let session = TrainingSession(ballType: "chinese8")
        session.date = date
        session.totalDurationMinutes = durationMinutes
        return session
    }

    private func writeEvidence(_ image: UIImage, name: String) throws {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("build/w6-screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(name).png")
        try XCTUnwrap(image.pngData()).write(to: url)
        print("[ProfileMonthlyOverview-evidence] \(url.path)")
    }
}
