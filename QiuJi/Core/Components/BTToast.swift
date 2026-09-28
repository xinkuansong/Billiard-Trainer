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
            BTNoticeContent(message: message)
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

/// Rule and aiming notices share one queue so a mode update cannot erase a foul.
@MainActor
final class BTRuleNoticeCenter: ObservableObject {
    enum Priority: Int { case mode, selection, ruling, terminal }
    @Published private(set) var message: BTToastMessage?
    private var priority: Priority = .mode
    private var generation = UUID()

    func clear() { generation = UUID(); message = nil; priority = .mode }

    func clearSelectionNotice() {
        guard priority == .selection else { return }
        generation = UUID()
        message = nil
    }

    func show(_ text: String, tone: BTToastTone, priority next: Priority,
              duration: TimeInterval = 3) {
        guard message == nil || next.rawValue >= priority.rawValue else { return }
        let repeated = message?.text == text
        priority = next
        let token = UUID()
        generation = token
        if !repeated { message = BTToastMessage(text, tone: tone) }
        if !repeated && UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: text)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self, self.generation == token else { return }
            self.message = nil
        }
    }
}

/// The same quiet surface for short feedback on ordinary and scene pages.
struct BTNoticeContent: View {
    let message: BTToastMessage
    var compact = false
    var textOnly = false
    private var symbol: String {
        switch message.tone {
        case .success: return "checkmark.circle"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.circle"
        case .error: return "exclamationmark.triangle"
        }
    }
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Image(systemName: symbol).foregroundStyle(textOnly ? Color.white : message.tone.color)
                .accessibilityHidden(true)
            Text(message.text).foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.btFootnote)
        .padding(.horizontal, Spacing.md).padding(.vertical, compact ? Spacing.xs : Spacing.sm)
        .background(textOnly ? Color.clear : HUDStyle.panelBackground, in: RoundedRectangle(cornerRadius: BTRadius.md))
        .overlay(RoundedRectangle(cornerRadius: BTRadius.md)
            .stroke(textOnly ? Color.clear : HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
        .shadow(color: textOnly ? .black.opacity(0.85) : .clear, radius: 2, y: 1)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 460)
        .allowsHitTesting(false)
    }
}

/// Decision surfaces share geometry and action hierarchy; hosts own their rules.
struct BTDecisionPanel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: Spacing.md) { content }
                .padding(Spacing.lg)
                .frame(maxWidth: 360)
                .background(HUDStyle.panelBackground, in: RoundedRectangle(cornerRadius: BTRadius.lg))
                .overlay(RoundedRectangle(cornerRadius: BTRadius.lg)
                    .stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
                .foregroundStyle(.white)
                .padding(Spacing.lg)
                .accessibilityAddTraits(.isModal)
        }
    }
}

struct BTDecisionActionStyle: ButtonStyle {
    var isPrimary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.btSubheadlineSemibold)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, Spacing.sm)
            .background(isPrimary ? Color.btPrimary : Color.white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: BTRadius.sm))
            .foregroundStyle(.white)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Scene decisions keep button boundaries, without a surrounding dialog surface.
struct BTSceneDecisionActionStyle: ButtonStyle {
    var isPrimary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.btSubheadlineSemibold)
            .padding(.horizontal, Spacing.md)
            .frame(minWidth: 64, minHeight: 44)
            .foregroundStyle(Color.white)
            .background(configuration.isPressed ? HUDStyle.selectedBackground : HUDStyle.controlBackground,
                        in: RoundedRectangle(cornerRadius: BTRadius.sm))
            .overlay(RoundedRectangle(cornerRadius: BTRadius.sm)
                .stroke(isPrimary ? HUDStyle.accent.opacity(0.6) : HUDStyle.hairline, lineWidth: 0.75))
            .contentShape(Rectangle())
    }
}
