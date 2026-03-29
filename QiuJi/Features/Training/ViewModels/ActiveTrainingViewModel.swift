import Foundation

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

    init(
        drillId: String,
        nameZh: String,
        description: String = "",
        coachingPoints: [String] = [],
        sets: Int,
        ballsPerSet: Int,
        phaseType: String = "free",
        phaseZh: String = "自由训练"
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
                    phaseZh: item.phaseZh
                ))
            }
            drills = items

        case .free:
            drills = []
        }
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
            ballsPerSet: content.sets.defaultBallsPerSet
        )
        drills.append(drill)
    }

    func removeDrill(at offsets: IndexSet) {
        drills.remove(atOffsets: offsets)
        if currentDrillIndex >= drills.count {
            currentDrillIndex = max(0, drills.count - 1)
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        pauseTimer()
    }
}
