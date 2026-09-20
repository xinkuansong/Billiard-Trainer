import XCTest
import SceneKit
@testable import QiuJi

/// v4 round-2 phase-0 probes. Read-only calls into the production engine.
///
/// Round 1 measured its transfer functions through a cue strike, which ties spin to the two
/// tip-offset knobs and always samples "just struck, <1 m of travel". That is why its free-run
/// deceleration came out at 1.962 m/s² = µ_s·g (`SpinPhysics.slidingFriction` 0.2 × 9.81) and got
/// mistaken for a table-wide energy bound (FL-079): every sample was still in the sliding phase.
/// Round 2 therefore seeds ball states directly (position, velocity, angular velocity) so the
/// probes tabulate genuine state → evolution maps over the reachable state box, and measures the
/// sliding and rolling phases separately.
///
/// Opt-in: without `SIX_V4_DIR` every test skips.
final class SixPocketV4Round2ProbeTests: XCTestCase {
    // MARK: - Coordinate contract
    // SceneKit world: XZ horizontal, Y up, metres. Portrait screen up = +X, right = +Z.
    // Travel frame of a ball moving along horizontal unit u: forward = u, up = +Y,
    // rollAxis = ŷ × u. Natural rolling is +v/R about rollAxis (verified in `testLongFreeRun`).
    private let y: Float = 0.8
    private var geometry: TableGeometry { .chineseEightBallQiuJi(surfaceY: y) }
    private var cueName: String { ShotInput.cueBallName }
    private let radius = BallPhysics.radius
    /// Linear cushion indices 0–5 are the six straight rails; every other segment is a jaw line,
    /// a fillet arc or a throat wall, which the cue may not touch (v4 3a). Evidence:
    /// `phase0/cushion-map/cushion-index-map.json` (`straightRailLinearIndices`).
    private let straightRails: Set<Int> = [0, 1, 2, 3, 4, 5]

    // MARK: - Harness

    private func env(_ key: String) -> String? {
        ProcessInfo.processInfo.environment[key] ?? ProcessInfo.processInfo.environment["TEST_RUNNER_" + key]
    }
    private func output() throws -> URL {
        guard let path = env("SIX_V4_DIR") else { throw XCTSkip("Opt-in v4 round-2 phase-0 probe") }
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func write(_ value: Any, _ name: String, to out: URL) throws {
        try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
            .write(to: out.appendingPathComponent(name), options: .atomic)
    }
    private func writeCompact(_ value: Any, _ name: String, to out: URL) throws {
        try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
            .write(to: out.appendingPathComponent(name), options: .atomic)
    }
    private func sourceDigest() -> Any {
        guard let path = env("SIX_V4_SOURCE_SHA256"),
              let text = try? String(contentsOfFile: path, encoding: .utf8) else { return "not supplied" }
        return text.split(separator: "\n").map(String.init)
    }
    private func settings(_ extra: [String: Any]) -> [String: Any] {
        var base: [String: Any] = [
            "spec": "SIX-POCKET-ONE-SHOT-20260917 problem restatement v4, round 2",
            "units": "metres, radians/s; SceneKit XZ horizontal, Y up; portrait up=+X right=+Z",
            "travelFrame": "forward = travel direction; rollAxis = yUp × forward; english = about yUp",
            "ballRadius": radius, "ballDiameter": BallPhysics.diameter,
            "slidingFriction": SpinPhysics.slidingFriction, "rollingFriction": SpinPhysics.rollingFriction,
            "gravity": 9.81,
            "cueSpeedCapMetresPerSecond": 8.0,
            "maxAchievableSpinRadPerSec": maxStrikeSpin,
            "maxAchievableBallSpeed": maxStrikeSpeed,
            "correctionOf": "FL-079 (single-phase v²/2a reachability prune)",
            "simulationModel": "EventDrivenEngine.SimulationModel.appDefault (planarReference)",
            "sourceSha256": sourceDigest()
        ]
        for (k, v) in extra { base[k] = v }
        return base
    }

    // MARK: - Geometry helpers

    private func distance(_ a: SCNVector3, _ b: SCNVector3) -> Float { hypotf(a.x - b.x, a.z - b.z) }
    private func planarSpeed(_ v: SCNVector3) -> Float { hypotf(v.x, v.z) }
    private func degrees(_ r: Float) -> Float { r * 180 / .pi }
    private func signedAngle(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        degrees(atan2f(a.x * b.z - a.z * b.x, a.x * b.x + a.z * b.z))
    }
    private func segmentDistance(_ p: SCNVector3, _ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dx = b.x - a.x, dz = b.z - a.z, l = dx * dx + dz * dz
        let t = l > 0 ? max(0, min(1, ((p.x - a.x) * dx + (p.z - a.z) * dz) / l)) : 0
        return hypotf(p.x - a.x - t * dx, p.z - a.z - t * dz)
    }

    // MARK: - State seeding

    /// Cue-strike envelope, used only to scale the spin grid to states a real stroke can produce.
    private var maxStrikeSpin: Float {
        let limit = CuePhysics.miscueLimitFraction
        var best: Float = 0
        for sx in [-limit, 0, limit] {
            for sy in [-limit, 0, limit] {
                let s = CueBallStrike.executeStrike(aimDirection: SCNVector3(1, 0, 0), velocity: 8,
                                                    spinX: sx, spinY: sy)
                best = max(best, sqrtf(s.angularVelocity.x * s.angularVelocity.x
                                       + s.angularVelocity.y * s.angularVelocity.y
                                       + s.angularVelocity.z * s.angularVelocity.z))
            }
        }
        return best
    }
    private var maxStrikeSpeed: Float {
        planarSpeed(CueBallStrike.executeStrike(aimDirection: SCNVector3(1, 0, 0), velocity: 8,
                                                spinX: 0, spinY: 0).velocity)
    }

    private func rollAxis(_ u: SCNVector3) -> SCNVector3 { SCNVector3(u.z, 0, -u.x) }

    /// Angular velocity for a travel direction and the three travel-frame knobs.
    /// `roll` is in multiples of the natural rolling rate v/R, `english` and `curl` in rad/s.
    private func spinVector(travel u: SCNVector3, speed: Float, roll: Float,
                            english: Float, curl: Float) -> SCNVector3 {
        let a = rollAxis(u), rate = roll * speed / radius
        return SCNVector3(a.x * rate + u.x * curl, english, a.z * rate + u.z * curl)
    }
    /// Travel-frame decomposition of an angular velocity: (rollRatio, english, curl).
    private func spinComponents(_ omega: SCNVector3, travel u: SCNVector3, speed: Float) -> (Float, Float, Float) {
        let a = rollAxis(u)
        let rollRate = omega.x * a.x + omega.z * a.z
        let curl = omega.x * u.x + omega.z * u.z
        return (speed > 1e-5 ? rollRate * radius / speed : 0, omega.y, curl)
    }
    /// Slip speed at the contact point: v + ω × (−R ŷ). Zero means rolling.
    /// With d = (0, −R, 0): (ω × d)_x = −ω_z·d_y = R·ω_z, (ω × d)_z = ω_x·d_y = −R·ω_x.
    private func slipSpeed(velocity v: SCNVector3, spin w: SCNVector3) -> Float {
        hypotf(v.x + radius * w.z, v.z - radius * w.x)
    }
    private func seeded(_ name: String, at p: SCNVector3, velocity v: SCNVector3, spin w: SCNVector3) -> BallState {
        let state: BallMotionState = slipSpeed(velocity: v, spin: w) < 1e-4 ? .rolling : .sliding
        return BallState(position: p, velocity: v, angularVelocity: w, state: state, name: name)
    }
    private func stationary(_ name: String, at p: SCNVector3) -> BallState {
        BallState(position: p, velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero,
                  state: .stationary, name: name)
    }
    private func cushionHits(_ e: EventDrivenEngine, ball: String) -> [Int] {
        e.resolvedEvents.compactMap { if case let .ballCushion(n, i, _) = $0, n == ball { return i }; return nil }
    }

    private func median(_ v: [Float]) -> Float {
        guard !v.isEmpty else { return -1 }
        let s = v.sorted()
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }
    private func percentile(_ v: [Float], _ p: Float) -> Float {
        guard !v.isEmpty else { return -1 }
        let s = v.sorted()
        return s[max(0, min(s.count - 1, Int(p * Float(s.count - 1))))]
    }

    // MARK: - Probe F2: long free run (FL-079 correction)

    /// Fires the cue ball down the length of an otherwise empty table and samples it every 0.1 m
    /// of path until it stops or reaches the far rail. This is the measurement round 1 was missing:
    /// it separates the sliding phase (µ_s·g) from the rolling phase (µ_r·g) and records where the
    /// transition happens, so a reachability bound can be built from the right coefficient.
    func testLongFreeRun() throws {
        let out = try output().appendingPathComponent("long-free-run")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let start = SCNVector3(-1.10, y + radius, 0)
        let heading = SCNVector3(1, 0, 0)
        let spins: [(label: String, roll: Float, english: Float, curl: Float)] = [
            ("centre(stun)", 0, 0, 0),
            ("naturalRoll", 1, 0, 0),
            ("top(high)", 1.6, 0, 0), ("topMax", 2.2, 0, 0),
            ("bottom(draw)", -0.8, 0, 0), ("bottomMax", -1.6, 0, 0),
            ("leftEnglish", 0, maxStrikeSpin * 0.5, 0), ("leftEnglishMax", 0, maxStrikeSpin, 0),
            ("rightEnglish", 0, -maxStrikeSpin * 0.5, 0), ("rightEnglishMax", 0, -maxStrikeSpin, 0)]
        let speeds: [Float] = [1, 1.5, 2, 3, 4, 6]
        // Wrong single-phase bound round 1 used, kept here so the report can quote both numbers.
        let round1Deceleration: Float = 1.9619997687030726
        var rows: [[String: Any]] = []
        var perConfig: [[String: Any]] = []
        var simulations = 0
        let started = Date()
        for v0 in speeds {
            for spin in spins {
                let omega = spinVector(travel: heading, speed: v0, roll: spin.roll,
                                       english: spin.english, curl: spin.curl)
                var samples: [(t: Float, path: Float, speed: Float, state: String, rollRatio: Float)] = []
                var previous = start
                var path: Float = 0
                var reachedRail = false
                var transitionPath: Float = -1, transitionSpeed: Float = -1, transitionTime: Float = -1
                var stopPath: Float = -1
                var t: Float = 0
                let step: Float = 0.01
                while t < 30 {
                    t += step
                    let e = EventDrivenEngine(tableGeometry: geometry)
                    e.setBall(seeded(cueName, at: start, velocity: SCNVector3(heading.x * v0, 0, heading.z * v0),
                                     spin: omega))
                    let term = e.simulatePrediction(model: .appDefault, maxEvents: 200, maxTime: t,
                                                    highFidelityBounds: true)
                    simulations += 1
                    guard let ball = e.getBall(cueName) else { break }
                    if !cushionHits(e, ball: cueName).isEmpty { reachedRail = true; break }
                    path += distance(previous, ball.position)
                    previous = ball.position
                    let speed = planarSpeed(ball.velocity)
                    let comps = spinComponents(ball.angularVelocity, travel: heading, speed: speed)
                    if transitionPath < 0, ball.state == .rolling || slipSpeed(velocity: ball.velocity,
                                                                              spin: ball.angularVelocity) < 1e-3 {
                        transitionPath = path; transitionSpeed = speed; transitionTime = t
                    }
                    // One row per 0.1 m of path, as specified.
                    if samples.isEmpty || path - samples[samples.count - 1].path >= 0.1 {
                        samples.append((t, path, speed, ball.state.rawValue, comps.0))
                    }
                    if term == .settled || speed < 1e-4 { stopPath = path; break }
                }
                for s in samples {
                    rows.append(["launchSpeed": v0, "spin": spin.label, "timeSeconds": s.t,
                                 "pathLengthMetres": s.path, "speed": s.speed, "state": s.state,
                                 "rollRatio": s.rollRatio])
                }
                // Slope fits: sliding phase between launch and transition, rolling phase after it.
                var slidingDeceleration: Float = -1, rollingDeceleration: Float = -1
                if transitionTime > 0, transitionSpeed >= 0 {
                    slidingDeceleration = (v0 - transitionSpeed) / transitionTime
                }
                let rolling = samples.filter { $0.state == "rolling" }
                if let a = rolling.first, let b = rolling.last, b.t - a.t > 0.2 {
                    rollingDeceleration = (a.speed - b.speed) / (b.t - a.t)
                }
                perConfig.append(["launchSpeed": v0, "spin": spin.label,
                                  "rollRatioSeed": spin.roll, "englishSeed": spin.english,
                                  "transitionPathLengthMetres": transitionPath,
                                  "transitionSpeed": transitionSpeed,
                                  "transitionSpeedRatio": transitionSpeed >= 0 ? transitionSpeed / v0 : -1,
                                  "slidingDeceleration": slidingDeceleration,
                                  "rollingDeceleration": rollingDeceleration,
                                  "measuredPathLengthMetres": path,
                                  "stoppedOnTable": stopPath >= 0, "reachedFarRail": reachedRail,
                                  "round1SinglePhasePredictionMetres": v0 * v0 / (2 * round1Deceleration),
                                  "samples": samples.count])
            }
        }
        try write(rows, "long-free-run.json", to: out)
        let stopped = perConfig.filter { ($0["stoppedOnTable"] as? Bool) == true }
        let slidingFits = perConfig.compactMap { $0["slidingDeceleration"] as? Float }.filter { $0 > 0 }
        let rollingFits = perConfig.compactMap { $0["rollingDeceleration"] as? Float }.filter { $0 > 0 }
        let ratios = perConfig.compactMap { $0["transitionSpeedRatio"] as? Float }.filter { $0 >= 0 }
        // Underestimate factor of the round-1 bound, on the configurations that actually stopped.
        let underestimate = stopped.compactMap { c -> Float? in
            guard let measured = c["measuredPathLengthMetres"] as? Float,
                  let predicted = c["round1SinglePhasePredictionMetres"] as? Float, predicted > 0 else { return nil }
            return measured / predicted
        }
        try write(["perConfiguration": perConfig,
                   "slidingDecelerationMedian": median(slidingFits),
                   "slidingDecelerationSamples": slidingFits.count,
                   "rollingDecelerationMedian": median(rollingFits),
                   "rollingDecelerationSamples": rollingFits.count,
                   "transitionSpeedRatioMedian": median(ratios),
                   "analyticSlidingDeceleration": SpinPhysics.slidingFriction * 9.81,
                   "analyticRollingDeceleration": SpinPhysics.rollingFriction * 9.81,
                   "round1SinglePhaseDeceleration": round1Deceleration,
                   "round1BoundUnderestimateFactorMedian": median(underestimate),
                   "round1BoundUnderestimateFactorMax": underestimate.max() ?? -1,
                   "configurationsReachingFarRail": perConfig.filter { ($0["reachedFarRail"] as? Bool) == true }.count,
                   "configurations": perConfig.count,
                   "claimUnderTest": "FL-079: 1.962 m/s² is the sliding phase only; after the slide→roll "
                                     + "transition the deceleration drops to µ_r·g ≈ 0.098 m/s², so the "
                                     + "single-phase v²/(2a) reachability bound is far too small"],
                  "long-free-run-summary.json", to: out)
        try write(settings(["probe": "long-free-run", "startXZ": [start.x, start.z],
                            "headingXZ": [heading.x, heading.z], "launchSpeeds": speeds,
                            "spinConfigurations": spins.map { ["label": $0.label, "rollRatio": $0.roll,
                                                               "english": $0.english, "curl": $0.curl] },
                            "timeStepSeconds": 0.01, "pathSampleStepMetres": 0.1,
                            "simulations": simulations, "seconds": Date().timeIntervalSince(started)]),
                  "experiment-settings.json", to: out)
        XCTAssertGreaterThan(rows.count, 0)
        XCTAssertGreaterThan(rollingFits.count, 0)
    }

    // MARK: - Probe G: free-flight arc table

    private var arcColumns: [String] {
        ["seedSpeed", "seedRollRatio", "seedEnglish", "seedCurl", "pathLengthMetres", "chordLengthMetres",
         "chordDeviationDegrees", "arrivalDirectionDegrees", "arrivalSpeed", "arrivalRollRatio",
         "arrivalEnglish", "arrivalCurl", "bulgeMetres", "timeSeconds", "stopped"]
    }

    /// State → evolution map for a freely running cue ball, in the travel frame of the launch
    /// direction. Seeded directly, so the grid covers the mid-chain states a chain planner needs
    /// (spin left over from an earlier collision) and not just freshly struck balls. Cushion-free
    /// by construction: sampling stops at the first rail contact, and rails are handled by the
    /// separate rail map so a segment can be composed as arc → rail → arc.
    func testFreeArcTable() throws {
        let out = try output().appendingPathComponent("free-arc")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        // Long runway down the middle of the table, so arcs up to ~2.3 m stay cushion-free.
        let start = SCNVector3(-1.15, y + radius, 0)
        let heading = SCNVector3(1, 0, 0)
        let speeds: [Float] = [0.3, 0.5, 0.8, 1.2, 1.6, 2.2, 3.0, 4.0, 5.0, 6.5, 8.0]
        let rollRatios: [Float] = [-1.6, -1.0, -0.5, 0, 0.5, 1.0, 1.5, 2.0]
        let englishLevels: [Float] = [-1, -0.5, -0.2, 0, 0.2, 0.5, 1].map { $0 * maxStrikeSpin }
        let curlLevels: [Float] = [-0.4, 0, 0.4].map { $0 * maxStrikeSpin }
        var flat: [[Float]] = []
        var simulations = 0
        let started = Date()
        for v0 in speeds {
            for roll in rollRatios {
                for english in englishLevels {
                    for curl in curlLevels {
                        let omega = spinVector(travel: heading, speed: v0, roll: roll,
                                               english: english, curl: curl)
                        let velocity = SCNVector3(heading.x * v0, 0, heading.z * v0)
                        var path: [SCNVector3] = [start]
                        var pathLength: Float = 0
                        var previous = start
                        var t: Float = 0
                        // 25 ms sampling matches probe E; a 6 s ceiling covers a 0.3 m/s roll-out.
                        while t < 6 {
                            t += 0.025
                            let e = EventDrivenEngine(tableGeometry: geometry)
                            e.setBall(seeded(cueName, at: start, velocity: velocity, spin: omega))
                            let term = e.simulatePrediction(model: .appDefault, maxEvents: 300, maxTime: t,
                                                            highFidelityBounds: true)
                            simulations += 1
                            guard let ball = e.getBall(cueName), !ball.isPocketed else { break }
                            if !cushionHits(e, ball: cueName).isEmpty { break }
                            pathLength += distance(previous, ball.position)
                            previous = ball.position
                            path.append(ball.position)
                            let speed = planarSpeed(ball.velocity)
                            let chord = SCNVector3(ball.position.x - start.x, 0, ball.position.z - start.z)
                            let chordLength = hypotf(chord.x, chord.z)
                            if chordLength > 0.03 {
                                let bulge = path.dropFirst().dropLast()
                                    .map { segmentDistance($0, start, ball.position) }.max() ?? 0
                                let comps = spinComponents(ball.angularVelocity, travel: heading, speed: speed)
                                let stopped: Float = (term == .settled || speed < 1e-4) ? 1 : 0
                                flat.append([v0, roll, english, curl, pathLength, chordLength,
                                             signedAngle(heading, chord),
                                             speed > 1e-5 ? signedAngle(heading, ball.velocity) : 0,
                                             speed, comps.0, comps.1, comps.2, bulge, t, stopped])
                            }
                            if term == .settled || speed < 1e-4 { break }
                        }
                    }
                }
            }
        }
        try writeCompact(["columns": arcColumns, "rows": flat], "free-arc.json", to: out)
        let lengthColumn = arcColumns.firstIndex(of: "chordLengthMetres")!
        let deviationColumn = arcColumns.firstIndex(of: "chordDeviationDegrees")!
        let speedColumn = arcColumns.firstIndex(of: "arrivalSpeed")!
        var bands: [[String: Any]] = []
        for (lo, hi) in [(Float(0.1), Float(0.3)), (0.3, 0.6), (0.6, 1.0), (1.0, 1.5), (1.5, 2.0), (2.0, 2.6)] {
            let inBand = flat.filter { $0[lengthColumn] >= lo && $0[lengthColumn] < hi }
            bands.append(["chordLengthMetres": [lo, hi], "samples": inBand.count,
                          "absDeviationDegreesMedian": median(inBand.map { abs($0[deviationColumn]) }),
                          "absDeviationDegreesMax": inBand.map { abs($0[deviationColumn]) }.max() ?? -1,
                          "arrivalSpeedMedian": median(inBand.map { $0[speedColumn] }),
                          "arrivalSpeedMax": inBand.map { $0[speedColumn] }.max() ?? -1])
        }
        // Longest cushion-free chord actually achieved per seed speed: the measured replacement for
        // the round-1 v²/(2a) bound.
        var reach: [[String: Any]] = []
        for v0 in speeds {
            let subset = flat.filter { $0[0] == v0 }
            reach.append(["seedSpeed": v0,
                          "maxChordLengthMetres": subset.map { $0[lengthColumn] }.max() ?? -1,
                          "maxPathLengthMetres": subset.map { $0[4] }.max() ?? -1,
                          "round1SinglePhasePredictionMetres": v0 * v0 / (2 * 1.9619997687030726),
                          "samples": subset.count])
        }
        try write(["rows": flat.count, "byChordLengthBand": bands, "reachBySeedSpeed": reach,
                   "note": "sampling stops at the first rail contact, so every row is a cushion-free arc"],
                  "free-arc-summary.json", to: out)
        try write(settings(["probe": "free-arc", "startXZ": [start.x, start.z],
                            "seedSpeeds": speeds, "seedRollRatios": rollRatios,
                            "seedEnglishRadPerSec": englishLevels, "seedCurlRadPerSec": curlLevels,
                            "timeSampleStepSeconds": 0.025, "timeSampleMaxSeconds": 6.0,
                            "flatTableColumns": arcColumns,
                            "simulations": simulations, "seconds": Date().timeIntervalSince(started)]),
                  "experiment-settings.json", to: out)
        XCTAssertGreaterThan(flat.count, 0)
    }

    // MARK: - Probe H: dense collision map

    private var collisionColumns: [String] {
        ["incomingSpeed", "incomingRollRatio", "incomingEnglish", "impactParameterInBallRadii",
         "cueOutSpeed", "cueOutDirectionFromTangentDegrees", "cueOutRollRatio", "cueOutEnglish", "cueOutCurl",
         "targetOutSpeed", "targetOutDirectionFromCentreLineDegrees", "cutAngleDegrees"]
    }

    /// Single collision, seeded directly at the contact approach so the row is indexed by the
    /// measured incoming state rather than by tip offsets. Also records the target ball's launch,
    /// which is what decides whether the pot is on.
    func testCollisionMap() throws {
        let out = try output().appendingPathComponent("collision-map")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let target = SCNVector3(0, y + radius, 0)
        let heading = SCNVector3(1, 0, 0)
        let approach: Float = 0.30
        let speeds: [Float] = [0.5, 0.8, 1.2, 1.6, 2.2, 3.0, 4.0, 5.0, 6.5, 8.0]
        let rollRatios: [Float] = [-1.6, -1.0, -0.5, 0, 0.5, 1.0, 1.5, 2.0]
        let englishLevels: [Float] = [-1, -0.5, 0, 0.5, 1].map { $0 * maxStrikeSpin }
        let offsets = Array(stride(from: Float(-1.95), through: 1.95, by: 0.05))
        var flat: [[Float]] = []
        var simulations = 0
        let started = Date()
        for v0 in speeds {
            for roll in rollRatios {
                for english in englishLevels {
                    for b in offsets {
                        let start = SCNVector3(target.x - approach, y + radius, target.z + b * radius)
                        let omega = spinVector(travel: heading, speed: v0, roll: roll, english: english, curl: 0)
                        let e = EventDrivenEngine(tableGeometry: geometry)
                        e.setBall(seeded(cueName, at: start, velocity: SCNVector3(v0, 0, 0), spin: omega))
                        e.setBall(stationary("_probe", at: target))
                        let term = e.simulatePrediction(model: .appDefault, maxEvents: 200, maxTime: 4,
                                                        highFidelityBounds: true,
                                                        stopAfterContactBetween: (cueName, "_probe"))
                        simulations += 1
                        guard term == .contactResolved,
                              let contactIndex = e.resolvedEvents.firstIndex(where: {
                                  if case .ballBall = $0 { return true }; return false }),
                              contactIndex < e.resolvedEventTimes.count,
                              let cueAfter = e.getBall(cueName), let targetAfter = e.getBall("_probe")
                        else { continue }
                        let contactTime = e.resolvedEventTimes[contactIndex]
                        // Exact pre-contact state, so the row is labelled by what actually arrived.
                        let pre = EventDrivenEngine(tableGeometry: geometry)
                        pre.setBall(seeded(cueName, at: start, velocity: SCNVector3(v0, 0, 0), spin: omega))
                        _ = pre.simulatePrediction(model: .appDefault, maxEvents: 200,
                                                   maxTime: max(0, contactTime - 1e-5), highFidelityBounds: true)
                        simulations += 1
                        guard let cueBefore = pre.getBall(cueName), cushionHits(pre, ball: cueName).isEmpty
                        else { continue }
                        let inSpeed = planarSpeed(cueBefore.velocity)
                        guard inSpeed > 1e-4 else { continue }
                        let inDir = SCNVector3(cueBefore.velocity.x / inSpeed, 0, cueBefore.velocity.z / inSpeed)
                        let inComps = spinComponents(cueBefore.angularVelocity, travel: inDir, speed: inSpeed)
                        let leftNormal = SCNVector3(-inDir.z, 0, inDir.x)
                        let measuredB = (leftNormal.x * (cueBefore.position.x - target.x)
                                         + leftNormal.z * (cueBefore.position.z - target.z)) / radius
                        let lineLength = distance(cueAfter.position, targetAfter.position)
                        guard lineLength > 1e-6 else { continue }
                        let centreLine = SCNVector3((targetAfter.position.x - cueAfter.position.x) / lineLength, 0,
                                                    (targetAfter.position.z - cueAfter.position.z) / lineLength)
                        let raw = SCNVector3(-centreLine.z, 0, centreLine.x)
                        let sign: Float = (raw.x * inDir.x + raw.z * inDir.z) >= 0 ? 1 : -1
                        let tangent = SCNVector3(raw.x * sign, 0, raw.z * sign)
                        let cueOutSpeed = planarSpeed(cueAfter.velocity)
                        let targetOutSpeed = planarSpeed(targetAfter.velocity)
                        guard cueOutSpeed > 1e-5 || targetOutSpeed > 1e-5 else { continue }
                        let cueOutDir = cueOutSpeed > 1e-5
                            ? SCNVector3(cueAfter.velocity.x / cueOutSpeed, 0, cueAfter.velocity.z / cueOutSpeed)
                            : tangent
                        let outComps = spinComponents(cueAfter.angularVelocity, travel: cueOutDir, speed: cueOutSpeed)
                        flat.append([inSpeed, inComps.0, inComps.1, measuredB,
                                     cueOutSpeed, signedAngle(tangent, cueAfter.velocity),
                                     outComps.0, outComps.1, outComps.2,
                                     targetOutSpeed,
                                     targetOutSpeed > 1e-5 ? signedAngle(centreLine, targetAfter.velocity) : 0,
                                     signedAngle(inDir, centreLine)])
                    }
                }
            }
        }
        try writeCompact(["columns": collisionColumns, "rows": flat], "collision-map.json", to: out)
        // Throw check: how far the target leaves the line of centres, and how the cue's departure
        // sits against the stun tangent. Round 1 asserted "spin barely changes"; quantify here.
        let throwColumn = collisionColumns.firstIndex(of: "targetOutDirectionFromCentreLineDegrees")!
        let cueOutColumn = collisionColumns.firstIndex(of: "cueOutDirectionFromTangentDegrees")!
        let throwValues = flat.filter { $0[9] > 1e-3 }.map { $0[throwColumn] }
        let cueDeviation = flat.filter { $0[4] > 1e-3 }.map { $0[cueOutColumn] }
        try write(["rows": flat.count,
                   "targetThrowDegreesMedian": median(throwValues),
                   "targetThrowDegreesP05": percentile(throwValues, 0.05),
                   "targetThrowDegreesP95": percentile(throwValues, 0.95),
                   "cueDepartureFromTangentDegreesMedian": median(cueDeviation),
                   "cueDepartureFromTangentDegreesP05": percentile(cueDeviation, 0.05),
                   "cueDepartureFromTangentDegreesP95": percentile(cueDeviation, 0.95)],
                  "collision-map-summary.json", to: out)
        try write(settings(["probe": "collision-map", "approachDistanceMetres": approach,
                            "targetXZ": [target.x, target.z], "seedSpeeds": speeds,
                            "seedRollRatios": rollRatios, "seedEnglishRadPerSec": englishLevels,
                            "impactParameterStepInBallRadii": 0.05,
                            "impactParameterRangeInBallRadii": [-1.95, 1.95],
                            "flatTableColumns": collisionColumns,
                            "simulations": simulations, "seconds": Date().timeIntervalSince(started)]),
                  "experiment-settings.json", to: out)
        XCTAssertGreaterThan(flat.count, 0)
    }

    // MARK: - Probe I: dense rail map

    private var railColumns: [String] {
        ["railIndex", "incomingSpeed", "incomingRollRatio", "incomingEnglish", "incidenceFromNormalDegrees",
         "outSpeed", "speedRetention", "deviationFromMirrorDegrees", "outRollRatio", "outEnglish", "outCurl"]
    }

    /// Rail reflection indexed by the measured pre-contact state, for the two straight-rail
    /// orientations (long rail 0/2, short rail 4/5). Needed because round 2 lets a chain segment
    /// use 1–2 cushions, and the round-1 reflection probe only carried five struck spin variants.
    func testRailMap() throws {
        let out = try output().appendingPathComponent("rail-map")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let g = geometry
        // Aim at a point well inside each straight rail, from a launch point offset along the
        // incoming direction so nothing else is in the way.
        let rails: [(index: Int, point: SCNVector3, normal: SCNVector3)] = [
            (2, SCNVector3(-0.62, y + radius, -0.635 + radius), SCNVector3(0, 0, 1)),
            (0, SCNVector3(-0.62, y + radius, 0.635 - radius), SCNVector3(0, 0, -1)),
            (4, SCNVector3(-1.27 + radius, y + radius, 0.10), SCNVector3(1, 0, 0)),
            (5, SCNVector3(1.27 - radius, y + radius, -0.10), SCNVector3(-1, 0, 0))]
        let speeds: [Float] = [0.5, 0.8, 1.2, 1.8, 2.5, 3.5, 5.0, 6.5, 8.0]
        let rollRatios: [Float] = [-1.0, 0, 0.5, 1.0, 1.6]
        let englishLevels: [Float] = [-1, -0.5, 0, 0.5, 1].map { $0 * maxStrikeSpin }
        let incidences: [Float] = [15, 25, 35, 45, 55, 65, 75]
        var flat: [[Float]] = []
        var simulations = 0
        let started = Date()
        for rail in rails {
            // Tangent along the rail; incidence is measured from the inward normal.
            let tangent = SCNVector3(-rail.normal.z, 0, rail.normal.x)
            for incidence in incidences {
                let a = incidence * .pi / 180
                // Travel direction into the rail: -normal rotated by the incidence about Y.
                let dir = SCNVector3(-rail.normal.x * cosf(a) + tangent.x * sinf(a), 0,
                                     -rail.normal.z * cosf(a) + tangent.z * sinf(a))
                let runway: Float = 0.45
                let start = SCNVector3(rail.point.x - dir.x * runway, y + radius, rail.point.z - dir.z * runway)
                guard abs(start.x) < 1.24, abs(start.z) < 0.60 else { continue }
                for v0 in speeds {
                    for roll in rollRatios {
                        for english in englishLevels {
                            let omega = spinVector(travel: dir, speed: v0, roll: roll, english: english, curl: 0)
                            let velocity = SCNVector3(dir.x * v0, 0, dir.z * v0)
                            let e = EventDrivenEngine(tableGeometry: geometry)
                            e.setBall(seeded(cueName, at: start, velocity: velocity, spin: omega))
                            let term = e.simulatePrediction(model: .appDefault, maxEvents: 60, maxTime: 6,
                                                            highFidelityBounds: true)
                            simulations += 1
                            _ = term
                            let hits = cushionHits(e, ball: cueName)
                            guard let first = hits.first, first == rail.index,
                                  let hitIndex = e.resolvedEvents.firstIndex(where: {
                                      if case let .ballCushion(n, i, _) = $0, n == cueName, i == rail.index { return true }
                                      return false }),
                                  hitIndex < e.resolvedEventTimes.count
                            else { continue }
                            let hitTime = e.resolvedEventTimes[hitIndex]
                            let pre = EventDrivenEngine(tableGeometry: geometry)
                            pre.setBall(seeded(cueName, at: start, velocity: velocity, spin: omega))
                            _ = pre.simulatePrediction(model: .appDefault, maxEvents: 60,
                                                       maxTime: max(0, hitTime - 1e-5), highFidelityBounds: true)
                            let post = EventDrivenEngine(tableGeometry: geometry)
                            post.setBall(seeded(cueName, at: start, velocity: velocity, spin: omega))
                            _ = post.simulatePrediction(model: .appDefault, maxEvents: 60,
                                                        maxTime: hitTime + 1e-4, highFidelityBounds: true)
                            simulations += 2
                            guard let before = pre.getBall(cueName), let after = post.getBall(cueName) else { continue }
                            let inSpeed = planarSpeed(before.velocity), outSpeed = planarSpeed(after.velocity)
                            guard inSpeed > 1e-4, outSpeed > 1e-5 else { continue }
                            let inDir = SCNVector3(before.velocity.x / inSpeed, 0, before.velocity.z / inSpeed)
                            let inComps = spinComponents(before.angularVelocity, travel: inDir, speed: inSpeed)
                            let dot = inDir.x * rail.normal.x + inDir.z * rail.normal.z
                            let mirror = SCNVector3(inDir.x - 2 * dot * rail.normal.x, 0,
                                                    inDir.z - 2 * dot * rail.normal.z)
                            let outDir = SCNVector3(after.velocity.x / outSpeed, 0, after.velocity.z / outSpeed)
                            let outComps = spinComponents(after.angularVelocity, travel: outDir, speed: outSpeed)
                            flat.append([Float(rail.index), inSpeed, inComps.0, inComps.1,
                                         abs(signedAngle(SCNVector3(-rail.normal.x, 0, -rail.normal.z), inDir)),
                                         outSpeed, outSpeed / inSpeed, signedAngle(mirror, after.velocity),
                                         outComps.0, outComps.1, outComps.2])
                        }
                    }
                }
            }
        }
        try writeCompact(["columns": railColumns, "rows": flat], "rail-map.json", to: out)
        let retention = flat.map { $0[6] }
        let deviation = flat.map { $0[7] }
        try write(["rows": flat.count,
                   "speedRetentionMedian": median(retention),
                   "speedRetentionP05": percentile(retention, 0.05),
                   "speedRetentionP95": percentile(retention, 0.95),
                   "mirrorDeviationDegreesMedian": median(deviation),
                   "mirrorDeviationDegreesP05": percentile(deviation, 0.05),
                   "mirrorDeviationDegreesP95": percentile(deviation, 0.95),
                   "absMirrorDeviationDegreesMax": deviation.map { abs($0) }.max() ?? -1],
                  "rail-map-summary.json", to: out)
        try write(settings(["probe": "rail-map",
                            "rails": rails.map { ["index": $0.index, "pointXZ": [$0.point.x, $0.point.z],
                                                  "inwardNormalXZ": [$0.normal.x, $0.normal.z]] },
                            "incidenceFromNormalDegrees": incidences, "seedSpeeds": speeds,
                            "seedRollRatios": rollRatios, "seedEnglishRadPerSec": englishLevels,
                            "flatTableColumns": railColumns,
                            "simulations": simulations, "seconds": Date().timeIntervalSince(started)]),
                  "experiment-settings.json", to: out)
        XCTAssertGreaterThan(flat.count, 0)
    }

    // MARK: - Probe J: multi-rail polyline reach (validation of the composed model)

    private var polylineColumns: [String] {
        ["seedSpeed", "seedRollRatio", "seedEnglish", "railCount", "rail1Index", "rail2Index",
         "leg1LengthMetres", "leg2LengthMetres", "leg3LengthMetres", "totalPathMetres",
         "arrivalSpeed", "endToEndDistanceMetres", "usable", "touchedForbiddenSegment"]
    }

    /// The round-1 reach probe stopped at the first cushion, so the planner could only use 0-rail
    /// segments. This probe follows the cue through up to two straight-rail contacts and records
    /// the polyline (contact point → rail points → arrival), marking any run that touches a jaw
    /// line, fillet arc or throat wall as unusable for the cue under v4 3a. It is the ground truth
    /// the composed arc → rail → arc model in `plan2.py` is checked against.
    func testMultiRailPolyline() throws {
        let out = try output().appendingPathComponent("multi-rail-polyline")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let anchors: [SCNVector3] = [SCNVector3(-0.9, y + radius, -0.3), SCNVector3(-0.3, y + radius, 0.2),
                                     SCNVector3(0.4, y + radius, -0.15), SCNVector3(0.95, y + radius, 0.35)]
        let headings: [Float] = Array(stride(from: Float(0), to: 360, by: 15)).map { $0 * .pi / 180 }
        let speeds: [Float] = [1.0, 2.0, 3.0, 4.5, 6.0, 8.0]
        let rollRatios: [Float] = [0, 1.0]
        let englishLevels: [Float] = [-1, 0, 1].map { $0 * maxStrikeSpin }
        var flat: [[Float]] = []
        var polylines: [[String: Any]] = []
        var simulations = 0
        let started = Date()
        for anchor in anchors {
            for h in headings {
                let dir = SCNVector3(cosf(h), 0, sinf(h))
                for v0 in speeds {
                    for roll in rollRatios {
                        for english in englishLevels {
                            let omega = spinVector(travel: dir, speed: v0, roll: roll, english: english, curl: 0)
                            let e = EventDrivenEngine(tableGeometry: geometry)
                            e.setBall(seeded(cueName, at: anchor, velocity: SCNVector3(dir.x * v0, 0, dir.z * v0),
                                             spin: omega))
                            _ = e.simulatePrediction(model: .appDefault, maxEvents: 400, maxTime: 12,
                                                     highFidelityBounds: true)
                            simulations += 1
                            var railTimes: [(index: Int, time: Float)] = []
                            for (i, event) in e.resolvedEvents.enumerated() {
                                if case let .ballCushion(n, index, _) = event, n == cueName,
                                   i < e.resolvedEventTimes.count {
                                    railTimes.append((index, e.resolvedEventTimes[i]))
                                }
                            }
                            let considered = Array(railTimes.prefix(2))
                            let forbidden = considered.contains { !straightRails.contains($0.index) }
                            // Positions at the rail contacts and at the end of the run.
                            var turns: [SCNVector3] = []
                            for hit in considered {
                                let mid = EventDrivenEngine(tableGeometry: geometry)
                                mid.setBall(seeded(cueName, at: anchor,
                                                   velocity: SCNVector3(dir.x * v0, 0, dir.z * v0), spin: omega))
                                _ = mid.simulatePrediction(model: .appDefault, maxEvents: 400,
                                                           maxTime: max(0, hit.time - 1e-5),
                                                           highFidelityBounds: true)
                                simulations += 1
                                if let ball = mid.getBall(cueName) { turns.append(ball.position) }
                            }
                            // End of the usable run: settle point, or the third rail contact.
                            let endTime = railTimes.count > 2 ? railTimes[2].time - 1e-5 : 12
                            let end = EventDrivenEngine(tableGeometry: geometry)
                            end.setBall(seeded(cueName, at: anchor,
                                               velocity: SCNVector3(dir.x * v0, 0, dir.z * v0), spin: omega))
                            _ = end.simulatePrediction(model: .appDefault, maxEvents: 400, maxTime: endTime,
                                                       highFidelityBounds: true)
                            simulations += 1
                            guard let last = end.getBall(cueName), !last.isPocketed else { continue }
                            var points = [anchor]; points.append(contentsOf: turns); points.append(last.position)
                            var legs: [Float] = []
                            for i in 1..<points.count { legs.append(distance(points[i - 1], points[i])) }
                            while legs.count < 3 { legs.append(-1) }
                            flat.append([v0, roll, english, Float(considered.count),
                                         considered.count > 0 ? Float(considered[0].index) : -1,
                                         considered.count > 1 ? Float(considered[1].index) : -1,
                                         legs[0], legs[1], legs[2], legs.filter { $0 > 0 }.reduce(0, +),
                                         planarSpeed(last.velocity), distance(anchor, last.position),
                                         forbidden ? 0 : 1, forbidden ? 1 : 0])
                            if !forbidden, considered.count >= 1 {
                                polylines.append(["seedSpeed": v0, "seedRollRatio": roll, "seedEnglish": english,
                                                  "headingRadians": h,
                                                  "points": points.map { [$0.x, $0.z] },
                                                  "railIndices": considered.map { $0.index },
                                                  "arrivalSpeed": planarSpeed(last.velocity)])
                            }
                        }
                    }
                }
            }
        }
        try writeCompact(["columns": polylineColumns, "rows": flat], "multi-rail-polyline.json", to: out)
        try writeCompact(polylines, "multi-rail-polylines-usable.json", to: out)
        let usable = flat.filter { $0[12] == 1 }
        var byRailCount: [[String: Any]] = []
        for n in 0...2 {
            let subset = usable.filter { $0[3] == Float(n) }
            byRailCount.append(["railCount": n, "samples": subset.count,
                                "totalPathMetresMedian": median(subset.map { $0[9] }),
                                "totalPathMetresMax": subset.map { $0[9] }.max() ?? -1,
                                "arrivalSpeedMedian": median(subset.map { $0[10] })])
        }
        try write(["rows": flat.count, "usableRows": usable.count,
                   "rowsTouchingForbiddenSegment": flat.filter { $0[13] == 1 }.count,
                   "byRailCount": byRailCount,
                   "note": "usable = the cue's first two cushion contacts are all straight rails 0–5"],
                  "multi-rail-polyline-summary.json", to: out)
        try write(settings(["probe": "multi-rail-polyline",
                            "anchorsXZ": anchors.map { [$0.x, $0.z] },
                            "headingStepDegrees": 15, "seedSpeeds": speeds,
                            "seedRollRatios": rollRatios, "seedEnglishRadPerSec": englishLevels,
                            "straightRailIndices": Array(straightRails).sorted(),
                            "flatTableColumns": polylineColumns,
                            "simulations": simulations, "seconds": Date().timeIntervalSince(started)]),
                  "experiment-settings.json", to: out)
        XCTAssertGreaterThan(flat.count, 0)
    }
}
