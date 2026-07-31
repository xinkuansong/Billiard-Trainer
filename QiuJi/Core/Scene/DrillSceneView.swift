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

    /// 击球前叠加在球桌上的「打点 + 力度」指示器数据（击球后隐藏，回放后复现）。
    struct ShotOverlayData {
        let spinX: Double      // +左塞 / −右塞
        let spinY: Double      // +高杆 / −低杆
        let velocity: Double   // 杆头速度 m/s
        /// 母球归一化位置（打点盘贴在它的一侧）。
        let cue: CGPoint
        /// 需避让的归一化位置（母球/目标球/袋口/轨迹中点/播放按钮）。
        let occupied: [CGPoint]
    }
    @Published var overlayData: ShotOverlayData?
    @Published var showOverlay = false

    /// 相框/正交取景与 `DrillSceneView` 必须一致，否则世界→屏幕映射会偏。
    static let frameAspect: Double = 1.81
    /// 顶视正交半高（场景单位），与 `DrillStaticPreview.Options.detail` 同一值。
    static let orthoScale: Double = DrillStaticPreview.Options.detail.orthoScale

    private var didSetup = false
    private var didPlaceBoard = false
    private var drill: DrillContent?
    private var previewSource: DrillStaticPreview.Source?
    private var prediction: ShotPrediction?
    private var homePositions: [String: SCNVector3] = [:]
    private var surfaceY: Float = 0
    private var trajectoryNodes: [SCNNode] = []
    /// F-SC-01：回放锁定期间 chrome 可见；不改不可打断语义。
    @Published private(set) var isPlaying = false

    /// 点播放到开始击打之间的预备停顿（秒），让动作不至于太快、先看清计划。
    private let preStrikePause: TimeInterval = 2.0

    private var orthoScale: Double { Self.orthoScale }

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

        if let cuePos = homePositions[PositionPlayBall.cueKey] {
            let targetKey = source.shot.targetKey
            let targetPos = homePositions[targetKey] ?? cuePos
            let pocketIndex = ShotIntent.pocketIndex(for: source.shot.pocket) ?? -1
            overlayData = ShotOverlayData(
                spinX: applied.spinX,
                spinY: applied.spinY,
                velocity: applied.velocity,
                cue: normScreen(cuePos),
                occupied: occupiedPoints(
                    cue: cuePos, target: targetPos, pocketIndex: pocketIndex
                )
            )
        }
        showOverlay = overlayData != nil
    }

    func play() {
        guard !isPlaying, scene.cueBallNode != nil else { return }
        isPlaying = true
        restoreHomePositions(clearActions: true)

        // 2 秒预备停顿：先保留轨迹 + 打点/力度指示器，让用户看清这一杆的计划，再清除并击打。
        DispatchQueue.main.asyncAfter(deadline: .now() + preStrikePause) { [weak self] in
            guard let self else { return }
            self.clearTrajectory()
            self.scene.ghostBallNode?.isHidden = true
            self.scene.hideContactDot()
            self.scene.hideCueStick()
            self.showOverlay = false
            self.startStrike()
        }
    }

    /// 预备停顿结束后真正开始球的运动（物理回放 / 退回手画折线）。
    private func startStrike() {
        guard let source = previewSource else { resetBalls(); return }

        if let pred = prediction, let recorder = pred.recorder, pred.duration > 0.05 {
            let yLevel = surfaceY + AngleSceneCalculator.ballRadius
            let playback = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel)
            let speed: Float = 1.0
            ShotAudioScheduler.shared.play(prediction: pred)
            var startedCue = false
            for (key, node) in scene.allBallNodes where !node.isHidden {
                let name = PositionPlayShotSolver.predName(boardKey: key, shot: source.shot)
                guard let action = playback.action(for: node, ballName: name, speed: speed) else {
                    continue
                }
                if PositionPlayBall.isCue(key) {
                    startedCue = true
                    action.timingMode = .linear
                    node.runAction(action) { [weak self] in
                        Task { @MainActor in self?.resetBalls() }
                    }
                } else {
                    node.runAction(action)
                }
            }
            if !startedCue { resetBalls() }
            return
        }

        playAnimationFallback()
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

    private func resetBalls() {
        ShotAudioScheduler.shared.cancel()
        restoreHomePositions(clearActions: true)
        isPlaying = false
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

    // MARK: - Overlay placement geometry

    /// 顶视正交相机下，场景坐标 → SCNView 归一化坐标（x:0左→1右, y:0上→1下）。
    private func normScreen(_ s: SCNVector3) -> CGPoint {
        let hx = orthoScale * Self.frameAspect
        let hz = orthoScale
        return CGPoint(
            x: (Double(s.x) + hx) / (2 * hx),
            y: (Double(s.z) + hz) / (2 * hz)
        )
    }

    private func occupiedPoints(cue: SCNVector3, target: SCNVector3, pocketIndex: Int) -> [CGPoint] {
        let c = normScreen(cue), t = normScreen(target)
        var pts = [c, t, CGPoint(x: (c.x + t.x) / 2, y: (c.y + t.y) / 2)]
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)
        if pocketIndex >= 0, pocketIndex < pockets.count {
            let p = normScreen(pockets[pocketIndex])
            pts.append(p)
            pts.append(CGPoint(x: (t.x + p.x) / 2, y: (t.y + p.y) / 2))
        }
        pts.append(CGPoint(x: 0.10, y: 0.90))
        return pts
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

/// 详情页 live USDZ 2D 顶视球桌（2:1）+ 回放按钮 + 可选「上手试打」入口（试打模式方案 §1.6）。
struct DrillSceneView: View {
    let drill: DrillContent
    /// Premium 锁定态：试打按钮带皇冠（点击由宿主弹订阅页，Freemium 钩子）。
    var tryoutLocked: Bool = false
    /// 「上手试打」点击回调。nil = 不显示试打按钮（既有调用零改动）。
    var onTryoutTap: (() -> Void)? = nil
    @StateObject private var controller = DrillSceneController()
    @State private var didAppear = false

    /// 取景余量处的兜底背景：与 `btTableFelt` 同源（F-SC-06），避免 letterbox 硬编码绿。
    private static let feltBackground = UIColor(Color.btTableFelt)

    var body: some View {
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
            // 击球前叠加「打点 + 力度」指示器（智能选最空角落，不挡球/轨迹；击球后随轨迹隐藏）。
            .overlay {
                if controller.showOverlay, let data = controller.overlayData {
                    DrillShotOverlay(data: data)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .animation(BTMotion.easeInOutFast, value: controller.showOverlay)

            Button {
                controller.play()
            } label: {
                // F-SC-01：回放锁定进行时视觉反馈——保持 play.fill + 降透明 + disabled；
                // 不换 stop 图标（按钮不可点，stop 会成假 affordance，违 B3 诚实反馈）。
                Image(systemName: "play.fill")
                    .font(.btFootnote14)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.black.opacity(0.4))
                    .clipShape(Circle())
                    .opacity(controller.isPlaying ? 0.4 : 1)
            }
            .disabled(controller.isPlaying)
            .buttonStyle(BTPressableStyle.capsule)
            .padding(Spacing.md)
            .accessibilityLabel(controller.isPlaying ? "回放中" : "回放")
            .accessibilityIdentifier("drillPlayButton")
        }
        // 「上手试打」胶囊：与回放按钮同层覆层，对角 bottomTrailing（§1.6 入口）。
        .overlay(alignment: .bottomTrailing) {
            if let onTryoutTap {
                Button(action: onTryoutTap) {
                    HStack(spacing: 4) {
                        if tryoutLocked {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.btAccent)
                        }
                        Text("上手试打")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(.black.opacity(0.4))
                    .clipShape(Capsule())
                }
                // F-DL-03：台面覆层试打钮按压（回放钮已接 BTPressableStyle.capsule）。
                .buttonStyle(BTPressableStyle.capsule)
                .padding(Spacing.md)
                .accessibilityLabel("上手试打")
                .accessibilityIdentifier("drillTryoutButton")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
        .onAppear {
            guard !didAppear else { return }
            didAppear = true
            controller.setup(drill: drill)
        }
    }
}

// MARK: - Shot overlay (打点 + 力度 指示器)

/// 击球前叠加在球桌上的「打点(塞) + 力度」指示器。
/// - 打点盘：复用「分离角与走位」页 `SpinPadView` 的视觉（白球 + 红色击球点 + 十字）只读版。
/// - 力度条：垂直、对数刻度（高速度增长放缓，避免条过高）。
/// 两个指示器在球桌四角中各选「离所有球/袋口/轨迹/播放按钮最远」的角落，互不同角，尽量不遮挡。
private struct DrillShotOverlay: View {
    let data: DrillSceneController.ShotOverlayData

    private let spinSize: CGFloat = 24      // 打点盘（更小）
    private let powerW: CGFloat = 10         // 力度条宽（更细）
    private let edgeMargin: CGFloat = 16     // 力度条距库边间距（不完全贴住）

    /// 短库（左右库边）在屏幕上的竖直跨度占视图高度的比例：innerWidth /（2·orthoScale）。
    private var cushionSpanFraction: CGFloat {
        CGFloat(Double(AngleSceneCalculator.innerWidth) / (2 * DrillSceneController.orthoScale))
    }

    // 速度条对数刻度上下限（m/s）：与全 App 力度滑条量程单一真源（ShotTuning.velocityRange）。
    static let vMin = ShotTuning.velocityRange.lowerBound
    static let vMax = ShotTuning.velocityRange.upperBound
    static func powerFraction(_ v: Double) -> Double {
        let lo = log(vMin), hi = log(vMax)
        let cv = max(vMin, min(vMax, v))
        return max(0, min(1, (log(cv) - lo) / (hi - lo)))
    }

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            let occ = data.occupied.map { CGPoint(x: $0.x * W, y: $0.y * H) }

            // 力度条：长 = 短库长 × 0.7，上下居中，贴左/右库边（不遮挡优先右）。
            let barH = cushionSpanFraction * H * 0.7
            let onRight = preferRightSide(W: W, H: H, barH: barH, occ: occ)
            let barX = onRight ? (W - edgeMargin - powerW / 2) : (edgeMargin + powerW / 2)
            let barCenter = CGPoint(x: barX, y: H / 2)

            // 打点盘：贴在母球的最空一侧。
            let cue = CGPoint(x: data.cue.x * W, y: data.cue.y * H)
            let spinCenter = spinPosition(near: cue, W: W, H: H,
                                          obstacles: Array(occ.dropFirst()),
                                          barCenter: barCenter, barH: barH)

            ZStack {
                DrillPowerBar(velocity: data.velocity)
                    .frame(width: powerW, height: barH)
                    .position(barCenter)
                BTSpinMiniIcon(spinX: data.spinX, spinY: data.spinY,
                               diameter: spinSize, trueScale: true)
                    .frame(width: spinSize, height: spinSize)
                    .position(spinCenter)
                    .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
            }
        }
    }

    /// 力度条选边：不遮挡优先右侧。右侧库边竖条与所有球/轨迹点的最近距离够大→右，否则比较左右取更空者（并列右）。
    private func preferRightSide(W: CGFloat, H: CGFloat, barH: CGFloat, occ: [CGPoint]) -> Bool {
        let yTop = H / 2 - barH / 2, yBot = H / 2 + barH / 2
        let rightX = W - edgeMargin - powerW / 2
        let leftX = edgeMargin + powerW / 2
        func clearance(_ x: CGFloat) -> CGFloat {
            occ.map { p -> CGFloat in
                let dy = max(0, max(yTop - p.y, p.y - yBot))
                return hypot(abs(p.x - x), dy)
            }.min() ?? .greatestFiniteMagnitude
        }
        let needed = powerW / 2 + 14   // 球需明显离开竖条才算不遮挡
        let cr = clearance(rightX), cl = clearance(leftX)
        if cr >= needed { return true }
        if cl >= needed { return false }
        return cr >= cl
    }

    /// 在母球**左右两侧**选一个在界内、离其他球/轨迹/力度条最远的方向放打点盘（不放上下）。
    private func spinPosition(near cue: CGPoint, W: CGFloat, H: CGFloat,
                              obstacles: [CGPoint], barCenter: CGPoint, barH: CGFloat) -> CGPoint {
        let off = spinSize / 2 + 13
        let dirs: [CGPoint] = [CGPoint(x: 1, y: 0), CGPoint(x: -1, y: 0)]
        let half = spinSize / 2 + 3
        // 力度条采样为障碍点，避免打点盘压住条。
        var obs = obstacles
        for f in stride(from: -0.5, through: 0.5, by: 0.25) {
            obs.append(CGPoint(x: barCenter.x, y: barCenter.y + CGFloat(f) * barH))
        }
        var best = CGPoint(x: cue.x + off, y: cue.y)
        var bestScore = -CGFloat.greatestFiniteMagnitude
        for d in dirs {
            let raw = CGPoint(x: cue.x + d.x * off, y: cue.y + d.y * off)
            let c = CGPoint(x: min(W - half, max(half, raw.x)),
                            y: min(H - half, max(half, raw.y)))
            // 出界夹回越多越扣分；离障碍越远越好。
            let clampPenalty = hypot(c.x - raw.x, c.y - raw.y)
            let clearance = obs.map { hypot($0.x - c.x, $0.y - c.y) }.min() ?? .greatestFiniteMagnitude
            let score = clearance - clampPenalty * 2
            if score > bestScore { bestScore = score; best = c }
        }
        return best
    }
}

/// 垂直力度条（对数刻度）：整条轨道铺满给定高度（≈短库 0.7），底→顶 绿→黄→橙 渐变，
/// 填充高度按 `powerFraction` 映射；速度值（m/s）浮在条顶。
private struct DrillPowerBar: View {
    let velocity: Double
    private var fraction: Double { DrillShotOverlay.powerFraction(velocity) }

    var body: some View {
        GeometryReader { g in
            let h = g.size.height
            ZStack(alignment: .bottom) {
                Capsule().fill(Color.black.opacity(0.30))
                // F-SC-02：与击打页力度 chrome 同源。
                LinearGradient(colors: HUDStyle.powerGradient, startPoint: .bottom, endPoint: .top)
                    .mask(alignment: .bottom) {
                        Capsule().frame(height: max(4, h * CGFloat(fraction)))
                    }
            }
            .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 0.5))
            .overlay(alignment: .top) {
                Text(String(format: "%.1f", velocity))
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .fixedSize()
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Color.black.opacity(0.5), in: Capsule())
                    .offset(y: -3)
            }
        }
    }
}
