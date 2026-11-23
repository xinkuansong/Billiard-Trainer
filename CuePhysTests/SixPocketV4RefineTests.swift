import XCTest
import SceneKit
import UIKit
@testable import QiuJi

/// v4 phase 2: in-cell refinement of the phase-1 candidates against the real engine.
///
/// Read-only use of the production engine. The optimiser never decides whether a shot succeeded —
/// success is only ever asserted from engine events (six target balls in their own pockets, cue
/// not pocketed, `.settled`) and then re-checked through the production entry
/// `ShotPredictor.simulateFree`. A near-zero residual on its own is not a result.
///
/// Opt-in: without `SIX_V4_DIR` and `SIX_V4_PLAN_JSON` every test skips.
final class SixPocketV4RefineTests: XCTestCase {
    // Coordinate contract, identical to the probe suite: SceneKit XZ horizontal, Y up, metres;
    // portrait screen up = +X, right = +Z.
    private let y: Float = 0.8
    /// Balls on the table and the pocket each one owns, as parallel arrays. Spec v5 removes one
    /// ball from the layout; `applyOmission` drops the pair so that everything downstream —
    /// placement, the success count, the replay obstacle list — follows from these two arrays.
    /// The emptied pocket stays in the geometry and stays a cue-pocketing risk, as the spec says.
    private var numbers = [1, 2, 3, 4, 5, 8]
    private var pocketIndices = [1, 3, 5, 2, 0, 4]
    private var omittedBall: Int?
    private func applyOmission(_ ball: Int?) {
        numbers = [1, 2, 3, 4, 5, 8]
        pocketIndices = [1, 3, 5, 2, 0, 4]
        omittedBall = nil
        guard let ball, let index = numbers.firstIndex(of: ball) else { return }
        numbers.remove(at: index)
        pocketIndices.remove(at: index)
        omittedBall = ball
    }
    private var geometry: TableGeometry { .chineseEightBallQiuJi(surfaceY: y) }
    private var cueName: String { ShotInput.cueBallName }
    private func key(_ ball: Int) -> String { "_\(ball)" }
    /// Pocket id each ball must fall into, by ball number.
    private func pocketID(_ ball: Int) -> String {
        geometry.pockets[pocketIndices[numbers.firstIndex(of: ball)!]].id
    }

    // MARK: - Harness

    private func env(_ k: String) -> String? {
        ProcessInfo.processInfo.environment[k] ?? ProcessInfo.processInfo.environment["TEST_RUNNER_" + k]
    }
    private func output() throws -> URL {
        guard let path = env("SIX_V4_DIR") else { throw XCTSkip("Opt-in v4 phase-2 refinement") }
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func write(_ value: Any, _ name: String, to out: URL) throws {
        try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
            .write(to: out.appendingPathComponent(name), options: .atomic)
    }
    private func planJSON() throws -> [String: Any] {
        guard let path = env("SIX_V4_PLAN_JSON") else { throw XCTSkip("SIX_V4_PLAN_JSON not supplied") }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw XCTSkip("plan JSON is not an object: \(path)")
        }
        return object
    }
    private var cueSpeedCap: Float { Float(env("SIX_V4_MAX_CUE_SPEED") ?? "8") ?? 8 }
    private var simulationBudget: Int { Int(env("SIX_V4_SIM_BUDGET") ?? "600") ?? 600 }
    private var wallClockBudget: TimeInterval { TimeInterval(env("SIX_V4_SECONDS") ?? "1800") ?? 1800 }

    private func distance(_ a: SCNVector3, _ b: SCNVector3) -> Float { hypotf(a.x - b.x, a.z - b.z) }

    // MARK: - Forbidden cue contacts (v4 clause 3a, unchanged by the v4.1 relaxation 3b)

    /// Cushion indices the cue may not touch: everything that is not one of the six straight
    /// rails, i.e. the corner jaw lines, the jaw fillet arcs and the corner/side throat and back
    /// walls. `EventDrivenEngine` reports circular arcs at `linearCushions.count + arcIndex`
    /// (see its cushion event construction), so linear and circular share one index space; the
    /// straight-rail classification is derived from the geometry exactly as probe A derives it.
    private func forbiddenCushionIndices() -> Set<Int> {
        let g = geometry
        let halfLength = TablePhysics.innerLength / 2, halfWidth = TablePhysics.innerWidth / 2
        var forbidden: Set<Int> = []
        for (i, s) in g.linearCushions.enumerated() {
            let onLongRail = abs(abs(s.start.z) - halfWidth) < 1e-4 && abs(abs(s.end.z) - halfWidth) < 1e-4
                && abs(s.normal.x) < 1e-4
            let onShortRail = abs(abs(s.start.x) - halfLength) < 1e-4 && abs(abs(s.end.x) - halfLength) < 1e-4
                && abs(s.normal.z) < 1e-4
            if !(onLongRail || onShortRail) { forbidden.insert(i) }
        }
        for arc in g.circularCushions.indices { forbidden.insert(g.linearCushions.count + arc) }
        return forbidden
    }

    // MARK: - Candidate model

    private struct Candidate {
        let order: [Int]
        let targetImpactParameters: [Float]      // b_k / R the plan wants for each ball, in order
        let toleranceInBallRadii: [Float]        // half-width of the acceptable b_k / R band
        let ballsChained: Int
        let closed: Bool
        var q: [Float]                           // cueX, cueZ, aim, speed, spinX, spinY
    }

    private func candidates(from plan: [String: Any]) -> [Candidate] {
        let acceptance = plan["acceptanceIntervalsDegrees"] as? [String: [[Int]]] ?? [:]
        func tolerance(_ ball: Int) -> Float {
            guard let runs = acceptance[String(ball)], let first = runs.first, first.count == 2 else {
                return 0.2
            }
            // The pot map's clean window is in degrees of the outgoing direction; the impact
            // parameter that produces it moves by b/R = 2 sin(phi), so the usable half-width in
            // impact-parameter units is 2 sin(half-width in radians).
            let half = Float(first[1] - first[0]) / 2 * .pi / 180
            return max(0.02, 2 * sinf(half))
        }
        func build(_ row: [String: Any], closed: Bool) -> Candidate? {
            guard let order = (row["order"] as? [NSNumber])?.map({ $0.intValue }),
                  let start = (row["cueStartXZ"] as? [NSNumber])?.map({ $0.floatValue }), start.count == 2,
                  let aim = (row["aimRadians"] as? NSNumber)?.floatValue,
                  let speed = (row["cueSpeed"] as? NSNumber)?.floatValue,
                  let events = row["events"] as? [[String: Any]] else { return nil }
            var targets: [Float] = []
            for ball in order {
                let match = events.first {
                    ($0["kind"] as? String) == "ballBall" && ($0["ball"] as? NSNumber)?.intValue == ball
                }
                targets.append((match?["impactParameterInBallRadii"] as? NSNumber)?.floatValue ?? 0)
            }
            let chained = (row["ballsChained"] as? NSNumber)?.intValue ?? order.count
            return Candidate(order: order, targetImpactParameters: targets,
                             toleranceInBallRadii: order.map(tolerance), ballsChained: chained,
                             closed: closed,
                             q: [start[0], start[1], aim, min(speed, cueSpeedCap),
                                 (row["spinX"] as? NSNumber)?.floatValue ?? 0,
                                 (row["spinY"] as? NSNumber)?.floatValue ?? 0])
        }
        var out: [Candidate] = []
        for row in plan["closableOrders"] as? [[String: Any]] ?? [] {
            if let c = build(row, closed: true) { out.append(c) }
        }
        // Phase 1 closed nothing on any rung, so its deepest partial chains are the only starting
        // points available. They are legitimate ones: u0 is fully determined by cue start, aim and
        // speed, and the residual vector below is defined for all six balls whether the planner
        // managed to chain them or not.
        for row in plan["deepestPartialChains"] as? [[String: Any]] ?? [] {
            if let c = build(row, closed: false) { out.append(c) }
        }
        let sorted = out.sorted { ($0.closed ? 1 : 0, $0.ballsChained) > ($1.closed ? 1 : 0, $1.ballsChained) }
        // Partial chains that agree on the planned prefix and on u0 differ only in balls the
        // planner never reached, so refining all of them would spend the whole budget on copies of
        // the same shot. Keep one per (prefix, u0) signature.
        var seen: Set<String> = []
        return sorted.filter { candidate in
            let prefix = candidate.order.prefix(max(1, candidate.ballsChained)).map(String.init).joined(separator: "-")
            let signature = prefix + String(format: "|%.4f,%.4f,%.4f,%.3f",
                                            candidate.q[0], candidate.q[1], candidate.q[2], candidate.q[3])
            return seen.insert(signature).inserted
        }
    }

    // MARK: - Engine evaluation

    private struct Outcome {
        var residuals: [Float]           // signed b_k/R minus target, per ball in visiting order
        var weightedCost: Float
        /// Metres of surface between the cue's path and the balls it never reached, summed. The
        /// only continuous signal available once a shot stops short: a pot is a step function, so
        /// without this the search is blind between routes that pot the same number of balls.
        var gapSumMetres: Float = 0
        var rejections: [String]
        var pottedCorrectly: Set<Int>
        var cuePocketed: Bool
        var termination: String
        var eventSignature: [String]
        var contactOrder: [Int]
        var planPrefixFollowed: Int
    }

    private func positions(_ d: Float) -> [SCNVector3] {
        let g = geometry
        return pocketIndices.map { i in
            let p = g.pockets[i].center
            if g.pockets[i].isCorner {
                let o = d / sqrtf(2)
                return SCNVector3(p.x - (p.x > 0 ? o : -o), y + BallPhysics.radius,
                                  p.z - (p.z > 0 ? o : -o))
            }
            return SCNVector3(0, y + BallPhysics.radius, p.z - (p.z > 0 ? d : -d))
        }
    }

    /// Signed perpendicular offset, in ball radii, of `centre` from the cue's path at the point of
    /// closest approach. Defined whether or not the cue actually reached the ball, which is what
    /// makes it usable as a residual: positive means the cue passed on the ball's left.
    private func signedImpactParameter(path: [SCNVector3], centre: SCNVector3) -> Float {
        var best = Float.greatestFiniteMagnitude
        var signed: Float = 0
        guard path.count >= 2 else { return 2 }
        for i in 0..<(path.count - 1) {
            let a = path[i], b = path[i + 1]
            let dx = b.x - a.x, dz = b.z - a.z
            let l2 = dx * dx + dz * dz
            guard l2 > 1e-12 else { continue }
            let t = max(0, min(1, ((centre.x - a.x) * dx + (centre.z - a.z) * dz) / l2))
            let px = a.x + t * dx, pz = a.z + t * dz
            let gap = hypotf(centre.x - px, centre.z - pz)
            if gap < best {
                best = gap
                let length = sqrtf(l2)
                // Left normal of travel, dotted onto (ball centre − path point).
                signed = (-dz / length) * (centre.x - px) + (dx / length) * (centre.z - pz)
                signed = signed >= 0 ? gap : -gap
            }
        }
        return signed / BallPhysics.radius
    }

    /// One engine run per call, wrapped in its own autorelease pool: the population search makes
    /// hundreds of thousands of these in a single test method, and without a pool the transient
    /// per-simulation objects are only drained when the method returns — which got the test
    /// process jetsammed ("crashed with signal kill") part-way through a long run.
    private func evaluate(_ q: [Float], candidate: Candidate, distance d: Float,
                          forbidden: Set<Int>) -> Outcome {
        autoreleasepool { evaluateOnce(q, candidate: candidate, distance: d, forbidden: forbidden) }
    }

    private func evaluateOnce(_ q: [Float], candidate: Candidate, distance d: Float,
                              forbidden: Set<Int>) -> Outcome {
        let places = positions(d)
        let e = EventDrivenEngine(tableGeometry: geometry)
        // Match ShotPredictor.simulateFree: normalise the aim and insert the cue before obstacles.
        let raw = SCNVector3(cosf(q[2]), 0, sinf(q[2]))
        let length = sqrtf(raw.x * raw.x + raw.z * raw.z)
        let strike = CueBallStrike.executeStrike(aimDirection: SCNVector3(raw.x / length, 0, raw.z / length),
                                                velocity: q[3], spinX: q[4], spinY: q[5])
        e.setBall(BallState(position: SCNVector3(q[0], y + BallPhysics.radius, q[1]),
                            velocity: strike.velocity, angularVelocity: strike.angularVelocity,
                            state: .sliding, name: cueName))
        for (i, p) in places.enumerated() {
            e.setBall(BallState(position: p, velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero,
                                state: .stationary, name: key(numbers[i])))
        }
        let termination = e.simulatePrediction(model: .appDefault, maxEvents: 4000, maxTime: 90,
                                               highFidelityBounds: true)
        let recorder = e.getTrajectoryRecorder()
        var rejections: [String] = []
        var contactOrder: [Int] = []
        var signature: [String] = []
        var struckAt: [String: Int] = [:]
        // v4.1 (spec §3b): a target ball may graze the jaw/fillet/throat on its way in; only more
        // than two of its own cushion events before dropping is a rejection. Rounds 1 and 2 counted
        // a single contact as fatal (clause 3a); that is the rule the user relaxed on 2026-09-17.
        var cushionsAfterStrike: [String: Int] = [:]
        let targetCushionLimit = 2
        for (index, event) in e.resolvedEvents.enumerated() {
            switch event {
            case let .ballBall(a, b):
                let pair = [a, b]
                guard pair.contains(cueName) else {
                    rejections.append("ballBall between two target balls: \(a)/\(b)")
                    signature.append("XX")
                    continue
                }
                let other = a == cueName ? b : a
                signature.append("B:\(other)")
                struckAt[other] = index
                if let ball = numbers.first(where: { key($0) == other }) { contactOrder.append(ball) }
            case let .ballCushion(name, cushion, _):
                signature.append("C:\(name):\(cushion)")
                if name == cueName {
                    if forbidden.contains(cushion) {
                        rejections.append("cue touched a forbidden cushion segment \(cushion)")
                    }
                } else if struckAt[name] != nil {
                    cushionsAfterStrike[name, default: 0] += 1
                }
            case let .pocket(name, _):
                signature.append("P:\(name)")
            case .transition:
                continue
            }
        }
        var potted: Set<Int> = []
        for entry in recorder.pocketEntries {
            let name = entry.ball.name
            if name == cueName { continue }
            guard let ball = numbers.first(where: { key($0) == name }) else { continue }
            if entry.pocketID == pocketID(ball) {
                potted.insert(ball)
                let cushions = cushionsAfterStrike[name] ?? 0
                if cushions > targetCushionLimit {
                    rejections.append("ball \(ball) hit \(cushions) cushions before dropping (v4.1 limit \(targetCushionLimit))")
                }
            } else {
                rejections.append("ball \(ball) fell into \(entry.pocketID), not \(pocketID(ball))")
            }
        }
        let cuePocketed = recorder.isBallPocketed(cueName)
        if cuePocketed { rejections.append("cue ball pocketed") }
        // v4 also forbids a target ball being knocked off its spot without dropping. Without this
        // check a run that moved a ball around the table and left it in play would read as clean.
        for ball in numbers where struckAt[key(ball)] != nil {
            let name = key(ball)
            if !recorder.isBallPocketed(name) {
                rejections.append("ball \(ball) was displaced without being potted")
            }
        }
        // How far the run followed the planned visiting order. This is deliberately *not* a hard
        // rejection: the order is a planning artefact, and the v4 success test only asks for six
        // balls in their own pockets under the clean/direct rules. Off-plan order is recorded and
        // penalised so the optimiser prefers the planned chain, but a genuine six-ball clearance
        // in some other order would still be recognised.
        var followed = 0
        for (i, ball) in contactOrder.enumerated() where i < candidate.order.count {
            if ball != candidate.order[i] { break }
            followed = i + 1
        }
        let deviatedFromPlan = followed < contactOrder.count
        // Residual vector: signed impact parameter minus the planned target, weighted by the
        // inverse of the acceptable band width. Balls beyond the first missed contact are still
        // reported, but they are given no weight: the cue never goes near them, so their
        // finite-difference derivatives are zero and including them only adds noise to the step.
        let path = (recorder.framesByBallName[cueName] ?? []).sorted { $0.time < $1.time }.map { $0.position }
        var residuals: [Float] = []
        var cost: Float = 0
        var gapSum: Float = 0
        for (i, ball) in candidate.order.enumerated() {
            let centre = places[numbers.firstIndex(of: ball)!]
            let measured = signedImpactParameter(path: path, centre: centre)
            let residual = measured - candidate.targetImpactParameters[i]
            residuals.append(residual)
            let weight = i <= followed ? 1 / max(0.02, candidate.toleranceInBallRadii[i]) : 0
            cost += (weight * residual) * (weight * residual)
            if !potted.contains(ball) {
                gapSum += max(0, abs(measured) - 2) * BallPhysics.radius
            }
        }
        // Chaining one more ball must always beat any residual improvement, and hard rejections
        // are a barrier rather than a discount: a rejected shot can never win, and a small
        // residual can never make one look successful.
        cost += 1e6 * Float(numbers.count - followed)
        cost += 1e4 * Float(rejections.count)
        if deviatedFromPlan { cost += 1e3 }
        return Outcome(residuals: residuals, weightedCost: cost, gapSumMetres: gapSum,
                       rejections: rejections,
                       pottedCorrectly: potted, cuePocketed: cuePocketed,
                       termination: String(describing: termination), eventSignature: signature,
                       contactOrder: contactOrder, planPrefixFollowed: followed)
    }

    /// Event signature without cushion indices. `ShotPredictor`'s public `ShotEvent` does not
    /// carry the cushion index, so this is the finest granularity on which the research entry and
    /// the production entry can be compared event for event.
    private func normalised(_ signature: [String]) -> [String] {
        signature.map { item in
            item.hasPrefix("C:") ? String(item.split(separator: ":").prefix(2).joined(separator: ":")) : item
        }
    }

    private func normalisedSignature(of events: [ShotEvent]) -> [String] {
        events.map { event in
            switch event.kind {
            case let .ballBall(a, b):
                let other = a == cueName ? b : (b == cueName ? a : "\(a)/\(b)")
                return "B:\(other)"
            case let .ballCushion(ball):
                return "C:\(ball)"
            case let .pocket(ball, _):
                return "P:\(ball)"
            }
        }
    }

    private func succeeded(_ o: Outcome) -> Bool {
        o.rejections.isEmpty && !o.cuePocketed && o.pottedCorrectly.count == numbers.count
            && o.termination == "settled"
    }

    private func clamp(_ q: [Float]) -> [Float] {
        var out = q
        let limit = CuePhysics.miscueLimitFraction
        out[0] = max(-TablePhysics.innerLength / 2 + BallPhysics.radius + 0.002,
                     min(TablePhysics.innerLength / 2 - BallPhysics.radius - 0.002, out[0]))
        out[1] = max(-TablePhysics.innerWidth / 2 + BallPhysics.radius + 0.002,
                     min(TablePhysics.innerWidth / 2 - BallPhysics.radius - 0.002, out[1]))
        out[3] = max(Float(ShotTuning.velocityRange.lowerBound), min(cueSpeedCap, out[3]))
        out[4] = max(-limit, min(limit, out[4]))
        out[5] = max(-limit, min(limit, out[5]))
        return out
    }

    // MARK: - Levenberg–Marquardt refinement

    func testCellRefinement() throws {
        let out = try output()
        let plan = try planJSON()
        let d = try XCTUnwrap((plan["distanceMetres"] as? NSNumber)?.floatValue)
        let rung = (plan["rung"] as? NSNumber)?.intValue ?? -1
        applyOmission((plan["omitBall"] as? NSNumber).map { $0.intValue }.flatMap { $0 == 0 ? nil : $0 })
        let forbidden = forbiddenCushionIndices()
        let list = candidates(from: plan)
        let started = Date()
        var reports: [[String: Any]] = []
        var winner: [String: Any]?
        // Finite-difference steps: metres, metres, radians, m/s, spin fraction, spin fraction.
        let steps: [Float] = [0.002, 0.002, 0.002, 0.02, 0.01, 0.01]

        for (candidateIndex, start) in list.enumerated() {
            if Date().timeIntervalSince(started) > wallClockBudget { break }
            var q = clamp(start.q)
            var simulations = 0
            var best = evaluate(q, candidate: start, distance: d, forbidden: forbidden)
            simulations += 1
            var bestQ = q
            var lambda: Float = 1e-3
            var iterations = 0
            var accepted = 0
            var restarts = 0
            var seed: UInt64 = 0x9E3779B97F4A7C15 &+ UInt64(candidateIndex)
            var trail: [[String: Any]] = []
            while simulations + steps.count + 1 <= simulationBudget,
                  Date().timeIntervalSince(started) <= wallClockBudget, !succeeded(best) {
                iterations += 1
                // Jacobian of the residual vector by forward differences.
                var jacobian = [[Float]](repeating: [Float](repeating: 0, count: steps.count),
                                         count: best.residuals.count)
                for j in 0..<steps.count {
                    var probe = q
                    probe[j] += steps[j]
                    let outcome = evaluate(clamp(probe), candidate: start, distance: d, forbidden: forbidden)
                    simulations += 1
                    for i in 0..<best.residuals.count {
                        jacobian[i][j] = (outcome.residuals[i] - best.residuals[i]) / steps[j]
                    }
                }
                // Normal equations (J^T J + lambda diag) delta = -J^T r, solved by Gauss-Jordan.
                var ata = [[Float]](repeating: [Float](repeating: 0, count: steps.count), count: steps.count)
                var atr = [Float](repeating: 0, count: steps.count)
                for i in 0..<best.residuals.count {
                    // Same staged weighting as the cost, so the step optimises the segment the
                    // chain is actually stuck on rather than balls the cue never approaches.
                    let weight: Float = i <= best.planPrefixFollowed
                        ? 1 / max(0.02, start.toleranceInBallRadii[i]) : 0
                    for a in 0..<steps.count {
                        atr[a] -= weight * weight * jacobian[i][a] * best.residuals[i]
                        for b in 0..<steps.count {
                            ata[a][b] += weight * weight * jacobian[i][a] * jacobian[i][b]
                        }
                    }
                }
                for a in 0..<steps.count { ata[a][a] += lambda * max(1e-6, ata[a][a]) }
                guard let delta = solve(ata, atr) else { break }
                var trial = q
                for a in 0..<steps.count where delta[a].isFinite { trial[a] += delta[a] * steps[a] }
                let candidateOutcome = evaluate(clamp(trial), candidate: start, distance: d, forbidden: forbidden)
                simulations += 1
                if candidateOutcome.weightedCost < best.weightedCost {
                    q = clamp(trial)
                    best = candidateOutcome
                    bestQ = q
                    lambda = max(1e-6, lambda / 3)
                    accepted += 1
                    trail.append(["iteration": iterations, "cost": best.weightedCost,
                                  "residuals": best.residuals, "pots": best.pottedCorrectly.sorted(),
                                  "rejections": best.rejections, "events": best.eventSignature])
                } else {
                    lambda *= 4
                    if lambda > 1e6 {
                        // Local minimum. Spend the rest of the budget on deterministic restarts
                        // around the best point rather than stopping with the budget unused.
                        lambda = 1e-3
                        restarts += 1
                        q = clamp(jitter(bestQ, seed: &seed, scale: Float(restarts)))
                        let restarted = evaluate(q, candidate: start, distance: d, forbidden: forbidden)
                        simulations += 1
                        if restarted.weightedCost < best.weightedCost {
                            best = restarted
                            bestQ = q
                        }
                    }
                }
            }
            var report: [String: Any] = [
                "candidateIndex": candidateIndex, "order": start.order, "closedInPhase1": start.closed,
                "ballsChainedInPhase1": start.ballsChained, "simulations": simulations,
                "iterations": iterations, "acceptedSteps": accepted, "restarts": restarts,
                "startParameters": start.q, "bestParameters": bestQ,
                "bestCost": best.weightedCost, "bestResiduals": best.residuals,
                "targetImpactParameters": start.targetImpactParameters,
                "pottedCorrectly": best.pottedCorrectly.sorted(),
                "rejections": best.rejections, "termination": best.termination,
                "contactOrder": best.contactOrder, "eventSignature": best.eventSignature,
                "planPrefixFollowed": best.planPrefixFollowed, "distanceMetres": d,
                "omitBall": omittedBall ?? 0, "targetBalls": numbers,
                "succeeded": succeeded(best), "acceptedTrail": trail]
            if succeeded(best) {
                // Determinism, then the production entry point. Only these two make it a result.
                let repeated = evaluate(bestQ, candidate: start, distance: d, forbidden: forbidden)
                report["repeatIsIdentical"] = repeated.eventSignature == best.eventSignature
                    && repeated.pottedCorrectly == best.pottedCorrectly
                let cue = SCNVector3(bestQ[0], y + BallPhysics.radius, bestQ[1])
                let prediction = ShotPredictor.simulateFree(
                    cueBall: cue, aimDir: SCNVector3(cosf(bestQ[2]), 0, sinf(bestQ[2])),
                    velocity: bestQ[3], spinX: bestQ[4], spinY: bestQ[5], surfaceY: y,
                    balls: positions(d).enumerated().map {
                        ObstacleBall(name: key(numbers[$0.offset]), position: $0.element) },
                    maxEvents: 4000, maxTime: 90, includePresentation: true)
                let engineNormalised = normalised(best.eventSignature)
                let replayNormalised = normalisedSignature(of: prediction.events)
                var replayPockets: [String: String] = [:]
                for entry in prediction.recorder?.pocketEntries ?? [] {
                    replayPockets[entry.ball.name] = entry.pocketID
                }
                report["normalisedEventSignature"] = engineNormalised
                report["replayEventSignature"] = replayNormalised
                report["replayPocketedBalls"] = prediction.pocketedBalls.sorted()
                report["replayPocketIDs"] = replayPockets
                report["replayCuePocketed"] = prediction.cuePocketed
                report["replayTermination"] = String(describing: prediction.termination)
                report["expectedPocketIDs"] = Dictionary(uniqueKeysWithValues: numbers.map { (key($0), pocketID($0)) })
                report["replayMatchesEngine"] = Set(prediction.pocketedBalls) == Set(numbers.map(key))
                    && !prediction.cuePocketed
                    && replayNormalised == engineNormalised
                    && numbers.allSatisfy { replayPockets[key($0)] == pocketID($0) }
                if winner == nil { winner = report }
            }
            reports.append(report)
            if winner != nil { break }
        }

        try write(["rung": rung, "distanceMetres": d, "cueSpeedCap": cueSpeedCap,
                   "omitBall": omittedBall ?? 0, "targetBalls": numbers,
                   "candidatesAvailable": list.count, "candidatesRefined": reports.count,
                   "simulationBudgetPerCandidate": simulationBudget,
                   "forbiddenCushionIndices": forbidden.sorted(),
                   "allTargetsPottedSolutionFound": winner != nil,
                   "sixBallSolutionFound": winner != nil && numbers.count == 6,
                   "candidates": reports,
                   "note": "success is asserted only from engine events plus a ShotPredictor.simulateFree "
                           + "replay; residual size alone is never treated as a result"],
                  "refine-summary.json", to: out)
        if let winner {
            try write(winner, "best.json", to: out)
        }
        XCTAssertGreaterThan(reports.count, 0, "no phase-1 candidate could be read from the plan JSON")
    }

    // MARK: - Route-archive population search (spec v5)

    /// Why this exists alongside the LM refiner: on this problem one engine simulation costs about
    /// four milliseconds, and the LM pass spends its whole budget — six finite differences per
    /// step — climbing one basin, which rounds 1–3 showed converges to one or two pots. The number
    /// of pots is a step function of the controls, so gradients only exist inside a basin. This
    /// pass therefore searches basins instead: every distinct (potted set, contact order) the
    /// engine produces is kept as its own archive entry with its own mutation width, so a route
    /// that pots fewer balls but reaches a new part of the table is not discarded.
    ///
    /// Judging is unchanged. `evaluate` applies the same hard rejections and `succeeded` still
    /// asks for every target in its own pocket, cue not pocketed, `settled`; the cost below only
    /// decides where to look next.
    private func searchCost(_ o: Outcome) -> Float {
        1e9 * Float(numbers.count - o.pottedCorrectly.count)
            + 1e7 * Float(o.rejections.count)
            + 1e3 * o.gapSumMetres
    }

    private struct ArchiveEntry {
        var q: [Float]
        var cost: Float
        var pots: Int
        var scale: Float
        var misses: Int
    }

    func testPopulationSearch() throws {
        let out = try output()
        let plan = try planJSON()
        let d = try XCTUnwrap((plan["distanceMetres"] as? NSNumber)?.floatValue)
        let rung = (plan["rung"] as? NSNumber)?.intValue ?? -1
        applyOmission((plan["omitBall"] as? NSNumber).map { $0.intValue }.flatMap { $0 == 0 ? nil : $0 })
        let forbidden = forbiddenCushionIndices()
        let seeds = candidates(from: plan)
        let seconds = TimeInterval(env("SIX_V5_SECONDS") ?? "900") ?? 900
        let simulationCap = Int(env("SIX_V5_SIMS") ?? "400000") ?? 400_000
        // Probability of drawing the parent from the elite pair instead of the tournament. Default
        // 0 = v5 behaviour unchanged.
        let eliteFraction = Float(env("SIX_V6_ELITE") ?? "0") ?? 0
        var rng: UInt64 = UInt64(env("SIX_V5_SEED") ?? "1") ?? 1
        func next() -> Float {
            rng = rng &* 6364136223846793005 &+ 1442695040888963407
            return Float(rng >> 40) / Float(1 << 24)
        }
        func symmetric() -> Float { next() * 2 - 1 }

        // Scoring probe: `evaluate` needs a candidate to define the residual vector, and the
        // population search wants residuals for every target, so the probe lists all of them with
        // a zero target. Only `pottedCorrectly`, `rejections` and `gapSumMetres` are read back.
        let probe = Candidate(order: numbers, targetImpactParameters: numbers.map { _ in 0 },
                              toleranceInBallRadii: numbers.map { _ in 0.2 },
                              ballsChained: 0, closed: false, q: [])
        let halfLength = TablePhysics.innerLength / 2, halfWidth = TablePhysics.innerWidth / 2
        let places = positions(d)
        func randomShot() -> [Float] {
            var q: [Float] = [0, 0, 0, 0, 0, 0]
            repeat {
                q[0] = (symmetric()) * (halfLength - BallPhysics.radius - 0.01)
                q[1] = (symmetric()) * (halfWidth - BallPhysics.radius - 0.01)
            } while places.contains { distance($0, SCNVector3(q[0], y, q[1])) < 2.2 * BallPhysics.radius }
            q[2] = next() * 2 * .pi
            q[3] = 0.5 + next() * (cueSpeedCap - 0.5)
            let limit = CuePhysics.miscueLimitFraction
            let angle = next() * 2 * .pi, radius = sqrtf(next()) * limit
            q[4] = radius * cosf(angle)
            q[5] = radius * sinf(angle)
            return clamp(q)
        }

        var archive: [String: ArchiveEntry] = [:]
        // Cheap incremental trackers for the two entries worth extra local density: the outright
        // cheapest route, and the best *clean* route (most pots, then cheapest). Scanning the
        // archive for them on every pick would cost more than the simulation it feeds.
        var bestCostKey: String?
        var bestCleanKey: String?
        var simulations = 0
        var winner: [String: Any]?
        var bestOverall: (cost: Float, q: [Float], outcome: Outcome)?
        let started = Date()
        let spread: [Float] = [0.08, 0.08, 0.06, 0.4, 0.12, 0.12]

        func consider(_ q: [Float]) -> Outcome {
            let outcome = evaluate(q, candidate: probe, distance: d, forbidden: forbidden)
            simulations += 1
            let cost = searchCost(outcome)
            if bestOverall == nil || cost < bestOverall!.cost { bestOverall = (cost, q, outcome) }
            let pots: String = outcome.pottedCorrectly.sorted().map(String.init).joined(separator: "-")
            let contacts: String = outcome.contactOrder.map(String.init).joined(separator: "-")
            let cleanliness: String = outcome.rejections.isEmpty ? "clean" : "v\(outcome.rejections.count)"
            let routeKey: String = pots + "|" + contacts + "|" + cleanliness
            if let existing = archive[routeKey] {
                if cost < existing.cost {
                    archive[routeKey] = ArchiveEntry(q: q, cost: cost,
                                                     pots: outcome.pottedCorrectly.count,
                                                     scale: max(0.25, existing.scale * 0.8), misses: 0)
                } else {
                    var bumped = existing
                    bumped.misses += 1
                    // A basin that keeps refusing improvements is either exhausted or too tightly
                    // sampled; widen it rather than abandoning the route.
                    if bumped.misses > 40 { bumped.scale = min(4, bumped.scale * 1.5); bumped.misses = 0 }
                    archive[routeKey] = bumped
                }
            } else {
                archive[routeKey] = ArchiveEntry(q: q, cost: cost,
                                                 pots: outcome.pottedCorrectly.count,
                                                 scale: 1, misses: 0)
            }
            if let entry = archive[routeKey] {
                if bestCostKey == nil || entry.cost < (archive[bestCostKey!]?.cost ?? .infinity) {
                    bestCostKey = routeKey
                }
                if routeKey.hasSuffix("|clean"), let incumbent = bestCleanKey.flatMap({ archive[$0] }) {
                    if (entry.pots, -entry.cost) > (incumbent.pots, -incumbent.cost) { bestCleanKey = routeKey }
                } else if routeKey.hasSuffix("|clean") {
                    bestCleanKey = routeKey
                }
            }
            return outcome
        }

        // Seeds: the planner chains, plus — when resuming — the archive of an earlier run on the
        // same combination. A 150 s sweep is not enough to finish a basin, and restarting from
        // scratch would throw away the routes it paid for.
        var resumed = 0
        if let resume = env("SIX_V5_RESUME"), FileManager.default.fileExists(atPath: resume) {
            let data = try Data(contentsOf: URL(fileURLWithPath: resume))
            let saved = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            for row in saved["topRoutes"] as? [[String: Any]] ?? [] {
                guard let parameters = (row["parameters"] as? [NSNumber])?.map({ $0.floatValue }),
                      parameters.count == 6 else { continue }
                _ = consider(clamp(parameters))
                resumed += 1
            }
        }
        for seed in seeds {
            let outcome = consider(clamp(seed.q))
            if succeeded(outcome) { break }
        }
        var iterations = 0
        while simulations < simulationCap, Date().timeIntervalSince(started) < seconds {
            iterations += 1
            var q: [Float]
            if archive.isEmpty || next() < 0.12 {
                q = randomShot()
            } else if eliteFraction > 0, next() < eliteFraction,
                      let pick = (next() < 0.5 ? bestCostKey : bestCleanKey) ?? bestCostKey,
                      let parent = archive[pick] {
                // Elite branch, off by default (`SIX_V6_ELITE` unset keeps the v5 run path and its
                // random stream exactly as it was: `&&`/`,` short-circuits before `next()`).
                // Why it exists: with several thousand archive entries a tournament of three almost
                // never draws the one route that is a single ball short, so the basin around the
                // best route gets no more sampling than any other. On the six-ball problem the
                // seeded rung-2 archive already holds a clean five-pot route whose only continuous
                // signal — the cue path's gap to the sixth ball — is exactly what mutating *that*
                // entry can close.
                q = parent.q
                for i in q.indices { q[i] += symmetric() * spread[i] * parent.scale }
                q = clamp(q)
            } else {
                // Tournament of three, biased to routes that potted more: exploit the good basins
                // without letting the single best one monopolise the budget.
                let keys = archive.keys.sorted()
                var pick = keys[Int(next() * Float(keys.count)) % keys.count]
                for _ in 0..<2 {
                    let other = keys[Int(next() * Float(keys.count)) % keys.count]
                    if let a = archive[other], let b = archive[pick], a.cost < b.cost { pick = other }
                }
                let parent = archive[pick]!
                q = parent.q
                for i in q.indices { q[i] += symmetric() * spread[i] * parent.scale }
                q = clamp(q)
            }
            let outcome = consider(q)
            if succeeded(outcome) {
                let repeated = evaluate(q, candidate: probe, distance: d, forbidden: forbidden)
                simulations += 1
                let engineNormalised = normalised(outcome.eventSignature)
                let prediction = ShotPredictor.simulateFree(
                    cueBall: SCNVector3(q[0], y + BallPhysics.radius, q[1]),
                    aimDir: SCNVector3(cosf(q[2]), 0, sinf(q[2])), velocity: q[3], spinX: q[4],
                    spinY: q[5], surfaceY: y,
                    balls: places.enumerated().map { ObstacleBall(name: key(numbers[$0.offset]), position: $0.element) },
                    maxEvents: 4000, maxTime: 90, includePresentation: true)
                var replayPockets: [String: String] = [:]
                for entry in prediction.recorder?.pocketEntries ?? [] {
                    replayPockets[entry.ball.name] = entry.pocketID
                }
                let replayNormalised: [String] = normalisedSignature(of: prediction.events)
                let expectedPockets: [String: String] =
                    Dictionary(uniqueKeysWithValues: numbers.map { (key($0), pocketID($0)) })
                let ballXZ: [String: [Float]] = Dictionary(uniqueKeysWithValues: numbers.enumerated()
                    .map { (key($0.element), [places[$0.offset].x, places[$0.offset].z]) })
                let pocketsMatch: Bool = numbers.allSatisfy { replayPockets[key($0)] == pocketID($0) }
                let ballsMatch: Bool = Set(prediction.pocketedBalls) == Set(numbers.map(key))
                let deterministic: Bool = repeated.eventSignature == outcome.eventSignature
                    && repeated.pottedCorrectly == outcome.pottedCorrectly
                var record: [String: Any] = [:]
                record["rung"] = rung
                record["distanceMetres"] = d
                record["omitBall"] = omittedBall ?? 0
                record["targetBalls"] = numbers
                record["bestParameters"] = q
                record["cueSpeedCap"] = cueSpeedCap
                record["pottedCorrectly"] = outcome.pottedCorrectly.sorted()
                record["contactOrder"] = outcome.contactOrder
                record["termination"] = outcome.termination
                record["rejections"] = outcome.rejections
                record["eventSignature"] = outcome.eventSignature
                record["normalisedEventSignature"] = engineNormalised
                record["repeatIsIdentical"] = deterministic
                record["replayEventSignature"] = replayNormalised
                record["replayPocketedBalls"] = prediction.pocketedBalls.sorted()
                record["replayPocketIDs"] = replayPockets
                record["replayCuePocketed"] = prediction.cuePocketed
                record["replayTermination"] = String(describing: prediction.termination)
                record["expectedPocketIDs"] = expectedPockets
                record["replayMatchesEngine"] = ballsMatch && !prediction.cuePocketed
                    && replayNormalised == engineNormalised && pocketsMatch
                record["simulationsUsed"] = simulations
                record["ballPositions"] = ballXZ
                winner = record
                break
            }
        }

        // Kept wide because this list is also the resume input for the next run: a handful of the
        // very best routes would collapse the archive's diversity on every restart.
        let ranked = archive.sorted { $0.value.cost < $1.value.cost }.prefix(250)
        var topRoutes: [[String: Any]] = []
        for (routeKey, entry) in ranked {
            topRoutes.append(["route": routeKey, "cost": entry.cost, "pots": entry.pots,
                              "parameters": entry.q])
        }
        // Best clean route on the archive, which is the number the report quotes: the overall best
        // cost can belong to a route with violations, and calling that "n balls potted" would
        // overstate the result.
        var bestClean = 0
        var bestCleanRoute: [String: Any] = [:]
        for (routeKey, entry) in archive where routeKey.hasSuffix("|clean") {
            if entry.pots > bestClean {
                bestClean = entry.pots
                bestCleanRoute = ["route": routeKey, "cost": entry.cost, "parameters": entry.q]
            }
        }
        var summary: [String: Any] = [:]
        summary["rung"] = rung
        summary["distanceMetres"] = d
        summary["omitBall"] = omittedBall ?? 0
        summary["targetBalls"] = numbers
        summary["cueSpeedCap"] = cueSpeedCap
        summary["seedCandidates"] = seeds.count
        summary["eliteFraction"] = eliteFraction
        summary["resumedRoutes"] = resumed
        summary["resumeSource"] = env("SIX_V5_RESUME") ?? ""
        summary["simulations"] = simulations
        summary["iterations"] = iterations
        summary["secondsSpent"] = Date().timeIntervalSince(started)
        summary["archiveRoutes"] = archive.count
        summary["solutionFound"] = winner != nil
        summary["bestPotCountAnyViolations"] = archive.values.map(\.pots).max() ?? 0
        summary["bestCleanPotCount"] = bestClean
        summary["bestCleanRoute"] = bestCleanRoute
        summary["bestParameters"] = bestOverall?.q ?? []
        summary["bestPotted"] = bestOverall?.outcome.pottedCorrectly.sorted() ?? []
        summary["bestRejections"] = bestOverall?.outcome.rejections ?? []
        summary["bestEventSignature"] = bestOverall?.outcome.eventSignature ?? []
        summary["topRoutes"] = topRoutes
        summary["note"] = "cost only steers the search; success is asserted from engine events "
            + "plus a ShotPredictor.simulateFree replay"
        try write(summary, "population-summary.json", to: out)
        if let winner {
            try write(winner, "best.json", to: out)
        }
        XCTAssertGreaterThan(simulations, 0, "population search ran no simulations")
    }

    /// Deterministic restart point: a widening jitter of the best parameters. The generator is a
    /// fixed LCG so a rerun of the same candidate explores the same points.
    private func jitter(_ q: [Float], seed: inout UInt64, scale: Float) -> [Float] {
        let spread: [Float] = [0.05, 0.05, 0.05, 0.5, 0.2, 0.2]
        var out = q
        for i in out.indices {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let unit = Float(seed >> 40) / Float(1 << 24) * 2 - 1     // −1 … 1
            out[i] += unit * spread[i] * min(4, scale)
        }
        return out
    }

    /// Gauss-Jordan solve of a small symmetric system; nil when it is singular.
    private func solve(_ a: [[Float]], _ b: [Float]) -> [Float]? {
        var m = a, v = b
        let n = v.count
        for col in 0..<n {
            var pivot = col
            for row in (col + 1)..<n where abs(m[row][col]) > abs(m[pivot][col]) { pivot = row }
            if abs(m[pivot][col]) < 1e-12 { return nil }
            m.swapAt(col, pivot); v.swapAt(col, pivot)
            let head = m[col][col]
            for k in col..<n { m[col][k] /= head }
            v[col] /= head
            for row in 0..<n where row != col {
                let factor = m[row][col]
                guard factor != 0 else { continue }
                for k in col..<n { m[row][k] -= factor * m[col][k] }
                v[row] -= factor * v[col]
            }
        }
        return v
    }

    // MARK: - Artefacts for a saved solution

    /// Dumps everything a solution has to be judged on: the engine's resolved events with their
    /// times, every ball's trajectory, a repeat-run consistency check, and a schematic PNG. The
    /// engine is run twice here (once directly, once through `ShotPredictor.simulateFree`) and
    /// both runs are compared, so the artefacts cannot silently come from a different shot.
    func testSolutionArtifacts() throws {
        let out = try output()
        guard let path = env("SIX_V4_BEST_JSON"), FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("no best.json to document")
        }
        let saved = try XCTUnwrap(try JSONSerialization.jsonObject(
            with: try Data(contentsOf: URL(fileURLWithPath: path))) as? [String: Any])
        let q = try XCTUnwrap((saved["bestParameters"] as? [NSNumber])?.map { $0.floatValue })
        let d = try XCTUnwrap((saved["distanceMetres"] as? NSNumber)?.floatValue)
        applyOmission((saved["omitBall"] as? NSNumber).map { $0.intValue }.flatMap { $0 == 0 ? nil : $0 })
        let places = positions(d)

        func run() -> (EventDrivenEngine, EventDrivenEngine.Termination) {
            let e = EventDrivenEngine(tableGeometry: geometry)
            let raw = SCNVector3(cosf(q[2]), 0, sinf(q[2]))
            let length = sqrtf(raw.x * raw.x + raw.z * raw.z)
            let strike = CueBallStrike.executeStrike(
                aimDirection: SCNVector3(raw.x / length, 0, raw.z / length),
                velocity: q[3], spinX: q[4], spinY: q[5])
            e.setBall(BallState(position: SCNVector3(q[0], y + BallPhysics.radius, q[1]),
                                velocity: strike.velocity, angularVelocity: strike.angularVelocity,
                                state: .sliding, name: cueName))
            for (i, p) in places.enumerated() {
                e.setBall(BallState(position: p, velocity: SCNVector3Zero,
                                    angularVelocity: SCNVector3Zero, state: .stationary,
                                    name: key(numbers[i])))
            }
            let termination = e.simulatePrediction(model: .appDefault, maxEvents: 4000, maxTime: 90,
                                                   highFidelityBounds: true)
            return (e, termination)
        }

        func describe(_ engine: EventDrivenEngine) -> [[String: Any]] {
            var rows: [[String: Any]] = []
            for (index, event) in engine.resolvedEvents.enumerated() {
                let time = index < engine.resolvedEventTimes.count ? engine.resolvedEventTimes[index] : -1
                switch event {
                case let .ballBall(a, b):
                    rows.append(["index": index, "time": time, "kind": "ballBall", "a": a, "b": b])
                case let .ballCushion(name, cushion, _):
                    let straight = cushion < 6
                    rows.append(["index": index, "time": time, "kind": "ballCushion", "ball": name,
                                 "cushionIndex": cushion,
                                 "segment": straight ? "straight rail" : "jaw/fillet/throat"])
                case let .pocket(name, pocket):
                    rows.append(["index": index, "time": time, "kind": "pocket", "ball": name,
                                 "pocket": pocket])
                case .transition:
                    continue
                }
            }
            return rows
        }

        let (first, terminationA) = run()
        let (second, terminationB) = run()
        let eventsA = describe(first), eventsB = describe(second)
        XCTAssertEqual(eventsA.count, eventsB.count, "two identical runs disagree on event count")
        XCTAssertEqual(String(describing: terminationA), String(describing: terminationB))
        let recorder = first.getTrajectoryRecorder()
        var paths: [String: [[Float]]] = [:]
        for (name, frames) in recorder.framesByBallName {
            paths[name] = frames.sorted { $0.time < $1.time }.map { [$0.position.x, $0.position.z] }
        }
        // Per-ball cushion bookkeeping the spec asks the report to state explicitly.
        var cushionsBeforePot: [String: [Int]] = [:]
        var cueCushions: [Int] = []
        var struck: Set<String> = []
        var dropped: Set<String> = []
        for event in first.resolvedEvents {
            switch event {
            case let .ballBall(a, b):
                if a != cueName { struck.insert(a) }
                if b != cueName { struck.insert(b) }
            case let .ballCushion(name, cushion, _):
                if name == cueName { cueCushions.append(cushion) }
                else if struck.contains(name), !dropped.contains(name) {
                    cushionsBeforePot[name, default: []].append(cushion)
                }
            case let .pocket(name, _):
                dropped.insert(name)
            case .transition:
                continue
            }
        }
        XCTAssertEqual(dropped, Set(numbers.map(key)), "documented run did not pot the saved target set")
        XCTAssertFalse(recorder.isBallPocketed(cueName))
        XCTAssertTrue(cueCushions.allSatisfy { !forbiddenCushionIndices().contains($0) },
                      "cue touched a forbidden cushion in the documented run")

        var payload: [String: Any] = [:]
        payload["bestJSON"] = path
        payload["omitBall"] = omittedBall ?? 0
        payload["targetBalls"] = numbers
        payload["distanceMetres"] = d
        payload["parameters"] = ["cueX": q[0], "cueZ": q[1], "aimRadians": q[2], "cueSpeed": q[3],
                                 "spinX": q[4], "spinY": q[5]]
        payload["termination"] = String(describing: terminationA)
        payload["resolvedEvents"] = eventsA
        payload["repeatRunIdentical"] = NSDictionary(dictionary: ["events": eventsA]) ==
            NSDictionary(dictionary: ["events": eventsB])
        payload["cueCushionSequence"] = cueCushions
        payload["targetCushionsBeforePot"] = cushionsBeforePot
        payload["ballPositions"] = Dictionary(uniqueKeysWithValues: numbers.enumerated().map {
            (key($0.element), [places[$0.offset].x, places[$0.offset].z]) })
        payload["cueStartXZ"] = [q[0], q[1]]
        try write(payload, "solution-events.json", to: out)
        try write(paths, "solution-trajectories.json", to: out)

        // Schematic: table outline, pockets, the emptied pocket marked, ball spots and the cue
        // path. A drawing, not a frame of the finished video.
        let scale: CGFloat = 320
        let halfLength = CGFloat(TablePhysics.innerLength / 2), halfWidth = CGFloat(TablePhysics.innerWidth / 2)
        let margin: CGFloat = 40
        let size = CGSize(width: (halfWidth * 2) * scale + margin * 2,
                          height: (halfLength * 2) * scale + margin * 2)
        func point(_ x: Float, _ z: Float) -> CGPoint {
            CGPoint(x: margin + (CGFloat(z) + halfWidth) * scale,
                    y: margin + (halfLength - CGFloat(x)) * scale)
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            cg.setFillColor(UIColor(red: 0.05, green: 0.28, blue: 0.22, alpha: 1).cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            cg.setStrokeColor(UIColor.white.cgColor)
            cg.setLineWidth(2)
            cg.stroke(CGRect(x: margin, y: margin, width: halfWidth * 2 * scale,
                             height: halfLength * 2 * scale))
            for pocket in geometry.pockets {
                let centre = point(pocket.center.x, pocket.center.z)
                let radius = CGFloat(pocket.radius) * scale
                let owned = numbers.contains { pocketID($0) == pocket.id }
                cg.setFillColor(owned ? UIColor.black.cgColor : UIColor.red.withAlphaComponent(0.55).cgColor)
                cg.fillEllipse(in: CGRect(x: centre.x - radius, y: centre.y - radius,
                                          width: radius * 2, height: radius * 2))
            }
            if let cuePath = recorder.framesByBallName[cueName]?.sorted(by: { $0.time < $1.time }),
               cuePath.count > 1 {
                cg.setStrokeColor(UIColor.white.withAlphaComponent(0.9).cgColor)
                cg.setLineWidth(2)
                cg.beginPath()
                cg.move(to: point(cuePath[0].position.x, cuePath[0].position.z))
                for frame in cuePath.dropFirst() {
                    cg.addLine(to: point(frame.position.x, frame.position.z))
                }
                cg.strokePath()
            }
            for ball in numbers {
                guard let frames = recorder.framesByBallName[key(ball)]?.sorted(by: { $0.time < $1.time }),
                      frames.count > 1 else { continue }
                cg.setStrokeColor(UIColor.yellow.withAlphaComponent(0.85).cgColor)
                cg.setLineWidth(1.5)
                cg.beginPath()
                cg.move(to: point(frames[0].position.x, frames[0].position.z))
                for frame in frames.dropFirst() {
                    cg.addLine(to: point(frame.position.x, frame.position.z))
                }
                cg.strokePath()
            }
            let radius = CGFloat(BallPhysics.radius) * scale
            for (i, place) in places.enumerated() {
                let centre = point(place.x, place.z)
                cg.setFillColor(UIColor.white.cgColor)
                cg.fillEllipse(in: CGRect(x: centre.x - radius, y: centre.y - radius,
                                          width: radius * 2, height: radius * 2))
                let label = "\(numbers[i])" as NSString
                label.draw(at: CGPoint(x: centre.x - 5, y: centre.y - 8),
                           withAttributes: [.font: UIFont.boldSystemFont(ofSize: 13),
                                            .foregroundColor: UIColor.black])
            }
            let cue = point(q[0], q[1])
            cg.setFillColor(UIColor.cyan.cgColor)
            cg.fillEllipse(in: CGRect(x: cue.x - radius, y: cue.y - radius,
                                      width: radius * 2, height: radius * 2))
        }
        try XCTUnwrap(image.pngData()).write(to: out.appendingPathComponent("solution-schematic.png"),
                                             options: .atomic)
    }

    /// Independent replay of a saved `best.json` through the production entry point.
    func testProductionReplay() throws {
        _ = try output()
        guard let path = env("SIX_V4_BEST_JSON"), FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("no best.json to replay")
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let saved = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let q = try XCTUnwrap((saved["bestParameters"] as? [NSNumber])?.map { $0.floatValue })
        let d = try XCTUnwrap((saved["distanceMetres"] as? NSNumber)?.floatValue)
        applyOmission((saved["omitBall"] as? NSNumber).map { $0.intValue }.flatMap { $0 == 0 ? nil : $0 })
        let prediction = ShotPredictor.simulateFree(
            cueBall: SCNVector3(q[0], y + BallPhysics.radius, q[1]),
            aimDir: SCNVector3(cosf(q[2]), 0, sinf(q[2])), velocity: q[3], spinX: q[4], spinY: q[5],
            surfaceY: y, balls: positions(d).enumerated().map {
                ObstacleBall(name: key(numbers[$0.offset]), position: $0.element) },
            maxEvents: 4000, maxTime: 90, includePresentation: true)
        XCTAssertEqual(Set(prediction.pocketedBalls), Set(numbers.map(key)))
        XCTAssertFalse(prediction.cuePocketed)
        XCTAssertEqual(String(describing: prediction.termination), "Optional(QiuJi.EventDrivenEngine.Termination.settled)")
        var replayPockets: [String: String] = [:]
        for entry in prediction.recorder?.pocketEntries ?? [] {
            replayPockets[entry.ball.name] = entry.pocketID
        }
        for ball in numbers {
            XCTAssertEqual(replayPockets[key(ball)], pocketID(ball), "ball \(ball) fell into the wrong pocket")
        }
        if let expected = saved["normalisedEventSignature"] as? [String] {
            XCTAssertEqual(normalisedSignature(of: prediction.events), expected,
                           "production replay produced a different event sequence")
        }
        try write(["bestJSON": path, "omitBall": omittedBall ?? 0, "targetBalls": numbers,
                   "replayPocketedBalls": prediction.pocketedBalls.sorted(),
                   "replayPocketIDs": replayPockets,
                   "replayCuePocketed": prediction.cuePocketed,
                   "replayTermination": String(describing: prediction.termination),
                   "replayEventSignature": normalisedSignature(of: prediction.events)],
                  "production-replay.json", to: try output())
    }
}
