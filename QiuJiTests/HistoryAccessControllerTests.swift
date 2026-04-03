import XCTest
@testable import QiuJi

final class HistoryAccessControllerTests: XCTestCase {

    // MARK: - Premium user

    func test_premium_user_always_has_access() {
        let oldSession = makeSession(daysAgo: 365)
        XCTAssertTrue(HistoryAccessController.isAccessible(oldSession, isPremium: true))
    }

    func test_premium_user_access_recent_session() {
        let recentSession = makeSession(daysAgo: 1)
        XCTAssertTrue(HistoryAccessController.isAccessible(recentSession, isPremium: true))
    }

    // MARK: - Free user within limit

    func test_free_user_access_today_session() {
        let todaySession = makeSession(daysAgo: 0)
        XCTAssertTrue(HistoryAccessController.isAccessible(todaySession, isPremium: false))
    }

    func test_free_user_access_30_day_old_session() {
        let session = makeSession(daysAgo: 30)
        XCTAssertTrue(HistoryAccessController.isAccessible(session, isPremium: false))
    }

    func test_free_user_access_59_day_old_session() {
        let session = makeSession(daysAgo: 59)
        XCTAssertTrue(HistoryAccessController.isAccessible(session, isPremium: false))
    }

    // MARK: - Free user beyond limit

    func test_free_user_no_access_61_day_old_session() {
        let session = makeSession(daysAgo: 61)
        XCTAssertFalse(HistoryAccessController.isAccessible(session, isPremium: false))
    }

    func test_free_user_no_access_90_day_old_session() {
        let session = makeSession(daysAgo: 90)
        XCTAssertFalse(HistoryAccessController.isAccessible(session, isPremium: false))
    }

    func test_free_user_no_access_365_day_old_session() {
        let session = makeSession(daysAgo: 365)
        XCTAssertFalse(HistoryAccessController.isAccessible(session, isPremium: false))
    }

    // MARK: - Boundary: exactly 60 days

    func test_free_user_boundary_exactly_60_days() {
        let cal = Calendar.current
        let justInside = cal.date(byAdding: .day, value: -60, to: Date())!.addingTimeInterval(60)
        let session = TrainingSession(ballType: "chinese8")
        session.date = justInside

        XCTAssertTrue(HistoryAccessController.isAccessible(session, isPremium: false))
    }

    func test_free_user_boundary_just_beyond_60_days() {
        let cal = Calendar.current
        let justOutside = cal.date(byAdding: .day, value: -60, to: Date())!.addingTimeInterval(-60)
        let session = TrainingSession(ballType: "chinese8")
        session.date = justOutside

        XCTAssertFalse(HistoryAccessController.isAccessible(session, isPremium: false))
    }

    // MARK: - freeDaysLimit constant

    func test_freeDaysLimit_is_60() {
        XCTAssertEqual(HistoryAccessController.freeDaysLimit, 60)
    }

    // MARK: - cutoffDate

    func test_cutoffDate_is_60_days_ago() {
        let cal = Calendar.current
        let expected = cal.date(byAdding: .day, value: -60, to: Date())!
        let cutoff = HistoryAccessController.cutoffDate()

        let diff = abs(cutoff.timeIntervalSince(expected))
        XCTAssertLessThan(diff, 1.0)
    }

    func test_cutoffDate_is_before_today() {
        let cutoff = HistoryAccessController.cutoffDate()
        XCTAssertTrue(cutoff < Date())
    }

    // MARK: - Helpers

    private func makeSession(daysAgo: Int) -> TrainingSession {
        let session = TrainingSession(ballType: "chinese8")
        session.date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return session
    }
}
