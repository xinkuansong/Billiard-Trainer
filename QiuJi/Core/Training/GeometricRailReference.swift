import Foundation
import SceneKit
import simd

/// Ideal centre-path geometry in world X/Z metres. No speed/spin or shot solving.
enum GeometricRailReference {
    typealias Point = SIMD2<Double>
    static let epsilon = 1e-8
    static func point(_ p: SCNVector3) -> Point { .init(Double(p.x), Double(p.z)) }
    static func cross(_ a: Point, _ b: Point) -> Double { a.x * b.y - a.y * b.x }
    static func unit(_ p: Point) -> Point? {
        let length = simd_length(p)
        return length.isFinite && length > epsilon ? p / length : nil
    }
    struct Rail {
        var start, end, normal: Point
        func nearest(_ p: Point) -> Point {
            let d = end - start
            let t = min(1, max(0, simd_dot(p - start, d) / simd_length_squared(d)))
            return start + t * d
        }
    }
    struct Context: Equatable, Codable {
        let cue, ghost, pocket, potDirection, incoming: Point
        init?(cue: SCNVector3, target: SCNVector3, pocket: SCNVector3) {
            let c = point(cue), t = point(target), p = point(pocket)
            guard let pot = unit(p - t) else { return nil }
            let ghost = t - 2 * Double(BallPhysics.radius) * pot
            guard let incoming = unit(ghost - c), simd_dot(incoming, pot) > epsilon else { return nil }
            self.cue = c; self.ghost = ghost; self.pocket = p
            self.potDirection = pot; self.incoming = incoming
        }
        var pocketSide: Double { cross(incoming, pocket - ghost) }
        var tangent: Point? { unit(incoming - simd_dot(incoming, potDirection) * potDirection) }
        /// The dividing line is cue -> ghost, NOT target -> pocket.
        func allows(_ p: Point) -> Bool {
            guard abs(pocketSide) > epsilon else { return true }
            return cross(incoming, p - ghost) * (pocketSide > 0 ? 1 : -1) <= epsilon
        }
        var allowedRails: [Rail] {
            rails.compactMap { rail in
                guard abs(pocketSide) > epsilon else { return rail }
                let sign = pocketSide > 0 ? 1.0 : -1.0
                let a = cross(incoming, rail.start - ghost) * sign
                let b = cross(incoming, rail.end - ghost) * sign
                if a > 0 && b > 0 { return nil }
                if a <= 0 && b <= 0 { return rail }
                let cut = rail.start + (rail.end - rail.start) * (a / (a - b))
                let clipped = Rail(start: a > 0 ? cut : rail.start,
                                   end: b > 0 ? cut : rail.end, normal: rail.normal)
                return simd_distance(clipped.start, clipped.end) > epsilon ? clipped : nil
            }
        }
        func constrain(_ p: Point) -> Point? {
            guard p.x.isFinite, p.y.isFinite else { return nil }
            return allowedRails.map { $0.nearest(p) }
                .min { simd_distance_squared($0, p) < simd_distance_squared($1, p) }
        }
        var defaultFirst: Point? {
            guard let tangent, let hit = boundaryHit(from: ghost, direction: tangent),
                  rail(at: hit.point) != nil, allows(hit.point) else { return nil }
            return hit.point
        }
    }
    /// Consume the real six main cushions, including actual pocket gaps. Offset by
    /// one ball radius so the reference sphere is tangent to the cushion nose.
    static let rails: [Rail] = TableGeometry.chineseEightBallCushions(y: 0).linear
        .filter { $0.soundSurface == .cushion }
        .map { segment in
            let normal = point(segment.normal)
            let offset = Double(BallPhysics.radius) * normal
            return Rail(start: point(segment.start) + offset, end: point(segment.end) + offset, normal: normal)
        }
    static func rail(at point: Point) -> Rail? {
        rails.first { simd_distance($0.nearest(point), point) < 1e-6 }
    }
    static func reflected(_ direction: Point, normal: Point) -> Point {
        direction - 2 * simd_dot(direction, normal) * normal
    }
    struct Hit { let point: Point; let normal: Point }
    static func boundaryHit(from p: Point, direction d: Point) -> Hit? {
        let half = Point(Double(TablePhysics.innerLength / 2 - BallPhysics.radius),
                         Double(TablePhysics.innerWidth / 2 - BallPhysics.radius))
        var nearest: (Double, Hit)?
        for axis in 0..<2 where abs(d[axis]) > epsilon {
            let edge = d[axis] > 0 ? half[axis] : -half[axis]
            let time = (edge - p[axis]) / d[axis]
            guard time > epsilon else { continue }
            let q = p + time * d
            guard abs(q[1 - axis]) <= half[1 - axis] + epsilon else { continue }
            var normal = Point.zero; normal[axis] = d[axis] > 0 ? -1 : 1
            if nearest == nil || time < nearest!.0 { nearest = (time, Hit(point: q, normal: normal)) }
        }
        return nearest?.1
    }
    /// N reflections plus one final outgoing leg, ending at the next rail/mouth.
    static func path(context: Context, first: Point, reflections: Int) -> [Point] {
        guard (1...5).contains(reflections), context.allows(first),
              let firstRail = rail(at: first), let incoming = unit(first - context.ghost) else { return [] }
        var points = [context.ghost, first]
        var p = first, d = reflected(incoming, normal: firstRail.normal)
        for _ in 0..<reflections {
            guard let hit = boundaryHit(from: p, direction: d) else { break }
            points.append(hit.point)
            guard let nextRail = rail(at: hit.point) else { break }
            p = hit.point; d = reflected(d, normal: nextRail.normal)
        }
        return points
    }
}
