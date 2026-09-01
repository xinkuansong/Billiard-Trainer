import XCTest
@testable import QiuJi

/// v49 W8：加塞一库变线、高杆加塞与低杆加塞的内容边界。
@MainActor
final class V49W8CopyContentTests: XCTestCase {

    func test_w8Drills_loadAndKeepCurrentShotCounts() async throws {
        let expected = ["drill_c018": 9, "drill_c020": 16, "drill_c021": 12]
        for (id, count) in expected {
            let drill = try await drill(id)
            XCTAssertEqual(shotSectionCount(drill.tutorial?.sections ?? []), count, id)
        }
    }

    func test_c018_comparesCueActionsOnOneFixedFormation() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c018"))
        XCTAssertTrue(copy.contains("九杆保持同一摆位"))
        XCTAssertTrue(copy.contains("第一碰库点、出库方向和最终停区"))
        XCTAssertTrue(copy.contains("入库方向、到库时剩余的前后旋与侧旋、以及速度"))
    }

    func test_followAndDrawSideSpin_keepDistinctObservationOrder() async throws {
        let follow = flattenedCopy(for: try await drill("drill_c020"))
        let draw = flattenedCopy(for: try await drill("drill_c021"))
        XCTAssertTrue(follow.contains("母球跟进后的第一碰库点"))
        XCTAssertTrue(draw.contains("先看母球碰库前的回拉线路"))
        XCTAssertTrue(draw.contains("当前序列包含六组不同切角"))
        XCTAssertFalse(draw.contains("不改角度"))
    }

    func test_w8Copy_removesConfigurationAndEquationTone() async throws {
        for id in ["drill_c018", "drill_c020", "drill_c021"] {
            let copy = flattenedCopy(for: try await drill(id))
            XCTAssertFalse(copy.contains("为什么这样排"), id)
            XCTAssertFalse(copy.contains(" = "), id)
            XCTAssertFalse(copy.contains("钉死"), id)
            XCTAssertFalse(copy.contains("仍锁"), id)
            XCTAssertFalse(copy.contains("拧开"), id)
        }
    }

    private func drill(_ id: String) async throws -> DrillContent {
        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: id)
        return try XCTUnwrap(loaded, "\(id) 应从正式 Bundle 成功解码")
    }

    private func shotSectionCount(_ sections: [TutorialSection]) -> Int {
        sections.filter { $0.title.hasPrefix("第") && $0.title.contains("杆：") }.count
    }

    private func flattenedCopy(for drill: DrillContent) -> String {
        let sections = (drill.tutorial?.sections ?? []) + (drill.tutorial?.formations ?? []).flatMap(\.sections)
        let tutorial = sections.flatMap { [$0.title, $0.content ?? ""] + ($0.items ?? []).flatMap { [$0.label, $0.text] } + [$0.caption ?? ""] }
        return ([drill.nameZh, drill.description, drill.standardCriteria] + drill.coachingPoints + tutorial).joined(separator: "\n")
    }
}
