import XCTest
import SceneKit
@testable import QiuJi

@MainActor
final class MultiBallPracticeTests: XCTestCase {

    func testManualPlanningFeedbackAndPersistentPocketColours() throws {
        var config = MultiBallConfiguration(); config.game = .chineseEight
        let controller = MultiBallPracticeController(configuration: config, defaults: defaults, limiter: limiter())
        let host = PositionPlayViewModel(); host.setupScene()
        defer { host.suspendAuthoringActivity() }
        controller.attach(to: host); controller.start(config)
        var balls = 0, pockets = 0
        host.scene.ballSelectionHaptic = { balls += 1 }
        host.scene.pocketSelectionHaptic = { pockets += 1 }
        let next = try XCTUnwrap(controller.continuationKeys.first)
        let node = try XCTUnwrap(host.scene.allBallNodes[next])
        XCTAssertTrue(controller.selectPlanningBall(next))
        XCTAssertEqual(balls, 1); XCTAssertEqual(pockets, 0)
        XCTAssertNotNil(node.action(forKey: TableBallPulse.actionKey))
        XCTAssertTrue(controller.selectContinuationPocket(2))
        XCTAssertEqual(pockets, 1)
        let markers = host.scene.addPocketMarkers().compactMap { $0 as? PocketLeatherMarker }
        let styles = markers.map(\.style)
        for _ in 0..<3 { controller.refreshPresentation() }
        XCTAssertEqual(pockets, 1); XCTAssertEqual(balls, 1)
        XCTAssertEqual(markers.map(\.style), styles)
        XCTAssertTrue(controller.selectContinuationPocket(2))
        XCTAssertEqual(pockets, 2, "A repeated manual tap is one new acknowledgement")
        let third = try XCTUnwrap(controller.thirdKeys.first)
        XCTAssertTrue(controller.selectPlanningBall(third)); XCTAssertEqual(balls, 2)
        controller.selectPaletteBall(third); XCTAssertEqual(balls, 3)
        controller.selectPaletteBall(next); XCTAssertEqual(balls, 4)
        XCTAssertFalse(controller.selectPlanningBall("_8"))
        XCTAssertFalse(controller.selectContinuationPocket(99))
        XCTAssertEqual(balls, 4); XCTAssertEqual(pockets, 2)
        controller.goToPreviousStep()
        XCTAssertEqual(balls, 4); XCTAssertEqual(pockets, 2, "Navigation is not a selection")
    }

    func testAcceptedCurrentBallFeedbackDoesNotDoubleAcknowledgeAutomaticPocket() throws {
        let host = PositionPlayViewModel(); host.setupScene()
        defer { host.suspendAuthoringActivity() }
        var balls = 0, pockets = 0
        host.scene.ballSelectionHaptic = { balls += 1 }
        host.scene.pocketSelectionHaptic = { pockets += 1 }
        let key = try XCTUnwrap(host.onTableKeys.first { !PositionPlayBall.isCue($0) })
        XCTAssertTrue(host.selectTarget(key: key)); XCTAssertTrue(host.selectTarget(key: key))
        XCTAssertEqual(balls, 2); XCTAssertEqual(pockets, 0)
        host.selectPocket(at: host.selectedPocketIndex)
        XCTAssertEqual(pockets, 1)
        XCTAssertFalse(host.selectTarget(key: "missing"))
        XCTAssertEqual(balls, 2)
    }

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
        var config = MultiBallConfiguration(); config.positionMode = .independent
        let controller = MultiBallPracticeController(configuration: config, defaults: defaults, limiter: limiter())
        controller.start(config)
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
        var config = MultiBallConfiguration(); config.rotationCount = 9; config.positionMode = .independent
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

    func testPlanningDefaultLegacyMigrationAndModePersistence() throws {
        XCTAssertEqual(MultiBallConfiguration().positionMode, .planned)
        let legacy = Data(#"{"game":"rotation","rotationCount":6,"ownCount":4,"randomOpponents":false}"#.utf8)
        let migrated = try JSONDecoder().decode(MultiBallConfiguration.self, from: legacy)
        XCTAssertEqual(migrated.positionMode, .planned)
        XCTAssertEqual(migrated.rotationCount, 6)
        var independent = migrated; independent.positionMode = .independent
        independent.save(defaults: defaults)
        migrated.save(defaults: defaults, is3D: true)
        XCTAssertEqual(MultiBallConfiguration.load(defaults: defaults).positionMode, .independent)
        XCTAssertEqual(MultiBallConfiguration.load(defaults: defaults, is3D: true).positionMode, .planned)
    }

    func testPlanningRotationOnlyRequiresNextPocketAndScoresNMinusOneStrokes() throws {
        let c = MultiBallPracticeController(configuration: .init(), defaults: defaults, limiter: limiter())
        c.start(.init())
        let board = try XCTUnwrap(c.rack?.board)
        for (index, number) in [1, 2, 3, 9].enumerated() {
            if index < 3 {
                XCTAssertTrue(c.canStrike)
                XCTAssertFalse(c.requestStrike())
                XCTAssertEqual(c.hasStruck, index > 0)
                XCTAssertEqual(c.scores.count, index)
                c.beginPlanning()
                XCTAssertEqual(c.draftNextKey, "_\([2,3,9][index])")
                XCTAssertFalse(c.selectContinuationBall("_9"))
                XCTAssertFalse(c.selectContinuationPocket(6))
                XCTAssertTrue(c.selectContinuationPocket(4))
            } else { XCTAssertFalse(c.needsContinuation) }
            XCTAssertTrue(c.canStrike)
            c.prepareShot()
            var prediction = ShotPrediction(); prediction.termination = .settled
            prediction.events = [.init(time: 0, kind: .ballBall(ballA: ShotInput.cueBallName, ballB: ShotInput.targetBallName))]
            prediction.pocketedBalls = [ShotInput.targetBallName]
            prediction.finalPositions = [ShotInput.cueBallName: SCNVector3(0, 0, 0.35)]
            if let plan = c.plan { prediction.finalPositions[plan.next] = SCNVector3(0, 0, -0.1) }
            let solved = PositionPlayViewModel.SolvedShot(before: board,
                shot: .init(targetKey: "_\(number)", pocket: "topLeft", velocity: 2), prediction: prediction)
            c.settle(solved); c.settle(solved)
            XCTAssertEqual(c.scores.count, min(index + 1, 3))
            if index < 3 { XCTAssertGreaterThan(c.scores.last!.value, 0) }
        }
        XCTAssertTrue(c.isComplete)
        XCTAssertEqual(c.scores.count, 3)
        XCTAssertEqual(c.averageScore!, c.scores.map(\.value).reduce(0,+)/3, accuracy: 1e-10)
        XCTAssertTrue(c.completionSummary.contains("平均走位"))
        c.restart(); XCTAssertTrue(c.scores.isEmpty); XCTAssertNil(c.plan)
    }

    func testChinesePlanningExcludesCurrentOpponentsAndEarlyBlack() throws {
        var config = MultiBallConfiguration(); config.game = .chineseEight; config.randomOpponents = true
        let c = MultiBallPracticeController(configuration: config, defaults: defaults, limiter: limiter())
        c.start(config); c.beginPlanning()
        XCTAssertNil(c.draftNextKey)
        XCTAssertFalse(c.selectContinuationPocket(0))
        XCTAssertFalse(c.selectContinuationBall(try XCTUnwrap(c.currentTarget)))
        XCTAssertFalse(c.selectContinuationBall("_8"))
        for key in try XCTUnwrap(c.rack).opponentKeys { XCTAssertFalse(c.selectContinuationBall(key)) }
        let next = try XCTUnwrap(c.continuationKeys.first)
        XCTAssertTrue(c.selectContinuationBall(next)); XCTAssertTrue(c.selectContinuationPocket(0))
        XCTAssertEqual(c.plan?.next, next); XCTAssertTrue(c.canStrike)
        XCTAssertFalse(c.requestStrike())
        let third = try XCTUnwrap(c.thirdKeys.first)
        XCTAssertNotEqual(third, next); XCTAssertNotEqual(third, c.currentTarget)
        XCTAssertTrue(c.selectPlanningBall(third))
        XCTAssertTrue(c.requestStrike())
        XCTAssertEqual(c.plan?.third, third)
    }

    func testPreviousStepNavigatesDraftRatherThanClickHistory() throws {
        var config = MultiBallConfiguration(); config.game = .chineseEight
        let c = MultiBallPracticeController(configuration: config, defaults: defaults, limiter: limiter())
        c.start(config)
        let second = try XCTUnwrap(c.continuationKeys.first)
        XCTAssertTrue(c.selectContinuationBall(second))
        XCTAssertEqual(c.planningStep, .pocket2)
        for pocket in [0, 2, 4] { XCTAssertTrue(c.selectContinuationPocket(pocket)) }
        let third = try XCTUnwrap(c.thirdKeys.first)
        XCTAssertTrue(c.selectPlanningBall(third))
        let plan = c.plan
        for expected in [PlanThreeRole.pocket2, .ball2, .pocket1, .ball1] {
            XCTAssertTrue(c.canGoToPreviousStep)
            c.goToPreviousStep()
            XCTAssertEqual(c.planningStep, expected)
            XCTAssertEqual(c.plan, plan)
            XCTAssertEqual(c.draftNextKey, second); XCTAssertEqual(c.thirdKey, third)
        }
        XCTAssertFalse(c.canGoToPreviousStep)
        c.goToPreviousStep(); XCTAssertEqual(c.planningStep, .ball1)
    }

    func testChineseOwnershipStaysFixedWithNoOpponentsAndAfterClearingOwnColors() throws {
        for opponents in [false, true] {
            var config = MultiBallConfiguration(); config.game = .chineseEight
            config.positionMode = .independent; config.randomOpponents = opponents
            let vm = PositionPlayViewModel(); vm.setupScene(loadsDefaultLayout: false)
            let c = MultiBallPracticeController(configuration: config, defaults: defaults, limiter: limiter())
            c.attach(to: vm)
            let rack = try XCTUnwrap(c.rack), colors = rack.ownKeys.subtracting(["_8"])
            XCTAssertEqual(c.legalKeys, colors)
            XCTAssertEqual(vm.legalAimTargets?(Set(vm.onTableKeys)), colors)
            for key in rack.opponentKeys { XCTAssertFalse(vm.selectTarget(key: key)) }
            let target = try XCTUnwrap(c.currentTarget)
            c.prepareShot()
            var prediction = ShotPrediction(); prediction.termination = .settled
            prediction.events = [.init(time: 0, kind: .ballBall(ballA: ShotInput.cueBallName, ballB: ShotInput.targetBallName))]
            prediction.pocketedBalls = [ShotInput.targetBallName] + colors.subtracting([target]).sorted()
            c.settle(.init(before: rack.board, shot: .init(targetKey: target, pocket: "topLeft", velocity: 2), prediction: prediction))
            XCTAssertNil(c.failure)
            XCTAssertEqual(c.legalKeys, ["_8"])
            XCTAssertEqual(vm.legalAimTargets?(Set(vm.onTableKeys)), ["_8"])
            XCTAssertEqual(c.rack?.ownKeys, rack.ownKeys)
            c.restart()
            XCTAssertEqual(c.legalKeys, colors)
            XCTAssertEqual(c.rack?.opponentKeys, rack.opponentKeys)
            c.finishAttempt(reason: "test")
        }
    }

    func testActualBoardObstructionBothLegsAndMovedBallScoring() throws {
        let cue = SCNVector3(0, 0, 0.35), ball = SCNVector3(0, 0, -0.1)
        var positions = [PositionPlayBall.cueKey: cue, "_2": ball]
        func score(_ values: [String: SCNVector3]) -> MultiBallPositionScore.Result {
            MultiBallPositionScore.evaluate(positions: values, target: "_2", pocket: 4, surfaceY: 0)
        }
        let clear = score(positions)
        XCTAssertNil(clear.reason)
        XCTAssertEqual(clear.value, try XCTUnwrap(TwoBallComfortScore.evaluateFreePosition(
            cue: (Double(cue.x), Double(cue.z)), ball: (Double(ball.x), Double(ball.z)), pocket: 4)).total, accuracy: 1e-10)
        for blocker in [SCNVector3(0,0,0.15), SCNVector3(0,0,-0.4)] {
            positions["_12"] = blocker
            XCTAssertEqual(score(positions).value, 0)
            XCTAssertEqual(score(positions).reason, "下一球线路被遮挡")
        }
        positions["_12"] = SCNVector3(0.2,0,0.15)
        XCTAssertEqual(score(positions), clear)
        positions["_2"] = SCNVector3(0.25,0,-0.1)
        XCTAssertNotEqual(score(positions).value, clear.value)
        positions.removeValue(forKey: "_2")
        XCTAssertEqual(score(positions).value, 0)
        XCTAssertEqual(MultiBallPositionScore.evaluate(positions: [:], target: "_2", pocket: 4,
            failure: "母球落袋", surfaceY: 0).reason, "母球落袋")
    }

    func testPlanningHostSelectionPreservesAimAndCarriesNextAim() throws {
        let vm = PositionPlayViewModel(); vm.usesAutomaticPocketFallback = true; vm.setupScene(loadsDefaultLayout: false)
        let c = MultiBallPracticeController(configuration: .init(), defaults: defaults, limiter: limiter())
        c.attach(to: vm)
        let target = vm.selectedTargetKey, pocket = vm.selectedPocketIndex
        c.beginPlanning(); XCTAssertTrue(c.selectContinuationPocket(4))
        XCTAssertEqual(vm.selectedTargetKey, target); XCTAssertEqual(vm.selectedPocketIndex, pocket)
        XCTAssertEqual(vm.continuationPocketIndex, 4)
        let plan = try XCTUnwrap(c.plan)
        c.prepareShot()
        var prediction = ShotPrediction(); prediction.termination = .settled
        prediction.events = [.init(time: 0, kind: .ballBall(ballA: ShotInput.cueBallName, ballB: ShotInput.targetBallName))]
        prediction.pocketedBalls = [ShotInput.targetBallName]
        prediction.finalPositions = [ShotInput.cueBallName: SCNVector3(0,0,0.35), plan.next: SCNVector3(0,0,-0.1)]
        let solved = PositionPlayViewModel.SolvedShot(before: try XCTUnwrap(c.rack?.board),
            shot: .init(targetKey: plan.current, pocket: "topLeft", velocity: 2), prediction: prediction)
        c.settle(solved)
        XCTAssertTrue(c.advancePlannedAim())
        XCTAssertEqual(vm.selectedTargetKey, plan.next); XCTAssertEqual(vm.selectedPocketIndex, plan.pocket)
        XCTAssertEqual(c.draftNextKey, plan.third)
        XCTAssertEqual(c.lockedCurrentPocket, plan.pocket)
        vm.selectPocket(at: (plan.pocket + 1) % 6)
        XCTAssertEqual(vm.selectedPocketIndex, plan.pocket)
        XCTAssertFalse(vm.selectTarget(key: "_9"))
        XCTAssertEqual(c.thirdKey, "_9")
        XCTAssertEqual(c.editingRole, 1)
        XCTAssertEqual(c.scores.count, 1)
        c.finishAttempt(reason: "test")
    }

    func testChineseRollingKeepsThirdAndDefersBlackUntilAllColors() throws {
        var config = MultiBallConfiguration(); config.game = .chineseEight; config.ownCount = 4
        let vm = PositionPlayViewModel(); vm.usesAutomaticPocketFallback = true; vm.setupScene(loadsDefaultLayout: false)
        let c = MultiBallPracticeController(configuration: config, defaults: defaults, limiter: limiter())
        c.attach(to: vm)
        let current = try XCTUnwrap(c.currentTarget)
        let second = try XCTUnwrap(c.continuationKeys.sorted().first)
        XCTAssertTrue(c.selectContinuationBall(second))
        XCTAssertFalse(c.thirdKeys.contains("_8"))
        let third = try XCTUnwrap(c.thirdKeys.first)
        XCTAssertEqual(c.planningStep, .pocket2)
        XCTAssertTrue(c.selectContinuationPocket(4))
        XCTAssertEqual(c.planningStep, .ball3)
        XCTAssertTrue(c.selectPlanningBall(third))
        let frozen = try XCTUnwrap(c.plan)
        c.prepareShot()
        XCTAssertFalse(c.selectContinuationPocket(0))
        XCTAssertFalse(c.selectPlanningBall("_8"))
        XCTAssertEqual(c.plan, frozen)
        var prediction = ShotPrediction(); prediction.termination = .settled
        prediction.events = [.init(time: 0, kind: .ballBall(ballA: ShotInput.cueBallName, ballB: ShotInput.targetBallName))]
        prediction.pocketedBalls = [ShotInput.targetBallName]
        prediction.finalPositions = [ShotInput.cueBallName: .init(0,0,0.35), second: .init(0,0,-0.1)]
        c.settle(.init(before: try XCTUnwrap(c.rack?.board), shot: .init(targetKey: current, pocket: "topLeft", velocity: 2), prediction: prediction))
        XCTAssertTrue(c.advancePlannedAim())
        XCTAssertEqual(c.currentTarget, second); XCTAssertEqual(c.draftNextKey, third)
        XCTAssertEqual(c.thirdKeys, ["_8"])
        XCTAssertNil(c.thirdKey); XCTAssertFalse(c.requestStrike())
        XCTAssertEqual(c.planningStep, .pocket2)
        c.goToPreviousStep()
        XCTAssertEqual(c.planningStep, .ball2)
        XCTAssertEqual(c.draftNextKey, third)
        XCTAssertFalse(c.canGoToPreviousStep, "The inherited current ball and pocket are a boundary")
        XCTAssertTrue(c.selectContinuationBall(third))
        XCTAssertTrue(c.selectContinuationPocket(2))
        XCTAssertEqual(c.planningStep, .ball3)
        XCTAssertTrue(c.selectPlanningBall("_8"))
        XCTAssertEqual(c.plan?.next, third); XCTAssertEqual(c.plan?.third, "_8")
        vm.setPreferredAimMode(.free); vm.setPreferredAimMode(.pocket)
        XCTAssertEqual(vm.selectedTargetKey, second); XCTAssertEqual(vm.selectedPocketIndex, 4)
        XCTAssertTrue(c.requestStrike())
        c.finishAttempt(reason: "test")
    }

    func testPlanningSamePocketKeepsBothColorsWithoutTableRoleRings() throws {
        let vm = PositionPlayViewModel(); vm.usesAutomaticPocketFallback = true; vm.setupScene(loadsDefaultLayout: false)
        let c = MultiBallPracticeController(configuration: .init(), defaults: defaults, limiter: limiter())
        c.attach(to: vm)
        let pocket = vm.selectedPocketIndex
        XCTAssertTrue((0..<6).contains(pocket))
        XCTAssertTrue(c.selectContinuationPocket(pocket))
        var markers: [PocketLeatherMarker] = []
        vm.scene.rootNode.enumerateChildNodes { node, _ in if let marker = node as? PocketLeatherMarker { markers.append(marker) } }
        XCTAssertEqual(markers.first { $0.pocketIndex == pocket }?.style, .practiceBoth)
        let rings = vm.scene.rootNode.childNodes.filter { $0.name?.hasPrefix("multiBall.role.") == true }
        XCTAssertTrue(rings.isEmpty)
        c.restart()
        XCTAssertNil(c.plan); XCTAssertNil(c.lockedCurrentPocket)
        XCTAssertEqual(vm.scene.rootNode.childNodes.filter { $0.name?.hasPrefix("multiBall.role.") == true }.count, 0)
        c.finishAttempt(reason: "test")
    }

}
