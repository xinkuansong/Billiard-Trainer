import XCTest
import SceneKit
import SwiftData
@testable import QiuJi

@MainActor
final class ThreeBallPracticeTests: XCTestCase {
    func testManualPocketFeedbackOnlyAfterAcceptedSelection() throws {
        let (question, _) = try fixture()
        let suite = "ThreeBallSelectionFeedback.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let limiter = AngleUsageLimiter(defaults: defaults, namespace: "feedback", limit: 3)
        let container = try ModelContainer(for: TrainingSession.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let repository = LocalThreeBallPracticeRepository(context: container.mainContext, enqueue: { _,_ in })
        let vm = ThreeBallPracticeViewModel(is3D: false, limiter: limiter, defaults: defaults)
        vm.attach(repository: repository)
        vm.start(.init(), prepared: .init(fingerprint: "test", question: question))
        var count = 0; vm.scene.pocketSelectionHaptic = { count += 1 }
        XCTAssertTrue(vm.canSelectPocket)
        vm.selectPocket(at: 2); vm.selectPocket(at: 2)
        XCTAssertEqual(count, 2)
        XCTAssertEqual(vm.record?.current?.plannedPocket, 2)
        vm.selectPocket(at: 99); XCTAssertEqual(count, 2)
        vm.openSettings(); vm.selectPocket(at: 3)
        XCTAssertEqual(count, 2)
        XCTAssertEqual(vm.record?.current?.plannedPocket, 2)
    }

    func testUnplayableContinuationEndsAtZeroAndRetryPreservesFirstAnswer() throws {
        let (source, prediction) = try fixture()
        var rejected: [Int] = []
        for pocket in 0..<6 {
            var q = source; q.plannedPocket = pocket
            let shot = try ThreeBallShot(question: q, input: .init(), prediction: prediction, surfaceY: BTTablePhysics.surfaceY)
            guard shot.failure == TrainingPracticeNotice.noDirectRoute else { continue }
            rejected.append(pocket)
            XCTAssertEqual(shot.freeScore, 0)
            XCTAssertEqual(shot.resultText, "0分，无法进指定袋，请重打")
            var record = ThreeBallPracticeRecord(ownerKey: "test", is3D: false, configuration: .init(),
                prepared: .init(fingerprint: "test", question: q))
            record.accept(shot)
            XCTAssertFalse(record.canAdvanceStage)
            XCTAssertTrue(record.questionComplete)
            XCTAssertEqual(record.averageScore, 0)
            record = try ThreeBallPracticeRecord.decodePayload(record.encodedPayload())
            record.retryLastStroke()
            XCTAssertEqual(record.current?.stage, 0)
            XCTAssertEqual(record.current?.board.cue.x, source.board.cue.x)
            XCTAssertEqual(record.current?.plannedPocket, pocket)
            XCTAssertFalse(record.showingResult)
            XCTAssertEqual(record.attempts.count, 1)
            XCTAssertEqual(record.consumed.count, 1)
        }
        XCTAssertFalse(rejected.isEmpty)
        print("NOTICE_REJECTED_POCKETS \(rejected)")
    }

    func testRecoverableNoticesDoNotSwallowSimulationOrStorageErrors() throws {
        XCTAssertNotNil(TrainingPracticeNotice.recoverable(SeparationQuestionGenerator.Failure.noDirectRoute))
        XCTAssertNotNil(TrainingPracticeNotice.recoverable(SeparationQuestionGenerator.Failure.inaccessible))
        XCTAssertFalse(try XCTUnwrap(TrainingPracticeNotice.recoverable(
            SeparationQuestionGenerator.Failure.inaccessible, reference: true)).text.contains("0分"))
        XCTAssertNil(TrainingPracticeNotice.recoverable(SeparationQuestionGenerator.Failure.incomplete))
        XCTAssertNil(TrainingPracticeNotice.recoverable(CocoaError(.fileWriteOutOfSpace)))
        XCTAssertNil(TrainingPracticeNotice.recoverable(CancellationError()))
        let q = try XCTUnwrap(ThreeBallBank.load().questions.first)
        let target = q.board.target.vector
        let aim = q.board.effectiveAim.vector
        let direction = SCNVector3(aim.x-target.x, 0, aim.z-target.z)
        let cue = SCNVector3(target.x+direction.x*0.4, target.y, target.z+direction.z*0.4)
        let board = ThreeBallQuestionPreparer.board(id: "impossible", cue: cue, target: target, pocket: q.board.pocketIndex)
        XCTAssertThrowsError(try SeparationQuestionGenerator.solve(board: board, input: .init(),
            surfaceY: BTTablePhysics.surfaceY, profile: AccuracyTipSelector.renderedProfile())) { error in
            guard case SeparationQuestionGenerator.Failure.noDirectRoute = error else {
                return XCTFail("Expected route rejection, got \(error)")
            }
        }
    }

    func testThreeSecondNoticeTimerAndOldTimerCannotClearReplacement() async throws {
        let center = BTRuleNoticeCenter()
        center.show("first", tone: .info, priority: .ruling)
        try await Task.sleep(for: .milliseconds(2000))
        XCTAssertEqual(center.message?.text, "first")
        center.show(TrainingPracticeNotice.cannotPot, tone: .info, priority: .ruling)
        try await Task.sleep(for: .milliseconds(1250))
        XCTAssertEqual(center.message?.text, TrainingPracticeNotice.cannotPot)
        try await Task.sleep(for: .milliseconds(1900))
        XCTAssertNil(center.message)
        XCTAssertNotEqual(TrainingPracticeNotice(text: "same"), TrainingPracticeNotice(text: "same"))
    }

    private func fixture() throws -> (ThreeBallQuestion, ShotPrediction) {
        let bank = try ThreeBallBank.load()
        for var q in bank.questions.prefix(30) {
            q.plannedPocket = 5
            let p = try ThreeBallQuestionPreparer.solve(question: q, input: .init(),
                surfaceY: BTTablePhysics.surfaceY, profile: AccuracyTipSelector.renderedProfile())
            if ThreeBallQuestionPreparer.failure(p, pocket: q.board.pocketIndex) == nil { return (q,p) }
        }
        throw ThreeBallBank.Failure.unavailable
    }
    func testBankSourceAndAllFilters() throws {
        let bank = try ThreeBallBank.load()
        XCTAssertEqual(bank.fingerprint, try ThreeBallBank.currentFingerprint())
        XCTAssertEqual(bank.questions.count, 111025)
        XCTAssertEqual(Set(bank.questions.map(\.contentID)).count, bank.questions.count)
        for q in bank.questions {
            XCTAssertEqual(q.stage, 0); XCTAssertNil(q.plannedPocket)
            XCTAssertTrue(q.third?.isFinite == true)
            XCTAssertNotEqual(q.ballNumber, q.secondBallNumber)
            XCTAssertEqual(q.ballNumber > 8, q.secondBallNumber > 8)
            XCTAssertEqual(q.thirdBallNumber, 8)
        }
        var c = SceneTrainingConfiguration(); c.angleSelection = [.small]
        for _ in 0..<20 { XCTAssertTrue(try bank.draw(c, excluding: []).board.matches(c)) }
        XCTAssertThrowsError(try bank.draw(c, excluding: Set(bank.questions.map(\.contentID))))
    }
    func testPreselectionFreezeTrueContinuationAndMean() throws {
        let (q,p) = try fixture()
        let prepared = ThreeBallQuestionPreparer.Prepared(fingerprint: "test", question: q)
        var record = ThreeBallPracticeRecord(ownerKey: "test", is3D: false, configuration: .init(), prepared: prepared)
        let shot = try ThreeBallShot(question: q, input: .init(), prediction: p, surfaceY: BTTablePhysics.surfaceY)
        record.accept(shot); record.showingResult = true
        XCTAssertEqual(record.attempts.count, 1); XCTAssertEqual(record.consumed.count, 1)
        XCTAssertNil(record.questionAverage); XCTAssertTrue(record.canAdvanceStage)
        record.selectPocket(0); XCTAssertEqual(record.current?.plannedPocket, 5)
        record.accept(shot); XCTAssertEqual(record.attempts.count, 1)
        try record.advanceStage()
        let next = try XCTUnwrap(record.current)
        XCTAssertEqual(next.stage, 1); XCTAssertNil(next.plannedPocket); XCTAssertNil(next.third)
        XCTAssertEqual(next.identity, q.identity)
        XCTAssertEqual(next.ballNumber, q.secondBallNumber); XCTAssertEqual(next.secondBallNumber, 8)
        XCTAssertEqual(next.board.pocketIndex, 5)
        XCTAssertEqual(next.board.cue.x, p.finalPositions[ShotInput.cueBallName]?.x)
        XCTAssertEqual(next.board.target.z, p.finalPositions[ThreeBallQuestionPreparer.secondBallName]?.z)
        XCTAssertEqual(next.second.x, p.finalPositions[ThreeBallQuestionPreparer.thirdBallName]?.x)
        record.selectPocket(1)
        let secondQ = try XCTUnwrap(record.current)
        let secondP = try ThreeBallQuestionPreparer.solve(question: secondQ, input: .init(),
            surfaceY: BTTablePhysics.surfaceY, profile: AccuracyTipSelector.renderedProfile())
        let second = try ThreeBallShot(question: secondQ, input: .init(), prediction: secondP, surfaceY: BTTablePhysics.surfaceY)
        record.accept(second); record.showingResult = true
        XCTAssertEqual(record.questionAverage, (shot.freeScore + second.freeScore)/2)
        XCTAssertEqual(record.averageScore, (shot.freeScore + second.freeScore)/2)
        XCTAssertEqual(record.consumed.count, 1); XCTAssertEqual(record.attempts.count, 2)
        let decoded = try ThreeBallPracticeRecord.decodePayload(record.encodedPayload())
        XCTAssertTrue(decoded.isCompatible); XCTAssertEqual(decoded.current?.plannedPocket, 1)
        XCTAssertEqual(decoded.firstStageScore, shot.freeScore)
        XCTAssertEqual(decoded.current?.identity, q.identity)
        XCTAssertEqual(decoded.latestShot?.secondPocket, 1)
        XCTAssertEqual(decoded.latestShot?.frames.keys.sorted(), second.frames.keys.sorted())
    }
    func testMissingPocketCannotSubmitAndRetryCannotRewriteFirstAnswer() throws {
        let (selected,p) = try fixture(); var q = selected; q.plannedPocket = nil
        XCTAssertThrowsError(try ThreeBallShot(question: q, input: .init(), prediction: p, surfaceY: BTTablePhysics.surfaceY))
        var record = ThreeBallPracticeRecord(ownerKey: "test", is3D: true, configuration: .init(),
            prepared: .init(fingerprint: "test", question: selected))
        let first = try ThreeBallShot(question: selected, input: .init(), prediction: p, surfaceY: BTTablePhysics.surfaceY)
        let retry = try ThreeBallShot(question: selected, input: .init(), prediction: p, surfaceY: BTTablePhysics.surfaceY)
        record.accept(first); record.accept(retry)
        XCTAssertEqual(record.attempts.count, 1); XCTAssertEqual(record.attempts.first?.id, first.id)
        XCTAssertEqual(record.latestShot?.id, retry.id); XCTAssertEqual(record.consumed.count, 1)
        record.selectPocket(0); XCTAssertEqual(record.current?.plannedPocket, 5)
    }
    func testIdenticalComfortFormulaAndThirdBallObstruction() throws {
        let (_,p) = try fixture()
        let cue = try XCTUnwrap(p.finalPositions[ShotInput.cueBallName])
        let target = try XCTUnwrap(p.finalPositions[ThreeBallQuestionPreparer.secondBallName])
        for pocket in 0..<6 {
            let expected = TwoBallComfortScore.evaluateFreePosition(cue: (Double(cue.x),Double(cue.z)),
                ball: (Double(target.x),Double(target.z)), pocket: pocket)?.total ?? 0
            XCTAssertEqual(ThreeBallQuestionPreparer.score(cue: cue, target: target, pocket: pocket,
                obstacle: nil, surfaceY: BTTablePhysics.surfaceY), expected, accuracy: 1e-10)
        }
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: 5, surfaceY: BTTablePhysics.surfaceY)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: aim, ballRadius: BallPhysics.radius)
        let obstacle = SCNVector3((cue.x+ghost.x)/2, cue.y, (cue.z+ghost.z)/2)
        XCTAssertEqual(ThreeBallQuestionPreparer.score(cue: cue, target: target, pocket: 5,
            obstacle: obstacle, surfaceY: BTTablePhysics.surfaceY), 0)

    }
    func testRepositoryOwnerQuotaAndRoundTrip() throws {
        let (q,p) = try fixture()
        let container = try ModelContainer(for: TrainingSession.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let repository = LocalThreeBallPracticeRepository(context: container.mainContext, enqueue: { _,_ in })
        var record = ThreeBallPracticeRecord(ownerKey: repository.ownerKey, is3D: false, configuration: .init(),
            prepared: .init(fingerprint: "test", question: q))
        record.accept(try ThreeBallShot(question: q, input: .init(), prediction: p, surfaceY: BTTablePhysics.surfaceY))
        record.showingResult = true
        try repository.save(record)
        XCTAssertEqual(try repository.resumable(is3D: false)?.current?.plannedPocket, 5)
        XCTAssertEqual(try repository.resumable(is3D: true)?.current?.plannedPocket, 5)
        let sessions = try container.mainContext.fetch(FetchDescriptor<TrainingSession>())
        XCTAssertEqual(sessions.first?.kind, TrainingSessionKind.threeBallPractice)
        XCTAssertEqual(HistoryViewModel.assembleThreeBallSessions(sessions: sessions).records.count, 1)
        let suite = "threeball-test-\(UUID())", defaults = UserDefaults(suiteName: "threeball-test-temp")!
        defer { defaults.removePersistentDomain(forName: "threeball-test-temp") }
        let limiter = AngleUsageLimiter(defaults: defaults, namespace: suite)
        for _ in 0..<2 { for (id,date) in record.consumed { limiter.recordQuestion(attemptID: id, submittedAt: date) } }
        XCTAssertEqual(limiter.questionsUsedToday, 1)
    }
    func testOwnerTransferAndRollbackPreserveBothStageIntents() throws {
        let (q,p) = try fixture()
        let suite = "threeball-owner-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let owner = CurrentOwnerContext(defaults: defaults), source = owner.ownerKey
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let repo = LocalThreeBallPracticeRepository(context: context, owner: owner, enqueue: { _,_ in })
        var record = ThreeBallPracticeRecord(ownerKey: source, is3D: true, configuration: .init(),
            prepared: .init(fingerprint: "test", question: q))
        record.accept(try ThreeBallShot(question: q, input: .init(), prediction: p, surfaceY: BTTablePhysics.surfaceY))
        record.showingResult = true
        try record.advanceStage(); record.selectPocket(1); try repo.save(record)
        let destination = OwnerKey.account("three-ball-transfer")
        XCTAssertThrowsError(try OwnerTransferService(context: context, saveAction: { _ in
            throw CocoaError(.fileWriteOutOfSpace)
        }).transfer(from: source, to: destination))
        XCTAssertEqual(try repo.resumable(is3D: true)?.ownerKey, source)
        XCTAssertEqual(try OwnerTransferService(context: context).transfer(from: source, to: destination).sessions, 1)
        owner.useAccount(userID: "three-ball-transfer")
        let restored = try XCTUnwrap(repo.resumable(is3D: true))
        XCTAssertEqual(restored.current?.plannedPocket, 1)
        XCTAssertEqual(restored.current?.board.pocketIndex, 5)
        XCTAssertEqual(restored.attempts.first?.pocket, 5)
    }

    func testEverySameGroupPairAndOrderIsFrozenInQuestion() throws {
        let (source, _) = try fixture()
        for first in 1...7 {
            for second in 1...7 where first != second {
                for stripes in [false, true] {
                    var q = source
                    q.identity = .init(solid: first, stripedFirst: stripes, secondInGroup: second)
                    let decoded = try JSONDecoder().decode(ThreeBallQuestion.self, from: JSONEncoder().encode(q))
                    XCTAssertEqual(decoded.identity, q.identity)
                    XCTAssertEqual(decoded.ballNumber, first + (stripes ? 8 : 0))
                    XCTAssertEqual(decoded.secondBallNumber, second + (stripes ? 8 : 0))
                    XCTAssertNotEqual(decoded.ballNumber, decoded.secondBallNumber)
                    XCTAssertEqual(decoded.ballNumber > 8, decoded.secondBallNumber > 8)
                    XCTAssertEqual(decoded.thirdKey, "_8")
                    var next = decoded; next.stage = 1; next.third = nil
                    XCTAssertEqual(next.ballNumber, decoded.secondBallNumber); XCTAssertEqual(next.secondKey, "_8")
                    XCTAssertEqual(next.board.cue.x, source.board.cue.x)
                    XCTAssertEqual(next.second.z, source.second.z)
                }
            }
        }
        for second in [0, 1, 8] {
            var invalid = source; invalid.identity = .init(solid: 1, stripedFirst: false, secondInGroup: second)
            let record = ThreeBallPracticeRecord(ownerKey: "test", is3D: false, configuration: .init(),
                prepared: .init(fingerprint: "test", question: invalid))
            XCTAssertFalse(record.isCompatible)
        }
    }

    func testRandomIdentityNeverMixesGroupsAndPreservesLegacyHistory() throws {
        var groups: Set<Bool> = []
        for _ in 0..<1000 {
            let identity = ThreeBallBallIdentity.random()
            groups.insert(identity.first > 8)
            XCTAssertTrue(identity.isValid)
            XCTAssertNotNil(identity.secondInGroup)
            XCTAssertNotEqual(identity.first, identity.second)
            XCTAssertEqual(identity.first > 8, identity.second > 8)
            XCTAssertNotEqual(identity.first, 8); XCTAssertNotEqual(identity.second, 8)
        }
        XCTAssertEqual(groups, [false, true])
        let old = try JSONDecoder().decode(ThreeBallBallIdentity.self,
            from: Data(#"{"solid":3,"stripedFirst":true}"#.utf8))
        XCTAssertEqual(old.first, 11); XCTAssertEqual(old.second, 3)
        XCTAssertEqual(try JSONDecoder().decode(ThreeBallBallIdentity.self, from: JSONEncoder().encode(old)), old)
        XCTAssertNotEqual(ThreeBallBank.appearancePolicy, "matching-pair-black8-v1")
    }

    func testRetryAcrossAutomaticStagePreservesPlanPosesAndFirstAnswer() throws {
        let (q,p) = try fixture()
        var record = ThreeBallPracticeRecord(ownerKey: "test", is3D: false, configuration: .init(),
            prepared: .init(fingerprint: "test", question: q))
        record.initialPoses = ["_white": [0,0,0,1]]
        let shot = try ThreeBallShot(question: q, input: .init(), prediction: p, surfaceY: BTTablePhysics.surfaceY)
        record.accept(shot)
        try record.advanceStage()
        record.selectPocket(2)
        record = try ThreeBallPracticeRecord.decodePayload(record.encodedPayload())
        XCTAssertTrue(record.canRetryPreviousStage)
        XCTAssertEqual(record.current?.board.pocketIndex, 5)
        record.retryLastStroke()
        XCTAssertEqual(record.current?.stage, 0)
        XCTAssertEqual(record.current?.plannedPocket, 5)
        XCTAssertEqual(record.current?.board.cue.x, q.board.cue.x)
        XCTAssertEqual(record.initialPoses["_white"], [0,0,0,1])
        XCTAssertFalse(record.plannedPocketLocked)
        record.selectPocket(2)
        XCTAssertEqual(record.current?.plannedPocket, 2)
        let retry = try ThreeBallShot(question: XCTUnwrap(record.current), input: .init(), prediction: p, surfaceY: BTTablePhysics.surfaceY)
        record.accept(retry)
        XCTAssertEqual(record.attempts.count, 1)
        XCTAssertEqual(record.attempts.first?.pocket, 5)
        XCTAssertEqual(record.attempts.first?.score, shot.freeScore)
        try record.advanceStage()
        XCTAssertEqual(record.current?.board.pocketIndex, 2)
        XCTAssertEqual(record.firstStageScore, retry.freeScore)
        XCTAssertEqual(record.consumed.count, 1)
    }

    func testPracticePocketRolesArePersistentAndShareBothColours() throws {
        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: false)
        let markers = scene.addPocketMarkers().compactMap { $0 as? PocketLeatherMarker }
        XCTAssertEqual(markers.count, 6)
        scene.setPracticePocketRoles(current: 0, next: 2)
        XCTAssertEqual(markers[0].style, .practiceCurrent)
        XCTAssertEqual(markers[2].style, .continuationTarget)
        scene.cancelPocketSelectionFeedback()
        XCTAssertEqual(markers[0].style, .practiceCurrent)
        scene.setPracticePocketRoles(current: 2, next: 2)
        XCTAssertEqual(markers[2].style, .practiceBoth)
        let both = try XCTUnwrap(markers[2].childNodes.first { $0.name == "leather_practiceBoth" })
        XCTAssertFalse(both.isHidden)
        XCTAssertEqual(both.geometry?.materials.count, 2)
        XCTAssertEqual(markers[0].style, .original)
    }

}
