import XCTest
import SceneKit
import SwiftData
@testable import QiuJi

final class DefensePracticeTests: XCTestCase {
    func testReferenceRoutesRejectObjectObjectContactsInEitherOrder() throws {
        typealias Event = DefenseBankQuestion.Reference.Expected.Event
        for pair in [[1,8],[8,1],[8,9],[9,8],[1,9],[9,1],[0,1],[1,0],[0,8],[8,0],[0,9],[9,0]] {
            let value: [String: Any] = ["kind":"ballBall", "timeSeconds":1.0, "ballNumbers":pair]
            let event = try JSONDecoder().decode(Event.self, from: JSONSerialization.data(withJSONObject:value))
            XCTAssertEqual(DefenseReferenceRoute.allows([event]), pair.contains(0))
        }
    }
    func testReferenceRoutesRejectPocketContactsForEveryBall() throws {
        typealias Event = DefenseBankQuestion.Reference.Expected.Event
        for ball in [0, 1, 8, 9] {
            for index: Int? in [nil, -1, 0, 5, 6, 14, 43, 44, 55, 999] {
                var value: [String: Any] = ["kind":"cushion", "timeSeconds":1.0, "ballNumbers":[ball]]
                if let index { value["railIndex"] = index }
                let event = try JSONDecoder().decode(Event.self, from: JSONSerialization.data(withJSONObject:value))
                XCTAssertEqual(DefenseReferenceRoute.allows([event]), index == 0 || index == 5)
            }
        }
        let trajectory = try DefenseBankStore.load(.trajectory)
        XCTAssertTrue(trajectory.flatMap(\.references).allSatisfy { DefenseReferenceRoute.allows($0.expected.events) })
    }
    func testLegacyPocketNamesDecodeAndMalformedIndicesFail() throws {
        typealias Event = DefenseBankQuestion.Reference.Expected.Event
        for pocket in 0..<6 {
            for value: Any in [pocket, "pocket_\(pocket)"] {
                let data = try JSONSerialization.data(withJSONObject: ["kind":"pocket", "timeSeconds":1.0, "ballNumbers":[9], "pocketIndex":value])
                let event = try JSONDecoder().decode(Event.self, from: data)
                XCTAssertEqual(event.pocketIndex, pocket)
                XCTAssertEqual(try JSONDecoder().decode(Event.self, from: JSONEncoder().encode(event)).pocketIndex, pocket)
            }
        }
        for value: Any in [-1, 6, "pocket_6", "2", "pocket_02", "unknown"] {
            let data = try JSONSerialization.data(withJSONObject: ["kind":"pocket", "timeSeconds":1.0, "ballNumbers":[9], "pocketIndex":value])
            XCTAssertThrowsError(try JSONDecoder().decode(Event.self, from: data))
        }
    }
    func testSmoothScoreIsBoundedMonotoneAndContinuousAtThreshold() throws {
        XCTAssertEqual(try XCTUnwrap(DefenseEffect.value(pipeDegrees:0,comfort:0,cutDegrees:0)),100,accuracy:1e-10)
        XCTAssertEqual(DefenseEffect.value(pipeDegrees:0,comfort:100,cutDegrees:0),0)
        var previous = 101.0
        for i in 0...1000 {
            let value = try XCTUnwrap(DefenseEffect.value(pipeDegrees: Double(i)*0.004, comfort:12,cutDegrees:0))
            XCTAssertTrue((0...100).contains(value)); XCTAssertLessThanOrEqual(value, previous); previous=value
        }
        let below = try XCTUnwrap(DefenseEffect.value(pipeDegrees:1.0-1e-9,comfort:0,cutDegrees:0))
        let above = try XCTUnwrap(DefenseEffect.value(pipeDegrees:1.0+1e-9,comfort:0,cutDegrees:0))
        XCTAssertGreaterThan(above, 20); XCTAssertEqual(below,above,accuracy:0.001)
        XCTAssertNil(DefenseEffect.value(pipeDegrees:.nan,comfort:0,cutDegrees:0))
        XCTAssertNil(DefenseEffect.value(pipeDegrees:-1,comfort:0,cutDegrees:0))
        XCTAssertNil(DefenseEffect.value(pipeDegrees:0,comfort:101,cutDegrees:0))
    }
    func testTargetPipeScoreUsesDegreeScaleAndRetainsPartialCredit() throws {
        // Lambda 5, straight cut; wide target windows reduce defensive marks.
        for (width, band) in [(1.0, 38.0...40.0), (2.0, 28.0...30.0), (5.0, 18.0...20.0)] {
            XCTAssertTrue(band.contains(try XCTUnwrap(DefenseEffect.value(pipeDegrees:width,comfort:10,cutDegrees:0))))
        }
        for width in [0.0, 0.1, 0.5, 1.0, 5.0] {
            var previous = 101.0
            for comfort in stride(from:0.0,through:100.0,by:1) {
                let score = try XCTUnwrap(DefenseEffect.value(pipeDegrees:width,comfort:comfort,cutDegrees:0))
                XCTAssertLessThanOrEqual(score,previous);previous=score
            }
        }
        XCTAssertGreaterThan(try XCTUnwrap(DefenseEffect.value(pipeDegrees:Double.greatestFiniteMagnitude,comfort:10,cutDegrees:0)),0)
    }
    func testLambdaFiveReducesSmallCutDefenseAndPreservesThinCutLimit() throws {
        let straight = try XCTUnwrap(DefenseEffect.value(pipeDegrees:1,comfort:10,cutDegrees:0))
        let thin = try XCTUnwrap(DefenseEffect.value(pipeDegrees:1,comfort:10,cutDegrees:60))
        let limit = try XCTUnwrap(DefenseEffect.value(pipeDegrees:1,comfort:10,cutDegrees:90))
        XCTAssertEqual(straight,38.7298334621,accuracy:1e-8)
        XCTAssertEqual(thin,63.2455532034,accuracy:1e-8)
        XCTAssertEqual(limit,94.8683298051,accuracy:1e-8)
        XCTAssertLessThan(straight,thin); XCTAssertLessThan(thin,limit)
        for invalid in [-1.0,90.01,Double.nan,Double.infinity] {
            XCTAssertNil(DefenseEffect.value(pipeDegrees:1,comfort:10,cutDegrees:invalid))
        }
        let routes = [DefenseAttackAssessment.PipeRoute(pocket:0,leftDegrees:0,rightDegrees:1,comfort:60,aim:[0,0],cutDegrees:85),
                      .init(pocket:1,leftDegrees:0,rightDegrees:1,comfort:50,aim:[0,0],cutDegrees:0)]
        // Opponent's best opportunity may have LOWER comfort after cut weighting.
        XCTAssertEqual(DefenseAttackAssessment.PipeResult(routes:routes).best?.pocket,1)
    }
    func testV8StoredRouteAndScoreKeepHistoricalFormula() throws {
        let raw = Data(#"{"pocket":0,"leftDegrees":0,"rightDegrees":1,"comfort":10,"aim":[0,0]}"#.utf8)
        let route = try JSONDecoder().decode(DefenseAttackAssessment.PipeRoute.self,from:raw)
        XCTAssertNil(route.cutDegrees)
        XCTAssertEqual(route.score,67.08203932499,accuracy:1e-8)
        var old = DefenseEffect(scoringVersion:"defense-target-pipe-always-scored-v8",failure:nil,
            fullDirectBlock:false,cueToleranceDegrees:nil,comfort:10,opponentBallNumber:9,score:67.082,unavailableReason:nil)
        old.pipeRoute=route;old.targetPipeToleranceDegrees=1
        let restored=try JSONDecoder().decode(DefenseEffect.self,from:JSONEncoder().encode(old))
        XCTAssertEqual(restored.score,67.082)
        XCTAssertTrue(restored.detail.contains("(1+管道角/1°)"))
        XCTAssertFalse(restored.detail.contains("cos²"))
    }
    func testUnscoredResultIsExplainedAndExcludedFromAverage() throws {
        let unscored = DefenseEffect(scoringVersion:DefenseEffect.version,failure:nil,fullDirectBlock:false,
            cueToleranceDegrees:0,comfort:0,opponentBallNumber:8,score:nil,
            unavailableReason:"未找到可靠的进袋路线；不计均分")
        XCTAssertEqual(unscored.scoreText,"未评分")
        XCTAssertTrue(unscored.resultText.contains("未找到可靠的进袋路线"))
        XCTAssertTrue(unscored.resultText.contains("不计均分"))
        XCTAssertNil(unscored.failure)
        let failure = DefenseEffect(scoringVersion:DefenseEffect.version,failure:"母球落袋",fullDirectBlock:false,
            cueToleranceDegrees:nil,comfort:nil,opponentBallNumber:8,score:0,unavailableReason:nil)
        XCTAssertEqual(failure.scoreText,"0.0");XCTAssertEqual(failure.resultText,"母球落袋")
        var config=DefenseConfiguration();config.mode = .free
        let prepared=try DefenseQuestionPreparer.prepare(config,seed:21)
        var record=DefensePracticeRecord(ownerKey:"test",is3D:false,configuration:config,prepared:prepared)
        record.attempts = [
            .init(id:UUID(),questionID:UUID(),submittedAt:Date(),failure:nil,effectScore:nil,trajectoryScore:nil),
            .init(id:UUID(),questionID:UUID(),submittedAt:Date(),failure:"母球落袋",effectScore:0,trajectoryScore:nil),
            .init(id:UUID(),questionID:UUID(),submittedAt:Date(),failure:nil,effectScore:20,trajectoryScore:nil)]
        let restored=try DefensePracticeRecord.decodePayload(record.encodedPayload())
        XCTAssertEqual(restored.totalProcessed,3);XCTAssertEqual(restored.scoredCount,2)
        XCTAssertEqual(restored.average,"10.0")
    }
    func testLegacyDefenseScoresStayFrozenAfterScoringUpgrade() throws {
        let legacy = DefenseEffect(scoringVersion:"defense-softplus8-angle008-comfort-v1",failure:nil,fullDirectBlock:false,
            cueToleranceDegrees:0.016,comfort:10,opponentBallNumber:8,score:0.614,unavailableReason:nil)
        let decoded=try JSONDecoder().decode(DefenseEffect.self,from:JSONEncoder().encode(legacy))
        XCTAssertEqual(decoded.score,0.614);XCTAssertEqual(decoded.scoreText,"0.6")
        XCTAssertTrue(decoded.detail.contains("平滑容错因子"))
        var config=DefenseConfiguration();config.mode = .free
        let prepared=try DefenseQuestionPreparer.prepare(config,seed:21)
        var record=DefensePracticeRecord(ownerKey:"test",is3D:false,configuration:config,prepared:prepared)
        record.scoringVersion=legacy.scoringVersion
        record.attempts=[.init(id:UUID(),questionID:prepared.question.id,submittedAt:Date(),failure:nil,effectScore:legacy.score,trajectoryScore:nil)]
        let restored=try DefensePracticeRecord.decodePayload(record.encodedPayload())
        XCTAssertTrue(restored.isCompatible);XCTAssertFalse(restored.canResumeCurrentTraining)
        XCTAssertEqual(restored.attempts.first?.effectScore,legacy.score);XCTAssertEqual(restored.average,"0.6")
    }
    func testContinuousBlockingProofAndMirrors() {
        let cue = SCNVector3(-0.8,0,0), target = SCNVector3(0.8,0,0)
        XCTAssertTrue(DefenseEffect.fullyBlocked(cue,target,[.init(0,0,0)]))
        XCTAssertFalse(DefenseEffect.fullyBlocked(cue,target,[.init(0,0,0.2)]))
        XCTAssertFalse(DefenseEffect.fullyBlocked(cue,target,[]))
        XCTAssertFalse(DefenseEffect.fullyBlocked(cue,target,[.init(0.9,0,0)]))
        XCTAssertTrue(DefenseEffect.fullyBlocked(target,cue,[.init(0,0,0)]))
    }
    func testBothBanksAndFreeModeIgnoreReferenceFilters() throws {
        let trajectory = try DefenseBankStore.load(.trajectory)
        XCTAssertEqual(trajectory.count,8662); XCTAssertEqual(trajectory.flatMap(\.references).count,17615)
        XCTAssertEqual(Dictionary(grouping:trajectory,by: \.kind).mapValues(\.count),
                       ["one":606,"three":6905,"two_black":580,"two_own":571])
        let free = try DefenseBankStore.load(.free)
        XCTAssertEqual(free.count,58470)
        XCTAssertEqual(Set(free.map(\.kind)),Set(DefenseKind.allCases.map(\.rawValue)))
        var config=DefenseConfiguration();config.mode = .free;config.kind = .three
        config.tactic = "not-a-tactic";config.spin = "back"
        let q = try DefenseQuestionPreparer.prepare(config,seed:17).question
        XCTAssertEqual(q.source.kind,"three");XCTAssertNil(q.reference);XCTAssertTrue(q.referencePaths.isEmpty)
        XCTAssertEqual(q.source.balls.count,3)
    }
    func testRemovedFiltersDecodeButNeverRestrictEitherMode() throws {
        let legacy = Data(#"{"mode":"trajectory","kind":"three","tactic":"block","tactics":["not-a-tactic"],"spin":"back","distance":"near","freePractice":false,"playsStroke":true}"#.utf8)
        let decoded = try JSONDecoder().decode(DefenseConfiguration.self, from: legacy)
        XCTAssertEqual(decoded.tactic, "block")
        XCTAssertEqual(decoded.tactics, ["not-a-tactic"])
        let current = decoded.forCurrentBank
        XCTAssertNil(current.tactic); XCTAssertNil(current.tactics)
        XCTAssertNil(current.spin); XCTAssertNil(current.distance)
        XCTAssertEqual(current.kind, .three)
        for mode in DefenseMode.allCases {
            var baseline = current; baseline.mode = mode
            var old = decoded; old.mode = mode
            for seed: UInt64 in [7, 47] {
                let expected = try DefenseQuestionPreparer.prepare(baseline, seed: seed).question
                // Intentionally pass the unnormalized legacy config, as resumed sessions do.
                let actual = try DefenseQuestionPreparer.prepare(old, seed: seed).question
                XCTAssertEqual(actual.contentID, expected.contentID)
                XCTAssertEqual(actual.referenceIndex, expected.referenceIndex)
            }
        }
    }
    func testFullBankSessionDrawsFifteenDistinctQuestions() throws {
        var seen=Set<String>(),last:String?
        for seed in 1...15 {
            let q=try DefenseQuestionPreparer.prepare(.init(),excluding:seen,lastContentID:last,seed:UInt64(seed)).question
            XCTAssertTrue(seen.insert(q.contentID).inserted)
            XCTAssertNotNil(q.reference);XCTAssertFalse(q.referencePaths.isEmpty)
            last=q.contentID
        }
        XCTAssertEqual(seen.count,15)
    }
    @MainActor func testPilotHistorySurvivesFullBankUpgradeWithoutResuming() throws {
        let context=ModelContext(ModelContainerFactory.makeInMemoryContainer())
        let repository=LocalDefensePracticeRepository(context:context,enqueue:{ _,_ in })
        var configuration=DefenseConfiguration();configuration.mode = .free
        let prepared=try DefenseQuestionPreparer.prepare(configuration,seed:21)
        let legacyPrepared = DefenseQuestionPreparer.Prepared(
            fingerprint: "defense-pilot18-free59000-v1-60c66173-3d9b9311", question: prepared.question)
        let record=DefensePracticeRecord(ownerKey:repository.ownerKey,is3D:false,configuration:configuration,prepared:legacyPrepared)
        XCTAssertTrue(record.isCompatible);XCTAssertFalse(record.canResumeCurrentTraining)
        try repository.save(record)
        XCTAssertNil(try repository.resumable(is3D:false,compatible:{ $0.canResumeCurrentTraining }))
        let stored=try XCTUnwrap(repository.resumable(is3D:false))
        XCTAssertEqual(stored.id,record.id);XCTAssertEqual(stored.current?.contentID,record.current?.contentID)
        XCTAssertEqual(stored.bankFingerprint,record.bankFingerprint)
    }
    func testRulesUseEventOrderAndSeparateOwnPotFromOpponentPot() throws {
        let q = try XCTUnwrap(DefenseBankStore.load(.trajectory).first { $0.kind == "three" })
        var p=ShotPrediction();p.termination = .settled;p.recorder=TrajectoryRecorder()
        let hit=ShotEvent(time:1,kind:.ballBall(ballA:ShotInput.cueBallName,ballB:"_\(q.ownBallNumber)"))
        let rail=ShotEvent(time:1,kind:.ballCushion(ball:ShotInput.cueBallName),cushionIndex:0)
        p.events=[rail,hit];XCTAssertNotNil(DefenseEffect.failure(q,p))
        p.events=[hit,rail];XCTAssertNil(DefenseEffect.failure(q,p))
        p.pocketedBalls=["_\(q.ownBallNumber)"];XCTAssertTrue(DefenseEffect.failure(q,p)!.contains("纯防守"))
        p.pocketedBalls=["_\(q.opponentBallNumber)"];XCTAssertNil(DefenseEffect.failure(q,p))
        p.pocketedBalls=["_8"];XCTAssertNotNil(DefenseEffect.failure(q,p))
        p.pocketedBalls=[];p.cuePocketed=true;XCTAssertEqual(DefenseEffect.failure(q,p),"母球落袋")
    }
    func testFreeDrawUsesFilteredPoolWithoutKindQuotas() throws {
        let bank=try DefenseBankStore.load(.free)
        let pool=Array(bank.filter { $0.kind == "one" }.prefix(1))+Array(bank.filter { $0.kind == "three" }.prefix(9))
        let excluded=Set(bank.map(\.id)).subtracting(pool.map(\.id))
        var configuration=DefenseConfiguration();configuration.mode = .free
        var three=0,seen=Set<String>()
        for seed in 1...80 {
            let q=try DefenseQuestionPreparer.prepare(configuration,excluding:excluded,seed:UInt64(seed)).question
            XCTAssertTrue(pool.contains { $0.id == q.contentID })
            seen.insert(q.source.kind);if q.source.kind == "three" { three += 1 }
        }
        XCTAssertEqual(seen,Set(["one","three"]))
        XCTAssertGreaterThan(three,50,"A 9:1 eligible pool must not become a kind quota or least-seen-kind draw")
    }
    func testDemonstrationQualificationAndThreeDistinctSubmissions() throws {
        XCTAssertFalse(PracticeDemonstrationProgress.qualifies(score: 74.9))
        XCTAssertTrue(PracticeDemonstrationProgress.qualifies(score: 75))
        var progress = PracticeDemonstrationProgress()
        let first = UUID()
        progress.accept(id: first, qualified: false)
        progress.accept(id: first, qualified: false)
        progress.accept(id: UUID(), qualified: false)
        XCTAssertFalse(progress.unlocked)
        progress = try JSONDecoder().decode(PracticeDemonstrationProgress.self, from: JSONEncoder().encode(progress))
        progress.accept(id: UUID(), qualified: false)
        XCTAssertTrue(progress.unlocked)
    }

    func testReferenceAdmissionReplayAndScoreRecording() throws {
        for kind in DefenseKind.allCases {
            var config=DefenseConfiguration();config.kind=kind
            let prepared=try DefenseQuestionPreparer.prepare(config,seed:11)
            let q=prepared.question,r=try XCTUnwrap(q.reference),v=r.parameters
            let input=SeparationInput(spinX:Float(v.spinX),spinY:Float(v.spinY),velocity:Float(v.velocity))
            let prediction=try DefenseQuestionPreparer.solve(question:q,input:input,direction:.init(Float(v.direction[0]),0,Float(v.direction[1])),surfaceY:0.8,profile:AccuracyTipSelector.renderedProfile())
            let shot=try DefenseShot(question:q,input:input,prediction:prediction,surfaceY:0.8)
            XCTAssertNil(shot.failure);XCTAssertGreaterThan(try XCTUnwrap(shot.trajectoryScore),99.99)
            XCTAssertNotNil(shot.effect.score,shot.effect.detail)
            var record=DefensePracticeRecord(ownerKey:"test",is3D:false,configuration:config,prepared:prepared)
            record.accept(shot);record.accept(shot)
            XCTAssertEqual(record.attempts.count,1)
            let decoded=try DefensePracticeRecord.decodePayload(record.encodedPayload())
            XCTAssertTrue(decoded.isCompatible);XCTAssertEqual(decoded.attempts.count,1)
            XCTAssertEqual(decoded.latestShot?.effect.score,shot.effect.score)
            XCTAssertEqual(Set(shot.frames.keys),Set([ShotInput.cueBallName]+q.source.keys))
            XCTAssertEqual(shot.prediction().events.count,prediction.events.count)
        }
    }
    @MainActor func testLocalRepositoryPersistsAcrossViewsAndRejectsWrongOwner() throws {
        let context = ModelContext(ModelContainerFactory.makeInMemoryContainer())
        let repository = LocalDefensePracticeRepository(context: context, enqueue: { _,_ in })
        var configuration = DefenseConfiguration(); configuration.mode = .free
        let prepared = try DefenseQuestionPreparer.prepare(configuration,seed:21)
        var record = DefensePracticeRecord(ownerKey:repository.ownerKey,is3D:false,configuration:configuration,prepared:prepared)
        try repository.save(record)
        XCTAssertEqual(try repository.resumable(is3D:true)?.id,record.id)
        XCTAssertEqual(try repository.resumable(is3D:false)?.current?.contentID,prepared.question.contentID)
        record.ownerKey = "other-owner"
        XCTAssertThrowsError(try repository.save(record))
        XCTAssertEqual(try repository.resumable(is3D:false)?.ownerKey,repository.ownerKey)
    }
    @MainActor func testTrajectoryReferenceIsAttachedAfterSceneSetupAndAimChanges() throws {
        let suite="DefenseReferenceTests.\(UUID())",defaults=try XCTUnwrap(UserDefaults(suiteName:suite))
        defer { defaults.removePersistentDomain(forName:suite) }
        let limiter=AngleUsageLimiter(defaults:defaults,namespace:suite,limit:15);limiter.isPremium=true
        let config=DefenseConfiguration(),prepared=try DefenseQuestionPreparer.prepare(config,seed:7)
        let vm=DefensePracticeViewModel(is3D:false,limiter:limiter,defaults:defaults)
        vm.attach(repository:MemoryDefenseRepository());vm.start(config,prepared:prepared)
        vm.setupScene();defer { vm.suspendTeachingActivity() }
        func attached() -> Int { vm.scene.rootNode.childNodes.filter { $0.name == "defense.reference" && !$0.isHidden && $0.geometry != nil }.count }
        XCTAssertGreaterThan(attached(),0,"Reference must be attached to the actual initialized scene, not only cached in an array")
        let count=attached();vm.nudgeAim(2);vm.setSpin(0,0.2)
        XCTAssertEqual(attached(),count)
        XCTAssertTrue(vm.switchTrainingView(to:true));XCTAssertEqual(attached(),count)
    }
    @MainActor func testRouteColorsSolidCueAndDemoKeepUserComparison() async throws {
        let suite = "DefenseRoutes.\(UUID())", defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let limiter = AngleUsageLimiter(defaults: defaults, namespace: suite, limit: 15); limiter.isPremium = true
        var configuration = DefenseConfiguration(); configuration.kind = .three; configuration.playsStroke = false
        let prepared = try DefenseQuestionPreparer.prepare(configuration, seed: 7)
        let q = prepared.question, p = try XCTUnwrap(q.reference).parameters
        let input = SeparationInput(spinX: Float(p.spinX), spinY: Float(p.spinY), velocity: Float(p.velocity))
        let prediction = try DefenseQuestionPreparer.solve(question: q, input: input,
            direction: .init(Float(p.direction[0]), 0, Float(p.direction[1])), surfaceY: 0.8,
            profile: AccuracyTipSelector.renderedProfile())
        let shot = try DefenseShot(question: q, input: input, prediction: prediction, surfaceY: 0.8)
        for mode in DefenseMode.allCases {
            configuration.mode = mode
            let repo = MemoryDefenseRepository()
            var record = DefensePracticeRecord(ownerKey: repo.ownerKey, is3D: false, configuration: configuration, prepared: .init(fingerprint: DefenseBankStore.fingerprint(for: mode), question: q))
            record.accept(shot); record.showingResult = true
            try repo.save(record)
            let vm = DefensePracticeViewModel(is3D: false, limiter: limiter, defaults: defaults)
            vm.attach(repository: repo); vm.setupScene()
            defer { vm.suspendTeachingActivity() }
            func routes(_ name: String) -> [SCNNode] { vm.scene.rootNode.childNodes.filter { $0.name == name } }
            func colors(_ name: String) -> [UIColor] { routes(name).compactMap { $0.geometry?.firstMaterial?.diffuse.contents as? UIColor } }
            let actual = routes("defense.actual")
            let white = actual.filter { ($0.geometry?.firstMaterial?.diffuse.contents as? UIColor) == TrajectoryStyle.aimColor }
            XCTAssertGreaterThan(white.count, 1, "The pre-contact path must contain solid segments, not one all-dashed ribbon")
            for key in vm.actualRouteKeys where key != ShotInput.cueBallName {
                XCTAssertTrue(colors("defense.actual").contains(TrajectoryStyle.potColor(for: key)))
            }
            XCTAssertGreaterThan(vm.actualRouteKeys.count, 1, "Fixture must actually move an object ball")
            XCTAssertFalse(vm.scene.rootNode.childNodes.contains { $0.name == "defense.aim" })
            if mode == .trajectory {
                XCTAssertTrue(colors("defense.reference").contains(DefenseRouteStyle.targetCue))
                XCTAssertTrue(colors("defense.reference").contains(DefenseRouteStyle.targetObject))
                XCTAssertNotEqual(DefenseRouteStyle.targetCue, DefenseRouteStyle.targetObject)
                let geometry = actual.flatMap { $0.geometry?.sources(for: .vertex).map(\.data) ?? [] }
                let alternate = try XCTUnwrap(q.source.references.indices.first { $0 != q.referenceIndex })
                vm.replayReference(at: alternate)
                XCTAssertFalse(routes("defense.actual").isEmpty, "Demo preparation must retain user routes")
                XCTAssertFalse(routes("defense.reference").isEmpty)
                for _ in 0..<1200 where vm.phase == .preparing { try await Task.sleep(for: .milliseconds(50)) }
                XCTAssertEqual(vm.phase, .playing)
                XCTAssertEqual(routes("defense.actual").flatMap { $0.geometry?.sources(for: .vertex).map(\.data) ?? [] }, geometry)
                XCTAssertFalse(routes("defense.reference").isEmpty, "Demo playback must retain target routes")
                XCTAssertEqual(vm.record?.latestShot?.id, shot.id)
                XCTAssertEqual(vm.record?.attempts.count, 1)
                XCTAssertEqual(vm.demonstrationInput?.velocity, Float(q.source.references[alternate].parameters.velocity))
                XCTAssertEqual(vm.record?.current?.referenceIndex, q.referenceIndex)
                vm.stopPlayback()
                XCTAssertEqual(vm.phase, .result)
                XCTAssertFalse(routes("defense.actual").isEmpty)
                XCTAssertFalse(routes("defense.reference").isEmpty)
            } else {
                XCTAssertTrue(routes("defense.reference").isEmpty)
                vm.retry()
                XCTAssertFalse(routes("defense.actual").isEmpty, "Free retry retains the previous actual route")
                XCTAssertTrue(vm.scene.rootNode.childNodes.contains { $0.name == "defense.aim" })
            }
        }
    }
    @MainActor func testTrajectoryRetryClearsActualAcrossViewsAndRestore() async throws {
        let suite = "DefenseRetry.\(UUID())", defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let limiter = AngleUsageLimiter(defaults: defaults, namespace: suite, limit: 15); limiter.isPremium = true
        var config = DefenseConfiguration(); config.playsStroke = false
        let prepared = try DefenseQuestionPreparer.prepare(config, seed: 7)
        let repo = MemoryDefenseRepository(), vm = DefensePracticeViewModel(is3D: false, limiter: limiter, defaults: defaults)
        vm.attach(repository: repo); vm.start(config, prepared: prepared); vm.setupScene()
        defer { vm.suspendTeachingActivity() }
        vm.velocity = 0.5; vm.strike()
        for _ in 0..<1200 where vm.phase == .preparing { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertEqual(vm.phase, .result)
        XCTAssertTrue(vm.scene.rootNode.childNodes.contains { $0.name == "defense.actual" })
        let first = vm.record?.attempts.first?.id
        vm.retry()
        XCTAssertFalse(vm.scene.rootNode.childNodes.contains { $0.name == "defense.actual" })
        XCTAssertTrue(vm.scene.rootNode.childNodes.contains { $0.name == "defense.reference" })
        XCTAssertTrue(vm.switchTrainingView(to: true))
        XCTAssertFalse(vm.scene.rootNode.childNodes.contains { $0.name == "defense.actual" })
        vm.suspendTeachingActivity()
        let restored = DefensePracticeViewModel(is3D: false, limiter: limiter, defaults: defaults)
        restored.attach(repository: repo); restored.setupScene()
        defer { restored.suspendTeachingActivity() }
        XCTAssertEqual(restored.phase, .aiming)
        XCTAssertFalse(restored.scene.rootNode.childNodes.contains { $0.name == "defense.actual" })
        XCTAssertEqual(restored.record?.attempts.first?.id, first)
        XCTAssertEqual(restored.record?.latestShot?.id, vm.record?.latestShot?.id)
    }
    @MainActor func testViewModelResultRetryNextAndSettingsCancel() async throws {
        let suite="DefenseTests.\(UUID())",defaults=try XCTUnwrap(UserDefaults(suiteName:suite))
        defer { defaults.removePersistentDomain(forName:suite) }
        let limiter=AngleUsageLimiter(defaults:defaults,namespace:suite,limit:15);limiter.isPremium=true
        var config=DefenseConfiguration();config.mode = .free;config.playsStroke=false;config.kind = .three
        let prepared=try DefenseQuestionPreparer.prepare(config,seed:7)
        let repo=MemoryDefenseRepository(),vm=DefensePracticeViewModel(is3D:false,limiter:limiter,defaults:defaults)
        vm.attach(repository:repo);vm.start(config,prepared:prepared);vm.setupScene()
        defer { vm.suspendTeachingActivity() }
        XCTAssertFalse(vm.shouldShowReference);XCTAssertEqual(vm.onTableKeys.count,4)
        let id=vm.record?.current?.id
        vm.openSettings();XCTAssertTrue(vm.cancelSettings());XCTAssertEqual(vm.record?.current?.id,id)
        // Small, legal input deliberately need not be a successful defense.
        vm.velocity=0.5;vm.strike()
        for _ in 0..<1200 where vm.phase == .preparing { try await Task.sleep(for:.milliseconds(50)) }
        XCTAssertEqual(vm.phase,.result,vm.diagnostic);XCTAssertEqual(vm.record?.attempts.count,1)
        let frozen=vm.record?.attempts.first?.effectScore
        vm.retry();XCTAssertEqual(vm.phase,.aiming);XCTAssertEqual(vm.onTableKeys.count,4)
        vm.strike()
        for _ in 0..<1200 where vm.phase == .preparing { try await Task.sleep(for:.milliseconds(50)) }
        XCTAssertEqual(vm.phase,.result);XCTAssertEqual(vm.record?.attempts.count,1);XCTAssertEqual(vm.record?.attempts.first?.effectScore,frozen)
        vm.next()
        for _ in 0..<1200 where vm.phase == .preparing { try await Task.sleep(for:.milliseconds(50)) }
        XCTAssertEqual(vm.phase,.aiming);XCTAssertNotEqual(vm.record?.current?.id,id);XCTAssertNil(vm.record?.latestShot)
        XCTAssertTrue(vm.canAdjust);XCTAssertFalse(vm.shouldShowReference)
    }
}
@MainActor private final class MemoryDefenseRepository: DefensePracticeRepository {
    var ownerKey="test"
    var records=[UUID:DefensePracticeRecord]()
    func save(_ record:DefensePracticeRecord) throws { records[record.id]=record }
    func saveAtomically(_ records:[DefensePracticeRecord]) throws { for r in records { try save(r) } }
    func resumable(is3D:Bool) throws -> DefensePracticeRecord? { records.values.first { $0.status == .active } }
}


/// Diagnostic corpus: recorded legal research strokes, re-simulated using current production code.
/// Passing this harness proves execution/data validity, not full attack-search coverage.
final class DefensePhysicalScoringTests: XCTestCase {
    typealias Reachability = DefenseAttackAssessment.PipeReachability
    typealias Point = DefenseAttackAssessment.P
    private func reachability(_ obstacles:[Point]) -> Reachability {
        .init(cue:Point(-0.8,0),ball:Point(0,0),obstacles:obstacles,
            pocket:Pocket(id:"probe",center:SCNVector3(1,0,0),radius:0.08,isCorner:false))
    }
    func testBothBlockedLimitsDoNotHideReachableMiddle() throws {
        let d=Double(2*AngleSceneCalculator.ballRadius)
        let probe=reachability([Point(0.5,d+0.002),Point(0.5,-d-0.002)])
        XCTAssertNil(probe.reachableEnd(-0.06));XCTAssertNil(probe.reachableEnd(0.06))
        guard case .reachable(let angle)=try probe.search(-0.06...0.06) else {
            return XCTFail("Blocked extremes must not imply a blocked interior")
        }
        XCTAssertNotNil(probe.reachableEnd(angle))
    }
    func testSubGridOffCenterOpeningIsFound() throws {
        let d=Double(2*AngleSceneCalculator.ballRadius),a=0.001234
        let n=Point(cos(a),sin(a)),side=Point(-sin(a),cos(a))
        let probe=reachability([n*0.5+side*(d+0.000003),n*0.5-side*(d+0.000003)])
        let left = -0.02, right = 0.02, count=Int(ceil((right-left)*180/Double.pi/0.01))
        XCTAssertFalse((0...count).contains { probe.reachableEnd(left+(right-left)*Double($0)/Double(count)) != nil },
            "Fixture must defeat the old 0.01-degree grid")
        guard case .reachable(let found)=try probe.search(left...right) else {
            return XCTFail("A sub-grid opening must not be scored as full blocking")
        }
        XCTAssertNotNil(probe.reachableEnd(found));XCTAssertEqual(found,a,accuracy:0.00002)
    }
    func testEitherPipeCanProveWholeWindowClosed() throws {
        for blockers in [[Point(0.5,0)],[Point(-0.4,0)]] {
            let probe=reachability(blockers)
            guard case .blocked=try probe.search(-0.03...0.03) else { return XCTFail("Expected continuous closure") }
            for i in 0...2000 { XCTAssertNil(probe.reachableEnd(-0.03+0.06*Double(i)/2000)) }
        }
    }
    func testJointBlockersCanCoverWindowWithoutOneCoveringEverything() throws {
        let d=Double(2*AngleSceneCalculator.ballRadius)
        let blockers=[Point(0.5,d-0.01),Point(0.5,-d+0.01)]
        XCTAssertFalse(reachability([blockers[0]]).provesClosed(-0.06...0.06))
        XCTAssertFalse(reachability([blockers[1]]).provesClosed(-0.06...0.06))
        guard case .blocked=try reachability(blockers).search(-0.06...0.06) else { return XCTFail("Union should close window") }
    }
    func testBlockerBeyondCaptureIsNotAPotBlock() throws {
        let probe=reachability([Point(1.15,0)])
        XCTAssertNotNil(probe.reachableEnd(0))
        guard case .reachable=try probe.search(-0.01...0.01) else { return XCTFail("Do not test past capture") }
    }
    func testExhaustedProofBudgetIsNotFullMarks() throws {
        guard case .unresolved=try reachability([Point(0.5,0)]).search(-0.03...0.03,maxNodes:0) else {
            return XCTFail("An incomplete proof must stay unresolved")
        }
    }
    func testZeroCleanWindowsCanStillHaveProvenBlockedPipes() throws {
        var assessment=DefenseAttackAssessment()
        let ball=Point(0,0),cue=Point(-0.8,0)
        // No positive angle is required for a full geometric closure proof.
        for pocket in 0..<6 {
            assessment.cache["0.0,0.0,\(pocket)"]=["baseRadians":0.0,"intervals":[[String:Any]](),"isolatedDirections":[Double]()] as [String:Any]
        }
        let result=try assessment.pipeAttack(cue,ball,[Point(-0.4,0)])
        XCTAssertTrue(result.allPotContactsBlocked)
        XCTAssertEqual(result.confirmedClosedPockets,Set(0..<6))
    }
    func testOldV6KeepsItsStoredScoreAndFormula() throws {
        let old=DefenseEffect(scoringVersion:"defense-target-pipe-angle1-block100-v6",failure:nil,
            fullDirectBlock:false,cueToleranceDegrees:nil,comfort:10,opponentBallNumber:8,score:67.082,
            unavailableReason:nil,targetPipeToleranceDegrees:1)
        let decoded=try JSONDecoder().decode(DefenseEffect.self,from:JSONEncoder().encode(old))
        XCTAssertEqual(decoded.score,old.score)
        XCTAssertTrue(decoded.detail.contains("管道角/1°"))
    }
    func testProductionPipeAttackFindsSubGridRoute() throws {
        var assessment=DefenseAttackAssessment()
        let ball=Point(-0.2,0),pocket=1,w=assessment.window(ball,pocket)
        let range=try XCTUnwrap((w["intervals"] as? [[String:Any]])?.first)
        let left=range["leftDegrees"] as! Double,right=range["rightDegrees"] as! Double
        let count=max(2,Int(ceil((right-left)/0.01)))
        let offset=left+(right-left)*(Double(count/2)+0.5)/Double(count)
        let angle=(w["baseRadians"] as! Double)+offset*Double.pi/180
        let n=Point(cos(angle),sin(angle)),side=Point(-sin(angle),cos(angle))
        let cue=ball-n*0.6,d=Double(2*AngleSceneCalculator.ballRadius)
        let obstacles=[ball+n*0.4+side*(d+0.000003),ball+n*0.4-side*(d+0.000003)]
        let probe=Reachability(cue:cue,ball:ball,obstacles:obstacles,pocket:assessment.table.pockets[pocket])
        XCTAssertFalse((0...count).contains {
            probe.reachableEnd((w["baseRadians"] as! Double)+(left+(right-left)*Double($0)/Double(count))*Double.pi/180) != nil
        })
        let result=try assessment.pipeAttack(cue,ball,obstacles)
        let found=try XCTUnwrap(result.routes.first { $0.pocket == pocket })
        XCTAssertEqual(found.tolerance,right-left,accuracy:1e-12)
        XCTAssertFalse(result.allPotContactsBlocked)
        let actual=atan2(found.aim[1]-ball.z,found.aim[0]-ball.x)
        XCTAssertNotNil(probe.reachableEnd(actual))
    }
    func testRecordedFinalStatesAgreeWithAndWithoutTable() throws {
        let samples=try JSONDecoder().decode([DefenseCoverageDiagnosticsTests.Sample].self,
            from:Data(DefenseCoverageDiagnosticsTests.fixtures.utf8))
        var rows=[[String:Any]]()
        for sample in samples {
            let q=sample.source,s=sample.shot,surface:Float=0.8
            func vector(_ a:[Double])->SCNVector3 { .init(Float(a[0]),surface+BallPhysics.radius,Float(a[1])) }
            let direction=SCNVector3(Float(s.direction[0]),0,Float(s.direction[1]))
            let p=ShotPredictor.simulateFree(cueBall:vector(q.cue),aimDir:direction,
                velocity:s.speed,spinX:s.spinX,spinY:s.spinY,surfaceY:surface,
                balls:q.balls.map { .init(name:"_\($0.number)",position:vector($0.position)) },
                maxEvents:1500,maxTime:60,includePresentation:false,simulationModel:.appDefault,recordedStrikeDirection:direction)
            let cached=try DefenseEffect.evaluate(question:q,prediction:p)
            let exact=try DefenseEffect.evaluate(question:q,prediction:p,usePrecomputedWindows:false)
            XCTAssertNotNil(cached.score,q.id);XCTAssertNil(cached.unavailableReason,q.id)
            XCTAssertNotNil(exact.score,q.id);XCTAssertNil(exact.unavailableReason,q.id)
            XCTAssertEqual(cached.score == nil,exact.score == nil,q.id)
            XCTAssertEqual(cached.fullDirectBlock,exact.fullDirectBlock,q.id)
            XCTAssertEqual(cached.potContactsBlocked,exact.potContactsBlocked,q.id)
            if let a=cached.score,let b=exact.score { XCTAssertEqual(a,b,accuracy:0.05,q.id) }
            if cached.potContactsBlocked == true { XCTAssertTrue(cached.detail.contains("进球管道或对应瞄准管道")) }
            if q.id == "S04-01-53" {
                XCTAssertEqual(cached.score,100)
                XCTAssertNil(cached.estimateReason)
                XCTAssertFalse(cached.fullDirectBlock);XCTAssertEqual(cached.potContactsBlocked,true)
                let restored=try JSONDecoder().decode(DefenseEffect.self,from:JSONEncoder().encode(cached))
                XCTAssertEqual(restored.estimateReason,cached.estimateReason)
                XCTAssertEqual(restored.score,cached.score)
            }
            rows.append(["id":q.id,"effect":try JSONSerialization.jsonObject(with:JSONEncoder().encode(cached))])
            print("DEFENSE_V8_CORPUS \(q.id) \(cached.scoreText) blocked=\(cached.fullDirectBlock || cached.potContactsBlocked == true) estimate=\(cached.estimateReason != nil)")
        }
        XCTAssertEqual(rows.count,15)
        let attachment=XCTAttachment(data:try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]),uniformTypeIdentifier:"public.json")
        attachment.name="defense-v7-corpus";attachment.lifetime = .keepAlways;add(attachment)
    }
    func testUnresolvedFallbackIsBoundedAndVariesWithGeometry() throws {
        let table=TableGeometry.chineseEightBallQiuJi(surfaceY:0),ball=Point(-0.2,0)
        var scores=Set<Int>(),comparisons=0
        for x in [-1.1,-0.6,0.0,0.6,1.1] {
            for z in [-0.5,-0.2,0.2,0.5] {
                let cue=Point(x,z),bound=DefenseEffect.optimisticAttackBound(cue:cue,ball:ball,table:table)
                XCTAssertTrue(bound.score.isFinite);XCTAssertTrue((0...100).contains(bound.score))
                XCTAssertEqual(bound.score,try XCTUnwrap(DefenseEffect.value(pipeDegrees:bound.degrees,comfort:bound.comfort,cutDegrees:0)))
                scores.insert(Int(bound.score*100))
                for pocket in table.pockets {
                    if let actual=ShotComfortScore.evaluate(cue:(x,z),ball:(ball.x,ball.z),aim:(Double(pocket.center.x),Double(pocket.center.z))) {
                        XCTAssertGreaterThanOrEqual(bound.comfort+1e-10,actual.total)
                        comparisons += 1
                    }
                }
            }
        }
        XCTAssertGreaterThan(comparisons,20);XCTAssertGreaterThan(scores.count,5)
    }
    func testEstimatedScoresCountInFirstAnswerAverage() throws {
        var config=DefenseConfiguration();config.mode = .free
        let prepared=try DefenseQuestionPreparer.prepare(config,seed:21)
        var record=DefensePracticeRecord(ownerKey:"test",is3D:false,configuration:config,prepared:prepared)
        let table=TableGeometry.chineseEightBallQiuJi(surfaceY:0)
        let estimate=DefenseEffect.optimisticAttackBound(cue:Point(0.4,0.1),ball:Point(-0.2,0),table:table)
        record.attempts=[.init(id:UUID(),questionID:UUID(),submittedAt:Date(),failure:nil,effectScore:estimate.score,trajectoryScore:nil)]
        XCTAssertEqual(record.scoredCount,1);XCTAssertEqual(record.scoreSum,estimate.score)
        XCTAssertEqual(record.average,String(format:"%.1f",estimate.score))
    }
    func testReportedCornerPositionUsesSharedTargetPipeGeometry() throws {
        let cue=Point(0.25323376059532166,-0.40874484181404114)
        let ball=Point(-1.1702895164489746,0.099954098463058472)
        let eight=Point(-1.1348888874053955,0.19820676743984222)
        let one=Point(-0.31796246767044067,-0.49101009964942932)
        var assessment=DefenseAttackAssessment(),rows=[[String:Any]]()
        for pocket in 0..<6 {
            let window=assessment.window(ball,pocket),base=window["baseRadians"] as! Double
            let ranges=window["intervals"] as! [[String:Any]]
            let shared=PocketToleranceGeometry.evaluate(x:Float(ball.x),z:Float(ball.z),pocket:pocket,useTable:false)
            var row:[String:Any]=["pocket":pocket,"window":window]
            switch shared {
            case .window(let result):
                XCTAssertFalse(ranges.isEmpty)
                row["sharedDegrees"]=result.degrees
                row["sharedEdges"]=result.edges.map { [$0.startX,$0.startZ,$0.endX,$0.endZ] }
            case .noStraightWindow: XCTAssertTrue(ranges.isEmpty);row["sharedStatus"]="noStraightWindow"
            case .unavailable: row["sharedStatus"]="unavailable"
            }
            let reach=Reachability(cue:cue,ball:ball,obstacles:[eight,one],pocket:assessment.table.pockets[pocket],rails:assessment.mainRails)
            row["edge8ClearanceMM"]=ranges.map { interval -> [Any] in
                [interval["leftDegrees"] as! Double,interval["rightDegrees"] as! Double].map { offset -> Any in
                    let angle=base+offset*Double.pi/180,n=Point(cos(angle),sin(angle))
                    guard let distance=assessment.table.pockets[pocket].entryTime(position:ball.scn,velocity:n.scn,acceleration:SCNVector3Zero,maxTime:4) else { return NSNull() }
                    return (Reachability.distance(eight,ball,ball+n*Double(distance))-2*assessment.rad)*1000
                }
            }
            if let envelope=reach.captureEnvelope {row["captureEnvelope"]=[envelope.lowerBound,envelope.upperBound]}
            rows.append(row)
        }
        let actual=try assessment.pipeAttack(cue,ball,[eight,one])
        XCTAssertTrue(actual.allPotContactsBlocked)
        XCTAssertEqual(actual.confirmedClosedPockets,Set(0..<6))
        let data=try JSONSerialization.data(withJSONObject:["pockets":rows,"allBlocked":actual.allPotContactsBlocked],options:[.prettyPrinted,.sortedKeys])
        let attachment=XCTAttachment(data:data,uniformTypeIdentifier:"public.json")
        attachment.name="S04-01-53-pipe-diagnostic";attachment.lifetime = .keepAlways;add(attachment)
        print("S04_PIPE_DIAGNOSTIC "+String(decoding:data,as:UTF8.self))
    }
    func testReviewedABCPositionsThroughProductionScoring() throws {
        let samples = try JSONDecoder().decode([DefenseCoverageDiagnosticsTests.Sample].self,
            from: Data(DefenseCoverageDiagnosticsTests.fixtures.utf8))
        var rows = [[String: Any]]()
        for id in ["S03-01-46", "S04-01-60", "S01-01-30"] {
            let sample = try XCTUnwrap(samples.first { $0.source.id == id })
            let q = sample.source, s = sample.shot, surface: Float = 0.8
            func vector(_ p: [Double]) -> SCNVector3 { .init(Float(p[0]), surface + BallPhysics.radius, Float(p[1])) }
            let direction = SCNVector3(Float(s.direction[0]), 0, Float(s.direction[1]))
            let p = ShotPredictor.simulateFree(cueBall: vector(q.cue), aimDir: direction,
                velocity: s.speed, spinX: s.spinX, spinY: s.spinY, surfaceY: surface,
                balls: q.balls.map { .init(name: "_\($0.number)", position: vector($0.position)) },
                maxEvents: 1500, maxTime: 60, includePresentation: false,
                simulationModel: .appDefault, recordedStrikeDirection: direction)
            let start = Date(), effect = try DefenseEffect.evaluate(question: q, prediction: p)
            let elapsed = Date().timeIntervalSince(start)
            XCTAssertNil(effect.failure)
            XCTAssertFalse(effect.fullDirectBlock)
            XCTAssertNil(effect.cueToleranceDegrees)
            XCTAssertNil(effect.attackRoute)
            if id != "S01-01-30" {
                XCTAssertNil(effect.unavailableReason)
                XCTAssertEqual(effect.score,100)
                XCTAssertEqual(effect.potContactsBlocked,true)
                XCTAssertNil(effect.targetPipeToleranceDegrees)
                XCTAssertNil(effect.comfort)
            } else {
                // Latest user decision: a reachable zero-angle route uses the formula.
                XCTAssertNil(effect.unavailableReason)
                XCTAssertEqual(effect.targetPipeToleranceDegrees,0)
                XCTAssertEqual(effect.pipeRoute?.pocket,0)
                XCTAssertEqual(effect.pipeRoute?.zeroWidthEstimate,true)
                XCTAssertEqual(try XCTUnwrap(effect.score),100*sqrt(1-(try XCTUnwrap(effect.comfort))/100),accuracy:1e-10)

            }
            let restored = try JSONDecoder().decode(DefenseEffect.self, from: JSONEncoder().encode(effect))
            XCTAssertEqual(restored.score, effect.score)
            XCTAssertEqual(restored.potContactsBlocked, effect.potContactsBlocked)
            XCTAssertEqual(restored.targetPipeToleranceDegrees, effect.targetPipeToleranceDegrees)
            XCTAssertEqual(restored.pipeRoute?.tolerance, effect.pipeRoute?.tolerance)
            rows.append(["id": id, "seconds": elapsed,
                "effect": try JSONSerialization.jsonObject(with: JSONEncoder().encode(effect))])
            print("DEFENSE_V4 \(id) \(effect.detail) seconds=\(elapsed)")
        }
        let data = try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "defense-v4-abc"; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testPipeAngleIsIndependentOfCueAndComfortUsesSameRoute() throws {
        typealias P = DefenseAttackAssessment.P
        let ball = P(-0.2,0), pocket = AngleSceneCalculator.pocketPositions(surfaceY:0)[1]
        let delta = P(Double(pocket.x),Double(pocket.z))-ball, n = delta*(1/delta.length)
        var widths = [Double](), comforts = [Double]()
        for distance in [0.4,0.9] {
            var assessment = DefenseAttackAssessment(); assessment.usePrecomputedWindows = true
            let attack = try assessment.pipeAttack(ball-n*distance,ball,[])
            let route = try XCTUnwrap(attack.routes.first { $0.pocket == 1 })
            widths.append(route.tolerance); comforts.append(route.comfort)
            XCTAssertEqual(route.score,try XCTUnwrap(DefenseEffect.value(pipeDegrees:route.tolerance,comfort:route.comfort,cutDegrees:try XCTUnwrap(route.cutDegrees))))
        }
        XCTAssertEqual(widths[0],widths[1],accuracy:1e-12)
        XCTAssertNotEqual(comforts[0],comforts[1])
        let routes = [DefenseAttackAssessment.PipeRoute(pocket:0,leftDegrees:0,rightDegrees:2,comfort:10,aim:[0,0],cutDegrees:0),
                      .init(pocket:1,leftDegrees:0,rightDegrees:0.125,comfort:80,aim:[0,0],cutDegrees:0)]
        let result = DefenseAttackAssessment.PipeResult(routes:routes)
        // At lambda 5 the wider opening wins despite its lower comfort.
        XCTAssertEqual(result.best?.pocket,0)
        XCTAssertGreaterThan(result.best!.score,DefenseEffect.value(pipeDegrees:2,comfort:80,cutDegrees:0)!)
    }

    func testPreviousReciprocalVersionKeepsItsFormulaAndFrozenScore() throws {
        let old = DefenseEffect(scoringVersion: "defense-reciprocal-angle008-comfort-v2", failure: nil,
            fullDirectBlock: false, cueToleranceDegrees: 0.016, comfort: 10,
            opponentBallNumber: 8, score: 54.772, unavailableReason: nil)
        let decoded = try JSONDecoder().decode(DefenseEffect.self, from: JSONEncoder().encode(old))
        XCTAssertEqual(decoded.score, 54.772)
        XCTAssertTrue(decoded.detail.contains("1 / (1 + 容错角/0.008°)"))
        XCTAssertNil(decoded.potContactsBlocked); XCTAssertNil(decoded.attackRoute)
    }
}

final class DefenseCoverageDiagnosticsTests: XCTestCase {
    struct Stroke: Decodable { let direction:[Double];let speed,spinX,spinY:Float }
    struct Sample: Decodable { let source:DefenseBankQuestion;let shot:Stroke;let historicalCategory:String }
    func testRecordedUnscoredPositionsAgainstProductionDirectPotSearch() throws {
        let samples=try JSONDecoder().decode([Sample].self,from:Data(Self.fixtures.utf8))
        XCTAssertEqual(samples.count,15)
        let surface:Float=0.8
        func vector(_ p:[Double])->SCNVector3 { .init(Float(p[0]),surface+BallPhysics.radius,Float(p[1])) }
        func position(_ p:SCNVector3)->[Double] { [Double(p.x),Double(p.z)] }
        var rows=[[String:Any]]()
        for sample in samples { try autoreleasepool {
            let q=sample.source,s=sample.shot,direction=SCNVector3(Float(s.direction[0]),0,Float(s.direction[1]))
            let p=ShotPredictor.simulateFree(cueBall:vector(q.cue),aimDir:direction,velocity:s.speed,spinX:s.spinX,spinY:s.spinY,
                surfaceY:surface,balls:q.balls.map{.init(name:"_\($0.number)",position:vector($0.position))},
                maxEvents:1500,maxTime:60,includePresentation:false,simulationModel:.planarReference,recordedStrikeDirection:direction)
            let effect=try DefenseEffect.evaluate(question:q,prediction:p)
            var row:[String:Any]=["id":q.id,"historicalCategory":sample.historicalCategory,
                "effect":try JSONSerialization.jsonObject(with:JSONEncoder().encode(effect)),
                "finalPositions":p.finalPositions.mapValues(position),"pocketed":p.pocketedBalls]
            if effect.failure == nil {
                let cue=try XCTUnwrap(p.finalPositions[ShotInput.cueBallName])
                let targetKey="_\(effect.opponentBallNumber)",target=try XCTUnwrap(p.finalPositions[targetKey])
                let obstacles=q.keys.filter{$0 != targetKey && !p.pocketedBalls.contains($0)}.map{ObstacleBall(name:$0,position:p.finalPositions[$0]!)}
                var assessment=DefenseAttackAssessment()
                let attack=assessment.attack(.init(position(cue)),.init(position(target)),obstacles.map{.init(position($0.position))},step:0.01)
                row["attack"]=attack
                row["incompleteComfort"]=assessment.incompleteComfort;row["edges"]=assessment.edges;row["windowDiff"]=assessment.windowDiff
                var candidates=[[String:Any]]()
                let start=Date()
                for pocket in 0..<6 {
                    for speed:Float in [0.8,1.4,2.2] {
                        let input=ShotInput(simulationModel:.planarReference,cueBall:cue,targetBall:target,pocketIndex:pocket,velocity:speed,spinX:0,spinY:0,surfaceY:surface,obstacles:obstacles)
                        let prediction=ShotPredictor.predict(input,maxEvents:1500,maxTime:60)
                        let success=ShotPredictor.isDirectPot(prediction,pocketIndex:pocket)
                        var candidate:[String:Any]=["pocket":pocket,"speed":speed,"directPot":success,"settled":prediction.hasFinalTableState,"feasible":prediction.feasible,"cuePocketed":prediction.cuePocketed]
                        if success {
                            candidate["direction"]=position(prediction.strikeDirection ?? prediction.aimDirection)
                            candidate["objectPath"]=prediction.objectPath.map(position)
                            candidate["cuePath"]=prediction.cuePath.map(position)
                        }
                        candidates.append(candidate)
                    }
                }
                row["physicalCandidates"]=candidates;row["searchSeconds"]=Date().timeIntervalSince(start)
            }
            rows.append(row)
            print("DEFENSE_COVERAGE \(q.id) \(effect.scoreText) \(effect.unavailableReason ?? effect.failure ?? "rated")")
        } }
        let data=try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys])
        let attachment=XCTAttachment(data:data,uniformTypeIdentifier:"public.json")
        attachment.name="defense-coverage-current";attachment.lifetime = .keepAlways;add(attachment)
        XCTAssertEqual(rows.count,samples.count)
    }
    static let fixtures = #"""
[{"source":{"id":"S01-01-2","sourceFormationID":"02a87cb7c049f46a93b76b0d09a88179b1c22728fe3d1295e4d53e695f3e4c72","sampleID":"S01-01","kind":"one","cue":[0.2555553022061561,0.30156025378881024],"balls":[{"number":8,"position":[-1.1799697017327342,-0.2184116252965283]}],"ownBallNumber":8,"opponentBallNumber":8,"references":[]},"shot":{"angle":-2.8311413277108515,"direction":[-0.9521957635879517,-0.3054884076118469],"speed":0.7,"spinX":0,"spinY":-0.2},"historicalCategory":"rated"},{"source":{"id":"S01-01-25","sourceFormationID":"02a87cb7c049f46a93b76b0d09a88179b1c22728fe3d1295e4d53e695f3e4c72","sampleID":"S01-01","kind":"one","cue":[0.2555553022061561,0.30156025378881024],"balls":[{"number":8,"position":[-1.1799697017327342,-0.2184116252965283]}],"ownBallNumber":8,"opponentBallNumber":8,"references":[]},"shot":{"angle":-2.8311413277108515,"direction":[-0.9521957635879517,-0.3054884076118469],"speed":3.2,"spinX":0,"spinY":0.2},"historicalCategory":"cornerWitness"},{"source":{"id":"S01-01-30","sourceFormationID":"02a87cb7c049f46a93b76b0d09a88179b1c22728fe3d1295e4d53e695f3e4c72","sampleID":"S01-01","kind":"one","cue":[0.2555553022061561,0.30156025378881024],"balls":[{"number":8,"position":[-1.1799697017327342,-0.2184116252965283]}],"ownBallNumber":8,"opponentBallNumber":8,"references":[]},"shot":{"angle":-2.8274347578001127,"direction":[-0.951056957244873,-0.309015691280365],"speed":1,"spinX":0,"spinY":-0.2},"historicalCategory":"noWindow"},{"source":{"id":"S02-01-2","sourceFormationID":"2532ecf7353d829e62e0aae94df552354dffc0d9e59868ddc2764b5b20cfa428","sampleID":"S02-01","kind":"two_black","cue":[-0.22971341051717686,-0.3788258335656973],"balls":[{"number":9,"position":[-0.5537393791922778,-0.5219878163222442]},{"number":8,"position":[1.1824530908187991,-0.3034381383747674]}],"ownBallNumber":8,"opponentBallNumber":9,"references":[]},"shot":{"angle":0.013314849344293313,"direction":[0.999911367893219,0.01331445574760437],"speed":0.7,"spinX":0,"spinY":-0.2},"historicalCategory":"cornerWitness"},{"source":{"id":"S02-01-4","sourceFormationID":"2532ecf7353d829e62e0aae94df552354dffc0d9e59868ddc2764b5b20cfa428","sampleID":"S02-01","kind":"two_black","cue":[-0.22971341051717686,-0.3788258335656973],"balls":[{"number":9,"position":[-0.5537393791922778,-0.5219878163222442]},{"number":8,"position":[1.1824530908187991,-0.3034381383747674]}],"ownBallNumber":8,"opponentBallNumber":9,"references":[]},"shot":{"angle":0.013314849344293313,"direction":[0.999911367893219,0.01331445574760437],"speed":1.4,"spinX":0,"spinY":-0.2},"historicalCategory":"rated"},{"source":{"id":"S02-01-33","sourceFormationID":"2532ecf7353d829e62e0aae94df552354dffc0d9e59868ddc2764b5b20cfa428","sampleID":"S02-01","kind":"two_black","cue":[-0.22971341051717686,-0.3788258335656973],"balls":[{"number":9,"position":[-0.5537393791922778,-0.5219878163222442]},{"number":8,"position":[1.1824530908187991,-0.3034381383747674]}],"ownBallNumber":8,"opponentBallNumber":9,"references":[]},"shot":{"angle":0.017316745706767826,"direction":[0.9998500943183899,0.017315879464149475],"speed":2.5,"spinX":0,"spinY":-0.2},"historicalCategory":"noWindow"},{"source":{"id":"S02-01-60","sourceFormationID":"2532ecf7353d829e62e0aae94df552354dffc0d9e59868ddc2764b5b20cfa428","sampleID":"S02-01","kind":"two_black","cue":[-0.22971341051717686,-0.3788258335656973],"balls":[{"number":9,"position":[-0.5537393791922778,-0.5219878163222442]},{"number":8,"position":[1.1824530908187991,-0.3034381383747674]}],"ownBallNumber":8,"opponentBallNumber":9,"references":[]},"shot":{"angle":0.021318642069242347,"direction":[0.9997727870941162,0.021317027509212494],"speed":2.5,"spinX":0,"spinY":-0.2},"historicalCategory":"fullBlock"},{"source":{"id":"S03-01-2","sourceFormationID":"ed1524a2ec778729012763de0444470f369dd54cca7e5d7f624932038f5a786b","sampleID":"S03-01","kind":"two_own","cue":[0.21350251569642897,0.12305157126006727],"balls":[{"number":8,"position":[-0.6880903674449256,-0.18945745155462843]},{"number":1,"position":[-1.1237354576253353,0.10149105560761144]}],"ownBallNumber":1,"opponentBallNumber":8,"references":[]},"shot":{"angle":-3.167788240096363,"direction":[-0.9996569156646729,0.026192590594291687],"speed":0.7,"spinX":0,"spinY":-0.2},"historicalCategory":"rated"},{"source":{"id":"S03-01-19","sourceFormationID":"ed1524a2ec778729012763de0444470f369dd54cca7e5d7f624932038f5a786b","sampleID":"S03-01","kind":"two_own","cue":[0.21350251569642897,0.12305157126006727],"balls":[{"number":8,"position":[-0.6880903674449256,-0.18945745155462843]},{"number":1,"position":[-1.1237354576253353,0.10149105560761144]}],"ownBallNumber":1,"opponentBallNumber":8,"references":[]},"shot":{"angle":-3.167788240096363,"direction":[-0.9996569156646729,0.026192590594291687],"speed":0.45,"spinX":0,"spinY":0.2},"historicalCategory":"fullBlock"},{"source":{"id":"S03-01-35","sourceFormationID":"ed1524a2ec778729012763de0444470f369dd54cca7e5d7f624932038f5a786b","sampleID":"S03-01","kind":"two_own","cue":[0.21350251569642897,0.12305157126006727],"balls":[{"number":8,"position":[-0.6880903674449256,-0.18945745155462843]},{"number":1,"position":[-1.1237354576253353,0.10149105560761144]}],"ownBallNumber":1,"opponentBallNumber":8,"references":[]},"shot":{"angle":-3.1635565043128167,"direction":[-0.999758780002594,0.021962085738778114],"speed":3.8,"spinX":0,"spinY":-0.2},"historicalCategory":"cornerWitness"},{"source":{"id":"S03-01-46","sourceFormationID":"ed1524a2ec778729012763de0444470f369dd54cca7e5d7f624932038f5a786b","sampleID":"S03-01","kind":"two_own","cue":[0.21350251569642897,0.12305157126006727],"balls":[{"number":8,"position":[-0.6880903674449256,-0.18945745155462843]},{"number":1,"position":[-1.1237354576253353,0.10149105560761144]}],"ownBallNumber":1,"opponentBallNumber":8,"references":[]},"shot":{"angle":-3.1635565043128167,"direction":[-0.999758780002594,0.021962085738778114],"speed":0.45,"spinX":0,"spinY":0.2},"historicalCategory":"noWindow"},{"source":{"id":"S04-01-2","sourceFormationID":"d7833be4cac40efb2909b9876cb40a21d7815e7ea685b4a087c69037a71b7bed","sampleID":"S04-01","kind":"three","cue":[-0.28012081879876316,0.43220962489515335],"balls":[{"number":8,"position":[-0.029415040836058077,0.20733656924541366]},{"number":9,"position":[-1.1267151350388493,0.12964524901545554]},{"number":1,"position":[1.1205350160598755,0.0802815705537796]}],"ownBallNumber":1,"opponentBallNumber":9,"references":[]},"shot":{"angle":-0.28535051011586304,"direction":[0.9595630168914795,-0.28149381279945374],"speed":0.7,"spinX":0,"spinY":-0.2},"historicalCategory":"rated"},{"source":{"id":"S04-01-24","sourceFormationID":"d7833be4cac40efb2909b9876cb40a21d7815e7ea685b4a087c69037a71b7bed","sampleID":"S04-01","kind":"three","cue":[-0.28012081879876316,0.43220962489515335],"balls":[{"number":8,"position":[-0.029415040836058077,0.20733656924541366]},{"number":9,"position":[-1.1267151350388493,0.12964524901545554]},{"number":1,"position":[1.1205350160598755,0.0802815705537796]}],"ownBallNumber":1,"opponentBallNumber":9,"references":[]},"shot":{"angle":-0.28535051011586304,"direction":[0.9595630168914795,-0.28149381279945374],"speed":2.5,"spinX":0,"spinY":0.2},"historicalCategory":"fullBlock"},{"source":{"id":"S04-01-53","sourceFormationID":"d7833be4cac40efb2909b9876cb40a21d7815e7ea685b4a087c69037a71b7bed","sampleID":"S04-01","kind":"three","cue":[-0.28012081879876316,0.43220962489515335],"balls":[{"number":8,"position":[-0.029415040836058077,0.20733656924541366]},{"number":9,"position":[-1.1267151350388493,0.12964524901545554]},{"number":1,"position":[1.1205350160598755,0.0802815705537796]}],"ownBallNumber":1,"opponentBallNumber":9,"references":[]},"shot":{"angle":-0.28143182892057705,"direction":[0.9606587886810303,-0.27773141860961914],"speed":3.8,"spinX":0,"spinY":0.2},"historicalCategory":"cornerWitness"},{"source":{"id":"S04-01-60","sourceFormationID":"d7833be4cac40efb2909b9876cb40a21d7815e7ea685b4a087c69037a71b7bed","sampleID":"S04-01","kind":"three","cue":[-0.28012081879876316,0.43220962489515335],"balls":[{"number":8,"position":[-0.029415040836058077,0.20733656924541366]},{"number":9,"position":[-1.1267151350388493,0.12964524901545554]},{"number":1,"position":[1.1205350160598755,0.0802815705537796]}],"ownBallNumber":1,"opponentBallNumber":9,"references":[]},"shot":{"angle":-0.277513147725291,"direction":[0.961739718914032,-0.2739647924900055],"speed":2.5,"spinX":0,"spinY":-0.2},"historicalCategory":"noWindow"}]
"""#
}
