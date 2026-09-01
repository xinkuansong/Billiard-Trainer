import XCTest
@testable import QiuJi

/// v49 W4：极薄角度球与中袋切球的文案、球形分层及示范偏差契约。
@MainActor
final class V49W4CopyContentTests: XCTestCase {

    func test_w4Drills_loadFromBundle() async throws {
        for id in ["drill_c052", "drill_c053"] {
            _ = try await drill(id)
        }
    }

    func test_c052_separatesAimThicknessFromDeliverySpeed() async throws {
        let drill = try await drill("drill_c052")
        let copy = flattenedCopy(for: drill)
        let sections = try XCTUnwrap(drill.tutorial?.sections)

        XCTAssertEqual(drill.nameZh, "极薄角度球")
        XCTAssertEqual(shotSectionCount(in: sections), 7)
        XCTAssertTrue(copy.contains("厚薄靠瞄准，进袋速度靠力度"))
        XCTAssertTrue(copy.contains("这一杆的示范没有把 8 号打进袋，不是合格结果"))
        XCTAssertTrue(copy.contains("同一摆位连续进 3 次，才算通过"))
        XCTAssertFalse(copy.contains("砸厚"))
        XCTAssertFalse(copy.contains("接触立住"))
    }

    func test_c053_keepsTwoMiddlePocketFormationsDistinct() async throws {
        let drill = try await drill("drill_c053")
        let copy = flattenedCopy(for: drill)
        let formations = try XCTUnwrap(drill.tutorial?.formations)

        XCTAssertEqual(formations.count, 2)
        XCTAssertEqual(shotSectionCount(in: formations[0].sections), 10)
        XCTAssertEqual(shotSectionCount(in: formations[1].sections), 13)
        XCTAssertTrue(copy.contains("正反两边都能重新找准厚薄"))
        XCTAssertTrue(copy.contains("这一形把 8 号到中袋的距离拉长约 10 公分"))
        XCTAssertTrue(copy.contains("第 11 杆示范母球落袋"))
        XCTAssertTrue(copy.contains("母球进袋就重来"))
        XCTAssertTrue(drill.standardCriteria.contains("母球留台"))
        XCTAssertFalse(copy.contains("更吃厚薄"))
        XCTAssertFalse(copy.contains("侧向搞反"))
        XCTAssertFalse(copy.contains("按示范小力"))
    }

    func test_w4Drills_explainDifferentTrainingProblems() async throws {
        let c052 = flattenedCopy(for: try await drill("drill_c052"))
        let c053 = flattenedCopy(for: try await drill("drill_c053"))

        XCTAssertTrue(c052.contains("切角从中大逐步推到极薄"))
        XCTAssertTrue(c052.contains("后 3 杆逐步加力"))
        XCTAssertFalse(c052.contains("中袋入口"))

        XCTAssertTrue(c053.contains("中袋对进球方向更挑剔"))
        XCTAssertTrue(c053.contains("母球沿 L 形"))
        XCTAssertFalse(c053.contains("后 3 杆逐步加力"))
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
