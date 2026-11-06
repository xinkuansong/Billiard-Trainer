import XCTest
@testable import QiuJi

@MainActor
final class DailyClearanceControllerTests: XCTestCase {
    private final class Host: DailyClearancePlayingHost {
        struct Request {
            let game: RackGame
            let seed: UInt64
            let callback: (BreakOutcome) -> Void
        }

        var board = BoardSnapshot(onTable: [
            "cueBall": CanvasPoint(x: 0.7, y: 0.25),
            "_1": CanvasPoint(x: 0.3, y: 0.2),
            "_9": CanvasPoint(x: 0.2, y: 0.2)
        ])
        var requests: [Request] = []
        var cueRestores = 0

        func restoreDailyClearanceCueBall() {
            cueRestores += 1
            var balls = board.onTable
            balls["cueBall"] = CanvasPoint(x: 0.5, y: 0.25)
            board = BoardSnapshot(onTable: balls)
        }

        func loadDailyClearanceBoard(_ board: BoardSnapshot) { self.board = board }
        func currentDailyClearanceBoard() -> BoardSnapshot { board }
        func beginDailyClearanceBreak(game: RackGame,
                                      seed: UInt64,
                                      onOutcome: @escaping (BreakOutcome) -> Void) {
            requests.append(Request(
                game: game,
                seed: seed,
                callback: onOutcome
            ))
        }

        func deliverLast(pocketed: [String] = [], settled: Bool = true) {
            let request = requests.last!
            request.callback(BreakOutcome(
                board: board,
                game: request.game,
                seed: request.seed,
                pocketedKeys: pocketed,
                cueScratched: pocketed.contains("cueBall"),
                terminalBallPocketed: pocketed.contains("_8") || pocketed.contains("_9"),
                settled: settled,
                facts: ShotFacts(firstContactKey: "_1", pocketedKeys: pocketed.filter { $0 != "cueBall" },
                    cuePocketed: pocketed.contains("cueBall"), railOrPocketAfterContact: true,
                    tableKeysBefore: ["_1", "_2", "_3", "_9"], railContactKeys: ["_1", "_2", "_3", "_9"])
            ))
        }
    }

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var calendar: Calendar!
    private var clock: Date!
    private var store: DailyClearanceStore!
    private var host: Host!

    override func setUp() {
        super.setUp()
        suiteName = "DailyClearanceControllerTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        clock = calendar.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 10))!
        store = DailyClearanceStore(
            defaults: defaults,
            calendar: calendar,
            now: { self.clock },
            log: { _ in }
        )
        host = Host()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        host = nil
        store = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func makeController(seed: UInt64 = 100, premium: Bool = true) -> DailyClearanceController {
        let controller = DailyClearanceController(
            store: store,
            now: { self.clock },
            seedGenerator: { seed }
        )
        controller.premiumProvider = { premium }
        return controller
    }

    func testFreeAllowanceStartsOnlyOnFirstAcceptedBreakAndSurvivesRelaunch() {
        let controller = makeController(premium: false)
        controller.start(host: host, defaultGame: .nineBall)
        XCTAssertFalse(store.hasUsedChallengeToday)
        controller.changeGame(.fiveBall)
        XCTAssertFalse(store.hasUsedChallengeToday)
        XCTAssertTrue(controller.authorizeFirstBreak())
        XCTAssertTrue(store.hasUsedChallengeToday)
        XCTAssertTrue(controller.authorizeFirstBreak(), "Repeated callbacks belong to this same challenge")
        let restored = makeController(premium: false)
        restored.start(host: host, defaultGame: .nineBall)
        XCTAssertEqual(restored.game, .fiveBall)
        XCTAssertTrue(restored.authorizeFirstBreak())
        let seed = restored.draft?.seed
        restored.changeGame(.nineBall)
        XCTAssertTrue(restored.showUpgrade)
        XCTAssertEqual(restored.game, .fiveBall)
        XCTAssertEqual(restored.draft?.seed, seed)
    }

    func testCancellingUpgradePreservesResultAndPurchaseResumesRequestedGame() {
        store.complete(store.makeDraft(game: .nineBall, seed: 9))
        let controller = makeController(premium: false)
        controller.start(host: host, defaultGame: .nineBall)
        controller.replay()
        XCTAssertTrue(controller.showUpgrade)
        XCTAssertTrue(controller.isCompleted)
        controller.showUpgrade = false
        controller.subscriptionDismissed()
        XCTAssertTrue(controller.isCompleted)
        XCTAssertEqual(host.requests.count, 0)
        controller.changeGame(.fiveBall)
        controller.premiumProvider = { true }
        controller.showUpgrade = false
        controller.subscriptionDismissed()
        XCTAssertEqual(controller.game, .fiveBall)
        XCTAssertEqual(controller.phase, .manualRacked)
        XCTAssertNotNil(store.loadTodayCompletion())
        XCTAssertEqual(host.requests.count, 1)
    }

    func testFreeQuotaSurvivesAbandoningDraftAndResetsNextDay() {
        let controller = makeController(premium: false)
        controller.start(host: host, defaultGame: .nineBall)
        XCTAssertTrue(controller.authorizeFirstBreak())
        store.clearDraft()
        let fresh = makeController(premium: false)
        fresh.start(host: host, defaultGame: .nineBall)
        XCTAssertTrue(fresh.firstBreakRequiresPro)
        XCTAssertFalse(fresh.authorizeFirstBreak())
        clock = clock.addingTimeInterval(86400)
        XCTAssertFalse(fresh.firstBreakRequiresPro)
        XCTAssertTrue(fresh.authorizeFirstBreak())
        XCTAssertTrue(store.isToday(fresh.draft!.challengeDay))
    }

    func testRulesRequiredRerackKeepsChallengeAllowance() {
        let controller = makeController(premium: false)
        controller.start(host: host, defaultGame: .chineseEightBall)
        XCTAssertTrue(controller.authorizeFirstBreak())
        let request = host.requests.last!
        request.callback(BreakOutcome(board: host.board, game: request.game, seed: request.seed,
            pocketedKeys: [], cueScratched: false, terminalBallPocketed: false, settled: true,
            facts: ShotFacts(firstContactKey: "_1", pocketedKeys: [], cuePocketed: false,
                railOrPocketAfterContact: false, tableKeysBefore: ["_1", "_8"], railContactKeys: [])))
        XCTAssertTrue(controller.breakChoices.contains(.rerackByBreaker))
        controller.resolveBreakChoice(.rerackByBreaker)
        XCTAssertEqual(controller.phase, .manualRacked)
        XCTAssertTrue(controller.authorizeFirstBreak())
        XCTAssertFalse(controller.showUpgrade)
        controller.confirmRerack()
        XCTAssertTrue(controller.showUpgrade, "Voluntary rerack starts a new challenge")
    }

    func testProExpiryDoesNotInterruptAlreadyStartedChallenge() {
        let controller = makeController(premium: true)
        controller.start(host: host, defaultGame: .nineBall)
        XCTAssertTrue(controller.authorizeFirstBreak())
        controller.premiumProvider = { false }
        XCTAssertTrue(controller.authorizeFirstBreak())
        controller.confirmRerack()
        XCTAssertTrue(controller.showUpgrade)
    }

    func testProductionBreakRunnerRejectsBeforeSimulationWithoutPermission() throws {
        store.recordChallengeStarted(at: clock)
        let vm = PositionPlayViewModel()
        vm.setupScene()
        defer { vm.cancelDailyAttempt() }
        let controller = makeController(premium: false)
        controller.start(host: vm, defaultGame: .nineBall)
        let runner = try XCTUnwrap(vm.breakRunner)
        runner.breakNow()
        XCTAssertEqual(runner.phase, .racked)
        XCTAssertNil(runner.lastBreakSpin)
        XCTAssertTrue(controller.showUpgrade)
        XCTAssertNil(controller.draft?.firstBreakAt)
        controller.premiumProvider = { true }
        controller.showUpgrade = false
        runner.breakNow()
        XCTAssertEqual(runner.phase, .computing)
        XCTAssertNotNil(controller.draft?.firstBreakAt, "Production break entry commits the allowance")
    }

    func test_firstEntryWaitsForManualBreakWithoutCountingShot() {
        let controller = makeController()
        controller.start(host: host, defaultGame: .nineBall)

        XCTAssertEqual(host.requests.count, 1)
        XCTAssertEqual(controller.phase, .manualRacked)
        XCTAssertEqual(host.requests[0].seed, 100)
        XCTAssertEqual(controller.shotCount, 0)
        XCTAssertEqual(controller.foulCount, 0)
    }

    func test_realHostKeepsRackEditableUntilPlayerStrikes() throws {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        defer { vm.cancelDailyAttempt() }
        let controller = makeController()
        controller.start(host: vm, defaultGame: .nineBall)
        let runner = try XCTUnwrap(vm.breakRunner)
        XCTAssertEqual(runner.phase, .racked)
        XCTAssertTrue(runner.autoDeliverOnSettle, "停稳后直接交付，无需点击完成")
        XCTAssertEqual(runner.velocity, 10)
        XCTAssertEqual(runner.draggableCue.count, 1, "开球前母球必须可拖动")
        XCTAssertNil(runner.lastBreakSpin, "进入页面不得发起击球")
        runner.velocity = 7.5
        runner.spinX = 0.1
        runner.spinY = 0.2
        runner.nudgeAim(byDegrees: 0.1)
        XCTAssertEqual(runner.phase, .racked)
        XCTAssertEqual(runner.velocity, 7.5)
        XCTAssertEqual(runner.spinX, 0.1, accuracy: 0.001)
        XCTAssertEqual(runner.spinY, 0.2, accuracy: 0.001)
        XCTAssertNil(runner.lastBreakSpin, "调整参数不得自动击球")
        runner.applySettledBoardForTesting(vm.currentDailyClearanceBoard())
        XCTAssertNil(vm.breakRunner, "停稳交付后须退出开球模式")
        XCTAssertEqual(controller.phase, .playing)
        XCTAssertEqual(controller.playedVisitCount, 1, "开球计入规则杆数")
        XCTAssertEqual(controller.shotCount, 0, "开球不增加散局后的击球次数")
    }

    func test_legacyTerminalBreakNeverRetriesAutomatically() {
        var legacy = store.makeDraft(game: .nineBall, seed: 100)
        legacy.ruleState.ruleVersion = 1
        legacy.phase = .autoBreaking
        store.saveDraft(legacy)
        let controller = makeController()
        controller.start(host: host, defaultGame: .nineBall)
        XCTAssertEqual(controller.phase, .manualRacked)
        host.deliverLast(pocketed: ["_9"])
        XCTAssertEqual(host.requests.count, 2, "终局球落袋后只摆手动球架")
        XCTAssertEqual(host.requests.last?.seed, 101)
        XCTAssertEqual(controller.draft?.automaticRetryCount, 0)
        XCTAssertEqual(controller.phase, .failed)
        XCTAssertEqual(controller.shotCount, 0)
    }

    func test_resumePlayingDraftRestoresBoardAndSeedWithoutNewBreak() throws {
        var draft = store.makeDraft(game: .sixBall, seed: 66)
        draft.phase = .playing
        draft.board = host.board
        draft.shotCount = 3
        store.saveDraft(draft)

        let controller = makeController()
        controller.start(host: host, defaultGame: .chineseEightBall)

        XCTAssertTrue(host.requests.isEmpty)
        XCTAssertEqual(controller.draft?.seed, 66)
        XCTAssertEqual(controller.shotCount, 3)
        XCTAssertEqual(try XCTUnwrap(host.board.onTable["_9"]).x, 0.2)
    }

    func test_resumeDeliveredBoardBeforeFirstShotRemainsShootableWithoutNewBreak() {
        var draft = store.makeDraft(game: .nineBall, seed: 90)
        draft.phase = .playing
        draft.board = host.board
        draft.shotCount = 0
        store.saveDraft(draft)

        let controller = makeController()
        controller.start(host: host, defaultGame: .chineseEightBall)

        XCTAssertTrue(host.requests.isEmpty, "已交付球形不能重复自动开球")
        XCTAssertEqual(controller.phase, .playing)
        XCTAssertEqual(controller.shotCount, 0)
        XCTAssertFalse(controller.legalTargetKeys(tableKeys: Set(host.board.onTableKeys)).isEmpty)
    }

    func test_resumeFailedDraftRestoresBoardAndWaitsForExplicitRerack() {
        var draft = store.makeDraft(game: .fiveBall, seed: 50)
        draft.phase = .failed
        draft.board = host.board
        draft.shotCount = 3
        store.saveDraft(draft)

        let controller = makeController()
        controller.start(host: host, defaultGame: .chineseEightBall)

        XCTAssertTrue(host.requests.isEmpty, "失败局有落盘球形时不得自动覆盖")
        XCTAssertEqual(controller.phase, .failed)
        XCTAssertEqual(controller.shotCount, 3)
        XCTAssertEqual(controller.requestRerack(), .confirmationRequired)
    }

    func test_resumeManualRackDoesNotAutomaticallyStrike() {
        var draft = store.makeDraft(game: .fiveBall, seed: 55)
        draft.phase = .manualRacked
        store.saveDraft(draft)

        let controller = makeController()
        controller.start(host: host, defaultGame: .chineseEightBall)

        XCTAssertEqual(host.requests.count, 1)
        XCTAssertEqual(controller.phase, .manualRacked)
    }

    func test_completedDayWaitsForExplicitReplayAndKeepsCompletion() {
        let draft = store.makeDraft(game: .nineBall, seed: 9)
        let completed = store.complete(draft)
        let controller = makeController(seed: 200)

        controller.start(host: host, defaultGame: .chineseEightBall)
        XCTAssertTrue(controller.isCompleted)
        XCTAssertTrue(host.requests.isEmpty)

        controller.replay()
        XCTAssertFalse(controller.isCompleted)
        XCTAssertEqual(host.requests.count, 1)
        XCTAssertEqual(controller.phase, .manualRacked)
        XCTAssertEqual(store.loadTodayCompletion()?.completedAt, completed.completedAt)
    }

    func test_terminalShotPersistsOnceAndIgnoresDuplicateCallbackAfterRestore() throws {
        let controller = makeController()
        controller.start(host: host, defaultGame: .nineBall)
        host.deliverLast()
        host.board = BoardSnapshot(onTable: ["cueBall": CanvasPoint(x: 0.5, y: 0.25)])
        let terminal = ShotFacts(firstContactKey: "_9", pocketedKeys: ["_9"],
                                 cuePocketed: false, railOrPocketAfterContact: true,
                                 tableKeysBefore: ["_9"])
        controller.prepareShot()
        XCTAssertTrue(try XCTUnwrap(controller.handleShotSettled(terminal)).completed)
        let first = try XCTUnwrap(store.loadTodayCompletion())
        XCTAssertEqual(first.shotCount, 1)
        XCTAssertNil(store.loadTodayDraft())
        clock = clock.addingTimeInterval(30)
        XCTAssertNil(controller.handleShotSettled(terminal))
        controller.flushActivity()
        let restored = makeController()
        restored.start(host: host, defaultGame: .nineBall)
        XCTAssertTrue(restored.isCompleted)
        XCTAssertNil(restored.handleShotSettled(terminal))
        let persisted = try XCTUnwrap(store.loadTodayCompletion())
        XCTAssertEqual(persisted.shotCount, first.shotCount)
        XCTAssertEqual(persisted.completedAt, first.completedAt)
        XCTAssertEqual(persisted.activeDurationSeconds, first.activeDurationSeconds)
        XCTAssertNil(store.loadTodayDraft())
    }

    func test_scratchRestoresCueAndFoulNineContinues() throws {
        for terminal in [false, true] {
            let controller = makeController()
            controller.start(host: host, defaultGame: .nineBall)
            host.deliverLast()
            host.board = BoardSnapshot(onTable: ["_9": CanvasPoint(x: 0.6, y: 0.2)])
            let count = host.cueRestores
            let facts = ShotFacts(firstContactKey: "_9", pocketedKeys: terminal ? ["_9"] : [],
                                  cuePocketed: true, railOrPocketAfterContact: true, tableKeysBefore: ["_9"])
            controller.prepareShot()
            let ruling = try XCTUnwrap(controller.handleShotSettled(facts))
            XCTAssertTrue(ruling.foul)
            XCTAssertFalse(ruling.failed)
            XCTAssertEqual(host.cueRestores, count + 1)
            let saved = try XCTUnwrap(store.loadTodayDraft())
            XCTAssertEqual(saved.board?.onTable["cueBall"] != nil, true)
            XCTAssertEqual(saved.foulCount, 1)
            store.clearDraft()
        }
    }

    func test_rerackNeedsConfirmationAfterFirstUserShotAndResetsAfterConfirm() {
        let controller = makeController()
        controller.start(host: host, defaultGame: .nineBall)
        host.deliverLast()
        controller.prepareShot()
        _ = controller.handleShotSettled(ShotFacts(
            firstContactKey: "_1",
            pocketedKeys: [],
            cuePocketed: false,
            railOrPocketAfterContact: true,
            tableKeysBefore: ["_1", "_9"]
        ))

        XCTAssertEqual(controller.requestRerack(), .confirmationRequired)
        controller.confirmRerack()
        XCTAssertEqual(controller.shotCount, 0)
        XCTAssertEqual(controller.foulCount, 0)
        XCTAssertEqual(controller.phase, .manualRacked)
    }

    func test_timerFlushIsIdempotentAndDoesNotCountBackgroundTime() {
        let controller = makeController()
        controller.start(host: host, defaultGame: .nineBall)
        clock = clock.addingTimeInterval(10)
        controller.flushActivity()
        XCTAssertEqual(controller.elapsedSeconds, 10, accuracy: 0.001)

        clock = clock.addingTimeInterval(100)
        controller.flushActivity()
        XCTAssertEqual(controller.elapsedSeconds, 10, accuracy: 0.001)

        controller.resumeActivity()
        clock = clock.addingTimeInterval(5)
        XCTAssertEqual(controller.elapsedSeconds, 15, accuracy: 0.001)
    }

    func test_layoutEditingAndBackgroundKeepBoardAndExcludePausedTime() {
        let controller = makeController()
        controller.start(host: host, defaultGame: .nineBall)
        host.deliverLast()
        let phase = controller.phase, shots = controller.shotCount
        clock = clock.addingTimeInterval(10)
        controller.flushActivity() // Enter editor.
        clock = clock.addingTimeInterval(60)
        controller.flushActivity() // Background while editor is still open.
        clock = clock.addingTimeInterval(100)
        XCTAssertEqual(controller.elapsedSeconds, 10, accuracy: 0.001)
        XCTAssertEqual(controller.phase, phase)
        XCTAssertEqual(controller.shotCount, shots)
        controller.resumeActivity() // Save/cancel exit, foreground only.
        controller.resumeActivity()
        clock = clock.addingTimeInterval(20)
        controller.flushActivity()
        XCTAssertEqual(controller.elapsedSeconds, 30, accuracy: 0.001)
    }

    func test_eachSettledShotPersistsElapsedTimeWithoutDoubleCounting() throws {
        let controller = makeController()
        controller.start(host: host, defaultGame: .nineBall)
        host.deliverLast()
        let facts = ShotFacts(firstContactKey: "_1", pocketedKeys: [], cuePocketed: false,
                              railOrPocketAfterContact: true, tableKeysBefore: ["_1", "_9"])
        clock = clock.addingTimeInterval(12)
        controller.prepareShot()
        controller.handleShotSettled(facts)
        XCTAssertEqual(try XCTUnwrap(store.loadTodayDraft()).activeDurationSeconds, 12, accuracy: 0.001)
        clock = clock.addingTimeInterval(8)
        controller.prepareShot()
        controller.handleShotSettled(facts)
        XCTAssertEqual(try XCTUnwrap(store.loadTodayDraft()).activeDurationSeconds, 20, accuracy: 0.001)
        // Recreate from disk without calling stop/flush on the previous controller.
        clock = clock.addingTimeInterval(100)
        let restored = makeController()
        restored.start(host: host, defaultGame: .nineBall)
        XCTAssertEqual(restored.shotCount, 2)
        XCTAssertEqual(restored.elapsedSeconds, 20, accuracy: 0.001)
        clock = clock.addingTimeInterval(3)
        restored.flushActivity()
        restored.flushActivity()
        XCTAssertEqual(try XCTUnwrap(store.loadTodayDraft()).activeDurationSeconds, 23, accuracy: 0.001)
    }

    func test_allFiveGamesWaitForManualBreakAndBecomeShootable() {
        for game in DailyClearanceGame.allCases {
            store.clearDraft()
            store.clearCompletion()
            host.requests.removeAll()

            let controller = makeController(seed: UInt64(game.rawValue.count + 1))
            controller.start(host: host, defaultGame: game)
            XCTAssertEqual(host.requests.count, 1, "\(game.displayName) 应摆好球架")
            XCTAssertEqual(controller.phase, .manualRacked, "\(game.displayName) 首次开球须等待用户击打")
            XCTAssertEqual(host.requests[0].game, game.rackGame)

            host.deliverLast()
            XCTAssertEqual(controller.phase, .playing, "\(game.displayName) 开球交付后应可击球")
            XCTAssertEqual(controller.shotCount, 0, "开球不计普通击球次数")
            XCTAssertFalse(controller.legalTargetKeys(tableKeys: Set(host.board.onTableKeys)).isEmpty)
        }
    }

    func test_resumeLegacyAutomaticBreakBecomesManualWithSameSeed() {
        var draft = store.makeDraft(game: .nineBall, seed: 909)
        draft.phase = .autoBreaking
        store.saveDraft(draft)

        let controller = makeController(seed: 1)
        controller.start(host: host, defaultGame: .chineseEightBall)

        XCTAssertEqual(host.requests.count, 1)
        XCTAssertEqual(store.loadTodayDraft()?.phase, .manualRacked)
        XCTAssertEqual(host.requests[0].seed, 909)
        XCTAssertEqual(controller.phase, .manualRacked)
        XCTAssertEqual(controller.shotCount, 0)
    }

    func test_settingChangeDoesNotReplaceGameInExistingDraft() {
        var draft = store.makeDraft(game: .chineseEightBall, seed: 8)
        draft.phase = .playing
        draft.board = host.board
        store.saveDraft(draft)

        let controller = makeController()
        controller.start(host: host, defaultGame: .nineBall)

        XCTAssertEqual(controller.game, .chineseEightBall)
        XCTAssertTrue(host.requests.isEmpty, "恢复草稿不应按新默认玩法重新开局")
    }
    func testSettledFoulRemainsRecordedAndIgnoresDuplicateSettlement() throws {
        var draft = store.makeDraft(game: .chineseEightBall, seed: 1)
        draft.phase = .playing; draft.board = host.board
        draft.ruleState.assignedGroup = .solid
        store.saveDraft(draft)
        let controller = makeController()
        controller.start(host: host, defaultGame: .chineseEightBall)
        controller.prepareShot()
        let shot = ShotFacts(firstContactKey: "_9", pocketedKeys: [], cuePocketed: false,
            railOrPocketAfterContact: true, tableKeysBefore: ["_1", "_9", "_8"])
        XCTAssertTrue(try XCTUnwrap(controller.handleShotSettled(shot)).foul)
        XCTAssertEqual(controller.assignedGroup, .stripe)
        XCTAssertEqual(controller.foulCount, 1)
        XCTAssertNil(controller.handleShotSettled(shot))
        XCTAssertEqual(controller.shotCount, 1)
        XCTAssertEqual(controller.playedVisitCount, 1)
        controller.previousStep()
        XCTAssertEqual(controller.foulCount, 1)
        XCTAssertEqual(controller.shotCount, 1)
        XCTAssertEqual(store.loadTodayDraft()?.ruleState.currentPlayer, .b)
    }

    func testScoredStrokeUsesCalledPocketAndSettledBoardThenPersistsFinalScore() throws {
        var draft = store.makeDraft(game: .nineBall, seed: 42)
        draft.phase = .playing
        draft.board = host.board
        store.saveDraft(draft)
        var controller = makeController()
        controller.start(host: host, defaultGame: .nineBall)
        controller.toggleScoring()
        XCTAssertEqual(controller.shotPlan?.first, "_1")
        XCTAssertFalse(controller.canStartShot())
        XCTAssertTrue(controller.editPlan { $0.choose(pocket: 4, in: $1) })
        XCTAssertTrue(controller.canGoBack)
        controller.previousStep()
        XCTAssertEqual(controller.shotPlan?.step, .pocket1)
        XCTAssertTrue(controller.editPlan { $0.choose(pocket: 4, in: $1) })
        XCTAssertTrue(controller.editPlan { $0.choose(pocket: 4, in: $1) })
        controller.prepareShot()
        let rest: [String: SIMD2<Float>] = ["cueBall": SIMD2(0.02, 0.20), "_9": SIMD2(0, -0.1)]
        var facts = ShotFacts.extract(events: [.init(time: 1, kind: .ballBall(ballA: "cue", ballB: "obj")),
            .init(time: 2, kind: .pocket(ball: "obj", pocketId: "pocket_4"))], cueName: "cue",
            tableKeys: ["cueBall", "_1", "_9"], pocketed: ["_1"], key: { $0 == "obj" ? "_1" : "cueBall" })
        facts.scoringRest = rest
        host.board.onTable.removeValue(forKey: "_1")
        XCTAssertNotNil(controller.handleShotSettled(facts))
        let result = try XCTUnwrap(controller.scoreSummary?.last)
        XCTAssertGreaterThan(result.value, 0)
        XCTAssertNotNil(result.comfort)
        XCTAssertEqual(controller.scoreNotice, result.text)
        XCTAssertNil(controller.handleShotSettled(facts))
        XCTAssertEqual(controller.shotPlan?.first, "_9")
        XCTAssertEqual(controller.shotPlan?.firstPocket, 4)
        controller.stop()
        controller = makeController()
        controller.start(host: host, defaultGame: .nineBall)
        XCTAssertEqual(controller.scoreSummary?.count, 1)
        XCTAssertEqual(controller.scoreSummary?.total, result.value)
        controller.prepareShot()
        let final = ShotFacts(firstContactKey: "_9", pocketedKeys: ["_9"], cuePocketed: false,
            railOrPocketAfterContact: true, tableKeysBefore: ["_9"])
        XCTAssertTrue(try XCTUnwrap(controller.handleShotSettled(final)).completed)
        XCTAssertEqual(store.loadTodayCompletion()?.scoringSummary?.total, result.value)
        XCTAssertEqual(controller.scoreSummary?.text, String(format: "平均走位 %.1f 分 · 计分 1 杆", result.value))
    }

    func testScoringZeroMissingEvidenceAndEarlyFinish() throws {
        let draft = store.makeDraft(game: .nineBall, seed: 43)
        let plan = DailyShotPlan(first: "_1", firstPocket: 4, second: "_2", secondPocket: 0)
        var state = DailyPositionScoring()
        var facts = ShotFacts(firstContactKey: "_1", pocketedKeys: ["_1"], cuePocketed: false,
            railOrPocketAfterContact: true, tableKeysBefore: ["_1", "_2", "_9"])
        var ruling = DailyClearanceRuling(message: "继续击球")
        XCTAssertTrue(try XCTUnwrap(state.settle(facts, ruling: ruling, frozen: plan, draft: draft)).contains("未评分"))
        facts.scoringRest = ["cueBall": .zero, "_2": SIMD2(0.3, 0.1)]
        XCTAssertTrue(try XCTUnwrap(state.settle(facts, ruling: ruling, frozen: plan, draft: draft)).contains("缺少落袋"))
        XCTAssertEqual(state.summary.text, "本局无可评分杆")
        facts.pocketIDs = ["_1": "pocket_0"]
        XCTAssertEqual(state.settle(facts, ruling: ruling, frozen: plan, draft: draft), "本杆走位 0.0 分 · 第一球未进指定袋")
        XCTAssertEqual(state.summary.text, "平均走位 0.0 分 · 计分 1 杆")
        ruling.completed = true
        XCTAssertNil(state.settle(facts, ruling: ruling, frozen: plan, draft: draft))
        XCTAssertEqual(state.summary.count, 1)
        ruling.completed = false
        ruling.failed = true
        ruling.message = "黑八提前落袋"
        _ = state.settle(facts, ruling: ruling, frozen: plan, draft: draft)
        XCTAssertEqual(state.failureMessage, ruling.message)
        XCTAssertEqual(state.summary.count, 2)
    }

    func testOpenTablePlanAndSummaryWithMixedScores() {
        var draft = store.makeDraft(game: .chineseEightBall, seed: 44)
        draft.phase = .playing
        draft.board = BoardSnapshot(onTable: Dictionary(uniqueKeysWithValues: ["cueBall", "_1", "_2", "_8", "_9"].map { ($0, CanvasPoint(x: 0.5, y: 0.25)) }))
        var plan = DailyShotPlan()
        XCTAssertTrue(plan.choose(ball: "_1", in: draft))
        XCTAssertTrue(plan.choose(pocket: 1, in: draft))
        XCTAssertFalse(plan.choose(ball: "_9", in: draft))
        XCTAssertTrue(plan.choose(ball: "_2", in: draft))
        XCTAssertTrue(plan.choose(pocket: 4, in: draft))
        XCTAssertTrue(plan.choose(ball: "_8", in: draft))
        XCTAssertNil(plan.missingStep(in: draft))
        plan.goBack(in: draft)
        XCTAssertEqual(plan.step, .pocket2)
        XCTAssertNil(plan.third)
        plan.goBack(in: draft)
        XCTAssertEqual(plan.step, .ball2)
        XCTAssertNil(plan.secondPocket)
        var summary = DailyScoreSummary()
        for value in [90.0, 0, 90] { summary.record(.init(value: value, reason: nil)) }
        XCTAssertEqual(summary.text, "平均走位 60.0 分 · 计分 3 杆")
    }

    func testScoringOffAndSameDayCompletionOwnership() throws {
        var earlier = store.makeDraft(game: .nineBall, seed: 1)
        var scoring = DailyPositionScoring()
        scoring.summary.record(.init(value: 90, reason: nil))
        earlier.scoring = scoring
        _ = store.complete(earlier)
        var current = store.makeDraft(game: .nineBall, seed: 2)
        current.phase = .playing
        current.board = BoardSnapshot(onTable: ["_9": CanvasPoint(x: 0.5, y: 0.08)])
        store.saveDraft(current)
        let controller = makeController()
        controller.start(host: host, defaultGame: .nineBall)
        XCTAssertFalse(controller.scoringEnabled)
        XCTAssertNil(controller.scoreSummary)
        controller.toggleScoring()
        controller.toggleScoring()
        XCTAssertEqual(store.loadTodayDraft()?.scoring?.enabled, false)
        controller.prepareShot()
        let shot = ShotFacts(firstContactKey: "_9", pocketedKeys: ["_9"], cuePocketed: false,
            railOrPocketAfterContact: true, tableKeysBefore: ["_9"])
        XCTAssertTrue(try XCTUnwrap(controller.handleShotSettled(shot)).completed)
        XCTAssertEqual(controller.scoreSummary?.text, "本局无可评分杆")
        XCTAssertEqual(store.loadTodayCompletion()?.scoringSummary?.text, "平均走位 90.0 分 · 计分 1 杆")
    }

    func testFailedGameKeepsZeroInScoreAfterRestore() throws {
        var draft = store.makeDraft(game: .chineseEightBall, seed: 3)
        draft.phase = .playing
        draft.ruleState.assignedGroup = .solid
        draft.board = BoardSnapshot(onTable: ["cueBall": CanvasPoint(x: 0.5, y: 0.2),
            "_1": CanvasPoint(x: 0.5, y: 0.08), "_8": CanvasPoint(x: 0.8, y: 0.08)])
        store.saveDraft(draft)
        let controller = makeController()
        controller.start(host: host, defaultGame: draft.game)
        controller.toggleScoring()
        XCTAssertTrue(controller.editPlan { $0.choose(ball: "_1", in: $1) })
        XCTAssertTrue(controller.editPlan { $0.choose(pocket: 4, in: $1) })
        XCTAssertTrue(controller.editPlan { $0.choose(ball: "_8", in: $1) })
        XCTAssertTrue(controller.editPlan { $0.choose(pocket: 1, in: $1) })
        controller.prepareShot()
        var shot = ShotFacts(firstContactKey: "_1", pocketedKeys: ["_8"], cuePocketed: false,
            railOrPocketAfterContact: true, tableKeysBefore: ["_1", "_8"])
        shot.scoringRest = ["cueBall": .zero, "_1": SIMD2(0.1, 0.2)]
        XCTAssertTrue(try XCTUnwrap(controller.handleShotSettled(shot)).failed)
        let restored = makeController()
        restored.start(host: host, defaultGame: draft.game)
        XCTAssertEqual(restored.phase, .failed)
        XCTAssertEqual(restored.scoreSummary?.text, "平均走位 0.0 分 · 计分 1 杆")
        XCTAssertTrue(restored.statusText.contains("黑八提前"))
    }

    func testReusedSeedDoesNotAdmitOldBreakCallbackAndNineBreakCompletesOnce() {
        let controller = makeController(seed: 10)
        controller.start(host: host, defaultGame: .nineBall)
        let old = host.requests[0]
        controller.confirmRerack()
        old.callback(BreakOutcome(board: host.board, game: .nineBall, seed: 10,
            pocketedKeys: [], cueScratched: false, terminalBallPocketed: false, settled: true))
        XCTAssertEqual(controller.phase, .manualRacked)
        let current = host.requests.last!
        let facts = ShotFacts(firstContactKey: "_1", pocketedKeys: ["_9"], cuePocketed: false,
            railOrPocketAfterContact: true, tableKeysBefore: ["_1", "_9"])
        let outcome = BreakOutcome(board: host.board, game: .nineBall, seed: 10,
            pocketedKeys: ["_9"], cueScratched: false, terminalBallPocketed: true, settled: true, facts: facts)
        current.callback(outcome)
        XCTAssertTrue(controller.isCompleted)
        XCTAssertEqual(controller.completion?.completionKind, .breakNine)
        current.callback(outcome)
        XCTAssertEqual(controller.shotCount, 0)
        XCTAssertEqual(host.requests.count, 2)
    }

}

extension DailyClearanceControllerTests {
    func testDisplayPreferenceOverwriteKeepsCurrentRackAndGame() throws {
        let preferences = TablePreferencesStore(defaults: defaults)
        let vm = PositionPlayViewModel()
        vm.scene.tablePreferencePage = .dailyClearance
        vm.scene.tablePreferences = preferences.snapshot(for: .dailyClearance)
        vm.setupScene(loadsDefaultLayout: false)
        defer { vm.cancelDailyAttempt() }
        let controller = makeController()
        controller.start(host: vm, defaultGame: .nineBall)
        let runner = try XCTUnwrap(vm.breakRunner)
        runner.velocity = 7.5
        runner.spinX = 0.1
        runner.spinY = 0.2
        let original = vm.currentDailyClearanceBoard()
        let identities = vm.scene.allBallNodes.mapValues { ObjectIdentifier($0) }
        let phase = controller.phase
        let defaultsBefore = defaults.dictionaryRepresentation()
        for field in TablePreferenceField.allCases {
            preferences.apply(field, value: 1)
            vm.scene.tablePreferences = preferences.snapshot(for: .dailyClearance)
            vm.hides3DShotAssists = !vm.scene.tablePreferences!.enabled(.shows3DTrajectory)
            vm.scene.setTableGridVisible(vm.scene.tablePreferences!.enabled(.grid))
            vm.cameraMode = vm.scene.tablePreferences!.enabled(.view3D) ? .perspective3D : .topDown2D
            vm.scene.setCameraMode(vm.cameraMode, animated: false)
            vm.refreshShotAssistVisibility()
        }
        UserPreferences(defaults: defaults).selectDailyClearanceGame(.chineseEightBall)
        XCTAssertTrue(vm.breakRunner === runner)
        XCTAssertEqual(controller.game, .nineBall, "默认玩法只用于下一个新局")
        XCTAssertEqual(controller.phase, phase)
        XCTAssertEqual(controller.shotCount, 0)
        XCTAssertEqual(controller.foulCount, 0)
        XCTAssertEqual(runner.velocity, 7.5)
        XCTAssertEqual(runner.spinX, 0.1, accuracy: 0.001)
        XCTAssertEqual(runner.spinY, 0.2, accuracy: 0.001)
        XCTAssertEqual(vm.scene.allBallNodes.mapValues { ObjectIdentifier($0) }, identities)
        let after = vm.currentDailyClearanceBoard()
        XCTAssertEqual(Set(after.onTable.keys), Set(original.onTable.keys))
        for (key, point) in original.onTable {
            XCTAssertEqual(try XCTUnwrap(after.onTable[key]).x, point.x)
            XCTAssertEqual(try XCTUnwrap(after.onTable[key]).y, point.y)
        }
        for (key, value) in defaultsBefore where key != TablePreferencesStore.storageKey {
            // Settings writes must leave the existing draft and records untouched.
            if key.hasPrefix("dailyClearance"), key != DailyClearanceStoreKey.preferredGame {
                XCTAssertEqual(String(describing: defaults.object(forKey: key)!), String(describing: value), key)
            }
        }
    }
}
