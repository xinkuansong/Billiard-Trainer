import SceneKit
import UIKit
import simd

/// Daily-camera candidate. World metres, XZ table plane, Y up; angles in radians.
/// The rail stores intent independently of the actual pose. Rendering consumes only `pose`.
final class TwoViewCamera {
    enum Owner { case automatic, manual }

    struct Pose {
        var eye: SIMD3<Float>
        var orientation: simd_quatf
        var fov: Float

        var forward: SIMD3<Float> { orientation.act(SIMD3(0, 0, -1)) }
        var transform: simd_float4x4 {
            var matrix = simd_float4x4(orientation)
            matrix.columns.3 = SIMD4(eye, 1)
            return matrix
        }

        static func looking(eye: SIMD3<Float>, yaw: Float, pitch: Float, fov: Float) -> Pose {
            let alpha = -pitch
            let right = SIMD3(sin(yaw), 0, -cos(yaw))
            let up = SIMD3(-cos(yaw) * sin(alpha), cos(alpha), -sin(yaw) * sin(alpha))
            let back = SIMD3(cos(yaw) * cos(alpha), sin(alpha), sin(yaw) * cos(alpha))
            return Pose(eye: eye, orientation: simd_quatf(simd_float3x3(columns: (right, up, back))), fov: fov)
        }

        func interpolated(to other: Pose, fraction: Float) -> Pose {
            let t = max(0, min(1, fraction))
            if t == 0 { return self }
            if t == 1 { return other }
            return Pose(eye: eye + (other.eye - eye) * t,
                        orientation: simd_slerp(orientation, other.orientation, t),
                        fov: fov + (other.fov - fov) * t)
        }
    }

    /// Table-owned viewing surface, independent of balls, pockets and shot generations (FL-099).
    /// theta/yaw is the eye's XZ bearing: 0 = +X end, pi/2 = +Z side. s = 0 near, 1 far.
    struct RailProfile {
        let anchor: SIMD3<Float> // Cloth centre, Y is the actual cloth surface, not ball-centre Y.
        let tableHalfExtents: SIMD2<Float>
        let fov: Float
        let viewport: CGSize
        let readableInsets: UIEdgeInsets
        let railViewport: CGSize // Creation domain; layout revalidation cannot relabel old samples.
        let railInsets: UIEdgeInsets
        var isWholeTable: Bool { true } // Table reference, not a promise that the near view shows all rails.
        var layoutMatchesRail: Bool { viewport == railViewport && readableInsets == railInsets }
        var hasReadableLayout: Bool { Self.readableBox(viewport: viewport, insets: readableInsets) != nil }

        private struct Sample {
            let near: SIMD4<Float> // radius, height above cloth, pitch-down, heading minus eye bearing
            let far: SIMD4<Float>
        }
        private let samples: [Sample]
        private let tableEnvelope: [SIMD3<Float>]

        // v1.5 visual candidates, not measured mesh clearance or a vision/readability threshold.
        private static let lensDegrees: Float = 55
        private static let tableTopEnvelopeHeight: Float = 0.12
        private static let nearSetback: Float = 0.40
        private static let nearEyeHeight: Float = 0.38
        private static let maximumEyeY: Float = 3.25 // 3.6m room walls minus a 0.35m candidate allowance.
        private static let headingLimit: Float = 12 * .pi / 180
        private static let sampleCount = 96
        private static let overviewPitch: Float = 35 * .pi / 180
        private static let overviewClothFraction: Float = 0.25 // Working soft target, awaiting visual review.

        func preservingLens(viewport: CGSize, insets: UIEdgeInsets) -> RailProfile {
            RailProfile(anchor: anchor, tableHalfExtents: tableHalfExtents, fov: fov,
                viewport: viewport, readableInsets: insets, railViewport: railViewport,
                railInsets: railInsets, samples: samples, tableEnvelope: tableEnvelope)
        }

        /// Full outer-table top-envelope diagnostic. False is expected when approaching the low near view.
        func containsSubjects(in pose: Pose) -> Bool {
            Self.contains(tableEnvelope, pose: pose, viewport: viewport, insets: readableInsets)
        }

        func nearRadius(yaw: Float) -> Float { sample(yaw: yaw).near.x }
        func farRadius(yaw: Float) -> Float { sample(yaw: yaw).far.x }

        func radius(yaw: Float, progress: Float) -> Float {
            let endpoints = sample(yaw: yaw)
            let s = max(0, min(1, progress))
            return endpoints.near.x * exp(log(endpoints.far.x / endpoints.near.x) * s)
        }

        func progress(yaw: Float, radius: Float) -> Float {
            guard yaw.isFinite, radius.isFinite, radius > 0 else { return 1 }
            let endpoints = sample(yaw: yaw)
            let range = log(endpoints.far.x / endpoints.near.x)
            return range > 0.000001
                ? max(0, min(1, log(radius / endpoints.near.x) / range)) : 1
        }

        /// A first global entry shows the whole table; ordinary mode switches restore their independent memory.
        func entryProgress(yaw: Float) -> Float { 1 }

        func pose(yaw: Float, progress: Float) -> Pose {
            let endpoints = sample(yaw: yaw)
            let s = max(0, min(1, progress))
            let r = endpoints.near.x * exp(log(endpoints.far.x / endpoints.near.x) * s)
            let h = endpoints.near.y + (endpoints.far.y - endpoints.near.y) * s
            let pitch = endpoints.near.z + (endpoints.far.z - endpoints.near.z) * s
            let heading = endpoints.near.w + (endpoints.far.w - endpoints.near.w) * s
            let eye = anchor + SIMD3(cos(yaw) * r, h, sin(yaw) * r)
            return .looking(eye: eye, yaw: yaw + heading, pitch: -pitch, fov: fov)
        }

        /// Runtime geometry check, not a mesh/occlusion certificate. Failed motion holds the actual pose.
        func legalPose(yaw: Float, progress: Float) -> Pose? {
            guard yaw.isFinite, progress.isFinite, layoutMatchesRail else { return nil }
            let endpoints = sample(yaw: yaw)
            guard endpoints.far.x >= max(endpoints.near.x * 1.25, endpoints.near.x + 0.40),
                  endpoints.far.y >= endpoints.near.y, endpoints.far.z >= endpoints.near.z else { return nil }
            let result = pose(yaw: yaw, progress: progress)
            guard containsEye(result.eye) else { return nil }
            // These two table-owned references keep the main direction readable; no ball must remain on screen.
            let d = SIMD3<Float>(cos(yaw), 0, sin(yaw))
            let innerRadius = 1 / sqrt(pow(d.x / tableHalfExtents.x, 2) + pow(d.z / tableHalfExtents.y, 2))
            let references = [anchor, anchor - d * (innerRadius * 0.35)]
            guard Self.contains(references, pose: result, viewport: viewport, insets: readableInsets) else { return nil }
            if progress >= 1 && !containsSubjects(in: result) { return nil }
            return result
        }

        private func containsEye(_ eye: SIMD3<Float>) -> Bool {
            let room = BakedTrainingRoom.cameraSafeHalfExtents
            let offset = eye - anchor
            return eye.x.isFinite && eye.y.isFinite && eye.z.isFinite
                && abs(eye.x) <= room.x && abs(eye.z) <= room.y
                && eye.y <= Self.maximumEyeY && offset.y > Self.tableTopEnvelopeHeight
                && (abs(offset.x) > tableHalfExtents.x + 0.02
                    || abs(offset.z) > tableHalfExtents.y + 0.02)
        }

        /// Periodic shape-preserving Hermite interpolation is C1 at the seam and every cache node.
        /// It keeps each scalar inside its adjacent sample range; legality still checks the resulting pose.
        private func sample(yaw: Float) -> Sample {
            let period = 2 * Float.pi
            let wrapped = yaw.isFinite ? yaw.truncatingRemainder(dividingBy: period) : 0
            let positive = wrapped < 0 ? wrapped + period : wrapped
            let index = positive / period * Float(samples.count)
            let floorIndex = Int(floor(index)) % samples.count
            let t = index - floor(index)
            func at(_ offset: Int) -> Sample { samples[(floorIndex + offset + samples.count) % samples.count] }
            func interpolate(_ a: SIMD4<Float>, _ b: SIMD4<Float>, _ c: SIMD4<Float>, _ d: SIMD4<Float>) -> SIMD4<Float> {
                func slope(_ p: Float, _ q: Float) -> Float { p * q > 0 ? 2 * p * q / (p + q) : 0 }
                let t2 = t * t, t3 = t2 * t
                var result = SIMD4<Float>(repeating: 0)
                for axis in 0..<4 {
                    let m0 = slope(b[axis] - a[axis], c[axis] - b[axis])
                    let m1 = slope(c[axis] - b[axis], d[axis] - c[axis])
                    result[axis] = (2 * t3 - 3 * t2 + 1) * b[axis] +
                        (t3 - 2 * t2 + t) * m0 + (-2 * t3 + 3 * t2) * c[axis] +
                        (t3 - t2) * m1
                }
                return result
            }
            return Sample(near: interpolate(at(-1).near, at(0).near, at(1).near, at(2).near),
                          far: interpolate(at(-1).far, at(0).far, at(1).far, at(2).far))
        }

        private static func readableBox(viewport: CGSize, insets: UIEdgeInsets, padding: CGFloat = 0) -> SIMD4<Float>? {
            guard viewport.width.isFinite, viewport.height.isFinite,
                  viewport.width > 1, viewport.height > 1,
                  [insets.left, insets.right, insets.top, insets.bottom].allSatisfy({ $0.isFinite && $0 >= 0 }) else { return nil }
            let box = SIMD4<Float>(Float(2 * (insets.left + padding) / viewport.width - 1),
                                  Float(1 - 2 * (insets.right + padding) / viewport.width),
                                  Float(2 * (insets.bottom + padding) / viewport.height - 1),
                                  Float(1 - 2 * (insets.top + padding) / viewport.height))
            // The conservative HUD rectangle must include the optical centre for this profile family.
            return box.x < 0 && box.y > 0 && box.z < 0 && box.w > 0 ? box : nil
        }

        private static func contains(_ points: [SIMD3<Float>], pose: Pose,
                                     viewport: CGSize, insets: UIEdgeInsets) -> Bool {
            guard let box = readableBox(viewport: viewport, insets: insets),
                  pose.fov.isFinite, pose.fov > 0, pose.fov < 180 else { return false }
            let tangent = tan(pose.fov * .pi / 360), aspect = Float(viewport.width / viewport.height)
            let inverse = pose.orientation.inverse
            return points.allSatisfy { point in
                let local = inverse.act(point - pose.eye)
                let depth = -local.z
                guard depth.isFinite, depth > 0.01 else { return false }
                let x = local.x / (depth * tangent * aspect), y = local.y / (depth * tangent)
                return x >= box.x && x <= box.y && y >= box.z && y <= box.w
            }
        }

        /// Central-band and far-side rays, with smooth table-relative weights. No preferred world side.
        private static func headingOffset(eye: SIMD3<Float>, anchor: SIMD3<Float>, halfExtents: SIMD2<Float>,
                                          yaw: Float, pitch: Float, aspect: Float, box: SIMD4<Float>) -> Float {
            var average = SIMD2<Float>(repeating: 0)
            let d = SIMD2<Float>(cos(yaw), sin(yaw))
            let support = halfExtents.x * abs(d.x) + halfExtents.y * abs(d.y)
            for ix in -1...1 {
                for iz in -1...1 {
                    let offset = SIMD2<Float>(Float(ix) * halfExtents.x * 0.55, Float(iz) * halfExtents.y * 0.55)
                    let central = exp(-2 * (Float(ix * ix + iz * iz)))
                    let far = 0.35 * (1 - tanh(3 * simd_dot(offset, d) / support))
                    let back = SIMD2(eye.x - anchor.x, eye.z - anchor.z) - offset
                    average += simd_normalize(back) * (central + far)
                }
            }
            let tableCorrection = TwoViewCamera.angleDelta(yaw, atan2(average.y, average.x))
            let hudCentre = (box.x + box.y) / 2
            let hudCorrection = -atan(hudCentre * tan(lensDegrees * .pi / 360) * aspect / max(0.25, cos(pitch)))
            return headingLimit * tanh((tableCorrection + hudCorrection) / headingLimit)
        }

        /// Exact pitch intervals at a fixed eye/heading, intersected over the eight table-top envelope corners.
        /// The horizontal inequality is D=L*cos(alpha+phi) >= abs(u)/(edge*tan(FOV/2)*aspect).
        private static func pitchInterval(eye: SIMD3<Float>, heading: Float, points: [SIMD3<Float>],
                                          minimum: Float, aspect: Float, box: SIMD4<Float>) -> SIMD2<Float>? {
            let tangent = tan(lensDegrees * .pi / 360)
            var low = minimum, high: Float = 85 * .pi / 180
            for point in points {
                let offset = point - eye
                let q = -offset.x * cos(heading) - offset.z * sin(heading)
                let u = offset.x * sin(heading) - offset.z * cos(heading)
                let length = hypot(q, offset.y), phi = atan2(offset.y, q)
                let edge = u < 0 ? -box.x : box.y
                let ratio = abs(u) / (edge * tangent * aspect * length)
                guard q > 0, length > 0.01, ratio.isFinite, ratio < 1 else { return nil }
                let angle = acos(ratio)
                low = max(low, atan(box.z * tangent) - phi, -angle - phi)
                high = min(high, atan(box.w * tangent) - phi, angle - phi)
            }
            return low <= high ? SIMD2(low, high) : nil
        }

        static func candidate(anchor: SIMD3<Float>, halfExtents: SIMD2<Float>,
                              viewport: CGSize, insets: UIEdgeInsets) -> RailProfile? {
            guard anchor.x.isFinite, anchor.y.isFinite, anchor.z.isFinite,
                  halfExtents.x.isFinite, halfExtents.y.isFinite,
                  halfExtents.x > 0, halfExtents.y > 0,
                  let box = readableBox(viewport: viewport, insets: insets, padding: 12) else { return nil }
            let room = BakedTrainingRoom.cameraSafeHalfExtents
            let farAxes = room - SIMD2(abs(anchor.x) + 0.02, abs(anchor.z) + 0.02)
            let nearAxes = (halfExtents + SIMD2<Float>(repeating: nearSetback)) * pow(Float(2), Float(0.25))
            guard farAxes.x > nearAxes.x + 0.15, farAxes.y > nearAxes.y + 0.15 else { return nil }
            let maximumHeight = maximumEyeY - anchor.y
            guard maximumHeight > nearEyeHeight + 0.5 else { return nil }
            var envelope: [SIMD3<Float>] = []
            for x in [-halfExtents.x, halfExtents.x] {
                for z in [-halfExtents.y, halfExtents.y] {
                    for y in [Float(0), tableTopEnvelopeHeight] { envelope.append(anchor + SIMD3(x, y, z)) }
                }
            }
            let aspect = Float(viewport.width / viewport.height)
            let tangent = tan(lensDegrees * .pi / 360)
            let verticalCentre = atan((box.z + box.w) / 2 * tangent)
            guard let actualBox = readableBox(viewport: viewport, insets: insets) else { return nil }
            let readableArea = (actualBox.y - actualBox.x) * (actualBox.w - actualBox.z)
            // This project has one calibrated 2.54 x 1.27m bed. Never project its corners outside a supplied frame.
            // Clamping is a footprint bound, not proof that an arbitrary replacement model has this bed geometry.
            let clothHalf = SIMD2(min(halfExtents.x, AngleSceneCalculator.innerLength / 2),
                                  min(halfExtents.y, AngleSceneCalculator.innerWidth / 2))
            let clothCorners = [SIMD3(-clothHalf.x, Float(0), -clothHalf.y),
                                SIMD3(clothHalf.x, Float(0), -clothHalf.y),
                                SIMD3(clothHalf.x, Float(0), clothHalf.y),
                                SIMD3(-clothHalf.x, Float(0), clothHalf.y)]
            var samples: [Sample] = []
            for index in 0..<sampleCount {
                let yaw = Float(index) * 2 * .pi / Float(sampleCount)
                let d = SIMD3<Float>(cos(yaw), 0, sin(yaw))
                // A circumscribed fourth-power ellipse encloses the expanded rectangular outer frame.
                let nearR = pow(pow(d.x / nearAxes.x, 4) + pow(d.z / nearAxes.y, 4), -0.25)
                let roomRadius = 1 / sqrt(pow(d.x / farAxes.x, 2) + pow(d.z / farAxes.y, 2))
                // Keep meaningful approach travel, with a 2cm cache/interpolation reserve.
                let minimumRadius = max(nearR * 1.25, nearR + 0.40) + 0.02
                guard roomRadius > minimumRadius else { return nil }
                let nearEye = anchor + d * nearR + SIMD3<Float>(0, nearEyeHeight, 0)
                let nearPitch = max(2 * Float.pi / 180, min(35 * Float.pi / 180,
                    atan2(nearEyeHeight, nearR) + verticalCentre))
                let nearHeading = headingOffset(eye: nearEye, anchor: anchor, halfExtents: halfExtents,
                    yaw: yaw, pitch: nearPitch, aspect: aspect, box: box)

                func farCandidate(radius: Float, pitch: Float) -> (parameters: SIMD4<Float>, score: Float)? {
                    guard radius >= minimumRadius, radius <= roomRadius,
                          pitch >= nearPitch + 0.08 else { return nil }
                    let eye = anchor + d * radius
                    let heading = headingOffset(eye: eye, anchor: anchor, halfExtents: halfExtents,
                        yaw: yaw, pitch: pitch, aspect: aspect, box: box)
                    let viewHeading = yaw + heading
                    let cosPitch = cos(pitch), sinPitch = sin(pitch)
                    // u, q and world Y are invariant during the height solve. q > 0 makes its midpoint monotonic.
                    let rays = envelope.map { point -> SIMD3<Float> in
                        let offset = point - eye
                        return SIMD3(offset.x * sin(viewHeading) - offset.z * cos(viewHeading),
                                     -offset.x * cos(viewHeading) - offset.z * sin(viewHeading), point.y - anchor.y)
                    }
                    guard rays.allSatisfy({ $0.y > 0 }) else { return nil }
                    func verticalMidpoint(_ height: Float) -> Float? {
                        var bottom: Float = .infinity, top: Float = -.infinity
                        for ray in rays {
                            let dy = ray.z - height
                            let depth = ray.y * cosPitch - dy * sinPitch
                            guard depth > 0.01 else { return nil }
                            let y = (ray.y * sinPitch + dy * cosPitch) / (depth * tangent)
                            bottom = min(bottom, y); top = max(top, y)
                        }
                        return (bottom + top) / 2
                    }
                    let target = (box.z + box.w) / 2
                    var low = nearEyeHeight + 0.40, high = maximumHeight
                    guard let lowMid = verticalMidpoint(low), let highMid = verticalMidpoint(high),
                          lowMid >= target, highMid <= target else { return nil }
                    // d(y_i)/dh = -q_i/(D_i^2*tan(FOV/2)) < 0, so both envelope extrema decrease.
                    for _ in 0..<12 {
                        let middle = (low + high) / 2
                        guard let centre = verticalMidpoint(middle) else { return nil }
                        if centre > target { low = middle } else { high = middle }
                    }
                    let height = (low + high) / 2
                    guard let interval = pitchInterval(eye: eye + SIMD3<Float>(0, height, 0),
                        heading: viewHeading, points: envelope, minimum: nearPitch + 0.08,
                        aspect: aspect, box: box), pitch >= interval.x, pitch <= interval.y else { return nil }
                    var projectedCloth: [SIMD2<Float>] = []
                    for point in clothCorners {
                        let offset = point - d * radius
                        let q = -offset.x * cos(viewHeading) - offset.z * sin(viewHeading)
                        let u = offset.x * sin(viewHeading) - offset.z * cos(viewHeading)
                        let depth = q * cosPitch + height * sinPitch
                        guard depth > 0.01 else { return nil }
                        projectedCloth.append(SIMD2(u / (depth * tangent * aspect),
                            (q * sinPitch - height * cosPitch) / (depth * tangent)))
                    }
                    var doubledArea: Float = 0
                    for corner in 0..<4 {
                        let a = projectedCloth[corner], b = projectedCloth[(corner + 1) % 4]
                        doubledArea += a.x * b.y - a.y * b.x
                    }
                    let fraction = abs(doubledArea) / (2 * readableArea)
                    guard fraction.isFinite, fraction > 0 else { return nil }
                    let angleError = (pitch - overviewPitch) / (10 * Float.pi / 180)
                    let areaError = log(fraction / overviewClothFraction)
                    // No smallest-radius/minimum-height reward: those can produce an uncomfortable posture.
                    let score = angleError * angleError + areaError * areaError
                    return (SIMD4(radius, height, pitch, heading), score)
                }
                // A bounded joint search at creation only. Room bounds constrain it; they do not choose the far eye.
                // 25 radii x 9 pitch candidates, then a 3x3 refinement. Parameters remain visual candidates.
                let radiusStep = (roomRadius - minimumRadius) / 24
                var best: (parameters: SIMD4<Float>, score: Float)?
                for pitchIndex in 0..<9 {
                    let pitch = Float(25 + pitchIndex * 5) * .pi / 180
                    for radiusIndex in 0...24 {
                        let radius = radiusIndex == 24 ? roomRadius : minimumRadius + radiusStep * Float(radiusIndex)
                        if let candidate = farCandidate(radius: radius, pitch: pitch),
                           best.map({ candidate.score < $0.score }) ?? true {
                            best = candidate
                        }
                    }
                }
                if let coarse = best {
                    for pitchOffset in -1...1 {
                        for radiusOffset in -1...1 {
                            let pitch = coarse.parameters.z + Float(pitchOffset) * 2.5 * .pi / 180
                            let radius = coarse.parameters.x + Float(radiusOffset) * radiusStep / 2
                            if let candidate = farCandidate(radius: radius, pitch: pitch),
                               candidate.score < (best?.score ?? .infinity) { best = candidate }
                        }
                    }
                }
                guard let far = best?.parameters else { return nil } // No large-FOV or out-of-room hidden fallback.
                samples.append(Sample(near: SIMD4(nearR, nearEyeHeight, nearPitch, nearHeading), far: far))
            }
            let result = RailProfile(anchor: anchor, tableHalfExtents: halfExtents, fov: lensDegrees,
                viewport: viewport, readableInsets: insets, railViewport: viewport, railInsets: insets,
                samples: samples, tableEnvelope: envelope)
            // A finite interpolation preflight; runtime legalPose remains authoritative between these samples.
            // This does not certify rail mesh occlusion, furniture clearance or all continuous paths.
            for index in 0..<(sampleCount * 4) {
                let yaw = Float(index) * 2 * .pi / Float(sampleCount * 4)
                for s in [Float(0), 0.25, 0.5, 0.75, 1] {
                    guard result.legalPose(yaw: yaw, progress: s) != nil else { return nil }
                }
            }
            return result
        }
    }

    /// Shot-relative observation. The reference eye, horizontal cue axis and lens are supplied by the rig.
    /// Only default pitch is fitted. Geometry containment does not certify cushion/mesh occlusion.
    struct ShotRailProfile {
        /// Stable through cache reuse and layout revalidation; a new fitted rail gets a new identity.
        let id: UUID
        let anchor: SIMD3<Float>
        let tableHalfExtents: SIMD2<Float>
        let viewport: CGSize
        let readableInsets: UIEdgeInsets
        let railViewport: CGSize
        let railInsets: UIEdgeInsets
        let context: UUID
        let defaultPose: Pose
        let defaultYaw: Float
        let defaultProgress: Float = 0.5
        var fov: Float { defaultPose.fov }
        var layoutMatchesRail: Bool { viewport == railViewport && readableInsets == railInsets }
        var hasReadableLayout: Bool { Self.box(viewport, readableInsets) != nil }
        private struct Sample { let near, middle, far: SIMD4<Float> }
        private let samples: [Sample]
        private let subjects: [SIMD3<Float>]
        private let balls: [SIMD3<Float>]
        private let cloth: [SIMD3<Float>]
        private let minimumReadableBallPixels: Float
        private let minimumReadableClothFraction: Float

        func preservingLens(viewport: CGSize, insets: UIEdgeInsets) -> Self {
            Self(id: id, anchor: anchor, tableHalfExtents: tableHalfExtents, viewport: viewport,
                 readableInsets: insets, railViewport: railViewport, railInsets: railInsets,
                 context: context, defaultPose: defaultPose, defaultYaw: defaultYaw,
                 samples: samples, subjects: subjects, balls: balls, cloth: cloth,
                 minimumReadableBallPixels: minimumReadableBallPixels,
                 minimumReadableClothFraction: minimumReadableClothFraction)
        }

        private func sample(_ yaw: Float) -> Sample {
            let turn = 2 * Float.pi
            let wrapped = (yaw - defaultYaw).truncatingRemainder(dividingBy: turn)
            let index = (wrapped < 0 ? wrapped + turn : wrapped) / turn * Float(samples.count)
            let i = Int(floor(index)) % samples.count, t = index - floor(index)
            func at(_ k: Int) -> Sample { samples[(i + k + samples.count) % samples.count] }
            func interpolate(_ a: SIMD4<Float>, _ b: SIMD4<Float>, _ c: SIMD4<Float>, _ d: SIMD4<Float>) -> SIMD4<Float> {
                func slope(_ p: Float, _ q: Float) -> Float { p * q > 0 ? 2 * p * q / (p + q) : 0 }
                var v = SIMD4<Float>(repeating: 0)
                for k in 0..<4 {
                    let bv=b[k]
                    let av=k == 3 ? bv + TwoViewCamera.angleDelta(bv,a[k]) : a[k]
                    let cv=k == 3 ? bv + TwoViewCamera.angleDelta(bv,c[k]) : c[k]
                    let dv=k == 3 ? cv + TwoViewCamera.angleDelta(cv,d[k]) : d[k]
                    let m0 = slope(bv-av, cv-bv), m1 = slope(cv-bv, dv-cv)
                    v[k] = (2*t*t*t-3*t*t+1)*bv + (t*t*t-2*t*t+t)*m0
                        + (-2*t*t*t+3*t*t)*cv + (t*t*t-t*t)*m1
                }
                return v
            }
            return Sample(near: interpolate(at(-1).near,at(0).near,at(1).near,at(2).near),
                          middle: interpolate(at(-1).middle,at(0).middle,at(1).middle,at(2).middle),
                          far: interpolate(at(-1).far,at(0).far,at(1).far,at(2).far))
        }

        private func parameters(yaw: Float, progress: Float) -> SIMD4<Float> {
            let p = sample(yaw), s = max(0, min(1, progress))
            let a = s <= 0.5 ? p.near : p.middle, b = s <= 0.5 ? p.middle : p.far
            let x = s <= 0.5 ? s * 2 : (s - 0.5) * 2
            // Zero slope at the default makes the two independently fitted halves C1.
            let t = x * x * (3 - 2 * x)
            var result = a + (b - a) * t
            result.w = a.w + TwoViewCamera.angleDelta(a.w,b.w) * t
            return result
        }

        func pose(yaw: Float, progress: Float) -> Pose {
            if abs(TwoViewCamera.angleDelta(defaultYaw, yaw)) < 0.0000001 && progress == defaultProgress {
                return defaultPose
            }
            let p = parameters(yaw: yaw, progress: progress)
            return .looking(eye: anchor + SIMD3(cos(yaw)*p.x,p.y,sin(yaw)*p.x),
                            yaw: yaw+p.w, pitch: -p.z, fov: fov)
        }

        func progress(yaw: Float, radius: Float) -> Float {
            let p = sample(yaw)
            let nearHalf = radius <= p.middle.x
            let a = nearHalf ? p.near.x : p.middle.x, b = nearHalf ? p.middle.x : p.far.x
            guard b-a > 0.00001 else { return defaultProgress }
            let t = max(0,min(1,(radius-a)/(b-a)))
            var low: Float = 0, high: Float = 1
            for _ in 0..<20 { let x=(low+high)/2; if x*x*(3-2*x)<t { low=x } else { high=x } }
            return (nearHalf ? 0 : 0.5) + (low+high)*0.25
        }

        /// Recover the viewing level from both distance and eye height, including a room-limited far radius.
        func progress(yaw: Float, actual: Pose) -> Float {
            let p=sample(yaw), r=hypot(actual.eye.x-anchor.x,actual.eye.z-anchor.z)
            let h=actual.eye.y-anchor.y
            let dr=max(0.05,p.far.x-p.near.x), dh=max(0.05,p.far.y-p.near.y)
            var bestS: Float=0.5, best=Float.infinity
            for i in 0...64 {
                let s=Float(i)/64, v=parameters(yaw:yaw,progress:s)
                let error=pow((v.x-r)/dr,2)+pow((v.y-h)/dh,2)
                if error<best { best=error; bestS=s }
            }
            return bestS
        }

        func nearRadius(yaw: Float) -> Float { sample(yaw).near.x }
        func farRadius(yaw: Float) -> Float { sample(yaw).far.x }
        func hasRetreatRoom(yaw: Float) -> Bool {
            let p=sample(yaw)
            return p.far.x >= p.middle.x+0.05 && p.far.y >= p.middle.y+0.025 && p.far.z >= p.middle.z+0.01
        }

        func containsSubjects(in pose: Pose) -> Bool {
            Self.contains(subjects, pose, viewport, readableInsets)
        }

        func legalPose(yaw: Float, progress: Float) -> Pose? {
            guard yaw.isFinite, progress.isFinite, layoutMatchesRail else { return nil }
            let p = pose(yaw: yaw, progress: progress), room = BakedTrainingRoom.cameraSafeHalfExtents
            guard abs(p.eye.x) <= room.x, abs(p.eye.z) <= room.y,
                  p.eye.y > anchor.y + 0.12, p.eye.y <= 3.25,
                  containsSubjects(in: p) else { return nil }
            if progress >= 1, hasRetreatRoom(yaw:yaw) {
                guard let b=Self.box(viewport,readableInsets),
                      Self.minimumBallPixels(balls,pose:p,viewport:viewport) >= minimumReadableBallPixels,
                      Self.clothFraction(cloth,pose:p,aspect:Float(viewport.width/viewport.height),box:b) >= minimumReadableClothFraction else { return nil }
            }
            return p
        }

        private static func box(_ viewport: CGSize, _ insets: UIEdgeInsets) -> SIMD4<Float>? {
            guard viewport.width.isFinite, viewport.height.isFinite, viewport.width > 1, viewport.height > 1,
                  [insets.left,insets.right,insets.top,insets.bottom].allSatisfy({ $0.isFinite && $0 >= 0 }) else { return nil }
            let b = SIMD4<Float>(Float(2*insets.left/viewport.width-1),Float(1-2*insets.right/viewport.width),
                                Float(2*insets.bottom/viewport.height-1),Float(1-2*insets.top/viewport.height))
            return b.x < 0 && b.y > 0 && b.z < 0 && b.w > 0 ? b : nil
        }

        /// Compose in the readable screen, with UIKit's downward y. This is a preference;
        /// the common subject interval remains authoritative for balls and the actual pocket mouth.
        private static func cuePitch(eye: SIMD3<Float>, heading: Float, cue: SIMD3<Float>,
                                     fraction: Float, fov: Float, box: SIMD4<Float>) -> Float {
            let d = cue - eye
            let depth = -d.x * cos(heading) - d.z * sin(heading)
            let screenY = box.w + (box.z - box.w) * fraction
            return atan(screenY * tan(fov * .pi / 360)) - atan2(d.y, depth)
        }

        private static func contains(_ points: [SIMD3<Float>], _ pose: Pose, _ viewport: CGSize, _ insets: UIEdgeInsets) -> Bool {
            guard let b = box(viewport,insets) else { return false }
            let t = tan(pose.fov * .pi / 360), aspect = Float(viewport.width/viewport.height)
            return points.allSatisfy { point in
                let p = pose.orientation.inverse.act(point-pose.eye), depth = -p.z
                guard depth.isFinite, depth > 0.01 else { return false }
                let x=p.x/(depth*t*aspect), y=p.y/(depth*t)
                return x>=b.x && x<=b.y && y>=b.z && y<=b.w
            }
        }

        /// Exact common pitch interval; horizontal containment also depends on pitch through depth.
        private static func pitchInterval(eye: SIMD3<Float>, heading: Float, points: [SIMD3<Float>],
                                          fov: Float, aspect: Float, box: SIMD4<Float>) -> SIMD2<Float>? {
            let t=tan(fov * .pi / 360)
            var lo: Float = 0.015, hi: Float = 80 * .pi / 180
            for point in points {
                let d=point-eye, q = -d.x*cos(heading)-d.z*sin(heading)
                let u=d.x*sin(heading)-d.z*cos(heading), length=hypot(q,d.y), phi=atan2(d.y,q)
                let ratio=abs(u)/((u<0 ? -box.x : box.y)*t*aspect*length)
                guard q>0, ratio.isFinite, ratio<1 else { return nil }
                let a=acos(ratio)
                lo=max(lo,atan(box.z*t)-phi,-a-phi); hi=min(hi,atan(box.w*t)-phi,a-phi)
            }
            return lo+0.00002<=hi-0.00002 ? SIMD2(lo+0.00002,hi-0.00002) : nil
        }

        /// A conservative projected sphere diameter bound; a visual readability preference, not acuity evidence.
        private static func minimumBallPixels(_ balls: [SIMD3<Float>], pose: Pose, viewport: CGSize) -> Float {
            let focal=Float(viewport.height)/(2*tan(pose.fov * .pi/360)), radius=BallPhysics.radius
            return balls.map { centre in
                let depth=simd_dot(centre-pose.eye,pose.forward)
                return depth>radius ? 2*radius*focal/(depth+radius) : 0
            }.min() ?? 0
        }

        /// Clip the actual bed polygon against the near plane, then the conservative HUD rectangle.
        private static func clothFraction(_ corners: [SIMD3<Float>], pose: Pose, aspect: Float, box: SIMD4<Float>) -> Float {
            let inverse=pose.orientation.inverse, tangent=tan(pose.fov * .pi/360)
            var local=corners.map { inverse.act($0-pose.eye) }
            var nearClipped: [SIMD3<Float>] = []
            for i in local.indices {
                let a=local[i], b=local[(i+1)%local.count], ai=a.z <= -0.01, bi=b.z <= -0.01
                if ai { nearClipped.append(a) }
                if ai != bi { nearClipped.append(a+(b-a)*((-0.01-a.z)/(b.z-a.z))) }
            }
            local=nearClipped
            guard local.count>=3 else { return 0 }
            var polygon=local.map { SIMD2($0.x/(-$0.z*tangent*aspect),$0.y/(-$0.z*tangent)) }
            for edge in 0..<4 {
                let axis=edge<2 ? 0 : 1, boundary=box[edge], greater=edge==0 || edge==2
                var clipped: [SIMD2<Float>] = []
                guard !polygon.isEmpty else { return 0 }
                for i in polygon.indices {
                    let a=polygon[i], b=polygon[(i+1)%polygon.count]
                    let ai=greater ? a[axis]>=boundary : a[axis]<=boundary
                    let bi=greater ? b[axis]>=boundary : b[axis]<=boundary
                    if ai { clipped.append(a) }
                    if ai != bi { clipped.append(a+(b-a)*((boundary-a[axis])/(b[axis]-a[axis]))) }
                }
                polygon=clipped
            }
            guard polygon.count>=3 else { return 0 }
            var doubled: Float=0
            for i in polygon.indices { let a=polygon[i],b=polygon[(i+1)%polygon.count]; doubled += a.x*b.y-a.y*b.x }
            return abs(doubled)/(2*(box.y-box.x)*(box.w-box.z))
        }

        static func candidate(defaultPose reference: Pose, cue: SIMD3<Float>, target: SIMD3<Float>?,
                              pocket: SIMD3<Float>?, pocketMouth: [SIMD3<Float>] = [],
                              anchor: SIMD3<Float>, halfExtents: SIMD2<Float>, viewport: CGSize,
                              insets: UIEdgeInsets, context: UUID,
                              clear: ((SIMD3<Float>, [SIMD3<Float>]) -> Bool)? = nil) -> Self? {
            let room=BakedTrainingRoom.cameraSafeHalfExtents
            guard [reference.eye.x,reference.eye.y,reference.eye.z,reference.fov,anchor.x,anchor.y,anchor.z,
                   halfExtents.x,halfExtents.y,cue.x,cue.y,cue.z].allSatisfy({ $0.isFinite }),
                  reference.fov>1, reference.fov<100, halfExtents.x>0, halfExtents.y>0,
                  abs(reference.eye.x)<=room.x,abs(reference.eye.z)<=room.y,
                  reference.eye.y>anchor.y+0.12,reference.eye.y<=3.25,
                  let b=box(viewport,insets) else { return nil }
            var subjects: [SIMD3<Float>] = []
            let r=BallPhysics.radius
            for ball in [cue]+(target.map { [$0] } ?? []) {
                for x in [-r,r] { for y in [-r,r] { for z in [-r,r] { subjects.append(ball+SIMD3(x,y,z)) } } }
            }
            if let pocket { subjects.append(pocket) }
            subjects += pocketMouth
            guard subjects.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }) else { return nil }
            let aspect=Float(viewport.width/viewport.height), f=reference.forward
            guard f.x.isFinite, f.y.isFinite, f.z.isFinite else { return nil }
            let psi=atan2(-f.z,-f.x), offset=reference.eye-anchor
            let theta=atan2(offset.z,offset.x), baseR=hypot(offset.x,offset.z), baseH=offset.y
            // Cached poses are interpolated, so keep a screen-space reserve rather than
            // placing fitted pocket mouths exactly on the runtime clipping boundary.
            let insetX=min(Float(8/viewport.width),(b.y-b.x)*0.04)
            let insetY=min(Float(8/viewport.height),(b.w-b.z)*0.04)
            let fitBox=b+SIMD4(insetX,-insetX,insetY,-insetY)
            let fittedInterval=pitchInterval(eye:reference.eye,heading:psi,points:subjects,
                fov:reference.fov,aspect:aspect,box:fitBox)
                ?? pitchInterval(eye:reference.eye,heading:psi,points:subjects,
                    fov:reference.fov,aspect:aspect,box:b)
            guard baseR>0.01, let interval=fittedInterval else { return nil }
            let landscape = viewport.width > viewport.height
            let preferredDefault = landscape
                ? cuePitch(eye:reference.eye,heading:psi,cue:cue,fraction:0.70,fov:reference.fov,box:b)
                : -asin(max(-1,min(1,f.y)))
            let alpha=max(interval.x,min(interval.y,preferredDefault))
            let base=Pose.looking(eye:reference.eye,yaw:psi,pitch:-alpha,fov:reference.fov)
            let delta=TwoViewCamera.angleDelta(theta,psi)
            let balls=[cue]+(target.map { [$0] } ?? [])
            func sightlinesClear(_ eye: SIMD3<Float>) -> Bool {
                clear?(eye, TwoViewCamera.ballSilhouettes(eye:eye,centers:balls)) ?? true
            }
            guard sightlinesClear(reference.eye) else { return nil }
            let clothHalf=SIMD2(min(halfExtents.x,AngleSceneCalculator.innerLength/2),
                                min(halfExtents.y,AngleSceneCalculator.innerWidth/2))
            let cloth=[SIMD3(-clothHalf.x,Float(0),-clothHalf.y),SIMD3(clothHalf.x,Float(0),-clothHalf.y),
                       SIMD3(clothHalf.x,Float(0),clothHalf.y),SIMD3(-clothHalf.x,Float(0),clothHalf.y)].map { $0+anchor }
            // Working scale preferences: retain >=80% of baseline, with a 35% HUD cloth-area candidate.
            // A baseline already below those candidates is not silently magnified or declared readable.
            let baselinePixels=minimumBallPixels(balls,pose:base,viewport:viewport)
            let baselineArea=clothFraction(cloth,pose:base,aspect:aspect,box:b)
            let minimumPixels=baselinePixels*0.80
            let minimumArea=max(baselineArea*0.80,min(baselineArea,0.35))
            let targetCentre: SIMD3<Float> = target ?? cue
            let pocketCentre: SIMD3<Float> = pocket ?? targetCentre
            var focusSum: SIMD3<Float> = cue + targetCentre
            focusSum += pocketCentre
            let focus: SIMD3<Float> = focusSum / Float(3)
            let cueHeading = atan2(reference.eye.z-cue.z,reference.eye.x-cue.x)
            let cueHeadingOffset = TwoViewCamera.angleDelta(cueHeading,psi)
            func footprint(_ yaw: Float) -> Float {
                let axes=halfExtents+SIMD2<Float>(repeating:0.15)
                return pow(pow(cos(yaw)/axes.x,4)+pow(sin(yaw)/axes.y,4),-0.25)
            }
            let baseFootprint=footprint(theta)
            var samples: [Sample] = []
            // Bounded creation work. Cache interpolation has runtime containment guards, not a path certificate.
            for i in 0..<72 {
                let yaw: Float = theta + Float(i) * (2 * Float.pi / 72)
                let d = SIMD3<Float>(cos(yaw), 0, sin(yaw))
                let maxR=min((room.x-abs(anchor.x))/max(0.00001,abs(d.x)),
                             (room.y-abs(anchor.z))/max(0.00001,abs(d.z)))
                let middleR=i==0 ? baseR : min(maxR,baseR*footprint(yaw)/baseFootprint)
                let eye: SIMD3<Float> = anchor + d * middleR + SIMD3<Float>(0,baseH,0)
                let sideWeight: Float = (1-cos(yaw-theta))/2
                let composedFocus = landscape ? focus + (anchor-focus)*sideWeight : focus
                let toFocus: SIMD3<Float> = eye - composedFocus
                let focusHeading: Float = atan2(toFocus.z,toFocus.x)
                let w=(1+cos(yaw-theta))/2
                let localCueHeading = atan2(eye.z-cue.z,eye.x-cue.x) + cueHeadingOffset*w
                var heading: Float = i == 0 ? psi : landscape
                    ? localCueHeading + TwoViewCamera.angleDelta(localCueHeading,focusHeading)*sideWeight
                    : yaw + TwoViewCamera.angleDelta(yaw,focusHeading)*(1-w)+delta*w
                var midInterval=pitchInterval(eye:eye,heading:heading,points:subjects,
                    fov:reference.fov,aspect:aspect,box:fitBox)
                if i != 0, landscape, midInterval == nil {
                    // Cue centring is a preference. When a near-rail shot cannot fit,
                    // yield continuously toward its shared subject region before stopping the orbit.
                    let origin=heading, correction=TwoViewCamera.angleDelta(origin,focusHeading)
                    var last: Float=0
                    for step in 1...12 {
                        let fraction=Float(step)/12
                        let candidate=origin+correction*fraction
                        if let range=pitchInterval(eye:eye,heading:candidate,points:subjects,
                            fov:reference.fov,aspect:aspect,box:fitBox) {
                            var low=last, high=fraction
                            for _ in 0..<10 {
                                let middle=(low+high)/2
                                if pitchInterval(eye:eye,heading:origin+correction*middle,points:subjects,
                                    fov:reference.fov,aspect:aspect,box:fitBox) != nil { high=middle }
                                else { low=middle }
                            }
                            // Keep an interior reserve for the interpolated path between cache nodes.
                            let interior=origin+correction*min(1,high+0.04)
                            if let interiorRange=pitchInterval(eye:eye,heading:interior,points:subjects,
                                fov:reference.fov,aspect:aspect,box:fitBox) {
                                heading=interior; midInterval=interiorRange
                            } else { heading=candidate; midInterval=range }
                            break
                        }
                        last=fraction
                    }
                }
                let preferred: Float = landscape
                    ? cuePitch(eye:eye,heading:heading,cue:cue,fraction:0.70,fov:reference.fov,box:b)
                    : atan2(baseH-(focus.y-anchor.y),max(Float(0.01),hypot(toFocus.x,toFocus.z)))
                let midPitch: Float = i == 0 ? alpha : midInterval.map { max($0.x,min($0.y,preferred)) } ?? preferred
                let mid=SIMD4<Float>(middleR,baseH,midPitch,TwoViewCamera.angleDelta(yaw,heading))
                var near=mid
                // Take the closest lower/flatter candidate that still contains the current shot ROI.
                for step in stride(from:12,through:1,by:-1) {
                    let t=Float(step)/12, radius=middleR*(1-0.22*t), height=max(0.30,baseH*(1-0.45*t))
                    let e=anchor+d*radius+SIMD3<Float>(0,height,0)
                    if let range=pitchInterval(eye:e,heading:heading,points:subjects,
                        fov:reference.fov,aspect:aspect,box:fitBox), range.x<=midPitch,
                       sightlinesClear(e) {
                        let preferredNear = landscape
                            ? cuePitch(eye:e,heading:heading,cue:cue,fraction:0.70+0.08*t,fov:reference.fov,box:b)
                            : midPitch*(1-0.35*t)
                        let pitch=max(range.x,min(min(range.y,midPitch),preferredNear))
                        near=SIMD4(radius,height,pitch,mid.w); break
                    }
                }
                var far=mid, best=Float.infinity
                let overviewPitch: Float = 35 * Float.pi / 180
                let headingLimit: Float = 15 * Float.pi / 180 // Working composition correction, not a new orbit.
                let radiusSpan: Float = max(Float(0),maxR-middleR)
                let heightSpan: Float = max(Float(0),Float(3.25)-anchor.y-baseH)
                func axisOffsets(span: Float, minimum: Float) -> [Float] {
                    guard span >= minimum else { return [] }
                    // Absolute local probes cannot grow coarser merely because the room is large.
                    var values: [Float] = [minimum,0.05,0.075,0.10,0.125,0.15,0.175,0.20,0.25,0.30,0.40,0.60]
                    for k in 0...8 {
                        let u: Float = Float(k)/Float(8)
                        values.append(minimum+(span-minimum)*u*u)
                    }
                    values=values.filter { $0>=minimum && $0<=span }.sorted()
                    var unique: [Float] = []
                    for value in values where unique.last.map({ abs($0-value)>0.0001 }) ?? true { unique.append(value) }
                    return unique
                }
                func farCandidate(radius: Float, height: Float, headingCorrection: Float)
                    -> (parameters: SIMD4<Float>, score: Float)? {
                    guard radius>=middleR+0.10, radius<=maxR, height>=baseH+0.05,
                          height<=Float(3.25)-anchor.y, abs(headingCorrection)<=headingLimit else { return nil }
                    let farHeading: Float = heading+headingCorrection
                    let farEye: SIMD3<Float> = anchor+d*radius+SIMD3<Float>(0,height,0)
                    guard let range=pitchInterval(eye:farEye,heading:farHeading,points:subjects,
                        fov:reference.fov,aspect:aspect,box:fitBox) else { return nil }
                    let low: Float = max(range.x,midPitch+Float(0.025))
                    let high: Float = range.y
                    guard low<=high else { return nil }
                    // The legal interval, not 35 degrees, determines available postures.
                    let preferredFar = landscape
                        ? cuePitch(eye:farEye,heading:farHeading,cue:cue,fraction:0.61,fov:reference.fov,box:b)
                        : overviewPitch
                    let pitches: [Float] = [low,low+(high-low)*0.25,(low+high)*0.5,
                        low+(high-low)*0.75,high,max(low,min(high,preferredFar))]
                    var candidate: (parameters: SIMD4<Float>, score: Float)?
                    for pitch in pitches {
                        let p=Pose.looking(eye:farEye,yaw:farHeading,pitch:-pitch,fov:reference.fov)
                        let pixels: Float = minimumBallPixels(balls,pose:p,viewport:viewport)
                        let area: Float = clothFraction(cloth,pose:p,aspect:aspect,box:b)
                        guard pixels>=minimumPixels*1.002, area>=minimumArea*1.002 else { continue }
                        let angleError: Float = (pitch-preferredFar)/(10 * Float.pi/180)
                        let travelPenalty: Float = max(Float(0),Float(0.35)-(radius-middleR))*Float(2)
                        let areaError: Float = log(max(Float(0.0001),area)/(landscape ? Float(0.50) : Float(0.40)))
                        let heightError: Float = (height-baseH)/Float(0.40)
                        let headingError: Float = headingCorrection/headingLimit
                        let postureCost: Float = angleError*angleError
                        let areaCost: Float = areaError*areaError
                        let heightCost: Float = heightError*heightError
                        let headingCost: Float = headingError*headingError
                        let scaleReward: Float = pixels*Float(0.015)
                        let score: Float = postureCost+areaCost+travelPenalty+heightCost+headingCost-scaleReward
                        if candidate.map({ score<$0.score }) ?? true {
                            candidate=(SIMD4(radius,height,pitch,mid.w+headingCorrection),score)
                        }
                    }
                    return candidate
                }
                let radii=axisOffsets(span:radiusSpan,minimum:0.10)
                let heights=axisOffsets(span:heightSpan,minimum:0.05)
                for dr in radii { for dh in heights { for k in -2...2 {
                    let correction: Float = Float(k)*headingLimit/Float(2)
                    if let candidate=farCandidate(radius:middleR+dr,height:baseH+dh,headingCorrection:correction),
                       candidate.score<best { best=candidate.score; far=candidate.parameters }
                } } }
                // Refine an actually feasible neighborhood. All candidates recheck the same continuous inequalities.
                if best.isFinite {
                    for step in [Float(0.025),0.0125] {
                        let origin=far
                        for ri in -1...1 { for hi in -1...1 { for gi in -1...1 {
                            let correction: Float = origin.w-mid.w+Float(gi)*headingLimit*step/Float(0.10)
                            if let candidate=farCandidate(radius:origin.x+Float(ri)*step,
                                height:origin.y+Float(hi)*step,headingCorrection:correction),candidate.score<best {
                                best=candidate.score; far=candidate.parameters
                            }
                        } } }
                    }
                }
                samples.append(Sample(near:near,middle:mid,far:far))
            }
            let result=Self(id:UUID(),anchor:anchor,tableHalfExtents:halfExtents,viewport:viewport,readableInsets:insets,
                railViewport:viewport,railInsets:insets,context:context,defaultPose:base,defaultYaw:theta,
                samples:samples,subjects:subjects,balls:balls,cloth:cloth,
                minimumReadableBallPixels:minimumPixels,minimumReadableClothFraction:minimumArea)
            return result.legalPose(yaw:theta,progress:0.5) != nil ? result : nil
        }
    }

    /// Tangent circle of each visible ball, sampled in world space. Unlike a point
    /// directly below its centre, these are the actual outlines seen from this eye.
    static func ballSilhouettes(eye: SIMD3<Float>, centers: [SIMD3<Float>]) -> [SIMD3<Float>] {
        centers.flatMap { center -> [SIMD3<Float>] in
            let offset=eye-center, distance=simd_length(offset), r=BallPhysics.radius
            guard distance>r else { return [center] }
            let normal=offset/distance
            let reference: SIMD3<Float> = abs(normal.y)<0.99 ? SIMD3(0,1,0) : SIMD3(1,0,0)
            let up=simd_normalize(reference-normal*simd_dot(reference,normal))
            let right=simd_cross(up,normal)
            let circleCenter=center+normal*(r*r/distance)
            let circleRadius=r*sqrt(1-r*r/(distance*distance))
            return (0..<8).map { i in
                let angle=Float(i)*(.pi/4)
                return circleCenter+(up*cos(angle)+right*sin(angle))*circleRadius
            }
        }
    }

    /// Entry-only framing. Raising the gaze or widening the lens cannot remove a rail occlusion;
    /// first find a clear eye using the host's actual table geometry, then choose the frozen lens.
    /// The protected samples are a cue contact/lower-contour ROI, not a whole-scene visibility proof.
    static func firstPersonEntry(reference: Pose, cue: SIMD3<Float>, strike: SIMD3<Float>,
                                 target: SIMD3<Float>?, viewport: CGSize, insets: UIEdgeInsets,
                                 maximumEyeY: Float,
                                 clear: (SIMD3<Float>, [SIMD3<Float>]) -> Bool) -> Pose? {
        let bearing = simd_normalize(SIMD3(reference.forward.x, 0, reference.forward.z))
        guard bearing.x.isFinite, bearing.z.isFinite,
              viewport.width > 1, viewport.height > 1, maximumEyeY >= reference.eye.y else { return nil }
        let right = SIMD3(-bearing.z, 0, bearing.x)
        let radius = BallPhysics.radius
        let lower = cue + SIMD3<Float>(0, -radius * 0.85, 0)
        let lowerSideCenter = cue - bearing * (radius * 0.4) + SIMD3<Float>(0, -radius * 0.5, 0)
        let sideOffset = right * (radius * 0.7)
        let protected: [SIMD3<Float>] = [strike, lower, lowerSideCenter + sideOffset, lowerSideCenter - sideOffset]
        var eye = reference.eye
        if !clear(eye, protected) {
            let highEye = SIMD3(eye.x, maximumEyeY, eye.z)
            guard clear(highEye, protected) else { return nil }
            var low = eye.y, high = maximumEyeY
            for _ in 0..<16 {
                let middle = (low + high) * 0.5
                if clear(SIMD3(eye.x, middle, eye.z), protected) { high = middle }
                else { low = middle }
            }
            eye.y = min(maximumEyeY, high + 0.005)
            guard clear(eye, protected) else { return nil }
        }
        let centers = [cue] + (target.map { [$0] } ?? [])
        let pitches = centers.map { atan2($0.y - eye.y, hypot($0.x - eye.x, $0.z - eye.z)) }
        let pitch = ((pitches.min() ?? 0) + (pitches.max() ?? 0)) * 0.5
        let yaw = atan2(-bearing.z, -bearing.x)
        var result = Pose.looking(eye: eye, yaw: yaw, pitch: pitch, fov: reference.fov)
        let halfX = Float(1 - 2 * max(insets.left, insets.right) / viewport.width)
        let halfY = Float(1 - 2 * max(insets.top, insets.bottom) / viewport.height)
        guard halfX > 0, halfY > 0 else { return nil }
        let aspect = Float(viewport.width / viewport.height)
        var tangent = tan(reference.fov * .pi / 360)
        for center in centers {
            for x in [-radius, radius] {
                for y in [-radius, radius] {
                    for z in [-radius, radius] {
                        let local = result.orientation.inverse.act(center + SIMD3(x, y, z) - eye)
                        let depth = -local.z
                        guard depth > 0.01 else { return nil }
                        tangent = max(tangent, abs(local.x) / (depth * aspect * halfX),
                                      abs(local.y) / (depth * halfY))
                    }
                }
            }
        }
        result.fov = 2 * atan(tangent * 1.08) * 180 / .pi
        guard result.fov.isFinite, result.fov <= 70 else { return nil }
        return result
    }

    /// v4 trial: two controls only. XZ metres, Y up; no shot/table fit or visibility solver.
    struct SimpleShot {
        var cue: SIMD3<Float>
        var strike: SIMD3<Float>
        var aim: SIMD3<Float>
        var surfaceY: Float
        var viewport: CGSize
        var distance: Float = 1.65
        var nearPose: Pose? = nil
        var usesMergedRange = false
        var surface: CameraSurface? = nil
        var actualDistance: Float { surface?.distance ?? distance }
        static let horizontalFOV: Float = 64

        var pose: Pose {
            if let surface { return surface.pose }
            let d = distance
            let radius = BallPhysics.radius
            let beta0 = atan2(Float(0.65) - radius, Float(1.65))
            let betaLow = Float(8) * .pi / 180
            let beta = betaLow + (2 * beta0 - 2 * betaLow) * d * d / (d * d + 1.65 * 1.65)
            let height = radius + d * tan(beta)
            let aspect = Float(max(1, viewport.width) / max(1, viewport.height))
            let fov = 2 * atan(tan(Self.horizontalFOV * .pi / 360) / aspect)
            let pitch = beta - atan(Float(0.34) * tan(fov / 2))
            let axis = simd_normalize(SIMD3<Float>(aim.x, 0, aim.z))
            // The actual shaft plane is centred, including a side-spin strike offset.
            let eye = SIMD3(strike.x, surfaceY + height, strike.z) - axis * d
            let base = Pose.looking(eye: eye, yaw: atan2(-axis.z, -axis.x), pitch: -pitch, fov: fov * 180 / .pi)
            guard usesMergedRange, distance < 1.65, let nearPose else { return base }
            let u = max(0, min(1, (1.65 - distance) / 0.75))
            let blend = u * u * (3 - 2 * u)
            return base.interpolated(to: nearPose, fraction: blend)
        }

        mutating func move(points: Float) {
            if surface != nil { surface?.move(points: points); return }
            // Fixed numerical/lens limits only, identical for every formation. No ROI limits.
            let minimum: Float = usesMergedRange ? 0.9 : 0.15
            let maximum: Float = usesMergedRange ? 2.0 : 12
            distance = max(minimum, min(maximum, distance * exp2(2 * points / Float(max(1, viewport.height)))))
        }
    }

    /// Arc-length clock for automatic surface travel. The local limiting rate wins:
    /// Base rates are 3.6 m/s, 180 degrees/s and 80 FOV degrees/s,
    /// multiplied by 1 + 0.25 * path length in metres for each request.
    /// The path stays on CameraSurface; only its time parameter is remapped.
    struct SurfaceMotion {
        static let linearSpeed: Float = 3.6
        static let angularSpeed: Float = .pi
        static let lensSpeed: Float = 80
        static let distanceGainPerMetre: Float = 0.25
        static let rampTime: Float = 0.16
        private let cumulative: [Float]
        let cruiseTime: Float
        let pathLength: Float
        let speedGain: Float
        let ramp: Float
        let peak: Float
        let duration: Float

        static func angleBetween(_ a: simd_quatf, _ b: simd_quatf) -> Float {
            let relative = a.inverse * b
            // atan2 stays well conditioned for tiny frame/sample angles, unlike acos(dot).
            return 2 * atan2(simd_length(relative.imag), abs(relative.real))
        }

        init(path: (Float) -> Pose) {
            let segments = 256
            var times: [Float] = [0]
            times.reserveCapacity(segments + 1)
            var previous = path(0)
            var length: Float = 0
            for i in 1...segments {
                let next = path(Float(i) / Float(segments))
                let segmentLength = simd_distance(previous.eye, next.eye)
                length += segmentLength
                let translation = segmentLength / Self.linearSpeed
                let rotation = Self.angleBetween(previous.orientation, next.orientation) / Self.angularSpeed
                let lens = abs(next.fov - previous.fov) / Self.lensSpeed
                times.append(times.last! + max(translation, rotation, lens))
                previous = next
            }
            pathLength = length
            let gain = 1 + Self.distanceGainPerMetre * length
            speedGain = gain
            cumulative = times.map { $0 / gain }
            cruiseTime = cumulative.last!
            // Short moves have no cruise plateau: lower the peak instead of overshooting
            // or forcing every tiny move to spend the same minimum duration.
            peak = min(1, sqrt(cruiseTime / Self.rampTime))
            ramp = Self.rampTime * peak
            duration = cruiseTime > 0.00001 ? cruiseTime / peak + ramp : 0
        }

        func fraction(at elapsed: Float) -> Float {
            guard duration > 0, elapsed < duration else { return 1 }
            guard elapsed > 0 else { return 0 }
            func rampDistance(_ t: Float) -> Float {
                peak * (t - ramp / .pi * sin(.pi * t / ramp)) / 2
            }
            let distance: Float
            if elapsed < ramp { distance = rampDistance(elapsed) }
            else if elapsed > duration - ramp { distance = cruiseTime - rampDistance(duration - elapsed) }
            else { distance = peak * (elapsed - ramp / 2) }
            var low = 0, high = cumulative.count - 1
            while high - low > 1 {
                let middle = (low + high) / 2
                if cumulative[middle] < distance { low = middle } else { high = middle }
            }
            let span = cumulative[high] - cumulative[low]
            let local = span > 0 ? (distance - cumulative[low]) / span : 0
            return (Float(low) + max(0, min(1, local))) / Float(cumulative.count - 1)
        }
    }

    private(set) var simpleShot: SimpleShot?
    private var displayedSurface: CameraSurface?
    private var surfaceTransitionOrigin: CameraSurface?
    private var surfaceMotion: SurfaceMotion?
    private var surfaceSamples: [(time: TimeInterval, surface: CameraSurface)] = []
    /// Two 60 Hz input intervals cover ordinary callback batching, independent of render FPS.
    /// No prediction or inertial extrapolation: the final real input drains within this delay.
    static let surfaceInputDelay: TimeInterval = 1.0 / 30.0

    @discardableResult
    func surfacePan(delta: SIMD2<Float>, at time: TimeInterval = CACurrentMediaTime()) -> Bool {
        guard delta.x.isFinite, delta.y.isFinite, time.isFinite, delta != .zero,
              mode == .thirdPerson, simpleShot?.surface != nil else { return false }
        _ = beginTemporaryObservation()
        guard var shot = simpleShot, var target = shot.surface else { return false }
        if surfaceSamples.isEmpty {
            surfaceSamples.append((time - Self.surfaceInputDelay / 2, displayedSurface ?? target))
        }
        // Both axes produce one target sample; only the display loop writes the camera node.
        target.orbit(points: delta.x)
        target.move(points: delta.y)
        shot.surface = target; simpleShot = shot
        let timestamp = max(time, surfaceSamples.last!.time)
        if timestamp == surfaceSamples.last!.time { surfaceSamples[surfaceSamples.count - 1] = (timestamp, target) }
        else { surfaceSamples.append((timestamp, target)) }
        return true
    }

    private func updateSurfaceInput(at time: TimeInterval) {
        guard !surfaceSamples.isEmpty else { return }
        let sampleTime = time - Self.surfaceInputDelay
        while surfaceSamples.count > 1, surfaceSamples[1].time <= sampleTime {
            surfaceSamples.removeFirst()
        }
        let first = surfaceSamples[0]
        if surfaceSamples.count > 1 {
            let next = surfaceSamples[1]
            displayedSurface = first.surface.interpolated(to: next.surface,
                fraction: Float((sampleTime - first.time) / (next.time - first.time)))
        } else {
            displayedSurface = first.surface
            if sampleTime >= first.time { surfaceSamples.removeAll(keepingCapacity: true) }
        }
        if let displayedSurface { pose = displayedSurface.pose }
    }

    /// nil selects the speed clock; explicit durations are for legacy/accessibility paths.
    func enterSimpleShot(_ shot: SimpleShot, duration: Float?) {
        if connector != nil, let current = simpleShot?.surface, let target = shot.surface,
           current.cue == target.cue, current.bearing == target.bearing,
           current.travel == target.travel, current.viewport == target.viewport { return }
        surfaceTransitionOrigin = simpleShot?.surface != nil && mode == .thirdPerson ? displayedSurface : nil
        surfaceSamples.removeAll(keepingCapacity: true)
        simpleShot = shot
        profile = nil; shotProfile = nil
        mode = .thirdPerson; owner = .automatic; entryContext = context
        temporaryObserving = false; observationReturn = nil; memoryDestination = nil
        yaw = atan2(-shot.aim.z, -shot.aim.x); targetYaw = yaw
        progress = log2(shot.distance / 1.65); targetProgress = progress
        headYaw = 0; targetHeadYaw = 0
        suspendedPose = false; railMotionLimited = false
        let originPose = pose
        let originSurface = surfaceTransitionOrigin
        surfaceMotion = duration == nil ? SurfaceMotion { fraction in
            if let originSurface, let target = shot.surface {
                return originSurface.interpolated(to: target, fraction: fraction).pose
            }
            return originPose.interpolated(to: shot.pose, fraction: fraction)
        } : nil
        let travelTime = duration ?? surfaceMotion!.duration
        connector = travelTime > 0 ? (pose, 0, travelTime) : nil
        if travelTime <= 0 { pose = shot.pose; displayedSurface = shot.surface }
        if shot.surface == nil { displayedSurface = nil; surfaceTransitionOrigin = nil }
        requestRevision &+= 1
    }

    func retreatSurface(cue: SIMD3<Float>, duration: Float?, bearing: Float? = nil) -> Bool {
        guard var shot = simpleShot, var surface = shot.surface else { return false }
        surface.cue = SIMD2(cue.x,cue.z); surface.travel = 1
        if let bearing { surface.bearing = bearing }
        shot.surface = surface
        enterSimpleShot(shot, duration: duration)
        return true
    }

    func updateSimpleShot(cue: SIMD3<Float>, strike: SIMD3<Float>, aim: SIMD3<Float>, nearPose: Pose? = nil) {
        guard mode == .thirdPerson, var shot = simpleShot, simd_length_squared(aim) > 0.000001 else { return }
        // Surface reference stays frozen until an explicit entry/new-shot request.
        // Rendering/physics cue updates must never carry the camera with a rolling ball.
        if shot.surface != nil { return }
        shot.cue = cue; shot.strike = strike; shot.aim = aim
        if shot.usesMergedRange { shot.nearPose = nearPose }
        simpleShot = shot
        yaw = atan2(-aim.z, -aim.x); targetYaw = yaw
        // Automatic entry keeps its 0.3s connector. Manual aiming is direct, with no lag.
        if connector == nil { pose = shot.pose }
    }

    struct Snapshot {
        let mode: CameraRig.PlayerView
        let owner: Owner
        let pose: Pose
        let profile: RailProfile?
        let shotProfile: ShotRailProfile?
        let simpleShot: SimpleShot?
        let defaultPose: Pose?
        let temporaryObserving: Bool
        let yaw, progress, headYaw: Float
        let firstPersonBase: Pose?
        let context: UUID
        let entryContext: UUID?
        let firstPersonMemory, thirdPersonMemory: ModeMemory?
    }

    struct ModeMemory {
        let mode: CameraRig.PlayerView
        let owner: Owner
        let pose: Pose
        let profile: RailProfile?
        let yaw, progress, headYaw: Float
        let firstPersonBase: Pose?
        let context: UUID
    }

    private(set) var mode: CameraRig.PlayerView = .thirdPerson
    private(set) var owner: Owner = .automatic
    private(set) var requestRevision: UInt64 = 0
    private(set) var pose: Pose
    private(set) var profile: RailProfile?
    private(set) var shotProfile: ShotRailProfile?
    private(set) var temporaryObserving = false
    private var observationReturn: Pose?
    var defaultPose: Pose? {
        if mode == .thirdPerson, var shot = simpleShot { shot.distance = 1.65; shot.surface?.travel = 0.5; return shot.pose }
        return mode == .thirdPerson ? shotProfile?.defaultPose : firstPersonBase
    }
    private(set) var yaw: Float = .pi
    private(set) var progress: Float = 1
    private(set) var headYaw: Float = 0
    private var targetYaw: Float = .pi
    private var targetProgress: Float = 1
    private var targetHeadYaw: Float = 0
    private var firstPersonBase: Pose?
    private var connector: (origin: Pose, elapsed: Float, duration: Float)?
    private var context = UUID()
    private var entryContext: UUID?
    private var firstPersonMemory: ModeMemory?
    private var thirdPersonMemory: ModeMemory?
    private var memoryDestination: Pose?
    private var layout: (viewport: CGSize, insets: UIEdgeInsets)?
    private(set) var layoutRevision: UInt64 = 0
    private(set) var railMotionLimited = false
    var layoutContainsSubjects: Bool? {
        guard mode == .thirdPerson else { return nil }
        return shotProfile.map { $0.containsSubjects(in: pose) } ?? profile.map { $0.containsSubjects(in: pose) }
    }

    init(pose: Pose) { self.pose = pose }

    var isTransitioning: Bool { connector != nil }
    var hasPendingMotion: Bool {
        !surfaceSamples.isEmpty || connector != nil || observationReturn != nil || abs(yaw - targetYaw) > 0.00001
            || abs(progress - targetProgress) > 0.00001 || abs(headYaw - targetHeadYaw) > 0.00001
    }

    @discardableResult
    func enterShotThirdPerson(_ replacement: ShotRailProfile, duration: Float) -> Bool {
        guard replacement.context == context, replacement.layoutMatchesRail,
              replacement.legalPose(yaw: replacement.defaultYaw, progress: replacement.defaultProgress) != nil else {
            railMotionLimited = true; return false
        }
        saveActiveMemory()
        profile = nil
        thirdPersonMemory = nil
        shotProfile = replacement
        simpleShot = nil
        mode = .thirdPerson; owner = .automatic; entryContext = context
        temporaryObserving = false; observationReturn = nil; memoryDestination = nil
        yaw = replacement.defaultYaw; targetYaw = yaw
        progress = replacement.defaultProgress; targetProgress = progress
        suspendedPose = false; railMotionLimited = false
        connector = (pose, 0, max(0.1, duration))
        requestRevision &+= 1
        return true
    }

    /// Rebase the destination without moving the actual displayed eye. Old-context returns are discarded.
    @discardableResult
    func rebaseShotThirdPersonPreservingPose(_ replacement: ShotRailProfile) -> Bool {
        guard mode == .thirdPerson, replacement.context == context, replacement.layoutMatchesRail else { return false }
        // A second drag on the same cached rail must not quantize the settled progress again.
        if shotProfile?.id == replacement.id, shotProfile?.layoutMatchesRail == true { return true }
        shotProfile = replacement; profile = nil; thirdPersonMemory = nil
        entryContext = context; memoryDestination = nil; observationReturn = nil
        let offset = pose.eye - replacement.anchor
        yaw = atan2(offset.z, offset.x); targetYaw = yaw
        progress = replacement.progress(yaw: yaw, actual: pose); targetProgress = progress
        connector = nil; suspendedPose = true; railMotionLimited = false
        requestRevision &+= 1
        return true
    }

    /// Touch-down is a real ownership event; it captures the actual pose even during a return.
    @discardableResult
    func beginTemporaryObservation() -> Bool {
        if mode == .thirdPerson, simpleShot != nil {
            if simpleShot?.surface != nil, !temporaryObserving, let displayedSurface {
                // Take over the currently visible surface, including mid-button transition.
                connector = nil; surfaceTransitionOrigin = nil; surfaceMotion = nil
                surfaceSamples.removeAll(keepingCapacity: true)
                simpleShot?.surface = displayedSurface
            }
            temporaryObserving = true; owner = .manual
            observationReturn = nil; memoryDestination = nil
            // A first entry from a non-surface camera still needs its connector.
            suspendedPose = false
            requestRevision &+= 1
            return true
        }
        guard (mode == .thirdPerson ? shotProfile?.context == context && shotProfile?.layoutMatchesRail == true
               : entryContext == context && firstPersonBase != nil) else { return false }
        if temporaryObserving { return true }
        let returning = observationReturn != nil || connector != nil || suspendedPose
        temporaryObserving = true; observationReturn = nil; memoryDestination = nil
        owner = .manual; suspendedPose = true
        targetYaw = yaw; targetProgress = progress; targetHeadYaw = headYaw
        connector = nil
        if mode == .thirdPerson, let shotProfile, returning,
           simd_length(shotProfile.pose(yaw:yaw,progress:progress).eye-pose.eye) > 0.000001 {
            let offset = pose.eye-shotProfile.anchor
            yaw = atan2(offset.z,offset.x); targetYaw = yaw
            progress = shotProfile.progress(yaw:yaw,actual: pose); targetProgress = progress
        } else if mode == .firstPerson, returning, let base = firstPersonBase {
            headYaw = Self.angleDelta(atan2(-base.forward.z,-base.forward.x),atan2(-pose.forward.z,-pose.forward.x))
            targetHeadYaw = headYaw
        }
        requestRevision &+= 1
        return true
    }

    func endTemporaryObservation(duration: Float = 0.8) {
        temporaryObserving = false
        if mode == .thirdPerson, simpleShot != nil {
            // Drain only the last real samples (at most 33ms), then hold exactly.
            // There is no extrapolated velocity or inertial return after release.
            owner = .manual
            observationReturn = nil; memoryDestination = nil
            targetYaw = yaw; targetProgress = progress; targetHeadYaw = headYaw
            requestRevision &+= 1
            return
        }
        if mode == .thirdPerson, shotProfile != nil {
            // v3.1: release means stop where the user is actually looking, including mid-follow.
            owner = .manual
            observationReturn = nil; memoryDestination = nil; connector = nil
            targetYaw = yaw; targetProgress = progress; targetHeadYaw = headYaw
            suspendedPose = true
            requestRevision &+= 1
            return
        }
        returnToShotDefault(duration: duration)
    }

    private func returnToShotDefault(duration: Float) {
        guard entryContext == context, let destination = defaultPose,
              mode != .thirdPerson || (shotProfile?.context == context && shotProfile?.layoutMatchesRail == true) else {
            observationReturn = nil; connector = nil; suspendedPose = true; return
        }
        owner = .automatic; memoryDestination = nil; observationReturn = destination
        targetYaw = yaw; targetProgress = progress; targetHeadYaw = headYaw
        connector = (pose,0,max(0.1,duration)); suspendedPose = false
        requestRevision &+= 1
    }

    func resetTemporaryObservation(duration: Float = 0.8) {
        temporaryObserving = false
        returnToShotDefault(duration: duration)
    }

    func enterThirdPerson(_ profile: RailProfile, yaw: Float, duration: Float, progress entryProgress: Float = 1) {
        guard yaw.isFinite, entryProgress.isFinite,
              profile.legalPose(yaw: yaw, progress: entryProgress) != nil else {
            railMotionLimited = true
            return
        }
        saveActiveMemory()
        simpleShot = nil
        shotProfile = nil; temporaryObserving = false; observationReturn = nil
        requestRevision &+= 1
        entryContext = context
        memoryDestination = nil
        suspendedPose = false
        self.profile = profile
        mode = .thirdPerson
        owner = .automatic
        self.yaw = yaw
        targetYaw = yaw
        progress = max(0, min(1, entryProgress))
        targetProgress = progress
        connector = (pose, 0, max(0.1, duration))
        railMotionLimited = false
    }

    /// A new layout/table profile does not teleport the displayed eye. The next explicit gesture reconnects.
    @discardableResult
    func replaceThirdPersonProfilePreservingPose(_ replacement: RailProfile) -> Bool {
        guard mode == .thirdPerson, replacement.layoutMatchesRail else { return false }
        let offset = pose.eye - replacement.anchor
        guard offset.x.isFinite, offset.z.isFinite else { return false }
        profile = replacement
        yaw = atan2(offset.z, offset.x) // Eye bearing, never the independently composed gaze heading.
        targetYaw = yaw
        progress = replacement.progress(yaw: yaw, radius: hypot(offset.x, offset.z))
        targetProgress = progress
        entryContext = context
        connector = nil
        memoryDestination = nil
        suspendedPose = true
        requestRevision &+= 1
        railMotionLimited = false
        saveActiveMemory()
        return true
    }

    func enterFirstPerson(_ base: Pose, duration: Float) {
        saveActiveMemory()
        // A surface pan/connector must not keep owning motion after a first-person request.
        simpleShot = nil
        displayedSurface = nil
        surfaceTransitionOrigin = nil
        surfaceMotion = nil
        surfaceSamples.removeAll(keepingCapacity: true)
        temporaryObserving = false; observationReturn = nil
        requestRevision &+= 1
        entryContext = context
        memoryDestination = nil
        suspendedPose = false
        mode = .firstPerson
        owner = .automatic
        firstPersonBase = base
        headYaw = 0
        targetHeadYaw = 0
        connector = (pose, 0, max(0.1, duration))
    }

    /// New shot observation is context-owned; the legacy table rail keeps its table-owned semantics.
    func setViewingContext(_ value: UUID) {
        guard context != value else { return }
        context = value
        surfaceSamples.removeAll(keepingCapacity: true)
        surfaceTransitionOrigin = nil
        surfaceMotion = nil
        if let displayedSurface { simpleShot?.surface = displayedSurface }
        requestRevision &+= 1
        firstPersonMemory = nil
        observationReturn = nil
        if mode == .thirdPerson, shotProfile != nil || simpleShot?.surface != nil {
            entryContext = nil
            observationReturn = nil; connector = nil; memoryDestination = nil
            targetYaw = yaw; targetProgress = progress
            suspendedPose = true
            return // A new shot needs an explicit fresh profile; the actual pose remains held.
        }
        if mode == .thirdPerson {
            entryContext = context
            return // A ball/pocket/aim change does not stop the user's table-orbit movement.
        }
        entryContext = nil
        // A first-person destination authorized by the old shot cannot finish on the new shot.
        connector = nil
        memoryDestination = nil
        targetYaw = yaw
        targetProgress = progress
        targetHeadYaw = headYaw
        suspendedPose = true
    }

    private func saveActiveMemory() {
        guard mode != .thirdPerson || shotProfile == nil else { return }
        guard (mode == .thirdPerson
            ? profile != nil : entryContext == context && firstPersonBase != nil) else { return }
        let memory = ModeMemory(mode: mode, owner: owner, pose: pose, profile: profile,
            yaw: yaw, progress: progress, headYaw: headYaw, firstPersonBase: firstPersonBase, context: context)
        if mode == .firstPerson { firstPersonMemory = memory } else { thirdPersonMemory = memory }
    }

    /// Ordinary mode switch restores the visible pose. Repeated mode buttons use the explicit entry/reset path.
    @discardableResult
    func switchToRememberedMode(_ destination: CameraRig.PlayerView, duration: Float) -> Bool {
        guard !(destination == .thirdPerson && shotProfile != nil), destination != mode,
              let memory = destination == .firstPerson ? firstPersonMemory : thirdPersonMemory,
              destination == .thirdPerson || memory.context == context else { return false }
        if destination == .thirdPerson, let current = profile, let remembered = memory.profile {
            guard current.anchor == remembered.anchor,
                  current.tableHalfExtents == remembered.tableHalfExtents else { return false }
        }
        saveActiveMemory()
        let origin = pose
        requestRevision &+= 1
        entryContext = context
        mode = memory.mode
        owner = memory.owner
        profile = memory.profile
        yaw = memory.yaw; targetYaw = yaw
        progress = memory.progress; targetProgress = progress
        headYaw = memory.headYaw; targetHeadYaw = headYaw
        firstPersonBase = memory.firstPersonBase
        if let layout { profile = profile?.preservingLens(viewport: layout.viewport, insets: layout.insets) }
        suspendedPose = false
        memoryDestination = memory.pose
        connector = (origin, 0, max(0.1, duration))
        return true
    }

    /// Keep actual eye/lens and frozen creation samples. Explicit profile replacement is required to reconnect.
    func revalidateLayout(viewport: CGSize, insets: UIEdgeInsets) {
        guard layout?.viewport != viewport || layout?.insets != insets else { return }
        layout = (viewport, insets)
        layoutRevision &+= 1
        if var shot = simpleShot {
            shot.viewport = viewport; shot.surface?.viewport = viewport; simpleShot = shot
            displayedSurface?.viewport = viewport
            surfaceTransitionOrigin?.viewport = viewport
            for i in surfaceSamples.indices { surfaceSamples[i].surface.viewport = viewport }
            if mode == .thirdPerson, connector == nil { pose = displayedSurface?.pose ?? shot.pose }
        }
        if let shotProfile {
            self.shotProfile = shotProfile.preservingLens(viewport: viewport, insets: insets)
            if mode == .thirdPerson { railMotionLimited = !self.shotProfile!.hasReadableLayout }
        }
        if let profile {
            let revalidated = profile.preservingLens(viewport: viewport, insets: insets)
            self.profile = revalidated
            if mode == .thirdPerson { railMotionLimited = !revalidated.hasReadableLayout }
        }
        if mode == .thirdPerson, profile != nil || shotProfile != nil {
            connector = nil
            observationReturn = nil
            memoryDestination = nil
            targetYaw = yaw
            targetProgress = progress
            suspendedPose = true
            requestRevision &+= 1
        }
    }

    @discardableResult
    func horizontal(delta: Float) -> Bool {
        if simpleShot?.surface != nil { return surfacePan(delta: SIMD2(delta, 0)) }
        guard delta.isFinite, delta != 0,
              mode == .firstPerson || profile != nil || shotProfile != nil else { return false }
        if shotProfile != nil && !beginTemporaryObservation() { return false }
        takeManualControl()
        // Shot-aware third person drags the visible scene: right drag moves a
        // forward reference right. Legacy table orbit retains its existing sign.
        if mode == .thirdPerson { targetYaw += delta * (shotProfile == nil ? 0.0025 : -0.0025) }
        else { targetHeadYaw = max(-.pi * 0.4, min(.pi * 0.4, targetHeadYaw + delta * 0.0025)) }
        return true
    }

    @discardableResult
    func vertical(delta: Float) -> Bool {
        if simpleShot?.surface != nil { return surfacePan(delta: SIMD2(0, delta)) }
        if mode == .thirdPerson, var shot = simpleShot, delta.isFinite {
            _ = beginTemporaryObservation()
            shot.move(points: delta); simpleShot = shot
            progress = log2(shot.distance / 1.65); targetProgress = progress
            if connector == nil { pose = shot.pose }
            return true
        }
        guard mode == .thirdPerson, delta.isFinite, delta != 0, profile != nil || shotProfile != nil else { return false }
        if shotProfile != nil && !beginTemporaryObservation() { return false }
        takeManualControl()
        // UIKit positive y is down: down retreats, up approaches.
        targetProgress = max(0, min(1, targetProgress + delta / 500))
        return true
    }

    @discardableResult
    func pinch(scale: Float) -> Bool {
        if mode == .thirdPerson, let shot = simpleShot, scale.isFinite, scale > 0 {
            return vertical(delta: -log2(scale) * Float(shot.viewport.height) / 2)
        }
        guard mode == .thirdPerson, scale.isFinite, scale > 0, scale != 1, profile != nil || shotProfile != nil else { return false }
        if shotProfile != nil && !beginTemporaryObservation() { return false }
        takeManualControl()
        targetProgress = max(0, min(1, targetProgress - log(scale) * 0.5))
        return true
    }

    private func takeManualControl() {
        if shotProfile != nil {
            _ = beginTemporaryObservation()
            resumeExplicitMotion()
            return
        }
        let wasManual = owner == .manual
        let wasRestoringMemory = memoryDestination != nil
        let wasSuspended = suspendedPose
        let needsFirstPersonEyeRebase = mode == .firstPerson
            && firstPersonBase.map { simd_length($0.eye - pose.eye) > 0.000001 } == true
        resumeExplicitMotion()
        memoryDestination = nil
        requestRevision &+= 1
        owner = .manual
        guard (!wasManual || wasRestoringMemory
               || (wasSuspended && (mode == .thirdPerson || needsFirstPersonEyeRebase))),
              connector != nil else { return }
        if mode == .thirdPerson, let profile {
            let offset = pose.eye - profile.anchor
            yaw = atan2(offset.z, offset.x)
            targetYaw = yaw
            progress = profile.progress(yaw: yaw, radius: hypot(offset.x, offset.z))
            targetProgress = progress
            // Continue from the actual visible pose; never snap to the nearest rail point.
            connector = (pose, 0, 0.25)
        } else {
            firstPersonBase = pose
            headYaw = 0
            targetHeadYaw = 0
            connector = nil
        }
    }

    func update(deltaTime: Float, time: TimeInterval = CACurrentMediaTime()) {
        if mode == .thirdPerson, let shot = simpleShot {
            guard deltaTime.isFinite, deltaTime > 0 else { return }
            if var move = connector {
                move.elapsed = min(move.duration, move.elapsed + deltaTime)
                let t = move.elapsed / move.duration
                let eased = surfaceMotion?.fraction(at: move.elapsed)
                    ?? (shot.surface != nil ? CameraSurface.smooth(t) : t * t * (3 - 2 * t))
                if let origin = surfaceTransitionOrigin, let target = shot.surface {
                    displayedSurface = origin.interpolated(to: target, fraction: eased)
                    pose = displayedSurface!.pose
                } else {
                    pose = move.origin.interpolated(to: shot.pose, fraction: eased)
                    if t >= 1 {
                        displayedSurface = shot.surface
                        // First entry already consumed the current input target; old samples
                        // must not pull it backwards on the following display frame.
                        surfaceSamples.removeAll(keepingCapacity: true)
                    }
                }
                connector = t >= 1 ? nil : move
            } else { updateSurfaceInput(at: time) }
            return
        }
        guard !suspendedPose, deltaTime.isFinite, deltaTime > 0 else { return }
        guard connector != nil || observationReturn != nil || memoryDestination != nil || yaw != targetYaw
            || progress != targetProgress || headYaw != targetHeadYaw else { return }
        let previousYaw = yaw, previousProgress = progress
        let t = 1 - exp(-8 * deltaTime)
        yaw += (targetYaw - yaw) * t
        progress += (targetProgress - progress) * t
        headYaw += (targetHeadYaw - headYaw) * t
        if abs(yaw - targetYaw) <= 0.00001 { yaw = targetYaw }
        if abs(progress - targetProgress) <= 0.00001 { progress = targetProgress }
        if abs(headYaw - targetHeadYaw) <= 0.00001 { headYaw = targetHeadYaw }
        let target: Pose
        if let observationReturn { target = observationReturn }
        else if let memoryDestination { target = memoryDestination }
        else if mode == .thirdPerson, let shotProfile {
            guard shotProfile.context == context,
                  let fitted = shotProfile.legalPose(yaw: yaw, progress: progress) else {
                yaw = previousYaw; targetYaw = yaw; progress = previousProgress; targetProgress = progress
                connector = nil; suspendedPose = true; railMotionLimited = true
                requestRevision &+= 1
                return
            }
            target = fitted
            railMotionLimited = progress > shotProfile.defaultProgress && !shotProfile.hasRetreatRoom(yaw: yaw)
        }
        else if mode == .thirdPerson, let profile {
            guard let fitted = profile.legalPose(yaw: yaw, progress: progress) else {
                // Hold the visible pose and discard this request; reverse/new input can try again.
                yaw = previousYaw; targetYaw = yaw
                progress = previousProgress; targetProgress = progress
                connector = nil; memoryDestination = nil
                suspendedPose = true
                requestRevision &+= 1
                railMotionLimited = true
                return
            }
            railMotionLimited = false
            target = fitted
        }
        else if let base = firstPersonBase {
            let forward = base.forward
            target = headYaw == 0 ? base : .looking(eye: base.eye, yaw: atan2(-forward.z, -forward.x) + headYaw,
                              pitch: asin(max(-1, min(1, forward.y))), fov: base.fov)
        } else { return }
        if var connector {
            connector.elapsed = min(connector.duration, connector.elapsed + deltaTime)
            let x = connector.elapsed / connector.duration
            let eased = x * x * x * (x * (x * 6 - 15) + 10)
            pose = connector.origin.interpolated(to: target, fraction: eased)
            self.connector = x >= 1 ? nil : connector
            if x >= 1, observationReturn != nil {
                observationReturn = nil
                railMotionLimited = false
                if mode == .thirdPerson, let shotProfile {
                    yaw = shotProfile.defaultYaw; targetYaw = yaw
                    progress = shotProfile.defaultProgress; targetProgress = progress
                } else { headYaw = 0; targetHeadYaw = 0 }
                suspendedPose = true
            }
            if x >= 1, memoryDestination != nil {
                memoryDestination = nil
                suspendedPose = true
            }
        } else { pose = target }
    }

    func snapshot() -> Snapshot {
        var visibleShot = simpleShot
        if let displayedSurface { visibleShot?.surface = displayedSurface }
        return Snapshot(mode: mode, owner: owner, pose: pose, profile: profile,
                 shotProfile: shotProfile, simpleShot: visibleShot, defaultPose: defaultPose, temporaryObserving: temporaryObserving, yaw: yaw,
                 progress: progress, headYaw: headYaw, firstPersonBase: firstPersonBase,
                 context: context, entryContext: entryContext,
                 firstPersonMemory: firstPersonMemory, thirdPersonMemory: thirdPersonMemory)
    }

    func restore(_ snapshot: Snapshot) {
        requestRevision &+= 1
        let currentShot = shotProfile
        simpleShot = snapshot.simpleShot
        displayedSurface = snapshot.simpleShot?.surface
        surfaceTransitionOrigin = nil
        surfaceMotion = nil
        surfaceSamples.removeAll(keepingCapacity: true)
        mode = snapshot.mode
        owner = snapshot.owner
        pose = snapshot.pose
        profile = snapshot.profile
        shotProfile = snapshot.context == context ? snapshot.shotProfile : currentShot.flatMap { $0.context == context ? $0 : nil }
        temporaryObserving = snapshot.context == context && snapshot.temporaryObserving
        observationReturn = nil
        yaw = snapshot.yaw
        targetYaw = yaw
        progress = snapshot.progress
        targetProgress = progress
        headYaw = snapshot.headYaw
        targetHeadYaw = headYaw
        firstPersonBase = snapshot.firstPersonBase
        entryContext = snapshot.entryContext
        firstPersonMemory = snapshot.context == context ? snapshot.firstPersonMemory : nil
        // The shot may have changed while displaying 2D; a table-owned TP memory remains meaningful.
        thirdPersonMemory = shotProfile == nil ? snapshot.thirdPersonMemory : nil
        if mode == .thirdPerson { entryContext = shotProfile == nil || shotProfile?.context == context ? context : nil }
        memoryDestination = nil
        if let layout {
            profile = profile?.preservingLens(viewport: layout.viewport, insets: layout.insets)
            shotProfile = shotProfile?.preservingLens(viewport: layout.viewport, insets: layout.insets)
        }
        connector = nil
        // A suspended mid-transition pose is held until a new explicit input/request.
        suspendedPose = true
    }

    private var suspendedPose = false

    func resumeExplicitMotion() {
        guard suspendedPose else { return }
        suspendedPose = false
        if mode == .thirdPerson, let shotProfile {
            let railPose = shotProfile.pose(yaw:yaw,progress:progress)
            if simd_length(railPose.eye-pose.eye) <= 0.000001,
               abs(simd_dot(railPose.orientation.vector,pose.orientation.vector)) >= 0.999999 {
                connector = nil
                return
            }
        }
        connector = (pose, 0, 0.25)
    }

    static func angleDelta(_ from: Float, _ to: Float) -> Float {
        atan2(sin(to - from), cos(to - from))
    }
}
