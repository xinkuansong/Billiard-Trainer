import Foundation

/// Reads the explicit `tutorial.tutorialKind` field (v26 W0).
///
/// Replaces the former legacy/modern structure heuristic. Call sites that need
/// template routing or list badges should prefer `drill.tutorial?.tutorialKind`
/// directly; this helper remains for a single nil-safe access point in filters.
enum DrillTutorialKindResolver {

    /// Returns the explicit template kind, or `nil` when the drill has no tutorial /
    /// the field is absent (should not happen for bundled drills after v26 W0).
    static func resolve(for drill: DrillContent) -> DrillTutorialKind? {
        drill.tutorial?.tutorialKind
    }
}
