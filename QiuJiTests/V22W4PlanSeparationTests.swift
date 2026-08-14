import XCTest
@testable import QiuJi

/// v22 W4 立档：分离角计划解码 + 结构自检。
/// v34 W3 重排后更新（问题集合_v34.md R6/D-v34-2）：不再钉死逐周主题/主轴与固定课时，
/// 改保护结构不变量 + separation 全量归属 + dose 契约 + index 一致性。
final class V22W4PlanSeparationTests: XCTestCase {

    /// separation 分类全量（v33 起 8 → 10 条，新增 c083 吃库分离角 / c084 不吃库分离角）。
    private let separationIds: Set<String> = [
        "drill_c024", "drill_c025", "drill_c026", "drill_c027",
        "drill_c028", "drill_c029", "drill_c030", "drill_c031",
        "drill_c083", "drill_c084",
    ]

    func testPlanSeparationDecodesAndMatchesShelfSpec() async throws {
        let plan = await PlanContentService.shared.loadPlanFromBundle(id: "plan_separation")
        XCTAssertNotNil(plan, "plan_separation 应可解码为 OfficialPlan")
        guard let plan else { return }

        XCTAssertEqual(plan.id, "plan_separation")
        XCTAssertEqual(plan.nameZh, "分离角")
        XCTAssertEqual(plan.isPremium, true)
        XCTAssertEqual(plan.sessionsPerWeek, 3, "v34 R6：每周 3 次课")
        XCTAssertTrue((2...5).contains(plan.durationWeeks), "v34 R6：周数 2–5，实际 \(plan.durationWeeks)")
        XCTAssertTrue(plan.description.contains("分离角"), "description 应标明分离角专项")

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

        // v31 W5：旧裸组数字段不得回流（在原始 JSON 层扫描键名）。
        try assertPlanJSONHasNoLegacyVolumeKeys("plan_separation")

        // 计划内容应恰为 separation 全量 10 条（v34 归属），且每条目 dose 恰好二选一。
        var allIds = Set<String>()
        for week in plan.weeks {
            for session in week.sessions {
                for phase in session.phases {
                    for drill in phase.drills {
                        allIds.insert(drill.drillId)
                        let dose = try XCTUnwrap(drill.dose, "\(drill.drillId) 缺 dose")
                        let hasUniform = dose.roundsPerFormation != nil
                        let hasListed = !(dose.formations ?? []).isEmpty
                        XCTAssertTrue(hasUniform != hasListed,
                                      "\(drill.drillId) dose 须恰好二选一（契约 §6.6）")
                    }
                }
            }
        }
        XCTAssertEqual(allIds, separationIds, "计划内容应恰为 separation 全量")

        // 全部 drillId ∈ Drills index
        let drillIndex = await DrillContentService.shared.loadDrillIndex()
        XCTAssertNotNil(drillIndex)
        let knownIds = Set(drillIndex?.allDrillIds ?? [])
        XCTAssertTrue(allIds.subtracting(knownIds).isEmpty,
                      "引用了不存在的 drillId: \(allIds.subtracting(knownIds))")
    }

    func testPlansIndexContainsSeparation() async {
        let index = await PlanContentService.shared.loadPlanIndex()
        XCTAssertNotNil(index)
        let entry = index?.plans.first { $0.id == "plan_separation" }
        XCTAssertNotNil(entry, "index 须登记 plan_separation")
        XCTAssertEqual(entry?.isPremium, true)

        // index 登记须与计划文件一致（防止只改一边）。
        let plan = await PlanContentService.shared.loadPlanFromBundle(id: "plan_separation")
        XCTAssertEqual(entry?.nameZh, plan?.nameZh, "index 与计划文件 nameZh 须一致")
        XCTAssertEqual(entry?.targetLevel, plan?.targetLevel, "index 与计划文件 targetLevel 须一致")
        XCTAssertGreaterThanOrEqual(index?.version ?? 0, 5, "W4 起 version ≥5")

        // 勿改坏免费/付费分布（D-v34-2）
        let accuracy = index?.plans.first { $0.id == "plan_accuracy" }
        XCTAssertNotNil(accuracy)
        XCTAssertEqual(accuracy?.isPremium, false)
        let force = index?.plans.first { $0.id == "plan_force" }
        XCTAssertNotNil(force)
        XCTAssertEqual(force?.isPremium, true)
    }
}
