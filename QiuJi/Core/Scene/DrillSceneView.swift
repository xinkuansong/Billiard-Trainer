import SwiftUI
import SceneKit

/// 详情页用的 live「USDZ 球桌 2D 顶视」场景：与角度页同一套 `AngleTrainingScene`
/// （`TaiQiuZhuo.usdz` 台呢 + 抽取球节点 + plain 光照），切正交顶视相机，按 drill 摆球。
///
/// 首帧与列表缩略图共用 `DrillStaticPreview`（代表性球形 · 真球号 · 杆 · 线语言 v2 · ghost）。
/// 回放由 `TrajectoryPlayback` 按物理记录驱动全桌球；无可行预测时退回手画折线。
///
/// ⚠️ 仅用于单个全屏/横幅场景。列表缩略图请用离线烘焙 PNG（`BTBakedDrillTable`）。
@MainActor
final class DrillSceneController: ObservableObject {
    let scene = AngleTrainingScene()
    var cameraMode: AngleTrainingScene.CameraMode = .topDown2D

    /// 本杆「打点 + 力度」HUD 条数据（逐杆更新为当前杆参数）。
    struct ShotOverlayData {
        let spinX: Double      // +左塞 / −右塞
        let spinY: Double      // +高杆 / −低杆
        let velocity: Double   // 杆头速度 m/s
    }
    @Published var overlayData: ShotOverlayData?
    @Published var showOverlay = false

    /// 相框/正交取景与 `DrillSceneView` 必须一致，否则世界→屏幕映射会偏。
    static let frameAspect: Double = 1.81

    private var didSetup = false
    private var didPlaceBoard = false
    private var drill: DrillContent?
    private var previewSource: DrillStaticPreview.Source?
    private var prediction: ShotPrediction?
    /// 整条示范序列（与静帧同一 formation）。为空 = 无多杆数据，退回单杆演示。
    private var steps: [SequenceStep] = []
    private var stepIndex = 0
    private var homePositions: [String: SCNVector3] = [:]
    private var surfaceY: Float = 0
    private var trajectoryNodes: [SCNNode] = []

    /// 演示播放状态机。
    ///
    /// F-SC-01 原为「回放不可打断」（按钮 disabled、不给 stop 图标以免假 affordance）；
    /// 序列演示可长达数十秒，现放开为**杆边界可暂停**：暂停请求不打断当前杆，
    /// 当前杆完整播完后停在该杆结果盘面，再点继续从下一杆接上。
    /// 因为暂停此刻是真行动，pause 图标不再是假 affordance。
    enum PlaybackState {
        case idle
        /// 正在演示。
        case playing
        /// 已请求暂停，等当前杆播完（此期间仍在播，可再点取消）。
        case pausingAfterShot
        /// 停在某杆结果盘面，等待继续。
        case paused
    }
    @Published private(set) var playbackState: PlaybackState = .idle

    /// 演示进行中（含「等当前杆播完」）：用于拦截已排期的异步回调。
    var isPlaying: Bool {
        playbackState == .playing || playbackState == .pausingAfterShot
    }

    /// 开场三拍（与 `SequenceVideoExporter.Options.teachingVideo()` 同节奏）：
    /// 「读球形」只摆球 → 「亮方案」预告线 + 假想球 + 瞄准位杆 → 「执行」运杆出杆。
    private let observeHold: TimeInterval = 1.5
    private let setupHold: TimeInterval = 1.5
    /// 序列后续杆的亮方案定格：与试打页 `runSequenceStep` 的 0.4s 同量级，
    /// 不用首杆的 1.5s，否则多杆序列整体拖沓。
    private let followUpSetupHold: TimeInterval = 0.45
    /// 杆间停顿：与 `PositionPlayViewModel.sequenceInterShotPause` 同值。
    private let interShotPause: TimeInterval = 0.7

    func setup(drill: DrillContent) {
        guard !didSetup else { return }
        didSetup = true
        self.drill = drill

        scene.setupScene(enhancedRendering: false)
        surfaceY = scene.surfaceY

        // 物理求解放后台；回主线程画与缩略图同契约的静帧。
        guard let source = DrillStaticPreview.resolveSource(for: drill) else { return }
        previewSource = source
        let solveSurfaceY = surfaceY

        // 整条示范序列：必须取 `resolveSource` 选中的同一 formation（按 token 命中），
        // 否则静帧球形与回放序列会分属不同球形而对不上。
        steps = DrillTryoutBoardStore.formations(for: drill.id)
            .first(where: { $0.token == source.token })?.steps ?? []

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let pred = PositionPlayShotSolver.solve(
                before: source.board, shot: source.shot, surfaceY: solveSurfaceY
            )
            DispatchQueue.main.async {
                guard let self else { return }
                self.prediction = pred
                self.applyPreviewFrame()
            }
        }
    }

    /// 应用与缩略图同契约的静帧（球 + 线 + ghost + 杆）。
    private func applyPreviewFrame() {
        guard let source = previewSource else { return }
        clearTrajectory()
        scene.ghostBallNode?.isHidden = true
        scene.hideContactDot()
        scene.hideCueStick()

        let applied = DrillStaticPreview.apply(
            source: source, to: scene, options: .detail,
            prediction: prediction, placeBalls: !didPlaceBoard
        )
        didPlaceBoard = true
        trajectoryNodes = applied.trajectoryNodes
        if let pred = applied.prediction, pred.feasible {
            prediction = pred
        }

        if homePositions.isEmpty {
            for (key, pt) in source.board.onTable {
                let p = AngleSceneCalculator.normalizedToScene(
                    point: CGPoint(x: pt.x, y: pt.y), surfaceY: surfaceY
                )
                homePositions[key] = p
            }
        }

        // 静帧只备好数据不显示：HUD 仅在播放期间可见（点播放前后都隐藏）。
        overlayData = ShotOverlayData(
            spinX: applied.spinX, spinY: applied.spinY, velocity: applied.velocity
        )
    }

    /// 播放按钮单一入口：空闲开播 / 播放中请求暂停 / 暂停中继续 / 撤销暂停请求。
    func togglePlayback() {
        switch playbackState {
        case .idle:
            play()
        case .playing:
            playbackState = .pausingAfterShot
        case .pausingAfterShot:
            playbackState = .playing
        case .paused:
            resume()
        }
    }

    /// 从暂停处继续：接着下一杆演示（当前杆已在暂停时播完）。
    private func resume() {
        guard playbackState == .paused, !steps.isEmpty else { return }
        playbackState = .playing
        showOverlay = overlayData != nil
        let next = stepIndex + 1
        guard next < steps.count else { finishPlayback(); return }
        runStep(next)
    }

    /// 播放整条示范序列：开场「读球形」一拍后逐杆演示，杆间停顿衔接，全部走完才收尾。
    /// HUD 条自点播放起常显（逐杆更新为当前杆参数），整条序列播完才隐藏。
    func play() {
        guard !isPlaying, scene.cueBallNode != nil else { return }
        playbackState = .playing
        stepIndex = 0
        restoreHomePositions(clearActions: true)

        // 第 1 拍·读球形：撤掉预告线 / 假想球 / 球杆，只留球形供观察。
        hidePlanDecorations()
        scene.hideCueStick()

        // HUD 随播放开始出现，并预置首杆参数。
        updateOverlay(shot: steps.first?.shot ?? previewSource?.shot)
        showOverlay = overlayData != nil

        DispatchQueue.main.asyncAfter(deadline: .now() + observeHold) { [weak self] in
            guard let self, self.isPlaying else { return }
            self.runStep(0)
        }
    }

    /// 逐杆演示的一杆：摆该杆击球前盘面 → 亮方案（线 + 假想球 + 瞄准位杆）→ 定格 → 运杆出杆。
    /// 与试打页 `PositionPlayViewModel.runSequenceStep` 同结构、同 `CueStroke` 运动学。
    private func runStep(_ i: Int) {
        guard isPlaying else { return }
        // 无多杆数据（shotIntent / animation 类）退回单杆演示。
        guard !steps.isEmpty else { startSingleShot(); return }
        guard i < steps.count else { finishPlayback(); return }

        stepIndex = i
        let step = steps[i]
        placeStepBoard(step.before)
        updateOverlay(shot: step.shot)

        guard let pred = PositionPlayShotSolver.solve(
                  before: step.before, shot: step.shot, surfaceY: surfaceY
              ), pred.feasible,
              let recorder = pred.recorder, pred.duration > 0.05,
              let cueNode = scene.allBallNodes[PositionPlayBall.cueKey], !cueNode.isHidden,
              let aim = DrillStaticPreview.aimDirection(path: pred.cuePath, from: cueNode.position)
        else {
            // 本杆不可行：直接落到该杆结果并推进，不阻断整条演示（同试打页）。
            clearTrajectory()
            scene.hideCueStick()
            applyStepRest(step: step, prediction: nil)
            scheduleNextStep(after: i)
            return
        }

        drawPlan(prediction: pred, shot: step.shot)
        let strikePos = CueStroke.strikePosition(
            cue: cueNode.position, aim: aim, spinX: step.shot.spinX
        )
        // 瞄准位摆杆走 `updateCueStick`（与试打页一致），不用静帧的 `showCueAtRest`：
        // 两者杆位/仰角算法不同，混用会在「定格 → 运杆第一帧」处跳一下。
        scene.updateCueStick(cueBallPosition: strikePos, aimDirection: aim)

        let hold = (i == 0) ? setupHold : followUpSetupHold
        let clearancePlayback = TrajectoryPlayback(
            recorder: recorder, surfaceY: surfaceY + AngleSceneCalculator.ballRadius
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + hold) { [weak self] in
            guard let self, self.isPlaying else { return }
            self.scene.runCueStroke(
                strikePosition: strikePos, aim: aim, velocity: Float(step.shot.velocity),
                clearanceProbe: { clearancePlayback.allBallCentersByName(at: Float($0)) }
            ) { [weak self] in
                self?.playStep(step: step, prediction: pred, recorder: recorder, index: i)
            }
        }
    }

    /// 触球瞬间：清预告线，按真实轨迹回放全桌球；球停后落静止位并衔接下一杆。
    /// 收杆不在此处——跟杆与淡出由 `runCueStroke` 接管（与试打页同）。
    private func playStep(step: SequenceStep, prediction pred: ShotPrediction,
                          recorder: TrajectoryRecorder, index i: Int) {
        guard isPlaying else { return }
        clearTrajectory()
        scene.ghostBallNode?.isHidden = true
        scene.hideContactDot()

        let yLevel = surfaceY + AngleSceneCalculator.ballRadius
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel)
        // G15：播到引擎自然静止，球停前无最后一跳/瞬移。
        let settle = playback.duration

        var cueAction: SCNAction?
        for (key, node) in scene.allBallNodes where !node.isHidden {
            let name = PositionPlayShotSolver.predName(boardKey: key, shot: step.shot)
            // 逐杆演示：进袋球只淡出、保留节点，否则下一杆无法重新挂回父节点。
            let action = playback.action(for: node, ballName: name, speed: 1.0,
                                         removeOnPocket: false, maxSimTime: settle)
            if PositionPlayBall.isCue(key) {
                cueAction = action
            } else if let action {
                node.runAction(action)
            }
        }

        let tail: TimeInterval = pred.pocketedBalls.isEmpty
            ? 0 : TrajectoryPlayback.pocketSettleDuration + 0.1
        guard let cueAction, let cueNode = scene.allBallNodes[PositionPlayBall.cueKey] else {
            applyStepRest(step: step, prediction: pred)
            scheduleNextStep(after: i)
            return
        }
        cueNode.runAction(cueAction) { [weak self] in
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(tail * 1_000_000_000))
                guard let self, self.isPlaying else { return }
                self.applyStepRest(step: step, prediction: pred)
                self.scheduleNextStep(after: i)
            }
        }
        ShotAudioScheduler.shared.play(prediction: pred)
    }

    /// 一杆收尾：球落静止位（有预测用引擎终位，否则用录制 `after`），清动画与球杆。
    private func applyStepRest(step: SequenceStep, prediction pred: ShotPrediction?) {
        ShotAudioScheduler.shared.cancel()
        guard let pred else {
            placeStepBoard(step.after)
            scene.hideCueStick()
            clearTrajectory()
            return
        }
        let yLevel = surfaceY + AngleSceneCalculator.ballRadius
        let potted = Set(pred.pocketedBalls.map { boardKey(forPredName: $0, shot: step.shot) })
        for (key, node) in scene.allBallNodes {
            guard step.before.onTable[key] != nil else { continue }
            if node.parent == nil { scene.rootNode.addChildNode(node) }
            node.removeAllActions()
            node.opacity = 1
            if potted.contains(key) {
                node.isHidden = true
            } else {
                node.isHidden = false
                let predName = PositionPlayShotSolver.predName(boardKey: key, shot: step.shot)
                if let p = pred.finalPositions[predName] {
                    node.position = SCNVector3(p.x, yLevel, p.z)
                }
            }
        }
        scene.hideCueStick()
        clearTrajectory()
    }

    /// 杆边界：这里是唯一的暂停生效点——当前杆已完整播完并落到静止位。
    private func scheduleNextStep(after i: Int) {
        guard isPlaying else { return }
        let next = i + 1
        guard next < steps.count else { finishPlayback(); return }
        if playbackState == .pausingAfterShot {
            // 停在本杆结果盘面；HUD 保留（整条序列尚未播完）。
            playbackState = .paused
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + interShotPause) { [weak self] in
            guard let self, self.isPlaying else { return }
            self.runStep(next)
        }
    }

    /// 整条序列播完：隐藏 HUD，复位回静帧（与缩略图同契约）。
    private func finishPlayback() {
        playbackState = .idle
        showOverlay = false
        scene.hideCueStick()
        resetBalls()
    }

    /// 无序列数据时的单杆演示：沿用静帧的代表性一杆。
    private func startSingleShot() {
        guard let source = previewSource,
              let pred = prediction, pred.feasible,
              let recorder = pred.recorder, pred.duration > 0.05,
              let cueNode = scene.allBallNodes[PositionPlayBall.cueKey], !cueNode.isHidden,
              let aim = DrillStaticPreview.aimDirection(path: pred.cuePath, from: cueNode.position)
        else {
            hidePlanDecorations()
            playAnimationFallback()
            return
        }

        drawPlan(prediction: pred, shot: source.shot)
        let strikePos = CueStroke.strikePosition(
            cue: cueNode.position, aim: aim, spinX: source.shot.spinX
        )
        scene.updateCueStick(cueBallPosition: strikePos, aimDirection: aim)

        let clearancePlayback = TrajectoryPlayback(
            recorder: recorder, surfaceY: surfaceY + AngleSceneCalculator.ballRadius
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + setupHold) { [weak self] in
            guard let self, self.isPlaying else { return }
            self.scene.runCueStroke(
                strikePosition: strikePos, aim: aim, velocity: Float(source.shot.velocity),
                clearanceProbe: { clearancePlayback.allBallCentersByName(at: Float($0)) }
            ) { [weak self] in
                self?.launchSingleShot(source: source, prediction: pred, recorder: recorder)
            }
        }
    }

    private func launchSingleShot(source: DrillStaticPreview.Source,
                                  prediction pred: ShotPrediction,
                                  recorder: TrajectoryRecorder) {
        guard isPlaying else { return }
        hidePlanDecorations()

        let yLevel = surfaceY + AngleSceneCalculator.ballRadius
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel)
        for (key, node) in scene.allBallNodes where !node.isHidden {
            let name = PositionPlayShotSolver.predName(boardKey: key, shot: source.shot)
            guard let action = playback.action(
                for: node, ballName: name, speed: 1.0, removeOnPocket: false
            ) else { continue }
            node.runAction(action)
        }
        ShotAudioScheduler.shared.play(prediction: pred)

        let ballTail: TimeInterval = pred.pocketedBalls.isEmpty
            ? 0 : TrajectoryPlayback.pocketSettleDuration + 0.1
        DispatchQueue.main.asyncAfter(
            deadline: .now() + TimeInterval(playback.duration) + ballTail
        ) { [weak self] in
            self?.finishPlayback()
        }
    }

    /// 亮方案：预告线 + 假想球（与试打页 `drawTrajectory` 同 `.positionPlay` 口径）。
    private func drawPlan(prediction pred: ShotPrediction, shot: PlannedShot) {
        clearTrajectory()
        TrajectoryRenderer.draw(
            prediction: pred,
            options: .positionPlay,
            context: TrajectoryRenderer.Context(
                prediction: pred,
                targetKey: shot.targetKey,
                pocket: shot.isFree ? nil : shot.pocket,
                surfaceY: surfaceY,
                showGhost: !shot.isFree
            ),
            scene: scene,
            into: &trajectoryNodes,
            detailOverride: DrillStaticPreview.Options.detail.trajectoryDetail
        )
    }

    /// 摆某杆的盘面：不在该盘面的球一律隐藏，在桌球复原 parent / opacity / 动作后定位。
    private func placeStepBoard(_ board: BoardSnapshot) {
        for (key, node) in scene.allBallNodes {
            node.removeAllActions()
            if board.onTable[key] == nil {
                node.isHidden = true
                continue
            }
            if node.parent == nil { scene.rootNode.addChildNode(node) }
            node.opacity = 1
            node.isHidden = false
        }
        DrillStaticPreview.placeBoard(
            board, on: scene, ballScale: DrillStaticPreview.Options.detail.ballScale
        )
        scene.setCueBallHomeOrientation(BallSpinIntegrator.identityOrientation, apply: true)
    }

    /// `PositionPlayShotSolver.predName` 的逆映射（引擎球名 → 盘面键）。
    private func boardKey(forPredName name: String, shot: PlannedShot) -> String {
        if name == ShotInput.cueBallName { return PositionPlayBall.cueKey }
        if !shot.isFree, name == ShotInput.targetBallName { return shot.targetKey }
        return name
    }

    private func updateOverlay(shot: PlannedShot?) {
        guard let shot else { return }
        overlayData = ShotOverlayData(
            spinX: shot.spinX, spinY: shot.spinY, velocity: shot.velocity
        )
    }

    /// 收起预告线 / 假想球 / 接触点。球杆与 HUD 不在此列。
    private func hidePlanDecorations() {
        clearTrajectory()
        scene.ghostBallNode?.isHidden = true
        scene.hideContactDot()
    }

    private func clearTrajectory() {
        scene.clearResultNodes(nodes: &trajectoryNodes)
    }

    // MARK: - Animation fallback playback

    private func playAnimationFallback() {
        guard let animation = drill?.animation,
              let cue = scene.cueBallNode,
              let cueHome = homePositions[PositionPlayBall.cueKey]
        else {
            resetBalls()
            return
        }
        let targetKey = previewSource?.shot.targetKey
            ?? homePositions.keys.first(where: { !PositionPlayBall.isCue($0) })
            ?? DrillBoardBuilder.targetKey
        let target = scene.allBallNodes[targetKey]
        let targetHome = homePositions[targetKey] ?? cueHome
        let total: TimeInterval = 1.4
        let cuePts = scenePoints(start: animation.cueBall.start, path: animation.cueBall.path, y: cueHome.y)
        let tgtPts = scenePoints(start: animation.targetBall.start, path: animation.targetBall.path, y: targetHome.y)
        if let cueAction = moveAction(points: cuePts, duration: total * 0.9, initialDelay: 0) {
            cue.runAction(cueAction) { [weak self] in Task { @MainActor in self?.resetBalls() } }
        }
        if let target, let tgtAction = moveAction(points: tgtPts, duration: total * 0.5, initialDelay: total * 0.38) {
            target.runAction(tgtAction)
        }
    }

    /// 回到静帧（与缩略图同契约）：HUD 仅在播放期间可见，故一并隐藏。
    private func resetBalls() {
        ShotAudioScheduler.shared.cancel()
        restoreHomePositions(clearActions: true)
        playbackState = .idle
        showOverlay = false
        applyPreviewFrame()
    }

    private func restoreHomePositions(clearActions: Bool) {
        let yLevel = surfaceY + AngleSceneCalculator.ballRadius
        for (key, home) in homePositions {
            guard let node = scene.allBallNodes[key] else { continue }
            if node.parent == nil { scene.rootNode.addChildNode(node) }
            if clearActions { node.removeAllActions() }
            node.opacity = 1
            node.isHidden = false
            scene.restoreNodePose(node)
            node.position = SCNVector3(home.x, yLevel, home.z)
            if PositionPlayBall.isCue(key) {
                scene.setCueBallHomeOrientation(
                    BallSpinIntegrator.identityOrientation, apply: true
                )
            }
        }
    }

    // MARK: - Geometry helpers

    private func point(_ p: CanvasPoint) -> SCNVector3 {
        AngleSceneCalculator.normalizedToScene(point: CGPoint(x: p.x, y: p.y), surfaceY: surfaceY)
    }

    private func lifted(_ v: SCNVector3, y: Float) -> SCNVector3 {
        SCNVector3(v.x, y, v.z)
    }

    private func scenePoints(start: CanvasPoint, path: [PathPoint], y: Float) -> [SCNVector3] {
        func at(_ c: CanvasPoint) -> SCNVector3 { lifted(point(c), y: y) }
        var pts: [SCNVector3] = [at(start)]
        var prev = start
        for p in path {
            if p.isCurve, let c1 = p.cp1, let c2 = p.cp2 {
                for s in 1...14 {
                    let t = Double(s) / 14
                    pts.append(at(cubicBezier(prev, c1, c2, p.endPoint, t)))
                }
            } else {
                pts.append(at(p.endPoint))
            }
            prev = p.endPoint
        }
        return pts
    }

    private func moveAction(points: [SCNVector3], duration: TimeInterval, initialDelay: TimeInterval) -> SCNAction? {
        guard points.count >= 2 else { return nil }
        var lengths: [Double] = []
        var total = 0.0
        for i in 1..<points.count {
            let d = distance(points[i - 1], points[i])
            lengths.append(d); total += d
        }
        guard total > 0.0001 else { return nil }

        var seq: [SCNAction] = []
        if initialDelay > 0 { seq.append(.wait(duration: initialDelay)) }
        for i in 1..<points.count {
            let segDur = duration * (lengths[i - 1] / total)
            let m = SCNAction.move(to: points[i], duration: segDur)
            m.timingMode = .linear
            seq.append(m)
        }
        return .sequence(seq)
    }

    private func distance(_ a: SCNVector3, _ b: SCNVector3) -> Double {
        let dx = Double(a.x - b.x), dz = Double(a.z - b.z)
        return (dx * dx + dz * dz).squareRoot()
    }

    private func cubicBezier(_ p0: CanvasPoint, _ p1: CanvasPoint,
                             _ p2: CanvasPoint, _ p3: CanvasPoint, _ t: Double) -> CanvasPoint {
        let mt = 1 - t
        let a = mt * mt * mt, b = 3 * mt * mt * t, c = 3 * mt * t * t, d = t * t * t
        return CanvasPoint(x: a * p0.x + b * p1.x + c * p2.x + d * p3.x,
                           y: a * p0.y + b * p1.y + c * p2.y + d * p3.y)
    }
}

/// 详情页 live USDZ 2D 顶视球桌（2:1）+ 回放按钮。
/// 「上手试打」入口在详情底栏（DR-057），台面不再叠主色胶囊以免与内容争抢。
struct DrillSceneView: View {
    let drill: DrillContent
    @StateObject private var controller = DrillSceneController()
    @State private var didAppear = false

    /// 取景余量处的兜底背景：与 `btTableFelt` 同源（F-SC-06），避免 letterbox 硬编码绿。
    private static let feltBackground = UIColor(Color.btTableFelt)

    /// HUD 条等比系数（设计基准 80pt 条高）：0.62 ⇒ 条高 ≈50pt、读数 12.4pt，
    /// 在详情横幅宽度下仍可读；力度条自适应剩余宽度。
    private static let hudScale: CGFloat = 0.62

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                AngleSceneView(
                    scene: controller.scene,
                    cameraMode: .constant(controller.cameraMode),
                    interactionMode: .none,
                    backgroundColor: Self.feltBackground
                )
                // 相框比例贴合球台木框实测长宽比（≈1.81），配合正交取景 0.77，
                // 球桌左右/上下都占满、无背景绿边（旧值 1.94 比球台宽 → 左右露绿）。
                .aspectRatio(CGFloat(DrillSceneController.frameAspect), contentMode: .fit)

                Button {
                    controller.togglePlayback()
                } label: {
                    // 次级幽灵钮：主行动留在详情底栏「上手试打」。
                    // 播放中给真 pause（杆边界可暂停，非假 affordance）；已请求暂停时降透明
                    // 表示「等本杆播完」，仍可点以撤销。
                    Image(systemName: playIcon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 28, height: 28)
                        .background(.black.opacity(0.28))
                        .clipShape(Circle())
                        .opacity(controller.playbackState == .pausingAfterShot ? 0.45 : 1)
                }
                .buttonStyle(BTPressableStyle.capsule)
                .padding(Spacing.md)
                .accessibilityLabel(playLabel)
                .accessibilityIdentifier("drillPlayButton")
            }

            // 球桌下方 HUD 条（与导出教学视频同款、同组件）：读球形拍与击球后置空，
            // 但保留条高，避免横幅高度在三拍之间跳动。
            hudBar
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
        .onAppear {
            guard !didAppear else { return }
            didAppear = true
            controller.setup(drill: drill)
        }
    }

    private var playIcon: String {
        switch controller.playbackState {
        case .idle, .paused: return "play.fill"
        case .playing, .pausingAfterShot: return "pause.fill"
        }
    }

    private var playLabel: String {
        switch controller.playbackState {
        case .idle: return "回放"
        case .playing: return "暂停"
        case .pausingAfterShot: return "本杆结束后暂停"
        case .paused: return "继续"
        }
    }

    @ViewBuilder
    private var hudBar: some View {
        // 条高恒定占位：HUD 显隐不改变横幅总高，避免三拍之间布局跳动。
        ZStack {
            Color.clear.frame(height: 80 * Self.hudScale)
            if controller.showOverlay, let data = controller.overlayData {
                BTShotHUDBar(
                    spinX: data.spinX, spinY: data.spinY, velocity: data.velocity,
                    k: Self.hudScale, powerBarWidth: nil, fixedWidth: false
                )
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("drillShotHUDBar")
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(BTMotion.easeInOutFast, value: controller.showOverlay)
    }
}

