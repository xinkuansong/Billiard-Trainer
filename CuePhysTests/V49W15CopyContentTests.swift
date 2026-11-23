import XCTest
@testable import QiuJi

/// v49 W15：翻袋、直接 K 球、吃库 K 球与贴库球的动作对象边界。
@MainActor
final class V49W15CopyContentTests: XCTestCase {

    func test_w15Drills_loadAndKeepCurrentShotCounts() async throws {
        let expected = [
            "drill_c054": 5,
            "drill_c055": 5,
            "drill_c056": 3,
            "drill_c057": 3,
            "drill_c058": 2
        ]
        for (id, count) in expected {
            let content = try await drill(id)
            XCTAssertEqual(shotSectionCount(content), count, id)
        }
    }

    func test_c054_explainsBankLineWithoutPretendingOneAimPointFitsAll() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c054"))
        XCTAssertTrue(copy.contains("五个起点覆盖正角和反角"))
        XCTAssertTrue(copy.contains("根据上一杆的反弹结果微调"))
        XCTAssertTrue(copy.contains("前两杆中力，后三杆小力"))
        XCTAssertFalse(copy.contains("袋口和低杆锁死"))
    }

    func test_c055_usesConfirmedSidePocketToleranceAndKeepsTheSpinException() async throws {
        let content = try await drill("drill_c055")
        let copy = flattenedCopy(for: content)
        XCTAssertTrue(copy.contains("中袋翻袋的进球容错比底袋更大"))
        XCTAssertTrue(copy.contains("只有第三杆加半颗皮头左塞"))
        XCTAssertTrue(copy.contains("10 次翻袋中至少 3 次 8 号进左侧中袋，且母球留台"))
        XCTAssertFalse(copy.contains("中袋容错更小"))
        XCTAssertFalse(copy.contains("袋口比角袋窄"))
        XCTAssertFalse(copy.contains("中袋容错小于角袋"))
    }

    func test_c056_definesNoCushionKShotWithCorrectBallRoles() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c056"))
        XCTAssertTrue(copy.contains("先把 1 号打进左下角袋"))
        XCTAssertTrue(copy.contains("母球不先碰库并直接 K 到 2 号"))
        XCTAssertTrue(copy.contains("2 号正是这杆要 K 的球"))
        XCTAssertFalse(copy.contains("把 1 号 K 到"))
    }

    func test_c057_definesCushionKShotWithCorrectOrder() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c057"))
        XCTAssertTrue(copy.contains("先把 1 号打进左下角袋"))
        XCTAssertTrue(copy.contains("母球碰库后 K 到 2 号"))
        XCTAssertTrue(copy.contains("进球线、回旋方向和库边反弹缺一不可"))
        XCTAssertFalse(copy.contains("再看母球随后碰库"))
    }

    func test_c057_keepsThreeRecordedCueingPatternsDistinct() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c057"))
        XCTAssertTrue(copy.contains("球形 1 用纯低杆中大力"))
        XCTAssertTrue(copy.contains("球形 2 用中高杆中力"))
        XCTAssertTrue(copy.contains("球形 3 用中低杆中力"))
    }

    func test_c058_separatesFullyFrozenAndSlightlyOffRailShots() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c058"))
        XCTAssertTrue(copy.contains("完全贴库时用高杆轻推"))
        XCTAssertTrue(copy.contains("微离库边时改用中杆中力"))
        XCTAssertTrue(copy.contains("不要立刻用侧塞补偿"))
    }

    func test_w15Copy_removesConfigurationAndEquationTone() async throws {
        for id in ["drill_c054", "drill_c055", "drill_c056", "drill_c057", "drill_c058"] {
            let copy = flattenedCopy(for: try await drill(id))
            for phrase in [" = ", " ≈ ", "锁死", "钉死", "训练档位", "这一档", "本档", "按示范"] {
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
