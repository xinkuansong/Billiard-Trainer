import XCTest
@testable import QiuJi

@MainActor
final class DrillTutorialKindResolverTests: XCTestCase {

    func test_modernDrill_hasItems_resolvesModern() async throws {
        let drill = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c001")
        let kind = DrillTutorialKindResolver.resolve(for: try XCTUnwrap(drill))
        XCTAssertEqual(kind, .modern)
    }

    func test_legacyDrill_plainSections_resolvesLegacy() async throws {
        let drill = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c032")
        let kind = DrillTutorialKindResolver.resolve(for: try XCTUnwrap(drill))
        XCTAssertEqual(kind, .legacy)
    }

    func test_bundleCounts_modernAndLegacyPartition() async {
        let drills = await DrillContentService.shared.loadFallbackDrills()
        XCTAssertFalse(drills.isEmpty)

        var modern = 0
        var legacy = 0
        var none = 0
        for drill in drills {
            switch DrillTutorialKindResolver.resolve(for: drill) {
            case .modern: modern += 1
            case .legacy: legacy += 1
            case .none: none += 1
            }
        }
        // 2026-08-03 inventory: 25 modern / 52 legacy / 0 none (v25 §2.7).
        XCTAssertEqual(modern + legacy + none, drills.count)
        XCTAssertEqual(none, 0, "All bundled drills currently ship a tutorial")
        XCTAssertGreaterThan(modern, 0)
        XCTAssertGreaterThan(legacy, 0)
    }

    func test_levelFilter_matchesTrainingTabMapping() {
        XCTAssertTrue(DrillLevelFilter.beginner.matches("L0"))
        XCTAssertFalse(DrillLevelFilter.beginner.matches("L1"))
        XCTAssertTrue(DrillLevelFilter.elementary.matches("L1"))
        XCTAssertTrue(DrillLevelFilter.intermediate.matches("L2"))
        XCTAssertTrue(DrillLevelFilter.advanced.matches("L3"))
        XCTAssertTrue(DrillLevelFilter.advanced.matches("L4"))
        XCTAssertFalse(DrillLevelFilter.advanced.matches("L2"))
    }
}
