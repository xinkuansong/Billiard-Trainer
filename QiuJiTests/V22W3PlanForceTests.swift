import XCTest
@testable import QiuJi

/// v22 W3 立档：力度计划解码 + 结构自检。
/// v34 W3 重排后更新（问题集合_v34.md R6/D-v34-2）：不再钉死逐周主题/主轴与固定课时，
/// 改保护结构不变量 + forceControl 全量归属 + dose 契约 + index 一致性。
final class V22W3PlanForceTests: XCTestCase {

    private let forceControlIds: Set<String> = [
        "drill_c044", "drill_c045", "drill_c046", "drill_c047",
        "drill_c048", "drill_c049", "drill_c050", "drill_c051",
    ]

    func testPlanForceDecodesAndMatchesShelfSpec() async throws {
        let plan = await PlanContentService.shared.loadPlanFromBundle(id: "plan_force")
        XCTAssertNotNil(plan, "plan_force 应可解码为 OfficialPlan")
        guard let plan else { return }

        XCTAssertEqual(plan.id, "plan_force")
        XCTAssertEqual(plan.nameZh, "力度")
        XCTAssertEqual(plan.isPremium, true)
        XCTAssertEqual(plan.sessionsPerWeek, 3, "v34 R6：每周 3 次课")
        XCTAssertTrue((2...5).contains(plan.durationWeeks), "v34 R6：周数 2–5，实际 \(plan.durationWeeks)")
        XCTAssertTrue(plan.description.contains("力度") || plan.description.contains("控力"),
                      "description 应标明力度/控力专项")

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
        try assertPlanJSONHasNoLegacyVolumeKeys("plan_force")

        // 计划内容应恰为 forceControl 全量 8 条（v34 归属），且每条目 dose 恰好二选一。
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
        XCTAssertEqual(allIds, forceControlIds, "计划内容应恰为 forceControl 全量")

        var firstFocused: [String] = []
        for week in plan.weeks {
            for session in week.sessions {
                for phase in session.phases where phase.type == "focused" {
                    for drill in phase.drills where !firstFocused.contains(drill.drillId) {
                        firstFocused.append(drill.drillId)
                    }
                }
            }
        }
        // 失败机理（PD-027 / v38 W0）：旧序把 c046 插进强弱杆周，且五档标尺晚于轻推。
        XCTAssertEqual(
            firstFocused,
            ["drill_c045", "drill_c049", "drill_c044", "drill_c047",
             "drill_c048", "drill_c050", "drill_c046", "drill_c051"],
            "力度 focused 首次引入须等于 W0 表：\(firstFocused)"
        )

        // 全部 drillId ∈ Drills index
        let drillIndex = await DrillContentService.shared.loadDrillIndex()
        XCTAssertNotNil(drillIndex)
        let knownIds = Set(drillIndex?.allDrillIds ?? [])
        XCTAssertTrue(allIds.subtracting(knownIds).isEmpty,
                      "引用了不存在的 drillId: \(allIds.subtracting(knownIds))")
    }

    func testPlansIndexContainsForce() async {
        let index = await PlanContentService.shared.loadPlanIndex()
        XCTAssertNotNil(index)
        let entry = index?.plans.first { $0.id == "plan_force" }
        XCTAssertNotNil(entry, "index 须登记 plan_force")
        XCTAssertEqual(entry?.isPremium, true)

        // index 登记须与计划文件一致（防止只改一边）。
        let plan = await PlanContentService.shared.loadPlanFromBundle(id: "plan_force")
        XCTAssertEqual(entry?.nameZh, plan?.nameZh, "index 与计划文件 nameZh 须一致")
        XCTAssertEqual(entry?.targetLevel, plan?.targetLevel, "index 与计划文件 targetLevel 须一致")
        XCTAssertGreaterThanOrEqual(index?.version ?? 0, 4, "W3 起 version ≥4")

        // 勿改坏免费档（D-v34-2：beginner/accuracy/cueball 免费）
        let accuracy = index?.plans.first { $0.id == "plan_accuracy" }
        XCTAssertNotNil(accuracy)
        XCTAssertEqual(accuracy?.isPremium, false)
    }
}
