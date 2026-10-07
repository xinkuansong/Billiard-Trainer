import SwiftUI
import SceneKit
import UIKit

/// 贴桌右缘的竖直「打点 + 力度」仪表柱（T-P18-44，设计稿 §1.5/§1.7 Z3a）。
///
/// 结构自上而下：打点盘迷你图示（点开 Z7 打点盘 sheet）→ 竖直力度柱 → 力度读数。
/// 力度柱与瞄准刻度轮是同一视觉家族的两根「尺子」（左管方向、右管力度）：
/// - 三级刻度线（1.0 / 0.5 / 0.1 m/s = 白 40 / 25 / 15%），无数值；
/// - 填充水位随力度低→高走克制暗调渐变（暗绿→暗金→暗橙，禁高饱和）；
/// - 连续拖动，不按刻度吸附；精调时局部放大刻度并提供轻触感。
/// - 读数 = `BTReadout` 语义（力度是可调量值 → 金）。
///
/// 量程由调用方传入（场景页一律 `ShotTuning.velocityRange` 单一真源；
/// 球形生成器开球力度用自己的 `powerRange`）。
struct BTShotInstrumentColumn: View {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let spinX: Double
    let spinY: Double
    /// 点开打点盘；nil = 不显示打点位（纯力度柱）。
    var onSpinTap: (() -> Void)? = nil
    @Binding var velocity: Double
    let range: ClosedRange<Double>
    /// Visual/coarse haptic spacing only; dragging never snaps to this interval.
    var step: Double = 0.1
    var accessibilityStep: Double = 0.01
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
    /// Visible compact ruler width; the shell keeps six points of padding on each side.
    var powerLabel: String = "力度"
    var compactPowerBarWidth: CGFloat = 28
    /// Compact spin entry diameter; other hosts retain the original 44-point button.
    var compactSpinButtonDiameter: CGFloat = 44
    var compactGroupSpacing: CGFloat = 6

    private var compact: Bool { usesCompactAppearance && !isReadOnly }

    @State private var adaptiveDrag = AdaptiveShotDrag()
    @State private var detents = ShotDragDetents()
    @State private var soundDetents = ShotDragDetents(minimumInterval: ShotDragDetents.soundMinimumInterval)
    @State private var precisionScale = ShotPrecisionScale()
    @State private var powerAdjustment: PowerDragAdjustment?
    @State private var powerDragStarted = false
    @GestureState private var powerGestureActive = false
    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    private var span: Double { range.upperBound - range.lowerBound }
    /// 非线性视觉行程（条 13.2：低段细、高段快，`ShotTuning.velocityCurveGamma`）。
    private var fraction: CGFloat {
        CGFloat(ShotTuning.fraction(forVelocity: velocity, in: range))
    }

    var body: some View {
        // 顺序（G5）：打点迷你图 + 两行读数在**顶部固定区**，力度条本体在**底部**填充——
        // 使力度条本体底部与左侧刻度轮底部齐平、且两者等长（顶部固定区不计入条长）。
        VStack(spacing: compact ? compactGroupSpacing : 6) {
            if let onSpinTap {
                Button(action: onSpinTap) {
                    VStack(spacing: 2) {
                        BTSpinMiniIcon(spinX: spinX, spinY: spinY,
                                       diameter: compact ? compactSpinButtonDiameter - 10 : 30)
                            .frame(minWidth: compact ? compactSpinButtonDiameter : 44,
                                   minHeight: compact ? compactSpinButtonDiameter : 44)
                            .background { BTHUDControlBackground(shape: Circle(), normal: compact ? HUDStyle.controlBackground : .clear) }
                            .overlay(Circle().stroke(compact ? HUDStyle.hairline : .clear, lineWidth: 1))
                        if compact { Text("击球点").font(.btMicro).foregroundStyle(.btTextSecondary) }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(BTHUDPressStyle())
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
                        .frame(width: compactPowerBarWidth + 12)
                }
            }
        }
        .opacity(isDisabled ? 0.5 : 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("打点与\(powerLabel)")
        .accessibilityIdentifier("shotStage.instrument")
    }

    private var powerReadout: some View {
        VStack(spacing: 0) {
            Text(compact ? powerLabel : PowerDisplay.name(velocity))
                .font(compact ? .btMicro : HUDStyle.labelFontCompact)
                .foregroundStyle(HUDStyle.labelColor)
            Text(String(format: isReadOnly ? "%.1f" : "%.2f", velocity))
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
            let w = compact ? min(compactPowerBarWidth, geo.size.width) : geo.size.width
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

                if !isReadOnly && precisionScale.isFine {
                    BTPowerPrecisionLens(value: velocity, range: range, step: max(step * 0.1, 0.001))
                        .frame(height: 64)
                        .position(x: w / 2, y: levelY)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                        .transition(.opacity)
                }

                // The global water level remains the current-value indicator.
                RoundedRectangle(cornerRadius: compact ? 2 : 0)
                    .fill(compact ? Color.btText : HUDStyle.tickIndicator)
                    .frame(width: w, height: compact ? 4 : 1.5)
                    .position(x: w / 2, y: min(max(levelY, 2), h - 2))
            }
            .clipShape(RoundedRectangle(cornerRadius: HUDStyle.rulerCornerRadius))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: precisionScale.isFine)
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
        .onChange(of: isEnabled) { _, enabled in
            if !enabled { finishPowerDrag(commit: false) }
        }
        .onChange(of: isReadOnly) { _, readOnly in
            if readOnly { finishPowerDrag(commit: false) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { finishPowerDrag(commit: false) }
        }
        .onDisappear { finishPowerDrag(commit: false) }
        .accessibilityElement()
        .accessibilityLabel(powerLabel)
        .accessibilityValue(String(format: isReadOnly ? "%.1f" : "%.2f", velocity))
        .accessibilityIdentifier("shotStage.powerBar")
        .disabled(isDisabled || isReadOnly)
        .accessibilityAdjustableAction { direction in
            guard isEnabled, !isDisabled, !isReadOnly else { return }
            velocity = min(range.upperBound, max(range.lowerBound,
                velocity + (direction == .increment ? accessibilityStep : -accessibilityStep)))
        }

    }

    private func dragGesture(height: CGFloat, width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($powerGestureActive) { _, active, _ in active = true }
            .onChanged { g in
                guard isEnabled, !isDisabled, !isReadOnly else {
                    finishPowerDrag(commit: false)
                    return
                }
                if !powerDragStarted {
                    powerDragStarted = true
                    precisionScale.resetTiming()
                    powerAdjustment = PowerDragAdjustment(velocity: velocity, range: range)
                    haptic.prepare()
                    if UserPreferences.shared.soundEffectsEnabled { ShotSoundBank.shared.prepare() }
                    onPowerDragBegan?()
                }
                let time = g.time.timeIntervalSinceReferenceDate
                let sample = adaptiveDrag.update(translation: Double(g.translation.height), time: time)
                precisionScale.update(sample: sample, time: time)
                guard var adjustment = powerAdjustment else { return }
                let result = adjustment.move(delta: sample.delta, height: Double(height), range: range)
                powerAdjustment = adjustment
                // Preserve exact tap values and do not tie model updates to haptic detents.
                if sample.delta != 0, result.velocity != velocity { velocity = result.velocity }
                if result.reachedBoundary {
                    haptic.impactOccurred(intensity: 1.0)
                    ShotSoundBank.shared.playControlTick(intensity: 1.0, control: .power)
                    detents = ShotDragDetents()
                    soundDetents = ShotDragDetents(minimumInterval: ShotDragDetents.soundMinimumInterval)
                } else {
                    let spacing = max(step * precisionScale.stepMultiplier, 0.001)
                    if let intensity = detents.intensity(position: result.velocity, spacing: spacing,
                                                        sample: sample, time: time) {
                        haptic.impactOccurred(intensity: CGFloat(intensity))
                    }
                    if let intensity = soundDetents.intensity(position: result.velocity, spacing: spacing,
                                                             sample: sample, time: time) {
                        ShotSoundBank.shared.playControlTick(intensity: intensity, control: .power)
                    }
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
        adaptiveDrag = AdaptiveShotDrag()
        detents = ShotDragDetents()
        soundDetents = ShotDragDetents(minimumInterval: ShotDragDetents.soundMinimumInterval)
        powerAdjustment = nil
        precisionScale.resetTiming()
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
    var controlSpacing: CGFloat = Spacing.sm
    @ObservedObject var rig: CameraRig
    var isEnabled: Bool
    var onWholeTable: (() -> Void)? = nil
    /// Explicit host opt-in; other shot/quiz pages retain their existing camera controls.
    var usesTwoViewControls = false
    var temporaryTopDownActive = false
    var onTemporaryTopDownBegan: (() -> Void)? = nil
    var onTemporaryTopDownEnded: (() -> Void)? = nil
    var onSelect: (CameraRig.PlayerView) -> Void

    var body: some View {
        VStack(spacing: controlSpacing) {
            if rig.usesMergedCamera {
                cameraButton(label: "全局观察", id: "dailyClearance.observeTable",
                    selected: rig.mergedGlobalActive && !temporaryTopDownActive,
                    action: { onWholeTable?() }) {
                    Image(systemName: "eye").font(.btHeadline)
                }.disabled(temporaryTopDownActive)
                cameraButton(label: rig.usesSurfaceCamera ? "沿杆观察" : "第三人称", id: "shotCamera.thirdPerson",
                    selected: !rig.usesSurfaceCamera && !rig.mergedGlobalActive && !temporaryTopDownActive,
                    action: { onSelect(.thirdPerson) }) {
                    Image(systemName: "figure.stand").font(.btTitle2)
                }.disabled(temporaryTopDownActive)
                cameraButton(label: "临时俯视", id: "shotCamera.temporaryTopDown",
                    selected: temporaryTopDownActive,
                    action: { if temporaryTopDownActive { onTemporaryTopDownEnded?() }
                        else { onTemporaryTopDownBegan?() } }) {
                    TemporaryTopDownFigure().frame(width: 28, height: 28)
                }.onDisappear { onTemporaryTopDownEnded?() }
            } else if usesTwoViewControls {
                twoViewButton(.thirdPerson, label: "第三人称") {
                    Image(systemName: "figure.stand").font(.btTitle2)
                }
                twoViewButton(.firstPerson, label: "第一人称") {
                    CueAimingFigure().frame(width: 28, height: 28)
                }
                TemporaryTopDownFigure()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(HUDStyle.valueMeasured)
                    .frame(width: 44, height: 44)
                    .background(temporaryTopDownActive ? HUDStyle.selectedBackground : HUDStyle.controlBackground, in: Circle())
                    .overlay(Circle().stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
                    .overlay {
                        BTTemporaryTopDownPressControl(isEnabled: isEnabled,
                            isActive: temporaryTopDownActive,
                            onBegin: { onTemporaryTopDownBegan?() },
                            onEnd: { onTemporaryTopDownEnded?() })
                    }
                    .onDisappear { onTemporaryTopDownEnded?() }
            } else if let onWholeTable {
                cameraButton(label: "全局观察", id: "dailyClearance.observeTable",
                             selected: rig.keepsWholeTableFramed, action: onWholeTable) {
                    Image(systemName: "eye").font(.btHeadline)
                }
                button(.thirdPerson, symbol: "figure.stand", label: "观察")
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

    private func twoViewButton<Icon: View>(_ view: CameraRig.PlayerView, label: String,
                                          @ViewBuilder icon: () -> Icon) -> some View {
        cameraButton(label: label, id: "shotCamera.\(view.rawValue)",
                     selected: rig.twoViewMode == view && !temporaryTopDownActive,
                     action: { onSelect(view) }, icon: icon)
            .disabled(temporaryTopDownActive)
    }

    private func button(_ view: CameraRig.PlayerView, symbol: String, label: String) -> some View {
        cameraButton(label: label, id: "shotCamera.\(view.rawValue)",
                     selected: rig.playerView == view, action: { onSelect(view) }) {
            Image(systemName: symbol)
                .font(view == .thirdPerson ? .system(size: 24, weight: .semibold) : .btHeadline)
        }
    }

    private func cameraButton<Icon: View>(label: String, id: String, selected: Bool,
                                         action: @escaping () -> Void,
                                         @ViewBuilder icon: () -> Icon) -> some View {
        Button(action: action) {
            icon()
                .frame(width: 44, height: 44)
                .background { BTHUDControlBackground(shape: Circle(), selected: selected) }
                .overlay(Circle().stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
                .contentShape(Rectangle())
        }
        .buttonStyle(BTHUDPressStyle())
        .foregroundStyle(.white)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
        .accessibilityValue(selected ? "已选中" : "未选中")
        .accessibilityIdentifier(id)
    }
}

/// The approved 28pt glyph: six pocket openings, cue ball and an upward aiming line.
private struct TemporaryTopDownFigure: View {
    var body: some View {
        Canvas { context, size in
            let transform = CGAffineTransform(scaleX: size.width / 28, y: size.height / 28)
            var lines = Path()
            let segments: [[CGPoint]] = [
                [.init(x: 9, y: 2.5), .init(x: 19, y: 2.5)],
                [.init(x: 7, y: 5), .init(x: 7, y: 11.5)],
                [.init(x: 7, y: 16.5), .init(x: 7, y: 23)],
                [.init(x: 9, y: 25.5), .init(x: 19, y: 25.5)],
                [.init(x: 21, y: 23), .init(x: 21, y: 16.5)],
                [.init(x: 21, y: 11.5), .init(x: 21, y: 5)],
                [.init(x: 8, y: 4), .init(x: 6.5, y: 2.5)],
                [.init(x: 20, y: 4), .init(x: 21.5, y: 2.5)],
                [.init(x: 7, y: 14), .init(x: 5.5, y: 14)],
                [.init(x: 21, y: 14), .init(x: 22.5, y: 14)],
                [.init(x: 8, y: 24), .init(x: 6.5, y: 25.5)],
                [.init(x: 20, y: 24), .init(x: 21.5, y: 25.5)],
                [.init(x: 14, y: 18), .init(x: 14, y: 8)],
                [.init(x: 11.5, y: 10.5), .init(x: 14, y: 8), .init(x: 16.5, y: 10.5)]
            ]
            for segment in segments {
                lines.move(to: segment[0])
                for point in segment.dropFirst() { lines.addLine(to: point) }
            }
            context.stroke(lines.applying(transform), with: .color(HUDStyle.valueMeasured),
                style: StrokeStyle(lineWidth: size.width / 28 * 1.65, lineCap: .round, lineJoin: .round))
            let ball = Path(ellipseIn: CGRect(x: 12.2, y: 19.2, width: 3.6, height: 3.6))
            context.fill(ball.applying(transform), with: .color(HUDStyle.valueMeasured))
        }
    }
}

#Preview("Temporary top-down Light") {
    TemporaryTopDownFigure().frame(width: 28, height: 28)
        .padding(Spacing.sm).background(HUDStyle.panelBackground)
        .preferredColorScheme(.light)
}

#Preview("Temporary top-down Dark") {
    TemporaryTopDownFigure().frame(width: 28, height: 28)
        .padding(Spacing.sm).background(HUDStyle.panelBackground)
        .preferredColorScheme(.dark)
}

/// Owns the entire touch; a short tap has no action and leaving the hit rect never rearms it.
private struct BTTemporaryTopDownPressControl: UIViewRepresentable {
    let isEnabled: Bool
    let isActive: Bool
    let onBegin: () -> Void
    let onEnd: () -> Void

    func makeUIView(context: Context) -> HoldControl { HoldControl() }

    func updateUIView(_ view: HoldControl, context: Context) {
        view.onBegin = onBegin
        view.onEnd = onEnd
        view.isEnabled = isEnabled
        view.accessibilityValue = isActive ? "正在临时俯视" : "本杆视角"
        view.accessibilityTraits = isEnabled ? .button : [.button, .notEnabled]
    }

    static func dismantleUIView(_ view: HoldControl, coordinator: ()) { view.finishHold() }

    final class HoldControl: UIControl {
        var onBegin: (() -> Void)?
        var onEnd: (() -> Void)?
        private var pending: DispatchWorkItem?
        private var holding = false
        private var trackingInside = false
        private var pressRevision: UInt64 = 0

        override var isEnabled: Bool { didSet { if !isEnabled { finishHold() } } }

        override init(frame: CGRect) {
            super.init(frame: frame)
            isAccessibilityElement = true
            accessibilityLabel = "临时俯视球桌"
            accessibilityHint = "按住查看，松手返回本杆视角；辅助功能激活暂时查看两秒"
            accessibilityIdentifier = "shotCamera.temporaryTopDown"
            accessibilityCustomActions = [UIAccessibilityCustomAction(name: "结束临时俯视", target: self, selector: #selector(endAccessibleHold))]
            NotificationCenter.default.addObserver(self, selector: #selector(cancelForInactiveScene),
                name: UIApplication.willResignActiveNotification, object: nil)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            guard isEnabled, bounds.contains(touch.location(in: self)) else { return false }
            finishHold()
            trackingInside = true
            let revision = pressRevision
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.pressRevision == revision,
                      self.isEnabled, self.trackingInside else { return }
                self.pending = nil
                self.holding = true
                self.onBegin?()
            }
            pending = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
            return true
        }

        override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            guard trackingInside, bounds.contains(touch.location(in: self)) else {
                finishHold()
                return false
            }
            return true
        }

        override func endTracking(_ touch: UITouch?, with event: UIEvent?) { finishHold() }
        override func cancelTracking(with event: UIEvent?) { finishHold() }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil { finishHold() }
        }

        func finishHold() {
            pressRevision &+= 1
            pending?.cancel()
            pending = nil
            trackingInside = false
            guard holding else { return }
            holding = false
            onEnd?()
        }

        override func accessibilityActivate() -> Bool {
            guard isEnabled else { return false }
            finishHold()
            holding = true
            onBegin?()
            let revision = pressRevision
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.pressRevision == revision else { return }
                self.finishHold()
            }
            pending = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
            return true
        }

        @objc private func endAccessibleHold() -> Bool { finishHold(); return true }
        @objc private func cancelForInactiveScene() { finishHold() }
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


/// A local magnifier over the existing water line. The rest of the full-range
/// power bar stays visible; ticks represent values, not additional input steps.
private struct BTPowerPrecisionLens: View {
    let value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        Canvas { context, size in
            let pixelsPerUnit = 8 / step
            let halfSpan = Double(size.height) / pixelsPerUnit / 2
            let first = Int(floor(max(range.lowerBound, value - halfSpan) / step))
            let last = Int(ceil(min(range.upperBound, value + halfSpan) / step))
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(HUDStyle.panelBackground))
            for index in first...last {
                let tick = Double(index) * step
                guard range.contains(tick) else { continue }
                let y = size.height / 2 - CGFloat((tick - value) * pixelsPerUnit)
                let major = index.isMultiple(of: 5)
                let length = size.width * (major ? 0.75 : 0.45)
                var path = Path()
                path.move(to: CGPoint(x: (size.width - length) / 2, y: y))
                path.addLine(to: CGPoint(x: (size.width + length) / 2, y: y))
                context.stroke(path, with: .color(major ? HUDStyle.tickMajor : HUDStyle.tickMid), lineWidth: 1)
            }
        }
        .mask(LinearGradient(stops: [.init(color: .clear, location: 0),
                                    .init(color: .white, location: 0.2),
                                    .init(color: .white, location: 0.8),
                                    .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
    }
}
