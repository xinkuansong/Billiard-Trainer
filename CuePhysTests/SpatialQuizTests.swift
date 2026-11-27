import XCTest
import SceneKit
@testable import CuePhys

final class SpatialQuizTests: XCTestCase {
    private typealias Facts = SpatialQuizFacts
    private typealias Judgement = SpatialQuizJudgement
    private func event(_ time: Double, _ kind: Facts.EventKind) -> Facts.Event {
        .init(time: time, kind: kind, source: "test-evidence")
    }
    private var hit: Facts.Event { event(1, .balls(.cue, .target)) }
    private func evaluate(_ events: [Facts.Event], complete: Bool = true, issues: [String] = []) -> Judgement.Outcome {
        Judgement.evaluate(.init(complete: complete, duration: 5, events: events, issues: issues))
    }
    func testAnyPocketAndEitherBallCushionCompleteBothModes() {
        for _ in SpatialQuizMode.allCases {
            for pocket in 0..<6 {
                XCTAssertEqual(evaluate([hit, event(2, .pocket(.target, id: "pocket_\(pocket)"))]), .success([.targetPotted]))
            }
            XCTAssertEqual(evaluate([hit, event(2, .surface(.cue, .cushion, approaching: true))]), .success([.cueCushionAfterContact]))
            XCTAssertEqual(evaluate([hit, event(2, .surface(.target, .cushion, approaching: true))]), .success([.targetCushionAfterContact]))
            XCTAssertEqual(evaluate([hit, event(2, .surface(.cue, .cushion, approaching: true)), event(3, .pocket(.target, id: "pocket_0"))]),
                .success([.targetPotted, .cueCushionAfterContact]))
        }
    }
    func testOnlyPostContactImpactsCountAndPriorRailIsNotAFoul() {
        let before = event(0.5, .surface(.cue, .cushion, approaching: true))
        XCTAssertEqual(evaluate([before, hit]), .failure(.noCompletion))
        XCTAssertTrue(evaluate([before, hit, event(2, .surface(.target, .cushion, approaching: true))]).succeeded)
        XCTAssertEqual(evaluate([hit]), .failure(.noCompletion))
        XCTAssertEqual(evaluate([]), .failure(.noTargetContact))
        XCTAssertEqual(evaluate([event(2, .pocket(.target, id: "pocket_0"))]), .failure(.noTargetContact))
    }
    func testClothLinerWoodAndInitialSupportAreNotCushions() {
        for surface in [Facts.Surface.cloth, .liner, .exterior] {
            XCTAssertEqual(evaluate([hit, event(2, .surface(.target, surface, approaching: true))]), .failure(.noCompletion))
        }
        XCTAssertEqual(evaluate([hit, event(2, .surface(.target, .cushion, approaching: false))]), .failure(.noCompletion))
        XCTAssertEqual(evaluate([event(0, .surface(.target, .cushion, approaching: false)), hit]), .failure(.noCompletion))
    }
    func testObstacleFirstAndSimultaneousContactsFailButLaterContactsAreLegal() {
        let pot = event(3, .pocket(.target, id: "pocket_1"))
        XCTAssertEqual(evaluate([event(0.5, .balls(.cue, .obstacle)), hit, pot]), .failure(.wrongFirstContact))
        for simultaneous in [event(1, .balls(.cue, .obstacle)), event(1, .balls(.target, .obstacle))] {
            let events = [hit, simultaneous, pot]
            XCTAssertEqual(evaluate(events), .failure(.wrongFirstContact))
            XCTAssertEqual(evaluate(events.reversed()), .failure(.wrongFirstContact))
        }
        for role in [Facts.Role.cue, .target] {
            let events=[hit,event(2,.balls(role,.obstacle)),pot]
            XCTAssertEqual(evaluate(events),.success([.targetPotted]))
            XCTAssertEqual(evaluate(events.reversed()),.success([.targetPotted]))
            XCTAssertEqual(evaluate([hit,event(2,.balls(role,.obstacle))]),.failure(.noCompletion))
            XCTAssertEqual(evaluate(events+[event(4,.pocket(.cue,id:"pocket_0"))]),.failure(.cuePotted))
        }
    }
    func testCompactOutcomeCopyKeepsOnlySuccessOrPrimaryReason() {
        XCTAssertEqual(Judgement.Outcome.success(Judgement.Completion.allCases).text,"成功")
        XCTAssertEqual(Judgement.Outcome.failure(.cuePotted).text,"母球落袋")
        XCTAssertEqual(Judgement.Outcome.failure(.noTargetContact).text,"未碰到目标球")
        XCTAssertEqual(Judgement.Outcome.failure(.noCompletion).text,"碰球后未进袋或吃库")
    }
    func testWholeStrokeFoulsOverrideEarlierCompletion() {
        let success = [hit, event(2, .pocket(.target, id: "pocket_0"))]
        let failures: [(Facts.EventKind, Judgement.Failure)] = [
            (.pocket(.cue, id: "pocket_2"), .cuePotted), (.outside(.cue), .cueOutside),
            (.outside(.target), .targetOutside), (.pocket(.obstacle, id: "pocket_0"), .obstaclePotted),
            (.outside(.obstacle), .obstacleOutside)]
        for (kind, expected) in failures { XCTAssertEqual(evaluate(success + [event(4, kind)]), .failure(expected)) }
    }
    func testSameTimeCushionRequiresCausalEvidenceNotEventOrder() {
        let events = [hit, event(1, .surface(.target, .cushion, approaching: true))]
        XCTAssertEqual(evaluate(events), .unconfirmed(["simultaneousCompletionNeedsCausalEvidence"]))
        XCTAssertEqual(evaluate(events.reversed()), evaluate(events))
    }
    func testIncompleteCorruptAndUnknownEvidenceNeverScores() {
        let valid = [hit, event(2, .pocket(.target, id: "pocket_0"))]
        XCTAssertFalse(evaluate(valid, complete: false).confirmed)
        XCTAssertFalse(evaluate(valid, issues: ["unknownSurface"]).confirmed)
        for time in [Double.nan, .infinity, -1, 6] {
            XCTAssertFalse(evaluate([hit, event(time, .pocket(.target, id: "pocket_0"))]).confirmed)
        }
        XCTAssertFalse(evaluate([hit, event(2, .pocket(.target, id: ""))]).confirmed)
        XCTAssertFalse(evaluate([event(1, .balls(.cue, .cue))]).confirmed)
    }
    func testFactsAndResultRoundTripRetainFullJudgement() throws {
        let facts = Facts(complete: true, duration: 4, events: [hit, event(2, .surface(.target, .cushion, approaching: true))], issues: [])
        let restored = try JSONDecoder().decode(Facts.self, from: JSONEncoder().encode(facts))
        XCTAssertEqual(restored, facts)
        let outcome = Judgement.evaluate(restored)
        XCTAssertEqual(try JSONDecoder().decode(Judgement.Outcome.self, from: JSONEncoder().encode(outcome)), outcome)
    }

    // Frozen independent research witnesses, sourceLayoutID target-59-m054-d6.
    // Masse: b9eb3986 / research-masse-00001; Jump: 331c6e24 / one-00001-jump-c01.
    private func fixture(_ mode: SpatialQuizMode, number: Int = 1) -> (SpatialQuizPhysics.Board, SpatialQuizPhysics.Input) {
        let y = BTTablePhysics.surfaceY + BallPhysics.radius
        let cue = SCNVector3(0.3598397971037417, y, -0.5416809291792913)
        let target = SCNVector3(-0.8853819663193399, y, -0.44039940642790193)
        let obstacle = mode == .masse ? SCNVector3(-0.01726232830820535, y, -0.5547654235081434)
            : SCNVector3(-0.013726731923182744, y, -0.5112964723538745)
        let input = mode == .masse
            ? SpatialQuizPhysics.Input(yaw: 3.0138771834392166, speed: 1.5, spinX: -0.3, spinY: -0.4, elevation: 10)
            : SpatialQuizPhysics.Input(yaw: atan2(-0.41624677325810716 - Double(cue.z), -0.8335864773381862 - Double(cue.x)),
                speed: 3.5, spinX: 0, spinY: 0.1, elevation: 50)
        return (.init(cue: cue, target: target, obstacle: obstacle, targetNumber: number, mode: mode), input)
    }
    func testRealMasseAndJumpReferencesUseSpaceAndPassNewRule() throws {
        for mode in SpatialQuizMode.allCases {
            let (board, input) = fixture(mode)
            let result = SpatialQuizPhysics.solve(board: board, input: input)
            XCTAssertEqual(result.prediction.termination, .settled)
            XCTAssertEqual(result.facts.issues, [], "\(mode)")
            XCTAssertTrue(result.outcome.succeeded, "\(mode): \(result.outcome)")
            let recorder = try XCTUnwrap(result.prediction.recorder)
            let spans = try XCTUnwrap(recorder.localIntervalsByBallName[ShotInput.cueBallName])
            XCTAssertFalse(spans.isEmpty, "Spatial intervals must not disappear into the planar default")
            let first = try XCTUnwrap(recorder.framesByBallName[ShotInput.cueBallName]?.first)
            XCTAssertLessThan(first.velocity.y, 0, "Elevated strike must consume the explicit angle")
            let peak = spans.map { max($0.start.position.y, $0.end.position.y) }.max() ?? 0
            if mode == .jump { XCTAssertGreaterThan(peak, Double(board.cue.y) + 0.05) }
            else {
                XCTAssertLessThan(peak, Double(board.cue.y) + 0.005)
                let points = spans.filter { $0.end.time < 0.4 }.map(\.end.position)
                let aim = input.aim
                let deviations: [Double] = points.map { point in
                    let dx = point.x - Double(board.cue.x)
                    let dz = point.z - Double(board.cue.z)
                    return abs(dx * Double(aim.z) - dz * Double(aim.x))
                }
                let deviation = deviations.max() ?? 0
                XCTAssertGreaterThan(deviation, 0.001, "Masse must retain actual curvature")
            }
            print("SPATIAL_QUIZ_B0 \(mode.rawValue): \(result.outcome), events=\(result.facts.events.count), peak=\(peak)")
        }
    }
    func testAdapterRequiresRecorderRolesAndKnownSurfaceEvidence() {
        let (board, _) = fixture(.masse)
        var prediction = ShotPrediction(); prediction.termination = .settled
        XCTAssertFalse(Judgement.evaluate(SpatialQuizPhysics.facts(prediction, board: board)).confirmed)
        prediction.recorder = TrajectoryRecorder()
        XCTAssertFalse(Judgement.evaluate(SpatialQuizPhysics.facts(prediction, board: board)).confirmed)
    }
    func testRealCushionWithoutPotIsSuccessful() {
        let y = BTTablePhysics.surfaceY + BallPhysics.radius
        let board = SpatialQuizPhysics.Board(cue: SCNVector3(-0.7, y, 0.2), target: SCNVector3(-0.2, y, 0.2),
            obstacle: SCNVector3(0.4, y, -0.3), targetNumber: 9)
        let input = SpatialQuizPhysics.Input(yaw: 0, speed: 2, spinX: 0, spinY: 0, elevation: 3)
        let result = SpatialQuizPhysics.solve(board: board, input: input)
        XCTAssertEqual(result.prediction.termination, .settled)
        XCTAssertTrue(result.prediction.pocketedBalls.isEmpty)
        XCTAssertEqual(result.facts.issues, [])
        XCTAssertTrue(result.outcome.succeeded, "\(result.outcome)")
        print("SPATIAL_QUIZ_B0 cushion-only: \(result.outcome)")
    }
    func testAdapterRejectsUnknownSurfaceAndRetainsExteriorBeforeRecovery() throws {
        let (board, input) = fixture(.masse)
        var result = SpatialQuizPhysics.solve(board: board, input: input)
        let recorder = try XCTUnwrap(result.prediction.recorder)
        let surfaceCount = try PocketGeometryAsset.load().surfaceRoles().count
        // Exterior indices are appended to the immutable table contact mesh by the solver.
        recorder.recordLocalStaticContact(.init(ballName: ShotInput.cueBallName, geometryID: "table-contact-geometry",
            contact: .init(time: 0.5, surface: surfaceCount, normal: .init(0, 1, 0))))
        XCTAssertEqual(Judgement.evaluate(SpatialQuizPhysics.facts(result.prediction, board: board)), .failure(.cueOutside))
        recorder.recordLocalStaticContact(.init(ballName: ShotInput.cueBallName, geometryID: "unknown-geometry",
            contact: .init(time: 0.6, surface: -1, normal: .init(0, 1, 0))))
        XCTAssertFalse(Judgement.evaluate(SpatialQuizPhysics.facts(result.prediction, board: board)).confirmed)
        result = SpatialQuizPhysics.solve(board: board, input: input)
        var prediction = result.prediction
        prediction.finalPositions.removeValue(forKey: "_8")
        XCTAssertFalse(Judgement.evaluate(SpatialQuizPhysics.facts(prediction, board: board)).confirmed)
    }
    func testCancelledAndBudgetLimitedSpatialAttemptsDoNotCount() {
        let (board, input) = fixture(.jump)
        let cancelled = PredictionCancellation(); cancelled.cancel()
        XCTAssertFalse(SpatialQuizPhysics.solve(board: board, input: input, cancellation: cancelled).outcome.confirmed)
        XCTAssertFalse(SpatialQuizPhysics.solve(board: board, input: input, maxEvents: 1, maxTime: 0.001).outcome.confirmed)
    }
    func testInvalidInputAndBlackTargetAreRejectedBeforeSimulation() {
        let (board, input) = fixture(.masse, number: 8)
        XCTAssertNil(SpatialQuizPhysics.solve(board: board, input: input).prediction.recorder)
        var invalid = input; invalid.elevation = 80
        XCTAssertNil(SpatialQuizPhysics.solve(board: fixture(.masse).0, input: invalid).prediction.recorder)
    }

    func testExistingAccuracyStillRequiresSelectedPocket() {
        var prediction = ShotPrediction(); prediction.termination = .settled
        prediction.events = [.init(time: 1, kind: .ballBall(ballA: ShotInput.cueBallName, ballB: ShotInput.targetBallName)),
            .init(time: 2, kind: .pocket(ball: ShotInput.targetBallName, pocketId: "pocket_0"))]
        prediction.pocketedBalls = [ShotInput.targetBallName]
        XCTAssertEqual(AccuracyShotJudgement.evaluate(prediction, pocketIndex: 0), .success)
        XCTAssertEqual(AccuracyShotJudgement.evaluate(prediction, pocketIndex: 1), .wrongPocket)
        prediction.cuePocketed = true
        XCTAssertEqual(AccuracyShotJudgement.evaluate(prediction, pocketIndex: 0), .scratch)
    }

    func testPlanarDefaultRemainsBitIdenticalAroundQuizSolve() {
        let (board, input) = fixture(.masse)
        func planar() -> ShotPrediction {
            ShotPredictor.simulateFree(cueBall: board.cue, aimDir: input.aim, velocity: 1.5,
                spinX: 0, spinY: 0, surfaceY: BTTablePhysics.surfaceY, balls: [])
        }
        func signature(_ prediction: ShotPrediction) -> [UInt32] {
            prediction.recorder?.framesByBallName[ShotInput.cueBallName]?.flatMap {
                [$0.time, $0.position.x, $0.position.y, $0.position.z, $0.velocity.x, $0.velocity.y, $0.velocity.z].map(\.bitPattern)
            } ?? []
        }
        let before = planar()
        XCTAssertFalse(signature(before).isEmpty)
        _ = SpatialQuizPhysics.solve(board: board, input: input)
        XCTAssertEqual(EventDrivenEngine.SimulationModel.appDefault, .planarReference)
        XCTAssertEqual(signature(before), signature(planar()))
    }
}

extension SpatialQuizTests {
    /// Independent polynomial witnesses, not generated from the classifier.
    private func techniqueWitness(curve:Double, height:Double, angle:Double = 0,
                                  mirror:Double = 1, obstacleOffset:Double = 0)
      -> (SpatialQuizPhysics.Board,[LocalPocketSimulation.Interval]) {
        typealias V = SIMD3<Double>
        let y = Double(BTTablePhysics.surfaceY+BallPhysics.radius)
        func rotate(_ p:V) -> V {
            V(p.x*cos(angle)-p.z*mirror*sin(angle),p.y,p.x*sin(angle)+p.z*mirror*cos(angle))
        }
        func scn(_ p:V) -> SCNVector3 { SCNVector3(Float(p.x),Float(p.y),Float(p.z)) }
        let p = rotate(V(-0.4,y,0)), v = rotate(V(0.8,4*height,4*curve)), a = rotate(V(0,-8*height,-8*curve))
        let board = SpatialQuizPhysics.Board(cue:scn(p),target:scn(rotate(V(0.45715,y,0))),
            obstacle:scn(rotate(V(0,y,obstacleOffset))),targetNumber:1)
        let start = LocalPocketSimulation.State(time:0,position:p,velocity:v,omega:.zero)
        let end = LocalPocketSimulation.State(time:1,position:p+v+a*0.5,velocity:v+a,omega:.zero)
        return (board,[.init(start:start,duration:1,acceleration:a,angularAcceleration:.zero,end:end)])
    }
    func testTechniqueSeparatesCurvedClothJumpSideJumpAndStraightRoutes() throws {
        for angle in [0.0,0.7,Double.pi/2,Double.pi] { for mirror in [-1.0,1.0] {
            for (curve,height,masse,jump) in [(0.08,0.0,true,false),(0.0,0.09,false,true),
                                           (0.08,0.09,true,false),(0.0,0.0,false,false)] {
                let (board,spans) = techniqueWitness(curve:curve,height:height,angle:angle,mirror:mirror)
                let technique = try XCTUnwrap(SpatialQuizTechnique.measure(intervals:spans,board:board,before:1))
                XCTAssertEqual(technique.maximumLift,height,accuracy:1e-7)
                XCTAssertEqual(technique.chordDeviation,curve,accuracy:1e-7)
                XCTAssertEqual(technique.jumpedOverObstacle,jump)
                for mode in SpatialQuizMode.allCases {
                    let facts = SpatialQuizFacts(complete:true,duration:5,
                        events:[hit,event(2,.pocket(.target,id:"pocket_0"))],issues:[],mode:mode,technique:technique)
                    XCTAssertEqual(SpatialQuizJudgement.evaluate(facts).succeeded,mode == .masse ? masse : jump)
                }
            }
        }}
    }
    func testMasseAllowsClearChordButStillUsesPreContactEvidenceOnly() throws {
        let (board,spans) = techniqueWitness(curve:0.08,height:0,obstacleOffset:0.2)
        let technique = try XCTUnwrap(SpatialQuizTechnique.measure(intervals:spans,board:board,before:1))
        XCTAssertGreaterThan(technique.chordDeviation,0.001)
        XCTAssertGreaterThan(technique.chordObstacleClearance,0)
        let facts = SpatialQuizFacts(complete:true,duration:5,
            events:[hit,event(2,.pocket(.target,id:"pocket_0"))],issues:[],mode:.masse,technique:technique)
        XCTAssertTrue(SpatialQuizJudgement.evaluate(facts).succeeded)
        let (flatBoard,flat) = techniqueWitness(curve:0,height:0)
        let after = LocalPocketSimulation.Interval(start:.init(time:1,position:flat[0].end.position,
            velocity:.init(0,1,1),omega:.zero),duration:1,acceleration:.zero,angularAcceleration:.zero,
            end:.init(time:2,position:flat[0].end.position+SIMD3(0,1,1),velocity:.init(0,1,1),omega:.zero))
        XCTAssertEqual(SpatialQuizTechnique.measure(intervals:flat+[after],board:flatBoard,before:1),
                       SpatialQuizTechnique.measure(intervals:flat,board:flatBoard,before:1))
        XCTAssertNil(SpatialQuizTechnique.measure(intervals:[after],board:flatBoard,before:1.5),"Missing pre-contact trace cannot pass")
    }
    func testTechniqueToleranceBoundaryAndMissingEvidence() throws {
        for height in [0.0009,0.0011] {
            let (board,spans) = techniqueWitness(curve:0.08,height:height)
            let measured = try XCTUnwrap(SpatialQuizTechnique.measure(intervals:spans,board:board,before:1))
            let facts = SpatialQuizFacts(complete:true,duration:5,
                events:[hit,event(2,.pocket(.target,id:"pocket_0"))],issues:[],mode:.masse,technique:measured)
            XCTAssertTrue(SpatialQuizJudgement.evaluate(facts).succeeded,"Lift alone does not disqualify a curved non-jump")
        }
        for mode in SpatialQuizMode.allCases {
            let base = [hit,event(2,.balls(.cue,.obstacle)),event(3,.pocket(.target,id:"pocket_0"))]
            let measured = SpatialQuizFacts.Technique(maximumLift:0,chordDeviation:0.01,chordObstacleClearance:-0.01,jumpedOverObstacle:mode == .jump)
            let valid = SpatialQuizFacts(complete:true,duration:5,events:base,issues:[],mode:mode,technique:measured)
            XCTAssertTrue(SpatialQuizJudgement.evaluate(valid).succeeded,"Post-target black-eight remains legal")
            var missing = valid; missing.technique = nil
            XCTAssertFalse(SpatialQuizJudgement.evaluate(missing).confirmed)
            let kick = SpatialQuizFacts(complete:true,duration:5,
                events:[event(0.5,.surface(.cue,.cushion,approaching:true))]+base,issues:[],mode:mode,technique:measured)
            XCTAssertEqual(SpatialQuizJudgement.evaluate(kick),.failure(.cushionBeforeTarget))
        }
    }
    func testV4ReclassifiesEveryRetainedV3Reference() throws {
        struct Row: Decodable { let id:String; let mode:SpatialQuizMode; let technique:SpatialQuizFacts.Technique }
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
        let rows=try JSONDecoder().decode([Row].self,from:Data(contentsOf:root.appendingPathComponent("tasks/spatial-v73/feedback-r4/reclassification-input.json")))
        XCTAssertEqual(rows.count,9323)
        for mode in SpatialQuizMode.allCases {
            let bank=try SpatialQuizBank.load(mode)
            XCTAssertEqual(Set(rows.filter { $0.mode == mode }.map(\.id)),Set(bank.questions.map(\.id)))
        }
        // Full v3 audit proved the unchanged common event rules. Re-evaluate its
        // frozen physical technique evidence through today's production judge.
        for row in rows {
            let facts=SpatialQuizFacts(complete:true,duration:5,
                events:[hit,event(2,.pocket(.target,id:"pocket_0"))],issues:[],mode:row.mode,technique:row.technique)
            XCTAssertTrue(SpatialQuizJudgement.evaluate(facts).succeeded,row.id)
        }
    }
    func testMasseCurveThresholdAndJumpExclusion() {
        for deviation in [0.0,0.0009,0.001,0.0011,0.08] {
            for jumped in [false,true] {
                let facts = SpatialQuizFacts(complete:true,duration:5,
                    events:[hit,event(2,.pocket(.target,id:"pocket_0"))],issues:[],mode:.masse,
                    technique:.init(maximumLift:0.09,chordDeviation:deviation,
                        chordObstacleClearance:0.2,jumpedOverObstacle:jumped))
                XCTAssertEqual(SpatialQuizJudgement.evaluate(facts).succeeded,deviation > 0.001 && !jumped)
            }
        }
    }
    func testRealStraightContactCannotPassEitherTechnique() {
        let y = BTTablePhysics.surfaceY+BallPhysics.radius
        for mode in SpatialQuizMode.allCases { for elevation in [0.0,3.0] {
            let board = SpatialQuizPhysics.Board(cue:SCNVector3(-0.7,y,0.2),target:SCNVector3(-0.2,y,0.2),
                obstacle:SCNVector3(0.4,y,-0.3),targetNumber:9,mode:mode)
            let result = SpatialQuizPhysics.solve(board:board,
                input:.init(yaw:0,speed:2,spinX:0,spinY:0,elevation:elevation))
            XCTAssertEqual(result.facts.issues,[])
            XCTAssertEqual(result.outcome,.failure(mode == .masse ? .noMasseAroundObstacle : .noJumpOverObstacle))
        }}
    }
}

extension SpatialQuizTests {
    func testRealReferenceCannotPassAsOtherTechniqueAndPlanarHandoffIsRequired() throws {
        for mode in SpatialQuizMode.allCases {
            var (board,input) = fixture(mode)
            board.mode = mode == .masse ? .jump : .masse
            let result = SpatialQuizPhysics.solve(board:board,input:input)
            XCTAssertEqual(result.outcome,.failure(mode == .masse ? .noJumpOverObstacle : .noMasseAroundObstacle))
            if mode == .masse {
                let original = try XCTUnwrap(result.prediction.recorder)
                let incomplete = TrajectoryRecorder()
                incomplete.recordLocalIntervals(ballName:ShotInput.cueBallName,
                    intervals:original.localIntervalsByBallName[ShotInput.cueBallName] ?? [])
                for frame in original.framesByBallName[ShotInput.cueBallName] ?? [] {
                    incomplete.recordFrame(ballName:ShotInput.cueBallName,frame:frame)
                }
                let end = try XCTUnwrap(result.facts.events.compactMap { event -> Double? in
                    if case let .balls(a,b) = event.kind, Set([a,b]) == [.cue,.target] { return event.time };return nil
                }.min())-SpatialQuizJudgement.contactTimeGroup
                XCTAssertNotNil(SpatialQuizTechnique.measure(recorder:original,board:board,before:end))
                XCTAssertNil(SpatialQuizTechnique.measure(recorder:incomplete,board:board,before:end),
                    "Frames alone cannot license an unknown spatial gap")
            }
        }
    }
    func testRealKickBeforeTargetFailsBothExercises() {
        let y = BTTablePhysics.surfaceY+BallPhysics.radius
        for mode in SpatialQuizMode.allCases {
            let board = SpatialQuizPhysics.Board(cue:SCNVector3(-0.7,y,0.2),target:SCNVector3(-0.2,y,0.2),
                obstacle:SCNVector3(0.4,y,-0.3),targetNumber:9,mode:mode)
            let result = SpatialQuizPhysics.solve(board:board,
                input:.init(yaw:Double.pi,speed:3,spinX:0,spinY:0,elevation:3))
            XCTAssertEqual(result.outcome,.failure(.cushionBeforeTarget),"\(result.outcome)")
        }
    }
}
