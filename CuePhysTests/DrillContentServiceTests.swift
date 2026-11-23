import XCTest
@testable import QiuJi

final class DrillContentServiceTests: XCTestCase {

    func test_loadDrillIndex_returnsNonNil() async {
        let index = await DrillContentService.shared.loadDrillIndex()
        XCTAssertNotNil(index, "Drill index should load from app bundle")
    }

    func test_loadDrillIndex_has8Categories() async {
        guard let index = await DrillContentService.shared.loadDrillIndex() else {
            XCTFail("Drill index not found")
            return
        }
        XCTAssertFalse(index.categories.isEmpty)
        XCTAssertEqual(index.categories.count, 8)
    }

    func test_loadDrillIndex_allDrillIds_notEmpty() async {
        guard let index = await DrillContentService.shared.loadDrillIndex() else {
            XCTFail("Drill index not found")
            return
        }
        XCTAssertGreaterThan(index.allDrillIds.count, 0)
    }

    func test_loadFallbackDrills_returnsNonEmpty() async {
        let drills = await DrillContentService.shared.loadFallbackDrills()
        XCTAssertGreaterThan(drills.count, 0, "Bundle should contain drills")
    }

    func test_loadDrillFromBundle_validId() async {
        let drill = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c001")
        XCTAssertNotNil(drill, "drill_c001 should exist in bundle")
        XCTAssertEqual(drill?.id, "drill_c001")
    }

    func test_loadDrillFromBundle_invalidId_returnsNil() async {
        let drill = await DrillContentService.shared.loadDrillFromBundle(id: "drill_nonexistent_xyz")
        XCTAssertNil(drill)
    }

    func test_drillContent_hasRequiredFields() async {
        guard let drill = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c001") else {
            XCTFail("drill_c001 not found")
            return
        }
        XCTAssertFalse(drill.nameZh.isEmpty)
        XCTAssertFalse(drill.nameEn.isEmpty)
        XCTAssertFalse(drill.category.isEmpty)
        XCTAssertFalse(drill.description.isEmpty)
        XCTAssertFalse(drill.coachingPoints.isEmpty)
        XCTAssertFalse(drill.standardCriteria.isEmpty)
    }
}
