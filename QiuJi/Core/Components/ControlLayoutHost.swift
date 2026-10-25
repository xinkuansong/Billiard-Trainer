import SwiftUI

/// One context per mounted table. Measurements never feed the Foundation/table fitter.
private struct ControlLayoutContext {
    var defaults: [ControlLayoutGroup: CGRect] = [:]
    var placement = ControlLayoutPlacement.Result(frames: [:], status: .original)
    func translation(_ group: ControlLayoutGroup) -> CGSize {
        placement.translation(for: group, from: defaults)
    }
}
private struct ControlLayoutContextKey: EnvironmentKey {
    static let defaultValue: ControlLayoutContext? = nil
}
private extension EnvironmentValues {
    var controlLayoutContext: ControlLayoutContext? {
        get { self[ControlLayoutContextKey.self] }
        set { self[ControlLayoutContextKey.self] = newValue }
    }
    var legacyControlGroup: ControlLayoutGroup? {
        get { self[LegacyControlGroupKey.self] }
        set { self[LegacyControlGroupKey.self] = newValue }
    }
}
private struct LegacyControlGroupKey: EnvironmentKey { static let defaultValue: ControlLayoutGroup? = nil }
private struct FreeControlLegacyMeasurementsKey: PreferenceKey {
    static var defaultValue = FreeControlLegacyMeasurements()
    static func reduce(value: inout FreeControlLegacyMeasurements, nextValue: () -> FreeControlLegacyMeasurements) {
        let next = nextValue()
        value.groups.merge(next.groups) { _, new in new }
        value.controls.merge(next.controls) { _, new in new }
        value.obstacles += next.obstacles
    }
}
private struct ControlLayoutFramesKey: PreferenceKey {
    static var defaultValue: [ControlLayoutGroup: CGRect] = [:]
    static func reduce(value: inout [ControlLayoutGroup: CGRect], nextValue: () -> [ControlLayoutGroup: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct ControlLayoutFixedFramesKey: PreferenceKey {
    static var defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) { value += nextValue() }
}

private struct ControlLayoutFixedRegionModifier: ViewModifier {
    @Environment(\.controlLayoutContext) private var context
    func body(content: Content) -> some View {
        content.background {
            if context != nil {
                GeometryReader { proxy in
                    Color.clear.preference(key: ControlLayoutFixedFramesKey.self,
                        value: [proxy.frame(in: .named("controlLayout"))])
                        .preference(key: FreeControlLegacyMeasurementsKey.self,
                            value: .init(obstacles: [proxy.frame(in: .named("controlLayout"))]))
                }
            }
        }
    }
}

/// Camera anchors can already inherit a movement from the native power-column overlay.
enum ControlLayoutAnchorMotion { case none, instrument, instrumentVertical }
private struct ControlLayoutGroupModifier: ViewModifier {
    let group: ControlLayoutGroup
    let enabled: Bool
    let anchorMotion: ControlLayoutAnchorMotion
    @Environment(\.controlLayoutContext) private var context
    func body(content: Content) -> some View {
        let translation = enabled ? (context?.translation(group) ?? .zero) : .zero
        let instrument = context?.translation(.instrument) ?? .zero
        let inherited = anchorMotion == .instrument ? instrument
            : (anchorMotion == .instrumentVertical ? CGSize(width: 0, height: instrument.height) : .zero)
        content
            .environment(\.legacyControlGroup, enabled ? group : nil)
            .background {
                if enabled && context != nil {
                    GeometryReader { proxy in
                        let frame = proxy.frame(in: .named("controlLayout"))
                        Color.clear.preference(key: ControlLayoutFramesKey.self,
                            value: [group: frame.offsetBy(dx: -translation.width, dy: -translation.height)])
                            .preference(key: FreeControlLegacyMeasurementsKey.self,
                                value: .init(groups: [group: frame.offsetBy(dx: -translation.width, dy: -translation.height)]))
                            .preference(key: BTCloseupProtectedFramesKey.self, value: [proxy.frame(in: .global)])
                    }
                }
            }
            .offset(x: translation.width - inherited.width, y: translation.height - inherited.height)
    }
}

extension View {
    func controlLayoutFixedRegion() -> some View { modifier(ControlLayoutFixedRegionModifier()) }
    func controlLayoutGroup(_ group: ControlLayoutGroup, enabled: Bool = true, anchorMotion: ControlLayoutAnchorMotion = .none) -> some View {
        modifier(ControlLayoutGroupModifier(group: group, enabled: enabled, anchorMotion: anchorMotion))
    }
    @ViewBuilder func controlLayoutHost(page: TablePreferencePage, mode: ControlLayoutLayer, size: CGSize,
                           leading: CGRect, trailing: CGRect, defaultFits: Bool, obstacles: [CGRect] = [], busy: Bool,
                           handlesInsufficientSpace: Bool = true, editing: Binding<Bool> = .constant(false),
                           groupRegions: [ControlLayoutGroup: ControlLayoutPlacement.LaneRegions] = [:],
                           rulerHeight: CGFloat = 144, primaryTitle: String = "击球", sequenceReadOnly: Bool = false,
                           editorToolbarTop: CGFloat? = nil) -> some View {
        if page.usesFreeControlLayout {
            modifier(FreeControlHost(page: page, mode: mode == .threeD ? .threeD : .twoD, editing: editing,
                busy: busy, editorToolbarTop: editorToolbarTop, legacyInput: .init(page: CGRect(origin: .zero, size: size),
                    leading: CGRect(x: leading.minX, y: 44, width: leading.width, height: max(1, size.height - 44)),
                    trailing: CGRect(x: trailing.minX, y: 44, width: trailing.width, height: max(1, size.height - 44)),
                    defaults: [:], obstacles: obstacles, defaultFits: defaultFits, groupRegions: groupRegions)))
        } else {
            self
        }
    }
}

private struct FreeControlMeasurement: Equatable {
    var name: String
    var frame: CGRect
}
private struct FreeControlFramesKey: PreferenceKey {
    static var defaultValue: [String: FreeControlMeasurement] = [:]
    static func reduce(value: inout [String: FreeControlMeasurement], nextValue: () -> [String: FreeControlMeasurement]) {
        value.merge(nextValue()) { _, new in new }
    }
}
private struct FreeControlContext {
    var values: FreeControlValues
    var defaults: [String: FreeControlMeasurement]
    var windowSize: CGSize
    var hostOrigin: CGPoint
}
private struct FreeControlContextKey: EnvironmentKey {
    static var defaultValue: FreeControlContext? = nil
}
private extension EnvironmentValues {
    var freeControlContext: FreeControlContext? {
        get { self[FreeControlContextKey.self] }
        set { self[FreeControlContextKey.self] = newValue }
    }
}

/// The measuring background is outside the visual transform, so moving one control
/// never changes its baseline or any sibling's layout proposal.
private struct FreeControlItem: ViewModifier {
    let id: String
    let name: String
    @Environment(\.freeControlContext) private var context
    @Environment(\.legacyControlGroup) private var legacyGroup
    func body(content: Content) -> some View {
        let value = context?.values[id]
        let baseline = context?.defaults[id]?.frame
        let window = context?.windowSize ?? .zero
        let delta = value.flatMap { v in baseline.map {
            CGSize(width: v.x * window.width - $0.midX, height: v.y * window.height - $0.midY)
        }} ?? .zero
        content.scaleEffect(value?.scale ?? 1)
            .offset(x: delta.width, y: delta.height)
            .background {
                if context != nil {
                    GeometryReader { proxy in
                        // SwiftUI .global can belong to a presentation root. Persist
                        // window points using the native host's measured window origin.
                        let local = proxy.frame(in: .named("controlLayout"))
                        let origin = context?.hostOrigin ?? .zero
                        let base = local.offsetBy(dx: origin.x, dy: origin.y)
                        let actual = value.map { p in
                            CGRect(x: p.x * window.width - base.width * p.scale / 2,
                                   y: p.y * window.height - base.height * p.scale / 2,
                                   width: base.width * p.scale, height: base.height * p.scale)
                        } ?? base
                        Color.clear.preference(key: FreeControlFramesKey.self,
                            value: [id: .init(name: name, frame: base)])
                            .preference(key: FreeControlLegacyMeasurementsKey.self,
                                value: .init(controls: [id: .init(frame: base, group: legacyGroup)]))
                            .preference(key: BTCloseupProtectedFramesKey.self, value: [actual])
                    }
                }
            }
    }
}
extension View {
    func freeControlItem(_ id: String, name: String) -> some View { modifier(FreeControlItem(id: id, name: name)) }
}

/// A scroll viewport would clip both rendering and native touches after a button
/// leaves its original column. Free-layout controls retain their default slots
/// in an unclipped stack; non-layout consumers retain their original scroll behavior.
struct FreeControlColumn<Content: View>: View {
    @Environment(\.freeControlContext) private var context
    @ViewBuilder var content: () -> Content
    var body: some View {
        if context != nil { content() }
        else { ScrollView(.vertical) { content() }.scrollIndicators(.hidden) }
    }
}

private struct FreeLayoutToolButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.padding(.horizontal, 4)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle()).opacity(configuration.isPressed ? 0.65 : 1)
    }
}

/// Read the actual hosting window, including multiwindow bounds, without using UIScreen.
private struct FreeControlWindowProbe: UIViewRepresentable {
    var report: (CGSize, CGRect) -> Void
    final class Probe: UIView {
        var report: ((CGSize, CGRect) -> Void)?
        var reported = CGSize.zero
        var reportedFrame = CGRect.zero
        override func didMoveToWindow() { super.didMoveToWindow(); publish() }
        override func layoutSubviews() { super.layoutSubviews(); publish() }
        func publish() {
            guard let window else { return }
            let size = window.bounds.size
            let frame = convert(bounds, to: window)
            guard size != reported || frame != reportedFrame else { return }
            reported = size
            reportedFrame = frame
            DispatchQueue.main.async { [weak self] in self?.report?(size, frame) }
        }
    }
    func makeUIView(context: Context) -> Probe { let view = Probe(); view.isUserInteractionEnabled = false; view.report = report; return view }
    func updateUIView(_ view: Probe, context: Context) { view.report = report; view.publish() }
}

private struct FreeControlMigrationPass: Equatable {
    let measurements: FreeControlLegacyMeasurements
    let window: CGSize
    let host: CGRect
    let page: CGRect
    let mode: FreeControlLayoutMode
    let busy: Bool
    let editing: Bool
    let legacyRevision: UInt64?
}

private struct FreeControlHost: ViewModifier {
    let page: TablePreferencePage
    let mode: FreeControlLayoutMode
    @Binding var editing: Bool
    let busy: Bool
    let editorToolbarTop: CGFloat?
    let legacyInput: ControlLayoutPlacement.Input
    @ObservedObject private var store = FreeControlLayoutStore.shared
    @State private var frames: [String: FreeControlMeasurement] = [:]
    @State private var windowSize = CGSize.zero
    @State private var hostFrame = CGRect.zero
    @State private var draft: FreeControlValues?
    @State private var selected: String?
    @State private var collapsed = false
    @State private var undo: [FreeControlValues] = []
    @State private var redo: [FreeControlValues] = []
    @State private var gestureStart: FreeControlValues?
    @State private var gestureOrigin: FreeControlPlacement?
    @State private var revision: UInt64 = 0
    @State private var templateID = UUID()
    @State private var name = ""
    @State private var showName = false
    @State private var error: String?
    @State private var sourceTemplate: FreeControlTemplate?
    @State private var legacyMeasurements = FreeControlLegacyMeasurements()
    @State private var conflict = false
    @State private var saveOnly = false
    @State private var draftCreatedAt = Date()
    @State private var showScaleValue = false
    @State private var scaleText = ""

    // Enable only verified rollout pages; remaining pages retain their entry flow.
    @State private var toolbarOrigin: CGPoint?
    @State private var toolbarDragOrigin: CGPoint?
    @State private var showTemplates = false
    @State private var showLegacyTemplates = false
    @State private var templatePanelSize = CGSize.zero
    @State private var showReset = false
    @State private var deletingTemplate: FreeControlTemplate?
    @State private var menuAnchors: [String: CGRect] = [:]
    @State private var actionTemplateID: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var values: FreeControlValues { editing ? (draft ?? store.values(page: page, mode: mode)) : store.values(page: page, mode: mode) }
    /// Only the new separation pages opt in: resizing may temporarily use native slots,
    /// while saved placements and the editor retain the user's original intent.
    private var renderedValues: FreeControlValues {
        guard !editing, page == .separationPractice2D || page == .separationPractice3D || page == .twoBallPractice2D || page == .twoBallPractice3D else { return values }
        let sourceID = store.archive.pageSources?[FreeControlArchive.key(page: page, mode: mode)]
        let source = store.archive.templates.first(where: { $0.id == sourceID })?.sourceWindow
        return FreeControlResizeSafety.needsNativeSlots(values: values,
            frames: frames.mapValues(\.frame), window: windowSize, source: source) ? [:] : values
    }
    private var canMeasure: Bool { windowSize.width > 0 && windowSize.height > 0 }
    private func placement(_ id: String) -> FreeControlPlacement {
        if let value = values[id] { return value }
        let rect = frames[id]?.frame ?? .zero
        return .init(x: rect.midX / max(1, windowSize.width), y: rect.midY / max(1, windowSize.height))
    }
    private func displayedFrame(_ id: String) -> CGRect {
        let p = placement(id), size = frames[id]?.frame.size ?? .zero
        return CGRect(x: p.x * windowSize.width - size.width * p.scale / 2 - hostFrame.minX,
                      y: p.y * windowSize.height - size.height * p.scale / 2 - hostFrame.minY,
                      width: size.width * p.scale, height: size.height * p.scale)
    }
    func body(content: Content) -> some View {
        content
            .allowsHitTesting(!editing)
            .accessibilityHidden(editing)
            .environment(\.freeControlContext, .init(values: renderedValues, defaults: frames,
                windowSize: windowSize, hostOrigin: hostFrame.origin))
            // Identity context measures the legacy groups without applying their constraints to v2.
            .environment(\.controlLayoutContext, ControlLayoutContext())
            .coordinateSpace(name: "controlLayout")
            .background(FreeControlWindowProbe { size, frame in
                if windowSize != size { windowSize = size }
                if hostFrame != frame { hostFrame = frame }
            })
            .onPreferenceChange(FreeControlFramesKey.self) { if frames != $0 { frames = $0 } }
            .onPreferenceChange(FreeControlLegacyMeasurementsKey.self) { legacyMeasurements = $0 }
            .task(id: FreeControlMigrationPass(measurements: legacyMeasurements, window: windowSize,
                host: hostFrame, page: legacyInput.page, mode: mode, busy: busy, editing: editing,
                legacyRevision: store.legacyArchive?.revision)) {
                // Navigation and rotation publish intermediate native frames; only use a settled pass.
                do { try await Task.sleep(nanoseconds: 300_000_000) } catch { return }
                migrateLegacy()
            }
            .overlay(alignment: .topLeading) {
                if editing { editor }
            }
            .ignoresSafeArea(.keyboard)
            .onChange(of: editing) { _, active in
                if active {
                    store.reload(); revision = store.pageRevision(page: page, mode: mode)
                    draft = nil; selected = nil; collapsed = false; undo = []; redo = []
                    sourceTemplate = nil
                    conflict = false; saveOnly = false
                    templateID = UUID(); error = store.loadError
                    toolbarOrigin = nil; toolbarDragOrigin = nil; showTemplates = false; showLegacyTemplates = false; showReset = false
                    begin(values: store.values(page: page, mode: mode))
                } else { draft = nil; gestureStart = nil; gestureOrigin = nil }
            }
            .alert((sourceTemplate != nil && !saveOnly ? "保存模板修改" : "保存为新模板") + " · " + mode.title, isPresented: $showName) {
                TextField("模板名称", text: $name).accessibilityIdentifier("freeLayout.name")
                Button("取消", role: .cancel) {}
                Button("保存") { save() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: { Text(saveOnly ? "仅保存到个人库，不改变当前页面。名称会自动加上 · \(mode.title)" : "名称会自动加上 · \(mode.title)") }
            .alert("布局操作未完成", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                if conflict && draft != nil {
                    Button("保留草稿", role: .cancel) { error = nil }
                    Button("仅另存模板") { error = nil; templateID = UUID(); saveOnly = true; showName = true }
                    Button("重载当前布局") {
                        checkpoint(); store.reload()
                        if let failure = store.loadError { error = failure }
                        else {
                            revision = store.pageRevision(page: page, mode: mode)
                            draft = store.values(page: page, mode: mode); selected = nil
                            templateID = UUID(); saveOnly = false; conflict = false; error = nil
                        }
                    }
                } else { Button("知道了", role: .cancel) { error = nil } }
            } message: { Text(error ?? "") }
            .alert("按键大小（百分比）", isPresented: $showScaleValue) {
                TextField("例如 137.5", text: $scaleText).keyboardType(.decimalPad)
                    .accessibilityIdentifier("freeLayout.scaleValue")
                Button("取消", role: .cancel) {}
                Button("确定") { setScaleValue() }
            }
            .alert("删除这个模板？", isPresented: Binding(get: { deletingTemplate != nil }, set: { if !$0 { deletingTemplate = nil } })) {
                Button("取消", role: .cancel) { deletingTemplate = nil }
                Button("删除", role: .destructive) {
                    guard let template = deletingTemplate else { return }
                    do {
                        try store.deleteLocal(template, page: page, mode: mode)
                        if sourceTemplate?.id == template.id { sourceTemplate = nil; templateID = UUID(); name = "" }
                    } catch { self.error = error.localizedDescription }
                    deletingTemplate = nil
                }.accessibilityIdentifier("freeLayout.confirmDelete")
            } message: { Text("删除后，当前正在使用的按键布局会保留。") }

    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            Color.clear.contentShape(Rectangle())
            if draft != nil && canMeasure {
                ForEach(frames.keys.sorted(), id: \.self) { id in
                    let rect = displayedFrame(id)
                    RoundedRectangle(cornerRadius: BTRadius.md)
                        .fill(Color.btAccent.opacity(collapsed ? 0 : (selected == id ? 0.16 : 0.03)))
                        .overlay(RoundedRectangle(cornerRadius: BTRadius.md).stroke(selected == id ? Color.btAccent : HUDStyle.hairline, lineWidth: collapsed ? 0 : (selected == id ? 2 : 1)))
                        .frame(width: max(1, rect.width), height: max(1, rect.height))
                        .contentShape(Rectangle())
                        .position(x: rect.midX, y: rect.midY)
                        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
                            .onChanged { value in
                                selected = id
                                if gestureStart == nil {
                                    gestureStart = draft ?? [:]
                                    gestureOrigin = placement(id)
                                }
                                let start = gestureOrigin ?? placement(id)
                                draft?[id] = .init(x: start.x + value.translation.width / windowSize.width,
                                                  y: start.y + value.translation.height / windowSize.height, scale: start.scale)
                            }.onEnded { _ in finishGesture() })
                        .simultaneousGesture(TapGesture().onEnded { selected = id })
                        .zIndex(selected == id ? 1 : 0)
                        .accessibilityElement().accessibilityLabel(frames[id]?.name ?? id)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("freeLayout.select.\(id)")
                        .accessibilityAction { selected = id }
                }
            }
            floatingTools.zIndex(2)
        }
        .frame(width: hostFrame.width, height: hostFrame.height)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("freeLayout.editor")
        // Layout tools use one dark appearance regardless of the surrounding page.
        .environment(\.colorScheme, .dark)
    }

    // Toolbar points are host-local, independent of the window-normalized control placements.
    // Only the toolbar is kept reachable. User controls remain free to cross the safe area.
    private var toolbarSize: CGSize {
        CGSize(width: collapsed ? 196 : min(480, max(280, hostFrame.width - 16)), height: collapsed ? 52 : 104)
    }
    private func reachableToolbar(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(max(8, point.x), max(8, hostFrame.width - toolbarSize.width - 8)),
                y: min(max(8, point.y), max(8, hostFrame.height - toolbarSize.height - 8)))
    }
    private var toolbarPoint: CGPoint {
        // The page supplies the visible palette edge in host-local points, not its larger hit boxes.
        return reachableToolbar(toolbarOrigin ?? CGPoint(x: (hostFrame.width - toolbarSize.width) / 2,
                                                         y: editorToolbarTop ?? 64))
    }
    private var hasDropdown: Bool { showTemplates || showReset }
    private func closeDropdown() { showTemplates = false; showLegacyTemplates = false; showReset = false; actionTemplateID = nil }
    private var dropdownAnchor: CGRect {
        menuAnchors[showReset ? "reset" : "templates"] ?? CGRect(origin: toolbarPoint, size: toolbarSize)
    }
    private var dropdownBelow: Bool {
        hostFrame.height - dropdownAnchor.maxY >= dropdownAnchor.minY
    }
    private var dropdownCapacity: CGFloat {
        max(60, (dropdownBelow ? hostFrame.height - dropdownAnchor.maxY : dropdownAnchor.minY) - 14)
    }
    private var dropdownFrame: CGRect {
        let width = min(288, hostFrame.width - 16)
        return CGRect(x: min(max(8, dropdownAnchor.minX), max(8, hostFrame.width - width - 8)),
                      y: dropdownBelow ? dropdownAnchor.maxY + 6 : dropdownAnchor.minY - 6 - templatePanelSize.height,
                      width: width, height: templatePanelSize.height)
    }
    private func actionMenuFrame(_ anchor: CGRect) -> CGRect {
        let width: CGFloat = 176, height: CGFloat = 184
        let right = dropdownFrame.maxX + 6
        let x = right + width <= hostFrame.width - 8 ? right : dropdownFrame.minX - 6 - width
        return CGRect(x: max(8, x), y: min(max(8, anchor.minY - 4), max(8, hostFrame.height - height - 8)),
                      width: width, height: height)
    }
    private var floatingTools: some View {
        ZStack(alignment: .topLeading) {
            if hasDropdown {
                Color.clear.contentShape(Rectangle()).onTapGesture { closeDropdown() }
                    .accessibilityLabel("关闭布局菜单").accessibilityIdentifier("freeLayout.dismissMenu")
            }
            VStack(spacing: 0) {
                if collapsed {
                    HStack(spacing: 0) {
                        toolbarHandle
                        Button { toggleToolbar() } label: { Label("布局工具", systemImage: "chevron.down") }
                            .accessibilityLabel("展开布局工具").accessibilityIdentifier("freeLayout.collapse")
                        Button { editing = false } label: { Image(systemName: "xmark") }
                            .accessibilityLabel("取消布局编辑").accessibilityIdentifier("freeLayout.cancel")
                    }
                } else {
                    floatingHeader
                    Divider()
                    floatingSelection
                }
            }
            .font(.btFootnote).foregroundStyle(Color.btText)
            .buttonStyle(FreeLayoutToolButtonStyle()).tint(.btPrimary)
            .padding(4).frame(width: toolbarSize.width, height: toolbarSize.height)
            .modifier(DailyLayoutEditorSurface())
            .contentShape(Rectangle()).onTapGesture { closeDropdown() }
            .position(x: toolbarPoint.x + toolbarSize.width / 2, y: toolbarPoint.y + toolbarSize.height / 2)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("freeLayout.floatingToolbar")
            if hasDropdown && !collapsed {
                DailyLayoutDropdown(title: dropdownTitle, capacity: dropdownCapacity,
                    back: nil,
                    close: closeDropdown) { dropdownItems }
                    .frame(width: min(288, hostFrame.width - 16))
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { templatePanelSize = $0 }
                    .position(x: dropdownFrame.midX, y: dropdownFrame.midY)
                    .transition(.opacity)
                    .zIndex(1)
                if let id = actionTemplateID,
                   let template = personalTemplates.first(where: { $0.id == id }),
                   let anchor = menuAnchors[id.uuidString] {
                    let rect = actionMenuFrame(anchor)
                    VStack(spacing: 0) { templateActions(template) }
                        .buttonStyle(DailyLayoutMenuButtonStyle())
                        .font(.btSubheadline).foregroundStyle(Color.btText).tint(.btPrimary)
                        .padding(.vertical, 4).frame(width: rect.width, height: rect.height)
                        .modifier(DailyLayoutEditorSurface())
                        .position(x: rect.midX, y: rect.midY)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("freeLayout.templateSubmenu")
                        .zIndex(2)
                }
            }
        }
        .coordinateSpace(name: "dailyLayoutTools")
        .onPreferenceChange(DailyLayoutMenuAnchorsKey.self) { menuAnchors = $0 }
    }
    private func toggleToolbar() {
        toolbarOrigin = toolbarPoint
        closeDropdown()
        withAnimation(reduceMotion ? nil : BTMotion.easeFast) { collapsed.toggle() }
    }
    private var dropdownTitle: String { showReset ? "重置布局" : (showLegacyTemplates ? "恢复旧版模板" : "布局模板 · \(mode.title)") }
    @ViewBuilder private var dropdownItems: some View {
        if showReset {
            Button("恢复此键") {
                if let id = selected { checkpoint(); draft?.removeValue(forKey: id) }; closeDropdown()
            }.disabled(selected == nil).accessibilityIdentifier("freeLayout.resetSelected")
            Divider().padding(.horizontal, 12)
            Button("全部默认") { checkpoint(); draft = [:]; closeDropdown() }.accessibilityIdentifier("freeLayout.resetAll")
            Divider().padding(.horizontal, 12)
            Button("重做") {
                if let last = redo.popLast() { undo.append(draft ?? [:]); draft = last }; closeDropdown()
            }.disabled(redo.isEmpty).accessibilityIdentifier("freeLayout.redo")
        } else if showLegacyTemplates {
            Button("返回本页模板") { showLegacyTemplates = false }
            Text("选择旧模板，在本页预览并另存。原模板会保留。")
                .font(.btCaption).foregroundStyle(Color.btTextSecondary).padding(12)
            if let failure = store.legacyError { Text(failure).font(.btCaption).padding(12) }
            ForEach((store.legacyArchive?.templates.values.map { $0 } ?? []).sorted { $0.name < $1.name }) { template in
                Button(template.name) { recoverLegacy(template.id, name: template.name) }
                    .accessibilityIdentifier("freeLayout.recoverLegacy." + template.id.uuidString)
            }
            ForEach(unassignedTemplates) { template in
                Button(template.displayName) {
                    do {
                        begin(values: try store.recoverUnassignedDraft(template, page: page, mode: mode))
                        name = FreeControlTemplate.userName(template.baseName)
                    } catch { self.error = error.localizedDescription }
                }.disabled(template.mode != mode)
            }
        } else {
            HStack(spacing: 8) {
                Button { begin(values: [:]) } label: {
                    Label("本页默认 · \(mode.title)", systemImage: "house")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("freeLayout.default")
                Button {} label: {
                    Image(systemName: "ellipsis").foregroundStyle(Color.btTextSecondary)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain).disabled(true)
                .accessibilityLabel("本页默认布局，不可管理")
                .accessibilityIdentifier("freeLayout.defaultActions")
            }.padding(.trailing, 4)
            ForEach(personalTemplates) { template in
                Divider().padding(.horizontal, 12)
                HStack(spacing: 8) {
                    Text(template.displayName).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    if template.pinnedAt != nil {
                        Image(systemName: "pin.fill").font(.btCaption).foregroundStyle(Color.btTextSecondary)
                    }
                    Button {
                        actionTemplateID = actionTemplateID == template.id ? nil : template.id
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .modifier(DailyLayoutMenuAnchor(id: template.id.uuidString))
                    .buttonStyle(.plain)
                    .accessibilityLabel(template.displayName + "，设置")
                    .accessibilityIdentifier("freeLayout.templateActions." + template.id.uuidString)
                }
                .padding(.leading, 12).padding(.trailing, 4).frame(minHeight: 44)
                .background(actionTemplateID == template.id ? Color.btPrimaryMuted : .clear)
                .accessibilityElement(children: .contain).accessibilityIdentifier("freeLayout.template." + template.id.uuidString)
            }
            if store.legacyArchive?.templates.isEmpty == false || store.legacyError != nil || !unassignedTemplates.isEmpty {
                Divider().padding(.horizontal, 12)
                Button { showLegacyTemplates = true; actionTemplateID = nil } label: {
                    HStack { Text("恢复旧版模板"); Spacer(); Image(systemName: "chevron.right") }
                }.accessibilityIdentifier("freeLayout.legacyRecovery")
            }
        }
    }

    private var unassignedTemplates: [FreeControlTemplate] {
        store.archive.templates.filter { TablePreferencePage(rawValue: $0.sourcePage)?.supportsControlLayoutEditing != true }
    }

    private func recoverLegacy(_ id: UUID, name: String) {
        var input = legacyInput
        input.defaults = mode == .twoD ? legacyMeasurements.groups.filter { $0.key != .camera } : legacyMeasurements.groups
        input.obstacles += legacyMeasurements.obstacles
        let domain: ControlLayoutDomain = UIDevice.current.userInterfaceIdiom == .pad
            ? (windowSize.height > windowSize.width ? .padPortrait : .padLandscape) : .phoneLandscape
        do {
            let result = try store.recoverLegacyDraft(id, page: page, mode: mode, domain: domain,
                input: input, controls: legacyMeasurements.controls,
                window: .init(width: windowSize.width, height: windowSize.height))
            if let pending = result.pending { error = pending; return }
            begin(values: result.values); self.name = FreeControlTemplate.userName(name)
        } catch { self.error = error.localizedDescription }
    }

    @ViewBuilder private func templateActions(_ template: FreeControlTemplate) -> some View {
        Button { use(template) } label: { Label("使用", systemImage: "checkmark") }
            .accessibilityIdentifier("freeLayout.useTemplate")
        Button {
            do {
                try store.validateLocal(template, page: page, mode: mode)
                begin(values: template.values)
                sourceTemplate = template; name = FreeControlTemplate.userName(template.baseName)
            } catch { self.error = error.localizedDescription }
        } label: { Label("修改", systemImage: "pencil") }
            .accessibilityIdentifier("freeLayout.editTemplate")
        Button {
            do {
                try store.setPinnedLocal(template, pinned: template.pinnedAt == nil, page: page, mode: mode)
                if sourceTemplate?.id == template.id { sourceTemplate = store.archive.templates.first { $0.id == template.id } }
                actionTemplateID = nil
            } catch { self.error = error.localizedDescription }
        } label: { Label(template.pinnedAt == nil ? "置顶" : "取消置顶", systemImage: "pin") }
            .accessibilityIdentifier("freeLayout.pinTemplate")
        Button(role: .destructive) { actionTemplateID = nil; deletingTemplate = template } label: {
            Label("删除", systemImage: "trash").foregroundStyle(Color.red)
        }.accessibilityIdentifier("freeLayout.deleteTemplate")
    }

    private var toolbarHandle: some View {
        Image(systemName: "line.3.horizontal")
            .foregroundStyle(Color.btTextSecondary)
            .frame(width: 44, height: 44).contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    if toolbarDragOrigin == nil { toolbarDragOrigin = toolbarPoint }
                    let start = toolbarDragOrigin ?? toolbarPoint
                    toolbarOrigin = reachableToolbar(CGPoint(x: start.x + value.translation.width, y: start.y + value.translation.height))
                    closeDropdown()
                }.onEnded { _ in toolbarDragOrigin = nil })
            .accessibilityElement().accessibilityLabel("拖动布局工具条")
            .accessibilityIdentifier("freeLayout.toolbarHandle")
            .accessibilityAction(named: "移至顶部") { toolbarOrigin = nil }
            .accessibilityAction(named: "移至底部") {
                toolbarOrigin = reachableToolbar(CGPoint(x: toolbarPoint.x, y: hostFrame.height))
            }
    }
    private var floatingHeader: some View {
        HStack(spacing: 0) {
            toolbarHandle
            Button { let next = !showTemplates; closeDropdown(); showTemplates = next } label: {
                HStack(spacing: 4) {
                    Text(sourceTemplate?.displayName ?? ((store.values(page: page, mode: mode).isEmpty ? "本页默认" : "当前布局") + " · " + mode.title))
                        .lineLimit(1)
                    Image(systemName: showTemplates ? "chevron.up" : "chevron.down").font(.btCaption2)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.accessibilityIdentifier("freeLayout.templates")
                .modifier(DailyLayoutMenuAnchor(id: "templates"))
                .background(showTemplates ? Color.btPrimaryMuted : .clear, in: RoundedRectangle(cornerRadius: BTRadius.sm))
            Button("撤销") {
                guard let last = undo.popLast() else { return }; redo.append(draft ?? [:]); draft = last
            }.disabled(undo.isEmpty).accessibilityIdentifier("freeLayout.undo")
            Button("重置") { let next = !showReset; closeDropdown(); showReset = next }
                .accessibilityIdentifier("freeLayout.resetMenu")
                .modifier(DailyLayoutMenuAnchor(id: "reset"))
                .background(showReset ? Color.btPrimaryMuted : .clear, in: RoundedRectangle(cornerRadius: BTRadius.sm))
            Button("取消") { editing = false }.accessibilityIdentifier("freeLayout.cancel")
            Button { showName = true } label: {
                Text("保存模板").foregroundStyle(.white).padding(.horizontal, 4)
                    .frame(height: 36).background(Color.btPrimary, in: RoundedRectangle(cornerRadius: BTRadius.sm))
            }.accessibilityIdentifier("freeLayout.save")
        }
    }
    private var floatingSelection: some View {
        HStack(spacing: 0) {
            Text(selected.flatMap { frames[$0]?.name } ?? "未选中")
                .lineLimit(1).frame(width: 88).accessibilityIdentifier("freeLayout.selectedName")
            if let id = selected {
                Button { resizeSelected(id, by: -0.05) } label: { Image(systemName: "minus") }
                    .accessibilityLabel("缩小按键").accessibilityIdentifier("freeLayout.smaller")
                Slider(value: Binding(get: { min(2.5, max(0.25, placement(id).scale)) }, set: { value in
                    var p = placement(id); p.scale = value; draft?[id] = p
                }), in: 0.25...2.5, onEditingChanged: { active in
                    if active { gestureStart = draft ?? [:] } else { finishGesture() }
                }).id(id).accessibilityLabel("按键大小").accessibilityIdentifier("freeLayout.scale")
                Button { resizeSelected(id, by: 0.05) } label: { Image(systemName: "plus") }
                    .accessibilityLabel("放大按键").accessibilityIdentifier("freeLayout.larger")
                Button(String(format: "%.0f%%", placement(id).scale * 100)) {
                    scaleText = String(format: "%.2f", placement(id).scale * 100); showScaleValue = true
                }.frame(minWidth: 50).monospacedDigit().accessibilityIdentifier("freeLayout.exactScale")
            } else {
                Text("点选按键后，拖动或调整大小").font(.btCaption).foregroundStyle(Color.btTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button { toggleToolbar() } label: { Image(systemName: "chevron.up") }
                .accessibilityLabel("收起布局工具")
                .accessibilityIdentifier("freeLayout.collapse")
        }
    }
    private func resizeSelected(_ id: String, by amount: Double) {
        checkpoint(); var p = placement(id); p.scale = max(0.01, p.scale + amount); draft?[id] = p
    }

    private var personalTemplates: [FreeControlTemplate] { store.localTemplates(page: page, mode: mode) }
    private func use(_ template: FreeControlTemplate) {
        do {
            try store.applyLocal(template.id, page: page, mode: mode, expectedPageRevision: revision)
            editing = false
        } catch { self.error = error.localizedDescription }
    }

    private func begin(values: FreeControlValues) {
        draft = values; selected = nil; undo = []; redo = []; templateID = UUID(); name = ""; sourceTemplate = nil
        saveOnly = false; conflict = false; draftCreatedAt = Date(); showTemplates = false; showLegacyTemplates = false
    }
    private func setScaleValue() {
        guard let id = selected,
              let percentage = Double(scaleText.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")),
              percentage.isFinite, percentage > 0, percentage / 100 > 0 else {
            error = "请输入大于零的有效百分比。"; return
        }
        checkpoint(); var value = placement(id); value.scale = percentage / 100; draft?[id] = value
    }
    private func migrateLegacy() {
        guard !editing, !busy, canMeasure, !legacyMeasurements.groups.isEmpty,
              !legacyMeasurements.controls.isEmpty else { return }
        guard UIDevice.current.userInterfaceIdiom == .pad || windowSize.width > windowSize.height else { return }
        guard abs(legacyInput.page.width - windowSize.width) < 1,
              abs(legacyInput.page.height - windowSize.height) < 1 else { return }
        var input = legacyInput
        input.defaults = mode == .twoD ? legacyMeasurements.groups.filter { $0.key != .camera } : legacyMeasurements.groups
        input.obstacles += legacyMeasurements.obstacles
        let domain: ControlLayoutDomain = UIDevice.current.userInterfaceIdiom == .pad
            ? (windowSize.height > windowSize.width ? .padPortrait : .padLandscape) : .phoneLandscape
        do {
            try store.migrateMeasuredPage(page: page, pageTitle: page.layoutTitle, mode: mode, domain: domain,
                input: input, controls: legacyMeasurements.controls,
                window: .init(width: windowSize.width, height: windowSize.height))
        } catch { self.error = error.localizedDescription }
    }
    private func checkpoint() { undo.append(draft ?? [:]); redo = [] }
    private func finishGesture() {
        if let start = gestureStart, start != draft { undo.append(start); redo = [] }
        gestureStart = nil
        gestureOrigin = nil
    }
    private func save() {
        guard canMeasure else { return }
        var result = draft ?? [:]
        // Capture each currently registered control, not the geometry of a group.
        for id in frames.keys where result[id] == nil { result[id] = placement(id) }
        do {
            if saveOnly {
                try store.saveCopyOnly(.init(id: templateID, baseName: name, mode: mode, sourcePage: page.rawValue,
                    createdAt: draftCreatedAt, values: result,
                    sourceWindow: .init(width: windowSize.width, height: windowSize.height), sourceTemplateID: sourceTemplate?.id))
            } else if let sourceTemplate {
                try store.validateLocal(sourceTemplate, page: page, mode: mode)
                try store.updateLocal(sourceTemplate, name: name, values: result, expectedPageRevision: revision,
                                      sourceWindow: .init(width: windowSize.width, height: windowSize.height))
            } else {
                try store.saveNew(id: templateID, name: name, page: page, mode: mode,
                                  values: result, expectedPageRevision: revision,
                                  sourceWindow: .init(width: windowSize.width, height: windowSize.height),
                                  sourceTemplateID: sourceTemplate?.id)
            }
            editing = false
        } catch { conflict = error as? ControlLayoutError == .conflict; self.error = error.localizedDescription }
    }
}


extension DailyLayoutMetrics.Palette {
    /// Same page-local hit bounds used by Palette.fits and DailyTemplateHeader, including the black-ball wing.
    func controlLayoutProtectionFrames(table: CGRect) -> [CGRect] {
        guard fits else { return [] }
        let hitHeight = twoRows ? height : max(44, height)
        let rect = CGRect(x: table.midX - targetWidth / 2,
                          y: table.minY - height / 2 - hitHeight / 2,
                          width: targetWidth, height: hitHeight)
        var result = [rect]
        if wingWidth > 0 {
            result.append(CGRect(x: rect.maxX + 4, y: table.minY - height / 2 - rowHeight / 2,
                                 width: wingWidth, height: rowHeight))
        }
        return result
    }
}

/// Uses the layout editor's fixed dark environment for material and semantic colors.
private struct DailyLayoutEditorSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: BTRadius.md)
        content.background {
            if reduceTransparency { shape.fill(Color.btBGSecondary) }
            else { shape.fill(.regularMaterial) }
        }.overlay(shape.strokeBorder(Color.btSeparator, lineWidth: 0.5))
    }
}

private struct DailyLayoutMenuButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
            .background(configuration.isPressed ? Color.btPrimaryMuted : .clear)
            .opacity(enabled ? 1 : 0.4)
    }
}

private struct DailyLayoutMenuAnchorsKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// Measure the actual trigger in the same coordinate space as both menu levels.
private struct DailyLayoutMenuAnchor: ViewModifier {
    let id: String
    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                Color.clear.preference(key: DailyLayoutMenuAnchorsKey.self,
                    value: [id: proxy.frame(in: .named("dailyLayoutTools"))])
            }
        }
    }
}

private struct DailyLayoutDropdown<Content: View>: View {
    let title: String
    let capacity: CGFloat
    let back: (() -> Void)?
    let close: () -> Void
    @ViewBuilder var content: () -> Content
    @State private var contentHeight: CGFloat = 1
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if let back {
                    Button(action: back) { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .accessibilityLabel("返回模板列表").accessibilityIdentifier("freeLayout.backToLibrary")
                }
                Text(title).font(.btSubheadlineSemibold).lineLimit(1).padding(.leading, back == nil ? 12 : 0)
                Spacer(minLength: 0)
                Button(action: close) { Image(systemName: "xmark").frame(width: 44, height: 44) }
                    .accessibilityLabel("关闭布局菜单").accessibilityIdentifier("freeLayout.closeTemplates")
            }.buttonStyle(.plain)
            Divider().padding(.horizontal, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) { content() }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: min(contentHeight, max(44, capacity - 52)))
            .buttonStyle(DailyLayoutMenuButtonStyle())
        }
        .padding(.bottom, 8)
        .font(.btSubheadline).foregroundStyle(Color.btText).tint(.btPrimary)
        .modifier(DailyLayoutEditorSurface())
        .contentShape(Rectangle()).onTapGesture {}
        .accessibilityElement(children: .contain).accessibilityIdentifier("freeLayout.dropdown")
        .accessibilityAddTraits(.isModal).accessibilityAction(.escape, close)
    }
}
