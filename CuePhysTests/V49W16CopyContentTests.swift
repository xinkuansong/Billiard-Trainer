import XCTest
@testable import QiuJi

/// v49 W16：防守、K 球综合、连续清台与规则流程课。
@MainActor
final class V49W16CopyContentTests: XCTestCase {

    func test_w16Drills_loadAndKeepCurrentShotCounts() async throws {
        let expected = ["drill_c060": 8, "drill_c085": 14, "drill_c064": 3]
        for (id, count) in expected {
            let content = try await drill(id)
            XCTAssertEqual(shotSectionCount(content), count, id)
        }
        for id in ["drill_c065", "drill_c068", "drill_c070"] {
            let content = try await drill(id)
            XCTAssertEqual(content.tutorial?.tutorialKind, .ruleset, id)
            XCTAssertGreaterThanOrEqual(content.tutorial?.sections?.count ?? 0, 6, id)
        }
    }

    func test_c060_judgesBothCueBallAndObjectBallOutcome() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c060"))
        XCTAssertTrue(copy.contains("母球和目标球的去向要一起规划"))
        XCTAssertTrue(copy.contains("目标球不会停到袋口附近"))
        XCTAssertTrue(copy.contains("第 5 杆指定 1 号进左侧中袋"))
    }

    func test_c085_namesEveryRecordedKBallTargetInOrder() async throws {
        let content = try await drill("drill_c085")
        let shotTitles = (content.tutorial?.sections ?? [])
            .filter { $0.title.contains("杆：") }
            .map(\.title)
        let targets = [1, 2, 3, 4, 5, 6, 7, 8, 9, 14, 13, 12, 11, 10]
        XCTAssertEqual(shotTitles.count, targets.count)
        for (title, target) in zip(shotTitles, targets) {
            XCTAssertTrue(title.contains("K \(target)号"), title)
        }
    }

    func test_c085_requiresBothPotAndKBallResult() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c085"))
        XCTAssertTrue(copy.contains("15 号每杆都进左侧中袋"))
        XCTAssertTrue(copy.contains("进球和 K 球目标必须同时完成"))
        XCTAssertTrue(copy.contains("母球按当杆路线 K 到指定号码球"))
    }

    func test_c064_explainsThreeBallReversePlanning() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c064"))
        XCTAssertTrue(copy.contains("先从 3 号倒推"))
        XCTAssertTrue(copy.contains("母球要停在 2 号左侧"))
        XCTAssertTrue(copy.contains("3 号右侧的近直线位置"))
    }

    func test_c065_andC068_useDifferentProgressMeasures() async throws {
        let ghost = flattenedCopy(for: try await drill("drill_c065"))
        let fiveBall = flattenedCopy(for: try await drill("drill_c068"))
        XCTAssertTrue(ghost.contains("胜负和清台球数"))
        XCTAssertTrue(ghost.contains("任一失误或犯规都结束本局"))
        XCTAssertTrue(fiveBall.contains("每进一颗就把规划向后更新一杆"))
        XCTAssertTrue(fiveBall.contains("断在第几颗"))
    }

    func test_c070_disclosesCustomOrderInsteadOfCallingItStandardMatchPlay() async throws {
        let copy = flattenedCopy(for: try await drill("drill_c070"))
        XCTAssertTrue(copy.contains("本课的自定义清台顺序"))
        XCTAssertTrue(copy.contains("不是标准对局计分"))
        XCTAssertTrue(copy.contains("先清一组花色，再打黑八，最后清另一组"))
    }

    func test_w16Copy_removesConfigurationAndEquationTone() async throws {
        for id in ["drill_c060", "drill_c085", "drill_c064", "drill_c065", "drill_c068", "drill_c070"] {
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
