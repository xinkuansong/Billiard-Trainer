import Foundation
import OSLog

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

/// 动作页「建议训练量」逐行文案（v34 R10，紧凑口径见 v34 后续展示层收敛）。
struct SuggestedDoseLine: Equatable {
    /// 多球形时的行首标签（如「球形1」）；单球形 / 汇总兜底为 nil。
    let title: String?
    /// 模式标签：「逐位重复」/「整链走位」；无序列汇总兜底为 nil。
    let modeLabel: String?
    /// 紧凑主文案：重复型「8 × 15」（位置 × 每位置颗数）、
    /// 走位链「10 × 8」（整链杆数 × 遍数），模式区分交给 `modeLabel`。
    let text: String
    /// 可选例外说明（内容侧 `doseNote`）。
    let note: String?
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
        /// 内容侧例外说明；展示用，不影响球数。
        let doseNote: String?

        init(
            formationToken: String?,
            formationName: String?,
            mode: DrillContent.DoseMode?,
            ballsPerRound: Int,
            rounds: Int,
            doseNote: String? = nil
        ) {
            self.formationToken = formationToken
            self.formationName = formationName
            self.mode = mode
            self.ballsPerRound = ballsPerRound
            self.rounds = rounds
            self.doseNote = doseNote
        }
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

    /// 完整展示文案（v34 R10/R11 紧凑口径）。
    /// 单球形：与 `suggestedDoseLines` 同行（m × n）；多球形：「N 球形 · 共 M 球」。
    func volumeText(unitLabel: String) -> String {
        guard let first = groups.first else { return "" }
        if groups.count == 1 {
            return Self.suggestedLineText(for: first)
        }
        return "\(groups.count) 球形 · 共 \(totalBalls) \(unitLabel)"
    }

    /// 窄行紧凑文案：单球形「75球」/「8杆×8」；多球形「2球形·150球」。
    var compactVolumeText: String {
        guard let first = groups.first else { return "" }
        if groups.count > 1 {
            return "\(groups.count)球形·\(totalBalls)球"
        }
        switch first.mode {
        case .sequence:
            return "\(first.ballsPerRound)杆×\(first.rounds)"
        case .repetition:
            return "\(first.rounds)×\(first.ballsPerRound)"
        case .none:
            return "\(totalRounds)×\(first.ballsPerRound)"
        }
    }

    /// 计划条目摘要（动作名由调用方拼接）：单球形直接内联「m × n」，
    /// 多球形只报「N 球形」——球数不再上条目行（v34 后续展示层收敛）。
    func planEntrySummaryText() -> String {
        guard let first = groups.first else { return "" }
        if groups.count == 1 {
            return Self.suggestedLineText(for: first)
        }
        return "\(groups.count) 球形"
    }

    /// 球数 → 分钟（R7 固定 2.5 球/分钟），向上取 5 的整数倍。
    static func estimatedMinutes(forBalls balls: Int) -> Int {
        guard balls > 0 else { return 0 }
        let raw = Double(balls) / 2.5
        return Int((raw / 5).rounded(.up)) * 5
    }

    /// 「建议训练量」逐球形文案（v34 R10）。无序列汇总兜底仍返回单行。
    func suggestedDoseLines() -> [SuggestedDoseLine] {
        guard !groups.isEmpty else { return [] }
        let multi = groups.count > 1
        return groups.enumerated().map { index, group in
            // 展示名统一序号制映射（groups 保持内容声明顺序 = 序列文件稳定顺序），
            // 不透出内容生产期的任意原始名（如「… · 球形4」）。
            let title: String? = multi ? "球形\(index + 1)" : nil
            return SuggestedDoseLine(
                title: title,
                modeLabel: Self.modeLabel(for: group.mode),
                text: Self.suggestedLineText(for: group),
                note: group.doseNote
            )
        }
    }

    /// 末行合计：紧凑行不再含总量，合计一律以「杆」（击打次数）计。
    /// 计划页不出合计，仅动作页调用。
    func suggestedDoseTotalText() -> String? {
        guard !groups.isEmpty else { return nil }
        return "合计：\(totalBalls) 杆"
    }

    private static func modeLabel(for mode: DrillContent.DoseMode?) -> String? {
        switch mode {
        case .repetition: return "逐位重复"
        case .sequence: return "整链走位"
        case .none: return nil
        }
    }

    /// 紧凑量文案：重复型「位置数 × 每位置颗数」、走位链「整链杆数 × 遍数」。
    private static func suggestedLineText(for group: Group) -> String {
        switch group.mode {
        case .sequence:
            return "\(group.ballsPerRound) × \(group.rounds)"
        default:
            return "\(group.rounds) × \(group.ballsPerRound)"
        }
    }
}

// MARK: - Resolver

/// 计划剂量（`dose`）× drill 内容（`sets.perFormation`）→ 组序列（契约 §6.6）。
///
/// drill JSON 是训练剂量唯一真源，计划只存强度系数；实际球数在**激活训练时**解析，
/// 落 `DrillSet` 时才快照冻结（§6.6「为什么这不违反 §6.5」）。
///
/// v34 R9（B 方案）：`roundsPerFormation` = **遍数倍数**（默认 1），展开 =
/// 每球形 `defaultRounds × 倍数`，位置永远全覆盖。`formations[].rounds` 不得低于
/// 内容 `defaultRounds`（低于时运行时钳到下限并打 debug log）。
enum TrainingDoseResolver {

    private static let logger = Logger(subsystem: "com.billiardtrainer", category: "TrainingDose")

    /// 多球形 drill 的可选球形；单球形（或无序列）返回空数组 —— 单球形不出选择 UI，
    /// `DrillSet.formationToken/Name` 保持 nil（契约 §4.1）。
    static func formationOptions(forDrillId drillId: String,
                                 bundle: Bundle = .main) -> [DrillFormationOption] {
        let formations = DrillTryoutBoardStore.formations(for: drillId, bundle: bundle)
        guard formations.count > 1 else { return [] }
        return formations.map {
            DrillFormationOption(token: $0.token, name: $0.title, displayName: $0.displayName)
        }
    }

    /// - Parameters:
    ///   - content: drill 内容（剂量真源）。缺失时只能走汇总兜底。
    ///   - dose: 计划条目的强度系数。自由训练传 nil ⇒ 用内容推荐轮数（×1）。
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
                        rounds: max(1, rounds),
                        doseNote: formation.doseNote
                    )
                })
            }
        }

        // 2) 汇总兜底：无序列 drill（契约 §5.6.4，8 条）或内容缺失。
        //    `roundsPerFormation` = 倍数；nil dose ⇒ ×1 = 完整 `defaultSets`。
        let multiplier = max(1, dose?.roundsPerFormation ?? 1)
        let baseRounds = config?.defaultSets ?? 1
        return uniformDose(
            rounds: baseRounds * multiplier,
            ballsPerRound: config?.defaultBallsPerSet ?? 1,
            formationOptions: formationOptions
        )
    }

    /// 计划 dose 决定每个球形练几轮：
    /// - `formations`：按 token 选球形；轮数不得低于内容 `defaultRounds`（v34 R9）。
    /// - `roundsPerFormation`：**遍数倍数**，每球形 = `defaultRounds × 倍数`（位置全覆盖）。
    /// - 无 dose：内容推荐完整剂量。
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
                guard let requested = roundsByToken[formation.token] else { return nil }
                let floor = max(1, formation.defaultRounds)
                let clamped = max(floor, requested)
                if clamped != requested {
                    logger.debug(
                        "formations rounds clamped token=\(formation.token, privacy: .public) requested=\(requested) floor=\(floor)"
                    )
                }
                return (formation, clamped)
            }
        }
        if let multiplier = dose?.roundsPerFormation {
            let m = max(1, multiplier)
            return perFormation.map { ($0, max(1, $0.defaultRounds) * m) }
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
                rounds: max(1, rounds),
                doseNote: nil
            )
        ])
    }
}
