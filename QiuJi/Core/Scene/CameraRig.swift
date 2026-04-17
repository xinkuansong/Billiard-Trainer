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
            aimFov: 35,
            standFov: 55,
            minRadius: 1.5,
            maxRadius: 4.0,
            minHeight: 0.8,
            maxHeight: 3.5,
            aimPitchRad: -0.35,
            standPitchRad: -1.2,
            dampingFactor: 0.15
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

    private enum ObservationConfig {
        static let zoom: Float = 1.0
        static let radius: Float = 2.0
        static let height: Float = 1.2
        static let fov: Float = 50
        static let pitchRad: Float = -45 * .pi / 180
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

    private(set) var currentViewMode: ViewMode = .observation

    // MARK: - Smooth Transition State

    private var smoothTarget: SmoothPose?
    private var smoothOrigin: SmoothPose?
    private var smoothProgress: Float = 1.0
    private var smoothDuration: Float = 0.5
    var isTransitioning: Bool { smoothProgress < 1.0 }

    // MARK: - 2D Mode State

    /// Orthographic half-height in scene units. For rotated 2D view, this is along
    /// the table's long axis (innerLength = 2.54m), so use innerLength/2 + padding.
    var topDownOrthographicScale: Double = Double(AngleSceneCalculator.innerLength) * 0.6
    var topDownPanOffset: CGPoint = .zero

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
        let sensitivity: Float = 0.008
        targetYaw += delta * sensitivity
        currentYaw += delta * sensitivity
    }

    func handleVerticalSwipe(delta: Float) {
        let sensitivity: Float = 0.005
        let newZoom = max(0, min(1, targetZoom + delta * sensitivity))
        targetZoom = newZoom
        currentZoom = newZoom
    }

    func handlePinch(scale: Float) {
        let pinchDelta = (1 - max(0.01, scale)) * 0.8
        targetZoom = max(0, min(1, targetZoom + pinchDelta))
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

        let targetPose = SmoothPose(
            yaw: targetYaw,
            pitch: config.aimPitchRad,
            radius: lerp(config.minRadius, config.maxRadius, 0.0),
            pivot: targetPivot,
            fov: Float(config.aimFov),
            height: config.minHeight
        )
        smoothToPose(targetPose, duration: 0.5)
    }

    func handleObservationPan(deltaX: Float) {
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
        let currentPose = captureCurrentPose()
        smoothOrigin = currentPose
        smoothTarget = pose
        smoothProgress = 0
        smoothDuration = max(0.1, duration)
    }

    func captureCurrentPose() -> SmoothPose {
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
            let t = smoothStep(smoothProgress)

            currentYaw = origin.yaw + shortestAngleDelta(from: origin.yaw, to: target.yaw) * t
            currentPivot = lerpVec(origin.pivot, target.pivot, t)
            let radius = lerp(origin.radius, target.radius, t)
            let height = lerp(origin.height, target.height, t)
            let pitch = lerp(origin.pitch, target.pitch, t)
            let fov = lerp(origin.fov, target.fov, t)

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
            }
            return
        }

        let frameScale = max(0.25, min(2.0, deltaTime * 60))
        let t = min(1, config.dampingFactor * frameScale)

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
        currentZoom = targetZoom
        currentYaw = targetYaw
        currentPivot = targetPivot
        applyCameraTransform()
    }

    // MARK: - Private

    private func applyCameraTransform() {
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

    private func shortestAngleDelta(from: Float, to: Float) -> Float {
        var delta = to - from
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        return delta
    }
}

// MARK: - SCNVector3 helpers

private extension SCNVector3 {
    func normalized() -> SCNVector3 {
        let len = sqrtf(x * x + y * y + z * z)
        guard len > 0.0001 else { return self }
        return SCNVector3(x / len, y / len, z / len)
    }

    static func + (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        SCNVector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }

    static func - (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        SCNVector3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }

    static func * (lhs: SCNVector3, rhs: Float) -> SCNVector3 {
        SCNVector3(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    }
}
