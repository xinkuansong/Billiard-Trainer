import SceneKit

/// Camera rig for angle training scenes.
/// Supports orbit mode (3D) with observation/aiming views,
/// and orthographic pan/zoom (2D top-down).
final class CameraRig {

    // MARK: - Config

    struct Config {
        let aimFov: CGFloat
        let standFov: CGFloat
        let minRadius: Float
        let maxRadius: Float
        let minHeight: Float
        let maxHeight: Float
        let aimPitchRad: Float
        let standPitchRad: Float
        let dampingFactor: Float

        static let `default` = Config(
            aimFov: AimingCameraConfig.aimFov,
            standFov: AimingCameraConfig.standFov,
            minRadius: AimingCameraConfig.aimRadius,
            maxRadius: AimingCameraConfig.standRadius,
            minHeight: AimingCameraConfig.aimHeight,
            maxHeight: AimingCameraConfig.standHeight,
            aimPitchRad: AimingCameraConfig.aimPitchRad,
            standPitchRad: AimingCameraConfig.standPitchRad,
            dampingFactor: AimingCameraConfig.dampingFactor
        )
    }

    // MARK: - Smooth Pose (for animated transitions)

    struct SmoothPose {
        var yaw: Float
        var pitch: Float
        var radius: Float
        var pivot: SCNVector3
        var fov: Float
        var height: Float
    }

    enum ViewMode {
        case observation
        case aiming
    }

    // MARK: - Observation Constants
    //
    // Mirrors `AimingCameraConfig`'s stand-pose so that:
    //   • `enterObservation` lands at `zoom == 1`, and the post-transition
    //     `applyCameraTransform` (which derives radius/height/pitch/fov from
    //     `currentZoom`) reproduces the *exact* observation pose. Otherwise
    //     the camera "comes closer" right after the transition — that was
    //     the visual regression the user reported (#1).
    //   • Vertical-swipe up to the upper bound = observation pose. So the
    //     observation toggle and the swipe gesture agree on the high view.

    private enum ObservationConfig {
        static let zoom: Float = 1.0
        static var radius: Float { AimingCameraConfig.standRadius }
        static var height: Float { AimingCameraConfig.standHeight }
        static var fov: Float { Float(AimingCameraConfig.standFov) }
        static var pitchRad: Float { AimingCameraConfig.standPitchRad }
        static let transitionSpeed: Float = 3.0
        static let returnToAimDuration: Float = 0.5
    }

    // MARK: - Properties

    private let cameraNode: SCNNode
    private let tableSurfaceY: Float
    private let config: Config

    var targetPivot: SCNVector3
    var targetZoom: Float
    var targetYaw: Float

    private(set) var currentPivot: SCNVector3
    private(set) var currentZoom: Float
    private(set) var currentYaw: Float

    var zoom: Float { currentZoom }

    /// Independent user orbit. Preset transitions keep their existing pose ladder.
    struct OrbitState {
        var distance: Float
        var elevation: Float
        var pitchOffset: Float
        var fov: Float
    }
    private var currentOrbit: OrbitState?
    private var targetOrbit: OrbitState?
    private var keepsWholeTableFramed = false
    var viewportSize: CGSize = .zero {
        didSet {
            guard viewportSize != oldValue, keepsWholeTableFramed else { return }
            observeWholeTable()
        }
    }
    private var fittedOrbitDistance: Float = 0
    var orbitDistance: Float { currentOrbit?.distance ?? hypot(captureCurrentPose().radius, captureCurrentPose().height) }
    var orbitElevation: Float { currentOrbit?.elevation ?? atan2(captureCurrentPose().height, captureCurrentPose().radius) }


    private(set) var currentViewMode: ViewMode = .observation

    // MARK: - Smooth Transition State

    private var smoothTarget: SmoothPose?
    private var smoothOrigin: SmoothPose?
    private var smoothProgress: Float = 1.0
    private var smoothDuration: Float = 0.5
    /// Last pose written to the camera node during a smooth transition.
    /// `captureCurrentPose()` returns this when an animation is in flight,
    /// so a mid-transition `smoothToPose(_:duration:)` call sees the actual
    /// visible pose as its starting origin instead of snapping back to a
    /// stale `currentZoom`-derived pose.
    private var currentInterpolatedPose: SmoothPose?
    var isTransitioning: Bool { smoothProgress < 1.0 }
    /// Automatic HUD anchoring must not translate a user-controlled observation pivot.
    var allowsCueScreenAnchor: Bool { currentOrbit == nil && !isTransitioning }

    /// Numerical settling floors in scene metres, yaw radians and normalized
    /// zoom; the damping law itself is unchanged. Allow Float rounding at large
    /// accumulated yaw so idle can still converge.
    var hasPendingDamping: Bool {
        let precision: Float = 0.00001
        let yawPrecision = max(precision, max(abs(currentYaw), abs(targetYaw)) * Float.ulpOfOne * 32)
        let orbitPending: Bool
        if let currentOrbit, let targetOrbit {
            orbitPending = abs(currentOrbit.distance - targetOrbit.distance) > precision
                || abs(currentOrbit.elevation - targetOrbit.elevation) > precision
                || abs(currentOrbit.pitchOffset - targetOrbit.pitchOffset) > precision
                || abs(currentOrbit.fov - targetOrbit.fov) > precision
        } else { orbitPending = false }
        return orbitPending || abs(shortestAngleDelta(from: currentYaw, to: targetYaw)) > yawPrecision
            || abs(currentZoom - targetZoom) > precision
            || abs(currentPivot.x - targetPivot.x) > precision
            || abs(currentPivot.y - targetPivot.y) > precision
            || abs(currentPivot.z - targetPivot.z) > precision
    }


    /// View-only state: keeps damping and an interrupted smooth move intact across 2D.
    struct PerspectiveState {
        fileprivate let currentPivot, targetPivot: SCNVector3
        fileprivate let currentYaw, targetYaw, currentZoom, targetZoom: Float
        fileprivate let viewMode: ViewMode
        fileprivate let origin, target, interpolated: SmoothPose?
        fileprivate let progress, duration: Float
        fileprivate let transform: SCNMatrix4
        fileprivate let fieldOfView: CGFloat
        fileprivate let currentOrbit, targetOrbit: OrbitState?
        fileprivate let keepsWholeTableFramed: Bool
    }

    func capturePerspectiveState() -> PerspectiveState {
        PerspectiveState(currentPivot: currentPivot, targetPivot: targetPivot,
                         currentYaw: currentYaw, targetYaw: targetYaw,
                         currentZoom: currentZoom, targetZoom: targetZoom,
                         viewMode: currentViewMode, origin: smoothOrigin,
                         target: smoothTarget, interpolated: currentInterpolatedPose,
                         progress: smoothProgress, duration: smoothDuration,
                         transform: cameraNode.transform,
                         fieldOfView: cameraNode.camera?.fieldOfView ?? config.standFov,
                         currentOrbit: currentOrbit, targetOrbit: targetOrbit,
                         keepsWholeTableFramed: keepsWholeTableFramed)
    }

    func restorePerspectiveState(_ state: PerspectiveState) {
        keepsWholeTableFramed = state.keepsWholeTableFramed
        currentOrbit = state.currentOrbit
        targetOrbit = state.targetOrbit
        currentPivot = state.currentPivot
        targetPivot = state.targetPivot
        currentYaw = state.currentYaw
        targetYaw = state.targetYaw
        currentZoom = state.currentZoom
        targetZoom = state.targetZoom
        currentViewMode = state.viewMode
        smoothOrigin = state.origin
        smoothTarget = state.target
        currentInterpolatedPose = state.interpolated
        smoothProgress = state.progress
        smoothDuration = state.duration
        cameraNode.transform = state.transform
        cameraNode.camera?.fieldOfView = state.fieldOfView
        cameraNode.camera?.usesOrthographicProjection = false
    }

    // MARK: - 2D Mode State

    /// Orthographic half-height in scene units. For rotated 2D view, this is along
    /// the table's long axis (innerLength = 2.54m), so use innerLength/2 + padding.
    var topDownOrthographicScale: Double = Double(AngleSceneCalculator.innerLength) * 0.6
    var topDownPanOffset: CGPoint = .zero

    // MARK: - Rotated top-down auto fit（统一取景，ADR-P11-08）

    /// USDZ 球桌外框实测兜底值；装桌后会由 `AngleTrainingScene` 的实测结果覆盖实例值。
    static let defaultTableOuterHalfLength: Double = 1.4055
    static let defaultTableOuterHalfWidth: Double = 0.7995
    static let defaultTableOuterAspect =
        defaultTableOuterHalfLength / defaultTableOuterHalfWidth

    /// 球桌外框半长（世界 X，rotated 顶视屏幕竖轴）。
    var tableOuterHalfLength: Double = CameraRig.defaultTableOuterHalfLength
    /// 球桌外框半宽（世界 Z，rotated 顶视屏幕横轴）。
    var tableOuterHalfWidth: Double = CameraRig.defaultTableOuterHalfWidth
    /// 取景安全余量（比例）：避免抗锯齿/阴影边缘贴边裁切。
    static let rotatedFitMargin: Double = 1.012

    /// 跨页统一球桌大小（#10）的统一正交 scale 下限。各 2D 球桌页的可视区高度受各自
    /// 顶/底控件影响而不同，纯自适应取景会让球桌「能多大就多大」⇒ 跨页大小不一。用一个
    /// 不低于常见视口自适应值的统一 scale 作为下限：常规页一律取此值 ⇒ 球桌呈现一致大小
    /// （顶/底留等量极小黑边）；仅极端窄高视口自适应值超过它时回退自适应，保证完整可见不裁切。
    /// 取值须 ≥ `tableOuterHalfLength × rotatedFitMargin`（竖轴约束），当前 ≈ 1.423。
    static let rotatedUnifiedScale: Double = 1.50

    /// 按视口宽高比把 rotated 顶视正交 scale 调到「球桌完整可见 + 双轴居中」的值。
    /// 竖轴约束：scale ≥ 半长×余量；横轴约束：scale×(W/H) ≥ 半宽×余量。再以统一 scale
    /// 兜底（取三者最大）⇒ 跨页球桌大小一致。所有 2D 球桌页共用此取景。
    func fitRotatedTable(viewSize: CGSize) {
        guard viewSize.width > 1, viewSize.height > 1 else { return }
        let fitVertical = tableOuterHalfLength * Self.rotatedFitMargin
        let fitHorizontal = tableOuterHalfWidth * Self.rotatedFitMargin
            * Double(viewSize.height / viewSize.width)
        topDownOrthographicScale = max(fitVertical, fitHorizontal, Self.rotatedUnifiedScale)
    }

    /// 横向顶视按真实外框与视口比例自适应：屏幕竖轴对应世界 Z，横轴对应世界 X。
    /// 返回正交半高，双轴均保留 `rotatedFitMargin` 安全余量，避免固定 scale 裁掉木框。
    static func landscapeOrthographicScale(
        viewSize: CGSize,
        halfLength: Double,
        halfWidth: Double
    ) -> Double? {
        guard viewSize.width > 1, viewSize.height > 1 else { return nil }
        let fitVertical = halfWidth * rotatedFitMargin
        let fitHorizontal = halfLength * rotatedFitMargin
            * Double(viewSize.height / viewSize.width)
        return max(fitVertical, fitHorizontal)
    }

    func fitLandscapeTable(viewSize: CGSize) {
        guard let scale = Self.landscapeOrthographicScale(
            viewSize: viewSize,
            halfLength: tableOuterHalfLength,
            halfWidth: tableOuterHalfWidth
        ) else { return }
        topDownOrthographicScale = scale
    }

    // MARK: - Init

    init(cameraNode: SCNNode, tableSurfaceY: Float, config: Config = .default) {
        self.cameraNode = cameraNode
        self.tableSurfaceY = tableSurfaceY
        self.config = config

        targetPivot = SCNVector3(0, tableSurfaceY, 0)
        targetZoom = 0.5
        targetYaw = 0
        currentPivot = targetPivot
        currentZoom = targetZoom
        currentYaw = targetYaw

        cameraNode.camera?.fieldOfView = config.standFov
        applyCameraTransform()
    }

    // MARK: - Input handlers (3D mode)

    func handleHorizontalSwipe(delta: Float) {
        beginManualOrbit()
        // Sensitivity 0.0025 — half of the previous value. Crucially we
        // only update `targetYaw`, not `currentYaw`: the per-frame damping
        // in `update(deltaTime:)` (dampingFactor 0.12) then eases
        // `currentYaw` toward target, giving a soft inertial follow that
        // dramatically reduces jitter compared to writing both at once.
        let sensitivity: Float = 0.0025
        targetYaw += delta * sensitivity
    }

    func handleVerticalSwipe(delta: Float) {
        beginManualOrbit()
        guard var orbit = targetOrbit else { return }
        // Full overhead is available; the lower bound retains the preset clearance.
        let minimumElevation = atan2(config.minHeight, config.maxRadius)
        let maximumElevation = .pi / 2 + min(0, orbit.pitchOffset)
        orbit.elevation = max(minimumElevation, min(maximumElevation, orbit.elevation + delta * 0.0035))
        targetOrbit = orbit
    }

    func handlePinch(scale: Float) {
        beginManualOrbit()
        guard var orbit = targetOrbit else { return }
        let maximumDistance = max(fittedOrbitDistance,
                                  max(hypot(config.maxRadius, config.maxHeight),
                                      2 * hypot(Float(tableOuterHalfLength), Float(tableOuterHalfWidth))))
        orbit.distance = max(config.minRadius,
                             min(maximumDistance, orbit.distance / max(0.01, scale)))
        targetOrbit = orbit
    }

    /// A gesture takes ownership from automatic framing at the currently visible pose.
    private func beginManualOrbit() {
        keepsWholeTableFramed = false
        if currentOrbit == nil {
            let pose = captureCurrentPose()
            let relativeHeight = pose.height - (pose.pivot.y - tableSurfaceY)
            let elevation = atan2(relativeHeight, pose.radius)
            let orbit = OrbitState(distance: hypot(pose.radius, relativeHeight), elevation: elevation,
                                   pitchOffset: pose.pitch + elevation, fov: pose.fov)
            currentOrbit = orbit
            targetOrbit = orbit
            currentYaw = pose.yaw
            targetYaw = pose.yaw
            currentPivot = pose.pivot
            targetPivot = pose.pivot
        }
        disableSmoothPoseControl()
        currentViewMode = .observation
    }

    /// Observation is a camera intent; it has no access to selected balls or shot parameters.
    func observe(at point: SCNVector3) {
        guard point.x.isFinite, point.y.isFinite, point.z.isFinite else { return }
        beginManualOrbit()
        targetPivot = point
        targetOrbit?.pitchOffset = 0
    }

    /// Fits the playable table envelope, including ball height, to the actual viewport.
    /// Returns false before layout; no guessed screen aspect is substituted.
    @discardableResult
    func observeWholeTable(yaw: Float? = nil) -> Bool {
        guard viewportSize.width > 1, viewportSize.height > 1 else { return false }
        beginManualOrbit()
        if let yaw, yaw.isFinite { targetYaw = yaw }
        guard var orbit = targetOrbit else { return false }
        orbit.elevation = abs(config.standPitchRad)
        orbit.pitchOffset = 0
        orbit.fov = Float(config.standFov)
        let pivot = SCNVector3(0, tableSurfaceY + BallPhysics.radius, 0)
        let back = SCNVector3(cos(targetYaw) * cos(orbit.elevation), sin(orbit.elevation),
                             sin(targetYaw) * cos(orbit.elevation))
        let right = SCNVector3(-sin(targetYaw), 0, cos(targetYaw))
        let up = SCNVector3(-cos(targetYaw) * sin(orbit.elevation), cos(orbit.elevation),
                           -sin(targetYaw) * sin(orbit.elevation))
        let tanV = tan(orbit.fov * .pi / 360)
        let tanH = tanV * Float(viewportSize.width / viewportSize.height)
        func dot(_ a: SCNVector3, _ b: SCNVector3) -> Float { a.x*b.x + a.y*b.y + a.z*b.z }
        var distance = config.minRadius
        for x in [-Float(tableOuterHalfLength), Float(tableOuterHalfLength)] {
            for z in [-Float(tableOuterHalfWidth), Float(tableOuterHalfWidth)] {
                for y in [-BallPhysics.radius, BallPhysics.radius] {
                    let offset = SCNVector3(x,y,z)
                    let depthOffset = dot(offset, back)
                    distance = max(distance, depthOffset + abs(dot(offset,right))/tanH,
                                   depthOffset + abs(dot(offset,up))/tanV)
                }
            }
        }
        orbit.distance = distance * Float(Self.rotatedFitMargin)
        fittedOrbitDistance = orbit.distance
        keepsWholeTableFramed = true
        targetPivot = pivot
        targetOrbit = orbit
        return true
    }

    // MARK: - Input handlers (2D mode)

    func applyCameraPan(translationX: Float, translationZ: Float) {
        let scale = Float(topDownOrthographicScale) * 0.002
        topDownPanOffset.x += CGFloat(translationX * scale)
        topDownPanOffset.y += CGFloat(translationZ * scale)

        let maxPan: CGFloat = 0.8
        topDownPanOffset.x = max(-maxPan, min(maxPan, topDownPanOffset.x))
        topDownPanOffset.y = max(-maxPan, min(maxPan, topDownPanOffset.y))
    }

    func applyTopDownAreaZoom(scale: Float) {
        let minScale = 0.3
        let maxScale = 2.0
        let newScale = topDownOrthographicScale / Double(max(0.01, scale))
        topDownOrthographicScale = max(minScale, min(maxScale, newScale))
    }

    // MARK: - Observation / Aiming

    func enterObservation(cueBallPosition: SCNVector3, aimDirection: SCNVector3) {
        currentViewMode = .observation
        targetPivot = SCNVector3(cueBallPosition.x, tableSurfaceY, cueBallPosition.z)

        let flatAim = SCNVector3(aimDirection.x, 0, aimDirection.z)
        let len = sqrtf(flatAim.x * flatAim.x + flatAim.z * flatAim.z)
        if len > 0.0001 {
            targetYaw = atan2(-flatAim.z / len, -flatAim.x / len)
        }

        let targetPose = SmoothPose(
            yaw: targetYaw,
            pitch: ObservationConfig.pitchRad,
            radius: ObservationConfig.radius,
            pivot: targetPivot,
            fov: ObservationConfig.fov,
            height: ObservationConfig.height
        )
        smoothToPose(targetPose, duration: 0.6)
    }

    func enterAiming(cueBallPosition: SCNVector3, targetDirection: SCNVector3) {
        currentViewMode = .aiming
        targetPivot = SCNVector3(cueBallPosition.x, tableSurfaceY, cueBallPosition.z)

        let flatAim = SCNVector3(targetDirection.x, 0, targetDirection.z)
        let len = sqrtf(flatAim.x * flatAim.x + flatAim.z * flatAim.z)
        if len > 0.0001 {
            targetYaw = atan2(-flatAim.z / len, -flatAim.x / len)
        }

        // Both 3D training pages enter at the midpoint of the existing pose ladder.
        // Reset deterministically for every question; gestures retain the full [0, 1] range.
        // Keep currentZoom intact until smoothToPose captures the visible starting pose.
        let entryZoom: Float = 0.5
        let prevZoom = currentZoom
        let targetPose = SmoothPose(
            yaw: targetYaw,
            pitch: lerp(config.aimPitchRad, config.standPitchRad, entryZoom * entryZoom),
            radius: lerp(config.minRadius, config.maxRadius, entryZoom),
            pivot: targetPivot,
            fov: lerp(Float(config.aimFov), Float(config.standFov), entryZoom),
            height: lerp(config.minHeight, config.maxHeight, entryZoom)
        )
        #if DEBUG
        print(String(format:
            "[CameraRig.enterAiming] pivot=(%.3f,%.3f,%.3f) yaw=%.3f entryZoom=%.2f prevZoom=%.2f radius=%.3f height=%.3f (wasTransitioning=%d)",
            targetPivot.x, targetPivot.y, targetPivot.z, targetYaw,
            entryZoom, prevZoom, targetPose.radius, targetPose.height,
            isTransitioning ? 1 : 0))
        #endif
        // 0.6s matches `enterObservation`. Δheight ≈ 1m and Δpitch ≈ 30°,
        // so a shorter duration shows up as a perceptible "snap" mid-motion.
        smoothToPose(targetPose, duration: 0.6)
    }

    func handleObservationPan(deltaX: Float) {
        beginManualOrbit()
        let sensitivity: Float = 0.006
        targetYaw += deltaX * sensitivity
    }

    func handleObservationPinch(scale: Float) {
        handlePinch(scale: scale)
    }

    func setAimYaw(_ yaw: Float) {
        targetYaw = yaw
        currentYaw = yaw
    }

    func aimDirectionForCurrentYaw() -> SCNVector3 {
        SCNVector3(-cosf(currentYaw), 0, -sinf(currentYaw))
    }

    // MARK: - Smooth Pose Transition

    func smoothToPose(_ pose: SmoothPose, duration: Float) {
        keepsWholeTableFramed = false
        let currentPose = captureCurrentPose()
        currentOrbit = nil
        targetOrbit = nil
        smoothOrigin = currentPose
        smoothTarget = pose
        smoothProgress = 0
        smoothDuration = max(0.1, duration)
    }

    /// Cancel any in-flight `smoothToPose(_:duration:)` animation and let the
    /// caller take direct control of `targetYaw / targetZoom / targetPivot`.
    /// Used by `AngleTrainingScene` before driving the camera through a
    /// 2D⇄3D mode-switch transaction.
    func disableSmoothPoseControl() {
        smoothOrigin = nil
        smoothTarget = nil
        smoothProgress = 1.0
        currentInterpolatedPose = nil
    }

    /// Translate the orbit pivot by an XZ delta. With `immediate: true` both
    /// `targetPivot` and `currentPivot` are snapped (no easing), matching the
    /// reference rig's anchor-lock semantics — the cue ball stays pinned to
    /// its on-screen position while the world slides under the camera.
    func translatePivot(deltaXZ: SCNVector3, immediate: Bool) {
        let delta = SCNVector3(deltaXZ.x, 0, deltaXZ.z)
        targetPivot = SCNVector3(
            targetPivot.x + delta.x,
            targetPivot.y,
            targetPivot.z + delta.z
        )
        if immediate {
            currentPivot = SCNVector3(
                currentPivot.x + delta.x,
                currentPivot.y,
                currentPivot.z + delta.z
            )
            applyCameraTransform()
        }
    }

    func captureCurrentPose() -> SmoothPose {
        if let orbit = currentOrbit {
            return SmoothPose(yaw: currentYaw, pitch: -orbit.elevation + orbit.pitchOffset,
                              radius: orbit.distance * cos(orbit.elevation), pivot: currentPivot,
                              fov: orbit.fov,
                              height: currentPivot.y - tableSurfaceY + orbit.distance * sin(orbit.elevation))
        }
        // While a smooth transition is in flight, return the last
        // interpolated pose so that re-entering smoothToPose does not snap
        // the camera back to a stale `currentZoom`-derived starting point.
        if let live = currentInterpolatedPose, smoothProgress < 1.0 {
            return live
        }
        let z = max(0, min(1, currentZoom))
        let radius = lerp(config.minRadius, config.maxRadius, z)
        let height = lerp(config.minHeight, config.maxHeight, z)
        let pitch = lerp(config.aimPitchRad, config.standPitchRad, z * z)
        let fov = lerp(Float(config.aimFov), Float(config.standFov), z)
        return SmoothPose(yaw: currentYaw, pitch: pitch, radius: radius, pivot: currentPivot, fov: fov, height: height)
    }

    // MARK: - Update

    func update(deltaTime: Float) {
        if smoothProgress < 1.0, let origin = smoothOrigin, let target = smoothTarget {
            smoothProgress += deltaTime / smoothDuration
            smoothProgress = min(1.0, smoothProgress)
            // smootherstep (5th-order, C2-continuous): no discontinuous
            // acceleration at the endpoints, so the camera glides in / out
            // of motion instead of "tugging".
            let t = smootherStep(smoothProgress)

            currentYaw = origin.yaw + shortestAngleDelta(from: origin.yaw, to: target.yaw) * t
            currentPivot = lerpVec(origin.pivot, target.pivot, t)
            let radius = lerp(origin.radius, target.radius, t)
            let height = lerp(origin.height, target.height, t)
            let pitch = lerp(origin.pitch, target.pitch, t)
            let fov = lerp(origin.fov, target.fov, t)

            // Cache the live pose so a mid-transition smoothToPose call has
            // a non-stale starting origin (see captureCurrentPose).
            currentInterpolatedPose = SmoothPose(
                yaw: currentYaw, pitch: pitch, radius: radius,
                pivot: currentPivot, fov: fov, height: height
            )

            let cameraY = tableSurfaceY + max(0.3, height)
            let forwardXZ = SCNVector3(-cosf(currentYaw), 0, -sinf(currentYaw))
            let position = SCNVector3(
                currentPivot.x - forwardXZ.x * radius,
                cameraY,
                currentPivot.z - forwardXZ.z * radius
            )
            let lookDir = (currentPivot - position).normalized()
            let yawEuler = atan2f(-lookDir.x, -lookDir.z)

            cameraNode.position = position
            cameraNode.eulerAngles = SCNVector3(pitch, yawEuler, 0)
            cameraNode.camera?.fieldOfView = CGFloat(fov)
            cameraNode.camera?.usesOrthographicProjection = false

            if smoothProgress >= 1.0 {
                targetYaw = currentYaw
                targetPivot = currentPivot
                let newZoom = (radius - config.minRadius) / max(0.001, config.maxRadius - config.minRadius)
                targetZoom = max(0, min(1, newZoom))
                currentZoom = targetZoom
                smoothOrigin = nil
                smoothTarget = nil
                currentInterpolatedPose = nil
            }
            return
        }

        let frameScale = max(0.25, min(2.0, deltaTime * 60))
        let t = min(1, config.dampingFactor * frameScale)

        if var orbit = currentOrbit, let target = targetOrbit {
            orbit.distance = lerp(orbit.distance, target.distance, t)
            orbit.elevation = lerp(orbit.elevation, target.elevation, t)
            orbit.pitchOffset = lerp(orbit.pitchOffset, target.pitchOffset, t)
            orbit.fov = lerp(orbit.fov, target.fov, t)
            currentOrbit = orbit
        }
        currentZoom += (targetZoom - currentZoom) * t
        currentYaw += shortestAngleDelta(from: currentYaw, to: targetYaw) * t
        currentPivot = currentPivot + (targetPivot - currentPivot) * t

        applyCameraTransform()
    }

    func applyTopDown2D() {
        cameraNode.camera?.usesOrthographicProjection = true
        cameraNode.camera?.orthographicScale = topDownOrthographicScale

        let panX = Float(topDownPanOffset.x)
        let panZ = Float(topDownPanOffset.y)
        cameraNode.position = SCNVector3(panX, tableSurfaceY + 5.0, panZ)
        cameraNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
    }

    /// Top-down 2D view with the table's long axis (X) appearing vertically on screen,
    /// so the table fits the phone's portrait orientation (long edge along long edge).
    func applyTopDown2DRotated() {
        cameraNode.camera?.usesOrthographicProjection = true
        cameraNode.camera?.orthographicScale = topDownOrthographicScale

        let panX = Float(topDownPanOffset.x)
        let panZ = Float(topDownPanOffset.y)
        cameraNode.position = SCNVector3(panX, tableSurfaceY + 5.0, panZ)
        // Look straight down at the table center, with world +X as the screen "up" direction.
        // Using look(at:up:) avoids the euler-angle order pitfall where Rz(π/2) applied AFTER
        // Rx(-π/2) would re-orient the forward vector sideways instead of keeping it down.
        cameraNode.look(
            at: SCNVector3(panX, tableSurfaceY, panZ),
            up: SCNVector3(1, 0, 0),
            localFront: SCNVector3(0, 0, -1)
        )
    }

    func snapToTarget() {
        if let targetOrbit { currentOrbit = targetOrbit }
        currentZoom = targetZoom
        currentYaw = targetYaw
        currentPivot = targetPivot
        applyCameraTransform()
    }

    /// Sync the rig's internal pose state directly to the aim pose without
    /// running any animation. Called by `AngleTrainingScene.transitionToPerspective`
    /// once the SCNTransaction has visually placed the camera in aim pose:
    /// without this, the rig would still think it's at whatever zoom /
    /// yaw / pivot it had before the 2D toggle, and the next `update(_:)`
    /// frame would overwrite the camera's actual pose with the stale
    /// internal state — which is the visible "snap from observation to
    /// aim" wobble the user reported when toggling 2D → 3D.
    /// - Skips `applyCameraTransform()` because the caller (SCNTransaction)
    ///   has already set the camera node to the desired pose; we only
    ///   need to align internal state for future input handling.
    func snapToAimPose(pivot: SCNVector3, aimDirection: SCNVector3) {
        currentOrbit = nil
        targetOrbit = nil
        let flatAim = SCNVector3(aimDirection.x, 0, aimDirection.z)
        let len = sqrtf(flatAim.x * flatAim.x + flatAim.z * flatAim.z)
        let yaw = len > 0.0001 ? atan2(-flatAim.z / len, -flatAim.x / len) : currentYaw

        targetPivot = SCNVector3(pivot.x, tableSurfaceY, pivot.z)
        targetYaw = yaw
        targetZoom = 0
        currentPivot = targetPivot
        currentYaw = yaw
        currentZoom = 0
        currentViewMode = .aiming

        // Cancel any in-flight smooth transition so it doesn't fight the
        // freshly-snapped state.
        smoothOrigin = nil
        smoothTarget = nil
        smoothProgress = 1.0
        currentInterpolatedPose = nil
    }

    // MARK: - Private

    private func applyCameraTransform() {
        if let orbit = currentOrbit {
            let radius = orbit.distance * cos(orbit.elevation)
            cameraNode.position = SCNVector3(currentPivot.x + cos(currentYaw) * radius,
                                             currentPivot.y + orbit.distance * sin(orbit.elevation),
                                             currentPivot.z + sin(currentYaw) * radius)
            let look = SCNVector3(-cos(currentYaw), 0, -sin(currentYaw))
            cameraNode.eulerAngles = SCNVector3(-orbit.elevation + orbit.pitchOffset,
                                                atan2(-look.x, -look.z), 0)
            cameraNode.camera?.fieldOfView = CGFloat(orbit.fov)
            cameraNode.camera?.usesOrthographicProjection = false
            return
        }
        let z = max(0, min(1, currentZoom))
        let radius = lerp(config.minRadius, config.maxRadius, z)
        let height = lerp(config.minHeight, config.maxHeight, z)
        let cameraY = tableSurfaceY + max(0.3, height)

        let easedZoom = z * z
        let pitch = lerp(config.aimPitchRad, config.standPitchRad, easedZoom)

        let forwardXZ = SCNVector3(-cosf(currentYaw), 0, -sinf(currentYaw))
        let position = SCNVector3(
            currentPivot.x - forwardXZ.x * radius,
            cameraY,
            currentPivot.z - forwardXZ.z * radius
        )

        let lookDir = (currentPivot - position).normalized()
        let yawEuler = atan2f(-lookDir.x, -lookDir.z)

        cameraNode.position = position
        cameraNode.eulerAngles = SCNVector3(pitch, yawEuler, 0)

        let fov = CGFloat(lerp(Float(config.aimFov), Float(config.standFov), z))
        cameraNode.camera?.fieldOfView = fov
        cameraNode.camera?.usesOrthographicProjection = false
    }

    private func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
        a + (b - a) * max(0, min(1, t))
    }

    private func lerpVec(_ a: SCNVector3, _ b: SCNVector3, _ t: Float) -> SCNVector3 {
        SCNVector3(
            a.x + (b.x - a.x) * t,
            a.y + (b.y - a.y) * t,
            a.z + (b.z - a.z) * t
        )
    }

    private func smoothStep(_ t: Float) -> Float {
        let x = max(0, min(1, t))
        return x * x * (3 - 2 * x)
    }

    /// 5th-order smootherstep (Ken Perlin). C2-continuous — first **and**
    /// second derivatives are zero at the endpoints, eliminating the slight
    /// "tug" the cubic smoothstep produces when starting/stopping a motion.
    private func smootherStep(_ t: Float) -> Float {
        let x = max(0, min(1, t))
        return x * x * x * (x * (x * 6 - 15) + 10)
    }

    private func shortestAngleDelta(from: Float, to: Float) -> Float {
        var delta = to - from
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        return delta
    }
}

// MARK: - SCNVector3 helpers
//
// `normalized()` / `+` / `-` / `*` 现由 `Core/Physics/SCNVector3+Physics.swift`
// 提供模块级实现（物理引擎移植时引入）。此处原有的 file-private 扩展会与之
// 产生同签名重载歧义，故移除，统一复用模块级版本。
