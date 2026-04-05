import SwiftUI

struct BTFloatingIndicator: View {
    let elapsedSeconds: Int
    var onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isBreathing = false

    private var timeString: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                Text("训练中")
                    .font(.btSubheadlineMedium)
                Text(timeString)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                Image(systemName: "chevron.left")
                    .font(.btCaption2)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.lg)
            .frame(height: 44)
            .background(Color.btPrimary)
            .clipShape(Capsule())
            .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.15), radius: 8, x: 0, y: 2)
            .offset(y: isBreathing ? -2 : 2)
            .animation(
                .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                value: isBreathing
            )
        }
        .buttonStyle(.plain)
        .onAppear { isBreathing = true }
        .accessibilityLabel("训练进行中 \(timeString)，点击返回")
    }
}

// MARK: - Preview

#Preview("BTFloatingIndicator Light") {
    VStack {
        Spacer()
        HStack {
            Spacer()
            BTFloatingIndicator(elapsedSeconds: 754) {}
                .padding(.trailing, Spacing.lg)
                .padding(.bottom, Spacing.sm)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.btBG)
}

#Preview("BTFloatingIndicator Dark") {
    VStack {
        Spacer()
        HStack {
            Spacer()
            BTFloatingIndicator(elapsedSeconds: 754) {}
                .padding(.trailing, Spacing.lg)
                .padding(.bottom, Spacing.sm)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.btBG)
    .preferredColorScheme(.dark)
}
