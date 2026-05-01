import SwiftUI

/// In-app numeric keypad that replaces the system keyboard for angle entry.
/// Compact 3×4 grid with backspace and submit. Total height ≈ 250pt vs
/// system keyboard's ~290pt PLUS our wrapper, freeing ~50% of screen for the table.
struct NumericKeypadHUD: View {
    @Binding var input: String
    let title: String
    let subtitle: String?
    let onSubmit: () -> Void
    let onCancel: () -> Void

    private let maxLength = 3 // angles 0-90 (or 0-100 just in case)

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Header — title + subtitle + cancel button
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.btText)
                    if let subtitle {
                        Text(subtitle)
                            .font(.btCaption)
                            .foregroundStyle(.btTextSecondary)
                    }
                }
                Spacer()
                Button("取消", action: onCancel)
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)

            // Big number display
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(input.isEmpty ? "0" : input)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(input.isEmpty ? .btTextTertiary : .btText)
                    .contentTransition(.numericText())
                Text("°")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(.btTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)

            // 3×4 keypad grid
            VStack(spacing: 6) {
                keyRow(["1", "2", "3"])
                keyRow(["4", "5", "6"])
                keyRow(["7", "8", "9"])
                HStack(spacing: 6) {
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
        .background(.regularMaterial)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: BTRadius.lg,
                                          topTrailingRadius: BTRadius.lg))
        .shadow(color: .black.opacity(0.25), radius: 12, y: -4)
    }

    // MARK: - Helpers

    private func keyRow(_ digits: [String]) -> some View {
        HStack(spacing: 6) {
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
                        Image(systemName: icon).font(.system(size: 20, weight: .medium))
                    } else if let label {
                        Text(label)
                            .font(.system(size: role == .submit ? 17 : 24,
                                          weight: role == .submit ? .semibold : .regular,
                                          design: .rounded))
                    }
                }
                .foregroundStyle(role == .submit ? .white : .btText)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(background(for: role))
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
        }
        .buttonStyle(KeypadKeyStyle())
    }

    private func background(for role: KeyRole) -> some ShapeStyle {
        switch role {
        case .digit: return AnyShapeStyle(Color.btBGTertiary)
        case .erase: return AnyShapeStyle(Color.btBGSecondary)
        case .submit: return AnyShapeStyle(Color.btPrimary)
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
