import SwiftUI

struct BTSegmentedTab<T: Hashable>: View {
    let tabs: [T]
    @Binding var selected: T
    let label: (T) -> String
    /// 可选无障碍标识前缀：每个分段按钮获得 `"\(prefix)_\(label)"` 标识，
    /// 供 UI 测试在标签与底部 Tab 重名时（如「训练」）精确定位。
    var accessibilityIdentifierPrefix: String? = nil

    @Namespace private var underline

    var body: some View {
        HStack(spacing: 24) {
            ForEach(tabs, id: \.self) { tab in
                let isActive = tab == selected
                Button {
                    withAnimation(BTMotion.easeFast) {
                        selected = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(label(tab))
                            .font(.btCallout)
                            .fontWeight(.medium)
                            .foregroundStyle(isActive ? Color.btPrimary : Color.btTextSecondary)

                        if isActive {
                            Capsule()
                                .fill(Color.btPrimary)
                                .frame(height: 2)
                                .matchedGeometryEffect(id: "underline", in: underline)
                        } else {
                            Capsule()
                                .fill(Color.clear)
                                .frame(height: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label(tab))
                .accessibilityIdentifier(
                    accessibilityIdentifierPrefix.map { "\($0)_\(label(tab))" } ?? ""
                )
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
    }
}

// MARK: - Preview

private enum SampleTab: String, CaseIterable {
    case history = "历史"
    case stats = "统计"
}

private enum PlanTab: String, CaseIterable {
    case official = "官方计划"
    case custom = "自定义模板"
    case personal = "个人计划"
}

#Preview("BTSegmentedTab Light") {
    VStack(spacing: Spacing.xxxl) {
        StatefulPreview(SampleTab.history) { binding in
            BTSegmentedTab(tabs: SampleTab.allCases, selected: binding) { $0.rawValue }
        }
        StatefulPreview(PlanTab.official) { binding in
            BTSegmentedTab(tabs: PlanTab.allCases, selected: binding) { $0.rawValue }
        }
    }
    .padding(Spacing.xxl)
    .background(Color.btBG)
}

#Preview("BTSegmentedTab Dark") {
    VStack(spacing: Spacing.xxxl) {
        StatefulPreview(SampleTab.history) { binding in
            BTSegmentedTab(tabs: SampleTab.allCases, selected: binding) { $0.rawValue }
        }
        StatefulPreview(PlanTab.official) { binding in
            BTSegmentedTab(tabs: PlanTab.allCases, selected: binding) { $0.rawValue }
        }
    }
    .padding(Spacing.xxl)
    .background(Color.btBG)
    .preferredColorScheme(.dark)
}

/// Wrapper to provide @State in previews
private struct StatefulPreview<Value, Content: View>: View {
    @State private var value: Value
    let content: (Binding<Value>) -> Content

    init(_ initialValue: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: initialValue)
        self.content = content
    }

    var body: some View {
        content($value)
    }
}
