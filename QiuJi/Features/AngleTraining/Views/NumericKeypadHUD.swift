import SwiftUI

/// In-app numeric keypad that replaces the system keyboard for angle entry.
/// Compact 3×4 grid with backspace and submit. Total height ≈ 250pt vs
/// system keyboard's ~290pt PLUS our wrapper, freeing ~50% of screen for the table.
struct NumericKeypadHUD: View {
    @Binding var input: String
    let title: String
    let subtitle: String?
    /// P5.1（问题集合 v3）：紧凑档——键高/读数再压一档，保证角度预测页
    /// 「换题 / 显示参考」按钮在键盘弹出时仍完整可见。
    var compact: Bool = false
    /// Table layout only: inline readout, no subtitle and no external shadow.
    /// Colors always follow the caller's color scheme, independently of this layout.
    var usesSceneStyle: Bool = false
    let onSubmit: () -> Void
    let onCancel: () -> Void

    private let maxLength = 3 // angles 0-90 (or 0-100 just in case)

    private var keyHeight: CGFloat { usesSceneStyle || compact ? 44 : 48 }
    private var displayFontSize: CGFloat { compact ? 24 : 38 }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Header — title + subtitle + cancel button
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.btFootnote.weight(.semibold))
                        .foregroundStyle(.btText)
                    if let subtitle, !usesSceneStyle {
                        Text(subtitle)
                            .font(.btCaption)
                            .foregroundStyle(.btTextSecondary)
                    }
                }
                Spacer()
                if usesSceneStyle {
                    angleReadout
                    Spacer()
                }
                Button(action: onCancel) {
                    Text("取消")
                        .font(.btCaption)
                        .foregroundStyle(.btTextSecondary)
                        .frame(minWidth: usesSceneStyle ? 44 : nil, minHeight: usesSceneStyle ? 44 : nil)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)

            if !usesSceneStyle {
                angleReadout
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, compact ? 2 : Spacing.xs)
            }

            // 3×4 keypad grid
            VStack(spacing: Spacing.xs) {
                keyRow(["1", "2", "3"])
                keyRow(["4", "5", "6"])
                keyRow(["7", "8", "9"])
                HStack(spacing: Spacing.xs) {
                    keyButton(label: nil, icon: "delete.left", role: .erase) { backspace() }
                    digitButton("0")
                    keyButton(label: "提交", icon: nil, role: .submit) {
                        guard !input.isEmpty else { return }
                        onSubmit()
                    }
                    .disabled(input.isEmpty)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.sm)
        }
        .background(usesSceneStyle ? AnyShapeStyle(Color.btBGSecondary) : AnyShapeStyle(.regularMaterial))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: BTRadius.lg,
                                          topTrailingRadius: BTRadius.lg))
        .shadow(color: .black.opacity(0.25), radius: usesSceneStyle ? 0 : 12, y: -4)
    }

    private var angleReadout: some View {
        HStack(alignment: .lastTextBaseline, spacing: Spacing.xs) {
            Text(input.isEmpty ? "0" : input)
                .font(.system(size: displayFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(input.isEmpty ? .btTextTertiary : .btText)
                .contentTransition(.numericText())
            Text("°")
                .font(.system(size: displayFontSize * 0.68, weight: .semibold, design: .rounded))
                .foregroundStyle(.btTextSecondary)
        }
    }

    // MARK: - Helpers

    private func keyRow(_ digits: [String]) -> some View {
        HStack(spacing: Spacing.xs) {
            ForEach(digits, id: \.self) { digitButton($0) }
        }
    }

    private func digitButton(_ d: String) -> some View {
        keyButton(label: d, icon: nil, role: .digit) { append(d) }
    }

    private enum KeyRole { case digit, erase, submit }

    private func keyButton(label: String?, icon: String?, role: KeyRole,
                           action: @escaping () -> Void) -> some View {
        Button(action: {
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            action()
        }) {
            ZStack {
                Group {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: compact ? 17 : 20, weight: .medium))
                    } else if let label {
                        Text(label)
                            .font(.system(size: role == .submit ? (compact ? 15 : 17)
                                                                : (compact ? 20 : 24),
                                          weight: role == .submit ? .semibold : .regular,
                                          design: .rounded))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: keyHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(KeypadKeyStyle(normalBackground: background(for: role)))
    }

    private func background(for role: KeyRole) -> Color {
        switch role {
        case .digit, .submit: return .btBGTertiary
        case .erase: return .btBGSecondary
        }
    }

    private func append(_ digit: String) {
        guard input.count < maxLength else { return }
        if input == "0" { input = "" }
        input.append(digit)
    }

    private func backspace() {
        guard !input.isEmpty else { return }
        input.removeLast()
    }
}

private struct KeypadKeyStyle: ButtonStyle {
    let normalBackground: Color
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = isEnabled && configuration.isPressed
        return configuration.label
            .foregroundStyle(Color.btText)
            .background(pressed ? HUDStyle.selectedBackground : normalBackground,
                        in: RoundedRectangle(cornerRadius: BTRadius.sm))
            .overlay {
                RoundedRectangle(cornerRadius: BTRadius.sm)
                    .stroke(Color.btSeparator, lineWidth: HUDStyle.hairlineWidth)
            }
            .scaleEffect(pressed ? 0.95 : 1)
            .opacity(isEnabled ? 1 : HUDStyle.chipTextDisabledOpacity)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

#Preview("Keypad Light") {
    NumericKeypadHUD(input: .constant("28"), title: "第1题", subtitle: nil,
                     compact: true, usesSceneStyle: true, onSubmit: {}, onCancel: {})
        .environment(\.colorScheme, .light)
}

#Preview("Keypad Dark") {
    NumericKeypadHUD(input: .constant("28"), title: "第1题", subtitle: nil,
                     compact: true, usesSceneStyle: true, onSubmit: {}, onCancel: {})
        .environment(\.colorScheme, .dark)
}
