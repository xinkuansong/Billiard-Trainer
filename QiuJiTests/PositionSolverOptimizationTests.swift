import XCTest
import SceneKit
@testable import QiuJi

/// Fixed, reproducible A/B corpus. The reference is frozen solver source, with the
/// same current physics, tolerances, compiler and process as the candidate.
final class PositionSolverOptimizationTests: XCTestCase {
    private let y = BTTablePhysics.surfaceY
    struct Case {
        let name: String
        let board: BoardSnapshot
        let pocket: String
        let constraint: SolveConstraint
        var continuation: (([String: SCNVector3]) -> Double)? = nil
    }
    private func scene(_ p: CanvasPoint) -> SCNVector3 {
        AngleSceneCalculator.normalizedToScene(point: CGPoint(x: p.x, y: p.y), surfaceY: y)
    }
    private var cases: [Case] {
        let boards: [(String, CanvasPoint, CanvasPoint, String, [String: CanvasPoint])] = [
            ("straight", .init(x: 0.5, y: 0.35), .init(x: 0.5, y: 0.15), "topCenter", [:]),
            ("cut", .init(x: 0.3, y: 0.36), .init(x: 0.55, y: 0.17), "topCenter", [:]),
            ("corner", .init(x: 0.35, y: 0.34), .init(x: 0.72, y: 0.16), "topRight", [:]),
            ("obstacle", .init(x: 0.3, y: 0.36), .init(x: 0.55, y: 0.17), "topCenter",
                ["_2": .init(x: 0.7, y: 0.32), "_3": .init(x: 0.25, y: 0.13)])
        ]
        var result: [Case] = []
        for (name, cue, target, pocket, others) in boards {
            var balls = others; balls[PositionPlayBall.cueKey] = cue; balls["_1"] = target
            let board = BoardSnapshot(onTable: balls)
            let constraints: [(String, SolveConstraint)] = [
                ("wide", .restRegion(.circle(center: .init(x: 0.5, y: 0.25), radius: 0.35))),
                ("region", .restRegion(.circle(center: .init(x: 0.43, y: 0.31), radius: 0.08))),
                ("point", .restRegion(.point(center: .init(x: 0.57, y: 0.25), tolerance: 0.02))),
                ("rail-region", .restRegion(.rect(center: .init(x: 0.8, y: 0.37), halfWidth: 0.07, halfHeight: 0.045))),
                ("pass", .passThrough(point: .init(x: 0.62, y: 0.27), vMin: 0.3)),
                ("unreachable", .restRegion(.circle(center: .init(x: 1.5, y: 0.25), radius: 0.02)))
            ]
            for (kind, constraint) in constraints {
                result.append(Case(name: name + "/" + kind, board: board, pocket: pocket, constraint: constraint))
            }
            // The current PlanThree default: sampled comfort contour with the real
            // second/third balls included as colliders, constructed outside timing.
            var planned = balls
            planned["_2"] = .init(x: 0.68, y: 0.32); planned["_3"] = .init(x: 0.82, y: 0.16)
            let second = scene(planned["_2"]!)
            let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: second, pocketIndex: 5, surfaceY: y)
            if let mesh = PlanThreeComfortRegion.compute(ball: second, aim: aim, third: scene(planned["_3"]!)) {
                result.append(Case(name: name + "/comfort", board: BoardSnapshot(onTable: planned), pocket: pocket,
                                   constraint: .restRegion(.sampled(mesh)), continuation: { positions in
                                       MultiBallPositionScore.evaluate(positions: positions, target: "_2", pocket: 5,
                                           third: "_3", surfaceY: self.y).value
                                   }))
            }
        }
        return result
    }

    /// Independent oracle: full settled, selected pot and no scratch; passage is
    /// sampled at 2ms after first cue/target contact (production uses 10ms with pruning).
    private func valid(_ sol: PositionPlaySolution, _ c: Case) -> Bool {
        let p = sol.prediction
        guard p.hasFinalTableState, p.feasible, p.objectPocketed, !p.cuePocketed else { return false }
        switch c.constraint {
        case .restRegion(let region):
            guard p.cueFinalSpeed < 0.05, let stop = p.finalPositions[ShotInput.cueBallName] else { return false }
            return region.signedDistanceMeters(fromScene: stop, surfaceY: y) <= 0
        case .passThrough(let point, let vMin):
            guard let recorder = p.recorder, let contact = p.events.first(where: {
                if case let .ballBall(a, b) = $0.kind {
                    return Set([a, b]) == Set([ShotInput.cueBallName, ShotInput.targetBallName])
                }; return false
            })?.time else { return false }
            let playback = TrajectoryPlayback(recorder: recorder, surfaceY: y + AngleSceneCalculator.ballRadius)
            let target = scene(point)
            var t = contact + 0.0001
            while t <= p.duration {
                if let st = playback.stateAt(ballName: ShotInput.cueBallName, time: t),
                   hypotf(st.velocity.x, st.velocity.z) > Float(max(vMin, 0.2)),
                   hypotf(st.position.x - target.x, st.position.z - target.z) < 2 * AngleSceneCalculator.ballRadius {
                    return true
                }
                t += 0.002
            }
            return false
        }
    }

    private func continuation(_ sol: PositionPlaySolution, _ c: Case) -> Double {
        guard let evaluate = c.continuation else { return -1 }
        var positions = sol.prediction.finalPositions
        for name in sol.prediction.pocketedBalls { positions.removeValue(forKey: name) }
        positions.removeValue(forKey: ShotInput.targetBallName)
        let cue = positions.removeValue(forKey: ShotInput.cueBallName)
        positions[PositionPlayBall.cueKey] = cue
        return evaluate(positions)
    }

    private func perturbationHits(_ sol: PositionPlaySolution, _ c: Case) -> Int {
        guard let offset = sol.prediction.aimOffsetUsed,
              let cue = c.board.onTable[PositionPlayBall.cueKey], let target = c.board.onTable["_1"],
              let pocket = ShotIntent.pocketIndex(for: c.pocket) else { return 0 }
        let obstacles = c.board.onTable.filter { $0.key != "_1" && $0.key != PositionPlayBall.cueKey }
            .map { ObstacleBall(name: $0.key, position: scene($0.value)) }
        let shot = sol.shot, angle: Float = 0.5 * .pi / 180
        let probes: [(Float, Double, Double)] = [
            (offset + angle, shot.velocity, shot.spinY), (offset - angle, shot.velocity, shot.spinY),
            (offset, shot.velocity * 1.08, shot.spinY), (offset, shot.velocity * 0.92, shot.spinY),
            (offset, shot.velocity, shot.spinY + 0.05), (offset, shot.velocity, shot.spinY - 0.05)]
        return probes.filter { off, velocity, spinY in
            let input = ShotInput(cueBall: scene(cue), targetBall: scene(target), pocketIndex: pocket,
                velocity: Float(velocity), spinX: Float(shot.spinX), spinY: Float(spinY), surfaceY: y, obstacles: obstacles)
            let probe = PositionPlaySolution(shot: shot,
                prediction: ShotPredictor.predictForPositionSolve(input, aimOffset: off),
                cushionCount: 0, potted: true, margin: 0, summary: "probe", satisfiesConstraint: false)
            return valid(probe, c)
        }.count
    }

    func testABQualityAndTimings() throws {
        // Wall-clock includes the complete solve and final presentation trajectories.
        // Alternate order each round; validate outside the timed region.
        let corpus = cases
        var oldTimes = [[Double]](repeating: [], count: corpus.count)
        var newTimes = oldTimes
        var rows: [[String: Any]] = []
        var oldSolutions = [[PositionPlaySolution]](repeating: [], count: corpus.count)
        var newSolutions = oldSolutions
        func run(_ old: Bool, _ c: Case) -> [PositionPlaySolution] {
            if old {
                return FrozenPositionPlaySolver20261102.solve(before: c.board, targetKey: "_1", pocket: c.pocket,
                    constraint: c.constraint, surfaceY: y)
            }
            var params: PositionPlaySolver.SearchParams
            switch c.constraint {
            case .restRegion: params = .standard
            case .passThrough: params = .passThrough
            }
            params.continuation = c.continuation
            return PositionPlaySolver.solve(before: c.board, targetKey: "_1", pocket: c.pocket,
                constraint: c.constraint, surfaceY: y, params: params)
        }
        _ = run(true, corpus[0]); _ = run(false, corpus[0])
        for round in 0..<5 {
            for (i, c) in corpus.enumerated() {
                for old in (round.isMultiple(of: 2) ? [true, false] : [false, true]) {
                    let start = ProcessInfo.processInfo.systemUptime
                    let solutions = autoreleasepool { run(old, c) }
                    let ms = (ProcessInfo.processInfo.systemUptime - start) * 1000
                    if old { oldTimes[i].append(ms); oldSolutions[i] = solutions }
                    else {
                        if round > 0 {
                            func signature(_ list: [PositionPlaySolution]) -> [String] {
                                list.map { "\($0.shot.spinX)/\($0.shot.spinY)/\($0.shot.velocity)/\($0.satisfiesConstraint)/\($0.cushionCount)" }
                            }
                            XCTAssertEqual(signature(solutions), signature(newSolutions[i]), c.name + ": nondeterministic result")
                        }
                        newTimes[i].append(ms); newSolutions[i] = solutions
                    }
                }
            }
        }
        func percentile(_ values: [Double], _ p: Double) -> Double {
            let sorted = values.sorted(); return sorted[min(sorted.count - 1, Int(ceil(Double(sorted.count) * p)) - 1)]
        }
        for (i, c) in corpus.enumerated() {
            let old = oldSolutions[i], new = newSolutions[i]
            let ov = old.filter { valid($0, c) }, nv = new.filter { valid($0, c) }
            let falseOld = old.filter { $0.satisfiesConstraint && !valid($0, c) }.count
            let falseNew = new.filter { $0.satisfiesConstraint && !valid($0, c) }.count
            XCTAssertEqual(falseNew, 0, c.name + ": falsely reported success")
            if !ov.isEmpty { XCTAssertFalse(nv.isEmpty, c.name + ": lost an effective solution") }
            if let first = new.first, !nv.isEmpty {
                XCTAssertTrue(valid(first, c), c.name + ": recommendation must be valid")
            }
            if c.continuation == nil, let o = ov.first, let n = nv.first, abs(o.shot.spinX) < 1e-9 {
                XCTAssertEqual(n.shot.spinX, 0, accuracy: 1e-9, c.name + ": introduced unnecessary side spin")
            }
            if c.continuation != nil, let o = ov.first, let n = nv.first {
                XCTAssertGreaterThanOrEqual(PositionPlaySolver.continuationBand(continuation(n, c)),
                    PositionPlaySolver.continuationBand(continuation(o, c)), c.name + ": continuation band regressed")
                XCTAssertEqual(n.continuationScore ?? -1, continuation(n, c), accuracy: 1e-9)
            }
            let row: [String: Any] = ["case": c.name,
                "oldMs": oldTimes[i], "newMs": newTimes[i],
                "oldP50": percentile(oldTimes[i], 0.5), "newP50": percentile(newTimes[i], 0.5),
                "oldValid": ov.count, "newValid": nv.count, "oldFalsePositive": falseOld, "newFalsePositive": falseNew,
                "oldFirstSpin": ov.first.map { abs($0.shot.spinX) } ?? -1,
                "newFirstSpin": nv.first.map { abs($0.shot.spinX) } ?? -1,
                "oldFirstMargin": ov.first.map { Double($0.margin) } ?? -1,
                "newFirstMargin": nv.first.map { Double($0.margin) } ?? -1,
                "oldFirstRails": ov.first?.cushionCount ?? -1, "newFirstRails": nv.first?.cushionCount ?? -1,
                "oldPerturbationHits": ov.first.map { perturbationHits($0, c) } ?? -1,
                "newPerturbationHits": nv.first.map { perturbationHits($0, c) } ?? -1,
                "oldContinuation": ov.first.map { continuation($0, c) } ?? -1,
                "newContinuation": nv.first.map { continuation($0, c) } ?? -1]
            if percentile(newTimes[i], 0.5) > percentile(oldTimes[i], 0.5) * 1.05 {
                for old in [true, false] {
                    PerformanceProfiler.reset()
                    _ = run(old, c)
                    print("SOLVER_PROFILE \(c.name) old=\(old)\n" + PerformanceProfiler.reportText())
                }
            }
            rows.append(row)
            print("SOLVER_AB " + String(data: try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]), encoding: .utf8)!)
        }
        let allOld = oldTimes.flatMap { $0 }, allNew = newTimes.flatMap { $0 }
        let result: [String: Any] = ["rounds": 5, "cases": rows,
            "oldP50": percentile(allOld, 0.5), "newP50": percentile(allNew, 0.5),
            "oldP95": percentile(allOld, 0.95), "newP95": percentile(allNew, 0.95),
            "oldMax": allOld.max()!, "newMax": allNew.max()!]
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "position-solver-ab"; attachment.lifetime = .keepAlways; add(attachment)
        print("SOLVER_AB_SUMMARY oldP50=\(percentile(allOld, 0.5)) newP50=\(percentile(allNew, 0.5)) oldP95=\(percentile(allOld, 0.95)) newP95=\(percentile(allNew, 0.95))")
        // Same-device A/B allows 5% measurement noise, never a larger performance budget.
        XCTAssertLessThanOrEqual(percentile(allNew, 0.5), percentile(allOld, 0.5) * 1.05)
        XCTAssertLessThanOrEqual(percentile(allNew, 0.95), percentile(allOld, 0.95) * 1.05)
    }

    private func synthetic(contact: Float = 0.1) -> ShotPrediction {
        let recorder = TrajectoryRecorder()
        for (time, x, speed): (Float, Float, Float) in [(0, 0.2, -0.5), (0.2, 0.04, -0.5), (0.3, 0.01, -0.1), (0.4, 0.01, 0)] {
            recorder.recordFrame(ballName: ShotInput.cueBallName, frame: BallFrame(time: time,
                position: SCNVector3(x, y, 0), velocity: SCNVector3(speed, 0, 0),
                angularVelocity: SCNVector4(0, 0, 0, 0), state: speed == 0 ? .stationary : .rolling))
        }
        var pred = ShotPrediction(); pred.termination = .settled
        pred.objectPocketed = true; pred.simObjectPotted = true
        pred.recorder = recorder; pred.duration = 0.4
        pred.finalPositions = [ShotInput.cueBallName: SCNVector3(0.01, y, 0)]
        pred.events = [ShotEvent(time: contact, kind: .ballBall(ballA: ShotInput.cueBallName, ballB: ShotInput.targetBallName))]
        return pred
    }
    func testPassageAcceptsEarlierFastPassEvenWhenClosestSampleIsTooSlow() {
        XCTAssertTrue(PositionPlaySolver.assess(prediction: synthetic(),
            constraint: .passThrough(point: .init(x: 0.5, y: 0.25), vMin: 0.3), surfaceY: y).satisfied)
    }
    func testPassageRejectsPreContactOnlyScratchAndIncompleteTrajectory() {
        let constraint = SolveConstraint.passThrough(point: .init(x: 0.5, y: 0.25), vMin: 0.3)
        XCTAssertFalse(PositionPlaySolver.assess(prediction: synthetic(contact: 0.35), constraint: constraint, surfaceY: y).satisfied)
        var p = synthetic(); p.cuePocketed = true
        XCTAssertFalse(PositionPlaySolver.assess(prediction: p, constraint: constraint, surfaceY: y).satisfied)
        p = synthetic(); p.termination = .timeLimit
        XCTAssertFalse(PositionPlaySolver.assess(prediction: p, constraint: constraint, surfaceY: y).satisfied)
    }
    func testThinRegionHitDoesNotRequireFourCentimetersPerCushion() {
        var p = synthetic(); p.cueCushionCount = 3
        let result = PositionPlaySolver.assess(prediction: p,
            constraint: .restRegion(.circle(center: .init(x: 0.5, y: 0.25), radius: 0.01)), surfaceY: y)
        XCTAssertTrue(result.satisfied); XCTAssertGreaterThan(result.margin, 0)
        XCTAssertLessThan(result.margin, 0.04); XCTAssertEqual(result.cushionCount, 3)
    }
}

@MainActor
final class PositionSolverAdjustmentTests: XCTestCase {
    private func fixture() throws -> SolveShotSnapshot {
        let y = BTTablePhysics.surfaceY
        let board = BoardSnapshot(onTable: [PositionPlayBall.cueKey: .init(x: 0.5, y: 0.35), "_1": .init(x: 0.5, y: 0.15)])
        var p = PositionPlaySolver.SearchParams.standard
        p.spinXValues = [0]; p.spinYValues = [0]; p.velocityMin = 2; p.velocityMax = 2
        let solution = try XCTUnwrap(PositionPlaySolver.solve(before: board, targetKey: "_1", pocket: "topCenter",
            constraint: .restRegion(.circle(center: .init(x: 0.5, y: 0.25), radius: 0.4)), surfaceY: y, params: p).first)
        XCTAssertTrue(solution.satisfiesConstraint)
        let stop = try XCTUnwrap(solution.prediction.finalPositions[ShotInput.cueBallName])
        let center = AngleSceneCalculator.sceneToNormalized(position: stop)
        return SolveShotSnapshot(before: board, shot: solution.shot, prediction: solution.prediction,
            solutions: [solution], currentIndex: 0,
            draft: .region(.circle(center: .init(x: Double(center.x), y: Double(center.y)), radius: 0.005)),
            velocity: solution.shot.velocity, spinX: 0, spinY: 0, allowSideSpin: true, basicPositionOnly: false)
    }
    private func waitUntilIdle(_ busy: () -> Bool) async {
        let end = Date().addingTimeInterval(15)
        while busy() && Date() < end { try? await Task.sleep(nanoseconds: 20_000_000) }
        XCTAssertFalse(busy(), "Adjustment must finish")
    }
    private func assertAdjustedMiss(_ current: PositionPlaySolution?, snapshot: SolveShotSnapshot) throws {
        let current = try XCTUnwrap(current)
        XCTAssertTrue(current.prediction.hasFinalTableState)
        XCTAssertFalse(current.satisfiesConstraint, "Must not inherit catalog success after leaving the region")
        XCTAssertLessThan(current.margin, 0)
        XCTAssertNotEqual(current.shot.spinY, snapshot.shot.spinY)
    }
    func testPlanThreeAdjustmentAndUndoReassessActualTrajectory() async throws {
        let vm = PlanThreeViewModel(); vm.setupScene()
        let snap = try fixture()
        let context = PlanThreeViewModel.UndoContext(snapshot: snap, ball1Key: "_1", ball2Key: nil, ball3Key: nil,
            pocket1Index: ShotIntent.pocketIndex(for: "topCenter")!, pocket2Index: -1, armedRole: nil)
        vm.restore(from: context)
        vm.adjustCurrentSolution(velocity: 3, spinY: -0.4)
        await waitUntilIdle { vm.isComputing }
        try assertAdjustedMiss(vm.currentSolution, snapshot: snap)
        XCTAssertTrue(vm.solutions[0].satisfiesConstraint, "Catalog remains intact")
        let adjusted = try XCTUnwrap(vm.currentSolution)
        let undo = vm.makeUndoContext(shot: adjusted.shot, prediction: adjusted.prediction)
        vm.restore(from: context); vm.restore(from: undo)
        try assertAdjustedMiss(vm.currentSolution, snapshot: snap)
        vm.stopForDismissal()
    }
    func testSiluAdjustmentAndUndoReassessActualTrajectory() async throws {
        let vm = SiluTrainerViewModel(); vm.setupScene()
        let snap = try fixture()
        let context = SiluTrainerViewModel.UndoContext(snapshot: snap, selectedTargetKey: "_1", selectedPocketIndex: ShotIntent.pocketIndex(for: "topCenter")!)
        vm.restore(from: context)
        vm.adjustCurrentSolution(velocity: 3, spinY: -0.4)
        await waitUntilIdle { vm.isComputing }
        try assertAdjustedMiss(vm.currentSolution, snapshot: snap)
        XCTAssertTrue(vm.solutions[0].satisfiesConstraint)
        let adjusted = try XCTUnwrap(vm.currentSolution)
        let undo = vm.makeUndoContext(shot: adjusted.shot, prediction: adjusted.prediction)
        vm.restore(from: context); vm.restore(from: undo)
        try assertAdjustedMiss(vm.currentSolution, snapshot: snap)
        vm.stopForDismissal()
    }
}

final class PositionSolverContinuationTests: XCTestCase {
    private func solution(score: Double, side: Double, hit: Bool = true) -> PositionPlaySolution {
        PositionPlaySolution(shot: .init(targetKey: "_1", pocket: "topCenter", velocity: 2, spinX: side, spinY: 0),
            prediction: ShotPrediction(), cushionCount: 1, potted: true, margin: 0.02, summary: "test",
            satisfiesConstraint: hit, continuationScore: score)
    }
    func testFixedFivePointBandsPreferValidThenContinuationThenNoSideSpin() {
        let lowEasy = solution(score: 92, side: 0)
        let lowHard = solution(score: 94.9, side: 0.3)
        let higher = solution(score: 95, side: 0.3)
        let invalid = solution(score: 100, side: 0, hit: false)
        let sorted = [invalid, lowHard, higher, lowEasy].sorted(by: PositionPlaySolver.preferredSolution)
        XCTAssertEqual(sorted.map { $0.continuationScore! }, [95, 92, 94.9, 100])
        XCTAssertEqual(PositionPlaySolver.continuationBand(95), PositionPlaySolver.continuationBand(100))
        XCTAssertEqual(PositionPlaySolver.continuationBand(89.99), 17)
        XCTAssertEqual(PositionPlaySolver.continuationBand(90), 18)
    }
    func testEvaluatorSeesGridBeforeShortlistAndReportsFinalPolishedStop() throws {
        let y = BTTablePhysics.surfaceY
        let board = BoardSnapshot(onTable: [PositionPlayBall.cueKey: CanvasPoint(x: 0.3, y: 0.36), "_1": .init(x: 0.55, y: 0.17)])
        let constraint = SolveConstraint.restRegion(.circle(center: .init(x: 0.5, y: 0.25), radius: 0.4))
        var params = PositionPlaySolver.SearchParams.standard
        params.spinXValues = [0]; params.spinYValues = [-0.2, 0, 0.2]
        params.velocityMax = 3
        func score(_ p: SCNVector3) -> Double { max(0, 100 - Double(hypotf(p.x - 0.2, p.z - 0.3)) * 50) }
        var sampled = 0
        params.continuation = { positions in
            sampled += 1
            return positions[PositionPlayBall.cueKey].map(score) ?? 0
        }
        let results = PositionPlaySolver.solve(before: board, targetKey: "_1", pocket: "topCenter",
            constraint: constraint, surfaceY: y, params: params)
        XCTAssertGreaterThan(sampled, 3 * max(1, results.count), "Scoring must precede top-three truncation")
        let best = try XCTUnwrap(results.first)
        XCTAssertTrue(best.satisfiesConstraint)
        for result in results {
            let stop = try XCTUnwrap(result.prediction.finalPositions[ShotInput.cueBallName])
            XCTAssertEqual(try XCTUnwrap(result.continuationScore), score(stop), accuracy: 1e-9)
        }
        params.continuation = nil
        let ordinary = PositionPlaySolver.solve(before: board, targetKey: "_1", pocket: "topCenter",
            constraint: constraint, surfaceY: y, params: params)
        XCTAssertTrue(ordinary.allSatisfy { $0.continuationScore == nil })
        let oldStop = try XCTUnwrap(ordinary.first?.prediction.finalPositions[ShotInput.cueBallName])
        XCTAssertGreaterThanOrEqual(PositionPlaySolver.continuationBand(best.continuationScore),
                                    PositionPlaySolver.continuationBand(score(oldStop)))
    }
}
