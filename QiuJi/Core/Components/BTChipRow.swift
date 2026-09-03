import SwiftUI

/// 暗色场景页统一「胶囊分段」控件（统一设计语言，ADR-P11-07）：
/// 替代系统 `.segmented` picker——选中项为 tint 实底胶囊白字，未选为半透明胶囊；
/// 选项过宽时自动横向滚动。翻袋/反射的库数、袋口选择等统一使用。
/// （原与 `ReflectionModeControl` 同文件；该控件随「理想/真实」模式于 W4 退役后独立成文件。）
struct BTChipRow: View {
    let options: [String]
    @Binding var selection: Int
    var tint: Color = .btPrimary
    /// false 时不包 ScrollView（紧凑内联场合，如与其他控件同行）。
    var scrollable: Bool = true
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if scrollable || dynamicTypeSize.isAccessibilitySize {
            scrollableChips
        } else {
            ViewThatFits(in: .horizontal) {
                chips
                    .fixedSize(horizontal: true, vertical: false)
                scrollableChips
            }
        }
    }

    private var scrollableChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            chips
                .fixedSize(horizontal: true, vertical: false)
        }
        .accessibilityIdentifier("shotStage.chipRow")
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
                        .frame(minHeight: 44)
                    if selection == i {
                        label.background(Capsule().fill(tint))
                    } else {
                        label.btHudGlass()
                    }
                }
                .buttonStyle(BTPressableStyle.capsule)
                .accessibilityIdentifier("shotStage.chip.\(i)")
            }
        }
    }
}
