import XCTest
@testable import QiuJi

@MainActor
final class MultiBallPracticeTests: XCTestCase {
    private let suite = "MultiBallPracticeTests.\(UUID())"
    private var defaults: UserDefaults { UserDefaults(suiteName: suite)! }
    override func tearDown() { defaults.removePersistentDomain(forName: suite) }
    func testSupportedCountsAndPreferencesRejectLegacySevenEight() throws {
        XCTAssertEqual(MultiBallConfiguration.rotationCounts, [4, 5, 6, 9])
        let name = "MultiBallTests.\(UUID())"
        let store = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { store.removePersistentDomain(forName: name) }
        var config = MultiBallConfiguration(); config.rotationCount = 7
        store.set(try JSONEncoder().encode(config), forKey: "multiBall.configuration.v1")
        XCTAssertEqual(MultiBallConfiguration.load(defaults: store), .init())
        config = .init(); config.game = .chineseEight; config.ownCount = 8; config.randomOpponents = true
        config.save(defaults: store)
        XCTAssertEqual(MultiBallConfiguration.load(defaults: store), config)
    }
    func testChineseRandomDeletionPreservesCoordinatesAndBothGroups() throws {
        var config = MultiBallConfiguration(); config.game = .chineseEight
        let rack = try MultiBallBank.shared.draw(configuration: config, excluding: nil)
        let url = try XCTUnwrap(Bundle.main.url(forResource: "bank-15", withExtension: "json", subdirectory: "MultiBallBank"))
        let bank = try JSONDecoder().decode(MultiBallBank.Envelope.self, from: Data(contentsOf: url))
        let base = try XCTUnwrap(bank.boards.first(where: { $0.id == rack.sourceID }))
        var random = SystemRandomNumberGenerator(), groups = Set<Bool>(), opponentCounts = Set<Int>(), variants = Set<Set<String>>()
        for count in 4...8 {
            config.ownCount = count
            for randomOpponents in [false, true] {
                config.randomOpponents = randomOpponents
                for _ in 0..<100 {
                    let value = MultiBallRack.make(base: base, configuration: config, using: &random)
                    XCTAssertEqual(value.ownKeys.count, count)
                    XCTAssertTrue(value.ownKeys.contains("_8"))
                    XCTAssertTrue(value.ownKeys.isDisjoint(with: value.opponentKeys))
                    XCTAssertEqual(value.board.onTable.count, count + value.opponentKeys.count + 1)
                    XCTAssertTrue(randomOpponents ? (1...7).contains(value.opponentKeys.count) : value.opponentKeys.isEmpty)
                    let solid = value.ownKeys.subtracting(["_8"]).allSatisfy { Int($0.dropFirst())! < 8 }
                    groups.insert(solid)
                    XCTAssertTrue(value.ownKeys.subtracting(["_8"]).allSatisfy { (Int($0.dropFirst())! < 8) == solid })
                    XCTAssertTrue(value.opponentKeys.allSatisfy { (Int($0.dropFirst())! < 8) != solid })
                    for key in value.paletteKeys {
                        XCTAssertEqual(value.board.onTable[key]?.x, base.balls[key]?[0])
                        XCTAssertEqual(value.board.onTable[key]?.y, base.balls[key]?[1])
                    }
                    let cue = try XCTUnwrap(value.board.onTable[PositionPlayBall.cueKey])
                    XCTAssertTrue(value.board.onTable.filter { $0.key != PositionPlayBall.cueKey }.values.allSatisfy { hypot($0.x-cue.x, $0.y-cue.y) > 0.0225 })
                    if randomOpponents { opponentCounts.insert(value.opponentKeys.count) }
                    variants.insert(value.ownKeys.union(value.opponentKeys))
                }
            }
        }
        XCTAssertEqual(groups.count, 2); XCTAssertEqual(opponentCounts, Set(1...7)); XCTAssertGreaterThan(variants.count, 20)
    }
    func testEveryRotationBankLoadsAndNextAvoidsImmediateRepeat() throws {
        var config = MultiBallConfiguration()
        for count in MultiBallConfiguration.rotationCounts {
            config.rotationCount = count
            let first = try MultiBallBank.shared.draw(configuration: config, excluding: nil)
            let second = try MultiBallBank.shared.draw(configuration: config, excluding: first.sourceID)
            XCTAssertNotEqual(first.sourceID, second.sourceID)
            XCTAssertEqual(first.ownKeys, Set(MultiBallConfiguration.numbers(count).map { "_\($0)" }))
            XCTAssertTrue(first.opponentKeys.isEmpty)
        }
    }
    func testRotationRequiresOrderButAllowsOtherCollisions() {
        XCTAssertEqual(MultiBallRuling.judge(game: .rotation, remaining: ["_1", "_2"], first: "_1", potted: ["_1"], complete: true), .continued(["_2"]))
        for (first, pots) in [("_2", Set(["_1"])), ("_1", Set(["_2"])), ("_1", Set(["_1", "_2"])), ("_1", Set<String>())] {
            if case .continued = MultiBallRuling.judge(game: .rotation, remaining: ["_1", "_2"], first: first, potted: pots, complete: true) { XCTFail("Out-of-order stroke accepted") }
        }
        XCTAssertEqual(MultiBallRuling.judge(game: .rotation, remaining: ["_9"], first: "_9", potted: ["_9"], complete: true), .continued([]))
    }
    func testChineseGroupBlackEightAndScratchPriority() {
        let own: Set<String> = ["_1", "_3", "_8"]
        XCTAssertEqual(MultiBallRuling.judge(game: .chineseEight, remaining: own, first: "_3", potted: ["_1", "_3", "_12"], complete: true), .continued(["_8"]))
        XCTAssertEqual(MultiBallRuling.judge(game: .chineseEight, remaining: ["_8"], first: "_8", potted: ["_8"], complete: true), .continued([]))
        for (remaining, first, pots, complete) in [(own, "_12", Set(["_1"]), true), (own, "_1", Set(["_12"]), true), (Set(["_1", "_8"]), "_1", Set(["_1", "_8"]), true), (Set(["_8"]), "_8", Set(["_8", PositionPlayBall.cueKey]), true), (own, "_1", Set(["_1"]), false)] {
            if case .continued = MultiBallRuling.judge(game: .chineseEight, remaining: remaining, first: first, potted: pots, complete: complete) { XCTFail("Illegal stroke accepted") }
        }
    }
    func testRestartFreezesActualSubsetAndLayoutIdentity() throws {
        var config = MultiBallConfiguration(); config.game = .chineseEight; config.randomOpponents = true
        let controller = MultiBallPracticeController(configuration: config, defaults: defaults, limiter: limiter())
        controller.start(config)
        let rack = try XCTUnwrap(controller.rack)
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let before = try encoder.encode(rack)
        for _ in 0..<5 { controller.restart(); XCTAssertEqual(try encoder.encode(controller.rack), before); XCTAssertTrue(controller.canPlaceCue) }
        controller.nextRack(); XCTAssertNotEqual(controller.rack?.sourceID, rack.sourceID)
        XCTAssertTrue(FreeControlCatalog.ids(page: .multiBallPractice, mode: .twoD).contains("multiBall.restart"))
        XCTAssertFalse(FreeControlCatalog.ids(page: .snakePractice, mode: .twoD).contains("multiBall.restart"))
    }
    func testCommittedFactsMapPocketAliasesAndIgnoreDuplicateCallbacks() throws {
        let controller = MultiBallPracticeController(configuration: .init(), defaults: defaults, limiter: limiter())
        controller.start(.init())
        let board = try XCTUnwrap(controller.rack?.board)
        for (index, n) in [1, 2, 3, 9].enumerated() {
            controller.prepareShot()
            var prediction = ShotPrediction(); prediction.termination = .settled
            prediction.events = [.init(time: 0, kind: .ballBall(ballA: ShotInput.cueBallName, ballB: ShotInput.targetBallName)),
                                 .init(time: 1, kind: .ballBall(ballA: ShotInput.targetBallName, ballB: "_4"))]
            prediction.pocketedBalls = [ShotInput.targetBallName]
            let solved = PositionPlayViewModel.SolvedShot(before: board,
                shot: .init(targetKey: "_\(n)", pocket: "topLeft", velocity: 2), prediction: prediction)
            controller.settle(solved)
            let remaining = controller.remaining
            controller.settle(solved)
            XCTAssertEqual(controller.remaining, remaining)
            XCTAssertEqual(remaining.count, 3-index)
            XCTAssertFalse(controller.canPlaceCue)
        }
        XCTAssertTrue(controller.isComplete); XCTAssertFalse(controller.canStrike)
        controller.restart(); XCTAssertTrue(controller.canPlaceCue); XCTAssertEqual(controller.remaining.count, 4)
        controller.finishAttempt(reason: "退出")
    }
    func testFreeAimKeysAndLateScratchAreAuthoritative() {
        var prediction = ShotPrediction(); prediction.termination = .settled
        prediction.events = [.init(time: 0, kind: .ballBall(ballA: ShotInput.cueBallName, ballB: "_2"))]
        prediction.pocketedBalls = ["_2"]
        let shot = PlannedShot(targetKey: "", pocket: "", velocity: 1.5, freeAim: .init(x: 1, y: 0))
        let solved = PositionPlayViewModel.SolvedShot(before: .init(onTable: [:]), shot: shot, prediction: prediction)
        XCTAssertEqual(MultiBallRuling.judge(game: .rotation, remaining: ["_2", "_3"], solved: solved), .continued(["_3"]))
        prediction.pocketedBalls.append(ShotInput.cueBallName)
        XCTAssertEqual(MultiBallRuling.judge(game: .rotation, remaining: ["_2", "_3"], solved: .init(before: solved.before, shot: shot, prediction: prediction)), .failed("母球落袋"))
    }

    private func limiter() -> AngleUsageLimiter { AngleUsageLimiter(defaults: defaults, namespace: "multi", limit: 3) }
    func testSharedQuotaAcrossGamesCountsAndRelaunch() throws {
        let usage = limiter()
        let c = MultiBallPracticeController(defaults: defaults, limiter: usage)
        c.start(.init()); XCTAssertEqual(usage.questionsUsedToday, 1)
        c.restart(); c.restart(); XCTAssertEqual(usage.questionsUsedToday, 1)
        var config = MultiBallConfiguration(); config.rotationCount = 9
        c.start(config); XCTAssertEqual(usage.questionsUsedToday, 2)
        config.game = .chineseEight; config.ownCount = 8
        c.start(config); XCTAssertEqual(usage.questionsUsedToday, 3)
        let last = try XCTUnwrap(c.rack?.sourceID)
        c.nextRack(); XCTAssertTrue(c.showDailyLimit); XCTAssertEqual(c.rack?.sourceID, last)
        c.restart(); XCTAssertTrue(c.canStrike)
        let restored = limiter()
        let next = MultiBallPracticeController(defaults: defaults, limiter: restored)
        next.start(.init()); XCTAssertTrue(next.showDailyLimit); XCTAssertNil(next.rack)
        XCTAssertEqual(restored.remainingToday, 0)
        XCTAssertEqual(AngleUsageLimiter(defaults: defaults, namespace: "unrelated").remainingToday, 20)
    }
    func testProAccessAndFixedSessionBoundary() throws {
        let usage = limiter()
        for is3D in [false, true] {
            var config = MultiBallConfiguration(); config.freePractice = !is3D
            let c = MultiBallPracticeController(configuration: config, defaults: defaults, is3D: is3D, limiter: usage)
            c.start(config); XCTAssertTrue(c.showUpgrade); XCTAssertNil(c.rack)
            var premium = true; c.premiumProvider = { premium }
            c.start(config)
            for _ in 0..<4 { c.nextRack() }
            XCTAssertEqual(c.questionNumber, 5); XCTAssertEqual(usage.questionsUsedToday, 0)
            premium = false
            XCTAssertFalse(c.canStrike); XCTAssertFalse(c.canPlaceCue)
            let id = c.rack?.sourceID; c.nextRack(); XCTAssertEqual(c.rack?.sourceID, id)
        }
        let c = MultiBallPracticeController(defaults: defaults, limiter: usage)
        c.premiumProvider = { true }; c.start(.init()); c.nextRack(); c.nextRack()
        let id = c.rack?.sourceID; c.nextRack()
        XCTAssertTrue(c.showSessionEnd); XCTAssertEqual(c.questionNumber, 3); XCTAssertEqual(c.rack?.sourceID, id)
        c.start(.init()); XCTAssertEqual(c.questionNumber, 1); XCTAssertFalse(c.showSessionEnd)
        XCTAssertEqual(TablePreferencePage.multiBallPractice.fixedControlLayoutMode, .twoD)
        XCTAssertEqual(TablePreferencePage.multiBallPractice3D.fixedControlLayoutMode, .threeD)
        XCTAssertFalse(TablePreferencePage.multiBallPractice.fields.contains(.view3D))
        XCTAssertTrue(FreeControlCatalog.ids(page: .multiBallPractice3D, mode: .threeD).contains("multiBall.restart"))
        XCTAssertFalse(AngleRoute.multiBallPractice.requiresPremium)
        XCTAssertTrue(AngleRoute.multiBallPractice3D.requiresPremium)
    }
    func testDailyRolloverAndLegacyConfigurationIsolation() throws {
        var date = Date(timeIntervalSince1970: 1800000000)
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let usage = AngleUsageLimiter(defaults: defaults, now: { date }, calendar: { calendar }, namespace: "rollover", limit: 3)
        for _ in 0..<3 { usage.recordQuestion() }
        XCTAssertTrue(usage.isLimitReached)
        date.addTimeInterval(86400); usage.refreshDay(); XCTAssertEqual(usage.remainingToday, 3)
        let legacy = Data(#"{"game":"rotation","rotationCount":4,"ownCount":4,"randomOpponents":false}"#.utf8)
        let config = try JSONDecoder().decode(MultiBallConfiguration.self, from: legacy)
        XCTAssertFalse(config.freePractice)
        var other = config; other.rotationCount = 9; other.freePractice = true
        config.save(defaults: defaults); other.save(defaults: defaults, is3D: true)
        XCTAssertEqual(MultiBallConfiguration.load(defaults: defaults), config)
        XCTAssertEqual(MultiBallConfiguration.load(defaults: defaults, is3D: true), other)
        let preferences = TablePreferencesStore(defaults: defaults)
        preferences.apply(.grid, value: 1, to: .multiBallPractice)
        preferences.apply(.transparency, value: 0.8, to: .multiBallPractice3D)
        let restored = TablePreferencesStore(defaults: defaults)
        XCTAssertTrue(restored.snapshot(for: .multiBallPractice).enabled(.grid))
        XCTAssertFalse(restored.snapshot(for: .multiBallPractice3D).enabled(.grid))
        XCTAssertEqual(restored.snapshot(for: .multiBallPractice3D)[.transparency], 0.8)
        XCTAssertEqual(restored.snapshot(for: .multiBallPractice)[.transparency], 0.5)
    }

}
