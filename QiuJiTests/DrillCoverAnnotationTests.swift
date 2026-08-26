import XCTest
@testable import QiuJi

@MainActor
final class DrillCoverAnnotationTests: XCTestCase {

    func test_fundamentals_remainingCovers_areDistinct() async throws {
        let ids = ["drill_c012", "drill_c009", "drill_c022", "drill_c001", "drill_c010", "drill_c023"]
        var labels: [String] = []
        for id in ids {
            let loaded = await DrillContentService.shared.loadDrillFromBundle(id: id)
            let drill = try XCTUnwrap(loaded)
            let label = try XCTUnwrap(
                DrillCoverAnnotation.coverLabel(for: drill),
                "\(id) should derive a cover label"
            )
            labels.append(label)
        }
        XCTAssertEqual(Set(labels).count, ids.count, "Fundamentals covers must differ: \(labels)")
    }

    func test_coverLabel_multiShotTutorial_c010() async throws {
        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c010")
        let drill = try XCTUnwrap(loaded)
        let label = try XCTUnwrap(DrillCoverAnnotation.coverLabel(for: drill))
        XCTAssertTrue(label.hasPrefix("7杆"), "c010 现网封面为 7 杆量级，got \(label)")
    }

    func test_coverLabel_doesNotUseCategoryName() async throws {
        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c009")
        let drill = try XCTUnwrap(loaded)
        let label = try XCTUnwrap(DrillCoverAnnotation.coverLabel(for: drill))
        XCTAssertFalse(label.contains("基础"), "Category must not appear on cover: \(label)")
        XCTAssertTrue(label.contains("袋") || label.contains("台"), label)
    }
}
