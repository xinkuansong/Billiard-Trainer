import SwiftUI

/// 翻袋 / 反射两页共用的「理想 / 真实」反射模式控件：
/// - 分段开关切换理想（入射角=反射角）与真实（反射偏短）；
/// - 真实模式下展开缩小因子滑块（0.50–1.00），用户可几次试打后拟合自己的球台 / 发力。
struct ReflectionModeControl: View {
    @Binding var realMode: Bool
    @Binding var factor: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Picker("反射模式", selection: $realMode) {
                Text("理想").tag(false)
                Text("真实").tag(true)
            }
            .pickerStyle(.segmented)
            .environment(\.colorScheme, .dark)

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
