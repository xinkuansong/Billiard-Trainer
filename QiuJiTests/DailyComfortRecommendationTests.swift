import XCTest
import SceneKit
@testable import QiuJi

final class DailyComfortRecommendationTests: XCTestCase {
    private let y = BTTablePhysics.surfaceY
    private func p(_ x: Float, _ z: Float) -> SCNVector3 { .init(x, y + AngleSceneCalculator.ballRadius, z) }

    func testMeasuredRegionMirrorsBoundaryAndDoesNotApplyToUnknownTable() throws {
        let c = try XCTUnwrap(MiddlePocketRegion.production)
        // Frozen native boundary samples from the 623873-shot study, not recomputed from the production formula.
        for (distance, degrees) in [(0.08,66.9414626746),(0.30,71.6146809029),(0.60,72.4622358120),(1.20,72.8859321442)] {
            for side in [-1.0,1.0] { for hand in [-1.0,1.0] { for delta in [-0.005,0.005] {
                let a=(degrees+delta)*Double.pi/180
                let target=p(Float(hand*distance*sin(a)),Float(side*(c.halfWidth-distance*cos(a))))
                XCTAssertEqual(MiddlePocketRegion.assess(target:target,pocket:side<0 ? 4:5,calibration:c),delta<0 ? .inside:.outside)
            }}}
        }
        XCTAssertEqual(MiddlePocketRegion.assess(target:p(0,0),pocket:0,calibration:c),.uncalibrated)
        XCTAssertEqual(MiddlePocketRegion.assess(target:p(0,0),pocket:4,calibration:nil),.uncalibrated)
        var changed=TableGeometry.chineseEightBallQiuJi(surfaceY:y)
        changed.pockets[4].captureLip[0].x += 0.001
        XCTAssertNil(MiddlePocketRegion.calibration(table:changed,length:2.54,width:1.27,radius:0.028575))
        changed = TableGeometry.chineseEightBallQiuJi(surfaceY:y)
        let index = try XCTUnwrap(changed.circularCushions.firstIndex { abs($0.center.x) < 0.1 })
        let arc = changed.circularCushions[index]
        changed.circularCushions[index] = .init(center: arc.center, radius: arc.radius,
            startAngle: arc.startAngle + 0.01, endAngle: arc.endAngle, restitution: arc.restitution)
        XCTAssertNil(MiddlePocketRegion.calibration(table:changed,length:2.54,width:1.27,radius:0.028575))
    }

    func testRegionVetoIsPerPocketAndDoesNotChangeLegacyManualAssessment() throws {
        let cue=p(-0.8,-0.50), target=p(-0.45,-0.50)
        XCTAssertEqual(MiddlePocketRegion.assess(target:target,pocket:4,calibration:MiddlePocketRegion.production),.outside)
        XCTAssertNil(DailyShotRecommendation.candidate(cue:cue,target:target,targetKey:"_1",pocketIndex:4,
            obstacles:[],surfaceY:y))
        let others=(0..<6).compactMap { DailyShotRecommendation.candidate(cue:cue,target:target,
            targetKey:"_1",pocketIndex:$0,obstacles:[],surfaceY:y) }
        XCTAssertFalse(others.isEmpty)
        XCTAssertTrue(others.contains { $0.pocketIndex<4 })
    }

    func testFullRankingHasNoNearestOrSeventyFiveDegreeGateAndStableTies() throws {
        func candidate(_ key:String,_ pocket:Int,_ cut:Double,_ score:Double)->DailyShotRecommendation.Candidate {
            .init(targetKey:key,pocketIndex:pocket,aim:p(0,0),cutDegrees:cut,comfortScore:score)
        }
        let near=candidate("near",0,20,30),far=candidate("far",1,76,31)
        XCTAssertEqual(DailyShotRecommendation.best([near,far])?.targetKey,"far")
        let tied=candidate("far",2,10,31)
        XCTAssertEqual(DailyShotRecommendation.best([tied,far])?.pocketIndex,1)
        XCTAssertEqual(DailyShotRecommendation.best([far,tied],preferred:("far",2))?.pocketIndex,2)
        XCTAssertEqual(DailyShotRecommendation.best([candidate("low",0,88,0.000001)])?.targetKey,"low")
        XCTAssertNil(DailyShotRecommendation.best([]))
    }

    func testCandidateUsesSameAimForDistanceScoreAndBlockedSegments() throws {
        let cue=p(-0.4,0),target=p(0,0)
        let candidate=try XCTUnwrap(DailyShotRecommendation.candidate(cue:cue,target:target,targetKey:"_1",
            pocketIndex:1,obstacles:[],surfaceY:y))
        let score=try XCTUnwrap(ShotComfortScore.evaluate(cue:(Double(cue.x),Double(cue.z)),ball:(0,0),
            aim:(Double(candidate.aim.x),Double(candidate.aim.z))))
        XCTAssertEqual(try XCTUnwrap(candidate.comfortScore),score.total,accuracy:1e-12)
        XCTAssertEqual(candidate.targetPocketDistance,hypot(Double(candidate.aim.x),Double(candidate.aim.z)),accuracy:1e-12)
        XCTAssertNil(DailyShotRecommendation.candidate(cue:cue,target:target,targetKey:"_1",
            pocketIndex:1,obstacles:[p(-0.2,0)],surfaceY:y))
        XCTAssertNil(ShotComfortScore.evaluate(cue:(.nan,0),ball:(0,0),aim:(1,0)))
        XCTAssertNil(ShotComfortScore.evaluate(cue:(-0.4,0),ball:(0,0),aim:(0,0)))
        XCTAssertNil(ShotComfortScore.evaluate(cue:(0.4,0),ball:(0,0),aim:(1,0)))
    }

    func testCommittedAimSurvivesSerializationAndPrediction() throws {
        let cue=p(-0.4,0),target=p(0,0)
        let c=try XCTUnwrap(DailyShotRecommendation.candidate(cue:cue,target:target,targetKey:"_1",
            pocketIndex:1,obstacles:[],surfaceY:y))
        func canvas(_ p:SCNVector3)->CanvasPoint {let q=AngleSceneCalculator.sceneToNormalized(position:p);return .init(x:Double(q.x),y:Double(q.y))}
        let shot=PlannedShot(targetKey:"_1",pocket:"topRight",velocity:1.5,pocketAim:canvas(c.aim))
        let copy=try JSONDecoder().decode(PlannedShot.self,from:JSONEncoder().encode(shot))
        let board=BoardSnapshot(onTable:[PositionPlayBall.cueKey:canvas(cue),"_1":canvas(target)])
        let pred=try XCTUnwrap(PositionPlayShotSolver.solve(before:board,shot:copy,surfaceY:y))
        XCTAssertEqual(pred.pocketAimPoint.x,c.aim.x,accuracy:1e-6)
        XCTAssertEqual(pred.pocketAimPoint.z,c.aim.z,accuracy:1e-6)
        let legacy=try JSONDecoder().decode(PlannedShot.self,from:Data(#"{"targetKey":"_1","pocket":"topRight","velocity":1.5,"spinX":0,"spinY":0}"#.utf8))
        XCTAssertNil(legacy.pocketAim)
    }

    @MainActor
    func testDailyVMSelectsLegalGlobalWinnerAndKeepsManualChoiceAcrossCamera() async throws {
        let vm=PositionPlayViewModel();vm.setupScene();defer{vm.cancelDailyAttempt()}
        vm.usesShotComfortRanking=true;vm.usesAutomaticPocketFallback=true
        vm.legalAimTargets={ $0.intersection(["_1","_2"]) }
        let positions=[PositionPlayBall.cueKey:p(-0.5,0.1),"_1":p(-0.2,0.4),"_2":p(0.3,0),"_9":p(0.8,-0.3)]
        let board=BoardSnapshot(onTable:positions.mapValues {let q=AngleSceneCalculator.sceneToNormalized(position:$0);return CanvasPoint(x:Double(q.x),y:Double(q.y))})
        vm.loadBoard(board)
        let candidates=["_1","_2"].flatMap { key in (0..<6).compactMap { pocket in
            DailyShotRecommendation.candidate(cue:positions[PositionPlayBall.cueKey]!,target:positions[key]!,targetKey:key,
                pocketIndex:pocket,obstacles:positions.filter{$0.key != key && $0.key != PositionPlayBall.cueKey}.map{$0.value},surfaceY:y)
        }}
        let best=try XCTUnwrap(DailyShotRecommendation.best(candidates))
        XCTAssertEqual(vm.selectedTargetKey,best.targetKey);XCTAssertEqual(vm.selectedPocketIndex,best.pocketIndex)
        func ready() async throws {
            let end=Date().addingTimeInterval(20)
            while Date()<end && (vm.isComputing || vm.solvedShot==nil) {try await Task.sleep(for:.milliseconds(50))}
            XCTAssertNotNil(vm.solvedShot)
        }
        try await ready()
        XCTAssertNotNil(vm.solvedShot?.shot.pocketAim)
        XCTAssertEqual(vm.solvedShot?.prediction.pocketAimPoint.x ?? 99,best.aim.x,accuracy:1e-6)
        XCTAssertTrue(vm.selectTarget(key:"_1"));let manualPocket=vm.selectedPocketIndex
        vm.cameraMode = .perspective3D;vm.cameraMode = .topDown2DRotated;vm.refreshLegalAimSelection()
        try await ready()
        XCTAssertEqual(vm.selectedTargetKey,"_1");XCTAssertEqual(vm.selectedPocketIndex,manualPocket)
        XCTAssertEqual(vm.entryTiming["physicalRecommendationCalls"],0)
    }

    func testFarTableInteriorStillHasDirectMiddlePocketWitness() throws {
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: y)
        // Opposite-half corners extend beyond the original 1.28 m radial sweep.
        for side: Float in [-1, 1] { for hand: Float in [-1, 1] {
            let start = p(hand * 1.20, -side * 0.57)
            let pocket = side < 0 ? 4 : 5
            XCTAssertEqual(MiddlePocketRegion.assess(target: start, pocket: pocket,
                calibration: MiddlePocketRegion.production), .inside)
            let aim = p(0, side * AngleSceneCalculator.innerWidth / 2)
            let delta = aim - start, velocity = delta * (3 / delta.length())
            let engine = EventDrivenEngine(tableGeometry: geometry)
            engine.setBall(BallState(position: start, velocity: velocity,
                angularVelocity: SCNVector3(0, 1, 0).cross(velocity) * (1 / AngleSceneCalculator.ballRadius),
                state: .rolling, name: "_8"))
            _ = engine.simulatePrediction(model: .appDefault, maxEvents: 500, maxTime: 45, highFidelityBounds: true)
            XCTAssertTrue(engine.resolvedEvents.contains { event in
                if case .pocket(_, let id) = event { return id == "pocket_\(pocket)" }
                return false
            })
        }}
    }

    func testReviewFixturesExportActualOldAndNewRecommendations() throws {
        let ring = (0..<8).map { index -> SCNVector3 in
            let a = Float(index) * .pi / 4
            return p(-0.5 + 0.08 * cos(a), 0.08 * sin(a))
        }
        let fixtures: [(String, SCNVector3, [String: SCNVector3], Set<String>)] = [
            ("shallow-middle", p(-0.8,-0.50), ["_1":p(-0.45,-0.50),"_2":p(0.3,0.1)], ["_1","_2"]),
            ("near-versus-easy", p(-0.5,0.1), ["_1":p(-0.2,0.4),"_2":p(0.3,0)], ["_1","_2"]),
            ("near-pocket", p(0.1,0.1), ["_1":p(1.05,-0.48),"_2":p(0.6,0.2)], ["_1","_2"]),
            ("blocked", p(-0.8,0), ["_1":p(0,0),"_2":p(-0.4,0),"_9":p(0.6,-0.3)], ["_1","_2"]),
            ("long-shot", p(-1.1,-0.4), ["_1":p(1,0.4)], ["_1"]),
            ("rule-limited", p(-0.5,0.1), ["_1":p(-0.2,0.4),"_2":p(0.3,0),"_9":p(0.8,-0.3)], ["_1"]),
            ("no-route", p(-0.5,0), Dictionary(uniqueKeysWithValues:
                [("_1",p(0.8,0))] + ring.enumerated().map { ("_\($0.offset+2)",$0.element) }), ["_1"])
        ]
        for (name, cue, balls, legal) in fixtures {
            let ordered = legal.sorted {
                AngleSceneCalculator.horizontalDistance(cue,balls[$0]!) < AngleSceneCalculator.horizontalDistance(cue,balls[$1]!)
            }
            func obstacles(_ key: String) -> [SCNVector3] { balls.filter { $0.key != key }.map { $0.value } }
            let old = AngleSceneCalculator.recommendDailyTarget(orderedKeys: ordered) { key in
                (0..<6).compactMap { AngleSceneCalculator.dailyPocketCandidate(cue: cue, target: balls[key]!,
                    targetKey: key, pocketIndex: $0, obstacles: obstacles(key), surfaceY: y) }
            }
            let candidates = ordered.flatMap { key in (0..<6).compactMap {
                DailyShotRecommendation.candidate(cue: cue, target: balls[key]!, targetKey: key,
                    pocketIndex: $0, obstacles: obstacles(key), surfaceY: y)
            }}
            let best = DailyShotRecommendation.best(candidates)
            func pair(_ key: String, _ pocket: Int, _ aim: SCNVector3) -> [String: Any] {
                let b = balls[key]!
                let score = ShotComfortScore.evaluate(cue: (Double(cue.x),Double(cue.z)),
                    ball: (Double(b.x),Double(b.z)), aim: (Double(aim.x),Double(aim.z)))
                return ["target":key,"pocket":pocket,"aim":[Double(aim.x),Double(aim.z)],"W":score?.total ?? 0]
            }
            var outcomes: [[String: Any]] = []
            if let best {
                for speed: Float in [1.5, 3] {
                    var input = ShotInput(cueBall: cue, targetBall: balls[best.targetKey]!, pocketIndex: best.pocketIndex,
                        velocity: speed, spinX: 0, spinY: 0, surfaceY: y,
                        obstacles: balls.filter { $0.key != best.targetKey }.map { ObstacleBall(name: $0.key, position: $0.value) })
                    input.pocketAimOverride = best.aim
                    let prediction = ShotPredictor.predictForPositionSolve(input)
                    if name == "near-pocket" {
                        XCTAssertTrue(prediction.objectPocketed, "Reject the high-score jaw-tip ray that misses capture")
                    }
                    outcomes.append(["speed":Double(speed),"potted":prediction.objectPocketed,
                        "aim":[Double(prediction.pocketAimPoint.x),Double(prediction.pocketAimPoint.z)]])
                }
            }
            let record: [String: Any] = ["name":name, "predictionChecks":outcomes,"cue":[Double(cue.x),Double(cue.z)],
                "balls":balls.mapValues { [Double($0.x),Double($0.z)] },"legal":legal.sorted(),
                "old":old.map { pair($0.targetKey,$0.pocketIndex,$0.aim) } as Any? ?? NSNull(),
                "new":best.map { pair($0.targetKey,$0.pocketIndex,$0.aim) } as Any? ?? NSNull(),
                "candidateCount":candidates.count]
            if name == "no-route" { XCTAssertNil(best) }
            if let best { XCTAssertTrue(legal.contains(best.targetKey)) }
            let data = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
            print("DAILY_RECOMMENDATION_FIXTURE " + String(decoding: data, as: UTF8.self))
        }
    }


    func testNewRecommendationRetainsNearRailCornerCandidates() {
        for (sx, sz, pocket) in [(Float(-1), Float(1), 0), (1, 1, 1), (-1, -1, 2), (1, -1, 3)] {
            for z in [-0.594, -0.58, -0.56, -0.54] as [Float] {
                for x in [0.4, 0.516, 0.7, 0.9] as [Float] {
                    XCTAssertNotNil(DailyShotRecommendation.candidate(cue: p(0.067 * sx, -0.313 * sz),
                        target: p(x * sx, z * sz), targetKey: "_13", pocketIndex: pocket, obstacles: [], surfaceY: y))
                }
            }
        }
    }


    @MainActor
    func testNoCandidateEntersTemporaryFreeAndRecoversOnNewBoard() {
        let vm = PositionPlayViewModel(); vm.setupScene(); defer { vm.cancelDailyAttempt() }
        vm.usesShotComfortRanking = true; vm.usesAutomaticPocketFallback = true
        vm.legalAimTargets = { $0.intersection(["_1"]) }
        func load(_ positions: [String: SCNVector3]) {
            vm.loadBoard(BoardSnapshot(onTable: positions.mapValues {
                let n = AngleSceneCalculator.sceneToNormalized(position: $0)
                return CanvasPoint(x: Double(n.x), y: Double(n.y))
            }))
        }
        var blocked = [PositionPlayBall.cueKey: p(-0.5,0), "_1":p(0.8,0)]
        for i in 0..<8 { let a = Float(i) * .pi / 4; blocked["_\(i+2)"] = p(-0.5+0.08*cos(a),0.08*sin(a)) }
        load(blocked)
        XCTAssertEqual(vm.selectedTargetKey,"_1"); XCTAssertEqual(vm.selectedPocketIndex,-1)
        XCTAssertEqual(vm.aimMode,.free)
        load([PositionPlayBall.cueKey:p(-0.4,0),"_1":p(0,0)])
        XCTAssertEqual(vm.selectedTargetKey,"_1"); XCTAssertGreaterThanOrEqual(vm.selectedPocketIndex,0)
        XCTAssertEqual(vm.aimMode,.pocket)
    }

    func testProductionRankingTimingForFullBoards() {
        var seed: UInt64 = 20261026
        func unit() -> Float { seed = seed &* 6364136223846793005 &+ 1; return Float(seed >> 40) / Float(1 << 24) }
        var samples: [Double] = [], selected = 0
        for _ in 0..<80 {
            var points: [SCNVector3] = []
            while points.count < 16 {
                let point = p((unit()-0.5)*2.4,(unit()-0.5)*1.14)
                if points.allSatisfy({ AngleSceneCalculator.horizontalDistance($0,point) > 0.06 }) { points.append(point) }
            }
            let start = Date.timeIntervalSinceReferenceDate
            let candidates = (1..<16).flatMap { i in (0..<6).compactMap { pocket in
                DailyShotRecommendation.candidate(cue: points[0], target: points[i], targetKey: "_\(i)",
                    pocketIndex: pocket, obstacles: (1..<16).filter { $0 != i }.map { points[$0] }, surfaceY: y)
            }}
            if DailyShotRecommendation.best(candidates) != nil { selected += 1 }
            samples.append((Date.timeIntervalSinceReferenceDate-start)*1000)
        }
        XCTAssertGreaterThan(selected,0)
        samples.sort()
        print("DAILY_PRODUCTION_TIMING debugSimulator boards=80 balls=15 meanMs=\(samples.reduce(0,+)/Double(samples.count)) p95Ms=\(samples[75]) maxMs=\(samples.last!)")
    }

}

/// Exercise the actual page connection and practice controllers, not a test-only opt-in.
@MainActor
final class ShotRecommendationReuseTests: XCTestCase {
    private func connect(_ vm: PositionPlayViewModel, mode: FreePlayEntryMode,
                         rules: FreePlayRulesSession, daily: DailyClearanceController,
                         notices: BTRuleNoticeCenter, editor: Bool = false, tryout: Bool = false) {
        FreePlayRulesSession.connect(vm: vm, rules: rules, daily: daily, notices: notices,
                                     mode: mode, isEditor: editor, isTryout: tryout)
        vm.setupScene(loadsDefaultLayout: false)
    }

    private var reviewBoard: BoardSnapshot {
        // Existing native pot witness: farther _1/topRight outranks nearer _2/bottomRight.
        let points: [String: SCNVector3] = [PositionPlayBall.cueKey: .init(0.1, 0, 0.1),
                                          "_1": .init(1.05, 0, -0.48), "_2": .init(0.6, 0, 0.2)]
        return .init(onTable: points.mapValues {
            let p = AngleSceneCalculator.sceneToNormalized(position: $0)
            return .init(x: Double(p.x), y: Double(p.y))
        })
    }

    func testFreePlayAndToolUseComfortFromFirstBoardAndPreserveManualIntent() async throws {
        for mode in [FreePlayEntryMode.standard, .shotSimulation] {
            let vm = PositionPlayViewModel(), rules = FreePlayRulesSession()
            let daily = DailyClearanceController(), notices = BTRuleNoticeCenter()
            connect(vm, mode: mode, rules: rules, daily: daily, notices: notices)
            defer { vm.cancelDailyAttempt() }
            vm.loadBoard(reviewBoard)
            XCTAssertEqual(vm.selectedTargetKey, "_1")
            XCTAssertEqual(vm.selectedPocketIndex, 1)
            let end = Date().addingTimeInterval(20)
            while Date() < end && (vm.isComputing || vm.solvedShot == nil) {
                try await Task.sleep(for: .milliseconds(50))
            }
            let solved = try XCTUnwrap(vm.solvedShot)
            let aim = try XCTUnwrap(solved.shot.pocketAim)
            let world = PositionPlayShotSolver.scenePoint(aim, surfaceY: vm.scene.surfaceY)
            XCTAssertEqual(solved.prediction.pocketAimPoint.x, world.x, accuracy: 1e-6)
            XCTAssertEqual(solved.prediction.pocketAimPoint.z, world.z, accuracy: 1e-6)
            XCTAssertTrue(vm.selectTarget(key: "_2"))
            let pocket = vm.selectedPocketIndex
            vm.velocity = 3; vm.cameraMode = .perspective3D
            vm.refreshLegalAimSelection()
            XCTAssertEqual(vm.selectedTargetKey, "_2")
            XCTAssertEqual(vm.selectedPocketIndex, pocket)
            vm.nudgeFreeAim(byDegrees: 1)
            let direction = vm.freeAimDir
            vm.refreshLegalAimSelection()
            XCTAssertEqual(vm.aimMode, .free)
            XCTAssertEqual(vm.freeAimDir?.x, direction?.x)
            XCTAssertEqual(vm.freeAimDir?.z, direction?.z)
            vm.setPreferredAimMode(.free)
            vm.loadBoard(reviewBoard)
            XCTAssertEqual(vm.preferredAimMode, .free)
            XCTAssertEqual(vm.aimMode, .free)
            // Free mode may retain a dormant pocket for returning to assisted aim.
            // Verify the actual requested shot, rather than that internal selection slot.
            XCTAssertEqual(vm.aimSelectionLabel(orientation: .landscape), "自由")
            let freeDeadline = Date().addingTimeInterval(20)
            while Date() < freeDeadline && (vm.isComputing || vm.solvedShot?.shot.isFree != true) {
                try await Task.sleep(for: .milliseconds(50))
            }
            XCTAssertTrue(try XCTUnwrap(vm.solvedShot).shot.isFree)
            XCTAssertEqual(vm.entryTiming["physicalRecommendationCalls"], 0)
        }
    }

    func testFreePlayReevaluatesActualRuleSetWithoutChangingIllegalManualSelection() throws {
        let vm = PositionPlayViewModel(), rules = FreePlayRulesSession()
        let daily = DailyClearanceController(), notices = BTRuleNoticeCenter()
        connect(vm, mode: .standard, rules: rules, daily: daily, notices: notices)
        defer { vm.cancelDailyAttempt() }
        // Swap labels: unrestricted comfort picks _2, rotation must select _1.
        var board = reviewBoard
        let first = board.onTable["_1"]
        board.onTable["_1"] = board.onTable["_2"]; board.onTable["_2"] = first
        vm.loadBoard(board)
        XCTAssertEqual(vm.selectedTargetKey, "_2")
        XCTAssertTrue(vm.selectTarget(key: "_2"))
        rules.rules = ZhuifenRules()
        vm.refreshLegalAimSelection()
        XCTAssertEqual(vm.selectedTargetKey, "_1")
        let pocket = vm.selectedPocketIndex
        XCTAssertFalse(vm.selectTarget(key: "_2"))
        XCTAssertEqual(vm.selectedPocketIndex, pocket)
        rules.rules = nil
        vm.refreshLegalAimSelection()
        XCTAssertEqual(vm.selectedTargetKey, "_2")
    }

    func testMultiBallControllersConstrainRankingAndRestartSameBoard() throws {
        let suite = "ShotRecommendationReuseTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        for game in [MultiBallConfiguration.Game.rotation, .chineseEight] {
            let vm = PositionPlayViewModel(), rules = FreePlayRulesSession()
            let daily = DailyClearanceController(), notices = BTRuleNoticeCenter()
            connect(vm, mode: .multiBallPractice, rules: rules, daily: daily, notices: notices)
            defer { vm.cancelDailyAttempt() }
            var config = MultiBallConfiguration(); config.game = game
            config.randomOpponents = true
            let controller = MultiBallPracticeController(configuration: config, defaults: defaults)
            controller.premiumProvider = { true }
            controller.attach(to: vm)
            XCTAssertNotNil(controller.rack)
            let first = try XCTUnwrap(vm.selectedTargetKey)
            XCTAssertTrue(controller.legalKeys.contains(first))
            if game == .rotation { XCTAssertEqual(first, "_1") }
            else {
                XCTAssertNotEqual(first, "_8")
                for key in try XCTUnwrap(controller.rack).opponentKeys { XCTAssertFalse(vm.selectTarget(key: key)) }
                XCTAssertFalse(vm.selectTarget(key: "_8"))
            }
            let board = vm.currentSnapshot(), pocket = vm.selectedPocketIndex
            controller.restart()
            XCTAssertEqual(Set(vm.currentSnapshot().onTable.keys), Set(board.onTable.keys))
            for (key, point) in board.onTable {
                XCTAssertEqual(vm.currentSnapshot().onTable[key]?.x ?? -1, point.x, accuracy: 1e-6)
                XCTAssertEqual(vm.currentSnapshot().onTable[key]?.y ?? -1, point.y, accuracy: 1e-6)
            }
            XCTAssertEqual(vm.selectedTargetKey, first)
            XCTAssertEqual(vm.selectedPocketIndex, pocket)
            XCTAssertTrue(vm.usesShotComfortRanking)
        }
    }

    func testSnakeRecommendsOnlyRequiredBallAfterControllerAdvances() throws {
        let suite = "ShotRecommendationSnake.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = PositionPlayViewModel(), rules = FreePlayRulesSession()
        let daily = DailyClearanceController(), notices = BTRuleNoticeCenter()
        connect(vm, mode: .snakePractice, rules: rules, daily: daily, notices: notices)
        defer { vm.cancelDailyAttempt() }
        let history = SnakePracticeHistory(defaults: defaults)
        let controller = SnakePracticeController(history: history, defaults: defaults)
        controller.attach(to: vm)
        XCTAssertEqual(vm.selectedTargetKey, "_1")
        XCTAssertFalse(vm.selectTarget(key: "_2"))
        let before = vm.currentSnapshot()
        var prediction = ShotPrediction(); prediction.termination = .settled
        prediction.events = [.init(time: 0, kind: .ballBall(ballA: ShotInput.cueBallName, ballB: ShotInput.targetBallName))]
        prediction.pocketedBalls = [ShotInput.targetBallName]
        vm.onShotWillStart?()
        vm.onCommittedPracticeShot?(.init(before: before,
            shot: .init(targetKey: "_1", pocket: "topCenter", velocity: 2), prediction: prediction))
        var after = before; after.onTable.removeValue(forKey: "_1")
        vm.loadBoard(after)
        XCTAssertEqual(controller.targetKey, "_2")
        XCTAssertEqual(vm.selectedTargetKey, "_2")
        XCTAssertFalse(vm.selectTarget(key: "_3"))
        XCTAssertTrue(vm.usesShotComfortRanking)
    }

    func testEditorAndGuidedTryoutKeepAuthoredSequenceAndLegacyPolicy() throws {
        let formation = try XCTUnwrap(DrillTryoutBoardStore.formations(for: "drill_c029").first)
        for tryout in [false, true] {
            let vm = PositionPlayViewModel(), rules = FreePlayRulesSession()
            let daily = DailyClearanceController(), notices = BTRuleNoticeCenter()
            connect(vm, mode: .standard, rules: rules, daily: daily, notices: notices, editor: true, tryout: tryout)
            defer { vm.exitSequenceMode(); vm.cancelDailyAttempt() }
            XCTAssertFalse(vm.usesShotComfortRanking)
            vm.isGuidedTryout = tryout
            vm.configureSequence(formation.steps)
            vm.enterSequenceMode()
            let target = vm.selectedTargetKey, pocket = vm.selectedPocketIndex
            vm.refreshLegalAimSelection()
            XCTAssertEqual(vm.selectedTargetKey, target)
            XCTAssertEqual(vm.selectedPocketIndex, pocket)
            XCTAssertTrue(vm.hasSequence)
            XCTAssertEqual(vm.selectedTargetKey, formation.steps[0].shot.targetKey)
            XCTAssertEqual(vm.selectedPocketIndex, ShotIntent.pocketIndex(for: formation.steps[0].shot.pocket))
            if tryout {
                vm.enterTryoutFreeMode(aimMode: .pocket)
                for (index, expected) in formation.steps.enumerated() {
                    if index > 0 { vm.moveTryoutStep(by: 1) }
                    vm.refreshLegalAimSelection()
                    XCTAssertEqual(vm.sequenceStepIndex, index)
                    XCTAssertEqual(vm.selectedTargetKey, expected.shot.targetKey)
                    XCTAssertEqual(vm.selectedPocketIndex, ShotIntent.pocketIndex(for: expected.shot.pocket))
                    XCTAssertEqual(vm.velocity, expected.shot.velocity)
                    XCTAssertEqual(vm.spinX, expected.shot.spinX)
                    XCTAssertEqual(vm.spinY, expected.shot.spinY)
                }
                XCTAssertFalse(vm.canGoToNextTryoutStep)
            }
        }
    }
}
