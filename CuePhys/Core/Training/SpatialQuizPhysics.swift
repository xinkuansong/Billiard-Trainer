import SceneKit
import simd

/// One explicit production entry for player attempts and reference reconstruction.
/// World X/Z are horizontal, Y is up, lengths are metres; elevation is in degrees at input.
enum SpatialQuizPhysics {
    struct Input: Codable, Equatable {
        var yaw: Double
        var speed: Double
        var spinX: Double
        var spinY: Double
        var elevation: Double
        var preferredElevation: Double? = nil
        var valid: Bool {
            [yaw, speed, spinX, spinY, elevation].allSatisfy(\.isFinite) &&
            (preferredElevation.map { $0.isFinite && (0...75).contains($0) } ?? true) &&
            (0.1...8).contains(speed) && (0...75).contains(elevation) &&
            spinX * spinX + spinY * spinY <= 0.64 + 1e-8
        }
        var aim: SCNVector3 { SCNVector3(Float(cos(yaw)), 0, Float(sin(yaw))) }
        var radians: Float { Float(elevation * .pi / 180) }
    }
    struct Board {
        let cue: SCNVector3
        let target: SCNVector3
        let obstacle: SCNVector3
        let targetNumber: Int
        var mode: SpatialQuizMode? = nil
        var targetName: String { "_\(targetNumber)" }
        var roles: [String: SpatialQuizFacts.Role] {
            [ShotInput.cueBallName: .cue, targetName: .target, "_8": .obstacle]
        }
        var valid: Bool {
            guard (1...15).contains(targetNumber), targetNumber != 8 else { return false }
            let positions = [cue, target, obstacle]
            guard positions.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite && SpatialPracticeGeometry.isOnBed($0) }) else { return false }
            for i in positions.indices {
                for j in positions.indices where j > i {
                    let a = positions[i], b = positions[j]
                    let d = SIMD3(a.x - b.x, a.y - b.y, a.z - b.z)
                    if simd_length(d) < 2 * BallPhysics.radius { return false }
                }
            }
            return true
        }
    }
    struct Result {
        let prediction: ShotPrediction
        let facts: SpatialQuizFacts
        var outcome: SpatialQuizJudgement.Outcome { SpatialQuizJudgement.evaluate(facts) }
    }
    static func solve(board: Board, input: Input, cancellation: PredictionCancellation? = nil,
                      maxEvents: Int = 3000, maxTime: Float = 40) -> Result {
        guard board.valid, input.valid else {
            return .init(prediction: .init(), facts: .init(complete: false, duration: 0,
                events: [], issues: ["invalidBoardOrInput"]))
        }
        let prediction = ShotPredictor.simulateFree(cueBall: board.cue, aimDir: input.aim,
            velocity: Float(input.speed), spinX: Float(input.spinX), spinY: Float(input.spinY),
            surfaceY: BTTablePhysics.surfaceY,
            balls: [.init(name: board.targetName, position: board.target), .init(name: "_8", position: board.obstacle)],
            maxEvents: maxEvents, maxTime: maxTime, simulationModel: .spatialPractice,
            cancellation: cancellation, elevation: input.radians,
            initialSpatialPositions: [ShotInput.cueBallName: board.cue, board.targetName: board.target, "_8": board.obstacle],
            buildPolylines: false)
        return .init(prediction: prediction, facts: facts(prediction, board: board, initiallyPlanar: input.radians == 0))
    }

    /// Read-only adapter. Static contacts are scored from physical surface roles and the
    /// incoming interval; ShotEvent's approximate rail index is retained only as a source ID.
    static func facts(_ prediction: ShotPrediction, board: Board, initiallyPlanar: Bool = false) -> SpatialQuizFacts {
        var events: [SpatialQuizFacts.Event] = [], issues: [String] = []
        var technique: SpatialQuizFacts.Technique?
        func result() -> SpatialQuizFacts {
            .init(complete: prediction.hasFinalTableState, duration: Double(prediction.duration), events: events, issues: issues, mode: board.mode, technique: technique)
        }
        guard board.valid else { issues.append("invalidBoard"); return result() }
        guard prediction.hasFinalTableState else { issues.append("termination:\(String(describing: prediction.termination))"); return result() }
        guard let recorder = prediction.recorder else { issues.append("missingRecorder"); return result() }
        let roles = board.roles
        func role(_ name: String) -> SpatialQuizFacts.Role? {
            guard let value = roles[name] else { issues.append("unknownBall:\(name)"); return nil }
            return value
        }
        guard Set(prediction.finalPositions.keys) == Set(roles.keys),
              Set(recorder.framesByBallName.keys) == Set(roles.keys) else {
            issues.append("missingOrUnexpectedBallState"); return result()
        }
        guard initiallyPlanar || recorder.localIntervalsByBallName[ShotInput.cueBallName]?.isEmpty == false else {
            issues.append("missingSpatialCueTrace"); return result()
        }
        recorder.prepareLocalIntervalIndex()
        let geometry = TableGeometry.chineseEightBallCuePhys(surfaceY: BTTablePhysics.surfaceY)
        for (index, event) in prediction.events.enumerated() {
            let kind: SpatialQuizFacts.EventKind
            var source = "shotEvent:\(index)"
            switch event.kind {
            case let .ballBall(a, b):
                guard let a = role(a), let b = role(b) else { continue }; kind = .balls(a, b)
            case let .pocket(name, pocket):
                guard let r = role(name) else { continue }; kind = .pocket(r, id: pocket)
            case let .ballCushion(name):
                guard let r = role(name) else { continue }
                // The mixed spatial engine can return supported balls to planar ownership.
                // Mesh-projected events are consumed below; planar events require the exact
                // pre-impact fact recorded only after resolveCushionImpact actually applies.
                if recorder.localStaticContacts.contains(where: {
                    $0.ballName == name && Float($0.contact.time) == event.time
                }) { continue }
                guard let cushion = event.cushionIndex, cushion >= 0,
                      cushion < geometry.linearCushions.count + geometry.circularCushions.count,
                      let impact = recorder.contactSounds.first(where: {
                          $0.ball == name && $0.time == event.time && $0.other == "cushion_\(cushion)"
                      }), impact.approachSpeed.isFinite, impact.approachSpeed > 0 else {
                    issues.append("missingCushionSource:\(index)"); continue
                }
                let material = geometry.linearCushions.indices.contains(cushion)
                    ? geometry.linearCushions[cushion].soundSurface : .jaw
                source += ":cushion:\(cushion)"
                switch material {
                case .cushion, .jaw: kind = .surface(r, .cushion, approaching: true)
                case .liner: kind = .surface(r, .liner, approaching: true)
                default: issues.append("unknownCushionMaterial:\(cushion)"); continue
                }
            }
            events.append(.init(time: Double(event.time), kind: kind, source: source))
        }
        do {
            let asset = try PocketGeometryAsset.load()
            let surfaces = try asset.surfaceRoles()
            let exteriorCount = try SpatialPracticeGeometry.exteriorSurfaces().count
            for (index, event) in recorder.localStaticContacts.enumerated() {
                guard let r = role(event.ballName) else { continue }
                let contact = event.contact, surface: SpatialQuizFacts.Surface
                guard event.geometryID == "table-contact-geometry", contact.surface >= 0,
                      contact.surface < surfaces.count + exteriorCount,
                      [contact.normal.x, contact.normal.y, contact.normal.z].allSatisfy(\.isFinite),
                      simd_length_squared(contact.normal) > 0 else {
                    issues.append("invalidSurface:\(index)"); continue
                }
                if surfaces.indices.contains(contact.surface) {
                    switch surfaces[contact.surface] {
                    case .cushion: surface = .cushion
                    case .clothBed: surface = .cloth
                    case .leather: surface = .liner
                    }
                } else { surface = .exterior }
                var approaching = false
                if surface == .cushion, contact.time > 0 {
                    if let incoming = recorder.localInterval(ballName: event.ballName, time: contact.time, incoming: true)?
                        .sample(at: contact.time, beforeEndpoint: true) {
                        let speed = -simd_dot(incoming.velocity, contact.normal)
                        if speed.isFinite { approaching = speed > 0 }
                        else { issues.append("invalidContactSpeed:\(index)") }
                    } else { issues.append("missingIncomingContact:\(index)") }
                }
                events.append(.init(time: Double(Float(contact.time)), kind: .surface(r, surface, approaching: approaching),
                    source: "\(event.geometryID):\(contact.surface):\(index)", physicalTime: contact.time))
                if surface == .exterior {
                    events.append(.init(time: contact.time, kind: .outside(r), source: "exterior:\(index)"))
                }
            }
        } catch { issues.append("surfaceMapping:\(error)") }
        let pocketNames = Set(prediction.events.compactMap { event -> String? in
            if case let .pocket(name, _) = event.kind { return name }; return nil
        })
        if pocketNames != Set(prediction.pocketedBalls) { issues.append("inconsistentPocketFacts") }
        let captures = recorder.confirmedCaptures
        if Set(captures.map(\.ballName)) != pocketNames { issues.append("missingConfirmedCapture") }
        for capture in captures {
            if !prediction.events.contains(where: { event in
                if case let .pocket(name, pocket) = event.kind {
                    return name == capture.ballName && pocket == capture.pocketID &&
                        event.time == Float(capture.state.time)
                }
                return false
            }) { issues.append("captureEventMismatch:\(capture.ballName)") }
        }
        for (name, final) in prediction.finalPositions {
            guard let r = role(name) else { continue }
            guard final.x.isFinite, final.y.isFinite, final.z.isFinite else { issues.append("invalidFinalPosition:\(name)"); continue }
            if let exit = recorder.spatialDomainExits[name] {
                events.append(.init(time: exit.time, kind: .outside(r), source: "spatialDomainExit:\(name)"))
            } else if !pocketNames.contains(name), !SpatialPracticeGeometry.isOnBed(final) {
                events.append(.init(time: Double(prediction.duration), kind: .outside(r), source: "finalOffBed:\(name)"))
            }
        }
        if board.mode != nil,
           let first = events.compactMap({ event -> Double? in
               if case let .balls(a,b) = event.kind, Set([a,b]) == [.cue,.target] { return event.time }
               return nil
           }).min() {
            technique = SpatialQuizTechnique.measure(recorder: recorder, board: board,
                before: max(0,first-max(SpatialQuizJudgement.contactTimeGroup,Double(Float(first).ulp))),
                initiallyPlanar: initiallyPlanar)
        }
        return result()
    }
}

/// Measures accepted solver intervals, never display samples. World X/Z in metres,
/// Y up; board.cue.y is the resting ball CENTRE, not the cloth surface.
enum SpatialQuizTechnique {
    // Existing research admission uses 1 mm for cloth/curvature. Keep a meaningful
    // 1 mm obstruction margin too; do not classify Float noise as a technique.
    static let techniqueTolerance = 0.001
    typealias V = SIMD3<Double>
    static func vector(_ p: SCNVector3) -> V { V(Double(p.x),Double(p.y),Double(p.z)) }
    static func horizontal(_ p: V) -> V { V(p.x,0,p.z) }

    static func measure(recorder: TrajectoryRecorder, board: SpatialQuizPhysics.Board,
                        before time: Double, initiallyPlanar: Bool = false) -> SpatialQuizFacts.Technique? {
        let name = ShotInput.cueBallName
        var spans = recorder.localIntervalsByBallName[name] ?? []
        // The mixed engine returns supported motion to its existing planar solver.
        // Reconstruct those event intervals with that solver's acceleration; only
        // an explicit returned handoff permits this path. Never fill a spatial gap.
        let handoffs = recorder.localHandoffs.filter { $0.ballName == name }
        var frames: [BallFrame] = []
        for frame in recorder.framesByBallName[name] ?? [] {
            if frames.last?.time == frame.time { frames[frames.count-1] = frame }
            else { frames.append(frame) }
        }
        for (frame,next) in zip(frames,frames.dropFirst()) where Double(frame.time) < time {
            let owner = handoffs.last(where:{ Float($0.state.time) <= frame.time })
            guard next.time > frame.time,
                  owner.map({ $0.kind == .returned }) ?? initiallyPlanar,
                  !handoffs.contains(where:{ $0.kind == .entered &&
                      Float($0.state.time) > frame.time && Float($0.state.time) < next.time }),
                  frame.velocity.y == 0, abs(frame.position.y-board.cue.y) < 0.000001 else { continue }
            let ball = BallState(position:frame.position,velocity:frame.velocity,
                angularVelocity:SCNVector3(frame.angularVelocity.x,frame.angularVelocity.y,frame.angularVelocity.z),
                state:frame.state,name:name)
            let duration = Double(next.time)-Double(frame.time)
            let acceleration = vector(EngineNumerics.acceleration(for:ball))
            let start = LocalPocketSimulation.State(time:Double(frame.time),position:vector(frame.position),
                velocity:vector(frame.velocity),omega:vector(ball.angularVelocity))
            let end = LocalPocketSimulation.State(time:Double(next.time),
                position:start.position+start.velocity*duration+acceleration*(0.5*duration*duration),
                velocity:start.velocity+acceleration*duration,omega:start.omega)
            spans.append(.init(start:start,duration:duration,acceleration:acceleration,angularAcceleration:.zero,end:end))
        }
        spans.sort { $0.start.time < $1.start.time }
        return measure(intervals:spans,board:board,before:time)
    }
    static func measure(intervals: [LocalPocketSimulation.Interval], board: SpatialQuizPhysics.Board,
                        before time: Double) -> SpatialQuizFacts.Technique? {
        guard time > 0, time.isFinite else { return nil }
        let cue = vector(board.cue), obstacle = vector(board.obstacle)
        let axisDelta = horizontal(obstacle-cue)
        guard simd_length(axisDelta) > 0 else { return nil }
        let axis = simd_normalize(axisDelta)
        let spans = intervals.filter { $0.end.time > 0 && $0.start.time < time }
        guard !spans.isEmpty else { return nil }
        // Allow only Float/Double event-clock joins, never an unobserved trajectory.
        let clockTolerance = SpatialQuizJudgement.contactTimeGroup
        var covered = 0.0
        for span in spans {
            guard span.start.time <= covered + clockTolerance, span.end.time > span.start.time,
                  span.duration.isFinite, span.duration > 0,
                  [span.start.position,span.start.velocity,span.acceleration].allSatisfy({
                      $0.x.isFinite && $0.y.isFinite && $0.z.isFinite
                  }) else { return nil }
            covered = max(covered,span.end.time)
        }
        guard covered >= time-clockTolerance, let last = spans.last,
              let end = last.sample(at:min(time,last.end.time),beforeEndpoint:true) else { return nil }
        let chord = horizontal(end.position-cue), chordLength = simd_length(chord)
        guard chordLength > 0 else { return nil }
        let normal = V(-chord.z,0,chord.x)/chordLength
        let fraction = max(0,min(1,simd_dot(horizontal(obstacle-cue),chord)/(chordLength*chordLength)))
        let clearance = simd_length(horizontal(obstacle-cue)-chord*fraction)-2*Double(BallPhysics.radius)
        var lift = 0.0, deviation = 0.0, jumped = false
        for span in spans {
            let lo = max(0,span.start.time), hi = min(time,span.end.time)
            guard hi > lo, let start = span.sample(at:lo,beforeEndpoint:true) else { continue }
            let duration = hi-lo, a = span.acceleration, p = start.position, v = start.velocity
            func point(_ dt: Double) -> V { p + v*dt + a*(0.5*dt*dt) }
            // Quadratic extrema, including both endpoints: no frame-rate dependence.
            var heightTimes = [0.0,duration]
            if a.y != 0 { let t = -v.y/a.y; if t > 0 && t < duration { heightTimes.append(t) } }
            for t in heightTimes { lift = max(lift,point(t).y-cue.y) }
            var curveTimes = [0.0,duration]
            let bend = simd_dot(a,normal)
            if bend != 0 {
                let t = -simd_dot(v,normal)/bend
                if t > 0 && t < duration { curveTimes.append(t) }
            }
            for t in curveTimes { deviation = max(deviation,abs(simd_dot(point(t)-cue,normal))) }
            // Closest horizontal approach on each accepted quadratic interval.
            // A cue-to-obstacle centre plane is NOT perpendicular to an oblique
            // shot; using that plane's clearance wrongly rejects valid edge jumps.
            let r = horizontal(p-obstacle), hv = horizontal(v), ha = horizontal(a)
            let roots = QuarticSolver.boundedRealRoots(coefficients:[
                simd_dot(ha,ha),3*simd_dot(hv,ha),
                2*(simd_dot(hv,hv)+simd_dot(r,ha)),2*simd_dot(r,hv)],maxTime:duration)
            for t in [0.0,duration]+roots where t >= 0 && t <= duration {
                let crossing = point(t), projected = simd_length(horizontal(crossing-obstacle))
                if simd_dot(horizontal(end.position-obstacle),axis) > 0,
                   simd_dot(v+a*t,axis) > 0,
                   projected < 2*Double(BallPhysics.radius)-techniqueTolerance,
                   crossing.y-cue.y > techniqueTolerance,
                   simd_length(crossing-obstacle) >= 2*Double(BallPhysics.radius)-0.0000005 {
                    jumped = true
                }
            }
        }
        return .init(maximumLift:lift,chordDeviation:deviation,
                     chordObstacleClearance:clearance,jumpedOverObstacle:jumped)
    }
}
