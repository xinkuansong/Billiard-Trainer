import XCTest
@testable import QiuJi

/// v49 W2：直线出杆、定杆与五分点四课的文案契约。
@MainActor
final class V49W2CopyContentTests: XCTestCase {

    func test_w2Drills_loadFromBundle() async throws {
        for id in ["drill_c009", "drill_c010", "drill_c022", "drill_c023"] {
            _ = try await drill(id)
        }
    }

    func test_c022_usesReturnLineAsTheStraightStrokeCheck() async throws {
        let drill = try await drill("drill_c022")
        let copy = flattenedCopy(for: drill)

        XCTAssertEqual(drill.nameZh, "直线推白球")
        XCTAssertEqual(drill.tutorial?.formations?.count, 2)
        XCTAssertTrue(copy.contains("球从哪条线出去，就该从哪条线回来"))
        XCTAssertTrue(copy.contains("图里标的是出球线"))
        XCTAssertTrue(copy.contains("球形 A 练 5 轮、球形 B 练 2 轮"))
        XCTAssertFalse(copy.contains("打点锁中心"))
        XCTAssertFalse(copy.contains("结果主要反映"))
    }

    func test_c023_keepsTheIntentWhileCallingOutRecordedMisses() async throws {
        let drill = try await drill("drill_c023")
        let copy = flattenedCopy(for: drill)
        let shotSections = drill.tutorial?.sections?.filter { $0.params != nil } ?? []

        XCTAssertEqual(drill.nameZh, "五分点")
        XCTAssertEqual(shotSections.count, 8)
        XCTAssertTrue(copy.contains("先看进球，再看停位"))
        XCTAssertTrue(copy.contains("第 3、4 杆录制时母球走过头进袋"))
        XCTAssertTrue(copy.contains("8 号进、母球留台才算对"))
        XCTAssertTrue(copy.contains("八种打法各练 15 球"))
        XCTAssertFalse(copy.contains("线散了，后面都作废"))
        XCTAssertFalse(copy.contains("这样排列，是为了"))
    }

    private func drill(_ id: String) async throws -> DrillContent {
        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: id)
        return try XCTUnwrap(loaded, "\(id) 应从正式 Bundle 成功解码")
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
