import XCTest
import SceneKit
@testable import QiuJi

/// v4 phase 0 atomic probes. Read-only calls into the production engine: the three
/// transfer functions (pot map, single-collision response, free run + cushion) are
/// measured here so phases 1–2 can plan on measurements instead of guesses.
/// Opt-in: without `SIX_V4_DIR` every test skips.
final class SixPocketV4ProbeTests: XCTestCase {
    // MARK: - Coordinate and layout contract
    // SceneKit world: XZ horizontal, Y up, metres. Portrait screen up = +X, right = +Z.
    // Six targets sit on their pocket's inward centre line (corner 45°, side normal to
    // the long rail) at one shared distance d from the physical drop-hole centre.
    private let y: Float = 0.8
    private let numbers = [1, 2, 3, 4, 5, 8]
    /// Same mapping as `SixPocketSearchTests`: ball 1→pocket_1, 2→3, 3→5, 4→2, 5→0, 8→4.
    private let pocketIndices = [1, 3, 5, 2, 0, 4]
    private var geometry: TableGeometry { .chineseEightBallQiuJi(surfaceY: y) }
    private var cueName: String { ShotInput.cueBallName }

    /// v4 §4: d = corner hole radius + ball radius + g, g ∈ {0, ½D, D, 1½D, 2D}.
    private var gapFactors: [Float] { [0, 0.5, 1, 1.5, 2] }
    private var distances: [Float] {
        gapFactors.map { TablePhysics.cornerPocketRadius + BallPhysics.radius + $0 * BallPhysics.diameter }
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

    // MARK: - Harness

    private func env(_ key: String) -> String? {
        ProcessInfo.processInfo.environment[key] ?? ProcessInfo.processInfo.environment["TEST_RUNNER_" + key]
    }
    private func output() throws -> URL {
        guard let path = env("SIX_V4_DIR") else { throw XCTSkip("Opt-in v4 phase-0 probe") }
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func write(_ value: Any, _ name: String, to out: URL) throws {
        try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
            .write(to: out.appendingPathComponent(name), options: .atomic)
    }
    private func writeText(_ text: String, _ name: String, to out: URL) throws {
        try text.data(using: .utf8)!.write(to: out.appendingPathComponent(name), options: .atomic)
    }
    private func sourceDigest() -> Any {
        guard let path = env("SIX_V4_SOURCE_SHA256"), let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            return "not supplied"
        }
        return text.split(separator: "\n").map(String.init)
    }
    private func settings(_ extra: [String: Any]) -> [String: Any] {
        var base: [String: Any] = [
            "spec": "SIX-POCKET-ONE-SHOT-20260917 problem restatement v4",
            "units": "metres; SceneKit XZ horizontal, Y up; portrait up=+X right=+Z",
            "ballRadius": BallPhysics.radius, "ballDiameter": BallPhysics.diameter,
            "cornerHoleRadius": TablePhysics.cornerPocketRadius,
            "sideHoleRadius": TablePhysics.sidePocketRadius,
            "cueSpeedCapMetresPerSecond": 8.0,
            "appVelocityRange": [ShotTuning.velocityRange.lowerBound, ShotTuning.velocityRange.upperBound],
            "miscueLimitFraction": CuePhysics.miscueLimitFraction,
            "distanceLadderGapFactorsOfBallDiameter": gapFactors,
            "distanceLadderMetres": distances,
            "simulationModel": "EventDrivenEngine.SimulationModel.appDefault (planarReference)",
            "sourceSha256": sourceDigest()
        ]
        for (k, v) in extra { base[k] = v }
        return base
    }

    private func distance(_ a: SCNVector3, _ b: SCNVector3) -> Float { hypotf(a.x - b.x, a.z - b.z) }
    private func segmentDistance(_ p: SCNVector3, _ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dx = b.x - a.x, dz = b.z - a.z, l = dx * dx + dz * dz
        let t = l > 0 ? max(0, min(1, ((p.x - a.x) * dx + (p.z - a.z) * dz) / l)) : 0
        return hypotf(p.x - a.x - t * dx, p.z - a.z - t * dz)
    }
    /// Distance from a point to the nearest cushion surface (same measure as the v3 harness).
    private func clearance(_ p: SCNVector3) -> Float {
        let g = geometry
        var result = Float.infinity
        for s in g.linearCushions { result = min(result, segmentDistance(p, s.start, s.end)) }
        for s in g.circularCushions {
            let a = atan2f(p.z - s.center.z, p.x - s.center.x)
            if s.isAngleInRange(a) { result = min(result, abs(distance(p, s.center) - s.radius)) }
            for t in [s.startAngle, s.endAngle] {
                result = min(result, distance(p, SCNVector3(s.center.x + s.radius * cosf(t), y,
                                                            s.center.z + s.radius * sinf(t))))
            }
        }
        return result
    }

    private func ball(_ name: String, at p: SCNVector3, velocity: SCNVector3 = SCNVector3Zero,
                      spin: SCNVector3 = SCNVector3Zero, state: BallMotionState = .stationary) -> BallState {
        BallState(position: p, velocity: velocity, angularVelocity: spin, state: state, name: name)
    }
    private func cushionEvents(_ e: EventDrivenEngine, ball: String) -> [Int] {
        e.resolvedEvents.compactMap { event in
            if case let .ballCushion(name, index, _) = event, name == ball { return index }
            return nil
        }
    }
    /// Index of the first resolved event of a given kind, or nil.
    private func firstEventIndex(_ e: EventDrivenEngine, where match: (PhysicsEventType) -> Bool) -> Int? {
        e.resolvedEvents.firstIndex(where: match)
    }

    // MARK: - Cushion index map (basis for the "cue must only touch straight rails" gate)

    /// The v4 3a gate needs to name which cushion indices are jaw lines, jaw fillet arcs and
    /// side-pocket throat walls. `TableGeometry` builds them in a fixed order, so the index
    /// classification is derived here from the geometry itself and written out as evidence.
    func testCushionIndexMap() throws {
        let out = try output()
        let g = geometry
        let halfLength = TablePhysics.innerLength / 2, halfWidth = TablePhysics.innerWidth / 2
        var rows: [[String: Any]] = []
        var straight: [Int] = []
        for (i, s) in g.linearCushions.enumerated() {
            let onLongRail = abs(abs(s.start.z) - halfWidth) < 1e-4 && abs(abs(s.end.z) - halfWidth) < 1e-4
                && abs(s.normal.x) < 1e-4
            let onShortRail = abs(abs(s.start.x) - halfLength) < 1e-4 && abs(abs(s.end.x) - halfLength) < 1e-4
                && abs(s.normal.z) < 1e-4
            let isStraightRail = onLongRail || onShortRail
            if isStraightRail { straight.append(i) }
            rows.append(["kind": "linear", "index": i, "straightRail": isStraightRail,
                         "start": [s.start.x, s.start.z], "end": [s.end.x, s.end.z],
                         "normal": [s.normal.x, s.normal.z],
                         "restitutionOverride": s.restitution.map { Double($0) } ?? -1])
        }
        for (i, s) in g.circularCushions.enumerated() {
            rows.append(["kind": "circular", "index": g.linearCushions.count + i, "arcIndex": i,
                         "straightRail": false, "center": [s.center.x, s.center.z], "radius": s.radius,
                         "startAngleDegrees": s.startAngle * 180 / .pi,
                         "endAngleDegrees": s.endAngle * 180 / .pi,
                         "restitutionOverride": s.restitution.map { Double($0) } ?? -1])
        }
        // Six straight rails: two segments per long rail (split by the side pockets) plus one per short rail.
        XCTAssertEqual(straight, [0, 1, 2, 3, 4, 5])
        XCTAssertEqual(g.linearCushions.count, 44)
        XCTAssertEqual(g.circularCushions.count, 12)
        try write(["segments": rows, "straightRailLinearIndices": straight,
                   "cueForbiddenLinearIndices": Array(6..<g.linearCushions.count),
                   "cueForbiddenCircularIndices": Array(0..<g.circularCushions.count),
                   "note": "v4 3a: cue may only touch the six straight rails. Every other segment is a corner jaw line, a corner jaw fillet arc, a corner throat/back wall, a side-pocket fillet arc or a side-pocket throat/back wall."],
                  "cushion-index-map.json", to: out)
        try write(settings(["probe": "cushion-index-map"]), "experiment-settings.json", to: out)
    }

    // MARK: - Probe A: five-rung fixture check

    func testDistanceLadderFixture() throws {
        let out = try output().appendingPathComponent("fixture-ladder")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let g = geometry
        var rows: [[String: Any]] = []
        var accepted = 0
        for (k, d) in distances.enumerated() {
            let ps = positions(d)
            var reasons: [String] = []
            var balls: [[String: Any]] = []
            for (i, p) in ps.enumerated() {
                let pocket = g.pockets[pocketIndices[i]]
                let margin = clearance(p) - BallPhysics.radius
                let holeGap = distance(p, pocket.center) - pocket.radius
                if margin <= 0 { reasons.append("ball \(numbers[i]) surface inside cushion (margin \(margin) m)") }
                if holeGap <= 0 { reasons.append("ball \(numbers[i]) centre inside capture circle") }
                if abs(distance(p, pocket.center) - d) > 1e-6 { reasons.append("ball \(numbers[i]) distance error") }
                for j in ps.indices where j != i {
                    if distance(p, ps[j]) <= 2 * BallPhysics.radius { reasons.append("balls \(numbers[i])/\(numbers[j]) overlap") }
                }
                balls.append(["ball": numbers[i], "pocket": pocket.id, "xz": [p.x, p.z],
                              "cushionSurfaceMarginMetres": margin, "captureCircleGapMetres": holeGap,
                              "distanceToHoleCentreMetres": distance(p, pocket.center)])
            }
            // Static rest: nothing may creep or self-pot in 30 s.
            var maximumDrift: Float = 0
            var settled = false, potted = 0
            if reasons.isEmpty {
                let e = EventDrivenEngine(tableGeometry: g)
                for (i, p) in ps.enumerated() { e.setBall(ball("_\(numbers[i])", at: p)) }
                settled = e.simulatePrediction(model: .appDefault, maxTime: 30, highFidelityBounds: true) == .settled
                potted = e.getTrajectoryRecorder().pocketEntries.count
                for (i, p) in ps.enumerated() {
                    maximumDrift = max(maximumDrift, distance(try XCTUnwrap(e.getBall("_\(numbers[i])")).position, p))
                }
                if !settled { reasons.append("30 s static simulation did not settle") }
                if potted > 0 { reasons.append("\(potted) ball(s) self-potted while stationary") }
                if maximumDrift >= 1e-7 { reasons.append("static drift \(maximumDrift) m") }
            }
            let spread = ps.enumerated().map { abs(distance($0.element, g.pockets[pocketIndices[$0.offset]].center) - d) }.max() ?? 0
            if spread >= 1e-6 { reasons.append("shared-distance spread \(spread) m ≥ 1 µm") }
            let valid = reasons.isEmpty
            if valid { accepted += 1 }
            rows.append(["rung": k, "gapFactorOfBallDiameter": gapFactors[k], "distanceMetres": d,
                         "edgeGapToHoleRimMetres": gapFactors[k] * BallPhysics.diameter,
                         "valid": valid, "rejectionReasons": reasons, "staticSettled": settled,
                         "staticPotted": potted, "maximumStaticDriftMetres": maximumDrift,
                         "sharedDistanceSpreadMetres": spread, "balls": balls])
            print("V4 FIXTURE rung=\(k) d=\(d) valid=\(valid) reasons=\(reasons)")
        }
        try write(rows, "fixture-ladder.json", to: out)
        try write(settings(["probe": "fixture-ladder", "acceptedRungs": accepted]), "experiment-settings.json", to: out)
        XCTAssertEqual(rows.count, 5)
        XCTAssertGreaterThan(accepted, 0)
    }

    // MARK: - Probe B: pot map P_i(phi, v)

    private struct PotSample {
        var code: Character
        var pocket: String
        var cushionsBeforePocket: Int
        /// Cushion segment indices the ball touched before dropping, in order. v4.1 (spec §3b)
        /// allows jaw/arc/throat contact on the way in, so the *count* and *which segments* are
        /// what the planner needs; round 1 only recorded "any cushion yes/no".
        var cushionIndicesBeforePocket: [Int]
        var settled: Bool
    }

    /// One isolated launch of one target ball. `phi` is the offset from the ball→hole-centre
    /// direction; the ball starts sliding with no spin, matching a freshly struck object ball.
    private func launchTarget(_ name: String, from p: SCNVector3, direction: Float, speed: Float,
                              ownPocket: String) -> PotSample {
        let e = EventDrivenEngine(tableGeometry: geometry)
        e.setBall(ball(name, at: p, velocity: SCNVector3(speed * cosf(direction), 0, speed * sinf(direction)),
                       state: .sliding))
        var term = e.simulatePrediction(model: .appDefault, maxEvents: 400, maxTime: 30, highFidelityBounds: true)
        term = e.completePlanarSpinTail(after: term, surfaceY: y)
        let settled = term == .settled
        let potIndex = firstEventIndex(e) { if case let .pocket(b, _) = $0 { return b == name }; return false }
        guard let potIndex else {
            let all = cushionEvents(e, ball: name)
            return PotSample(code: ".", pocket: "", cushionsBeforePocket: all.count,
                             cushionIndicesBeforePocket: all, settled: settled)
        }
        var pocketID = ""
        if case let .pocket(_, id) = e.resolvedEvents[potIndex] { pocketID = id }
        let indicesBefore: [Int] = e.resolvedEvents.prefix(potIndex).compactMap {
            if case let .ballCushion(b, index, _) = $0, b == name { return index }
            return nil
        }
        let cushionsBefore = indicesBefore.count
        if pocketID != ownPocket {
            return PotSample(code: "W", pocket: pocketID, cushionsBeforePocket: cushionsBefore,
                             cushionIndicesBeforePocket: indicesBefore, settled: settled)
        }
        // v4.1 grid alphabet: 'O' = clean (0 cushions, the old 3a window), '1'/'2' = own pocket
        // after 1/2 cushions (accepted by 3b), 'x' = own pocket after 3 or more (rejected).
        let code: Character = cushionsBefore == 0 ? "O" : (cushionsBefore <= 2 ? Character("\(cushionsBefore)") : "x")
        return PotSample(code: code, pocket: pocketID,
                         cushionsBeforePocket: cushionsBefore,
                         cushionIndicesBeforePocket: indicesBefore, settled: settled)
    }

    func testPotMap() throws {
        let out = try output().appendingPathComponent("pot-map")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let g = geometry
        let phiStep = Float(env("SIX_V4_PHI_STEP_DEGREES").flatMap(Double.init) ?? 1)
        let phiLimit = Float(env("SIX_V4_PHI_LIMIT_DEGREES").flatMap(Double.init) ?? 45)
        let speedStep = Float(env("SIX_V4_SPEED_STEP").flatMap(Double.init) ?? 0.25)
        let speedMax = Float(env("SIX_V4_SPEED_MAX").flatMap(Double.init) ?? 6)
        let phis = Array(stride(from: -phiLimit, through: phiLimit, by: phiStep))
        let speeds = Array(stride(from: speedStep, through: speedMax, by: speedStep))
        let started = Date()
        var simulations = 0
        var summary: [[String: Any]] = []
        for (k, d) in distances.enumerated() {
            let ps = positions(d)
            var ladderRows: [[String: Any]] = []
            for (i, p) in ps.enumerated() {
                let pocket = g.pockets[pocketIndices[i]]
                let base = atan2f(pocket.center.z - p.z, pocket.center.x - p.x)
                // Pure-geometry corridor reference: half-angle whose chord clears the hole rim.
                let corridorHalfAngle = asinf(min(1, max(-1, (pocket.radius - BallPhysics.radius) / d))) * 180 / .pi
                var grid: [String] = []
                var intervals: [[String: Any]] = []
                var cleanSamples = 0
                var v41Samples = 0
                var v41CushionIndices: Set<Int> = []
                var v41StraightRailSamples = 0
                var v41CountHistogram = [0, 0, 0]
                for v in speeds {
                    var line = ""
                    var runs: [[Float]] = []
                    var runStart: Float?
                    var v41Runs: [[Float]] = []
                    var v41Start: Float?
                    for phi in phis {
                        let sample = launchTarget("_\(numbers[i])", from: p,
                                                  direction: base + phi * .pi / 180, speed: v,
                                                  ownPocket: pocket.id)
                        simulations += 1
                        line.append(sample.code)
                        if sample.code == "O" {
                            cleanSamples += 1
                            if runStart == nil { runStart = phi }
                        } else if let s = runStart {
                            runs.append([s, phi - phiStep]); runStart = nil
                        }
                        // v4.1 §3b: own pocket, at most two of the ball's own cushion events first.
                        let v41 = sample.code == "O" || sample.code == "1" || sample.code == "2"
                        if v41 {
                            v41Samples += 1
                            v41CountHistogram[sample.cushionsBeforePocket] += 1
                            v41CushionIndices.formUnion(sample.cushionIndicesBeforePocket)
                            // Straight rails are linear segments 0–5; anything else is jaw / throat
                            // / back wall / arc, i.e. the segments the *cue* may never touch.
                            if sample.cushionIndicesBeforePocket.contains(where: { $0 <= 5 }) {
                                v41StraightRailSamples += 1
                            }
                            if v41Start == nil { v41Start = phi }
                        } else if let s = v41Start {
                            v41Runs.append([s, phi - phiStep]); v41Start = nil
                        }
                    }
                    if let s = runStart { runs.append([s, phis.last ?? s]) }
                    if let s = v41Start { v41Runs.append([s, phis.last ?? s]) }
                    grid.append(line)
                    intervals.append(["speed": v, "cleanIntervalsDegrees": runs,
                                      "cleanWidthDegrees": runs.reduce(Float(0)) { $0 + ($1[1] - $1[0] + phiStep) },
                                      "v41IntervalsDegrees": v41Runs,
                                      "v41WidthDegrees": v41Runs.reduce(Float(0)) { $0 + ($1[1] - $1[0] + phiStep) }])
                }
                ladderRows.append(["ball": numbers[i], "pocket": pocket.id, "isCorner": pocket.isCorner,
                                   "xz": [p.x, p.z], "baseDirectionRadians": base,
                                   "geometricCorridorHalfAngleDegrees": corridorHalfAngle,
                                   "cleanSamples": cleanSamples, "grid": grid,
                                   "cleanAcceptanceBySpeed": intervals,
                                   "v41Samples": v41Samples,
                                   "v41CushionCountHistogram": v41CountHistogram,
                                   "v41CushionIndicesTouched": v41CushionIndices.sorted(),
                                   "v41SamplesTouchingStraightRail": v41StraightRailSamples])
                var art = "d rung \(k)  d=\(d) m  ball \(numbers[i]) → \(pocket.id)\n"
                art += "legend O clean own pocket / 1,2 own pocket after 1,2 cushions (v4.1 ok) / x own pocket after 3+ / W wrong pocket / . no pot\n"
                art += "rows: speed \(speeds.first!)…\(speeds.last!) step \(speedStep); cols: phi \(-phiLimit)…\(phiLimit) step \(phiStep)\n"
                for (r, line) in grid.enumerated() {
                    art += String(format: "%5.2f |%@|\n", speeds[r], line)
                }
                try writeText(art, String(format: "potmap-rung%d-ball%d.txt", k, numbers[i]), to: out)
                print("V4 POTMAP rung=\(k) ball=\(numbers[i]) clean=\(cleanSamples) v41=\(v41Samples)/\(phis.count * speeds.count) elapsed=\(Date().timeIntervalSince(started))")
            }
            try write(["rung": k, "distanceMetres": d, "phiDegrees": phis, "speeds": speeds,
                       "balls": ladderRows], String(format: "pot-map-rung%d.json", k), to: out)
            summary.append(["rung": k, "distanceMetres": d,
                            "totalCleanSamples": ladderRows.reduce(0) { $0 + ($1["cleanSamples"] as? Int ?? 0) },
                            "perBallCleanSamples": ladderRows.map { $0["cleanSamples"] as? Int ?? 0 },
                            "totalV41Samples": ladderRows.reduce(0) { $0 + ($1["v41Samples"] as? Int ?? 0) },
                            "perBallV41Samples": ladderRows.map { $0["v41Samples"] as? Int ?? 0 }])
        }
        try write(summary, "pot-map-summary.json", to: out)
        try write(settings(["probe": "pot-map",
                            "v41Criterion": "own pocket AND at most 2 ballCushion events by that ball before dropping (spec v4 §3b)",
                            "phiDegrees": phis, "speeds": speeds,
                            "simulations": simulations, "seconds": Date().timeIntervalSince(started)]),
                  "experiment-settings.json", to: out)
        XCTAssertEqual(summary.count, 5)
        XCTAssertGreaterThan(simulations, 0)
    }

    // MARK: - Probe C: single collision response R

    private struct SpinVariant { let label: String; let spinX: Float; let spinY: Float }
    /// spinX is pooltool `a` (side english, produces squirt); spinY is pooltool `b`
    /// (vertical, top/bottom). Verified against `CueBallStrike.strikeModel`.
    private var spinVariants: [SpinVariant] {
        let s: Float = 0.6 * CuePhysics.miscueLimitFraction   // 60 % of the miscue boundary
        return [SpinVariant(label: "centre", spinX: 0, spinY: 0),
                SpinVariant(label: "top(spinY+)", spinX: 0, spinY: s),
                SpinVariant(label: "bottom(spinY-)", spinX: 0, spinY: -s),
                SpinVariant(label: "side(spinX+)", spinX: s, spinY: 0),
                SpinVariant(label: "side(spinX-)", spinX: -s, spinY: 0)]
    }
    /// Aim direction that makes the post-squirt cue velocity point along `desired`.
    private func compensatedAim(_ desired: Float, spinX: Float, spinY: Float, speed: Float) -> SCNVector3 {
        let probe = CueBallStrike.executeStrike(aimDirection: SCNVector3(1, 0, 0), velocity: speed,
                                               spinX: spinX, spinY: spinY)
        let bias = atan2f(probe.velocity.z, probe.velocity.x)
        let a = desired - bias
        return SCNVector3(cosf(a), 0, sinf(a))
    }
    /// Cue-ball speed immediately after the strike. The cue tip speed is not the ball speed:
    /// the strike model gives the ball roughly 1.5× the tip speed for a heavier cue.
    private func launchSpeed(aim: SCNVector3, speed: Float, spinX: Float, spinY: Float) -> Float {
        let length = sqrtf(aim.x * aim.x + aim.z * aim.z)
        let strike = CueBallStrike.executeStrike(aimDirection: SCNVector3(aim.x / length, 0, aim.z / length),
                                                velocity: speed, spinX: spinX, spinY: spinY)
        return planarSpeed(strike.velocity)
    }
    private func setCue(_ e: EventDrivenEngine, at p: SCNVector3, aim: SCNVector3, speed: Float,
                        spinX: Float, spinY: Float) {
        let length = sqrtf(aim.x * aim.x + aim.z * aim.z)
        let strike = CueBallStrike.executeStrike(aimDirection: SCNVector3(aim.x / length, 0, aim.z / length),
                                                 velocity: speed, spinX: spinX, spinY: spinY)
        e.setBall(ball(cueName, at: p, velocity: strike.velocity, spin: strike.angularVelocity, state: .sliding))
    }
    /// Sentinel for an angle that has no definition (the ball came to rest); JSON rejects NaN.
    private let undefinedAngle: Float = -999
    private func planarSpeed(_ v: SCNVector3) -> Float { hypotf(v.x, v.z) }
    private func degrees(_ r: Float) -> Float { r * 180 / .pi }
    /// Signed angle from vector a to vector b in the XZ plane, in degrees.
    private func signedAngle(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        degrees(atan2f(a.x * b.z - a.z * b.x, a.x * b.x + a.z * b.z))
    }

    func testCollisionResponse() throws {
        let out = try output().appendingPathComponent("collision-response")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let target = SCNVector3(0, y + BallPhysics.radius, 0)
        let approach: Float = 0.45
        let radius = BallPhysics.radius
        let offsets = Array(stride(from: Float(-2), through: 2, by: 0.1)).map { $0 * radius }
        var rows: [[String: Any]] = []
        var simulations = 0
        let started = Date()
        for speed in [Float(2), 4, 6, 8] {
            for variant in spinVariants {
                for b0 in offsets {
                    // Cue starts `approach` upstream of the target along +X, offset b0 along +Z.
                    let start = SCNVector3(target.x - approach, y + BallPhysics.radius, target.z + b0)
                    let aim = compensatedAim(0, spinX: variant.spinX, spinY: variant.spinY, speed: speed)
                    let e = EventDrivenEngine(tableGeometry: geometry)
                    setCue(e, at: start, aim: aim, speed: speed, spinX: variant.spinX, spinY: variant.spinY)
                    e.setBall(ball("_probe", at: target))
                    let term = e.simulatePrediction(model: .appDefault, maxEvents: 200, maxTime: 4,
                                                    highFidelityBounds: true,
                                                    stopAfterContactBetween: (cueName, "_probe"))
                    simulations += 1
                    guard term == .contactResolved,
                          let contactIndex = firstEventIndex(e, where: { if case .ballBall = $0 { return true }; return false }),
                          contactIndex < e.resolvedEventTimes.count else {
                        rows.append(["cueSpeed": speed, "spin": variant.label, "nominalOffsetMetres": b0,
                                     "nominalOffsetInBallRadii": b0 / radius, "contacted": false,
                                     "termination": String(describing: term)])
                        continue
                    }
                    let contactTime = e.resolvedEventTimes[contactIndex]
                    let cueAfter = try XCTUnwrap(e.getBall(cueName))
                    let targetAfter = try XCTUnwrap(e.getBall("_probe"))
                    // Exact pre-contact state: rerun the identical launch alone, stopped just before contact.
                    let pre = EventDrivenEngine(tableGeometry: geometry)
                    setCue(pre, at: start, aim: aim, speed: speed, spinX: variant.spinX, spinY: variant.spinY)
                    _ = pre.simulatePrediction(model: .appDefault, maxEvents: 200,
                                               maxTime: max(0, contactTime - 1e-5), highFidelityBounds: true)
                    simulations += 1
                    let cueBefore = try XCTUnwrap(pre.getBall(cueName))
                    let inSpeed = planarSpeed(cueBefore.velocity)
                    guard inSpeed > 1e-4, cushionEvents(pre, ball: cueName).isEmpty else {
                        rows.append(["cueSpeed": speed, "spin": variant.label, "nominalOffsetMetres": b0,
                                     "contacted": false, "termination": "pre-contact probe unusable"])
                        continue
                    }
                    let inDir = SCNVector3(cueBefore.velocity.x / inSpeed, 0, cueBefore.velocity.z / inSpeed)
                    // Signed impact parameter: left-normal of travel, dotted onto (cue line − target).
                    let leftNormal = SCNVector3(-inDir.z, 0, inDir.x)
                    let bMeasured = leftNormal.x * (cueBefore.position.x - target.x)
                        + leftNormal.z * (cueBefore.position.z - target.z)
                    let lineLength = distance(cueAfter.position, targetAfter.position)
                    let centreLine = SCNVector3((targetAfter.position.x - cueAfter.position.x) / lineLength, 0,
                                                (targetAfter.position.z - cueAfter.position.z) / lineLength)
                    // Tangent branch aligned with the incoming direction, so a thin cut reads ≈0°
                    // deviation on both sides of the target instead of flipping to ±180°.
                    let rawTangent = SCNVector3(-centreLine.z, 0, centreLine.x)
                    let tangentSign: Float = (rawTangent.x * inDir.x + rawTangent.z * inDir.z) >= 0 ? 1 : -1
                    let tangent = SCNVector3(rawTangent.x * tangentSign, 0, rawTangent.z * tangentSign)
                    let cueOut = planarSpeed(cueAfter.velocity), targetOut = planarSpeed(targetAfter.velocity)
                    // Curvature over the next 0.3 s, cue alone from its post-contact state.
                    let tail = EventDrivenEngine(tableGeometry: geometry)
                    tail.setBall(BallState(position: cueAfter.position, velocity: cueAfter.velocity,
                                           angularVelocity: cueAfter.angularVelocity, state: cueAfter.state,
                                           name: cueName))
                    _ = tail.simulatePrediction(model: .appDefault, maxEvents: 60, maxTime: 0.3,
                                                highFidelityBounds: true)
                    simulations += 1
                    let tailBall = try XCTUnwrap(tail.getBall(cueName))
                    let tailSpeed = planarSpeed(tailBall.velocity)
                    rows.append([
                        "cueSpeed": speed, "spin": variant.label, "spinX": variant.spinX, "spinY": variant.spinY,
                        "nominalOffsetMetres": b0, "nominalOffsetInBallRadii": b0 / radius,
                        "contacted": true, "contactTime": contactTime,
                        "launchBallSpeed": launchSpeed(aim: aim, speed: speed, spinX: variant.spinX, spinY: variant.spinY),
                        "preContactPathLengthMetres": distance(start, cueBefore.position),
                        "measuredImpactParameterMetres": bMeasured,
                        "measuredImpactParameterInBallRadii": bMeasured / radius,
                        "incomingBallSpeed": inSpeed,
                        "incomingSpin": [cueBefore.angularVelocity.x, cueBefore.angularVelocity.y, cueBefore.angularVelocity.z],
                        "cutAngleDegrees": degrees(asinf(min(1, max(-1, bMeasured / (2 * radius))))),
                        "cueOutSpeed": cueOut, "cueSpeedRatio": cueOut / inSpeed,
                        "targetOutSpeed": targetOut, "targetSpeedRatio": targetOut / inSpeed,
                        "cueDeviationFromTangentDegrees": cueOut > 1e-5 ? signedAngle(tangent, cueAfter.velocity) : undefinedAngle,
                        "targetDeviationFromCentreLineDegrees": targetOut > 1e-5 ? signedAngle(centreLine, targetAfter.velocity) : undefinedAngle,
                        "cueSpinAfter": [cueAfter.angularVelocity.x, cueAfter.angularVelocity.y, cueAfter.angularVelocity.z],
                        "cueSpinMagnitudeBefore": magnitude(cueBefore.angularVelocity),
                        "cueSpinMagnitudeAfter": magnitude(cueAfter.angularVelocity),
                        "cueSpinChangeOverMagnitude": spinChangeRatio(cueBefore.angularVelocity, cueAfter.angularVelocity),
                        "targetSpinAfter": [targetAfter.angularVelocity.x, targetAfter.angularVelocity.y, targetAfter.angularVelocity.z],
                        "cueDeviationAfter0p3sDegrees": tailSpeed > 1e-5 ? signedAngle(tangent, tailBall.velocity) : undefinedAngle,
                        "cueSpeedAfter0p3s": tailSpeed,
                        "eventsWithin0p3s": tail.resolvedEvents.count])
                }
            }
        }
        try write(rows, "collision-response.json", to: out)
        // Aggregate check of the analysis document's two qualitative claims.
        let contacted = rows.filter { ($0["contacted"] as? Bool) == true }
        // Bin by |b|/R: grazing (|b|→2R) and near-full (|b|→0) hits are degenerate for the
        // tangent measure, so the working band is reported separately from the extremes.
        var bins: [[String: Any]] = []
        for (label, lo, hi) in [("full 0.0–0.3R", Float(0), Float(0.3)), ("working 0.3–1.7R", 0.3, 1.7),
                                ("grazing 1.7–2.0R", 1.7, 2.01)] {
            let band = contacted.filter {
                let b = abs(($0["measuredImpactParameterInBallRadii"] as? Float) ?? 9); return b >= lo && b < hi
            }
            let deviation = band.compactMap { $0["cueDeviationFromTangentDegrees"] as? Float }
                .filter { $0.isFinite && $0 != undefinedAngle }
            let spin = band.compactMap { $0["cueSpinChangeOverMagnitude"] as? Float }
            let cueRatio = band.compactMap { $0["cueSpeedRatio"] as? Float }
            let targetRatio = band.compactMap { $0["targetSpeedRatio"] as? Float }
            let throwOff = band.compactMap { $0["targetDeviationFromCentreLineDegrees"] as? Float }
                .filter { $0 != undefinedAngle }
            bins.append(["band": label, "samples": band.count,
                         "cueTangentDeviationDegrees": ["min": deviation.min() ?? -1, "max": deviation.max() ?? -1,
                                                        "median": median(deviation)],
                         "cueSpinChangeOverMagnitude": ["min": spin.min() ?? -1, "max": spin.max() ?? -1,
                                                        "median": median(spin)],
                         "cueSpeedRatio": ["min": cueRatio.min() ?? -1, "max": cueRatio.max() ?? -1,
                                           "median": median(cueRatio)],
                         "targetSpeedRatio": ["min": targetRatio.min() ?? -1, "max": targetRatio.max() ?? -1,
                                              "median": median(targetRatio)],
                         "targetThrowFromCentreLineDegrees": ["min": throwOff.min() ?? -1, "max": throwOff.max() ?? -1,
                                                              "median": median(throwOff)]])
        }
        // Per spin variant, restricted to the working band: does the spin label change separation?
        var bySpin: [[String: Any]] = []
        for variant in spinVariants {
            let band = contacted.filter {
                ($0["spin"] as? String) == variant.label
                    && abs(($0["measuredImpactParameterInBallRadii"] as? Float) ?? 9) >= 0.3
                    && abs(($0["measuredImpactParameterInBallRadii"] as? Float) ?? 9) < 1.7
            }
            let deviation = band.compactMap { $0["cueDeviationFromTangentDegrees"] as? Float }
                .filter { $0 != undefinedAngle }
            let tail = band.compactMap { $0["cueDeviationAfter0p3sDegrees"] as? Float }.filter { $0 != undefinedAngle }
            bySpin.append(["spin": variant.label, "samples": band.count,
                           "immediateDeviationDegreesMedian": median(deviation),
                           "immediateDeviationDegreesMin": deviation.min() ?? -1,
                           "immediateDeviationDegreesMax": deviation.max() ?? -1,
                           "deviationAfter0p3sDegreesMedian": median(tail),
                           "deviationAfter0p3sDegreesMin": tail.min() ?? -1,
                           "deviationAfter0p3sDegreesMax": tail.max() ?? -1])
        }
        try write(["contactedSamples": contacted.count, "totalSamples": rows.count,
                   "byImpactParameterBand": bins, "bySpinVariant": bySpin,
                   "undefinedAngleSentinel": undefinedAngle,
                   "claimUnderTest": "analysis §1.2 cue spin is essentially unchanged by the collision; §1.5 stun separation is along the tangent"],
                  "collision-response-summary.json", to: out)
        try write(settings(["probe": "collision-response", "approachDistanceMetres": approach,
                            "cueSpeeds": [2, 4, 6, 8], "impactParameterStepInBallRadii": 0.1,
                            "spinVariants": spinVariants.map { ["label": $0.label, "spinX": $0.spinX, "spinY": $0.spinY] },
                            "simulations": simulations, "seconds": Date().timeIntervalSince(started)]),
                  "experiment-settings.json", to: out)
        XCTAssertGreaterThan(contacted.count, 0)
    }

    private func magnitude(_ v: SCNVector3) -> Float { sqrtf(v.x * v.x + v.y * v.y + v.z * v.z) }
    /// |Δω| / |ω| across the collision. Component-wise ratios are useless here because the
    /// vertical component is ~0 before a centre strike.
    private func spinChangeRatio(_ before: SCNVector3, _ after: SCNVector3) -> Float {
        let d = SCNVector3(after.x - before.x, after.y - before.y, after.z - before.z)
        return magnitude(d) / max(magnitude(before), 1e-6)
    }
    private func median(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return -1 }
        let s = values.sorted()
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }

    // MARK: - Probe D: free run and straight-rail reflection F

    func testCushionReflection() throws {
        let out = try output().appendingPathComponent("cushion-reflection")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let g = geometry
        // Four straight rails; the long rails are split into two segments by the side pockets,
        // so aim at the segment whose interior is comfortably away from any pocket.
        let rails: [(label: String, index: Int)] = [("+Z long (x>0)", 1), ("-Z long (x>0)", 3),
                                                    ("-X short", 4), ("+X short", 5)]
        var rows: [[String: Any]] = []
        var simulations = 0
        let started = Date()
        for rail in rails {
            let segment = g.linearCushions[rail.index]
            let inward = SCNVector3(segment.normal.x, 0, segment.normal.z)   // stored normal points into the table
            let along = SCNVector3(segment.end.x - segment.start.x, 0, segment.end.z - segment.start.z)
            let alongLength = hypotf(along.x, along.z)
            let alongUnit = SCNVector3(along.x / alongLength, 0, along.z / alongLength)
            let mid = SCNVector3((segment.start.x + segment.end.x) / 2, y + BallPhysics.radius,
                                 (segment.start.z + segment.end.z) / 2)
            // Ball-centre contact line sits one radius inside the rail face.
            let impact = SCNVector3(mid.x + inward.x * BallPhysics.radius, y + BallPhysics.radius,
                                    mid.z + inward.z * BallPhysics.radius)
            for incidence in [Float(30), 45, 60] {
                // Travel direction: rotate the inbound normal (−inward) by the incidence angle
                // toward the rail's `along` direction.
                let a = incidence * .pi / 180
                let travel = SCNVector3(-inward.x * cosf(a) + alongUnit.x * sinf(a), 0,
                                        -inward.z * cosf(a) + alongUnit.z * sinf(a))
                var start: SCNVector3?
                for reach in [Float(0.9), 0.75, 0.6, 0.45, 0.35, 0.25] {
                    let candidate = SCNVector3(impact.x - travel.x * reach, y + BallPhysics.radius,
                                               impact.z - travel.z * reach)
                    let nearPocket = g.pockets.map { distance(candidate, $0.center) }.min() ?? 1
                    if clearance(candidate) > BallPhysics.radius + 0.01, nearPocket > 0.2 { start = candidate; break }
                }
                guard let start else {
                    rows.append(["rail": rail.label, "railIndex": rail.index,
                                 "incidenceFromNormalDegrees": incidence, "usable": false,
                                 "reason": "no valid launch point inside the table"])
                    continue
                }
                let desired = atan2f(travel.z, travel.x)
                for speed in [Float(2), 4, 6] {
                    for variant in spinVariants {
                        let aim = compensatedAim(desired, spinX: variant.spinX, spinY: variant.spinY, speed: speed)
                        let e = EventDrivenEngine(tableGeometry: geometry)
                        setCue(e, at: start, aim: aim, speed: speed, spinX: variant.spinX, spinY: variant.spinY)
                        _ = e.simulatePrediction(model: .appDefault, maxEvents: 200, maxTime: 6,
                                                 highFidelityBounds: true)
                        simulations += 1
                        guard let hitIndex = firstEventIndex(e, where: { if case .ballCushion = $0 { return true }; return false }),
                              hitIndex < e.resolvedEventTimes.count else {
                            rows.append(["rail": rail.label, "railIndex": rail.index,
                                         "incidenceFromNormalDegrees": incidence, "cueSpeed": speed,
                                         "spin": variant.label, "usable": false, "reason": "no cushion contact"])
                            continue
                        }
                        var hitCushion = -1
                        if case let .ballCushion(_, index, _) = e.resolvedEvents[hitIndex] { hitCushion = index }
                        let hitTime = e.resolvedEventTimes[hitIndex]
                        let frames = e.getTrajectoryRecorder().framesByBallName[cueName] ?? []
                        guard let post = frames.first(where: { $0.time >= hitTime - 1e-6 }) else {
                            rows.append(["rail": rail.label, "railIndex": rail.index,
                                         "incidenceFromNormalDegrees": incidence, "cueSpeed": speed,
                                         "spin": variant.label, "usable": false, "reason": "no post-contact frame"])
                            continue
                        }
                        // Exact pre-contact state: identical launch stopped just before the bounce.
                        let pre = EventDrivenEngine(tableGeometry: geometry)
                        setCue(pre, at: start, aim: aim, speed: speed, spinX: variant.spinX, spinY: variant.spinY)
                        _ = pre.simulatePrediction(model: .appDefault, maxEvents: 200,
                                                   maxTime: max(0, hitTime - 1e-5), highFidelityBounds: true)
                        simulations += 1
                        let before = try XCTUnwrap(pre.getBall(cueName))
                        let inSpeed = planarSpeed(before.velocity), outSpeed = planarSpeed(post.velocity)
                        guard inSpeed > 1e-4, outSpeed > 1e-6, cushionEvents(pre, ball: cueName).isEmpty else {
                            rows.append(["rail": rail.label, "railIndex": rail.index,
                                         "incidenceFromNormalDegrees": incidence, "cueSpeed": speed,
                                         "spin": variant.label, "usable": false, "reason": "pre-contact probe unusable"])
                            continue
                        }
                        // Mirror reflection of the measured inbound direction about the rail normal.
                        let dot = before.velocity.x * inward.x + before.velocity.z * inward.z
                        let mirror = SCNVector3(before.velocity.x - 2 * dot * inward.x, 0,
                                               before.velocity.z - 2 * dot * inward.z)
                        let actualIncidence = degrees(acosf(min(1, max(-1, -dot / inSpeed))))
                        rows.append(["rail": rail.label, "railIndex": rail.index, "hitCushionIndex": hitCushion,
                                     "hitIntendedRail": hitCushion == rail.index,
                                     "incidenceFromNormalDegrees": incidence,
                                     "measuredIncidenceFromNormalDegrees": actualIncidence,
                                     "cueSpeed": speed, "spin": variant.label,
                                     "spinX": variant.spinX, "spinY": variant.spinY,
                                     "launchXZ": [start.x, start.z], "usable": true,
                                     "launchBallSpeed": launchSpeed(aim: aim, speed: speed,
                                                                    spinX: variant.spinX, spinY: variant.spinY),
                                     "preContactPathLengthMetres": distance(start, before.position),
                                     "incomingBallSpeed": inSpeed, "outgoingBallSpeed": outSpeed,
                                     "speedRetention": outSpeed / inSpeed,
                                     "deviationFromMirrorDegrees": signedAngle(mirror, post.velocity),
                                     "incomingSpin": [before.angularVelocity.x, before.angularVelocity.y, before.angularVelocity.z],
                                     "outgoingSpin": [post.angularVelocity.x, post.angularVelocity.y, post.angularVelocity.z],
                                     "contactTime": hitTime])
                    }
                }
            }
        }
        try write(rows, "cushion-reflection.json", to: out)
        let usable = rows.filter { ($0["usable"] as? Bool) == true && ($0["hitIntendedRail"] as? Bool) == true }
        let retention = usable.compactMap { $0["speedRetention"] as? Float }
        let deviations = usable.compactMap { $0["deviationFromMirrorDegrees"] as? Float }
        try write(["usableSamples": usable.count, "totalSamples": rows.count,
                   "speedRetentionMin": retention.min() ?? -1, "speedRetentionMax": retention.max() ?? -1,
                   "speedRetentionMedian": median(retention),
                   "mirrorDeviationDegreesMin": deviations.min() ?? -1,
                   "mirrorDeviationDegreesMax": deviations.max() ?? -1,
                   "mirrorDeviationDegreesMedian": median(deviations),
                   "claimUnderTest": "analysis §1.6 ≈80 % normal-speed retention per cushion; §1.5 side english shifts the reflection angle with one sign"],
                  "cushion-reflection-summary.json", to: out)
        try write(settings(["probe": "cushion-reflection", "rails": rails.map { ["label": $0.label, "index": $0.index] },
                            "incidenceFromNormalDegrees": [30, 45, 60], "cueSpeeds": [2, 4, 6],
                            "spinVariants": spinVariants.map { ["label": $0.label, "spinX": $0.spinX, "spinY": $0.spinY] },
                            "simulations": simulations, "seconds": Date().timeIntervalSince(started)]),
                  "experiment-settings.json", to: out)
        XCTAssertGreaterThan(usable.count, 0)
    }

    // MARK: - Probe E: post-collision reach set

    /// Probe C reads the cue's departure 0.3 s after a collision; that window is far shorter than
    /// a chain segment, and its summary already shows the deviation growing from ≤10.9° at contact
    /// to a median 13.7° (top) / −8.3° (bottom) by 0.3 s. A chain planner that works with straight
    /// segments therefore needs the deviation of the **chord** from the contact point to the point
    /// the cue actually reaches, as a function of chord length — which is what this probe tabulates.
    ///
    /// Rig is Probe C's: target at table centre, cue arriving along +X with a signed offset. After
    /// the contact the cue is replayed alone from its post-contact state, sampled in time, and each
    /// sample contributes one (chord length, chord deviation from tangent, arrival speed) row.
    /// Spin is a continuous two-dimensional knob, and it is the only knob the chain has left once
    /// the ball positions and the potting directions are fixed, so the reach probe samples a grid
    /// rather than the five labelled variants used by probes C and D.
    private var reachSpinGrid: [SpinVariant] {
        let limit = CuePhysics.miscueLimitFraction
        var grid: [SpinVariant] = []
        for fy in [Float(-0.9), -0.6, -0.3, 0, 0.3, 0.6, 0.9] {
            for fx in [Float(-0.6), 0, 0.6] {
                grid.append(SpinVariant(label: String(format: "sx%+.1f_sy%+.1f", fx, fy),
                                        spinX: fx * limit, spinY: fy * limit))
            }
        }
        return grid
    }

    /// Column order of the flat reach table written by `testPostCollisionReach`.
    private var reachColumns: [String] {
        ["rigIndex", "cueSpeed", "spinX", "spinY", "measuredImpactParameterInBallRadii",
         "postContactCueSpeed", "chordLengthMetres", "chordDeviationFromTangentDegrees",
         "arrivalDirectionFromTangentDegrees", "arrivalSpeed", "pathBulgeMetres", "timeSeconds"]
    }

    func testPostCollisionReach() throws {
        let out = try output().appendingPathComponent("post-collision-reach")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let approach: Float = 0.35
        let radius = BallPhysics.radius
        let offsets = Array(stride(from: Float(-1.75), through: 1.75, by: 0.25)).map { $0 * radius }
        let sampleTimes = Array(stride(from: Float(0.025), through: 3.0, by: 0.025))
        let speeds = Array(stride(from: Float(2), through: 8, by: 1))
        // A rig anchored at the table centre can never show a cushion-free run longer than about
        // 0.6 m, but chain segments between pocket-mouth balls are routinely over 1 m. The reach
        // set is translation and rotation invariant as long as no cushion is touched, so the same
        // rig is repeated at four anchors, each with the runway pointing down the table.
        let rigs: [(label: String, anchor: SCNVector3, heading: Float)] = [
            ("centre", SCNVector3(0, y + radius, 0), 0),
            ("west-low", SCNVector3(-0.85, y + radius, -0.42), 0),
            ("west-high", SCNVector3(-0.85, y + radius, 0.42), 0),
            ("east-low", SCNVector3(0.85, y + radius, -0.42), .pi),
            ("east-high", SCNVector3(0.85, y + radius, 0.42), .pi)]
        var rows: [[String: Any]] = []
        var flat: [[Float]] = []
        var simulations = 0
        let started = Date()
        for (rigIndex, rig) in rigs.enumerated() {
        let target = rig.anchor
        let heading = SCNVector3(cosf(rig.heading), 0, sinf(rig.heading))
        let headingNormal = SCNVector3(-heading.z, 0, heading.x)
        for speed in speeds {
            for variant in reachSpinGrid {
                for b0 in offsets {
                    let start = SCNVector3(target.x - approach * heading.x + b0 * headingNormal.x,
                                           y + radius,
                                           target.z - approach * heading.z + b0 * headingNormal.z)
                    let aim = compensatedAim(rig.heading, spinX: variant.spinX, spinY: variant.spinY, speed: speed)
                    let e = EventDrivenEngine(tableGeometry: geometry)
                    setCue(e, at: start, aim: aim, speed: speed, spinX: variant.spinX, spinY: variant.spinY)
                    e.setBall(ball("_probe", at: target))
                    let term = e.simulatePrediction(model: .appDefault, maxEvents: 200, maxTime: 4,
                                                    highFidelityBounds: true,
                                                    stopAfterContactBetween: (cueName, "_probe"))
                    simulations += 1
                    guard term == .contactResolved,
                          let contactIndex = firstEventIndex(e, where: { if case .ballBall = $0 { return true }; return false }),
                          contactIndex < e.resolvedEventTimes.count,
                          let cueAfter = e.getBall(cueName), let targetAfter = e.getBall("_probe") else {
                        continue
                    }
                    let contactTime = e.resolvedEventTimes[contactIndex]
                    // Pre-contact state, to label the row by its measured impact parameter.
                    let pre = EventDrivenEngine(tableGeometry: geometry)
                    setCue(pre, at: start, aim: aim, speed: speed, spinX: variant.spinX, spinY: variant.spinY)
                    _ = pre.simulatePrediction(model: .appDefault, maxEvents: 200,
                                               maxTime: max(0, contactTime - 1e-5), highFidelityBounds: true)
                    simulations += 1
                    guard let cueBefore = pre.getBall(cueName) else { continue }
                    let inSpeed = planarSpeed(cueBefore.velocity)
                    guard inSpeed > 1e-4, cushionEvents(pre, ball: cueName).isEmpty else { continue }
                    let inDir = SCNVector3(cueBefore.velocity.x / inSpeed, 0, cueBefore.velocity.z / inSpeed)
                    let leftNormal = SCNVector3(-inDir.z, 0, inDir.x)
                    let bMeasured = leftNormal.x * (cueBefore.position.x - target.x)
                        + leftNormal.z * (cueBefore.position.z - target.z)
                    let lineLength = distance(cueAfter.position, targetAfter.position)
                    guard lineLength > 1e-6 else { continue }
                    let centreLine = SCNVector3((targetAfter.position.x - cueAfter.position.x) / lineLength, 0,
                                                (targetAfter.position.z - cueAfter.position.z) / lineLength)
                    let rawTangent = SCNVector3(-centreLine.z, 0, centreLine.x)
                    let tangentSign: Float = (rawTangent.x * inDir.x + rawTangent.z * inDir.z) >= 0 ? 1 : -1
                    let tangent = SCNVector3(rawTangent.x * tangentSign, 0, rawTangent.z * tangentSign)
                    let outSpeed = planarSpeed(cueAfter.velocity)
                    guard outSpeed > 1e-4 else { continue }
                    // One flat numeric record per sample (column order in `reachColumns`). A dict
                    // per sample blew past 100 MB of JSON for a single rig and killed the test
                    // host, so the bulge of the real path around the chord is accumulated here
                    // instead of exporting every intermediate position.
                    var path: [SCNVector3] = [cueAfter.position]
                    var samples = 0
                    for t in sampleTimes {
                        let tail = EventDrivenEngine(tableGeometry: geometry)
                        tail.setBall(BallState(position: cueAfter.position, velocity: cueAfter.velocity,
                                               angularVelocity: cueAfter.angularVelocity,
                                               state: cueAfter.state, name: cueName))
                        let tailTerm = tail.simulatePrediction(model: .appDefault, maxEvents: 400,
                                                               maxTime: t, highFidelityBounds: true)
                        simulations += 1
                        guard let now = tail.getBall(cueName), !now.isPocketed else { break }
                        // Only cushion-free samples describe a straight-segment chord.
                        if !cushionEvents(tail, ball: cueName).isEmpty { break }
                        let arrivalSpeed = planarSpeed(now.velocity)
                        path.append(now.position)
                        let chord = SCNVector3(now.position.x - cueAfter.position.x, 0,
                                               now.position.z - cueAfter.position.z)
                        let chordLength = hypotf(chord.x, chord.z)
                        if chordLength > 0.05, arrivalSpeed > 1e-5 {
                            let bulge = path.dropFirst().dropLast()
                                .map { segmentDistance($0, cueAfter.position, now.position) }
                                .max() ?? 0
                            flat.append([Float(rigIndex), speed, variant.spinX, variant.spinY,
                                         bMeasured / radius, outSpeed, chordLength,
                                         signedAngle(tangent, chord),
                                         // Travel direction on arrival sets the impact parameter of
                                         // the next collision; on a curved path it differs from the
                                         // chord direction.
                                         signedAngle(tangent, now.velocity),
                                         arrivalSpeed, bulge, t])
                            samples += 1
                        }
                        if tailTerm == .settled { break }
                    }
                    rows.append(["rig": rig.label, "cueSpeed": speed, "spin": variant.label,
                                 "spinX": variant.spinX, "spinY": variant.spinY,
                                 "measuredImpactParameterInBallRadii": bMeasured / radius,
                                 "incomingBallSpeed": inSpeed, "postContactCueSpeed": outSpeed,
                                 "immediateDeviationFromTangentDegrees": signedAngle(tangent, cueAfter.velocity),
                                 "cushionFreeSamples": samples])
                }
            }
        }
        }
        try JSONSerialization.data(withJSONObject: ["columns": reachColumns, "rows": flat],
                                   options: [.sortedKeys])
            .write(to: out.appendingPathComponent("post-collision-reach.json"), options: .atomic)
        try write(rows, "post-collision-reach-rows.json", to: out)
        // Envelope of |chord deviation| in chord-length bands: how far a straight-segment planner
        // may legitimately bend the cue away from the tangent over a segment of that length.
        let lengthColumn = reachColumns.firstIndex(of: "chordLengthMetres")!
        let deviationColumn = reachColumns.firstIndex(of: "chordDeviationFromTangentDegrees")!
        var bands: [[String: Any]] = []
        for (lo, hi) in [(Float(0.1), Float(0.3)), (0.3, 0.6), (0.6, 1.0), (1.0, 1.5), (1.5, 2.0),
                         (2.0, 3.0)] {
            let deviations = flat.filter { $0[lengthColumn] >= lo && $0[lengthColumn] < hi }
                .map { abs($0[deviationColumn]) }
            bands.append(["chordLengthMetres": [lo, hi], "samples": deviations.count,
                          "absDeviationDegreesMedian": median(deviations),
                          "absDeviationDegreesMax": deviations.max() ?? -1,
                          "absDeviationDegreesP95": deviations.isEmpty ? -1
                              : deviations.sorted()[Int(0.95 * Float(deviations.count - 1))]])
        }
        try write(["rows": rows.count, "cushionFreeSamples": flat.count, "byChordLengthBand": bands,
                   "claimUnderTest": "probe C's 0.3 s window understates the reachable bend; the chord "
                                     + "deviation available to a straight-segment planner grows with segment length"],
                  "post-collision-reach-summary.json", to: out)
        try write(settings(["probe": "post-collision-reach", "approachDistanceMetres": approach,
                            "rigs": rigs.map { ["label": $0.label, "anchorXZ": [$0.anchor.x, $0.anchor.z],
                                                "headingRadians": $0.heading] },
                            "cueSpeeds": speeds, "impactParameterStepInBallRadii": 0.25,
                            "tailSampleStepSeconds": 0.025, "tailSampleMaxSeconds": 3.0,
                            "spinVariants": reachSpinGrid.map { ["label": $0.label, "spinX": $0.spinX, "spinY": $0.spinY] },
                            "flatTableColumns": reachColumns,
                            "simulations": simulations, "seconds": Date().timeIntervalSince(started)]),
                  "experiment-settings.json", to: out)
        XCTAssertGreaterThan(rows.count, 0)
        XCTAssertGreaterThan(flat.count, 0)
    }
}
