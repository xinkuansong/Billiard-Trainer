import XCTest
import SwiftData
import SceneKit
@testable import QiuJi

final class SceneTrainingRulesTests: XCTestCase {
    func testAimGradeBoundariesAndInvalidDirections() {
        for (mm, grade) in [(0.0,"完美"),(0.5,"完美"),(0.5001,"很好"),(1,"很好"),(1.0001,"好"),(2,"好"),(2.0001,"一般"),(5,"一般"),(5.0001,"差")] {
            for sign in [-1.0, 1.0] { XCTAssertEqual(SceneAimScore(status: .valid, millimetres: mm * sign, straight: false).grade, grade) }
        }
        for status in [SceneAimScore.Status.backwards, .wrongSide, .missesTarget] {
            let score = SceneAimScore(status: status, millimetres: nil, straight: false)
            XCTAssertEqual(score.grade, "差"); XCTAssertTrue(score.explanation.contains(score.label))
        }
    }

    func testTwoBallSettingsMigrateWithoutWritingAndShareViewsButKeepModesIndependent() throws {
        let suite = "training-settings-review." + UUID().uuidString
        let store = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { store.removePersistentDomain(forName: suite) }
        var legacy = SceneTrainingConfiguration.defaults(for: "twoBallPractice2D")
        legacy.angleSelection = [.small]
        legacy.allowsVerticalSpin = false
        store.set(try JSONEncoder().encode(legacy), forKey: "sceneTraining.rules2.mixedDefaults.twoBallPractice2D")
        store.set(false, forKey: "twoBallPractice.2D.playsStroke")
        let originalKeys = Set(store.dictionaryRepresentation().keys)
        var trajectory = TwoBallSettingsPreference.load(for: "twoBallPractice2D", mode: .trajectory, defaults: store)
        var free = TwoBallSettingsPreference.load(for: "twoBallPractice2D", mode: .free, defaults: store)
        XCTAssertEqual(trajectory.configuration, legacy)
        XCTAssertEqual(free, trajectory)
        XCTAssertFalse(free.playsStroke)
        XCTAssertEqual(Set(store.dictionaryRepresentation().keys), originalKeys, "Opening and Cancel must not migrate preferences by writing")
        trajectory.configuration.cueDistanceSelection = [.long]
        free.configuration.cueDistanceSelection = [.short]
        free.playsStroke = true
        free.showsReference = true
        trajectory.save(for: "twoBallPractice2D", mode: .trajectory, defaults: store)
        free.save(for: "twoBallPractice2D", mode: .free, defaults: store)
        XCTAssertEqual(TwoBallSettingsPreference.load(for: "twoBallPractice2D", mode: .trajectory, defaults: store), trajectory)
        XCTAssertEqual(TwoBallSettingsPreference.load(for: "twoBallPractice2D", mode: .free, defaults: store), free)
        XCTAssertEqual(TwoBallSettingsPreference.load(for: "twoBallPractice3D", mode: .free, defaults: store), free)
        // A reset remains an uncommitted value until the user starts again.
        free = .defaults(for: "twoBallPractice2D")
        XCTAssertNotEqual(TwoBallSettingsPreference.load(for: "twoBallPractice2D", mode: .free, defaults: store), free)
    }

    func testFreeTwoBallGenerationIgnoresHiddenSpinFiltersButPreservesBoardConditions() {
        var trajectory = SceneTrainingConfiguration.defaults(for: "twoBallPractice2D")
        trajectory.allowsVerticalSpin = false; trajectory.allowsSideSpin = false
        trajectory.cueDistanceSelection = [.short, .long]
        trajectory.pocketSelection = [.side]
        let free = trajectory.forTwoBallMode(.free)
        XCTAssertTrue(free.allowsVerticalSpin)
        XCTAssertTrue(free.allowsSideSpin)
        XCTAssertEqual(free.angleSelection, trajectory.angleSelection)
        XCTAssertEqual(free.cueDistanceSelection, trajectory.cueDistanceSelection)
        XCTAssertEqual(free.pocketSelection, trajectory.pocketSelection)
        XCTAssertEqual(trajectory.forTwoBallMode(.trajectory), trajectory)
        XCTAssertFalse(trajectory.allowsVerticalSpin)
        XCTAssertFalse(trajectory.allowsSideSpin)
    }

    func testEveryRangeUsesMeasuredGeometryAndRequestedDistances() throws {
        for range in SceneTrainingConfiguration.AngleRange.allCases {
            var config = SceneTrainingConfiguration(); config.angles = range
            var generator = SceneTrainingGenerator(seed: 15)
            let batch = try generator.batch(config)
            XCTAssertEqual(batch.count, 20)
            XCTAssertEqual(batch.filter { $0.geometry.pocketType == .corner }.count, 10)
            let nonZero = batch.filter { $0.side != 0 }
            XCTAssertLessThanOrEqual(abs(nonZero.filter { $0.side == 1 }.count - nonZero.filter { $0.side == -1 }.count), 1)
            for (index, item) in batch.enumerated() {
                let q = item.geometry
                let cue = AngleSceneCalculator.normalizedToScene(point: q.cueBall, surfaceY: 0)
                let target = AngleSceneCalculator.normalizedToScene(point: q.targetBall, surfaceY: 0)
                let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: q.pocketIndex, surfaceY: 0)
                let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: aim, ballRadius: AngleSceneCalculator.ballRadius)
                // Independently recompute an unsigned angle using atan2(cross,dot), without the production angle helper.
                let ux = Double(ghost.x - cue.x), uz = Double(ghost.z - cue.z)
                let vx = Double(aim.x - target.x), vz = Double(aim.z - target.z)
                let measured = abs(atan2(ux * vz - uz * vx, ux * vx + uz * vz)) * 180 / .pi
                XCTAssertEqual(measured, q.actualAngle, accuracy: 0.01)
                XCTAssertEqual(q.actualAngle,q.actualAngle.rounded(),"Integer questions must score the exact displayed answer")
                XCTAssertTrue(range.degrees.contains(Int(measured.rounded())))
                XCTAssertEqual(measured, measured.rounded(), accuracy: 0.05)
                XCTAssertTrue(config.cueDistance.metres(cue: true).contains(Double(hypot(cue.x-target.x,cue.z-target.z))))
                XCTAssertTrue(config.pocketDistance.metres(cue: false).contains(Double(hypot(aim.x-target.x,aim.z-target.z))))
                XCTAssertTrue(AngleSceneCalculator.trainingHasCleanPocketPath(target: target, aim: aim, pocketIndex: q.pocketIndex))
                let score = SceneAimScore.measure(cue: cue, target: target, ghost: ghost, direction: SCNVector3(ghost.x-cue.x,0,ghost.z-cue.z))
                XCTAssertEqual(score.status, .valid)
                let centerAim = SCNVector3(target.x-cue.x,0,target.z-cue.z).normalized()
                XCTAssertEqual(SceneAimScore.measure(cue:cue,target:target,ghost:ghost,direction:centerAim).status, .valid,
                    "Two-centre initial aim must not become wrong-side through Float roundoff")
                XCTAssertEqual(try XCTUnwrap(score.millimetres), 0, accuracy: 0.001)
                if index > 0 { XCTAssertNotEqual(Int(batch[index-1].geometry.actualAngle.rounded()), Int(measured.rounded())) }
            }
            if range == .mixed {
                XCTAssertEqual(batch.filter { $0.geometry.actualAngle.rounded() <= 10 }.count, 4)
                for band in [SceneTrainingConfiguration.AngleRange.small, .medium, .large, .thin] {
                    XCTAssertEqual(batch.filter { band.degrees.contains(Int($0.geometry.actualAngle.rounded())) }.count, 4)
                }
            }
        }
    }

    func testMultiSelectionAndLegacyConfigurationMigration() throws {
        let legacy = Data(#"{"freePractice":true,"angles":"thin","cueDistance":"long","pocketDistance":"mixed","pockets":"side"}"#.utf8)
        var config = try JSONDecoder().decode(SceneTrainingConfiguration.self, from: legacy)
        XCTAssertEqual(config.angleSelection, [.thin])
        XCTAssertEqual(config.cueDistanceSelection, [.long])
        XCTAssertEqual(config.railDistanceSelection, [.mixed])
        XCTAssertTrue(config.freePractice)
        XCTAssertTrue(SceneTrainingConfiguration.toggle(.small, random: .mixed, in: &config.angleSelection))
        XCTAssertEqual(config.angleSelection, [.thin, .small])
        XCTAssertTrue(SceneTrainingConfiguration.toggle(.mixed, random: .mixed, in: &config.angleSelection))
        XCTAssertEqual(config.angleSelection, [.mixed])
        XCTAssertFalse(SceneTrainingConfiguration.toggle(.mixed, random: .mixed, in: &config.angleSelection))
        XCTAssertEqual(try JSONDecoder().decode(SceneTrainingConfiguration.self, from: JSONEncoder().encode(config)), config)
        let invalid = Data(#"{"angleSelection":["mixed","small"]}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(SceneTrainingConfiguration.self, from: invalid))
    }

    func testMultipleFiltersAreConsumedAsUnionsWithinIntersection() throws {
        var config = SceneTrainingConfiguration()
        config.angleSelection = [.small, .large]
        config.cueDistanceSelection = [.short, .middle]
        config.pocketDistanceSelection = [.short]
        config.pocketSelection = [.corner]
        config.railDistanceSelection = [.near, .frozen]
        var generator = SceneTrainingGenerator(seed: 81020)
        let batch = try generator.batch(config)
        XCTAssertEqual(batch.count, 20)
        XCTAssertEqual(batch.filter { (11...30).contains(Int($0.geometry.actualAngle)) }.count, 10)
        XCTAssertEqual(batch.filter { (51...70).contains(Int($0.geometry.actualAngle)) }.count, 10)
        for item in batch {
            XCTAssertEqual(item.geometry.pocketType, .corner)
            XCTAssertTrue([SceneTrainingConfiguration.Distance.short, .middle].contains(item.cueBand))
            XCTAssertEqual(item.pocketBand, .short)
            let target = AngleSceneCalculator.normalizedToScene(point: item.geometry.targetBall, surfaceY: 0)
            XCTAssertTrue(SceneTrainingRailGeometry.matches(target, selection: [.near, .frozen]))
        }
    }

    func testRailFiltersUseSurfaceGapAndFrozenCandidatesAreGenerated() throws {
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: 0)
        let rail = geometry.linearCushions[0]
        let mid = (rail.start + rail.end) * 0.5
        let touching = mid + rail.normal * BallPhysics.radius
        let near = mid + rail.normal * (BallPhysics.radius + 0.05)
        let boundary = mid + rail.normal * (BallPhysics.radius + 0.10)
        let far = mid + rail.normal * (BallPhysics.radius + 0.101)
        XCTAssertTrue(SceneTrainingRailGeometry.matches(touching, selection: [.frozen]))
        XCTAssertFalse(SceneTrainingRailGeometry.matches(touching, selection: [.near]))
        XCTAssertTrue(SceneTrainingRailGeometry.matches(near, selection: [.near]))
        XCTAssertTrue(SceneTrainingRailGeometry.matches(boundary, selection: [.near]), "10cm is inclusive")
        XCTAssertFalse(SceneTrainingRailGeometry.matches(near, selection: [.frozen]))
        XCTAssertFalse(SceneTrainingRailGeometry.matches(far, selection: [.near, .frozen]))
        XCTAssertTrue(SceneTrainingRailGeometry.matches(far, selection: [.mixed]))
        var generator = SceneTrainingGenerator(seed: 81021)
        var count = 0
        for pocket in 0..<6 {
            if let item = generator.question(angle: 30, side: 1, pocket: pocket, cueBand: .short, pocketBand: .short, railSelection: [.frozen]) {
                count += 1
                let target = AngleSceneCalculator.normalizedToScene(point: item.geometry.targetBall, surfaceY: 0)
                XCTAssertTrue(SceneTrainingRailGeometry.matches(target, selection: [.frozen]))
                XCTAssertLessThanOrEqual(abs(SceneTrainingRailGeometry.clearance(target)), SceneTrainingRailGeometry.contactRoundoff)
            }
        }
        XCTAssertGreaterThan(count, 0, "Frozen generation cannot rely on a continuous random sample hitting zero")
    }

    func testRailClearanceIncludesFiniteEndpointsBesideMiddlePocket() {
        for sign: Float in [-1, 1] {
            let nearOpening = SCNVector3(0, 0, sign * 0.55)
            let expected = hypot(TablePhysics.sidePocketRadius + TablePhysics.sidePocketFilletRadius,
                                 TablePhysics.innerWidth / 2 - 0.55) - BallPhysics.radius
            XCTAssertEqual(SceneTrainingRailGeometry.clearance(nearOpening), expected, accuracy: 0.000001)
            XCTAssertTrue(SceneTrainingRailGeometry.matches(nearOpening, selection: [.near]))
            XCTAssertFalse(SceneTrainingRailGeometry.matches(nearOpening, selection: [.frozen]))
        }
        XCTAssertEqual(SceneTrainingRailGeometry.clearance(SCNVector3(-0.050163984, 0, -0.40629935)),
                       0.2012629, accuracy: 0.000001)
        XCTAssertEqual(SceneTrainingRailGeometry.clearance(SCNVector3(-0.06391573, 0, 0.013841867)),
                       0.5926496, accuracy: 0.000001)
    }

    func testLongDistanceHasNoNearestPocketFallback() throws {
        var generator = SceneTrainingGenerator(seed: 102)
        let item = try XCTUnwrap(generator.question(angle: 45, side: 1, pocket: 0, cueBand: .short, pocketBand: .long))
        let q = item.geometry
        let target = AngleSceneCalculator.normalizedToScene(point: q.targetBall, surfaceY: 0)
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: 0, surfaceY: 0)
        XCTAssertGreaterThan(AngleSceneCalculator.horizontalDistance(target, aim), 1.20)
        XCTAssertLessThanOrEqual(AngleSceneCalculator.horizontalDistance(target, aim), 1.80)
    }

    func testImpossibleCombinationFailsWithoutFallback() {
        var generator = SceneTrainingGenerator(seed: 42)
        // Straight cue+target distances exceed table diagonal when both are long toward a middle pocket.
        XCTAssertNil(generator.question(angle: 0, side: 0, pocket: 4, cueBand: .long, pocketBand: .long))
    }

    func testTransverseScoreMirrorsAndRejectsBackwardsMissAndWrongSide() throws {
        let radius = Double(AngleSceneCalculator.ballRadius)
        for mirror: Double in [-1, 1] {
            let cue = SCNVector3(0,0,0)
            let ghost = SCNVector3(1,0,0)
            let target = SCNVector3(1 + 2*radius*cos(.pi/6),0,mirror*2*radius*sin(.pi/6))
            for mm: Double in [-6,-2,0,2,6] {
                let direction = SCNVector3(1,0,-mirror * mm/1000)
                let score = SceneAimScore.measure(cue: cue,target: target,ghost: ghost,direction: direction)
                XCTAssertEqual(score.status,.valid)
                XCTAssertEqual(try XCTUnwrap(score.millimetres),mm,accuracy:0.001)
            }
            XCTAssertEqual(SceneAimScore.measure(cue:cue,target:target,ghost:ghost,direction:SCNVector3(-1,0,0)).status,.backwards)
            XCTAssertEqual(SceneAimScore.measure(cue:cue,target:target,ghost:ghost,direction:SCNVector3(1,0,-mirror*0.2)).status,.missesTarget)
            XCTAssertEqual(SceneAimScore.measure(cue:cue,target:target,ghost:ghost,direction:SCNVector3(1,0,mirror*0.05)).status,.wrongSide)
        }
        let straight = SceneAimScore.measure(cue:SCNVector3(0,0,0),target:SCNVector3(1.05715,0,0),ghost:SCNVector3(1,0,0),direction:SCNVector3(1,0,0.002))
        XCTAssertTrue(straight.straight)
        XCTAssertEqual(straight.label,"偏左")
    }

    func testTrueZeroAndThinContactUseTwoRadii() throws {
        var generator = SceneTrainingGenerator(seed: 77)
        for angle in [0,85] {
            let q = try XCTUnwrap(generator.question(angle:angle,side:angle == 0 ? 0 : -1,pocket:4,cueBand:.short,pocketBand:.short)).geometry
            XCTAssertEqual(q.actualAngle,Double(angle),accuracy:0.05)
            let cue = AngleSceneCalculator.normalizedToScene(point:q.cueBall,surfaceY:0)
            let target = AngleSceneCalculator.normalizedToScene(point:q.targetBall,surfaceY:0)
            let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall:target,pocketIndex:q.pocketIndex,surfaceY:0)
            let ghost = AngleSceneCalculator.ghostBallPosition(targetBall:target,pocket:aim,ballRadius:AngleSceneCalculator.ballRadius)
            XCTAssertEqual(SceneAimScore.measure(cue:cue,target:target,ghost:ghost,direction:SCNVector3(ghost.x-cue.x,0,ghost.z-cue.z)).status,.valid)
        }
    }
}

@MainActor
final class SceneTrainingPersistenceTests: XCTestCase {
    func testV5DiskStoreMigratesWithoutInventingLegacyAssistance() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:folder) }
        let url = folder.appendingPathComponent("migration.store")
        let id: UUID
        do {
            let schema = Schema(versionedSchema:QiuJiSchemaV5.self)
            let container = try ModelContainer(for:schema,configurations:[ModelConfiguration(schema:schema,url:url)])
            let context = ModelContext(container)
            let old = QiuJiSchemaV5.AngleTestResult(actualAngle:30,userAngle:29,pocketType:"corner",quizType:"scene2D")
            id = old.id; context.insert(old); try context.save()
        }
        let schema = ModelContainerFactory.currentSchema
        let container = try ModelContainer(for:schema,migrationPlan:QiuJiMigrationPlan.self,configurations:[ModelConfiguration(schema:schema,url:url)])
        let result = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<AngleTestResult>()).first)
        XCTAssertEqual(result.id,id); XCTAssertEqual(result.error,1)
        XCTAssertNil(result.trainingMetadataJSON)
        XCTAssertTrue(result.cohort.contains("辅助状态未知"))
    }

    func testMetadataDTORoundTripAndRepeatExclusion() throws {
        var generator = SceneTrainingGenerator(seed:15)
        var run = SceneTrainingRun(queue:try generator.batch(.init()))
        let question = try run.next()
        run.assistance.insert("angleHint")
        let metadata = try XCTUnwrap(run.metadata(unit:"mm",score:.init(status:.backwards,millimetres:nil,straight:false)))
        let record = AngleTestResult(actualAngle:0,userAngle:0,pocketType:"corner",quizType:"aimPoint2D")
        record.trainingMetadataJSON = metadata.json
        let dto = try JSONDecoder().decode(AngleTestDTO.self,from:JSONEncoder().encode(AngleTestDTO(from:record)))
        XCTAssertEqual(dto.trainingMetadataJSON,record.trainingMetadataJSON)
        XCTAssertNil(record.measurementError)
        let session = TrainingSession(kind:"cognitive")
        let item = CognitiveSessionItem.make(session:session,results:[record])
        XCTAssertEqual(item.measurementUnit,"mm")
        XCTAssertFalse(item.hasValidMeasurement)
        XCTAssertEqual(item.accurateCount,0)
        let history = AngleHistoryViewModel()
        history.allResults = [record]
        history.timeRange = .all
        XCTAssertEqual(history.rangeStats.count,5)
        XCTAssertEqual(history.rangeStats.compactMap(\.sampleCount).reduce(0,+),1)
        XCTAssertEqual(history.invalidCount,1)
        run.record(error:nil,signedError:nil,angle:question.actualAngle)
        run.record(error:0,signedError:0,angle:question.actualAngle)
        XCTAssertEqual(run.firstAnswers.count,1)
        XCTAssertEqual(run.assistance, ["angleHint"])
        XCTAssertTrue(try XCTUnwrap(run.metadata(unit:"mm")).firstAttempt)
    }
}

@MainActor
final class SceneTrainingLifecycleTests: XCTestCase {
    @MainActor private func waitForSave(_ busy: () -> Bool) async throws {
        for _ in 0..<200 {
            if !busy() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Answer persistence did not finish")
    }

    func testFifteenFirstAnswersKeepLastResultAndPremiumDoesNotConsumeQuota() async throws {
        let suite = "scene-lifecycle-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName:suite))
        defer { defaults.removePersistentDomain(forName:suite) }
        let limiter = AngleUsageLimiter(defaults:defaults); limiter.isPremium = true
        let vm = AimingQuizViewModel(limiter:limiter)
        vm.configure(repository: TrainingAnswerRepositoryStub())
        vm.setupScene(initialCameraMode:.topDown2D,autoStart:false)
        var generator = SceneTrainingGenerator(seed:15)
        vm.startTest(questions:try generator.batch(.init()))
        for index in 0..<15 {
            vm.openAnswerInput(); vm.userInput = "20"; vm.submitAnswer(); vm.submitAnswer()
            try await waitForSave { vm.isSaving }
            XCTAssertEqual(vm.phase,.showingResult)
            XCTAssertFalse(vm.testFinished)
            XCTAssertEqual(vm.run.firstAnswers.count,index+1)
            XCTAssertEqual(limiter.questionsUsedToday,0)
            if index < 14 { vm.advanceToNext() }
        }
        vm.openAnswerInput(); vm.userInput = "20"; vm.submitAnswer()
        XCTAssertEqual(vm.phase,.showingResult)
        XCTAssertEqual(vm.run.firstAnswers.count,15); XCTAssertEqual(limiter.questionsUsedToday,0)
        vm.advanceToNext(); XCTAssertTrue(vm.testFinished)
    }

    func testAimHintStickyAndQuotaKeepsResultWithoutMovingBalls() async throws {
        let suite = "scene-quota-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName:suite))
        defer { defaults.removePersistentDomain(forName:suite) }
        let limiter = AngleUsageLimiter(defaults: defaults, namespace: "aimPoint2D", limit: 15)
        for _ in 0..<14 { limiter.recordQuestion() }
        let vm = AimPointSceneQuizViewModel(limiter:limiter)
        vm.configure(repository: TrainingAnswerRepositoryStub())
        vm.setupScene(cameraMode:.topDown2D,autoStart:false)
        var generator = SceneTrainingGenerator(seed:15)
        vm.startTest(questions:try generator.batch(.init()))
        vm.toggleAngleHint(); vm.toggleAngleHint()
        XCTAssertEqual(vm.run.assistance,["angleHint"]); XCTAssertFalse(vm.showAngleHint)
        vm.nudgeAim(byDegrees:0.2)
        let before = try XCTUnwrap(vm.currentPlayerAim)
        let cue = try XCTUnwrap(vm.scene.cueBallNode).position
        vm.submit(); vm.submit()
        try await waitForSave { vm.isSaving }
        XCTAssertNotNil(vm.answerCloseupSnapshot?.standardAimLine)
        XCTAssertFalse(vm.finished, "Quota completion must not cover the last answer")
        let comparison = try XCTUnwrap(vm.answerCloseupSnapshot)
        XCTAssertEqual(limiter.questionsUsedToday,15)
        XCTAssertEqual(vm.currentPlayerAim?.x,before.x); XCTAssertEqual(vm.currentPlayerAim?.z,before.z)
        try await Task.sleep(nanoseconds:2_000_000_000)
        XCTAssertEqual(vm.phase,.showingResult)
        XCTAssertEqual(vm.scene.cueBallNode?.position.x,cue.x)
        XCTAssertEqual(vm.scene.cueBallNode?.position.z,cue.z)
        vm.submit()
        XCTAssertEqual(vm.phase,.showingResult)
        XCTAssertEqual(vm.answerCloseupSnapshot, comparison)
        XCTAssertEqual(limiter.questionsUsedToday,15); XCTAssertEqual(vm.run.firstAnswers.count,1)
        vm.nextQuestion(); XCTAssertTrue(vm.finished)
    }

    func testAimRetryKeepsFirstAnswerAndLastQuota() async throws {
        let suite = "aim-retry-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let limiter = AngleUsageLimiter(defaults: defaults, namespace: "aimPoint2D", limit: 15)
        for _ in 0..<14 { limiter.recordQuestion() }
        let vm = AimPointSceneQuizViewModel(limiter: limiter)
        vm.configure(repository: TrainingAnswerRepositoryStub())
        vm.setupScene(cameraMode: .topDown2D, autoStart: false)
        var generator = SceneTrainingGenerator(seed: 15)
        vm.startTest(questions: try generator.batch(.init()))
        vm.submit(); try await waitForSave { vm.isSaving }
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let first = try encoder.encode(vm.run.firstAnswers), question = vm.run.current?.id
        let direction = try XCTUnwrap(vm.currentPlayerAim)
        for _ in 0..<2 {
            XCTAssertTrue(vm.canRetry); vm.retry()
            XCTAssertEqual(vm.phase, .aiming); XCTAssertTrue(vm.run.submitted)
            XCTAssertNil(vm.answerCloseupSnapshot)
            XCTAssertEqual(vm.currentPlayerAim?.x, direction.x)
            vm.submit()
            XCTAssertEqual(vm.phase, .showingResult)
            XCTAssertEqual(vm.run.current?.id, question)
            XCTAssertEqual(try encoder.encode(vm.run.firstAnswers), first)
            XCTAssertEqual(limiter.questionsUsedToday, 15)
            XCTAssertFalse(vm.finished)
        }
        vm.nextQuestion(); XCTAssertTrue(vm.finished)
    }

    func testAimComparisonFreezesOfficialGeometryAndClearsOnNextQuestion() async throws {
        let suite = "aim-comparison-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let limiter = AngleUsageLimiter(defaults: defaults); limiter.isPremium = true
        let vm = AimPointSceneQuizViewModel(limiter: limiter)
        vm.configure(repository: TrainingAnswerRepositoryStub())
        vm.setupScene(cameraMode: .topDown2D, autoStart: false)
        var generator = SceneTrainingGenerator(seed: 15)
        vm.startTest(questions: try generator.batch(.init()))
        XCTAssertNil(vm.answerCloseupSnapshot)
        let cue = try XCTUnwrap(vm.scene.cueBallNode).position
        let target = try XCTUnwrap(vm.targetNode).position
        let q = try XCTUnwrap(vm.question)
        let pocket = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: q.pocketIndex, surfaceY: vm.scene.surfaceY)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: pocket, ballRadius: AngleSceneCalculator.ballRadius)
        vm.aimToward(worldPoint: ghost)
        vm.nudgeAim(byDegrees: 1)
        let submittedDirection = try XCTUnwrap(vm.currentPlayerAim)
        vm.submit()
        try await waitForSave { vm.isSaving }
        let answer = try XCTUnwrap(vm.answerCloseupSnapshot)
        let standard = try XCTUnwrap(answer.standardAimLine)
        let user = try XCTUnwrap(answer.aimLine)
        let cuePoint = CGPoint(x: CGFloat(cue.x), y: CGFloat(cue.z))
        XCTAssertEqual(standard.start, cuePoint)
        XCTAssertEqual(user.start, cuePoint)
        // Independently verify official and submitted directions; offset rays must not be parallel.
        let dx = CGFloat(ghost.x - cue.x), dz = CGFloat(ghost.z - cue.z)
        let sx = standard.end.x - cuePoint.x, sz = standard.end.y - cuePoint.y
        let ux = user.end.x - cuePoint.x, uz = user.end.y - cuePoint.y
        XCTAssertEqual(sx * dz - sz * dx, 0, accuracy: 1e-7)
        XCTAssertGreaterThan(sx * dx + sz * dz, 0)
        XCTAssertEqual(ux * CGFloat(submittedDirection.z) - uz * CGFloat(submittedDirection.x), 0, accuracy: 1e-7)
        XCTAssertGreaterThan(abs(ux * sz - uz * sx), 0.001)
        XCTAssertGreaterThan(hypot(sx, sz), hypot(CGFloat(target.x - cue.x), CGFloat(target.z - cue.z)))
        vm.nudgeAim(byDegrees: 20); vm.submit()
        XCTAssertEqual(vm.answerCloseupSnapshot, answer)
        XCTAssertEqual(vm.run.firstAnswers.count, 1)
        XCTAssertEqual(limiter.questionsUsedToday, 0)
        vm.nextQuestion()
        XCTAssertNil(vm.answerCloseupSnapshot)
        XCTAssertEqual(vm.phase, .aiming)
    }


}
