import XCTest
import SceneKit
import SwiftData
@testable import QiuJi

final class BankPracticeTests: XCTestCase {
    func testSelectedBankDemonstrationRebuildsRealShot() throws {
        var accepted = 0
        for pocket: BankPocketType? in [nil, .middle, .corner] {
            for rails in 1...3 {
                var configuration = BankConfiguration()
                configuration.railCount = rails
                configuration.pocketType = pocket
                let question = try BankQuestionPreparer.prepare(configuration, seed: 31).question
                let reference = try BankQuestionPreparer.solve(question: question, input: question.source.input,
                    direction: question.source.direction.vector, surfaceY: BTTablePhysics.surfaceY,
                    profile: AccuracyTipSelector.renderedProfile())
                let expected = try BankShot(question: question, input: question.source.input, prediction: reference, surfaceY: BTTablePhysics.surfaceY)
                if let failure = expected.failure {
                    XCTAssertThrowsError(try question.demonstrationShot(surfaceY: BTTablePhysics.surfaceY)) { error in
                        XCTAssertTrue(error.localizedDescription.contains(failure.rawValue))
                    }
                } else {
                    let demo = try question.demonstrationShot(surfaceY: BTTablePhysics.surfaceY)
                    XCTAssertEqual(demo.input, question.source.input)
                    XCTAssertNil(demo.failure)
                    accepted += 1
                    print("BANK_DEMONSTRATION_ACCEPTED", rails, pocket?.rawValue ?? "all", question.source.id)
                }
            }
        }
        XCTAssertGreaterThan(accepted, 0)
    }

    func testBankReferenceWithMidRouteJawIsRejected() throws {
        let bank = try BankPracticeBankStore.load()
        let source = try XCTUnwrap(bank.questions.first { $0.id == "bank-v1-C-W3-R43-3-T1-C24-S3" })
        let question = BankQuestion(id: UUID(), source: source)
        XCTAssertThrowsError(try question.demonstrationShot(surfaceY: BTTablePhysics.surfaceY)) { error in
            XCTAssertTrue(error.localizedDescription.contains(BankJudgement.Failure.jaw.rawValue))
        }
    }

    func testDemonstrationUnlockUsesDistinctCompletedShotsAndSurvivesResume() throws {
        let prepared = try BankQuestionPreparer.prepare(.init(), seed: 31)
        var record = BankPracticeRecord(ownerKey: "test", is3D: false, configuration: .init(), prepared: prepared)
        let first = try syntheticShot(prepared.question, success: false)
        record.accept(first); record.accept(first)
        XCTAssertFalse(record.demonstrationUnlocked)
        record.accept(try syntheticShot(prepared.question, success: false))
        record = try BankPracticeRecord.decodePayload(record.encodedPayload())
        XCTAssertFalse(record.demonstrationUnlocked)
        var early = BankPracticeRecord(ownerKey: "test", is3D: false, configuration: .init(), prepared: prepared)
        early.accept(try syntheticShot(prepared.question, success: true))
        XCTAssertTrue(early.demonstrationUnlocked)
        record.accept(try syntheticShot(prepared.question, success: false))
        XCTAssertTrue(record.demonstrationUnlocked)
        XCTAssertEqual(record.attempts.count, 1)
    }

    func testFullBankCoverageAndStratifiedReferencesPassProductionConsumer() throws {
        let started = Date()
        let bank = try BankPracticeBankStore.load()
        print("BANK_LOAD_SECONDS=\(Date().timeIntervalSince(started))")
        XCTAssertEqual(bank.questions.count, 21_569)
        let counts = Dictionary(grouping: bank.questions) { "\($0.walls.count)-\($0.pocketType.rawValue)" }.mapValues(\.count)
        XCTAssertEqual(counts, ["1-middle": 2634, "2-middle": 1373, "3-middle": 987,
                                "1-corner": 9164, "2-corner": 4846, "3-corner": 2565])
        // Every pocket × rail count × original/perturbation × mirror direction.
        // The source ID's -P token and -S suffix are provenance, never shot parameters.
        let strata = Dictionary(grouping: bank.questions) { source in
            "\(source.walls.count)-\(source.pocket)-\(source.id.contains("-P"))-\(source.id.suffix(2))"
        }
        XCTAssertEqual(strata.count, 36)
        var samples: [BankPracticeBankQuestion] = []
        for key in strata.keys.sorted() {
            let rows = strata[key]!.sorted { $0.id < $1.id }
            samples += (0..<10).map { rows[$0 * (rows.count - 1) / 9] }
        }
        XCTAssertEqual(samples.count, 360)
        print("BANK_REFERENCE_REPLAYS=\(samples.count)")
        for source in samples {
            try autoreleasepool {
                let question = BankQuestion(id: UUID(), source: source)
                let prediction = try BankQuestionPreparer.solve(question: question, input: source.input,
                    direction: source.direction.vector, surfaceY: BTTablePhysics.surfaceY,
                    profile: AccuracyTipSelector.renderedProfile())
                let shot = try BankShot(question: question, input: source.input,
                    prediction: prediction, surfaceY: BTTablePhysics.surfaceY)
                XCTAssertNil(shot.failure, source.id + ": " + shot.judgement.failures.map(\.rawValue).joined(separator: ","))
                XCTAssertEqual(shot.judgement.actualSegments, source.railSegments, source.id)
                XCTAssertGreaterThan(shot.objectTrajectory.count, 1, source.id)
                let restored = shot.prediction()
                XCTAssertEqual(BankJudgement.evaluate(restored, question: source, surfaceY: BTTablePhysics.surfaceY).failures, [])
            }
        }
    }

    func testStrictTargetRouteRejectsFewerExtraWrongOrderAndWrongPocket() throws {
        let source = try XCTUnwrap(BankPracticeBankStore.load().questions.first { $0.walls.count == 3 })
        let cue = ShotInput.cueBallName, target = ShotInput.targetBallName
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: BTTablePhysics.surfaceY)
        let hit = ShotEvent(time: 1, kind: .ballBall(ballA: cue, ballB: target))
        let rails = source.railSegments.enumerated().map { ShotEvent(time: Float($0.offset + 2), kind: .ballCushion(ball: target), cushionIndex: $0.element) }
        let pot = ShotEvent(time: 10, kind: .pocket(ball: target, pocketId: geometry.pockets[source.pocket].id))
        func result(_ events: [ShotEvent], complete: Bool = true) -> [BankJudgement.Failure] {
            var prediction = ShotPrediction()
            prediction.events = events; prediction.recorder = TrajectoryRecorder()
            prediction.termination = complete ? .settled : .timeLimit
            return BankJudgement.evaluate(prediction, question: source, surfaceY: BTTablePhysics.surfaceY).failures
        }
        XCTAssertEqual(result([hit] + rails + [pot]), [])
        XCTAssertTrue(result([hit, pot]).contains(.railCount))
        XCTAssertTrue(result([hit] + rails.dropLast() + [pot]).contains(.railCount))
        XCTAssertTrue(result([hit] + rails + [rails[0], pot]).contains(.railCount))
        var wrong = rails
        wrong[0] = .init(time: 2, kind: .ballCushion(ball: target), cushionIndex: (source.railSegments[0] + 1) % 6)
        XCTAssertTrue(result([hit] + wrong + [pot]).contains(.railOrder))
        XCTAssertTrue(result([hit] + rails + [.init(time: 10, kind: .pocket(ball: target, pocketId: geometry.pockets[(source.pocket + 1) % 6].id))]).contains(.pocket))
        XCTAssertTrue(result([.init(time: 0, kind: .ballCushion(ball: cue), cushionIndex: 0), hit] + rails + [pot]).contains(.firstContact))
        XCTAssertTrue(result([hit, hit] + rails + [pot]).contains(.secondContact))
        XCTAssertEqual(result([hit] + rails + [pot, .init(time: 20, kind: .pocket(ball: cue, pocketId: "pocket_0"))]).first, .scratch)
        XCTAssertTrue(result([hit, .init(time: 1.5, kind: .ballCushion(ball: target), cushionIndex: 6)] + rails + [pot]).contains(.jaw))
        XCTAssertEqual(result([hit] + rails + [pot], complete: false), [.incomplete])
        // Cue-ball rails must never count as object-ball rails.
        let cueRails = rails.map { ShotEvent(time: $0.time, kind: .ballCushion(ball: cue), cushionIndex: $0.cushionIndex) }
        XCTAssertTrue(result([hit] + cueRails + [pot]).contains(.railCount))
    }

    func testFiltersStableIdentityInitialAimAndRoundTrip() throws {
        for pocket in BankPocketType.allCases {
            for count in BankConfiguration.availableRailCounts {
                var configuration = BankConfiguration(); configuration.pocketType = pocket; configuration.railCount = count
                let prepared = try BankQuestionPreparer.prepare(configuration, seed: 7)
                let question = prepared.question
                XCTAssertEqual(question.source.pocketType, pocket)
                XCTAssertEqual(question.source.walls.count, count)
                XCTAssertTrue(question.contentID.hasPrefix("bank-v1-"))
                let delta = question.source.target.vector - question.source.cue.vector
                let direction = question.initialDirection.vector
                XCTAssertEqual(direction.x * delta.z - direction.z * delta.x, 0, accuracy: 0.000001)
                XCTAssertGreaterThan(direction.dot(delta), 0)
                let record = BankPracticeRecord(ownerKey: "test", is3D: false, configuration: configuration, prepared: prepared)
                let restored = try BankPracticeRecord.decodePayload(record.encodedPayload())
                XCTAssertEqual(restored.current?.source, question.source)
                XCTAssertTrue(restored.canResumeCurrentTraining)
                XCTAssertEqual(restored.draftDirection, question.initialDirection)
            }
        }
    }
    func testOldBankHistoryRemainsReadableButCannotResumeAndDraftDropsFourRails() throws {
        var configuration = BankConfiguration()
        configuration.railCount = 4; configuration.pocketType = .corner
        configuration.showsRailColors = false
        let draft = configuration.forCurrentBank
        XCTAssertNil(draft.railCount)
        XCTAssertEqual(draft.pocketType, .corner)
        XCTAssertFalse(draft.showsRailColors)
        XCTAssertEqual(configuration.railCount, 4)
        // Actual four-rail r2 content, retained only as a historical decoding fixture.
        let legacy = try JSONDecoder().decode(BankPracticeBankQuestion.self, from: Data(#"{"id":"bank-r2-C4-01","revision":"r2-20261101","cue":{"x":0.3294495940208435,"z":-0.48940935730934143},"target":{"x":0.6071797609329224,"z":-0.07326504588127136},"walls":[1,3,0,2],"railSegments":[5,1,4,2],"pocket":3,"pocketType":"corner","direction":{"x":0.5045340657234192,"z":0.8633917570114136},"input":{"spinX":0,"spinY":0,"velocity":4.800000190734863}}"#.utf8))
        let prepared = BankQuestionPreparer.Prepared(fingerprint: "af536fcd57f51d274a2141c683c60e0d312c1463d0f6d719924b0a16908ac99f",
            question: BankQuestion(id: UUID(), source: legacy))
        var old = BankPracticeRecord(ownerKey: "history", is3D: false, configuration: configuration, prepared: prepared)
        old.accept(try syntheticShot(prepared.question, success: true))
        let restored = try BankPracticeRecord.decodePayload(old.encodedPayload())
        XCTAssertTrue(restored.isCompatible)
        XCTAssertFalse(restored.canResumeCurrentTraining)
        XCTAssertEqual(restored.successCount, 1)
        XCTAssertEqual(restored.configuration.railCount, 4)
    }

    func testFirstAnswerFrozenRetryAndPayloadRoundTrip() throws {
        let prepared = try BankQuestionPreparer.prepare(.init(), seed: 31)
        var record = BankPracticeRecord(ownerKey: "test", is3D: false, configuration: .init(), prepared: prepared)
        let failed = try syntheticShot(prepared.question, success: false)
        let success = try syntheticShot(prepared.question, success: true)
        record.accept(failed); record.accept(success); record.accept(success)
        XCTAssertEqual(record.attempts.count, 1); XCTAssertEqual(record.successCount, 0)
        XCTAssertEqual(record.latestShot?.id, success.id)
        let restored = try BankPracticeRecord.decodePayload(record.encodedPayload())
        XCTAssertTrue(restored.canResumeCurrentTraining)
        XCTAssertEqual(restored.draftDirection, success.direction)
        XCTAssertEqual(restored.latestShot?.id, success.id)
        XCTAssertFalse(TrainingSessionKind.countsTowardAccuracy(TrainingSessionKind.bankPractice))
    }
    @MainActor func testDirectionSettingsCancelViewSwitchAndOwnerIsolation() throws {
        let suite = "BankPracticeTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let limiter = AngleUsageLimiter(defaults: defaults, namespace: suite, limit: 15)
        limiter.isPremium = true
        let prepared = try BankQuestionPreparer.prepare(.init(), seed: 31)
        let repo = MemoryBankRepository()
        let vm = BankPracticeViewModel(is3D: false, limiter: limiter, defaults: defaults)
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
    @MainActor func testRepositoryHistoryAndAtomicOwnerRollback() throws {
        let suite = "BankRepositoryTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let owner = CurrentOwnerContext(defaults: defaults)
        let context = ModelContext(ModelContainerFactory.makeInMemoryContainer())
        let repository = LocalBankPracticeRepository(context: context, owner: owner, enqueue: { _, _ in })
        let prepared = try BankQuestionPreparer.prepare(.init(), seed: 31)
        var record = BankPracticeRecord(ownerKey: owner.ownerKey, is3D: false, configuration: .init(), prepared: prepared)
        record.accept(try syntheticShot(prepared.question, success: true)); try repository.save(record)
        var changed = record; changed.activeSeconds = 120
        var invalid = record.continuation(prepared: prepared); invalid.ownerKey = "different"
        XCTAssertThrowsError(try repository.saveAtomically([changed, invalid]))
        XCTAssertEqual(try repository.resumable(is3D: true)?.activeSeconds, 0)
        let sessions = try context.fetch(FetchDescriptor<TrainingSession>())
        XCTAssertEqual(HistoryViewModel.assembleBankSessions(sessions: sessions).records.count, 1)
        sessions[0].sourcePayloadSnapshot = Data("broken".utf8)
        XCTAssertThrowsError(try repository.resumable(is3D: false))
        XCTAssertEqual(HistoryViewModel.assembleBankSessions(sessions: sessions).unreadableCount, 1)
    }
    @MainActor func testOwnerTransferRollsBackCompressedPayloadAndRemapsOnSuccess() throws {
        let suite = "BankTransferTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let owner = CurrentOwnerContext(defaults: defaults)
        let context = ModelContext(ModelContainerFactory.makeInMemoryContainer())
        let repo = LocalBankPracticeRepository(context: context, owner: owner, enqueue: { _, _ in })
        let prepared = try BankQuestionPreparer.prepare(.init(), seed: 31)
        var record = BankPracticeRecord(ownerKey: owner.ownerKey, is3D: false, configuration: .init(), prepared: prepared)
        record.accept(try syntheticShot(prepared.question, success: true)); try repo.save(record)
        let source = owner.ownerKey, destination = OwnerKey.account("bank-transfer")
        enum SaveFailure: Error { case rejected }
        XCTAssertThrowsError(try OwnerTransferService(context: context, saveAction: { _ in throw SaveFailure.rejected })
            .transfer(from: source, to: destination))
        XCTAssertEqual(try repo.resumable(is3D: true)?.ownerKey, source)
        XCTAssertEqual(try OwnerTransferService(context: context).transfer(from: source, to: destination).sessions, 1)
        owner.useAccount(userID: "bank-transfer")
        XCTAssertEqual(try repo.resumable(is3D: true)?.ownerKey, destination)
        XCTAssertEqual(try repo.resumable(is3D: false)?.successCount, 1)
    }
    func testOwnPreferenceLayoutAndQuotaIdentity() {
        XCTAssertEqual(TrainingProject.from(route: "bankPractice3D"), .bank)
        XCTAssertEqual(TablePreferencePage.bankPractice2D.trainingProject, .bank)
        XCTAssertTrue(FreeControlCatalog.ids(page: .bankPractice2D, mode: .twoD).contains("shot.aim"))
        XCTAssertFalse(FreeControlCatalog.ids(page: .bankPractice2D, mode: .threeD).contains("shot.aim"))
        XCTAssertNotEqual(TrainingProject.bank.page2D, TrainingProject.kBall.page2D)
    }
    @MainActor func testMeasurementStartsAtTargetAndUsesFirstSegmentMidpoint() throws {
        let scene = AngleTrainingScene()
        let tool = GeometricReferenceTool(scene: scene)
        let target = SCNVector3(0.1, 0.5, 0.2)
        for segment in 0..<6 {
            tool.updateForBank(identity: "bank-\(segment)", target: target, firstSegment: segment)
            tool.select(2)
            XCTAssertEqual(tool.points.first, GeometricRailReference.point(target))
            let rail = GeometricRailReference.rails[segment]
            let midpoint = (rail.start + rail.end) / 2
            let first = try XCTUnwrap(tool.draft.first)
            XCTAssertEqual(first.x, midpoint.x, accuracy: 0.000001)
            XCTAssertEqual(first.y, midpoint.y, accuracy: 0.000001)
            tool.freeze(); tool.complete(); tool.restore()
            XCTAssertEqual(tool.draft.first, first)
        }
    }
    func testRailNamesDistinguishAllSixSegmentsInBothOrientations() {
        for orientation in PocketDisplay.Orientation.allCases {
            XCTAssertEqual(Set((0..<6).map { BankRailDisplay.name(segment: $0, orientation: orientation) }).count, 6)
        }
    }
    func testSelectionNeverImmediatelyRepeatsWhenRecentWindowCoversSample() throws {
        var config = BankConfiguration(); config.railCount = 1; config.pocketType = .middle
        let bank = try BankPracticeBankStore.load()
        let last = try BankQuestionPreparer.prepare(config, seed: 1)
        let next = try BankQuestionPreparer.prepare(config, excluding: Set(bank.questions.map(\.id)),
            lastContentID: last.question.contentID, seed: 1)
        XCTAssertNotEqual(next.question.contentID, last.question.contentID)
    }
    @MainActor func testNoPredictiveReferenceRetryQuotaAndOrdinaryRound() async throws {
        let suite = "BankSubmissionTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let limiter = AngleUsageLimiter(defaults: defaults, namespace: suite, limit: 15)
        limiter.isPremium = false
        var configuration = BankConfiguration(); configuration.playsStroke = false
        let prepared = try BankQuestionPreparer.prepare(configuration, seed: 31)
        let vm = BankPracticeViewModel(is3D: false, limiter: limiter, defaults: defaults)
        let repository = MemoryBankRepository()
        vm.attach(repository: repository); vm.start(configuration, prepared: prepared); vm.setupScene()
        defer { vm.suspendTeachingActivity() }
        func wait(_ predicate: () -> Bool) async throws {
            for _ in 0..<200 where !predicate() { try await Task.sleep(for: .milliseconds(50)) }
            XCTAssertTrue(predicate(), vm.diagnostic)
        }
        func assertNoReference() {
            XCTAssertFalse(vm.shouldShowReference)
            XCTAssertNil(vm.referenceTrajectory)
            XCTAssertNil(vm.referenceDirection)
        }
        assertNoReference()
        vm.setSpin(0.2, 0.2); vm.velocity = 3
        assertNoReference()
        vm.prepareGeometryReference(); vm.geometryReference.select(2)
        assertNoReference()
        vm.geometryReference.select(0)
        assertNoReference()
        XCTAssertTrue(vm.switchTrainingView(to: true))
        assertNoReference()
        XCTAssertTrue(vm.switchTrainingView(to: false))
        assertNoReference()
        vm.strike(); vm.suspendTeachingActivity()
        XCTAssertEqual(vm.phase, .aiming)
        XCTAssertEqual(vm.record?.attempts.count, 0)
        XCTAssertEqual(limiter.questionsUsedToday, 0)
        vm.resumeTeachingActivity()
        assertNoReference()
        let source = prepared.question.source
        let current = try XCTUnwrap(vm.record?.draftDirection)
        vm.nudgeAim((atan2(source.direction.z, source.direction.x)-atan2(current.z, current.x)) * 180 / .pi)
        vm.setSpin(Double(source.input.spinX), Double(source.input.spinY)); vm.velocity = Double(source.input.velocity)
        vm.strike(); try await wait { vm.phase == .result }
        XCTAssertNil(vm.record?.latestShot?.failure)
        XCTAssertEqual(vm.record?.successCount, 1); XCTAssertEqual(limiter.questionsUsedToday, 1)
        XCTAssertFalse(vm.shouldShowReference)
        let first = try XCTUnwrap(vm.record?.currentAttempt?.id)
        vm.retry(); vm.velocity = 0.5; vm.strike(); try await wait { vm.phase == .result }
        XCTAssertEqual(vm.record?.currentAttempt?.id, first)
        XCTAssertEqual(vm.record?.successCount, 1); XCTAssertEqual(limiter.questionsUsedToday, 1)
        XCTAssertNil(vm.referenceTrajectory)
        // A retry cannot add an answer. The ordinary round ends explicitly at 15 first answers.
        for count in 2...15 {
            let old = vm.record?.current?.id
            vm.next(); try await wait { vm.phase == .aiming && vm.record?.current?.id != old }
            assertNoReference()
            vm.strike(); try await wait { vm.phase == .result }
            XCTAssertEqual(vm.record?.totalProcessed, count)
            XCTAssertEqual(limiter.questionsUsedToday, count)
        }
        XCTAssertEqual(vm.primaryTitle, "查看总结")
        vm.next(); XCTAssertEqual(vm.phase, .summary)
        XCTAssertEqual(vm.record?.status, .completed)
    }
    @MainActor func testCloseupPreferencePersistsAcrossBankViewsWithoutChangingOtherPractices() throws {
        let suite = "BankCloseupPreference.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = TablePreferencesStore(defaults: defaults)
        _ = store.beginTraining(.bank, source3D: false)
        XCTAssertTrue(store.snapshot(for: .bankPractice2D).enabled(.closeup))
        store.apply(.closeup, value: 0, to: .bankPractice2D)
        XCTAssertFalse(store.snapshot(for: .bankPractice3D).enabled(.closeup))
        let restored = TablePreferencesStore(defaults: defaults)
        XCTAssertFalse(restored.snapshot(for: .bankPractice3D).enabled(.closeup))
        XCTAssertTrue(restored.snapshot(for: .accuracy2D).enabled(.closeup))
        XCTAssertFalse(restored.snapshot(for: .kickPractice2D).enabled(.closeup))
        restored.apply(.closeup, value: 1, to: .bankPractice3D)
        XCTAssertTrue(restored.snapshot(for: .bankPractice2D).enabled(.closeup))
    }

    @MainActor func testCloseupTracksUserAimWithFixedCenterReferencesAndLifecycle() async throws {
        for is3D in [false, true] {
            let suite = "BankCloseup.\(UUID())"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let limiter = AngleUsageLimiter(defaults: defaults, namespace: suite, limit: 15)
            limiter.isPremium = true
            var config = BankConfiguration(); config.playsStroke = false
            let vm = BankPracticeViewModel(is3D: is3D, limiter: limiter, defaults: defaults)
            vm.attach(repository: MemoryBankRepository())
            vm.start(config, prepared: try BankQuestionPreparer.prepare(config, seed: 31)); vm.setupScene()
            defer { vm.suspendTeachingActivity() }
            func verify() throws -> AimCloseupSnapshot {
                let snapshot = try XCTUnwrap(vm.closeupSnapshot)
                let cue = try XCTUnwrap(vm.scene.cueBallNode).position
                let target = try XCTUnwrap(vm.targetNode).position
                let direction = try XCTUnwrap(vm.currentPlayerAim)
                func point(_ p: SCNVector3) -> CGPoint { .init(x: CGFloat(p.x), y: CGFloat(p.z)) }
                let line = AimLineGeometry.resolve(cue: point(cue), dir: point(direction), target: point(target),
                    ballRadius: CGFloat(BallPhysics.radius), railEnd: point(AngleSceneCalculator.rayToInnerRail(from: cue, dir: direction)))
                XCTAssertEqual(snapshot.aimLine?.end, line.lineEnd)
                XCTAssertEqual(snapshot.centerReferenceLine, .init(start: point(cue), end: point(target)))
                XCTAssertEqual(snapshot.targetReferenceRadius, 2 * snapshot.ballRadius)
                XCTAssertNotNil(vm.scene.rootNode.childNode(withName: "bank.centerReferenceLine", recursively: true))
                XCTAssertNil(snapshot.ghost); XCTAssertNil(snapshot.idealLine); XCTAssertNil(snapshot.potLine)
                XCTAssertNil(snapshot.aimPointMarker); XCTAssertNil(snapshot.contactMarker)
                return snapshot
            }
            let initial = try verify()
            vm.nudgeAim(0.25)
            let moved = try verify()
            XCTAssertNotEqual(moved.aimLine, initial.aimLine)
            XCTAssertEqual(moved.centerReferenceLine, initial.centerReferenceLine)
            XCTAssertEqual(moved.auxLine, initial.auxLine)
            vm.suspendTeachingActivity(); XCTAssertNil(vm.closeupSnapshot)
            XCTAssertNil(vm.scene.rootNode.childNode(withName: "bank.centerReferenceLine", recursively: true))
            vm.resumeTeachingActivity(); XCTAssertEqual(try verify(), moved)
            vm.strike()
            for _ in 0..<500 where vm.phase == .preparing { try await Task.sleep(for: .milliseconds(10)) }
            XCTAssertEqual(vm.phase, .result); XCTAssertNil(vm.closeupSnapshot)
            vm.retry(); _ = try verify()
            vm.replayLastShot(); XCTAssertEqual(vm.phase, .playing)
            XCTAssertNil(vm.closeupSnapshot)
            XCTAssertNil(vm.scene.rootNode.childNode(withName: "bank.centerReferenceLine", recursively: true))
            vm.stopPlayback(); XCTAssertEqual(vm.phase, .aiming); _ = try verify()
            vm.nudgeAim(180); XCTAssertNil(vm.closeupSnapshot)
            XCTAssertNotNil(vm.scene.rootNode.childNode(withName: "bank.centerReferenceLine", recursively: true))
        }
    }

    @MainActor func testAnimatedStrokeShowsFrozenRoutesBeforeBallsMoveInBothViews() async throws {
        for is3D in [false, true] {
            let suite = "BankStrokeRoutes.\(UUID())"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let limiter = AngleUsageLimiter(defaults: defaults, namespace: suite, limit: 15)
            limiter.isPremium = true
            var configuration = BankConfiguration(); configuration.playsStroke = true
            let prepared = try BankQuestionPreparer.prepare(configuration, seed: 31)
            let vm = BankPracticeViewModel(is3D: is3D, limiter: limiter, defaults: defaults)
            vm.attach(repository: MemoryBankRepository()); vm.start(configuration, prepared: prepared); vm.setupScene()
            defer { vm.suspendTeachingActivity() }
            let cue = try XCTUnwrap(vm.scene.cueBallNode).position
            vm.strike()
            for _ in 0..<500 where vm.phase == .preparing { try await Task.sleep(for: .milliseconds(10)) }
            XCTAssertEqual(vm.phase, .playing)
            XCTAssertNil(vm.closeupSnapshot)
            XCTAssertNil(vm.scene.rootNode.childNode(withName: "bank.centerReferenceLine", recursively: true))
            XCTAssertTrue(vm.scene.rootNode.childNodes.contains { $0.name == "bank.actual" })
            XCTAssertTrue(vm.scene.rootNode.childNodes.contains { $0.name == "bank.objectActual" })
            XCTAssertFalse(vm.scene.rootNode.childNodes.contains { $0.name == "bank.reference" })
            XCTAssertEqual(vm.scene.cueBallNode?.position.x ?? .nan, cue.x, accuracy: 0.000001)
            XCTAssertEqual(vm.scene.cueBallNode?.position.z ?? .nan, cue.z, accuracy: 0.000001)
            XCTAssertEqual(vm.record?.attempts.count, 1)
        }
    }

    @MainActor func testFreePracticeSegmentsAndRestoresWithoutRebillingOrReference() async throws {
        let suite = "BankFreeTests.\(UUID())", repo = MemoryBankRepository()
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let limiter = AngleUsageLimiter(defaults: defaults, namespace: suite, limit: 15); limiter.isPremium = true
        var config = BankConfiguration(); config.freePractice = true; config.playsStroke = false
        let vm = BankPracticeViewModel(is3D: false, limiter: limiter, defaults: defaults)
        vm.attach(repository: repo); vm.start(config, prepared: try BankQuestionPreparer.prepare(config, seed: 2)); vm.setupScene()
        defer { vm.suspendTeachingActivity() }
        let logicalID = vm.record?.logicalSessionID
        func wait(_ predicate: () -> Bool) async throws {
            for _ in 0..<200 where !predicate() { try await Task.sleep(for: .milliseconds(50)) }
            XCTAssertTrue(predicate(), vm.diagnostic)
        }
        for count in 1...16 {
            XCTAssertFalse(vm.shouldShowReference)
            XCTAssertNil(vm.referenceTrajectory)
            vm.strike(); try await wait { vm.phase == .result }
            XCTAssertEqual(vm.record?.totalProcessed, count)
            XCTAssertFalse(vm.shouldFinish)
            if count < 16 {
                let old = vm.record?.current?.id
                vm.next(); try await wait { vm.phase == .aiming && vm.record?.current?.id != old }
            }
        }
        XCTAssertGreaterThan(repo.records.count, 1)
        XCTAssertEqual(vm.record?.logicalSessionID, logicalID)
        XCTAssertEqual(limiter.questionsUsedToday, 0)
        XCTAssertTrue(vm.switchTrainingView(to: true))
        let last = try XCTUnwrap(vm.record?.latestShot?.id), question = vm.record?.current?.id
        vm.suspendTeachingActivity()
        let restored = BankPracticeViewModel(is3D: false, limiter: limiter, defaults: defaults)
        restored.attach(repository: repo); restored.setupScene()
        defer { restored.suspendTeachingActivity() }
        XCTAssertTrue(restored.is3D)
        XCTAssertEqual(restored.phase, .result)
        XCTAssertEqual(restored.record?.totalProcessed, 16)
        XCTAssertEqual(restored.record?.current?.id, question)
        XCTAssertEqual(restored.record?.latestShot?.id, last)
        XCTAssertFalse(restored.shouldShowReference)
        XCTAssertEqual(limiter.questionsUsedToday, 0)
    }
    private func syntheticShot(_ question: BankQuestion, success: Bool) throws -> BankShot {
        var prediction = ShotPrediction()
        prediction.termination = .settled; prediction.recorder = TrajectoryRecorder()
        prediction.strikeDirection = question.source.direction.vector
        prediction.finalPositions = [ShotInput.cueBallName: question.board.cue.vector]
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: BTTablePhysics.surfaceY)
        prediction.events = [.init(time: 1, kind: .ballBall(ballA: ShotInput.cueBallName, ballB: ShotInput.targetBallName))]
        if success {
            prediction.events += question.railSegments.enumerated().map {
                .init(time: Float($0.offset + 2), kind: .ballCushion(ball: ShotInput.targetBallName), cushionIndex: $0.element)
            }
            prediction.events.append(.init(time: 10, kind: .pocket(ball: ShotInput.targetBallName, pocketId: geometry.pockets[question.source.pocket].id)))
        }
        return try .init(question: question, input: .init(), prediction: prediction, surfaceY: BTTablePhysics.surfaceY)
    }
}

@MainActor private final class MemoryBankRepository: BankPracticeRepository {
    var ownerKey = "test"
    var records: [UUID: BankPracticeRecord] = [:]
    var rejectSubmittedRecord = false
    func save(_ record: BankPracticeRecord) throws {
        if rejectSubmittedRecord, record.latestShot != nil { throw LocalBankPracticeRepository.Failure.oversizedRecord }
        records[record.id] = record
    }
    func saveAtomically(_ records: [BankPracticeRecord]) throws { for record in records { try save(record) } }
    func resumable(is3D: Bool) throws -> BankPracticeRecord? { records.values.first { $0.status == .active } }
}
