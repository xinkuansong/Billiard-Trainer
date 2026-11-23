import UIKit

/// Unified quiz outcome feedback (G23 / C22).
/// Maps correct / close / off → `UINotificationFeedbackGenerator` success / warning / error.
/// Keypad / aim-wheel light impact haptics stay on their existing call sites.
enum BTFeedback {

    enum QuizOutcome: Equatable {
        case correct
        case close
        case off
    }

    /// Reserved for optional light SFX; currently a no-op when `true`.
    static var soundEnabled: Bool = false

    private static let notification = UINotificationFeedbackGenerator()

    /// Degree-error bands aligned with Geometric / SceneAiming `ErrorRating` (≤3 / ≤10).
    static func quiz(errorDegrees: Double) {
        quiz(outcome(forDegrees: errorDegrees))
    }

    /// Absolute mm-error bands aligned with AimPoint rating colors (≤2 / ≤6).
    static func quiz(errorMM: Double) {
        quiz(outcome(forMM: abs(errorMM)))
    }

    static func quiz(_ outcome: QuizOutcome) {
        notification.prepare()
        notification.notificationOccurred(notificationType(for: outcome))
        playSoundIfEnabled(for: outcome)
    }

    // MARK: - Mapping (testable)

    static func outcome(forDegrees error: Double) -> QuizOutcome {
        if error <= 3 { return .correct }
        if error <= 10 { return .close }
        return .off
    }

    static func outcome(forMM absError: Double) -> QuizOutcome {
        if absError <= 2 { return .correct }
        if absError <= 6 { return .close }
        return .off
    }

    static func notificationType(for outcome: QuizOutcome)
        -> UINotificationFeedbackGenerator.FeedbackType {
        switch outcome {
        case .correct: return .success
        case .close: return .warning
        case .off: return .error
        }
    }

    private static func playSoundIfEnabled(for _: QuizOutcome) {
        guard soundEnabled else { return }
        // Reserved: wire soft correct/close/off SFX when product enables quiz audio.
    }
}
