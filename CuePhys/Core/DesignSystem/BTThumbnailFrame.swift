import SwiftUI

/// Shared chrome for real baked-table thumbnails (grid cover + 64×64 row) — v27 W2 / DR-044 E4.
///
/// Triple: corner clip · bottom vignette · Dark hairline stroke.
/// Light/Dark share vignette opacity; stroke only in Dark (matches pre-W2 card language).
enum BTThumbnailFrame {
    static let vignetteOpacity: Double = 0.35
    /// Fraction of container height; capped so large grid covers stay at historical 36pt.
    static let vignetteHeightRatio: CGFloat = 0.28
    static let vignetteMaxHeight: CGFloat = 36
    static let darkStrokeWidth: CGFloat = 0.5

    static func vignetteHeight(for containerHeight: CGFloat) -> CGFloat {
        min(vignetteMaxHeight, max(0, containerHeight * vignetteHeightRatio))
    }
}

extension View {
    /// Applies clip + bottom vignette (+ optional Dark stroke) for a baked drill thumbnail.
    ///
    /// - Parameters:
    ///   - topCornersOnly: grid covers clip only top radii; row thumbs use full radius.
    ///   - cornerRadius: `BTRadius.md` (grid) or `BTRadius.sm` (64×64 row).
    ///   - showsStroke: row thumbs `true`; grid cards keep stroke on the outer card (`false`).
    func btThumbnailFrame(
        cornerRadius: CGFloat,
        topCornersOnly: Bool,
        showsStroke: Bool,
        colorScheme: ColorScheme
    ) -> some View {
        modifier(
            BTThumbnailFrameModifier(
                cornerRadius: cornerRadius,
                topCornersOnly: topCornersOnly,
                showsStroke: showsStroke,
                colorScheme: colorScheme
            )
        )
    }
}

private struct BTThumbnailFrameModifier: ViewModifier {
    let cornerRadius: CGFloat
    let topCornersOnly: Bool
    let showsStroke: Bool
    let colorScheme: ColorScheme

    func body(content: Content) -> some View {
        GeometryReader { geo in
            let h = BTThumbnailFrame.vignetteHeight(for: geo.size.height)
            let strokeWidth = (showsStroke && colorScheme == .dark)
                ? BTThumbnailFrame.darkStrokeWidth : 0

            Group {
                if topCornersOnly {
                    framed(
                        content: content,
                        size: geo.size,
                        vignetteHeight: h,
                        shape: UnevenRoundedRectangle(
                            topLeadingRadius: cornerRadius,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: cornerRadius
                        ),
                        strokeWidth: strokeWidth
                    )
                } else {
                    framed(
                        content: content,
                        size: geo.size,
                        vignetteHeight: h,
                        shape: RoundedRectangle(cornerRadius: cornerRadius),
                        strokeWidth: strokeWidth
                    )
                }
            }
        }
    }

    private func framed<S: Shape>(
        content: Content,
        size: CGSize,
        vignetteHeight: CGFloat,
        shape: S,
        strokeWidth: CGFloat
    ) -> some View {
        ZStack(alignment: .bottom) {
            content
                .frame(width: size.width, height: size.height)

            LinearGradient(
                colors: [.clear, .black.opacity(BTThumbnailFrame.vignetteOpacity)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: vignetteHeight)
            .allowsHitTesting(false)
        }
        .clipShape(shape)
        .overlay {
            shape.stroke(Color.btSeparator, lineWidth: strokeWidth)
        }
    }
}
