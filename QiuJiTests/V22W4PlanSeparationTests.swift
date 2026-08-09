import XCTest
@testable import QiuJi

/// v22 W4：分离角专项 plan_separation 解码 + 周次结构自检。
final class V22W4PlanSeparationTests: XCTestCase {

    /// separation 分类全量（v33 起 8 → 10 条，新增 c083 吃库分离角 / c084 不吃库分离角）。
    private let separationIds: Set<String> = [
        "drill_c024", "drill_c025", "drill_c026", "drill_c027",
        "drill_c028", "drill_c029", "drill_c030", "drill_c031",
        "drill_c083", "drill_c084",
    ]

    /// dose → 轮数（统一轮数，或按球形逐条求和）。v31 W3a：计划不再存裸组数。
    static func rounds(of dose: PlanDrillDose) -> Int {
        if let listed = dose.formations, !listed.isEmpty {
            return listed.reduce(0) { $0 + $1.rounds }
        }
        return dose.roundsPerFormation ?? 0
    }

    func testPlanSeparationDecodesAndMatchesShelfSpec() async throws {
        let plan = await PlanContentService.shared.loadPlanFromBundle(id: "plan_separation")
        XCTAssertNotNil(plan, "plan_separation 应可解码为 OfficialPlan")
        guard let plan else { return }

        XCTAssertEqual(plan.id, "plan_separation")
        XCTAssertEqual(plan.nameZh, "分离角专项")
        XCTAssertEqual(plan.nameEn, "Separation Angle Specialist")
        XCTAssertEqual(plan.targetLevel, "L2")
        XCTAssertEqual(plan.durationWeeks, 6)
        XCTAssertEqual(plan.sessionsPerWeek, 3)
        XCTAssertEqual(plan.minutesPerSession, 75)
        XCTAssertEqual(plan.isPremium, true)
        XCTAssertTrue(
            plan.description.contains("分离角"),
            "description 应标明分离角专项"
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
            1: "90° 规则",
            2: "厚薄感知",
            3: "高杆缩小分离角",
            4: "低杆扩大分离角",
            5: "定杆精确与走位应用",
            6: "综合挑战",
        ]
        for (n, theme) in themes {
            let week = plan.weeks.first { $0.weekNumber == n }
            XCTAssertEqual(week?.theme, theme, "week \(n) theme")
        }

        // focused 主轴：每周至少含 §2.2 primary（+ secondary）
        let requiredFocused: [Int: Set<String>] = [
            1: ["drill_c024"],
            2: ["drill_c025", "drill_c026"],
            3: ["drill_c027"],
            4: ["drill_c028"],
            5: ["drill_c029", "drill_c030"],
            6: ["drill_c031"],
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

        // focused 轮数 ≥70% 落在 separation（本计划目标 100%）
        // v31 W3a 起计划只存 dose（契约 §6.6），组数口径改为 dose 轮数。
        var sepSets = 0
        var totalFocusedSets = 0
        // v31 W5：`PlanDrillRef.sets/ballsPerSet` 已删除（契约 §6.6），原逐条
        // `XCTAssertNil(drill.sets/…)` 不再可编译；且解码器忽略未知键 ⇒ JSON 残留旧字段
        // 在 Swift 侧不可观察。改为在原始 JSON 层扫描键名，覆盖全计划（不止 focused 段）。
        try assertPlanJSONHasNoLegacyVolumeKeys("plan_separation")
        for week in plan.weeks {
            for session in week.sessions {
                for phase in session.phases where phase.type == "focused" {
                    for drill in phase.drills {
                        let dose = try XCTUnwrap(drill.dose, "\(drill.drillId) 缺 dose")
                        let rounds = Self.rounds(of: dose)
                        totalFocusedSets += rounds
                        if separationIds.contains(drill.drillId) {
                            sepSets += rounds
                        }
                    }
                }
            }
        }
        XCTAssertGreaterThan(totalFocusedSets, 0)
        let ratio = Double(sepSets) / Double(totalFocusedSets)
        XCTAssertGreaterThanOrEqual(ratio, 0.70, "focused separation 组数比 \(sepSets)/\(totalFocusedSets)=\(ratio)")
        XCTAssertEqual(sepSets, totalFocusedSets, "本专项 focused 应 100% separation")

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

    func testPlansIndexContainsSeparation() async {
        let index = await PlanContentService.shared.loadPlanIndex()
        XCTAssertNotNil(index)
        let entry = index?.plans.first { $0.id == "plan_separation" }
        XCTAssertNotNil(entry, "index 须登记 plan_separation")
        XCTAssertEqual(entry?.nameZh, "分离角专项")
        XCTAssertEqual(entry?.targetLevel, "L2")
        XCTAssertEqual(entry?.isPremium, true)
        // W4 升至 5；后续批次继续递增，故断言 ≥5 而非钉死
        XCTAssertGreaterThanOrEqual(index?.version ?? 0, 5, "W4 起 version ≥5")

        // 勿改坏 plan_accuracy / plan_force
        let accuracy = index?.plans.first { $0.id == "plan_accuracy" }
        XCTAssertNotNil(accuracy)
        XCTAssertEqual(accuracy?.isPremium, false)
        let force = index?.plans.first { $0.id == "plan_force" }
        XCTAssertNotNil(force)
        XCTAssertEqual(force?.isPremium, true)
        XCTAssertEqual(force?.targetLevel, "L1→L2")
    }
}
