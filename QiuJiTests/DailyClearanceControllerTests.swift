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

    private func makeController(seed: UInt64 = 100) -> DailyClearanceController {
        DailyClearanceController(
            store: store,
            now: { self.clock },
            seedGenerator: { seed }
        )
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
        XCTAssertEqual(runner.velocity, 8)
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
    func testUndoRestoresRulesCountsAndIgnoresDuplicateSettlement() throws {
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
        XCTAssertTrue(controller.canUndo)
        controller.undoShot()
        XCTAssertEqual(controller.assignedGroup, .solid)
        XCTAssertEqual(controller.foulCount, 0)
        XCTAssertEqual(controller.shotCount, 0)
        XCTAssertEqual(controller.playedVisitCount, 0)
        XCTAssertFalse(controller.canUndo)
        XCTAssertEqual(store.loadTodayDraft()?.ruleState.currentPlayer, .a)
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
