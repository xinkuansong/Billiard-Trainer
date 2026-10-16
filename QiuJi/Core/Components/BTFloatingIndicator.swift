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

private struct BTTrainingPillObstruction: Equatable {
    let frame: CGRect
    let edge: VerticalEdge
}

private struct BTTrainingPillObstructions: PreferenceKey {
    static var defaultValue: [BTTrainingPillObstruction] = []
    static func reduce(value: inout [BTTrainingPillObstruction], nextValue: () -> [BTTrainingPillObstruction]) {
        value.append(contentsOf: nextValue())
    }
}

private struct BTTrainingPillObstacle: ViewModifier {
    var edge: VerticalEdge
    @State private var isVisible = false
    func body(content: Content) -> some View {
        content.background {
            GeometryReader { geometry in
                Color.clear.preference(key: BTTrainingPillObstructions.self,
                    value: isVisible ? [BTTrainingPillObstruction(frame: geometry.frame(in: .global), edge: edge)] : [])
            }
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }
}

extension View {
    /// Register a complete, currently visible action bar, including its padding.
    func btTrainingPillObstacle(edge: VerticalEdge = .bottom) -> some View {
        modifier(BTTrainingPillObstacle(edge: edge))
    }

    func btTrainingPillOverlay<Pill: View>(isPresented: Bool = true, includesTabBar: Bool = false,
                                         position: BTTrainingPillPosition? = nil,
                                         @ViewBuilder pill: @escaping () -> Pill) -> some View {
        modifier(BTTrainingPillOverlay(isPresented: isPresented, includesTabBar: includesTabBar, position: position, pill: pill))
    }
}

private struct BTTrainingPillOverlay<Pill: View>: ViewModifier {
    var isPresented: Bool
    var includesTabBar: Bool
    var position: BTTrainingPillPosition?
    @ViewBuilder var pill: () -> Pill
    @State private var safeFrame: CGRect?
    @State private var navigationBottom: CGFloat = 0
    @State private var keyboardTop: CGFloat?
    @State private var tabFrame: CGRect?

    func body(content: Content) -> some View {
        content
            .background {
                if isPresented {
                    BTTrainingPillBoundaryReader(includesTabBar: includesTabBar) { safe, tab, navBottom, keyboard in
                        if keyboardTop != keyboard { keyboardTop = keyboard }
                        if safeFrame != safe { safeFrame = safe }
                        if navigationBottom != navBottom { navigationBottom = navBottom }
                        if tabFrame != tab { tabFrame = tab }
                    }.frame(width: 0, height: 0)
                }
            }
            .overlayPreferenceValue(BTTrainingPillObstructions.self) { obstacles in
                GeometryReader { geometry in
                    let frame = geometry.frame(in: .global)
                    let barriers = obstacles.filter { $0.edge == .bottom }.map(\.frame)
                        + (tabFrame.map { [$0] } ?? [])
                    let floor = min(frame.maxY, safeFrame?.maxY ?? frame.maxY, keyboardTop ?? frame.maxY)
                    let boundary = barriers.filter {
                        !$0.isEmpty && $0.intersects(frame) && $0.maxY > frame.midY
                    }.reduce(floor) { min($0, $1.minY) }
                    if isPresented, let position {
                        let viewport = frame.intersection(safeFrame ?? frame)
                        let ceiling = obstacles.filter {
                            $0.edge == .top && $0.frame.intersects(frame)
                        }.reduce(max(viewport.minY, navigationBottom)) { max($0, $1.frame.maxY) }
                        let available = CGRect(x: viewport.minX, y: ceiling,
                                               width: viewport.width, height: max(0, boundary - ceiling))
                        BTDraggableTrainingPill(position: position, viewport: viewport,
                                                available: available, hostOrigin: frame.origin, pill: pill)
                    } else {
                        pill()
                            .padding(.trailing, BTTrainingPillMetrics.edgeGap)
                            .padding(.bottom, max(0, frame.maxY - boundary) + BTTrainingPillMetrics.edgeGap)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    }
                }
            }
    }
}

/// Owned by a training session; each kind of pill has its own placement.
final class BTTrainingPillPosition: ObservableObject {
    @Published var verticalFraction: CGFloat?
}

/// All inputs are window points (x right, y down). Bounds include the full pill.
struct BTTrainingPillDragLayout {
    let viewport: CGRect
    let available: CGRect
    let pillSize: CGSize

    private var insetX: CGFloat { BTTrainingPillMetrics.edgeGap + pillSize.width / 2 }
    private var insetY: CGFloat { BTTrainingPillMetrics.edgeGap + pillSize.height / 2 }
    var fits: Bool {
        !viewport.isNull && pillSize.width > 0 && pillSize.height > 0
            && available.width >= insetX * 2 && available.height >= insetY * 2
    }
    func clamped(_ point: CGPoint) -> CGPoint {
        guard fits else { return .zero }
        return CGPoint(x: min(max(point.x, available.minX + insetX), available.maxX - insetX),
                y: min(max(point.y, available.minY + insetY), available.maxY - insetY))
    }
    func docked(fraction: CGFloat?) -> CGPoint {
        clamped(CGPoint(x: available.maxX - insetX,
                        y: fraction.map { viewport.minY + $0 * viewport.height } ?? (available.maxY - insetY)))
    }
    func fraction(at point: CGPoint) -> CGFloat {
        guard viewport.height > 0 else { return 1 }
        return min(1, max(0, (clamped(point).y - viewport.minY) / viewport.height))
    }
}

private struct BTDraggableTrainingPill<Pill: View>: View {
    @ObservedObject var position: BTTrainingPillPosition
    let viewport: CGRect
    let available: CGRect
    let hostOrigin: CGPoint
    @ViewBuilder var pill: () -> Pill
    @State private var pillSize: CGSize = .zero
    @GestureState private var translation: CGSize? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let layout = BTTrainingPillDragLayout(viewport: viewport, available: available, pillSize: pillSize)
        let docked = layout.docked(fraction: position.verticalFraction)
        let center = layout.clamped(CGPoint(x: docked.x + (translation?.width ?? 0),
                                            y: docked.y + (translation?.height ?? 0)))
        pill()
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { pillSize = $0 }
            // A recognized drag wins over the button's tap. Outside this capsule,
            // the underlying page retains all scrolling and table gestures.
            .highPriorityGesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .global)
                    .updating($translation) { value, state, transaction in
                        transaction.animation = nil
                        state = value.translation
                    }
                    .onEnded { value in
                        let end = CGPoint(x: docked.x + value.translation.width,
                                          y: docked.y + value.translation.height)
                        position.verticalFraction = layout.fraction(at: end)
                    }
            )
            .accessibilityHint("可拖动调整位置，松手后贴靠右侧")
            .accessibilityAction(named: Text("上移浮窗")) {
                position.verticalFraction = layout.fraction(at: CGPoint(x: docked.x, y: docked.y - pillSize.height))
            }
            .accessibilityAction(named: Text("下移浮窗")) {
                position.verticalFraction = layout.fraction(at: CGPoint(x: docked.x, y: docked.y + pillSize.height))
            }
            .position(x: center.x - hostOrigin.x, y: center.y - hostOrigin.y)
            .opacity(layout.fits ? 1 : 0)
            .allowsHitTesting(layout.fits)
            .accessibilityHidden(!layout.fits)
            .animation(reduceMotion || translation != nil ? nil : BTMotion.springPanel,
                       value: translation == nil)
    }
}

/// Window coordinates match the SwiftUI global frames used by the page action bars.
private struct BTTrainingPillBoundaryReader: UIViewRepresentable {
    let includesTabBar: Bool
    let onMeasure: (CGRect, CGRect?, CGFloat, CGFloat?) -> Void

    func makeUIView(context: Context) -> Probe {
        Probe(includesTabBar: includesTabBar, onMeasure: onMeasure)
    }
    func updateUIView(_ view: Probe, context: Context) { view.report() }

    final class Probe: UIView {
        let includesTabBar: Bool
        let onMeasure: (CGRect, CGRect?, CGFloat, CGFloat?) -> Void
        private weak var trackedTab: UITabBar?
        private var displayLink: CADisplayLink?

        private final class DisplayLinkTarget {
            weak var probe: Probe?
            init(_ probe: Probe) { self.probe = probe }
            @objc func tick() { probe?.report() }
        }
        init(includesTabBar: Bool, onMeasure: @escaping (CGRect, CGRect?, CGFloat, CGFloat?) -> Void) {
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
                let safe = window.bounds.inset(by: window.safeAreaInsets)
                let keyboard = window.keyboardLayoutGuide.layoutFrame
                let keyboardTop = !keyboard.isEmpty && keyboard.intersects(safe) ? keyboard.minY : nil
                let navigationBottom = Self.visibleNavigationBottom(in: window, window: window)
                onMeasure(safe, frame.flatMap { $0.midY > window.bounds.midY ? $0 : nil }, navigationBottom, keyboardTop)
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
        private static func visibleNavigationBottom(in view: UIView, window: UIWindow) -> CGFloat {
            guard isVisible(view) else { return 0 }
            if let bar = view as? UINavigationBar {
                return bar.convert(bar.bounds, to: window).maxY
            }
            return view.subviews.map { visibleNavigationBottom(in: $0, window: window) }.max() ?? 0
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
