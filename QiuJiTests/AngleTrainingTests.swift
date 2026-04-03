import XCTest
@testable import QiuJi

final class AngleCalculatorTests: XCTestCase {

    func test_contactPointOffset_45degrees_approximately0707() {
        let offset = AngleCalculator.contactPointOffset(angle: 45.0)
        XCTAssertEqual(offset, sin(45.0 * .pi / 180.0), accuracy: 0.001)
        XCTAssertEqual(offset, 0.707, accuracy: 0.001)
    }

    func test_contactPointOffset_knownValues() {
        XCTAssertEqual(AngleCalculator.contactPointOffset(angle: 0), 0.0, accuracy: 0.001)
        XCTAssertEqual(AngleCalculator.contactPointOffset(angle: 30), 0.5, accuracy: 0.001)
        XCTAssertEqual(AngleCalculator.contactPointOffset(angle: 90), 1.0, accuracy: 0.001)
        XCTAssertEqual(AngleCalculator.contactPointOffset(angle: 60), sin(60.0 * .pi / 180.0), accuracy: 0.001)
    }

    func test_randomAngle_corner_inRange5to85_stepOf5() {
        for _ in 0..<200 {
            let angle = AngleCalculator.randomAngle(pocketType: .corner)
            XCTAssertGreaterThanOrEqual(angle, 5)
            XCTAssertLessThanOrEqual(angle, 85)
            XCTAssertEqual(angle.truncatingRemainder(dividingBy: 5), 0, "Angle must be a multiple of 5°")
        }
    }

    func test_randomAngle_side_inRange15to60_stepOf5() {
        for _ in 0..<200 {
            let angle = AngleCalculator.randomAngle(pocketType: .side)
            XCTAssertGreaterThanOrEqual(angle, 15)
            XCTAssertLessThanOrEqual(angle, 60)
            XCTAssertEqual(angle.truncatingRemainder(dividingBy: 5), 0, "Angle must be a multiple of 5°")
        }
    }

    func test_generateQuestion_returnsCorrectAngleAndPocketType() {
        for pocketType in PocketType.allCases {
            let angle = AngleCalculator.randomAngle(pocketType: pocketType)
            let q = AngleCalculator.generateQuestion(angle: angle, pocketType: pocketType)
            XCTAssertEqual(q.actualAngle, angle)
            XCTAssertEqual(q.pocketType, pocketType)
            XCTAssertEqual(q.pocket.type, pocketType)
        }
    }

    func test_generateQuestion_ballsWithinTableBounds() {
        for _ in 0..<50 {
            let pocketType: PocketType = Bool.random() ? .corner : .side
            let angle = AngleCalculator.randomAngle(pocketType: pocketType)
            let q = AngleCalculator.generateQuestion(angle: angle, pocketType: pocketType)

            XCTAssertGreaterThanOrEqual(q.targetBall.x, 0.0)
            XCTAssertLessThanOrEqual(q.targetBall.x, 1.0)
            XCTAssertGreaterThanOrEqual(q.targetBall.y, 0.0)
            XCTAssertLessThanOrEqual(q.targetBall.y, 0.5)

            XCTAssertGreaterThanOrEqual(q.cueBall.x, 0.0)
            XCTAssertLessThanOrEqual(q.cueBall.x, 1.0)
            XCTAssertGreaterThanOrEqual(q.cueBall.y, 0.0)
            XCTAssertLessThanOrEqual(q.cueBall.y, 0.5)
        }
    }

    func test_pockets_has6_4corner2side() {
        let pockets = AngleCalculator.pockets
        XCTAssertEqual(pockets.count, 6)
        XCTAssertEqual(pockets.filter { $0.type == .corner }.count, 4)
        XCTAssertEqual(pockets.filter { $0.type == .side }.count, 2)
    }
}

// MARK: - AdaptiveQuestionEngine Tests

final class AdaptiveQuestionEngineTests: XCTestCase {

    private let engineStorageKey = "AdaptiveQuestionEngine_v1"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: engineStorageKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: engineStorageKey)
        super.tearDown()
    }

    func test_cornerAngles_17values_5to85() {
        let angles = AdaptiveQuestionEngine.cornerAngles
        XCTAssertEqual(angles.count, 17)
        XCTAssertEqual(angles.first, 5)
        XCTAssertEqual(angles.last, 85)
    }

    func test_sideAngles_10values_15to60() {
        let angles = AdaptiveQuestionEngine.sideAngles
        XCTAssertEqual(angles.count, 10)
        XCTAssertEqual(angles.first, 15)
        XCTAssertEqual(angles.last, 60)
    }

    func test_selectPocketType_100questions_cornerSideRatio55to65() {
        let engine = AdaptiveQuestionEngine()
        var cornerCount = 0
        let total = 100

        for _ in 0..<total {
            if engine.selectPocketType() == .corner {
                cornerCount += 1
            }
        }

        let cornerPercent = Double(cornerCount) / Double(total) * 100.0
        XCTAssertGreaterThanOrEqual(cornerPercent, 45,
            "Corner ratio \(cornerPercent)% below 45% — expected around 60%")
        XCTAssertLessThanOrEqual(cornerPercent, 75,
            "Corner ratio \(cornerPercent)% above 75% — expected around 60%")
    }

    func test_selectPocketType_1000questions_tighterBounds() {
        let engine = AdaptiveQuestionEngine()
        var cornerCount = 0
        let total = 1000

        for _ in 0..<total {
            if engine.selectPocketType() == .corner {
                cornerCount += 1
            }
        }

        let cornerPercent = Double(cornerCount) / Double(total) * 100.0
        XCTAssertGreaterThanOrEqual(cornerPercent, 55,
            "Corner ratio \(cornerPercent)% below 55% — expected ~60%")
        XCTAssertLessThanOrEqual(cornerPercent, 65,
            "Corner ratio \(cornerPercent)% above 65% — expected ~60%")
    }

    func test_selectAngle_corner_returnsValidAngle() {
        let engine = AdaptiveQuestionEngine()
        for _ in 0..<100 {
            let angle = Int(engine.selectAngle(for: .corner))
            XCTAssertTrue(AdaptiveQuestionEngine.cornerAngles.contains(angle),
                          "Angle \(angle) not in cornerAngles")
        }
    }

    func test_selectAngle_side_returnsValidAngle() {
        let engine = AdaptiveQuestionEngine()
        for _ in 0..<100 {
            let angle = Int(engine.selectAngle(for: .side))
            XCTAssertTrue(AdaptiveQuestionEngine.sideAngles.contains(angle),
                          "Angle \(angle) not in sideAngles")
        }
    }

    func test_zoneHistory_averageError() {
        var zone = AdaptiveQuestionEngine.ZoneHistory()
        XCTAssertEqual(zone.averageError, 0)

        zone.addError(10)
        zone.addError(20)
        XCTAssertEqual(zone.averageError, 15.0, accuracy: 0.001)
    }

    func test_zoneHistory_rollingWindow_max10() {
        var zone = AdaptiveQuestionEngine.ZoneHistory()
        for i in 1...15 {
            zone.addError(Double(i))
        }
        XCTAssertEqual(zone.errors.count, 10, "Should keep at most 10 errors")
        XCTAssertEqual(zone.errors.first, 6, "Oldest kept should be 6 (after removing 1–5)")
    }

    func test_recordResult_storesInCorrectZone() {
        let engine = AdaptiveQuestionEngine()
        engine.recordResult(angle: 45, error: 5, pocketType: .corner)
        engine.recordResult(angle: 30, error: 8, pocketType: .side)

        XCTAssertNotNil(engine.cornerZones[45])
        XCTAssertEqual(engine.cornerZones[45]?.errors, [5.0])
        XCTAssertNotNil(engine.sideZones[30])
        XCTAssertEqual(engine.sideZones[30]?.errors, [8.0])
    }

    func test_recordResult_persistsToUserDefaults() {
        let engine = AdaptiveQuestionEngine()
        engine.recordResult(angle: 45, error: 5, pocketType: .corner)

        let engine2 = AdaptiveQuestionEngine()
        XCTAssertNotNil(engine2.cornerZones[45])
        XCTAssertEqual(engine2.cornerZones[45]?.errors, [5.0])
    }
}

// MARK: - AngleUsageLimiter Tests

final class AngleUsageLimiterTests: XCTestCase {

    private let countKey = "AngleUsage_count"
    private let dateKey  = "AngleUsage_date"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: countKey)
        UserDefaults.standard.removeObject(forKey: dateKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: countKey)
        UserDefaults.standard.removeObject(forKey: dateKey)
        super.tearDown()
    }

    func test_dailyLimit_is20() {
        XCTAssertEqual(AngleUsageLimiter.dailyLimit, 20)
    }

    func test_freshStart_zeroUsed() {
        let limiter = AngleUsageLimiter()
        XCTAssertEqual(limiter.questionsUsedToday, 0)
        XCTAssertEqual(limiter.remainingToday, 20)
        XCTAssertFalse(limiter.isLimitReached)
    }

    func test_recordQuestion_incrementsCount() {
        let limiter = AngleUsageLimiter()
        limiter.recordQuestion()
        limiter.recordQuestion()
        XCTAssertEqual(limiter.questionsUsedToday, 2)
        XCTAssertEqual(limiter.remainingToday, 18)
    }

    func test_limitReached_at20() {
        let limiter = AngleUsageLimiter()
        for _ in 0..<20 { limiter.recordQuestion() }
        XCTAssertTrue(limiter.isLimitReached)
        XCTAssertEqual(limiter.remainingToday, 0)
    }

    func test_premium_bypassesLimit() {
        let limiter = AngleUsageLimiter()
        for _ in 0..<25 { limiter.recordQuestion() }
        limiter.isPremium = true
        XCTAssertFalse(limiter.isLimitReached, "Premium users should not be limited")
    }

    func test_dateReset_clearsPreviousDayCount() {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        UserDefaults.standard.set(df.string(from: yesterday), forKey: dateKey)
        UserDefaults.standard.set(15, forKey: countKey)

        let limiter = AngleUsageLimiter()
        XCTAssertEqual(limiter.questionsUsedToday, 0, "Should reset for a new day")
    }

    func test_sameDay_restoresCount() {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        UserDefaults.standard.set(df.string(from: Date()), forKey: dateKey)
        UserDefaults.standard.set(7, forKey: countKey)

        let limiter = AngleUsageLimiter()
        XCTAssertEqual(limiter.questionsUsedToday, 7)
    }
}
