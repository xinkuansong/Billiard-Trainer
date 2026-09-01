import XCTest
@testable import QiuJi

/// v49 W9：自然分离、薄厚变化、力度与前后旋边界。
@MainActor
final class V49W9CopyContentTests: XCTestCase {

    func test_w9Drills_loadAndKeepCurrentShotCounts() async throws {
        let expected = [
            "drill_c024": [6], "drill_c025": [6, 7], "drill_c026": [5, 7, 5],
            "drill_c027": [4], "drill_c028": [4]
        ]
        for (id, counts) in expected {
            let drill = try await drill(id)
            let groups = drill.tutorial?.formations?.map(\.sections) ?? [drill.tutorial?.sections ?? []]
            XCTAssertEqual(groups.map(shotSectionCount), counts, id)
        }
    }

    func test_c024_definesNinetyDegreesAtCollisionNotFinalLanding() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c024"))
        XCTAssertTrue(copy.contains("碰撞瞬间接近无前后旋"))
        XCTAssertTrue(copy.contains("第一段路线会接近这条线的垂线"))
        XCTAssertTrue(copy.contains("最终落点不作为 90° 的判据"))
    }

    func test_thinAndThickDrills_keepDifferentFirstPrinciples() async throws {
        let thin = flattenedCopy(for: try await drill("drill_c025"))
        let thick = flattenedCopy(for: try await drill("drill_c026"))
        XCTAssertTrue(thin.contains("母球会保留较多原来的运动方向"))
        XCTAssertTrue(thick.contains("越接近正碰，母球在碰撞后保留的速度越少"))
        XCTAssertTrue(thick.contains("到达碰撞点时仍在滑动还是已经自然前滚"))
    }

    func test_followAndDraw_changeEarlyCurveNotGuaranteedFinalOrder() async throws {
        let follow = flattenedCopy(for: try await drill("drill_c027"))
        let draw = flattenedCopy(for: try await drill("drill_c028"))
        XCTAssertTrue(follow.contains("前旋，路线会在随后向前弯"))
        XCTAssertTrue(draw.contains("底旋，路线会在随后向后弯"))
        XCTAssertTrue(follow.contains("最终落点只作辅助"))
        XCTAssertTrue(draw.contains("最终落点只作辅助"))
    }

    func test_w9Copy_removesConfigurationAndEquationTone() async throws {
        for id in ["drill_c024", "drill_c025", "drill_c026", "drill_c027", "drill_c028"] {
            let copy = flattenedCopy(for: try await drill(id))
            XCTAssertFalse(copy.contains("为什么这样排"), id)
            XCTAssertFalse(copy.contains(" = "), id)
            XCTAssertFalse(copy.contains(" ≈ "), id)
            XCTAssertFalse(copy.contains("锁死"), id)
            XCTAssertFalse(copy.contains("钉死"), id)
            XCTAssertFalse(copy.contains("训练档位"), id)
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
