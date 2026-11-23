import SwiftUI
import SceneKit
import OSLog

struct SnakePracticeConfiguration: Equatable {
    enum Mode: String, CaseIterable, Identifiable, Codable {
        case alongLine = "沿线清台"
        case rightToLeft = "从右到左"
        case numbered = "按号清台"
        var title: String {
            switch self {
            case .alongLine: return "从左到右"
            case .rightToLeft: return "从右到左"
            case .numbered: return "按号"
            }
        }
        var id: String { rawValue }
    }
    static let counts = Array(3...15)
    var count: Int
    var mode: Mode
    var numbers: [Int]

    init(count: Int = 5, mode: Mode = .rightToLeft, numbers: [Int]? = nil) {
        self.count = count
        self.mode = mode
        self.numbers = numbers ?? (mode == .rightToLeft ? Array((1...count).reversed()) : Array(1...count))
    }

    mutating func regenerate() {
        numbers = Array(1...count)
        if mode == .numbered { numbers.shuffle() }
        else if mode == .rightToLeft { numbers.reverse() }
    }

    var keys: [String] { (1...count).map { "_\($0)" } }

    /// The library's continuous 5/10/15-ball snakes use approximately 15–16 cm
    /// center spacing. Normalize that to 1/16 of the 2.54 m table length;
    /// fewer balls shorten the centered row instead of increasing the gaps.
    static let spacing = 1.0 / 16
    var positions: [CanvasPoint] {
        (0..<count).map { index in
            CanvasPoint(x: 0.5 + (Double(index) - Double(count - 1) / 2) * Self.spacing, y: 0.25)
        }
    }

    var board: BoardSnapshot {
        let positions = positions
        var balls = Dictionary(uniqueKeysWithValues: zip(numbers, positions).map { ("_\($0.0)", $0.1) })
        let firstIndex = numbers.firstIndex(of: 1) ?? 0
        balls[PositionPlayBall.cueKey] = CanvasPoint(x: positions[firstIndex].x, y: 0.375)
        return BoardSnapshot(onTable: balls)
    }

    static func load(defaults: UserDefaults = .standard) -> Self {
        var value = Self()
        let count = defaults.integer(forKey: "snakePractice.count")
        if counts.contains(count) { value.count = count }
        value.mode = Mode(rawValue: defaults.string(forKey: "snakePractice.mode") ?? "") ?? .rightToLeft
        value.regenerate()
        return value
    }

    func save(defaults: UserDefaults = .standard) {
        defaults.set(count, forKey: "snakePractice.count")
        defaults.set(mode.rawValue, forKey: "snakePractice.mode")
        defaults.removeObject(forKey: "snakePractice.random")
    }
}

/// Local snake history is deliberately separate from training statistics and sync.
struct SnakePracticeRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var date: Date
    var count: Int
    var mode: SnakePracticeConfiguration.Mode
    var completed: Int
    var reason: String
    var succeeded: Bool { completed == count }
}

@MainActor
final class SnakePracticeHistory: ObservableObject {
    static let shared = SnakePracticeHistory()
    static let storageKey = "snakePractice.history.v1"
    private struct Archive: Codable {
        var records: [SnakePracticeRecord] = []
        var active: SnakePracticeRecord?
    }
    @Published private(set) var records: [SnakePracticeRecord] = []
    private(set) var active: SnakePracticeRecord?
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.xinkuan.qiuji", category: "SnakePracticeHistory")

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-snakePractice.resetHistory") {
            defaults.removeObject(forKey: Self.storageKey)
        }
        #endif
        guard let data = defaults.data(forKey: Self.storageKey) else { return }
        do {
            let archive = try JSONDecoder().decode(Archive.self, from: data)
            records = Array(archive.records.prefix(10))
            active = archive.active
        } catch {
            logger.error("Unable to decode snake history: \(String(describing: error), privacy: .public)")
        }
    }

    func checkpoint(_ record: SnakePracticeRecord) {
        // Undoing a completed last shot reopens the same attempt, not a new one.
        records.removeAll { $0.id == record.id }
        active = record
        persist()
    }

    func finish(_ record: SnakePracticeRecord) {
        records.removeAll { $0.id == record.id }
        records.insert(record, at: 0)
        records = Array(records.prefix(10))
        if active?.id == record.id { active = nil }
        persist()
    }

    func recoverInterruptedAttempt() {
        guard let active else { return }
        finish(active)
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(Archive(records: records, active: active))
            defaults.set(data, forKey: Self.storageKey)
        } catch {
            logger.error("Unable to encode snake history: \(String(describing: error), privacy: .public)")
        }
    }
}

/// Consumes the complete committed stroke, including collisions after the target drops.
enum SnakePracticeRuling: Equatable {
    case success, incomplete, scratch, otherBall, noContact, miss

    var message: String {
        switch self {
        case .success: return ""
        case .incomplete: return "本杆未完成"
        case .scratch: return "母球落袋"
        case .otherBall: return "碰到非目标球"
        case .noContact: return "未碰到指定球"
        case .miss: return "目标球未进"
        }
    }

    static func judge(target: String, remaining: Set<String>, shot: PlannedShot,
                      prediction: ShotPrediction) -> Self {
        guard prediction.hasFinalTableState else { return .incomplete }
        func key(_ name: String) -> String {
            if name == ShotInput.cueBallName { return PositionPlayBall.cueKey }
            if !shot.isFree && name == ShotInput.targetBallName { return shot.targetKey }
            return name
        }
        let potted = Set(prediction.pocketedBalls.map(key))
        if potted.contains(PositionPlayBall.cueKey) { return .scratch }
        let protected = remaining.subtracting([target])
        var first: String?
        var touchedOther = !potted.isDisjoint(with: protected)
        for event in prediction.events.sorted(by: { $0.time < $1.time }) {
            if case let .ballBall(a, b) = event.kind {
                let a = key(a), b = key(b)
                if first == nil {
                    if a == PositionPlayBall.cueKey { first = b }
                    else if b == PositionPlayBall.cueKey { first = a }
                }
                if protected.contains(a) || protected.contains(b) { touchedOther = true }
            }
        }
        if touchedOther { return .otherBall }
        guard first == target else { return .noContact }
        return potted.contains(target) ? .success : .miss
    }
}

@MainActor
final class SnakePracticeController: ObservableObject {
    @Published private(set) var configuration: SnakePracticeConfiguration
    @Published private(set) var targetIndex = 0
    @Published private(set) var hasStruck = false
    @Published private(set) var failure: SnakePracticeRuling?
    @Published private(set) var isComplete = false
    @Published private(set) var completionVisible = false
    @Published var showFailureChoice = false
    @Published var showSettings = false
    private weak var host: PositionPlayViewModel?
    private var previousIndex: Int?
    private var initialBoard: BoardSnapshot?
    private var completionTask: Task<Void, Never>?

    private let history: SnakePracticeHistory
    private let defaults: UserDefaults
    private var attemptID: UUID?
    private var attemptOpen = false
    // Unlike hasStruck (cue placement), this survives retrying the first stroke.
    private var attemptHasStruck = false
    private var awaitingShot = false

    init(configuration: SnakePracticeConfiguration = .init(), history: SnakePracticeHistory = .shared,
         defaults: UserDefaults = .standard) {
        self.configuration = configuration
        self.history = history
        self.defaults = defaults
    }

    private func record(reason: String) -> SnakePracticeRecord? {
        guard let attemptID else { return nil }
        return SnakePracticeRecord(id: attemptID, date: Date(), count: configuration.count,
            mode: configuration.mode, completed: targetIndex, reason: reason)
    }

    private func checkpoint() {
        guard attemptOpen, attemptHasStruck, let record = record(reason: failure?.message ?? "提前结束") else { return }
        history.checkpoint(record)
    }

    /// Idempotent across exit, restart, setting changes and late playback callbacks.
    func finishAttempt(reason: String = "提前结束") {
        guard attemptOpen else { return }
        if attemptHasStruck, !isComplete, let record = record(reason: failure?.message ?? reason) { history.finish(record) }
        attemptOpen = false
        awaitingShot = false
        showFailureChoice = false
    }

    var targetKey: String? { isComplete ? nil : "_\(targetIndex + 1)" }
    var canPlaceCue: Bool { !hasStruck && failure == nil && !isComplete }
    var canStrike: Bool { attemptOpen && failure == nil && !isComplete }
    var notice: String { failure?.message ?? (completionVisible ? "已清台" : "") }

    func attach(to vm: PositionPlayViewModel) {
        host = vm
        vm.legalAimTargets = { [weak self] keys in
            guard let self, let key = self.targetKey, keys.contains(key) else { return [] }
            return [key]
        }
        vm.onShotSettled = nil
        vm.onAimModeNotice = nil
        vm.onAimSelectionNotice = nil
        vm.onShotWillStart = { [weak self] in self?.prepareShot() }
        vm.onCommittedPracticeShot = { [weak self] solved in self?.settle(solved) }
        start(configuration)
    }

    func start(_ configuration: SnakePracticeConfiguration) {
        guard host?.isPlaying != true else { return }
        finishAttempt(reason: "更换设置")
        self.configuration = configuration
        configuration.save(defaults: defaults)
        reset()
        initialBoard = configuration.board
        attemptID = UUID(); attemptOpen = true
        checkpoint()
        host?.loadBoard(configuration.board)
        host?.refreshLegalAimSelection()
        showSettings = false
    }

    private func reset() {
        completionTask?.cancel()
        showFailureChoice = false; awaitingShot = false; attemptHasStruck = false
        targetIndex = 0; hasStruck = false; failure = nil
        isComplete = false; completionVisible = false; previousIndex = nil
    }

    func restart() {
        guard host?.isPlaying != true else { return }
        let board = initialBoard ?? configuration.board
        finishAttempt(reason: "重新开始")
        reset()
        attemptID = UUID(); attemptOpen = true
        checkpoint()
        host?.loadBoard(board)
        host?.refreshLegalAimSelection()
    }

    func nextRack() {
        var next = configuration
        next.regenerate()
        start(next)
    }

    func prepareShot() {
        guard canStrike, !awaitingShot else { return }
        awaitingShot = true
        if !hasStruck { initialBoard = host?.currentSnapshot() }
        previousIndex = targetIndex
        hasStruck = true
        attemptHasStruck = true
        checkpoint()
    }

    func settle(_ solved: PositionPlayViewModel.SolvedShot) {
        guard awaitingShot, let target = targetKey else { return }
        awaitingShot = false
        let ruling = SnakePracticeRuling.judge(target: target,
            remaining: Set(configuration.keys.dropFirst(targetIndex)),
            shot: solved.shot, prediction: solved.prediction)
        if ruling == .success {
            targetIndex += 1
            if targetIndex == configuration.count {
                isComplete = true; completionVisible = true
                if let record = record(reason: "") { history.finish(record) }
                completionTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { return }
                    self?.completionVisible = false
                }
            }
        } else { failure = ruling; showFailureChoice = true }
        if !isComplete { checkpoint() }
    }

    func undo() {
        guard host?.isPlaying != true, host == nil || host?.canReplay == true,
              let index = previousIndex else { return }
        completionTask?.cancel()
        showFailureChoice = false; awaitingShot = false
        targetIndex = index; failure = nil; isComplete = false; completionVisible = false
        hasStruck = index > 0
        previousIndex = nil
        host?.replayCurrent()
        checkpoint()
    }
}
