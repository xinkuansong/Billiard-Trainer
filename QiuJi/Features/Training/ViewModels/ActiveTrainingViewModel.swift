import Foundation
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

    init(
        drillId: String,
        nameZh: String,
        description: String = "",
        coachingPoints: [String] = [],
        sets: Int,
        ballsPerSet: Int,
        phaseType: String = "free",
        phaseZh: String = "自由训练",
        animation: DrillAnimation? = nil
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
    let totalBallsMade: Int
    let totalBallsPossible: Int

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
    @Published var currentSetIndices: [Int] = []
    @Published var ballsMadeRecords: [[Int]] = []

    private var timerTask: Task<Void, Never>?

    var currentDrill: ActiveDrill? {
        guard !drills.isEmpty, currentDrillIndex >= 0, currentDrillIndex < drills.count else { return nil }
        return drills[currentDrillIndex]
    }

    var formattedTime: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    var progressText: String {
        guard !drills.isEmpty else { return "" }
        return "第 \(currentDrillIndex + 1) 项 / 共 \(drills.count) 项"
    }

    var progress: Double {
        guard !drills.isEmpty else { return 0 }
        return Double(currentDrillIndex + 1) / Double(drills.count)
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
                    animation: content?.animation
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
            animation: content.animation
        )
        drills.append(drill)
        currentSetIndices.append(0)
        ballsMadeRecords.append(Array(repeating: 0, count: drill.sets))
    }

    func removeDrill(at offsets: IndexSet) {
        drills.remove(atOffsets: offsets)
        if currentDrillIndex >= drills.count {
            currentDrillIndex = max(0, drills.count - 1)
        }
    }

    // MARK: - Recording

    private func initializeRecords() {
        currentSetIndices = drills.map { _ in 0 }
        ballsMadeRecords = drills.map { Array(repeating: 0, count: $0.sets) }
    }

    var currentSetIndex: Int {
        guard currentDrillIndex < currentSetIndices.count else { return 0 }
        return currentSetIndices[currentDrillIndex]
    }

    var currentBallsMade: Int {
        guard currentDrillIndex < ballsMadeRecords.count,
              currentSetIndex < ballsMadeRecords[currentDrillIndex].count else { return 0 }
        return ballsMadeRecords[currentDrillIndex][currentSetIndex]
    }

    var isCurrentDrillAllSetsCompleted: Bool {
        guard let drill = currentDrill,
              currentDrillIndex < currentSetIndices.count else { return false }
        return currentSetIndices[currentDrillIndex] >= drill.sets
    }

    func incrementBalls() {
        guard currentDrillIndex < ballsMadeRecords.count,
              currentSetIndex < ballsMadeRecords[currentDrillIndex].count else { return }
        let drill = drills[currentDrillIndex]
        if ballsMadeRecords[currentDrillIndex][currentSetIndex] < drill.ballsPerSet {
            ballsMadeRecords[currentDrillIndex][currentSetIndex] += 1
        }
    }

    func decrementBalls() {
        guard currentDrillIndex < ballsMadeRecords.count,
              currentSetIndex < ballsMadeRecords[currentDrillIndex].count else { return }
        if ballsMadeRecords[currentDrillIndex][currentSetIndex] > 0 {
            ballsMadeRecords[currentDrillIndex][currentSetIndex] -= 1
        }
    }

    func completeCurrentSet() {
        guard currentDrillIndex < currentSetIndices.count else { return }
        let drill = drills[currentDrillIndex]
        if currentSetIndices[currentDrillIndex] < drill.sets - 1 {
            currentSetIndices[currentDrillIndex] += 1
        } else {
            currentSetIndices[currentDrillIndex] = drill.sets
            if currentDrillIndex < drills.count - 1 {
                currentDrillIndex += 1
            }
        }
    }

    // MARK: - End Training Flow

    func endTraining() {
        pauseTimer()
        trainingPhase = .note
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
        drills.reduce(0) { $0 + $1.sets }
    }

    var overallSuccessRate: Double {
        let totalMade = ballsMadeRecords.flatMap { $0 }.reduce(0, +)
        let totalPossible = drills.reduce(0) { $0 + $1.sets * $1.ballsPerSet }
        guard totalPossible > 0 else { return 0 }
        return Double(totalMade) / Double(totalPossible)
    }

    var drillSummaries: [DrillSummary] {
        zip(drills, ballsMadeRecords).map { drill, records in
            DrillSummary(
                id: drill.id,
                nameZh: drill.nameZh,
                totalBallsMade: records.reduce(0, +),
                totalBallsPossible: drill.sets * drill.ballsPerSet
            )
        }.sorted { $0.successRate > $1.successRate }
    }

    func saveTraining(context: ModelContext) {
        saveError = nil

        do {
            let session = TrainingSession()
            session.totalDurationMinutes = elapsedSeconds / 60
            session.note = trainingNote

            for (drillIdx, drill) in drills.enumerated() {
                let entry = DrillEntry(drillId: drill.drillId, drillNameZh: drill.nameZh)

                guard drillIdx < ballsMadeRecords.count else { continue }
                let records = ballsMadeRecords[drillIdx]

                for (setIdx, madeBalls) in records.enumerated() {
                    let drillSet = DrillSet(
                        setNumber: setIdx + 1,
                        targetBalls: drill.ballsPerSet,
                        madeBalls: madeBalls
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
