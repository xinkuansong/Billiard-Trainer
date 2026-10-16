import XCTest
import SceneKit
@testable import QiuJi

@MainActor
final class SnakePracticeTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!
    private var history: SnakePracticeHistory!
    override func setUpWithError() throws {
        suite = "SnakePracticeTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        history = SnakePracticeHistory(defaults: defaults)
    }
    override func tearDownWithError() throws { defaults.removePersistentDomain(forName: suite) }

    private let cue = ShotInput.cueBallName
    private let object = ShotInput.targetBallName
    private var shot: PlannedShot { .init(targetKey: "_1", pocket: "topCenter", velocity: 1.5) }

    private func prediction(_ events: [ShotEvent.Kind], pots: [String] = []) -> ShotPrediction {
        var result = ShotPrediction()
        result.termination = .settled
        result.events = events.enumerated().map { .init(time: Float($0.offset), kind: $0.element) }
        result.pocketedBalls = pots
        return result
    }
    private func judge(_ p: ShotPrediction, shot: PlannedShot? = nil, target: String = "_1",
                       remaining: Set<String> = ["_1", "_2", "_3"]) -> SnakePracticeRuling {
        SnakePracticeRuling.judge(target: target, remaining: remaining, shot: shot ?? self.shot, prediction: p)
    }

    func testAllCountsAreInsideTableSeparatedAndOrdered() {
        for count in SnakePracticeConfiguration.counts {
            var config = SnakePracticeConfiguration(count: count, mode: .alongLine)
            config.regenerate()
            let board = config.board
            XCTAssertEqual(board.onTable.count, count + 1)
            XCTAssertEqual(config.keys.count, count)
            XCTAssertEqual(config.numbers, Array(1...count))
            for pair in zip(config.positions, config.positions.dropFirst()) {
                XCTAssertEqual((pair.1.x - pair.0.x) * 2.54, 0.15875, accuracy: 1e-8)
                XCTAssertEqual(pair.0.y, 0.25)
            }
            XCTAssertEqual(Set(config.keys), Set(board.targetCandidates))
            let points = board.onTable.values.map {
                AngleSceneCalculator.normalizedToScene(point: CGPoint(x: $0.x, y: $0.y), surfaceY: 0.8)
            }
            for (i, a) in points.enumerated() {
                XCTAssertLessThan(abs(a.x), TablePhysics.innerLength / 2 - BallPhysics.radius)
                XCTAssertLessThan(abs(a.z), TablePhysics.innerWidth / 2 - BallPhysics.radius)
                for b in points.dropFirst(i + 1) {
                    XCTAssertGreaterThan(hypot(a.x-b.x, a.z-b.z), BallPhysics.diameter)
                }
            }
        }
    }

    func testDirectionalOrdersAndLegacyPreferences() throws {
        XCTAssertEqual(SnakePracticeConfiguration.load(defaults: defaults).mode, .rightToLeft)
        for count in SnakePracticeConfiguration.counts {
            for mode in [SnakePracticeConfiguration.Mode.alongLine, .rightToLeft] {
                var config = SnakePracticeConfiguration(count: count, mode: mode)
                config.regenerate()
                let controller = SnakePracticeController(configuration: config, history: history, defaults: defaults)
                controller.start(config)
                var xs: [Double] = []
                for _ in 0..<count {
                    xs.append(try XCTUnwrap(config.board.onTable[controller.targetKey!]).x)
                    stroke(controller, success: true)
                }
                for (a, b) in zip(xs, xs.dropFirst()) {
                    XCTAssertTrue(mode == .alongLine ? a < b : a > b)
                }
                XCTAssertTrue(controller.isComplete)
                config.save(defaults: defaults)
                XCTAssertEqual(SnakePracticeConfiguration.load(defaults: defaults).mode, mode)
            }
        }
        for raw in ["沿线清台", "按号清台"] {
            defaults.set(raw, forKey: "snakePractice.mode")
            XCTAssertEqual(SnakePracticeConfiguration.load(defaults: defaults).mode.rawValue, raw)
            let json = Data("\"\(raw)\"".utf8)
            XCTAssertEqual(try JSONDecoder().decode(SnakePracticeConfiguration.Mode.self, from: json).rawValue, raw)
        }
    }

    func testRandomPermutationChangesOnlyNumberAssignment() {
        for count in SnakePracticeConfiguration.counts {
            var config = SnakePracticeConfiguration(count: count, mode: .numbered)
            var seen: Set<[Int]> = []
            for _ in 0..<20 {
                config.regenerate(); seen.insert(config.numbers)
                XCTAssertEqual(config.numbers.sorted(), Array(1...count))
                XCTAssertEqual(Set(config.board.targetCandidates), Set(config.keys))
                let xs = config.board.onTable.filter { $0.key != PositionPlayBall.cueKey }.values.map(\.x).sorted()
                XCTAssertEqual(xs.first!, 0.5 - Double(count-1)/32, accuracy: 1e-8)
                XCTAssertEqual(xs.last!, 0.5 + Double(count-1)/32, accuracy: 1e-8)
            }
            XCTAssertGreaterThan(seen.count, 1)
        }
    }

    func testFreePocketChoiceIncludesAllSixPockets() {
        for pocket in ["topLeft", "topRight", "bottomLeft", "bottomRight", "topCenter", "bottomCenter"] {
            XCTAssertEqual(judge(prediction([.ballBall(ballA: cue, ballB: object),
                .pocket(ball: object, pocketId: pocket)], pots: [object])), .success)
        }
    }

    func testCushionBeforeCorrectContactIsAllowed() {
        XCTAssertEqual(judge(prediction([.ballCushion(ball: cue), .ballBall(ballA: cue, ballB: object)], pots: [object])), .success)
    }
    func testCueHitsFutureBallAfterTargetDrops() {
        XCTAssertEqual(judge(prediction([.ballBall(ballA: cue, ballB: object),
            .pocket(ball: object, pocketId: "topCenter"), .ballBall(ballA: cue, ballB: "_2")], pots: [object])), .otherBall)
    }
    func testTargetHitsFutureBallEvenWithoutMeasurableDisplacement() {
        XCTAssertEqual(judge(prediction([.ballBall(ballA: cue, ballB: object),
            .ballBall(ballA: object, ballB: "_2")], pots: [object])), .otherBall)
    }
    func testWrongFirstBallCannotBeRescuedByPottingTarget() {
        XCTAssertEqual(judge(prediction([.ballBall(ballA: cue, ballB: "_3"),
            .ballBall(ballA: cue, ballB: object)], pots: [object])), .otherBall)
    }
    func testSimultaneousCorrectAndProtectedContactFails() {
        var p = prediction([.ballBall(ballA: cue, ballB: object), .ballBall(ballA: cue, ballB: "_2")], pots: [object])
        p.events = p.events.map { ShotEvent(time: 1, kind: $0.kind) }
        XCTAssertEqual(judge(p), .otherBall)
    }
    func testExtraPocketedBallFailsEvenIfCollisionEventIsMissing() {
        XCTAssertEqual(judge(prediction([.ballBall(ballA: cue, ballB: object)], pots: [object, "_2"])), .otherBall)
    }
    func testScratchAfterLastTargetIsNotCompletion() {
        XCTAssertEqual(judge(prediction([.ballBall(ballA: cue, ballB: object),
            .pocket(ball: object, pocketId: "topCenter"), .pocket(ball: cue, pocketId: "topLeft")], pots: [object, cue]), remaining: ["_1"]), .scratch)
    }
    func testIncompleteSimulationCannotAdvance() {
        var p = prediction([.ballBall(ballA: cue, ballB: object)], pots: [object])
        p.termination = nil
        XCTAssertEqual(judge(p), .incomplete)
    }
    func testMissAndNoContactAreDifferentFailures() {
        XCTAssertEqual(judge(prediction([.ballBall(ballA: cue, ballB: object)])), .miss)
        XCTAssertEqual(judge(prediction([])), .noContact)
    }
    func testFreeAimUsesBoardKeysRatherThanObjectAlias() {
        let free = PlannedShot(targetKey: "", pocket: "", velocity: 1.5, freeAim: .init(x: 1, y: 0))
        XCTAssertEqual(judge(prediction([.ballBall(ballA: cue, ballB: "_2")], pots: ["_2"]), shot: free, target: "_2", remaining: ["_2", "_3"]), .success)
    }
    func testBallEightHasNoSeparateWinRule() {
        let eight = PlannedShot(targetKey: "_8", pocket: "topLeft", velocity: 1.5)
        XCTAssertEqual(judge(prediction([.ballBall(ballA: cue, ballB: object)], pots: [object]), shot: eight, target: "_8", remaining: ["_8", "_9"]), .success)
    }
    func testPreferencesOnlyStoreConfiguration() throws {
        XCTAssertEqual(SnakePracticeConfiguration.counts, Array(3...15))
        let name = "SnakePracticeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        var config = SnakePracticeConfiguration(count: 10, mode: .alongLine)
        config.regenerate(); config.save(defaults: defaults)
        let restored = SnakePracticeConfiguration.load(defaults: defaults)
        XCTAssertEqual(config, restored)
        XCTAssertEqual(Set(defaults.persistentDomain(forName: name)!.keys),
                       ["snakePractice.count", "snakePractice.mode"])
    }

    func testControllerAdvancesByNumberAndCompletesOnlyAfterLastLegalStroke() {
        let config = SnakePracticeConfiguration(mode: .numbered, numbers: [3, 1, 5, 2, 4])
        let controller = SnakePracticeController(configuration: config, history: history, defaults: defaults)
        controller.start(config)
        XCTAssertTrue(controller.canPlaceCue)
        for n in 1...5 {
            XCTAssertEqual(controller.targetKey, "_\(n)")
            XCTAssertFalse(controller.isComplete)
            controller.prepareShot()
            controller.settle(.init(before: config.board,
                shot: PlannedShot(targetKey: "_\(n)", pocket: "topLeft", velocity: 1.5),
                prediction: prediction([.ballBall(ballA: cue, ballB: object)], pots: [object])))
            XCTAssertFalse(controller.canPlaceCue)
        }
        XCTAssertTrue(controller.isComplete)
        XCTAssertNil(controller.targetKey)
        XCTAssertFalse(controller.canStrike)
        XCTAssertEqual(controller.notice, "已清台")
    }

    func testControllerFailureRetainsTargetAndRequiresRecovery() {
        let controller = SnakePracticeController(history: history, defaults: defaults)
        controller.start(.init())
        controller.prepareShot()
        controller.settle(.init(before: SnakePracticeConfiguration().board, shot: shot,
            prediction: prediction([.ballBall(ballA: cue, ballB: object),
                                    .ballBall(ballA: object, ballB: "_2")], pots: [object])))
        XCTAssertEqual(controller.failure, .otherBall)
        XCTAssertEqual(controller.targetKey, "_1")
        XCTAssertFalse(controller.isComplete)
        XCTAssertFalse(controller.canPlaceCue)
        XCTAssertFalse(controller.canStrike)
    }
    private func session(count: Int = 5) -> SnakePracticeController {
        var config = SnakePracticeConfiguration(count: count, mode: .alongLine)
        config.regenerate()
        let controller = SnakePracticeController(configuration: config, history: history, defaults: defaults)
        controller.start(config)
        return controller
    }
    private func stroke(_ controller: SnakePracticeController, success: Bool) {
        controller.prepareShot()
        controller.settle(.init(before: controller.configuration.board,
            shot: PlannedShot(targetKey: controller.targetKey!, pocket: "topLeft", velocity: 1.5),
            prediction: prediction([.ballBall(ballA: cue, ballB: object)], pots: success ? [object] : [])))
    }
    func testFailedShotRetryThenLegalPotCountsNormallyInSameAttempt() throws {
        let controller = session()
        for _ in 0..<4 { stroke(controller, success: true) }
        stroke(controller, success: false)
        XCTAssertEqual(controller.targetIndex, 4)
        XCTAssertTrue(controller.showFailureChoice)
        XCTAssertTrue(history.records.isEmpty)
        let id = try XCTUnwrap(history.active?.id)
        controller.undo()
        XCTAssertFalse(controller.showFailureChoice)
        XCTAssertTrue(controller.canStrike)
        XCTAssertEqual(controller.targetIndex, 4)
        stroke(controller, success: true)
        XCTAssertTrue(controller.isComplete)
        XCTAssertEqual(history.records.count, 1)
        XCTAssertEqual(history.records.first?.completed, 5)
        XCTAssertEqual(history.records.first?.id, id)
        XCTAssertEqual(history.records.first?.succeeded, true)
        controller.finishAttempt()
        controller.finishAttempt()
        XCTAssertEqual(history.records.count, 1)
    }
    func testRestartAfterFailureRecordsOnlyLegalBallsAndStartsNewAttempt() throws {
        let controller = session()
        for _ in 0..<4 { stroke(controller, success: true) }
        stroke(controller, success: false)
        let oldID = try XCTUnwrap(history.active?.id)
        controller.restart()
        XCTAssertEqual(history.records.first?.completed, 4)
        XCTAssertEqual(history.records.first?.reason, "目标球未进")
        XCTAssertEqual(history.records.first?.id, oldID)
        XCTAssertNil(history.active)
        XCTAssertEqual(controller.targetIndex, 0)
        XCTAssertTrue(controller.canPlaceCue)
        controller.finishAttempt()
        XCTAssertEqual(history.records.count, 1)
        XCTAssertEqual(history.records.first?.completed, 4)
    }
    func testCompletionUndoReopensSameRecordAndCanFinishAgain() {
        let controller = session(count: 3)
        for _ in 0..<3 { stroke(controller, success: true) }
        let id = history.records.first?.id
        controller.undo()
        XCTAssertTrue(history.records.isEmpty)
        XCTAssertEqual(history.active?.id, id)
        XCTAssertEqual(controller.targetIndex, 2)
        stroke(controller, success: true)
        XCTAssertEqual(history.records.count, 1)
        XCTAssertEqual(history.records.first?.id, id)
        controller.restart()
        XCTAssertEqual(history.records.count, 1)
    }
    func testChangingConfigurationEndsPreviousAndKeepsItsOwnModeAndCount() {
        let controller = session()
        stroke(controller, success: true)
        var next = SnakePracticeConfiguration(count: 9, mode: .numbered)
        next.regenerate()
        controller.start(next)
        XCTAssertEqual(history.records.first?.count, 5)
        XCTAssertEqual(history.records.first?.mode, .alongLine)
        XCTAssertEqual(history.records.first?.completed, 1)
        XCTAssertEqual(history.records.first?.reason, "更换设置")
        XCTAssertNil(history.active)
        controller.prepareShot()
        XCTAssertEqual(history.active?.count, 9)
        XCTAssertEqual(history.active?.mode, .numbered)
    }
    func testHistoryKeepsTenNewestAndRestoresInterruptedAttemptExactlyOnce() {
        let controller = session()
        for _ in 0..<12 { stroke(controller, success: false); controller.restart() }
        controller.prepareShot()
        XCTAssertEqual(history.records.count, 10)
        let pendingID = history.active?.id
        let restored = SnakePracticeHistory(defaults: defaults)
        restored.recoverInterruptedAttempt()
        restored.recoverInterruptedAttempt()
        XCTAssertEqual(restored.records.count, 10)
        XCTAssertEqual(restored.records.first?.id, pendingID)
        XCTAssertEqual(Set(restored.records.map(\.id)).count, 10)
        XCTAssertNil(restored.active)
        XCTAssertEqual(SnakePracticeHistory(defaults: defaults).records, restored.records)
    }
    func testLateOrRepeatedStrokeCannotChangeClosedAttempt() {
        let controller = session()
        controller.prepareShot()
        controller.finishAttempt()
        controller.settle(.init(before: controller.configuration.board, shot: shot,
            prediction: prediction([.ballBall(ballA: cue, ballB: object)], pots: [object])))
        XCTAssertEqual(controller.targetIndex, 0)
        XCTAssertEqual(history.records.count, 1)
        XCTAssertEqual(history.records.first?.completed, 0)
    }

    func testUnplayedExitRestartAndConfigurationChangeCreateNoHistory() {
        let controller = session()
        XCTAssertNil(history.active)
        controller.restart()
        controller.start(SnakePracticeConfiguration(count: 9, mode: .numbered, numbers: Array(1...9)))
        controller.finishAttempt()
        controller.finishAttempt()
        XCTAssertTrue(history.records.isEmpty)
        XCTAssertNil(history.active)
        let restored = SnakePracticeHistory(defaults: defaults)
        restored.recoverInterruptedAttempt()
        XCTAssertTrue(restored.records.isEmpty)
        XCTAssertNil(restored.active)
    }
    func testFirstMissThenRetryAndExitStillRecordsAttempt() throws {
        let controller = session()
        stroke(controller, success: false)
        let id = try XCTUnwrap(history.active?.id)
        controller.undo()
        XCTAssertTrue(controller.canPlaceCue)
        controller.finishAttempt()
        XCTAssertEqual(history.records.count, 1)
        XCTAssertEqual(history.records.first?.id, id)
        XCTAssertEqual(history.records.first?.completed, 0)
        XCTAssertNil(history.active)
    }
    func testFirstStrokeInterruptedBeforeSettlementIsRecovered() {
        let controller = session()
        controller.prepareShot()
        let restored = SnakePracticeHistory(defaults: defaults)
        restored.recoverInterruptedAttempt()
        XCTAssertEqual(restored.records.count, 1)
        XCTAssertEqual(restored.records.first?.completed, 0)
        XCTAssertFalse(restored.records.first!.succeeded)
    }

}
