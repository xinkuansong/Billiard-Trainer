import XCTest
import SceneKit
@testable import QiuJi

final class AccuracyFeasibleTipTests: XCTestCase {
    private func fixture(_ index: Int, cue: SCNVector3, target: SCNVector3 = SCNVector3(0,0,0), pocket: Int = 4) -> TrainingBankBoard {
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocket, surfaceY: 0)
        return .init(gridID: "access-fixture-\(index)", seed: UInt64(index), cue: cue, target: target, aim: aim,
            pocket: pocket, angle: AngleSceneCalculator.cutAngle(cueBall: cue, targetBall: target, pocket: aim),
            side: 1, cueBand: .long, pocketBand: .middle, combinationID: "access-fixture", qualification: "test-fixture", generationAngle: 0)
    }

    func testDefaultCenterThenMinimumHighAndEnabledAxes() throws {
        let profile = AccuracyTipSelector.renderedProfile()
        var random = SceneTrainingGenerator.SeededRandom(state: 20261021)
        let open = fixture(0, cue: SCNVector3(-0.8,0,0.1))
        let center = try XCTUnwrap(AccuracyTipSelector.select(board: open, configuration: .init(), profile: profile, random: &random))
        XCTAssertEqual(center, .center)
        // Stored corner-mouth layout reproduced in the live-scene audit.
        // Merely being near a straight rail does not imply center is blocked.
        let bank = try TrainingBankStore.load()
        let ti = try XCTUnwrap(bank.payload.targets.firstIndex { $0.inventoryTargetIndex == 2128 })
        let near = bank.board(reference: UInt32(ti << 12 | 37 << 4 | 6), combination: try XCTUnwrap(bank.payload.combinationTable.firstIndex { $0.id == "a2-p1-c2-o1-r0" }))
        let access = AccuracyTipSelector.access(near, profile: profile)
        XCTAssertFalse(access.isAvailable(spinX: 0, spinY: 0), "Fixture must exercise blocked center")
        let high = try XCTUnwrap(AccuracyTipSelector.select(board: near, configuration: .init(), profile: profile, random: &random))
        XCTAssertEqual(high.x, 0); XCTAssertGreaterThan(high.y, 0); XCTAssertTrue(high.raisedForClearance)
        XCTAssertTrue(access.isAvailable(spinX: 0, spinY: Double(high.y)))
        XCTAssertFalse(access.isAvailable(spinX: 0, spinY: Double(max(0,high.y-0.002))), "Fallback should be near first usable height")
        for vertical in [false,true] { for lateral in [false,true] {
            var c = SceneTrainingConfiguration(); c.allowsVerticalSpin = vertical; c.allowsSideSpin = lateral
            for _ in 0..<20 {
                if let tip = AccuracyTipSelector.select(board: near, configuration: c, profile: profile, random: &random) {
                    XCTAssertTrue(access.isAvailable(spinX: Double(tip.x), spinY: Double(tip.y)))
                    if !lateral { XCTAssertEqual(tip.x, 0) }
                    if !vertical && lateral { XCTAssertEqual(tip.y, 0) }
                }
            }
        } }
        // An obstacle overlapping the strike ball leaves no physical access;
        // exercise finite failure, not a false guarantee that upward always works.
        let impossible = CueStrikeAccess(cue: SCNVector3(0,0,0), aim: SCNVector3(1,0,0),
            obstacles: [], surfaceY: 1, profile: profile)
        XCTAssertNil(AccuracyTipSelector.select(access: impossible, vertical: false, lateral: false, random: &random))
    }

    func testReplacementStaysInCombinationAndHasBoundedFailure() throws {
        let bank = try TrainingBankStore.load()
        let initial = try bank.draw(.init(), seed: 19)
        let rejected = try XCTUnwrap(initial.boards.first)
        let changed = try bank.draw(.init(), seed: 19, accepting: { $0.id != rejected.id })
        XCTAssertNotEqual(changed.boards[0].id, rejected.id)
        XCTAssertEqual(changed.boards[0].combinationID, rejected.combinationID)
        XCTAssertEqual(Set(changed.boards.map(\.id)).count, 20)
        var calls = 0
        XCTAssertThrowsError(try bank.draw(.init(), seed: 19, accepting: { _ in calls += 1; return false }))
        XCTAssertLessThanOrEqual(calls, 256 * bank.counts.filter { $0 > 0 }.count)
        let removed = try bank.draw(.init(), seed: 19, accepting: { $0.combinationID != rejected.combinationID })
        XCTAssertEqual(removed.boards.count, 20)
        XCTAssertFalse(removed.boards.contains { $0.combinationID == rejected.combinationID })
        XCTAssertTrue(removed.inaccessibleCombinations.contains(try XCTUnwrap(rejected.combinationID)))
    }

    func testExactTipSurvivesFreezeRoundTripAndLegacyDecoding() throws {
        let bank = try TrainingBankStore.load(), boards = try bank.draw(.init(), seed: 90).boards
        let exact = AccuracyTip(x: 0.137, y: 0.318)
        let questions = boards.map { AccuracyPracticeQuestion(board: $0, selectedTip: exact) }
        var record = try AccuracyPracticeRecord(ownerKey: "test", is3D: true, configuration: .init(), bankFingerprint: bank.sourceFingerprint, questions: questions)
        let frozen = try record.freezeAttempt()
        XCTAssertEqual(frozen.fixedTip, exact)
        let decoded = try JSONDecoder().decode(AccuracyPracticeRecord.self, from: JSONEncoder().encode(record))
        XCTAssertEqual(decoded.attempts.first?.fixedTip, exact)
        XCTAssertEqual(decoded.current?.fixedTip, exact)
        let legacy = AccuracyPracticeQuestion(board: boards[0], tip: .lowLeft)
        let legacyDecoded = try JSONDecoder().decode(AccuracyPracticeQuestion.self, from: JSONEncoder().encode(legacy))
        XCTAssertNil(legacyDecoded.exactTip)
        XCTAssertEqual(legacyDecoded.fixedTip, AccuracyTip(legacy: .lowLeft))
    }

    @MainActor
    func testRailAndPocketSamplesAgainstLiveSceneAndExportReview() throws {
        struct Sample: Encodable {
            let name: String
            let board: TrainingBankBoard
            let tip: AccuracyTip
            let centerAvailable: Bool
            let previousLeftAvailable: Bool
            let elevationDegrees: Float
            let feasibleDisc: [[Bool]]
        }
        let bank = try TrainingBankStore.load(), profile = AccuracyTipSelector.renderedProfile()
        var random = SceneTrainingGenerator.SeededRandom(state: 2026102102)
        // Use real stored layouts: one close to each of the six pocket mouths,
        // plus one near each of the four rail faces, without editing their positions.
        var selected: [TrainingBankBoard] = []
        var best = Array(repeating: Float.infinity, count: 10)
        var slots: [TrainingBankBoard?] = Array(repeating: nil, count: 10)
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: 0)
        for seed in 0..<160 {
            for b in try bank.draw(.init(), seed: UInt64(seed+4000)).boards {
                var scores = pockets.map { hypot(b.cue.x-$0.x,b.cue.z-$0.z) }
                scores += [abs(b.cue.x+1.27-BallPhysics.radius),abs(1.27-BallPhysics.radius-b.cue.x),
                           abs(b.cue.z+0.635-BallPhysics.radius),abs(0.635-BallPhysics.radius-b.cue.z)]
                for i in 0..<10 where scores[i] < best[i] { best[i] = scores[i]; slots[i] = b }
            }
        }
        selected = try slots.map { try XCTUnwrap($0) }
        let names = ["母球靠左上角袋","母球靠右上角袋","母球靠左下角袋","母球靠右下角袋",
                     "母球靠上中袋","母球靠下中袋","母球靠左短库","母球靠右短库","母球靠上长库","母球靠下长库"]
        let scene = AngleTrainingScene()
        scene.configureReferenceTableRendering(); scene.setupScene(enhancedRendering: false)
        var output: [Sample] = [], raised = 0
        for (index, board) in selected.enumerated() {
            let access = AccuracyTipSelector.access(board, profile: profile)
            let centerOK = access.isAvailable(spinX: 0, spinY: 0)
            let tip = try XCTUnwrap(AccuracyTipSelector.select(board: board, configuration: .init(), profile: profile, random: &random))
            if tip.raisedForClearance { raised += 1 }
            let pose = try XCTUnwrap(access.resolvedPose(spinX: Double(tip.x), spinY: Double(tip.y)))
            let y = scene.surfaceY+BallPhysics.radius
            scene.applyBallLayout(cueBallPosition: SCNVector3(board.cue.x,y,board.cue.z),
                targetBallNumber: 10, targetPosition: SCNVector3(board.target.x,y,board.target.z))
            XCTAssertTrue(scene.permitsCueStrike(aim: access.aim, spinX: Double(tip.x), spinY: Double(tip.y)), names[index])
            let live = try XCTUnwrap(scene.cueStrikeAccess(aim: access.aim))
            XCTAssertEqual(live.isAvailable(spinX: 0, spinY: 0), centerOK)
            for vertical in [false,true] { for lateral in [false,true] {
                var c = SceneTrainingConfiguration(); c.allowsVerticalSpin = vertical; c.allowsSideSpin = lateral
                if let candidate = AccuracyTipSelector.select(board: board, configuration: c, profile: profile, random: &random) {
                    XCTAssertTrue(scene.permitsCueStrike(aim: access.aim, spinX: Double(candidate.x), spinY: Double(candidate.y)))
                }
            } }
            let disc = (0...20).map { row in (0...20).map { col in
                live.isAvailable(spinX: Double(col-10)*0.05, spinY: Double(10-row)*0.05)
            } }
            output.append(.init(name: names[index], board: board, tip: tip, centerAvailable: centerOK,
                previousLeftAvailable: live.isAvailable(spinX: 0.25, spinY: 0),
                elevationDegrees: pose.elevation*180 / .pi, feasibleDisc: disc))
        }
        XCTAssertGreaterThan(raised, 0)
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("output/accuracy-feasible-tip-20261021")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
        try encoder.encode(output).write(to: directory.appendingPathComponent("samples.json"), options: .atomic)
        print("FEASIBLE_TIP_REVIEW samples=\(output.count) raised=\(raised) profileSections=\(profile.count)")
    }
}
