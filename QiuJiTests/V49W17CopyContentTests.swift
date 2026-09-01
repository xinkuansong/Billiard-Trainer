import XCTest
@testable import QiuJi

/// v49 W17：中级 / 高级蛇彩的首杆阶梯与长链路决策。
@MainActor
final class V49W17CopyContentTests: XCTestCase {

    func test_w17Drills_loadAndKeepShotCounts() async throws {
        let expected = ["drill_c069": 18, "drill_c071": 23]
        for (id, count) in expected {
            let content = try await drill(id)
            XCTAssertEqual(shotSectionCount(content), count, id)
            XCTAssertEqual(content.tutorial?.formations?.count, 2, id)
        }
    }

    func test_c069_separatesOpenFirstShotFromTenBallChain() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c069"))
        XCTAssertTrue(copy.contains("同一套不贴库三球"))
        XCTAssertTrue(copy.contains("8 杆彼此独立"))
        XCTAssertTrue(copy.contains("第 6 杆是整组的换侧点"))
        XCTAssertTrue(copy.contains("第 9 杆是收尾关键球"))
    }

    func test_c071_separatesRailConstrainedFirstShotFromFifteenBallChain() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c071"))
        XCTAssertTrue(copy.contains("靠近底库的三球布局"))
        XCTAssertTrue(copy.contains("低杆离库"))
        XCTAssertTrue(copy.contains("第 6 杆换侧和第 12 杆重新取位"))
        XCTAssertTrue(copy.contains("第 14 杆是最后的关键球"))
    }

    func test_w17NeighbourDescriptions_areNotInterchangeable() async throws {
        let intermediate = try await drill("drill_c069")
        let advanced = try await drill("drill_c071")
        XCTAssertTrue(intermediate.description.contains("不贴库"))
        XCTAssertTrue(intermediate.description.contains("十球"))
        XCTAssertFalse(intermediate.description.contains("十五球"))
        XCTAssertTrue(advanced.description.contains("靠近底库"))
        XCTAssertTrue(advanced.description.contains("十五球"))
        XCTAssertFalse(advanced.description.contains("十球"))
    }

    func test_w17Copy_removesConfigurationAndEquationTone() async throws {
        for id in ["drill_c069", "drill_c071"] {
            let copy = flattenedCopy(for: try await drill(id))
            for phrase in [" = ", " ≈ ", "锁死", "钉死", "训练档位", "这一档", "本档", "按示范", "锚点", "只改"] {
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
