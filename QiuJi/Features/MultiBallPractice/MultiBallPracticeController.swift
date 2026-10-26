import Foundation
import Combine

/// Shared lifecycle surface for fixed-rack practices hosted by the daily table shell.
@MainActor
protocol RackPracticeControlling: AnyObject {
    var canPlaceCue: Bool { get }
    var canStrike: Bool { get }
    var isComplete: Bool { get }
    var targetKey: String? { get }
    var legalKeys: Set<String> { get }
    var paletteKeys: [String] { get }
    var notice: String { get }
    var showFailureChoice: Bool { get set }
    var showSettings: Bool { get set }
    func attach(to host: PositionPlayViewModel)
    func restart()
    func nextRack()
    func undo()
    func finishAttempt(reason: String)
}

extension SnakePracticeController: RackPracticeControlling {
    var legalKeys: Set<String> { targetKey.map { [$0] } ?? [] }
    var paletteKeys: [String] { configuration.keys }
}

enum MultiBallRuling: Equatable {
    case continued(Set<String>), failed(String)
    static func judge(game: MultiBallConfiguration.Game, remaining: Set<String>,
                      first: String?, potted: Set<String>, complete: Bool) -> Self {
        guard complete else { return .failed("本杆未完成") }
        guard !potted.contains(PositionPlayBall.cueKey) else { return .failed("母球落袋") }
        if game == .rotation {
            guard let target = remaining.min(by: { Int($0.dropFirst())! < Int($1.dropFirst())! }), first == target else { return .failed("未先碰最小号球") }
            guard potted == [target] else { return .failed(potted.isEmpty ? "目标球未进" : "请按号码顺序逐颗打进") }
        } else {
            let colored = remaining.subtracting(["_8"])
            let legal = colored.isEmpty ? Set(["_8"]) : colored
            if potted.contains("_8") && !colored.isEmpty { return .failed("黑八提前落袋") }
            guard let first, legal.contains(first) else { return .failed("未先碰己方目标球") }
            guard !potted.isDisjoint(with: legal) else { return .failed("己方目标球未进") }
        }
        return .continued(remaining.subtracting(potted))
    }
    static func judge(game: MultiBallConfiguration.Game, remaining: Set<String>, solved: PositionPlayViewModel.SolvedShot) -> Self {
        func key(_ name: String) -> String {
            if name == ShotInput.cueBallName { return PositionPlayBall.cueKey }
            if !solved.shot.isFree && name == ShotInput.targetBallName { return solved.shot.targetKey }
            return name
        }
        var first: String?
        for event in solved.prediction.events.sorted(by: { $0.time < $1.time }) {
            if case let .ballBall(a, b) = event.kind {
                if key(a) == PositionPlayBall.cueKey { first = key(b); break }
                if key(b) == PositionPlayBall.cueKey { first = key(a); break }
            }
        }
        return judge(game: game, remaining: remaining, first: first,
                     potted: Set(solved.prediction.pocketedBalls.map(key)), complete: solved.prediction.hasFinalTableState)
    }
}

@MainActor
final class MultiBallPracticeController: ObservableObject, RackPracticeControlling {
    @Published private(set) var configuration: MultiBallConfiguration
    @Published private(set) var rack: MultiBallRack?
    @Published private(set) var remaining: Set<String> = []
    @Published private(set) var hasStruck = false
    @Published private(set) var failure: String?
    @Published private(set) var isComplete = false
    @Published var showFailureChoice = false
    @Published var showSettings = false
    @Published var showDailyLimit = false
    @Published var showUpgrade = false
    @Published var showSessionEnd = false
    @Published private(set) var questionNumber = 0
    let is3D: Bool
    private let limiter: AngleUsageLimiter
    var premiumProvider: () -> Bool = { false }
    private var pendingNewSession = false
    var newSessionRequiresPro: Bool { !premiumProvider() && (is3D || configuration.freePractice || limiter.remainingToday == 0) }
    func requestNewSession() {
        limiter.refreshDay()
        if newSessionRequiresPro { pendingNewSession = true; showUpgrade = true }
        else { showSettings = true }
    }
    func subscriptionDismissed() {
        if pendingNewSession && premiumProvider() { showSettings = true }
        pendingNewSession = false
    }
    private var requiresPremium: Bool { is3D || configuration.freePractice }
    private var authorized: Bool { !requiresPremium || premiumProvider() }
    var progressTitle: String { is3D || configuration.freePractice ? "" : "第 \(questionNumber)/3 题 · " }

    private weak var host: PositionPlayViewModel?
    private let defaults: UserDefaults
    private var awaiting = false
    private var previous: (remaining: Set<String>, hasStruck: Bool)?
    private var initialBoard: BoardSnapshot?
    private var completionTask: Task<Void, Never>?
    @Published private var completionVisible = false
    init(configuration: MultiBallConfiguration = .load(), defaults: UserDefaults = .standard,
         is3D: Bool = false, limiter: AngleUsageLimiter = .multiBallTraining) {
        self.configuration = configuration; self.defaults = defaults
        self.is3D = is3D; self.limiter = limiter
    }
    var paletteKeys: [String] { rack?.paletteKeys ?? [] }
    var legalKeys: Set<String> {
        guard !isComplete, failure == nil else { return [] }
        if configuration.game == .rotation { return remaining.min(by: { Int($0.dropFirst())! < Int($1.dropFirst())! }).map { [$0] } ?? [] }
        let colored = remaining.subtracting(["_8"])
        return colored.isEmpty ? remaining : colored
    }
    var targetKey: String? { legalKeys.sorted().first }
    var canPlaceCue: Bool { authorized && rack != nil && !hasStruck && failure == nil && !isComplete }
    var canStrike: Bool { authorized && rack != nil && failure == nil && !isComplete }
    var notice: String { failure ?? (completionVisible ? "已清台" : "") }
    var groupTitle: String {
        guard let rack, configuration.game == .chineseEight else { return "按号码顺序清台" }
        return rack.ownKeys.contains(where: { $0 != "_8" && (Int($0.dropFirst()) ?? 8) < 8 }) ? "己方全色 · 最后打黑八" : "己方花色 · 最后打黑八"
    }
    func attach(to vm: PositionPlayViewModel) {
        host = vm
        vm.legalAimTargets = { [weak self] keys in self?.legalKeys.intersection(keys) ?? [] }
        vm.onShotSettled = nil; vm.onAimModeNotice = nil; vm.onAimSelectionNotice = nil
        vm.onShotWillStart = { [weak self] in self?.prepareShot() }
        vm.onCommittedPracticeShot = { [weak self] in self?.settle($0) }
        start(configuration)
    }
    func start(_ value: MultiBallConfiguration) { loadRack(value, resettingSession: true) }
    private func loadRack(_ value: MultiBallConfiguration, resettingSession: Bool) {
        guard host?.isPlaying != true else { return }
        let premium = premiumProvider()
        limiter.refreshDay()
        if !premium {
            guard !is3D && !value.freePractice else { showUpgrade = true; return }
            guard limiter.questionsUsedToday < limiter.limit else { showDailyLimit = true; return }
        }
        do {
            let next = try MultiBallBank.shared.draw(configuration: value, excluding: rack?.sourceID)
            if !premium { limiter.recordQuestion() }
            questionNumber = resettingSession ? 1 : questionNumber + 1
            showSessionEnd = false; showDailyLimit = false
            configuration = value; value.save(defaults: defaults, is3D: is3D); rack = next; initialBoard = next.board
            restart(); showSettings = false
        } catch { failure = MultiBallBank.BankError.unavailable.localizedDescription; showFailureChoice = false }
    }
    func restart() {
        guard authorized, host?.isPlaying != true, let rack, let initialBoard else { return }
        completionTask?.cancel(); completionVisible = false
        remaining = rack.ownKeys; hasStruck = false; failure = nil; isComplete = false
        previous = nil; awaiting = false; showFailureChoice = false
        host?.loadBoard(initialBoard); host?.refreshLegalAimSelection()
    }
    func nextRack() {
        guard host?.isPlaying != true else { return }
        if !is3D && !configuration.freePractice && questionNumber >= 3 {
            showSessionEnd = true; return
        }
        loadRack(configuration, resettingSession: false)
    }
    func prepareShot() {
        guard canStrike, !awaiting else { return }
        previous = (remaining, hasStruck)
        if !hasStruck, let board = host?.currentSnapshot() { initialBoard = board }
        hasStruck = true; awaiting = true
    }
    func settle(_ solved: PositionPlayViewModel.SolvedShot) {
        guard awaiting else { return }; awaiting = false
        switch MultiBallRuling.judge(game: configuration.game, remaining: remaining, solved: solved) {
        case .continued(let next):
            remaining = next; isComplete = next.isEmpty
            if isComplete {
                completionVisible = true
                completionTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(3))
                    if !Task.isCancelled { self?.completionVisible = false }
                }
            }
        case .failed(let reason): failure = reason; showFailureChoice = true
        }
    }
    func undo() {
        guard authorized, host?.isPlaying != true, host?.canReplay == true, let previous else { return }
        completionTask?.cancel(); completionVisible = false
        remaining = previous.remaining; hasStruck = previous.hasStruck
        failure = nil; isComplete = false; showFailureChoice = false; awaiting = false
        self.previous = nil; host?.replayCurrent()
    }
    func finishAttempt(reason: String) { awaiting = false; completionTask?.cancel(); showFailureChoice = false }
}
