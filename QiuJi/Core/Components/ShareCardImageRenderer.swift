import SwiftUI
import UIKit

/// Single source of truth for off-screen `BTShareCard` → `UIImage` export.
///
/// Size contract (long-image revision): width is fixed, **height follows content**.
/// The old fixed 480pt height was a workaround for a greedy `Spacer` in the card
/// that made width-only rendering blow up (see
/// `ShareCardImageRendererRootCauseDiagTests`); the Spacer is gone, so height is
/// now bounded by the card's own folding rules
/// (`BTShareCard.maxDrillCards` / `setGridBudget`) rather than by a magic constant.
enum ShareCardImageRenderer {
    static let cardWidth: CGFloat = 375

    /// Upper bound the card's folding rules must keep the exported image under.
    /// Used by regression tests; not enforced by clamping (a clamp would silently
    /// crop content — if this is ever exceeded, the folding rule is what's wrong).
    static let maxCardHeight: CGFloat = 3_000

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
        .frame(width: cardWidth)
        .fixedSize(horizontal: false, vertical: true)

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
