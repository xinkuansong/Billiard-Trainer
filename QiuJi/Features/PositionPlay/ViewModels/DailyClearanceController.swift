import Combine
import Foundation

@MainActor
protocol DailyClearancePlayingHost: AnyObject {
    func loadDailyClearanceBoard(_ board: BoardSnapshot)
    func currentDailyClearanceBoard() -> BoardSnapshot
    func captureDailyUndo() -> () -> Void
    func respotDailyBalls(_ keys: Set<String>)
    func restoreDailyClearanceCueBall()
    func beginDailyClearanceBreak(game: RackGame,
                                  seed: UInt64,
                                  onOutcome: @escaping (BreakOutcome) -> Void)
}

extension DailyClearancePlayingHost {
    func captureDailyUndo() -> () -> Void {
        let board = currentDailyClearanceBoard()
        return { [weak self] in self?.loadDailyClearanceBoard(board) }
    }
    func respotDailyBalls(_ keys: Set<String>) {}
}

extension PositionPlayViewModel: DailyClearancePlayingHost {
    func loadDailyClearanceBoard(_ board: BoardSnapshot) {
        loadBoard(board)
    }

    func currentDailyClearanceBoard() -> BoardSnapshot {
        currentSnapshot()
    }

    func restoreDailyClearanceCueBall() {
        guard !onTableKeys.contains(PositionPlayBall.cueKey) else { return }
        placeFromPalette(PositionPlayBall.cueKey)
    }

    func beginDailyClearanceBreak(game: RackGame,
                                  seed: UInt64,
                                  onOutcome: @escaping (BreakOutcome) -> Void) {
        // Cancel callbacks and playback before replacing the controller attempt.
        cancelDailyAttempt()
        startBreakFlow(
            game: game,
            manualDeliver: false,
            seed: seed,
            onOutcome: onOutcome
        )
        // Start at 8 m/s; the player can adjust every input before striking.
        breakRunner?.velocity = 8.0
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
    private var breakGeneration = UUID()
    private var awaitingShot = false
    private var undoDraft: DailyClearanceDraft?
    private var undoHost: (() -> Void)?
    @Published private(set) var canUndo = false
    var breakChoices: [DailyBreakChoice] { draft?.ruleState.breakChoices ?? [] }
    var cuePlacement: DailyCuePlacement { draft?.ruleState.cuePlacement ?? .none }
    var visitCount: Int { draft?.ruleState.visitCount ?? completion?.visitCount ?? 1 }

    var turnLabel: String {
        guard let current = draft else { return "" }
        let old = current.ruleState.ruleVersion < 2 ? "旧规则 · " : ""
        let targets = legalTargetKeys(tableKeys: Set(current.board?.onTable.keys.map { $0 } ?? []))
        let turn: String
        if current.game == .chineseEightBall {
            turn = current.ruleState.assignedGroup.map { $0.displayName + (targets == ["_8"] ? " · 黑八" : "") } ?? "开放局，进球后定组"
        } else {
            let number = targets.compactMap(PositionPlayBall.number(for:)).min()
            turn = "第\(current.ruleState.visitCount)次上手" + (number.map { " · 先碰\($0)号" } ?? "")
        }
        let placement = current.ruleState.cuePlacement
        return old + turn + (placement == .none ? "" : (placement == .anywhere ? " · 自由球" : " · 线后自由球"))
    }

    func prepareShot() {
        guard let current = draft, current.phase == .playing, breakChoices.isEmpty else { return }
        undoDraft = current
        undoHost = host?.captureDailyUndo()
        awaitingShot = true
        canUndo = false
    }

    func undoShot() {
        guard canUndo, let previous = undoDraft, let restore = undoHost, draft?.phase == .playing else { return }
        draft = previous
        rulesEngine = DailyClearanceRulesEngine(game: previous.game, state: previous.ruleState)
        restore()
        store.saveDraft(previous)
        undoDraft = nil; undoHost = nil; canUndo = false; awaitingShot = false
        statusText = "已恢复上一杆，继续击球"
    }

    private func prepareBehindStringPlacement(engine: DailyClearanceRulesEngine) -> String? {
        guard engine.state.cuePlacement == .behindHeadString,
              let board = host?.currentDailyClearanceBoard() else { return nil }
        let legal = engine.legalTargetKeys(tableKeys: Set(board.onTable.keys))
        let balls = legal.compactMap { key -> (String, CanvasPoint)? in board.onTable[key].map { (key, $0) } }
        guard !balls.isEmpty, balls.allSatisfy({ $0.1.x > 0.75 }),
              let nearest = balls.sorted(by: { $0.1.x == $1.1.x ? $0.0 < $1.0 : $0.1.x < $1.1.x }).first else { return nil }
        host?.respotDailyBalls([nearest.0])
        return "线后目标球已重置：\(PositionPlayBall.shortLabel(for: nearest.0))号"
    }

    func savePlacedBoard() {
        guard var current = draft, current.phase == .playing else { return }
        current.board = host?.currentDailyClearanceBoard()
        current.updatedAt = now()
        draft = current; store.saveDraft(current)
    }

    func selectionMessage(for key: String, tableKeys: Set<String>) -> String? {
        if !breakChoices.isEmpty { return "请先处理开球犯规" }
        return rulesEngine?.selectionMessage(for: key, tableKeys: tableKeys)
    }

    func resolveBreakChoice(_ choice: DailyBreakChoice) {
        guard var engine = rulesEngine, var current = draft, breakChoices.contains(choice) else { return }
        let rerack = engine.resolveBreakChoice(choice)
        current.ruleState = engine.state
        current.updatedAt = now()
        if rerack { current.phase = .manualRacked; current.board = nil; current.seed &+= 1 }
        rulesEngine = engine; draft = current
        store.saveDraft(current)
        statusText = choice.label
        if let notice = prepareBehindStringPlacement(engine: engine) { statusText += "；" + notice; savePlacedBoard() }
        if rerack { beginBreak() }
    }


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
    var playedVisitCount: Int? {
        if let draft { return draft.ruleState.playedVisitCount }
        return completion?.playedVisitCount
    }
    var visitSummary: String {
        playedVisitCount.map { "\($0)杆" } ?? "击球\(shotCount)次"
    }

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
            resetAndBeginManualRack(game: defaultGame)
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
        guard awaitingShot, var current = draft,
              current.phase == .playing,
              var engine = rulesEngine else { return nil }

        awaitingShot = false
        let timestamp = now()
        if let started = activeSince {
            current.activeDurationSeconds += max(0, timestamp.timeIntervalSince(started))
            activeSince = timestamp
        }
        current.shotCount += 1
        let ruling = engine.judge(facts)
        if ruling.foul { current.foulCount += 1 }
        current.ruleState = engine.state
        host?.respotDailyBalls(ruling.respotKeys)
        if facts.cuePocketed, ruling.ballInHand, !ruling.failed, !ruling.completed {
            host?.restoreDailyClearanceCueBall()
        }
        current.board = host?.currentDailyClearanceBoard()
        current.updatedAt = timestamp
        rulesEngine = engine
        canUndo = !ruling.completed && !ruling.failed && undoDraft != nil

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
        guard draft != nil else { return .unavailable }
        return .confirmationRequired
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
        resetAndBeginManualRack(game: replayGame)
        resumeActivity()
    }

    func legalTargetKeys(tableKeys: Set<String>) -> Set<String> {
        rulesEngine?.legalTargetKeys(tableKeys: tableKeys) ?? []
    }

    private func restore(_ restored: DailyClearanceDraft) {
        switch restored.phase {
        case .playing:
            if let board = restored.board { host?.loadDailyClearanceBoard(board) }
            statusText = restored.ruleState.ruleVersion < 2 ? "已恢复旧规则球局；重新开球后使用新规则" : "已恢复今日清台"
            if !restored.ruleState.breakChoices.isEmpty {
                statusText = restored.ruleState.breakChoices.contains(.rerackByBreaker)
                    ? "开球未满足碰库要求" : "开球犯规"
            }
        case .autoBreaking:
            // Migrate interrupted system breaks without discarding the rack or history.
            var manual = restored
            manual.phase = .manualRacked
            manual.updatedAt = now()
            draft = manual
            store.saveDraft(manual)
            beginBreak()
            statusText = "已恢复待开球球架"
        case .manualRacked:
            beginBreak()
            statusText = "已恢复待开球球架"
        case .failed:
            if let board = restored.board {
                host?.loadDailyClearanceBoard(board)
            } else {
                beginBreak()
            }
            statusText = "本局已结束"
        }
    }

    private func beginBreak() {
        guard let current = draft else { return }
        let generation = UUID()
        breakGeneration = generation
        awaitingShot = false; undoDraft = nil; undoHost = nil; canUndo = false
        host?.beginDailyClearanceBreak(
            game: current.game.rackGame,
            seed: current.seed,
            onOutcome: { [weak self] outcome in
                guard let self, self.breakGeneration == generation else { return }
                self.breakGeneration = UUID()
                self.handleBreakOutcome(outcome)
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

        if current.ruleState.ruleVersion >= 2, let facts = outcome.facts {
            var engine = rulesEngine ?? DailyClearanceRulesEngine(game: current.game)
            let ruling = current.game == .chineseEightBall
                ? engine.judgeChineseBreak(facts, automatic: false)
                : engine.judgeNineBreak(facts, automatic: false)
            host?.respotDailyBalls(ruling.respotKeys)
            if ruling.ballInHand { host?.restoreDailyClearanceCueBall() }
            let placementNotice = prepareBehindStringPlacement(engine: engine)
            current.board = host?.currentDailyClearanceBoard() ?? outcome.board
            current.ruleState = engine.state
            current.foulCount = engine.state.foulCount
            current.phase = ruling.failed ? .failed : .playing
            current.updatedAt = now()
            rulesEngine = engine; draft = current
            statusText = ruling.message + (placementNotice.map { "；" + $0 } ?? "")
            if ruling.completed { finishCompletion() } else { store.saveDraft(current) }
            return
        }

        if current.ruleState.ruleVersion >= 2 {
            current.phase = .failed
            current.board = outcome.board
            current.updatedAt = now()
            draft = current; store.saveDraft(current)
            statusText = "开球事实不完整，请重新开球"
            return
        }

        if outcome.terminalBallPocketed {
            current.seed &+= 1
            current.phase = .failed
            current.board = nil
            current.updatedAt = now()
            draft = current
            store.saveDraft(current)
            statusText = "终局球开球落袋，请手动重新开球"
            beginBreak()
            return
        }

        current.phase = .playing
        current.board = outcome.board
        current.ruleState = DailyClearanceRuleState(ruleVersion: current.ruleState.ruleVersion)
        current.updatedAt = now()
        draft = current
        rulesEngine = DailyClearanceRulesEngine(game: current.game, state: current.ruleState)
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
        beginBreak()
        resumeActivity(at: timestamp)
    }

    private func finishCompletion() {
        flushActivity()
        guard let current = draft else { return }
        if store.loadTodayCompletion() != nil {
            completion = store.makeCompletion(current)
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
        case "scratch":
            fixtureDraft.phase = .playing
            fixtureDraft.board = BoardSnapshot(onTable: [
                PositionPlayBall.cueKey: CanvasPoint(x: 0.5, y: 0.08),
                defaultGame.terminalBallKey: CanvasPoint(x: 0.8, y: 0.25)
            ])
        case "lastBall":
            if defaultGame == .chineseEightBall { fixtureDraft.ruleState.assignedGroup = .solid }
            // Input only: a legal final-ball layout aimed toward the middle pocket.
            // The normal solver, playback and rules must produce the completion.
            fixtureDraft.phase = .playing
            fixtureDraft.board = BoardSnapshot(onTable: [
                PositionPlayBall.cueKey: CanvasPoint(x: 0.5, y: 0.23),
                defaultGame.terminalBallKey: CanvasPoint(x: 0.5, y: 0.08)
            ])
        case "cameraLift":
            fixtureDraft.phase = .playing
            fixtureDraft.ruleState.assignedGroup = .solid
            // Legal close-to-rail cue position; production clearance must raise the shaft.
            fixtureDraft.board = BoardSnapshot(onTable: [
                PositionPlayBall.cueKey: CanvasPoint(x: 0.014, y: 0.07),
                "_1": CanvasPoint(x: 0.34, y: 0.20),
                "_2": CanvasPoint(x: 0.68, y: 0.30),
                "_9": CanvasPoint(x: 0.72, y: 0.12),
                "_8": CanvasPoint(x: 0.48, y: 0.38)
            ])
        case "closeup0", "closeup1", "closeup2", "closeup3", "closeup4", "closeup5":
            // Test input preferences, equivalent to enabling the existing menu toggles.
            UserPreferences.shared.showAimCloseup = true
            UserPreferences.shared.trajectoryDetail = .full
            fixtureDraft.phase = .playing
            fixtureDraft.ruleState.assignedGroup = .solid
            let index = Int(fixture.suffix(1)) ?? 0
            let targets = [CanvasPoint(x:0.87,y:0.12),CanvasPoint(x:0.13,y:0.12),
                           CanvasPoint(x:0.87,y:0.38),CanvasPoint(x:0.13,y:0.38),
                           CanvasPoint(x:0.5,y:0.12),CanvasPoint(x:0.5,y:0.38)]
            let target = targets[index]
            fixtureDraft.board = BoardSnapshot(onTable:[
                PositionPlayBall.cueKey:CanvasPoint(x:target.x+(index.isMultiple(of:2) ? -0.035 : 0.035),
                                                   y:target.y < 0.25 ? target.y+0.05 : target.y-0.05),
                "_1":target,"_2":CanvasPoint(x:0.3,y:0.3),"_8":CanvasPoint(x:0.65,y:0.25),
                "_9":CanvasPoint(x:0.7,y:0.15),"_10":CanvasPoint(x:0.2,y:0.38)])
        case "selection", "selectionStripe", "selectionOpen", "selectionBlack", "selectionNine":
            fixtureDraft.phase = .playing
            fixtureDraft.ruleState.assignedGroup = .solid
            fixtureDraft.board = BoardSnapshot(onTable: [
                PositionPlayBall.cueKey: CanvasPoint(x: 0.3, y: 0.2),
                "_1": CanvasPoint(x: 0.5, y: 0.22),
                "_2": CanvasPoint(x: 0.7, y: 0.3),
                "_9": CanvasPoint(x: 0.7, y: 0.12),
                "_8": CanvasPoint(x: 0.4, y: 0.38)
            ])
            if fixture == "selectionStripe" { fixtureDraft.ruleState.assignedGroup = .stripe }
            if fixture == "selectionOpen" { fixtureDraft.ruleState.assignedGroup = nil }
            if fixture == "selectionBlack" {
                fixtureDraft.board?.onTable.removeValue(forKey: "_1")
                fixtureDraft.board?.onTable.removeValue(forKey: "_2")
            }
            if fixture == "selectionNine" {
                fixtureDraft.ruleState.assignedGroup = nil
                fixtureDraft.board?.onTable.removeValue(forKey: "_8")
            }
        case "weakBreak":
            fixtureDraft.phase = .playing
            fixtureDraft.ruleState.breakChoices = [.rerackByIncoming, .rerackByBreaker, .acceptBallInHand]
        case "ballInHand", "behindHeadString":
            fixtureDraft.phase = .playing
            fixtureDraft.ruleState.assignedGroup = .solid
            fixtureDraft.ruleState.cuePlacement = fixture == "ballInHand" ? .anywhere : .behindHeadString
            fixtureDraft.board = BoardSnapshot(onTable: [
                PositionPlayBall.cueKey: CanvasPoint(x: 0.82, y: 0.25),
                "_1": CanvasPoint(x: 0.30, y: 0.22), "_8": CanvasPoint(x: 0.4, y: 0.38)])
        case "cueAccess", "cueAccessRoom", "cueAccessHigh", "cueAccessRear":
            fixtureDraft.phase = .playing
            fixtureDraft.ruleState.assignedGroup = .solid
            fixtureDraft.board = BoardSnapshot(onTable: [
                PositionPlayBall.cueKey: CanvasPoint(x: (fixture == "cueAccessRoom" ? 0.1 : fixture == "cueAccessHigh" ? Double(AngleSceneCalculator.ballRadius) : 0.045) / 2.54, y: 0.25),
                "_1": CanvasPoint(x: 0.60, y: 0.25), "_8": CanvasPoint(x: 0.75, y: 0.35)])
            if fixture == "cueAccessRear" {
                fixtureDraft.board=BoardSnapshot(onTable:[
                    PositionPlayBall.cueKey:CanvasPoint(x:0.4,y:0.25),
                    "_2":CanvasPoint(x:0.4-Double(2*AngleSceneCalculator.ballRadius)/2.54,y:0.25),
                    "_1":CanvasPoint(x:0.6,y:0.25),"_8":CanvasPoint(x:0.75,y:0.35)])
            }
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
