import XCTest
@testable import QiuJi

final class TrainingAtmosphereTests: XCTestCase {
    func testLocalTimeBoundariesAndMidnight() throws {
        for zone in ["Asia/Shanghai", "America/Los_Angeles"] {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try XCTUnwrap(TimeZone(identifier: zone))
            let cases: [(Int, Int, TrainingDaypart)] = [
                (0, 0, .evening), (5, 59, .evening), (6, 0, .morning),
                (10, 59, .morning), (11, 0, .day), (17, 59, .day),
                (18, 0, .evening), (23, 59, .evening)
            ]
            for (hour, minute, expected) in cases {
                let date = try XCTUnwrap(calendar.date(from: DateComponents(
                    year: 2026, month: 9, day: 9, hour: hour, minute: minute)))
                XCTAssertEqual(TrainingDaypart.resolve(at: date, calendar: calendar), expected,
                               "\(zone) \(hour):\(minute)")
            }
        }
    }

    @MainActor
    func testEveryDefaultGameHasCorrectTerminalBallAndBundledArt() {
        for game in DailyClearanceGame.allCases {
            let expected = game == .chineseEightBall ? "profileBall8" : "profileBall9"
            XCTAssertEqual(BTProfileGameBall.assetName(for: game), expected)
            XCTAssertNotNil(UIImage(named: expected))
        }
        for part in TrainingDaypart.allCases {
            XCTAssertNotNil(UIImage(named: part.assetName))
        }
    }
}
