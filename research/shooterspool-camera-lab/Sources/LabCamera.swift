import SwiftUI
import SceneKit
import simd

enum LabView: String, CaseIterable {
    case global = "全局观察", standing = "站立找线", down = "俯身瞄准", top = "临时俯视"
}

@MainActor
final class LabCamera: ObservableObject {
    struct Adjustment {
        var look: Float = 0
        var tilt: Float = 0
        var zoom: Float = 1
    }
    struct Pose {
        var eye: SIMD3<Float>
        var rotation: simd_quatf
        var fov: Float

        init(_ eye: SIMD3<Float>, yaw: Float, pitch: Float, fov: Float) {
            self.eye = eye
            let node = SCNNode()
            let flat = SIMD3<Float>(cos(yaw), 0, sin(yaw))
            node.simdPosition = eye
            node.simdLook(at: eye + flat * cos(pitch) + SIMD3(0, sin(pitch), 0))
            rotation = node.simdOrientation
            self.fov = fov
        }
        func toward(_ target: Self, fraction t: Float) -> Self {
            var p = self
            p.eye = eye + (target.eye - eye) * t
            p.rotation = simd_slerp(rotation, target.rotation, t)
            p.fov += (target.fov - fov) * t
            return p
        }
    }

    weak var host: PositionPlayViewModel?
    var wake: (() -> Void)?
    @Published private(set) var mode: LabView = .standing
    @Published private(set) var switching = false
    private var people: [LabView: Adjustment] = [:]
    private var globalSource = LabView.standing
    private var topSource = LabView.standing
    private var center = SIMD2<Float>.zero
    private var orbit: Float = 0
    private var elevation: Float = 0.73
    private var radius: Float = 2.65
    private var playerAnchor = SIMD3<Float>(0, BTTablePhysics.surfaceY + BallPhysics.radius, 0)
    private var bearing = Float.pi
    private var shotRunning = false
    private var shotTarget: SCNNode?
    private var watchedPocket = false
    private var shaftLift: Float = 0
    private var contactOffset = SIMD3<Float>.zero
    private var axis = SurfacePanAxisLock()
    private let lens = SCNNode()
    private var displayed: Pose?
    private var transition: (Pose, CFTimeInterval, Double)?
    private var aimBefore: (String?, Int)?
    private var lastShotMode: PositionPlayViewModel.AimMode?
    private var lastBounds = CGSize(width: 800, height: 380)
    var needsFrames: Bool { transition != nil || displayed == nil }
    var moving: Bool { host?.isPlaying == true || host?.breakRunner?.isBusy == true }
    func status(_ vm: PositionPlayViewModel) -> String {
        let name = vm.isBreakMode ? "开球" : vm.aimMode == .free ? "自由" : "进袋"
        return "\(name) · \(mode.rawValue)"
    }

    func readout(_ vm: PositionPlayViewModel, shots: Int) -> String {
        let aim = vm.currentPlayerAim.map { String(format: "%.4f", AngleSceneCalculator.bearingDeg(of: $0)) } ?? "nil"
        return "aim=\(aim) target=\(vm.selectedTargetKey ?? "nil") pocket=\(vm.selectedPocketIndex) shots=\(shots)"
    }
    private func startTransition(_ duration: Double) {
        if let displayed, !UIAccessibility.isReduceMotionEnabled {
            transition = (displayed, CACurrentMediaTime(), duration)
            if !switching { switching = true }
        }
        wake?()
    }
    func choose(_ requested: LabView) {
        guard !(switching && requested == mode) else { return }
        if requested == .top {
            if mode == .top { mode = topSource }
            else { topSource = mode; mode = .top }
        } else if mode == .top { return }
        else if requested == .global {
            if mode == .global { mode = globalSource }
            else {
                globalSource = mode
                center = .zero
                orbit = cos(bearing) > 0 ? Float.pi : 0
                elevation = 0.73
                // The near short rail is the limiting corner when looking along the long axis.
                // Fit once on entry. Subsequent orbit gestures keep the selected radius.
                let halfX = Float(host?.scene.cameraRig?.tableOuterHalfLength ?? CameraRig.defaultTableOuterHalfLength)
                let halfZ = Float(host?.scene.cameraRig?.tableOuterHalfWidth ?? CameraRig.defaultTableOuterHalfWidth)
                let tanV = tan(Float(56) * .pi / 360)
                let aspect = Float(lastBounds.width / max(1, lastBounds.height))
                let vertical = halfX * sin(elevation) / (0.78 * tanV)
                let horizontal = halfZ / (0.66 * tanV * max(1, aspect))
                radius = halfX * cos(elevation) + max(vertical, horizontal) + 0.10
                mode = .global
            }
        } else {
            guard host?.scene.cueBallNode != nil else { return }
            if mode == requested { people[requested] = Adjustment() }
            mode = requested
        }
        startTransition(0.36)
    }

    func adjustAim(_ degrees: Float) {
        guard !moving, mode != .top, degrees.isFinite, degrees != 0, let host else { return }
        let lookingAway = people.values.contains { abs($0.look) > 0.001 }
        for pose in [LabView.standing, .down] { people[pose, default: Adjustment()].look = 0 }
        if let runner = host.breakRunner { runner.nudgeAim(byDegrees: degrees) }
        else { host.nudgeFreeAim(byDegrees: degrees) }
        if lookingAway && mode != .global { startTransition(0.19) }
        wake?()
    }

    func pan(_ g: UIPanGestureRecognizer) {
        let delta = g.translation(in: g.view)
        g.setTranslation(.zero, in: g.view)
        if g.state == .began { axis = SurfacePanAxisLock() }
        guard [.changed, .began].contains(g.state), g.numberOfTouches == 1 else { return }
        drag(axis.filter(SIMD2(Float(delta.x), Float(delta.y))), width: Float(g.view?.bounds.width ?? 800))
    }
    func drag(_ xy: SIMD2<Float>, width: Float) {
        guard mode != .top, xy != .zero, let host else { return }
        let x = xy.x / max(1, width), y = xy.y / max(1, Float(lastBounds.height))
        if mode == .global {
            let candidate = orbit + x * 4.5
            let pitch = min(1.32, max(0.20, elevation - y * 1.9))
            if globalFits(angle: candidate, pitch: pitch, distance: radius, focus: center) {
                orbit = candidate
                elevation = pitch
            }
        } else if !moving {
            if x != 0 {
                if host.aimMode == .pocket && !host.isBreakMode {
                    people[mode, default: Adjustment()].look += x * 2.15
                } else {
                    adjustAim(x * (mode == .down ? 35 : 70))
                }
            }
            let base = people[mode, default: Adjustment()].tilt
            people[mode, default: Adjustment()].tilt = min(0.57, max(-0.60, base - y * 1.55))
        }
        wake?()
    }
    func pinch(_ g: UIPinchGestureRecognizer) {
        guard g.state == .changed else { return }
        let scale = max(0.01, Float(g.scale))
        g.scale = 1
        if mode == .global {
            let value = min(3.4, max(0.45, radius / scale))
            if globalFits(angle: orbit, pitch: elevation, distance: value, focus: center) { radius = value }
        } else if mode != .top {
            people[mode, default: Adjustment()].zoom = min(2.3, max(0.80, people[mode, default: Adjustment()].zoom * scale))
        }
        wake?()
    }
    func translate(_ g: UIPanGestureRecognizer) {
        let d = g.translation(in: g.view)
        g.setTranslation(.zero, in: g.view)
        guard mode == .global, g.state == .changed else { return }
        let right = SIMD2<Float>(sin(orbit), -cos(orbit)), forward = -SIMD2<Float>(cos(orbit), sin(orbit))
        let scale = radius * 0.8 / Float(max(1, lastBounds.height))
        let next = center - right * Float(d.x) * scale + forward * Float(d.y) * scale / max(0.3, sin(elevation))
        let limit = SIMD2(AngleSceneCalculator.innerLength, AngleSceneCalculator.innerWidth) * 0.5
        let bounded = simd_clamp(next, -limit, limit)
        if globalFits(angle: orbit, pitch: elevation, distance: radius, focus: bounded) { center = bounded }
        wake?()
    }
    private func globalFits(angle: Float, pitch: Float, distance: Float, focus: SIMD2<Float>) -> Bool {
        let eye = focus + SIMD2(cos(angle), sin(angle)) * cos(pitch) * distance
        let bounds = BakedTrainingRoom.cameraSafeHalfExtents
        return abs(eye.x) <= bounds.x && abs(eye.y) <= bounds.y &&
            BTTablePhysics.surfaceY + sin(pitch) * distance < BakedTrainingRoom.ceilingHeight - 0.12
    }

    private func targetPose(surface: Float) -> Pose {
        if mode == .top {
            // A near-vertical lens keeps the table's long axis horizontal and the eye inside the room.
            return Pose(SIMD3(0, surface + 2.61, 0.001), yaw: -.pi / 2, pitch: -.pi / 2 + 0.0003, fov: 45)
        }
        if mode == .global {
            let eye = SIMD3(center.x + radius * cos(elevation) * cos(orbit), surface + radius * sin(elevation),
                            center.y + radius * cos(elevation) * sin(orbit))
            return Pose(eye, yaw: orbit + .pi, pitch: -elevation, fov: 56)
        }
        let p = people[mode, default: Adjustment()]
        let low = mode == .down
        let setback: Float = low ? 0.43 : 1.32
        let rise: Float = low ? 0.15 + setback * tan(shaftLift) : 0.70
        let eye = playerAnchor + (low ? contactOffset : .zero) + SIMD3(-cos(bearing) * setback, rise, -sin(bearing) * setback)
        // Frame the standing address at its own working distance. Keeping the cue ball
        // 63% down the frame lets us compare the perspective to the reference footage.
        let baseFOV: Float = low ? 51 : 25
        let cueVerticalOffset = 2 * Float(0.63) - 1
        let standingPitch = -atan2(rise, setback) + atan(cueVerticalOffset * tan(baseFOV * .pi / 360))
        let pitch: Float = low ? -atan2(rise, 1.05) : standingPitch
        let fov = 2 * atan(tan(baseFOV * .pi / 360) / p.zoom) * 180 / .pi
        return Pose(eye, yaw: bearing + p.look, pitch: pitch + p.tilt, fov: fov)
    }

    func render(in view: SCNView) {
        guard let host, let original = host.scene.cameraNode?.camera else { return }
        lastBounds = view.bounds.size
        if lens.parent == nil {
            lens.camera = original.copy() as? SCNCamera
            lens.camera?.usesOrthographicProjection = false
            lens.camera?.projectionDirection = .vertical
            lens.camera?.zNear = 0.012
            host.scene.rootNode.addChildNode(lens)
        }
        if view.pointOfView !== lens { view.pointOfView = lens }
        let running = moving
        if !running, let cue = host.scene.cueBallNode, !cue.isHidden {
            playerAnchor = cue.simdWorldPosition
            if let aim = host.currentPlayerAim {
                bearing = atan2(aim.z, aim.x)
                let strike = CueStroke.strikePosition(cue: cue.position, aim: aim, spinX: host.breakRunner?.spinX ?? host.spinX, spinY: host.breakRunner?.spinY ?? host.spinY)
                contactOffset = SIMD3(strike.x - cue.position.x, strike.y - cue.position.y, strike.z - cue.position.z)
                if let stick = host.scene.cueStick, !stick.rootNode.isHidden {
                    shaftLift = min(CueStrikeAccess.maximumElevation, max(0, -stick.rootNode.eulerAngles.x))
                }
            }
            let changed = aimBefore?.0 != host.selectedTargetKey || aimBefore?.1 != host.selectedPocketIndex
            if changed || (lastShotMode == .free && host.aimMode == .pocket) || shotRunning {
                for pose in [LabView.standing, .down] { people[pose, default: Adjustment()].look = 0 }
                if shotRunning {
                    if mode == .global { globalSource = .standing }
                    else if mode == .top { topSource = topSource == .global ? .global : .standing; globalSource = .standing }
                    else { mode = .standing }
                }
                startTransition(0.28)
            }
            aimBefore = (host.selectedTargetKey, host.selectedPocketIndex)
            lastShotMode = host.aimMode
        }
        if running && !shotRunning {
            watchedPocket = false
            shotTarget = host.isBreakMode ? nil : aimBefore?.0.flatMap { host.scene.allBallNodes[$0] }
        }
        if running, !watchedPocket, let shotTarget, shotTarget.isHidden || shotTarget.presentation.opacity < 0.12 {
            watchedPocket = true
            if mode == .down {
                mode = .standing
                startTransition(0.32)
            }
        }
        shotRunning = running
        var pose = targetPose(surface: host.scene.surfaceY)
        if let (from, start, duration) = transition {
            let t = min(1, Float((CACurrentMediaTime() - start) / duration))
            pose = from.toward(pose, fraction: t * t * (3 - 2 * t))
            if t >= 1 { transition = nil; switching = false }
        }
        lens.simdPosition = pose.eye
        lens.simdOrientation = pose.rotation
        lens.camera?.fieldOfView = CGFloat(pose.fov)
        displayed = pose
    }
}

struct LabCameraButtons: View {
    @ObservedObject var camera: LabCamera
    var body: some View {
        VStack(spacing: 4) {
            ForEach(LabView.allCases, id: \.self) { view in
                Button { camera.choose(view) } label: {
                    Group {
                        switch view {
                        case .global: Image(systemName: "eye")
                        case .standing: BTPlayerViewGlyph(pose: .standing).frame(width: 28, height: 28)
                        case .down: BTPlayerViewGlyph(pose: .aiming).frame(width: 28, height: 28)
                        case .top: TemporaryTopDownFigure().frame(width: 28, height: 28)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(camera.mode == view ? HUDStyle.selectedBackground : HUDStyle.controlBackground, in: Circle())
                    .overlay(Circle().stroke(HUDStyle.hairline))
                }
                .buttonStyle(BTHUDPressStyle())
                .foregroundStyle(.white)
                .disabled(camera.mode == .top && view != .top)
                .accessibilityLabel(view.rawValue)
                .accessibilityAddTraits(camera.mode == view ? .isSelected : [])
            }
        }
    }
}
