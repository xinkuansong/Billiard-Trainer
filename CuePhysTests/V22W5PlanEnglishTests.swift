import XCTest
@testable import QiuJi

/// v22 W5 立档：加塞计划解码 + 结构自检。
/// v34 W3 重排后更新（问题集合_v34.md R6/D-v34-2）：plan_english = 杆法Ⅱ·加塞挤偏，
/// 主轴 = c073–c075（加塞认知/挤偏）+ c018/c020/c021（加塞杆法）；带塞准度 c076–c078
/// 已移交 plan_accuracy3（准度Ⅲ·带塞，D-v38-2=A）。v54 起按阶段/课次校验，
/// 不再把课程结构解释为周历，也不再钉死每周训练次数。
final class V22W5PlanEnglishTests: XCTestCase {

    /// v34 归属主轴：本计划承担 ×3 覆盖义务的 6 条。
    private let englishCoreIds: Set<String> = [
        "drill_c073", "drill_c074", "drill_c075",
        "drill_c018", "drill_c020", "drill_c021",
    ]

    func testPlanEnglishDecodesAndMatchesShelfSpec() async throws {
        let plan = await PlanContentService.shared.loadPlanFromBundle(id: "plan_english")
        XCTAssertNotNil(plan, "plan_english 应可解码为 OfficialPlan")
        guard let plan else { return }

        XCTAssertEqual(plan.id, "plan_english")
        XCTAssertEqual(plan.nameZh, "杆法Ⅱ·加塞挤偏")
        XCTAssertEqual(plan.isPremium, true)
        XCTAssertEqual(plan.stages.count, 4, "v54：杆法Ⅱ包含 4 个课程阶段")
        XCTAssertEqual(plan.lessonCount, 12, "v54：杆法Ⅱ包含 12 个稳定课次")
        XCTAssertTrue(plan.description.contains("加塞") || plan.description.contains("挤偏"),
                      "description 应标明加塞/挤偏专项")

        for stage in plan.stages {
            XCTAssertFalse(stage.lessons.isEmpty, "stage \(stage.id) 至少包含一个课次")
            for lesson in stage.lessons {
                for phase in lesson.phases {
                    XCTAssertGreaterThan(phase.durationMinutes, 0,
                                         "stage \(stage.id) lesson \(lesson.id) 相位时长须为正")
                }
            }
        }

        // v31 W5：旧裸组数字段不得回流（在原始 JSON 层扫描键名）。
        try assertPlanJSONHasNoLegacyVolumeKeys("plan_english")

        // 主轴 6 条须全部在计划内；带塞准度 c076–c078 不得回流（已归 plan_accuracy3）。
        var allIds = Set<String>()
        for lesson in plan.lessons {
            for phase in lesson.phases {
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
        var firstFocused: [String] = []
        for lesson in plan.lessons {
            for phase in lesson.phases where phase.type == "focused" {
                for drill in phase.drills where !firstFocused.contains(drill.drillId) {
                    firstFocused.append(drill.drillId)
                }
            }
        }
        // 失败机理（PD-027 / v38 W0）：旧序把走位加塞整周提前、长台/塞量在后。
        XCTAssertEqual(
            firstFocused,
            ["drill_c073", "drill_c074", "drill_c075", "drill_c018", "drill_c020", "drill_c021"],
            "杆法Ⅱ focused 首次引入须等于 W0 表：\(firstFocused)"
        )

        XCTAssertTrue(englishCoreIds.isSubset(of: allIds),
                      "加塞主轴 6 条须全部在 plan_english：\(allIds)")
        for banned in ["drill_c076", "drill_c077", "drill_c078"] {
            XCTAssertFalse(allIds.contains(banned),
                           "\(banned)（带塞准度）已归 plan_accuracy3，不得回流")
        }

        // 全部 drillId ∈ Drills index
        let drillIndex = await DrillContentService.shared.loadDrillIndex()
        XCTAssertNotNil(drillIndex)
        let knownIds = Set(drillIndex?.allDrillIds ?? [])
        XCTAssertTrue(allIds.subtracting(knownIds).isEmpty,
                      "引用了不存在的 drillId: \(allIds.subtracting(knownIds))")
    }

    func testPlansIndexContainsEnglish() async {
        let index = await PlanContentService.shared.loadPlanIndex()
        XCTAssertNotNil(index)
        let entry = index?.plans.first { $0.id == "plan_english" }
        XCTAssertNotNil(entry, "index 须登记 plan_english")
        XCTAssertEqual(entry?.isPremium, true)

        // index 登记须与计划文件一致（防止只改一边）。
        let plan = await PlanContentService.shared.loadPlanFromBundle(id: "plan_english")
        XCTAssertEqual(entry?.nameZh, plan?.nameZh, "index 与计划文件 nameZh 须一致")
        XCTAssertEqual(entry?.targetLevel, plan?.targetLevel, "index 与计划文件 targetLevel 须一致")
        XCTAssertGreaterThanOrEqual(index?.version ?? 0, 6, "W5 起 version ≥6")

        // 勿改坏免费/付费分布（D-v34-2：免费 = beginner/accuracy/cueball）
        for freeId in ["plan_beginner", "plan_accuracy", "plan_cueball"] {
            let e = index?.plans.first { $0.id == freeId }
            XCTAssertNotNil(e, "index 须登记 \(freeId)")
            XCTAssertEqual(e?.isPremium, false, "\(freeId) 应为免费档")
        }
        for paidId in ["plan_intermediate", "plan_accuracy3", "plan_english", "plan_positioning",
                       "plan_positioning2", "plan_separation", "plan_force",
                       "plan_advanced", "plan_fullskill"] {
            let e = index?.plans.first { $0.id == paidId }
            XCTAssertNotNil(e, "index 须登记 \(paidId)")
            XCTAssertEqual(e?.isPremium, true, "\(paidId) 应为付费档")
        }
    }
}
