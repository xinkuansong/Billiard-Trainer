import XCTest
@testable import QiuJi

/// v21 W5 立档：计划 JSON 接入加塞 drill（解码合法 + 引用可 grep）。
/// v34 W3 重排后更新：加塞主轴 c073–c075 归 `plan_english`（杆法Ⅱ·加塞挤偏），
/// 带塞准度 c076–c078 归 `plan_intermediate`（准度Ⅱ·远台带塞），见 问题集合_v34.md D-v34-2。
final class V21W5PlanContentTests: XCTestCase {

    func testPlanEnglishContainsEnglishDrills() async {
        let plan = await PlanContentService.shared.loadPlanFromBundle(id: "plan_english")
        XCTAssertNotNil(plan, "plan_english 应可解码")
        guard let plan else { return }

        let allIds = Set(
            plan.weeks.flatMap { week in
                week.sessions.flatMap { session in
                    session.phases.flatMap { $0.drills.map(\.drillId) }
                }
            }
        )
        for id in ["drill_c073", "drill_c074", "drill_c075"] {
            XCTAssertTrue(allIds.contains(id), "加塞主轴 \(id) 须在 plan_english：\(allIds)")
        }
        XCTAssertTrue(
            allIds.contains("drill_c018") || allIds.contains("drill_c020") || allIds.contains("drill_c021"),
            "plan_english 应含加塞杆法课（c018/c020/c021）：\(allIds)"
        )
    }

    func testPlanIntermediateContainsSpinAccuracyDrills() async {
        let plan = await PlanContentService.shared.loadPlanFromBundle(id: "plan_intermediate")
        XCTAssertNotNil(plan, "plan_intermediate 应可解码")
        guard let plan else { return }

        let allIds = Set(
            plan.weeks.flatMap { week in
                week.sessions.flatMap { session in
                    session.phases.flatMap { $0.drills.map(\.drillId) }
                }
            }
        )
        for id in ["drill_c076", "drill_c077", "drill_c078"] {
            XCTAssertTrue(allIds.contains(id), "带塞准度 \(id) 须在 plan_intermediate：\(allIds)")
        }
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
