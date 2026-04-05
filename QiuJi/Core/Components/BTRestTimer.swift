import SwiftUI

struct BTRestTimer: View {
    let totalSeconds: Int
    @Binding var remainingSeconds: Int
    var onComplete: () -> Void
    var onExtend: (Int) -> Void

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - Double(remainingSeconds) / Double(totalSeconds)
    }

    private var timeString: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: Spacing.xxl) {
            timerRing
            buttonRow
        }
    }

    // MARK: - Timer Ring

    private var timerRing: some View {
        ZStack {
            Circle()
                .stroke(Color.btBGQuaternary, lineWidth: 8)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.btPrimary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Circle()
                .trim(from: 0, to: progress * 0.8)
                .stroke(Color.btAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(14)

            VStack(spacing: 2) {
                Text(timeString)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.btText)
                    .monospacedDigit()

                Text("组间休息")
                    .font(.btFootnote)
                    .foregroundStyle(.btTextSecondary)
            }
        }
        .frame(width: 200, height: 200)
        .accessibilityLabel("休息倒计时 \(timeString)")
    }

    // MARK: - Buttons

    private var buttonRow: some View {
        HStack(spacing: Spacing.md) {
            Button("+30S") { onExtend(30) }
                .buttonStyle(BTButtonStyle.secondary)
                .frame(maxWidth: .infinity)

            Button("完成休息") { onComplete() }
                .buttonStyle(BTButtonStyle.primary)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Preview

#Preview("BTRestTimer Light") {
    RestTimerPreview()
        .background(Color.btBG)
}

#Preview("BTRestTimer Dark") {
    RestTimerPreview()
        .background(Color.btBG)
        .preferredColorScheme(.dark)
}

private struct RestTimerPreview: View {
    @State private var remaining = 23

    var body: some View {
        BTRestTimer(
            totalSeconds: 60,
            remainingSeconds: $remaining,
            onComplete: {},
            onExtend: { remaining += $0 }
        )
        .padding(Spacing.xxl)
    }
}
