import SwiftUI
import SceneKit

/// 跨 SwiftUI / SceneKit 的坐标桥接（走位编排器用）。
/// `AngleSceneView` 在 `makeUIView`/`updateUIView` 用捕获 `SCNView` 的闭包填充，
/// 供上层把球库拖拽落点反投影到台面（`unproject`），或把球节点世界坐标正投影到屏幕（`project`）。
/// 闭包接收/返回的均为 SCNView 本地坐标（点，原点在 SCNView 左上角）。
final class TableProjector {
    /// 屏幕点（SCNView 本地）→ 台面平面世界坐标。
    var unproject: ((CGPoint) -> SCNVector3?)?
    /// 世界坐标 → 屏幕点（SCNView 本地）。
    var project: ((SCNVector3) -> CGPoint?)?
}

/// UIViewRepresentable wrapper for SceneKit angle training.
/// Manages gesture recognition and CADisplayLink render loop.
/// Shares ball dragging, camera gestures and pocket tapping across table editors.
struct AngleSceneView: UIViewRepresentable {
    @ObservedObject private var roomPreferences = UserPreferences.shared
    /// Camera/touch interaction policy.
    /// - `cameraControl`: drag eligible balls; pan empty space/pinch to control the camera.
    /// - `tapsOnly`: only taps & ball drag are recognised; camera is locked.
    /// - `none`: all gestures disabled (locked-in quiz answer state).
    enum InteractionMode {
        case cameraControl
        case tapsOnly
        case none
    }

    let scene: AngleTrainingScene
    @Binding var cameraMode: AngleTrainingScene.CameraMode
    var interactionMode: InteractionMode = .cameraControl
    var locksCueBallScreenAnchor = false
    /// rotated 顶视下按视口自适应取景（统一各 2D 球桌页的球桌占比/居中，ADR-P11-08）。
    /// 仅 `tapsOnly`/`none` 的固定 2D 页开启；带捏合缩放的 `cameraControl` 页保持手动 scale。
    var autoFitsRotatedTable = false
    /// landscape 顶视按真实球桌外框与视口比例自适应，避免固定正交 scale 裁掉木框。
    var autoFitsLandscapeTable = false
    /// SCNView 背景色。默认黑（3D 角度页用）；2D 顶视球桌（详情页）传台呢绿，
    /// 让相机取景与相框比例不完全吻合时残留的极小边缘融入而非露出黑边。
    var backgroundColor: UIColor = .black
    var onPocketTapped: ((Int) -> Void)?

    var draggableBallNodes: [SCNNode] = []
    var onDragBegan: ((SCNNode) -> Void)?
    var onDragMoved: ((SCNNode, SCNVector3) -> Void)?
    var onDragEnded: ((SCNNode) -> Void)?
    /// 拖拽结束时附带结束屏幕坐标（SCNView 本地点），供「拖回球库即移除」判定。
    /// Released finger in SCNView-local points; excludes table-placement offset.
    var onDragEndedAt: ((SCNNode, CGPoint) -> Void)?

    /// 可点选的球（走位编排器点选目标球）。tap 命中其一即回调，优先于袋口判定。
    var selectableBallNodes: [SCNNode] = []
    var onBallTapped: ((SCNNode) -> Void)?

    /// 点击未命中球/袋口时，反投影到台面平面的世界坐标回调（走位编排器自由瞄准用）。
    var onTableTapped: ((SCNVector3) -> Void)?

    /// 自由瞄准拖动（G13 语义重做，问题集合 v5）：pan 起手**未命中球**即进入「瞄准调整」分支
    /// （球命中优先移球）。**第一落点只选中当前瞄准线、不改变方向**；随后每帧回调一个相对角位移
    /// （度，屏幕顺时针为正），由消费方按 `rotatedAim` 做增量旋转（绕母球公转模型，见
    /// `AngleSceneCalculator.aimNudgeDegrees`）。取代旧的「逐帧回调手指台面点、指哪打哪」绝对语义。
    var onAimNudged: ((Float) -> Void)?
    /// Reports the actual table-aim gesture lifetime, including cancellation.
    var onAimDragActiveChanged: ((Bool) -> Void)?
    /// 瞄准调整结束（可选，用于收尾震动/求解调度）。
    var onAimDragEnded: (() -> Void)?

    /// 坐标桥接（可选）。传入后由本视图填充 unproject/project 闭包。
    var projector: TableProjector?
    /// nil preserves existing consumers; explicit activity enables bounded idle work.
    var contentIsAnimating: Bool? = nil

    static func requestedFPS(maximum: Int, selected: RenderFrameRate = .fps60, active: Bool, thermal: ProcessInfo.ThermalState, lowPower: Bool) -> Int {
        let ceiling = thermal == .critical ? 30 : ((thermal == .serious || lowPower) ? 60 : maximum)
        return max(1, min(maximum, min(ceiling, active ? selected.rawValue : min(selected.rawValue, 30))))
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = scene
        scene.applyTableStyle(roomPreferences.tableStyle, showsSights: roomPreferences.showsTableSights)
        scene.applyClothColor(roomPreferences.clothColor)
        context.coordinator.frameDelegate.contact = scene.contactOcclusion
        scnView.delegate = context.coordinator.frameDelegate
        scene.closeupViewport = scnView
        if let cam = scene.cameraNode {
            scnView.pointOfView = cam
        }
        scnView.allowsCameraControl = false
        scnView.antialiasingMode = .multisampling4X
        scnView.preferredFramesPerSecond = min(UIScreen.main.maximumFramesPerSecond, UserPreferences.shared.renderFrameRate.rawValue)
        scnView.isPlaying = true
        scnView.backgroundColor = backgroundColor

        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.maximumNumberOfTouches = 1
        // Arbitration against ancestor UIScrollViews (paging TabView / vertical ScrollView),
        // see `Coordinator.gestureRecognizer(_:shouldBeRequiredToFailBy:)`.
        panGesture.delegate = context.coordinator
        context.coordinator.panGesture = panGesture
        scnView.addGestureRecognizer(panGesture)

        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        scnView.addGestureRecognizer(pinchGesture)

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)

        // 2D zoom/pan on every table page (DR-296): two-finger pan never competes with the
        // single-finger ball drag / aim nudge; double tap resets to the whole-table fit.
        // Single taps are not delayed (`require(toFail:)` deliberately omitted — pocket/ball
        // taps are idempotent selections, so the extra fire on a double tap is harmless).
        let twoFingerPan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTwoFingerPan(_:)))
        twoFingerPan.minimumNumberOfTouches = 2
        twoFingerPan.maximumNumberOfTouches = 2
        scnView.addGestureRecognizer(twoFingerPan)
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scnView.addGestureRecognizer(doubleTap)

        context.coordinator.scnView = scnView
        context.coordinator.installFPSReadout(in: scnView)
        context.coordinator.onPocketTapped = onPocketTapped
        context.coordinator.updatePocketAccessibility()
        context.coordinator.contentIsAnimating = contentIsAnimating
        context.coordinator.startRenderLoop()
        context.coordinator.requestInteractiveFrames()
        bindProjector(to: scnView)

        // 4x8 台面网格（条 16）：交互页进场按全局偏好显隐；
        // 离线渲染（缩略图/视频导出）不走本视图，不受影响。
        scene.setTableGridVisible(UserPreferences.shared.showTableGrid)

        return scnView
    }

    /// 用捕获的 `SCNView` 填充坐标桥接闭包（台面平面 = surfaceY + 球半径）。
    private func bindProjector(to scnView: SCNView) {
        guard let projector else { return }
        projector.unproject = { [weak scnView, weak scene] point in
            guard let scnView, let scene else { return nil }
            let nearPoint = scnView.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 0))
            let farPoint = scnView.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 1))
            let dir = SCNVector3(farPoint.x - nearPoint.x, farPoint.y - nearPoint.y, farPoint.z - nearPoint.z)
            guard abs(dir.y) > 1e-6 else { return nil }
            let y = scene.surfaceY + AngleSceneCalculator.ballRadius
            let t = (y - nearPoint.y) / dir.y
            guard t > 0 else { return nil }
            return SCNVector3(nearPoint.x + dir.x * t, y, nearPoint.z + dir.z * t)
        }
        projector.project = { [weak scnView] world in
            guard let scnView else { return nil }
            let p = scnView.projectPoint(world)
            return CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
        }
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        scene.applyTableStyle(roomPreferences.tableStyle, showsSights: roomPreferences.showsTableSights)
        scene.applyClothColor(roomPreferences.clothColor)
        scene.applyBallStickerStyle(roomPreferences.ballStickerStyle)
        scene.cueStick?.applyStyle(roomPreferences.cueStyle)
        if scene.rootNode.childNode(withName: "reference_room", recursively: false) != nil {
            scene.installReferenceRoom(style: roomPreferences.roomStyle)
        }
        if uiView.pointOfView !== scene.cameraNode, let cam = scene.cameraNode {
            uiView.pointOfView = cam
        }
        if uiView.backgroundColor != backgroundColor {
            uiView.backgroundColor = backgroundColor
        }
        context.coordinator.contentIsAnimating = contentIsAnimating
        context.coordinator.requestInteractiveFrames()
        context.coordinator.cameraMode = cameraMode
        context.coordinator.interactionMode = interactionMode
        context.coordinator.locksCueBallScreenAnchor = locksCueBallScreenAnchor
        context.coordinator.autoFitsRotatedTable = autoFitsRotatedTable
        context.coordinator.autoFitsLandscapeTable = autoFitsLandscapeTable
        context.coordinator.onPocketTapped = onPocketTapped
        context.coordinator.draggableBallNodes = draggableBallNodes
        context.coordinator.onDragBegan = onDragBegan
        context.coordinator.onDragMoved = onDragMoved
        context.coordinator.onDragEnded = onDragEnded
        context.coordinator.onDragEndedAt = onDragEndedAt
        context.coordinator.selectableBallNodes = selectableBallNodes
        context.coordinator.onBallTapped = onBallTapped
        context.coordinator.onTableTapped = onTableTapped
        context.coordinator.onAimNudged = onAimNudged
        context.coordinator.onAimDragActiveChanged = onAimDragActiveChanged
        context.coordinator.onAimDragEnded = onAimDragEnded
        context.coordinator.updatePocketAccessibility()
        if let projector, projector.unproject == nil {
            bindProjector(to: uiView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(scene: scene, cameraMode: cameraMode, interactionMode: interactionMode)
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        coordinator.endBallDrag()
        coordinator.endAimDrag()
        coordinator.stopRenderLoop()
        uiView.isPlaying = false
        uiView.pointOfView = nil
        uiView.scene = nil
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject {
        let scene: AngleTrainingScene
        var cameraMode: AngleTrainingScene.CameraMode
        var interactionMode: InteractionMode
        var locksCueBallScreenAnchor = false
        var autoFitsRotatedTable = false
        var autoFitsLandscapeTable = false
        var onPocketTapped: ((Int) -> Void)?
        weak var scnView: SCNView?
        /// Single-finger pan installed in `makeUIView`; identity check inside the delegate callbacks.
        weak var panGesture: UIPanGestureRecognizer?
        private var displayLink: CADisplayLink?
        private var lastTimestamp: CFTimeInterval = 0
        var contentIsAnimating: Bool?
        private var needsContinuousUpdates = true
        private var interactiveUntil: CFTimeInterval = 0
        let frameDelegate = FrameDelegate()
        private var fpsHost: UIHostingController<FPSReadout>?
        private let diagramLabels = DiagramLabelOverlay()
        private var fpsText = "— FPS"
        private var fpsSampleTime = CACurrentMediaTime()

        func installFPSReadout(in view: SCNView) {
            let host = UIHostingController(rootView: FPSReadout(text: "— FPS"))
            host.sizingOptions = .intrinsicContentSize
            host.view.backgroundColor = .clear
            host.view.isUserInteractionEnabled = false
            host.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(host.view)
            NSLayoutConstraint.activate([
                host.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Spacing.xs),
                host.view.centerXAnchor.constraint(equalTo: view.centerXAnchor)
            ])
            fpsHost = host
            updateFPSReadout()
        }

        private func updateFPSReadout() {
            fpsHost?.view.isHidden = cameraMode != .perspective3D
            let now = CACurrentMediaTime()
            guard now - fpsSampleTime >= 1 else { return }
            let count = frameDelegate.takeFrameCount()
            let fps = Int((Double(count) / (now - fpsSampleTime)).rounded())
            fpsSampleTime = now
            guard cameraMode == .perspective3D else { return }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-v63.cameraDiagnostics"),
               let scnView, let rig = scene.cameraRig, let host = fpsHost {
                let center = scnView.projectPoint(SCNVector3(0, scene.surfaceY + BallPhysics.radius, 0))
                let corners = [-Float(rig.tableOuterHalfLength), Float(rig.tableOuterHalfLength)].flatMap { x in
                    [-Float(rig.tableOuterHalfWidth), Float(rig.tableOuterHalfWidth)].map { z in
                        scnView.projectPoint(SCNVector3(x, scene.surfaceY, z))
                    }
                }
                host.view.isAccessibilityElement = true
                host.view.accessibilityIdentifier = "v63.cameraDiagnostics"
                host.view.accessibilityValue = "viewport=\(scnView.bounds.size) rigViewport=\(rig.viewportSize) center=\(center) corners=\(corners) pivot=\(rig.targetPivot) yaw=\(rig.targetYaw) distance=\(rig.orbitDistance)"
            }
            #endif
            let next = !needsContinuousUpdates ? "FPS · 静止" : "\(fps) FPS"
            guard fpsText != next else { return }
            fpsText = next
            fpsHost?.rootView = FPSReadout(text: next)
            updatePocketAccessibility()
        }

        private var lastSevereThermalTime: CFTimeInterval = -.infinity

        func requestInteractiveFrames() {
            interactiveUntil = CACurrentMediaTime() + 0.5
            updateFramePacing()
        }

        private func updateFramePacing() {
            guard let scnView, let displayLink else { return }
            let gestureActive = scnView.gestureRecognizers?.contains { $0.state == .began || $0.state == .changed } ?? false
            var active = (contentIsAnimating ?? true) || gestureActive || scene.isCameraModeTransitioning
                || (scene.cameraRig?.isTransitioning ?? false)
                || (cameraMode == .perspective3D && (scene.cameraRig?.hasPendingDamping ?? false))
                || CACurrentMediaTime() < interactiveUntil
            // Preserve SceneKit cue strokes, fades and selection pulses even when
            // the view model has no physics playback in progress.
            if !active {
                active = scene.rootNode.hasActions || !scene.rootNode.animationKeys.isEmpty
                scene.rootNode.enumerateChildNodes { node, stop in
                    if node.hasActions || !node.animationKeys.isEmpty { active = true; stop.pointee = true }
                }
            }
            needsContinuousUpdates = active
            if scnView.isPlaying != active { scnView.isPlaying = active }
            if scnView.rendersContinuously { scnView.rendersContinuously = false }
            let maximum = scnView.window?.screen.maximumFramesPerSecond ?? UIScreen.main.maximumFramesPerSecond
            let thermal = ProcessInfo.processInfo.thermalState
            let now = CACurrentMediaTime()
            if thermal == .serious || thermal == .critical { lastSevereThermalTime = now }
            let requested = AngleSceneView.requestedFPS(maximum: maximum, selected: UserPreferences.shared.renderFrameRate, active: active,
                thermal: thermal, lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled)
            // Avoid bouncing straight back to 120 as thermal state crosses a boundary.
            let fps = min(requested, now - lastSevereThermalTime < 30 ? 60 : maximum)
            if scnView.preferredFramesPerSecond != fps { scnView.preferredFramesPerSecond = fps }
            if displayLink.preferredFrameRateRange.preferred != Float(fps) {
                displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: Float(fps), maximum: Float(fps), preferred: Float(fps))
            }
        }
        var gesturesEnabled = true

        var draggableBallNodes: [SCNNode] = []
        var onDragBegan: ((SCNNode) -> Void)?
        var onDragMoved: ((SCNNode, SCNVector3) -> Void)?
        var onDragEnded: ((SCNNode) -> Void)?
        var onDragEndedAt: ((SCNNode, CGPoint) -> Void)?
        var selectableBallNodes: [SCNNode] = []
        var onBallTapped: ((SCNNode) -> Void)?
        var onTableTapped: ((SCNVector3) -> Void)?
        var onAimNudged: ((Float) -> Void)?
        var onAimDragActiveChanged: ((Bool) -> Void)?
        var onAimDragEnded: (() -> Void)?
        private var draggedNode: SCNNode?
        private weak var selectedDragBall: SCNNode?
        /// 本次 pan 是否在调整瞄准（起手未命中球时进入；球命中优先移球）。
        private var isAimFollowing = false
        /// 瞄准调整的旋转轴心 = 母球屏幕投影（.began 捕获一次，2D 页相机不动故恒定）。
        /// nil = 起手时母球不可投影（此 pan 内不产生转向，仅拦截相机平移）。
        private var aimPivotScreen: CGPoint?
        /// 上一帧手指屏幕点，用于逐帧求相对角位移（G13）。
        private var lastAimTouch: CGPoint = .zero

        /// Dominant axis lock for 3D camera-pan gestures. Once decided
        /// (when cumulative motion crosses `panAxisLockThreshold`), the
        /// other axis's deltas are dropped for the rest of the gesture.
        /// Eliminates "vertical drag also rotates yaw" cross-axis bleed.
        private enum PanAxis { case horizontal, vertical }
        private var panDominantAxis: PanAxis?
        private var panCumX: CGFloat = 0
        private var panCumY: CGFloat = 0
        private let panAxisLockThreshold: CGFloat = 12

        /// Ball-drag finger-offset state. The ball trails the finger by a fixed
        /// gap so the finger never occludes the ball during precise placement:
        /// - After grab, the first `dragDeadZone` points of motion move the ball
        ///   *not at all* (dead zone). Crossing the dead zone is a one-time gate:
        ///   at that instant we lock a constant trailing offset and from then on
        ///   the ball tracks the finger 1:1 (so reversing direction keeps the
        ///   gap instead of snapping the ball back toward the grab point).
        /// - `dragGrabOffset`: ball-center→touch delta captured at grab, so the
        ///   ball doesn't jump under the finger the instant it is picked up.
        private var dragGrabOffset: CGSize = .zero
        private var dragStartLocation: CGPoint = .zero
        private var dragBrokeDeadZone = false
        private var dragLockedOffset: CGSize = .zero
        private let dragDeadZone: CGFloat = 52

        /// Effective screen sample point for the current finger location.
        /// Dead zone is a one-time gate: before breaking it the ball stays put;
        /// at the moment of breaking we lock `dragLockedOffset` (= start − finger,
        /// magnitude ≈ deadZone, continuous with no jump) and afterwards the ball
        /// simply follows the finger by that fixed offset in every direction.
        private func dragSamplePoint(for location: CGPoint) -> CGPoint {
            if !dragBrokeDeadZone {
                let dx = location.x - dragStartLocation.x
                let dy = location.y - dragStartLocation.y
                if hypot(dx, dy) <= dragDeadZone {
                    return CGPoint(x: dragStartLocation.x + dragGrabOffset.width,
                                   y: dragStartLocation.y + dragGrabOffset.height)
                }
                dragBrokeDeadZone = true
                dragLockedOffset = CGSize(width: dragStartLocation.x - location.x,
                                          height: dragStartLocation.y - location.y)
            }
            return CGPoint(x: location.x + dragLockedOffset.width + dragGrabOffset.width,
                           y: location.y + dragLockedOffset.height + dragGrabOffset.height)
        }

        init(scene: AngleTrainingScene, cameraMode: AngleTrainingScene.CameraMode, interactionMode: InteractionMode) {
            self.scene = scene
            self.cameraMode = cameraMode
            self.interactionMode = interactionMode
        }

        deinit {
            displayLink?.invalidate()
        }

        func startRenderLoop() {
            displayLink?.invalidate()
            let link = CADisplayLink(target: self, selector: #selector(renderUpdate))
            let fps = Float(min(UIScreen.main.maximumFramesPerSecond, UserPreferences.shared.renderFrameRate.rawValue))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: fps, maximum: fps, preferred: fps)
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        func stopRenderLoop() {
            displayLink?.invalidate()
            displayLink = nil
            lastTimestamp = 0
        }

        @objc private func renderUpdate(_ link: CADisplayLink) {
            defer {
                if let scnView { diagramLabels.update(scene: scene, in: scnView) }
                #if DEBUG
                if dragProbeEnabled { updatePocketAccessibility() }
                #endif
            }
            if let scnView { scene.cameraRig?.viewportSize = scnView.bounds.size }
            updateFramePacing()
            let dt: Float
            if lastTimestamp == 0 {
                dt = Float(max(0, link.targetTimestamp - link.timestamp))
            } else {
                dt = Float(link.timestamp - lastTimestamp)
            }
            lastTimestamp = link.timestamp

            // Ensure SCNView's pointOfView tracks the scene's camera node.
            // The camera node is created in setupScene() which runs in .onAppear,
            // AFTER makeUIView. Without this, pointOfView stays nil → black screen.
            if let scnView, scnView.pointOfView !== scene.cameraNode, let cam = scene.cameraNode {
                scnView.pointOfView = cam
            }
            frameDelegate.contact = scene.contactOcclusion
            if let scnView, scnView.delegate !== frameDelegate { scnView.delegate = frameDelegate }
            updateFPSReadout()

            // A stable table needs no repeated camera writes. Scene graph changes
            // still invalidate SCNView; gestures and SwiftUI updates wake it above.
            if contentIsAnimating != nil && !needsContinuousUpdates {
                lastTimestamp = 0
                return
            }

            guard !scene.isCameraModeTransitioning, draggedNode == nil else { return }

            switch cameraMode {
            case .topDown2D:
                if autoFitsLandscapeTable, let scnView {
                    scene.cameraRig?.fitLandscapeTable(viewSize: scnView.bounds.size)
                }
                scene.cameraRig?.applyTopDown2D()
            case .topDown2DRotated:
                if autoFitsRotatedTable, let scnView {
                    scene.cameraRig?.fitRotatedTable(viewSize: scnView.bounds.size)
                }
                scene.cameraRig?.applyTopDown2DRotated()
            case .perspective3D:
                scene.cameraRig?.update(deltaTime: dt)
                // Smooth transitions and manual observation own the pivot.
                // A competing per-frame translatePivot would fight their pose
                // or drag a chosen ball/pocket focus back toward the cue ball.
                if locksCueBallScreenAnchor,
                   scene.cameraRig?.allowsCueScreenAnchor == true,
                   let scnView,
                   let cueBall = scene.cueBallNode {
                    // Anchor cue ball in the upper half of the visible area
                    // so the bottom-half input HUD never overlaps it
                    // (fixes "table jammed under modal" in 3D瞄准页面输入后.PNG).
                    scene.lockCueBallScreenAnchor(
                        in: scnView,
                        cueBallWorld: scene.visualCenter(of: cueBall),
                        anchorNormalized: CGPoint(x: 0.5, y: 0.42)
                    )
                }
            }
        }

        // MARK: - Hit Testing for Balls

        func hitTestBall(at location: CGPoint) -> SCNNode? {
            guard let scnView else { return nil }
            let candidates = draggableBallNodes.filter { !$0.isHidden && $0.parent != nil }
            guard !candidates.isEmpty else { return nil }

            func ballAncestor(of node: SCNNode) -> SCNNode? {
                var current: SCNNode? = node
                while let node = current {
                    if candidates.contains(node) { return node }
                    current = node.parent
                }
                return nil
            }
            // Use the visible surface, including nested USDZ ball meshes.
            if let hit = scnView.hitTest(location, options: [
                .searchMode: SCNHitTestSearchMode.closest.rawValue
            ]).first, let ball = ballAncestor(of: hit.node) {
                return ball
            }

            // Preserve the existing finger allowance, but choose the nearest
            // visible centre instead of depending on the caller's array order.
            let hitRadius: CGFloat = 48
            var nearest: SCNNode?
            var nearestDistance = hitRadius
            let ordered = candidates.sorted { $0 === selectedDragBall && $1 !== selectedDragBall }
            for ball in ordered {
                let projected = scnView.projectPoint(scene.visualCenter(of: ball))
                guard projected.z >= 0, projected.z <= 1 else { continue }
                let point = CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
                guard scnView.bounds.contains(point) else { continue }
                let distance = hypot(location.x - point.x, location.y - point.y)
                guard distance < nearestDistance else { continue }
                // A triangle ray may miss a mesh seam even at the projected
                // centre. Reject an actual foreground hit, not an empty result.
                if cameraMode == .perspective3D,
                   let front = scnView.hitTest(point, options: [
                       .searchMode: SCNHitTestSearchMode.closest.rawValue
                   ]).first, ballAncestor(of: front.node) !== ball {
                    continue
                }
                if ball === selectedDragBall { return ball }
                nearest = ball
                nearestDistance = distance
            }
            return nearest
        }

        /// 母球视觉中心的屏幕投影（G13 瞄准调整的旋转轴心）。母球缺失/隐藏时返回 nil。
        private func cueBallScreenPoint() -> CGPoint? {
            guard let scnView, let cue = scene.cueBallNode, !cue.isHidden else { return nil }
            let p = scnView.projectPoint(scene.visualCenter(of: cue))
            return CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
        }

        /// Project a screen point onto the table surface plane (y = planeY).
        private func unprojectToTablePlane(screenPoint: CGPoint, in view: SCNView, planeY: Float) -> SCNVector3? {
            let nearPoint = view.unprojectPoint(SCNVector3(Float(screenPoint.x), Float(screenPoint.y), 0))
            let farPoint = view.unprojectPoint(SCNVector3(Float(screenPoint.x), Float(screenPoint.y), 1))
            let dir = SCNVector3(farPoint.x - nearPoint.x, farPoint.y - nearPoint.y, farPoint.z - nearPoint.z)
            guard abs(dir.y) > 1e-6 else { return nil }
            let t = (planeY - nearPoint.y) / dir.y
            guard t > 0 else { return nil }
            return SCNVector3(nearPoint.x + dir.x * t, planeY, nearPoint.z + dir.z * t)
        }

        // MARK: - Gestures

        func endAimDrag() {
            guard isAimFollowing else { return }
            isAimFollowing = false
            panDominantAxis = nil
            panCumX = 0
            panCumY = 0
            aimPivotScreen = nil
            onAimDragActiveChanged?(false)
            onAimDragEnded?()
        }

        func endBallDrag(at location: CGPoint? = nil) {
            guard let ball = draggedNode else { return }
            draggedNode = nil
            dragGrabOffset = .zero
            dragStartLocation = .zero
            dragBrokeDeadZone = false
            dragLockedOffset = .zero
            onDragEnded?(ball)
            if let location { onDragEndedAt?(ball, location) }
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            #if DEBUG
            if dragProbeEnabled { dragProbePanCount += 1 }
            #endif
            requestInteractiveFrames()
            if [.ended, .cancelled, .failed].contains(gesture.state), isAimFollowing {
                endAimDrag()
                return
            }
            if [.ended, .cancelled, .failed].contains(gesture.state), draggedNode != nil {
                endBallDrag(at: gesture.state == .ended ? gesture.location(in: scnView) : nil)
                return
            }
            guard gesturesEnabled, interactionMode != .none, let scnView else { return }

            switch gesture.state {
            case .began:
                panDominantAxis = nil
                panCumX = 0
                panCumY = 0
                let current = gesture.location(in: scnView)
                let translation = gesture.translation(in: scnView)
                let location = CGPoint(x: current.x - translation.x, y: current.y - translation.y)
                if let ball = hitTestBall(at: location) {
                    #if DEBUG
                    if dragProbeEnabled { dragProbeGrabCount += 1 }
                    #endif
                    selectedDragBall = ball
                    draggedNode = ball
                    dragStartLocation = location
                    dragBrokeDeadZone = false
                    dragLockedOffset = .zero
                    let projected = scnView.projectPoint(scene.visualCenter(of: ball))
                    dragGrabOffset = CGSize(width: CGFloat(projected.x) - location.x,
                                            height: CGFloat(projected.y) - location.y)
                    onDragBegan?(ball)
                    return
                }
                draggedNode = nil
                selectedDragBall = nil
                // 瞄准调整（G13）：起手未命中球即进入。**第一落点只选中瞄准线、不改变方向**，
                // 故此处不回调；轴心 = 母球屏幕投影，记下起手点，后续 .changed 逐帧求相对角位移。
                if onAimNudged != nil {
                    isAimFollowing = true
                    onAimDragActiveChanged?(true)
                    aimPivotScreen = cueBallScreenPoint()
                    lastAimTouch = location
                    return
                }

            case .changed:
                if isAimFollowing {
                    let cur = gesture.location(in: scnView)
                    if let pivot = aimPivotScreen {
                        let deg = AngleSceneCalculator.aimNudgeDegrees(cueScreen: pivot, from: lastAimTouch, to: cur)
                        if deg != 0 { onAimNudged?(deg) }
                    }
                    lastAimTouch = cur
                    return
                }
                if let ball = draggedNode {
                    let sample = dragSamplePoint(for: gesture.location(in: scnView))
                    let planeY = scene.surfaceY + AngleSceneCalculator.ballRadius
                    guard let worldPos = unprojectToTablePlane(screenPoint: sample, in: scnView, planeY: planeY) else { return }
                    #if DEBUG
                    if dragProbeEnabled { dragProbeMoveCount += 1 }
                    #endif
                    onDragMoved?(ball, worldPos)
                    return
                }

            case .ended, .cancelled:
                panDominantAxis = nil
                panCumX = 0
                panCumY = 0


            default:
                break
            }

            guard draggedNode == nil, interactionMode == .cameraControl, let rig = scene.cameraRig else { return }
            let translation = gesture.translation(in: gesture.view)

            switch cameraMode {
            case .perspective3D:
                // Track cumulative motion to decide a dominant axis once
                // the user has made a clear directional intent (>12px).
                // After the lock, deltas on the perpendicular axis are
                // dropped — eliminating the "vertical drag induces yaw"
                // and "horizontal drag induces zoom" cross-axis bleed.
                panCumX += abs(translation.x)
                panCumY += abs(translation.y)
                if panDominantAxis == nil,
                   panCumX + panCumY >= panAxisLockThreshold {
                    panDominantAxis = panCumX > panCumY ? .horizontal : .vertical
                }

                let dx: Float = panDominantAxis == .horizontal ? Float(translation.x) : 0
                let dy: Float = panDominantAxis == .vertical ? Float(translation.y) : 0
                rig.handleHorizontalSwipe(delta: dx)
                rig.handleVerticalSwipe(delta: dy)
            case .topDown2D, .topDown2DRotated:
                rig.applyTopDownScreenPan(dx: translation.x, dy: translation.y,
                                          viewSize: scnView.bounds.size,
                                          rotated: cameraMode == .topDown2DRotated)
            }
            gesture.setTranslation(.zero, in: gesture.view)
        }

        /// Two-finger pan: 2D camera pan on every table page (DR-296), including pages whose
        /// single finger is reserved for ball drag / aim nudge (`tapsOnly`). No-op at 1× (clamped).
        @objc func handleTwoFingerPan(_ gesture: UIPanGestureRecognizer) {
            requestInteractiveFrames()
            guard gesturesEnabled, interactionMode != .none, draggedNode == nil, !isAimFollowing,
                  cameraMode != .perspective3D, let scnView, let rig = scene.cameraRig else { return }
            let translation = gesture.translation(in: scnView)
            rig.applyTopDownScreenPan(dx: translation.x, dy: translation.y,
                                      viewSize: scnView.bounds.size,
                                      rotated: cameraMode == .topDown2DRotated)
            gesture.setTranslation(.zero, in: scnView)
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            requestInteractiveFrames()
            guard gesturesEnabled, interactionMode != .none,
                  draggedNode == nil, let scnView, let rig = scene.cameraRig else { return }

            switch cameraMode {
            case .perspective3D:
                guard interactionMode == .cameraControl else { return }
                rig.handlePinch(scale: Float(gesture.scale))
            case .topDown2D, .topDown2DRotated:
                // 2D zoom is available on every table page; zoom about the pinch centre.
                let centre = gesture.location(in: scnView)
                let focal = CGPoint(x: centre.x - scnView.bounds.midX, y: centre.y - scnView.bounds.midY)
                rig.applyTopDownZoom(factor: Float(gesture.scale), focalOffset: focal,
                                     viewSize: scnView.bounds.size,
                                     rotated: cameraMode == .topDown2DRotated)
            }
            gesture.scale = 1.0
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            requestInteractiveFrames()
            guard gesturesEnabled, interactionMode != .none, cameraMode != .perspective3D,
                  let rig = scene.cameraRig else { return }
            rig.resetTopDownZoom()
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            requestInteractiveFrames()
            guard let scnView else { return }
            handleTap(at: gesture.location(in: scnView))
        }

        func handleTap(at location: CGPoint) {
            guard gesturesEnabled, interactionMode != .none, let scnView else { return }
            selectedDragBall = hitTestBall(at: location)

            // Position-Play: tap a ball to select it as the target (takes priority over pockets,
            // since balls sit on the interior while pockets sit at the rails).
            if let onBallTapped, !selectableBallNodes.isEmpty {
                let tapRadius: CGFloat = 40
                var best: SCNNode?
                var bestDist: CGFloat = .greatestFiniteMagnitude
                for ball in selectableBallNodes {
                    let projected = scnView.projectPoint(ball.position)
                    let screenPos = CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
                    let dist = hypot(location.x - screenPos.x, location.y - screenPos.y)
                    if dist < tapRadius, dist < bestDist { bestDist = dist; best = ball }
                }
                if let best { onBallTapped(best); return }
            }

            // Hit any visible leather variant via its pocket parent; keep ball priority.
            let hitResults = scnView.hitTest(location, options: [
                .searchMode: SCNHitTestSearchMode.closest.rawValue
            ])
            for hit in hitResults {
                if onPocketTapped != nil, let index = PocketLeatherMarker.index(of: hit.node) {
                    onPocketTapped?(index)
                    return
                }
            }

            // Fallback: project pocket marker positions to screen and pick the nearest within radius.
            let pocketPositions = AngleSceneCalculator.pocketMarkerPositions(surfaceY: scene.surfaceY)
            let tapRadius: CGFloat = 44
            var bestIndex: Int?
            var bestDist: CGFloat = .greatestFiniteMagnitude
            for (index, pos) in pocketPositions.enumerated() {
                let projected = scnView.projectPoint(pos)
                guard projected.z >= 0, projected.z <= 1,
                      projected.x >= 0, projected.x <= Float(scnView.bounds.width),
                      projected.y >= 0, projected.y <= Float(scnView.bounds.height) else { continue }
                let screenPos = CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
                // A projected point may be inside the viewport yet hidden by the
                // near rail in 3D. Do not select it through foreground geometry.
                if let camera = scnView.pointOfView,
                   let front = scnView.hitTest(screenPos, options: [.searchMode: SCNHitTestSearchMode.closest.rawValue]).first {
                    let hitDepth = camera.convertPosition(front.worldCoordinates, from: nil).z
                    let pocketDepth = camera.convertPosition(pos, from: nil).z
                    if hitDepth > pocketDepth + 0.015 { continue }
                }
                let dist = hypot(location.x - screenPos.x, location.y - screenPos.y)
                if dist < tapRadius, dist < bestDist {
                    bestDist = dist
                    bestIndex = index
                }
            }
            if let bestIndex, let onPocketTapped {
                onPocketTapped(bestIndex)
                return
            }

            // 未命中球/袋口：反投影到台面平面回调（自由瞄准设定方向）。
            if let onTableTapped {
                let planeY = scene.surfaceY + AngleSceneCalculator.ballRadius
                if let world = unprojectToTablePlane(screenPoint: location, in: scnView, planeY: planeY) {
                    onTableTapped(world)
                }
            }
        }

        #if DEBUG
        private var dragProbePanCount = 0
        private var dragProbeGrabCount = 0
        private var dragProbeMoveCount = 0
        private let dragProbeEnabled = ProcessInfo.processInfo.arguments.contains("-3dDrag.probe")
        private func dragProbeValue(in view: SCNView) -> String {
            let balls: [[String: Any]] = scene.allBallNodes.sorted { $0.key < $1.key }.compactMap { key, node in
                guard !node.isHidden else { return nil }
                let p = view.projectPoint(scene.visualCenter(of: node))
                return ["key": key, "screen": [p.x, p.y, p.z],
                        "world": [node.position.x, node.position.y, node.position.z],
                        "draggable": draggableBallNodes.contains(node)]
            }
            let transform = view.pointOfView?.worldTransform ?? SCNMatrix4Identity
            let data: [String: Any] = ["panCount": dragProbePanCount, "grabCount": dragProbeGrabCount, "moveCount": dragProbeMoveCount, "balls": balls, "camera": [transform.m11, transform.m12, transform.m13,
                transform.m21, transform.m22, transform.m23, transform.m31, transform.m32, transform.m33,
                transform.m41, transform.m42, transform.m43]]
            do {
                return String(decoding: try JSONSerialization.data(withJSONObject: data), as: UTF8.self)
            } catch {
                assertionFailure("Ball drag probe could not encode scene: \(error)")
                return "Ball drag probe encoding failed"
            }
        }
        #endif

        func updatePocketAccessibility() {
            guard let scnView else { return }
            scnView.isAccessibilityElement = true
            scnView.accessibilityIdentifier = "table.scene"
            scnView.accessibilityLabel = "球桌"
            scnView.accessibilityValue = scene.pocketSelectionDescription
                + "，台呢颜色：" + scene.installedClothColor.displayName
                + "，球桌风格：" + scene.installedTableStyle.displayName
                + "，颗星参考点：" + (scene.showsTableSights ? "显示" : "隐藏")
                + (cameraMode == .perspective3D ? "，渲染帧率 " + fpsText : "")
            #if DEBUG
            if dragProbeEnabled { scnView.accessibilityValue = dragProbeValue(in: scnView) }
            #endif
            scnView.accessibilityCustomActions = onPocketTapped == nil || interactionMode == .none ? [] : (0..<6).map { index in
                UIAccessibilityCustomAction(name: "选择\(index + 1)号\(index < 4 ? "角袋" : "中袋")") { [weak self] _ in
                    guard let self, self.gesturesEnabled, self.interactionMode != .none,
                          let select = self.onPocketTapped else { return false }
                    select(index)
                    self.updatePocketAccessibility()
                    return true
                }
            }
        }

    }
}

// MARK: - Pan arbitration against ancestor scroll views

extension AngleSceneView.Coordinator: UIGestureRecognizerDelegate {
    /// Whether the single-finger pan has any work to do for the current mode. When it does not
    /// (`interactionMode == .none`, e.g. the 2D 球台示意 inside the training pager), the pan must
    /// fail immediately so ancestor scroll views (paging `TabView`, vertical `ScrollView`) get the
    /// swipe instead of a dead recognizer swallowing it.
    static func panClaimsSingleFingerTouch(gesturesEnabled: Bool,
                                                      interactionMode: AngleSceneView.InteractionMode) -> Bool {
        gesturesEnabled && interactionMode != .none
    }

    /// Whether `other` is a scroll-driving pan on an ancestor `UIScrollView` (SwiftUI paging
    /// `TabView` / `ScrollView` are both UIScrollView-backed). Only those are asked to wait for
    /// our pan; SwiftUI's own simultaneous gestures and the SCNView's sibling recognizers are
    /// left to default arbitration.
    static func isAncestorScrollPan(_ other: UIGestureRecognizer, sceneView: UIView?) -> Bool {
        guard other is UIPanGestureRecognizer, let host = other.view, host is UIScrollView else { return false }
        return host !== sceneView
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === panGesture else { return true }
        return Self.panClaimsSingleFingerTouch(gesturesEnabled: gesturesEnabled, interactionMode: interactionMode)
    }

    /// 3D camera orbit (and ball drag / aim nudge on `tapsOnly` pages) owns a swipe that starts on
    /// the table: the enclosing pager must not also page, and must not steal the swipe.
    /// Returning `true` is the dynamic form of `other.require(toFail: panGesture)`.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === panGesture,
              Self.panClaimsSingleFingerTouch(gesturesEnabled: gesturesEnabled, interactionMode: interactionMode)
        else { return false }
        return Self.isAncestorScrollPan(otherGestureRecognizer, sceneView: scnView)
    }
}

/// Counts completed SceneKit render callbacks, not the requested display-link rate.
private struct FPSReadout: View {
    let text: String
    var body: some View {
        Text(text).font(.btCaption2).monospacedDigit().fixedSize()
            .foregroundStyle(Color.btTextSecondary)
            .padding(.horizontal, Spacing.sm).padding(.vertical, Spacing.xs)
            .background(Color.btBGSecondary.opacity(0.85), in: Capsule())
            .environment(\.colorScheme, .dark)
            .accessibilityLabel("渲染帧率，" + text)
            .accessibilityIdentifier("table.renderFPS")
    }
}

/// SceneKit invokes delegates off the main thread; the counter and forwarding
/// target are protected together. UI updates remain on the coordinator's main loop.
final class FrameDelegate: NSObject, SCNSceneRendererDelegate {
    private let lock = NSLock()
    private var frames = 0
    private var target: MobileContactOcclusion?
    var contact: MobileContactOcclusion? {
        get { lock.lock(); defer { lock.unlock() }; return target }
        set { lock.lock(); target = newValue; lock.unlock() }
    }
    func takeFrameCount() -> Int {
        lock.lock(); defer { lock.unlock() }
        let result = frames; frames = 0; return result
    }
    func renderer(_ renderer: SCNSceneRenderer, didApplyAnimationsAtTime time: TimeInterval) {
        contact?.renderer(renderer, didApplyAnimationsAtTime: time)
    }
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        lock.lock(); frames += 1; lock.unlock()
        #if DEBUG
        contact?.renderer(renderer, didRenderScene: scene, atTime: time)
        #endif
    }
}

/// Screen-space labels keep world anchors, but reserve their complete readable footprint.
/// Only the interactive angle diagram opts in. This overlay never intercepts table gestures.
@MainActor
final class DiagramLabelOverlay {
    private var labels: [UILabel] = []
    private let angleMark = CAShapeLayer()
    private var choices: [Int: Int] = [:]
    private var geometryKey: [Float] = []
    private var previousAngleOffset: CGPoint?

    func update(scene: AngleTrainingScene, in view: SCNView) {
        guard scene.usesAdaptiveDiagramLabels, let g = scene.diagramLabelGeometry,
              view.bounds.width > 0, view.bounds.height > 0 else {
            labels.forEach { $0.isHidden = true }
            angleMark.isHidden = true
            geometryKey = []
            previousAngleOffset = nil
            return
        }
        scene.angleArcNode?.childNodes.filter { $0.name == "diagramTableArc" }.forEach {
            $0.isHidden = scene.currentCameraMode != .perspective3D
        }
        // Camera projection and ball positions are the complete layout input. Avoid per-frame
        // text measurement/candidate searches while the table and camera are stationary.
        let matrix = scene.cameraNode?.presentation.worldTransform ?? SCNMatrix4Identity
        let visible = scene.allBallNodes.values.filter { !$0.isHidden }
        let key: [Float] = [matrix.m11, matrix.m12, matrix.m13, matrix.m21, matrix.m22, matrix.m23,
            matrix.m31, matrix.m32, matrix.m33, matrix.m41, matrix.m42, matrix.m43,
            Float(view.bounds.width), Float(view.bounds.height),
            Float(scene.cameraNode?.camera?.orthographicScale ?? 0),
            g.cue.x, g.cue.z, g.target.x, g.target.z, g.pocket.x, g.pocket.z,
            Float(scene.currentTargetNumber ?? 0), Float(scene.cameraNode?.camera?.fieldOfView ?? 0)]
            + visible.sorted { ($0.name ?? "") < ($1.name ?? "") }.flatMap { [$0.position.x, $0.position.z] }
        guard key != geometryKey else { return }
        geometryKey = key
        angleMark.isHidden = true
        if labels.isEmpty {
            angleMark.name = "angleDiagram.arc"
            angleMark.fillColor = UIColor.clear.cgColor
            angleMark.strokeColor = TrajectoryStyle.contactColor.cgColor
            angleMark.lineWidth = 1.5
            angleMark.lineCap = .round
            view.layer.addSublayer(angleMark)
            for index in 0..<3 {
                let label = UILabel()
                label.font = .systemFont(ofSize: index == 0 ? 11 : 10, weight: .regular)
                label.textAlignment = .center
                label.isUserInteractionEnabled = false
                label.isAccessibilityElement = false
                label.accessibilityIdentifier = "angleDiagram.label.\(index)"
                label.layer.shadowColor = UIColor.black.cgColor
                label.layer.shadowOpacity = index == 0 ? 0 : 0.5
                label.layer.shadowRadius = 1
                label.layer.shadowOffset = CGSize(width: 0, height: 1)
                view.addSubview(label)
                labels.append(label)
            }
        }
        func projected(_ p: SCNVector3) -> CGPoint? {
            let s = view.projectPoint(p)
            guard s.x.isFinite, s.y.isFinite, s.z > 0, s.z < 1 else { return nil }
            return CGPoint(x: CGFloat(s.x), y: CGFloat(s.y))
        }
        guard let cue = projected(g.cue), let target = projected(g.target),
              let ghost = projected(g.ghost), let pocket = projected(g.pocket),
              let rail = projected(g.rail) else {
            labels.forEach { $0.isHidden = true }; return
        }
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let table = [SCNVector3(-halfL, g.cue.y, -halfW), SCNVector3(halfL, g.cue.y, -halfW),
                     SCNVector3(halfL, g.cue.y, halfW), SCNVector3(-halfL, g.cue.y, halfW)].compactMap(projected)
        guard table.count == 4 else { labels.forEach { $0.isHidden = true }; return }
        let polygon = UIBezierPath()
        polygon.move(to: table[0]); table.dropFirst().forEach { polygon.addLine(to: $0) }; polygon.close()
        let radius = AngleSceneCalculator.ballRadius
        func diskRect(_ p: SCNVector3, radius: Float, padding: CGFloat = 4, minimum: CGFloat = 6) -> CGRect? {
            guard let center = projected(p) else { return nil }
            let offsets = [SCNVector3(radius, 0, 0), SCNVector3(-radius, 0, 0),
                           SCNVector3(0, radius, 0), SCNVector3(0, 0, radius), SCNVector3(0, 0, -radius)]
            let extent = offsets.compactMap { projected(SCNVector3(p.x + $0.x, p.y + $0.y, p.z + $0.z)) }
                .map { hypot($0.x - center.x, $0.y - center.y) }.max() ?? 0
            let r = max(minimum, extent) + padding
            return CGRect(x: center.x - r, y: center.y - r, width: 2*r, height: 2*r)
        }
        let ballObstacles = visible.compactMap { diskRect(scene.visualCenter(of: $0), radius: radius) }
        let tightBallObstacles = visible.compactMap { diskRect(scene.visualCenter(of: $0), radius: radius, padding: 1, minimum: 0) }
        var occupied = ballObstacles
        if let rect = diskRect(g.ghost, radius: radius * 2.6) { occupied.append(rect) }
        let dx = g.pocket.x - g.target.x, dz = g.pocket.z - g.target.z
        let length = max(1e-6, hypotf(dx, dz))
        let ux = dx / length, uz = dz / length
        let reverse = max(radius * 6, 0.22)
        let back = projected(SCNVector3(g.target.x - ux*reverse, g.target.y, g.target.z - uz*reverse)) ?? ghost
        let tangentA = projected(SCNVector3(g.ghost.x - uz*radius*4, g.ghost.y, g.ghost.z + ux*radius*4)) ?? ghost
        let tangentB = projected(SCNVector3(g.ghost.x + uz*radius*4, g.ghost.y, g.ghost.z - ux*radius*4)) ?? ghost
        let lines = [(cue, rail), (pocket, back), (tangentA, tangentB)]
        let texts = ["\(Int(g.angle.rounded()))°", "瞄准线", "进球线"]
        var layouts: [[(Int, CGRect)]] = []
        for index in 0..<3 {
            let label = labels[index]
            label.text = texts[index]
            label.backgroundColor = .clear
            label.layer.cornerRadius = 3
            label.textColor = index == 2 ? TrajectoryStyle.potColor(forNumber: scene.currentTargetNumber) : .white
            let measured = label.sizeThatFits(CGSize(width: 200, height: 40))
            let size = CGSize(width: ceil(measured.width) + 4, height: ceil(measured.height) + 2)
            var candidates: [CGPoint] = []
            if index == 0 {
                // Keep a bounded local anchor. Small wedges use a nearby side label
                // instead of sending the value far down the rays to fit its full width.
                let a = atan2(ghost.y - cue.y, ghost.x - cue.x)
                let b = atan2(pocket.y - target.y, pocket.x - target.x)
                let sweep = atan2(sin(b-a), cos(b-a))
                let mid = a + sweep / 2
                for distance: CGFloat in [42, 48, 54] {
                    for fraction: CGFloat in [0.5, 0.35, 0.65] {
                        let direction = a + sweep * fraction
                        candidates.append(CGPoint(x: ghost.x + cos(direction)*distance,
                                                  y: ghost.y + sin(direction)*distance))
                    }
                }
                for offset: CGFloat in [30, 45, 60, 75, 90] {
                    for distance: CGFloat in [42, 48, 54, 60] {
                        for side: CGFloat in [1, -1] {
                            let direction = mid + side * offset * .pi / 180
                            candidates.append(CGPoint(x: ghost.x + cos(direction)*distance,
                                                      y: ghost.y + sin(direction)*distance))
                        }
                    }
                }
            } else {
                let start = index == 1 ? cue : target
                let end = index == 1 ? ghost : pocket
                let dx = end.x - start.x, dy = end.y - start.y
                let length = max(1, hypot(dx, dy))
                let nx = -dy / length, ny = dx / length
                let clearance = abs(nx)*size.width/2 + abs(ny)*size.height/2 + 3
                for step: CGFloat in [0, 1, 2, 3, 4] {
                    let extra = step * size.height
                    for t: CGFloat in (index == 1 ? [0.5, 0.45, 0.55, 0.35, 0.65] : [0.5, 0.35, 0.65, 0.2, 0.8]) {
                        for side: CGFloat in [1, -1] {
                            candidates.append(CGPoint(x: start.x + dx*t + nx*(clearance+extra)*side,
                                                      y: start.y + dy*t + ny*(clearance+extra)*side))
                        }
                    }
                }
            }
            if index > 0 {
                // Short lines near a rail can have no room on either normal. Search
                // around their midpoint as well, so the label may clear an endpoint.
                let start = index == 1 ? cue : target
                let end = index == 1 ? ghost : pocket
                let center = CGPoint(x: (start.x + end.x)/2, y: (start.y + end.y)/2)
                for step: CGFloat in [1, 2, 3, 4] {
                    let distance = max(size.width, size.height)/2 + step*size.height
                    for sector in 0..<16 {
                        let angle = CGFloat(sector) * CGFloat.pi / 8
                        candidates.append(CGPoint(x: center.x + cos(angle)*distance, y: center.y + sin(angle)*distance))
                    }
                }
            }
            var indices = Array(candidates.indices)
            if index == 0, let previous = previousAngleOffset {
                // A blocked side candidate should move to its nearest usable neighbour,
                // rather than restarting the search on the other side of the angle.
                let sideIndices = indices.filter { $0 >= 9 }.sorted {
                    let lhs = hypot(candidates[$0].x-ghost.x-previous.x, candidates[$0].y-ghost.y-previous.y)
                    let rhs = hypot(candidates[$1].x-ghost.x-previous.x, candidates[$1].y-ghost.y-previous.y)
                    return abs(lhs-rhs) < 0.01 ? $0 < $1 : lhs < rhs
                }
                indices = Array(indices.prefix(9)) + sideIndices
            }
            var valid: [(Int, CGRect)] = []
            for candidate in indices where candidates.indices.contains(candidate) {
                let center = candidates[candidate]
                let rect = CGRect(x: center.x-size.width/2, y: center.y-size.height/2, width: size.width, height: size.height)
                let padded = rect.insetBy(dx: -3, dy: -3)
                let corners = [CGPoint(x: padded.minX, y: padded.minY), CGPoint(x: padded.maxX, y: padded.minY),
                               CGPoint(x: padded.maxX, y: padded.maxY), CGPoint(x: padded.minX, y: padded.maxY)]
                guard view.bounds.insetBy(dx: 6, dy: 6).contains(padded),
                      corners.allSatisfy({ polygon.contains($0) }),
                      !occupied.contains(where: { $0.intersects(padded) }),
                      !lines.contains(where: { Self.segment($0.0, $0.1, intersects: rect.insetBy(dx: -1, dy: -1)) }),
                      (index != 0 || !Self.segment(pocket, back, intersects: rect.insetBy(dx: -4, dy: -4))) else { continue }
                valid.append((candidate, rect))
            }
            if index == 0 && valid.isEmpty {
                // Near a rail, permit the same local candidates beyond the cloth,
                // still clear of the balls and both labeled rays.
                valid = []
                for candidate in indices where candidates.indices.contains(candidate) {
                    let center = candidates[candidate]
                    let rect = CGRect(x: center.x-size.width/2, y: center.y-size.height/2,
                                      width: size.width, height: size.height)
                    let padded = rect.insetBy(dx: -3, dy: -3)
                    guard view.bounds.insetBy(dx: 6, dy: 6).contains(padded),
                          !tightBallObstacles.contains(where: { $0.intersects(rect) }),
                          !Self.segment(pocket, back, intersects: rect.insetBy(dx: -4, dy: -4)),
                          !Self.segment(cue, rail, intersects: rect.insetBy(dx: -1, dy: -1)) else { continue }
                    valid.append((candidate, rect))
                }
                label.backgroundColor = .clear
            }
            layouts.append(valid)
        }
        // Three labels must be placed together: greedily placing the angle first can
        // consume the only free space beside a short, rail-adjacent aim line.
        func solve(_ index: Int, placed: [(Int, CGRect)]) -> [(Int, CGRect)]? {
            if index == layouts.count { return placed }
            for candidate in layouts[index] {
                guard !placed.contains(where: { $0.1.insetBy(dx: -6, dy: -6).intersects(candidate.1) }) else { continue }
                if let result = solve(index + 1, placed: placed + [candidate]) { return result }
            }
            return nil
        }
        if let solution = solve(0, placed: []) {
            for (index, item) in solution.enumerated() {
                labels[index].isHidden = false; labels[index].frame = item.1; choices[index] = item.0
            }
        } else {
            // At extreme zoom or a densely occupied table, preserve readable labels in
            // semantic priority order. Never draw a label through a ball to keep it visible.
            var placed: [CGRect] = []
            for index in layouts.indices {
                let item = layouts[index].first { candidate in
                    !placed.contains { $0.insetBy(dx: -6, dy: -6).intersects(candidate.1) }
                }
                labels[index].isHidden = item == nil
                if let item {
                    labels[index].frame = item.1; choices[index] = item.0; placed.append(item.1)
                }
            }
        }
        if !labels[0].isHidden {
            previousAngleOffset = CGPoint(x: labels[0].center.x-ghost.x, y: labels[0].center.y-ghost.y)
        }
        let aimAngle = atan2(ghost.y - cue.y, ghost.x - cue.x)
        let potAngle = atan2(pocket.y - target.y, pocket.x - target.x)
        let sweep = atan2(sin(potAngle - aimAngle), cos(potAngle - aimAngle))
        if abs(sweep) > 0.001 {
            let arcRadius: CGFloat = 22
            let path = UIBezierPath()
            if scene.currentCameraMode == .perspective3D {
                // SceneKit's flat table arc participates in depth testing, so balls
                // naturally occlude it. Never paint an overlay arc over their pixels.
                angleMark.isHidden = true
                return
            } else {
                path.addArc(withCenter: ghost, radius: arcRadius, startAngle: aimAngle,
                            endAngle: aimAngle + sweep, clockwise: sweep > 0)
                // Short end ticks make small acute-angle marks legible in either camera mode.
                for a in [aimAngle, aimAngle + sweep] {
                    path.move(to: CGPoint(x: ghost.x + cos(a)*(arcRadius-3), y: ghost.y + sin(a)*(arcRadius-3)))
                    path.addLine(to: CGPoint(x: ghost.x + cos(a)*(arcRadius+3), y: ghost.y + sin(a)*(arcRadius+3)))
                }
            }
            angleMark.path = path.cgPath
            angleMark.isHidden = false
        }
    }

    /// Slab clipping gives an exact segment/rectangle test, including edge contact.
    static func segment(_ a: CGPoint, _ b: CGPoint, intersects rect: CGRect) -> Bool {
        var low: CGFloat = 0, high: CGFloat = 1
        for (origin, delta, minimum, maximum) in [(a.x, b.x-a.x, rect.minX, rect.maxX),
                                                (a.y, b.y-a.y, rect.minY, rect.maxY)] {
            if abs(delta) < 1e-8 {
                if origin < minimum || origin > maximum { return false }
            } else {
                let t0 = (minimum-origin)/delta, t1 = (maximum-origin)/delta
                low = max(low, min(t0,t1)); high = min(high, max(t0,t1))
                if low > high { return false }
            }
        }
        return true
    }
}
