import XCTest
@testable import QiuJi

/// v49 W3：小角度、长距离瞄准与中大角度球的文案契约。
@MainActor
final class V49W3CopyContentTests: XCTestCase {

    func test_w3Drills_loadFromBundle() async throws {
        for id in ["drill_c013", "drill_c032", "drill_c033", "drill_c063", "drill_c072"] {
            _ = try await drill(id)
        }
    }

    func test_c013_keepsNearAndFarFormationsDistinct() async throws {
        let drill = try await drill("drill_c013")
        let copy = flattenedCopy(for: drill)

        XCTAssertEqual(drill.nameZh, "底袋小角度")
        XCTAssertEqual(drill.tutorial?.formations?.count, 2)
        XCTAssertTrue(copy.contains("先在近距离认准接触位置，再把同样的判断带到更远的球形"))
        XCTAssertTrue(copy.contains("第 4 杆接近直线，打点略低于中心"))
        XCTAssertTrue(copy.contains("任一档连续打进 3 次，该档过关"))
        XCTAssertFalse(copy.contains("把厚薄立住"))
        XCTAssertFalse(copy.contains("瞄偏被距离吃掉"))
    }

    func test_distanceDrills_explainDifferentSourcesOfDifficulty() async throws {
        let c032 = flattenedCopy(for: try await drill("drill_c032"))
        let c033 = flattenedCopy(for: try await drill("drill_c033"))
        let c072 = flattenedCopy(for: try await drill("drill_c072"))

        XCTAssertTrue(c032.contains("进球线更长，同样的瞄准偏差会在袋口形成更大的偏移"))
        XCTAssertTrue(c033.contains("难点不在角度大，而在母球离 8 号球约 1.8 米"))
        XCTAssertTrue(c072.contains("两档分别从左右方向完成近直线进球"))
        XCTAssertTrue(c072.contains("不要求第一杆给第二杆留位"))
    }

    func test_c063_keepsTrainingIntentSeparateFromRecordedTransition() async throws {
        let drill = try await drill("drill_c063")
        let copy = flattenedCopy(for: drill)

        XCTAssertEqual(drill.nameZh, "底袋中大角度")
        XCTAssertTrue(copy.contains("练习时把两档当作独立球形"))
        XCTAssertTrue(copy.contains("当前录制连续展示了两杆，但不把这段衔接当作走位要求"))
        XCTAssertTrue(copy.contains("方向正确但到不了袋，再补力度；方向已偏，先修正厚薄"))
        XCTAssertFalse(copy.contains("不是连打走位"))
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
