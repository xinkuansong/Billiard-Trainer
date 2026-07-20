import SwiftUI

/// 文档学页共享交互控件条（问题集合 v14 B1 / L4）。
///
/// 两档 + 通用读数行；API 一律 `Binding`，**不**绑定具体 ViewModel。
/// 视觉对齐现网：θ ← `AimingMethodsView` / `SpinAndEnglishView`；
/// 实况三轴 ← `AimingCorrectionView.sharedControls`。
enum LearnControlStrip {

    // MARK: - θ 档

    /// 切角 θ：标签「切角 θ」+ monospaced 读数 + Slider。
    /// 默认范围对齐现网 `5…75`、`step 1`。
    struct Theta: View {
        static let defaultRange: ClosedRange<Double> = 5...75
        static let defaultStep: Double = 1

        @Binding var cutAngleDeg: Double
        var range: ClosedRange<Double> = Self.defaultRange
        var step: Double = Self.defaultStep
        /// 可选说明（caption / tertiary）。
        var caption: String? = nil
        var accessibilityIdentifier: String? = nil

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.md) {
                LearnControlStrip.ReadoutRow(
                    label: "切角 θ",
                    value: "\(Int(cutAngleDeg.rounded()))°",
                    labelEmphasis: .primary,
                    valueSize: 16
                )
                Slider(value: $cutAngleDeg, in: range, step: step)
                    .tint(.btPrimary)
                    .accessibilityIdentifier(accessibilityIdentifier ?? "learnControlStrip.thetaSlider")
                if let caption, !caption.isEmpty {
                    Text(caption)
                        .font(.btCaption)
                        .foregroundStyle(.btTextTertiary)
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("learnControlStrip.theta")
        }
    }

    // MARK: - 实况三轴档

    /// 力度 Slider + 高低杆 segmented Picker + 左右塞 Slider。
    ///
    /// - `spinYTier` 使用教学三档枚举（与瞄准修正同口径），仍以 Binding 接入。
    /// - `spinXRange` / `spinXDisabled` 由调用方按打滑极限等语义提供。
    struct LiveAxes: View {
        @Binding var velocity: Double
        @Binding var spinYTier: AimingCorrectionMath.SpinYTier
        @Binding var spinX: Double

        var velocityRange: ClosedRange<Double> = ShotTuning.velocityRange
        var velocityStep: Double = 0.1
        var spinXRange: ClosedRange<Double>
        var spinXStep: Double = 0.01
        var spinXDisabled: Bool = false
        /// 自定义左右塞读数；`nil` 时用内置中塞/左塞/右塞格式。
        var spinXReadout: String? = nil
        var title: String = "实况参数"
        var footer: String? = nil
        var velocityAccessibilityIdentifier: String? = nil
        var spinYAccessibilityIdentifier: String? = nil
        var spinXAccessibilityIdentifier: String? = nil

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(title)
                    .font(.btSubheadlineMedium)
                    .foregroundStyle(.btText)

                LearnControlStrip.ReadoutRow(
                    label: "力度",
                    value: String(format: "%.1f m/s", velocity),
                    labelEmphasis: .secondary,
                    valueSize: 14
                )
                Slider(value: $velocity, in: velocityRange, step: velocityStep)
                    .tint(.btPrimary)
                    .accessibilityIdentifier(
                        velocityAccessibilityIdentifier ?? "learnControlStrip.velocitySlider"
                    )

                Text("高低杆")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                Picker("高低杆", selection: $spinYTier) {
                    ForEach(AimingCorrectionMath.SpinYTier.allCases) { tier in
                        Text(tier.label).tag(tier)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier(
                    spinYAccessibilityIdentifier ?? "learnControlStrip.spinYPicker"
                )

                LearnControlStrip.ReadoutRow(
                    label: "左右塞",
                    value: spinXReadout ?? Self.defaultSpinXReadout(spinX),
                    labelEmphasis: .secondary,
                    valueSize: 14
                )
                Slider(value: $spinX, in: spinXRange, step: spinXStep)
                    .tint(.btPrimary)
                    .disabled(spinXDisabled)
                    .accessibilityIdentifier(
                        spinXAccessibilityIdentifier ?? "learnControlStrip.spinXSlider"
                    )

                if let footer, !footer.isEmpty {
                    Text(footer)
                        .font(.btCaption)
                        .foregroundStyle(.btTextTertiary)
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("learnControlStrip.liveAxes")
        }

        /// 对齐 `AimingCorrectionView.spinXReadout`。
        static func defaultSpinXReadout(_ spinX: Double) -> String {
            if abs(spinX) < 0.005 { return "中塞 0" }
            let side = spinX > 0 ? "左塞" : "右塞"
            return String(format: "%@ %+.2f", side, spinX)
        }
    }

    // MARK: - 通用读数行

    /// 标签 + monospaced 读数（对照表角度行等可复用）。
    struct ReadoutRow: View {
        enum LabelEmphasis {
            /// 主控条标签（如「切角 θ」）：主色 + subheadline medium。
            case primary
            /// 轴内标签（如「力度」「左右塞」）：次级色 + caption。
            case secondary
        }

        let label: String
        let value: String
        var labelEmphasis: LabelEmphasis = .secondary
        var valueSize: CGFloat = 14
        var valueColor: Color = .btPrimary

        var body: some View {
            HStack {
                Text(label)
                    .font(labelEmphasis == .primary ? Font.btSubheadlineMedium : Font.btCaption)
                    .foregroundStyle(labelEmphasis == .primary ? Color.btText : Color.btTextSecondary)
                Spacer()
                Text(value)
                    .font(.system(size: valueSize, weight: .semibold, design: .monospaced))
                    .foregroundStyle(valueColor)
            }
        }
    }
}

#if DEBUG
#Preview("LearnControlStrip θ") {
    struct Host: View {
        @State private var theta = 30.0
        var body: some View {
            LearnControlStrip.Theta(
                cutAngleDeg: $theta,
                caption: "默认 5°–75°，step 1。"
            )
            .padding(Spacing.lg)
            .background(Color.btBG)
        }
    }
    return Host()
}

#Preview("LearnControlStrip LiveAxes") {
    struct Host: View {
        @State private var velocity = ShotTuning.defaultVelocity
        @State private var tier: AimingCorrectionMath.SpinYTier = .mid
        @State private var spinX = 0.0
        var body: some View {
            let lim = Double(CuePhysics.miscueLimitFraction)
            let rem = lim * lim - Double(tier.spinY) * Double(tier.spinY)
            let maxAbs = rem > 0 ? sqrt(rem) : 0
            return LearnControlStrip.LiveAxes(
                velocity: $velocity,
                spinYTier: $tier,
                spinX: $spinX,
                spinXRange: -max(maxAbs, 1e-6)...max(maxAbs, 1e-6),
                spinXDisabled: maxAbs < 1e-4,
                footer: "Preview：Binding 接入，不绑 ViewModel。"
            )
            .padding(Spacing.lg)
            .background(Color.btBG)
        }
    }
    return Host()
}
#endif
