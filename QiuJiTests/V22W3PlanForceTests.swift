import XCTest
@testable import QiuJi

/// v22 W3：力度控制专项 plan_force 解码 + 周次结构自检。
final class V22W3PlanForceTests: XCTestCase {

    private let forceControlIds: Set<String> = [
        "drill_c044", "drill_c045", "drill_c046", "drill_c047",
        "drill_c048", "drill_c049", "drill_c050", "drill_c051",
    ]

    func testPlanForceDecodesAndMatchesShelfSpec() async {
        let plan = await PlanContentService.shared.loadPlanFromBundle(id: "plan_force")
        XCTAssertNotNil(plan, "plan_force 应可解码为 OfficialPlan")
        guard let plan else { return }

        XCTAssertEqual(plan.id, "plan_force")
        XCTAssertEqual(plan.nameZh, "力度控制专项")
        XCTAssertEqual(plan.nameEn, "Force Control Specialist")
        XCTAssertEqual(plan.targetLevel, "L1→L2")
        XCTAssertEqual(plan.durationWeeks, 4)
        XCTAssertEqual(plan.sessionsPerWeek, 3)
        XCTAssertEqual(plan.minutesPerSession, 70)
        XCTAssertEqual(plan.isPremium, true)
        XCTAssertTrue(
            plan.description.contains("力度") || plan.description.contains("控力"),
            "description 应标明力度/控力专项"
        )

        XCTAssertEqual(plan.weeks.count, plan.durationWeeks)
        for week in plan.weeks {
            XCTAssertEqual(
                week.sessions.count, plan.sessionsPerWeek,
                "week \(week.weekNumber) sessions.count 应等于 sessionsPerWeek"
            )
            for session in week.sessions {
                let minutes = session.phases.reduce(0) { $0 + $1.durationMinutes }
                XCTAssertEqual(minutes, 70, "week \(week.weekNumber) day \(session.dayNumber) 时长应约 70′")
                let types = session.phases.map(\.type)
                XCTAssertEqual(types, ["warmup", "focused", "combined", "review"])
            }
        }

        let themes: [Int: String] = [
            1: "轻推与三档",
            2: "控力落点",
            3: "强力杆法",
            4: "阶梯与全力度",
        ]
        for (n, theme) in themes {
            let week = plan.weeks.first { $0.weekNumber == n }
            XCTAssertEqual(week?.theme, theme, "week \(n) theme")
        }

        // focused 主轴：每周至少含 primary + secondary（§2.2）
        let requiredFocused: [Int: Set<String>] = [
            1: ["drill_c044", "drill_c045"],
            2: ["drill_c046", "drill_c050"],
            3: ["drill_c047", "drill_c048"],
            4: ["drill_c049", "drill_c051"],
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
            XCTAssertTrue(
                required.isSubset(of: focusedIds),
                "week \(n) focused 须含 \(required)：\(focusedIds)"
            )
        }

        // focused 组数 ≥70% 落在 forceControl（本计划目标 100%）
        var forceSets = 0
        var totalFocusedSets = 0
        for week in plan.weeks {
            for session in week.sessions {
                for phase in session.phases where phase.type == "focused" {
                    for drill in phase.drills {
                        totalFocusedSets += drill.sets
                        if forceControlIds.contains(drill.drillId) {
                            forceSets += drill.sets
                        }
                    }
                }
            }
        }
        XCTAssertGreaterThan(totalFocusedSets, 0)
        let ratio = Double(forceSets) / Double(totalFocusedSets)
        XCTAssertGreaterThanOrEqual(ratio, 0.70, "focused forceControl 组数比 \(forceSets)/\(totalFocusedSets)=\(ratio)")
        XCTAssertEqual(forceSets, totalFocusedSets, "本专项 focused 应 100% forceControl")

        // 全部 drillId ∈ Drills index
        let drillIndex = await DrillContentService.shared.loadDrillIndex()
        XCTAssertNotNil(drillIndex)
        let knownIds = Set(drillIndex?.allDrillIds ?? [])
        let allPlanIds = Set(
            plan.weeks.flatMap { week in
                week.sessions.flatMap { session in
                    session.phases.flatMap { $0.drills.map(\.drillId) }
                }
            }
        )
        let missing = allPlanIds.subtracting(knownIds)
        XCTAssertTrue(missing.isEmpty, "引用了不存在的 drillId: \(missing)")
    }

    func testPlansIndexContainsForce() async {
        let index = await PlanContentService.shared.loadPlanIndex()
        XCTAssertNotNil(index)
        let entry = index?.plans.first { $0.id == "plan_force" }
        XCTAssertNotNil(entry, "index 须登记 plan_force")
        XCTAssertEqual(entry?.nameZh, "力度控制专项")
        XCTAssertEqual(entry?.targetLevel, "L1→L2")
        XCTAssertEqual(entry?.isPremium, true)
        // W3 升至 4；后续批次继续递增，故断言 ≥4 而非钉死
        XCTAssertGreaterThanOrEqual(index?.version ?? 0, 4, "W3 起 version ≥4")

        // 勿改坏 plan_accuracy
        let accuracy = index?.plans.first { $0.id == "plan_accuracy" }
        XCTAssertNotNil(accuracy)
        XCTAssertEqual(accuracy?.isPremium, false)
    }
}
