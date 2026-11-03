import XCTest
import CryptoKit
import SceneKit
@testable import QiuJi

final class BankKickSolverOptimizationTests: XCTestCase {
    let y: Float = 0.8
    func point(_ x: Float, _ z: Float) -> SCNVector3 { .init(x, y + BallPhysics.radius, z) }

    func test_coarseCandidateSurvivesRefinementAndDuplicateOffsetsAreRemoved() {
        XCTAssertEqual(ShotPredictor.bankKickFinalCandidates(polished: [0.02, -0.03, 0.02], coarse: [0, 0.04]),
                       [0.02, -0.03, 0, 0.04])
    }

    func test_exactInputCacheDoesNotAliasSubmillimeterMotionOrContinuousPower() {
        func key(_ x: Float = 0.1, _ power: Double = 3.6, _ name: String = "_2", _ height: Float = 0.8) -> BankKickSolveKey {
            .make(cue: .init(x, height, 0), object: point(0.2, 0.2),
                  obstacles: [.init(name: name, position: point(-0.3, 0.1))], pocketIndex: 1, power: power)
        }
        XCTAssertNotEqual(key(), key(0.1001))
        XCTAssertNotEqual(key(), key(0.1, 3.61))
        XCTAssertNotEqual(key(), key(0.1, 3.6, "_3"))
        XCTAssertNotEqual(key(), key(0.1, 3.6, "_2", 0.81))
        XCTAssertEqual(key(), key())
    }

    func test_cancelledRequestsDoNoSearch() {
        let token = PredictionCancellation(); token.cancel()
        XCTAssertTrue(BankKickSolvePipeline.solveBank(cue: point(-0.5,-0.2), object: point(0.1,0.1),
            pocketIndex: 1, surfaceY: y, power: 3.6, cancellation: token).isEmpty)
        XCTAssertTrue(BankKickSolvePipeline.solveKick(cue: point(-0.5,-0.2), target: point(0.4,0.25),
            surfaceY: y, power: 3.6, cancellation: token).isEmpty)
    }

    func test_deferredPresentationReusesFullRecorderAndMatchesEagerOutput() throws {
        for kick in [false, true] {
            var input = ShotInput(cueBall: point(-0.5,-0.2), targetBall: point(0.1,0.1),
                pocketIndex: 1, velocity: 3.6, spinX: 0.12, spinY: 0.1, surfaceY: y)
            if kick { input.kickRails = [.left] } else { input.bankRails = [.right] }
            var seed = ShotPrediction()
            let context = try XCTUnwrap(ShotPredictor.prepareAim(input, into: &seed))
            let aim = context.aimDir.rotatedY(0.02)
            let eager = ShotPredictor.buildPrediction(finalAim: aim, context: context, input: input,
                result: seed, maxEvents: 500, maxTime: 15)
            let compact = ShotPredictor.buildPrediction(finalAim: aim, context: context, input: input,
                result: seed, maxEvents: 500, maxTime: 15, includePresentation: false)
            let deferred = ShotPredictor.materializeBankKick(compact, input: input)
            XCTAssertTrue(compact.recorder === deferred.recorder, "Presentation must reuse the completed physics")
            XCTAssertEqual(deferred.termination, eager.termination)
            XCTAssertEqual(deferred.pocketedBalls.sorted(), eager.pocketedBalls.sorted())
            XCTAssertEqual(deferred.separationAngleDeg, eager.separationAngleDeg)
            for (a, b) in [(deferred.cuePath,eager.cuePath),(deferred.objectPath,eager.objectPath)] {
                XCTAssertEqual(a.count,b.count)
                for (p,q) in zip(a,b) {
                    XCTAssertEqual(p.x,q.x); XCTAssertEqual(p.y,q.y); XCTAssertEqual(p.z,q.z)
                }
            }
            XCTAssertEqual(deferred.ghost.x,eager.ghost.x); XCTAssertEqual(deferred.ghost.z,eager.ghost.z)
            XCTAssertEqual(deferred.firstContact?.x,eager.firstContact?.x)
            XCTAssertEqual(deferred.firstContact?.z,eager.firstContact?.z)
        }
    }

    func test_parallelRefinementMatchesSerialSelectionAndCompleteEvents() {
        let c = scenarios[1]
        func compare<S: RankableSolution>(_ serial: [S], _ parallel: [S]) {
            XCTAssertEqual(serial.count,parallel.count)
            for (a,b) in zip(serial,parallel) {
                XCTAssertEqual(a.spinX,b.spinX); XCTAssertEqual(a.goodness,b.goodness)
                XCTAssertEqual(a.cushions,b.cushions); XCTAssertEqual(a.pathLength,b.pathLength)
                XCTAssertEqual(a.prediction.termination,b.prediction.termination)
                XCTAssertEqual(a.prediction.aimDirection.x,b.prediction.aimDirection.x)
                XCTAssertEqual(a.prediction.aimDirection.z,b.prediction.aimDirection.z)
                XCTAssertEqual(a.prediction.events.map(\.time),b.prediction.events.map(\.time))
                XCTAssertEqual(a.prediction.events.map { String(describing:$0.kind) },
                               b.prediction.events.map { String(describing:$0.kind) })
            }
        }
        compare(BankKickSolvePipeline.solveBank(cue:c.cue,object:c.object,pocketIndex:c.pocket,
                    surfaceY:y,power:c.power,limit:nil,parallelRefinement:false),
                BankKickSolvePipeline.solveBank(cue:c.cue,object:c.object,pocketIndex:c.pocket,
                    surfaceY:y,power:c.power,limit:nil))
        compare(BankKickSolvePipeline.solveKick(cue:c.cue,target:c.object,surfaceY:y,power:c.power,
                    limit:nil,parallelRefinement:false),
                BankKickSolvePipeline.solveKick(cue:c.cue,target:c.object,surfaceY:y,power:c.power,limit:nil))
    }

    func test_runningSearchStopsAndPublishesNoPartialCatalog() {
        for kick in [false, true] {
            let token = PredictionCancellation()
            let finished = expectation(description: "cancelled search returns")
            let c = scenarios[1]
            DispatchQueue.global(qos: .userInitiated).async {
                let count = kick
                    ? BankKickSolvePipeline.solveKick(cue: c.cue, target: c.object, surfaceY: self.y,
                        power: c.power, cancellation: token).count
                    : BankKickSolvePipeline.solveBank(cue: c.cue, object: c.object, pocketIndex: c.pocket,
                        surfaceY: self.y, power: c.power, cancellation: token).count
                XCTAssertEqual(count, 0)
                finished.fulfill()
            }
            let deadline = Date().addingTimeInterval(5)
            while token.workCounts["bankKickSearch", default: 0] == 0 && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.001)
            }
            XCTAssertGreaterThan(token.workCounts["bankKickSearch", default: 0], 0)
            token.cancel()
            wait(for: [finished], timeout: 5)
        }
    }

    func test_successRejectsScratchAndUnfinishedResult() {
        var p = ShotPrediction(); p.termination = .settled; p.simObjectPotted = true
        p.objectRailContacts = [.far]
        p.events = [.init(time: 0.1, kind: .ballCushion(ball: ShotInput.cueBallName),
                          contactNormal: .init(0,0,1), cushionIndex: 0),
                    .init(time: 0.2, kind: .ballBall(ballA: ShotInput.cueBallName, ballB: ShotInput.targetBallName))]
        XCTAssertFalse(BankKickValidity.kick(p), "Contact alone does not satisfy the post-contact cushion rule")
        p.events.append(.init(time: 0.3, kind: .ballCushion(ball: ShotInput.targetBallName), cushionIndex: 0))
        XCTAssertTrue(BankKickValidity.kick(p))
        p.cuePocketed = true
        XCTAssertFalse(BankKickValidity.kick(p)); XCTAssertFalse(BankKickValidity.bank(p))
        p.cuePocketed = false; p.termination = .timeLimit
        XCTAssertFalse(BankKickValidity.kick(p)); XCTAssertFalse(BankKickValidity.bank(p))
        p.termination = .settled; p.events.removeFirst()
        XCTAssertTrue(BankKickValidity.bank(p)); XCTAssertFalse(BankKickValidity.kick(p))
    }

    func test_failedDraftDoesNotCarryPreviousRobustnessOrRailMetadata() {
        var p = ShotPrediction(); p.termination = .settled
        let input = ShotInput(cueBall: point(-0.5,-0.2), targetBall: point(0.1,0.1),
                              pocketIndex: 1, velocity: 0.5, spinX: 0.2, spinY: -0.1, surfaceY: y)
        let b = BankKickSolvePipeline.bankDraft(input: input, seedRails: [.far], prediction: p)
        let k = BankKickSolvePipeline.kickDraft(input: input, seedRails: [.far], prediction: p)
        XCTAssertNil(b.robustness); XCTAssertNil(k.robustness)
        XCTAssertEqual(b.cushions, 0); XCTAssertEqual(k.cushions, 0)
        XCTAssertEqual(b.spinX, input.spinX); XCTAssertEqual(k.spinY, input.spinY)
    }

    struct Scenario {
        let name: String
        let cue: SCNVector3
        let object: SCNVector3
        let pocket: Int
        let power: Float
        let obstacles: [ObstacleBall]
    }
    var scenarios: [Scenario] {
        [
            .init(name: "typical-2", cue: point(-0.5,-0.2), object: point(0.1,0.1), pocket: 1, power: 2, obstacles: []),
            .init(name: "typical-3.6", cue: point(-0.5,-0.2), object: point(0.1,0.1), pocket: 1, power: 3.6, obstacles: []),
            .init(name: "middle", cue: point(-0.55,0.15), object: point(-0.35,0.4), pocket: 4, power: 3.6, obstacles: []),
            .init(name: "long", cue: point(-0.9,-0.35), object: point(0.65,0.2), pocket: 2, power: 3.6, obstacles: []),
            .init(name: "frozen", cue: point(-0.5,-0.2), object: point(0.2,0.635-BallPhysics.radius), pocket: 1, power: 3.6, obstacles: []),
            .init(name: "obstacle", cue: point(-0.5,-0.2), object: point(0.4,0.25), pocket: 1, power: 3.6,
                  obstacles: [.init(name: "_2", position: point(-0.1,0.05)), .init(name: "_3", position: point(0.6,-0.25))]),
            .init(name: "weak", cue: point(-0.6,-0.2), object: point(0.6,0.2), pocket: 1, power: 0.5, obstacles: [])
        ]
    }
    struct Result {
        let prediction: ShotPrediction
        let spin: Float
        let spinY: Float
        let cushions: Int
        let robustness: Double?
    }
    /// Independent event oracle: settled, no scratch, first cue collision is the target;
    /// bank must pot the selected pocket after a main cushion; kick must hit a main cushion first.
    func valid(_ p: ShotPrediction, _ c: Scenario, kick: Bool) -> Bool {
        guard p.termination == .settled else { return false }
        let cue = ShotInput.cueBallName, target = ShotInput.targetBallName
        if p.events.contains(where: { if case .pocket(let b, _) = $0.kind { return b == cue }; return false }) { return false }
        guard let first = p.events.firstIndex(where: {
            if case .ballBall(let a, let b) = $0.kind { return a == cue || b == cue }; return false
        }), case .ballBall(let a, let b) = p.events[first].kind, Set([a,b]) == Set([cue,target]) else { return false }
        let cueRails = p.events[..<first].filter {
            if case .ballCushion(let b) = $0.kind { return b == cue && (0..<6).contains($0.cushionIndex ?? -1) }; return false
        }
        func parallelPair(_ events: ArraySlice<ShotEvent>, ball: String) -> Bool {
            let walls = events.compactMap { event -> Int? in
                guard case .ballCushion(let name) = event.kind, name == ball,
                      let index = event.cushionIndex, (0..<6).contains(index) else { return nil }
                return index < 4 ? index / 2 : index - 2
            }
            let opposite = [0:1,1:0,2:3,3:2]
            return zip(walls,walls.dropFirst()).contains { opposite[$0.0] == $0.1 }
        }
        if kick {
            guard !parallelPair(p.events[..<first],ball:cue) else { return false }
            return !cueRails.isEmpty && p.events.dropFirst(first + 1).contains { later in
                if case .ballCushion(let ball) = later.kind {
                    return later.time > p.events[first].time && (ball == cue || ball == target)
                }
                return false
            }
        }
        guard cueRails.isEmpty, let pot = p.events.firstIndex(where: {
            if case .pocket(let b, let id) = $0.kind { return b == target && id == "pocket_\(c.pocket)" }; return false
        }), pot > first else { return false }
        guard !parallelPair(p.events[first..<pot],ball:target) else { return false }
        return p.events[first..<pot].contains {
            if case .ballCushion(let b) = $0.kind { return b == target && (0..<6).contains($0.cushionIndex ?? -1) }; return false
        }
    }

    func solve(_ c: Scenario, kick: Bool, old: Bool) -> [Result] {
        if kick {
            if old { return FrozenBankKickSolvePipeline20261102.solveKick(cue: c.cue, target: c.object, surfaceY: y,
                power: c.power, obstacles: c.obstacles).map { .init(prediction: $0.prediction, spin: $0.spinX, spinY: $0.spinY, cushions: $0.cushions, robustness: $0.robustness) } }
            return BankKickSolvePipeline.solveKick(cue: c.cue, target: c.object, surfaceY: y,
                power: c.power, obstacles: c.obstacles, limit: nil).map { .init(prediction: $0.prediction, spin: $0.spinX, spinY: $0.spinY, cushions: $0.cushions, robustness: $0.robustness) }
        }
        if old { return FrozenBankKickSolvePipeline20261102.solveBank(cue: c.cue, object: c.object, pocketIndex: c.pocket,
            surfaceY: y, power: c.power, obstacles: c.obstacles).map { .init(prediction: $0.prediction, spin: $0.spinX, spinY: $0.spinY, cushions: $0.cushions, robustness: $0.robustness) } }
        return BankKickSolvePipeline.solveBank(cue: c.cue, object: c.object, pocketIndex: c.pocket,
            surfaceY: y, power: c.power, obstacles: c.obstacles, limit: nil).map { .init(prediction: $0.prediction, spin: $0.spinX, spinY: $0.spinY, cushions: $0.cushions, robustness: $0.robustness) }
    }

    func independentRobustness(_ r: Result?, _ c: Scenario, kick: Bool) -> Double {
        guard let r else { return -1 }
        let delta = Float.pi / 360
        let probes: [(Float, Float, Float)] = [(-delta,c.power,r.spin),(delta,c.power,r.spin),
            (0,c.power*0.92,r.spin),(0,c.power*1.08,r.spin),(0,c.power,r.spin-0.02),(0,c.power,r.spin+0.02)]
        let successes = probes.filter { angle, power, spin in
            let aim = r.prediction.aimDirection.rotatedY(angle)
            let p = ShotPredictor.simulateFree(cueBall:c.cue, aimDir:aim, velocity:power,
                spinX:spin, spinY:r.spinY, surfaceY:y,
                balls:[.init(name:ShotInput.targetBallName,position:c.object)]+c.obstacles,
                recordedStrikeDirection:aim)
            return valid(p,c,kick:kick)
        }.count
        return Double(successes)/6
    }

    func test_frozenAB_fullCatalogTimingValidityAndCushionCoverage() throws {
        var rows: [[String: Any]] = []
        for kick in [false,true] {
            for c in scenarios {
                var times = [[Double](), [Double]()]
                var results = [[Result](), [Result]()]
                for round in 0..<3 {
                    for version in (round % 2 == 0 ? [0,1] : [1,0]) {
                        let start = ProcessInfo.processInfo.systemUptime
                        let r = solve(c, kick: kick, old: version == 0)
                        times[version].append((ProcessInfo.processInfo.systemUptime-start)*1000)
                        results[version] = r
                    }
                }
                let oldValid = results[0].filter { valid($0.prediction,c,kick: kick) }
                let newValid = results[1].filter { valid($0.prediction,c,kick: kick) }
                XCTAssertEqual(results[1].count, newValid.count, c.name)
                XCTAssertTrue(oldValid.isEmpty || !newValid.isEmpty, "lost valid case: \(kick)/\(c.name)")
                let oldBuckets = Set(oldValid.map(\.cushions)), newBuckets = Set(newValid.map(\.cushions))
                XCTAssertTrue(oldBuckets.isSubset(of: newBuckets), "lost cushion bucket: \(kick)/\(c.name)")
                let oldRobustness = independentRobustness(oldValid.first,c,kick:kick)
                let newRobustness = independentRobustness(newValid.first,c,kick:kick)
                // Clean bank entry / centered kick contact now precede the old representative
                // preference. Keep first-place robustness as evidence; verify its reported value below.
                if kick {
                    let routes = newValid.compactMap { BankKickRoute.measured($0.prediction, kick: true) }
                    XCTAssertEqual(routes.count, newValid.count)
                    for (i, route) in routes.enumerated() {
                        for other in routes.dropFirst(i+1) { XCTAssertFalse(route.matches(other), c.name) }
                    }
                }
                if !kick, let a = oldValid.first, let b = newValid.first {
                    XCTAssertLessThanOrEqual(ShotPredictor.bankPocketContactCount(events:b.prediction.events),
                                             ShotPredictor.bankPocketContactCount(events:a.prediction.events),c.name)
                }
                if let reported = newValid.first?.robustness {
                    XCTAssertEqual(reported,newRobustness,accuracy:1e-8,"Full probes must match independent fixed-direction replay")
                }
                print("BANK_KICK_CASE \(kick ? "kick" : "bank")/\(c.name) old=\(times[0]) new=\(times[1]) valid=\(oldValid.count)->\(newValid.count)")
                var row: [String: Any] = [:]
                row["name"] = (kick ? "kick/" : "bank/") + c.name
                row["oldMS"] = times[0]
                row["newMS"] = times[1]
                row["oldValid"] = oldValid.count
                row["newValid"] = newValid.count
                row["oldInvalid"] = results[0].count - oldValid.count
                row["newInvalid"] = results[1].count - newValid.count
                row["oldBuckets"] = oldBuckets.sorted()
                row["newBuckets"] = newBuckets.sorted()
                row["oldFirstJaw"] = oldValid.first.map { ShotPredictor.bankPocketContactCount(events: $0.prediction.events) } ?? -1
                row["newFirstJaw"] = newValid.first.map { ShotPredictor.bankPocketContactCount(events: $0.prediction.events) } ?? -1
                row["oldFirstSpin"] = oldValid.first.map { Double(abs($0.spin)) } ?? -1
                row["newFirstSpin"] = newValid.first.map { Double(abs($0.spin)) } ?? -1
                row["oldFirstRobustness"] = oldValid.first?.robustness ?? -1
                row["newFirstRobustness"] = newValid.first?.robustness ?? -1
                row["oldFirstIndependentRobustness"] = oldRobustness
                row["newFirstIndependentRobustness"] = newRobustness
                rows.append(row)
            }
        }
        let data = try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted,.sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "bank-kick-ab.json"; attachment.lifetime = .keepAlways; add(attachment)
        print("BANK_KICK_AB " + String(decoding:data, as:UTF8.self))
    }
}

// Second-round baseline: complete ordered catalog, exact floating-point bits and recorded frames.
// Timing is a separate interval from hashing; profiler worker sums are not wall-clock phases.
extension BankKickSolverOptimizationTests {
    func structuralCatalog<S: RankableSolution>(_ solutions: [S]) throws -> String {
        func vector(_ p: SCNVector3) -> [UInt32] { [p.x.bitPattern,p.y.bitPattern,p.z.bitPattern] }
        let rows: [[String: Any]] = solutions.map { s in
            let p = s.prediction
            let frames: [[String: Any]] = (p.recorder?.framesByBallName.keys.sorted() ?? []).map { name in
                ["name":name,"frames":p.recorder!.framesByBallName[name]!.map { f -> [String: Any] in
                    ["t":f.time.bitPattern,"p":vector(f.position),"v":vector(f.velocity),
                     "w":[f.angularVelocity.x.bitPattern,f.angularVelocity.y.bitPattern,
                          f.angularVelocity.z.bitPattern,f.angularVelocity.w.bitPattern],"state":String(describing:f.state)]
                }]
            }
            return ["spin":s.spinX.bitPattern,"goodness":String(s.goodness.bitPattern),
                "cushions":s.cushions,"length":String(s.pathLength.bitPattern),
                "seed":s.searchKey.map { String(describing:$0) },
                "rails":s.route?.rails.map { String(describing:$0) } ?? [],
                "aim":vector(p.aimDirection),"ghost":vector(p.ghost),
                "termination":String(describing:p.termination),"potted":p.pocketedBalls.sorted(),
                "finals":p.finalPositions.mapValues(vector),"cuePath":p.cuePath.map(vector),
                "objectPath":p.objectPath.map(vector),"extraPaths":p.extraBallPaths.mapValues { $0.map(vector) },
                "events":p.events.map { e -> [String: Any] in
                    ["t":e.time.bitPattern,"kind":String(describing:e.kind),
                     "normal":e.contactNormal.map(vector) ?? [],"index":e.cushionIndex ?? -1]
                },"frames":frames]
        }
        let data = try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys])
        return SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined()
    }

    func test_structuralBaseline_completeCatalogAndPhaseTiming() throws {
        var rows: [[String: Any]] = []
        // Historical digests remain diagnostic evidence. The user replaced both route
        // contracts: clean bank entry (11-02), centered kick contact / one rail sequence (11-03).
        let baseline: [String:(digest:String,count:Int)] = [
            "bank/typical-2":("4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945",0),
            "bank/typical-3.6":("12684b092837de756a73f76e76dcc3b3f40682f1e6cb5e53ad5998cc4fb5c9fe",3),
            "bank/middle":("5f15a395b5c051ea1932cd9c38d02f942732b875dfd9ebba4c8cbaf94d2161d0",2),
            "bank/long":("84bc416b60809f1259aaf3693a83ef4db7dc61d2c053aef8a07591f02f288eeb",4),
            "bank/frozen":("a23d0670b9882c50f6fa31bef729d719788e36f5396c843739ade1597b23c1cc",1),
            "bank/obstacle":("f95d8533c780b7d56f91c20d38890c0c77669c89be8f076de4c038d2d0a3e213",1),
            "bank/weak":("4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945",0),
            "kick/typical-2":("a7ef663a303b1c4d2fd8293ca2ca6d720e3d52972e9dce34e02f871293cbb4b4",25),
            "kick/typical-3.6":("e019f3ed1ba0dcbf53ed2c4766c55519bea5e226abe7bee4cd82ed6283186c13",37),
            "kick/middle":("0dc0cbaae4d0e1651fa5ed01b604bb222614c46b9bf16dac9be905a90b1557f8",29),
            "kick/long":("8c7490e919c88de2b74bb52c4e1a2ed5c3a14270f5f44492a2edf91b4e7fe3e8",25),
            "kick/frozen":("6bee23793689e4c11a38c7fa20ba3336a08b1d0ccebdacd2905b8433453e52ef",27),
            "kick/obstacle":("fd5524f7b3150f52fd147e592bc6169e370e3603c72742e14d6d84703fc78c19",36),
            "kick/weak":("4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945",0)
        ]
        for kick in [false,true] {
            for c in scenarios {
                let name = (kick ? "kick/" : "bank/") + c.name
                var times: [Double] = [], digests: [String] = [], count = 0
                var profile = ""
                for _ in 0..<3 {
                    PerformanceProfiler.reset()
                    let start = ProcessInfo.processInfo.systemUptime
                    if kick {
                        let r = BankKickSolvePipeline.solveKick(cue:c.cue,target:c.object,surfaceY:y,
                            power:c.power,obstacles:c.obstacles,limit:nil)
                        times.append((ProcessInfo.processInfo.systemUptime-start)*1000)
                        digests.append(try structuralCatalog(r)); count = r.count
                        XCTAssertTrue(r.allSatisfy { KickRouteQuality.accepts($0.prediction) })
                        for (i, a) in r.enumerated() {
                            for b in r.dropFirst(i+1) { XCTAssertNotEqual(a.rails, b.rails, "One target / rail sequence is one kick solution") }
                        }
                    } else {
                        let r = BankKickSolvePipeline.solveBank(cue:c.cue,object:c.object,pocketIndex:c.pocket,
                            surfaceY:y,power:c.power,obstacles:c.obstacles,limit:nil)
                        times.append((ProcessInfo.processInfo.systemUptime-start)*1000)
                        digests.append(try structuralCatalog(r)); count = r.count
                        XCTAssertTrue(r.allSatisfy { BankRouteQuality.accepts($0.prediction) })
                        for (i, a) in r.enumerated() {
                            for b in r.dropFirst(i+1) { XCTAssertNotEqual(a.rails, b.rails, "One pocket / rail sequence is one bank solution") }
                        }
                    }
                    profile = PerformanceProfiler.reportText()
                }
                XCTAssertEqual(Set(digests).count,1,"Repeated catalog must be bitwise stable: \(name)")
                let expected = try XCTUnwrap(baseline[name])
                rows.append(["name":name,"ms":times,"digest":digests[0],"count":count,"profile":profile,
                             "comparedBaseline":false,"priorDigest":expected.digest,"priorCount":expected.count])
                print("BANK_KICK_STRUCTURAL_CASE \(name) ms=\(times) count=\(count) digest=\(digests[0])")
            }
        }
        let data = try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys])
        let attachment = XCTAttachment(data:data,uniformTypeIdentifier:"public.json")
        attachment.name = "bank-kick-structural.json"; attachment.lifetime = .keepAlways; add(attachment)
        print("BANK_KICK_STRUCTURAL " + String(decoding:data,as:UTF8.self))
    }
}

extension BankKickSolverOptimizationTests {
    func test_recorderLookupPreservesInsertionOrderBoundariesAndSnapshots() throws {
        let fixtures: [[Float]] = [[],[1],[0,1,1,1,2,10],[3,1,2,0],[0,.nan,2],[0,.infinity,3],[-.infinity,0,1]]
        let queries: [Float] = [-.infinity,-1,0,0.5,1,1.5,2,3,10,11,.infinity,.nan]
        for times in fixtures {
            let recorder = TrajectoryRecorder()
            for (i,t) in times.enumerated() {
                recorder.recordFrame(ballName:"a",frame:.init(time:t,position:.init(Float(i),0,0),
                    velocity:SCNVector3Zero,angularVelocity:SCNVector4Zero,state:.stationary))
                let frames = recorder.framesByBallName["a"]!
                for q in queries {
                    let expected = frames.first { $0.time >= q } ?? frames.last
                    XCTAssertEqual(recorder.stateAt(ballName:"a",time:q)?.position.x,expected?.position.x)
                }
            }
            XCTAssertNil(recorder.stateAt(ballName:"missing",time:0))
            if times.isEmpty { XCTAssertNil(recorder.stateAt(ballName:"a",time:0)) }
            let snapshot = recorder.framesByBallName
            recorder.recordFrame(ballName:"a",frame:.init(time:100,position:.init(100,0,0),
                velocity:SCNVector3Zero,angularVelocity:SCNVector4Zero,state:.stationary))
            XCTAssertEqual(snapshot["a"]?.count ?? 0,times.count,"Published value snapshots must not mutate")
            recorder.recordFrame(ballName:"b",frame:.init(time:0,position:.init(99,0,0),
                velocity:SCNVector3Zero,angularVelocity:SCNVector4Zero,state:.stationary))
            XCTAssertEqual(recorder.stateAt(ballName:"b",time:1)?.position.x,99)
        }
    }

    func test_recorderCostAgainstLegacyAppendAndQuery() throws {
        final class Legacy {
            var frames: [String:[BallFrame]] = [:]
            @inline(never) func append(_ frame:BallFrame) {
                var list = frames["cue"] ?? []; list.append(frame); frames["cue"] = list
            }
            @inline(never) func query(_ t:Float) -> BallFrame? {
                frames["cue"]?.first { $0.time >= t } ?? frames["cue"]?.last
            }
        }
        let frames = (0..<4000).map { i in
            BallFrame(time:Float(i)/120,position:.init(Float(i),0,0),velocity:SCNVector3Zero,
                      angularVelocity:SCNVector4Zero,state:.stationary)
        }
        var rows: [[String:Any]] = []
        for round in 0..<5 {
            for old in (round % 2 == 0 ? [true,false] : [false,true]) {
                let legacy = Legacy(), current = TrajectoryRecorder()
                let start = ProcessInfo.processInfo.systemUptime
                for f in frames { if old { legacy.append(f) } else { current.recordFrame(ballName:"cue",frame:f) } }
                let appendEnd = ProcessInfo.processInfo.systemUptime
                var sum:Float = 0
                for i in 0..<8000 {
                    let t = Float((i*997)%4000)/120
                    sum += (old ? legacy.query(t) : current.stateAt(ballName:"cue",time:t))!.position.x
                }
                let queryEnd = ProcessInfo.processInfo.systemUptime
                XCTAssertGreaterThan(sum,0)
                rows.append(["old":old,"appendMS":(appendEnd-start)*1000,"queryMS":(queryEnd-appendEnd)*1000,"checksum":sum])
            }
        }
        XCTAssertEqual(Set(rows.compactMap { $0["checksum"] as? Float }).count,1)
        let data = try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys])
        let attachment=XCTAttachment(data:data,uniformTypeIdentifier:"public.json")
        attachment.name="bank-kick-recorder-cost.json";attachment.lifetime = .keepAlways;add(attachment)
        print("BANK_KICK_RECORDER_COST " + String(decoding:data,as:UTF8.self))
    }

    func test_validationFactsMatchCompletePredictionAcrossProbeInputs() throws {
        var comparisons = 0, successful = 0, unsuccessful = 0
        for kick in [false,true] {
            for c in scenarios {
                var input = ShotInput(cueBall:c.cue,targetBall:c.object,pocketIndex:kick ? 0:c.pocket,
                    velocity:c.power,spinX:0,spinY:0,surfaceY:y)
                input.obstacles = c.obstacles
                let seeds: [(ShotInput, Float)]
                if kick {
                    seeds = ShotPredictor.predictKickAll(input,includePresentation:false).prefix(2).map { rails,p in
                        var i=input;i.kickRails=rails;return (i,p.aimOffsetUsed ?? 0)
                    }
                } else {
                    seeds = ShotPredictor.predictBankAll(input,includePresentation:false).prefix(2).map { rails,p in
                        var i=input;i.bankRails=rails;return (i,p.aimOffsetUsed ?? 0)
                    }
                }
                var fallback = input
                if kick { fallback.kickRails=[.left] } else { fallback.bankRails=[.right] }
                for (base,offset) in seeds + [(fallback,Float(0.3))] {
                    var scratch = ShotPrediction()
                    guard let context = ShotPredictor.prepareAim(base,into:&scratch) else { continue }
                    let probes: [(Float,Float,Float)] = [(-Float.pi/360,base.velocity,base.spinX),
                        (Float.pi/360,base.velocity,base.spinX),(0,base.velocity*0.92,base.spinX),
                        (0,base.velocity*1.08,base.spinX),(0,base.velocity,base.spinX-0.02),(0,base.velocity,base.spinX+0.02),
                        (0,0.01,0),(Float.pi,3.6,0)]
                    for (angle,speed,spin) in probes {
                        var probe=base;probe.velocity=speed;probe.spinX=spin
                        let full = ShotPredictor.bankKickProbe(input:probe,context:context,offset:offset+angle)
                        let facts = ShotPredictor.bankKickValidation(input:probe,context:context,offset:offset+angle)
                        XCTAssertEqual(facts.termination,full.termination)
                        XCTAssertEqual(facts.cuePocketed,full.cuePocketed)
                        XCTAssertEqual(facts.simObjectPotted,full.simObjectPotted)
                        XCTAssertEqual(facts.cueCushionsBeforeContact,full.cueCushionsBeforeContact)
                        XCTAssertEqual(facts.objectRailContacts,full.objectRailContacts)
                        XCTAssertEqual(facts.objectDepartureDir?.x,full.objectDepartureDir?.x)
                        XCTAssertEqual(facts.objectDepartureDir?.z,full.objectDepartureDir?.z)
                        XCTAssertEqual(facts.events.map(\.time),full.events.map(\.time))
                        XCTAssertEqual(facts.events.map { String(describing:$0.kind) },full.events.map { String(describing:$0.kind) })
                        XCTAssertEqual(BankKickValidity.bank(facts),BankKickValidity.bank(full))
                        XCTAssertEqual(BankKickValidity.kick(facts),BankKickValidity.kick(full))
                        let valid = kick ? BankKickValidity.kick(facts):BankKickValidity.bank(facts)
                        if valid { successful += 1 } else { unsuccessful += 1 }; comparisons += 1
                    }
                    let token=PredictionCancellation();token.cancel()
                    let cancelled=ShotPredictor.bankKickValidation(input:base,context:context,offset:offset,cancellation:token)
                    XCTAssertFalse(BankKickValidity.bank(cancelled));XCTAssertFalse(BankKickValidity.kick(cancelled))
                }
            }
        }
        XCTAssertGreaterThan(comparisons,100);XCTAssertGreaterThan(successful,0);XCTAssertGreaterThan(unsuccessful,0)
        print("BANK_KICK_VALIDATION_FACTS comparisons=\(comparisons) successful=\(successful) unsuccessful=\(unsuccessful)")
    }
}
