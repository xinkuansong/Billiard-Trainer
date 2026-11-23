import XCTest
@testable import QiuJi

/// v49 W5：近台、薄球与远台三组带塞准度课的边界和示范偏差契约。
@MainActor
final class V49W5CopyContentTests: XCTestCase {

    func test_w5Drills_loadFromBundle() async throws {
        for id in ["drill_c076", "drill_c077", "drill_c078"] {
            _ = try await drill(id)
        }
    }

    func test_c076_pairsLeftAndRightSpinAcrossTwoPockets() async throws {
        let drill = try await drill("drill_c076")
        let copy = flattenedCopy(for: drill)
        let formations = try XCTUnwrap(drill.tutorial?.formations)

        XCTAssertEqual(formations.count, 2)
        XCTAssertEqual(shotSectionCount(in: formations[0].sections), 14)
        XCTAssertEqual(shotSectionCount(in: formations[1].sections), 14)
        XCTAssertTrue(copy.contains("同一摆位先打左塞，再打右塞"))
        XCTAssertTrue(copy.contains("换到另一个袋口后，重新看进球线"))
        XCTAssertFalse(copy.contains("中袋更窄"))
        XCTAssertFalse(copy.contains("开档"))
    }

    func test_c077_isTruthfulAboutRightSpinOnlySequence() async throws {
        let drill = try await drill("drill_c077")
        let copy = flattenedCopy(for: drill)
        let sections = try XCTUnwrap(drill.tutorial?.sections)

        XCTAssertEqual(shotSectionCount(in: sections), 5)
        XCTAssertTrue(copy.contains("这五个摆位只练右塞"))
        XCTAssertTrue(copy.contains("前 3 杆小力，第 4、5 杆逐步加力"))
        XCTAssertFalse(copy.contains("分别带左塞和右塞"))
        XCTAssertFalse(copy.contains("上限档"))
    }

    func test_c078_requiresCueBallToStayAndDisclosesRecordedScratches() async throws {
        let drill = try await drill("drill_c078")
        let copy = flattenedCopy(for: drill)
        let sections = try XCTUnwrap(drill.tutorial?.sections)

        XCTAssertEqual(shotSectionCount(in: sections), 16)
        XCTAssertTrue(copy.contains("母球到 8 号约 1.5～1.6 米"))
        XCTAssertTrue(copy.contains("示范第 8、10、12、14、16 杆的母球落袋不是合格结果"))
        XCTAssertTrue(drill.standardCriteria.contains("母球留台"))
        XCTAssertFalse(copy.contains("母球宜留台"))
        XCTAssertFalse(copy.contains("让点被远距吃掉"))
    }

    func test_w5Drills_explainDifferentTrainingProblems() async throws {
        let c076 = flattenedCopy(for: try await drill("drill_c076"))
        let c077 = flattenedCopy(for: try await drill("drill_c077"))
        let c078 = flattenedCopy(for: try await drill("drill_c078"))

        XCTAssertTrue(c076.contains("先练左侧中袋，再换左下角袋"))
        XCTAssertTrue(c077.contains("只把母球逐步移到更薄的位置"))
        XCTAssertTrue(c078.contains("长瞄准线下的加塞准度"))
        XCTAssertFalse(c076.contains("长瞄准线下"))
        XCTAssertFalse(c077.contains("高杆左塞"))
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
