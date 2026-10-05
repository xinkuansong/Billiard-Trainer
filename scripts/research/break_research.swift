// Test-only research harness, temporarily compiled inside the existing test target.
// All motion, collision, pocket, strike and rack rules come from production sources.
// Coordinates: SceneKit X-Z metres, +Y up; rack axis -X.
final class BreakPottingResearchTests: XCTestCase {
    private let configurationPath = "/Users/song/projects/13.billiard_trainer/build/break-potting-research-20261002/config.json"
    private let cue = PositionPlayBall.cueKey

    private struct Job: Decodable {
        let id: String
        let rackKind: String
        let seed: UInt64
        let theta: Float
        let fraction: Float
        let contactSpeed: Float
        var reverse: Bool = false
        var mirror: Bool = false
        var trace: Bool = false
        var mode: String = "matched"
        var cueX: Float = 0.70
        var cueZ: Float = 0
        var aimTheta: Float = 0
        var power: Float = 8
        var spinY: Float = 0
        var spinX: Float?
        var targetSlot: Int?
        var maxTime: Float?
    }

    private struct Batch: Decodable { let jobs: [Job] }
    private struct Input {
        let position: SCNVector3
        let direction: SCNVector3
        let velocity: SCNVector3
        let omega: SCNVector3
        let distance: Float
        let time: Float
        let power: Float
        let spinY: Float
        let spinX: Float
    }
    private enum ResearchError: Error { case invalid(String) }

    private func emit(_ row: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys])
        print("[BREAK-RESEARCH] " + String(decoding: data, as: UTF8.self))
    }

    private func vector(_ v: SCNVector3) -> [Float] { [v.x, v.y, v.z] }
    private func angle(_ v: SCNVector3) -> Float { atan2f(v.z, -v.x) * 180 / .pi }
    private func lengthXZ(_ v: SCNVector3) -> Float { hypotf(v.x, v.z) }

    private func rack(_ job: Job) -> Rack {
        let original = RackLayout.make(.chineseEightBall, seed: job.seed)
        var positions = original.balls.map(\.position)
        if job.rackKind == "nominal" {
            let d = 2 * BallPhysics.radius + RackLayout.gap
            let step = d * sqrtf(3) / 2
            positions = (0..<5).flatMap { row in
                (0...row).map { col in
                    SCNVector3(-TablePhysics.innerLength / 4 - Float(row) * step,
                        original.surfaceY + BallPhysics.radius, (Float(row) / 2 - Float(col)) * d)
                }
            }
        }
        if job.mirror { positions = positions.map { SCNVector3($0.x, $0.y, -$0.z) } }
        let balls = original.balls.enumerated().map { i, b in
            RackBall(key: b.key, number: b.number, position: positions[i])
        }
        return Rack(game: original.game, cue: original.cue, balls: balls, surfaceY: original.surfaceY)
    }

    // Invert the existing horizontal strike by matching omega/v first, then scale V0.
    private func strikeControls(direction: SCNVector3, velocity: SCNVector3,
                                omega: SCNVector3) throws -> (Float, Float) {
        let v = lengthXZ(velocity)
        let side = direction.cross(SCNVector3(0, 1, 0))
        let ratio = omega.dot(side) / v
        var low: Float = -0.75, high: Float = 0.75
        for _ in 0..<40 {
            let b = (low + high) / 2
            let strike = CueBallStrike.executeStrike(aimDirection: direction, velocity: 1, spinX: 0, spinY: b)
            let measured = strike.angularVelocity.dot(side) / lengthXZ(strike.velocity)
            // Positive high-ball spin gives a negative component along u cross up.
            if measured > ratio { low = b } else { high = b }
        }
        let spinY = (low + high) / 2
        let unit = CueBallStrike.executeStrike(aimDirection: direction, velocity: 1, spinX: 0, spinY: spinY)
        let power = v / lengthXZ(unit.velocity)
        let strike = CueBallStrike.executeStrike(aimDirection: direction, velocity: power, spinX: 0, spinY: spinY)
        guard (strike.velocity - velocity).length() < 0.00002,
              (strike.angularVelocity - omega).length() < 0.002 else {
            throw ResearchError.invalid("Strike inversion mismatch")
        }
        return (power, spinY)
    }

    private func input(_ job: Job, rack: Rack) throws -> Input {
        let theta = (job.mirror ? -job.theta : job.theta) * .pi / 180
        let u = SCNVector3(-cosf(theta), 0, sinf(theta))
        let p = SCNVector3(sinf(theta), 0, cosf(theta))
        let targetSlot = job.mode == "design" ? (job.targetSlot ?? 0) : 0
        guard rack.balls.indices.contains(targetSlot) else { throw ResearchError.invalid("Unknown target slot") }
        let apex = rack.balls[targetSlot].position
        let beta = asinf(job.mirror ? -job.fraction : job.fraction)
        let normal = u * cosf(beta) + p * sinf(beta)
        let contact = apex - normal * (2 * BallPhysics.radius)
        if job.mode == "execute" {
            let spinX = job.spinX ?? 0
            guard hypotf(spinX, job.spinY) <= CuePhysics.miscueLimitFraction, job.power > 0,
                  job.cueX >= TablePhysics.innerLength / 4,
                  abs(job.cueX) + BallPhysics.radius < TablePhysics.innerLength / 2,
                  abs(job.cueZ) + BallPhysics.radius < TablePhysics.innerWidth / 2 else {
                throw ResearchError.invalid("Illegal execution controls")
            }
            let aim = job.aimTheta * .pi / 180
            let direction = SCNVector3(-cosf(aim), 0, sinf(aim))
            let strike = CueBallStrike.executeStrike(aimDirection: direction, velocity: job.power,
                spinX: spinX, spinY: job.spinY)
            return Input(position: SCNVector3(job.cueX, apex.y, job.cueZ), direction: direction,
                velocity: strike.velocity, omega: strike.angularVelocity, distance: 0, time: 0,
                power: job.power, spinY: job.spinY, spinX: spinX)
        }
        guard abs(job.fraction) < 1, job.contactSpeed > 0, -u.x > 0 else {
            throw ResearchError.invalid("Invalid matched parameters")
        }
        let distance = (job.cueX - contact.x) / (-u.x)
        let position = contact - u * distance
        guard distance > 0, position.x >= TablePhysics.innerLength / 4,
              abs(position.x) + BallPhysics.radius < TablePhysics.innerLength / 2,
              abs(position.z) + BallPhysics.radius < TablePhysics.innerWidth / 2 else {
            throw ResearchError.invalid("Cue outside legal start domain")
        }
        if job.mode == "design" {
            let diameter = 2 * BallPhysics.radius
            let first = rack.balls.enumerated().compactMap { slot, ball -> (Float, Int)? in
                let delta = ball.position - position
                let along = delta.dot(u), lateral = delta.dot(p)
                let disc = diameter * diameter - lateral * lateral
                return disc >= 0 && along > 0 ? (along - sqrtf(disc), slot) : nil
            }.min(by: { $0.0 < $1.0 })?.1
            guard first == targetSlot else { throw ResearchError.invalid("Nominal ray first hits another ball") }
            let spinX = job.spinX ?? 0
            guard hypotf(spinX, job.spinY) <= CuePhysics.miscueLimitFraction, job.power > 0 else {
                throw ResearchError.invalid("Illegal design strike")
            }
            // Compensate production squirt once on the nominal rack. This fixes the initial
            // velocity ray, not the eventual collision state or the perturbed rack outcome.
            let reference = CueBallStrike.executeStrike(aimDirection: u, velocity: job.power,
                spinX: spinX, spinY: job.spinY)
            let aimAngle = theta - (angle(reference.velocity) * .pi / 180 - theta)
            let aim = SCNVector3(-cosf(aimAngle), 0, sinf(aimAngle))
            let strike = CueBallStrike.executeStrike(aimDirection: aim, velocity: job.power,
                spinX: spinX, spinY: job.spinY)
            guard abs(angle(strike.velocity) - job.theta) < 0.001 else {
                throw ResearchError.invalid("Squirt compensation direction mismatch")
            }
            return Input(position: position, direction: aim, velocity: strike.velocity,
                omega: strike.angularVelocity, distance: distance, time: 0,
                power: job.power, spinY: job.spinY, spinX: spinX)
        }
        // With zero omega at impact, slip remains in direction u over the entire approach.
        let a = SpinPhysics.slidingFriction * TablePhysics.gravity
        let initialSpeed = sqrtf(job.contactSpeed * job.contactSpeed + 2 * a * distance)
        let time = 2 * distance / (initialSpeed + job.contactSpeed)
        let velocity = u * initialSpeed
        let omega = u.cross(SCNVector3(0, 1, 0)) * (5 * a * time / (2 * BallPhysics.radius))
        let end = AnalyticalMotion.evolveSliding(position: position, velocity: velocity,
            angularVelocity: omega, dt: time)
        guard (end.position - contact).length() < 0.000003,
              abs(lengthXZ(end.velocity) - job.contactSpeed) < 0.00002,
              end.angularVelocity.length() < 0.002 else {
            throw ResearchError.invalid("Analytic inverse mismatch")
        }
        // Check the first geometric intersection, including all non-apex rack balls.
        let diameter = 2 * BallPhysics.radius
        var intersections: [(Float, String)] = []
        for ball in rack.balls {
            let delta = ball.position - position
            let along = delta.dot(u)
            let lateral = delta.dot(p)
            let disc = diameter * diameter - lateral * lateral
            if disc >= 0, along > 0 {
                intersections.append((along - sqrtf(disc), ball.key))
            }
        }
        guard intersections.min(by: { $0.0 < $1.0 })?.1 == rack.balls[0].key else {
            throw ResearchError.invalid("Another rack ball is struck before apex")
        }
        let controls = try strikeControls(direction: u, velocity: velocity, omega: omega)
        guard abs(controls.1) <= CuePhysics.miscueLimitFraction else {
            throw ResearchError.invalid("Matched state requires an unreachable strike")
        }
        let actualStrike = CueBallStrike.executeStrike(aimDirection: u, velocity: controls.0,
            spinX: 0, spinY: controls.1)
        return Input(position: position, direction: u, velocity: actualStrike.velocity, omega: actualStrike.angularVelocity,
            distance: distance, time: time, power: controls.0, spinY: controls.1, spinX: 0)
    }

    private func engine(_ rack: Rack, input: Input, reverse: Bool) -> EventDrivenEngine {
        let e = EventDrivenEngine(tableGeometry: .chineseEightBallQiuJi(surfaceY: rack.surfaceY))
        e.getTrajectoryRecorder().cueStrikeSpeed = input.power
        e.setBall(BallState(position: input.position, velocity: input.velocity, angularVelocity: input.omega,
            state: .sliding, name: cue))
        for ball in reverse ? Array(rack.balls.reversed()) : rack.balls {
            e.setBall(BallState(position: ball.position, velocity: SCNVector3Zero,
                angularVelocity: SCNVector3Zero, state: .stationary, name: ball.key))
        }
        return e
    }

    private func precontact(_ recorder: TrajectoryRecorder, time: Float) throws
        -> (position: SCNVector3, velocity: SCNVector3, angularVelocity: SCNVector3) {
        let frames = try XCTUnwrap(recorder.framesByBallName[cue])
        let f = try XCTUnwrap(frames.last(where: { $0.time < time }))
        let omega = SCNVector3(f.angularVelocity.x, f.angularVelocity.y, f.angularVelocity.z)
        switch f.state {
        case .sliding:
            return AnalyticalMotion.evolveSliding(position: f.position, velocity: f.velocity,
                angularVelocity: omega, dt: time - f.time)
        case .rolling:
            return AnalyticalMotion.evolveRolling(position: f.position, velocity: f.velocity,
                angularVelocity: omega, dt: time - f.time)
        default: throw ResearchError.invalid("Unexpected approach state \(f.state)")
        }
    }

    private func run(_ job: Job) throws -> [String: Any] {
        let r = rack(job)
        var row: [String: Any] = ["id": job.id, "rackKind": job.rackKind, "seed": job.seed,
            "theta": job.theta, "fraction": job.fraction, "contactSpeed": job.contactSpeed,
            "mode": job.mode, "reverse": job.reverse, "mirror": job.mirror]
        let start: Input
        do { start = try input(job, rack: r) }
        catch { row["inputError"] = String(describing: error); return row }
        row["cuePosition"] = vector(start.position)
        row["initialVelocity"] = vector(start.velocity)
        row["initialOmega"] = vector(start.omega)
        row["distanceM"] = start.distance
        row["power"] = start.power
        row["spinY"] = start.spinY
        row["spinX"] = start.spinX
        row["aimTheta"] = angle(start.direction)
        let e = engine(r, input: start, reverse: job.reverse)
        let begin = DispatchTime.now().uptimeNanoseconds
        var termination = e.simulatePrediction(model: .appDefault, maxEvents: 8000,
            maxTime: job.maxTime ?? 30, highFidelityBounds: true)
        if termination == .settled { termination = e.resolveRestingOverlaps() }
        row["computeMS"] = Double(DispatchTime.now().uptimeNanoseconds - begin) / 1_000_000
        row["termination"] = String(describing: termination)
        row["maxTime"] = job.maxTime ?? 30
        row["settled"] = termination == .settled
        let rec = e.getTrajectoryRecorder()
        row["duration"] = rec.duration
        row["events"] = e.resolvedEvents.count
        var firstIndex: Int?
        for (index, event) in e.resolvedEvents.enumerated() {
            if case .ballBall(let a, let b) = event, a == cue || b == cue {
                firstIndex = index; break
            }
        }
        var contactValid = false
        if let index = firstIndex {
            let t = e.resolvedEventTimes[index]
            let pre = try precontact(rec, time: t)
            let v = lengthXZ(pre.velocity)
            let incoming = pre.velocity * (1 / v)
            var firstBall = ""
            if case .ballBall(let a, let b) = e.resolvedEvents[index] { firstBall = a == cue ? b : a }
            let firstPosition = try XCTUnwrap(r.balls.first(where: { $0.key == firstBall })).position
            let normal = (firstPosition - pre.position).normalized()
            let side = SCNVector3(incoming.z, 0, -incoming.x)
            let measuredFraction = normal.dot(side)
            let actualTheta = angle(pre.velocity)
            let expectedTheta = job.mirror ? -job.theta : job.theta
            let expectedFraction = job.mirror ? -job.fraction : job.fraction
            let preBanks = e.resolvedEvents.prefix(index).filter {
                if case .ballCushion(let ball, _, _) = $0 { return ball == cue }; return false
            }.count
            contactValid = firstBall == r.balls[0].key && preBanks == 0
            if job.mode == "matched" {
                contactValid = contactValid && abs(actualTheta - expectedTheta) < 0.02
                    && abs(measuredFraction - expectedFraction) < 0.001
                    && abs(v - job.contactSpeed) < 0.002 && pre.angularVelocity.length() < 0.05
            }
            row["contact"] = ["time": t, "firstBall": firstBall, "firstSlot": r.balls.firstIndex(where: { $0.key == firstBall }) ?? -1,
                "theta": actualTheta, "fraction": measuredFraction, "speed": v,
                "omega": vector(pre.angularVelocity), "position": vector(pre.position), "cueBanksBefore": preBanks] as [String: Any]
        }
        row["contactValid"] = contactValid
        let final = e.getAllBalls()
        if termination != .settled {
            row["remainingMotion"] = final.filter { !$0.isPocketed && $0.state != .stationary }.map {
                ["name": $0.name, "state": $0.state.rawValue, "velocity": vector($0.velocity),
                 "omega": vector($0.angularVelocity)] as [String: Any]
            }
        }
        let pockets = Set(final.filter { $0.isPocketed }.map(\.name))
        let scratched = pockets.contains(cue)
        let eight = pockets.contains("_8")
        let ordinary = pockets.subtracting([cue, "_8"])
        row["ordinaryPots"] = ordinary.count
        row["scratch"] = scratched
        row["eight"] = eight
        row["effectivePot"] = termination == .settled && (job.mode == "execute" ? firstIndex != nil : contactValid)
            && !scratched && !ordinary.isEmpty
        row["pocketedSlots"] = r.balls.enumerated().filter { pockets.contains($0.element.key) }.map { $0.offset }
        row["finalBySlot"] = r.balls.map { ball -> [Any] in
            let state = final.first(where: { $0.name == ball.key })!
            return [state.position.x, state.position.z, state.state.rawValue]
        }
        row["cueFinal"] = final.first(where: { $0.name == cue }).map { vector($0.position) }
        var banks = Set<String>()
        var paths: [[String: Any]] = []
        for (index, event) in e.resolvedEvents.enumerated() {
            if case .ballCushion(let ball, _, _) = event, ball != cue { banks.insert(ball) }
            if case .pocket(let ball, let pocketID) = event {
                var cushions: [Int] = [], collisions = 0
                for earlier in e.resolvedEvents.prefix(index) {
                    switch earlier {
                    case .ballCushion(let b, let c, _) where b == ball: cushions.append(c)
                    case .ballBall(let a, let b) where a == ball || b == ball: collisions += 1
                    default: break
                    }
                }
                var path: [String: Any] = ["ball": ball, "slot": r.balls.firstIndex(where: { $0.key == ball }) ?? -1,
                    "pocket": pocketID, "time": e.resolvedEventTimes[index], "cushions": cushions,
                    "ballContacts": collisions]
                if let entry = rec.pocketEntries.last(where: { $0.ball.name == ball }) {
                    path["entrySpeed"] = lengthXZ(entry.ball.velocity)
                    path["entryVelocity"] = vector(entry.ball.velocity)
                    path["entrySource"] = String(describing: entry.source)
                }
                paths.append(path)
            }
        }
        row["objectBanks"] = banks.count
        row["pocketPaths"] = paths
        if job.trace {
            row["eventTimeline"] = e.resolvedEvents.enumerated().map { index, event -> [String: Any] in
                var entry: [String: Any] = ["time": e.resolvedEventTimes[index]]
                func slot(_ name: String) -> Int { r.balls.firstIndex(where: { $0.key == name }) ?? -1 }
                switch event {
                case .ballBall(let a, let b): entry["kind"] = "ballBall"; entry["slots"] = [slot(a),slot(b)].sorted()
                case .ballCushion(let b, let c, _): entry["kind"] = "cushion"; entry["slot"] = slot(b); entry["cushion"] = c
                case .pocket(let b, let p): entry["kind"] = "pocket"; entry["slot"] = slot(b); entry["pocket"] = p
                case .transition(let b, let from, let to): entry["kind"] = "transition"; entry["slot"] = slot(b)
                    entry["from"] = from.rawValue; entry["to"] = to.rawValue
                }
                return entry
            }
            row["rackPositions"] = r.balls.map { vector($0.position) }
            row["trajectories"] = ([cue] + r.balls.map(\.key)).map { key -> [String: Any] in
                let frames = rec.framesByBallName[key] ?? []
                let stride = max(1, frames.count / 180)
                let sampled = frames.enumerated().filter { $0.element.time < 0.3 || $0.offset % stride == 0 || $0.offset == frames.count - 1 }
                return ["ball": key, "slot": r.balls.firstIndex(where: { $0.key == key }) ?? -1,
                    "frames": sampled.map { [$0.element.time, $0.element.position.x, $0.element.position.z] }]
            }
        }
        return row
    }

    func test_preflightGeometryStateAndProductionParity() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: configurationPath))
        let jobs = try JSONDecoder().decode(Batch.self, from: data).jobs
        var invalid = 0, accepted = 0
        for job in jobs {
            let r = rack(job)
            do {
                let start = try input(job, rack: r)
                accepted += 1
                XCTAssertGreaterThanOrEqual(start.position.x, TablePhysics.innerLength / 4)
                XCTAssertLessThan(abs(start.position.z) + BallPhysics.radius, TablePhysics.innerWidth / 2)
                for i in r.balls.indices {
                    for j in r.balls.indices where j > i {
                        XCTAssertGreaterThanOrEqual((r.balls[i].position - r.balls[j].position).length(),
                            2 * BallPhysics.radius - 0.0000005)
                    }
                }
            } catch { invalid += 1 }
        }
        try emit(["kind": "geometry", "accepted": accepted, "invalid": invalid, "requested": jobs.count])
        XCTAssertGreaterThan(accepted, 0)
        let representatives = jobs.filter { abs($0.theta) <= 16 && abs($0.fraction) <= 0.3 }
        for job in representatives.enumerated().filter({ $0.offset % 101 == 0 }).map(\.element) {
            let r = rack(job), start = try input(job, rack: rack(job))
            let row = try run(job)
            try emit(row)
            XCTAssertEqual(row["contactValid"] as? Bool, true)
            XCTAssertEqual(row["settled"] as? Bool, true)
            let production = BreakSimulator.breakShot(rack: r, cuePosition: start.position,
                aimDirection: start.direction, power: start.power, spinX: start.spinX, spinY: start.spinY)
            XCTAssertTrue(production.settled)
            XCTAssertEqual(production.cueScratched, row["scratch"] as? Bool)
            XCTAssertEqual(production.eightOnBreak, row["eight"] as? Bool)
            XCTAssertEqual(production.pocketed.filter { $0 != cue && $0 != "_8" }.count, row["ordinaryPots"] as? Int)
            let final = try XCTUnwrap(row["finalBySlot"] as? [[Any]])
            for (slot, ball) in r.balls.enumerated() where !production.pocketed.contains(ball.key) {
                let point = try XCTUnwrap(production.board.onTable[ball.key])
                let expected = AngleSceneCalculator.sceneToNormalized(position:
                    SCNVector3(final[slot][0] as! Float, r.surfaceY + BallPhysics.radius, final[slot][1] as! Float))
                XCTAssertEqual(point.x, Double(expected.x), accuracy: 0.001)
                XCTAssertEqual(point.y, Double(expected.y), accuracy: 0.001)
            }
            try emit(["kind": "productionParity", "id": job.id, "settled": production.settled,
                "duration": production.recorder.duration])
        }
    }

    func test_exportNominalSearchControls() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: configurationPath))
        let jobs = try JSONDecoder().decode(Batch.self, from: data).jobs
        for job in jobs {
            do {
                XCTAssertEqual(job.rackKind, "nominal")
                let start = try input(job, rack: rack(job))
                try emit(["kind": "designControl", "id": job.id, "cueX": start.position.x,
                    "cueZ": start.position.z, "aimTheta": angle(start.direction),
                    "power": start.power, "spinX": start.spinX, "spinY": start.spinY,
                    "initialTheta": angle(start.velocity), "initialSpeed": lengthXZ(start.velocity),
                    "initialOmega": vector(start.omega), "targetSlot": job.targetSlot ?? 0,
                    "theta": job.theta, "fraction": job.fraction])
            } catch { try emit(["kind": "designRejected", "id": job.id, "reason": String(describing: error)]) }
        }
        try emit(["kind": "batchComplete", "requested": jobs.count])
    }

    func test_jointSearchProductionParity() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: configurationPath))
        let jobs = try JSONDecoder().decode(Batch.self, from: data).jobs
        XCTAssertFalse(jobs.isEmpty)
        for job in jobs {
            let r = rack(job), start = try input(job, rack: r)
            let row = try run(job)
            try emit(row)
            let actual = BreakSimulator.breakShot(rack: r, cuePosition: start.position,
                aimDirection: start.direction, power: start.power, spinX: start.spinX, spinY: start.spinY,
                maxTime: job.maxTime ?? 30)
            XCTAssertEqual(actual.settled, row["settled"] as? Bool)
            XCTAssertEqual(actual.cueScratched, row["scratch"] as? Bool)
            XCTAssertEqual(actual.eightOnBreak, row["eight"] as? Bool)
            XCTAssertEqual(actual.pocketed.filter { $0 != cue && $0 != "_8" }.count, row["ordinaryPots"] as? Int)
            XCTAssertEqual(actual.recorder.duration, row["duration"] as? Float)
        }
        try emit(["kind": "batchComplete", "requested": jobs.count])
    }

    func test_pairContactSymmetryAudit() throws {
        var maxVelocityDelta: Float = 0, maxSurfaceSpinDelta: Float = 0
        var count = 0
        for degrees in stride(from: -180, through: 180, by: 15) {
            let a = Float(degrees) * .pi / 180
            let normal = SCNVector3(cosf(a), 0, sinf(a))
            let tangent = SCNVector3(-sinf(a), 0, cosf(a))
            let pa = SCNVector3Zero, pb = normal * (2 * BallPhysics.radius)
            for speed: Float in [2, 6, 10] {
                for fraction: Float in [-0.4, 0, 0.4] {
                    for spin: Float in [-20, 0, 20] {
                        let va = normal * speed + tangent * (fraction * speed)
                        let vb = normal * (0.1 * speed)
                        let wa = SCNVector3(0, spin, 0), wb = tangent * (spin / 2)
                        let direct = CollisionResolver.resolveBallBallPure(posA: pa, posB: pb, velA: va, velB: vb,
                            angVelA: wa, angVelB: wb)
                        let swap = CollisionResolver.resolveBallBallPure(posA: pb, posB: pa, velA: vb, velB: va,
                            angVelA: wb, angVelB: wa)
                        maxVelocityDelta = max(maxVelocityDelta, (direct.velA - swap.velB).length(),
                            (direct.velB - swap.velA).length())
                        maxSurfaceSpinDelta = max(maxSurfaceSpinDelta,
                            BallPhysics.radius * (direct.angVelA - swap.angVelB).length(),
                            BallPhysics.radius * (direct.angVelB - swap.angVelA).length())
                        count += 1
                    }
                }
            }
        }
        try emit(["kind": "pairSymmetryAudit", "pairs": count,
            "maxVelocityDeltaMPS": maxVelocityDelta, "maxSurfaceSpinDeltaMPS": maxSurfaceSpinDelta])
        XCTAssertLessThan(maxVelocityDelta, 0.001)
        XCTAssertLessThan(maxSurfaceSpinDelta, 0.001)
    }

    func test_rackGapTriggerAudit() throws {
        executionTimeAllowance = 300
        let nominal = rack(Job(id: "gap-reference", rackKind: "nominal", seed: 0,
            theta: 0, fraction: 0, contactSpeed: 10))
        var edges: [(Int, Int)] = []
        for i in nominal.balls.indices {
            for j in nominal.balls.indices where j > i {
                if (nominal.balls[j].position - nominal.balls[i].position).length()
                    < 2 * BallPhysics.radius + RackLayout.gap + 0.000001 { edges.append((i,j)) }
            }
        }
        XCTAssertEqual(edges.count, 30)
        var count = 0, triggered = 0
        var minGap: Float = .greatestFiniteMagnitude, maxGap: Float = 0
        var gapSum: Double = 0, fractionSum: Double = 0, fractionSquares: Double = 0
        for seed: UInt64 in 200000..<210000 {
            let r = RackLayout.make(.chineseEightBall, seed: seed)
            var perRack = 0
            for (i,j) in edges {
                let delta = r.balls[j].position - r.balls[i].position
                let gap = delta.length() - 2 * BallPhysics.radius
                minGap = min(minGap,gap); maxGap = max(maxGap,gap); gapSum += Double(gap)
                let a = BallState(position: r.balls[i].position, velocity: delta.normalized() * 10,
                    angularVelocity: SCNVector3Zero, state: .sliding, name: "auditA")
                let b = BallState(position: r.balls[j].position, velocity: SCNVector3Zero,
                    angularVelocity: SCNVector3Zero, state: .stationary, name: "auditB")
                if EngineNumerics.isBallPairOverlappingOrTouching(a,b) { perRack += 1; triggered += 1 }
                count += 1
            }
            let f = Double(perRack) / Double(edges.count)
            fractionSum += f; fractionSquares += f*f
        }
        let n: Double = 10000, mean = fractionSum / n
        let variance = max(0, (fractionSquares - n*mean*mean)/(n-1))
        let half = 1.95996398454 * sqrt(variance/n)
        try emit(["kind": "rackGapAudit", "independentRacks": 10000, "edgesPerRack": edges.count,
            "pairs": count, "positiveGapImmediateTriggers": triggered,
            "minGapM": minGap, "maxGapM": maxGap, "meanGapM": gapSum/Double(count),
            "meanPerRackTriggeredFraction": mean, "rackClusterNormal95": [mean-half,mean+half],
            "scenario": "Each positive-gap neighbor independently assigned 10 m/s closing velocity; not an actual break event count"])
        XCTAssertGreaterThan(minGap, 0.000015)
        XCTAssertLessThan(maxGap, 0.000385)
        var examples: [[String: Any]] = []
        for gap: Float in [0.00002,0.00010,0.00020,0.00024,0.00026,0.00038] {
            let pa = SCNVector3Zero, pb = SCNVector3(2 * BallPhysics.radius + gap,0,0)
            let a = BallState(position: pa, velocity: SCNVector3(10,0,0), angularVelocity: SCNVector3Zero,
                state: .sliding, name: "auditA")
            let b = BallState(position: pb, velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero,
                state: .stationary, name: "auditB")
            let time = try XCTUnwrap(CollisionDetector.ballBallCollisionTime(p1: pa,p2: pb,
                v1: a.velocity,v2: b.velocity,a1: EngineNumerics.acceleration(for: a),
                a2: EngineNumerics.acceleration(for: b),R: Double(BallPhysics.radius),maxTime: 0.001))
            XCTAssertGreaterThan(time, 0)
            examples.append(["gapM": gap,"ccdTimeS": time,
                "immediatePredicate": EngineNumerics.isBallPairOverlappingOrTouching(a,b)])
            if gap == 0.00020 {
                XCTExpectFailure("Known production defect: positive 0.20 mm gap is treated as immediate contact") {
                    XCTAssertFalse(EngineNumerics.isBallPairOverlappingOrTouching(a,b),
                        "Separated approaching balls must reach geometric contact before impulse resolution")
                }
            }
        }
        try emit(["kind": "gapPredicateExamples", "pairs": examples])
    }

    private func parallelRows(_ jobs: [Job]) throws -> [[String: Any]] {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        let lock = NSLock()
        var result = Array<[String: Any]?>(repeating: nil, count: jobs.count)
        var failure: Error?
        for (index, job) in jobs.enumerated() {
            queue.addOperation {
                do {
                    let row = try autoreleasepool { try self.run(job) }
                    lock.lock(); result[index] = row; lock.unlock()
                } catch {
                    lock.lock(); if failure == nil { failure = error }; lock.unlock()
                }
            }
        }
        queue.waitUntilAllOperationsAreFinished()
        if let failure { throw failure }
        return try result.map { try XCTUnwrap($0) }
    }

    func test_jointParallelCompatibility() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: configurationPath))
        let jobs = try JSONDecoder().decode(Batch.self, from: data).jobs
        XCTAssertFalse(jobs.isEmpty)
        let serial = try jobs.map { job in try autoreleasepool { try run(job) } }
        // Repeat independent-engine concurrency to catch shared-state effects.
        let keys = ["cuePosition", "initialVelocity", "initialOmega", "contact", "contactValid",
            "duration", "events", "termination", "settled", "ordinaryPots", "scratch", "eight",
            "effectivePot", "pocketedSlots", "finalBySlot", "cueFinal", "objectBanks", "pocketPaths"]
        for repetition in 0..<3 {
            let concurrent = try parallelRows(jobs)
            for (index, pair) in zip(serial, concurrent).enumerated() {
                let left = pair.0.filter { keys.contains($0.key) }
                let right = pair.1.filter { keys.contains($0.key) }
                let a = try JSONSerialization.data(withJSONObject: left, options: [.sortedKeys])
                let b = try JSONSerialization.data(withJSONObject: right, options: [.sortedKeys])
                XCTAssertEqual(a, b, "Parallel mismatch at job \(jobs[index].id), repetition \(repetition)")
            }
        }
        try emit(["kind": "parallelCompatibility", "controls": jobs.count,
            "repetitions": 3, "maxConcurrentCases": 3, "exactStateAndEventComparison": true])
        try emit(["kind": "batchComplete", "requested": jobs.count])
    }

    func test_runConfiguredBatch() throws {
        executionTimeAllowance = 1800
        let data = try Data(contentsOf: URL(fileURLWithPath: configurationPath))
        let jobs = try JSONDecoder().decode(Batch.self, from: data).jobs
        XCTAssertFalse(jobs.isEmpty)
        let results = try parallelRows(jobs)
        for (index, row) in results.enumerated() {
            try emit(row)
            if index % 50 == 0 { print("[BREAK-RESEARCH-PROGRESS] \(index + 1)/\(jobs.count)") }
        }
        try emit(["kind": "batchComplete", "requested": jobs.count])
    }
}
