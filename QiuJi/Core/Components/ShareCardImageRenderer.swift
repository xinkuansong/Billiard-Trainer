import SwiftUI
import UIKit

/// Single source of truth for off-screen `BTShareCard` → `UIImage` export.
///
/// Size contract (W1 / 问题集合_v9): content always has **bounded width and height**,
/// matching `BTShareCard` Previews (`.frame(height: 480)`). Do not call
/// `ImageRenderer` with width-only frames — Preview and save paths must share
/// the same dimension semantics.
enum ShareCardImageRenderer {
    static let cardWidth: CGFloat = 361
    static let cardHeight: CGFloat = 480

    /// Reasonable pixel-height upper bound for regression tests (far below any
    /// runaway Spacer / unbounded-layout magnitude). At @3x: 480 × 3 = 1440.
    static let maxReasonablePixelHeight: Int = 2_000

    @MainActor
    static func render(
        session: TrainingSessionSummary,
        theme: ShareCardTheme,
        fontChoice: ShareCardFont = .system,
        hideSuccessRate: Bool = false,
        scale: CGFloat
    ) -> UIImage? {
        let content = BTShareCard(
            session: session,
            theme: theme,
            fontChoice: fontChoice,
            hideSuccessRate: hideSuccessRate
        )
        .frame(width: cardWidth, height: cardHeight)

        let renderer = ImageRenderer(content: content)
        renderer.scale = scale
        return renderer.uiImage
    }

    /// Production convenience: uses the main screen scale.
    @MainActor
    static func render(
        session: TrainingSessionSummary,
        theme: ShareCardTheme,
        fontChoice: ShareCardFont = .system,
        hideSuccessRate: Bool = false
    ) -> UIImage? {
        render(
            session: session,
            theme: theme,
            fontChoice: fontChoice,
            hideSuccessRate: hideSuccessRate,
            scale: UIScreen.main.scale
        )
    }
}
