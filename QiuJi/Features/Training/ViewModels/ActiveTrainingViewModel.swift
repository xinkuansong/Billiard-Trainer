import Foundation
import SwiftUI
import SwiftData

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
        level: DrillLevel? = nil
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
    }
}

enum TrainingMode: Identifiable {
    case plan(drills: [TodayDrillItem])
    case free

    var id: String {
        switch self {
        case .plan: return "plan"
        case .free: return "free"
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

    // Recording state per drill
    @Published var drillSetsData: [[DrillSetData]] = []
    @Published var drillNotes: [String] = []

    // Rest timer
    @Published var restDuration: Int = 60
    @Published var restSecondsRemaining: Int = 0
    @Published var isRestTimerActive: Bool = false

    private var timerTask: Task<Void, Never>?
    private var restTimerTask: Task<Void, Never>?

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
        isLoading = true
        defer { isLoading = false }

        switch mode {
        case .plan(let todayDrills):
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
                    level: content.flatMap { DrillLevel(rawValue: $0.level) }
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
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                self?.elapsedSeconds += 1
            }
        }
    }

    func pauseTimer() {
        isTimerRunning = false
        timerTask?.cancel()
        timerTask = nil
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
        let drill = ActiveDrill(
            drillId: content.id,
            nameZh: content.nameZh,
            description: content.description,
            coachingPoints: content.coachingPoints,
            sets: content.sets.defaultSets,
            ballsPerSet: content.sets.defaultBallsPerSet,
            animation: content.animation,
            level: DrillLevel(rawValue: content.level)
        )
        drills.append(drill)
        let sets = (1...drill.sets).map { DrillSetData(id: $0, targetBalls: drill.ballsPerSet) }
        drillSetsData.append(sets)
        drillNotes.append("")
    }

    func removeDrill(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            drills.remove(at: index)
            if index < drillSetsData.count { drillSetsData.remove(at: index) }
            if index < drillNotes.count { drillNotes.remove(at: index) }
        }
        if currentDrillIndex >= drills.count {
            currentDrillIndex = max(0, drills.count - 1)
        }
    }

    // MARK: - Recording

    private func initializeRecords() {
        drillSetsData = drills.map { drill in
            (1...drill.sets).map { setNum in
                DrillSetData(
                    id: setNum,
                    targetBalls: drill.ballsPerSet,
                    isWarmup: drill.phaseType == "warmup" && setNum == 1
                )
            }
        }
        drillNotes = drills.map { _ in "" }
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
        drillSetsData[drillIndex][setIndex].isCompleted.toggle()

        if drillSetsData[drillIndex].allSatisfy({ $0.isCompleted }) {
            if drillIndex < drills.count - 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                    self?.currentDrillIndex = drillIndex + 1
                }
            }
        } else if !wasCompleted && restDuration > 0 {
            startRestTimer()
        }
    }

    func addSet(drillIndex: Int) {
        guard drillIndex < drillSetsData.count, drillIndex < drills.count else { return }
        let nextId = (drillSetsData[drillIndex].last?.id ?? 0) + 1
        let target = drills[drillIndex].ballsPerSet
        drillSetsData[drillIndex].append(DrillSetData(id: nextId, targetBalls: target))
    }

    func deleteSet(drillIndex: Int, setIndex: Int) {
        guard drillIndex < drillSetsData.count,
              setIndex < drillSetsData[drillIndex].count else { return }
        drillSetsData[drillIndex].remove(at: setIndex)
    }

    // MARK: - Rest Timer

    func startRestTimer() {
        stopRestTimer()
        restSecondsRemaining = restDuration
        isRestTimerActive = true
        restTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                guard let self else { break }
                if self.restSecondsRemaining > 0 {
                    self.restSecondsRemaining -= 1
                } else {
                    self.isRestTimerActive = false
                    break
                }
            }
        }
    }

    func stopRestTimer() {
        restTimerTask?.cancel()
        restTimerTask = nil
        isRestTimerActive = false
        restSecondsRemaining = 0
    }

    func skipRestTimer() {
        stopRestTimer()
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
            let session = TrainingSession()
            session.totalDurationMinutes = elapsedSeconds / 60
            session.note = trainingNote

            for (drillIdx, drill) in drills.enumerated() {
                let entry = DrillEntry(drillId: drill.drillId, drillNameZh: drill.nameZh)

                guard drillIdx < drillSetsData.count else { continue }
                for setData in drillSetsData[drillIdx] {
                    let drillSet = DrillSet(
                        setNumber: setData.id,
                        targetBalls: setData.targetBalls,
                        madeBalls: setData.madeBalls
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
