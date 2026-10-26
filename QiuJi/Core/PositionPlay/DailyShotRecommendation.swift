import Foundation
import SceneKit

/// Opt-in daily single-shot ranking. Frozen legacy aiming and training geometry stay untouched.
enum DailyShotRecommendation {
    struct Candidate {
        let targetKey: String
        let pocketIndex: Int
        let aim: SCNVector3
        let cutDegrees: Double
        var cueTargetDistance: Double = 0
        var targetPocketDistance: Double = 0
        var comfortScore: Double? = nil
    }
    static func candidate(cue: SCNVector3, target: SCNVector3,
                          targetKey: String, pocketIndex: Int,
                          obstacles: [SCNVector3], surfaceY: Float) -> Candidate? {
        guard (0..<6).contains(pocketIndex),
              [cue.x, cue.z, target.x, target.z].allSatisfy(\.isFinite),
              obstacles.allSatisfy({ $0.x.isFinite && $0.z.isFinite }) else { return nil }
        if MiddlePocketRegion.assess(target: target, pocket: pocketIndex,
            calibration: MiddlePocketRegion.production) == .outside { return nil }
        var best: Candidate?
        let nominal = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)[pocketIndex]
        let (a, b) = AngleSceneCalculator.pocketJaws(surfaceY: surfaceY)[pocketIndex]
        let width = AngleSceneCalculator.horizontalDistance(a, b)
        guard width > 2 * AngleSceneCalculator.ballRadius else { return nil }
        let inset = AngleSceneCalculator.ballRadius / width
        var aims = [nominal]
        for t in [Float(0.5), inset, 1 - inset] {
            aims.append(SCNVector3(a.x + (b.x - a.x) * t, surfaceY, a.z + (b.z - a.z) * t))
        }
        // The rounded nose can admit a near-rail line outside the inset chord.
        // Include its two tips; do not turn missing chord samples into a veto.
        aims.append(contentsOf: [a, b])
        // Frozen balls run parallel to their rail. Using the nominal jaw endpoint
        // tilts that line and can place the ghost beyond the ball-centre boundary.
        // Curved-jaw entry remains an estimate, not a simulated pot guarantee.
        if pocketIndex < 4 {
            if abs(target.z) >= AngleSceneCalculator.innerWidth / 2 - AngleSceneCalculator.ballRadius, target.z * nominal.z > 0 {
                aims.append(SCNVector3(nominal.x, surfaceY, target.z))
            }
            if abs(target.x) >= AngleSceneCalculator.innerLength / 2 - AngleSceneCalculator.ballRadius, target.x * nominal.x > 0 {
                aims.append(SCNVector3(target.x, surfaceY, nominal.z))
            }
        }
        let epsilon: Float = 0.000001 // metre-scale Float roundoff, not gameplay padding
        for index in 0...aims.count {
            // Prefer clean finite mouth samples. If none survives, retain the existing
            // pipe aim (which also handles near-rail far-jaw entry) as one fallback.
            // Raw jaw tips must not win merely by shaving a little off the cut angle.
            let isPipeFallback = index == aims.count
            if isPipeFallback && best != nil { break }
            let aim = isPipeFallback
                ? AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: surfaceY)
                : aims[index]
            let angle = AngleSceneCalculator.cutAngle(cueBall: cue, targetBall: target, pocket: aim)
            guard angle < AngleSceneCalculator.maxCutAngle else { continue }
            let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: aim, ballRadius: AngleSceneCalculator.ballRadius)
            guard abs(ghost.x) <= AngleSceneCalculator.innerLength / 2 - AngleSceneCalculator.ballRadius + epsilon,
                  abs(ghost.z) <= AngleSceneCalculator.innerWidth / 2 - AngleSceneCalculator.ballRadius + epsilon,
                  AngleSceneCalculator.horizontalDistance(cue, ghost) > epsilon,
                  !mainCushionSegments.contains(where: {
                      segmentDistance(Vector2(cue.x, cue.z), Vector2(ghost.x, ghost.z), $0.a, $0.b) < AngleSceneCalculator.ballRadius - epsilon
                      || segmentDistance(Vector2(target.x, target.z), Vector2(aim.x, aim.z), $0.a, $0.b) < AngleSceneCalculator.ballRadius - epsilon
                  }),
                  !AngleSceneCalculator.isPathBlocked(from: cue, to: ghost, obstacles: obstacles, clearance: 2 * AngleSceneCalculator.ballRadius - epsilon),
                  !AngleSceneCalculator.isPathBlocked(from: target, to: aim, obstacles: obstacles, clearance: 2 * AngleSceneCalculator.ballRadius - epsilon)
                else { continue }
            guard isPipeFallback || AngleSceneCalculator.trainingHasCleanPocketPath(
                target: target, aim: aim, pocketIndex: pocketIndex) else { continue }
            var candidate = Candidate(targetKey: targetKey, pocketIndex: pocketIndex,
                aim: aim, cutDegrees: angle,
                cueTargetDistance: hypot(Double(cue.x) - Double(target.x), Double(cue.z) - Double(target.z)),
                targetPocketDistance: hypot(Double(target.x) - Double(aim.x), Double(target.z) - Double(aim.z)))
            guard let comfort = ShotComfortScore.evaluate(cue: (Double(cue.x), Double(cue.z)),
                ball: (Double(target.x), Double(target.z)), aim: (Double(aim.x), Double(aim.z))) else { continue }
            candidate.comfortScore = comfort.total
            if best == nil || comfort.total > best!.comfortScore! { best = candidate }
        }
        return best
    }
    static func best(_ candidates: [Candidate],
        preferred: (target: String, pocket: Int)? = nil) -> Candidate? {
        candidates.filter { $0.comfortScore?.isFinite == true }.min { lhs, rhs in
            if lhs.comfortScore! != rhs.comfortScore! { return lhs.comfortScore! > rhs.comfortScore! }
            let lp = lhs.targetKey == preferred?.target && lhs.pocketIndex == preferred?.pocket
            let rp = rhs.targetKey == preferred?.target && rhs.pocketIndex == preferred?.pocket
            if lp != rp { return lp }
            if lhs.targetKey != rhs.targetKey { return lhs.targetKey < rhs.targetKey }
            return lhs.pocketIndex < rhs.pocketIndex
        }
    }
    private static let table = TableGeometry.chineseEightBallQiuJi(surfaceY: 0)
    private static let mainCushionSegments: [Segment2D] = table.linearCushions.filter { $0.soundSurface == .cushion }.map {
            Segment2D(a: Vector2($0.start.x, $0.start.z), b: Vector2($0.end.x, $0.end.z))
        }
    private struct Vector2 {
        let x: Float
        let z: Float

        init(_ x: Float, _ z: Float) {
            self.x = x
            self.z = z
        }

        var length: Float { sqrtf(x * x + z * z) }

        static func + (lhs: Vector2, rhs: Vector2) -> Vector2 {
            Vector2(lhs.x + rhs.x, lhs.z + rhs.z)
        }

        static func - (lhs: Vector2, rhs: Vector2) -> Vector2 {
            Vector2(lhs.x - rhs.x, lhs.z - rhs.z)
        }

        static func * (lhs: Vector2, rhs: Float) -> Vector2 {
            Vector2(lhs.x * rhs, lhs.z * rhs)
        }

        static func / (lhs: Vector2, rhs: Float) -> Vector2 {
            Vector2(lhs.x / rhs, lhs.z / rhs)
        }

        func dot(_ other: Vector2) -> Float {
            x * other.x + z * other.z
        }
    }
    private struct Segment2D {
        let a: Vector2
        let b: Vector2
    }
    private static func closestPointOnSegment(point: Vector2, segment: Segment2D) -> Vector2 {
        let v = segment.b - segment.a
        let lenSq = v.dot(v)
        guard lenSq > 1e-8 else { return segment.a }
        let t = max(0, min(1, (point - segment.a).dot(v) / lenSq))
        return segment.a + v * t
    }
    private static func segmentDistance(_ a: Vector2, _ b: Vector2, _ c: Vector2, _ d: Vector2) -> Float {
        if segmentsIntersect(a, b, c, d) { return 0 }
        return min(
            min(pointSegmentDistance(a, Segment2D(a: c, b: d)),
                pointSegmentDistance(b, Segment2D(a: c, b: d))),
            min(pointSegmentDistance(c, Segment2D(a: a, b: b)),
                pointSegmentDistance(d, Segment2D(a: a, b: b)))
        )
    }
    private static func pointSegmentDistance(_ point: Vector2, _ segment: Segment2D) -> Float {
        (point - closestPointOnSegment(point: point, segment: segment)).length
    }
    private static func segmentsIntersect(_ a: Vector2, _ b: Vector2, _ c: Vector2, _ d: Vector2) -> Bool {
        func orient(_ a: Vector2, _ b: Vector2, _ c: Vector2) -> Float {
            (b.x - a.x) * (c.z - a.z) - (b.z - a.z) * (c.x - a.x)
        }
        let o1 = orient(a, b, c)
        let o2 = orient(a, b, d)
        let o3 = orient(c, d, a)
        let o4 = orient(c, d, b)
        return (o1 > 0) != (o2 > 0) && (o3 > 0) != (o4 > 0)
    }
}
extension DailyShotRecommendation.Candidate {
    init(legacy c: AngleSceneCalculator.DailyPocketCandidate) {
        self.init(targetKey: c.targetKey, pocketIndex: c.pocketIndex, aim: c.aim, cutDegrees: c.cutDegrees,
            cueTargetDistance: c.cueTargetDistance, targetPocketDistance: c.targetPocketDistance)
    }
}
