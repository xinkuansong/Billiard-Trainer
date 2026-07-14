import SwiftUI

struct BTFloatingIndicator: View {
    let elapsedSeconds: Int
    /// F-AT-04: shared resume copy with TrainingHome full-width bar.
    var title: String = "继续训练"
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
                Image(systemName: BTIcon.playCircle)
                    .font(.btCaption.weight(.semibold))
                Text(title)
                    .font(.btSubheadlineMedium)
                Text(timeString)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
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
        .buttonStyle(BTPressableStyle.capsule)
        .onAppear { isBreathing = true }
        .accessibilityLabel("\(title) \(timeString)，点击返回")
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
