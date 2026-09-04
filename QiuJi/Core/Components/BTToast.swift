import SwiftUI

/// Shared ephemeral toast tones (ui-polish W2-9 / F-OV-03).
/// Default placement: top capsule, auto-dismiss 1.6s.
enum BTToastTone: Equatable {
    case success
    case info
    case warning
    case error

    var color: Color {
        switch self {
        case .success: return .btSuccess
        case .info: return .btPrimary
        case .warning: return .btWarning
        case .error: return .btDestructive
        }
    }
}

struct BTToastMessage: Equatable {
    let text: String
    let tone: BTToastTone

    init(_ text: String, tone: BTToastTone = .success) {
        self.text = text
        self.tone = tone
    }
}

/// Top-anchored capsule toast chrome. AngleDynamic bottom status bar is a
/// persistent teaching-state exception and must **not** use this component
/// (F-OV-03 / OV-疑3).
struct BTToastBanner: View {
    let message: BTToastMessage

    var body: some View {
        VStack {
            Text(message.text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(message.tone.color, in: Capsule())
                .padding(.top, 60)
                .padding(.horizontal, Spacing.lg)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.move(edge: .top).combined(with: .opacity))
        .allowsHitTesting(false)
    }
}

enum BTToast {
    static let defaultDuration: TimeInterval = 1.6

    /// Present + auto-clear helper for `@State` / `@Published` toast bindings.
    /// Prefer this over page-local `flash` wrappers (G20 / C10).
    @MainActor
    static func present(
        _ text: String,
        tone: BTToastTone = .success,
        duration: TimeInterval = defaultDuration,
        assign: @escaping (BTToastMessage?) -> Void
    ) {
        withAnimation(BTMotion.easeChrome) {
            assign(BTToastMessage(text, tone: tone))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation(BTMotion.easeChrome) {
                assign(nil)
            }
        }
    }

    /// Convenience for `@Binding` / `@State` toast — same animation + duration as `present`.
    @MainActor
    static func flash(
        _ text: String,
        tone: BTToastTone = .success,
        duration: TimeInterval = defaultDuration,
        to message: Binding<BTToastMessage?>
    ) {
        present(text, tone: tone, duration: duration) { message.wrappedValue = $0 }
    }
}

private struct BTToastOverlayModifier: ViewModifier {
    @Binding var message: BTToastMessage?

    func body(content: Content) -> some View {
        content.overlay {
            if let message {
                BTToastBanner(message: message)
            }
        }
        .animation(BTMotion.easeChrome, value: message)
    }
}

extension View {
    /// Overlays a shared top toast when `message` is non-nil.
    func btToast(_ message: Binding<BTToastMessage?>) -> some View {
        modifier(BTToastOverlayModifier(message: message))
    }
}
