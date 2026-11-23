import XCTest
@testable import QiuJi

/// v49 W11：走位方向、距离、目标区域与库数边界。
@MainActor
final class V49W11CopyContentTests: XCTestCase {

    func test_w11Drills_loadAndKeepCurrentShotCounts() async throws {
        let expected = [
            "drill_c005": 4, "drill_c034": 5, "drill_c035": 8,
            "drill_c036": 9, "drill_c037": 3, "drill_c038": 12
        ]
        for (id, count) in expected {
            let drill = try await drill(id)
            XCTAssertEqual(shotSectionCount(drill.tutorial?.sections ?? []), count, id)
        }
    }

    func test_c005_isIndependentReversePlanningNotAContinuousRun() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c005"))
        XCTAssertTrue(copy.contains("四个常见球形分别练一库走位"))
        XCTAssertTrue(copy.contains("确定下一杆需要的角度"))
        XCTAssertTrue(copy.contains("不要把四杆连成清台顺序"))
    }

    func test_c034_followsCurrentAllDrawSequenceAndMovingReference() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c034"))
        XCTAssertTrue(copy.contains("当前五杆都使用低杆系打点"))
        XCTAssertTrue(copy.contains("8 号会随杆次移动"))
        XCTAssertTrue(copy.contains("母球不碰库"))
        XCTAssertFalse(copy.contains("高杆往前"))
    }

    func test_c035AndC036_separateNaturalLineFromSideSpinCorrection() async throws {
        let follow = flattenedCopy(for: try await drill("drill_c035"))
        let draw = flattenedCopy(for: try await drill("drill_c036"))
        XCTAssertTrue(follow.contains("无塞高杆建立自然路线"))
        XCTAssertTrue(follow.contains("左右塞修正出库方向"))
        XCTAssertTrue(draw.contains("无塞低杆建立自然回撤线"))
        XCTAssertTrue(draw.contains("侧旋主要影响入库后的方向"))
    }

    func test_c037_teachesMultipleRoutesIntoOnePlayableArea() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c037"))
        XCTAssertTrue(copy.contains("同一目标区域不一定只有一种走法"))
        XCTAssertTrue(copy.contains("中杆、中高杆和纯低杆设计三条路线"))
        XCTAssertTrue(copy.contains("角度和出杆空间"))
    }

    func test_c038_qualifiesRatherThanUniversalizesTwoCushionTolerance() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c038"))
        XCTAssertTrue(copy.contains("横穿区域能给力度留出一定余量"))
        XCTAssertTrue(copy.contains("并不天然比一库简单"))
        XCTAssertTrue(copy.contains("倒推第二次和第一次碰库点"))
    }

    func test_w11Copy_removesConfigurationAndEquationTone() async throws {
        for id in ["drill_c005", "drill_c034", "drill_c035", "drill_c036", "drill_c037", "drill_c038"] {
            let copy = flattenedCopy(for: try await drill(id))
            for phrase in ["为什么这样排", " = ", " ≈ ", "锁死", "钉死", "训练档位", "这一档", "本档", "按示范"] {
                XCTAssertFalse(copy.contains(phrase), "\(id): \(phrase)")
            }
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
