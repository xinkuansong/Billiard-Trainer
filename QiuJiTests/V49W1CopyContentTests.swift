import XCTest
@testable import QiuJi

/// v49 W1 样张契约：只锁定本批三课，不继承全库历史数量与空 pocket 债务。
@MainActor
final class V49W1CopyContentTests: XCTestCase {

    func test_sampleDrills_loadFromBundleWithExpectedNames() async throws {
        let c001 = try await drill("drill_c001")
        let c011 = try await drill("drill_c011")
        let c012 = try await drill("drill_c012")

        XCTAssertEqual(c001.nameZh, "半台直线球")
        XCTAssertEqual(c011.nameZh, "近台小角度进球")
        XCTAssertEqual(c012.nameZh, "中袋直线出杆")
    }

    func test_c001_copyKeepsPositionChangeAndStrokeAsOneTask() async throws {
        let drill = try await drill("drill_c001")
        let copy = flattenedCopy(for: drill)

        XCTAssertTrue(copy.contains("每次换位都重新站线"))
        XCTAssertTrue(copy.contains("前三杆用中杆"))
        XCTAssertTrue(copy.contains("后两杆"))
        XCTAssertFalse(copy.contains("前三档"))
        XCTAssertFalse(copy.contains("锁线"))
        XCTAssertFalse(copy.contains("这样排列，是为了"))
    }

    func test_c011_copyDescribesSmallAnglesInsteadOfStraightShot() async throws {
        let drill = try await drill("drill_c011")
        let copy = flattenedCopy(for: drill)

        XCTAssertTrue(copy.contains("从稍有角度打到接近直线"))
        XCTAssertTrue(copy.contains("重新找瞄准点"))
        XCTAssertFalse(copy.contains("不练切角"))
        XCTAssertFalse(copy.contains("近台底袋直线球"))
        XCTAssertFalse(copy.contains("结果主要反映"))
    }

    func test_c012_copyMakesCueBallPocketingAnExplicitSuccess() async throws {
        let drill = try await drill("drill_c012")
        let copy = flattenedCopy(for: drill)

        XCTAssertTrue(copy.contains("彩球只用来记位置"))
        XCTAssertTrue(copy.contains("母球直接进左侧中袋"))
        XCTAssertTrue(copy.contains("每换一个位置，都从袋口重新拉线"))
        XCTAssertFalse(copy.contains("只拉距离"))
        XCTAssertFalse(copy.contains("不换切角"))
        XCTAssertFalse(copy.contains("结果主要由"))
    }

    private func drill(_ id: String) async throws -> DrillContent {
        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: id)
        return try XCTUnwrap(
            loaded,
            "\(id) 应从正式 Bundle 成功解码"
        )
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
