import XCTest
import SceneKit
import SwiftData
@testable import QiuJi

final class KickPracticeTests: XCTestCase {
    private let cue = ShotInput.cueBallName
    private func rail(_ wall: KickWall, time: Float = 0) -> ShotEvent {
        let index = (0..<6).first { KickWall.from(cushion: $0) == wall }!
        return .init(time: time, kind: .ballCushion(ball: cue), cushionIndex: index)
    }
    private var hit: ShotEvent { .init(time: 5, kind: .ballBall(ballA: cue, ballB: ShotInput.targetBallName)) }
    func testSelectedBankDemonstrationRebuildsRealShot() throws {
        var configuration = KickConfiguration()
        configuration.railCount = 1
        let question = try KickQuestionPreparer.prepare(configuration, seed: 31).question
        let reference = try KickQuestionPreparer.solve(question: question, input: question.source.input,
            direction: question.source.direction.vector, surfaceY: BTTablePhysics.surfaceY,
            profile: AccuracyTipSelector.renderedProfile())
        let expected = try KickShot(question: question, input: question.source.input, prediction: reference, surfaceY: BTTablePhysics.surfaceY)
        XCTAssertNil(expected.failure, question.source.id + " " + expected.resultText)
        let demo = try question.demonstrationShot(surfaceY: BTTablePhysics.surfaceY)
        XCTAssertEqual(demo.input, question.source.input)
        XCTAssertNil(demo.failure)
    }

    func testDemonstrationUnlockUsesDistinctCompletedShotsAndSurvivesResume() throws {
        let prepared = try KickQuestionPreparer.prepare(.init(), seed: 31)
        var record = KickPracticeRecord(ownerKey: "test", is3D: false, configuration: .init(), prepared: prepared)
        let first = try syntheticShot(prepared.question, success: false)
        record.accept(first); record.accept(first)
        XCTAssertFalse(record.demonstrationUnlocked)
        record.accept(try syntheticShot(prepared.question, success: false))
        record = try KickPracticeRecord.decodePayload(record.encodedPayload())
        XCTAssertFalse(record.demonstrationUnlocked)
        var early = KickPracticeRecord(ownerKey: "test", is3D: false, configuration: .init(), prepared: prepared)
        early.accept(try syntheticShot(prepared.question, success: true))
        XCTAssertTrue(early.demonstrationUnlocked)
        record.accept(try syntheticShot(prepared.question, success: false))
        XCTAssertTrue(record.demonstrationUnlocked)
        XCTAssertEqual(record.attempts.count, 1)
    }

    func testInitialAimUsesEachFirstSegmentMidpointOutsideByOneRadius() throws {
        let prepared = try KickQuestionPreparer.prepare(.init(), seed: 31)
        let rails = TableGeometry.chineseEightBallCushions(y: 0).linear
        for index in 0..<6 {
            var question = prepared.question; question.railSegments = [index]
            let rail = rails[index], point = question.initialAimPoint
            let midpoint = (rail.start + rail.end) * 0.5
            XCTAssertEqual((point - midpoint).dot(rail.normal), -BallPhysics.radius, accuracy: 0.000001)
            XCTAssertEqual((point - midpoint).distanceXZ(to: SCNVector3Zero), BallPhysics.radius, accuracy: 0.000001)
            let delta = point - question.source.cue.vector
            let direction = question.initialDirection.vector
            XCTAssertEqual(hypot(direction.x, direction.z), 1, accuracy: 0.000001)
            XCTAssertEqual(direction.x * delta.z - direction.z * delta.x, 0, accuracy: 0.000001)
            XCTAssertGreaterThan(direction.dot(delta), 0)
            if index < 4 { XCTAssertGreaterThan(abs(point.x), 0.5) } // never the middle pocket
        }
        var record = KickPracticeRecord(ownerKey: "aim", is3D: false, configuration: .init(), prepared: prepared)
        XCTAssertEqual(record.draftDirection, prepared.question.initialDirection)
        record.draftDirection = .init(SCNVector3(1, 0, 0))
        XCTAssertEqual(try KickPracticeRecord.decodePayload(record.encodedPayload()).draftDirection, record.draftDirection)
        record.resetInput()
        XCTAssertEqual(record.draftDirection, prepared.question.initialDirection)
        XCTAssertEqual(record.continuation(prepared: prepared).draftDirection, prepared.question.initialDirection)
    }
    func testDirectAimIncludesThinHitsButAllowsMissesAndCushionFirst() {
        func question(_ target: SCNVector3) -> KickQuestion {
            .init(id: UUID(), source: .init(id: "aim", cue: .init(SCNVector3Zero), target: .init(target),
                walls: [.right], direction: .init(SCNVector3(1, 0, 0)), input: .init()), railSegments: [5])
        }
        for aim in [SCNVector3(1, 0, 0), SCNVector3(-1, 0, 0), SCNVector3(0, 0, 1), SCNVector3(0, 0, -1)] {
            let cross = SCNVector3(-aim.z, 0, aim.x)
            XCTAssertTrue(question(aim * 0.4).aimsDirectlyAtTarget(aim))
            XCTAssertTrue(question(aim * 0.4 + cross * (1.99 * BallPhysics.radius)).aimsDirectlyAtTarget(aim))
            XCTAssertFalse(question(aim * 0.4 + cross * (2.01 * BallPhysics.radius)).aimsDirectlyAtTarget(aim))
            XCTAssertFalse(question(aim * -0.4).aimsDirectlyAtTarget(aim))
        }
        // Synthetic target beyond the right cushion proves event ordering, not an infinite ray test.
        XCTAssertFalse(question(.init(1.4, 0, 0)).aimsDirectlyAtTarget(.init(1, 0, 0)))
    }
    func testOptionalLastRailAcceptsOnlyFullRouteOrExactPrefix() {
        let route = [2, 5, 1, 3]
        for count in 1...4 {
            let expected = Array(route.prefix(count))
            let walls = expected.compactMap { KickWall.from(cushion: $0) }
            func failure(_ actual: [Int], after: [Int] = []) -> KickJudgement.Failure? {
                let before = actual.enumerated().map { ShotEvent(time: Float($0.offset), kind: .ballCushion(ball: cue), cushionIndex: $0.element) }
                let later = after.enumerated().map { ShotEvent(time: Float(6 + $0.offset), kind: .ballCushion(ball: cue), cushionIndex: $0.element) }
                return KickJudgement.failure(events: before + [hit] + later, complete: true, walls: walls, segments: expected)
            }
            XCTAssertEqual(failure(expected), .noRailAfterContact)
            XCTAssertNil(failure(expected, after: [4]))
            let prefix = Array(expected.dropLast())
            if count == 1 {
                XCTAssertEqual(failure(prefix), .directContact)
                XCTAssertEqual(failure(prefix, after: expected), .directContact)
            } else {
                XCTAssertEqual(failure(prefix), .noRailAfterContact)
                XCTAssertNil(failure(prefix, after: [expected.last!]))
                XCTAssertNil(failure(prefix, after: [4, 2])) // after contact is unrestricted
                XCTAssertNotNil(failure(Array(prefix.dropLast())))
            }
            XCTAssertEqual(failure(expected + [4]), .rail)
            XCTAssertEqual(failure(prefix + [4]), .rail)
            if prefix.count > 1 { XCTAssertEqual(failure(Array(prefix.reversed())), .rail) }
            var wrongHalf = expected; wrongHalf[0] = 3
            XCTAssertEqual(failure(wrongHalf), .rail)
        }
    }
    func testOlderKickRecordsKeepHistoryButCannotResume() throws {
        let prepared = try KickQuestionPreparer.prepare(.init(), seed: 31)
        var record = KickPracticeRecord(ownerKey: "old", is3D: false, configuration: .init(), prepared: prepared)
        record.accept(try syntheticShot(prepared.question, success: true))
        XCTAssertEqual(record.judgementVersion, 4)
        XCTAssertTrue(record.canResumeCurrentTraining)
        for version: Int? in [nil, 1, 2, 3] {
            record.judgementVersion = version
            let old = try KickPracticeRecord.decodePayload(record.encodedPayload())
            XCTAssertTrue(old.isCompatible); XCTAssertFalse(old.canResumeCurrentTraining)
            XCTAssertEqual(old.successCount, 1)
            XCTAssertEqual(old.latestShot?.id, record.latestShot?.id)
        }
    }
    func testOrderedRailsRejectDirectFewerExtraAndWrongOrder() {
        let required: [KickWall] = [.top, .right, .bottom]
        let good = required.enumerated().map { rail($0.element, time: Float($0.offset)) } + [hit, rail(.right, time: 6)]
        XCTAssertNil(KickJudgement.failure(events: good, complete: true, walls: required))
        XCTAssertEqual(KickJudgement.failure(events: [hit], complete: true, walls: required), .directContact)
        for bad in [[rail(.top), hit], [rail(.right), rail(.top), rail(.bottom), hit],
                    [rail(.top), rail(.right), rail(.bottom), rail(.left), hit]] {
            XCTAssertEqual(KickJudgement.failure(events: bad, complete: true, walls: required), .rail)
        }
        XCTAssertEqual(KickJudgement.failure(events: good, complete: false, walls: required), .incomplete)
        XCTAssertEqual(KickJudgement.failure(events: [rail(.top)], complete: true, walls: [.top]), .firstContact)
        XCTAssertEqual(KickJudgement.failure(events: [.init(time: 0, kind: .ballCushion(ball: cue), cushionIndex: 6), hit], complete: true, walls: [.top]), .railFacts)
        XCTAssertEqual(KickJudgement.failure(events: [.init(time: 0, kind: .ballBall(ballA: cue, ballB: "obstacle")), hit], complete: true, walls: []), .firstContact)
    }
    func testPostContactRailRequiresEitherBallAfterContactAndScratchStillFails() {
        XCTAssertEqual(KickJudgement.failure(events: [rail(.top), hit], complete: true, walls: [.top]), .noRailAfterContact)
        let targetRail = ShotEvent(time: 6, kind: .ballCushion(ball: ShotInput.targetBallName), cushionIndex: 0)
        XCTAssertNil(KickJudgement.failure(events: [rail(.top), hit, targetRail], complete: true, walls: [.top]))
        let jawAfter = ShotEvent(time: 6, kind: .ballCushion(ball: cue), cushionIndex: 6)
        XCTAssertNil(KickJudgement.failure(events: [rail(.top), hit, jawAfter], complete: true, walls: [.top]))
        let simultaneous = ShotEvent(time: 5, kind: .ballCushion(ball: cue), cushionIndex: 0)
        XCTAssertEqual(KickJudgement.failure(events: [rail(.top), hit, simultaneous], complete: true, walls: [.top]), .noRailAfterContact)
        let before = ShotEvent(time: 4, kind: .ballCushion(ball: ShotInput.targetBallName), cushionIndex: 0)
        XCTAssertEqual(KickJudgement.failure(events: [rail(.top), before, hit], complete: true, walls: [.top]), .noRailAfterContact)
        let unrelatedRail = ShotEvent(time: 6, kind: .ballCushion(ball: "obstacle"), cushionIndex: 0)
        XCTAssertEqual(KickJudgement.failure(events: [rail(.top), hit, unrelatedRail], complete: true, walls: [.top]), .noRailAfterContact)
        let good = [rail(.top), hit, rail(.right, time: 6)]
        XCTAssertNil(KickJudgement.failure(events: good, complete: true, walls: [.top]))
        XCTAssertEqual(KickJudgement.failure(events: good + [.init(time: 7, kind: .pocket(ball: cue, pocketId: "pocket_0"))], complete: true, walls: [.top]), .scratch)
        // The two main segments on a long wall are the same physical wall.
        for wall in [KickWall.top, .bottom] {
            let indices = (0..<6).filter { KickWall.from(cushion: $0) == wall }
            XCTAssertEqual(indices.count, 2)
            for index in indices {
                XCTAssertNil(KickJudgement.failure(events: [.init(time: 1, kind: .ballCushion(ball: cue), cushionIndex: index), hit, rail(.right, time: 6)], complete: true, walls: [wall]))
            }
        }
    }
    func testAllBundledReferencesReplayUnderCurrentProductionPhysics() throws {
        let loadStarted = Date()
        let bank = try KickBankStore.load()
        print("Kick full bank: \(bank.questions.count) questions, cold load \(Date().timeIntervalSince(loadStarted) * 1000) ms")
        XCTAssertEqual(bank.questions.count, 53928)
        let profile = AccuracyTipSelector.renderedProfile()
        var counts: [Int: Int] = [:]
        var referencesWithoutPostContactRail = 0
        for source in bank.questions {
            try autoreleasepool {
                let q = KickQuestion(id: UUID(), source: source)
                let prediction = try KickQuestionPreparer.solve(question: q, input: source.input,
                    direction: source.direction.vector, surfaceY: BTTablePhysics.surfaceY, profile: profile)
                let shot = try KickShot(question: q, input: source.input, prediction: prediction, surfaceY: BTTablePhysics.surfaceY)
                let contact = try XCTUnwrap(prediction.events.first(where: {
                    if case .ballBall = $0.kind { return true }; return false
                }), source.id)
                let hasLaterRail = prediction.events.contains(where: {
                    if case .ballCushion = $0.kind { return $0.time > contact.time }; return false
                })
                XCTAssertEqual(shot.failure, hasLaterRail ? nil : .noRailAfterContact, source.id)
                if !hasLaterRail { referencesWithoutPostContactRail += 1 }
                let segments = PracticeRailColors.beforeTarget(prediction.events)
                XCTAssertEqual(segments.count, source.walls.count)
                XCTAssertEqual(KickJudgement.failure(events: prediction.events, complete: true,
                    walls: source.walls, segments: segments), shot.failure, source.id)
                XCTAssertGreaterThan(shot.trajectory.count, 1, source.id)
                XCTAssertEqual(shot.trajectory.first?.position.x ?? 0, source.cue.x, accuracy: 0.00001)
                XCTAssertFalse(prediction.cuePocketed, source.id)
                counts[source.walls.count, default: 0] += 1
            }
        }
        XCTAssertEqual(counts, [1: 15165, 2: 17974, 3: 13326, 4: 7463])
        XCTAssertEqual(referencesWithoutPostContactRail, 10207)
    }

    // SYMMETRY_SAMPLE_BEGIN: generated from the frozen pre-replay sample manifest.
    func testSymmetryBankCoversEveryCellInAllFourQuadrants() throws {
        let bank = try KickBankStore.load()
        var quadrants: [Int: Int] = [:]
        var cells: [String: Set<String>] = [:]
        var railCounts: [Int: Int] = [:]
        for q in bank.questions {
            let quadrant = (q.cue.x > 0 ? 1 : 0) + (q.cue.z > 0 ? 2 : 0)
            quadrants[quadrant, default: 0] += 1
            railCounts[q.walls.count, default: 0] += 1
            let cell = String(q.id.split(separator: "-")[0])
            cells["\(q.walls.count)/\(quadrant)", default: []].insert(cell)
        }
        XCTAssertEqual(bank.questions.count, 53928)
        XCTAssertEqual(quadrants, [0: 13482, 1: 13482, 2: 13482, 3: 13482])
        XCTAssertEqual(railCounts, [1: 15165, 2: 17974, 3: 13326, 4: 7463])
        XCTAssertEqual(cells.count, 16)
        for (key, value) in cells { XCTAssertEqual(value.count, 72, key) }
    }
    func testFrozenSymmetrySampleReplaysExpectedRailSegments() throws {
        let bank = try KickBankStore.load()
        let sources = Dictionary(uniqueKeysWithValues: bank.questions.map { ($0.id, $0) })
        let profile = AccuracyTipSelector.renderedProfile()
        let fixtures = Self.symmetrySample.split(separator: "\n")
        XCTAssertEqual(fixtures.count, 463)
        var actualCases = 0
        for line in fixtures {
            try autoreleasepool {
                let fields = line.split(separator: "|")
                let id = String(fields[0])
                let expected = try fields[1].split(separator: ",").map { try XCTUnwrap(Int($0)) }
                let source = try XCTUnwrap(sources[id], id)
                let question = KickQuestion(id: UUID(), source: source)
                let prediction = try KickQuestionPreparer.solve(question: question, input: source.input,
                    direction: source.direction.vector, surfaceY: BTTablePhysics.surfaceY, profile: profile)
                let shot = try KickShot(question: question, input: source.input, prediction: prediction,
                    surfaceY: BTTablePhysics.surfaceY)
                XCTAssertEqual(PracticeRailColors.beforeTarget(prediction.events), expected, id)
                XCTAssertEqual(expected.compactMap { KickWall.from(cushion: $0) }, source.walls, id)
                XCTAssertFalse(prediction.cuePocketed, id)
                // Bank references retain their routes; player success additionally
                // requires a later cushion. Do not filter or rewrite the bank.
                let contact = try XCTUnwrap(prediction.events.first(where: {
                    if case .ballBall = $0.kind { return true }; return false
                }), id)
                let hasLaterRail = prediction.events.contains {
                    if case .ballCushion = $0.kind { return $0.time > contact.time }; return false
                }
                XCTAssertEqual(shot.failure, hasLaterRail ? nil : .noRailAfterContact, id)
                XCTAssertGreaterThan(shot.trajectory.count, 1, id)
                XCTAssertEqual(shot.trajectory.first?.position.x ?? 0, source.cue.x, accuracy: 0.00001, id)
                XCTAssertEqual(shot.trajectory.first?.position.z ?? 0, source.cue.z, accuracy: 0.00001, id)
                actualCases += 1
            }
        }
        print("Kick symmetry stratified references replayed: \(actualCases)/463")
        XCTAssertEqual(actualCases, 463)
    }
    private static let symmetrySample = """
    C28-A320-V4.5-S0.25-N3-P0|0,3,5
    C08-A145-V1.5-S-0.25-N1-P0|4
    C33-A295-V1.5-S-0.5-N1-P0|2
    C02-A320-V2.5-S0.25-N3-P0|3,0,4
    C37-A135-V4.5-S0.5-N4-P0|4,0,3,5
    C55-A145-V4.5-S-0.5-N2-P0|4,2
    C38-A295-V3.5-S0-N1-P0|1
    C28-A155-V4.5-S0.25-N4-P0|4,0,5,3
    C08-A130-V2.5-S0-N3-P0|4,0,5
    C68-A020-V4.5-S-0.25-N4-P0|5,1,4,2
    C24-A025-V1.5-S0-N2-P0|5,3
    C36-A155-V1.5-S0.5-N2-P0|5,1
    C35-A035-V4.5-S-0.25-N2-P0|0,4
    C44-A305-V1.5-S-0.5-N3-P0|0,5,3
    C05-A050-V1.5-S0.5-N1-P0|2
    C03-A320-V4.5-S0-N2-P0|0,3
    C43-A055-V2.5-S0.25-N4-P0|2,4,0,3
    C15-A330-V4.5-S0.5-N2-P0|3,4
    C26-A155-V4.5-S0.5-N3-P0|4,0,5
    C20-A120-V3.5-S-0.5-N2-P0|4,2
    C34-A295-V3.5-S-0.25-N1-P0|2
    C65-A055-V2.5-S0.5-N4-P0|0,4,2,1
    C56-A020-V4.5-S0.5-N1-P0|5
    C17-A020-V4.5-S0.25-N2-P0|2,4
    C32-A040-V1.5-S0-N3-P0|0,4,2
    C71-A250-V2.5-S-0.25-N1-P0|0
    C26-A035-V2.5-S0.25-N3-P0|2,4,0
    C62-A245-V1.5-S0.5-N1-P0|3
    C25-A035-V4.5-S0.5-N3-P0|3,5,1
    C32-A235-V2.5-S-0.25-N1-P0|0
    C20-A125-V2.5-S0.25-N4-P0|5,1,2,4
    C52-A225-V3.5-S-0.5-N3-P0|2,4,0
    C28-A300-V3.5-S0-N1-P0|2
    C23-A210-V2.5-S0.5-N1-P0|4
    C44-A015-V3.5-S0.5-N1-P0|5
    C56-A225-V2.5-S0-N4-P0|1,5,3,0
    C45-A040-V3.5-S0.25-N3-P0|3,5,1
    C68-A340-V2.5-S-0.25-N2-P0|0,4
    C17-A320-V3.5-S0.5-N1-P1|3
    C05-A055-V4.5-S0.5-N2-P0|1,2
    C11-A060-V2.5-S0.25-N1-P0|1
    C40-A255-V4.5-S-0.5-N1-P0|1
    C58-A160-V3.5-S-0.5-N1-P0|5
    C01-A065-V3.5-S0-N1-P2|1
    C07-A040-V3.5-S-0.5-N2-P0|3,5
    C40-A200-V2.5-S-0.25-N4-P0|4,0,5,3
    C13-A110-V4.5-S0.5-N3-P0|5,3,1
    C38-A020-V2.5-S-0.25-N2-P0|4,0
    C69-A335-V3.5-S0-N4-P0|0,4,3,5
    C06-A115-V2.5-S0-N2-P0|4,2
    C51-A040-V3.5-S0-N2-P0|3,5
    C23-A130-V3.5-S0-N3-P0|4,2,1
    C53-A115-V3.5-S0.25-N1-P0|2
    C62-A215-V2.5-S0.25-N3-P0|1,5,3
    C03-A045-V2.5-S-0.25-N1-P0|3
    C09-A055-V3.5-S0-N2-P0|0,3
    C07-A135-V4.5-S-0.5-N3-P0|4,0,5
    C05-A290-V3.5-S-0.25-N2-P0|3,1
    C34-A160-V4.5-S0.5-N3-P2|4,2,5
    C17-A300-V1.5-S0-N1-P0|3
    C55-A205-V3.5-S0.25-N2-P0|0,4
    C39-A320-V1.5-S-0.5-N2-P0|2,5
    C09-A290-V3.5-S0-N2-P0|1,3
    C56-A125-V2.5-S0.25-N3-P0|0,4,2
    C57-A150-V3.5-S0.5-N4-P0|4,2,1,5
    C30-A140-V4.5-S0.25-N2-P0|5,1
    C32-A320-V4.5-S0.25-N2-P0|1,2
    C64-A055-V2.5-S-0.25-N2-P0|0,2
    C59-A230-V2.5-S0-N3-P0|0,4,2
    C23-A220-V1.5-S0-N3-P0|5,3,4
    C26-A035-V2.5-S0.25-N1-P1|3
    C14-A110-V2.5-S0.25-N1-P0|4
    C30-A130-V2.5-S0.5-N4-P0|4,2,1,5
    C56-A155-V1.5-S0.5-N2-P0|5,1
    C57-A045-V1.5-S-0.5-N2-P0|1,5
    C30-A120-V4.5-S0.25-N1-P0|5
    C22-A135-V2.5-S0.5-N4-P0|5,3,0,4
    C04-A340-V3.5-S0.5-N1-P1|0
    C23-A220-V2.5-S0.25-N2-P0|4,2
    C40-A295-V2.5-S-0.5-N3-P0|3,0,4
    C42-A110-V1.5-S0-N2-P0|0,4
    C21-A245-V3.5-S-0.25-N1-P0|3
    C04-A315-V4.5-S0.25-N2-P0|3,0
    C04-A050-V3.5-S0.25-N4-P0|2,1,5,3
    C66-A030-V2.5-S0-N1-P0|5
    C61-A110-V3.5-S-0.5-N4-P0|3,5,1,2
    C43-A130-V2.5-S0-N2-P0|4,0
    C29-A295-V1.5-S-0.25-N1-P0|2
    C34-A340-V4.5-S0-N2-P0|3,5
    C69-A050-V1.5-S0.5-N2-P0|1,5
    C64-A235-V3.5-S0.5-N2-P0|3,5
    C40-A330-V4.5-S0-N2-P0|3,5
    C09-A035-V1.5-S-0.5-N2-P0|2,4
    C10-A120-V1.5-S-0.25-N2-P0|4,0
    C48-A155-V2.5-S0.25-N1-P0|4
    C68-A130-V4.5-S-0.25-N2-P0|3,5
    C62-A115-V2.5-S0.25-N2-P0|1,3
    C33-A305-V2.5-S0.5-N2-P0|1,2
    C55-A225-V4.5-S-0.25-N4-P0|1,5,3,0
    C21-A025-V4.5-S0.25-N1-P0|0
    C63-A325-V4.5-S0.25-N2-P0|0,4
    C39-A310-V4.5-S-0.25-N4-P0|1,2,4,0
    C47-A040-V1.5-S0.25-N3-P0|3,5,1
    C36-A025-V4.5-S0-N3-P0|4,0,5
    C61-A130-V2.5-S0-N4-P0|0,4,2,1
    C38-A215-V2.5-S0.5-N3-P0|3,5,1
    C53-A105-V2.5-S0.25-N1-P0|3
    C41-A030-V1.5-S0.5-N2-P0|3,5
    C52-A155-V4.5-S0.5-N2-P0|4,0
    C58-A150-V3.5-S0-N4-P0|4,2,5,1
    C19-A220-V2.5-S0-N3-P0|3,5,1
    C67-A050-V4.5-S0.25-N4-P0|3,5,1,2
    C30-A030-V2.5-S-0.5-N3-P0|4,2,1
    C35-A335-V3.5-S-0.25-N3-P0|0,4,2
    C46-A255-V3.5-S-0.5-N1-P0|3
    C65-A250-V4.5-S0.25-N2-P0|2,0
    C55-A205-V3.5-S0-N4-P0|2,4,1,5
    C40-A305-V2.5-S0.5-N2-P0|0,3
    C58-A235-V4.5-S-0.25-N3-P0|1,3,5
    C69-A060-V2.5-S0-N1-P0|0
    C60-A130-V3.5-S-0.5-N3-P1|1,5,3
    C47-A040-V2.5-S0.5-N3-P0|0,4,2
    C65-A160-V4.5-S0.25-N3-P1|5,3,4
    C35-A205-V4.5-S0-N3-P0|5,1,4
    C08-A050-V3.5-S0-N3-P1|1,2,4
    C42-A060-V3.5-S-0.5-N2-P1|3,1
    C56-A130-V3.5-S-0.5-N1-P0|0
    C56-A235-V4.5-S0.25-N3-P0|0,4,2
    C37-A335-V4.5-S0-N4-P0|2,5,1,4
    C63-A150-V1.5-S0.25-N2-P0|5,3
    C29-A150-V3.5-S0-N4-P0|5,1,4,2
    C06-A120-V4.5-S0-N3-P0|5,3,0
    C67-A330-V3.5-S0.25-N1-P0|3
    C48-A055-V1.5-S-0.25-N2-P0|0,4
    C69-A215-V4.5-S-0.5-N3-P0|0,4,3
    C60-A035-V3.5-S0.25-N3-P0|5,3,4
    C69-A130-V4.5-S-0.25-N1-P1|1
    C13-A140-V3.5-S-0.5-N2-P0|4,3
    C17-A055-V4.5-S0.5-N1-P0|2
    C21-A160-V2.5-S0.5-N4-P0|5,3,4,0
    C60-A035-V4.5-S-0.25-N4-P0|5,3,0,4
    C43-A025-V4.5-S0.25-N1-P0|4
    C53-A240-V1.5-S0.25-N3-P0|3,5,1
    C28-A305-V4.5-S-0.25-N2-P0|0,3
    C03-A050-V4.5-S-0.5-N4-P0|0,3,5,1
    C29-A195-V4.5-S0.5-N1-P0|5
    C53-A130-V2.5-S0-N4-P0|1,5,3,0
    C44-A150-V2.5-S0.5-N3-P0|5,1,2
    C57-A045-V1.5-S-0.25-N2-P0|3,5
    C30-A140-V3.5-S0.5-N3-P0|4,2,1
    C38-A305-V1.5-S-0.25-N1-P0|2
    C15-A055-V1.5-S0-N3-P0|0,3,5
    C10-A055-V1.5-S-0.25-N1-P0|3
    C59-A165-V4.5-S-0.25-N1-P0|5
    C31-A145-V4.5-S0.5-N2-P0|5,1
    C37-A135-V4.5-S0.5-N2-P0|5,3
    C04-A310-V3.5-S0.25-N1-P0|3
    C20-A320-V1.5-S-0.5-N1-P0|1
    C43-A160-V1.5-S0.5-N2-P0|5,3
    C58-A220-V2.5-S0.5-N3-P0|0,4,2
    C50-A115-V2.5-S-0.25-N2-P0|2,4
    C43-A340-V3.5-S-0.25-N4-P0|2,5,1,4
    C38-A040-V4.5-S0-N3-P0|3,5,1
    C26-A245-V3.5-S0.5-N4-P0|3,5,1,2
    C14-A125-V1.5-S0.25-N2-P0|4,0
    C50-A140-V3.5-S0.5-N4-P0|5,3,0,4
    C19-A055-V2.5-S0-N3-P0|0,3,5
    C11-A045-V3.5-S-0.5-N2-P0|3,0
    C63-A215-V4.5-S0-N2-P0|3,5
    C28-A160-V1.5-S0.5-N1-P0|5
    C09-A320-V1.5-S-0.5-N3-P0|0,5,3
    C58-A045-V1.5-S-0.25-N1-P0|3
    C29-A065-V4.5-S0.5-N4-P0|2,1,5,3
    C56-A110-V4.5-S0.5-N1-P0|3
    C14-A050-V2.5-S-0.25-N2-P0|0,3
    C58-A045-V2.5-S-0.25-N2-P0|1,5
    C56-A125-V2.5-S-0.25-N4-P0|0,4,2,1
    C00-A055-V4.5-S-0.25-N2-P0|3,0
    C37-A045-V1.5-S0.25-N2-P0|0,4
    C46-A120-V1.5-S-0.25-N3-P0|3,5,1
    C51-A250-V2.5-S0.5-N2-P0|3,5
    C49-A045-V4.5-S-0.5-N3-P0|0,4,2
    C68-A120-V2.5-S-0.5-N3-P0|1,5,3
    C64-A235-V3.5-S0.25-N4-P0|3,5,1,2
    C02-A300-V3.5-S-0.5-N2-P0|3,0
    C18-A025-V3.5-S-0.25-N2-P0|5,1
    C19-A145-V2.5-S0.25-N3-P0|4,2,5
    C63-A230-V2.5-S0.25-N2-P1|2,4
    C09-A295-V4.5-S-0.25-N1-P0|2
    C71-A150-V3.5-S-0.5-N1-P0|1
    C07-A340-V2.5-S-0.5-N3-P0|3,4,0
    C12-A060-V1.5-S0.25-N3-P0|3,0,4
    C22-A065-V3.5-S0.25-N2-P0|1,2
    C11-A305-V4.5-S0.25-N1-P0|0
    C39-A320-V3.5-S0-N1-P1|3
    C07-A335-V3.5-S-0.25-N2-P1|0,5
    C65-A045-V2.5-S0.5-N2-P0|1,5
    C48-A025-V2.5-S0-N1-P0|4
    C26-A235-V2.5-S-0.25-N1-P0|3
    C02-A065-V4.5-S0.5-N4-P0|3,0,4,2
    C57-A220-V2.5-S-0.25-N3-P0|0,4,2
    C31-A025-V3.5-S-0.25-N2-P0|4,2
    C53-A335-V2.5-S0-N1-P0|3
    C26-A240-V4.5-S0.25-N4-P0|1,5,3,0
    C70-A025-V2.5-S0-N2-P0|4,0
    C49-A225-V3.5-S0-N2-P0|1,5
    C21-A065-V2.5-S-0.5-N1-P0|2
    C52-A165-V4.5-S-0.5-N1-P0|5
    C58-A310-V4.5-S0.5-N3-P0|2,0,4
    C71-A230-V3.5-S0.5-N3-P1|1,5,3
    C70-A070-V3.5-S0-N2-P0|0,2
    C50-A215-V3.5-S0-N3-P0|2,4,0
    C17-A075-V4.5-S-0.5-N1-P1|0
    C50-A025-V4.5-S-0.5-N2-P0|4,0
    C56-A340-V4.5-S0.25-N2-P0|1,5
    C10-A305-V2.5-S0-N1-P0|3
    C29-A335-V3.5-S-0.5-N2-P0|3,5
    C61-A025-V1.5-S-0.25-N3-P0|5,1,4
    C59-A045-V4.5-S0.25-N2-P0|1,5
    C04-A055-V1.5-S0.25-N3-P0|2,1,5
    C66-A155-V3.5-S0.25-N2-P0|4,0
    C64-A230-V4.5-S0.5-N2-P0|1,5
    C20-A035-V2.5-S-0.5-N2-P0|3,5
    C25-A035-V4.5-S0.5-N2-P0|0,4
    C40-A115-V1.5-S-0.5-N1-P0|1
    C47-A230-V3.5-S-0.5-N3-P0|1,5,3
    C37-A335-V3.5-S0.5-N2-P0|1,4
    C70-A325-V1.5-S-0.5-N3-P0|0,4,2
    C64-A045-V1.5-S0.25-N2-P0|1,5
    C15-A070-V3.5-S0-N2-P0|3,1
    C29-A290-V2.5-S-0.5-N3-P0|1,2,4
    C67-A050-V2.5-S0.25-N4-P0|3,5,1,2
    C02-A335-V4.5-S0-N2-P1|0,5
    C61-A220-V3.5-S0.25-N2-P0|0,4
    C70-A045-V3.5-S-0.25-N1-P1|1
    C46-A230-V1.5-S0.5-N1-P0|2
    C11-A125-V2.5-S0.25-N2-P0|5,3
    C50-A105-V1.5-S0-N2-P0|3,1
    C59-A320-V4.5-S0.5-N2-P0|2,4
    C40-A035-V1.5-S0.25-N1-P1|1
    C57-A235-V4.5-S0.5-N2-P0|0,4
    C33-A290-V3.5-S-0.5-N1-P0|0
    C37-A340-V2.5-S0-N2-P0|1,4
    C63-A235-V2.5-S-0.5-N1-P0|0
    C64-A130-V4.5-S0.25-N3-P0|1,5,3
    C00-A015-V2.5-S0.25-N1-P0|5
    C57-A330-V3.5-S0-N3-P1|1,5,3
    C21-A335-V2.5-S0.25-N2-P0|0,5
    C31-A065-V2.5-S0.5-N1-P0|1
    C42-A045-V3.5-S-0.25-N3-P0|3,5,1
    C39-A115-V4.5-S-0.25-N4-P0|1,5,3,0
    C16-A150-V3.5-S0.5-N2-P0|4,0
    C26-A065-V4.5-S0-N1-P1|3
    C45-A035-V3.5-S0.5-N4-P0|0,4,2,5
    C37-A020-V4.5-S0-N1-P0|5
    C33-A135-V4.5-S0.25-N3-P0|5,1,2
    C36-A045-V2.5-S-0.25-N2-P0|2,4
    C11-A045-V2.5-S0.25-N3-P0|0,3,5
    C54-A060-V2.5-S0-N2-P1|1,3
    C45-A220-V2.5-S0-N3-P0|1,5,3
    C70-A130-V2.5-S-0.25-N3-P0|1,5,3
    C03-A040-V1.5-S0.25-N1-P0|2
    C35-A250-V1.5-S0-N1-P0|2
    C67-A205-V4.5-S-0.5-N2-P0|3,5
    C54-A200-V3.5-S0-N3-P0|1,5,2
    C20-A145-V3.5-S0.25-N4-P0|4,0,5,3
    C58-A335-V4.5-S0-N4-P0|3,5,0,4
    C18-A125-V3.5-S0.5-N2-P0|4,2
    C65-A120-V1.5-S0-N1-P0|2
    C59-A050-V3.5-S0.5-N2-P0|2,4
    C24-A150-V2.5-S0.5-N1-P0|4
    C30-A155-V4.5-S-0.25-N1-P0|4
    C31-A065-V2.5-S0.25-N4-P0|2,1,5,3
    C10-A290-V2.5-S0-N2-P0|0,2
    C18-A145-V4.5-S0.5-N1-P0|5
    C62-A150-V2.5-S-0.25-N2-P0|4,0
    C38-A295-V1.5-S-0.5-N3-P0|3,0,4
    C67-A155-V2.5-S0.5-N2-P0|5,3
    C08-A065-V3.5-S0-N1-P0|3
    C71-A250-V2.5-S0.5-N1-P0|2
    C22-A035-V4.5-S-0.25-N1-P0|1
    C23-A050-V4.5-S0.25-N4-P0|1,2,4,0
    C28-A200-V3.5-S-0.25-N4-P0|5,1,4,2
    C64-A310-V1.5-S0.25-N1-P0|1
    C39-A020-V3.5-S0.5-N1-P0|5
    C16-A200-V4.5-S-0.25-N2-P0|5,3
    C35-A245-V3.5-S0.25-N3-P0|0,4,2
    C50-A115-V4.5-S-0.5-N4-P0|3,5,1,2
    C55-A020-V3.5-S-0.5-N3-P0|5,3,4
    C31-A155-V4.5-S0.5-N2-P0|4,0
    C52-A130-V1.5-S-0.5-N2-P0|2,4
    C64-A225-V3.5-S-0.25-N4-P0|3,5,1,2
    C13-A160-V1.5-S0.25-N2-P0|4,3
    C51-A115-V2.5-S0.5-N2-P0|3,5
    C61-A230-V3.5-S0.25-N2-P1|3,5
    C02-A060-V1.5-S0.25-N1-P0|1
    C15-A300-V3.5-S-0.5-N4-P0|2,1,5,3
    C57-A325-V2.5-S0.5-N1-P0|2
    C39-A040-V3.5-S0.25-N2-P0|2,4
    C52-A035-V2.5-S0.25-N2-P0|2,4
    C49-A140-V4.5-S-0.25-N2-P0|4,0
    C68-A235-V2.5-S-0.5-N3-P0|2,0,4
    C02-A340-V3.5-S-0.25-N1-P1|0
    C43-A130-V2.5-S0-N4-P0|4,2,1,5
    C15-A325-V1.5-S-0.5-N3-P0|0,5,3
    C07-A335-V3.5-S-0.5-N3-P0|1,4,2
    C28-A310-V4.5-S-0.25-N4-P0|3,0,4,2
    C32-A145-V4.5-S-0.25-N1-P0|4
    C01-A055-V4.5-S-0.5-N4-P0|3,0,4,2
    C62-A220-V3.5-S0-N4-P0|0,4,2,1
    C57-A105-V1.5-S0-N2-P0|3,1
    C13-A125-V2.5-S-0.25-N4-P0|4,0,3,5
    C54-A160-V3.5-S-0.25-N1-P0|4
    C47-A125-V1.5-S0-N3-P0|2,4,0
    C03-A305-V3.5-S0.5-N2-P0|3,1
    C60-A060-V2.5-S-0.25-N1-P0|2
    C41-A025-V4.5-S0-N3-P0|1,5,2
    C57-A330-V1.5-S0-N3-P0|0,4,3
    C15-A330-V3.5-S0-N1-P0|0
    C49-A115-V2.5-S-0.5-N4-P0|1,5,3,0
    C55-A225-V4.5-S-0.25-N1-P1|3
    C41-A330-V4.5-S-0.5-N3-P1|2,4,0
    C19-A315-V2.5-S0.5-N4-P0|2,1,5,3
    C63-A220-V3.5-S-0.25-N3-P0|3,5,1
    C68-A215-V2.5-S-0.25-N3-P0|1,5,3
    C44-A285-V3.5-S0-N1-P1|2
    C39-A035-V4.5-S-0.25-N3-P0|1,5,2
    C70-A055-V3.5-S0.5-N3-P0|3,5,1
    C14-A320-V3.5-S0-N3-P0|3,0,4
    C70-A050-V1.5-S0.25-N1-P0|2
    C60-A140-V4.5-S-0.5-N3-P0|5,3,0
    C46-A225-V1.5-S-0.5-N2-P0|0,4
    C44-A220-V2.5-S-0.25-N3-P0|1,5,3
    C16-A315-V4.5-S-0.25-N1-P1|0
    C12-A130-V4.5-S0.25-N4-P0|4,2,1,5
    C14-A130-V3.5-S0.25-N3-P0|5,1,2
    C50-A300-V2.5-S-0.5-N1-P0|1
    C27-A290-V2.5-S-0.5-N4-P0|0,3,5,1
    C49-A050-V3.5-S0.25-N3-P0|1,5,3
    C06-A345-V1.5-S-0.5-N1-P0|3
    C03-A335-V1.5-S-0.5-N1-P0|0
    C65-A300-V4.5-S-0.25-N4-P0|2,0,4,2
    C49-A050-V3.5-S0.5-N1-P1|3
    C53-A325-V4.5-S-0.25-N3-P0|1,5,3
    C57-A235-V1.5-S0-N1-P0|1
    C43-A160-V2.5-S-0.25-N1-P0|4
    C61-A150-V4.5-S0.5-N4-P0|5,1,2,4
    C62-A335-V2.5-S0.25-N3-P0|3,5,4
    C71-A230-V3.5-S0.25-N3-P0|1,5,3
    C24-A130-V3.5-S0.5-N4-P0|5,1,2,4
    C12-A065-V3.5-S-0.25-N1-P0|1
    C60-A110-V2.5-S-0.5-N4-P0|3,5,1,2
    C41-A150-V2.5-S0.5-N3-P0|4,0,3
    C68-A070-V1.5-S0-N2-P0|3,1
    C43-A055-V3.5-S0-N1-P0|0
    C19-A155-V2.5-S-0.5-N1-P0|4
    C19-A345-V3.5-S-0.25-N4-P1|1,4,2,5
    C51-A110-V3.5-S-0.5-N4-P0|0,4,2,1
    C47-A235-V3.5-S0-N4-P0|2,4,0,3
    C12-A035-V2.5-S0.25-N3-P0|1,5,3
    C64-A135-V4.5-S0.25-N1-P1|0
    C61-A030-V3.5-S0.25-N1-P0|4
    C34-A235-V1.5-S0.5-N3-P0|3,5,1
    C22-A310-V3.5-S0.5-N1-P0|0
    C51-A045-V3.5-S0.5-N3-P0|1,5,3
    C70-A120-V3.5-S0.5-N4-P1|2,0,4,2
    C18-A060-V2.5-S0.25-N1-P0|1
    C17-A215-V2.5-S-0.5-N2-P0|5,1
    C04-A310-V2.5-S-0.25-N3-P0|2,1,5
    C22-A135-V3.5-S-0.5-N4-P0|4,2,1,5
    C57-A230-V2.5-S-0.5-N2-P0|2,4
    C54-A060-V2.5-S0.5-N3-P0|2,4,0
    C71-A305-V4.5-S-0.5-N4-P0|1,5,3,0
    C31-A040-V1.5-S0.5-N3-P0|3,5,1
    C28-A110-V4.5-S-0.5-N2-P0|3,5
    C09-A015-V4.5-S0-N1-P0|4
    C65-A035-V1.5-S0.5-N3-P0|1,5,3
    C21-A050-V2.5-S0.5-N3-P0|0,5,3
    C28-A130-V4.5-S0-N4-P0|4,2,1,5
    C21-A130-V4.5-S-0.25-N1-P0|5
    C00-A040-V2.5-S-0.5-N2-P0|3,5
    C16-A320-V1.5-S-0.25-N2-P0|1,4
    C23-A295-V3.5-S-0.5-N1-P0|1
    C67-A335-V3.5-S-0.25-N3-P0|3,5,1
    C05-A325-V1.5-S-0.5-N1-P0|2
    C57-A335-V4.5-S0-N4-P0|0,4,3,5
    C56-A050-V4.5-S0.25-N4-P0|1,5,3,0
    C19-A040-V3.5-S-0.25-N4-P0|3,5,1,4
    C48-A150-V2.5-S0.25-N2-P0|4,0
    C34-A245-V4.5-S0.5-N4-P1|1,5,3,0
    C52-A330-V2.5-S-0.5-N3-P0|1,5,3
    C48-A065-V1.5-S-0.25-N1-P0|0
    C08-A110-V4.5-S-0.5-N2-P1|4,2
    C40-A295-V3.5-S-0.25-N1-P0|1
    C60-A145-V2.5-S0-N1-P0|4
    C34-A070-V4.5-S-0.5-N1-P0|2
    C60-A145-V4.5-S-0.25-N3-P0|5,1,4
    C48-A135-V3.5-S-0.25-N3-P0|5,3,0
    C27-A070-V2.5-S0.5-N1-P1|0
    C34-A110-V2.5-S-0.25-N4-P0|1,5,3,0
    C27-A295-V2.5-S-0.5-N2-P0|3,0
    C14-A135-V4.5-S0.5-N4-P0|4,2,1,5
    C39-A220-V1.5-S0.25-N3-P0|2,4,0
    C66-A060-V2.5-S0.25-N4-P0|0,4,2,1
    C05-A320-V4.5-S0-N1-P0|1
    C50-A025-V1.5-S0-N2-P0|4,0
    C66-A020-V2.5-S-0.5-N1-P0|4
    C66-A115-V2.5-S-0.25-N1-P0|3
    C01-A050-V2.5-S-0.25-N1-P0|0
    C06-A130-V4.5-S0-N2-P0|5,3
    C25-A040-V4.5-S-0.25-N4-P0|1,5,3,4
    C31-A065-V3.5-S0.5-N4-P0|0,3,5,0
    C52-A105-V2.5-S0.5-N1-P0|3
    C13-A320-V4.5-S0.25-N3-P0|3,0,4
    C27-A145-V2.5-S0.25-N4-P0|5,3,4,0
    C24-A145-V2.5-S-0.5-N2-P0|5,2
    C41-A125-V4.5-S0-N4-P0|3,5,1,2
    C44-A240-V1.5-S0.25-N4-P0|1,5,3,0
    C43-A330-V4.5-S0.25-N3-P0|2,5,1
    C57-A250-V1.5-S0.5-N3-P0|1,5,3
    C27-A320-V1.5-S-0.5-N2-P0|3,4
    C01-A325-V1.5-S0.5-N1-P0|0
    C45-A145-V2.5-S0.25-N2-P0|4,0
    C33-A340-V4.5-S0-N1-P0|3
    C63-A025-V2.5-S0-N1-P0|4
    C30-A040-V4.5-S0-N4-P0|0,4,2,1
    C25-A155-V3.5-S0.25-N1-P0|5
    C00-A040-V2.5-S-0.25-N1-P0|0
    C68-A060-V4.5-S-0.5-N4-P2|2,0,4,2
    C54-A050-V2.5-S-0.25-N2-P0|0,4
    C42-A045-V2.5-S-0.25-N2-P0|0,4
    C06-A120-V3.5-S-0.25-N1-P0|4
    C57-A220-V4.5-S-0.5-N2-P0|2,4
    C20-A325-V1.5-S-0.25-N3-P0|0,5,3
    C14-A140-V1.5-S0.5-N3-P0|5,3,0
    C38-A140-V2.5-S-0.25-N4-P0|5,3,4,0
    C68-A130-V3.5-S0.5-N3-P0|1,5,3
    C19-A155-V2.5-S0.25-N4-P0|4,1,5,3
    C24-A015-V3.5-S0.25-N1-P1|5
    C36-A135-V3.5-S0.25-N3-P0|4,0,3
    C02-A325-V3.5-S0.25-N3-P0|2,1,5
    C12-A140-V3.5-S0.25-N4-P0|5,3,4,0
    C16-A205-V1.5-S-0.25-N4-P0|4,2,5,1
    C36-A145-V4.5-S-0.25-N1-P0|4
    C60-A035-V3.5-S-0.25-N4-P0|4,2,1,5
    C49-A315-V3.5-S-0.5-N4-P0|3,4,0,3
    C42-A045-V2.5-S0.25-N1-P1|2
    C33-A240-V1.5-S-0.25-N3-P1|3,5,1
    C15-A045-V3.5-S0.5-N1-P0|0
    C68-A120-V4.5-S-0.5-N4-P0|1,5,3,0
    C31-A110-V2.5-S-0.5-N4-P0|0,4,2,1
    C67-A225-V1.5-S0.25-N4-P0|2,4,0,3
    C68-A030-V3.5-S-0.5-N4-P0|4,0,3,5
    C44-A110-V1.5-S-0.5-N3-P0|0,4,2
    C32-A230-V1.5-S0.25-N4-P0|3,5,1,2
    C21-A150-V1.5-S0.25-N4-P0|4,2,5,1
    C23-A220-V1.5-S0-N4-P0|4,2,5,1
    C11-A230-V1.5-S-0.25-N4-P0|4,0,3,5
    C11-A235-V1.5-S-0.25-N4-P0|5,3,0,4
    C15-A205-V1.5-S-0.25-N4-P0|5,1,4,2
    C17-A220-V1.5-S0-N4-P0|4,0,5,3
    C16-A220-V1.5-S0-N4-P0|5,3,4,0
    C26-A230-V1.5-S0-N4-P0|1,5,3,0
    """
    // SYMMETRY_SAMPLE_END

    func testFilteringNonRepeatingSelectionAndExplicitExhaustion() throws {
        var config = KickConfiguration(); config.railCount = 4
        let fourRailIDs = try KickBankStore.load().questions.filter { $0.walls.count == 4 }.map(\.id)
        // Exercise the last three unseen entries and exhaustion, independent of bank size.
        var seen = Set(fourRailIDs.dropLast(3))
        for _ in 0..<3 {
            let prepared = try KickQuestionPreparer.prepare(config, excluding: seen, seed: 31)
            XCTAssertEqual(prepared.question.source.walls.count, 4)
            XCTAssertTrue(seen.insert(prepared.question.contentID).inserted)
        }
        XCTAssertThrowsError(try KickQuestionPreparer.prepare(config, excluding: seen))
    }
    @MainActor func testPreviousBankRecordRemainsReadableButCannotResumeIntoNewBank() throws {
        let suite = "KickPreviousBankTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let owner = CurrentOwnerContext(defaults: defaults)
        let context = ModelContext(ModelContainerFactory.makeInMemoryContainer())
        let repository = LocalKickPracticeRepository(context: context, owner: owner, enqueue: { _, _ in })
        let prepared = try KickQuestionPreparer.prepare(.init(), seed: 31)
        let previous = KickQuestionPreparer.Prepared(fingerprint: "previous-bank", question: prepared.question)
        var record = KickPracticeRecord(ownerKey: owner.ownerKey, is3D: false, configuration: .init(), prepared: previous)
        record.accept(try syntheticShot(prepared.question, success: true))
        try repository.save(record)
        let restored = try KickPracticeRecord.decodePayload(record.encodedPayload())
        XCTAssertTrue(restored.isCompatible)
        XCTAssertEqual(restored.current?.contentID, prepared.question.contentID)
        XCTAssertFalse(restored.canResumeCurrentTraining)
        XCTAssertNil(try repository.resumable(is3D: false, compatible: { $0.canResumeCurrentTraining }))
        let sessions = try context.fetch(FetchDescriptor<TrainingSession>())
        XCTAssertEqual(HistoryViewModel.assembleKickSessions(sessions: sessions).records.count, 1)
        let current = KickPracticeRecord(ownerKey: owner.ownerKey, is3D: false, configuration: .init(), prepared: prepared)
        try repository.save(current)
        XCTAssertEqual(try repository.resumable(is3D: true, compatible: { $0.canResumeCurrentTraining })?.id, current.id)
    }
    func testFirstAnswerFrozenRetryAndPayloadRoundTrip() throws {
        let prepared = try KickQuestionPreparer.prepare(.init(), seed: 31)
        var record = KickPracticeRecord(ownerKey: "test", is3D: false, configuration: .init(), prepared: prepared)
        let failed = try syntheticShot(prepared.question, success: false)
        let success = try syntheticShot(prepared.question, success: true)
        record.accept(failed); record.accept(success); record.accept(success)
        XCTAssertEqual(record.attempts.count, 1); XCTAssertEqual(record.successCount, 0)
        XCTAssertEqual(record.latestShot?.id, success.id)
        let restored = try KickPracticeRecord.decodePayload(record.encodedPayload())
        XCTAssertTrue(restored.canResumeCurrentTraining)
        XCTAssertEqual(restored.draftDirection, success.direction)
        XCTAssertEqual(restored.latestShot?.id, success.id)
        XCTAssertFalse(TrainingSessionKind.countsTowardAccuracy(TrainingSessionKind.kickPractice))
    }
    @MainActor func testDirectionSettingsCancelViewSwitchAndOwnerIsolation() throws {
        let suite = "KickPracticeTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let limiter = AngleUsageLimiter(defaults: defaults, namespace: suite, limit: 15)
        limiter.isPremium = true
        let prepared = try KickQuestionPreparer.prepare(.init(), seed: 31)
        let repo = MemoryKickRepository()
        let vm = KickPracticeViewModel(is3D: false, limiter: limiter, defaults: defaults)
        vm.attach(repository: repo); vm.start(.init(), prepared: prepared)
        let id = vm.record?.current?.id, initial = vm.record?.draftDirection
        vm.nudgeAim(15); vm.velocity = 3; vm.setSpin(0.25, 0)
        XCTAssertNotEqual(vm.record?.draftDirection, initial)
        let direction = vm.record?.draftDirection, input = vm.input
        vm.openSettings(); XCTAssertTrue(vm.cancelSettings())
        XCTAssertTrue(vm.switchTrainingView(to: true))
        XCTAssertEqual(vm.record?.current?.id, id); XCTAssertEqual(vm.record?.draftDirection, direction)
        XCTAssertEqual(vm.input, input); XCTAssertEqual(limiter.questionsUsedToday, 0)
        XCTAssertFalse(vm.shouldShowReference)
        vm.ownerChanged(); XCTAssertNil(vm.record)
    }
    @MainActor func testRealSubmissionUsesPlayerDirectionAndRetryFreezesFirstSuccess() async throws {
        let suite = "KickSubmissionTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let limiter = AngleUsageLimiter(defaults: defaults, namespace: suite, limit: 15)
        limiter.isPremium = true
        var config = KickConfiguration(); config.playsStroke = false
        let bank = try KickBankStore.load()
        let prepared = try KickQuestionPreparer.prepare(config,
            excluding: Set(bank.questions.map(\.id)).subtracting(["C53-A035-V4.5-S-0.5-N1-P0"]), seed: 31)
        let vm = KickPracticeViewModel(is3D: false, limiter: limiter, defaults: defaults)
        let repository = MemoryKickRepository()
        vm.attach(repository: repository); vm.start(config, prepared: prepared)
        vm.setupScene()
        defer { vm.suspendTeachingActivity() }
        XCTAssertFalse(vm.shouldShowReference)
        XCTAssertNil(vm.referenceTrajectory)
        vm.setSpin(0.25, 0.25); vm.velocity = 3.5
        vm.nudgeAim(5); vm.nudgeAim(-2)
        XCTAssertTrue(vm.switchTrainingView(to: true))
        vm.suspendTeachingActivity(); vm.resumeTeachingActivity()
        await Task.yield()
        XCTAssertFalse(vm.shouldShowReference)
        XCTAssertNil(vm.referenceTrajectory)
        XCTAssertNil(vm.scene.rootNode.childNode(withName: "kick.reference", recursively: true))
        func aim(_ target: TrainingBankPoint) throws {
            let current = try XCTUnwrap(vm.record?.draftDirection)
            // The project rotatedY helper defines positive XZ angles towards +Z.
            vm.nudgeAim((atan2(target.z, target.x)-atan2(current.z, current.x)) * 180 / .pi)
        }
        let source = prepared.question.source
        let direct = source.target.vector - source.cue.vector
        try aim(.init(direct * (1 / hypot(direct.x, direct.z))))
        let quota = limiter.remainingToday
        vm.strike()
        XCTAssertEqual(vm.phase, .aiming)
        XCTAssertEqual(vm.notice?.text, "请先碰库，再碰目标球")
        XCTAssertEqual(vm.record?.attempts.count, 0)
        XCTAssertNil(vm.record?.latestShot)
        XCTAssertEqual(limiter.remainingToday, quota)
        let firstNotice = vm.notice?.id
        vm.strike()
        XCTAssertNotEqual(vm.notice?.id, firstNotice)
        try aim(prepared.question.initialDirection)
        let originalDirection = vm.record?.draftDirection, originalInput = vm.input
        let originalCue = try XCTUnwrap(vm.scene.cueBallNode?.position)
        vm.prepareGeometryReference(); vm.geometryReference.select(2)
        let handle = vm.geometryReference.handle
        vm.dragBegan(node: handle)
        vm.dragMoved(node: handle, worldPosition: .init(-1.0, vm.scene.surfaceY, 0.5))
        vm.dragEnded(node: handle)
        XCTAssertNotEqual(vm.geometryReference.draft.first, vm.geometryReference.draft.context?.defaultFirst)
        XCTAssertEqual(vm.record?.draftDirection, originalDirection); XCTAssertEqual(vm.input, originalInput)
        XCTAssertEqual(vm.scene.cueBallNode?.position.x, originalCue.x)
        XCTAssertEqual(vm.scene.cueBallNode?.position.z, originalCue.z)
        try aim(source.direction)
        XCTAssertEqual(vm.record?.draftDirection.x ?? 0, source.direction.x, accuracy: 0.00001)
        XCTAssertEqual(vm.record?.draftDirection.z ?? 0, source.direction.z, accuracy: 0.00001)
        vm.setSpin(Double(source.input.spinX), Double(source.input.spinY)); vm.velocity = Double(source.input.velocity)
        repository.rejectSubmittedRecord = true
        vm.strike()
        for _ in 0..<200 where vm.phase == .preparing { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertEqual(vm.phase, .aiming)
        XCTAssertFalse(vm.shouldShowReference)
        XCTAssertEqual(vm.record?.attempts.count, 0)
        XCTAssertNil(vm.referenceTrajectory, "A rejected save must not reveal a kick prediction")
        repository.rejectSubmittedRecord = false
        vm.strike()
        for _ in 0..<600 where vm.phase == .preparing || vm.phase == .playing { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertEqual(vm.phase, .result, vm.message ?? "No completed result")
        XCTAssertNil(vm.record?.latestShot?.failure)
        XCTAssertEqual(vm.record?.successCount, 1); XCTAssertEqual(vm.record?.attempts.count, 1)
        XCTAssertFalse(vm.shouldShowReference)
        XCTAssertNil(vm.referenceTrajectory)
        vm.retry()
        XCTAssertNotNil(vm.scene.rootNode.childNode(withName: "kick.actual", recursively: true))
        XCTAssertNil(vm.scene.rootNode.childNode(withName: "kick.reference", recursively: true))
        XCTAssertNil(vm.scene.rootNode.childNode(withName: "kick.objectActual", recursively: true))
        let previousShot = vm.record?.latestShot?.id
        let delta = source.target.vector - source.cue.vector
        try aim(.init(delta * (1 / hypot(delta.x, delta.z))))
        vm.setSpin(0, 0); vm.velocity = 2; vm.strike()
        XCTAssertEqual(vm.phase, .aiming)
        XCTAssertEqual(vm.notice?.text, "请先碰库，再碰目标球")
        XCTAssertEqual(vm.record?.latestShot?.id, previousShot)
        XCTAssertEqual(vm.record?.successCount, 1); XCTAssertEqual(vm.record?.attempts.count, 1)
    }
    @MainActor func testRepositoryHistoryAndAtomicOwnerRollback() throws {
        let suite = "KickRepositoryTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let owner = CurrentOwnerContext(defaults: defaults)
        let context = ModelContext(ModelContainerFactory.makeInMemoryContainer())
        let repository = LocalKickPracticeRepository(context: context, owner: owner, enqueue: { _, _ in })
        let prepared = try KickQuestionPreparer.prepare(.init(), seed: 31)
        var record = KickPracticeRecord(ownerKey: owner.ownerKey, is3D: false, configuration: .init(), prepared: prepared)
        record.accept(try syntheticShot(prepared.question, success: true)); try repository.save(record)
        var changed = record; changed.activeSeconds = 120
        var invalid = record.continuation(prepared: prepared); invalid.ownerKey = "different"
        XCTAssertThrowsError(try repository.saveAtomically([changed, invalid]))
        XCTAssertEqual(try repository.resumable(is3D: true)?.activeSeconds, 0)
        let sessions = try context.fetch(FetchDescriptor<TrainingSession>())
        XCTAssertEqual(HistoryViewModel.assembleKickSessions(sessions: sessions).records.count, 1)
        sessions[0].sourcePayloadSnapshot = Data("broken".utf8)
        XCTAssertThrowsError(try repository.resumable(is3D: false))
        XCTAssertEqual(HistoryViewModel.assembleKickSessions(sessions: sessions).unreadableCount, 1)
    }
    @MainActor func testOwnerTransferRollsBackCompressedPayloadAndRemapsOnSuccess() throws {
        let suite = "KickTransferTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let owner = CurrentOwnerContext(defaults: defaults)
        let context = ModelContext(ModelContainerFactory.makeInMemoryContainer())
        let repo = LocalKickPracticeRepository(context: context, owner: owner, enqueue: { _, _ in })
        let prepared = try KickQuestionPreparer.prepare(.init(), seed: 31)
        var record = KickPracticeRecord(ownerKey: owner.ownerKey, is3D: false, configuration: .init(), prepared: prepared)
        record.accept(try syntheticShot(prepared.question, success: true)); try repo.save(record)
        let source = owner.ownerKey, destination = OwnerKey.account("kick-transfer")
        enum SaveFailure: Error { case rejected }
        XCTAssertThrowsError(try OwnerTransferService(context: context, saveAction: { _ in throw SaveFailure.rejected })
            .transfer(from: source, to: destination))
        XCTAssertEqual(try repo.resumable(is3D: true)?.ownerKey, source)
        XCTAssertEqual(try OwnerTransferService(context: context).transfer(from: source, to: destination).sessions, 1)
        owner.useAccount(userID: "kick-transfer")
        XCTAssertEqual(try repo.resumable(is3D: true)?.ownerKey, destination)
        XCTAssertEqual(try repo.resumable(is3D: false)?.successCount, 1)
    }
    func testOwnPreferenceLayoutAndQuotaIdentity() {
        XCTAssertEqual(TrainingProject.from(route: "kickPractice3D"), .kick)
        XCTAssertEqual(TablePreferencePage.kickPractice2D.trainingProject, .kick)
        XCTAssertTrue(FreeControlCatalog.ids(page: .kickPractice2D, mode: .twoD).contains("shot.aim"))
        XCTAssertFalse(FreeControlCatalog.ids(page: .kickPractice2D, mode: .threeD).contains("shot.aim"))
        XCTAssertNotEqual(TrainingProject.kick.page2D, TrainingProject.kBall.page2D)
    }
    func testColorSettingsLegacyDecodeAndBankRemainsUnfiltered() throws {
        let old = Data(#"{"railCount":null,"freePractice":false,"playsStroke":true}"#.utf8)
        var config = try JSONDecoder().decode(KickConfiguration.self, from: old)
        XCTAssertTrue(config.showsRailColors)
        config.showsRailColors = false
        XCTAssertFalse(try JSONDecoder().decode(KickConfiguration.self, from: JSONEncoder().encode(config)).showsRailColors)
        let bank = try KickBankStore.load()
        let referenceWithoutLaterRail = "C68-A120-V2.5-S0-N1-P0"
        let selected = try KickQuestionPreparer.prepare(config,
            excluding: Set(bank.questions.map(\.id)).subtracting([referenceWithoutLaterRail]))
        XCTAssertEqual(selected.question.contentID, referenceWithoutLaterRail)
        XCTAssertEqual(selected.question.railSegments?.count, 1)
        var oldRecord = KickPracticeRecord(ownerKey: "test", is3D: false, configuration: config, prepared: selected)
        oldRecord.judgementVersion = 1
        XCTAssertTrue(oldRecord.isCompatible)
        XCTAssertFalse(oldRecord.canResumeCurrentTraining)
    }
    func testRealNoPostContactRailFailsAndRetryPreservesFirstAnswer() throws {
        let bank = try KickBankStore.load()
        let referenceID = "C68-A120-V2.5-S0-N1-P0"
        let prepared = try KickQuestionPreparer.prepare(.init(),
            excluding: Set(bank.questions.map(\.id)).subtracting([referenceID]))
        let q = prepared.question
        let prediction = try KickQuestionPreparer.solve(question: q, input: q.source.input,
            direction: q.source.direction.vector, surfaceY: BTTablePhysics.surfaceY,
            profile: AccuracyTipSelector.renderedProfile())
        let contact = try XCTUnwrap(prediction.events.first(where: {
            if case .ballBall = $0.kind { return true }; return false
        }))
        XCTAssertFalse(prediction.events.contains {
            if case .ballCushion = $0.kind { return $0.time > contact.time }; return false
        })
        XCTAssertEqual(PracticeRailColors.beforeTarget(prediction.events), q.railSegments)
        let failed = try KickShot(question: q, input: q.source.input, prediction: prediction,
            surfaceY: BTTablePhysics.surfaceY)
        XCTAssertThrowsError(try q.demonstrationShot(surfaceY: BTTablePhysics.surfaceY))
        XCTAssertEqual(failed.failure, .noRailAfterContact)
        XCTAssertEqual(failed.resultText, "犯规：碰球后无球碰库 · 失败")
        var record = KickPracticeRecord(ownerKey: "post-contact", is3D: false,
            configuration: .init(), prepared: prepared)
        record.accept(failed)
        XCTAssertEqual(record.successCount, 0)
        XCTAssertEqual(record.attempts.first?.failure, .noRailAfterContact)
        let retry = try syntheticShot(q, success: true)
        XCTAssertNil(retry.failure)
        record.accept(retry)
        let restored = try KickPracticeRecord.decodePayload(record.encodedPayload())
        XCTAssertEqual(restored.attempts.count, 1)
        XCTAssertEqual(restored.successCount, 0)
        XCTAssertEqual(restored.attempts.first?.failure, .noRailAfterContact)
        XCTAssertEqual(restored.latestShot?.id, retry.id)
        XCTAssertTrue(restored.canResumeCurrentTraining)
    }
    func testSixSegmentIdentityRejectsOppositeHalfOfSameWall() {
        let hit = self.hit
        let first = ShotEvent(time: 0, kind: .ballCushion(ball: cue), cushionIndex: 0)
        let good = [first, hit, rail(.right, time: 6)]
        XCTAssertNil(KickJudgement.failure(events: good, complete: true, walls: [.bottom], segments: [0]))
        XCTAssertEqual(KickJudgement.failure(events: good, complete: true, walls: [.bottom], segments: [1]), .rail)
    }
    @MainActor func testPracticeStripUsesInstalledSightInnerTangents() throws {
        let scene = AngleTrainingScene(); scene.setupScene()
        let table = try XCTUnwrap(scene.tableNode)
        let edges = PracticeRailColors.innerSightEdges(in: table, surfaceY: scene.surfaceY)
        XCTAssertEqual(edges.count, 6)
        let rails = TableGeometry.chineseEightBallCushions(y: 0).linear
        for id in 0..<6 {
            let edge = try XCTUnwrap(edges[id])
            let mid = (rails[id].start + rails[id].end) * 0.5
            let nose = abs(rails[id].normal.x) > 0.9 ? abs(mid.x) : abs(mid.z)
            XCTAssertGreaterThan(edge, nose + 0.02)
            XCTAssertLessThan(edge, nose + 0.15)
        }
        scene.setPracticeRailColors(true, segments: [5, 0])
        scene.applyTableStyle(.charcoal, showsSights: false)
        XCTAssertEqual(PracticeRailColors.innerSightEdges(in: table, surfaceY: scene.surfaceY), edges)
        scene.setPracticeRailColors(false)
    }
    @MainActor func testRailTintLeavesClothAndSightsIntactAndRestoresWood() throws {
        let table = SCNNode()
        let mesh = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
        let wood = SCNMaterial(); wood.name = "Wood"; wood.shaderModifiers = [.surface: "#pragma body\n_surface.roughness = 0.7;"]
        let cloth = SCNMaterial(); cloth.name = "TaiNi"
        let sight = SCNMaterial(); sight.name = "White"
        mesh.materials = [wood, cloth, sight]; table.geometry = mesh
        PracticeRailColors.apply(to: table, enabled: true, segments: [2, 5], surfaceY: 0.5)
        XCTAssertTrue(mesh.materials[0].shaderModifiers?[.surface]?.contains("practiceRailTintBegin") == true)
        XCTAssertTrue(mesh.materials[1] === cloth); XCTAssertTrue(mesh.materials[2] === sight)
        PracticeRailColors.apply(to: table, enabled: false, surfaceY: 0.5)
        XCTAssertFalse(mesh.materials[0].shaderModifiers?[.surface]?.contains("practiceRailTintBegin") == true)
        XCTAssertTrue(mesh.materials[0].shaderModifiers?[.surface]?.contains("_surface.roughness = 0.7;") == true)
        XCTAssertNil(wood.shaderModifiers?[.surface]?.range(of: "practiceRailTintBegin"))
    }
    @MainActor func testKickMeasurementStartsAtCueAndRestoresDraft() throws {
        let scene = AngleTrainingScene()
        let tool = GeometricReferenceTool(scene: scene)
        let cue = SCNVector3(0, 0.5, 0.2), direction = SCNVector3(1, 0, 0)
        tool.updateForKick(identity: "kick", cue: cue, direction: direction); tool.select(2)
        XCTAssertEqual(tool.points.first, GeometricRailReference.point(cue))
        XCTAssertEqual(tool.draft.context?.allowedRails.count, 6)
        let first = try XCTUnwrap(tool.draft.first)
        tool.freeze(); tool.complete(); tool.restore()
        XCTAssertEqual(tool.draft.first, first)
        tool.nextShot(); XCTAssertFalse(tool.visible); XCTAssertEqual(tool.draft.reflections, 0)
    }
    private func syntheticShot(_ question: KickQuestion, success: Bool) throws -> KickShot {
        var prediction = ShotPrediction()
        prediction.termination = .settled; prediction.recorder = TrajectoryRecorder()
        prediction.strikeDirection = question.source.direction.vector
        prediction.finalPositions = [cue: question.board.cue.vector]
        prediction.events = (success ? (question.railSegments ?? question.source.walls.map { wall in (0..<6).first { KickWall.from(cushion: $0) == wall }! }).map {
            ShotEvent(time: 0, kind: .ballCushion(ball: cue), cushionIndex: $0)
        } : []) + [hit, rail(.right, time: 6)]
        return try .init(question: question, input: .init(), prediction: prediction, surfaceY: BTTablePhysics.surfaceY)
    }
}

@MainActor private final class MemoryKickRepository: KickPracticeRepository {
    var ownerKey = "test"
    var records: [UUID: KickPracticeRecord] = [:]
    var rejectSubmittedRecord = false
    func save(_ record: KickPracticeRecord) throws {
        if rejectSubmittedRecord, record.latestShot != nil { throw LocalKickPracticeRepository.Failure.oversizedRecord }
        records[record.id] = record
    }
    func saveAtomically(_ records: [KickPracticeRecord]) throws { for record in records { try save(record) } }
    func resumable(is3D: Bool) throws -> KickPracticeRecord? { records.values.first { $0.status == .active } }
}
