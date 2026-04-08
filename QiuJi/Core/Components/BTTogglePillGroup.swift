import SwiftUI

struct BTTogglePillGroup<T: Hashable>: View {
    let options: [T]
    @Binding var selected: T
    let label: (T) -> String

    @Environment(\.colorScheme) private var colorScheme

    private func fillColor(isActive: Bool) -> Color {
        if isActive {
            return colorScheme == .dark
                ? Color(red: 0.95, green: 0.95, blue: 0.97)
                : Color.btPrimary
        }
        return colorScheme == .dark ? Color.btBGTertiary : Color.btBGSecondary
    }

    private func textColor(isActive: Bool) -> Color {
        if isActive {
            return colorScheme == .dark ? .black : .white
        }
        return colorScheme == .dark ? Color.btTextSecondary : .btText
    }

    private func textFont(isActive: Bool) -> Font {
        isActive && colorScheme == .dark ? .btSubheadlineSemibold : .btSubheadlineMedium
    }

    private func borderColor(isActive: Bool) -> Color {
        if isActive { return .clear }
        return colorScheme == .dark ? Color.btBGQuaternary : Color.btSeparator
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(options, id: \.self) { option in
                let isActive = option == selected
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selected = option
                    }
                } label: {
                    Text(label(option))
                        .font(textFont(isActive: isActive))
                        .foregroundStyle(textColor(isActive: isActive))
                        .padding(.horizontal, Spacing.md)
                        .frame(height: 36)
                        .background(fillColor(isActive: isActive))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(borderColor(isActive: isActive), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label(option))
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
    }
}

// MARK: - Preview

private enum TimerMode: String, CaseIterable {
    case countdown = "倒计时"
    case countup = "正计时"
}

private enum MetricType: String, CaseIterable {
    case rate = "成功率"
    case balls = "进球数"
    case duration = "用时"
}

private enum LevelFilter: String, CaseIterable {
    case all = "全"
    case beginner = "入"
    case elementary = "初"
    case intermediate = "中"
    case advanced = "高"
}

#Preview("BTTogglePillGroup Light") {
    VStack(spacing: Spacing.xxl) {
        StatefulPillPreview(TimerMode.countdown) { binding in
            BTTogglePillGroup(options: TimerMode.allCases, selected: binding) { $0.rawValue }
        }
        StatefulPillPreview(MetricType.rate) { binding in
            BTTogglePillGroup(options: MetricType.allCases, selected: binding) { $0.rawValue }
        }
        StatefulPillPreview(LevelFilter.all) { binding in
            BTTogglePillGroup(options: LevelFilter.allCases, selected: binding) { $0.rawValue }
        }
    }
    .padding(Spacing.xxl)
    .background(Color.btBG)
}

#Preview("BTTogglePillGroup Dark") {
    VStack(spacing: Spacing.xxl) {
        StatefulPillPreview(TimerMode.countdown) { binding in
            BTTogglePillGroup(options: TimerMode.allCases, selected: binding) { $0.rawValue }
        }
        StatefulPillPreview(MetricType.rate) { binding in
            BTTogglePillGroup(options: MetricType.allCases, selected: binding) { $0.rawValue }
        }
        StatefulPillPreview(LevelFilter.all) { binding in
            BTTogglePillGroup(options: LevelFilter.allCases, selected: binding) { $0.rawValue }
        }
    }
    .padding(Spacing.xxl)
    .background(Color.btBG)
    .preferredColorScheme(.dark)
}

private struct StatefulPillPreview<Value, Content: View>: View {
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
