import XCTest
import SwiftData
import SceneKit
@testable import CuePhys

@MainActor
final class SpatialQuizSessionTests: XCTestCase {
    final class DiskRepository: SpatialQuizRepository {
        var ownerKey = "guest:spatial-test"
        var failNextSave = false
        let root: URL
        init() throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent("spatial-quiz-"+UUID().uuidString)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }
        func cleanup() { try? FileManager.default.removeItem(at: root) }
        func save(_ record: SpatialQuizRecord) throws { try saveAtomically([record]) }
        func saveAtomically(_ records: [SpatialQuizRecord]) throws {
            if failNextSave { failNextSave = false; throw SpatialQuizBank.Failure.invalid("injected save failure") }
            guard records.allSatisfy({ $0.ownerKey == ownerKey }) else { throw SpatialQuizBank.Failure.invalid("owner") }
            var values = try archive()
            for record in records { values[record.id.uuidString] = try record.encodedPayload() }
            try JSONEncoder().encode(values).write(to: root.appendingPathComponent("records.json"), options: .atomic)
        }
        func archive() throws -> [String:Data] {
            let url = root.appendingPathComponent("records.json")
            return FileManager.default.fileExists(atPath: url.path) ? try JSONDecoder().decode([String:Data].self, from: Data(contentsOf: url)) : [:]
        }
        func resumable(mode: SpatialQuizMode) throws -> SpatialQuizRecord? {
            try archive().values.map(SpatialQuizRecord.decodePayload).filter { $0.mode == mode && $0.ownerKey == ownerKey && $0.status == .active }.max { $0.updatedAt < $1.updatedAt }
        }
    }
    @MainActor struct Harness {
        let repo: DiskRepository
        let defaults: UserDefaults
        let suite: String
        let limiter: AngleUsageLimiter
        let bank: SpatialQuizBank.Bank
        let session: SpatialQuizSession
        func cleanup() { repo.cleanup(); defaults.removePersistentDomain(forName: suite) }
    }
    func harness(_ mode: SpatialQuizMode, free: Bool = false) throws -> Harness {
        let repo = try DiskRepository(), suite = "SpatialQuizTests."+UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let limiter = AngleUsageLimiter(defaults: defaults, namespace: mode.rawValue, limit: 15)
        limiter.isPremium = free
        let bank = try SpatialQuizBank.load(mode)
        let session = SpatialQuizSession(mode: mode, repository: repo, limiter: limiter)
        try session.start(configuration: .init(freePractice: free, playsStroke: false), bank: bank)
        return .init(repo: repo, defaults: defaults, suite: suite, limiter: limiter, bank: bank, session: session)
    }
    // State-machine fixtures deliberately isolate scoring from physics (B0/B1 cover real solves).
    // The archived space path is sampled from a real completed stroke; only its ruling facts vary.
    func submit(_ h: Harness, success: Bool, failSave: Bool = false) throws -> SpatialQuizShot {
        let pending = try XCTUnwrap(h.session.freeze())
        let question = try XCTUnwrap(h.session.record?.current)
        let result = SpatialQuizPhysics.solve(board: question.source.board, input: pending.input)
        let physical = try XCTUnwrap(SpatialPracticeRecord.freeze(prediction: result.prediction, input: pending.input.spatialInput, before: question.board))
        var events: [SpatialQuizFacts.Event] = []
        if success { events = [.init(time: 0.01, kind: .balls(.cue,.target), source: "state-fixture"),
                              .init(time: 0.02, kind: .pocket(.target,id:"pocket_0"), source:"state-fixture")] }
        let facts = SpatialQuizFacts(complete: true, duration: max(1,Double(physical.duration)), events: events, issues: [], mode: h.session.record?.mode,
            technique:.init(maximumLift:0,chordDeviation:0.01,chordObstacleClearance:-0.01,jumpedOverObstacle:h.bank.manifest.mode == .jump))
        let shot = SpatialQuizShot(id: pending.id, questionID: question.id, submittedAt: pending.submittedAt,
            physical: physical, facts: facts, outcome: SpatialQuizJudgement.evaluate(facts))
        h.repo.failNextSave = failSave
        XCTAssertEqual(h.session.accept(shot, pending: pending), !failSave)
        if !failSave {
            XCTAssertEqual(h.session.activity,.playing,"Legacy playsStroke=false must still animate")
            h.session.playbackFinished()
        }
        return shot
    }
    func testThreeFailuresUnlockOnlyAfterReliableSaveAndRetryDoesNotChangeFirstAnswer() throws {
        for mode in SpatialQuizMode.allCases {
            let h = try harness(mode); defer { h.cleanup() }
            let original = try XCTUnwrap(h.session.record?.current)
            for index in 0..<3 {
                let shot = try submit(h, success: false, failSave: index == 2)
                if index == 2 {
                    XCTAssertEqual(h.session.activity, .saveFailed)
                    XCTAssertNil(h.session.beginDemonstration())
                    XCTAssertFalse(h.session.record?.demonstrationProgress.unlocked ?? true)
                    XCTAssertTrue(h.session.retrySave()); XCTAssertFalse(h.session.retrySave())
                    XCTAssertEqual(h.session.activity,.playing);h.session.playbackFinished()
                }
                XCTAssertEqual(h.session.record?.firstAnswers.count, 1)
                XCTAssertEqual(h.limiter.questionsUsedToday, 1)
                XCTAssertEqual(h.session.canDemonstrate, index == 2)
                XCTAssertEqual(h.session.record?.latestShot?.id, shot.id)
                if index < 2 { try h.session.retry() }
                XCTAssertEqual(h.session.record?.current.source, original.source)
            }
            let oldLatest = h.session.record?.latestShot?.id
            XCTAssertNotNil(h.session.beginDemonstration()); XCTAssertFalse(h.session.canAdjust)
            XCTAssertEqual(h.session.record?.latestShot?.id, oldLatest)
            h.session.playbackFinished()
            try h.session.next(bank: h.bank)
            XCTAssertFalse(h.session.canDemonstrate); XCTAssertFalse(h.session.record?.demonstrationProgress.unlocked ?? true)
            XCTAssertNil(h.session.record?.latestShot)
        }
    }
    func testFirstOrSecondSuccessUnlocksAndLaterFailureCannotRelock() throws {
        for mode in SpatialQuizMode.allCases { for firstSuccess in [true,false] {
            let h = try harness(mode); defer { h.cleanup() }
            let first = try submit(h, success: firstSuccess)
            XCTAssertEqual(h.session.canDemonstrate, firstSuccess)
            if !firstSuccess { try h.session.retry(); _ = try submit(h, success: true) }
            XCTAssertTrue(h.session.canDemonstrate)
            try h.session.retry(); XCTAssertNil(h.session.beginDemonstration())
            _ = try submit(h, success: false); XCTAssertTrue(h.session.canDemonstrate)
            XCTAssertEqual(h.session.record?.firstAnswers.first?.id, first.id)
            let saved=try SpatialQuizRecord.decodePayload(try XCTUnwrap(h.session.record).encodedPayload())
            XCTAssertEqual(saved.firstAnswers.first?.input,first.physical.input)
            XCTAssertEqual(saved.firstAnswers.first?.facts,first.facts)
            XCTAssertNotEqual(saved.latestShot?.id,first.id)
            XCTAssertEqual(h.session.record?.successCount, firstSuccess ? 1 : 0)
        }}
    }
    func testFrozenAttemptRecoveryTechnicalFailureAndStaleOwnerCallbacks() throws {
        for mode in SpatialQuizMode.allCases {
            let h = try harness(mode); defer { h.cleanup() }
            let pending = try XCTUnwrap(h.session.freeze())
            h.session.calculationUnconfirmed(pending, message: "test incomplete")
            XCTAssertEqual(h.limiter.questionsUsedToday, 0); XCTAssertNil(h.session.beginDemonstration())
            let restored = SpatialQuizSession(mode: mode, repository: h.repo, limiter: h.limiter)
            try restored.restore(bank: h.bank)
            XCTAssertEqual(restored.activity, .unconfirmed)
            XCTAssertEqual(try restored.freeze(), pending)
            restored.calculationUnconfirmed(pending, message: "cancel")
            try restored.retry(); let replacement = try XCTUnwrap(restored.freeze())
            XCTAssertNotEqual(replacement.id, pending.id)
            restored.calculationUnconfirmed(pending, message: "stale")
            XCTAssertEqual(restored.activity, .calculating)
            h.repo.ownerKey = "another-owner"
            restored.calculationUnconfirmed(replacement, message: "late owner")
            XCTAssertNil(try restored.freeze()); XCTAssertFalse(restored.canAdjust)
            restored.invalidateOwner(); XCTAssertNil(restored.record)
        }
    }
    func testSavedReceiptRecoveryIsIdempotentAndPlaybackDoesNotCount() throws {
        for mode in SpatialQuizMode.allCases {
            let h = try harness(mode); defer { h.cleanup() }
            let shot = try submit(h, success: true)
            // Simulate another process restoring a saved result before its local quota commit.
            let freshSuite = "SpatialQuizReceipt."+UUID().uuidString
            let defaults = try XCTUnwrap(UserDefaults(suiteName: freshSuite)); defer { defaults.removePersistentDomain(forName:freshSuite) }
            let limiter = AngleUsageLimiter(defaults: defaults, namespace: mode.rawValue, limit: 15)
            let restored = SpatialQuizSession(mode: mode, repository: h.repo, limiter: limiter)
            try restored.restore(bank: h.bank); try restored.restore(bank: h.bank)
            XCTAssertEqual(limiter.questionsUsedToday, 1); XCTAssertTrue(restored.canDemonstrate)
            XCTAssertEqual(restored.beginReplay()?.id, shot.id); restored.suspend()
            XCTAssertEqual(restored.activity,.idle); XCTAssertEqual(limiter.questionsUsedToday, 1)
            XCTAssertEqual(restored.record?.phase,.result)
        }
    }
    func testEntitlementDowngradeKeepsCompletedQuestionWithoutOpeningNewUnlimitedQuestions() throws {
        for mode in SpatialQuizMode.allCases {
            let h=try harness(mode,free:true);defer { h.cleanup() }
            let first=try submit(h,success:true),question=try XCTUnwrap(h.session.record?.current.id)
            h.limiter.isPremium=false
            XCTAssertTrue(h.session.canDemonstrate)
            XCTAssertNotNil(h.session.beginReplay());h.session.playbackFinished()
            try h.session.retry();XCTAssertTrue(h.session.canAdjust)
            _=try submit(h,success:false)
            XCTAssertEqual(h.session.record?.firstAnswers.first?.id,first.id)
            XCTAssertEqual(h.limiter.questionsUsedToday,0)
            XCTAssertThrowsError(try h.session.next(bank:h.bank))
            XCTAssertEqual(h.session.record?.current.id,question)
            XCTAssertThrowsError(try h.session.start(configuration:.init(freePractice:true),bank:h.bank))
        }
    }
    func testEndedSummaryReviewDoesNotCreateAnotherQuestion() throws {
        for mode in SpatialQuizMode.allCases {
            let h=try harness(mode);defer { h.cleanup() }
            _=try submit(h,success:true)
            let question=h.session.record?.current.id
            try h.session.finish();try h.session.reviewLastQuestion()
            XCTAssertEqual(h.session.record?.phase,.result)
            try h.session.next(bank:h.bank)
            XCTAssertEqual(h.session.record?.phase,.summary)
            XCTAssertEqual(h.session.record?.current.id,question)
            XCTAssertEqual(h.session.record?.firstAnswers.count,1)
            XCTAssertEqual(h.limiter.questionsUsedToday,1)
        }
    }
    func testOrdinaryLastQuestionAndUnlimitedContinuationAreAtomic() throws {
        for mode in SpatialQuizMode.allCases {
            for free in [false,true] {
                let h = try harness(mode,free:free); defer { h.cleanup() }
                // Advance actual first-answer transactions; no fake counter increment.
                for _ in 0..<(free ? 10 : 15) {
                    _ = try submit(h,success:true)
                    XCTAssertEqual(h.session.record?.phase,.result)
                    try h.session.next(bank:h.bank)
                }
                if free {
                    XCTAssertEqual(h.session.record?.totalCount,10)
                    XCTAssertEqual(h.session.record?.phase,.aiming)
                    XCTAssertGreaterThanOrEqual(try h.repo.archive().count,2)
                    XCTAssertEqual(h.limiter.questionsUsedToday,0)
                } else {
                    XCTAssertEqual(h.session.record?.phase,.summary)
                    XCTAssertEqual(h.session.record?.totalCount,15)
                    XCTAssertEqual(h.limiter.questionsUsedToday,15)
                }
            }
        }
    }
    func testPayloadKeepsSpaceFactsAndRejectsCorruptionWithoutDeletingDisk() throws {
        for mode in SpatialQuizMode.allCases {
            let h = try harness(mode); defer { h.cleanup() }
            let shot = try submit(h,success:true)
            let record = try XCTUnwrap(h.session.record)
            let data = try record.encodedPayload()
            let restored = try SpatialQuizRecord.decodePayload(data)
            XCTAssertEqual(restored.latestShot?.facts,shot.facts)
            XCTAssertEqual(restored.latestShot?.physical.paths.keys.sorted(),shot.physical.paths.keys.sorted())
            XCTAssertLessThan(data.count,SpatialQuizRecord.payloadLimit)
            print("SPATIAL_B2_PAYLOAD \(mode.rawValue) bytes=\(data.count) samples=\(shot.physical.paths.values.reduce(0){$0+$1.count})")
            XCTAssertThrowsError(try SpatialQuizRecord.decodePayload(Data([1,2,3])))
            var future = record; future.version = 99; XCTAssertThrowsError(try future.encodedPayload())
            let url=h.repo.root.appendingPathComponent("records.json")
            let bad=Data([0,1,2]);try bad.write(to:url)
            XCTAssertThrowsError(try h.repo.resumable(mode:mode));XCTAssertEqual(try Data(contentsOf:url),bad)
        }
    }
    func testProductionRepositorySeparatesModesAndRollsBackInvalidBatch() throws {
        let suite="SpatialQuizRepository."+UUID().uuidString
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite));defer { defaults.removePersistentDomain(forName:suite) }
        let owner=CurrentOwnerContext(defaults:defaults)
        let context=ModelContext(ModelContainerFactory.makeInMemoryContainer())
        var uploads=0
        let repo=LocalSpatialQuizRepository(context:context,owner:owner,enqueue:{_,_ in uploads += 1})
        var records:[SpatialQuizRecord]=[]
        for mode in SpatialQuizMode.allCases {
            let bank=try SpatialQuizBank.load(mode)
            let record=SpatialQuizRecord(owner:owner.ownerKey,mode:mode,configuration:.init(),bank:bank,questions:Array(bank.questions.prefix(15)))
            try repo.save(record);records.append(record)
            XCTAssertEqual(try repo.resumable(mode:mode)?.id,record.id)
        }
        var modified=records[0];modified.draft.speed=3
        var invalid=records[1];invalid.ownerKey="wrong-owner"
        XCTAssertThrowsError(try repo.saveAtomically([modified,invalid]))
        XCTAssertEqual(try repo.resumable(mode:.masse)?.draft.speed,2)
        XCTAssertEqual(uploads,0)
    }
    func testDuplicateCallbacksAndFailedFreezeNeverCreateAcceptedFacts() throws {
        for mode in SpatialQuizMode.allCases {
            let h = try harness(mode); defer { h.cleanup() }
            h.repo.failNextSave = true
            XCTAssertThrowsError(try h.session.freeze())
            XCTAssertTrue(h.session.canAdjust); XCTAssertEqual(h.limiter.questionsUsedToday,0)
            let shot = try submit(h,success:false)
            let pending = SpatialQuizRecord.Pending(id:shot.id,questionID:shot.questionID,
                input:try XCTUnwrap(h.session.record?.draft),submittedAt:shot.submittedAt,premium:false)
            XCTAssertFalse(h.session.accept(shot,pending:pending))
            XCTAssertEqual(h.session.record?.firstAnswers.count,1)
            XCTAssertFalse(h.session.canDemonstrate)
            try h.session.retry()
            XCTAssertFalse(h.session.accept(shot,pending:pending))
            XCTAssertEqual(h.limiter.questionsUsedToday,1)
        }
    }
    func testLargeSpaceArchiveLimitAndFailedContinuationKeepOriginal() throws {
        for mode in SpatialQuizMode.allCases {
            let h = try harness(mode,free:true); defer { h.cleanup() }
            _ = try submit(h,success:true)
            var record = try XCTUnwrap(h.session.record)
            let latest = try XCTUnwrap(record.latestShot)
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(latest)) as? [String:Any])
            var physical = try XCTUnwrap(object["physical"] as? [String:Any])
            var paths:[String:Any]=[:]
            var random:UInt64=42
            func value()->Double { random = random &* 6364136223846793005 &+ 1; return Double(random >> 11)/Double(UInt64.max >> 11) }
            for key in latest.physical.paths.keys {
                paths[key] = (0..<12_000).map { index -> [String:Any] in
                    ["time":Double(index)/300,"position":["x":value(),"y":value(),"z":value()],
                     "rotation":[value(),value(),value(),value()],"hidden":false]
                }
            }
            physical["paths"]=paths;physical["duration"]=40;object["physical"]=physical
            let huge = try JSONDecoder().decode(SpatialQuizShot.self,from:JSONSerialization.data(withJSONObject:object))
            record.latestShot=huge
            XCTAssertTrue(record.valid)
            XCTAssertThrowsError(try record.encodedPayload())
            // Keep a valid, bounded >512KB archive to exercise size-triggered atomic continuation.
            for key in latest.physical.paths.keys { paths[key] = Array((paths[key] as! [[String:Any]]).prefix(4_000)) }
            physical["paths"]=paths;object["physical"]=physical
            record.latestShot=try JSONDecoder().decode(SpatialQuizShot.self,from:JSONSerialization.data(withJSONObject:object))
            let bytes=try record.encodedPayload().count
            XCTAssertGreaterThan(bytes,512_000);XCTAssertLessThan(bytes,SpatialQuizRecord.payloadLimit)
            try h.repo.save(record)
            let restored=SpatialQuizSession(mode:mode,repository:h.repo,limiter:h.limiter)
            try restored.restore(bank:h.bank)
            h.repo.failNextSave=true
            XCTAssertThrowsError(try restored.next(bank:h.bank))
            XCTAssertEqual(restored.record?.id,record.id);XCTAssertEqual(restored.record?.phase,.result)
            try restored.next(bank:h.bank)
            XCTAssertNotEqual(restored.record?.id,record.id)
            XCTAssertEqual(restored.record?.totalCount,1)
            XCTAssertEqual(restored.record?.logicalSessionID,record.logicalSessionID)
            print("SPATIAL_B2_SIZE_ROLLOVER \(mode.rawValue) bytes=\(bytes)")
        }
    }

}

extension SpatialQuizSessionTests {
    func testV2HistoryKeepsFrozenSuccessButCannotResumeUnderV3() throws {
        for mode in SpatialQuizMode.allCases {
            let h = try harness(mode); defer { h.cleanup() }
            let shot = try submit(h,success:true)
            var old = try XCTUnwrap(h.session.record)
            var legacyFacts = shot.facts; legacyFacts.mode = nil; legacyFacts.technique = nil
            old.judgementVersion = "spatial-quiz-v2"
            old.latestShot = .init(id:shot.id,questionID:shot.questionID,submittedAt:shot.submittedAt,
                physical:shot.physical,facts:legacyFacts,outcome:shot.outcome)
            let answer = try XCTUnwrap(old.firstAnswers.first)
            old.firstAnswers = [.init(id:answer.id,questionID:answer.questionID,input:answer.input,
                facts:legacyFacts,outcome:answer.outcome,receipt:answer.receipt)]
            let restored = try SpatialQuizRecord.decodePayload(old.encodedPayload())
            XCTAssertEqual(restored.latestShot?.outcome,shot.outcome)
            XCTAssertEqual(restored.successCount,1)
            XCTAssertFalse(restored.isCurrentCompatible)
            var unsupported = restored; unsupported.judgementVersion = SpatialQuizJudgement.version
            XCTAssertFalse(unsupported.valid,"Current results must carry the requested technique mode")
            try h.repo.save(old)
            let session = SpatialQuizSession(mode:mode,repository:h.repo,limiter:h.limiter)
            try session.restore(bank:h.bank)
            XCTAssertNil(session.record)
            XCTAssertNotNil(try h.repo.archive()[old.id.uuidString])
        }
    }
}
