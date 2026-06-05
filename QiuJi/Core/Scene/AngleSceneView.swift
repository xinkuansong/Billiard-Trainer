import SwiftUI
import SceneKit

/// UIViewRepresentable wrapper for SceneKit angle training.
/// Manages gesture recognition and CADisplayLink render loop.
/// Supports ball dragging (for AngleDynamicView) and pocket tapping.
struct AngleSceneView: UIViewRepresentable {
    /// Camera/touch interaction policy.
    /// - `cameraControl`: full pan/pinch on camera (used by 3D观察).
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
    /// SCNView 背景色。默认黑（3D 角度页用）；2D 顶视球桌（详情页）传台呢绿，
    /// 让相机取景与相框比例不完全吻合时残留的极小边缘融入而非露出黑边。
    var backgroundColor: UIColor = .black
    var onPocketTapped: ((Int) -> Void)?

    var draggableBallNodes: [SCNNode] = []
    var onDragBegan: ((SCNNode) -> Void)?
    var onDragMoved: ((SCNNode, SCNVector3) -> Void)?
    var onDragEnded: ((SCNNode) -> Void)?

    /// 可点选的球（走位编排器点选目标球）。tap 命中其一即回调，优先于袋口判定。
    var selectableBallNodes: [SCNNode] = []
    var onBallTapped: ((SCNNode) -> Void)?

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = scene
        if let cam = scene.cameraNode {
            scnView.pointOfView = cam
        }
        scnView.allowsCameraControl = false
        scnView.antialiasingMode = .multisampling4X
        // 跟随屏幕原生刷新率（ProMotion 120Hz）。回放用逐帧解析求位，渲染帧率越高越顺滑；
        // 旧值硬封顶 60fps 在 120Hz 屏上每帧显示两次刷新，正是减速段残留的卡顿来源。
        scnView.preferredFramesPerSecond = UIScreen.main.maximumFramesPerSecond
        scnView.isPlaying = true
        scnView.backgroundColor = backgroundColor

        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.maximumNumberOfTouches = 1
        scnView.addGestureRecognizer(panGesture)

        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        scnView.addGestureRecognizer(pinchGesture)

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)

        context.coordinator.scnView = scnView
        context.coordinator.startRenderLoop()

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        if uiView.pointOfView !== scene.cameraNode, let cam = scene.cameraNode {
            uiView.pointOfView = cam
        }
        if uiView.backgroundColor != backgroundColor {
            uiView.backgroundColor = backgroundColor
        }
        context.coordinator.cameraMode = cameraMode
        context.coordinator.interactionMode = interactionMode
        context.coordinator.locksCueBallScreenAnchor = locksCueBallScreenAnchor
        context.coordinator.onPocketTapped = onPocketTapped
        context.coordinator.draggableBallNodes = draggableBallNodes
        context.coordinator.onDragBegan = onDragBegan
        context.coordinator.onDragMoved = onDragMoved
        context.coordinator.onDragEnded = onDragEnded
        context.coordinator.selectableBallNodes = selectableBallNodes
        context.coordinator.onBallTapped = onBallTapped
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(scene: scene, cameraMode: cameraMode, interactionMode: interactionMode)
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        coordinator.stopRenderLoop()
        uiView.isPlaying = false
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {
        let scene: AngleTrainingScene
        var cameraMode: AngleTrainingScene.CameraMode
        var interactionMode: InteractionMode
        var locksCueBallScreenAnchor = false
        var onPocketTapped: ((Int) -> Void)?
        weak var scnView: SCNView?
        private var displayLink: CADisplayLink?
        private var lastTimestamp: CFTimeInterval = 0
        var gesturesEnabled = true

        var draggableBallNodes: [SCNNode] = []
        var onDragBegan: ((SCNNode) -> Void)?
        var onDragMoved: ((SCNNode, SCNVector3) -> Void)?
        var onDragEnded: ((SCNNode) -> Void)?
        var selectableBallNodes: [SCNNode] = []
        var onBallTapped: ((SCNNode) -> Void)?
        private var draggedNode: SCNNode?

        /// Dominant axis lock for 3D camera-pan gestures. Once decided
        /// (when cumulative motion crosses `panAxisLockThreshold`), the
        /// other axis's deltas are dropped for the rest of the gesture.
        /// Eliminates "vertical drag also rotates yaw" cross-axis bleed.
        private enum PanAxis { case horizontal, vertical }
        private var panDominantAxis: PanAxis?
        private var panCumX: CGFloat = 0
        private var panCumY: CGFloat = 0
        private let panAxisLockThreshold: CGFloat = 12

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
            // 允许跑到屏幕最高刷新率（ProMotion 120Hz），与 SCNView 渲染同步，避免回放被限到 60fps。
            let maxFPS = Float(UIScreen.main.maximumFramesPerSecond)
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: maxFPS, preferred: maxFPS)
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        func stopRenderLoop() {
            displayLink?.invalidate()
            displayLink = nil
            lastTimestamp = 0
        }

        @objc private func renderUpdate(_ link: CADisplayLink) {
            let dt: Float
            if lastTimestamp == 0 {
                dt = Float(1.0 / 60.0)
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

            guard !scene.isCameraModeTransitioning else { return }

            switch cameraMode {
            case .topDown2D:
                scene.cameraRig?.applyTopDown2D()
            case .topDown2DRotated:
                scene.cameraRig?.applyTopDown2DRotated()
            case .perspective3D:
                scene.cameraRig?.update(deltaTime: dt)
                // Skip anchor-lock while a smooth pose transition (e.g. 观察⇄瞄准
                // toggle) is in flight: the smooth interpolator is already
                // driving the pivot toward the cue ball, and a competing
                // per-frame translatePivot would fight it and cause wobble.
                let rigBusy = scene.cameraRig?.isTransitioning ?? false
                if locksCueBallScreenAnchor,
                   !rigBusy,
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

        private func hitTestBall(at location: CGPoint) -> SCNNode? {
            guard let scnView, !draggableBallNodes.isEmpty else { return nil }

            let hitResults = scnView.hitTest(location, options: [
                .searchMode: SCNHitTestSearchMode.all.rawValue,
                .boundingBoxOnly: true
            ])

            for hit in hitResults {
                if draggableBallNodes.contains(hit.node) {
                    return hit.node
                }
                if let parent = hit.node.parent, draggableBallNodes.contains(parent) {
                    return parent
                }
            }

            let hitRadius: CGFloat = 30
            for ball in draggableBallNodes {
                let projected = scnView.projectPoint(ball.position)
                let screenPos = CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
                let dist = hypot(location.x - screenPos.x, location.y - screenPos.y)
                if dist < hitRadius {
                    return ball
                }
            }

            return nil
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

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard gesturesEnabled, interactionMode != .none, let scnView else { return }

            switch gesture.state {
            case .began:
                panDominantAxis = nil
                panCumX = 0
                panCumY = 0
                let location = gesture.location(in: scnView)
                if let ball = hitTestBall(at: location) {
                    draggedNode = ball
                    onDragBegan?(ball)
                    return
                }
                draggedNode = nil

            case .changed:
                if let ball = draggedNode {
                    let location = gesture.location(in: scnView)
                    let planeY = scene.surfaceY + AngleSceneCalculator.ballRadius
                    guard let worldPos = unprojectToTablePlane(screenPoint: location, in: scnView, planeY: planeY) else { return }
                    onDragMoved?(ball, worldPos)
                    return
                }

            case .ended, .cancelled:
                panDominantAxis = nil
                panCumX = 0
                panCumY = 0
                if let ball = draggedNode {
                    onDragEnded?(ball)
                    draggedNode = nil
                    return
                }

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
                rig.applyCameraPan(translationX: -Float(translation.x),
                                   translationZ: -Float(translation.y))
            }
            gesture.setTranslation(.zero, in: gesture.view)
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard gesturesEnabled, interactionMode == .cameraControl,
                  draggedNode == nil, let rig = scene.cameraRig else { return }

            switch cameraMode {
            case .perspective3D:
                rig.handlePinch(scale: Float(gesture.scale))
            case .topDown2D, .topDown2DRotated:
                rig.applyTopDownAreaZoom(scale: Float(gesture.scale))
            }
            gesture.scale = 1.0
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesturesEnabled, interactionMode != .none, let scnView else { return }
            let location = gesture.location(in: scnView)

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

            // Try precise hit-test first against pocket marker planes by name.
            let hitResults = scnView.hitTest(location, options: [
                .searchMode: SCNHitTestSearchMode.all.rawValue
            ])
            for hit in hitResults {
                if let name = hit.node.name, name.hasPrefix("pocketMarker_"),
                   let index = pocketIndex(from: name) {
                    onPocketTapped?(index)
                    return
                }
            }

            // Fallback: project pocket positions to screen and pick the nearest within radius.
            let pocketPositions = AngleSceneCalculator.pocketPositions(surfaceY: scene.surfaceY)
            let tapRadius: CGFloat = 44
            var bestIndex: Int?
            var bestDist: CGFloat = .greatestFiniteMagnitude
            for (index, pos) in pocketPositions.enumerated() {
                let projected = scnView.projectPoint(pos)
                let screenPos = CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
                let dist = hypot(location.x - screenPos.x, location.y - screenPos.y)
                if dist < tapRadius, dist < bestDist {
                    bestDist = dist
                    bestIndex = index
                }
            }
            if let bestIndex {
                onPocketTapped?(bestIndex)
            }
        }

        private func pocketIndex(from name: String) -> Int? {
            let parts = name.split(separator: "_")
            guard parts.count == 2 else { return nil }
            return Int(parts[1])
        }
    }
}
