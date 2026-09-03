import Combine
import Foundation

@MainActor
protocol DailyClearancePlayingHost: AnyObject {
    func loadDailyClearanceBoard(_ board: BoardSnapshot)
    func currentDailyClearanceBoard() -> BoardSnapshot
    func beginDailyClearanceBreak(game: RackGame,
                                  seed: UInt64,
                                  automaticallyStrike: Bool,
                                  onOutcome: @escaping (BreakOutcome) -> Void)
}

extension PositionPlayViewModel: DailyClearancePlayingHost {
    func loadDailyClearanceBoard(_ board: BoardSnapshot) {
        loadBoard(board)
    }

    func currentDailyClearanceBoard() -> BoardSnapshot {
        currentSnapshot()
    }

    func beginDailyClearanceBreak(game: RackGame,
                                  seed: UInt64,
                                  automaticallyStrike: Bool,
                                  onOutcome: @escaping (BreakOutcome) -> Void) {
        startBreakFlow(
            game: game,
            manualDeliver: !automaticallyStrike,
            seed: seed,
            onOutcome: onOutcome
        )
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-dailyClearance.fixtureSettled") {
            let objectKeys: [String]
            switch game {
            case .chineseEightBall: objectKeys = ["_1", "_2", "_8"]
            case .nineBall, .zhuifen: objectKeys = ["_1", "_2", "_9"]
            }
            var onTable = [
                PositionPlayBall.cueKey: CanvasPoint(x: 0.72, y: 0.50)
            ]
            for (index, key) in objectKeys.enumerated() {
                onTable[key] = CanvasPoint(x: 0.30 + Double(index) * 0.08, y: 0.42 + Double(index % 2) * 0.14)
            }
            breakRunner?.applySettledBoardForTesting(BoardSnapshot(onTable: onTable))
            return
        }
        #endif
        if automaticallyStrike {
            breakRunner?.breakNow()
        }
    }
}

enum DailyClearanceRerackDecision: Equatable {
    case started
    case confirmationRequired
    case unavailable
}

/// 每日清台编排层：只协调规则、草稿、计时与开球宿主，不持有 SwiftUI View。
@MainActor
final class DailyClearanceController: ObservableObject {
    static let maximumAutomaticRetries = 3

    @Published private(set) var draft: DailyClearanceDraft?
    @Published private(set) var completion: DailyClearanceCompletion?
    @Published private(set) var statusText = "准备每日清台"

    private let store: DailyClearanceStore
    private let now: () -> Date
    private let seedGenerator: () -> UInt64
    private weak var host: (any DailyClearancePlayingHost)?
    private var rulesEngine: DailyClearanceRulesEngine?
    private var activeSince: Date?
    private var hasStarted = false
    private var currentBreakIsAutomatic = false

    init(store: DailyClearanceStore = DailyClearanceStore(),
         now: @escaping () -> Date = Date.init,
         seedGenerator: @escaping () -> UInt64 = {
             UInt64.random(in: 1...UInt64.max)
         }) {
        self.store = store
        self.now = now
        self.seedGenerator = seedGenerator
    }

    var game: DailyClearanceGame? { draft?.game ?? completion?.game }
    var isCompleted: Bool { draft == nil && completion != nil }
    var shotCount: Int { draft?.shotCount ?? completion?.shotCount ?? 0 }
    var foulCount: Int { draft?.foulCount ?? completion?.foulCount ?? 0 }
    var phase: DailyClearancePhase? { draft?.phase }
    var assignedGroup: DailyClearanceBallGroup? { draft?.ruleState.assignedGroup }
    var isAutomaticallyBreaking: Bool { draft?.phase == .autoBreaking }
    var remainingBallCount: Int {
        guard let board = draft?.board else { return 0 }
        return board.onTableKeys.filter { !PositionPlayBall.isCue($0) }.count
    }

    var elapsedSeconds: TimeInterval {
        let persisted = draft?.activeDurationSeconds ?? completion?.activeDurationSeconds ?? 0
        guard let activeSince else { return persisted }
        return persisted + max(0, now().timeIntervalSince(activeSince))
    }

    func start(host: any DailyClearancePlayingHost,
               defaultGame: DailyClearanceGame) {
        self.host = host
        guard !hasStarted else {
            resumeActivity()
            return
        }
        hasStarted = true
        installUITestFixtureIfNeeded(defaultGame: defaultGame)
        completion = store.loadTodayCompletion()

        if let restored = store.loadTodayDraft() {
            draft = restored
            rulesEngine = DailyClearanceRulesEngine(game: restored.game, state: restored.ruleState)
            restore(restored)
        } else if completion != nil {
            statusText = "今日已清台"
        } else {
            beginNewAutomaticAttempt(game: defaultGame, seed: seedGenerator())
        }
        resumeActivity()
    }

    func stop() {
        flushActivity()
    }

    func resumeActivity(at timestamp: Date? = nil) {
        guard activeSince == nil, draft != nil else { return }
        activeSince = timestamp ?? now()
    }

    /// 把前台用时一次性结算进草稿；activeSince 清空保证重复调用幂等。
    func flushActivity(at timestamp: Date? = nil) {
        guard let started = activeSince, var current = draft else { return }
        let end = timestamp ?? now()
        current.activeDurationSeconds += max(0, end.timeIntervalSince(started))
        current.updatedAt = end
        activeSince = nil
        draft = current
        store.saveDraft(current)
    }

    @discardableResult
    func handleShotSettled(_ facts: ShotFacts) -> DailyClearanceRuling? {
        guard var current = draft,
              current.phase == .playing,
              var engine = rulesEngine else { return nil }

        current.shotCount += 1
        let ruling = engine.judge(facts)
        if ruling.foul { current.foulCount += 1 }
        current.ruleState = engine.state
        current.board = host?.currentDailyClearanceBoard()
        current.updatedAt = now()
        rulesEngine = engine

        if ruling.completed {
            draft = current
            finishCompletion()
        } else {
            if ruling.failed { current.phase = .failed }
            draft = current
            store.saveDraft(current)
            statusText = ruling.message
        }
        return ruling
    }

    func requestRerack() -> DailyClearanceRerackDecision {
        guard let current = draft, current.phase != .autoBreaking else { return .unavailable }
        if current.shotCount > 0 { return .confirmationRequired }
        resetAndBeginManualRack(game: current.game)
        return .started
    }

    func confirmRerack() {
        guard let current = draft else { return }
        resetAndBeginManualRack(game: current.game)
    }

    func changeGame(_ game: DailyClearanceGame) {
        resetAndBeginManualRack(game: game)
    }

    func replay() {
        let replayGame = game ?? .chineseEightBall
        beginNewAutomaticAttempt(game: replayGame, seed: seedGenerator())
        resumeActivity()
    }

    func legalTargetKeys(tableKeys: Set<String>) -> Set<String> {
        rulesEngine?.legalTargetKeys(tableKeys: tableKeys) ?? []
    }

    private func restore(_ restored: DailyClearanceDraft) {
        switch restored.phase {
        case .playing:
            if let board = restored.board { host?.loadDailyClearanceBoard(board) }
            statusText = "已恢复今日清台"
        case .autoBreaking:
            beginBreak(automaticallyStrike: true)
        case .manualRacked:
            beginBreak(automaticallyStrike: false)
            statusText = "已恢复待开球球架"
        case .failed:
            if let board = restored.board {
                host?.loadDailyClearanceBoard(board)
            } else {
                beginBreak(automaticallyStrike: false)
            }
            statusText = "本局已结束，可重新开球"
        }
    }

    private func beginNewAutomaticAttempt(game: DailyClearanceGame, seed: UInt64) {
        let current = store.makeDraft(game: game, seed: seed)
        draft = current
        rulesEngine = DailyClearanceRulesEngine(game: game)
        store.saveDraft(current)
        statusText = "正在自动开球…"
        beginBreak(automaticallyStrike: true)
    }

    private func beginBreak(automaticallyStrike: Bool) {
        guard let current = draft else { return }
        currentBreakIsAutomatic = automaticallyStrike
        host?.beginDailyClearanceBreak(
            game: current.game.rackGame,
            seed: current.seed,
            automaticallyStrike: automaticallyStrike,
            onOutcome: { [weak self] outcome in
                self?.handleBreakOutcome(outcome)
            }
        )
    }

    private func handleBreakOutcome(_ outcome: BreakOutcome) {
        guard var current = draft, current.seed == outcome.seed else { return }

        if !outcome.settled {
            current.phase = .failed
            current.board = nil
            current.updatedAt = now()
            draft = current
            store.saveDraft(current)
            statusText = "开球未完全停稳，请重新开球"
            return
        }

        if outcome.terminalBallPocketed {
            if currentBreakIsAutomatic,
               current.automaticRetryCount < Self.maximumAutomaticRetries {
                current.automaticRetryCount += 1
                current.seed &+= 1
                current.board = nil
                current.phase = .autoBreaking
                current.updatedAt = now()
                draft = current
                store.saveDraft(current)
                statusText = "终局球开球落袋，正在重开…"
                beginBreak(automaticallyStrike: true)
                return
            }

            current.seed &+= 1
            current.phase = .failed
            current.board = nil
            current.updatedAt = now()
            draft = current
            store.saveDraft(current)
            statusText = "终局球开球落袋，请手动重新开球"
            beginBreak(automaticallyStrike: false)
            return
        }

        current.phase = .playing
        current.board = outcome.board
        current.ruleState = DailyClearanceRuleState()
        current.updatedAt = now()
        draft = current
        rulesEngine = DailyClearanceRulesEngine(game: current.game)
        store.saveDraft(current)
        statusText = outcome.cueScratched ? "母球已补回开球区，开始清台" : "开球完成，开始清台"
    }

    private func resetAndBeginManualRack(game: DailyClearanceGame) {
        flushActivity()
        let timestamp = now()
        var current = store.makeDraft(game: game, seed: seedGenerator())
        current.phase = .manualRacked
        current.startedAt = timestamp
        current.updatedAt = timestamp
        draft = current
        rulesEngine = DailyClearanceRulesEngine(game: game)
        store.saveDraft(current)
        statusText = "已重新摆架，请调整后开球"
        beginBreak(automaticallyStrike: false)
        resumeActivity(at: timestamp)
    }

    private func finishCompletion() {
        flushActivity()
        guard let current = draft else { return }
        if let existing = store.loadTodayCompletion() {
            completion = existing
            store.clearDraft()
        } else {
            completion = store.complete(current)
        }
        draft = nil
        activeSince = nil
        statusText = "今日已清台"
    }

    private func installUITestFixtureIfNeeded(defaultGame: DailyClearanceGame) {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-dailyClearance.resetState") {
            store.clearDraft()
            store.clearCompletion()
        }
        guard let fixture = args.first(where: { $0.hasPrefix("-dailyClearance.fixture=") })?
            .replacingOccurrences(of: "-dailyClearance.fixture=", with: "") else { return }

        store.clearDraft()
        store.clearCompletion()
        let timestamp = now()
        let board = BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.72, y: 0.50),
            "_1": CanvasPoint(x: 0.30, y: 0.42),
            defaultGame.terminalBallKey: CanvasPoint(x: 0.43, y: 0.56)
        ])

        if fixture == "completed" {
            store.saveCompletion(DailyClearanceCompletion(
                challengeDay: store.day(containing: timestamp),
                game: defaultGame,
                shotCount: 7,
                foulCount: 1,
                activeDurationSeconds: 128,
                completedAt: timestamp
            ))
            return
        }

        var fixtureDraft = store.makeDraft(game: defaultGame, seed: 52)
        fixtureDraft.board = board
        fixtureDraft.activeDurationSeconds = 65
        switch fixture {
        case "progress":
            fixtureDraft.phase = .playing
            fixtureDraft.shotCount = 2
            fixtureDraft.foulCount = 1
        case "failed":
            fixtureDraft.phase = .failed
            fixtureDraft.shotCount = 3
            fixtureDraft.foulCount = 1
        case "manual":
            fixtureDraft.phase = .manualRacked
            fixtureDraft.board = nil
        default:
            return
        }
        store.saveDraft(fixtureDraft)
        #endif
    }
}
