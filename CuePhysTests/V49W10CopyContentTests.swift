import XCTest
@testable import QiuJi

/// v49 W10：分离角走位、参考球校准与吃库边界。
@MainActor
final class V49W10CopyContentTests: XCTestCase {

    func test_w10Drills_loadAndKeepCurrentShotCounts() async throws {
        let expected = [
            "drill_c029": 6,
            "drill_c030": 5,
            "drill_c031": 13,
            "drill_c083": 8,
            "drill_c084": 8
        ]
        for (id, count) in expected {
            let drill = try await drill(id)
            XCTAssertEqual(shotSectionCount(drill.tutorial?.sections ?? []), count, id)
        }
    }

    func test_c029_keepsNinetyDegreeConditionAndRecordedAngleOrder() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c029"))
        XCTAssertTrue(copy.contains("轻微低杆用于抵消自然前滚"))
        XCTAssertTrue(copy.contains("22°、13°、5°、4°、13°、21°"))
        XCTAssertTrue(copy.contains("第一段路线才会接近切线"))
    }

    func test_c030_plansBackwardFromMovingEightBallReference() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c030"))
        XCTAssertTrue(copy.contains("8 号会出现在不同位置"))
        XCTAssertTrue(copy.contains("再倒推这一杆的落点"))
        XCTAssertTrue(copy.contains("8 号只表示下一杆的位置"))
    }

    func test_c031_keepsForceFixedAndUsesReferenceBallAsResult() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c031"))
        XCTAssertTrue(copy.contains("力度保持 3.4 m/s"))
        XCTAssertTrue(copy.contains("参考球给出的是整条路线的结果"))
        XCTAssertTrue(copy.contains("5 号会随线路入袋"))
        XCTAssertTrue(copy.contains("11 号会随线路入袋"))
    }

    func test_c083_andC084_keepCushionBoundaryClear() async throws {
        let cushion = flattenedCopy(for: try await drill("drill_c083"))
        let direct = flattenedCopy(for: try await drill("drill_c084"))
        XCTAssertTrue(cushion.contains("入库角和出库角近似相等当作起始估算"))
        XCTAssertTrue(cushion.contains("入库速度、打点高低、剩余侧旋和库边状态"))
        XCTAssertTrue(direct.contains("去掉库边反弹"))
        XCTAssertTrue(direct.contains("母球不吃库并碰到事先指定的参考球"))
    }

    func test_w10Copy_removesConfigurationAndEquationTone() async throws {
        for id in ["drill_c029", "drill_c030", "drill_c031", "drill_c083", "drill_c084"] {
            let copy = flattenedCopy(for: try await drill(id))
            XCTAssertFalse(copy.contains("为什么这样排"), id)
            XCTAssertFalse(copy.contains(" = "), id)
            XCTAssertFalse(copy.contains(" ≈ "), id)
            XCTAssertFalse(copy.contains("锁死"), id)
            XCTAssertFalse(copy.contains("钉死"), id)
            XCTAssertFalse(copy.contains("训练档位"), id)
            XCTAssertFalse(copy.contains("这一档"), id)
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
