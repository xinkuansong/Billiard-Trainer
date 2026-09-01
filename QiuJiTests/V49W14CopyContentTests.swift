import XCTest
@testable import QiuJi

/// v49 W14：力度标尺、碰库往返与高低杆距离边界。
@MainActor
final class V49W14CopyContentTests: XCTestCase {

    func test_w14Drills_loadAndKeepCurrentShotCounts() async throws {
        let expected = [
            "drill_c044": 6, "drill_c045": 3, "drill_c046": 5, "drill_c047": 12,
            "drill_c048": 12, "drill_c049": 5, "drill_c050": 5, "drill_c051": 4
        ]
        for (id, count) in expected {
            let content = try await drill(id)
            XCTAssertEqual(shotSectionCount(content), count, id)
        }
    }

    func test_c044_usesSixPositionsInsteadOfSixForceLevels() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c044"))
        XCTAssertTrue(copy.contains("六个直线球摆位"))
        XCTAssertTrue(copy.contains("刚好够进袋的力量"))
        XCTAssertTrue(copy.contains("六个摆位各进袋至少一次"))
        XCTAssertFalse(copy.contains("六档轻推"))
    }

    func test_c045AndC049_compareRoundTripTravelNotMonotonicFinalDistance() async throws {
        let c045 = flattenedCopy(for: try await drill("drill_c045"))
        let c049 = flattenedCopy(for: try await drill("drill_c049"))
        XCTAssertTrue(c045.contains("完整往返行程和最终停区"))
        XCTAssertTrue(c049.contains("最终停点可能再次靠近起点"))
        XCTAssertTrue(c049.contains("不能简单按离起点远近排序"))
        XCTAssertFalse(c049.contains("单调"))
    }

    func test_c046_statesWhatResetsAndWhatContinues() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c046"))
        XCTAssertTrue(copy.contains("1 号球按图在左右两侧重摆"))
        XCTAssertTrue(copy.contains("母球保留上一杆停位"))
        XCTAssertTrue(copy.contains("最后一杆才用中低杆收尾"))
    }

    func test_c047_disclosesRecordedScratchesWithoutChangingTheStandard() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c047"))
        XCTAssertTrue(copy.contains("第 1–3、8–9 杆母球落袋"))
        XCTAssertTrue(copy.contains("1 号进右下角袋、母球留台"))
    }

    func test_c050_explainsWhySoftShotsCanStillTravelFar() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c050"))
        XCTAssertTrue(copy.contains("后两杆改打中袋、切角更明显"))
        XCTAssertTrue(copy.contains("仍可能走出较长距离"))
        XCTAssertTrue(copy.contains("前三杆母球停在近距区域"))
    }

    func test_c051_separatesForceComparisonFromSpinApplication() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c051"))
        XCTAssertTrue(copy.contains("这组不是单纯比较力量"))
        XCTAssertTrue(copy.contains("前两杆保持中杆无塞"))
        XCTAssertTrue(copy.contains("参考球标出本杆要到的区域，不参与击打"))
    }

    func test_w14Copy_removesConfigurationAndEquationTone() async throws {
        for id in ["drill_c044", "drill_c045", "drill_c046", "drill_c047", "drill_c048", "drill_c049", "drill_c050", "drill_c051"] {
            let copy = flattenedCopy(for: try await drill(id))
            for phrase in [" = ", " ≈ ", "锁死", "钉死", "训练档位", "这一档", "本档", "按示范", "各扫", "爬到"] {
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
