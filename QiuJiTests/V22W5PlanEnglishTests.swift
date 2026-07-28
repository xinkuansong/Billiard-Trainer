import XCTest
@testable import QiuJi

/// v22 W5：加塞专项 plan_english 解码 + 周次结构自检。
final class V22W5PlanEnglishTests: XCTestCase {

    /// 加塞主轴：c073–c075 cueAction + c076–c078 accuracy 带塞准度
    private let englishIds: Set<String> = [
        "drill_c073", "drill_c074", "drill_c075",
        "drill_c076", "drill_c077", "drill_c078",
    ]

    func testPlanEnglishDecodesAndMatchesShelfSpec() async {
        let plan = await PlanContentService.shared.loadPlanFromBundle(id: "plan_english")
        XCTAssertNotNil(plan, "plan_english 应可解码为 OfficialPlan")
        guard let plan else { return }

        XCTAssertEqual(plan.id, "plan_english")
        XCTAssertEqual(plan.nameZh, "加塞专项")
        XCTAssertEqual(plan.nameEn, "English / Squirt Specialist")
        XCTAssertEqual(plan.targetLevel, "L2")
        XCTAssertEqual(plan.durationWeeks, 6)
        XCTAssertEqual(plan.sessionsPerWeek, 3)
        XCTAssertEqual(plan.minutesPerSession, 75)
        XCTAssertEqual(plan.isPremium, true)
        XCTAssertTrue(
            plan.description.contains("带塞进袋") || plan.description.contains("挤偏"),
            "description 应标明带塞进袋准度 / 挤偏让点专项"
        )
        XCTAssertFalse(
            plan.description.contains("碰库变线") && !plan.description.contains("非碰库变线"),
            "description 不得把碰库变线当主题（可写⛔非碰库变线）"
        )

        XCTAssertEqual(plan.weeks.count, plan.durationWeeks)
        for week in plan.weeks {
            XCTAssertEqual(
                week.sessions.count, plan.sessionsPerWeek,
                "week \(week.weekNumber) sessions.count 应等于 sessionsPerWeek"
            )
            for session in week.sessions {
                let minutes = session.phases.reduce(0) { $0 + $1.durationMinutes }
                XCTAssertEqual(minutes, 75, "week \(week.weekNumber) day \(session.dayNumber) 时长应约 75′")
                let types = session.phases.map(\.type)
                XCTAssertEqual(types, ["warmup", "focused", "combined", "review"])
            }
        }

        let themes: [Int: String] = [
            1: "挤偏认知·近台",
            2: "挤偏放大·长台",
            3: "塞量阶梯",
            4: "小角度带塞",
            5: "中大角度带塞",
            6: "远台带塞准度",
        ]
        for (n, theme) in themes {
            let week = plan.weeks.first { $0.weekNumber == n }
            XCTAssertEqual(week?.theme, theme, "week \(n) theme")
        }

        // focused 主轴：每周至少含 §2.2 primary
        let requiredFocused: [Int: Set<String>] = [
            1: ["drill_c073"],
            2: ["drill_c074"],
            3: ["drill_c075"],
            4: ["drill_c076"],
            5: ["drill_c077"],
            6: ["drill_c078"],
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
            XCTAssertFalse(
                focusedIds.contains("drill_c018"),
                "week \(n) focused 不得使用 drill_c018（碰库变线）"
            )
        }

        // focused 组数 ≥70% 落在加塞主轴（本计划目标 100%）；且无 c018
        var englishSets = 0
        var totalFocusedSets = 0
        var focusedIdsAll = Set<String>()
        for week in plan.weeks {
            for session in week.sessions {
                for phase in session.phases where phase.type == "focused" {
                    for drill in phase.drills {
                        totalFocusedSets += drill.sets
                        focusedIdsAll.insert(drill.drillId)
                        if englishIds.contains(drill.drillId) {
                            englishSets += drill.sets
                        }
                    }
                }
            }
        }
        XCTAssertGreaterThan(totalFocusedSets, 0)
        let ratio = Double(englishSets) / Double(totalFocusedSets)
        XCTAssertGreaterThanOrEqual(ratio, 0.70, "focused 加塞主轴组数比 \(englishSets)/\(totalFocusedSets)=\(ratio)")
        XCTAssertEqual(englishSets, totalFocusedSets, "本专项 focused 应 100% c073–c078")
        XCTAssertFalse(focusedIdsAll.contains("drill_c018"), "focused 不得含 drill_c018")
        XCTAssertEqual(focusedIdsAll, englishIds, "focused 应恰好覆盖 c073–c078")

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

    func testPlansIndexContainsEnglish() async {
        let index = await PlanContentService.shared.loadPlanIndex()
        XCTAssertNotNil(index)
        let entry = index?.plans.first { $0.id == "plan_english" }
        XCTAssertNotNil(entry, "index 须登记 plan_english")
        XCTAssertEqual(entry?.nameZh, "加塞专项")
        XCTAssertEqual(entry?.targetLevel, "L2")
        XCTAssertEqual(entry?.isPremium, true)
        // W5 升至 6；后续批次继续递增，故断言 ≥6 而非钉死
        XCTAssertGreaterThanOrEqual(index?.version ?? 0, 6, "W5 起 version ≥6")

        // 勿改坏已落地三套专项
        let accuracy = index?.plans.first { $0.id == "plan_accuracy" }
        XCTAssertNotNil(accuracy)
        XCTAssertEqual(accuracy?.isPremium, false)
        let force = index?.plans.first { $0.id == "plan_force" }
        XCTAssertNotNil(force)
        XCTAssertEqual(force?.isPremium, true)
        XCTAssertEqual(force?.targetLevel, "L1→L2")
        let separation = index?.plans.first { $0.id == "plan_separation" }
        XCTAssertNotNil(separation)
        XCTAssertEqual(separation?.nameZh, "分离角专项")
        XCTAssertEqual(separation?.isPremium, true)
        XCTAssertEqual(separation?.targetLevel, "L2")
    }
}
