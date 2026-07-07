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
                    // 状态语法（T-P18-45）：选中 = tint 实底白字；未选 = 仪表玻璃底 + 白 75% 字。
                    let label = Text(options[i])
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(selection == i ? .white : HUDStyle.chipTextUnselected)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 6)
                    if selection == i {
                        label.background(Capsule().fill(tint))
                    } else {
                        label.btHudGlass()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// 翻袋 / 反射两页共用的「理想 / 真实」反射模式控件：
/// - 胶囊分段切换理想（入射角=反射角）与真实（物理引擎按力度模拟，反射偏短）；
/// - 真实模式下**同行内联**力度滑块（m/s），力度越大越接近镜面反射、越小翻库越「偏短」。
/// - 单行紧凑形态（SPEC §8.4「顶部控制区 ≤2 行」，T-P18-32）；说明文案收进页面 (i) sheet。
struct ReflectionModeControl: View {
    @Binding var realMode: Bool
    @Binding var power: Double

    private static let minPower = Double(CushionReflectionSettings.minPower)
    private static let maxPower = Double(CushionReflectionSettings.maxPower)

    var body: some View {
        HStack(spacing: Spacing.sm) {
            BTChipRow(
                options: ["理想", "真实"],
                selection: Binding(get: { realMode ? 1 : 0 }, set: { realMode = $0 == 1 }),
                scrollable: false
            )

            if realMode {
                HStack(spacing: Spacing.sm) {
                    // 术语词表（T-P18-50）：发力 → 力度。
                    Text("力度")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                    Slider(value: $power, in: Self.minPower...Self.maxPower, step: 0.1)
                        .tint(.btAccent)
                        .frame(width: 120)
                    Text(String(format: "%.1f", power))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.btAccent)
                        .monospacedDigit()
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 4)
                .btHudGlass()
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: realMode)
    }
}
