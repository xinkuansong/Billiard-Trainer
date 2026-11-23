import XCTest
@testable import QiuJi

final class DailyClearanceStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var now: Date!
    private var calendar: Calendar!
    private var messages: [String] = []

    override func setUp() {
        super.setUp()
        suiteName = "DailyClearanceStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 12))!
        messages = []
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func makeStore() -> DailyClearanceStore {
        DailyClearanceStore(
            defaults: defaults,
            calendar: calendar,
            now: { self.now },
            log: { self.messages.append($0) }
        )
    }

    func test_draftRoundTripPreservesBoardAndRuleState() throws {
        let store = makeStore()
        var draft = store.makeDraft(game: .chineseEightBall, seed: 42)
        draft.phase = .playing
        draft.board = BoardSnapshot(onTable: [
            "cueBall": CanvasPoint(x: 0.75, y: 0.25),
            "_8": CanvasPoint(x: 0.2, y: 0.1)
        ])
        draft.ruleState = DailyClearanceRuleState(assignedGroup: .stripe)
        draft.shotCount = 7
        draft.foulCount = 2
        draft.activeDurationSeconds = 91
        store.saveDraft(draft)

        let restored = try XCTUnwrap(store.loadTodayDraft())
        XCTAssertEqual(restored.seed, 42)
        XCTAssertEqual(restored.automaticRetryCount, 0)
        XCTAssertEqual(restored.game, .chineseEightBall)
        XCTAssertEqual(restored.phase, .playing)
        XCTAssertEqual(restored.ruleState.assignedGroup, .stripe)
        XCTAssertEqual(restored.shotCount, 7)
        XCTAssertEqual(restored.foulCount, 2)
        XCTAssertEqual(restored.board?.onTable["cueBall"]?.x, 0.75)
        XCTAssertEqual(restored.board?.onTable["_8"]?.y, 0.1)
    }

    func test_yesterdayDraftIsDiscardedOnNewDay() {
        let store = makeStore()
        var draft = store.makeDraft(game: .nineBall, seed: 9)
        draft.challengeDay = calendar.date(byAdding: .day, value: -1, to: now)!
        store.saveDraft(draft)

        XCTAssertNil(store.loadTodayDraft())
        XCTAssertNil(defaults.data(forKey: DailyClearanceStoreKey.activeDraft))
        XCTAssertTrue(messages.contains { $0.contains("跨日草稿") })
    }

    func test_completionClearsDraftAndAllowsReplayWithoutDuplicateCompletion() throws {
        let store = makeStore()
        var draft = store.makeDraft(game: .sixBall, seed: 6)
        draft.shotCount = 5
        draft.foulCount = 1
        store.saveDraft(draft)

        let completion = store.complete(draft)
        XCTAssertEqual(completion.shotCount, 5)
        XCTAssertNil(store.loadTodayDraft())
        XCTAssertTrue(store.hasCompletedToday())

        let replay = store.makeDraft(game: .fourBall, seed: 44)
        store.saveDraft(replay)
        XCTAssertEqual(try XCTUnwrap(store.loadTodayDraft()).game, .fourBall)
        XCTAssertEqual(try XCTUnwrap(store.loadTodayCompletion()).game, .sixBall)
    }

    func test_oldCompletionDoesNotMarkTodayComplete() {
        let store = makeStore()
        let old = DailyClearanceCompletion(
            challengeDay: calendar.date(byAdding: .day, value: -1, to: now)!,
            game: .nineBall,
            shotCount: 4,
            foulCount: 0,
            activeDurationSeconds: 30,
            completedAt: calendar.date(byAdding: .day, value: -1, to: now)!
        )
        store.saveCompletion(old)
        XCTAssertFalse(store.hasCompletedToday())
    }

    func test_corruptedDraftIsReportedAndOnlyCorruptedKeyIsCleared() {
        let store = makeStore()
        let validCompletion = DailyClearanceCompletion(
            challengeDay: store.day(containing: now),
            game: .nineBall,
            shotCount: 3,
            foulCount: 0,
            activeDurationSeconds: 12,
            completedAt: now
        )
        store.saveCompletion(validCompletion)
        defaults.set(Data("not-json".utf8), forKey: DailyClearanceStoreKey.activeDraft)

        XCTAssertNil(store.loadTodayDraft())
        XCTAssertTrue(messages.contains { $0.contains("草稿损坏") })
        XCTAssertNil(defaults.data(forKey: DailyClearanceStoreKey.activeDraft))
        XCTAssertTrue(store.hasCompletedToday())
    }
}
