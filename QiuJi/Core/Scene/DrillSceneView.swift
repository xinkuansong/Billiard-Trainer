import SwiftUI
import SceneKit

/// 详情页用的 live「USDZ 球桌 2D 顶视」场景：与角度页同一套 `AngleTrainingScene`
/// （`TaiQiuZhuo.usdz` 台呢 + 抽取球节点 + plain 光照），切正交顶视相机，按 drill 摆球。
///
/// 轨迹与回放**由物理引擎 `ShotPredictor` 真算**（含减速/吃库/分离角/走位），用
/// `TrajectoryPlayback` 按真实运动重采样回放——而非沿手画折线匀速移动。物理不可行时
/// 退回手画 `DrillAnimation`。非交互（无拖球/点袋）。
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
    /// 顶视正交半高（场景单位），与 `DrillSceneView` 的 `orthoScale` 同一值。
    static let orthoScale: Double = 0.77

    private var didSetup = false
    private var drill: DrillContent?
    private var prediction: ShotPrediction?
    private var cueStart = SCNVector3Zero
    private var targetStart = SCNVector3Zero
    private var surfaceY: Float = 0
    private var trajectoryNodes: [SCNNode] = []
    private var isPlaying = false

    /// 点播放到开始击打之间的预备停顿（秒），让动作不至于太快、先看清计划。
    private let preStrikePause: TimeInterval = 2.0

    private let ballScale: Float = 1.3
    // 球台木边外框实测：半宽（X）≈1.406、半高（Z）≈0.777 场景单位，真实长宽比≈1.81
    // （木边在四周等宽外扩，会把 2:1 的台面拉成 ~1.81）。相框比例随之设为 1.81（见 DrillSceneView），
    // 正交半高取 0.77：球台占满相框、左右无绿边（仅裁掉最外侧 ~1% 木边，所有袋口完整）。
    private var orthoScale: Double { Self.orthoScale }
    // 进球线随目标球球色（本场景目标球为黑 8 → 亮灰，ADR-P11-12）。
    private let cueColor = TrajectoryStyle.aimColor
    private let targetColor = TrajectoryStyle.potColor(for: "_8")

    func setup(drill: DrillContent) {
        guard !didSetup else { return }
        didSetup = true
        self.drill = drill

        scene.setupScene(enhancedRendering: false)
        surfaceY = scene.surfaceY
        let animation = drill.animation

        let input = DrillShotResolver.shotInput(for: drill, surfaceY: surfaceY)
        let cue = input?.cueBall ?? point(animation.cueBall.start)
        let target = input?.targetBall ?? point(animation.targetBall.start)
        scene.applyBallLayout(cueBallPosition: cue, targetBallNumber: 8, targetPosition: target)
        scene.hideCueStick()
        enlarge(scene.cueBallNode)
        scene.targetBallNodes.forEach(enlarge)

        cueStart = scene.cueBallNode?.position ?? cue
        targetStart = scene.targetBallNodes.first?.position ?? target

        if let input {
            overlayData = ShotOverlayData(
                spinX: Double(input.spinX),
                spinY: Double(input.spinY),
                velocity: Double(input.velocity),
                cue: normScreen(cueStart),
                occupied: occupiedPoints(cue: cueStart, target: targetStart, pocketIndex: input.pocketIndex)
            )
        }

        scene.cameraRig?.topDownOrthographicScale = orthoScale
        scene.cameraRig?.topDownPanOffset = .zero
        scene.cameraRig?.applyTopDown2D()

        // 物理求解放后台（避免首帧卡顿），回主线程画轨迹。
        if let input {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let pred = ShotPredictor.predict(input)
                DispatchQueue.main.async {
                    guard let self else { return }
                    if pred.feasible, pred.cuePath.count >= 2 {
                        self.prediction = pred
                    }
                    self.redrawTrajectory()
                }
            }
        } else {
            redrawTrajectory()
        }
    }

    func play() {
        guard !isPlaying, let cue = scene.cueBallNode, let target = scene.targetBallNodes.first else { return }
        isPlaying = true
        cue.removeAllActions(); target.removeAllActions()
        cue.position = cueStart
        target.position = targetStart

        // 2 秒预备停顿：先保留轨迹 + 打点/力度指示器，让用户看清这一杆的计划，再清除并击打。
        DispatchQueue.main.asyncAfter(deadline: .now() + preStrikePause) { [weak self] in
            guard let self else { return }
            self.clearTrajectory()
            self.showOverlay = false
            self.startStrike()
        }
    }

    /// 预备停顿结束后真正开始球的运动（物理回放 / 退回手画折线）。
    private func startStrike() {
        guard let cue = scene.cueBallNode, let target = scene.targetBallNodes.first else { resetBalls(); return }

        // 物理回放：用真实模拟记录的逐帧位置（含减速/吃库），与所绘轨迹同源。
        if let pred = prediction, let recorder = pred.recorder, pred.duration > 0.05 {
            let yLevel = surfaceY + AngleSceneCalculator.ballRadius
            let playback = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel)
            let speed: Float = 1.0
            ShotAudioScheduler.shared.play(prediction: pred)
            if let tgtAction = playback.action(for: target, ballName: ShotInput.targetBallName, speed: speed) {
                target.runAction(tgtAction)
            }
            if let cueAction = playback.action(for: cue, ballName: ShotInput.cueBallName, speed: speed) {
                cueAction.timingMode = .linear
                cue.runAction(cueAction) { [weak self] in
                    Task { @MainActor in self?.resetBalls() }
                }
            }
            return
        }

        // 物理不可行时退回沿手画折线匀速移动。
        playAnimationFallback()
    }

    // MARK: - Trajectory drawing

    /// 按当前求解结果重绘预览轨迹：物理可行用真算路径，否则退回手画折线。
    private func redrawTrajectory() {
        if let pred = prediction, pred.feasible, pred.cuePath.count >= 2 {
            drawPhysics(pred)
        } else if let animation = drill?.animation {
            drawAnimationFallback(animation)
        }
        // 指示器与预览轨迹同生命周期：一起显示。
        showOverlay = overlayData != nil
    }

    private func drawPhysics(_ pred: ShotPrediction) {
        clearTrajectory()
        let y = surfaceY + AngleSceneCalculator.ballRadius * 0.5
        addPolyline(pred.objectPath.map { lifted($0, y: y) }, color: targetColor)
        addPolyline(pred.cuePath.map { lifted($0, y: y) }, color: cueColor)
        if UserPreferences.shared.showSeparationAngle {
            scene.addSeparationAngleLine(for: pred, into: &trajectoryNodes)
        }
    }

    private func drawAnimationFallback(_ animation: DrillAnimation) {
        clearTrajectory()
        let y = surfaceY + AngleSceneCalculator.ballRadius * 0.5
        addPolyline(scenePoints(start: animation.targetBall.start, path: animation.targetBall.path, y: y), color: targetColor)
        addPolyline(scenePoints(start: animation.cueBall.start, path: animation.cueBall.path, y: y), color: cueColor)
    }

    private func addPolyline(_ pts: [SCNVector3], color: UIColor) {
        guard pts.count >= 2 else { return }
        for i in 0..<(pts.count - 1) {
            trajectoryNodes.append(scene.addLine(from: pts[i], to: pts[i + 1], color: color,
                                                 radius: TrajectoryStyle.potRadius))
        }
    }

    private func clearTrajectory() {
        scene.clearResultNodes(nodes: &trajectoryNodes)
    }

    // MARK: - Animation fallback playback

    private func playAnimationFallback() {
        guard let animation = drill?.animation,
              let cue = scene.cueBallNode, let target = scene.targetBallNodes.first else { return }
        let total: TimeInterval = 1.4
        let cuePts = scenePoints(start: animation.cueBall.start, path: animation.cueBall.path, y: cueStart.y)
        let tgtPts = scenePoints(start: animation.targetBall.start, path: animation.targetBall.path, y: targetStart.y)
        if let cueAction = moveAction(points: cuePts, duration: total * 0.9, initialDelay: 0) {
            cue.runAction(cueAction) { [weak self] in Task { @MainActor in self?.resetBalls() } }
        }
        if let tgtAction = moveAction(points: tgtPts, duration: total * 0.5, initialDelay: total * 0.38) {
            target.runAction(tgtAction)
        }
    }

    private func resetBalls() {
        ShotAudioScheduler.shared.cancel()
        let yLevel = surfaceY + AngleSceneCalculator.ballRadius
        if let cue = scene.cueBallNode {
            if cue.parent == nil { scene.rootNode.addChildNode(cue) }
            cue.removeAllActions(); cue.opacity = 1
            cue.position = SCNVector3(cueStart.x, yLevel, cueStart.z)
        }
        if let target = scene.targetBallNodes.first {
            if target.parent == nil { scene.rootNode.addChildNode(target) }
            target.removeAllActions(); target.opacity = 1
            target.position = SCNVector3(targetStart.x, yLevel, targetStart.z)
        }
        // 回放结束、球归位后重新显示预览轨迹与指示器，并允许再次播放。
        isPlaying = false
        redrawTrajectory()
    }

    // MARK: - Overlay placement geometry

    /// 顶视正交相机下，场景坐标 → SCNView 归一化坐标（x:0左→1右, y:0上→1下）。
    /// 半宽 Hx = orthoScale·相框比例（屏幕水平=世界 +X），半高 Hz = orthoScale（屏幕上=世界 −Z）。
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
        // 左下角播放按钮占位，避免指示器压住它。
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

    private func enlarge(_ node: SCNNode?) {
        guard let node else { return }
        node.scale = SCNVector3(node.scale.x * ballScale, node.scale.y * ballScale, node.scale.z * ballScale)
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

    /// 取景余量处的兜底背景（深台呢绿），替代默认黑，避免任何残留边缘露出黑边。
    private static let feltBackground = UIColor(red: 0.11, green: 0.22, blue: 0.15, alpha: 1.0)

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
            .animation(.easeInOut(duration: 0.2), value: controller.showOverlay)

            Button {
                controller.play()
            } label: {
                Image(systemName: "play.fill")
                    .font(.btFootnote14)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.black.opacity(0.4))
                    .clipShape(Circle())
            }
            .padding(Spacing.md)
            .accessibilityLabel("回放")
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
                LinearGradient(colors: [.green, .yellow, .orange], startPoint: .bottom, endPoint: .top)
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
