import Foundation
import simd

/// Explicit host policy. Never infer the pilot from rendering style, title or saved preferences.
enum ShotCameraPolicy: String, Codable {
    case legacy
    case p01Replayable
}

/// SceneKit world convention: XZ metres, +Y up. No nodes, business mode or physics state.
/// Absolute-time evaluation makes the same input recording independent of render cadence.
struct P01CameraMotion {
    static let panRadiansPerPoint: Float = 0.00135
    private static let thirdPersonPresetDistance: Float = 1.65

    // Accepted Daily Clearance landscape lens, measured in its 874 × 402 pt scene.
    static let dailyAimLensAspect: Float = 874.0 / 402.0

    enum View: String, Codable { case firstPerson, thirdPerson, overview }
    struct Shot: Codable, Equatable {
        var cue: SIMD3<Float>
        var strike: SIMD3<Float>
        var aim: SIMD3<Float>
        var elevation: Float
        var addressButtOffset: Float? = nil
        // A pending selection can establish a camera bearing before a legal shaft exists.
        var observationOnlyAddress: Bool? = nil
        var bearing: Float { atan2(-aim.z, -aim.x) }
        var valid: Bool {
            [cue.x, cue.y, cue.z, strike.x, strike.y, strike.z, aim.x, aim.y, aim.z, elevation].allSatisfy(\.isFinite)
                && hypot(aim.x, aim.z) > 0.0001
        }
    }
    struct Layout: Codable, Equatable {
        var viewport: SIMD2<Float>
        var insets: SIMD4<Float> // left, top, right, bottom, in logical points
        var surfaceY: Float
        var tableHalfExtents: SIMD2<Float>
        var roomHalfExtents: SIMD2<Float>
        var ceilingY: Float
        var ballRadius: Float
        // Older recordings can carry the former card-only lens. New live layouts
        // carry a shared aim lens while projection and picking use the real viewport.
        var thirdPersonLensAspect: Float? = nil
        var aimLensAspect: Float? = nil
        var aspect: Float { viewport.x / viewport.y }
        var valid: Bool {
            [viewport.x, viewport.y, insets.x, insets.y, insets.z, insets.w, surfaceY,
             tableHalfExtents.x, tableHalfExtents.y, roomHalfExtents.x, roomHalfExtents.y, ceilingY, ballRadius].allSatisfy(\.isFinite)
                && viewport.x > 1 && viewport.y > 1 && tableHalfExtents.x > 0 && tableHalfExtents.y > 0
                && roomHalfExtents.x > tableHalfExtents.x && roomHalfExtents.y > tableHalfExtents.y
                && ballRadius > 0 && ceilingY > surfaceY + 0.4
        }
        func legalEye(_ eye: SIMD3<Float>) -> Bool {
            eye.x.isFinite && eye.y.isFinite && eye.z.isFinite
                && abs(eye.x) <= roomHalfExtents.x && abs(eye.z) <= roomHalfExtents.y
                && eye.y >= surfaceY + 0.12 && eye.y <= ceilingY - 0.2
        }
    }
    struct Pose: Codable, Equatable {
        var eye: SIMD3<Float>
        var rotation: SIMD4<Float>
        var verticalFOV: Float
        var orientation: simd_quatf { simd_quatf(vector: rotation) }
        var forward: SIMD3<Float> { orientation.act(.init(0, 0, -1)) }
        var yaw: Float { atan2(-forward.z, -forward.x) }
        var pitch: Float { asin(min(1, max(-1, forward.y))) }
        var transform: simd_float4x4 {
            var m = simd_float4x4(orientation); m.columns.3 = .init(eye, 1); return m
        }
        static func looking(eye: SIMD3<Float>, yaw: Float, pitch: Float, verticalFOV: Float) -> Pose {
            let forward = SIMD3<Float>(-cos(yaw)*cos(pitch), sin(pitch), -sin(yaw)*cos(pitch))
            let right = SIMD3<Float>(sin(yaw), 0, -cos(yaw))
            let up = simd_cross(right, forward)
            return .init(eye: eye, rotation: simd_quatf(simd_float3x3(columns: (right, up, -forward))).vector,
                         verticalFOV: verticalFOV)
        }
        func project(_ point: SIMD3<Float>, layout: Layout) -> SIMD2<Float>? {
            let local = orientation.inverse.act(point-eye), depth = -local.z
            guard depth > 0.001 else { return nil }
            let t = tan(verticalFOV * .pi / 360)
            return .init((1 + local.x / (depth*t*layout.aspect))/2,
                         (1 - local.y / (depth*t))/2)
        }
    }
    enum GeneralTiming: String, Codable { case selectionMatchedV1 }
    struct State: Codable, Equatable {
        // nil decodes old recordings with their original timing.
        var generalTiming: GeneralTiming? = nil
        // Missing from first-generation Codable snapshots. Keep their recorded geometry and gains.
        var fixedAxisOrbit: Bool? = true
        // Missing from snapshots made before transitions were composed around an anchor.
        var anchoredTransitions: Bool? = nil
        var view: View = .thirdPerson
        var watchingBreak: Bool? = nil
        var lastAimView: View = .thirdPerson
        var distance: Float = P01CameraMotion.thirdPersonPresetDistance
        var height: Float = 0.65
        // Missing in older recordings: preserve their original third-person eye.
        var followsCueElevation: Bool? = nil
        var observationYaw: Float = 0
        var headYaw: Float = 0
        var gazeYawOffset: Float = 0
        var gazePitchOffset: Float = 0
        var thirdPersonZoomPitchOffset: Float? = nil
        // Older recordings retain their recorded pitch accumulation and zoom behavior.
        var boundedThirdPersonZoom: Bool? = nil
        var observationHorizontalFOV: Float? = nil
        var overviewYaw: Float = .pi
        var overviewHeight: Float = 1.8
        var overviewFramingLift: Float = 0
        var overviewScale: Float = 1
        var overviewHorizontalFOV: Float = 80
        var overviewInitialized = false
        // Stored with the camera so older trajectories keep their original eye position.
        var firstPersonSetback: Float? = nil
        // Positive values move the eye forward along the current shaft. The base
        // setback remains derived from the shot or the camera preset.
        var firstPersonDolly: Float? = nil
        func baseShaftSetback(for shot: Shot) -> Float { shot.addressButtOffset ?? firstPersonSetback ?? 0.90 }
        func shaftSetback(for shot: Shot) -> Float { baseShaftSetback(for: shot) - (firstPersonDolly ?? 0) }
        var firstPersonClearanceLift: Float = 0
        var focusPoint: SIMD3<Float>? = nil

        func thirdPersonElevationLift(for shot: Shot) -> Float {
            guard followsCueElevation == true, view == .thirdPerson,
                  fixedAxisOrbit == true, watchingBreak != true,
                  shot.observationOnlyAddress != true else { return 0 }
            // Resting butt rise relative to a level shaft. Dolly and stroke travel
            // do not participate; height remains the user's independent offset.
            return max(0, baseShaftSetback(for: shot)) * max(0, sin(shot.elevation))
        }

    }
    struct Snapshot: Codable {
        var schema = 1
        var context: UUID
        var time: Double
        var state: State
        var shot: Shot
        var pose: Pose
        var headBase: Pose?
        var layout: Layout? = nil
        var motion: Transition? = nil
    }
    struct Sample: Codable { var time: Double; var pose: Pose }
    enum TurnPace: String, Codable {
        case selection120, original180

        var radiansPerSecond: Double { self == .selection120 ? 2 * .pi / 3 : .pi }
        var rampSeconds: Double { self == .selection120 ? 0.16 : 0.12 }
    }

    struct Input: Codable {
        enum Kind: String, Codable { case watchBreak, beginObservation, pan, pinch, view, aim, shot, release, layout, context, focus, restore, target }
        var time: Double
        var kind: Kind
        var breakPullbackSeconds: Double? = nil
        var delta: SIMD2<Float> = .zero
        var scale: Float = 1
        var animated = true
        var clearanceLift: Float? = nil
        var view: View? = nil
        var shot: Shot? = nil
        var layout: Layout? = nil
        var context: UUID? = nil
        var point: SIMD3<Float>? = nil
        var snapshot: Snapshot? = nil
        var restoringBoard = false
        var preservesVisiblePose: Bool? = nil
        var resetThirdPerson: Bool? = nil
        var preservePinchPitch: Bool? = nil
        var pacedTargetTurn: Bool? = nil // Earlier recordings used the original 180°/s pace.
        var turnPace: TurnPace? = nil
    }
    struct Recording: Codable {
        var schema = 1
        var policy = ShotCameraPolicy.p01Replayable
        var geometryID: String
        var initial: Snapshot
        var layout: Layout
        var inputs: [Input]
        var samples: [Sample] = []
    }
    struct Destination: Codable, Equatable {
        var context: UUID
        var state: State
        var shot: Shot
        var layout: Layout
        var target: Pose
        var resetThirdPerson: Bool?
    }
    struct Transition: Codable {
        var origin: Pose
        var start: Double
        var duration: Double
        var lift: Float
        var targetYaw: Float
        var previousTargetYaw: Float
        var fixedTarget: Pose?
        var framing: FramingPath? = nil

        var rampSeconds: Double? = nil
        // Cumulative channel time at uniformly sampled path parameters. Stored in
        // snapshots so restoration and replay never depend on render cadence.
        var channelTimes: [Double]? = nil
        var destination: Destination? = nil

        func blend(at time: Double) -> Float {
            let distance = timeBlend(at: time)
            guard let times = channelTimes, times.count > 1, let total = times.last,
                  total > 0, distance > 0, distance < 1 else { return distance }
            let wanted = Double(distance) * total
            var low = 0, high = times.count - 1
            while high - low > 1 {
                let mid = (low + high) / 2
                if times[mid] < wanted { low = mid } else { high = mid }
            }
            let span = times[high] - times[low]
            let local = span > 0 ? (wanted - times[low]) / span : 1
            return Float((Double(low) + local) / Double(times.count - 1))
        }
        private func timeBlend(at time: Double) -> Float {
            if let ramp = rampSeconds, ramp > 0, duration >= 2 * ramp {
                let elapsed = min(duration, max(0, time - start))
                // Integrate a half-cosine velocity ramp on each end of the cruise.
                func rampDistance(_ t: Double) -> Double {
                    (t - ramp / .pi * sin(.pi * t / ramp)) * 0.5 / (duration - ramp)
                }
                if elapsed <= ramp { return Float(rampDistance(elapsed)) }
                if elapsed >= duration - ramp { return Float(1 - rampDistance(duration - elapsed)) }
                return Float((elapsed - ramp / 2) / (duration - ramp))
            }
            let u = Float(min(1, max(0, (time - start) / duration)))
            return u * u * u * (u * (u * 6 - 15) + 10)
        }
    }
    struct FramingPath: Codable {
        var start: SIMD3<Float>
        var end: SIMD3<Float>

        func point(at blend: Float) -> SIMD3<Float> {
            simd_mix(start, end, SIMD3(repeating: blend))
        }
    }
    private(set) var state = State()
    private(set) var shot: Shot
    private(set) var layout: Layout
    private(set) var pose: Pose
    private(set) var context: UUID
    private(set) var time: Double = 0
    private(set) var diagnostic: String?
    private var transition: Transition?
    private var headBase: Pose?
    var hasPendingMotion: Bool { transition != nil }

    init?(shot: Shot, layout: Layout, context: UUID = UUID(), anchoredTransitions: Bool = false,
          firstPersonSetback: Float? = nil, generalTiming: GeneralTiming? = nil,
          followsCueElevation: Bool = false) {
        let initial = State(generalTiming: generalTiming, anchoredTransitions: anchoredTransitions ? true : nil,
                            followsCueElevation: followsCueElevation ? true : nil,
                            boundedThirdPersonZoom: anchoredTransitions ? true : nil,
                            firstPersonSetback: firstPersonSetback)
        guard let evaluated = Self.evaluate(state: initial, shot: shot, layout: layout) else { return nil }
        self.state = initial; self.shot = shot; self.layout = layout; self.context = context; self.pose = evaluated
    }
    init?(recording: Recording) {
        guard recording.schema == 1, recording.policy == .p01Replayable,
              recording.initial.schema == 1, recording.initial.time.isFinite,
              recording.initial.time >= 0 else { return nil }
        self.init(shot:recording.initial.shot,layout:recording.layout,context:recording.initial.context)
        guard restore(recording.initial) else { return nil }
        time=recording.initial.time
        state=recording.initial.state;headBase=recording.initial.headBase
        transition=recording.initial.motion
    }
    static func legacyRadius(_ yaw: Float) -> Float {
        let x = cos(yaw)/3.5, z = sin(yaw)/2.5
        return 1 / pow(x*x*x*x + z*z*z*z, 0.25)
    }
    private static func overviewBaseRadius(_ state: State, yaw: Float, layout: Layout) -> Float {
        if state.fixedAxisOrbit == true {
            return min(layout.roomHalfExtents.x, layout.roomHalfExtents.y) - 0.001
        }
        return legacyRadius(yaw)
    }

    private static func overviewPitch(_ state: State, radius: Float, layout: Layout) -> Float {
        let height = state.overviewHeight + state.overviewFramingLift
        guard state.fixedAxisOrbit == true else { return atan2(-height, radius) }
        // Frame the near rail and the far ball tops across the entire turn.
        let extent = simd_length(layout.tableHalfExtents)
        let near = atan2(-height, radius - extent)
        let far = atan2(layout.ballRadius * 2 - height, radius + extent)
        return (near + far) / 2
    }

    /// Components of the cue-to-strike offset in the shaft's horizontal frame.
    /// Rotate this offset with the eye so sidespin preserves the shaft framing during observation.
    private static func strikeOffset(_ shot: Shot) -> SIMD2<Float> {
        let back = SIMD2<Float>(cos(shot.bearing), sin(shot.bearing))
        let offset = SIMD2(shot.strike.x - shot.cue.x, shot.strike.z - shot.cue.z)
        return SIMD2(simd_dot(offset, back), simd_dot(offset, SIMD2(-back.y, back.x)))
    }

    static func verticalFOV(horizontal: Float, aspect: Float) -> Float {
        2 * atan(tan(horizontal * .pi / 360) / aspect) * 180 / .pi
    }
    static func observationSightlineTargets(shot: Shot, radius: Float) -> [SIMD3<Float>] {
        let towardTable = simd_normalize(SIMD3<Float>(shot.aim.x, 0, shot.aim.z))
        return [shot.cue + SIMD3<Float>(0, radius * 0.8, 0),
                shot.cue + towardTable * radius * 0.35 + SIMD3<Float>(0, radius * 0.55, 0)]
    }

    /// Setback limits are derived from the current shaft, room envelope and
    /// cue-ball clearance. They are intentionally independent of the page.
    private static func firstPersonSetbackBounds(shot: Shot, layout: Layout) -> ClosedRange<Float> {
        let axis = simd_normalize(SIMD3<Float>(shot.aim.x, 0, shot.aim.z))
        let horizontalStep = max(0.05, abs(cos(shot.elevation)))
        let minimum = max(CueClearance.tipOffset + CueStroke.addressPull,
                          layout.ballRadius * 2)
        var maximum = Float.infinity
        let xStep = abs(axis.x) * horizontalStep
        let zStep = abs(axis.z) * horizontalStep
        if xStep > 0.0001 {
            maximum = min(maximum, (layout.roomHalfExtents.x + abs(shot.strike.x)) / xStep)
        }
        if zStep > 0.0001 {
            maximum = min(maximum, (layout.roomHalfExtents.y + abs(shot.strike.z)) / zStep)
        }
        let verticalStep = sin(shot.elevation)
        if verticalStep > 0.0001 {
            maximum = min(maximum, (layout.ceilingY - 0.2 - shot.strike.y - 0.13) / verticalStep)
        } else if verticalStep < -0.0001 {
            maximum = min(maximum, (shot.strike.y + 0.13 - (layout.surfaceY + 0.12)) / -verticalStep)
        }
        if !maximum.isFinite {
            maximum = minimum + 2 * max(layout.roomHalfExtents.x, layout.roomHalfExtents.y)
        }
        return minimum...max(minimum, maximum)
    }

    private static func boundedFirstPersonDolly(state: State, shot: Shot, layout: Layout,
                                                desired: Float,
                                                clear: ((SIMD3<Float>, [SIMD3<Float>]) -> Bool)?) -> Float {
        let bounds = firstPersonSetbackBounds(shot: shot, layout: layout)
        let base = state.baseShaftSetback(for: shot)
        let minimumDolly = base - bounds.upperBound
        let maximumDolly = base - bounds.lowerBound
        let target = min(maximumDolly, max(minimumDolly, desired))
        let current = min(maximumDolly, max(minimumDolly, state.firstPersonDolly ?? 0))
        func isValid(_ offset: Float) -> Bool {
            var candidate = state
            candidate.firstPersonDolly = offset
            return evaluate(state: candidate, shot: shot, layout: layout, clear: clear) != nil
        }
        guard isValid(current) else { return current }
        guard !isValid(target) else { return target }
        var valid = current
        var invalid = target
        for _ in 0..<18 {
            let middle = (valid + invalid) * 0.5
            if isValid(middle) {
                valid = middle
            } else {
                invalid = middle
            }
        }
        return valid
    }

    static func evaluate(state: State, shot: Shot, layout: Layout,
                         clear: ((SIMD3<Float>, [SIMD3<Float>]) -> Bool)? = nil) -> Pose? {
        guard shot.valid, layout.valid else { return nil }
        let axis = simd_normalize(SIMD3<Float>(shot.aim.x, 0, shot.aim.z))
        let yaw = shot.bearing + state.observationYaw
        var eye: SIMD3<Float>, fov: Float, anchor: Float, heading: Float
        var referenceDepth: Float?
        if state.watchingBreak == true {
            // Centre the two short rails on the opening end of the table. At the reference
            // landscape aspect the visible near rail spans about 84% of the frame width.
            let eye = SIMD3<Float>(layout.tableHalfExtents.x + 1.24, layout.surfaceY + 0.72, 0)
            guard layout.legalEye(eye) else { return nil }
            return .looking(eye: eye, yaw: 0, pitch: -0.281,
                            verticalFOV: max(32, verticalFOV(horizontal: 64, aspect: layout.aspect)))
        }
        if state.view == .overview {
            let r = overviewBaseRadius(state, yaw: state.overviewYaw, layout: layout) * state.overviewScale
            eye = .init(cos(state.overviewYaw)*r, layout.surfaceY+state.overviewHeight+state.overviewFramingLift, sin(state.overviewYaw)*r)
            fov = verticalFOV(horizontal: state.observationHorizontalFOV ?? state.overviewHorizontalFOV, aspect: layout.aspect)
            guard layout.legalEye(eye) else { return nil }
            return .looking(eye: eye, yaw: state.overviewYaw + state.gazeYawOffset,
                            pitch: overviewPitch(state, radius: r, layout: layout) + state.gazePitchOffset, verticalFOV: fov)
        } else if state.view == .firstPerson {
            eye = shot.strike - axis*(state.shaftSetback(for: shot)*cos(shot.elevation))
            eye.y = shot.strike.y + state.shaftSetback(for: shot)*sin(shot.elevation) + 0.13 + (clear == nil ? state.firstPersonClearanceLift : 0)
            fov = min(40, verticalFOV(horizontal: 56, aspect: layout.aimLensAspect ?? layout.aspect)); anchor = 0.70; heading = shot.bearing
            if let clear {
                let right = SIMD3<Float>(-axis.z, 0, axis.x), r = layout.ballRadius
                let low = shot.cue - axis*(r*0.4) + SIMD3<Float>(0, -r*0.5, 0)
                let fullAddress = [shot.strike, shot.cue + SIMD3<Float>(0,-r*0.85,0), low+right*(r*0.7), low-right*(r*0.7)]
                func clearHeight(_ samples: [SIMD3<Float>], maximumLift: Float) -> Float? {
                    if clear(eye, samples) { return eye.y }
                    let high = min(eye.y + maximumLift, layout.ceilingY - 0.2)
                    guard high >= eye.y, clear(.init(eye.x, high, eye.z), samples) else { return nil }
                    var lo = eye.y, hi = high
                    for _ in 0..<16 {
                        let mid = (lo+hi)/2
                        if clear(.init(eye.x,mid,eye.z),samples) { hi=mid } else { lo=mid }
                    }
                    return min(high, hi+0.005)
                }
                // Prefer the full address. At a cushion its contact and lower
                // hemisphere can be hidden even with a valid physical shaft.
                // Keep that shaft's pivot, inclination and setback when checking
                // whether the exposed cue-ball crown remains readable.
                let fullHeight = shot.observationOnlyAddress == true ? nil : clearHeight(fullAddress, maximumLift: 0.20)
                let readableHeight = fullHeight ?? ((state.anchoredTransitions == true || shot.observationOnlyAddress == true)
                    ? clearHeight(observationSightlineTargets(shot: shot, radius: r), maximumLift: 0.65) : nil)
                guard let readableHeight else { return nil }
                eye.y = readableHeight
            }
        } else if state.fixedAxisOrbit == true {
            let offset = strikeOffset(shot)
            let back = SIMD2<Float>(cos(yaw), sin(yaw))
            let side = SIMD2(-back.y, back.x)
            var depthLimit = Float.infinity
            if state.observationHorizontalFOV == nil {
                // Limit the whole orbit once, independently of yaw. At the wall a horizontal
                // drag should never push the camera towards and away from the ball.
                let clearance = min(layout.roomHalfExtents.x - abs(shot.cue.x),
                                    layout.roomHalfExtents.y - abs(shot.cue.z)) - 0.001
                guard clearance > abs(offset.y) else { return nil }
                depthLimit = sqrt(clearance * clearance - offset.y * offset.y)
            }
            let along = min(state.distance + offset.x, depthLimit)
            if state.boundedThirdPersonZoom == true {
                // Height changes tilt around the preset distance. Moving along the orbit's
                // radius does not add a pitch offset that could survive a gesture loop.
                referenceDepth = min(thirdPersonPresetDistance + offset.x, depthLimit)
            }
            let displacement = along * back + offset.y * side
            let requestedY = layout.surfaceY + state.height + state.thirdPersonElevationLift(for: shot)
            let eyeY = state.followsCueElevation == true ? min(layout.ceilingY - 0.2, requestedY) : requestedY
            eye = .init(shot.cue.x + displacement.x, eyeY,
                        shot.cue.z + displacement.y)
            let legacyAspect = state.observationHorizontalFOV == nil ? (layout.thirdPersonLensAspect ?? layout.aspect) : layout.aspect
            let lensAspect = layout.aimLensAspect ?? legacyAspect
            fov = verticalFOV(horizontal: state.observationHorizontalFOV ?? 64, aspect: lensAspect)
            anchor = 0.67
            heading = yaw
        } else {
            // Replay the original P01 direction-dependent orbit.
            let desired = state.distance * legacyRadius(yaw)/legacyRadius(shot.bearing)
            let back = SIMD3<Float>(cos(yaw),0,sin(yaw))
            let limitX = abs(back.x) > 0.00001 ? (layout.roomHalfExtents.x - (back.x > 0 ? shot.strike.x : -shot.strike.x)) / abs(back.x) : Float.infinity
            let limitZ = abs(back.z) > 0.00001 ? (layout.roomHalfExtents.y - (back.z > 0 ? shot.strike.z : -shot.strike.z)) / abs(back.z) : Float.infinity
            let d = min(desired, min(limitX,limitZ)-0.0001)
            guard d > 0.01 else { return nil }
            eye = shot.strike + back*d; eye.y = layout.surfaceY+state.height
            fov = verticalFOV(horizontal: state.observationHorizontalFOV ?? 64, aspect: layout.aspect); anchor = 0.67; heading = yaw
        }
        guard layout.legalEye(eye) else { return nil }
        if let point=state.focusPoint {
            let delta=point-eye, distance=hypot(delta.x,delta.z)
            guard distance > 0.01 else { return nil }
            return .looking(eye:eye,yaw:atan2(-delta.z,-delta.x),
                            pitch: atan2(delta.y,distance) + (state.view == .firstPerson ? state.gazePitchOffset : 0),
                            verticalFOV:fov)
        }
        // Use shaft-plane forward depth, not lateral distance, so sidespin keeps the shaft centred.
        let flatForward = SIMD3<Float>(-cos(heading),0,-sin(heading))
        let depth = simd_dot(shot.cue-eye,flatForward)
        guard depth > 0.01 else { return nil }
        let pitch = atan2(shot.cue.y-eye.y,referenceDepth ?? depth) + atan((2*anchor-1)*tan(fov * .pi/360))
        return .looking(eye: eye,
                        yaw: heading + (state.view == .firstPerson ? state.headYaw : state.gazeYawOffset),
                        pitch: pitch + state.gazePitchOffset + (state.view == .firstPerson ? 0 : (state.thirdPersonZoomPitchOffset ?? 0)),
                        verticalFOV: fov)
    }

    /// Fit the full heading envelope once for this H/scale/layout, never once per orbit frame.
    static func overviewLens(state: State, layout: Layout) -> Float? {
        guard layout.valid else { return nil }
        let left = 1-2*(layout.insets.x+8)/layout.viewport.x
        let right = 1-2*(layout.insets.z+8)/layout.viewport.x
        let top = 1-2*(layout.insets.y+8)/layout.viewport.y
        let bottom = 1-2*(layout.insets.w+8)/layout.viewport.y
        guard min(left,right,top,bottom) > 0 else { return nil }
        var tangent: Float = tan(64 * .pi/360)
        // One-degree sweep plus explicit optical margin. Eye safety is analytic over the envelope.
        for i in 0..<360 {
            let yaw = Float(i)*(.pi/180), r = overviewBaseRadius(state, yaw: yaw, layout: layout) * state.overviewScale
            let p = Pose.looking(eye: .init(cos(yaw)*r,layout.surfaceY+state.overviewHeight+state.overviewFramingLift,sin(yaw)*r),
                                 yaw: yaw,pitch: overviewPitch(state, radius: r, layout: layout),verticalFOV: 60)
            for x in [-layout.tableHalfExtents.x,layout.tableHalfExtents.x] {
                for z in [-layout.tableHalfExtents.y,layout.tableHalfExtents.y] {
                    for y in [layout.surfaceY,layout.surfaceY+layout.ballRadius*2] {
                        let v = p.orientation.inverse.act(SIMD3<Float>(x,y,z)-p.eye), depth = -v.z
                        guard depth > 0.01 else { return nil }
                        tangent=max(tangent,abs(v.x)/(depth*(v.x >= 0 ? right:left)),
                                    abs(v.y)*layout.aspect/(depth*(v.y >= 0 ? top:bottom)))
                    }
                }
            }
        }
        let result = 2*atan(tangent)*180 / .pi + 0.25
        if state.fixedAxisOrbit == true { return result < 120 ? result : nil }
        return result <= 84 ? result : nil
    }

    /// Preserve requested height; compact HUDs may need an explicit bounded framing lift.
    static func fittedOverview(_ state: State, layout: Layout) -> State? {
        var next=state;next.overviewFramingLift=0
        if state.fixedAxisOrbit == true {
            guard let lens = overviewLens(state: next, layout: layout) else { return nil }
            next.overviewHorizontalFOV = lens
            return next
        }
        for step in 0...40 {
            next.overviewFramingLift=Float(step)*0.05
            guard next.overviewHeight+next.overviewFramingLift <= 2.5001 else { return nil }
            if let lens=overviewLens(state:next,layout:layout) { next.overviewHorizontalFOV=lens;return next }
        }
        return nil
    }

    func snapshot() -> Snapshot { .init(context:context,time:time,state:state,shot:shot,pose:pose,headBase:headBase,layout:layout,motion:transition) }
    mutating func restore(_ snapshot: Snapshot, requireSameContext: Bool = true) -> Bool {
        guard snapshot.schema == 1, (!requireSameContext || snapshot.context == context),
              snapshot.shot.valid, layout.legalEye(snapshot.pose.eye),
              snapshot.pose.rotation.allFinite, snapshot.pose.verticalFOV.isFinite,
              snapshot.pose.verticalFOV > 1 && snapshot.pose.verticalFOV < 170 else { return false }
        state=snapshot.state; shot=snapshot.shot; pose=snapshot.pose; headBase=snapshot.headBase; transition=nil
        if state.view != .firstPerson && state.watchingBreak != true {
            let currentLayout=layout
            if let original=snapshot.layout, original.valid { layout=original }
            beginObservation();layout=currentLayout
        }
        if let original=snapshot.layout, original != layout {
            var next=state
            if next.view == .overview, next.observationHorizontalFOV == nil, let fitted=Self.fittedOverview(next,layout:layout) { next=fitted }
            guard let adapted=Self.evaluate(state:next,shot:shot,layout:layout) else { diagnostic="restore-layout-unavailable"; return false }
            state=next;pose=adapted
            if headBase != nil { var base=state;base.headYaw=0;headBase=Self.evaluate(state:base,shot:shot,layout:layout) }
        }
        diagnostic=nil; return true
    }
    mutating func setContext(_ id: UUID) {
        guard context != id else { return }
        context=id; transition=nil; headBase=nil; state.watchingBreak=nil; state.observationYaw=0; state.headYaw=0
        state.firstPersonDolly = nil
        state.firstPersonClearanceLift = 0
    }
    mutating func setLayout(_ value: Layout) {
        guard value != layout, value.valid else { return }
        let previous=layout; layout=value
        var next=state
        if state.view == .overview, state.observationHorizontalFOV == nil {
            guard let fitted=Self.fittedOverview(next,layout:value) else { layout=previous; diagnostic="overview-layout-unavailable"; return }
            next=fitted
        }
        _ = accept(next, animated:false)
        // A layout revision invalidates request identity even when a later resize
        // returns to the same dimensions. The visible motion may continue, but a
        // subsequent explicit reset must be rebuilt for that revised viewport.
        transition?.destination = nil
        if state.view == .firstPerson, headBase != nil {
            var base=state;base.headYaw=0
            headBase=Self.evaluate(state:base,shot:shot,layout:layout)
        }
    }
    mutating func updateShot(_ value: Shot, manuallyAimed: Bool,
                             clear: ((SIMD3<Float>, [SIMD3<Float>]) -> Bool)? = nil) {
        guard value.valid else { diagnostic="invalid-shot"; return }
        guard value != shot || manuallyAimed else { return }
        let old=shot
        // A live solver/board revision can retarget an existing transition without
        // restarting it. An earlier explicit request no longer owns that motion.
        if value != old { transition?.destination = nil }
        let detached=Self.evaluate(state:state,shot:old,layout:layout).map {
            simd_distance($0.eye,pose.eye)>0.001 || simd_distance($0.forward,pose.forward)>0.001
        } ?? true
        shot=value
        var next=state
        if manuallyAimed {
            next.watchingBreak=nil
            if next.view == .overview { next.view=next.lastAimView }
            next.focusPoint=nil
            next.observationYaw=0; next.headYaw=0; next.gazeYawOffset=0; next.gazePitchOffset=0; next.observationHorizontalFOV=nil
        } else {
            next.firstPersonDolly = nil
            next.firstPersonClearanceLift = 0
        }
        let needsReturn=manuallyAimed && (state.watchingBreak == true || state.view == .overview || abs(state.observationYaw)>0.0001 || headBase != nil || state.focusPoint != nil || abs(state.gazeYawOffset)>0.0001 || abs(state.gazePitchOffset)>0.0001 || state.observationHorizontalFOV != nil || detached)
        if !accept(next, animated:needsReturn, duration:0.35, restart:false, clear:clear) { shot=old }
        if manuallyAimed { headBase=nil }
        else if headBase != nil {
            var base=state; base.headYaw=0
            headBase=Self.evaluate(state:base,shot:shot,layout:layout,clear:clear)
        }
    }
    mutating func watchBreak(animated: Bool, duration: Double?) {
        var next = state
        next.watchingBreak = true
        next.view = .thirdPerson
        next.lastAimView = .thirdPerson
        next.distance = Self.thirdPersonPresetDistance
        next.height = State().height
        next.thirdPersonZoomPitchOffset = nil
        next.observationHorizontalFOV = nil
        next.observationYaw = 0
        next.gazeYawOffset = 0
        next.gazePitchOffset = 0
        next.headYaw = 0
        next.focusPoint = nil
        if !animated { transition = nil }
        if accept(next, animated: animated, generalTimingAllowed: false) {
            headBase = nil
            // Older recordings use the original distance-based timing.
            if let duration, duration.isFinite, duration > 0 { transition?.duration = duration }
        }
    }

    @discardableResult
    mutating func select(_ view: View, animated: Bool = true, shot newShot: Shot? = nil, turnPace: TurnPace? = nil, resetThirdPerson: Bool = false,
                         clear: ((SIMD3<Float>, [SIMD3<Float>]) -> Bool)? = nil) -> Bool {
        let oldShot=shot
        if let newShot, !newShot.valid { diagnostic="invalid-shot";return false }
        let usesFraming = state.anchoredTransitions == true
        var framing: FramingPath?
        if usesFraming, animated {
            let tableCenter = SIMD3<Float>(0, layout.surfaceY, 0)
            let presentedAnchor = transition.flatMap { move in move.framing?.point(at: move.blend(at: time)) }
            let aimAnchor = pose.project(oldShot.cue, layout: layout) == nil ? (state.focusPoint ?? oldShot.cue) : oldShot.cue
            framing = .init(start: presentedAnchor ?? (state.view == .overview || state.watchingBreak == true ? tableCenter : aimAnchor),
                            end: view == .overview ? tableCenter : (newShot ?? shot).cue)
        }
        var next=state; next.watchingBreak=nil; next.view=view; next.headYaw=0; next.observationYaw=0
        next.gazeYawOffset=0; next.gazePitchOffset=0; next.focusPoint=nil;next.observationHorizontalFOV=nil
        if view == .firstPerson || (newShot != nil && newShot != oldShot) {
            next.firstPersonDolly = nil
            next.firstPersonClearanceLift = 0
        }
        if resetThirdPerson && view == .thirdPerson {
            next.distance = State().distance
            next.height = State().height
            next.thirdPersonZoomPitchOffset = nil
        }
        if view != .overview { next.lastAimView=view }
        else {
            next.overviewHeight=min(2.5,max(0.65,next.overviewHeight))
            next.overviewScale=min(1,max(0.7,next.overviewScale))
            if !next.overviewInitialized { next.overviewYaw=pose.yaw; next.overviewInitialized=true }
            guard let fitted=Self.fittedOverview(next,layout:layout) else {
                diagnostic = "overview-fit-unavailable"
                if !usesFraming { transition = nil }
                return false
            }
            next=fitted
        }
        shot = newShot ?? shot
        let oldTransition = transition
        if !animated { transition=nil }
        let result=accept(next,animated:animated,clear:clear,framing: framing, turnPace: turnPace, resetThirdPerson: resetThirdPerson)
        if result { headBase=nil } else { transition=usesFraming ? oldTransition : nil;shot=oldShot }
        return result
    }
    @discardableResult
    mutating func selectTarget(shot newShot: Shot, preservesVisiblePose: Bool, animated: Bool = true, turnPace: TurnPace? = nil,
                               clear: ((SIMD3<Float>, [SIMD3<Float>]) -> Bool)? = nil) -> Bool {
        guard newShot.valid else { diagnostic="invalid-shot"; return false }
        if preservesVisiblePose {
            shot = newShot
            beginObservation()
            diagnostic = nil
            return true
        }
        let aimView = state.view == .overview ? state.lastAimView : state.view
        return select(aimView, animated: animated, shot: newShot, turnPace: turnPace, clear: clear)
    }
    mutating func focus(on point: SIMD3<Float>, animated: Bool = true) {
        guard point.x.isFinite, point.y.isFinite, point.z.isFinite else { return }
        if state.watchingBreak == true { beginObservation() }
        var next=state; next.focusPoint=point
        if next.view == .overview { next.view=next.lastAimView; next.observationYaw=0 }
        if !animated { transition=nil }
        if accept(next,animated:animated) { headBase=nil }
    }
    mutating func beginObservation() {
        let wasWatchingBreak = state.watchingBreak == true
        state.watchingBreak = nil
        let settled = !wasWatchingBreak && state.focusPoint == nil && Self.evaluate(state:state,shot:shot,layout:layout).map {
            simd_distance($0.eye,pose.eye) < 0.00001 && simd_distance($0.forward,pose.forward) < 0.00001
        } == true
        transition=nil; state.focusPoint=nil
        if state.view != .firstPerson && settled { return }
        if state.view == .firstPerson { headBase=pose; state.headYaw=0; return }
        let lensAspect = state.view == .thirdPerson && state.fixedAxisOrbit == true ? (layout.aimLensAspect ?? layout.aspect) : layout.aspect
        state.observationHorizontalFOV = 2*atan(tan(pose.verticalFOV * .pi/360)*lensAspect)*180 / .pi
        let center = state.view == .overview ? SIMD3<Float>(0,layout.surfaceY,0) : (state.fixedAxisOrbit == true ? shot.cue : shot.strike)
        let delta=pose.eye-center, yaw=atan2(delta.z,delta.x)
        if state.view == .overview {
            state.overviewYaw=yaw; state.overviewHeight=pose.eye.y-layout.surfaceY-state.overviewFramingLift
            state.overviewScale=hypot(delta.x,delta.z)/Self.overviewBaseRadius(state, yaw: yaw, layout: layout)
        } else if state.fixedAxisOrbit == true {
            let offset = Self.strikeOffset(shot)
            let radial = hypot(delta.x, delta.z)
            let along = sqrt(max(0, radial * radial - offset.y * offset.y))
            state.distance = along - offset.x
            state.observationYaw = Self.angleDelta(shot.bearing, yaw - atan2(offset.y, along))
            state.height = pose.eye.y - layout.surfaceY - state.thirdPersonElevationLift(for: shot)
        } else {
            state.observationYaw=Self.angleDelta(shot.bearing,yaw)
            state.distance=hypot(delta.x,delta.z)*Self.legacyRadius(shot.bearing)/Self.legacyRadius(yaw)
            state.height=pose.eye.y-layout.surfaceY
        }
        state.gazeYawOffset=0; state.gazePitchOffset=0
        if let reference=Self.evaluate(state:state,shot:shot,layout:layout) {
            state.gazeYawOffset=Self.angleDelta(reference.yaw,pose.yaw)
            state.gazePitchOffset=pose.pitch-reference.pitch
        }
    }
    private static func adjusted(_ value: Float, from current: Float, within range: ClosedRange<Float>) -> Float {
        // A connector may be interrupted outside a preset's preferred range. Allow
        // gradual travel back into that range without snapping the first input.
        min(max(range.upperBound,current),max(min(range.lowerBound,current),value))
    }
    mutating func pan(_ delta: SIMD2<Float>) {
        guard delta.x.isFinite && delta.y.isFinite else { return }
        if delta == .zero { return }
        if transition != nil || state.watchingBreak == true { beginObservation() }
        if state.view == .firstPerson {
            guard delta.x != 0 else { return }
            if headBase == nil { beginObservation() }
            guard let base=headBase else { return }
            state.headYaw=min(.pi/6,max(-.pi/6,state.headYaw+delta.x*0.0025))
            pose = .looking(eye:base.eye,yaw:base.yaw+state.headYaw,pitch:base.pitch,verticalFOV:base.verticalFOV)
            return
        }
        var next=state
        let yawGain: Float = next.fixedAxisOrbit == true ? Self.panRadiansPerPoint : 0.0025
        let heightGain: Float = next.fixedAxisOrbit == true ? 0.67 : 2
        if next.view == .overview {
            next.overviewYaw += delta.x*yawGain
            next.overviewHeight=Self.adjusted(next.overviewHeight+delta.y*heightGain/layout.viewport.y,from:next.overviewHeight,within:0.65...max(0.65,2.5-next.overviewFramingLift))
            // Lens is fixed during gesture, including vertical motion. Reject infeasible eye positions.
        } else {
            next.observationYaw += delta.x*yawGain
            let maximumHeight: Float = next.followsCueElevation == true ? min(1.8, max(0.18,
                layout.ceilingY - 0.2 - layout.surfaceY - next.thirdPersonElevationLift(for: shot))) : 1.8
            if delta.y != 0 {
                // A newly raised shaft can reach the ceiling before manual height
                // does. Start a reverse gesture at the visible eye, without a dead zone.
                let current = next.followsCueElevation == true ? min(next.height, maximumHeight) : next.height
                next.height=Self.adjusted(current+delta.y*heightGain/layout.viewport.y,from:current,within:0.18...maximumHeight)
            }
            if next.boundedThirdPersonZoom == true, state.focusPoint == nil,
               let target = Self.evaluate(state: next, shot: shot, layout: layout),
               visibleTravel(from: pose, to: pose, roundingTolerance: 0.00001) != nil,
               visibleTravel(from: target, to: target) == nil {
                // At a zoom stop keep the subject readable during vertical and diagonal pans.
                // Solve from the last visible state, so an immediate reverse remains available.
                var low: Float = 0
                var high: Float = 1
                var visible = state
                for _ in 0..<16 {
                    let blend = (low + high) / 2
                    var candidate = next
                    candidate.height = state.height + (next.height - state.height) * blend
                    candidate.observationYaw = state.observationYaw + (next.observationYaw - state.observationYaw) * blend
                    if let evaluated = Self.evaluate(state: candidate, shot: shot, layout: layout),
                       visibleTravel(from: evaluated, to: evaluated) != nil {
                        low = blend
                        visible = candidate
                    } else {
                        high = blend
                    }
                }
                next = visible
            }
        }
        _ = accept(next,animated:false)
    }
    mutating func pinch(_ scale: Float, preservingPitch: Bool = false,
                        clear: ((SIMD3<Float>, [SIMD3<Float>]) -> Bool)? = nil) {
        guard scale.isFinite, scale > 0 else { return }
        if state.view == .firstPerson {
            guard scale != 1 else { return }
            var next = state
            let desired = (state.firstPersonDolly ?? 0) + log(scale) * 0.45
            next.firstPersonDolly = Self.boundedFirstPersonDolly(state: state, shot: shot, layout: layout,
                                                                 desired: desired, clear: clear)
            guard (next.firstPersonDolly ?? 0) != (state.firstPersonDolly ?? 0) else { return }
            let previousPitch = pose.pitch
            next.gazePitchOffset = 0
            if let reprojected = Self.evaluate(state: next, shot: shot, layout: layout, clear: clear) {
                next.gazePitchOffset = previousPitch - reprojected.pitch
            }
            transition = nil
            if accept(next, animated: false, clear: clear), headBase != nil {
                headBase = .looking(eye: pose.eye, yaw: pose.yaw - state.headYaw,
                                    pitch: previousPitch, verticalFOV: pose.verticalFOV)
            }
            return
        }
        if transition != nil || state.watchingBreak == true || (preservingPitch && state.view == .thirdPerson && state.focusPoint != nil) { beginObservation() }
        var next=state
        if next.view == .overview { next.overviewScale=Self.adjusted(next.overviewScale/scale,from:next.overviewScale,within:0.7...1) }
        else {
            next.distance = Self.adjusted(next.distance / scale, from: next.distance, within: 0.9...3.5)
            if preservingPitch {
                guard let moved = Self.evaluate(state: next, shot: shot, layout: layout) else { return }
                if next.boundedThirdPersonZoom == true {
                    guard let blend = visibleTravel(from: pose, to: moved) else { return }
                    let travel = simd_distance(pose.eye, moved.eye)
                    next.distance = state.distance + (next.distance < state.distance ? -travel : travel) * blend
                } else {
                    next.thirdPersonZoomPitchOffset = (next.thirdPersonZoomPitchOffset ?? 0) + (pose.pitch - moved.pitch)
                }
            }
        }
        _ = accept(next,animated:false)
    }

    private func visibleTravel(from origin: Pose, to candidate: Pose, roundingTolerance: Float = 0) -> Float? {
        let tangent = tan(origin.verticalFOV * .pi / 360)
        let halfWidth = tangent * layout.aspect
        let insets = layout.insets / .init(layout.viewport.x, layout.viewport.y, layout.viewport.x, layout.viewport.y)
        guard insets.x + insets.z < 1, insets.y + insets.w < 1 else { return nil }
        let planes: [SIMD3<Float>] = [
            .init(1, 0, -(1 - 2 * insets.x) * halfWidth),
            .init(-1, 0, -(1 - 2 * insets.z) * halfWidth),
            .init(0, -1, -(1 - 2 * insets.y) * tangent),
            .init(0, 1, -(1 - 2 * insets.w) * tangent)
        ]
        let flatAim = simd_normalize(SIMD3<Float>(shot.aim.x, 0, shot.aim.z))
        let shaftBack = -flatAim * cos(shot.elevation) + SIMD3<Float>(0, sin(shot.elevation), 0)
        // The spin-dependent inset places the address tip between these endpoints.
        let nearTip = shot.strike + shaftBack * (CueStroke.addressPull + 0.0005)
        let farTip = shot.strike + shaftBack * (CueStroke.addressPull + CueClearance.tipOffset)
        let tipRadius = CueClearance.tipRadius + 0.001
        let subjects = [(shot.cue, layout.ballRadius), (nearTip, tipRadius), (farTip, tipRadius)]
        let localRotation = origin.orientation.inverse
        let localTravel = localRotation.act(candidate.eye - origin.eye)
        var lower: Float = 0
        var upper: Float = 1

        // At fixed pitch and heading the eye travels along a line. Each frustum plane
        // clips a linear interval; use the furthest visible point in the requested direction.
        for (center, radius) in subjects {
            let local = localRotation.act(center - origin.eye)
            for plane in planes {
                let clearance = simd_dot(plane, local) - (radius - roundingTolerance) * simd_length(plane)
                let loss = simd_dot(plane, localTravel)
                if loss > 0 {
                    upper = min(upper, clearance / loss)
                } else if loss < 0 {
                    lower = max(lower, clearance / loss)
                } else if clearance < 0 {
                    return nil
                }
            }
        }
        return lower <= upper ? upper : nil
    }
    mutating func release(clear: ((SIMD3<Float>, [SIMD3<Float>]) -> Bool)? = nil) {
        guard state.view == .firstPerson, headBase != nil else { return }
        var next=state; next.headYaw=0
        if accept(next,animated:true,duration:0.65,clear:clear,targetOverride:headBase) { headBase=nil }
    }
    private mutating func accept(_ next: State, animated: Bool, duration: Double? = nil, restart: Bool = true,
                                 clear: ((SIMD3<Float>, [SIMD3<Float>]) -> Bool)? = nil, targetOverride: Pose? = nil,
                                 framing: FramingPath? = nil, turnPace: TurnPace? = nil,
                                 resetThirdPerson: Bool? = nil, generalTimingAllowed: Bool = true) -> Bool {
        guard let target=targetOverride ?? Self.evaluate(state:next,shot:shot,layout:layout,clear:clear) else { diagnostic="no-legal-pose"; return false }
        state=next; diagnostic=nil
        if next.view == .firstPerson, clear != nil, targetOverride == nil {
            state.firstPersonClearanceLift=max(0,target.eye.y-(shot.strike.y+next.shaftSetback(for: shot)*sin(shot.elevation)+0.13))
        }
        let usesGeneral = next.generalTiming == .selectionMatchedV1 && generalTimingAllowed
        let destination = Destination(context: context, state: state, shot: shot, layout: layout,
                                      target: target, resetThirdPerson: resetThirdPerson)
        if usesGeneral && animated && restart {
            if transition?.destination == destination { return true }
            if simd_distance(pose.eye, target.eye) < 0.00001,
               abs(Self.angleDelta(pose.yaw, target.yaw)) < 0.00001,
               abs(pose.pitch - target.pitch) < 0.00001,
               abs(pose.verticalFOV - target.verticalFOV) < 0.0001 {
                pose = target; transition = nil; return true
            }
        }
        if animated {
            if restart || transition == nil || (transition?.framing != nil && framing == nil) {
                let framedPath = next.anchoredTransitions == true ? framing : nil
                let canLift = next.anchoredTransitions != true && simd_distance(pose.eye, target.eye) >= 0.0001
                let lift: Float = canLift ? min(0.15,max(0,layout.ceilingY-0.2-max(pose.eye.y,target.eye.y))) : 0
                let length=simd_distance(pose.eye,target.eye)+4*lift
                let angle=abs(Self.angleDelta(pose.yaw,target.yaw))+abs(target.pitch-pose.pitch)+2*lift
                var seconds=max(0.25,1.875*Double(length)/1.8,1.875*Double(angle)/(.pi/2),
                                1.875*Double(abs(target.verticalFOV-pose.verticalFOV))/40)
                var channelTimes: [Double]?
                if let turnPace, let framedPath {
                    let from = pose.eye - framedPath.start
                    let to = target.eye - framedPath.end
                    let orbitAngle = abs(Self.angleDelta(atan2(from.z, from.x), atan2(to.z, to.x)))
                    // A moving cue also limits anchor translation to 3 m/s.
                    let cruiseTime = max(Double(orbitAngle) / turnPace.radiansPerSecond, Double(simd_distance(framedPath.start, framedPath.end)) / 3)
                    seconds = max(2 * turnPace.rampSeconds, cruiseTime + turnPace.rampSeconds)
                } else if usesGeneral {
                    channelTimes = Self.channelTimes(from: pose, to: target, framing: framedPath, layout: layout)
                    if let total = channelTimes?.last {
                        seconds = max(0.32, total + 0.16)
                    }
                } else if let framedPath {
                    seconds = max(seconds, Self.framedDuration(from: pose, to: target, along: framedPath, layout: layout))
                }
                transition = .init(origin:pose,start:time,duration:max(duration ?? seconds,seconds),lift:lift,
                                   targetYaw:pose.yaw+Self.angleDelta(pose.yaw,target.yaw),previousTargetYaw:target.yaw,
                                   fixedTarget:targetOverride,framing:framedPath,
                                   rampSeconds: turnPace?.rampSeconds ?? (channelTimes == nil ? nil : 0.16),
                                   channelTimes: channelTimes, destination: usesGeneral ? destination : nil)
            }
        } else if transition == nil { pose=target }
        if var move=transition {
            move.fixedTarget=targetOverride
            move.targetYaw += Self.angleDelta(move.previousTargetYaw,target.yaw)
            move.previousTargetYaw=target.yaw; transition=move
        }
        if next.view == .thirdPerson {
            if next.fixedAxisOrbit == true {
                let offset = Self.strikeOffset(shot)
                let requestedRadius = hypot(next.distance + offset.x, offset.y)
                if hypot(target.eye.x - shot.cue.x, target.eye.z - shot.cue.z) < requestedRadius - 0.001 {
                    diagnostic = "room-distance-clamped"
                }
            } else {
                let desired = next.distance * Self.legacyRadius(shot.bearing + next.observationYaw) / Self.legacyRadius(shot.bearing)
                if hypot(target.eye.x-shot.strike.x,target.eye.z-shot.strike.z) < desired-0.001 { diagnostic="room-distance-clamped" }
            }
        } else if next.view == .firstPerson, state.firstPersonClearanceLift > 0.001 { diagnostic="table-clearance-lift" }
        if next.view == .overview, next.overviewFramingLift > 0 { diagnostic="overview-framing-lift" }
        // During a continuing aim return, only update the destination, never restart its clock.
        return true
    }
    private static func framedPose(from origin: Pose, to target: Pose, along framing: FramingPath,
                                   at blend: Float, layout: Layout) -> Pose? {
        if blend <= 0 { return layout.legalEye(origin.eye) ? origin : nil }
        if blend >= 1 { return layout.legalEye(target.eye) ? target : nil }
        guard let start = origin.project(framing.start, layout: layout),
              let end = target.project(framing.end, layout: layout) else { return nil }

        // Interpolate around the framed subject so switching from the other side
        // of the table cannot send the eye through that point.
        let point = framing.point(at: blend)
        let from = origin.eye - framing.start, to = target.eye - framing.end
        let fromYaw = atan2(from.z, from.x), toYaw = atan2(to.z, to.x)
        let bearing = fromYaw + angleDelta(fromYaw, toYaw) * blend
        let back = SIMD2<Float>(cos(bearing), sin(bearing))
        let fromRadius = hypot(from.x, from.z), toRadius = hypot(to.x, to.z)
        let preferredRadius = fromRadius + (toRadius - fromRadius) * blend
        let wallX = abs(back.x) > 0.00001
            ? (layout.roomHalfExtents.x - (back.x > 0 ? point.x : -point.x)) / abs(back.x) : Float.infinity
        let wallZ = abs(back.y) > 0.00001
            ? (layout.roomHalfExtents.y - (back.y > 0 ? point.z : -point.z)) / abs(back.y) : Float.infinity
        let radius = min(preferredRadius, min(wallX, wallZ) - 0.0001)
        guard radius > 0.001 else { return nil }
        let eye = SIMD3<Float>(point.x + radius * back.x,
                               origin.eye.y + (target.eye.y - origin.eye.y) * blend,
                               point.z + radius * back.y)
        guard layout.legalEye(eye) else { return nil }

        let screen = start + (end - start) * blend
        let fov = origin.verticalFOV + (target.verticalFOV - origin.verticalFOV) * blend
        let tangent = tan(fov * .pi / 360)
        let ray = simd_normalize(SIMD3<Float>((2 * screen.x - 1) * tangent * layout.aspect,
                                              (1 - 2 * screen.y) * tangent, -1))
        let delta = point - eye
        // With zero roll the camera's right vector stays in XZ. Match that
        // component first, then solve pitch from the remaining forward depth.
        let rightRatio = simd_length(delta) * ray.x / radius
        let yaw = bearing - asin(min(0.999999, max(-0.999999, rightRatio)))
        let forwardDepth = -cos(yaw) * delta.x - sin(yaw) * delta.z
        let pitch = atan2(delta.y, forwardDepth) + atan((2 * screen.y - 1) * tangent)
        return .looking(eye: eye, yaw: yaw, pitch: pitch, verticalFOV: fov)
    }

    /// Independent channels preserve the accepted orbit speed. In particular,
    /// tangential eye travel is not subjected to the old 1.8 m/s chord limit.
    private static func channelTimes(from origin: Pose, to target: Pose, framing: FramingPath?,
                                     layout: Layout) -> [Double]? {
        let steps = 96
        var times = [0.0]
        var previous = origin
        for step in 1...steps {
            let u = Float(step) / Float(steps)
            let current: Pose
            var travel: Double
            if let framing {
                guard let p = framedPose(from: origin, to: target, along: framing, at: u, layout: layout) else { return nil }
                current = p
                let a = previous.eye - framing.point(at: Float(step - 1) / Float(steps))
                let b = current.eye - framing.point(at: u)
                let orbit = abs(angleDelta(atan2(a.z, a.x), atan2(b.z, b.x)))
                let radial = abs(hypot(b.x, b.z) - hypot(a.x, a.z))
                let anchor = simd_distance(framing.start, framing.end) / Float(steps)
                travel = max(Double(orbit) / TurnPace.selection120.radiansPerSecond,
                             Double(radial) / 3, Double(anchor) / 3)
            } else {
                current = .looking(eye: simd_mix(origin.eye, target.eye, SIMD3(repeating: u)),
                    yaw: origin.yaw + angleDelta(origin.yaw, target.yaw) * u,
                    pitch: origin.pitch + (target.pitch - origin.pitch) * u,
                    verticalFOV: origin.verticalFOV + (target.verticalFOV - origin.verticalFOV) * u)
                travel = Double(simd_distance(current.eye, previous.eye)) / 1.8
            }
            travel = max(travel,
                Double(abs(angleDelta(previous.yaw, current.yaw))) / TurnPace.selection120.radiansPerSecond,
                Double(abs(current.eye.y - previous.eye.y)) / 1.8,
                Double(abs(current.pitch - previous.pitch)) / (.pi / 2),
                Double(abs(current.verticalFOV - previous.verticalFOV)) / 40)
            times.append(times.last! + travel)
            previous = current
        }
        return times
    }

    private static func framedDuration(from origin: Pose, to target: Pose, along framing: FramingPath,
                                       layout: Layout) -> Double {
        // The moving anchor and room boundary bend the path. Estimate the
        // largest local rate at construction time instead of treating it as a chord.
        let steps = 48
        var previous = origin
        var maximumSeconds: Float = 0
        for step in 1...steps {
            guard let current = framedPose(from: origin, to: target, along: framing,
                                           at: Float(step) / Float(steps), layout: layout) else { return 0 }
            let distance = simd_distance(previous.eye, current.eye)
            let a = previous.forward, b = current.forward
            let angle = atan2(simd_length(simd_cross(a, b)), simd_dot(a, b))
            maximumSeconds = max(maximumSeconds, distance / 1.8, angle / (.pi / 2))
            previous = current
        }
        // A small margin covers the difference between adjacent samples and
        // the continuous path. The quintic ease has a peak derivative of 1.875.
        return Double(maximumSeconds) * Double(steps) * 1.875 * 1.025
    }

    mutating func advance(to now: Double, clear: ((SIMD3<Float>, [SIMD3<Float>]) -> Bool)? = nil) {
        guard now.isFinite, now>=time else { return }; time=now
        let sightlines = state.anchoredTransitions == true && state.view == .firstPerson ? nil : clear
        guard let move=transition, let target=move.fixedTarget ?? Self.evaluate(state:state,shot:shot,layout:layout,clear:sightlines) else { return }
        let u=Float(min(1,max(0,(now-move.start)/move.duration)))
        let t=move.blend(at: now)
        if let framing = move.framing,
           let framed = Self.framedPose(from: move.origin, to: target, along: framing, at: t, layout: layout) {
            pose = framed
            if u >= 1 { transition = nil }
            return
        }
        var eye=simd_mix(move.origin.eye,target.eye,SIMD3(repeating:t))
        eye.y += 4*t*(1-t)*move.lift
        guard layout.legalEye(eye) else { transition=nil; diagnostic="path-outside-safe-volume"; return }
        // Follow a quaternion arc, then solve the gaze from the lifted eye. This
        // avoids the zero-length gaze produced by blending opposite look vectors.
        let rotation=Pose.looking(eye:eye, yaw:move.origin.yaw+(move.targetYaw-move.origin.yaw)*t,
                                  pitch:move.origin.pitch+(target.pitch-move.origin.pitch)*t,verticalFOV:60).orientation
        let gaze=rotation.act(SIMD3<Float>(0,0,-2)) - SIMD3<Float>(0,4*t*(1-t)*move.lift,0)
        let d=simd_normalize(gaze)
        pose = .looking(eye:eye,yaw:atan2(-d.z,-d.x),pitch:asin(min(1,max(-1,d.y))),
                        verticalFOV:move.origin.verticalFOV+(target.verticalFOV-move.origin.verticalFOV)*t)
        if u>=1 { pose=target; transition=nil }
    }
    mutating func apply(_ input: Input,
                        clear: ((SIMD3<Float>, [SIMD3<Float>]) -> Bool)? = nil) {
        advance(to:input.time)
        let maximumLift: Float = state.anchoredTransitions == true || (input.shot ?? shot).observationOnlyAddress == true ? 0.65 : 0.20
        if let lift=input.clearanceLift, lift.isFinite, (0...(maximumLift + 0.0001)).contains(lift) {
            state.firstPersonClearanceLift=lift
        }
        switch input.kind {
        case .restore: if let value=input.snapshot { _=restore(value,requireSameContext: !input.restoringBoard) }
        case .focus: if let point=input.point {
            // Historical focus inputs ignored animated; preserve those recordings.
            focus(on:point, animated:state.generalTiming == .selectionMatchedV1 ? input.animated : true)
        }
        case .target: if let shot=input.shot {
            selectTarget(shot: shot, preservesVisiblePose: input.preservesVisiblePose == true, animated: input.animated,
                         turnPace: input.turnPace ?? (input.pacedTargetTurn == true ? .original180 : nil))
        }
        case .watchBreak: watchBreak(animated: input.animated, duration: input.breakPullbackSeconds)
        case .beginObservation: beginObservation()
        case .pan: pan(input.delta)
        case .pinch: pinch(input.scale, preservingPitch: input.preservePinchPitch == true, clear: clear)
        case .view: if let view=input.view { _=select(view,animated:input.animated,shot:input.shot,turnPace:input.turnPace,resetThirdPerson:input.resetThirdPerson == true) }
        case .aim: if let shot=input.shot { updateShot(shot,manuallyAimed:true) }
        case .shot: if let shot=input.shot { updateShot(shot,manuallyAimed:false) }
        case .release: release()
        case .layout: if let layout=input.layout { setLayout(layout) }
        case .context: if let context=input.context { setContext(context) }
        }
    }
    static func angleDelta(_ a: Float, _ b: Float) -> Float { atan2(sin(b-a),cos(b-a)) }
}

private extension SIMD4 where Scalar == Float {
    var allFinite: Bool { x.isFinite && y.isFinite && z.isFinite && w.isFinite }
}
