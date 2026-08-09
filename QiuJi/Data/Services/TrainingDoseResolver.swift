import Foundation

// MARK: - Resolved Types

/// 展开后的一组训练：目标球数 + 球形快照。落 `DrillSet` 时冻结（契约 §6.5 / §6.6）。
struct PlannedTrainingSet: Equatable {
    /// 本组所属球形。单球形 drill 为 nil（契约 §4.1）。
    let formationToken: String?
    /// 球形显示名，取自序列文件（`DrillTryoutBoardStore`），随组次一起快照。
    let formationName: String?
    /// 本组目标球数 = 该球形的 `ballsPerRound`。
    let targetBalls: Int
    /// 该球形的训练模式，仅用于展示单位（`sequence` 型一轮 = 打完序列全部杆）。
    let mode: DrillContent.DoseMode?

    /// 同构组序列（无球形维度）的便捷构造，供预览 / 旧格式路径使用。
    static func uniform(rounds: Int, targetBalls: Int) -> [PlannedTrainingSet] {
        guard rounds > 0 else { return [] }
        return (0..<rounds).map { _ in
            PlannedTrainingSet(formationToken: nil, formationName: nil,
                               targetBalls: targetBalls, mode: nil)
        }
    }
}

/// 一条 drill 在一次训练中的完整剂量解析结果（v31 R3/R4/R6）。
struct ResolvedDose: Equatable {

    /// 一个球形的剂量块：练 `rounds` 轮，每轮 `ballsPerRound` 球。
    struct Group: Equatable {
        let formationToken: String?
        let formationName: String?
        let mode: DrillContent.DoseMode?
        let ballsPerRound: Int
        let rounds: Int
    }

    let groups: [Group]

    /// 组序列：球形 1 轮 1 → 球形 1 轮 2 → … → 球形 N 轮 M（v31 R6 展开顺序）。
    var plannedSets: [PlannedTrainingSet] {
        groups.flatMap { group in
            (0..<group.rounds).map { _ in
                PlannedTrainingSet(
                    formationToken: group.formationToken,
                    formationName: group.formationName,
                    targetBalls: group.ballsPerRound,
                    mode: group.mode
                )
            }
        }
    }

    var totalRounds: Int { groups.reduce(0) { $0 + $1.rounds } }

    var totalBalls: Int { groups.reduce(0) { $0 + $1.rounds * $1.ballsPerRound } }

    /// 各球形每轮球数是否一致（异构时展示层不能再写「N 组 × N 球」）。
    var isUniform: Bool {
        guard let first = groups.first else { return true }
        return groups.allSatisfy {
            $0.ballsPerRound == first.ballsPerRound && $0.mode == first.mode
        }
    }

    /// 一轮的单位：`sequence` 型一轮就是按序打完整条序列，故以「杆」计；
    /// 其余跟 `unitLabel` 口径（契约 §5.2：球 / 局 / 次）。
    private func unit(for group: Group, unitLabel: String) -> String {
        group.mode == .sequence ? "杆" : unitLabel
    }

    /// 完整展示文案。同构：「4 轮 × 10 球」；异构多球形：「2 球形 · 4 轮 · 共 23 球」。
    func volumeText(unitLabel: String) -> String {
        guard let first = groups.first else { return "" }
        if isUniform {
            return "\(totalRounds) 轮 × \(first.ballsPerRound) \(unit(for: first, unitLabel: unitLabel))"
        }
        return "\(groups.count) 球形 · \(totalRounds) 轮 · 共 \(totalBalls) \(unitLabel)"
    }

    /// 窄行用紧凑文案（计划详情逐条目）：同构「4×10」；异构「4轮·23」。
    var compactVolumeText: String {
        guard let first = groups.first else { return "" }
        if isUniform { return "\(totalRounds)×\(first.ballsPerRound)" }
        return "\(totalRounds)轮·\(totalBalls)"
    }
}

// MARK: - Resolver

/// 计划剂量（`dose`）× drill 内容（`sets.perFormation`）→ 组序列（契约 §6.6）。
///
/// drill JSON 是训练剂量唯一真源，计划只存强度系数；实际球数在**激活训练时**解析，
/// 落 `DrillSet` 时才快照冻结（§6.6「为什么这不违反 §6.5」）。
enum TrainingDoseResolver {

    /// 多球形 drill 的可选球形；单球形（或无序列）返回空数组 —— 单球形不出选择 UI，
    /// `DrillSet.formationToken/Name` 保持 nil（契约 §4.1）。
    static func formationOptions(forDrillId drillId: String,
                                 bundle: Bundle = .main) -> [DrillFormationOption] {
        let formations = DrillTryoutBoardStore.formations(for: drillId, bundle: bundle)
        guard formations.count > 1 else { return [] }
        return formations.map { DrillFormationOption(token: $0.token, name: $0.title) }
    }

    /// - Parameters:
    ///   - content: drill 内容（剂量真源）。缺失时只能走汇总兜底。
    ///   - dose: 计划条目的强度系数。自由训练传 nil ⇒ 用内容推荐轮数。
    ///   - formationOptions: 球形显示名来源；只影响 `formationName`，不影响球数。
    static func resolve(
        content: DrillContent?,
        dose: PlanDrillDose? = nil,
        formationOptions: [DrillFormationOption] = []
    ) -> ResolvedDose {
        let config = content?.sets

        // 1) 剂量真源路径：逐球形展开。
        if let perFormation = config?.perFormation, !perFormation.isEmpty {
            let selected = selectFormations(perFormation, dose: dose)
            if !selected.isEmpty {
                // 单球形一律不带 token（契约 §4.1）；多球形才逐组快照球形身份。
                let carriesToken = selected.count > 1 || formationOptions.count > 1
                var names: [String: String] = [:]
                for option in formationOptions { names[option.token] = option.name }
                return ResolvedDose(groups: selected.map { formation, rounds in
                    ResolvedDose.Group(
                        formationToken: carriesToken ? formation.token : nil,
                        formationName: carriesToken ? names[formation.token] : nil,
                        mode: formation.mode,
                        ballsPerRound: max(1, formation.ballsPerRound),
                        rounds: max(1, rounds)
                    )
                })
            }
        }

        // 2) 汇总兜底：无序列 drill（契约 §5.6.4，8 条）或内容缺失。
        return uniformDose(
            rounds: dose?.roundsPerFormation ?? config?.defaultSets ?? 1,
            ballsPerRound: config?.defaultBallsPerSet ?? 1,
            formationOptions: formationOptions
        )
    }

    /// 计划 dose 决定每个球形练几轮：按球形逐条 > 统一轮数 > 内容推荐轮数。
    /// 顺序一律以内容 `perFormation` 的顺序为准（球形即难度阶梯，契约 §6.6 推论 2）。
    private static func selectFormations(
        _ perFormation: [DrillContent.FormationDose],
        dose: PlanDrillDose?
    ) -> [(DrillContent.FormationDose, Int)] {
        if let listed = dose?.formations, !listed.isEmpty {
            var roundsByToken: [String: Int] = [:]
            for entry in listed { roundsByToken[entry.token] = entry.rounds }
            // 未列出的球形本次不展开（契约 §6.6 推论 3）。
            return perFormation.compactMap { formation in
                roundsByToken[formation.token].map { (formation, $0) }
            }
        }
        if let uniformRounds = dose?.roundsPerFormation {
            return perFormation.map { ($0, uniformRounds) }
        }
        return perFormation.map { ($0, $0.defaultRounds) }
    }

    private static func uniformDose(
        rounds: Int,
        ballsPerRound: Int,
        formationOptions: [DrillFormationOption]
    ) -> ResolvedDose {
        ResolvedDose(groups: [
            ResolvedDose.Group(
                formationToken: formationOptions.first?.token,
                formationName: formationOptions.first?.name,
                mode: nil,
                ballsPerRound: max(1, ballsPerRound),
                rounds: max(1, rounds)
            )
        ])
    }
}
