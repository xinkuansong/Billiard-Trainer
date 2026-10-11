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
    /// Valid visible-depth world projection in window coordinates for floating HUD anchors.
    var projectInWindow: ((SCNVector3) -> CGPoint?)?
    var projectVisible: ((SCNVector3) -> CGPoint?)?
    static func world(at point: CGPoint, in renderer: SCNView, planeY: Float) -> SCNVector3? {
        let near = renderer.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 0))
        let far = renderer.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 1))
        let direction = SCNVector3(far.x - near.x, far.y - near.y, far.z - near.z)
        guard abs(direction.y) > 1e-6 else { return nil }
        let t = (planeY - near.y) / direction.y
        guard t > 0 else { return nil }
        return SCNVector3(near.x + direction.x * t, planeY, near.z + direction.z * t)
    }

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
    /// Supplied only by the explicitly instrumented daily-clearance page.
    var daily3DDiagnostics: Daily3DRenderDiagnostics? = nil
    /// Daily header reserves a trailing slot; nil retains the shared centered readout.
    var fpsReadoutTrailingInset: CGFloat? = nil
    /// An optional page-owned readout relocates telemetry without changing render scheduling.
    var fpsReadoutState: TableFPSReadoutState? = nil
    /// Daily two-view fixed HUD's measured free stage, in window points. Legacy hosts leave nil.
    /// Transient center overlays need separate visibility review; four edge insets do not certify them.
    var twoViewReadableFrameInWindow: CGRect? = nil
    var onCameraObservationBegan: (() -> Void)? = nil
    var onCameraObservationEnded: (() -> Void)? = nil
    var twoViewAutomaticEntryCount: Int = 0
    var twoViewSolverDiagnostics: String = ""
    var onThirdPersonAimNudged: ((Float) -> Void)? = nil

    var onTemporaryTopDownDismiss: (() -> Void)? = nil
    var topDownContentRevision: Int = 0
    /// Fit a temporary table to the same measured stage as fixed 2D training.
    var usesStandardTemporaryTable = false

    static func requestedFPS(maximum: Int, selected: RenderFrameRate = .fps60, active: Bool, thermal: ProcessInfo.ThermalState, lowPower: Bool) -> Int {
        let ceiling = thermal == .critical ? 30 : ((thermal == .serious || lowPower) ? 60 : maximum)
        return max(1, min(maximum, min(ceiling, active ? selected.rawValue : min(selected.rawValue, 30))))
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = LayoutAwareSceneView()
        scnView.onLayout = { [weak coordinator = context.coordinator] in
            coordinator?.synchronizeDailyViewportAfterLayout()
        }
        DailyLayoutProbe.record("viewport.make", ["renderer": String(describing: ObjectIdentifier(scnView)), "scene": String(describing: ObjectIdentifier(scene))])
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
        context.coordinator.twoViewReadableFrameInWindow = twoViewReadableFrameInWindow
        context.coordinator.onCameraObservationBegan = onCameraObservationBegan
        context.coordinator.onCameraObservationEnded = onCameraObservationEnded
        context.coordinator.twoViewAutomaticEntryCount = twoViewAutomaticEntryCount
        context.coordinator.twoViewSolverDiagnostics = twoViewSolverDiagnostics
        context.coordinator.onThirdPersonAimNudged = onThirdPersonAimNudged
        context.coordinator.onTemporaryTopDownDismiss = onTemporaryTopDownDismiss
        context.coordinator.topDownContentRevision = topDownContentRevision
        context.coordinator.usesStandardTemporaryTable = usesStandardTemporaryTable
        context.coordinator.fpsReadoutState = fpsReadoutState
        context.coordinator.installFPSReadout(in: scnView, trailingInset: fpsReadoutTrailingInset)
        context.coordinator.onPocketTapped = onPocketTapped
        context.coordinator.updatePocketAccessibility()
        context.coordinator.contentIsAnimating = contentIsAnimating
        context.coordinator.setDaily3DDiagnostics(daily3DDiagnostics)
        context.coordinator.startRenderLoop()
        context.coordinator.requestInteractiveFrames()
        bindProjector(to: scnView, coordinator: context.coordinator)

        // 4x8 台面网格（条 16）：交互页进场按全局偏好显隐；
        // 离线渲染（缩略图/视频导出）不走本视图，不受影响。
        scene.setTableGridVisible(UserPreferences.shared.showTableGrid)

        return scnView
    }

    /// 用捕获的 `SCNView` 填充坐标桥接闭包（台面平面 = surfaceY + 球半径）。
    private func bindProjector(to scnView: SCNView, coordinator: Coordinator) {
        guard let projector else { return }
        projector.unproject = { [weak coordinator] point in coordinator?.editingWorld(at: point) }
        projector.project = { [weak coordinator] world in coordinator?.editingPoint(world, visibleOnly: false) }
        projector.projectVisible = { [weak coordinator] world in coordinator?.editingPoint(world) }
        projector.projectInWindow = { [weak coordinator, weak scnView] world in
            guard let point = coordinator?.editingPoint(world), let scnView else { return nil }
            return scnView.convert(point, to: nil)
        }
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        #if DEBUG
        let cameraDiagnosticsChanged = context.coordinator.twoViewAutomaticEntryCount != twoViewAutomaticEntryCount
            || context.coordinator.twoViewSolverDiagnostics != twoViewSolverDiagnostics
        #endif
        context.coordinator.fpsReadoutState = fpsReadoutState
        context.coordinator.positionFPSReadout(trailingInset: fpsReadoutTrailingInset)
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
        if context.coordinator.locksCueBallScreenAnchor != locksCueBallScreenAnchor
            || context.coordinator.autoFitsRotatedTable != autoFitsRotatedTable
            || context.coordinator.autoFitsLandscapeTable != autoFitsLandscapeTable {
            context.coordinator.requestInteractiveFrames()
        }
        context.coordinator.setDaily3DDiagnostics(daily3DDiagnostics)
        context.coordinator.updateContentActivity(contentIsAnimating, cameraMode: cameraMode)
        context.coordinator.interactionMode = interactionMode
        context.coordinator.updateTwoViewReadableFrame(twoViewReadableFrameInWindow)
        let temporary2D = scene.cameraRig?.temporaryTopDownActive == true
        if context.coordinator.temporaryTopDownWasActive != temporary2D {
            context.coordinator.temporaryTopDownWasActive = temporary2D
            context.coordinator.requestInteractiveFrames()
        }
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
        context.coordinator.onCameraObservationBegan = onCameraObservationBegan
        context.coordinator.onCameraObservationEnded = onCameraObservationEnded
        context.coordinator.twoViewAutomaticEntryCount = twoViewAutomaticEntryCount
        context.coordinator.twoViewSolverDiagnostics = twoViewSolverDiagnostics
        context.coordinator.onThirdPersonAimNudged = onThirdPersonAimNudged
        context.coordinator.onTemporaryTopDownDismiss = onTemporaryTopDownDismiss
        context.coordinator.topDownContentRevision = topDownContentRevision
        context.coordinator.usesStandardTemporaryTable = usesStandardTemporaryTable
        context.coordinator.frameDelegate.contact = scene.contactOcclusion
        context.coordinator.updatePocketAccessibility()
        context.coordinator.updateTemporaryTopDownOverlay()
        #if DEBUG
        if cameraDiagnosticsChanged, ProcessInfo.processInfo.arguments.contains("-v63.cameraDiagnostics") {
            context.coordinator.refreshCameraDiagnostics()
        }
        #endif
        if let projector, projector.unproject == nil {
            bindProjector(to: uiView, coordinator: context.coordinator)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(scene: scene, cameraMode: cameraMode, interactionMode: interactionMode)
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        DailyLayoutProbe.record("viewport.dismantle", ["renderer": String(describing: ObjectIdentifier(uiView))])
        coordinator.removeTemporaryTopDownOverlay()
        coordinator.finishCameraObservation()
        coordinator.scene.cancelPocketSelectionFeedback()
        coordinator.endBallDrag()
        coordinator.endAimDrag()
        coordinator.stopRenderLoop()
        // 2D/3D layouts replace this child view while FreePlayView stays visible.
        // The page owns visibility; teardown only detaches this renderer's target.
        coordinator.setDaily3DDiagnostics(nil)
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
        private var lastViewportSize: CGSize?
        var twoViewReadableFrameInWindow: CGRect?
        var onCameraObservationBegan: (() -> Void)?
        var onCameraObservationEnded: (() -> Void)?
        var twoViewAutomaticEntryCount = 0
        var twoViewSolverDiagnostics = ""
        var onThirdPersonAimNudged: ((Float) -> Void)?
        private var cameraObservationActive = false
        var temporaryTopDownWasActive = false
        var onTemporaryTopDownDismiss: (() -> Void)?
        var topDownContentRevision = 0
        var usesStandardTemporaryTable = false
        private var mergedOverlay: SCNView?
        private var mergedDiagramLabels: DiagramLabelOverlay?
        private var mergedOverlayActivation = -1
        private var mergedNodeCopies: [SCNNode: SCNNode] = [:]
        private var mergedOverlayBuildCount = 0
        #if DEBUG
        private var ordinary2DAimSamples = 0
        private var ordinary2DProjectionViolations = 0
        #endif
        var mergedTouchOrigin: CGPoint?
        private var mergedDragNode: SCNNode?
        private var mergedDragOffset = SIMD3<Float>.zero
        private var temporaryTopDownImageView: UIImageView?
        private var temporaryTopDownImageBounds: CGRect?
        private var temporaryTopDownImageReadableRect: CGRect?
        private var temporaryTopDownImageScale: CGFloat?
        private var temporaryTopDownImageActivation = -1
        private var temporaryTopDownCaptureCount = 0
        private var temporaryTopDownCaptureMatrix: simd_float4x4?
        private var temporaryTopDownCaptureFOV: CGFloat = 0
        private var temporaryTopDownProjectedTable: CGRect = .zero
        private var temporaryTopDownHeldMatrixDelta: Float = 0
        private var temporaryTopDownHeldFOVDelta: CGFloat = 0
        private var temporaryTopDownHeldRoomVisible = false
        private var temporaryTopDownHoldCaptureCount = 0
        private var temporaryTopDownCaptureStartCount = 0
        private weak var temporaryTopDownRenderer: SCNRenderer?
        private var temporaryTopDownLastImageSize: CGSize = .zero
        private var temporaryTopDownHeldSeen = false
        private var temporaryTopDownCaptureWasOrthographic = false
        private var temporaryTopDownHeldOrthoChanged = false
        private var temporaryTopDownLastViewport: CGSize = .zero
        private var temporaryTopDownLastFrameInWindow: CGRect = .zero

        func removeTemporaryTopDownOverlay() {
            mergedOverlay?.scene = nil
            mergedOverlay?.removeFromSuperview()
            mergedOverlay = nil
            mergedDiagramLabels = nil
            mergedNodeCopies.removeAll()
            mergedDragNode = nil
            temporaryTopDownImageView?.image = nil
            temporaryTopDownImageView?.removeFromSuperview()
            temporaryTopDownImageView = nil
            temporaryTopDownImageBounds = nil
            temporaryTopDownImageReadableRect = nil
            temporaryTopDownImageScale = nil
        }

        private func updateMergedOverlay(view: SCNView, rig: CameraRig, frame: CameraRig.TemporaryTopDownFrame) {
            let overlay = mergedOverlay ?? SCNView(frame: view.bounds, options: nil)
            if mergedOverlay == nil { mergedDiagramLabels = DiagramLabelOverlay() }
            let rebuild = mergedOverlay == nil || mergedOverlayActivation != rig.temporaryTopDownActivationCount
            if rebuild {
                mergedNodeCopies.removeAll()
                overlay.scene = scene.makeTemporaryTopDownRenderScene { source, copy in
                    self.mergedNodeCopies[source] = copy
                }
                mergedOverlayBuildCount += 1
                let node = SCNNode()
                node.camera = (scene.cameraNode?.camera?.copy() as? SCNCamera) ?? SCNCamera()
                node.camera?.usesOrthographicProjection = true
                node.camera?.projectionDirection = .vertical
                node.camera?.zNear = 0.01; node.camera?.zFar = 100
                overlay.scene?.rootNode.addChildNode(node)
                overlay.pointOfView = node
                mergedOverlayActivation = rig.temporaryTopDownActivationCount
            }
            let stage = usesStandardTemporaryTable
                ? twoViewReadableFrameInWindow.map { view.convert($0, from: nil).intersection(view.bounds) } ?? view.bounds
                : view.bounds
            guard !stage.isEmpty, !stage.isNull else { return }
            let cameraChanged = rebuild || overlay.frame != stage
            overlay.frame = stage
            overlay.clipsToBounds = true
            let rotated = abs(frame.up.x) > 0.5
            let standardScale = CameraRig.landscapeOrthographicScale(viewSize: stage.size,
                halfLength: rotated ? rig.tableOuterHalfWidth : rig.tableOuterHalfLength,
                halfWidth: rotated ? rig.tableOuterHalfLength : rig.tableOuterHalfWidth)
            overlay.backgroundColor = .clear
            overlay.isOpaque = false
            overlay.isUserInteractionEnabled = false
            overlay.isPlaying = false
            overlay.rendersContinuously = false
            overlay.antialiasingMode = view.antialiasingMode
            overlay.autoenablesDefaultLighting = view.autoenablesDefaultLighting
            if cameraChanged {
            overlay.pointOfView?.camera?.orthographicScale = usesStandardTemporaryTable ? standardScale ?? frame.orthographicScale : frame.orthographicScale
            let target = usesStandardTemporaryTable ? SIMD3<Float>(0, frame.target.y, 0) : frame.target
            overlay.pointOfView?.simdPosition = usesStandardTemporaryTable ? target + SIMD3<Float>(0, 5, 0) : frame.eye
            overlay.pointOfView?.look(at: SCNVector3(target.x,target.y,target.z),
                up: SCNVector3(frame.up.x,frame.up.y,frame.up.z), localFront: SCNVector3(0,0,-1))
            }
            if let renderScene = overlay.scene {
                scene.synchronizeTemporaryTopDownScene(renderScene, copies: &mergedNodeCopies)
                // The orthographic layer uses the shared screen-space angle arc, not
                // the main perspective scene's table-space arc. Keep source nodes intact.
                if scene.usesAdaptiveDiagramLabels {
                    for (source, copy) in mergedNodeCopies where source.name == "diagramTableArc" {
                        copy.isHidden = true
                    }
                }
            }
            if overlay.superview == nil { view.insertSubview(overlay, at: 0) }
            mergedOverlay = overlay
        }

        /// All standard editable overlays use the renderer actually seen by the user.
        /// Legacy temporary-image hosts retain their existing frame protocol below.
        private var editingRenderer: SCNView? {
            if usesStandardTemporaryTable, scene.cameraRig?.temporaryTopDownActive == true {
                return mergedOverlay
            }
            return scnView
        }

        func editingWorld(at point: CGPoint) -> SCNVector3? {
            guard let main = scnView, let renderer = editingRenderer else { return nil }
            return TableProjector.world(at: renderer.convert(point, from: main), in: renderer,
                planeY: scene.surfaceY + AngleSceneCalculator.ballRadius)
        }

        func editingPoint(_ world: SCNVector3, visibleOnly: Bool = true) -> CGPoint? {
            guard let main = scnView, let renderer = editingRenderer else { return nil }
            let p = renderer.projectPoint(world)
            guard p.x.isFinite, p.y.isFinite, !visibleOnly || (p.z > 0 && p.z < 1) else { return nil }
            return main.convert(CGPoint(x: CGFloat(p.x), y: CGFloat(p.y)), from: renderer)
        }

        private func overlayWorld(_ point: CGPoint) -> SIMD3<Float>? {
            if usesStandardTemporaryTable {
                return editingWorld(at: point).map { SIMD3($0.x, $0.y, $0.z) }
            }
            guard let view = scnView, let frame = scene.cameraRig?.temporaryTopDownOverlayFrame else { return nil }
            return frame.world(at: point, viewport: view.bounds.size)
        }

        private func overlayPoint(_ node: SCNNode) -> CGPoint? {
            if usesStandardTemporaryTable { return editingPoint(node.worldPosition) }
            guard let view = scnView, let frame = scene.cameraRig?.temporaryTopDownOverlayFrame else { return nil }
            return frame.screen(point: node.simdWorldPosition, viewport: view.bounds.size)
        }

        private func overlayBall(at point: CGPoint, candidates: [SCNNode]) -> SCNNode? {
            candidates.filter { !$0.isHidden }.compactMap { node -> (SCNNode, CGFloat)? in
                guard let p = overlayPoint(node) else { return nil }
                let distance = hypot(p.x-point.x,p.y-point.y)
                return distance <= 22 ? (node,distance) : nil
            }.min { $0.1 < $1.1 }?.0
        }

        private func handleOverlayTap(_ point: CGPoint) {
            guard scene.cameraRig?.usesMergedCamera == true, let view = scnView,
                let rig = scene.cameraRig, let frame = rig.temporaryTopDownOverlayFrame else { return }
            if let ball = overlayBall(at: point, candidates: selectableBallNodes) {
                onBallTapped?(ball); requestInteractiveFrames(); return
            }
            let pockets = AngleSceneCalculator.pocketMarkerPositions(surfaceY: scene.surfaceY)
            let closest = pockets.enumerated().map { index, p -> (Int, CGFloat) in
                let screen = usesStandardTemporaryTable
                    ? editingPoint(p) ?? CGPoint(x: -10000, y: -10000)
                    : frame.screen(point: SIMD3(p.x,p.y,p.z), viewport: view.bounds.size)
                return (index,hypot(screen.x-point.x,screen.y-point.y))
            }.min { $0.1 < $1.1 }
            if let closest, closest.1 <= 24 {
                onPocketTapped?(closest.0); requestInteractiveFrames(); return
            }
            guard let world = overlayWorld(point) else { return }
            if abs(world.x) > Float(rig.tableOuterHalfLength) || abs(world.z) > Float(rig.tableOuterHalfWidth) {
                onTemporaryTopDownDismiss?()
            }
        }

        private func handleOverlayPan(_ gesture: UIPanGestureRecognizer) {
            guard scene.cameraRig?.usesMergedCamera == true, let view = scnView else { return }
            let point = gesture.location(in: view)
            switch gesture.state {
            case .began:
                let delta = gesture.translation(in: view)
                let start = mergedTouchOrigin ?? CGPoint(x: point.x-delta.x,y: point.y-delta.y)
                guard let node = overlayBall(at: start, candidates: draggableBallNodes),
                    let world = overlayWorld(start) else { return }
                mergedDragNode = node
                mergedDragOffset = node.simdWorldPosition - world
                onDragBegan?(node)
            case .changed:
                guard let node = mergedDragNode, let world = overlayWorld(point) else { return }
                let destination = world + mergedDragOffset
                onDragMoved?(node,SCNVector3(destination.x,destination.y,destination.z))
            case .ended, .cancelled, .failed:
                if let node = mergedDragNode {
                    if gesture.state == .ended, let world = overlayWorld(point) {
                        let destination = world + mergedDragOffset
                        onDragMoved?(node,SCNVector3(destination.x,destination.y,destination.z))
                    }
                    onDragEnded?(node)
                    if gesture.state == .ended { onDragEndedAt?(node, point) }
                }
                mergedTouchOrigin = nil
                mergedDragNode = nil
            default: break
            }
            requestInteractiveFrames()
            updateTemporaryTopDownOverlay()
        }

        /// No renderer is retained: one immutable table image per hold/layout.
        func updateTemporaryTopDownOverlay() {
            guard let view = scnView, let rig = scene.cameraRig,
                  rig.usesTwoViewCameraControls, rig.temporaryTopDownActive else {
                removeTemporaryTopDownOverlay()
                return
            }
            guard view.window != nil, view.bounds.width > 1, view.bounds.height > 1,
                  let frame = rig.temporaryTopDownOverlayFrame else { return }
            if rig.usesMergedCamera {
                updateMergedOverlay(view: view, rig: rig, frame: frame)
                return
            }
            if let captured = temporaryTopDownCaptureMatrix,
               temporaryTopDownImageActivation == rig.temporaryTopDownActivationCount,
               let camera = scene.cameraNode {
                temporaryTopDownHeldSeen = true
                temporaryTopDownHeldOrthoChanged = temporaryTopDownHeldOrthoChanged
                    || (camera.camera?.usesOrthographicProjection == true) != temporaryTopDownCaptureWasOrthographic
                let current = camera.presentation.simdWorldTransform
                for column in 0..<4 {
                    for row in 0..<4 {
                        temporaryTopDownHeldMatrixDelta = max(temporaryTopDownHeldMatrixDelta,
                            abs(current[column][row] - captured[column][row]))
                    }
                }
                temporaryTopDownHeldFOVDelta = max(temporaryTopDownHeldFOVDelta,
                    abs((camera.camera?.fieldOfView ?? 0) - temporaryTopDownCaptureFOV))
                let room = scene.rootNode.childNode(withName: "reference_room", recursively: false)
                temporaryTopDownHeldRoomVisible = temporaryTopDownHeldRoomVisible && room?.isHidden == false
            }
            let scale = view.contentScaleFactor
            guard temporaryTopDownImageView == nil
                || temporaryTopDownImageBounds != view.bounds
                || temporaryTopDownImageReadableRect != frame.readableRect
                || temporaryTopDownImageScale != scale
                || temporaryTopDownImageActivation != rig.temporaryTopDownActivationCount else { return }

            if temporaryTopDownImageActivation != rig.temporaryTopDownActivationCount {
                temporaryTopDownCaptureMatrix = scene.cameraNode?.presentation.simdWorldTransform
                temporaryTopDownCaptureFOV = scene.cameraNode?.camera?.fieldOfView ?? 0
                temporaryTopDownHeldMatrixDelta = 0
                temporaryTopDownHeldFOVDelta = 0
                temporaryTopDownHeldRoomVisible = scene.rootNode.childNode(withName: "reference_room", recursively: false)?.isHidden == false
                temporaryTopDownCaptureStartCount = temporaryTopDownCaptureCount
                temporaryTopDownHeldSeen = false
                temporaryTopDownCaptureWasOrthographic = scene.cameraNode?.camera?.usesOrthographicProjection == true
                temporaryTopDownHeldOrthoChanged = false
            }
            let renderScene = scene.makeTemporaryTopDownRenderScene()
            let cameraNode = SCNNode()
            cameraNode.name = "temporaryTopDownSnapshotCamera"
            let camera = (scene.cameraNode?.camera?.copy() as? SCNCamera) ?? SCNCamera()
            camera.usesOrthographicProjection = true
            camera.projectionDirection = .vertical
            camera.orthographicScale = frame.orthographicScale
            camera.automaticallyAdjustsZRange = false
            camera.zNear = 0.01
            camera.zFar = 100
            cameraNode.camera = camera
            cameraNode.simdPosition = frame.eye
            cameraNode.look(at: SCNVector3(frame.target.x, frame.target.y, frame.target.z),
                up: SCNVector3(frame.up.x, frame.up.y, frame.up.z), localFront: SCNVector3(0, 0, -1))
            renderScene.rootNode.addChildNode(cameraNode)

            let renderer = SCNRenderer(device: view.device, options: nil)
            temporaryTopDownRenderer = renderer
            renderer.scene = renderScene
            renderer.pointOfView = cameraNode
            renderer.autoenablesDefaultLighting = view.autoenablesDefaultLighting
            renderer.isJitteringEnabled = view.isJitteringEnabled
            renderer.isPlaying = false
            let image = renderer.snapshot(atTime: view.sceneTime,
                with: CGSize(width: view.bounds.width * scale, height: view.bounds.height * scale),
                antialiasingMode: view.antialiasingMode)
            temporaryTopDownLastImageSize = CGSize(width: CGFloat(image.cgImage?.width ?? 0),
                height: CGFloat(image.cgImage?.height ?? 0))
            temporaryTopDownLastViewport = view.bounds.size
            temporaryTopDownLastFrameInWindow = view.convert(view.bounds, to: nil)
            // The standalone renderer projects into a bottom-left pixel viewport.
            // UIKit uses a top-left origin; flip Y, restore the view bounds origin,
            // then convert local points to the window used by HUD diagnostics.
            let corners = [-Float(rig.tableOuterHalfLength), Float(rig.tableOuterHalfLength)].flatMap { x in
                [-Float(rig.tableOuterHalfWidth), Float(rig.tableOuterHalfWidth)].map { z in
                    let point = renderer.projectPoint(SCNVector3(x, scene.surfaceY, z))
                    return view.convert(CGPoint(x: view.bounds.minX + CGFloat(point.x) / scale,
                        y: view.bounds.maxY - CGFloat(point.y) / scale), to: nil)
                }
            }
            if let minX = corners.map(\.x).min(), let maxX = corners.map(\.x).max(),
               let minY = corners.map(\.y).min(), let maxY = corners.map(\.y).max() {
                temporaryTopDownProjectedTable = CGRect(x: minX, y: minY,
                    width: maxX - minX, height: maxY - minY)
            }
            let imageView = temporaryTopDownImageView ?? UIImageView()
            imageView.frame = view.bounds
            imageView.backgroundColor = .clear
            imageView.isOpaque = false
            imageView.contentMode = .scaleToFill
            imageView.isUserInteractionEnabled = false
            imageView.isAccessibilityElement = true
            imageView.accessibilityIdentifier = "shotCamera.temporaryTopDownOverlay"
            imageView.accessibilityLabel = "临时俯视球桌叠层"
            imageView.image = image
            if imageView.superview == nil { view.insertSubview(imageView, at: 0) }
            temporaryTopDownImageView = imageView
            temporaryTopDownImageBounds = view.bounds
            temporaryTopDownImageReadableRect = frame.readableRect
            temporaryTopDownImageScale = scale
            temporaryTopDownImageActivation = rig.temporaryTopDownActivationCount
            temporaryTopDownCaptureCount += 1
            temporaryTopDownHoldCaptureCount = temporaryTopDownCaptureCount - temporaryTopDownCaptureStartCount
            imageView.accessibilityValue = "静态正投影；生成\(temporaryTopDownCaptureCount)次"
            #if DEBUG
            // Explicit diagnostics only; exports the original snapshot including alpha.
            // "documents" resolves inside the app container; an explicit app-writable
            // absolute directory remains available to the diagnostic host.
            if ProcessInfo.processInfo.arguments.contains("-v63.cameraDiagnostics"),
               let directory = ProcessInfo.processInfo.environment["TWO_VIEW_OVERLAY_DIAG_DIR"],
               !directory.isEmpty, let data = image.pngData() {
                do {
                    let url: URL
                    if directory == "documents" {
                        guard let documents = FileManager.default.urls(for: .documentDirectory,
                            in: .userDomainMask).first else {
                            throw NSError(domain: "TwoViewOverlayDiagnostics", code: 1,
                                userInfo: [NSLocalizedDescriptionKey: "Application Documents directory is unavailable"])
                        }
                        url = documents.appendingPathComponent("TwoViewOverlays", isDirectory: true)
                    } else {
                        url = URL(fileURLWithPath: directory, isDirectory: true)
                    }
                    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                    try data.write(to: url.appendingPathComponent(
                        "overlay-\(rig.temporaryTopDownActivationCount)-\(temporaryTopDownCaptureCount).png"), options: .atomic)
                } catch {
                    NSLog("Temporary top-down diagnostic export failed: %@", error.localizedDescription)
                }
            }
            updateFPSReadout(force: true)
            #endif
        }
        #if DEBUG
        private var twoViewPanDX: Float = 0
        private var twoViewPanDY: Float = 0
        private var twoViewHeldSamples = 0
        private var twoViewHeldPeak = -Float.infinity
        private var twoViewHeldPose: TwoViewCamera.Pose?
        private var twoViewHeldProgress: Float = 0
        private var twoViewHeldYaw: Float = 0
        private var twoViewGestureAxis = "none"
        #endif

        func finishCameraObservation() {
            surfaceAxisLock = SurfacePanAxisLock()
            guard cameraObservationActive else { return }
            cameraObservationActive = false
            if let onCameraObservationEnded { onCameraObservationEnded() }
            else { scene.cameraRig?.endTemporaryObservation() }
            requestInteractiveFrames()
        }

        func updateTwoViewReadableFrame(_ frame: CGRect?) {
            guard twoViewReadableFrameInWindow != frame else { return }
            twoViewReadableFrameInWindow = frame
            if let scnView { updateViewport(scnView.bounds.size) }
            requestInteractiveFrames()
        }
        var contentIsAnimating: Bool?
        private var needsContinuousUpdates = true
        // Keep legacy callers with unknown activity running; explicit idle sleeps.
        var eventDrivenIdle = true
        var isDisplayLinkPaused: Bool { displayLink?.isPaused ?? true }
        private(set) var displayLinkCallbackCount = 0
        private(set) var interactiveUntil: CFTimeInterval = 0
        let frameDelegate: FrameDelegate = Daily3DRenderDiagnostics.isEnabled ? Daily3DFrameDelegate() : FrameDelegate()
        private(set) var daily3DDiagnostics: Daily3DRenderDiagnostics?
        weak var fpsReadoutState: TableFPSReadoutState?
        private var fpsHost: UIHostingController<FPSReadout>?
        private let diagramLabels = DiagramLabelOverlay()
        private var fpsText = "— FPS"
        private var fpsConstraints: [NSLayoutConstraint] = []
        private var fpsTrailingInset: CGFloat?
        private var fpsSampleTime = CACurrentMediaTime()

        func setDaily3DDiagnostics(_ diagnostics: Daily3DRenderDiagnostics?) {
            guard daily3DDiagnostics !== diagnostics else { return }
            daily3DDiagnostics = diagnostics
            (frameDelegate as? Daily3DFrameDelegate)?.setDiagnostics(diagnostics)
        }

        #if DEBUG
        /// Publication freshness only: do not extend activity or resume the renderer.
        func refreshCameraDiagnostics() {
            updateFPSReadout(force: true)
        }
        #endif

        func installFPSReadout(in view: SCNView, trailingInset: CGFloat? = nil) {
            let host = UIHostingController(rootView: FPSReadout(text: "— FPS", compact: trailingInset != nil, suppressed: fpsReadoutState != nil))
            host.sizingOptions = .intrinsicContentSize
            host.view.backgroundColor = .clear
            host.view.isUserInteractionEnabled = false
            host.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(host.view)
            fpsHost = host
            positionFPSReadout(trailingInset: trailingInset)
            updateFPSReadout()
        }

        func positionFPSReadout(trailingInset: CGFloat?) {
            guard let view = scnView, let host = fpsHost,
                  fpsConstraints.isEmpty || fpsTrailingInset != trailingInset else { return }
            NSLayoutConstraint.deactivate(fpsConstraints)
            fpsTrailingInset = trailingInset
            if let trailingInset {
                fpsConstraints = [
                    host.view.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 62),
                    host.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -trailingInset)
                ]
            } else {
                fpsConstraints = [
                    host.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Spacing.xs),
                    host.view.centerXAnchor.constraint(equalTo: view.centerXAnchor)
                ]
            }
            host.rootView = FPSReadout(text: fpsText, compact: trailingInset != nil, suppressed: fpsReadoutState != nil)
            NSLayoutConstraint.activate(fpsConstraints)
        }

        private func updateFPSReadout(force: Bool = false) {
            #if DEBUG
            let showsCameraDiagnostics = ProcessInfo.processInfo.arguments.contains("-v63.cameraDiagnostics")
            #else
            let showsCameraDiagnostics = false
            #endif
            fpsHost?.view.isHidden = (fpsReadoutState != nil || cameraMode != .perspective3D) && !showsCameraDiagnostics
            let now = CACurrentMediaTime()
            guard force || now - fpsSampleTime >= 1 else { return }
            let count = frameDelegate.takeFrameCount()
            let elapsed = now - fpsSampleTime
            let fps = elapsed > 0 ? Int((Double(count) / elapsed).rounded()) : 0
            fpsSampleTime = now
            guard cameraMode == .perspective3D || showsCameraDiagnostics || fpsReadoutState != nil else {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-renderProfileProbe") { updatePocketAccessibility() }
                #endif
                return
            }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-v63.cameraDiagnostics"),
               let scnView, let rig = scene.cameraRig, let host = fpsHost {
                let center = scnView.projectPoint(SCNVector3(0, scene.surfaceY + BallPhysics.radius, 0))
                let corners = [-Float(rig.tableOuterHalfLength), Float(rig.tableOuterHalfLength)].flatMap { x in
                    [-Float(rig.tableOuterHalfWidth), Float(rig.tableOuterHalfWidth)].map { z in
                        scnView.projectPoint(SCNVector3(x, scene.surfaceY, z))
                    }
                }
                let balls = scene.allBallNodes.sorted { $0.key < $1.key }.filter { !$0.value.isHidden }.map { key, node in
                    let p = scnView.projectPoint(node.position)
                    let window = scnView.convert(CGPoint(x: CGFloat(p.x), y: CGFloat(p.y)), to: nil)
                    return "ball_\(key)=\(p.x),\(p.y),\(p.z) window_\(key)=\(window.x),\(window.y),\(p.z)"
                }.joined(separator: " ")
                host.view.isAccessibilityElement = true
                host.view.accessibilityIdentifier = "v63.cameraDiagnostics"
                let pocket = rig.observationPocket.map { "pocketIndex=\($0.index) pocketWorld=\($0.position) pocketScreen=\(scnView.projectPoint($0.position))" } ?? "pocketIndex=-1"
                host.view.accessibilityValue = "viewport=\(scnView.bounds.size) rigViewport=\(rig.viewportSize) center=\(center) corners=\(corners) pivot=\(rig.targetPivot) yaw=\(rig.targetYaw) distance=\(rig.orbitDistance) elevation=\(rig.orbitElevation) pitch=\(rig.captureCurrentPose().pitch) fov=\(rig.captureCurrentPose().fov) eye=\(scene.cameraNode?.position ?? SCNVector3Zero) cueLift=\(-(scene.cueStick?.rootNode.eulerAngles.x ?? 0)) \(balls) \(pocket)"
                if let stick = scene.cueStick, let cue = scene.cueBallNode, let aim = scene.lastCueAim {
                    let shown = stick.rootNode.presentation
                    let back = shown.simdWorldTransform.columns.2
                    let denominator = hypot(back.x, back.z) * hypot(aim.x, aim.z)
                    let alignment = denominator > 0 ? -(back.x * aim.x + back.z * aim.z) / denominator : -1
                    let distance = simd_distance(shown.simdWorldPosition, cue.presentation.simdWorldPosition)
                    host.view.accessibilityValue = (host.view.accessibilityValue ?? "")
                        + " cueAddressAlignment=\(alignment) cueAddressDistance=\(distance) cueAddressHidden=\(stick.rootNode.isHidden) cueAddressOpacity=\(stick.fadeOpacity)"
                }
                if rig.usesTwoViewCameraControls, let camera = scene.cameraNode {
                    host.view.accessibilityValue = (host.view.accessibilityValue ?? "") + " " + twoViewSolverDiagnostics
                    let shown = camera.presentation
                    let eye = shown.worldPosition
                    let readable = twoViewReadableFrameInWindow ?? .zero
                    host.view.accessibilityValue = (host.view.accessibilityValue ?? "")
                        + " twoViewMode=\(rig.twoViewMode.rawValue) twoViewOwner=\(rig.twoViewOwnerIsManual ? "manual" : "automatic") twoViewMoving=\(rig.isTransitioning || rig.hasPendingDamping) twoViewEyeX=\(eye.x) twoViewEyeY=\(eye.y) twoViewEyeZ=\(eye.z) twoViewYaw=\(shown.eulerAngles.y) twoViewFOV=\(shown.camera?.fieldOfView ?? 0) twoViewReadableX=\(readable.minX) twoViewReadableY=\(readable.minY) twoViewReadableW=\(readable.width) twoViewReadableH=\(readable.height) twoViewPanDX=\(twoViewPanDX) twoViewPanDY=\(twoViewPanDY) twoViewAutomaticEntryCount=\(twoViewAutomaticEntryCount)"
                    let matrix = shown.simdWorldTransform
                    let forward = -SIMD3<Float>(matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z)
                    let heading = atan2(-forward.z, -forward.x)
                    let pitchDown = -asin(max(-1, min(1, forward.y)))
                    let centerWindow = scnView.convert(CGPoint(x: CGFloat(center.x), y: CGFloat(center.y)), to: nil)
                    let centerFraction = readable.width > 1 ? (centerWindow.x - readable.minX) / readable.width : 0.5
                    let tableWindows = corners.map { scnView.convert(CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)), to: nil) }
                    host.view.accessibilityValue = (host.view.accessibilityValue ?? "")
                        + " twoViewHeading=\(heading) twoViewPitchDown=\(pitchDown) twoViewCenterXFraction=\(centerFraction) twoViewRadius=\(hypot(eye.x, eye.z))"
                        + " twoViewTableMinX=\(tableWindows.map(\.x).min() ?? 0) twoViewTableMaxX=\(tableWindows.map(\.x).max() ?? 0) twoViewTableMinY=\(tableWindows.map(\.y).min() ?? 0) twoViewTableMaxY=\(tableWindows.map(\.y).max() ?? 0) twoViewTableMinDepth=\(corners.map(\.z).min() ?? 0) twoViewTableMaxDepth=\(corners.map(\.z).max() ?? 0)"
                    if let simple = rig.twoViewSnapshot?.simpleShot {
                        host.view.accessibilityValue = (host.view.accessibilityValue ?? "")
                            + " simpleCueScale=\(scene.cueBallNode?.scale.x ?? 0) simpleCamera=true simpleDistance=\(simple.actualDistance) surfaceCamera=\(simple.surface != nil) surfaceTravel=\(simple.surface?.travel ?? -1) surfaceBearing=\(simple.surface?.bearing ?? 0) simpleHeight=\(simple.pose.eye.y-simple.surfaceY)"
                    }
                    if let snapshot = rig.twoViewSnapshot {
                        host.view.accessibilityValue = (host.view.accessibilityValue ?? "")
                            + " twoViewProgress=\(snapshot.progress) twoViewRailYaw=\(snapshot.yaw)"
                        if let baseline = snapshot.defaultPose ?? snapshot.firstPersonBase {
                            let forward = baseline.forward
                            host.view.accessibilityValue = (host.view.accessibilityValue ?? "")
                                + " twoViewDefaultEyeX=\(baseline.eye.x) twoViewDefaultEyeY=\(baseline.eye.y) twoViewDefaultEyeZ=\(baseline.eye.z) twoViewDefaultHeading=\(atan2(-forward.z, -forward.x)) twoViewDefaultPitchDown=\(-asin(max(-1, min(1, forward.y)))) twoViewDefaultProgress=0.5 twoViewDefaultFOV=\(baseline.fov)"
                        }
                    }
                    let aim = rig.twoViewCurrentAim ?? SCNVector3Zero
                    host.view.accessibilityValue = (host.view.accessibilityValue ?? "")
                        + " mergedGlobal=\(rig.mergedGlobalActive) mergedOverlay=\(mergedOverlay != nil) topDownRevision=\(topDownContentRevision) overlayBuilds=\(mergedOverlayBuildCount) ordinary2DAimSamples=\(ordinary2DAimSamples) ordinary2DProjectionViolations=\(ordinary2DProjectionViolations) twoViewGestureAxis=\(twoViewGestureAxis) twoViewHeldSamples=\(twoViewHeldSamples) twoViewTemporary2D=\(rig.temporaryTopDownActive) twoViewOrtho=\(camera.camera?.usesOrthographicProjection == true) twoView2DActivationCount=\(rig.temporaryTopDownActivationCount) twoView2DHeldSamples=\(rig.temporaryTopDownHeldSamples) twoView2DUpX=\(rig.temporaryTopDownLastUp.x) twoView2DUpZ=\(rig.temporaryTopDownLastUp.z) twoViewAimX=\(aim.x) twoViewAimZ=\(aim.z)"
                    host.view.accessibilityValue = (host.view.accessibilityValue ?? "")
                        + " twoView2DReferenceYaw=\(rig.temporaryTopDownReferenceYaw) twoView2DReferenceSource=\(rig.temporaryTopDownReferenceSource.replacingOccurrences(of: " ", with: "_")) twoView2DScreenRightX=\(-rig.temporaryTopDownLastUp.z) twoView2DScreenRightZ=\(rig.temporaryTopDownLastUp.x)"
                    if rig.usesMergedCamera, let frame = rig.temporaryTopDownOverlayFrame {
                        let view = scnView
                        for (key, node) in scene.allBallNodes where !node.isHidden {
                            let local = frame.screen(point: node.simdWorldPosition, viewport: view.bounds.size)
                            let p = view.convert(local, to: nil)
                            host.view.accessibilityValue = (host.view.accessibilityValue ?? "")
                                + " overlay_\(key)X=\(p.x) overlay_\(key)Y=\(p.y)"
                        }
                        for (index,pocket) in AngleSceneCalculator.pocketMarkerPositions(surfaceY: scene.surfaceY).enumerated() {
                            let p = view.convert(frame.screen(point: SIMD3(pocket.x,pocket.y,pocket.z), viewport: view.bounds.size), to: nil)
                            host.view.accessibilityValue = (host.view.accessibilityValue ?? "") + " overlay_pocket\(index)X=\(p.x) overlay_pocket\(index)Y=\(p.y)"
                        }
                    }
                    if let captured = temporaryTopDownCaptureMatrix {
                        var matrixDelta: Float = 0
                        for column in 0..<4 {
                            for row in 0..<4 {
                                matrixDelta = max(matrixDelta, abs(matrix[column][row] - captured[column][row]))
                            }
                        }
                        let room = scene.rootNode.childNode(withName: "reference_room", recursively: false)
                        let table = temporaryTopDownProjectedTable
                        host.view.accessibilityValue = (host.view.accessibilityValue ?? "")
                            + " twoViewOverlayActive=\(temporaryTopDownImageView != nil) twoViewOverlayCaptureCount=\(temporaryTopDownCaptureCount) twoViewOverlayResidentRenderer=\(temporaryTopDownRenderer != nil) twoViewOverlayMainMatrixDelta=\(matrixDelta) twoViewOverlayMainFOVDelta=\(abs((camera.camera?.fieldOfView ?? 0) - temporaryTopDownCaptureFOV)) twoViewOverlayRoomVisible=\(room != nil && room?.isHidden == false) twoViewOverlayTableMinX=\(table.minX) twoViewOverlayTableMaxX=\(table.maxX) twoViewOverlayTableMinY=\(table.minY) twoViewOverlayTableMaxY=\(table.maxY) twoViewOverlayImageWidth=\(temporaryTopDownLastImageSize.width) twoViewOverlayImageHeight=\(temporaryTopDownLastImageSize.height)"
                        host.view.accessibilityValue = (host.view.accessibilityValue ?? "")
                            + " twoViewOverlayHoldCaptureCount=\(temporaryTopDownHoldCaptureCount) twoViewOverlayHeldMainMatrixDelta=\(temporaryTopDownHeldMatrixDelta) twoViewOverlayHeldMainFOVDelta=\(temporaryTopDownHeldFOVDelta) twoViewOverlayHeldRoomVisible=\(temporaryTopDownHeldRoomVisible)"
                        host.view.accessibilityValue = (host.view.accessibilityValue ?? "")
                            + " twoViewOverlayHeldSeen=\(temporaryTopDownHeldSeen) twoViewOverlayHeldOrthoChanged=\(temporaryTopDownHeldOrthoChanged)"
                        let overlayFrame = temporaryTopDownLastFrameInWindow
                        host.view.accessibilityValue = (host.view.accessibilityValue ?? "")
                            + " twoViewOverlayViewportWidth=\(temporaryTopDownLastViewport.width) twoViewOverlayViewportHeight=\(temporaryTopDownLastViewport.height) twoViewOverlayFrameX=\(overlayFrame.minX) twoViewOverlayFrameY=\(overlayFrame.minY) twoViewOverlayFrameWidth=\(overlayFrame.width) twoViewOverlayFrameHeight=\(overlayFrame.height)"
                    }
                    if let held = twoViewHeldPose {
                        let forward = held.forward
                        host.view.accessibilityValue = (host.view.accessibilityValue ?? "")
                            + " twoViewHeldEyeX=\(held.eye.x) twoViewHeldEyeY=\(held.eye.y) twoViewHeldEyeZ=\(held.eye.z) twoViewHeldHeading=\(atan2(-forward.z, -forward.x)) twoViewHeldPitchDown=\(-asin(max(-1, min(1, forward.y)))) twoViewHeldProgress=\(twoViewHeldProgress) twoViewHeldRailYaw=\(twoViewHeldYaw) twoViewHeldFOV=\(held.fov)"
                    }
                }
            }
            #endif
            let next = !needsContinuousUpdates ? "FPS · 静止" : "\(fps) FPS"
            guard fpsText != next else { return }
            fpsText = next
            // Publish outside UIViewRepresentable's update pass; only the small HUD subscribes.
            if let state = fpsReadoutState {
                DispatchQueue.main.async { [weak state] in state?.publish(next) }
            }
            fpsHost?.rootView = FPSReadout(text: next, compact: fpsTrailingInset != nil, suppressed: fpsReadoutState != nil)
            updatePocketAccessibility()
        }

        private var lastSevereThermalTime: CFTimeInterval = -.infinity

        /// A projection switch resizes the retained renderer. Apply the camera's new
        /// viewport before SceneKit's first frame at that size, not one display-link later.
        func synchronizeDailyViewportAfterLayout() {
            guard twoViewReadableFrameInWindow != nil, let view = scnView,
                  view.bounds.width > 0, view.bounds.height > 0 else { return }
            updateViewport(view.bounds.size)
            guard cameraMode == scene.currentCameraMode, !scene.isCameraModeTransitioning,
                  draggedNode == nil else { return }
            switch cameraMode {
            case .topDown2D:
                if autoFitsLandscapeTable { scene.cameraRig?.fitLandscapeTable(viewSize: view.bounds.size) }
                scene.cameraRig?.applyTopDown2D()
            case .topDown2DRotated:
                if autoFitsLandscapeTable { scene.cameraRig?.fitLandscapeTable(viewSize: view.bounds.size, rotated: true) }
                else if autoFitsRotatedTable { scene.cameraRig?.fitRotatedTable(viewSize: view.bounds.size) }
                scene.cameraRig?.applyTopDown2DRotated()
            case .perspective3D:
                scene.cameraRig?.update(deltaTime: 0)
            }
        }

        private var dailyProbeDeliveredFirstViewport = false

        func updateViewport(_ size: CGSize) {
            if DailyLayoutProbe.enabled, let view = scnView {
                var fields = DailyLayoutProbe.windowFields(view)
                fields["scene"] = String(describing: ObjectIdentifier(scene))
                fields["coordinator"] = String(describing: ObjectIdentifier(self))
                fields["viewport"] = DailyLayoutProbe.size(size)
                fields["readableFrame"] = twoViewReadableFrameInWindow.map { DailyLayoutProbe.rect($0) } ?? [:]
                fields["mode"] = String(describing: cameraMode)
                fields["sceneMode"] = String(describing: scene.currentCameraMode)
                fields["transitioning"] = scene.isCameraModeTransitioning
                fields["dragging"] = draggedNode != nil
                fields["rigPresent"] = scene.cameraRig != nil
                fields["effectiveViewport"] = size.width > 0 && size.height > 0 && view.window != nil && scene.cameraRig != nil
                DailyLayoutProbe.record("viewport.update", fields)
            }
            // The rig can be installed after makeUIView/first layout.
            scene.cameraRig?.viewportSize = size
            if let rig = scene.cameraRig, rig.usesTwoViewCameraControls,
               let scnView, scnView.window != nil, let frame = twoViewReadableFrameInWindow {
                let readable = scnView.convert(frame, from: nil).intersection(scnView.bounds)
                if !readable.isNull, !readable.isEmpty {
                    rig.setTwoViewReadableInsets(UIEdgeInsets(
                        top: readable.minY - scnView.bounds.minY,
                        left: readable.minX - scnView.bounds.minX,
                        bottom: scnView.bounds.maxY - readable.maxY,
                        right: scnView.bounds.maxX - readable.maxX))
                }
            }
            if DailyLayoutProbe.enabled, !dailyProbeDeliveredFirstViewport,
               size.width > 0, size.height > 0, let view = scnView,
               view.window != nil, let rig = scene.cameraRig {
                dailyProbeDeliveredFirstViewport = true
                var fields = DailyLayoutProbe.windowFields(view)
                fields["scene"] = String(describing: ObjectIdentifier(scene))
                fields["coordinator"] = String(describing: ObjectIdentifier(self))
                fields["rigViewport"] = DailyLayoutProbe.size(rig.viewportSize)
                DailyLayoutProbe.record("viewport.firstValid", fields)
            }
            guard size != lastViewportSize else { return }
            lastViewportSize = size
            // Layout changes must still refit a stationary 2D table.
            requestInteractiveFrames()
        }

        func updateContentActivity(_ animating: Bool?, cameraMode mode: AngleTrainingScene.CameraMode) {
            let changed = contentIsAnimating != animating || cameraMode != mode
            contentIsAnimating = animating
            cameraMode = mode
            // SceneKit invalidates changed nodes itself. Unrelated SwiftUI publications
            // must not extend the interactive window on a stationary table.
            if changed { requestInteractiveFrames() }
        }

        func requestInteractiveFrames() {
            interactiveUntil = CACurrentMediaTime() + 0.5
            updateFramePacing()
        }

        private func updateFramePacing() {
            guard let scnView, let displayLink else { return }
            let gestureActive = scnView.gestureRecognizers?.contains { $0.state == .began || $0.state == .changed } ?? false
            var active = (contentIsAnimating ?? true) || gestureActive || scene.isCameraModeTransitioning
                || (scene.cameraRig?.temporaryTopDownActive == true && scene.cameraRig?.usesMergedCamera != true)
                || (scene.cameraRig?.isTransitioning ?? false)
                || (cameraMode == .perspective3D && (scene.cameraRig?.hasPendingDamping ?? false))
                || CACurrentMediaTime() < interactiveUntil
            // Preserve SceneKit cue strokes, fades and selection pulses even when
            // the view model has no physics playback in progress.
            if !active {
                // Render-thread action completion may release SceneKit's action storage.
                // Read the graph and animation state under SceneKit's global transaction lock.
                SCNTransaction.lock()
                active = scene.rootNode.hasActions || !scene.rootNode.animationKeys.isEmpty
                if !active {
                    scene.rootNode.enumerateChildNodes { node, stop in
                        if node.hasActions || !node.animationKeys.isEmpty { active = true; stop.pointee = true }
                    }
                }
                SCNTransaction.unlock()
            }
            let wasActive = needsContinuousUpdates
            needsContinuousUpdates = active
            if let daily3DDiagnostics {
                daily3DDiagnostics.rendererState(active: active,
                    cameraMoving: scene.isCameraModeTransitioning
                        || (scene.cameraRig?.isTransitioning ?? false)
                        || (cameraMode == .perspective3D && (scene.cameraRig?.hasPendingDamping ?? false)))
            }
            if eventDrivenIdle {
                displayLink.isPaused = !active
                frameDelegate.watchesIdleInvalidation = !active
                if wasActive != active {
                    lastTimestamp = 0
                    updateFPSReadout(force: true)
                }
            }
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
            daily3DDiagnostics?.setRenderConfiguration(.init(
                selectedFPS: UserPreferences.shared.renderFrameRate.rawValue,
                scheduledFPS: fps,
                antialiasingSamples: Daily3DRenderDiagnostics.sampleCount(for: scnView.antialiasingMode),
                contentScale: Double(scnView.contentScaleFactor)))
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
        private var surfaceTouchOrigin: CGPoint?
        private var surfacePanLastLocation: CGPoint?
        private var surfaceAxisLock = SurfacePanAxisLock()
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
            frameDelegate.idleInvalidation = { [weak self] in
                guard let self, self.displayLink != nil else { return }
                self.frameDelegate.contact = self.scene.contactOcclusion
                if let view = self.scnView {
                    self.updateViewport(view.bounds.size)
                    self.updateTemporaryTopDownOverlay()
                    self.updateDiagramAnnotations()
                    #if DEBUG
                    // Static annotation invalidation also updates the UI-test probe;
                    // the display link may already be paused when results appear.
                    if self.dragProbeEnabled || self.pocketProbeEnabled { self.updatePocketAccessibility() }
                    #endif
                }
                self.updateFramePacing()
            }
        }

        private func updateDiagramAnnotations() {
            guard let view = scnView else { return }
            if let overlay = mergedOverlay {
                diagramLabels.hide()
                mergedDiagramLabels?.update(scene: scene, in: overlay, projectionMode: .topDown2D)
            } else {
                diagramLabels.update(scene: scene, in: view)
            }
        }

        func stopRenderLoop() {
            displayLink?.invalidate()
            displayLink = nil
            frameDelegate.watchesIdleInvalidation = false
            frameDelegate.idleInvalidation = nil
            lastTimestamp = 0
        }

        @objc private func renderUpdate(_ link: CADisplayLink) {
            displayLinkCallbackCount += 1
            daily3DDiagnostics?.displayLinkCallback()
            defer {
                updateDiagramAnnotations()
                #if DEBUG
                if dragProbeEnabled || pocketProbeEnabled { updatePocketAccessibility() }
                #endif
            }
            if let scnView { updateViewport(scnView.bounds.size) }
            updateTemporaryTopDownOverlay()
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
            // SwiftUI can deliver the new binding after the scene has already switched.
            // A stale 2D frame must not reacquire projection ownership over a 3D entry.
            if scene.cameraRig?.usesTwoViewCameraControls == true,
               cameraMode != scene.currentCameraMode { return }

            switch cameraMode {
            case .topDown2D:
                if autoFitsLandscapeTable, let scnView {
                    scene.cameraRig?.fitLandscapeTable(viewSize: scnView.bounds.size)
                }
                scene.cameraRig?.applyTopDown2D()
            case .topDown2DRotated:
                if autoFitsLandscapeTable, let scnView {
                    scene.cameraRig?.fitLandscapeTable(viewSize: scnView.bounds.size, rotated: true)
                } else if autoFitsRotatedTable, let scnView {
                    scene.cameraRig?.fitRotatedTable(viewSize: scnView.bounds.size)
                }
                scene.cameraRig?.applyTopDown2DRotated()
            case .perspective3D:
                scene.cameraRig?.update(deltaTime: dt)
                #if DEBUG
                if cameraObservationActive, let rig = scene.cameraRig,
                   let snapshot = rig.twoViewSnapshot, let camera = scene.cameraNode {
                    twoViewHeldSamples += 1
                    let pose = TwoViewCamera.Pose(eye: camera.simdWorldPosition,
                        orientation: camera.simdWorldOrientation,
                        fov: Float(camera.camera?.fieldOfView ?? 55))
                    let baseline = snapshot.defaultPose ?? snapshot.firstPersonBase ?? snapshot.pose
                    let movement = simd_length(pose.eye - baseline.eye)
                        + abs(simd_dot(pose.forward, baseline.forward) - 1)
                    // Surface default follows the current bearing, so peak distance cannot identify
                    // the release pose. Record the latest rendered held sample for this controller.
                    if snapshot.simpleShot?.surface != nil || movement > twoViewHeldPeak {
                        twoViewHeldPeak = movement
                        twoViewHeldPose = pose
                        twoViewHeldProgress = snapshot.progress
                        twoViewHeldYaw = snapshot.yaw
                    }
                }
                #endif
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
            if scene.cameraRig?.temporaryTopDownActive == true { handleOverlayPan(gesture); return }
            let surfacePan = scene.cameraRig?.usesSurfaceCamera == true
            if [.ended, .cancelled, .failed].contains(gesture.state), !surfacePan { finishCameraObservation() }
            defer {
                if surfacePan, [.ended, .cancelled, .failed].contains(gesture.state) {
                    finishCameraObservation()
                    surfacePanLastLocation = nil
                    surfaceTouchOrigin = nil
                }
            }
            #if DEBUG
            if dragProbeEnabled { dragProbePanCount += 1 }
            #endif
            if gesture.state == .began, gesturesEnabled, interactionMode != .none {
                daily3DDiagnostics?.input(.tablePan)
            } else if [.ended, .cancelled, .failed].contains(gesture.state) {
                daily3DDiagnostics?.setInteraction(.tablePan, stage: .orbit, active: false)
            }
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
                scene.cancelPocketSelectionFeedback()
                panDominantAxis = nil
                panCumX = 0
                panCumY = 0
                let current = gesture.location(in: scnView)
                let translation = gesture.translation(in: scnView)
                let location = surfacePan ? (surfaceTouchOrigin ?? current) : CGPoint(x: current.x - translation.x, y: current.y - translation.y)
                if let ball = hitTestBall(at: location) {
                    daily3DDiagnostics?.setInteraction(.tablePan, stage: .aim, active: true)
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
                    daily3DDiagnostics?.setInteraction(.tablePan, stage: .aim, active: true)
                    isAimFollowing = true
                    onAimDragActiveChanged?(true)
                    aimPivotScreen = cueBallScreenPoint()
                    lastAimTouch = location
                    return
                }
                if cameraMode == .perspective3D, interactionMode == .cameraControl {
                    daily3DDiagnostics?.setInteraction(.tablePan, stage: .orbit, active: true)
                }

            case .changed:
                if isAimFollowing {
                    let cur = gesture.location(in: scnView)
                    if let pivot = aimPivotScreen {
                        let deg = AngleSceneCalculator.aimNudgeDegrees(cueScreen: pivot, from: lastAimTouch, to: cur)
                        if deg != 0 {
                            onAimNudged?(deg)
                            #if DEBUG
                            if cameraMode != .perspective3D {
                                ordinary2DAimSamples += 1
                                if scene.cameraNode.camera?.usesOrthographicProjection != true {
                                    ordinary2DProjectionViolations += 1
                                }
                            }
                            #endif
                        }
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
                if scene.cameraRig?.usesTwoViewPoseControl == true, !surfacePan { return }


            default:
                break
            }

            guard draggedNode == nil, interactionMode == .cameraControl, let rig = scene.cameraRig else { return }
            let translation = gesture.translation(in: gesture.view)

            switch cameraMode {
            case .perspective3D:
                if rig.usesTwoViewPoseControl {
                    if rig.usesSurfaceCamera {
                        applySurfacePan(gesture, rig: rig)
                        return
                    }
                    guard gesture.state == .changed else {
                        gesture.setTranslation(.zero, in: gesture.view)
                        return
                    }
                    panCumX += translation.x
                    panCumY += translation.y
                    if panDominantAxis == nil,
                       max(abs(panCumX), abs(panCumY)) >= (rig.usesSimpleCueCamera ? 8 : panAxisLockThreshold),
                       max(abs(panCumX), abs(panCumY)) >= min(abs(panCumX), abs(panCumY)) * (rig.usesSimpleCueCamera ? 1.3 : 1.25) {
                        panDominantAxis = abs(panCumX) > abs(panCumY) ? .horizontal : .vertical
                    }
                    guard let axis = panDominantAxis else {
                        gesture.setTranslation(.zero, in: gesture.view)
                        return
                    }
                    if !cameraObservationActive {
                        cameraObservationActive = true
                        if let onCameraObservationBegan { onCameraObservationBegan() }
                        else { rig.prepareTemporaryObservation(cue: scene.cueBallNode?.position ?? SCNVector3Zero,
                            aim: rig.observationCandidates.last.map { $0 - (scene.cueBallNode?.position ?? SCNVector3Zero) } ?? SCNVector3(1, 0, 0)) }
                        #if DEBUG
                        twoViewHeldSamples = 0
                        twoViewHeldPeak = -.infinity
                        twoViewHeldPose = nil
                        twoViewGestureAxis = axis == .horizontal ? "horizontal" : "vertical"
                        #endif
                    }
                    let dx = axis == .horizontal ? Float(translation.x) : 0
                    let dy = axis == .vertical ? Float(translation.y) : 0
                    #if DEBUG
                    twoViewPanDX += dx
                    twoViewPanDY += dy
                    #endif
                    if dx != 0 {
                        if rig.usesSimpleCueCamera, !rig.usesSurfaceCamera, rig.twoViewMode == .thirdPerson,
                           let onThirdPersonAimNudged {
                            onThirdPersonAimNudged(dx * 64 / Float(max(1, scnView.bounds.width)))
                        } else { rig.handleHorizontalSwipe(delta: dx) }
                    }
                    if dy != 0 { rig.handleVerticalSwipe(delta: dy) }
                    gesture.setTranslation(.zero, in: gesture.view)
                    return
                }
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

        /// Lock to the first recognized pan direction, with no extra threshold.
        /// Keep the chosen axis until release; discard perpendicular finger drift.
        /// Deliver touch-down→began and the final ended sample exactly once.
        private func applySurfacePan(_ gesture: UIPanGestureRecognizer, rig: CameraRig) {
            guard let scnView, [.began, .changed, .ended].contains(gesture.state) else { return }
            let location = gesture.location(in: scnView)
            let previous = surfacePanLastLocation ?? surfaceTouchOrigin ?? location
            surfacePanLastLocation = location
            let delta = surfaceAxisLock.filter(SIMD2(Float(location.x - previous.x), Float(location.y - previous.y)))
            let dx = delta.x, dy = delta.y
            guard dx != 0 || dy != 0 else { return }
            if !cameraObservationActive {
                cameraObservationActive = true
                onCameraObservationBegan?()
                #if DEBUG
                twoViewHeldSamples = 0
                twoViewHeldPeak = -.infinity
                twoViewHeldPose = nil
                twoViewGestureAxis = surfaceAxisLock.axis == .horizontal ? "horizontal" : "vertical"
                #endif
            }
            #if DEBUG
            twoViewPanDX += dx
            twoViewPanDY += dy
            #endif
            rig.handleSurfacePan(delta: SIMD2(dx, dy))
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
            if [.ended, .cancelled, .failed].contains(gesture.state) { finishCameraObservation() }
            guard scene.cameraRig?.temporaryTopDownActive != true else { return }
            if gesture.state == .began, gesturesEnabled, interactionMode == .cameraControl,
               cameraMode == .perspective3D, draggedNode == nil {
                daily3DDiagnostics?.input(.tablePinch, intent: .orbit)
                daily3DDiagnostics?.setInteraction(.tablePinch, stage: .orbit, active: true)
            } else if [.ended, .cancelled, .failed].contains(gesture.state) {
                daily3DDiagnostics?.setInteraction(.tablePinch, stage: .orbit, active: false)
            }
            requestInteractiveFrames()
            guard gesturesEnabled, interactionMode != .none,
                  draggedNode == nil, let scnView, let rig = scene.cameraRig else { return }

            switch cameraMode {
            case .perspective3D:
                guard interactionMode == .cameraControl else { return }
                if rig.usesTwoViewPoseControl {
                    guard gesture.state == .changed, gesture.scale != 1,
                          rig.twoViewMode == .thirdPerson else { return }
                    if !cameraObservationActive {
                        cameraObservationActive = true
                        onCameraObservationBegan?()
                        #if DEBUG
                        twoViewHeldSamples = 0
                        twoViewHeldPeak = -.infinity
                        twoViewHeldPose = nil
                        twoViewGestureAxis = "pinch"
                        #endif
                    }
                }
                if gesture.state == .began, rig.usesShotAwareCamera, !rig.usesTwoViewPoseControl {
                    let centre = gesture.location(in: scnView)
                    let radius = min(scnView.bounds.width, scnView.bounds.height) * 0.22
                    let candidate = rig.observationCandidates.compactMap { point -> (SCNVector3, CGFloat)? in
                        let p = scnView.projectPoint(point)
                        guard p.z > 0, p.z < 1 else { return nil }
                        let distance = hypot(CGFloat(p.x) - centre.x, CGFloat(p.y) - centre.y)
                        return distance <= radius ? (point, distance) : nil
                    }.min { $0.1 < $1.1 }?.0
                    rig.beginObservationPinch(at: candidate)
                }
                if !rig.usesTwoViewPoseControl || gesture.scale != 1 {
                    rig.handlePinch(scale: Float(gesture.scale))
                }
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
                  let rig = scene.cameraRig, let scnView else { return }
            let location = gesture.location(in: scnView)
            guard hitTestBall(at: location) == nil else { return }
            guard !scene.allBallNodes.values.contains(where: {
                guard !$0.isHidden else { return false }
                let p = scnView.projectPoint(scene.visualCenter(of: $0))
                return p.z >= 0 && p.z <= 1 && hypot(location.x - CGFloat(p.x), location.y - CGFloat(p.y)) < 40
            }) else { return }
            let pockets = AngleSceneCalculator.pocketMarkerPositions(surfaceY: scene.surfaceY)
            guard !pockets.contains(where: {
                let p = scnView.projectPoint($0)
                return hypot(location.x - CGFloat(p.x), location.y - CGFloat(p.y)) < 44
            }) else { return }
            scene.cancelPocketSelectionFeedback()
            rig.resetTopDownZoom()
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            if scene.cameraRig?.temporaryTopDownActive == true {
                if let view = scnView { handleOverlayTap(gesture.location(in: view)) }
                return
            }
            if gesturesEnabled, interactionMode != .none {
                daily3DDiagnostics?.input(.tableTap, intent: .aim)
            }
            requestInteractiveFrames()
            guard let scnView else { return }
            handleTap(at: gesture.location(in: scnView))
        }

        func handleTap(at location: CGPoint) {
            guard gesturesEnabled, interactionMode != .none, let scnView else { return }
            selectedDragBall = hitTestBall(at: location)

            // Resolve the actual visible mesh before enlarging either hit area.
            // A visible leather rim wins over a nearby ball's 40pt tolerance.
            let hitResults = scnView.hitTest(location, options: [
                .searchMode: SCNHitTestSearchMode.closest.rawValue
            ])
            if let front = hitResults.first {
                var node: SCNNode? = front.node
                while let current = node {
                    if scene.ballKey(for: current) != nil {
                        if selectableBallNodes.contains(current) { onBallTapped?(current) }
                        return // A cue/forbidden ball also occludes the pocket behind it.
                    }
                    node = current.parent
                }
                if let index = PocketLeatherMarker.index(of: front.node), let onPocketTapped {
                    onPocketTapped(index); return
                }
            }
            if let onBallTapped, !selectableBallNodes.isEmpty {
                let tapRadius: CGFloat = 40
                var best: SCNNode?
                var bestDist: CGFloat = .greatestFiniteMagnitude
                for ball in selectableBallNodes {
                    let center = scene.visualCenter(of: ball)
                    let projected = scnView.projectPoint(center)
                    guard projected.z >= 0, projected.z <= 1 else { continue }
                    let screenPos = CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
                    guard scnView.bounds.contains(screenPos) else { continue }
                    if cameraMode == .perspective3D, let camera = scnView.pointOfView,
                       let front = scnView.hitTest(screenPos, options: [.searchMode: SCNHitTestSearchMode.closest.rawValue]).first,
                       camera.convertPosition(front.worldCoordinates, from: nil).z >
                        camera.convertPosition(center, from: nil).z + AngleSceneCalculator.ballRadius { continue }
                    let dist = hypot(location.x - screenPos.x, location.y - screenPos.y)
                    if dist < tapRadius, dist < bestDist { bestDist = dist; best = ball }
                }
                if let best { onBallTapped(best); return }
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
        private let dragProbeRendererID = UUID().uuidString
        private var dragProbePanCount = 0
        private var dragProbeGrabCount = 0
        private var dragProbeMoveCount = 0
        private let dragProbeEnabled = ProcessInfo.processInfo.arguments.contains("-3dDrag.probe")
        private let pocketProbeEnabled = ProcessInfo.processInfo.arguments.contains("-pocketSelection.probe")
        private func dragProbeValue(in view: SCNView) -> String {
            let balls: [[String: Any]] = scene.allBallNodes.sorted { $0.key < $1.key }.compactMap { key, node in
                guard !node.isHidden else { return nil }
                let world = scene.visualCenter(of: node)
                let p = view.projectPoint(world)
                let active = usesStandardTemporaryTable && scene.cameraRig?.temporaryTopDownActive == true
                    ? editingPoint(world) : nil
                return ["key": key, "screen": [Float(active?.x ?? CGFloat(p.x)), Float(active?.y ?? CGFloat(p.y)), p.z],
                        "world": [node.position.x, node.position.y, node.position.z],
                        "draggable": draggableBallNodes.contains(node)]
            }
            let transform = view.pointOfView?.worldTransform ?? SCNMatrix4Identity
            var data: [String: Any] = ["rendererID": dragProbeRendererID, "panCount": dragProbePanCount, "grabCount": dragProbeGrabCount, "moveCount": dragProbeMoveCount, "balls": balls, "camera": [transform.m11, transform.m12, transform.m13,
                transform.m21, transform.m22, transform.m23, transform.m31, transform.m32, transform.m33,
                transform.m41, transform.m42, transform.m43]]
            if let overlay = mergedOverlay, let labels = mergedDiagramLabels {
                data["diagram"] = labels.diagnostic(in: overlay, scene: scene)
                data["diagramSurface"] = "temporaryTopDown"
            } else {
                data["diagram"] = diagramLabels.diagnostic(in: view, scene: scene)
                data["diagramSurface"] = "main"
            }
            let displayed = mergedOverlay ?? view
            if let rig = scene.cameraRig {
                let corners = [-1.0, 1.0].flatMap { x in [-1.0, 1.0].map { z in
                    displayed.projectPoint(SCNVector3(Float(x * rig.tableOuterHalfLength), scene.surfaceY,
                        Float(z * rig.tableOuterHalfWidth)))
                }}
                let points = corners.map { displayed.convert(CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)), to: nil) }
                data["displayedTable"] = [points.map(\.x).min()!, points.map(\.y).min()!,
                    points.map(\.x).max()!, points.map(\.y).max()!]
            }
            data["pockets"] = AngleSceneCalculator.pocketMarkerPositions(surfaceY: scene.surfaceY).enumerated().compactMap { index, world -> [String: Any]? in
                guard let p = editingPoint(world) else { return nil }
                return ["index": index, "screen": [p.x, p.y]]
            }
            data["cueVisible"] = scene.cueStick?.rootNode.isHidden == false
            data["standardTemporaryTable"] = mergedOverlay != nil && usesStandardTemporaryTable
            let renderedFrame = displayed.convert(displayed.bounds, to: nil)
            data["displayedViewport"] = [renderedFrame.minX, renderedFrame.minY, renderedFrame.width, renderedFrame.height]
            data["hasMeasuredStage"] = twoViewReadableFrameInWindow != nil
            if DailyLayoutProbe.enabled { data["dailyLayout"] = DailyLayoutProbe.snapshot() }
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
            if ProcessInfo.processInfo.arguments.contains("-renderProfileProbe") {
                var seen=Set<ObjectIdentifier>(),reflection=0,shadow=0
                scene.rootNode.enumerateHierarchy { node, _ in
                    for material in node.geometry?.materials ?? [] where seen.insert(ObjectIdentifier(material)).inserted {
                        let shader=material.shaderModifiers?[.surface] ?? ""
                        if shader.contains("// v2SplitSum") { reflection += 1 }
                        if shader.contains("// v2AnalyticShadow") { shadow += 1 }
                    }
                }
                scnView.accessibilityValue = (scnView.accessibilityValue ?? "") + " reflection=\(reflection) shadow=\(shadow) 调度=\(needsContinuousUpdates ? "活动" : "静止")"
            }
            if pocketProbeEnabled {
                let pockets: [[String: Any]] = scene.addPocketMarkers().compactMap { node in
                    guard let marker = node as? PocketLeatherMarker else { return nil }
                    let points = AngleSceneCalculator.pocketMarkerPositions(surfaceY: scene.surfaceY)
                    let p = scnView.projectPoint(points[marker.pocketIndex])
                    let pulse = marker.childNode(withName: "leather_selectionPulse", recursively: true)
                    return ["index": marker.pocketIndex, "screen": [p.x, p.y, p.z],
                        "style": marker.style.rawValue, "yellow": pulse?.opacity ?? 0,
                        "pending": pulse?.hasActions ?? false]
                }
                let data: [String: Any] = ["selection": scene.pocketSelectionDescription, "pockets": pockets,
                    "viewport": [scnView.bounds.width, scnView.bounds.height]]
                if let encoded = try? JSONSerialization.data(withJSONObject: data) {
                    scnView.accessibilityValue = String(decoding: encoded, as: UTF8.self)
                }
            }
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

/// Layout callback is only consumed for the daily page's measured readable viewport.
private final class LayoutAwareSceneView: SCNView {
    var onLayout: (() -> Void)?
    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}

/// The recognizer supplies touch-down→began displacement first. It already applies
/// its recognition threshold, so a second threshold would discard short gestures.
struct SurfacePanAxisLock {
    enum Axis { case horizontal, vertical }
    private(set) var axis: Axis?

    mutating func filter(_ delta: SIMD2<Float>) -> SIMD2<Float> {
        guard delta.x.isFinite, delta.y.isFinite, delta != .zero else { return .zero }
        if axis == nil {
            // Exact diagonal ties pick horizontal instead of waiting indefinitely.
            axis = abs(delta.x) >= abs(delta.y) ? .horizontal : .vertical
        }
        return axis == .horizontal ? SIMD2(delta.x, 0) : SIMD2(0, delta.y)
    }
}

// MARK: - Pan arbitration against ancestor scroll views

extension AngleSceneView.Coordinator: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Called at touch-down, before pan recognition or tap release. A new hand
        // interaction invalidates the previous delayed acknowledgement immediately.
        scene.cancelPocketSelectionFeedback()
        if gestureRecognizer === panGesture, scene.cameraRig?.usesSurfaceCamera == true, let scnView {
            surfaceTouchOrigin = touch.location(in: scnView)
            surfacePanLastLocation = nil
            surfaceAxisLock = SurfacePanAxisLock()
        }
        if gestureRecognizer === panGesture, scene.cameraRig?.usesMergedCamera == true,
           scene.cameraRig?.temporaryTopDownActive == true, let scnView {
            mergedTouchOrigin = touch.location(in: scnView)
        }
        return true
    }
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
@MainActor
final class TableFPSReadoutState: ObservableObject {
    @Published private(set) var text = "— FPS"
    func publish(_ value: String) { if text != value { text = value } }
}

private struct FPSReadout: View {
    let text: String
    var compact = false
    var suppressed = false
    var body: some View {
        if suppressed {
            // Keep only the diagnostic hosting anchor; do not retain a second AX readout.
            Color.clear.frame(width: 1, height: 1).accessibilityHidden(true)
        } else {
        Text(compact && text == "FPS · 静止" ? "静止" : text)
            .font(compact ? .system(size: 10) : .btCaption2).monospacedDigit().fixedSize()
            .foregroundStyle(Color.btTextSecondary)
            .padding(.horizontal, compact ? 0 : Spacing.sm).padding(.vertical, Spacing.xs)
            .background(compact ? Color.clear : Color.btBGSecondary.opacity(0.85), in: Capsule())
            .environment(\.colorScheme, .dark)
            .accessibilityLabel("渲染帧率，" + text)
            .accessibilityIdentifier("table.renderFPS")
        }
    }
}

/// SceneKit invokes delegates off the main thread; the counter and forwarding
/// target are protected together. UI updates remain on the coordinator's main loop.
class FrameDelegate: NSObject, SCNSceneRendererDelegate {
    private let lock = NSLock()
    private var frames = 0
    private var watchesIdle = false
    private var invalidationPending = false
    private var idleCallback: (@MainActor () -> Void)?
    var watchesIdleInvalidation: Bool {
        get { lock.lock(); defer { lock.unlock() }; return watchesIdle }
        set { lock.lock(); watchesIdle = newValue; lock.unlock() }
    }
    var idleInvalidation: (@MainActor () -> Void)? {
        get { lock.lock(); defer { lock.unlock() }; return idleCallback }
        set { lock.lock(); idleCallback = newValue; lock.unlock() }
    }
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
        lock.lock()
        frames += 1
        let notify = watchesIdle && !invalidationPending && idleCallback != nil
        if notify { invalidationPending = true }
        lock.unlock()
        if notify {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.lock.lock()
                self.invalidationPending = false
                let callback = self.idleCallback
                self.lock.unlock()
                callback?()
            }
        }
        #if DEBUG
        contact?.renderer(renderer, didRenderScene: scene, atTime: time)
        #endif
    }
}

/// Screen-space labels keep world anchors, but reserve their complete readable footprint.
/// Only the interactive angle diagram opts in. This overlay never intercepts table gestures.
@MainActor
final class DiagramLabelOverlay {
    /// Screen points; shared by the drawn arc, label clearance and diagnostics.
    static let angleArcRadius: CGFloat = 28
    private var labels: [UILabel] = []
    private let angleMark = CAShapeLayer()
    private var choices: [Int: Int] = [:]
    private var geometryKey: [Float] = []
    private var previousAngleOffset: CGPoint?

    func hide() {
        labels.forEach { $0.isHidden = true }
        angleMark.isHidden = true
        geometryKey = []
        previousAngleOffset = nil
    }

    func update(scene: AngleTrainingScene, in view: SCNView,
                projectionMode: AngleTrainingScene.CameraMode? = nil) {
        let displayMode = projectionMode ?? scene.currentCameraMode
        guard scene.usesAdaptiveDiagramLabels, let g = scene.diagramLabelGeometry,
              view.bounds.width > 0, view.bounds.height > 0 else {
            hide()
            return
        }
        if view.scene === scene {
            scene.angleArcNode?.childNodes.filter { $0.name == "diagramTableArc" }.forEach {
                $0.isHidden = displayMode != .perspective3D
            }
        }
        // Camera projection and ball positions are the complete layout input. Avoid per-frame
        // text measurement/candidate searches while the table and camera are stationary.
        let matrix = scene.cameraNode?.presentation.worldTransform ?? SCNMatrix4Identity
        let visible = scene.allBallNodes.values.filter { !$0.isHidden }
        let key: [Float] = [matrix.m11, matrix.m12, matrix.m13, matrix.m21, matrix.m22, matrix.m23,
            matrix.m31, matrix.m32, matrix.m33, matrix.m41, matrix.m42, matrix.m43,
            Float(view.bounds.width), Float(view.bounds.height), scene.diagramShowsLineLabels ? 1 : 0,
            displayMode == .perspective3D ? 1 : 0,
            Float(scene.cameraNode?.camera?.orthographicScale ?? 0),
            g.cue.x, g.cue.z, g.target.x, g.target.z, g.pocket.x, g.pocket.z,
            Float(scene.currentTargetNumber ?? 0), Float(scene.cameraNode?.camera?.fieldOfView ?? 0)]
            + visible.sorted { ($0.name ?? "") < ($1.name ?? "") }.flatMap { [$0.position.x, $0.position.z] }
        // SceneKit can commit its viewport/projection after the camera model has settled.
        // Cache the actual projected anchors too: an unchanged model matrix does not prove
        // that projectPoint is still mapping the cloth to the same screen coordinates.
        let projectedKey = [g.cue, g.target, g.ghost, g.pocket, g.rail].flatMap { point -> [Float] in
            let projected = view.projectPoint(point)
            return [projected.x, projected.y, projected.z]
        }
        let completeKey = key + projectedKey
        guard completeKey != geometryKey else { return }
        geometryKey = completeKey
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
        let labelCount = scene.diagramShowsLineLabels ? 3 : 1
        labels.dropFirst(labelCount).forEach { $0.isHidden = true }
        for index in 0..<labelCount {
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
                for clearance: CGFloat in [20, 26, 32] {
                    let distance = Self.angleArcRadius + clearance
                    for fraction: CGFloat in [0.5, 0.35, 0.65] {
                        let direction = a + sweep * fraction
                        candidates.append(CGPoint(x: ghost.x + cos(direction)*distance,
                                                  y: ghost.y + sin(direction)*distance))
                    }
                }
                for offset: CGFloat in [30, 45, 60, 75, 90] {
                    for clearance: CGFloat in [20, 26, 32] {
                        let distance = Self.angleArcRadius + clearance
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
            let arcRadius = Self.angleArcRadius
            let path = UIBezierPath()
            if displayMode == .perspective3D {
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

    #if DEBUG
    /// Actual rendered path versus current SceneKit projection, for native regression checks.
    func diagnostic(in view: SCNView, scene: AngleTrainingScene) -> [String: Any] {
        guard let g = scene.diagramLabelGeometry else { return [:] }
        let cue = view.projectPoint(g.cue), ghost = view.projectPoint(g.ghost)
        let angle = atan2(CGFloat(ghost.y - cue.y), CGFloat(ghost.x - cue.x))
        let expected = CGPoint(x: CGFloat(ghost.x) + cos(angle) * Self.angleArcRadius,
                               y: CGFloat(ghost.y) + sin(angle) * Self.angleArcRadius)
        var firstPoint: CGPoint?
        angleMark.path?.applyWithBlock { element in
            if firstPoint == nil, element.pointee.type == .moveToPoint {
                firstPoint = element.pointee.points[0]
            }
        }
        var result: [String: Any] = ["ghost": [ghost.x, ghost.y],
            "expectedArcStart": [expected.x, expected.y], "arcRadiusPoints": Self.angleArcRadius,
            "arcHidden": angleMark.isHidden]
        if let firstPoint { result["arcStart"] = [firstPoint.x, firstPoint.y] }
        if let label = labels.first {
            result["labelCenter"] = [label.center.x, label.center.y]
            result["labelFontSize"] = label.font.pointSize
            result["labelHidden"] = label.isHidden
        }
        return result
    }
    #endif

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
