import XCTest
@testable import QiuJi

/// v21 W5 立档：计划 JSON 接入加塞 drill（解码合法 + 引用可 grep）。
/// v34 W3 重排后更新：加塞主轴 c073–c075 归 `plan_english`（杆法Ⅱ·加塞挤偏），
/// 带塞准度 c076–c078 归 `plan_accuracy3`（准度Ⅲ·带塞，D-v38-2=A）。
/// W1 只加槽、不填课表，故本批只断言它们不在准度Ⅱ / 杆法Ⅱ。
final class V21W5PlanContentTests: XCTestCase {

    func testPlanCueballFirstFocusedOrder() async {
        let plan = await PlanContentService.shared.loadPlanFromBundle(id: "plan_cueball")
        XCTAssertNotNil(plan, "plan_cueball 应可解码")
        guard let plan else { return }

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
        // 失败机理（PD-027 / v38 W0）：旧序热身已是跟进、远台跟进先于近中距。
        XCTAssertEqual(
            firstFocused,
            ["drill_c016", "drill_c014", "drill_c003", "drill_c004", "drill_c015", "drill_c017"],
            "杆法Ⅰ focused 首次引入须等于 W0 表：\(firstFocused)"
        )
    }

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

    func testPlanIntermediateDoesNotContainSpinAccuracyDrills() async {
        // 失败机理（PD-027 / D-v38-2=A）：带塞准度主课迁出准度Ⅱ，写入 plan_accuracy3。
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
            XCTAssertFalse(allIds.contains(id), "带塞准度 \(id) 已归 plan_accuracy3，不得留在准度Ⅱ：\(allIds)")
        }
    }

    func testPlanIntermediateFirstFocusedOrder() async {
        let plan = await PlanContentService.shared.loadPlanFromBundle(id: "plan_intermediate")
        XCTAssertNotNil(plan, "plan_intermediate 应可解码")
        guard let plan else { return }

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
        // 失败机理（PD-027 / v38 W0）：带塞已请出；序为中袋角度 → 远台斜线 → 远台直线/中袋 → 极薄 → 三分点。
        XCTAssertEqual(
            firstFocused,
            ["drill_c053", "drill_c033", "drill_c072", "drill_c062", "drill_c063", "drill_c052"],
            "准度Ⅱ focused 首次引入须等于 W0 表：\(firstFocused)"
        )
    }

    func testPlanAccuracy3ContainsSpinAccuracyDrills() async {
        let plan = await PlanContentService.shared.loadPlanFromBundle(id: "plan_accuracy3")
        XCTAssertNotNil(plan, "plan_accuracy3 应可解码")
        guard let plan else { return }

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
        XCTAssertEqual(firstFocused, ["drill_c076", "drill_c077", "drill_c078"],
                       "准度Ⅲ focused 首次引入须为 c076→c077→c078：\(firstFocused)")
    }

    func testPlanPositioningFirstFocusedOrder() async {
        let plan = await PlanContentService.shared.loadPlanFromBundle(id: "plan_positioning")
        XCTAssertNotNil(plan, "plan_positioning 应可解码")
        guard let plan else { return }

        let allIds = Set(
            plan.weeks.flatMap { week in
                week.sessions.flatMap { session in
                    session.phases.flatMap { $0.drills.map(\.drillId) }
                }
            }
        )
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
        // 失败机理（PD-027 / v38 W0）：引入序本就对，本批锁死以免回流；禁三库/蛇彩。
        XCTAssertEqual(
            firstFocused,
            ["drill_c034", "drill_c037", "drill_c005", "drill_c035",
             "drill_c036", "drill_c079", "drill_c081"],
            "走位Ⅰ focused 首次引入须等于 W0 表：\(firstFocused)"
        )
        for banned in ["drill_c040", "drill_c042", "drill_c082"] {
            XCTAssertFalse(allIds.contains(banned),
                           "\(banned) 是三库/蛇彩，不得进走位Ⅰ")
        }
    }

    func testPlanPositioning2FirstFocusedOrder() async {
        let plan = await PlanContentService.shared.loadPlanFromBundle(id: "plan_positioning2")
        XCTAssertNotNil(plan, "plan_positioning2 应可解码")
        guard let plan else { return }

        let allIds = Set(
            plan.weeks.flatMap { week in
                week.sessions.flatMap { session in
                    session.phases.flatMap { $0.drills.map(\.drillId) }
                }
            }
        )
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
        // 失败机理（PD-027 / v38 W0）：旧序第一堂是初级蛇彩；c040 必须 focused。
        // allIds 含咬合热身 c036/c079，不是请出/迁入主课。
        XCTAssertEqual(
            firstFocused,
            ["drill_c080", "drill_c038", "drill_c041", "drill_c039",
             "drill_c040", "drill_c042", "drill_c082"],
            "走位Ⅱ focused 首次引入须等于 W0 表：\(firstFocused)"
        )
        XCTAssertTrue(firstFocused.contains("drill_c040"), "c040 三库必须 focused")
        for core in ["drill_c080", "drill_c038", "drill_c041", "drill_c039",
                     "drill_c040", "drill_c042", "drill_c082"] {
            XCTAssertTrue(allIds.contains(core), "\(core) 须在走位Ⅱ")
        }
        XCTAssertTrue(allIds.contains("drill_c036") || allIds.contains("drill_c079"),
                      "走位Ⅱ开档应咬合走位Ⅰ c036 或 c079")
    }

    func testPlanBeginnerFirstFocusedOrder() async {
        let plan = await PlanContentService.shared.loadPlanFromBundle(id: "plan_beginner")
        XCTAssertNotNil(plan, "plan_beginner 应可解码")
        guard let plan else { return }

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
        // 失败机理（PD-027 / v38 W0）：旧序五分点进 W2、定杆在后；高级手架插进远台周主题错位。
        XCTAssertEqual(
            firstFocused,
            ["drill_c006", "drill_c007", "drill_c008", "drill_c009",
             "drill_c010", "drill_c023", "drill_c022", "drill_c043"],
            "基本功 focused 首次引入须等于 W0 表：\(firstFocused)"
        )
        XCTAssertEqual(plan.isPremium, false, "基本功须保持免费")
    }

    func testPlanAdvancedFirstFocusedOrder() async {
        let plan = await PlanContentService.shared.loadPlanFromBundle(id: "plan_advanced")
        XCTAssertNotNil(plan, "plan_advanced 应可解码")
        guard let plan else { return }

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
        // 失败机理（PD-027 / v38 W0）：旧序 K 球先于翻角袋；中袋热身伺候角袋衰减。
        XCTAssertEqual(
            firstFocused,
            ["drill_c054", "drill_c056", "drill_c057", "drill_c055",
             "drill_c058", "drill_c059", "drill_c060", "drill_c061"],
            "特殊球 focused 首次引入须等于 W0 表：\(firstFocused)"
        )
    }

    func testPlanFullskillFirstFocusedOrderAndBites() async throws {
        let plan = await PlanContentService.shared.loadPlanFromBundle(id: "plan_fullskill")
        XCTAssertNotNil(plan, "plan_fullskill 应可解码")
        guard let plan else { return }

        var firstFocused: [String] = []
        var allIds: [String] = []
        var biteCount: [String: Int] = [:]
        for week in plan.weeks {
            for session in week.sessions {
                for phase in session.phases {
                    for drill in phase.drills {
                        if !allIds.contains(drill.drillId) { allIds.append(drill.drillId) }
                        if phase.type == "focused", !firstFocused.contains(drill.drillId) {
                            firstFocused.append(drill.drillId)
                        }
                        if ["drill_c082", "drill_c054", "drill_c078"].contains(drill.drillId) {
                            biteCount[drill.drillId, default: 0] += 1
                            XCTAssertEqual(phase.type, "warmup", "\(drill.drillId) 只许咬合热身")
                            let dose = try XCTUnwrap(drill.dose, "\(drill.drillId) 缺 dose")
                            XCTAssertEqual(dose.reviewFrom, [
                                "drill_c082": "plan_positioning2",
                                "drill_c054": "plan_advanced",
                                "drill_c078": "plan_accuracy3",
                            ][drill.drillId], "\(drill.drillId) reviewFrom 须指向来源计划")
                        }
                    }
                }
            }
        }
        // 失败机理（PD-027 / v38 W0）：旧序十球/十五球蛇彩先于五球。
        XCTAssertEqual(
            firstFocused,
            ["drill_c066", "drill_c064", "drill_c068", "drill_c069",
             "drill_c071", "drill_c067", "drill_c065", "drill_c070"],
            "全能 focused 首次引入须等于 W0 表：\(firstFocused)"
        )
        XCTAssertEqual(plan.minutesPerSession, 120, "全能课时档 120′")
        XCTAssertEqual(plan.isPremium, true, "全能须保持 Pro")
        for bite in ["drill_c082", "drill_c054", "drill_c078"] {
            XCTAssertEqual(biteCount[bite], 1, "\(bite) 各至多 1 次，且本批应收一次：\(biteCount)")
        }
        let stolen = allIds.filter { id in
            !firstFocused.contains(id) && !["drill_c082", "drill_c054", "drill_c078"].contains(id)
        }
        XCTAssertTrue(stolen.isEmpty, "全能不得另抢其它线程主课：\(stolen)")
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
