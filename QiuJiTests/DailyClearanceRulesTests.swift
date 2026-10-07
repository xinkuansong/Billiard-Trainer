import XCTest
import SceneKit
@testable import QiuJi

final class DailyClearanceRulesTests: XCTestCase {
    private var fullEightBallTable: Set<String> { Set((1...15).map { "_\($0)" }) }

    private func facts(first: String?,
                       pocketed: [String] = [],
                       cuePocketed: Bool = false,
                       rail: Bool = true,
                       table: Set<String>) -> ShotFacts {
        ShotFacts(
            firstContactKey: first,
            pocketedKeys: pocketed,
            cuePocketed: cuePocketed,
            railOrPocketAfterContact: rail,
            tableKeysBefore: table
        )
    }

    func test_gameMapsAllFiveRackLayouts() {
        XCTAssertEqual(DailyClearanceGame.chineseEightBall.rackGame, .chineseEightBall)
        XCTAssertEqual(DailyClearanceGame.nineBall.rackGame, .nineBall)
        XCTAssertEqual(DailyClearanceGame.sixBall.rackGame, .zhuifen(balls: 6))
        XCTAssertEqual(DailyClearanceGame.fiveBall.rackGame, .zhuifen(balls: 5))
        XCTAssertEqual(DailyClearanceGame.fourBall.rackGame, .zhuifen(balls: 4))
    }

    func test_initialDefaultFollowsLegacySportOnlyAtMigration() {
        XCTAssertEqual(DailyClearanceGame.initialDefault(for: .chinese8), .chineseEightBall)
        XCTAssertEqual(DailyClearanceGame.initialDefault(for: .nineBall), .nineBall)
        XCTAssertEqual(DailyClearanceGame.initialDefault(for: .both), .chineseEightBall)
    }

    func test_chineseEight_openTablePotAssignsGroup() {
        var engine = DailyClearanceRulesEngine(game: .chineseEightBall)
        let ruling = engine.judge(facts(first: "_3", pocketed: ["_3"], table: fullEightBallTable))
        XCTAssertFalse(ruling.foul)
        XCTAssertEqual(engine.state.assignedGroup, .solid)
        XCTAssertEqual(engine.state.status, .active)
    }

    func test_chineseEight_wrongFirstContactIsFoulWithRotation() {
        var engine = DailyClearanceRulesEngine(
            game: .chineseEightBall,
            state: DailyClearanceRuleState(assignedGroup: .solid)
        )
        let ruling = engine.judge(facts(first: "_9", table: fullEightBallTable))
        XCTAssertTrue(ruling.foul)
        XCTAssertTrue(ruling.ballInHand)
        XCTAssertEqual(engine.state.assignedGroup, .stripe)
        XCTAssertEqual(engine.state.currentPlayer, .b)
        XCTAssertEqual(engine.state.status, .active)
    }

    func test_chineseEight_groupClearedLegalEightCompletes() {
        var engine = DailyClearanceRulesEngine(
            game: .chineseEightBall,
            state: DailyClearanceRuleState(assignedGroup: .solid)
        )
        let ruling = engine.judge(facts(first: "_8", pocketed: ["_8"], table: ["_8", "_9"]))
        XCTAssertTrue(ruling.completed)
        XCTAssertEqual(engine.state.status, .completed)
    }

    func test_chineseEight_earlyEightFails() {
        var engine = DailyClearanceRulesEngine(
            game: .chineseEightBall,
            state: DailyClearanceRuleState(assignedGroup: .solid)
        )
        let ruling = engine.judge(facts(first: "_2", pocketed: ["_8"], table: ["_2", "_8"]))
        XCTAssertTrue(ruling.failed)
        XCTAssertEqual(engine.state.status, .failed)
    }

    func test_chineseEight_foulEightFails() {
        var engine = DailyClearanceRulesEngine(
            game: .chineseEightBall,
            state: DailyClearanceRuleState(assignedGroup: .solid)
        )
        let ruling = engine.judge(facts(
            first: "_8",
            pocketed: ["_8"],
            cuePocketed: true,
            table: ["_8", "_9"]
        ))
        XCTAssertTrue(ruling.foul)
        XCTAssertTrue(ruling.failed)
        XCTAssertFalse(ruling.ballInHand)
    }

    func test_nineBallLowestContactAndLegalComboNineCompletes() {
        var engine = DailyClearanceRulesEngine(game: .nineBall)
        XCTAssertEqual(engine.legalTargetKeys(tableKeys: ["_1", "_4", "_9"]), ["_1"])
        let ruling = engine.judge(facts(
            first: "_1",
            pocketed: ["_9"],
            table: ["_1", "_4", "_9"]
        ))
        XCTAssertTrue(ruling.completed)
        XCTAssertEqual(engine.state.status, .completed)
    }

    func test_nineBallWrongFirstContactIsContinuingFoul() {
        var engine = DailyClearanceRulesEngine(game: .nineBall)
        let ruling = engine.judge(facts(first: "_4", table: ["_1", "_4", "_9"]))
        XCTAssertTrue(ruling.foul)
        XCTAssertTrue(ruling.ballInHand)
        XCTAssertEqual(engine.state.status, .active)
    }

    func test_nineBallScratchIsContinuingFoul() {
        var engine = DailyClearanceRulesEngine(game: .nineBall)
        let ruling = engine.judge(facts(
            first: "_1",
            cuePocketed: true,
            table: ["_1", "_9"]
        ))
        XCTAssertTrue(ruling.foul)
        XCTAssertTrue(ruling.ballInHand)
        XCTAssertEqual(engine.state.status, .active)
    }

    func test_nineBallFoulTerminalPocketRespots() {
        var engine = DailyClearanceRulesEngine(game: .nineBall)
        let ruling = engine.judge(facts(
            first: "_4",
            pocketed: ["_9"],
            table: ["_1", "_4", "_9"]
        ))
        XCTAssertTrue(ruling.foul)
        XCTAssertFalse(ruling.failed)
        XCTAssertTrue(ruling.ballInHand)
        XCTAssertEqual(ruling.respotKeys, ["_9"])
        XCTAssertEqual(engine.state.status, .active)
    }

    func testOpenCrossGroupPotDoesNotAssignAndDualGroupUsesContactGroup() {
        var engine = DailyClearanceRulesEngine(game: .chineseEightBall)
        let cross = engine.judge(facts(first: "_1", pocketed: ["_9"], table: fullEightBallTable))
        XCTAssertNil(engine.state.assignedGroup)
        XCTAssertTrue(cross.changedTurn)
        XCTAssertFalse(cross.foul)
        let both = engine.judge(facts(first: "_2", pocketed: ["_10", "_2"], table: fullEightBallTable))
        XCTAssertEqual(engine.state.assignedGroup, .solid)
        XCTAssertFalse(both.changedTurn)
    }

    func testOwnAndOtherPotContinuesOnlyOtherPotRotatesAndMissRotatesBack() {
        var engine = DailyClearanceRulesEngine(game: .chineseEightBall,
            state: .init(assignedGroup: .solid))
        XCTAssertFalse(engine.judge(facts(first: "_1", pocketed: ["_1", "_9"], table: fullEightBallTable)).changedTurn)
        XCTAssertTrue(engine.judge(facts(first: "_2", pocketed: ["_10"], table: fullEightBallTable)).changedTurn)
        XCTAssertEqual(engine.state.assignedGroup, .stripe)
        engine.judge(facts(first: "_11", table: fullEightBallTable))
        XCTAssertEqual(engine.state.assignedGroup, .solid)
        XCTAssertEqual(engine.state.visitCount, 3)
    }

    func testLastOwnAndEightTogetherFailsButScratchOnEightWithoutPotDoesNot() {
        var engine = DailyClearanceRulesEngine(game: .chineseEightBall, state: .init(assignedGroup: .solid))
        XCTAssertTrue(engine.judge(facts(first: "_1", pocketed: ["_1", "_8"], table: ["_1", "_8", "_9"])).failed)
        engine = DailyClearanceRulesEngine(game: .chineseEightBall, state: .init(assignedGroup: .solid))
        let scratch = engine.judge(facts(first: "_8", cuePocketed: true, table: ["_8", "_9"]))
        XCTAssertTrue(scratch.foul)
        XCTAssertFalse(scratch.failed)
        XCTAssertEqual(scratch.cuePlacement, .anywhere)
        XCTAssertEqual(engine.legalTargetKeys(tableKeys: ["_8", "_9"]), ["_9"])
    }

    func testSimultaneousLegalContactWinsAndOrdinaryFoulsRotateOnce() {
        var engine = DailyClearanceRulesEngine(game: .chineseEightBall, state: .init(assignedGroup: .solid))
        var simultaneous = facts(first: "_9", pocketed: ["_1"], table: fullEightBallTable)
        simultaneous.simultaneousFirstContacts = ["_9", "_1"]
        XCTAssertFalse(engine.judge(simultaneous).foul)
        for shot in [facts(first: nil, table: fullEightBallTable), facts(first: "_9", rail: false, table: fullEightBallTable)] {
            let ruling = engine.judge(shot)
            XCTAssertTrue(ruling.foul)
            XCTAssertTrue(ruling.changedTurn)
        }
        XCTAssertEqual(engine.state.foulCount, 2)
        XCTAssertEqual(engine.state.visitCount, 3)
    }

    func testBlackEightAndWrongGroupSelectionMessages() {
        let engine = DailyClearanceRulesEngine(game: .chineseEightBall, state: .init(assignedGroup: .solid))
        XCTAssertEqual(engine.selectionMessage(for: "_9", tableKeys: fullEightBallTable), "请先击打全色球")
        XCTAssertEqual(engine.selectionMessage(for: "_8", tableKeys: fullEightBallTable), "先打完全色球，再打黑八")
        XCTAssertEqual(engine.selectionMessage(for: "_9", tableKeys: ["_8", "_9"]), "本组已清空，请击打黑八")
        XCTAssertNil(engine.selectionMessage(for: "_1", tableKeys: fullEightBallTable))
    }

    func testLegalBreakEightRespotAndNoAssignment() {
        var engine = DailyClearanceRulesEngine(game: .chineseEightBall)
        let ruling = engine.judgeChineseBreak(facts(first: "_1", pocketed: ["_8", "_3"], table: fullEightBallTable), automatic: false)
        XCTAssertEqual(ruling.respotKeys, ["_8"])
        XCTAssertFalse(ruling.completed)
        XCTAssertFalse(ruling.failed)
        XCTAssertNil(engine.state.assignedGroup)
        XCTAssertFalse(engine.state.automaticBreak)
    }

    func testBreakFoulSpecialChoicesAndFourDistinctRails() {
        var engine = DailyClearanceRulesEngine(game: .chineseEightBall)
        var shot = facts(first: "_1", table: fullEightBallTable)
        shot.railContactKeys = ["_1", "_2", "_3", PositionPlayBall.cueKey]
        let insufficient = engine.judgeChineseBreak(shot, automatic: false)
        XCTAssertEqual(insufficient.breakChoices, [.rerackByIncoming, .rerackByBreaker, .acceptBallInHand])
        XCTAssertTrue(engine.resolveBreakChoice(.rerackByBreaker))
        XCTAssertTrue(engine.judgeChineseBreak(shot, automatic: false).failed)
        engine = DailyClearanceRulesEngine(game: .chineseEightBall)
        shot.railContactKeys.insert("_4")
        XCTAssertFalse(engine.judgeChineseBreak(shot, automatic: false).foul)
        engine = DailyClearanceRulesEngine(game: .chineseEightBall)
        shot.cueStartedBehindHeadString = false
        let behind = engine.judgeChineseBreak(shot, automatic: false)
        XCTAssertEqual(behind.cuePlacement, .behindHeadString)
    }

    func testBreakEightWithScratchCountsOneFoulAndEightOffTableFails() {
        var engine = DailyClearanceRulesEngine(game: .chineseEightBall)
        let ruling = engine.judgeChineseBreak(facts(first: "_1", pocketed: ["_8"], cuePocketed: true,
            table: fullEightBallTable), automatic: false)
        XCTAssertEqual(ruling.respotKeys, ["_8"])
        XCTAssertEqual(ruling.cuePlacement, .behindHeadString)
        XCTAssertEqual(engine.state.foulCount, 1)
        XCTAssertTrue(engine.state.breakChoices.isEmpty)
        engine = DailyClearanceRulesEngine(game: .chineseEightBall)
        var off = facts(first: "_1", table: fullEightBallTable)
        off.offTableKeys = ["_8"]
        XCTAssertTrue(engine.judgeChineseBreak(off, automatic: false).failed)
    }

    func testOldRuleStateDecodesAndRetainsLegacyRotationBehavior() throws {
        let legacy = try JSONDecoder().decode(DailyClearanceRuleState.self,
            from: Data(#"{"assignedGroup":"solid","status":"active"}"#.utf8))
        XCTAssertEqual(legacy.ruleVersion, 1)
        var engine = DailyClearanceRulesEngine(game: .chineseEightBall, state: legacy)
        XCTAssertTrue(engine.judge(facts(first: "_9", table: fullEightBallTable)).foul)
        XCTAssertEqual(engine.state.assignedGroup, .solid)
        let data = try JSONEncoder().encode(engine.state)
        XCTAssertEqual(try JSONDecoder().decode(DailyClearanceRuleState.self, from: data), engine.state)
    }
    func testNineFamiliesVisitsFoulRespotAndCompletionKinds() {
        for game in [DailyClearanceGame.nineBall, .sixBall, .fiveBall, .fourBall] {
            var engine = DailyClearanceRulesEngine(game: game)
            let keys = Set(game.paletteKeys).subtracting([PositionPlayBall.cueKey])
            XCTAssertEqual(engine.legalTargetKeys(tableKeys: keys), ["_1"])
            engine.judge(facts(first: "_1", table: keys))
            XCTAssertEqual(engine.state.visitCount, 2)
            for _ in 0..<3 { engine.judge(facts(first: nil, table: keys)) }
            XCTAssertEqual(engine.state.foulCount, 3)
            XCTAssertEqual(engine.state.status, .active)
            let combo = engine.judge(facts(first: "_1", pocketed: ["_9"], table: keys))
            XCTAssertTrue(combo.completed)
            XCTAssertEqual(engine.state.completionKind, .combinationNine)
            engine = DailyClearanceRulesEngine(game: game)
            var off = facts(first: "_1", table: keys)
            off.offTableKeys = ["_9"]
            XCTAssertEqual(engine.judge(off).respotKeys, ["_9"])
        }
        for automatic in [false, true] {
            var engine = DailyClearanceRulesEngine(game: .nineBall)
            engine.judgeNineBreak(facts(first: "_1", pocketed: ["_1"], table: ["_1", "_9"]), automatic: automatic)
            engine.judge(facts(first: "_9", pocketed: ["_9"], table: ["_9"]))
            XCTAssertEqual(engine.state.completionKind, automatic ? .systemBreakRun : .breakRun)
            engine = DailyClearanceRulesEngine(game: .nineBall)
            XCTAssertTrue(engine.judgeNineBreak(facts(first: "_1", pocketed: ["_9"], table: ["_1", "_9"]), automatic: automatic).completed)
            XCTAssertEqual(engine.state.completionKind, automatic ? .systemBreakNine : .breakNine)
        }
    }

    func testPhysicalFactsExtractDistinctRailsAndExactSimultaneousContacts() {
        let events: [ShotEvent] = [
            .init(time: 0.1, kind: .ballBall(ballA: "cue", ballB: "_9")),
            .init(time: 0.1, kind: .ballBall(ballA: "cue", ballB: "_1")),
            .init(time: 0.11, kind: .ballBall(ballA: "cue", ballB: "_2")),
            .init(time: 0.2, kind: .ballCushion(ball: "_1")),
            .init(time: 0.3, kind: .ballCushion(ball: "_1")),
            .init(time: 0.4, kind: .pocket(ball: "_9", pocketId: "p"))
        ]
        let extracted = ShotFacts.extract(events: events, cueName: "cue", tableKeys: ["_1", "_2", "_9"],
            pocketed: ["_9"], key: { $0 })
        XCTAssertEqual(extracted.simultaneousFirstContacts, ["_9", "_1"])
        XCTAssertEqual(extracted.railContactKeys, ["_1"])
        XCTAssertTrue(extracted.railOrPocketAfterContact)
        XCTAssertEqual(extracted.pocketedKeys, ["_9"])
    }

    func testBehindStringPlacementMustCrossLineBeforeContact() {
        var state = DailyClearanceRuleState(assignedGroup: .solid)
        state.cuePlacement = .behindHeadString
        var engine = DailyClearanceRulesEngine(game: .chineseEightBall, state: state)
        var shot = facts(first: "_1", table: ["_1", "_8", "_9"])
        shot.cueCrossedHeadStringBeforeContact = false
        XCTAssertTrue(engine.judge(shot).foul)
        XCTAssertEqual(engine.state.assignedGroup, .stripe)
        XCTAssertEqual(engine.state.cuePlacement, .anywhere)
    }

}

/// Real engine integration: one opening rack, then only legal shots / awarded cue placement.
/// This complements UI last-ball tests; it does not claim human or rendered full-game acceptance.
final class DailyClearancePhysicalGameTests: XCTestCase {
    func testCompleteChineseGameFromPhysicalBreak() throws { try runGame(.chineseEightBall) }
    func testCompleteNineGameFromPhysicalBreak() throws { try runGame(.nineBall) }

    private func runGame(_ game: DailyClearanceGame) throws {
        let surface = BTTablePhysics.surfaceY
        let opening = BreakSimulator.breakShot(rack: RackLayout.make(game.rackGame, seed: 52), power: 8)
        XCTAssertTrue(opening.settled)
        var board = opening.board
        var engine = DailyClearanceRulesEngine(game: game)
        let openingFacts = try XCTUnwrap(opening.facts)
        let openingRuling = game == .chineseEightBall
            ? engine.judgeChineseBreak(openingFacts, automatic: true)
            : engine.judgeNineBreak(openingFacts, automatic: true)
        applyPlacement(openingRuling, board: &board)
        if engine.state.breakChoices.contains(.acceptBallInHand) { _ = engine.resolveBreakChoice(.acceptBallInHand) }
        var steps: [SequenceStep] = []
        for turn in 0..<60 where engine.state.status == .active {
            let legal = engine.legalTargetKeys(tableKeys: Set(board.onTable.keys)).sorted()
            let pockets = AngleSceneCalculator.pocketPositions(surfaceY: surface)
            var chosen: (BoardSnapshot, PlannedShot, ShotPrediction, ShotFacts)?
            search: for key in legal {
                guard let targetPoint = board.onTable[key] else { continue }
                let target = world(targetPoint)
                let orderedPockets = (0..<6).sorted { (pockets[$0] - target).length() < (pockets[$1] - target).length() }
                for pocket in orderedPockets {
                    var candidate = board
                    if engine.state.cuePlacement != .none {
                        let direction = (target - pockets[pocket]).normalized()
                        let cue = target + direction * 0.35
                        if validCue(cue, board: board, placement: engine.state.cuePlacement) {
                            candidate.onTable[PositionPlayBall.cueKey] = normalized(cue)
                        }
                    }
                    guard let cuePoint = candidate.onTable[PositionPlayBall.cueKey],
                          AngleSceneCalculator.isFeasible(cueBall: world(cuePoint), targetBall: target, pocket: pockets[pocket]) else { continue }
                    for speed in [1.5, 2.5, 4.0] {
                        let shot = PlannedShot(targetKey: key, pocket: ShotIntent.pocketId(for: pocket)!, velocity: speed)
                        guard let prediction = PositionPlayShotSolver.solve(before: candidate, shot: shot, surfaceY: surface),
                              prediction.hasFinalTableState, prediction.objectPocketed, !prediction.cuePocketed else { continue }
                        let facts = physicalFacts(prediction, before: candidate, shot: shot)
                        var trial = engine
                        let ruling = trial.judge(facts)
                        guard !ruling.failed, !ruling.foul, facts.pocketedKeys.contains(key) else { continue }
                        chosen = (candidate, shot, prediction, facts)
                        break search
                    }
                }
            }
            if chosen == nil, let key = legal.first, let target = board.onTable[key], let cue = board.onTable[PositionPlayBall.cueKey] {
                let delta = world(target) - world(cue)
                let shot = PlannedShot(targetKey: key, pocket: "", velocity: 2.5,
                    freeAim: CanvasPoint(x: Double(delta.x), y: Double(delta.z)))
                if let prediction = PositionPlayShotSolver.solve(before: board, shot: shot, surfaceY: surface), prediction.hasFinalTableState {
                    chosen = (board, shot, prediction, physicalFacts(prediction, before: board, shot: shot))
                }
            }
            let (before, shot, prediction, facts) = try XCTUnwrap(chosen, "No executable shot at turn \(turn), \(game)")
            var after: [String: CanvasPoint] = [:]
            for key in before.onTable.keys where !facts.pocketedKeys.contains(key) && !(key == PositionPlayBall.cueKey && facts.cuePocketed) {
                let alias = PositionPlayShotSolver.predName(boardKey: key, shot: shot)
                after[key] = prediction.finalPositions[alias].map(normalized) ?? before.onTable[key]
            }
            board = BoardSnapshot(onTable: after)
            let ruling = engine.judge(facts)
            steps.append(SequenceStep(before: before, shot: shot, after: board,
                potted: facts.pocketedKeys, cuePocketed: facts.cuePocketed, objectPocketed: prediction.objectPocketed, note: ruling.message))
            print("[DailyPhysicalGame] \(game) shot=\(turn + 1) \(ruling.message) remaining=\(board.onTable.count - 1)")
            applyPlacement(ruling, board: &board)
            XCTAssertFalse(ruling.failed, "\(game) \(ruling.message)")
        }
        let environment = ProcessInfo.processInfo.environment
        if let output = environment["DAILY_PHYSICAL_GAME_DIR"] ?? environment["TEST_RUNNER_DAILY_PHYSICAL_GAME_DIR"] {
            let folder = URL(fileURLWithPath: output)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try JSONEncoder().encode(steps).write(to: folder.appendingPathComponent("\(game.rawValue)-steps.json"))
        }
        XCTAssertEqual(engine.state.status, .completed, "\(game) did not finish after \(steps.count) physical shots")
        XCTAssertGreaterThan(steps.count, 1)
    }

    private func physicalFacts(_ prediction: ShotPrediction, before: BoardSnapshot, shot: PlannedShot) -> ShotFacts {
        func key(_ name: String) -> String {
            if name == ShotInput.cueBallName { return PositionPlayBall.cueKey }
            if !shot.isFree && name == ShotInput.targetBallName { return shot.targetKey }
            return name
        }
        var facts = ShotFacts.extract(events: prediction.events, cueName: ShotInput.cueBallName,
            tableKeys: Set(before.onTable.keys), pocketed: Set(prediction.pocketedBalls.map(key)), key: key)
        facts.cueStartedBehindHeadString = (before.onTable[PositionPlayBall.cueKey]?.x ?? 0) > 0.75
        let time = prediction.events.first { event in
            if case .ballBall(let a, let b) = event.kind { return a == ShotInput.cueBallName || b == ShotInput.cueBallName }
            return false
        }?.time ?? 0
        facts.cueCrossedHeadStringBeforeContact = prediction.recorder?.framesByBallName[ShotInput.cueBallName]?.contains {
            $0.time <= time && $0.position.x < AngleSceneCalculator.innerLength / 4
        } ?? false
        return facts
    }

    private func applyPlacement(_ ruling: DailyClearanceRuling, board: inout BoardSnapshot) {
        for key in ruling.respotKeys {
            let occupied = board.onTable.filter { $0.key != key }.values.map(world)
            if let x = DailyRespotPlacement.closestFreeX(foot: -AngleSceneCalculator.innerLength / 4, lower: -AngleSceneCalculator.innerLength / 2 + BallPhysics.radius,
                upper: AngleSceneCalculator.innerLength / 2 - BallPhysics.radius, radius: BallPhysics.radius, occupied: occupied) {
                board.onTable[key] = normalized(SCNVector3(x, BTTablePhysics.surfaceY + BallPhysics.radius, 0))
            }
        }
        if board.onTable[PositionPlayBall.cueKey] == nil && ruling.ballInHand {
            for x in [0.85, 0.9, 0.8] {
                for y in [0.25, 0.15, 0.35] {
                    let point = CanvasPoint(x: x, y: y)
                    if validCue(world(point), board: board, placement: ruling.cuePlacement) {
                        board.onTable[PositionPlayBall.cueKey] = point; return
                    }
                }
            }
        }
    }

    private func validCue(_ point: SCNVector3, board: BoardSnapshot, placement: DailyCuePlacement) -> Bool {
        let radius = BallPhysics.radius
        guard abs(point.x) < AngleSceneCalculator.innerLength / 2 - radius,
              abs(point.z) < AngleSceneCalculator.innerWidth / 2 - radius,
              placement != .behindHeadString || point.x > AngleSceneCalculator.innerLength / 4 else { return false }
        return board.onTable.allSatisfy { key, value in
            key == PositionPlayBall.cueKey || (world(value) - point).length() > 2 * radius
        }
    }
    private func world(_ point: CanvasPoint) -> SCNVector3 {
        AngleSceneCalculator.normalizedToScene(point: CGPoint(x: point.x, y: point.y), surfaceY: BTTablePhysics.surfaceY)
    }
    private func normalized(_ point: SCNVector3) -> CanvasPoint {
        let p = AngleSceneCalculator.sceneToNormalized(position: point)
        return CanvasPoint(x: p.x, y: p.y)
    }
}

extension DailyClearanceRulesTests {
    func testPlayedVisitsCountRunsRatherThanStrokes() throws {
        var engine = DailyClearanceRulesEngine(game: .chineseEightBall)
        XCTAssertEqual(engine.state.playedVisitCount, 0)
        _ = engine.judge(facts(first: "_1", pocketed: ["_1"], table: ["_1", "_2", "_8", "_9"]))
        _ = engine.judge(facts(first: "_2", pocketed: ["_2"], table: ["_2", "_8", "_9"]))
        XCTAssertEqual(engine.state.playedVisitCount, 1)
        let saved = try JSONEncoder().encode(engine.state)
        engine = DailyClearanceRulesEngine(game: .chineseEightBall, state: try JSONDecoder().decode(DailyClearanceRuleState.self, from: saved))
        let result = engine.judge(facts(first: "_8", pocketed: ["_8"], table: ["_8", "_9"]))
        XCTAssertTrue(result.completed)
        XCTAssertEqual(engine.state.playedVisitCount, 1)
        XCTAssertEqual(engine.state.strokeCount, 3)
    }

    func testEmptyVisitCountsOnceAndNextVisitWaitsForActualStroke() {
        var engine = DailyClearanceRulesEngine(game: .chineseEightBall)
        _ = engine.judge(facts(first: "_1", table: fullEightBallTable))
        XCTAssertEqual(engine.state.visitCount, 2)
        XCTAssertEqual(engine.state.playedVisitCount, 1)
        let undoState = engine.state
        _ = engine.judge(facts(first: "_9", pocketed: ["_9"], table: fullEightBallTable))
        XCTAssertEqual(engine.state.playedVisitCount, 2)
        engine = DailyClearanceRulesEngine(game: .chineseEightBall, state: undoState)
        XCTAssertEqual(engine.state.playedVisitCount, 1)
    }

    func testAutomaticBreakDoesNotCountAsPlayerVisitAndLegacyIsUnknown() throws {
        let opening = facts(first: "_1", pocketed: ["_1"], table: fullEightBallTable)
        var automatic = DailyClearanceRulesEngine(game: .chineseEightBall)
        _ = automatic.judgeChineseBreak(opening, automatic: true)
        XCTAssertEqual(automatic.state.playedVisitCount, 0)
        var manual = DailyClearanceRulesEngine(game: .chineseEightBall)
        _ = manual.judgeChineseBreak(opening, automatic: false)
        _ = manual.judge(facts(first: "_2", pocketed: ["_2"], table: fullEightBallTable.subtracting(["_1"])))
        XCTAssertEqual(manual.state.playedVisitCount, 1)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(manual.state)) as? [String: Any])
        json.removeValue(forKey: "playedVisitCount")
        json.removeValue(forKey: "lastPlayedVisit")
        let legacy = try JSONDecoder().decode(DailyClearanceRuleState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(legacy.playedVisitCount)
    }
}


extension DailyClearanceRulesTests {
    func testForcedRerackBySameBreakerStartsAnotherPlayedVisit() {
        var engine = DailyClearanceRulesEngine(game: .chineseEightBall)
        _ = engine.judgeChineseBreak(facts(first: "_1", rail: false, table: fullEightBallTable), automatic: false)
        XCTAssertEqual(engine.state.playedVisitCount, 1)
        XCTAssertTrue(engine.resolveBreakChoice(.rerackByBreaker))
        XCTAssertEqual(engine.state.playedVisitCount, 1, "选择重开还未实际出杆，不应提前计数")
        _ = engine.judgeChineseBreak(facts(first: "_1", pocketed: ["_1"], table: fullEightBallTable), automatic: false)
        XCTAssertEqual(engine.state.playedVisitCount, 2)
    }
}


extension DailyClearanceRulesTests {
    func testWeakBreakOptionsKeepDistinctPlayerWarningAndPlacementEffects() {
        for choice in [DailyBreakChoice.rerackByIncoming, .rerackByBreaker, .acceptBallInHand] {
            var engine = DailyClearanceRulesEngine(game: .chineseEightBall)
            _ = engine.judgeChineseBreak(facts(first: "_1", rail: false, table: fullEightBallTable), automatic: false)
            let player = engine.state.currentPlayer
            let result = engine.resolveBreakChoice(choice)
            XCTAssertTrue(engine.state.breakChoices.isEmpty)
            XCTAssertEqual(result, choice != .acceptBallInHand)
            if choice == .rerackByBreaker {
                XCTAssertEqual(engine.state.currentPlayer, player)
                XCTAssertEqual(engine.state.warnedBreaker, player)
                XCTAssertNil(engine.state.lastPlayedVisit)
            } else {
                XCTAssertNotEqual(engine.state.currentPlayer, player)
            }
            if choice == .acceptBallInHand { XCTAssertEqual(engine.state.cuePlacement, .anywhere) }
        }
    }
}
