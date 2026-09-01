import XCTest
@testable import QiuJi

/// v49 W13：新录多杆链的顺序、换边与关键杆边界。
@MainActor
final class V49W13CopyContentTests: XCTestCase {

    func test_w13Drills_loadAndKeepCurrentShotCounts() async throws {
        let expected = ["drill_c079": 4, "drill_c080": 4, "drill_c081": 4, "drill_c082": 12]
        for (id, count) in expected {
            let content = try await drill(id)
            XCTAssertEqual(shotSectionCount(content), count, id)
        }
    }

    func test_c079_limitsOneCushionPositioningToFirstThreeShots() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c079"))
        XCTAssertTrue(copy.contains("前三杆都让母球走一库换边"))
        XCTAssertTrue(copy.contains("第四杆收尾"))
        XCTAssertTrue(copy.contains("前三杆后母球都完成一库换边"))
        XCTAssertFalse(copy.contains("每一杆都吃一库"))
    }

    func test_c080_isAReSpottedTwoBallShuttle() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c080"))
        XCTAssertTrue(copy.contains("进袋后复位"))
        XCTAssertTrue(copy.contains("三次把母球送到另一半台"))
        XCTAssertTrue(copy.contains("前三杆后都能从停位直接击打下一颗"))
    }

    func test_c081_keepsOneAndTwoCushionRoutesDistinct() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c081"))
        XCTAssertTrue(copy.contains("一库或两库把母球叫回"))
        XCTAssertTrue(copy.contains("能用较短路线到位，就不要额外增加一次碰库"))
        XCTAssertTrue(copy.contains("目标袋始终是左下角袋"))
    }

    func test_c082_statesTheAlternatingTargetAndSpaceChecks() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c082"))
        XCTAssertTrue(copy.contains("按彩球、8 号交替的顺序连续击打"))
        XCTAssertTrue(copy.contains("打完彩球要回到 8 号，打完 8 号要去另一侧彩球"))
        XCTAssertTrue(copy.contains("看得见下一颗，并留出正常架杆空间"))
    }

    func test_w13Copy_removesConfigurationAndEquationTone() async throws {
        for id in ["drill_c079", "drill_c080", "drill_c081", "drill_c082"] {
            let copy = flattenedCopy(for: try await drill(id))
            for phrase in [" = ", " ≈ ", "锁死", "钉死", "训练档位", "这一档", "本档", "按示范", "锁杆法"] {
                XCTAssertFalse(copy.contains(phrase), "\(id): \(phrase)")
            }
        }
    }

    private func drill(_ id: String) async throws -> DrillContent {
        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: id)
        return try XCTUnwrap(loaded, "\(id) 应从正式 Bundle 成功解码")
    }

    private func shotSectionCount(_ drill: DrillContent) -> Int {
        let sections = (drill.tutorial?.sections ?? []) + (drill.tutorial?.formations ?? []).flatMap(\.sections)
        return sections.filter { $0.title.hasPrefix("第") && $0.title.contains("杆：") }.count
    }

    private func flattenedCopy(for drill: DrillContent) -> String {
        let sections = (drill.tutorial?.sections ?? []) + (drill.tutorial?.formations ?? []).flatMap(\.sections)
        let tutorial = sections.flatMap { [$0.title, $0.content ?? ""] + ($0.items ?? []).flatMap { [$0.label, $0.text] } + [$0.caption ?? ""] }
        return ([drill.nameZh, drill.description, drill.standardCriteria] + drill.coachingPoints + tutorial).joined(separator: "\n")
    }
}
