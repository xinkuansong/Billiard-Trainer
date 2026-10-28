import XCTest
import SwiftData
import SceneKit
@testable import QiuJi

@MainActor
final class AccuracyPracticeRecordTests: XCTestCase {
    private func record(owner: String = "guest:test") throws -> AccuracyPracticeRecord {
        var generator = SceneTrainingGenerator(seed: 20261021)
        let questions = try generator.batch(.init()).prefix(15).enumerated().map { index, question in
            let board = TrainingBankBoard(question: question, seed: UInt64(index))
            return AccuracyPracticeQuestion(board: board,
                variant: .init(boardID: board.id, proofID: "record-fixture", tip: .center))
        }
        return try .init(ownerKey: owner, is3D: false, configuration: .init(), bankFingerprint: "fixture", questions: questions)
    }
    private func success(pocket: Int) -> AccuracyPracticeAttempt.Result {
        var shot = ShotPrediction(); shot.termination = .settled
        shot.events = [
            .init(time: 1, kind: .ballBall(ballA: ShotInput.cueBallName, ballB: ShotInput.targetBallName)),
            .init(time: 2, kind: .pocket(ball: ShotInput.targetBallName, pocketId: "pocket_\(pocket)"))
        ]
        return .init(prediction: shot, pocketIndex: pocket)
    }
    func testFreezeAndCompletionAreIdempotentAcrossEncodingAndLastQuestion() throws {
        var run = try record()
        for index in 0..<15 {
            XCTAssertEqual(run.cursor, index)
            let frozen = try run.freezeAttempt()
            XCTAssertEqual(try run.freezeAttempt().id, frozen.id)
            let data = try JSONEncoder().encode(run)
            run = try JSONDecoder().decode(AccuracyPracticeRecord.self, from: data)
            XCTAssertEqual(try run.freezeAttempt().id, frozen.id)
            let result = success(pocket: try XCTUnwrap(run.current).board.pocketIndex)
            XCTAssertTrue(run.accept(result, attemptID: frozen.id))
            XCTAssertFalse(run.accept(result, attemptID: frozen.id))
            XCTAssertEqual(run.status, .active, "Even the last question presents its result before the summary")
            try run.advance()
        }
        XCTAssertEqual(run.validAttempts.count, 15)
        XCTAssertEqual(run.successCount, 15)
        XCTAssertEqual(run.status, .completed)
    }
    func testTechnicalFailureDoesNotCountOrReplaceFrozenInput() throws {
        var run = try record()
        let attempt = try run.freezeAttempt()
        let failure = AccuracyPracticeAttempt.Result(prediction: ShotPrediction(), pocketIndex: 0)
        XCTAssertTrue(run.accept(failure, attemptID: attempt.id))
        XCTAssertEqual(run.validAttempts.count, 0)
        XCTAssertThrowsError(try run.advance())
        run.draftVelocity = 6
        XCTAssertEqual(try run.freezeAttempt().velocity, attempt.velocity)
        XCTAssertEqual(try run.freezeAttempt().id, attempt.id)
    }
    func testRepositoryAcceptsManualTipAndRejectsChangesToLockedAxes() throws {
        let suite = "accuracy-spin-repository-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let owner = CurrentOwnerContext(defaults: defaults)
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let repo = LocalAccuracyPracticeRepository(context: context, owner: owner, enqueue: { _, _ in })
        let template = try record(owner: owner.ownerKey)
        for vertical in [false, true] {
            for side in [false, true] {
                var configuration = SceneTrainingConfiguration()
                configuration.allowsManualVerticalSpin = vertical
                configuration.allowsManualSideSpin = side
                var questions = template.questions
                questions[0].exactTip = .init(x: 0.1, y: 0.2)
                var run = try AccuracyPracticeRecord(ownerKey: owner.ownerKey, is3D: false,
                    configuration: configuration, bankFingerprint: "fixture", questions: questions)
                run.draftTip = run.constrainedTip(x: -0.15, y: -0.1)
                let frozen = try run.freezeAttempt()
                try repo.save(run)
                XCTAssertEqual(try repo.resumable(is3D: false)?.currentAttempt?.fixedTip, frozen.fixedTip)
                if !side || !vertical {
                    let x = side ? frozen.fixedTip.x : frozen.fixedTip.x + 0.05
                    let y = vertical ? frozen.fixedTip.y : frozen.fixedTip.y + 0.05
                    run.attempts[0].exactTip = .init(x: x, y: y)
                    XCTAssertThrowsError(try repo.save(run))
                }
                run.attempts[0].exactTip = .init(x: 1, y: 1)
                XCTAssertThrowsError(try repo.save(run))
            }
        }
        withExtendedLifetime(container) {}
    }

    func testRepositoryPreservesOwnerAndTransportWithoutTrainingAggregates() throws {
        let suite = "accuracy-record-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let owner = CurrentOwnerContext(defaults: defaults)
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        var uploads = 0
        let repo = LocalAccuracyPracticeRepository(context: context, owner: owner, enqueue: { _, _ in uploads += 1 })
        var run = try record(owner: owner.ownerKey)
        try repo.save(run)
        XCTAssertEqual(uploads, 0, "Untouched drafts stay local")
        XCTAssertTrue(HistoryViewModel.assembleAccuracySessions(
            sessions: try context.fetch(FetchDescriptor<TrainingSession>())).records.isEmpty)
        let attempt = try run.freezeAttempt()
        _ = run.accept(success(pocket: try XCTUnwrap(run.current).board.pocketIndex), attemptID: attempt.id)
        try repo.save(run); try repo.save(run)
        let saved = try context.fetch(FetchDescriptor<TrainingSession>())
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(try repo.resumable(is3D: false)?.attempts.count, 1)
        XCTAssertFalse(TrainingSessionKind.countsTowardGoal(saved[0].kind))
        XCTAssertFalse(TrainingSessionKind.countsTowardAccuracy(saved[0].kind))
        let dto = TrainingSessionDTO(from: saved[0])
        let decoded = try JSONDecoder().decode(TrainingSessionDTO.self, from: JSONEncoder().encode(dto))
        XCTAssertEqual(decoded.kind, LocalAccuracyPracticeRepository.kind)
        XCTAssertEqual(decoded.sourcePayloadSnapshot, saved[0].sourcePayloadSnapshot)
        let history = HistoryViewModel.assembleAccuracySessions(sessions: saved)
        XCTAssertEqual(history.records.count, 1)
        XCTAssertEqual(history.records[0].successCount, 1)
        XCTAssertEqual(history.unreadableCount, 0)
        saved[0].sourcePayloadSnapshot = Data("invalid".utf8)
        XCTAssertEqual(HistoryViewModel.assembleAccuracySessions(sessions: saved).unreadableCount, 1)
        owner.useAccount(userID: "another")
        XCTAssertNil(try repo.resumable(is3D: false))
        XCTAssertThrowsError(try repo.save(run))
        XCTAssertEqual(try context.fetch(FetchDescriptor<TrainingSession>()).count, 1)
    }

    func testAllowanceRestorationIsIdempotentAndDoesNotChargeNextDay() throws {
        let suite = "accuracy-quota-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var now = Date(timeIntervalSince1970: 1_790_000_000)
        let submitted = now, id = UUID()
        let limiter = AngleUsageLimiter(defaults: defaults, now: { now })
        limiter.recordQuestion(attemptID: id, submittedAt: submitted)
        limiter.recordQuestion(attemptID: id, submittedAt: submitted)
        XCTAssertEqual(limiter.questionsUsedToday, 1)
        let restored = AngleUsageLimiter(defaults: defaults, now: { now })
        restored.recordQuestion(attemptID: id, submittedAt: submitted)
        XCTAssertEqual(restored.questionsUsedToday, 1)
        now = now.addingTimeInterval(86400)
        restored.recordQuestion(attemptID: id, submittedAt: submitted)
        XCTAssertEqual(restored.questionsUsedToday, 0)
        restored.recordQuestion(attemptID: UUID(), submittedAt: now)
        XCTAssertEqual(restored.questionsUsedToday, 1)
    }
    func testFrozenDiagnosticWhenRequested() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let request = root.appendingPathComponent("output/accuracy-practice-20261020/frozen-diagnostic-request")
        guard FileManager.default.fileExists(atPath: request.path) else { throw XCTSkip("Explicit diagnostic request required") }
        try FileManager.default.removeItem(at: request)
        var generator = SceneTrainingGenerator(seed: 20261023)
        for index in 0..<6 {
            guard let q = generator.question(angle: 40, side: index % 2 == 0 ? 1 : -1, pocket: index % 4,
                cueBand: .short, pocketBand: .short, railSelection: [.frozen], allowsTargetJawContact: true) else { continue }
            let board = TrainingBankBoard(question: q, seed: UInt64(index))
            for speed: Float in [0.4, 0.6, 0.8, 1, 1.2, 1.5, 1.8, 2, 2.5, 3.5] {
                let input = ShotInput(cueBall: board.cue.vector, targetBall: board.target.vector,
                    pocketIndex: board.pocketIndex, velocity: speed, spinX: 0, spinY: 0, surfaceY: 0)
                let candidate = ShotPredictor.predictForPositionSolve(input, includePresentation: false)
                guard candidate.feasible else { continue }
                var outcomes: [String: Int] = [:]
                for offset: Float in [-0.1, -0.05, 0, 0.05, 0.1] {
                    let shot = ShotPredictor.simulateFree(cueBall: board.cue.vector,
                        aimDir: candidate.aimDirection.rotatedY(offset * .pi / 180), velocity: speed,
                        spinX: 0, spinY: 0, surfaceY: 0,
                        balls: [.init(name: ShotInput.targetBallName, position: board.target.vector)])
                    outcomes[AccuracyShotJudgement.evaluate(shot, pocketIndex: board.pocketIndex).rawValue, default: 0] += 1
                    if offset == 0 {
                        print("FROZEN_TRACE board=\(index) speed=\(speed) outcome=\(AccuracyShotJudgement.evaluate(shot, pocketIndex: board.pocketIndex)) cue=\(board.cue) target=\(board.target)")
                        for event in shot.events {
                            if let railID = event.cushionIndex, railID < 6,
                               case .ballCushion(let name) = event.kind, name == ShotInput.targetBallName {
                                let rail = TableGeometry.chineseEightBallQiuJi(surfaceY: 0).linearCushions[railID]
                                let frames = shot.recorder?.framesByBallName[name] ?? []
                                let gap = frames.filter { $0.time <= event.time }.map { ($0.position - rail.start).dot(rail.normal) - BallPhysics.radius }.max() ?? -1
                                print("FROZEN_RAIL t=\(event.time) rail=\(railID) maxDeparture=\(gap)")
                            }
                        }
                    }
                }
                print("FROZEN_OUTCOMES board=\(index) speed=\(speed) values=\(outcomes)")
            }
        }
    }

}
