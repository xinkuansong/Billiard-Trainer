import XCTest
import SwiftData
@testable import QiuJi

/// v31 W2：计划 dose × drill `perFormation` → 组序列（契约 §6.6）。
///
/// 断言口径一律**与 Bundle 内容真源交叉核对**（perFormation token / ballsPerRound、
/// 序列实测杆数），不写死期望数字，避免内容改版后测试变成「保护过时快照」。
@MainActor
final class TrainingHomeViewModelTests: XCTestCase {

    // MARK: - Fixtures

    /// 必须持有容器：`makeInMemoryContainer().mainContext` 用完即释放容器会在 SwiftData 内崩溃。
    private var container: ModelContainer!

    override func setUp() {
        super.setUp()
        container = ModelContainerFactory.makeInMemoryContainer()
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    private func makeContext() -> ModelContext {
        container.mainContext
    }

    private func bundledDrill(_ id: String) throws -> DrillContent {
        try XCTUnwrap(DrillContentService.decodeDrillFromBundle(id: id),
                      "\(id) 未能从 Bundle 解码")
    }

    /// 建一个只含指定 drill 的自定义计划并激活。
    private func activateCustomPlan(
        context: ModelContext, drillId: String, nameZh: String, rounds: Int
    ) throws {
        let plan = CustomPlan(name: "W2 测试计划", sessionsPerWeek: 3)
        plan.drills = [
            CustomPlanDrill(drillId: drillId, drillNameZh: nameZh,
                            roundsPerFormation: rounds, order: 0)
        ]
        context.insert(plan)
        context.insert(UserActivePlan(planId: plan.id.uuidString, isCustom: true))
        try context.save()
    }

    // MARK: - 多球形展开顺序与逐组 token（R6）

    func test_customPlan_multiFormation_expandsFormationMajorOrder() async throws {
        let content = try bundledDrill("drill_c013")
        let perFormation = try XCTUnwrap(content.sets.perFormation)
        XCTAssertGreaterThan(perFormation.count, 1, "drill_c013 应为多球形")

        let context = makeContext()
        let rounds = 2
        try activateCustomPlan(context: context, drillId: content.id,
                               nameZh: content.nameZh, rounds: rounds)

        let vm = TrainingHomeViewModel()
        await vm.load(context: context)

        let item = try XCTUnwrap(vm.todaySession?.drills.first)
        XCTAssertEqual(item.plannedSets.count, perFormation.count * rounds)

        // 球形 1 轮 1 → 球形 1 轮 2 → 球形 2 轮 1 → 球形 2 轮 2
        let expectedTokens = perFormation.flatMap { formation in
            Array(repeating: formation.token, count: rounds)
        }
        XCTAssertEqual(item.plannedSets.map(\.formationToken), expectedTokens)

        // 每组球数 = 该球形 ballsPerRound
        let expectedTargets = perFormation.flatMap { formation in
            Array(repeating: formation.ballsPerRound, count: rounds)
        }
        XCTAssertEqual(item.plannedSets.map(\.targetBalls), expectedTargets)

        // 球形显示名来自序列文件（落库快照，契约 §6.5）
        let optionNames = Dictionary(
            uniqueKeysWithValues: TrainingDoseResolver
                .formationOptions(forDrillId: content.id).map { ($0.token, $0.name) }
        )
        for planned in item.plannedSets {
            let token = try XCTUnwrap(planned.formationToken)
            XCTAssertEqual(planned.formationName, optionNames[token])
        }

        print("[W2-EVIDENCE] c013 expanded: "
              + item.plannedSets.map { "\($0.formationToken ?? "nil")/\($0.targetBalls)" }
                  .joined(separator: " → "))
    }

    /// 逐球形球数异构：c053 两个球形 10 / 13，展开后逐组球数必须跟着球形走。
    func test_customPlan_heterogeneousBallsPerFormation() async throws {
        let content = try bundledDrill("drill_c053")
        let perFormation = try XCTUnwrap(content.sets.perFormation)
        XCTAssertGreaterThan(Set(perFormation.map(\.ballsPerRound)).count, 1,
                             "drill_c053 应为逐球形球数异构")

        let context = makeContext()
        try activateCustomPlan(context: context, drillId: content.id,
                               nameZh: content.nameZh, rounds: 2)

        let vm = TrainingHomeViewModel()
        await vm.load(context: context)

        let item = try XCTUnwrap(vm.todaySession?.drills.first)
        let expected = perFormation.flatMap { Array(repeating: $0.ballsPerRound, count: 2) }
        XCTAssertEqual(item.plannedSets.map(\.targetBalls), expected)
        XCTAssertEqual(item.totalBalls, expected.reduce(0, +))
        // 异构不得再渲染成「N 轮 × N 球」
        XCTAssertTrue(item.volumeText.contains("球形"), "异构文案实际为：\(item.volumeText)")

        print("[W2-EVIDENCE] c053 volumeText=\(item.volumeText) targets=\(expected)")
    }

    // MARK: - sequence / repetition 口径（R3）

    /// sequence 型球形：每组目标球数必须等于该球形序列的**实测杆数**（契约 §5.6.2 / I6b）。
    func test_sequenceFormations_targetEqualsSequenceShotCount() throws {
        var checked = 0
        for drillId in try allBundledDrillIds() {
            guard let content = DrillContentService.decodeDrillFromBundle(id: drillId),
                  let perFormation = content.sets.perFormation else { continue }
            let sequences = DrillTryoutBoardStore.formations(for: drillId)
            guard !sequences.isEmpty else { continue }
            let stepCounts = Dictionary(
                sequences.map { ($0.token, $0.stepCount) }, uniquingKeysWith: { a, _ in a }
            )

            let resolved = TrainingDoseResolver.resolve(content: content)
            for (index, formation) in perFormation.enumerated()
            where formation.mode == .sequence {
                guard let steps = stepCounts[formation.token] else { continue }
                XCTAssertEqual(resolved.groups[index].ballsPerRound, steps,
                               "\(drillId)/\(formation.token) sequence 型每轮球数应 = 序列杆数")
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 0, "库内应存在 sequence 型球形")
        print("[W2-EVIDENCE] sequence 型球形核对条数=\(checked)")
    }

    /// repetition 型：每组目标球数取内容声明的 `ballsPerRound`（与序列杆数无关）。
    func test_repetitionFormation_usesDeclaredBallsPerRound() throws {
        let content = try bundledDrill("drill_c013")
        let perFormation = try XCTUnwrap(content.sets.perFormation)
        XCTAssertTrue(perFormation.allSatisfy { $0.mode == .repetition })

        let resolved = TrainingDoseResolver.resolve(content: content)
        XCTAssertEqual(resolved.groups.map(\.ballsPerRound), perFormation.map(\.ballsPerRound))
        XCTAssertEqual(resolved.groups.map(\.rounds), perFormation.map(\.defaultRounds))
    }

    /// 无 `perFormation` 的 drill（契约 §5.6.4 豁免清单）回落到汇总兜底，且不带球形 token。
    func test_drillWithoutPerFormation_fallsBackToSummaryDose() throws {
        let content = try bundledDrill("drill_c008")
        XCTAssertNil(content.sets.perFormation, "drill_c008 应无 perFormation（无序列豁免）")

        let resolved = TrainingDoseResolver.resolve(content: content)
        XCTAssertEqual(resolved.groups.count, 1)
        XCTAssertEqual(resolved.totalRounds, content.sets.defaultSets)
        XCTAssertEqual(resolved.groups[0].ballsPerRound, content.sets.defaultBallsPerSet)
        XCTAssertNil(resolved.groups[0].formationToken)

        // 计划给了轮数时按计划轮数，球数仍取汇总兜底。
        let planned = TrainingDoseResolver.resolve(
            content: content, dose: PlanDrillDose(roundsPerFormation: 5)
        )
        XCTAssertEqual(planned.totalRounds, 5)
        XCTAssertEqual(planned.totalBalls, 5 * content.sets.defaultBallsPerSet)
    }

    // MARK: - dose 语义

    /// 单球形 drill 不带 token（契约 §4.1：`DrillSet.formationToken` 保持 nil）。
    func test_singleFormationDrill_keepsFormationTokenNil() throws {
        let content = try bundledDrill("drill_c001")
        XCTAssertEqual(content.sets.perFormation?.count, 1)
        let resolved = TrainingDoseResolver.resolve(
            content: content,
            formationOptions: TrainingDoseResolver.formationOptions(forDrillId: content.id)
        )
        XCTAssertTrue(resolved.plannedSets.allSatisfy { $0.formationToken == nil })
    }

    /// 按球形引用：未列出的球形本次不展开（契约 §6.6 推论 3）。
    func test_doseFormations_onlyListedFormationsExpand() throws {
        let content = try bundledDrill("drill_c013")
        let perFormation = try XCTUnwrap(content.sets.perFormation)
        let second = perFormation[1]

        let resolved = TrainingDoseResolver.resolve(
            content: content,
            dose: PlanDrillDose(formations: [
                PlanDrillDose.FormationRounds(token: second.token, rounds: 3)
            ]),
            formationOptions: TrainingDoseResolver.formationOptions(forDrillId: content.id)
        )
        XCTAssertEqual(resolved.groups.count, 1)
        XCTAssertEqual(resolved.groups[0].formationToken, second.token)
        XCTAssertEqual(resolved.totalRounds, 3)
        XCTAssertEqual(resolved.plannedSets.map(\.targetBalls),
                       Array(repeating: second.ballsPerRound, count: 3))
    }

    /// v31 W5：`PlanDrillRef.sets/ballsPerSet` 与 `resolve(legacySets:legacyBallsPerSet:)` 已删除
    /// （契约 §6.6：计划不再存裸球数）。原 `test_legacyPlanEntry_rendersWithoutFormationExpansion`
    /// 断言的是被删掉的兼容路径本身，被测对象不复存在故随代码一并移除；
    /// 它守护的语义「计划里不得再出现裸球数」改由下面的原始 JSON 键扫描承接——
    /// 因为字段删除后 `XCTAssertNil(ref.sets)` 无法再编译，而解码器会静默忽略未知键，
    /// 只有直接读 JSON 才能证明残留为零。
    // MARK: - 官方计划端到端渲染

    func test_officialPlan_todaySessionRenders() async throws {
        let plans = await PlanContentService.shared.loadAllPlans()
        let plan = try XCTUnwrap(plans.first)

        let context = makeContext()
        context.insert(UserActivePlan(planId: plan.id, isCustom: false))
        try context.save()

        let vm = TrainingHomeViewModel()
        await vm.load(context: context)

        let session = try XCTUnwrap(vm.todaySession)
        XCTAssertFalse(session.drills.isEmpty)
        for item in session.drills {
            XCTAssertFalse(item.plannedSets.isEmpty, "\(item.drillId) 未解析出任何组")
            XCTAssertTrue(item.plannedSets.allSatisfy { $0.targetBalls > 0 })
            XCTAssertFalse(item.volumeText.isEmpty)
        }
        print("[W2-EVIDENCE] official plan \(plan.id) 首条：\(session.drills[0].volumeText)")
    }

    /// v31 W3a：6 份专项计划已全量迁移到 dose 格式，且每条目都能解析出非空组序列。
    /// 期望值不写死球数——只核「dose 存在 / 旧字段清零 / 解析结果与内容真源一致」。
    func test_rewrittenSpecialistPlans_areDoseOnlyAndResolvable() async throws {
        let rewritten = [
            "plan_accuracy", "plan_cueball", "plan_english",
            "plan_force", "plan_separation", "plan_positioning",
        ]
        var entries = 0
        for planId in rewritten {
            let plan = try XCTUnwrap(PlanContentService.decodePlanFromBundle(id: planId),
                                     "\(planId) 未能解码")
            try assertPlanJSONHasNoLegacyVolumeKeys(planId)
            for week in plan.weeks {
                for session in week.sessions {
                    for phase in session.phases {
                        for ref in phase.drills {
                            let dose = try XCTUnwrap(ref.dose, "\(planId) \(ref.drillId) 缺 dose")
                            XCTAssertTrue(
                                (dose.roundsPerFormation == nil) != (dose.formations == nil),
                                "\(planId) \(ref.drillId) 的 dose 两种形态必须恰好二选一"
                            )
                            let content = try XCTUnwrap(
                                DrillContentService.decodeDrillFromBundle(id: ref.drillId),
                                "\(planId) 引用了无法解码的 \(ref.drillId)"
                            )
                            let resolved = TrainingDoseResolver.resolve(content: content, dose: dose)
                            XCTAssertFalse(resolved.plannedSets.isEmpty,
                                           "\(planId) \(ref.drillId) 解析出 0 组")
                            XCTAssertTrue(resolved.plannedSets.allSatisfy { $0.targetBalls > 0 })
                            // 按球形引用：token 必须存在于该 drill 的 perFormation
                            if let listed = dose.formations {
                                let known = Set(content.sets.perFormation?.map(\.token) ?? [])
                                for item in listed {
                                    XCTAssertTrue(known.contains(item.token),
                                                  "\(planId) \(ref.drillId) token \(item.token) 不存在")
                                }
                                XCTAssertEqual(resolved.groups.count, listed.count)
                            }
                            entries += 1
                        }
                    }
                }
            }
        }
        XCTAssertGreaterThan(entries, 400, "6 份计划条目数量级异常：\(entries)")
        print("[W3a-EVIDENCE] 6 份专项计划 dose 条目核对数=\(entries)")
    }

    /// v31 W3b：4 份综合计划（beginner / intermediate / advanced / fullskill）同样全量 dose 化。
    /// 与上面的专项计划用例同一口径——⛔ 不写死球数，只核格式切净与解析结果自洽。
    func test_rewrittenCompositePlans_areDoseOnlyAndResolvable() async throws {
        let rewritten = [
            "plan_beginner", "plan_intermediate", "plan_advanced", "plan_fullskill",
        ]
        var entries = 0
        for planId in rewritten {
            let plan = try XCTUnwrap(PlanContentService.decodePlanFromBundle(id: planId),
                                     "\(planId) 未能解码")
            try assertPlanJSONHasNoLegacyVolumeKeys(planId)
            XCTAssertEqual(plan.weeks.count, plan.durationWeeks, "\(planId) 周数与 durationWeeks 不符")
            for week in plan.weeks {
                XCTAssertEqual(week.sessions.count, plan.sessionsPerWeek,
                               "\(planId) W\(week.weekNumber) 天数与 sessionsPerWeek 不符")
                for session in week.sessions {
                    XCTAssertEqual(session.phases.reduce(0) { $0 + $1.durationMinutes },
                                   plan.minutesPerSession,
                                   "\(planId) W\(week.weekNumber) D\(session.dayNumber) 阶段时长合计不符")
                    for phase in session.phases {
                        for ref in phase.drills {
                            let dose = try XCTUnwrap(ref.dose, "\(planId) \(ref.drillId) 缺 dose")
                            XCTAssertTrue(
                                (dose.roundsPerFormation == nil) != (dose.formations == nil),
                                "\(planId) \(ref.drillId) 的 dose 两种形态必须恰好二选一"
                            )
                            let content = try XCTUnwrap(
                                DrillContentService.decodeDrillFromBundle(id: ref.drillId),
                                "\(planId) 引用了无法解码的 \(ref.drillId)"
                            )
                            let resolved = TrainingDoseResolver.resolve(content: content, dose: dose)
                            XCTAssertFalse(resolved.plannedSets.isEmpty,
                                           "\(planId) \(ref.drillId) 解析出 0 组")
                            XCTAssertTrue(resolved.plannedSets.allSatisfy { $0.targetBalls > 0 })
                            if let listed = dose.formations {
                                let known = Set(content.sets.perFormation?.map(\.token) ?? [])
                                for item in listed {
                                    XCTAssertTrue(known.contains(item.token),
                                                  "\(planId) \(ref.drillId) token \(item.token) 不存在")
                                }
                                XCTAssertEqual(resolved.groups.count, listed.count)
                            }
                            entries += 1
                        }
                    }
                }
            }
        }
        XCTAssertGreaterThan(entries, 600, "4 份综合计划条目数量级异常：\(entries)")
        print("[W3b-EVIDENCE] 4 份综合计划 dose 条目核对数=\(entries)")
    }

    // MARK: - Helpers

    private func allBundledDrillIds() throws -> [String] {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "index",
                                                           withExtension: "json",
                                                           subdirectory: "Drills")
                                ?? Bundle.main.url(forResource: "index",
                                                   withExtension: "json",
                                                   subdirectory: "Drills"))
        let index = try JSONDecoder().decode(DrillIndex.self, from: try Data(contentsOf: url))
        return index.allDrillIds
    }
}

/// v31 W5：直接读计划原始 JSON，证明条目里没有旧格式裸球数键（契约 §6.6）。
///
/// 为什么不能再用 `XCTAssertNil(ref.sets)`：W5 已把 `PlanDrillRef.sets/ballsPerSet` 删除，
/// 那两行断言不再可编译；而 `JSONDecoder` 默认忽略未知键 ⇒ 即便 JSON 里残留旧字段，
/// 解码也照样成功、没有任何 Swift 侧可观察量。故改为在 JSON 层扫描键名，
/// 断言强度不降反升（旧断言只能覆盖能映射到属性的字段）。
func assertPlanJSONHasNoLegacyVolumeKeys(
    _ planId: String, file: StaticString = #filePath, line: UInt = #line
) throws {
    let bundle = Bundle(for: TrainingHomeViewModelTests.self)
    let url = try XCTUnwrap(
        bundle.url(forResource: planId, withExtension: "json", subdirectory: "Plans")
            ?? Bundle.main.url(forResource: planId, withExtension: "json", subdirectory: "Plans"),
        "\(planId).json 未找到", file: file, line: line
    )
    let root = try XCTUnwrap(
        JSONSerialization.jsonObject(with: try Data(contentsOf: url)) as? [String: Any],
        "\(planId).json 顶层不是对象", file: file, line: line
    )
    let weeks = root["weeks"] as? [[String: Any]] ?? []
    XCTAssertFalse(weeks.isEmpty, "\(planId) weeks 为空", file: file, line: line)
    var checked = 0
    for week in weeks {
        for session in week["sessions"] as? [[String: Any]] ?? [] {
            for phase in session["phases"] as? [[String: Any]] ?? [] {
                for drill in phase["drills"] as? [[String: Any]] ?? [] {
                    let drillId = drill["drillId"] as? String ?? "?"
                    XCTAssertNil(drill["sets"],
                                 "\(planId) \(drillId) 仍残留旧格式 sets", file: file, line: line)
                    XCTAssertNil(drill["ballsPerSet"],
                                 "\(planId) \(drillId) 仍残留旧格式 ballsPerSet", file: file, line: line)
                    checked += 1
                }
            }
        }
    }
    XCTAssertGreaterThan(checked, 0, "\(planId) 未扫描到任何条目", file: file, line: line)
}
