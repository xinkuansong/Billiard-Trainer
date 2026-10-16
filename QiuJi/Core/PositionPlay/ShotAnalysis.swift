import Foundation
import SceneKit

/// Optional teaching facts. Never consulted by aim solving or sequence replay.
struct ShotAnalysis: Codable, Equatable {
    var schemaVersion: Int = 1
    /// Identifies the audited physics snapshot; see SHOT-ANALYSIS-20261015.md.
    var engineVersion: String = "qiuji-planar-reference-20261015"
    var aim: AimGeometry?
    var noAimReason: String?
    var firstContact: FirstContact?
    var noContactReason: String?
    var cueCushionContacts: [CushionContact]
    /// Integral of planar speed until rest or planar pocket entry, in metres.
    var cueTravelDistanceMeters: Double

    struct Vector: Codable, Equatable {
        var x: Double
        var y: Double
        var z: Double
        init(_ v: SCNVector3) { x = Double(v.x); y = Double(v.y); z = Double(v.z) }
    }
    struct AimGeometry: Codable, Equatable {
        var aimAngleDegrees: Double
        var targetBallKey: String
        var pocket: String
        var pocketAimPointMeters: Vector
        var ghostCenterMeters: Vector
    }
    struct FirstContact: Codable, Equatable {
        var ballKey: String
        var timeSeconds: Double
        /// Incoming cue velocity vs cue-to-object contact normal, in the XZ plane.
        var actualCutAngleDegrees: Double?
        var undefinedAngleReason: String?
        var cueSpeedMetersPerSecond: Double
        var cueVelocity: Vector
        var cueAngularVelocityRadiansPerSecond: Vector
        var cueMotionState: String
        var cueClothSlipSpeedMetersPerSecond: Double
        /// Positive = forward roll, negative = backspin. Nil when horizontal speed is zero.
        var cueForwardRollRatio: Double?
    }
    struct CushionContact: Codable, Equatable {
        var timeSeconds: Double
        var cushionIndex: Int
        /// negativeX / positiveX / negativeZ / positiveZ, independent of camera orientation.
        /// Nil identifies a jaw or another non-main-rail cushion.
        var mainRail: String?
        /// beforeFirstContact / afterFirstContact / noBallContact; equal times use event order.
        var phase: String
    }

    static func make(prediction: ShotPrediction, shot: PlannedShot, before: BoardSnapshot,
                     surfaceY: Float = BTTablePhysics.surfaceY) -> ShotAnalysis? {
        guard prediction.hasFinalTableState, let recorder = prediction.recorder, recorder.hasPlanarAnalysisFacts,
              let frames = recorder.framesByBallName[ShotInput.cueBallName], !frames.isEmpty else { return nil }
        let impact = recorder.firstBallContacts[ShotInput.cueBallName]
        let firstContact = impact.map { snapshot -> FirstContact in
            let cue = snapshot.incoming, object = snapshot.other
            let velocity = cue.velocity
            let speed = hypot(Double(velocity.x), Double(velocity.z))
            let delta = object.position - cue.position
            let norm = hypot(Double(delta.x), Double(delta.z))
            let angle: Double? = speed > 0 && norm > 0
                ? acos(max(-1, min(1, (Double(velocity.x)*Double(delta.x) + Double(velocity.z)*Double(delta.z))/(speed*norm)))) * 180 / .pi : nil
            let slip = AnalyticalMotion.surfaceVelocity(linear: velocity, angular: cue.angularVelocity, radius: BallPhysics.radius)
            let rollRatio: Double? = speed > 0
                ? (Double(cue.angularVelocity.x)*Double(velocity.z) - Double(cue.angularVelocity.z)*Double(velocity.x)) * Double(BallPhysics.radius)/(speed*speed) : nil
            let key = !shot.isFree && object.name == ShotInput.targetBallName ? shot.targetKey : object.name
            return FirstContact(ballKey: key, timeSeconds: Double(snapshot.time),
                actualCutAngleDegrees: angle, undefinedAngleReason: angle == nil ? "zeroIncomingSpeedOrContactNormal" : nil,
                cueSpeedMetersPerSecond: speed, cueVelocity: Vector(velocity),
                cueAngularVelocityRadiansPerSecond: Vector(cue.angularVelocity), cueMotionState: cue.state.rawValue,
                cueClothSlipSpeedMetersPerSecond: hypot(Double(slip.x), Double(slip.z)), cueForwardRollRatio: rollRatio)
        }
        var passedFirst = false
        var contacts: [CushionContact] = []
        for event in prediction.events {
            if case let .ballBall(a, b) = event.kind,
               (a == ShotInput.cueBallName || b == ShotInput.cueBallName),
               let impact, event.time == impact.time { passedFirst = true }
            guard case let .ballCushion(ball) = event.kind, ball == ShotInput.cueBallName,
                  let index = event.cushionIndex else { continue }
            let rail: String?
            if (0..<6).contains(index), let n = event.contactNormal {
                if n.x > 0.9 { rail = "negativeX" }
                else if n.x < -0.9 { rail = "positiveX" }
                else if n.z > 0.9 { rail = "negativeZ" }
                else if n.z < -0.9 { rail = "positiveZ" }
                else { rail = nil }
            } else { rail = nil }
            contacts.append(CushionContact(timeSeconds: Double(event.time), cushionIndex: index, mainRail: rail,
                phase: impact == nil ? "noBallContact" : (passedFirst ? "afterFirstContact" : "beforeFirstContact")))
        }
        let aim = aimGeometry(before: before, shot: shot, surfaceY: surfaceY)
        return ShotAnalysis(aim: aim, noAimReason: aim == nil ? (shot.isFree ? "freeAimHasNoPocketLine" : "missingOrDegenerateAimGeometry") : nil,
            firstContact: firstContact, noContactReason: impact == nil ? "noCueBallCollision" : nil,
            cueCushionContacts: contacts, cueTravelDistanceMeters: travelDistance(frames: frames, recorder: recorder))
    }

    /// Geometric aim angle before compensation: same pocket-pipe helper as prepareAim.
    /// Do not use prediction.ghost: buildPrediction replaces it with the compensated ray contact.
    static func aimGeometry(before: BoardSnapshot, shot: PlannedShot, surfaceY: Float) -> AimGeometry? {
        guard !shot.isFree, let cuePoint = before.onTable[PositionPlayBall.cueKey],
              let objectPoint = before.onTable[shot.targetKey],
              let pocketIndex = ShotIntent.pocketIndex(for: shot.pocket) else { return nil }
        let cue = PositionPlayShotSolver.scenePoint(cuePoint, surfaceY: surfaceY)
        let object = PositionPlayShotSolver.scenePoint(objectPoint, surfaceY: surfaceY)
        let pocket = AngleSceneCalculator.effectivePocketAimPoint(targetBall: object, pocketIndex: pocketIndex, surfaceY: surfaceY)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: object, pocket: pocket, ballRadius: BallPhysics.radius)
        let aim = ghost - cue, line = pocket - object
        let scale = hypot(Double(aim.x),Double(aim.z)) * hypot(Double(line.x),Double(line.z))
        guard scale > 0 else { return nil }
        let cosine = (Double(aim.x)*Double(line.x) + Double(aim.z)*Double(line.z))/scale
        let degrees = acos(max(-1,min(1,cosine))) * 180 / .pi
        return AimGeometry(aimAngleDegrees:degrees,targetBallKey:shot.targetKey,pocket:shot.pocket,
                           pocketAimPointMeters:Vector(pocket),ghostCenterMeters:Vector(ghost))
    }

    /// Integrate speed within the engine's contact-free intervals, excluding separation
    /// corrections and the pocket snap. Eight-point Gauss-Legendre quadrature in Double;
    /// velocity evaluation uses the very same analytical equations as playback.
    static func travelDistance(frames: [BallFrame], recorder: TrajectoryRecorder) -> Double {
        guard let last = frames.last else { return 0 }
        let end = recorder.pocketEntries.first(where: { $0.ball.name == ShotInput.cueBallName })?.time ?? last.time
        let nodes: [Double] = [-0.9602898564975363,-0.7966664774136267,-0.5255324099163290,-0.1834346424956498,
                               0.1834346424956498,0.5255324099163290,0.7966664774136267,0.9602898564975363]
        let weights: [Double] = [0.1012285362903763,0.2223810344533745,0.3137066458778873,0.3626837833783620,
                                 0.3626837833783620,0.3137066458778873,0.2223810344533745,0.1012285362903763]
        var distance = 0.0
        for (a, b) in zip(frames, frames.dropFirst()) {
            let dt = min(b.time, end) - a.time
            guard dt > 0, a.state == .sliding || a.state == .rolling else { continue }
            let omega = SCNVector3(a.angularVelocity.x, a.angularVelocity.y, a.angularVelocity.z)
            for (node, weight) in zip(nodes, weights) {
                let t = Float((node + 1) * Double(dt) / 2)
                let v: SCNVector3
                if a.state == .sliding {
                    v = AnalyticalMotion.evolveSliding(position: a.position, velocity: a.velocity, angularVelocity: omega, dt: t).velocity
                } else {
                    v = AnalyticalMotion.evolveRolling(position: a.position, velocity: a.velocity, angularVelocity: omega, dt: t).velocity
                }
                distance += weight * Double(dt) / 2 * hypot(Double(v.x), Double(v.z))
            }
        }
        return distance
    }
}
