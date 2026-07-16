import SwiftUI

/// Shared press feedback for custom-labeled Buttons (W2-1 / F-GL-02).
///
/// **FL-004 contract**: behaves like `.plain` — no system tint, no background —
/// only scale + short easeInOut. Use this *instead of* `.buttonStyle(.plain)`
/// when press feedback is desired; do not stack a second ButtonStyle.
///
/// Tiers:
/// - ``row`` (0.98): list/custom rows, text actions, chips
/// - ``capsule`` (0.96): pill / capsule CTAs
struct BTPressableStyle: ButtonStyle {
    /// Pressed scale relative to 1.0 (typically 0.96–0.98).
    var pressedScale: CGFloat

    static let row = BTPressableStyle(pressedScale: 0.98)
    static let capsule = BTPressableStyle(pressedScale: 0.96)

    init(pressedScale: CGFloat = 0.98) {
        self.pressedScale = pressedScale
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(BTMotion.easePress, value: configuration.isPressed)
    }
}
