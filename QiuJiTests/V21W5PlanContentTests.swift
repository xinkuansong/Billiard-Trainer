import XCTest
@testable import QiuJi

/// v21 W5：计划 JSON 接入加塞 drill（解码合法 + 引用可 grep）。
final class V21W5PlanContentTests: XCTestCase {

    func testPlanCueballContainsEnglishDrillsInFocusedWeek() async {
        let plan = await PlanContentService.shared.loadPlanFromBundle(id: "plan_cueball")
        XCTAssertNotNil(plan, "plan_cueball 应可解码")
        guard let plan else { return }

        XCTAssertEqual(plan.weeks.count, 6)
        let week6 = plan.weeks.first { $0.weekNumber == 6 }
        XCTAssertNotNil(week6)
        XCTAssertTrue(week6?.theme.contains("加塞") == true, "第 6 周主题应含加塞：\(week6?.theme ?? "")")

        let focusedIds = Set(
            (week6?.sessions ?? []).flatMap { session in
                session.phases
                    .filter { $0.type == "focused" }
                    .flatMap { $0.drills.map(\.drillId) }
            }
        )
        XCTAssertTrue(focusedIds.contains("drill_c073"), "week6 focused 须含免费钩子 c073：\(focusedIds)")
        XCTAssertTrue(
            focusedIds.contains("drill_c074") || focusedIds.contains("drill_c075")
                || focusedIds.contains("drill_c016") || focusedIds.contains("drill_c018"),
            "week6 focused 应再含加塞/斯登线：\(focusedIds)"
        )
    }

    func testPlanIntermediateWeek1ContainsEnglishDrills() async {
        let plan = await PlanContentService.shared.loadPlanFromBundle(id: "plan_intermediate")
        XCTAssertNotNil(plan, "plan_intermediate 应可解码")
        guard let plan else { return }

        let week1 = plan.weeks.first { $0.weekNumber == 1 }
        XCTAssertNotNil(week1)
        XCTAssertTrue(week1?.theme.contains("加塞") == true, "第 1 周主题应含加塞（免费预览可见）：\(week1?.theme ?? "")")

        let allIds = Set(
            (week1?.sessions ?? []).flatMap { session in
                session.phases.flatMap { $0.drills.map(\.drillId) }
            }
        )
        XCTAssertTrue(allIds.contains("drill_c073"), "week1 须含 c073：\(allIds)")
        XCTAssertTrue(
            allIds.contains("drill_c076") || allIds.contains("drill_c075") || allIds.contains("drill_c018"),
            "week1 应再含准度/塞量课：\(allIds)"
        )
    }

    func testAllOfficialPlansStillDecode() async {
        let plans = await PlanContentService.shared.loadAllPlans()
        XCTAssertGreaterThanOrEqual(plans.count, 6, "官方计划应 ≥6 套")
        for plan in plans {
            XCTAssertFalse(plan.weeks.isEmpty, "\(plan.id) weeks 非空")
            XCTAssertEqual(plan.weeks.count, plan.durationWeeks,
                           "\(plan.id) weeks.count 应等于 durationWeeks")
        }
    }
}
