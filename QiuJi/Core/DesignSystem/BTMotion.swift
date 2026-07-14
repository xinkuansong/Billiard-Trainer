import SwiftUI

/// UI chrome motion tokens — single source of truth (ui-polish W2-4 / §1.2).
///
/// Scope: panels, expand/collapse, tabs, chips, calendar chrome, popup scale.
/// Out of scope: physics playback, trajectory replay, sequence timing, cue stroke.
enum BTMotion {
    /// Panel / expand / accordion / calendar / stage chrome.
    /// `spring(response: 0.34, dampingFraction: 0.86)`.
    static let springPanel: Animation = .spring(response: 0.34, dampingFraction: 0.86)

    /// High-frequency chrome (chips, segmented tabs) — easeOut ≤200ms.
    static let easeFast: Animation = .easeOut(duration: 0.2)

    /// General chrome transitions ≤300ms (stage reveal, brief dismiss).
    static let easeChrome: Animation = .easeOut(duration: 0.25)
}
