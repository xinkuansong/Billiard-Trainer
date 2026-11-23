import CoreGraphics
import Foundation
import SceneKit

/// Shared `AimCloseupSnapshot` builders for the aim closeup loupe (问题集合 v23 W3).
///
/// **Coordinate contract**: planar points in one consistent system
/// (SceneKit XZ → `CGPoint(x: X, y: Z)`), meters. Same contract as
/// `AimProximityMath` / `AimCloseupCoords.mapRotated`.
///
/// Pages retain their own shot/answer layers. Every loupe adds the same
/// answer-independent center line, 2R ring and center-line normal (DR-439 r14).
enum AimCloseupBuilder {

    /// Framing tightness: `halfWorld = 3.2R` ⇒ object ball ≈ 1/3 of the loupe.
    static let halfWorldMultiple: CGFloat = 3.2

    struct Ball: Equatable {
        var pos: CGPoint
        /// Ball number for `BTFigureBall` fidelity; nil = plain white.
        var number: Int?

        init(pos: CGPoint, number: Int? = nil) {
            self.pos = pos
            self.number = number
        }
    }

    struct Result: Equatable {
        var snapshot: AimCloseupSnapshot?
        /// Feed back into `previouslyNear` next tick (enter 3R / exit 3.5R hysteresis).
        var isNear: Bool
    }

    /// Assessment-safe magnification of the existing direction line and balls only.
    /// No pocket/answer/solver input is accepted, and no predicted contact layers are built.
    static func currentAim(cue: CGPoint, direction: CGPoint, target: CGPoint, number: Int?,
                           ballRadius r: CGFloat, railEnd: CGPoint, previouslyNear: Bool) -> Result {
        let sample = AimProximityMath.advance(cue: cue, direction: direction, target: target,
            ballRadius: r, previouslyNear: previouslyNear)
        guard sample.isNear else { return Result(snapshot: nil, isNear: false) }
        let line = AimLineGeometry.resolve(cue: cue, dir: direction, target: target,
            ballRadius: r, railEnd: railEnd)
        let halfWorld = r * halfWorldMultiple
        return Result(snapshot: AimCloseupSnapshot(band: sample.band, focus: target,
            ballRadius: r, halfWorld: halfWorld, targetBallNumber: number,
            cue: hypot(cue.x - target.x, cue.y - target.y) < halfWorld * 1.35 ? cue : nil,
            aimLine: .init(start: cue, end: line.lineEnd),
            usesTrainingAssistStyle: true).withCenterReferences(cue: cue), isNear: true)
    }

    /// A solved contact already drawn by the main scene. XZ metres, no new
    /// pocket or ideal-direction layer; reject non-tangent/stale scene data.
    static func solvedContact(cue: CGPoint, target: CGPoint, ghost: CGPoint,
                              number: Int?, ballRadius r: CGFloat, incoming: AimCloseupSegment? = nil) -> AimCloseupSnapshot? {
        let distance = hypot(target.x - ghost.x, target.y - ghost.y)
        guard distance.isFinite, abs(distance - 2 * r) < 0.0001 else { return nil }
        let contact = CGPoint(x: (target.x + ghost.x) / 2, y: (target.y + ghost.y) / 2)
        return AimCloseupSnapshot(band: .contact, focus: target, ballRadius: r,
            halfWorld: r * halfWorldMultiple, targetBallNumber: number,
            aimLine: incoming ?? .init(start: cue, end: ghost), ghost: ghost,
            ghostShowsAimPoint: false, contactMarker: contact).withCenterReferences(cue: cue)
    }

    /// Free-aim closeup: focus = first ball the aim corridor hits; if none is hit,
    /// the nearest **near-band** ball being skimmed (offset < 3R/3.5R) is framed and
    /// captioned 「打空」. `railEnd` = aim line end when nothing is contacted.
    ///
    /// Returns `snapshot == nil` when no ball is in the near band (caller hides HUD).
    static func freeAim(
        cue: CGPoint,
        direction: CGPoint,
        balls: [Ball],
        ballRadius r: CGFloat,
        railEnd: CGPoint,
        halfLength: CGFloat,
        halfWidth: CGFloat,
        previouslyNear: Bool
    ) -> Result {
        struct Candidate {
            var ball: Ball
            var sample: AimProximityMath.Sample
            var ghost: CGPoint?
            /// Distance cue → ghost (contact order along the ray).
            var travel: CGFloat
        }

        let candidates: [Candidate] = balls.compactMap { ball in
            let sample = AimProximityMath.advance(
                cue: cue, direction: direction, target: ball.pos,
                ballRadius: r, previouslyNear: previouslyNear)
            guard sample.isNear else { return nil }
            let ghost = AimProximityMath.userGhost(
                cue: cue, direction: direction, target: ball.pos, ballRadius: r)
            let travel = ghost.map { hypot($0.x - cue.x, $0.y - cue.y) }
                ?? .greatestFiniteMagnitude
            return Candidate(ball: ball, sample: sample, ghost: ghost, travel: travel)
        }

        // 首碰优先（沿射线最先被碰到的那颗），其次擦身带里垂距最小的一颗；
        // 不叠多个 HUD（E1）。
        let picked = candidates.min { a, b in
            let aContact = a.ghost != nil, bContact = b.ghost != nil
            if aContact != bContact { return aContact }
            return aContact ? a.travel < b.travel : a.sample.offset < b.sample.offset
        }
        guard let picked else { return Result(snapshot: nil, isNear: false) }

        let focus = picked.ball.pos
        let lineEnd = picked.ghost ?? railEnd
        let contactMarker = picked.ghost.flatMap { ghost -> CGPoint? in
            let dx = focus.x - ghost.x, dy = focus.y - ghost.y
            let len = hypot(dx, dy)
            guard len > 1e-5 else { return nil }
            return CGPoint(x: ghost.x + dx / len * r, y: ghost.y + dy / len * r)
        }
        let halfWorld = r * halfWorldMultiple
        let cueInFrame = hypot(cue.x - focus.x, cue.y - focus.y) < halfWorld * 1.35

        var snapshot = AimCloseupSnapshot(
            band: picked.sample.band,
            focus: focus,
            ballRadius: r,
            halfWorld: halfWorld,
            showsTargetBall: true,
            targetBallNumber: picked.ball.number,
            cue: cueInFrame ? cue : nil,
            aimLine: AimCloseupSegment(start: cue, end: lineEnd),
            potLine: nil,
            auxLine: nil,
            ghost: picked.ghost,
            // 场景里假想球是一颗整球圈 + 独立接触点，不带瞄准点十字 ⇒ HUD 同步。
            ghostShowsAimPoint: false,
            aimPointMarker: nil,
            contactMarker: contactMarker,
            showMissCaption: picked.sample.band == .skim,
            focusNorm: AimCloseupPlacement.focusNormInRotatedTopDown(
                worldXZ: focus, halfLength: halfLength, halfWidth: halfWidth)
        )
        snapshot.idealLine = picked.ghost.flatMap { IdealObjectDirection.preview(target: focus, ghost: $0)?.line }
        return Result(snapshot: snapshot.withCenterReferences(cue: cue), isNear: true)
    }
}

extension AimCloseupSnapshot {
    /// XZ metres. Only actual centers enter this reference frame; aim/ghost/pocket do not.
    func withCenterReferences(cue: CGPoint) -> Self {
        var result = self
        let dx = focus.x - cue.x, dz = focus.y - cue.y
        let distance = hypot(dx, dz)
        guard showsTargetBall, distance.isFinite, distance > 1e-9 else { return result }
        let nx = -dz / distance, nz = dx / distance
        result.centerReferenceLine = .init(start: cue, end: focus)
        result.targetReferenceRadius = 2 * ballRadius
        result.auxLine = .init(
            start: CGPoint(x: focus.x - nx * halfWorld, y: focus.y - nz * halfWorld),
            end: CGPoint(x: focus.x + nx * halfWorld, y: focus.y + nz * halfWorld))
        return result
    }
}

/// A geometric initial object-ball direction, independent of power/spin and of
/// the full shot solver. SceneKit XZ meters, finite-radius ball, no rebounds.
enum IdealObjectDirection {
    static let color = UIColor(white: 0.78, alpha: 1)
    enum Termination: Equatable { case cushion, pocket(String) }
    struct Preview: Equatable {
        var line: AimCloseupSegment
        var termination: Termination
    }
    // The same production geometry factory as ShotPredictor. Y is irrelevant
    // to XZ ray queries; keep a single immutable table rather than rebuilding on drag.
    private static let table = TableGeometry.chineseEightBallQiuJi(surfaceY: 0)

    static func preview(target: CGPoint, ghost: CGPoint) -> Preview? {
        let dx = target.x - ghost.x, dz = target.y - ghost.y
        let length = hypot(dx, dz)
        guard length.isFinite, length > 1e-8 else { return nil }
        let p = SCNVector3(Float(target.x), 0, Float(target.y))
        let v = SCNVector3(Float(dx / length), 0, Float(dz / length))
        let r = BallPhysics.radius
        let limit = Double(hypot(AngleSceneCalculator.innerLength, AngleSceneCalculator.innerWidth) * 2)
        var nearest = Float(limit)
        var termination: Termination?
        func consider(_ distance: Float, _ kind: Termination) {
            guard distance.isFinite, distance >= 0, distance <= nearest else { return }
            nearest = distance
            termination = kind
        }
        for segment in table.linearCushions {
            let gap = (p - segment.start).dot(segment.normal) - r
            let approach = v.dot(segment.normal)
            let time: Float?
            if abs(gap) < 1e-6 && approach < -1e-6 {
                time = 0
            } else {
                time = CollisionDetector.ballLinearCushionTime(
                    p: p, v: v, a: SCNVector3Zero, lineNormal: segment.normal,
                    lineOffset: Double(segment.normal.dot(segment.start)), R: Double(r), maxTime: limit)
            }
            if let time, EngineNumerics.isWithinLinearCushionSegment(point: p + v * time, segment: segment) {
                consider(time, .cushion)
            }
        }
        for arc in table.circularCushions {
            let delta = p - arc.center
            let distance = hypotf(delta.x, delta.z)
            if abs(distance - arc.radius - r) < 1e-6,
               delta.dot(v) < 0, arc.isAngleInRange(arc.angle(to: p)) {
                consider(0, .cushion)
            } else if let time = CollisionDetector.ballCircularCushionTime(
                p: p, v: v, a: SCNVector3Zero, arc: arc, R: r, maxTime: limit, pockets: table.pockets) {
                consider(time, .cushion)
            }
        }
        // Ball center entering the physical hole circle is the engine's pocket
        // criterion. Unit-speed ray reduces its zero-acceleration equation to a quadratic.
        for pocket in table.pockets {
            let offset = p - pocket.center
            let b = offset.x * v.x + offset.z * v.z
            let c = offset.x * offset.x + offset.z * offset.z - pocket.radius * pocket.radius
            if c <= 0 { consider(0, .pocket(pocket.id)); continue }
            let discriminant = b * b - c
            if discriminant >= 0 { consider(-b - sqrtf(discriminant), .pocket(pocket.id)) }
        }
        guard let termination else { return nil }
        let end = p + v * nearest
        let start = p + v * min(r, nearest)
        return Preview(line: .init(start: CGPoint(x: CGFloat(start.x), y: CGFloat(start.z)),
                                   end: CGPoint(x: CGFloat(end.x), y: CGFloat(end.z))), termination: termination)
    }
}

/// Uses the displayed prediction polyline, including the post-contact cue leg.
enum DailyCloseupTrajectory {
    static func protectedCuePath(_ prediction: ShotPrediction, detail: TrajectoryDetail) -> [SCNVector3] {
        let points = prediction.cuePath
        guard points.count > 1 else { return points }
        var last = points.count - 1
        func closestIndex(to point: SCNVector3) -> Int {
            points.indices.min { (points[$0]-point).length() < (points[$1]-point).length() } ?? last
        }
        if let event = prediction.events.first(where: {
            if case .ballCushion(let ball) = $0.kind { return ball == ShotInput.cueBallName }
            return false
        }), let frames = prediction.recorder?.framesByBallName[ShotInput.cueBallName],
           let impact = frames.min(by: { abs($0.time-event.time) < abs($1.time-event.time) }) {
            // Include the next display sample conservatively: simplified render paths
            // need not contain the exact collision timestamp.
            last = min(last, closestIndex(to: impact.position) + 1)
        }
        if detail == .minimal, let contact = prediction.firstContact {
            last = min(last, closestIndex(to: contact))
        }
        return Array(points.prefix(last + 1))
    }
}
