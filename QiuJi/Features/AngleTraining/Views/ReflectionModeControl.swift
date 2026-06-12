import SwiftUI

/// 暗色场景页统一「胶囊分段」控件（统一设计语言，ADR-P11-07）：
/// 替代系统 `.segmented` picker——选中项为 tint 实底胶囊白字，未选为半透明胶囊；
/// 选项过宽时自动横向滚动。反射/翻袋的库数、理想/真实、袋口选择统一使用。
struct BTChipRow: View {
    let options: [String]
    @Binding var selection: Int
    var tint: Color = .btPrimary
    /// false 时不包 ScrollView（紧凑内联场合，如与其他控件同行）。
    var scrollable: Bool = true

    var body: some View {
        if scrollable {
            ScrollView(.horizontal, showsIndicators: false) { chips }
        } else {
            chips
        }
    }

    private var chips: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(options.indices, id: \.self) { i in
                Button { selection = i } label: {
                    Text(options[i])
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(selection == i ? .white : .white.opacity(0.7))
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(selection == i ? tint : Color.white.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// 翻袋 / 反射两页共用的「理想 / 真实」反射模式控件：
/// - 胶囊分段切换理想（入射角=反射角）与真实（反射偏短）；
/// - 真实模式下展开缩小因子滑块（0.50–1.00），用户可几次试打后拟合自己的球台 / 发力。
struct ReflectionModeControl: View {
    @Binding var realMode: Bool
    @Binding var factor: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            BTChipRow(
                options: ["理想", "真实"],
                selection: Binding(get: { realMode ? 1 : 0 }, set: { realMode = $0 == 1 })
            )

            if realMode {
                HStack(spacing: Spacing.sm) {
                    Text("缩小因子")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                    Slider(value: $factor, in: 0.50...1.00, step: 0.01)
                        .tint(.btAccent)
                    Text(String(format: "%.2f", factor))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.btAccent)
                        .frame(width: 40, alignment: .trailing)
                        .monospacedDigit()
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("1.00＝理想反射；越小反射越「偏短」。蓝色虚线为理想路线对照。")
                    .font(.btCaption2)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: realMode)
    }
}
