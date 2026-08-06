import SwiftUI

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

    @State private var lastDetent: Int = .min
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
                    BTSpinMiniIcon(spinX: spinX, spinY: spinY, diameter: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("打点")
                .disabled(isDisabled || !spinTapEnabled)
            }

            // 两行读数（条 13.2）：上 = 力度名，下 = 速度值；fixedSize 防折行。
            VStack(spacing: 0) {
                Text(PowerDisplay.name(velocity))
                    .font(HUDStyle.labelFontCompact)
                    .foregroundStyle(HUDStyle.labelColor)
                Text(String(format: "%.1f", velocity))
                    .font(HUDStyle.valueFontCompact)
                    .foregroundStyle(HUDStyle.valueAdjustable)
                    .monospacedDigit()
            }
            .fixedSize()

            powerBar
        }
        .opacity(isDisabled ? 0.5 : 1)
    }

    // MARK: - Power bar

    private var powerBar: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = geo.size.width
            let levelY = h * (1 - fraction)
            ZStack {
                RoundedRectangle(cornerRadius: HUDStyle.rulerCornerRadius, style: .continuous)
                    .fill(HUDStyle.glassTint)
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
                Rectangle()
                    .fill(HUDStyle.tickIndicator)
                    .frame(width: w, height: 1.5)
                    .position(x: w / 2, y: min(max(levelY, 2), h - 2))
            }
            .contentShape(Rectangle())
            .gesture(isDisabled || isReadOnly ? nil : dragGesture(height: h))
        }
    }

    /// 拖动阻尼系数（条 13.2「滑动阻尼感」）：手指位移只按 0.6 折算到水位——
    /// 移动比手指慢、更像拨有阻尼的实体推子；配合逐档 haptic 形成「减速+棘轮」手感。
    private let dragDamping: CGFloat = 0.6

    private func dragGesture(height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { g in
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
            .onEnded { _ in
                lastDetent = .min
                lastDragY = nil
                dragFrac = nil
            }
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
