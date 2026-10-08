import SwiftUI

/// UIKit's corner-aware safe area tracks iPadOS window controls during resizing.
/// Measure only the header band; an inset for the entire page would shrink the table.
struct DailyWindowControlInsets: UIViewRepresentable {
    var onChange: (UIEdgeInsets, UIEdgeInsets, Bool) -> Void

    func makeUIView(context: Context) -> MeasuringView { MeasuringView() }
    func updateUIView(_ view: MeasuringView, context: Context) {
        view.onChange = onChange
        view.setNeedsLayout()
    }

    final class MeasuringView: UIView {
        var onChange: ((UIEdgeInsets, UIEdgeInsets, Bool) -> Void)?
        private var last = UIEdgeInsets.zero
        private var lastWindowSafeArea = UIEdgeInsets.zero
        private var lastStatusVisible: Bool?
        override func didMoveToWindow() { super.didMoveToWindow(); setNeedsLayout() }
        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            setNeedsLayout()
        }
        override func layoutSubviews() {
            super.layoutSubviews()
            measureInsets()
        }
        private func measureInsets() {
            var inset = UIEdgeInsets.zero
            if #available(iOS 26.0, *), traitCollection.userInterfaceIdiom == .pad {
                let adapted = edgeInsets(for: .safeArea(cornerAdaptation: .horizontal))
                inset.left = max(0, adapted.left - safeAreaInsets.left)
                inset.right = max(0, adapted.right - safeAreaInsets.right)
            }
            var windowSafeArea = window?.safeAreaInsets ?? .zero
            var statusOcclusion = CGRect.zero
            if traitCollection.userInterfaceIdiom == .pad, let window,
               let scene = window.windowScene, let manager = scene.statusBarManager,
               !manager.isStatusBarHidden {
                // iPadOS can keep a maximized window's floating 10pt inset while
                // drawing the status bar over it. Measure the display's visible
                // status band in this window, so a floating window below it adds nothing.
                let screen = scene.screen.coordinateSpace
                let band = CGRect(x: screen.bounds.minX, y: screen.bounds.minY,
                                  width: screen.bounds.width, height: manager.statusBarFrame.height)
                let intersection = window.convert(band, from: screen).intersection(window.bounds)
                if !intersection.isNull, intersection.minY <= window.bounds.minY {
                    statusOcclusion = intersection
                    windowSafeArea.top = max(windowSafeArea.top, intersection.maxY - window.bounds.minY)
                }
            }
            if DailyLayoutProbe.enabled, let window, let scene = window.windowScene {
                let manager = scene.statusBarManager
                let statusFrame = manager.map { window.convert($0.statusBarFrame, from: scene.coordinateSpace) } ?? .zero
                DailyLayoutProbe.record("window.chrome", [
                    "window": DailyLayoutProbe.rect(window.bounds),
                    "header": DailyLayoutProbe.rect(convert(bounds, to: window)),
                    "windowInsets": DailyLayoutProbe.insets(windowSafeArea),
                    "rootInsets": DailyLayoutProbe.insets(window.rootViewController?.view.safeAreaInsets ?? .zero),
                    "statusFrame": DailyLayoutProbe.rect(statusFrame),
                    "statusOcclusion": DailyLayoutProbe.rect(statusOcclusion),
                    "screenWindow": DailyLayoutProbe.rect(window.convert(window.bounds, to: scene.screen.coordinateSpace)),
                    "statusHidden": manager?.isStatusBarHidden ?? true])
            }
            let statusVisible = window?.windowScene?.statusBarManager?.isStatusBarHidden == false
            guard inset != last || windowSafeArea != lastWindowSafeArea || statusVisible != lastStatusVisible else { return }
            lastStatusVisible = statusVisible
            last = inset
            lastWindowSafeArea = windowSafeArea
            DailyLayoutProbe.record("window.safeArea", [
                "top": windowSafeArea.top, "bottom": windowSafeArea.bottom,
                "left": inset.left, "right": inset.right])
            DispatchQueue.main.async { [weak self] in self?.onChange?(inset, windowSafeArea, statusVisible) }
        }
    }
}

/// One presentation owner prevents menus, settings and decisions from stacking.
enum DailyHUDPresentation: Equatable {
    case more, aim, trajectory, games, transparency, rerack, breakRerack
    case gameChange(DailyClearanceGame)

    var isDecision: Bool {
        switch self { case .rerack, .gameChange, .breakRerack: return true; default: return false }
    }
}

struct DailyHUDMenuItem: Identifiable {
    let id: String
    let title: String
    var detail: String? = nil
    var segments: [String] = []
    var selected = false
    var disclosure = false
    var disabled = false
    var action: (() -> Void)? = nil
}

struct DailyHUDMenuPanel: View {
    let title: String?
    let items: [DailyHUDMenuItem]
    let availableSize: CGSize
    let onBack: () -> Void
    let onClose: () -> Void
    @State private var measuredHeight: CGFloat = 1
    @State private var measuredHeaderHeight: CGFloat = 44
    @Environment(\.dynamicTypeSize) private var typeSize
    @AccessibilityFocusState private var headingFocused: Bool

    private var width: CGFloat { min(typeSize.isAccessibilitySize ? 360 : 252, max(44, availableSize.width)) }
    private var headerHeight: CGFloat { title == nil ? 0 : measuredHeaderHeight + 0.5 }
    private var availableHeight: CGFloat { max(44, availableSize.height - headerHeight - 16) }

    var body: some View {
        VStack(spacing: 0) {
            if let title {
                HStack(spacing: 0) {
                    Button(action: onBack) { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .accessibilityLabel("返回更多菜单").accessibilityIdentifier("dailyClearance.menuBack")
                    Text(title).font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader).accessibilityFocused($headingFocused)
                    Spacer(minLength: 0)
                    Button(action: onClose) { Image(systemName: "xmark").frame(width: 44, height: 44) }
                        .accessibilityLabel("关闭菜单").accessibilityIdentifier("dailyClearance.menuClose")
                }
                .background(GeometryReader { geometry in
                    Color.clear.preference(key: DailyMenuHeaderHeightKey.self, value: geometry.size.height)
                })
                separator(strong: true)
            }
            ScrollView(.vertical) { content }
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: min(measuredHeight, availableHeight))
                .accessibilityIdentifier("dailyClearance.menuScroll")
                .background {
                    content.fixedSize(horizontal: false, vertical: true)
                        .background(GeometryReader { geometry in
                            Color.clear.preference(key: DailyMenuHeightKey.self, value: geometry.size.height)
                        })
                        .hidden().allowsHitTesting(false).accessibilityHidden(true)
                }
        }
        .padding(.vertical, 8)
        .frame(width: width)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .modifier(DailyPanelSurface())
        .buttonStyle(.plain)
        .contentShape(Rectangle()).onTapGesture {}
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dailyClearance.menuPanel")
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onClose)
        .onPreferenceChange(DailyMenuHeightKey.self) { value in
            if value.isFinite, value > 0 { measuredHeight = value }
        }
        .onPreferenceChange(DailyMenuHeaderHeightKey.self) { value in
            if value.isFinite, value > 0 { measuredHeaderHeight = value }
        }
        .onAppear { headingFocused = true }
    }

    private var content: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { separator(strong: item.action == nil) }
                if let action = item.action {
                    Button(action: action) {
                        HStack(spacing: 8) {
                            Text(item.title).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            if !item.segments.isEmpty {
                                HStack(spacing: 0) {
                                    ForEach(item.segments, id: \.self) { segment in
                                        Text(segment).font(.btFootnote.weight(.semibold))
                                            .foregroundStyle(segment == item.detail ? Color.white : .btTextSecondary)
                                            .frame(width: 44, height: 34)
                                            .background(segment == item.detail ? HUDStyle.selectedBackground : .clear, in: Capsule())
                                    }
                                }
                                .padding(3)
                                .background { BTHUDControlBackground(shape: Capsule()) }
                                .overlay(Capsule().stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
                            } else if let detail = item.detail {
                                Text(detail).foregroundStyle(.white.opacity(0.7))
                            }
                            if item.selected { Image(systemName: "checkmark").foregroundStyle(HUDStyle.accent) }
                            if item.disclosure { Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.6)) }
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .disabled(item.disabled)
                    .opacity(item.disabled ? 0.4 : 1)
                    .accessibilityIdentifier(item.id)
                    .accessibilityValue(item.selected ? "已选" : (item.detail ?? ""))
                } else {
                    Text(item.title).font(.caption).foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.vertical, 4)
                        .accessibilityAddTraits(.isHeader)
                }
            }
        }
    }

    private func separator(strong: Bool) -> some View {
        Rectangle().fill(Color.white.opacity(strong ? 0.16 : 0.08))
            .frame(height: 0.5).padding(.horizontal, 16).accessibilityHidden(true)
    }
}

struct DailyConfirmationCard: View {
    let title: String
    var availableHeight: CGFloat
    var availableWidth: CGFloat
    let firstTitle: String
    let secondTitle: String
    let firstID: String
    let secondID: String
    let first: () -> Void
    let second: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @AccessibilityFocusState private var titleFocused: Bool
    @State private var titleHeight: CGFloat = 21
    @State private var actionsHeight: CGFloat = 44
    private var contentSpacing: CGFloat { typeSize.isAccessibilitySize ? 8 : 19 }

    private var heading: some View {
        Text(title).font(.subheadline).multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 21)
            .padding(.vertical, typeSize.isAccessibilitySize ? 4 : 0)
            .accessibilityAddTraits(.isHeader).accessibilityFocused($titleFocused)
            .accessibilityIdentifier("dailyClearance.confirmationTitle")
    }
    private var titleCapacity: CGFloat { max(44, availableHeight - actionsHeight - 24 - contentSpacing) }

    var body: some View {
        VStack(spacing: contentSpacing) {
            ScrollView(.vertical) {
                heading.background(GeometryReader { geometry in
                    Color.clear.preference(key: DailyConfirmationTitleHeightKey.self, value: geometry.size.height)
                })
            }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDisabled(titleHeight <= titleCapacity)
                .frame(height: min(titleHeight, titleCapacity))
                .accessibilityIdentifier("dailyClearance.confirmationTitleScroll")
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
            layout {
                action(firstTitle, id: firstID, primary: false, perform: first)
                action(secondTitle, id: secondID, primary: true, perform: second)
            }
            .fixedSize(horizontal: false, vertical: true)
            .background(GeometryReader { geometry in
                Color.clear.preference(key: DailyConfirmationActionsHeightKey.self, value: geometry.size.height)
            })
        }
        .padding(12).frame(width: min(typeSize.isAccessibilitySize ? 360 : 252, availableWidth))
        .foregroundStyle(.white).environment(\.colorScheme, .dark)
        .modifier(DailyPanelSurface())
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("dailyClearance.confirmation")
        .onPreferenceChange(DailyConfirmationTitleHeightKey.self) { if $0 > 0 { titleHeight = $0 } }
        .onPreferenceChange(DailyConfirmationActionsHeightKey.self) { if $0 > 0 { actionsHeight = $0 } }
        .onAppear { titleFocused = true }
    }

    private func action(_ text: String, id: String, primary: Bool, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Text(text).font(.subheadline).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(primary ? HUDStyle.selectedBackground : Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityIdentifier(id)
    }
}

private struct DailyMenuHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 1
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct DailyMenuHeaderHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 44
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct DailyConfirmationTitleHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 21
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
private struct DailyConfirmationActionsHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 44
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}


/// C55: informational chrome is independent of table/palette sizing and shot state.
struct DailyDeviceStatus: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var level: Float = -1
    @State private var batteryState: UIDevice.BatteryState = .unknown
    @State private var wasMonitoring = false
    @State private var clockEpoch = UUID()

    static func fraction(level: Float, state: UIDevice.BatteryState) -> CGFloat? {
        guard state != .unknown, level.isFinite, (0...1).contains(level) else { return nil }
        return CGFloat(level)
    }

    static func fits(_ rect: CGRect, in bounds: CGRect, obstacles: [CGRect], clearance: CGFloat = 4) -> Bool {
        bounds.contains(rect) && !obstacles.contains { $0.insetBy(dx: -clearance, dy: -clearance).intersects(rect) }
    }

    static func clockText(_ date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private var fraction: CGFloat? { Self.fraction(level: level, state: batteryState) }
    private var charging: Bool { batteryState == .charging || batteryState == .full }
    private var batteryLabel: String {
        guard let fraction else { return "电量暂不可用" }
        return "电量\(Int((fraction * 100).rounded()))%" + (charging ? "，已连接电源" : "")
    }
    private func refresh() {
        level = UIDevice.current.batteryLevel
        batteryState = UIDevice.current.batteryState
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            let time = Self.clockText(context.date)
            VStack(spacing: 3) {
                Text(time).font(.system(size: 11, weight: .medium).monospacedDigit())
                    .fixedSize(horizontal: true, vertical: true)
                    .foregroundStyle(.white.opacity(0.84)).frame(width: 32, height: 14)
                ZStack {
                    Canvas { context, _ in
                        let shell = Path(roundedRect: CGRect(x: 0.5, y: 0.5, width: 20, height: 9), cornerRadius: 2)
                        context.stroke(shell, with: .color(.white.opacity(0.52)), lineWidth: 1)
                        context.fill(Path(roundedRect: CGRect(x: 21.5, y: 3, width: 1.5, height: 4), cornerRadius: 0.6), with: .color(.white.opacity(0.52)))
                        if let fraction {
                            let color: Color = fraction <= 0.2 && !charging ? .red : .white.opacity(0.70)
                            context.fill(Path(roundedRect: CGRect(x: 2, y: 2, width: 17 * fraction, height: 6), cornerRadius: 1), with: .color(color))
                        } else {
                            context.fill(Path(CGRect(x: 7, y: 4.5, width: 7, height: 1)), with: .color(.white.opacity(0.70)))
                        }
                    }
                    if charging {
                        Image(systemName: "bolt.fill").font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white).shadow(color: .black, radius: 1)
                    }
                }.frame(width: 23, height: 10)
            }
            .frame(width: 32, height: 27)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("时间\(time)，\(batteryLabel)")
            .accessibilityIdentifier("dailyClearance.deviceStatus")
        }
        .id(clockEpoch)
        .allowsHitTesting(false)
        .onAppear {
            wasMonitoring = UIDevice.current.isBatteryMonitoringEnabled
            UIDevice.current.isBatteryMonitoringEnabled = true
            refresh()
        }
        .onDisappear { UIDevice.current.isBatteryMonitoringEnabled = wasMonitoring }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in clockEpoch = UUID() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh(); clockEpoch = UUID() }
        }
    }
}


/// C56 A: time, battery, then the renderer's measured FPS (or idle state).
struct DailyStatusCluster: View {
    @ObservedObject var fps: TableFPSReadoutState
    let showsDeviceStatus: Bool

    var body: some View {
        VStack(spacing: 3) {
            if showsDeviceStatus { DailyDeviceStatus() }
            Text(fps.text == "FPS · 静止" ? "静止" : fps.text)
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.60))
                .lineLimit(1).minimumScaleFactor(0.85)
                .frame(width: 32, height: 11)
                .accessibilityLabel("渲染帧率，" + fps.text)
                .accessibilityValue(fps.text)
                .accessibilityIdentifier("dailyClearance.renderFPS")
        }
        .frame(width: 32, height: 41)
        .allowsHitTesting(false)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dailyClearance.statusCluster")
    }
}
