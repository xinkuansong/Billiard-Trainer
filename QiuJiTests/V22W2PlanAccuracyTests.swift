import XCTest
@testable import QiuJi

/// v22 W2：准度专项 plan_accuracy 解码 + 周次结构自检。
final class V22W2PlanAccuracyTests: XCTestCase {

    func testPlanAccuracyDecodesAndMatchesShelfSpec() async {
        let plan = await PlanContentService.shared.loadPlanFromBundle(id: "plan_accuracy")
        XCTAssertNotNil(plan, "plan_accuracy 应可解码为 OfficialPlan")
        guard let plan else { return }

        XCTAssertEqual(plan.id, "plan_accuracy")
        XCTAssertEqual(plan.nameZh, "准度专项")
        XCTAssertEqual(plan.nameEn, "Accuracy Specialist")
        XCTAssertEqual(plan.targetLevel, "L1→L2")
        XCTAssertEqual(plan.durationWeeks, 6)
        XCTAssertEqual(plan.sessionsPerWeek, 3)
        XCTAssertEqual(plan.minutesPerSession, 75)
        XCTAssertEqual(plan.isPremium, false)
        XCTAssertTrue(plan.description.contains("准度专项") || plan.description.contains("短板补强"))

        XCTAssertEqual(plan.weeks.count, plan.durationWeeks)
        for week in plan.weeks {
            XCTAssertEqual(week.sessions.count, plan.sessionsPerWeek,
                           "week \(week.weekNumber) sessions.count 应等于 sessionsPerWeek")
        }

        let themes: [Int: String] = [
            1: "近台直线打底",
            2: "底袋角度入门",
            3: "中台角度巩固",
            4: "中袋角度系列",
            5: "远台与三分点",
            6: "薄切与极限综合",
        ]
        for (n, theme) in themes {
            let week = plan.weeks.first { $0.weekNumber == n }
            XCTAssertEqual(week?.theme, theme, "week \(n) theme")
        }

        // focused 主轴：每周至少含 primary
        let requiredFocused: [Int: Set<String>] = [
            1: ["drill_c011"],
            2: ["drill_c013"],
            3: ["drill_c032"],
            4: ["drill_c053"],
            5: ["drill_c033"],
            6: ["drill_c063"],
        ]
        for (n, required) in requiredFocused {
            let week = plan.weeks.first { $0.weekNumber == n }
            let focusedIds = Set(
                (week?.sessions ?? []).flatMap { session in
                    session.phases
                        .filter { $0.type == "focused" }
                        .flatMap { $0.drills.map(\.drillId) }
                }
            )
            XCTAssertTrue(required.isSubset(of: focusedIds),
                          "week \(n) focused 须含 primary \(required)：\(focusedIds)")
        }

        // 禁止 c076–c078
        let allIds = Set(
            plan.weeks.flatMap { week in
                week.sessions.flatMap { session in
                    session.phases.flatMap { $0.drills.map(\.drillId) }
                }
            }
        )
        for banned in ["drill_c076", "drill_c077", "drill_c078"] {
            XCTAssertFalse(allIds.contains(banned), "准度专项不得含 \(banned)")
        }

        // W5 须用到 c052 或 c062
        let week5Focused = Set(
            (plan.weeks.first { $0.weekNumber == 5 }?.sessions ?? []).flatMap { session in
                session.phases
                    .filter { $0.type == "focused" }
                    .flatMap { $0.drills.map(\.drillId) }
            }
        )
        XCTAssertTrue(
            week5Focused.contains("drill_c052") || week5Focused.contains("drill_c062"),
            "W5 focused 须含 c052/c062：\(week5Focused)"
        )
    }

    func testPlansIndexContainsAccuracy() async {
        let index = await PlanContentService.shared.loadPlanIndex()
        XCTAssertNotNil(index)
        let entry = index?.plans.first { $0.id == "plan_accuracy" }
        XCTAssertNotNil(entry, "index 须登记 plan_accuracy")
        XCTAssertEqual(entry?.nameZh, "准度专项")
        XCTAssertEqual(entry?.targetLevel, "L1→L2")
        XCTAssertEqual(entry?.isPremium, false)
        // W2 升至 3；后续批次继续递增，故断言 ≥3 而非钉死
        XCTAssertGreaterThanOrEqual(index?.version ?? 0, 3, "W2 起 version ≥3")
    }
}
