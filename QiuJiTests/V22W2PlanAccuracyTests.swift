import XCTest
@testable import QiuJi

/// v22 W2 立档：准度计划解码 + 结构自检。
/// v34 W3 重排后更新为「准度Ⅰ·近中台」货架规格（问题集合_v34.md R6/D-v34-2）：
/// 不再钉死逐周主题/主轴，改保护结构不变量 + v34 归属集合 + index 一致性。
final class V22W2PlanAccuracyTests: XCTestCase {

    /// v34 归属：近中台准度 7 条（c013/c053 因单课剂量超免费 75′ 档归准度Ⅱ）。
    private let assignedIds: Set<String> = [
        "drill_c001", "drill_c002", "drill_c011", "drill_c012",
        "drill_c032", "drill_c052", "drill_c063",
    ]

    func testPlanAccuracyDecodesAndMatchesShelfSpec() async throws {
        let plan = await PlanContentService.shared.loadPlanFromBundle(id: "plan_accuracy")
        XCTAssertNotNil(plan, "plan_accuracy 应可解码为 OfficialPlan")
        guard let plan else { return }

        XCTAssertEqual(plan.id, "plan_accuracy")
        XCTAssertEqual(plan.nameZh, "准度Ⅰ·近中台")
        XCTAssertEqual(plan.isPremium, false, "免费档三件套之一（D-v34-2）")
        XCTAssertEqual(plan.sessionsPerWeek, 3, "v34 R6：每周 3 次课")
        XCTAssertTrue((2...5).contains(plan.durationWeeks), "v34 R6：周数 2–5，实际 \(plan.durationWeeks)")
        XCTAssertEqual(plan.weeks.count, plan.durationWeeks)
        for week in plan.weeks {
            XCTAssertEqual(week.sessions.count, plan.sessionsPerWeek,
                           "week \(week.weekNumber) sessions.count 应等于 sessionsPerWeek")
            for session in week.sessions {
                for phase in session.phases {
                    XCTAssertGreaterThan(phase.durationMinutes, 0,
                                         "week \(week.weekNumber) day \(session.dayNumber) 相位时长须为正")
                }
            }
        }

        let allIds = Set(
            plan.weeks.flatMap { week in
                week.sessions.flatMap { session in
                    session.phases.flatMap { $0.drills.map(\.drillId) }
                }
            }
        )
        XCTAssertEqual(allIds, assignedIds, "计划内容应恰为 v34 归属集合")

        // 全部 drillId ∈ Drills index
        let drillIndex = await DrillContentService.shared.loadDrillIndex()
        XCTAssertNotNil(drillIndex)
        let knownIds = Set(drillIndex?.allDrillIds ?? [])
        XCTAssertTrue(allIds.subtracting(knownIds).isEmpty,
                      "引用了不存在的 drillId: \(allIds.subtracting(knownIds))")
    }

    func testPlansIndexContainsAccuracy() async {
        let index = await PlanContentService.shared.loadPlanIndex()
        XCTAssertNotNil(index)
        let entry = index?.plans.first { $0.id == "plan_accuracy" }
        XCTAssertNotNil(entry, "index 须登记 plan_accuracy")
        XCTAssertEqual(entry?.isPremium, false)

        // index 登记须与计划文件一致（防止只改一边）。
        let plan = await PlanContentService.shared.loadPlanFromBundle(id: "plan_accuracy")
        XCTAssertEqual(entry?.nameZh, plan?.nameZh, "index 与计划文件 nameZh 须一致")
        XCTAssertEqual(entry?.targetLevel, plan?.targetLevel, "index 与计划文件 targetLevel 须一致")
        // v22 W2 升至 3，后续批次继续递增，故断言 ≥3 而非钉死
        XCTAssertGreaterThanOrEqual(index?.version ?? 0, 3, "W2 起 version ≥3")
    }
}
