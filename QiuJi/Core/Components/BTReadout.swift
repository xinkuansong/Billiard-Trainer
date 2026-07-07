import SwiftUI

/// 读数胶囊「仪表窗」（签名元素三，T-P18-45，设计稿 §1.4/§1.7）。
///
/// 所有数值读数统一式样：小号灰白 label + 等宽圆体 value。
/// value 语义色三通道：白 = 测量结果，金 = 可调/方案量值，红 = 失误。
/// 数字一律 `.rounded + monospacedDigit`。
///
/// 两种用法：
/// - 裸件：嵌进共享的仪表玻璃容器（一行多个读数时）。
/// - `.capsule` 包装：独立读数胶囊（自带 `btHudGlass` 底）。
struct BTReadout: View {
    enum Emphasis {
        /// 测量结果（白）。
        case measured
        /// 可调 / 方案量值（金）。
        case adjustable
        /// 失误 / 告警（红）。
        case alert

        var color: Color {
            switch self {
            case .measured: HUDStyle.valueMeasured
            case .adjustable: HUDStyle.valueAdjustable
            case .alert: HUDStyle.valueAlert
            }
        }
    }

    enum Size {
        /// 标准档：label 11pt / value 15pt。
        case regular
        /// 紧凑档（底部条、内联行）：label 10pt / value 13pt。
        case compact
    }

    var label: String? = nil
    let value: String
    var emphasis: Emphasis = .measured
    var size: Size = .regular
    /// 自带仪表玻璃胶囊底；false 时为裸件（嵌共享容器）。
    var standalone: Bool = false

    var body: some View {
        if standalone {
            pair
                .padding(.horizontal, size == .regular ? Spacing.md : Spacing.sm)
                .padding(.vertical, size == .regular ? 6 : 4)
                .btHudGlass()
        } else {
            pair
        }
    }

    private var pair: some View {
        HStack(spacing: 4) {
            if let label {
                Text(label)
                    .font(size == .regular ? HUDStyle.labelFont : HUDStyle.labelFontCompact)
                    .foregroundStyle(HUDStyle.labelColor)
            }
            Text(value)
                .font(size == .regular ? HUDStyle.valueFont : HUDStyle.valueFontCompact)
                .foregroundStyle(emphasis.color)
                .monospacedDigit()
        }
    }
}

#Preview("Readouts") {
    VStack(spacing: 20) {
        HStack(spacing: 16) {
            BTReadout(label: "切角", value: "29°")
            BTReadout(label: "力度", value: "2.4 m/s", emphasis: .adjustable)
            BTReadout(label: "误差", value: "12°", emphasis: .alert)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 6)
        .btHudGlass()

        BTReadout(label: "夹角", value: "36°", standalone: true)
        BTReadout(label: "力度", value: "2.4", emphasis: .adjustable, size: .compact, standalone: true)
    }
    .padding(40)
    .background(Color.black)
}
