import XCTest
@testable import QiuJi

@MainActor
final class DrillCoverAnnotationTests: XCTestCase {

    func test_fundamentals_firstFourCovers_areDistinct() async throws {
        let ids = ["drill_c006", "drill_c007", "drill_c008", "drill_c009"]
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
        XCTAssertEqual(Set(labels).count, 4, "First four fundamentals covers must differ: \(labels)")
    }

    func test_coverLabel_matchesMeasuredDistanceAndPocket_c006() async throws {
        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c006")
        let drill = try XCTUnwrap(loaded)
        let dist = try XCTUnwrap(DrillCoverAnnotation.cueTargetDistanceInTableLengths(for: drill))
        XCTAssertEqual(dist, 0.26, accuracy: 0.001)
        XCTAssertEqual(DrillCoverAnnotation.coverLabel(for: drill), "0.3台·下中袋")
    }

    func test_coverLabel_multiShotTutorial_c010() async throws {
        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c010")
        let drill = try XCTUnwrap(loaded)
        let label = try XCTUnwrap(DrillCoverAnnotation.coverLabel(for: drill))
        XCTAssertTrue(label.hasPrefix("4杆"), "c010 tutorial has four 第N杆 sections, got \(label)")
    }

    func test_coverLabel_doesNotUseCategoryName() async throws {
        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c006")
        let drill = try XCTUnwrap(loaded)
        let label = try XCTUnwrap(DrillCoverAnnotation.coverLabel(for: drill))
        XCTAssertFalse(label.contains("基础"), "Category must not appear on cover: \(label)")
        XCTAssertTrue(label.contains("下中袋") || label.contains("台"), label)
    }
}
