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
    let sets: Int
    let ballsPerSet: Int
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
        self.id = UUID()
        self.drillId = drillId
        self.nameZh = nameZh
        self.description = description
        self.coachingPoints = coachingPoints
        self.sets = sets
        self.ballsPerSet = ballsPerSet
        self.phaseType = phaseType
        self.phaseZh = phaseZh
        self.animation = animation
        self.level = level
        self.category = category
        self.subcategory = subcategory
        self.standardCriteria = standardCriteria
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
                    sets: item.sets,
                    ballsPerSet: item.ballsPerSet,
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
            drills = []
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
        let drill = ActiveDrill(
            drillId: content.id,
            nameZh: content.nameZh,
            description: content.description,
            coachingPoints: content.coachingPoints,
            sets: content.sets.defaultSets,
            ballsPerSet: content.sets.defaultBallsPerSet,
            animation: content.animation,
            level: DrillLevel(rawValue: content.level),
            category: content.category,
            subcategory: content.subcategory,
            standardCriteria: content.standardCriteria
        )
        drills.append(drill)
        let formations = Self.formationOptions(for: drill.drillId)
        let sets = (1...drill.sets).map {
            DrillSetData(
                id: $0,
                targetBalls: drill.ballsPerSet,
                formationToken: formations.first?.token,
                formationName: formations.first?.name
            )
        }
        drillSetsData.append(sets)
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
        drillSetsData = drills.enumerated().map { drillIdx, drill in
            let formations = drillIdx < drillFormations.count ? drillFormations[drillIdx] : []
            return (1...drill.sets).map { setNum in
                DrillSetData(
                    id: setNum,
                    targetBalls: drill.ballsPerSet,
                    isWarmup: drill.phaseType == "warmup" && setNum == 1,
                    formationToken: formations.first?.token,
                    formationName: formations.first?.name
                )
            }
        }
        drillNotes = drills.map { _ in "" }
    }

    /// 多球形 drill 的可选球形；单球形（或无序列）返回空数组 —— 单球形不出选择 UI，
    /// `DrillSet.formationToken/Name` 保持 nil（契约 §4.1）。
    static func formationOptions(for drillId: String) -> [DrillFormationOption] {
        let formations = DrillTryoutBoardStore.formations(for: drillId)
        guard formations.count > 1 else { return [] }
        return formations.map { DrillFormationOption(token: $0.token, name: $0.title) }
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
        let nextId = (drillSetsData[drillIndex].last?.id ?? 0) + 1
        let target = drills[drillIndex].ballsPerSet
        let last = drillSetsData[drillIndex].last
        drillSetsData[drillIndex].append(DrillSetData(
            id: nextId,
            targetBalls: target,
            formationToken: last?.formationToken,
            formationName: last?.formationName
        ))
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
        } catch {
            saveError = "训练记录保存失败，请确认设备存储空间充足后重试"
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        pauseTimer()
    }
}
