import XCTest
@testable import QiuJi

final class DrillCategoryAndLevelTests: XCTestCase {

    // MARK: - DrillCategory

    func test_drillCategory_allCases_count8() {
        XCTAssertEqual(DrillCategory.allCases.count, 8)
    }

    func test_drillCategory_rawValues() {
        let expected: Set<String> = [
            "fundamentals", "accuracy", "cueAction", "separation",
            "positioning", "forceControl", "specialShots", "combined"
        ]
        let actual = Set(DrillCategory.allCases.map(\.rawValue))
        XCTAssertEqual(actual, expected)
    }

    func test_drillCategory_nameZh_nonEmpty() {
        for cat in DrillCategory.allCases {
            XCTAssertFalse(cat.nameZh.isEmpty, "\(cat.rawValue) nameZh should not be empty")
        }
    }

    func test_drillCategory_icon_nonEmpty() {
        for cat in DrillCategory.allCases {
            XCTAssertFalse(cat.icon.isEmpty, "\(cat.rawValue) icon should not be empty")
        }
    }

    func test_drillCategory_id_equalsRawValue() {
        for cat in DrillCategory.allCases {
            XCTAssertEqual(cat.id, cat.rawValue)
        }
    }

    // MARK: - DrillLevel

    func test_drillLevel_allCases_count5() {
        XCTAssertEqual(DrillLevel.allCases.count, 5)
    }

    func test_drillLevel_rawValues() {
        let expected = ["L0", "L1", "L2", "L3", "L4"]
        let actual = DrillLevel.allCases.map(\.rawValue)
        XCTAssertEqual(actual, expected)
    }

    func test_drillLevel_displayName_nonEmpty() {
        for level in DrillLevel.allCases {
            XCTAssertFalse(level.displayName.isEmpty,
                           "\(level.rawValue) displayName should not be empty")
        }
    }

    func test_drillLevel_displayNames_unique() {
        let names = DrillLevel.allCases.map(\.displayName)
        XCTAssertEqual(names.count, Set(names).count, "Display names must be unique")
    }

    // MARK: - BallTypeFilter

    func test_ballTypeFilter_allCases_count3() {
        XCTAssertEqual(BallTypeFilter.allCases.count, 3)
    }

    func test_ballTypeFilter_all_matchesAnyDrill() {
        let universalDrill = makeDrill(ballType: ["universal"])
        let chinese8Drill = makeDrill(ballType: ["chinese8"])
        let nineBallDrill = makeDrill(ballType: ["nineBall"])

        XCTAssertTrue(BallTypeFilter.all.matches(universalDrill))
        XCTAssertTrue(BallTypeFilter.all.matches(chinese8Drill))
        XCTAssertTrue(BallTypeFilter.all.matches(nineBallDrill))
    }

    func test_ballTypeFilter_chinese8_matchesChinese8AndUniversal() {
        let chinese8Drill = makeDrill(ballType: ["chinese8"])
        let universalDrill = makeDrill(ballType: ["universal"])
        let nineBallDrill = makeDrill(ballType: ["nineBall"])

        XCTAssertTrue(BallTypeFilter.chinese8.matches(chinese8Drill))
        XCTAssertTrue(BallTypeFilter.chinese8.matches(universalDrill))
        XCTAssertFalse(BallTypeFilter.chinese8.matches(nineBallDrill))
    }

    func test_ballTypeFilter_nineBall_matchesNineBallAndUniversal() {
        let chinese8Drill = makeDrill(ballType: ["chinese8"])
        let universalDrill = makeDrill(ballType: ["universal"])
        let nineBallDrill = makeDrill(ballType: ["nineBall"])

        XCTAssertFalse(BallTypeFilter.nineBall.matches(chinese8Drill))
        XCTAssertTrue(BallTypeFilter.nineBall.matches(universalDrill))
        XCTAssertTrue(BallTypeFilter.nineBall.matches(nineBallDrill))
    }

    func test_ballTypeFilter_multiBallType() {
        let multiDrill = makeDrill(ballType: ["chinese8", "nineBall"])
        XCTAssertTrue(BallTypeFilter.chinese8.matches(multiDrill))
        XCTAssertTrue(BallTypeFilter.nineBall.matches(multiDrill))
    }

    // MARK: - Helpers

    private func makeDrill(ballType: [String]) -> DrillContent {
        DrillContent(
            id: "test_drill",
            nameZh: "测试",
            nameEn: "Test",
            category: "fundamentals",
            subcategory: "test",
            ballType: ballType,
            level: "L0",
            difficulty: 1,
            isPremium: false,
            description: "Test drill",
            coachingPoints: ["Point 1"],
            standardCriteria: "Test criteria",
            sets: DrillContent.DrillSetsConfig(defaultSets: 3, defaultBallsPerSet: 10),
            animation: DrillAnimation(
                cueBall: BallAnimation(
                    start: CanvasPoint(x: 0.5, y: 0.25),
                    path: [PathPoint(x: 0.5, y: 0.4)]
                ),
                targetBall: BallAnimation(
                    start: CanvasPoint(x: 0.5, y: 0.42),
                    path: [PathPoint(x: 0.5, y: 0.5268)]
                ),
                pocket: "bottomCenter",
                cueDirection: CanvasPoint(x: 0.5, y: 0.0)
            )
        )
    }
}
