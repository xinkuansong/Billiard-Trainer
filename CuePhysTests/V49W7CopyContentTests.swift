import XCTest
@testable import QiuJi

/// v49 W7：基础高低杆、距离阶梯与斯登控制的边界。
@MainActor
final class V49W7CopyContentTests: XCTestCase {

    func test_w7Drills_loadAndKeepShotCounts() async throws {
        let expected = ["drill_c003": [4, 5], "drill_c004": [4, 4], "drill_c014": [7],
                        "drill_c015": [8], "drill_c016": [6], "drill_c017": [5]]
        for (id, counts) in expected {
            let drill = try await drill(id)
            let groups = drill.tutorial?.formations?.map(\.sections) ?? [drill.tutorial?.sections ?? []]
            XCTAssertEqual(groups.map(shotSectionCount), counts, id)
        }
    }

    func test_followDrills_discloseRecordedScratchesWithoutChangingStandard() async throws {
        let c003 = try await drill("drill_c003")
        let c015 = try await drill("drill_c015")
        XCTAssertTrue(flattenedCopy(for: c003).contains("当前四杆录制中母球都跟进落袋"))
        XCTAssertTrue(flattenedCopy(for: c003).contains("第 2 至第 5 杆母球都跟进落袋"))
        XCTAssertTrue(flattenedCopy(for: c015).contains("当前八杆录制中母球都跟进落袋"))
        XCTAssertTrue(c003.standardCriteria.contains("母球跟进后留台"))
        XCTAssertTrue(c015.standardCriteria.contains("母球留台"))
    }

    func test_drawStopAndStun_haveDistinctObservableResults() async throws {
        let c004 = flattenedCopy(for: try await drill("drill_c004"))
        let c014 = flattenedCopy(for: try await drill("drill_c014"))
        let c016 = flattenedCopy(for: try await drill("drill_c016"))
        let c017 = flattenedCopy(for: try await drill("drill_c017"))

        XCTAssertTrue(c004.contains("母球回退并留台"))
        XCTAssertTrue(c014.contains("碰到 8 号的那一刻接近无前后旋"))
        XCTAssertTrue(c016.contains("前斯登与后斯登"))
        XCTAssertTrue(c017.contains("底旋保留到碰撞"))
        XCTAssertFalse(c014.contains("定杆怎么守见"))
        XCTAssertFalse(c017.contains("没有穿透就几乎不回退"))
    }

    func test_w7Copy_removesConfigurationAndEquationTone() async throws {
        for id in ["drill_c003", "drill_c004", "drill_c014", "drill_c015", "drill_c016", "drill_c017"] {
            let copy = flattenedCopy(for: try await drill(id))
            XCTAssertFalse(copy.contains("为什么这样排"), id)
            XCTAssertFalse(copy.contains(" = "), id)
            XCTAssertFalse(copy.contains("钉死"), id)
            XCTAssertFalse(copy.contains("锁死"), id)
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
