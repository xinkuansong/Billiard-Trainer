import SwiftUI

/// UIKit's corner-aware safe area tracks iPadOS window controls during resizing.
/// Measure only the header band; an inset for the entire page would shrink the table.
struct DailyWindowControlInsets: UIViewRepresentable {
    var onChange: (UIEdgeInsets, UIEdgeInsets) -> Void

    func makeUIView(context: Context) -> MeasuringView { MeasuringView() }
    func updateUIView(_ view: MeasuringView, context: Context) {
        view.onChange = onChange
        view.setNeedsLayout()
    }

    final class MeasuringView: UIView {
        var onChange: ((UIEdgeInsets, UIEdgeInsets) -> Void)?
        private var last = UIEdgeInsets.zero
        private var lastWindowSafeArea = UIEdgeInsets.zero
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
            guard inset != last || windowSafeArea != lastWindowSafeArea else { return }
            last = inset
            lastWindowSafeArea = windowSafeArea
            DailyLayoutProbe.record("window.safeArea", [
                "top": windowSafeArea.top, "bottom": windowSafeArea.bottom,
                "left": inset.left, "right": inset.right])
            DispatchQueue.main.async { [weak self] in self?.onChange?(inset, windowSafeArea) }
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
                            if let detail = item.detail { Text(detail).foregroundStyle(.white.opacity(0.7)) }
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
