import SceneKit

/// Pure geometry helpers for cue-stick / ball clearance (render layer only).
///
/// Coordinate contract (SceneKit world):
/// - Horizontal plane = X–Z, Y up; units metres.
/// - Cue pivot = strike point (cue-ball centre ± spin offset); local +z = back = −aim (flat).
/// - Tip at local z = `tipOffset + pullBack`; shaft extends +z by `shaftLength`.
/// - Elevation pivots about the strike point: euler (−elevation, yaw, 0).
enum CueClearance {

    static let tipRadius: Float = CuePhysics.tipContactRadius
    static let buttRadius: Float = 0.014
    static let shaftLength: Float = 1.45
    /// Tip standoff from pivot along local +z when `pullBack == 0`.
    /// Note: equals `R + 1mm` and does **not** include `tipRadius`. Rest contact therefore
    /// already violates `R + tipRadius + collisionMargin` — collision search uses a
    /// per-ball separation latch rather than widening this offset (render pivot unchanged).
    static var tipOffset: Float { AngleSceneCalculator.ballRadius + 0.001 }
    /// Conservative max backswing for occlusion span.
    /// Source: `CueStroke.basePullBack + pullBackPerSpeed · v` with v ≈ 2.9 m/s
    /// → 0.05 + 0.035·2.86 ≈ 0.15 m.
    static let maxPullBack: Float = 0.15
    /// Visual clearance added on top of R + shaft radius (m).
    static let ballClearance: Float = 0.002
    /// Contact margin for post-contact collision probe (m).
    static let collisionMargin: Float = 0.003
    /// Sample step for collision search (≈ 1/60 s).
    static let sampleDt: TimeInterval = 1.0 / 60.0
    /// Start retracting this long before predicted contact.
    static let retractLead: TimeInterval = 0.12
    /// Retract + fade duration.
    static let retractFade: TimeInterval = 0.18
    /// Extra pull-back applied during emergency retract (along back).
    static let retractPullExtra: Float = 0.25

    // MARK: - Shaft radius (cone)

    /// Cone radius at horizontal distance `s` along back from the pivot.
    /// Linear tip→butt over the conservative occupied span
    /// `[R, R + maxPullBack + length]` so backswing tip positions stay covered.
    static func shaftRadius(atDistanceAlongBack s: Float) -> Float {
        let r = AngleSceneCalculator.ballRadius
        let s0 = r
        let s1 = r + maxPullBack + shaftLength
        let u = max(0, min(1, (s - s0) / max(1e-6, s1 - s0)))
        return tipRadius + u * (buttRadius - tipRadius)
    }

    /// Cone radius along the shaft parameter from tip (0) to butt (1).
    static func shaftRadius(alongShaftU u: Float) -> Float {
        let t = max(0, min(1, u))
        return tipRadius + t * (buttRadius - tipRadius)
    }

    // MARK: - World segment

    /// World-space tip→butt segment for the cue at a given pullBack / elevation.
    static func shaftSegment(
        strikePosition: SCNVector3,
        aimDirection: SCNVector3,
        elevation: Float,
        pullBack: Float
    ) -> (tip: SCNVector3, butt: SCNVector3) {
        let aim = normalizeFlat(aimDirection)
        let back = SCNVector3(-aim.x, 0, -aim.z)
        let yaw = atan2f(back.x, back.z)
        let tipZ = tipOffset + pullBack
        let buttZ = tipZ + shaftLength
        return (
            worldPoint(localZ: tipZ, yaw: yaw, elevation: elevation, pivot: strikePosition),
            worldPoint(localZ: buttZ, yaw: yaw, elevation: elevation, pivot: strikePosition)
        )
    }

    /// Pull-back after contact: follow-through curve then hold at `endPull`.
    static func pullBackAfterContact(tau: TimeInterval, endPull: Float) -> Float {
        if tau <= CueStroke.followThroughDuration {
            return CueStroke.followThrough(at: tau, endPull: endPull)
        }
        return endPull
    }

    // MARK: - Collision search

    /// First post-contact time when any **previously separated** ball re-intersects the shaft.
    ///
    /// ## Separation latch (required — not a time/speed hack)
    /// At rest contact, `tipOffset = R+0.001` is already **inside** the collision threshold
    /// `R + tipRadius + margin` (tipOffset ignores tip radius). Soft shots keep tip≈ball for
    /// several samples after contact, so a naïve `dist < thresh` fires at τ≈1/60 and would
    /// skip the entire follow-through (violates D2).
    ///
    /// Fix: per-ball latch — a ball is a collision candidate only after it has been
    /// **outside** the threshold at least once. Cue ball rides the tip then draws back →
    /// separates then re-enters → captured. Object/third balls start outside → latch armed
    /// immediately → captured on first entry. No velocity or “skip N frames” special cases.
    ///
    /// - Parameter ballsAt: **all** ball centres keyed by stable id (cue + objects + colliders).
    /// - Returns: earliest `t*` or `nil` if none within the search window.
    static func firstCollisionTime(
        strikePosition: SCNVector3,
        aimDirection: SCNVector3,
        elevation: Float,
        endPull: Float,
        holdDuration: TimeInterval,
        ballsAt: (TimeInterval) -> [String: SCNVector3],
        sampleDt: TimeInterval = sampleDt,
        searchHorizon: TimeInterval? = nil
    ) -> TimeInterval? {
        let horizon = searchHorizon ?? (CueStroke.followThroughDuration + holdDuration)
        guard horizon > 0, sampleDt > 0 else { return nil }
        let r = AngleSceneCalculator.ballRadius
        // Integer index loop — avoid float-step while under/overflow (FL-024).
        // Skip i=0 (exact contact frame); latch handles the soft-shot tip-envelope after that.
        let steps = Int(ceil(horizon / sampleDt)) + 1
        var hasSeparated: Set<String> = []
        for i in 1...steps {
            let t = min(horizon, TimeInterval(i) * sampleDt)
            let pull = pullBackAfterContact(tau: t, endPull: endPull)
            let seg = shaftSegment(
                strikePosition: strikePosition,
                aimDirection: aimDirection,
                elevation: elevation,
                pullBack: pull
            )
            for (id, center) in ballsAt(t) {
                if intersectsBall(center: center, tip: seg.tip, butt: seg.butt, ballRadius: r) {
                    if hasSeparated.contains(id) {
                        return t
                    }
                    // Still inside the contact envelope since strike — not a re-entry.
                } else {
                    hasSeparated.insert(id)
                }
            }
        }
        return nil
    }

    /// Distance from ball centre to tapered shaft; threshold = R + shaftR(u) + margin.
    static func clearanceDistance(
        center: SCNVector3,
        tip: SCNVector3,
        butt: SCNVector3
    ) -> (distance: Float, threshold: Float) {
        let (closest, u) = closestPointOnSegment(point: center, a: tip, b: butt)
        let dx = center.x - closest.x
        let dy = center.y - closest.y
        let dz = center.z - closest.z
        let dist = sqrtf(dx * dx + dy * dy + dz * dz)
        let shaftR = shaftRadius(alongShaftU: u)
        let r = AngleSceneCalculator.ballRadius
        return (dist, r + shaftR + collisionMargin)
    }

    /// True when sphere of radius `ballRadius` intersects the tapered shaft segment.
    static func intersectsBall(
        center: SCNVector3,
        tip: SCNVector3,
        butt: SCNVector3,
        ballRadius: Float,
        margin: Float = collisionMargin
    ) -> Bool {
        let (dist, _) = clearanceDistance(center: center, tip: tip, butt: butt)
        // Recompute threshold with the provided ballRadius (normally == AngleSceneCalculator.ballRadius).
        let (_, u) = closestPointOnSegment(point: center, a: tip, b: butt)
        let shaftR = shaftRadius(alongShaftU: u)
        return dist < ballRadius + shaftR + margin
    }

    // MARK: - Forward gap (follow-through clamp)

    /// Surface gap from cue-ball centre to the nearest obstacle along +aim (metres).
    /// `max(0, dist_centers − 2R)`. Ignores balls behind or beside the aim ray
    /// (lateral > R + tipRadius).
    static func forwardSurfaceGap(
        cueBallPosition: SCNVector3,
        aimDirection: SCNVector3,
        obstacleCenters: [SCNVector3]
    ) -> Float {
        let aim = normalizeFlat(aimDirection)
        let r = AngleSceneCalculator.ballRadius
        var best = Float.greatestFiniteMagnitude
        for p in obstacleCenters {
            let dx = p.x - cueBallPosition.x
            let dz = p.z - cueBallPosition.z
            let s = dx * aim.x + dz * aim.z
            guard s > 1e-4 else { continue }
            let latX = dx - s * aim.x
            let latZ = dz - s * aim.z
            let lateral = sqrtf(latX * latX + latZ * latZ)
            guard lateral < r + tipRadius else { continue }
            best = min(best, s - 2 * r)
        }
        if best == .greatestFiniteMagnitude { return .greatestFiniteMagnitude }
        return max(0, best)
    }

    // MARK: - Math helpers

    static func normalizeFlat(_ v: SCNVector3) -> SCNVector3 {
        let len = sqrtf(v.x * v.x + v.z * v.z)
        guard len > 1e-6 else { return SCNVector3(1, 0, 0) }
        return SCNVector3(v.x / len, 0, v.z / len)
    }

    /// SceneKit `eulerAngles = (−elevation, yaw, 0)` applied to local `(0,0,localZ)`.
    /// Composition matches SceneKit: roll(z)=0, then yaw(y), then pitch(x)=−elev
    /// (docs: components applied in reverse order of the vector). Cross-checked against
    /// `SCNNode.convertPosition` in `CueClearanceTests.test_shaftSegment_matchesSceneKitNode`.
    static func worldPoint(
        localZ: Float, yaw: Float, elevation: Float, pivot: SCNVector3
    ) -> SCNVector3 {
        let ce = cosf(elevation), se = sinf(elevation)
        let cy = cosf(yaw), sy = sinf(yaw)
        // pitch −elev about X: (0,0,z) → (0, z·sin e, z·cos e); then yaw about Y.
        let y = localZ * se
        let zFlat = localZ * ce
        return SCNVector3(
            pivot.x + zFlat * sy,
            pivot.y + y,
            pivot.z + zFlat * cy
        )
    }

    /// Closest point on segment a→b; returns (point, u∈[0,1] from a to b).
    static func closestPointOnSegment(
        point: SCNVector3, a: SCNVector3, b: SCNVector3
    ) -> (SCNVector3, Float) {
        let abx = b.x - a.x, aby = b.y - a.y, abz = b.z - a.z
        let abLenSq = abx * abx + aby * aby + abz * abz
        guard abLenSq > 1e-12 else { return (a, 0) }
        let apx = point.x - a.x, apy = point.y - a.y, apz = point.z - a.z
        let u = max(0, min(1, (apx * abx + apy * aby + apz * abz) / abLenSq))
        return (SCNVector3(a.x + abx * u, a.y + aby * u, a.z + abz * u), u)
    }
}
