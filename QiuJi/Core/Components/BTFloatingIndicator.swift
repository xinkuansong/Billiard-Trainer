import SwiftUI

enum BTTrainingPillMetrics {
    static let height: CGFloat = 44
    static let edgeGap: CGFloat = 12
}

/// One compact shell for entry, resume and rest states.
struct BTTrainingPill: View {
    let title: String
    let icon: String
    var time: String? = nil
    var tint: Color = .btPrimary
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.btCallout.weight(.semibold))
                    .accessibilityHidden(true)
                if time == nil {
                    Text(title).font(.btSubheadlineSemibold)
                }
                if let time {
                    Text(time)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                }
            }
            .lineLimit(1)
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.lg)
            .frame(height: BTTrainingPillMetrics.height)
            .fixedSize(horizontal: true, vertical: false)
            .background(tint, in: Capsule())
            .contentShape(Capsule())
            .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.15), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(BTPressableStyle.capsule)
    }
}

private struct BTTrainingPillObstructions: PreferenceKey {
    static var defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}

private struct BTTrainingPillObstacle: ViewModifier {
    @State private var isVisible = false
    func body(content: Content) -> some View {
        content.background {
            GeometryReader { geometry in
                Color.clear.preference(key: BTTrainingPillObstructions.self,
                    value: isVisible ? [geometry.frame(in: .global)] : [])
            }
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }
}

extension View {
    /// Register the complete, currently visible bottom action bar, including its padding.
    func btTrainingPillObstacle() -> some View {
        modifier(BTTrainingPillObstacle())
    }

    func btTrainingPillOverlay<Pill: View>(isPresented: Bool = true, includesTabBar: Bool = false,
                                         @ViewBuilder pill: @escaping () -> Pill) -> some View {
        modifier(BTTrainingPillOverlay(isPresented: isPresented, includesTabBar: includesTabBar, pill: pill))
    }
}

private struct BTTrainingPillOverlay<Pill: View>: ViewModifier {
    var isPresented: Bool
    var includesTabBar: Bool
    @ViewBuilder var pill: () -> Pill
    @State private var safeBottom: CGFloat?
    @State private var tabFrame: CGRect?

    func body(content: Content) -> some View {
        content
            .background {
                if isPresented {
                    BTTrainingPillBoundaryReader(includesTabBar: includesTabBar) { bottom, tab in
                        if safeBottom != bottom { safeBottom = bottom }
                        if tabFrame != tab { tabFrame = tab }
                    }.frame(width: 0, height: 0)
                }
            }
            .overlayPreferenceValue(BTTrainingPillObstructions.self) { obstacles in
                GeometryReader { geometry in
                    let frame = geometry.frame(in: .global)
                    let barriers = obstacles + (tabFrame.map { [$0] } ?? [])
                    let floor = min(frame.maxY, safeBottom ?? frame.maxY)
                    let boundary = barriers.filter {
                        !$0.isEmpty && $0.intersects(frame) && $0.maxY > frame.midY
                    }.reduce(floor) { min($0, $1.minY) }
                    pill()
                        .padding(.trailing, BTTrainingPillMetrics.edgeGap)
                        .padding(.bottom, max(0, frame.maxY - boundary) + BTTrainingPillMetrics.edgeGap)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
    }
}

/// Window coordinates match the SwiftUI global frames used by the page action bars.
private struct BTTrainingPillBoundaryReader: UIViewRepresentable {
    let includesTabBar: Bool
    let onMeasure: (CGFloat, CGRect?) -> Void

    func makeUIView(context: Context) -> Probe {
        Probe(includesTabBar: includesTabBar, onMeasure: onMeasure)
    }
    func updateUIView(_ view: Probe, context: Context) { view.report() }

    final class Probe: UIView {
        let includesTabBar: Bool
        let onMeasure: (CGFloat, CGRect?) -> Void
        private weak var trackedTab: UITabBar?
        private var displayLink: CADisplayLink?

        private final class DisplayLinkTarget {
            weak var probe: Probe?
            init(_ probe: Probe) { self.probe = probe }
            @objc func tick() { probe?.report() }
        }
        init(includesTabBar: Bool, onMeasure: @escaping (CGFloat, CGRect?) -> Void) {
            self.includesTabBar = includesTabBar
            self.onMeasure = onMeasure
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }
        required init?(coder: NSCoder) { nil }
        deinit { displayLink?.invalidate() }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            displayLink?.invalidate()
            displayLink = nil
            trackedTab = nil
            // UIKit can restore the Tab Bar after SwiftUI's final navigation layout.
            // Observe its actual visibility independently of SwiftUI view updates.
            if window != nil && includesTabBar {
                let link = CADisplayLink(target: DisplayLinkTarget(self), selector: #selector(DisplayLinkTarget.tick))
                link.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
                link.add(to: .main, forMode: .common)
                displayLink = link
            }
            report()
        }
        override func layoutSubviews() { super.layoutSubviews(); report() }
        override func safeAreaInsetsDidChange() { super.safeAreaInsetsDidChange(); report() }
        func report() {
            DispatchQueue.main.async { [weak self] in
                guard let self, let window else { return }
                if includesTabBar && trackedTab?.window !== window {
                    trackedTab = Self.findTab(in: window)
                }
                let tab = includesTabBar && Self.isVisible(trackedTab) ? trackedTab : nil
                let frame = tab.map { $0.convert($0.bounds, to: window) }
                onMeasure(window.bounds.maxY - window.safeAreaInsets.bottom,
                          frame.flatMap { $0.midY > window.bounds.midY ? $0 : nil })
            }
        }
        private static func isVisible(_ view: UIView?) -> Bool {
            guard let view, view.window != nil else { return false }
            var cursor: UIView? = view
            while let current = cursor {
                if current.isHidden || current.alpha <= 0.01 { return false }
                cursor = current.superview
            }
            return true
        }
        private static func findTab(in view: UIView) -> UITabBar? {
            if let tab = view as? UITabBar { return tab }
            for child in view.subviews {
                if let tab = findTab(in: child) { return tab }
            }
            return nil
        }
    }
}

struct BTFloatingIndicator: View {
    let elapsedSeconds: Int
    /// F-AT-04: shared resume copy with TrainingHome full-width bar.
    var title: String = "继续"
    var onTap: () -> Void


    private var timeString: String {
        Self.formatElapsedTime(elapsedSeconds)
    }

    static func formatElapsedTime(_ elapsedSeconds: Int) -> String {
        let safeSeconds = max(0, elapsedSeconds)
        let hours = safeSeconds / 3600
        let minutes = (safeSeconds % 3600) / 60
        let seconds = safeSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        BTTrainingPill(title: title, icon: BTIcon.playCircle, time: timeString, onTap: onTap)
            .accessibilityLabel("继续训练 \(timeString)，点击返回")
            .accessibilityIdentifier("minimizedTraining.resume")
    }

}

// MARK: - Preview

#Preview("BTFloatingIndicator Light") {
    VStack {
        Spacer()
        HStack {
            Spacer()
            BTFloatingIndicator(elapsedSeconds: 754) {}
                .padding(.trailing, Spacing.lg)
                .padding(.bottom, Spacing.sm)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.btBG)
}

#Preview("BTFloatingIndicator Dark") {
    VStack {
        Spacer()
        HStack {
            Spacer()
            BTFloatingIndicator(elapsedSeconds: 754) {}
                .padding(.trailing, Spacing.lg)
                .padding(.bottom, Spacing.sm)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.btBG)
    .preferredColorScheme(.dark)
}
