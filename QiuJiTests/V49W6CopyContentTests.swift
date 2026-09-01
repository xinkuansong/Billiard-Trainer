import XCTest
@testable import QiuJi

/// v49 W6：挤偏认知、长台放大与塞量阶梯的训练边界。
@MainActor
final class V49W6CopyContentTests: XCTestCase {

    func test_w6Drills_loadFromBundle() async throws {
        for id in ["drill_c073", "drill_c074", "drill_c075"] {
            _ = try await drill(id)
        }
    }

    func test_c073_buildsFromDirectionToForceComparison() async throws {
        let drill = try await drill("drill_c073")
        let copy = flattenedCopy(for: drill)
        let formations = try XCTUnwrap(drill.tutorial?.formations)

        XCTAssertEqual(formations.count, 2)
        XCTAssertEqual(shotSectionCount(in: formations[0].sections), 7)
        XCTAssertEqual(shotSectionCount(in: formations[1].sections), 8)
        XCTAssertTrue(copy.contains("看清左、右塞会把起始路线挤向哪一边"))
        XCTAssertTrue(copy.contains("不能机械照搬上一杆的让点"))
        XCTAssertFalse(copy.contains("让点不动，只加长出杆"))
    }

    func test_c074_restoresFivePointIntent() async throws {
        let drill = try await drill("drill_c074")
        let copy = flattenedCopy(for: drill)
        let formations = try XCTUnwrap(drill.tutorial?.formations)

        XCTAssertEqual(formations.count, 2)
        XCTAssertEqual(shotSectionCount(in: formations[0].sections), 6)
        XCTAssertEqual(shotSectionCount(in: formations[1].sections), 9)
        XCTAssertTrue(copy.contains("远台加塞五分点"))
        XCTAssertTrue(copy.contains("母球停在 8 号原位附近"))
        XCTAssertFalse(copy.contains("不要按定杆去守原位"))
        XCTAssertFalse(copy.contains("也不按五分点原地转来打"))
    }

    func test_c075_observesRailRouteAcrossThreeCueHeights() async throws {
        let drill = try await drill("drill_c075")
        let copy = flattenedCopy(for: drill)
        let formations = try XCTUnwrap(drill.tutorial?.formations)

        XCTAssertEqual(formations.count, 3)
        XCTAssertEqual(formations.map { shotSectionCount(in: $0.sections) }, [7, 5, 5])
        XCTAssertTrue(copy.contains("观察碰库后的路线如何随击点分开"))
        XCTAssertTrue(copy.contains("示范中有一杆母球落袋"))
        XCTAssertTrue(drill.standardCriteria.contains("母球留台"))
        XCTAssertFalse(copy.contains("走位变线放到后面的课"))
    }

    func test_w6Drills_haveDistinctLearningProblems() async throws {
        let c073 = flattenedCopy(for: try await drill("drill_c073"))
        let c074 = flattenedCopy(for: try await drill("drill_c074"))
        let c075 = flattenedCopy(for: try await drill("drill_c075"))

        XCTAssertTrue(c073.contains("起始偏移"))
        XCTAssertTrue(c074.contains("长台会放大"))
        XCTAssertTrue(c075.contains("碰库位置和离库方向"))
        XCTAssertFalse(c073.contains("五分点"))
        XCTAssertFalse(c074.contains("三组近直线"))
    }

    private func drill(_ id: String) async throws -> DrillContent {
        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: id)
        return try XCTUnwrap(loaded, "\(id) 应从正式 Bundle 成功解码")
    }

    private func shotSectionCount(in sections: [TutorialSection]) -> Int {
        sections.filter { $0.title.hasPrefix("第") && $0.title.contains("杆：") }.count
    }

    private func flattenedCopy(for drill: DrillContent) -> String {
        let tutorialSections = (drill.tutorial?.sections ?? [])
            + (drill.tutorial?.formations ?? []).flatMap(\.sections)
        let tutorialCopy = tutorialSections.flatMap { section in
            [section.title, section.content ?? ""]
                + (section.items ?? []).flatMap { [$0.label, $0.text] }
                + [section.caption ?? ""]
        }
        return ([drill.nameZh, drill.description, drill.standardCriteria]
            + drill.coachingPoints
            + tutorialCopy)
            .joined(separator: "\n")
    }
}
