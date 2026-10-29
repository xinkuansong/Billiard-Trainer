import XCTest
import SceneKit
import SwiftData
@testable import QiuJi

@MainActor
final class TwoBallPracticeTests: XCTestCase {
    func testFirstShotReferenceStaysHiddenAfterRouteChangeAndRestore() throws {
        let prepared = try fixture()
        let suite = "two-reference-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let limiter = AngleUsageLimiter(defaults: defaults, namespace: suite); limiter.isPremium = true
        let repo = MemoryRepository()
        var record = TwoBallPracticeRecord(ownerKey: repo.ownerKey, is3D: false,
            configuration: .init(), mode: .trajectory, prepared: prepared)
        repo.saved = record
        let before = TwoBallPracticeViewModel(is3D: false, limiter: limiter, defaults: defaults)
        before.attach(repository: repo)
        XCTAssertTrue(before.shouldShowReference)
        before.suspendTeachingActivity()
        record.accept(try realShot(prepared.question))
        record.advanceRoute()
        repo.saved = record
        let restored = TwoBallPracticeViewModel(is3D: false, limiter: limiter, defaults: defaults)
        defer { restored.suspendTeachingActivity() }
        restored.attach(repository: repo); restored.setShowsReference(true)
        XCTAssertNotNil(restored.record)
        XCTAssertFalse(restored.shouldShowReference, "A new route and legacy retention preference cannot restore a baseline after the first accepted stroke")
    }

    func testResumedFreeModePrefetchIgnoresLegacyReferenceSpinFilters() async throws {
        let prepared = try fixture()
        let suite = "two-ball-free-prefetch-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let limiter = AngleUsageLimiter(defaults: defaults, namespace: suite)
        limiter.isPremium = true
        let repository = MemoryRepository()
        var configuration = SceneTrainingConfiguration.defaults(for: "twoBallPractice2D")
        configuration.allowsVerticalSpin = false; configuration.allowsSideSpin = false
        repository.saved = .init(ownerKey: repository.ownerKey, is3D: false,
            configuration: configuration, mode: .free, prepared: prepared)
        let received = expectation(description: "Resumed free session requests an unrestricted reference route pool")
        let vm = TwoBallPracticeViewModel(is3D: false, limiter: limiter, defaults: defaults,
            prepareQuestion: { next, excluded in
                XCTAssertTrue(next.allowsVerticalSpin)
                XCTAssertTrue(next.allowsSideSpin)
                XCTAssertEqual(next.angleSelection, [.straight, .small, .medium])
                XCTAssertTrue(excluded.contains(prepared.question.contentID))
                received.fulfill()
                throw CancellationError()
            })
        defer { vm.suspendTeachingActivity() }
        vm.attach(repository: repository); vm.setupScene()
        await fulfillment(of: [received], timeout: 15)
        XCTAssertEqual(vm.record?.configuration, configuration, "Do not rewrite the frozen historical configuration")
    }

    func testImpossibleStopFeedbackLeavesTrajectoryAndLegacyScoresIntact() throws {
        let q = try fixture().question
        let original = try realShot(q)
        // Replay snapshots omit collision events; use the solver's complete event stream.
        var prediction = try TwoBallQuestionPreparer.solve(board: q.board, second: q.second,
            input: q.route.source.input, surfaceY: BTTablePhysics.surfaceY,
            profile: AccuracyTipSelector.renderedProfile(), direction: q.route.source.direction)
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: q.second.vector,
            pocketIndex: q.secondPocket, surfaceY: BTTablePhysics.surfaceY)
        // A synthetic settled stop on the pocket side of the next ball: no forward contact.
        prediction.finalPositions[ShotInput.cueBallName] = .init(
            q.second.x + (aim.x-q.second.x)*0.4, BTTablePhysics.surfaceY + BallPhysics.radius,
            q.second.z + (aim.z-q.second.z)*0.4)
        let shot = try TwoBallShot(question: q, input: original.input, prediction: prediction, surfaceY: BTTablePhysics.surfaceY)
        XCTAssertNil(shot.failure, "The first pot still succeeded")
        XCTAssertEqual(shot.continuationUnavailable, true)
        XCTAssertEqual(shot.freeScore, 0)
        XCTAssertEqual(shot.resultText(mode: .free), "0分，无法进指定袋，请重打")
        XCTAssertEqual(shot.trajectoryScore, original.trajectoryScore)
        XCTAssertFalse(shot.resultText(mode: .trajectory).contains("请重打"))
        let decoded = try JSONDecoder().decode(TwoBallShot.self, from: JSONEncoder().encode(shot))
        XCTAssertEqual(decoded.freeScore, 0)
        var legacy = original
        legacy.continuationUnavailable = nil
        let saved = try JSONDecoder().decode(TwoBallShot.self, from: JSONEncoder().encode(legacy))
        XCTAssertNil(saved.continuationUnavailable)
        XCTAssertEqual(saved.freeScore, original.freeScore)
    }

    func testFirstShotExecutionFormula() throws {
        let score = try XCTUnwrap(TwoBallExecutionDifficulty.evaluate(velocity: 2.25, spinX: -0.2,
            spinY: -0.3, cushions: 2, lengthMeters: 1.5))
        XCTAssertEqual(score.components.stroke, 0.86, accuracy: 1e-12)
        XCTAssertEqual(score.components.power, 0.2, accuracy: 1e-12)
        XCTAssertEqual(score.components.route, 0.33, accuracy: 1e-12)
        XCTAssertEqual(score.components.interaction, 0.12, accuracy: 1e-12)
        XCTAssertEqual(score.effort, 1.51, accuracy: 1e-12)
        XCTAssertEqual(score.difficulty, 151/2.51, accuracy: 1e-12)
        XCTAssertNil(TwoBallExecutionDifficulty.evaluate(velocity: .nan, spinX: 0, spinY: 0, cushions: 0, lengthMeters: 1))
    }

    func testParameterConsumerRejectsMalformedReferencesAndParameters() throws {
        let bank = try TwoBallBankStore.load()
        let name = bank.index.shards[0].name
        let url = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "jsonl.gz", subdirectory: "TwoBallBank"))
        let raw = try XCTUnwrap(TwoBallBankStore.gunzip(Data(contentsOf: url)).split(separator: 10).first)
        let original = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw)) as? [String: Any])
        func validate(_ value: [String: Any]) throws {
            try TwoBallBankStore.validate(JSONDecoder().decode(TwoBallLayout.self, from: JSONSerialization.data(withJSONObject: value)))
        }
        try validate(original)
        for pair in [[], [1], [Int.max,0], [0,6]] {
            var bad = original, qs = original["questions"] as! [[String: Any]]
            qs[0]["refs"] = [pair]; bad["questions"] = qs
            XCTAssertThrowsError(try validate(bad))
        }
        for (key, value) in [("v", -1.0 as Any), ("dir", [0,0] as Any), ("rails", [99] as Any), ("sx", 1.0 as Any)] {
            var bad = original, rs = original["routes"] as! [[String: Any]]
            rs[0][key] = value; bad["routes"] = rs
            XCTAssertThrowsError(try validate(bad))
        }
        var gzip = try Data(contentsOf: url); gzip.append(0)
        XCTAssertThrowsError(try TwoBallBankStore.gunzip(gzip))
    }

    func testLegacyRecordRemainsReadableButCannotResumeOldBank() throws {
        let record = TwoBallPracticeRecord(ownerKey: "test", is3D: false, configuration: .init(),
                                           mode: .trajectory, prepared: try fixture())
        XCTAssertTrue(record.canResumeCurrentTraining)
        var raw = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? [String: Any])
        raw.removeValue(forKey: "trainingBankPolicyVersion")
        let legacy = try JSONDecoder().decode(TwoBallPracticeRecord.self, from: JSONSerialization.data(withJSONObject: raw))
        XCTAssertTrue(legacy.isCompatible)
        XCTAssertFalse(legacy.canResumeCurrentTraining)
        XCTAssertNoThrow(try TwoBallPracticeRecord.decodePayload(legacy.encodedPayload()))
    }
    func testBankAndSourceDifficulty() throws {
        let bank = try TwoBallBankStore.load()
        XCTAssertEqual(bank.index.layouts.count, 13358)
        XCTAssertEqual(bank.index.shards.count, 1357)
        XCTAssertEqual(bank.index.counts.questions, 166443)
        XCTAssertEqual(bank.index.counts.recommendations, 677488)
        XCTAssertEqual(bank.index.policyVersion, TwoBallBankStore.policyVersion)
        let row = try bank.layout(bank.index.layouts[0])
        try TwoBallBankStore.validate(row)
        XCTAssertFalse(row.questions.isEmpty)
        XCTAssertEqual(try bank.board(for: row).id, row.id)
        XCTAssertThrowsError(try TwoBallBankStore.gunzip(Data([0,1,2,3])))
    }
    func testDifficultyBoundaries() throws {
        let g = TwoBallDifficultyMetric.Geometry.source
        let p = try XCTUnwrap(g.anchor(4))
        let ball = (0.0,0.0)
        XCTAssertNil(TwoBallDifficultyMetric.evaluate(cue:ball,ball:ball,pocket:4))
        XCTAssertNil(TwoBallDifficultyMetric.evaluate(cue:(0,-0.4),ball:ball,pocket:4))
        for a in [0.0,25,26,80,89.9] {
            let theta = a * .pi / 180
            let cue = (sin(theta)*0.5,2*g.radius+cos(theta)*0.5)
            let d = try XCTUnwrap(TwoBallDifficultyMetric.evaluate(cue:cue,ball:ball,pocket:4))
            XCTAssertEqual(d.angle,a,accuracy:1e-8)
            XCTAssertEqual(d.value,abs(p.1)/cos(theta),accuracy:1e-7)
        }
    }
    func fixture() throws -> TwoBallQuestionPreparer.Prepared {
        var c = SceneTrainingConfiguration(); c.allowsVerticalSpin = true; c.allowsSideSpin = true
        return try TwoBallQuestionPreparer.prepare(c,seed:20261025)
    }
    func testThreeBallSourceReplayAndFrozenRecord() throws {
        let prepared = try fixture(), q = prepared.question
        XCTAssertFalse(q.routes.isEmpty)
        for (i,route) in q.routes.enumerated() {
            XCTAssertTrue(route.recommendation.comfort?.isQualified == true)
            XCTAssertTrue(route.source.executionDifficulty?.matches(route.source) == true)
            if i > 0 {
                XCTAssertLessThanOrEqual(q.routes[i-1].source.executionDifficulty!.effort, route.source.executionDifficulty!.effort)
            }
            var current = q; current.routeIndex = i
            let prediction = try TwoBallQuestionPreparer.solve(board:q.board,second:q.second,input:route.source.input,
                surfaceY:BTTablePhysics.surfaceY,profile:AccuracyTipSelector.renderedProfile(),direction:route.source.direction)
            XCTAssertNil(TwoBallQuestionPreparer.failure(prediction,pocket:q.board.pocketIndex))
            XCTAssertNil(route.replayRMSCM)
            let replay = try XCTUnwrap(SeparationTrajectoryScore.evaluate(target: route.source.trajectory2mm.trajectory, actual: SeparationTrajectory.extract(prediction)))
            XCTAssertLessThanOrEqual(try XCTUnwrap(replay.rmsDistanceCM), TwoBallQuestionPreparer.maximumReplayRMSCM)
            let shot = try TwoBallShot(question:current,input:route.source.input,prediction:prediction,surfaceY:BTTablePhysics.surfaceY)
            XCTAssertEqual(Set(shot.frames.keys),Set(["cueBall","object","second"]))
            XCTAssertNotNil(shot.difficulty)
            let restored = try JSONDecoder().decode(TwoBallShot.self,from:JSONEncoder().encode(shot))
            XCTAssertEqual(restored.prediction().duration,prediction.duration)
            XCTAssertEqual(restored.finalPositions["second"]?.x, q.second.x)
            print("TWO_BALL_REPLAY",q.contentID,route.source.comboIndex,route.replayRMSCM,shot.difficulty!.value)
        }
    }
    func testTrajectorySkippingAndFreeDefault() throws {
        let prepared = try fixture()
        var record = TwoBallPracticeRecord(ownerKey:"guest:test",is3D:false,configuration:.init(),mode:.trajectory,prepared:prepared)
        XCTAssertFalse(record.shouldSkip, "The first route accepts the default shot")
        record.skip(); XCTAssertTrue(record.attempts.isEmpty)
        record.accept(try realShot(prepared.question))
        let count = record.current!.routes.count
        for i in 1..<count {
            record.advanceRoute(); XCTAssertTrue(record.shouldSkip)
            record.draftInput.velocity += 0.01; XCTAssertFalse(record.shouldSkip)
            record.draftInput = .init(); XCTAssertTrue(record.shouldSkip)
            record.retryOverride = true; XCTAssertFalse(record.shouldSkip); record.retryOverride = false
            record.skip(); XCTAssertEqual(record.consumed.count,1)
            XCTAssertEqual(record.current?.routeIndex,i)
        }
        XCTAssertFalse(record.hasNextRoute)
        XCTAssertEqual(record.skippedRoutes,count-1); XCTAssertEqual(record.totalAttemptCount,1)
        let recovered = try TwoBallPracticeRecord.decodePayload(record.encodedPayload())
        XCTAssertEqual(recovered.skippedRoutes,count-1)
        let free = TwoBallPracticeRecord(ownerKey:"guest:test",is3D:true,configuration:.init(),mode:.free,prepared:prepared)
        XCTAssertFalse(free.shouldSkip); XCTAssertFalse(free.hasNextRoute)
    }
}


extension TwoBallPracticeTests {
    private func realShot(_ q: TwoBallQuestion) throws -> TwoBallShot {
        let p = try TwoBallQuestionPreparer.solve(board:q.board,second:q.second,input:q.route.source.input,
            surfaceY:BTTablePhysics.surfaceY,profile:AccuracyTipSelector.renderedProfile(),direction:q.route.source.direction)
        return try TwoBallShot(question:q,input:q.route.source.input,prediction:p,surfaceY:BTTablePhysics.surfaceY)
    }
    func testFirstScoresRetriesAndQuestionWeightedMean() throws {
        let prepared = try fixture(), q = prepared.question
        var record = TwoBallPracticeRecord(ownerKey:"test",is3D:false,configuration:.init(),mode:.trajectory,prepared:prepared)
        var first = try realShot(q), retry = try realShot(q)
        first.physical.score = .init(rmsDistanceCM:0,targetSampleCount:100,actualSampleCount:100)
        retry.physical.score = .init(rmsDistanceCM:20,targetSampleCount:100,actualSampleCount:100)
        record.accept(first);record.accept(retry);record.accept(retry)
        XCTAssertEqual(record.attempts.count,1);XCTAssertEqual(record.averageScore,100)
        XCTAssertEqual(record.retryCount,2);XCTAssertEqual(record.latestShot?.trajectoryScore,50)
        XCTAssertEqual(record.currentRouteAverage(), 75)
        XCTAssertEqual(record.currentRouteAverage(excluding: retry.id), 100)
        record.advanceRoute(); XCTAssertNil(record.currentRouteAverage()); record.skip()
        let next = TwoBallQuestion(id:UUID(),board:q.board,cellID:q.cellID,second:q.second,routes:q.routes)
        record.questions.append(next);record.cursor += 1;record.resetInput()
        var other = try realShot(next);other.physical.score = .init(rmsDistanceCM:20,targetSampleCount:100,actualSampleCount:100)
        record.accept(other)
        XCTAssertEqual(record.averageScore,75);XCTAssertEqual(record.totalAttemptCount,2)
        XCTAssertEqual(record.consumed.count,2)
        let restored = try TwoBallPracticeRecord.decodePayload(record.encodedPayload())
        XCTAssertEqual(restored.averageScore,75);XCTAssertEqual(restored.skippedRoutes,1)
        XCTAssertLessThan(try restored.encodedPayload().count,512_000)
    }
    func testRealSecondBallCollisionAndInvalidDifficulty() throws {
        let q = try fixture().question
        let a = q.board.target.vector, c = q.board.cue.vector
        // Put B between cue and A, retaining the real three-ball collision engine.
        let b = TrainingBankPoint(SCNVector3((a.x+c.x)/2,0,(a.z+c.z)/2))
        let p = try TwoBallQuestionPreparer.solve(board:q.board,second:b,input:.init(velocity:2.5),
            surfaceY:BTTablePhysics.surfaceY,profile:AccuracyTipSelector.renderedProfile(),
            direction:AccuracyTipSelector.referenceDirection(q.board))
        XCTAssertEqual(TwoBallQuestionPreparer.failure(p,pocket:q.board.pocketIndex),"碰动第二球")
        let bad = TwoBallQuestion(id:UUID(),board:q.board,cellID:999,second:b,routes:q.routes)
        let shot = try TwoBallShot(question:bad,input:.init(),prediction:p,surfaceY:BTTablePhysics.surfaceY)
        XCTAssertNil(shot.difficulty);XCTAssertEqual(shot.trajectoryScore,0)
        XCTAssertEqual(shot.freeScore, 0); XCTAssertNil(shot.comfort)
        var free = TwoBallPracticeRecord(ownerKey:"test",is3D:false,configuration:.init(),mode:.free,
            prepared:.init(fingerprint:"fixture",question:bad))
        free.accept(shot)
        XCTAssertEqual(free.totalAttemptCount,1);XCTAssertEqual(free.validCount,0);XCTAssertNil(free.averageDifficulty)
        XCTAssertEqual(free.averageScore, 0); XCTAssertEqual(free.currentRouteAverage(), 0)
        XCTAssertEqual(shot.frames.keys.count,3)
        XCTAssertNotEqual(shot.finalPositions["second"]?.x,b.x)
    }
    func testFilteredRoutesAndEmptyMalformedRows() throws {
        for (vertical,side) in [(false,false),(true,false),(false,true)] {
            var config = SceneTrainingConfiguration();config.allowsVerticalSpin=vertical;config.allowsSideSpin=side
            let prepared = try TwoBallQuestionPreparer.prepare(config,seed:20261025)
            XCTAssertFalse(prepared.question.routes.isEmpty)
            XCTAssertTrue(prepared.question.routes.allSatisfy { (vertical || $0.source.spinY == 0) && (side || $0.source.spinX == 0) })
        }
        let bank = try TwoBallBankStore.load(), row = try bank.layout(bank.index.layouts[0])
        let empty = TwoBallLayout(id:row.id,board:row.board,questions:[],routes:[])
        XCTAssertNoThrow(try TwoBallBankStore.validate(empty))
        let broken = TwoBallLayout(id:row.id,board:row.board,questions:row.questions,routes:[])
        XCTAssertThrowsError(try TwoBallBankStore.validate(broken))
        let duplicate = TwoBallLayout(id:row.id,board:row.board,questions:row.questions,routes:row.routes+row.routes)
        XCTAssertThrowsError(try TwoBallBankStore.validate(duplicate))
    }
    func testQuotaTwentyQuestionsRoutesAndDayRollover() throws {
        let suite = "two-ball-quota-"+UUID().uuidString
        let defaults = UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        var now = Date()
        let limiter = AngleUsageLimiter(defaults:defaults,now:{now},namespace:suite)
        let prepared = try fixture(), q = prepared.question
        var record = TwoBallPracticeRecord(ownerKey:"test",is3D:false,configuration:.init(),mode:.trajectory,prepared:prepared)
        for i in 0..<20 {
            if i > 0 { record.questions.append(.init(id:UUID(),board:q.board,cellID:q.cellID,second:q.second,routes:q.routes));record.cursor += 1;record.resetInput() }
            for index in q.routes.indices {
                if index == 0 { record.accept(try realShot(record.current!)) }
                else { record.skip(now:now) }
                for (id,date) in record.consumed { limiter.recordQuestion(attemptID:id,submittedAt:date) }
                record.advanceRoute()
            }
            XCTAssertEqual(limiter.questionsUsedToday,i+1)
        }
        XCTAssertTrue(limiter.isLimitReached);XCTAssertEqual(record.skippedQuestions,0)
        XCTAssertEqual(record.totalProcessed,20);XCTAssertEqual(record.totalAttemptCount,20)
        now = now.addingTimeInterval(86400);limiter.refreshDay()
        for (id,date) in record.consumed { limiter.recordQuestion(attemptID:id,submittedAt:date) }
        XCTAssertEqual(limiter.questionsUsedToday,0)
        let continuation = record.continuation(prepared:prepared)
        XCTAssertEqual(continuation.questionNumber,21);XCTAssertEqual(continuation.skippedQuestions,0)
        XCTAssertEqual(continuation.logicalSessionID,record.logicalSessionID)
        XCTAssertTrue(continuation.attempts.isEmpty)
    }
    func testRepositoryTransportHistoryAndAtomicRollback() throws {
        let suite = "two-ball-repo-"+UUID().uuidString
        let defaults = UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        let owner = CurrentOwnerContext(defaults:defaults)
        let context = ModelContext(ModelContainerFactory.makeInMemoryContainer())
        var uploads = 0
        let repo = LocalTwoBallPracticeRepository(context:context,owner:owner,enqueue:{_,_ in uploads += 1})
        var record = TwoBallPracticeRecord(ownerKey:owner.ownerKey,is3D:false,configuration:.init(),mode:.free,prepared:try fixture())
        try repo.save(record);XCTAssertEqual(uploads,0)
        record.accept(try realShot(record.current!));try repo.save(record)
        var changed = record;changed.activeSeconds=120
        var invalid = record.continuation(prepared:try fixture());invalid.ownerKey="wrong-owner"
        XCTAssertThrowsError(try repo.saveAtomically([changed,invalid]))
        XCTAssertEqual(try repo.resumable(is3D:false)?.activeSeconds,0)
        let sessions = try context.fetch(FetchDescriptor<TrainingSession>())
        XCTAssertEqual(sessions.count,1);XCTAssertEqual(uploads,1)
        let dto = TrainingSessionDTO(from:sessions[0])
        let decoded = try JSONDecoder().decode(TrainingSessionDTO.self,from:JSONEncoder().encode(dto))
        XCTAssertEqual(decoded.sourcePayloadSnapshot,sessions[0].sourcePayloadSnapshot)
        XCTAssertEqual(HistoryViewModel.assembleTwoBallSessions(sessions:sessions).records.count,1)
        XCTAssertFalse(TrainingSessionKind.countsTowardAccuracy(decoded.kind))
        XCTAssertFalse(TrainingSessionKind.countsTowardGoal(decoded.kind))
        sessions[0].sourcePayloadSnapshot=Data("broken".utf8)
        XCTAssertThrowsError(try repo.resumable(is3D:false))
        XCTAssertEqual(HistoryViewModel.assembleTwoBallSessions(sessions:sessions).unreadableCount,1)
        owner.useAccount(userID:"other");XCTAssertThrowsError(try repo.save(record))
        XCTAssertNil(try repo.resumable(is3D:false))
    }
    private final class MemoryRepository: TwoBallPracticeRepository {
        let ownerKey="two-ball-state-owner"
        var saved:TwoBallPracticeRecord?
        var failSubmissions=false
        func save(_ record:TwoBallPracticeRecord) throws {
            if failSubmissions && !record.attempts.isEmpty { throw CocoaError(.fileWriteOutOfSpace) }
            saved=record
        }
        func saveAtomically(_ records:[TwoBallPracticeRecord]) throws { if let last=records.last { try save(last) } }
        func resumable(is3D:Bool) throws -> TwoBallPracticeRecord? { saved }
    }
    func testOpeningOldBankPreservesUnselectedDraftAndQuota() throws {
        let suite = "two-ball-bank-migration-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let limiter = AngleUsageLimiter(defaults: defaults, namespace: suite)
        let repository = MemoryRepository()
        var old = TwoBallPracticeRecord(ownerKey: repository.ownerKey, is3D: false, configuration: .init(),
                                         mode: .trajectory, prepared: try fixture())
        old.presentation = nil
        old.trainingBankPolicyVersion = nil
        old.accept(try realShot(old.current!))
        repository.saved = old
        let vm = TwoBallPracticeViewModel(is3D: false, limiter: limiter, defaults: defaults)
        defer { vm.suspendTeachingActivity() }
        vm.attach(repository: repository)
        XCTAssertEqual(vm.phase, .settings); XCTAssertNil(vm.record)
        XCTAssertEqual(repository.saved?.status, .active)
        XCTAssertEqual(repository.saved?.id, old.id)
        XCTAssertEqual(repository.saved?.latestShot?.id, old.latestShot?.id)
        XCTAssertEqual(repository.saved?.attempts.count, old.attempts.count)
        XCTAssertEqual(limiter.questionsUsedToday, 0)
        XCTAssertNil(vm.message)
    }
    func testLegacyBallPosesFollowRolesAfterRestore() throws {
        let prepared = try fixture()
        let repo = MemoryRepository()
        var record = TwoBallPracticeRecord(ownerKey: repo.ownerKey, is3D: false, configuration: .init(), mode: .trajectory, prepared: prepared)
        let first: [Float] = [0, 0, 0, 1], second: [Float] = [0, 1, 0, 0]
        record.initialPoses = ["cueBall": first, "_1": first, "_2": second]
        record.finalPoses = ["cueBall": first, "_2": second]
        repo.saved = record
        let vm = TwoBallPracticeViewModel(is3D: false)
        defer { vm.suspendTeachingActivity() }
        vm.attach(repository: repo); vm.setupScene()
        XCTAssertEqual(vm.record?.initialPoses["_8"], second)
        XCTAssertEqual(vm.record?.initialPoses["_\(prepared.question.ballNumber)"], first)
        XCTAssertEqual(vm.record?.finalPoses["_8"], second)
        XCTAssertEqual(vm.secondNode?.simdOrientation.vector, SIMD4<Float>(0, 1, 0, 0))
        XCTAssertEqual(vm.targetNode?.name, "_\(prepared.question.ballNumber)")
    }

    func testSaveFailureRestoreAndSameQuestionAtQuotaLimit() async throws {
        let suite="two-ball-state-"+UUID().uuidString
        let defaults=UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        let limiter=AngleUsageLimiter(defaults:defaults,namespace:suite,limit:15)
        for _ in 0..<14 { limiter.recordQuestion() }
        let repo=MemoryRepository(), vm=TwoBallPracticeViewModel(is3D:false,limiter:limiter,defaults:defaults)
        defer { vm.suspendTeachingActivity() }
        vm.attach(repository:repo);vm.start(.init(),prepared:try fixture());vm.setupScene();vm.setPlaysStroke(false)
        let q = try XCTUnwrap(vm.record?.current)
        XCTAssertNotEqual(q.ballNumber, 8)
        XCTAssertEqual(vm.targetNode?.name, "_\(q.ballNumber)")
        XCTAssertEqual(vm.secondNode?.name, "_8")
        XCTAssertEqual(Set(vm.onTableKeys), Set(["cueBall", "_\(q.ballNumber)", "_8"]))
        XCTAssertEqual(Set(vm.scene.allBallNodes.filter { !$0.value.isHidden }.keys), Set(vm.onTableKeys))
        vm.velocity=2.6;repo.failSubmissions=true;vm.strike()
        for _ in 0..<1000 where vm.phase == .preparing { try await Task.sleep(for:.milliseconds(10)) }
        XCTAssertEqual(vm.phase,.saveFailed);XCTAssertEqual(limiter.questionsUsedToday,14)
        repo.failSubmissions=false;vm.retrySave()
        XCTAssertEqual(vm.phase,.result);XCTAssertEqual(limiter.questionsUsedToday,15)
        vm.retry();XCTAssertEqual(vm.phase,.aiming);XCTAssertEqual(vm.primaryTitle,"提交")
        vm.strike()
        for _ in 0..<1000 where vm.phase == .preparing { try await Task.sleep(for:.milliseconds(10)) }
        XCTAssertEqual(vm.phase,.result);XCTAssertEqual(limiter.questionsUsedToday,15)
        XCTAssertEqual(vm.record?.attempts.count,1)
        let restored=TwoBallPracticeViewModel(is3D:false,limiter:limiter,defaults:defaults)
        restored.attach(repository:repo)
        XCTAssertEqual(restored.record?.current?.id,vm.record?.current?.id)
        XCTAssertEqual(restored.phase,.result);XCTAssertEqual(limiter.questionsUsedToday,15)
        while vm.record?.hasNextRoute == true {
            vm.next();XCTAssertEqual(vm.phase,.aiming);vm.strike()
        }
        if vm.phase == .aiming { vm.strike() }
        vm.next();XCTAssertEqual(vm.phase,.summary);XCTAssertEqual(limiter.questionsUsedToday,15)
        vm.ownerChanged();XCTAssertNil(vm.record)
    }
    func testDiskReopenOwnerTransferAndRollback() throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("two-ball-disk-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:folder) }
        let suite="two-ball-owner-"+UUID().uuidString
        let defaults=UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        let owner=CurrentOwnerContext(defaults:defaults), source=owner.ownerKey
        var record=TwoBallPracticeRecord(ownerKey:source,is3D:true,configuration:.init(),mode:.free,prepared:try fixture())
        record.accept(try realShot(record.current!));record.showingResult=true
        let url=folder.appendingPathComponent("practice.store")
        do {
            let container=try ModelContainerFactory.makeContainer(at:url)
            try LocalTwoBallPracticeRepository(context:container.mainContext,owner:owner,enqueue:{_,_ in }).save(record)
        }
        let container=try ModelContainerFactory.makeContainer(at:url), context=container.mainContext
        let repo=LocalTwoBallPracticeRepository(context:context,owner:owner,enqueue:{_,_ in })
        XCTAssertEqual(try repo.resumable(is3D:true)?.latestShot?.id,record.latestShot?.id)
        let destination=OwnerKey.account("two-ball-transfer")
        let failed=OwnerTransferService(context:context,saveAction:{_ in throw CocoaError(.fileWriteOutOfSpace)})
        XCTAssertThrowsError(try failed.transfer(from:source,to:destination))
        XCTAssertEqual(try repo.resumable(is3D:true)?.ownerKey,source)
        XCTAssertEqual(try OwnerTransferService(context:context).transfer(from:source,to:destination).sessions,1)
        owner.useAccount(userID:"two-ball-transfer")
        XCTAssertEqual(try repo.resumable(is3D:true)?.latestShot?.id,record.latestShot?.id)
        XCTAssertEqual(try repo.resumable(is3D:true)?.current?.contentID,record.current?.contentID)
    }
    func testTwentyPhysicalQuestionsAndBoundedFreeContinuation() throws {
        var config=SceneTrainingConfiguration();config.freePractice=true
        var record:TwoBallPracticeRecord?, seen=Set<String>(), maxBytes=0
        var seconds:[Double]=[]
        for i in 0..<21 {
            let start=ProcessInfo.processInfo.systemUptime
            let prepared=try TwoBallQuestionPreparer.prepare(config,excluding:seen,seed:UInt64(20261025+i))
            seconds.append(ProcessInfo.processInfo.systemUptime-start)
            XCTAssertFalse(seen.contains(prepared.question.contentID));seen.insert(prepared.question.contentID)
            if let previous=record, previous.consumed.count == 10 {
                record=previous.continuation(prepared:prepared)
                XCTAssertEqual(record?.logicalSessionID,previous.logicalSessionID)
            } else if record != nil {
                record?.questions.append(prepared.question);record?.cursor += 1;record?.resetInput()
            } else {
                record = .init(ownerKey:"physical-round",is3D:false,configuration:config,mode:.free,prepared:prepared)
            }
            let shot=try realShot(prepared.question)
            XCTAssertNil(shot.failure);XCTAssertNotNil(shot.difficulty)
            record?.accept(shot)
            XCTAssertEqual(record?.totalAttemptCount,i+1);XCTAssertEqual(record?.validCount,i+1)
            let payload=try record!.encodedPayload();maxBytes=max(maxBytes,payload.count)
            XCTAssertLessThan(payload.count,512_000)
            XCTAssertEqual(try TwoBallPracticeRecord.decodePayload(payload).questionNumber,i+1)
        }
        print("TWO_BALL_21_QUESTIONS maxPayloadBytes=\(maxBytes) prepareSeconds=\(seconds)")
        XCTAssertEqual(record?.completedQuestionOffset,20);XCTAssertEqual(record?.questions.count,1)
    }

}

// Frozen 22-stop oracle from the approved five-board research, independent Python calculation.
extension TwoBallPracticeTests {
    func testComfortMatchesApproved22StopsAndMirrors() throws {
        let rows: [[Double]] = [[-0.08950220793485641, 0.4004509747028351, -0.7628736318567686, 0.5229766145382663, 2, 100.0, 97.99448802711103, 100.0, 99.3269765653701], [0.8432851433753967, 0.2857246398925781, -0.7628736318567686, 0.5229766145382663, 2, 29.94348133283265, 99.75790249193399, 100.0, 66.84719681915213], [1.104933738708496, 0.26721468567848206, -0.7628736318567686, 0.5229766145382663, 2, 12.322308969826594, 91.01420014607582, 100.0, 48.2244278369838], [-0.1620529592037201, 0.3955541253089905, -0.7628736318567686, 0.5229766145382663, 2, 100.0, 98.1651862916573, 100.0, 99.38461622680616], [0.47675952315330505, 0.2539675831794739, -0.7628736318567686, 0.5229766145382663, 2, 67.6931775248056, 99.87997993000117, 100.0, 87.768993002219], [-1.0214099884033203, -0.44307222962379456, -1.170113438166937, 0.10012474542270358, 2, 100.0, 94.02978899357919, 100.0, 97.96895760997131], [-1.1322920322418213, 0.3090967535972595, -1.170113438166937, 0.10012474542270358, 0, 90.7803232518404, 89.34271357838584, 100.0, 93.25746829798304], [-1.1836743354797363, 0.38836875557899475, -1.170113438166937, 0.10012474542270358, 0, 100.0, 76.5303365139925, 100.0, 91.46983050426134], [-1.0118451118469238, 0.42398715019226074, -1.170113438166937, 0.10012474542270358, 0, 100.0, 95.84946525032146, 91.43939178329397, 95.69906051728812], [0.883952796459198, -0.366070419549942, 0.1001360035581673, 0.5233769024937074, 5, 76.77897169525838, 98.70412808699109, 100.0, 91.1715215173003], [0.8165768980979919, -0.3390231728553772, 0.1001360035581673, 0.5233769024937074, 5, 83.24536706402428, 99.22716001446122, 100.0, 93.82751437604523], [0.6641753315925598, -0.16852480173110962, 0.1001360035581673, 0.5233769024937074, 5, 98.48473136392919, 99.97499829831636, 100.0, 99.48404532115362], [0.2779718041419983, 0.3522981107234955, 0.1001360035581673, 0.5233769024937074, 5, 66.97865545935652, 99.17801629633134, 100.0, 87.2537191383702], [0.949649453163147, 0.3183777630329132, 1.1544035241170072, -0.27035077071153074, 1, 100.0, 99.34383223730569, 100.0, 99.78079726513408], [1.1608376502990723, 0.3601384162902832, 1.1544035241170072, -0.27035077071153074, 1, 100.0, 83.26610873794371, 99.72154119556399, 93.99088750017559], [0.8265523910522461, 0.17225418984889984, 1.1544035241170072, -0.27035077071153074, 1, 100.0, 99.95997273512184, 90.50604797146218, 96.71664958580553], [1.105139136314392, -0.5023871064186096, 1.1544035241170072, -0.27035077071153074, 3, 100.0, 83.2947749790173, 100.0, 94.08908672874547], [0.2095216065645218, 0.46564364433288574, 0.1436154139184857, -0.1279154582712886, 4, 100.0, 91.65372761633097, 100.0, 97.13670723589892], [0.16563019156455994, 0.5563692450523376, 0.1436154139184857, -0.1279154582712886, 4, 99.99312805357455, 66.05875965345506, 99.99429394095318, 87.08805592742839], [0.30038776993751526, 0.14198586344718933, 0.1436154139184857, -0.1279154582712886, 4, 89.69157573637861, 99.98554796820856, 99.31241130201003, 96.21234588351591], [0.2142994999885559, -0.5381754636764526, 0.1436154139184857, -0.1279154582712886, 5, 100.0, 73.92761809938345, 100.0, 90.420916474754], [0.20364996790885925, -0.47637689113616943, 0.1436154139184857, -0.1279154582712886, 5, 100.0, 90.06701760366464, 100.0, 96.57289724981098]]
        for row in rows {
            let result = try XCTUnwrap(TwoBallComfortScore.evaluate(cue: (row[0], row[1]), ball: (row[2], row[3]), pocket: Int(row[4])))
            for (actual, expected) in zip([result.distance, result.space, result.angle, result.total], row.suffix(4)) {
                XCTAssertEqual(actual, expected, accuracy: 1e-8)
                XCTAssertTrue((0...100.00000001).contains(actual))
            }
            let mirroredPocket = [1,0,3,2,4,5][Int(row[4])]
            let mirror = try XCTUnwrap(TwoBallComfortScore.evaluate(cue: (-row[0], row[1]), ball: (-row[2], row[3]), pocket: mirroredPocket))
            XCTAssertEqual(mirror.total, result.total, accuracy: 1e-8)
        }
        XCTAssertNil(TwoBallComfortScore.evaluate(cue: (0,0), ball: (0,0), pocket: 4))
        XCTAssertNil(TwoBallComfortScore.evaluate(cue: (0,-0.4), ball: (0,0), pocket: 4))
        for angle in [0.0, 10, 15, 30, 60, 89] {
            let theta = angle * .pi/180, r = TwoBallDifficultyMetric.Geometry.source.radius
            let value = try XCTUnwrap(TwoBallComfortScore.evaluate(cue: (sin(theta)*0.5, 2*r+cos(theta)*0.5), ball: (0,0), pocket: 4))
            XCTAssertEqual(value.angle, 100*exp(-pow(max(angle-15,0)/30,2)), accuracy: 1e-8)
        }
    }
    func testComfortRetryStatisticsAndLegacyRecordsStaySeparate() throws {
        let prepared = try fixture()
        var record = TwoBallPracticeRecord(ownerKey: "test", is3D: false, configuration: .init(), mode: .free, prepared: prepared)
        var first = try realShot(prepared.question), retry = try realShot(prepared.question)
        XCTAssertNotNil(first.comfort)
        first.comfort = .init(distance: 100, space: 100, angle: 100, total: 100)
        retry.comfort = .init(distance: 50, space: 50, angle: 50, total: 50)
        record.accept(first); record.accept(retry); record.accept(retry)
        XCTAssertEqual(record.averageScore, 100)
        XCTAssertEqual(record.currentRouteAverage(), 75)
        XCTAssertEqual(record.currentRouteAverage(excluding: retry.id), 100)
        XCTAssertEqual(record.attempts.count, 1)
        let restored = try TwoBallPracticeRecord.decodePayload(record.encodedPayload())
        XCTAssertEqual(restored.currentRouteAverage(), 75)
        XCTAssertEqual(restored.latestShot?.freeScore, 50)
        XCTAssertTrue(restored.historyDetail.contains("首答均分"))
        let next = record.continuation(prepared: prepared)
        XCTAssertEqual(next.averageScore, 100)
        XCTAssertNil(next.currentRouteAverage())
        // Simulate a genuine v1 payload with no new optional keys, not a recalculated old result.
        var raw = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? [String: Any])
        for key in ["currentComfortSum", "currentComfortCount", "previousComfortSum", "previousComfortCount"] { raw.removeValue(forKey: key) }
        var shots = try XCTUnwrap(raw["attempts"] as? [[String: Any]])
        for i in shots.indices { shots[i].removeValue(forKey: "comfortScore") }
        raw["attempts"] = shots
        var latest = try XCTUnwrap(raw["latestShot"] as? [String: Any])
        latest.removeValue(forKey: "comfort"); latest.removeValue(forKey: "comfortVersion"); raw["latestShot"] = latest
        var legacy = try JSONDecoder().decode(TwoBallPracticeRecord.self, from: JSONSerialization.data(withJSONObject: raw))
        XCTAssertNil(legacy.averageScore); XCTAssertNil(legacy.currentRouteAverage()); XCTAssertNil(legacy.latestShot?.freeScore)
        XCTAssertTrue(legacy.historyDetail.contains("旧版难度"))
        XCTAssertEqual(legacy.averageDifficulty, record.averageDifficulty)
        let oldAttempt = legacy.attempts[0]
        let newShot = try realShot(prepared.question)
        legacy.accept(newShot)
        XCTAssertEqual(legacy.attempts[0].difficulty, oldAttempt.difficulty)
        XCTAssertNil(legacy.attempts[0].comfortScore)
        XCTAssertEqual(legacy.averageScore, newShot.freeScore)
        XCTAssertEqual(legacy.currentRouteAverage(), newShot.freeScore)
        let suite = "comfort-legacy-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let owner = CurrentOwnerContext(defaults: defaults)
        let context = ModelContext(ModelContainerFactory.makeInMemoryContainer())
        let repository = LocalTwoBallPracticeRepository(context: context, owner: owner, enqueue: { _,_ in })
        legacy.ownerKey = owner.ownerKey
        try repository.save(legacy)
        let recovered = try XCTUnwrap(repository.resumable(is3D: false))
        XCTAssertEqual(recovered.attempts.count, 2)
        XCTAssertEqual(recovered.averageScore, newShot.freeScore)
        XCTAssertNil(recovered.attempts[0].comfortScore)
    }
}

extension TwoBallPracticeTests {
    /// Diagnostic evidence for cross-runtime floating point replay. World X/Z are
    /// metres; Y is up, surfaceY is cloth height, positions are ball centres.
    /// No reference replacement or tolerance change is performed here.
    func testFrozenRouteRuntimeDiagnostic() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "TwoBallParameterReplay", withExtension: "json"))
        let cases = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]])
        let reference = try XCTUnwrap(cases.first { ($0["key"] as? String) == "grid-v3:101:102:5#52" })
        let bank = try TwoBallBankStore.load()
        let entry = try XCTUnwrap(bank.index.layouts.first { $0.id == reference["layoutID"] as? String })
        let layout = try bank.layout(entry), board = try bank.board(for: layout)
        let q = try XCTUnwrap(layout.questions.first { $0.id == reference["cellID"] as? Int })
        let second = TrainingBankPoint(.init(Float(q.p[0]), 0, Float(q.p[1])))
        let profile = TwoBallQuestionPreparer.renderedProfile()
        var rows: [[String: Any]] = []
        func vector(_ v: SCNVector3) -> [Float] { [v.x, v.y, v.z] }
        for pair in q.refs {
            let parameter = try XCTUnwrap(layout.routes.first { $0.id == pair[0] })
            let prediction = try TwoBallQuestionPreparer.solve(board: board, second: second,
                input: parameter.input, surfaceY: BTTablePhysics.surfaceY, profile: profile, direction: parameter.direction)
            let recorder = try XCTUnwrap(prediction.recorder)
            var frames: [String: [[String: Any]]] = [:]
            for (name, values) in recorder.framesByBallName {
                frames[name] = values.map { ["t": $0.time, "p": vector($0.position), "v": vector($0.velocity),
                    "w": [$0.angularVelocity.x, $0.angularVelocity.y, $0.angularVelocity.z, $0.angularVelocity.w],
                    "state": String(describing: $0.state)] }
            }
            rows.append(["combo": parameter.id, "direction": vector(parameter.direction), "frames": frames,
                "events": prediction.events.map { ["time": $0.time, "kind": String(describing: $0.kind)] }])
            XCTAssertTrue(prediction.hasFinalTableState)
        }
        let data = try JSONSerialization.data(withJSONObject: ["os": ProcessInfo.processInfo.operatingSystemVersionString,
            "key": reference["key"]!, "surfaceY": BTTablePhysics.surfaceY, "routes": rows], options: [.sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "frozen-route-runtime-diagnostic"; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testProductionParametersMatchFrozen578References() throws {
        struct Reference: Decodable {
            struct Route: Decodable {
                let comboIndex: Int
                let cueStop: [Float]
                let trajectory2mm: TwoBallSourceRoute.Line
                let executionDifficulty: TwoBallExecutionDifficulty
            }
            let key, layoutID: String
            let cellID: Int
            let candidate: TwoBallCandidate
            let routes: [Route]
        }
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "TwoBallParameterReplay", withExtension: "json"))
        let cases = try JSONDecoder().decode([Reference].self, from: Data(contentsOf: url))
        XCTAssertEqual(cases.count, 138)
        let bank = try TwoBallBankStore.load(), profile = TwoBallQuestionPreparer.renderedProfile()
        var tested = 0, maxScoreDelta = 0.0, maxEffortDelta = 0.0
        for c in cases {
            let entry = try XCTUnwrap(bank.index.layouts.first { $0.id == c.layoutID })
            let layout = try bank.layout(entry), board = try bank.board(for: layout)
            let q = try XCTUnwrap(layout.questions.first { $0.id == c.cellID })
            XCTAssertEqual(q.refs, c.candidate.top5.map { [$0.comboIndex,$0.pocket] })
            let second = TrainingBankPoint(.init(Float(q.p[0]),0,Float(q.p[1])))
            var efforts: [Double] = []
            for (rank,pair) in q.refs.enumerated() {
                let param = try XCTUnwrap(layout.routes.first { $0.id == pair[0] })
                let result = try XCTUnwrap(TwoBallQuestionPreparer.materialize(board: board, second: second,
                    parameter: param, pocket: pair[1], rank: rank, profile: profile), c.key)
                let old = try XCTUnwrap(c.routes.first { $0.comboIndex == param.id })
                XCTAssertNil(result.replayRMSCM)
                XCTAssertEqual(result.source.cueStop, old.cueStop, c.key)
                XCTAssertEqual(result.source.trajectory2mm.points, old.trajectory2mm.points, c.key)
                XCTAssertEqual(result.source.trajectory2mm.mandatoryPointIndices, old.trajectory2mm.mandatoryPointIndices, c.key)
                XCTAssertEqual(result.source.trajectory2mm.cushions?.map(\.cushionID), old.trajectory2mm.cushions?.map(\.cushionID), c.key)
                let comfort = try XCTUnwrap(result.recommendation.comfort)
                XCTAssertTrue(comfort.isQualified)
                let expected = try XCTUnwrap(c.candidate.top5[rank].comfort)
                for (actual,reference) in zip([comfort.distanceScore,comfort.spaceScore,comfort.angleScore,comfort.totalScore],
                    [expected.distanceScore,expected.spaceScore,expected.angleScore,expected.totalScore]) {
                    XCTAssertEqual(actual,reference,accuracy: 0.0001,c.key)
                    maxScoreDelta = max(maxScoreDelta,abs(actual-reference))
                }
                let effort = try XCTUnwrap(result.source.executionDifficulty)
                XCTAssertEqual(effort.effort, old.executionDifficulty.effort, accuracy: 1e-12)
                maxEffortDelta = max(maxEffortDelta,abs(effort.effort-old.executionDifficulty.effort))
                efforts.append(effort.effort); tested += 1
            }
            XCTAssertEqual(efforts,efforts.sorted(),c.key)
        }
        XCTAssertEqual(tested,578)
        print("PARAMETER_PRODUCTION_AUDIT questions=\(cases.count) routes=\(tested) maxPartDelta=\(maxScoreDelta) maxEffortDelta=\(maxEffortDelta)")
    }

    func testGeneratedRouteRejectsChangedRailOrderAndLowComfort() throws {
        let bank = try TwoBallBankStore.load(), q = try fixture().question
        let layout = try bank.layout(XCTUnwrap(bank.index.layouts.first { $0.id == q.board.id }))
        let param = try XCTUnwrap(layout.routes.first { $0.id == q.route.source.comboIndex })
        let changed = TwoBallParameterRoute(id: param.id,v: param.v,sx: param.sx,sy: param.sy,
                                            dir: param.dir,rails: param.rails+[0])
        XCTAssertNil(try TwoBallQuestionPreparer.materialize(board: q.board, second: q.second, parameter: changed,
            pocket: q.secondPocket, rank: 0, profile: TwoBallQuestionPreparer.renderedProfile()))
        // Same first-shot geometry, B at the old stop: an obstructed continuation cannot become an approved reference.
        let stop = TrainingBankPoint(.init(q.route.source.cueStop[0],0,q.route.source.cueStop[1]))
        let result = try? TwoBallQuestionPreparer.materialize(board: q.board, second: stop, parameter: param,
            pocket: q.secondPocket, rank: 0, profile: TwoBallQuestionPreparer.renderedProfile())
        XCTAssertNil(result)
    }
}

// User-approved r4 oracle: the exact 36 shapes reviewed before implementation.
// Source: output/two-ball-pocket-angle-r4-20261026/weighted-data.json
extension TwoBallPracticeTests {
    func testFreeComfortMatchesReviewed36ShapesAndMirrors() throws {
        let rows: [[Double]] = [
            [0.3957016227973612, -0.2986068620483201, 0.9595171952689062, -0.5038189480437213, 1, 100.0, 99.70805320042369, 100.0, 99.8053213717019],
            [0.4350110371720798, -0.21245441671139376, 0.9595171952689062, -0.5038189480437213, 1, 100.0, 99.94856134968124, 100.0, 99.96570609607019],
            [0.45969128189152825, -0.17189417295685022, 0.9595171952689062, -0.5038189480437213, 1, 100.0, 99.97790852541624, 100.0, 99.98527207911462],
            [0.5185185173240909, -0.09697725149465203, 0.9595171952689062, -0.5038189480437213, 1, 100.0, 99.99554184581069, 77.8800783071405, 84.94157625823368],
            [0.5890336012938384, -0.031863540621243414, 0.9595171952689062, -0.5038189480437213, 1, 100.0, 99.99889131456248, 36.787944117144235, 54.220405185467335],
            [0.6698970850233553, 0.021652451502776227, 0.9595171952689062, -0.5038189480437213, 1, 100.0, 99.99859357861682, 10.539922456186433, 28.888178140221445],
            [0.1137938365615887, -0.19600081905061953, 0.6776094090331337, -0.4012129050460207, 1, 100.0, 99.96342104687422, 100.0, 99.97561328775403],
            [0.15310325093630728, -0.10984837371369316, 0.6776094090331337, -0.4012129050460207, 1, 100.0, 99.99411988417967, 100.0, 99.99607990357705],
            [0.17778349565575574, -0.06928812995914962, 0.6776094090331337, -0.4012129050460207, 1, 100.0, 99.99756966413364, 100.0, 99.99837977280762],
            [0.23661073108831843, 0.005628791503048569, 0.6776094090331337, -0.4012129050460207, 1, 100.0, 99.99931021367064, 77.8800783071405, 84.94215411244993],
            [0.30712581505806597, 0.07074250237645718, 0.6776094090331337, -0.4012129050460207, 1, 100.0, 99.99692956053642, 36.787944117144235, 54.22017090583982],
            [0.3879892987875828, 0.12425849450047682, 0.6776094090331337, -0.4012129050460207, 1, 100.0, 99.98978228954277, 10.539922456186433, 28.887484420300446],
            [-0.16811394967418392, -0.09339477605291888, 0.3957016227973611, -0.29860686204832004, 1, 100.0, 99.99588419775432, 100.0, 99.99725612242497],
            [-0.12880453529946523, -0.0072423307159925066, 0.3957016227973611, -0.29860686204832004, 1, 100.0, 99.99938695864434, 100.0, 99.99959130555409],
            [-0.10412429058001682, 0.03331791303855103, 0.3957016227973611, -0.29860686204832004, 1, 100.0, 99.99878196168669, 91.05103613800341, 93.98698303148433],
            [-0.04529705514745419, 0.10823483450074922, 0.3957016227973611, -0.29860686204832004, 1, 100.0, 99.99337503045514, 43.00946406400623, 59.24587864815146],
            [0.025218028822293403, 0.17334854537415784, 0.3957016227973611, -0.29860686204832004, 1, 100.0, 99.97213042755958, 9.596708604499847, 27.687895589901363],
            [0.10608151255181028, 0.22686453749817748, 0.3957016227973611, -0.29860686204832004, 1, 100.0, 99.91188908511857, 1.011485645260456, 11.315824343948988],
            [-0.4500217359099563, 0.009211266944781776, 0.1137938365615887, -0.19600081905061945, 1, 100.0, 99.99933195708928, 100.0, 99.99955463781157],
            [-0.41071232153523773, 0.09536371228170815, 0.1137938365615887, -0.19600081905061945, 1, 100.0, 99.99534529729988, 96.92332344763442, 97.94276391300917],
            [-0.38603207681578927, 0.13592395603625163, 0.1137938365615887, -0.19600081905061945, 1, 100.0, 99.9885706222559, 75.48396019890073, 83.26576367455974],
            [-0.3272048413832266, 0.21084087749844982, 0.1137938365615887, -0.19600081905061945, 1, 100.0, 99.94195539426208, 21.62651668298873, 40.81972160478956],
            [-0.25668975741347905, 0.27595458837185843, 0.1137938365615887, -0.19600081905061945, 1, 100.0, 99.77177503510401, 2.2794180883612354, 15.305708932458904],
            [-0.17582627368396214, 0.3294705804958782, 0.1137938365615887, -0.19600081905061945, 1, 100.0, 99.32245547365564, 0.08838263069350491, 4.83168405425053],
            [-0.7319295221457289, 0.11181730994248244, -0.16811394967418392, -0.0933947760529188, 1, 100.0, 99.99218696982743, 100.0, 99.99479127930377],
            [-0.6926201077710104, 0.1979697552794088, -0.16811394967418392, -0.0933947760529188, 1, 100.0, 99.95812928216542, 90.48374180359595, 93.59592531156228],
            [-0.6679398630515618, 0.23852999903395228, -0.16811394967418392, -0.0933947760529188, 1, 100.0, 99.90226780374462, 60.275166475009534, 72.35982221180153],
            [-0.6091126276189992, 0.31344692049615047, -0.16811394967418392, -0.0933947760529188, 1, 100.0, 99.54470959575681, 10.474253370494475, 28.77047687405711],
            [-0.5385975436492516, 0.3785606313695591, -0.16811394967418392, -0.0933947760529188, 1, 100.0, 98.35632000242396, 0.5214823686591382, 8.883587344126383],
            [-0.45773405991973476, 0.43207662349357884, -0.16811394967418392, -0.0933947760529188, 1, 100.0, 95.50990467083398, 0.007438546485972924, 2.074570193528848],
            [-1.0138373083815015, 0.21442335294018297, -0.45002173590995653, 0.009211266944781804, 1, 100.0, 98.23857719006384, 100.0, 98.82397738633755],
            [-0.9745278940067829, 0.30057579827710934, -0.45002173590995653, 0.009211266944781804, 1, 100.0, 99.11164300560553, 82.90291181804004, 88.28260610834157],
            [-0.9498476492873345, 0.3411360420316529, -0.45002173590995653, 0.009211266944781804, 1, 100.0, 99.13938531128244, 47.236655274101466, 62.44633689249048],
            [-0.8910204138547718, 0.41605296349385107, -0.45002173590995653, 0.009211266944781804, 1, 100.0, 96.86593339443701, 4.978706836786392, 20.689122526010483],
            [-0.8205053298850242, 0.4811666743672597, -0.45002173590995653, 0.009211266944781804, 1, 100.0, 90.05846110459667, 0.11708796207911744, 5.14773705246892],
            [-0.7396418461555073, 0.5346826664912794, -0.45002173590995653, 0.009211266944781804, 1, 100.0, 76.16217835588978, 0.0006144212353328198, 0.836626016014847]
        ]
        for row in rows {
            let score = try XCTUnwrap(TwoBallComfortScore.evaluateFreePosition(
                cue: (row[0],row[1]), ball: (row[2],row[3]), pocket: Int(row[4])))
            let bank = try XCTUnwrap(TwoBallComfortScore.evaluate(
                cue: (row[0],row[1]), ball: (row[2],row[3]), pocket: Int(row[4])))
            for (value, expected) in zip([score.distance, score.space, score.angle, score.total], row.suffix(4)) {
                XCTAssertEqual(value, expected, accuracy: 1e-8)
            }
            XCTAssertEqual(score.distance, bank.distance)
            XCTAssertEqual(score.space, bank.space)
            XCTAssertLessThanOrEqual(score.total, bank.total + 1e-8)
            let mirror = try XCTUnwrap(TwoBallComfortScore.evaluateFreePosition(
                cue: (-row[0],row[1]), ball: (-row[2],row[3]), pocket: [1,0,3,2,4,5][Int(row[4])]))
            XCTAssertEqual(mirror.total, score.total, accuracy: 1e-8)
        }
    }
    func testFreeComfortPlateauDistanceAndInvalidGeometry() throws {
        let g = TwoBallDifficultyMetric.Geometry.source
        let p = try XCTUnwrap(g.anchor(1))
        // Fixed pocket ray; incoming direction rotates about the geometrical ghost ball.
        func score(_ distance: Double, _ angle: Double) throws -> Double {
            let heading = -20.0 * Double.pi/180, theta = heading-angle*Double.pi/180
            let ball = (p.0-distance*cos(heading), p.1-distance*sin(heading))
            let cue = (ball.0-2*g.radius*cos(heading)-0.5*cos(theta),
                       ball.1-2*g.radius*sin(heading)-0.5*sin(theta))
            return try XCTUnwrap(TwoBallComfortScore.evaluateFreePosition(cue: cue, ball: ball, pocket: 1)).angle
        }
        XCTAssertEqual(try score(0.3, 15), 100, accuracy: 1e-8)
        XCTAssertLessThan(try score(0.3, 25), 100)
        XCTAssertEqual(try score(1.2, 7.5), 100, accuracy: 1e-8)
        XCTAssertLessThan(try score(1.2, 10), 100)
        XCTAssertEqual(try score(0.6-1e-8, 25), try score(0.6+1e-8, 25), accuracy: 1e-4)
        for angle in [0.0,10,15,25,35,45,60,80] {
            let values = try [0.3,0.6,0.9,1.2,1.5,1.8].map { try score($0, angle) }
            for (a,b) in zip(values,values.dropFirst()) { XCTAssertLessThanOrEqual(b, a+1e-8) }
            if angle == 0 { for value in values { XCTAssertEqual(value,100,accuracy:1e-8) } }
        }
        for cue in [(0.0,0.0), (0,-0.4), (Double.nan,0)] {
            XCTAssertNil(TwoBallComfortScore.evaluateFreePosition(cue: cue,ball: (0,0),pocket: 4))
        }
        XCTAssertNil(TwoBallComfortScore.evaluateFreePosition(cue: (0,0.4),ball: (0,0),pocket: 6))
    }
    func testFreeMinimumWeightIncludesDistanceAndSpace() throws {
        // Two independent frozen research cases where angle is 100 but another factor is weakest.
        let distance = try XCTUnwrap(TwoBallComfortScore.evaluateFreePosition(
            cue: (1.104933738708496,0.26721468567848206),
            ball: (-0.7628736318567686,0.5229766145382663),pocket: 2))
        XCTAssertEqual(distance.angle,100,accuracy:1e-8)
        XCTAssertEqual(distance.total,30.273368403405197,accuracy:1e-8)
        let space = try XCTUnwrap(TwoBallComfortScore.evaluateFreePosition(
            cue: (0.2095216065645218,0.46564364433288574),
            ball: (0.1436154139184857,-0.1279154582712886),pocket: 4))
        XCTAssertEqual(space.angle,100,accuracy:1e-8)
        XCTAssertEqual(space.total,94.39521742561595,accuracy:1e-8)
    }
    func testFreeComfortProductionShotAndFrozenVersionRoundTrip() throws {
        let prepared = try fixture(), q = prepared.question
        let shot = try realShot(q)
        XCTAssertNil(shot.failure)
        XCTAssertEqual(shot.comfortVersion, TwoBallComfortScore.freePositionVersion)
        let cue = try XCTUnwrap(shot.finalPositions[ShotInput.cueBallName])
        let expected = try XCTUnwrap(TwoBallComfortScore.evaluateFreePosition(
            cue: (Double(cue.x),Double(cue.z)),ball: (Double(q.second.x),Double(q.second.z)),pocket: q.secondPocket))
        XCTAssertEqual(try XCTUnwrap(shot.freeScore), expected.total, accuracy: 1e-8)
        XCTAssertEqual(try TwoBallBankStore.load().index.comfortVersion, TwoBallComfortScore.version)
        XCTAssertNotEqual(TwoBallComfortScore.version, TwoBallComfortScore.freePositionVersion)
        for is3D in [false,true] {
            var record = TwoBallPracticeRecord(ownerKey: "test", is3D: is3D, configuration: .init(), mode: .free, prepared: prepared)
            var old = shot
            old.comfortVersion = TwoBallComfortScore.version
            old.comfort = .init(distance: 100,space: 100,angle: 100,total: 100)
            record.accept(old)
            let restored = try TwoBallPracticeRecord.decodePayload(record.encodedPayload())
            XCTAssertEqual(restored.latestShot?.freeScore,100)
            XCTAssertEqual(restored.averageScore,100)
            XCTAssertTrue(restored.canResumeCurrentTraining)
            var continued = restored
            let retry = try realShot(q)
            continued.accept(retry)
            XCTAssertEqual(continued.averageScore,100, "A new-model retry never rewrites the old first answer")
            XCTAssertEqual(try XCTUnwrap(continued.currentRouteAverage()),(100+expected.total)/2,accuracy:1e-8)
            var fresh = TwoBallPracticeRecord(ownerKey: "test", is3D: is3D, configuration: .init(), mode: .free, prepared: prepared)
            fresh.accept(shot)
            let saved = try TwoBallPracticeRecord.decodePayload(fresh.encodedPayload())
            XCTAssertEqual(saved.attempts.first?.comfortVersion, TwoBallComfortScore.freePositionVersion)
            XCTAssertEqual(saved.latestShot?.freeScore, shot.freeScore)
            XCTAssertTrue(saved.latestShot?.comfort?.details.contains("三项最低分") == true)
            XCTAssertFalse(restored.latestShot?.comfort?.details.contains("三项最低分") == true)
        }
        var unknown = shot
        unknown.comfortVersion = "unknown-future"
        XCTAssertNil(unknown.freeScore)
        unknown.comfortVersion = nil
        XCTAssertNil(unknown.freeScore)
    }
}
