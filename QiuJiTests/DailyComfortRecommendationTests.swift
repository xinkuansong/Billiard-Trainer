import XCTest
import Combine
import SceneKit
import simd
@testable import QiuJi

final class DailyComfortRecommendationTests: XCTestCase {
    private let y = BTTablePhysics.surfaceY
    private func p(_ x: Float, _ z: Float) -> SCNVector3 { .init(x, y + AngleSceneCalculator.ballRadius, z) }

    @MainActor
    func testDailyNearRailSideObservationCanEnterFirstPerson() throws {
        let (vm, rig) = try dailyNearRailObservation(cueZ: 0.635, eightZ: 0.7874)
        let before = try XCTUnwrap(rig.p01Snapshot)
        XCTAssertGreaterThan(abs(before.state.observationYaw), 0.01)
        let aim = try XCTUnwrap(vm.playerViewDirection)
        XCTAssertNil(vm.scene.cueStrikeAccess(aim: aim)?.resolvedPose(spinX: vm.spinX, spinY: vm.spinY))
        let board = vm.currentSnapshot()
        let accepted = vm.requestPlayerView(.firstPerson)
        XCTAssertTrue(accepted, rig.p01CameraDiagnostic ?? "No first-person camera")
        for _ in 0..<480 { rig.update(deltaTime: 1 / 120) }
        XCTAssertEqual(rig.playerView, .firstPerson)
        XCTAssertTrue(try XCTUnwrap(vm.scene.cueStick).rootNode.isHidden)
        XCTAssertNil(vm.currentPlayerAim)
        XCTAssertEqual(vm.currentSnapshot().onTable.mapValues { [$0.x, $0.y] },
                       board.onTable.mapValues { [$0.x, $0.y] })
        XCTAssertEqual(vm.selectedTargetKey, "_1")
        XCTAssertEqual(vm.selectedPocketIndex, -1)

        let rendered = try XCTUnwrap(rig.p01Snapshot)
        XCTAssertEqual(rendered.shot.observationOnlyAddress, true)
        XCTAssertLessThanOrEqual(rendered.state.firstPersonClearanceLift, 0.65)
        XCTAssertLessThan(simd_distance(rendered.shot.aim, SIMD3<Float>(aim)), 0.0001)
        let bytes = try XCTUnwrap(rig.p01ReplayData)
        let recording = try JSONDecoder().decode(P01CameraMotion.Recording.self, from: bytes)
        XCTAssertTrue(recording.layout.legalEye(rendered.pose.eye))
        XCTAssertTrue(recording.samples.allSatisfy { recording.layout.legalEye($0.pose.eye) })
        let clear = try XCTUnwrap(rig.twoViewTableSightlinesClear)
        XCTAssertTrue(clear(rendered.pose.eye, P01CameraMotion.observationSightlineTargets(
            shot: rendered.shot, radius: recording.layout.ballRadius)))
        var replay = try XCTUnwrap(P01CameraMotion(recording: recording))
        for input in recording.inputs { replay.apply(input) }
        replay.advance(to: rendered.time)
        XCTAssertLessThan(simd_distance(replay.pose.eye, rendered.pose.eye), 0.0001)
        XCTAssertLessThan(simd_distance(replay.pose.forward, rendered.pose.forward), 0.0001)

    }

    @MainActor
    func testDailyLegalNearRailSideObservationCanEnterFirstPerson() throws {
        let legalCueZ = AngleSceneCalculator.innerWidth / 2 - AngleSceneCalculator.ballRadius
        let (vm, rig) = try dailyNearRailObservation(cueZ: legalCueZ, eightZ: 0.4)
        let cue = try XCTUnwrap(vm.scene.cueBallNode).position
        XCTAssertEqual(cue.z, legalCueZ, accuracy: 0.0001)
        let board = vm.currentSnapshot().onTable.mapValues { [$0.x, $0.y] }
        let aim = try XCTUnwrap(vm.playerViewDirection)
        let shaft = try XCTUnwrap(vm.scene.cueStrikeAccess(aim: aim)?.resolvedPose(spinX: vm.spinX, spinY: vm.spinY))
        XCTAssertTrue(vm.requestPlayerView(.firstPerson, animated: false), rig.p01CameraDiagnostic ?? "No first-person camera")
        let camera = try XCTUnwrap(rig.p01Snapshot)
        XCTAssertEqual(rig.playerView, .firstPerson)
        XCTAssertEqual(vm.currentSnapshot().onTable.mapValues { [$0.x, $0.y] }, board)
        XCTAssertLessThan(simd_distance(camera.shot.aim, SIMD3<Float>(aim)), 0.0001)
        XCTAssertNil(camera.shot.observationOnlyAddress)
        XCTAssertLessThan(simd_distance(camera.shot.strike, SIMD3<Float>(shaft.pivot)), 0.0001)
        XCTAssertEqual(camera.shot.elevation, shaft.elevation, accuracy: 0.0001)
        XCTAssertEqual(camera.shot.addressButtOffset,
                       vm.scene.cueStick?.addressButtOffset(tipInset: shaft.inset))
    }

    @MainActor
    func testDailyVisibleCueFirstPersonUsesRealShaftAtRailAndCenter() throws {
        let legalCueZ = AngleSceneCalculator.innerWidth / 2 - AngleSceneCalculator.ballRadius
        for cueZ in [legalCueZ, 0] {
            let (vm, rig) = try dailyNearRailObservation(cueZ: cueZ, eightZ: 0.4)
            let cue = try XCTUnwrap(vm.scene.cueBallNode).position
            let aim = try XCTUnwrap(vm.playerViewDirection)
            let shaft = try XCTUnwrap(vm.scene.cueStrikeAccess(aim: aim)?.resolvedPose(spinX: 0, spinY: 0))
            vm.scene.updateCueStick(cueBallPosition: shaft.pivot, aimDirection: aim,
                elevationOverride: shaft.elevation, tipInsetOverride: shaft.inset)
            let stick = try XCTUnwrap(vm.scene.cueStick)
            XCTAssertFalse(stick.rootNode.isHidden)
            XCTAssertTrue(rig.enterPlayerView(.firstPerson, cue: cue, aim: aim, duration: 0),
                          rig.p01CameraDiagnostic ?? "No first-person camera for a visible shaft")
            let address = try XCTUnwrap(rig.p01Snapshot)
            XCTAssertEqual(rig.playerView, .firstPerson)
            XCTAssertNil(address.shot.observationOnlyAddress)
            XCTAssertEqual(address.shot.addressButtOffset, stick.addressButtOffset)
            XCTAssertEqual(address.shot.elevation, shaft.elevation, accuracy: 0.0001)
            if cueZ == 0 { XCTAssertEqual(address.state.firstPersonClearanceLift, 0, accuracy: 0.0001) }
        }
    }

    @MainActor
    private func dailyNearRailObservation(cueZ: Float, eightZ: Float) throws -> (PositionPlayViewModel, CameraRig) {
        let vm = PositionPlayViewModel()
        vm.scene.configureDailyClearanceRendering()
        vm.setupScene(loadsDefaultLayout: false)
        vm.enablePlayerCameraControls(policy: .p01Replayable)
        vm.automaticRecommendationEnabled = false
        vm.setPreferredAimMode(.pocket)
        let positions: [String: SCNVector3] = [
            PositionPlayBall.cueKey: p(0.5588001, cueZ),
            "_1": p(-0.50799996, 0.4318),
            "_8": p(-0.17779994, eightZ)
        ]
        vm.loadBoard(.init(onTable: positions.mapValues {
            let value = AngleSceneCalculator.sceneToNormalized(position: $0)
            return CanvasPoint(x: Double(value.x), y: Double(value.y))
        }))
        XCTAssertTrue(vm.selectTarget(key: "_1"))
        XCTAssertEqual(vm.aimMode, .pocket)
        XCTAssertNil(vm.currentPlayerAim)
        XCTAssertTrue(try XCTUnwrap(vm.scene.cueStick).rootNode.isHidden)
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        XCTAssertTrue(rig.p01AnchoredTransitions)
        rig.viewportSize = CGSize(width: 874, height: 402)
        XCTAssertTrue(ShotPlayCamera.setMode(.perspective3D, on: vm))
        XCTAssertTrue(vm.requestPlayerView(.thirdPerson, animated: false, resetThirdPerson: true))
        rig.handleHorizontalSwipe(delta: 85)
        return (vm, rig)
    }

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

    private var screenshotRack: BoardSnapshot {
        // Centres read from the reported landscape screenshot. Normalize by table length.
        let pixels: [String: CGPoint] = [
            PositionPlayBall.cueKey: .init(x: 770.5, y: 465),
            "_1": .init(x: 718.3, y: 245.3), "_2": .init(x: 1338.9, y: 679),
            "_4": .init(x: 734.6, y: 559.1), "_5": .init(x: 846.6, y: 585.3),
            "_6": .init(x: 607.8, y: 477.5), "_7": .init(x: 1353, y: 712),
            "_8": .init(x: 879.8, y: 352), "_9": .init(x: 497, y: 361),
            "_10": .init(x: 428, y: 223), "_11": .init(x: 1423.5, y: 246.2),
            "_12": .init(x: 1192, y: 388), "_13": .init(x: 1025, y: 340),
            "_14": .init(x: 827, y: 378.8), "_15": .init(x: 1224, y: 350.6)
        ]
        return BoardSnapshot(onTable: pixels.mapValues {
            CanvasPoint(x: Double(($0.x - 353) / 1134), y: Double(($0.y - 175) / 1178))
        })
    }

    func testComposerRanksScreenshotRackAfterBreakHandoff() throws {
        let board = screenshotRack
        let composer = PositionPlayComposerView()
        XCTAssertTrue(composer.usesAttackRecommendations)

        let vm = PositionPlayViewModel(), rules = FreePlayRulesSession()
        let daily = DailyClearanceController(), notices = BTRuleNoticeCenter()
        defer { vm.cancelDailyAttempt() }
        func deliverRack(useAttackRecommendations: Bool) throws {
            FreePlayRulesSession.connect(vm: vm, rules: rules, daily: daily, notices: notices,
                mode: .standard, isEditor: true, isTryout: false,
                usesEditorAttackRecommendations: useAttackRecommendations)
            vm.startBreakFlow(game: .chineseEightBall, manualDeliver: false, seed: 1)
            try XCTUnwrap(vm.breakRunner).applySettledBoardForTesting(board, pocketedKeys: ["_3"])
            XCTAssertNil(vm.breakRunner)
            XCTAssertEqual(Set(vm.onTableKeys), Set(board.onTable.keys))
        }
        vm.setupScene(loadsDefaultLayout: false)
        try deliverRack(useAttackRecommendations: false)
        print("SCREENSHOT_RACK legacy=\(vm.selectedTargetKey ?? "none")/\(vm.selectedPocketIndex)")
        XCTAssertEqual(vm.selectedTargetKey, "_4")
        XCTAssertEqual(vm.selectedPocketIndex, 5)

        try deliverRack(useAttackRecommendations: composer.usesAttackRecommendations)
        let positions = vm.scene.visibleBalls().mapValues(\.position)
        let cue = try XCTUnwrap(positions[PositionPlayBall.cueKey])
        let targets = positions.filter { $0.key != PositionPlayBall.cueKey }
        var assessment = DefenseAttackAssessment()
        assessment.usePrecomputedWindows = true
        let routes = try targets.keys.sorted().flatMap { key in
            try DailyShotRecommendation.attackCandidates(cue: cue, target: XCTUnwrap(targets[key]),
                targetKey: key, obstacles: targets.filter { $0.key != key }.map(\.value),
                surfaceY: vm.scene.surfaceY, assessment: &assessment)
        }
        let best = try XCTUnwrap(DailyShotRecommendation.best(routes))
        let five = try XCTUnwrap(DailyShotRecommendation.best(routes.filter { $0.targetKey == "_5" && $0.pocketIndex == 5 }))
        for route in routes.sorted(by: { ($0.attackScore ?? 0) > ($1.attackScore ?? 0) }) {
            print("SCREENSHOT_RACK \(route.targetKey)/\(route.pocketIndex) cut=\(route.cutDegrees)"
                  + " window=\(route.targetToleranceDegrees ?? 0) comfort=\(route.comfortScore ?? 0)"
                  + " attack=\(route.attackScore ?? 0)")
        }
        XCTAssertNotEqual(best.targetKey, "_4")
        XCTAssertLessThan(five.cutDegrees, 20)
        XCTAssertEqual(vm.selectedTargetKey, best.targetKey)
        XCTAssertEqual(vm.selectedPocketIndex, best.pocketIndex)
    }

    func testPhotoImportRanksTheImportedBoardWithoutReplacingIt() throws {
        let board = screenshotRack
        let composer = PositionPlayComposerView(initialBoard: board)
        let vm = PositionPlayViewModel(), rules = FreePlayRulesSession()
        let daily = DailyClearanceController(), notices = BTRuleNoticeCenter()
        defer { vm.cancelDailyAttempt() }
        FreePlayRulesSession.connect(vm: vm, rules: rules, daily: daily, notices: notices,
            mode: .standard, isEditor: true, isTryout: false,
            usesEditorAttackRecommendations: composer.usesAttackRecommendations)
        vm.setupScene(loadsDefaultLayout: false)
        vm.loadBoard(board)
        XCTAssertEqual(vm.selectedTargetKey, "_13")
        XCTAssertEqual(vm.selectedPocketIndex, 1)
        let imported = vm.currentSnapshot().onTable
        XCTAssertEqual(Set(imported.keys), Set(board.onTable.keys))
        for (key, point) in board.onTable {
            let actual = try XCTUnwrap(imported[key])
            XCTAssertEqual(actual.x, point.x, accuracy: 1e-6)
            XCTAssertEqual(actual.y, point.y, accuracy: 1e-6)
        }
    }

    func testDailyV9RanksOpeningThenRespectsGroupAndManualPlanning() throws {
        let suite = "DailyV9-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = DailyClearanceStore(defaults: defaults)
        let vm = PositionPlayViewModel(), rules = FreePlayRulesSession()
        let daily = DailyClearanceController(store: store, seedGenerator: { 1 })
        let notices = BTRuleNoticeCenter()
        defer { vm.cancelDailyAttempt() }
        connect(vm, mode: .dailyClearance, rules: rules, daily: daily, notices: notices)
        daily.start(host: vm, defaultGame: .chineseEightBall)
        try XCTUnwrap(vm.breakRunner).applySettledBoardForTesting(screenshotRack, pocketedKeys: ["_3"])
        XCTAssertEqual(daily.phase, .playing)
        XCTAssertEqual(vm.selectedTargetKey, "_13")
        XCTAssertEqual(vm.selectedPocketIndex, 1)

        var draft = try XCTUnwrap(store.loadTodayDraft())
        draft.ruleState.assignedGroup = .solid
        store.saveDraft(draft)
        let resumed = DailyClearanceController(store: store)
        FreePlayRulesSession.connect(vm: vm, rules: rules, daily: resumed, notices: notices,
            mode: .dailyClearance, isEditor: false, isTryout: false)
        resumed.start(host: vm, defaultGame: .chineseEightBall)
        XCTAssertEqual(vm.selectedTargetKey, "_5")
        XCTAssertEqual(vm.selectedPocketIndex, 5)
        XCTAssertFalse(vm.selectTarget(key: "_13"))
        XCTAssertTrue(vm.selectTarget(key: "_4"))
        vm.selectPocket(at: 5)
        vm.refreshLegalAimSelection()
        XCTAssertEqual(vm.selectedTargetKey, "_4")
        XCTAssertEqual(vm.selectedPocketIndex, 5)

        resumed.toggleScoring()
        XCTAssertTrue(vm.practiceRequiresExplicitAim)
        XCTAssertTrue(resumed.editPlan { $0.choose(ball: "_4", in: $1) })
        XCTAssertTrue(resumed.editPlan { $0.choose(pocket: 2, in: $1) })
        vm.refreshLegalAimSelection()
        XCTAssertEqual(vm.selectedTargetKey, "_4")
        XCTAssertEqual(vm.selectedPocketIndex, 2)
        XCTAssertEqual(resumed.shotPlan?.firstPocket, 2)
        resumed.toggleScoring()
        XCTAssertFalse(vm.practiceRequiresExplicitAim)
        XCTAssertEqual(vm.selectedTargetKey, "_5")
        XCTAssertEqual(vm.selectedPocketIndex, 5)
    }

    func testShotSimulationReranksRailAndPocketBallAfterBoardEdits() throws {
        let vm = PositionPlayViewModel(), rules = FreePlayRulesSession()
        let daily = DailyClearanceController(), notices = BTRuleNoticeCenter()
        connect(vm, mode: .shotSimulation, rules: rules, daily: daily, notices: notices)
        defer { vm.cancelDailyAttempt() }
        let y = vm.scene.surfaceY + AngleSceneCalculator.ballRadius
        let railZ = -AngleSceneCalculator.innerWidth / 2 + AngleSceneCalculator.ballRadius
        let cue = SCNVector3(-0.65, y, -0.48)
        let rail = SCNVector3(-0.10, y, railZ)
        let nearPocket = SCNVector3(1.06, y, -0.51)
        func canvas(_ point: SCNVector3) -> CanvasPoint {
            let normalized = AngleSceneCalculator.sceneToNormalized(position: point)
            return .init(x: Double(normalized.x), y: Double(normalized.y))
        }
        vm.loadBoard(.init(onTable: [PositionPlayBall.cueKey: canvas(cue), "_1": canvas(rail)]))
        XCTAssertEqual(vm.selectedTargetKey, "_1")
        vm.placeFromPalette("_2", atWorld: nearPocket)
        let layout = [(key: "_1", other: "_2"), (key: "_2", other: "_1")]
        let actualCue = try XCTUnwrap(vm.scene.cueBallNode).position
        var assessment = DefenseAttackAssessment()
        assessment.usePrecomputedWindows = true
        var old = [DailyShotRecommendation.Candidate](), new = old
        for (key, other) in layout {
            let target = try XCTUnwrap(vm.scene.allBallNodes[key]).position
            let obstacle = try XCTUnwrap(vm.scene.allBallNodes[other]).position
            let legacy = (0..<6).compactMap { index in
                DailyShotRecommendation.candidate(cue: actualCue, target: target, targetKey: key,
                    pocketIndex: index, obstacles: [obstacle], surfaceY: vm.scene.surfaceY)
            }
            let attack = try DailyShotRecommendation.attackCandidates(cue: actualCue, target: target,
                targetKey: key, obstacles: [obstacle], surfaceY: vm.scene.surfaceY, assessment: &assessment)
            old.append(contentsOf: legacy)
            new.append(contentsOf: attack)
            for (name, candidates) in [("old", legacy), ("v9", attack)] {
                if let best = DailyShotRecommendation.best(candidates) {
                    print("RAIL_POCKET \(name) \(key) pocket=\(best.pocketIndex) comfort=\(best.comfortScore ?? -1)"
                          + " tolerance=\(best.targetToleranceDegrees ?? -1) cut=\(best.cutDegrees)"
                          + " attack=\(best.attackScore ?? -1)")
                }
            }
        }
        let oldBest = try XCTUnwrap(DailyShotRecommendation.best(old))
        let newBest = try XCTUnwrap(DailyShotRecommendation.best(new))
        XCTAssertEqual(oldBest.targetKey, "_1")
        XCTAssertEqual(newBest.targetKey, "_2")
        XCTAssertEqual(vm.selectedTargetKey, newBest.targetKey)
        XCTAssertEqual(vm.selectedPocketIndex, newBest.pocketIndex)
        vm.removeFromTable("_2")
        XCTAssertEqual(vm.selectedTargetKey, "_1")
        vm.placeFromPalette("_2", atWorld: SCNVector3(-1.06, y, -0.51))
        XCTAssertEqual(vm.selectedTargetKey, "_2")
        XCTAssertEqual(vm.selectedPocketIndex, 0)
        let pocketBall = try XCTUnwrap(vm.scene.allBallNodes["_2"])
        vm.dragBegan(node: pocketBall)
        vm.dragMoved(node: pocketBall, worldPosition: nearPocket)
        XCTAssertEqual(vm.selectedPocketIndex, 0)
        vm.dragEnded(node: pocketBall)
        XCTAssertEqual(vm.selectedTargetKey, newBest.targetKey)
        XCTAssertEqual(vm.selectedPocketIndex, newBest.pocketIndex)
        XCTAssertTrue(vm.selectTarget(key: "_1"))
        let manualPocket = vm.selectedPocketIndex
        XCTAssertGreaterThanOrEqual(manualPocket, 0)
        vm.selectPocket(at: manualPocket)
        let cueNode = try XCTUnwrap(vm.scene.cueBallNode)
        vm.dragBegan(node: cueNode)
        vm.dragMoved(node: cueNode, worldPosition: SCNVector3(cue.x, cue.y, cue.z + 0.02))
        vm.dragEnded(node: cueNode)
        vm.removeFromTable("_2")
        vm.placeFromPalette("_2", atWorld: nearPocket)
        XCTAssertEqual(vm.selectedTargetKey, "_1")
        XCTAssertEqual(vm.selectedPocketIndex, manualPocket)
        vm.removeFromTable("_1")
        XCTAssertEqual(vm.selectedTargetKey, "_2")
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
            var config = MultiBallConfiguration(); config.game = game; config.positionMode = .independent
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


@MainActor
final class BoardMemoryTests: XCTestCase {
    private struct Value: Codable, Equatable { let number: Int }
    private final class Model: ObservableObject { @Published var number = 1 }

    func testLatestWriterOwnerIsolationAndImportPriority() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = Model()
        let first = BoardMemory(page: "composer", root: root)
        first.begin(owner: "a", changes: model.objectWillChange,
                    capture: { Value(number: model.number) }, restore: { model.number = $0.number })
        model.number = 17; first.save()
        let secondModel = Model()
        let second = BoardMemory(page: "composer", root: root)
        second.begin(owner: "a", changes: secondModel.objectWillChange,
                     capture: { Value(number: secondModel.number) }, restore: { secondModel.number = $0.number })
        XCTAssertEqual(secondModel.number, 17)
        model.number = 99; first.end()
        secondModel.number = 23; second.save(); second.end()
        let imported = BoardMemory(page: "composer", root: root)
        imported.begin(owner: "a", changes: model.objectWillChange, imported: true,
                       capture: { Value(number: 31) }, restore: { _ in XCTFail("Import must win") })
        imported.end()
        let other = BoardMemory(page: "composer", root: root)
        other.begin(owner: "b", changes: model.objectWillChange,
                    capture: { Value(number: 44) }, restore: { _ in XCTFail("Owner leaked") })
        other.end()
        let restored = BoardMemory(page: "composer", root: root)
        restored.begin(owner: "a", changes: model.objectWillChange,
                       capture: { Value(number: model.number) }, restore: { model.number = $0.number })
        XCTAssertEqual(model.number, 31)
        restored.end()
    }

    func testUnreadableRecordRemainsUntilExplicitReset() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = Model(), memory = BoardMemory(page: "test", root: root)
        memory.begin(owner: "a", changes: model.objectWillChange,
                     capture: { Value(number: model.number) }, restore: { model.number = $0.number })
        memory.end()
        let owner = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).first)
        let file = owner.appendingPathComponent("test.json")
        let corrupt = Data("broken".utf8)
        try corrupt.write(to: file)
        memory.begin(owner: "a", changes: model.objectWillChange,
                     capture: { Value(number: model.number) }, restore: { model.number = $0.number })
        XCTAssertNotNil(memory.message)
        model.number = 55; memory.save()
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
        memory.reset { model.number = 1 }
        XCTAssertNil(memory.message)
        XCTAssertNotEqual(try Data(contentsOf: file), corrupt)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: owner.path).count, 2)
        memory.end()
    }

    func testComposerSavedBoardRestoresSelectionAndEmptyTable() throws {
        let vm = PositionPlayViewModel()
        vm.usesAttackRecommendations = true
        vm.usesShotComfortRanking = true
        vm.setupScene(loadsDefaultLayout: false)
        vm.loadBoard(PositionPlayComposerView.defaultBoard)
        XCTAssertTrue(vm.selectTarget(key: "_8"))
        vm.selectPocket(at: 3)
        let saved = try XCTUnwrap(vm.savedBoard)
        XCTAssertTrue(saved.manual)
        vm.clearTable()
        try vm.restoreSavedBoard(saved)
        XCTAssertEqual(vm.selectedTargetKey, "_8")
        XCTAssertEqual(vm.selectedPocketIndex, 3)
        XCTAssertEqual(Set(vm.currentSnapshot().onTable.keys), Set(saved.board.onTable.keys))
        vm.clearTable()
        let empty = try XCTUnwrap(vm.savedBoard)
        vm.loadBoard(PositionPlayComposerView.defaultBoard)
        try vm.restoreSavedBoard(empty)
        XCTAssertTrue(vm.currentSnapshot().onTable.isEmpty)
        vm.cancelDailyAttempt()
    }
}

extension BoardMemoryTests {
    func testPageIsolationVersionRejectionAndWriteFailureRecovery() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = Model()
        let a = BoardMemory(page: "one", root: root)
        a.begin(owner: "a", changes: model.objectWillChange, capture: { Value(number: model.number) }, restore: { model.number = $0.number })
        a.end()
        let b = BoardMemory(page: "two", root: root)
        b.begin(owner: "a", changes: model.objectWillChange, capture: { Value(number: 42) }, restore: { _ in XCTFail("Page leaked") })
        b.end()
        let owner = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).first)
        let file = owner.appendingPathComponent("one.json")
        var record = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        record["version"] = 999
        let incompatible = try JSONSerialization.data(withJSONObject: record)
        try incompatible.write(to: file)
        a.begin(owner: "a", changes: model.objectWillChange, capture: { Value(number: 7) }, restore: { _ in XCTFail("Incompatible version restored") })
        a.save(); XCTAssertEqual(try Data(contentsOf: file), incompatible); XCTAssertNotNil(a.message)
        a.reset { }; a.end()
        // A parent which is a file forces create/write failure without permission assumptions.
        let blocked = root.appendingPathComponent("blocked")
        try Data("block".utf8).write(to: blocked)
        let failed = BoardMemory(page: "one", root: blocked)
        failed.begin(owner: "a", changes: model.objectWillChange, capture: { Value(number: 23) }, restore: { _ in })
        XCTAssertNotNil(failed.message)
        try FileManager.default.removeItem(at: blocked)
        failed.save(); XCTAssertNil(failed.message); failed.end()
    }

    func testComposerAutomaticSelectionAndPreparedBreakRoundTrip() throws {
        let vm = PositionPlayViewModel()
        vm.usesAttackRecommendations = true; vm.usesShotComfortRanking = true
        vm.setupScene(loadsDefaultLayout: false)
        defer { vm.cancelBreakFlow(); vm.cancelDailyAttempt() }
        vm.loadBoard(PositionPlayComposerView.defaultBoard)
        vm.refreshLegalAimSelection()
        let automatic = try XCTUnwrap(vm.savedBoard)
        XCTAssertFalse(automatic.manual)
        try vm.restoreSavedBoard(automatic)
        XCTAssertFalse(try XCTUnwrap(vm.savedBoard).manual)
        vm.startBreakFlow(game: .nineBall, manualDeliver: false, seed: 123)
        let runner = try XCTUnwrap(vm.breakRunner)
        runner.velocity = 7; runner.spinX = 0.1; runner.spinY = 0.2
        runner.nudgeAim(byDegrees: 3)
        let saved = try XCTUnwrap(vm.savedBoard)
        XCTAssertEqual(saved.preparedBreak?.count, 9)
        let expectedDirection = saved.preparedBreak?.direction
        vm.cancelBreakFlow()
        try vm.restoreSavedBoard(saved)
        XCTAssertEqual(vm.breakRunner?.velocity, 7)
        XCTAssertEqual(vm.breakRunner?.savedInput?.direction, expectedDirection)
        vm.breakRunner?.breakNow()
        XCTAssertNil(vm.savedBoard)
        vm.breakRunner?.suspendActivity()
        XCTAssertEqual(vm.savedBoard?.preparedBreak?.count, 9)
    }
}

extension BoardMemoryTests {
    func testComposerStableShotAndReplayMemory() async throws {
        let vm = PositionPlayViewModel()
        vm.setupScene(loadsDefaultLayout: false)
        vm.loadBoard(.init(onTable: [PositionPlayBall.cueKey: .init(x: 0.5, y: 0.36), "_1": .init(x: 0.5, y: 0.16)]))
        _ = vm.selectTarget(key: "_1"); vm.selectPocket(at: 4); vm.velocity = 1.4
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 874, height: 402))
        view.scene = vm.scene; view.pointOfView = vm.scene.cameraNode; view.isPlaying = true
        let window = UIWindow(windowScene: try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene))
        let controller = UIViewController(); controller.view = view; window.rootViewController = controller; window.makeKeyAndVisible()
        defer { vm.cancelDailyAttempt(); window.isHidden = true; view.isPlaying = false }
        func wait(_ predicate: () -> Bool) async throws {
            let deadline = Date().addingTimeInterval(30)
            while !predicate(), Date() < deadline {
                vm.scene.cameraRig?.update(deltaTime: 0.02)
                try await Task.sleep(for: .milliseconds(20))
            }
            XCTAssertTrue(predicate())
        }
        try await wait { !vm.isComputing && !vm.cameraTransitionBusy && vm.solvedShot != nil }
        let before = try XCTUnwrap(vm.savedBoard)
        vm.play(); XCTAssertTrue(vm.isPlaying); XCTAssertNil(vm.savedBoard)
        vm.suspendAuthoringActivity()
        XCTAssertEqual(vm.currentSnapshot().onTable.mapValues { [$0.x, $0.y] }, before.board.onTable.mapValues { [$0.x, $0.y] })
        vm.resumeAuthoringActivity()
        try await wait { !vm.isComputing && !vm.cameraTransitionBusy }
        vm.play(); XCTAssertTrue(vm.isPlaying)
        try await wait { !vm.isPlaying && !vm.isComputing }
        let after = try XCTUnwrap(vm.savedBoard)
        vm.replayLastShot(); XCTAssertTrue(vm.isPlaying); XCTAssertNil(vm.savedBoard)
        vm.suspendAuthoringActivity()
        XCTAssertEqual(vm.currentSnapshot().onTable.mapValues { [$0.x, $0.y] }, after.board.onTable.mapValues { [$0.x, $0.y] })
        try vm.restoreSavedBoard(after)
        XCTAssertEqual(vm.currentSnapshot().onTable.mapValues { [$0.x, $0.y] }, after.board.onTable.mapValues { [$0.x, $0.y] })
    }
}

@MainActor
final class PlanningBoardMemoryTests: XCTestCase {
    private func roundTrip<T: Codable>(_ value: T) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
    }
    private func bytes<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        return try encoder.encode(value)
    }
    func testSiluAllConstraintKindsAndImportAndEmptyBoard() throws {
        for tool in [SiluTrainerViewModel.Tool.region, .restPoint, .passPoint] {
            for shape in [SiluTrainerViewModel.RegionShape.rect, .circle] {
                let vm = SiluTrainerViewModel(); vm.setupScene()
                vm.placeFromPalette("_5")
                vm.activeTool = tool; vm.regionShape = shape
                vm.toolDrag(startNormalized: .init(x: 0.34, y: 0.24), currentNormalized: .init(x: 0.56, y: 0.40), ended: true)
                let saved = try roundTrip(XCTUnwrap(vm.savedBoard))
                vm.stopForDismissal()
                let restored = SiluTrainerViewModel(); restored.setupScene()
                try restored.restoreSavedBoard(saved)
                let result = try XCTUnwrap(restored.savedBoard)
                XCTAssertEqual(try bytes(result.draft), try bytes(saved.draft))
                XCTAssertEqual(result.tool, tool); XCTAssertEqual(result.shape, shape)
                XCTAssertEqual(result.target, saved.target); XCTAssertEqual(result.pocket, saved.pocket)
                XCTAssertEqual(Set(result.board.onTable.keys), Set(saved.board.onTable.keys))
                restored.stopForDismissal()
            }
        }
        let vm = SiluTrainerViewModel(); vm.setupScene(); vm.clearTable()
        let empty = try roundTrip(XCTUnwrap(vm.savedBoard))
        vm.resetRememberedBoard(); try vm.restoreSavedBoard(empty)
        XCTAssertEqual(vm.onTableKeys, [PositionPlayBall.cueKey])
        vm.stopForDismissal()
    }
    func testPlanThreeIncompleteFullAndClearedRolesRoundTrip() throws {
        for stage in 0...3 {
            let vm = PlanThreeViewModel(); vm.setupScene()
            if stage > 0 { vm.selectPaletteBall("_1"); vm.selectPocket(at: 4) }
            if stage > 1 { vm.selectPaletteBall("_2"); vm.selectPocket(at: 5) }
            if stage > 2 { vm.selectPaletteBall("_3") }
            vm.stopForDismissal()
            let saved = try roundTrip(XCTUnwrap(vm.savedBoard))
            let restored = PlanThreeViewModel(); restored.setupScene()
            try restored.restoreSavedBoard(saved)
            XCTAssertEqual(restored.ball1Key, saved.ball1); XCTAssertEqual(restored.ball2Key, saved.ball2)
            XCTAssertEqual(restored.ball3Key, saved.ball3); XCTAssertEqual(restored.pocket1Index, saved.pocket1)
            XCTAssertEqual(restored.pocket2Index, saved.pocket2); XCTAssertEqual(restored.armedRole, saved.armed)
            restored.stopForDismissal()
            restored.resumeTeachingActivity()
            restored.clearPaletteRole("_2")
            restored.stopForDismissal()
            let cleared = try roundTrip(XCTUnwrap(restored.savedBoard))
            try vm.restoreSavedBoard(cleared)
            XCTAssertEqual(vm.ball2Key, cleared.ball2)
            vm.stopForDismissal()
        }
    }
    func testRestoredPlanningInputsSolveAndStrike() async throws {
        let silu = SiluTrainerViewModel(); silu.setupScene()
        silu.toolDrag(startNormalized: .init(x: 0.34, y: 0.24), currentNormalized: .init(x: 0.56, y: 0.40), ended: true)
        let saved = try roundTrip(XCTUnwrap(silu.savedBoard)); silu.stopForDismissal()
        try silu.restoreSavedBoard(saved)
        try await exercise(silu, computing: { silu.isComputing }, ready: { silu.canStrike }, play: silu.play, playing: { silu.isPlaying }, stop: silu.stopForDismissal)
        let planner = PlanThreeViewModel(); planner.setupScene()
        planner.loadBoard(.init(onTable: [PositionPlayBall.cueKey: .init(x: 0.5, y: 0.36), "_1": .init(x: 0.5, y: 0.16)]))
        planner.selectPaletteBall("_1"); planner.selectPocket(at: 4)
        let plan = try roundTrip(XCTUnwrap(planner.savedBoard)); planner.stopForDismissal()
        try planner.restoreSavedBoard(plan)
        try await exercise(planner, computing: { planner.isComputing }, ready: { planner.canStrike }, play: planner.play, playing: { planner.isPlaying }, stop: planner.stopForDismissal)
    }
    private func exercise<VM: TeachingTableHost>(_ vm: VM, computing: () -> Bool, ready: () -> Bool,
        play: () -> Void, playing: () -> Bool, stop: () -> Void) async throws {
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 874, height: 402))
        view.scene = vm.scene; view.pointOfView = vm.scene.cameraNode; view.isPlaying = true
        let window = UIWindow(windowScene: try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene))
        let controller = UIViewController(); controller.view = view; window.rootViewController = controller; window.makeKeyAndVisible()
        defer { stop(); view.isPlaying = false; window.isHidden = true }
        let deadline = Date().addingTimeInterval(90)
        while computing() || !ready(), Date() < deadline {
            vm.scene.cameraRig?.update(deltaTime: 0.02); try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(ready()); play(); XCTAssertTrue(playing())
        let end = Date().addingTimeInterval(30)
        while playing(), Date() < end { vm.scene.cameraRig?.update(deltaTime: 0.02); try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertFalse(playing())
    }
}

@MainActor
final class ObservationBoardMemoryTests: XCTestCase {
    func testToleranceRemembersEachPocketUnselectedAndRemovedBall() throws {
        let vm = PocketToleranceViewModel(); vm.setupScene()
        vm.selectPocket(at: 0)
        vm.placeFromPalette("_5"); vm.selectPocket(at: 2)
        vm.placeFromPalette("_7"); vm.selectPocket(at: 4)
        vm.placeFromPalette("_9")
        let saved = try XCTUnwrap(vm.savedBoard)
        let decoded = try JSONDecoder().decode(SavedObservationBoard.self, from: JSONEncoder().encode(saved))
        let restored = PocketToleranceViewModel(); restored.setupScene(); try restored.restoreSavedBoard(decoded)
        for (key, pocket) in [("_3", 0), ("_5", 2), ("_7", 4), ("_9", -1)] {
            restored.selectTarget(key: key); XCTAssertEqual(restored.selectedPocketIndex, pocket)
        }
        restored.removeFromTable("_5"); restored.placeFromPalette("_5")
        XCTAssertEqual(restored.selectedPocketIndex, -1)
        restored.resetRememberedBoard()
        XCTAssertEqual(restored.onTableKeys, ["_3"]); XCTAssertEqual(restored.selectedPocketIndex, -1)
        vm.suspendTeachingActivity(); restored.suspendTeachingActivity()
    }
    func testAngleRestoresMultipleBallsAndManualPocketAndEmptyTable() throws {
        let vm = AngleDynamicViewModel(); vm.setupScene(); vm.placeFromPalette("_5")
        vm.selectTarget(key: "_5"); vm.selectPocket(at: 2)
        let saved = try XCTUnwrap(vm.savedBoard)
        let restored = AngleDynamicViewModel(); restored.setupScene(); try restored.restoreSavedBoard(saved)
        XCTAssertEqual(restored.selectedTargetKey, "_5"); XCTAssertEqual(restored.selectedPocketIndex, 2)
        XCTAssertEqual(restored.cutAngleDegrees, vm.cutAngleDegrees, accuracy: 0.001)
        try restored.restoreSavedBoard(.init(board: .init(onTable: [:]), target: nil, pockets: [:]))
        XCTAssertTrue(restored.onTableKeys.isEmpty)
        restored.resetRememberedBoard(); XCTAssertEqual(restored.selectedTargetKey, "_8")
        vm.suspendTeachingActivity(); restored.suspendTeachingActivity()
    }
}

@MainActor
final class CushionBoardMemoryTests: XCTestCase {
    private func roundTrip(_ value: SavedCushionBoard) throws -> SavedCushionBoard {
        try JSONDecoder().decode(SavedCushionBoard.self, from: JSONEncoder().encode(value))
    }
    private func compare(_ expected: SavedCushionBoard, _ actual: SavedCushionBoard) throws {
        XCTAssertEqual(actual.target, expected.target); XCTAssertEqual(actual.free, expected.free)
        XCTAssertEqual(actual.pocket, expected.pocket); XCTAssertEqual(actual.cushions, expected.cushions)
        XCTAssertEqual(actual.direction, expected.direction); XCTAssertEqual(actual.power, expected.power)
        XCTAssertEqual(actual.spinX, expected.spinX); XCTAssertEqual(actual.spinY, expected.spinY)
        XCTAssertEqual(Set(actual.poses.keys), Set(expected.poses.keys))
        for (key, pose) in expected.poses {
            let other = try XCTUnwrap(actual.poses[key])
            XCTAssertEqual(pose.position, other.position)
            let a = try pose.restored(), b = try other.restored()
            XCTAssertEqual(abs(simd_dot(a.orientation.vector, b.orientation.vector)), 1, accuracy: 0.0001)
        }
    }
    func testBankTargetIdentityObstaclePosesFreeInputsAndReset() throws {
        let vm = BankShotViewModel(); vm.setupScene(); vm.toggleMode()
        vm.placeObstacle("_3", atWorld: nil); vm.placeObstacle("_5", atWorld: nil)
        vm.selectTarget(key: "_3"); vm.selectPocket(2); vm.selectCushions(2)
        vm.nudgeFreeAim(byDegrees: 7); vm.reflectionPower = 1.8; vm.spinX = 0.1; vm.spinY = 0.2
        vm.scene.allBallNodes["_5"]?.simdOrientation = simd_quatf(angle: 0.6, axis: SIMD3<Float>(0, 1, 0))
        let saved = try roundTrip(XCTUnwrap(vm.savedBoard)); vm.stopForDismissal()
        let restored = BankShotViewModel(); restored.setupScene(); try restored.restoreSavedBoard(saved)
        try compare(saved, XCTUnwrap(restored.savedBoard))
        XCTAssertEqual(restored.scene.ballKey(for: try XCTUnwrap(restored.scene.targetBallNodes.first)), "_3")
        restored.resetRememberedBoard(); XCTAssertEqual(restored.reflectionPower, Double(CushionReflectionSettings.defaultPower)); XCTAssertEqual(restored.selectedTargetKey, "_8")
        XCTAssertEqual(restored.mode, .solve); XCTAssertNil(restored.selectedCushions)
        restored.stopForDismissal()
    }
    func testDiamondObstaclePosesFreeInputsAndReset() throws {
        let vm = DiamondSystemViewModel(); vm.setupScene(); vm.toggleMode()
        vm.placeObstacle("_3", atWorld: nil); vm.selectCushions(3)
        vm.nudgeFreeAim(byDegrees: -5); vm.reflectionPower = 2.3; vm.spinX = -0.1; vm.spinY = 0.2
        let saved = try roundTrip(XCTUnwrap(vm.savedBoard)); vm.stopForDismissal()
        let restored = DiamondSystemViewModel(); restored.setupScene(); try restored.restoreSavedBoard(saved)
        try compare(saved, XCTUnwrap(restored.savedBoard))
        restored.resetRememberedBoard(); XCTAssertEqual(restored.reflectionPower, Double(CushionReflectionSettings.defaultPower)); XCTAssertEqual(restored.mode, .solve); XCTAssertNil(restored.selectedCushions)
        restored.stopForDismissal()
    }
    func testRestoredCushionFreeShotsAndCurrentSolve() async throws {
        let bank = BankShotViewModel(); bank.setupScene(); bank.toggleMode()
        let bankSaved = try roundTrip(XCTUnwrap(bank.savedBoard)); bank.stopForDismissal()
        try bank.restoreSavedBoard(bankSaved)
        try await shoot(bank)
        let kick = DiamondSystemViewModel(); kick.setupScene(); kick.toggleMode()
        let kickSaved = try roundTrip(XCTUnwrap(kick.savedBoard)); kick.stopForDismissal()
        try kick.restoreSavedBoard(kickSaved)
        try await shoot(kick)
    }
    private func shoot<VM: SolverStageHosting>(_ vm: VM) async throws {
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 874, height: 402))
        view.scene = vm.scene; view.pointOfView = vm.scene.cameraNode; view.isPlaying = true
        let window = UIWindow(windowScene: try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene))
        let controller = UIViewController(); controller.view = view; window.rootViewController = controller; window.makeKeyAndVisible()
        defer { vm.stopForDismissal(); view.isPlaying = false; window.isHidden = true }
        let deadline = Date().addingTimeInterval(60)
        while !vm.canFreeStrike, Date() < deadline { vm.scene.cameraRig?.update(deltaTime: 0.02); try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertTrue(vm.canFreeStrike); vm.freeStrike(); XCTAssertTrue(vm.isPlaying)
        let end = Date().addingTimeInterval(30)
        while vm.isPlaying, Date() < end { vm.scene.cameraRig?.update(deltaTime: 0.02); try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertFalse(vm.isPlaying)
        vm.toggleMode()
        let solveEnd = Date().addingTimeInterval(90)
        while vm.isSolving, Date() < solveEnd { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertFalse(vm.isSolving)
    }
}

extension PlanningBoardMemoryTests {
    func testSavedSiluFineTuningReturnsOnlyAfterFreshSolve() async throws {
        let vm = SiluTrainerViewModel(); vm.setupScene()
        defer { vm.stopForDismissal() }
        vm.toolDrag(startNormalized: .init(x: 0.34, y: 0.24), currentNormalized: .init(x: 0.56, y: 0.40), ended: true)
        func wait() async throws {
            let end = Date().addingTimeInterval(60)
            while vm.isComputing, Date() < end { try await Task.sleep(for: .milliseconds(20)) }
            XCTAssertFalse(vm.isComputing)
        }
        try await wait(); XCTAssertTrue(vm.hasSolutions)
        vm.selectSolution(at: min(1, vm.solutions.count - 1))
        vm.adjustCurrentSolution(velocity: vm.velocity + 0.03)
        try await wait()
        let saved = try roundTrip(XCTUnwrap(vm.savedBoard))
        let expected = try XCTUnwrap(saved.input)
        vm.stopForDismissal(); try vm.restoreSavedBoard(saved)
        XCTAssertTrue(vm.isComputing)
        try await wait()
        XCTAssertEqual(vm.velocity, expected.adjusted.velocity, accuracy: 0.0001)
        XCTAssertEqual(vm.spinX, expected.adjusted.spinX, accuracy: 0.0001)
        XCTAssertEqual(vm.spinY, expected.adjusted.spinY, accuracy: 0.0001)
        XCTAssertEqual(vm.selectedTargetKey, saved.target)
    }
}

extension CushionBoardMemoryTests {
    func testRestoredBankSolveRetainsFineTunedInput() async throws {
        let vm = BankShotViewModel(); vm.setupScene()
        defer { vm.stopForDismissal() }
        func wait() async throws {
            let end = Date().addingTimeInterval(90)
            while vm.isSolving || vm.isAdjustingSolution, Date() < end { try await Task.sleep(for: .milliseconds(20)) }
            XCTAssertFalse(vm.isSolving || vm.isAdjustingSolution)
        }
        try await wait(); XCTAssertTrue(vm.hasSolution)
        vm.adjustCurrentSolution(velocity: vm.reflectionPower + 0.02, spinX: nil, spinY: nil)
        try await wait()
        let saved = try roundTrip(XCTUnwrap(vm.savedBoard))
        vm.stopForDismissal(); try vm.restoreSavedBoard(saved)
        try await wait()
        XCTAssertTrue(vm.hasSolution)
        XCTAssertEqual(vm.reflectionPower, saved.power, accuracy: 0.0001)
        XCTAssertEqual(vm.spinX, saved.spinX, accuracy: 0.0001)
        XCTAssertEqual(vm.spinY, saved.spinY, accuracy: 0.0001)
    }
    func testRestoredDiamondSolveRetainsFineTunedInput() async throws {
        let vm = DiamondSystemViewModel(); vm.setupScene()
        defer { vm.stopForDismissal() }
        func wait() async throws {
            let end = Date().addingTimeInterval(90)
            while vm.isSolving || vm.isAdjustingSolution, Date() < end { try await Task.sleep(for: .milliseconds(20)) }
            XCTAssertFalse(vm.isSolving || vm.isAdjustingSolution)
        }
        try await wait(); XCTAssertTrue(vm.hasSolution)
        vm.adjustCurrentSolution(velocity: vm.reflectionPower + 0.02, spinX: nil, spinY: nil)
        try await wait()
        let saved = try roundTrip(XCTUnwrap(vm.savedBoard))
        vm.stopForDismissal(); try vm.restoreSavedBoard(saved)
        try await wait()
        XCTAssertTrue(vm.hasSolution)
        XCTAssertEqual(vm.reflectionPower, saved.power, accuracy: 0.0001)
        XCTAssertEqual(vm.spinX, saved.spinX, accuracy: 0.0001)
        XCTAssertEqual(vm.spinY, saved.spinY, accuracy: 0.0001)
    }
}

@MainActor
final class AutomaticRecommendationPreferenceTests: XCTestCase {
    private func assertTargetAddress(_ scene: AngleTrainingScene, key: String,
                                     file: StaticString = #filePath, line: UInt = #line) throws {
        let cue = try XCTUnwrap(scene.cueBallNode, file: file, line: line)
        let target = try XCTUnwrap(scene.allBallNodes[key], file: file, line: line)
        let direction = SCNVector3(target.position.x - cue.position.x, 0, target.position.z - cue.position.z).normalized()
        let preview = try XCTUnwrap(scene.rootNode.childNode(withName: "freeAimPreview", recursively: false),
                                    file: file, line: line)
        let bounds = try XCTUnwrap(preview.geometry, file: file, line: line).boundingBox
        let mid = SCNVector3((bounds.min.x + bounds.max.x) / 2, (bounds.min.y + bounds.max.y) / 2,
                             (bounds.min.z + bounds.max.z) / 2)
        let center = preview.convertPosition(mid, to: scene.rootNode)
        XCTAssertEqual(center.x, (cue.position.x + target.position.x) / 2, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(center.z, (cue.position.z + target.position.z) / 2, accuracy: 0.001, file: file, line: line)
        let shaft = try XCTUnwrap(scene.cueStick, file: file, line: line)
        XCTAssertFalse(shaft.rootNode.isHidden, file: file, line: line)
        let actual = try XCTUnwrap(scene.lastCueAim, file: file, line: line)
        XCTAssertEqual(actual.x, direction.x, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(actual.z, direction.z, accuracy: 0.0001, file: file, line: line)
    }

    func testFiveIndependentPreferencesAndSharedMultiBallCameraModes() throws {
        let suite = "AutoRecommendation-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let pages: [TablePreferencePage] = [.composer, .dailyClearance, .customFormationPractice, .multiBallPractice, .silu]
        for changed in pages {
            let store = TablePreferencesStore(defaults: defaults)
            XCTAssertTrue(pages.allSatisfy { store.automaticRecommendation(for: $0) })
            store.setAutomaticRecommendation(false, for: changed)
            let restored = TablePreferencesStore(defaults: defaults)
            for page in pages { XCTAssertEqual(restored.automaticRecommendation(for: page), page != changed) }
            XCTAssertEqual(restored.automaticRecommendation(for: .multiBallPractice3D), changed != .multiBallPractice)
            restored.setAutomaticRecommendation(true, for: changed == .multiBallPractice ? .multiBallPractice3D : changed)
        }
    }

    func testAutomaticAndHandPickedPartsAcrossEditsAndNextShot() throws {
        let vm = PositionPlayViewModel()
        vm.usesAttackRecommendations = true
        vm.usesShotComfortRanking = true
        vm.usesAutomaticPocketFallback = true
        vm.setupScene(loadsDefaultLayout: false)
        defer { vm.cancelDailyAttempt() }
        vm.loadBoard(PositionPlayComposerView.defaultBoard)
        let target = try XCTUnwrap(vm.selectedTargetKey)
        vm.setAutomaticRecommendation(false)
        XCTAssertNil(vm.selectedTargetKey)
        XCTAssertEqual(vm.selectedPocketIndex, -1)
        XCTAssertNotNil(vm.playerViewDirection)
        vm.placeFromPalette("_3")
        vm.dragEnded(node: try XCTUnwrap(vm.scene.allBallNodes["_3"]))
        XCTAssertNil(vm.selectedTargetKey)
        XCTAssertTrue(vm.selectTarget(key: target))
        XCTAssertEqual(vm.selectedPocketIndex, -1)
        try assertTargetAddress(vm.scene, key: target)
        XCTAssertNil(vm.solvedShot)
        XCTAssertFalse(vm.isFeasible)
        vm.setAutomaticRecommendation(true)
        XCTAssertEqual(vm.selectedTargetKey, target)
        XCTAssertGreaterThanOrEqual(vm.selectedPocketIndex, 0)
        let pocket = vm.selectedPocketIndex
        vm.setAutomaticRecommendation(false)
        XCTAssertEqual(vm.selectedTargetKey, target)
        XCTAssertEqual(vm.selectedPocketIndex, -1)
        vm.selectPocket(at: pocket)
        vm.setAutomaticRecommendation(true)
        vm.setAutomaticRecommendation(false)
        XCTAssertEqual(vm.selectedTargetKey, target)
        XCTAssertEqual(vm.selectedPocketIndex, pocket)
        let manual = vm.trainingInput
        vm.recommendTargetAfterShot()
        XCTAssertNil(vm.selectedTargetKey)
        XCTAssertEqual(vm.selectedPocketIndex, -1)
        vm.restoreTrainingInput(manual)
        XCTAssertEqual(vm.selectedPocketIndex, pocket)
        vm.removeFromTable(target)
        XCTAssertNil(vm.selectedTargetKey)
        XCTAssertEqual(vm.selectedPocketIndex, -1)
    }

    func testRequiredBallKeepsItsRuleAndPlanningKeepsItsPocket() {
        let vm = PositionPlayViewModel()
        vm.hasRuleDefinedTargets = true
        vm.legalAimTargets = { $0.intersection(["_1"]) }
        vm.automaticRecommendationEnabled = false
        vm.setupScene(loadsDefaultLayout: false)
        defer { vm.cancelDailyAttempt() }
        vm.loadBoard(PositionPlayComposerView.defaultBoard)
        XCTAssertEqual(vm.selectedTargetKey, "_1")
        XCTAssertEqual(vm.selectedPocketIndex, -1)
        XCTAssertFalse(vm.selectTarget(key: "_8"))
        vm.practiceRequiresExplicitAim = true
        vm.selectPocket(at: 1)
        vm.refreshLegalAimSelection()
        XCTAssertEqual(vm.selectedPocketIndex, 1)
    }

    func testSolverKeepsHandPickedTargetAcrossRestoreAndAsksForPocket() throws {
        let vm = SiluTrainerViewModel()
        vm.setupScene()
        defer { vm.stopForDismissal() }
        vm.setAutomaticRecommendation(false)
        vm.loadBoard(PositionPlayComposerView.defaultBoard)
        XCTAssertNil(vm.selectedTargetKey)
        vm.selectTarget(node: try XCTUnwrap(vm.scene.allBallNodes["_1"]))
        XCTAssertEqual(vm.selectedPocketIndex, -1)
        try assertTargetAddress(vm.scene, key: "_1")
        vm.selectTarget(key: "_8")
        try assertTargetAddress(vm.scene, key: "_8")
        vm.selectTarget(key: "_1")
        try assertTargetAddress(vm.scene, key: "_1")
        XCTAssertFalse(vm.canStrike)
        vm.setAutomaticRecommendation(true)
        XCTAssertGreaterThanOrEqual(vm.selectedPocketIndex, 0)
        XCTAssertNil(vm.scene.rootNode.childNode(withName: "freeAimPreview", recursively: false))
        let saved = try XCTUnwrap(vm.savedBoard)
        vm.setAutomaticRecommendation(false)
        try vm.restoreSavedBoard(saved)
        XCTAssertEqual(vm.selectedTargetKey, "_1")
        XCTAssertEqual(vm.selectedPocketIndex, -1)
        vm.selectPocket(at: 3)
        vm.setAutomaticRecommendation(true)
        vm.setAutomaticRecommendation(false)
        XCTAssertEqual(vm.selectedPocketIndex, 3)
        vm.removeFromTable("_1")
        XCTAssertNil(vm.selectedTargetKey)
        XCTAssertEqual(vm.selectedPocketIndex, -1)
    }
}
