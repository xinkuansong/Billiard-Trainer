import SceneKit
import UIKit
import simd

/// Daily clearance surface: cloth-relative metres, XZ horizontal, Y up. No business aim mutation.
/// `travel` selects a continuous height ring; bearing moves along that ring.
struct CameraSurface {
    var cue: SIMD2<Float>
    var surfaceY: Float
    var viewport: CGSize
    var bearing: Float
    var travel: Float = 0.5

    /// Four centred outer-ring views, chosen by visible heading rather than shot aim.
    /// Stable ordering resolves exact half-way ties, including the ±π seam.
    static func nearestOverviewBearing(yaw: Float) -> Float {
        let candidates: [Float] = [0, .pi / 2, .pi, -.pi / 2]
        // Account for argument/subtraction rounding when equivalent angles include
        // whole turns. This is a floating-point tie tolerance, not an angular snap band.
        let tieTolerance = 8 * max(abs(yaw).ulp, Float.pi.ulp)
        var best = candidates[0]
        var distance = abs(TwoViewCamera.angleDelta(yaw, best))
        for candidate in candidates.dropFirst() {
            let next = abs(TwoViewCamera.angleDelta(yaw, candidate))
            if next < distance - tieTolerance { best = candidate; distance = next }
        }
        return best
    }

    static func smooth(_ value: Float) -> Float {
        let t = max(0, min(1, value))
        return t * t * t * (10 + t * (-15 + 6 * t))
    }

    static func boundary(_ phi: Float) -> SIMD2<Float> {
        let c = cos(phi), s = sin(phi)
        let a = c / 3.5, b = s / 2.5
        let r = pow(a*a*a*a + b*b*b*b, -0.25)
        return SIMD2(c*r, s*r)
    }

    static func bearing(cue: SIMD2<Float>, backwards: SIMD2<Float>) -> Float {
        let direction = simd_normalize(backwards)
        var low: Float = 0, high: Float = 8
        for _ in 0..<32 {
            let d = (low + high) / 2
            let point = cue + direction * d
            let x = point.x / 3.5, z = point.y / 2.5
            if x*x*x*x + z*z*z*z < 1 { low = d } else { high = d }
        }
        let point = cue + direction * ((low + high) / 2)
        return atan2(point.y, point.x)
    }

    var farDistance: Float { simd_length(Self.boundary(bearing) - cue) }
    /// Monotone Hermite bands share the harmonic-mean tangent at the default ring.
    /// Both distance and height are C1 there, despite unequal inner/outer travel spans.
    static func ringValue(_ u: Float, near: Float, middle: Float, far: Float) -> Float {
        let a = middle - near, b = far - middle
        let tangent = 2 * a * b / (a + b)
        let outer = u > 0.5
        let t = max(0, min(1, outer ? (u - 0.5) * 2 : u * 2))
        let start = outer ? middle : near, end = outer ? far : middle
        let m0 = outer ? tangent : a, m1 = outer ? b : tangent
        let t2 = t*t, t3 = t2*t
        return (2*t3-3*t2+1)*start + (t3-2*t2+t)*m0
            + (-2*t3+3*t2)*end + (t3-t2)*m1
    }

    static let outerHeight: Float = 1.80 // Old outer ring peaked at 1.7791m above cloth.
    var nearHeight: Float {
        let r = BallPhysics.radius
        let clearance = max(r, min(1.27 - abs(cue.x), 0.635 - abs(cue.y)))
        // Conservative cue-centre sightline at the nearest cushion, common to every bearing.
        // This is not a certificate for the whole ball silhouette or the physical cue shaft.
        return max(0.18, r + 0.9 * (BTTablePhysics.cushionHeight - r) / clearance + 0.01)
    }
    var height: Float { Self.ringValue(travel, near: nearHeight, middle: 0.65, far: Self.outerHeight) }
    var distance: Float { Self.ringValue(travel, near: 0.9, middle: 1.65, far: farDistance) }

    /// Resample motion in surface coordinates, never along a chord between two eyes.
    /// Interpolate ring coordinates so resampling a horizontal drag stays exactly level.
    func interpolated(to target: CameraSurface, fraction: Float) -> CameraSurface {
        let t = max(0, min(1, fraction))
        if t == 0 { return self }
        if t == 1 { return target }
        var result = self
        result.cue += (target.cue - cue) * t
        result.surfaceY += (target.surfaceY - surfaceY) * t
        result.viewport = target.viewport
        result.bearing += TwoViewCamera.angleDelta(bearing, target.bearing) * t
        result.travel += (target.travel - travel) * t
        return result
    }

    /// Input uses projected table motion, rather than equal increments of `travel`.
    /// Distance is integrated in metres so the two travel bands cannot introduce a speed step.
    mutating func move(points: Float) {
        integrate(points: points, horizontal: false)
    }

    mutating func orbit(points: Float) {
        integrate(points: points, horizontal: true)
    }

    private mutating func advanceDistance(_ metres: Float) {
        let d = max(0.9, min(farDistance, distance + metres))
        if d <= 0.9 { travel = 0; return }
        if d >= farDistance { travel = 1; return }
        var low: Float = 0, high: Float = 1
        let far = farDistance
        for _ in 0..<22 {
            let u = (low + high) / 2
            if Self.ringValue(u, near: 0.9, middle: 1.65, far: far) < d { low = u }
            else { high = u }
        }
        travel = (low + high) / 2
    }

    private mutating func advanceOrbit(_ delta: Float) {
        let back = simd_normalize(Self.boundary(bearing) - cue)
        let angle = atan2(back.y, back.x) + delta
        let nearBearing = Self.bearing(cue: cue, backwards: SIMD2(cos(angle), sin(angle)))
        let nearDelta = atan2(sin(nearBearing-bearing), cos(nearBearing-bearing))
        let weight = Self.smooth((travel - 0.5) * 2)
        bearing += nearDelta * (1-weight) + delta * weight
        bearing = atan2(sin(bearing), cos(bearing))
    }

    /// Weighted RMS screen motion of fixed cloth landmarks (UIKit points).
    /// Soft viewport weights avoid gain jumps when a landmark crosses a screen edge.
    /// No live ball, pocket selection, or HUD state enters the response function.
    private func screenMotion(_ a: TwoViewCamera.Pose, _ b: TwoViewCamera.Pose) -> Float {
        let size = SIMD2<Float>(Float(max(1, viewport.width)), Float(max(1, viewport.height)))
        let aspect = size.x / size.y
        func projection(_ point: SIMD3<Float>, _ pose: TwoViewCamera.Pose) -> SIMD2<Float>? {
            let relative = point - pose.eye
            let depth = simd_dot(relative, pose.forward)
            guard depth > 0.05 else { return nil }
            let right = simd_normalize(SIMD3(-pose.forward.z, 0, pose.forward.x))
            let up = simd_cross(right, pose.forward)
            let tangent = tan(pose.fov * .pi / 360)
            return SIMD2(simd_dot(relative, right) / (depth * tangent * aspect),
                         simd_dot(relative, up) / (depth * tangent))
        }
        var total: Float = 0, weights: Float = 0
        for x: Float in [-1.27, -0.635, 0, 0.635, 1.27] {
            for z: Float in [-0.635, 0, 0.635] {
                let point = SIMD3(x, surfaceY, z)
                guard let pa = projection(point, a), let pb = projection(point, b) else { continue }
                let middle = (pa + pb) / 2
                let weight = exp(-simd_length_squared(middle))
                let movement = (pb - pa) * size / 2
                total += weight * simd_length_squared(movement)
                weights += weight
            }
        }
        return sqrt(total / max(0.00001, weights))
    }

    /// Target: 0.325 points of representative cloth motion per finger point (half sensitivity).
    /// A speed ceiling prevents runaway gain when visible cloth has little parallax.
    /// Do not impose a distance-speed floor: steep projection changes require slower travel.
    private func responseRate(horizontal: Bool) -> Float {
        var low = self, high = self
        let span: Float
        if horizontal {
            low.advanceOrbit(-0.001); high.advanceOrbit(0.001)
            span = 0.002
        } else {
            low.advanceDistance(-0.002); high.advanceDistance(0.002)
            span = max(0.00001, high.distance - low.distance)
        }
        let speed = screenMotion(low.pose, high.pose) / span
        if horizontal {
            let baseline = 64 * Float.pi / (180 * Float(max(1, viewport.width)))
            return min(baseline * 2, 0.325 / max(0.001, speed))
        }
        // Relative-distance ceiling scales with viewport height, not callback frequency.
        let baseline = distance / Float(max(1, viewport.height))
        return min(baseline * 2, 0.325 / max(0.001, speed))
    }

    private mutating func integrate(points: Float, horizontal: Bool) {
        guard points.isFinite, points != 0 else { return }
        // Midpoint substeps make fast/coalesced input agree with many small updates.
        let limit = Float(max(1, max(viewport.width, viewport.height))) * 4
        var remaining = max(-limit, min(limit, points))
        while abs(remaining) > 0.0001 {
            let step = max(-4, min(4, remaining))
            var middle = self
            let first = responseRate(horizontal: horizontal)
            if horizontal { middle.advanceOrbit(step * first / 2) }
            else { middle.advanceDistance(step * first / 2) }
            let rate = middle.responseRate(horizontal: horizontal)
            if horizontal { advanceOrbit(step * rate) } // right swipe turns the viewpoint right (S2)
            else { advanceDistance(step * rate) }
            remaining -= step
            if !horizontal, (travel == 0 && step < 0) || (travel == 1 && step > 0) { break }
        }
    }

    private func outerTangent(aspect: Float) -> Float {
        let far = Self.boundary(bearing)
        let eye = SIMD3(far.x, Self.outerHeight, far.y)
        let forward = simd_normalize(SIMD3<Float>(0, BallPhysics.radius, 0)-eye)
        let right = simd_normalize(SIMD3(-forward.z, 0, forward.x))
        let up = simd_cross(right, forward)
        var candidates: [Float] = [tan(64 * .pi / 360)]
        for x: Float in [-1.4055, 1.4055] {
            for z: Float in [-0.7995, 0.7995] {
                for y: Float in [0, BallPhysics.radius + 0.037] {
                    let relative = SIMD3(x,y,z)-eye
                    let depth = simd_dot(relative,forward)
                    let px = simd_dot(relative,right)/depth
                    let py = simd_dot(relative,up)/depth
                    candidates += [px/0.88, -px/0.88, py*aspect/0.90, -py*aspect/0.90].map { $0*1.012 }
                }
            }
        }
        let peak = candidates.max()!
        return peak + 0.002*log(candidates.reduce(Float(0)) { $0 + exp(($1-peak)/0.002) })
    }

    var pose: TwoViewCamera.Pose {
        let far = Self.boundary(bearing), r = BallPhysics.radius
        let back = simd_normalize(far-cue), d = distance
        let eyeXZ = cue + back*d
        let wf = Self.smooth((travel - 0.5) * 2)
        let focus = cue*(1-wf)
        let length = simd_length(eyeXZ-focus)
        let aspect = Float(max(1,viewport.width)/max(1,viewport.height))
        let tanNear = tan(Float(64)*Float.pi/360)
        let tanH = tanNear+(outerTangent(aspect:aspect)-tanNear)*wf
        let delta = atan(0.34*(1-wf)*tanH/aspect)
        let alpha = atan((height-r)/length) - delta
        let viewBack = eyeXZ-focus
        return .looking(eye:SIMD3(eyeXZ.x,surfaceY+height,eyeXZ.y),
                        yaw:atan2(viewBack.y,viewBack.x),pitch:-alpha,
                        fov:2*atan(tanH/aspect)*180 / .pi)
    }
}
