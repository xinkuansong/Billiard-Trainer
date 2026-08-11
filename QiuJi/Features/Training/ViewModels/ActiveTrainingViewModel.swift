import Foundation
import SwiftUI
import SwiftData
import UIKit
import AudioToolbox

// MARK: - Supporting Types

struct ActiveDrill: Identifiable {
    let id: UUID
    let drillId: String
    let nameZh: String
    let description: String
    let coachingPoints: [String]
    /// 展开后的组序列（球形 1 轮 1 → … → 球形 N 轮 M，v31 R6）。异构多球形时逐组球数不同。
    let plannedSets: [PlannedTrainingSet]
    let phaseType: String
    let phaseZh: String
    let animation: DrillAnimation?
    let level: DrillLevel?
    /// 内容分类，决定录入单位语义（契约 §5.2）。内容缺失时为空串。
    let category: String
    let subcategory: String
    /// 达标说明原文，保存时快照进 `DrillEntry.criteriaText`（契约 §6.5）。
    let standardCriteria: String

    /// made/target 的单位（契约 §5.2："球" | "局" | "次"）。
    var unitLabel: String {
        DrillUnitLabel.label(category: category, subcategory: subcategory)
    }

    /// 组数 = 展开后的组序列长度。
    var sets: Int { plannedSets.count }
    /// 首组球数。异构多球形下**不代表全部组**，仅供「加一组」等回落场景。
    var ballsPerSet: Int { plannedSets.first?.targetBalls ?? 0 }

    init(
        drillId: String,
        nameZh: String,
        description: String = "",
        coachingPoints: [String] = [],
        plannedSets: [PlannedTrainingSet],
        phaseType: String = "free",
        phaseZh: String = "自由训练",
        animation: DrillAnimation? = nil,
        level: DrillLevel? = nil,
        category: String = "",
        subcategory: String = "",
        standardCriteria: String = ""
    ) {
        self.id = UUID()
        self.drillId = drillId
        self.nameZh = nameZh
        self.description = description
        self.coachingPoints = coachingPoints
        self.plannedSets = plannedSets
        self.phaseType = phaseType
        self.phaseZh = phaseZh
        self.animation = animation
        self.level = level
        self.category = category
        self.subcategory = subcategory
        self.standardCriteria = standardCriteria
    }

    /// 同构组序列的便捷构造（无球形维度）：预览与不涉及球形的场景用。
    init(
        drillId: String,
        nameZh: String,
        description: String = "",
        coachingPoints: [String] = [],
        sets: Int,
        ballsPerSet: Int,
        phaseType: String = "free",
        phaseZh: String = "自由训练",
        animation: DrillAnimation? = nil,
        level: DrillLevel? = nil,
        category: String = "",
        subcategory: String = "",
        standardCriteria: String = ""
    ) {
        self.init(
            drillId: drillId,
            nameZh: nameZh,
            description: description,
            coachingPoints: coachingPoints,
            plannedSets: PlannedTrainingSet.uniform(rounds: sets, targetBalls: ballsPerSet),
            phaseType: phaseType,
            phaseZh: phaseZh,
            animation: animation,
            level: level,
            category: category,
            subcategory: subcategory,
            standardCriteria: standardCriteria
        )
    }
}

/// 录入单位语义（契约 §5.2，只影响展示文案，不参与任何计算）。
///
/// 取值依据是各 drill `standardCriteria` 原文里的量词，不是猜测：
/// - `ghostGame`（c065）原文「10 局 Ghost Game 中赢 3 局以上」→「局」；
/// - `runOut` / `nineBallClear` / `comboPosition` / `keyBall`（c037/c039/c064/c067/c068）
///   原文以「10 组中 N 组…」计，`breakShot` / `clearance` / `safety` / `escape`
///   （c060/c061/c066/c070）原文以「10 次…中 N 次」计 → 统一为「次」
///   （契约 §5.2 只允许 球/局/次 三值，「组」归入「次」）；
/// - 其余（含 `snakeDrill` / `advancedSnake`，原文为「8 球或 10 球蛇彩连续完成 6 颗以上」）
///   均以球计 →「球」。
enum DrillUnitLabel {
    static func label(category: String, subcategory: String) -> String {
        switch subcategory {
        case "ghostGame":
            return "局"
        case "runOut", "nineBallClear", "comboPosition", "keyBall",
             "breakShot", "clearance", "safety", "escape":
            return "次"
        default:
            return "球"
        }
    }
}

enum TrainingMode: Identifiable {
    /// `planId` = 当前激活计划的 `UserActivePlan.planId`（官方计划 id 或自定义计划 UUID 串）。
    /// 落 `TrainingSession.planId`，是「按完成推进计划」的判定依据。
    case plan(drills: [TodayDrillItem], planId: String?)
    case free

    var id: String {
        switch self {
        case .plan: return "plan"
        case .free: return "free"
        }
    }

    var planId: String? {
        switch self {
        case .plan(_, let planId): return planId
        case .free: return nil
        }
    }
}

enum TrainingPhase: Equatable {
    case active
    case note
    case summary
}

struct DrillSummary: Identifiable {
    let id: UUID
    let drillId: String
    let nameZh: String
    let level: DrillLevel?
    let totalBallsMade: Int
    let totalBallsPossible: Int
    let sets: [SetResult]

    struct SetResult: Identifiable {
        let id: Int
        let madeBalls: Int
        let targetBalls: Int
    }

    var successRate: Double {
        guard totalBallsPossible > 0 else { return 0 }
        return Double(totalBallsMade) / Double(totalBallsPossible)
    }
}

// MARK: - ViewModel

@MainActor
final class ActiveTrainingViewModel: ObservableObject {
    let mode: TrainingMode

    @Published var drills: [ActiveDrill] = []
    @Published var currentDrillIndex: Int = 0
    @Published var elapsedSeconds: Int = 0
    @Published var isTimerRunning: Bool = false
    @Published var isTimerSkipped: Bool = false
    @Published var isLoading: Bool = true
    @Published var showDrillPicker: Bool = false
    @Published var showEndConfirm: Bool = false
    @Published var trainingPhase: TrainingPhase = .active
    @Published var trainingNote: String = ""
    @Published var saveError: String?
    @Published var didSaveSuccessfully: Bool = false
    @Published var showingOverview: Bool = true

    // Recording state per drill
    @Published var drillSetsData: [[DrillSetData]] = []
    @Published var drillNotes: [String] = []
    /// 每个 drill 的可选球形（多球形 drill 才非空；单球形不出选择 UI）。
    @Published var drillFormations: [[DrillFormationOption]] = []

    // Rest timer
    @Published var restDuration: Int = 60
    @Published var restSecondsRemaining: Int = 0
    @Published var isRestTimerActive: Bool = false
    @Published var restTotalSeconds: Int = 0

    private var timerTask: Task<Void, Never>?
    private var restTimer: DispatchSourceTimer?
    private var pendingDrillAdvance: Int?
    private let liveActivityManager = RestTimerLiveActivityManager.shared

    private var hasLoaded = false
    private var timerStartDate: Date?
    private var accumulatedBeforePause: Int = 0
    private var restEndDate: Date?

    var currentDrill: ActiveDrill? {
        guard !drills.isEmpty, currentDrillIndex >= 0, currentDrillIndex < drills.count else { return nil }
        return drills[currentDrillIndex]
    }

    var formattedTime: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    var progressText: String {
        guard !drills.isEmpty else { return "" }
        let completedSets = drillSetsData.flatMap { $0 }.filter { $0.isCompleted }.count
        let totalSetsCount = drillSetsData.flatMap { $0 }.count
        return "\(completedSets)/\(totalSetsCount) 组 \(currentDrillIndex + 1)/\(drills.count) 项目"
    }

    /// 当前动作三级进度（v34 R12，杆位口径）：
    /// 重复型「球形 x/y · 第 m/n 杆 · 第 k 颗」（一杆 = 一个位置，重复打 k 颗）；
    /// 走位链「球形 x/y · 第 r 遍 · 第 k/n 杆」（整链第 r 遍，链内第 k 杆）；
    /// 单球形不显示「球形 x/y」。
    var currentSetProgressText: String {
        guard currentDrillIndex < drills.count,
              currentDrillIndex < drillSetsData.count else { return "" }
        let sets = drillSetsData[currentDrillIndex]
        guard !sets.isEmpty else { return "" }
        let activeIdx = sets.firstIndex(where: { !$0.isCompleted }) ?? (sets.count - 1)
        let active = sets[activeIdx]
        let mode = modeForSet(drillIndex: currentDrillIndex, setIndex: activeIdx)

        let formationKeys = orderedFormationKeys(in: sets)
        let multiFormation = formationKeys.count > 1

        var parts: [String] = []
        let key = formationKey(active)
        if multiFormation, let fi = formationKeys.firstIndex(of: key) {
            parts.append("球形 \(fi + 1)/\(formationKeys.count)")
        }
        let peers = sets.indices.filter { formationKey(sets[$0]) == key }
        let ordinal = (peers.firstIndex(of: activeIdx) ?? 0) + 1

        if mode == .sequence {
            parts.append("第 \(ordinal) 遍")
            let shotNumber = min(max(active.madeBalls + 1, 1), max(active.targetBalls, 1))
            parts.append("第 \(shotNumber)/\(max(active.targetBalls, 1)) 杆")
            return parts.joined(separator: " · ")
        }

        parts.append("第 \(ordinal)/\(peers.count) 杆")
        let ballNumber = min(max(active.madeBalls + 1, 1), max(active.targetBalls, 1))
        parts.append("第 \(ballNumber) 颗")
        return parts.joined(separator: " · ")
    }

    private func modeForSet(drillIndex: Int, setIndex: Int) -> DrillContent.DoseMode? {
        // 录入行自带 mode（makeSetData / addSet 均写入）；手动加组插入分节内后
        // 行序 ≠ plannedSets 序，禁止再按下标映射回 plannedSets。
        let sets = drillSetsData[drillIndex]
        if let mode = sets[setIndex].mode { return mode }
        // 兜底：同 token 最近一条计划组，再回落末组。
        let planned = drills[drillIndex].plannedSets
        let token = sets[setIndex].formationToken
        if let match = planned.last(where: { $0.formationToken == token }) {
            return match.mode
        }
        return planned.last?.mode
    }

    private func formationKey(_ set: DrillSetData) -> String {
        set.formationToken ?? "_single"
    }

    private func orderedFormationKeys(in sets: [DrillSetData]) -> [String] {
        var seen: [String] = []
        for set in sets {
            let key = formationKey(set)
            if !seen.contains(key) { seen.append(key) }
        }
        return seen
    }

    var progress: Double {
        guard !drills.isEmpty else { return 0 }
        let allSets = drillSetsData.flatMap { $0 }
        guard !allSets.isEmpty else { return 0 }
        return Double(allSets.filter { $0.isCompleted }.count) / Double(allSets.count)
    }

    var isPlanMode: Bool {
        if case .plan = mode { return true }
        return false
    }

    init(mode: TrainingMode) {
        self.mode = mode
    }

    // MARK: - Data Loading

    func loadDrills() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        isLoading = true
        defer { isLoading = false }

        switch mode {
        case .plan(let todayDrills, _):
            let service = DrillContentService.shared
            var items: [ActiveDrill] = []
            for item in todayDrills where !item.isCompleted {
                let content = await service.loadDrillFromBundle(id: item.drillId)
                items.append(ActiveDrill(
                    drillId: item.drillId,
                    nameZh: item.nameZh,
                    description: content?.description ?? "",
                    coachingPoints: content?.coachingPoints ?? [],
                    plannedSets: item.plannedSets,
                    phaseType: item.phaseType,
                    phaseZh: item.phaseZh,
                    animation: content?.animation,
                    level: content.flatMap { DrillLevel(rawValue: $0.level) },
                    category: content?.category ?? "",
                    subcategory: content?.subcategory ?? "",
                    standardCriteria: content?.standardCriteria ?? ""
                ))
            }
            drills = items

        case .free:
            // 自由模式允许进入前已预置动作（UITest deeplink / 外部注入）。
            // ⛔ 不得清空，否则与 View `.task` 竞态会抹掉预置项。
            break
        }
        // 计划模式总是重建；自由模式仅在尚未建立录入行时初始化（避免抹掉 addDrill 已写入的行）。
        if case .free = mode, !drills.isEmpty, drillSetsData.count == drills.count {
            return
        }
        initializeRecords()
    }

    // MARK: - Timer

    func startTimer() {
        guard !isTimerSkipped, !isTimerRunning else { return }
        isTimerRunning = true
        timerStartDate = Date()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                self?.recalculateElapsed()
            }
        }
    }

    func pauseTimer() {
        isTimerRunning = false
        timerTask?.cancel()
        timerTask = nil
        recalculateElapsed()
        accumulatedBeforePause = elapsedSeconds
        timerStartDate = nil
    }

    private func recalculateElapsed() {
        guard let start = timerStartDate else { return }
        elapsedSeconds = accumulatedBeforePause + Int(Date().timeIntervalSince(start))
    }

    func refreshTimers() {
        if isTimerRunning {
            recalculateElapsed()
        }
        if isRestTimerActive, let end = restEndDate {
            let remaining = Int(ceil(end.timeIntervalSinceNow))
            if remaining <= 0 {
                restSecondsRemaining = 0
                onRestComplete()
            } else {
                restSecondsRemaining = remaining
            }
        }
    }

    func toggleTimer() {
        isTimerRunning ? pauseTimer() : startTimer()
    }

    func skipTimer() {
        pauseTimer()
        isTimerSkipped = true
    }

    func unskipTimer() {
        isTimerSkipped = false
    }

    // MARK: - Drill Navigation

    func goToDrill(at index: Int) {
        guard index >= 0, index < drills.count else { return }
        currentDrillIndex = index
    }

    // MARK: - Free Mode: Add / Remove Drills

    func addDrill(_ content: DrillContent) {
        guard !drills.contains(where: { $0.drillId == content.id }) else { return }
        let formations = Self.formationOptions(for: content.id)
        // 自由训练无计划 dose ⇒ 用内容推荐轮数逐球形展开（契约 §5.6 / §6.6）。
        let resolved = TrainingDoseResolver.resolve(content: content, formationOptions: formations)
        let drill = ActiveDrill(
            drillId: content.id,
            nameZh: content.nameZh,
            description: content.description,
            coachingPoints: content.coachingPoints,
            plannedSets: resolved.plannedSets,
            animation: content.animation,
            level: DrillLevel(rawValue: content.level),
            category: content.category,
            subcategory: content.subcategory,
            standardCriteria: content.standardCriteria
        )
        drills.append(drill)
        drillSetsData.append(Self.makeSetData(for: drill))
        drillNotes.append("")
        drillFormations.append(formations)
    }

    /// Remove the first matching free-mode drill by content id (picker toggle deselect).
    func removeDrill(drillId: String) {
        guard let index = drills.firstIndex(where: { $0.drillId == drillId }) else { return }
        removeDrill(at: IndexSet(integer: index))
    }

    func removeDrill(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            drills.remove(at: index)
            if index < drillSetsData.count { drillSetsData.remove(at: index) }
            if index < drillNotes.count { drillNotes.remove(at: index) }
            if index < drillFormations.count { drillFormations.remove(at: index) }
        }
        if currentDrillIndex >= drills.count {
            currentDrillIndex = max(0, drills.count - 1)
        }
    }

    // MARK: - Recording

    private func initializeRecords() {
        drillFormations = drills.map { Self.formationOptions(for: $0.drillId) }
        drillSetsData = drills.map { Self.makeSetData(for: $0) }
        drillNotes = drills.map { _ in "" }
    }

    /// 组序列 → 录入行：逐组带上该组所属球形与目标球数（v31 R6，替代「全部预填第一个球形」）。
    /// v34 后续：重复型组补真实杆位 `shotIndex`（遍数倍数 >1 时杆位按序列长度循环）；
    /// 计划自带的多球形组锁定球形列（球形是计划既定事实，不可改选）。
    private static func makeSetData(for drill: ActiveDrill) -> [DrillSetData] {
        let stepCounts = sequenceStepCounts(for: drill.drillId)
        var ordinalByToken: [String: Int] = [:]
        return drill.plannedSets.enumerated().map { index, planned in
            let key = planned.formationToken ?? ""
            let ordinal = (ordinalByToken[key] ?? 0) + 1
            ordinalByToken[key] = ordinal
            var shotIndex: Int?
            if planned.mode == .repetition {
                if let count = stepCounts[key], count > 0 {
                    shotIndex = (ordinal - 1) % count + 1
                } else {
                    shotIndex = ordinal
                }
            }
            return DrillSetData(
                id: index + 1,
                targetBalls: planned.targetBalls,
                isWarmup: drill.phaseType == "warmup" && index == 0,
                formationToken: planned.formationToken,
                formationName: planned.formationName,
                mode: planned.mode,
                shotIndex: shotIndex,
                isFormationLocked: planned.formationToken != nil
            )
        }
    }

    /// token → 序列杆数（重复型 = 可选位置数）。单球形旧式文件 token 为空串。
    private static func sequenceStepCounts(for drillId: String) -> [String: Int] {
        var counts: [String: Int] = [:]
        for formation in DrillTryoutBoardStore.formations(for: drillId) {
            counts[formation.token] = formation.stepCount
        }
        return counts
    }

    /// 多球形 drill 的可选球形；单球形（或无序列）返回空数组 —— 单球形不出选择 UI，
    /// `DrillSet.formationToken/Name` 保持 nil（契约 §4.1）。
    static func formationOptions(for drillId: String) -> [DrillFormationOption] {
        TrainingDoseResolver.formationOptions(forDrillId: drillId)
    }

    var currentSetIndex: Int {
        guard currentDrillIndex < drillSetsData.count else { return 0 }
        return drillSetsData[currentDrillIndex].firstIndex(where: { !$0.isCompleted })
            ?? drillSetsData[currentDrillIndex].count
    }

    var currentBallsMade: Int {
        guard currentDrillIndex < drillSetsData.count else { return 0 }
        let sets = drillSetsData[currentDrillIndex]
        guard let activeIdx = sets.firstIndex(where: { !$0.isCompleted }) else { return 0 }
        return sets[activeIdx].madeBalls
    }

    var isCurrentDrillAllSetsCompleted: Bool {
        guard currentDrillIndex < drillSetsData.count else { return false }
        let sets = drillSetsData[currentDrillIndex]
        return !sets.isEmpty && sets.allSatisfy { $0.isCompleted }
    }

    func incrementBalls() {
        guard currentDrillIndex < drillSetsData.count else { return }
        guard let activeIdx = drillSetsData[currentDrillIndex].firstIndex(where: { !$0.isCompleted }) else { return }
        let target = drillSetsData[currentDrillIndex][activeIdx].targetBalls
        if drillSetsData[currentDrillIndex][activeIdx].madeBalls < target {
            drillSetsData[currentDrillIndex][activeIdx].madeBalls += 1
        }
    }

    func decrementBalls() {
        guard currentDrillIndex < drillSetsData.count else { return }
        guard let activeIdx = drillSetsData[currentDrillIndex].firstIndex(where: { !$0.isCompleted }) else { return }
        if drillSetsData[currentDrillIndex][activeIdx].madeBalls > 0 {
            drillSetsData[currentDrillIndex][activeIdx].madeBalls -= 1
        }
    }

    func completeCurrentSet() {
        guard currentDrillIndex < drillSetsData.count else { return }
        guard let activeIdx = drillSetsData[currentDrillIndex].firstIndex(where: { !$0.isCompleted }) else { return }
        drillSetsData[currentDrillIndex][activeIdx].isCompleted = true

        if drillSetsData[currentDrillIndex].allSatisfy({ $0.isCompleted }) {
            if currentDrillIndex < drills.count - 1 {
                currentDrillIndex += 1
            }
        }
    }

    func completeSet(drillIndex: Int, setIndex: Int) {
        guard drillIndex < drillSetsData.count,
              setIndex < drillSetsData[drillIndex].count else { return }
        let wasCompleted = drillSetsData[drillIndex][setIndex].isCompleted
        // F-AT-02: animate completion / active-bar handoff
        withAnimation(BTMotion.easeFast) {
            drillSetsData[drillIndex][setIndex].isCompleted.toggle()
        }

        guard !wasCompleted else { return }

        // F-AT-11: light haptic only on incomplete → complete (no sound expansion)
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.prepare()
        impact.impactOccurred()

        if drillSetsData[drillIndex].allSatisfy({ $0.isCompleted }) {
            if drillIndex < drills.count - 1 {
                pendingDrillAdvance = drillIndex + 1
            }
        }

        if restDuration > 0 {
            startRestTimer()
        } else if let next = pendingDrillAdvance {
            pendingDrillAdvance = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.currentDrillIndex = next
            }
        }
    }

    func addSet(drillIndex: Int) {
        guard drillIndex < drillSetsData.count, drillIndex < drills.count else { return }
        let sets = drillSetsData[drillIndex]
        // R12：复制「当前位置」（首个未完成组）；全部完成后回落末组。
        // 重复型 = 再打同位置一局（同 token / 同球数）；走位链 = 再打一遍整链。
        let source = sets.first(where: { !$0.isCompleted }) ?? sets.last
        let nextId = (sets.map(\.id).max() ?? 0) + 1
        let target = source?.targetBalls ?? drills[drillIndex].ballsPerSet
        drillSetsData[drillIndex].append(DrillSetData(
            id: nextId,
            targetBalls: target,
            formationToken: source?.formationToken,
            formationName: source?.formationName,
            mode: source?.mode,
            shotIndex: source?.shotIndex
        ))
    }

    /// 结构化加组（v34 后续）：用户指定球形（多球形）与杆号（重复型）。
    /// 新组插到同球形分节末尾（保持分节完整），而不是整表末尾。
    func addSet(drillIndex: Int, choice: DrillAddSetChoice, shotIndex: Int?) {
        guard drillIndex < drillSetsData.count, drillIndex < drills.count else { return }
        let sets = drillSetsData[drillIndex]
        let nextId = (sets.map(\.id).max() ?? 0) + 1
        let newSet = DrillSetData(
            id: nextId,
            targetBalls: choice.targetBalls,
            formationToken: choice.token,
            formationName: choice.name,
            mode: choice.mode,
            shotIndex: choice.mode == .repetition ? shotIndex : nil
        )
        if let lastIndex = sets.lastIndex(where: { $0.formationToken == choice.token }) {
            drillSetsData[drillIndex].insert(newSet, at: lastIndex + 1)
        } else {
            drillSetsData[drillIndex].append(newSet)
        }
    }

    /// 「添加一组」可选目标：按计划组序列聚合出每球形一项（保序），
    /// 附模式、序列杆数与默认目标球数。无球形/模式信息（自由记录旧格式）返回空。
    func addSetChoices(at index: Int) -> [DrillAddSetChoice] {
        guard index < drills.count else { return [] }
        let drill = drills[index]
        let planned = drill.plannedSets
        guard planned.contains(where: { $0.mode != nil }) else { return [] }
        let stepCounts = Self.sequenceStepCounts(for: drill.drillId)
        let options = formationOptions(at: index)
        var choices: [DrillAddSetChoice] = []
        var seen: Set<String> = []
        for set in planned {
            let key = set.formationToken ?? ""
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            let plannedCount = planned.filter { ($0.formationToken ?? "") == key }.count
            choices.append(DrillAddSetChoice(
                token: set.formationToken,
                name: set.formationName,
                mode: set.mode,
                shotCount: stepCounts[key] ?? plannedCount,
                targetBalls: set.targetBalls,
                // 菜单展示名走序号制映射（「球形N」），与录入表格同一口径。
                displayName: options.first(where: { $0.token == set.formationToken })?.displayName
            ))
        }
        return choices
    }

    func deleteSet(drillIndex: Int, setIndex: Int) {
        guard drillIndex < drillSetsData.count,
              setIndex < drillSetsData[drillIndex].count else { return }
        drillSetsData[drillIndex].remove(at: setIndex)
    }

    // MARK: - Rest Timer

    func startRestTimer() {
        stopRestTimer()
        restTotalSeconds = restDuration
        restSecondsRemaining = restDuration
        isRestTimerActive = true
        restEndDate = Date().addingTimeInterval(Double(restDuration))

        let drillName = currentDrill?.nameZh ?? "训练"
        liveActivityManager.startActivity(drillName: drillName, totalSeconds: restDuration, endDate: restEndDate!)
        liveActivityManager.activateBackgroundAudio()

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in
            guard let self, let end = self.restEndDate else { return }
            let remaining = Int(ceil(end.timeIntervalSinceNow))
            if remaining > 0 {
                self.restSecondsRemaining = remaining
                if remaining <= 10 {
                    AudioServicesPlaySystemSound(1057)
                }
            } else {
                self.restSecondsRemaining = 0
                self.onRestComplete()
            }
        }
        timer.resume()
        restTimer = timer
    }

    private func onRestComplete() {
        restTimer?.cancel()
        restTimer = nil
        liveActivityManager.endActivity()
        liveActivityManager.deactivateBackgroundAudio()
        AudioServicesPlaySystemSound(1005)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        // F-AT-07: chrome dismiss ≤300ms (was 800ms zombie at 0:00)
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(BTMotion.easeChrome) {
                isRestTimerActive = false
            }
            if let next = pendingDrillAdvance {
                pendingDrillAdvance = nil
                currentDrillIndex = next
            }
        }
    }

    func stopRestTimer() {
        restTimer?.cancel()
        restTimer = nil
        isRestTimerActive = false
        restSecondsRemaining = 0
        restTotalSeconds = 0
        restEndDate = nil
        liveActivityManager.endActivity()
        liveActivityManager.deactivateBackgroundAudio()
    }

    func skipRestTimer() {
        let hadPendingAdvance = pendingDrillAdvance
        stopRestTimer()
        if let next = hadPendingAdvance {
            pendingDrillAdvance = nil
            currentDrillIndex = next
        }
    }

    func addRestTime(_ seconds: Int) {
        // F-AT-07: block +30S once countdown has hit zero (dismiss window)
        guard isRestTimerActive, restSecondsRemaining > 0 else { return }
        restSecondsRemaining += seconds
        restTotalSeconds += seconds
        restEndDate = restEndDate?.addingTimeInterval(Double(seconds))
        if let end = restEndDate {
            liveActivityManager.updateEndDate(end)
        }
    }

    func setsBinding(for index: Int) -> Binding<[DrillSetData]> {
        Binding(
            get: { [weak self] in
                guard let self, index < self.drillSetsData.count else { return [] }
                return self.drillSetsData[index]
            },
            set: { [weak self] newValue in
                guard let self, index < self.drillSetsData.count else { return }
                self.drillSetsData[index] = newValue
            }
        )
    }

    /// 每个 drill 的训练心得绑定（落 `DrillEntry.note`，契约 §8.7）。
    func noteBinding(for index: Int) -> Binding<String> {
        Binding(
            get: { [weak self] in
                guard let self, index < self.drillNotes.count else { return "" }
                return self.drillNotes[index]
            },
            set: { [weak self] newValue in
                guard let self, index < self.drillNotes.count else { return }
                self.drillNotes[index] = newValue
            }
        )
    }

    func formationOptions(at index: Int) -> [DrillFormationOption] {
        guard index < drillFormations.count else { return [] }
        return drillFormations[index]
    }

    // MARK: - End Training Flow

    func endTraining() {
        pauseTimer()
        trainingPhase = .note
    }

    func resumeTraining() {
        trainingPhase = .active
    }

    func skipNote() {
        trainingNote = ""
        trainingPhase = .summary
    }

    func submitNote() {
        trainingPhase = .summary
    }

    // MARK: - Summary Statistics

    var totalSets: Int {
        drillSetsData.flatMap { $0 }.count
    }

    var overallSuccessRate: Double {
        let allSets = drillSetsData.flatMap { $0 }
        let totalMade = allSets.reduce(0) { $0 + $1.madeBalls }
        let totalPossible = allSets.reduce(0) { $0 + $1.targetBalls }
        guard totalPossible > 0 else { return 0 }
        return Double(totalMade) / Double(totalPossible)
    }

    var totalBallsMade: Int {
        drillSetsData.flatMap { $0 }.reduce(0) { $0 + $1.madeBalls }
    }

    var drillSummaries: [DrillSummary] {
        var summaries: [DrillSummary] = []
        for i in 0..<min(drills.count, drillSetsData.count) {
            let drill = drills[i]
            let sets = drillSetsData[i]
            let made = sets.reduce(0) { $0 + $1.madeBalls }
            let possible = sets.reduce(0) { $0 + $1.targetBalls }
            summaries.append(DrillSummary(
                id: drill.id,
                drillId: drill.drillId,
                nameZh: drill.nameZh,
                level: drill.level,
                totalBallsMade: made,
                totalBallsPossible: possible,
                sets: sets.map { DrillSummary.SetResult(id: $0.id, madeBalls: $0.madeBalls, targetBalls: $0.targetBalls) }
            ))
        }
        return summaries.sorted { $0.successRate > $1.successRate }
    }

    func saveTraining(context: ModelContext) {
        saveError = nil

        do {
            // 训练 Tab 的正式训练一律是真实球台成绩（契约 §5.3）。
            let session = TrainingSession(kind: "drill")
            session.totalDurationMinutes = elapsedSeconds / 60
            session.note = trainingNote
            // 自由训练保持 nil；计划训练写入当前激活计划 id（W7 计划推进的判定依据）。
            session.planId = mode.planId

            for (drillIdx, drill) in drills.enumerated() {
                let entry = DrillEntry(
                    drillId: drill.drillId,
                    drillNameZh: drill.nameZh,
                    orderIndex: drillIdx,
                    note: drillIdx < drillNotes.count ? drillNotes[drillIdx] : "",
                    // 快照写入即冻结：展示层不得再回查当前内容（契约 §6.5 推论 2）。
                    criteriaText: drill.standardCriteria
                )

                guard drillIdx < drillSetsData.count else { continue }
                for setData in drillSetsData[drillIdx] {
                    let drillSet = DrillSet(
                        setNumber: setData.id,
                        targetBalls: setData.targetBalls,
                        madeBalls: setData.madeBalls,
                        formationToken: setData.formationToken,
                        formationName: setData.formationName,
                        unitLabel: drill.unitLabel,
                        // 内容侧尚未补机读达标线，0/0 = 未设定（D-v29-1，契约 §5.5）。
                        passMade: 0,
                        passTotal: 0,
                        durationSeconds: setData.duration.map { Int($0.rounded()) }
                    )
                    entry.sets.append(drillSet)
                }

                session.drillEntries.append(entry)
            }

            context.insert(session)
            try context.save()

            SyncQueueManager.shared.enqueue(
                entityType: "TrainingSession",
                entityId: session.id,
                operation: "create"
            )

            didSaveSuccessfully = true

            // W7 计划推进：训练已落库，这一步只前移计划游标（判定依据 = 上面写入的
            // session.planId）。失败不影响本次成绩，但必须可见，不静默吞。
            do {
                try PlanProgressService.advanceAfterPlanSession(session, context: context)
            } catch {
                saveError = "训练已保存，但计划进度未更新，可在训练首页「今日安排」手动跳过今天"
            }
        } catch {
            saveError = "训练记录保存失败，请确认设备存储空间充足后重试"
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        pauseTimer()
    }
}
