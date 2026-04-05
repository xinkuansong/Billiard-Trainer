import SwiftUI

// MARK: - BTButtonStyle

enum BTButtonStyle {
    case primary
    case secondary
    case text
    case destructive
    case darkPill
    case iconCircle
    case segmentedPill(isSelected: Bool)
}

extension BTButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        switch self {
        case .primary:
            PrimaryButtonBody(configuration: configuration)
        case .secondary:
            SecondaryButtonBody(configuration: configuration)
        case .text:
            TextButtonBody(configuration: configuration)
        case .destructive:
            DestructiveButtonBody(configuration: configuration)
        case .darkPill:
            DarkPillButtonBody(configuration: configuration)
        case .iconCircle:
            IconCircleButtonBody(configuration: configuration)
        case .segmentedPill(let isSelected):
            SegmentedPillButtonBody(configuration: configuration, isSelected: isSelected)
        }
    }
}

// MARK: - Primary

private struct PrimaryButtonBody: View {
    let configuration: ButtonStyleConfiguration

    var body: some View {
        configuration.label
            .font(.btHeadline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(configuration.isPressed ? Color.btPrimary.opacity(0.8) : Color.btPrimary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Secondary

private struct SecondaryButtonBody: View {
    let configuration: ButtonStyleConfiguration

    var body: some View {
        configuration.label
            .font(.btHeadline)
            .foregroundStyle(.btPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(.clear)
            .overlay(
                RoundedRectangle(cornerRadius: BTRadius.sm)
                    .stroke(Color.btPrimary, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Text

private struct TextButtonBody: View {
    let configuration: ButtonStyleConfiguration

    var body: some View {
        configuration.label
            .font(.btCallout)
            .foregroundStyle(configuration.isPressed ? Color.btPrimary.opacity(0.6) : .btPrimary)
            .frame(minHeight: 44)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Destructive

private struct DestructiveButtonBody: View {
    let configuration: ButtonStyleConfiguration

    var body: some View {
        configuration.label
            .font(.btHeadline)
            .foregroundStyle(.btDestructive)
            .frame(minHeight: 44)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Dark Pill

private struct DarkPillButtonBody: View {
    @Environment(\.colorScheme) private var colorScheme
    let configuration: ButtonStyleConfiguration

    private var fillColor: Color {
        colorScheme == .dark
            ? Color.btBGTertiary
            : Color(red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x1E / 255.0)
    }

    var body: some View {
        configuration.label
            .font(.btHeadline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(configuration.isPressed ? fillColor.opacity(0.8) : fillColor)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Icon Circle

private struct IconCircleButtonBody: View {
    let configuration: ButtonStyleConfiguration

    var body: some View {
        configuration.label
            .font(.btTitle2)
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(configuration.isPressed ? Color.btPrimary.opacity(0.8) : Color.btPrimary)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Segmented Pill

private struct SegmentedPillButtonBody: View {
    @Environment(\.colorScheme) private var colorScheme
    let configuration: ButtonStyleConfiguration
    let isSelected: Bool

    var body: some View {
        configuration.label
            .font(.btSubheadlineMedium)
            .foregroundStyle(isSelected ? .white : .btText)
            .padding(.horizontal, Spacing.lg)
            .frame(height: 36)
            .background(isSelected ? Color.btPrimary : Color.btBGSecondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.btSeparator, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Buttons Light") {
    ScrollView {
        VStack(spacing: Spacing.xl) {
            Group {
                Text("primary").font(.btCaption).foregroundStyle(.btTextSecondary)
                Button("开始训练") {}
                    .buttonStyle(BTButtonStyle.primary)
            }

            Group {
                Text("secondary").font(.btCaption).foregroundStyle(.btTextSecondary)
                Button("复制到今天") {}
                    .buttonStyle(BTButtonStyle.secondary)
            }

            Group {
                Text("text").font(.btCaption).foregroundStyle(.btTextSecondary)
                Button("跳过") {}
                    .buttonStyle(BTButtonStyle.text)
            }

            Group {
                Text("destructive").font(.btCaption).foregroundStyle(.btTextSecondary)
                Button("删除训练") {}
                    .buttonStyle(BTButtonStyle.destructive)
            }

            Group {
                Text("darkPill").font(.btCaption).foregroundStyle(.btTextSecondary)
                Button("关闭") {}
                    .buttonStyle(BTButtonStyle.darkPill)
            }

            Group {
                Text("iconCircle").font(.btCaption).foregroundStyle(.btTextSecondary)
                HStack(spacing: Spacing.lg) {
                    Button {} label: { Image(systemName: "plus") }
                        .buttonStyle(BTButtonStyle.iconCircle)
                    Button {} label: { Image(systemName: "checkmark") }
                        .buttonStyle(BTButtonStyle.iconCircle)
                }
            }

            Group {
                Text("segmentedPill").font(.btCaption).foregroundStyle(.btTextSecondary)
                HStack(spacing: Spacing.sm) {
                    Button("淳出") {}
                        .buttonStyle(BTButtonStyle.segmentedPill(isSelected: true))
                    Button("不淳出") {}
                        .buttonStyle(BTButtonStyle.segmentedPill(isSelected: false))
                    Button("延迟") {}
                        .buttonStyle(BTButtonStyle.segmentedPill(isSelected: false))
                }
            }
        }
        .padding(Spacing.xxl)
    }
    .background(Color.btBG)
}

#Preview("Buttons Dark") {
    ScrollView {
        VStack(spacing: Spacing.xl) {
            Group {
                Text("primary").font(.btCaption).foregroundStyle(.btTextSecondary)
                Button("开始训练") {}
                    .buttonStyle(BTButtonStyle.primary)
            }

            Group {
                Text("secondary").font(.btCaption).foregroundStyle(.btTextSecondary)
                Button("复制到今天") {}
                    .buttonStyle(BTButtonStyle.secondary)
            }

            Group {
                Text("text").font(.btCaption).foregroundStyle(.btTextSecondary)
                Button("跳过") {}
                    .buttonStyle(BTButtonStyle.text)
            }

            Group {
                Text("destructive").font(.btCaption).foregroundStyle(.btTextSecondary)
                Button("删除训练") {}
                    .buttonStyle(BTButtonStyle.destructive)
            }

            Group {
                Text("darkPill").font(.btCaption).foregroundStyle(.btTextSecondary)
                Button("关闭") {}
                    .buttonStyle(BTButtonStyle.darkPill)
            }

            Group {
                Text("iconCircle").font(.btCaption).foregroundStyle(.btTextSecondary)
                HStack(spacing: Spacing.lg) {
                    Button {} label: { Image(systemName: "plus") }
                        .buttonStyle(BTButtonStyle.iconCircle)
                    Button {} label: { Image(systemName: "checkmark") }
                        .buttonStyle(BTButtonStyle.iconCircle)
                }
            }

            Group {
                Text("segmentedPill").font(.btCaption).foregroundStyle(.btTextSecondary)
                HStack(spacing: Spacing.sm) {
                    Button("淳出") {}
                        .buttonStyle(BTButtonStyle.segmentedPill(isSelected: true))
                    Button("不淳出") {}
                        .buttonStyle(BTButtonStyle.segmentedPill(isSelected: false))
                    Button("延迟") {}
                        .buttonStyle(BTButtonStyle.segmentedPill(isSelected: false))
                }
            }
        }
        .padding(Spacing.xxl)
    }
    .background(Color.btBG)
    .preferredColorScheme(.dark)
}
