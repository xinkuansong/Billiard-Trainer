import SwiftUI
import SceneKit

/// 贴桌右缘的竖直「打点 + 力度」仪表柱（T-P18-44，设计稿 §1.5/§1.7 Z3a）。
///
/// 结构自上而下：打点盘迷你图示（点开 Z7 打点盘 sheet）→ 竖直力度柱 → 力度读数。
/// 力度柱与瞄准刻度轮是同一视觉家族的两根「尺子」（左管方向、右管力度）：
/// - 三级刻度线（1.0 / 0.5 / 0.1 m/s = 白 40 / 25 / 15%），无数值；
/// - 填充水位随力度低→高走克制暗调渐变（暗绿→暗金→暗橙，禁高饱和）；
/// - 当前档位 = 金色短线；拖动按 `step` 离散步进，越档轻触感。
/// - 读数 = `BTReadout` 语义（力度是可调量值 → 金）。
///
/// 量程由调用方传入（场景页一律 `ShotTuning.velocityRange` 单一真源；
/// 球形生成器开球力度用自己的 `powerRange`）。
struct BTShotInstrumentColumn: View {
    let spinX: Double
    let spinY: Double
    /// 点开打点盘；nil = 不显示打点位（纯力度柱）。
    var onSpinTap: (() -> Void)? = nil
    @Binding var velocity: Double
    let range: ClosedRange<Double>
    var step: Double = 0.1
    var isDisabled: Bool = false
    /// 只读展示（序列演示）：力度条不可拖，但**不灰化**——这里显示的是本杆真实参数，
    /// 压到 50% 透明会让读数不可读。与 `isDisabled`（不可用态，灰化）语义不同。
    var isReadOnly: Bool = false
    /// 打点迷你图是否可点开。只读展示时演示进行中传 false、暂停时传 true。
    var spinTapEnabled: Bool = true
    /// Adjustment lifecycle; ending a drag never authorizes a shot.
    var onPowerDragBegan: (() -> Void)? = nil
    var onPowerDragEnded: ((Bool) -> Void)? = nil

    /// Compact dimensions and tick density for the daily landscape stage.
    var usesCompactAppearance = true
    /// Opt-in fixed travel length; the rest of the instrument keeps its intrinsic size.
    var fixedPowerBarHeight: CGFloat? = nil

    private var compact: Bool { usesCompactAppearance && !isReadOnly }

    @State private var lastDetent: Int = .min
    @State private var powerDragStarted = false
    @GestureState private var powerGestureActive = false
    @State private var lastDragY: CGFloat?
    /// 拖动中的连续行程（不量化），避免小位移被 step 吸附「吃掉」导致卡住。
    @State private var dragFrac: CGFloat?
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    private var span: Double { range.upperBound - range.lowerBound }
    /// 非线性视觉行程（条 13.2：低段细、高段快，`ShotTuning.velocityCurveGamma`）。
    private var fraction: CGFloat {
        CGFloat(ShotTuning.fraction(forVelocity: velocity, in: range))
    }

    var body: some View {
        // 顺序（G5）：打点迷你图 + 两行读数在**顶部固定区**，力度条本体在**底部**填充——
        // 使力度条本体底部与左侧刻度轮底部齐平、且两者等长（顶部固定区不计入条长）。
        VStack(spacing: 6) {
            if let onSpinTap {
                Button(action: onSpinTap) {
                    VStack(spacing: 2) {
                        BTSpinMiniIcon(spinX: spinX, spinY: spinY, diameter: compact ? 34 : 30)
                            .frame(minWidth: 44, minHeight: 44)
                            .background(compact ? HUDStyle.controlBackground : .clear, in: Circle())
                            .overlay(Circle().stroke(compact ? HUDStyle.hairline : .clear, lineWidth: 1))
                        if compact { Text("击球点").font(.btMicro).foregroundStyle(.btTextSecondary) }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("打点")
                .accessibilityIdentifier("shotStage.spinEntry")
                .disabled(isDisabled || !spinTapEnabled)
            }

            VStack(spacing: 6) {
                if !compact { powerReadout }
                powerBar.frame(height: fixedPowerBarHeight)
                if compact { powerReadout }
            }
            // Keep the existing vertical geometry while removing the wide second shell.
            .padding(.vertical, compact ? 6 : 0)
            .background {
                if compact {
                    RoundedRectangle(cornerRadius: BTRadius.xl)
                        .fill(HUDStyle.controlBackground)
                        .overlay(RoundedRectangle(cornerRadius: BTRadius.xl)
                            .stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
                        .frame(width: 40)
                }
            }
        }
        .opacity(isDisabled ? 0.5 : 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("打点与力度")
        .accessibilityIdentifier("shotStage.instrument")
    }

    private var powerReadout: some View {
        VStack(spacing: 0) {
            Text(compact ? "力度" : PowerDisplay.name(velocity))
                .font(compact ? .btMicro : HUDStyle.labelFontCompact)
                .foregroundStyle(HUDStyle.labelColor)
            Text(String(format: "%.1f", velocity))
                .font(HUDStyle.valueFontCompact)
                .foregroundStyle(HUDStyle.valueAdjustable)
                .monospacedDigit()
        }
        .fixedSize()
    }

    // MARK: - Power bar

    private var powerBar: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = compact ? min(28, geo.size.width) : geo.size.width
            let levelY = h * (1 - fraction)
            ZStack {
                RoundedRectangle(cornerRadius: HUDStyle.rulerCornerRadius, style: .continuous)
                    .fill(compact ? HUDStyle.controlBackground : HUDStyle.glassTint)
                    .overlay(RoundedRectangle(cornerRadius: HUDStyle.rulerCornerRadius, style: .continuous)
                        .stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))

                // 填充水位：暗调渐变（底暗绿 → 顶暗橙），按当前力度裁到水位线。
                LinearGradient(colors: HUDStyle.powerGradient, startPoint: .bottom, endPoint: .top)
                    .clipShape(RoundedRectangle(cornerRadius: HUDStyle.rulerCornerRadius, style: .continuous))
                    .mask(alignment: .bottom) {
                        Rectangle().frame(height: max(0, h - levelY))
                    }

                // 三级刻度（同瞄准轮家族）：major = 整 m/s，mid = 0.5，minor = step。
                // 位置走同一非线性映射——低速区刻度更疏（细调），高速区更密。
                Canvas { ctx, size in
                    var v = range.lowerBound
                    while v <= range.upperBound + 1e-6 {
                        let y = size.height * CGFloat(1 - ShotTuning.fraction(forVelocity: v, in: range))
                        let r = (v * 10).rounded() / 10
                        let isMajor = abs(r - r.rounded()) < 0.001
                        let isMed = abs(r * 2 - (r * 2).rounded()) < 0.001
                        if compact && !isMajor && !isMed { v += step; continue }
                        let len: CGFloat = isMajor ? size.width * 0.62 : (isMed ? size.width * 0.42 : size.width * 0.26)
                        var p = Path()
                        p.move(to: CGPoint(x: (size.width - len) / 2, y: y))
                        p.addLine(to: CGPoint(x: (size.width + len) / 2, y: y))
                        ctx.stroke(p, with: .color(HUDStyle.tickColor(major: isMajor, mid: isMed)),
                                   lineWidth: isMajor ? 1.4 : 0.8)
                        v += step
                    }
                }
                .padding(.vertical, 4)

                // 当前档位 = 金色短线（§1.7 刻度语法）。
                RoundedRectangle(cornerRadius: compact ? 2 : 0)
                    .fill(compact ? Color.btText : HUDStyle.tickIndicator)
                    .frame(width: w, height: compact ? 4 : 1.5)
                    .position(x: w / 2, y: min(max(levelY, 2), h - 2))
            }
            .frame(width: w)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(isDisabled || isReadOnly ? nil : dragGesture(height: h, width: geo.size.width))
        }
        .onChange(of: powerGestureActive) { _, active in
            if !active { finishPowerDrag(commit: false) }
        }
        .onChange(of: isDisabled) { _, disabled in
            if disabled { finishPowerDrag(commit: false) }
        }
        .onDisappear { finishPowerDrag(commit: false) }
        .accessibilityElement()
        .accessibilityLabel("力度")
        .accessibilityValue(String(format: "%.1f", velocity))
        .accessibilityIdentifier("shotStage.powerBar")
        .disabled(isDisabled || isReadOnly)
        .accessibilityAdjustableAction { direction in
            guard !isDisabled, !isReadOnly else { return }
            velocity = min(range.upperBound, max(range.lowerBound,
                velocity + (direction == .increment ? step : -step)))
        }

    }

    /// 拖动阻尼系数（条 13.2「滑动阻尼感」）：手指位移只按 0.6 折算到水位——
    /// 移动比手指慢、更像拨有阻尼的实体推子；配合逐档 haptic 形成「减速+棘轮」手感。
    private let dragDamping: CGFloat = 0.6

    private func dragGesture(height: CGFloat, width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($powerGestureActive) { _, active, _ in active = true }
            .onChanged { g in
                if !powerDragStarted {
                    powerDragStarted = true
                    onPowerDragBegan?()
                }
                let h = max(height, 1)
                // 相对增量 + 阻尼：起手不跳变（不吸附到手指绝对位置）；
                // 连续行程存 `dragFrac`，量化只发生在写回 velocity 时。
                var f = dragFrac ?? fraction
                if let last = lastDragY {
                    f -= (g.location.y - last) * dragDamping / h
                }
                f = min(max(f, 0), 1)
                lastDragY = g.location.y
                dragFrac = f
                let raw = ShotTuning.velocity(forFraction: Double(f), in: range)
                let snapped = (raw / step).rounded() * step
                let clamped = min(max(snapped, range.lowerBound), range.upperBound)
                let detent = Int((clamped / step).rounded())
                if detent != lastDetent {
                    if lastDetent != .min { haptic.impactOccurred(intensity: 0.4) }
                    lastDetent = detent
                    velocity = clamped
                }
            }
            .onEnded { g in
                let moved = abs(g.translation.height) >= 4
                let inside = g.location.x >= -20 && g.location.x <= width + 20
                finishPowerDrag(commit: moved && inside)
            }
    }

    private func finishPowerDrag(commit: Bool) {
        guard powerDragStarted else { return }
        powerDragStarted = false
        lastDetent = .min
        lastDragY = nil
        dragFrac = nil
        onPowerDragEnded?(commit)
    }
}

#Preview("Instrument column") {
    struct Host: View {
        @State var v = 3.3
        var body: some View {
            HStack {
                Spacer()
                BTShotInstrumentColumn(
                    spinX: 0.2, spinY: -0.3,
                    onSpinTap: {},
                    velocity: $v,
                    range: ShotTuning.velocityRange
                )
                .frame(width: 44, height: 260)
                .padding()
            }
            .frame(maxHeight: .infinity)
            .background(Color.black)
        }
    }
    return Host()
}

/// Shared explicit player poses; icons keep accessible names and active state.
struct ShotPlayerCameraButtons: View {
    @ObservedObject var rig: CameraRig
    var isEnabled: Bool
    var onWholeTable: (() -> Void)? = nil
    var onSelect: (CameraRig.PlayerView) -> Void

    var body: some View {
        VStack(spacing: Spacing.sm) {
            if let onWholeTable {
                cameraButton(label: "全局观察", id: "dailyClearance.observeTable",
                             selected: rig.keepsWholeTableFramed, action: onWholeTable) {
                    Image(systemName: "rectangle.inset.filled").font(.btHeadline)
                }
                button(.thirdPerson, symbol: "eye", label: "观察")
                cameraButton(label: "第一人称瞄准", id: "shotCamera.firstPerson",
                             selected: rig.playerView == .firstPerson,
                             action: { onSelect(.firstPerson) }) {
                    CueAimingFigure().frame(width: 28, height: 28)
                }
            } else {
                button(.firstPerson, symbol: "eye", label: "第一人称瞄准")
                button(.thirdPerson, symbol: "figure.stand", label: "第三人称观察")
            }
        }
    }

    private func button(_ view: CameraRig.PlayerView, symbol: String, label: String) -> some View {
        cameraButton(label: label, id: "shotCamera.\(view.rawValue)",
                     selected: rig.playerView == view, action: { onSelect(view) }) {
            Image(systemName: symbol).font(.btHeadline)
        }
    }

    private func cameraButton<Icon: View>(label: String, id: String, selected: Bool,
                                         action: @escaping () -> Void,
                                         @ViewBuilder icon: () -> Icon) -> some View {
        Button(action: action) {
            icon()
                .frame(width: 44, height: 44)
                .background(selected ? HUDStyle.selectedBackground : HUDStyle.controlBackground, in: Circle())
                .overlay(Circle().stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
        .accessibilityValue(selected ? "已选中" : "未选中")
        .accessibilityIdentifier(id)
    }
}

/// Left-facing cueing silhouette: low head, extended bridge and raised rear elbow.
private struct CueAimingFigure: View {
    var body: some View {
        Canvas { context, size in
            let transform = CGAffineTransform(scaleX: size.width / 100, y: size.height / 100)
            var silhouette = Path()
            silhouette.move(to: CGPoint(x: 40, y: 32))
            silhouette.addCurve(to: CGPoint(x: 64, y: 35), control1: CGPoint(x: 48, y: 28), control2: CGPoint(x: 59, y: 31))
            silhouette.addQuadCurve(to: CGPoint(x: 72, y: 49), control: CGPoint(x: 73, y: 38))
            silhouette.addLine(to: CGPoint(x: 77, y: 69))
            silhouette.addLine(to: CGPoint(x: 87, y: 87))
            silhouette.addQuadCurve(to: CGPoint(x: 94, y: 91), control: CGPoint(x: 94, y: 87))
            silhouette.addLine(to: CGPoint(x: 81, y: 91))
            silhouette.addQuadCurve(to: CGPoint(x: 75, y: 86), control: CGPoint(x: 77, y: 91))
            silhouette.addLine(to: CGPoint(x: 61, y: 62))
            silhouette.addLine(to: CGPoint(x: 55, y: 74))
            silhouette.addLine(to: CGPoint(x: 50, y: 87))
            silhouette.addQuadCurve(to: CGPoint(x: 54, y: 91), control: CGPoint(x: 55, y: 88))
            silhouette.addLine(to: CGPoint(x: 41, y: 91))
            silhouette.addLine(to: CGPoint(x: 44, y: 78))
            silhouette.addQuadCurve(to: CGPoint(x: 53, y: 53), control: CGPoint(x: 47, y: 62))
            silhouette.addLine(to: CGPoint(x: 40, y: 43))
            silhouette.addQuadCurve(to: CGPoint(x: 28, y: 48), control: CGPoint(x: 34, y: 48))
            silhouette.addLine(to: CGPoint(x: 10, y: 50))
            silhouette.addQuadCurve(to: CGPoint(x: 7, y: 47), control: CGPoint(x: 5, y: 50))
            silhouette.addLine(to: CGPoint(x: 27, y: 42))
            silhouette.addLine(to: CGPoint(x: 37, y: 35))
            silhouette.closeSubpath()
            context.fill(silhouette.applying(transform), with: .color(.white))
            let head = Path(ellipseIn: CGRect(x: 25, y: 25, width: 15, height: 15))
            context.fill(head.applying(transform), with: .color(.white))
            var rearArm = Path()
            rearArm.move(to: CGPoint(x: 45, y: 35))
            rearArm.addLine(to: CGPoint(x: 68, y: 21))
            rearArm.addQuadCurve(to: CGPoint(x: 76, y: 24), control: CGPoint(x: 74, y: 18))
            rearArm.addLine(to: CGPoint(x: 79, y: 43))
            rearArm.addQuadCurve(to: CGPoint(x: 73, y: 49), control: CGPoint(x: 81, y: 48))
            context.stroke(rearArm.applying(transform), with: .color(.white),
                           style: StrokeStyle(lineWidth: size.width * 0.065, lineCap: .round, lineJoin: .round))
            var cue = Path()
            cue.move(to: CGPoint(x: 3, y: 51)); cue.addLine(to: CGPoint(x: 96, y: 51))
            context.stroke(cue.applying(transform), with: .color(.white),
                           style: StrokeStyle(lineWidth: size.width * 0.035, lineCap: .round))
        }
        .accessibilityHidden(true)
    }
}

/// Explicit camera controls for a solved shot. Hosts decide when a solution is available.
/// This never selects a target or changes the solver/quiz state.
struct ShotSceneCameraButtons: View {
    let scene: AngleTrainingScene
    let aim: SCNVector3?
    let isEnabled: Bool
    var onSelect: () -> Void

    var body: some View {
        if let rig = scene.cameraRig {
            ShotPlayerCameraButtons(rig: rig, isEnabled: isEnabled && aim != nil) { view in
                guard let cue = scene.cueBallNode, !cue.isHidden, let aim else { return }
                onSelect()
                scene.discardSavedPerspectiveView()
                rig.usesRailCameraControls = true
                rig.enterPlayerView(view, cue: cue.position, aim: aim,
                    duration: UIAccessibility.isReduceMotionEnabled ? 0.1 : 0.95)
            }
        }
    }
}
