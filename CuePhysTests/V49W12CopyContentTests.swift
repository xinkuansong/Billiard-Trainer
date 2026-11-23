import XCTest
@testable import QiuJi

/// v49 W12：连续链、独立路线对照与初级蛇彩的语义边界。
@MainActor
final class V49W12CopyContentTests: XCTestCase {

    func test_w12Drills_loadAndKeepCurrentShotCounts() async throws {
        let expected = ["drill_c039": 8, "drill_c040": 10, "drill_c041": 12, "drill_c042": 13]
        for (id, count) in expected {
            let drill = try await drill(id)
            XCTAssertEqual(shotSectionCount(drill), count, id)
        }
    }

    func test_c039_isAContinuousEightBallChainWithNextBallPlanning() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c039"))
        XCTAssertTrue(copy.contains("八颗球按顺序连续打完"))
        XCTAssertTrue(copy.contains("先看下一颗的进球线"))
        XCTAssertTrue(copy.contains("第七杆后，8 号应能顺畅打进左上角袋"))
        XCTAssertFalse(copy.contains("把母球停在原位附近"))
    }

    func test_c040_isIndependentThreeCushionRouteComparison() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c040"))
        XCTAssertTrue(copy.contains("连续走三库"))
        XCTAssertTrue(copy.contains("从目标区域反推三次碰库路线"))
        XCTAssertTrue(copy.contains("十杆之间没有连续叫位关系"))
    }

    func test_c041_teachesNaturalLineBeforeSpinAndDirectionBeforeSpeed() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c041"))
        XCTAssertTrue(copy.contains("先画出不加塞时的自然路线"))
        XCTAssertTrue(copy.contains("先看母球是否进入对角半台，再看停位深浅"))
        XCTAssertTrue(copy.contains("加力只会让错误路线走得更远"))
    }

    func test_c042_separatesEightIndependentOpenersFromFiveBallRun() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c042"))
        XCTAssertTrue(copy.contains("8 种独立首杆"))
        XCTAssertTrue(copy.contains("2、3 号在这里提供后续走位参照"))
        XCTAssertTrue(copy.contains("第二组把判断接成连续走位"))
        XCTAssertTrue(copy.contains("第 4 杆后能顺畅进攻 5 号左下角袋"))
    }

    func test_w12Copy_removesConfigurationAndEquationTone() async throws {
        for id in ["drill_c039", "drill_c040", "drill_c041", "drill_c042"] {
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
