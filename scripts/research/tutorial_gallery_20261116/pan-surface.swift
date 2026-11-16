/// A directional recognizer rejects horizontal drags before recognition at 1x,
/// so the enclosing page TabView can receive them on every supported iOS version.
private struct TutorialMediaPanSurface: UIViewRepresentable {
    let scale: CGFloat
    let allowsDismiss: Bool
    let onChanged: (CGSize) -> Void
    let onEnded: (CGSize, Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.dragged(_:)))
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = false
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)
        view.isAccessibilityElement = true
        view.accessibilityIdentifier = "tutorialMediaZoom"
        view.accessibilityLabel = "精讲媒体"
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.parent = self
        view.accessibilityValue = "缩放 \(Int((scale * 100).rounded()))%"
    }

    static func shouldBegin(scale: CGFloat, allowsDismiss: Bool, velocity: CGPoint) -> Bool {
        scale > 1 || (allowsDismiss && velocity.y > abs(velocity.x))
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: TutorialMediaPanSurface
        init(_ parent: TutorialMediaPanSurface) { self.parent = parent }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            return TutorialMediaPanSurface.shouldBegin(
                scale: parent.scale, allowsDismiss: parent.allowsDismiss,
                velocity: pan.velocity(in: pan.view?.window)
            )
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
            guard let scroll = other.view as? UIScrollView,
                  other === scroll.panGestureRecognizer,
                  let view = gestureRecognizer.view else { return false }
            // Paging waits for our direction decision. A 1x horizontal drag fails
            // immediately; a zoomed pan or downward dismissal stays in this page.
            return view.isDescendant(of: scroll)
        }

        @objc func dragged(_ pan: UIPanGestureRecognizer) {
            let translation = pan.translation(in: pan.view?.window)
            let delta = CGSize(width: translation.x, height: translation.y)
            switch pan.state {
            case .began, .changed: parent.onChanged(delta)
            case .ended: parent.onEnded(delta, false)
            case .cancelled, .failed: parent.onEnded(delta, true)
            default: break
            }
        }
    }
}
