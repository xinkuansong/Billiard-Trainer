import SwiftUI

// MARK: - 自由瞄准角度齿轮（竖向棘轮标尺）

/// 贴球桌左缘的竖向刻度齿轮：拖动微调自由瞄准方向（控件瘦身 v2，问题集合条 13.1）。
///
/// **纯相对微调**——无绝对角度概念（去 bearing 刻度锚定）：手指滑屏是粗调、
/// 这里是细调，刻度只是「转了多少」的手感反馈，不代表任何绝对方位。
/// 内容跟手——往上拖刻度上滚（= 屏幕顺时针/向右）。
///
/// Slow vertical dragging continuously reduces the base gain down to 10%; coarse dragging retains it.
/// 默认基础灵敏度 `AimWheelGain.defaultDegreesPerPoint`（0.15°/pt）。v23 瞄准点页可传入
/// 连续毫米口径增益（D-v23-4=B）并关闭整度触感（D-v23-6）。
///
/// T-P18-43（设计稿 §1.5/§1.7 刻度语法）：**只画刻度不画数值**——打点精确到毫米级，
/// 用户看台面效果；三级刻度随精度缩放，白 15/25/40%，当前位置金线保持居中。
struct BTAimWheel: View {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onNudge: (Float) -> Void
    /// Degrees of aim rotation per point of vertical drag.
    var degreesPerPoint: Float = AimWheelGain.defaultDegreesPerPoint
    /// Legacy angular detents (1° coarse / 0.1° fine) when travel feedback is off.
    var degreeHapticEnabled: Bool = true
    /// Detents for 8 base points of travel, subdivided tenfold at fine precision.
    var travelHapticEnabled: Bool = true
    /// Drag lifecycle for closeup HUD gating (近区 ∧ 正在改瞄准).
    var onDragActiveChanged: ((Bool) -> Void)? = nil

    var visibleWidth: CGFloat? = nil
    var usesCompactAppearance = true
    /// Hosts with a combined instrument shell may provide their own footer.
    var showsDirectionLabel = true

    private var pointsPerDegree: CGFloat {
        let dpp = max(lockedGain ?? degreesPerPoint, 1e-4)
        return CGFloat(1 / dpp)
    }

    /// 相对累计转量（度），只用于刻度滚动的视觉反馈。
    @State private var accumulated: Double = 0
    @State private var adaptiveDrag = AdaptiveShotDrag()
    @State private var detents = ShotDragDetents()
    @State private var soundDetents = ShotDragDetents(minimumInterval: ShotDragDetents.soundMinimumInterval)
    @State private var precisionScale = ShotPrecisionScale()
    @State private var dragStarted = false
    @GestureState private var gestureActive = false
    /// Lock ball-distance calibration, while DR-336 varies the speed multiplier continuously.
    @State private var lockedGain: Float?
    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        GeometryReader { geo in
            let h = max(1, geo.size.height - (showsDirectionLabel ? 24 : 0))
            VStack(spacing: 4) {
              ZStack {
                RoundedRectangle(cornerRadius: HUDStyle.rulerCornerRadius, style: .continuous)
                    .fill(usesCompactAppearance ? HUDStyle.controlBackground : HUDStyle.glassTint)
                    .overlay(RoundedRectangle(cornerRadius: HUDStyle.rulerCornerRadius, style: .continuous)
                        .stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))

                BTAimPrecisionRuler(value: accumulated,
                                    pointsPerDegree: Double(pointsPerDegree),
                                    magnification: precisionScale.magnification)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: precisionScale.isFine)
                .clipShape(RoundedRectangle(cornerRadius: HUDStyle.rulerCornerRadius, style: .continuous))

                // 当前位置指示 = 金色短线（§1.7 刻度语法）。
                Rectangle()
                    .fill(HUDStyle.tickIndicator)
                    .frame(height: 1.5)
            }
              .frame(height: h)
              if showsDirectionLabel {
                  Text("方向").font(.btMicro).foregroundStyle(HUDStyle.labelColor)
                      .frame(height: 20)
              }
            }
            .background(usesCompactAppearance ? HUDStyle.controlBackground : .clear,
                        in: RoundedRectangle(cornerRadius: HUDStyle.rulerCornerRadius))
            .frame(width: visibleWidth ?? geo.size.width)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($gestureActive) { _, active, _ in active = true }
                    .onChanged { v in
                        guard isEnabled else { finishDrag(); return }
                        if !dragStarted {
                            dragStarted = true
                            lockedGain = degreesPerPoint
                            precisionScale.resetTiming()
                            haptic.prepare()
                            if UserPreferences.shared.soundEffectsEnabled { ShotSoundBank.shared.prepare() }
                            onDragActiveChanged?(true)
                        }
                        let time = v.time.timeIntervalSinceReferenceDate
                        let sample = adaptiveDrag.update(translation: Double(v.translation.height), time: time)
                        let delta = Float(-sample.delta) * (lockedGain ?? degreesPerPoint)
                        if delta != 0 {
                            onNudge(delta)
                            accumulated += Double(delta)
                        }
                        precisionScale.update(sample: sample, time: time)
                        do {
                            let position = accumulated
                            let usesTravelDetents = travelHapticEnabled || !degreeHapticEnabled
                            let baseStep = usesTravelDetents ? 8 * Double(lockedGain ?? degreesPerPoint) : 1
                            let spacing = baseStep * precisionScale.stepMultiplier
                            if let intensity = detents.intensity(position: position, spacing: spacing,
                                                                 sample: sample, time: time) {
                                if travelHapticEnabled || degreeHapticEnabled {
                                    haptic.impactOccurred(intensity: CGFloat(intensity))
                                }
                            }
                            if let intensity = soundDetents.intensity(position: position, spacing: spacing,
                                                                      sample: sample, time: time) {
                                ShotSoundBank.shared.playControlTick(intensity: intensity, control: .aim)
                            }
                        }
                    }
                    .onEnded { _ in
                        finishDrag()
                    }
            )
        }
        .onChange(of: gestureActive) { _, active in
            if !active { finishDrag() }
        }
        .onChange(of: isEnabled) { _, enabled in
            if !enabled { finishDrag() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { finishDrag() }
        }
        .onDisappear { finishDrag() }
        .accessibilityElement()
        .accessibilityLabel("瞄准微调")
        .accessibilityHint("上划向右微调，下划向左微调")
        .accessibilityValue(precisionScale.isFine ? "精细刻度" : "常规刻度")
        .accessibilityAdjustableAction { direction in
            guard isEnabled else { return }
            let delta: Float
            switch direction {
            case .increment: delta = degreesPerPoint
            case .decrement: delta = -degreesPerPoint
            @unknown default: return
            }
            onDragActiveChanged?(true)
            onNudge(delta)
            accumulated += Double(delta)
            onDragActiveChanged?(false)
        }
        .accessibilityIdentifier("shotStage.aimWheel")
    }
    private func finishDrag() {
        guard dragStarted else { return }
        adaptiveDrag = AdaptiveShotDrag()
        detents = ShotDragDetents()
        soundDetents = ShotDragDetents(minimumInterval: ShotDragDetents.soundMinimumInterval)
        precisionScale.resetTiming()
        dragStarted = false
        lockedGain = nil
        onDragActiveChanged?(false)
    }

}

// MARK: - Thickness Overlap Icon

/// 用两个等大圆形错位重叠表示"厚度"：
/// 在击球瞬间，沿瞄准方向看，目标球与白球的中心横向偏移量为 `2R · sin(α)`。
/// 把它直接映射到画布即可：α 越小重叠越多（"厚"），α 越大错位越多（"薄"）。
/// 原生于角度与打点页（private），P18 B2 下沉共享并参数化尺寸。
struct ThicknessOverlapIcon: View {
    /// 切球角，单位：度。
    let cutAngle: Double
    /// 图标尺寸（宽:高 ≈ 2:1 视觉最佳）。
    var size: CGSize = CGSize(width: 26, height: 14)

    var body: some View {
        Canvas { ctx, canvasSize in
            // 单球半径选择：让最大错位（α=90°，offset=2R）时两球刚好首尾相接、不出画布。
            // 因此 r = size.width / 4。再做一次 0.96 收缩留 1px 描边的余量。
            let r = (canvasSize.width / 4) * 0.96
            let centerY = canvasSize.height / 2

            let alphaRad = max(0, min(90, cutAngle)) * .pi / 180
            let offset = CGFloat(2 * r * sin(alphaRad))  // 球心横向偏移量

            // 让两个球关于画布中心对称错开：目标球居左、白球居右。
            let targetCenter = CGPoint(x: canvasSize.width / 2 - offset / 2, y: centerY)
            let cueCenter    = CGPoint(x: canvasSize.width / 2 + offset / 2, y: centerY)

            // 目标球（暖色）：实心 + 描边
            let targetRect = CGRect(x: targetCenter.x - r, y: targetCenter.y - r,
                                    width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: targetRect),
                     with: .color(Color(red: 0.96, green: 0.65, blue: 0.14)))
            ctx.stroke(Path(ellipseIn: targetRect),
                       with: .color(.white.opacity(0.5)), lineWidth: 0.5)

            // 白球：实心白 + 微弱描边，覆盖在目标球之上以呈现"被遮挡"的厚度
            let cueRect = CGRect(x: cueCenter.x - r, y: cueCenter.y - r,
                                 width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: cueRect), with: .color(.white))
            ctx.stroke(Path(ellipseIn: cueRect),
                       with: .color(.white.opacity(0.6)), lineWidth: 0.5)
        }
        .frame(width: size.width, height: size.height)
    }
}


/// The current value remains at the center throughout the animated zoom.
private struct BTAimPrecisionRuler: View, Animatable {
    let value: Double
    let pointsPerDegree: Double
    var magnification: Double

    var animatableData: Double {
        get { magnification }
        set { magnification = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let fineStep = 0.8 / pointsPerDegree
            let pixelsPerDegree = pointsPerDegree * magnification
            let halfSpan = Double(size.height) / pixelsPerDegree / 2
            let first = Int(floor((value - halfSpan) / fineStep))
            let last = Int(ceil((value + halfSpan) / fineStep))
            for index in first...last {
                let major = index.isMultiple(of: 10)
                let medium = index.isMultiple(of: 5)
                let spacing = fineStep * pixelsPerDegree * (major ? 10 : medium ? 5 : 1)
                let opacity = ShotRulerTicks.opacity(spacing: spacing)
                guard opacity > 0 else { continue }
                let y = size.height / 2 + CGFloat((Double(index) * fineStep - value) * pixelsPerDegree)
                let length = size.width * (major ? 0.62 : medium ? 0.42 : 0.26)
                var path = Path()
                path.move(to: CGPoint(x: (size.width - length) / 2, y: y))
                path.addLine(to: CGPoint(x: (size.width + length) / 2, y: y))
                context.stroke(path, with: .color(HUDStyle.tickColor(major: major, mid: medium).opacity(opacity)),
                               lineWidth: major ? 1.4 : 0.8)
            }
        }
    }
}
