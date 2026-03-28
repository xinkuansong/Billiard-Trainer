import SwiftUI

// MARK: - BTButtonStyle

enum BTButtonStyle {
    case primary
    case secondary
    case text
    case destructive
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
        }
    }
}

// MARK: - 主按钮

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

// MARK: - 次级按钮

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

// MARK: - 文字按钮

private struct TextButtonBody: View {
    let configuration: ButtonStyleConfiguration

    var body: some View {
        configuration.label
            .font(.btCallout)
            .foregroundStyle(configuration.isPressed ? Color.btPrimary.opacity(0.6) : .btPrimary)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - 危险按钮

private struct DestructiveButtonBody: View {
    let configuration: ButtonStyleConfiguration

    var body: some View {
        configuration.label
            .font(.btHeadline)
            .foregroundStyle(.btDestructive)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Buttons Light") {
    VStack(spacing: Spacing.lg) {
        Button("开始训练") {}
            .buttonStyle(BTButtonStyle.primary)
        Button("查看详情") {}
            .buttonStyle(BTButtonStyle.secondary)
        Button("跳过") {}
            .buttonStyle(BTButtonStyle.text)
        Button("注销账号") {}
            .buttonStyle(BTButtonStyle.destructive)
    }
    .padding(Spacing.xxl)
    .background(Color.btBG)
}

#Preview("Buttons Dark") {
    VStack(spacing: Spacing.lg) {
        Button("开始训练") {}
            .buttonStyle(BTButtonStyle.primary)
        Button("查看详情") {}
            .buttonStyle(BTButtonStyle.secondary)
        Button("跳过") {}
            .buttonStyle(BTButtonStyle.text)
        Button("注销账号") {}
            .buttonStyle(BTButtonStyle.destructive)
    }
    .padding(Spacing.xxl)
    .background(Color.btBG)
    .preferredColorScheme(.dark)
}
