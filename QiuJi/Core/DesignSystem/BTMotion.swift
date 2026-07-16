import SwiftUI

/// UI chrome motion tokens — single source of truth (ui-polish W2-4 / §1.2 / v7 G22).
///
/// Scope: panels, expand/collapse, tabs, chips, calendar chrome, popup scale, stage chrome.
/// Out of scope: physics playback, trajectory replay, sequence timing, cue stroke.
enum BTMotion {
    /// Panel / expand / accordion / calendar / spin-pad stage chrome.
    /// Source: `spring(response: 0.34, dampingFraction: 0.86)` — spin pad / panel.
    static let springPanel: Animation = .spring(response: 0.34, dampingFraction: 0.86)

    /// Overlay / solution-state layout transitions (quiz phase, solver mode chips).
    /// Source: `spring(response: 0.35, dampingFraction: 0.75)` — SceneAiming / SolverStageChrome.
    static let springLayout: Animation = .spring(response: 0.35, dampingFraction: 0.75)

    /// High-frequency chrome (chips, segmented tabs) — easeOut ≤200ms.
    /// Source: `easeOut(duration: 0.2)`.
    static let easeFast: Animation = .easeOut(duration: 0.2)

    /// Cross-fade / phase / toggle alignment — easeInOut 200ms.
    /// Source: `easeInOut(duration: 0.2)` — stage index, quiz phase, profile toggles.
    static let easeInOutFast: Animation = .easeInOut(duration: 0.2)

    /// General chrome transitions ≤300ms (toast, brief dismiss, list collapse).
    /// Source: `easeOut(duration: 0.25)`.
    static let easeChrome: Animation = .easeOut(duration: 0.25)

    /// Symmetric chrome reveal (banner / brief / onboarding page).
    /// Source: `easeInOut(duration: 0.25)`.
    static let easeInOutChrome: Animation = .easeInOut(duration: 0.25)

    /// Slider / continuous readout instant feedback.
    /// Source: `easeOut(duration: 0.12)` — ContactPointTable sliders.
    static let easeInstant: Animation = .easeOut(duration: 0.12)

    /// Button / pressable scale feedback.
    /// Source: `easeInOut(duration: 0.1)` — BTButton / BTPressableStyle / pressed configs.
    static let easePress: Animation = .easeInOut(duration: 0.1)
}
