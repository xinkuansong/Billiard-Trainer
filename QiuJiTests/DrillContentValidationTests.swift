import XCTest
@testable import QiuJi

/// Validates all 72 Drill JSONs loaded from Bundle for Schema compliance,
/// coordinate bounds, isPremium/level consistency, and animation integrity.
final class DrillContentValidationTests: XCTestCase {

    private var allDrills: [DrillContent] = []
    private var drillIndex: DrillIndex!

    override func setUp() async throws {
        try await super.setUp()
        let index = await DrillContentService.shared.loadDrillIndex()
        XCTAssertNotNil(index, "Drill index must load from bundle")
        drillIndex = index!
        allDrills = await DrillContentService.shared.loadFallbackDrills()
    }

    // MARK: - Index Integrity

    func test_index_has8Categories() {
        XCTAssertEqual(drillIndex.categories.count, 8, "Index must have exactly 8 categories")
    }

    func test_index_totalDrillCount_is72() {
        XCTAssertEqual(drillIndex.allDrillIds.count, 72, "Index should reference 72 drill IDs")
    }

    func test_index_allIdsUnique() {
        let ids = drillIndex.allDrillIds
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "All drill IDs in index must be unique")
    }

    func test_index_categoryNames_matchDrillCategoryEnum() {
        let expectedCategories = Set(DrillCategory.allCases.map(\.rawValue))
        let indexCategories = Set(drillIndex.categories.map(\.category))
        XCTAssertEqual(indexCategories, expectedCategories,
                       "Index categories must match DrillCategory enum cases")
    }

    func test_allIndexedDrills_loadSuccessfully() {
        let loadedIds = Set(allDrills.map(\.id))
        let indexedIds = Set(drillIndex.allDrillIds)
        let missing = indexedIds.subtracting(loadedIds)
        XCTAssertTrue(missing.isEmpty,
                      "These indexed drills failed to load: \(missing.sorted())")
    }

    func test_loadedDrillCount_matches72() {
        XCTAssertEqual(allDrills.count, 72, "Should load exactly 72 drills from bundle")
    }

    // MARK: - Schema Field Validation (every drill)

    func test_allDrills_haveNonEmptyRequiredFields() {
        for drill in allDrills {
            XCTAssertFalse(drill.id.isEmpty, "\(drill.id): id is empty")
            XCTAssertFalse(drill.nameZh.isEmpty, "\(drill.id): nameZh is empty")
            XCTAssertFalse(drill.nameEn.isEmpty, "\(drill.id): nameEn is empty")
            XCTAssertFalse(drill.category.isEmpty, "\(drill.id): category is empty")
            XCTAssertFalse(drill.subcategory.isEmpty, "\(drill.id): subcategory is empty")
            XCTAssertFalse(drill.ballType.isEmpty, "\(drill.id): ballType is empty")
            XCTAssertFalse(drill.level.isEmpty, "\(drill.id): level is empty")
            XCTAssertFalse(drill.description.isEmpty, "\(drill.id): description is empty")
            XCTAssertFalse(drill.coachingPoints.isEmpty, "\(drill.id): coachingPoints is empty")
            XCTAssertFalse(drill.standardCriteria.isEmpty, "\(drill.id): standardCriteria is empty")
        }
    }

    func test_allDrills_categoryMatchesDrillCategoryEnum() {
        let validCategories = Set(DrillCategory.allCases.map(\.rawValue))
        for drill in allDrills {
            XCTAssertTrue(validCategories.contains(drill.category),
                          "\(drill.id): category '\(drill.category)' is not a valid DrillCategory")
        }
    }

    func test_allDrills_levelIsValidDrillLevel() {
        let validLevels = Set(DrillLevel.allCases.map(\.rawValue))
        for drill in allDrills {
            XCTAssertTrue(validLevels.contains(drill.level),
                          "\(drill.id): level '\(drill.level)' is not a valid DrillLevel")
        }
    }

    func test_allDrills_difficultyInRange1to5() {
        for drill in allDrills {
            XCTAssertTrue((1...5).contains(drill.difficulty),
                          "\(drill.id): difficulty \(drill.difficulty) not in 1...5")
        }
    }

    func test_allDrills_ballTypeValuesAreValid() {
        let validTypes: Set<String> = ["chinese8", "nineBall", "universal", "snooker"]
        for drill in allDrills {
            for bt in drill.ballType {
                XCTAssertTrue(validTypes.contains(bt),
                              "\(drill.id): ballType '\(bt)' is not recognized")
            }
        }
    }

    func test_allDrills_setsConfigValid() {
        for drill in allDrills {
            XCTAssertGreaterThan(drill.sets.defaultSets, 0,
                                 "\(drill.id): defaultSets must be > 0")
            XCTAssertGreaterThan(drill.sets.defaultBallsPerSet, 0,
                                 "\(drill.id): defaultBallsPerSet must be > 0")
        }
    }

    // MARK: - Animation Coordinate Validation

    func test_allDrills_cueBallStartWithinBounds() {
        for drill in allDrills {
            assertPointWithinTable(drill.animation.cueBall.start,
                                   context: "\(drill.id) cueBall.start")
        }
    }

    func test_allDrills_targetBallStartWithinBounds() {
        for drill in allDrills {
            assertPointWithinTable(drill.animation.targetBall.start,
                                   context: "\(drill.id) targetBall.start")
        }
    }

    func test_allDrills_animationPathsNotEmpty() {
        for drill in allDrills {
            XCTAssertFalse(drill.animation.cueBall.path.isEmpty,
                           "\(drill.id): cueBall path is empty")
            XCTAssertFalse(drill.animation.targetBall.path.isEmpty,
                           "\(drill.id): targetBall path is empty")
        }
    }

    func test_allDrills_pocketValueIsValid() {
        let validPockets: Set<String> = [
            "topLeft", "topRight", "bottomLeft", "bottomRight",
            "topCenter", "bottomCenter"
        ]
        for drill in allDrills {
            XCTAssertTrue(validPockets.contains(drill.animation.pocket),
                          "\(drill.id): pocket '\(drill.animation.pocket)' is invalid")
        }
    }

    // MARK: - isPremium Distribution

    func test_L0drills_allFree() {
        let l0Drills = allDrills.filter { $0.level == "L0" }
        for drill in l0Drills {
            XCTAssertFalse(drill.isPremium,
                           "\(drill.id): L0 drill must be free (isPremium=false)")
        }
    }

    func test_freeDrills_exist() {
        let freeDrills = allDrills.filter { !$0.isPremium }
        XCTAssertGreaterThan(freeDrills.count, 0, "Must have at least some free drills")
    }

    func test_premiumDrills_exist() {
        let premiumDrills = allDrills.filter { $0.isPremium }
        XCTAssertGreaterThan(premiumDrills.count, 0, "Must have at least some premium drills")
    }

    // MARK: - Category Distribution

    func test_everyCategory_hasAtLeastOneDrill() {
        for category in DrillCategory.allCases {
            let drillsInCat = allDrills.filter { $0.category == category.rawValue }
            XCTAssertGreaterThan(drillsInCat.count, 0,
                                 "Category '\(category.rawValue)' has no drills")
        }
    }

    // MARK: - Helpers

    private func assertPointWithinTable(_ point: CanvasPoint, context: String) {
        let margin: Double = 0.05
        XCTAssertGreaterThanOrEqual(point.x, -margin,
                                     "\(context): x=\(point.x) below minimum")
        XCTAssertLessThanOrEqual(point.x, 1.0 + margin,
                                  "\(context): x=\(point.x) above maximum")
        XCTAssertGreaterThanOrEqual(point.y, -margin,
                                     "\(context): y=\(point.y) below minimum")
        XCTAssertLessThanOrEqual(point.y, 0.5 + margin,
                                  "\(context): y=\(point.y) above maximum")
    }
}
