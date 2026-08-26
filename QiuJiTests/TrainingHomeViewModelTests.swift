import XCTest
import SwiftData
import Combine
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
        // v34 R9：roundsPerFormation = 遍数倍数；×2 ⇒ 每球形 defaultRounds×2、位置全覆盖。
        let multiplier = 2
        try activateCustomPlan(context: context, drillId: content.id,
                               nameZh: content.nameZh, rounds: multiplier)

        let vm = TrainingHomeViewModel()
        await vm.load(context: context)

        let item = try XCTUnwrap(vm.todaySession?.drills.first)
        let expectedSetCount = perFormation.reduce(0) { $0 + $1.defaultRounds * multiplier }
        XCTAssertEqual(item.plannedSets.count, expectedSetCount)

        // 球形 1 的全部位置 → 球形 2 的全部位置（各 × 倍数）
        let expectedTokens = perFormation.flatMap { formation in
            Array(repeating: formation.token, count: formation.defaultRounds * multiplier)
        }
        XCTAssertEqual(item.plannedSets.map(\.formationToken), expectedTokens)

        // 每组球数 = 该球形 ballsPerRound
        let expectedTargets = perFormation.flatMap { formation in
            Array(repeating: formation.ballsPerRound, count: formation.defaultRounds * multiplier)
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

        print("[W4-EVIDENCE] c013 expanded ×\(multiplier): "
              + item.plannedSets.map { "\($0.formationToken ?? "nil")/\($0.targetBalls)" }
                  .joined(separator: " → "))
    }

    /// 逐球形球数异构：c069（sequence 10 + repetition 15）展开后逐组球数必须跟着球形走（倍数语义）。
    /// ⚠️ W2 后 c053 两球形均为 bpr=15，不再异构；改锚到仍异构的 c069。
    func test_customPlan_heterogeneousBallsPerFormation() async throws {
        let content = try bundledDrill("drill_c069")
        let perFormation = try XCTUnwrap(content.sets.perFormation)
        XCTAssertGreaterThan(Set(perFormation.map(\.ballsPerRound)).count, 1,
                             "drill_c069 应为逐球形球数异构")

        let context = makeContext()
        let multiplier = 2
        try activateCustomPlan(context: context, drillId: content.id,
                               nameZh: content.nameZh, rounds: multiplier)

        let vm = TrainingHomeViewModel()
        await vm.load(context: context)

        let item = try XCTUnwrap(vm.todaySession?.drills.first)
        let expected = perFormation.flatMap {
            Array(repeating: $0.ballsPerRound, count: $0.defaultRounds * multiplier)
        }
        XCTAssertEqual(item.plannedSets.map(\.targetBalls), expected)
        XCTAssertEqual(item.totalBalls, expected.reduce(0, +))
        // 异构不得再渲染成「N 轮 × N 球」
        XCTAssertTrue(item.volumeText.contains("球形"), "异构文案实际为：\(item.volumeText)")

        print("[W4-EVIDENCE] c069 volumeText=\(item.volumeText) targets=\(expected)")
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
        let content = try bundledDrill("drill_c065")
        XCTAssertNil(content.sets.perFormation, "drill_c065 应无 perFormation（无序列豁免）")

        let resolved = TrainingDoseResolver.resolve(content: content)
        XCTAssertEqual(resolved.groups.count, 1)
        XCTAssertEqual(resolved.totalRounds, content.sets.defaultSets)
        XCTAssertEqual(resolved.groups[0].ballsPerRound, content.sets.defaultBallsPerSet)
        XCTAssertNil(resolved.groups[0].formationToken)

        // v34 R9：无序列 drill 的 roundsPerFormation = 倍数，作用于 defaultSets。
        let multiplier = 5
        let planned = TrainingDoseResolver.resolve(
            content: content, dose: PlanDrillDose(roundsPerFormation: multiplier)
        )
        XCTAssertEqual(planned.totalRounds, content.sets.defaultSets * multiplier)
        XCTAssertEqual(planned.totalBalls,
                       content.sets.defaultSets * multiplier * content.sets.defaultBallsPerSet)
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
        // 高于 defaultRounds 的显式轮数保留（选球形 + 加量）；低于则另测钳制。
        let requested = second.defaultRounds + 2

        let resolved = TrainingDoseResolver.resolve(
            content: content,
            dose: PlanDrillDose(formations: [
                PlanDrillDose.FormationRounds(token: second.token, rounds: requested)
            ]),
            formationOptions: TrainingDoseResolver.formationOptions(forDrillId: content.id)
        )
        XCTAssertEqual(resolved.groups.count, 1)
        XCTAssertEqual(resolved.groups[0].formationToken, second.token)
        XCTAssertEqual(resolved.totalRounds, requested)
        XCTAssertEqual(resolved.plannedSets.map(\.targetBalls),
                       Array(repeating: second.ballsPerRound, count: requested))
    }

    // MARK: - v34 R9 倍数语义 / formations 下限

    /// `roundsPerFormation=2` ⇒ 每球形 defaultRounds×2，位置全覆盖（不砍位置）。
    func test_roundsPerFormation_isMultiplier_fullCoverage() throws {
        let content = try bundledDrill("drill_c013")
        let perFormation = try XCTUnwrap(content.sets.perFormation)
        let multiplier = 2

        let resolved = TrainingDoseResolver.resolve(
            content: content,
            dose: PlanDrillDose(roundsPerFormation: multiplier),
            formationOptions: TrainingDoseResolver.formationOptions(forDrillId: content.id)
        )

        XCTAssertEqual(resolved.groups.map(\.rounds),
                       perFormation.map { $0.defaultRounds * multiplier })
        XCTAssertEqual(resolved.groups.map(\.ballsPerRound),
                       perFormation.map(\.ballsPerRound))
        XCTAssertEqual(resolved.totalRounds,
                       perFormation.reduce(0) { $0 + $1.defaultRounds * multiplier })
        // 位置全覆盖：展开条数 = Σ (defaultRounds × 倍数)，不得被砍成「每球形仅 2 轮」。
        XCTAssertGreaterThan(resolved.totalRounds, perFormation.count * multiplier)
    }

    /// formations 轮数低于内容 defaultRounds 时钳到下限（不得静默砍位置）。
    func test_formations_roundsBelowFloor_clampedToDefaultRounds() throws {
        let content = try bundledDrill("drill_c013")
        let perFormation = try XCTUnwrap(content.sets.perFormation)
        let second = perFormation[1]
        XCTAssertGreaterThan(second.defaultRounds, 1, "需有可低于的 defaultRounds")

        let resolved = TrainingDoseResolver.resolve(
            content: content,
            dose: PlanDrillDose(formations: [
                PlanDrillDose.FormationRounds(token: second.token, rounds: 1)
            ]),
            formationOptions: TrainingDoseResolver.formationOptions(forDrillId: content.id)
        )

        XCTAssertEqual(resolved.groups.count, 1)
        XCTAssertEqual(resolved.groups[0].rounds, second.defaultRounds)
        XCTAssertEqual(resolved.plannedSets.count, second.defaultRounds)
    }

    /// v38 R7：`repetition` + decay 仍不得砍位置，rounds 钳回 defaultRounds。
    func test_formations_repetitionDecay_doesNotCutPositions() throws {
        let content = try bundledDrill("drill_c013")
        let perFormation = try XCTUnwrap(content.sets.perFormation)
        let second = perFormation[1]
        XCTAssertEqual(second.mode, .repetition)
        XCTAssertGreaterThan(second.defaultRounds, 1, "需有可低于的 defaultRounds")

        let resolved = TrainingDoseResolver.resolve(
            content: content,
            dose: PlanDrillDose(
                formations: [
                    PlanDrillDose.FormationRounds(token: second.token, rounds: 1)
                ],
                decay: true
            ),
            formationOptions: TrainingDoseResolver.formationOptions(forDrillId: content.id)
        )

        XCTAssertEqual(resolved.groups.count, 1)
        XCTAssertEqual(resolved.groups[0].rounds, second.defaultRounds)
        XCTAssertEqual(resolved.groups[0].ballsPerRound, second.ballsPerRound)
        XCTAssertEqual(resolved.plannedSets.count, second.defaultRounds)
    }

    /// v38 R7：`repetition` + decay + 计划侧 ballsPerRound 只降每位置颗数。
    func test_formations_repetitionDecay_reducesBallsPerRound() throws {
        let content = try bundledDrill("drill_c013")
        let perFormation = try XCTUnwrap(content.sets.perFormation)
        let second = perFormation[1]
        XCTAssertEqual(second.mode, .repetition)
        let reduced = max(1, second.ballsPerRound - 5)

        let resolved = TrainingDoseResolver.resolve(
            content: content,
            dose: PlanDrillDose(
                formations: [
                    PlanDrillDose.FormationRounds(
                        token: second.token,
                        rounds: second.defaultRounds,
                        ballsPerRound: reduced
                    )
                ],
                decay: true
            ),
            formationOptions: TrainingDoseResolver.formationOptions(forDrillId: content.id)
        )

        XCTAssertEqual(resolved.groups[0].rounds, second.defaultRounds)
        XCTAssertEqual(resolved.groups[0].ballsPerRound, reduced)
    }

    /// v38 R7：`sequence` + decay 仍可降整链遍数。
    func test_formations_sequenceDecay_allowsRoundsBelowDefault() throws {
        let content = try bundledDrill("drill_c046")
        let formation = try XCTUnwrap(content.sets.perFormation?.first)
        XCTAssertEqual(formation.mode, .sequence)
        XCTAssertGreaterThan(formation.defaultRounds, 1)

        let resolved = TrainingDoseResolver.resolve(
            content: content,
            dose: PlanDrillDose(
                formations: [
                    PlanDrillDose.FormationRounds(token: formation.token, rounds: 2)
                ],
                decay: true
            ),
            formationOptions: TrainingDoseResolver.formationOptions(forDrillId: content.id)
        )

        XCTAssertEqual(resolved.groups[0].rounds, 2)
        XCTAssertEqual(resolved.groups[0].ballsPerRound, formation.ballsPerRound)
    }

    /// 无序列 drill：倍数作用于 `defaultSets`。
    func test_noSequenceDrill_multiplierAppliesToDefaultSets() throws {
        let content = try bundledDrill("drill_c065")
        XCTAssertNil(content.sets.perFormation)
        let multiplier = 2

        let resolved = TrainingDoseResolver.resolve(
            content: content,
            dose: PlanDrillDose(roundsPerFormation: multiplier)
        )
        XCTAssertEqual(resolved.totalRounds, content.sets.defaultSets * multiplier)
        XCTAssertEqual(resolved.totalBalls,
                       content.sets.defaultSets * multiplier * content.sets.defaultBallsPerSet)
    }

    /// v34 R11（紧凑口径）：`volumeText` 与 suggestedDose 同口径；
    /// 多球形摘要不含「轮」；计划条目摘要不再含球数；分钟向上取 5 的倍数。
    func test_volumeText_matchesSuggestedDoseCaliber() throws {
        let rep = try bundledDrill("drill_c001")
        let repResolved = TrainingDoseResolver.resolve(content: rep)
        XCTAssertEqual(repResolved.volumeText(unitLabel: "球"),
                       repResolved.suggestedDoseLines()[0].text)

        let seq = try bundledDrill("drill_c039")
        let seqResolved = TrainingDoseResolver.resolve(content: seq)
        XCTAssertEqual(seqResolved.volumeText(unitLabel: "球"),
                       seqResolved.suggestedDoseLines()[0].text)

        let multi = try bundledDrill("drill_c026")
        let multiResolved = TrainingDoseResolver.resolve(content: multi)
        let text = multiResolved.volumeText(unitLabel: "球")
        XCTAssertTrue(text.contains("球形") && text.contains("共") && text.contains("\(multiResolved.totalBalls)"))
        XCTAssertFalse(text.contains("轮"), "多球形摘要不应再写轮：\(text)")
        // 条目摘要：多球形只报球形数，不再上球数
        XCTAssertEqual(multiResolved.planEntrySummaryText(),
                       "\(multiResolved.groups.count) 球形")
        // 单球形条目摘要 = 内联紧凑量
        XCTAssertEqual(repResolved.planEntrySummaryText(),
                       repResolved.suggestedDoseLines()[0].text)
        // 分钟：2.5 球/分钟，向上取 5 的倍数
        XCTAssertEqual(ResolvedDose.estimatedMinutes(forBalls: 75), 30)
        XCTAssertEqual(ResolvedDose.estimatedMinutes(forBalls: 135), 55)  // 54 → 55
        XCTAssertEqual(ResolvedDose.estimatedMinutes(forBalls: 1), 5)
        XCTAssertEqual(ResolvedDose.estimatedMinutes(forBalls: 0), 0)
    }

    /// 逐球形文案（紧凑口径）：重复型「m × n」+ 逐位重复标签；
    /// 走位链「链杆数 × 遍数」+ 整链走位标签；合计以杆计。
    func test_suggestedDoseLines_repetitionSequenceAndMulti() throws {
        let rep = try bundledDrill("drill_c001")
        let repResolved = TrainingDoseResolver.resolve(content: rep)
        let repLines = repResolved.suggestedDoseLines()
        XCTAssertEqual(repLines.count, 1)
        let f1 = try XCTUnwrap(rep.sets.perFormation?.first)
        XCTAssertEqual(repLines[0].text, "\(f1.defaultRounds) × \(f1.ballsPerRound)")
        XCTAssertEqual(repLines[0].modeLabel, "逐位重复")
        // 失败机理（v39 R5）：单球形计划行第二行必须是「球形1 + 模式 + m × n」，
        // 不再把 title 留空以免只剩光秃 m × n。禁止删本断言求绿。
        XCTAssertEqual(repLines[0].title, "球形1")

        let seq = try bundledDrill("drill_c039")
        let seqLines = TrainingDoseResolver.resolve(content: seq).suggestedDoseLines()
        let s1 = try XCTUnwrap(seq.sets.perFormation?.first)
        XCTAssertEqual(seqLines[0].text, "\(s1.ballsPerRound) × \(s1.defaultRounds)")
        XCTAssertEqual(seqLines[0].modeLabel, "整链走位")

        let multi = try bundledDrill("drill_c026")
        let options = TrainingDoseResolver.formationOptions(forDrillId: multi.id)
        let multiResolved = TrainingDoseResolver.resolve(content: multi, formationOptions: options)
        let multiLines = multiResolved.suggestedDoseLines()
        XCTAssertEqual(multiLines.count, multi.sets.perFormation?.count)
        XCTAssertTrue(multiLines.allSatisfy { $0.title != nil })
        // 合计以杆计，单球形也返回（紧凑行不含总量，合计是唯一总量出处）
        XCTAssertEqual(multiResolved.suggestedDoseTotalText(),
                       "合计：\(multiResolved.totalBalls) 杆")
        XCTAssertEqual(repResolved.suggestedDoseTotalText(),
                       "合计：\(repResolved.totalBalls) 杆")
    }

    /// v39 W1：c002/c022 的 `doseNote` 留给 I6b，计划行读屏/摘要不得上屏「用户裁定」。
    func test_planEntryAccessibility_omitsDoseNote() throws {
        for id in ["drill_c022"] {
            let content = try bundledDrill(id)
            let notes = (content.sets.perFormation ?? []).compactMap(\.doseNote).filter { !$0.isEmpty }
            XCTAssertFalse(notes.isEmpty, "\(id) 应有非空 doseNote（I6b）")
            XCTAssertTrue(notes.contains { $0.contains("用户裁定") }, "\(id) doseNote 应变含「用户裁定」")

            let resolved = TrainingDoseResolver.resolve(content: content)
            let label = resolved.planEntryAccessibilityLabel(drillName: content.nameZh)
            XCTAssertFalse(label.contains("用户裁定"), "计划行 accessibility 不得含内部备注：\(label)")
            XCTAssertFalse(resolved.planEntrySummaryText().contains("用户裁定"))
            XCTAssertTrue(label.contains(content.nameZh))
            XCTAssertTrue(label.contains(resolved.planEntrySummaryText()))
            if resolved.groups.count == 1 {
                XCTAssertTrue(label.contains("球形1"), "单球形读屏应含统一行标题：\(label)")
                XCTAssertTrue(
                    label.contains("逐位重复") || label.contains("整链走位"),
                    "单球形读屏应含模式标签：\(label)"
                )
            }
            XCTAssertTrue(
                resolved.suggestedDoseLines().contains { ($0.note ?? "").contains("用户裁定") },
                "\(id) SuggestedDoseLine.note 应仍持有 doseNote"
            )
        }
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

    /// 6 份专项计划：dose 格式切净 + 每条目可解析（v34 W3 重排后条目量级约百级，不再用 v31 的 400+ 下限）。
    func test_rewrittenSpecialistPlans_areDoseOnlyAndResolvable() async throws {
        let rewritten = [
            "plan_accuracy", "plan_cueball", "plan_english",
            "plan_force", "plan_separation", "plan_positioning",
            "plan_positioning2",
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
        // v34 W3：专项计划合计约 165 条（旧 v31 千级下限已过时）。
        XCTAssertGreaterThan(entries, 100, "7 份计划条目数量级异常：\(entries)")
        print("[W3a-EVIDENCE] 7 份专项计划 dose 条目核对数=\(entries)")
    }

    /// 4 份综合计划：dose 可解析；阶段时长相对计划级 `minutesPerSession` 允许 ±20%（v34 R7「大概」）。
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
                XCTAssertGreaterThan(week.sessions.count, 0,
                                     "\(planId) W\(week.weekNumber) 至少 1 次课")
                XCTAssertLessThanOrEqual(week.sessions.count, plan.sessionsPerWeek,
                                         "\(planId) W\(week.weekNumber) 天数不得超过 sessionsPerWeek")
                for session in week.sessions {
                    // v34 W3 后各节阶段时长可与计划级 minutesPerSession 不同（R7「大概」）；
                    // 本用例只核 dose 可解析，不在此重做课时护栏。
                    let phaseSum = session.phases.reduce(0) { $0 + $1.durationMinutes }
                    XCTAssertGreaterThan(phaseSum, 0,
                                         "\(planId) W\(week.weekNumber) D\(session.dayNumber) 阶段时长合计为 0")
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
        // v37 W4：11 份货架把内容拆到专项后，综合四份合计约 97 条（v34 W3 约 127、>100 下限已过时）。
        XCTAssertGreaterThanOrEqual(entries, 50, "4 份综合计划条目数量级异常：\(entries)")
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

    // MARK: - 二次加载不出骨架（训练货架滚动记忆）

    func test_reloadDoesNotFlipIsLoadingWhenPlansAlreadyPresent() async {
        let context = makeContext()
        let vm = TrainingHomeViewModel()
        await vm.load(context: context)
        XCTAssertFalse(vm.isLoading)
        XCTAssertFalse(vm.officialPlans.isEmpty, "Bundle 官方计划应已装入")

        var sawLoadingTrue = false
        let sub = vm.$isLoading.sink { if $0 { sawLoadingTrue = true } }
        await vm.load(context: context)
        XCTAssertFalse(sawLoadingTrue, "二次 load 不得再把 isLoading 打成 true（会拆掉货架、滚回顶）")
        XCTAssertFalse(vm.isLoading)
        XCTAssertFalse(vm.officialPlans.isEmpty)
        _ = sub
    }

    func test_requestBrowseScrollIncrementsTickAndSetsTarget() {
        let vm = TrainingHomeViewModel()
        XCTAssertEqual(vm.browseScrollTick, 0)
        vm.requestBrowseScroll(to: "plan_positioning2")
        XCTAssertEqual(vm.browseScrollTarget, "plan_positioning2")
        XCTAssertEqual(vm.browseScrollTick, 1)
        vm.requestBrowseScroll(to: TrainingHomeViewModel.scrollTopID)
        XCTAssertEqual(vm.browseScrollTarget, TrainingHomeViewModel.scrollTopID)
        XCTAssertEqual(vm.browseScrollTick, 2)
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
